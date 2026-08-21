---
name: ihc-if-quantification
version: 2.3.0-alpha.2
description: Reproducible, auditable quantification of brightfield DAB/hematoxylin IHC and multi-channel immunofluorescence (IF) images. Automatically routes between brightfield DAB-IHC (v2.2.2 backward-compatible) and multi-channel IF pipelines. Supports four measurement domains (global tissue, nucleus, cytoplasm, extracellular), single-cell scoring, H-DAB reconstruction, 8-panel IF QC overviews, colocalization (Pearson/Manders), puncta/foci detection, and publication-ready biological-unit aggregation figures.
---

# IHC & Immunofluorescence (IF) Quantification Skill v2.3.0-alpha.2

## Purpose

Use this skill to perform auditable, QC-first quantification of:
1. **Brightfield Chromogenic DAB/Hematoxylin IHC**: Exported as RGB TIFF, PNG, or JPEG fields. (Stable v2.2.2 workflow; OME-TIFF metadata is not required for DAB routing.)
2. **Multi-channel Fluorescence Microscopy (IF)**: Validated for single-channel, multi-channel composite, and ImageJ hyperstack/Z-stack TIFF inputs. OME-TIFF metadata-aware ingestion is experimental in v2.3.0-alpha.2 and must not be treated as a validated interchange contract.

---

## Modality Router

The one-click runner (`run_one_click.sh`, `run_one_click.ps1`, `run_one_click.cmd`, `scripts/run_quantification.R`) automatically determines analysis modality from the manifest header:

```
                      Input Manifest (manifest.csv)
                                   │
                     ┌─────────────┴─────────────┐
                     ▼                           ▼
        [modality: brightfield_dab]    [modality: immunofluorescence]
                     │                           │
                     ▼                           ▼
          run_ihc_quantification.R     run_if_quantification.R
          (DAB optical density,        (Fluorescence linear MFI,
           H-score, H-DAB deconv)       4-compartments, Coloc, Puncta)
```

---

## Non-Negotiable Scientific Governance

1. **Research Use Only (RUO)**: Not for clinical diagnosis, diagnostic screening, or patient management decisions.
2. **Biological Replicates as Inferential Unit**: Always aggregate to `biological_unit_id` ($n$). Cells, ROIs, and pixels are nested measurements, not independent sample size.
3. **Strict Modality Isolation**:
   - **DAB**: Optical density (absorbance), H-DAB color deconvolution, H-score (0–300), DAB-positive area fraction.
   - **IF**: Linear fluorescence intensity (MFI), integrated fluorescence intensity, positivity area fraction, nuclear-to-cytoplasmic (N/C) ratio, colocalization ($r, M_1, M_2$), puncta count.
   - **Prohibition**: Never write fluorescence intensity as "OD" or "optical density"; never call IF integrated intensity "IOD"; never call automated extracellular space "stroma" without validated pathology annotation.
4. **Four-Compartment Quantification**:
   - `global`: Whole analyzed tissue / valid field of view.
   - `nucleus`: Nuclear counterstain mask (Hematoxylin or DAPI).
   - `cytoplasm`: Propagated cell mask minus nucleus.
   - `extracellular`: Valid field minus cell masks.
5. **Quality Control & Flagging**:
   - Every image generates a standardized QC overview (H-DAB reconstruction for DAB; 8-panel montage for IF).
   - Automated detection of `HIGH_SATURATION`, `LOW_DYNAMIC_RANGE`, `HIGH_BACKGROUND`, `LOW_CELL_COUNT`, `NO_SIGNAL`, `EMPTY_CHANNEL`, `NO_TISSUE_DETECTED`, and `CHANNEL_REGISTRATION_SUSPECT`.
   - A required IF QC failure blocks publication-figure rendering and returns a non-zero exit status. The QC image and source tables are retained for review.

---

## Quick Start (One-Click Execution)

### 1. Brightfield DAB-IHC Analysis
```bash
bash run_one_click.sh \
  "manifest_dab.csv" \
  "results/dab_run" \
  "roi_annotations.csv" \
  "config/analysis_parameters_template.csv" \
  "Rlib" \
  "control,treatment"
```

