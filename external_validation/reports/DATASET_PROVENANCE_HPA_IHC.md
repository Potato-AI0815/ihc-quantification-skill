# Dataset Provenance — Human Protein Atlas (HPA) IHC Benchmark

| Field | Value |
|---|---|
| Dataset | Human Protein Atlas (HPA) Tissue Microarray IHC Benchmark |
| Official Portal | https://www.proteinatlas.org |
| Source API | HPA XML API (schemaVersion 3.0, release 25) |
| Image Host | https://images.proteinatlas.org |
| Access Date | 2026-08-28 |
| License | Creative Commons Attribution 4.0 International (CC BY 4.0) |
| Attribution Requirement | Any reuse must credit the Human Protein Atlas and include the canonical citation below together with the portal URL https://www.proteinatlas.org |
| Citation | Uhlen M, et al. Tissue-based map of the human proteome. Science 357(6352):eaan3707 (2017); Uhlen M, et al. A pathology atlas of the human cancer transcriptome. Science 357(6352):eaan2507 (2017). Images: Human Protein Atlas, https://www.proteinatlas.org |
| Evaluated Markers | 4 representative clinical/pathological markers (EPCAM, ESR1, KRT20, PAX8) |
| Staining Tiers | 4 pathologist-assigned qualitative tiers (Not detected, Low, Medium, High), spanning different tissues, patients, and antibodies |
| Sample Size | 64 total images (16 images per gene, 4 selected images per tier; observational TMA samples, not experimental replicates) |
| Subcellular Compartments | Nuclear (ESR1, PAX8), Membranous/Cytoplasmic (EPCAM, KRT20) |
| Calibration Boundary | HPA XML metadata and image payload carry no pixel-size calibration; analyses run in the explicit pixel-fallback mode of the pipeline (scale_mode = "pixel_fallback") and no physical-length claims are made |
| Software Baseline | Frozen DAB-IHC pipeline (optical density deconvolution + watershed segmentation) |

## Locked Analysis Design
- All 64 images were selected by deterministic pre-analysis rules from structured HPA XML metadata (balanced tiers per marker) without outcome-based cherry-picking: the selection ran before any image was quantified, and no image was added, dropped, or re-selected after inspecting quantitative results.
- Ground-truth tiers are qualitative pathological staining levels assigned by HPA pathologists across heterogeneous tissues and antibodies; the concordance evaluated here is ordinal grading agreement at the image level, not single-pixel or region-level ground truth.
- Quantitative endpoints: DAB Optical Density (Mean, Median, P95), Positive Tissue Fraction, and Cellular H-Score (0–300).
- Primary evaluation: Spearman rank correlation between quantitative endpoints and pathologist-assigned tiers, plus monotonic tier-mean progression.
- Gate criteria:
  - `PASS`: Overall Spearman $\rho \ge 0.70$ and monotonic progression across tiers.
  - `PASS_WITH_WARNINGS`: Overall Spearman $\rho \ge 0.50$.
  - `FAIL`: Overall Spearman $\rho < 0.50$.

