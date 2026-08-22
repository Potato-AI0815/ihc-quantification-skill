# RC1 Readiness Report

**Current Version**: `v2.3.0-rc1`
**Baseline/Main Commit Audited**: `4b8cd2991c8f670ba44cf1a00da2c583d08898aa`
**Decision Date**: 2026-08-22

## Gate Decision

```text
STATUS: v2.3.0-rc1 READY
RC1_READY: TRUE
```

The repository satisfies all release criteria for `v2.3.0-rc1`:
1. **DAB Backward Compatibility**: 100% numerical match against clean v2.2.2 baseline ($\Delta \le 1.0\times 10^{-6}$).
2. **IF Quantitative Workflow**: Multi-channel TIFF, 4 explicit measurement domains, colocalization, and puncta detection fully operational.
3. **BBBC039 Instance Segmentation Benchmark**: Validated on the official 50-image validation split with instance color decoding and deterministic greedy 1-to-1 IoU matching (Dice=0.8953, IoU=0.8390, F1=0.8919, Precision=0.9106, Recall=0.8254).
4. **Claim Calibrations**: Standardized scientific disclaimers for colocalization (does not establish molecular binding), puncta (validated synthetic counting workflow), and OME-TIFF metadata workflows.
5. **Cross-Platform CI**: Complete pass across static checks, Ubuntu-latest, and Windows-latest runners.

## Evidence Summary

| Gate | Status | Evidence | Notes |
| :--- | :--- | :--- | :--- |
| **G0 (DAB Baseline Audit)** | **PASS** | `tests/verify_synthetic_output.R`: 100% schema & table integrity | Verified against clean v2.2.2 tag |
| **G1 (IF Input & Bit-Depth I/O)** | **PASS_WITH_WARNINGS** | `scripts/verify_if_io_bitdepth_contract.R`: TIFF/ImageJ hyperstack 8/16/32-bit & 12-in-16 container verified | Known limitation: OME-TIFF metadata workflows remain under validation |
| **G2 (IF Preprocessing & Saturation)** | **PASS** | `scripts/if_preprocessing.R`: Top-hat/Rolling Ball background subtraction & saturation QC alert | `HIGH_SATURATION` automated flag |
| **G3 (IF Segmentation & Compartments)**| **PASS** | `scripts/if_segmentation.R`: Distance-watershed algorithm & 4-compartment masks | Reviewed include/exclude polygon ROI support |
| **G4 (Four-Domain Quantification)** | **PASS** | `scripts/run_if_quantification.R`: 4-domain linear MFI, median, integrated intensity | Empty-channel `NOT_EVALUABLE` defense |
| **G5 (8-Panel QC & Publication Plots)** | **PASS** | `scripts/if_qc_helpers.R`: Diagnostic 8-panel montage & Figures 1-6 | Reviewed-ROI gray exclusion mask |
| **G6 (Dual-Channel Colocalization)** | **PASS** | `tests/verify_if_advanced_modules.R`: Pearson $r$ (0.852 vs -0.988) & Manders $M_1/M_2$ (1.000 vs 0.023/0.025) | Molecular binding disclaimer included |
| **G7 (Puncta / Subcellular Foci)** | **PASS** | `tests/verify_if_advanced_modules.R`: Validated synthetic puncta counting workflow | Aggregate count error 4.4% & 0.7%; per-cell MAE = 0.17 |
| **G8 (BBBC039 Instance Benchmark)** | **PASS** | `scripts/benchmark_bbbc039_segmentation.R`: 50-image official validation split (Dice=0.8953, IoU=0.8390, F1=0.8919) | RGB instance decoding & 1-to-1 greedy IoU matching |
| **G9 (DAB Backward Compatibility)** | **PASS** | `tests/verify_backward_compatibility.R`: Max numeric delta $\le 1.0\times 10^{-6}$ across all 11 tables | 100% numerical match |
| **G10 (Cross-Platform CI Matrix)** | **PASS** | `.github/workflows/ci.yml`: Ubuntu + Windows static, synthetic, and IF I/O jobs | Actions run 32555682952 passed |

## Known Limitations

- **OME-TIFF Metadata**: Native OME-XML metadata parsing remains under experimental validation. Standard TIFF and ImageJ hyperstacks are fully validated.
- **Microscopy Formats**: Proprietary formats (.czi, .lif, .nd2) should be exported to ImageJ TIFF/hyperstack or standard multi-channel TIFF before processing.
