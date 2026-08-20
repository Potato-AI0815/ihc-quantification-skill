# Dual-modality synthetic smoke test — v2.3.0-alpha.1

The fixture contains four deterministic DAB/hematoxylin-like RGB images and four deterministic IF images. It validates the maintained DAB v2.2.2 workflow together with the v2.3.0-alpha.1 IF modality.

Linux/macOS:

```bash
bash tests/run_synthetic_smoke_test.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_synthetic_smoke_test.ps1
```

The test suite requires:

- four successful images;
- GLOBAL, tumor, and stroma ROI compartments;
- nuclear, cytoplasmic, whole-cell, and extracellular metrics;
- four separate fixed-scale main figures and source CSV files;
- 0–100% axes for fraction figures and 0–300 axes for H-score figures;
- correct `n=1` captions with no claimed SE;
- four eight-panel QC overviews;
- four H-DAB reconstructions;
- four DAB-positive masks;
- four H-DAB and four RGB domain overlays;
- ROI evidence and overlap audit;
- paired effects for two biological units;
- manual-QC template;
- no image errors.

`verify_plot_contract.R` separately inspects ggplot objects for fixed axis limits, subtitle wrapping, low-n captions, and repeated-unit text.

This fixture validates software wiring only. It is not a biological validation dataset and cannot justify thresholds, segmentation settings, or biological conclusions.
