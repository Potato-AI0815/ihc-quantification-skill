# Migration from v2.1 to v2.2

## Existing inputs

Existing v2.1 manifests, ROI files, and parameter files remain valid. New parameters have defaults and are optional.

## Changed main results

v2.1 commonly plotted one configured-domain H-score. v2.2 automatically writes four domain-specific figures:

1. global tissue DAB-positive area fraction;
2. nuclear H-score;
3. cytoplasmic H-score;
4. extracellular DAB-positive area fraction.

The old `h_score` column remains for backward compatibility and follows `cell_scoring_domain`. New analyses should use explicit domain columns when the biological localization is known.

## New QC files

Expect additional files under:

- `qc/qc_overview/`;
- `qc/compartment_overlays/`;
- `qc/masks/`;
- `qc/roi_evidence/crops/`;
- `qc/stain_channels/*_hdab_reconstruction.png`.

## Runtime fix

Do not reapply the temporary v2.1 `data.table` patch. The fix is already integrated into v2.2.

## Required action

Rerun the synthetic smoke test and then rerun the real dataset from raw images. Do not merge v2.1 and v2.2 numeric tables manually.

## v2.2.2 correction note

The v2.2.2 maintenance update fixes publication-axis ranges, low-n captions, text clipping, QC threshold evidence, and GitHub release engineering without changing the v2.2 core quantification formulas. Rerun from raw images rather than reusing v2.2 figures.
