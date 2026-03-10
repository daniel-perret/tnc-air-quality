# Run as background job?

library(tidyverse)
library(terra)

# Conditional emissions

ce_baseline_list <- list.files("data/flamstat/by_pyrome/emissions/conditional/baseline/", full.names=T) %>%
  str_subset(".xml",negate = T)
ce_baseline <- sprc(ce_baseline_list) %>% merge()
writeRaster(ce_baseline, "data/flamstat/emissions_rasters/dp_merged/conditional_baseline_conus.tif", overwrite=T)
gc()
rm(ce_baseline)

ce_Rx_fire_list <- list.files("data/flamstat/by_pyrome/emissions/conditional/Rx_fire/", full.names=T) %>%
  str_subset(".xml",negate = T)
ce_Rx_fire <- sprc(ce_Rx_fire_list) %>% merge()
writeRaster(ce_Rx_fire, "data/flamstat/emissions_rasters/dp_merged/conditional_Rx_fire_conus.tif", overwrite=T)
gc()
rm(ce_Rx_fire)

ce_Tx_fire_list <- list.files("data/flamstat/by_pyrome/emissions/conditional/Tx_fire/", full.names=T) %>%
  str_subset(".xml",negate = T)
ce_Tx_fire <- sprc(ce_Tx_fire_list) %>% merge()
writeRaster(ce_Tx_fire, "data/flamstat/emissions_rasters/dp_merged/conditional_Tx_fire_conus.tif", overwrite=T)
gc()
rm(ce_Tx_fire)

ce_Rx_diff_list <- list.files("data/flamstat/by_pyrome/emissions/conditional/differences/", full.names=T) %>%
  str_subset("Rx") %>% 
  str_subset(".xml",negate = T)
ce_Rx_diff <- sprc(ce_Tx_fire_list) %>% merge()
writeRaster(ce_Tx_diff, "data/flamstat/emissions_rasters/dp_merged/conditional_Rx_fire_diff_conus.tif", overwrite=T)
gc()
rm(ce_Rx_diff)

ce_Tx_diff_list <- list.files("data/flamstat/by_pyrome/emissions/conditional/differences/", full.names=T) %>%
  str_subset("Tx") %>% 
  str_subset(".xml",negate = T)
ce_Tx_diff <- sprc(ce_Tx_fire_list) %>% merge()
writeRaster(ce_Tx_diff, "data/flamstat/emissions_rasters/dp_merged/conditional_Tx_fire_diff_conus.tif", overwrite=T)
gc()
rm(ce_Tx_diff)


# Expected emissions

exp_baseline_list <- list.files("data/flamstat/by_pyrome/emissions/expected/baseline/", full.names=T) %>%
  str_subset(".xml",negate = T)
exp_baseline <- sprc(exp_baseline_list) %>% merge()
writeRaster(exp_baseline, "data/flamstat/emissions_rasters/dp_merged/expected_baseline_conus.tif", overwrite=T)
gc()
rm(exp_baseline)

exp_Rx_fire_list <- list.files("data/flamstat/by_pyrome/emissions/expected/Rx_fire/", full.names=T) %>%
  str_subset(".xml",negate = T)
exp_Rx_fire <- sprc(exp_Rx_fire_list) %>% merge()
writeRaster(expexp_Rx_fire, "data/flamstat/emissions_rasters/dp_merged/expected_Rx_fire_conus.tif", overwrite=T)
gc()
rm(exp_Rx_fire)

exp_Tx_fire_list <- list.files("data/flamstat/by_pyrome/emissions/expected/Tx_fire/", full.names=T) %>%
  str_subset(".xml",negate = T)
exp_Tx_fire <- sprc(exp_Tx_fire_list) %>% merge()
writeRaster(exp_Tx_fire, "data/flamstat/emissions_rasters/dp_merged/expected_Tx_fire_conus.tif", overwrite=T)
gc()
rm(exp_Tx_fire)

exp_Rx_diff_list <- list.files("data/flamstat/by_pyrome/emissions/expected/differences/", full.names=T) %>%
  str_subset("Rx") %>% 
  str_subset(".xml",negate = T)
exp_Rx_diff <- sprc(exp_Tx_fire_list) %>% merge()
writeRaster(exp_Tx_diff, "data/flamstat/emissions_rasters/dp_merged/expected_Rx_fire_diff_conus.tif", overwrite=T)
gc()
rm(exp_Rx_diff)

exp_Tx_diff_list <- list.files("data/flamstat/by_pyrome/emissions/expected/differences/Tx*", full.names=T) %>%
  str_subset("Tx") %>% 
  str_subset(".xml",negate = T)
exp_Tx_diff <- sprc(exp_Tx_fire_list) %>% merge()
writeRaster(exp_Tx_diff, "data/flamstat/emissions_rasters/dp_merged/expected_Tx_fire_diff_conus.tif", overwrite=T)
gc()
rm(exp_Tx_diff)