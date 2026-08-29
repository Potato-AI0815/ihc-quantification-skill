#!/usr/bin/env Rscript

# Regression test for the HPA real-data checkpoint/resume contract
# (external_validation/scripts/hpa_checkpoint_helpers.R).
#
# Simulates the full checkpoint lifecycle with deterministic mock result rows —
# no image analysis is performed:
#   A. clean 64-image run
#   B. interrupted run checkpointed at image 32 (simulated crash)
#   C. resumed run computing only images 33-64
#   core acceptance: the interrupted-then-resumed final checkpoint must equal
#   the clean-run final checkpoint exactly (in memory and byte-for-byte),
#   in manifest order.
#   D. duplicate checkpoint image_ids        -> FAIL loudly
#   E. checkpoint image_id outside manifest  -> FAIL loudly
#   F. checkpoint mode change                -> invalidate and restart safely
#   G. malformed / incomplete checkpoints    -> FAIL clearly, never silently

options(stringsAsFactors = FALSE, scipen = 999)

# CI bootstrap: on GitHub Actions the R dependencies live in <workspace>/Rlib
# (see .github/workflows/ci.yml); add it explicitly because R_LIBS_USER alone
# is not reliably applied on the Windows runner. No-op when unset or absent.
ci_local_lib <- Sys.getenv("GITHUB_WORKSPACE", unset = "")
if (nzchar(ci_local_lib)) {
  ci_local_lib <- file.path(ci_local_lib, "Rlib")
  if (dir.exists(ci_local_lib)) {
    .libPaths(c(normalizePath(ci_local_lib), .libPaths()))
  }
}

suppressPackageStartupMessages(library(data.table))

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run with Rscript.")
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE))
root <- dirname(script_dir)
source(file.path(root, "external_validation", "scripts", "hpa_checkpoint_helpers.R"))

failures <- character()
check <- function(label, condition) {
  if (isTRUE(condition)) {
    cat(sprintf("PASS: %s\n", label))
  } else {
    failures <<- c(failures, label)
    cat(sprintf("FAIL: %s\n", label))
  }
}

expect_error <- function(label, expr, pattern) {
  err <- tryCatch({ force(expr); NULL }, error = function(e) e)
  if (is.null(err)) {
    failures <<- c(failures, label)
    cat(sprintf("FAIL: %s (no error raised)\n", label))
  } else if (!grepl(pattern, conditionMessage(err))) {
    failures <<- c(failures, label)
    cat(sprintf("FAIL: %s (unexpected message: %s)\n", label, conditionMessage(err)))
  } else {
    cat(sprintf("PASS: %s\n", label))
  }
}

# Deterministic mock manifest and result rows (no randomness anywhere).
manifest <- data.table(image_id = sprintf("IMG_%03d", seq_len(64L)))

mock_row <- function(manifest_row) {
  idx <- match(manifest_row$image_id, manifest$image_id)
  data.table(
    image_id = manifest_row$image_id,
    gene = "MOCKGENE",
    antibody_id = "CAB000000",
    patient_id = sprintf("P%04d", idx),
    tissue = "Test tissue",
    subcellular_location = "nuclear",
    gt_staining = c("Not detected", "Low", "Medium", "High")[idx %% 4L + 1L],
    gt_tier_num = idx %% 4L,
    gt_intensity = "Weak",
    gt_quantity = "25%-75%",
    image_width = 3000L,
    image_height = 3000L,
    tissue_pixels = 1000000L + idx,
    cell_count = 500L + idx,
    dab_tissue_mean_od = round(0.100 + idx * 0.001, 5),
    dab_tissue_median_od = round(0.050 + idx * 0.001, 5),
    dab_tissue_p95_od = round(0.300 + idx * 0.002, 5),
    dab_tissue_pos_fraction = round(0.500 + idx * 0.001, 4),
    mean_cell_dab_od = round(0.110 + idx * 0.001, 5),
    mean_nuc_dab_od = round(0.120 + idx * 0.001, 5),
    mean_cyto_dab_od = round(0.090 + idx * 0.001, 5),
    ihc_h_score = round(10 + idx * 0.5, 2),
    positive_cell_fraction = round(0.400 + idx * 0.002, 4)
  )
}
compute_mock <- function(ids) rbindlist(lapply(ids, function(id) mock_row(manifest[image_id == id])))

