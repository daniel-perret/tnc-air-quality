## This script chunks up national emissions rasters, divides them, and exports them at the pyrome level, to be merged later

library(tidyverse)
library(terra)

fvs.info <- rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif")

reclass.mat <- read.csv("data/troubleshooting/rx_consumption_table.csv",
                          header=T,stringsAsFactors=F) %>% 
  select(StandID,NonCanopy_Carbon) %>% 
  data.matrix()

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
  
  # crop StandIDs
  
  py_fvs <- fvs.info %>% crop(pyrome, mask=T)
  gc()
  
  # reclassify
  py_rx <- py_fvs %>% 
    classify(., rcl = reclass.mat)
  gc()
  rm(py_fvs)
  
  #save new raster
  writeRaster(py_rx, 
              paste0("data/flamstat/by_pyrome/emissions/treatments/Rxfire_Noncanopy/Rx_treat_nocan_pyrome", 
                     pyrome$PYROME, ".tif"), overwrite = T)
  
  # load up NT emissions
  py_nt <- rast(nt_emit_list %>% 
                  str_subset(paste0("_",pyrome$PYROME,".tif")))
  
  gc()
  
  ## get ratio of treated to baseline
  rx_nt_ratio <- py_rx/py_nt
  
  gc()
  
  # write out rasters
  writeRaster(rx_nt_ratio, 
              paste0("data/flamstat/by_pyrome/emissions/treatments/RxNocan_NT_ratio/rxNocan_nt_ratio_pyrome_", 
                     pyrome$PYROME, ".tif"), overwrite = T)
  
  rm(rx_nt_ratio)
  rm(py_rx)
  rm(py_nt)
  
  time_2 <- Sys.time()
  
  print(time_2 - time_1)
}

print(paste0("Total time: ", Sys.time()- t_0))
