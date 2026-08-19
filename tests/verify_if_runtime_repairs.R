#!/usr/bin/env Rscript
# Regression checks for repaired IF runtime contracts.

options(stringsAsFactors = FALSE)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run with Rscript.")
root <- dirname(dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE)))

suppressPackageStartupMessages({
  library(data.table)
  library(EBImage)
})

source(file.path(root, "scripts", "if_io_helpers.R"))
source(file.path(root, "scripts", "if_quantification_helpers.R"))

# Reviewed IF ROI masks must be applied to the analysis image without changing
# the raw source file.  A small rectangle is used here so the contract remains
# deterministic and does not depend on a public-data download.
roi_fixture <- data.table(
  image_id = rep("ROI_IMAGE", 4L),
  roi_id = rep("artifact", 4L),
  vertex_order = 1:4,
  x = c(4, 6, 6, 4),
  y = c(4, 4, 6, 6),
  compartment = rep("artifact", 4L),
  action = rep("exclude", 4L),
  selection_source = rep("test", 4L),
  selection_method = rep("polygon", 4L),
  reviewer = rep("test", 4L),
  annotation_status = rep("approved", 4L)
)
roi_res <- build_if_analysis_mask(roi_fixture, "ROI_IMAGE", nr = 8L, nc = 8L)
if (roi_res$status != "REVIEWED_ROI_APPLIED" ||
    roi_res$excluded_pixel_count <= 0L ||
    !any(!roi_res$analysis_mask[4:6, 4:6])) {
  stop("Reviewed IF ROI exclusion mask contract failed.")
}
no_roi_res <- build_if_analysis_mask(NULL, "ROI_IMAGE", nr = 8L, nc = 8L)
if (no_roi_res$status != "NO_REVIEWED_ROI" || !all(no_roi_res$analysis_mask)) {
  stop("No-ROI IF analysis mask contract failed.")
}

# An all-zero corrected target is a non-evaluable channel, not a zero threshold.
empty_threshold <- calculate_positivity_threshold(matrix(0, nrow = 8, ncol = 8))
if (!identical(empty_threshold$threshold_qc_status, "EMPTY_CHANNEL") ||
    !is.na(empty_threshold$threshold_value)) {
  stop("EMPTY_CHANNEL threshold contract failed.")
}

seg <- list(
  tissue_mask = matrix(TRUE, nrow = 4, ncol = 4),
  nuc_mask = matrix(c(TRUE, TRUE, FALSE, FALSE,
                      TRUE, TRUE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE,
                      FALSE, FALSE, FALSE, FALSE), nrow = 4, byrow = TRUE),
  cyto_mask = matrix(FALSE, nrow = 4, ncol = 4),
  extracellular_mask = matrix(TRUE, nrow = 4, ncol = 4),
  n_cells = 1L,
  nuc_labels = matrix(c(1L, 1L, 0L, 0L,
                        1L, 1L, 0L, 0L,
                        0L, 0L, 0L, 0L,
                        0L, 0L, 0L, 0L), nrow = 4, byrow = TRUE),
  cell_labels = matrix(c(1L, 1L, 0L, 0L,
                         1L, 1L, 0L, 0L,
                         0L, 0L, 0L, 0L,
                         0L, 0L, 0L, 0L), nrow = 4, byrow = TRUE)
)
empty_comp <- quantify_if_compartments(
  matrix(0, nrow = 4, ncol = 4), seg,
  marker_name = "target", channel_name = "target",
  image_id = "EMPTY", biological_unit_id = "UNIT", condition = "test",
  threshold_res = empty_threshold
)
if (any(!is.na(empty_comp$positive_area_fraction))) {
  stop("EMPTY_CHANNEL positivity was converted into a numeric fraction.")
}

# A missing/empty compartment must also remain non-evaluable; reporting a
# numeric zero here would turn a segmentation failure into a biological result.
no_tissue_seg <- seg
no_tissue_seg$tissue_mask <- matrix(FALSE, nrow = 4, ncol = 4)
no_tissue_seg$extracellular_mask <- matrix(FALSE, nrow = 4, ncol = 4)
no_tissue_comp <- quantify_if_compartments(
  matrix(0, nrow = 4, ncol = 4), no_tissue_seg,
  marker_name = "target", channel_name = "target",
  image_id = "NO_TISSUE", biological_unit_id = "UNIT", condition = "test",
  threshold_res = empty_threshold
)
if (any(!is.na(no_tissue_comp$positive_area_fraction))) {
  stop("Empty compartments were converted into a numeric positivity fraction.")
}

valid_manifest <- data.table(
  image_id = rep("IMG", 2),
  biological_unit_id = rep("UNIT", 2),
  condition = rep("test", 2),
  modality = rep("immunofluorescence", 2),
  marker = c("DAPI", "target"),
  channel_name = c("nucleus", "target"),
  channel_index = 1:2,
  channel_role = c("nucleus", "target"),
  file_path = rep("placeholder.tif", 2)
)
validate_if_manifest(valid_manifest)
bad_manifest <- copy(valid_manifest)
bad_manifest$channel_index[2] <- 1L
bad_ok <- tryCatch({ validate_if_manifest(bad_manifest); FALSE }, error = function(e) TRUE)
if (!bad_ok) stop("Duplicate IF channel_index mapping was not rejected.")

# Optional public cache checks: do not require raw public data in CI, but when
# present verify the exact ImageJ axis metadata that caused the original bug.
fc <- file.path(root, "work", "public_data_cache", "FluorescentCells.tif")
cs <- file.path(root, "work", "public_data_cache", "confocal-series.tif")
if (file.exists(fc)) {
  meta <- read_imagej_description(fc)
  if (is.null(meta) || as.integer(meta$images) != 3L || as.integer(meta$channels) != 3L) {
    stop("FluorescentCells ImageJ metadata contract failed.")
  }
}
if (file.exists(cs)) {
  meta <- read_imagej_description(cs)
  if (is.null(meta) || as.integer(meta$images) != 50L ||
      as.integer(meta$channels) != 2L || as.integer(meta$slices) != 25L) {
    stop("confocal-series ImageJ metadata contract failed.")
  }
}

cat("PASS: IF runtime repair contracts validated (empty channel, manifest mapping, ImageJ metadata).\n")
