future::plan(future.callr::callr, 
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