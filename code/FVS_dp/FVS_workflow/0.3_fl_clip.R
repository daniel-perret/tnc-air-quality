#### 0.3_fl_clip.R
#### Pre-processes FlamStat flame length probability rasters by cropping to each FVS variant boundary.
#### Outputs: Individual cropped FL rasters to data/fl_clip_rasters/fl_clip_{VARIANT}.tif
#### Cropped FL rasters are aligned to TreeMap raster extents (from 0.2_tm_clip.R) for seamless stacking.
#### Run once before 3.0 to avoid redundant memory-intensive crops in loop.

## ---- Configuration ----

library(here)
source(here("code/FVS_dp/cleaned_workflow/0.0_setup.R"))

# FlamStat flame length probability rasters directory (pre-treatment baseline)
fl_prob_dir <- "data/flamstat/flamelength_rasters/PreTreatment_CONUS/"

# FVS variant boundaries shapefile
variant_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVSVariantMap20210525/FVS_Variants_and_Locations.shp"

# Pre-clipped TreeMap rasters directory (from 0.2_tm_clip.R) for extent reference
tm_clip_dir <- here("data/tm_clip_rasters")

## ---- Setup ----

# Load variant boundaries to get list of variants
variants_vect <- vect(variant_path)

# Output directory (shared across all runs)
outdir_root <- here("data/fl_clip_rasters")
dir.create(outdir_root, showWarnings = FALSE)

# All unique variants to process
all_variants <- unique(variants_vect$FVSVariant)

# FL probability rasters sorted by ascending FL value
fl_prob_files <- list.files(fl_prob_dir, pattern = "\\.tif$", full.names = TRUE) %>%
  str_subset("Conditional", negate = TRUE) %>%
  str_subset("NoBurn",      negate = TRUE)
fl_prob_files <- fl_prob_files[order(parse_number(basename(fl_prob_files)))]

## ---- Crop and write per-variant rasters (parallelized) ----

# Function to process a single variant
# Rasters are loaded independently within each worker process
process_variant <- function(variant, fl_prob_files_input, variant_path_input, tm_clip_dir_input, output_root) {
  
  message("Processing variant: ", variant)
  
  # Load FL rasters and variants within worker process
  fl.rast <- terra::rast(fl_prob_files_input)
  
  variants_vect_local <- terra::vect(variant_path_input) %>%
    terra::project(terra::crs(fl.rast))
  
  # Crop to variant boundary
  variant_poly <- variants_vect_local[variants_vect_local$FVSVariant == variant, ]
  fl.clip      <- terra::crop(fl.rast,
                              variant_poly,
                              mask = TRUE)
  
  # Match extent to TreeMap raster for this variant
  tm_ref_path <- file.path(tm_clip_dir_input, paste0("tm_ref_", variant, ".tif"))
  if (file.exists(tm_ref_path)) {
    tm_ref <- terra::rast(tm_ref_path)
    fl.clip <- terra::crop(fl.clip, terra::ext(tm_ref))
  }
  
  # Write cropped raster
  fl.clip.path <- file.path(output_root, paste0("fl_clip_", variant, ".tif"))
  terra::writeRaster(fl.clip,
                     fl.clip.path,
                     overwrite = TRUE)
  
  message("Variant ", variant, " complete.")
  
  return(fl.clip.path)
}

# Parallel execution
future::plan(future.callr::callr, workers = parallel::detectCores() - 2)
furrr::future_map(all_variants, 
                  ~ process_variant(., fl_prob_files, variant_path, tm_clip_dir, outdir_root),
                  .progress = TRUE)
future::plan(sequential)

message("Flame length raster clipping complete. Output directory: ", outdir_root)
