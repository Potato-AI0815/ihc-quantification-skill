# External Real-Data Validation Comprehensive Report

**Release Milestone**: `v2.3.0-rc3` Preparation & Review  
**Date**: 2026-08-29  
**Scope**: Level A (Manual Ground-Truth) and Level B (Biological Concordance) External Datasets  
**Provenance**: This report and `EXTERNAL_VALIDATION_MATRIX.csv` are generated from the result CSVs by `external_validation/scripts/build_summary_reports.py`; `scripts/verify_report_consistency.py` fails CI if either artifact drifts from the measured data. Manual edits to the two summary artifacts are not permitted.

---

## 1. Executive Summary & Evidence Framework

To validate that the dual-modality **IHC & Immunofluorescence Quantification Skill** generalizes beyond internal synthetic regression fixtures, the software was evaluated against **4 independent, publicly accessible biological image datasets**:

1. **BBBC007 (Level A — Segmentation Benchmark)**: Morphological cell boundary & nuclear segmentation on 16 complete fields of Drosophila cells with manual outline ground-truth.
2. **BBBC013 (Level B — Dose-Response Translocation)**: FKHR-EGFP **cytoplasm-to-nucleus translocation** (nuclear accumulation under PI3K/Akt inhibition) across a 96-well dose series (Wortmannin & LY294002), with roles assigned from the official per-drug platemaps.
3. **BBBC016 (Level B — Puncta Foci Induction)**: $\beta$-arrestin Transfluor assay (72 fields, 24 wells) testing subcellular puncta accumulation under agonist stimulation.
4. **Human Protein Atlas IHC (Level B — Clinical Staining Progression)**: 64 real-world tissue microarray (TMA) cores across 4 key clinical biomarkers (`EPCAM`, `ESR1`, `KRT20`, `PAX8`) evaluating 4-tier pathologist-graded staining intensity (qualitative grading concordance).

---

## 2. External Validation Matrix

| Dataset | Modality | Evidence Level | Sample Size | Primary Metric | Primary Result | Secondary Metric | Secondary Result | Trend Association | Gate Status |
| :--- | :--- | :--- | :--- | :--- | :---: | :--- | :---: | :--- | :---: |
| **BBBC007** | Immunofluorescence | Level A (Manual GT Outlines) | 16 fields | Nucleus F1 | **0.7781** | Median boundary distance (px) | **2.7257** | N/A | **PASS_WITH_WARNINGS** |
| **BBBC013** | Immunofluorescence | Level B (Biological Dose Response) | 96 wells (2 drugs) | Spearman rho (Wortmannin N/C vs dose) | **0.8844** | Spearman rho (LY294002 N/C vs dose) | **0.9031** | Positive dose association = TRUE | **PASS** |
| **BBBC016** | Immunofluorescence | Level B (Biological Dose Response) | 24 wells (72 fields) | Spearman rho (puncta per cell vs dose) | **0.3720** | Spearman rho (integrated puncta OD vs dose) | **0.6254** | Positive dose association = TRUE | **PASS_WITH_WARNINGS** |
| **HPA_IHC** | Brightfield DAB-IHC | Level B (Clinical Staining Grading) | 64 TMA cores (4 markers) | Spearman rho (P95 DAB OD vs tier) | **0.7058** | Spearman rho (mean DAB OD vs tier) | **0.6340** | Monotonic tier progression = TRUE | **PASS_WITH_WARNINGS** |

---

## 3. Dataset-Specific Quantitative Assessments

### 3.1 BBBC007 — Cell Boundary & Nuclear Segmentation

**External accuracy against manual outlines** (empirical benchmark measurements):

- **Nucleus object F1 = 0.7781** (Precision = 0.7529, Recall = 0.8119, Count Relative Error = 12.9%).
- Boundary precision: 58.8% within 2 px, 68.9% within 3 px, 46.6% within 1 px of expert manual outlines.
- Median boundary distance (field mean) = 2.7257 px; 95th percentile (field mean) = 9.7545 px.

**Structural invariants by construction** (verified regression guards, **not** external accuracy measurements): the predicted cell representation is a mutually exclusive integer label image grown from nucleus seeds, so zero overlap (`cell_mask_overlap_pixels = 0`) and one nucleus per predicted cell (1.0000, multi-nucleus cells = 0, zero-nucleus cells = 0) hold by the data structure itself, independent of agreement with the manual outlines.

