# Stable Readiness Report — Post-RC3 Stable-Preparation Cleanup

**Date**: 2026-08-29
**Scope**: post-`v2.3.0-rc3` non-algorithmic cleanup + regression validation on `main`
**Recommendation**: **READY_FOR_FINAL_STABLE_REVIEW**

## 1. Commit & CI provenance

| Item | Value |
|---|---|
| Immutable released tag | `v2.3.0-rc3` → `b025b3805800dbf1f6d3850e881a40c8e6ebac71` (re-verified via `git rev-list -n 1 v2.3.0-rc3` and the GitHub API; tag untouched by stable-prep work) |
| rc3 exact-tag CI | run [33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913) — `success` at `b025b380` (verified) |
| rc3 historical same-SHA main CI | run [33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218) — `success` at `b025b380` (verified) |
| Historical baseline | `v2.3.0-rc2` / `8099297a6b64b975e2845aabff6c08f6ca2d8efe` (superseded) |
| Post-RC3 stable-prep main | multiple non-algorithmic hardening commits after the rc3 tag (lineage below); the final stable-prep SHA and its exact-SHA CI run are populated only after push and successful exact-SHA verification — recorded in the stable-release audit handoff, not hardcoded here, so closing out the release does not create a new tracked-file revision requiring yet another CI run |
| Post-rc3 release actions | none: no stable tag, no stable GitHub release, no force push, no tag movement |

### Post-RC3 lineage

| Commit | Purpose |
|---|---|
| `b025b380` | `v2.3.0-rc3` — immutable released tag (validation-layer corrections, re-run) |
| `7e28d7ed` | `fix(stable-prep): harden rc3 validation provenance and resume contracts` |
| `e23bd40f` | `fix(stable-prep): bootstrap CI Rlib in HPA resume regression test` |
| `257e2bf0` | `fix(stable-prep): harden cross-platform HPA checkpoint recovery` |
| `e5ad231f` | `fix(stable-prep): normalize release evidence and public asset provenance` (current `main` HEAD at the time of this report) |

All post-rc3 commits are non-algorithmic: documentation, validation scripts,
reporting generators, report-consistency tests, metadata, checkpoint/resume
implementation, and CI validation logic. `git diff v2.3.0-rc3 -- <frozen
analysis scripts>` shows no analytical behavior change: the only differences
in the frozen analysis files are non-executable, version-neutral header
comments (release version strings removed from source headers).

## 2. Gate statuses carried into stable review

| Benchmark | Gate status | Key values |
|---|---|---|
| BBBC007 (manual GT segmentation, Level A) | `PASS_WITH_WARNINGS` | Nucleus F1 0.7781; 58.8% boundary within 2 px; median boundary distance 2.7257 px |
| BBBC013 (real N/C translocation, Level B) | `PASS` | Wortmannin ρ = +0.884 (plate-wide positive-control reference at 150 nM above negatives); LY294002 ρ = +0.903 (80 µM maximum-dose reference above negatives) |
| BBBC016 (real puncta dose association, Level B) | `PASS_WITH_WARNINGS` | puncta/cell ρ = 0.3720; integrated puncta intensity ρ = 0.6254 (values unchanged by this cleanup) |
| HPA DAB-IHC (qualitative ordinal grading, Level B) | `PASS_WITH_WARNINGS` | P95 OD ρ = 0.7058; mean OD ρ = 0.6340; H-Score ρ = 0.5901; ESR1 ρ = 0.4972 kept visible |

## 3. Regression validation results

