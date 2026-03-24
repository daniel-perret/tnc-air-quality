library(RSQLite)
library(sqldf)
library(DBI)
library(data.table)
library(dplyr)


options(scipen = 999)
## Set working directory as the master folder with all FIA SQLite databases within their
## individual folders. Named: FIADBs.
setwd("C:\\Users\\Houtmanr\\FVS_Tradeoffs\\rFVSProcessing\\FIADBs")

# This file lists all unique stand identifiers (Plot_CN) values for the study area
### ENTER CORRECT STAND TABLE PATHWAY HERE ###
target_stands <- read.table("C:/Users/houtmanr/FVS_Tradeoffs/rFVSProcessing/FIADBs/Stands_byVariantR6_Carbon_2014.csv", sep = ",", header = TRUE)

target_stands <- as.data.table(unique(target_stands["CN"]))
target_stands$CN <- as.character(target_stands$CN)
target_stands <-setkey(target_stands, CN)


# connect to the sqlite database
con = dbConnect(RSQLite::SQLite(), dbname="FIADB_USA.db")

# get a list of all tables
alltables = dbListTables(con)
alltables

#FVS plots:
plots <- as.data.table(dbGetQuery(con, 'select * from FVS_PLOTINIT_PLOT'))
plots_filtered <- merge(plots, target_stands, by.x = "STAND_CN", by.y = "CN")
plots <- NULL
#write.csv(plots_filtered, "R6_Plots.csv")

#FVS trees:
trees <- as.data.table(dbGetQuery(con, 'select * from FVS_TREEINIT_PLOT'))
trees_filtered <- merge(trees, target_stands, by.x = "STAND_CN", by.y = "CN")
trees <- NULL
#write.csv(trees_filtered, "R6_Trees.csv")

#FVS stands:
stands <- as.data.table(dbGetQuery(con, 'select * from FVS_STANDINIT_PLOT'))
stands_filtered <- merge(stands, target_stands, by.x = "STAND_CN", by.y = "CN")
stands_filtered$VARIANT <- "EC"
stands_filtered$INV_YR <- 2014
#write.csv(stands_filtered, "R6_Stands.csv")


setwd("C:/Users/houtmanr/FVS_Tradeoffs/rFVSProcessing/FIADBs/")

con = dbConnect(RSQLite::SQLite(), dbname = 'R6_TreeMapStands.db', path = "#?*_~")
dbWriteTable(conn=con, name = "FVS_StandInit", value = stands_filtered)
dbWriteTable(conn=con, name = "FVS_PlotsInit", value = plots_filtered)
dbWriteTable(conn=con, name = "FVS_TreeInit", value = trees_filtered)
dbListTables(conn = con)

dbDisconnect(con)
