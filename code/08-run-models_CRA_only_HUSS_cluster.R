#' # Run the CRA (health) model only: HUSS 2020 and 2025 with LASTING inputs
#'
#' Version of 08-run-models with only the CRA portion. Uses LASTING's original
#' inputs (NHANES 2015-2018, original disease and population data) plus the
#' US20/US25 counterfactual rows added by add_huss_diets_to_lasting_inputs.R.
#' The environmental, economic and social models are not run.
#'
#' Changes from LASTING's 08 are marked "# HUSS EDIT".
#'
## ----initial_setup--------------------------------------

rm(list = ls(all = TRUE)) # remove all data from memory

# load packages
library(tidyverse)
library(data.table)
library(foreach)
library(doParallel)

# File location
file_location = "data_inputs/FINAL/model_data/"

# Code location
code_location = "code/"

# Set the seed
set.seed(3172023)

# data version date -- set centrally in code/version_date.R
# (defines `version_date` and the `dated()` filename helper)
# HUSS EDIT: version_date must be the date on LASTING's model files (2025-05-20)
source("code/version_date.R")

# Create parent output directory with today's date
ifelse(!dir.exists(file.path(paste0("outputs/model/output_", Sys.Date()))),
       dir.create(file.path(paste0("outputs/model/output_", Sys.Date()))),
       "Directory Exists")

# set output directory
output_dir <- paste0("outputs/model/output_", Sys.Date(), "/")

# HUSS EDIT: check the model input files exist before running anything
input_files <- c("input_data", "rr_agesexrace", "food_to_bmi_effects_converted",
                 "food_to_sbp_effects_converted", "nhanes1518_agesexrace_merged",
                 "cvd_cancer_merged")
input_check <- setNames(file.exists(dated(paste0(file_location, input_files))), input_files)
print(input_check)
if (!all(input_check)) stop("Missing model input file(s): ",
                            paste(names(input_check)[!input_check], collapse = ", "))

# HUSS EDIT: the cluster (Linux) treats file names as case-sensitive, so ".r" and
# ".R" are different files there (not on Windows). find_file() returns the file
# whatever the capitals of its name, so the source() calls below work on both.
find_file <- function(path) {
  if (file.exists(path)) return(path)
  in_folder <- list.files(dirname(path), full.names = TRUE)
  match <- in_folder[tolower(basename(in_folder)) == tolower(basename(path))]
  if (length(match) == 1) return(match)
  stop("Cannot find ", path, " (checked for any capitalisation)")
}

# HUSS EDIT: check every script the model loads before running anything
scripts <- c("source_code/presimulate_pop_draws.r",
             "source_code/presimulate_observed_disease_draws.r",
             "source_code/PIF_analysis_part_1.r",
             "source_code/PIF_analysis_part_2.r",
             "source_code/PIF_analysis_part_3.r",
             "functions/sum_by_strata.r")
print(sapply(paste0("code/", scripts), find_file))


## ----start_clock----------------------------------------

start_time <- Sys.time()


## ----create_dirs----------------------------------------

# HUSS EDIT: CRA output folder only
ifelse(!dir.exists(file.path(paste0(output_dir, "CRA"))),
       dir.create(file.path(paste0(output_dir, "CRA"))),
       "Directory Exists")


## ----year.vec-------------------------------------------

# strictly for naming output files
year.vec <- 2015

if(length(year.vec) > 1) {
  year.vec.string <- paste(year.vec[1], "-", year.vec[length(year.vec)], sep = "")
} else {
  year.vec.string <- as.character(year.vec)
}


## ----nsims----------------------------------------------

# Number of simulations
# HUSS EDIT: number of simulations comes from the batch file (NSIM1=10 in
# run_cra_test.sh, NSIM1=1000 in run_cra.sh). Running in RStudio without a
# batch file uses 3.
nsim1 <- as.integer(Sys.getenv("NSIM1", "3"))
print(paste("Number of simulations:", nsim1))
n.sims <- nsim1


