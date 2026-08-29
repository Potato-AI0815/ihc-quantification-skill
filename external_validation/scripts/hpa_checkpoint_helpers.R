# Checkpoint/resume helpers for the HPA real-data validation.
#
# These helpers isolate the crash-resilient checkpoint contract from the
# analysis loop so that the merge/resume semantics can be regression-tested
# (tests/verify_hpa_checkpoint_resume.R) without re-running any image analysis:
#
#   - checkpoints carry the full result schema and are validated before use;
#   - duplicate image_ids and image_ids outside the manifest FAIL explicitly
#     (never a silent overwrite or silent drop);
#   - merged output is always ordered by the manifest;
#   - final results must cover the manifest exactly (no missing, no extra);
#   - checkpoint writes are atomic (temporary file + rename).

suppressPackageStartupMessages(library(data.table))

HPA_RESULT_REQUIRED_COLUMNS <- c(
  "image_id", "gene", "antibody_id", "patient_id", "tissue",
  "subcellular_location", "gt_staining", "gt_tier_num", "gt_intensity",
  "gt_quantity", "image_width", "image_height", "tissue_pixels",
  "cell_count", "dab_tissue_mean_od", "dab_tissue_median_od",
  "dab_tissue_p95_od", "dab_tissue_pos_fraction", "mean_cell_dab_od",
  "mean_nuc_dab_od", "mean_cyto_dab_od", "ihc_h_score",
  "positive_cell_fraction"
)

HPA_RESULT_NUMERIC_COLUMNS <- c(
  "gt_tier_num", "image_width", "image_height", "tissue_pixels",
  "cell_count", "dab_tissue_mean_od", "dab_tissue_median_od",
  "dab_tissue_p95_od", "dab_tissue_pos_fraction", "mean_cell_dab_od",
  "mean_nuc_dab_od", "mean_cyto_dab_od", "ihc_h_score",
  "positive_cell_fraction"
)

# Decide whether an existing checkpoint may be resumed. A missing or
# mismatched mode marker invalidates any results CSV from an unknown prior
# run (e.g. a different calibration), which is then removed and the marker
# rewritten.
hpa_checkpoint_state <- function(mode_file, checkpoint_csv, current_mode) {
  restart <- TRUE
  if (file.exists(mode_file)) {
    recorded <- tryCatch(
      readLines(mode_file, warn = FALSE)[1L],
      error = function(e) NA_character_
    )
    restart <- is.na(recorded) || is.na(current_mode) || recorded != current_mode
  }
  if (restart) {
    unlink(checkpoint_csv)
    writeLines(current_mode, mode_file)
    list(action = "restart")
  } else {
    list(action = "resume")
  }
}

# Validate a checkpoint table read back from disk. Any structural problem is a
# hard error: a silently truncated or corrupt checkpoint must never be merged.
hpa_validate_checkpoint <- function(prev, manifest) {
  if (is.null(prev) || !is.data.frame(prev) || nrow(prev) == 0L) {
    stop("HPA checkpoint is empty or unreadable: refusing to resume.")
  }
  missing_cols <- setdiff(HPA_RESULT_REQUIRED_COLUMNS, names(prev))
  if (length(missing_cols)) {
    stop("HPA checkpoint is missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }
  ids <- as.character(prev$image_id)
  if (anyNA(ids) || any(trimws(ids) == "")) {
    stop("HPA checkpoint contains empty or NA image_id values.")
  }
  dup <- unique(ids[duplicated(ids)])
  if (length(dup)) {
    stop("HPA checkpoint contains duplicate image_id entries: ",
         paste(dup, collapse = ", "))
  }
  unknown <- setdiff(ids, as.character(manifest$image_id))
  if (length(unknown)) {
    stop("HPA checkpoint contains image_ids absent from the current manifest: ",
         paste(unknown, collapse = ", "))
  }
  for (col in HPA_RESULT_NUMERIC_COLUMNS) {
    raw <- trimws(as.character(prev[[col]]))
    bad <- !is.na(raw) & raw != "" & is.na(suppressWarnings(as.numeric(raw)))
    if (any(bad)) {
      stop("HPA checkpoint column '", col, "' has malformed numeric value(s): ",
           paste(unique(raw[bad]), collapse = ", "))
    }
  }
  tiers <- suppressWarnings(as.numeric(trimws(as.character(prev$gt_tier_num))))
  tiers_valid <- is.na(tiers) | tiers %in% c(0, 1, 2, 3)
  if (any(!tiers_valid)) {
    stop("HPA checkpoint column 'gt_tier_num' has values outside 0-3.")
  }
  prev
}

# Merge previously checkpointed rows with newly computed rows. The result is
# always ordered by the manifest. Duplicates and unknown image_ids are hard
# failures. With allow_incomplete = FALSE the merge additionally asserts the
# final coverage contract: exactly the manifest's images, no more, no fewer.
hpa_merge_checkpoint <- function(existing_results, new_rows, manifest,
                                 allow_incomplete = TRUE) {
  combined <- rbindlist(list(existing_results, new_rows), fill = TRUE)
  if (nrow(combined)) {
    ids <- as.character(combined$image_id)
    dup <- unique(ids[duplicated(ids)])
    if (length(dup)) {
      stop("Duplicate image_id in HPA results (refusing silent overwrite): ",
           paste(dup, collapse = ", "))
    }
    unknown <- setdiff(ids, as.character(manifest$image_id))
    if (length(unknown)) {
      stop("HPA results contain image_ids absent from the current manifest: ",
           paste(unknown, collapse = ", "))
    }
    order_idx <- match(as.character(manifest$image_id), ids)
    order_idx <- order_idx[!is.na(order_idx)]
    combined <- combined[order_idx]
  }
  if (!allow_incomplete) {
    complete <- nrow(combined) == nrow(manifest) &&
      uniqueN(combined$image_id) == nrow(manifest) &&
      setequal(as.character(combined$image_id), as.character(manifest$image_id))
    if (!complete) {
      missing <- setdiff(as.character(manifest$image_id),
                         as.character(combined$image_id))
      stop("HPA results do not cover the manifest exactly. Rows: ",
           nrow(combined), "/", nrow(manifest),
           ". Missing image_ids: ", paste(utils::head(missing, 10), collapse = ", "),
           if (length(missing) > 10L) " ..." else "")
    }
  }
  combined
}

# Write a checkpoint atomically: the target is either the previous complete
# checkpoint or the new complete checkpoint, never a half-written file.
hpa_atomic_fwrite <- function(dt, path) {
  tmp <- paste0(path, ".tmp")
  fwrite(dt, tmp)
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  # POSIX rename atomically replaces an existing target. Windows blocks rename
  # onto an existing file, so remove it first there; the remove-rename window
  # can only lose a checkpoint (resumable), never silently corrupt a result.
  if (.Platform$OS.type == "windows" && file.exists(path)) unlink(path)
  if (!file.rename(tmp, path)) {
    stop("HPA checkpoint atomic rename failed for: ", path)
  }
  invisible(path)
}
