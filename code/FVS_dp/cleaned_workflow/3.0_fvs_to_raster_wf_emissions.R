#### 3.0_fvs_to_raster_wf_emissions.R
#### Associates wildfire FVS emissions with pixel locations via TreeMap imputation.
#### For each FVS variant: reclassifies the TMFM2020 raster using per-stand emissions
#### for each flame length bin, then computes conditional expected emissions weighted
#### by FlamStat flame length probability rasters.
#### Outputs: per-variant rasters in data/dp_FVS_postprocess/{wf_run_name}/{VARIANT}/
#### Variant rasters are mosaicked into CONUS layers in 3.4_variant_raster_merge.R


## ---- Configuration ----

# Completed wildfire wet run to rasterize
wf_run_name <- "Wildfire_WetRun_XXXX"

# TreeMap raster (pixel -> TreeMap StandID)
tm_path <- "data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif"

# FVS variant boundaries shapefile
variant_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVSVariantMap20210525/FVS_Variants_and_Locations.shp"

# FlamStat flame length probability rasters directory (pre-treatment baseline)
fl_prob_dir <- "data/flamstat/flamelength_rasters/PreTreatment_CONUS/"


## ---- Setup ----

all_dbs <- list.files(here("FVS_runs/full", wf_run_name, "outputs"), full.names = TRUE)

outpath_root <- here("data/dp_FVS_postprocess", wf_run_name)
dir.create(outpath_root, showWarnings = FALSE)

# Load TreeMap raster once; cropped per variant in loop
tm.ras <- rast(tm_path)
activeCat(tm.ras) <- 8  # verify column index for TMFM2020_FVSVariant_Key.tif

# Load variant boundaries and reproject to match TreeMap CRS
variants_vect <- vect(variant_path) %>%
  project(crs(tm.ras))

# Unique variants present in run outputs
run_variants <- str_sub(basename(all_dbs), -5, -4) %>% unique()

# FL probability rasters sorted by ascending FL value
fl_prob_files <- list.files(fl_prob_dir, pattern = "\\.tif$", full.names = TRUE) %>%
  str_subset("Conditional", negate = TRUE) %>%
  str_subset("NoBurn",      negate = TRUE)
fl_prob_files <- fl_prob_files[order(parse_number(basename(fl_prob_files)))]


## ---- Per-variant rasterization loop ----

for (variant in run_variants) {

  message("Processing variant: ", variant)

  outpath <- file.path(outpath_root, variant)
  dir.create(outpath, showWarnings = FALSE)

  # Crop TreeMap raster to variant boundary
  variant_poly <- variants_vect[variants_vect$FVSVariant == variant, ]
  tm.clip      <- crop(tm.ras,
                       variant_poly,
                       mask = TRUE)
  tm.clip.path <- file.path(outpath, paste0("tm_ref_", variant, ".tif"))
  writeRaster(tm.clip,
              tm.clip.path,
              overwrite = TRUE)
  rm(tm.clip)

  # Build reclass table from all FL databases for this variant
  variant_dbs <- all_dbs[str_detect(all_dbs, paste0("_", variant, "\\.db$"))]

  reclass.long <- map_dfr(variant_dbs, function(db_path) {
    fl_val <- parse_number(basename(db_path))
    con    <- dbConnect(SQLite(), db_path)
    dat    <- dbGetQuery(con, "SELECT StandID, Carbon_Released_From_Fire
                               FROM FVS_Carbon WHERE Year = 2020")
    dbDisconnect(con)
    mutate(dat, FL = fl_val, StandID = as.integer(StandID))
  })

  fl_levels   <- sort(unique(reclass.long$FL))
  fl_colnames <- paste0("FL", fl_levels)

  reclass.df <- reclass.long %>%
    pivot_wider(names_from   = FL,
                values_from  = Carbon_Released_From_Fire,
                names_prefix = "FL") %>%
    select(StandID, all_of(fl_colnames))

  # Reclassify raster for each FL bin in parallel
  process_var <- function(var) {
    reclass.mat <- reclass.df %>%
      select(from = StandID, to = all_of(var)) %>%
      as.matrix()

    out <- terra::classify(rast(tm.clip.path), reclass.mat, others = NA)
    names(out) <- var

    writeRaster(out, file.path(outpath, paste0(var, ".tif")), overwrite = TRUE)
    gc()
  }

  future::plan(future.callr::callr, workers = parallel::detectCores() - 2)
  furrr::future_map(fl_colnames, process_var)
  future::plan(sequential)

  # Stack FL emissions rasters (already in ascending FL order)
  emit_stack <- rast(file.path(outpath, paste0(fl_colnames, ".tif")))
  gc()

  # Load and crop FL probability rasters to this variant
  fl.rast <- rast(fl_prob_files) %>%
    crop(variant_poly,
         mask = TRUE)

  # Conditional expected emissions (probability-weighted mean across FL bins)
  cond.emit <- app(emit_stack * fl.rast, sum)

  # Conditional standard deviation
  sd.emit <- app(
    fl.rast * (emit_stack - cond.emit)^2,
    \(x) sqrt(sum(x, na.rm = TRUE))
  )

  # Coefficient of variation
  cv.emit <- sd.emit / cond.emit

  writeRaster(cond.emit,
              file.path(outpath, "Conditional_mean_CarbonReleasedFromFire.tif"),
              overwrite = TRUE)
  writeRaster(sd.emit,
              file.path(outpath, "Conditional_sd_CarbonReleasedFromFire.tif"),
              overwrite = TRUE)
  writeRaster(cv.emit,
              file.path(outpath, "Conditional_cv_CarbonReleasedFromFire.tif"),
              overwrite = TRUE)

  rm(reclass.long, reclass.df, emit_stack, fl.rast, cond.emit, sd.emit, cv.emit)
  gc()
  message("Variant ", variant, " complete.")
}
