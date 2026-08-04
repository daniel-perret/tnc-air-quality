# Summarize ratio raster by categorical values within ecological zones
# Uses terra::zonal() within each polygon, parallelized across polygons

library(tidyverse)
library(terra)
library(sf)
library(furrr)
library(future)
library(future.callr)

# ============================================================================
# 1. Configuration
# ============================================================================

raster_path <- "data/dp_FVS_postprocess/CONUS_mosaic/Rx_CarbonReleasedFromFire_FRG_masked.tif"
categorical_raster_path <- "../../SHARED_DATA/TREEMAP/TreeMap2020_CONUS_FORTYPCD.tif"

# USER: Specify polygon path and ID column name
polygon_path <- "../../SHARED_DATA/base_spatialdata/cleland_usfs_ecoregions/S_USA.EcoMapProvinces.shp"  # Change this path as needed
polygon_id_col <- "US_L3CODE"  # Change this to appropriate ID column


# ============================================================================
# 2. Load and prepare inputs
# ============================================================================

ratio_raster <- terra::rast(raster_path)
categorical_raster <- terra::rast(categorical_raster_path)
# 
# # Align rasters if needed
# if (!identical(terra::ext(ratio_raster), terra::ext(categorical_raster)) ||
#     !identical(terra::res(ratio_raster), terra::res(categorical_raster))) {
#   categorical_raster <- terra::resample(categorical_raster, ratio_raster, method = "near")
# }

polygons <- sf::st_read(polygon_path) %>%
  sf::st_transform(terra::crs(ratio_raster))

# ============================================================================
# 3. Parallel zonal statistics within polygons
# ============================================================================

n_workers <- 1

terraOptions(memfrac = (56/n_workers)/56,
             memmax = 56/n_workers,
             threads = 16)
             

plan(future.callr::callr,
     workers = n_workers)

# Split polygons into chunks
polygon_chunks <- polygons %>%
  mutate(.chunk = ntile(row_number(), n_workers)) %>%
  group_split(.chunk)

cat("Processing", length(polygon_chunks), "chunks across", n_workers, "workers\n\n")

zone_category_summaries <- future_imap(
  polygon_chunks,
  function(chunk, i) {
    ratio_r <- terra::rast(raster_path)
    cat_r <- terra::rast(categorical_raster_path)
    
    # Align categorical raster to ratio raster
    if (!identical(terra::ext(ratio_r), terra::ext(cat_r)) ||
        !identical(terra::res(ratio_r), terra::res(cat_r))) {
      cat_r <- terra::resample(cat_r, ratio_r, method = "near")
    }
    
    # For each polygon, crop rasters and compute zonal stats
    zone_results <- map_df(
      seq_len(nrow(chunk)),
      function(j) {
        zone_id <- chunk[[polygon_id_col]][j]
        zone_geom <- chunk[j, ]
        
        # Crop rasters to polygon extent
        ratio_cropped <- terra::crop(ratio_r, terra::vect(zone_geom), mask = TRUE)
        cat_cropped <- terra::crop(cat_r, terra::vect(zone_geom), mask = TRUE)
        
        # convert cat to polygons
        
        cat_poly <- terra::as.polygons(cat_cropped) %>% 
          sf::st_as_sf()
        
        # use exact_extractr to calculate summaries over polygons
        
        stats <- exactextractr::exact_extract(r, cat_poly, 
                                              fun = c("mean", "median", "stdev"),
                                              max_cells_in_memory = 1e6,
                                              progress = FALSE)
        
        
        # Compute zonal statistics using categorical raster as zones
        zonal_result <- terra::zonal(
          ratio_cropped,
          cat_cropped,
          fun = function(x) {
            data.frame(
              mean = mean(x, na.rm = TRUE),
              median = median(x, na.rm = TRUE),
              sd = sd(x, na.rm = TRUE)
              )
          }
        ) %>%
          as_tibble() %>%
          rename(category = Label) %>%
          mutate(zone_id = zone_id, .before = category)
        
        zonal_result
      }
    )
    
    zone_results
  },
  .options = furrr_options(seed = TRUE)
) %>%
  bind_rows()


# ============================================================================
# 4. Inspect and save results
# ============================================================================

# Save results
write_csv(
  zone_category_summaries,
  paste0("data/dp_FVS_postprocess/zonal_summaries/",
         gsub("\\.shp$", "", basename(polygon_path)), "_fortypcd_Tratio.csv")
)

cat("Summary saved to data/dp_FVS_postprocess/zonal_summaries/\n")
