# Public release audit — v2.2.2 CI candidate

## Included

- source code, templates, documentation, CI configuration, and synthetic fixtures;
- four synthetic PNG inputs under `tests/synthetic_fixture/images/`;
- synthetic manifest and reviewed synthetic ROI annotations.

## Excluded

- raw or derived real microscopy images;
- specimen, patient, animal, project, or local sample identifiers;
- local asset manifests, test reports, source notes, and generated QC/main figures;
- user-specific Windows, macOS, or Linux absolute paths;
- local package libraries, caches, output directories, and private token blocklists.

## Local check before every push

1. Copy `.private_tokens.example` to `.private_tokens.txt`.
2. Add any private sample identifiers, usernames, project codes, and folder tokens—one per line.
3. Run `python scripts/preflight_public_release.py`.
4. Confirm `git status --short` contains only intended source, documentation, and synthetic files.

`.private_tokens.txt` is ignored by Git and is not part of the release archive.
