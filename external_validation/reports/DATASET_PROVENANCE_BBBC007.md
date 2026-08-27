# Dataset Provenance — BBBC007 v1

| Field | Value |
|---|---|
| Dataset | BBBC007 v1 — Drosophila Kc167 cells |
| Official page | https://bbbc.broadinstitute.org/BBBC007 |
| Images download | https://data.broadinstitute.org/bbbc/BBBC007/BBBC007_v1_images.zip |
| Outlines download | https://data.broadinstitute.org/bbbc/BBBC007/BBBC007_v1_outlines.zip |
| Access date | 2026-08-27 |
| Licence | CC0 / copyright and related rights waived to the extent possible |
| Recommended citation | BBBC007v1; Jones et al., CVBIA 2005; Ljosa et al., Nature Methods 2012 |
| Images archive SHA-256 | `b7009e2fce0a3152a5c9adda916eaa699d09696f4bd02a7d05d12d041e30c6d1` |
| Outlines archive SHA-256 | `6a5246f9a9d743d22eafdb409fae638a8461af97e9ff9c4a92f25eba236224d3` |
| Dataset selection | All 16 complete DNA/actin fields with matching nuclear/cell outlines; no result-based exclusion |
| Conversion | None; 8-bit TIFF intensity values are read directly. One-bit outline TIFFs are decoded into enclosed instance labels without intensity rescaling. |
| Software baseline | `8099297a6b64b975e2845aabff6c08f6ca2d8efe` (`v2.3.0-rc2`) |

## Locked analysis parameters

The core values are those frozen in `EXTERNAL_VALIDATION_BASELINE.md`:

```text
nuclear threshold = Otsu
nuclear area = 20–5000 px
watershed tolerance/ext = 1.0 / 1
cell propagation radius = 15 px requested
maximum cytoplasm expansion = 10 px
inter-cell gap = 1 px
```

No BBBC007 image is used for calibration.

## Pre-registered outcome rules

- Evaluate every complete field.
- Nucleus objects use one-to-one IoU matching at IoU >= 0.5.
- Relevant predicted cell-boundary pixels are interfaces between two non-zero
  predicted cell labels; exterior cell/background edges are excluded.
- Structural failure occurs if any predicted label map contains overlapping
  cell memberships or a predicted cell contains more than one segmented
  nucleus.
- `PASS`: mean relevant-boundary agreement within 2 px >= 0.60,
  one-nucleus-per-cell fraction >= 0.95, and no structural failure.
- `PASS_WITH_WARNINGS`: boundary agreement within 2 px >= 0.40 and
  one-nucleus-per-cell fraction >= 0.90, with no structural failure.
- Otherwise: `FAIL`.

## Visual evidence selection

Six fields are chosen by fixed rules, not appearance:

1. minimum GT cell count (low density);
2. closest to median GT cell count (medium density);
3. maximum GT cell count (high density);
4. maximum manual boundary-pixel fraction (touching-cell proxy);
5. maximum GT cell-area coefficient of variation (irregular-cell proxy);
6. lowest measured 2-px boundary agreement (worst-performing field).

Duplicate selections are resolved by the next-ranked unused field. The worst
field is always retained.
