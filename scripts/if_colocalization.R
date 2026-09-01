# if_colocalization.R
# Colocalization Analysis (Pearson's r, Manders' M1/M2) for Dual-Target IF Modality.
# Part of the IHC/IF Quantification Skill
#
# Production preprocessing contract: the runner passes raw projected channel
# matrices (channel_A_mat / channel_B_mat) restricted to the analysis mask.
# Background correction is not applied to colocalization inputs so the
# production path and the synthetic validation fixtures use the same pixel
# space.  No automatic image translation is performed: registration QC flags
# suspect shifts and blocks metric interpretation.

suppressPackageStartupMessages({
  library(data.table)
})

# Reproducible dynamic-range assessment used by the colocalization QC gate.
# This mirrors the documented contract in docs/if_colocalization_guide.md:
# (P99.9 - P0.1) / (max - min) must be >= dynamic_range_min.
assess_coloc_dynamic_range <- function(channel_mat, mask = NULL) {
  values <- if (is.null(mask)) as.vector(channel_mat) else channel_mat[mask]
  values <- values[is.finite(values)]
  if (length(values) < 2L) return(0.0)
  value_range <- max(values) - min(values)
  if (!is.finite(value_range) || value_range <= 0) return(0.0)
  p999 <- stats::quantile(values, 0.999, na.rm = TRUE, names = FALSE)
  p001 <- stats::quantile(values, 0.001, na.rm = TRUE, names = FALSE)
  dr <- (p999 - p001) / value_range
  if (!is.finite(dr)) 0.0 else max(0.0, dr)
}

# Shared row constructor so every QC branch emits the same auditable schema.
make_colocalization_row <- function(
  image_id,
  biological_unit_id,
  condition,
  compartment,
  marker_A,
  marker_B,
  pixel_count,
  dynamic_range_A,
  dynamic_range_B,
  registration_shift_x,
  registration_shift_y,
  registration_correlation,
  registration_status,
  pearson_r,
  manders_m1,
  manders_m2,
  threshold_A,
  threshold_B,
  colocalization_qc_status
) {
  data.table(
    image_id = image_id,
    biological_unit_id = biological_unit_id,
    condition = condition,
    compartment = compartment,
    marker_A = marker_A,
    marker_B = marker_B,
    pixel_count = pixel_count,
    dynamic_range_A = dynamic_range_A,
    dynamic_range_B = dynamic_range_B,
    registration_shift_x = registration_shift_x,
    registration_shift_y = registration_shift_y,
    registration_correlation = registration_correlation,
    registration_status = registration_status,
    pearson_r = pearson_r,
    manders_m1 = manders_m1,
    manders_m2 = manders_m2,
    threshold_A = threshold_A,
    threshold_B = threshold_B,
    colocalization_input_contract = "raw_channel_pixels",
    colocalization_qc_status = colocalization_qc_status
  )
}

