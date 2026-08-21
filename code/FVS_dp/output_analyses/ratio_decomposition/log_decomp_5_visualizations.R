# log_decomp_5_visualizations.R
#
# Produces all figures for the log-decomposition analysis:
#
#   1. rx_pull vs. wf_pull biplot (zone level, faceted by scale)
#   2. Driver classification choropleth map (HUC12)
#   3. rx_frac distribution by eco province
#   4. Variance decomposition stacked bar chart (by scale)
#   5. Scatter of d_logT vs. d_logRx and d_logWF (faceted)
#
# Inputs:
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/huc12_logdecomp.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/ecofortype_logdecomp.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/huc12_decomp_summary.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/firesheds_decomp_summary.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/ecoprovince_decomp_summary.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/variance_decomp_by_scale.csv
#   data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries/scale_variation_summary.csv
#   Zone polygon shapefiles (for map)
#
# Outputs (all in outputs/ratio_decomposition/):
#   rxpull_wfpull_biplot.png
#   driver_class_map_huc12.png
#   rx_frac_by_province.png
#   variance_decomp_bar.png
#   dlogT_vs_components.png

library(tidyverse)
library(sf)

out_fig_dir <- "outputs/ratio_decomposition"
out_csv_dir <- "data/dp_FVS_postprocess/ratio_decomposition/zonal_summaries"
dir.create(out_fig_dir, showWarnings = FALSE, recursive = TRUE)

# ============================================================================
# 0. Load inputs
# ============================================================================

huc12_zonal   <- read_csv(file.path(out_csv_dir, "huc12_logdecomp.csv"),      show_col_types = FALSE)
eco_zonal     <- read_csv(file.path(out_csv_dir, "ecofortype_logdecomp.csv"), show_col_types = FALSE)
huc12_raster  <- read_csv(file.path(out_csv_dir, "huc12_decomp_summary.csv"), show_col_types = FALSE)
fireshed_rast <- read_csv(file.path(out_csv_dir, "firesheds_decomp_summary.csv"), show_col_types = FALSE)
eco_raster    <- read_csv(file.path(out_csv_dir, "ecoprovince_decomp_summary.csv"), show_col_types = FALSE)
var_decomp    <- read_csv(file.path(out_csv_dir, "variance_decomp_by_scale.csv"),  show_col_types = FALSE)
scale_summary <- read_csv(file.path(out_csv_dir, "scale_variation_summary.csv"),   show_col_types = FALSE)

# Driver class color palette (consistent across all plots)
driver_colors <- c(
  "Rx-dominant, above mean"  = "#2166ac",
  "WF-dominant, above mean"  = "#d6604d",
  "Rx-dominant, below mean"  = "#92c5de",
  "WF-dominant, below mean"  = "#f4a582",
  "Mixed"                    = "#d9d9d9"
)

# ============================================================================
# 1. Rx-pull vs. WF-pull biplot (zonal means from Script 2 CSV data)
# ============================================================================

# Combine HUC12 and eco x fortype into a single long frame for faceting
biplot_data <- bind_rows(
  huc12_zonal %>%
    select(zone_id, rx_pull, wf_pull, driver, T_direction, reinforcing) %>%
    mutate(scale = "HUC12"),
  eco_zonal %>%
    mutate(zone_id = paste0(province, "_", fortype)) %>%
    select(zone_id, rx_pull, wf_pull, driver, T_direction, reinforcing) %>%
    mutate(scale = "Eco x ForType")
) %>%
  filter(!is.na(rx_pull), !is.na(wf_pull)) %>%
  # Truncate extremes for display
  group_by(scale) %>%
  filter(
    rx_pull >= quantile(rx_pull, 0.005),
    rx_pull <= quantile(rx_pull, 0.995),
    wf_pull >= quantile(wf_pull, 0.005),
    wf_pull <= quantile(wf_pull, 0.995)
  ) %>%
  ungroup() %>%
  mutate(
    driver_label = case_when(
      driver == "Rx"    & T_direction == "above_mean" ~ "Rx-dominant, above mean",
      driver == "WF"    & T_direction == "above_mean" ~ "WF-dominant, above mean",
      driver == "Rx"    & T_direction == "below_mean" ~ "Rx-dominant, below mean",
      driver == "WF"    & T_direction == "below_mean" ~ "WF-dominant, below mean",
      TRUE                                            ~ "Mixed"
    ),
    driver_label = factor(driver_label, levels = names(driver_colors))
  )

