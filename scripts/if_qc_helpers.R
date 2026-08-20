# if_qc_helpers.R
# Standardization of 8-Panel IF QC Overviews, Pseudocolor Overlays, and QC Flag Auditing.
# Part of IHC/IF Quantification Skill v2.3.0-alpha.1

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
  library(ragg)
})

# Create multichannel composite RGB image
create_composite_rgb <- function(
  channel_list,
  channel_roles,
  colors = list(nucleus = "blue", target = "green", target2 = "red", structural_reference = "magenta")
) {
  # Get dimensions from first channel
  first_mat <- channel_list[[1L]]
  nr <- nrow(first_mat)
  nc <- ncol(first_mat)

  r_plane <- matrix(0, nrow = nr, ncol = nc)
  g_plane <- matrix(0, nrow = nr, ncol = nc)
  b_plane <- matrix(0, nrow = nr, ncol = nc)

  target_seen <- 0L
  for (i in seq_along(channel_list)) {
    ch_name <- names(channel_list)[i]
    role <- if (ch_name %in% names(channel_roles)) channel_roles[[ch_name]] else "target"

    mat <- channel_list[[ch_name]]
    # Stretch display
    disp <- create_display_image(mat)

    if (role == "nucleus") {
      # Blue
      b_plane <- pmax(b_plane, disp)
    } else if (role == "target") {
      # Green for the first target and red for a second target.  Use the role
      # count rather than the manifest row position; channel indices need not
      # be ordered by biological role.
      target_seen <- target_seen + 1L
      if (target_seen == 1L) {
        g_plane <- pmax(g_plane, disp)
      } else {
        r_plane <- pmax(r_plane, disp)
      }
    } else if (role == "structural_reference" || role == "cytoplasm_reference") {
      # Red / Magenta
      r_plane <- pmax(r_plane, disp)
      b_plane <- pmax(b_plane, disp * 0.5)
    } else {
      # White/gray
      r_plane <- pmax(r_plane, disp * 0.5)
      g_plane <- pmax(g_plane, disp * 0.5)
      b_plane <- pmax(b_plane, disp * 0.5)
    }
  }

  rgb_arr <- array(0, dim = c(nr, nc, 3L))
  rgb_arr[, , 1L] <- pmin(r_plane, 1.0)
  rgb_arr[, , 2L] <- pmin(g_plane, 1.0)
  rgb_arr[, , 3L] <- pmin(b_plane, 1.0)

  EBImage::Image(rgb_arr, colormode = "Color")
}

