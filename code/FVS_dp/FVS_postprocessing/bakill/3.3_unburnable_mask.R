#### 3.3_unburnable_mask.R
#### Masks the merged Rx:WF Bakill / PctBAkill ratio rasters. Pixels are set to NA if
#### they are unburnable (WF mean conditional emissions == 0, the same mask used for the
#### emissions ratio so all ratios share the same valid pixels) or if the ratio is
#### non-finite (WF value == 0 gives Inf/NaN).
#### Requires completed 3.2 run (mosaicked Bakill rasters) and the emissions 3.2 mosaic.
#### Outputs: *_masked.tif versions of each ratio raster in data/dp_FVS_postprocess/CONUS_mosaic/

source("code/FVS_dp/FVS_workflow/0.0_setup.R")

## ---- Configuration ----

setwd(here())

# Path to mosaicked rasters directory
mosaic_outpath <- here("data/dp_FVS_postprocess", "CONUS_mosaic")

metrics <- c("BAkill", "PctBAkill")

# Ratio rasters to mask
ratio_layers <- c(paste0("Rx_WF_", metrics, "_ratio"),
                  paste0("Rx_WF_", metrics, "_ratio_90p"))


## ---- Setup ----

message("Loading mosaicked rasters...")

# Emissions layer defines unburnable pixels
wf_emissions_mean <- rast(file.path(mosaic_outpath,
                                    "WF_Conditional_mean_CarbonReleasedFromFire.tif"))

wf_mask <- wf_emissions_mean == 0


## ---- Mask ratios ----

for (layer in ratio_layers) {

  message("Masking: ", layer)

  ratio <- rast(file.path(mosaic_outpath, paste0(layer, ".tif")))

  # Unburnable pixels -> NA
  ratio_burnable <- terra::mask(ratio, wf_mask, maskvalue = 1, updatevalue = NA)

  # Non-finite ratios -> NA
  ratio_masked <- terra::ifel(is.finite(ratio_burnable), ratio_burnable, NA)

  out_path <- file.path(mosaic_outpath, paste0(layer, "_masked.tif"))
  writeRaster(ratio_masked, out_path, overwrite = TRUE)

  n_total    <- terra::global(ratio, "notNA")[1, 1]
  n_burnable <- terra::global(ratio_burnable, "notNA")[1, 1]
  n_final    <- terra::global(ratio_masked, "notNA")[1, 1]

  message("  Total pixels: ", format(n_total, big.mark = ","))
  message("  Masked as unburnable (WF emissions == 0): ",
          format(n_total - n_burnable, big.mark = ","))
  message("  Masked as non-finite ratio: ", format(n_burnable - n_final, big.mark = ","))
  message("  Remaining valid pixels: ", format(n_final, big.mark = ","))
  message("  Output: ", out_path)

  rm(ratio, ratio_burnable, ratio_masked)
  gc()
}
