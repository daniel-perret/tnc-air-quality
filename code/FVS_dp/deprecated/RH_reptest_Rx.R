######## This script puts together FVS runs attempting to replicate Rachel Houtman's national emissions runs for wildfire flame length bins. 


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
run_name <- str_c("RH_reptest_Rx_VarIE_canMod_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))

# Create a dir for this run.
RunDirectory <- str_c(here(), "/FVS_runs/", run_name)
dir.create(RunDirectory)

setwd(paste0(RunDirectory))

log_session_info()

# Specify treatment kcp files

treat_kcps <- list.files(paste0(RunDirectory,"/treat_kcps"), full.names = T)

# Write the simulation .key files

write_keywords_parallel(database_paths = dbs, 
                        stand_subset = "all", 
                        FSim_scenarios = NA, #rename this var
                        treat_kcps = treat_kcps, 
                        fire_kcps = NA,
                        ncycles = 2,
                        interval = 1)

#Reset parallel backend

plan(sequential)

#Create the data frame of run scenario parameters to parallelize over

variants <- c("ie")

treatments <- list.files("./treat_kcps")
treatments <- stringr::str_sub(treatments, end = -5) 

runs <- expand.grid(variant=variants, 
                    #flame_length = FSim_scenarios$flame_length, 
                    treatment = treatments, 
                    stringsAsFactors = FALSE)

#Make an outputs directory

dir.create(paste0(RunDirectory, "/outputs"))

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

combine_dbs_general(dbDirectory = paste0(RunDirectory, "/outputs/"), 
                    rm.files = FALSE, 
                    output_db_name = "Combined_Outputs_All_FLs_txs2.db")
