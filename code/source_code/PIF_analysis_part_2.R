# Title: Part 2 - Run PIF analysis
# Authors: Fred Cudhea & Brooke Bell
# Last Updated: 09-15-2025

############################################################################

### Documentation for R script ###

# This script runs after "PIF_analysis_part_1.r". After we've generated a distribution of 
# PIFs/attributable mortality/incidence for each subgroup/dietary factor/disease, 
# we run this to generate summary statistics (median, uncertainty intervals) of 
# the output generated in part one.

############################################################################

# First, read in relevant files, including the PIFs/attributable mortality sims 
# file (alldisease), observed mortality/incidence sims file (total disease), and 
# observed population sims file (pop.draws).

alldisease <- read_csv(file = paste0(output_location, diet_pattern, 
                               "/all.disease.draws_", year.vec.string, 
                               "_", covar.vec.string, "_", diet_pattern, 
                               ".csv"))


alldisease <- alldisease[order(alldisease$riskfactor, alldisease$outcome, 
                         alldisease$female, alldisease$age, alldisease$race),]

totaldisease <- read_csv(paste0(file_location, "observed.disease.burden.draws.csv"))

pop.draws <- read_csv(paste0(file_location, "observed.pop.draws.csv"))

# For pop.draws, rename sim variables (specifically change "X123", to "Y123", etc...). 
# This will come in handy when we later merge with files that use "X123" naming scheme. 

names(pop.draws) <- gsub("X", "Y", names(pop.draws))

# Recode demographic variables in totaldisease (to match with "alldisease", the 
# output created in part one).

totaldisease <- totaldisease[order(totaldisease$disease, totaldisease$subgroup),]
totaldisease$age <- 0
totaldisease$age[totaldisease$Age_label == "20-34"] <- 25
totaldisease$age[totaldisease$Age_label == "35-44"] <- 35
totaldisease$age[totaldisease$Age_label == "45-54"] <- 45
totaldisease$age[totaldisease$Age_label == "55-64"] <- 55
totaldisease$age[totaldisease$Age_label == "65-74"] <- 65
totaldisease$age[totaldisease$Age_label == "75+"] <- 75

totaldisease$female[totaldisease$Sex == 1] <- 1
totaldisease$female[totaldisease$Sex == 2] <- 0

totaldisease$race[totaldisease$Race_label == "NHW"] <- 1
totaldisease$race[totaldisease$Race_label == "NHB"] <- 2
totaldisease$race[totaldisease$Race_label == "HIS"] <- 3
totaldisease$race[totaldisease$Race_label == "OTH"] <- 4

# Recall that, for the purposes of calculating the PIFs, we treat each 
# outcome/pathway as a distinct outcome (direct effect, mediated by BMI, and 
# mediated by SBP). But for purposes of collapsing outcomes (e.g, calculating 
# joint PIFs), it's better to have the outcomes and pathway separated into two 
# different variables. Below is code do that. 

totaldisease[!grepl("_", totaldisease$disease, fixed = TRUE),]$disease <- 
  paste(totaldisease[!grepl("_", totaldisease$disease, fixed = TRUE),]$disease, "_direct", sep = "")

totaldisease <-totaldisease %>% separate(col = disease, into = c("outcome", "pathway"), sep = "_")
totaldisease <- totaldisease[totaldisease$pathway  == "direct",]
totaldisease <- subset(totaldisease, outcome %in% diseases.vec, select = -c(pathway))

# Recall, we also have three broader outcome categories of interest (denoted as 
# disease type 1, disease type 2, disease type 3), and have mapped each outcome 
# to each category (for all three) in run_models.rmd, and that mapping is stored 
# in disease.table. Code below uses that mapping to create variables for the 
# three disease type categories.

totaldisease$disease_type <- 
  disease.type.vec[match(totaldisease$outcome[totaldisease$outcome %in% diseases.vec], 
                         disease.table)]

totaldisease$disease_type1 <- 
  disease.type1.vec[match(totaldisease$outcome[totaldisease$outcome %in% diseases.vec], 
                          disease.table)]

totaldisease$disease_type2 <- 
  disease.type2.vec[match(totaldisease$outcome[totaldisease$outcome %in% diseases.vec], 
                          disease.table)]

