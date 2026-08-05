---
name: ihc-quantification
version: 2.2.2
description: Reproducible, auditable quantification of DAB/hematoxylin brightfield IHC images. The default analysis is whole-tissue global quantification, followed by four explicit measurement domains (global tissue, nucleus, cytoplasm, extracellular tissue), H-DAB reconstruction, color-coded QC overlays, ROI evidence crops, biological-unit aggregation, and four separate bar-background paired-point comparison figures.
---

# IHC Quantification Skill v2.2.2

## Purpose

Use this skill to quantify chromogenic DAB/hematoxylin IHC images exported as RGB TIFF, OME-TIFF, PNG, or JPEG fields/tiles. The workflow is designed for reproducible research quantification, not diagnosis.

The default primary analysis is **GLOBAL whole-tissue quantification after documented exclusions**. Manual ROI selection is not required to obtain a result. Optional reviewed ROIs may be supplied for tumor, stroma, interface, custom, or other spatial comparisons.

This EBImage implementation is intended for microscopy fields or manageable tiles. Do not load native `.svs`, `.ndpi`, `.mrxs`, `.scn`, or similarly large whole-slide files directly. Export tiles, annotations, or masks from QuPath or another WSI reader first.

## Non-negotiable analytical contract

1. Keep raw images read-only and unchanged.
2. Use `biological_unit_id`—patient, animal, specimen, organoid, or other declared independent unit—as the inferential unit.
3. Treat images, fields, ROIs, pixels, nuclei, and cells as nested measurements, not independent sample size.
4. Always generate a `GLOBAL` whole-tissue result after applying explicit exclusion masks.
5. Always quantify four **measurement domains** inside every analyzed region:
   - `global`: all analyzed tissue pixels;
   - `nucleus`: segmented nuclear pixels and nuclear cell scores;
   - `cytoplasm`: propagated cell pixels excluding nuclei and cytoplasmic cell scores;
   - `extracellular`: analyzed tissue outside propagated cell masks.
6. Keep **ROI compartment** and **measurement domain** separate:
   - ROI compartments describe *where* the measurement was taken, such as global, tumor, stroma, interface, or custom;
   - measurement domains describe *what spatial component* was measured inside that ROI.
7. Never infer tumor, stroma, interface, or a cell lineage from DAB/hematoxylin morphology alone. These labels require reviewed manual annotations or an externally validated segmentation model.
8. Every selected or excluded ROI must retain source-image coordinates, area, action, provenance, review state, overview outline, H-DAB proof image, and local evidence crops.
9. Do not assign H-score to extracellular tissue. H-score is a cell-based score; extracellular signal is reported with pixel-based DAB burden metrics.
10. Do not claim statistical significance when the biological-unit sample size is inadequate. With fewer than two paired units, paired inference is marked `NOT_EVALUABLE_N_LT_2`.
11. All images requiring manual review remain non-final until segmentation, threshold, background, and compartment overlays are approved.
12. Publication-facing fraction figures use a fixed 0–100% y-axis and H-score figures use a fixed 0–300 y-axis. Data-scaled zoomed figures are optional QC diagnostics and must be labeled as such.
13. When each condition contains one biological unit, the bar represents the observed value, no SE is calculated or claimed, and the caption states that inference is not evaluable.
14. Public repositories must contain only synthetic or explicitly authorized de-identified examples; raw clinical images, specimen identifiers, local absolute paths, and private asset manifests are excluded.

## Default four-result framework

The one-click run automatically creates four separate main figures for the GLOBAL ROI compartment:

| Figure | Measurement domain | Default metric | Interpretation |
|---|---|---|---|
| 1 | Global tissue | `tissue_positive_area_fraction` | Pixel-based DAB-positive tissue burden |
| 2 | Nucleus | `nuclear_h_score` | Cell-based nuclear H-score, 0–300 |
| 3 | Cytoplasm | `cytoplasm_h_score` | Cell-based cytoplasmic H-score, 0–300 |
| 4 | Extracellular | `extracellular_positive_area_fraction` | Pixel-based DAB burden outside propagated cells |

Each figure uses:

- a neutral summary bar in the background;
- one point per biological unit;
- connecting lines for biological units repeated across conditions;
- an error bar only for conditions with at least two finite biological-unit values;
- a caption stating per-condition sample sizes, the number of repeated units, the summary statistic, the conditional error-bar definition, and whether the display is descriptive only.

