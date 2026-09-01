# Runtime Validation Summary

## Scope

This file records where the quantitative core has actually been executed, and
what a successful run does and does not demonstrate. It is updated as part of
release-evidence normalization; the immutable validation candidate is
`v2.3.0-rc3` (tag commit `b025b3805800dbf1f6d3850e881a40c8e6ebac71`), the
`v2.3.0` tag is withdrawn because its commit still identified as `2.3.0-rc3`,
and current `main` targets canonical stable `v2.3.1` pending exact-SHA CI.

## Immutable rc3 evidence

- Exact-tag CI run [33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913)
  and same-SHA main run [33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218):
  static (incl. report-consistency and privacy preflight gates), synthetic
  dual-modality smoke test, and IF I/O contract jobs pass on Ubuntu and Windows.
- External real-data gates at rc3: BBBC013 `PASS`; BBBC007, BBBC016, and HPA
  `PASS_WITH_WARNINGS` (see `EXTERNAL_VALIDATION_MATRIX.csv`).

## Current v2.3.1 stable-candidate validation

- The frozen analysis core carries no analytical behavior change relative to
  the rc3 tag (`git diff v2.3.0-rc3` over the frozen analysis scripts shows
  only non-executable version-neutral header comments plus the exact
  allow-listed release version constant); DAB backward
  compatibility against the clean v2.2.2 baseline re-verifies at zero numeric
  deviation.
- Tracked release-evidence reports are regenerated deterministically from the
  current checkout (version from `VERSION`, date from
  `external_validation/VALIDATION_METADATA.json`), and CI fails if a tracked
  report drifts from a fresh regeneration.
- The current `main` is a **stable release candidate** for `v2.3.1`. No `v2.3.1`
  tag or stable GitHub release is claimed until exact-SHA main CI and exact-tag
  CI both pass.

## Historical runtime baseline (pre-2.3.0 line)

The quantitative core was exercised in a private Windows 11 environment using
R 4.5.3, EBImage 4.52.0, and data.table 1.18.2.1. Two RGB fields completed
without image-level errors, and the four-domain outputs, H-DAB reconstruction,
masks, ROI evidence, and biological-unit aggregation were generated. Only
aggregate software-validation facts are retained; original images, identifiers,
local paths, and private-derived figures are not in the public repository.

## Confirmed safeguards (unchanged)

- literal condition labels are not biologically reinterpreted;
- tumor/stroma/interface identity is not inferred from a single stain;
- missing physical calibration remains an explicit QC warning;
- cells, pixels, fields, and ROIs are not counted as independent biological replicates;
- low-n paired inference is blocked;
- manual review remains required for stain separation, thresholds, segmentation, background, and exclusions.

Runtime success validates software execution, not universal validity across
markers, tissues, scanners, magnifications, or staining batches.
