#!/usr/bin/env Rscript

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
for (subdir in c(
  "source_data", "config", "work",
  "qc/qc_overview", "qc/compartment_overlays", "qc/segmentation_overlays",
  "qc/roi_evidence", "qc/roi_evidence/crops", "qc/stain_channels", "qc/masks",
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
})
source(file.path(script_dir, "ihc_helpers.R"))

read_config <- function(path = NULL) {
  cfg <- ihc_default_config()
  if (is.null(path)) return(cfg)
  tab <- fread(normalize_path_portable(path, must_work = TRUE))
  if (!all(c("parameter", "value") %in% names(tab))) stop("Config must contain parameter and value columns.")
  for (i in seq_len(nrow(tab))) {
    key <- as.character(tab$parameter[[i]])
    value <- as.character(tab$value[[i]])
    if (startsWith(key, "dab_threshold_")) {
      threshold_name <- sub("^dab_threshold_", "", key)
      if (threshold_name %in% names(cfg$dab_thresholds)) cfg$dab_thresholds[[threshold_name]] <- as.numeric(value)
    } else if (key %in% names(cfg) && key != "version") {
      if (is.logical(cfg[[key]])) cfg[[key]] <- parse_bool(value)
      else if (is.numeric(cfg[[key]])) cfg[[key]] <- as.numeric(value)
      else cfg[[key]] <- value
    }
  }
  thresholds <- unname(cfg$dab_thresholds[c("negative", "weak", "moderate")])
  if (any(!is.finite(thresholds)) || any(diff(thresholds) <= 0)) stop("DAB thresholds must be finite and strictly increasing.")
  cfg$cell_scoring_domain <- tolower(as.character(cfg$cell_scoring_domain))
  if (!cfg$cell_scoring_domain %in% c("cytoplasm", "nucleus", "whole_cell")) stop("cell_scoring_domain must be cytoplasm, nucleus, or whole_cell.")
  cfg$plot_summary_stat <- tolower(as.character(cfg$plot_summary_stat))
  if (!cfg$plot_summary_stat %in% c("mean", "median")) stop("plot_summary_stat must be mean or median.")
  cfg$plot_errorbar <- tolower(as.character(cfg$plot_errorbar))
  if (!cfg$plot_errorbar %in% c("se", "sd", "iqr", "none")) stop("plot_errorbar must be se, sd, iqr, or none.")
  cfg$plot_axis_mode <- tolower(as.character(cfg$plot_axis_mode))
  if (!cfg$plot_axis_mode %in% c("fixed", "data")) stop("plot_axis_mode must be fixed or data.")
  for (width_name in c("plot_subtitle_width", "plot_caption_width")) {
    cfg[[width_name]] <- as.integer(round(cfg[[width_name]]))
    if (!is.finite(cfg[[width_name]]) || cfg[[width_name]] < 20L) stop(width_name, " must be an integer >= 20.")
  }
  if (!is.finite(cfg$qc_od_display_upper_quantile) || cfg$qc_od_display_upper_quantile < 0.5 || cfg$qc_od_display_upper_quantile > 1) {
    stop("qc_od_display_upper_quantile must be between 0.5 and 1.")
  }
  for (alpha_name in c("qc_overlay_fill_alpha", "qc_overlay_boundary_alpha")) {
    if (!is.finite(cfg[[alpha_name]]) || cfg[[alpha_name]] < 0 || cfg[[alpha_name]] > 1) stop(alpha_name, " must be between 0 and 1.")
  }
  if (!is.finite(cfg$max_image_pixels) || cfg$max_image_pixels <= 0) stop("max_image_pixels must be positive.")
  cfg
}

resolve_source <- function(path, base_dir) {
  resolve_path_portable(as.character(path), base_dir = base_dir, must_work = TRUE)
}

