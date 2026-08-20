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
if (is.null(cli$manifest)) stop("Required: --manifest=/path/manifest.csv [--roi=/path/roi.csv --out=/path/input_validation.tsv --local-lib=/path/Rlib]")
local_lib <- normalize_optional_dir(cli$`local-lib`)
if (!is.null(local_lib)) {
  .libPaths(c(local_lib, .libPaths()))
}

suppressPackageStartupMessages(library(data.table))
manifest_path <- normalize_path_portable(cli$manifest, must_work = TRUE)
manifest <- fread(manifest_path)
issues <- list()
add_issue <- function(level, scope, id, issue, detail = "") {
  issues[[length(issues) + 1L]] <<- data.table(level = level, scope = scope, id = as.character(id), issue = issue, detail = detail)
}

aliases <- list(
  biological_unit_id = c("biological_unit_id", "patient_id", "animal_id", "sample_id"),
  field_id = c("field_id", "field", "image_field"),
  file_path = c("file_path", "source_file")
)
for (target in names(aliases)) {
  if (!target %in% names(manifest)) {
    found <- aliases[[target]][aliases[[target]] %in% names(manifest)]
    if (length(found)) setnames(manifest, found[[1]], target)
  }
}

is_if_modality <- ("modality" %in% names(manifest) && any(tolower(trimws(manifest$modality)) %in% c("immunofluorescence", "if")))

if (is_if_modality) {
  required <- c("image_id", "biological_unit_id", "condition", "marker", "channel_name", "channel_role", "file_path")
  # Channel indices are part of the IF input contract.  They are optional for
  # legacy DAB manifests, but an IF image must map each physical channel once
  # and only once before any reader can safely interpret an ImageJ hyperstack.
  required <- c(required, "channel_index")
} else {
  required <- c("image_id", "biological_unit_id", "condition", "field_id", "file_path")
}

