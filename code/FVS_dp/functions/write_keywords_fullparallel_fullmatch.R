write_keywords_fullparallel_fullmatch <- function(RunDirectory = here::here(),
                                                  database_paths,             # list of directory paths for .db files containing FVS input tables
                                                  stand_subset = "all",       # do you want to create a .key for only a portion of stands in the .db, or "all" of them? default is all, can also supply either a vector of standIDs or a number of randomly-sampled rows to pull from the db
                                                  FSim_scenarios,            # data.frame with simulation parameters    
                                                  treat_kcps = NA,                # file paths for treatment .kcp files
                                                  fire_kcps = NA,                 # file paths for fire .kcp files
                                                  ncycles = 10,              # how many simulation cycles?
                                                  interval = 1, # how many years per cycle?
                                                  
                                                  runtype = "dry", # "wet" means conditioned on variables in the STAND_EXTRA database table; "dry" means unconditioned ; "wet_rx" means same as wet but also adding FL,
                                                  extraStandDat = NULL, #dataframe with extra data for every StandID
                                                  
                                                  fbfm = "default", # default uses normal FVS logic; "fuzzy" constrains FVS matching to LF set, "full" is a full match of all TM-LF combinations
                                                  fbfmDat = NULL, #dataframe with fbfm keys and standID matches
                                                  nworkers = parallel::detectCores() # how many cpus?
) {
  
  # parallelization cross-product
  run_matrix <- tidyr::expand_grid(
    db_path   = database_paths,
    treat_kcp = treat_kcps,
    fire_kcp  = fire_kcps)
  
  future::plan(future.callr::callr, workers = nworkers)
  
  furrr::future_pmap(run_matrix, function(db_path, treat_kcp, fire_kcp) {
    
    variant <-   str_sub(db_path, -5,-4)
    
    # Load stands to iterate over
    
    if(fbfm %in% c("default","fuzzy")){ #use input db standinit table for ids to iterate
      
      con <- dbConnect(SQLite(), db_path)
      standinit <- dbReadTable(con, "FVS_STANDINIT")
      dbDisconnect(con)
      
    } else if (fbfm == "full"){ #use fbfm lookup table filtered to db for ids to iterate
      if(runtype == "dry"){
        
        if(is.null(fbfmDat)){stop("must supply fbfmDat")}
        
        con <- dbConnect(SQLite(), db_path)
        db.in <- dbReadTable(con, "FVS_STANDINIT")
        dbDisconnect(con)
        
        standinit <- fbfmDat %>% 
          rename(Stand_ID = StandID) %>% 
          filter(Stand_ID %in% db.in$Stand_ID)
        
        rm(db.in)
      } else if(runtype == "wet_rx") {
        
        if(is.null(extraStandDat)){stop("must supply extraStandDat")}
        standinit <- extraStandDat
        
      } else if (runtype == "wet"){stop("full FBFM match not implemented for wet runtype")}
      
    } else {stop("'fbfm' arg must be 'default', 'fuzzy', or 'full'")}
    
    
    # Stand subset
    if (identical(stand_subset, "all")) {
      stand.indices <- seq_len(nrow(standinit))
    } else if (length(stand_subset) == 1) {
      if(!is.numeric(stand_subset)){stop("stand_subset must be numeric")}
      stand.indices <- sample(seq_len(nrow(standinit)), stand_subset, FALSE)
    } else {
      stand.indices <- which(standinit$Stand_ID %in% stand_subset)
    }
    
    # Scenario ID parts
    if(is.na(treat_kcp)){
      treatment_name <- "NoTreat"
    } else {treatment_name <- tools::file_path_sans_ext(basename(treat_kcp))}
    
    if(is.na(fire_kcp)){
      fire_name <- "NoWF"
    } else {fire_name <- tools::file_path_sans_ext(basename(fire_kcp))}
    
    scenario_id <- paste0(
      treatment_name, "_", fire_name, "_", variant
    )
    
    message("Params: ",
            "treatment_kcp = ", treat_kcp, 
            "; fire_kcp = ", fire_kcp)
    
    # initialize key text and out path
    
    out_db <- file.path("./outputs", paste0(scenario_id, ".db"))
    key_text_all <- character()
    
    # create key text for every stand, calling the correct function for the scenario and run type
    
    if (!runtype %in% c("dry", "wet", "wet_rx")){
      stop("Runtype must be 'dry', 'wet', or 'wet_rx'")
    }
    
    for (j in stand.indices) {
      
      key = standinit[j,1]
      
      #this is a special case so that we can use extraStandDat as the standinit to iterate over
      if(runtype == "wet_rx" && fbfm == "full"){
        stand <- standinit[j,"TM_StandID"]
      } else {
        stand <- standinit[j,"Stand_ID"]
      }
      
      ## here we decide which key text variant to create
      
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
        } else if (fbfm == "fuzzy") {
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
        } else if (fbfm == "full"){
          stop("full fbfm match not implemented for wet runtype")
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
        } else if (fbfm == "fuzzy"){
          stop("Fuzzy fbfm not implemented for wet_rx runtype")
        } else if (fbfm == "full"){
          
          key_text_all <- c(
            key_text_all,
            createKeyText_wet_fbfm(
              key = key,
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              extraStandDat = extraStandDat[which(extraStandDat$Stand_ID == key),],
              fbfm.list = NULL
            ))
          
        }
        
      } else if (runtype == "dry") {
        if(fbfm == "default"){
          key_text_all <- c(
            key_text_all,
            createKeyText_dry_fbfm(
              key = stand,
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              fbfm.list=NULL))
        } else if (fbfm == "fuzzy") {
          key_text_all <- c(
            key_text_all,
            createKeyText_dry_fbfm(
              key = stand,
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              fbfm.list = fbfmDat[which(fbfmDat[,1] == stand),2]))
        } else if (fbfm == "full"){
          
          key_text_all <- c(
            key_text_all,
            createKeyText_dry_fbfm(
              key = key,
              stand = stand,
              managementID = scenario_id,
              outputDatabase = out_db,
              treat_kcp = treat_kcp,
              fire_kcp = fire_kcp,
              ncycles = ncycles,
              interval = interval,
              inputDatabase = db_path,
              fbfm.list = standinit[which(standinit[,1] == key),"FBFM"]))
          
        } 
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
  }
  )
}
