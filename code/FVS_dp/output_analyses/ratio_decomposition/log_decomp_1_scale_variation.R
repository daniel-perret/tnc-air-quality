# log_decomp_1_scale_variation.R
#
# Analyzes how much variation in the T ratio (Rx:WF carbon emissions) is captured
# between zones vs. within zones at five spatial/ecological scales:
#   HUC8, HUC10, HUC12, Firesheds, EcoMapProvince x Forest Type
#
# Computes pseudo-ICC (intraclass correlation) at each scale to inform which
# reference level should be used for departure calculations in Script 2.
#
# Note on weighting: HUC and fireshed CSVs do not include pixel counts (n),
# so ICC is computed unweighted for those scales. The eco x fortype CSVs
# include n, enabling n-weighted ICC.
#
# Inputs:
#   data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/*.csv
#
# Outputs:
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/scale_variation_summary.csv
#   outputs/ratio_decomposition/scale_variation_ICC.png
#   outputs/ratio_decomposition/zone_mean_distributions.png
#   outputs/ratio_decomposition/ecofortype_heatmap.png

library(tidyverse)

# ============================================================================
# 0. Paths
# ============================================================================

zonal_dir   <- "data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries"
out_csv_dir <- "data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries"
out_fig_dir <- "outputs/ratio_decomposition"

dir.create(out_csv_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(out_fig_dir, showWarnings = FALSE, recursive = TRUE)

# ============================================================================
# 1. Load and standardize zonal T ratio CSVs
# ============================================================================

# All files: zone_id | mean | sd | (n if available)
# sd column is named "sd" in output from summarize_ratio_by_polygons.R

huc8 <- read_csv(
  file.path(zonal_dir, "huc8_Tratio.csv"), show_col_types = FALSE
) %>%
  rename(zone_id = HUC8) %>%
  mutate(scale = "HUC8", n = NA_real_) %>%
  select(zone_id, scale, mean, sd, n)

huc10 <- read_csv(
  file.path(zonal_dir, "huc10_Tratio.csv"), show_col_types = FALSE
) %>%
  rename(zone_id = huc10) %>%
  mutate(scale = "HUC10", n = NA_real_) %>%
  select(zone_id, scale, mean, sd, n)

huc12 <- read_csv(
  file.path(zonal_dir, "huc12_Tratio.csv"), show_col_types = FALSE
) %>%
  rename(zone_id = huc12) %>%
  mutate(scale = "HUC12", n = NA_real_) %>%
  select(zone_id, scale, mean, sd, n)

firesheds <- read_csv(
  file.path(zonal_dir, "firesheds_Tratio.csv"), show_col_types = FALSE
) %>%
  rename(zone_id = ID) %>%
  mutate(scale = "Fireshed", n = NA_real_,
         zone_id = as.character(zone_id)) %>%
  select(zone_id, scale, mean, sd, n)

# Eco x fortype: zone_id = province code, category = forest type code
eco_T <- read_csv(
  file.path(zonal_dir, "S_USA.EcoMapProvinces_fortypcd_Tratio.csv"),
  show_col_types = FALSE
) %>%
  rename(province = zone_id, fortype = category) %>%
  # Exclude any rows with NA mean (no data for that province x fortype combination)
  filter(!is.na(mean), !is.na(sd), n > 1)

# Flat version of eco x fortype for the combined distribution plot
eco_T_flat <- eco_T %>%
  mutate(zone_id = paste0(province, "_", fortype),
         scale   = "Eco x ForType") %>%
  select(zone_id, scale, mean, sd, n)

# ============================================================================
# 2. ICC helper functions
# ============================================================================

# Unweighted ICC (for scales without pixel counts)
# B = var(zone_means), W = mean(zone_sd^2)
# ICC = B / (B + W)
icc_unweighted <- function(df, scale_name) {
  df <- df %>% filter(!is.na(mean), !is.na(sd), sd >= 0)

  mu  <- df$mean
  sig <- df$sd

  n_zones  <- length(mu)
  mu_bar   <- mean(mu)
  B        <- var(mu)
  W        <- mean(sig^2)
  ICC      <- B / (B + W)
  CV_btwn  <- sd(mu) / abs(mu_bar)

  tibble(
    scale        = scale_name,
    n_zones      = n_zones,
    mean_T       = mu_bar,
    sd_zone_means = sd(mu),
    CV_between   = CV_btwn,
    B_between    = B,
    W_within     = W,
    ICC          = ICC,
    weighted     = FALSE
  )
}

# Weighted ICC (for eco x fortype, where n is available)
# B = weighted variance of zone means, W = weighted mean of zone variances
icc_weighted <- function(df, scale_name) {
  df <- df %>% filter(!is.na(mean), !is.na(sd), !is.na(n), n > 1, sd >= 0)

  mu  <- df$mean
  sig <- df$sd
  n   <- df$n

  n_zones  <- nrow(df)
  mu_bar   <- weighted.mean(mu, n)
  B        <- sum(n * (mu - mu_bar)^2) / (sum(n) - 1)
  W        <- sum(n * sig^2) / sum(n)
  ICC      <- B / (B + W)
  CV_btwn  <- sqrt(B) / abs(mu_bar)

  tibble(
    scale         = scale_name,
    n_zones       = n_zones,
    mean_T        = mu_bar,
    sd_zone_means = sqrt(B),
    CV_between    = CV_btwn,
    B_between     = B,
    W_within      = W,
    ICC           = ICC,
    weighted      = TRUE
  )
}

# ============================================================================
# 3. Compute ICCs for each scale
# ============================================================================

icc_huc8      <- icc_unweighted(huc8,      "HUC8")
icc_huc10     <- icc_unweighted(huc10,     "HUC10")
icc_huc12     <- icc_unweighted(huc12,     "HUC12")
icc_firesheds <- icc_unweighted(firesheds, "Fireshed")
icc_ecofortype <- icc_weighted(eco_T_flat, "Eco x ForType")

# ============================================================================
# 4. Eco x ForType two-way decomposition
# ============================================================================

# Province-level marginal means (aggregate across fortypes within each province)
province_margins <- eco_T %>%
  group_by(province) %>%
  summarise(
    n_tot         = sum(n),
    mean_T        = weighted.mean(mean, n),
    # Pooled within-fortype variance for this province
    W_within_prov = sum(n * sd^2) / sum(n),
    .groups = "drop"
  ) %>%
  filter(!is.na(mean_T))

icc_province <- icc_weighted(
  province_margins %>% transmute(mean = mean_T, sd = sqrt(W_within_prov), n = n_tot),
  "Eco Province"
)

# Forest-type-level marginal means (aggregate across provinces within each fortype)
fortype_margins <- eco_T %>%
  group_by(fortype) %>%
  summarise(
    n_tot        = sum(n),
    mean_T       = weighted.mean(mean, n),
    W_within_ft  = sum(n * sd^2) / sum(n),
    .groups = "drop"
  ) %>%
  filter(!is.na(mean_T))

icc_fortype <- icc_weighted(
  fortype_margins %>% transmute(mean = mean_T, sd = sqrt(W_within_ft), n = n_tot),
  "Forest Type"
)

# ============================================================================
# 5. Collate and save scale variation summary
# ============================================================================

scale_summary <- bind_rows(
  icc_huc8,
  icc_huc10,
  icc_huc12,
  icc_firesheds,
  icc_ecofortype,
  icc_province,
  icc_fortype
) %>%
  arrange(desc(ICC))

write_csv(
  scale_summary,
  file.path(out_csv_dir, "scale_variation_summary.csv")
)

cat("Scale variation summary (sorted by ICC):\n")
print(scale_summary, n = Inf)

# ============================================================================
# 6. Visualizations
# ============================================================================

# Shared scale ordering (primary 5 scales, ranked by ICC)
primary_scales <- scale_summary %>%
  pull(scale)

# -- 6a. ICC bar chart -------------------------------------------------------

p_icc <- scale_summary %>%
  mutate(
    scale = factor(scale, levels = rev(primary_scales)),
    weighted_label = if_else(weighted, "(n-weighted)", "(unweighted)")
  ) %>%
  ggplot(aes(x = ICC, y = scale)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = round(ICC, 3)), hjust = -0.15, size = 3.2) +
  scale_x_continuous(
    limits = c(0, 1),
    labels = scales::label_number(accuracy = 0.01),
    expand = expansion(mult = c(0, 0.08))
  ) +
  labs(
    x        = "Pseudo-ICC  (between-zone variance / total variance)",
    y        = NULL,
    title    = "Proportion of T ratio variance explained by zone membership",
    subtitle = "ICC closer to 1 = zones are more internally homogeneous; HUC/fireshed ICCs are unweighted"
  ) +
  theme(panel.grid.major.y = element_blank())

