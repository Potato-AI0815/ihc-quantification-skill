# Final Release Decision — IHC & Immunofluorescence Quantification Skill

**Current candidate**: `v2.3.0-rc3`
**Current state**: POST-RC3 STABLE PREPARATION
**Decision date**: 2026-08-29
**Decision**: **`READY_FOR_FINAL_STABLE_REVIEW`**

> This is **not** an approval of the `v2.3.0` stable release. The stable
> decision requires (a) the exact-SHA GitHub Actions run of the final
> stable-prep `main` commit passing all jobs, and (b) the external final
> review of this state. Until both exist, no `v2.3.0` tag or stable GitHub
> release is created.

---

## 1. Current state summary

1. **Immutable released candidate**: `v2.3.0-rc3` (commit
   `b025b3805800dbf1f6d3850e881a40c8e6ebac71`), published as a GitHub
   pre-release; exact-tag CI run [33225049913](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225049913)
   and same-SHA main run [33225696218](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33225696218)
   pass on Ubuntu and Windows.
2. **Post-rc3 stable preparation**: `main` carries only non-algorithmic
   hardening (validation reporting, provenance/licensing, checkpoint/resume,
   CI gates). The frozen core is byte-identical to the rc3 tag; DAB backward
   compatibility re-verifies at zero deviation.
3. **External real-data gates** (`EXTERNAL_VALIDATION_MATRIX.csv`): BBBC013
   `PASS`; BBBC007, BBBC016, and HPA `PASS_WITH_WARNINGS`. Weak results
   (ESR1 ρ = 0.4972, BBBC016 puncta/cell ρ = 0.3720) are reported as measured.
4. **Generated evidence**: every tracked "current" report is deterministically
   regenerated (version from `VERSION`, date from
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
| G8 | Public Benchmark Validation | Both | **PASS** |
| G9 | 100% DAB Backward Compatibility | Brightfield DAB | **PASS** |
| G10 | Cross-Platform CI Matrix | Both | **PASS** |

Warnings are accepted, disclosed findings; no gate was relaxed to obtain them.

## 3. Conditions for the stable decision

- Exact-SHA CI of the final stable-prep `main` commit: all jobs `success`.
- External final review of `STABLE_READINESS_REPORT.md` and this decision.
- Then — and only then — cut `v2.3.0` (tag + stable release) in a dedicated
  release action.

## 4. Historical decisions

- rc1: [`docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md`](docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md)
  (historical snapshot, not current evidence).
