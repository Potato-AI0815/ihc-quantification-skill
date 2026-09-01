# Public release audit — current v2.3.1 stable-release recovery state

**Scope**: what the repository bundles and excludes, as enforced by
`scripts/preflight_public_release.py` and `THIRD_PARTY_ASSETS.md`. The
validation evidence originates from the immutable candidate `v2.3.0-rc3`; `v2.3.0` is a withdrawn historical release identity; current `main` targets the canonical stable version `v2.3.1` and makes no stable tag/release claim until exact-SHA CI and exact-tag CI pass.

## Included

- source code, templates, documentation, CI configuration, and deterministic synthetic fixtures;
- four synthetic PNG inputs under `tests/synthetic_fixture/images/` plus generated-at-test-time IF/coloc/puncta fixtures (fixture TIFF inputs are generated, not committed);
- small derived demo/QC figures from explicitly licensed public datasets, each with per-asset provenance: Cell Image Library CIL:45501 (Public Domain) and Broad BBBC007v1 (CC0 1.0 Public Domain) — see `docs/assets/public_validation/provenance.csv` and `THIRD_PARTY_ASSETS.md`;
- synthetic manifest and reviewed synthetic ROI annotations.

## Excluded

- raw external-validation datasets and raw microscopy of any origin (BBBC/HPA/CIL originals stay out of the repository);
- raw or private clinical/specimen microscopy, and any specimen, patient, animal, project, or local sample identifiers;
- local asset manifests, test reports, source notes, and generated per-run QC/main figures;
- user-specific Windows, macOS, or Linux absolute paths;
- local package libraries, caches, output directories, and private token blocklists;
- public-derived images without verified license provenance (the ImageJ "FluorescentCells" sample-derived QC figure was removed on 2026-08-29 for exactly this reason; see `THIRD_PARTY_ASSETS.md`).

## Local check before every push

1. Copy `.private_tokens.example` to `.private_tokens.txt`.
2. Add any private sample identifiers, usernames, project codes, and folder tokens—one per line.
3. Run `python scripts/preflight_public_release.py`.
4. Confirm `git status --short` contains only intended source, documentation, synthetic, and provenance-tracked public-derived files.
