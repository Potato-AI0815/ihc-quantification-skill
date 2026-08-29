#!/usr/bin/env Rscript

# BBBC013 v1 external biological-response validation.  The assay is used to
# test nuclear/cytoplasmic quantification and dose-direction recovery; it is
# not used to tune segmentation or threshold parameters.
#
# Biology: BBBC013 is a PI3K/Akt-inhibition translocation assay. Inhibition of
# PI3K/Akt causes FKHR-EGFP to accumulate in the nucleus, so the
# nuclear-to-cytoplasmic ratio is expected to INCREASE with drug dose
# (dose-dependent nuclear translocation/accumulation), not decrease.
#
# Official plate layout (per the two official per-drug platemap files, which
# agree with the combined BBBC013_v1_platemap_all.txt):
#   Rows A-D, Wortmannin (doses in nM):
#     columns 01-02  negative controls (0 nM)
#     columns 03-11  9-point dose series (0.98 ... 250 nM)
#     column  12     positive control (150 nM Wortmannin; the plate-wide
#                    positive control named in the official description)
#   Rows E-H, LY294002 (doses in uM):
#     column  01     high-dose reference (80 uM LY294002 — the maximum dose
#                    of the official LY294002 dose series)
#     column  02     negative control (0 uM)
#     columns 03-11  9-point dose series (0.31 ... 80 uM)
#     column  12     "empty" wells (no drug; dose 0 in the platemap)
# E12-H12 therefore carry no LY294002 and must NOT be labeled as LY294002
# positive controls; the roles below are assigned from the platemap doses and
# cross-checked against the official layout.

options(stringsAsFactors = FALSE, scipen = 999)
suppressPackageStartupMessages({
  library(data.table)
  library(EBImage)
  library(tiff)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run with Rscript.")
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE))
root <- dirname(dirname(script_dir))
source(file.path(root, "scripts", "if_preprocessing.R"))
source(file.path(root, "scripts", "if_segmentation.R"))
source(file.path(root, "scripts", "if_quantification_helpers.R"))

converted_dir <- file.path(root, ".external_validation_cache", "BBBC013", "converted_tiff")
platemap_path <- file.path(root, ".external_validation_cache", "BBBC013", "BBBC013_v1_platemap_all.txt")
result_dir <- file.path(root, "external_validation", "results")
report_dir <- file.path(root, "external_validation", "reports")
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(converted_dir) || !file.exists(platemap_path)) stop("Run convert_bbbc013_bmp_to_tiff.R and download the platemap first.")

read_tiff_matrix <- function(path) {
  arr <- tiff::readTIFF(path, native = FALSE, convert = TRUE, all = FALSE)
  if (length(dim(arr)) > 2L) arr <- arr[, , 1L]
  matrix(as.numeric(arr), nrow = dim(arr)[1L], ncol = dim(arr)[2L])
}

platemap_values <- suppressWarnings(as.numeric(readLines(platemap_path, warn = FALSE)[-1L]))
platemap_values <- platemap_values[is.finite(platemap_values)]
if (length(platemap_values) != 96L) stop("Expected 96 numeric BBBC013 platemap entries; found ", length(platemap_values), ".")
plate <- matrix(platemap_values, nrow = 8L, ncol = 12L, byrow = TRUE,
                dimnames = list(LETTERS[1:8], sprintf("%02d", 1:12)))

well_table <- CJ(row = LETTERS[1:8], column = sprintf("%02d", 1:12), unique = TRUE)
well_table[, well := paste0(row, column)]
well_table[, drug := fifelse(row %chin% LETTERS[1:4], "Wortmannin", "LY294002")]
well_table[, dose_value := as.numeric(plate[cbind(match(row, LETTERS[1:8]), match(column, sprintf("%02d", 1:12)))])]
well_table[, dose_unit := fifelse(drug == "Wortmannin", "nM", "uM")]
# Roles assigned from the official per-drug platemap layouts (see header).
well_table[, role := "dose_series"]
well_table[drug == "Wortmannin" & column %chin% c("01", "02") & dose_value == 0, role := "negative_control"]
well_table[drug == "Wortmannin" & column == "12" & dose_value == 150, role := "positive_control"]
well_table[drug == "LY294002" & column == "01" & dose_value == 80, role := "positive_control"]
well_table[drug == "LY294002" & column == "02" & dose_value == 0, role := "negative_control"]
well_table[drug == "LY294002" & column == "12" & dose_value == 0, role := "empty"]
# Cross-check the official layout: the plate-wide positive control is the
# 150 nM Wortmannin column (A12-D12); E12-H12 are no-drug wells and are never
# treated as LY294002 positive controls.
stopifnot(
  all(well_table[drug == "Wortmannin" & column == "12", role] == "positive_control"),
  all(well_table[drug == "LY294002" & column == "12", role] == "empty"),
  all(well_table[drug == "LY294002" & column == "01", role] == "positive_control"),
  sum(well_table$role == "positive_control") == 8L,
  sum(well_table$role == "negative_control") == 12L,
  sum(well_table$role == "empty") == 4L
)
well_table[, replicate := fifelse(drug == "Wortmannin", match(row, LETTERS[1:4]), match(row, LETTERS[5:8]))]

