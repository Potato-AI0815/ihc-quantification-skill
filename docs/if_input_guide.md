# IF Input and Format Support Guide

## Validated Formats
The core IF pipeline natively supports standard multi-dimensional TIFF formats:
- `.tif` / `.tiff` (Single-channel 8/16-bit, multi-channel composite, multi-plane Z-stack)
- **ImageJ TIFF / hyperstack** with explicit C/Z/T metadata

The following are experimental and not formally validated by the current I/O
contract: OME-TIFF metadata-aware axis parsing and packed native-12-bit TIFF.
Values from a 12-bit detector stored in a 16-bit TIFF container are covered by
the validation fixture.

### Axis Ordering
For ImageJ TIFFs the reader uses the embedded `ImageDescription` metadata (`channels`, `slices`, and `images`) and maps channel pages explicitly; it does not guess C/Z/T axes from an array dimension. The manifest must contain one unique `channel_index` for each declared channel.

For non-ImageJ TIFFs the reader supports these explicit dimension contracts:
- 2D Single Channel: $(X \times Y)$
- 3D Multi-channel: $(X \times Y \times C)$
- 3D Z-stack: $(X \times Y \times Z)$
- 4D Multi-channel Z-stack: $(X \times Y \times C \times Z)$ or $(X \times Y \times Z \times C)$

Compressed TIFFs require the optional R `tiff` package. Unsupported or ambiguous axes stop the run instead of silently duplicating a channel.

### Reviewed artifact and field-of-view ROIs

Pass an IF ROI table with `--roi=...` when the source image contains a
burned-in annotation, scale bar, border artifact, or a reviewed field-of-view
polygon. The table follows `references/templates/if_roi_annotations_template.csv`.
`include` polygons restrict the analysis field; `exclude` polygons remove
artifacts. Raw pixels remain unchanged, and the applied mask is recorded in
`source_data/if_roi_exclusion_summary.csv`.

### Z-Stack Projections
When 3D Z-stacks are provided, the pipeline supports:
- `max_projection`: Maximum intensity projection (default, recommended for standard confocal/epifluorescence)
- `mean_projection`: Average intensity across focal planes
- `sum_projection`: Summed intensity across slices
- `single_plane`: Mid-plane slice extraction

---

## Proprietary Microscope Formats (.czi, .lif, .nd2)
Proprietary formats from Zeiss (.czi), Leica (.lif), and Nikon (.nd2) must be exported to ImageJ TIFF/hyperstack or standard multi-channel TIFF before core processing. OME-TIFF export may be used experimentally, but its OME-XML axes must be manually verified before quantification:
- Use Fiji / ImageJ: `Plugins > Bio-Formats > Bio-Formats Exporter` -> save as `OME-TIFF`.
- Or use automated python conversion: `aicsimageio` or `bioformats2raw`.
