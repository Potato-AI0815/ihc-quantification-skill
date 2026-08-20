# IF Quality Control (QC) and Automated Flagging Guide

## 8-Panel Standard IF QC Overview
Each processed IF image automatically generates a standardized 8-panel montage saved to `qc/overview/<image_id>_if_8panel_qc.png`:
- **Panel A**: Merged Multi-channel Composite RGB
- **Panel B**: Nuclear Channel (DAPI / Hoechst)
- **Panel C**: Raw Target Channel
- **Panel D**: Background-Corrected Target Channel
- **Panel E**: Nuclear Segmentation Mask Overlay
- **Panel F**: Cell / Cytoplasm Boundary Overlay
- **Panel G**: Positive Signal Binary Mask
- **Panel H**: Four-Compartment Overlay (Nucleus, Cytoplasm, Extracellular)

---

## Automated QC Flags

| QC Flag | Severity | Trigger Condition | Recommended Action |
| :--- | :--- | :--- | :--- |
| `HIGH_SATURATION` | WARNING / CRITICAL | Saturated pixels $> 0.5\%$ | Inspect laser power/gain; re-acquire or flag for manual review |
| `LOW_DYNAMIC_RANGE` | WARNING | Dynamic range used $< 5\%$ | Check staining intensity / exposure |
| `HIGH_BACKGROUND` | WARNING | Estimated background $> 60\%$ of signal | Adjust rolling ball radius or verify wash steps |
| `LOW_CELL_COUNT` | WARNING | Number of detected cells $< 10$ | Verify DAPI channel focus and threshold parameters |
| `SEGMENTATION_SUSPECT` | WARNING | Nuclear area fraction $< 0.1\%$ | Adjust nuclear watershed sensitivity |
| `CHANNEL_REGISTRATION_SUSPECT` | WARNING | Cross-channel registration shift $> 5\text{ px}$ | Verify optical alignment or enable shift correction |
| `NO_SIGNAL` | CRITICAL | Max pixel intensity $= 0$ | Verify channel assignment in manifest |
| `EMPTY_CHANNEL` | CRITICAL | All pixels zero or unreadable | Exclude image from statistical aggregation |

`NO_SIGNAL`, `EMPTY_CHANNEL`, `NO_TISSUE_DETECTED`, and critical segmentation failures block publication-figure rendering and return a non-zero run status. The output directory is retained with the QC montage and source tables so that a reviewer can correct the manifest or image rather than receiving a fabricated positive mask.

The positive mask is never defined as `channel >= 0` for an empty channel. Empty-channel positivity is recorded as `NA`/not evaluable.
