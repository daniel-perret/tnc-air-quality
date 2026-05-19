#### 0.3_initialFVSrun.R
#### This script performs a basic no-treatment, no-fire FVS cycle that calculates canopy fuels variables used in all subsequent emissions calculations.

# Set location of TMFM sqlite databases and read in data
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/"

dbs <- list.files(TMFM2020_dir_path,
                  full.names=TRUE)

# Name the FVS run
run_name <- str_c("NoFireDryRun_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))

# Create a directory for this run.
RunDirectory <- str_c(here(), "/FVS_runs/full/", run_name)
dir.create(RunDirectory)

setwd(paste0(RunDirectory))

log_session_info()

# Write the simulation .key files

write_keywords_fullparallel(database_paths = dbs, 
                            stand_subset = "all", 
                            FSim_scenarios = NA, #rename this var
                            treat_kcps = NA, 
                            fire_kcps = NA,
                            ncycles = 2,
                            interval = 1)

write_keywords_fullparallel_fullmatch(RunDirectory = RunDirectory,
                                      database_paths = dbs, 
                                      stand_subset = "all", 
                                      FSim_scenarios = NA, #rename this var
                                      treat_kcps = NA, 
                                      fire_kcps = NA,
                                      ncycles = 2,
                                      interval = 1,
                                      runtype = "dry",
                                      fbfm = "default",
                                      nworkers = parallel::detectCores()-2)

# Create the data frame of run scenario parameters to parallelize over

variants <- dbs %>% 
  str_sub(., -5,-4) %>% 
  tolower()

runs <- expand.grid(variant=variants, 
                    flame_length=NA,
                    fire_kcp="NoWF",
                    treatment="NoTreat",
                    #flame_length = FSim_scenarios$flame_length, 
                    #treatment = treatments, 
                    stringsAsFactors = FALSE)

# Make an outputs directory

dir.create(paste0(RunDirectory, "/outputs"))

# Save R environment to be loaded into the FVS background job

## ---- Save inputs for background FVS run ----

saveRDS(
  list(
    runs         = runs,
    RunDirectory = RunDirectory,
    fvs_bin      = fvs_bin
  ),
  file = file.path(RunDirectory, "runFVS_inputs.rds")
)

## FINAL FVS RUN IS CALLED FROM TERMINAL USING Rscript runFVS_batch.R



