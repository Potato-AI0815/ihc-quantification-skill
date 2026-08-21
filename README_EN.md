# IHC & Immunofluorescence (IF) Quantification Skill v2.3.0-alpha.2

A reproducible, QC-first, auditable R/EBImage workflow for **brightfield DAB-IHC** and **multi-channel immunofluorescence (IF)** quantification.

> [!IMPORTANT]
> - **Brightfield DAB Workflow**: **Stable** (Full v2.2.2 backward compatibility maintained).
> - **Immunofluorescence (IF) Workflow**: **v2.3.0-alpha.2** (Multi-channel TIFF, 4-compartment MFI, Colocalization, Puncta detection, 8-panel QC).
> - **IF public-image runtime status**: **Repaired public smoke test PASS_WITH_WARNINGS**; FluorescentCells uses a reviewed artifact-exclusion ROI and remains a teaching image rather than a biological replication benchmark.
> - **Current release gate**: The validation hotfix and exact `v2.3.0-alpha.2` main-commit Ubuntu/Windows CI pass ([Actions run 32452752381](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/32452752381)); this remains an alpha prerelease with the warnings documented below.
> - **Research Use Only (RUO)**: Designed strictly for scientific quantification and methodological auditing, not for clinical diagnosis or treatment decisions.

---

## Key Features

1. **Automatic Modality Routing**: Seamlessly routes tasks based on the `modality` declared in `manifest.csv` (`brightfield_dab` vs `immunofluorescence`).
2. **Brightfield DAB-IHC (Stable v2.2.2)**: Whole-tissue global burden, 4-compartment H-scores (0–300), H-DAB color deconvolution, and ROI evidence crops.
3. **Multi-channel IF (v2.3.0-alpha.2)**: Validated multi-channel TIFF / ImageJ hyperstack / Z-stack ingestion; OME-TIFF metadata-aware ingestion is experimental. Tested intensity preservation covers 8/16/32-bit float and 12-bit detector-range values stored in a 16-bit container; packed native 12-bit TIFF is not formally validated. The workflow also provides background correction (Rolling Ball / Top-hat), 4-compartment quantification (GLOBAL, NUCLEUS, CYTOPLASM, EXTRACELLULAR), single-cell N/C ratios, dual-channel colocalization (Pearson $r$, Manders $M_1/M_2$), and foci/puncta quantification (DoG).
4. **Biological Unit Contract**: In all statistical inferences, $n$ equals the number of independent biological units (`biological_unit_id`), preventing pseudo-replication.
5. **Standardized QC Overviews**: 8-panel diagnostic montages and automated quality flags (`HIGH_SATURATION`, `LOW_DYNAMIC_RANGE`, `HIGH_BACKGROUND`, `LOW_CELL_COUNT`).
6. **Reviewed IF ROI support**: optional include/exclude polygons constrain analysis or remove burned-in artifacts without rewriting raw pixels; applied pixels and ROI IDs are recorded.

---

## Running the Smoke Test

```bash
# Linux / macOS
bash tests/run_synthetic_smoke_test.sh

# Windows
powershell -ExecutionPolicy Bypass -File .\tests\run_synthetic_smoke_test.ps1
```
