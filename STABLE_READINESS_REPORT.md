# Stable Readiness Report — v2.3.2 Scientific-Contract Hotfix

**Date**: 2026-09-01
**Scope**: physical-scale contract and colocalization production QC enforcement
**Recommendation**: **`APPROVED_FOR_STABLE_RELEASE_PENDING_EXACT_SHA_MAIN_CI`** (no tag/release authorized by this document)

## 1. Release lineage

| Item | Value |
|---|---|
| Canonical stable release | `v2.3.1` / `5f9cd52ddc32c7233180680e3623af3dd6e9f009`; stable GitHub Release exists |
| Withdrawn historical release | `v2.3.0` / `708a976af38a4ed78fa59850294de3da6cb8ee18`; preserved, not moved |
| Immutable validation baseline | `v2.3.0-rc3` / `b025b3805800dbf1f6d3850e881a40c8e6ebac71` |
| Current patch candidate | `v2.3.2` on `main`; no tag or Release claim in this commit |

## 2. Independently confirmed problems

| Finding | Status |
|---|---|
| IF runner defaulted missing `pixel_size_um` to `1.0` and emitted `*_um2` metrics | **CONFIRMED** |
| `compute_if_colocalization()` did not call registration or dynamic-range QC in production | **CONFIRMED** |
| Documentation claimed registration shift `< 5 px` and dynamic range QC | **CONFIRMED (documentation only)** |
| DAB pipeline affected by these defects | **NOT CONFIRMED** (DAB has its own `resolve_scaled_config` contract and passed 11-table compatibility) |
| Puncta detector algorithm itself required changes | **PARTIALLY CONFIRMED** only for physical-unit output fields; detection formula unchanged |

## 3. Physical-scale contract

| Input | `scale_mode` | Pixel-domain metrics | `*_um2` / `*_per_um2` | QC warning |
| :--- | :--- | :--- | :--- | :--- |
| `0.5` | `physical_calibrated` | finite | finite | none |
| missing / `NA` | `pixel_fallback` | finite | `NA` | `MISSING_PIXEL_SIZE_CALIBRATION` |
| `0`, `-1`, `Inf`, `NaN` | `pixel_fallback` | finite | `NA` | `MISSING_PIXEL_SIZE_CALIBRATION` |

## 4. Colocalization production QC contract

| Fixture | Expected status | Metrics |
| :--- | :--- | :--- |
| Aligned high colocalization | `PASS` | finite |
| Aligned low colocalization | `PASS` | finite, distinguishable from high |
| Channel B shifted 7 px | `NOT_EVALUABLE_REGISTRATION_SUSPECT` | `NA` |
| Low dynamic range | `NOT_EVALUABLE_LOW_DYNAMIC_RANGE` | `NA` |
| Low valid pixel count | `NOT_EVALUABLE_LOW_PIXEL_COUNT` | `NA` |

The production path uses raw projected channel pixels for colocalization;
background correction and automatic image translation are not applied.

## 5. Frozen-core scope

- DAB files: unchanged vs the immutable `v2.3.0-rc3` baseline except the
  version metadata constant.
- IF segmentation, QC helpers, and DAB runner: unchanged.
- IF quantification/colocalization/puncta/preprocessing/runner: changed only
  for the two approved scientific contracts; the exact normalized non-comment
  content is pinned by the frozen-core guard's v2.3.2 approved-patch contract.
- No scientific threshold was changed to improve any benchmark.

## 6. Known limitations

- OME-TIFF metadata workflows remain experimental.
- Packed native 12-bit TIFF remains not formally validated.
- Puncta detection remains `VALIDATED_FOR_SYNTHETIC_AGGREGATE_COUNTING` only;
  no coordinate-level precision/recall/F1 detector validation.
- Colocalization does not establish molecular binding.
- HPA validation is ordinal concordance, not clinical validation.
- Weak external results remain disclosed: BBBC007, BBBC016, and HPA are
  `PASS_WITH_WARNINGS`.
