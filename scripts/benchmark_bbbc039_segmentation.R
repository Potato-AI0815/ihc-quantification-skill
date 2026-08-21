# scripts/benchmark_bbbc039_segmentation.R
# Downloads the official BBBC039 validation split and evaluates ground-truth
# segmentation metrics (P3).
# Part of IHC/IF Quantification Skill v2.3.0-alpha.2

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root <- if (length(script_arg) == 1L) {
  dirname(dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE)))
} else {
  getwd()
}

source(file.path(root, "scripts", "if_segmentation.R"))
source(file.path(root, "scripts", "path_utils.R"))

cache_dir <- file.path(root, "work", "bbbc039_cache")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

overlay_dir <- file.path(root, "work", "segmentation_benchmark_overlays")
dir.create(overlay_dir, recursive = TRUE, showWarnings = FALSE)

# 1. Download BBBC039 Masks and Images if needed
masks_zip <- file.path(cache_dir, "masks.zip")
images_zip <- file.path(cache_dir, "images.zip")
metadata_zip <- file.path(cache_dir, "metadata.zip")

url_masks <- "https://data.broadinstitute.org/bbbc/BBBC039/masks.zip"
url_images <- "https://data.broadinstitute.org/bbbc/BBBC039/images.zip"
url_metadata <- "https://data.broadinstitute.org/bbbc/BBBC039/metadata.zip"

if (!dir.exists(file.path(cache_dir, "masks"))) {
  cat("Downloading BBBC039 ground-truth masks (2.7 MB)...\n")
  utils::download.file(url_masks, destfile = masks_zip, mode = "wb", quiet = TRUE)
  utils::unzip(masks_zip, exdir = file.path(cache_dir, "masks"))
}

if (!dir.exists(file.path(cache_dir, "images"))) {
  cat("Downloading BBBC039 sample images...\n")
  utils::download.file(url_images, destfile = images_zip, mode = "wb", quiet = TRUE)
  utils::unzip(images_zip, exdir = file.path(cache_dir, "images"))
}

if (!file.exists(file.path(cache_dir, "metadata", "validation.txt"))) {
  cat("Downloading BBBC039 official split metadata...\n")
  utils::download.file(url_metadata, destfile = metadata_zip, mode = "wb", quiet = TRUE)
  utils::unzip(metadata_zip, exdir = cache_dir)
}

mask_files <- list.files(file.path(cache_dir, "masks"), pattern = "\\.(png|tif|tiff)$", full.names = TRUE, recursive = TRUE)
img_files <- list.files(file.path(cache_dir, "images"), pattern = "\\.(png|tif|tiff)$", full.names = TRUE, recursive = TRUE)

if (length(mask_files) == 0L || length(img_files) == 0L) {
  stop("BBBC039 files not found in cache.")
}

cat(sprintf("Found %d images and %d ground-truth masks in BBBC039.\n", length(img_files), length(mask_files)))

# Use the official validation partition rather than an arbitrary filesystem
# ordering.  This keeps the benchmark comparable with published BBBC039
# evaluations and makes the selected image set auditable.
validation_names <- trimws(readLines(file.path(cache_dir, "metadata", "validation.txt"), warn = FALSE))
validation_names <- validation_names[nzchar(validation_names)]
validation_stems <- tools::file_path_sans_ext(basename(validation_names))
image_stems <- tools::file_path_sans_ext(basename(img_files))
val_imgs <- img_files[match(validation_stems, image_stems)]
val_imgs <- val_imgs[!is.na(val_imgs)]
if (!length(val_imgs)) stop("No BBBC039 images matched the official validation split metadata.")
cat(sprintf("Using %d images from the official BBBC039 validation split.\n", length(val_imgs)))

