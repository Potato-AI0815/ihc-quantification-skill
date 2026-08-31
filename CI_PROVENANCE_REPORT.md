# CI Provenance & Release Integrity Report

**Skill**: `ihc-quantification-skill`
**Current public release candidate**: `v2.3.0-rc3`

**Audit date**: 2026-08-29
**Result**: **VERIFIED** (all values below re-checked against `git` and the GitHub API at audit time; nothing is copied from earlier reports)

## Release lineage

| Lineage slot | Value | Status |
|---|---|---|
| Historical baseline | `v2.3.0-rc2` / commit `8099297a6b64b975e2845aabff6c08f6ca2d8efe` | Superseded, immutable |
| **Current release candidate** | **`v2.3.0-rc3` / commit `b025b3805800dbf1f6d3850e881a40c8e6ebac71`** | **Immutable released tag** |
| Post-rc3 `main` | Advances with stable-preparation commits (`fix(stable-prep): ...`) | Moving branch state |

`v2.3.0-rc3` is the immutable released candidate: the tag is never moved,
deleted, or recreated, and the released commit is never amended. Post-rc3
`main` is a stable-preparation branch state whose HEAD SHA is intentionally
different from the rc3 tag SHA; the two must never be conflated in provenance
records.

## v2.3.0-rc3 exact provenance (re-verified 2026-08-29)

| Field | Evidence |
|---|---|
| Tag target (`git rev-list -n 1 v2.3.0-rc3`) | `b025b3805800dbf1f6d3850e881a40c8e6ebac71` |
| Expected previous audit value | `b025b3805800dbf1f6d3850e881a40c8e6ebac71` — **match** |
| Exact-tag CI | [Actions run 33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913) |
| Exact-tag CI head SHA / conclusion | `b025b380...` / `success` (verified via GitHub API) |
| Exact-main CI (same commit, pre-release) | [Actions run 33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218) |
| Exact-main CI head SHA / conclusion | `b025b380...` / `success` (verified via GitHub API) |
| GitHub prerelease | [v2.3.0-rc3](https://github.com/Potato-AI0815/ihc-quantification-skill/releases/tag/v2.3.0-rc3), published 2026-08-29T01:23:24Z, marked pre-release |
| Release archive | `ihc-quantification-skill_v2.3.0-rc3.zip` + SHA-256 sidecar asset |

Note: tag run [33224653801](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33224653801)
and branch run 33224651655 were triggered by the transient pre-scrub commit
`70fe0508` (privacy preflight failure on local absolute paths in the archived
review handover). That commit was superseded by `b025b380` before release; the
failing runs are retained as history and describe no released artifact.

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

## Post-rc3 stable-preparation work

Post-rc3 `main` commits are restricted to non-algorithmic work: documentation,
validation scripts, reporting generators, report-consistency tests, metadata,
checkpoint/resume implementation, and CI validation logic. The frozen analysis
scripts must carry no analytical behavior change relative to the rc3 tag
(`git diff v2.3.0-rc3 -- <core>` may show, at most, non-executable
version-neutral header comments). No stable tag and no stable GitHub release
are created from this work; the next release action is a final stable review.
