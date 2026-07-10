
This document contains information regarding analytical plans and processes related to wildfire and prescribed fire smoke emissions simulations.

## 1. Project Context

**Initialized**: June 12, 2026

**Scope**: Analysis of Forest Vegetation Simulator (FVS) raster outputs from the cleaned production workflow. The workflow generated CONUS-scale estimates of carbon emissions from wildfire and prescribed fire scenarios, conditioned on forest structure, fuel models, and fire behavior across six flame length bins.

**Core Metric**: **T** = the Rx:WF emissions ratio (Rx carbon released from fire / WF carbon released from fire), as specified in Kreider, Urbanski, & Fargione *in press*. T quantifies the relative intensity of prescribed fire to wildfire on a per-pixel basis. Values T \> 1 indicate pixels where Rx emissions exceed WF emissions; T \< 1 indicates pixels where WF emissions exceed Rx emissions. In almost all cases, T should be \< 1.

## 2. Data resources

### 2.1 Primary Raster Outputs

Location: `data/dp_FVS_postprocess/CONUS_mosaic/`

| Raster | File | Size | Description |
|----------------|----------------|----------------|-------------------------|
| WF Mean Emissions | `WF_Conditional_mean_CarbonReleasedFromFire.tif` | 9.8 GB | Wildfire carbon emissions (Mg C/ha), probability-weighted across 6 flame length bins (1, 3, 5, 7, 10, 20 ft) |
| WF Uncertainty (SD) | `WF_Conditional_sd_CarbonReleasedFromFire.tif` | 10.8 GB | Standard deviation of WF emissions; quantifies fire impact uncertainty |
| WF Variation (CV) | `WF_Conditional_cv_CarbonReleasedFromFire.tif` | 11.4 GB | Coefficient of variation (SD/mean) of WF emissions; normalized uncertainty metric |
| Rx Emissions | `Rx_CarbonReleasedFromFire.tif` | 5.6 GB | Prescribed fire carbon emissions (Mg C/ha) per pixel |
| Rx Flame Length | `Rx_FlameLength.tif` | 1.4 GB | Flame length predictions for prescribed fires; auxiliary metric |
| **T Ratio (Masked)** | **`Rx_WF_Ratio_masked.tif`** | **9.5 GB** | **Primary analysis metric**: Rx/WF ratio per pixel, masked to exclude unburnable pixels (WF mean = 0) |

### 2.2 Ancillary data  

Location: `../../../SHARED_DATA/`

| Dataset | Path | Description |
|---------|------|-------------|
| **Pyromes** | `pyromes/Data/Pyromes_CONUS_20200206.shp` | Fire/vegetation regional groupings (vector polygon). Enables stratification of analyses by broad fire ecology regions. |
| **FSIM Burn Probability** | `FSIM/RDS-2020-0016-2__BP_CONUS/BP_CONUS/BP_CONUS.tif` | Raster layer of annual burn probability from USFS Flame and Smoke monitoring. Provides spatial context for fire regimes. |
| **LandFire FBFM40** | `LANDFIRE/LF2022_FBFM40_220_CONUS/Tif/LC22_F40_220.tif` | Raster of fuel models (40-class Anderson classification); 30m resolution. Already used in FVS workflow to classify stands by fuel type. |
| **FVS Variant Boundaries** | `FVSVariantMap20210525/FVS_Variants_and_Locations.shp` | Vector polygon of FVS regional variants (ecological regions used in Forest Vegetation Simulator). Defines geographic extent and stratification for FVS runs. |

**Note**: Additional reference datasets (ecoregions, firesheds, forest types) may be available in SHARED_DATA. Coordinate with project team to identify and document relevant geospatial layers for stratification.

## 3. Initial analyses

### 3.1 Analysis Framework

For each geographic/ecological subset (pyromes, firesheds, ecoregions, forest types), compute the following metrics to characterize T and underlying emissions. This hierarchical approach allows both broad spatial summaries and detailed examination of drivers within each zone.

**Subsets for stratification:**

- **3.1.1 By pyrome**: Regional fire/vegetation groupings (vector layer: `Pyromes_CONUS_20200206.shp`)

- **3.1.2 By fireshed**: Fire-responsive management units (obtain geospatial layer if available)

- **3.1.3 By ecoregion**: Ecological stratification, EPA ecoregions or equivalent (obtain layer if available)

