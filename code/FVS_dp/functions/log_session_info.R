#This is a function that saves the session information to record which R script was used, when, and with which package versions, to do the run
#
#Generated with ChatGPT by Laurel Sindewald


log_session_info <- function(script_name = NULL, log_file = "session_log.txt") {
  # Get date
  current_date <- Sys.Date()
  
  # Get session info (only package names and versions)
  pkg_info <- sessionInfo()$otherPkgs
  pkg_versions <- sapply(pkg_info, function(pkg) paste(pkg$Package, pkg$Version))
  
  # Determine script name
  if (is.null(script_name)) {
    script_name <- tryCatch({
      # Try commandArgs() for command-line execution
      args <- commandArgs(trailingOnly = FALSE)
      script_path <- sub("--file=", "", args[grep("--file=", args)])
      if (length(script_path) > 0) {
        basename(script_path)
      } else if (requireNamespace("rstudioapi", quietly = TRUE) &&
                 rstudioapi::isAvailable()) {
        # If in RStudio, use the active document name
        rstudioapi::getActiveDocumentContext()$path |>
          basename()
      } else {
        "Unknown_Script"
      }
    }, error = function(e) "Unknown_Script")
  }
  
  # Compose the log text
  log_text <- c(
    paste0("Date: ", current_date),
    paste0("Script: ", script_name),
    "Package Versions:",
    pkg_versions,
    ""  # Blank line for spacing
  )
  
  # Write to file (append mode)
  con <- file(log_file, open = "a")  # Open in append mode
  writeLines(log_text, con = con)
  close(con)
}
