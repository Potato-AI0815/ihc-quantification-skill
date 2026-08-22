# Release Status — IHC & Immunofluorescence Quantification Skill

**Current Version**: `2.3.0-alpha.2` (IF public runtime revalidated with warnings)
**Validation Decision**: `ALPHA_VALIDATED_WITH_WARNINGS (exact-main GitHub Ubuntu/Windows CI passed; prerelease only)`

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
| **G1** | IF Input & Bit-Depth I/O | IF | **PASS_WITH_WARNINGS** | Standard TIFF/ImageJ C/Z mapping and 8/16/32-bit plus 12-bit-in-16-bit-container values verified; OME-XML and packed native-12-bit remain experimental |
| **G2** | IF Preprocessing & Saturation | IF | **PASS** | Top-hat/Rolling Ball background, saturation QC alert |
| **G3** | IF Segmentation & Compartments | IF | **PASS_WITH_WARNINGS** | Public FluorescentCells run yielded 6 nuclei after reviewed artifact exclusion; LOW_CELL_COUNT retained |
| **G4** | Four-Domain IF Quantification | IF | **PASS** | Four compartments quantified with non-empty mapped target; empty-channel guard covered by regression tests |
| **G5** | 8-Panel QC & Publication Plots | IF | **PASS_WITH_WARNINGS** | Repaired 8-panel QC rendered; gray reviewed-ROI exclusion is explicit; biological review remains required |
| **G6** | Dual-Channel Colocalization | IF | **PASS** | Pearson: 0.852 vs -0.988, M1: 1.000 vs 0.023, M2: 1.000 vs 0.025 |
| **G7** | Puncta / Subcellular Foci | IF | **PASS_WITH_WARNINGS** | Synthetic aggregate count recovery: GT5=45->Det=43; GT15=135->Det=134; coordinate-level detector precision/recall not validated |
| **G8** | Public Benchmark Validation | Both | **PASS_WITH_WARNINGS** | BBBC039 official split: Dice=0.8953, IoU=0.8390, precision=0.9106, recall=0.8254, F1=0.8919; one zero-GT image non-evaluable; ImageJ teaching image remains non-biological |
| **G9** | 100% DAB Backward Compatibility| Brightfield DAB | **PASS** | Clean v2.2.2 checkout comparison ($\Delta = 0.000000\text{e}+00$) |
| **G10**| Cross-Platform CI Matrix | Both | **PASS** | Exact `main@748016a` static, Ubuntu, Windows, and IF I/O contract jobs passed in [Actions run 32452752381](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/32452752381) |

---

## 2. Validation Deliverables Index
- [`VALIDATION_CLOSEOUT_REPORT.md`](VALIDATION_CLOSEOUT_REPORT.md)
- [`IF_IO_VALIDATION_REPORT.md`](IF_IO_VALIDATION_REPORT.md)
- [`IF_IO_VALIDATION_FINAL.md`](IF_IO_VALIDATION_FINAL.md)
- [`SEGMENTATION_BENCHMARK_REPORT.md`](SEGMENTATION_BENCHMARK_REPORT.md)
- [`BBBC039_SEGMENTATION_BENCHMARK_FINAL.md`](BBBC039_SEGMENTATION_BENCHMARK_FINAL.md)
- [`benchmark_bbbc039_results.csv`](benchmark_bbbc039_results.csv)
- [`RC1_READINESS_REPORT.md`](RC1_READINESS_REPORT.md)
- [`COLOCALIZATION_VALIDATION_REPORT.md`](COLOCALIZATION_VALIDATION_REPORT.md)
- [`PUNCTA_VALIDATION_REPORT.md`](PUNCTA_VALIDATION_REPORT.md)
- [`BACKWARD_COMPATIBILITY_REPORT_FINAL.md`](BACKWARD_COMPATIBILITY_REPORT_FINAL.md)
- [`GATE_MATRIX_FINAL.csv`](GATE_MATRIX_FINAL.csv)
- [`segmentation_benchmark.csv`](segmentation_benchmark.csv)
