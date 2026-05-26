#### 2.0_RxDryRun.R
#### Runs prescribed fire FVS simulations (dry run) across all CONUS variants
#### using the full set of TM-LF FBFM combinations. Outputs flame lengths and
#### stand structure needed to condition the prescribed fire wet run (2.1).
#### Outputs: per-variant SQLite databases in RunDirectory/outputs/


## ---- Configuration ----

# Input databases
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/"

# FVS run name
run_name <- str_c("RxDryRun_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))


## ---- Run directory setup ----

dbs <- list.files(TMFM2020_dir_path, full.names = TRUE)

RunDirectory <- here("FVS_runs/full", run_name)
dir.create(RunDirectory)

setwd(RunDirectory)

log_session_info()


## ---- Load TM-LF FBFM key ----

fbfm.key <- read.csv(here("data/tmlf_keys/tmlf_key_conus.csv"),
                     header = TRUE,
                     stringsAsFactors = FALSE) %>%
  select(key     = real.key,
         StandID = tm,
         FBFM    = lf)


## ---- Specify treatment keyword files ----



treat_kcps <- list.files(file.path(RunDirectory, "treat_kcps"), full.names = TRUE)


## ---- Write FVS keyword files ----

write_keywords_fullparallel_fullmatch(RunDirectory   = RunDirectory,
                                      database_paths = dbs,
                                      stand_subset   = "all",
                                      treat_kcps     = treat_kcps,
                                      fire_kcps      = NA,
                                      ncycles        = 2,
                                      interval       = 1,
                                      runtype        = "dry",
                                      fbfm           = "full",
                                      fbfmDat        = fbfm.key,
                                      nworkers       = parallel::detectCores() - 2)


## ---- Build runs table ----

variants <- dbs %>%
  str_sub(-5, -4) %>%
  tolower()

treatments <- list.files(file.path(RunDirectory, "treat_kcps")) %>%
  tools::file_path_sans_ext()

runs <- expand.grid(variant      = variants,
                    flame_length = NA,
                    treatment    = treatments,
                    fire_kcp     = "NoWF",
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