normalise_manifest <- function(path) {
  manifest <- fread(path)
  aliases <- list(
    biological_unit_id = c("biological_unit_id", "patient_id", "animal_id", "sample_id"),
    field_id = c("field_id", "field", "image_field")
  )
  for (target in names(aliases)) {
    if (!target %in% names(manifest)) {
      found <- aliases[[target]][aliases[[target]] %in% names(manifest)]
      if (length(found)) setnames(manifest, found[[1]], target)
    }
  }
  required <- c("image_id", "biological_unit_id", "condition", "field_id", "source_file")
  missing <- setdiff(required, names(manifest))
  if (length(missing)) stop("Manifest missing columns: ", paste(missing, collapse = ", "))
  if (!"analysis_status" %in% names(manifest)) manifest[, analysis_status := "include"]
  if (!"batch_id" %in% names(manifest)) manifest[, batch_id := "batch_1"]
  if (!"pixel_size_um" %in% names(manifest)) manifest[, pixel_size_um := NA_real_]
  if (!"magnification" %in% names(manifest)) manifest[, magnification := NA_character_]
  if (!"marker" %in% names(manifest)) manifest[, marker := NA_character_]
  if (!"tissue_type" %in% names(manifest)) manifest[, tissue_type := NA_character_]
  if (!"is_negative_control" %in% names(manifest)) manifest[, is_negative_control := FALSE]

  manifest[, `:=`(
    image_id = as.character(image_id),
    biological_unit_id = as.character(biological_unit_id),
    condition = as.character(condition),
    field_id = as.character(field_id),
    batch_id = as.character(batch_id),
    marker = as.character(marker),
    tissue_type = as.character(tissue_type),
    analysis_status = tolower(as.character(analysis_status)),
    pixel_size_um = suppressWarnings(as.numeric(pixel_size_um)),
    source_file_original = source_file
  )]
  manifest[is.na(batch_id) | batch_id == "", batch_id := "batch_1"]
  manifest[is.na(marker) | marker == "", marker := "unspecified_marker"]
  manifest[is.na(tissue_type) | tissue_type == "", tissue_type := "unspecified_tissue"]
  manifest <- manifest[analysis_status %in% c("include", "included")]
  if (!nrow(manifest)) stop("No included images remain in the manifest.")
  if (anyDuplicated(manifest$image_id)) stop("image_id values must be unique.")
  manifest[, source_file := vapply(source_file, resolve_source, character(1), base_dir = dirname(path))]
  if (any(!file.exists(manifest$source_file))) stop("One or more source images do not exist.")
  wsi_ext <- grepl("\\.(svs|ndpi|mrxs|scn)$", tolower(manifest$source_file))
  if (any(wsi_ext)) stop("Whole-slide formats require tiling or QuPath-exported fields/masks before this EBImage pipeline: ", paste(manifest$image_id[wsi_ext], collapse = ", "))
  manifest
}

cfg <- read_config(cli$config)
manifest <- normalise_manifest(manifest_path)
roi_vertices <- data.table()
if (!is.null(cli$roi)) roi_vertices <- normalise_roi_table(fread(normalize_path_portable(cli$roi, must_work = TRUE)))

parameter_table <- rbindlist(lapply(names(cfg), function(key) {
  value <- cfg[[key]]
  if (key == "dab_thresholds") {
    return(data.table(parameter = paste0("dab_threshold_", names(value)), value = as.character(unname(value))))
  }
  data.table(parameter = key, value = paste(value, collapse = ";"))
}))
fwrite(parameter_table, file.path(outdir, "config", "analysis_parameters_used.csv"))
fwrite(manifest, file.path(outdir, "config", "image_manifest_used.csv"))
if (nrow(roi_vertices)) fwrite(roi_vertices, file.path(outdir, "config", "roi_annotations_used.csv"))

qc_palette <- ihc_qc_palette()
qc_legend <- data.table(
  label = names(qc_palette),
  hex_colour = unname(qc_palette),
  semantics = c(
    "analyzed whole-tissue boundary", "segmented nuclear domain", "propagated cytoplasmic domain",
    "tissue outside propagated cells", "excluded artifact/annotation region", "reviewed tumor ROI",
    "reviewed stroma ROI", "reviewed interface ROI", "other reviewed custom ROI", "artifact ROI"
  )
)
fwrite(qc_legend, file.path(outdir, "source_data", "ihc_qc_color_legend.csv"))

metric_dictionary <- data.table(
  measurement_domain = c("global", "nucleus", "cytoplasm", "extracellular"),
  default_metric = c("tissue_positive_area_fraction", "nuclear_h_score", "cytoplasm_h_score", "extracellular_positive_area_fraction"),
  metric_type = c("pixel_based", "cell_based", "cell_based", "pixel_based"),
  valid_range = c("0_to_1", "0_to_300", "0_to_300", "0_to_1"),
  default_figure = c("01_global_dab_burden", "02_nuclear_h_score", "03_cytoplasmic_h_score", "04_extracellular_dab_burden"),
  interpretation = c(
    "DAB-positive fraction of analyzed tissue pixels",
    "Nuclear cell intensity-class H-score",
    "Cytoplasmic cell intensity-class H-score",
    "DAB-positive fraction of tissue pixels outside propagated cells"
  )
)
fwrite(metric_dictionary, file.path(outdir, "source_data", "ihc_metric_dictionary.csv"))

