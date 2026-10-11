## ----include=FALSE--------------------------------------

knitr::opts_chunk$set(echo = TRUE,
                      results = "hide", 
                      message = FALSE,
                      warning = FALSE)


#' 
#' # Cleaning Code for NHANES Diet Data
#' 
#' This chapter walks you through all of code used to clean the raw **NHANES dietary intake** datasets.
#' 
#' ## Processed and Organ Meat
#' 
#' To start, we need to disaggregate "procecessed meat" into "processed red meat" and "processed poultry' categories. We need this because the environmental impact factors don't take "processed" into consideration, so we'll need to eventually create new food groups for the environment model ("total red meat" and "total poultry", which include both unprocessed and processed meat).
#' 
#' This is done using a SAS MACRO written by the USDA, located here:
#' 
#' -   data_inputs/DIET/dietary_intake/CODE/1. Processed Meat Categories NHANES day 1_revised_121123.sas
#' 
#' This code produces four SAS datasets:
#' 
#' -   meat_day1.sas7bdat
#' -   meat_day1_sum.sas7bdat
#' -   meat_day2.sas7bdat
#' -   meat_day2_sum.sas7bdat
#' 
#' We also have to disaggregate the organ meat food codes into "red meat" or "poultry" categories. I manually mapped various FNDDS codes that represented organ meats to either "red meat" or "poultry". The mapping is here:
#' 
#' -   methods_manual/data_inputs/DIET/dietary_intake/DATA/raw_data/meat/organ_meats_bothdays_mapped_121323.csv
#' 
#' Then, I merged this mapping with the processed meat data.
#' 
## ----message=FALSE, warning=FALSE, results='hide'-------

# OW EDIT - SECTION BEGIN
# 10/10/2026 - New inputs for processed meat disaggregation that uses NHANES 2017-2023 data. FPED 2021-2023 not available yet, so used FPED 2017-2020 for both cycles

library(tidyverse)
library(haven)

rm(list = ls())

# read in meat data
meat_day1 <- read_sas("data_inputs/DIET/dietary_intake/DATA/clean_data/meat_day1.sas7bdat")
meat_day2 <- read_sas("data_inputs/DIET/dietary_intake/DATA/clean_data/meat_day2.sas7bdat")

# read in organ mapping
new_organ <- read_csv("data_inputs/DIET/dietary_intake/DATA/raw_data/meat/organ_meats_bothdays_mapped_1723.csv")   #Edited 10/10/26 to include sweetbreads,cooked in pf_redm

# DAY 1 -----

meat_day1_1 <- meat_day1 %>% filter(!(is.na(SEQN))) %>% select(SEQN, DESCRIPTION, FOODCODE, DR1ILINE, DR1IGRMS,
                                                               DR1I_PF_ORGAN,
                                                               total_redmeat, total_poultry) %>% 
  arrange(SEQN, DR1ILINE)

# filter to organ intake > 0
meat_day1_1 %>% filter(DR1I_PF_ORGAN > 0)

# join with day1
meat_day1_2 <- left_join(meat_day1_1, new_organ, by = "DESCRIPTION")

meat_day1_3 <- meat_day1_2 %>% 
  rowwise() %>% 
  mutate(new = ifelse(is.na(new), "No change", new),
         total_redmeat_new = ifelse(new == "pf_redm", total_redmeat + DR1I_PF_ORGAN, total_redmeat),
         total_poultry_new = ifelse(new == "pf_poultry", total_poultry + DR1I_PF_ORGAN, total_poultry)) %>% 
  select(SEQN, DR1ILINE, total_redmeat_new, total_poultry_new)

# export
write_rds(meat_day1_3, "data_inputs/DIET/dietary_intake/DATA/clean_data/meat_day1_1723.rds")

# DAY 2 -----

meat_day2_1 <- meat_day2 %>% filter(!(is.na(SEQN))) %>% select(SEQN, DESCRIPTION2, FOODCODE2, DR2ILINE, DR2IGRMS,
                                                               DR2I_PF_ORGAN, total_redmeat_day2, total_poultry_day2) %>% 
  arrange(SEQN, DR2ILINE)

meat_day2_1 %>% filter(DR2I_PF_ORGAN > 0)

# join with day2
meat_day2_2 <- left_join(meat_day2_1, new_organ, by = c("DESCRIPTION2" = "DESCRIPTION"))

meat_day2_3 <- meat_day2_2 %>% 
  rowwise() %>% 
  mutate(new = ifelse(is.na(new), "No change", new),
         total_redmeat_new = ifelse(new == "pf_redm", total_redmeat_day2 + DR2I_PF_ORGAN, total_redmeat_day2),
         total_poultry_new = ifelse(new == "pf_poultry", total_poultry_day2 + DR2I_PF_ORGAN, total_poultry_day2)) %>% 
  select(SEQN, DR2ILINE, total_redmeat_new, total_poultry_new)

# export
write_rds(meat_day2_3, "data_inputs/DIET/dietary_intake/DATA/clean_data/meat_day2_1723.rds")

# To list organ-meat foods that are not yet in the mapping file:

meat_day1_1 %>% filter(DR1I_PF_ORGAN > 0) %>%
  anti_join(new_organ, by = "DESCRIPTION") %>% distinct(DESCRIPTION)

meat_day2_1 %>% filter(DR2I_PF_ORGAN > 0) %>%
  anti_join(new_organ, by = c("DESCRIPTION2" = "DESCRIPTION")) %>% distinct(DESCRIPTION2)

#OW EDIT SECTION END

#' 
#' ## Clean Raw NHANES Data {#id}
#' 
#' Now that I have dealt with processed and organ meat, I can start to clean the raw NHANES data. We use data from the 2015-2016 and 2017-2018 cycles.
#' 
#' #### Step 1: Set up workspace {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

rm(list=ls())

# load packages
library(foreign)
library(survey)
library(tidyverse)
library(psych)
library(haven)
library(readxl)

#' 
#' #### Step 2: Clean individual-level food intake datasets {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# OW Edit - Section Begin

#' NHANES 2017-March 2020 pre-pandemic (P) and August 2021-August 2023 (L).
#' P cycle: USDA's FPED individual-food files for that cycle.
#' L cycle: no FPED release yet, so FPED 2017-2018 values per 100 g are looked
#' up by food code and multiplied by grams eaten.
#'
## ----results='hide', warning=FALSE, message=FALSE-------

raw <- "data_inputs/DIET/dietary_intake/DATA/raw_data/"

# Helper: compare column names between two data frames before binding them
check_names <- function(a, b) {
  cat("In first but not second:\n");  print(setdiff(names(a), names(b)))
  cat("In second but not first:\n");  print(setdiff(names(b), names(a)))
}

# Person-level and day-level columns not needed at food level.
# Step 3 takes demographics, design variables and weights from DEMO/total files.
drop_vars <- c("RIAGENDR", "RIDAGEYR", "RIDRETH3", "SDMVPSU", "SDMVSTRA", "INDFMPIR",
               "WTDRD1PP", "WTDR2DPP", "WTDRD1", "WTDR2D", "DR1TNUMF", "DR2TNUMF")

# Join FPED food-level data to NHANES food-level nutrients.
# Matches on person (SEQN) and food line only; nutrient columns that are
# also in the FPED file are taken from the FPED file.
join_foods <- function(whole, nutrients, day, cycle) {
  line <- paste0("DR", day, "ILINE")
  nutr_only <- setdiff(names(nutrients), names(whole))
  left_join(whole,
            nutrients %>% select(SEQN, all_of(line), all_of(nutr_only)),
            by = c("SEQN", line)) %>%
    select(-any_of(drop_vars)) %>%
    mutate(nhanes_cycle = cycle)
}


# ---- 2017-March 2020 pre-pandemic (P) ----------------------------------------

# foods day 1
foods_p1_nutrients <- read_xpt(paste0(raw, "P_DR1IFF.xpt"))
foods_p1_whole     <- read_sas(paste0(raw, "fped_dr1iff_1720.sas7bdat"))   # TODO your P day-1 FPED file name
foods_p1 <- join_foods(foods_p1_whole, foods_p1_nutrients, day = 1, cycle = "2017-2020")

# foods day 2
foods_p2_nutrients <- read_xpt(paste0(raw, "P_DR2IFF.xpt"))
foods_p2_whole     <- read_sas(paste0(raw, "fped_dr2iff_1720.sas7bdat"))   # TODO your P day-2 FPED file name
foods_p2 <- join_foods(foods_p2_whole, foods_p2_nutrients, day = 2, cycle = "2017-2020")


# ---- August 2021-August 2023 (L) ----------------------------------------------

# FPED 2017-2020 values per 100 g, one row per food code
fped_100g <- read_sas(paste0(raw, "fped_1720.sas7bdat"))
fped_comp <- setdiff(names(fped_100g), c("FOODCODE", "DESCRIPTION"))   # FPED components

# Optional: stand-in 2017-2020 codes for 2021-2023 codes that FPED 2017-2018
# does not cover. CSV with two columns: new_code, proxy_code.
# Until the file exists, those foods keep NA FPED values.
proxy_file <- paste0(raw, "fped_proxy_codes_2123.csv")   
proxy <- if (file.exists(proxy_file)) {
  read_csv(proxy_file, show_col_types = FALSE)
} else {
  tibble(new_code = numeric(), proxy_code = numeric())
}

# Turn NHANES food lines into FPED amounts: value per 100 g x grams / 100
build_fped_iff <- function(iff, day) {
  line  <- paste0("DR", day, "ILINE")
  code  <- paste0("DR", day, "IFDCD")
  grams <- paste0("DR", day, "IGRMS")
  iff %>%
    select(SEQN, all_of(c(line, code, grams))) %>%
    # use the proxy code for the FPED lookup where one is given
    mutate(lookup_code = coalesce(proxy$proxy_code[match(.data[[code]], proxy$new_code)],
                                  .data[[code]])) %>%
    left_join(fped_100g, by = c("lookup_code" = "FOODCODE")) %>%
    select(-lookup_code) %>%
    mutate(across(all_of(fped_comp), ~ .x * .data[[grams]] / 100)) %>%
    rename_with(~ paste0("DR", day, "I_", .x), all_of(fped_comp))
}

# foods day 1
foods_l1_nutrients <- read_xpt(paste0(raw, "DR1IFF_L.xpt"))
foods_l1_whole     <- build_fped_iff(foods_l1_nutrients, day = 1)
foods_l1 <- join_foods(foods_l1_whole, foods_l1_nutrients, day = 1, cycle = "2021-2023")

# foods day 2
foods_l2_nutrients <- read_xpt(paste0(raw, "DR2IFF_L.xpt"))
foods_l2_whole     <- build_fped_iff(foods_l2_nutrients, day = 2)
foods_l2 <- join_foods(foods_l2_whole, foods_l2_nutrients, day = 2, cycle = "2021-2023")


# ---- Checks before binding ----------------------------------------------------
# NOTE: This is only needed because we don't have 2021-2023 FPED

# 1. Columns should match: expect character(0) under both headings
check_names(foods_p1, foods_l1)
check_names(foods_p2, foods_l2)

# 2. Is the 2021-2023 file complete? Compare people with food records against
#    people with a reliable day-1 recall in the total file.
n_distinct(foods_l1_nutrients$SEQN)
read_xpt(paste0(raw, "DR1TOT_L.xpt")) %>% filter(DR1DRSTZ == 1) %>% nrow()

# 3. 2021-2023 food codes with no FPED match (need a proxy code)
unmatched_l <- bind_rows(
  foods_l1 %>% filter(is.na(DR1I_F_TOTAL)) %>% distinct(food_code = DR1IFDCD),
  foods_l2 %>% filter(is.na(DR2I_F_TOTAL)) %>% distinct(food_code = DR2IFDCD)) %>%
  distinct()
unmatched_l   # look these up in the FNDDS 2021-2023 descriptions to choose proxies

# 4. Nutrients and food source filled in
sum(is.na(foods_l1$DR1ISODI))                # a few NA (e.g. breast milk) is normal
table(foods_l1$DR1FS, useNA = "always")

