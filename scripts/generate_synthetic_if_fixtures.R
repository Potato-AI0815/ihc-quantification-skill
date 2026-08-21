# generate_synthetic_if_fixtures.R
# Deterministic Generator for Synthetic IF Fixtures (Standard IF, Colocalization, Puncta).
# Part of IHC/IF Quantification Skill v2.3.0-alpha.2

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

set.seed(42)

# Helper to create simulated cell image
create_synthetic_cell_scene <- function(
  n_cells = 30,
  img_size = 256,
  target_a_nuclear_level = 0.2,
  target_a_cyto_level = 0.8,
  target_b_mode = "coloc_high", # "coloc_high", "coloc_low", "puncta"
  n_puncta_per_cell = 0
) {
  # 1. Channel 1: DAPI (Nuclear)
  dapi_mat <- matrix(0.01 + stats::runif(img_size * img_size, 0, 0.02), nrow = img_size, ncol = img_size)
  # 2. Channel 2: Target A
  target_a_mat <- matrix(0.01 + stats::runif(img_size * img_size, 0, 0.02), nrow = img_size, ncol = img_size)
  # 3. Channel 3: Target B
  target_b_mat <- matrix(0.01 + stats::runif(img_size * img_size, 0, 0.02), nrow = img_size, ncol = img_size)

  # Grid of cells
  grid_step <- floor(img_size / (sqrt(n_cells) + 1))
  cell_coords <- expand.grid(
    x = seq(grid_step, img_size - grid_step, by = grid_step),
    y = seq(grid_step, img_size - grid_step, by = grid_step)
  )
  cell_coords <- cell_coords[1:n_cells, ]

  # Distance coordinates
  coords_x <- matrix(rep(1:img_size, img_size), nrow = img_size, ncol = img_size)
  coords_y <- matrix(rep(1:img_size, each = img_size), nrow = img_size, ncol = img_size)

  for (i in seq_len(nrow(cell_coords))) {
    cx <- cell_coords$x[i] + stats::runif(1, -3, 3)
    cy <- cell_coords$y[i] + stats::runif(1, -3, 3)

    r_nuc <- 7.0 + stats::runif(1, -0.5, 0.5)
    r_cell <- 15.0 + stats::runif(1, -1.0, 1.0)

    dist_sq <- (coords_x - cx)^2 + (coords_y - cy)^2

    # Nuclear mask & DAPI intensity
    nuc_idx <- which(dist_sq <= r_nuc^2)
    cyto_idx <- which(dist_sq > r_nuc^2 & dist_sq <= r_cell^2)

    # DAPI signal (Gaussian profile)
    dapi_mat[nuc_idx] <- pmax(dapi_mat[nuc_idx], 0.7 * exp(-dist_sq[nuc_idx] / (2 * (r_nuc * 0.6)^2)))

    # Target A & B signal depending on mode
    if (target_b_mode == "coloc_high") {
      target_a_mat[nuc_idx] <- target_a_mat[nuc_idx] + target_a_nuclear_level * (1 + stats::rnorm(length(nuc_idx), 0, 0.05))
      target_a_mat[cyto_idx] <- target_a_mat[cyto_idx] + target_a_cyto_level * (1 + stats::rnorm(length(cyto_idx), 0, 0.05))
      target_b_mat[nuc_idx] <- target_b_mat[nuc_idx] + (target_a_nuclear_level * 0.9 + 0.1) * (1 + stats::rnorm(length(nuc_idx), 0, 0.05))
      target_b_mat[cyto_idx] <- target_b_mat[cyto_idx] + (target_a_cyto_level * 0.9 + 0.1) * (1 + stats::rnorm(length(cyto_idx), 0, 0.05))
    } else if (target_b_mode == "coloc_low") {
      # Mutually exclusive distribution (Odd cells express A, Even cells express B)
      if (i %% 2 == 1) {
        target_a_mat[nuc_idx] <- target_a_mat[nuc_idx] + target_a_nuclear_level * (1 + stats::rnorm(length(nuc_idx), 0, 0.05))
        target_a_mat[cyto_idx] <- target_a_mat[cyto_idx] + target_a_cyto_level * (1 + stats::rnorm(length(cyto_idx), 0, 0.05))
      } else {
        target_b_mat[nuc_idx] <- target_b_mat[nuc_idx] + target_a_nuclear_level * (1 + stats::rnorm(length(nuc_idx), 0, 0.05))
        target_b_mat[cyto_idx] <- target_b_mat[cyto_idx] + target_a_cyto_level * (1 + stats::rnorm(length(cyto_idx), 0, 0.05))
      }
    } else {
      target_a_mat[nuc_idx] <- target_a_mat[nuc_idx] + target_a_nuclear_level * (1 + stats::rnorm(length(nuc_idx), 0, 0.05))
      target_a_mat[cyto_idx] <- target_a_mat[cyto_idx] + target_a_cyto_level * (1 + stats::rnorm(length(cyto_idx), 0, 0.05))
    }

    # Puncta insertion
    if (n_puncta_per_cell > 0) {
      for (p in seq_len(n_puncta_per_cell)) {
        angle <- stats::runif(1, 0, 2 * pi)
        radius <- stats::runif(1, 1, max(1, r_cell - 2))
        px <- round(cx + radius * cos(angle))
        py <- round(cy + radius * sin(angle))
        if (!is.na(px) && !is.na(py) && length(px) == 1L && length(py) == 1L &&
            px >= 2 && px <= (img_size - 1) && py >= 2 && py <= (img_size - 1)) {
          # Sharp Gaussian puncta of 3x3
          target_b_mat[(px - 1):(px + 1), (py - 1):(py + 1)] <- target_b_mat[(px - 1):(px + 1), (py - 1):(py + 1)] + 0.8
        }
      }
    }
  }

  # Clamp values to [0, 1]
  dapi_mat <- pmin(pmax(dapi_mat, 0), 1.0)
  target_a_mat <- pmin(pmax(target_a_mat, 0), 1.0)
  target_b_mat <- pmin(pmax(target_b_mat, 0), 1.0)

  # Combine into 3-channel image (dim: img_size x img_size x 3)
  arr <- array(0, dim = c(img_size, img_size, 3L))
  arr[, , 1L] <- dapi_mat
  arr[, , 2L] <- target_a_mat
  arr[, , 3L] <- target_b_mat

  EBImage::Image(arr, colormode = "Color")
}

