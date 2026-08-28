# Cell Propagation & Boundary Segmentation Visual Audit

**Validation Milestone**: External Real-Data Benchmark (Level A)  
**Dataset**: Broad Bioimage Benchmark Collection 007 (BBBC007 v1 — Drosophila Kc167 cells)  
**Software Baseline**: `c8bbe77bf0707574d9b8f4c1cd9b92778ba2cb56` (Per-nucleus local propagation radius)  
**Status**: **PASS_WITH_WARNINGS**

---

## 1. Audit Rationale: Structural Invariants by Construction

Cellular boundary propagation in high-content immunofluorescence requires balancing whole-cell territory expansion with strict topological safety invariants. Items 1 and 2 below are **not empirical accuracy measurements**: the predicted cell representation is a mutually exclusive integer label image whose territories are grown from nucleus seeds, so a pixel carries exactly one label and every territory contains exactly its own seed. Zero overlap and one nucleus per predicted cell are guarantees of this data structure itself — independent of how well predictions match the manual outlines — and are re-verified on every run as regression guards:

1. **Zero Overlap (`cell_mask_overlap_pixels = 0`)**: A structural invariant by construction of the mutually exclusive label image (a pixel cannot carry two integer labels); adjacent cytoplasmic domains cannot overlap by representation.
2. **Strict Monoclonality (`multi_nucleus_predicted_cell_count = 0`)**: A structural invariant by construction of seed propagation (each territory is grown from exactly one nucleus seed).
3. **Bounded Propagation**: Expansion radius must respect the frozen maximum ($R_{\text{max}} = 10\text{ px}$) and stop at cell-cell contact lines — an empirical verification per field.
4. **No Artificial Collapse**: Local neighbor proximity must scale the radius per nucleus rather than collapsing the entire field — an empirical verification per field.

---

## 2. Visual Representative Categories (6 Deterministic QC Plates)

Six representative fields from `external_validation/results/figures/BBBC007/` illustrate segmentation quality across challenging morphological regimes:

| Category | Representative Field | Ground-Truth vs Prediction Color Coding | Key Morphological Assessment |
| :--- | :--- | :--- | :--- |
| **Low Density** | `17P1_POS0006` | Cyan = Manual GT<br>Magenta = Prediction<br>White = Exact Overlap | Clean isolated cells; propagation smoothly halts at $R = 10\text{ px}$. |
| **Medium Density** | `A9_p5` | Cyan = Manual GT<br>Magenta = Prediction<br>White = Exact Overlap | Accurate contact-line partition between neighboring cells without merger. |
| **High Density** | `A9_p9` | Cyan = Manual GT<br>Magenta = Prediction<br>White = Exact Overlap | Dense cell clusters resolved without merger (70.0% of relevant boundary within 3 px). |
| **Touching Cells** | `A9_p7` | Cyan = Manual GT<br>Magenta = Prediction<br>White = Exact Overlap | Voronoi/distance-watershed boundary separates adjoining cytoplasms. |
| **Irregular Cells** | `17P1_POS0014` | Cyan = Manual GT<br>Magenta = Prediction<br>White = Exact Overlap | Elongated / dendritic cellular extensions correctly tracked. |
| **Worst-Performing** | `20P1_POS0010` | Cyan = Manual GT<br>Magenta = Prediction<br>White = Exact Overlap | Nuclear debris / sub-optimal focus field; zero overlap maintained. |

---

## 3. Quantitative Verification Metrics

### 3.1 External empirical accuracy vs manual outlines

Across all 16 complete BBBC007 fields:
- **Nucleus F1 Score**: `0.7781` (Object Precision: `0.7529`, Object Recall: `0.8119`)
- **Median Boundary Distance**: `2.7257 px`
- **Boundary within 2 px**: `58.80%`
- **Boundary within 3 px**: `68.91%`

### 3.2 Structural invariants by construction (verified, not measured)

- **Multi-Nucleus Cells**: `0` (by construction of seed propagation)
- **Zero-Nucleus Cells**: `0` (by construction of seed propagation)
- **Overlap Pixels**: `0` (by construction of the mutually exclusive label image)
- **Non-Zero Propagation Rate**: `100.0%` (16/16 fields)

---

## 4. Audit Conclusion

The per-nucleus local propagation algorithm satisfies all structural and topological invariants, generating biologically plausible cellular boundaries across diverse cell densities without requiring manual parameter tuning.
