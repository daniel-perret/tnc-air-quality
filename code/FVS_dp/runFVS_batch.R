#!/usr/bin/env Rscript

## ===============================
## Batch runner for SCRIPT 2 only
## ===============================

## ---- 0. Clean startup ----
rm(list = ls())
gc()

## ---- 1. Load required packages ----

library(future)
library(future.callr)
library(furrr)

## ---- 2. Load run inputs produced by SCRIPT 1 ----
## Expect this file to exist in the working directory
inputs <- readRDS("runFVS_inputs.rds")

runs         <- inputs$runs
RunDirectory <- inputs$RunDirectory
fvs_bin      <- inputs$fvs_bin

## ---- 3. Source runFVS definition ----
## Adjust path if runFVS.R lives elsewhere
source("C:/Users/daniel.perret/LOCAL_WORKSPACE/PROJECTS/tnc-air-quality/code/FVS_dp/functions/runFVS.R")

## ---- 4. Execute SCRIPT 2 logic ----

setwd(RunDirectory)

message("Starting batch run at ", Sys.time())

future::plan(
  future.callr::callr,
  workers = parallel::detectCores()-2
)

furrr::future_pmap(
  list(
    variant       = runs$variant,
    flame_length  = runs$flame_length,
    treatment     = runs$treatment,
    fire_kcp      = runs$fire_kcp
  ),
  
  function(...) {
    message("Running combination: ", paste(..., collapse = " | "))
    runFVS(...)
  },
  
  RunDirectory = RunDirectory,
  fvs_bin      = fvs_bin
)

future::plan(sequential)
gc()

message("All futures completed at ", Sys.time())

quit(status = 0)