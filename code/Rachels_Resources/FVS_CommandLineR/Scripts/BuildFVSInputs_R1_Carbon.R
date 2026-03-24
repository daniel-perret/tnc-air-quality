
##########################################
#                                        #
#           Create FVS Keyword File      #
#           for FORSYS processing        #
#                                        #
##########################################

options(scipen = 9999)
library(dplyr, tidyverse, data.table)


## Set the working directory here.
inputDirectory <- c('C:/Users/Houtmanr/FVS/FVS_CommandLineR/Inputs/')
setwd(inputDirectory)

kcp_file_list <- list.files("C:/Users/Houtmanr/FVS/FVS_CommandLineR/Inputs/Riley_Carbon/")
FL <- c("1", "3", "5", "7", "10", "20", "0")

# Check if output directory exists
outputs <- c("TestStand")
if(!dir.exists(file.path(getwd(), outputs))){
  print(paste("Making output directory: ", file.path(getwd(), outputs)), sep="")
  dir.create(file.path(getwd(), outputs))
} else(
  print(paste("output directory, ", file.path(getwd(), outputs), ", already exists"), sep="")
)

## This function creates the string for a single stand in FVS.
createInputFile <- function(stand, managementID, inputDatabase, num_cycles, outputDatabase, areaSpecificKcp, FL){
  # Create .key file
  input <- paste0('STDIDENT\n',
                  stand, '\n',
                  'STANDCN\n',
                  stand, '\n',
                  'MGMTID\n',
                  managementID,
                  '\nNUMCYCLE       3\n',
                  'TIMEINT         0        1\n',
                  'SCREEN\n',
                  'DATABASE\n',
                  'DSNIN\n',
                  inputDatabase, '\n',
                  'StandSQL\n',
                  'SELECT * FROM FVS_StandInit\n',
                  "WHERE  Stand_CN  = '%stand_cn%'\n",
                  'EndSQL\n',
                  'DSNIN\n',
                  inputDatabase, '\n',
                  'TreeSQL\n',
                  'SELECT * FROM FVS_TreeInit\n',
                  'WHERE Stand_CN = (SELECT Stand_CN FROM FVS_StandInit\n',
                  "WHERE Stand_CN = '%stand_cn%')\n",
                  'EndSQL\n',
                  'END\n',
                  'COMPUTE            0\n',
                  'SEV_FL = POTFLEN(1)\n',
                  'MOD_FL = POTFLEN(2)\n',
                  'scenario = 1\n',
                  'CC = acancov\n',
                  'FML = fuelmods(1,1)\n',
                  'CHT = ATOPHT\n',
                  'CBH = crbaseht\n',
                  'CBD = crbulkdn\n',
                  'YR = year\n',
                  'FLEN = ', 
                  FL,
                  '\n',
                  'END\n',
                  'FMIN\n',
                  'FUELOUT\n',
                  'POTFIRE\n',
                  'BURNREPT\n',
                  'FUELREPT\n',
                  'MORTREPT\n',
                  'CARBREPT\n',
                  'CARBCUT\n',
                  'FIRECALC           0         1         2\n',
                  'END\n',
                  'STRCLASS           1     30.00        5.       16.     20.00       50.     35.00\n',
                  ##Include any addfiles here.
                  'OPEN              81\n',
                  getwd(),
                  "/kcpfiles/",
                  areaSpecificKcp,
                  "\n",
                  'ADDFILE           81\n',
                  'CLOSE             81\n',
                  'CUTLIST\n',
                  'TREELIST\n',
                  'DATABASE\n',
                  'DSNOUT\n',
                  outputDatabase, '\n',
                  'SUMMARY\n',
                  'COMPUTE\n',
                  'FUELSOUT\n',
                  'POTFIRE\n',
                  'BURNREPT\n',
                  'FUELREPT\n',
                  'MORTREPT\n',
                  'STRCLASS\n',
                  'CARBRPTS\n',
                  'END\n',
                  'SPLABEL\n',
                  'ALL\n',
                  'Process\n\n')

}

## Set the file path to the stand input database here:
inputDatabase <- paste0(getwd(), '/R6_2Stands.db')

setwd('../Outputs')
## Set the file path to the FVS output database here (database MUST exist before running FVS):
outputDatabase <- paste0(getwd(), '/Region6_2014.db')
setwd(inputDirectory)

# READ in the stand table here. The fields should be Stand_ID, variant, and kcp.
# If kcp does not exist in the file, it can be set below for all stands.
#standlist <- read.table(paste0(getwd(), '/Stands_byVariantR1_Carbon_2014.csv'), header = T, sep = ",")
standlist <- data.table::data.table(CN = c("35370998010690", "40220615010497"),
                        FVSVariant = c("EC", "EC"))

standlist <- unique(standlist)
## If there is a single kcp, set that value here. Otherwise there should be a field in the dataset that identifies
## the kcp file for each stand.
# areaSpecificKcp <- paste0(getwd(),'/kcpfiles/', 'FlameAdjust_KLR_5_7_feet_FL.kcp')
for(a in 1:length(FL)){ 
  
  if(FL[a] > 0)
    standlist$kcp <- paste0('FlameAdjust_KLR_', FL[a], '_feet_FL.kcp')
  if(FL[a] == 0)    
    standlist$kcp <- paste0('NoFire_KLR.kcp')
  
  # This creates a key variable for each unique set of kcp and variant combinations. This creates input files that link the correct kcp with
  # each stand, and sends the stands to the correct FVS variant for processing.
  standlist$treat_key <- paste0(stringr::str_sub(standlist$kcp, end = -5), '_', standlist$FVSVariant)

  
  for(g in unique(standlist$treat_key)){
    masterkeys <- NULL
    group_stands <- subset(standlist, treat_key == g)
    for(s in 1:nrow(group_stands)){
      keywords <- createInputFile(group_stands$CN[s], group_stands$CN[s], inputDatabase,
                                  group_stands$NUM_CYCLES[s], outputDatabase, paste0("Riley_Carbon/", group_stands$kcp[s]), FL[a])
      masterkeys <- paste0(masterkeys, keywords)
    }
    # Print to the key file
    masterkeys <- paste0(masterkeys, "\n STOP\n")
    file_name <- stringr::str_sub(g, end = -5)
    write(masterkeys, file = paste0( outputs, '/', g, '.key'))

    ## Creat the .in file ##
    fvs_in <- paste0(g, ".key\n",
                     g, ".fvs\n",
                     g, ".out\n",
                     g, ".trl\n",
                     g, ".sum\n")
    fvs_in_file <- paste0(outputs, '\\', g, '.in')
    write(fvs_in, file = fvs_in_file)
    fvs_bat <- paste0("C:\\FVSbin\\FVS", unique(group_stands$FVSVariant), ".exe < ", g, ".in\n")
    write(fvs_bat, paste0(outputs, '\\test.bat'), append = "TRUE")
  }
}

write( "\nPAUSE\n", paste0(outputs, '\\test.bat'), append = "TRUE")

## To run the program directly from R, update the working directory to the new file and run the following two lines.
#setwd(outputs)
#shell.exec("test.bat")

