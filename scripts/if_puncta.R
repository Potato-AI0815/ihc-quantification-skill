# if_puncta.R
# Puncta and Foci Detection (LoG / DoG) for IF Modality.
# Part of the IHC/IF Quantification Skill

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

# Detect puncta/foci using Difference of Gaussians (DoG) filter
detect_if_puncta <- function(
  channel_mat,
  seg_res,
  marker_name = "Puncta_Marker",
  channel_name = "Target",
  image_id = "IMG",
  biological_unit_id = "BU",
  condition = "COND",
  sigma1 = 1.0,
  sigma2 = 2.5,
  threshold_sd_multiplier = 3.0,
  min_area = 2,
  max_area = 150,
  pixel_size_um = NA_real_,
  scale_mode = NULL
) {
  nr <- nrow(channel_mat)
  nc <- ncol(channel_mat)

  scale_contract <- if (is.null(scale_mode)) {
    resolve_if_scale_contract(pixel_size_um)
  } else {
    list(
      pixel_size_um = suppressWarnings(as.numeric(pixel_size_um)),
      scale_mode = as.character(scale_mode)[[1L]]
    )
  }
  calibrated <- identical(scale_contract$scale_mode, "physical_calibrated")
  pixel_size_um_out <- if (calibrated) scale_contract$pixel_size_um else NA_real_
  pixel_area_um2 <- if (calibrated) pixel_size_um_out * pixel_size_um_out else NA_real_

  # 1. Compute DoG filter
  g1 <- EBImage::gblur(EBImage::Image(as.matrix(channel_mat), colormode = "Grayscale"), sigma = sigma1)
  g2 <- EBImage::gblur(EBImage::Image(as.matrix(channel_mat), colormode = "Grayscale"), sigma = sigma2)
  dog_mat <- as.matrix(g1 - g2)
  dog_mat <- pmax(dog_mat, 0)

  # 2. Thresholding on DoG
  mean_dog <- mean(dog_mat, na.rm = TRUE)
  sd_dog <- stats::sd(as.vector(dog_mat), na.rm = TRUE)
  th_val <- mean_dog + threshold_sd_multiplier * sd_dog

  puncta_bin <- (dog_mat >= th_val)

  # 3. Connected components & size filtering
  labeled_puncta <- EBImage::bwlabel(EBImage::Image(puncta_bin, colormode = "Grayscale"))
  feats <- EBImage::computeFeatures.shape(labeled_puncta)

  if (!is.null(feats) && nrow(feats) > 0) {
    valid_objs <- which(feats[, "s.area"] >= min_area & feats[, "s.area"] <= max_area)
    lookup <- rep(0L, max(labeled_puncta, na.rm = TRUE) + 1L)
    lookup[valid_objs + 1L] <- seq_along(valid_objs)
    puncta_labels_mat <- as.matrix(labeled_puncta)
    puncta_labels <- matrix(lookup[puncta_labels_mat + 1L], nrow = nr, ncol = nc)
  } else {
    puncta_labels <- matrix(0L, nrow = nr, ncol = nc)
  }

  n_puncta_total <- max(puncta_labels, na.rm = TRUE)
  puncta_mask <- puncta_labels > 0

  # 4. Compartment level summary
  n_cells <- max(1, seg_res$n_cells)

  comp_masks <- list(
    global = seg_res$tissue_mask,
    nucleus = seg_res$nuc_mask,
    cytoplasm = seg_res$cyto_mask,
    extracellular = seg_res$extracellular_mask
  )

  summary_rows <- list()
  for (comp in names(comp_masks)) {
    c_m <- comp_masks[[comp]]
    pts_in_comp <- which(puncta_mask & c_m)

    # Count unique puncta in compartment
    unique_puncta_ids <- unique(puncta_labels[pts_in_comp])
    unique_puncta_ids <- unique_puncta_ids[unique_puncta_ids > 0]
    p_count <- length(unique_puncta_ids)

    comp_area_px2 <- as.numeric(sum(c_m))
    comp_area_um2 <- if (calibrated) comp_area_px2 * pixel_area_um2 else NA_real_
    p_density_px2 <- if (comp_area_px2 > 0) p_count / comp_area_px2 else NA_real_
    p_density_um2 <- if (calibrated && is.finite(comp_area_um2) && comp_area_um2 > 0) {
      p_count / comp_area_um2
    } else {
      NA_real_
    }
    p_per_cell <- if (comp != "extracellular") p_count / n_cells else NA_real_

    p_pix_vals <- channel_mat[pts_in_comp]
    p_mean_int <- if (length(p_pix_vals)) mean(p_pix_vals, na.rm = TRUE) else 0.0
    p_int_int <- if (length(p_pix_vals)) sum(p_pix_vals, na.rm = TRUE) else 0.0

    summary_rows[[comp]] <- data.table(
      image_id = image_id,
      biological_unit_id = biological_unit_id,
      condition = condition,
      marker = marker_name,
      channel_name = channel_name,
      compartment = comp,
      pixel_size_um = pixel_size_um_out,
      scale_mode = scale_contract$scale_mode,
      puncta_count = p_count,
      puncta_count_per_cell = p_per_cell,
      total_puncta_area_px2 = as.numeric(length(pts_in_comp)),
      total_puncta_area_um2 = if (calibrated) as.numeric(length(pts_in_comp)) * pixel_area_um2 else NA_real_,
      puncta_density_per_px2 = p_density_px2,
      puncta_density_per_um2 = p_density_um2,
      puncta_mean_intensity = p_mean_int,
      puncta_integrated_intensity = p_int_int,
      sigma1 = sigma1,
      sigma2 = sigma2,
      threshold_used = th_val
    )
  }

  # 5. Per-cell puncta count
  cell_puncta_list <- list()
  if (seg_res$n_cells > 0) {
    for (k in seq_len(seg_res$n_cells)) {
      cell_idx <- which(seg_res$cell_labels == k)
      nuc_idx <- which(seg_res$nuc_labels == k)
      cyto_idx <- setdiff(cell_idx, nuc_idx)

      c_pids <- unique(puncta_labels[cell_idx])
      c_pids <- c_pids[c_pids > 0]

      n_pids <- unique(puncta_labels[nuc_idx])
      n_pids <- n_pids[n_pids > 0]

      cy_pids <- unique(puncta_labels[cyto_idx])
      cy_pids <- cy_pids[cy_pids > 0]

      cell_puncta_list[[k]] <- data.table(
        image_id = image_id,
        biological_unit_id = biological_unit_id,
        condition = condition,
        cell_id = k,
        marker = marker_name,
        cell_puncta_count = length(c_pids),
        nuclear_puncta_count = length(n_pids),
        cytoplasmic_puncta_count = length(cy_pids)
      )
    }
  }


  return(list(
    puncta_mask = puncta_mask,
    puncta_labels = puncta_labels,
    dog_mat = dog_mat,
    summary = rbindlist(summary_rows),
    cell_puncta = rbindlist(cell_puncta_list)
  ))
}
