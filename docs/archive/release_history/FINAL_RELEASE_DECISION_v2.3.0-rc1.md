> HISTORICAL SNAPSHOT — NOT CURRENT RELEASE EVIDENCE
> This document records the v2.3.0-rc1 release decision exactly as made on
> 2026-08-22, including gate statuses that were current at that time (some,
> such as G7, have since been reclassified). The current decision lives in
> [`FINAL_RELEASE_DECISION.md`](../../FINAL_RELEASE_DECISION.md).

# Final Release Decision — IHC & Immunofluorescence Quantification Skill

**Release Candidate**: `v2.3.0-rc1`  
**Evaluation Role**: Release Engineer + Bioimage Validation Reviewer  
**Decision Date**: 2026-08-22  
**Final Release Decision**: **`v2.3.0-rc1 READY`**

---

## 1. Executive Release Summary

The `ihc-quantification-skill` has successfully completed all required validation gates, claim calibrations, and cross-platform verification suites for promotion from `v2.3.0-alpha.2` to **`v2.3.0-rc1`**.

The software satisfies the standards of reproducible, auditable bioimage analysis software:
1. **DAB-IHC Modality**: Full backward compatibility with v2.2.2 baseline confirmed ($\Delta \le 1.0\times 10^{-6}$ across all 11 tables).
2. **Immunofluorescence Modality**: 4-compartment quantification (GLOBAL, NUCLEUS, CYTOPLASM, EXTRACELLULAR), single-cell MFI, N/C ratios, dual-channel colocalization, and puncta detection operational.
3. **BBBC039 Instance Segmentation Benchmark**: Validated on the official 50-image validation split using ground-truth RGB instance color decoding and deterministic greedy 1-to-1 IoU matching at $\text{IoU} \ge 0.5$ (Dice = 0.8953, IoU = 0.8390, Object F1 = 0.8919, Object Precision = 0.9106, Object Recall = 0.8254).
4. **Calibrated Scientific Governance**: Explicit disclaimers embedded across code and documentation:
   - Colocalization: *"colocalization does not establish molecular binding."*
   - Puncta: *"validated synthetic puncta counting workflow."*
   - OME-TIFF: *"Supports TIFF and ImageJ-compatible hyperstacks; OME-TIFF metadata workflows remain under validation."*
5. **Cross-Platform Continuous Integration**: Passed on Ubuntu and Windows environments covering static checks, dual-modality execution, and I/O bit-depth contracts.

---

## 2. Gate Verification Matrix

| Gate | Name | Modality | Evaluation Status | Evidence / Metrics |
| :--- | :--- | :--- | :--- | :--- |
| **G0** | DAB Baseline Audit | DAB | **PASS** | 100% table and QC schema integrity verified against clean v2.2.2 tag |
| **G1** | IF Input & Bit-Depth I/O | IF | **PASS_WITH_WARNINGS** | TIFF/ImageJ hyperstack 8/16/32-bit & 12-in-16 container verified; OME-XML experimental |
| **G2** | IF Preprocessing & Saturation | IF | **PASS** | Top-hat/Rolling Ball background subtraction, saturation QC alert |
| **G3** | IF Segmentation & Compartments | IF | **PASS** | Classical distance-watershed pipeline; 4 explicit measurement domains; reviewed ROI support |
| **G4** | Four-Domain IF Quantification | IF | **PASS** | Four compartments quantified with non-empty mapped target; empty-channel guard triggers NOT_EVALUABLE |
| **G5** | 8-Panel QC & Publication Plots | IF | **PASS** | Repaired 8-panel QC rendered; gray reviewed-ROI exclusion explicit; biological comparison plots |
| **G6** | Dual-Channel Colocalization | IF | **PASS** | Pearson: 0.852 vs -0.988, M1: 1.000 vs 0.023, M2: 1.000 vs 0.025; molecular binding disclaimer |
| **G7** | Puncta / Subcellular Foci | IF | **PASS** | Validated synthetic puncta counting workflow: GT5=45->Det=43 (Err: 4.4%); GT15=135->Det=134 (Err: 0.7%); per-cell MAE = 0.17 |
| **G8** | Public Benchmark Validation | Both | **PASS** | BBBC039 official 50-image validation split: Dice=0.8953, IoU=0.8390, precision=0.9106, recall=0.8254, F1=0.8919, Count Err=13.0%; 1-to-1 instance matching |
| **G9** | 100% DAB Backward Compatibility| DAB | **PASS** | Clean v2.2.2 checkout comparison ($\Delta \le 1.0\times 10^{-6}$) |
| **G10**| Cross-Platform CI Matrix | Both | **PASS** | Exact main commit static, Ubuntu, Windows, and IF I/O contract jobs passed in Actions run 32555682952 |

---

## 3. Known Limitations & User Guidance

1. **OME-TIFF Metadata**: Native OME-XML metadata parsing remains under experimental validation. Standard TIFF and ImageJ hyperstacks are fully validated.
2. **Proprietary Formats**: Files from proprietary formats (.czi, .lif, .nd2) should be exported to ImageJ TIFF/hyperstack or standard multi-channel TIFF before processing.
3. **Biological Review**: Automated QC flags (`HIGH_SATURATION`, `LOW_CELL_COUNT`, `HIGH_BACKGROUND`) should be inspected via the 8-panel QC montages prior to publication.

---

## 4. Final Verdict

```text
========================================
STATUS: v2.3.0-rc1 READY
RELEASE_DECISION: APPROVED FOR RC1 RELEASE
========================================
```
