# FVS Decay Rates Figure
# Creates a four-panel heatmap showing annual decay rates by decay class and fuel size
# One panel per decay class, with all variants displayed in consistent order across panels

library(tidyverse)
library(ggplot2)
library(patchwork)

# Read the decay rates data
decay_data <- read_csv("data/fve_ffe_decay_rates_all_variants.csv")

# Consistent variant order (high to low overall mean decay rate)
variant_order <- c("NE", "SN", "WC", "CS", "LS", "BM", "EC", "PN", "SO", "CA", 
                   "EM", "IE", "CI", "AK", "TT", "UT", "CR", "NC", "WS")

# Step 1: For variants with NA decay_class, replicate their values across all decay classes 1-4
heatmap_data_processed <- decay_data %>%
  # Exclude Duff
  filter(size_class != "Duff") %>%
  # For rows with NA decay_class, create 4 copies (one for each decay class)
  mutate(
    decay_class = case_when(
      is.na(decay_class) ~ NA_real_,  # Keep as NA for now, will expand below
      TRUE ~ decay_class
    )
  ) %>%
  # Split into two groups: with and without decay_class
  {
    with_dc <- filter(., !is.na(decay_class))
    without_dc <- filter(., is.na(decay_class)) %>%
      select(-decay_class) %>%
      expand_grid(decay_class = 1:4)  # Replicate across all decay classes
    
    bind_rows(with_dc, without_dc)
  } %>%
  group_by(variant, decay_class, size_class) %>%
  summarise(
    mean_decay_rate = mean(annual_loss_rate, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    variant = factor(variant, levels = variant_order, ordered = TRUE),
    # Litter first, then woody fuels in size order
    size_class = factor(size_class, 
      levels = c("Litter", "<0.25\"", "0.25-1\"", "1-3\"", "3-6\"", "6-12\"", ">12\""),
      ordered = TRUE)
  )

# Step 2: Create complete grid with all variants, all decay classes, all size classes
complete_grid <- expand_grid(
  variant = factor(variant_order, levels = variant_order, ordered = TRUE),
  decay_class = 1:4,
  size_class = factor(c("Litter", "<0.25\"", "0.25-1\"", "1-3\"", "3-6\"", "6-12\"", ">12\""),
                     levels = c("Litter", "<0.25\"", "0.25-1\"", "1-3\"", "3-6\"", "6-12\"", ">12\""),
                     ordered = TRUE)
) %>%
  left_join(heatmap_data_processed, by = c("variant", "decay_class", "size_class"))

# Step 3: Function to create individual heatmaps for each decay class
make_decay_heatmap <- function(dc) {
  data_subset <- complete_grid %>%
    filter(decay_class == dc)
  
  ggplot(data_subset, aes(x = size_class, y = variant, fill = mean_decay_rate)) +
    geom_tile(color = "white", linewidth = 0.3) +
    scale_fill_gradient(low = "white", high = "darkred", name = "Decay Rate",
                       limits = c(0, max(heatmap_data_processed$mean_decay_rate, na.rm = TRUE))) +
    labs(
      title = paste("Decay Class", dc),
      x = "Fuel Size Class",
      y = "Variant"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
      axis.text.y = element_text(size = 8),
      plot.title = element_text(size = 12, face = "bold"),
      axis.title = element_text(size = 10),
      legend.position = "right",
      legend.key.size = unit(0.4, "cm"),
      legend.text = element_text(size = 7)
    )
}

# Step 4: Create all four heatmaps
p1 <- make_decay_heatmap(1)
p2 <- make_decay_heatmap(2)
p3 <- make_decay_heatmap(3)
p4 <- make_decay_heatmap(4)

# Step 5: Combine into a 2x2 grid
combined <- (p1 + p2) / (p3 + p4) +
  plot_annotation(
    title = "Annual Decay Rates by Decay Class and Fuel Size",
    subtitle = "Averaged across climate conditions; variants without decay classes replicated across all panels",
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 11, hjust = 0.5)
    )
  ) +
  plot_layout(guides = "collect")

# Step 6: Save to figures directory
ggsave("figures/decay_rates_by_decay_class.png", 
       plot = combined, width = 14, height = 13, dpi = 300)

cat("✓ Created figures/decay_rates_by_decay_class.png\n")
