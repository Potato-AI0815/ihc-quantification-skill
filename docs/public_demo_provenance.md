# Public demo provenance

The repository gallery includes two small PNGs derived from public teaching
datasets: BBBC007v1 (CC0 1.0 Public Domain) and Cell Image Library CIL:45501
(Public Domain). The raw microscopy files are not redistributed in this
repository. The PNGs are outputs of the same IF workflow used by the
public-data validation script, with the run configuration and source tables
retained locally for auditability. Licensing details and enforcement are in
[`THIRD_PARTY_ASSETS.md`](../THIRD_PARTY_ASSETS.md) and
[`docs/assets/public_validation/provenance.csv`](assets/public_validation/provenance.csv).

## BBBC007v1 — IF QC overview

- Source dataset: [Broad Bioimage Benchmark Collection BBBC007v1](https://bbbc.broadinstitute.org/BBBC007)
  (field A9 p5; DNA + actin), CC0 1.0 Public Domain.
- Gallery asset: `docs/assets/public_validation/bbbc007_if_8panel_qc.png`
- Demonstrated output: eight-panel input/QC, channel preprocessing, reviewed
  artifact exclusion, segmentation, positive mask, and compartment view.
- Interpretation: two public single-channel fields stacked into one 2-channel
  image (`n = 1` field pair); this is an engineering validation output, not
  evidence for a biological group comparison.
- Withdrawn predecessor: the ImageJ "FluorescentCells"-derived QC panel was
  removed on 2026-08-29 because its redistribution license could not be
  verified from an authoritative source; this CC0-dedicated BBBC007-derived
  panel replaces it.

## CIL45501 — IF colocalization

- Source dataset: [Cell Image Library CIL45501 image](https://cildata.crbs.ucsd.edu/media/images/45501/45501.tif);
  the Public Domain usage statement is carried on the CIL image page
  ([cellimagelibrary.org/images/45501](https://www.cellimagelibrary.org/images/45501)),
  and DOI 10.7295/W9CIL45501 is the citation identifier.
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
