# ------------------------------------------------------------
# ArcGIS Pro "Combine"-equivalent using terra
# Final raster values are dense IDs: 1:n(combinations)
# tm = band 1, lf = band 2
# ------------------------------------------------------------

library(tidyverse)
library(terra)

# Read rasters
tm <- rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif")
lf <- rast("../../SHARED_DATA/LANDFIRE/LF2022_FBFM40_220_CONUS/Tif/LC22_F40_220.tif") %>% 
  crop(.,tm)

activeCat(tm) <- 8
activeCat(lf) <- 0

# Geometry check
stopifnot(compareGeom(tm, lf, stopOnError = T))

# ------------------------------------------------------------
# Encode (tm, lf) using numeric key: max(lf)+1
# ------------------------------------------------------------
mult <- cats(lf) %>% 
  as.data.frame() %>% 
  pull(Value) %>% 
  max() + 1

terraOptions(datatype = "INT4S")
key  <- tm * mult + lf
names(key) <- "combo_key"

# ------------------------------------------------------------
# Extract unique observed combinations, reverse encoding, and assign key value
# ------------------------------------------------------------
keys <- freq(key) %>%
  select(comp.key = value) %>% 
  mutate(tm = comp.key %/% mult,
         lf = comp.key %% mult,
         real.key = row_number())

# ------------------------------------------------------------
# Reclassify encoded raster to key
# ------------------------------------------------------------
rcl <- keys %>%
  select(comp.key, real.key) %>%
  as.matrix()

combine_raster <- classify(
  key,
  rcl = rcl,
  others = NA,
  filename = "data/tmlf_keys/tmlf_key_conus_64bit.tif",
  overwrite = TRUE
)

write.table(keys, 
            file = "data/tmlf_keys/tmlf_key_conus_64bit.csv",
            sep = ",",
            row.names = F)

terraOptions(datatype = "FLT4S")

# Outputs:
# - combine_raster: integer raster with values 1:n(combinations)
# - combo_tbl: mapping combo_id -> (tm, lf)
# ------------------------------------------------------------