## ----define_subgroups-----------------------------------

# Covariates vector
covar.vec <- c("Age", "Sex", "Race") # Don't mess with the order age, sex, race
covar.vec.string <- paste(covar.vec, sep = "", collapse = "")
n.covar <- length(covar.vec)


## ----diet_patterns--------------------------------------

# HUSS EDIT: LASTING's US pattern (as a check against LASTING's results) and
# HUSS 2020 / 2025. Names must match "diet_pattern" in the input data file.
diet.vec <- c("US", "US20", "US25")


## ----import_primary_data_file---------------------------

# Import exposure file
primary_input <- read_csv(file = dated(paste0(file_location, "input_data")))

# rename vars
primary_input1 <- primary_input %>%
    mutate(population = Population_size,
           subgroup = subgroup_id,
           # fix veg name
           diet_pattern = case_match(diet_pattern,
                                      "Vegetarian" ~ "Veg",
                                      .default = diet_pattern))

# HUSS EDIT: check the new patterns are in the file
print(primary_input1 %>% filter(diet_pattern %in% diet.vec) %>% count(diet_pattern, datatype))


## ----pop------------------------------------------------

# Population
# HUSS EDIT: LASTING took this from the env-eco-soc inputs (first diet, grocery rows).
# Population counts are the same for every food and diet, so take them from the
# US pattern's grocery rows directly.
pop <- primary_input1 %>%
  filter(diet_pattern == "US", datatype == "Grocery") %>%
  mutate(Sex = as.character(Sex)) %>%
  select(subgroup, Age, Age_label, Sex, Sex_label, Race, Race_label, population) %>%
  distinct() %>%
  mutate(population.se = 0) %>%
  filter(!(is.na(subgroup))) %>%
  arrange(subgroup)

nrow(pop)   # expect 48


## ----presim_pop-----------------------------------------

# pre-simulate total population numbers
source(find_file(paste0(code_location, "source_code/presimulate_pop_draws.r")))   # HUSS EDIT: find_file()

#' ## Health Models
#' 
#' Now we start with CRA portion of the code. 
#' 
#' List out dietary factors of interest and subset the primary input file by them.
#' 
#' *Note* that you must include at least two dietary factors in the CRA analysis in order for the code to run properly.
#' 
## ----diet_factors_cra-----------------------------------

# Dietary factors vector (for CRA)
# HUSS EDIT: all CRA dietary factors (LASTING's file had only 2 active, for testing).
# Every factor listed needs US20/US25 counterfactual values in the input file.
rfvec_cra <- c("dairy_tot",
               "gr_whole",
               "pf_ns",
               "pf_pm",
               "pf_redm",
               "pf_seafood",
               "veg_exc_sta",
               "ssb",
               "sodium",
               "fruit_exc_juice",
               "leg_tot")

# subset to only include dietary factors for CRA
primary_input_cra <- subset(primary_input, Foodgroup %in% rfvec_cra)


#' 
#' List out all of the cancer and cardiometabolic diseases in the disease vector, and create a corresponding disease type vector (Cancer or CMD).
#' 
#' Also, we wanted to summarize the results in two additional ways: first, by breaking down "CMD" into seven subgroups (IHD, ISTK, HSTK, OSTK, DIAB, HHD, Other_CVD), and second, by breaking down "CMD" into five subgroups (All_HD, All_STK, DIAB, All_HD, Other_CVD). 
#' 
## ----disease_vec----------------------------------------

# Diseases vector
diseases.vec <- c(# Cancers
                  "CC", "MLPC", "LC", "UC", "BC", "KC",
                  "SCC", "SCNC", "LVC", "PC", "ECA", "TC",
                  "APCA", "MMC", "OC", "GC",
                  
                  # Cardiometabolic diseases
                  "IHD", "ISTK", "HSTK", "OSTK", "DIAB", "HHD",
                  "AA", "RHD", "ENDO", "OTH", "CM", "AFF", "PVD"
                  )

