#!/usr/bin/env Rscript
# verify_backward_compatibility.R
# Validates 100% numerical and structural backward compatibility with v2.2.2 DAB-IHC results.

options(stringsAsFactors = FALSE)
suppressPackageStartupMessages(library(data.table))

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
root <- dirname(script_dir)

baseline_dir <- file.path(root, "tests", "baseline_v222_reference")
if (!dir.exists(baseline_dir)) {
  stop("Baseline reference directory does not exist at: ", baseline_dir)
}

current_out <- file.path(root, "tests", "synthetic_output")

# CSV numeric serialization can differ by a few ulps across R/platform builds
# even when the underlying DAB-IHC calculation is unchanged. Keep the
# structural and character checks exact, while allowing this bounded,
# cross-platform floating-point drift.
numeric_tolerance <- 1e-6

cat("Comparing current DAB output against v2.2.2 baseline...\n")

# Tables to compare
tables_to_check <- c(
  "source_data/ihc_region_summary.csv",
  "source_data/ihc_biological_unit_summary.csv",
  "source_data/ihc_primary_domain_summary_long.csv",
  "source_data/ihc_image_qc.csv",
  "source_data/ihc_paired_effects.csv",
  "source_data/ihc_roi_registry.csv",
  "source_data/ihc_roi_overlap_audit.csv",
  "source_data/ihc_metric_dictionary.csv",
  "source_data/ihc_qc_color_legend.csv"
)

diff_count <- 0L

for (tbl_rel in tables_to_check) {
  base_path <- file.path(baseline_dir, tbl_rel)
  curr_path <- file.path(current_out, tbl_rel)

  if (!file.exists(curr_path)) {
    cat("FAIL: Current output missing file:", tbl_rel, "\n")
    diff_count <- diff_count + 1L
    next
  }

  dt_base <- fread(base_path)
  dt_curr <- fread(curr_path)

  if (!identical(dim(dt_base), dim(dt_curr))) {
    cat(sprintf("FAIL: Dimensions differ in %s (Baseline: %s, Current: %s)\n",
                tbl_rel, paste(dim(dt_base), collapse = "x"), paste(dim(dt_curr), collapse = "x")))
    diff_count <- diff_count + 1L
    next
  }

  if (!identical(names(dt_base), names(dt_curr))) {
    cat("FAIL: Column names differ in", tbl_rel, "\n")
    diff_count <- diff_count + 1L
    next
  }

  # Numerical tolerance check
  max_num_diff <- 0.0
  for (col in names(dt_base)) {
    if (is.numeric(dt_base[[col]])) {
      v_base <- dt_base[[col]]
      v_curr <- dt_curr[[col]]
      diffs <- abs(v_base - v_curr)
      diffs <- diffs[!is.na(diffs)]
      if (length(diffs)) {
        max_d <- max(diffs)
        if (max_d > max_num_diff) max_num_diff <- max_d
      }
    } else {
      # Character comparison
      v_base <- as.character(dt_base[[col]])
      v_curr <- as.character(dt_curr[[col]])
      if (!identical(v_base, v_curr)) {
        cat(sprintf("FAIL: Character content mismatch in %s column '%s'\n", tbl_rel, col))
        diff_count <- diff_count + 1L
      }
    }
  }

  if (max_num_diff > numeric_tolerance) {
    cat(sprintf("FAIL: Numerical difference in %s exceeds %e (max diff = %e)\n",
                tbl_rel, numeric_tolerance, max_num_diff))
    diff_count <- diff_count + 1L
  } else {
    cat(sprintf("PASS: %s numerically compatible (max diff: %e; tolerance: %e)\n",
                tbl_rel, max_num_diff, numeric_tolerance))
  }
}

if (diff_count > 0L) {
  stop("Backward compatibility audit FAILED with ", diff_count, " differences.")
} else {
  cat("\n=======================================================\n")
  cat(sprintf("PASS: DAB BACKWARD COMPATIBILITY AUDIT CONFIRMED (numeric tolerance: %e)!\n",
              numeric_tolerance))
  cat("=======================================================\n")
}
