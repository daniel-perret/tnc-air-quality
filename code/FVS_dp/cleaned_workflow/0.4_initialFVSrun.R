#### 0.3_initialFVSrun.R
#### Runs a no-treatment, no-fire FVS cycle for all CONUS variants to calculate
#### canopy fuel variables (CBH, CHT, CBD) used in all subsequent emissions runs.
#### Outputs: per-variant SQLite databases in RunDirectory/outputs/


## ---- Configuration ----

# Input databases
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/"

# FVS run name
run_name <- str_c("NoFireDryRun_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))


## ---- Run directory setup ----

dbs <- list.files(TMFM2020_dir_path, full.names = TRUE)

RunDirectory <- here("FVS_runs/full", run_name)
dir.create(RunDirectory)

setwd(RunDirectory)

log_session_info()


## ---- Write FVS keyword files ----

write_keywords_fullparallel_fullmatch(RunDirectory = RunDirectory,
                                      database_paths = dbs,
                                      stand_subset = "all",
                                      treat_kcps = NA,
                                      fire_kcps = NA,
                                      ncycles = 2,
                                      interval = 1,
                                      runtype = "dry",
                                      fbfm = "default",
                                      nworkers = parallel::detectCores() - 2)


## ---- Build runs table ----

variants <- dbs %>%
  str_sub(-5, -4) %>%
  tolower()

runs <- expand.grid(variant     = variants,
                    flame_length = NA,
                    fire_kcp    = "NoWF",
                    treatment   = "NoTreat",
                    stringsAsFactors = FALSE)


## ---- Save and dispatch ----

dir.create(file.path(RunDirectory, "outputs"))

saveRDS(
  list(
    runs         = runs,
    RunDirectory = RunDirectory,
    fvs_bin      = fvs_bin
  ),
  file = file.path(RunDirectory, "runFVS_inputs.rds")
)

## Run FVS via terminal: Rscript runFVS_batch.R
