###############################################################################
#################  Mask Ratio pixels to frequent-fire forests #################
###############################################################################

# We're going to accomplish this just using LandFire FRG groups as a first pass
# filter; plan is maybe to eventually implement the Landfire X TreeMap forest 
# type filter that Mark started working up. But want to think through whether
# that additional layer/wrinkle really adds anything to the analysis, or if it 
# just adds complexity and processing time.


source("code/FVS_dp/cleaned_workflow/0.0_setup.R")

terraOptions(memfrac = 0.8,
             threads = 16,
             memmax = 56)

ratio <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked.tif")

frg <- rast("../../SHARED_DATA/LANDFIRE/LF2016_FRG_CONUS/LF2016_FRG_CONUS/Tif/LF2016_FRG_CONUS.tif")

frequent.fire.groups <- c("I-A", "I-B", "I-C", "II-A", "II-B", "II-C", "III-A")

# Extract the FRG categories and identify which cell values correspond to frequent-fire groups
frg_categories <- cats(frg) %>% as.data.frame()
keep_ids <- frg_categories %>%
  filter(FRG_NEW %in% frequent.fire.groups) %>%
  pull(Value)

# # Create a mask where frequent-fire pixels are TRUE, all others are NA
# frg_mask <- frg %in% keep_ids

frg <- crop(frg, ratio, mask = T)

# Apply mask to ratio raster
ratio_masked <- mask(ratio, classify(frg, cbind(keep_ids, 1), others = NA))

terra::writeRaster(ratio_masked, "data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked_FRG.tif")
