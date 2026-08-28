# Dataset Provenance — BBBC016 v1

| Field | Value |
|---|---|
| Dataset | BBBC016 v1 — human U2OS Transfluor assay |
| Official page | https://bbbc.broadinstitute.org/BBBC016 |
| Images download | https://data.broadinstitute.org/bbbc/BBBC016/BBBC016_v1_images.zip |
| Platemap download | https://data.broadinstitute.org/bbbc/BBBC016/BBBC016_v1_platemap.txt |
| Access date | 2026-08-27 |
| Licence | Creative Commons Attribution 3.0 Unported, by Ilya Ravkin |
| Recommended citation | BBBC016v1 provided by Ilya Ravkin; Ljosa et al., Nature Methods 2012 |
| Images archive SHA-256 | `866ea3e6229a0f6fa2c9a18852b3274f7617326ecfae15d40f7f5e1123df7dd1` |
| Platemap SHA-256 | `5324f1958d264d2f9a732dbad554a851b7e77a3cc6dd8719973dce0f46e44076` |
| Dataset selection | All 24 wells × 3 fields × 2 channels (144 TIFF files); no field excluded after inspection |
| Channel mapping | `d0` = DNA/nuclei; `d2` = GFP/β-arrestin target, confirmed from the official channel description and image morphology |
| Software baseline | `8099297a6b64b975e2845aabff6c08f6ca2d8efe`, followed by the documented local-radius propagation bugfix |

## Locked analysis design

- Dose values are assigned in the exact order of the official 72-entry
  platemap after sorting by well and field.
- All three fields are analyzed and then aggregated to the well.
- The experimental unit is the well; cells are nested measurements.
- Frozen puncta settings: DoG sigma1 `1.0`, sigma2 `2.5`, threshold
  `mean + 3 SD`, component area `2–150 px`.
- Primary metric: well-level mean puncta count per cell.
- Supporting metrics: well-level puncta integrated intensity and puncta density
  per analyzed pixel.
- `PASS`: Spearman rho for puncta-per-cell > 0.5, maximum-dose effect over
  control > 0, and at least 22/24 valid wells.
- `PASS_WITH_WARNINGS`: rho > 0 and maximum-dose effect > 0 with at least
  18/24 valid wells.
- Otherwise: `FAIL`.

This is a real-data biological-response concordance test. Published BBBC016
Z′/V-factor values use different endpoints and are not optimization targets.
