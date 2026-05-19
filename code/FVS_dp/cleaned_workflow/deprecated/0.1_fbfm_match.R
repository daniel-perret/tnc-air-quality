### This script writes a series of dataframes that contain the TM StandID and LF FBFM40 combinations for each variant

### ONLY RUN ONCE, THEN READ IN RESULTS FOR SUBSEQUENT SCRIPTS

## define variants, load shps and rasters

dbs <- list.files(TMFM2020_dir_path,
                  full.names=TRUE)

variants <- dbs %>% 
  str_sub(., -5,-4)
                  
tm <- rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif")
activeCat(tm) <- 8

lf.fbfm <- rast("../../SHARED_DATA/LANDFIRE/LF2022_FBFM40_220_CONUS/Tif/LC22_F40_220.tif")
activeCat(lf.fbfm) <- 0

variants.shp <- sf::read_sf("../../SHARED_DATA/FVSVariantMap20210525/FVS_Variants_and_Locations.shp") %>% 
  sf::st_transform(crs(tm))

## parallelize across variants

future::plan(future.callr::callr,
             workers=4)

furrr::future_pmap(
  list(variant = variants),
  function(variant){
    # 
    # td <- tempfile()
    # dir.create(td, recursive = TRUE)
    # terra::terraOptions(tempdir = td, threads = 1)    
    
    tm <- rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif")
    activeCat(tm) <- 8
    
    lf.fbfm <- rast("../../SHARED_DATA/LANDFIRE/LF2022_FBFM40_220_CONUS/Tif/LC22_F40_220.tif")
    activeCat(lf.fbfm) <- 0
    
    variant.vect <- variants.shp %>% 
      filter(FVSVariant==variant) %>% 
      sf::st_union() %>% 
      vect()
    
    tm.clip <- tm %>% 
      terra::crop(., 
                  variant.vect, 
                  mask = T)
    
    lf.clip <- lf.fbfm %>% 
      terra::crop(., 
                  variant.vect, 
                  mask = T)
    
    lf_aligned <- terra::resample(
      lf.clip,
      tm.clip,
      method = "near"   # categorical-safe
    )
    
    fbfm.dat <- terra::crosstab(c(tm.clip, lf_aligned)) %>%
      as.data.frame() %>% 
      filter(Freq>0) %>% 
      select(StandID,
             FBFM = Value)
    
    write.table(fbfm.dat,
                file = paste0("data/fbfm_crosstabs/fbfm_", variant,".csv"),
                sep = ",",
                row.names = F)
  }
)




