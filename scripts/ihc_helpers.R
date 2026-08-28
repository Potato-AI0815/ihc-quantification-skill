suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

# Generic chromogenic IHC defaults. Parameters with *_um or *_um2 are used when
# pixel_size_um is available; otherwise explicit pixel fallbacks are recorded.
ihc_default_config <- function() {
  list(
    version = "2.3.0-rc3",
    max_image_pixels = 80000000,
    white_quantile = 0.98,
    tissue_od_min = 0.10,
    tissue_close_radius_px = 2,
    nucleus_blur_sigma_um = 0.8,
    nucleus_blur_sigma_px = 1.2,
    nucleus_min_area_um2 = 20,
    nucleus_max_area_um2 = 400,
    nucleus_min_area_px = 80,
    nucleus_max_area_px = 5000,
    nucleus_min_circularity = 0.20,
    nucleus_max_eccentricity = 0.98,
    nucleus_min_h_mean = 0.035,
    border_margin_um = 1.0,
    border_margin_px = 3,
    cell_expansion_radius_um = 6.0,
    cell_expansion_radius_px = 18,
    local_background_inner_radius_um = 7.0,
    local_background_outer_radius_um = 12.0,
    local_background_inner_radius_px = 22,
    local_background_outer_radius_px = 36,
    local_background_min_pixels = 60,
    use_local_background = TRUE,
    cell_scoring_domain = "cytoplasm",
    minimum_cells_for_qc = 20,
    minimum_tissue_fraction_for_qc = 0.05,
    high_background_od_for_qc = 0.10,
    qc_overlay_fill_alpha = 0.08,
    qc_overlay_boundary_alpha = 0.95,
    write_stain_channels = TRUE,
    generate_qc_overview = TRUE,
    generate_roi_triplets = TRUE,
    generate_main_plots = TRUE,
    plot_summary_stat = "mean",
    plot_errorbar = "se",
    plot_axis_mode = "fixed",
    generate_zoomed_plots = FALSE,
    plot_subtitle_width = 72,
    plot_caption_width = 100,
    qc_include_dab_positive_mask = TRUE,
    qc_od_display_upper_quantile = 0.99,
    dab_thresholds = c(negative = 0.08, weak = 0.18, moderate = 0.35)
  )
}

clamp01 <- function(x) {
  x[x < 0] <- 0
  x[x > 1] <- 1
  x
}

as_gray_image <- function(x) {
  Image(as.matrix(x), colormode = Grayscale)
}

odd_brush_size <- function(radius_px) {
  radius_px <- max(1L, as.integer(round(radius_px)))
  2L * radius_px + 1L
}

resolve_scaled_config <- function(cfg, pixel_size_um = NA_real_) {
  out <- cfg
  calibrated <- is.finite(pixel_size_um) && pixel_size_um > 0
  if (calibrated) {
    out$nucleus_blur_sigma_effective_px <- max(0.5, cfg$nucleus_blur_sigma_um / pixel_size_um)
    out$nucleus_min_area_effective_px <- max(5, cfg$nucleus_min_area_um2 / (pixel_size_um^2))
    out$nucleus_max_area_effective_px <- max(out$nucleus_min_area_effective_px + 1, cfg$nucleus_max_area_um2 / (pixel_size_um^2))
    out$border_margin_effective_px <- max(1L, round(cfg$border_margin_um / pixel_size_um))
    out$cell_expansion_radius_effective_px <- max(2L, round(cfg$cell_expansion_radius_um / pixel_size_um))
    out$local_background_inner_effective_px <- max(2L, round(cfg$local_background_inner_radius_um / pixel_size_um))
    out$local_background_outer_effective_px <- max(out$local_background_inner_effective_px + 2L, round(cfg$local_background_outer_radius_um / pixel_size_um))
    out$scale_mode <- "physical_um"
  } else {
    out$nucleus_blur_sigma_effective_px <- cfg$nucleus_blur_sigma_px
    out$nucleus_min_area_effective_px <- cfg$nucleus_min_area_px
    out$nucleus_max_area_effective_px <- cfg$nucleus_max_area_px
    out$border_margin_effective_px <- cfg$border_margin_px
    out$cell_expansion_radius_effective_px <- cfg$cell_expansion_radius_px
    out$local_background_inner_effective_px <- cfg$local_background_inner_radius_px
    out$local_background_outer_effective_px <- cfg$local_background_outer_radius_px
    out$scale_mode <- "pixel_fallback"
  }
  out$pixel_size_um_effective <- if (calibrated) pixel_size_um else NA_real_
  out
}

points_in_polygon <- function(x, y, polygon_x, polygon_y) {
  n_vertex <- length(polygon_x)
  if (n_vertex < 3L) return(rep(FALSE, length(x)))
  inside <- rep(FALSE, length(x))
  j <- n_vertex
  for (i in seq_len(n_vertex)) {
    crosses <- ((polygon_y[[i]] > y) != (polygon_y[[j]] > y)) &
      (x < (polygon_x[[j]] - polygon_x[[i]]) * (y - polygon_y[[i]]) /
         (polygon_y[[j]] - polygon_y[[i]] + .Machine$double.eps) + polygon_x[[i]])
    inside <- xor(inside, crosses)
    j <- i
  }
  inside
}

polygon_to_mask <- function(width_px, height_px, polygon_x, polygon_y) {
  mask <- matrix(FALSE, nrow = width_px, ncol = height_px)
  if (length(polygon_x) < 3L) return(mask)
  xmin <- max(1L, floor(min(polygon_x, na.rm = TRUE)))
  xmax <- min(width_px, ceiling(max(polygon_x, na.rm = TRUE)))
  ymin <- max(1L, floor(min(polygon_y, na.rm = TRUE)))
  ymax <- min(height_px, ceiling(max(polygon_y, na.rm = TRUE)))
  if (xmin > xmax || ymin > ymax) return(mask)
  xs <- seq.int(xmin, xmax)
  for (yy in seq.int(ymin, ymax)) {
    inside <- points_in_polygon(xs, rep(yy, length(xs)), polygon_x, polygon_y)
    if (any(inside)) mask[xs[inside], yy] <- TRUE
  }
  mask
}