# 5. Run the corrected unmatched-code check
unmatched_l <- tibble(food_code = unique(c(foods_l1_nutrients$DR1IFDCD,
                                           foods_l2_nutrients$DR2IFDCD))) %>%
  filter(!food_code %in% fped_100g$FOODCODE)
nrow(unmatched_l)

# 6. Confirm sodium NAs and see how much the unmatched codes matter:
  # which foods have missing sodium? (expect mostly 11000000, breast milk)
  foods_l1 %>% filter(is.na(DR1ISODI)) %>% count(DR1IFDCD, sort = TRUE)
  
  # how many food lines use the 29 unmatched codes, out of all lines?
  sum(foods_l1_nutrients$DR1IFDCD %in% unmatched_l$food_code); nrow(foods_l1_nutrients)

# 7. Choosing proxies to update fped_poxy_codes_2123.csv file
  fcd_l <- read_xpt(paste0(raw, "DRXFCD_L.xpt"))
  unmatched_l %>%
    left_join(fcd_l, by = c("food_code" = "DRXFDCD")) %>%
    left_join(bind_rows(
      foods_l1_nutrients %>% count(food_code = DR1IFDCD, name = "n_day1"),
      foods_l2_nutrients %>% count(food_code = DR2IFDCD, name = "n_day2")) %>%
        group_by(food_code) %>% summarise(across(everything(), ~ sum(.x, na.rm = TRUE))),
      by = "food_code") %>%
    print(n = Inf)
  
  # NOTABLE PROXIES WITH JUDGEMENT CALLS:
  # Almond-milk yogurt → sweetened almond milk. The only non-dairy yogurt in FPED 2017–2018 is soy yogurt, which would wrongly add soy and dairy servings.
  # Oat milk → rice milk. It’s the closest grain-based plant milk.
  # Pork stew with pasta → beef, noodles and vegetables with gravy. The pork-and-noodle codes say “ham or pork”, which could be counted as processed meat. The beef code keeps it as unprocessed red meat, the same category as pork.
  # Lentil soup with meat → bean and ham soup. This adds a small amount of processed meat. If you’d rather not assume ham, use plain lentil soup (41603010) instead.
  # Potato soup with meat → potato chowder. It may contain less meat than the original.
  # Hard seltzer → vodka and soda; Moscow mule → whiskey and ginger ale; michelada → beer. These matter only for added sugar.
  # Ramen bowls → the closest noodle soup by protein: beef or meat → pho; chicken → chicken noodle soup; fish → noodle soup with fish ball and shrimp; vegetarian → Asian-style vegetable noodle soup.
  
# 8. Check, after updating proxies and running Step 2 again, that only breast milk is left without FPED values
  foods_l1 %>% filter(is.na(DR1I_F_TOTAL)) %>% count(DR1IFDCD)   # expect only 11000000
  foods_l2 %>% filter(is.na(DR2I_F_TOTAL)) %>% count(DR2IFDCD)

# ---- Combine cycles -----------------------------------------------------------

foods_day1 <- bind_rows(foods_p1, foods_l1) %>%
  mutate(foodsource = ifelse(DR1FS == 1, "Grocery", "Other"), # create food source variable
         foodsource = replace_na(foodsource, "Other"),        # NAs to "Other" (tap water, breast milk)
         dayrec = 1)

foods_day2 <- bind_rows(foods_p2, foods_l2) %>%
  mutate(foodsource = ifelse(DR2FS == 1, "Grocery", "Other"),
         foodsource = replace_na(foodsource, "Other"),
         dayrec = 2)

# read in meat data (processed-meat SAS program, run on both cycles)
meat_day1 <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/meat_day1_1723.rds")
meat_day2 <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/meat_day2_1723.rds")

foods_day1_ <- left_join(foods_day1, meat_day1, by = c("SEQN", "DR1ILINE"))
foods_day2_ <- left_join(foods_day2, meat_day2, by = c("SEQN", "DR2ILINE"))

# Fill meat totals for lines the SAS program could not process
# (2021-2023 foods that use a stand-in FPED code). Cured meat is counted as
# red meat; none of the stand-in foods contain cured poultry.
foods_day1_ <- foods_day1_ %>%
  mutate(fill = is.na(total_redmeat_new) & !is.na(DR1I_PF_MPS_TOTAL),
         total_redmeat_new = ifelse(fill, DR1I_PF_MEAT + DR1I_PF_CUREDMEAT + DR1I_PF_ORGAN,
                                    total_redmeat_new),
         total_poultry_new = ifelse(fill, DR1I_PF_POULT, total_poultry_new)) %>%
  select(-fill)

foods_day2_ <- foods_day2_ %>%
  mutate(fill = is.na(total_redmeat_new) & !is.na(DR2I_PF_MPS_TOTAL),
         total_redmeat_new = ifelse(fill, DR2I_PF_MEAT + DR2I_PF_CUREDMEAT + DR2I_PF_ORGAN,
                                    total_redmeat_new),
         total_poultry_new = ifelse(fill, DR2I_PF_POULT, total_poultry_new)) %>%
  select(-fill)

# Re-apply the SAS red meat / poultry split to each line's own FPED meat amount.
# Fixes lines where the SAS output swapped values between repeats of the same food.
fix_meat_split <- function(d, day) {
  mps <- paste0("DR", day, "I_PF_MPS_TOTAL")
  hi  <- paste0("DR", day, "I_PF_SEAFD_HI")
  lo  <- paste0("DR", day, "I_PF_SEAFD_LOW")
  d %>%
    mutate(land_meat = .data[[mps]] - .data[[hi]] - .data[[lo]],   # meat + poultry, no seafood
           sas_total = total_redmeat_new + total_poultry_new,
           red_proportion = ifelse(sas_total > 0, total_redmeat_new / sas_total, NA_real_),
           total_redmeat_new = ifelse(!is.na(red_proportion), red_proportion * land_meat,
                                      total_redmeat_new),
           total_poultry_new = ifelse(!is.na(red_proportion), (1 - red_proportion) * land_meat,
                                      total_poultry_new)) %>%
    select(-land_meat, -sas_total, -red_proportion)
}

foods_day1_ <- fix_meat_split(foods_day1_, day = 1)
foods_day2_ <- fix_meat_split(foods_day2_, day = 2)

# check: meat columns filled in for both cycles
foods_day1_ %>%
  group_by(nhanes_cycle) %>%
  summarise(lines = n(), missing_redmeat_new = sum(is.na(total_redmeat_new)))

foods_day1_ %>%
  filter(DR1I_PF_ORGAN > 0) %>%
  select(SEQN, DR1ILINE, DR1I_PF_MPS_TOTAL, DR1I_PF_SEAFD_HI, DR1I_PF_SEAFD_LOW,
         total_redmeat_new, total_poultry_new)


      # 1. What are the lines with missing meat values?
      foods_day1_ %>%
        filter(is.na(total_redmeat_new)) %>%
        group_by(nhanes_cycle) %>%
        summarise(lines = n(),
                  with_meat = sum(DR1I_PF_MPS_TOTAL > 0, na.rm = TRUE),
                  no_fped   = sum(is.na(DR1I_PF_MPS_TOTAL)),
                  breast_milk = sum(DR1IFDCD == 11000000))
      
      foods_day2_ %>%
        filter(is.na(total_redmeat_new)) %>%
        group_by(nhanes_cycle) %>%
        summarise(lines = n(),
                  with_meat = sum(DR2I_PF_MPS_TOTAL > 0, na.rm = TRUE),
                  no_fped   = sum(is.na(DR2I_PF_MPS_TOTAL)),
                  breast_milk = sum(DR2IFDCD == 11000000))
      
      # 2. Does meat add up on every line? (red meat + poultry + seafood = total)
      foods_day1_ %>%
        filter(!is.na(total_redmeat_new)) %>%
        mutate(diff = DR1I_PF_MPS_TOTAL - DR1I_PF_SEAFD_HI - DR1I_PF_SEAFD_LOW -
                 total_redmeat_new - total_poultry_new) %>%
        group_by(nhanes_cycle) %>%
        summarise(lines_off = sum(abs(diff) > 0.05, na.rm = TRUE),
                  largest_gap = max(abs(diff), na.rm = TRUE))
      
      foods_day2_ %>%
        filter(!is.na(total_redmeat_new)) %>%
        mutate(diff = DR2I_PF_MPS_TOTAL - DR2I_PF_SEAFD_HI - DR2I_PF_SEAFD_LOW -
                 total_redmeat_new - total_poultry_new) %>%
        group_by(nhanes_cycle) %>%
        summarise(lines_off = sum(abs(diff) > 0.05, na.rm = TRUE),
                  largest_gap = max(abs(diff), na.rm = TRUE))
      
      #Looks good; Only lines left without meat values are breast milk; meat adds up
    
# ---- Dietary factors (unchanged from the original) -----------------------------

# day 1
foods_day1_1 <- foods_day1_ %>%
  rowwise() %>%
  rename(sat_fat = DR1ISFAT,
         p_fat = DR1IPFAT,
         sodium = DR1ISODI,
         gr_refined = DR1I_G_REFINED,
         gr_whole = DR1I_G_WHOLE,
         added_sugar = DR1I_ADD_SUGARS,
         fruit_tot = DR1I_F_TOTAL,
         fruit_juice = DR1I_F_JUICE,
         fiber = DR1IFIBE,
         dairy_tot = DR1I_D_TOTAL,
         veg_dg = DR1I_V_DRKGR,
         veg_oth = DR1I_V_OTHER,
         veg_ro = DR1I_V_REDOR_TOTAL,
         veg_sta = DR1I_V_STARCHY_TOTAL,
         veg_leg = DR1I_V_LEGUMES,
         oil = DR1I_OILS,
         pf_egg = DR1I_PF_EGGS,
         pf_ns = DR1I_PF_NUTSDS,
         pf_soy = DR1I_PF_SOY,
         pf_poultry = DR1I_PF_POULT,
         pf_redm = DR1I_PF_MEAT,
         pf_redm_tot = total_redmeat_new,
         pf_poultry_tot = total_poultry_new,
         pf_leg = DR1I_PF_LEGUMES,
         kcal = DR1IKCAL) %>%
  mutate(sea_omega3_fa = sum(DR1IP226, DR1IP205),
         veg_exc_sta = sum(veg_dg, veg_ro, veg_oth),
         fruit_exc_juice = sum(DR1I_F_CITMLB, DR1I_F_OTHER),
         pf_pm = sum(DR1I_PF_CUREDMEAT, DR1I_PF_ORGAN),
         pf_seafood = sum(DR1I_PF_SEAFD_HI, DR1I_PF_SEAFD_LOW),
         leg_tot = sum(pf_leg, pf_soy),
         pf_animal = sum(DR1I_PF_MPS_TOTAL, pf_egg),
         pf_plant = sum(pf_leg, pf_ns, pf_soy)) %>%
  ungroup()

# create soy milk category
foods_day1_2 <- foods_day1_1 %>%
  mutate(dairy_soy = ifelse(str_detect(DESCRIPTION, "Soy milk") & dairy_tot > 0, dairy_tot, 0),
         dairy_cow = ifelse(str_detect(DESCRIPTION, "Soy milk", negate = TRUE) & dairy_tot > 0, dairy_tot, 0))

# check
foods_day1_2 %>% filter(dairy_tot > 0) %>% select(SEQN, DESCRIPTION, dairy_tot, dairy_soy, dairy_cow)

