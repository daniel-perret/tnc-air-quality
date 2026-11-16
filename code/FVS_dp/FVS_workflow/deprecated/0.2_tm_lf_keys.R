# PURPOSE:
# Given two categorical SpatRasters with identical geometry, produce:
#  (1) a raster whose values encode unique cell-wise category combinations
#  (2) a table mapping each encoded value back to the original categories
#
# This uses terra::encode() as the canonical solution.
# terra::crosstab() is used ONLY to supply frequencies (optional, but useful).
source("code/FVS_dp/cleaned_workflow/0.0_setup.R")

## encode and write function ----
encode_combinations <- function(variant) {
  
  # --- Load, clip, and align treemap and landfire rasters
  
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
                mask = T) %>% 
    resample(., tm.clip,
             method="near")
  
  # crosstab() is terra-native and authoritative for joint categories
  ctpath <- paste0("data/fbfm_crosstabs/fbfm_",variant,".csv")
  ct <- read.csv(ctpath, header=T, stringsAsFactors = F)
  ct$key <- seq_len(nrow(ct))
  
  # --- Extract cell-wise values ------------------------------------------
  # v <- values(c(tm.clip, lf.clip))          # matrix: ncell x 2
  # colnames(v) <- names(ct)[1:2]
  # ok <- complete.cases(v)
  
  # Logical raster identifying cells where both inputs are non-NA
  ok_rast <- !is.na(tm.clip) & !is.na(lf.clip)
  
  # Extract values only after defining validity at raster level
  v <- values(c(tm.clip, lf.clip))
  colnames(v) <- names(ct)[1:2]
  
  # Logical index corresponding to valid cells
  ok <- values(ok_rast)
  
  # --- Map each cell to its combination ID -------------------------------
  id_vec <- rep(NA_integer_, nrow(v))
  
  ind <- match(interaction(v[ok,1],v[ok,2]),
               interaction(ct[,1],ct[,2]))
  
  id_vec[ok] <- ct$key[ind]
  
  # --- Write IDs back to a raster ----------------------------------------
  out <- setValues(tm.clip, id_vec)
  levels(out) <- ct %>% 
    select(value = key, StandID, FBFM)
  
  
  # --- Write out raster ---------------------------------------------
  
  filename = paste0("data/tmlf_keys/tmlf_key_",variant,".tif")
  print(filename)
  writeRaster(out, filename = filename, overwrite=T)
}

encode_combinations_app <- function(variant) {
  
  # --- Load, clip, and align treemap and landfire rasters -----------------
  
  tm <- rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif")
  activeCat(tm) <- 8
  
  lf.fbfm <- rast("../../SHARED_DATA/LANDFIRE/LF2022_FBFM40_220_CONUS/Tif/LC22_F40_220.tif")
  activeCat(lf.fbfm) <- 0
  
  variant.vect <- variants.shp %>%
    filter(FVSVariant == variant) %>%
    sf::st_union() %>%
    vect()
  
  tm.clip <- tm %>%
    crop(variant.vect, mask = TRUE)
  
  lf.clip <- lf.fbfm %>%
    crop(variant.vect, mask = TRUE) %>%
    resample(tm.clip, method = "near")
  
  # --- Load crosstab ------------------------------------------------------
  
  ctpath <- paste0("data/fbfm_crosstabs/fbfm_", variant, ".csv")
  ct <- read.csv(ctpath, header = TRUE, stringsAsFactors = FALSE)
  ct$key <- seq_len(nrow(ct))
  
  # Precompute lookup tables (small; safe in R)
  ct_keys <- interaction(ct[, 1], ct[, 2])
  ct_vals <- ct$key
  
  # --- Block-wise encoding via terra::app() -------------------------------
  
  out <- app(
    c(tm.clip, lf.clip),
    fun = function(x) {
      
      tmv <- x[, 1]
      lfv <- x[, 2]
      
      ok  <- !is.na(tmv) & !is.na(lfv)
      ids <- rep(NA_integer_, length(tmv))
      
      if (any(ok)) {
        ind <- match(
          interaction(tmv[ok], lfv[ok]),
          ct_keys
        )
        ids[ok] <- ct_vals[ind]
      }
      
      ids
    }
  )
  
  # --- Attach attribute table --------------------------------------------
  
  levels(out) <- ct %>%
    dplyr::select(value = key, StandID, FBFM)
  
  # --- Write out raster ---------------------------------------------------
  
  filename <- paste0("data/tmlf_keys/tmlf_key_", variant, ".tif")
  print(filename)
  writeRaster(out, filename = filename, overwrite = TRUE)
}

## define variants, load shps and rasters ----

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

## parallelize process over variants

future::plan(future.callr::callr,
             workers=1)

furrr::future_pmap(
  list(variant = variants),
  encode_combinations_app)



