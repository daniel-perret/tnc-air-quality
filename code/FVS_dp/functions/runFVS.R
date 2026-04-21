##### This function, written by Laurel Sindewald and modified by Daniel Perret, runs a single FVS simulation with .key and .kcp set from directory, using rFVS::fvsRun()

runFVS <- function(variant,       # FVS Variant, two-letter lowercase abbreviation (e.g., "ec")
                   flame_length,  # this references a specific fire .kcp scenario
                   treatment = "NoTreat",     # a treatment scenario
                   fire_kcp,      # a .kcp file containing parameters for the fire event in the simulation
                   RunDirectory,  # the directory containing .kcp, .key, .in, .out, and Output folders/directories
                   fvs_bin        # file path for the fvs .dlls
                   ) {
  withr::with_dir(RunDirectory, {
    # Load the variant DLL
    rFVS::fvsLoad(
      fvsProgram = paste0("FVS", variant, ".dll"),
      bin = fvs_bin
    )
    
    # Set the command line (keyword file)
    # note: can't pass object to fvsSetCmdLine(), need to pass string directly
    keyfile <- sprintf("--keywordfile=%s_%s_%s.key", treatment, fire_kcp, toupper(variant))
    
    print(keyfile)
    
    rFVS::fvsSetCmdLine(
      cl = keyfile,
      PACKAGE = paste0("FVS", tolower(variant))
    )
    
    # Run FVS until done — IMPORTANT: pass PACKAGE here too!
    retCode <- 0
    while (retCode == 0) {
      retCode <- rFVS::fvsRun(PACKAGE = paste0("FVS", tolower(variant)))
    }
  }
  )
  # Explicitly return useful info:
  list(
    variant = variant,
    flame_length = flame_length,
    treatment = treatment,
    status = retCode
  )
}