totaldisease$disease_type3 <- 
  disease.type3.vec[match(totaldisease$outcome[totaldisease$outcome %in% diseases.vec], 
                          disease.table)]

# Get rid of unused demo vars (we'll be using the new recoded ones we created earlier).

totaldisease <- 
  totaldisease[, -which(names(totaldisease) %in% c("X", "disease", "Sex", 
                                            "age_gp", "race_gp", "agecat"))]

# Read in PIF sims file.

pif <- read_csv(file = paste0(output_location, diet_pattern, "/all.PIFs_", 
                            year.vec.string, "_", covar.vec.string, "_", 
                            diet_pattern, ".csv"))

# Read in script that defines functions for summing up by demographic variables.

source(paste0(code_location, "functions/sum_by_strata.r"))

# Get summary stats of attributable mortality/incidence for each 
# subgroup/dietary-factor+pathway/outcome. Rename certain variables of 
# resulting variables for clarity.

sum.stats.attr.disease.PIF <- sum.stats.maker(alldisease = alldisease)

sum.stats.PIF <- sum.stats.maker(alldisease = pif)

names(sum.stats.attr.disease.PIF)[(1 + length(covar.vec)):(6 + length(covar.vec))] <- 
  c("mean (food)", "se (food)", "sd (food)", "mean (food, counterfactual)", 
    "se (food, counterfactual)", "sd (food, counterfactual)")

names(sum.stats.PIF)[(1 + length(covar.vec)):(6 + length(covar.vec))] <- 
  c("mean (food)", "se (food)", "sd (food)", "mean (food, counterfactual)", 
    "se (food, counterfactual)", "sd (food, counterfactual)")

# Read in original exposure file, strictly for the purpose of calculating "l", 
# the number of subgroups. Note this is only valid assuming you subgroups are 
# defined by age, sex, and race.

# Read CSV file of exposure
disease.dat <- read_csv(file = paste0(file_location, "nhanes1723_agesexrace_merged_", 
                                 version.date ,".csv"))

disease.dat <- disease.dat[order(disease.dat$diet),]

if(identical(covar.vec, c("Age", "Sex", "Race"))) {
  
  l <- length(table(disease.dat$agecat)) *
    length(table(disease.dat$female)) *
    length(table(disease.dat$race))
  
}

# Now we will calculate "reverse engineered PIFs", meaning we are going to 
# back-calculte PIFs from taking the attributable mortality/incidence and dividing 
# by total number of deaths/cases. This is how we calculate PIFs for broader 
# subgroups (results by age, results by sex, results by disease type, overall 
# results for the population, etc... as opposed results by each 
# age/sex/race/outcome/etc..). 

# First, we merge "alldisease", "totaldisease" and "pop.draws" into one file, and 
# identify the column index where part starts in this new dataframe.

merged <- reduce(list(alldisease, totaldisease, pop.draws), merge)

alldisease.starting.point <- which(names(merged) == "V1")
alldisease.ending.point <- which(names(merged) == paste("V", nsim1, sep = ""))
totaldisease.starting.point <- which(names(merged) == "X1")
totaldisease.ending.point <- which(names(merged) == paste("X", nsim1, sep = ""))
pop.starting.point <- which(names(merged) == "Y1")
pop.ending.point <- which(names(merged) == paste("Y", nsim1, sep = ""))

# Create a new matrix with "reverse-engineered" PIFs calculated by dividing 
# "alldisease" values (attributable disease) by "totaldisease" values (observed disease). 
# Order it (by risk factor, disease type, outcome, sex, age, race). If any NAs 
# (from observed disease values being zero for whatever reason), change to 0. Save. 

RE.PIFs <- cbind(merged[, which(names(merged) %in% c("age", 
                                                    "female", 
                                                    "race", 
                                                    "outcome", 
                                                    "pathway", 
                                                    "disease_type", 
                                                    "disease_type1", 
                                                    "disease_type2", 
                                                    "disease_type3",
                                                    "riskfactor"))], 
                 merged[, alldisease.starting.point:alldisease.ending.point] / 
                   merged[, totaldisease.starting.point:totaldisease.ending.point])

RE.PIFs <- RE.PIFs[order(RE.PIFs$riskfactor, 
                         RE.PIFs$disease_type, 
                         RE.PIFs$outcome, 
                         RE.PIFs$female, 
                         RE.PIFs$age, 
                         RE.PIFs$race),]