p_icc

ggsave(
  file.path(out_fig_dir, "scale_variation_ICC.png"),
  p_icc, width = 7, height = 4, dpi = 200
)

# -- 6b. Distribution of zone means at each scale ----------------------------

all_scales_long <- bind_rows(
  huc8      %>% select(zone_id, mean, scale),
  huc10     %>% select(zone_id, mean, scale),
  huc12     %>% select(zone_id, mean, scale),
  firesheds %>% select(zone_id, mean, scale),
  eco_T_flat %>% select(zone_id, mean, scale)
) %>%
  # Truncate extreme values for display (keep 1st–99th percentile per scale)
  group_by(scale) %>%
  filter(
    mean >= quantile(mean, 0.01, na.rm = TRUE),
    mean <= quantile(mean, 0.99, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(scale = factor(scale, levels = primary_scales))

p_dists <- ggplot(all_scales_long, aes(x = mean)) +
  geom_histogram(bins = 80, fill = "steelblue4", color = NA, alpha = 0.8) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "firebrick", linewidth = 0.5) +
  facet_wrap(~scale, ncol = 1, scales = "free_y") +
  labs(
    x        = "Zone mean T (Rx:WF carbon ratio)",
    y        = "Number of zones",
    title    = "Distribution of T across spatial scales"
  ) +
  #theme_minimal(base_size = 11) +
  theme(strip.text = element_text(face = "bold"))

p_dists

ggsave(
  file.path(out_fig_dir, "zone_mean_distributions.png"),
  p_dists, width = 7, height = 10, dpi = 200
)

cat("\nScript 1 complete.\n")
cat("  CSVs  ->", out_csv_dir, "\n")
cat("  Plots ->", out_fig_dir, "\n")
