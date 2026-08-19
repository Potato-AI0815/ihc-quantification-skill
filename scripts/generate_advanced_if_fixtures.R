suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

# Determine root directory
script_arg_adv <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
root_adv <- if (length(script_arg_adv) == 1L) {
  dirname(dirname(normalizePath(path.expand(sub("^--file=", "", script_arg_adv[[1L]])), mustWork = TRUE)))
} else {
  getwd()
}
source(file.path(root_adv, "scripts", "generate_synthetic_if_fixtures.R"))

set.seed(42)

# ==============================================================================
# 1. Colocalization Fixture (High vs Mutually Exclusive Low)
# ==============================================================================
dir_coloc <- file.path(root_adv, "tests", "synthetic_coloc_fixture")
dir.create(file.path(dir_coloc, "images"), recursive = TRUE, showWarnings = FALSE)

img_high <- create_synthetic_cell_scene(n_cells = 20, img_size = 256, target_a_nuclear_level = 0.8, target_a_cyto_level = 0.8, target_b_mode = "coloc_high")
img_low <- create_synthetic_cell_scene(n_cells = 20, img_size = 256, target_a_nuclear_level = 0.8, target_a_cyto_level = 0.8, target_b_mode = "coloc_low")

EBImage::writeImage(img_high, file.path(dir_coloc, "images", "coloc_high.tif"))
EBImage::writeImage(img_low, file.path(dir_coloc, "images", "coloc_low.tif"))

coloc_manifest <- data.table(
  image_id = c("COLOC_HIGH", "COLOC_HIGH", "COLOC_HIGH", "COLOC_LOW", "COLOC_LOW", "COLOC_LOW"),
  biological_unit_id = c("U1", "U1", "U1", "U2", "U2", "U2"),
  condition = c("high", "high", "high", "low", "low", "low"),
  modality = "immunofluorescence",
  marker = c("DAPI", "MarkerA", "MarkerB", "DAPI", "MarkerA", "MarkerB"),
  channel_name = c("DAPI", "TargetA", "TargetB", "DAPI", "TargetA", "TargetB"),
  channel_index = c(1L, 2L, 3L, 1L, 2L, 3L),
  channel_role = c("nucleus", "target", "target", "nucleus", "target", "target"),
  pixel_size_um = 0.5,
  z_spacing_um = NA_real_,
  timepoint = "T0",
  batch = "BATCH_COLOC",
  replicate = 1L,
  file_path = c(
    "images/coloc_high.tif", "images/coloc_high.tif", "images/coloc_high.tif",
    "images/coloc_low.tif", "images/coloc_low.tif", "images/coloc_low.tif"
  )
)
fwrite(coloc_manifest, file.path(dir_coloc, "manifest.csv"))

# ==============================================================================
# 2. Puncta Fixture with Explicit Ground-Truth Registry
# ==============================================================================
dir_puncta <- file.path(root_adv, "tests", "synthetic_puncta_fixture")
dir.create(file.path(dir_puncta, "images"), recursive = TRUE, showWarnings = FALSE)