p_biplot <- ggplot(biplot_data, aes(x = wf_pull, y = rx_pull, color = driver_label)) +
  geom_point(size = 0.6, alpha = 0.5, shape = 16) +
  geom_hline(yintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "grey40") +
  geom_abline(slope = -1, intercept = 0,
              linewidth = 0.4, linetype = "dotted", color = "grey40") +
  scale_color_manual(values = driver_colors, name = "Driver class") +
  facet_wrap(~scale, scales = "free") +
  labs(
    x        = "WF-pull  [−δ log(WF)]",
    y        = "Rx-pull  [δ log(Rx)]",
    title    = "Additive contributions of Rx and WF to T ratio departures",
    subtitle = "Dotted line: equal magnitude; upper-left = WF-dominated; lower-right = Rx-dominated"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))

ggsave(file.path(out_fig_dir, "rxpull_wfpull_biplot.png"),
       p_biplot, width = 10, height = 5, dpi = 200)

# ============================================================================
# 2. Driver classification choropleth map (HUC12, from raster-derived summary)
# ============================================================================

cat("Loading HUC12 polygons for map...\n")
huc12_polys <- sf::st_read(
  "../../SHARED_DATA/HUC_boundaries/huc12_conus/WBDHU12 selection.shp",
  quiet = TRUE
)

# Determine dominant driver from the raster-derived class proportions
driver_class_cols <- c("pct_Rx_above", "pct_WF_above", "pct_Rx_below",
                        "pct_WF_below", "pct_Mixed")
available_cols <- intersect(driver_class_cols, names(huc12_raster))

huc12_map_data <- huc12_raster %>%
  filter(!is.na(mean_logT)) %>%
  mutate(
    dominant_driver = if_else(
      length(available_cols) > 0,
      apply(select(., all_of(available_cols)), 1,
            function(x) {
              lbl <- available_cols[which.max(x)]
              case_when(
                lbl == "pct_Rx_above" ~ "Rx-dominant, above mean",
                lbl == "pct_WF_above" ~ "WF-dominant, above mean",
                lbl == "pct_Rx_below" ~ "Rx-dominant, below mean",
                lbl == "pct_WF_below" ~ "WF-dominant, below mean",
                TRUE                  ~ "Mixed"
              )
            }),
      NA_character_
    ),
    dominant_driver = factor(dominant_driver, levels = names(driver_colors))
  )

huc12_map_sf <- huc12_polys %>%
  left_join(huc12_map_data, by = c("huc12" = "zone_id"))

# State boundaries for reference
states <- sf::st_read(
  "../../SHARED_DATA/base_spatialdata/state_boundaries/state_boundaries.shp",
  quiet = TRUE
) %>%
  sf::st_transform(sf::st_crs(huc12_map_sf))

p_map <- ggplot() +
  geom_sf(data = huc12_map_sf,
          aes(fill = dominant_driver),
          color = NA, linewidth = 0) +
  geom_sf(data = states,
          fill = NA, color = "white", linewidth = 0.2) +
  scale_fill_manual(
    values   = driver_colors,
    na.value = "grey90",
    name     = "Dominant driver"
  ) +
  labs(
    title    = "Dominant driver of T ratio departure from CONUS mean (HUC12)",
    subtitle = "Classified by majority of pixels within each HUC12 watershed"
  ) +
  theme_void(base_size = 11) +
  theme(
    legend.position  = "bottom",
    legend.direction = "horizontal",
    plot.title       = element_text(face = "bold")
  )

ggsave(file.path(out_fig_dir, "driver_class_map_huc12.png"),
       p_map, width = 12, height = 7, dpi = 200)

# ============================================================================
# 3. rx_frac distribution by eco province
# ============================================================================

# Using the exact (raster-derived) zonal means from Script 4
eco_rxfrac <- eco_raster %>%
  filter(!is.na(mean_rxfrac)) %>%
  # Order provinces by mean_rxfrac for readability
  mutate(province = reorder(zone_id, mean_rxfrac))

p_rxfrac <- ggplot(eco_rxfrac, aes(x = mean_rxfrac, y = province)) +
  geom_point(aes(size = n), alpha = 0.7) +
  geom_errorbarh(
    aes(xmin = mean_rxfrac - sd_rxfrac, xmax = mean_rxfrac + sd_rxfrac),
    height = 0, linewidth = 0.4, alpha = 0.5
  ) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.5) +
  scale_size_continuous(name = "Pixel count", labels = scales::label_comma()) +
  scale_x_continuous(
    limits = c(-1, 1),
    labels = scales::label_number(accuracy = 0.1)
  ) +
  labs(
    x        = "Mean rx_frac  [rx_pull / (|rx_pull| + |wf_pull|)]",
    y        = "Eco province",
    title    = "Rx vs. WF influence on T ratio departure by eco province",
    subtitle = "Positive = Rx is dominant driver; negative = WF is dominant driver; bars = ±1 SD"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.y = element_text(size = 7),
    panel.grid.minor = element_blank()
  )