# Diseases type vector
disease.type.vec <- c("Cancer", "Cancer", "Cancer", "Cancer", "Cancer", "Cancer",
                       "Cancer", "Cancer", "Cancer", "Cancer", "Cancer", "Cancer",
                       "Cancer", "Cancer", "Cancer", "Cancer",
                       "CMD", "CMD", "CMD", "CMD", "CMD", "CMD",
                       "CMD", "CMD", "CMD", "CMD", "CMD", "CMD", "CMD"
                      )

# option 1
disease.type1.vec <- disease.type.vec

# option 2
disease.type2.vec <- c("Cancer", "Cancer", "Cancer", "Cancer", "Cancer", "Cancer",
                       "Cancer", "Cancer", "Cancer", "Cancer", "Cancer", "Cancer",
                       "Cancer", "Cancer", "Cancer", "Cancer",
                       "IHD", "ISTK", "HSTK", "OSTK", "DIAB", "HHD",
                       "Other_CVD", "Other_CVD", "Other_CVD", "Other_CVD", 
                       "Other_CVD", "Other_CVD", "Other_CVD"
)

# option 3
disease.type3.vec <- c("Cancer", "Cancer", "Cancer", "Cancer", "Cancer", "Cancer",
                       "Cancer", "Cancer", "Cancer", "Cancer", "Cancer", "Cancer",
                       "Cancer", "Cancer", "Cancer", "Cancer",
                       "All_HD", "All_STK", "All_STK", "All_STK", "DIAB", "All_HD",
                       "Other_CVD", "Other_CVD", "Other_CVD", "Other_CVD", 
                       "Other_CVD", "Other_CVD", "Other_CVD"
)



#' 
#' Create variable for number of diseases, and create various vectors and matrices for the "expanded" disease list, meaning each disease, but repeated three times for the three pathways: Direct effect, mediated by SBP, and mediated by BMI.  
#' 
## ----include_mediation_pathways-------------------------

# Create some vectors
n.diseases <- length(diseases.vec)

pathway.vec <- c("direct", "medBMI", "medSBP")
pathway <- rep(pathway.vec, each = length(diseases.vec))

disease.table <- cbind(diseases.vec, 
                       disease.type.vec, 
                       disease.type1.vec, 
                       disease.type2.vec, 
                       disease.type3.vec)

diseases_medBMI.vec <- paste(diseases.vec, "_medBMI", sep = "")
diseases_medSBP.vec <- paste(diseases.vec, "_medSBP", sep = "")

diseases.vec <- c(diseases.vec, diseases_medBMI.vec, diseases_medSBP.vec)
diseases.vec.mn <- paste(diseases.vec, "mn", sep = "")
diseases.vec.se <- paste(diseases.vec, "se", sep = "")
num.diseases <- length(diseases.vec.mn)

disease.total.vec <- gsub(pattern = "_medBMI|_medSBP", replacement = "", x = diseases.vec)

disease.type.total.vec <- disease.type.vec[match(disease.total.vec, disease.table)]
disease.type1.total.vec <- disease.type1.vec[match(disease.total.vec, disease.table)]
disease.type2.total.vec <- disease.type2.vec[match(disease.total.vec, disease.table)]
disease.type3.total.vec <- disease.type3.vec[match(disease.total.vec, disease.table)]


#' 
#' Set number of exposure files and mediated effects. These should not change unless you are considering adding more mediation effects (You'd have to edit the code to add those effects those, not just this line).
#' 
## ----set_ns---------------------------------------------

nsim3 <- 1  # number of exposure files
n.mediated.effects <- 2 # number of mediated effects


#' 
#' Read in RRs, food to BMI effects, food to SBP effects, and TMREDs, and do a little data processing. (These inputs may also be in the primary data input file for the sake of completeness, but the actual inputs for the code are from the files listed below.
#' 
## ----read_inputs----------------------------------------

# Import relative risk (RR) data input
rrtotal <- read_csv(file = dated(paste0(file_location, "rr_agesexrace")))

