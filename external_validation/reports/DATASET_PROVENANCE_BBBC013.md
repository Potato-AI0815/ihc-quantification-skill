# Dataset Provenance — BBBC013 v1

| Field | Value |
|---|---|
| Dataset | BBBC013 v1 — human U2OS FKHR-EGFP cytoplasm-to-nucleus translocation |
| Official page | https://bbbc.broadinstitute.org/BBBC013 |
| Images download | https://data.broadinstitute.org/bbbc/BBBC013/BBBC013_v1_images_bmp.zip |
| Platemap download | https://data.broadinstitute.org/bbbc/BBBC013/BBBC013_v1_platemap_all.txt |
| Access date | 2026-08-27 |
| Licence | Creative Commons Attribution 3.0 Unported, by Ilya Ravkin |
| Recommended citation | BBBC013v1 provided by Ilya Ravkin; Ljosa et al., Nature Methods 2012 |
| Images archive SHA-256 | `c059b569d96f70ad5626fad144867e6ece4353622119c46a8af8f9794f1e7985` |
| Platemap SHA-256 | `e8db6666271d47962fa7d2abfa3ea965352b8e87bee461f2983d0f667bc7ff08` |
| Dataset selection | All 96 wells × 2 channels; rows A–D Wortmannin (nM), rows E–H LY294002 (µM); one image per channel/well |
| Official layout | Rows A–D (Wortmannin, nM): columns 1–2 negative controls (0), columns 3–11 dose series (0.98–250), column 12 plate-wide positive control (150 nM Wortmannin). Rows E–H (LY294002, µM): column 1 positive control (80), column 2 negative control (0), columns 3–11 dose series (0.31–80), column 12 no-drug ("empty") wells — E12–H12 are **not** LY294002 positive controls |
| Platemap sources | `BBBC013_v1_platemap_all.txt`; per-drug `BBBC013_v1_platemap_wortmannin.txt` (doses in nM) and `BBBC013_v1_platemap_ly294002.txt` (doses in µM) from the official BBBC013 download area |
| Conversion | BMP → uncompressed 8-bit TIFF in the ignored cache using `bmp` + `tiff`; exact integer pixel round-trip checked for every file |
| Software baseline | `8099297a6b64b975e2845aabff6c08f6ca2d8efe` (`v2.3.0-rc2`) before any bugfix |

## Pre-registered design

- Channel 1 is FKHR-EGFP target; Channel 2 is DNA/nuclear stain.
- Biological direction: PI3K/Akt inhibition drives FKHR-EGFP accumulation in
  the nucleus, so the nuclear-to-cytoplasmic ratio is expected to **increase**
  with dose (positive Spearman rho) and positive-control wells are expected
  above negative controls. Nuclear export is not the expected direction.
- Roles follow the official per-drug platemaps: Wortmannin positive control is
  column 12 (150 nM, rows A–D); LY294002 positive control is column 1 (80 µM,
  rows E–H); E12–H12 are no-drug wells, excluded from the LY294002 positive-
  control statistics and reported separately.
- Dose units follow the official per-drug platemap headers: nM for Wortmannin,
  µM for LY294002. Correlations use the platemap dose values within each drug.
- Primary endpoint is the well-level median nuclear-to-cytoplasmic ratio.
- Cells are within-well observations; they are aggregated to the well before
  response summaries. No cell-level p-values are used.
- Each drug is analyzed separately. Spearman dose-response, positive-minus-
  negative effect, and Z-prime are descriptive/assay-quality summaries only.
- Published Z′ values are contextual references, not optimization targets.
