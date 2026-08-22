#!/usr/bin/env Rscript
# run_if_quantification.R
# Master Execution Controller for Immunofluorescence (IF) Modality Quantification.
# Part of IHC/IF Quantification Skill v2.3.0-alpha.2

options(stringsAsFactors = FALSE, scipen = 999)

parse_cli <- function(x) {
  out <- list()
  for (arg in x) {
    if (!grepl("^--[^=]+=", arg)) stop("Arguments must use --key=value: ", arg)
    pair <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    out[[pair[[1L]]]] <- paste(pair[-1L], collapse = "=")
  }
  out
}

parse_bool <- function(x) {
  value <- tolower(trimws(as.character(x)))
  if (value %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (value %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop("Cannot parse logical value: ", x)
}

cli <- parse_cli(commandArgs(trailingOnly = TRUE))
required_cli <- c("manifest", "outdir")
missing_cli <- required_cli[!required_cli %in% names(cli)]
if (length(missing_cli)) stop("Required arguments missing: ", paste0("--", missing_cli, collapse = ", "))

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this tool with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
source(file.path(script_dir, "path_utils.R"))

manifest_path <- normalize_path_portable(cli$manifest, must_work = TRUE)
outdir <- normalize_path_portable(cli$outdir, must_work = FALSE)

# Create output folder hierarchy
for (subdir in c(
  "source_data", "config", "work",
  "qc/overview", "qc/channels", "qc/segmentation",
  "qc/roi", "qc/colocalization", "qc/puncta", "qc/masks",
  "figures/main", "figures/supporting"
)) dir.create(file.path(outdir, subdir), recursive = TRUE, showWarnings = FALSE)

dir.create(file.path(outdir, "work", "font-cache"), recursive = TRUE, showWarnings = FALSE)
Sys.setenv(XDG_CACHE_HOME = file.path(outdir, "work", "font-cache"))

local_lib <- normalize_optional_dir(cli$`local-lib`)
if (!is.null(local_lib)) {
  .libPaths(c(local_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
  library(ggplot2)
  library(ragg)
  library(svglite)
})

# Source IF helper modules
source(file.path(script_dir, "if_io_helpers.R"))
source(file.path(script_dir, "if_preprocessing.R"))
source(file.path(script_dir, "if_segmentation.R"))
source(file.path(script_dir, "if_quantification_helpers.R"))
source(file.path(script_dir, "if_colocalization.R"))
source(file.path(script_dir, "if_puncta.R"))
source(file.path(script_dir, "if_qc_helpers.R"))
source(file.path(script_dir, "if_plot_helpers.R"))

# Default IF Configuration
if_default_config <- function() {
  list(
    z_mode = "max_projection",
    bg_method = "top_hat",
    bg_radius = 25,
    segmentation_engine = "ebimage",
    nuc_threshold_method = "otsu",
    nuc_threshold_value = NULL,
    nuc_min_area = 20,
    nuc_max_area = 5000,
    cell_propagation_radius = 15,
    max_cytoplasm_expansion_radius = 10,
    cytoplasm_boundary_gap_px = 1,
    nuc_watershed_tolerance = 1.0,
    nuc_watershed_ext = 1,
    refine_dense_nuclei = TRUE,
    pos_threshold_method = "otsu",
    pos_threshold_value = NULL,
    colocalization_enabled = FALSE,
    puncta_enabled = FALSE,
    puncta_sigma1 = 1.0,
    puncta_sigma2 = 2.5,
    puncta_threshold_sd = 3.0
  )
}

read_if_config <- function(path = NULL) {
  cfg <- if_default_config()
  if (is.null(path) || !file.exists(path)) return(cfg)
  tab <- fread(normalize_path_portable(path, must_work = TRUE))
  if (!all(c("parameter", "value") %in% names(tab))) return(cfg)
  for (i in seq_len(nrow(tab))) {
    p <- trimws(tab$parameter[i])
    v <- trimws(tab$value[i])
    if (p %in% names(cfg)) {
      if (is.logical(cfg[[p]])) {
        cfg[[p]] <- parse_bool(v)
      } else if (is.numeric(cfg[[p]])) {
        cfg[[p]] <- as.numeric(v)
      } else {
        cfg[[p]] <- v
      }
    }
  }
  cfg
}

config_path <- if (!is.null(cli$config) && nzchar(cli$config)) cli$config else NULL
cfg <- read_if_config(config_path)

# Save effective config
cfg_dt <- data.table(parameter = names(cfg), value = vapply(cfg, function(x) paste(x, collapse = ","), character(1L)))
fwrite(cfg_dt, file.path(outdir, "config", "if_analysis_parameters_used.csv"))

# Load manifest
manifest <- fread(manifest_path)
validate_if_manifest(manifest)
fwrite(manifest, file.path(outdir, "config", "if_manifest_used.csv"))

# Optional ROI annotations
roi_path <- if (!is.null(cli$roi) && nzchar(cli$roi)) cli$roi else NULL
roi_dt <- if (!is.null(roi_path) && file.exists(roi_path)) fread(roi_path) else NULL
if (!is.null(roi_dt)) fwrite(roi_dt, file.path(outdir, "config", "if_roi_annotations_used.csv"))

cat("Starting IF quantification on", uniqueN(manifest$image_id), "images...\n")

# Aggregator collectors
all_channel_meta <- list()
all_channel_qc <- list()
all_compartment_summaries <- list()
all_cell_summaries <- list()
all_colocalization_summaries <- list()
all_puncta_summaries <- list()
all_image_qc <- list()
all_roi_summaries <- list()

image_ids <- unique(manifest$image_id)

for (idx in seq_along(image_ids)) {
  img_id <- image_ids[idx]
  img_rows <- manifest[image_id == img_id]
  cat(sprintf("[%02d/%02d] Processing IF Image: %s\n", idx, length(image_ids), img_id))

  # Resolve file path
  img_file_raw <- img_rows$file_path[1L]
  img_file <- resolve_path_portable(img_file_raw, base_dir = dirname(manifest_path), must_work = TRUE)

  # 1. Read and parse channels
  read_res <- read_if_image(img_file, img_rows, z_mode = cfg$z_mode)
  channels <- read_res$channels
  ch_meta <- read_res$channel_meta
  all_channel_meta[[length(all_channel_meta) + 1L]] <- ch_meta

  # Apply only reviewed polygon ROIs from the optional IF ROI table.  Raw files
  # remain untouched; pixels outside an include ROI or inside an exclude ROI
  # are masked only for segmentation, quantification, and diagnostic panels.
  roi_res <- build_if_analysis_mask(
    roi_dt = roi_dt,
    image_id = img_id,
    nr = nrow(channels[[1L]]),
    nc = ncol(channels[[1L]])
  )
  if (!all(roi_res$analysis_mask)) {
    for (ch_name in names(channels)) {
      ch_mat <- channels[[ch_name]]
      ch_mat[!roi_res$analysis_mask] <- 0
      channels[[ch_name]] <- ch_mat
    }
    ch_meta[, `:=`(
      roi_mask_status = roi_res$status,
      included_pixel_count = roi_res$included_pixel_count,
      excluded_pixel_count = roi_res$excluded_pixel_count
    )]
    all_channel_meta[[length(all_channel_meta)]] <- ch_meta
  }
  all_roi_summaries[[length(all_roi_summaries) + 1L]] <- data.table(
    image_id = img_id,
    included_roi_ids = if (length(roi_res$include_roi_ids)) paste(roi_res$include_roi_ids, collapse = ";") else "NONE",
    excluded_roi_ids = if (length(roi_res$exclude_roi_ids)) paste(roi_res$exclude_roi_ids, collapse = ";") else "NONE",
    roi_mask_status = roi_res$status,
    included_pixel_count = roi_res$included_pixel_count,
    excluded_pixel_count = roi_res$excluded_pixel_count,
    included_fraction = roi_res$included_pixel_count / (nrow(roi_res$analysis_mask) * ncol(roi_res$analysis_mask))
  )

  # Identify roles
  nuc_row <- img_rows[tolower(channel_role) == "nucleus"][1L]
  target_rows <- img_rows[tolower(channel_role) == "target"]
  cyto_ref_row <- img_rows[tolower(channel_role) %in% c("cytoplasm_reference", "structural_reference")][1L]

  nuc_ch_name <- nuc_row$channel_name
  nuc_raw_mat <- channels[[nuc_ch_name]]

  # A structural/cytoplasm reference is optional.  Do not evaluate is.na() on
  # a zero-row data.table: ImageJ confocal manifests may legitimately contain
  # only nucleus + target channels.
  cyto_ref_mat <- if (nrow(cyto_ref_row) > 0L &&
                      !is.na(cyto_ref_row$channel_name[[1L]]) &&
                      nzchar(cyto_ref_row$channel_name[[1L]])) {
    channels[[cyto_ref_row$channel_name[[1L]]]]
  } else {
    NULL
  }

  # 2. Preprocess nuclear channel & segmentation
  nuc_prep <- preprocess_if_channel(
    nuc_raw_mat,
    method = cfg$bg_method,
    radius = cfg$bg_radius,
    bit_depth = read_res$image_meta$bit_depth
  )
  nuc_corr_mat <- nuc_prep$corrected_mat

  # Nuclear and 4-compartment segmentation
  seg_res <- segment_if_image(
    nuclear_mat = nuc_corr_mat,
    target_mat = NULL,
    cyto_ref_mat = cyto_ref_mat,
    segmentation_engine = cfg$segmentation_engine,
    nuc_threshold_method = cfg$nuc_threshold_method,
    nuc_threshold_value = cfg$nuc_threshold_value,
    nuc_min_area = cfg$nuc_min_area,
    nuc_max_area = cfg$nuc_max_area,
    cell_propagation_radius = cfg$cell_propagation_radius,
    max_cytoplasm_expansion_radius = cfg$max_cytoplasm_expansion_radius,
    cytoplasm_boundary_gap_px = cfg$cytoplasm_boundary_gap_px,
    nuc_watershed_tolerance = cfg$nuc_watershed_tolerance,
    nuc_watershed_ext = cfg$nuc_watershed_ext,
    refine_dense_nuclei = cfg$refine_dense_nuclei
  )

  # Process each target channel
  img_qc_flags <- character()
  if (roi_res$status == "REVIEWED_ROI_APPLIED") {
    img_qc_flags <- c(img_qc_flags, "REVIEWED_ROI_APPLIED")
  }
  if (seg_res$metrics$segmentation_qc_status != "PASS") {
    img_qc_flags <- c(img_qc_flags, seg_res$metrics$segmentation_qc_status)
  }

  # Prepare for composite
  ch_roles_vec <- structure(img_rows$channel_role, names = img_rows$channel_name)
  composite_rgb <- create_composite_rgb(channels, ch_roles_vec)

  # Process targets
  for (t_idx in seq_len(nrow(target_rows))) {
    t_row <- target_rows[t_idx]
    t_ch_name <- t_row$channel_name
    t_marker <- t_row$marker
    t_raw_mat <- channels[[t_ch_name]]

    # Preprocessing
    t_prep <- preprocess_if_channel(
      t_raw_mat,
      method = cfg$bg_method,
      radius = cfg$bg_radius,
      bit_depth = read_res$image_meta$bit_depth
    )
    t_corr_mat <- t_prep$corrected_mat

    # Saturation & Channel QC
    ch_qc <- compute_channel_qc_metrics(
      raw_mat = t_raw_mat,
      corr_mat = t_corr_mat,
      bit_depth = read_res$image_meta$bit_depth
    )
    ch_qc[, `:=`(
      image_id = img_id,
      channel_name = t_ch_name,
      marker = t_marker,
      channel_role = "target",
      background_method = t_prep$background_method,
      background_estimated = t_prep$background_value
    )]
    all_channel_qc[[length(all_channel_qc) + 1L]] <- ch_qc

    if (ch_qc$channel_qc_flags != "PASS") {
      img_qc_flags <- c(img_qc_flags, ch_qc$channel_qc_flags)
    }

    # Positivity Threshold
    th_res <- calculate_positivity_threshold(
      channel_mat = t_corr_mat,
      method = cfg$pos_threshold_method,
      manual_val = cfg$pos_threshold_value
    )

    # Empty channels are non-evaluable, never zero-threshold positive.
    pos_mask <- if (identical(th_res$threshold_qc_status, "EMPTY_CHANNEL") || is.na(th_res$threshold_value)) {
      matrix(FALSE, nrow = nrow(t_corr_mat), ncol = ncol(t_corr_mat))
    } else {
      t_corr_mat >= th_res$threshold_value
    }
    if (identical(th_res$threshold_qc_status, "EMPTY_CHANNEL")) {
      img_qc_flags <- c(img_qc_flags, "EMPTY_CHANNEL")
    }

    # Four-compartment quantification
    pix_size <- if (!is.na(t_row$pixel_size_um)) as.numeric(t_row$pixel_size_um) else 1.0
    comp_df <- quantify_if_compartments(
      channel_mat = t_corr_mat,
      seg_res = seg_res,
      marker_name = t_marker,
      channel_name = t_ch_name,
      image_id = img_id,
      biological_unit_id = t_row$biological_unit_id,
      condition = t_row$condition,
      threshold_res = th_res,
      pixel_size_um = pix_size
    )
    all_compartment_summaries[[length(all_compartment_summaries) + 1L]] <- comp_df

    # Single cell quantification
    cell_df <- quantify_if_single_cells(
      channel_mat = t_corr_mat,
      seg_res = seg_res,
      marker_name = t_marker,
      channel_name = t_ch_name,
      image_id = img_id,
      biological_unit_id = t_row$biological_unit_id,
      condition = t_row$condition,
      threshold_val = th_res$threshold_value,
      pixel_size_um = pix_size
    )
    if (nrow(cell_df) > 0) {
      all_cell_summaries[[length(all_cell_summaries) + 1L]] <- cell_df
    }

    # Puncta detection if enabled or target marker indicates punctate foci
    is_puncta_marker <- grepl("gamma|h2ax|foci|puncta|lc3|fish", tolower(t_marker)) ||
                        grepl("foci|puncta", tolower(t_ch_name))
    if (cfg$puncta_enabled || is_puncta_marker) {
      p_res <- detect_if_puncta(
        channel_mat = t_corr_mat,
        seg_res = seg_res,
        marker_name = t_marker,
        channel_name = t_ch_name,
        image_id = img_id,
        biological_unit_id = t_row$biological_unit_id,
        condition = t_row$condition,
        sigma1 = cfg$puncta_sigma1,
        sigma2 = cfg$puncta_sigma2,
        threshold_sd_multiplier = cfg$puncta_threshold_sd,
        pixel_size_um = pix_size
      )
      all_puncta_summaries[[length(all_puncta_summaries) + 1L]] <- p_res$summary
    }

    # Render 8-Panel QC Overview for primary target
    if (t_idx == 1L) {
      qc_flags_summary <- if (length(img_qc_flags)) paste(unique(img_qc_flags), collapse = ";") else "PASS"
      qc_out_png <- file.path(outdir, "qc", "overview", paste0(img_id, "_if_8panel_qc.png"))
      render_if_8panel_qc(
        out_path = qc_out_png,
        nuc_mat = nuc_raw_mat,
        target_mat = t_raw_mat,
        target_corr_mat = t_corr_mat,
        seg_res = seg_res,
        pos_mask = pos_mask,
        composite_rgb = composite_rgb,
        image_id = img_id,
        qc_flags_str = qc_flags_summary,
        analysis_mask = roi_res$analysis_mask
      )
    }
  }

  # Colocalization if dual target
  if ((cfg$colocalization_enabled || nrow(target_rows) >= 2L) && nrow(target_rows) >= 2L) {
    t1_mat <- channels[[target_rows$channel_name[1L]]]
    t2_mat <- channels[[target_rows$channel_name[2L]]]
    coloc_df <- compute_if_colocalization(
      channel_A_mat = t1_mat,
      channel_B_mat = t2_mat,
      mask = seg_res$tissue_mask,
      marker_A = target_rows$marker[1L],
      marker_B = target_rows$marker[2L],
      image_id = img_id,
      biological_unit_id = img_rows$biological_unit_id[1L],
      condition = img_rows$condition[1L],
      compartment = "global"
    )
    all_colocalization_summaries[[length(all_colocalization_summaries) + 1L]] <- coloc_df
  }

  # Record Image-level QC
  final_qc_flags <- if (length(img_qc_flags)) paste(unique(img_qc_flags), collapse = ";") else "PASS"
  all_image_qc[[length(all_image_qc) + 1L]] <- data.table(
    image_id = img_id,
    biological_unit_id = img_rows$biological_unit_id[1L],
    condition = img_rows$condition[1L],
    n_cells = seg_res$n_cells,
    requested_cell_propagation_radius = seg_res$metrics$requested_cell_propagation_radius,
    max_cytoplasm_expansion_radius = seg_res$metrics$max_cytoplasm_expansion_radius,
    effective_cell_propagation_radius = seg_res$metrics$effective_cell_propagation_radius,
    cytoplasm_boundary_gap_px = seg_res$metrics$cytoplasm_boundary_gap_px,
    nuc_watershed_tolerance = seg_res$metrics$nuc_watershed_tolerance,
    nuc_watershed_ext = seg_res$metrics$nuc_watershed_ext,
    dense_nucleus_watershed_refinement = seg_res$metrics$dense_nucleus_watershed_refinement,
    nuclear_area_fraction = seg_res$metrics$nuclear_area_fraction,
    cytoplasmic_area_fraction = seg_res$metrics$cytoplasmic_area_fraction,
    extracellular_area_fraction = seg_res$metrics$extracellular_area_fraction,
    qc_flags = final_qc_flags,
    qc_status = if (grepl("HIGH_SATURATION|NO_SIGNAL|EMPTY_CHANNEL|NO_CELLS|NO_TISSUE|SEGMENTATION_SUSPECT", final_qc_flags)) {
      "FAIL_REVIEW_REQUIRED"
    } else "PASS"
  )
}

# Consolidate and export source data
channel_qc_dt <- rbindlist(all_channel_qc, fill = TRUE)
compartment_dt <- rbindlist(all_compartment_summaries, fill = TRUE)
cell_dt <- rbindlist(all_cell_summaries, fill = TRUE)
image_qc_dt <- rbindlist(all_image_qc, fill = TRUE)
roi_summary_dt <- rbindlist(all_roi_summaries, fill = TRUE)

fwrite(channel_qc_dt, file.path(outdir, "source_data", "if_channel_summary.csv"))
fwrite(compartment_dt, file.path(outdir, "source_data", "if_compartment_summary.csv"))
if (nrow(cell_dt) > 0) {
  fwrite(cell_dt, file.path(outdir, "source_data", "if_cell_summary.csv.gz"))
}
fwrite(image_qc_dt, file.path(outdir, "source_data", "if_image_qc.csv"))
fwrite(roi_summary_dt, file.path(outdir, "source_data", "if_roi_exclusion_summary.csv"))

channel_meta_dt <- rbindlist(all_channel_meta, fill = TRUE)
fwrite(channel_meta_dt, file.path(outdir, "source_data", "if_channel_metadata.csv"))

# Biological Unit Aggregation
bio_unit_dt <- aggregate_if_biological_units(compartment_dt)
fwrite(bio_unit_dt, file.path(outdir, "source_data", "if_biological_unit_summary.csv"))

# Primary Domain Summary Long table (strictly matching specification)
primary_long_dt <- compartment_dt[, .(
  image_id, biological_unit_id, condition, marker,
  measurement_domain = compartment,
  mean_intensity, median_intensity, integrated_intensity,
  positive_area_fraction
)]
fwrite(primary_long_dt, file.path(outdir, "source_data", "if_primary_domain_summary_long.csv"))

# Colocalization and Puncta summaries
if (length(all_colocalization_summaries)) {
  coloc_dt <- rbindlist(all_colocalization_summaries, fill = TRUE)
  fwrite(coloc_dt, file.path(outdir, "source_data", "if_colocalization_summary.csv"))
}
if (length(all_puncta_summaries)) {
  puncta_dt <- rbindlist(all_puncta_summaries, fill = TRUE)
  fwrite(puncta_dt, file.path(outdir, "source_data", "if_puncta_summary.csv"))
}

# Generate Manual QC Template
manual_qc <- data.table(
  image_id = image_ids,
  HUMAN_APPROVED = "PENDING",
  reviewer = "",
  review_date = as.character(Sys.Date()),
  channel_mapping_approved = "PENDING",
  segmentation_approved = "PENDING",
  threshold_approved = "PENDING",
  comments = ""
)
fwrite(manual_qc, file.path(outdir, "source_data", "if_manual_qc_template.csv"))

# Render Publication Figures (Figures 1 - 4 + optional 5, 6)
blocking_qc <- image_qc_dt[qc_status == "FAIL_REVIEW_REQUIRED"]
if (nrow(blocking_qc) > 0L) {
  run_status <- data.table(
    run_status = "BLOCKED_QC",
    qc_status = "FAIL_REVIEW_REQUIRED",
    blocked_images = paste(blocking_qc$image_id, collapse = ";"),
    reason = paste(unique(blocking_qc$qc_flags), collapse = ";")
  )
  fwrite(run_status, file.path(outdir, "source_data", "if_run_status.csv"))
  stop("IF quantification blocked by required QC review: ", paste(blocking_qc$image_id, collapse = ", "))
}

cat("Rendering publication figures (Figures 1-6)...\n")
cond_order <- if (!is.null(cli$`condition-order`)) strsplit(cli$`condition-order`, ",", fixed = TRUE)[[1L]] else NULL

fig_records <- list()

# Figure 1: Global Mean Intensity
fig1_data <- bio_unit_dt[compartment == "global"]
if (nrow(fig1_data) > 0) {
  f1_res <- render_if_biological_figure(
    plot_data = fig1_data,
    metric_col = "mean_intensity",
    metric_label = "Global Mean Fluorescence Intensity",
    title_str = "Figure 1: Global Target Fluorescence",
    out_stem = file.path(outdir, "figures", "main", "if_main_01_global_mean_intensity"),
    condition_order = cond_order
  )
  if (!is.null(f1_res)) {
    fig_records[[1L]] <- data.table(figure_id = "Figure_1", metric = "global_mean_intensity", png = f1_res$png, svg = f1_res$svg, pdf = f1_res$pdf)
  }
}

# Figure 2: Nuclear Mean Intensity
fig2_data <- bio_unit_dt[compartment == "nucleus"]
if (nrow(fig2_data) > 0) {
  f2_res <- render_if_biological_figure(
    plot_data = fig2_data,
    metric_col = "mean_intensity",
    metric_label = "Nuclear Mean Fluorescence Intensity",
    title_str = "Figure 2: Nuclear Target Fluorescence",
    out_stem = file.path(outdir, "figures", "main", "if_main_02_nuclear_mean_intensity"),
    condition_order = cond_order
  )
  if (!is.null(f2_res)) {
    fig_records[[2L]] <- data.table(figure_id = "Figure_2", metric = "nuclear_mean_intensity", png = f2_res$png, svg = f2_res$svg, pdf = f2_res$pdf)
  }
}

# Figure 3: Cytoplasmic Mean Intensity
fig3_data <- bio_unit_dt[compartment == "cytoplasm"]
if (nrow(fig3_data) > 0) {
  f3_res <- render_if_biological_figure(
    plot_data = fig3_data,
    metric_col = "mean_intensity",
    metric_label = "Cytoplasmic Mean Fluorescence Intensity",
    title_str = "Figure 3: Cytoplasmic Target Fluorescence",
    out_stem = file.path(outdir, "figures", "main", "if_main_03_cytoplasmic_mean_intensity"),
    condition_order = cond_order
  )
  if (!is.null(f3_res)) {
    fig_records[[3L]] <- data.table(figure_id = "Figure_3", metric = "cytoplasmic_mean_intensity", png = f3_res$png, svg = f3_res$svg, pdf = f3_res$pdf)
  }
}

# Figure 4: Extracellular Positive Area Fraction
fig4_data <- bio_unit_dt[compartment == "extracellular"]
if (nrow(fig4_data) > 0) {
  f4_res <- render_if_biological_figure(
    plot_data = fig4_data,
    metric_col = "positive_area_fraction",
    metric_label = "Extracellular Positive Area Fraction",
    title_str = "Figure 4: Extracellular Signal Fraction",
    out_stem = file.path(outdir, "figures", "main", "if_main_04_extracellular_positive_fraction"),
    condition_order = cond_order,
    y_min = 0, y_max = 1
  )
  if (!is.null(f4_res)) {
    fig_records[[4L]] <- data.table(figure_id = "Figure_4", metric = "extracellular_positive_fraction", png = f4_res$png, svg = f4_res$svg, pdf = f4_res$pdf)
  }
}

# Figure 5: Colocalization if present
if (exists("coloc_dt") && nrow(coloc_dt) > 0) {
  f5_res <- render_if_biological_figure(
    plot_data = coloc_dt,
    metric_col = "pearson_r",
    metric_label = "Pearson Correlation Coefficient (r)",
    title_str = "Figure 5: Colocalization Association",
    out_stem = file.path(outdir, "figures", "main", "if_main_05_colocalization_pearson_r"),
    condition_order = cond_order,
    y_min = -1, y_max = 1
  )
  if (!is.null(f5_res)) {
    fig_records[[5L]] <- data.table(figure_id = "Figure_5", metric = "colocalization_pearson_r", png = f5_res$png, svg = f5_res$svg, pdf = f5_res$pdf)
  }
}

# Figure 6: Puncta per cell if present
if (exists("puncta_dt") && nrow(puncta_dt) > 0) {
  p_cell_data <- puncta_dt[compartment == "global"]
  f6_res <- render_if_biological_figure(
    plot_data = p_cell_data,
    metric_col = "puncta_count_per_cell",
    metric_label = "Puncta Count per Cell",
    title_str = "Figure 6: Puncta / Foci Quantification",
    out_stem = file.path(outdir, "figures", "main", "if_main_06_puncta_per_cell"),
    condition_order = cond_order
  )
  if (!is.null(f6_res)) {
    fig_records[[6L]] <- data.table(figure_id = "Figure_6", metric = "puncta_per_cell", png = f6_res$png, svg = f6_res$svg, pdf = f6_res$pdf)
  }
}

fig_manifest <- rbindlist(fig_records, fill = TRUE)
fwrite(fig_manifest, file.path(outdir, "figures", "main", "if_main_figure_manifest.csv"))

fwrite(data.table(
  run_status = "PASS",
  qc_status = "PASS",
  blocked_images = "",
  reason = ""
), file.path(outdir, "source_data", "if_run_status.csv"))

cat("IF quantification complete:", uniqueN(manifest$image_id), "images processed.\n")