create_puncta_scene_with_gt <- function(n_cells = 9, img_size = 256, n_puncta_per_cell = 5, seed = 101) {
  set.seed(seed)
  dapi_mat <- matrix(stats::runif(img_size * img_size, 0.005, 0.015), nrow = img_size, ncol = img_size)
  cyto_mat <- matrix(stats::runif(img_size * img_size, 0.005, 0.015), nrow = img_size, ncol = img_size)
  puncta_mat <- matrix(stats::runif(img_size * img_size, 0.005, 0.015), nrow = img_size, ncol = img_size)

  grid_step <- floor(img_size / (sqrt(n_cells) + 1))
  cell_coords <- expand.grid(
    x = seq(grid_step, img_size - grid_step, length.out = sqrt(n_cells)),
    y = seq(grid_step, img_size - grid_step, length.out = sqrt(n_cells))
  )

  coords_x <- matrix(rep(1:img_size, img_size), nrow = img_size, ncol = img_size)
  coords_y <- matrix(rep(1:img_size, each = img_size), nrow = img_size, ncol = img_size)

  gt_puncta_list <- list()

  for (i in seq_len(nrow(cell_coords))) {
    cx <- round(cell_coords$x[i])
    cy <- round(cell_coords$y[i])
    r_nuc <- 8.0
    r_cell <- 16.0

    dist_sq <- (coords_x - cx)^2 + (coords_y - cy)^2
    nuc_idx <- which(dist_sq <= r_nuc^2)
    cyto_idx <- which(dist_sq > r_nuc^2 & dist_sq <= r_cell^2)

    dapi_mat[nuc_idx] <- pmax(dapi_mat[nuc_idx], 0.8 * exp(-dist_sq[nuc_idx] / (2 * (r_nuc * 0.6)^2)))
    cyto_mat[cyto_idx] <- pmax(cyto_mat[cyto_idx], 0.4)

    # Place non-overlapping sharp puncta
    if (n_puncta_per_cell > 0) {
      placed <- 0
      attempts <- 0
      cell_puncta_coords <- list()
      while (placed < n_puncta_per_cell && attempts < 100) {
        attempts <- attempts + 1
        angle <- stats::runif(1, 0, 2 * pi)
        radius <- stats::runif(1, 2, r_cell - 3)
        px <- round(cx + radius * cos(angle))
        py <- round(cy + radius * sin(angle))

        # Check distance to already placed puncta in this cell
        too_close <- FALSE
        if (length(cell_puncta_coords) > 0) {
          for (existing in cell_puncta_coords) {
            if ((px - existing$x)^2 + (py - existing$y)^2 < 4^2) {
              too_close <- TRUE
              break
            }
          }
        }
        if (!too_close && px >= 3 && px <= (img_size - 2) && py >= 3 && py <= (img_size - 2)) {
          placed <- placed + 1
          cell_puncta_coords[[placed]] <- list(x = px, y = py)
          # Add Gaussian peak for punctum
          for (dx in -1:1) {
            for (dy in -1:1) {
              w <- exp(-(dx^2 + dy^2) / 1.0)
              puncta_mat[px + dx, py + dy] <- puncta_mat[px + dx, py + dy] + 0.85 * w
            }
          }
          gt_puncta_list[[length(gt_puncta_list) + 1L]] <- data.table(
            cell_id = i,
            puncta_id = length(gt_puncta_list) + 1L,
            x = px,
            y = py
          )
        }
      }
    }
  }

  arr <- array(0, dim = c(img_size, img_size, 3L))
  arr[, , 1L] <- pmin(pmax(dapi_mat, 0), 1.0)
  arr[, , 2L] <- pmin(pmax(cyto_mat, 0), 1.0)
  arr[, , 3L] <- pmin(pmax(puncta_mat, 0), 1.0)

  list(
    image = EBImage::Image(arr, colormode = "Color"),
    gt = rbindlist(gt_puncta_list)
  )
}

res_p5 <- create_puncta_scene_with_gt(n_cells = 9, img_size = 256, n_puncta_per_cell = 5, seed = 101)
res_p15 <- create_puncta_scene_with_gt(n_cells = 9, img_size = 256, n_puncta_per_cell = 15, seed = 202)

EBImage::writeImage(res_p5$image, file.path(dir_puncta, "images", "puncta_5.tif"))
EBImage::writeImage(res_p15$image, file.path(dir_puncta, "images", "puncta_15.tif"))

res_p5$gt[, image_id := "PUNCTA_5"]
res_p15$gt[, image_id := "PUNCTA_15"]
puncta_gt_all <- rbind(res_p5$gt, res_p15$gt)
fwrite(puncta_gt_all, file.path(dir_puncta, "puncta_ground_truth.csv"))

puncta_manifest <- data.table(
  image_id = rep(c("PUNCTA_5", "PUNCTA_15"), each = 3),
  biological_unit_id = rep(c("U1", "U2"), each = 3),
  condition = rep(c("dose_low", "dose_high"), each = 3),
  modality = "immunofluorescence",
  marker = rep(c("DAPI", "Tubulin", "GammaH2AX"), 2),
  channel_name = rep(c("DAPI", "Alexa568_cyto", "Alexa488_foci"), 2),
  channel_index = rep(1:3, 2),
  channel_role = rep(c("nucleus", "structural_reference", "target"), 2),
  pixel_size_um = 0.5,
  z_spacing_um = NA_real_,
  timepoint = "T0",
  batch = "BATCH_PUNCTA",
  replicate = 1L,
  file_path = rep(c("images/puncta_5.tif", "images/puncta_15.tif"), each = 3)
)
fwrite(puncta_manifest, file.path(dir_puncta, "manifest.csv"))

cat("Generated Colocalization and Puncta fixtures successfully.\n")