normalise_roi_table <- function(roi_vertices) {
  if (is.null(roi_vertices) || !nrow(roi_vertices)) return(data.table())
  roi <- copy(as.data.table(roi_vertices))
  required <- c("image_id", "roi_id", "vertex_order", "x", "y")
  missing <- setdiff(required, names(roi))
  if (length(missing)) stop("ROI table missing columns: ", paste(missing, collapse = ", "))
  defaults <- list(
    compartment = "custom",
    action = "include",
    selection_source = "manual",
    selection_method = "polygon",
    reviewer = NA_character_,
    annotation_status = "selected"
  )
  for (nm in names(defaults)) if (!nm %in% names(roi)) roi[, (nm) := defaults[[nm]]]
  roi[, `:=`(
    image_id = as.character(image_id),
    roi_id = as.character(roi_id),
    compartment = tolower(trimws(as.character(compartment))),
    action = tolower(trimws(as.character(action))),
    selection_source = tolower(trimws(as.character(selection_source))),
    selection_method = tolower(trimws(as.character(selection_method))),
    reviewer = trimws(as.character(reviewer)),
    annotation_status = tolower(trimws(as.character(annotation_status))),
    vertex_order = as.integer(vertex_order),
    x = as.numeric(x),
    y = as.numeric(y)
  )]
  if (any(is.na(roi$image_id) | roi$image_id == "")) stop("ROI image_id cannot be empty.")
  if (any(is.na(roi$roi_id) | roi$roi_id == "")) stop("ROI roi_id cannot be empty.")
  if (any(!is.finite(roi$x) | !is.finite(roi$y))) stop("ROI coordinates must be finite numeric values.")
  if (any(!roi$action %in% c("include", "exclude"))) stop("ROI action must be include or exclude.")
  allowed_status <- c("selected", "reviewed", "approved", "draft", "rejected")
  if (any(!roi$annotation_status %in% allowed_status)) stop("ROI annotation_status must be selected, reviewed, approved, draft, or rejected.")
  roi <- roi[annotation_status %in% c("selected", "reviewed", "approved")]
  if (!nrow(roi)) return(data.table())

  metadata_check <- roi[, .(
    n_compartment = uniqueN(compartment),
    n_action = uniqueN(action),
    n_source = uniqueN(selection_source),
    n_method = uniqueN(selection_method),
    n_reviewer = uniqueN(reviewer),
    n_status = uniqueN(annotation_status)
  ), by = .(image_id, roi_id)]
  inconsistent <- metadata_check[n_compartment > 1L | n_action > 1L | n_source > 1L | n_method > 1L | n_reviewer > 1L | n_status > 1L]
  if (nrow(inconsistent)) stop("Each image_id/roi_id must have consistent metadata: ", paste(paste(inconsistent$image_id, inconsistent$roi_id, sep = "/"), collapse = ", "))

  named_compartments <- c("tumor", "stroma", "interface")
  named <- roi[compartment %in% named_compartments]
  if (nrow(named)) {
    bad_source <- named[selection_source %in% c("", "automatic", "unknown") | is.na(selection_source), unique(paste(image_id, roi_id, sep = "/"))]
    if (length(bad_source)) stop("Tumor/stroma/interface ROIs require manual or external-model provenance: ", paste(bad_source, collapse = ", "))
    missing_reviewer <- named[is.na(reviewer) | reviewer == "", unique(paste(image_id, roi_id, sep = "/"))]
    if (length(missing_reviewer)) stop("Tumor/stroma/interface ROIs require a recorded reviewer: ", paste(missing_reviewer, collapse = ", "))
  }
  roi
}

build_roi_masks <- function(width_px, height_px, image_id, roi_vertices = NULL) {
  roi <- normalise_roi_table(roi_vertices)
  target_image_id <- as.character(image_id)
  if (nrow(roi)) roi <- roi[get("image_id") == target_image_id]
  if (!nrow(roi)) {
    return(list(exclusion_mask = matrix(FALSE, width_px, height_px), regions = list(), registry = data.table(), overlaps = data.table()))
  }

  if (any(roi$x < 1 | roi$x > width_px | roi$y < 1 | roi$y > height_px)) {
    bad <- roi[x < 1 | x > width_px | y < 1 | y > height_px, unique(roi_id)]
    stop("ROI coordinates fall outside the source image for: ", paste(bad, collapse = ", "))
  }

  masks <- list()
  registry <- list()
  grouped <- unique(roi[, .(roi_id, compartment, action, selection_source, selection_method, reviewer, annotation_status)])
  for (i in seq_len(nrow(grouped))) {
    meta <- grouped[i]
    polygon <- roi[roi_id == meta$roi_id][order(vertex_order)]
    if (nrow(polygon) < 3L) stop("ROI has fewer than three vertices: ", meta$roi_id)
    mask <- polygon_to_mask(width_px, height_px, polygon$x, polygon$y)
    if (!any(mask)) stop("ROI has zero rasterized area: ", meta$roi_id)
    masks[[as.character(meta$roi_id)]] <- mask
    registry[[i]] <- data.table(
      image_id = image_id,
      roi_id = as.character(meta$roi_id),
      compartment = as.character(meta$compartment),
      action = as.character(meta$action),
      selection_source = as.character(meta$selection_source),
      selection_method = as.character(meta$selection_method),
      reviewer = as.character(meta$reviewer),
      annotation_status = as.character(meta$annotation_status),
      n_vertices = nrow(polygon),
      x_min = min(polygon$x), x_max = max(polygon$x),
      y_min = min(polygon$y), y_max = max(polygon$y),
      selected_area_px = sum(mask),
      coordinate_space = "source_image_pixels"
    )
  }
  registry <- rbindlist(registry, fill = TRUE)
  exclusion_ids <- registry[action == "exclude", roi_id]
  exclusion_mask <- matrix(FALSE, width_px, height_px)
  if (length(exclusion_ids)) {
    for (id in exclusion_ids) exclusion_mask <- exclusion_mask | masks[[id]]
  }
  include_ids <- registry[action == "include", roi_id]
  regions <- lapply(include_ids, function(id) {
    row <- registry[roi_id == id][1]
    list(
      roi_id = id,
      compartment = row$compartment,
      mask = masks[[id]],
      selection_source = row$selection_source,
      selection_method = row$selection_method
    )
  })

  overlap_rows <- list()
  if (length(include_ids) > 1L) {
    pairs <- utils::combn(include_ids, 2L)
    overlap_rows <- lapply(seq_len(ncol(pairs)), function(k) {
      id1 <- pairs[1L, k]
      id2 <- pairs[2L, k]
      overlap_area <- sum(masks[[id1]] & masks[[id2]])
      if (overlap_area <= 0L) return(NULL)
      area1 <- sum(masks[[id1]])
      area2 <- sum(masks[[id2]])
      data.table(
        image_id = image_id,
        roi_id_1 = id1,
        compartment_1 = registry[roi_id == id1, compartment][[1]],
        roi_id_2 = id2,
        compartment_2 = registry[roi_id == id2, compartment][[1]],
        overlap_area_px = overlap_area,
        overlap_fraction_roi_1 = overlap_area / max(1, area1),
        overlap_fraction_roi_2 = overlap_area / max(1, area2),
        same_compartment = registry[roi_id == id1, compartment][[1]] == registry[roi_id == id2, compartment][[1]]
      )
    })
  }
  overlaps <- if (length(overlap_rows) && any(vapply(overlap_rows, function(x) !is.null(x) && nrow(x) > 0L, logical(1)))) rbindlist(overlap_rows, fill = TRUE) else data.table()
  list(exclusion_mask = exclusion_mask, regions = regions, registry = registry, overlaps = overlaps)
}

white_balance_rgb <- function(img, analysis_mask = NULL, cfg = ihc_default_config()) {
  rgb <- imageData(img)
  if (length(dim(rgb)) != 3L || dim(rgb)[3] < 3L) stop("Expected an RGB image.")
  rgb <- rgb[, , 1:3, drop = FALSE]
  px <- matrix(rgb, ncol = 3L)
  brightness <- rowMeans(px)
  eligible <- rep(TRUE, nrow(px))
  if (!is.null(analysis_mask)) eligible <- as.vector(analysis_mask)
  eligible <- eligible & is.finite(brightness)
  if (!any(eligible)) stop("No eligible pixels remain after exclusions.")
  q <- stats::quantile(brightness[eligible], cfg$white_quantile, na.rm = TRUE, names = FALSE)
  bg <- eligible & brightness >= q
  white <- apply(px[bg, , drop = FALSE], 2L, stats::median, na.rm = TRUE)
  white[!is.finite(white) | white < 0.5] <- 1
  corrected <- sweep(px, 2L, white, "/")
  corrected <- clamp01(corrected)
  Image(array(corrected, dim = dim(rgb)), colormode = Color)
}

