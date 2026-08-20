# if_segmentation.R
# Core EBImage Segmentation, Cell Propagation, and Four-Compartment Definition for IF Modality.
# Part of IHC/IF Quantification Skill v2.3.0-alpha.1

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

# Segment nuclei and define 4 compartments (GLOBAL, NUCLEUS, CYTOPLASM, EXTRACELLULAR)
segment_if_image <- function(
  nuclear_mat,
  target_mat = NULL,
  cyto_ref_mat = NULL,
  external_mask_path = NULL,
  segmentation_engine = "ebimage", # "ebimage", "cellpose_optional", "stardist_optional", "external_mask"
  nuc_threshold_method = "otsu", # "otsu", "adaptive", "manual"
  nuc_threshold_value = NULL,
  nuc_min_area = 20,
  nuc_max_area = 5000,
  cell_propagation_radius = 15,
  tissue_threshold_pct = 0.02
) {
  dims <- dim(nuclear_mat)
  nr <- dims[1L]
  nc <- dims[2L]

  # Step 1: Check for external mask if requested
  if (segmentation_engine == "external_mask" && !is.null(external_mask_path) && file.exists(external_mask_path)) {
    ext_mask <- EBImage::readImage(external_mask_path)
    if (nrow(ext_mask) != nr || ncol(ext_mask) != nc) {
      stop("External mask dimensions (", nrow(ext_mask), "x", ncol(ext_mask),
           ") do not match image dimensions (", nr, "x", nc, ").")
    }
    nuc_labels <- as.matrix(ext_mask)
    if (length(dim(nuc_labels)) > 2) nuc_labels <- nuc_labels[, , 1]
    nuc_labels <- EBImage::bwlabel(nuc_labels > 0)
    engine_used <- "external_mask"
  } else {
    # Default EBImage Nuclear Segmentation Pipeline
    engine_used <- "ebimage"

    # 1. Smooth nuclear channel
    smoothed <- EBImage::gblur(EBImage::Image(as.matrix(nuclear_mat), colormode = "Grayscale"), sigma = 1.5)

    # 2. Thresholding
    if (nuc_threshold_method == "manual" && !is.null(nuc_threshold_value)) {
      nuc_binary <- smoothed > nuc_threshold_value
    } else {
      # Otsu thresholding
      otsu_val <- EBImage::otsu(smoothed)
      nuc_binary <- smoothed > otsu_val
    }

    # 3. Morphological cleaning: fill holes, open
    nuc_binary <- EBImage::fillHull(nuc_binary)
    kern <- EBImage::makeBrush(3, shape = "disc")
    nuc_binary <- EBImage::opening(nuc_binary, kern)

    # 4. Distance transform and watershed seeds
    dist_map <- EBImage::distmap(nuc_binary)
    # Find local maxima as seeds
    seeds <- EBImage::watershed(dist_map, tolerance = 1.0, ext = 2)
    # Mask out non-nuclear background
    nuc_labels <- as.matrix(seeds) * as.matrix(nuc_binary)

    # 5. Filter by area
    feats <- EBImage::computeFeatures.shape(nuc_labels)
    if (!is.null(feats) && nrow(feats) > 0) {
      valid_objs <- which(feats[, "s.area"] >= nuc_min_area & feats[, "s.area"] <= nuc_max_area)
      # Re-label valid objects
      lookup <- rep(0L, max(nuc_labels, na.rm = TRUE) + 1L)
      lookup[valid_objs + 1L] <- seq_along(valid_objs)
      nuc_labels_mat <- as.matrix(nuc_labels)
      nuc_labels <- matrix(lookup[nuc_labels_mat + 1L], nrow = nr, ncol = nc)
    } else {
      nuc_labels <- matrix(0L, nrow = nr, ncol = nc)
    }
  }

  n_cells <- max(nuc_labels, na.rm = TRUE)

  # Step 2: Cell and Cytoplasm Propagation
  nuc_mask <- nuc_labels > 0

  if (n_cells > 0) {
    # Define cell boundary via constrained Voronoi propagation
    # We create a distance mask from nuclei limited to cell_propagation_radius
    dist_from_nuc <- EBImage::distmap(!nuc_mask)
    cell_allowed <- (dist_from_nuc <= cell_propagation_radius)

    if (!is.null(cyto_ref_mat)) {
      # If cytoplasm reference channel exists, intersect with positive cyto signal
      cyto_smooth <- EBImage::gblur(EBImage::Image(as.matrix(cyto_ref_mat), colormode = "Grayscale"), sigma = 2.0)
      cyto_otsu <- EBImage::otsu(cyto_smooth)
      cyto_allowed <- as.matrix(cyto_smooth) > (cyto_otsu * 0.5)
      cell_allowed <- cell_allowed & (nuc_mask | cyto_allowed)
    }

    # Propagate labels from nuclei into cell_allowed territory
    cell_labels <- EBImage::propagate(
      x = EBImage::Image(matrix(0, nrow = nr, ncol = nc), colormode = "Grayscale"),
      seeds = EBImage::Image(nuc_labels, colormode = "Grayscale"),
      mask = EBImage::Image(cell_allowed, colormode = "Grayscale")
    )
    cell_labels <- as.matrix(cell_labels)
  } else {
    cell_labels <- matrix(0L, nrow = nr, ncol = nc)
  }

  cell_mask <- cell_labels > 0
  cyto_mask <- cell_mask & (!nuc_mask)

  # Step 3: Global Tissue & Extracellular Compartment
  # Do not silently treat the complete camera canvas as tissue.  Use the
  # nuclear channel plus an available structural/cytoplasm reference as a
  # conservative foreground proxy.  A reviewed tissue/ROI mask remains the
  # preferred input for publication work; this proxy is explicitly recorded in
  # the metrics and never called stroma or histology.
  tissue_signal <- as.matrix(nuclear_mat)
  tissue_mask_source <- "nuclear_channel_proxy"
  if (!is.null(cyto_ref_mat)) {
    tissue_signal <- pmax(tissue_signal, as.matrix(cyto_ref_mat), na.rm = TRUE)
    tissue_mask_source <- "nuclear_plus_structural_proxy"
  }
  finite_signal <- tissue_signal[is.finite(tissue_signal)]
  signal_max <- if (length(finite_signal)) max(finite_signal) else 0
  threshold_fraction <- as.numeric(tissue_threshold_pct)
  if (!is.finite(threshold_fraction) || threshold_fraction <= 0 || threshold_fraction >= 1) {
    threshold_fraction <- 0.02
  }
  tissue_threshold <- if (signal_max > 0) signal_max * threshold_fraction else Inf
  tissue_mask <- is.finite(tissue_signal) & tissue_signal > tissue_threshold
  # Remove isolated one-pixel noise without filling the entire canvas.
  if (any(tissue_mask)) {
    tissue_mask <- as.matrix(EBImage::opening(
      EBImage::Image(tissue_mask, colormode = "Grayscale"),
      EBImage::makeBrush(3, shape = "disc")
    )) > 0
  }
  extracellular_mask <- tissue_mask & (!cell_mask)

  # Segmentation QC Flagging
  seg_flags <- character()
  if (n_cells == 0) seg_flags <- c(seg_flags, "NO_CELLS_DETECTED")
  if (n_cells < 10) seg_flags <- c(seg_flags, "LOW_CELL_COUNT")
  if (!any(tissue_mask)) seg_flags <- c(seg_flags, "NO_TISSUE_DETECTED")
  if (is.null(cyto_ref_mat)) seg_flags <- c(seg_flags, "TISSUE_MASK_PROXY_NUCLEAR_ONLY")

  # Area fractions
  total_pixels <- nr * nc
  nuc_frac <- sum(nuc_mask) / total_pixels
  cyto_frac <- sum(cyto_mask) / total_pixels
  extra_frac <- sum(extracellular_mask) / total_pixels

  if (nuc_frac < 0.001 && n_cells > 0) seg_flags <- c(seg_flags, "SEGMENTATION_SUSPECT")

  flag_str <- if (length(seg_flags) > 0) paste(seg_flags, collapse = ";") else "PASS"

  return(list(
    nuc_labels = nuc_labels,
    cell_labels = cell_labels,
    nuc_mask = nuc_mask,
    cell_mask = cell_mask,
    cyto_mask = cyto_mask,
    extracellular_mask = extracellular_mask,
    tissue_mask = tissue_mask,
    n_cells = n_cells,
    engine_used = engine_used,
    metrics = data.table(
      n_cells = n_cells,
      nuclear_area_fraction = nuc_frac,
      cytoplasmic_area_fraction = cyto_frac,
      extracellular_area_fraction = extra_frac,
      tissue_mask_source = tissue_mask_source,
      tissue_threshold_fraction = threshold_fraction,
      tissue_threshold_value = tissue_threshold,
      segmentation_qc_status = flag_str
    )
  ))
}
