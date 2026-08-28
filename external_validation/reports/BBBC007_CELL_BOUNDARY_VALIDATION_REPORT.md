# BBBC007 Cell-Boundary External Validation Report

**Evidence level**: Level A — manual ground-truth benchmark

**Dataset**: BBBC007 v1, all 16 complete fields

**Software commit**: `c8bbe77bf0707574d9b8f4c1cd9b92778ba2cb56` (independent bugfix after the recorded zero-propagation failure)

**Status**: **PASS_WITH_WARNINGS**

## Frozen-method result

No BBBC007 field was used for calibration and no boundary threshold was tuned
after result inspection. This run uses the independent bugfix that replaces the
field-wide radius collapse with per-nucleus local safety radii; the frozen
maximum (10 px), one-pixel gap, and watershed settings are unchanged.

| Metric | Aggregate result |
|---|---:|
| Nucleus Dice | 0.7645 |
| Nucleus IoU | 0.6277 |
| Nucleus object precision | 0.7529 |
| Nucleus object recall | 0.8119 |
| Nucleus object F1 | 0.7781 |
| Nucleus count relative error | 0.1290 |
| Relevant boundary within 1 px | 0.4663 |
| Relevant boundary within 2 px | 0.5880 |
| Relevant boundary within 3 px | 0.6891 |
| Median boundary distance, field mean | 2.7257 px |
| 95th percentile boundary distance, field mean | 9.7545 px |
| One nucleus per predicted cell | 1.0000 |
| Multi-nucleus predicted cells | 0 |
| Zero-nucleus predicted cells | 0 |
| Overlap pixels | 0 |
| Fields with non-zero cell propagation | 1.0000 |
| Maximum observed propagation radius | 10.00 px |

## Structural acceptance

- `cell_mask_overlap_pixels = 0`: PASS
- `multi_nucleus_predicted_cell_count = 0`: PASS
- propagation never exceeded the configured maximum: PASS
- non-zero cell propagation in >= 90% of fields: PASS

## Visual evidence

Six deterministic QC plates are stored in `external_validation/results/figures/BBBC007/`. They include low-, medium-, and high-density fields, touching and irregular-cell proxies, and the worst-performing field. Cyan is manual GT, magenta is prediction, and white is overlap. No best-only gallery is used.

## Interpretation boundary

BBBC007 directly benchmarks manual nuclear and whole-cell outlines. The result does not establish performance on every tissue morphology or acquisition system. Cell-boundary agreement is reported using relevant internal predicted boundaries, consistent with the BBBC007 recommendation.
