## This script chunks up national emissions rasters, divides them, and exports them at the pyrome level, to be merged later

library(tidyverse)
library(terra)

rx_emit_list <- list.files("data/flamstat/by_pyrome/emissions/treatments/Rxfire/", full.names=T) %>%
  str_subset(".xml",negate = T)

nt_emit_list <- list.files("data/flamstat/by_pyrome/emissions/conditional/2020_baseline/", full.names=T) %>%
  str_subset(".xml",negate = T)

pyromes <- vect("../../SHARED_DATA/pyromes/Data/Pyromes_CONUS_20200206.shp") %>% project(crs("EPSG:5070"))

t_0 <- Sys.time()

chunk1 <- 1:(nrow(pyromes)/4)
chunk2 <- (max(chunk1)+1):(max(chunk1)*2)
chunk3 <- (max(chunk2)+1):(max(chunk1)*3)
chunk4 <- (max(chunk3)+1):nrow(pyromes)

for(i in chunk4){
  
  time_1 <- Sys.time()
  
  # filter to just pyrome in question
  pyrome <- pyromes[i,]
  
  # print out pyrome output
  print(paste(pyrome$PYROME, pyrome$NAME))
  
  # filter emissions to just the pyrome boundary
  py_rx <- rast(rx_emit_list %>% 
                  str_subset(paste0("_",pyrome$PYROME,".tif")))
  py_nt <- rast(nt_emit_list %>% 
                  str_subset(paste0("_",pyrome$PYROME,".tif")))
  
  gc()
  
  ## get difference from baseline to treated
  rx_nt_ratio <- py_rx/py_nt
  
  gc()
  
  # write out rasters
  writeRaster(rx_nt_ratio, 
              paste0("data/flamstat/by_pyrome/emissions/treatments/Rx_NT_ratio/rx_nt_ratio_pyrome_", 
                     pyrome$PYROME, ".tif"), overwrite = T)
  
  rm(rx_nt_ratio)
  rm(py_rx)
  rm(py_nt)
  
  time_2 <- Sys.time()
  
  print(time_2 - time_1)
}

print(paste0("Total time: ", Sys.time()- t_0))
