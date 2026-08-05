suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(ragg)
})

if (!requireNamespace("svglite", quietly = TRUE)) stop("Package svglite is required for SVG output.")

sanitize_file_token <- function(x) {
  x <- gsub("[^A-Za-z0-9_-]+", "_", as.character(x))
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  ifelse(nchar(x), x, "unspecified")
}

wrap_plot_text <- function(x, width = 72L) {
  x <- paste(as.character(x), collapse = " ")
  paste(strwrap(x, width = max(20L, as.integer(width))), collapse = "\n")
}

ihc_primary_domain_spec <- function() {
  data.table(
    order = 1:4,
    measurement_domain = c("global", "nucleus", "cytoplasm", "extracellular"),
    metric = c(
      "tissue_positive_area_fraction",
      "nuclear_h_score",
      "cytoplasm_h_score",
      "extracellular_positive_area_fraction"
    ),
    metric_label = c(
      "Global tissue DAB-positive area",
      "Nuclear H-score",
      "Cytoplasmic H-score",
      "Extracellular DAB-positive area"
    ),
    file_label = c(
      "01_global_dab_burden",
      "02_nuclear_h_score",
      "03_cytoplasmic_h_score",
      "04_extracellular_dab_burden"
    ),
    is_fraction = c(TRUE, FALSE, FALSE, TRUE),
    fixed_y_min = c(0, 0, 0, 0),
    fixed_y_max = c(1, 300, 300, 1),
    interpretation = c(
      "Pixel-based DAB burden across analyzed whole tissue",
      "Cell-based nuclear intensity-class score (0–300)",
      "Cell-based cytoplasmic intensity-class score (0–300)",
      "Pixel-based DAB burden outside propagated cell masks"
    )
  )
}

summary_bar_table <- function(plot_data, summary_stat = "mean", errorbar = "se") {
  summary_stat <- tolower(summary_stat)
  errorbar <- tolower(errorbar)
  if (!summary_stat %in% c("mean", "median")) stop("summary_stat must be mean or median.")
  if (!errorbar %in% c("se", "sd", "iqr", "none")) stop("errorbar must be se, sd, iqr, or none.")
  plot_data[, {
    values <- value[is.finite(value)]
    n <- length(values)
    center <- if (!n) NA_real_ else if (summary_stat == "mean") mean(values) else stats::median(values)
    lower <- upper <- NA_real_
    if (n >= 2L && errorbar != "none") {
      if (errorbar == "se") {
        spread <- stats::sd(values) / sqrt(n)
        lower <- center - spread
        upper <- center + spread
      } else if (errorbar == "sd") {
        spread <- stats::sd(values)
        lower <- center - spread
        upper <- center + spread
      } else if (errorbar == "iqr") {
        bounds <- stats::quantile(values, c(0.25, 0.75), names = FALSE)
        lower <- bounds[[1]]
        upper <- bounds[[2]]
      }
    }
    .(summary_value = center, lower = lower, upper = upper, n_units = n)
  }, by = condition]
}

resolve_plot_limits <- function(plot_data, metric_label, is_fraction, axis_mode = "fixed", fixed_limits = NULL) {
  axis_mode <- tolower(as.character(axis_mode))
  if (!axis_mode %in% c("fixed", "data")) stop("axis_mode must be fixed or data.")
  if (axis_mode == "fixed") {
    if (!is.null(fixed_limits) && length(fixed_limits) == 2L && all(is.finite(fixed_limits))) {
      return(as.numeric(fixed_limits))
    }
    if (is_fraction) return(c(0, 1))
    if (grepl("H-score", metric_label, fixed = TRUE)) return(c(0, 300))
  }
  values <- plot_data$value[is.finite(plot_data$value)]
  observed_max <- if (length(values)) max(values) else 0
  if (is_fraction) return(c(0, min(1, max(0.05, observed_max * 1.12))))
  if (grepl("H-score", metric_label, fixed = TRUE)) return(c(0, min(300, max(5, observed_max * 1.12))))
  c(0, max(1, observed_max * 1.12))
}

