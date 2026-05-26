### This function, written by Rachel Houtman and Laurel Sindwald and modified by Daniel Perret, writes the core keyword text for an FVS run. This function is intended to be called from another "write_keywords" function that iterates across all stands included in the simulation.

createKeyText_withExtraStandDat_FBFMmatch_rx <- function(stand,            # Unique stand ID present in the standinit data
                                                         managementID,     # identifier for management scenario
                                                         outputDatabase,   # .db for simulation output
                                                         treat_kcp,        # optional .kcp specifying treatment
                                                         fire_kcp,         # optional .kcp specifying fire
                                                         ncycles = 10,     # How many simulation cycles to carry out
                                                         interval = 1,     # How many years in each cycle?
                                                         inputDatabase,     # .db with all input tables
                                                         extraStandDat, # row from extra stand dataframe
                                                         fbfm.list # vector of fuel models to be made available for the stand
                                                         ) {
  
  all.fbfm <- c(101:108,121:124,141:149,161:165,181:189,201:204)
  fmodlist <- paste0()
  
  for(fbfm in all.fbfm){
    fmodlist <- paste0(fmodlist,
                       'FMODLIST           0           ',fbfm,'           ',ifelse(fbfm%in%fbfm.list,0,1),'\n')}
  
  keytext <- paste0(
    'STDIDENT\n', stand, '\n',
    'STANDCN\n', stand, '\n',
    'MGMTID\n', managementID, '\n',
    'NUMCYCLE        ', ncycles, '\n',
    'TIMEINT         0        ', interval, '\n',
    'SCREEN\n',
    'DataBase\n',
    'DSNout\n', outputDatabase, '\n',
    'SUMMARY\n',
    'COMPUTDB\n',
    'CALBSTDB\n',
    
    # ---- Report Database Output ----
    'BURNREDB\n',
    'CARBREDB\n',
    'DWDCVDB\n',
    'FUELREDB\n',
    'FUELSOUT\n',
    'MORTREDB\n',
    'POTFIRDB\n',
    # 'SNAGOUDB\n',
    # 'SNAGSUDB\n',
    'STRCLSDB\n',
    #'CutLiDB           2         2         2\n',
    #'TreeLiDB          2         2         2\n',
    'End\n',
    
    # ---- Input DB Queries ----
    'DATABASE\n',
    'DSNIN\n', inputDatabase, '\n',
    'StandSQL\n',
    "SELECT * FROM FVS_StandInit\n",
    "WHERE  Stand_ID  = '%stand_cn%'\n",
    'EndSQL\n',
    'DSNIN\n', inputDatabase, '\n',
    'TreeSQL\n',
    'SELECT * FROM FVS_TreeInit\n',
    'WHERE Stand_ID = (SELECT Stand_ID FROM FVS_StandInit\n',
    "WHERE Stand_ID = '%stand_cn%')\n",
    'EndSQL\n',
    'END\n',
    
    # ---- COMPUTE block with scenario inputs ----
    'COMPUTE            0\n',
    'SEV_FL = POTFLEN(1)\n',
    'MOD_FL = POTFLEN(2)\n',
    'scenario = 1\n',
    'CC = acancov\n',
    'FML = fuelmods(1,1)\n',
    'FLEN_init = ', extraStandDat$FLEN_init, '\n',
    'CHT_init = ', extraStandDat$CHT_init, '\n',      # These are the the "wet" variables from the initial "dry" run
    'CBH_init = ', extraStandDat$CBH_init, '\n',
    'CBD_init = ', extraStandDat$CBD_init, '\n',
    'YR = year\n',
    'END\n',
    
    # ---- Fire Reports ----
    'FMIN\n',
    'BURNREPT\n',
    # 'CanFProf\n',
    # 'CarbRept\n',
    # 'DWDCvOut\n',
    'FUELREPT\n',
    'FUELOUT\n',
    'MORTREPT\n',
    'POTFIRE\n',
    # 'SNAGOUT\n',
    # 'SNAGSUM\n',
    'FIRECALC           0         1        1\n',  # last arg is 2=53 FBFM, 1=40; which matches Flamstat better?
    fmodlist, # defined above
    # 'STATFUEL\n',
    'END\n',
    
    # ---- Tree outputs and classification ----
    # 'TreeList        1\n',
    # 'TreeList        2\n',
    # 'TreeList        3\n',
    # 'CALBSTAT\n',
    # 'CutList\n',
    'STRCLASS           1     30.00        5.       16.     20.00       50.     35.00\n')
  
  if(!is.na(treat_kcp)){
    keytext <- paste0(keytext,
                      'OPEN              81\n',
                      treat_kcp, '\n',
                      'ADDFILE           81\n',
                      'CLOSE             81\n')}
  
  if(!is.na(fire_kcp)){
    keytext <- paste0(keytext,
                      'OPEN              81\n',
                      fire_kcp, '\n',
                      'ADDFILE           81\n',
                      'CLOSE             81\n')}
  
  keytext <- paste0(keytext, 'Process\n\n')
  
  keytext

}
