# Final Release Decision — IHC & Immunofluorescence Quantification Skill

**Current target**: `v2.3.1`
**Current state**: STABLE RELEASE CANDIDATE — RECOVERY FROM v2.3.0 IDENTITY MISMATCH
**Decision date**: 2026-08-31
**Decision**: **`APPROVED FOR STABLE RELEASE`**
**Gate**: **`PENDING EXACT-SHA MAIN CI AND TAG CI`**

> `v2.3.0` remains preserved as historical provenance but is **withdrawn** as
> a canonical stable release: its tag commit still identified the software
> internally as `2.3.0-rc3`. The scientific calculations and validation
> results are unaffected. The canonical stable release is `v2.3.1`.

---

## 1. Current state summary

1. **Immutable validation candidate**: `v2.3.0-rc3` (commit
   `b025b3805800dbf1f6d3850e881a40c8e6ebac71`), published as a GitHub
   pre-release; exact-tag CI run [33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913)
   and same-SHA main run [33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218)
   pass on Ubuntu and Windows.
2. **Withdrawn release**: `v2.3.0` (tag commit
   `708a976af38a4ed78fa59850294de3da6cb8ee18`) is retained without moving,
   deleting, recreating, or force-pushing. Its GitHub Release is marked
   `WITHDRAWN / SUPERSEDED`; its tag commit internally identified as
   `2.3.0-rc3` (`VERSION`, `DESCRIPTION`, `CITATION.cff`, `SKILL.md`).
3. **Canonical stable target**: `v2.3.1`. Internal metadata is normalized to
   `2.3.1` across `VERSION`, `DESCRIPTION`, `CITATION.cff`, `SKILL.md`,
   `scripts/ihc_helpers.R`, `README.md`, and `README_EN.md`.
4. **Frozen analytical core**: no analytical behavior change relative to
   `v2.3.0-rc3`; the only allowed non-comment executable difference is the
   exact release-version constant allow-listed in
   `tests/verify_frozen_core_diff.py`.
5. **External real-data gates** (`EXTERNAL_VALIDATION_MATRIX.csv`): BBBC013
   `PASS`; BBBC007, BBBC016, and HPA `PASS_WITH_WARNINGS`. Weak results
   (ESR1 rho = 0.4972, BBBC016 puncta/cell rho = 0.3720) are reported as
   measured.
6. **Generated evidence**: every tracked "current" report is deterministically
   regenerated (version from `VERSION`, validation date from
   `external_validation/VALIDATION_METADATA.json`), and CI fails on tracked
   report drift.

## 2. Authoritative gate matrix (current)

| Gate | Name | Modality | Status |
| :--- | :--- | :--- | :--- |
| G0 | DAB Baseline Audit | Brightfield DAB | **PASS** |
| G1 | IF Input & Bit-Depth I/O | IF | **PASS_WITH_WARNINGS** (OME-XML and packed native-12-bit experimental) |
| G2 | IF Preprocessing & Saturation | IF | **PASS** |
| G3 | IF Segmentation & Compartments | IF | **PASS** |
| G4 | Four-Domain IF Quantification | IF | **PASS** |
| G5 | 8-Panel QC & Publication Plots | IF | **PASS** |
| G6 | Dual-Channel Colocalization | IF | **PASS** |
| G7 | Puncta / Subcellular Foci | IF | **PASS_WITH_WARNINGS** (synthetic aggregate counting only; no coordinate-level ground truth) |
| G8 | Public Benchmark Validation | IF / nuclear segmentation | **PASS** |
| G9 | DAB Backward Compatibility | Brightfield DAB | **PASS** |
| G10 | Cross-Platform CI Matrix | Both | **PASS** |

Warnings are accepted, disclosed findings; no gate was relaxed to obtain them.

## 3. Conditions for the stable release action

- Exact-SHA `main` CI of the final `v2.3.1` candidate commit: all jobs
  `success`.
- Exact-tag CI of `v2.3.1` at the same commit: all jobs `success`, including
  `tag-version-contract` (`v2.3.1 == VERSION 2.3.1`).
- Only then create the `v2.3.1` GitHub stable Release (`prerelease = false`)
  and upload the verified archive with SHA-256 sidecar.

## 4. Historical decisions

- rc1: [`docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md`](docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md)
  (historical snapshot, not current evidence).
- `v2.3.0` stable decision was revoked as a release-identity mismatch; the
  tag/release are preserved for provenance only.
