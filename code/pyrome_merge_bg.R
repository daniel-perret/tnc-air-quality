library(tidyverse)
library(terra)


ce_baseline_list <- list.files("data/flamstat/by_pyrome/emissions/conditional/2020_baseline/", full.names=T) %>%
  str_subset(".xml",negate = T)
ce_baseline <- sprc(ce_baseline_list) %>% merge()
writeRaster(ce_baseline, "data/flamstat/emissions_rasters/dp_merged/2020_cond_baseline_conus.tif", overwrite=T)
gc()
rm(ce_baseline)