ggsave(file.path(out_fig_dir, "rx_frac_by_province.png"),
       p_rxfrac, width = 8, height = 10, dpi = 200)

# ============================================================================
# 4. Variance decomposition stacked bar chart
# ============================================================================

var_decomp_long <- var_decomp %>%
  select(scale, pct_from_Rx, pct_from_WF, pct_cov_term) %>%
  tidyr::pivot_longer(
    cols      = c(pct_from_Rx, pct_from_WF, pct_cov_term),
    names_to  = "component",
    values_to = "pct"
  ) %>%
  mutate(
    component = factor(
      component,
      levels = c("pct_from_Rx", "pct_cov_term", "pct_from_WF"),
      labels = c("Rx variance", "Covariance term (−2·Cov)", "WF variance")
    ),
    scale = factor(scale, levels = rev(unique(scale)))
  )

p_vardecomp <- ggplot(var_decomp_long,
                       aes(x = pct, y = scale, fill = component)) +
  geom_col(width = 0.6, position = "stack") +
  geom_vline(xintercept = 100, linetype = "dashed",
             color = "grey30", linewidth = 0.4) +
  scale_fill_manual(
    values = c(
      "Rx variance"               = "#2166ac",
      "Covariance term (−2·Cov)"  = "#d9d9d9",
      "WF variance"               = "#d6604d"
    ),
    name = "Variance component"
  ) +
  scale_x_continuous(
    labels = scales::label_percent(scale = 1),
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    x        = "% of Var(log T) across zones",
    y        = NULL,
    title    = "Variance decomposition: Rx vs. WF contributions to log(T) variation",
    subtitle = "Components sum to 100% by construction; covariance term can be negative"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position  = "bottom",
    panel.grid.major.y = element_blank()
  )

ggsave(file.path(out_fig_dir, "variance_decomp_bar.png"),
       p_vardecomp, width = 8, height = 4, dpi = 200)

# ============================================================================
# 5. Scatter of d_logT vs. d_logRx and d_logWF (faceted)
# ============================================================================

# Use HUC12 zonal data from Script 2 (largest zone count, good coverage)
scatter_data <- huc12_zonal %>%
  filter(!is.na(d_logT), !is.na(d_logRx), !is.na(d_logWF)) %>%
  # Sample for display if large (>50k points)
  {if (nrow(.) > 50000) dplyr::slice_sample(., n = 50000) else .} %>%
  mutate(
    driver_label = case_when(
      driver == "Rx" & T_direction == "above_mean" ~ "Rx-dominant, above mean",
      driver == "WF" & T_direction == "above_mean" ~ "WF-dominant, above mean",
      driver == "Rx" & T_direction == "below_mean" ~ "Rx-dominant, below mean",
      driver == "WF" & T_direction == "below_mean" ~ "WF-dominant, below mean",
      TRUE                                         ~ "Mixed"
    ),
    driver_label = factor(driver_label, levels = names(driver_colors))
  ) %>%
  tidyr::pivot_longer(
    cols      = c(d_logRx, d_logWF),
    names_to  = "component",
    values_to = "component_value"
  ) %>%
  mutate(
    component = factor(
      component,
      levels = c("d_logRx", "d_logWF"),
      labels = c("δ log(Rx)  [Rx component]",
                 "δ log(WF)  [WF component; note: T rises when WF is below mean]")
    )
  )

p_scatter <- ggplot(scatter_data,
                     aes(x = component_value, y = d_logT, color = driver_label)) +
  geom_point(size = 0.4, alpha = 0.3, shape = 16) +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "grey50") +
  geom_vline(xintercept = 0, linewidth = 0.3, color = "grey50") +
  scale_color_manual(values = driver_colors, name = "Driver class") +
  facet_wrap(~component, ncol = 2, scales = "fixed") +
  labs(
    x        = "Component departure from CONUS mean [log scale]",
    y        = "δ log(T)  [T ratio departure from CONUS mean]",
    title    = "δ log(T) vs. Rx and WF component departures (HUC12 zones)",
    subtitle = "Left: correlation with Rx departure; Right: correlation with WF departure"
  ) +
  guides(color = guide_legend(override.aes = list(size = 2, alpha = 1))) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    strip.text      = element_text(face = "bold", size = 9)
  )

ggsave(file.path(out_fig_dir, "dlogT_vs_components.png"),
       p_scatter, width = 11, height = 5.5, dpi = 200)

# ============================================================================
# 6. Summary
# ============================================================================

cat("\nScript 5 complete. Figures written to:", out_fig_dir, "\n")
cat("  rxpull_wfpull_biplot.png\n")
cat("  driver_class_map_huc12.png\n")
cat("  rx_frac_by_province.png\n")
cat("  variance_decomp_bar.png\n")
cat("  dlogT_vs_components.png\n")
