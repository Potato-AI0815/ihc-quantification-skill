#!/usr/bin/env Rscript
# verify_if_synthetic_output.R
# Validation and Contract Checker for Immunofluorescence (IF) Modality Synthetic Outputs.
# Part of IHC/IF Quantification Skill v2.3.0-alpha.2

options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript tests/verify_if_synthetic_output.R /path/to/synthetic_if_output")
outdir <- normalizePath(args[[1]], mustWork = TRUE)

suppressPackageStartupMessages(library(data.table))

require_file <- function(path) {
  if (!file.exists(path)) stop("Missing expected IF output file: ", path)
  path
}

require_count <- function(pattern, expected, label) {
  found <- Sys.glob(pattern)
  if (length(found) != expected) stop(label, ": expected ", expected, " file(s), found ", length(found), ". Pattern: ", pattern)
  found
}

compartment <- fread(require_file(file.path(outdir, "source_data", "if_compartment_summary.csv")))
biological <- fread(require_file(file.path(outdir, "source_data", "if_biological_unit_summary.csv")))
channel_qc <- fread(require_file(file.path(outdir, "source_data", "if_channel_summary.csv")))
channel_meta <- fread(require_file(file.path(outdir, "source_data", "if_channel_metadata.csv")))
primary_long <- fread(require_file(file.path(outdir, "source_data", "if_primary_domain_summary_long.csv")))
image_qc <- fread(require_file(file.path(outdir, "source_data", "if_image_qc.csv")))
fig_manifest <- fread(require_file(file.path(outdir, "figures", "main", "if_main_figure_manifest.csv")))

# 1. Check Image count
if (uniqueN(compartment$image_id) != 4L) stop("Expected 4 synthetic IF images.")
if (any(image_qc$qc_status != "PASS")) stop("Synthetic IF fixture unexpectedly contains blocking QC failure.")
if (nrow(channel_meta) < 12L || any(!is.finite(channel_meta$raw_max))) stop("IF channel/page metadata is incomplete.")
if (any(!is.na(compartment$positive_area_fraction) & (compartment$positive_area_fraction < 0 | compartment$positive_area_fraction > 1))) {
  stop("IF positive area fractions must be bounded between 0 and 1.")
}

# 2. Check Compartments
if (!all(c("global", "nucleus", "cytoplasm", "extracellular") %in% unique(compartment$compartment))) {
  stop("Missing 4-compartment definitions in IF compartment summary.")
}

# 3. Scientific Terminology Contract: NO DAB/OD in IF tables
forbidden_terms <- c("optical_density", "h_score", "dab_od", "iod")
all_col_names <- tolower(c(names(compartment), names(biological), names(channel_qc), names(primary_long)))
for (term in forbidden_terms) {
  if (any(grepl(paste0("^", term, "$"), all_col_names))) {
    stop("Forbidden DAB term '", term, "' found in IF output columns!")
  }
}

# 4. Check Directional Hypothesis Consistency
# Treatment condition must have higher nuclear MFI than control
ctrl_nuc <- biological[condition == "control" & compartment == "nucleus", mean(mean_intensity)]
treat_nuc <- biological[condition == "treatment" & compartment == "nucleus", mean(mean_intensity)]
if (treat_nuc <= ctrl_nuc) {
  stop("Directional validation failed: Treatment nuclear MFI (", treat_nuc,
       ") should be > Control nuclear MFI (", ctrl_nuc, ")")
}

# Control condition must have higher cytoplasmic MFI than treatment
ctrl_cyto <- biological[condition == "control" & compartment == "cytoplasm", mean(mean_intensity)]
treat_cyto <- biological[condition == "treatment" & compartment == "cytoplasm", mean(mean_intensity)]
if (ctrl_cyto <= treat_cyto) {
  stop("Directional validation failed: Control cytoplasmic MFI (", ctrl_cyto,
       ") should be > Treatment cytoplasmic MFI (", treat_cyto, ")")
}

# 5. Check Main Figures (Figures 1-4)
if (nrow(fig_manifest) < 4L) {
  stop("Expected at least 4 main IF publication figures.")
}
for (col in c("png", "svg", "pdf")) {
  for (fpath in fig_manifest[[col]]) {
    if (!file.exists(fpath)) stop("Missing figure file recorded in manifest: ", fpath)
    if (file.info(fpath)$size == 0) stop("Generated figure file is 0 bytes: ", fpath)
  }
}

# 6. Check 8-panel QC overviews
require_count(file.path(outdir, "qc", "overview", "*_if_8panel_qc.png"), 4L, "IF 8-panel QC overview")

cat("PASS: IF synthetic output is complete and fully validated against scientific contracts.\n")
cat("Images:", uniqueN(compartment$image_id), "| Replicates (n):", uniqueN(biological$biological_unit_id),
    "| Figures:", nrow(fig_manifest), "\n")