| Check | Result |
|---|---|
| Core algorithm drift vs `v2.3.0-rc3` (`if_segmentation.R`, `if_quantification_helpers.R`, `if_puncta.R`, `if_preprocessing.R`, `if_colocalization.R`, `if_qc_helpers.R`, `run_ihc_quantification.R`, `run_if_quantification.R`, `ihc_helpers.R`) | **No analytical behavior change** — the only diffs are non-executable version-neutral header comments (7 of 9 files, one line each) |
| DAB backward compatibility (`tests/verify_backward_compatibility.R`) | **PASS** (11 tables, Δ ≤ 1e-6; observed Δ = 0) |
| BBBC039 validation-partition regression (`tests/verify_bbbc039_benchmark.R`) | **PASS** |
| IF I/O bit-depth contract (`scripts/verify_if_io_bitdepth_contract.R`) | **PASS_PRESERVED** |
| Synthetic dual-modality smoke test (`tests/run_synthetic_smoke_test.sh`) | **PASS** (macOS/R 4.x; Windows coverage delegated to GitHub Actions as usual) |
| HPA checkpoint/resume regression (`tests/verify_hpa_checkpoint_resume.R`) | **PASS** — 34/34 checks across scenarios A–H: interrupted-at-32 resumed output equals the clean 64-image run in memory and byte-for-byte; duplicate-id, foreign-id, malformed-checkpoint, incomplete-coverage, mode-change, and marker-present/checkpoint-missing paths all fail safely and loudly |
| Real-data resume proof | an interrupted real run (checkpoint at image 8) was resumed with the fixed logic; the final `HPA_IHC_REALDATA_RESULTS.csv` is **byte-identical** to the released rc3 evidence, and every summary metric is unchanged |
| Report consistency gate (`scripts/verify_report_consistency.py`) | **PASS** — numeric agreement plus new terminology/wording/badge guards |
| Summary generator determinism (`tests/verify_summary_generator_determinism.py`) | **PASS** — byte-identical rebuilds; report date sourced from `external_validation/VALIDATION_METADATA.json` |
| Static package validation / privacy preflight / manifest verification | **PASS / PASS / PASS** (manifest regenerated last) |

## 4. Fixes contained in this cleanup

1. **IF terminology**: "integrated puncta OD" eliminated repo-wide; IF puncta metrics are now "integrated puncta intensity". DAB OD terminology unchanged; BBBC016 measured values unchanged.
2. **HPA checkpoint/resume data-loss bug**: previously checkpointed rows were dropped from the final table on resume. Resume now validates the checkpoint (schema, unique/known image_ids, numeric sanity), merges explicitly in manifest order with hard duplicate/foreign-id failures, writes checkpoints via temporary-file replacement (atomic on POSIX; failure-safe with clean-restart semantics on Windows), and asserts exact manifest coverage before finishing.
3. **HPA missing-checkpoint edge case**: resume requires the mode marker to match AND the checkpoint file to be present. If the process dies inside the Windows remove/rename replacement window (marker survives, checkpoint gone), the next startup restarts cleanly instead of attempting an invalid `fread`; no phantom checkpoint is created.
4. **HPA scientific wording**: calibrated to "overall moderate-to-strong ordinal concordance with substantial marker-specific heterogeneity"; the weak ESR1 result (ρ = 0.4972) stays visible; "scale-invariant" over-claim removed in favour of the precise no-physical-scale statement; non-diagnostic / non-pixel-level / cross-tissue heterogeneity scoping explicit; CC BY 4.0 provenance retained.
5. **README/README_EN**: rc3 release badge with direct tag link, external real-data validation overview (statuses quoted from the matrix), validation entry points repointed to `RELEASE_STATUS.md` / `EXTERNAL_REALDATA_VALIDATION_REPORT.md` / `EXTERNAL_VALIDATION_MATRIX.csv`; rc1-era gate matrices marked as archived history.
6. **Provenance/status metadata**: `CI_PROVENANCE_REPORT.md` and `RELEASE_STATUS.md` rewritten to the released rc3 lineage (historical rc2 baseline separated from the immutable rc3 candidate and the moving post-rc3 `main`); `CITATION.cff` release date corrected to the actual GitHub publish date (2026-08-29).
7. **Deterministic report build**: no wall-clock dates in the summary generator; validation date/milestone come from `external_validation/VALIDATION_METADATA.json`.
8. **Stronger CI gates**: IF-OD terminology ban, HPA wording guards, README badge/VERSION agreement, generator determinism test, and the HPA checkpoint/resume regression are all enforced in CI.

## 5. Remaining warnings (unchanged from rc3, disclosed)

- OME-TIFF metadata workflows remain experimental (G1 `PASS_WITH_WARNINGS`).
- BBBC007 external accuracy stays at warning level (58.8% boundary within 2 px) — real benchmark result, not tuned.
- HPA concordance is qualitative ordinal grading across heterogeneous tissues/antibodies; ESR1 remains weak (ρ = 0.4972); no pixel-size calibration exists for HPA images (pixel-fallback mode).
- BBBC016 per-cell association is moderate (ρ = 0.372) — reported as measured.
- No stable tag/release is created in this state; `2.3.0` remains blocked until the final stable review.
