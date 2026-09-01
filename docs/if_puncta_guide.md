# IF Puncta / Foci Detection Guide

## Applications
- DNA damage foci ($\gamma\text{H2AX}$, 53BP1)
- Autophagy puncta (LC3B)
- RNA-FISH and single-molecule localization
- Punctate granules (Stress granules, PML nuclear bodies)

## Algorithm: Difference of Gaussians (DoG)
1. **Filtering**: Bandpass filter with narrow ($\sigma_1 = 1.0$) and wide ($\sigma_2 = 2.5$) Gaussian kernels:
   $$I_{\text{dog}} = G_{\sigma_1}(I) - G_{\sigma_2}(I)$$
2. **Dynamic Thresholding**: $T = \mu_{\text{dog}} + k \cdot \sigma_{\text{dog}}$ (default $k = 3.0$).
3. **Connected Components & Size Gating**: Objects filtered by area ($2 \le \text{Area} \le 150\text{ px}$).

## Metrics Output
- `puncta_count`: Total puncta count in image or compartment.
- `puncta_count_per_cell`: Average foci per segmented cell.
- `total_puncta_area_px2`: Puncta-positive pixel count (pixel-domain area).
- `total_puncta_area_um2`: Physical puncta area; available only in `physical_calibrated` mode.
- `puncta_density_per_px2`: Puncta count normalized by compartment pixel area; always available.
- `puncta_density_per_um2`: Puncta count normalized by compartment physical area; `NA` in `pixel_fallback` mode.
- `puncta_mean_intensity` & `puncta_integrated_intensity`: Fluorescence burden inside foci (pixel-intensity domain; interpretable without physical calibration).
- `pixel_size_um` / `scale_mode`: record the physical-scale contract for every row.

Physical-unit puncta metrics are never emitted when `pixel_size_um` is missing,
`NA`, non-finite, or `<= 0`; such runs are `pixel_fallback` and emit the
`MISSING_PIXEL_SIZE_CALIBRATION` warning.  The pipeline never assumes
`1 px = 1 um`.
