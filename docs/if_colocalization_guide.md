# IF Colocalization Analysis Guide

## Purpose
Quantifies spatial overlap and intensity correlation between two distinct fluorescence channels (e.g. Marker A and Marker B).

## Quantitative Metrics

### 1. Pearson's Correlation Coefficient ($r$)
Measures the linear relationship between pixel intensities in channel A and channel B:
$$r = \frac{\sum (A_i - \bar{A})(B_i - \bar{B})}{\sqrt{\sum (A_i - \bar{A})^2 \sum (B_i - \bar{B})^2}}$$
- Range: $-1.0$ (complete anti-correlation) to $+1.0$ (perfect co-localization).

### 2. Manders' Overlap Coefficients ($M_1$ and $M_2$)
Measures fractional intensity of channel A overlapping with positive channel B pixels:
$$M_1 = \frac{\sum_{i, B_i \ge T_B} A_i}{\sum_i A_i}, \quad M_2 = \frac{\sum_{i, A_i \ge T_A} B_i}{\sum_i B_i}$$
- Range: $0.0$ to $1.0$.

## Preprocessing Contract
The production runner computes Pearson/Manders on **raw projected channel
pixels** restricted to the analysis mask.  It does not apply background
correction or automatic image translation.  The synthetic validation
benchmark uses the same raw-pixel path.  Each output row records
`colocalization_input_contract = raw_channel_pixels`.

## Quality Control Rules
The production runner executes these gates in order before interpreting
Pearson/Manders:

| Gate | Blocking status |
| :--- | :--- |
| Valid pixel count `< 30` | `NOT_EVALUABLE_LOW_PIXEL_COUNT` |
| Either channel dynamic range `< 0.05`, where dynamic range is `(P99.9 - P0.1) / (max - min)` | `NOT_EVALUABLE_LOW_DYNAMIC_RANGE` |
| `abs(registration_shift_x) > 5` or `abs(registration_shift_y) > 5` | `NOT_EVALUABLE_REGISTRATION_SUSPECT` |
| Registration assessment unavailable | `NOT_EVALUABLE_REGISTRATION_SUSPECT` |
| Zero variance surviving the dynamic-range gate | `ZERO_VARIANCE` |

Blocked rows record the QC fields and emit `NA` for Pearson and Manders.
Registration QC uses the existing `compute_channel_registration()` and records
`registration_shift_x`, `registration_shift_y`,
`registration_correlation`, and `registration_status`.  The pipeline detects
and flags suspect shifts; it does **not** automatically translate channels and
silently continue.

- **Scientific Notice**: High colocalization scores signify spatial co-occurrence; colocalization does not establish molecular binding (which requires complementary biophysical assays such as FRET, PLA, or Co-IP).
