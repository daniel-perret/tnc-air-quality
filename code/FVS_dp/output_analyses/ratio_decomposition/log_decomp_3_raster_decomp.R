# log_decomp_3_raster_decomp.R
#
# Pixel-level log-decomposition of the T ratio raster. This is the exact
# decomposition (no Jensen's inequality caveat) and produces the primary
# spatial outputs for the analysis.
#
# Identity implemented at the pixel level:
#   log(T_i) = log(Rx_i) - log(WF_i)                        [exact]
#   delta_log(T_i) = delta_log(Rx_i) - delta_log(WF_i)      [exact]
#                  = rx_pull_i + wf_pull_i
#
# All inputs use the FRG mask. Rx has no zero pixels under the FRG mask.
# All output rasters are written to disk immediately (no large in-memory objects).
#
# Inputs:
#   data/dp_FVS_postprocess/CONUS_mosaic/WF_Conditional_mean_CarbonReleasedFromFire_FRG_masked.tif
#   data/dp_FVS_postprocess/CONUS_mosaic/Rx_CarbonReleasedFromFire_FRG_masked.tif
#   data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked_FRG.tif  (for verification)
#
# Outputs (all in data/dp_FVS_postprocess/CONUS_mosaic/ratio_decomposition/):
#   log_WF.tif        — log of WF mean carbon emissions
#   log_Rx.tif        — log of Rx carbon emissions
#   log_T.tif         — log(T) = log_Rx - log_WF
#   d_logWF.tif       — departure of log_WF from CONUS mean
#   d_logRx.tif       — departure of log_Rx from CONUS mean
#   d_logT.tif        — departure of log_T from CONUS mean (= d_logRx - d_logWF)
#   rx_pull.tif       — Rx contribution to T departure (= d_logRx)
#   wf_pull.tif       — WF contribution to T departure (= -d_logWF)
#   rx_frac.tif       — fraction of |total pull| from Rx [-1, 1]
#   driver_class.tif  — categorical driver classification (integer 1-5)
#
# driver_class values:
#   1 = Rx-dominant, T above CONUS mean
#   2 = WF-dominant, T above CONUS mean
#   3 = Rx-dominant, T below CONUS mean
#   4 = WF-dominant, T below CONUS mean
#   5 = Mixed (|rx_pull| and |wf_pull| within MIXED_THRESHOLD of each other)
#
# Reference values (CONUS mean of each log-raster) are saved to:
#   data/dp_FVS_postprocess/ratio_decomposition/conus_reference_values.csv

library(tidyverse)
library(terra)

# ============================================================================
# 0. Configuration
# ============================================================================

MIXED_THRESHOLD <- 0.10  # pulls within 10% of total = "Mixed"

mosaic_dir <- "data/dp_FVS_postprocess/CONUS_mosaic"
out_dir    <- file.path(mosaic_dir, "ratio_decomposition")
ref_dir    <- "data/dp_FVS_postprocess/ratio_decomposition"

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(ref_dir, showWarnings = FALSE, recursive = TRUE)

# Input raster paths
wf_path <- file.path(mosaic_dir, "WF_Conditional_mean_CarbonReleasedFromFire_FRG_masked.tif")
rx_path <- file.path(mosaic_dir, "Rx_CarbonReleasedFromFire_FRG_masked.tif")
t_path  <- file.path(mosaic_dir, "Rx_WF_ratio_masked_FRG.tif")   # for verification only

# Output raster paths
log_wf_path  <- file.path(out_dir, "log_WF.tif")
log_rx_path  <- file.path(out_dir, "log_Rx.tif")
log_t_path   <- file.path(out_dir, "log_T.tif")
d_logwf_path <- file.path(out_dir, "d_logWF.tif")
d_logrx_path <- file.path(out_dir, "d_logRx.tif")
d_logt_path  <- file.path(out_dir, "d_logT.tif")
rxpull_path  <- file.path(out_dir, "rx_pull.tif")
wfpull_path  <- file.path(out_dir, "wf_pull.tif")
rxfrac_path  <- file.path(out_dir, "rx_frac.tif")
driver_path  <- file.path(out_dir, "driver_class.tif")

# Terra memory options: use most of available RAM, write intermediates to disk
terraOptions(memfrac = 0.80, memmax = 100)

# ============================================================================
# 1. Load input rasters
# ============================================================================

cat("Loading input rasters...\n")
wf_r <- terra::rast(wf_path)
rx_r <- terra::rast(rx_path)

# Verify alignment
stopifnot(
  "WF and Rx rasters must have identical extent and resolution" =
    all(terra::compareGeom(wf_r, rx_r, stopOnError = FALSE))
)

cat("  WF raster:", terra::ncell(wf_r), "cells,", terra::nrow(wf_r), "rows x", terra::ncol(wf_r), "cols\n")
cat("  CRS:", terra::crs(wf_r, describe = TRUE)$name, "\n")

# ============================================================================
# 2. Compute log rasters
# ============================================================================

# All intermediates written directly to disk via filename= argument.

