# Colocalization Module Validation Report

**Version**: 2.3.0-alpha.1
**Date**: 2026-08-18
**Status**: **PASS**

---

## 1. Experimental Fixture Design
- **High Colocalization (`COLOC_HIGH`)**: Co-expression of Target A and Target B in identical cellular compartments across all cells.
- **Low Colocalization (`COLOC_LOW`)**: Mutually exclusive distribution where odd-indexed cells express Target A only, and even-indexed cells express Target B only.

---

## 2. Quantitative Verification Results

| Metric | High Colocalization | Low Colocalization | Expected Behavior | Outcome |
| :--- | :--- | :--- | :--- | :--- |
| **Pearson Correlation Coefficient ($r$)** | 0.8520 | -0.9880 | $r_{\text{high}} \gg r_{\text{low}}$ ($r_{\text{low}} < 0.15$) | **PASS** |
| **Manders Overlap Coefficient ($M_1$)** | 0.9996 | 0.0226 | $M_{1,\text{high}} \gg M_{1,\text{low}}$ ($M_{1,\text{low}} < 0.25$) | **PASS** |
| **Manders Overlap Coefficient ($M_2$)** | 0.9997 | 0.0251 | $M_{2,\text{high}} \gg M_{2,\text{low}}$ ($M_{2,\text{low}} < 0.25$) | **PASS** |

---

## 3. Scientific Governance
The colocalization pipeline reports spatial pixel intensity associations within the optical resolution limits of the microscope. High colocalization scores do **not** directly demonstrate physical molecular binding or complex formation without complementary biophysical assays (e.g. FRET, PLA, Co-IP).
