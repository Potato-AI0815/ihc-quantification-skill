# if_io_helpers.R
# Auditable Input/Output and Channel Parsing Helpers for Immunofluorescence (IF) Modality.
# Part of IHC/IF Quantification Skill v2.3.0-alpha.2

suppressPackageStartupMessages({
  library(EBImage)
  library(data.table)
})

# Channel roles contract
ALLOWED_CHANNEL_ROLES <- c(
  "nucleus",
  "target",
  "cytoplasm_reference",
  "membrane_reference",
  "structural_reference",
  "background_reference",
  "other"
)

# ImageJ writes the axis contract into the TIFF ImageDescription tag.  EBImage
# exposes the pixel pages, but it does not reliably expose ImageJ's C/Z/T axes;
# guessing from the third array dimension can therefore turn a CxZ hyperstack
# into one channel or duplicate the same projection across roles.
read_imagej_description <- function(file_path, scan_bytes = 1024L * 1024L) {
  size <- as.numeric(file.info(file_path)$size)
  if (!is.finite(size) || size <= 0) return(NULL)
  read_n <- min(size, scan_bytes)
  con <- file(file_path, open = "rb")
  on.exit(close(con), add = TRUE)
  raw <- readBin(con, what = "raw", n = read_n)
  ascii <- as.integer(raw)
  ascii[ascii == 0L | ascii > 127L | (ascii < 32L & !ascii %in% c(9L, 10L, 13L))] <- 32L
  txt <- paste(rawToChar(as.raw(ascii), multiple = TRUE), collapse = "")
  marker <- regexpr("ImageJ=", txt, fixed = TRUE)[1L]
  if (marker < 1L && size > scan_bytes) {
    close(con)
    con <- file(file_path, open = "rb")
    raw <- readBin(con, what = "raw", n = size)
    ascii <- as.integer(raw)
    ascii[ascii == 0L | ascii > 127L | (ascii < 32L & !ascii %in% c(9L, 10L, 13L))] <- 32L
    txt <- paste(rawToChar(as.raw(ascii), multiple = TRUE), collapse = "")
    marker <- regexpr("ImageJ=", txt, fixed = TRUE)[1L]
  }
  if (marker < 1L) return(NULL)
  raw_int <- as.integer(raw)
  nul_after <- which(raw_int == 0L & seq_along(raw_int) > marker)[1L]
  text_end <- if (is.na(nul_after)) min(length(raw_int), marker + 8192L) else nul_after - 1L
  tail_txt <- paste(rawToChar(as.raw(raw_int[marker:text_end]), multiple = TRUE), collapse = "")
  lines <- strsplit(tail_txt, "\\r?\\n", perl = TRUE)[[1L]]
  lines <- lines[nzchar(lines)]
  kv <- strsplit(lines, "=", fixed = TRUE)
  out <- list()
  for (pair in kv) {
    if (length(pair) < 2L) next
    key <- tolower(trimws(pair[[1L]]))
    value <- trimws(paste(pair[-1L], collapse = "="))
    out[[key]] <- value
  }
  out
}

tiff_u16 <- function(raw, offset0, endian = "MM") {
  b <- as.integer(raw[(offset0 + 1L):(offset0 + 2L)])
  if (endian == "II") b[[1L]] + 256 * b[[2L]] else 256 * b[[1L]] + b[[2L]]
}

tiff_u32 <- function(raw, offset0, endian = "MM") {
  b <- as.double(as.integer(raw[(offset0 + 1L):(offset0 + 4L)]))
  if (endian == "II") {
    b[[1L]] + 256 * b[[2L]] + 65536 * b[[3L]] + 16777216 * b[[4L]]
  } else {
    16777216 * b[[1L]] + 65536 * b[[2L]] + 256 * b[[3L]] + b[[4L]]
  }
}

tiff_type_size <- function(type) {
  sizes <- c(`1` = 1L, `2` = 1L, `3` = 2L, `4` = 4L, `5` = 8L,
             `6` = 1L, `7` = 1L, `8` = 2L, `9` = 4L, `10` = 8L,
             `11` = 4L, `12` = 8L)
  value <- sizes[[as.character(type)]]
  if (is.null(value)) stop("Unsupported TIFF field type: ", type)
  value
}

