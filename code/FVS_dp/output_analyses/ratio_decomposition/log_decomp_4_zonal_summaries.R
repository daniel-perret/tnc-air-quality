# log_decomp_4_zonal_summaries.R
#
# Aggregates the pixel-level decomposition rasters (from Script 3) to
# spatial/ecological zones. Because aggregation happens in log-space
# (after the log transform), these summaries are free of the Jensen's
# inequality issue present in Script 2.
#
# For each zone type, extracts:
#   - zone_mean[log_T], zone_mean[log_Rx], zone_mean[log_WF]
#   - zone_mean[rx_pull], zone_mean[wf_pull], zone_mean[rx_frac]
#   - zone_mean[|d_logT|]  (average departure magnitude)
#   - proportion of pixels in each driver_class
#
# Uses the block-chunk parallelization pattern from
# summarize_ratio_by_raster_categories.R to handle CONUS-scale rasters.
#
# Inputs:
#   data/dp_FVS_postprocess/CONUS_mosaic/ratio_decomposition/*.tif  (from Script 3)
#   Zone polygon shapefiles (HUC12, firesheds, eco provinces)
#
# Outputs (all in data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/):
#   huc12_decomp_summary.csv
#   firesheds_decomp_summary.csv
#   ecoprovince_decomp_summary.csv
#   variance_decomp_by_scale.csv

library(tidyverse)
library(terra)
library(sf)
library(data.table)
library(furrr)
library(future)
library(future.callr)

# ============================================================================
# 0. Configuration
# ============================================================================

n_workers          <- 20
threads_per_worker <- 3    # 20 * 3 = 60 of 64 cores
mem_per_worker_gb  <- 5    # 20 * 5 = 100 GB

decomp_dir  <- "data/dp_FVS_postprocess/CONUS_mosaic/ratio_decomposition"
out_csv_dir <- "data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries"
cache_dir   <- file.path(decomp_dir, "cache")

