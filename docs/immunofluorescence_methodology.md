# Immunofluorescence (IF) Methodology and Scientific Governance

## Overview
The Immunofluorescence (IF) quantification module provides an auditable, QC-first pipeline for multi-channel fluorescence microscopy images (epifluorescence, confocal, spinning disk, multiphoton).

### Scope and Purpose
- **Research Use Only (RUO)**: This software is intended strictly for scientific research and quantitative image exploration. It is **not** approved for clinical diagnosis, diagnostic screening, or patient management decisions.

---

## Modality Isolation Principle
The IF pipeline operates independently from the brightfield DAB-IHC pipeline:
1. **Intensity Scales**: Fluorescence values represent linear emitted photons (arbitrary fluorescence intensity units / count values), **never** optical density (OD / absorbance).
2. **Integrated Intensity**: Total signal per compartment or cell is termed **Integrated Fluorescence Intensity** or **Integrated Intensity**, **never** "Integrated Optical Density (IOD)".
3. **Biological Compartments**:
   - `NUCLEUS`: Derived from DAPI / nuclear Hoechst counterstain segmentation.
   - `CYTOPLASM`: Derived from constrained Voronoi propagation or structural cytoplasm markers minus the nuclear mask.
   - `CELL`: Combined nuclear and cytoplasmic compartment mask.
   - `EXTRACELLULAR`: Valid image area minus cell masks. **Never** automatically designated as "stroma" without validated histological tissue classification.
   - `GLOBAL`: Entire tissue area / valid field of view.

---

## Preprocessing and Calibration
1. **Dynamic Range & Bit Depth Preservation**:
   - Native 8-bit ($0..255$), 12-bit ($0..4095$), 16-bit ($0..65535$), and 32-bit float images are supported.
   - Pixel intensities are quantified on linear calibrated scales.
   - Non-linear adjustments (e.g. CLAHE, histogram equalization) are restricted strictly to visualization rendering and excluded from quantitative metrics.
2. **Background Correction**:
   - Supported algorithms: `rolling_ball` (morphological opening), `top_hat`, `local_background`, `user_defined_background_roi`.
   - Corrected pixel values are clamped at zero ($I_{\text{corr}} \ge 0$).
3. **Saturation QC**:
   - Quantifies `saturated_pixel_fraction`, `near_zero_pixel_fraction`, and `dynamic_range_used`.
   - If saturation exceeds 0.5%, the image receives a `HIGH_SATURATION` flag requiring manual review.

---

## Colocalization Governance
- Pearson correlation coefficient ($r$) and Manders overlap coefficients ($M_1, M_2$) quantify spatial intensity association.
- **Scientific disclaimer**: High colocalization scores demonstrate correlated pixel distribution within optical resolution limits, **not** direct physical molecular interaction.

---

## Statistical Governance: Biological Unit Contract
- In all aggregated analyses, the unit of observation ($n$) is the **biological replicate** (`biological_unit_id`), not individual cells.
- Aggregation computes mean/median intensities per biological unit across fields of view.
- For small sample sizes ($n < 2$), paired significance testing is explicitly flagged as `NOT_EVALUABLE_N_LT_2` to prevent pseudo-replication and spurious claims.
