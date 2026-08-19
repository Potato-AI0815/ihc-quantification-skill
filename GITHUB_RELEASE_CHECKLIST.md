# GitHub release checklist

## Code and tests

- [ ] Repository root contains the contents of `ihc-quantification-skill-repo/`, not an extra nested archive folder.

- [ ] `python scripts/static_validate_package.py` passes.
- [ ] `python scripts/preflight_public_release.py` passes.
- [ ] Synthetic smoke test passes on the intended R/EBImage environment.
- [ ] `tests/verify_plot_contract.R` passes.
- [ ] GitHub Actions passes on Windows and Linux for the v2.3.0-alpha.1 candidate.

## Figures

- [ ] Fraction figures use a 0–100% publication axis.
- [ ] H-score figures use a 0–300 publication axis.
- [ ] `n=1` captions do not claim an SE.
- [ ] Subtitles and captions are not clipped.
- [ ] Zoomed figures, when generated, are labeled as QC diagnostics.

## Privacy and provenance

- [ ] No raw or identifiable microscopy data are committed.
- [ ] No local absolute paths or usernames remain; optional `.private_tokens.txt` preflight passes.
- [ ] README examples use only the bundled synthetic fixture.
- [ ] Tumor/stroma/interface examples include reviewer provenance.
- [ ] The license and citation metadata are correct for the repository owner.

## Release metadata

- [ ] `VERSION`, `SKILL.md`, `DESCRIPTION`, `CITATION.cff`, and `CHANGELOG.md` agree.
- [ ] `RELEASE_STATUS.md` reflects the exact runtime evidence for this build, including whether GitHub CI has run.
- [ ] The release archive SHA256 is published.
