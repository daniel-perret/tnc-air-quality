######## This script puts together an FVS run for a simple prescribed fire in year 1, with canopy variables and flame lengths conditioned from: (1) a "dry" no-fire run, and (2) a "dry" prescribed fire run from which we can grab a flame length. The purpose of this is for canopy consumption calculations to match the fixed-FL logic we use in the wildfire simulations.


######## required libraries
library(tidyverse) #For data manipulation
library(RSQLite) #For working with sqlite databases
library(terra) #For raster and vector geospatial operations
library(data.table) #Faster data format, works with default R dataframe functions
library(foreign) #For reading in .dbf files
library(furrr) #For parallelization
library(withr) #For parallelization - used to temporarily change the working directory for each worker
library(rFVS)
library(here)

######## Get pre-calculated variables from other runs ----

# this first db is a simple prescribed fire run, no modifications
rx.db <- extract_sqlite_tables("FVS_runs/RH_reptest_Rx_VarIE_09Apr26_1522/outputs/SimpleRxFire_NoWF_IE.db")
# this second db is a simple grow cycle, no modifications
dry.db <- extract_sqlite_tables("FVS_runs/DryRun_test_Cycle1_16Apr26_1711/outputs/NoTreat_NoWF_IE.db")

# this is the data that gets read into the .key file
extraStandDat <- dry.db$FVS_Compute %>% 
  filter(Year==2020) %>% 
  select(Stand_ID = StandID, 
         CBH_init = CBH, 
         CHT_init = CHT, 
         CBD_init = CBD) %>% 
  left_join(rx.db$FVS_BurnReport %>% 
              select(Stand_ID = StandID,
                     FLEN_init = Flame_length))


######### Set up the run ----

# Set the FVS executable folder
fvs_bin = "C:/FVS/FVSSoftware/FVSbin"

# Source all required functions

lapply(list.files("/Users/daniel.perret/LOCAL_WORKSPACE/PROJECTS/tnc-air-quality/code/FVS_dp/functions",
                  full.names = T), source)

# Set location of TMFM sqlite databases and read in data
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/"

dbs <- list.files(TMFM2020_dir_path,
                  full.names=TRUE)

dbs <- dbs[9]

#Name the FVS run
run_name <- str_c("RxWetRun_test_Cycle2_complete_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))

# Create a dir for this run.
RunDirectory <- str_c(here(), "/FVS_runs/", run_name)
dir.create(RunDirectory)

setwd(paste0(RunDirectory))

log_session_info()

# Specify treatment kcp files, first move treatment kcp over to the directory and modify as needed
treat_kcps <- list.files(paste0(RunDirectory,"/treat_kcps"), full.names = T)

# Write the simulation .key files

write_keywords_parallel(database_paths = dbs, 
                        stand_subset = "all", 
                        FSim_scenarios = NA, #rename this var
                        treat_kcps = treat_kcps, 
                        fire_kcps = NA,
                        ncycles = 2,
                        interval = 1,
                        runtype = "wet_rx",
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

######## Run FVS **USE BACKGROUND SCRIPT** ----

future::plan(multisession, 
             workers = parallel::detectCores())

#Run FVS in parallel for all combinations
furrr::future_pmap(
  list(
    variant = runs$variant,
    flame_length=NA,
    treatment=runs$treatment,
    fire_kcp="NoWF"
  ),
  runFVS,
  RunDirectory = RunDirectory,
  fvs_bin = fvs_bin
)

plan(sequential)
gc()


# 
# combine_dbs_general(dbDirectory = paste0(RunDirectory, "/outputs/"), 
#                     rm.files = FALSE, 
#                     output_db_name = "Combined_Outputs_All_FLs_txs2.db")
