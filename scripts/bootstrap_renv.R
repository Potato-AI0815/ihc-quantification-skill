#!/usr/bin/env Rscript

options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 1200)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this tool with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
root <- dirname(script_dir)
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
setwd(root)
renv::restore(prompt = FALSE)
cat("renv restore completed for ", root, "\n", sep = "")
