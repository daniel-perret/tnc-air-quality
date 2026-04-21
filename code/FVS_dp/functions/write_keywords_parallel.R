### This function, written by Laurel Sindewald and Rachel Houtman, and modified by Daniel Perret, writes the keyword file needed for a large multi-stand FVS run.
### Inputs:
### database_paths -- list of directory paths for .db files containing FVS input tables
### stand_subset -- do you want to create a .key for only a portion of stands in the .db, or "all" of them? default is all, can also supply either a vector of standIDs or a number of randomly-sampled rows to pull from the db
### FSim_scenarios -- data.frame containing simulation parameters
### treat_kcps -- file paths for treatment .kcp files
### fire_kcps -- file paths for fire .kcp files

write_keywords_parallel <- function(database_paths,             # list of directory paths for .db files containing FVS input tables
                                    stand_subset = "all",       # do you want to create a .key for only a portion of stands in the .db, or "all" of them? default is all, can also supply either a vector of standIDs or a number of randomly-sampled rows to pull from the db
                                    FSim_scenarios,            # data.frame with simulation parameters    
                                    treat_kcps,                # file paths for treatment .kcp files
                                    fire_kcps,                 # file paths for fire .kcp files
                                    ncycles = 10,              # how many simulation cycles?
                                    interval = 1, # how many years per cycle?
                                    runtype = "dry", # "wet" means conditioned on variables in the STAND_EXTRA database table; "dry" means unconditioned ; "wet_rx" means same as wet but also adding FL
                                    extraStandDat = NULL, #dataframe with extra data for every StandID
                                    nworkers = parallel::detectCores() # how many cpus?
) {
  for(db in seq_along(database_paths)){ # run the function for every variant included in the simulation
    # Load stand data once
    con <- DBI::dbConnect(RSQLite::SQLite(), database_paths[[db]])
    standinit <- DBI::dbReadTable(con, "FVS_STANDINIT")
    DBI::dbDisconnect(con)
    
    #Create a cross-product of scenarios, treatment kcps, and fire kcps
    run_matrix <- expand_grid(
      treat_kcp = treat_kcps,
      fire_kcp = fire_kcps
    )
    
    #set standID indices we want to include in the .key file
    
    if(stand_subset == "all"){
      stand.indices <- 1:nrow(standinit)
    } else if (length(stand_subset)==1) {
      stand.indices <- sample(x = 1:nrow(standinit),
                              size = stand_subset,
                              replace = T)
    } else if (length(stand_subset)>1) {
      stand.indices <- which(standinit$STAND_ID %in% stand_subset)
    }
    
    future::plan(future.callr::callr, 
                 workers = nworkers)
    
    # Create scenario-specific .key and .in files in parallel
    furrr::future_pmap(run_matrix, function(...){
      
      inputs <- list(...)
      
      #Compose a unique scenario ID with flame length, treatment, and fire KCPs
      
      if(is.na(inputs$treat_kcp)){
        treatment_name <- "NoTreat"
      } else {treatment_name <- tools::file_path_sans_ext(basename(inputs$treat_kcp))}
      
      if(is.na(inputs$fire_kcp)){
        fire_name <- "NoWF"
      } else {fire_name <- tools::file_path_sans_ext(basename(inputs$fire_kcp))}
      
      scenario_id <- paste0(treatment_name, "_", fire_name,
                            "_", standinit$Variant[1])
      
      message("Params: ",
              "treatment_kcp = ", inputs$treat_kcp, 
              "; fire_kcp = ", inputs$fire_kcp)
      
      key_text_all <- character()
      
      # #Subset just the parameters from the inputs
      # params_row <- inputs[c(
      #   "flame_length", "fm1", "fm10", "fm100", "fm1000",
      #   "fmduff", "fmlwood", "fmlherb", "wspd_mph", 
      #   "temp_F", "mortality", "per_stand_burned", "season"
      # )]
      
      for (j in stand.indices) {
        stand <- standinit$Stand_ID[j]
        variant <- standinit$Variant[j]
        out_db <- paste0("./outputs/", scenario_id, ".db")
        
        if(runtype == "wet") {
          
          if(is.null(extraStandDat)){stop("For `wet` run, need to supply additional stand variables!")}
          
          key_text_all <- c(
            key_text_all,
            createKeyText_withExtraStandDat(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = inputs$treat_kcp,
              fire_kcp = inputs$fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = database_paths[[db]],
              extraStandDat = extraStandDat[which(extraStandDat$Stand_ID == stand),]
            ))
        } else if (runtype == "wet_rx") {
          
          if(is.null(extraStandDat)){stop("For `wet` run, need to supply additional stand variables!")}
          
          key_text_all <- c(
            key_text_all,
            createKeyText_withExtraStandDat_rx(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = inputs$treat_kcp,
              fire_kcp = inputs$fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = database_paths[[db]],
              extraStandDat = extraStandDat[which(extraStandDat$Stand_ID == stand),]
            ))
        } else {
          key_text_all <- c(
            key_text_all,
            createKeyText2(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = inputs$treat_kcp,
              fire_kcp = inputs$fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = database_paths[[db]]))
        }
      }
      
      # Append STOP
      key_text_all <- c(key_text_all, "STOP\n")
      
      # Write output
      key_file <- file.path(RunDirectory, paste0(scenario_id, ".key"))
      writeLines(key_text_all, key_file)
      
      ## Write .in file 
      fvs_in <- paste0(
        scenario_id, ".key\n",
        scenario_id, ".fvs\n",
        scenario_id, ".out\n",
        scenario_id, ".trl\n",
        scenario_id, ".sum\n"
      )
      
      in_file <- file.path(RunDirectory, paste0(scenario_id, ".in"))
      writeLines(fvs_in, in_file)
      
    })
  }
  
  future::plan(sequential)
  
}
