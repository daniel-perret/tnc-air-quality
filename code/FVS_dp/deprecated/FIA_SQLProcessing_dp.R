library(RSQLite)
library(sqldf)
library(DBI)
library(data.table)


options(scipen = 999)
## Set working directory as the master folder with all FIA SQLite databases within their 
## individual folders. Named: FIADBs.
setwd("C:\\Users\\Houtmanr\\FVS_Tradeoffs\\rFVSProcessing\\FIADBs")

# This file lists all unique stand identifiers (Plot_CN) values for the study area
### ENTER CORRECT STAND TABLE PATHWAY HERE ###
target_stands <- read.table("C:/Users/houtmanr/FVS_2016/FVSInputFiles/R6_Stands_Variant.csv", sep = ",", header = TRUE)
target_stands <- unique(target_stands["CN"]) # Pulls out the unique CNs
target_stands[] <- lapply(target_stands, as.character) #Creates a list of CNs as Characters.
tree_header <- c("Stand_CN", "INVYR", "STATUSCD", "Tree_count", "SPCD", "DBH", "HT", "ACTUALHT", "CR", "SUBP",
                 "TREE", "AGENTCD", "Species", "History", "CrRatio") # sets a list with header names

states <- list.dirs() # Lists the files in a directory folder
states <- grep("SQLit", states, value = TRUE) # It search for matches to argument pattern within each element of a character vector, if true it returns the vector

# This loop iterates through every state database and extracts the tree data from FIA
tree_table <- NULL
for(db in 1:length(states)){
  # connect to the sqlite file
  dbtitle <- list.files(path = states[db], full.names = FALSE)
  dbname <- paste0(states[db], "\\", dbtitle)
  con = dbConnect(RSQLite::SQLite(), dbname=dbname)
  # get a list of all tables
  alltables = dbListTables(con)
  alltables

  tree <- as.data.table(dbGetQuery(con, 'select PLT_CN, INVYR, STATUSCD, TPA_UNADJ, SPCD, DIA, HT, ACTUALHT, CR, SUBP, TREE, AGENTCD from TREE'))
  tree_filtered <- merge(tree, target_stands, by.x = "PLT_CN", by.y = "CN") 

  tree_filtered[, ':=' (Species = (SPCD), History = 1, CrRatio = CR )]
  tree_filtered[AGENTCD != 'NULL', ':=' (History = 8)]
  
  tree_characteristics = c("PLT_CN", "INVYR", "STATUSCD", "TPA_UNADJ", "SPCD", "DIA", "HT", "ACTUALHT", "CR", "SUBP", "TREE", "AGENTCD","Species", "History", "CrRatio")
  tree_table <- rbind(tree_table, tree_filtered[, tree_characteristics, with=FALSE])
  
  dbDisconnect(con)
}

forest_type <- as.data.table(dbGetQuery(con, 'select * FROM REF_FOREST_TYPE'))

names(tree_table) <- tree_header
plots <- length(unique(tree_table$Stand_CN))

# This loop iterates through the stand characteristics and builds an input stand table for FVS
stand_header <- c("Stand_CN", "Inv_Year", "Case", "Basal_Area_Factor", "Inv_Plot_Size", "Brk_DBH")
stand_table <- NULL
for(db in 1:length(states)){
  # connect to the sqlite file
  dbtitle <- list.files(path = states[db], full.names = FALSE)
  dbname <- paste0(states[db], "\\", dbtitle)
  con = dbConnect(RSQLite::SQLite(), dbname=dbname)
  # get a list of all tables
  alltables = dbListTables(con)
  
  plot_table <- as.data.table(dbGetQuery(con, 'select CN, INVYR from PLOT'))
  plot_filtered <- as.data.table(merge(plot_table, target_stands, by.x = "CN", by.y = "CN"))
  
  plot_filtered <- plot_filtered[, ':=' (Inv_Year = 2014, Case = (INVYR), INVYR = NULL, Basal_Area_Factor = 0, Inv_Plot_Size = 1, Brk_DBH = 999)]

  stand_table <- rbind(stand_table, plot_filtered)
    dbDisconnect(con)
}

names(stand_table) <- stand_header

# Remove NA values when writing files (FVS does NOT like them)
### UPDATE YOUR OUTPUT FILE NAMES HERE ###
write.csv(tree_table, file = "tree_table_R6_2016.csv", na = "")
write.csv(stand_table, file = "stand_table_R6_2016.csv", na = "")
