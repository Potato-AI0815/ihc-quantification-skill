# BBBC016 Puncta External Validation

**Evidence level**: Level B — real-data biological-response concordance

**Status**: **PASS_WITH_WARNINGS**

## Frozen workflow

All 72 fields from 24 wells were processed with the existing DoG settings (sigma1 1.0, sigma2 2.5, threshold mean + 3 SD, object area 2–150 px). Fields were aggregated to wells before response analysis; cells were not treated as replicates.

## Results — positive dose association

The frozen puncta workflow recovered a **positive dose-associated trend**: the Spearman rank association between agonist dose and puncta burden is positive for both integrated puncta intensity (the stronger endpoint) and puncta per cell (the weaker endpoint), and maximum-dose wells sit above controls. These are positive rank associations, **not** claims of strict monotonic dose recovery.

| Metric | Result |
|---|---:|
| Valid wells | 24/24 |
| Spearman rho — puncta per cell | 0.3720 |
| Spearman rho — integrated intensity | 0.6254 |
| Spearman rho — puncta density | 0.4374 |
| Maximum-dose minus control effect | 0.5474 |

## Interpretation boundary

This benchmark tests whether the frozen puncta workflow recovers the direction of a real Transfluor dose response. It does not reproduce the published V-factor, whose endpoint differs from puncta-per-cell, integrated intensity, and density used here. The moderate per-cell association (rho 0.3720) is reported as measured: it reflects real per-well variability and was not tuned or excluded.
