# tnc-air-quality: Project Plan & To-Do

Running list of ideas and tasks. Formal analysis spec lives in
[code/FVS_dp/output_analyses/analysis_plan.md](code/FVS_dp/output_analyses/analysis_plan.md).

**Conventions**: `[ ]` open, `[x]` done, `[~]` in progress / blocked (add a note). Add a date when closing an item.
Priority tags: **P1** (do next), **P2** (soon), **P3** (someday).

---

## In Progress

- [~] **P1** Fix hang in `log_decomp_4_zonal_summaries.R` ("building zone raster cache" ran for hours)
  - Suspect `terra::rasterize()` of HUC12 polygons (single-threaded, in-memory), plus redundant `classify()` pass
  - Option 1 (preferred): `sf::gdal_utils("rasterize", ...)` with `-a zone_int`, `-te`, `-tr`, nodata 0, tiled/compressed output; drop `classify()`
  - Option 2: rasterize per row-block inside workers (no cache)
  - Option 3: rewrite extraction with `exactextractr::exact_extract()` over polygon chunks (as in `summarize_ratio_by_polygons.R`); needs a custom fn for driver-class proportions
  - Test on a small subset (one ecoprovince / few HUC12s) and compare with existing output

## To Do

### Ratio decomposition (`output_analyses/ratio_decomposition/`)

- [ ] **P2** Make workers in Script 4 set `terraOptions(memfrac, threads)` (currently set only in the main session)
- [ ] **P3** Check numerical stability of the sum-of-squares SD formula in Script 4 (cancellation if mean >> SD); consider Welford/Chan combine
- [ ] **P3** Script 4 section 5: variance decomposition uses zone means only (covariance approximated); decide whether pixel-level Cov is needed
- [ ] **P2** Document that zone raster and `_lookup.csv` must be deleted/rebuilt together
- [ ] **P2** Script 5 (visualizations) after Script 4 outputs are regenerated

### FVS postprocessing

- [ ] **P3** Confirm `bakill/` scripts 3.0-3.3 mirror the emissions versions

## Ideas / Parking Lot

- [ ] Convert large shapefiles (HUC12, firesheds) to GeoPackage/FlatGeobuf once to speed reads
- [ ]

## Done

- [x] (2026-11-18) Created this plan file