Publication defaults are fixed at **0–100%** for global/extracellular fractions and **0–300** for nuclear/cytoplasmic H-scores. This prevents automatic y-axis zoom from visually exaggerating small values. Set `generate_zoomed_plots=true` only to create additional `_zoomed` QC diagnostics; these do not replace the fixed-scale main figures.

Default bars show the mean and error bars show the standard error where `n>=2`. If every condition has `n=1`, bars show the observed value and no error bar is drawn or claimed. Configure `plot_summary_stat` and `plot_errorbar` to use median/IQR, mean/SD, or no error bar.

## H-score definition

For a selected cellular domain, each segmented cell is classified using local-background-corrected mean DAB optical density:

- `0`: below the negative threshold;
- `1+`: negative threshold to weak threshold;
- `2+`: weak threshold to moderate threshold;
- `3+`: at or above the moderate threshold.

The H-score is:

`100 × mean(intensity-class weight)`

where weights are 0, 1, 2, and 3. The theoretical range is 0–300.

The workflow calculates nuclear, cytoplasmic, and whole-cell intensity classes separately for every cell. The configured `cell_scoring_domain` remains the marker-specific backward-compatible score, while v2.2.2 also reports `nuclear_h_score`, `cytoplasm_h_score`, and `whole_cell_h_score` explicitly.

## Marker-localization decision

Set `cell_scoring_domain` before analysis:

- `nucleus`: transcription factors, proliferation markers, and clearly nuclear targets;
- `cytoplasm`: cytoplasmic proteins and diffuse intracellular DAB;
- `whole_cell`: diffuse targets where nuclear/cytoplasmic separation is not biologically meaningful.

A generic membrane H-score is **not** claimed. Membranous markers require a validated membrane-ring or membrane-completeness algorithm specific to the marker and tissue.

## Inputs

### 1. Image manifest

One row per image.

Required columns:

`image_id, biological_unit_id, condition, field_id, source_file`

Recommended columns:

`batch_id, marker, tissue_type, magnification, pixel_size_um, is_negative_control, analysis_status`

Legacy aliases `patient_id`, `animal_id`, `sample_id`, `field`, and `image_field` are normalized.

`pixel_size_um` is strongly recommended. Without physical calibration, the workflow uses explicit pixel fallbacks and writes `MISSING_PIXEL_SIZE_CALIBRATION` to QC. Pixel fallbacks must not be transferred across magnifications, scanners, or acquisition batches without validation.

Template: `references/templates/manifest_template.csv`

### 2. Optional ROI annotations

Columns:

`image_id, roi_id, compartment, action, selection_source, selection_method, reviewer, annotation_status, vertex_order, x, y`

Rules:

- `action=include` creates a named analysis region;
- `action=exclude` removes scale bars, text, blank glass, folds, necrosis, debris, or other prespecified artifacts from GLOBAL analysis;
- only `selected`, `reviewed`, or `approved` annotations are analyzed;
- `draft` and `rejected` annotations are ignored;
- tumor, stroma, and interface labels require a non-automatic source and a reviewer;
- coordinates are source-image pixels, not resized display coordinates;
- out-of-bounds coordinates fail validation;
- overlapping include ROIs are audited because the same pixels/cells may otherwise contribute more than once.

Template: `references/templates/roi_annotations_template.csv`

### 3. Optional analysis configuration

Two columns:

`parameter,value`

Template: `references/templates/analysis_parameters_template.csv`

Important parameters include:

- physical and pixel-fallback nucleus size thresholds;
- cell propagation radius;
- local background ring dimensions;
- DAB intensity thresholds;
- `cell_scoring_domain`;
- QC thresholds;
- overlay alpha;
- automatic QC and plot generation;
- `plot_axis_mode`, `generate_zoomed_plots`, subtitle/caption wrapping widths;
- plot summary and conditional error-bar definitions;
- DAB-positive-mask display and OD visualization quantile.

## One-click execution

### Windows

```powershell
.\run_one_click.ps1 `
  -Manifest ".\input\image_manifest.csv" `
  -Outdir ".\results\ihc_run" `
  -Roi ".\input\roi_annotations.csv" `
  -Config ".\input\analysis_parameters.csv" `
  -LocalLib ".\Rlib" `
  -ConditionOrder "control,treatment"
```

