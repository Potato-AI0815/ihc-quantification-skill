# IHC quantification methods reference — v2.2.2

## 1. Analytical hierarchy

The workflow distinguishes three nested concepts:

1. **biological unit**: the independent patient, animal, specimen, organoid, or other unit;
2. **ROI compartment**: the analyzed location, such as global, tumor, stroma, interface, or custom;
3. **measurement domain**: global tissue, nucleus, cytoplasm, or extracellular tissue inside the ROI.

Images, fields, ROIs, cells, and pixels are nested observations. Statistical summaries are aggregated to `biological_unit_id` before condition comparison.

## 2. Color preprocessing and H-DAB deconvolution

The input is read as RGB. A high-brightness white reference is estimated from eligible, non-excluded pixels. RGB values are divided by this reference and clamped to the valid range.

Optical density is calculated as:

`OD = −log(max(RGB, 1/255))`

The fixed stain vectors are:

- hematoxylin: `(0.650, 0.704, 0.286)`;
- DAB: `(0.268, 0.570, 0.776)`.

A residual vector completes the stain matrix. Concentrations are estimated by matrix inversion and negative concentrations are set to zero.

The H-DAB reconstruction uses only estimated hematoxylin and DAB concentrations and their stain vectors. It is a QC visualization of stain separation, not a new measurement channel.

## 3. Tissue and exclusion masks

The tissue mask is based on total optical density above `tissue_od_min`, followed by morphological closing. Explicit `action=exclude` polygons are removed before tissue segmentation and all subsequent measurements.

Common exclusions include:

- scale bars and labels;
- annotation text;
- blank glass;
- folds and tears;
- necrosis when prespecified;
- debris and edge artifacts.

Exclusions must be recorded in source-image coordinates.

## 4. Nuclear segmentation

The hematoxylin OD channel is scaled, blurred, thresholded, morphologically cleaned, filled, and separated with watershed. Candidate nuclei are filtered using:

- physical or pixel area;
- circularity;
- eccentricity;
- mean hematoxylin OD;
- distance from the image border.

Physical thresholds are used when `pixel_size_um` is available. Otherwise, explicit pixel fallbacks are used and flagged.

## 5. Cell propagation and cytoplasm

Cell regions are propagated from nuclear seeds within a configurable dilation reach and tissue mask. Cytoplasm is defined as propagated cell area minus nuclear area.

This is a generic approximation. It must be reviewed for:

- merged or split nuclei;
- cell propagation across neighbors;
- cell propagation into extracellular tissue;
- cell density and morphology unsuitable for nucleus-seeded propagation.

## 6. Extracellular domain

Extracellular tissue is defined as analyzed tissue outside propagated cell masks.

It is not automatically equivalent to stroma. The result depends on cell propagation and therefore requires overlay review. It is reported using pixel-based burden metrics, not H-score.

## 7. Pixel-based metrics

For each ROI compartment and measurement mask:

- `area_px`;
- `positive_area_px`;
- `positive_area_fraction`;
- `mean_dab_od`;
- `positive_mean_dab_od`;
- `integrated_dab_od`.

The positive threshold is `dab_threshold_negative`.

## 8. Local background correction

For each cell, an extracellular ring is sampled between configurable inner and outer radii. Pixels must be tissue, non-excluded, and outside all propagated cell masks.

If the ring contains fewer than `local_background_min_pixels`, the field-level extracellular median DAB OD is used. Corrected values are:

`max(raw DAB OD − local background OD, 0)`

Both raw and corrected measurements are retained where implemented.

## 9. Domain-specific cell scores

Each cell receives separate mean DAB OD values for:

- nucleus;
- cytoplasm;
- whole cell.

Each domain is classified independently using three thresholds:

- negative threshold;
- weak threshold;
- moderate threshold.

Classes are `0`, `1+`, `2+`, and `3+`.

H-score is:

`100 × mean(0, 1, 2, or 3 across cells)`

with a range of 0–300.

The v2.2.2 explicit outputs are:

- `nuclear_h_score`;
- `cytoplasm_h_score`;
- `whole_cell_h_score`.

The backward-compatible `h_score` follows `cell_scoring_domain`.

## 10. Default primary results

The four default figures use:

- global: `tissue_positive_area_fraction`;
- nucleus: `nuclear_h_score`;
- cytoplasm: `cytoplasm_h_score`;
- extracellular: `extracellular_positive_area_fraction`.

This avoids applying a cell-based H-score to non-cellular tissue.

## 11. Biological-unit aggregation

Pixel metrics are weighted by the relevant area. Cell metrics are weighted by cell count. Integrated OD is summed. Multiple image-region rows remain traceable through source tables.

## 12. Plotting

Default plots contain:

- background summary bars;
- one point per biological unit;
- connecting lines for units repeated across conditions;
- error bars when at least two finite values exist;
- descriptive-only warning when fewer than two repeated units exist.

The plot does not convert nested measurements into independent sample size.

## 13. Paired-effect table

For exactly two conditions, data are cast by biological unit and differences are calculated as comparison minus reference.

Exact sign-flip P values are produced only for 2–20 paired units. With one paired unit, the P value is `NA` and status is `NOT_EVALUABLE_N_LT_2`.

## 14. QC visualization

The fixed colors are:

- global: blue;
- nucleus: red;
- cytoplasm: green;
- extracellular: orange;
- exclude: gray;
- tumor: purple;
- stroma: cyan;
- interface: yellow;
- custom: magenta.

The overview includes RGB, H-DAB, H OD, DAB OD, segmentation, and domain overlay. ROI evidence includes RGB, H-DAB, and selection-overlay crops.

## 15. Known limitations

- Fixed stain vectors may not optimally represent every laboratory/scanner combination.
- Thresholds are not clinical cutoffs unless separately validated.
- Nucleus-seeded propagation is not a true membrane or cell-boundary model.
- Extracellular masks depend on propagation quality.
- Single-stain morphology cannot identify cell lineage or histologic compartment reliably.
- Native WSI handling is outside this EBImage implementation.
- Batch normalization and confirmatory statistical modeling require study-specific design.
## Publication-axis and low-n display policy

The four default publication-facing figures use fixed biological ranges: 0–100% for DAB-positive area fractions and 0–300 for H-scores. Optional data-scaled `_zoomed` figures are threshold/segmentation diagnostics only. When each condition has one biological unit, the background bar shows the observed value, no SE is calculated or displayed, and the caption states that inferential analysis is not evaluable.

The eight-panel QC overview includes numeric grayscale display ranges for hematoxylin and DAB OD, a DAB-positive threshold mask, and a physical-calibration/pixel-fallback note. These display ranges affect visualization only and do not alter the underlying OD values.

