# IHC Quantification Skill v2.2.2

A reproducible and auditable R/EBImage workflow for DAB/hematoxylin brightfield IHC research images.

The workflow is global-first, supports reviewed ROIs, quantifies global tissue, nuclear, cytoplasmic, and extracellular domains, and produces H-DAB QC plus four biological-unit-level comparison figures. Publication-facing fraction axes are fixed at 0–100% and H-score axes at 0–300. Data-scaled zoomed plots are optional QC diagnostics only. When each condition has one biological unit, the caption reports observed values and does not claim an SE.

Run the bundled synthetic smoke test before real data:

```bash
bash tests/run_synthetic_smoke_test.sh
```

Do not commit real microscopy images, specimen identifiers, local absolute paths, or unreviewed outputs to a public repository. See `SKILL.md`, `GITHUB_RELEASE_CHECKLIST.md`, and `RELEASE_STATUS.md` for the complete contract.

Before pushing, copy `.private_tokens.example` to `.private_tokens.txt`, add one private identifier or local path token per line, and run:

```bash
python scripts/static_validate_package.py
python scripts/preflight_public_release.py
python scripts/verify_package_manifest.py
```

Only the bundled synthetic images are intended for public distribution. GitHub Actions runs the synthetic workflow on Ubuntu and Windows.
