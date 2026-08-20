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
- `puncta_density_per_um2`: Puncta count normalized by compartment physical area.
- `puncta_mean_intensity` & `puncta_integrated_intensity`: Fluorescence burden inside foci.