RE.PIFs[is.na(RE.PIFs)] <- 0

write_csv(x = RE.PIFs, 
          file = paste0(output_location, diet_pattern, "/all.disease.draws_RE.PIFs_", 
                     year.vec.string, "_", covar.vec.string, "_", diet_pattern, 
                     ".csv"))

# Next, we use the same idea to get "standardized mortality", as in, the number 
# of people saved (if at the counterfactual) per 100,000 people. So now, we take 
# attributable disease, divide by total population, then multiply by 100,000.

standardized.disease.info <- merged[,which(names(merged) %in% c("age", 
                                                             "female", 
                                                             "race", 
                                                             "outcome", 
                                                             "pathway", 
                                                             "disease_type", 
                                                             "disease_type1", 
                                                             "disease_type2", 
                                                             "disease_type3",
                                                             "riskfactor"))]

standardized.disease <- 
  cbind(standardized.disease.info, 
        merged[, alldisease.starting.point:alldisease.ending.point] /
          merged[, pop.starting.point:pop.ending.point] * 100000)

standardized.disease <- 
  standardized.disease[order(standardized.disease$riskfactor, 
                          standardized.disease$outcome, 
                          standardized.disease$disease_type, 
                          standardized.disease$female, 
                          standardized.disease$age, 
                          standardized.disease$race),]

standardized.disease[is.na(standardized.disease)] <- 0

write_csv(x = standardized.disease, 
          file = paste0(output_location, diet_pattern, "/standardized.disease_", 
                     year.vec.string, "_", covar.vec.string, "_", 
                     diet_pattern, ".csv"))

# Now we have a distribution of "reverse-engineered" PIFs and events prevented 
# per 100,000 for all subgroups. Now we take those and get summary stats (and 
# edit var names for standardized.disease.sum.stats file for clarity).

RE.PIFs.sum.stats <- sum.stats.maker.RE.PAFs(RE.PIFs)

standardized.disease.sum.stats <- sum.stats.maker(standardized.disease)

names(standardized.disease.sum.stats)[(length(names(standardized.disease.sum.stats)) - 4):
                                     length(names(standardized.disease.sum.stats))] <- 
  paste0("disease.per.100k.", 
         names(standardized.disease.sum.stats)[(length(names(standardized.disease.sum.stats)) - 4):
                                              length(names(standardized.disease.sum.stats))])

# Merge the summary stats files for attributable mortality/incidence, 
# "reverse-engineered" PIFs, and standardized attributable mortality/incidence, and 
# save it. Also, save the summary stats file for the actual PIFs 
# (not "reverse-engineered") we made earlier.

sum.stats.attr.disease.merged <- 
  reduce(list(sum.stats.attr.disease.PIF, 
              RE.PIFs.sum.stats, 
              standardized.disease.sum.stats), 
         merge)

write.csv(x = sum.stats.attr.disease.merged, 
          file = paste0(output_location, diet_pattern, 
                     "/summarystats_attributable_USdisease_", 
                     covar.vec.string, "_", year.vec.string, "_", 
                     diet_pattern, ".csv"), row.names = FALSE)

write.csv(x = sum.stats.PIF, 
          file = paste0(output_location, diet_pattern, "/summarystats_PIFs_", 
                     covar.vec.string, "_", year.vec.string, "_", 
                     diet_pattern, ".csv"), row.names = FALSE)

# Ok, now that we've done that. Let's get to making output for the manuscript. 
# That is, summary statistics for broader subgroups (results by age, results by 
# sex, results by disease type, etc... as opposed results by each age/sex/race/outcome/etc..).

# We will create results for all possible combinations that could be of interest 
# here but you will choose what to report based on what your research focus is.

# First we put all strata of interest into a vector called "strata". Then we 
# loop through the length of that vector. For each iteration i of that loop, we 
# extract all combinations of that vector with i element using the combn function, 
# convert the resulting matrix to a list, and append those list elements to 
# "strata.combos" list which will have an element for each possible strata combination.

strata.combos <- list()
strata <- c("age", "female", "race", "outcome", "pathway", 
            "disease_type", "disease_type1", "disease_type2", "disease_type3")