# day 2
foods_day2_1 <- foods_day2_ %>%
  rowwise() %>%
  rename(sat_fat = DR2ISFAT,
         p_fat = DR2IPFAT,
         sodium = DR2ISODI,
         gr_refined = DR2I_G_REFINED,
         gr_whole = DR2I_G_WHOLE,
         added_sugar = DR2I_ADD_SUGARS,
         fruit_tot = DR2I_F_TOTAL,
         fruit_juice = DR2I_F_JUICE,
         fiber = DR2IFIBE,
         dairy_tot = DR2I_D_TOTAL,
         veg_dg = DR2I_V_DRKGR,
         veg_oth = DR2I_V_OTHER,
         veg_ro = DR2I_V_REDOR_TOTAL,
         veg_sta = DR2I_V_STARCHY_TOTAL,
         veg_leg = DR2I_V_LEGUMES,
         oil = DR2I_OILS,
         pf_egg = DR2I_PF_EGGS,
         pf_ns = DR2I_PF_NUTSDS,
         pf_soy = DR2I_PF_SOY,
         pf_poultry = DR2I_PF_POULT,
         pf_redm = DR2I_PF_MEAT,
         pf_redm_tot = total_redmeat_new,
         pf_poultry_tot = total_poultry_new,
         pf_leg = DR2I_PF_LEGUMES,
         kcal = DR2IKCAL) %>%
  mutate(sea_omega3_fa = sum(DR2IP226, DR2IP205),
         veg_exc_sta = sum(veg_dg, veg_ro, veg_oth),
         fruit_exc_juice = sum(DR2I_F_CITMLB, DR2I_F_OTHER),
         pf_pm = sum(DR2I_PF_CUREDMEAT, DR2I_PF_ORGAN),
         pf_seafood = sum(DR2I_PF_SEAFD_HI, DR2I_PF_SEAFD_LOW),
         leg_tot = sum(pf_leg, pf_soy),
         pf_animal = sum(DR2I_PF_MPS_TOTAL, pf_egg),
         pf_plant = sum(pf_leg, pf_ns, pf_soy)) %>%
  ungroup()

# create soy milk category
foods_day2_2 <- foods_day2_1 %>%
  mutate(dairy_soy = ifelse(str_detect(DESCRIPTION, "Soy milk") & dairy_tot > 0, dairy_tot, 0),
         dairy_cow = ifelse(str_detect(DESCRIPTION, "Soy milk", negate = TRUE) & dairy_tot > 0, dairy_tot, 0))

# check
foods_day2_2 %>% filter(dairy_tot > 0) %>% select(SEQN, DESCRIPTION, dairy_tot, dairy_soy, dairy_cow)

# built 2021-2023 FPED food-level files, needed for daily totals in Step 3
write_rds(foods_l1_whole, "data_inputs/DIET/dietary_intake/DATA/clean_data/fped_dr1iff_L_built_1723.rds")
write_rds(foods_l2_whole, "data_inputs/DIET/dietary_intake/DATA/clean_data/fped_dr2iff_L_built_1723.rds")

# export foods day 1 and day 2 for later use
write_rds(foods_day1_2, "data_inputs/DIET/dietary_intake/DATA/clean_data/foods_day1_clean_1723.rds")
write_rds(foods_day2_2, "data_inputs/DIET/dietary_intake/DATA/clean_data/foods_day2_clean_1723.rds")

#' 
#' #### Step 3: Clean the food and nutrient intake (summary) datasets {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

rm(list=setdiff(ls(), c("foods_day1_2", "foods_day2_2")))

# QUICKLY HANDLE MEAT
meat_sum_day1 <- 
  foods_day1_2 %>% 
  group_by(SEQN) %>% 
  summarise(pf_redm_tot_1 = sum(pf_redm_tot),
            pf_poultry_tot_1 = sum(pf_poultry_tot))

meat_sum_day2 <- 
  foods_day2_2 %>% 
  group_by(SEQN) %>% 
  summarise(pf_redm_tot_2 = sum(pf_redm_tot),
            pf_poultry_tot_2 = sum(pf_poultry_tot))

#OW EDIT - Section Begin

raw <- "data_inputs/DIET/dietary_intake/DATA/raw_data/"
check_names <- function(a, b) {
  cat("In first but not second:\n");  print(setdiff(names(a), names(b)))
  cat("In second but not first:\n");  print(setdiff(names(b), names(a)))
}

demo_vars <- c("SEQN", "RIAGENDR", "RIDRETH1", "DMDEDUC2", "INDFMPIR", "RIDAGEYR")

# ---- P cycle (2017-2020) ----
demo_p <- read_xpt(paste0(raw, "P_DEMO.xpt")) %>%
  select(all_of(demo_vars), any_of(c("SDMVPSU", "SDMVSTRA")))

fped_p1 <- read_sas(paste0(raw, "fped_dr1tot_1720.sas7bdat"))   
fped_p2 <- read_sas(paste0(raw, "fped_dr2tot_1720.sas7bdat"))   
fped_p  <- left_join(fped_p1, fped_p2)

nutrient_p1 <- read_xpt(paste0(raw, "P_DR1TOT.xpt"))
nutrient_p2 <- read_xpt(paste0(raw, "P_DR2TOT.xpt"))
nutrient_p  <- full_join(nutrient_p1, nutrient_p2)

nhanes_p <- fped_p %>%
  left_join(nutrient_p) %>%
  left_join(demo_p) %>%
  # pre-pandemic dietary weights have a "PP" suffix; give them the usual names
  rename(any_of(c(WTDRD1 = "WTDRD1PP", WTDR2D = "WTDR2DPP"))) %>%
  mutate(nhanes_cycle = "2017-2020")

# ---- L cycle (2021-2023) ----
demo_l <- read_xpt(paste0(raw, "DEMO_L.xpt")) %>%
  select(all_of(demo_vars), any_of(c("SDMVPSU", "SDMVSTRA")))

# FPED daily totals for 2021-2023: sum each person's food-level FPED amounts
clean <- "data_inputs/DIET/dietary_intake/DATA/clean_data/"

