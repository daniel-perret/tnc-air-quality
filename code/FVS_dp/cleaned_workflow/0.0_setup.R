#### libraries and setup code

library(tidyverse)
library(ggplot2)
library(terra)
library(sf)
library(tidyterra)
library(RSQLite)
library(furrr) #For parallelization
library(here)
library(future)
library(stringr)
library(callr)
library(future.callr)

select <- dplyr::select

#### source all FVS helper function

lapply(list.files("/Users/daniel.perret/LOCAL_WORKSPACE/PROJECTS/tnc-air-quality/code/FVS_dp/functions",
                  full.names = T), source)


# setting my preferred ggplot2 theme
theme_set(theme_bw())
theme_update(text = element_text(size=16, color = "black"),
             panel.grid.major = element_blank(),
             panel.grid.minor = element_blank(),
             strip.background = element_blank(),
             panel.border=element_rect(linewidth=1.5))

options(scipen = 9999)

# set variables used in all scripts

fvs_bin = "C:/FVS/FVSSoftware/FVSbin"