- **3.1.4 By forest type**: Forest type classifications derived from LandFire FBFM groups or TreeMap 2020

------------------------------------------------------------------------

### 3.2 Summary and Distributional Statistics (computed within each subset)

For each geographic/ecological zone, compute:

- **Central tendency**: Mean, median of T, WF emissions, and Rx emissions; area-weighted where appropriate
- **Spread**: Standard deviation, coefficient of variation, interquartile range
- **Quantile breakdown**: 5th, 25th, 50th, 75th, 95th percentiles of T
- **Prevalence**: Proportion of pixels where T \> 1 vs T \< 1; pixel counts and data availability
- **Uncertainty bounds**: 95% CIs on regional T estimates, propagated from WF emissions CV

**Expected outputs**: Summary tables (CSV) by subset; choropleth maps (PNG) showing mean T, WF emissions, Rx emissions, and pixel counts by geographic/ecological zone.

------------------------------------------------------------------------

### 3.3 Distribution Shape and Spatial Structure (global and within subsets)

Characterize variation in T across CONUS and within geographic/ecological subsets:

- **Global statistics**: CONUS-wide mean, median, SD, CV of T; proportion of pixels where T \> 1 vs T \< 1
- **Distribution shape**: Histograms, density plots, Q-Q plots (global and by subset); test for normality and skewness
- **Spatial clustering**: Moran's I or similar autocorrelation test; identify geographic hotspots (high T) and coldspots (low T)
- **Outlier identification**: Pixels with extreme T values; investigate whether they correspond to rare fuel/forest type combinations or data artifacts
- **Uncertainty relationship**: Scatter plots of T vs WF emissions CV; test whether regions with high WF uncertainty also show high T variation

**Expected outputs**: Distribution plots (histograms, density, Q-Q) by subset; spatial autocorrelation statistics; maps of T hotspots/coldspots; scatter plots of T vs WF CV.

------------------------------------------------------------------------

### 3.4 Drivers of T Variation: WF vs Rx Emissions (global and within subsets)

Decompose whether T is driven primarily by high Rx emissions, low WF emissions, or both:

- **Correlation analysis**: Pixel-level Pearson/Spearman correlations between T and (a) WF mean, (b) Rx emissions, computed globally and within each subset
- **Scatter analysis**: 2D scatter plots of WF emissions (x-axis) vs Rx emissions (y-axis), colored by T; identify quadrants where T is high/low (global and by subset)
- **Conditional analysis**: Stratify WF emissions into quartiles; within each quartile, examine distribution and variability of Rx emissions
- **Regional decomposition**: Repeat scatter and correlation analyses by major region (e.g., Southwest, Northwest, Upper Midwest, Southeast)
- **Sensitivity check**: For zones where T \> 1 on average, is this driven by exceptionally high Rx or exceptionally low WF?

**Expected outputs**: Correlation matrices (global and by subset, CSV); multi-panel scatter plots (PNG); summary tables of correlation strength by subset.

------------------------------------------------------------------------

### 3.5 Major Correlates of T (within forest types and fuel characteristics)

Investigate what landscape and forest characteristics explain variation in T beyond geography alone:

- **Forest type**: ANOVA/Kruskal-Wallis tests of T across forest types within each geographic subset; box/violin plots; summary tables
- **Fuel characteristics**: Does T vary systematically with FBFM group, CBH (canopy base height), CHT (canopy height), CBD (canopy bulk density)? Compare within and across subsets.
- **Wildfire flame length regime**: Does T vary by WF flame length environment (high-wind vs. low-wind)?
- **Stand age/structure**: If available, do age-structure variables explain T?
- **Variance partitioning**: After accounting for forest type and fuel structure within a subset, how much of T variation remains attributable to region or other factors?

**Expected outputs**: ANOVA/Kruskal-Wallis summary tables; regression model summaries (linear/GLM of T \~ predictors); box/violin plots of T by forest type/fuel group (by subset); correlation matrices of T with continuous predictors.

------------------------------------------------------------------------

## 4. Methods & Technical Notes

### 4.1 Data Masking

- T raster is pre-masked to remove unburnable pixels (WF mean = 0)
- All analyses use the masked raster; report the number of masked pixels removed in initial summaries
- Avoid division-by-zero artifacts when examining extreme ratios

### 4.2 Spatial Aggregation & Area-Weighting

