# log_decomp_2_zonal_decomp.R
#
# Performs the log-decomposition of the T ratio at the zonal level using
# existing zonal summary CSVs. Uses the identity:
#
#   log(T) = log(Rx) - log(WF)
#   delta_log(T) = delta_log(Rx) - delta_log(WF)
#                = rx_pull + wf_pull
#
# where rx_pull = delta_log(Rx)  (positive = Rx above reference; pushes T up)
#       wf_pull = -delta_log(WF) (positive = WF below reference; pushes T up)
#
# NOTE (Jensen's inequality): This script uses log(zone_mean_X), not
# zone_mean[log(X)]. These are approximately equal when within-zone variance
# is small, but the decomposition identity log(T) = log(Rx) - log(WF) holds
# only approximately at the zonal mean level. Residuals from the identity are
# reported as a diagnostic. The exact decomposition is implemented in Script 3
# (pixel-level rasters).
#
# Scales with all three components (T, WF, Rx):
#   - HUC12
#   - EcoMapProvince x Forest Type
#
# Inputs:
#   data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/huc12_Tratio.csv
#   data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/huc12_WfCarbon.csv
#   data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/huc12_RxCarbon.csv
#   data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/S_USA.EcoMapProvinces_fortypcd_*.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/scale_variation_summary.csv
#     (from Script 1 — used to report reference scale recommendation)
#
# Outputs:
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/huc12_logdecomp.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/ecofortype_logdecomp.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/variance_decomp_zonal.csv

library(tidyverse)

# ============================================================================
# 0. Paths and configuration
# ============================================================================

zonal_dir   <- "data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries"
out_csv_dir <- "data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries"
dir.create(out_csv_dir, showWarnings = FALSE, recursive = TRUE)

# Driver classification threshold: a zone is "Mixed" if neither pull exceeds
# the other by more than this fraction of the total absolute pull.
# 0.10 = pulls must differ by >10% of their combined magnitude to be classified.
MIXED_THRESHOLD <- 0.10

# ============================================================================
# 1. Load and join zonal summaries
# ============================================================================

# -- HUC12 -------------------------------------------------------------------
# ID columns differ across files: huc12_Tratio uses "huc12", others use "ID"

huc12_T <- read_csv(
  file.path(zonal_dir, "huc12_Tratio.csv"), show_col_types = FALSE
) %>%
  rename(zone_id = huc12, mean_T = mean, sd_T = sd, median_T = median)

huc12_WF <- read_csv(
  file.path(zonal_dir, "huc12_WfCarbon.csv"), show_col_types = FALSE
) %>%
  rename(zone_id = ID, mean_WF = mean, sd_WF = sd, median_WF = median)

huc12_Rx <- read_csv(
  file.path(zonal_dir, "huc12_RxCarbon.csv"), show_col_types = FALSE
) %>%
  rename(zone_id = ID, mean_Rx = mean, sd_Rx = sd, median_Rx = median)

huc12 <- huc12_T %>%
  inner_join(huc12_WF, by = "zone_id") %>%
  inner_join(huc12_Rx, by = "zone_id") %>%
  filter(!is.na(mean_T), !is.na(mean_WF), !is.na(mean_Rx),
         mean_T > 0, mean_WF > 0, mean_Rx > 0) %>%
  mutate(n = NA_real_)  # pixel counts not available in HUC12 CSVs

cat("HUC12 zones joined:", nrow(huc12), "\n")

# -- EcoMapProvince x Forest Type --------------------------------------------

eco_T <- read_csv(
  file.path(zonal_dir, "S_USA.EcoMapProvinces_fortypcd_Tratio.csv"),
  show_col_types = FALSE
) %>%
  rename(province = zone_id, fortype = category,
         mean_T = mean, sd_T = sd, median_T = median, n = n)

eco_WF <- read_csv(
  file.path(zonal_dir, "S_USA.EcoMapProvinces_fortypcd_WFCarbon.csv"),
  show_col_types = FALSE
) %>%
  rename(province = zone_id, fortype = category,
         mean_WF = mean, sd_WF = sd, median_WF = median)

eco_Rx <- read_csv(
  file.path(zonal_dir, "S_USA.EcoMapProvinces_fortypcd_RxCarbon.csv"),
  show_col_types = FALSE
) %>%
  rename(province = zone_id, fortype = category,
         mean_Rx = mean, sd_Rx = sd, median_Rx = median)

