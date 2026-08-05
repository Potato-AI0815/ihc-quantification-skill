#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript tests/verify_synthetic_output.R /path/to/synthetic_output")
outdir <- normalizePath(args[[1]], mustWork = TRUE)

suppressPackageStartupMessages(library(data.table))

require_file <- function(path) {
  if (!file.exists(path)) stop("Missing expected file: ", path)
  path
}
require_count <- function(pattern, expected, label) {
  found <- Sys.glob(pattern)
  if (length(found) != expected) stop(label, ": expected ", expected, " file(s), found ", length(found), ". Pattern: ", pattern)
  found
}

region <- fread(require_file(file.path(outdir, "source_data", "ihc_region_summary.csv")))
biological <- fread(require_file(file.path(outdir, "source_data", "ihc_biological_unit_summary.csv")))
primary <- fread(require_file(file.path(outdir, "source_data", "ihc_primary_domain_summary_long.csv")))
qc <- fread(require_file(file.path(outdir, "source_data", "ihc_image_qc.csv")))
fig_manifest <- fread(require_file(file.path(outdir, "figures", "main", "ihc_main_figure_manifest.csv")))

if (uniqueN(region$image_id) != 4L) stop("Expected four successful synthetic images.")
if (!all(c("global", "tumor", "stroma") %in% unique(region$compartment))) stop("Expected global, tumor, and stroma ROI compartments.")
required_region_metrics <- c(
  "nuclear_h_score", "cytoplasm_h_score", "whole_cell_h_score",
  "nuclear_integrated_dab_od", "cytoplasm_integrated_dab_od", "extracellular_integrated_dab_od"
)
if (length(setdiff(required_region_metrics, names(region)))) stop("Missing v2.2 region metrics: ", paste(setdiff(required_region_metrics, names(region)), collapse = ", "))
if (!all(c("global", "nucleus", "cytoplasm", "extracellular") %in% unique(primary$measurement_domain))) stop("Primary domain long table is incomplete.")
if (nrow(fig_manifest) != 4L) stop("Expected exactly four default main figures for the single synthetic marker/tissue/batch group.")
required_figure_fields <- c(
  "finite_value_count", "plot_status", "axis_mode", "y_axis_min", "y_axis_max",
  "n_unique_units", "n_repeated_units", "min_per_condition_n", "max_per_condition_n",
  "errorbar_status", "zoomed_png", "zoomed_svg", "zoomed_pdf"
)
if (length(setdiff(required_figure_fields, names(fig_manifest)))) {
  stop("Figure manifest is missing v2.2.2 fields: ", paste(setdiff(required_figure_fields, names(fig_manifest)), collapse = ", "))
}
if (any(fig_manifest$axis_mode != "fixed")) stop("Default publication figures must use fixed biological axes.")
expected_axis <- data.table::data.table(
  measurement_domain = c("global", "nucleus", "cytoplasm", "extracellular"),
  expected_max = c(1, 300, 300, 1)
)
axis_check <- merge(fig_manifest[, .(measurement_domain, y_axis_min, y_axis_max)], expected_axis, by = "measurement_domain", all.x = TRUE)
if (any(axis_check$y_axis_min != 0 | axis_check$y_axis_max != axis_check$expected_max)) stop("Unexpected default y-axis contract in figure manifest.")
if (any(fig_manifest$plot_status != "PLOTTED")) stop("Synthetic domains should contain finite values; unexpected plot status: ", paste(unique(fig_manifest$plot_status), collapse = ", "))
for (column in c("png", "svg", "pdf", "source_data")) {
  missing <- fig_manifest[!file.exists(get(column)), get(column)]
  if (length(missing)) stop("Figure manifest points to missing files: ", paste(missing, collapse = ", "))
}
require_count(file.path(outdir, "qc", "qc_overview", "*_qc_overview.png"), 4L, "QC overview")
require_count(file.path(outdir, "qc", "stain_channels", "*_hdab_reconstruction.png"), 4L, "H-DAB reconstruction")
require_count(file.path(outdir, "qc", "compartment_overlays", "*_domains_on_hdab.png"), 4L, "H-DAB domain overlay")
require_count(file.path(outdir, "qc", "compartment_overlays", "*_domains_on_rgb.png"), 4L, "RGB domain overlay")
require_count(file.path(outdir, "qc", "masks", "*_dab_positive_mask.png"), 4L, "DAB-positive binary mask")
if (nrow(qc) != 4L) stop("Expected one QC row per image.")
if (file.exists(file.path(outdir, "work", "image_errors.tsv"))) {
  errors <- fread(file.path(outdir, "work", "image_errors.tsv"))
  if (nrow(errors)) stop("Synthetic run recorded image errors.")
}
paired_path <- require_file(file.path(outdir, "source_data", "ihc_paired_effects.csv"))
paired <- fread(paired_path)
if (!any(paired$n_paired_units == 2L)) stop("Expected paired effects for two synthetic biological units.")
if (!all(c("nuclear_h_score", "cytoplasm_h_score") %in% unique(paired$metric))) stop("Paired effects omit domain-specific H-scores.")
if (!file.exists(file.path(outdir, "source_data", "ihc_manual_qc_template.csv"))) stop("Manual QC template is missing.")
if (!file.exists(file.path(outdir, "source_data", "ihc_roi_overlap_audit.csv"))) stop("ROI overlap audit is missing.")

cat("PASS: v2.2.2 synthetic smoke test output is complete.\n")
cat("Images:", uniqueN(region$image_id), "Cells:", sum(biological[compartment == "global", n_cells], na.rm = TRUE), "Main figures:", nrow(fig_manifest), "\n")