# Import effect data inputs
Food.to.BMI.effects <- 
  read_csv(file = dated(paste0(file_location, "food_to_bmi_effects_converted")))

Food.to.SBP.effects <- 
  read_csv(file = dated(paste0(file_location, "food_to_sbp_effects_converted")))

# Create theoretical minimum ('theomin') (TMRED) from data input file
theomin <- primary_input_cra %>%
  filter(datatype == "Total") %>%
  select(Foodgroup, TMRED_Mean_Intake, TMRED_SD_Intake, TMRED_intake_unit) %>%
  distinct() %>%
  rename(Risk_factor = Foodgroup,
         TMRED = TMRED_Mean_Intake,
         SD = TMRED_SD_Intake,
         Unit = TMRED_intake_unit)


#' 
#' Create mortality/incidence simulations.
#' 
## ----presim_disease, results='hide'---------------------

# pre-simulate mortality/incidence numbers, to be used in CRA simulations, as well for calculating reverse-engineered PAFs
source(find_file(paste0(code_location, "source_code/presimulate_observed_disease_draws.r")))   # HUSS EDIT: find_file()


#' 
#' Create new output file path.
#' 
## ----cra_output_path------------------------------------

output_location <- paste0(output_dir, "CRA/")

print(output_location)


#' 
#' Next, we set up parallel processing so we can run all five diet patterns at the same time.
#' 

## ----setup_parallel_processing--------------------------

# HUSS EDIT: choose how the diet patterns are run.
# FALSE = one after another in this R session (works on Windows; use for testing).
# TRUE  = in parallel. On Windows ("PSOCK") the CRA scripts can fail with
#         "object not found", so use TRUE on the cluster (Linux) or a Mac.
use_parallel <- nzchar(Sys.getenv("SLURM_JOB_ID"))   # TRUE on the cluster, FALSE in RStudio

if (use_parallel) {
  get_os <- function(){
    sysinf <- Sys.info()
    if (!is.null(sysinf)){
      os <- sysinf['sysname']
      if (os == 'Darwin')
        os <- "osx"
      if (os == "windows")
        os <- "windows"
    } else { # if we still don't know
      os <- .Platform$OS.type
      if (grepl("^darwin", R.version$os))
        os <- "osx"
      if (grepl("linux-gnu", R.version$os))
        os <- "linux"
    }
    tolower(os)
  }

  cluster_type <- if (get_os() == "windows") {"PSOCK"} else {"FORK"}

  # HUSS EDIT: use the CPUs requested in the batch file, not every core on the node
  no_cores <- min(as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", detectCores() - 1)),
                  length(diet.vec))
  s = 1 # initialize iteration variable before forking

  cl <- makeCluster(no_cores, type = cluster_type) # Make the cluster
  registerDoParallel(cl)
}

`%run%` <- if (use_parallel) foreach::`%dopar%` else foreach::`%do%`


#' 
#' Start the for-each loop. Inside the loop is the code to run the CRA. Recall that diet.vec is a vector listing all dietary patterns of interest. The for-each loop allows us to run the code (in this case, the CRA code) within the loop in parallel for each element in diet.vec. 
#' 
#' Read in data input file, subset by dietary pattern of interest, and do some data processing. Also set seed within the for-loop with the hope that any duplicated simulations will be consistent among dietary patterns.
#' 
#' Add variable to specify number of risk factors, variable to specify length of exposure dataset for one risk factor (in our case, that's the number of subgroups) and variable specifying name of dietary of pattern. Note some of these variables needed to be added to the global environment for the code to work with parallel processing. 
#' 
#' Once we have read in everything we need, next is running the model. Part 1 actually calculates the PIFs for all diet-disease pairs of interest for all subgroups, x times depending on what you set nsim to be. The entire simulation results will be saved. Part 2 creates summary results, for all possible subgroup combinations. Part 3 calculates joint PIFs (for all subgroups).
#' 
## ----run_cra, results='hide'----------------------------

