# Files whose code writes or reads the renamed outputs
files <- c("02-cleaning-code-diet.Rmd",
           "03-cleaning-code-health.Rmd",
           "04-cleaning-code-enviro.Rmd",
           "05-cleaning-code-cost.Rmd",
           "06-calculate-impact-factors.Rmd",
           "code/source_code/PIF_analysis_part_2.R")

# old text = new text (exact matches only)
renames <- c(
  # chapter 02 outputs
  "meat_day1.rds"            = "meat_day1_1723.rds",
  "meat_day2.rds"            = "meat_day2_1723.rds",
  "foods_day1_clean.rds"     = "foods_day1_clean_1723.rds",
  "foods_day2_clean.rds"     = "foods_day2_clean_1723.rds",
  "foods_day1_ssb.rds"       = "foods_day1_ssb_1723.rds",
  "foods_day2_ssb.rds"       = "foods_day2_ssb_1723.rds",
  "nhanes_incl_ssb_adj_clean_long.csv" = "nhanes1723_incl_ssb_adj_clean_long.csv",
  "nhanes1518_"              = "nhanes1723_",   # clean, incl_ssb, adj_long/wide, agesexrace(_merged)
  "NHANES_1518_summary_allfoods_adj_bysub_ncimethod" =
    "NHANES_1723_summary_allfoods_adj_bysub_ncimethod",
  # chapter 04-05 temporary outputs
  "fndds_flw.rds"            = "fndds_flw_1723.rds",
  "both_days15_env.rds"      = "both_days15_env_1723.rds",
  "enviro_input_dat.rds"     = "enviro_input_dat_1723.rds",
  "both_days11_cost.rds"     = "both_days11_cost_1723.rds",
  "price_input_dat.rds"      = "price_input_dat_1723.rds"
)

for (f in files) {
  if (!file.exists(f)) { message("Not found, skipped: ", f); next }
  txt <- readLines(f, warn = FALSE)
  n_changed <- 0
  for (old in names(renames)) {
    hits <- grepl(old, txt, fixed = TRUE)
    n_changed <- n_changed + sum(hits)
    txt <- gsub(old, renames[[old]], txt, fixed = TRUE)
  }
  writeLines(txt, f)
  message(f, ": ", n_changed, " lines changed")
}