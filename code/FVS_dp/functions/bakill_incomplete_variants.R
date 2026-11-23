#### bakill_incomplete_variants.R
#### Helpers to find FVS variants with missing/empty Bakill rasters after
#### 3.0 (wildfire) or 3.1 (Rx), so only those variants are rerun.
#### Completeness = every expected file exists and is non-empty (contents are not validated).

library(here)
library(dplyr)
library(purrr)
library(stringr)
library(tibble)


# Files expected in each variant folder for a given stage
bakill_expected_files <- function(
    stage,                               # "3.0" (wildfire) or "3.1" (Rx) (character)
    metrics   = c("BAkill", "PctBAkill"),  # metrics rasterized (character vector)
    fl_levels = c(1, 3, 5, 7, 10, 20)      # flame length bins (numeric vector)
) {

  stage <- match.arg(stage, c("3.0", "3.1"))

  if (stage == "3.0") {
    c(paste0("Conditional_", rep(c("mean", "sd", "cv"), times = length(metrics)),
             "_", rep(metrics, each = 3), ".tif"),
      paste0(rep(metrics, each = length(fl_levels)), "_FL", fl_levels, ".tif"))
  } else {
    # 90p ratio is excluded: it is commented out in 3.1
    c(paste0("Rx_", metrics, ".tif"),
      paste0("Rx_WF_", metrics, "_ratio.tif"))
  }
}


# Per-variant completeness table for one stage
check_bakill_variants <- function(
    stage,                               # "3.0" or "3.1" (character)
    run_name,                            # FVS run being rasterized: wildfire run for 3.0, Rx run for 3.1 (character)
    wf_run_name = NULL,                  # wildfire run providing Conditional_mean rasters; required for 3.1 (character)
    metrics     = c("BAkill", "PctBAkill"),  # metrics rasterized (character vector)
    fl_levels   = c(1, 3, 5, 7, 10, 20)      # flame length bins (numeric vector)
) {

  stage <- match.arg(stage, c("3.0", "3.1"))
  if (stage == "3.1" && is.null(wf_run_name)) stop("wf_run_name is required for stage 3.1")

  # non-empty file check, vectorized
  file_ok <- function(
      paths  # file paths (character vector)
  ) {
    sz <- file.size(paths)
    !is.na(sz) & sz > 0
  }

  variants <- list.files(here("FVS_runs/full", run_name, "outputs")) %>%
    str_sub(-5, -4) %>%
    unique() %>%
    sort()

  expected <- bakill_expected_files(stage, metrics, fl_levels)
  out_root <- here("data/dp_FVS_postprocess", run_name)

  map_dfr(variants, function(
      variant  # FVS variant code, e.g. "PN" (character)
  ) {
    present <- file_ok(file.path(out_root, variant, expected))

    # 3.1 divides by the wildfire conditional means, so they must exist first
    ready <- if (stage == "3.0") {
      TRUE
    } else {
      all(file_ok(file.path(here("data/dp_FVS_postprocess", wf_run_name), variant,
                            paste0("Conditional_mean_", metrics, ".tif"))))
    }

    tibble(variant    = variant,
           n_expected = length(expected),
           n_missing  = sum(!present),
           missing    = paste(expected[!present], collapse = ", "),
           ready      = ready)
  })
}


# Variants to (re)run: incomplete and, for 3.1, with wildfire inputs available
incomplete_bakill_variants <- function(
    stage,                               # "3.0" or "3.1" (character)
    run_name,                            # FVS run being rasterized (character)
    wf_run_name = NULL,                  # wildfire run for Conditional_mean inputs; required for 3.1 (character)
    metrics     = c("BAkill", "PctBAkill"),  # metrics rasterized (character vector)
    fl_levels   = c(1, 3, 5, 7, 10, 20)      # flame length bins (numeric vector)
) {

  status <- check_bakill_variants(stage, run_name, wf_run_name, metrics, fl_levels)

  incomplete <- filter(status, n_missing > 0)
  blocked    <- filter(incomplete, !ready)
  to_run     <- filter(incomplete, ready)

  message("Stage ", stage, ": ", nrow(status) - nrow(incomplete), " of ", nrow(status),
          " variants complete; rerunning ", nrow(to_run), ": ",
          paste(to_run$variant, collapse = ", "))

  if (nrow(blocked) > 0) {
    message("Skipping (wildfire 3.0 rasters not ready): ",
            paste(blocked$variant, collapse = ", "))
  }

  to_run$variant
}
