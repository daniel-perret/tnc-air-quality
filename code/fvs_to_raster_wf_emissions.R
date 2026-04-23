##### This script turns FVS wildfire emissions outputs into raster layers based on TreeMap imputation, and combines then with existing flame length probabilities to generate conditional expected emissions layers


library(terra)
library(DBI)
library(RSQLite)
library(dplyr)
library(furrr)
library(future)
library(future.callr)

## ---- setup ----

tm_path   <- "data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif"

run_name <- "DryRun_test_Cycle2_complete_20Apr26_1118"

variant_path  <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVSVariantMap20210525/FVS_Variants_and_Locations.shp"

dbs <- list.files(paste0("FVS_runs/", run_name, "/outputs/"), full.names = T)

outpath <- paste0("data/dp_FVS_postprocess/", run_name, "/emissions_rasters2/")
dir.create(outpath)

## ---- load + clip ONCE (step 1) ----
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

fl1 <- extract_sqlite_tables(dbs[1])
fl10 <- extract_sqlite_tables(dbs[2])
fl20 <- extract_sqlite_tables(dbs[3])
fl3 <- extract_sqlite_tables(dbs[4])
fl5 <- extract_sqlite_tables(dbs[5])
fl7 <- extract_sqlite_tables(dbs[6])

reclass.df <- fl1$FVS_Carbon %>% 
  filter(Year==2020) %>% 
  select(StandID,
         FL1_CarbonReleasedFromFire = Carbon_Released_From_Fire) %>% 
  left_join(fl10$FVS_Carbon %>% 
              filter(Year==2020) %>% 
              select(StandID,
                     FL10_CarbonReleasedFromFire = Carbon_Released_From_Fire)) %>% 
  left_join(fl20$FVS_Carbon %>% 
              filter(Year==2020) %>% 
              select(StandID,
                     FL20_CarbonReleasedFromFire = Carbon_Released_From_Fire)) %>% 
  left_join(fl3$FVS_Carbon %>% 
              filter(Year==2020) %>% 
              select(StandID,
                     FL3_CarbonReleasedFromFire = Carbon_Released_From_Fire)) %>% 
  left_join(fl5$FVS_Carbon %>% 
              filter(Year==2020) %>% 
              select(StandID,
                     FL5_CarbonReleasedFromFire = Carbon_Released_From_Fire)) %>% 
  left_join(fl7$FVS_Carbon %>% 
              filter(Year==2020) %>% 
              select(StandID,
                     FL7_CarbonReleasedFromFire = Carbon_Released_From_Fire)) %>% 
  mutate(across(where(is.character), as.numeric))

target_vars <- names(reclass.df)[c(2,5,6,7,3,4)] # put FLs in ascending order

## ---- reclass function ----
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

## ---- stackindividual FL emissions rasters ----

out_list <- list.files(outpath, full.names=T) %>% 
  str_subset("cv",negate=T) %>% 
  str_subset("sd",negate=T) %>% 
  str_subset("mean",negate=T) %>% 
  str_subset("Rx",negate=T) %>% 
  str_subset(".xml",negate=T) %>% 
  .[c(1,4,5,6,2,3)]
emit_stack <- rast(out_list)

gc()

## ---- actuarial calculations ----

fl.rast <- list.files("data/flamstat/flamelength_rasters/PreTreatment_CONUS/",full.names = T) %>% 
  str_subset("Conditional",negate = T) %>% 
  str_subset(".tif.",negate = T) %>% 
  str_subset(".tfw",negate = T) %>%  
  str_subset("NoBurn",negate=T) %>% 
  .[c(1,3,4,5,6,2)] %>%           # make sure order matches emissions raster stack!
  rast() %>% 
  crop(variant, mask = T)

cond.emit <- app(emit_stack*fl.rast, sum)

sd.emit <- app(
  fl.rast * ((emit_stack - cond.emit)^2),
  \(x) sqrt(sum(x, na.rm = TRUE))
)

cv.emit <- sd.emit/cond.emit


## ---- write outputs ----

writeRaster(cond.emit, 
            paste0(outpath,"Conditional_mean_CarbonReleasedFromFire.tif"), 
            overwrite = TRUE)
writeRaster(sd.emit, 
            paste0(outpath,"Conditional_sd_CarbonReleasedFromFire.tif"), 
            overwrite = TRUE)
writeRaster(cv.emit, 
            paste0(outpath,"Conditional_cv_CarbonReleasedFromFire.tif"), 
            overwrite = TRUE)

