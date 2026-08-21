# Log-Decomposition Analysis of the T Ratio: Implementation Plan

**Date**: 2026-08-13  
**Author**: Posit Assistant  
**Context**: Wildfire/Rx fire emissions pipeline — CONUS raster analysis

---

## 1. Overview and Mathematical Foundation

T = Rx / WF (prescribed fire carbon emissions / wildfire carbon emissions per pixel).

The log-decomposition identity:

> **log(T) = log(Rx) − log(WF)**

This means any departure of T from a reference value decomposes *additively* in log-space:

> **δ log(T) = δ log(Rx) − δ log(WF)**

where δ denotes departure from a reference mean (global, or conditioned on an ecological zone). Define:

- **Rx-pull** = δ log(Rx) — positive when Rx emissions are above average (pushes T up)
- **WF-pull** = −δ log(WF) — positive when WF emissions are *below* average (also pushes T up)

Both pulls are additive: δ log(T) = Rx-pull + WF-pull.

**Relative influence** of each component:
- A pixel/zone is **Rx-driven** when |Rx-pull| > |WF-pull|
- A pixel/zone is **WF-driven** when |WF-pull| > |Rx-pull|
- Pulls in the same direction are **reinforcing**; in opposite directions, **opposing**

**Global variance decomposition** across all zones:

> Var(log T) = Var(log Rx) + Var(log WF) − 2·Cov(log Rx, log WF)

This partitions total variance in log(T) into contributions from Rx variation, WF variation, and their covariance (which can dampen or amplify total T variance depending on sign).

---

## 2. Jensen's Inequality: Pixel-Level vs. Zonal-Level Consistency

Because log is concave, mean[log(X)] ≠ log(mean[X]) in general. This matters for how we handle zonal summaries:

