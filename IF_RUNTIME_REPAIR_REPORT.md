# IF Runtime Repair Report

**Scope**: public ImageJ `FluorescentCells.tif` and `confocal-series.tif` runs
**Version**: `2.3.0-alpha.2`
**Status**: **CODE REPAIRED; PUBLIC RERUN PASS WITH WARNINGS**

## Why the previous figures are not valid evidence

The previous public output directories were produced before the ImageJ
hyperstack and QC repairs. They showed the failure pattern that prompted this
review:

- the target channel in `FluorescentCells` was parsed as an all-zero channel;
- an empty corrected channel received threshold `0`, so `>= 0` counted every
  pixel as positive;
- the default tissue mask was the complete camera canvas;
- ImageJ channel pages were inferred from array dimensions rather than from
  `ImageDescription` (`channels`, `slices`, and `images`);
- unpaired point jitter could move hollow points away from their observed
  values;
- a failed image QC state did not prevent publication-figure rendering.

The pre-repair images and tables were retained for forensic comparison only.
The current `work/` outputs were regenerated after the repairs and are the
runtime evidence described below; they still require biological/manual review
before use in a manuscript.

The public `FluorescentCells.tif` itself contains a burned-in ImageJ
instructional annotation near the lower-right edge. The repaired reader keeps
raw pixels unchanged and applies an explicitly reviewed exclusion polygon for
this public smoke test. The applied ROI is recorded in
`source_data/if_roi_exclusion_summary.csv`; it is not an implicit crop or
deleted source data.

## Repairs now in the workflow

1. **ImageJ-aware TIFF reader**
   - reads the embedded ImageJ axis metadata;
   - maps channel pages explicitly using unique `channel_index = 1..N`;
   - preserves the declared Z depth and rejects unsupported time-lapse
     collapse;
   - uses the built-in reader for uncompressed 8/16/32-bit single-sample TIFF
     pages and an explicit optional `tiff` dependency for compressed pages.

2. **Manifest validation**
   - IF input validation now requires `channel_index`;
   - duplicate, missing, or non-contiguous channel mappings stop before image
     processing.

3. **Empty-channel handling**
   - no valid signal returns `EMPTY_CHANNEL` and `threshold_value = NA`;
   - positive pixels, positive area fraction, and positive-cell calls become
     non-evaluable (`NA`), never 100% positive;
   - image QC status becomes `FAIL_REVIEW_REQUIRED` for empty/no-signal or
     otherwise blocking segmentation cases; low-cell-count remains a visible
     warning because some module-level benchmarks intentionally contain fewer
     than ten objects.

4. **Tissue mask**
   - the full canvas is no longer treated as tissue;
   - a conservative nuclear/structural foreground proxy is used when no
     reviewed tissue or ROI mask is supplied;
   - the source and threshold are recorded in segmentation metrics.

5. **Plot and delivery behavior**
   - point-only figures are used for one biological unit instead of a bar/SE
     scaffold;
   - unpaired point jitter has `height = 0`, so y-values are not altered;
   - blocking QC failures write `if_run_status.csv`, retain diagnostic source
     tables, and stop before main publication figures are rendered;
   - the router propagates the child R process exit code;
   - reviewed IF include/exclude polygons are applied before segmentation and
     quantification, while the raw TIFF remains unchanged;
   - static QC panels use a neutral gray fill for excluded pixels instead of
     presenting a black artifact block as biological background.

## Public rerun result

The repaired public smoke test now completes successfully with the local R
runtime:

```text
FluorescentCells: PASS
  ImageJ channels: 3 x 2D pages
  reviewed artifact ROI: applied (13,104 pixels excluded)
  segmented nuclei: 6
  QC: PASS_WITH_WARNING (LOW_CELL_COUNT)

confocal-series: PASS
  2 channels x 25 z-slices preserved
  max projection max 0.23137255 >= mean projection max 0.09019608
```

The low-cell-count warning is retained because this teaching image is a
single public field of view, not a biological replication benchmark.

## Static checks completed

```text
R syntax parse: PASS
static_validate_package.py: PASS
preflight_public_release.py: PASS
verify_package_manifest.py: PASS (130 files)
base TIFF/ImageJ metadata parse: PASS
```

The local validation environment uses R 4.6 with the declared packages in the
repository-local library. Static parsing, runtime repair contracts, and the
public ImageJ smoke test all pass.

The public run is an engineering smoke test, not a substitute for reviewed
segmentation, tissue masks, or biological replication. DAB
backward-compatibility claims are unaffected.
