# if_quantification_helpers.R
# Core Four-Domain and Single-Cell Fluorescence Intensity Quantification for IF Modality.
# Part of IHC/IF Quantification Skill v2.3.0-alpha.1

suppressPackageStartupMessages({
  library(data.table)
  library(EBImage)
})

# Calculate positivity threshold on a channel matrix
calculate_positivity_threshold <- function(
  channel_mat,
  method = "otsu", # "manual", "otsu", "triangle", "background_based", "percentile_based"
  manual_val = NULL,
  percentile_val = 0.90,
  bg_sd_multiplier = 3.0,
  background_mean = NULL,
  background_sd = NULL
) {
  vec <- as.vector(channel_mat)
  finite_vec <- vec[is.finite(vec) & vec > 0]

  if (length(finite_vec) == 0L) {
    return(list(
      threshold_method = "empty_channel",
      threshold_value = NA_real_,
      threshold_source = "no_valid_signal",
      threshold_qc_status = "EMPTY_CHANNEL"
    ))
  }

  if (method == "manual" && !is.null(manual_val)) {
    return(list(
      threshold_method = "manual",
      threshold_value = as.numeric(manual_val),
      threshold_source = "user_specified",
      threshold_qc_status = "LOCKED_MANUAL"
    ))
  }

  if (method == "otsu") {
    # EBImage Otsu threshold
    th_val <- EBImage::otsu(EBImage::Image(as.matrix(channel_mat), colormode = "Grayscale"))
    return(list(
      threshold_method = "otsu",
      threshold_value = th_val,
      threshold_source = "automatic_image_histogram",
      threshold_qc_status = "AUTO_OTSU"
    ))
  }

  if (method == "percentile_based") {
    th_val <- stats::quantile(finite_vec, percentile_val, na.rm = TRUE, names = FALSE)
    return(list(
      threshold_method = paste0("percentile_", round(percentile_val * 100)),
      threshold_value = th_val,
      threshold_source = "automatic_percentile",
      threshold_qc_status = "AUTO_PERCENTILE"
    ))
  }

  if (method == "background_based") {
    bg_m <- if (!is.null(background_mean)) background_mean else stats::median(finite_vec)
    bg_s <- if (!is.null(background_sd)) background_sd else stats::mad(finite_vec)
    th_val <- bg_m + bg_sd_multiplier * bg_s
    return(list(
      threshold_method = paste0("bg_plus_", bg_sd_multiplier, "_sd"),
      threshold_value = th_val,
      threshold_source = "background_distribution",
      threshold_qc_status = "AUTO_BACKGROUND_BASED"
    ))
  }

  # Default fallback
  th_val <- stats::quantile(finite_vec, 0.90, na.rm = TRUE, names = FALSE)
  return(list(
    threshold_method = "percentile_90_fallback",
    threshold_value = th_val,
    threshold_source = "default_fallback",
    threshold_qc_status = "FALLBACK"
  ))
}

# Measure four compartments (GLOBAL, NUCLEUS, CYTOPLASM, EXTRACELLULAR)
quantify_if_compartments <- function(
  channel_mat,
  seg_res,
  marker_name,
  channel_name,
  image_id,
  biological_unit_id,
  condition,
  threshold_res,
  pixel_size_um = 1.0
) {
  pixel_area_um2 <- pixel_size_um * pixel_size_um
  th_val <- threshold_res$threshold_value

  compartment_masks <- list(
    global = seg_res$tissue_mask,
    nucleus = seg_res$nuc_mask,
    cytoplasm = seg_res$cyto_mask,
    extracellular = seg_res$extracellular_mask
  )

  rows <- list()

  for (comp_name in names(compartment_masks)) {
    c_mask <- compartment_masks[[comp_name]]
    pixels <- channel_mat[c_mask]
    n_pix <- length(pixels)

    if (n_pix == 0L || all(is.na(pixels))) {
      rows[[comp_name]] <- data.table(
        image_id = image_id,
        biological_unit_id = biological_unit_id,
        condition = condition,
        marker = marker_name,
        channel_name = channel_name,
        compartment = comp_name,
        pixel_count = 0L,
        area_um2 = 0.0,
        mean_intensity = NA_real_,
        median_intensity = NA_real_,
        integrated_intensity = 0.0,
        max_intensity = NA_real_,
        intensity_sd = NA_real_,
        # No pixels is not the same as a measured zero fraction.  Keep the
        # positivity fields non-evaluable so an absent/invalid tissue mask
        # cannot be plotted as a biological zero.
        positive_pixel_count = NA_integer_,
        positive_area_fraction = NA_real_,
        threshold_method = threshold_res$threshold_method,
        threshold_value = th_val,
        threshold_source = threshold_res$threshold_source,
        threshold_qc_status = threshold_res$threshold_qc_status
      )
    } else {
      # An empty target channel is not equivalent to a zero threshold.  Return
      # non-evaluable positivity rather than counting every zero-valued pixel
      # as positive (the previous >= 0 fallback produced 100% positivity).
      if (identical(threshold_res$threshold_qc_status, "EMPTY_CHANNEL") || is.na(th_val)) {
        pos_pix <- NA_integer_
        pos_frac <- NA_real_
      } else {
        pos_pix <- sum(pixels >= th_val, na.rm = TRUE)
        pos_frac <- pos_pix / n_pix
      }

      rows[[comp_name]] <- data.table(
        image_id = image_id,
        biological_unit_id = biological_unit_id,
        condition = condition,
        marker = marker_name,
        channel_name = channel_name,
        compartment = comp_name,
        pixel_count = n_pix,
        area_um2 = n_pix * pixel_area_um2,
        mean_intensity = mean(pixels, na.rm = TRUE),
        median_intensity = stats::median(pixels, na.rm = TRUE),
        integrated_intensity = sum(pixels, na.rm = TRUE),
        max_intensity = max(pixels, na.rm = TRUE),
        intensity_sd = stats::sd(pixels, na.rm = TRUE),
        positive_pixel_count = pos_pix,
        positive_area_fraction = pos_frac,
        threshold_method = threshold_res$threshold_method,
        threshold_value = th_val,
        threshold_source = threshold_res$threshold_source,
        threshold_qc_status = threshold_res$threshold_qc_status
      )
    }
  }

  rbindlist(rows)
}

