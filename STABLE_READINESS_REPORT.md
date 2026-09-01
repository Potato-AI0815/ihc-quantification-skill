# Stable Readiness Report — v2.3.1 Release Identity Recovery

**Date**: 2026-08-31
**Scope**: release-provenance recovery from the mislabeled `v2.3.0` stable tag; no analytical work
**Recommendation**: **`APPROVED_FOR_STABLE_RELEASE_PENDING_EXACT_SHA_MAIN_CI_AND_TAG_CI`**

## 0. Release recovery explanation

| Item | Value |
|---|---|
| `v2.3.0` | historical **withdrawn** release identity; tag `708a976af38a4ed78fa59850294de3da6cb8ee18` is preserved, not moved or recreated |
| `v2.3.0` tag name | `v2.3.0` |
| `v2.3.0` internal metadata | `2.3.0-rc3` in `VERSION`, `DESCRIPTION`, `CITATION.cff`, and `SKILL.md` |
| Scientific calculations | **unaffected** |
| External validation | **unaffected** |
| Release identity | **inconsistent**, therefore `v2.3.0` is not canonical |
| Canonical replacement | **`v2.3.1`** |

## 1. Commit & CI provenance

| Item | Value |
|---|---|
| Immutable validation tag | `v2.3.0-rc3` -> `b025b3805800dbf1f6d3850e881a40c8e6ebac71` (re-verified via `git rev-list -n 1 v2.3.0-rc3` and the GitHub API; tag untouched) |
| rc3 exact-tag CI | run [33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913) — `success` at `b025b380` |
| rc3 historical same-SHA main CI | run [33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218) — `success` at `b025b380` |
| Historical baseline | `v2.3.0-rc2` / `8099297a6b64b975e2845aabff6c08f6ca2d8efe` (superseded) |
| Withdrawn release | `v2.3.0` / `708a976af38a4ed78fa59850294de3da6cb8ee18` (preserved; GitHub Release body marked WITHDRAWN / SUPERSEDED) |
| Canonical stable target | `v2.3.1`; final SHA and exact-SHA CI/tag CI are recorded only after successful verification, not hardcoded in this tracked file, so the tagged commit is never revised after tag CI |

## 2. Gate statuses carried into stable review

| Benchmark | Gate status | Key values |
|---|---|---|
| BBBC007 (manual GT segmentation, Level A) | `PASS_WITH_WARNINGS` | Nucleus F1 0.7781; 58.8% boundary within 2 px; median boundary distance 2.7257 px |
| BBBC013 (real N/C translocation, Level B) | `PASS` | Wortmannin rho = +0.884 (plate-wide positive-control reference at 150 nM above negatives); LY294002 rho = +0.903 (80 uM maximum-dose reference above negatives) |
| BBBC016 (real puncta dose association, Level B) | `PASS_WITH_WARNINGS` | puncta/cell rho = 0.3720; integrated puncta intensity rho = 0.6254 (values unchanged by this cleanup) |
| HPA DAB-IHC (qualitative ordinal grading, Level B) | `PASS_WITH_WARNINGS` | P95 OD rho = 0.7058; mean OD rho = 0.6340; H-Score rho = 0.5901; ESR1 rho = 0.4972 kept visible |

## 3. Regression validation results

| Check | Result |
|---|---|
| Core algorithm drift vs `v2.3.0-rc3` (`if_segmentation.R`, `if_quantification_helpers.R`, `if_puncta.R`, `if_preprocessing.R`, `if_colocalization.R`, `if_qc_helpers.R`, `run_ihc_quantification.R`, `run_if_quantification.R`, `ihc_helpers.R`) | **No analytical behavior change** — non-comment executable text is unchanged except the exact allow-listed release version constant in `ihc_helpers.R` |
| DAB backward compatibility (`tests/verify_backward_compatibility.R`) | **PASS** (11 tables, Delta <= 1e-6; observed Delta = 0) |
| BBBC039 validation-partition regression (`tests/verify_bbbc039_benchmark.R`) | **PASS** |
| IF I/O bit-depth contract (`scripts/verify_if_io_bitdepth_contract.R`) | **PASS_PRESERVED** |
| Synthetic dual-modality smoke test (`tests/run_synthetic_smoke_test.sh`) | **PASS** (macOS/R 4.x; Windows coverage delegated to GitHub Actions as usual) |
| HPA checkpoint/resume regression (`tests/verify_hpa_checkpoint_resume.R`) | **PASS** — 34/34 checks across scenarios A-H |
| Report consistency gate (`scripts/verify_report_consistency.py`) | **PASS** — numeric agreement plus terminology/wording/badge guards |
| Summary generator determinism (`tests/verify_summary_generator_determinism.py`) | **PASS** — byte-identical rebuilds |
| Static package validation / privacy preflight / manifest verification | **PASS / PASS / PASS** (manifest regenerated last) |
| Tag/internal release version contract (`scripts/verify_tag_version.py`) | **PASS** — all internal sources equal `VERSION`; tag events additionally require tag == VERSION |

## 4. Remaining warnings (unchanged from rc3, disclosed)

- OME-TIFF metadata workflows remain experimental (G1 `PASS_WITH_WARNINGS`).
- BBBC007 external accuracy stays at warning level (58.8% boundary within 2 px) — real benchmark result, not tuned.
- HPA concordance is qualitative ordinal grading across heterogeneous tissues/antibodies; ESR1 remains weak (rho = 0.4972); no pixel-size calibration exists for HPA images (pixel-fallback mode).
- BBBC016 per-cell association is moderate (rho = 0.372) — reported as measured.
- `v2.3.1` is a stable candidate in this tracked state; it becomes canonical only after exact-SHA main CI, exact-tag CI, and the GitHub stable Release are complete.
