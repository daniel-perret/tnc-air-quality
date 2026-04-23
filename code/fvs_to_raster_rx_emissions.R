##### This script turns FVS Rx fire emissions outputs into raster layers based on TreeMap imputation

library(terra)
library(DBI)
library(RSQLite)
library(dplyr)
library(furrr)
library(future)
library(future.callr)

## ---- setup ----
setwd(here())

runName <- "RxWetRun_fuelmoisture3_22Apr26_1539"

tm_path   <- "data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif"

variant_path  <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVSVariantMap20210525/FVS_Variants_and_Locations.shp"

dbs <- list.files(paste0("FVS_runs/",runName,"/outputs/"), full.names = T)

outpath <- paste0("data/dp_FVS_postprocess/", runName)
dir.create(outpath)

## ---- load + clip TreeMap raster (just need path now) ----
# tm.ras   <- terra::rast(tm_path)
# variant <- vect(variant_path) %>%    # Here we're filtering to IE, but could parallelize over Variants as well
#   filter(FVSVariant == "IE") %>% 
#   terra::project(crs(tm.ras))
# tm.clip  <- crop(tm.ras, variant, mask = TRUE)
# activeCat(tm.clip) <- 8
# 
# writeRaster(tm.clip,
#             "data/dp_FVS_postprocess/DryRun_test_Cycle2_complete_20Apr26_1118/tm_ref_IE.tif")
# rm(tm.clip)

tm.path <- "data/dp_FVS_postprocess/DryRun_test_Cycle2_complete_20Apr26_1118/tm_ref_IE.tif"

## ---- db pull ONCE ----

rx <- extract_sqlite_tables(dbs[1])

reclass.df <- rx$FVS_Carbon %>% 
  filter(Year==2020) %>% 
  select(StandID,
         Rx_CarbonReleasedFromFire = Carbon_Released_From_Fire) %>% 
  left_join(rx$FVS_BurnReport %>% 
              select(StandID,
                     Rx_FlameLength = Flame_length)) %>% 
  mutate(across(where(is.character),as.numeric))

target_vars <- names(reclass.df)[-1]

## ---- reclass and write ----
process_var <- function(var) {
  
  reclass.mat <- reclass.df %>% 
    select(from = StandID,
           to = all_of(var)) %>% 
    as.matrix()
  
  tm.clip <- rast(tm.path)
  
  out <- terra::classify(tm.clip, reclass.mat, others = NA)
  names(out) <- var
  
  writeRaster(out,
              paste0(outpath,"/",var,".tif"),
              overwrite=T)
  
  gc()
}

## ---- parallel reclassification ----

future::plan(future.callr::callr, 
             workers = parallel::detectCores())

furrr::future_map(
  target_vars,
  process_var
)

## ---- get ratio/difference from wildfire ----

wf.cond <- rast("data/dp_FVS_postprocess/DryRun_test_Cycle2_complete_20Apr26_1118/emissions_rasters2/Conditional_mean_CarbonReleasedFromFire.tif")

rx.emit <- rast(paste0(outpath,"/Rx_CarbonReleasedFromFire.tif"))

ratio <- rx.emit/wf.cond

writeRaster(ratio,
            paste0(outpath,"/Rx_WF_ratio.tif"),
            overwrite=T)