Or:

```cmd
run_one_click.cmd image_manifest.csv ihc_results roi_annotations.csv analysis_parameters.csv Rlib control,treatment
```

### Linux/macOS

```bash
bash run_one_click.sh \
  image_manifest.csv \
  ihc_results \
  roi_annotations.csv \
  analysis_parameters.csv \
  Rlib \
  control,treatment
```

The ROI, config, local library, and condition order arguments are optional. When exactly two conditions are present and no order is supplied, manifest order is retained.

### Direct R execution

```bash
Rscript scripts/run_ihc_quantification.R \
  --manifest=/absolute/path/image_manifest.csv \
  --roi=/absolute/path/roi_annotations.csv \
  --config=/absolute/path/analysis_parameters.csv \
  --outdir=/absolute/path/ihc_results \
  --condition-order=control,treatment
```

Useful switches:

```text
--local-lib=/absolute/path/Rlib
--qc-limit=0                     # 0 = QC output for every image
--write-stain-channels=true
--generate-qc-overview=true
--generate-roi-triplets=true
--generate-main-plots=true
--axis-mode=fixed                # standalone plotting helper
--generate-zoomed-plots=false    # QC diagnostic only
```

## Interactive ROI annotation

```bash
Rscript scripts/annotate_ihc_rois.R \
  --manifest=/absolute/path/image_manifest.csv \
  --image-id=S01_TREAT_F1 \
  --roi=/absolute/path/roi_annotations.csv \
  --roi-id=stroma_1 \
  --compartment=stroma \
  --shape=rectangle \
  --action=include \
  --reviewer=Reviewer01 \
  --local-lib=/absolute/path/Rlib
```

Polygon mode is available with `--shape=polygon`. The annotation tool uses the fixed semantic ROI color, saves source-image vertices and an immediate visual proof, and requires `--reviewer` for tumor/stroma/interface labels. The main workflow subsequently generates RGB and H-DAB overview proofs plus local evidence crops.

## QC visualization contract

Every analyzed image receives an H-DAB reconstruction and color-coded domain overlays.

Fixed color semantics:

| Domain/ROI | Color |
|---|---|
| Global tissue | Blue |
| Nucleus | Red |
| Cytoplasm | Green |
| Extracellular tissue | Orange |
| Exclude/artifact | Gray |
| Tumor ROI | Purple |
| Stroma ROI | Cyan |
| Interface ROI | Yellow |
| Other custom ROI | Magenta |

The QC overview contains eight panels:

1. original RGB;
2. H-DAB reconstruction;
3. hematoxylin OD with a displayed grayscale OD range;
4. DAB OD with a displayed grayscale OD range;
5. thresholded DAB-positive pixels on the H-DAB base;
6. nuclear and propagated-cell segmentation;
7. global/nuclear/cytoplasmic/extracellular/exclude domains on the H-DAB base;
8. analyzed tissue boundary and recorded exclusion regions.

The QC footer records whether physical calibration or pixel fallback was used. A visible scale bar embedded in the source image is not treated as programmatic `pixel_size_um` calibration; it must be excluded from measurement if it overlaps the analyzed field.

For each ROI, the workflow writes local RGB, H-DAB, and color-overlay/selection crops. These are evidence of where and how the comparison region was selected; they are not decorative images.

## Output structure

```text
ihc_results/
  config/
    analysis_parameters_used.csv
    image_manifest_used.csv
    roi_annotations_used.csv
    effective_image_parameters.csv
  source_data/
    ihc_region_summary.csv
    ihc_biological_unit_summary.csv
    ihc_primary_domain_summary_long.csv
    ihc_cell_measurements.csv.gz
    ihc_cell_region_membership.csv.gz
    ihc_image_qc.csv
    ihc_manual_qc_template.csv
    ihc_roi_registry.csv
    ihc_roi_overlap_audit.csv
    ihc_design_summary.csv
    ihc_paired_effects.csv
  qc/
    qc_overview/
    compartment_overlays/
    segmentation_overlays/
    stain_channels/
    masks/
      *_global_mask.png
      *_nucleus_mask.png
      *_cytoplasm_mask.png
      *_extracellular_mask.png
      *_exclude_mask.png
      *_dab_positive_mask.png
    roi_evidence/
      crops/
  figures/
    main/
      ihc_main_01_global_dab_burden.png|svg|pdf
      ihc_main_02_nuclear_h_score.png|svg|pdf
      ihc_main_03_cytoplasmic_h_score.png|svg|pdf
      ihc_main_04_extracellular_dab_burden.png|svg|pdf
      ihc_main_*_zoomed.png|svg|pdf       # optional QC diagnostics only
      ihc_main_figure_manifest.csv
    supporting/
  work/
    input_validation.tsv
    image_errors.tsv
    run_summary.md
    R_sessionInfo.txt
```

