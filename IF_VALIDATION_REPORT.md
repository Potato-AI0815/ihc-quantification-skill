# Immunofluorescence (IF) Validation Report

**Version**: `2.3.0-alpha.2`
**Execution Environment**: R 4.6.0, EBImage 4.54.0, data.table 1.18.4, ggplot2 4.0.3, ragg 1.5.2, svglite 2.2.2
**Date**: 2026-08-19

---

## 1. Directional Statistical Hypothesis Validation

### Synthetic IF Fixture Configuration
- **Design**: 2 Biological Units (`S01`, `S02`) $\times$ 2 Conditions (`control`, `treatment`) = 4 multi-channel images.
- **Hypothesis Target A (SPATS2)**:
  - `control`: Designed with predominantly cytoplasmic localization ($Cyto > Nuc$).
  - `treatment`: Designed with predominantly nuclear translocation ($Nuc > Cyto$).

### Empirical Quantification Results

| Biological Unit | Condition | Nuclear MFI | Cytoplasmic MFI | Extracellular MFI | Outcome |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `S01` | `control` | 0.1600 | 0.6394 | 0.0099 | **PASS** ($Cyto > Nuc$) |
| `S01` | `treatment` | 0.8591 | 0.2454 | 0.0100 | **PASS** ($Nuc > Cyto$) |
| `S02` | `control` | 0.2099 | 0.6064 | 0.0099 | **PASS** ($Cyto > Nuc$) |
| `S02` | `treatment` | 0.8097 | 0.2621 | 0.0099 | **PASS** ($Nuc > Cyto$) |

- **Statistical Directionality**:
  - Nuclear MFI (Treatment) $= 0.8344 \gg 0.1850$ Nuclear MFI (Control) (**Direction Validated**)
  - Cytoplasmic MFI (Control) $= 0.6229 \gg 0.2537$ Cytoplasmic MFI (Treatment) (**Direction Validated**)

---

## 2. Colocalization Module Validation

- **High Colocalization Fixture (`COLOC_HIGH`)**:
  - Pearson's $r = 0.8519787$
  - Manders' $M_1 = 0.9996396$, $M_2 = 0.9996617$
- **Low Colocalization Fixture (`COLOC_LOW`)**:
  - Pearson's $r = -0.9880178$
  - Manders' $M_1 = 0.0226491$, $M_2 = 0.0250744$
- **Validation**: Pearson and both Manders coefficients satisfy the current regression thresholds (**PASS**). These are spatial pixel-association metrics, not evidence of molecular binding.

---

## 3. Puncta / Foci Detection Validation

- **5 Foci/Cell Ground Truth (`PUNCTA_5`)**: Detected $43$ of $45$ total foci (4.4% relative error; 4.78 detected foci/cell).
- **15 Foci/Cell Ground Truth (`PUNCTA_15`)**: Detected $134$ of $135$ total foci (0.7% relative error; 14.89 detected foci/cell).
- **Validation**: Synthetic aggregate foci-count dose-response ordering is preserved: $\text{Count}_{15} > \text{Count}_{5}$ ($134 > 43$) (**PASS_WITH_WARNINGS**). This fixture does not provide coordinate-level false-positive/false-negative annotations, so detector precision/recall/F1 are not claimed.

---

## 4. Figure Manifest and Graphic Artifacts
- `if_main_01_global_mean_intensity.png / .svg / .pdf`: Verified non-empty.
- `if_main_02_nuclear_mean_intensity.png / .svg / .pdf`: Verified non-empty.
- `if_main_03_cytoplasmic_mean_intensity.png / .svg / .pdf`: Verified non-empty.
- `if_main_04_extracellular_positive_fraction.png / .svg / .pdf`: Verified non-empty.
- `if_main_05_colocalization_pearson_r.png / .svg / .pdf`: Verified non-empty (when enabled).
- `if_main_06_puncta_per_cell.png / .svg / .pdf`: Verified non-empty (when enabled).
- Standard 8-panel QC montages generated for all synthetic images.

---

## 5. Segmentation QC Repair — Panel F Cell/Cytoplasm Boundaries

**Repair date**: 2026-08-22

**Review trigger**: The previous Panel F overlay re-labelled the union of all
propagated cell pixels with `bwlabel(cell_labels > 0)`. When adjacent cell
territories touched, that display step collapsed them into one large polygon.
The propagation radius was also a single unconstrained value, which could let
neighboring cytoplasm territories meet in dense fields.

**Defensive changes**:

- `max_cytoplasm_expansion_radius = 10` px is now a hard cap, in addition to
  the legacy `cell_propagation_radius = 15` setting.
- The distance-transform expansion threshold is dynamically capped by the
  closest pair of nuclear boundaries, with `cytoplasm_boundary_gap_px = 1` px
  retained between neighboring propagated labels.
- Dense-field nuclear splitting uses
  `nuc_watershed_tolerance = 1.0`, `nuc_watershed_ext = 1`, and
  `refine_dense_nuclei = TRUE` by default.
- Panel F now paints the original labelled cell image rather than a binary
  re-labelling, so each nucleus retains its own cell boundary in the QC view.

**Synthetic IF rerun**:

```text
IF images processed: 4
Nuclei per image: 25
QC status: PASS for all 4 images
Panel F acceptance: PASS — individual cell-like boundaries, one nucleus per
cell compartment, no large merged polygon regions
```

The change is a segmentation/QC defensive repair only. It does not change any
biological interpretation claim, modality definition, or fluorescence metric
semantics. The full synthetic smoke test, including
`tests/verify_if_advanced_modules.R`, completed successfully after the repair.
The runtime regression contract also reports `nuclei = 25`,
`union_components = 25`, `effective_radius = 10`, and `gap = 1` for the
reference synthetic IF image.

**Dense public-image check**: the public CIL45501 IF image was rerun with the
same defaults. It produced `799` watershed nuclei with
`effective_cell_propagation_radius = 0` because neighboring nuclear
boundaries leave no defensible cytoplasm expansion interval under the guarded
gap rule. Panel F retains separate nucleus-labelled boundaries and does not
draw a merged cell polygon; cytoplasmic measurements are consequently left
non-evaluable for this dense field rather than being inferred by expansion.
