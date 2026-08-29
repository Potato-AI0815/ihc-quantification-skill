# if_segmentation.R
# Core EBImage Segmentation, Cell Propagation, and Four-Compartment Definition for IF Modality.
# Part of the IHC/IF Quantification Skill

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
  max_cytoplasm_expansion_radius = 10,
  cytoplasm_boundary_gap_px = 1,
  nuc_watershed_tolerance = 1.0,
  nuc_watershed_ext = 1,
  refine_dense_nuclei = TRUE,
  tissue_threshold_pct = 0.02
) {
  dims <- dim(nuclear_mat)
  nr <- dims[1L]
  nc <- dims[2L]
  watershed_tolerance <- as.numeric(nuc_watershed_tolerance)
  watershed_ext <- as.numeric(nuc_watershed_ext)
  if (!is.finite(watershed_tolerance) || watershed_tolerance < 0) watershed_tolerance <- 0.5
  if (!is.finite(watershed_ext) || watershed_ext < 1) watershed_ext <- 1
  # Dense-field refinement uses a one-pixel local-maximum neighborhood while
  # retaining the caller's intensity tolerance; this avoids turning texture
  # noise into hundreds of artificial nuclei.
  if (isTRUE(refine_dense_nuclei)) watershed_ext <- min(watershed_ext, 1)

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

    # 4. Distance transform and watershed seeds.  The one-pixel local-maximum
    # neighborhood deliberately preserves touching-nucleus peaks in dense
    # fields without lowering the intensity tolerance into image texture.
    dist_map <- EBImage::distmap(nuc_binary)
    # Find local maxima as seeds and split touching nuclei before filtering.
    seeds <- EBImage::watershed(
      dist_map,
      tolerance = watershed_tolerance,
      ext = as.integer(round(watershed_ext))
    )
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
  if (!is.finite(n_cells) || n_cells < 1) n_cells <- 0L
  n_cells <- as.integer(round(n_cells))

  # Step 2: Cell and Cytoplasm Propagation
  nuc_mask <- nuc_labels > 0

  # The legacy implementation used one unconstrained radius for every
  # nucleus.  In dense fields that can make neighboring dilations overlap and
  # produce a single report-like cell polygon.  The effective radius is now
  # capped per nucleus by its closest neighbouring nuclear boundaries.
  configured_radius <- as.numeric(cell_propagation_radius)
  max_radius <- as.numeric(max_cytoplasm_expansion_radius)
  boundary_gap_px <- as.numeric(cytoplasm_boundary_gap_px)
  if (!is.finite(configured_radius) || configured_radius < 0) configured_radius <- 15
  if (!is.finite(max_radius) || max_radius < 0) max_radius <- 10
  if (!is.finite(boundary_gap_px) || boundary_gap_px < 0) boundary_gap_px <- 1
  configured_radius <- floor(configured_radius)
  max_radius <- floor(max_radius)
  boundary_gap_px <- floor(boundary_gap_px)
  configured_effective_radius <- min(configured_radius, max_radius)
  local_expansion_radii <- if (n_cells > 0L) {
    rep(configured_effective_radius, n_cells)
  } else {
    numeric()
  }

  if (n_cells >= 2L) {
    centers <- do.call(rbind, lapply(seq_len(n_cells), function(id) {
      ij <- which(nuc_labels == id, arr.ind = TRUE)
      if (!nrow(ij)) return(c(NA_real_, NA_real_))
      c(mean(ij[, 2]), mean(ij[, 1]))
    }))
    areas <- vapply(seq_len(n_cells), function(id) sum(nuc_labels == id), numeric(1L))
    radii <- sqrt(pmax(areas, 1) / pi)
    center_dist <- as.matrix(stats::dist(centers))
    diag(center_dist) <- Inf
    safe_pairs <- (center_dist - outer(radii, radii, "+") - boundary_gap_px) / 2
    safe_pairs[!is.finite(safe_pairs)] <- Inf
    local_safe_radius <- floor(pmax(0, apply(safe_pairs, 1L, min)))
    local_expansion_radii <- pmin(local_expansion_radii, local_safe_radius)
  }
  effective_radius <- if (length(local_expansion_radii)) max(local_expansion_radii) else 0

  if (n_cells > 0) {
    # Assign every pixel to its nearest nucleus first, then apply the guarded
    # radius for that specific nucleus.  A single close pair therefore cannot
    # collapse propagation for the entire field, while each pixel still has at
    # most one cell label.
    dist_from_nuc <- as.matrix(EBImage::distmap(!nuc_mask))
    nearest_labels <- round(as.matrix(EBImage::propagate(
      x = EBImage::Image(matrix(0, nrow = nr, ncol = nc), colormode = "Grayscale"),
      seeds = EBImage::Image(nuc_labels, colormode = "Grayscale"),
      mask = EBImage::Image(matrix(TRUE, nrow = nr, ncol = nc), colormode = "Grayscale")
    )))
    radius_map <- matrix(0, nrow = nr, ncol = nc)
    assigned <- nearest_labels > 0
    radius_map[assigned] <- local_expansion_radii[as.integer(nearest_labels[assigned])]
    cell_allowed <- nuc_mask | (assigned & dist_from_nuc <= radius_map)

    if (!is.null(cyto_ref_mat)) {
      # If cytoplasm reference channel exists, intersect with positive cyto signal
      cyto_smooth <- EBImage::gblur(EBImage::Image(as.matrix(cyto_ref_mat), colormode = "Grayscale"), sigma = 2.0)
      cyto_otsu <- EBImage::otsu(cyto_smooth)
      cyto_allowed <- as.matrix(cyto_smooth) > (cyto_otsu * 0.5)
      cell_allowed <- cell_allowed & (nuc_mask | cyto_allowed)
    }

    cell_labels <- nearest_labels
    cell_labels[!cell_allowed] <- 0L

    # Remove a narrow neutral boundary wherever two propagated labels touch.
    # Nuclei are protected, so this only trims cytoplasm and cannot erase a
    # valid nuclear object.  The gap prevents adjacent cytoplasm masks from
    # becoming one connected polygon in QC overlays or downstream masks.
    if (boundary_gap_px > 0) {
      contact <- matrix(FALSE, nrow = nr, ncol = nc)
      if (nr > 1L) contact[2:nr, ] <- contact[2:nr, ] |
        (cell_labels[2:nr, ] > 0 & cell_labels[1:(nr - 1L), ] > 0 &
           cell_labels[2:nr, ] != cell_labels[1:(nr - 1L), ])
      if (nc > 1L) contact[, 2:nc] <- contact[, 2:nc] |
        (cell_labels[, 2:nc] > 0 & cell_labels[, 1:(nc - 1L)] > 0 &
           cell_labels[, 2:nc] != cell_labels[, 1:(nc - 1L)])
      if (boundary_gap_px > 1L) {
        contact <- as.matrix(EBImage::dilate(
          EBImage::Image(contact, colormode = "Grayscale"),
          EBImage::makeBrush(2L * boundary_gap_px + 1L, shape = "disc")
        )) > 0
      }
      contact[nuc_mask] <- FALSE
      cell_labels[contact] <- 0L
    }
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
    cell_expansion_radius_by_nucleus = local_expansion_radii,
    metrics = data.table(
      n_cells = n_cells,
      requested_cell_propagation_radius = configured_radius,
      max_cytoplasm_expansion_radius = max_radius,
      effective_cell_propagation_radius = effective_radius,
      median_cell_propagation_radius = if (length(local_expansion_radii)) stats::median(local_expansion_radii) else 0,
      mean_cell_propagation_radius = if (length(local_expansion_radii)) mean(local_expansion_radii) else 0,
      nonzero_cell_propagation_fraction = if (length(local_expansion_radii)) mean(local_expansion_radii > 0) else 0,
      cytoplasm_boundary_gap_px = boundary_gap_px,
      nuc_watershed_tolerance = watershed_tolerance,
      nuc_watershed_ext = as.integer(round(watershed_ext)),
      dense_nucleus_watershed_refinement = isTRUE(refine_dense_nuclei),
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
