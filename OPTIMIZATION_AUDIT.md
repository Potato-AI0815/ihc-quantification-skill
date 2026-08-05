# IHC Quantification Skill v2.2.2 — CI-readiness audit

Date: 2026-08-05

## Scope

This maintenance build addresses cross-platform path handling and public-repository data hygiene. Core IHC formulas and four-domain output definitions are unchanged.

## Cross-platform corrections

- Added `scripts/path_utils.R` with portable absolute-path detection, tilde expansion, relative-path resolution, and safe normalization.
- Updated quantification, validation, ROI annotation, plotting, dependency installation, and test entry points.
- Replaced current-working-directory assumptions with executing-script-relative defaults.
- Hardened Bash wrappers with `${BASH_SOURCE[0]}`, quoted arrays, and `pwd -P`.
- Hardened PowerShell wrappers with `$PSScriptRoot` and argument arrays.
- Added `.gitattributes` for predictable line endings and binary image handling.
- Added a path contract test including a directory containing spaces.
- Fixed plot-contract caption matching by normalizing wrapped whitespace.

## Public-data cleanup

- The archive contains only synthetic PNG fixtures and synthetic ROI/manifest files.
- No real TIFF/WSI, generated real-data figures, asset manifests, local test reports, source notes, or user-specific absolute paths are included.
- Hard-coded private sample tokens were removed from the public preflight source.
- The preflight now supports a local ignored `.private_tokens.txt` blocklist and an optional `IHC_PRIVATE_TOKENS` environment variable.
- Public images are allowlisted to synthetic directories; unexpected images and raw microscopy formats fail preflight.
- Aggregate runtime evidence is retained without distributing source data or identifiers.

## Decision

Static validation, privacy preflight, and package-manifest verification pass. The build is ready to upload for GitHub Actions validation on Ubuntu and Windows. It should remain a CI candidate until both synthetic jobs pass.