qc_limit <- if (!is.null(cli$`qc-limit`)) as.integer(cli$`qc-limit`) else 0L
if (!is.finite(qc_limit) || qc_limit < 0L) stop("--qc-limit must be a non-negative integer.")
write_stain_channels <- if (!is.null(cli$`write-stain-channels`)) parse_bool(cli$`write-stain-channels`) else isTRUE(cfg$write_stain_channels)
generate_qc_overview <- if (!is.null(cli$`generate-qc-overview`)) parse_bool(cli$`generate-qc-overview`) else isTRUE(cfg$generate_qc_overview)
generate_roi_triplets <- if (!is.null(cli$`generate-roi-triplets`)) parse_bool(cli$`generate-roi-triplets`) else isTRUE(cfg$generate_roi_triplets)
generate_main_plots <- if (!is.null(cli$`generate-main-plots`)) parse_bool(cli$`generate-main-plots`) else isTRUE(cfg$generate_main_plots)

cell_results <- vector("list", nrow(manifest))
region_results <- vector("list", nrow(manifest))
qc_results <- vector("list", nrow(manifest))
roi_registry_results <- vector("list", nrow(manifest))
roi_overlap_results <- vector("list", nrow(manifest))
cell_membership_results <- vector("list", nrow(manifest))
scale_results <- vector("list", nrow(manifest))
errors <- list()

