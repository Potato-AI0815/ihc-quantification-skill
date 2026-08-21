# scripts/download_and_verify_public_images.R
# Downloads public ImageJ datasets and runs IF pipeline validation (P1)
# Part of IHC/IF Quantification Skill v2.3.0-alpha.2

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- if (length(script_arg) == 1L) {
  dirname(dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE)))
} else {
  getwd()
}

# The documented install command places dependencies in the repository-local
# Rlib.  Add that library before loading EBImage/data.table and also forward it
# to child runners; otherwise a clean R session cannot find the installed
# packages even though installation succeeded.
local_lib <- file.path(root, "Rlib")
if (dir.exists(local_lib)) .libPaths(c(normalizePath(local_lib), .libPaths()))

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

source(file.path(root, "scripts", "path_utils.R"))

cache_dir <- file.path(root, "work", "public_data_cache")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

# 1. Download Datasets
url_fc <- "https://wsr.imagej.net/images/FluorescentCells.zip"
url_cs <- "https://wsr.imagej.net/images/confocal-series.zip"

zip_fc <- file.path(cache_dir, "FluorescentCells.zip")
zip_cs <- file.path(cache_dir, "confocal-series.zip")

if (!file.exists(file.path(cache_dir, "FluorescentCells.tif"))) {
  cat("Downloading FluorescentCells.zip...\n")
  utils::download.file(url_fc, destfile = zip_fc, mode = "wb", quiet = TRUE)
  utils::unzip(zip_fc, exdir = cache_dir)
}

if (!file.exists(file.path(cache_dir, "confocal-series.tif"))) {
  cat("Downloading confocal-series.zip...\n")
  utils::download.file(url_cs, destfile = zip_cs, mode = "wb", quiet = TRUE)
  utils::unzip(zip_cs, exdir = cache_dir)
}

file_fc <- file.path(cache_dir, "FluorescentCells.tif")
file_cs <- file.path(cache_dir, "confocal-series.tif")

if (!file.exists(file_fc) || !file.exists(file_cs)) {
  stop("Failed to download or unpack public ImageJ test datasets.")
}
cat("Public datasets verified in cache directory.\n")

# ==============================================================================
# A. FluorescentCells Multi-Channel Validation
# ==============================================================================
cat("\n=== Validating Dataset A: FluorescentCells Multi-Channel TIFF ===\n")
fc_outdir <- file.path(root, "work", "public_fc_output")
if (dir.exists(fc_outdir)) unlink(fc_outdir, recursive = TRUE)

fc_manifest <- data.table(
  image_id = "FluorescentCells_01",
  biological_unit_id = "PublicSample_01",
  condition = "standard",
  modality = "immunofluorescence",
  # ImageJ's public FluorescentCells stack is three interleaved 2D pages.  The
  # third page is the nuclear signal; pages 1 and 2 are the structural/target
  # channels.  This mapping is explicit rather than inferred from row order.
  marker = c("Tubulin", "Actin", "DAPI"),
  channel_name = c("Alexa488_Tubulin", "Alexa568_Actin", "DAPI"),
  channel_index = c(1L, 2L, 3L),
  channel_role = c("target", "cytoplasm_reference", "nucleus"),
  pixel_size_um = 0.25,
  z_spacing_um = NA_real_,
  timepoint = "T0",
  batch = "BATCH_PUBLIC",
  replicate = 1L,
  file_path = file_fc
)
fc_manifest_path <- file.path(cache_dir, "fc_manifest.csv")
fwrite(fc_manifest, fc_manifest_path)

# The public FluorescentCells teaching image contains a burned-in ImageJ
# instruction in the lower-right corner.  Keep the downloaded TIFF unchanged,
# but use a reviewed exclude polygon for analysis/QC so the text is not
# mistaken for cells or tissue.  Coordinates follow the IF ROI contract:
# x = image rows and y = image columns.
fc_roi_path <- file.path(cache_dir, "fc_roi_annotations.csv")
fc_roi <- data.table(
  image_id = rep("FluorescentCells_01", 4L),
  roi_id = rep("burned_in_imagej_text", 4L),
  vertex_order = 1:4,
  x = c(440, 512, 512, 440),
  y = c(330, 330, 512, 512),
  compartment = rep("artifact", 4L),
  action = rep("exclude", 4L),
  selection_source = rep("public_dataset_qc", 4L),
  selection_method = rep("polygon", 4L),
  reviewer = rep("skill_validation", 4L),
  annotation_status = rep("approved", 4L)
)
fwrite(fc_roi, fc_roi_path)

cmd_fc <- sprintf(
  "Rscript %s --manifest=%s --outdir=%s --condition-order=%s --roi=%s --local-lib=%s",
  shQuote(file.path(root, "scripts", "run_if_quantification.R")),
  shQuote(fc_manifest_path),
  shQuote(fc_outdir),
  shQuote("standard"),
  shQuote(fc_roi_path),
  shQuote(local_lib)
)
status_fc <- system(cmd_fc)
if (status_fc != 0L) stop("FluorescentCells quantification failed.")

