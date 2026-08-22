# Release Status — IHC & Immunofluorescence Quantification Skill

**Current Version**: `2.3.0-rc1`
**Validation Decision**: `v2.3.0-rc1 READY (Exact-main GitHub Ubuntu/Windows CI passed; Release Candidate Ready)`

> [!IMPORTANT]
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
| **G7** | Puncta / Subcellular Foci | IF | **PASS** | Validated synthetic puncta counting workflow: GT5=45->Det=43 (Err: 4.4%); GT15=135->Det=134 (Err: 0.7%); per-cell MAE = 0.17 |
| **G8** | Public Benchmark Validation | Both | **PASS** | BBBC039 official 50-image validation split: Dice=0.8953, IoU=0.8390, precision=0.9106, recall=0.8254, F1=0.8919, Count Err=13.0%; 1-to-1 instance matching |
| **G9** | 100% DAB Backward Compatibility| Brightfield DAB | **PASS** | Clean v2.2.2 checkout comparison ($\Delta \le 1.0\times 10^{-6}$) |
| **G10**| Cross-Platform CI Matrix | Both | **PASS** | Exact main commit static, Ubuntu, Windows, and IF I/O contract jobs passed in Actions run 32555682952 |

---

## 2. Validation Deliverables Index
- [`VALIDATION_CLOSEOUT_REPORT.md`](VALIDATION_CLOSEOUT_REPORT.md)
- [`IF_IO_VALIDATION_REPORT.md`](IF_IO_VALIDATION_REPORT.md)
- [`IF_IO_VALIDATION_FINAL.md`](IF_IO_VALIDATION_FINAL.md)
- [`SEGMENTATION_BENCHMARK_REPORT.md`](SEGMENTATION_BENCHMARK_REPORT.md)
- [`BBBC039_SEGMENTATION_BENCHMARK_FINAL.md`](BBBC039_SEGMENTATION_BENCHMARK_FINAL.md)
- [`benchmark_bbbc039_results.csv`](benchmark_bbbc039_results.csv)
- [`RC1_READINESS_REPORT.md`](RC1_READINESS_REPORT.md)
- [`GATE_MATRIX_RC1_FINAL.csv`](GATE_MATRIX_RC1_FINAL.csv)
- [`COLOCALIZATION_VALIDATION_REPORT.md`](COLOCALIZATION_VALIDATION_REPORT.md)
- [`PUNCTA_VALIDATION_REPORT.md`](PUNCTA_VALIDATION_REPORT.md)
- [`BACKWARD_COMPATIBILITY_REPORT_FINAL.md`](BACKWARD_COMPATIBILITY_REPORT_FINAL.md)
- [`GATE_MATRIX_FINAL.csv`](GATE_MATRIX_FINAL.csv)
- [`segmentation_benchmark.csv`](segmentation_benchmark.csv)

