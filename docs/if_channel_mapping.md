# IF Channel Mapping and Manifest Specification

## Channel Manifest (`manifest.csv`)
Each row in the IF manifest declares a single channel for an image.

### Required Fields
| Column Name | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `image_id` | String | Unique image identifier | `IMG_001` |
| `biological_unit_id` | String | Biological replicate / sample ID | `Patient_01` |
| `condition` | String | Experimental group / condition | `Treatment` |
| `modality` | String | Must be `immunofluorescence` | `immunofluorescence` |
| `marker` | String | Stained target or stain name | `SPATS2` |
| `channel_name` | String | Channel descriptor in image | `Alexa488_SPATS2` |
| `channel_index` | Integer | 1-based channel slice index | `2` |
| `channel_role` | String | Functional role of the channel | `target` |
| `pixel_size_um` | Numeric (optional) | Physical pixel calibration in microns; missing/`NA`/non-finite/`<=0` switches IF quantification to `pixel_fallback` mode | `0.325` |
| `file_path` | String | Relative or absolute path to TIFF | `images/sample1.tif` |

### Allowed `channel_role` Values
- `nucleus`: Nuclear counterstain (DAPI, Hoechst, DRAQ5) used for primary nuclear segmentation. (Required: at least one per image).
- `target`: Biomarker of interest to be quantified (MFI, integrated intensity, positivity). (Required: at least one per image).
- `cytoplasm_reference`: Structural cytoplasmic stain (Phalloidin, Tubulin, Cytokeratin) used to constrain cell boundary propagation.
- `membrane_reference`: Cell membrane marker (E-Cadherin, Na+/K+ ATPase, WGA).
- `structural_reference`: General organelle or structural marker.
- `background_reference`: Autofluorescence or unstained channel.
- `other`: Generic non-target channel.

> [!CAUTION]
> The pipeline strictly forbids guessing channel roles based on display colors or arbitrary assumptions. All channel semantics must be explicitly mapped in the manifest.

## Physical-scale contract
- `pixel_size_um` finite positive -> `scale_mode = physical_calibrated`; `*_um2` and `*_per_um2` metrics are emitted.
- `pixel_size_um` missing / `NA` / empty / non-finite / `<= 0` -> `scale_mode = pixel_fallback`; `MISSING_PIXEL_SIZE_CALIBRATION` is emitted; all physical-unit metrics are `NA`.
- The pipeline never assumes `1 px = 1 um`. Pixel-domain metrics (`area_px2`, `puncta_density_per_px2`, intensity metrics) remain available.