cat("\nComputing log_WF...\n")
log_wf_r <- terra::app(
  wf_r,
  fun      = log,
  filename = log_wf_path,
  overwrite = TRUE,
  wopt     = list(datatype = "FLT4S")
)

cat("Computing log_Rx...\n")
log_rx_r <- terra::app(
  rx_r,
  fun      = log,
  filename = log_rx_path,
  overwrite = TRUE,
  wopt     = list(datatype = "FLT4S")
)

cat("Computing log_T = log_Rx - log_WF...\n")
log_t_r <- log_rx_r - log_wf_r
terra::writeRaster(log_t_r, log_t_path, overwrite = TRUE,
                   wopt = list(datatype = "FLT4S"))
log_t_r <- terra::rast(log_t_path)  # reload from disk to free memory

# ============================================================================
# 3. Verification: compare log_T to log(T_ratio raster)
# ============================================================================

cat("\nVerification: sampling log_T vs log(T_ratio raster)...\n")

t_r       <- terra::rast(t_path)
log_t_ref <- terra::app(t_r, fun = log)

set.seed(8473)
samp_idx <- terra::spatSample(log_t_r, size = 5e5, method = "random",
                               cells = TRUE, na.rm = TRUE)$cell

log_t_vals     <- terra::extract(log_t_r,   samp_idx)[, 1]
log_t_ref_vals <- terra::extract(log_t_ref, samp_idx)[, 1]

resid <- log_t_vals - log_t_ref_vals
cat("  Residual (log_T computed vs log_T from ratio raster):\n")
cat("    mean =", round(mean(resid, na.rm = TRUE), 6), "\n")
cat("    SD   =", round(sd(resid,   na.rm = TRUE), 6), "\n")
cat("    max  =", round(max(abs(resid), na.rm = TRUE), 6), "\n")

rm(t_r, log_t_ref, samp_idx, log_t_vals, log_t_ref_vals, resid)
gc()

# ============================================================================
# 4. Compute CONUS reference values (mean of each log-raster)
# ============================================================================

cat("\nComputing CONUS reference values (global means)...\n")

ref_log_WF <- terra::global(log_wf_r, "mean", na.rm = TRUE)[1, 1]
ref_log_Rx <- terra::global(log_rx_r, "mean", na.rm = TRUE)[1, 1]
ref_log_T  <- terra::global(log_t_r,  "mean", na.rm = TRUE)[1, 1]

cat("  ref_log_WF =", round(ref_log_WF, 5), "\n")
cat("  ref_log_Rx =", round(ref_log_Rx, 5), "\n")
cat("  ref_log_T  =", round(ref_log_T,  5), "\n")
cat("  Check: ref_log_Rx - ref_log_WF =", round(ref_log_Rx - ref_log_WF, 5),
    "(should be approx equal to ref_log_T)\n")

# Save reference values for use in Scripts 4 and 5
ref_vals <- tibble(
  quantity    = c("ref_log_WF", "ref_log_Rx", "ref_log_T"),
  value       = c(ref_log_WF,   ref_log_Rx,   ref_log_T),
  description = c(
    "CONUS mean of log(WF mean carbon) over FRG-masked pixels",
    "CONUS mean of log(Rx carbon) over FRG-masked pixels",
    "CONUS mean of log(T ratio) over FRG-masked pixels"
  )
)
write_csv(ref_vals, file.path(ref_dir, "conus_reference_values.csv"))

# ============================================================================
# 5. Compute departure rasters
# ============================================================================

cat("\nComputing departure rasters...\n")

d_logwf_r <- log_wf_r - ref_log_WF
terra::writeRaster(d_logwf_r, d_logwf_path, overwrite = TRUE,
                   wopt = list(datatype = "FLT4S"))
d_logwf_r <- terra::rast(d_logwf_path)

d_logrx_r <- log_rx_r - ref_log_Rx
terra::writeRaster(d_logrx_r, d_logrx_path, overwrite = TRUE,
                   wopt = list(datatype = "FLT4S"))
d_logrx_r <- terra::rast(d_logrx_path)

d_logt_r <- log_t_r - ref_log_T
terra::writeRaster(d_logt_r, d_logt_path, overwrite = TRUE,
                   wopt = list(datatype = "FLT4S"))
d_logt_r <- terra::rast(d_logt_path)

# ============================================================================
# 6. Compute pull rasters
# ============================================================================

cat("Computing pull rasters...\n")

# rx_pull = d_logRx  (positive = Rx above mean = elevates T)
terra::writeRaster(d_logrx_r, rxpull_path, overwrite = TRUE,
                   wopt = list(datatype = "FLT4S"))
rx_pull_r <- terra::rast(rxpull_path)

# wf_pull = -d_logWF  (positive = WF below mean = elevates T)
wf_pull_r <- -d_logwf_r
terra::writeRaster(wf_pull_r, wfpull_path, overwrite = TRUE,
                   wopt = list(datatype = "FLT4S"))
wf_pull_r <- terra::rast(wfpull_path)