# 1. Create Standard Synthetic IF Fixture
out_dir_main <- "tests/synthetic_if_fixture"
dir.create(file.path(out_dir_main, "images"), recursive = TRUE, showWarnings = FALSE)

# Generate 4 images: S01_CTRL, S01_TREAT, S02_CTRL, S02_TREAT
# Condition CTRL: higher cytoplasmic Target A (nuc = 0.2, cyto = 0.8)
# Condition TREAT: higher nuclear Target A (nuc = 0.8, cyto = 0.2)

imgs_spec <- list(
  list(id = "IF_S01_CTRL_F1", unit = "S01", cond = "control", nuc = 0.15, cyto = 0.85),
  list(id = "IF_S01_TREAT_F1", unit = "S01", cond = "treatment", nuc = 0.85, cyto = 0.20),
  list(id = "IF_S02_CTRL_F1", unit = "S02", cond = "control", nuc = 0.20, cyto = 0.80),
  list(id = "IF_S02_TREAT_F1", unit = "S02", cond = "treatment", nuc = 0.80, cyto = 0.25)
)

manifest_rows <- list()

for (spec in imgs_spec) {
  img_obj <- create_synthetic_cell_scene(
    n_cells = 25,
    img_size = 256,
    target_a_nuclear_level = spec$nuc,
    target_a_cyto_level = spec$cyto,
    target_b_mode = "coloc_high"
  )

  file_rel <- file.path("images", paste0(spec$id, ".tif"))
  EBImage::writeImage(img_obj, file.path(out_dir_main, file_rel))

  # Channel 1: DAPI
  manifest_rows[[length(manifest_rows) + 1L]] <- data.table(
    image_id = spec$id,
    biological_unit_id = spec$unit,
    condition = spec$cond,
    modality = "immunofluorescence",
    marker = "DAPI",
    channel_name = "DAPI",
    channel_index = 1L,
    channel_role = "nucleus",
    pixel_size_um = 0.5,
    z_spacing_um = NA_real_,
    timepoint = "T0",
    batch = "BATCH_1",
    replicate = 1L,
    file_path = file_rel
  )

  # Channel 2: SPATS2
  manifest_rows[[length(manifest_rows) + 1L]] <- data.table(
    image_id = spec$id,
    biological_unit_id = spec$unit,
    condition = spec$cond,
    modality = "immunofluorescence",
    marker = "SPATS2",
    channel_name = "Alexa488_SPATS2",
    channel_index = 2L,
    channel_role = "target",
    pixel_size_um = 0.5,
    z_spacing_um = NA_real_,
    timepoint = "T0",
    batch = "BATCH_1",
    replicate = 1L,
    file_path = file_rel
  )

  # Channel 3: Tubulin
  manifest_rows[[length(manifest_rows) + 1L]] <- data.table(
    image_id = spec$id,
    biological_unit_id = spec$unit,
    condition = spec$cond,
    modality = "immunofluorescence",
    marker = "Tubulin",
    channel_name = "Alexa568_Tubulin",
    channel_index = 3L,
    channel_role = "structural_reference",
    pixel_size_um = 0.5,
    z_spacing_um = NA_real_,
    timepoint = "T0",
    batch = "BATCH_1",
    replicate = 1L,
    file_path = file_rel
  )
}

manifest_dt <- rbindlist(manifest_rows)
fwrite(manifest_dt, file.path(out_dir_main, "manifest.csv"))

cat("Generated synthetic IF fixture in:", out_dir_main, "\n")