tiff_tag_values <- function(raw, value_offset0, type, count, endian = "MM") {
  n_bytes <- tiff_type_size(type) * count
  data_offset0 <- if (n_bytes <= 4L) value_offset0 else tiff_u32(raw, value_offset0, endian)
  if (data_offset0 < 0 || data_offset0 + n_bytes > length(raw)) {
    stop("TIFF tag points outside the file.")
  }
  bytes <- raw[(data_offset0 + 1L):(data_offset0 + n_bytes)]
  if (type == 1L || type == 6L || type == 7L) return(as.integer(bytes))
  if (type == 2L) {
    chars <- as.integer(bytes)
    nul <- which(chars == 0L)[1L]
    if (!is.na(nul)) chars <- chars[seq_len(max(0L, nul - 1L))]
    return(if (length(chars)) rawToChar(as.raw(chars)) else "")
  }
  if (type == 3L) {
    starts <- seq.int(1L, by = 2L, length.out = count)
    return(vapply(starts, function(i) {
      bb <- bytes[i:(i + 1L)]
      if (endian == "II") as.integer(bb[[1L]]) + 256L * as.integer(bb[[2L]]) else
        256L * as.integer(bb[[1L]]) + as.integer(bb[[2L]])
    }, numeric(1L)))
  }
  if (type == 4L) {
    starts <- seq.int(1L, by = 4L, length.out = count)
    return(vapply(starts, function(i) {
      tiff_u32(bytes, i - 1L, endian)
    }, numeric(1L)))
  }
  if (type == 5L || type == 10L) {
    starts <- seq.int(1L, by = 8L, length.out = count)
    return(vapply(starts, function(i) {
      numerator <- tiff_u32(bytes, i - 1L, endian)
      denominator <- tiff_u32(bytes, i + 3L, endian)
      if (!is.finite(denominator) || denominator == 0) NA_real_ else numerator / denominator
    }, numeric(1L)))
  }
  stop("TIFF field type ", type, " is not supported by the built-in reader.")
}

parse_tiff_ifds <- function(file_path) {
  size <- as.numeric(file.info(file_path)$size)
  raw <- readBin(file_path, what = "raw", n = size)
  if (length(raw) < 8L) stop("TIFF file is shorter than its header.")
  endian <- rawToChar(raw[1:2])
  if (!endian %in% c("II", "MM")) stop("Unsupported TIFF byte order.")
  magic <- tiff_u16(raw, 2L, endian)
  if (magic != 42L) stop("Unsupported TIFF magic number: ", magic)
  ifd_offset <- tiff_u32(raw, 4L, endian)
  pages <- list()
  guard <- 0L
  while (ifd_offset > 0 && guard < 10000L) {
    guard <- guard + 1L
    n_entries <- tiff_u16(raw, ifd_offset, endian)
    entry_start <- ifd_offset + 2L
    tags <- list()
    for (i in seq_len(n_entries)) {
      pos <- entry_start + (i - 1L) * 12L
      tag <- tiff_u16(raw, pos, endian)
      type <- tiff_u16(raw, pos + 2L, endian)
      count <- tiff_u32(raw, pos + 4L, endian)
      tags[[as.character(tag)]] <- tiff_tag_values(raw, pos + 8L, type, count, endian)
    }
    next_pos <- entry_start + n_entries * 12L
    ifd_offset <- tiff_u32(raw, next_pos, endian)
    pages[[length(pages) + 1L]] <- tags
  }
  list(pages = pages, raw = raw, endian = endian)
}

decode_tiff_strip_bytes <- function(bytes, bits_per_sample, endian = "MM") {
  if (bits_per_sample == 8L) return(as.numeric(as.integer(bytes)))
  if (bits_per_sample == 16L) {
    starts <- seq.int(1L, by = 2L, length.out = floor(length(bytes) / 2L))
    return(vapply(starts, function(i) tiff_u16(bytes, i - 1L, endian), numeric(1L)))
  }
  if (bits_per_sample == 32L) {
    starts <- seq.int(1L, by = 4L, length.out = floor(length(bytes) / 4L))
    return(vapply(starts, function(i) tiff_u32(bytes, i - 1L, endian), numeric(1L)))
  }
  stop("Built-in TIFF reader supports 8-, 16-, and 32-bit unsigned samples only.")
}

