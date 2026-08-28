#!/usr/bin/env Rscript

# Lossless validation-layer conversion only. BMP is not added to core input
# support; converted TIFFs are written to the ignored external cache.

options(stringsAsFactors = FALSE)
suppressPackageStartupMessages({
  library(data.table)
  library(bmp)
  library(tiff)
  library(digest)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run with Rscript.")
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE))
root <- dirname(dirname(script_dir))
source_dir <- file.path(root, ".external_validation_cache", "BBBC013", "extracted", "BBBC013_v1_images_bmp")
converted_dir <- file.path(root, ".external_validation_cache", "BBBC013", "converted_tiff")
result_dir <- file.path(root, "external_validation", "results")
dir.create(converted_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)

if (!dir.exists(source_dir)) stop("BBBC013 BMP source directory is missing.")
files <- list.files(source_dir, pattern = "\\.BMP$", full.names = TRUE, ignore.case = TRUE)
if (length(files) != 192L) stop("Expected 192 BBBC013 BMP files; found ", length(files), ".")

rows <- vector("list", length(files))
for (i in seq_along(files)) {
  src <- files[[i]]
  base <- basename(src)
  image_match <- regexec("^Channel([12])-([0-9]{2})-([A-H])-([0-9]{2})\\.BMP$", base, ignore.case = TRUE)
  tokens <- regmatches(base, image_match)[[1L]]
  if (length(tokens) != 5L) stop("Unexpected BBBC013 filename: ", base)
  channel <- as.integer(tokens[[2L]])
  well <- paste0(toupper(tokens[[4L]]), tokens[[5L]])
  matrix_int <- bmp::read.bmp(src)
  if (!is.matrix(matrix_int) || typeof(matrix_int) != "integer") stop("BMP reader did not return an integer matrix: ", base)
  before_min <- min(matrix_int); before_max <- max(matrix_int)
  rel <- paste0("Channel", channel, "-", tokens[[3L]], "-", tokens[[4L]], "-", tokens[[5L]], ".tif")
  dest <- file.path(converted_dir, rel)
  # tiff::writeTIFF expects [0, 1] real values.  Dividing by 255 and reading
  # back with convert=TRUE preserves every original 8-bit integer exactly.
  tiff::writeTIFF(matrix(as.numeric(matrix_int) / 255, nrow(matrix_int), ncol(matrix_int)),
                  dest, bits.per.sample = 8L, compression = "none")
  roundtrip <- tiff::readTIFF(dest, native = FALSE, convert = TRUE, all = FALSE)
  if (length(dim(roundtrip)) > 2L) roundtrip <- roundtrip[, , 1L]
  after_int <- as.integer(round(roundtrip * 255))
  exact <- identical(as.integer(matrix_int), after_int) &&
    min(after_int) == before_min && max(after_int) == before_max
  if (!exact) stop("Lossless BMP->TIFF check failed: ", base)
  rows[[i]] <- data.table(
    source_file = base,
    converted_file = rel,
    channel = channel,
    well = well,
    width_px = ncol(matrix_int), height_px = nrow(matrix_int),
    source_sha256 = digest::digest(src, file = TRUE, algo = "sha256"),
    converted_sha256 = digest::digest(dest, file = TRUE, algo = "sha256"),
    min_before = before_min, max_before = before_max,
    min_after = min(after_int), max_after = max(after_int),
    exact_integer_roundtrip = exact
  )
}

conversion <- rbindlist(rows)
fwrite(conversion, file.path(result_dir, "BBBC013_BMP_TIFF_CONVERSION.csv"))
cat(sprintf("BBBC013 lossless conversion PASS: %d BMP files converted and byte/pixel checked.\n", nrow(conversion)))
