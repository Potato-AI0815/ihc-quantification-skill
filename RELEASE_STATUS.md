# Release Status — IHC & Immunofluorescence Quantification Skill

**Current Version**: `2.3.1`
**Release state**: `STABLE RELEASE CANDIDATE — exact-SHA CI required before tagging`
**Canonical stable target**: `v2.3.1` (no `v2.3.1` tag/release claim is made in this state)
**Withdrawn historical release**: `v2.3.0` — tag commit `708a976af38a4ed78fa59850294de3da6cb8ee18`; GitHub Release marked `WITHDRAWN / SUPERSEDED`; tag preserved for provenance and not moved, deleted, or recreated.
**Immutable validation candidate**: `v2.3.0-rc3` — **RELEASED AS GITHUB PRE-RELEASE** ([release page](https://github.com/Potato-AI0815/ihc-quantification-skill/releases/tag/v2.3.0-rc3), published 2026-08-29)
**Release tag commit**: `b025b3805800dbf1f6d3850e881a40c8e6ebac71` (immutable; verified via `git rev-list -n 1 v2.3.0-rc3` and the GitHub API)
**Exact tag CI**: Actions run [33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913) — `success` at `b025b380`
**Exact rc3 main CI**: Actions run [33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218) — `success` at `b025b380`
**v2.3.1 release gate**: exact-SHA `main` CI and exact-tag CI must both pass before a `v2.3.1` stable tag and GitHub Release are created. The tag-version contract (`scripts/verify_tag_version.py`) is enforced in CI.

> [!IMPORTANT]
> **Release identity correction**: `v2.3.0` is preserved as historical
> provenance but is **not** the canonical stable release. Its tagged commit
> still identified the package internally as `2.3.0-rc3`. Use `v2.3.1` or
> later. Scientific calculations and validation results are unaffected.
>
> **Known limitation**: OME-TIFF metadata workflows are not yet formally validated. Standard multi-channel TIFF, ImageJ hyperstacks, and 8/16/32-bit (plus 12-bit in 16-bit container) data are fully verified and supported.

---

## 1. Validation Gate Matrix Summary

| Gate ID | Gate Name | Modality | Status | Summary Metrics / Outcome |
| :--- | :--- | :--- | :--- | :--- |
| **G0** | DAB Baseline Audit | Brightfield DAB | **PASS** | 100% table and QC schema integrity verified |
| **G1** | IF Input & Bit-Depth I/O | IF | **PASS_WITH_WARNINGS** | Standard TIFF/ImageJ C/Z mapping and 8/16/32-bit plus 12-bit-in-16-bit-container values verified; OME-XML and packed native-12-bit remain experimental |
| **G2** | IF Preprocessing & Saturation | IF | **PASS** | Top-hat/Rolling Ball background, saturation QC alert |
| **G3** | IF Segmentation & Compartments | IF | **PASS** | Classical distance-watershed pipeline; 4 explicit measurement domains; reviewed ROI support |
| **G4** | Four-Domain IF Quantification | IF | **PASS** | Four compartments quantified with non-empty mapped target; empty-channel guard triggers NOT_EVALUABLE |
| **G5** | 8-Panel QC & Publication Plots | IF | **PASS** | Repaired 8-panel QC rendered; gray reviewed-ROI exclusion explicit; biological comparison plots |
| **G6** | Dual-Channel Colocalization | IF | **PASS** | Pearson: 0.852 vs -0.988, M1: 1.000 vs 0.023, M2: 1.000 vs 0.025; molecular binding disclaimer |
| **G7** | Puncta / Subcellular Foci | IF | **PASS_WITH_WARNINGS** | Validated synthetic puncta counting workflow: GT5=45->Det=43 (Err: 4.4%); GT15=135->Det=134 (Err: 0.7%); per-cell MAE = 0.17. Warning: no coordinate-level precision/recall/F1 ground truth exists for the fixture — closely spaced puncta can merge into single detections, so no universal single-molecule counting claim is supported |
| **G8** | Public Benchmark Validation | IF / nuclear segmentation | **PASS** | BBBC039 official 50-image validation split (segmented with the IF nuclear segmentation implementation): Dice=0.8953, IoU=0.8390, precision=0.9106, recall=0.8254, F1=0.8919, Count Err=13.0%; 1-to-1 instance matching |
| **G9** | DAB Backward Compatibility | Brightfield DAB | **PASS** | Clean v2.2.2 checkout comparison across all 11 baseline tables; exact structural/categorical agreement, observed numeric Δ = 0 (acceptance tolerance ≤ 1.0×10⁻⁶) |
| **G10**| Cross-Platform CI Matrix | Both | **PASS** | Exact public release-candidate commit `b025b3805800dbf1f6d3850e881a40c8e6ebac71` passed static (incl. external report consistency gate and privacy preflight), Ubuntu, Windows, and IF I/O contract jobs in exact-tag Actions run [33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913) and exact-main run [33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218) for `v2.3.0-rc3` (historical rc2 evidence: run [32791143505](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/32791143505) at `8099297a`) |

---

## 2. Release Identity Correction

- **Historical release**: `v2.3.0` tag points at commit `708a976af38a4ed78fa59850294de3da6cb8ee18`.
- **Mismatch**: that commit's `VERSION`, `DESCRIPTION`, `CITATION.cff`, and `SKILL.md` all identify `2.3.0-rc3` while the tag/Release claimed `v2.3.0 stable`.
- **Action**: the `v2.3.0` GitHub Release body was edited to state `WITHDRAWN / SUPERSEDED` and `DO NOT USE AS CANONICAL STABLE RELEASE`; it is marked prerelease. The tag itself is unchanged.
- **Canonical replacement**: `v2.3.1`.
- **Scientific scope**: analytical behavior, DAB 11-table compatibility, and external-validation metrics are unchanged.

---

## 3. Evidence Index

### Current evidence (active claims)

- [`EXTERNAL_REALDATA_VALIDATION_REPORT.md`](EXTERNAL_REALDATA_VALIDATION_REPORT.md) — generated deterministically
- [`EXTERNAL_VALIDATION_MATRIX.csv`](EXTERNAL_VALIDATION_MATRIX.csv) — generated deterministically
- [`STABLE_READINESS_REPORT.md`](STABLE_READINESS_REPORT.md)
- [`CI_PROVENANCE_REPORT.md`](CI_PROVENANCE_REPORT.md)
- [`COLOCALIZATION_VALIDATION_REPORT.md`](COLOCALIZATION_VALIDATION_REPORT.md) — CURRENT GENERATED EVIDENCE (regenerated by `tests/verify_if_advanced_modules.R` in every smoke test)
- [`PUNCTA_VALIDATION_REPORT.md`](PUNCTA_VALIDATION_REPORT.md) — CURRENT GENERATED EVIDENCE (source of truth for gate G7)
- [`RUNTIME_VALIDATION_SUMMARY.md`](RUNTIME_VALIDATION_SUMMARY.md), [`RUNTIME_COMPATIBILITY.md`](RUNTIME_COMPATIBILITY.md), [`PUBLIC_RELEASE_PREFLIGHT.md`](PUBLIC_RELEASE_PREFLIGHT.md), [`PUBLIC_RELEASE_AUDIT.md`](PUBLIC_RELEASE_AUDIT.md) — current release-facing policy/state
- [`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md) + [`docs/assets/public_validation/provenance.csv`](docs/assets/public_validation/provenance.csv) — bundled public-derived asset licensing

### Historical (archived) validation evidence

These files record decisions and gate snapshots that were current when written;
they are retained for provenance and are NOT current release claims.

- [`VALIDATION_CLOSEOUT_REPORT.md`](VALIDATION_CLOSEOUT_REPORT.md)
- [`IF_IO_VALIDATION_REPORT.md`](IF_IO_VALIDATION_REPORT.md) / [`IF_IO_VALIDATION_FINAL.md`](IF_IO_VALIDATION_FINAL.md) (regenerated by the I/O contract test; last regenerated at the current validation date)
- [`IF_VALIDATION_REPORT.md`](IF_VALIDATION_REPORT.md), [`IF_UPGRADE_AUDIT.md`](IF_UPGRADE_AUDIT.md), [`IF_RUNTIME_REPAIR_REPORT.md`](IF_RUNTIME_REPAIR_REPORT.md) (alpha-era snapshots)
- [`SEGMENTATION_BENCHMARK_REPORT.md`](SEGMENTATION_BENCHMARK_REPORT.md) / [`BBBC039_SEGMENTATION_BENCHMARK_FINAL.md`](BBBC039_SEGMENTATION_BENCHMARK_FINAL.md) / [`benchmark_bbbc039_results.csv`](benchmark_bbbc039_results.csv) (last full benchmark run 2026-08-28; regenerated by `scripts/benchmark_bbbc039_segmentation.R`)
- [`RC1_BASELINE_REPORT.md`](RC1_BASELINE_REPORT.md), [`RC1_READINESS_REPORT.md`](RC1_READINESS_REPORT.md), [`GATE_MATRIX_RC1_FINAL.csv`](GATE_MATRIX_RC1_FINAL.csv) (rc1-era snapshots)
- [`GATE_MATRIX_FINAL.csv`](GATE_MATRIX_FINAL.csv) (historical rc1-era snapshot despite the generic filename)
- [`docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md`](docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md) (current decision lives in [`FINAL_RELEASE_DECISION.md`](FINAL_RELEASE_DECISION.md))
- [`BACKWARD_COMPATIBILITY_REPORT.md`](BACKWARD_COMPATIBILITY_REPORT.md) / [`BACKWARD_COMPATIBILITY_REPORT_FINAL.md`](BACKWARD_COMPATIBILITY_REPORT_FINAL.md) (v2.2.2 baseline compatibility snapshots)
- [`segmentation_benchmark.csv`](segmentation_benchmark.csv) (per-image table of the 2026-08-28 benchmark run)
- [`RELEASE_NOTES_v2.3.0-rc1.md`](RELEASE_NOTES_v2.3.0-rc1.md)
