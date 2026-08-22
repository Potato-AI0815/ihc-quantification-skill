# IF Image I/O, Bit-Depth, and Projection Validation Report

**Version**: 2.3.0-rc1
**Date**: 2026-08-22
**Status**: **PASS_WITH_WARNINGS (validated scope only)**

---

## 1. Scope & Bit-Depth Preservation Governance
- **Validated requirement**: Standard TIFF and ImageJ TIFF/hyperstack inputs preserve tested 8-bit, 16-bit, 32-bit floating-point, and 12-bit detector-range values stored in a 16-bit container without silent downscaling or clipping.
- **Validated axes**: $(X \times Y)$, $(X \times Y \times C)$, $(X \times Y \times Z)$, and tested 4D ImageJ hyperstacks $(X \times Y \times C \times Z)$.
- **Not formally validated in this contract**: OME-XML metadata-aware ingestion and packed native-12-bit TIFF encodings. These remain experimental and must not be advertised as validated formats.

---

## 2. Quantitative Verification Matrix

| Filename | Format | Axes | SizeC | SizeZ | SizeT | Dimension Order | Bit Depth | Channel Count | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `test_8bit.tif` | Standard TIFF | XYC | 2 | 1 | 1 | XYC | 8-bit | 2 | **PASS** |
| `test_16bit.tif` | Standard TIFF | XYC | 2 | 1 | 1 | XYC | 16-bit | 2 | **PASS** |
| `test_12bit_in_16bit_container.tif` | Standard TIFF | XYC | 2 | 1 | 1 | XYC | 12-bit (16-bit container) | 2 | **PASS** |
| `test_32bit.tif` | Standard TIFF | XYC | 2 | 1 | 1 | XYC | 32-bit float | 2 | **PASS** |
| `test_zstack_4d.tif` | ImageJ Hyperstack | XYCZ | 2 | 5 | 1 | XYCZ | 16-bit / norm float | 2 | **PASS** |
| `OME-TIFF metadata workflow` | OME-TIFF / OME-XML | — | — | — | — | — | — | — | **UNDER_VALIDATION** |

### Dynamic Range Preservation Audit

| Fixture / Format | Detected Representation | Dimensions ($X 	imes Y 	imes Z$) | Observed Min | Observed Max | Dynamic Range Used | Silent Conversion Audit |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **8-bit TIFF** | normalized_float | 128 $	imes$ 128 $	imes$ 1 | 0.0000 | 0.9412 | 1.0000 | **PASS_PRESERVED** |
| **16-bit TIFF** | normalized_float | 128 $	imes$ 128 $	imes$ 1 | 0.0000 | 0.8850 | 1.0000 | **PASS_PRESERVED** |
| **12-bit range in 16-bit container** | normalized_float | 128 $	imes$ 128 $	imes$ 1 | 0.0000 | 0.0625 | 1.0000 | **PASS_PRESERVED** |
| **32-bit Float** | normalized_float | 128 $	imes$ 128 $	imes$ 1 | 0.0000 | 0.9500 | 1.0000 | **PASS_PRESERVED** |
| **4D Z-Stack (Max Proj)** | 4D Z-Stack | 128 $	imes$ 128 $	imes$ 5 | 0.0000 | 0.9000 | 0.9000 | **PASS_PRESERVED** |
| **4D Z-Stack (Mean Proj)** | 4D Z-Stack | 128 $	imes$ 128 $	imes$ 5 | 0.0000 | 0.4471 | 0.4471 | **PASS_PRESERVED** |
| **4D Z-Stack (Sum Proj)** | 4D Z-Stack | 128 $	imes$ 128 $	imes$ 5 | 0.0000 | 2.2353 | 2.2353 | **PASS_PRESERVED** |

---

## 3. Z-Projection Mathematical Contract
1. **Sum Projection** $\ge$ **Max Projection**: Verified ($I_{\text{sum, max}} = 2.2353 \ge I_{\text{max, max}} = 0.9000$).
2. **Max Projection** $\ge$ **Mean Projection**: Verified ($I_{\text{max, max}} = 0.9000 \ge I_{\text{mean, max}} = 0.4471$).
3. **Channel Integrity**: Multi-channel Z-stacks parse individual channels independently prior to slice projection.

