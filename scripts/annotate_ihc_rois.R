#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

parse_cli <- function(x) {
  out <- list()
  for (arg in x) {
    if (!grepl("^--[^=]+=", arg)) stop("Arguments must use --key=value: ", arg)
    pair <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    out[[pair[[1L]]]] <- paste(pair[-1L], collapse = "=")
  }
  out
}

cli <- parse_cli(commandArgs(trailingOnly = TRUE))
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this tool with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
source(file.path(script_dir, "path_utils.R"))
required <- c("manifest", "image-id", "roi", "compartment")
missing <- required[!required %in% names(cli)]
if (length(missing)) {
  stop("Required: --manifest=... --image-id=... --roi=... --compartment=stroma [--roi-id=stroma_1 --shape=rectangle --action=include --reviewer=Reviewer01 --local-lib=/path/Rlib]")
}
local_lib <- normalize_optional_dir(cli$`local-lib`)
if (!is.null(local_lib)) {
  .libPaths(c(local_lib, .libPaths()))
}

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

manifest_path <- normalize_path_portable(cli$manifest, must_work = TRUE)
manifest <- fread(manifest_path)
if (!"image_id" %in% names(manifest) || !"source_file" %in% names(manifest)) stop("Manifest requires image_id and source_file.")
image_id <- cli$`image-id`
target_image_id <- as.character(image_id)
row <- manifest[as.character(get("image_id")) == target_image_id]
if (nrow(row) != 1L) stop("image_id must resolve to exactly one row: ", image_id)
source_file <- resolve_path_portable(as.character(row$source_file[[1]]), dirname(manifest_path), must_work = TRUE)
img <- suppressWarnings(readImage(source_file))
d <- dim(img)

roi_path <- normalize_path_portable(cli$roi, must_work = FALSE)
roi_id <- if (!is.null(cli$`roi-id`)) cli$`roi-id` else paste0(cli$compartment, "_", format(Sys.time(), "%Y%m%d%H%M%S"))
target_roi_id <- as.character(roi_id)
shape <- if (!is.null(cli$shape)) tolower(cli$shape) else "rectangle"
action <- if (!is.null(cli$action)) tolower(cli$action) else "include"
reviewer <- if (!is.null(cli$reviewer)) trimws(cli$reviewer) else NA_character_
compartment_value <- tolower(trimws(as.character(cli$compartment)))
if (!shape %in% c("rectangle", "polygon")) stop("--shape must be rectangle or polygon")
if (!action %in% c("include", "exclude")) stop("--action must be include or exclude")
if (compartment_value %in% c("tumor", "stroma", "interface") && (is.na(reviewer) || reviewer == "")) {
  stop("Tumor/stroma/interface annotation requires --reviewer=<reviewer ID>.")
}
annotation_palette <- c(
  global = "#2563EB", nucleus = "#DC2626", cytoplasm = "#16A34A",
  extracellular = "#F97316", exclude = "#6B7280", tumor = "#7C3AED",
  stroma = "#0891B2", interface = "#CA8A04", custom = "#DB2777"
)
annotation_colour <- if (action == "exclude") annotation_palette[["exclude"]] else if (compartment_value %in% names(annotation_palette)) annotation_palette[[compartment_value]] else annotation_palette[["custom"]]

if (capabilities("X11")) {
  grDevices::X11(width = 13, height = 8)
} else if (capabilities("aqua")) {
  grDevices::quartz(width = 13, height = 8)
} else if (.Platform$OS.type == "windows") {
  grDevices::windows(width = 13, height = 8)
} else {
  stop("No interactive R graphics device is available. Use a desktop R session or create the ROI CSV externally; the main pipeline will still generate proof images.")
}

graphics::par(mar = c(1, 1, 3, 1), xaxs = "i", yaxs = "i")
graphics::plot(NA, xlim = c(1, d[[1]]), ylim = c(d[[2]], 1), asp = 1, axes = FALSE, xlab = "", ylab = "")
graphics::rasterImage(as.raster(img), 1, d[[2]], d[[1]], 1, interpolate = TRUE)
if (shape == "rectangle") {
  graphics::title(main = paste0(image_id, ": click two opposite corners for ", roi_id))
  points <- graphics::locator(n = 2, type = "p", pch = 3, col = annotation_colour, lwd = 2)
  if (is.null(points) || length(points$x) != 2L) stop("Two corners are required; nothing saved.")
  x1 <- min(points$x); x2 <- max(points$x); y1 <- min(points$y); y2 <- max(points$y)
  vertices <- data.table(
    vertex_order = 1:4,
    x = c(x1, x2, x2, x1),
    y = c(y1, y1, y2, y2)
  )
} else {
  graphics::title(main = paste0(image_id, ": click polygon vertices; press Esc/right-click to finish ", roi_id))
  points <- graphics::locator(type = "l", col = annotation_colour, lwd = 2)
  if (is.null(points) || length(points$x) < 3L) stop("At least three vertices are required; nothing saved.")
  vertices <- data.table(vertex_order = seq_along(points$x), x = points$x, y = points$y)
}

graphics::polygon(vertices$x, vertices$y, border = annotation_colour, lwd = 3)
graphics::text(min(vertices$x), min(vertices$y), labels = paste0(roi_id, " · ", compartment_value), pos = 4, col = annotation_colour, font = 2)

new_vertices <- vertices[, .(
  image_id = image_id,
  roi_id = roi_id,
  compartment = compartment_value,
  action = action,
  selection_source = "manual",
  selection_method = shape,
  reviewer = reviewer,
  annotation_status = "selected",
  vertex_order,
  x,
  y
)]
existing <- if (file.exists(roi_path)) fread(roi_path) else data.table()
if (nrow(existing)) existing <- existing[!(as.character(get("image_id")) == target_image_id & as.character(get("roi_id")) == target_roi_id)]
dir.create(dirname(roi_path), recursive = TRUE, showWarnings = FALSE)
fwrite(rbindlist(list(existing, new_vertices), fill = TRUE), roi_path)

proof_dir <- if (!is.null(cli$`proof-dir`)) cli$`proof-dir` else file.path(dirname(roi_path), "roi_selection_proof")
dir.create(proof_dir, recursive = TRUE, showWarnings = FALSE)
proof_path <- file.path(proof_dir, paste0(image_id, "_", roi_id, "_selection_proof.png"))
grDevices::png(proof_path, width = 1800, height = 1100, res = 160, bg = "white")
graphics::par(mar = c(1, 1, 3, 1), xaxs = "i", yaxs = "i")
graphics::plot(NA, xlim = c(1, d[[1]]), ylim = c(d[[2]], 1), asp = 1, axes = FALSE, xlab = "", ylab = "")
graphics::rasterImage(as.raster(img), 1, d[[2]], d[[1]], 1, interpolate = TRUE)
graphics::polygon(vertices$x, vertices$y, border = annotation_colour, lwd = 5)
graphics::text(min(vertices$x), min(vertices$y), labels = paste0(roi_id, " · ", compartment_value, " · ", action), pos = 4, col = annotation_colour, font = 2, cex = 1.1)
graphics::title(main = paste0(image_id, " — ROI selection proof"))
grDevices::dev.off()

cat("Saved ROI vertices:", roi_path, "\n")
cat("Saved visual proof:", proof_path, "\n")
