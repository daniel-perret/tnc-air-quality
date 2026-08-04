###############################################################################
#################  Mask Rasters to frequent-fire forests (FRG)  #############
###############################################################################

# Apply FRG masking to ratio and carbon rasters using LandFire FRG groups.
# We're using this as a first-pass filter; plan is maybe to eventually 
# implement the Landfire X TreeMap forest type filter that Mark started 
# working up. But want to think through whether that additional layer/wrinkle 
# really adds anything to the analysis, or if it just adds complexity and 
# processing time.


source("code/FVS_dp/cleaned_workflow/0.0_setup.R")

terraOptions(memfrac = 0.8,
             threads = 16,
             memmax = 56)

# Load rasters
ratio <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked.tif")
ratio_masked <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked_FRG.tif")
rx_carbon <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_CarbonReleasedFromFire.tif")
wf_carbon <- rast("data/dp_FVS_postprocess/CONUS_mosaic/WF_Conditional_mean_CarbonReleasedFromFire.tif")

frg <- rast("../../SHARED_DATA/LANDFIRE/LF2016_FRG_CONUS/LF2016_FRG_CONUS/Tif/LF2016_FRG_CONUS.tif")

frequent.fire.groups <- c("I-A", "I-B", "I-C", "II-A", "II-B", "II-C", "III-A")

# Extract the FRG categories and identify which cell values correspond to frequent-fire groups
frg_categories <- cats(frg) %>% as.data.frame()
keep_ids <- frg_categories %>%
  filter(FRG_NEW %in% frequent.fire.groups) %>%
  pull(Value)

# Crop FRG to match extent of ratio raster (reference)
frg <- crop(frg, ratio, mask = T)
rx_carbon_masked <- crop(rx_carbon, ratio_masked, mask=T)
wf_carbon_masked <- crop(wf_carbon, ratio_masked, mask=T)

# Create masking raster once (reuse for all)
frg_mask_raster <- classify(frg, cbind(keep_ids, 1), others = NA)

# Apply mask to ratio raster
ratio_masked <- mask(ratio, frg_mask_raster)
terra::writeRaster(ratio_masked, "data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked_FRG.tif", overwrite = TRUE)

# Apply mask to Rx carbon raster
rx_carbon_masked <- mask(rx_carbon, frg_mask_raster)
terra::writeRaster(rx_carbon_masked, "data/dp_FVS_postprocess/CONUS_mosaic/Rx_CarbonReleasedFromFire_FRG_masked.tif", overwrite = TRUE)

# Apply mask to WF conditional mean carbon raster
wf_carbon_masked <- mask(wf_carbon, frg_mask_raster)
terra::writeRaster(wf_carbon_masked, "data/dp_FVS_postprocess/CONUS_mosaic/WF_Conditional_mean_CarbonReleasedFromFire_FRG_masked.tif", overwrite = TRUE)
