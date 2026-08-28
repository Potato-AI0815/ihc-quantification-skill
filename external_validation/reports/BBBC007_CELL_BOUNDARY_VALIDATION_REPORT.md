# BBBC007 Cell-Boundary External Validation Report

**Evidence level**: Level A — manual ground-truth benchmark

**Dataset**: BBBC007 v1, all 16 complete fields

**Status**: **PASS_WITH_WARNINGS**

## Frozen-method result

No BBBC007 field was used for calibration and no core parameter was changed after result inspection.

## External accuracy against manual outlines

These are the empirical benchmark measurements: predictions compared to the expert manual outlines.

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

## Structural invariants by construction

The items below are **not external accuracy measurements**. The predicted cell representation is a mutually exclusive integer label image whose territories are grown from nucleus seeds; a pixel carries exactly one label and every territory contains exactly its own seed. Zero overlap and one nucleus per predicted cell are therefore guarantees of the data structure itself, independent of how well predictions match the manual outlines. They are re-verified on every run as regression guards, and are reported here to keep them separate from the empirical metrics above.

| Invariant (verified) | Result |
|---|---:|
| Overlap pixels between predicted cells (0 by construction) | 0 |
| One nucleus per predicted cell (1.0 by construction) | 1.0000 |
| Multi-nucleus predicted cells (0 by construction) | 0 |
| Zero-nucleus predicted cells (0 by construction) | 0 |
| Fields with non-zero cell propagation | 1.0000 |
| Maximum observed propagation radius | 10.00 px |
| Propagation never exceeded the configured maximum | PASS |

## Visual evidence

Six deterministic QC plates are stored in `external_validation/results/figures/BBBC007/`. They include low-, medium-, and high-density fields, touching and irregular-cell proxies, and the worst-performing field. Cyan is manual GT, magenta is prediction, and white is overlap. No best-only gallery is used.

## Interpretation boundary

BBBC007 directly benchmarks manual nuclear and whole-cell outlines. The empirical accuracy metrics (nucleus F1, boundary distances) establish performance on this Drosophila Kc167 morphology and acquisition system only; they do not establish performance on every tissue morphology or acquisition system. Cell-boundary agreement is reported using relevant internal predicted boundaries, consistent with the BBBC007 recommendation.
