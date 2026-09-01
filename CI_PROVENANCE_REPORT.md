# CI Provenance & Release Integrity Report

**Skill**: `ihc-quantification-skill`
**Current target**: `v2.3.1` canonical stable release
**Current state**: stable candidate; exact-SHA main CI and exact-tag CI required before tagging/releasing

**Audit date**: 2026-08-31
**Result**: **VERIFIED** (rc3 and v2.3.0 lineage re-checked against `git` and the GitHub API; v2.3.1 CI is pending until its final SHA is pushed)

## Release lineage

| Lineage slot | Value | Status |
|---|---|---|
| Historical baseline | `v2.3.0-rc2` / commit `8099297a6b64b975e2845aabff6c08f6ca2d8efe` | Superseded, immutable |
| Immutable validation candidate | `v2.3.0-rc3` / commit `b025b3805800dbf1f6d3850e881a40c8e6ebac71` | Immutable released pre-release |
| Historical mislabeled stable | `v2.3.0` / commit `708a976af38a4ed78fa59850294de3da6cb8ee18` | **Withdrawn / superseded; tag preserved** |
| Canonical stable target | `v2.3.1` | Pending exact-SHA CI and exact-tag CI |

`v2.3.0-rc3` and `v2.3.0` are immutable public tags: neither is moved,
deleted, or recreated. The `v2.3.0` GitHub Release body has been edited to
state `WITHDRAWN / SUPERSEDED`; its assets and checksum are preserved as part
of the historical release provenance.

## v2.3.0-rc3 exact provenance (re-verified 2026-08-31)

| Field | Evidence |
|---|---|
| Tag target (`git rev-list -n 1 v2.3.0-rc3`) | `b025b3805800dbf1f6d3850e881a40c8e6ebac71` |
| Exact-tag CI | [Actions run 33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913) |
| Exact-tag CI head SHA / conclusion | `b025b380...` / `success` (verified via GitHub API) |
| Exact-main CI (same commit, pre-release) | [Actions run 33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218) |
| Exact-main CI head SHA / conclusion | `b025b380...` / `success` (verified via GitHub API) |
| GitHub prerelease | [v2.3.0-rc3](https://github.com/Potato-AI0815/ihc-quantification-skill/releases/tag/v2.3.0-rc3), published 2026-08-29T01:23:24Z, marked pre-release |

## v2.3.0 withdrawn release provenance (verified 2026-08-31)

| Field | Evidence |
|---|---|
| Tag target (`git rev-list -n 1 v2.3.0`) | `708a976af38a4ed78fa59850294de3da6cb8ee18` |
| Internal `VERSION` at that commit | `2.3.0-rc3` |
| Exact-tag CI | run [33388064663](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33388064663) — `success` |
| Exact-main CI at same SHA | run [33385701750](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33385701750) — `success` |
| GitHub Release state | body edited to `WITHDRAWN / SUPERSEDED`; marked prerelease; assets and checksum retained |
| Tag movement | none |

## Tag/internal version contract

`scripts/verify_tag_version.py` is enforced in CI before the frozen-core,
report-consistency, preflight, and manifest gates:

- Branch CI: `VERSION`, `DESCRIPTION`, `CITATION.cff`, `SKILL.md`, and the
  `ihc_helpers.R` release constant must all agree.
- Tag CI: the pushed tag name (minus leading `v`) must equal `VERSION`.
  A future `v2.3.0`-style mismatch fails with
  `FAIL tag-version-contract tag vX.Y.Z != VERSION x.y.z-rcN`.

## Exact-tag CI verification matrix (run 33225049913, verified success)

| Workflow job | Target | Outcome |
|---|---|---|
| Static package validation | Ubuntu / Python | **PASS** |
| External report consistency gate | Ubuntu / Python | **PASS** |
| Public-release privacy preflight | Ubuntu / Python | **PASS** |
| Package manifest verification | Ubuntu / Python | **PASS** |
| Synthetic DAB + IF smoke test | Ubuntu / R | **PASS** |
| Synthetic DAB + IF smoke test | Windows / R 4.5.3 | **PASS** |
| IF I/O and bit-depth validation | Ubuntu / R | **PASS** |
| IF I/O and bit-depth validation | Windows / R 4.5.3 | **PASS** |

## Current v2.3.1 release action

The final stable SHA, exact-SHA main CI run, exact-tag CI run, archive SHA256,
and release publication are recorded in the GitHub Release body and the release
audit handoff only after they exist, so the tagged commit is not revised after
tag CI. No algorithm, scientific threshold, or validation result is changed.