rows <- vector("list", nrow(well_table))
for (i in seq_len(nrow(well_table))) {
  w <- well_table[i]
  # The first two digits in the official file name are the well index; the
  # row/column tokens are the authoritative plate coordinates.
  index <- sprintf("%02d", (match(w$row, LETTERS[1:8]) - 1L) * 12L + as.integer(w$column))
  target_file <- file.path(converted_dir, paste0("Channel1-", index, "-", w$row, "-", w$column, ".tif"))
  dna_file <- file.path(converted_dir, paste0("Channel2-", index, "-", w$row, "-", w$column, ".tif"))
  if (!file.exists(target_file) || !file.exists(dna_file)) stop("Missing converted BBBC013 pair for ", w$well, ": ", target_file, " / ", dna_file)

  target_raw <- read_tiff_matrix(target_file)
  dna_raw <- read_tiff_matrix(dna_file)
  dna_prep <- preprocess_if_channel(dna_raw, method = "top_hat", radius = 25, bit_depth = 8L)
  target_prep <- preprocess_if_channel(target_raw, method = "top_hat", radius = 25, bit_depth = 8L)
  seg <- segment_if_image(
    nuclear_mat = dna_prep$corrected_mat,
    target_mat = NULL,
    cyto_ref_mat = NULL,
    nuc_threshold_method = "otsu",
    nuc_min_area = 20,
    nuc_max_area = 5000,
    cell_propagation_radius = 15,
    max_cytoplasm_expansion_radius = 10,
    cytoplasm_boundary_gap_px = 1,
    nuc_watershed_tolerance = 1.0,
    nuc_watershed_ext = 1,
    refine_dense_nuclei = TRUE
  )
  cells <- quantify_if_single_cells(
    channel_mat = target_prep$corrected_mat,
    seg_res = seg,
    marker_name = "FKHR-EGFP",
    channel_name = "Channel1",
    image_id = w$well,
    biological_unit_id = w$well,
    condition = w$drug,
    threshold_val = NA_real_,
    pixel_size_um = 1.0
  )
  nc <- cells$nuclear_to_cytoplasmic_ratio
  rows[[i]] <- data.table(
    well = w$well,
    row = w$row,
    column = w$column,
    drug = w$drug,
    role = w$role,
    dose_value = w$dose_value,
    dose_unit = w$dose_unit,
    replicate = w$replicate,
    cell_count = nrow(cells),
    median_nuclear_intensity = if (nrow(cells)) stats::median(cells$nuclear_mean_intensity, na.rm = TRUE) else NA_real_,
    median_cytoplasmic_intensity = if (nrow(cells)) stats::median(cells$cytoplasmic_mean_intensity, na.rm = TRUE) else NA_real_,
    median_NC_ratio = if (any(is.finite(nc))) stats::median(nc, na.rm = TRUE) else NA_real_,
    segmented_nuclei = seg$n_cells,
    effective_propagation_radius = seg$metrics$effective_cell_propagation_radius,
    median_propagation_radius = seg$metrics$median_cell_propagation_radius,
    nonzero_propagation_fraction = seg$metrics$nonzero_cell_propagation_fraction,
    segmentation_qc_status = seg$metrics$segmentation_qc_status
  )
}

results <- rbindlist(rows, fill = TRUE)
fwrite(results, file.path(result_dir, "BBBC013_NC_TRANSLOCATION_RESULTS.csv"))

summaries <- list()
for (drug_name in unique(results$drug)) {
  d <- results[drug == drug_name]
  neg <- d[role == "negative_control" & is.finite(median_NC_ratio), median_NC_ratio]
  pos <- d[role == "positive_control" & is.finite(median_NC_ratio), median_NC_ratio]
  empty <- d[role == "empty" & is.finite(median_NC_ratio), median_NC_ratio]
  dose <- d[role == "dose_series" & is.finite(median_NC_ratio) & is.finite(dose_value)]
  rho <- if (nrow(dose) >= 3L && length(unique(dose$dose_value)) >= 3L) {
    suppressWarnings(cor(dose$dose_value, dose$median_NC_ratio, method = "spearman"))
  } else NA_real_
  neg_mean <- if (length(neg)) mean(neg) else NA_real_
  pos_mean <- if (length(pos)) mean(pos) else NA_real_
  zprime <- if (length(neg) >= 2L && length(pos) >= 2L && is.finite(pos_mean - neg_mean) && abs(pos_mean - neg_mean) > 0) {
    1 - 3 * (stats::sd(pos) + stats::sd(neg)) / abs(pos_mean - neg_mean)
  } else NA_real_
  # Expected biology: PI3K/Akt inhibition drives FKHR-EGFP into the nucleus,
  # so the N/C ratio must increase with dose (positive rho) and the
  # positive-control wells must sit above the negative-control wells.
  summaries[[drug_name]] <- data.table(
    drug = drug_name,
    n_wells = nrow(d),
    n_valid_wells = sum(is.finite(d$median_NC_ratio)),
    negative_control_median_NC_ratio = if (length(neg)) stats::median(neg) else NA_real_,
    positive_control_median_NC_ratio = if (length(pos)) stats::median(pos) else NA_real_,
    empty_well_median_NC_ratio = if (length(empty)) stats::median(empty) else NA_real_,
    positive_minus_negative_effect = if (length(neg) && length(pos)) stats::median(pos) - stats::median(neg) else NA_real_,
    spearman_dose_response_rho = rho,
    z_prime_descriptive = zprime,
    expected_direction_recovered = is.finite(rho) && rho > 0 && length(pos) > 0 && length(neg) > 0 && stats::median(pos) > stats::median(neg)
  )
}
summary_dt <- rbindlist(summaries, fill = TRUE)
all_direction <- all(summary_dt$expected_direction_recovered)
valid_fraction <- mean(is.finite(results$median_NC_ratio))
status <- if (all_direction && valid_fraction >= 0.80) "PASS" else if (any(summary_dt$expected_direction_recovered) && valid_fraction >= 0.50) "PASS_WITH_WARNINGS" else "FAIL"

