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

## v2.3.0-alpha.2 CI candidate

v2.3.0-alpha.2 adds the IF modality while retaining the v2.2.2 DAB baseline, portable path handling, private-release scanning, and the wrapped-caption plot-contract test. The local macOS R 4.6.0 dual-modality smoke test passes; GitHub Actions on Windows and Linux remains pending until this candidate is pushed. Do not assign a release-candidate or stable tag before that matrix passes.

Runtime success validates software execution, not universal validity across markers, tissues, scanners, magnifications, or staining batches.
