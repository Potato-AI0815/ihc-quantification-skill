# if_preprocessing.R
# Preprocessing, Illumination Correction, Registration, and Saturation QC for IF Modality.
# Part of the IHC/IF Quantification Skill

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

# Preprocess a single channel matrix
preprocess_if_channel <- function(
  channel_mat,
  method = "top_hat", # "none", "rolling_ball", "top_hat", "local_background", "user_defined_background_roi"
  radius = 25,
  user_bg_val = NULL,
  bit_depth = "16-bit"
) {
  raw_mat <- as.matrix(channel_mat)
  dims <- dim(raw_mat)

  bg_val_estimated <- 0.0
  bg_method_applied <- method

  if (method == "none" || is.null(method)) {
    corr_mat <- raw_mat
    bg_method_applied <- "none"
  } else if (method %in% c("top_hat", "rolling_ball", "morphological_opening")) {
    # Approximation of rolling ball using morphological top-hat with disc structuring element
    r <- max(3, as.integer(radius))
    kern <- EBImage::makeBrush(size = 2 * r + 1, shape = "disc")
    # Opening: erode then dilate
    opened <- EBImage::opening(EBImage::Image(raw_mat, colormode = "Grayscale"), kern)
    bg_val_estimated <- mean(opened, na.rm = TRUE)
    corr_mat <- as.matrix(raw_mat - as.matrix(opened))
    corr_mat <- pmax(corr_mat, 0)
  } else if (method == "local_background") {
    # 5th percentile or large Gaussian filter approximation
    kern_size <- max(15, as.integer(radius) * 2 + 1)
    bg_est <- EBImage::gblur(EBImage::Image(raw_mat, colormode = "Grayscale"), sigma = kern_size / 2)
    bg_val_estimated <- mean(bg_est, na.rm = TRUE)
    corr_mat <- as.matrix(raw_mat - as.matrix(bg_est))
    corr_mat <- pmax(corr_mat, 0)
  } else if (method == "user_defined_background_roi") {
    if (is.null(user_bg_val) || !is.numeric(user_bg_val)) {
      warning("user_defined_background_roi requested but no numeric value given, defaulting to none.")
      corr_mat <- raw_mat
      bg_method_applied <- "none"
    } else {
      bg_val_estimated <- user_bg_val
      corr_mat <- pmax(raw_mat - user_bg_val, 0)
    }
  } else {
    warning("Unknown background method '", method, "', leaving uncorrected.")
    corr_mat <- raw_mat
    bg_method_applied <- "none"
  }

  return(list(
    corrected_mat = corr_mat,
    background_method = bg_method_applied,
    background_value = bg_val_estimated,
    parameters = paste0("radius=", radius, ";user_bg=", user_bg_val)
  ))
}

# Saturation and Dynamic Range Quality Control
compute_channel_qc_metrics <- function(
  raw_mat,
  corr_mat,
  bit_depth = "16-bit",
  saturation_threshold = 0.005 # 0.5% pixels saturated triggers flag
) {
  # Determine max theoretical level
  max_val <- max(raw_mat, na.rm = TRUE)
  min_val <- min(raw_mat, na.rm = TRUE)

  # For EBImage normalized images [0, 1] vs integer [0, 255] / [0, 65535]
  sat_cut <- if (max_val > 255) {
    65500
  } else if (max_val > 1.0) {
    254
  } else {
    0.999
  }

  n_pixels <- length(raw_mat)
  n_sat <- sum(raw_mat >= sat_cut, na.rm = TRUE)
  sat_frac <- n_sat / max(1, n_pixels)

  n_near_zero <- sum(raw_mat <= (min_val + 1e-5), na.rm = TRUE)
  near_zero_frac <- n_near_zero / max(1, n_pixels)

  # Dynamic range (P99.9 - P0.1) / (max_val - min_val)
  p999 <- stats::quantile(raw_mat, 0.999, na.rm = TRUE, names = FALSE)
  p001 <- stats::quantile(raw_mat, 0.001, na.rm = TRUE, names = FALSE)
  dr_used <- if ((max_val - min_val) > 0) (p999 - p001) / (max_val - min_val) else 0.0

  # Mean signal-to-background estimate
  mean_signal <- mean(corr_mat, na.rm = TRUE)
  bg_mean <- mean(raw_mat, na.rm = TRUE) - mean_signal

  flags <- character()
  if (sat_frac > saturation_threshold) flags <- c(flags, "HIGH_SATURATION")
  if (dr_used < 0.05 && max_val > 0) flags <- c(flags, "LOW_DYNAMIC_RANGE")
  if (max_val == 0 || mean_signal < 1e-6) flags <- c(flags, "NO_SIGNAL")
  if (bg_mean > (0.6 * max(1e-5, mean_signal))) flags <- c(flags, "HIGH_BACKGROUND")

  flag_str <- if (length(flags) > 0) paste(flags, collapse = ";") else "PASS"

  return(data.table(
    raw_min = min_val,
    raw_max = max_val,
    corr_min = min(corr_mat, na.rm = TRUE),
    corr_max = max(corr_mat, na.rm = TRUE),
    mean_signal = mean_signal,
    saturated_pixel_fraction = sat_frac,
    near_zero_pixel_fraction = near_zero_frac,
    dynamic_range_used = dr_used,
    channel_qc_flags = flag_str
  ))
}

