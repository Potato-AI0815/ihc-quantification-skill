# Third-Party Assets — Licensing & Provenance

**Scope**: every bundled image in this repository that derives from, or depicts, a public dataset.
**Machine-readable manifest**: [`docs/assets/public_validation/provenance.csv`](docs/assets/public_validation/provenance.csv)
**Enforcement**: `scripts/preflight_public_release.py` fails unless every bundled public-derived image under
`docs/assets/public_validation/` and `external_validation/results/figures/` has a provenance entry with a
non-empty source URL, an allow-listed license (Public Domain / CC0 / CC BY 4.0), and explicit attribution.

## Policy

1. No private or raw clinical/specimen microscopy is bundled. Raw external-validation datasets (BBBC, HPA,
   CIL originals) stay out of the repository; only small derived figures are tracked.
2. Every public-derived bundled asset requires an explicit, verified license. "Freely downloadable" is not a
   license; downloads are never treated as redistribution permission.
3. Attribution follows each source's requested citation format.
4. Synthetic fixture figures rendered from the deterministic in-repo fixtures are original work and carry no
   third-party source.

## Bundled public-derived assets

| Asset(s) | Source | License | Notes |
|---|---|---|---|
| `docs/assets/public_validation/cil45501_if_colocalization_pearson_r.png` | Cell Image Library **CIL:45501** (human iPSC-derived cells; nestin / beta3-tubulin(Tuj1) / DAPI) | **Public Domain** — usage policy stated on the CIL image page ([cellimagelibrary.org/images/45501](https://www.cellimagelibrary.org/images/45501)); DOI 10.7295/W9CIL45501 is the citation identifier, not the license statement | Attribution: CIL:45501; Abraham Al-Ahmad and Eric Shusta. Derived IF colocalization figure; source OME-TIFF SHA-256 recorded in `provenance.csv`. |
| `docs/assets/public_validation/bbbc007_if_8panel_qc.png` | Broad **BBBC007v1**, field A9 p5 (DNA + actin) | **CC0 1.0 Public Domain** (copyright waived by Anne Carpenter; images courtesy of the laboratory of David Sabatini, Whitehead Institute) | Derived 8-panel IF QC overview; the two public single-channel TIFFs were stacked into one 2-channel TIFF and processed with the frozen IF pipeline. |
| `external_validation/results/figures/BBBC007/*.png` (6 QC plates) | Broad **BBBC007v1** | **CC0 1.0 Public Domain** | Deterministic segmentation QC plates rendered by `external_validation/scripts/validate_bbbc007.R`. |

Requested BBBC007 citation (followed throughout): "We used image set BBBC007v1", Jones et al., Proc. ICCV
Workshop on Computer Vision for Biomedical Image Applications, 2005; Ljosa et al., Nature Methods, 2012.

## Removed assets

| Asset | Reason | Replacement |
|---|---|---|
| `docs/assets/public_validation/fluorescentcells_if_8panel_qc.png` (removed 2026-08-29) | The ImageJ sample image "FluorescentCells" (Molecular Probes demo slide) carries no verifiable public-domain dedication, CC license, or redistribution permission from an authoritative source. "Downloadable" is not "licensable for redistribution". | Replaced by the CC0-dedicated BBBC007-derived QC above (`bbbc007_if_8panel_qc.png`). |

## Dataset-level provenance pointers

- BBBC007 provenance, checksums, and layout: [`external_validation/reports/DATASET_PROVENANCE_BBBC007.md`](external_validation/reports/DATASET_PROVENANCE_BBBC007.md)
- CIL demo run record (download manifest with SHA-256, pipeline commands): `work/PUBLIC_CIL_IF_VALIDATION_REPORT.md`
  (local cache documentation; the tracked provenance row carries the source URL and checksum).
- HPA provenance (no HPA imagery is bundled): [`external_validation/reports/DATASET_PROVENANCE_HPA_IHC.md`](external_validation/reports/DATASET_PROVENANCE_HPA_IHC.md)
