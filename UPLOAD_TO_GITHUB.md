# Upload to GitHub and start CI

## What to upload

Extract the release archive and upload the **contents inside** `ihc-quantification-v2.2.2/` to the repository root. Hidden entries must also be included:

- `.github/`
- `.gitattributes`
- `.gitignore`
- `.private_tokens.example`

Do not upload the ZIP itself into the repository.

## What must stay local

- `.private_tokens.txt`
- real TIFF/WSI files;
- real-data QC or main figures;
- asset manifests, local test reports, and source notes;
- `Rlib/`, `results/`, `tests/synthetic_output/`, and other generated outputs.

## Before pushing

```bash
cp .private_tokens.example .private_tokens.txt
# Add one private identifier, username, project code, or folder token per line.
python scripts/static_validate_package.py
python scripts/preflight_public_release.py
python scripts/verify_package_manifest.py
```

## Git command example

```bash
git init
git add .
git commit -m "Add IHC Quantification Skill v2.2.2 CI candidate"
git branch -M main
git remote add origin <YOUR_REPOSITORY_URL>
git push -u origin main
```

After the push, open the repository **Actions** tab. The workflow runs:

1. static structure validation;
2. public-release privacy preflight;
3. package-manifest verification;
4. synthetic R/EBImage analysis on Ubuntu;
5. synthetic R/EBImage analysis on Windows;
6. output, plot, and path-contract verification.

Do not create a stable release tag until both operating-system jobs pass.
