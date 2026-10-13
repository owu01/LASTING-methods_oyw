# Check: for each CRA dietary factor and diet pattern, is the counterfactual
# intake MORE or LESS favourable than current intake, subgroup by subgroup?
#
# Why: the CRA sets negative PIFs to 0. Where a pattern moves intake in the
# unhealthy direction (e.g. more red meat, fewer vegetables), the model shows
# zero benefit instead of added disease. This check shows where that happens.
#
# Also flags counterfactuals beyond the TMRED (theoretical minimum risk exposure):
# relative risks are not allowed below 1, so moving past the TMRED (e.g. more
# whole grains than the TMRED) adds no further benefit in the model.
#
# Uses the input file the model read (huss-cra-lasting-inputs branch).
# Updated 10-12-2026.

library(tidyverse)

input_file <- "data_inputs/FINAL/model_data/input_data_2025-05-20.csv"
out_file   <- "outputs/model/Check_counterfactual_direction.csv"

patterns <- c("US20", "US25")

# Direction of benefit for each CRA factor
factors <- tribble(
  ~Foodgroup,        ~label,                      ~healthier_is,
  "fruit_exc_juice", "Fruits",                    "more",
  "veg_exc_sta",     "Vegetables",                "more",
  "leg_tot",         "Beans, peas, and lentils",  "more",
  "gr_whole",        "Whole grains",              "more",
  "pf_ns",           "Nuts and seeds",            "more",
  "pf_seafood",      "Seafood",                   "more",
  "dairy_tot",       "Dairy",                     "more",
  "pf_redm",         "Unprocessed red meat",      "less",
  "pf_pm",           "Processed meat",            "less",
  "ssb",             "Sugar-sweetened beverages", "less",
  "sodium",          "Sodium",                    "less"
)

inp <- read_csv(input_file, show_col_types = FALSE)

d <- inp %>%
  filter(Foodgroup %in% factors$Foodgroup, datatype == "Total",
         diet_pattern %in% patterns) %>%
  select(diet_pattern, subgroup_id, Foodgroup, Intake_unit,
         current = Mean_Intake, cf = CF_Mean_Intake, tmred = TMRED_Mean_Intake) %>%
  left_join(factors, by = "Foodgroup") %>%
  mutate(
    # counterfactual moves intake in the UNHEALTHY direction for this subgroup
    less_favourable = if_else(healthier_is == "more", cf < current, cf > current),
    # counterfactual goes beyond the TMRED (no extra benefit past it)
    beyond_tmred    = if_else(healthier_is == "more", cf > tmred, cf < tmred)
  )

check <- d %>%
  group_by(diet_pattern, label, healthier_is, Intake_unit) %>%
  summarise(counterfactual  = first(cf),
            current_min     = min(current),
            current_median  = median(current),
            current_max     = max(current),
            tmred           = first(tmred),
            subgroups_less_favourable = sum(less_favourable),
            subgroups_total = n(),
            cf_beyond_tmred = first(beyond_tmred),
            .groups = "drop") %>%
  mutate(
    across(c(counterfactual, current_min, current_median, current_max, tmred), ~ round(.x, 2)),
    direction = case_when(
      subgroups_less_favourable == 0               ~ "Healthier for all subgroups",
      subgroups_less_favourable == subgroups_total ~ "LESS HEALTHY for all subgroups",
      TRUE ~ paste0("Less healthy for ", subgroups_less_favourable, " of ",
                    subgroups_total, " subgroups")),
    diet_pattern = factor(diet_pattern, levels = patterns),
    label = factor(label, levels = factors$label)) %>%
  arrange(label, diet_pattern) %>%
  select(`Dietary factor` = label, `Healthier is` = healthier_is, Pattern = diet_pattern,
         Unit = Intake_unit, Counterfactual = counterfactual,
         `Current (min)` = current_min, `Current (median)` = current_median,
         `Current (max)` = current_max, TMRED = tmred,
         `Subgroups where counterfactual is less healthy` = subgroups_less_favourable,
         Direction = direction, `Counterfactual beyond TMRED` = cf_beyond_tmred)

print(check, n = Inf, width = Inf)

# factor-patterns where the model hides harm (any subgroup less favourable)
cat("\nWhere the counterfactual is less healthy than current intake for any subgroup:\n")
check %>%
  filter(`Subgroups where counterfactual is less healthy` > 0) %>%
  select(`Dietary factor`, Pattern, Counterfactual, `Current (median)`, Direction) %>%
  print(n = Inf, width = Inf)

dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
write_csv(check, out_file)