- Pixel-level summaries should be area-weighted when computing regional means/medians (raster cell size = 30 m)
- When stratifying by polygon zones (pyrome, fireshed, ecoregion), use `terra::extract()` to associate pixels with zones
- Report pixel counts and data availability alongside all summaries

### 4.3 Uncertainty Quantification

- WF uncertainty (SD and CV rasters) should be summarized alongside means
- When computing regional T estimates, propagate uncertainty (e.g., 95% CIs using WF CV)
- Consider whether WF emissions uncertainty explains variation in T

### 4.4 Visualization Standards

- Use consistent color scales across maps (e.g., diverging color scale for T centered at 1.0)
- Include map legends, geographic reference information (state boundaries, projection)
- Report n (pixel count) and data availability alongside all tabular summaries

------------------------------------------------------------------------

## 5. Reference Data Requirements

The following external spatial datasets are needed to complete analyses. **STATUS**: Identify sources and coordinate data acquisition.

- **Pyromes**: Fire/vegetation regional groupings
- **Firesheds**: Fire-responsive management units
- **Ecoregions**: Ecological regions (EPA ecoregions or equivalent)
- **Forest types**: Forest type classifications

---

## 6. Proposed Scripts & Implementation

The following scripts will be developed in `code/FVS_dp/output_analyses/` to implement analyses outlined in sections 3.1–3.5. Scripts are organized into three phases: Setup (0.x), Data Extraction (1.x), Stratified Analyses (2.x), and Visualization (3.x).

### 6.1 Phase 0: Setup & Reference Data

#### **0.0_setup.R**
Load libraries, set visualization themes, and source analysis-specific helper functions.

**Key tasks**: 
- Load analysis libraries (`tidyverse`, `terra`, `sf`, `ggplot2`, `broom`, `spdep`)
- Set visualization theme and output paths
- Initialize parallel processing options

**Outputs**: Global R environment ready for downstream analyses

---

#### **0.1_load_reference_data.R**
Load and validate all spatial reference datasets (pyromes, firesheds, ecoregions, forest types).

**Key tasks**:
- Load pyromes from `SHARED_DATA/pyromes/Data/Pyromes_CONUS_20200206.shp`
- Load additional zone layers (firesheds, ecoregions, forest types) if available
- Validate spatial extent and project to raster CRS (EPSG:5070)
- Save as RDS for downstream use; generate summary statistics

**Outputs**:
- `data/reference_data.rds` — List of sf objects
- `outputs/reference_data_summary.txt` — Validation and counts

---

#### **0.2_load_rasters_to_memory.R**
Load T, WF, Rx, and uncertainty rasters; validate alignment and compute global summary statistics.

**Key tasks**:
- Load primary rasters: T (masked), WF mean/CV, Rx emissions
- Validate CRS, extent, resolution alignment
- Compute and report global statistics (mean, median, SD, CV, NA counts)
- Cache rasters as RDS for repeated downstream access

**Outputs**:
- `data/rasters_loaded.rds` — List of loaded rasters
- `outputs/raster_summary_statistics.csv` — Global summary table

---

### 6.2 Phase 1: Zone-by-Zone Analysis (Memory-Efficient)

Given raster size (~2 billion pixels), Phase 1 adopts a **zone-by-zone workflow** where rasters are cropped and extracted within each geographic/ecological zone, rather than loading all pixels into memory.

#### **1.0_zone_iterator_analysis.R**
Orchestrate zone-by-zone extraction and computation of all statistics (Sections 3.2–3.5) within each zone.

**Approach**:

Iterate over pyromes (or firesheds/ecoregions). For each zone:

1. Crop rasters (T, WF, Rx, WF_CV) to zone boundary using `terra::crop()`
2. Extract pixel values using `terra::values()` (stays in memory only for cropped zone)
3. Compute all statistics for that zone (3.2–3.5 metrics) using cropped data
4. Save zone-specific results (CSV, plots) to `outputs/by_zone/<zone_name>/`
5. Append to cumulative summary tables
6. After all zones, collate summaries into master tables

**Key tasks**:

- Load zone geometries and rasters
- For each zone (pyrome, fireshed, ecoregion):
  - Crop T, WF, Rx, WF_CV to zone boundary
  - Extract pixel values (automatically in memory only for cropped extent)
  - Compute summary statistics (mean, median, SD, CV, quantiles, prevalence of T > 1)
  - Compute distributional stats (histogram, density plot, Q-Q plot)
  - Compute correlations (T ~ WF, T ~ Rx)
  - Create scatter plots and conditional analyses
  - Test for forest_type effects (ANOVA)
  - Save zone-specific results
