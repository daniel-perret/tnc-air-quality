# Summarize ratio raster across polygons
# Returns sf object with summary statistics added as new columns
# Optimized for large CONUS-scale rasters (30m, ~9B cells)

library(tidyverse)
library(terra)
library(sf)
library(exactextractr)
library(furrr)
library(future)

# ============================================================================
# 1. Load and prepare inputs
# ============================================================================

raster_path <- "data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked_FRG.tif"

ratio_raster <- terra::rast(raster_path)

zone_name <- "huc10"

polygons <- sf::st_read("../../SHARED_DATA/HUC_boundaries/huc10_conus/WBDHU10 selection.shp") %>%
  sf::st_transform(terra::crs(ratio_raster))

# ============================================================================
# 2. Parallel zonal statistics via exactextractr
# ============================================================================

# exact_extract returns NA for all-NA polygons (i.e. outside FRG mask) cheaply —
# no pre-filtering needed; NAs are dropped from output after extraction

n_workers <- 16  # adjust to available cores

plan(multisession, workers = n_workers)

# Split into chunks and pass the raster file path rather than the terra object —
# each worker loads its own SpatRaster to avoid cross-session serialization issues
polygon_chunks <- polygons %>%
  mutate(.chunk = ntile(row_number(), n_workers)) %>%
  group_split(.chunk)

polygon_summaries <- future_imap(
  polygon_chunks,
  function(chunk, i) {
    r <- terra::rast(raster_path)
    stats <- exactextractr::exact_extract(r, chunk, 
                                          fun = c("mean", "median", "stdev"),
                                          max_cells_in_memory = 0)
    message(sprintf("[%d/%d] Chunk complete (%d polygons)", i, length(polygon_chunks), nrow(chunk)))
    chunk %>%
      select(-.chunk) %>%
      bind_cols(stats) %>%
      rename(sd = stdev)
  },
  .options = furrr_options(seed = TRUE)
) %>%
  bind_rows()

plan(sequential)  # release workers

# Drop polygons with no valid raster coverage (entirely outside FRG mask)
polygon_summaries <- polygon_summaries %>%
  filter(!is.na(mean))


# ============================================================================
# 3. Inspect and save results
# ============================================================================

head(polygon_summaries)

polygon_summaries %>%
  sf::st_drop_geometry() %>%
  select(huc10, mean, median, sd) %>%
  write_csv(paste0("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/",
                   zone_name,"_Tratio.csv"))
