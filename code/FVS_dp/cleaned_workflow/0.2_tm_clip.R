#### 0.2_tm_clip.R
#### Pre-processes TreeMap raster by cropping to each FVS variant boundary.
#### Outputs: Individual cropped TM rasters to data/tm_clip_rasters/tm_ref_{VARIANT}.tif
#### Run once before 3.0, 3.1 to avoid redundant memory-intensive crops in loops.

## ---- Configuration ----
library(here)
source(here("code/FVS_dp/cleaned_workflow/0.0_setup.R"))

# TreeMap raster (pixel -> TreeMap StandID)
tm_path <- "data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif"

# FVS variant boundaries shapefile
variant_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVSVariantMap20210525/FVS_Variants_and_Locations.shp"

## ---- Setup ----

# Load variant boundaries to get list of variants
variants_vect <- vect(variant_path)

# Output directory (shared across all runs)
outdir_root <- here("data/tm_clip_rasters")
dir.create(outdir_root, showWarnings = FALSE)

# All unique variants to process
all_variants <- unique(variants_vect$FVSVariant)

## ---- Crop and write per-variant rasters (parallelized) ----

# Function to process a single variant
# Rasters are loaded independently within each worker process
process_variant <- function(variant, tm_path_input, variant_path_input, output_root) {
  
  message("Processing variant: ", variant)
  
  # Load raster and variants within worker process
  tm.ras <- terra::rast(tm_path_input)
  terra::activeCat(tm.ras) <- 8  # verify column index for TMFM2020_FVSVariant_Key.tif
  
  variants_vect_local <- terra::vect(variant_path_input) %>%
    terra::project(terra::crs(tm.ras))
  
  # Crop to variant boundary
  variant_poly <- variants_vect_local[variants_vect_local$FVSVariant == variant, ]
  tm.clip      <- terra::crop(tm.ras,
                              variant_poly,
                              mask = TRUE)
  
  # Write cropped raster
  tm.clip.path <- file.path(output_root, paste0("tm_ref_", variant, ".tif"))
  terra::writeRaster(tm.clip,
                     tm.clip.path,
                     overwrite = TRUE)
  
  message("Variant ", variant, " complete.")
  
  return(tm.clip.path)
}

# Parallel execution
future::plan(future.callr::callr, workers = parallel::detectCores() - 2)
furrr::future_map(all_variants, 
                  ~ process_variant(., tm_path, variant_path, outdir_root),
                  .progress = TRUE)

message("TreeMap clipping complete. Output directory: ", outdir_root)