# BBBC039 PNG masks use colors to encode touching nuclei as separate
# instances.  Decode each non-background color into connected components
# instead of collapsing the RGB mask to a binary foreground mask.
decode_bbbc039_mask <- function(gt_img) {
  gt_arr <- as.array(gt_img)
  if (length(dim(gt_arr)) < 3L) {
    gt_mask <- as.matrix(gt_img > 0)
    return(as.matrix(EBImage::bwlabel(EBImage::Image(gt_mask, colormode = "Grayscale"))))
  }

  n_channels <- dim(gt_arr)[3L]
  n_use <- min(3L, n_channels)
  rgb <- gt_arr[, , seq_len(n_use), drop = FALSE]
  # EBImage stores PNG channels in [0, 1]; quantising before coding avoids
  # tiny floating-point differences creating multiple labels for one color.
  rgb8 <- array(as.integer(round(pmin(1, pmax(0, rgb)) * 255)), dim = dim(rgb))
  code <- rgb8[, , 1L]
  if (n_use >= 2L) code <- code + 256 * rgb8[, , 2L]
  if (n_use >= 3L) code <- code + 65536 * rgb8[, , 3L]

  # The most frequent color is the background in the distributed BBBC039
  # masks.  Treat every other color as an instance-color candidate.
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
  if (n_pred == 0L || n_gt == 0L) return(list(tp = 0L, iou = matrix(numeric(), nrow = n_pred, ncol = n_gt)))

  pred_size <- tabulate(as.integer(pred_labels), nbins = n_pred + 1L)[-1L]
  gt_size <- tabulate(as.integer(gt_labels), nbins = n_gt + 1L)[-1L]
  iou <- matrix(0, nrow = n_pred, ncol = n_gt)
  for (p_id in seq_len(n_pred)) {
    overlap_counts <- tabulate(as.integer(gt_labels[pred_labels == p_id]), nbins = n_gt + 1L)[-1L]
    gt_ids <- which(overlap_counts > 0)
    if (!length(gt_ids)) next
    intersections <- overlap_counts[gt_ids]
    unions <- pred_size[p_id] + gt_size[gt_ids] - intersections
    iou[p_id, gt_ids] <- intersections / unions
  }

  candidate <- which(iou >= iou_threshold, arr.ind = TRUE)
  if (!nrow(candidate)) return(list(tp = 0L, iou = iou))
  candidate <- candidate[order(iou[cbind(candidate[, 1L], candidate[, 2L])], decreasing = TRUE), , drop = FALSE]
  used_pred <- rep(FALSE, n_pred)
  used_gt <- rep(FALSE, n_gt)
  tp <- 0L
  for (i in seq_len(nrow(candidate))) {
    p_id <- candidate[i, 1L]
    g_id <- candidate[i, 2L]
    if (used_pred[p_id] || used_gt[g_id]) next
    used_pred[p_id] <- TRUE
    used_gt[g_id] <- TRUE
    tp <- tp + 1L
  }
  list(tp = tp, iou = iou)
}

benchmark_results <- list()

