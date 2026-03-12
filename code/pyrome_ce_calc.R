library(tidyverse)
library(terra)

nt_fl <- list.files("data/flamstat/flamelength_rasters/PreTreatment_CONUS/",full.names = T) %>% 
  str_subset("Conditional",negate = T) %>% 
  str_subset(".tif.",negate = T) %>% 
  str_subset(".tfw",negate = T) %>%  
  str_subset("NoBurn",negate=T) %>% 
  .[c(1,3,4,5,6,2)] %>% 
  rast()

nt_emit <- rast("data/flamstat/emissions_rasters/TMFM2020_Carbon_Emissions/TMFM2020_Carbon_Emissions.tif")[[1:6]]

pyromes <- vect("../../SHARED_DATA/pyromes/Data/Pyromes_CONUS_20200206.shp") %>% project(crs("EPSG:5070"))

i <- 1

t_0 <- Sys.time()

chunk1 <- 1:(nrow(pyromes)/4)
chunk2 <- (max(chunk1)+1):(max(chunk1)*2)
chunk3 <- (max(chunk2)+1):(max(chunk1)*3)
chunk4 <- (max(chunk3)+1):nrow(pyromes)


for(i in 25:32){
  time_1 <- Sys.time()
  
  # filter to just pyrome in question
  pyrome <- pyromes[i,]
  
  # print out pyrome output
  print(paste(pyrome$PYROME, pyrome$NAME))
  
  # filter emissions to just the pyrome boundary
  py_fl <- nt_fl %>% crop(pyrome, mask = T)
  
  py_emit <- nt_emit %>% crop(pyrome, mask=T)
  
  gc()
  
  ## get difference from baseline to treated ##
  py_ce <- sum(py_fl*py_emit)
  names(py_ce) <- "CondEmis"
  
  gc()
  
  # write out rasters
  writeRaster(py_ce, 
              paste0("data/flamstat/by_pyrome/emissions/conditional/2020_baseline/ce_pyrome_", 
                     pyrome$PYROME, ".tif"), overwrite = T)
  
  rm(py_ce)
  rm(py_fl)
  rm(py_emit)
  gc()
  
  time_2 <- Sys.time()
  
  print(time_2 - time_1)
}

print(paste0("Total time: ", Sys.time()- t_0))
