#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this test with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
root <- dirname(script_dir)
source(file.path(root, "scripts", "path_utils.R"))

stopifnot(is_absolute_path_portable("/tmp/example"))
stopifnot(is_absolute_path_portable("C:/example/file.csv"))
stopifnot(is_absolute_path_portable("C:\\example\\file.csv"))
stopifnot(is_absolute_path_portable("\\\\server\\share\\file.csv"))
stopifnot(is_absolute_path_portable("~/example/file.csv"))
stopifnot(!is_absolute_path_portable("relative/path.csv"))

base <- file.path(tempdir(), "ihc path contract with spaces")
dir.create(base, recursive = TRUE, showWarnings = FALSE)
probe <- file.path(base, "probe file.txt")
writeLines("synthetic", probe)
resolved <- resolve_path_portable("probe file.txt", base_dir = base, must_work = TRUE)
stopifnot(file.exists(resolved), identical(basename(resolved), "probe file.txt"))

cat("PASS: cross-platform absolute-path detection and relative paths with spaces are supported.\n")
