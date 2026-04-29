write_keywords_fullparallel <- function(database_paths,             # list of directory paths for .db files containing FVS input tables
                                    stand_subset = "all",       # do you want to create a .key for only a portion of stands in the .db, or "all" of them? default is all, can also supply either a vector of standIDs or a number of randomly-sampled rows to pull from the db
                                    FSim_scenarios,            # data.frame with simulation parameters    
                                    treat_kcps,                # file paths for treatment .kcp files
                                    fire_kcps,                 # file paths for fire .kcp files
                                    ncycles = 10,              # how many simulation cycles?
                                    interval = 1, # how many years per cycle?
                                    
                                    runtype = "dry", # "wet" means conditioned on variables in the STAND_EXTRA database table; "dry" means unconditioned ; "wet_rx" means same as wet but also adding FL,
                                    extraStandDat = NULL, #dataframe with extra data for every StandID
                                    
                                    fbfm = "default", # default uses normal FVS logic; "landfire" uses a data.frame of standID and LF FBFM40 assignments, defined in variable below
                                    fbfmDat = NULL, #dataframe with two rows, first is standIDs and second is fuel models, multiple rows per standID
                                    
                                    nworkers = parallel::detectCores() # how many cpus?
) {
  
  # parallelization cross-product
  run_matrix <- tidyr::expand_grid(
    db_path   = database_paths,
    treat_kcp = treat_kcps,
    fire_kcp  = fire_kcps
  )
  
  future::plan(future.callr::callr, workers = nworkers)
  
  furrr::future_pmap(run_matrix, function(db_path, treat_kcp, fire_kcp) {
    
    # Load stand data for this DB
    con <- dbConnect(SQLite(), db_path)
    standinit <- dbReadTable(con, "FVS_STANDINIT")
    dbDisconnect(con)
    
    # Stand subset
    if (identical(stand_subset, "all")) {
      stand.indices <- seq_len(nrow(standinit))
    } else if (length(stand_subset) == 1) {
      stand.indices <- sample(seq_len(nrow(standinit)), stand_subset, TRUE)
    } else {
      stand.indices <- which(standinit$STAND_ID %in% stand_subset)
    }
    
    # Scenario ID parts
    treatment_name <- if (is.na(treat_kcp)) "NoTreat"
    else tools::file_path_sans_ext(basename(treat_kcp))
    
    fire_name <- if (is.na(fire_kcp)) "NoWF"
    else tools::file_path_sans_ext(basename(fire_kcp))
    
    scenario_id <- paste0(
      treatment_name, "_", fire_name, "_", standinit$Variant[1]
    )
    
    message("Params: ",
            "treatment_kcp = ", treat_kcp, 
            "; fire_kcp = ", fire_kcp)
    
    out_db <- file.path("./outputs", paste0(scenario_id, ".db"))
    key_text_all <- character()
    
    # create key text for every stand, calling the correct function for the scenario and run type
    
    for (j in stand.indices) {
      stand <- standinit$Stand_ID[j]
      variant <- standinit$Variant[j]

      if(runtype == "wet") {
        
        if(is.null(extraStandDat)){stop("For `wet` run, need to supply additional stand variables!")}
        
        if(fbfm == "default"){
          key_text_all <- c(
            key_text_all,
            createKeyText_wet_fbfm(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              extraStandDat = extraStandDat[which(extraStandDat$Stand_ID == stand),],
              fbfm.list = NULL
            ))
        } else if (fbfm == "landfire") {
          key_text_all <- c(
            key_text_all,
            createKeyText_wet_fbfm(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              extraStandDat = extraStandDat[which(extraStandDat$Stand_ID == stand),],
              fbfm.list = fbfmDat[which(fbfmDat[,1] == stand),2]
            ))
        }
        
      } else if (runtype == "wet_rx") {
        
        if(is.null(extraStandDat)){stop("For `wet` run, need to supply additional stand variables!")}
        if(!"FLEN_init" %in% names(extraStandDat)){stop("For `wet_rx` run, need to supply `FLEN_init` in extraStandDat!")}
        
        if (fbfm == "default"){
          key_text_all <- c(
            key_text_all,
            createKeyText_wet_fbfm(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              extraStandDat = extraStandDat[which(extraStandDat$Stand_ID == stand),],
              fbfm.list = NULL
            ))
        } else if (fbfm == "landfire"){
          if(is.null(fbfmDat)){stop("Must supply Landfire FBFM information!")}
          
          key_text_all <- c(
            key_text_all,
            createKeyText_wet_fbfm(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              extraStandDat = extraStandDat[which(extraStandDat$Stand_ID == stand),],
              fbfm.list = fbfmDat[which(fbfmDat[,1] == stand),2]
            ))
        }
        
      } else if (runtype == "dry") {
        if(fbfm == "default"){
          key_text_all <- c(
            key_text_all,
            createKeyText_dry_fbfm(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              fbfm.list=NULL))
        } else if (fbfm == "landfire") {
          key_text_all <- c(
            key_text_all,
            createKeyText_dry_fbfm(
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              fbfm.list = fbfmDat[which(fbfmDat[,1] == stand),2]))
        }
      } else {
        stop("Runtype must be 'dry', 'wet', or 'wet_rx'")
      }
    }
    
    #append stop
    key_text_all <- c(key_text_all, "STOP\n")
    
    # write .key file
    writeLines(
      key_text_all,
      file.path(RunDirectory, paste0(scenario_id, ".key"))
    )
    
    ## write .in file
    writeLines(
      paste0(
        scenario_id, ".key\n",
        scenario_id, ".fvs\n",
        scenario_id, ".out\n",
        scenario_id, ".trl\n",
        scenario_id, ".sum\n"
      ),
      file.path(RunDirectory, paste0(scenario_id, ".in"))
    )
  })
  
  future::plan(sequential)
}
