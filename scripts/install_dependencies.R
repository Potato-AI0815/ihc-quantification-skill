#!/usr/bin/env Rscript

options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 1200)
args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this tool with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
source(file.path(script_dir, "path_utils.R"))
root <- dirname(script_dir)
lib_arg <- grep("^--lib=", args, value = TRUE)
lib_raw <- if (length(lib_arg)) sub("^--lib=", "", lib_arg[[1L]]) else file.path(root, "Rlib")
lib <- normalize_path_portable(lib_raw, must_work = FALSE)
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
lib <- normalizePath(lib, mustWork = TRUE)
.libPaths(c(lib, .libPaths()))

cran <- c("data.table", "ggplot2", "ragg", "svglite", "tiff")
missing_cran <- cran[!vapply(cran, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_cran)) install.packages(missing_cran, lib = lib)
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager", lib = lib)
if (!requireNamespace("EBImage", quietly = TRUE)) BiocManager::install("EBImage", lib = lib, ask = FALSE, update = FALSE)
cat("IHC skill dependencies available in ", lib, "\n", sep = "")
cat("R version: ", R.version.string, "\n", sep = "")
for (pkg in c("EBImage", "data.table", "ggplot2", "ragg", "svglite", "tiff")) {
  cat(pkg, ": ", as.character(utils::packageVersion(pkg)), "\n", sep = "")
}
