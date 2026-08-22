#!/usr/bin/env Rscript
# Regression tests for BBBC039 color-instance decoding and one-to-one matching.

suppressPackageStartupMessages(library(EBImage))

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- if (length(script_arg) == 1L) {
  dirname(dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE)))
} else {
  getwd()
}
source(file.path(root, "scripts", "bbbc039_benchmark_helpers.R"))

# Two touching nuclei are intentionally assigned different colors. A binary
# RGB > 0 foreground would merge them; the decoder must preserve two labels.
rgb <- array(0, dim = c(32L, 32L, 3L))
rgb[8:16, 8:16, 1L] <- 1
rgb[8:16, 17:25, 2L] <- 1
mask_image <- EBImage::Image(rgb, colormode = "Color")
decoded <- decode_bbbc039_mask(mask_image)
if (max(decoded) != 2L) {
  stop("BBBC039 color-instance decoder failed: expected 2 touching instances, got ", max(decoded))
}
if (any(decoded[8:16, 16] == decoded[8:16, 17])) {
  stop("Touching instance colors were collapsed into one label.")
}

# Identical prediction must produce two true positives.
matched <- one_to_one_iou_matching(decoded, decoded, iou_threshold = 0.5)
if (matched$tp != 2L || length(matched$matches) != 2L || any(abs(matched$matches - 1) > 1e-12)) {
  stop("One-to-one matching failed on an identical two-instance fixture.")
}

# Splitting one GT object into two predictions cannot produce more TPs than GT
# objects. This catches the historical many-predictions-to-one-GT bug.
split_pred <- decoded
split_pred[8:12, 8:16] <- 1L
split_pred[13:16, 8:16] <- 3L
split_match <- one_to_one_iou_matching(split_pred, decoded, iou_threshold = 0.5)
if (split_match$tp > max(decoded)) {
  stop("One-to-one matching over-counted a GT object.")
}

cat("PASS: BBBC039 color-instance decoding and one-to-one matching contracts.\n")