# This is the for loop that runs the CRA analysis for all dietary patterns
# HUSS EDIT: %run% is %do% or %dopar% depending on use_parallel above
foreach(ss = 1:length(diet.vec), .verbose = TRUE) %run% {

  set.seed(359)

  # Read CSV file of exposure 
  expos <- read_csv(file = dated(paste0(file_location, "input_data")))
  
  expos1 <- expos %>% 
    # fix veg
    mutate(diet_pattern = case_match(diet_pattern,
                                     "Vegetarian" ~ "Veg",
                                     .default = diet_pattern)) %>% 
    # rename variable
    rename("riskfactor" = "Foodgroup")
  
  expos2 <- expos1 %>% 
    # only keep food groups we specified above
    filter(riskfactor %in% rfvec_cra) %>% 
    # remove 'grocery' and 'nongrocery' data types
    # only keep diet pattern that we specified above
    filter(datatype == "Total" & diet_pattern == diet.vec[ss]) %>% 
    arrange(riskfactor, subgroup_id)

  # check
  print(as.data.frame(table(expos2$riskfactor, useNA = "always"))) # good
  
  expos3 <- expos2 %>% 
    rename(mean = Mean_Intake,
           se = SE_Intake,
           sd = sigma_u_wgt,
           subgroup = subgroup_id,
           CF_mean_intake = CF_Mean_Intake,
           CF_se_intake = CF_SE_Intake,
           agecat = Age,
           race = Race) %>% 
    mutate(age = case_when(agecat == 1 ~ 25,
                           agecat == 2 ~ 35,
                           agecat == 3 ~ 45,
                           agecat == 4 ~ 55,
                           agecat == 5 ~ 65,
                           agecat == 6 ~ 75),
           age.mid = case_when(agecat == 1 ~ median(c(25,35)),
                               agecat == 2 ~ median(c(35,45)),
                               agecat == 3 ~ median(c(45,55)),
                               agecat == 4 ~ median(c(55,65)),
                               agecat == 5 ~ median(c(65,75)),
                               agecat == 6 ~ median(c(75,100))),
           female = case_when(Sex == 1 ~ 1,
                              Sex == 2 ~ 0)) %>% 
    relocate(c(age, age.mid), .after = agecat) %>% 
    relocate(female, .before = Sex)
  
  # add expos3 to global environment
  .GlobalEnv$expos3 <- expos3

  # Create # of strata variable
  n.strata <- expos3 %>% select(subgroup) %>% distinct() %>% nrow()

  # number of risk factors in the file (e.g., 1 if there is only one risk factor)
  expos.rf <- length(unique(expos3$riskfactor)) 

  # length of exposure dataset for one risk factor (i.e. rows in exposure dataset: sex * age-groups * coutries)
  nsim2 <- length(expos3$mean)/expos.rf 

  # add var to global environment
  .GlobalEnv$nsim2 <- nsim2

  # set diet pattern
  diet_pattern <- diet.vec[ss]

  # add var to global environment
  .GlobalEnv$diet_pattern <- diet_pattern

  # Part 1
  # Actually runs the simulations and calculates PIF for nsim1 simulations
  source(find_file(paste0(code_location, "source_code/PIF_analysis_part_1.r")))   # HUSS EDIT: find_file() 

  # Part 2
  source(find_file(paste0(code_location, "source_code/PIF_analysis_part_2.r")))   # HUSS EDIT: find_file()

  # Part 3
  # Calculates Joint PIFs for each strata and each disease
  source(find_file(paste0(code_location, "source_code/PIF_analysis_part_3.r")))   # HUSS EDIT: find_file() 

}


#' 
#' We're done! End the timer, stop the set up to run simultaneously, and print how much time it took to run the code.
#' 
## ----end, include=TRUE----------------------------------

end_time2 <- Sys.time()

# HUSS EDIT: only stop the cluster if one was started
if (use_parallel) stopCluster(cl)

print("Time it takes to run health models: ")

# print(end_time2 - end_time1)
print(end_time2 - start_time)