fped_l1 <- read_rds(paste0(clean, "fped_dr1iff_L_built_1723.rds")) %>%
  group_by(SEQN) %>%
  summarise(across(starts_with("DR1I_"), ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
  rename_with(~ sub("^DR1I_", "DR1T_", .x), starts_with("DR1I_"))

fped_l2 <- read_rds(paste0(clean, "fped_dr2iff_L_built_1723.rds")) %>%
  group_by(SEQN) %>%
  summarise(across(starts_with("DR2I_"), ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
  rename_with(~ sub("^DR2I_", "DR2T_", .x), starts_with("DR2I_"))

fped_l <- full_join(fped_l1, fped_l2, by = "SEQN")

nutrient_l1 <- read_xpt(paste0(raw, "DR1TOT_L.xpt"))
nutrient_l2 <- read_xpt(paste0(raw, "DR2TOT_L.xpt"))
nutrient_l  <- full_join(nutrient_l1, nutrient_l2)

# start from the NHANES file so every 2021-2023 participant is kept
nhanes_l <- nutrient_l %>%
  left_join(fped_l, by = "SEQN") %>%
  left_join(demo_l, by = "SEQN") %>%
  mutate(nhanes_cycle = "2021-2023")

# The original renamed DR1TWSZ/DR2TWSZ for 2017-2018 only. Check whether
# the P and L files differ on these (or any other) names, and rename if needed.
any(nhanes_p$SEQN %in% nhanes_l$SEQN)          # should now be FALSE

# FPED column names should match the 2017-2020 file
check_names(fped_p %>% select(starts_with("DR1T_"), starts_with("DR2T_")),
            fped_l %>% select(starts_with("DR1T_"), starts_with("DR2T_")))

check_names(nhanes_p, nhanes_l)   
# TODO look at output --> 10/10/26 "RIDRETH3" in nhanes_p but not nhanes_l; 
# detailed race/ethnicity variable that includes non-Hispanic Asian as its own group; code builds race from RIDETH1, this isn't needed
# Drop RIDRETH3
nhanes_p <- nhanes_p %>% select(-any_of("RIDRETH3"))   

# combine the two NHANES datasets
nhanes_comb <- bind_rows(nhanes_p, nhanes_l)

# check the weights and design variables came through for both cycles
nhanes_comb %>%
  group_by(nhanes_cycle) %>%
  summarise(n = n(),
            missing_WTDRD1 = sum(is.na(WTDRD1)),
            missing_PSU = sum(is.na(SDMVPSU)))

#OW Edit - Section End

# combine with meat
nhanes_comb1 <- left_join(nhanes_comb, meat_sum_day1, by = "SEQN") %>% left_join(meat_sum_day2, by = "SEQN")

# create dairy variables
dairy_day1 <-
  foods_day1_2 %>% 
  group_by(SEQN) %>% 
  summarise(dairy_cow_1 = sum(dairy_cow),
            dairy_soy_1 = sum(dairy_soy))

dairy_day2 <-
  foods_day2_2 %>% 
  group_by(SEQN) %>% 
  summarise(dairy_cow_2 = sum(dairy_cow),
            dairy_soy_2 = sum(dairy_soy))

# merge with nhanes
dairy_bothdays <- full_join(dairy_day1, dairy_day2)

nhanes_comb2 <- nhanes_comb1 %>% left_join(dairy_bothdays, by = "SEQN")


#' 
#' #### Step 4: Construct dietary factors {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

nhanes_comb3 <-
  nhanes_comb2 %>% 
  rename(kcal_1 = DR1TKCAL,
         kcal_2 = DR2TKCAL,
         
         sat_fat_1 = DR1TSFAT,
         sat_fat_2 = DR2TSFAT,
         
         sodium_1 = DR1TSODI,
         sodium_2 = DR2TSODI,
         
         gr_refined_1 = DR1T_G_REFINED,
         gr_refined_2 = DR2T_G_REFINED,
         
         gr_whole_1 = DR1T_G_WHOLE,
         gr_whole_2 = DR2T_G_WHOLE,
         
         added_sugar_1 = DR1T_ADD_SUGARS,
         added_sugar_2 = DR2T_ADD_SUGARS,
         
         fruit_tot_1 = DR1T_F_TOTAL,
         fruit_tot_2 = DR2T_F_TOTAL,
         
         fruit_juice_1 = DR1T_F_JUICE,
         fruit_juice_2 = DR2T_F_JUICE,
         
         fiber_1 = DR1TFIBE,
         fiber_2 = DR2TFIBE,
         
         dairy_tot_1 = DR1T_D_TOTAL,
         dairy_tot_2 = DR2T_D_TOTAL,
         
         veg_dg_1 = DR1T_V_DRKGR,
         veg_dg_2 = DR2T_V_DRKGR,
         
         veg_oth_1 = DR1T_V_OTHER,
         veg_oth_2 = DR2T_V_OTHER,
         
         veg_ro_1 = DR1T_V_REDOR_TOTAL,
         veg_ro_2 = DR2T_V_REDOR_TOTAL,
         
         veg_sta_1 = DR1T_V_STARCHY_TOTAL,
         veg_sta_2 = DR2T_V_STARCHY_TOTAL,
         
         # Beans, peas, and lentils  (legumes) computed as vegetables (cup eq.) 
         veg_leg_1 = DR1T_V_LEGUMES,
         veg_leg_2 = DR2T_V_LEGUMES,
         
         oil_1 = DR1T_OILS,
         oil_2 = DR2T_OILS,
         
         pf_egg_1 = DR1T_PF_EGGS,
         pf_egg_2 = DR2T_PF_EGGS,
         
         pf_ns_1 = DR1T_PF_NUTSDS,
         pf_ns_2 = DR2T_PF_NUTSDS,
         
         # soy only
         # Soy products, excluding calcium fortified soy milk (soymilk) 
         # and raw soybeans products (oz. eq.) 
         pf_soy_1 = DR1T_PF_SOY,
         pf_soy_2 = DR2T_PF_SOY,
         
         pf_poultry_1 = DR1T_PF_POULT,
         pf_poultry_2 = DR2T_PF_POULT,
         
         pf_redm_1 = DR1T_PF_MEAT,
         pf_redm_2 = DR2T_PF_MEAT,
         
         pf_pm_1 = DR1T_PF_CUREDMEAT,
         pf_pm_2 = DR2T_PF_CUREDMEAT,
         
         pf_organ_1 = DR1T_PF_ORGAN,
         pf_organ_2 = DR2T_PF_ORGAN,
         
         # Beans and Peas (legumes) computed as protein foods (oz. eq.) 
         pf_leg_1 = DR1T_PF_LEGUMES,
         pf_leg_2 = DR2T_PF_LEGUMES) %>% 
  
  rowwise() %>% 
  
  mutate(sea_omega3_fa_1 = sum(DR1TP226, DR1TP205),
         sea_omega3_fa_2 = sum(DR2TP226, DR2TP205),
         
         veg_exc_sta_1 = sum(veg_dg_1, veg_ro_1, veg_oth_1),
         veg_exc_sta_2 = sum(veg_dg_2, veg_ro_2, veg_oth_2),
         
         fruit_exc_juice_1 = sum(DR1T_F_CITMLB, DR1T_F_OTHER),
         fruit_exc_juice_2 = sum(DR2T_F_CITMLB, DR2T_F_OTHER),
         
         # pf_redm_tot_1 = sum(),
         # pf_redm_tot_2 = sum(),
         # 
         # pf_poultry_tot_1 = sum(),
         # pf_poultry_tot_2 = sum(),
         
         pufa_energy_1 = ((DR1TPFAT * 9) / kcal_1) * 100,
         pufa_energy_2 = ((DR2TPFAT * 9) / kcal_2) * 100,
         
         sfat_energy_1 = ((sat_fat_1 * 9) / kcal_1) * 100,
         sfat_energy_2 = ((sat_fat_2 * 9) / kcal_2) * 100,
         
         pf_seafood_1 = sum(DR1T_PF_SEAFD_HI, DR1T_PF_SEAFD_LOW),
         pf_seafood_2 = sum(DR2T_PF_SEAFD_HI, DR2T_PF_SEAFD_LOW),
         
         # includes legumes and soy foods
         leg_tot_1 = sum(pf_leg_1, pf_soy_1),
         leg_tot_2 = sum(pf_leg_2, pf_soy_2),
         
         pf_animal_1 = sum(DR1T_PF_MPS_TOTAL, pf_egg_1),
         pf_animal_2 = sum(DR2T_PF_MPS_TOTAL, pf_egg_2),
         
         pf_plant_1 = sum(pf_leg_1, pf_ns_1, pf_soy_1),
         pf_plant_2 = sum(pf_leg_2, pf_ns_2, pf_soy_2)
  )

# select the variables we need - OW EDIT 10/10/26 added "nhanes_cycle"
nhanes_comb4 <- nhanes_comb3 %>% select(SEQN, nhanes_cycle, RIAGENDR, RIDRETH1, DMDEDUC2,
                                        INDFMPIR, RIDAGEYR, SDMVPSU, SDMVSTRA,
                                        WTDRD1, WTDR2D, DR1DRSTZ, DR2DRSTZ, 
                                        DRDINT, ends_with("_1"), ends_with("_2")) %>% 
  ungroup() # stop using rowwise


#' 
#' #### Step 5: Create sociodemographic subgroups {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# OW EDIT - SECTIon BEGIN

# TODO confirm this against the NCHS analytic guidance for August 2021-August 2023.
yrs_p <- 3.2
yrs_l <- 2.0

nhanes_comb5 <- nhanes_comb4 %>% mutate(
  female = ifelse(RIAGENDR == 2, 1, 0),
  sex = ifelse(female == 1, 1, 2),
  race = recode(RIDRETH1,
                `3` = 1,
                `4` = 2,
                `1` = 3,
                `2` = 3,
                `5` = 4),
  age = case_when(RIDAGEYR >= 20 & RIDAGEYR < 35 ~ 1,
                  RIDAGEYR >= 35 & RIDAGEYR < 45 ~ 2,
                  RIDAGEYR >= 45 & RIDAGEYR < 55 ~ 3,
                  RIDAGEYR >= 55 & RIDAGEYR < 65 ~ 4,
                  RIDAGEYR >= 65 & RIDAGEYR < 75 ~ 5,
                  RIDAGEYR >= 75 ~ 6),
  # combined day-1 weight across the two cycles
  wtnew = case_when(nhanes_cycle == "2017-2020" ~ WTDRD1 * yrs_p / (yrs_p + yrs_l),
                    nhanes_cycle == "2021-2023" ~ WTDRD1 * yrs_l / (yrs_p + yrs_l)))


  #check new weights; missing_wtnew should be 0; two sum_wtnew values should be 3.2:2 
  nhanes_comb5 %>%
    group_by(nhanes_cycle) %>%
    summarise(sum_wtnew = sum(wtnew), missing_wtnew = sum(is.na(wtnew)))

# OW EDIT - SECTION END

#' 
#' #### Step 6: Create averages of dietary factors for Day 1 and Day 2 {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

nhanes_comb6 <- nhanes_comb5 %>%
  rowwise() %>%
  mutate(kcal = mean(c(kcal_1, kcal_2), na.rm = TRUE),
         sat_fat = mean(c(sat_fat_1, sat_fat_2), na.rm = TRUE),
         sodium = mean(c(sodium_1, sodium_2), na.rm = TRUE),
         gr_refined = mean(c(gr_refined_1, gr_refined_2), na.rm = TRUE),
         gr_whole = mean(c(gr_whole_1, gr_whole_2), na.rm = TRUE),
         added_sugar = mean(c(added_sugar_1, added_sugar_2), na.rm = TRUE),
         fruit_tot = mean(c(fruit_tot_1, fruit_tot_2), na.rm = TRUE),
         fruit_exc_juice = mean(c(fruit_exc_juice_1, fruit_exc_juice_2), na.rm = TRUE),
         fruit_juice = mean(c(fruit_juice_1, fruit_juice_2), na.rm = TRUE),
         fiber = mean(c(fiber_1, fiber_2), na.rm = TRUE),
         dairy_tot = mean(c(dairy_tot_1, dairy_tot_2), na.rm = TRUE),
         dairy_cow = mean(c(dairy_cow_1, dairy_cow_2), na.rm = TRUE),
         dairy_soy = mean(c(dairy_soy_1, dairy_soy_2), na.rm = TRUE),
         veg_dg = mean(c(veg_dg_1, veg_dg_2), na.rm = TRUE),
         veg_oth = mean(c(veg_oth_1, veg_oth_2), na.rm = TRUE),
         veg_ro = mean(c(veg_ro_1, veg_ro_2), na.rm = TRUE),
         veg_sta = mean(c(veg_sta_1, veg_sta_2), na.rm = TRUE),
         veg_leg = mean(c(veg_leg_1, veg_leg_2), na.rm = TRUE),
         veg_exc_sta = mean(c(veg_exc_sta_1, veg_exc_sta_2), na.rm = TRUE),
         oil = mean(c(oil_1, oil_2), na.rm = TRUE),
         pf_egg = mean(c(pf_egg_1, pf_egg_2), na.rm = TRUE),
         pf_ns = mean(c(pf_ns_1, pf_ns_2), na.rm = TRUE),
         pf_soy = mean(c(pf_soy_1, pf_soy_2), na.rm = TRUE),
         pf_poultry = mean(c(pf_poultry_1, pf_poultry_2), na.rm = TRUE),
         pf_poultry_tot = mean(c(pf_poultry_tot_1, pf_poultry_tot_2), na.rm = TRUE),
         pf_pm = mean(c(pf_pm_1, pf_pm_2), na.rm = TRUE),
         pf_redm = mean(c(pf_redm_1, pf_redm_2), na.rm = TRUE),
         pf_redm_tot = mean(c(pf_redm_tot_1, pf_redm_tot_2), na.rm = TRUE),
         pf_organ = mean(c(pf_organ_1, pf_organ_2), na.rm = TRUE),
         pf_leg = mean(c(pf_leg_1, pf_leg_2), na.rm = TRUE),
         sea_omega3_fa = mean(c(sea_omega3_fa_1, sea_omega3_fa_2), na.rm = TRUE),
         pufa_energy = mean(c(pufa_energy_1, pufa_energy_2), na.rm = TRUE),
         sfat_energy = mean(c(sfat_energy_1, sfat_energy_2), na.rm = TRUE),
         pf_seafood = mean(c(pf_seafood_1, pf_seafood_2), na.rm = TRUE),
         leg_tot = mean(c(leg_tot_1, leg_tot_2), na.rm = TRUE),
         pf_animal = mean(c(pf_animal_1, pf_animal_2), na.rm = TRUE),
         pf_plant = mean(c(pf_plant_1, pf_plant_2), na.rm = TRUE))

# get rid of NaN
nhanes_comb6[nhanes_comb6 == "NaN"] <- NA

# ungroup
nhanes_comb7 <- nhanes_comb6 %>% ungroup()

# Merge with subgroup file
subgroups <- read_csv("data_inputs/OTHER/labels/DATA/population_subgroups_48_060923_FINAL.csv")

nhanes_comb8 <-
  nhanes_comb7 %>% 
  left_join(subgroups, by = c("age" = "Age", 
                              "sex" = "Sex", 
                              "race" = "Race"))

# create final dataset
nhanes_final <- nhanes_comb8

# look at meat variables
nhanes_final %>%
  select(SEQN, starts_with(c("pf_redm", "pf_poultry", "pf_pm", "pf_organ"))) %>%
  mutate(sumtot = (pf_redm + pf_poultry + pf_pm + pf_organ == pf_redm_tot + pf_poultry_tot),
         sum1 = (pf_redm_1 + pf_poultry_1 + pf_pm_1 + pf_organ_1 == pf_redm_tot_1 + pf_poultry_tot_1),
         sum2 = (pf_redm_2 + pf_poultry_2 + pf_pm_2 + pf_organ_2 == pf_redm_tot_2 + pf_poultry_tot_2))

nhanes_final %>%
  select(SEQN, starts_with(c("pf_redm", "pf_poultry", "pf_pm", "pf_organ"))) %>%
  mutate(sum1 = (pf_redm + pf_poultry + pf_pm + pf_organ == pf_redm_tot + pf_poultry_tot)) %>%
  filter(sum1 == "FALSE")

# look at day 1
nhanes_final %>%
  rowwise() %>%
  select(SEQN, pf_redm_1, pf_poultry_1, pf_pm_1, pf_organ_1, pf_redm_tot_1, pf_poultry_tot_1) %>%
  mutate(sum1 = round(sum(pf_redm_1, pf_poultry_1, pf_pm_1, pf_organ_1), digits = 3),
         sum2 = round(sum(pf_redm_tot_1, pf_poultry_tot_1), digits = 3),
         my_test = (sum1 == sum2)) %>%
  filter(my_test == "FALSE") %>%
  mutate(my_subtract = sum2 - sum1) %>%
  filter(my_subtract < -0.05 | my_subtract > 0.05) # not bad

# look at day2
nhanes_final %>%
  rowwise() %>%
  select(SEQN, pf_redm_2, pf_poultry_2, pf_pm_2, pf_organ_2, pf_redm_tot_2, pf_poultry_tot_2) %>%
  mutate(sum1 = round(sum(pf_redm_2, pf_poultry_2, pf_pm_2, pf_organ_2), digits = 3),
         sum2 = round(sum(pf_redm_tot_2, pf_poultry_tot_2), digits = 3),
         my_test = (sum1 == sum2)) %>%
  filter(my_test == "FALSE") %>%
  mutate(my_subtract = sum2 - sum1) %>%
  filter(my_subtract < -0.05 | my_subtract > 0.05) # not bad

#Check - alternative way
nhanes_final %>%
  mutate(gap = (pf_redm + pf_poultry + pf_pm + pf_organ) -
           (pf_redm_tot + pf_poultry_tot)) %>%
  group_by(nhanes_cycle) %>%
  summarise(people  = sum(!is.na(gap)),
            off     = sum(abs(gap) > 0.05, na.rm = TRUE),
            largest = max(abs(gap), na.rm = TRUE))    #Essentially a pas; one person in 2017-2020 is off by 1.92 oz-eq; moving on

#' 
#' #### Step 7: Examine cleaned NHANES data {#step-seven} {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# check missing
summary(nhanes_final)

# check for outliers

# kcal < 500
nhanes_final %>% filter(kcal_1 < 500) %>% nrow()  #233 - OW EDIT 272
nhanes_final %>% filter(kcal_2 < 500) %>% nrow()  #301 - OW EDIT 343

# kcal > 3500
nhanes_final %>% filter(kcal_1 > 3500) %>% nrow()  #1028 - OW EDIT 1185
nhanes_final %>% filter(kcal_2 > 3500) %>% nrow()  #588 - OW EDIT 791

# do not remove because I will filter out 
# dietary recalls that are not valid later

# diet recall status
table(nhanes_final$DR1DRSTZ, useNA = "always") 
table(nhanes_final$DR2DRSTZ, useNA = "always") 

# first, create inAnalysis variable
nhanes_final1 <- nhanes_final %>% 
  rowwise() %>% 
  mutate(
    # Define sub-population of interest: 
    # Adults aged 20+ with 1 or 2 days of reliable dietary recalls
    
    reliable_yes = ifelse((DRDINT == 1 & DR1DRSTZ == 1) | (DRDINT == 2 & DR1DRSTZ == 1 & DR2DRSTZ == 1), 1, 0),
    
    inAnalysis = (!(is.na(subgroup)) & reliable_yes == 1), # if subgroup ISN'T missing and reliable data
    
    # Change NAs to 0s, otherwise svydesign function below won't run
    wtnew = ifelse(is.na(wtnew), 0, wtnew),
    SDMVPSU = ifelse(is.na(SDMVPSU), 0, SDMVPSU),
    SDMVSTRA = ifelse(is.na(SDMVSTRA), 0, SDMVSTRA)
  )

# check new survey weight
nhanes_final1 %>% select(SEQN, wtnew, SDMVPSU, SDMVSTRA, inAnalysis) # looks good

#alternative check
nhanes_final1 %>%
  ungroup() %>%
  group_by(nhanes_cycle) %>%
  summarise(people         = n(),
            in_analysis    = sum(inAnalysis),
            missing_wtnew  = sum(is.na(wtnew)),
            pop_total_mil  = sum(wtnew) / 1e6,
            pop_adults_mil = sum(wtnew[inAnalysis]) / 1e6) %>%
  as.data.frame()   #none missing_wtnew

# export
write_rds(nhanes_final1,
          "data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_clean.rds")

# =============================================================================
# NEW CHUNK (add after Step 7): grocery proportion of intake (pro_gro)
# Needed only for the env-eco-soc models. Replaces the old
# "..._bysource_02-03-2025.csv" input, whose code is not in the manual.
# This is a survey-weighted point estimate from unadjusted intake, so it
# approximates the original method.
# =============================================================================
source("code/version_date.R")

foods_day1_2  <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/foods_day1_clean_1723.rds")
foods_day2_2  <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/foods_day2_clean_1723.rds")
nhanes_final1 <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_clean.rds")

diet_vars <- read_csv("data_inputs/OTHER/labels/DATA/dietary_factors_010424_FINAL.csv") %>%
  pull(Food_group)

# food groups that exist at the individual-food level
food_vars <- intersect(diet_vars, names(foods_day1_2))

# total intake from each source, per person, both days together
by_source <- bind_rows(
  foods_day1_2 %>% select(SEQN, foodsource, all_of(food_vars)),
  foods_day2_2 %>% select(SEQN, foodsource, all_of(food_vars))) %>%
  group_by(SEQN, foodsource) %>%
  summarise(across(all_of(food_vars), ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
  pivot_longer(all_of(food_vars), names_to = "food", values_to = "amount") %>%
  pivot_wider(names_from = foodsource, values_from = amount, values_fill = 0)

# weighted proportion of each food group's intake that came from grocery stores
grocery_proportions <- by_source %>%
  left_join(nhanes_final1 %>% select(SEQN, subgroup, wtnew, inAnalysis), by = "SEQN") %>%
  filter(inAnalysis) %>%
  group_by(subgroup, food) %>%
  summarise(pro_gro = sum(wtnew * Grocery) / sum(wtnew * (Grocery + Other)),
            .groups = "drop") %>%
  mutate(pro_gro = ifelse(is.nan(pro_gro), NA, pro_gro),
         subgroup = as.character(subgroup))   # 02 joins on character subgroup

# check: proportions between 0 and 1, and 48 subgroups per food
summary(grocery_proportions$pro_gro)
grocery_proportions %>% count(food)

write_csv(grocery_proportions,
          dated("data_inputs/DIET/dietary_intake/DATA/output_data/NHANES_1723_pro_gro"))

# SSB is not a column in foods_day1_2. If you need its proportion, repeat the
# calculation with foods_day1_ssb_1723.rds / foods_day2_ssb_1723.rds (grams).



#' 
#' Finally, the cleaned dataset is exported to use later.
#' 
#' ## Create Sugar Sweetened Beverage (SSB) Variables
#' 
#' Now we must separately deal with the beverage data in NHANES. Because SSB can be defined many different ways, there is no "SSB" variable that comes with the NHANES dataset. We must use the raw data to create our own. Our goal is to create SSB variables that we can use in our analysis.
#' 
#' ### Import and Merge Data Inputs
#' 
#' Set up the working directory.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# OW EDIT - SECTION BEGIN

rm(list = ls())
library(tidyverse)
library(readxl)
library(haven)

raw <- "data_inputs/DIET/dietary_intake/DATA/raw_data/"
wweia_codes <- paste0(raw, "WWEIA category codes.xlsx")   # NEW: file path used below

# ---- WWEIA food categories by FNDDS food code ------------------------------
wweia_p <- read_xlsx(paste0(raw, "WWEIA1720_foodcat_FNDDS.xlsx"))
wweia_l <- read_xlsx(paste0(raw, "WWEIA2123_foodcat_FNDDS.xlsx"))

# ---- WWEIA category groupings (GL1-GL3) used to identify SSBs --------------
gl1  <- read_xlsx(wweia_codes, sheet = "GL1")
gl2  <- read_xlsx(wweia_codes, sheet = "GL2")
gl2b <- read_xlsx(wweia_codes, sheet = "GL2b")
gl3  <- read_xlsx(wweia_codes, sheet = "GL3")

# ---- Mapping from WWEIA categories to the GL groupings ---------------------
map <- read_xlsx(wweia_codes, sheet = "Mapping")

# NEW: WWEIA categories introduced with FNDDS 2021-2023 (some also appear in the
# 2017-2020 category file) are not in the Mapping sheet. Each copies the GL
# mapping of the existing category it most resembles. None is an SSB category
# (GL1 151-156), so this only stops them coming out as NA.
new_categories <- tribble(
  ~category_number, ~copy_from,
  1902, 1404,   # Plant-based milk               <- Milk substitutes
  1904, 1820,   # Plant-based yogurt             <- Yogurt, regular
  3740, 3703,   # Deli and cured meat sandwiches <- Frankfurter sandwiches
  3742, 3704,   # Meat and BBQ sandwiches        <- Chicken fillet sandwiches
  3744, 3720,   # Vegetable sandwiches/burgers   <- Cheese sandwiches
  3804, 3802,   # Soups, broth-based             <- Soups
  3806, 3802,   # Soups, cream-based             <- Soups
  3808, 3802,   # Ramen and Asian broth soups    <- Soups
  9007, 9008    # Baby food: mixtures            <- Baby food: meat and dinners
)

new_rows <- new_categories %>%
  left_join(map, by = c("copy_from" = "category_number")) %>%
  select(-copy_from)

map <- bind_rows(map, new_rows)

# join the GL groupings (now includes the new categories)
map_join <-
  map %>%
  left_join(gl1) %>%
  left_join(gl2) %>%
  left_join(gl2b) %>%
  left_join(gl3)

# ---- Merge with the WWEIA food-category files ------------------------------
wweia_p_1 <- wweia_p %>% left_join(map_join, by = "category_number")
wweia_l_1 <- wweia_l %>% left_join(map_join, by = "category_number")

# ---- Checks ----------------------------------------------------------------
new_rows %>% filter(if_any(-category_number, is.na))             # should be empty
wweia_p_1 %>% filter(is.na(GL1)) %>% distinct(category_number)   # should be empty
wweia_l_1 %>% filter(is.na(GL1)) %>% distinct(category_number)   # should be empty

# How the new categories were identified (kept for reference; no need to re-run)
# wweia_l %>%
#   filter(category_number %in% new_categories$category_number) %>%
#   distinct(category_number, category_description) %>%
#   arrange(category_number)
#
# wweia_p %>%
#   distinct(category_number, category_description) %>%
#   left_join(map_join %>% select(category_number, GL1, GL2, GL3), by = "category_number") %>%
#   filter(str_detect(category_description,
#                     regex("milk substitute|yogurt|sandwich|soup|baby food", ignore_case = TRUE))) %>%
#   arrange(category_number) %>%
#   print(n = Inf)      

# ---- Added sugar per 100 g by food code (FPED) -----------------------------
# CHANGED: there is no FPED 2021-2023 yet. Both cycles use FPED 2017-2020
# (fped_1720), and the 29 new 2021-2023 food codes take the values of their
# stand-in codes from fped_proxy_codes_2123.csv (same file as Step 2).
fped_100g <- read_sas(paste0(raw, "fped_1720.sas7bdat"))

fped_p_1 <- fped_100g %>%
  rename(food_code = FOODCODE) %>%
  mutate(add_sugars_g = ADD_SUGARS * 4.2) %>%   # 1 tsp = 4.2 g sugar
  select(food_code, add_sugars_g)

# NEW: 2021-2023 = all FPED 2017-2020 codes + the new codes via their stand-ins
proxy <- read_csv(paste0(raw, "fped_proxy_codes_2123.csv"), show_col_types = FALSE)

fped_l_1 <- bind_rows(
  fped_p_1,
  proxy %>%
    select(food_code = new_code, proxy_code) %>%
    left_join(fped_p_1, by = c("proxy_code" = "food_code")) %>%
    select(food_code, add_sugars_g))

# NEW checks: each food code once; every new code got an added-sugar value
fped_l_1 %>% count(food_code) %>% filter(n > 1) %>% nrow()                          # expect 0
fped_l_1 %>% filter(food_code %in% proxy$new_code, is.na(add_sugars_g)) %>% nrow()  # expect 0

# ---- Individual food data, split by cycle and day ----------------------------
foods_day1 <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/foods_day1_clean_1723.rds")
foods_day2 <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/foods_day2_clean_1723.rds")

nhanes_p_day1 <- foods_day1 %>% filter(nhanes_cycle == "2017-2020")
nhanes_l_day1 <- foods_day1 %>% filter(nhanes_cycle == "2021-2023")
nhanes_p_day2 <- foods_day2 %>% filter(nhanes_cycle == "2017-2020")
nhanes_l_day2 <- foods_day2 %>% filter(nhanes_cycle == "2021-2023")

# ---- WWEIA category + added sugar for each food code -------------------------
merge_p <- left_join(wweia_p_1, fped_p_1, by = "food_code")
merge_l <- left_join(wweia_l_1, fped_l_1, by = "food_code")

nhanes_p_day1_join <- left_join(nhanes_p_day1, merge_p, by = c("DR1IFDCD" = "food_code"))
nhanes_p_day2_join <- left_join(nhanes_p_day2, merge_p, by = c("DR2IFDCD" = "food_code"))
nhanes_l_day1_join <- left_join(nhanes_l_day1, merge_l, by = c("DR1IFDCD" = "food_code"))
nhanes_l_day2_join <- left_join(nhanes_l_day2, merge_l, by = c("DR2IFDCD" = "food_code"))

# ---- SSB indicator: same rule as the original ---------------------------------
# >= 5 g added sugar per 100 g, and WWEIA beverage group GL1 151-156
make_ssb <- function(d) mutate(d, ssb = ifelse(add_sugars_g >= 5 & between(GL1, 151, 156), 1, 0))

day1_final <- bind_rows(
  make_ssb(nhanes_p_day1_join) %>% select(SEQN, DR1ILINE, DR1IFDCD, DESCRIPTION, DR1IGRMS, nhanes_cycle, ssb),
  make_ssb(nhanes_l_day1_join) %>% select(SEQN, DR1ILINE, DR1IFDCD, DESCRIPTION, DR1IGRMS, nhanes_cycle, ssb))

day2_final <- bind_rows(
  make_ssb(nhanes_p_day2_join) %>% select(SEQN, DR2ILINE, DR2IFDCD, DESCRIPTION, DR2IGRMS, nhanes_cycle, ssb),
  make_ssb(nhanes_l_day2_join) %>% select(SEQN, DR2ILINE, DR2IFDCD, DESCRIPTION, DR2IGRMS, nhanes_cycle, ssb))

# ---- Checks -------------------------------------------------------------------
# CHANGED: by cycle and for both days. Expect few or no NA lines.
day1_final %>% group_by(nhanes_cycle) %>%
  summarise(lines = n(), ssb_lines = sum(ssb == 1, na.rm = TRUE), unmatched = sum(is.na(ssb)))
day2_final %>% group_by(nhanes_cycle) %>%
  summarise(lines = n(), ssb_lines = sum(ssb == 1, na.rm = TRUE), unmatched = sum(is.na(ssb)))

# if unmatched > 0, see which foods they are
day1_final %>% filter(is.na(ssb)) %>% count(DR1IFDCD, DESCRIPTION, sort = TRUE)

write_rds(day1_final, "data_inputs/DIET/dietary_intake/DATA/clean_data/foods_day1_ssb_1723.rds")
write_rds(day2_final, "data_inputs/DIET/dietary_intake/DATA/clean_data/foods_day2_ssb_1723.rds")


# OW EDIT - SECTION END


#' 
#' ### Calculate SSB Intake
#' 
#' Now that we know which foodcodes are sugar-sweetened beverages, we want to calculate how much SSB each participant consumed (in grams), per day.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# Day 1
ssb_day1 <- day1_final %>% 
  mutate(ssb = as.character(ssb)) %>% 
  group_by(SEQN, ssb) %>% 
  summarise(grams = sum(DR1IGRMS)) %>% #calculate grams of intake by person
  arrange(SEQN, ssb)

ssb_day1_wide <-
  pivot_wider(ssb_day1,
            id_cols = SEQN,
            names_from = ssb,
            values_from = grams,
            names_prefix = "ssb")

ssb_day1_wide1 <- 
  ssb_day1_wide %>% 
  mutate(ssb1 = ifelse(!is.na(ssb0) & is.na(ssb1), 0, ssb1)) %>% 
  select(SEQN, ssb1) %>% 
  rename(ssb_1 = ssb1)

# Day 2
ssb_day2 <- day2_final %>% 
  mutate(ssb = as.character(ssb)) %>% 
  group_by(SEQN, ssb) %>% 
  summarise(grams = sum(DR2IGRMS)) %>% #calculate grams of intake by person
  arrange(SEQN, ssb)

ssb_day2_wide <-
  pivot_wider(ssb_day2,
              id_cols = SEQN,
              names_from = ssb,
              values_from = grams,
              names_prefix = "ssb")

ssb_day2_wide1 <- 
  ssb_day2_wide %>% 
  mutate(ssb1 = ifelse(!is.na(ssb0) & is.na(ssb1), 0, ssb1)) %>% 
  select(SEQN, ssb1) %>% 
  rename(ssb_2 = ssb1)

# combine
ssb_bothdays <- full_join(ssb_day1_wide1, ssb_day2_wide1, by = "SEQN")


#' 
#' Next, calculate the each participant's average intake across 2 days of intake.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# check
# are there any where both are missing? 
ssb_bothdays %>% filter(is.na(ssb_1) & is.na(ssb_2))
# -- OW EDIT 10/10/26; yes: 268 (217 in 2017-2020, 51 in 2021-2023),
# all children / non-reliable recalls (breastfed infants: breast milk has no grams).
# None are in the analysis sample (adults 20+, reliable day-1 recall).
  
  # unmatched food lines by cycle (from the previous section)
  day1_final %>% group_by(nhanes_cycle) %>% summarise(lines = n(), unmatched = sum(is.na(ssb)))
  
  # which foods are unmatched most often
  day1_final %>% filter(is.na(ssb)) %>% count(DR1IFDCD, DESCRIPTION, sort = TRUE) %>% print(n = 20)
  
  # are the 268 people in the analysis sample (adults 20+, reliable day-1 recall)?
  both_na <- ssb_bothdays %>% filter(is.na(ssb_1) & is.na(ssb_2)) %>% pull(SEQN)
  nhanes_1 %>% ungroup() %>% filter(SEQN %in% both_na) %>%
    count(nhanes_cycle, adult_20plus = RIDAGEYR >= 20, reliable_day1 = DR1DRSTZ == 1)
      

# calculate day1/day2 ssb intake average
ssb_bothdays_1 <-
  ssb_bothdays %>%
  rowwise() %>%
  mutate(ssb = mean(c(ssb_1, ssb_2), na.rm=TRUE))

# get rid of NaN
ssb_bothdays_1[ssb_bothdays_1 == "NaN"] <- NA


#' 
#' Now merge with the main NHANES intake dataset.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# read in clean nhanes dataset
nhanes <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_clean.rds")

# merge
nhanes_1 <- left_join(nhanes, ssb_bothdays_1, by = "SEQN")

# which ones where ssb (in grams) is more than 0 but lower than 10 grams? (maybe a sip?)
nhanes_1 %>% filter(ssb_1 > 0 & ssb_1 < 11) %>% head()
nhanes_1 %>% filter(ssb_2 > 0 & ssb_2 < 11) %>% head()

# look at just one person 
day1_final %>% filter(SEQN == 113450, ssb == 1)   # their SSB line(s) on day 1

# it looks fine


#' 
#' Export.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

write_rds(nhanes_1,
          "data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_incl_ssb_clean.rds")


#' 
#' ## Energy Adjustment
#' 
#' This next section describes the process of conducting energy adjustment.
#' 
#' Energy adjustment is an analytic method by which nutrient and food group intakes are evaluated in relation to total energy intake. Energy adjustment methods are used for two primary reasons:
#' 
#' - They account for the fact that total energy requirements are related to body size, metabolic efficiency, and physical activity, thereby providing a measure of diet composition.
#' - They are useful in mitigating the effects of [glossary term:]measurement error in data collected using self-reported dietary assessment instruments.
#' 
#' One frequently used energy adjustment method is the **residual method**. In this method, the energy-adjusted intake estimate is the residual from a regression model in which total energy intake is the independent variable and absolute nutrient intake is the dependent variable. Thus, the residual is an estimate of nutrient intake uncorrelated with total energy intake and directly related to overall variation in food choice and composition.
#' 
#' You can find more information about this on the NCI website [here](https://dietassessmentprimer.cancer.gov/learn/adjustment.html).
#' 
#' Additionally, you can refer to Willett WC, Howe GR, Kushi LH. Adjustment for total energy intake in epidemiologic studies. Am J Clin Nutr. 1997 Apr;65(4 Suppl):1220S-1228S; discussion 1229S-1231S. doi: 10.1093/ajcn/65.4.1220S. PMID: 9094926.
#' 
#' #### Step 1: Set up workspace {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

rm(list=ls())

# load packages
library(tidyverse)
library(modelr)
library(survey)


#' 
#' #### Step 2: Import and prepare cleaned NHANES dataset  {.unnumbered}
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

nhanes <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_incl_ssb_clean.rds") %>% 
  ungroup() # get rid of rowwise formatting

nhanes1 <- nhanes %>% 
  select(-c(kcal:pf_plant, ssb)) %>%
  relocate(c(wtnew:inAnalysis), .before = fruit_juice_1)

# wide to long
nhanes_long <- pivot_longer(nhanes1, 
                            cols = ends_with(c("_1", "_2")),
                            names_to = "names_temp",
                            values_to = "values_temp")


nhanes_long1 <- nhanes_long %>% separate(names_temp, into=c("name", "day"), sep = "_(?=[^_]+$)")

nhanes_long2 <- nhanes_long1 %>% 
  pivot_wider(names_from = "name", values_from = "values_temp")


#' 
#' #### Step 3: Conduct energy adjustment using the residual method
#' 
#' Calculate the mean calorie intake across all participants and days ("meancalories"), each observation's log(calories), the log of "meancalories", and the log of 2000 kcals.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

nhanes2 <- nhanes_long2 %>% mutate(calories = kcal,
                         meancalories = mean(calories, na.rm = TRUE),
                         log_calories = log(calories),
                         log_meancalories = log(meancalories),
                         log_2000 = log(2000))


#' 
#' There are a few people who have kcal intake = 0, and the log of this value is -Inf. We need to change this to NA so that the function will run.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# 12 people have kcal=0
nhanes2 %>% filter(log_calories == "-Inf" & inAnalysis == "TRUE") %>% head()
nhanes2 %>%
  filter(is.infinite(log_calories), inAnalysis) %>%
  count(nhanes_cycle, day)

# if logcalories is -Inf, change to NA
nhanes3 <- nhanes2 %>% 
  mutate(log_calories = ifelse(log_calories == "-Inf", NA, log_calories)) %>% 
  arrange(SEQN, day)

# check
nhanes3 %>% filter(log_calories == "-Inf" & inAnalysis == "TRUE") #good

# OW EDT -- NOTES
# 12 person-days (adults in analysis) have kcal = 0, e.g. only water that day:
# 2017-2020: 2 on day 1, 4 on day 2; 2021-2023: 5 on day 1, 1 on day 2.
# log(0) = -Inf, so these are set to NA below and left out of the energy adjustment.

#' 
#' Below is a function that we can apply to all dietary factors in order to calculate the residual method for each.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

resid_function <- function(x, y){
  
  dat <- x
  
  dat[["var_tem"]] <- dat[[y]] 
  
  dat1 <- dat %>% mutate(log_var_tem = ifelse(var_tem > 0, log(var_tem), NA))
  
  mod <- lm(log_var_tem ~ log_calories, data = dat1)
  
  a = summary(mod)$coefficients["(Intercept)", "Estimate"]
  b = summary(mod)$coefficients["log_calories", "Estimate"]
  
  dat_new <- dat1 %>% 
    add_residuals(mod) %>% 
    rowwise() %>% 
    mutate(log_cons_var_tem = a + (b * log_2000),
           a_log_var_tem = log_cons_var_tem + resid,
           a_var_tem = ifelse(var_tem == 0, 0,exp(a_log_var_tem)),
           "{y}_adj" := a_var_tem)
  
  dat_new1 <- dat_new %>% arrange(SEQN, day) %>% select(paste0(y, "_adj"))

  print(dat_new1)  
  
}

# test
resid_function(nhanes3, "pf_pm")      
resid_function(nhanes3, "fruit_exc_juice") 
resid_function(nhanes3, "sodium")  


#' 
#' Create a vector of dietary factors we want to use.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

diet_vars <- read_csv("data_inputs/OTHER/labels/DATA/dietary_factors_010424_FINAL.csv") %>%
  select(Food_group) %>%
  unlist() %>%
  as.vector()

nums <- which(variable.names(nhanes3) %in% diet_vars)

new_diet_vars <- variable.names(nhanes3[nums])


#' 
#' Apply the function of all dietary factors of interest.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# create empty list
resid_list <- list()

# loop through all diet factors
for (i in new_diet_vars) {
  
  resid_list[[i]] <- resid_function(nhanes3, i)
  
}


#' 
#' Create a dataset that contains all of the adjusted values, and export.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# nhanes with adjusted vars
nhanes_adj <- nhanes3 %>% 
  cbind(bind_cols(resid_list))

# check a few diet vars
nhanes_adj %>% select(ssb, ssb_adj) %>% head()
nhanes_adj %>% select(fruit_exc_juice, fruit_exc_juice_adj) %>% head()
nhanes_adj %>% select(pf_ns, pf_ns_adj) %>% head()
nhanes_adj %>% select(pf_redm_tot, pf_redm_tot_adj) %>% head()
nhanes_adj %>% select(pf_poultry_tot, pf_poultry_tot_adj) %>% head()

# export data
write_rds(nhanes_adj,
          "data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_adj_clean_long.rds")

write_csv(nhanes_adj,
          "data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_adj_clean_long.csv")


#' 
#' #### Step 4: Calculate average daily intake of adjusted variables
#' 
#' Pivot to wide format, then calculate the average daily intake by taking the mean of Day 1 and Day 2 values.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# pivot to wide
nhanes_adj_wide <- nhanes_adj %>% pivot_wider(id_cols = SEQN:inAnalysis,
                           names_from = day,
                           values_from = ends_with("_adj"))

# calculate averages
nhanes_adj_wide1 <- nhanes_adj_wide %>%
  rowwise() %>%
  mutate(
         # fruits
         fruit_tot_adj = mean(c(fruit_tot_adj_1, fruit_tot_adj_2), na.rm = TRUE),
         fruit_exc_juice_adj = mean(c(fruit_exc_juice_adj_1, fruit_exc_juice_adj_2), na.rm = TRUE),
         fruit_juice_adj = mean(c(fruit_juice_adj_1, fruit_juice_adj_2), na.rm = TRUE),
         
         # vegs
         veg_dg_adj = mean(c(veg_dg_adj_1, veg_dg_adj_2), na.rm = TRUE),
         veg_oth_adj = mean(c(veg_oth_adj_1, veg_oth_adj_2), na.rm = TRUE),
         veg_ro_adj = mean(c(veg_ro_adj_1, veg_ro_adj_2), na.rm = TRUE),
         veg_sta_adj = mean(c(veg_sta_adj_1, veg_sta_adj_2), na.rm = TRUE),
         veg_leg_adj = mean(c(veg_leg_adj_1, veg_leg_adj_2), na.rm = TRUE),
         veg_exc_sta_adj = mean(c(veg_exc_sta_adj_1, veg_exc_sta_adj_2), na.rm = TRUE),
         
         # grains
         gr_refined_adj = mean(c(gr_refined_adj_1, gr_refined_adj_2), na.rm = TRUE),
         gr_whole_adj = mean(c(gr_whole_adj_1, gr_whole_adj_2), na.rm = TRUE),
         
         # plant based proteins
         pf_ns_adj = mean(c(pf_ns_adj_1, pf_ns_adj_2), na.rm = TRUE),
         pf_soy_adj = mean(c(pf_soy_adj_1, pf_soy_adj_2), na.rm = TRUE),
         pf_leg_adj = mean(c(pf_leg_adj_1, pf_leg_adj_2), na.rm = TRUE),
         leg_tot_adj = mean(c(leg_tot_adj_1, leg_tot_adj_2), na.rm = TRUE),
         pf_plant_adj = mean(c(pf_plant_adj_1, pf_plant_adj_2), na.rm = TRUE),
         
         # animal proteins
         pf_egg_adj = mean(c(pf_egg_adj_1, pf_egg_adj_2), na.rm = TRUE),
         pf_seafood_adj = mean(c(pf_seafood_adj_1, pf_seafood_adj_2), na.rm = TRUE),
         pf_poultry_adj = mean(c(pf_poultry_adj_1, pf_poultry_adj_2), na.rm = TRUE),
         pf_poultry_tot_adj = mean(c(pf_poultry_tot_adj_1, pf_poultry_tot_adj_2), na.rm = TRUE),
         pf_pm_adj = mean(c(pf_pm_adj_1, pf_pm_adj_2), na.rm = TRUE),
         pf_redm_adj = mean(c(pf_redm_adj_1, pf_redm_adj_2), na.rm = TRUE),
         pf_redm_tot_adj = mean(c(pf_redm_tot_adj_1, pf_redm_tot_adj_2), na.rm = TRUE),
         pf_animal_adj = mean(c(pf_animal_adj_1, pf_animal_adj_2), na.rm = TRUE),
         
         # ssb
         ssb_adj = mean(c(ssb_adj_1, ssb_adj_2), na.rm=TRUE),
         
         # dairy
         dairy_tot_adj = mean(c(dairy_tot_adj_1, dairy_tot_adj_2), na.rm = TRUE),
         dairy_cow_adj = mean(c(dairy_cow_adj_1, dairy_cow_adj_2), na.rm = TRUE),
         dairy_soy_adj = mean(c(dairy_soy_adj_1, dairy_soy_adj_2), na.rm = TRUE),
         
         # other foods
         oil_adj = mean(c(oil_adj_1, oil_adj_2), na.rm = TRUE),
         sodium_adj = mean(c(sodium_adj_1, sodium_adj_2), na.rm = TRUE),
         added_sugar_adj = mean(c(added_sugar_adj_1, added_sugar_adj_2), na.rm = TRUE),
         
         # other nutrients
         sea_omega3_fa_adj = mean(c(sea_omega3_fa_adj_1, sea_omega3_fa_adj_2), na.rm = TRUE),
         pufa_energy_adj = mean(c(pufa_energy_adj_1, pufa_energy_adj_2), na.rm = TRUE),
         sfat_energy_adj = mean(c(sfat_energy_adj_1, sfat_energy_adj_2), na.rm = TRUE),
         sat_fat_adj = mean(c(sat_fat_adj_1, sat_fat_adj_2), na.rm = TRUE),
         fiber_adj = mean(c(fiber_adj_1, fiber_adj_2), na.rm = TRUE))


#' 
#' Change unit to grams. Use the conversion units from the following file:
#' 
#' - data_inputs/OTHER/unit_conversions/DATA/Unit_conversions_1.4.24.csv
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# calculate food group means in grams
nhanes_adj_wide2 <- nhanes_adj_wide1 %>% 
  rowwise() %>% 
  mutate(veg_dg_adj_grams = veg_dg_adj * 118 ,
         veg_oth_adj_grams = veg_oth_adj * 140,
         veg_ro_adj_grams = veg_ro_adj * 144,
         veg_sta_adj_grams = veg_sta_adj * 134,
         veg_tot_adj_grams = sum(veg_dg_adj_grams, 
                                 veg_oth_adj_grams,
                                 veg_ro_adj_grams,
                                 veg_sta_adj_grams),
         
         gr_refined_adj_grams = gr_refined_adj * 36,
         gr_whole_adj_grams = gr_whole_adj * 51,
         gr_tot_adj_grams = sum(gr_refined_adj_grams,
                                gr_whole_adj_grams),
         
         pf_egg_adj_grams = pf_egg_adj * 50,
         pf_poultry_tot_adj_grams = pf_poultry_tot_adj * 29,
         pf_redm_tot_adj_grams = pf_redm_tot_adj * 31,
         pf_seafood_adj_grams = pf_seafood_adj * 29,
         pf_ns_adj_grams = pf_ns_adj * 15,
         leg_tot_adj_grams = leg_tot_adj * 37,
         pf_tot_adj_grams = sum(pf_egg_adj_grams,
                                pf_poultry_tot_adj_grams,
                                pf_redm_tot_adj_grams,
                                pf_seafood_adj_grams,
                                pf_ns_adj_grams,
                                leg_tot_adj_grams),
         
         fruit_exc_juice_adj_grams = fruit_exc_juice_adj * 152,
         fruit_juice_adj_grams = fruit_juice_adj * 251,
         fruit_tot_adj_grams = sum(fruit_exc_juice_adj_grams,
                                   fruit_juice_adj_grams))

# get rid of NaN
nhanes_adj_wide2[nhanes_adj_wide2 == "NaN"] <- NA


#' 
#' Export.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

write_rds(nhanes_adj_wide2,
          "data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_adj_clean_wide.rds")

write_csv(nhanes_adj_wide2,
          "data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_adj_clean_wide.csv",
          na = "")

#' 
#' ## Calculating Mean and Standard Deviation Using SAS Macros {#sas-macro}
#' 
#' We need to calculate the (i) mean intake and (ii) standard deviation of the mean intake for each dietary factor and demographic subgroup. This can be done using the [NCI Method](https://epi.grants.cancer.gov/diet/usualintakes/method.html) SAS macros.
#' 
#' We use a modified version of the SIMPLE macro, which is a single macro that links 3 NCI macros, the MIXTRAN, DISTRIB, and BRR_PVALUE_CI, to facilitate estimation of usual intake distributions for food and nutrients consumed “nearly-daily.” 
#' 
#' The SIMPLE macro documentation is provided [here](https://osf.io/ytd34/). An updated version of the macro was provided to our team by Hanqi Luo. The publication describing the macro is located [here](https://pubmed.ncbi.nlm.nih.gov/33693802/).
#' 
#' The NCI macro documentation is provided [here](https://epi.grants.cancer.gov/diet/usualintakes/macros_single.html).
#' 
#' I highly recommend you read all of the aforementioned documentation before your proceed.
#' 
#' The SIMPLE macro was modified by Brooke Bell (the person writing this!). She added code to the macro to additionally calculate the standard deviation of the mean intake. The version that she modified is located here:
#' 
#' - data_inputs/DIET/standard_deviations/CODE/macros/simple_macro_v3.4_bmb.sas
#' 
#' This macro is run on the Tufts cluster because it uses a lot of processing power. 
#' 
#' The following sections will describe the data inputs that are used in the macro, and how to run the macro on the cluster.
#' 
#' ### Prepare NHANES Data for SAS Macros
#' 
#' We need to make some minor adjustments to the diet dataset's structure in order to properly use the SAS macro.
#' 
#' First, import the adjusted intake dataset (long format) that was created in the previous section.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

rm(list = ls())

library(tidyverse)
library(fastDummies)

# Import data
nhanes <- read_rds("data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_adj_clean_long.rds")

# only select certain variables
nhanes1 <- nhanes %>% 
  select(SEQN, age, sex, race, subgroup, DRDINT, SDMVPSU, SDMVSTRA, wtnew, reliable_yes, inAnalysis, day, ends_with("adj"))

#' 
#' Then, we need to create a new variable ("subgroup_new") that only has a non-missing subgroup number if that participant's data is reliable (i.e., inAnalysis == TRUE). This essentially changes any subgroup number to NA if the participant's data is unreliable.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

nhanes2 <- nhanes1 %>% 
  mutate(subgroup_new = ifelse(inAnalysis == "TRUE", subgroup, NA),
         inAnalysis_num = ifelse(inAnalysis == "TRUE", 1, 2)) %>% 
  relocate(subgroup_new, .after = subgroup) %>% 
  relocate(inAnalysis_num, .after = inAnalysis)

# check
nhanes2 %>% filter(!(is.na(subgroup)) & !(is.na(subgroup_new))) %>% head()

#' 
#' Next, create dummy variables for the variables "day", "inAnalysis", "subgroup", and "subgroup_new". We utilize the "dummy_cols" function from the "fastDummies" package to do this quickly. You can learn more about this function by running the command "?dummy_cols".
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

nhanes3 <- nhanes2 %>% 
  dummy_cols(select_columns = c("day", "inAnalysis", "inAnalysis_num", "subgroup", "subgroup_new"),
             remove_first_dummy = TRUE) %>% 
  relocate(day_2, .after = day)


#' 
#' We need to remove the rows where a participant's number of days of intake is 1 (DRDINT == 1) and day == 2 (since they don't have any data for this day).
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# check
nhanes3 %>% filter(DRDINT == 1 & day == 2) %>% head()

nhanes4 <- nhanes3 %>% 
  filter(!(DRDINT == 1 & day == 2))
  
# check
nhanes4 %>% filter(is.na(fruit_tot_adj)) %>% head() #good
nhanes4 %>% filter(is.na(fruit_tot_adj) & inAnalysis == "TRUE") %>% head() #good

# OW EDIT - check alternative -- rows with missing adjusted fruit intake, by analysis status
nhanes4 %>% filter(is.na(fruit_tot_adj)) %>% count(inAnalysis)
# NOTE (to fix later): 3 analysed person-days have missing adjusted intake for all
# FPED food groups (fruit_tot_adj, veg_*_adj, gr_*_adj, pf_*_adj, etc.).
# SEQN 130663, 133923, 138671 - all 2021-2023, day 1, kcal = 0 (reliable recall,
# no foods reported, e.g. only plain water).
# Cause: 2021-2023 FPED daily totals were built by summing food lines (Step 3),
# so people with no food lines get NA instead of 0. USDA's 2017-2020 daily-total
# files give 0 for such people, so 2017-2020 is not affected.
# Fix: in Step 3, after nhanes_l is built, set missing DR1T_/DR2T_ FPED columns
# to 0 where DR1DRSTZ / DR2DRSTZ == 1, then re-run 02 from Step 3 onwards.
# Impact for now: negligible - the NCI macro drops these 3 person-days and uses
# those people's other recall day where available.

#' 
#' Need to change poultry variable name because it's too long for SAS (this is why SAS is inferior to R - insert poop emoji).
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

nhanes5 <- nhanes4 %>% 
  rename(poult_tot_adj = pf_poultry_tot_adj)


#' 
#' Export to Box. 
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

write_csv(nhanes5,
          "data_inputs/DIET/dietary_intake/DATA/clean_data/nhanes1723_incl_ssb_adj_clean_long.csv",
          na = "")


#' 
#' Export to the standard_deviations folder.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

write_csv(nhanes5,
          "data_inputs/DIET/standard_deviations/in/nhanes1723_incl_ssb_adj_clean_long.csv",
          na = "")

# OW EDIT - SECTIon BEGIN
# =============================================================================
# Checks on the NCI (SIMPLE macro) input file before sending it to the cluster
# Run after the "Prepare NHANES Data for SAS Macros" section of 02.
# Each check prints a result; the comment says what to expect.
# =============================================================================

rm(list = ls())

library(tidyverse)

# the exact file the SAS program will read
nci_file <- "data_inputs/DIET/standard_deviations/DATA/in/nhanes1723_incl_ssb_adj_clean_long.csv"
d <- read_csv(nci_file, show_col_types = FALSE)

# list of diet variables the macro will run
macro_vars <- read_csv("data_inputs/DIET/standard_deviations/DATA/in/macro_input_LASTING_ALL_VARS.csv",
                       show_col_types = FALSE)

# ---- 1. Structure ------------------------------------------------------------
dim(d)                                   # rows = person-days; about 23,160 + day-2 rows
d %>% count(SEQN, day) %>% filter(n > 1) %>% nrow()   # expect 0: one row per person-day
d %>% filter(DRDINT == 1, day == 2) %>% nrow()        # expect 0: no empty day-2 rows

# columns the prep code creates and the macro uses
needed <- c("SEQN", "age", "sex", "race", "subgroup", "subgroup_new", "DRDINT",
            "SDMVPSU", "SDMVSTRA", "wtnew", "reliable_yes", "inAnalysis",
            "inAnalysis_num", "day", "day_2")
setdiff(needed, names(d))                # expect character(0)

# SAS variable names: max 32 characters, letters/digits/underscore, no leading digit
names(d)[nchar(names(d)) > 32]                       # expect character(0)
names(d)[!grepl("^[A-Za-z_][A-Za-z0-9_]*$", names(d))]  # expect character(0)

# ---- 2. Diet variables the macro will run ------------------------------------
names(macro_vars)                        # find the column listing the variable names
# replace `variable` below with that column's name
macro_var_names <- macro_vars$variable   # TODO column name
setdiff(macro_var_names, names(d))       # expect character(0): every variable exists

# ---- 3. Analysis sample ------------------------------------------------------
an <- d %>% filter(inAnalysis_num == 1)

n_distinct(an$SEQN)                      # adults 20+ with reliable day-1 recall
an %>% filter(is.na(subgroup_new)) %>% nrow()                 # expect 0
range(an$subgroup_new)                                        # expect 1 48
an %>% distinct(SEQN, subgroup_new) %>% count(subgroup_new) %>%
  summarise(smallest = min(n), largest = max(n))              # every subgroup has people
d %>% filter(inAnalysis_num != 1, !is.na(subgroup_new)) %>% nrow()  # expect 0

# ---- 4. Weights and survey design --------------------------------------------
an %>% summarise(missing_wt = sum(is.na(wtnew)), zero_wt = sum(wtnew == 0),
                 missing_psu = sum(is.na(SDMVPSU)), missing_strata = sum(is.na(SDMVSTRA)))
# expect all 0

# a person's weight should be the same on both days
d %>% group_by(SEQN) %>% summarise(k = n_distinct(wtnew)) %>% filter(k > 1) %>% nrow()  # expect 0

# every stratum needs at least 2 PSUs among analysed people (for standard errors)
an %>% distinct(SDMVSTRA, SDMVPSU) %>% count(SDMVSTRA) %>% filter(n < 2)   # expect 0 rows

# strata numbers must not overlap between the two cycles
# (needs nhanes_cycle; if it is not in the file, join it from nhanes1723_clean.rds)
if ("nhanes_cycle" %in% names(d)) {
  d %>% distinct(nhanes_cycle, SDMVSTRA) %>% count(SDMVSTRA) %>% filter(n > 1) %>% nrow()  # expect 0
}

# ---- 5. Intake values --------------------------------------------------------
adj_vars <- names(d)[str_ends(names(d), "_adj")]

an %>%
  summarise(across(all_of(adj_vars),
                   list(missing  = ~ sum(is.na(.x)),
                        negative = ~ sum(.x < 0, na.rm = TRUE),
                        zero_pct = ~ round(100 * mean(.x == 0, na.rm = TRUE), 1),
                        mean     = ~ round(mean(.x, na.rm = TRUE), 2),
                        max      = ~ round(max(.x, na.rm = TRUE), 1)))) %>%
  pivot_longer(everything(), names_to = c("variable", ".value"),
               names_pattern = "(.*_adj)_(.*)") %>%
  print(n = Inf)
# expect: missing small (the 0-kcal days); negative 0;
# zero_pct high for episodically eaten foods (e.g. pf_organ, ssb) and low for
# everyday ones (e.g. sodium, kcal); means in plausible daily units at 2,000 kcal


# OW EDIT - SECTIOn END





#' 
#' ### Fill Out Macro Template
#' 
#' Before running the SIMPLE macro, I **highly** suggest that you read the following documentation:
#' 
#' - data_inputs/DIET/dietary_intake/RESOURCES/SAS MACRO User Guides/SIMPLE_macro_user_manual_10-30-2020.pdf
#'  
#' The Simulating Intake of Micronutrients for Policy Learning and Engagement (SIMPLE) macro is a ‘wrapper’ for the National Cancer Institute MIXTRAN, DISTRIB, and BOXCOX_SURVEY macros to facilitate estimation of usual intake distributions for food and nutrients consumed ‘nearly-daily’.
#' 
#' You must first fill out a CSV file that lists all of the diet variables that you want the SIMPLE macro to run.
#' 
#' If you would like to run all the diet variables that were included in the four-pillar paper analysis, then you can use the following file: 
#' 
#' - data_inputs/DIET/standard_deviations/DATA/in/macro_input_LASTING_ALL_VARS.csv
#' 
#' I will refer you to the above documentation if you want to make any modifications to the input file that already exists.
#' 
#' ### Log In to Tufts HPC
#' 
#' The next step is to actually run the macro on the cluster ("HPC").
#' 
#' The file that you will be running is the following:
#' 
#' - GitHub/LASTING/standard-deviations/cluster_code/Calculate_SD_nci_method_05-19-25_cluster_loop.sas
#' 
#' **Please read the SAS file first before running it on the cluster so that you understand what is happening in the code.**
#' 
#' You should save a new version of the SAS code for your own project, so that you don't accidentally write over the orignial one.
#' 
#' You must first log into the cluster computer via [OnDemand](https://ondemand.pax.tufts.edu/).
#' 
#' See the [Code](index.html#code) section for information on how to gain access to OnDemand, and how to get a GitHub access token.
#' 
#' ### Run SAS Macro {#run-sas-macro}
#' 
#' Once logged in to OnDemand, navigate to /cluster/tufts/lasting/shared/LASTING.
#' 
#' Then, open the terminal.
#' 
#' Type "git pull" into the command prompt.
#' 
#' It will ask you to log into Github with your username and token.
#' 
#' Then, it will start to sync with the most updated version of the LASTING repo.
#' 
#' **NOTE: NEVER use the "git push" command. Just trust me. Ask Fred if you're really curious.**
#' 
#' Then, type "exit" and close the terminal.
#' 
#' Now, navigate to /cluster/tufts/lasting/shared/LASTING/standard-devations/cluster_code.
#' 
#' The batch file you're going to be running is "Run_SDs_cluster.sh".
#' 
#' I also recommend saving a new version of this for your own project. You will also need to edit some of the parameters in the file, such as time requested and email. You can edit the file by clicking the button "Edit". Don't forget to click "Save" when you're done.
#' 
#' Then, open the terminal again.
#' 
#' Type "sbatch Run_SDs_cluster" into the command prompt.
#' 
#' Once you see that the job was submitted, you can exit the terminal.
#' 
#' ### Export Output to Box
#' 
#' When the code is done running, the output is saved to the following folders:
#' 
#' - /cluster/tufts/lasting/shared/model_development/data/outputs/CRA/
#' - /cluster/tufts/lasting/shared/model_development/data/outputs/cost_env/
#' 
#' You will need to use a file transfer software to copy the output files to Box.
#' 
#' Fred and I use [FileZilla](https://filezilla-project.org/), but it looks like Tufts IT recommends [Globus](https://rtguides.it.tufts.edu/hpc/access/globus/index.html)). I'd go with that. Follow IT's instructions on how to set up the connection.
#' 
#' Anyway, using whatever software you decide on, you will simply copy the files to the following Box folder:
#' 
#' - /Box/lasting_aim_3/model development/methods_manual/outputs/intake/
#' 
#' Create a folder named "output_INSERTDATE_ncimethod" and put the files in there.
#' 
#' ### Clean Output from Cluster
#' 
#' Lastly (phew), we need to clean the output to use in the following sections. You will need to update the file path when running this.
#' 
#' First, retrieve all the output file names.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

rm(list=ls())

source("code/version_date.R")

# Specify the directory containing the CSV files
directory <- "outputs/intake/output_101126_ncimethod"

# Get the list of all CSV files in the directory
file_list <- list.files(path = directory, pattern = "*.csv", full.names = TRUE)


#' 
#' Then, import the files and clean.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

# Read each CSV file and store them in a list of data frames
data_list <- lapply(file_list, read_csv)

# Combine all data frames into one data frame
combined_data <- bind_rows(data_list)

# Clean
intake <- combined_data %>% 
  select(note, subgroup_new, N, mean, mean_SE, StdDev) %>% 
  # only select subgroups 1-48
  filter(subgroup_new %in% c(1:48)) %>%
  rename(food = note, 
         subgroup = subgroup_new,
         SE = mean_SE) %>% 
  arrange(subgroup, food)

# fix food name
intake1 <- intake %>% 
  mutate(food = str_remove(food, "_adj$"))

# fix poultry name
intake2 <- intake1 %>% 
  mutate(food = ifelse(food == "poult_tot", "pf_poultry_tot", food))

# for subgroup 0 only
# leave commented out
# write_csv(intake2, 
#           dated("data_inputs/DIET/dietary_intake/DATA/output_data_from_cluster/NHANES_1723_summary_allfoods_adj_bysub_ncimethod"))


#' 
#' Read in two datasets (food labels and % grocery intake) and merge with intake data.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------
# merge with food labels
labels <- read_csv("data_inputs/OTHER/labels/DATA/dietary_factors_010424_FINAL.csv")

labels1 <- labels %>% 
  rename(food = Food_group) %>% 
  relocate(food)

# read in pro_gro from original output
ratio <- read_csv("data_inputs/DIET/dietary_intake/DATA/output_data/NHANES_1723_summary_allfoods_adj_bysub_bysource_02-03-2025.csv") %>% 
  select(subgroup, food, pro_gro) %>% 
  mutate(subgroup = as.character(subgroup))

# join
intake3 <- left_join(intake2, labels1, by = "food") %>% 
  left_join(ratio, by = c("subgroup", "food"))

intake4 <- intake3 %>% 
  relocate(subgroup) %>% 
  rename(food_label = Var_label,
         food_desc = Var_desc) %>% 
  arrange(subgroup, food)


#' 
#' Export.
#' 
## ----results='hide', warning=FALSE, message=FALSE-------

write_csv(intake4, 
          dated("data_inputs/DIET/dietary_intake/DATA/output_data_from_cluster/NHANES_1723_summary_allfoods_adj_bysub_ncimethod"))