# Check outputs
fc_comp_table <- file.path(fc_outdir, "source_data", "if_compartment_summary.csv")
fc_qc_img <- file.path(fc_outdir, "qc", "overview", "FluorescentCells_01_if_8panel_qc.png")
if (!file.exists(fc_comp_table) || !file.exists(fc_qc_img)) {
  stop("FluorescentCells output tables or 8-panel QC image missing.")
}
dt_fc <- fread(fc_comp_table)
fc_qc <- fread(file.path(fc_outdir, "source_data", "if_image_qc.csv"))
fc_meta <- fread(file.path(fc_outdir, "source_data", "if_channel_metadata.csv"))
fc_roi_summary <- fread(file.path(fc_outdir, "source_data", "if_roi_exclusion_summary.csv"))
if (any(fc_qc$qc_status != "PASS")) stop("FluorescentCells QC did not pass: ", paste(fc_qc$qc_flags, collapse = ";"))
if (nrow(fc_meta) != 3L || !all(fc_meta$dim_z == 1L)) stop("FluorescentCells ImageJ channel/page parsing is not 3 x 2D pages.")
if (any(!is.finite(fc_meta$raw_max) | fc_meta$raw_max <= 0)) stop("FluorescentCells contains an empty parsed channel.")
if (nrow(fc_roi_summary) != 1L ||
    fc_roi_summary$roi_mask_status[[1L]] != "REVIEWED_ROI_APPLIED" ||
    fc_roi_summary$excluded_pixel_count[[1L]] <= 0L) {
  stop("FluorescentCells reviewed artifact ROI was not applied and audited.")
}
if (fc_qc$n_cells[[1L]] >= 20L) {
  stop("FluorescentCells annotation artifact still contributes to the segmented cell count.")
}
fc_target <- dt_fc[marker == "Tubulin"]
if (!nrow(fc_target) || all(!is.finite(fc_target$mean_intensity))) stop("FluorescentCells target channel is not quantitatively evaluable.")
cat(sprintf("FluorescentCells PASS: %d compartments quantified, ImageJ axes and QC verified.\n", nrow(dt_fc)))
print(dt_fc[, .(compartment, marker, mean_intensity, integrated_intensity, positive_area_fraction)])

# ==============================================================================
# B. Confocal-Series Z-Stack Projections Validation
# ==============================================================================
cat("\n=== Validating Dataset B: confocal-series Z-Stack Projections ===\n")
z_modes <- c("max_projection", "mean_projection", "single_plane")
z_results <- list()

for (zm in z_modes) {
  cs_outdir <- file.path(root, "work", paste0("public_cs_", zm, "_output"))
  if (dir.exists(cs_outdir)) unlink(cs_outdir, recursive = TRUE)

  cs_manifest <- data.table(
    image_id = paste0("ConfocalSeries_", zm),
    biological_unit_id = "PublicSample_02",
    condition = "standard",
    modality = "immunofluorescence",
    marker = c("Confocal_Channel_1", "Confocal_Channel_2"),
    channel_name = c("Confocal_C1", "Confocal_C2"),
    channel_index = c(1L, 2L),
    channel_role = c("nucleus", "target"),
    pixel_size_um = 0.5,
    z_spacing_um = 0.2,
    timepoint = "T0",
    batch = "BATCH_PUBLIC",
    replicate = 1L,
    file_path = file_cs
  )
  cs_manifest_path <- file.path(cache_dir, paste0("cs_manifest_", zm, ".csv"))
  fwrite(cs_manifest, cs_manifest_path)

  cfg_dt <- data.table(parameter = "z_mode", value = zm)
  cfg_path <- file.path(cache_dir, paste0("cs_config_", zm, ".csv"))
  fwrite(cfg_dt, cfg_path)

  cmd_cs <- sprintf(
    "Rscript %s --manifest=%s --outdir=%s --config=%s --condition-order=%s --local-lib=%s",
    shQuote(file.path(root, "scripts", "run_if_quantification.R")),
    shQuote(cs_manifest_path),
    shQuote(cs_outdir),
    shQuote(cfg_path),
    shQuote("standard"),
    shQuote(local_lib)
  )
  status_cs <- system(cmd_cs)
  if (status_cs != 0L) stop(sprintf("Confocal series run with %s failed.", zm))

  dt_cs <- fread(file.path(cs_outdir, "source_data", "if_compartment_summary.csv"))
  cs_meta <- fread(file.path(cs_outdir, "source_data", "if_channel_metadata.csv"))
  if (nrow(cs_meta) != 2L || !all(cs_meta$dim_z == 25L)) stop(sprintf("Confocal %s run did not preserve 2-channel x 25-slice metadata.", zm))
  if (length(unique(cs_meta$raw_max)) < 2L) stop(sprintf("Confocal %s run collapsed the two channels.", zm))
  z_results[[zm]] <- dt_cs[compartment == "global"]
}

dt_z_comp <- rbindlist(z_results)
cat("Confocal series Z-projection comparison:\n")
print(dt_z_comp[, .(image_id, mean_intensity, median_intensity, max_intensity, integrated_intensity)])

# Verify projection relationships:
# Max projection max_intensity >= Mean projection max_intensity
max_proj_max <- dt_z_comp[grepl("max_projection", image_id), max_intensity][1L]
mean_proj_max <- dt_z_comp[grepl("mean_projection", image_id), max_intensity][1L]

if (max_proj_max < mean_proj_max) {
  stop("Z-stack projection contract violated: Max projection max < Mean projection max")
}
cat(sprintf("PASS: Z-Stack projection contract verified (MaxProj Max: %.3f >= MeanProj Max: %.3f)\n",
            max_proj_max, mean_proj_max))

cat("\nALL PUBLIC IMAGE SMOKE TESTS COMPLETED SUCCESSFULLY!\n")