hdab_deconvolution <- function(img, analysis_mask = NULL, cfg = ihc_default_config()) {
  d <- dim(img)
  width_px <- d[[1]]
  height_px <- d[[2]]
  if (is.null(analysis_mask)) analysis_mask <- matrix(TRUE, width_px, height_px)
  balanced <- white_balance_rgb(img, analysis_mask, cfg)
  px <- matrix(imageData(balanced), ncol = 3L)
  optical_density <- -log(pmax(px, 1 / 255))

  hematoxylin <- c(0.650, 0.704, 0.286)
  dab <- c(0.268, 0.570, 0.776)
  residual <- c(
    hematoxylin[[2]] * dab[[3]] - hematoxylin[[3]] * dab[[2]],
    hematoxylin[[3]] * dab[[1]] - hematoxylin[[1]] * dab[[3]],
    hematoxylin[[1]] * dab[[2]] - hematoxylin[[2]] * dab[[1]]
  )
  residual <- residual / sqrt(sum(residual^2))
  stain_matrix <- cbind(hematoxylin, dab, residual)
  concentration <- optical_density %*% t(solve(stain_matrix))
  concentration[!is.finite(concentration)] <- 0
  concentration <- pmax(concentration, 0)

  h_od <- matrix(concentration[, 1], nrow = width_px, ncol = height_px)
  dab_od <- matrix(concentration[, 2], nrow = width_px, ncol = height_px)
  total_od <- matrix(rowSums(optical_density), nrow = width_px, ncol = height_px)
  tissue_mask <- total_od > cfg$tissue_od_min & analysis_mask
  radius <- max(1L, as.integer(cfg$tissue_close_radius_px))
  tissue_mask <- closing(as_gray_image(tissue_mask), makeBrush(odd_brush_size(radius), shape = "disc")) > 0
  tissue_mask <- tissue_mask & analysis_mask

  list(
    original = img,
    balanced = balanced,
    hematoxylin_od = h_od,
    dab_od = dab_od,
    total_od = total_od,
    tissue_mask = tissue_mask,
    analysis_mask = analysis_mask,
    stain_matrix = stain_matrix
  )
}

safe_scale01 <- function(x, mask = NULL, probs = c(0.02, 0.995)) {
  values <- if (is.null(mask)) as.vector(x) else x[mask]
  values <- values[is.finite(values)]
  if (!length(values)) return(matrix(0, nrow(x), ncol(x)))
  limits <- stats::quantile(values, probs, na.rm = TRUE, names = FALSE)
  if (!all(is.finite(limits)) || diff(limits) <= 0) limits <- range(values, finite = TRUE)
  clamp01((x - limits[[1]]) / max(diff(limits), .Machine$double.eps))
}

renumber_labels <- function(labels, keep_ids) {
  labels_int <- as.integer(labels)
  max_id <- max(labels_int, na.rm = TRUE)
  if (!is.finite(max_id) || max_id < 1L) return(labels)
  lut <- integer(max_id + 1L)
  keep_ids <- keep_ids[keep_ids > 0 & keep_ids <= max_id]
  lut[keep_ids + 1L] <- seq_along(keep_ids)
  Image(matrix(lut[labels_int + 1L], nrow = dim(labels)[1], ncol = dim(labels)[2]), colormode = Grayscale)
}

feature_table <- function(labels, intensity_image) {
  if (!is.finite(max(labels)) || max(labels) < 1L) return(data.table())
  shape <- as.data.table(computeFeatures.shape(labels))
  moment <- as.data.table(computeFeatures.moment(labels, as_gray_image(intensity_image)))
  basic <- as.data.table(computeFeatures.basic(labels, as_gray_image(intensity_image)))
  out <- cbind(data.table(cell_id = seq_len(nrow(shape))), shape, moment, basic)
  if (all(c("s.area", "s.perimeter") %in% names(out))) {
    out[, circularity := 4 * pi * s.area / pmax(s.perimeter^2, .Machine$double.eps)]
  }
  out
}

segment_nuclei <- function(deconv, cfg) {
  h_od <- deconv$hematoxylin_od
  h_norm <- safe_scale01(h_od, deconv$analysis_mask)
  h_smooth <- gblur(as_gray_image(h_norm), sigma = cfg$nucleus_blur_sigma_effective_px)
  threshold <- max(as.numeric(otsu(h_smooth)), 0.12)
  candidate <- (h_smooth > threshold) & deconv$tissue_mask & deconv$analysis_mask
  candidate <- opening(candidate, makeBrush(3, shape = "disc"))
  candidate <- closing(candidate, makeBrush(3, shape = "disc"))
  candidate <- fillHull(candidate)

  labels_raw <- watershed(distmap(candidate), tolerance = 1, ext = 1)
  labels_raw[!candidate] <- 0
  features_raw <- feature_table(labels_raw, h_od)
  if (!nrow(features_raw)) {
    return(list(labels_raw = labels_raw, labels = labels_raw, features = features_raw, threshold = threshold, h_norm = h_norm))
  }

  required <- c("s.area", "circularity", "m.eccentricity", "m.cx", "m.cy", "b.mean")
  missing <- setdiff(required, names(features_raw))
  if (length(missing)) stop("EBImage feature columns missing: ", paste(missing, collapse = ", "))
  width_px <- dim(labels_raw)[1]
  height_px <- dim(labels_raw)[2]
  keep <- features_raw[
    s.area >= cfg$nucleus_min_area_effective_px &
      s.area <= cfg$nucleus_max_area_effective_px &
      circularity >= cfg$nucleus_min_circularity &
      m.eccentricity <= cfg$nucleus_max_eccentricity &
      b.mean >= cfg$nucleus_min_h_mean &
      m.cx > cfg$border_margin_effective_px & m.cx < (width_px - cfg$border_margin_effective_px) &
      m.cy > cfg$border_margin_effective_px & m.cy < (height_px - cfg$border_margin_effective_px),
    cell_id
  ]
  labels <- renumber_labels(labels_raw, keep)
  features <- feature_table(labels, h_od)
  list(labels_raw = labels_raw, labels = labels, features = features, threshold = threshold, h_norm = h_norm)
}

expand_cell_regions <- function(nucleus_labels, deconv, cfg) {
  if (!is.finite(max(nucleus_labels)) || max(nucleus_labels) < 1L) return(nucleus_labels)
  brush <- makeBrush(odd_brush_size(cfg$cell_expansion_radius_effective_px), shape = "disc")
  reach <- dilate(nucleus_labels > 0, brush) & deconv$tissue_mask & deconv$analysis_mask
  terrain <- as_gray_image(safe_scale01(deconv$total_od, deconv$analysis_mask))
  cells <- propagate(terrain, seeds = nucleus_labels, mask = reach, lambda = 1e-5)
  cells[!reach] <- 0
  cells
}