fmt <- function(x, digits = 3L) if (is.finite(x)) formatC(x, digits = digits, format = "f") else "NA"
report <- c(
  "# BBBC013 Nuclear/Cytoplasmic Translocation External Validation",
  "",
  "**Evidence level**: Level B — real biological-response concordance",
  "",
  paste0("**Status**: **", status, "**"),
  "",
  "The BBBC013 BMP archive was converted to uncompressed 8-bit TIFF only in the validation cache. The conversion script checked exact integer pixel round-trips for all 192 files. No BMP support was added to the core workflow.",
  "",
  "## Biological direction",
  "",
  "BBBC013 is a PI3K/Akt-inhibition translocation assay: inhibiting PI3K/Akt prevents phosphorylation-dependent cytoplasmic retention of FKHR-EGFP, so FKHR-EGFP **accumulates in the nucleus** with increasing drug concentration. The expected signature is a **dose-dependent increase of the nuclear-to-cytoplasmic (N/C) ratio** (positive Spearman rho), together with N/C elevation in positive-control wells relative to negative controls. A dose-dependent N/C decrease would contradict this biology and is not an expected outcome.",
  "",
  "## Pre-registered design",
  "",
  "- Channel 1: FKHR-EGFP target; Channel 2: DNA.",
  "- Roles follow the official per-drug platemap files, not column symmetry:",
  "  - Rows A-D, Wortmannin (nM): columns 1-2 negative controls (0), columns 3-11 dose series (0.98-250), column 12 positive control (150 nM Wortmannin — the plate-wide positive control).",
  "  - Rows E-H, LY294002 (uM): column 1 high-dose reference (80, the maximum dose of the official LY294002 series), column 2 negative control (0), columns 3-11 dose series (0.31-80), column 12 no-drug (empty) wells.",
  "- E12-H12 contain no LY294002 and are therefore **excluded from the LY294002 positive-control statistics**; they are reported separately as no-drug wells.",
  "- Primary endpoint: well-level median nuclear-to-cytoplasmic ratio.",
  "- Cells are nested observations and are aggregated to wells before response summaries.",
  "- A positive dose-response direction (rho > 0) and positive-control shift above negative controls indicate recovery of cytoplasm-to-nucleus translocation.",
  "",
  "## Drug-level summaries",
  "",
  "| Drug | Valid wells | Negative median N/C | Positive median N/C | No-drug (empty) median N/C | Positive-minus-negative | Spearman rho | Z-prime (descriptive) | Direction |",
  "|---|---:|---:|---:|---:|---:|---:|---:|---|",
  vapply(seq_len(nrow(summary_dt)), function(i) {
    r <- summary_dt[i]
    sprintf("| %s | %d/%d | %s | %s | %s | %s | %s | %s | %s |",
            r$drug, r$n_valid_wells, r$n_wells,
            fmt(r$negative_control_median_NC_ratio), fmt(r$positive_control_median_NC_ratio),
            fmt(r$empty_well_median_NC_ratio),
            fmt(r$positive_minus_negative_effect), fmt(r$spearman_dose_response_rho),
            fmt(r$z_prime_descriptive), if (r$expected_direction_recovered) "PASS" else "FAIL")
  }, character(1L)),
  "",
  paste0("Valid well fraction: ", fmt(valid_fraction), "."),
  "",
  "## Interpretation boundary",
  "",
  "This is a real-data biological-response concordance test, not a reproduction of the published Z'/V-factor endpoint and not a clinical assay validation. Published benchmark values were not used as optimization targets."
)
writeLines(report, file.path(report_dir, "BBBC013_NC_TRANSLOCATION_VALIDATION.md"))
fwrite(summary_dt, file.path(result_dir, "BBBC013_NC_TRANSLOCATION_SUMMARY.csv"))
cat(sprintf("BBBC013_STATUS=%s wells=%d valid_fraction=%.4f\n", status, nrow(results), valid_fraction))
if (status == "FAIL") quit(status = 2L)
