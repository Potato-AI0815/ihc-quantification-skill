# Stable Readiness Report — Post-RC3 Stable-Preparation Cleanup

**Date**: 2026-08-29
**Scope**: post-`v2.3.0-rc3` non-algorithmic cleanup + regression validation on `main`
**Recommendation**: **READY_FOR_FINAL_STABLE_REVIEW**

## 1. Commit & CI provenance

| Item | Value |
|---|---|
| Immutable released tag | `v2.3.0-rc3` → `b025b3805800dbf1f6d3850e881a40c8e6ebac71` (re-verified via `git rev-list -n 1 v2.3.0-rc3` and the GitHub API; tag untouched by this work) |
| rc3 exact-tag CI | run [33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913) — `success` at `b025b380` (verified) |
| rc3 exact-main CI | run [33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218) — `success` at `b025b380` (verified) |
| Historical baseline | `v2.3.0-rc2` / `8099297a6b64b975e2845aabff6c08f6ca2d8efe` (superseded) |
| Post-rc3 cleanup commit | the `main` commit that introduces this report (single-commit cleanup; SHA and its exact-SHA CI conclusion are recorded in the stable-review audit handoff — the report is frozen inside the commit it describes so the cleanup stays one commit) |
| Post-rc3 release actions | none: no stable tag, no stable GitHub release, no force push, no tag movement |

## 2. Gate statuses carried into stable review

| Benchmark | Gate status | Key values |
|---|---|---|
| BBBC007 (manual GT segmentation, Level A) | `PASS_WITH_WARNINGS` | Nucleus F1 0.7781; 58.8% boundary within 2 px; median boundary distance 2.7257 px |
| BBBC013 (real N/C translocation, Level B) | `PASS` | Wortmannin ρ = +0.884; LY294002 ρ = +0.903; both positive-control shifts correct |
| BBBC016 (real puncta dose association, Level B) | `PASS_WITH_WARNINGS` | puncta/cell ρ = 0.3720; integrated puncta intensity ρ = 0.6254 (values unchanged by this cleanup) |
| HPA DAB-IHC (qualitative ordinal grading, Level B) | `PASS_WITH_WARNINGS` | P95 OD ρ = 0.7058; mean OD ρ = 0.6340; H-Score ρ = 0.5901; ESR1 ρ = 0.4972 kept visible |

## 3. Regression validation results

| Check | Result |
|---|---|
| Core algorithm drift vs `v2.3.0-rc3` (`if_segmentation.R`, `if_quantification_helpers.R`, `if_puncta.R`, `if_preprocessing.R`, `run_ihc_quantification.R`, `run_if_quantification.R`, `ihc_helpers.R`) | **Zero diff** (byte-identical, including the version constant) |
| DAB backward compatibility (`tests/verify_backward_compatibility.R`) | **PASS** (11 tables, Δ ≤ 1e-6; observed Δ = 0) |
| BBBC039 validation-partition regression (`tests/verify_bbbc039_benchmark.R`) | **PASS** |
| IF I/O bit-depth contract (`scripts/verify_if_io_bitdepth_contract.R`) | **PASS_PRESERVED** |
| Synthetic dual-modality smoke test (`tests/run_synthetic_smoke_test.sh`) | **PASS** (macOS/R 4.x; Windows coverage delegated to GitHub Actions as usual) |
| HPA checkpoint/resume regression (`tests/verify_hpa_checkpoint_resume.R`) | **PASS** — 32/32 checks: interrupted-at-32 resumed output equals the clean 64-image run in memory and byte-for-byte; duplicate-id, foreign-id, malformed-checkpoint, mode-change and incomplete-coverage paths all fail loudly |
| Real-data resume proof | an interrupted real run (checkpoint at image 8) was resumed with the fixed logic; the final `HPA_IHC_REALDATA_RESULTS.csv` is **byte-identical** to the released rc3 evidence, and every summary metric is unchanged |
| Report consistency gate (`scripts/verify_report_consistency.py`) | **PASS** — numeric agreement plus new terminology/wording/badge guards |
| Summary generator determinism (`tests/verify_summary_generator_determinism.py`) | **PASS** — byte-identical rebuilds; report date sourced from `external_validation/VALIDATION_METADATA.json` |
| Static package validation / privacy preflight / manifest verification | **PASS / PASS / PASS** (manifest regenerated last) |

## 4. Fixes contained in this cleanup

1. **IF terminology**: "integrated puncta OD" eliminated repo-wide; IF puncta metrics are now "integrated puncta intensity". DAB OD terminology unchanged; BBBC016 measured values unchanged.
2. **HPA checkpoint/resume data-loss bug**: previously checkpointed rows were dropped from the final table on resume. Resume now validates the checkpoint (schema, unique/known image_ids, numeric sanity), merges explicitly in manifest order with hard duplicate/foreign-id failures, writes checkpoints atomically, and asserts exact manifest coverage before finishing.
3. **HPA scientific wording**: calibrated to "overall moderate-to-strong ordinal concordance with substantial marker-specific heterogeneity"; the weak ESR1 result (ρ = 0.4972) stays visible; "scale-invariant" over-claim removed in favour of the precise no-physical-scale statement; non-diagnostic / non-pixel-level / cross-tissue heterogeneity scoping explicit; CC BY 4.0 provenance retained.
4. **README/README_EN**: rc3 release badge with direct tag link, external real-data validation overview (statuses quoted from the matrix), validation entry points repointed to `RELEASE_STATUS.md` / `EXTERNAL_REALDATA_VALIDATION_REPORT.md` / `EXTERNAL_VALIDATION_MATRIX.csv`; rc1-era gate matrices marked as archived history.
5. **Provenance/status metadata**: `CI_PROVENANCE_REPORT.md` and `RELEASE_STATUS.md` rewritten to the released rc3 lineage (historical rc2 baseline separated from the immutable rc3 candidate and the moving post-rc3 `main`); `CITATION.cff` release date corrected to the actual GitHub publish date (2026-08-29).
6. **Deterministic report build**: no wall-clock dates in the summary generator; validation date/milestone come from `external_validation/VALIDATION_METADATA.json`.
7. **Stronger CI gates**: IF-OD terminology ban, HPA wording guards, README badge/VERSION agreement, generator determinism test, and the HPA checkpoint/resume regression are all enforced in CI.

## 5. Remaining warnings (unchanged from rc3, disclosed)

- OME-TIFF metadata workflows remain experimental (G1 `PASS_WITH_WARNINGS`).
- BBBC007 external accuracy stays at warning level (58.8% boundary within 2 px) — real benchmark result, not tuned.
- HPA concordance is qualitative ordinal grading across heterogeneous tissues/antibodies; ESR1 remains weak (ρ = 0.4972); no pixel-size calibration exists for HPA images (pixel-fallback mode).
- BBBC016 per-cell association is moderate (ρ = 0.372) — reported as measured.
- No stable tag/release is created in this state; `2.3.0` remains blocked until the final stable review.