measure_cells <- function(nucleus_labels, cell_labels, deconv, cfg) {
  if (!is.finite(max(nucleus_labels)) || max(nucleus_labels) < 1L) return(data.table())
  scoring_domain_value <- tolower(as.character(cfg$cell_scoring_domain))
  if (!scoring_domain_value %in% c("cytoplasm", "nucleus", "whole_cell")) {
    stop("cell_scoring_domain must be cytoplasm, nucleus, or whole_cell.")
  }

  nucleus_features <- feature_table(nucleus_labels, deconv$hematoxylin_od)
  setnames(nucleus_features, setdiff(names(nucleus_features), "cell_id"), paste0("nuc_", setdiff(names(nucleus_features), "cell_id")))

  cytoplasm_labels <- cell_labels
  cytoplasm_labels[nucleus_labels > 0] <- 0
  dab <- as.numeric(deconv$dab_od)
  make_index <- function(labels) {
    lab <- as.integer(labels)
    valid <- lab > 0 & is.finite(dab)
    split(which(valid), lab[valid])
  }
  cytoplasm_idx <- make_index(cytoplasm_labels)
  nucleus_idx <- make_index(nucleus_labels)
  whole_cell_idx <- make_index(cell_labels)
  thresholds <- unname(cfg$dab_thresholds[c("negative", "weak", "moderate")])

  width_px <- dim(cell_labels)[1]
  height_px <- dim(cell_labels)[2]
  all_cell_mask <- cell_labels > 0
  field_background_pixels <- deconv$tissue_mask & deconv$analysis_mask & !all_cell_mask
  field_background_values <- deconv$dab_od[field_background_pixels]
  field_background_values <- field_background_values[is.finite(field_background_values)]
  field_background_od <- if (length(field_background_values)) stats::median(field_background_values) else 0

  local_background_for_cell <- function(id) {
    if (!isTRUE(cfg$use_local_background)) return(0)
    target_cell_id <- as.integer(id)
    feature_row <- nucleus_features[get("cell_id") == target_cell_id]
    if (!nrow(feature_row)) return(field_background_od)
    cx <- round(feature_row$nuc_m.cx[[1]])
    cy <- round(feature_row$nuc_m.cy[[1]])
    outer <- cfg$local_background_outer_effective_px
    x <- seq.int(max(1L, cx - outer), min(width_px, cx + outer))
    y <- seq.int(max(1L, cy - outer), min(height_px, cy + outer))
    grid <- CJ(x = x, y = y)
    distance_sq <- (grid$x - cx)^2 + (grid$y - cy)^2
    ring <- distance_sq >= cfg$local_background_inner_effective_px^2 &
      distance_sq <= cfg$local_background_outer_effective_px^2
    grid <- grid[ring]
    if (!nrow(grid)) return(field_background_od)
    keep <- deconv$analysis_mask[cbind(grid$x, grid$y)] &
      deconv$tissue_mask[cbind(grid$x, grid$y)] &
      !all_cell_mask[cbind(grid$x, grid$y)]
    values <- deconv$dab_od[cbind(grid$x[keep], grid$y[keep])]
    values <- values[is.finite(values)]
    if (length(values) < cfg$local_background_min_pixels) field_background_od else stats::median(values)
  }

  domain_stats <- function(id, index_list, local_background_od) {
    key <- as.character(id)
    raw_values <- if (key %in% names(index_list)) dab[index_list[[key]]] else numeric()
    values <- pmax(raw_values - local_background_od, 0)
    positive <- values >= thresholds[[1]]
    raw_positive <- raw_values >= thresholds[[1]]
    list(
      area_px = length(values),
      mean_od = if (length(values)) mean(values) else NA_real_,
      median_od = if (length(values)) stats::median(values) else NA_real_,
      q90_od = if (length(values)) as.numeric(stats::quantile(values, 0.90, names = FALSE)) else NA_real_,
      positive_area_fraction = if (length(values)) mean(positive) else NA_real_,
      positive_mean_od = if (any(positive)) mean(values[positive]) else 0,
      raw_mean_od = if (length(raw_values)) mean(raw_values) else NA_real_,
      raw_positive_area_fraction = if (length(raw_values)) mean(raw_positive) else NA_real_,
      raw_positive_mean_od = if (any(raw_positive)) mean(raw_values[raw_positive]) else 0
    )
  }

  measurements <- rbindlist(lapply(nucleus_features$cell_id, function(id) {
    bg <- local_background_for_cell(id)
    cyto <- domain_stats(id, cytoplasm_idx, bg)
    nuc <- domain_stats(id, nucleus_idx, bg)
    whole <- domain_stats(id, whole_cell_idx, bg)
    data.table(
      cell_id = id,
      local_background_od = bg,
      cytoplasm_area_px = cyto$area_px,
      cytoplasm_dab_mean_od = cyto$mean_od,
      cytoplasm_dab_median_od = cyto$median_od,
      cytoplasm_dab_q90_od = cyto$q90_od,
      cytoplasm_dab_positive_area_fraction = cyto$positive_area_fraction,
      cytoplasm_dab_positive_mean_od = cyto$positive_mean_od,
      cytoplasm_dab_raw_mean_od = cyto$raw_mean_od,
      cytoplasm_dab_raw_positive_area_fraction = cyto$raw_positive_area_fraction,
      cytoplasm_dab_raw_positive_mean_od = cyto$raw_positive_mean_od,
      nuclear_area_px_cell = nuc$area_px,
      nuclear_dab_mean_od = nuc$mean_od,
      nuclear_dab_median_od = nuc$median_od,
      nuclear_dab_q90_od = nuc$q90_od,
      nuclear_dab_positive_area_fraction = nuc$positive_area_fraction,
      nuclear_dab_positive_mean_od = nuc$positive_mean_od,
      nuclear_dab_raw_mean_od = nuc$raw_mean_od,
      nuclear_dab_raw_positive_area_fraction = nuc$raw_positive_area_fraction,
      whole_cell_area_px = whole$area_px,
      whole_cell_dab_mean_od = whole$mean_od,
      whole_cell_dab_median_od = whole$median_od,
      whole_cell_dab_q90_od = whole$q90_od,
      whole_cell_dab_positive_area_fraction = whole$positive_area_fraction,
      whole_cell_dab_positive_mean_od = whole$positive_mean_od,
      whole_cell_dab_raw_mean_od = whole$raw_mean_od,
      whole_cell_dab_raw_positive_area_fraction = whole$raw_positive_area_fraction
    )
  }), fill = TRUE)

  out <- merge(nucleus_features, measurements, by = "cell_id", all.x = TRUE, sort = TRUE)
  out[is.na(cytoplasm_area_px), cytoplasm_area_px := 0]
  out[, cytoplasm_to_nucleus := cytoplasm_area_px / pmax(nuc_s.area, 1)]
  out[, scoring_domain := scoring_domain_value]

  classify_intensity <- function(x) {
    cut(x, breaks = c(-Inf, thresholds, Inf), labels = c("0", "1+", "2+", "3+"), right = FALSE)
  }
  out[, `:=`(
    nuclear_intensity_class = classify_intensity(nuclear_dab_mean_od),
    cytoplasm_intensity_class = classify_intensity(cytoplasm_dab_mean_od),
    whole_cell_intensity_class = classify_intensity(whole_cell_dab_mean_od),
    nuclear_cell_positive = is.finite(nuclear_dab_mean_od) & nuclear_dab_mean_od >= thresholds[[1]],
    cytoplasm_cell_positive = is.finite(cytoplasm_dab_mean_od) & cytoplasm_dab_mean_od >= thresholds[[1]],
    whole_cell_positive = is.finite(whole_cell_dab_mean_od) & whole_cell_dab_mean_od >= thresholds[[1]]
  )]

  if (scoring_domain_value == "cytoplasm") {
    out[, `:=`(
      dab_mean_od = cytoplasm_dab_mean_od,
      dab_median_od = cytoplasm_dab_median_od,
      dab_q90_od = cytoplasm_dab_q90_od,
      dab_positive_area_fraction = cytoplasm_dab_positive_area_fraction,
      dab_positive_mean_od = cytoplasm_dab_positive_mean_od,
      dab_raw_mean_od = cytoplasm_dab_raw_mean_od,
      dab_raw_positive_area_fraction = cytoplasm_dab_raw_positive_area_fraction,
      dab_raw_positive_mean_od = cytoplasm_dab_raw_positive_mean_od,
      intensity_class = cytoplasm_intensity_class,
      cell_positive = cytoplasm_cell_positive
    )]
  } else if (scoring_domain_value == "nucleus") {
    out[, `:=`(
      dab_mean_od = nuclear_dab_mean_od,
      dab_median_od = nuclear_dab_median_od,
      dab_q90_od = nuclear_dab_q90_od,
      dab_positive_area_fraction = nuclear_dab_positive_area_fraction,
      dab_positive_mean_od = nuclear_dab_positive_mean_od,
      dab_raw_mean_od = nuclear_dab_raw_mean_od,
      dab_raw_positive_area_fraction = nuclear_dab_raw_positive_area_fraction,
      dab_raw_positive_mean_od = NA_real_,
      intensity_class = nuclear_intensity_class,
      cell_positive = nuclear_cell_positive
    )]
  } else {
    out[, `:=`(
      dab_mean_od = whole_cell_dab_mean_od,
      dab_median_od = whole_cell_dab_median_od,
      dab_q90_od = whole_cell_dab_q90_od,
      dab_positive_area_fraction = whole_cell_dab_positive_area_fraction,
      dab_positive_mean_od = whole_cell_dab_positive_mean_od,
      dab_raw_mean_od = whole_cell_dab_raw_mean_od,
      dab_raw_positive_area_fraction = whole_cell_dab_raw_positive_area_fraction,
      dab_raw_positive_mean_od = NA_real_,
      intensity_class = whole_cell_intensity_class,
      cell_positive = whole_cell_positive
    )]
  }
  out
}

