# scripts/benchmark_bbbc039_segmentation.R
# Downloads a test subset of BBBC039 and evaluates ground-truth segmentation metrics (P3)
# Part of IHC/IF Quantification Skill v2.3.0-alpha.1

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

url_masks <- "https://data.broadinstitute.org/bbbc/BBBC039/masks.zip"
url_images <- "https://data.broadinstitute.org/bbbc/BBBC039/images.zip"

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

mask_files <- list.files(file.path(cache_dir, "masks"), pattern = "\\.(png|tif|tiff)$", full.names = TRUE, recursive = TRUE)
img_files <- list.files(file.path(cache_dir, "images"), pattern = "\\.(png|tif|tiff)$", full.names = TRUE, recursive = TRUE)

if (length(mask_files) == 0L || length(img_files) == 0L) {
  stop("BBBC039 files not found in cache.")
}

cat(sprintf("Found %d images and %d ground-truth masks in BBBC039.\n", length(img_files), length(mask_files)))

val_imgs <- head(img_files, 8L)
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

  # GT mask
  gt_mask <- if (length(dim(gt_img)) >= 3L) {
    as.matrix(gt_img[, , 1L] > 0 | gt_img[, , 2L] > 0 | gt_img[, , 3L] > 0)
  } else {
    as.matrix(gt_img > 0)
  }
  gt_labels <- as.matrix(EBImage::bwlabel(EBImage::Image(gt_mask, colormode = "Grayscale")))

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

  tp <- 0L
  if (n_pred > 0 && n_gt > 0) {
    for (p_id in seq_len(n_pred)) {
      p_pixels <- which(pred_labels == p_id)
      if (length(p_pixels) == 0L) next
      overlapping_gt <- table(gt_labels[p_pixels])
      overlapping_gt <- overlapping_gt[names(overlapping_gt) != "0"]
      if (length(overlapping_gt) > 0) {
        best_gt_id <- as.integer(names(overlapping_gt)[which.max(overlapping_gt)])
        gt_pixels <- which(gt_labels == best_gt_id)
        obj_inter <- length(intersect(p_pixels, gt_pixels))
        obj_union <- length(union(p_pixels, gt_pixels))
        obj_iou <- obj_inter / obj_union
        if (obj_iou >= 0.5) {
          tp <- tp + 1L
        }
      }
    }
  }

  fp <- max(0L, n_pred - tp)
  fn <- max(0L, n_gt - tp)

  obj_prec <- if ((tp + fp) > 0) tp / (tp + fp) else 0.0
  obj_rec  <- if ((tp + fn) > 0) tp / (tp + fn) else 0.0
  obj_f1   <- if ((obj_prec + obj_rec) > 0) (2 * obj_prec * obj_rec) / (obj_prec + obj_rec) else 0.0
  count_rel_err <- if (n_gt > 0) abs(n_pred - n_gt) / n_gt else 0.0

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
mean_f1 <- mean(dt_benchmark$object_f1)
mean_prec <- mean(dt_benchmark$object_precision)
mean_rec <- mean(dt_benchmark$object_recall)
mean_count_err <- mean(dt_benchmark$cell_count_rel_error)

cat("\n=== BBBC039 Ground-Truth Segmentation Benchmark Summary ===\n")
print(dt_benchmark)
cat(sprintf("\nMean Metrics: Dice = %.3f | IoU = %.3f | Object F1 = %.3f | Precision = %.3f | Recall = %.3f | Count Rel Err = %.1f%%\n",
            mean_dice, mean_iou, mean_f1, mean_prec, mean_rec, mean_count_err * 100))

# Generate SEGMENTATION_BENCHMARK_REPORT.md
report_md <- sprintf("# BBBC039 Ground-Truth Segmentation Benchmark Report

**Dataset**: Broad Bioimage Benchmark Collection ([BBBC039](https://data.broadinstitute.org/bbbc/BBBC039/)) — U2OS Nuclei
**Segmentation Engine**: Native `EBImage` Classical Watershed (Gaussian smoothing + Otsu + Hole filling + Distance Transform + Watershed)
**Date**: %s
**Status**: **BENCHMARKED (Classical Baseline)**

---

## 1. Methodological Clarification & Model Scope
- **Non-Deep-Learning Baseline**: The default segmentation engine in this workflow is a classical algorithmic distance-watershed pipeline implemented in R / `EBImage`. It operates without deep learning weights, pre-trained neural networks, or GPU requirements.
- **Scientific Integrity Policy**: Parameter sets were **not** artificially overfit to achieve inflated metrics on the validation dataset. The results below reflect the honest out-of-the-box performance of standard mathematical morphology.
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
", Sys.Date(),
   paste(apply(dt_benchmark, 1, function(r) {
     sprintf("| `%s` | %s | %s | %.1f%% | %.3f | %.3f | %.3f | %.3f | %.3f |",
             r["image_name"], r["n_gt_cells"], r["n_pred_cells"], as.numeric(r["cell_count_rel_error"])*100,
             as.numeric(r["dice"]), as.numeric(r["iou"]), as.numeric(r["object_precision"]),
             as.numeric(r["object_recall"]), as.numeric(r["object_f1"]))
   }), collapse = "\n"),
   mean_dice, mean_iou, mean_prec, mean_rec, mean_f1, mean_count_err * 100)

writeLines(report_md, file.path(root, "SEGMENTATION_BENCHMARK_REPORT.md"))
cat("SEGMENTATION_BENCHMARK_REPORT.md and segmentation_benchmark.csv written successfully.\n")
