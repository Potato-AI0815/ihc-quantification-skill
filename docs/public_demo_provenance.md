# Public demo provenance

The repository gallery includes two small PNGs derived from public teaching
datasets. The raw microscopy files are not redistributed in this repository.
The PNGs are outputs of the same IF workflow used by the public-data validation
script, with the run configuration and source tables retained locally for
auditability.

## FluorescentCells — IF QC overview

- Source dataset: [ImageJ sample image — FluorescentCells](https://wsr.imagej.net/images/FluorescentCells.zip)
- Local validation route: `scripts/download_and_verify_public_images.R`
- Gallery asset: `docs/assets/public_validation/fluorescentcells_if_8panel_qc.png`
- Demonstrated output: eight-panel input/QC, channel preprocessing, reviewed
  artifact exclusion, segmentation, positive mask, and compartment view.
- Interpretation: one public teaching image (`n = 1`); this is an engineering
  validation output, not evidence for a biological group comparison.

## CIL45501 — IF colocalization

- Source dataset: [Cell Image Library CIL45501 image](https://cildata.crbs.ucsd.edu/media/images/45501/45501.tif)
- Local validation route: the public CIL IF validation workflow documented in
  `work/PUBLIC_CIL_IF_VALIDATION_REPORT.md` during local testing.
- Gallery asset: `docs/assets/public_validation/cil45501_if_colocalization_pearson_r.png`
- Demonstrated output: Pearson channel-intensity association after the
  workflow's QC, segmentation, compartment assignment, and colocalization
  calculation.
- Interpretation: one public single-image run (`n = 1`); Pearson correlation
  indicates spatial intensity association within the image and does not prove
  molecular binding, physical complex formation, or causality.

## Synthetic-only gallery panels

- `docs/assets/synthetic/dab_synthetic_global_burden_demo.png` is generated
  from the bundled DAB-IHC fixture.
- `docs/assets/synthetic/puncta_synthetic_validation_demo.png` is generated
  from the bundled puncta fixture.

These panels demonstrate reproducible rendering and output contracts. They are
not public biological observations. Public DAB-IHC and public puncta runs are
not bundled in this release, so the README labels these two panels explicitly
instead of presenting them as public-data results.