### 2. Immunofluorescence (IF) Analysis
```bash
bash run_one_click.sh \
  "manifest_if.csv" \
  "results/if_run" \
  "" \
  "config/if_analysis_parameters_template.csv" \
  "Rlib" \
  "control,treatment"
```

---

## IF Manifest Format (`manifest.csv`)

Required columns for multi-channel IF:
```csv
image_id,biological_unit_id,condition,modality,marker,channel_name,channel_index,channel_role,pixel_size_um,z_spacing_um,timepoint,batch,replicate,file_path
SAMPLE_01,Patient_01,control,immunofluorescence,DAPI,DAPI,1,nucleus,0.325,,T0,BATCH_1,1,images/sample_01.tif
SAMPLE_01,Patient_01,control,immunofluorescence,SPATS2,Alexa488_SPATS2,2,target,0.325,,T0,BATCH_1,1,images/sample_01.tif
SAMPLE_01,Patient_01,control,immunofluorescence,Tubulin,Alexa568_Tubulin,3,structural_reference,0.325,,T0,BATCH_1,1,images/sample_01.tif
```

Allowed `channel_role`: `nucleus`, `target`, `cytoplasm_reference`, `membrane_reference`, `structural_reference`, `background_reference`, `other`.

---

## Output Architecture

```
results/
└── immunofluorescence_run/
    ├── source_data/
    │   ├── if_compartment_summary.csv          # 4-compartment MFI, area, integrated intensity
    │   ├── if_biological_unit_summary.csv      # Biological-unit aggregated statistics
    │   ├── if_cell_summary.csv.gz              # Single-cell measurements and N/C ratios
    │   ├── if_channel_summary.csv              # Channel saturation, dynamic range, background QC
    │   ├── if_channel_metadata.csv             # Parsed channel/page/axis metadata
    │   ├── if_roi_exclusion_summary.csv        # Reviewed include/exclude mask audit
    │   ├── if_colocalization_summary.csv       # Pearson r, Manders M1/M2 (if enabled)
    │   ├── if_puncta_summary.csv               # Foci counts, density, intensity (if enabled)
    │   ├── if_image_qc.csv                     # Image-level QC flags and cell counts
    │   └── if_manual_qc_template.csv           # Human auditor sign-off template
    ├── qc/
    │   └── overview/                           # 8-panel QC overviews per image
    └── figures/
        └── main/
            ├── if_main_01_global_mean_intensity.png / .svg / .pdf
            ├── if_main_02_nuclear_mean_intensity.png / .svg / .pdf
            ├── if_main_03_cytoplasmic_mean_intensity.png / .svg / .pdf
            ├── if_main_04_extracellular_positive_fraction.png / .svg / .pdf
            └── if_main_figure_manifest.csv
```

ImageJ TIFF and hyperstack files are parsed from their ImageDescription axes (C/Z/T) rather than inferred from an array dimension. Each image must declare unique `channel_index` values `1..N`; duplicate or ambiguous mappings are rejected. The optional `tiff` R package is installed by `scripts/install_dependencies.R` for compressed TIFFs; the built-in reader covers uncompressed 8/16/32-bit single-sample pages. The validated bit-depth contract includes 12-bit detector-range values stored in a 16-bit container; packed native-12-bit TIFF and OME-XML metadata-aware axis parsing remain experimental.

An empty required target channel is `NOT_EVALUABLE`, not zero-threshold positive. The pipeline never treats the full camera canvas as tissue by default; global/extracellular masks are conservative foreground proxies unless a reviewed mask is supplied.

Reviewed IF polygon annotations may be passed with `--roi`. Include polygons
restrict the analyzed field and exclude polygons remove artifacts or
annotations without changing the raw image. Applied pixel counts and ROI IDs
are recorded in `if_roi_exclusion_summary.csv`.

---

## References and Manuals
- [Methodology & Governance](docs/immunofluorescence_methodology.md)
- [IF Input Formats Guide](docs/if_input_guide.md)
- [Channel Mapping Guide](docs/if_channel_mapping.md)
- [Segmentation Guide](docs/if_segmentation_guide.md)
- [Colocalization Guide](docs/if_colocalization_guide.md)
- [Puncta Detection Guide](docs/if_puncta_guide.md)
- [QC & Flagging Guide](docs/if_qc_guide.md)
- [Validation Benchmarks](docs/if_validation_datasets.md)