pixel_metrics <- function(mask, dab_od, positive_threshold) {
  values <- dab_od[mask]
  values <- values[is.finite(values)]
  if (!length(values)) {
    return(list(area_px = 0, positive_area_px = 0, positive_area_fraction = NA_real_, mean_od = NA_real_, positive_mean_od = NA_real_, integrated_od = NA_real_))
  }
  positive <- values >= positive_threshold
  list(
    area_px = length(values),
    positive_area_px = sum(positive),
    positive_area_fraction = mean(positive),
    mean_od = mean(values),
    positive_mean_od = if (any(positive)) mean(values[positive]) else 0,
    integrated_od = sum(values)
  )
}

cell_metrics_for_domain <- function(cells, domain = c("selected", "nuclear", "cytoplasm", "whole_cell")) {
  domain <- match.arg(domain)
  class_weight <- c("0" = 0, "1+" = 1, "2+" = 2, "3+" = 3)
  if (!nrow(cells)) {
    return(list(
      n_cells = 0L,
      positive_cell_fraction = NA_real_,
      h_score = NA_real_,
      mean_cell_dab_od = NA_real_,
      median_cell_dab_od = NA_real_,
      mean_local_background_od = NA_real_
    ))
  }
  if (domain == "selected") {
    class_values <- cells$intensity_class
    positive_values <- cells$cell_positive
    od_values <- cells$dab_mean_od
  } else if (domain == "nuclear") {
    class_values <- cells$nuclear_intensity_class
    positive_values <- cells$nuclear_cell_positive
    od_values <- cells$nuclear_dab_mean_od
  } else if (domain == "cytoplasm") {
    class_values <- cells$cytoplasm_intensity_class
    positive_values <- cells$cytoplasm_cell_positive
    od_values <- cells$cytoplasm_dab_mean_od
  } else {
    class_values <- cells$whole_cell_intensity_class
    positive_values <- cells$whole_cell_positive
    od_values <- cells$whole_cell_dab_mean_od
  }
  weights <- unname(class_weight[as.character(class_values)])
  valid_weights <- is.finite(weights)
  valid_positive <- !is.na(positive_values)
  valid_od <- is.finite(od_values)
  list(
    n_cells = nrow(cells),
    positive_cell_fraction = if (any(valid_positive)) mean(positive_values[valid_positive]) else NA_real_,
    h_score = if (any(valid_weights)) 100 * mean(weights[valid_weights]) else NA_real_,
    mean_cell_dab_od = if (any(valid_od)) mean(od_values[valid_od]) else NA_real_,
    median_cell_dab_od = if (any(valid_od)) stats::median(od_values[valid_od]) else NA_real_,
    mean_local_background_od = if (any(is.finite(cells$local_background_od))) mean(cells$local_background_od, na.rm = TRUE) else NA_real_
  )
}

summarise_region <- function(result, region_mask, image_meta, roi_id = "GLOBAL", compartment = "global", selection_source = "automatic", selection_method = "whole_tissue") {
  deconv <- result$deconv
  region_tissue <- region_mask & deconv$tissue_mask & deconv$analysis_mask
  nucleus_mask <- region_tissue & (result$nuclei$labels > 0)
  cell_mask <- region_tissue & (result$cell_labels > 0)
  cytoplasm_mask <- cell_mask & !nucleus_mask
  extracellular_mask <- region_tissue & !cell_mask
  threshold <- unname(result$config$dab_thresholds[["negative"]])

  tissue <- pixel_metrics(region_tissue, deconv$dab_od, threshold)
  nuclear <- pixel_metrics(nucleus_mask, deconv$dab_od, threshold)
  cytoplasm <- pixel_metrics(cytoplasm_mask, deconv$dab_od, threshold)
  extracellular <- pixel_metrics(extracellular_mask, deconv$dab_od, threshold)

  cells <- result$cells
  if (nrow(cells)) {
    cx <- pmax(1L, pmin(dim(region_mask)[1], round(cells$nuc_m.cx)))
    cy <- pmax(1L, pmin(dim(region_mask)[2], round(cells$nuc_m.cy)))
    keep <- region_mask[cbind(cx, cy)] & deconv$tissue_mask[cbind(cx, cy)] & deconv$analysis_mask[cbind(cx, cy)]
    cells <- cells[keep]
  }
  selected_cell <- cell_metrics_for_domain(cells, "selected")
  nuclear_cell <- cell_metrics_for_domain(cells, "nuclear")
  cytoplasm_cell <- cell_metrics_for_domain(cells, "cytoplasm")
  whole_cell <- cell_metrics_for_domain(cells, "whole_cell")

  data.table(
    image_id = image_meta$image_id,
    biological_unit_id = image_meta$biological_unit_id,
    condition = image_meta$condition,
    field_id = image_meta$field_id,
    batch_id = image_meta$batch_id,
    marker = image_meta$marker,
    tissue_type = image_meta$tissue_type,
    cell_scoring_domain = result$config$cell_scoring_domain,
    roi_id = roi_id,
    compartment = compartment,
    selection_source = selection_source,
    selection_method = selection_method,
    tissue_area_px = tissue$area_px,
    tissue_positive_area_px = tissue$positive_area_px,
    tissue_positive_area_fraction = tissue$positive_area_fraction,
    tissue_mean_dab_od = tissue$mean_od,
    tissue_positive_mean_dab_od = tissue$positive_mean_od,
    tissue_integrated_dab_od = tissue$integrated_od,
    nuclear_area_px = nuclear$area_px,
    nuclear_positive_area_px = nuclear$positive_area_px,
    nuclear_positive_area_fraction = nuclear$positive_area_fraction,
    nuclear_mean_dab_od = nuclear$mean_od,
    nuclear_positive_mean_dab_od = nuclear$positive_mean_od,
    nuclear_integrated_dab_od = nuclear$integrated_od,
    cytoplasm_area_px = cytoplasm$area_px,
    cytoplasm_positive_area_px = cytoplasm$positive_area_px,
    cytoplasm_positive_area_fraction = cytoplasm$positive_area_fraction,
    cytoplasm_mean_dab_od = cytoplasm$mean_od,
    cytoplasm_positive_mean_dab_od = cytoplasm$positive_mean_od,
    cytoplasm_integrated_dab_od = cytoplasm$integrated_od,
    extracellular_area_px = extracellular$area_px,
    extracellular_positive_area_px = extracellular$positive_area_px,
    extracellular_positive_area_fraction = extracellular$positive_area_fraction,
    extracellular_mean_dab_od = extracellular$mean_od,
    extracellular_positive_mean_dab_od = extracellular$positive_mean_od,
    extracellular_integrated_dab_od = extracellular$integrated_od,
    n_cells = selected_cell$n_cells,
    positive_cell_fraction = selected_cell$positive_cell_fraction,
    h_score = selected_cell$h_score,
    mean_cell_dab_od = selected_cell$mean_cell_dab_od,
    median_cell_dab_od = selected_cell$median_cell_dab_od,
    mean_local_background_od = selected_cell$mean_local_background_od,
    nuclear_positive_cell_fraction = nuclear_cell$positive_cell_fraction,
    nuclear_h_score = nuclear_cell$h_score,
    nuclear_mean_cell_dab_od = nuclear_cell$mean_cell_dab_od,
    nuclear_median_cell_dab_od = nuclear_cell$median_cell_dab_od,
    cytoplasm_positive_cell_fraction = cytoplasm_cell$positive_cell_fraction,
    cytoplasm_h_score = cytoplasm_cell$h_score,
    cytoplasm_mean_cell_dab_od = cytoplasm_cell$mean_cell_dab_od,
    cytoplasm_median_cell_dab_od = cytoplasm_cell$median_cell_dab_od,
    whole_cell_positive_cell_fraction = whole_cell$positive_cell_fraction,
    whole_cell_h_score = whole_cell$h_score,
    whole_cell_mean_cell_dab_od = whole_cell$mean_cell_dab_od,
    whole_cell_median_cell_dab_od = whole_cell$median_cell_dab_od
  )
}

