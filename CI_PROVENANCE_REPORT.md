# CI Provenance & Release Integrity Report

**Skill**: `ihc-quantification-skill`  
**Version**: `2.3.0-rc2` baseline

**Audit date**: 2026-08-27

**Result**: **SUCCESS**

## Exact release provenance

| Field | Evidence |
|---|---|
| Branch | `main` |
| Baseline commit | `8099297a6b64b975e2845aabff6c08f6ca2d8efe` |
| Immutable tag | `v2.3.0-rc2` |
| Tag target | `8099297a6b64b975e2845aabff6c08f6ca2d8efe` |
| Exact-tag CI | [Actions run 32791143505](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/32791143505) |
| CI conclusion | `SUCCESS` |
| GitHub prerelease date | 2026-08-25 |

The public `v2.3.0-rc2` tag is immutable and is not moved or recreated by the
external-validation work. Any tracked change after this baseline requires a
new candidate tag.

## Exact-tag CI verification matrix

| Workflow job | Target | Outcome |
|---|---|---|
| Static package validation | Ubuntu / Python | **PASS** |
| Public-release privacy preflight | Ubuntu / Python | **PASS** |
| Package manifest verification | Ubuntu / Python | **PASS** |
| Synthetic DAB + IF smoke test | Ubuntu / R | **PASS** |
| Synthetic DAB + IF smoke test | Windows / R 4.5.3 | **PASS** |
| IF I/O and bit-depth validation | Ubuntu / R | **PASS** |
| IF I/O and bit-depth validation | Windows / R 4.5.3 | **PASS** |
| BBBC039 official validation-partition regression | CI validation job | **PASS** |

## External-validation transition

External validation starts from the frozen baseline recorded in
`EXTERNAL_VALIDATION_BASELINE.md`. Synthetic tests remain regression evidence;
they are not reported as external biological validation. If the external gates
pass, this report will be updated with the exact `v2.3.0-rc3` main and tag CI
evidence before release.
