#### 2.1_RxWetRun.R
#### Runs prescribed fire FVS simulations (wet run) across all CONUS variants,
#### iterating over all TM-LF FBFM combinations. Conditioned on two prior runs:
####   - Canopy fuel variables (CBH, CHT, CBD) from the initial dry run (0.2)
####   - Flame lengths from the Rx dry run (2.0)
#### Outputs: per-variant SQLite databases in RunDirectory/outputs/


## ---- Configuration ----

# Input databases
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/"

# Completed runs to condition from
init_dry_run_name <- "NoFireDryRun_20May26_1629"   # 0.2 output
rx_dry_run_name   <- "RxDryRun_02Jun26_2233"      # 2.0 output — set before running

# FVS run name
run_name <- str_c("RxWetRun_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))


## ---- Run directory setup ----

dbs <- list.files(TMFM2020_dir_path, full.names = TRUE)

RunDirectory <- here("FVS_runs/full", run_name)
dir.create(RunDirectory)

setwd(RunDirectory)

log_session_info()


## ---- Load TM-LF FBFM key ----

fbfm.key <- read.csv(here("data/tmlf_keys/tmlf_key_conus_64bit.csv"),
                     header = TRUE,
                     stringsAsFactors = FALSE) %>%
  select(key = real.key,
         TM_StandID = tm,
         FBFM = lf) %>%
  mutate(key = as.character(key),
         TM_StandID = as.character(TM_StandID))


## ---- Load conditioning data ----

init_dry_run_paths <- list.files(here("FVS_runs/full", init_dry_run_name, "outputs"), full.names = TRUE)
rx_dry_run_paths   <- list.files(here("FVS_runs/full", rx_dry_run_name,   "outputs"), full.names = TRUE)

# Canopy fuel variables from 0.2 initial dry run
canopy_dat <- map_df(init_dry_run_paths, ~ {
  extract_sqlite_tables(.x) %>%
    pluck("FVS_Compute") %>%
    filter(Year == 2020) %>%
    select(TM_StandID = StandID,
           CBH_init   = CBH,
           CHT_init   = CHT,
           CBD_init   = CBD)
})

# Flame lengths from 2.0 Rx dry run
fl_dat <- map_df(rx_dry_run_paths, ~ {
  extract_sqlite_tables(.x) %>%
    pluck("FVS_BurnReport") %>%
    select(Stand_ID = StandID,
           FLEN     = Flame_length)
})

extraStandDat <- fl_dat %>%
  left_join(fbfm.key, by = c("Stand_ID" = "key")) %>%
  left_join(canopy_dat, by = "TM_StandID") %>%
  mutate(FLEN_init = case_when(
    FLEN >  0 & FLEN <  2 ~ 1,
    FLEN >= 2 & FLEN <  4 ~ 3,
    FLEN >= 4 & FLEN <  6 ~ 5,
    FLEN >= 6 & FLEN <  8 ~ 7,
    FLEN >= 8 & FLEN < 12 ~ 10,
    FLEN >= 12             ~ 20
  ))


## ---- Specify treatment keyword files ----

treat_kcp_dir <- file.path(RunDirectory, "treat_kcps")
if (!dir.exists(treat_kcp_dir)) {
  stop("Treatment .kcp directory not found: ", treat_kcp_dir)
}

treat_kcps <- list.files(file.path(RunDirectory, "treat_kcps"), full.names = TRUE)


## ---- Write FVS keyword files ----

write_keywords_fullparallel_fullmatch(RunDirectory   = RunDirectory,
                                      database_paths = dbs,
                                      stand_subset   = "all",
                                      treat_kcps     = treat_kcps,
                                      fire_kcps      = NA,
                                      ncycles        = 2,
                                      interval       = 1,
                                      runtype        = "wet_rx",
                                      fbfm           = "full",
                                      extraStandDat  = extraStandDat,
                                      nworkers       = parallel::detectCores() - 4)


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