**Gate status**: **PASS_WITH_WARNINGS**.

**Detailed artifacts**: [`BBBC007_CELL_BOUNDARY_VALIDATION_REPORT.md`](external_validation/reports/BBBC007_CELL_BOUNDARY_VALIDATION_REPORT.md), [`BBBC007_CELL_BOUNDARY_VALIDATION.csv`](external_validation/results/BBBC007_CELL_BOUNDARY_VALIDATION.csv), [`CELL_PROPAGATION_VISUAL_AUDIT.md`](CELL_PROPAGATION_VISUAL_AUDIT.md).

### 3.2 BBBC013 — Cytoplasm-to-Nucleus Translocation

**Biological target**: FKHR-EGFP **accumulates in the nucleus** upon PI3K/Akt inhibition (Wortmannin, LY294002). The nuclear-to-cytoplasmic (N/C) ratio therefore **increases with dose**; a positive dose-response rho and a positive-control shift above negative controls are the expected signature. A dose-dependent N/C decrease would contradict this biology and is not an expected outcome.

**Dose-response recovery** (roles from the official per-drug platemaps; dose units nM for Wortmannin, µM for LY294002):

- Wortmannin dose-response Spearman rho = +0.8844; LY294002 dose-response Spearman rho = +0.9031.
- Wortmannin: positive control (150 nM, column 12) median N/C = 4.7762 vs negative controls (columns 1–2) = 0.7026; effect = +4.0735; Z-prime (descriptive) = 0.6635.
- LY294002: positive control (80 µM, column 1) median N/C = 4.8914 vs negative controls (column 2) = 0.7315; effect = +4.1599; Z-prime (descriptive) = 0.5348.
- E12–H12 are no-drug wells (platemap dose 0): median N/C = 0.8374. They are **excluded** from the LY294002 positive-control statistics — the official plate positive control is the 150 nM Wortmannin column, and the LY294002 arm's maximum-dose control is column 1.

**Gate status**: **PASS**.

**Detailed artifacts**: [`BBBC013_NC_TRANSLOCATION_VALIDATION.md`](external_validation/reports/BBBC013_NC_TRANSLOCATION_VALIDATION.md), [`BBBC013_NC_TRANSLOCATION_RESULTS.csv`](external_validation/results/BBBC013_NC_TRANSLOCATION_RESULTS.csv), [`BBBC013_NC_TRANSLOCATION_SUMMARY.csv`](external_validation/results/BBBC013_NC_TRANSLOCATION_SUMMARY.csv), [`DATASET_PROVENANCE_BBBC013.md`](external_validation/reports/DATASET_PROVENANCE_BBBC013.md).

### 3.3 BBBC016 — Puncta / Subcellular Foci Accumulation

**Biological target**: Transfluor agonist dose-response GFP-$\beta$-arrestin endocytic vesicle accumulation.

**Positive dose association** (not a strict monotonicity claim): the frozen puncta workflow recovered a positive dose-associated trend across 24/24 valid wells:

- Puncta per cell Spearman rho = 0.3720 (weaker endpoint).
- Integrated puncta OD Spearman rho = 0.6254 (stronger endpoint).
- Puncta density Spearman rho = 0.4374; maximum-dose minus control effect = +0.5474.

**Gate status**: **PASS_WITH_WARNINGS**.

**Detailed artifacts**: [`BBBC016_PUNCTA_EXTERNAL_VALIDATION.md`](external_validation/reports/BBBC016_PUNCTA_EXTERNAL_VALIDATION.md), [`BBBC016_PUNCTA_REALDATA_RESULTS.csv`](external_validation/results/BBBC016_PUNCTA_REALDATA_RESULTS.csv), [`BBBC016_PUNCTA_FIELD_RESULTS.csv`](external_validation/results/BBBC016_PUNCTA_FIELD_RESULTS.csv), [`DATASET_PROVENANCE_BBBC016.md`](external_validation/reports/DATASET_PROVENANCE_BBBC016.md).

### 3.4 Human Protein Atlas (HPA) — DAB-IHC Pathological Grading

