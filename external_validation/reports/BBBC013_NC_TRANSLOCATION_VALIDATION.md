# BBBC013 Nuclear/Cytoplasmic Translocation External Validation

**Evidence level**: Level B — real biological-response concordance

**Status**: **PASS**

The BBBC013 BMP archive was converted to uncompressed 8-bit TIFF only in the validation cache. The conversion script checked exact integer pixel round-trips for all 192 files. No BMP support was added to the core workflow.

## Biological direction

BBBC013 is a PI3K/Akt-inhibition translocation assay: inhibiting PI3K/Akt prevents phosphorylation-dependent cytoplasmic retention of FKHR-EGFP, so FKHR-EGFP **accumulates in the nucleus** with increasing drug concentration. The expected signature is a **dose-dependent increase of the nuclear-to-cytoplasmic (N/C) ratio** (positive Spearman rho), together with N/C elevation in positive-control wells relative to negative controls. A dose-dependent N/C decrease would contradict this biology and is not an expected outcome.

## Pre-registered design

- Channel 1: FKHR-EGFP target; Channel 2: DNA.
- Roles follow the official per-drug platemap files, not column symmetry:
  - Rows A-D, Wortmannin (nM): columns 1-2 negative controls (0), columns 3-11 dose series (0.98-250), column 12 positive control (150 nM Wortmannin — the plate-wide positive control).
  - Rows E-H, LY294002 (uM): column 1 positive control (80), column 2 negative control (0), columns 3-11 dose series (0.31-80), column 12 no-drug (empty) wells.
- E12-H12 contain no LY294002 and are therefore **excluded from the LY294002 positive-control statistics**; they are reported separately as no-drug wells.
- Primary endpoint: well-level median nuclear-to-cytoplasmic ratio.
- Cells are nested observations and are aggregated to wells before response summaries.
- A positive dose-response direction (rho > 0) and positive-control shift above negative controls indicate recovery of cytoplasm-to-nucleus translocation.

## Drug-level summaries

| Drug | Valid wells | Negative median N/C | Positive median N/C | No-drug (empty) median N/C | Positive-minus-negative | Spearman rho | Z-prime (descriptive) | Direction |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Wortmannin | 48/48 | 0.703 | 4.776 | NA | 4.074 | 0.884 | 0.664 | PASS |
| LY294002 | 48/48 | 0.732 | 4.891 | 0.837 | 4.160 | 0.903 | 0.535 | PASS |

Valid well fraction: 1.000.

## Interpretation boundary

This is a real-data biological-response concordance test, not a reproduction of the published Z'/V-factor endpoint and not a clinical assay validation. Published benchmark values were not used as optimization targets.
