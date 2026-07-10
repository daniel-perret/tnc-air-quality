##### This script digs into some CONUS-wide fire emissions data products, and
##### pulls out standIDs and associated information for pixels with T>1. The 
##### goal is to get a sense of what problems are remaining and whether 
##### there are any other fixes I need to explore.

source("code/FVS_dp/cleaned_workflow/0.0_setup.R")

t.rast <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked.tif")

gt1.mask <- t.rast > 1.001

## apply mask to TMLF raster, get values, and pull from key data.frame

tmlf.rast <- rast("data/tmlf_keys/tmlf_key_conus_64bit.tif") %>% 
  terra::crop(., ext(gt1.mask))

gt1.keys <- terra::mask(tmlf.rast, gt1.mask, inverse = T, maskvalue = 1, updatevalue = NA) 

gt1.key.values <- freq(gt1.keys)

tmlf.keys <- read.csv("data/tmlf_keys/tmlf_key_conus_64bit.csv", header = T, stringsAsFactors = F) %>% 
  filter(real.key %in% gt1.key.values$value)

#### DB digging -----

rx_run_name <- "RxWetRun_03Jun26_2229"
all_dbs <- list.files(here("FVS_runs/full", rx_run_name, "outputs"), full.names = TRUE)
wf_run_name <- "Wildfire_WetRun_21May26_0855"
wf_dbs <- list.files(here("FVS_runs/full", wf_run_name, "outputs"), full.names = TRUE)


rx_dbs <- map_df(all_dbs, ~{
  db <- DBI::dbConnect(RSQLite::SQLite(), .x)
  on.exit(DBI::dbDisconnect(db))
  
  dbReadTable(db, "FVS_Compute") %>% 
    filter(Year == 2020)
})

rx_dbs <- rx_dbs %>% 
  filter(StandID %in% tmlf.keys$real.key)

rx_br <- map_df(all_dbs, ~{
  db <- DBI::dbConnect(RSQLite::SQLite(), .x)
  on.exit(DBI::dbDisconnect(db))
  
  dbReadTable(db, "FVS_BurnReport") %>% 
    filter(Year == 2020)
})

rx_br <- rx_br %>% 
  filter(StandID %in% tmlf.keys$real.key)

rx_con <- map_df(all_dbs, ~{
  db <- DBI::dbConnect(RSQLite::SQLite(), .x)
  on.exit(DBI::dbDisconnect(db))
  
  dbReadTable(db, "FVS_Consumption") %>% 
    filter(Year == 2020)
})

rx_con <- rx_con %>% 
  filter(StandID %in% tmlf.keys$real.key)


rx_case <- map_df(all_dbs, ~{
  db <- DBI::dbConnect(RSQLite::SQLite(), .x)
  on.exit(DBI::dbDisconnect(db))
  
  dbReadTable(db, "FVS_Cases")
})

rx_case <- rx_case %>% 
  filter(StandID %in% tmlf.keys$real.key)


wf_br <- map_df(wf_dbs, ~{
  db <- DBI::dbConnect(RSQLite::SQLite(), .x)
  on.exit(DBI::dbDisconnect(db))
  
  dbReadTable(db, "FVS_BurnReport")
})

wf_br <- wf_br %>% 
  filter(StandID %in% tmlf.keys$tm)

wf_con <- map_df(wf_dbs, ~{
  db <- DBI::dbConnect(RSQLite::SQLite(), .x)
  on.exit(DBI::dbDisconnect(db))
  
  dbReadTable(db, "FVS_Consumption")
})

wf_con <- wf_con %>% 
  filter(StandID %in% tmlf.keys$tm) %>% 
  slice(1:length(unique(tmlf.keys$tm)))





#### checking distribution of conditional FL probs in those areas ----

cfl <- rast("data/flamstat/flamelength_rasters/PreTreatment_CONUS/CONUS_PreT_ConditionalFL.tif")

cfl.masked <- terra::mask(cfl, gt1.mask, inverse = T, maskvalue = 1, updatevalue = NA)

# cfl.vals <- terra::values(cfl.masked, na.rm=T, data.frame = T)
# 
# cfl.freq <- freq(cfl)

rx.cfl <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_FlameLength.tif") %>% 
  terra::crop(., ext(gt1.mask))
rx.cfl.masked <- terra::mask(rx.cfl, gt1.mask, inverse = T, maskvalue = 1, updatevalue = NA)

plot(cfl.masked, rx.cfl.masked, maxcell = 3e6)
abline(0,1,col = "red")

slp <- rast("../../SHARED_DATA/LANDFIRE/LF2020_SlpD_CONUS/LF2020_SlpD_CONUS/Tif/LF2020_SlpD_CONUS.tif") %>% 
  terra::crop(., ext(gt1.mask))
slp.masked <- terra::mask(slp, gt1.mask, inverse = T, maskvalue = 1, updatevalue = NA)
slp.antimasked <- terra::mask(slp, gt1.mask, inverse = F, maskvalue = 1, updatevalue = NA)








dry_dbs <- list.files(here("FVS_runs/full", "RxDryRun_02Jun26_2233", "outputs"), full.names = TRUE)

rxdry_br <- map_df(dry_dbs, ~{
  db <- DBI::dbConnect(RSQLite::SQLite(), .x)
  on.exit(DBI::dbDisconnect(db))
  
  dbReadTable(db, "FVS_BurnReport")})

View(rxdry_br %>% filter(StandID %in% tf))

     