focus_score <- function(img) {
  rgb <- imageData(img)[, , 1:3, drop = FALSE]
  gray <- apply(rgb, c(1, 2), mean)
  gx <- gray[-1, , drop = FALSE] - gray[-nrow(gray), , drop = FALSE]
  gy <- gray[, -1, drop = FALSE] - gray[, -ncol(gray), drop = FALSE]
  mean(gx^2, na.rm = TRUE) + mean(gy^2, na.rm = TRUE)
}

make_qc_flags <- function(result, global_summary, cfg) {
  d <- dim(result$image)
  tissue_fraction <- sum(result$deconv$tissue_mask) / max(1, d[[1]] * d[[2]])
  background_values <- result$deconv$dab_od[result$deconv$tissue_mask & !(result$cell_labels > 0)]
  background_values <- background_values[is.finite(background_values)]
  background_od <- if (length(background_values)) stats::median(background_values) else NA_real_
  flags <- character()
  if (tissue_fraction < cfg$minimum_tissue_fraction_for_qc) flags <- c(flags, "LOW_TISSUE_COVERAGE")
  if (global_summary$n_cells < cfg$minimum_cells_for_qc) flags <- c(flags, "LOW_CELL_COUNT")
  if (is.finite(background_od) && background_od > cfg$high_background_od_for_qc) flags <- c(flags, "HIGH_EXTRACELLULAR_DAB_BACKGROUND")
  if (nrow(result$roi_masks$overlaps)) flags <- c(flags, "OVERLAPPING_INCLUDE_ROIS")
  if (identical(cfg$scale_mode, "pixel_fallback")) flags <- c(flags, "MISSING_PIXEL_SIZE_CALIBRATION")
  if (!length(flags)) flags <- "PASS"
  data.table(
    image_id = global_summary$image_id,
    width_px = d[[1]],
    height_px = d[[2]],
    image_pixels = d[[1]] * d[[2]],
    tissue_fraction = tissue_fraction,
    n_segmented_cells = global_summary$n_cells,
    n_overlapping_include_roi_pairs = nrow(result$roi_masks$overlaps),
    median_extracellular_background_od = background_od,
    focus_score = focus_score(result$image),
    scale_mode = cfg$scale_mode,
    pixel_size_um = cfg$pixel_size_um_effective,
    qc_flags = paste(flags, collapse = ";"),
    manual_review_required = !identical(flags, "PASS")
  )
}

analyse_ihc_image <- function(path, cfg = ihc_default_config(), pixel_size_um = NA_real_, roi_vertices = NULL, image_id = NA_character_) {
  img <- suppressWarnings(readImage(path))
  d <- dim(img)
  if (length(d) < 3L || d[[3]] < 3L) stop("Input must be an RGB brightfield image.")
  if (d[[1]] * d[[2]] > cfg$max_image_pixels) {
    stop("Image exceeds max_image_pixels. Tile/export a field from the whole-slide image or raise the limit deliberately.")
  }
  scaled_cfg <- resolve_scaled_config(cfg, pixel_size_um)
  roi_masks <- build_roi_masks(d[[1]], d[[2]], image_id, roi_vertices)
  analysis_mask <- !roi_masks$exclusion_mask
  deconv <- hdab_deconvolution(img, analysis_mask, scaled_cfg)
  nuclei <- segment_nuclei(deconv, scaled_cfg)
  cell_labels <- expand_cell_regions(nuclei$labels, deconv, scaled_cfg)
  cells <- measure_cells(nuclei$labels, cell_labels, deconv, scaled_cfg)
  list(
    image = img,
    deconv = deconv,
    nuclei = nuclei,
    cell_labels = cell_labels,
    cells = cells,
    roi_masks = roi_masks,
    config = scaled_cfg
  )
}

ihc_qc_palette <- function() {
  c(
    global = "#2563EB",
    nucleus = "#DC2626",
    cytoplasm = "#16A34A",
    extracellular = "#F97316",
    exclude = "#6B7280",
    tumor = "#7C3AED",
    stroma = "#0891B2",
    interface = "#CA8A04",
    custom = "#DB2777",
    artifact = "#6B7280"
  )
}

hex_to_rgb01 <- function(hex) {
  as.numeric(grDevices::col2rgb(hex)) / 255
}

mask_boundary <- function(mask, radius_px = 1L) {
  if (!any(mask)) return(matrix(FALSE, nrow(mask), ncol(mask)))
  brush <- makeBrush(odd_brush_size(max(1L, radius_px)), shape = "disc")
  outer <- dilate(as_gray_image(mask), brush) > 0
  inner <- erode(as_gray_image(mask), brush) > 0
  outer & !inner
}

alpha_blend_mask <- function(rgb, mask, colour, alpha) {
  if (!any(mask) || !is.finite(alpha) || alpha <= 0) return(rgb)
  colour_rgb <- hex_to_rgb01(colour)
  for (channel in seq_len(3L)) {
    layer <- rgb[, , channel]
    layer[mask] <- (1 - alpha) * layer[mask] + alpha * colour_rgb[[channel]]
    rgb[, , channel] <- layer
  }
  rgb
}

reconstruct_hdab_image <- function(result) {
  h <- as.vector(result$deconv$hematoxylin_od)
  d <- as.vector(result$deconv$dab_od)
  concentration <- cbind(h, d)
  stain_vectors <- result$deconv$stain_matrix[, 1:2, drop = FALSE]
  reconstructed_od <- concentration %*% t(stain_vectors)
  reconstructed_rgb <- exp(-reconstructed_od)
  reconstructed_rgb[!is.finite(reconstructed_rgb)] <- 1
  reconstructed_rgb <- clamp01(reconstructed_rgb)
  dims <- dim(result$image)
  Image(array(reconstructed_rgb, dim = c(dims[[1]], dims[[2]], 3L)), colormode = Color)
}

compartment_masks <- function(result) {
  tissue <- result$deconv$tissue_mask & result$deconv$analysis_mask
  nucleus <- tissue & (result$nuclei$labels > 0)
  cell <- tissue & (result$cell_labels > 0)
  cytoplasm <- cell & !nucleus
  extracellular <- tissue & !cell
  list(
    global = tissue,
    nucleus = nucleus,
    cytoplasm = cytoplasm,
    extracellular = extracellular,
    exclude = result$roi_masks$exclusion_mask
  )
}

paint_compartment_overlay <- function(result, base = c("hdab", "rgb"), fill_alpha = NULL, boundary_alpha = NULL) {
  base <- match.arg(base)
  if (is.null(fill_alpha)) fill_alpha <- result$config$qc_overlay_fill_alpha
  if (is.null(boundary_alpha)) boundary_alpha <- result$config$qc_overlay_boundary_alpha
  base_image <- if (base == "hdab") reconstruct_hdab_image(result) else result$image
  rgb <- imageData(base_image)[, , 1:3, drop = FALSE]
  masks <- compartment_masks(result)
  palette <- ihc_qc_palette()
  order <- c("global", "extracellular", "cytoplasm", "nucleus", "exclude")
  for (name in order) {
    mask <- masks[[name]]
    if (is.null(mask) || !any(mask)) next
    this_fill <- if (name == "global") 0 else fill_alpha
    rgb <- alpha_blend_mask(rgb, mask, palette[[name]], this_fill)
    rgb <- alpha_blend_mask(rgb, mask_boundary(mask, 1L), palette[[name]], boundary_alpha)
  }
  Image(clamp01(rgb), colormode = Color)
}