If multiple marker/tissue/batch combinations are present, the four figures are written in separate group subdirectories.

## Core numeric outputs

### Pixel-based metrics

For global tissue, nuclei, cytoplasm, and extracellular tissue:

- area in pixels;
- DAB-positive area in pixels;
- DAB-positive area fraction;
- mean DAB OD;
- mean OD among positive pixels;
- integrated DAB OD.

### Cell-based metrics

For nuclear, cytoplasmic, whole-cell, and configured scoring domains:

- positive-cell fraction;
- H-score;
- mean and median cell DAB OD;
- per-cell local background OD;
- per-cell intensity class;
- raw and background-corrected domain measurements.

## Biological-unit aggregation

Multiple fields or ROIs from the same biological unit and condition are aggregated using area- or cell-count-weighted summaries as appropriate. The output retains image counts, region counts, cell counts, ROI compartment, marker, tissue type, and batch.

Do not replace the biological-unit aggregation with cell-level or ROI-level hypothesis testing.

## Paired effects

Paired effects are generated only when:

- exactly two conditions are present; or
- exactly two conditions are explicitly supplied through `--condition-order`.

The difference is calculated as:

`comparison condition − reference condition`

With fewer than two paired biological units:

- descriptive differences are retained;
- `inferential_status=NOT_EVALUABLE_N_LT_2`;
- exact sign-flip P value is `NA`.

For larger confirmatory studies, use a prespecified statistical model outside this plotting helper, accounting for pairing, batches, repeated fields, and multiplicity where applicable.

## Mandatory QC before interpretation

Review every flagged image and at least one complete QC set per biological unit. Confirm that:

- glass, scale bars, text, folds, necrosis, and artifacts are excluded without removing true tissue;
- the H-DAB reconstruction reflects plausible stain separation;
- hematoxylin and DAB OD panels have plausible displayed ranges and the DAB-positive threshold mask matches visible stain;
- the source-image scale bar/label is excluded from measurement where required, and visible scale-bar text is not mistaken for physical calibration;
- nuclei are not systematically merged, split, missed, or over-segmented;
- propagated cells do not cross neighboring cells or absorb large extracellular spaces;
- nuclear, cytoplasmic, and extracellular overlays correspond to the intended masks;
- high extracellular DAB is not misreported as intracellular signal;
- ROI borders and local evidence crops correspond to the intended source-image coordinates;
- included ROI overlaps are absent or explicitly justified;
- thresholds are supported by negative controls, batch validation, or a prespecified sensitivity analysis;
- physical scale or pixel-fallback use is appropriate;
- biological-unit aggregation is complete;
- low-n results are described without inferential claims.

Record decisions in `ihc_manual_qc_template.csv`. Do not edit numeric outputs manually. Revise annotations or parameters and rerun from raw images.

## Threshold and batch validation

A fixed OD threshold is reproducible only within a validated staining/scanning workflow. Before publication or clinical cutoff use:

1. include negative and positive controls where possible;
2. verify stain separation and background by batch;
3. inspect intensity distributions and segmentation overlays;
4. prespecify thresholds or calibrate them on an independent training set;
5. perform threshold sensitivity analyses;
6. avoid choosing thresholds after inspecting group differences;
7. report scanner, magnification, pixel size, antibody, staining batch, and software version.

## Interpretation guardrails

- Positive area fraction, mean OD, integrated OD, positive-cell fraction, and H-score are not interchangeable.
- Global and extracellular defaults are pixel-based burden metrics.
- Nuclear and cytoplasmic defaults are cell-based H-scores.
- Extracellular tissue is not automatically “stroma.”
- A single-stain image cannot establish cell identity.
- Whole-tissue analysis reduces ROI cherry-picking but does not eliminate segmentation or threshold bias.
- Rectangle ROIs are acceptable for standardized fields; irregular histologic structures should use polygons or imported masks.
- Hotspot analysis is secondary/exploratory unless prespecified and requires a documented sampling rule.
- The workflow does not make diagnostic, prognostic, or therapeutic claims.