plot_sample_metadata <- function(plot_data) {
  condition_counts <- plot_data[, .(n_units = uniqueN(biological_unit_id)), by = condition]
  unit_condition_counts <- unique(plot_data[, .(biological_unit_id, condition)])[, .N, by = biological_unit_id]
  repeated_units <- unit_condition_counts[N > 1L, biological_unit_id]
  list(
    condition_counts = condition_counts,
    n_unique_units = uniqueN(plot_data$biological_unit_id),
    n_repeated_units = length(repeated_units),
    repeated_units = repeated_units,
    min_per_condition_n = if (nrow(condition_counts)) min(condition_counts$n_units) else 0L,
    max_per_condition_n = if (nrow(condition_counts)) max(condition_counts$n_units) else 0L
  )
}

make_plot_caption <- function(
    plot_data,
    summary_stat = "mean",
    errorbar = "se",
    caption_width = 100L) {
  summary_stat <- tolower(summary_stat)
  errorbar <- tolower(errorbar)
  meta <- plot_sample_metadata(plot_data)
  counts_text <- paste0(as.character(meta$condition_counts$condition), "=", meta$condition_counts$n_units, collapse = ", ")
  all_single <- nrow(meta$condition_counts) > 0L && all(meta$condition_counts$n_units == 1L)
  if (all_single) {
    summary_text <- "Bars show the observed biological-unit value; no error bars are shown because each condition has n=1."
  } else {
    summary_label <- if (summary_stat == "mean") "mean" else "median"
    if (errorbar == "none") {
      summary_text <- paste0("Bars = ", summary_label, "; error bars disabled.")
    } else {
      error_label <- switch(errorbar, se = "SE", sd = "SD", iqr = "IQR")
      summary_text <- paste0("Bars = ", summary_label, "; error bars = ", error_label, " only where a condition has n>=2.")
    }
  }
  pair_text <- if (meta$n_repeated_units > 0L) {
    paste0("Points are biological units; lines connect ", meta$n_repeated_units, " repeated unit(s) across conditions.")
  } else {
    "Points are biological units; no repeated unit was available for a connecting line."
  }
  inference_text <- if (meta$n_repeated_units < 2L) {
    "Descriptive only: fewer than two repeated biological units; no inferential claim."
  } else {
    "Any formal inference must follow the prespecified study-level statistical plan."
  }
  wrap_plot_text(
    paste(summary_text, paste0("Per-condition n: ", counts_text, "."), pair_text, inference_text),
    width = caption_width
  )
}

make_empty_domain_plot <- function(
    metric_label,
    subtitle,
    reason,
    is_fraction = FALSE,
    axis_mode = "fixed",
    fixed_limits = NULL,
    subtitle_width = 72L,
    caption_width = 100L) {
  y_limits <- resolve_plot_limits(
    data.table(value = numeric()),
    metric_label = metric_label,
    is_fraction = is_fraction,
    axis_mode = axis_mode,
    fixed_limits = fixed_limits
  )
  y_span <- diff(y_limits)
  if (!is.finite(y_span) || y_span <= 0) y_span <- 1
  ggplot() +
    annotate(
      "text",
      x = 1,
      y = y_limits[[1]] + 0.58 * y_span,
      label = wrap_plot_text(reason, width = 58L),
      size = 4,
      colour = "grey25"
    ) +
    annotate(
      "segment",
      x = 0.65,
      xend = 1.35,
      y = y_limits[[1]] + 0.32 * y_span,
      yend = y_limits[[1]] + 0.32 * y_span,
      linewidth = 1.1,
      colour = "grey80"
    ) +
    coord_cartesian(xlim = c(0.5, 1.5), ylim = y_limits, clip = "off") +
    labs(
      title = metric_label,
      subtitle = wrap_plot_text(subtitle, subtitle_width),
      caption = wrap_plot_text(
        "No quantitative comparison was drawn. Review segmentation, masks, thresholds, and finite biological-unit values.",
        caption_width
      ),
      x = NULL,
      y = metric_label
    ) +
    theme_classic(base_size = 10, base_family = "sans") +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.subtitle = element_text(colour = "grey30", size = 9, margin = margin(b = 6)),
      plot.caption = element_text(colour = "grey35", hjust = 0, size = 8, margin = margin(t = 8)),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      plot.margin = margin(10, 22, 10, 10)
    )
}