paint_segmentation_overlay <- function(result) {
  out <- result$image
  if (is.finite(max(result$cell_labels)) && max(result$cell_labels) > 0L) {
    out <- paintObjects(result$cell_labels, out, opac = c(1, 1), col = c(ihc_qc_palette()[["cytoplasm"]], NA), thick = TRUE, closed = TRUE)
  }
  if (is.finite(max(result$nuclei$labels)) && max(result$nuclei$labels) > 0L) {
    out <- paintObjects(result$nuclei$labels, out, opac = c(1, 1), col = c(ihc_qc_palette()[["nucleus"]], NA), thick = TRUE, closed = TRUE)
  }
  out
}

safe_crop_bounds <- function(img, x_min, x_max, y_min, y_max, padding_fraction = 0.08) {
  d <- dim(img)
  dx <- max(1, x_max - x_min)
  dy <- max(1, y_max - y_min)
  pad_x <- round(dx * padding_fraction)
  pad_y <- round(dy * padding_fraction)
  list(
    x1 = max(1L, floor(x_min - pad_x)),
    x2 = min(d[[1]], ceiling(x_max + pad_x)),
    y1 = max(1L, floor(y_min - pad_y)),
    y2 = min(d[[2]], ceiling(y_max + pad_y))
  )
}

safe_crop <- function(img, x_min, x_max, y_min, y_max, padding_fraction = 0.08) {
  bounds <- safe_crop_bounds(img, x_min, x_max, y_min, y_max, padding_fraction)
  img[bounds$x1:bounds$x2, bounds$y1:bounds$y2, , drop = FALSE]
}

plot_raster_panel <- function(img, title = NULL) {
  dims <- dim(img)
  graphics::plot(NA, xlim = c(1, dims[[1]]), ylim = c(dims[[2]], 1), asp = 1, axes = FALSE, xlab = "", ylab = "")
  graphics::rasterImage(as.raster(img), 1, dims[[2]], dims[[1]], 1, interpolate = TRUE)
  if (!is.null(title)) graphics::title(main = title, line = 0.5, cex.main = 0.95)
}

scaled_gray_image <- function(values, mask = NULL, upper_quantile = 0.995) {
  upper_quantile <- min(1, max(0.5, as.numeric(upper_quantile)))
  Image(safe_scale01(values, mask, probs = c(0, upper_quantile)), colormode = Grayscale)
}

od_display_upper <- function(values, mask = NULL, upper_quantile = 0.99) {
  upper_quantile <- min(1, max(0.5, as.numeric(upper_quantile)))
  observed <- if (is.null(mask)) as.vector(values) else values[mask]
  observed <- observed[is.finite(observed)]
  if (!length(observed)) return(NA_real_)
  upper <- as.numeric(stats::quantile(observed, upper_quantile, na.rm = TRUE, names = FALSE))
  if (!is.finite(upper) || upper <= 0) upper <- max(observed, na.rm = TRUE)
  upper
}

plot_gray_od_panel <- function(values, mask, title, upper_quantile = 0.99) {
  upper <- od_display_upper(values, mask, upper_quantile)
  plot_raster_panel(scaled_gray_image(values, mask, upper_quantile), title)
  if (!is.finite(upper) || upper <= 0) return(invisible(NULL))
  dims <- dim(values)
  x_start <- dims[[1]] * 0.05
  x_end <- dims[[1]] * 0.40
  y_top <- dims[[2]] * 0.88
  y_bottom <- dims[[2]] * 0.95
  graphics::rect(
    x_start - dims[[1]] * 0.012,
    y_top - dims[[2]] * 0.035,
    x_end + dims[[1]] * 0.012,
    y_bottom + dims[[2]] * 0.065,
    col = grDevices::adjustcolor("white", alpha.f = 0.80),
    border = "grey35",
    lwd = 0.7
  )
  n_step <- 64L
  edges <- seq(x_start, x_end, length.out = n_step + 1L)
  for (i in seq_len(n_step)) {
    graphics::rect(
      edges[[i]], y_top, edges[[i + 1L]], y_bottom,
      col = grDevices::gray(1 - (i - 1L) / max(1L, n_step - 1L)),
      border = NA
    )
  }
  graphics::rect(x_start, y_top, x_end, y_bottom, border = "grey20", lwd = 0.5)
  graphics::text(x_start, y_bottom + dims[[2]] * 0.035, labels = "0", adj = c(0, 0.5), cex = 0.62)
  graphics::text(
    x_end,
    y_bottom + dims[[2]] * 0.035,
    labels = paste0("q", round(100 * upper_quantile), " = ", formatC(upper, digits = 3, format = "fg")),
    adj = c(1, 0.5),
    cex = 0.62
  )
  invisible(NULL)
}

dab_positive_mask <- function(result) {
  tissue <- result$deconv$tissue_mask & result$deconv$analysis_mask
  tissue & is.finite(result$deconv$dab_od) & result$deconv$dab_od >= result$config$dab_thresholds[["negative"]]
}

paint_dab_positive_overlay <- function(result, base = c("hdab", "rgb"), alpha = 0.45) {
  base <- match.arg(base)
  base_image <- if (base == "hdab") reconstruct_hdab_image(result) else result$image
  rgb <- imageData(base_image)[, , 1:3, drop = FALSE]
  positive <- dab_positive_mask(result)
  rgb <- alpha_blend_mask(rgb, positive, ihc_qc_palette()[["extracellular"]], alpha)
  rgb <- alpha_blend_mask(rgb, mask_boundary(positive, 1L), ihc_qc_palette()[["extracellular"]], 0.95)
  Image(clamp01(rgb), colormode = Color)
}

paint_analysis_mask_overlay <- function(result) {
  rgb <- imageData(reconstruct_hdab_image(result))[, , 1:3, drop = FALSE]
  tissue <- result$deconv$tissue_mask & result$deconv$analysis_mask
  excluded <- result$roi_masks$exclusion_mask
  rgb <- alpha_blend_mask(rgb, mask_boundary(tissue, 1L), ihc_qc_palette()[["global"]], 0.95)
  rgb <- alpha_blend_mask(rgb, excluded, ihc_qc_palette()[["exclude"]], 0.35)
  rgb <- alpha_blend_mask(rgb, mask_boundary(excluded, 1L), ihc_qc_palette()[["exclude"]], 0.95)
  Image(clamp01(rgb), colormode = Color)
}

save_qc_overview <- function(result, image_id, path) {
  grDevices::png(path, width = 3200, height = 1720, res = 180, bg = "white")
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 4), mar = c(1, 1, 3, 1), oma = c(4.2, 0, 3, 0), xaxs = "i", yaxs = "i")
  plot_raster_panel(result$image, "Original RGB")
  plot_raster_panel(reconstruct_hdab_image(result), "H-DAB reconstruction")
  plot_gray_od_panel(
    result$deconv$hematoxylin_od,
    result$deconv$analysis_mask,
    "Hematoxylin OD",
    result$config$qc_od_display_upper_quantile
  )
  plot_gray_od_panel(
    result$deconv$dab_od,
    result$deconv$analysis_mask,
    "DAB OD",
    result$config$qc_od_display_upper_quantile
  )
  if (isTRUE(result$config$qc_include_dab_positive_mask)) {
    plot_raster_panel(
      paint_dab_positive_overlay(result, "hdab"),
      paste0("DAB-positive pixels (OD >= ", formatC(result$config$dab_thresholds[["negative"]], digits = 3, format = "fg"), ")")
    )
  } else {
    plot_raster_panel(paint_analysis_mask_overlay(result), "Analysis tissue + exclusions")
  }
  plot_raster_panel(paint_segmentation_overlay(result), "Nuclei + propagated cells")
  plot_raster_panel(paint_compartment_overlay(result, "hdab"), "Measurement domains on H-DAB")
  plot_raster_panel(paint_analysis_mask_overlay(result), "Analysis tissue + exclusions")
  palette <- ihc_qc_palette()
  graphics::legend(
    "bottom", legend = c("Global", "Nucleus", "Cytoplasm", "Extracellular", "Exclude"),
    col = unname(palette[c("global", "nucleus", "cytoplasm", "extracellular", "exclude")]),
    lwd = 4, horiz = TRUE, bty = "n", cex = 0.68, inset = 0.01
  )
  scale_note <- if (identical(result$config$scale_mode, "physical_um")) {
    paste0("Physical calibration used: ", formatC(result$config$pixel_size_um_effective, digits = 4, format = "fg"), " um/pixel.")
  } else {
    "Pixel fallback used: no pixel_size_um calibration was supplied. Any visible scale bar is source-image content and is not a program-generated calibration."
  }
  graphics::mtext(
    paste0(scale_note, " Orange threshold overlay marks DAB-positive tissue pixels; gray marks recorded exclusions."),
    outer = TRUE,
    side = 1,
    line = 1.2,
    cex = 0.68,
    col = "grey25"
  )
  graphics::mtext(paste0(image_id, " — IHC QC overview"), outer = TRUE, side = 3, line = 1, font = 2, cex = 1.15)
}