- At the **pixel level**, the decomposition is exact: log(T_i) = log(Rx_i) − log(WF_i).
- At the **zone level**, using log(zone_mean_T) vs. zone_mean[log(T)] introduces a bias (Jensen's gap), which grows with within-zone variance.
- The existing CSVs provide zone means of T, WF, Rx — so they give log(zone_mean_X), not zone_mean[log(X)].

**Plan**: Work at two levels:
1. **Approximate zonal decomposition** from existing CSVs: use log(mean_T) = log(mean_Rx) − log(mean_WF) at each zone. Flag that log(mean_T) ≈ log(mean_Rx) − log(mean_WF) is only approximate due to Jensen's inequality.
2. **Exact pixel-level decomposition** via raster operations: compute log-rasters, sample/aggregate into zones after transformation. This is the rigorous path and the main deliverable for the raster-level script.

---

## 3. Scale Variation Analysis

### 3.1 Goal

Determine which spatial/ecological scale best captures variation in T (and its components), to inform the appropriate reference level for departure calculations. We have zonal summary data at five scales:

| Scale | Zones | Components available |
|---|---|---|
| HUC8 | ~2,115 | T |
| HUC10 | ~15,234 | T, Rx |
| HUC12 | ~79,163 | T, WF, Rx |
| Firesheds | ~7,571 | T |
| EcoMapProvince × forest type | ~1,883 | T, WF, Rx |

### 3.2 Metrics to Compute at Each Scale

From zone means (μ_z) and within-zone SDs (σ_z), weighted by pixel count (n_z) where available:

**Between-zone variance**:

> B = weighted Var(μ_z) = Σ n_z·(μ_z − μ̄)² / (Σ n_z − 1)

**Within-zone variance** (pooled):

> W = weighted mean(σ_z²) = Σ n_z·σ_z² / Σ n_z

**Pseudo-ICC (intraclass correlation)**:

> ICC = B / (B + W)

ICC = 1 means all variation is between zones (zones are perfectly internally homogeneous).  
ICC = 0 means zones capture no variation — all variation is within-zone.

**Coefficient of variation of zone means**:

> CV_between = SD(μ_z) / mean(μ_z)

This gives the normalized spread of zone averages (i.e., how much zones differ from each other, without reference to within-zone spread).

**Note**: HUC and fireshed CSVs do not include pixel counts (n). ICC is computed unweighted for these scales. Only the eco×fortype files include n, enabling weighted ICC.

### 3.3 EcoMapProvince × Forest Type: Two-Way Decomposition

The eco×fortype table is a two-way design. Compute separately:
- **Province-level ICC**: aggregate each province's mean across all its forest types (weighted by n); compute ICC using province-level means vs. within-province variation.
- **Forest-type-level ICC**: aggregate each forest type's mean across all provinces; compute ICC using fortype means vs. within-fortype variation.
- **Interaction ICC**: residual variation in the full province × fortype table after removing province and fortype main effects.

### 3.4 Outputs

- Summary table: ICC and CV_between for T (and where available, WF and Rx) at each scale
- Visualization: ridgeline/density chart of zone means at each scale, showing the spread of zone-level T across CONUS
- Heatmap for eco×fortype: province on rows, forest type on columns, cell fill = mean log(T), ordered by marginal means

### 3.5 Informing the Reference Scale

The scale variation results guide departure calculations:
- **If ICC is high at a coarse scale** (e.g., eco province), most variation in T is between provinces. Within-province departures will then reveal fine-scale drivers.
- **If ICC is low everywhere**, T is highly variable within all zones; global departures are the most appropriate reference.
- **Recommended approach**: Always compute global departures; additionally compute conditional departures at the best-supported scale (highest ICC that is also ecologically meaningful). Report both.

---

## 4. Log-Decomposition Workflow

### 4.1 Zonal Decomposition from Existing CSVs (Immediate)

**Input**: Existing CSVs at each scale with mean_T, mean_WF, mean_Rx per zone.

**Steps**:

1. Join T, WF, Rx CSVs per scale (where all three are available: HUC12, eco×fortype).
2. Compute log-transformed means:
   - log_T = log(mean_T), log_WF = log(mean_WF), log_Rx = log(mean_Rx)
   - Verify: log_T ≈ log_Rx − log_WF (should hold approximately; report residuals)
3. Compute CONUS-reference values (weighted by n where available):
   - ref_log_T = weighted.mean(log_T, n), similarly for log_WF and log_Rx
4. Compute zone-level departures:
   - d_logT = log_T − ref_log_T
   - d_logRx = log_Rx − ref_log_Rx
   - d_logWF = log_WF − ref_log_WF
5. Compute pulls:
   - rx_pull = d_logRx
   - wf_pull = −d_logWF
6. Compute relative influence:
   - total_pull_abs = |rx_pull| + |wf_pull|
   - rx_frac = rx_pull / total_pull_abs  ∈ [−1, 1]  (positive = Rx elevates T)
   - wf_frac = wf_pull / total_pull_abs  (positive = low WF elevates T)
7. Classify each zone:
   - `driver`: "Rx" if |rx_pull| > |wf_pull| × 1.1, "WF" if |wf_pull| > |rx_pull| × 1.1, "Mixed" otherwise
   - `T_direction`: "above_mean" / "below_mean"
   - `reinforcing`: TRUE if rx_pull and wf_pull have the same sign (both elevate or both suppress T)
8. Compute conditional departures relative to eco province means (for HUC12):
   - Join HUC12 to eco provinces spatially (or use existing crosswalk if available)
   - Compute province-mean log(T), log(Rx), log(WF)
   - Conditional departures = zone value − province mean
   - Repeat classification from steps 5–7

**Output**: Enhanced zonal summary CSV per scale, with columns:
`zone_id, n, mean_T, mean_WF, mean_Rx, log_T, log_WF, log_Rx, d_logT, d_logRx, d_logWF, rx_pull, wf_pull, rx_frac, driver, T_direction, reinforcing`

### 4.2 Pixel-Level Raster Decomposition (Rigorous)

**Input**: 
- `WF_Conditional_mean_CarbonReleasedFromFire_FRG_masked.tif`
- `Rx_CarbonReleasedFromFire_FRG_masked.tif`
- `Rx_WF_ratio_masked_FRG.tif`

All inputs use the FRG mask throughout. Rx has no zero pixels under the FRG mask.

**Steps**:

1. Compute log-rasters:
   - `log_WF.tif` = log(WF_raster)
   - `log_Rx.tif` = log(Rx_raster)
   - `log_T.tif` = log_Rx − log_WF (verify against log(T_raster))
2. Compute CONUS reference values:
   - Use terra::global() with mean on each log-raster
   - Reference: ref_log_Rx, ref_log_WF, ref_log_T = ref_log_Rx − ref_log_WF
3. Compute departure rasters:
   - `d_logRx.tif` = log_Rx − ref_log_Rx
   - `d_logWF.tif` = log_WF − ref_log_WF
   - `d_logT.tif` = d_logRx − d_logWF  (= log_T − ref_log_T)
4. Compute pull rasters:
   - `rx_pull.tif` = d_logRx
   - `wf_pull.tif` = −d_logWF
5. Compute influence rasters:
   - `rx_frac.tif` = rx_pull / (|rx_pull| + |wf_pull|)
   - `driver_class.tif` (categorical integer): 
     - 1 = Rx-dominant, T above mean
     - 2 = WF-dominant, T above mean
     - 3 = Rx-dominant, T below mean
     - 4 = WF-dominant, T below mean
     - 5 = Mixed (pulls within 10% of each other in magnitude)
6. Aggregate log-rasters to zones:
   - For each zone type, compute zone mean of log_Rx, log_WF, log_T, rx_pull, wf_pull, rx_frac
   - These are zone_mean[log(X)] — the correct aggregation for log-space decomposition, avoiding Jensen's inequality

**Output rasters** (in `data/dp_FVS_postprocess/CONUS_mosaic/ratio_decomposition/`):
- `log_WF.tif`, `log_Rx.tif`, `log_T.tif`
- `d_logWF.tif`, `d_logRx.tif`, `d_logT.tif`
- `rx_pull.tif`, `wf_pull.tif`
- `rx_frac.tif`
- `driver_class.tif`

**Note on memory/performance**: Write all intermediates to disk using `filename=` arguments rather than holding in memory. Use `terraOptions(memfrac=0.8)`.

### 4.3 Conditional Departures (Multi-Level)

After global departures are computed, compute conditional departures at the chosen reference scale (informed by Script 1):

1. Aggregate log-rasters to reference zones (e.g., eco provinces): compute zone_mean[log(Rx)], zone_mean[log(WF)] per province
2. Rasterize those provincial means back to the pixel grid
3. Subtract provincial mean from global log-rasters → conditional departure rasters
4. Rerun the pull/driver classification on conditional departures

---

## 5. Zonal and Spatial Summaries of the Decomposition

### 5.1 Zone-Level Summary Metrics

For each zone type, summarize:
- Mean and SD of rx_frac across pixels in zone
- Fraction of pixels classified as Rx-driven, WF-driven, Mixed
- Fraction where pulls are reinforcing vs. opposing
- Weighted mean of d_logT, d_logRx, d_logWF
- Magnitude: mean |d_logT| (average departure from CONUS mean)

### 5.2 Key Synthesis Questions

- **Which regions are Rx-driven vs. WF-driven in T?** (expected: Rx-driven in low-severity regimes; WF-driven in high-severity regimes)
- **Where are pulls reinforcing vs. opposing?** Opposing pulls (e.g., high Rx AND high WF) produce moderate T even though both components are elevated — important for interpretation
- **Does the dominant driver change at different scales?** A region may be WF-driven at the HUC12 level but Rx-driven within specific forest types

### 5.3 Variance Decomposition Summary Table

For each scale, report (using the pixel-level aggregated data):
- Var(log T), Var(log Rx), Var(log WF) across zones
- Cov(log Rx, log WF) across zones
- % of Var(log T) attributable to Rx: Var(log Rx) / Var(log T) × 100
- % attributable to WF: Var(log WF) / Var(log T) × 100
- Covariance term: −2·Cov(log Rx, log WF) / Var(log T) × 100

---

## 6. Scripts

All scripts live in `code/FVS_dp/output_analyses/ratio_decomposition/`. They follow the project's `%>%` (magrittr) pipe convention and `furrr`/`future.callr` parallelization pattern where needed.

| Script | Inputs | Dependencies |
|---|---|---|
| `log_decomp_1_scale_variation.R` | Existing zonal CSVs | None |
| `log_decomp_2_zonal_decomp.R` | Existing zonal CSVs | Script 1 (reference scale) |
| `log_decomp_3_raster_decomp.R` | FRG-masked rasters | None (run in parallel with 1–2) |
| `log_decomp_4_zonal_summaries.R` | Decomp rasters + zone polygons | Script 3 |
| `log_decomp_5_visualizations.R` | CSVs from 2 & 4; rasters from 3 | Scripts 2–4 |

### Output locations

| Type | Directory |
|---|---|
| Zonal summary CSVs | `data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/` |
| Decomposition rasters | `data/dp_FVS_postprocess/CONUS_mosaic/ratio_decomposition/` |
| Figures | `outputs/ratio_decomposition/` |

---

## 7. Execution Dependencies

```
log_decomp_1_scale_variation.R    ← existing CSVs only; run first
log_decomp_2_zonal_decomp.R       ← existing CSVs only; run after Script 1
log_decomp_3_raster_decomp.R      ← rasters; can run in parallel with Scripts 1–2
log_decomp_4_zonal_summaries.R    ← depends on Script 3
log_decomp_5_visualizations.R     ← depends on Scripts 2 and 4
```

---

## 8. Open Questions

1. **Reference scale for conditional departures**: Script 1 will resolve this empirically. Placeholder: eco province level, pending ICC results.

2. **"Mixed" driver threshold**: The 10% threshold for the "Mixed" class may need tuning based on the actual distribution of |rx_pull| / |wf_pull| ratios.

3. **WF uncertainty propagation**: Flagged as a future extension. The WF CV raster could be used to propagate uncertainty through the decomposition but is not implemented in this script sequence.