eco <- eco_T %>%
  inner_join(eco_WF %>% select(province, fortype, mean_WF, sd_WF), by = c("province", "fortype")) %>%
  inner_join(eco_Rx %>% select(province, fortype, mean_Rx, sd_Rx), by = c("province", "fortype")) %>%
  filter(!is.na(mean_T), !is.na(mean_WF), !is.na(mean_Rx),
         mean_T > 0, mean_WF > 0, mean_Rx > 0,
         n > 1)

cat("Eco x ForType rows joined:", nrow(eco), "\n")

# ============================================================================
# 2. Core decomposition function
# ============================================================================

# Applies the log decomposition to a data frame that has:
#   mean_T, mean_WF, mean_Rx
#   (optionally n, for weighted reference means)
#
# Returns the input data frame with decomposition columns appended.

log_decompose <- function(df, n_col = NULL, scale_label = "") {

  # Log-transform zone means
  df <- df %>%
    mutate(
      log_T  = log(mean_T),
      log_WF = log(mean_WF),
      log_Rx = log(mean_Rx),
      # Additivity residual: how far log(T) departs from log(Rx) - log(WF)
      # due to Jensen's inequality at the zonal mean scale
      jensen_residual = log_T - (log_Rx - log_WF)
    )

  cat("\n--- Jensen's inequality diagnostic for", scale_label, "---\n")
  cat("  Residual (log_T - [log_Rx - log_WF]):\n")
  cat("    mean =", round(mean(df$jensen_residual, na.rm = TRUE), 5), "\n")
  cat("    SD   =", round(sd(df$jensen_residual,   na.rm = TRUE), 5), "\n")
  cat("    max  =", round(max(abs(df$jensen_residual), na.rm = TRUE), 5), "\n")

  # CONUS reference values (unweighted if n unavailable; weighted if n present)
  if (!is.null(n_col) && n_col %in% names(df)) {
    wts <- df[[n_col]]
    ref_log_T  <- weighted.mean(df$log_T,  wts, na.rm = TRUE)
    ref_log_WF <- weighted.mean(df$log_WF, wts, na.rm = TRUE)
    ref_log_Rx <- weighted.mean(df$log_Rx, wts, na.rm = TRUE)
    cat("  Using n-weighted CONUS reference values\n")
  } else {
    ref_log_T  <- mean(df$log_T,  na.rm = TRUE)
    ref_log_WF <- mean(df$log_WF, na.rm = TRUE)
    ref_log_Rx <- mean(df$log_Rx, na.rm = TRUE)
    cat("  Using unweighted CONUS reference values (n unavailable)\n")
  }

  cat("  ref_log_T  =", round(ref_log_T,  4), "\n")
  cat("  ref_log_WF =", round(ref_log_WF, 4), "\n")
  cat("  ref_log_Rx =", round(ref_log_Rx, 4), "\n")

  # Global departures
  df <- df %>%
    mutate(
      d_logT  = log_T  - ref_log_T,
      d_logWF = log_WF - ref_log_WF,
      d_logRx = log_Rx - ref_log_Rx,

      # Pulls: contribution of each component to the T departure
      rx_pull = d_logRx,        # positive = Rx above mean (elevates T)
      wf_pull = -d_logWF,       # positive = WF below mean (elevates T)
      # Verify: rx_pull + wf_pull == d_logT (up to Jensen residual)

      # Relative influence of Rx vs. WF in driving the T departure
      total_pull_abs = abs(rx_pull) + abs(wf_pull),
      rx_frac = if_else(total_pull_abs > 0, rx_pull / total_pull_abs, NA_real_),
      wf_frac = if_else(total_pull_abs > 0, wf_pull / total_pull_abs, NA_real_),

      # Driver classification
      driver = case_when(
        total_pull_abs == 0                          ~ "None",
        abs(rx_pull) > abs(wf_pull) * (1 + MIXED_THRESHOLD) ~ "Rx",
        abs(wf_pull) > abs(rx_pull) * (1 + MIXED_THRESHOLD) ~ "WF",
        TRUE                                         ~ "Mixed"
      ),

      T_direction = if_else(d_logT >= 0, "above_mean", "below_mean"),

      # Reinforcing = pulls in the same direction (both push T same way)
      # Opposing = pulls in opposite directions (one up, one down)
      reinforcing = (rx_pull >= 0) == (wf_pull >= 0)
    )

  # Attach reference values as attributes for use in downstream scripts
  attr(df, "ref_log_T")  <- ref_log_T
  attr(df, "ref_log_WF") <- ref_log_WF
  attr(df, "ref_log_Rx") <- ref_log_Rx

  df
}