for (img_path in val_imgs) {
  stem <- tools::file_path_sans_ext(basename(img_path))
  mask_match <- grep(stem, mask_files, fixed = TRUE, value = TRUE)
  if (length(mask_match) == 0L) next
  mask_path <- mask_match[1L]
  vname <- stem

  # Read Image and GT Mask
  raw_img <- EBImage::readImage(img_path)
  gt_img <- EBImage::readImage(mask_path)

  # Extract 2D matrix
  raw_mat <- as.matrix(if (length(dim(raw_img)) >= 3L) raw_img[, , 1L] else raw_img)
  raw_mat <- (raw_mat - min(raw_mat)) / (max(raw_mat) - min(raw_mat) + 1e-8)

  # Decode the color-coded instance mask before deriving its binary union.
  gt_labels <- decode_bbbc039_mask(gt_img)
  gt_mask <- gt_labels > 0

  # Segment using default EBImage pipeline
  seg <- segment_if_image(
    nuclear_mat = raw_mat,
    segmentation_engine = "ebimage",
    nuc_threshold_method = "otsu",
    nuc_min_area = 30,
    nuc_max_area = 4000
  )

  pred_mask <- as.matrix(seg$nuc_mask)
  pred_labels <- as.matrix(seg$nuc_labels)

  # 1. Pixel-level metrics
  intersection <- sum(pred_mask & gt_mask)
  union_px <- sum(pred_mask | gt_mask)
  dice <- if ((sum(pred_mask) + sum(gt_mask)) > 0) (2 * intersection) / (sum(pred_mask) + sum(gt_mask)) else 0.0
  iou <- if (union_px > 0) intersection / union_px else 0.0

  # 2. Object-level metrics (IoU threshold = 0.5)
  n_pred <- if (length(pred_labels) > 0 && max(pred_labels) > 0) max(pred_labels) else 0L
  n_gt <- if (length(gt_labels) > 0 && max(gt_labels) > 0) max(gt_labels) else 0L
  matching <- one_to_one_iou_matching(pred_labels, gt_labels, iou_threshold = 0.5)
  tp <- matching$tp

  fp <- max(0L, n_pred - tp)
  fn <- max(0L, n_gt - tp)

  obj_prec <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_
  obj_rec  <- if ((tp + fn) > 0) tp / (tp + fn) else NA_real_
  obj_f1   <- if (is.finite(obj_prec) && is.finite(obj_rec) && (obj_prec + obj_rec) > 0) {
    (2 * obj_prec * obj_rec) / (obj_prec + obj_rec)
  } else {
    NA_real_
  }
  count_rel_err <- if (n_gt > 0) abs(n_pred - n_gt) / n_gt else NA_real_

  # Export visual comparison overlay
  ov_rgb <- array(0, dim = c(nrow(raw_mat), ncol(raw_mat), 3L))
  ov_rgb[, , 1L] <- ifelse(gt_mask & !pred_mask, 0.9, raw_mat * 0.5) # Red = GT False Negatives
  ov_rgb[, , 2L] <- ifelse(pred_mask & gt_mask, 0.9, raw_mat * 0.5)   # Green = True Positives (Overlap)
  ov_rgb[, , 3L] <- ifelse(pred_mask & !gt_mask, 0.9, raw_mat * 0.5) # Blue = Predicted False Positives

  ov_path <- file.path(overlay_dir, paste0(vname, "_pred_vs_gt.png"))
  EBImage::writeImage(EBImage::Image(ov_rgb, colormode = "Color"), ov_path)

  benchmark_results[[length(benchmark_results) + 1L]] <- data.table(
    image_name = vname,
    n_gt_cells = n_gt,
    n_pred_cells = n_pred,
    cell_count_rel_error = count_rel_err,
    dice = dice,
    iou = iou,
    object_precision = obj_prec,
    object_recall = obj_rec,
    object_f1 = obj_f1
  )
}

dt_benchmark <- rbindlist(benchmark_results)
fwrite(dt_benchmark, file.path(root, "work", "segmentation_benchmark.csv"))
fwrite(dt_benchmark, file.path(root, "segmentation_benchmark.csv"))

mean_dice <- mean(dt_benchmark$dice)
mean_iou <- mean(dt_benchmark$iou)
mean_f1 <- mean(dt_benchmark$object_f1, na.rm = TRUE)
mean_prec <- mean(dt_benchmark$object_precision, na.rm = TRUE)
mean_rec <- mean(dt_benchmark$object_recall, na.rm = TRUE)
mean_count_err <- mean(dt_benchmark$cell_count_rel_error, na.rm = TRUE)
zero_gt_images <- sum(dt_benchmark$n_gt_cells == 0L)

cat("\n=== BBBC039 Ground-Truth Segmentation Benchmark Summary ===\n")
print(dt_benchmark)
cat(sprintf("\nMean Metrics: Dice = %.3f | IoU = %.3f | Object F1 = %.3f | Precision = %.3f | Recall = %.3f | Count Rel Err = %.1f%%\n",
            mean_dice, mean_iou, mean_f1, mean_prec, mean_rec, mean_count_err * 100))

