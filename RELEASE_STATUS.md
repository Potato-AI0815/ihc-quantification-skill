# Release status — IHC Quantification Skill v2.2.2

Release decision: `READY_FOR_GITHUB_CI_VALIDATION`

## Completed for this build

- v2.2 quantitative and QC core retained without formula changes;
- portable path handling added for Windows drive paths, UNC paths, Unix/macOS paths, `~`, relative paths, spaces, and non-repository working directories;
- wrapped-caption plot-contract assertion corrected with whitespace normalization;
- source examples converted to relative paths;
- public package contains only synthetic images and synthetic annotations;
- private sample tokens were removed from committed source code;
- optional local `.private_tokens.txt` scanning added;
- generated real-data reports, asset manifests, source notes, QC figures, and main figures are excluded by policy and `.gitignore`;
- static package validation: PASS;
- public-release privacy preflight: PASS;
- package manifest verification: PASS.

## Required before stable tag

1. Upload this package contents to the repository root.
2. Confirm GitHub Actions passes on Ubuntu and Windows.
3. Review uploaded CI artifacts only if a job fails.
4. Update this decision to `PASS_RUNTIME_VALIDATED_WITH_LIMITATIONS` after both synthetic jobs pass.

A CI pass validates software portability and the bundled synthetic contract. Marker-specific stain vectors, thresholds, pixel calibration, segmentation, batch stability, and histologic ROI labels remain study-specific human-validation requirements.
