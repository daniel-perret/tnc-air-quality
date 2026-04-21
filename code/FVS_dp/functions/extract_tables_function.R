## This is a function that extracts SQLite tables into a named list of data.frames, written by Copilot on 4/8/26


extract_sqlite_tables <- function(db_path) {
  # Connect to the SQLite database
  con <- dbConnect(RSQLite::SQLite(), db_path)
  
  # Ensure the connection is closed on exit
  on.exit(dbDisconnect(con), add = TRUE)
  
  # Get all table names
  tables <- dbListTables(con)
  
  # Read each table into a data frame
  table_list <- lapply(tables, function(tbl) {
    dbReadTable(con, tbl)
  })
  
  # Name the list elements after the tables
  names(table_list) <- tables
  
  return(table_list)
}
