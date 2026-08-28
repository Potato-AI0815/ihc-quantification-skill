# BBBC007 Initial Frozen-Method Failure

**Run date**: 2026-08-27

**Software baseline**: `8099297a6b64b975e2845aabff6c08f6ca2d8efe`

**Calibration performed**: none

**Decision**: **FAIL — independent bugfix required**

## Failure observed

The first run used all 16 BBBC007 fields with the frozen rc2 parameters. Every
field reported:

```text
configured maximum propagation radius = 10 px
effective propagation radius = 0 px
maximum observed propagation radius = 0 px
```

The global nearest-neighbour safety cap was determined by the single closest
nuclear pair in each field. In these crowded images, that pair reduced the
radius for every nucleus to zero. The resulting `cell_labels` were exclusive
and contained one nucleus each, but they were effectively nuclear territories,
not cell/cytoplasm segmentation.

The initial weighted 2-px boundary proximity was `0.5876`, but this value is
not accepted as successful cell-boundary recovery: many relevant predicted
pixels were merely interfaces between touching nuclear labels. Visual plates
showed almost no predicted whole-cell boundary over the actin channel,
including the required worst-performing field.

## Why this is a core failure

- `cell_mask_overlap_pixels = 0` and zero multi-nucleus territories confirm
  that merge prevention worked.
- However, zero propagation in all fields fails the explicit requirement for
  individual cell-like boundaries and cytoplasmic compartments.
- The result therefore cannot be promoted as `PASS_WITH_WARNINGS` and blocks
  `v2.3.0-rc3` until corrected and fully revalidated.

## Required bugfix scope

Replace the field-wide radius collapse with per-nucleus local safety radii or
an equivalent exclusive propagation constraint. The 10-px maximum, 1-px
inter-cell gap, one-nucleus-per-cell rule, and frozen watershed settings remain
unchanged. No BBBC007 outcome may be used to tune an accuracy threshold.

The independent fix was implemented in commit
`c8bbe77bf0707574d9b8f4c1cd9b92778ba2cb56` and then re-run against all 16
fields.