## Failure and fallback behavior

- Missing files, duplicate image IDs, invalid coordinates, unsupported WSI formats, and invalid ROI provenance fail input validation.
- Image-level failures are recorded in `work/image_errors.tsv`.
- If all images fail, the run stops.
- Missing physical calibration triggers pixel fallback and a QC flag.
- Missing or invalid named-compartment provenance stops the analysis.
- Overlapping included ROIs are retained in the audit but force manual review.
- Plot generation is enabled by default and is part of a complete run. Disable it only for debugging with `--generate-main-plots=false`. If a domain has no finite biological-unit values, the workflow writes a clearly labeled placeholder figure and records `plot_status=NO_FINITE_VALUES_PLACEHOLDER` instead of aborting the numeric analysis.
- Main figures use `plot_axis_mode=fixed` by default. `plot_axis_mode=data` is diagnostic, not the publication default.
- `generate_zoomed_plots=true` writes separate `_zoomed` files and never overwrites fixed-scale main figures.

## Runtime compatibility

v2.2.2 retains the v2.2 removal of collision-prone `data.table` lookups such as `..image_id` and `..compartment` from the core workflow. This directly incorporates the compatibility issue observed under R 4.5.3 and data.table 1.18.2.1.

Required packages:

- `EBImage`
- `data.table`
- `ggplot2`
- `ragg`
- `svglite`

Install once:

```bash
Rscript scripts/install_dependencies.R --lib=/absolute/path/Rlib
```

## Validation

Static package validation:

```bash
python scripts/static_validate_package.py
```

Synthetic runtime validation:

```bash
bash tests/run_synthetic_smoke_test.sh
```

or:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_synthetic_smoke_test.ps1
```

The smoke test verifies software wiring, four-domain metrics, fixed biological axes, correct `n=1` captions, four main figures, eight-panel H-DAB/QC outputs, DAB-positive masks, ROI evidence, aggregation, and paired-effect status. It is not a biological validation dataset.

Public-release privacy preflight:

```bash
python scripts/preflight_public_release.py
```

## Publication reporting minimum

Report:

- independent biological unit and nesting structure;
- number of biological units, images, fields, ROIs, and cells;
- marker localization and scoring domain;
- image format, scanner/microscope, magnification, and pixel size;
- H-DAB method and stain vectors;
- tissue, nucleus, cell, and extracellular mask methods;
- DAB thresholds and how they were selected;
- local background correction;
- exclusion and ROI annotation rules;
- QC acceptance criteria and blinded review where applicable;
- primary metric and whether analyses were paired;
- software, package, skill version, and configuration files.

## Agent execution rules

When invoking this skill:

1. validate inputs before quantification;
2. do not reinterpret condition labels without user confirmation;
3. run GLOBAL analysis even when optional ROIs are present;
4. generate H-DAB and color-coded QC for every analyzed image unless explicitly disabled for debugging;
5. generate the four separate default result figures;
6. surface all QC warnings and low-n limitations;
7. never call extracellular tissue “stroma” without reviewed provenance;
8. never report H-score for extracellular tissue;
9. never promote a smoke test or unapproved QC run to a biological conclusion;
10. preserve source data and configuration needed to reproduce every figure.

## GitHub/public-release contract

Before a public tag or release:

1. run static validation, privacy preflight, and the synthetic smoke test;
2. confirm GitHub Actions passes on Windows and Linux;
3. publish only synthetic examples unless real data have explicit authorization and complete de-identification;
4. verify `VERSION`, `SKILL.md`, `DESCRIPTION`, `CITATION.cff`, `CHANGELOG.md`, and `RELEASE_STATUS.md` agree;
5. review `GITHUB_RELEASE_CHECKLIST.md` and publish the archive SHA256;
6. do not describe this generic workflow as validated across all tissues, antibodies, scanners, or staining batches.

The repository includes MIT licensing, citation metadata, contribution guidance, a privacy preflight, a direct-dependency `renv.lock` baseline, and GitHub Actions. The lockfile is a release baseline for direct dependencies; archive the complete local `sessionInfo()` and configuration with each study run.
