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
run_name <- str_c("RH_reptest_WF_VarIE_modCan",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))

# Create a dir for this run.
RunDirectory <- str_c(here(), "/FVS_runs/", run_name)
dir.create(RunDirectory)

setwd(paste0(RunDirectory))

log_session_info()

#Create a table of FSim fire scenario parameters (flame lengths and associated fuel moisture and weather conditions)

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

# Write the kcp files for the wildfire parameters set above

write_kcps_wildfire(params_df = FSim_scenarios,
                    output_dir = "fire_kcps/")

fire_kcps <- list.files(paste0(RunDirectory, "/fire_kcps"), full.names = TRUE)


# Write the simulation .key files

write_keywords_parallel(database_paths = dbs, 
                        stand_subset = "all", 
                        FSim_scenarios = FSim_scenarios, #rename this var
                        treat_kcps=NA, 
                        fire_kcps,
                        ncycles = 2,
                        interval = 1)

#Reset parallel backend
plan(sequential)

#Create the data frame of run scenario parameters to parallelize over

variants <- c("ie")

fire_scenarios <- list.files("./fire_kcps")
fire_scenarios <- stringr::str_sub(fire_scenarios, end = -5) 

runs <- expand.grid(variant=variants, 
                    flame_length = FSim_scenarios$flame_length, #treatment = treatments, 
                    stringsAsFactors = FALSE) %>% 
  left_join(data.frame(fire_kcp = fire_scenarios, 
                       flame_length = readr::parse_number(fire_scenarios)),
            by = "flame_length") %>% 
  mutate(treatments = "NoTreat")


#runs <- runs[5,]
#Make an outputs directory

dir.create(paste0(RunDirectory, "/outputs"))

future::plan(future.callr::callr, 
             workers = parallel::detectCores())

#Run FVS in parallel for all combinations
furrr::future_pmap(
  list(
    variant = runs$variant,
    flame_length=runs$flame_length,
    treatment=runs$treatment,
    fire_kcp=runs$fire_kcp
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