make_bar_paired_plot <- function(
    plot_data,
    metric_label,
    subtitle,
    is_fraction = FALSE,
    summary_stat = "mean",
    errorbar = "se",
    axis_mode = "fixed",
    fixed_limits = NULL,
    subtitle_width = 72L,
    caption_width = 100L) {
  plot_data <- copy(as.data.table(plot_data)[is.finite(value)])
  if (!nrow(plot_data)) {
    return(make_empty_domain_plot(
      metric_label = metric_label,
      subtitle = subtitle,
      reason = "No finite biological-unit values are available for this domain.",
      is_fraction = is_fraction,
      axis_mode = axis_mode,
      fixed_limits = fixed_limits,
      subtitle_width = subtitle_width,
      caption_width = caption_width
    ))
  }
  plot_data[, condition := droplevels(condition)]
  unit_condition_counts <- unique(plot_data[, .(biological_unit_id, condition)])[, .N, by = biological_unit_id]
  repeated_units <- unit_condition_counts[N > 1L, biological_unit_id]
  paired_data <- plot_data[biological_unit_id %in% repeated_units]
  bar_data <- summary_bar_table(plot_data, summary_stat, errorbar)
  bar_data[is.finite(lower), lower := pmax(0, lower)]
  if (is_fraction) bar_data[is.finite(upper), upper := pmin(1, upper)]
  if (grepl("H-score", metric_label, fixed = TRUE)) bar_data[is.finite(upper), upper := pmin(300, upper)]
  y_limits <- resolve_plot_limits(
    plot_data,
    metric_label = metric_label,
    is_fraction = is_fraction,
    axis_mode = axis_mode,
    fixed_limits = fixed_limits
  )

  p <- ggplot() +
    geom_col(
      data = bar_data,
      aes(x = condition, y = summary_value),
      width = 0.64,
      fill = "grey88",
      colour = "grey35",
      linewidth = 0.45,
      alpha = 0.82
    )
  if (any(is.finite(bar_data$lower) & is.finite(bar_data$upper))) {
    p <- p + geom_errorbar(
      data = bar_data[is.finite(lower) & is.finite(upper)],
      aes(x = condition, ymin = lower, ymax = upper),
      width = 0.14,
      linewidth = 0.55,
      colour = "grey20"
    )
  }
  if (nrow(paired_data)) {
    p <- p + geom_line(
      data = paired_data,
      aes(x = condition, y = value, group = biological_unit_id),
      linewidth = 0.55,
      alpha = 0.55,
      colour = "grey45"
    )
  }
  p <- p +
    geom_point(
      data = plot_data,
      aes(x = condition, y = value, fill = condition),
      shape = 21,
      size = 2.8,
      stroke = 0.45,
      colour = "black",
      alpha = 0.95,
      show.legend = FALSE
    ) +
    labs(
      title = metric_label,
      subtitle = wrap_plot_text(subtitle, subtitle_width),
      caption = make_plot_caption(plot_data, summary_stat, errorbar, caption_width),
      x = NULL,
      y = metric_label
    ) +
    theme_classic(base_size = 10, base_family = "sans") +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.subtitle = element_text(colour = "grey30", size = 9, margin = margin(b = 6)),
      plot.caption = element_text(colour = "grey35", hjust = 0, size = 8, margin = margin(t = 8)),
      axis.text.x = element_text(face = "bold"),
      plot.margin = margin(10, 22, 10, 10)
    )

  if (is_fraction) {
    p <- p + scale_y_continuous(
      labels = function(x) paste0(format(round(100 * x, 1), trim = TRUE), "%"),
      limits = y_limits,
      breaks = if (tolower(axis_mode) == "fixed") seq(0, 1, by = 0.25) else waiver(),
      expand = expansion(mult = c(0, 0.025))
    )
  } else if (grepl("H-score", metric_label, fixed = TRUE)) {
    p <- p + scale_y_continuous(
      limits = y_limits,
      breaks = if (tolower(axis_mode) == "fixed") seq(0, 300, by = 50) else waiver(),
      expand = expansion(mult = c(0, 0.025))
    )
  } else {
    p <- p + scale_y_continuous(limits = y_limits, expand = expansion(mult = c(0, 0.025)))
  }
  p
}

