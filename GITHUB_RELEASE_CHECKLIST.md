# GitHub release checklist (reusable)

Apply this checklist to every release candidate. It is deliberately
version-agnostic: record the exact candidate SHA and CI run in the release
notes and in `CI_PROVENANCE_REPORT.md` rather than editing this file per
release.

## Code and tests

- [ ] `python scripts/static_validate_package.py` passes.
- [ ] `python scripts/preflight_public_release.py` passes.
- [ ] `python scripts/verify_report_consistency.py` passes (external evidence + gate/wording guards).
- [ ] `python tests/verify_summary_generator_determinism.py` passes (generated evidence rebuilds byte-identically).
- [ ] Synthetic dual-modality smoke test passes on the intended R/EBImage environment, and the working tree is unchanged afterwards (`git diff --exit-code`).
- [ ] `tests/verify_plot_contract.R` passes.
- [ ] GitHub Actions passes on Windows and Linux for the **exact** release-commit SHA (`headSha == FINAL_MAIN_SHA`, conclusion `success`).

## Figures

- [ ] Fraction figures use a 0–100% publication axis.
- [ ] H-score figures use a 0–300 publication axis.
- [ ] `n=1` captions do not claim an SE.
- [ ] Subtitles and captions are not clipped.
- [ ] Zoomed figures, when generated, are labeled as QC diagnostics.

## Privacy, licensing, and provenance

- [ ] No raw or identifiable microscopy data are committed.
- [ ] No local absolute paths or usernames remain; optional `.private_tokens.txt` preflight passes.
- [ ] Every bundled public-derived image has a verified license and per-asset provenance (`docs/assets/public_validation/provenance.csv`, `THIRD_PARTY_ASSETS.md`); "freely downloadable" is not a license.
- [ ] README examples use bundled synthetic fixtures or provenance-tracked public-derived demos only.
- [ ] The license and citation metadata are correct for the repository owner.

## Release metadata

- [ ] `VERSION`, `SKILL.md`, `DESCRIPTION` (`X-Release-Version`), `CITATION.cff`, and `CHANGELOG.md` agree.
- [ ] `RELEASE_STATUS.md` reflects the exact runtime evidence for this build, including the completed GitHub CI run.
- [ ] The release archive SHA256 is published as a sidecar asset with the GitHub prerelease.
- [ ] Immutable-tag discipline: a released tag is never moved, deleted, or recreated; release-body fixes (if any) are metadata-only (`gh release edit`), never archive replacements or tag rewrites.
