library(tidyverse)
library(terra)

rx_emit <- rast("data/flamstat/emissions_rasters/Rx_treatment_emissions.tif")

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
  py_rx <- rx_emit %>% crop(pyrome, mask = T)
  py_nt <- rast(nt_emit_list %>% 
                  str_subset(paste0("_",pyrome$PYROME,".tif")))

  gc()

  writeRaster(py_rx,
              paste0("data/flamstat/by_pyrome/emissions/treatments/Rxfire/Rx_treat_pyrome_",
                     pyrome$PYROME,".tif"), overwrite=T)
  
  ## get difference from baseline to treated
  rx_nt_diff <- py_rx - py_nt
  
  gc()
  
  # write out rasters
  writeRaster(rx_nt_diff, 
              paste0("data/flamstat/by_pyrome/emissions/treatments/Rx_NT_difference/rx_nt_diff_pyrome_", 
                     pyrome$PYROME, ".tif"), overwrite = T)
 
  rm(rx_nt_diff)
  rm(py_rx)
  rm(py_nt)
  
  time_2 <- Sys.time()
  
  print(time_2 - time_1)
}

print(paste0("Total time: ", Sys.time()- t_0))