# Generate Standard 8-Panel IF QC Overview
render_if_8panel_qc <- function(
  out_path,
  nuc_mat,
  target_mat,
  target_corr_mat,
  seg_res,
  pos_mask,
  composite_rgb,
  image_id,
  qc_flags_str,
  analysis_mask = NULL
) {
  nr <- nrow(nuc_mat)
  nc <- ncol(nuc_mat)
  if (is.null(analysis_mask)) {
    analysis_mask <- matrix(TRUE, nrow = nr, ncol = nc)
  }
  if (!all(dim(analysis_mask) == c(nr, nc))) {
    stop("IF QC analysis_mask dimensions do not match the image.")
  }
  has_excluded_roi <- any(!analysis_mask)

  # Prepare panel displays
  pA <- composite_rgb

  pB_disp <- create_display_image(nuc_mat)
  pB <- EBImage::Image(array(rep(pB_disp, 3), dim = c(nr, nc, 3)), colormode = "Color")
  pB[, , 1] <- 0
  pB[, , 2] <- 0 # blue tint for DAPI

  pC_disp <- create_display_image(target_mat)
  pC <- EBImage::Image(array(rep(pC_disp, 3), dim = c(nr, nc, 3)), colormode = "Color")
  pC[, , 1] <- 0
  pC[, , 3] <- 0 # green tint for target

  pD_disp <- create_display_image(target_corr_mat)
  pD <- EBImage::Image(array(rep(pD_disp, 3), dim = c(nr, nc, 3)), colormode = "Color")
  pD[, , 1] <- 0
  pD[, , 3] <- 0

  # Panel E: Nuclear segmentation overlay
  nuc_outline <- EBImage::bwlabel(seg_res$nuc_labels > 0)
  pE <- EBImage::paintObjects(nuc_outline, pB, col = c("#FF00FF", "#FF00FF"), opac = c(1, 0.2))

  # Panel F: Cell propagation overlay
  cell_outline <- EBImage::bwlabel(seg_res$cell_labels > 0)
  pF <- EBImage::paintObjects(cell_outline, pA, col = c("#FFFF00", "#FFFF00"), opac = c(0.8, 0.1))

  # Panel G: Positive signal mask
  pG_arr <- array(0, dim = c(nr, nc, 3))
  pG_arr[, , 2] <- ifelse(pos_mask, 1.0, 0.0)
  pG <- EBImage::Image(pG_arr, colormode = "Color")

  # Panel H: Four-compartment overlay
  # Blue = Nucleus, Yellow = Cytoplasm, Dark Gray = Extracellular
  pH_arr <- array(0, dim = c(nr, nc, 3))
  pH_arr[, , 3] <- ifelse(seg_res$nuc_mask, 1.0, 0.0) # Blue nucleus
  pH_arr[, , 1] <- ifelse(seg_res$cyto_mask, 0.9, ifelse(seg_res$extracellular_mask, 0.2, 0.0))
  pH_arr[, , 2] <- ifelse(seg_res$cyto_mask, 0.9, ifelse(seg_res$extracellular_mask, 0.2, 0.0))
  pH <- EBImage::Image(pH_arr, colormode = "Color")

  # Render through base rasterImage rather than EBImage::display().  The latter
  # adds an interactive "Press 'r' ..." hint to static device output, which
  # contaminates QC figures and can look like a biological annotation.
  panel_raster <- function(img, mask = analysis_mask) {
    arr <- as.array(img)
    if (length(dim(arr)) == 2L) {
      vals <- pmin(pmax(arr, 0), 1)
      raster <- grDevices::gray(vals)
      dim(raster) <- dim(vals)
      if (has_excluded_roi) raster[!mask] <- "#666666"
      return(raster)
    }
    if (length(dim(arr)) == 3L && dim(arr)[3L] >= 3L) {
      rgb_arr <- pmin(pmax(arr[, , 1:3, drop = FALSE], 0), 1)
      raster <- grDevices::rgb(
        rgb_arr[, , 1L], rgb_arr[, , 2L], rgb_arr[, , 3L],
        maxColorValue = 1
      )
      dim(raster) <- dim(rgb_arr)[1:2]
      if (has_excluded_roi) raster[!mask] <- "#666666"
      return(raster)
    }
    stop("QC panel image must be a grayscale matrix or RGB array.")
  }

  draw_panel <- function(img, title, subtitle = NULL, mask = analysis_mask) {
    graphics::plot.new()
    graphics::plot.window(
      xlim = c(0, 1), ylim = c(0, 1), asp = 1,
      xaxs = "i", yaxs = "i"
    )
    graphics::rasterImage(
      panel_raster(img, mask), 0, 0, 1, 1,
      interpolate = FALSE
    )
    graphics::title(main = title, col.main = "white", cex.main = 0.82, line = 0.35)
    if (!is.null(subtitle) && nzchar(subtitle)) {
      subtitle_lines <- strwrap(subtitle, width = 34, simplify = TRUE)
      graphics::text(
        x = 0.02, y = 0.98,
        labels = paste(subtitle_lines, collapse = "\n"),
        adj = c(0, 1), col = "white", cex = 0.42
      )
    }
  }

  # Render via ragg with crisp raster panels and non-clipped titles.
  ragg::agg_png(out_path, width = 2400, height = 1200, res = 200)
  graphics::par(
    mfrow = c(2, 4), mar = c(0.3, 0.3, 2.7, 0.3),
    bg = "#1E1E1E", col.main = "white", fg = "white"
  )

  draw_panel(pA, "Panel A: Merged Composite")
  draw_panel(pB, "Panel B: Nuclear (DAPI)")
  draw_panel(pC, "Panel C: Raw Target")
  draw_panel(pD, "Panel D: Background-Corrected")
  draw_panel(pE, "Panel E: Nuclei Segmentation")
  draw_panel(pF, "Panel F: Cell/Cyto Segmentation")
  draw_panel(pG, "Panel G: Positive Mask")
  draw_panel(
    pH,
    "Panel H: 4-Compartments",
    paste0(
      if (has_excluded_roi) "gray = excluded ROI | " else "",
      "QC: ", qc_flags_str
    ),
    mask = analysis_mask
  )

  grDevices::dev.off()

  return(out_path)
}
