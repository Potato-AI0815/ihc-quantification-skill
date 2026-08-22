# Changelog

## 2.3.0-rc1 release candidate — 2026-08-22

- Promoted dual-modality workflow to Release Candidate (v2.3.0-rc1).
- Formally calibrated BBBC039 instance segmentation benchmark with instance RGB color decoding, deterministic greedy 1-to-1 IoU matching at IoU >= 0.5, and standard 12-column result schema.
- Standardized OME-TIFF metadata workflow support statement and documented known experimental status without blocking core TIFF/ImageJ hyperstack execution.
- Standardized colocalization disclaimer ("colocalization does not establish molecular binding") and puncta counting workflow ("validated synthetic puncta counting workflow").
- Validated cross-platform CI matrix on Ubuntu and Windows with 100% DAB backward compatibility confirmed against clean v2.2.2 baseline.

## 2.3.0-alpha.2 validation hotfix — 2026-08-21

- Recomputed the BBBC039 segmentation benchmark on the official validation
  split, decoding color-coded touching-nucleus instances and using one-to-one
  IoU matching.
- Downgraded OME-TIFF metadata-aware ingestion and packed native-12-bit TIFF to
  experimental status; validated 12-bit detector-range values in a 16-bit
  container instead.
- Added the IF bit-depth/projection contract to the cross-platform CI matrix.
- Reclassified puncta validation as synthetic aggregate-count validation, not
  full object-detector validation.
- Exact `main@ec0902d` Ubuntu/Windows CI, including the IF I/O contract, passed
  in Actions run `32555682952`.
- Final merged `main@ec0902d` rerun passed static, synthetic, and independent
  IF I/O jobs in Actions run `32555682952`.

## 2.3.0-alpha.1 release closeout — 2026-08-20

- Ignored generated IF synthetic-output directories so release staging cannot
  accidentally include rendered results.
- Unified the documented colocalization and puncta metrics with the current
  deterministic regression fixtures.
- Recorded successful Ubuntu/Windows GitHub dual-modality CI for the
  v2.3.0-alpha.1 candidate (Actions run `32331513608`).
- Updated smoke-test and upload instructions to describe the dual-modality
  v2.3.0-alpha.1 package.

## 2.3.0-alpha.1 runtime repair — 2026-08-18

- Fixed ImageJ C/Z page mapping and non-square uncompressed TIFF row
  orientation.
- Added reviewed IF include/exclude polygon masks; public FluorescentCells
  annotation pixels are excluded from segmentation without rewriting the raw
  TIFF.
- Added ROI audit output and neutral-gray exclusion rendering in the IF QC
  overview.
- Fixed optional structural/cytoplasm reference handling and empty-channel
  non-evaluable behavior.
- Re-ran the public FluorescentCells and confocal-series smoke tests and the
  complete dual-modality synthetic regression suite.

## 2.3.0-alpha.1 — 2026-08-17

### Added (Immunofluorescence Quantification Modality)
- **Modality Router**: Unified entry point (`run_quantification.R` / `run_one_click.sh`) that automatically dispatches to `run_ihc_quantification.R` or `run_if_quantification.R` based on manifest `modality`.
- **Multi-channel & Z-Stack IF Reader**: Full support for single-plane, multi-channel composite, and Z-stack TIFF/OME-TIFF formats (`X x Y`, `X x Y x C`, `X x Y x Z`, `X x Y x C x Z`). Supports max, mean, and sum projections.
- **Dynamic Range Preservation**: Preserves native 8/12/16/32-bit linear intensities with automated saturation fraction and dynamic range quality control flags (`HIGH_SATURATION`, `LOW_DYNAMIC_RANGE`).
- **Four-Compartment IF Quantification**: Outputs linear Mean Fluorescence Intensity (MFI), median intensity, integrated fluorescence intensity, and positive area fractions across `GLOBAL`, `NUCLEUS`, `CYTOPLASM`, and `EXTRACELLULAR` domains.
- **Single-Cell Scoring**: Measures cell-level nuclear MFI, cytoplasmic MFI, whole-cell MFI, and nuclear-to-cytoplasmic (N/C) ratios.
- **Dual-Channel Colocalization**: Optional module computing Pearson's correlation coefficient ($r$) and Manders' overlap coefficients ($M_1, M_2$) with spatial association disclaimer.
- **Puncta / Foci Quantification**: Optional Difference of Gaussians (DoG) filter module for counting subcellular foci ($\gamma\text{H2AX}$, LC3, FISH) per cell and per compartment.
- **Standard 8-Panel IF QC Overview**: Generates composite, raw channel, background-corrected, nuclear mask, cell propagation, positivity mask, and 4-compartment overlays.
- **Dual-Modality Synthetic Test Fixtures**: Direction-validated synthetic IF fixtures, colocalization fixtures, and puncta detection fixtures.

### Maintained (100% Backward Compatibility)
- **DAB-IHC v2.2.2 Workflow**: Preserved completely untouched with exact numerical match ($0.000000\text{e}+00$ difference against baseline v2.2.2 results).
- **Strict Modality Isolation**: Zero cross-pollution of DAB OD/H-score terminology into IF tables.

### Documentation Suite
- Added `docs/immunofluorescence_methodology.md`, `docs/if_input_guide.md`, `docs/if_channel_mapping.md`, `docs/if_segmentation_guide.md`, `docs/if_colocalization_guide.md`, `docs/if_puncta_guide.md`, `docs/if_qc_guide.md`, and `docs/if_validation_datasets.md`.
- Added configuration and manifest templates in `references/templates/`.