- Collate all zone-level results into master summary tables and comparison visualizations

**Outputs**:

- `outputs/by_zone/<zone_name>/summary_stats.csv` — Zone-level summary table
- `outputs/by_zone/<zone_name>/distribution_plots.png` — Histograms, density, Q-Q
- `outputs/by_zone/<zone_name>/scatter_WF_vs_Rx.png` — Scatter plot colored by T
- `outputs/by_zone/<zone_name>/boxplots_by_forest_type.png` — T by forest type
- `outputs/summary_by_pyrome.csv` — Collated pyrome summaries
- `outputs/summary_by_fireshed.csv` — Collated fireshed summaries (if available)
- `outputs/summary_by_ecoregion.csv` — Collated ecoregion summaries (if available)
- `outputs/comparison_plots_across_zones.png` — Side-by-side zone comparisons

**Advantages**:

- Memory footprint remains constant (only one zone's pixels in memory at a time)
- Scales to arbitrary raster sizes
- Zone-specific outputs enable detailed inspection
- Naturally parallelizable over zones (via `furrr`)
- Supports all downstream analyses (3.2–3.5) at both zone and global levels

---

### 6.3 Phase 2: Global-Level Analyses & Synthesis

After zone-by-zone analyses complete (script 1.0), global and cross-zone analyses are performed to synthesize findings and identify patterns.

#### **2.0_global_summary_collation.R**
*Implements Sections 3.2–3.5 at global (CONUS) level*

Collate zone-specific results; compute global summaries and cross-zone comparisons.

**Key tasks**:

- Aggregate zone-level summary statistics into CONUS-wide tables
- Compute global distribution plots (histograms, density, Q-Q) from aggregated zone data
- Compute global correlations: T ~ WF, T ~ Rx across all pixels (via summary statistics)
- Identify top/bottom zones by mean T, T variation, WF/Rx drivers
- Create multi-zone comparison visualizations (e.g., side-by-side boxplots, faceted scatter plots)
- Test for significant differences in T across zones (Kruskal-Wallis test)

**Outputs**:

- `outputs/global_summary_table.csv` — CONUS-wide summary statistics
- `outputs/zone_comparison_table.csv` — Mean T, WF, Rx by zone (ranked)
- `outputs/global_distribution_plots.png` — CONUS-wide distributions
- `outputs/zone_comparison_boxplots.png` — T by zone (multi-panel)
- `outputs/kruskal_wallis_test_results.txt` — Statistical test for zone differences

---

#### **2.1_spatial_analysis_global.R**
*Implements spatial structure analysis at global scale*

Analyze spatial autocorrelation and identify hotspots/coldspots globally.

**Key tasks**:

- Load full T raster
- Compute global Moran's I on T (pixel-level spatial autocorrelation)
- Identify high-high and low-low clusters using local Moran's I (or equivalent)
- Map hotspots and coldspots across CONUS
- Relate to zone boundaries: which zones contain hotspots? coldspots?
- Create publication-quality maps

**Outputs**:

- `outputs/spatial_autocorrelation_statistics.txt` — Moran's I results
- `outputs/hotspot_coldspot_map.png` — CONUS map with clusters
- `outputs/hotspot_analysis_by_zone.csv` — Zone attribution of hotspots

---

#### **2.2_uncertainty_analysis.R**
*Implements uncertainty integration (related to Sections 3.2–3.4)*

Analyze how WF emissions uncertainty (CV) relates to T.

**Key tasks**:

- Scatter plot: T vs WF_CV (global and by zone)
- Correlation: does high WF uncertainty correlate with high T variation?
- Propagate WF_CV to compute 95% CIs on zone-level T estimates
- Identify zones where WF uncertainty is high (and implications for T estimates)

**Outputs**:

- `outputs/T_vs_uncertainty_scatter.png`
- `outputs/uncertainty_by_zone_summary.csv` — Zone-level uncertainty metrics
- `outputs/correlation_T_WF_CV.txt` — Correlation statistics

---

### 6.4 Phase 3: Visualization & Reporting

#### **3.0_map_layers.R**
Create publication-quality maps of T, WF, Rx, and uncertainty by zone.

**Key tasks**:

- Map 1: T raster (diverging color scale, centered at 1.0)
- Maps 2–3: WF and Rx emissions rasters
- Map 4: WF uncertainty (CV)
- Maps 5–8: Choropleth maps of mean T by pyrome, fireshed, ecoregion, forest_type

**Outputs**:

- `outputs/maps/T_CONUS.png`
- `outputs/maps/WF_emissions_CONUS.png`
- `outputs/maps/Rx_emissions_CONUS.png`
- `outputs/maps/WF_uncertainty_CONUS.png`
- `outputs/maps/T_by_pyrome.png`
- `outputs/maps/T_by_ecoregion.png`

---

#### **3.1_quarto_report.qmd**
Compile all analyses into a single narrative Quarto document.

**Structure**:

1. Executive summary
2. Data & methods (reference to analysis_plan.md)
3. Results by section (3.2–3.5):
   - Summary statistics and maps
   - Distribution and spatial structure
   - Drivers of T variation
   - Correlates of T
4. Interpretation and key findings
5. Appendix: methodology, uncertainty propagation

**Execution**: Sources output CSVs/PNGs from scripts 2.x and 3.0; renders to HTML

**Outputs**:
- `outputs/FVS_T_Analysis_Report.html`
- `outputs/FVS_T_Analysis_Report.pdf` (optional)

---

### 6.5 Supporting Functions Library

#### **functions/extract_utilities.R**
Reusable functions for raster extraction and data frame operations.

**Functions**:

- `extract_to_zones(raster, zone_sf, zone_name)` — Extract raster values by polygon zones
- `compute_zonal_stats(df, group_col, value_col, area_col)` — Compute zonal summaries
- `propagate_uncertainty(mean_vals, cv_vals)` — Calculate 95% CIs from CV

---

#### **functions/visualization_utilities.R**
Reusable functions for consistent plotting across scripts.

**Functions**:

- `plot_distribution(data, var, title)` — Histograms + density plots
- `plot_scatter_colored(x, y, color, title)` — Colored scatter plots
- `plot_map_raster(raster, title, palette)` — Raster maps with consistent styling
- `plot_boxplot_by_group(data, x, y, title)` — Grouped boxplots

---

### 6.6 Execution Dependency Graph

```
0.0_setup.R
  ├── 0.1_load_reference_data.R
  ├── 0.2_load_rasters_to_memory.R (loads rasters; no cropping yet)
  │   └── 1.0_zone_iterator_analysis.R
  │       ├── 2.0_global_summary_collation.R
  │       ├── 2.1_spatial_analysis_global.R
  │       ├── 2.2_uncertainty_analysis.R
  │       └── 3.0_map_layers.R
  └── 3.1_quarto_report.qmd (runs all 2.x and 3.0 scripts)
```

**Parallel execution**: 

- Script 1.0 can parallelize zone-by-zone processing using `furrr` (zones processed in parallel)
- Scripts 2.0–2.2 can run in parallel after 1.0 completes (each is independent)
- Script 3.0 (mapping) depends on 2.0 for collated summaries and 0.2 for rasters

---

### 6.7 Implementation Notes

1. **Memory-efficient zone-by-zone approach**: Script 1.0 iterates through zones (pyromes, firesheds, ecoregions, forest_types), cropping and extracting rasters zone-by-zone. Only one zone's pixels are in memory at a time, allowing the workflow to scale to arbitrary raster sizes (2 billion+ pixels).

2. **Parallelization**: Script 1.0 can parallelize zone processing using `furrr` (following project patterns in cleaned_workflow). Each zone is processed independently by a worker, with results saved to zone-specific output directories and aggregated at the end.

3. **Missing reference data**: Confirm firesheds, ecoregions, forest_type availability in SHARED_DATA before implementing scripts. If unavailable, skip corresponding zone iterations in script 1.0.

4. **Spatial autocorrelation** (Script 2.1): Computing Moran's I on full CONUS raster may be intensive. Consider:
   - Using `spdep::moran.test()` with a weight matrix based on spatial adjacency, or
   - Sampling pixels for preliminary analysis, then full raster for final results, or
   - Using focal (local) Moran's I for hotspot identification (more efficient)

5. **Publication readiness**: Script 3.1 can be adapted for journal submission, methods appendix, or internal technical report.