dir.create(out_csv_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(cache_dir,   showWarnings = FALSE, recursive = TRUE)

terraOptions(
  memfrac = mem_per_worker_gb / 128,
  threads = threads_per_worker
)

# Decomposition raster paths (all must exist from Script 3)
raster_paths <- list(
  log_T   = file.path(decomp_dir, "log_T.tif"),
  log_Rx  = file.path(decomp_dir, "log_Rx.tif"),
  log_WF  = file.path(decomp_dir, "log_WF.tif"),
  d_logT  = file.path(decomp_dir, "d_logT.tif"),
  rx_pull = file.path(decomp_dir, "rx_pull.tif"),
  wf_pull = file.path(decomp_dir, "wf_pull.tif"),
  rx_frac = file.path(decomp_dir, "rx_frac.tif"),
  driver  = file.path(decomp_dir, "driver_class.tif")
)

# Verify all rasters exist
missing <- names(raster_paths)[!file.exists(unlist(raster_paths))]
if (length(missing) > 0) {
  stop("Missing decomposition rasters (run Script 3 first): ",
       paste(missing, collapse = ", "))
}

# Reference raster: use log_T as the grid template
ref_r <- terra::rast(raster_paths$log_T)

# ============================================================================
# 1. Zone definitions
# ============================================================================

# Each zone configuration:
#   path       — path to polygon shapefile
#   id_col     — column name for the unique zone identifier
#   cache_name — stem for the rasterized zone-id cache file

zones <- list(
  huc12 = list(
    path       = "../../SHARED_DATA/HUC_boundaries/huc12_conus/WBDHU12 selection.shp",
    id_col     = "huc12",
    cache_name = "huc12_zone_id"
  ),
  firesheds = list(
    path       = "../../SHARED_DATA/Firesheds/Firesheds.shp",
    id_col     = "OBJECTID",
    cache_name = "firesheds_zone_id"
  ),
  ecoprovince = list(
    path       = "../../SHARED_DATA/base_spatialdata/cleland_usfs_ecoregions/S_USA.EcoMapProvinces.shp",
    id_col     = "MAP_UNIT_S",
    cache_name = "ecoprovince_zone_id"
  )
)

# ============================================================================
# 2. Build or load rasterized zone-id rasters (one-time cache per zone type)
# ============================================================================

build_zone_raster <- function(zone_cfg, ref_raster, cache_dir) {
  zone_raster_path <- file.path(cache_dir, paste0(zone_cfg$cache_name, ".tif"))
  lookup_path      <- file.path(cache_dir, paste0(zone_cfg$cache_name, "_lookup.csv"))

  if (!file.exists(zone_raster_path)) {
    cat("Building zone raster cache:", zone_cfg$cache_name, "\n")

    polys <- sf::st_read(zone_cfg$path, quiet = TRUE) %>%
      sf::st_transform(terra::crs(ref_raster))

    zone_lookup <- polys %>%
      sf::st_drop_geometry() %>%
      dplyr::distinct(.data[[zone_cfg$id_col]]) %>%
      dplyr::mutate(zone_int = dplyr::row_number())

    polys <- polys %>% dplyr::left_join(zone_lookup, by = zone_cfg$id_col)

    terra::vect(polys) %>%
      terra::rasterize(ref_raster, field = "zone_int") %>%
      terra::classify(cbind(from = 0, to = NA),
                      filename  = zone_raster_path,
                      overwrite = TRUE,
                      wopt      = list(datatype = "INT4S"))

    readr::write_csv(zone_lookup, lookup_path)
    cat("  Cached:", zone_raster_path, "\n")
  }

  list(
    zone_raster_path = zone_raster_path,
    zone_lookup      = readr::read_csv(lookup_path, show_col_types = FALSE),
    id_col           = zone_cfg$id_col
  )
}

zone_caches <- purrr::map(zones, build_zone_raster,
                           ref_raster = ref_r,
                           cache_dir  = cache_dir)

# ============================================================================
# 3. Parallel block-chunk extraction for one zone type
# ============================================================================

# For each zone type, processes the raster stack in row blocks, accumulating:
#   - count / sum / sumsq  for log_T, log_Rx, log_WF, d_logT, rx_pull, wf_pull, rx_frac
#   - count per driver_class
# These are exactly combinable across chunks.

extract_decomp_by_zone <- function(zone_cache, raster_paths, n_workers,
                                   threads_per_worker, mem_per_worker_gb,
                                   zone_label) {
  zone_raster_path <- zone_cache$zone_raster_path
  zone_lookup      <- zone_cache$zone_lookup
  id_col           <- zone_cache$id_col

  cat("\n--- Extracting decomposition by zone:", zone_label, "---\n")

  # Size chunks based on available memory per worker
  terraOptions(
    memfrac = mem_per_worker_gb / 128,
    threads = threads_per_worker
  )
  r_ref  <- terra::rast(raster_paths$log_T)
  # n=8: ~8 raster layers read concurrently per chunk
  blk    <- terra::blocks(r_ref, n = 8)
  chunks <- purrr::map2(blk$row, blk$nrows, ~list(row = .x, nrows = .y))
  cat("  Processing", length(chunks), "row-block chunks across", n_workers, "workers\n")

  plan(future.callr::callr, workers = n_workers)

  process_chunk <- function(row_start, nrows) {
    r_logT   <- terra::rast(raster_paths$log_T)
    r_logRx  <- terra::rast(raster_paths$log_Rx)
    r_logWF  <- terra::rast(raster_paths$log_WF)
    r_dlogT  <- terra::rast(raster_paths$d_logT)
    r_rxpull <- terra::rast(raster_paths$rx_pull)
    r_wfpull <- terra::rast(raster_paths$wf_pull)
    r_rxfrac <- terra::rast(raster_paths$rx_frac)
    r_driver <- terra::rast(raster_paths$driver)
    r_zone   <- terra::rast(zone_raster_path)

    rasters <- list(r_logT, r_logRx, r_logWF, r_dlogT,
                    r_rxpull, r_wfpull, r_rxfrac, r_driver, r_zone)
    purrr::walk(rasters, terra::readStart)
    on.exit(purrr::walk(rasters, terra::readStop))

    read_block <- function(r) terra::readValues(r, row = row_start, nrows = nrows)

    dt <- data.table::data.table(
      zone     = read_block(r_zone),
      log_T    = read_block(r_logT),
      log_Rx   = read_block(r_logRx),
      log_WF   = read_block(r_logWF),
      d_logT   = read_block(r_dlogT),
      rx_pull  = read_block(r_rxpull),
      wf_pull  = read_block(r_wfpull),
      rx_frac  = read_block(r_rxfrac),
      driver   = as.integer(read_block(r_driver))
    )

    dt <- dt[!is.na(zone) & !is.na(log_T)]

    if (nrow(dt) == 0) {
      empty_agg <- data.table::data.table(
        zone = integer(), n = integer(),
        sum_logT = numeric(), sumsq_logT = numeric(),
        sum_logRx = numeric(), sumsq_logRx = numeric(),
        sum_logWF = numeric(), sumsq_logWF = numeric(),
        sum_dlogT = numeric(), sum_abs_dlogT = numeric(),
        sum_rxpull = numeric(), sum_wfpull = numeric(),
        sum_rxfrac = numeric(), sumsq_rxfrac = numeric()
      )
      empty_driver <- data.table::data.table(
        zone = integer(), driver = integer(), count = integer()
      )
      return(list(agg = empty_agg, driver = empty_driver))
    }

    agg <- dt[, .(
      n             = .N,
      sum_logT      = sum(log_T),   sumsq_logT  = sum(log_T^2),
      sum_logRx     = sum(log_Rx),  sumsq_logRx = sum(log_Rx^2),
      sum_logWF     = sum(log_WF),  sumsq_logWF = sum(log_WF^2),
      sum_dlogT     = sum(d_logT),
      sum_abs_dlogT = sum(abs(d_logT)),
      sum_rxpull    = sum(rx_pull),
      sum_wfpull    = sum(wf_pull),
      sum_rxfrac    = sum(rx_frac,    na.rm = TRUE),
      sumsq_rxfrac  = sum(rx_frac^2, na.rm = TRUE)
    ), by = zone]

    driver_counts <- dt[!is.na(driver), .(count = .N), by = .(zone, driver)]

    list(agg = agg, driver = driver_counts)
  }

  chunk_results <- furrr::future_map(
    chunks,
    ~process_chunk(.x$row, .x$nrows),
    .options = furrr::furrr_options(seed = TRUE)
  )

  # Combine across chunks
  agg_all <- data.table::rbindlist(purrr::map(chunk_results, "agg"))[
    , .(
      n             = sum(n),
      sum_logT      = sum(sum_logT),   sumsq_logT  = sum(sumsq_logT),
      sum_logRx     = sum(sum_logRx),  sumsq_logRx = sum(sumsq_logRx),
      sum_logWF     = sum(sum_logWF),  sumsq_logWF = sum(sumsq_logWF),
      sum_dlogT     = sum(sum_dlogT),
      sum_abs_dlogT = sum(sum_abs_dlogT),
      sum_rxpull    = sum(sum_rxpull),
      sum_wfpull    = sum(sum_wfpull),
      sum_rxfrac    = sum(sum_rxfrac),
      sumsq_rxfrac  = sum(sumsq_rxfrac)
    ),
    by = zone
  ]

  driver_all <- data.table::rbindlist(purrr::map(chunk_results, "driver"))[
    , .(count = sum(count)), by = .(zone, driver)
  ]

  # Compute means and SDs from aggregated sums
  agg_all[, `:=`(
    mean_logT    = sum_logT  / n,
    sd_logT      = sqrt(pmax(sumsq_logT  - sum_logT^2  / n, 0) / pmax(n - 1, 1)),
    mean_logRx   = sum_logRx / n,
    sd_logRx     = sqrt(pmax(sumsq_logRx - sum_logRx^2 / n, 0) / pmax(n - 1, 1)),
    mean_logWF   = sum_logWF / n,
    sd_logWF     = sqrt(pmax(sumsq_logWF - sum_logWF^2 / n, 0) / pmax(n - 1, 1)),
    mean_dlogT   = sum_dlogT / n,
    mean_abs_dlogT = sum_abs_dlogT / n,
    mean_rxpull  = sum_rxpull / n,
    mean_wfpull  = sum_wfpull / n,
    mean_rxfrac  = sum_rxfrac / n,
    sd_rxfrac    = sqrt(pmax(sumsq_rxfrac - sum_rxfrac^2 / n, 0) / pmax(n - 1, 1))
  )]

  # Driver class proportions (wide format)
  driver_wide <- driver_all %>%
    as_tibble() %>%
    left_join(agg_all %>% as_tibble() %>% select(zone, n), by = "zone") %>%
    mutate(
      pct = count / n,
      driver_label = case_when(
        driver == 1L ~ "pct_Rx_above",
        driver == 2L ~ "pct_WF_above",
        driver == 3L ~ "pct_Rx_below",
        driver == 4L ~ "pct_WF_below",
        driver == 5L ~ "pct_Mixed",
        TRUE         ~ paste0("pct_class_", driver)
      )
    ) %>%
    select(zone, driver_label, pct) %>%
    tidyr::pivot_wider(names_from = driver_label, values_from = pct,
                       values_fill = 0)

  # Final joined summary
  result <- agg_all %>%
    as_tibble() %>%
    select(zone, n,
           mean_logT, sd_logT,
           mean_logRx, sd_logRx,
           mean_logWF, sd_logWF,
           mean_dlogT, mean_abs_dlogT,
           mean_rxpull, mean_wfpull,
           mean_rxfrac, sd_rxfrac) %>%
    left_join(driver_wide, by = "zone") %>%
    left_join(zone_lookup %>% rename(zone = zone_int), by = "zone") %>%
    rename(zone_id = all_of(id_col)) %>%
    select(-zone) %>%
    arrange(zone_id)

  cat("  Extracted", nrow(result), "zones\n")
  result
}

# ============================================================================
# 4. Run extraction for each zone type
# ============================================================================

huc12_decomp_summary <- extract_decomp_by_zone(
  zone_caches$huc12, raster_paths, n_workers, threads_per_worker, mem_per_worker_gb,
  zone_label = "HUC12"
)

firesheds_decomp_summary <- extract_decomp_by_zone(
  zone_caches$firesheds, raster_paths, n_workers, threads_per_worker, mem_per_worker_gb,
  zone_label = "Firesheds"
)

ecoprovince_decomp_summary <- extract_decomp_by_zone(
  zone_caches$ecoprovince, raster_paths, n_workers, threads_per_worker, mem_per_worker_gb,
  zone_label = "Eco Province"
)

# ============================================================================
# 5. Variance decomposition table (using pixel-level aggregated log values)
# ============================================================================

# At this point we have zone-level means and SDs of log_T, log_Rx, log_WF.
# Cross-zone variance decomposition:
#   Var(log T) = Var(log Rx) + Var(log WF) - 2*Cov(log Rx, log WF)
# Cov(log Rx, log WF) cannot be recovered from sums alone without the full
# pixel data, so it is estimated from the zone-mean values here (an approximation).

var_decomp_raster <- function(df, scale_label) {
  d <- df %>% filter(!is.na(mean_logT), !is.na(mean_logRx), !is.na(mean_logWF))

  var_logT  <- var(d$mean_logT)
  var_logRx <- var(d$mean_logRx)
  var_logWF <- var(d$mean_logWF)
  cov_RxWF  <- cov(d$mean_logRx, d$mean_logWF)

  tibble(
    scale           = scale_label,
    n_zones         = nrow(d),
    var_logT        = var_logT,
    var_logRx       = var_logRx,
    var_logWF       = var_logWF,
    cov_logRx_logWF = cov_RxWF,
    recon_check     = var_logRx + var_logWF - 2 * cov_RxWF,
    pct_from_Rx     = 100 * var_logRx / var_logT,
    pct_from_WF     = 100 * var_logWF / var_logT,
    pct_cov_term    = 100 * (-2 * cov_RxWF) / var_logT
  )
}

var_decomp_raster_table <- bind_rows(
  var_decomp_raster(huc12_decomp_summary,      "HUC12"),
  var_decomp_raster(firesheds_decomp_summary,  "Firesheds"),
  var_decomp_raster(ecoprovince_decomp_summary, "Eco Province")
)

cat("\n--- Cross-zone variance decomposition (from raster-derived means) ---\n")
print(var_decomp_raster_table)

# ============================================================================
# 6. Save outputs
# ============================================================================

write_csv(huc12_decomp_summary,      file.path(out_csv_dir, "huc12_decomp_summary.csv"))
write_csv(firesheds_decomp_summary,  file.path(out_csv_dir, "firesheds_decomp_summary.csv"))
write_csv(ecoprovince_decomp_summary, file.path(out_csv_dir, "ecoprovince_decomp_summary.csv"))
write_csv(var_decomp_raster_table,   file.path(out_csv_dir, "variance_decomp_by_scale.csv"))

cat("\nScript 4 complete. Outputs written to:", out_csv_dir, "\n")
cat("Proceed to Script 5 (visualizations).\n")
