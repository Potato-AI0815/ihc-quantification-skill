# if_colocalization.R
# Colocalization Analysis (Pearson's r, Manders' M1/M2) for Dual-Target IF Modality.
# Part of the IHC/IF Quantification Skill

suppressPackageStartupMessages({
  library(data.table)
})

# Compute Pearson Correlation Coefficient and Manders' Overlap Coefficients
compute_if_colocalization <- function(
  channel_A_mat,
  channel_B_mat,
  mask = NULL,
  threshold_A = NULL,
  threshold_B = NULL,
  marker_A = "Marker_A",
  marker_B = "Marker_B",
  image_id = "IMG",
  biological_unit_id = "BU",
  condition = "COND",
  compartment = "global"
) {
  if (is.null(mask)) {
    mask <- matrix(TRUE, nrow = nrow(channel_A_mat), ncol = ncol(channel_A_mat))
  }

  vec_A <- channel_A_mat[mask]
  vec_B <- channel_B_mat[mask]

  # Filter finite positive values
  valid_idx <- which(is.finite(vec_A) & is.finite(vec_B))
  n_pix <- length(valid_idx)

  if (n_pix < 30L) {
    return(data.table(
      image_id = image_id,
      biological_unit_id = biological_unit_id,
      condition = condition,
      compartment = compartment,
      marker_A = marker_A,
      marker_B = marker_B,
      pixel_count = n_pix,
      pearson_r = NA_real_,
      manders_m1 = NA_real_,
      manders_m2 = NA_real_,
      threshold_A = NA_real_,
      threshold_B = NA_real_,
      colocalization_qc_status = "NOT_EVALUABLE_LOW_PIXEL_COUNT"
    ))
  }

  vA <- vec_A[valid_idx]
  vB <- vec_B[valid_idx]

  # Pearson correlation coefficient
  sd_A <- stats::sd(vA)
  sd_B <- stats::sd(vB)

  pearson_r <- if (sd_A > 1e-8 && sd_B > 1e-8) {
    stats::cor(vA, vB, method = "pearson")
  } else {
    NA_real_
  }

  # Determine thresholds for Manders (Otsu signal threshold if not provided)
  thA <- if (!is.null(threshold_A)) {
    threshold_A
  } else {
    tryCatch({
      EBImage::otsu(EBImage::Image(channel_A_mat, colormode = "Grayscale"))
    }, error = function(e) {
      stats::mean(vA, na.rm = TRUE) + stats::sd(vA, na.rm = TRUE)
    })
  }

  thB <- if (!is.null(threshold_B)) {
    threshold_B
  } else {
    tryCatch({
      EBImage::otsu(EBImage::Image(channel_B_mat, colormode = "Grayscale"))
    }, error = function(e) {
      stats::mean(vB, na.rm = TRUE) + stats::sd(vB, na.rm = TRUE)
    })
  }

  sum_A <- sum(vA, na.rm = TRUE)
  sum_B <- sum(vB, na.rm = TRUE)

  m1 <- if (sum_A > 1e-8) sum(vA[vB >= thB], na.rm = TRUE) / sum_A else NA_real_
  m2 <- if (sum_B > 1e-8) sum(vB[vA >= thA], na.rm = TRUE) / sum_B else NA_real_

  qc_status <- if (is.na(pearson_r)) "ZERO_VARIANCE" else "PASS"

  return(data.table(
    image_id = image_id,
    biological_unit_id = biological_unit_id,
    condition = condition,
    compartment = compartment,
    marker_A = marker_A,
    marker_B = marker_B,
    pixel_count = n_pix,
    pearson_r = pearson_r,
    manders_m1 = m1,
    manders_m2 = m2,
    threshold_A = thA,
    threshold_B = thB,
    colocalization_qc_status = qc_status
  ))
}
