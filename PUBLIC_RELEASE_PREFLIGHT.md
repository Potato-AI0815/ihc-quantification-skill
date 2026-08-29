# Public Release Preflight Audit

**Package**: `ihc-quantification-skill`
**Version**: `2.3.0-rc3`
**Date**: 2026-08-29
**Result**: **PASS**

---

## Preflight Verification Checklist

- [x] **No Private Tokens**: Zero API keys, private tokens, or credentials found.
- [x] **No Local User Paths**: Zero hardcoded local absolute paths in codebase.
- [x] **No Raw Clinical Microscopy**: No raw or identifiable clinical/specimen microscopy is bundled; raw external-validation datasets (BBBC, HPA, CIL originals) remain out of the repository.
- [x] **Approved Synthetic Fixture Images**: Deterministic, in-repo synthetic fixture images may be bundled.
- [x] **Approved Derived Public-Validation Demo Images**: Small derived demo/QC figures from explicitly licensed public datasets (Cell Image Library CIL:45501 — Public Domain; Broad BBBC007v1 — CC0 1.0 Public Domain) may be bundled, each with per-asset provenance and attribution in `docs/assets/public_validation/provenance.csv` and `THIRD_PARTY_ASSETS.md`.
- [x] **Third-Party License Enforcement**: Every bundled public-derived image must carry a verified allow-listed license (Public Domain / CC0 / CC BY 4.0); "freely downloadable" is not accepted as a license, and unverifiable-license assets are removed rather than assumed.
- [x] **Binary Integrity**: All source scripts, templates, and fixtures are verified against `PACKAGE_MANIFEST.sha256`.
- [x] **Research Use Only**: RUO disclaimers clearly embedded in `README.md`, `README_EN.md`, `SKILL.md`, and documentation suite.
