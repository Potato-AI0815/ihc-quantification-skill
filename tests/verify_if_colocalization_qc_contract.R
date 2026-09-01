#!/usr/bin/env Rscript
# verify_if_colocalization_qc_contract.R
# Deterministic production-path regression for the colocalization QC gate.
#
# The production contract is:
#   NOT_EVALUABLE_LOW_PIXEL_COUNT          valid pixel count < 30
#   NOT_EVALUABLE_LOW_DYNAMIC_RANGE        either channel dynamic range < 0.05
#   NOT_EVALUABLE_REGISTRATION_SUSPECT     abs(shift_x/y) > 5 px
#   ZERO_VARIANCE                          retained zero-variance branch
#   PASS                                   all gates pass -> finite metrics

options(stringsAsFactors = FALSE)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this tool with Rscript.")
root <- dirname(dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE)))
local_lib <- file.path(root, "Rlib")
if (dir.exists(local_lib)) .libPaths(c(normalizePath(local_lib), .libPaths()))

suppressPackageStartupMessages({
  library(data.table)
  library(EBImage)
})

source(file.path(root, "scripts", "if_preprocessing.R"))
source(file.path(root, "scripts", "if_colocalization.R"))

expect_qc <- function(row, status) {
  if (!identical(row$colocalization_qc_status, status)) {
    stop("expected colocalization_qc_status ", status, ", got ",
         row$colocalization_qc_status)
  }
  invisible(row)
}

expect_na_metrics <- function(row) {
  if (!is.na(row$pearson_r) || !is.na(row$manders_m1) || !is.na(row$manders_m2)) {
    stop("blocked colocalization branch must not emit finite Pearson/Manders metrics")
  }
  invisible(row)
}

set.seed(20260901)
n <- 64L
base <- matrix(stats::runif(n * n, 0.05, 0.20), nrow = n, ncol = n)
structure_mask <- matrix(FALSE, nrow = n, ncol = n)
structure_mask[16:48, 16:48] <- TRUE
structure_mask[20:44, 20:44] <- FALSE
A_high <- base
A_high[structure_mask] <- A_high[structure_mask] + 0.55
B_high <- A_high

full_mask <- matrix(TRUE, nrow = n, ncol = n)

cat("Fixture 1: aligned high colocalization\n")
row_high <- compute_if_colocalization(A_high, B_high, mask = full_mask,
                                      image_id = "ALIGNED_HIGH",
                                      biological_unit_id = "U1", condition = "high")
expect_qc(row_high, "PASS")
if (!is.finite(row_high$pearson_r) || !is.finite(row_high$manders_m1) ||
    !is.finite(row_high$manders_m2)) {
  stop("aligned high fixture must produce finite colocalization metrics")
}

cat("Fixture 2: low colocalization (biologically anti-correlated, aligned)\n")
B_low <- base
B_low[!structure_mask] <- B_low[!structure_mask] + 0.55
row_low <- compute_if_colocalization(A_high, B_low, mask = full_mask,
                                     image_id = "ALIGNED_LOW",
                                     biological_unit_id = "U2", condition = "low")
expect_qc(row_low, "PASS")
if (is.na(row_low$pearson_r) || row_low$pearson_r >= row_high$pearson_r) {
  stop("low fixture must be distinguishable from the high fixture by Pearson r")
}

cat("Fixture 3: channel B shifted by 7 px\n")
shift <- 7L
B_shifted <- matrix(0, nrow = n, ncol = n)
B_shifted[(shift + 1):n, (shift + 1):n] <- B_high[1:(n - shift), 1:(n - shift)]
row_shift <- compute_if_colocalization(A_high, B_shifted, mask = full_mask,
                                       image_id = "MISREGISTERED",
                                       biological_unit_id = "U3", condition = "shift7")
expect_qc(row_shift, "NOT_EVALUABLE_REGISTRATION_SUSPECT")
expect_na_metrics(row_shift)
if (!identical(row_shift$registration_status, "CHANNEL_REGISTRATION_SUSPECT")) {
  stop("misregistered fixture must record CHANNEL_REGISTRATION_SUSPECT")
}

cat("Fixture 4: low dynamic range\n")
B_flat <- matrix(0.50, nrow = n, ncol = n)
row_flat <- compute_if_colocalization(A_high, B_flat, mask = full_mask,
                                      image_id = "LOW_DYNAMIC_RANGE",
                                      biological_unit_id = "U4", condition = "flat")
expect_qc(row_flat, "NOT_EVALUABLE_LOW_DYNAMIC_RANGE")
expect_na_metrics(row_flat)
if (row_flat$dynamic_range_B >= 0.05) {
  stop("low-dynamic-range fixture must measure dynamic_range_B < 0.05")
}

cat("Fixture 5: low valid pixel count\n")
small_mask <- matrix(FALSE, nrow = n, ncol = n)
small_mask[1:5, 1:5] <- TRUE
row_small <- compute_if_colocalization(A_high, B_high, mask = small_mask,
                                       image_id = "LOW_PIXEL_COUNT",
                                       biological_unit_id = "U5", condition = "small")
expect_qc(row_small, "NOT_EVALUABLE_LOW_PIXEL_COUNT")
expect_na_metrics(row_small)
if (row_small$pixel_count >= 30L) stop("low-pixel-count fixture must have <30 valid pixels")

cat("PASS: colocalization production QC contract (aligned, low, shifted, low-dynamic, low-pixel)\n")
