# GitHub release checklist

## Code and tests

- [x] Repository root contains the contents of `ihc-quantification-skill-repo/`, not an extra nested archive folder.

- [x] `python scripts/static_validate_package.py` passes.
- [x] `python scripts/preflight_public_release.py` passes.
- [x] Synthetic smoke test passes on the intended R/EBImage environment.
- [x] `tests/verify_plot_contract.R` passes.
- [ ] GitHub Actions passes on Windows and Linux for the v2.3.0-alpha.2 candidate (exact main-commit run pending).

## Figures

- [x] Fraction figures use a 0–100% publication axis.
- [x] H-score figures use a 0–300 publication axis.
- [x] `n=1` captions do not claim an SE.
- [x] Subtitles and captions are not clipped.
- [x] Zoomed figures, when generated, are labeled as QC diagnostics.

## Privacy and provenance

- [x] No raw or identifiable microscopy data are committed.
- [x] No local absolute paths or usernames remain; optional `.private_tokens.txt` preflight passes.
- [x] README examples use only the bundled synthetic fixture.
- [x] Tumor/stroma/interface examples include reviewer provenance.
- [x] The license and citation metadata are correct for the repository owner.

## Release metadata

- [x] `VERSION`, `SKILL.md`, `DESCRIPTION`, `CITATION.cff`, and `CHANGELOG.md` agree.
- [x] `RELEASE_STATUS.md` reflects the exact runtime evidence for this build, including the completed GitHub CI run.
- [ ] The release archive SHA256 is published as a sidecar asset with the GitHub prerelease.
