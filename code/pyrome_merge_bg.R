library(tidyverse)
library(terra)


merge_list <- list.files("data/flamstat/by_pyrome/emissions/treatments/Rx_NT_ratio/", full.names=T) %>%
  str_subset(".xml",negate = T)

merged <- sprc(merge_list) %>% merge()

writeRaster(merged, "data/flamstat/emissions_rasters/dp_merged/Rx_baseline_2020_ratio.tif", overwrite=T)

gc()

rm(merged)