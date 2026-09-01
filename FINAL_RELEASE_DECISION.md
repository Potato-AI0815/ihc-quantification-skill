# Final Release Decision — IHC & Immunofluorescence Quantification Skill

**Current target**: `v2.3.2`
**Current state**: `PRE_RELEASE_READINESS` — scientific-contract hotfix candidate
**Decision date**: 2026-09-01
**Decision**: **`APPROVED FOR STABLE RELEASE`**
**Gate**: **`PENDING EXACT-SHA MAIN CI`** (tag/release only if explicitly authorized)

> `v2.3.1` remains the canonical stable release. `v2.3.0` remains withdrawn
> and preserved for provenance. This decision approves the v2.3.2 code changes
> only after all local regressions and the exact-SHA main CI pass. It does not
> authorize creating a `v2.3.2` tag or GitHub Release.

---

## 1. Current state summary

1. **Canonical stable**: `v2.3.1` (commit
   `5f9cd52ddc32c7233180680e3623af3dd6e9f009`; stable Release published;
   `prerelease = false`).
2. **Withdrawn release**: `v2.3.0` (commit
   `708a976af38a4ed78fa59850294de3da6cb8ee18`) is retained, not moved, and
   marked `WITHDRAWN / SUPERSEDED`.
3. **v2.3.2 P0**: missing/invalid `pixel_size_um` now produces
   `scale_mode = pixel_fallback`, `NA` physical-unit metrics, and the
   `MISSING_PIXEL_SIZE_CALIBRATION` warning. Pixel-domain metrics remain
   available. `1 px = 1 um` is never assumed.
4. **v2.3.2 P1**: the production colocalization path now executes dynamic-range
   and registration QC before Pearson/Manders interpretation. Blocked rows
   have `NA` metrics and explicit `NOT_EVALUABLE_*` statuses.
5. **Frozen analytical core**: DAB behavior is unchanged. IF changes are
   limited to the two release-blocking scientific contracts plus their
   deterministic regressions.
6. **External real-data gates**: validation evidence originates from
   `v2.3.0-rc3`; BBBC013 `PASS`; BBBC007, BBBC016, and HPA
   `PASS_WITH_WARNINGS`. Weak results are preserved.

## 2. Authoritative gate matrix (current)

| Gate | Name | Modality | Status |
| :--- | :--- | :--- | :--- |
| G0 | DAB Baseline Audit | Brightfield DAB | **PASS** |
| G1 | IF Input & Bit-Depth I/O | IF | **PASS_WITH_WARNINGS** |
| G2 | IF Preprocessing & Saturation | IF | **PASS** |
| G3 | IF Segmentation & Compartments | IF | **PASS** |
| G4 | Four-Domain IF Quantification | IF | **PASS** |
| G5 | 8-Panel QC & Publication Plots | IF | **PASS** |
| G6 | Dual-Channel Colocalization | IF | **PASS** |
| G7 | Puncta / Subcellular Foci | IF | **PASS_WITH_WARNINGS** |
| G8 | Public Benchmark Validation | IF / nuclear segmentation | **PASS** |
| G9 | DAB Backward Compatibility | Brightfield DAB | **PASS** |
| G10 | Cross-Platform CI Matrix | Both | **PASS** for v2.3.1; **PENDING** for v2.3.2 |

Warnings are accepted, disclosed findings; no gate was relaxed.

## 3. Conditions for the stable release action

- Exact-SHA `main` CI of the final `v2.3.2` candidate commit: all jobs
  `success` on Ubuntu and Windows, including the new physical-scale and
  colocalization QC regressions.
- Only with explicit release authorization: create annotated tag `v2.3.2`,
  verify `tag == VERSION == 2.3.2`, wait for exact-tag CI `success`, then
  publish a `prerelease = false` GitHub Release and verified archive.
- `v2.3.0` and `v2.3.1` tags remain immutable.

## 4. Historical decisions

- rc1: [`docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md`](docs/archive/release_history/FINAL_RELEASE_DECISION_v2.3.0-rc1.md)
- `v2.3.0` stable decision revoked as release-identity mismatch; tag preserved.
- `v2.3.1` canonical stable release audit recorded in
  [`RELEASE_STATUS.md`](RELEASE_STATUS.md) and
  [`CI_PROVENANCE_REPORT.md`](CI_PROVENANCE_REPORT.md).
