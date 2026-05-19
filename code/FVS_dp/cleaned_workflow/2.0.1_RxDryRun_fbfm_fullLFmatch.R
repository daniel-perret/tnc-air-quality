######## This script does a prescribed fire "dry" run that uses the full set of TMFM stands and LF FBFM combinations

# Set location of TMFM sqlite databases
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/"

dbs <- list.files(TMFM2020_dir_path,
                  full.names=TRUE)

dbs <- dbs[9]

variants <- dbs %>% 
  str_sub(., -5,-4)

#Name the FVS run
run_name <- str_c("RxDryRun_fullLFmatch_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))

# Create a dir for this run.
RunDirectory <- str_c(here(), "/FVS_runs/", run_name)
dir.create(RunDirectory)

setwd(paste0(RunDirectory))

log_session_info()

# Specify treatment kcp files

treat_kcps <- list.files(paste0(RunDirectory,"/treat_kcps"), full.names = T)

# Pull out TreeMap - Landfire StandID x FBFM40 combinations to feed into the keyfile

fbfm.key <- read.csv(paste0(here(),"/data/tmlf_keys/tmlf_key_conus.csv"),
                     header = T,
                     stringsAsFactors = F) %>% 
  select(key = real.key,
         StandID = tm,
         FBFM = lf)

# Write the simulation .key files

write_keywords_fullparallel_fullmatch(RunDirectory = getwd(),
                                      database_paths = dbs, 
                                      stand_subset = "all", 
                                      FSim_scenarios = NA, #rename this var
                                      treat_kcps = treat_kcps, 
                                      fire_kcps = NA,
                                      ncycles = 2,
                                      interval = 1,
                                      runtype = "dry",
                                      fbfm = "full",
                                      fbfmDat = fbfm.key)

#Create the data frame of run scenario parameters to parallelize over

treatments <- list.files("./treat_kcps")
treatments <- stringr::str_sub(treatments, end = -5) 

runs <- expand.grid(variant=tolower(variants), 
                    flame_length = NA, 
                    treatment = treatments, 
                    fire_kcp = "NoWF",
                    stringsAsFactors = FALSE)

#Make an outputs directory

dir.create(paste0(RunDirectory, "/outputs"))

# Save R environment to be loaded into the FVS background job
gc()
save(list = ls(envir = .GlobalEnv), file = "RunEnv.RData")

# Call parallelized FVS run as background job, passing the R env we saved

p <- callr::r_bg(function(){
  load("RunEnv.RData")
  source("../../code/FVS_dp/functions/runFVS_background_fn.R")
  runFVS_background(runs, RunDirectory, fvs_bin, runFVS)
  gc()
})

# 
# #Run FVS in parallel for all combinations -- use BG script
# future::plan(future.callr::callr, 
#              workers = parallel::detectCores())
# 
# furrr::future_pmap(
#   list(
#     variant = runs$variant,
#     flame_length=NA,
#     treatment=runs$treatment,
#     fire_kcp="NoWF"
#   ),
#   runFVS,
#   RunDirectory = RunDirectory,
#   fvs_bin = fvs_bin
# )
# 
# plan(sequential)
# gc()
