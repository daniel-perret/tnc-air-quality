#### 3.1_fvs_to_raster_rx_bakill.R
#### Associates prescribed fire FVS basal area killed with pixel locations via
#### TreeMap-LandFire imputation. Two metrics: BAkill (ft2/ac) and PctBAkill
#### (% of pre-fire basal area).
#### For each FVS variant: reclassifies the TMLF combination raster using per-stand
#### values, then computes ratios relative to wildfire conditional values (standard mean
#### and top-10% mean).
#### Bakill is taken from the all-species ("ALL") rows of FVS_Mortality in the fire year (2020).
#### Stands with no FVS_Mortality row (no live tree mortality) are assigned Bakill = 0.
#### Pre-fire BA is FVS_Summary BA in 2020 (fire-year rows are pre-fire);
#### stands with BA <= 0 get PctBAkill = NA.
#### Outputs: per-variant rasters in data/dp_FVS_postprocess/{rx_run_name}/{VARIANT}/
#### Requires completed 3.0 and 3.0.1 (Bakill) for the wildfire run.
#### Variant rasters are mosaicked into CONUS layers in 3.2_variant_rasters_merge.R

source("code/FVS_dp/FVS_workflow/0.0_setup.R")

## ---- Configuration ----

setwd(here())

# Completed prescribed fire wet run to rasterize
rx_run_name <- "RxWetRun_03Jun26_2229"

# Completed wildfire run for ratio calculations
wf_run_name <- "Wildfire_WetRun_21May26_0855"

# TreeMap-LandFire combination raster (pixel -> unique TM-LF combination)
tmlf_path <- "data/tmlf_keys/tmlf_key_conus_64bit.tif"

# FVS variant boundaries shapefile
variant_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVSVariantMap20210525/FVS_Variants_and_Locations.shp"

# Metrics to rasterize (column names returned by the SQL query below)
metrics <- c("BAkill", "PctBAkill")


## ---- Setup ----

all_dbs <- list.files(here("FVS_runs/full", rx_run_name, "outputs"), full.names = TRUE)

outpath_root <- here("data/dp_FVS_postprocess", rx_run_name)
dir.create(outpath_root, showWarnings = FALSE)

# Load TMLF raster and variant boundaries
tmlf.ras <- rast(tmlf_path)

variants_vect <- vect(variant_path) %>%
  project(crs(tmlf.ras))

# Unique variants present in run outputs
run_variants <- str_sub(basename(all_dbs), -5, -4) %>% unique()

# Rerun only variants with missing/empty rasters whose wildfire 3.0 inputs exist
# (set FALSE to redo all variants)
rerun_incomplete_only <- TRUE

if (rerun_incomplete_only) {
  source(here("code/FVS_dp/functions/bakill_incomplete_variants.R"))
  run_variants <- incomplete_bakill_variants(
    stage       = "3.1",
    run_name    = rx_run_name,
    wf_run_name = wf_run_name,
    metrics     = metrics
  )
}


## ---- Per-variant rasterization loop ----

terraOptions(memfrac = 0.8, memmax = 24)

for (variant in run_variants) {

  message("Processing variant: ", variant)

  outpath <- file.path(outpath_root, variant)
  dir.create(outpath, showWarnings = FALSE)

  # Variant-clipped TMLF raster; reuse if already created by the emissions workflow
  tmlf.clip.path <- file.path(outpath, paste0("tmlf_key_", variant, ".tif"))

  if (!file.exists(tmlf.clip.path)) {
    variant_poly <- variants_vect[variants_vect$FVSVariant == variant, ]

    tmlf.clip <- crop(tmlf.ras,
                      variant_poly,
                      mask = TRUE)

    writeRaster(tmlf.clip,
                tmlf.clip.path,
                overwrite = TRUE)

    rm(tmlf.clip)
  }

  # Load Rx database for this variant
  rx_db <- all_dbs[str_detect(all_dbs, paste0("_", variant, "\\.db$"))]

  # Start from FVS_Cases so stands with no FVS_Mortality row get Bakill = 0
  # Note: StandID from rx FVS output tables corresponds with TMLF key field
  con <- dbConnect(SQLite(),
                   rx_db)
  # Eastern variants (CS, LS, NE, SN) write FVS_Summary_East instead of FVS_Summary
  summary_tbl <- if ("FVS_Summary" %in% dbListTables(con)) "FVS_Summary" else "FVS_Summary_East"
  reclass.df <- dbGetQuery(con,
                           paste0("SELECT c.StandID,
                                   COALESCE(m.Bakill, 0) AS BAkill,
                                   CASE WHEN s.BA > 0
                                        THEN 100.0 * COALESCE(m.Bakill, 0) / s.BA
                                   END AS PctBAkill
                            FROM FVS_Cases c
                            LEFT JOIN FVS_Mortality m
                              ON c.CaseID = m.CaseID
                             AND m.SpeciesFVS = 'ALL'
                             AND m.Year = 2020
                            LEFT JOIN ", summary_tbl, " s
                              ON c.CaseID = s.CaseID
                             AND s.Year = 2020"))
  dbDisconnect(con)

  reclass.df <- reclass.df %>%
    mutate(StandID = as.integer(StandID))

  wf_outpath     <- here("data/dp_FVS_postprocess", wf_run_name, variant)
  # wf_outpath_90p <- here("data/dp_FVS_postprocess", paste0(wf_run_name, "_90p"), variant)

  for (metric in metrics) {

    rx_name <- paste0("Rx_", metric)

    # Reclassify TMLF raster with Rx values (NA values, BA <= 0, dropped; others = NA)
    reclass.mat <- reclass.df %>%
      select(from = StandID, to = all_of(metric)) %>%
      filter(!is.na(to)) %>%
      as.matrix()

    rx_rast <- terra::classify(rast(tmlf.clip.path), reclass.mat, others = NA)
    names(rx_rast) <- rx_name

    writeRaster(rx_rast,
                file.path(outpath, paste0(rx_name, ".tif")),
                overwrite = TRUE)

    # WF conditional mean (from 3.0) and top-10% mean (from 3.0.1)
    wf_cond     <- rast(file.path(wf_outpath,
                                  paste0("Conditional_mean_", metric, ".tif")))
    # wf_cond_90p <- rast(file.path(wf_outpath_90p,
    #                               paste0("top10pct_mean_", metric, ".tif")))

    # Align extents
    rx_rast     <- crop(rx_rast, wf_cond)
    #wf_cond_90p <- crop(wf_cond_90p, wf_cond)

    # Rx:WF ratios
    writeRaster(rx_rast / wf_cond,
                file.path(outpath, paste0("Rx_WF_", metric, "_ratio.tif")),
                overwrite = TRUE)

    # writeRaster(rx_rast / wf_cond_90p,
    #             file.path(outpath, paste0("Rx_WF_", metric, "_ratio_90p.tif")),
    #             overwrite = TRUE)

    rm(reclass.mat, rx_rast, wf_cond)#, wf_cond_90p)
    gc()
  }

  rm(reclass.df)
  gc()
  message("Variant ", variant, " complete.")
}
