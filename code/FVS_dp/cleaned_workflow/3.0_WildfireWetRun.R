#### 1.0_WildfireWetRun.R
#### Runs FVS wildfire simulations across six flame length bins for all CONUS variants.
#### Canopy fuel variables (CBH, CHT, CBD) are conditioned from a completed initial dry run.
#### Outputs: per-variant SQLite databases in RunDirectory/outputs/


## ---- Configuration ----

# Input databases
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/"

# Completed initial dry run to condition canopy fuel variables from
dry_run_name <- "NoFireDryRun_20May26_1629"

# FVS run name
run_name <- str_c("Wildfire_WetRun_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))

# or set run_name manually for an interrupted session
run_name <- "Wildfire_WetRun_21May26_0855"

## ---- Run directory setup ----

dbs <- list.files(TMFM2020_dir_path, full.names = TRUE)

RunDirectory <- here("FVS_runs/full", run_name)
dir.create(RunDirectory)

setwd(RunDirectory)

log_session_info()


## ---- Fire scenario parameters ----

FSim_scenarios <- data.frame(
  fire_year = 1,
  flame_length = c(1, 3, 5, 7, 10, 20),
  fm1 = c(8, 7, 6, 5, 4, 3),
  fm10 = c(8, 7, 6, 5, 4, 4),
  fm100 = c(10, 9, 8, 7, 6, 5),
  fm1000 = c(15, 13, 11, 10, 8, 6),
  fmduff = c(50, 45, 40, 30, 20, 15),
  fmlwood = c(110, 100, 90, 80, 60, 60),
  fmlherb = c(110, 100, 90, 70, 30, 30),
  wspd_mph = c(2, 4, 4, 6, 7, 10),       ## WHY IS THIS SO LOW?
  temp_F = c(85, 85, 90, 90, 90, 90),
  mortality = 1,
  per_stand_burned = c(70, 80, 90, 90, 100, 100),
  season = 3   # post-greenup, not autumn as stated in methods doc
)

write_kcps_wildfire(params_df = FSim_scenarios,
                    output_dir = "fire_kcps/")

fire_kcps <- list.files(file.path(RunDirectory, "fire_kcps"), full.names = TRUE)


## ---- Load dry run conditioning data ----

dry.run.paths <- list.files(here("FVS_runs/full", dry_run_name, "outputs"), full.names = TRUE)

extraStandDat <- map_df(dry.run.paths, ~ {
  extract_sqlite_tables(.) %>%
    pluck("FVS_Compute") %>%
    filter(Year == 2020) %>%
    select(Stand_ID = StandID,
           CBH_init = CBH,
           CHT_init = CHT,
           CBD_init = CBD)
})

## ---- Write FVS keyword files ----

write_keywords_fullparallel_fullmatch(RunDirectory = RunDirectory,
                                      database_paths = dbs,
                                      stand_subset = "all",
                                      treat_kcps = NA,
                                      fire_kcps = fire_kcps,
                                      ncycles = 2,
                                      interval = 1,
                                      runtype = "wet",
                                      fbfm = "default",
                                      extraStandDat = extraStandDat,
                                      nworkers = parallel::detectCores() - 2)


## ---- Build runs table ----

variants <- dbs %>%
  str_sub(-5, -4) %>%
  tolower()

fire_scenarios <- list.files("./fire_kcps") %>%
  tools::file_path_sans_ext()

runs <- expand.grid(variant = variants,
                    flame_length = FSim_scenarios$flame_length,
                    stringsAsFactors = FALSE) %>%
  left_join(data.frame(fire_kcp = fire_scenarios,
                       flame_length = readr::parse_number(fire_scenarios)),
            by = "flame_length") %>%
  mutate(treatment = "NoTreat")


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
