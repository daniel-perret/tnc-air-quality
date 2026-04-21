##### This is a function written by Rachel Houtman and Laurel Sindewald, and modified by Daniel Perret, that writes .kcp files for wildfire events in FVS. The idea here is to create a dataframe with all the different event types we're interested in, and have the function automatically write correctly-formatted files for us.
##### 
##### Inputs:
##### params_df <- a data.frame of parameters with the following named columns: fire_year,flame_length,fm1,fm10,fm100,fm1000,fmduff,fmlwood,fmlherb,wspd_mph,temp_F,mortality,per_stand_burned,season
##### output_dir <- the directory into which all auto-generated the .kcp files will be written
##### base_filename <- stem for output file names



write_kcps_wildfire <- function(params_df, 
                                output_dir = "./kcps", 
                                base_filename = "FlameAdjust"
                                ) {
  
  # create output directory if it doesn't already exist
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  
  # make sure parameter df has the correct inputs
  input_names <- c("fire_year",
                   "flame_length",
                   "fm1","fm10","fm100","fm1000",
                   "fmduff","fmlwood","fmlherb",
                   "wspd_mph","temp_F",
                   "mortality",
                   "per_stand_burned",
                   "season")
  
  if(!all(input_names %in% names(params_df))) {
    stop("CHECK YOUR PARAMETERS! You must include: ", paste0(input_names, collapse=", "))
  }
  
  # loop through every row of the parameter dataframe
  for (i in 1:nrow(params_df)) {
    
    p <- params_df[i, ]
    
    # Build the kcp text with hardcoded values
    kcp_text <- paste0(
      "!! Auto-generated wildfire KCP file based on scenario ", i, "\n",
      "!! The following variables and values were hard-coded from input parameters: \n",
      
      "!! ", paste0(names(p), collapse = ", "), "\n",
      "!! ", paste0(p, collapse = ", "), "\n\n", 
      
      "*Keyword | Field 1 | Field 2 | Field 3 | Field 4 | Field 5 | Field 6 | Field 7 |\n",
      "* -------+---------+---------+---------+---------+---------+---------+---------+\n",
      
      "COMPUTE           ",p$fire_year,"\n",
      "FLEN = ", p$flame_length, "\n",
      "CPC = 0  \n",
      "HSM = 6.026 * (FLEN / 3.2808) ** 1.4466\n",
      "HS_ = HSM * 3.2808\n",
      
      "IF                0\n",
      "CBD_init GT 0.0001\n",
      "THEN\n",
      "Io_ = (0.010 * CBH_init * 0.3048 * (460.0 + 25.9 * 100)) ** (3 / 2)\n",
      "FLCRIT = (0.07749 * Io_ ** 0.46) * 3.281\n",
      "FLCRIT2 = 0.3 * CHT_init\n",
      "FSLOPE = 0.9 / (FLCRIT2 - FLCRIT)\n",
      "NTERCEPT = 1.0 - (FSLOPE * FLCRIT2)\n",
      "Y_ = MAX((FLEN * FSLOPE + NTERCEPT), 0.0)\n",
      "YSQRT = SQRT(Y_)\n",
      "fplace = maxindex(FLEN, FLCRIT)\n",
      "CPC = (INDEX(fplace, MIN(YSQRT, 1), 0)) * 100\n",
      "Done = 1\n",
      "END\n",

      "FMIN\n",
      "!! Fuel moisture by size class\n",
      "!!moisture     year       1hr      10hr     100hr    1000hr      duff   lvwoody    lvherb\n",
      "MOISTURE          ", p$fire_year, "         ",
      p$fm1, "         ", p$fm10, "       ", p$fm100, "       ",
      p$fm1000, "        ", p$fmduff, "      ", p$fmlwood, "       ", p$fmlherb, "\n",
      "!! Flame adjustment inputs for flame length scenario\n",
      "FLAMEADJ          ", p$fire_year, "     PARMS(1.0, ", p$flame_length, ", CPC, HS_)\n",
      "!!simfire      year   wind(mph)  moisture    temp(F)  mortality  %burned   season\n",
      "SIMFIRE           ", p$fire_year, "         ",
      p$wspd_mph, "         ", p$moisture, "         ", p$temp_F, "        ", p$mortality, "       ", p$per_stand_burned, "         ", p$season, "\n",
      "END\n"
    )
    
    # Write to file
    kcp_filename <- file.path(output_dir, paste0(base_filename, "_wildfire_", p$flame_length, ".kcp"))
    writeLines(kcp_text, con = kcp_filename)
  }
}