for (nm in setdiff(required, names(manifest))) add_issue("ERROR", "manifest", "ALL", "MISSING_REQUIRED_COLUMN", nm)
if (!all(required %in% names(manifest))) {
  result <- rbindlist(issues, fill = TRUE)
} else if (is_if_modality) {
  # IF Manifest validation
  manifest[, image_id := as.character(image_id)]
  for (i in seq_len(nrow(manifest))) {
    path <- resolve_path_portable(as.character(manifest$file_path[[i]]), dirname(manifest_path), must_work = FALSE)
    if (!file.exists(path)) add_issue("ERROR", "image", manifest$image_id[[i]], "SOURCE_FILE_NOT_FOUND", path)
  }
  allowed_roles <- c("nucleus", "target", "cytoplasm_reference", "membrane_reference", "structural_reference", "background_reference", "other")
  for (r in unique(tolower(trimws(manifest$channel_role)))) {
    if (!r %in% allowed_roles) add_issue("ERROR", "manifest", "ALL", "INVALID_CHANNEL_ROLE", r)
  }
  for (id in unique(manifest$image_id)) {
    sub_m <- manifest[image_id == id]
    roles <- tolower(trimws(sub_m$channel_role))
    if (!"nucleus" %in% roles) add_issue("ERROR", "image", id, "NO_NUCLEAR_CHANNEL")
    if (!"target" %in% roles) add_issue("ERROR", "image", id, "NO_TARGET_SIGNAL")
    idx <- suppressWarnings(as.integer(sub_m$channel_index))
    if (anyNA(idx) || anyDuplicated(idx) || !setequal(idx, seq_len(nrow(sub_m)))) {
      add_issue(
        "ERROR", "image", id, "INVALID_CHANNEL_INDEX_MAPPING",
        paste0("Expected unique 1..", nrow(sub_m), " channel_index values.")
      )
    }
  }
  result <- if (length(issues)) rbindlist(issues, fill = TRUE) else data.table(level = "PASS", scope = "all", id = "ALL", issue = "INPUT_VALIDATION_PASS", detail = "")
} else {
  manifest[, image_id := as.character(image_id)]
  if (anyDuplicated(manifest$image_id)) {
    for (id in unique(manifest$image_id[duplicated(manifest$image_id) | duplicated(manifest$image_id, fromLast = TRUE)])) add_issue("ERROR", "image", id, "DUPLICATE_IMAGE_ID")
  }
  if (!"pixel_size_um" %in% names(manifest)) {
    add_issue("WARNING", "manifest", "ALL", "PIXEL_SIZE_COLUMN_MISSING", "Cross-magnification analysis will use pixel fallback parameters.")
  } else {
    px <- suppressWarnings(as.numeric(manifest$pixel_size_um))
    for (id in manifest$image_id[!is.finite(px) | px <= 0]) add_issue("WARNING", "image", id, "MISSING_PIXEL_SIZE", "Physical calibration unavailable.")
  }
  for (i in seq_len(nrow(manifest))) {
    src_f <- if ("file_path" %in% names(manifest)) manifest$file_path[[i]] else manifest$source_file[[i]]
    path <- resolve_path_portable(as.character(src_f), dirname(manifest_path), must_work = FALSE)
    if (!file.exists(path)) add_issue("ERROR", "image", manifest$image_id[[i]], "SOURCE_FILE_NOT_FOUND", path)
    if (grepl("\\.(svs|ndpi|mrxs|scn)$", tolower(path))) add_issue("ERROR", "image", manifest$image_id[[i]], "NATIVE_WSI_NOT_SUPPORTED", "Export tiles or regions first.")
  }
  if (any(is.na(manifest$biological_unit_id) | manifest$biological_unit_id == "")) add_issue("ERROR", "manifest", "ALL", "MISSING_BIOLOGICAL_UNIT_ID")
  if (any(is.na(manifest$condition) | manifest$condition == "")) add_issue("ERROR", "manifest", "ALL", "MISSING_CONDITION")

  if (!is.null(cli$roi)) {
    roi <- fread(normalize_path_portable(cli$roi, must_work = TRUE))
    roi_required <- c("image_id", "roi_id", "vertex_order", "x", "y")
    for (nm in setdiff(roi_required, names(roi))) add_issue("ERROR", "roi", "ALL", "MISSING_ROI_COLUMN", nm)
    if (all(roi_required %in% names(roi))) {
      unknown <- setdiff(unique(as.character(roi$image_id)), manifest$image_id)
      for (id in unknown) add_issue("ERROR", "roi", id, "ROI_IMAGE_ID_NOT_IN_MANIFEST")
      vertices <- roi[, .N, by = .(image_id, roi_id)]
      for (i in seq_len(nrow(vertices[ N < 3 ]))) {
        row <- vertices[N < 3][i]
        add_issue("ERROR", "roi", paste(row$image_id, row$roi_id, sep = "/"), "ROI_HAS_FEWER_THAN_3_VERTICES")
      }
      if (any(!is.finite(suppressWarnings(as.numeric(roi$x))) | !is.finite(suppressWarnings(as.numeric(roi$y))))) add_issue("ERROR", "roi", "ALL", "NON_NUMERIC_ROI_COORDINATE")
      if ("action" %in% names(roi)) {
        actions <- unique(tolower(trimws(as.character(roi$action))))
        bad <- actions[!actions %in% c("include", "exclude")]
        for (x in bad) add_issue("ERROR", "roi", "ALL", "INVALID_ROI_ACTION", x)
      }
      if ("annotation_status" %in% names(roi)) {
        statuses <- unique(tolower(trimws(as.character(roi$annotation_status))))
        bad <- statuses[!statuses %in% c("selected", "reviewed", "approved", "draft", "rejected")]
        for (x in bad) add_issue("ERROR", "roi", "ALL", "INVALID_ANNOTATION_STATUS", x)
        ignored <- roi[tolower(trimws(as.character(annotation_status))) %in% c("draft", "rejected"), .N]
        if (ignored > 0L) add_issue("WARNING", "roi", "ALL", "DRAFT_OR_REJECTED_ROIS_WILL_BE_IGNORED", as.character(ignored))
      }
      if ("compartment" %in% names(roi)) {
        named_idx <- tolower(trimws(as.character(roi$compartment))) %in% c("tumor", "stroma", "interface")
        named <- roi[named_idx]
        if (nrow(named)) {
          if (!"selection_source" %in% names(roi)) {
            add_issue("ERROR", "roi", "ALL", "NAMED_COMPARTMENT_WITHOUT_SOURCE", "Add manual/external_model provenance.")
          } else {
            bad_source <- named[is.na(selection_source) | trimws(as.character(selection_source)) == "" | tolower(trimws(as.character(selection_source))) %in% c("automatic", "unknown")]
            for (id in unique(paste(bad_source$image_id, bad_source$roi_id, sep = "/"))) add_issue("ERROR", "roi", id, "NAMED_COMPARTMENT_INVALID_SOURCE")
          }
          if (!"reviewer" %in% names(roi)) {
            add_issue("ERROR", "roi", "ALL", "NAMED_COMPARTMENT_WITHOUT_REVIEWER")
          } else {
            missing_reviewer <- named[is.na(reviewer) | trimws(as.character(reviewer)) == ""]
            for (id in unique(paste(missing_reviewer$image_id, missing_reviewer$roi_id, sep = "/"))) add_issue("ERROR", "roi", id, "NAMED_COMPARTMENT_WITHOUT_REVIEWER")
          }
        }
      }
      metadata_cols <- intersect(c("compartment", "action", "selection_source", "selection_method", "reviewer", "annotation_status"), names(roi))
      if (length(metadata_cols)) {
        consistency <- roi[, lapply(.SD, uniqueN), by = .(image_id, roi_id), .SDcols = metadata_cols]
        count_cols <- setdiff(names(consistency), c("image_id", "roi_id"))
        count_matrix <- as.matrix(consistency[, count_cols, with = FALSE])
        bad <- consistency[rowSums(count_matrix > 1L) > 0L, .(image_id, roi_id)]
        for (id in unique(paste(bad$image_id, bad$roi_id, sep = "/"))) add_issue("ERROR", "roi", id, "INCONSISTENT_ROI_METADATA")
      }
    }
  }
  result <- if (length(issues)) rbindlist(issues, fill = TRUE) else data.table(level = "PASS", scope = "all", id = "ALL", issue = "INPUT_VALIDATION_PASS", detail = "")
}

out <- if (!is.null(cli$out)) normalize_path_portable(cli$out, must_work = FALSE) else file.path(dirname(manifest_path), "ihc_input_validation.tsv")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
fwrite(result, out, sep = "\t")
cat("Validation report:", out, "\n")
cat("Errors:", result[level == "ERROR", .N], "Warnings:", result[level == "WARNING", .N], "\n")
if (result[level == "ERROR", .N] > 0L) quit(status = 2L)