roi_colour <- function(compartment, action = "include") {
  palette <- ihc_qc_palette()
  key <- tolower(as.character(compartment))
  if (tolower(as.character(action)) == "exclude") return(palette[["exclude"]])
  if (key %in% names(palette)) return(palette[[key]])
  palette[["custom"]]
}

save_roi_overview <- function(img, roi_vertices, image_id, path, title_suffix = "ROI selection proof") {
  roi <- normalise_roi_table(roi_vertices)
  target_image_id <- as.character(image_id)
  if (nrow(roi)) roi <- roi[get("image_id") == target_image_id]
  grDevices::png(path, width = 1800, height = 1100, res = 160, bg = "white")
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(1, 1, 3, 1), xaxs = "i", yaxs = "i")
  plot_raster_panel(img)
  dims <- dim(img)
  if (nrow(roi)) {
    ids <- unique(roi$roi_id)
    for (id in ids) {
      target_roi_id <- as.character(id)
      polygon <- roi[get("roi_id") == target_roi_id][order(vertex_order)]
      colour <- roi_colour(polygon$compartment[[1]], polygon$action[[1]])
      lty <- if (polygon$action[[1]] == "exclude") 2 else 1
      graphics::polygon(polygon$x, polygon$y, border = colour, lwd = 4, lty = lty)
      label <- paste0(id, " · ", polygon$compartment[[1]], " · ", polygon$action[[1]])
      graphics::text(min(polygon$x), min(polygon$y), labels = label, pos = 4, cex = 0.85, col = colour, font = 2)
    }
  } else {
    graphics::rect(1, 1, dims[[1]], dims[[2]], border = ihc_qc_palette()[["global"]], lwd = 4)
    graphics::text(1, 1, labels = "GLOBAL · whole tissue", pos = 4, cex = 1, col = ihc_qc_palette()[["global"]], font = 2)
  }
  graphics::title(main = paste0(image_id, " — ", title_suffix), family = "sans")
}

save_roi_contact_sheet <- function(img, roi_vertices, image_id, path) {
  roi <- normalise_roi_table(roi_vertices)
  target_image_id <- as.character(image_id)
  if (nrow(roi)) roi <- roi[get("image_id") == target_image_id & action == "include"]
  if (!nrow(roi)) {
    grDevices::png(path, width = 1200, height = 850, res = 150, bg = "white")
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::par(mar = c(1, 1, 3, 1), xaxs = "i", yaxs = "i")
    plot_raster_panel(img)
    dims <- dim(img)
    graphics::rect(1, 1, dims[[1]], dims[[2]], border = ihc_qc_palette()[["global"]], lwd = 5)
    graphics::title(main = paste0(image_id, " — GLOBAL whole-tissue selection"))
    return(invisible(NULL))
  }
  meta <- unique(roi[, .(roi_id, compartment, action)])
  n <- nrow(meta)
  ncol_plot <- min(3L, max(1L, ceiling(sqrt(n))))
  nrow_plot <- ceiling(n / ncol_plot)
  grDevices::png(path, width = 700 * ncol_plot, height = 550 * nrow_plot, res = 140, bg = "white")
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(nrow_plot, ncol_plot), mar = c(1, 1, 3, 1), xaxs = "i", yaxs = "i")
  for (i in seq_len(n)) {
    target_roi_id <- as.character(meta$roi_id[[i]])
    polygon <- roi[get("roi_id") == target_roi_id][order(vertex_order)]
    bounds <- safe_crop_bounds(img, min(polygon$x), max(polygon$x), min(polygon$y), max(polygon$y))
    crop <- img[bounds$x1:bounds$x2, bounds$y1:bounds$y2, , drop = FALSE]
    dims <- dim(crop)
    local_x <- polygon$x - bounds$x1 + 1
    local_y <- polygon$y - bounds$y1 + 1
    plot_raster_panel(crop)
    colour <- roi_colour(meta$compartment[[i]], meta$action[[i]])
    graphics::polygon(local_x, local_y, border = colour, lwd = 6)
    graphics::rect(1, 1, dims[[1]], dims[[2]], border = colour, lwd = 2, lty = 3)
    graphics::title(main = paste0(meta$roi_id[[i]], " · ", meta$compartment[[i]]), col.main = colour, font.main = 2)
  }
}

save_roi_evidence_triplets <- function(result, roi_vertices, image_id, outdir) {
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  roi <- normalise_roi_table(roi_vertices)
  target_image_id <- as.character(image_id)
  if (nrow(roi)) roi <- roi[get("image_id") == target_image_id]
  hdab <- reconstruct_hdab_image(result)
  overlay <- paint_compartment_overlay(result, "hdab")
  if (!nrow(roi)) {
    writeImage(result$image, file.path(outdir, paste0(image_id, "__GLOBAL__rgb.png")), quality = 95)
    writeImage(hdab, file.path(outdir, paste0(image_id, "__GLOBAL__hdab.png")), quality = 95)
    writeImage(overlay, file.path(outdir, paste0(image_id, "__GLOBAL__domains.png")), quality = 95)
    return(invisible(NULL))
  }
  ids <- unique(roi$roi_id)
  for (id in ids) {
    target_roi_id <- as.character(id)
    polygon <- roi[get("roi_id") == target_roi_id][order(vertex_order)]
    bounds <- safe_crop_bounds(result$image, min(polygon$x), max(polygon$x), min(polygon$y), max(polygon$y))
    rgb_crop <- result$image[bounds$x1:bounds$x2, bounds$y1:bounds$y2, , drop = FALSE]
    hdab_crop <- hdab[bounds$x1:bounds$x2, bounds$y1:bounds$y2, , drop = FALSE]
    domain_crop <- overlay[bounds$x1:bounds$x2, bounds$y1:bounds$y2, , drop = FALSE]
    stem <- paste0(image_id, "__", gsub("[^A-Za-z0-9_-]+", "_", id))
    writeImage(rgb_crop, file.path(outdir, paste0(stem, "__rgb.png")), quality = 95)
    writeImage(hdab_crop, file.path(outdir, paste0(stem, "__hdab.png")), quality = 95)
    grDevices::png(file.path(outdir, paste0(stem, "__selection.png")), width = 1000, height = 800, res = 150, bg = "white")
    graphics::par(mar = c(1, 1, 3, 1), xaxs = "i", yaxs = "i")
    plot_raster_panel(domain_crop)
    local_x <- polygon$x - bounds$x1 + 1
    local_y <- polygon$y - bounds$y1 + 1
    colour <- roi_colour(polygon$compartment[[1]], polygon$action[[1]])
    graphics::polygon(local_x, local_y, border = colour, lwd = 6, lty = if (polygon$action[[1]] == "exclude") 2 else 1)
    graphics::title(main = paste0(id, " · ", polygon$compartment[[1]], " · ", polygon$action[[1]]), col.main = colour)
    grDevices::dev.off()
  }
}

