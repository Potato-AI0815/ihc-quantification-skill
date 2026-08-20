# IF Segmentation and Compartment Definition Guide

## Segmentation Engines
The pipeline supports modular segmentation engines:

### 1. Default: EBImage Watershed Pipeline
- **Method**: Gaussian smoothing ($\sigma = 1.5$) -> Otsu / Adaptive thresholding -> Hole filling -> Distance transform -> Watershed peak separation -> Morphological size filtering ($20 \le \text{Area} \le 5000\text{ px}$).
- **Zero External Dependency**: Operates natively in R via Bioconductor `EBImage`.

### 2. External Mask Import (`external_mask`)
- Seamlessly import pre-computed masks from external tools:
  - **Fiji / ImageJ** (ROI manager / binary mask TIFF)
  - **QuPath** (Object label map export)
  - **Cellpose / StarDist** (Integer label mask `.tif` / `.png`)
  - **ilastik / napari** (Segmentation label export)

### 3. Optional AI Segmentation (`cellpose_optional`, `stardist_optional`)
- If a Python environment with `cellpose` or `stardist` is detected, the pipeline can delegate primary nuclear segmentation to deep learning models.
- **Graceful Fallback**: If Python or model dependencies are unavailable, the engine automatically falls back to native EBImage watershed without halting the analysis pipeline.

---

## Compartment Definition
1. `NUCLEUS`: Defined by nuclear segmentation mask.
2. `CYTOPLASM`: Defined by constrained Voronoi propagation around nuclei (default radius = 15 px) or constrained by cytoplasmic reference channel minus nuclear mask.
3. `CELL`: $M_{\text{cell}} = M_{\text{nuc}} \cup M_{\text{cyto}}$.
4. `EXTRACELLULAR`: $M_{\text{extracellular}} = M_{\text{tissue}} \setminus M_{\text{cell}}$.
