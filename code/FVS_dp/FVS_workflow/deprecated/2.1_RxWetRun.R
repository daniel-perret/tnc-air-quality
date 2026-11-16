######## This script puts together an FVS run for a simple prescribed fire in year 1, with canopy variables and flame lengths conditioned from: (1) a "dry" no-fire run, and (2) a "dry" prescribed fire run from which we can grab a flame length. The purpose of this is for canopy consumption calculations to match the fixed-FL logic we use in the wildfire simulations.

setwd(here())

# dataframe containing the key values for linking TM stands and LF FBFMs

fbfm.key <- read.csv(paste0(here(),"/data/tmlf_keys/tmlf_key_conus.csv"),
                     header = T,
                     stringsAsFactors = F) %>% 
  select(key = real.key,
         TM_StandID = tm,
         FBFM = lf) %>% 
  mutate(key = as.character(key),
         TM_StandID = as.character(TM_StandID))

# this first db is a simple prescribed fire run, no modifications
rx.db <- extract_sqlite_tables("FVS_runs/RxDryRun_fullLFmatch_11May26_1342/outputs/SimpleRxFire_NoWF_IE.db")

# this second db is a simple grow cycle, no modifications
dry.db <- extract_sqlite_tables("FVS_runs/DryRun_test_Cycle1_16Apr26_1711/outputs/NoTreat_NoWF_IE.db")

# this is the data that gets read into the .key file
extraStandDat <- rx.db$FVS_BurnReport %>% 
  select(Stand_ID = StandID,
         FLEN = Flame_length) %>% 
  left_join(fbfm.key,
            by = c("Stand_ID" = "key")) %>% 
  left_join(dry.db$FVS_Compute %>% 
              filter(Year == 2020) %>% 
              select(TM_StandID = StandID,
                     CBH_init = CBH,
                     CHT_init = CHT,
                     CBD_init = CBD),
            by = "TM_StandID") %>% 
  mutate(FLEN_init = case_when(FLEN > 0 & FLEN < 2 ~ 1, #testing this logic to match WF bins
                               FLEN >= 2 & FLEN < 4 ~ 3,
                               FLEN >= 4 & FLEN < 6 ~ 5,
                               FLEN >= 6 & FLEN < 8 ~ 7,
                               FLEN >= 8 & FLEN < 12 ~ 10,
                               FLEN >= 12 ~ 20))

######### Set up the run ----

# Set the FVS executable folder
fvs_bin = "C:/FVS/FVSSoftware/FVSbin"

# Set location of TMFM sqlite databases and read in data
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/"

dbs <- list.files(TMFM2020_dir_path,
                  full.names=TRUE)

dbs <- dbs[9]

#Name the FVS run
run_name <- str_c("RxWetRun_fullLFmatch_FLENbin_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))

# Create a dir for this run.
RunDirectory <- str_c(here(), "/FVS_runs/", run_name)
dir.create(RunDirectory)

setwd(paste0(RunDirectory))

log_session_info()

# Specify treatment kcp files, first move treatment kcp over to the directory and modify as needed
# Make sure to copy over the "ModRxFire.kcp" version
treat_kcps <- list.files(paste0(RunDirectory,"/treat_kcps"), full.names = T)

# Write the simulation .key files

write_keywords_fullparallel_fullmatch(RunDirectory = RunDirectory,
                                      database_paths = dbs, 
                                      stand_subset = "all", 
                                      FSim_scenarios = NA, #rename this var
                                      treat_kcps = treat_kcps, 
                                      fire_kcps = NA,
                                      ncycles = 2,
                                      interval = 1,
                                      runtype = "wet_rx",
                                      fbfm = "full",
                                      extraStandDat = extraStandDat)

#Create the data frame of run scenario parameters to parallelize over

variants <- c("ie")

treatments <- list.files("./treat_kcps")
treatments <- stringr::str_sub(treatments, end = -5) 

runs <- expand.grid(variant=variants, 
                    flame_length = NA, 
                    treatment = treatments, 
                    fire_kcp = "NoWF",
                    stringsAsFactors = FALSE)

#Make an outputs directory

dir.create(paste0(RunDirectory, "/outputs"))


## ---- Save inputs for background FVS run ----

saveRDS(
  list(
    runs         = runs,
    RunDirectory = RunDirectory,
    fvs_bin      = fvs_bin
  ),
  file = file.path(RunDirectory, "runFVS_inputs.rds")
)



######## Run FVS **USE BACKGROUND SCRIPT** ----
# 
# future::plan(multisession, 
#              workers = parallel::detectCores())
# 
# #Run FVS in parallel for all combinations
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


# 
# combine_dbs_general(dbDirectory = paste0(RunDirectory, "/outputs/"), 
#                     rm.files = FALSE, 
#                     output_db_name = "Combined_Outputs_All_FLs_txs2.db")