- **Data Source**: Official HPA XML metadata API (schemaVersion 3.0, release 25). License: **Creative Commons Attribution 4.0 International (CC BY 4.0)** with the canonical HPA citation and portal-URL attribution requirements (see [`DATASET_PROVENANCE_HPA_IHC.md`](external_validation/reports/DATASET_PROVENANCE_HPA_IHC.md)).
- **Calibration boundary**: HPA metadata carries no pixel size, so analyses ran in the pipeline's explicit pixel-fallback mode (`scale_mode = "pixel_fallback"`); endpoints are scale-invariant and no physical-length claims are made.
- **Cohort composition**: 64 distinct TMA cores (16 per marker) across 4 clinical biomarkers: `EPCAM`, `ESR1`, `KRT20`, `PAX8`; 64 unique image IDs and cell counts from 18 to 6067 cells per core.
- **Ground-truth semantics**: the 4 tiers are pathologist-assigned **qualitative** staining levels spanning different tissues, patients, and antibodies; the evaluation measures ordinal grading concordance at the image level, not single-pixel or region-level ground truth.

**Grading concordance**:

- Overall P95 DAB OD Spearman rho = **0.7058**
- Overall mean DAB OD Spearman rho = **0.6340**
- Overall H-Score (0–300) Spearman rho = **0.5901**
- Per-gene P95 OD Spearman rho: EPCAM (`0.8974`), KRT20 (`0.8731`), PAX8 (`0.9216`), ESR1 (`0.4972`). The weaker ESR1 association is a real biological result of this cohort and is reported as measured.

**Tier-by-tier progression** (means per tier):

| Ground-Truth Tier | N | Mean DAB OD | P95 DAB OD | Mean H-Score (0–300) | Positive Area Fraction |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **0 - Not detected** | 16 | 0.1065 | 0.2639 | 3.7 | 51.4% |
| **1 - Low** | 16 | 0.1397 | 0.3534 | 13.1 | 56.6% |
| **2 - Medium** | 16 | 0.2543 | 0.7501 | 42.8 | 66.6% |
| **3 - High** | 16 | 0.5423 | 1.6542 | 74.6 | 74.1% |

Tier-mean progression is strictly monotonic for both mean OD and P95 OD: **TRUE**.

**Gate status**: **PASS_WITH_WARNINGS**.

**Detailed artifacts**: [`HPA_IHC_EXTERNAL_VALIDATION.md`](external_validation/reports/HPA_IHC_EXTERNAL_VALIDATION.md), [`HPA_IHC_REALDATA_RESULTS.csv`](external_validation/results/HPA_IHC_REALDATA_RESULTS.csv), [`HPA_IHC_SUMMARY_METRICS.csv`](external_validation/results/HPA_IHC_SUMMARY_METRICS.csv), [`DATASET_PROVENANCE_HPA_IHC.md`](external_validation/reports/DATASET_PROVENANCE_HPA_IHC.md).

---

## 4. Technical Audit & Discrepancy Reconciliation

1. **BBBC013 plate semantics correction (rc3)**: the rc2-era draft summary mislabeled E12–H12 as LY294002 positive controls (they are no-drug wells with platemap dose 0) and quoted contradictory negative correlations that never existed in the measured summary CSV. The corrected roles (LY294002 positive control = column 1, 80 µM) were verified against the official per-drug platemap files and the observed per-well N/C data; the measured positive correlations (Wortmannin +0.8844, LY294002 +0.9031) now match every summary artifact via the consistency gate.
2. **Preliminary HPA mock run vs real execution**: an initial test-run script drafted before a function-naming mismatch (`deconvolve_stains` vs `hdab_deconvolution`) produced an early mock log ($\rho = 0.9856$). Once corrected to the canonical `analyse_ihc_image` pipeline on the downloaded JPEG files, the real metrics were calculated and permanently recorded in `HPA_IHC_REALDATA_RESULTS.csv`. The mock figures are superseded and appear nowhere in the artifacts.
3. **Distinct TMA cores & independent cell counts**: all 64 images have unique URLs, unique image files, and unique biological cell counts (18–6067 cells per core), confirming zero file overwriting or placeholder reuse.
4. **No outcome-based re-selection**: dataset selections (BBBC007 all 16 fields; BBBC013 all 96 wells; BBBC016 all 24 wells × 3 fields; HPA 64 pre-selected cores) were fixed before analysis and were not modified after inspecting results.

---

## 5. Conclusion & Release Gate Recommendation

All 4 external benchmarks evaluate to **`PASS`** or **`PASS_WITH_WARNINGS`** under frozen parameter baselines, with every summary artifact numerically aligned to the underlying result CSVs by the consistency gate. The repository satisfies the criteria for promotion to **`v2.3.0-rc3`**.
