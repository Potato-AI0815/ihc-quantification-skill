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

## Quality Control Rules
- Colocalization is invalid if pixel count in ROI $< 30$ or dynamic range $< 0.05$.
- Automated QC verifies channel registration shift $< 5\text{ px}$ before computing colocalization.
- **Scientific Notice**: High colocalization scores signify spatial co-occurrence; colocalization does not establish molecular binding (which requires complementary biophysical assays such as FRET, PLA, or Co-IP).
