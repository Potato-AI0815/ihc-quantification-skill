# Handover Report: IHC & IF Quantification Skill (v2.3.0-rc2 → v2.3.0-rc3 Transition)

**Date**: 2026-08-28  
**Repository**: `Potato-AI0815/ihc-quantification-skill`  
**Current Branch**: `bugfix/if-per-nucleus-propagation`  
**Current Git Commit**: `43fc7018da0f8fc06cc138ab7d3e9d295ac3d93d`  
**Current VERSION**: `2.3.0-rc2`  
**Target Release**: `v2.3.0-rc3`  
**Overall Status**: **FAIL FOR RC3 PROMOTION (Actionable Validation-Layer Refinements Required)**

---

## 1. Executive Summary & Review Verdict

A rigorous independent review of the external real-data validation bundle (`external_realdata_validation_review_bundle.zip`, SHA256: `09de2f356c695cccd7e8afe45cb571f2fecde2f1d21daaf303bc05ef01424c4a`) revealed that while the core algorithms and real-data computations are functional, **several validation-layer reporting discrepancies, plate layout misinterpretations, and methodological overclaims must be resolved before tagging `v2.3.0-rc3`**:

```
+------------------+------------------------------+-------------------------------------------------------------+
| Module           | Review Verdict               | Core Issues to Address                                     |
+------------------+------------------------------+-------------------------------------------------------------+
| BBBC007          | PASS_WITH_WARNINGS           | Separate structural invariants from empirical accuracy      |
| BBBC013          | FAIL / NEEDS CORRECTION      | Fix summary vs script contradiction; fix positive controls  |
| BBBC016          | PASS_WITH_WARNINGS           | Soften "monotonic recovery" to "positive dose association"  |
| HPA DAB-IHC      | PASS_WITH_MAJOR_WARNINGS     | Fix license (CC BY 4.0), remove unproven pixel_size=0.5     |
| Summary Report   | FAIL                         | Source-of-truth inconsistency; inject metrics automatically |
+------------------+------------------------------+-------------------------------------------------------------+
```

---

## 2. Hard Constraints (DO NOT VIOLATE)

1. **NO CORE ALGORITHM MODIFICATIONS**:
   - `scripts/if_segmentation.R`, `scripts/if_preprocessing.R`, `scripts/if_quantification_helpers.R`, `scripts/ihc_helpers.R`, `scripts/run_ihc_quantification.R`, `scripts/run_if_quantification.R` are **FROZEN**.
2. **NO PARAMETER TUNING / OVERFITTING**:
   - Do NOT tune thresholds, watershed parameters, or filter sizes to inflate external validation scores.
3. **DO NOT HIDE WEAK SIGNALS**:
   - ESR1 $\rho \approx 0.497$ and BBBC016 $\rho \approx 0.372$ are real biological results and must be retained transparently.
4. **MAINTAIN BACKWARD COMPATIBILITY**:
   - DAB backward compatibility against v2.2.2 baseline (`tests/verify_backward_compatibility.R`) must remain at $\Delta \le 10^{-6}$.

---

## 3. Specific Action Items by Module

### 3.1 BBBC013 (Critical Blocker — Dose-Response Translocation)
- **Biological Context**: Under PI3K/Akt inhibition (Wortmannin, LY294002), FKHR-EGFP translocates **from cytoplasm into the nucleus**. Thus, Nuclear/Cytoplasmic ($N/C$) ratio **increases** with dose (positive correlation).
- **Issue 1 (Metric Inconsistency)**:
  - `validate_bbbc013.R` and `BBBC013_NC_TRANSLOCATION_RESULTS.csv` found positive correlations: Wortmannin $\rho = +0.884$, LY294002 $\rho = +0.903$.
  - `EXTERNAL_REALDATA_VALIDATION_REPORT.md` incorrectly reported $\rho = -0.9760$ and $\rho = -0.9120$ and mislabeled the process as "nuclear export".
  - **Fix**: Correct all summary tables to positive correlations and use the term **"dose-dependent nuclear translocation / accumulation"**.
- **Issue 2 (Positive Control Definition)**:
  - In official BBBC013 documentation: Columns 3–11 are 9-point dilution curves. Columns 1–2 are negative controls. Column 12 is positive control (150 nM Wortmannin).
  - Rows E–H column 12 is NOT a "LY294002 positive control" (its dose is 0 nM in platemap).
  - **Fix**: In `external_validation/scripts/validate_bbbc013.R`, decouple plate positive control from drug row splitting; do NOT label E12–H12 as LY294002 positive control.
  - Re-run `validate_bbbc013.R` and regenerate `BBBC013_NC_TRANSLOCATION_VALIDATION.md` and `BBBC013_NC_TRANSLOCATION_RESULTS.csv`.

### 3.2 BBBC007 (Cell Boundary & Topological Invariants)
- **Issue**: `cell_mask_overlap_pixels = 0L` was hardcoded in `validate_bbbc007.R` and presented in the report as an empirical benchmark measurement.
- **Fix**: Clarify in `BBBC007_CELL_BOUNDARY_VALIDATION_REPORT.md` and `CELL_PROPAGATION_VISUAL_AUDIT.md`:
  - **Structural Invariants by Construction**: Zero overlap (`cell_mask_overlap_pixels = 0`) and one nucleus per cell (`one_nucleus_per_cell = 1.0`) are mathematical guarantees of the seeded partition representation.
  - **Empirical Benchmark Metrics**: Nucleus F1 = `0.7781`, Median boundary distance = `2.7257 px`, Boundary within 2 px = `58.8%`.
