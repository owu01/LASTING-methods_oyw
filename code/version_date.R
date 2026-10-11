# =====================================================================
# LASTING model -- central version-date configuration
# =====================================================================
# SINGLE source of truth for the date stamp appended to every
# generated data-input file. Format: ISO 8601 (YYYY-MM-DD).
#
# WHY THIS FILE EXISTS
#   Cleaning / finalize chapters (02-07) WRITE dated files; later
#   chapters READ them back. If each chapter stamped its own
#   Sys.Date(), running them on different days would break the
#   hand-off: a file written ".._2026-07-21.csv" cannot be found by a
#   reader looking for ".._2026-07-22.csv". Centralizing the date here
#   guarantees writers and readers always agree, and makes a run
#   fully reproducible.
#
# HOW TO CUT A NEW DATA VERSION
#   1. Set `version_date` below to the date you (re)generate the
#      inputs. Use a fixed date for reproducibility, or Sys.Date()
#      to stamp with today.
#   2. Re-run chapters 02-07 so all files are written with this stamp.
#   3. Downstream chapters need no edits -- they read this same value.
#
# USAGE (already wired into every chapter's setup chunk)
#   source("code/version_date.R")
#   read_csv(dated("data_inputs/FINAL/model_data/input_data"))
#     # -> "data_inputs/FINAL/model_data/input_data_2026-06-21.csv"
#   saveRDS(x, dated("data_inputs/.../temp/enviro_input", ".rds"))
#     # -> "data_inputs/.../temp/enviro_input_2026-06-21.rds"
# =====================================================================

# --- Set the version date here (ISO 8601, YYYY-MM-DD) ----------------
# Fixed date for reproducibility. Change this one line to cut a new
# version, or replace with Sys.Date() to always use today.
version_date <- as.Date("2026-10-10")

# --- Helper: build a dated file path ---------------------------------
# Appends "_<version_date>" (always ISO 8601) plus the extension to a
# path stem. This keeps the separator, date format, and extension
# defined in ONE place, so every file name is built identically.
#   dated("path/to/stem")          -> "path/to/stem_2026-06-21.csv"
#   dated("path/to/stem", ".rds")  -> "path/to/stem_2026-06-21.rds"
dated <- function(stem, ext = ".csv") {
  paste0(stem, "_", format(version_date, "%Y-%m-%d"), ext)
}

# --- Backward-compatibility alias ------------------------------------
# Some cluster scripts sourced by chapter 08 (presimulate_observed_
# disease_draws.R, PIF_analysis_part_2.R) still reference the old name
# `version.date`. Keep it defined so those sources don't error. New
# code should use version_date / dated() instead.
version.date <- version_date