# ---- Scenario A: clean run over all 64 images -------------------------------
work_a <- file.path(tempdir(), "hpa_ckpt_test_clean")
unlink(work_a, recursive = TRUE)
dir.create(work_a, recursive = TRUE)
csv_a <- file.path(work_a, "results.csv")
mode_a <- file.path(work_a, "checkpoint_mode.txt")

state_a1 <- hpa_checkpoint_state(mode_a, csv_a, "pixel_fallback_v1")
check("A: fresh run starts in restart state", state_a1$action == "restart")
accumulated_a <- data.table()
for (i in seq_len(nrow(manifest))) {
  accumulated_a <- hpa_merge_checkpoint(accumulated_a, mock_row(manifest[i]), manifest)
  hpa_atomic_fwrite(accumulated_a, csv_a)
}
res_a <- hpa_merge_checkpoint(data.table(), accumulated_a, manifest,
                              allow_incomplete = FALSE)
check("A: clean run has 64 rows", nrow(res_a) == 64L)
check("A: clean run ids match manifest order exactly",
      identical(as.character(res_a$image_id), as.character(manifest$image_id)))
check("A: atomic write leaves no temp file behind", !file.exists(paste0(csv_a, ".tmp")))

# ---- Scenario B: interrupted run checkpointed at image 32 -------------------
work_b <- file.path(tempdir(), "hpa_ckpt_test_resume")
unlink(work_b, recursive = TRUE)
dir.create(work_b, recursive = TRUE)
csv_b <- file.path(work_b, "results.csv")
mode_b <- file.path(work_b, "checkpoint_mode.txt")

invisible(hpa_checkpoint_state(mode_b, csv_b, "pixel_fallback_v1"))
interrupted_at <- 32L
partial <- hpa_merge_checkpoint(data.table(),
                                compute_mock(manifest$image_id[seq_len(interrupted_at)]),
                                manifest)
hpa_atomic_fwrite(partial, csv_b)
check("B: interrupted checkpoint holds exactly 32 rows",
      nrow(fread(csv_b)) == interrupted_at)
# (simulated crash: nothing is written back to the in-memory session)

# ---- Scenario C: resume computes only images 33-64 --------------------------
state_c <- hpa_checkpoint_state(mode_b, csv_b, "pixel_fallback_v1")
check("C: matching mode resumes", state_c$action == "resume")
existing_c <- hpa_validate_checkpoint(fread(csv_b), manifest)
done_ids <- existing_c$image_id
check("C: resume sees exactly the 32 checkpointed ids",
      setequal(done_ids, manifest$image_id[seq_len(interrupted_at)]) &&
        length(done_ids) == interrupted_at)
remaining <- setdiff(manifest$image_id, done_ids)
check("C: resume computes only the remaining 32 images", length(remaining) == 32L)
accumulated_c <- existing_c
for (id in remaining) {
  accumulated_c <- hpa_merge_checkpoint(accumulated_c, mock_row(manifest[image_id == id]), manifest)
  hpa_atomic_fwrite(accumulated_c, csv_b)
}
res_c <- hpa_merge_checkpoint(data.table(), accumulated_c, manifest,
                              allow_incomplete = FALSE)
check("C: resumed run has exactly 64 rows", nrow(res_c) == 64L)
check("C: resumed run has 64 unique image ids", uniqueN(res_c$image_id) == 64L)
check("C: no missing ids",
      setequal(as.character(res_c$image_id), as.character(manifest$image_id)))
check("C: no duplicate ids", !anyDuplicated(res_c$image_id))
check("C: row order matches manifest",
      identical(as.character(res_c$image_id), as.character(manifest$image_id)))

# Core acceptance: interrupted-then-resumed output == clean-run output.
check("C: resumed table equals clean table (in-memory)",
      isTRUE(all.equal(res_c, res_a, check.attributes = TRUE)))