# ============================================================================
# 3. Apply decomposition
# ============================================================================

huc12_decomp <- log_decompose(huc12, n_col = NULL, scale_label = "HUC12")
eco_decomp   <- log_decompose(eco,   n_col = "n",  scale_label = "Eco x ForType")

# ============================================================================
# 4. Driver classification summary diagnostics
# ============================================================================

summarize_drivers <- function(df, scale_label) {
  cat("\n--- Driver classification summary:", scale_label, "---\n")

  driver_counts <- df %>%
    count(driver, T_direction) %>%
    mutate(pct = round(100 * n / sum(n), 1))
  print(driver_counts)

  cat("\nReinforcing vs. opposing:\n")
  df %>%
    count(reinforcing) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    print()
}

summarize_drivers(huc12_decomp, "HUC12")
summarize_drivers(eco_decomp,   "Eco x ForType")

# ============================================================================
# 5. Variance decomposition at each scale
# ============================================================================

# Var(log T) = Var(log Rx) + Var(log WF) - 2*Cov(log Rx, log WF)
# Reports each component's contribution to total variance in log(T).

variance_decomp <- function(df, scale_label) {
  d <- df %>% filter(!is.na(log_T), !is.na(log_Rx), !is.na(log_WF))

  var_logT  <- var(d$log_T)
  var_logRx <- var(d$log_Rx)
  var_logWF <- var(d$log_WF)
  cov_RxWF  <- cov(d$log_Rx, d$log_WF)

  # Verify: var_logRx + var_logWF - 2*cov == var_logT (up to Jensen residual)
  recon      <- var_logRx + var_logWF - 2 * cov_RxWF

  tibble(
    scale           = scale_label,
    var_logT        = var_logT,
    var_logRx       = var_logRx,
    var_logWF       = var_logWF,
    cov_logRx_logWF = cov_RxWF,
    recon_check     = recon,         # should ≈ var_logT
    pct_from_Rx     = 100 * var_logRx / var_logT,
    pct_from_WF     = 100 * var_logWF / var_logT,
    pct_cov_term    = 100 * (-2 * cov_RxWF) / var_logT
    # pct_from_Rx + pct_from_WF + pct_cov_term = 100 (by definition)
  )
}

var_decomp_table <- bind_rows(
  variance_decomp(huc12_decomp, "HUC12"),
  variance_decomp(eco_decomp,   "Eco x ForType")
)

cat("\n--- Variance decomposition ---\n")
print(var_decomp_table)

# ============================================================================
# 6. Save outputs
# ============================================================================

# Select and order output columns for HUC12
huc12_out <- huc12_decomp %>%
  select(
    zone_id,
    mean_T, mean_WF, mean_Rx,
    log_T, log_WF, log_Rx,
    jensen_residual,
    d_logT, d_logWF, d_logRx,
    rx_pull, wf_pull,
    total_pull_abs, rx_frac, wf_frac,
    driver, T_direction, reinforcing
  )

write_csv(huc12_out, file.path(out_csv_dir, "huc12_logdecomp.csv"))
cat("\nHUC12 decomposition written:", nrow(huc12_out), "zones\n")

# Eco x ForType
eco_out <- eco_decomp %>%
  select(
    province, fortype, n,
    mean_T, mean_WF, mean_Rx,
    log_T, log_WF, log_Rx,
    jensen_residual,
    d_logT, d_logWF, d_logRx,
    rx_pull, wf_pull,
    total_pull_abs, rx_frac, wf_frac,
    driver, T_direction, reinforcing
  )

write_csv(eco_out, file.path(out_csv_dir, "ecofortype_logdecomp.csv"))
cat("Eco x ForType decomposition written:", nrow(eco_out), "rows\n")

# Variance decomposition table
write_csv(var_decomp_table, file.path(out_csv_dir, "variance_decomp_zonal.csv"))
cat("Variance decomposition written.\n")

cat("\nScript 2 complete. Outputs written to:", out_csv_dir, "\n")
cat("Next step: review scale_variation_summary.csv from Script 1 to confirm\n")
cat("reference scale, then proceed to Script 3 (raster decomposition).\n")
