# CI Provenance & Release Integrity Report

**Skill**: `ihc-quantification-skill`
**Current version**: `2.3.2`
**Current state**: `PRE_RELEASE_READINESS`; exact-SHA main CI pending before any tag/release action

**Audit date**: 2026-09-01
**Result**: **VERIFIED** (v2.3.1 release provenance re-checked; v2.3.2 CI not yet claimed)

## Release lineage

| Lineage slot | Value | Status |
|---|---|---|
| Historical baseline | `v2.3.0-rc2` / `8099297a6b64b975e2845aabff6c08f6ca2d8efe` | Superseded, immutable |
| Immutable validation candidate | `v2.3.0-rc3` / `b025b3805800dbf1f6d3850e881a40c8e6ebac71` | Immutable pre-release |
| Withdrawn stable | `v2.3.0` / `708a976af38a4ed78fa59850294de3da6cb8ee18` | Preserved; release body WITHDRAWN / SUPERSEDED |
| Canonical stable | `v2.3.1` / `5f9cd52ddc32c7233180680e3623af3dd6e9f009` | Released; `prerelease = false` |
| Current patch candidate | `v2.3.2` | Pre-release readiness; no tag/release yet |

## POST_RELEASE_AUDIT — v2.3.1

| Field | Evidence |
|---|---|
| Tag target (`git rev-list -n 1 v2.3.1`) | `5f9cd52ddc32c7233180680e3623af3dd6e9f009` |
| Exact-SHA main CI | run [33504060489](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33504060489) — `success` |
| Exact-tag CI | run [33505086731](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33505086731) — `success` |
| tag-version-contract | `PASS tag-version-contract 2.3.1 == 2.3.1` |
| GitHub Release | [v2.3.1](https://github.com/Potato-AI0815/ihc-quantification-skill/releases/tag/v2.3.1); `prerelease = false` |
| Archive | `ihc-quantification-skill_v2.3.1.zip`; SHA256 `d1799d611f7945f0eb45a8dedd26eb7b7e9ae3ba0429abdb88aeadfe268a6f53` |

## v2.3.0 withdrawn release provenance

- Tag target: `708a976af38a4ed78fa59850294de3da6cb8ee18`
- Internal `VERSION` at that commit: `2.3.0-rc3`
- Tag CI: run [33388064663](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33388064663) — `success`
- Release body: `WITHDRAWN / SUPERSEDED`; marked prerelease; assets retained.
- Tag movement: none.

## Tag/internal version contract

`scripts/verify_tag_version.py` runs in CI before the frozen-core,
report-consistency, preflight, and manifest gates. Branch CI verifies internal
consistency; tag CI additionally requires `tag == VERSION`. For this branch
`VERSION == 2.3.2`.

## Exact-tag CI verification matrix (run 33505086731, verified success for v2.3.1)

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

## v2.3.2 release action

The final SHA and v2.3.2 CI runs are recorded only after they exist. No
`v2.3.2` tag or Release is created by this commit.
