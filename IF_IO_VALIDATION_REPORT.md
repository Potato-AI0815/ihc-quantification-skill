# IF Image I/O, Bit-Depth, and Projection Validation Report

**Version**: 2.3.0-alpha.1
**Date**: 2026-08-18
**Status**: **PASS (Zero Silent Conversions)**

---

## 1. Scope & Bit-Depth Preservation Governance
- **Requirement**: The IF reader must natively ingest 8-bit, 12-bit, 16-bit, and 32-bit floating point images without silent downscaling, clipping, or lossy 8-bit conversion.
- **Physical Axes Support**: Supports $(X \times Y)$, $(X \times Y \times C)$, $(X \times Y \times Z)$, and 4D hyperstacks $(X \times Y \times C \times Z)$ and $(X \times Y \times Z \times C)$.

---

## 2. Quantitative Verification Matrix

| Fixture / Format | Detected Representation | Dimensions ($X \times Y \times Z$) | Observed Min | Observed Max | Dynamic Range Used | Silent Conversion Audit |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **8-bit TIFF** | normalized_float | 128 $\times$ 128 $\times$ 1 | 0.0000 | 0.9412 | 1.0000 | **PASS_PRESERVED** |
| **16-bit TIFF** | normalized_float | 128 $\times$ 128 $\times$ 1 | 0.0000 | 0.8850 | 1.0000 | **PASS_PRESERVED** |
| **32-bit Float** | normalized_float | 128 $\times$ 128 $\times$ 1 | 0.0000 | 0.9500 | 1.0000 | **PASS_PRESERVED** |
| **4D Z-Stack (Max Proj)** | 4D Z-Stack | 128 $\times$ 128 $\times$ 5 | 0.0000 | 0.9000 | 0.9000 | **PASS_PRESERVED** |
| **4D Z-Stack (Mean Proj)** | 4D Z-Stack | 128 $\times$ 128 $\times$ 5 | 0.0000 | 0.4471 | 0.4471 | **PASS_PRESERVED** |
| **4D Z-Stack (Sum Proj)** | 4D Z-Stack | 128 $\times$ 128 $\times$ 5 | 0.0000 | 2.2353 | 2.2353 | **PASS_PRESERVED** |

---

## 3. Z-Projection Mathematical Contract
1. **Sum Projection** $\ge$ **Max Projection**: Verified ($I_{\text{sum, max}} = 2.2353 \ge I_{\text{max, max}} = 0.9000$).
2. **Max Projection** $\ge$ **Mean Projection**: Verified ($I_{\text{max, max}} = 0.9000 \ge I_{\text{mean, max}} = 0.4471$).
3. **Channel Integrity**: Multi-channel Z-stacks parse individual channels independently prior to slice projection.
