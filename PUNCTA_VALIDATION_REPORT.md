# Puncta / Foci Module Quantitative Benchmark Report

**Version**: 2.3.2
**Date**: 2026-08-29
**Module Classification**: **VALIDATED_FOR_SYNTHETIC_AGGREGATE_COUNTING**
**Gate G7 Assessment**: **PASS_WITH_WARNINGS**

---

## 1. Synthetic Ground-Truth Benchmark Setup
- **Known Ground-Truth Counts**:
  - `PUNCTA_5`: 9 cells $\times$ 5 puncta = 45 puncta total (5.0 puncta/cell)
  - `PUNCTA_15`: 9 cells $\times$ 15 puncta = 135 puncta total (15.0 puncta/cell)
- **Algorithm**: Difference of Gaussians (DoG) bandpass filter ($\sigma_1 = 1.0, \sigma_2 = 2.5, k = 3.0$) with connected component labeling.

---

## 2. Benchmark Quantitative Metrics

| Metric | Condition Low (`PUNCTA_5`) | Condition High (`PUNCTA_15`) | Overall Summary |
| :--- | :--- | :--- | :--- |
| **Ground-Truth Count** | 45 | 135 | Total GT = 180 |
| **Detected Count** | 43 | 134 | Total Detected = 177 |
| **GT Count / Cell** | 5.00 | 15.00 | — |
| **Detected Count / Cell** | 4.78 | 14.89 | — |
| **Relative Count Error** | 4.4% | 0.7% | Mean Rel Err = 2.6% |
| **Mean Absolute Error (MAE) / Cell** | 0.22 | 0.11 | Overall MAE = 0.17 |
| **Dose-Response Directionality** | — | — | **PASS** (Count 15 > Count 5) |

---

## 3. Methodological Governance & Limitations
- When puncta are closely clustered or near the diffraction limit, DoG connected components may group adjoining peaks into single merged regions.
- **Classification Status**: Assigned **VALIDATED_FOR_SYNTHETIC_AGGREGATE_COUNTING**; Gate G7 evaluated as **PASS_WITH_WARNINGS**.
- **Usage Recommendation**: Recommended for relative comparison across experimental conditions (dose-response, knock-down vs control); absolute single-molecule counts should be cross-validated with single-molecule localization microscopy or spot-intensity deconvolution if exact counting is required.