## v2.2.2 CI hotfix 3 — 2026-08-05

- Expose the repository-local `Rlib` to subsequent Windows R sessions in GitHub Actions.
- Invoke Linux launch scripts through `bash` so CI does not depend on a Windows-preserved executable bit.
- Make release-manifest verification robust to Git LF/CRLF normalization while keeping binary files byte-exact.
- No IHC quantification formulas, thresholds, segmentation rules, or result schemas were changed.


## 2.2.2 — 2026-08-05

### Fixed

- Removed working-directory and locally patched absolute-path assumptions from tests and entry points.
- Added portable handling for Windows drive paths, UNC paths, Unix/macOS paths, tilde expansion, relative paths, spaces, and repository execution from arbitrary directories.
- Made the plot-contract caption test robust to automatic line wrapping.
- Replaced the unqualified `copy()` call in the plot test with `data.table::copy()`.

### Public-release hygiene

- Removed embedded private specimen-token examples from committed preflight code.
- Restricted public images to approved synthetic directories and added filename, path, raw-image, large-file, and optional private-token checks.
- Added `.private_tokens.example`, `.gitattributes`, `PUBLIC_RELEASE_AUDIT.md`, and stricter `.gitignore` rules.
- Converted documentation examples to repository-relative paths.
- Retained runtime evidence only as an aggregate, de-identified software-validation summary.

### Release status

- Static validation: PASS.
- Public-release preflight: PASS.
- Package manifest verification: PASS.
- GitHub Actions Windows/Linux synthetic validation: pending upload.

## 2.2.2 — 2026-08-05

### Fixed

- Fixed publication y-axes at 0–100% for fraction metrics and 0–300 for H-scores.
- Corrected `n=1` captions so they report observed values and do not claim an SE.
- Strengthened subtitle/caption wrapping and plot margins to prevent clipping.
- Corrected release documentation to incorporate the completed v2.2 real-image and synthetic runtime evidence.

### Added

- Optional `_zoomed` data-scaled QC figures without replacing fixed-scale main figures.
- Eight-panel QC overview with OD display ranges, a thresholded DAB-positive mask, analysis/exclusion panel, and physical-scale/pixel-fallback note.
- DAB-positive binary mask output.
- Figure-manifest fields for axis range, biological-unit counts, repeated-unit counts, and error-bar status.
- Dedicated plot-contract test.
- GitHub CI for Windows/Linux, MIT license, citation metadata, contribution/security files, privacy preflight, release checklist, and a direct-dependency renv baseline.

### Release status

- v2.2 runtime baseline: PASS with documented limitations.
- v2.2.2 static and privacy checks: PASS.
- v2.2.2 synthetic retest: required before stable tag.

## 2.2.0 — 2026-08-05

### Added

- Four explicit measurement domains inside every analyzed ROI: global tissue, nucleus, cytoplasm, and extracellular tissue.
- Separate nuclear, cytoplasmic, and whole-cell intensity classes and H-scores.
- Pixel-level positive area, positive mean OD, and integrated OD for all four spatial domains.
- H-DAB reconstruction, six-panel image QC, RGB/H-DAB domain overlays, binary masks, fixed semantic colors, and a QC color-legend table.
- Per-ROI RGB, H-DAB, and color-overlay evidence crops plus RGB/H-DAB overview proofs.
- Four automatic main figures with neutral summary bars, biological-unit points, repeated-unit connecting lines, conditional error bars, source CSV files, and a figure manifest.
- `ihc_primary_domain_summary_long.csv`, `ihc_design_summary.csv`, `ihc_manual_qc_template.csv`, `ihc_metric_dictionary.csv`, and `ihc_qc_color_legend.csv`.
- Explicit low-n paired status: `NOT_EVALUABLE_N_LT_2`.
- Configurable plot summary (`mean`/`median`) and error bars (`se`/`sd`/`iqr`/`none`).
- Non-fatal empty-domain plotting: no finite values produce a labeled placeholder and `plot_status=NO_FINITE_VALUES_PLACEHOLDER` instead of terminating the numeric run.
- Expanded synthetic output verifier for four-domain metrics, QC assets, figures, and paired status.

### Changed

- Global and extracellular main figures use pixel-based DAB burden rather than an inappropriate generic H-score.
- Nuclear and cytoplasmic H-scores are calculated independently of the configured backward-compatible scoring domain.
- Condition order defaults to manifest order when exactly two conditions are present.
- Stain-channel, QC-overview, ROI-triplet, and main-plot generation are enabled by default.
- One-click wrappers accept optional condition order and local R library arguments.
- The interactive annotation tool uses the same fixed semantic colors as downstream QC and requires a reviewer for tumor/stroma/interface labels.
- Local R library paths are passed through input validation, quantification, plotting, and annotation entry points.

### Fixed

- Removed collision-prone `data.table` `..image_id` and `..compartment` lookups from core scripts for compatibility with the tested R 4.5.3/data.table 1.18.2.1 environment.
- Removed project-specific IMM/EMM and plasma-cell assumptions from the generic package.
- Exact sign-flip P values are no longer reported for a single paired biological unit.
- Multi-condition datasets no longer silently select the first two labels for paired-effect calculations.

### Validation status

- Static package validation: PASS.
- v2.1 core runtime was previously exercised under R 4.5.3 + EBImage 4.52.0 on real and synthetic images.
- v2.2 requires a fresh runtime smoke test because it adds new QC rendering, domain-specific metrics, and automatic figures.

## 2.1.0 — 2026-08-05

- Rebuilt the original project-specific workflow as a generic whole-tissue-first IHC quantification framework.
