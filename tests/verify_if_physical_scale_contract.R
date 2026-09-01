#!/usr/bin/env Rscript
# verify_if_physical_scale_contract.R
# Deterministic regression for the IF physical-scale contract.
#
# Missing / NA / empty / non-finite / <=0 pixel_size_um values MUST produce
# pixel_fallback mode with NA physical-unit metrics.  They must never default
# to the forbidden assumption 1 px == 1 um.

options(stringsAsFactors = FALSE)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this tool with Rscript.")
root <- dirname(dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE)))

suppressPackageStartupMessages({
  library(data.table)
  library(EBImage)
})

source(file.path(root, "scripts", "if_quantification_helpers.R"))
source(file.path(root, "scripts", "if_puncta.R"))

make_fixture_seg <- function() {
  tissue <- matrix(TRUE, nrow = 10L, ncol = 10L)
  nuc_labels <- matrix(0L, nrow = 10L, ncol = 10L)
  nuc_labels[1:5, 1:5] <- 1L
  nuc_labels[6:10, 1:5] <- 2L
  cell_labels <- matrix(0L, nrow = 10L, ncol = 10L)
  cell_labels[1:5, 1:7] <- 1L
  cell_labels[6:10, 1:7] <- 2L
  nuc_mask <- nuc_labels > 0L
  cell_mask <- cell_labels > 0L
  list(
    tissue_mask = tissue,
    nuc_mask = nuc_mask,
    cyto_mask = cell_mask & !nuc_mask,
    extracellular_mask = tissue & !cell_mask,
    n_cells = 2L,
    nuc_labels = nuc_labels,
    cell_labels = cell_labels
  )
}

seg <- make_fixture_seg()
set.seed(20260901)
channel_mat <- matrix(stats::runif(100L, 0.05, 0.90), nrow = 10L, ncol = 10L)
threshold_res <- list(
  threshold_method = "manual",
  threshold_value = 0.10,
  threshold_source = "test",
  threshold_qc_status = "LOCKED_MANUAL"
)

check_compartment_contract <- function(pixel_size_um, expected_mode) {
  sc <- resolve_if_scale_contract(pixel_size_um)
  if (!identical(sc$scale_mode, expected_mode)) {
    stop("scale_mode mismatch for input ", format(pixel_size_um), ": ",
         sc$scale_mode, " != ", expected_mode)
  }
  comp <- quantify_if_compartments(
    channel_mat = channel_mat,
    seg_res = seg,
    marker_name = "M",
    channel_name = "C",
    image_id = "IMG",
    biological_unit_id = "U",
    condition = "C",
    threshold_res = threshold_res,
    pixel_size_um = sc$pixel_size_um,
    scale_mode = sc$scale_mode
  )
  global <- comp[compartment == "global"]
  if (!is.finite(global$pixel_count) || global$pixel_count != 100L) {
    stop("global pixel_count must be 100 in the deterministic fixture")
  }
  if (!is.finite(global$area_px2) || global$area_px2 != 100.0) {
    stop("global area_px2 must be finite and equal 100")
  }
  if (expected_mode == "physical_calibrated") {
    expected_um2 <- 100.0 * (sc$pixel_size_um ^ 2)
    if (!is.finite(global$area_um2) || abs(global$area_um2 - expected_um2) > 1e-12) {
      stop("calibrated area_um2 mismatch: ", global$area_um2, " != ", expected_um2)
    }
  } else {
    if (!is.na(global$area_um2)) {
      stop("pixel_fallback mode must produce NA area_um2, got ", global$area_um2)
    }
  }

  cells <- quantify_if_single_cells(
    channel_mat = channel_mat,
    seg_res = seg,
    marker_name = "M",
    channel_name = "C",
    image_id = "IMG",
    biological_unit_id = "U",
    condition = "C",
    threshold_val = 0.10,
    pixel_size_um = sc$pixel_size_um,
    scale_mode = sc$scale_mode
  )
  if (nrow(cells) != 2L || any(!is.finite(cells$cell_area_px2))) {
    stop("single-cell pixel-domain areas must be finite")
  }
  if (expected_mode == "physical_calibrated") {
    if (any(!is.finite(cells$cell_area_um2))) stop("calibrated single-cell area_um2 must be finite")
  } else {
    if (any(!is.na(cells$cell_area_um2))) stop("fallback single-cell area_um2 must be NA")
  }

  puncta <- detect_if_puncta(
    channel_mat = channel_mat,
    seg_res = seg,
    marker_name = "M",
    channel_name = "C",
    image_id = "IMG",
    biological_unit_id = "U",
    condition = "C",
    sigma1 = 0.5,
    sigma2 = 1.0,
    pixel_size_um = sc$pixel_size_um,
    scale_mode = sc$scale_mode
  )$summary
  pg <- puncta[compartment == "global"]
  if (!is.finite(pg$total_puncta_area_px2)) stop("puncta area_px2 must be finite")
  if (!is.finite(pg$puncta_density_per_px2)) stop("puncta density_per_px2 must be finite")
  if (expected_mode == "physical_calibrated") {
    if (!is.finite(pg$total_puncta_area_um2) || !is.finite(pg$puncta_density_per_um2)) {
      stop("calibrated puncta physical metrics must be finite")
    }
  } else {
    if (!is.na(pg$total_puncta_area_um2) || !is.na(pg$puncta_density_per_um2)) {
      stop("fallback puncta physical metrics must be NA")
    }
  }
  invisible(list(scale = sc, comp = comp, cells = cells, puncta = pg))
}

cat("Case A: calibrated pixel_size_um = 0.5\n")
a <- check_compartment_contract(0.5, "physical_calibrated")
if (abs(a$comp[compartment == "global"]$area_um2 - 25.0) > 1e-12) stop("0.5 um calibration area contract failed")
if (length(a$scale$qc_warning) != 0L) stop("calibrated mode must not emit MISSING_PIXEL_SIZE_CALIBRATION")

cat("Case B: missing pixel_size_um = NA\n")
b <- check_compartment_contract(NA_real_, "pixel_fallback")
if (!identical(b$scale$qc_warning, "MISSING_PIXEL_SIZE_CALIBRATION")) {
  stop("missing calibration must emit MISSING_PIXEL_SIZE_CALIBRATION")
}
if (!is.na(b$comp[compartment == "global"]$area_um2)) stop("fallback area_um2 must be NA")

cat("Case C: invalid pixel_size_um values\n")
for (bad_value in list(0, -1, Inf, NaN)) {
  sc <- resolve_if_scale_contract(bad_value)
  if (!identical(sc$scale_mode, "pixel_fallback") || !is.na(sc$pixel_size_um)) {
    stop("invalid pixel_size_um was not resolved to pixel_fallback: ", format(bad_value))
  }
  comp <- quantify_if_compartments(
    channel_mat = channel_mat,
    seg_res = seg,
    marker_name = "M",
    channel_name = "C",
    image_id = "IMG",
    biological_unit_id = "U",
    condition = "C",
    threshold_res = threshold_res,
    pixel_size_um = sc$pixel_size_um,
    scale_mode = sc$scale_mode
  )
  if (any(!is.na(comp$area_um2))) {
    stop("invalid calibration produced finite physical area for input ", format(bad_value))
  }
}

cat("PASS: IF physical-scale contract (calibrated, missing, and invalid inputs)\n")