for (i in seq_len(nrow(manifest))) {
  row <- manifest[i]
  message(sprintf("[%02d/%02d] %s", i, nrow(manifest), row$image_id))
  result <- tryCatch(
    analyse_ihc_image(
      row$source_file,
      cfg = cfg,
      pixel_size_um = row$pixel_size_um,
      roi_vertices = roi_vertices,
      image_id = row$image_id
    ),
    error = function(e) {
      errors[[length(errors) + 1L]] <<- data.table(
        image_id = row$image_id,
        source_file = row$source_file,
        error = conditionMessage(e)
      )
      NULL
    }
  )
  if (is.null(result)) next

  meta <- list(
    image_id = row$image_id,
    biological_unit_id = row$biological_unit_id,
    condition = row$condition,
    field_id = row$field_id,
    batch_id = row$batch_id,
    marker = row$marker,
    tissue_type = row$tissue_type
  )

  cells <- copy(result$cells)
  if (nrow(cells)) {
    cells[, `:=`(
      image_id = row$image_id,
      biological_unit_id = row$biological_unit_id,
      condition = row$condition,
      field_id = row$field_id,
      batch_id = row$batch_id,
      marker = row$marker,
      tissue_type = row$tissue_type,
      cell_scoring_domain = result$config$cell_scoring_domain,
      pixel_size_um = result$config$pixel_size_um_effective,
      scale_mode = result$config$scale_mode
    )]
    setcolorder(cells, c("image_id", "biological_unit_id", "condition", "field_id", "batch_id", "marker", "tissue_type", "cell_scoring_domain", setdiff(names(cells), c("image_id", "biological_unit_id", "condition", "field_id", "batch_id", "marker", "tissue_type", "cell_scoring_domain"))))
  }
  cell_results[[i]] <- cells

  global_summary <- summarise_region(
    result,
    region_mask = result$deconv$analysis_mask,
    image_meta = meta,
    roi_id = "GLOBAL",
    compartment = "global",
    selection_source = "automatic",
    selection_method = "whole_tissue"
  )
  summaries <- list(global_summary)

  membership <- list()
  if (nrow(cells)) {
    membership[[1]] <- data.table(image_id = row$image_id, cell_id = cells$cell_id, roi_id = "GLOBAL", compartment = "global", inside_region = TRUE)
  }

  if (length(result$roi_masks$regions)) {
    for (r in seq_along(result$roi_masks$regions)) {
      region <- result$roi_masks$regions[[r]]
      summaries[[length(summaries) + 1L]] <- summarise_region(
        result,
        region_mask = region$mask,
        image_meta = meta,
        roi_id = region$roi_id,
        compartment = region$compartment,
        selection_source = region$selection_source,
        selection_method = region$selection_method
      )
      if (nrow(cells)) {
        cx <- pmax(1L, pmin(dim(region$mask)[1], round(cells$nuc_m.cx)))
        cy <- pmax(1L, pmin(dim(region$mask)[2], round(cells$nuc_m.cy)))
        inside <- region$mask[cbind(cx, cy)] & result$deconv$tissue_mask[cbind(cx, cy)]
        membership[[length(membership) + 1L]] <- data.table(
          image_id = row$image_id,
          cell_id = cells$cell_id[inside],
          roi_id = region$roi_id,
          compartment = region$compartment,
          inside_region = TRUE
        )
      }
    }
  }
  region_table <- rbindlist(summaries, fill = TRUE)
  region_results[[i]] <- region_table
  if (length(membership)) cell_membership_results[[i]] <- rbindlist(membership, fill = TRUE)

  registry <- copy(result$roi_masks$registry)
  global_registry <- data.table(
    image_id = row$image_id,
    roi_id = "GLOBAL",
    compartment = "global",
    action = "include",
    selection_source = "automatic",
    selection_method = "whole_tissue",
    reviewer = NA_character_,
    annotation_status = "selected",
    n_vertices = 0L,
    x_min = 1, x_max = dim(result$image)[1], y_min = 1, y_max = dim(result$image)[2],
    selected_area_px = sum(result$deconv$tissue_mask),
    coordinate_space = "source_image_pixels"
  )
  roi_registry_results[[i]] <- rbindlist(list(global_registry, registry), fill = TRUE)
  roi_overlap_results[[i]] <- copy(result$roi_masks$overlaps)
  qc_row <- make_qc_flags(result, global_summary, result$config)
  qc_row[, `:=`(biological_unit_id = row$biological_unit_id, condition = row$condition, batch_id = row$batch_id, marker = row$marker, tissue_type = row$tissue_type)]
  qc_results[[i]] <- qc_row
  scale_results[[i]] <- data.table(
    image_id = row$image_id,
    pixel_size_um_input = row$pixel_size_um,
    scale_mode = result$config$scale_mode,
    nucleus_min_area_effective_px = result$config$nucleus_min_area_effective_px,
    nucleus_max_area_effective_px = result$config$nucleus_max_area_effective_px,
    cell_expansion_radius_effective_px = result$config$cell_expansion_radius_effective_px,
    local_background_inner_effective_px = result$config$local_background_inner_effective_px,
    local_background_outer_effective_px = result$config$local_background_outer_effective_px,
    nucleus_threshold = result$nuclei$threshold
  )

  if (qc_limit == 0L || i <= qc_limit) {
    image_id_value <- as.character(row$image_id)
    hdab_image <- reconstruct_hdab_image(result)
    rgb_domain_overlay <- paint_compartment_overlay(result, "rgb")
    hdab_domain_overlay <- paint_compartment_overlay(result, "hdab")
    writeImage(paint_segmentation_overlay(result), file.path(outdir, "qc", "segmentation_overlays", paste0(image_id_value, "_segmentation.png")), quality = 95)
    writeImage(rgb_domain_overlay, file.path(outdir, "qc", "compartment_overlays", paste0(image_id_value, "_domains_on_rgb.png")), quality = 95)
    writeImage(hdab_domain_overlay, file.path(outdir, "qc", "compartment_overlays", paste0(image_id_value, "_domains_on_hdab.png")), quality = 95)
    writeImage(hdab_image, file.path(outdir, "qc", "stain_channels", paste0(image_id_value, "_hdab_reconstruction.png")), quality = 95)
    save_roi_overview(result$image, roi_vertices, image_id_value, file.path(outdir, "qc", "roi_evidence", paste0(image_id_value, "_roi_overview_rgb.png")), "ROI selection proof on RGB")
    save_roi_overview(hdab_image, roi_vertices, image_id_value, file.path(outdir, "qc", "roi_evidence", paste0(image_id_value, "_roi_overview_hdab.png")), "ROI selection proof on H-DAB")
    save_roi_contact_sheet(hdab_image, roi_vertices, image_id_value, file.path(outdir, "qc", "roi_evidence", paste0(image_id_value, "_roi_contact_sheet_hdab.png")))
    if (generate_roi_triplets) {
      save_roi_evidence_triplets(result, roi_vertices, image_id_value, file.path(outdir, "qc", "roi_evidence", "crops", image_id_value))
    }
    if (generate_qc_overview) {
      save_qc_overview(result, image_id_value, file.path(outdir, "qc", "qc_overview", paste0(image_id_value, "_qc_overview.png")))
    }
    masks <- compartment_masks(result)
    masks$dab_positive <- dab_positive_mask(result)
    for (mask_name in names(masks)) {
      mask_image <- Image(ifelse(masks[[mask_name]], 1, 0), colormode = Grayscale)
      writeImage(mask_image, file.path(outdir, "qc", "masks", paste0(image_id_value, "_", mask_name, "_mask.png")))
    }
    if (write_stain_channels) {
      h <- scaled_gray_image(result$deconv$hematoxylin_od, result$deconv$analysis_mask)
      d <- scaled_gray_image(result$deconv$dab_od, result$deconv$analysis_mask)
      writeImage(h, file.path(outdir, "qc", "stain_channels", paste0(image_id_value, "_hematoxylin_od.png")))
      writeImage(d, file.path(outdir, "qc", "stain_channels", paste0(image_id_value, "_dab_od.png")))
    }
  }
}