# Compute Pearson Correlation Coefficient and Manders' Overlap Coefficients
# only after the production QC contract has passed:
#   1. valid pixel count >= 30
#   2. both channels have dynamic range >= dynamic_range_min
#   3. registration shift is <= registration_max_shift on both axes
#   4. both channels have positive variance
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
  compartment = "global",
  dynamic_range_min = 0.05,
  registration_max_shift = 5,
  registration_search_shift = 15
) {
  if (is.null(mask)) {
    mask <- matrix(TRUE, nrow = nrow(channel_A_mat), ncol = ncol(channel_A_mat))
  }
  if (!identical(dim(channel_A_mat), dim(channel_B_mat)) ||
      !identical(dim(channel_A_mat), dim(mask))) {
    return(make_colocalization_row(
      image_id, biological_unit_id, condition, compartment, marker_A, marker_B,
      pixel_count = NA_integer_,
      dynamic_range_A = NA_real_, dynamic_range_B = NA_real_,
      registration_shift_x = NA_integer_, registration_shift_y = NA_integer_,
      registration_correlation = NA_real_,
      registration_status = "DIMENSION_MISMATCH",
      pearson_r = NA_real_, manders_m1 = NA_real_, manders_m2 = NA_real_,
      threshold_A = NA_real_, threshold_B = NA_real_,
      colocalization_qc_status = "NOT_EVALUABLE_DIMENSION_MISMATCH"
    ))
  }

  vec_A <- channel_A_mat[mask]
  vec_B <- channel_B_mat[mask]

  # Filter finite values.  Positivity is not required here because Pearson and
  # Manders are defined on finite intensity pairs; zero-pixels are legitimate
  # background in the raw-channel production contract.
  valid_idx <- which(is.finite(vec_A) & is.finite(vec_B))
  n_pix <- length(valid_idx)

  if (n_pix < 30L) {
    return(make_colocalization_row(
      image_id, biological_unit_id, condition, compartment, marker_A, marker_B,
      pixel_count = n_pix,
      dynamic_range_A = NA_real_, dynamic_range_B = NA_real_,
      registration_shift_x = NA_integer_, registration_shift_y = NA_integer_,
      registration_correlation = NA_real_,
      registration_status = "NOT_ASSESSED_LOW_PIXEL_COUNT",
      pearson_r = NA_real_, manders_m1 = NA_real_, manders_m2 = NA_real_,
      threshold_A = NA_real_, threshold_B = NA_real_,
      colocalization_qc_status = "NOT_EVALUABLE_LOW_PIXEL_COUNT"
    ))
  }

  vA <- vec_A[valid_idx]
  vB <- vec_B[valid_idx]

  # Dynamic-range gate before any Pearson/Manders calculation.
  dr_A <- assess_coloc_dynamic_range(channel_A_mat, mask)
  dr_B <- assess_coloc_dynamic_range(channel_B_mat, mask)

  # Registration gate.  Production sources if_preprocessing.R first, which
  # defines compute_channel_registration().  If that function is unavailable
  # the metrics are blocked rather than silently skipping the documented gate.
  registration <- if (exists("compute_channel_registration", mode = "function")) {
    tryCatch(
      compute_channel_registration(channel_A_mat, channel_B_mat,
                                   max_shift = registration_search_shift),
      error = function(e) {
        list(shift_x = NA_integer_, shift_y = NA_integer_,
             correlation = NA_real_, registration_status = "REGISTRATION_ASSESSMENT_UNAVAILABLE")
      }
    )
  } else {
    list(shift_x = NA_integer_, shift_y = NA_integer_,
         correlation = NA_real_, registration_status = "REGISTRATION_ASSESSMENT_UNAVAILABLE")
  }

  registration_shift_x <- suppressWarnings(as.numeric(registration$shift_x[[1L]]))
  registration_shift_y <- suppressWarnings(as.numeric(registration$shift_y[[1L]]))
  registration_correlation <- suppressWarnings(as.numeric(registration$correlation[[1L]]))

  if (!is.finite(registration_shift_x) || !is.finite(registration_shift_y)) {
    registration_status <- "REGISTRATION_ASSESSMENT_UNAVAILABLE"
  } else if (abs(registration_shift_x) > registration_max_shift ||
             abs(registration_shift_y) > registration_max_shift) {
    registration_status <- "CHANNEL_REGISTRATION_SUSPECT"
  } else {
    registration_status <- if (identical(registration$registration_status, "ALIGNED")) {
      "ALIGNED"
    } else {
      "ALIGNED_WITH_WARNING"
    }
  }

  if (dr_A < dynamic_range_min || dr_B < dynamic_range_min) {
    return(make_colocalization_row(
      image_id, biological_unit_id, condition, compartment, marker_A, marker_B,
      pixel_count = n_pix,
      dynamic_range_A = dr_A, dynamic_range_B = dr_B,
      registration_shift_x = registration_shift_x,
      registration_shift_y = registration_shift_y,
      registration_correlation = registration_correlation,
      registration_status = registration_status,
      pearson_r = NA_real_, manders_m1 = NA_real_, manders_m2 = NA_real_,
      threshold_A = NA_real_, threshold_B = NA_real_,
      colocalization_qc_status = "NOT_EVALUABLE_LOW_DYNAMIC_RANGE"
    ))
  }

  if (registration_status %in% c("CHANNEL_REGISTRATION_SUSPECT",
                                 "REGISTRATION_ASSESSMENT_UNAVAILABLE")) {
    return(make_colocalization_row(
      image_id, biological_unit_id, condition, compartment, marker_A, marker_B,
      pixel_count = n_pix,
      dynamic_range_A = dr_A, dynamic_range_B = dr_B,
      registration_shift_x = registration_shift_x,
      registration_shift_y = registration_shift_y,
      registration_correlation = registration_correlation,
      registration_status = registration_status,
      pearson_r = NA_real_, manders_m1 = NA_real_, manders_m2 = NA_real_,
      threshold_A = NA_real_, threshold_B = NA_real_,
      colocalization_qc_status = "NOT_EVALUABLE_REGISTRATION_SUSPECT"
    ))
  }

  # Pearson correlation coefficient (zero variance is retained as a distinct
  # non-evaluable condition even though constant channels normally fail the
  # dynamic-range gate first).
  sd_A <- stats::sd(vA)
  sd_B <- stats::sd(vB)

  pearson_r <- if (is.finite(sd_A) && is.finite(sd_B) && sd_A > 1e-8 && sd_B > 1e-8) {
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

  make_colocalization_row(
    image_id, biological_unit_id, condition, compartment, marker_A, marker_B,
    pixel_count = n_pix,
    dynamic_range_A = dr_A, dynamic_range_B = dr_B,
    registration_shift_x = registration_shift_x,
    registration_shift_y = registration_shift_y,
    registration_correlation = registration_correlation,
    registration_status = registration_status,
    pearson_r = pearson_r,
    manders_m1 = m1,
    manders_m2 = m2,
    threshold_A = thA,
    threshold_B = thB,
    colocalization_qc_status = qc_status
  )
}