# Cross-correlation based 2D Channel Registration (translation)
compute_channel_registration <- function(ref_mat, target_mat, max_shift = 15) {
  # Fast translation registration via cross-correlation of downsampled or center region
  # Center crop to avoid border artifacts
  nr <- nrow(ref_mat)
  nc <- ncol(ref_mat)

  cx_range <- max(1, floor(nr * 0.2)):min(nr, ceiling(nr * 0.8))
  cy_range <- max(1, floor(nc * 0.2)):min(nc, ceiling(nc * 0.8))

  r_crop <- ref_mat[cx_range, cy_range]
  t_crop <- target_mat[cx_range, cy_range]

  # Normalize crops
  r_norm <- (r_crop - mean(r_crop)) / (stats::sd(as.vector(r_crop)) + 1e-8)
  t_norm <- (t_crop - mean(t_crop)) / (stats::sd(as.vector(t_crop)) + 1e-8)

  best_shift_x <- 0L
  best_shift_y <- 0L
  best_cor <- suppressWarnings(stats::cor(as.vector(r_norm), as.vector(t_norm)))

  # Search within [-max_shift, max_shift] grid
  for (dx in seq(-max_shift, max_shift, by = 2)) {
    for (dy in seq(-max_shift, max_shift, by = 2)) {
      if (dx == 0 && dy == 0) next
      # shifted indices
      sx_r <- max(1, 1 + dx):min(nrow(r_norm), nrow(r_norm) + dx)
      sx_t <- max(1, 1 - dx):min(nrow(t_norm), nrow(t_norm) - dx)
      sy_r <- max(1, 1 + dy):min(ncol(r_norm), ncol(r_norm) + dy)
      sy_t <- max(1, 1 - dy):min(ncol(t_norm), ncol(t_norm) - dy)

      len_x <- min(length(sx_r), length(sx_t))
      len_y <- min(length(sy_r), length(sy_t))
      if (len_x < 10 || len_y < 10) next

      sub_r <- r_norm[sx_r[1:len_x], sy_r[1:len_y]]
      sub_t <- t_norm[sx_t[1:len_x], sy_t[1:len_y]]

      val_cor <- suppressWarnings(stats::cor(as.vector(sub_r), as.vector(sub_t)))
      # Translation registration is meaningful only for positive normalized
      # cross-correlation.  Biologically anti-correlated channels (for example
      # the mutually exclusive low-colocalization fixture) can otherwise
      # produce a spurious border shift because their zero-shift correlation
      # is negative and any less-negative border overlap wins the old
      # comparison.  Positive-only update keeps such channels aligned at
      # shift 0 instead of misclassifying them as registration failures.
      if (is.finite(val_cor) && val_cor > 0 && val_cor > best_cor) {
        best_cor <- val_cor
        best_shift_x <- dx
        best_shift_y <- dy
      }
    }
  }

  status <- if (abs(best_shift_x) > 5 || abs(best_shift_y) > 5) "SUSPECT_SHIFT" else "ALIGNED"

  return(list(
    shift_x = best_shift_x,
    shift_y = best_shift_y,
    correlation = best_cor,
    registration_status = status
  ))
}

# Visualization helper: contrast stretching strictly for visual figures
create_display_image <- function(mat, p_low = 0.01, p_high = 0.995) {
  v_low <- stats::quantile(mat, p_low, na.rm = TRUE)
  v_high <- stats::quantile(mat, p_high, na.rm = TRUE)
  if (v_high <= v_low) v_high <- max(mat, na.rm = TRUE)
  if (v_high <= v_low) return(matrix(0, nrow = nrow(mat), ncol = ncol(mat)))

  stretched <- (mat - v_low) / (v_high - v_low)
  pmin(pmax(stretched, 0), 1)
}
