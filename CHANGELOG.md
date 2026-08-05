# Changelog

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
