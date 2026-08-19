# Release Status — IHC & Immunofluorescence Quantification Skill

**Current Version**: `2.3.0-alpha.1` (IF public runtime revalidated with warnings)
**Validation Decision**: `ALPHA_VALIDATED_WITH_WARNINGS (GitHub CI pending; do not tag v2.3.0-rc1 yet)`

The previous public-image outputs are historical artifacts only. The current
public outputs were regenerated after the ImageJ axis/channel mapping,
empty-channel, tissue-mask, ROI, QC-blocking, and plot-point repairs. They are
engineering smoke-test evidence and still require biological/manual review
before any release-candidate or manuscript claim.

---

## 1. Validation Gate Matrix Summary

| Gate ID | Gate Name | Modality | Status | Summary Metrics / Outcome |
| :--- | :--- | :--- | :--- | :--- |
| **G0** | DAB Baseline Audit | Brightfield DAB | **PASS** | 100% table and QC schema integrity verified |
| **G1** | IF Input & Bit-Depth I/O | IF | **PASS** | ImageJ parser and explicit C/Z mapping verified on FluorescentCells and confocal-series |
| **G2** | IF Preprocessing & Saturation | IF | **PASS** | Top-hat/Rolling Ball background, saturation QC alert |
| **G3** | IF Segmentation & Compartments | IF | **PASS_WITH_WARNINGS** | Public FluorescentCells run yielded 6 nuclei after reviewed artifact exclusion; LOW_CELL_COUNT retained |
| **G4** | Four-Domain IF Quantification | IF | **PASS** | Four compartments quantified with non-empty mapped target; empty-channel guard covered by regression tests |
| **G5** | 8-Panel QC & Publication Plots | IF | **PASS_WITH_WARNINGS** | Repaired 8-panel QC rendered; gray reviewed-ROI exclusion is explicit; biological review remains required |
| **G6** | Dual-Channel Colocalization | IF | **PASS** | Pearson: 0.852 vs -0.988, M1: 1.000 vs 0.023, M2: 1.000 vs 0.025 |
| **G7** | Puncta / Subcellular Foci | IF | **PASS** | GT5=45->Det=43 (Err: 4.4%), GT15=135->Det=134 (Err: 0.7%) |
| **G8** | Public Benchmark Validation | Both | **PASS_WITH_WARNINGS** | FluorescentCells and confocal-series rerun passed; public teaching image is not a biological replication benchmark |
| **G9** | 100% DAB Backward Compatibility| Brightfield DAB | **PASS** | Clean v2.2.2 checkout comparison ($\Delta = 0.000000\text{e}+00$) |
| **G10**| Cross-Platform CI Matrix | Both | **PENDING_GITHUB_CI** | Workflow configured; local macOS smoke passed; Ubuntu/Windows run pending push |

---

## 2. Validation Deliverables Index
- [`VALIDATION_CLOSEOUT_REPORT.md`](VALIDATION_CLOSEOUT_REPORT.md)
- [`IF_IO_VALIDATION_REPORT.md`](IF_IO_VALIDATION_REPORT.md)
- [`SEGMENTATION_BENCHMARK_REPORT.md`](SEGMENTATION_BENCHMARK_REPORT.md)
- [`COLOCALIZATION_VALIDATION_REPORT.md`](COLOCALIZATION_VALIDATION_REPORT.md)
- [`PUNCTA_VALIDATION_REPORT.md`](PUNCTA_VALIDATION_REPORT.md)
- [`BACKWARD_COMPATIBILITY_REPORT_FINAL.md`](BACKWARD_COMPATIBILITY_REPORT_FINAL.md)
- [`GATE_MATRIX_FINAL.csv`](GATE_MATRIX_FINAL.csv)
- [`segmentation_benchmark.csv`](segmentation_benchmark.csv)
