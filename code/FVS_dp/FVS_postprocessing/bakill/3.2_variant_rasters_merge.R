#### 3.2_variant_rasters_merge.R
#### Mosaics per-variant Bakill / PctBAkill rasters from wildfire and prescribed fire
#### post-processing into CONUS-wide layers.
#### Requires completed 3.0, 3.0.1, 3.0.2 and 3.1 (bakill) runs.
#### Outputs: CONUS-wide rasters in data/dp_FVS_postprocess/CONUS_mosaic/
#### (same directory as emissions mosaics; Bakill layer names are distinct)

library(here)
source(here("code/FVS_dp/FVS_workflow/0.0_setup.R"))


## ---- Configuration ----

# Completed post-processing runs to mosaic
wf_run_name <- "Wildfire_WetRun_21May26_0855"
rx_run_name <- "RxWetRun_03Jun26_2229"

# 90th / 10th percentile runs
wf_run_name_90p <- paste0(wf_run_name, "_90p")
wf_run_name_10p <- paste0(wf_run_name, "_10p")

metrics   <- c("BAkill", "PctBAkill")
fl_levels <- c(1, 3, 5, 7, 10, 20)


## ---- Setup ----

wf_outpath_root     <- here("data/dp_FVS_postprocess", wf_run_name)
wf_outpath_root_90p <- here("data/dp_FVS_postprocess", wf_run_name_90p)
wf_outpath_root_10p <- here("data/dp_FVS_postprocess", wf_run_name_10p)
rx_outpath_root     <- here("data/dp_FVS_postprocess", rx_run_name)

mosaic_outpath <- here("data/dp_FVS_postprocess", "CONUS_mosaic")
dir.create(mosaic_outpath, showWarnings = FALSE)

# Variants in each output set
wf_variants     <- list.dirs(wf_outpath_root, full.names = FALSE, recursive = FALSE)
wf_variants_90p <- list.dirs(wf_outpath_root_90p, full.names = FALSE, recursive = FALSE)
wf_variants_10p <- list.dirs(wf_outpath_root_10p, full.names = FALSE, recursive = FALSE)
rx_variants     <- list.dirs(rx_outpath_root, full.names = FALSE, recursive = FALSE)

# Layers to mosaic (file name in the variant folder)
wf_layers     <- c(paste0("Conditional_mean_", metrics, ".tif"),
                   paste0("Conditional_sd_", metrics, ".tif"),
                   paste0("Conditional_cv_", metrics, ".tif"))
wf_layers_90p <- paste0("top10pct_mean_", metrics, ".tif")
wf_layers_10p <- paste0("bottom10pct_mean_", metrics, ".tif")
rx_layers     <- c(paste0("Rx_", metrics, ".tif"),
                   paste0("Rx_WF_", metrics, "_ratio.tif"),
                   paste0("Rx_WF_", metrics, "_ratio_90p.tif"))
wf_fl_layers  <- paste0(rep(metrics, each = length(fl_levels)), "_FL", fl_levels, ".tif")


## ---- Mosaic function ----

# Variants are non-overlapping, so terra::merge() is sufficient
mosaic_layer <- function(layer, variants, root, out_name) {

  message("  Processing: ", layer)

  variant_rasters <- map(variants, ~ rast(file.path(root, .x, layer)))
  mosaic <- do.call(terra::merge, variant_rasters)

  writeRaster(mosaic,
              file.path(mosaic_outpath, out_name),
              overwrite = TRUE)

  rm(variant_rasters, mosaic)
  gc()
}


## ---- Mosaic wildfire layers ----

message("Mosaicking wildfire layers...")
for (layer in wf_layers) {
  mosaic_layer(layer, wf_variants, wf_outpath_root, paste0("WF_", layer))
}

message("Mosaicking wildfire 90p layers...")
for (layer in wf_layers_90p) {
  mosaic_layer(layer, wf_variants_90p, wf_outpath_root_90p, paste0("WF_90p_", layer))
}

message("Mosaicking wildfire 10p layers...")
for (layer in wf_layers_10p) {
  mosaic_layer(layer, wf_variants_10p, wf_outpath_root_10p, paste0("WF_10p_", layer))
}


## ---- Mosaic prescribed fire layers ----

message("Mosaicking prescribed fire layers...")
for (layer in rx_layers) {
  mosaic_layer(layer, rx_variants, rx_outpath_root, layer)
}


## ---- Mosaic wildfire FL layers ----

message("Mosaicking wildfire FL layers...")
for (layer in wf_fl_layers) {
  mosaic_layer(layer, wf_variants, wf_outpath_root, paste0("WF_", layer))
}

message("Bakill mosaicking complete. Output directory: ", mosaic_outpath)
