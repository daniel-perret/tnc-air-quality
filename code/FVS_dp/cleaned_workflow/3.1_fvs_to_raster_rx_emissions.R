#### 3.1_fvs_to_raster_rx_emissions.R
#### Associates prescribed fire FVS emissions with pixel locations via TreeMap-LandFire
#### imputation. For each FVS variant: reclassifies the TMLF combination raster using
#### per-stand emissions and flame lengths, then computes ratio relative to wildfire
#### conditional emissions.
#### Outputs: per-variant rasters in data/dp_FVS_postprocess/{rx_run_name}/{VARIANT}/
#### Variant rasters are mosaicked into CONUS layers in 3.4_variant_raster_merge.R

source("code/FVS_dp/cleaned_workflow/0.0_setup.R")

## ---- Configuration ----

setwd(here())

# Completed prescribed fire wet run to rasterize
rx_run_name <- "RxWetRun_28May26_1323"

# Completed wildfire run for ratio calculations
wf_run_name <- "Wildfire_WetRun_21May26_0855"

# TreeMap-LandFire combination raster (pixel → unique TM-LF combination)
tmlf_path <- "data/tmlf_keys/tmlf_key_conus.tif"

# TreeMap-LF combination lookup table
tmlf_key_path <- "data/tmlf_keys/tmlf_key_conus.csv"

# FVS variant boundaries shapefile
variant_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVSVariantMap20210525/FVS_Variants_and_Locations.shp"


## ---- Setup ----

all_dbs <- list.files(here("FVS_runs/full", rx_run_name, "outputs"), full.names = TRUE)

outpath_root <- here("data/dp_FVS_postprocess", rx_run_name)
dir.create(outpath_root, showWarnings = FALSE)

# Load TMLF raster and variant boundaries
tmlf.ras <- rast(tmlf_path)
#activeCat(tmlf.ras) <- 1  # verify column index for tmlf_key_conus.tif

variants_vect <- vect(variant_path) %>% 
  project(crs(tmlf.ras))

# TMLF lookup table (key → TreeMap StandID and LandFire FBFM)
tmlf_key <- read.csv(tmlf_key_path)

# Unique variants present in run outputs
run_variants <- str_sub(basename(all_dbs), -5, -4) %>% unique()


## ---- Per-variant rasterization loop ----

terraOptions(memfrac = 0.8, memmax = 24)

for (variant in run_variants) {

  message("Processing variant: ", variant)

  outpath <- file.path(outpath_root, variant)
  dir.create(outpath, showWarnings = FALSE)

  # Crop TMLF raster to variant boundary
  variant_poly <- variants_vect[variants_vect$FVSVariant == variant, ]
  
  tmlf.clip    <- crop(tmlf.ras,
                       variant_poly,
                       mask = TRUE)
  
  tmlf.clip.path <- file.path(outpath, paste0("tmlf_key_", variant, ".tif"))
  
  writeRaster(tmlf.clip,
              tmlf.clip.path,
              overwrite = TRUE)
  
  rm(tmlf.clip)

  # Load Rx database for this variant
  rx_db <- all_dbs[str_detect(all_dbs, paste0("_", variant, "\\.db$"))]

  con <- dbConnect(SQLite(),
                  rx_db)
  rx_carbon <- dbGetQuery(con,
                          "SELECT StandID, Carbon_Released_From_Fire
                                  FROM FVS_Carbon WHERE Year = 2020")
  rx_burnrep <- dbGetQuery(con,
                           "SELECT StandID, Flame_length
                                   FROM FVS_BurnReport")
  dbDisconnect(con)

  # Join emissions and flame length, then join to TMLF key to get combination IDs
  # Note: StandID from rx FVS output tables corresponds with TMLF key field
  reclass.df <- rx_carbon %>%
    rename(Rx_CarbonReleasedFromFire = Carbon_Released_From_Fire) %>%
    left_join(rx_burnrep %>%
                rename(Rx_FlameLength = Flame_length),
              by = "StandID") %>%
    mutate(StandID = as.integer(StandID)) %>%
    left_join(tmlf_key %>%
                select(real.key, tm, lf) %>%
                rename(key = real.key, TM_StandID = tm),
              by = c("StandID" = "key"))

  target_vars <- c("Rx_CarbonReleasedFromFire", "Rx_FlameLength")

  # Reclassify raster for emissions and flame length in parallel
  process_var <- function(var) {
    reclass.mat <- reclass.df %>%
      select(from = StandID, to = all_of(var)) %>%
      as.matrix()

    out <- terra::classify(rast(tmlf.clip.path), reclass.mat, others = NA)
    names(out) <- var

    writeRaster(out, file.path(outpath, paste0(var, ".tif")), overwrite = TRUE)
    gc()
  }

  future::plan(future.callr::callr,
               workers = parallel::detectCores() - 2)
  
  furrr::future_map(target_vars, 
                    process_var)

  # Load WF conditional emissions for this variant and compute ratio
  wf_outpath <- here("data/dp_FVS_postprocess",
                     wf_run_name,
                     variant)
  wf_cond <- rast(file.path(wf_outpath,
                            "Conditional_mean_CarbonReleasedFromFire.tif"))

  rx_emit <- rast(file.path(outpath,
                            "Rx_CarbonReleasedFromFire.tif"))

  # Align extents
  rx_emit <- crop(rx_emit, wf_cond)
  #wf_cond <- crop(wf_cond, rx_emit)

  ratio <- rx_emit / wf_cond

  writeRaster(ratio,
              file.path(outpath,
                        "Rx_WF_ratio.tif"),
              overwrite = TRUE)

  rm(rx_carbon, rx_burnrep, reclass.df, wf_cond, rx_emit, ratio)
  gc()
  message("Variant ", variant, " complete.")
}
