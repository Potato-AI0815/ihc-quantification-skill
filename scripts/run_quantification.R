#!/usr/bin/env Rscript
# run_quantification.R
# Modality Router for IHC / IF Quantification Skill v2.3.0-alpha.2

options(stringsAsFactors = FALSE, scipen = 999)

parse_cli <- function(x) {
  out <- list()
  for (arg in x) {
    if (!grepl("^--[^=]+=", arg)) stop("Arguments must use --key=value: ", arg)
    pair <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    out[[pair[[1L]]]] <- paste(pair[-1L], collapse = "=")
  }
  out
}

raw_args <- commandArgs(trailingOnly = TRUE)
cli <- parse_cli(raw_args)
required_cli <- c("manifest", "outdir")
missing_cli <- required_cli[!required_cli %in% names(cli)]
if (length(missing_cli)) stop("Required arguments missing: ", paste0("--", missing_cli, collapse = ", "))

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this tool with Rscript.")
script_dir <- dirname(normalizePath(path.expand(sub("^--file=", "", script_arg[[1L]])), mustWork = TRUE))
source(file.path(script_dir, "path_utils.R"))

manifest_path <- normalize_path_portable(cli$manifest, must_work = TRUE)
manifest_header <- utils::read.csv(manifest_path, nrows = 5)

if (!"modality" %in% names(manifest_header)) {
  # Default legacy DAB IHC if modality column not specified
  modality <- "brightfield_dab"
} else {
  mods <- unique(tolower(trimws(manifest_header$modality)))
  if (length(mods) == 0L) {
    modality <- "brightfield_dab"
  } else if ("immunofluorescence" %in% mods || "if" %in% mods) {
    modality <- "immunofluorescence"
  } else if ("brightfield_dab" %in% mods || "dab" %in% mods || "ihc" %in% mods) {
    modality <- "brightfield_dab"
  } else {
    stop("Unknown modality in manifest: '", paste(mods, collapse = ", "),
         "'. Supported modalities: 'brightfield_dab', 'immunofluorescence'.")
  }
}

cat(sprintf("Routing quantification task to modality handler: [%s]\n", modality))

if (modality == "immunofluorescence") {
  target_script <- file.path(script_dir, "run_if_quantification.R")
} else {
  target_script <- file.path(script_dir, "run_ihc_quantification.R")
}

# Forward all CLI arguments to target runner
status <- system2("Rscript", args = c(target_script, raw_args), stdout = "", stderr = "")
if (!is.null(status) && is.numeric(status) && status != 0L) {
  quit(status = as.integer(status))
}