# order should match with covar.vec
for(i in 1:length(strata)) {
  
  x <- combn(strata, i)
  combos.for.i <- split(x, rep(1:ncol(x), each = nrow(x))) 
  strata.combos <- c(strata.combos, combos.for.i)
  
}

# Not all combinations are of interest. We want to, at the very least, have 
# outcome pathway or a disease type as a strata (Results are event-specific 
# after all. We aren't reporting all preventable events by age when the types 
# of events are not even consistent by outcome). Also, not all the strata are 
# mutually exclusive. It's redundant to stratify by disease type 1 if you're 
# already stratifying by outcome so we don't need any strata combos that has 
# both outcome and disease type 1, for example. We want to filter out unnecessary 
# strata combos, which is what the code below does (we loop through the list of 
# strata combos and identify the index the strata combos that qualify as of interest).
                                                                                                                         
# An astute reader might note that stratifying just by "pathway" and not 
# outcome/disease type will mix up incidence (from cancer) and mortality 
# (from CMDs). Good point! You got me! (Generally, I recommend not mixing 
# cancer mortality and CMD incidence when reporting results)

strata.combos.of.interest.boolean <- c()

for(i in 1:length(strata.combos)) {
  
  disease_overlap_count <- 
    sum("outcome" %in% strata.combos[[i]], 
        "disease_type" %in% strata.combos[[i]], 
        "disease_type1" %in% strata.combos[[i]], 
        "disease_type2" %in% strata.combos[[i]], 
        "disease_type3" %in% strata.combos[[i]])
  
  strata.combos.of.interest.boolean[i] <- 
    any(strata.combos[[i]] %in% c("outcome", 
                                  "pathway", 
                                  "disease_type", 
                                  "disease_type1", 
                                  "disease_type2", 
                                  "disease_type3")) & (disease_overlap_count < 2)
  
}

strata.combos.of.interest.index <- which(strata.combos.of.interest.boolean)

# check
print(strata.combos.of.interest.index)

# Having identifying the index for each strata combo of interest, we can loop 
# through them and apply the Sum.by.strata command which takes as inputs the 
# attributable disease sims, total disease sims, total pop sims, and the stratas of 
# interest, and uses that to calculate 4 output files  of interest: 
#   
# 1: summary stats of attributable mortality/incidence  +  "reverse engineered" PIFs 
#  +  standardized preventable mortality/incidence by specified strata, 
# 
# 2: entire simulation of attributable mortality/incidence by specified strata, 
# 
# 3: entire simulation of observed deaths by specified strata, 
# 
# 4: entire simulation of "reverse engineered" PIFs by specified strata.

for(i in strata.combos.of.interest.index) {
  
  print(i)
  print(strata.combos[[i]])
  print("")
  
  sum.stats.byX.attr.disease <- 
    Sum.by.strata(alldisease = alldisease, 
                  totaldisease = totaldisease, 
                  pop = pop.draws, 
                  covar = strata.combos[[i]])
  
  write.csv(x = sum.stats.byX.attr.disease[[1]], 
            file = paste0(output_location, diet_pattern, 
                       "/summarystats_attributable_USdisease_", 
                       "by_", paste(strata.combos[[i]], sep = "", collapse = "_"), 
                       "_", year.vec.string, "_", diet_pattern,".csv"), 
            row.names = FALSE)
  
  write.csv(x = sum.stats.byX.attr.disease[[2]], 
            file = paste0(output_location, diet_pattern, 
                       "/attributable_USdisease_draws_", 
                       "by_", paste(strata.combos[[i]], sep = "", collapse = "_"), 
                       "_", year.vec.string, "_", diet_pattern, ".csv"), 
            row.names = FALSE)
  
  write.csv(x = sum.stats.byX.attr.disease[[3]], 
            file = paste0(output_location, diet_pattern, 
                       "/total_USdisease_draws_", 
                       "by_", paste(strata.combos[[i]], sep = "", collapse = "_"), 
                       "_", year.vec.string, "_", diet_pattern, ".csv"), 
            row.names = FALSE)
  
  write.csv(x = sum.stats.byX.attr.disease[[4]], 
            file = paste0(output_location, diet_pattern, 
                       "/RE_PIFs_draws_", 
                       "by_", paste(strata.combos[[i]], sep = "", collapse = "_"), 
                       "_", year.vec.string, "_", diet_pattern, ".csv"), 
            row.names = FALSE)
  
}