save_ihc_plot <- function(plot, stem, width_mm = 165, height_mm = 125) {
  dir.create(dirname(stem), recursive = TRUE, showWarnings = FALSE)
  ragg::agg_png(
    paste0(stem, ".png"),
    width = width_mm,
    height = height_mm,
    units = "mm",
    res = 300,
    background = "white"
  )
  print(plot)
  grDevices::dev.off()
  svglite::svglite(
    paste0(stem, ".svg"),
    width = width_mm / 25.4,
    height = height_mm / 25.4,
    bg = "white"
  )
  print(plot)
  grDevices::dev.off()
  if (capabilities("cairo")) {
    grDevices::cairo_pdf(
      paste0(stem, ".pdf"),
      width = width_mm / 25.4,
      height = height_mm / 25.4,
      family = "sans"
    )
  } else {
    grDevices::pdf(
      paste0(stem, ".pdf"),
      width = width_mm / 25.4,
      height = height_mm / 25.4,
      family = "sans"
    )
  }
  print(plot)
  grDevices::dev.off()
}

write_default_domain_plots <- function(
    summary,
    outdir,
    roi_compartment = "global",
    condition_order = NULL,
    summary_stat = "mean",
    errorbar = "se",
    axis_mode = "fixed",
    generate_zoomed_plots = FALSE,
    subtitle_width = 72L,
    caption_width = 100L) {
  summary <- copy(as.data.table(summary))
  required <- c("biological_unit_id", "condition", "compartment", "marker", "tissue_type", "batch_id")
  missing <- setdiff(required, names(summary))
  if (length(missing)) stop("Biological-unit summary missing columns: ", paste(missing, collapse = ", "))
  axis_mode <- tolower(as.character(axis_mode))
  if (!axis_mode %in% c("fixed", "data")) stop("axis_mode must be fixed or data.")
  generate_zoomed_plots <- isTRUE(generate_zoomed_plots)
  spec <- ihc_primary_domain_spec()
  missing_metrics <- setdiff(spec$metric, names(summary))
  if (length(missing_metrics)) stop("Summary is missing v2.2 domain metrics: ", paste(missing_metrics, collapse = ", "))

  target_roi_compartment <- as.character(roi_compartment)
  working <- summary[get("compartment") == target_roi_compartment]
  if (!nrow(working)) stop("No summary rows found for ROI compartment: ", target_roi_compartment)
  if (!is.null(condition_order) && length(condition_order)) {
    condition_order <- as.character(condition_order)
    unknown <- setdiff(condition_order, unique(working$condition))
    if (length(unknown)) stop("Condition order includes absent labels: ", paste(unknown, collapse = ", "))
    working <- working[condition %in% condition_order]
  } else {
    condition_order <- sort(unique(working$condition))
  }
  working[, condition := factor(condition, levels = condition_order)]

  group_cols <- c("marker", "tissue_type", "batch_id")
  groups <- unique(working[, group_cols, with = FALSE])
  multi_group <- nrow(groups) > 1L
  manifest_rows <- list()
  for (group_index in seq_len(nrow(groups))) {
    group_row <- groups[group_index]
    group_data <- working[
      marker == group_row$marker & tissue_type == group_row$tissue_type & batch_id == group_row$batch_id
    ]
    group_token <- paste(
      sanitize_file_token(group_row$marker),
      sanitize_file_token(group_row$tissue_type),
      sanitize_file_token(group_row$batch_id),
      sep = "__"
    )
    group_outdir <- if (multi_group) file.path(outdir, group_token) else outdir
    dir.create(group_outdir, recursive = TRUE, showWarnings = FALSE)
    for (spec_index in seq_len(nrow(spec))) {
      domain_row <- spec[spec_index]
      metric_name <- domain_row$metric[[1]]
      plot_data <- group_data[, .(
        biological_unit_id,
        condition,
        marker,
        tissue_type,
        batch_id,
        roi_compartment = compartment,
        measurement_domain = domain_row$measurement_domain[[1]],
        metric = metric_name,
        value = get(metric_name)
      )]
      subtitle <- paste0(
        "Marker: ", group_row$marker,
        "; ROI compartment: ", target_roi_compartment,
        "; ", domain_row$interpretation[[1]]
      )
      finite_value_count <- sum(is.finite(plot_data$value))
      plot_status <- if (finite_value_count > 0L) "PLOTTED" else "NO_FINITE_VALUES_PLACEHOLDER"
      fixed_limits <- c(domain_row$fixed_y_min[[1]], domain_row$fixed_y_max[[1]])
      main_limits <- resolve_plot_limits(
        plot_data,
        metric_label = domain_row$metric_label[[1]],
        is_fraction = domain_row$is_fraction[[1]],
        axis_mode = axis_mode,
        fixed_limits = fixed_limits
      )
      plot <- make_bar_paired_plot(
        plot_data,
        metric_label = domain_row$metric_label[[1]],
        subtitle = subtitle,
        is_fraction = domain_row$is_fraction[[1]],
        summary_stat = summary_stat,
        errorbar = errorbar,
        axis_mode = axis_mode,
        fixed_limits = fixed_limits,
        subtitle_width = subtitle_width,
        caption_width = caption_width
      )
      stem <- file.path(group_outdir, paste0("ihc_main_", domain_row$file_label[[1]]))
      fwrite(plot_data, paste0(stem, "_source_data.csv"))
      save_ihc_plot(plot, stem)

      zoomed_stem <- NA_character_
      if (generate_zoomed_plots && axis_mode == "fixed" && finite_value_count > 0L) {
        zoomed_plot <- make_bar_paired_plot(
          plot_data,
          metric_label = paste0(domain_row$metric_label[[1]], " — zoomed diagnostic"),
          subtitle = paste0(subtitle, "; data-scaled y-axis for QC only"),
          is_fraction = domain_row$is_fraction[[1]],
          summary_stat = summary_stat,
          errorbar = errorbar,
          axis_mode = "data",
          fixed_limits = fixed_limits,
          subtitle_width = subtitle_width,
          caption_width = caption_width
        )
        zoomed_stem <- paste0(stem, "_zoomed")
        save_ihc_plot(zoomed_plot, zoomed_stem)
      }

      sample_meta <- plot_sample_metadata(plot_data[is.finite(value)])
      errorbar_status <- if (tolower(errorbar) == "none") {
        "DISABLED"
      } else if (sample_meta$max_per_condition_n >= 2L) {
        "SHOWN_WHERE_N_GE_2"
      } else {
        "NOT_SHOWN_N_LT_2"
      }
      manifest_rows[[length(manifest_rows) + 1L]] <- data.table(
        marker = group_row$marker,
        tissue_type = group_row$tissue_type,
        batch_id = group_row$batch_id,
        roi_compartment = target_roi_compartment,
        measurement_domain = domain_row$measurement_domain[[1]],
        metric = metric_name,
        finite_value_count = finite_value_count,
        plot_status = plot_status,
        axis_mode = axis_mode,
        y_axis_min = main_limits[[1]],
        y_axis_max = main_limits[[2]],
        n_unique_units = sample_meta$n_unique_units,
        n_repeated_units = sample_meta$n_repeated_units,
        min_per_condition_n = sample_meta$min_per_condition_n,
        max_per_condition_n = sample_meta$max_per_condition_n,
        errorbar_status = errorbar_status,
        png = paste0(stem, ".png"),
        svg = paste0(stem, ".svg"),
        pdf = paste0(stem, ".pdf"),
        source_data = paste0(stem, "_source_data.csv"),
        zoomed_png = if (is.na(zoomed_stem)) NA_character_ else paste0(zoomed_stem, ".png"),
        zoomed_svg = if (is.na(zoomed_stem)) NA_character_ else paste0(zoomed_stem, ".svg"),
        zoomed_pdf = if (is.na(zoomed_stem)) NA_character_ else paste0(zoomed_stem, ".pdf")
      )
    }
  }
  output_manifest <- rbindlist(manifest_rows, fill = TRUE)
  fwrite(output_manifest, file.path(outdir, "ihc_main_figure_manifest.csv"))
  output_manifest
}
