runFVS_background <- function(runs, RunDirectory, fvs_bin, runFVS){
  library(future)
  library(furrr)
  
  future::plan(multisession,
               workers = parallel::detectCores())
  
  furrr::future_pmap(
    list(
      variant = runs$variant,
      flame_length=runs$flame_length,
      treatment=runs$treatment,
      fire_kcp=runs$fire_kcp
    ),
    runFVS,
    RunDirectory = RunDirectory,
    fvs_bin = fvs_bin
  )
  
  plan(sequential)
}