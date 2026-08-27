# External Validation Baseline

**Baseline date**: 2026-08-27  
**Baseline branch**: `main`  
**Baseline commit**: `8099297a6b64b975e2845aabff6c08f6ca2d8efe`  
**Immutable baseline tag**: `v2.3.0-rc2`  
**Exact-tag CI**: Actions run `32791143505` — `SUCCESS`

The external datasets are locked test data. The parameters below were frozen
before downloading or inspecting benchmark results. Results are not used to
tune these values. If a core algorithm change becomes necessary, it must be
handled as a separately documented bugfix followed by complete synthetic,
external, DAB-compatibility, and cross-platform revalidation.

## Frozen core-file digests

| Asset | SHA-256 at baseline |
|---|---|
| `scripts/if_segmentation.R` | `f91399f579f2eb109f5f7a1df0758db3411efbda3b3d4392e4e43a305628c147` |
| `scripts/if_quantification_helpers.R` | `a76ec742a98927c21ad540b7f2cc65f0ead6a005f405bb7756b1af7e49a767` |
| `scripts/if_puncta.R` | `a8560b4d011f6327b448cb7c70a9b1f46660a1b4b39211ce603b14903c5e0144` |
| `scripts/if_preprocessing.R` | `2b36f41a1cf59bccf13ebb9f6590b7d00e8bc35d9527fc621c4cecbd4f5158c9` |
| `scripts/ihc_helpers.R` | `4ecdba72eaa9f91f543ef94d5cd28bcc46f7e754d6f0fbda03c2a5657ff2f7b1` |
| `scripts/run_if_quantification.R` | `c9742b860029df6975885b905e386f880ff66811874bf79341069341ebeeeb0a` |
| `scripts/run_ihc_quantification.R` | `b48ffd2ece8f4fc4267b69b85a5b0cc13e8d681fd127332fe198158aae7ed435` |

## Frozen IF segmentation and propagation parameters

```text
segmentation_engine = ebimage
nuc_threshold_method = otsu
nuc_threshold_value = NA
nuc_min_area = 20 px
nuc_max_area = 5000 px
nuc_watershed_tolerance = 1.0
nuc_watershed_ext = 1
refine_dense_nuclei = TRUE
cell_propagation_radius = 15 px
max_cytoplasm_expansion_radius = 10 px
cytoplasm_boundary_gap_px = 1 px
```

Cell propagation remains neighbor-aware: the effective expansion radius is
bounded by the configured maximum and by the closest nuclear-boundary pair.
No benchmark-specific override is permitted.

## Frozen IF preprocessing, positivity, and puncta parameters

```text
z_mode = max_projection
background_method = top_hat
background_radius = 25 px
positivity_threshold = Otsu unless an analysis manifest pre-registers a manual value
puncta_sigma1 = 1.0 px
puncta_sigma2 = 2.5 px
puncta_threshold_sd = 3.0
puncta_min_area = 2 px
puncta_max_area = 150 px
```

## Frozen DAB-IHC parameters

```text
white_quantile = 0.98
tissue_od_min = 0.10
tissue_close_radius_px = 2
nucleus_blur_sigma_um = 0.8
nucleus_blur_sigma_px = 1.2
nucleus_min_area_um2 = 20
nucleus_max_area_um2 = 400
nucleus_min_area_px = 80
nucleus_max_area_px = 5000
cell_expansion_radius_um = 6.0
cell_expansion_radius_px = 18
DAB thresholds = 0.08 / 0.18 / 0.35 OD
```

The H-DAB colour-deconvolution implementation and v2.2.2 backward-
compatibility baseline are frozen. HPA images, if evaluable, are an external
concordance test rather than quantitative ground truth.

## Selection governance

- Dataset versions, fixed sample lists, and selection rules are recorded before
  inspecting Skill-derived outcomes.
- BBBC007 and BBBC039 are Level A ground-truth benchmarks.
- BBBC013, BBBC016, and HPA DAB are Level B biological-response or ordinal
  concordance tests.
- Cells and fields are nested observations; wells, independent samples, or
  images are the declared experimental/observational units.
- Worst-performing fields are retained in visual audits.