# Single-cell quantification
quantify_if_single_cells <- function(
  channel_mat,
  seg_res,
  marker_name,
  channel_name,
  image_id,
  biological_unit_id,
  condition,
  threshold_val,
  pixel_size_um = 1.0
) {
  n_cells <- seg_res$n_cells
  if (n_cells == 0L) {
    return(data.table())
  }

  pixel_area_um2 <- pixel_size_um * pixel_size_um
  nuc_labels <- seg_res$nuc_labels
  cell_labels <- seg_res$cell_labels

  # Compute single-cell metrics using EBImage or direct matrix indexing
  # Extract pixel values per object
  cell_dt_list <- list()

  for (k in seq_len(n_cells)) {
    nuc_idx <- which(nuc_labels == k)
    cell_idx <- which(cell_labels == k)
    cyto_idx <- setdiff(cell_idx, nuc_idx)

    nuc_pix <- channel_mat[nuc_idx]
    cell_pix <- channel_mat[cell_idx]
    cyto_pix <- channel_mat[cyto_idx]

    nuc_m <- if (length(nuc_pix)) mean(nuc_pix, na.rm = TRUE) else NA_real_
    nuc_med <- if (length(nuc_pix)) stats::median(nuc_pix, na.rm = TRUE) else NA_real_
    nuc_int <- if (length(nuc_pix)) sum(nuc_pix, na.rm = TRUE) else 0.0

    cyto_m <- if (length(cyto_pix)) mean(cyto_pix, na.rm = TRUE) else NA_real_
    cyto_med <- if (length(cyto_pix)) stats::median(cyto_pix, na.rm = TRUE) else NA_real_
    cyto_int <- if (length(cyto_pix)) sum(cyto_pix, na.rm = TRUE) else 0.0

    cell_m <- if (length(cell_pix)) mean(cell_pix, na.rm = TRUE) else NA_real_
    cell_med <- if (length(cell_pix)) stats::median(cell_pix, na.rm = TRUE) else NA_real_
    cell_int <- if (length(cell_pix)) sum(cell_pix, na.rm = TRUE) else 0.0

    # N/C Ratio (handling zero denominator)
    nc_ratio <- if (!is.na(nuc_m) && !is.na(cyto_m) && cyto_m > 1e-6) {
      nuc_m / cyto_m
    } else {
      NA_real_
    }

    # Positivity: cell mean >= threshold_val
    is_pos <- if (!is.na(cell_m) && is.finite(threshold_val)) (cell_m >= threshold_val) else NA

    cell_dt_list[[k]] <- data.table(
      image_id = image_id,
      biological_unit_id = biological_unit_id,
      condition = condition,
      cell_id = k,
      marker = marker_name,
      channel_name = channel_name,
      nuclear_pixel_count = length(nuc_idx),
      nuclear_area_um2 = length(nuc_idx) * pixel_area_um2,
      nuclear_mean_intensity = nuc_m,
      nuclear_median_intensity = nuc_med,
      nuclear_integrated_intensity = nuc_int,
      cytoplasmic_pixel_count = length(cyto_idx),
      cytoplasmic_area_um2 = length(cyto_idx) * pixel_area_um2,
      cytoplasmic_mean_intensity = cyto_m,
      cytoplasmic_median_intensity = cyto_med,
      cytoplasmic_integrated_intensity = cyto_int,
      cell_pixel_count = length(cell_idx),
      cell_area_um2 = length(cell_idx) * pixel_area_um2,
      cell_mean_intensity = cell_m,
      cell_median_intensity = cell_med,
      cell_integrated_intensity = cell_int,
      nuclear_to_cytoplasmic_ratio = nc_ratio,
      is_positive_cell = is_pos
    )
  }

  rbindlist(cell_dt_list)
}

# Aggregate to biological unit level (n = biological replicate)
aggregate_if_biological_units <- function(compartment_dt) {
  # Aggregate mean_intensity, median_intensity, integrated_intensity, positive_area_fraction
  # by biological_unit_id, condition, marker, compartment
  mean_or_na <- function(x) {
    x <- x[is.finite(x)]
    if (!length(x)) NA_real_ else mean(x)
  }
  median_or_na <- function(x) {
    x <- x[is.finite(x)]
    if (!length(x)) NA_real_ else stats::median(x)
  }
  agg <- compartment_dt[, .(
    n_images = uniqueN(image_id),
    total_area_um2 = sum(area_um2, na.rm = TRUE),
    mean_intensity = mean_or_na(mean_intensity),
    median_intensity = median_or_na(median_intensity),
    integrated_intensity = sum(integrated_intensity, na.rm = TRUE),
    positive_area_fraction = mean_or_na(positive_area_fraction)
  ), by = .(biological_unit_id, condition, marker, compartment)]

  return(agg)
}