if (length(errors)) fwrite(rbindlist(errors, fill = TRUE), file.path(outdir, "work", "image_errors.tsv"), sep = "\t")
cell_table <- if (any(vapply(cell_results, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) rbindlist(cell_results, fill = TRUE) else data.table()
region_table <- if (any(vapply(region_results, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) rbindlist(region_results, fill = TRUE) else data.table()
qc_table <- if (any(vapply(qc_results, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) rbindlist(qc_results, fill = TRUE) else data.table()
roi_registry <- if (any(vapply(roi_registry_results, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) rbindlist(roi_registry_results, fill = TRUE) else data.table()
roi_overlap_table <- if (any(vapply(roi_overlap_results, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) {
  rbindlist(roi_overlap_results, fill = TRUE)
} else {
  data.table(
    image_id = character(), roi_id_1 = character(), compartment_1 = character(),
    roi_id_2 = character(), compartment_2 = character(), overlap_area_px = integer(),
    overlap_fraction_roi_1 = numeric(), overlap_fraction_roi_2 = numeric(), same_compartment = logical()
  )
}
cell_membership <- if (any(vapply(cell_membership_results, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) rbindlist(cell_membership_results, fill = TRUE) else data.table()
scale_table <- if (any(vapply(scale_results, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) rbindlist(scale_results, fill = TRUE) else data.table()
if (!nrow(region_table)) stop("All images failed; see work/image_errors.tsv.")

if (nrow(cell_table)) {
  setorder(cell_table, biological_unit_id, condition, field_id, image_id, cell_id)
  fwrite(cell_table, file.path(outdir, "source_data", "ihc_cell_measurements.csv.gz"))
}
setorder(region_table, biological_unit_id, condition, field_id, image_id, compartment, roi_id)
fwrite(region_table, file.path(outdir, "source_data", "ihc_region_summary.csv"))
fwrite(qc_table, file.path(outdir, "source_data", "ihc_image_qc.csv"))
fwrite(roi_registry, file.path(outdir, "source_data", "ihc_roi_registry.csv"))
fwrite(roi_overlap_table, file.path(outdir, "source_data", "ihc_roi_overlap_audit.csv"))
fwrite(scale_table, file.path(outdir, "config", "effective_image_parameters.csv"))
if (nrow(cell_membership)) fwrite(cell_membership, file.path(outdir, "source_data", "ihc_cell_region_membership.csv.gz"))

weighted_mean_safe <- function(x, w) {
  keep <- is.finite(x) & is.finite(w) & w > 0
  if (!any(keep)) return(NA_real_)
  stats::weighted.mean(x[keep], w[keep])
}

aggregate_region_rows <- function(tab) {
  tab[, .(
    n_images = uniqueN(image_id),
    n_regions = .N,
    tissue_area_px = sum(tissue_area_px, na.rm = TRUE),
    tissue_positive_area_fraction = sum(tissue_positive_area_px, na.rm = TRUE) / max(1, sum(tissue_area_px, na.rm = TRUE)),
    tissue_mean_dab_od = weighted_mean_safe(tissue_mean_dab_od, tissue_area_px),
    tissue_positive_mean_dab_od = weighted_mean_safe(tissue_positive_mean_dab_od, tissue_positive_area_px),
    tissue_integrated_dab_od = sum(tissue_integrated_dab_od, na.rm = TRUE),
    nuclear_area_px = sum(nuclear_area_px, na.rm = TRUE),
    nuclear_positive_area_px = sum(nuclear_positive_area_px, na.rm = TRUE),
    nuclear_positive_area_fraction = sum(nuclear_positive_area_px, na.rm = TRUE) / max(1, sum(nuclear_area_px, na.rm = TRUE)),
    nuclear_mean_dab_od = weighted_mean_safe(nuclear_mean_dab_od, nuclear_area_px),
    nuclear_positive_mean_dab_od = weighted_mean_safe(nuclear_positive_mean_dab_od, nuclear_positive_area_px),
    nuclear_integrated_dab_od = sum(nuclear_integrated_dab_od, na.rm = TRUE),
    cytoplasm_area_px = sum(cytoplasm_area_px, na.rm = TRUE),
    cytoplasm_positive_area_px = sum(cytoplasm_positive_area_px, na.rm = TRUE),
    cytoplasm_positive_area_fraction = sum(cytoplasm_positive_area_px, na.rm = TRUE) / max(1, sum(cytoplasm_area_px, na.rm = TRUE)),
    cytoplasm_mean_dab_od = weighted_mean_safe(cytoplasm_mean_dab_od, cytoplasm_area_px),
    cytoplasm_positive_mean_dab_od = weighted_mean_safe(cytoplasm_positive_mean_dab_od, cytoplasm_positive_area_px),
    cytoplasm_integrated_dab_od = sum(cytoplasm_integrated_dab_od, na.rm = TRUE),
    extracellular_area_px = sum(extracellular_area_px, na.rm = TRUE),
    extracellular_positive_area_px = sum(extracellular_positive_area_px, na.rm = TRUE),
    extracellular_positive_area_fraction = sum(extracellular_positive_area_px, na.rm = TRUE) / max(1, sum(extracellular_area_px, na.rm = TRUE)),
    extracellular_mean_dab_od = weighted_mean_safe(extracellular_mean_dab_od, extracellular_area_px),
    extracellular_positive_mean_dab_od = weighted_mean_safe(extracellular_positive_mean_dab_od, extracellular_positive_area_px),
    extracellular_integrated_dab_od = sum(extracellular_integrated_dab_od, na.rm = TRUE),
    n_cells = sum(n_cells, na.rm = TRUE),
    positive_cell_fraction = weighted_mean_safe(positive_cell_fraction, n_cells),
    h_score = weighted_mean_safe(h_score, n_cells),
    mean_cell_dab_od = weighted_mean_safe(mean_cell_dab_od, n_cells),
    median_of_region_medians_cell_dab_od = if (any(is.finite(median_cell_dab_od))) stats::median(median_cell_dab_od, na.rm = TRUE) else NA_real_,
    mean_local_background_od = weighted_mean_safe(mean_local_background_od, n_cells),
    nuclear_positive_cell_fraction = weighted_mean_safe(nuclear_positive_cell_fraction, n_cells),
    nuclear_h_score = weighted_mean_safe(nuclear_h_score, n_cells),
    nuclear_mean_cell_dab_od = weighted_mean_safe(nuclear_mean_cell_dab_od, n_cells),
    nuclear_median_of_region_medians_cell_dab_od = if (any(is.finite(nuclear_median_cell_dab_od))) stats::median(nuclear_median_cell_dab_od, na.rm = TRUE) else NA_real_,
    cytoplasm_positive_cell_fraction = weighted_mean_safe(cytoplasm_positive_cell_fraction, n_cells),
    cytoplasm_h_score = weighted_mean_safe(cytoplasm_h_score, n_cells),
    cytoplasm_mean_cell_dab_od = weighted_mean_safe(cytoplasm_mean_cell_dab_od, n_cells),
    cytoplasm_median_of_region_medians_cell_dab_od = if (any(is.finite(cytoplasm_median_cell_dab_od))) stats::median(cytoplasm_median_cell_dab_od, na.rm = TRUE) else NA_real_,
    whole_cell_positive_cell_fraction = weighted_mean_safe(whole_cell_positive_cell_fraction, n_cells),
    whole_cell_h_score = weighted_mean_safe(whole_cell_h_score, n_cells),
    whole_cell_mean_cell_dab_od = weighted_mean_safe(whole_cell_mean_cell_dab_od, n_cells)
  ), by = .(marker, tissue_type, batch_id, biological_unit_id, condition, compartment, cell_scoring_domain)]
}

biological_table <- aggregate_region_rows(region_table)
setorder(biological_table, biological_unit_id, condition, compartment)
fwrite(biological_table, file.path(outdir, "source_data", "ihc_biological_unit_summary.csv"))

primary_domain_summary <- rbindlist(list(
  biological_table[, .(
    marker, tissue_type, batch_id, biological_unit_id, condition, compartment, cell_scoring_domain,
    measurement_domain = "global", metric = "tissue_positive_area_fraction", value = tissue_positive_area_fraction,
    metric_semantics = "pixel_based_global_tissue_dab_positive_area_fraction"
  )],
  biological_table[, .(
    marker, tissue_type, batch_id, biological_unit_id, condition, compartment, cell_scoring_domain,
    measurement_domain = "nucleus", metric = "nuclear_h_score", value = nuclear_h_score,
    metric_semantics = "cell_based_nuclear_h_score_0_to_300"
  )],
  biological_table[, .(
    marker, tissue_type, batch_id, biological_unit_id, condition, compartment, cell_scoring_domain,
    measurement_domain = "cytoplasm", metric = "cytoplasm_h_score", value = cytoplasm_h_score,
    metric_semantics = "cell_based_cytoplasmic_h_score_0_to_300"
  )],
  biological_table[, .(
    marker, tissue_type, batch_id, biological_unit_id, condition, compartment, cell_scoring_domain,
    measurement_domain = "extracellular", metric = "extracellular_positive_area_fraction", value = extracellular_positive_area_fraction,
    metric_semantics = "pixel_based_extracellular_dab_positive_area_fraction"
  )]
), fill = TRUE)
setorder(primary_domain_summary, marker, tissue_type, batch_id, biological_unit_id, condition, compartment, measurement_domain)
fwrite(primary_domain_summary, file.path(outdir, "source_data", "ihc_primary_domain_summary_long.csv"))

design_summary <- biological_table[compartment == "global", .(
  n_images = sum(n_images, na.rm = TRUE),
  n_biological_units = uniqueN(biological_unit_id)
), by = .(marker, tissue_type, batch_id, condition)]
fwrite(design_summary, file.path(outdir, "source_data", "ihc_design_summary.csv"))

manual_qc_template <- qc_table[, .(
  image_id, biological_unit_id, condition, batch_id, marker, tissue_type,
  automatic_qc_flags = qc_flags,
  review_status = "pending",
  reviewer = "",
  segmentation_review = "pending",
  threshold_review = "pending",
  compartment_overlay_review = "pending",
  background_review = "pending",
  final_decision = "pending",
  comments = ""
)]
fwrite(manual_qc_template, file.path(outdir, "source_data", "ihc_manual_qc_template.csv"))

exact_signflip_p <- function(difference) {
  difference <- difference[is.finite(difference)]
  if (length(difference) < 2L || length(difference) > 20L) return(NA_real_)
  sign_grid <- as.matrix(expand.grid(rep(list(c(-1, 1)), length(difference))))
  permuted <- as.vector(sign_grid %*% difference / length(difference))
  observed <- abs(mean(difference))
  mean(abs(permuted) >= observed - sqrt(.Machine$double.eps))
}

conditions <- unique(manifest$condition)
comparison_conditions <- character()
if (!is.null(cli$`condition-order`)) {
  comparison_conditions <- trimws(strsplit(cli$`condition-order`, ",", fixed = TRUE)[[1L]])
  if (length(comparison_conditions) != 2L || any(comparison_conditions == "")) stop("--condition-order must contain exactly two non-empty conditions.")
  if (!all(comparison_conditions %in% conditions)) stop("--condition-order contains conditions absent from the analyzed data.")
} else if (length(conditions) == 2L) {
  comparison_conditions <- conditions
}

metric_map <- c(
  tissue_positive_area_fraction = "Tissue DAB-positive area fraction",
  tissue_mean_dab_od = "Mean tissue DAB optical density",
  nuclear_positive_area_fraction = "Nuclear DAB-positive area fraction",
  nuclear_h_score = "Nuclear H-score",
  cytoplasm_positive_area_fraction = "Cytoplasmic DAB-positive area fraction",
  cytoplasm_h_score = "Cytoplasmic H-score",
  extracellular_positive_area_fraction = "Extracellular DAB-positive area fraction",
  extracellular_mean_dab_od = "Mean extracellular DAB optical density",
  positive_cell_fraction = "Configured-domain positive-cell fraction",
  h_score = "Configured-domain cell H-score",
  mean_cell_dab_od = "Configured-domain mean cell DAB optical density"
)

paired_effects <- data.table()
if (length(comparison_conditions) == 2L && all(comparison_conditions %in% conditions)) {
  comparison_groups <- unique(biological_table[, .(marker, tissue_type, batch_id, compartment, cell_scoring_domain)])
  paired_list <- lapply(seq_len(nrow(comparison_groups)), function(g) {
    group_row <- comparison_groups[g]
    working <- biological_table[
      marker == group_row$marker & tissue_type == group_row$tissue_type & batch_id == group_row$batch_id &
        compartment == group_row$compartment & cell_scoring_domain == group_row$cell_scoring_domain &
        condition %in% comparison_conditions
    ]
    rbindlist(lapply(names(metric_map), function(metric) {
      wide <- dcast(working, biological_unit_id ~ condition, value.var = metric)
      if (!all(comparison_conditions %in% names(wide))) return(NULL)
      difference <- wide[[comparison_conditions[[2L]]]] - wide[[comparison_conditions[[1L]]]]
      difference <- difference[is.finite(difference)]
      if (!length(difference)) return(NULL)
      data.table(
        marker = group_row$marker,
        tissue_type = group_row$tissue_type,
        batch_id = group_row$batch_id,
        compartment = group_row$compartment,
        cell_scoring_domain = group_row$cell_scoring_domain,
        metric = metric,
        metric_label = unname(metric_map[[metric]]),
        reference_condition = comparison_conditions[[1L]],
        comparison_condition = comparison_conditions[[2L]],
        n_paired_units = length(difference),
        n_higher_in_comparison = sum(difference > 0),
        mean_paired_difference = mean(difference),
        median_paired_difference = stats::median(difference),
        inferential_status = if (length(difference) < 2L) "NOT_EVALUABLE_N_LT_2" else "DESCRIPTIVE_EXACT_SIGNFLIP",
        exact_signflip_p_mean_difference = exact_signflip_p(difference)
      )
    }), fill = TRUE)
  })
  if (any(vapply(paired_list, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) paired_effects <- rbindlist(paired_list, fill = TRUE)
}
if (!nrow(paired_effects)) {
  paired_effects <- data.table(
    marker = character(), tissue_type = character(), batch_id = character(), compartment = character(),
    cell_scoring_domain = character(), metric = character(), metric_label = character(),
    reference_condition = character(), comparison_condition = character(), n_paired_units = integer(),
    n_higher_in_comparison = integer(), mean_paired_difference = numeric(), median_paired_difference = numeric(),
    inferential_status = character(), exact_signflip_p_mean_difference = numeric()
  )
}
fwrite(paired_effects, file.path(outdir, "source_data", "ihc_paired_effects.csv"))

main_figure_manifest <- data.table()
if (generate_main_plots) {
  source(file.path(script_dir, "ihc_plot_helpers.R"))
  plot_condition_order <- if (length(comparison_conditions)) comparison_conditions else sort(unique(biological_table$condition))
  main_figure_manifest <- write_default_domain_plots(
    biological_table,
    outdir = file.path(outdir, "figures", "main"),
    roi_compartment = "global",
    condition_order = plot_condition_order,
    summary_stat = cfg$plot_summary_stat,
    errorbar = cfg$plot_errorbar,
    axis_mode = cfg$plot_axis_mode,
    generate_zoomed_plots = cfg$generate_zoomed_plots,
    subtitle_width = cfg$plot_subtitle_width,
    caption_width = cfg$plot_caption_width
  )
}

capture.output(sessionInfo(), file = file.path(outdir, "work", "R_sessionInfo.txt"))
run_lines <- c(
  "# IHC quantification run summary",
  "",
  paste0("- Skill version: ", cfg$version),
  paste0("- Included images: ", nrow(manifest)),
  paste0("- Successful images: ", uniqueN(region_table$image_id)),
  paste0("- Segmented cells: ", nrow(cell_table)),
  paste0("- Manual/external included ROIs: ", roi_registry[action == "include" & roi_id != "GLOBAL", .N]),
  paste0("- Exclusion ROIs: ", roi_registry[action == "exclude", .N]),
  paste0("- Overlapping included ROI pairs: ", nrow(roi_overlap_table)),
  paste0("- Images requiring manual QC review: ", qc_table[manual_review_required %in% TRUE, .N]),
  paste0("- Image errors: ", length(errors)),
  paste0("- Primary default ROI compartment: global"),
  paste0("- Default measurement-domain figures: ", if (generate_main_plots) nrow(main_figure_manifest) else 0L, " (global, nucleus, cytoplasm, extracellular per marker/tissue/batch group)"),
  paste0("- Main-figure y-axis mode: ", cfg$plot_axis_mode, " (fractions fixed at 0-100%; H-scores fixed at 0-300 when plot_axis_mode=fixed)"),
  paste0("- Zoomed diagnostic figures: ", if (isTRUE(cfg$generate_zoomed_plots)) "enabled" else "disabled"),
  paste0("- Condition comparison: ", if (length(comparison_conditions) == 2L) paste(comparison_conditions, collapse = " -> ") else "descriptive multi-condition display; paired-effect table requires exactly two conditions or explicit --condition-order"),
  "",
  "Global whole-tissue quantification is the default ROI compartment. Four separate default result figures are generated: global tissue DAB burden, nuclear H-score, cytoplasmic H-score, and extracellular DAB burden. Publication-facing defaults use fixed biological scales (0-100% for fractions; 0-300 for H-scores). Optional data-scaled zoomed figures are QC diagnostics only. H-score is not assigned to extracellular tissue. Tumor, stroma, interface, or other named compartments are reported only when supplied as reviewed ROI annotations; the pipeline does not infer histologic identity from DAB/hematoxylin alone."
)
writeLines(run_lines, file.path(outdir, "work", "run_summary.md"))
message("IHC quantification complete: ", uniqueN(region_table$image_id), " images; ", nrow(cell_table), " cells; ", nrow(region_table), " image-region summaries.")
