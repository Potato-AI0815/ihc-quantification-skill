# Release Status — IHC & Immunofluorescence Quantification Skill

**Current Version**: `2.3.2`
**Release state**: `PRE_RELEASE_READINESS` — scientific-contract hotfix candidate; no `v2.3.2` tag or GitHub Release exists in this commit.
**Current canonical stable**: `v2.3.1` (tag `5f9cd52ddc32c7233180680e3623af3dd6e9f009`; [GitHub Release](https://github.com/Potato-AI0815/ihc-quantification-skill/releases/tag/v2.3.1); `prerelease = false`)
**Withdrawn historical release**: `v2.3.0` (tag `708a976af38a4ed78fa59850294de3da6cb8ee18`); release body marked `WITHDRAWN / SUPERSEDED`; tag preserved.
**Immutable validation candidate**: `v2.3.0-rc3` (tag `b025b3805800dbf1f6d3850e881a40c8e6ebac71`)

## POST_RELEASE_AUDIT — v2.3.1 (facts that existed only after release)

- Canonical stable commit: `5f9cd52ddc32c7233180680e3623af3dd6e9f009`
- Exact-SHA main CI: run [33504060489](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33504060489) — `success`
- Exact-tag CI: run [33505086731](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33505086731) — `success`
- tag-version-contract: `PASS tag-version-contract 2.3.1 == 2.3.1`
- Archive: `ihc-quantification-skill_v2.3.1.zip`; SHA256 `d1799d611f7945f0eb45a8dedd26eb7b7e9ae3ba0429abdb88aeadfe268a6f53`
- This information is recorded here after release and is not used to revise the immutable `v2.3.1` tagged commit.

## PRE_RELEASE_READINESS — v2.3.2

- Scope: physical-scale contract hotfix and colocalization production QC enforcement. No new features and no DAB analytical change.
- P0 physical-scale contract: missing/`NA`/non-finite/`<=0` `pixel_size_um` now means `scale_mode = pixel_fallback`; all `*_um2` / `*_per_um2` outputs are `NA`; `MISSING_PIXEL_SIZE_CALIBRATION` is recorded. `1 px = 1 um` is never assumed.
- P1 colocalization production QC: production `compute_if_colocalization()` now gates pixel count, dynamic range, and registration before Pearson/Manders interpretation; blocked rows have `NA` metrics.
- `v2.3.2` tag and GitHub Release are not claimed in this commit. They may be created only after exact-SHA main CI and (if release is authorized) exact-tag CI.

---

## 1. Validation Gate Matrix Summary

| Gate ID | Gate Name | Modality | Status | Summary Metrics / Outcome |
| :--- | :--- | :--- | :--- | :--- |
| **G0** | DAB Baseline Audit | Brightfield DAB | **PASS** | 100% table and QC schema integrity verified |
| **G1** | IF Input & Bit-Depth I/O | IF | **PASS_WITH_WARNINGS** | Standard TIFF/ImageJ C/Z mapping and 8/16/32-bit plus 12-bit-in-16-bit-container values verified; OME-XML and packed native-12-bit remain experimental |
| **G2** | IF Preprocessing & Saturation | IF | **PASS** | Top-hat/Rolling Ball background, saturation QC |
| **G3** | IF Segmentation & Compartments | IF | **PASS** | Classical distance-watershed pipeline; 4 explicit measurement domains; reviewed ROI support |
| **G4** | Four-Domain IF Quantification | IF | **PASS** | Four compartments quantified with non-empty mapped target; empty-channel guard triggers NOT_EVALUABLE |
| **G5** | 8-Panel QC & Publication Plots | IF | **PASS** | Repaired 8-panel QC rendered; gray reviewed-ROI exclusion explicit; biological comparison plots |
| **G6** | Dual-Channel Colocalization | IF | **PASS** | Production QC now gates pixel count, dynamic range, and registration; aligned fixtures produce Pearson: 0.852 vs -0.988, M1: 1.000 vs 0.023, M2: 1.000 vs 0.025; misregistered/low-dynamic/low-pixel fixtures are `NOT_EVALUABLE` with `NA` metrics |
| **G7** | Puncta / Subcellular Foci | IF | **PASS_WITH_WARNINGS** | Validated synthetic puncta counting workflow: GT5=45->Det=43 (Err: 4.4%); GT15=135->Det=134 (Err: 0.7%); per-cell MAE = 0.17. No coordinate-level precision/recall/F1 ground truth exists for the fixture |
| **G8** | Public Benchmark Validation | IF / nuclear segmentation | **PASS** | BBBC039 official 50-image validation split: Dice=0.8953, IoU=0.8390, precision=0.9106, recall=0.8254, F1=0.8919, Count Err=13.0%; 1-to-1 instance matching |
| **G9** | DAB Backward Compatibility | Brightfield DAB | **PASS** | Clean v2.2.2 checkout comparison across all 11 baseline tables; exact structural/categorical agreement, observed numeric Δ = 0 (acceptance tolerance ≤ 1.0×10⁻⁶) |
| **G10**| Cross-Platform CI Matrix | Both | **v2.3.1 PASS; v2.3.2 PENDING** | `v2.3.1` exact-tag run [33505086731](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33505086731) and main run [33504060489](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33504060489) are `success`. The v2.3.2 main CI run will be recorded only after it exists. |

---

## 2. Evidence Index

### Current evidence (active claims)

- [`EXTERNAL_REALDATA_VALIDATION_REPORT.md`](EXTERNAL_REALDATA_VALIDATION_REPORT.md) — generated deterministically
- [`EXTERNAL_VALIDATION_MATRIX.csv`](EXTERNAL_VALIDATION_MATRIX.csv) — generated deterministically
- [`STABLE_READINESS_REPORT.md`](STABLE_READINESS_REPORT.md)
- [`CI_PROVENANCE_REPORT.md`](CI_PROVENANCE_REPORT.md)
- [`COLOCALIZATION_VALIDATION_REPORT.md`](COLOCALIZATION_VALIDATION_REPORT.md) — CURRENT GENERATED EVIDENCE
- [`PUNCTA_VALIDATION_REPORT.md`](PUNCTA_VALIDATION_REPORT.md) — CURRENT GENERATED EVIDENCE (source of truth for gate G7)
- [`RUNTIME_VALIDATION_SUMMARY.md`](RUNTIME_VALIDATION_SUMMARY.md), [`RUNTIME_COMPATIBILITY.md`](RUNTIME_COMPATIBILITY.md), [`PUBLIC_RELEASE_PREFLIGHT.md`](PUBLIC_RELEASE_PREFLIGHT.md), [`PUBLIC_RELEASE_AUDIT.md`](PUBLIC_RELEASE_AUDIT.md) — current release-facing policy/state
- [`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md) + [`docs/assets/public_validation/provenance.csv`](docs/assets/public_validation/provenance.csv) — bundled public-derived asset licensing

### Historical (archived) validation evidence

These files are retained for provenance and are NOT current release claims:

- [`VALIDATION_CLOSEOUT_REPORT.md`](VALIDATION_CLOSEOUT_REPORT.md)
- [`IF_IO_VALIDATION_REPORT.md`](IF_IO_VALIDATION_REPORT.md) / [`IF_IO_VALIDATION_FINAL.md`](IF_IO_VALIDATION_FINAL.md) (regenerated by the I/O contract test)
- [`IF_VALIDATION_REPORT.md`](IF_VALIDATION_REPORT.md), [`IF_UPGRADE_AUDIT.md`](IF_UPGRADE_AUDIT.md), [`IF_RUNTIME_REPAIR_REPORT.md`](IF_RUNTIME_REPAIR_REPORT.md) (alpha-era snapshots)
- [`SEGMENTATION_BENCHMARK_REPORT.md`](SEGMENTATION_BENCHMARK_REPORT.md) / [`BBBC039_SEGMENTATION_BENCHMARK_FINAL.md`](BBBC039_SEGMENTATION_BENCHMARK_FINAL.md)
- [`RC1_BASELINE_REPORT.md`](RC1_BASELINE_REPORT.md), [`RC1_READINESS_REPORT.md`](RC1_READINESS_REPORT.md), [`GATE_MATRIX_RC1_FINAL.csv`](GATE_MATRIX_RC1_FINAL.csv)
- [`GATE_MATRIX_FINAL.csv`](GATE_MATRIX_FINAL.csv) — historical snapshot despite the generic filename; banner added at top
- [`docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md`](docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md)
- [`BACKWARD_COMPATIBILITY_REPORT.md`](BACKWARD_COMPATIBILITY_REPORT.md) / [`BACKWARD_COMPATIBILITY_REPORT_FINAL.md`](BACKWARD_COMPATIBILITY_REPORT_FINAL.md) — historical v2.2.2 baseline snapshots; banner added at top
