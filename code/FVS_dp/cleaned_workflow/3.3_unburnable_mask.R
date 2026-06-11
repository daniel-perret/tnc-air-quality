#### 3.3_unburnable_mask.R
#### Masks the merged Rx:WF ratio raster by setting pixels with WF mean
#### conditional emissions of 0 to NA (unburnable pixels).
#### Requires completed 3.2 run (mosaicked rasters).
#### Outputs: masked Rx_WF_ratio.tif in data/dp_FVS_postprocess/CONUS_mosaic/

source("code/FVS_dp/cleaned_workflow/0.0_setup.R")

## ---- Configuration ----

setwd(here())

# Path to mosaicked rasters directory
mosaic_outpath <- here("data/dp_FVS_postprocess", "CONUS_mosaic")


## ---- Setup ----

# Load mosaicked rasters
message("Loading mosaicked rasters...")

wf_conditional_mean <- rast(file.path(mosaic_outpath, 
                                       "WF_Conditional_mean_CarbonReleasedFromFire.tif"))
rx_wf_ratio <- rast(file.path(mosaic_outpath, 
                               "Rx_WF_ratio.tif"))


## ---- Mask Rx:WF ratio by WF unburnable pixels ----

message("Masking Rx:WF ratio raster...")

# Set pixels with WF mean conditional emissions == 0 to NA
wf_mask <- wf_conditional_mean == 0

# Apply mask to Rx:WF ratio raster
rx_wf_ratio_masked <- terra::mask(rx_wf_ratio, wf_mask, maskvalue = 1, updatevalue = NA)

# Write masked raster
writeRaster(rx_wf_ratio_masked,
            file.path(mosaic_outpath, "Rx_WF_ratio_masked.tif"),
            overwrite = TRUE)

message("Masking complete. Output: ", file.path(mosaic_outpath, "Rx_WF_ratio_masked.tif"))

# Summary stats
n_pixels_total <- terra::global(rx_wf_ratio, "notNA")[1, 1]
n_pixels_masked <- terra::global(rx_wf_ratio_masked, "notNA")[1, 1]
n_pixels_na <- n_pixels_total - n_pixels_masked

message("Summary:")
message("  Total pixels in Rx:WF ratio raster: ", format(n_pixels_total, big.mark = ","))
message("  Pixels masked to NA (unburnable): ", format(n_pixels_na, big.mark = ","))
message("  Remaining valid pixels: ", format(n_pixels_masked, big.mark = ","))


