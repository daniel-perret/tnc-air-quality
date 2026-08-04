# Summarize ratio raster by categorical values within ecological zones
#
# Strategy: rather than looping crop/mask over each ecoregion polygon
# (expensive GDAL I/O per polygon, and hard to balance across workers because
# ecoregions vary hugely in area), we:
#   1. Rasterize ecoregion polygons ONCE onto the ratio raster's grid
#      (an integer "zone id" raster), and align/cache the categorical raster
#      ONCE, rather than re-resampling it inside every worker.
#   2. Split the raster into row-block chunks (more chunks than workers, so
#      idle workers can pick up more work -- chunks vary in how much valid
#      data they contain).
#   3. In parallel, each chunk reads its row block from all three aligned
#      rasters, drops NAs, and aggregates count / sum / sum-of-squares per
#      (zone, category) -- these are exactly combinable across chunks.
#   4. Median is NOT exactly combinable across chunks, so each chunk also
#      accumulates a fixed-width histogram per (zone, category); histograms
#      are summed across chunks and used to interpolate an approximate
#      median. Accuracy is bounded by bin width (n_hist_bins below).
#
# This avoids the polygon-count-based chunking (unbalanced load), the
# vector/polygonize detour (unnecessary and slow at 30m CONUS scale), and
# the invalid use of terra::zonal() with a data.frame-returning fun.

library(tidyverse)
library(terra)
library(sf)
library(data.table)
library(furrr)
library(future)
library(future.callr)

# ============================================================================
# 1. Configuration
# ============================================================================

raster_path <- "data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked_FRG.tif"
categorical_raster_path <- "../../SHARED_DATA/TREEMAP/TreeMap2020_CONUS_FORTYPCD.tif"

# USER: Specify polygon path and ID column name
polygon_path <- "../../SHARED_DATA/base_spatialdata/cleland_usfs_ecoregions/S_USA.EcoMapProvinces.shp"
polygon_id_col <- "MAP_UNIT_S"

# Cached, pre-aligned rasters (built once, reused across runs/workers)
cache_dir <- "data/dp_FVS_postprocess/CONUS_mosaic/cache"
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
zone_raster_path <- file.path(cache_dir, "ecoregion_zone_id.tif")
aligned_cat_raster_path <- file.path(cache_dir, "fortypcd_aligned.tif")

output_path <- paste0(
  "data/dp_FVS_postprocess/zonal_summaries/",
  gsub("\\.shp$", "", basename(polygon_path)), "_fortypcd_Tratio.csv"
)

# USER: Hardware budget -- 64 cores / 128 GB on this machine.
# Keep n_workers * threads_per_worker comfortably under total cores, and
# n_workers * mem_per_worker_gb comfortably under total RAM, to leave
# headroom for the OS, GDAL caching, and the main R session.
n_workers <- 20
threads_per_worker <- 3     # 20 * 3 = 60 of 64 cores
mem_per_worker_gb <- 5      # 20 * 5 = 100 of 128 GB
# Number of chunks is now derived from terra::blocks() (memory-aware row
# sizing), not set directly -- see section 4.

n_hist_bins <- 512          # resolution of the approximate median

terraOptions(memfrac = 0.8,
             memmax = 120)

# ============================================================================
# 2. Build (or load cached) aligned rasters
# ============================================================================

ratio_raster <- terra::rast(raster_path)
categorical_raster <- terra::rast(categorical_raster_path)

if (!file.exists(aligned_cat_raster_path)) {
  cat("Aligning categorical raster to ratio raster grid (one-time cache)...\n")
  if (!identical(terra::ext(ratio_raster), terra::ext(categorical_raster)) ||
      !identical(terra::res(ratio_raster), terra::res(categorical_raster))) {
    terra::resample(
      categorical_raster, ratio_raster, method = "near",
      filename = aligned_cat_raster_path, overwrite = TRUE,
      wopt = list(datatype = "INT4S")
    )
  } else {
    terra::writeRaster(categorical_raster, aligned_cat_raster_path, overwrite = TRUE)
  }
}
aligned_cat_raster_path_final <- aligned_cat_raster_path

if (!file.exists(zone_raster_path)) {
  cat("Rasterizing ecoregion polygons to zone-id raster (one-time cache)...\n")
  polygons <- sf::st_read(polygon_path, quiet = TRUE) |>
    sf::st_transform(terra::crs(ratio_raster))

  zone_lookup <- polygons |>
    sf::st_drop_geometry() |>
    dplyr::distinct(.data[[polygon_id_col]]) |>
    dplyr::mutate(zone_int = dplyr::row_number())

  polygons <- polygons |>
    dplyr::left_join(zone_lookup, by = polygon_id_col)

  terra::vect(polygons) |> 
  terra::rasterize(ratio_raster, field = "zone_int") |> 
    terra::classify(cbind(from = 0, to = NA),
                    filename = zone_raster_path, overwrite = TRUE,
                    wopt = list(datatype = "INT4S"))

  readr::write_csv(zone_lookup, file.path(cache_dir, "zone_lookup.csv"))
} else {
  zone_lookup <- readr::read_csv(file.path(cache_dir, "zone_lookup.csv"), show_col_types = FALSE)
}

# ============================================================================
# 3. Determine value range for the median-approximating histogram
# ============================================================================
setMinMax(ratio_raster,force=T)

mm <- terra::minmax(ratio_raster, compute = TRUE)
hist_breaks <- seq(mm["min", 1], mm["max", 1], length.out = n_hist_bins + 1)

