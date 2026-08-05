# Runtime validation summary

## Validated private baseline

The quantitative core was exercised in a private Windows 11 environment using R 4.5.3, EBImage 4.52.0, and data.table 1.18.2.1. Two RGB fields completed without image-level errors, and the four-domain outputs, H-DAB reconstruction, masks, ROI evidence, and biological-unit aggregation were generated. A separate four-image synthetic smoke test also passed.

Only aggregate software-validation facts are retained here. The original images, identifiers, local paths, asset manifests, QC figures, and derived private-data figures are not included in the public repository.

## Confirmed safeguards

- literal condition labels are not biologically reinterpreted;
- tumor/stroma/interface identity is not inferred from a single stain;
- missing physical calibration remains an explicit QC warning;
- cells, pixels, fields, and ROIs are not counted as independent biological replicates;
- low-n paired inference is blocked;
- manual review remains required for stain separation, thresholds, segmentation, background, and exclusions.

## v2.2.2 CI candidate

v2.2.2 adds portable path handling for relative paths, Unix paths, Windows drive paths, UNC paths, tilde expansion, and paths containing spaces. It also removes embedded private-token examples, strengthens public-release scanning, and fixes the wrapped-caption plot-contract test. Run the bundled synthetic smoke test and GitHub Actions on Windows and Linux before assigning a stable release tag.

Runtime success validates software execution, not universal validity across markers, tissues, scanners, magnifications, or staining batches.
