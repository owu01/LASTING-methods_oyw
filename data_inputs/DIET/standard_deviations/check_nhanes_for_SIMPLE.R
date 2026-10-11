# Check that the script-02 output has everything the SIMPLE macro input CSV expects.
# Run in your R project after script 02.
library(readr)

nhanes <- read_csv("C:/GitHub/LASTING-methods_oyw/data_inputs/DIET/standard_deviations/in/nhanes1723_incl_ssb_adj_clean_long.csv")

diet_vars <- c("fruit_exc_juice_adj", "pf_redm_tot_adj", "pf_pm_adj", "pf_poultry_adj",
               "poult_tot_adj", "pf_seafood_adj", "pf_egg_adj", "pf_ns_adj", "leg_tot_adj",
               "dairy_tot_adj", "dairy_cow_adj", "dairy_soy_adj", "ssb_adj", "oil_adj",
               "added_sugar_adj", "sat_fat_adj", "sodium_adj")
design_vars <- c("SEQN", "day", "day_2", "SDMVSTRA", "SDMVPSU", "wtnew",
                 "subgroup_new", paste0("subgroup_new_", 2:48))

# 1. Any required columns missing? (should print character(0))
setdiff(c(diet_vars, design_vars), names(nhanes))

# 2. Diet variables numeric, no missing values?
sapply(nhanes[diet_vars], is.numeric)
colSums(is.na(nhanes[diet_vars]))

# 3. Design checks
table(nhanes$day, nhanes$day_2)               # day 1 -> 0, day 2 -> 1
length(unique(nhanes$SDMVSTRA))               # expect 39 -> nreps = 40
with(nhanes, table(SDMVSTRA, SDMVPSU))        # only stratum 156 should have a PSU 3
sum(is.na(nhanes$wtnew) | nhanes$wtnew <= 0)  # should be 0 after the script 02 filters
table(nhanes$DR1DRSTZ)                        # should be all 1
table(nhanes$DR2DRSTZ[nhanes$day == 2])       # should be all 1
max(table(nhanes$SEQN))                       # should be 2 (one or two rows per person)
range(nhanes$subgroup_new)                    # expect 1 to 48

# 4. People per subgroup (small cells -> unstable SDs / convergence problems)
sort(table(nhanes$subgroup_new[nhanes$day == 1]))

# 5. Proportion of days with zero intake (daily-type variables should be < 5%)
round(colMeans(nhanes[diet_vars] == 0), 3)

# When writing the CSV in script 02, write NAs as blanks so SAS reads columns as numeric:
# write_csv(nhanes, "nhanes1723_incl_ssb_adj_clean_long.csv", na = "")