# ============================================================================
# 4. Row-block chunks across the full raster extent
# ============================================================================

# Set terra's memory budget BEFORE sizing chunks: terra::blocks() uses the
# current memfrac/maxmemory options (and raster width/dtype/# of layers) to
# compute how many rows fit safely in memory, rather than us guessing a row
# count. Splitting only by a fixed n_chunks (ignoring row width) is why the
# previous version blew memory: at ~153,810 columns wide, ~1,200 rows/chunk
# is already a ~1.4 GB double vector per raster, before overhead.
terraOptions(
  memfrac = mem_per_worker_gb / 128,
  threads = threads_per_worker
)

# n = 6 accounts for holding ~2 copies each of the 3 input vectors
# (raw read + data.table column) concurrently within a chunk.
blk <- terra::blocks(ratio_raster, n = 6)
chunks <- purrr::map2(blk$row, blk$nrows, ~ list(row = .x, nrows = .y))

cat("Processing", length(chunks), "row-block chunks across", n_workers, "workers\n\n")

# ============================================================================
# 5. Parallel per-chunk aggregation (count / sum / sumsq / histogram)
# ============================================================================

plan(future.callr::callr, workers = n_workers)

process_chunk <- function(row_start, nrows) {
  ratio_r <- terra::rast(raster_path)
  cat_r <- terra::rast(aligned_cat_raster_path_final)
  zone_r <- terra::rast(zone_raster_path)

  # terra requires an explicit readStart()/readStop() around readValues()
  # for windowed (row/nrows) reads of disk-backed rasters -- without it,
  # readValues() fails with "the file is not open for reading", especially
  # in persistent worker processes (future.callr reuses R sessions across
  # chunks rather than spawning a fresh process each time).
  terra::readStart(ratio_r)
  terra::readStart(cat_r)
  terra::readStart(zone_r)
  on.exit({
    terra::readStop(ratio_r)
    terra::readStop(cat_r)
    terra::readStop(zone_r)
  })

  v_ratio <- terra::readValues(ratio_r, row = row_start, nrows = nrows)
  v_cat <- terra::readValues(cat_r, row = row_start, nrows = nrows)
  v_zone <- terra::readValues(zone_r, row = row_start, nrows = nrows)

  dt <- data.table::data.table(zone = v_zone, category = v_cat, value = v_ratio)
  dt <- dt[!is.na(zone) & !is.na(category) & !is.na(value)]

  if (nrow(dt) == 0) {
    return(list(
      agg = data.table::data.table(zone = integer(), category = integer(),
                                    n = integer(), sum = numeric(), sumsq = numeric()),
      hist = data.table::data.table(zone = integer(), category = integer(),
                                     bin = integer(), count = integer())
    ))
  }

  dt[, bin := findInterval(value, hist_breaks, all.inside = TRUE)]

  agg <- dt[, .(n = .N, sum = sum(value), sumsq = sum(value^2)), by = .(zone, category)]
  hist_counts <- dt[, .(count = .N), by = .(zone, category, bin)]

  list(agg = agg, hist = hist_counts)
}

chunk_results <- furrr::future_map(
  chunks,
  ~ process_chunk(.x$row, .x$nrows),
  .options = furrr::furrr_options(seed = TRUE)
)

agg_all <- data.table::rbindlist(purrr::map(chunk_results, "agg"))[
  , .(n = sum(n), sum = sum(sum), sumsq = sum(sumsq)),
  by = .(zone, category)
]
hist_all <- data.table::rbindlist(purrr::map(chunk_results, "hist"))[
  , .(count = sum(count)),
  by = .(zone, category, bin)
]

# ============================================================================
# 6. Combine into final mean / sd / approximate median
# ============================================================================

agg_all[, `:=`(
  mean = sum / n,
  sd = sqrt(pmax(sumsq - sum^2 / n, 0) / (n - 1))
)]

# Linear interpolation within the histogram bin containing the median rank.
approx_median <- function(bin, count, breaks, n) {
  o <- order(bin)
  bin <- bin[o]
  count <- count[o]
  cum <- cumsum(count)
  target <- n / 2
  idx <- which(cum >= target)[1]
  if (is.na(idx)) return(NA_real_)
  cum_before <- if (idx == 1) 0 else cum[idx - 1]
  count_in_bin <- count[idx]
  lo <- breaks[bin[idx]]
  hi <- breaks[bin[idx] + 1]
  if (count_in_bin == 0) return((lo + hi) / 2)
  lo + ((target - cum_before) / count_in_bin) * (hi - lo)
}

hist_with_n <- merge(hist_all, agg_all[, .(zone, category, n)], by = c("zone", "category"))
median_all <- hist_with_n[
  , .(median = approx_median(bin, count, hist_breaks, n[1])),
  by = .(zone, category)
]

zone_category_summaries <- merge(agg_all, median_all, by = c("zone", "category")) |>
  as_tibble() |>
  left_join(zone_lookup, by = c("zone" = "zone_int")) |>
  select(zone_id = all_of(polygon_id_col), category, n, mean, median, sd)

# ============================================================================
# 7. Save results
# ============================================================================

dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
write_csv(zone_category_summaries, output_path)

cat("Summary saved to", output_path, "\n")
cat("Note: median is an approximation, accurate to within",
    round(diff(hist_breaks)[1], 4), "(the histogram bin width).",
    "Increase n_hist_bins for finer resolution if needed.\n")
