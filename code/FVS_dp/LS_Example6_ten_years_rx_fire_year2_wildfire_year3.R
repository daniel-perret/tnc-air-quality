library(tidyverse) #For data manipulation
library(RSQLite) #For working with sqlite databases
library(terra) #For raster and vector geospatial operations
library(data.table) #Faster data format, works with default R dataframe functions
library(foreign) #For reading in .dbf files
library(furrr) #For parallelization
library(withr) #For parallelization - used to temporarily change the working directory for each worker
library(rFVS)
 
# setwd("C:/Users/Laurel/Documents/WFSETP/Scenarios/Maximum_Effort/FVS/FVS_Run6_rx_fire_yr2_wildfire_yr3_10yrs")
wd <- getwd()

#Set the FVS executable folder
fvs_bin = "C:/FVS/FVSSoftware/FVSbin"

#---Set location of TMFM sqlite databases and read in data----------------------
TMFM2020_dir_path <- "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM2020_OkaWen/TMFM_2020_OkaWen_Databases/"


okawen_dbs <- list.files(TMFM2020_dir_path,
                         full.names=TRUE)

okawen_dbs <- okawen_dbs[1]

#Name the FVS run
run_name <- str_c("fvsTest_",
                  strftime(Sys.Date(), "%d%b%y"),
                  "_", strftime(Sys.time(), "%H%M"))

# Create a dir for this run.
RunDirectory <- str_c(wd, "/FVS_runs/", run_name)
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
  fmlwood = c(110, 100, 90, 80, 60, 50),
  fmlherb = c(110, 100, 90, 70, 40, 40),
  wspd_mph = c(2, 4, 4, 6, 7, 10),
  temp_F = c(85, 85, 85, 90, 90, 90),
  mortality = 1,
  per_stand_burned = c(70, 80, 90, 90, 100, 100),
  season = 3
)

write_kcps_wildfire(params_df = FSim_scenarios,
                    output_dir = "fire_kcps/")

#Paths to kcps
fire_kcps <- list.files(paste0(RunDirectory, "/fire_kcps"), full.names = TRUE)

#Path to rx fire kcp
treat_kcps <- list.files(paste0(RunDirectory, "/treat_kcps"), full.names = TRUE)

#Write the scenario .key files in parallel
write_keywords_parallel(okawen_dbs, 
                        stand_subset = 10, 
                        FSim_scenarios = FSim_scenarios, #rename this var
                        treat_kcps=NA, 
                        fire_kcps,
                        ncycles = 2,
                        interval = 1)

#Reset parallel backend
plan(sequential)

#Create the data frame of run scenario parameters to parallelize over
#The number of rows is the number of FVS runs you're doing

variants <- c("ec")

fire_scenarios <- list.files("./fire_kcps")
fire_scenarios <- stringr::str_sub(fire_scenarios, end = -5) 

runs <- expand.grid(variant=variants, 
                    flame_length = FSim_scenarios$flame_length, #treatment = treatments, 
                    stringsAsFactors = FALSE) %>% 
  left_join(data.frame(fire_kcp = fire_scenarios, 
                       flame_length = readr::parse_number(fire_scenarios)),
            by = "flame_length") %>% 
  mutate(treatments = "NoTreat")

#Make an outputs directory
dir.create(paste0(RunDirectory, "/outputs"))

future::plan(multisession, 
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

database_dir <- paste0(RunDirectory, "/outputs/")

combine_dbs_general(RunDirectory = database_dir, rm.files = FALSE, output_db_name = "Combined_Outputs_All_FLs_txs.db")
