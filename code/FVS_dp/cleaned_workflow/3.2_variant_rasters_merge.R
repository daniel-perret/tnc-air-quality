#### 3.2_variant_rasters_merge.R
#### Mosaics per-variant rasters from wildfire and prescribed fire post-processing
#### into CONUS-wide layers. Requires completed 3.0 and 3.1 runs.
#### Outputs: CONUS-wide rasters in data/dp_FVS_postprocess/{CONUS_mosaic}/


## ---- Configuration ----

# Completed post-processing runs to mosaic
wf_run_name <- "Wildfire_WetRun_21May26_0855"
rx_run_name <- "RxWetRun_XXXX"


## ---- Setup ----

wf_outpath_root <- here("data/dp_FVS_postprocess", wf_run_name)
rx_outpath_root <- here("data/dp_FVS_postprocess", rx_run_name)

mosaic_outpath <- here("data/dp_FVS_postprocess", "CONUS_mosaic")
dir.create(mosaic_outpath, showWarnings = FALSE)

# Identify variants in WF outputs
wf_variants <- list.dirs(wf_outpath_root, full.names = FALSE, recursive = FALSE)

# Identify variants in Rx outputs
rx_variants <- list.dirs(rx_outpath_root, full.names = FALSE, recursive = FALSE)

# WF output layers to mosaic
wf_layers <- c("Conditional_mean_CarbonReleasedFromFire.tif",
               "Conditional_sd_CarbonReleasedFromFire.tif",
               "Conditional_cv_CarbonReleasedFromFire.tif")

# Rx output layers to mosaic
rx_layers <- c("Rx_CarbonReleasedFromFire.tif",
               "Rx_FlameLength.tif",
               "Rx_WF_ratio.tif")


## ---- Mosaic wildfire layers ----

message("Mosaicking wildfire layers...")

for (layer in wf_layers) {
  
  message("  Processing: ", layer)
  
  # Load all variant rasters for this layer
  variant_rasters <- map(wf_variants, ~ {
    rast(file.path(wf_outpath_root, .x, layer))
  })
  
  # Mosaic via terra::merge()
  mosaic <- do.call(terra::merge, variant_rasters)
  
  # Write mosaicked layer
  writeRaster(mosaic,
              file.path(mosaic_outpath, paste0("WF_", layer)),
              overwrite = TRUE)
  
  rm(variant_rasters, mosaic)
  gc()
}


## ---- Mosaic prescribed fire layers ----

message("Mosaicking prescribed fire layers...")

for (layer in rx_layers) {
  
  message("  Processing: ", layer)
  
  # Load all variant rasters for this layer
  variant_rasters <- map(rx_variants, ~ {
    rast(file.path(rx_outpath_root, .x, layer))
  })
  
  # Mosaic via terra::merge()
  mosaic <- do.call(terra::merge, variant_rasters)
  
  # Write mosaicked layer
  writeRaster(mosaic,
              file.path(mosaic_outpath, paste0("Rx_", layer)),
              overwrite = TRUE)
  
  rm(variant_rasters, mosaic)
  gc()
}

message("Mosaicking complete. Output directory: ", mosaic_outpath)
