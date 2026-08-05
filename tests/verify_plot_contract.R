#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this test with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
root <- dirname(script_dir)
source(file.path(root, "scripts", "ihc_plot_helpers.R"))

assert_close <- function(x, y, tolerance = 1e-12, label = "values") {
  if (length(x) != length(y) || any(!is.finite(x)) || any(abs(x - y) > tolerance)) {
    stop(label, " differ. Observed: ", paste(x, collapse = ", "), "; expected: ", paste(y, collapse = ", "))
  }
}
normalize_text <- function(x) gsub("[[:space:]]+", " ", as.character(x))

single_unit_fraction <- data.table::data.table(
  biological_unit_id = c("SYN01", "SYN01"),
  condition = factor(c("control", "treatment"), levels = c("control", "treatment")),
  value = c(0.84, 0.24)
)
p_fraction <- make_bar_paired_plot(
  single_unit_fraction,
  metric_label = "Global tissue DAB-positive area",
  subtitle = paste(rep("Long subtitle text used to verify automatic wrapping", 4), collapse = "; "),
  is_fraction = TRUE,
  axis_mode = "fixed"
)
assert_close(p_fraction$scales$get_scales("y")$limits, c(0, 1), label = "Fraction fixed y-axis")
fraction_caption <- normalize_text(p_fraction$labels$caption)
if (!grepl("no error bars", fraction_caption, fixed = TRUE)) stop("n=1 caption must state that no error bars are shown.")
if (!grepl("each condition has n=1", fraction_caption, fixed = TRUE)) stop("n=1 caption must state the per-condition reason.")
if (!grepl("\n", p_fraction$labels$subtitle)) stop("Long subtitles must be wrapped before rendering.")

single_unit_h <- data.table::copy(single_unit_fraction)
single_unit_h[, value := c(2.36, 21.19)]
p_h <- make_bar_paired_plot(
  single_unit_h,
  metric_label = "Nuclear H-score",
  subtitle = "Cell-based nuclear intensity-class score (0-300)",
  is_fraction = FALSE,
  axis_mode = "fixed"
)
assert_close(p_h$scales$get_scales("y")$limits, c(0, 300), label = "H-score fixed y-axis")

multi_unit <- data.table::data.table(
  biological_unit_id = rep(c("SYN01", "SYN02"), each = 2),
  condition = factor(rep(c("control", "treatment"), 2), levels = c("control", "treatment")),
  value = c(0.2, 0.4, 0.3, 0.5)
)
p_multi <- make_bar_paired_plot(
  multi_unit,
  metric_label = "Global tissue DAB-positive area",
  subtitle = "Two repeated biological units",
  is_fraction = TRUE,
  summary_stat = "mean",
  errorbar = "se",
  axis_mode = "fixed"
)
multi_caption <- normalize_text(p_multi$labels$caption)
if (!grepl("SE only where", multi_caption, fixed = TRUE)) stop("n>=2 caption must describe conditional SE display.")
if (!grepl("lines connect 2 repeated unit", multi_caption, fixed = TRUE)) stop("Paired-unit count is missing from caption.")

cat("PASS: v2.2.2 plot contract uses fixed biological scales, wrapped text, and whitespace-robust low-n captions.\n")