csv_a_final <- file.path(work_a, "final.csv")
csv_b_final <- file.path(work_b, "final.csv")
hpa_atomic_fwrite(res_a, csv_a_final)
hpa_atomic_fwrite(res_c, csv_b_final)
check("C: resumed checkpoint bytes identical to clean-run checkpoint",
      identical(readLines(csv_a_final, warn = FALSE),
                readLines(csv_b_final, warn = FALSE)))

# ---- Scenario D: duplicate checkpoint image_ids must FAIL -------------------
dup_prev <- rbind(compute_mock(manifest$image_id[1:5]),
                  compute_mock(manifest$image_id[3]))  # IMG_003 twice
expect_error("D: duplicate checkpoint ids fail validation",
             hpa_validate_checkpoint(dup_prev, manifest),
             "duplicate image_id")
expect_error("D: duplicate ids fail the merge too",
             hpa_merge_checkpoint(dup_prev,
                                  compute_mock(manifest$image_id[6:10]), manifest),
             "Duplicate image_id")

# ---- Scenario E: checkpoint image_id outside the manifest must FAIL ---------
foreign_prev <- compute_mock(manifest$image_id[1:5])
foreign_prev[2, image_id := "IMG_NOT_IN_MANIFEST"]
expect_error("E: foreign checkpoint id fails validation",
             hpa_validate_checkpoint(foreign_prev, manifest),
             "absent from the current manifest")
expect_error("E: foreign id fails the merge too",
             hpa_merge_checkpoint(data.table(), foreign_prev, manifest),
             "absent from the current manifest")

# ---- Scenario F: checkpoint mode change invalidates and restarts ------------
invisible(hpa_checkpoint_state(mode_b, csv_b, "pixel_fallback_v1"))
check("F: checkpoint exists before mode change", file.exists(csv_b))
state_f <- hpa_checkpoint_state(mode_b, csv_b, "pixel_fallback_v2")
check("F: changed mode forces restart", state_f$action == "restart")
check("F: stale checkpoint removed on mode change", !file.exists(csv_b))
check("F: mode marker rewritten to the new mode",
      readLines(mode_b, warn = FALSE)[1L] == "pixel_fallback_v2")

# ---- Scenario G: malformed checkpoints fail clearly -------------------------
garbage_cols <- data.table(image_id = c("IMG_001", "IMG_002"), gene = c("G", "G"))
expect_error("G: checkpoint missing required columns fails",
             hpa_validate_checkpoint(garbage_cols, manifest),
             "missing required columns")
bad_numeric <- compute_mock(manifest$image_id[1:3])
bad_numeric[, cell_count := as.character(cell_count)]
bad_numeric[2, cell_count := "many cells"]  # keep the raw malformed string in the column
expect_error("G: malformed numeric cell fails",
             hpa_validate_checkpoint(bad_numeric, manifest),
             "malformed numeric value")
bad_tier <- compute_mock(manifest$image_id[1:3])
bad_tier[1, gt_tier_num := 7L]
expect_error("G: out-of-range tier fails",
             hpa_validate_checkpoint(bad_tier, manifest),
             "outside 0-3")
expect_error("G: empty checkpoint fails",
             hpa_validate_checkpoint(data.table(), manifest),
             "empty or unreadable")
empty_ids <- compute_mock(manifest$image_id[1:2])
empty_ids[1, image_id := ""]
expect_error("G: empty image_id fails",
             hpa_validate_checkpoint(empty_ids, manifest),
             "empty or NA image_id")
incomplete <- compute_mock(manifest$image_id[1:10])
expect_error("G: incomplete final merge fails",
             hpa_merge_checkpoint(data.table(), incomplete, manifest,
                                  allow_incomplete = FALSE),
             "do not cover the manifest exactly")

if (length(failures)) {
  cat(sprintf("\nFAIL: HPA checkpoint/resume regression (%d failure(s))\n",
              length(failures)))
  quit(status = 1L)
}
cat("\nPASS: HPA checkpoint/resume regression (interrupted-then-resumed == clean run)\n")