# Generate SEGMENTATION_BENCHMARK_REPORT.md
report_md <- sprintf("# BBBC039 Ground-Truth Segmentation Benchmark Report

**Dataset**: Broad Bioimage Benchmark Collection ([BBBC039](https://data.broadinstitute.org/bbbc/BBBC039/)) — U2OS Nuclei
**Segmentation Engine**: Native `EBImage` Classical Watershed (Gaussian smoothing + Otsu + Hole filling + Distance Transform + Watershed)
**Date**: %s
**Status**: **BENCHMARKED_WITH_WARNINGS (Classical Baseline; official validation split)**

---

## 1. Methodological Clarification & Model Scope
- **Non-Deep-Learning Baseline**: The default segmentation engine in this workflow is a classical algorithmic distance-watershed pipeline implemented in R / `EBImage`. It operates without deep learning weights, pre-trained neural networks, or GPU requirements.
- **Scientific Integrity Policy**: Parameter sets were **not** artificially overfit to achieve inflated metrics on the validation dataset. The results below reflect the honest out-of-the-box performance of standard mathematical morphology.
- **Ground-truth decoding**: BBBC039 color-coded instance masks were decoded per non-background color before object scoring, preserving touching nuclei as separate instances.
- **Object matching**: Object precision/recall/F1 use a one-to-one greedy assignment over the full predicted-vs-ground-truth IoU matrix at IoU $\\ge 0.5$; one ground-truth nucleus cannot be counted twice.
- **Partition**: All images in the official BBBC039 validation split from `metadata.zip` are evaluated; this is not an arbitrary filesystem-order subset.
- **Non-evaluable images**: %d validation image(s) contained no decoded ground-truth objects; object recall/F1 and count error are reported as `NA` for those images and excluded from their aggregate means.
- **Modular AI Extensibility**: For challenging tissues or densely packed clusters where classical watershed underperforms, users can import deep-learning masks (from Cellpose, StarDist, or QuPath) via the `external_mask` parameter.

---

## 2. Quantitative Benchmark Results across Validation Images

| Image ID | Ground-Truth Count | Predicted Count | Count Rel Err | Pixel Dice | Pixel IoU | Object Precision (IoU $\\ge 0.5$) | Object Recall (IoU $\\ge 0.5$) | Object F1 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
%s

---

## 3. Aggregate Performance Summary

| Metric | Mean Value across Dataset |
| :--- | :--- |
| **Pixel Dice Coefficient** | **%.4f** |
| **Pixel Intersection-over-Union (IoU)** | **%.4f** |
| **Object-Level Precision (IoU $\\ge 0.5$)** | **%.4f** |
| **Object-Level Recall (IoU $\\ge 0.5$)** | **%.4f** |
| **Object-Level F1 Score** | **%.4f** |
| **Cell Count Mean Relative Error** | **%.1f%%** |

---

## 4. Visual Evidence Artifacts
Predicted-vs-Ground-Truth overlay montages have been exported to:
`work/segmentation_benchmark_overlays/`
- **Green**: True Positives (Spatial agreement between prediction and GT)
- **Red**: False Negatives (GT nuclei unsegmented by watershed)
- **Blue**: False Positives (Over-segmented or spurious background regions)
", Sys.Date(), zero_gt_images,
   paste(apply(dt_benchmark, 1, function(r) {
     sprintf("| `%s` | %s | %s | %s | %.3f | %.3f | %.3f | %.3f | %.3f |",
             r["image_name"], r["n_gt_cells"], r["n_pred_cells"], if (is.finite(as.numeric(r["cell_count_rel_error"]))) sprintf("%.1f%%", as.numeric(r["cell_count_rel_error"])*100) else "NA",
             as.numeric(r["dice"]), as.numeric(r["iou"]), as.numeric(r["object_precision"]),
             as.numeric(r["object_recall"]), as.numeric(r["object_f1"]))
   }), collapse = "\n"),
   mean_dice, mean_iou, mean_prec, mean_rec, mean_f1, mean_count_err * 100)

writeLines(report_md, file.path(root, "SEGMENTATION_BENCHMARK_REPORT.md"))
cat("SEGMENTATION_BENCHMARK_REPORT.md and segmentation_benchmark.csv written successfully.\n")
