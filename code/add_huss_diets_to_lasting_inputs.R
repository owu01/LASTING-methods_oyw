# =============================================================================
# Add HUSS 2020 (US20) and HUSS 2025 (US25) counterfactual diets to LASTING's
# existing model input file, keeping all other LASTING inputs unchanged
# (NHANES 2015-2018 intake, disease, population, RRs, TMREDs).
#
# Only the CRA uses the new rows (datatype == "Total"). The env-eco-soc model is
# not run in this setup.
# Lines marked # TODO need checking against your files.
# =============================================================================
library(tidyverse)
source("code/version_date.R")   # version_date must match the date on LASTING's model files

model_dir  <- "data_inputs/FINAL/model_data/"                 
input_file <- paste0(model_dir, "input_data_2025-05-20_FINAL.csv")
file.exists(input_file)     # should now be TRUE


inp <- read_csv(input_file, show_col_types = FALSE)

# ---- Column names in LASTING's input file ----------------------------------
names(inp)                     # check the names below against this list
food_col <- "Foodgroup"       
cf_cols  <- c("CF_Mean_Intake", "CF_SE_Intake", "CF_sd_intake")   
setdiff(c(food_col, "diet_pattern", "datatype", cf_cols), names(inp))   # expect character(0)

inp %>% count(diet_pattern, datatype)   # existing patterns; US20/US25 should not be there yet

# ---- Your counterfactual values ----------------------------------------------
# One row per food group x diet pattern, same units as LASTING's
# counterfactual_intake_050724.csv (per day; pf_leg in CUPS, leg_tot in OZ-EQ).
# Columns: food, diet_pattern (US20 / US25), CF_mean_intake, CF_se_intake, CF_sd_intake
cf_new <- read_csv("data_inputs/DIET/counterfactual_intake/DATA/huss_counterfactuals.csv",
                   show_col_types = FALSE) %>%                 
  # chapter 03 converts pf_leg from cups to oz-eq (x 4); do the same here
  mutate(across(c(CF_mean_intake, CF_se_intake, CF_sd_intake),
                ~ ifelse(food == "pf_leg", .x * 4, .x))) %>%
  rename(CF_Mean_Intake = CF_mean_intake,
         CF_SE_Intake   = CF_se_intake,
         CF_sd_intake   = CF_sd_intake)

# ---- Build the new rows from LASTING's "US" rows -----------------------------
# Same subgroups, current intake, TMREDs, etc.; only the counterfactual changes.
template <- inp %>% filter(diet_pattern == "US", datatype == "Total")

new_rows <- map_dfr(c("US20", "US25"), function(p) {
  template %>%
    select(-all_of(cf_cols)) %>%
    mutate(diet_pattern = p,
           diet_label   = ifelse(p == "US20", "Healthy US-Style 2020", "Healthy US-Style 2025")) %>%
    left_join(cf_new %>% filter(diet_pattern == p) %>% select(-diet_pattern),
              by = setNames("food", food_col))
}) %>%
  select(all_of(names(inp)))     # same column order as the original file

# ---- Checks ------------------------------------------------------------------
# 1. CRA risk factors must all have a counterfactual (copy rfvec_cra from 08)
rfvec_cra <- c("dairy_tot", "gr_whole", "pf_ns", "pf_pm", "pf_redm", "pf_seafood",
               "veg_exc_sta", "ssb", "sodium", "fruit_exc_juice", "leg_tot")   # TODO match 08
new_rows %>%
  filter(.data[[food_col]] %in% rfvec_cra, is.na(CF_Mean_Intake)) %>%
  distinct(diet_pattern, .data[[food_col]])            # expect 0 rows

# 2. Same number of rows per pattern as LASTING's US
nrow(template); new_rows %>% count(diet_pattern)       # each n should equal nrow(template)

# 3. Side-by-side with LASTING's US pattern (one subgroup) to spot unit mistakes,
#    e.g. sodium in mg vs g, or legumes in cups vs oz-eq
bind_rows(template, new_rows) %>%
  filter(subgroup_id == first(template$subgroup_id), .data[[food_col]] %in% rfvec_cra) %>%
  select(all_of(food_col), diet_pattern, CF_Mean_Intake) %>%
  pivot_wider(names_from = diet_pattern, values_from = CF_Mean_Intake) %>%
  print(n = Inf)

# ---- Save --------------------------------------------------------------------
# 08 reads input_data_<version_date>.csv; LASTING's _FINAL file stays unchanged
out_file <- dated(paste0(model_dir, "input_data"))
out_file                                              # input_data_2025-05-20.csv

out <- bind_rows(inp %>% filter(!diet_pattern %in% c("US20", "US25")), new_rows)
write_csv(out, out_file)

read_csv(out_file, show_col_types = FALSE) %>% count(diet_pattern, datatype)
