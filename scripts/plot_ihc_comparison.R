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

cli <- parse_cli(commandArgs(trailingOnly = TRUE))
summary_path <- cli$summary
if (is.null(summary_path) && !is.null(cli$`patient-summary`)) summary_path <- cli$`patient-summary`
if (is.null(summary_path) || is.null(cli$outdir)) {
  stop("Required: --summary=/path/ihc_biological_unit_summary.csv --outdir=/path/figures [--preset=main4]")
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this tool with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
source(file.path(script_dir, "path_utils.R"))
local_lib <- normalize_optional_dir(cli$`local-lib`)
if (!is.null(local_lib)) .libPaths(c(local_lib, .libPaths()))
source(file.path(script_dir, "ihc_plot_helpers.R"))

summary <- fread(normalize_path_portable(summary_path, must_work = TRUE))
outdir <- normalize_path_portable(cli$outdir, must_work = FALSE)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

preset <- if (!is.null(cli$preset)) tolower(cli$preset) else if (!is.null(cli$metric)) "single" else "main4"
if (!preset %in% c("main4", "single")) stop("--preset must be main4 or single.")
condition_order <- if (!is.null(cli$`condition-order`)) trimws(strsplit(cli$`condition-order`, ",", fixed = TRUE)[[1L]]) else NULL
summary_stat <- if (!is.null(cli$`summary-stat`)) cli$`summary-stat` else "mean"
errorbar <- if (!is.null(cli$errorbar)) cli$errorbar else "se"
axis_mode <- if (!is.null(cli$`axis-mode`)) tolower(cli$`axis-mode`) else "fixed"
if (!axis_mode %in% c("fixed", "data")) stop("--axis-mode must be fixed or data.")
generate_zoomed_plots <- if (!is.null(cli$`generate-zoomed-plots`)) {
  tolower(cli$`generate-zoomed-plots`) %in% c("true", "t", "1", "yes", "y")
} else FALSE
subtitle_width <- if (!is.null(cli$`subtitle-width`)) as.integer(cli$`subtitle-width`) else 72L
caption_width <- if (!is.null(cli$`caption-width`)) as.integer(cli$`caption-width`) else 100L
if (!is.finite(subtitle_width) || subtitle_width < 20L) stop("--subtitle-width must be >= 20.")
if (!is.finite(caption_width) || caption_width < 20L) stop("--caption-width must be >= 20.")
roi_compartment <- if (!is.null(cli$`roi-compartment`)) cli$`roi-compartment` else if (!is.null(cli$compartment)) cli$compartment else "global"

if (preset == "main4") {
  write_default_domain_plots(
    summary,
    outdir = outdir,
    roi_compartment = roi_compartment,
    condition_order = condition_order,
    summary_stat = summary_stat,
    errorbar = errorbar,
    axis_mode = axis_mode,
    generate_zoomed_plots = generate_zoomed_plots,
    subtitle_width = subtitle_width,
    caption_width = caption_width
  )
  message("Four default domain figures written to: ", outdir)
} else {
  if (is.null(cli$metric)) stop("--preset=single requires --metric=<summary column>.")
  metric <- cli$metric
  if (!metric %in% names(summary)) stop("Unknown metric: ", metric)
  mode <- if (!is.null(cli$mode)) tolower(cli$mode) else "conditions"
  if (!mode %in% c("conditions", "compartments")) stop("--mode must be conditions or compartments.")

  if (mode == "conditions") {
    target_roi_compartment <- as.character(roi_compartment)
    plot_data <- summary[get("compartment") == target_roi_compartment]
    if (!nrow(plot_data)) stop("No rows found for ROI compartment: ", target_roi_compartment)
    if (!is.null(condition_order)) plot_data <- plot_data[condition %in% condition_order]
    if (is.null(condition_order)) condition_order <- unique(plot_data$condition)
    plot_data[, condition := factor(condition, levels = condition_order)]
    groups <- unique(plot_data[, .(marker, tissue_type, batch_id)])
    if (nrow(groups) != 1L) stop("--preset=single requires one marker/tissue_type/batch; prefilter the summary.")
    working <- plot_data[, .(
      biological_unit_id,
      condition,
      marker,
      tissue_type,
      batch_id,
      roi_compartment = compartment,
      measurement_domain = if (!is.null(cli$domain)) cli$domain else "custom",
      metric = metric,
      value = get(metric)
    )]
    subtitle <- paste0("Marker: ", groups$marker[[1]], "; ROI compartment: ", target_roi_compartment)
    stem <- file.path(outdir, paste0("ihc_single_conditions_", sanitize_file_token(target_roi_compartment), "_", sanitize_file_token(metric)))
  } else {
    if (is.null(cli$condition)) stop("--mode=compartments requires --condition=<condition label>.")
    target_condition <- as.character(cli$condition)
    compartments <- if (!is.null(cli$compartments)) trimws(strsplit(cli$compartments, ",", fixed = TRUE)[[1L]]) else unique(summary$compartment)
    plot_data <- summary[condition == target_condition & compartment %in% compartments]
    if (!nrow(plot_data)) stop("No rows found for the requested condition and ROI compartments.")
    plot_data[, compartment := factor(compartment, levels = compartments)]
    groups <- unique(plot_data[, .(marker, tissue_type, batch_id)])
    if (nrow(groups) != 1L) stop("--preset=single requires one marker/tissue_type/batch; prefilter the summary.")
    working <- plot_data[, .(
      biological_unit_id,
      condition = compartment,
      marker,
      tissue_type,
      batch_id,
      roi_compartment = as.character(compartment),
      measurement_domain = if (!is.null(cli$domain)) cli$domain else "custom",
      metric = metric,
      value = get(metric)
    )]
    subtitle <- paste0("Marker: ", groups$marker[[1]], "; condition: ", target_condition, "; x-axis = reviewed ROI compartments")
    stem <- file.path(outdir, paste0("ihc_single_compartments_", sanitize_file_token(target_condition), "_", sanitize_file_token(metric)))
  }

  is_fraction <- grepl("fraction$", metric)
  metric_label <- if (!is.null(cli$`metric-label`)) cli$`metric-label` else gsub("_", " ", metric)
  plot <- make_bar_paired_plot(
    working,
    metric_label = metric_label,
    subtitle = subtitle,
    is_fraction = is_fraction,
    summary_stat = summary_stat,
    errorbar = errorbar,
    axis_mode = axis_mode,
    fixed_limits = if (is_fraction) c(0, 1) else if (grepl("H-score", metric_label, fixed = TRUE)) c(0, 300) else NULL,
    subtitle_width = subtitle_width,
    caption_width = caption_width
  )
  fwrite(working, paste0(stem, "_source_data.csv"))
  save_ihc_plot(plot, stem)
  message("Single comparison figure written: ", stem)
}
