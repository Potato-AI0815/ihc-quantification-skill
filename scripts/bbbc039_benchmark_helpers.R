# Reusable BBBC039 instance-mask decoding and object-matching contracts.
# This file deliberately contains no segmentation algorithm.

decode_bbbc039_mask <- function(gt_img) {
  gt_arr <- as.array(gt_img)
  if (length(dim(gt_arr)) < 3L) {
    gt_mask <- as.matrix(gt_img > 0)
    return(as.matrix(EBImage::bwlabel(EBImage::Image(gt_mask, colormode = "Grayscale"))))
  }

  n_channels <- dim(gt_arr)[3L]
  n_use <- min(3L, n_channels)
  rgb <- gt_arr[, , seq_len(n_use), drop = FALSE]
  # EBImage stores PNG channels in [0, 1]; quantising first prevents tiny
  # floating-point differences from creating multiple labels for one color.
  rgb8 <- array(as.integer(round(pmin(1, pmax(0, rgb)) * 255)), dim = dim(rgb))
  code <- rgb8[, , 1L]
  if (n_use >= 2L) code <- code + 256 * rgb8[, , 2L]
  if (n_use >= 3L) code <- code + 65536 * rgb8[, , 3L]

  # The most frequent color is the background in the distributed BBBC039
  # masks. Treat every other color as an instance-color candidate.
  code_vec <- as.vector(code)
  background_code <- as.numeric(names(which.max(table(code_vec))))
  object_codes <- sort(unique(code_vec[code_vec != background_code]))
  labels <- matrix(0L, nrow = dim(code)[1L], ncol = dim(code)[2L])
  next_id <- 0L
  for (object_code in object_codes) {
    color_mask <- code == object_code
    components <- as.matrix(EBImage::bwlabel(EBImage::Image(color_mask, colormode = "Grayscale")))
    n_components <- if (length(components) && max(components) > 0) max(components) else 0L
    if (n_components > 0L) {
      components[components > 0] <- components[components > 0] + next_id
      labels[color_mask] <- components[color_mask]
      next_id <- next_id + n_components
    }
  }
  labels
}

one_to_one_iou_matching <- function(pred_labels, gt_labels, iou_threshold = 0.5) {
  n_pred <- if (length(pred_labels) && max(pred_labels) > 0) max(pred_labels) else 0L
  n_gt <- if (length(gt_labels) && max(gt_labels) > 0) max(gt_labels) else 0L
  if (n_pred == 0L || n_gt == 0L) {
    return(list(tp = 0L, matches = numeric(), iou = matrix(numeric(), nrow = n_pred, ncol = n_gt)))
  }

  # R's tabulate() already uses label 1 as its first bin; zero is ignored,
  # so do not drop the first element (which would shift every object size).
  pred_size <- tabulate(as.integer(pred_labels), nbins = n_pred)
  gt_size <- tabulate(as.integer(gt_labels), nbins = n_gt)
  iou <- matrix(0, nrow = n_pred, ncol = n_gt)
  for (p_id in seq_len(n_pred)) {
    overlap_counts <- tabulate(as.integer(gt_labels[pred_labels == p_id]), nbins = n_gt)
    gt_ids <- which(overlap_counts > 0)
    if (!length(gt_ids)) next
    intersections <- overlap_counts[gt_ids]
    unions <- pred_size[p_id] + gt_size[gt_ids] - intersections
    iou[p_id, gt_ids] <- intersections / unions
  }

  candidate <- which(iou >= iou_threshold, arr.ind = TRUE)
  if (!nrow(candidate)) return(list(tp = 0L, matches = numeric(), iou = iou))
  candidate <- candidate[order(iou[cbind(candidate[, 1L], candidate[, 2L])], decreasing = TRUE), , drop = FALSE]
  used_pred <- rep(FALSE, n_pred)
  used_gt <- rep(FALSE, n_gt)
  matched_iou <- numeric()
  for (i in seq_len(nrow(candidate))) {
    p_id <- candidate[i, 1L]
    g_id <- candidate[i, 2L]
    if (used_pred[p_id] || used_gt[g_id]) next
    used_pred[p_id] <- TRUE
    used_gt[g_id] <- TRUE
    matched_iou <- c(matched_iou, iou[p_id, g_id])
  }
  list(tp = length(matched_iou), matches = matched_iou, iou = iou)
}