- **Status**: Maintain **`PASS_WITH_WARNINGS`**.

### 3.3 BBBC016 (Subcellular Puncta Induction)
- **Issue**: Summary matrix claimed `Monotonic Trend = TRUE`, but $\rho = 0.3720$ represents moderate positive association rather than strict monotonicity.
- **Fix**:
  - In `EXTERNAL_VALIDATION_MATRIX.csv` and reports, change `Monotonic Trend` to `Positive dose association = TRUE`.
  - Frame the result accurately: the frozen puncta workflow recovered a positive dose-associated trend with stronger concordance for integrated intensity ($\rho = 0.6254$) than per-cell count ($\rho = 0.3720$).
- **Status**: Maintain **`PASS_WITH_WARNINGS`**.

### 3.4 HPA DAB-IHC (Human Protein Atlas Real-World TMA)
- **Issue 1 (License)**: `DATASET_PROVENANCE_HPA_IHC.md` listed `CC BY-SA 4.0`. Official HPA license is **`CC BY 4.0`** with explicit citation and URL requirements.
  - **Fix**: Update provenance to `Creative Commons Attribution 4.0 International (CC BY 4.0)` with proper attribution format.
- **Issue 2 (Pixel Size Calibration)**:
  - `validate_hpa_ihc.R` hardcoded `pixel_size_um = 0.5` without provenance from XML metadata or scanner calibration.
  - **Fix**: Set `pixel_size_um = NA_real_` in `validate_hpa_ihc.R` to invoke the pipeline's explicit pixel fallback mode (`scale_mode = "pixel_fallback"`).
  - Re-run `validate_hpa_ihc.R` on the 64 images and update CSVs.
- **Issue 3 (Methodological Nuance & Selection Claims)**:
  - Replace "without manual selection bias" with **"deterministic pre-analysis selection without outcome-based cherry-picking"**.
  - Document that the 4-tier grading concordance ($\rho_{\text{P95}} = 0.7058$, $\rho_{\text{Mean}} = 0.6340$) reflects qualitative pathological staging across diverse tissues and antibodies rather than pixel-level ground truth.
- **Status**: Maintain **`PASS_WITH_MAJOR_WARNINGS`**.

### 3.5 Comprehensive Summary Report & Consistency Automation
- **Issue**: Discrepancies existed between CSV raw results and markdown narrative text.
- **Fix**:
  - Rewrite `EXTERNAL_REALDATA_VALIDATION_REPORT.md` and `EXTERNAL_VALIDATION_MATRIX.csv` to ensure 100% concordance with updated CSV outputs.
  - Create an automated cross-report validation script: `scripts/verify_report_consistency.py` to ensure CI will fail if markdown tables deviate from CSV data.

---

## 4. Key File Paths & Locations

| Purpose | File Path |
|---|---|
| Project Root | `/Users/yue/Documents/codex_work/ihc-quantification-skill-repo` |
| R Library Path | `export R_LIBS_USER="/Users/yue/Documents/codex_work/.r-lib-4.6"` |
| Review Zip Archive | `/Users/yue/Documents/codex_work/external_realdata_validation_review_bundle.zip` |
| BBBC007 Script | `external_validation/scripts/validate_bbbc007.R` |
| BBBC013 Script | `external_validation/scripts/validate_bbbc013.R` |
| BBBC016 Script | `external_validation/scripts/validate_bbbc016.R` |
| HPA Extractor | `external_validation/scripts/extract_hpa_candidates.py` |
| HPA Validator | `external_validation/scripts/validate_hpa_ihc.R` |
| Validation Reports | `external_validation/reports/*.md` |
| Results CSVs | `external_validation/results/*.csv` |
| Summary Report | `EXTERNAL_REALDATA_VALIDATION_REPORT.md` |
| Summary Matrix | `EXTERNAL_VALIDATION_MATRIX.csv` |

---

## 5. Verification Checklist for Next Agent

Before asking the reviewer for final approval of `v2.3.0-rc3`:

1. [ ] **BBBC013 Re-run**: Positive control logic corrected; positive correlation confirmed ($\rho > 0$).
2. [ ] **HPA Re-run**: `pixel_size_um = NA` applied; `CC BY 4.0` provenance updated; 64 images re-analyzed.
3. [ ] **Cross-Report Consistency**: Zero discrepancies between `*.csv` files and `*.md` reports.
4. [ ] **DAB Backward Compatibility**: `Rscript tests/verify_backward_compatibility.R` passes with 11 tables $\Delta \le 10^{-6}$.
5. [ ] **Static Package Check**: `python3 scripts/static_validate_package.py` and `python3 scripts/verify_package_manifest.py` pass.
6. [ ] **Git Status & Version**: Working tree clean, VERSION updated to `2.3.0-rc3`, and commit ready for tagging.