read_uncompressed_tiff_pages <- function(file_path) {
  parsed <- parse_tiff_ifds(file_path)
  pages <- lapply(parsed$pages, function(tags) {
    get_tag <- function(id, default = NULL) {
      value <- tags[[as.character(id)]]
      if (is.null(value)) default else value
    }
    width <- as.integer(get_tag(256))
    height <- as.integer(get_tag(257))
    bits <- as.integer(get_tag(258, 8L)[1L])
    compression <- as.integer(get_tag(259, 1L)[1L])
    samples <- as.integer(get_tag(277, 1L)[1L])
    rows_per_strip <- as.integer(get_tag(278, height)[1L])
    strip_offsets <- as.numeric(get_tag(273))
    strip_counts <- as.numeric(get_tag(279))
    if (is.na(width) || is.na(height) || !length(strip_offsets) || !length(strip_counts)) {
      stop("TIFF page is missing width, height, or strip data.")
    }
    if (compression != 1L) stop("TIFF compression ", compression, " requires the optional tiff package.")
    if (samples != 1L) stop("RGB/multi-sample TIFF pages require an explicit channel mapping.")
    all_values <- numeric()
    for (i in seq_along(strip_offsets)) {
      start <- as.numeric(strip_offsets[[i]])
      count <- as.numeric(strip_counts[[min(i, length(strip_counts))]])
      bytes <- parsed$raw[(start + 1L):(start + count)]
      all_values <- c(all_values, decode_tiff_strip_bytes(bytes, bits, parsed$endian))
    }
    expected <- width * height
    if (length(all_values) < expected) stop("TIFF strip data are shorter than the declared image size.")
    all_values <- all_values[seq_len(expected)]
    max_possible <- 2^bits - 1
    # TIFF strips are stored row-by-row.  Keep the image convention used by
    # EBImage (rows = height, columns = width); matrix(..., byrow=TRUE)
    # prevents a silent transpose/rotation of non-square images.
    matrix(all_values / max_possible, nrow = height, ncol = width, byrow = TRUE)
  })
  bits <- vapply(parsed$pages, function(tags) as.integer((tags[["258"]] %||% 8L)[1L]), integer(1L))
  list(pages = pages, bits_per_sample = bits, parser = "built_in_uncompressed_tiff")
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# Rasterise reviewed IF include/exclude polygons without modifying the source
# image.  The same source-image pixel convention as the DAB ROI contract is
# used: x indexes rows and y indexes columns.  An include polygon restricts the
# analysis field; exclude polygons remove artifacts/annotations from it.
if_points_in_polygon <- function(x, y, polygon_x, polygon_y) {
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

if_polygon_to_mask <- function(nr, nc, polygon_x, polygon_y) {
  mask <- matrix(FALSE, nrow = nr, ncol = nc)
  if (length(polygon_x) < 3L) return(mask)
  xmin <- max(1L, floor(min(polygon_x, na.rm = TRUE)))
  xmax <- min(nr, ceiling(max(polygon_x, na.rm = TRUE)))
  ymin <- max(1L, floor(min(polygon_y, na.rm = TRUE)))
  ymax <- min(nc, ceiling(max(polygon_y, na.rm = TRUE)))
  if (xmin > xmax || ymin > ymax) return(mask)
  xs <- seq.int(xmin, xmax)
  for (yy in seq.int(ymin, ymax)) {
    inside <- if_points_in_polygon(xs, rep(yy, length(xs)), polygon_x, polygon_y)
    if (any(inside)) mask[xs[inside], yy] <- TRUE
  }
  mask
}

build_if_analysis_mask <- function(roi_dt, image_id, nr, nc) {
  all_mask <- matrix(TRUE, nrow = nr, ncol = nc)
  empty <- list(
    analysis_mask = all_mask,
    include_mask = matrix(FALSE, nrow = nr, ncol = nc),
    exclude_mask = matrix(FALSE, nrow = nr, ncol = nc),
    include_roi_ids = character(),
    exclude_roi_ids = character(),
    excluded_pixel_count = 0L,
    included_pixel_count = nr * nc,
    status = "NO_REVIEWED_ROI"
  )
  if (is.null(roi_dt) || !nrow(roi_dt)) return(empty)

  target_id <- as.character(image_id)[1L]
  roi <- as.data.table(roi_dt)
  required <- c("image_id", "roi_id", "vertex_order", "x", "y", "action")
  missing <- setdiff(required, names(roi))
  if (length(missing)) stop("IF ROI table missing required columns: ", paste(missing, collapse = ", "))
  if (!"annotation_status" %in% names(roi)) roi[, annotation_status := "selected"]
  roi[, `:=`(
    image_id = as.character(image_id), roi_id = as.character(roi_id),
    action = tolower(trimws(as.character(action))),
    annotation_status = tolower(trimws(as.character(annotation_status))),
    vertex_order = as.integer(vertex_order), x = as.numeric(x), y = as.numeric(y)
  )]
  allowed_status <- c("selected", "reviewed", "approved")
  bad_status <- roi[!annotation_status %in% allowed_status, unique(annotation_status)]
  if (length(bad_status)) stop("IF ROI annotation_status must be selected, reviewed, or approved: ", paste(bad_status, collapse = ", "))
  if (any(!roi$action %in% c("include", "exclude"))) stop("IF ROI action must be include or exclude.")
  roi <- roi[image_id == target_id & annotation_status %in% allowed_status]
  if (!nrow(roi)) return(empty)
  if (any(!is.finite(roi$x) | !is.finite(roi$y))) stop("IF ROI coordinates must be finite numeric values.")
  if (any(roi$x < 1 | roi$x > nr | roi$y < 1 | roi$y > nc)) stop("IF ROI coordinates fall outside the source image for image ", target_id, ".")

  include_mask <- matrix(FALSE, nrow = nr, ncol = nc)
  exclude_mask <- matrix(FALSE, nrow = nr, ncol = nc)
  ids <- unique(roi$roi_id)
  for (id in ids) {
    poly <- roi[roi_id == id][order(vertex_order)]
    if (nrow(poly) < 3L) stop("IF ROI has fewer than three vertices: ", id)
    mask <- if_polygon_to_mask(nr, nc, poly$x, poly$y)
    if (!any(mask)) stop("IF ROI has zero rasterized area: ", id)
    action <- unique(poly$action)
    if (length(action) != 1L) stop("IF ROI has inconsistent action metadata: ", id)
    if (action == "include") include_mask <- include_mask | mask else exclude_mask <- exclude_mask | mask
  }
  analysis_mask <- if (any(include_mask)) include_mask else all_mask
  analysis_mask <- analysis_mask & !exclude_mask
  list(
    analysis_mask = analysis_mask,
    include_mask = include_mask,
    exclude_mask = exclude_mask,
    include_roi_ids = unique(roi[action == "include", roi_id]),
    exclude_roi_ids = unique(roi[action == "exclude", roi_id]),
    excluded_pixel_count = sum(exclude_mask),
    included_pixel_count = sum(analysis_mask),
    status = if (any(exclude_mask) || any(include_mask)) "REVIEWED_ROI_APPLIED" else "NO_REVIEWED_ROI"
  )
}

read_tiff_pages <- function(file_path) {
  built_in <- tryCatch(read_uncompressed_tiff_pages(file_path), error = function(e) e)
  if (!inherits(built_in, "error")) return(built_in)

  if (!requireNamespace("tiff", quietly = TRUE)) {
    stop("ImageJ/compressed TIFF requires the R 'tiff' package. Install it with scripts/install_dependencies.R. Built-in reader error: ", built_in$message)
  }
  obj <- tryCatch(
    tiff::readTIFF(file_path, all = TRUE, native = FALSE, convert = TRUE),
    error = function(e) stop("R 'tiff' package could not read TIFF: ", e$message)
  )
  pages <- if (is.list(obj)) obj else list(obj)
  pages <- lapply(pages, function(page) {
    arr <- as.array(page)
    if (length(dim(arr)) == 2L) return(as.matrix(arr))
    if (length(dim(arr)) == 3L && dim(arr)[3L] == 1L) return(as.matrix(arr[, , 1L]))
    stop("TIFF reader returned an RGB/multi-sample page; provide explicit single-channel pages or OME/ImageJ channel metadata.")
  })
  list(pages = pages, bits_per_sample = rep(NA_integer_, length(pages)), parser = "R_tiff_package")
}

read_imagej_tiff <- function(file_path, channel_manifest_rows, z_mode, imagej_meta) {
  n_manifest <- nrow(channel_manifest_rows)
  manifest_indices <- as.integer(channel_manifest_rows$channel_index)
  if (anyNA(manifest_indices) || anyDuplicated(manifest_indices)) {
    stop("ImageJ hyperstack manifest must contain one unique channel_index per declared channel.")
  }

  stack <- read_tiff_pages(file_path)
  pages <- stack$pages
  n_pages <- length(pages)
  n_channels <- as.integer(imagej_meta$channels %||% n_manifest)
  n_slices <- as.integer(imagej_meta$slices %||% 1L)
  n_time <- as.integer(imagej_meta$frames %||% imagej_meta$frames_t %||% 1L)
  if (!is.finite(n_channels) || n_channels < 1L) n_channels <- n_manifest
  if (!is.finite(n_slices) || n_slices < 1L) n_slices <- 1L
  if (!is.finite(n_time) || n_time < 1L) n_time <- 1L
  if (n_channels != n_manifest) {
    stop("ImageJ metadata declares ", n_channels, " channels but manifest declares ", n_manifest, ".")
  }
  if (n_time != 1L) stop("Time-lapse ImageJ stacks are not silently collapsed; split timepoints before quantification.")
  if (n_pages != n_channels * n_slices * n_time) {
    stop("ImageJ metadata/pages mismatch: images=", n_pages, ", channels=", n_channels, ", slices=", n_slices, ".")
  }
  if (!setequal(manifest_indices, seq_len(n_channels))) {
    stop("Manifest channel_index must be exactly 1..", n_channels, " for ImageJ hyperstacks.")
  }

  channel_list <- list()
  meta_rows <- list()
  for (i in order(manifest_indices)) {
    ch_row <- channel_manifest_rows[i]
    page_idx <- ch_row$channel_index + n_channels * seq.int(0L, n_slices - 1L)
    ch_stack <- if (length(page_idx) == 1L) pages[[page_idx]] else simplify2array(pages[page_idx])
    projected <- apply_z_projection(ch_stack, z_mode)
    ch_name <- ch_row$channel_name
    channel_list[[ch_name]] <- as.matrix(projected)
    meta_rows[[length(meta_rows) + 1L]] <- data.table(
      image_id = ch_row$image_id,
      channel_name = ch_name,
      channel_index = ch_row$channel_index,
      marker = ch_row$marker,
      channel_role = ch_row$channel_role,
      original_bit_depth = if (all(is.na(stack$bits_per_sample))) "unknown" else paste0(stack$bits_per_sample[1L], "-bit"),
      dim_x = ncol(projected),
      dim_y = nrow(projected),
      dim_z = n_slices,
      raw_min = min(projected, na.rm = TRUE),
      raw_max = max(projected, na.rm = TRUE),
      z_mode_applied = if (n_slices > 1L) z_mode else "single_plane"
    )
  }
  list(
    channels = channel_list,
    channel_meta = rbindlist(meta_rows),
    image_meta = list(
      dim_x = ncol(pages[[1L]]), dim_y = nrow(pages[[1L]]), dim_z = n_slices,
      bit_depth = if (all(is.na(stack$bits_per_sample))) "unknown" else paste0(stack$bits_per_sample[1L], "-bit"),
      file_path = file_path, z_mode = z_mode, n_frames = n_pages,
      n_channels = n_channels, n_slices = n_slices, n_time = n_time,
      axis_source = "ImageJ_ImageDescription", parser = stack$parser
    )
  )
}

# Validates and reads IF image file into a list of 2D/3D matrices per channel
# Returns: list(
#   channels = list(channel_name = matrix/array),
#   channel_meta = data.table(...),
#   image_meta = list(dim_x, dim_y, dim_z, bit_depth, file_path)
# )
read_if_image <- function(file_path, channel_manifest_rows, z_mode = "max_projection") {
  if (!file.exists(file_path)) {
    stop("IF image file not found: ", file_path)
  }

  imagej_meta <- read_imagej_description(file_path)
  if (!is.null(imagej_meta)) {
    return(read_imagej_tiff(file_path, channel_manifest_rows, z_mode, imagej_meta))
  }

  # Read ordinary non-ImageJ images using EBImage.  ImageJ stacks take the
  # metadata-aware branch above; they must never be inferred from dimensions.
  raw_img <- tryCatch({
    EBImage::readImage(file_path)
  }, error = function(e) {
    stop("Failed to read image file '", file_path, "': ", e$message)
  })

  dims <- dim(raw_img)
  ndims <- length(dims)

  # Determine bit depth and raw range
  # EBImage normalizes values to [0, 1] internally for floating-point representation,
  # but we inspect header/values or file metadata to reconstruct and record accurate ranges.
  raw_min <- min(raw_img, na.rm = TRUE)
  raw_max <- max(raw_img, na.rm = TRUE)

  # Determine data representation
  bit_depth <- if (max(raw_img, na.rm = TRUE) > 255) {
    "16-bit"
  } else if (max(raw_img, na.rm = TRUE) > 1.0) {
    "8-bit"
  } else {
    # Could be float [0, 1] or normalized 8/16-bit in EBImage
    "normalized_float"
  }

  # Parse dimensions:
  # Case 1: 2D single channel (X x Y)
  # Case 2: 3D (X x Y x C) or (X x Y x Z)
  # Case 3: 4D (X x Y x C x Z) or (X x Y x Z x C)

  n_channels_manifest <- nrow(channel_manifest_rows)
  channel_list <- list()
  channel_metadata_list <- list()

  dim_x <- dims[1L]
  dim_y <- dims[2L]
  dim_z <- 1L

  if (ndims == 2L) {
    # Single 2D plane
    if (n_channels_manifest != 1L) {
      stop("Image '", basename(file_path), "' is 2D (1 channel) but manifest declares ", n_channels_manifest, " channels.")
    }
    ch_row <- channel_manifest_rows[1L]
    ch_name <- ch_row$channel_name
    ch_data <- as.matrix(raw_img)
    channel_list[[ch_name]] <- ch_data

    channel_metadata_list[[1L]] <- data.table(
      image_id = ch_row$image_id,
      channel_name = ch_name,
      channel_index = 1L,
      marker = ch_row$marker,
      channel_role = ch_row$channel_role,
      original_bit_depth = bit_depth,
      dim_x = dim_x,
      dim_y = dim_y,
      dim_z = 1L,
      raw_min = min(ch_data, na.rm = TRUE),
      raw_max = max(ch_data, na.rm = TRUE),
      z_mode_applied = "single_plane"
    )
  } else if (ndims == 3L) {
    # 3D: Could be X x Y x C (multi-channel 2D) or X x Y x Z (single channel Z-stack)
    dim3 <- dims[3L]

    unique_ch_idx <- unique(channel_manifest_rows$channel_index)
    if (n_channels_manifest == dim3 && length(unique_ch_idx) > 1L) {
      # Multi-channel 2D (X x Y x C)
      for (i in seq_len(dim3)) {
        ch_row <- channel_manifest_rows[channel_index == i]
        if (nrow(ch_row) == 0L) {
          ch_row <- channel_manifest_rows[i]
        }
        ch_name <- ch_row$channel_name
        ch_data <- raw_img[, , i]
        channel_list[[ch_name]] <- as.matrix(ch_data)

        channel_metadata_list[[i]] <- data.table(
          image_id = ch_row$image_id,
          channel_name = ch_name,
          channel_index = i,
          marker = ch_row$marker,
          channel_role = ch_row$channel_role,
          original_bit_depth = bit_depth,
          dim_x = dim_x,
          dim_y = dim_y,
          dim_z = 1L,
          raw_min = min(ch_data, na.rm = TRUE),
          raw_max = max(ch_data, na.rm = TRUE),
          z_mode_applied = "single_plane"
        )
      }
    } else if (n_channels_manifest == 1L || length(unique_ch_idx) == 1L) {
      # Single-channel Z-stack (X x Y x Z)
      dim_z <- dim3
      projected <- apply_z_projection(raw_img, z_mode)
      for (i in seq_len(n_channels_manifest)) {
        ch_row <- channel_manifest_rows[i]
        ch_name <- ch_row$channel_name
        channel_list[[ch_name]] <- projected

        channel_metadata_list[[i]] <- data.table(
          image_id = ch_row$image_id,
          channel_name = ch_name,
          channel_index = ch_row$channel_index,
          marker = ch_row$marker,
          channel_role = ch_row$channel_role,
          original_bit_depth = bit_depth,
          dim_x = dim_x,
          dim_y = dim_y,
          dim_z = dim_z,
          raw_min = min(projected, na.rm = TRUE),
          raw_max = max(projected, na.rm = TRUE),
          z_mode_applied = z_mode
        )
      }
    } else if (dim3 > n_channels_manifest && (dim3 %% n_channels_manifest == 0L)) {
      # Multi-channel Z-stack stored as flattened TIFF stack (dim3 = n_channels * n_z)
      n_z <- dim3 / n_channels_manifest
      dim_z <- n_z
      for (i in seq_len(n_channels_manifest)) {
        ch_row <- channel_manifest_rows[channel_index == i]
        if (nrow(ch_row) == 0L) ch_row <- channel_manifest_rows[i]
        ch_name <- ch_row$channel_name

        # Test interleaved vs sequential slices
        slices <- seq(i, dim3, by = n_channels_manifest)
        ch_3d <- raw_img[, , slices]
        projected <- apply_z_projection(ch_3d, z_mode)
        channel_list[[ch_name]] <- projected

        channel_metadata_list[[i]] <- data.table(
          image_id = ch_row$image_id,
          channel_name = ch_name,
          channel_index = i,
          marker = ch_row$marker,
          channel_role = ch_row$channel_role,
          original_bit_depth = bit_depth,
          dim_x = dim_x,
          dim_y = dim_y,
          dim_z = n_z,
          raw_min = min(projected, na.rm = TRUE),
          raw_max = max(projected, na.rm = TRUE),
          z_mode_applied = z_mode
        )
      }
    } else {
      stop("Dimension mismatch: 3rd dimension is ", dim3, " but manifest specifies ", n_channels_manifest, " channels.")
    }
  } else if (ndims == 4L) {
    # 4D: (X x Y x C x Z) or (X x Y x Z x C)
    # Check matching with manifest
    if (dims[3L] == n_channels_manifest) {
      # X x Y x C x Z
      n_c <- dims[3L]
      n_z <- dims[4L]
      dim_z <- n_z
      for (i in seq_len(n_c)) {
        ch_row <- channel_manifest_rows[channel_index == i]
        if (nrow(ch_row) == 0L) ch_row <- channel_manifest_rows[i]
        ch_name <- ch_row$channel_name
        z_stack_ch <- raw_img[, , i, ]
        projected <- apply_z_projection(z_stack_ch, z_mode)
        channel_list[[ch_name]] <- projected

        channel_metadata_list[[i]] <- data.table(
          image_id = ch_row$image_id,
          channel_name = ch_name,
          channel_index = i,
          marker = ch_row$marker,
          channel_role = ch_row$channel_role,
          original_bit_depth = bit_depth,
          dim_x = dim_x,
          dim_y = dim_y,
          dim_z = n_z,
          raw_min = min(projected, na.rm = TRUE),
          raw_max = max(projected, na.rm = TRUE),
          z_mode_applied = z_mode
        )
      }
    } else if (dims[4L] == n_channels_manifest) {
      # X x Y x Z x C
      n_z <- dims[3L]
      n_c <- dims[4L]
      dim_z <- n_z
      for (i in seq_len(n_c)) {
        ch_row <- channel_manifest_rows[channel_index == i]
        if (nrow(ch_row) == 0L) ch_row <- channel_manifest_rows[i]
        ch_name <- ch_row$channel_name
        z_stack_ch <- raw_img[, , , i]
        projected <- apply_z_projection(z_stack_ch, z_mode)
        channel_list[[ch_name]] <- projected

        channel_metadata_list[[i]] <- data.table(
          image_id = ch_row$image_id,
          channel_name = ch_name,
          channel_index = i,
          marker = ch_row$marker,
          channel_role = ch_row$channel_role,
          original_bit_depth = bit_depth,
          dim_x = dim_x,
          dim_y = dim_y,
          dim_z = n_z,
          raw_min = min(projected, na.rm = TRUE),
          raw_max = max(projected, na.rm = TRUE),
          z_mode_applied = z_mode
        )
      }
    } else {
      stop("Cannot determine C and Z axes for 4D image dimensions: ", paste(dims, collapse = "x"))
    }
  } else {
    stop("Unsupported image dimensions count: ", ndims)
  }

  ch_meta_dt <- rbindlist(channel_metadata_list)

  return(list(
    channels = channel_list,
    channel_meta = ch_meta_dt,
    image_meta = list(
      dim_x = dim_x,
      dim_y = dim_y,
      dim_z = dim_z,
      bit_depth = bit_depth,
      file_path = file_path,
      z_mode = z_mode
    )
  ))
}

# Apply 3D Z-stack projection to 2D
apply_z_projection <- function(img_3d, z_mode = "max_projection") {
  if (length(dim(img_3d)) == 2L) return(as.matrix(img_3d))

  if (z_mode == "max_projection") {
    apply(img_3d, c(1L, 2L), max, na.rm = TRUE)
  } else if (z_mode == "mean_projection") {
    apply(img_3d, c(1L, 2L), mean, na.rm = TRUE)
  } else if (z_mode == "sum_projection") {
    apply(img_3d, c(1L, 2L), sum, na.rm = TRUE)
  } else if (z_mode == "single_plane") {
    # Default to middle plane if single plane requested from 3D stack
    mid_z <- ceiling(dim(img_3d)[3L] / 2)
    as.matrix(img_3d[, , mid_z])
  } else {
    warning("Unknown z_mode '", z_mode, "', defaulting to max_projection")
    apply(img_3d, c(1L, 2L), max, na.rm = TRUE)
  }
}

# Helper to validate manifest columns and roles
validate_if_manifest <- function(manifest_dt) {
  required_cols <- c(
    "image_id", "biological_unit_id", "condition", "modality",
    "marker", "channel_name", "channel_index", "channel_role",
    "file_path"
  )
  missing_cols <- setdiff(required_cols, names(manifest_dt))
  if (length(missing_cols) > 0L) {
    stop("IF manifest is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Check modality
  if (any(tolower(manifest_dt$modality) != "immunofluorescence")) {
    bad_mods <- unique(manifest_dt$modality[tolower(manifest_dt$modality) != "immunofluorescence"])
    stop("Non-immunofluorescence modality detected in IF manifest: ", paste(bad_mods, collapse = ", "))
  }

  # Check channel roles
  invalid_roles <- setdiff(unique(tolower(manifest_dt$channel_role)), ALLOWED_CHANNEL_ROLES)
  if (length(invalid_roles) > 0L) {
    stop("Invalid channel_role in manifest: ", paste(invalid_roles, collapse = ", "),
         ". Allowed roles: ", paste(ALLOWED_CHANNEL_ROLES, collapse = ", "))
  }

  # Must have at least one nucleus channel and one target channel per image
  for (img_id in unique(manifest_dt$image_id)) {
    sub_dt <- manifest_dt[image_id == img_id]
    roles <- tolower(sub_dt$channel_role)
    idx <- as.integer(sub_dt$channel_index)
    if (anyNA(idx) || anyDuplicated(idx) || !setequal(idx, seq_len(nrow(sub_dt)))) {
      stop("Image '", img_id, "' must declare unique channel_index values 1..", nrow(sub_dt), ".")
    }
    if (!"nucleus" %in% roles) {
      stop("Image '", img_id, "' has no channel designated with channel_role == 'nucleus'.")
    }
    if (!"target" %in% roles) {
      stop("Image '", img_id, "' has no channel designated with channel_role == 'target'.")
    }
  }

  return(TRUE)
}
