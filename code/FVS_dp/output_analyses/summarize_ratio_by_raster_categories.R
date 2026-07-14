# Summarize ratio raster across categorical raster pixel groups
# Returns summary table with one row per category
# Optimized for large CONUS-scale rasters

library(tidyverse)
library(terra)

# ============================================================================
# 1. Load and prepare inputs (memory-efficient)
# ============================================================================

# Load ratio raster
ratio_raster <- terra::rast("path/to/ratio_raster.tif")

# Load categorical raster
categorical_raster <- terra::rast("path/to/categorical_raster.tif")

# Check alignment; resample only if necessary
if (!identical(terra::ext(ratio_raster), terra::ext(categorical_raster)) ||
    !identical(terra::res(ratio_raster), terra::res(categorical_raster))) {
  categorical_raster <- terra::resample(categorical_raster, ratio_raster, method = "near")
}


# ============================================================================
# 2. Process by blocks to avoid loading entire raster into memory
# ============================================================================

# Initialize summary statistics list
category_stats <- list()

# Process raster by blocks (adjust block size based on available RAM)
block_size <- 1000  # rows per block; adjust downward if memory constrained

for (block_idx in seq_len(terra::nrow(ratio_raster) %/% block_size + 1)) {
  # Define block boundaries
  row_start <- (block_idx - 1) * block_size + 1
  row_end <- min(block_idx * block_size, terra::nrow(ratio_raster))
  
  # Read block of both rasters
  ratio_block <- terra::readValues(
    ratio_raster,
    row = row_start,
    nrows = row_end - row_start + 1
  )
  cat_block <- terra::readValues(
    categorical_raster,
    row = row_start,
    nrows = row_end - row_start + 1
  )
  
  # Create temporary data frame for this block
  block_df <- data.frame(
    ratio = as.vector(ratio_block),
    category = as.vector(cat_block)
  ) %>%
    filter(!is.na(ratio) & !is.na(category))
  
  # Store block summary
  category_stats[[block_idx]] <- block_df
  
  if (block_idx %% 10 == 0) {
    cat("Processed block", block_idx, "of", terra::nrow(ratio_raster) %/% block_size + 1, "\n")
  }
}

# Combine all blocks
df <- bind_rows(category_stats)


# ============================================================================
# 3. Compute summary statistics by category
# ============================================================================

category_summaries <- df %>%
  group_by(category) %>%
  summarise(
    mean = mean(ratio, na.rm = TRUE),
    median = median(ratio, na.rm = TRUE),
    sd = sd(ratio, na.rm = TRUE),
    n_pixels = n(),
    .groups = "drop"
  ) %>%
  arrange(category)


# ============================================================================
# 4. Inspect and save results
# ============================================================================

# View results
print(category_summaries)

# Save to CSV
write_csv(category_summaries, "path/to/output_category_summaries.csv")

# Clean up
rm(df, category_stats)
