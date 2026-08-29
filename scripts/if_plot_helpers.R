# if_plot_helpers.R
# Publication-Ready Biological-Unit Plots (Figures 1-6) for IF Modality.
# Part of the IHC/IF Quantification Skill

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(ragg)
  library(svglite)
})

# Nature / Scientific publication theme
theme_if_publication <- function(base_size = 11) {
  ggplot2::theme_classic(base_size = base_size) +
    ggplot2::theme(
      axis.line = ggplot2::element_line(color = "black", linewidth = 0.5),
      axis.ticks = ggplot2::element_line(color = "black", linewidth = 0.5),
      axis.text = ggplot2::element_text(color = "black", size = base_size * 0.9),
      axis.title = ggplot2::element_text(color = "black", size = base_size, face = "bold"),
      plot.title = ggplot2::element_text(color = "black", size = base_size * 1.1, face = "bold", hjust = 0.5),
      plot.subtitle = ggplot2::element_text(color = "gray30", size = base_size * 0.85, hjust = 0.5),
      legend.position = "right",
      legend.title = ggplot2::element_text(face = "bold", size = base_size * 0.9),
      panel.grid.major.y = ggplot2::element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor = ggplot2::element_blank()
    )
}

# Plot a single biological-unit comparison figure
render_if_biological_figure <- function(
  plot_data, # aggregated data.table by biological_unit_id x condition
  metric_col,
  metric_label,
  title_str,
  out_stem,
  condition_order = NULL,
  y_min = NULL,
  y_max = NULL,
  width_in = 4.5,
  height_in = 4.0
) {
  dt <- copy(plot_data)
  if (!metric_col %in% names(dt)) {
    warning("Metric '", metric_col, "' not in plot data, skipping figure: ", out_stem)
    return(NULL)
  }

  # Remove NAs
  dt <- dt[!is.na(get(metric_col))]
  if (nrow(dt) == 0L) {
    warning("No non-NA data for '", metric_col, "', skipping figure: ", out_stem)
    return(NULL)
  }

  if (!is.null(condition_order)) {
    dt[, condition := factor(condition, levels = condition_order)]
  } else {
    dt[, condition := factor(condition)]
  }

  n_units <- uniqueN(dt$biological_unit_id)
  is_paired <- any(table(dt$biological_unit_id) > 1L)

  # With one biological unit there is no estimable between-unit spread.  Do not
  # render a bar/SE scaffold that visually implies replication.  For all point
  # displays, explicitly set height = 0: vertical jitter changes the observed
  # value and was the source of the displaced hollow points in the public demo.
  p <- ggplot2::ggplot(dt, ggplot2::aes(x = condition, y = .data[[metric_col]], fill = condition)) +
    ggplot2::scale_fill_brewer(palette = "Set2") +
    theme_if_publication() +
    ggplot2::labs(
      title = title_str,
      subtitle = paste0("Biological replicates (n = ", n_units, ")"),
      x = "Condition",
      y = metric_label
    )

  if (n_units > 1L) {
    p <- p +
      ggplot2::stat_summary(
        fun = mean, geom = "bar", width = 0.55, alpha = 0.7,
        color = "black", linewidth = 0.5, show.legend = FALSE
      ) +
      ggplot2::stat_summary(
        fun.data = mean_se, geom = "errorbar", width = 0.2,
        linewidth = 0.5, color = "black"
      )
  }

  if (is_paired) {
    p <- p +
      ggplot2::geom_line(
        ggplot2::aes(group = biological_unit_id),
        color = "gray40", linetype = "solid", linewidth = 0.5, alpha = 0.6
      ) +
      ggplot2::geom_point(
        ggplot2::aes(color = condition),
        size = 2.5, shape = 21, stroke = 0.8, fill = "white", show.legend = FALSE
      )
  } else {
    p <- p +
      ggplot2::geom_point(
        ggplot2::aes(color = condition),
        position = ggplot2::position_jitter(width = 0.1, height = 0),
        size = 2.5, shape = 21, stroke = 0.8, fill = "white", show.legend = FALSE
      )
  }

  if (!is.null(y_min) && !is.null(y_max)) {
    p <- p + ggplot2::coord_cartesian(ylim = c(y_min, y_max))
  }

  # Save PNG, SVG, PDF
  png_path <- paste0(out_stem, ".png")
  svg_path <- paste0(out_stem, ".svg")
  pdf_path <- paste0(out_stem, ".pdf")

  ragg::agg_png(png_path, width = width_in, height = height_in, units = "in", res = 300)
  print(p)
  grDevices::dev.off()

  svglite::svglite(svg_path, width = width_in, height = height_in)
  print(p)
  grDevices::dev.off()

  grDevices::pdf(pdf_path, width = width_in, height = height_in, useDingbats = FALSE)
  print(p)
  grDevices::dev.off()

  return(list(
    png = png_path,
    svg = svg_path,
    pdf = pdf_path,
    n_units = n_units,
    metric = metric_col
  ))
}