rm(d_logwf_r, d_logrx_r, log_wf_r, log_rx_r)
gc()

# ============================================================================
# 7. Compute rx_frac raster
# ============================================================================

cat("Computing rx_frac (relative Rx influence)...\n")

# rx_frac = rx_pull / (|rx_pull| + |wf_pull|)
# Range: [-1, 1]  positive = Rx dominant contributor to T departure
# NA where both pulls are zero (T exactly at CONUS mean for both components)

total_pull_abs_r <- abs(rx_pull_r) + abs(wf_pull_r)
rx_frac_r <- terra::ifel(
  total_pull_abs_r > 0,
  rx_pull_r / total_pull_abs_r,
  NA
)
terra::writeRaster(rx_frac_r, rxfrac_path, overwrite = TRUE,
                   wopt = list(datatype = "FLT4S"))
rx_frac_r <- terra::rast(rxfrac_path)

# ============================================================================
# 8. Compute driver_class raster (integer categorical)
# ============================================================================

cat("Computing driver_class raster...\n")

# A pixel is "Mixed" if neither pull exceeds the other by more than
# MIXED_THRESHOLD * total_pull_abs (i.e., |rx_frac| is close to 0.5).
# mixed_band: 0.5 - MIXED_THRESHOLD/2 ... 0.5 + MIXED_THRESHOLD/2
# In terms of rx_frac: |rx_frac| in (0.5 - thresh/2, 0.5 + thresh/2) -> Mixed
# Equivalently: |rx_frac - 0.5| < MIXED_THRESHOLD/2
# But rx_frac is signed [-1,1]; the "equal magnitude" zone is |rx_frac| < MIXED_THRESHOLD
# i.e., rx_pull accounts for <MIXED_THRESHOLD of the signed range -> Mixed

mixed_band <- MIXED_THRESHOLD  # |rx_frac| < this => Mixed

driver_r <- terra::ifel(
  abs(rx_frac_r) <= mixed_band,
  5L,  # Mixed
  terra::ifel(
    d_logt_r >= 0 & rx_frac_r > mixed_band,
    1L,  # Rx-dominant, T above mean
    terra::ifel(
      d_logt_r >= 0 & rx_frac_r < -mixed_band,
      2L,  # WF-dominant, T above mean
      terra::ifel(
        d_logt_r < 0 & rx_frac_r > mixed_band,
        3L,  # Rx-dominant, T below mean
        4L   # WF-dominant, T below mean
      )
    )
  )
)

terra::writeRaster(
  driver_r, driver_path, overwrite = TRUE,
  wopt = list(datatype = "INT1U")
)

# Save driver class lookup table alongside outputs
driver_lookup <- tibble(
  class_value = 1:5,
  label = c(
    "Rx-dominant, T above CONUS mean",
    "WF-dominant, T above CONUS mean",
    "Rx-dominant, T below CONUS mean",
    "WF-dominant, T below CONUS mean",
    "Mixed (pulls within threshold)"
  ),
  mixed_threshold = MIXED_THRESHOLD
)
write_csv(driver_lookup, file.path(out_dir, "driver_class_lookup.csv"))

# ============================================================================
# 9. Summary statistics of decomposition rasters
# ============================================================================

cat("\nComputing summary statistics of output rasters...\n")

raster_summary <- tibble(
  raster   = c("log_WF", "log_Rx", "log_T",
                "d_logWF", "d_logRx", "d_logT",
                "rx_pull", "wf_pull", "rx_frac"),
  path     = c(log_wf_path, log_rx_path, log_t_path,
               d_logwf_path, d_logrx_path, d_logt_path,
               rxpull_path, wfpull_path, rxfrac_path)
) %>%
  mutate(
    stats = purrr::map(path, function(p) {
      r  <- terra::rast(p)
      gm <- terra::global(r, c("mean", "sd", "min", "max"), na.rm = TRUE)
      tibble(mean = gm[1,1], sd = gm[1,2], min = gm[1,3], max = gm[1,4])
    })
  ) %>%
  tidyr::unnest(stats) %>%
  select(-path)

cat("\nDecomposition raster summaries:\n")
print(raster_summary)

# Driver class pixel counts
driver_r_loaded <- terra::rast(driver_path)
driver_counts <- terra::freq(driver_r_loaded) %>%
  as_tibble() %>%
  rename(class_value = value, pixel_count = count) %>%
  left_join(driver_lookup %>% select(class_value, label), by = "class_value") %>%
  mutate(pct = round(100 * pixel_count / sum(pixel_count), 2))

cat("\nDriver class pixel distribution:\n")
print(driver_counts)

write_csv(raster_summary, file.path(ref_dir, "decomp_raster_summary.csv"))
write_csv(driver_counts,  file.path(ref_dir, "driver_class_pixel_counts.csv"))

cat("\nScript 3 complete.\n")
cat("  Decomposition rasters written to:", out_dir, "\n")
cat("  Reference values and summaries written to:", ref_dir, "\n")
cat("  Proceed to Script 4 (zonal summaries of decomposition).\n")
