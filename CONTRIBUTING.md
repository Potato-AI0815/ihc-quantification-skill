# Contributing

Contributions are welcome when they preserve the scientific and auditability contracts in `SKILL.md`.

## Before opening a pull request

1. Do not commit identifiable specimens, raw clinical images, local absolute paths, or unreviewed real-data outputs.
2. Run `python scripts/static_validate_package.py`.
3. Run `python scripts/preflight_public_release.py`.
4. Run the synthetic test with `tests/run_synthetic_smoke_test.ps1` or `tests/run_synthetic_smoke_test.sh`.
5. Add or update a focused test for every behavioral change.
6. Update `CHANGELOG.md` and, when applicable, `SKILL.md`.

## Scientific constraints

- Keep `GLOBAL` whole-tissue analysis as the default.
- Do not infer tumor, stroma, interface, or cell identity from a single DAB stain without reviewed provenance.
- Do not treat cells, fields, tiles, or ROIs as independent biological replicates.
- Do not use H-score for extracellular tissue.
- Keep publication-facing fraction axes at 0–100% and H-score axes at 0–300 unless a user explicitly requests a diagnostic zoom.
- Preserve raw numeric outputs and rerun from source images rather than editing results manually.

## Bug reports

Include the skill version, operating system, R version, package versions, a synthetic or de-identified reproducer, the command used, and the relevant error log. Never attach identifiable clinical material to a public issue.
