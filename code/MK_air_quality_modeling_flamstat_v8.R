
# code to do initial foray into air quality impacts


library(raster)
library(sf)
library(terra)
library(tidyterra)
library(tidyverse)
library(ggplot2)
library(leaflet)
library(sfarrow)
library(stats)
library(tmap)
library(ggspatial)
library(jrvFinance)
library(viridis)
library(scales)




# load conditional emissions (from FlamStat)
conditional_emission_baseline <- rast("data/flamstat/conditional_estimated_combined/C_Emissions_FlamStat_NT.tif")
conditional_emission_Rx_fire <- rast("data/flamstat/conditional_estimated_combined/C_Emissions_FlamStat_RxFire.tif")
conditional_emission_thin_burn <- rast("data/flamstat/conditional_estimated_combined/C_Emissions_FlamStat_Mech.tif")

# load burn probability (from FSim)
burn_probability <- rast("FSim_CONUS_rasters/BP_CONUS/BP_CONUS.tif")

# load pyromes
pyromes <- vect("pyromes/Data/Pyromes_CONUS_20200206.shp")


i <- 1
for(i in 1:nrow(pyromes)){
  time_1 <- Sys.time()
  # filter to just pyrome in question
  pyrome <- pyromes[i,] %>% project(crs("EPSG:5070"))
  
  # print out pyrome output
  print(paste(pyrome$PYROME, pyrome$NAME))
  
  # filter conditional emissions to just the pyrome boundary
  pyrome_conditional_emission_baseline <- conditional_emission_baseline %>% crop(pyrome, mask = T)
  pyrome_conditional_emission_Rx_fire <- conditional_emission_Rx_fire %>% crop(pyrome, mask = T)
  pyrome_conditional_emission_thin_burn <- conditional_emission_thin_burn %>% crop(pyrome, mask = T)
  
  gc()
  
  # filter burn probability to just the pyrome boundary
  pyrome_burn_probability <- burn_probability %>% crop(pyrome, mask = T)
  
  gc()
  
  ## multiply conditional emissions by burn probability to get annual expected emissions ##
  pyrome_estimated_annual_emission_baseline <- pyrome_conditional_emission_baseline * pyrome_burn_probability
  pyrome_estimated_annual_emission_Rx_fire <- pyrome_conditional_emission_Rx_fire * pyrome_burn_probability
  pyrome_estimated_annual_emission_thin_burn <- pyrome_conditional_emission_thin_burn * pyrome_burn_probability
  
  rm(pyrome_conditional_emission_baseline)
  rm(pyrome_conditional_emission_Rx_fire)
  rm(pyrome_conditional_emission_thin_burn)
  gc()
  
  # write out rasters
  writeRaster(pyrome_estimated_annual_emission_baseline, 
              paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/baseline/pyrome_estimated_annual_emission_baseline_pyrome_", pyrome$PYROME, ".tif"), overwrite = T)
  writeRaster(pyrome_estimated_annual_emission_Rx_fire, 
              paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/Rx_fire/pyrome_estimated_annual_emission_Rx_fire_pyrome_", pyrome$PYROME, ".tif"), overwrite = T)
  writeRaster(pyrome_estimated_annual_emission_thin_burn, 
              paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/thin_burn/pyrome_estimated_annual_emission_thin_burn_pyrome_", pyrome$PYROME, ".tif"), overwrite = T)
  
  
  
  ## get difference from baseline to treated ##
  pyrome_estimated_annual_emission_diff_Rx_fire <- pyrome_estimated_annual_emission_Rx_fire - pyrome_estimated_annual_emission_baseline
  pyrome_estimated_annual_emission_diff_thin_burn <- pyrome_estimated_annual_emission_thin_burn - pyrome_estimated_annual_emission_baseline
  
  # write out rasters
  writeRaster(pyrome_estimated_annual_emission_diff_Rx_fire, 
              paste0("pyrome_level_flamstat_output/annual_estimated_emissions_diff_pyromes/Rx_fire/pyrome_estimated_annual_emission_diff_Rx_fire_pyrome_", pyrome$PYROME, ".tif"), overwrite = T)
  writeRaster(pyrome_estimated_annual_emission_diff_thin_burn, 
              paste0("pyrome_level_flamstat_output/annual_estimated_emissions_diff_pyromes/thin_burn/pyrome_estimated_annual_emission_diff_thin_burn_pyrome_", pyrome$PYROME, ".tif"), overwrite = T)
  
  # remove files
  rm(pyrome_estimated_annual_emission_baseline)
  rm(pyrome_estimated_annual_emission_Rx_fire)
  rm(pyrome_estimated_annual_emission_thin_burn)
  
  rm(pyrome_estimated_annual_emission_diff_Rx_fire)
  rm(pyrome_estimated_annual_emission_diff_thin_burn)
  
  gc()
  time_2 <- Sys.time()
  
  print(time_2 - time_1)
  
}


# merge together all the rasters

# baseline
pyrome_estimated_annual_emissions_baseline_files <- list.files("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/baseline/", full.names = T)
estimated_annual_emissions_baseline <- pyrome_estimated_annual_emissions_baseline_files %>%
  sprc() %>%
  merge()

writeRaster(estimated_annual_emissions_baseline, "estimated_annual_emissions_baseline.tif")

gc()

# Rx fire
pyrome_estimated_annual_emissions_Rx_fire_files <- list.files("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/Rx_fire/", full.names = T)
estimated_annual_emissions_Rx_fire <- pyrome_estimated_annual_emissions_Rx_fire_files %>%
  sprc() %>%
  merge()

gc()

writeRaster(estimated_annual_emissions_Rx_fire, "estimated_annual_emissions_Rx_fire.tif")

# Thin & burn
pyrome_estimated_annual_emissions_thin_burn_files <- list.files("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/thin_burn/", full.names = T)
estimated_annual_emissions_thin_burn <- pyrome_estimated_annual_emissions_thin_burn_files %>%
  sprc() %>%
  merge()

gc()

writeRaster(estimated_annual_emissions_thin_burn, "estimated_annual_emissions_thin_burn.tif")


# Diff Rx fire
pyrome_estimated_annual_emissions_Rx_fire_diff_files <- list.files("pyrome_level_flamstat_output/annual_estimated_emissions_diff_pyromes/Rx_fire/", full.names = T)
estimated_annual_emissions_Rx_fire_diff <- pyrome_estimated_annual_emissions_Rx_fire_diff_files %>%
  sprc() %>%
  merge()

gc()

writeRaster(estimated_annual_emissions_Rx_fire_diff, "estimated_annual_emissions_Rx_fire_diff.tif")

# Diff Thin burn
pyrome_estimated_annual_emissions_thin_burn_diff_files <- list.files("pyrome_level_flamstat_output/annual_estimated_emissions_diff_pyromes/thin_burn/", full.names = T)
estimated_annual_emissions_thin_burn_diff <- pyrome_estimated_annual_emissions_thin_burn_diff_files %>%
  sprc() %>%
  merge()

gc()

writeRaster(estimated_annual_emissions_thin_burn_diff, "estimated_annual_emissions_thin_burn_diff.tif")


ggplot() + 
  geom_spatraster(data = pyrome_estimated_annual_emission_diff_Rx_fire) + 
  scale_fill_viridis_c()


ggplot() + 
  geom_spatraster(data = pyrome_estimated_annual_emission_diff_thin_burn) + 
  scale_fill_gradient2(
    low = "blue", 
    mid = "white", 
    high = "red", 
    midpoint = 0,
    name = "Emission Difference"
  )


# get risk --------


i <- 1



pyrome_emissions_summary <- 1:nrow(pyromes) %>% lapply(function(i){
  
  print(i)
  # subset to just pyrome in question
  pyrome <- pyromes %>% filter(PYROME == i)
  
  # get rasters of emissions
  emissions_baseline <- rast(paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/baseline/pyrome_estimated_annual_emission_baseline_pyrome_", i, ".tif"))
  emissions_Rx_fire <- rast(paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/Rx_fire/pyrome_estimated_annual_emission_Rx_fire_pyrome_", i, ".tif"))
  emissions_thin_burn <- rast(paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/thin_burn/pyrome_estimated_annual_emission_thin_burn_pyrome_", i, ".tif"))
  
  # Calculate pixel area in acres
  pixel_area_acres <- res(emissions_baseline)[1] * res(emissions_baseline)[2] * 0.000247105  # Convert square meters to acres
  
  # Weight the values by the pixel area
  emissions_baseline_tons <- values(emissions_baseline) * pixel_area_acres
  emissions_Rx_fire_tons <- values(emissions_Rx_fire) * pixel_area_acres
  emissions_thin_burn_tons <- values(emissions_thin_burn) * pixel_area_acres
  
  # Convert from tons to kilograms (1 ton = 907.185 kg)
  baseline_weighted_values_kg <- emissions_baseline_tons * 907.185
  Rx_fire_weighted_values_kg <- emissions_Rx_fire_tons * 907.185
  thin_burn_weighted_values_kg <- emissions_thin_burn_tons * 907.185
  
  # Sum up all the weighted values in kg
  baseline_total_emissions_kg <- sum(baseline_weighted_values_kg, na.rm = TRUE)
  Rx_fire_total_emissions_kg <- sum(Rx_fire_weighted_values_kg, na.rm = TRUE)
  thin_burn_total_emissions_kg <- sum(thin_burn_weighted_values_kg, na.rm = TRUE)
  
  # store info in a data frame
  summary_df <- data.frame(PYROME = pyrome$PYROME, 
                           NAME = pyrome$NAME,
                           baseline_total_annual_expected_emissions_kg = baseline_total_emissions_kg,
                           Rx_fire_total_annual_expected_emissions_kg = Rx_fire_total_emissions_kg,
                           thin_burn_total_annual_expected_emissions_kg = thin_burn_total_emissions_kg) %>%
    mutate(baseline_total_annual_expected_pm25_emissions_kg = baseline_total_annual_expected_emissions_kg * 0.0127,
           Rx_fire_total_annual_expected_pm25_emissions_kg = Rx_fire_total_annual_expected_emissions_kg * 0.0127,
           thin_burn_total_annual_expected_pm25_emissions_kg = thin_burn_total_annual_expected_emissions_kg * 0.0127)
  
  return(summary_df)
}) %>% bind_rows()

saveRDS(pyrome_emissions_summary, "R_objects/pyrome_emissions_summary_FlamStat")


pyrome_emissions_summary <- readRDS("R_objects/pyrome_emissions_summary_FlamStat")


(pyrome_emissions_summary %>%
  filter(NAME == "Northern Sierra Nevada") %>%
  pull(baseline_total_annual_expected_pm25_emissions_kg)) * 0.00110231

pyrome_emissions_summary$baseline_total_annual_expected_emissions_kg
pyrome_emissions_summary$Rx_fire_total_annual_expected_emissions_kg

pyrome_emissions_summary %>%
  mutate(prop_reduction_Rx = Rx_fire_total_annual_expected_emissions_kg / baseline_total_annual_expected_emissions_kg) %>%
  filter(prop_reduction_Rx > 1)

pyromes_emissions <- pyromes %>%
  merge(., pyrome_emissions_summary, by = c("NAME", "PYROME"))

writeVector(pyromes_emissions, "R_objects/pyromes_emissions.gpkg", overwrite = T)


# link up with source receptor matrices -------

#load pyrome total emissions back in
pyromes_emissions <- vect("R_objects/pyromes_emissions.gpkg")
sum(pyromes_emissions$baseline_total_annual_expected_pm25_emissions_kg) * 0.00110231
california <- us_states %>% filter(STATEFP == "06") %>% vect()

pyromes_california <- pyromes_emissions %>% terra::intersect(california)
(pyromes_california$baseline_total_annual_expected_pm25_emissions_kg %>% sum()) * 0.00110231

leaflet() %>%
  addTiles() %>%
  addPolygons(data = california %>% project("WGS84")) %>%
  addPolygons(data = pyromes_california %>% project("WGS84"))

(pyromes_california$baseline_total_annual_expected_pm25_emissions_kg %>% sum()) / (55 * 1000000)


(pyromes_california$baseline_total_annual_expected_pm25_emissions_kg %>% sum()) 
# get area of each pyrome
pyromes_emissions %>% names()
pyromes_emissions_area <- pyromes_emissions
pyromes_emissions_area$area_km2 <- as.numeric(expanse(pyromes_emissions, "m")) / 1e6
pyromes_emissions_area <- pyromes_emissions_area %>%
  mutate(pm25_kg_km2_baseline = baseline_total_annual_expected_pm25_emissions_kg / area_km2,
         pm25_kg_km2_Rx_fire = Rx_fire_total_annual_expected_pm25_emissions_kg / area_km2,
         pm25_kg_km2_thin_burn = thin_burn_total_annual_expected_pm25_emissions_kg / area_km2) %>%
  mutate(diff_pm25_kg_km2_from_Rx_fire = pm25_kg_km2_Rx_fire - pm25_kg_km2_baseline,
         diff_pm25_kg_km2_from_thin_burn = pm25_kg_km2_thin_burn - pm25_kg_km2_baseline)



pyromes_emissions_area %>%
  ggplot() + 
  geom_point(aes(x = baseline_total_annual_expected_pm25_emissions_kg, y = Rx_fire_total_annual_expected_pm25_emissions_kg)) + 
  geom_abline(slope = 1, intercept = 0)

pyromes_emissions_area %>% 
  #filter(PYROME %in% 1:10) %>%
  ggplot() + 
  geom_sf(aes(fill = pm25_kg_km2_baseline), color = NA) +
  scale_fill_viridis_c(option = "plasma") + 
  theme_void() +
  ggtitle("Baseline emissions")

# Define signed log10 transformation
signed_log10 <- function(x) sign(x) * log10(1 + abs(x))

# Original scale breaks and labels
breaks_raw <- c(-100, -10, -1, 0, 1, 10, 100)
breaks_log <- signed_log10(breaks_raw)

pyromes_emissions_area %>%
  mutate(
    diff_pm25_log = signed_log10(diff_pm25_kg_km2_from_Rx_fire)
  ) %>%
  ggplot() + 
  geom_sf(aes(fill = diff_pm25_log), color = NA) +
  scale_fill_gradient2(
    low = "blue",
    mid = "white",
    high = "red",
    midpoint = 0,
    name = "PM2.5 Δ (kg/km²)",
    breaks = breaks_log,
    labels = breaks_raw
  ) +
  theme_void() +
  ggtitle("Change in expected fire emissions post-Rx treatment/n(log-scaled)")

pyromes_emissions_area %>%
  mutate(
    diff_pm25_log = signed_log10(diff_pm25_kg_km2_from_thin_burn)
  ) %>%
  ggplot() + 
  geom_sf(aes(fill = diff_pm25_log), color = NA) +
  scale_fill_gradient2(
    low = "blue",
    mid = "white",
    high = "red",
    midpoint = 0,
    name = "PM2.5 Δ (kg/km²)",
    breaks = breaks_log,
    labels = breaks_raw
  ) +
  theme_void() +
  ggtitle("Change in expected fire emissions Thin burn treatment/n(log-scaled)")


# how much emissions does a pyrome have relative to the benchmark 1000 kg / km2
pyromes_emissions_multiplier <- pyromes_emissions_area %>% as.data.frame() %>%
  mutate(emissions_multiplier_baseline = pm25_kg_km2_baseline / 1000,
         emissions_multiplier_Rx_fire = pm25_kg_km2_Rx_fire / 1000,
         emissions_multiplier_thin_burn = pm25_kg_km2_thin_burn / 1000) %>%
  dplyr::select(NAME, 
                emissions_multiplier_baseline,
                emissions_multiplier_Rx_fire,
                emissions_multiplier_thin_burn) %>%
  rename("PyromeName" = "NAME")




saveRDS(pyromes_emissions_multiplier, "R_objects/pyromes_emissions_multiplier")

pyromes_emissions_multiplier <- readRDS("R_objects/pyromes_emissions_multiplier")





# load resulting concentrations from InMAP 
air_quality_gridded <- st_read_parquet("InMAP_source_receptors/Wildfire_pyromes_inmap_steady_gridded.parquet")
# air_quality_gridded <- st_read_parquet("C:/Users/mark.kreider/Box/Mark's Folder/AirQuality/Analysis/InMAP_source_receptors") # old filepath

crs(air_quality_gridded)



# load US states
us_states <- st_read("US_states/cb_2018_us_state_20m.shp") %>%
  filter(!STUSPS %in% c("AK", "PR", "HI")) %>%
  st_transform(crs("EPSG:5070"))

us_states_df <- 
  us_states %>% as.data.frame() %>%
  dplyr::select(STATEFP, STUSPS, NAME) %>%
  rename("state" = STUSPS,
         "state_name" = NAME)

# mortality data
# country polygons 
counties <- st_read("cb_2018_us_county_500k/cb_2018_us_county_500k.shp" ) %>%
  st_transform(st_crs("EPSG:5070"))


mortality_data_raw <- read.csv("mortality_data/data_multiple_causes_death_2018-2023.csv") %>%
  rename("county" = "County",
         "county_code" = "County.Code",
         "deaths" = "Deaths",
         "population" = "Population",
         "rate_per_100000" = "Crude.Rate") %>%
  mutate(GEOID = ifelse(nchar(county_code) == 4, paste0("0", county_code), county_code))

# deal with NA data in mortality date
mortality_data_raw %>% filter(is.na(rate_per_100000))

# mortality rates are pretty normally distributed...
mortality_data_raw %>% 
  ggplot() + 
  geom_density(aes(x = rate_per_100000))

#... assign mean mortality rate to missing NA values
mortality_data <- mortality_data_raw %>%
  mutate(rate_per_100000 = ifelse(rate_per_100000 %>% is.na(), 
                                  mean(rate_per_100000, na.rm = T),
                                  rate_per_100000))



mortality_data_spatial <- mortality_data %>%
  merge(counties, ., by = "GEOID") 

st_write(mortality_data_spatial, "R_objects/mortality_data_spatial.gpkg")



# filter concentrations to just those from a single pyrome
air_quality_gridded_example <- air_quality_gridded %>%
  filter(PyromeName %in% c("Southern Rockies Front Range")) %>%
  st_transform(crs("EPSG:5070"))




# find which grid cells intersect with CONUS
bbox_us_states <- us_states %>% st_bbox %>% st_as_sfc()
intersecting_indices_mat <- st_intersects(air_quality_gridded_example, us_states, sparse = FALSE)

intersecting_indices <- ((intersecting_indices_mat %>% apply(1, sum)) > 0) %>% which()



InMAP_grid_CONUS <- air_quality_gridded_example %>%
  filter(PlumeRiseCode == 1) %>%
  mutate(geom = geometry) %>% 
  dplyr::select(geom) %>%
  vect()




InMAP_grid_CONUS[1:100] 

ggplot() +
  geom_sf(data = InMAP_grid_CONUS[1:1000])


# emissions from treatments -----


emissions_from_treatments <- read.csv("data/flamstat/Treatment_Emissions_FlamStat_2020.csv")
carbon_emissions <- read.csv("data/flamstat/Carbon_emissions/Total_Carbon_Emissions_FlamStat.csv")

emissions_from_treatments %>%
  mutate(kg_pm25_per_km2_from_rx_treatment = Carbon_Released_From_Fire_RxFire_0 * 224170.231 * 0.0127) %>%
  pull(kg_pm25_per_km2_from_rx_treatment) %>%
  density() %>% plot()


kg_per_km2 <- tons_per_acre * 224170.231




# look at treatment emissions relative to carbon emissions savings
trt_emissions_explore <- emissions_from_treatments %>% 
  merge(., carbon_emissions, by = "StandID") 


trt_emissions_explore %>% dplyr::select(Carbon_Released_From_Fire_RxFire_0, Carbon_Released_From_Fire_PostFire_20)

x <- 288
equivalent_flame_length_emissions <- 1:nrow(trt_emissions_explore) %>% lapply(function(x){
  print(x)
  row <- trt_emissions_explore[x,]
  
  untreated_emissions_vec <- c(row$Carbon_Released_From_Fire_PostFire_1,
                               row$Carbon_Released_From_Fire_PostFire_3,
                               row$Carbon_Released_From_Fire_PostFire_5,
                               row$Carbon_Released_From_Fire_PostFire_7,
                               row$Carbon_Released_From_Fire_PostFire_10,
                               row$Carbon_Released_From_Fire_PostFire_20)
  
  Rx_less_than_untreated_index <- (row$Carbon_Released_From_Fire_RxFire_0 < untreated_emissions_vec) %>% which() %>% min()
  thinburn_less_than_untreated_index <- (row$Carbon_Released_From_Fire_Mech_0 < untreated_emissions_vec) %>% which() %>% min() 
  
  
  flamelength_vec <- c(1, 3, 5, 7, 10, 20)
  
  data.frame(StandID = row$StandID,
             flamelength_with_emissions_greater_than_Rx_fire = flamelength_vec[Rx_less_than_untreated_index],
             flamelength_with_emissions_greater_than_thin_burn =flamelength_vec[thinburn_less_than_untreated_index]) %>% return()
  
}) %>% bind_rows()

equivalent_flame_length_emissions$flamelength_with_emissions_greater_than_Rx_fire %>% mean(na.rm = T)
equivalent_flame_length_emissions$flamelength_with_emissions_greater_than_thin_burn %>% mean(na.rm = T)

equivalent_flame_length_emissions$flamelength_with_emissions_greater_than_Rx_fire %>% is.na() %>% mean()
equivalent_flame_length_emissions$flamelength_with_emissions_greater_than_thin_burn %>% is.na() %>% mean()


trt_emissions_explore %>% names()
trt_emissions_explore %>% 
  mutate(carbon_reduction_postRx_1 = Carbon_Released_From_Fire_PostRx_WF_1 - Carbon_Released_From_Fire_PostFire_1,
         carbon_reduction_postRx_3 = Carbon_Released_From_Fire_PostRx_WF_3 - Carbon_Released_From_Fire_PostFire_3,
         carbon_reduction_postRx_5 = Carbon_Released_From_Fire_PostRx_WF_5 - Carbon_Released_From_Fire_PostFire_5,
         carbon_reduction_postRx_7 = Carbon_Released_From_Fire_PostRx_WF_7 - Carbon_Released_From_Fire_PostFire_7,
         carbon_reduction_postRx_10 = Carbon_Released_From_Fire_PostRx_WF_10 - Carbon_Released_From_Fire_PostFire_10,
         carbon_reduction_postRx_20 = Carbon_Released_From_Fire_PostRx_WF_20 - Carbon_Released_From_Fire_PostFire_20) %>%
  dplyr::select(Carbon_Released_From_Fire_RxFire_0, 
                carbon_reduction_postRx_1,
                carbon_reduction_postRx_3,
                carbon_reduction_postRx_5,
                carbon_reduction_postRx_7,
                carbon_reduction_postRx_10,
                carbon_reduction_postRx_20)

# load data -----

# load population density 
population_raster <- rast("RDS-2020-0060-2__CONUS_PopCount/PopCount_CONUS.tif")

x <- 100
InMAP_grid_population_list <- 
  1:nrow(InMAP_grid_CONUS) %>% 
  lapply(function(x){
    print(paste(x, "of", nrow(InMAP_grid_CONUS)))
    InMAP_grid <- InMAP_grid_CONUS[x,]
    
    # Get the extents of both rasters
    extent_population <- ext(population_raster)
    extent_inmap <- ext(InMAP_grid)
    
    # Check if they overlap
    overlap <- terra::intersect(extent_population, extent_inmap)
    
    if(length(overlap) > 0){
      InMAP_grid_pop_raster <- population_raster %>% crop(InMAP_grid, mask = T)
      InMAP_grid_pop <- InMAP_grid_pop_raster %>% values() %>% sum(na.rm = T)
      
      return(InMAP_grid %>% 
               mutate(population = InMAP_grid_pop))
      
    }else{
      return(InMAP_grid %>% 
               mutate(population = as.numeric(NA)))
    }
    
    
    
  }) 

InMAP_grid_population <- 1:length(InMAP_grid_population_list) %>% lapply(function(x){
  print(x)
  InMAP_grid_population_list[x] %>% as.data.frame() %>% return()
  
}) %>% bind_rows()

saveRDS(InMAP_grid_population, "R_objects/InMAP_grid_population_FlamStat")


InMAP_grid_population <- readRDS("R_objects/InMAP_grid_population_FlamStat")

InMAP_grid_population

# why is population higher than total population???
InMAP_grid_population$population %>% sum(na.rm = T)


# get mortality estimates for each cell ------
mortality_data_spatial <- st_read("R_objects/mortality_data_spatial.gpkg")

mortality_data_spatial_terra <- mortality_data_spatial %>% vect()
extent_mortality <- ext(mortality_data_spatial_terra)
x <- 1
InMAP_grid_mortality <- 
  1:nrow(InMAP_grid_CONUS) %>% 
  lapply(function(x){
    print(paste(x, "of", nrow(InMAP_grid_CONUS)))
    InMAP_grid <- InMAP_grid_CONUS[x,]
    
    # Get the extents of grid
    extent_inmap <- ext(InMAP_grid)
    
    # Check if they overlap
    overlap <- terra::intersect(extent_mortality, extent_inmap)
    
    if(length(overlap) > 0){
      overlapping_counties <- terra::intersect(mortality_data_spatial_terra, InMAP_grid) 
      
      
      # select country that is bigger portion of grid cell     
      if(nrow(overlapping_counties) > 1){
        overlapping_counties <- overlapping_counties[which.max(overlapping_counties %>% expanse()),]
        
      }
      
      if(nrow(overlapping_counties) == 0){
        data.frame(geom = InMAP_grid$geom,
                   mortality_rate_per_1000 = NA) %>%
          return()
      }
      
      if(nrow(overlapping_counties) > 0){
        data.frame(geom = InMAP_grid$geom,
                   mortality_rate_per_1000 = overlapping_counties$rate_per_100000) %>%
          return()
      }
    }else{
      return(
        data.frame(geom = InMAP_grid$geom,
                   mortality_rate_per_1000 = NA)
      )
    }
    
    
  })  %>% bind_rows()

saveRDS(InMAP_grid_mortality, "R_objects/InMAP_grid_mortality_FlamStat")

InMAP_grid_mortality <- readRDS("R_objects/InMAP_grid_mortality_FlamStat")



# cycle through all pyromes and get estimated deaths ------

mortality_function <- function(TotalPM25, TotalPop, MortalityRate){
  deaths <- (exp(log(1.14)/10 * TotalPM25) - 1) * TotalPop * 1.0465819687408728 * MortalityRate * 1.025229357798165 / 100000
  
  return(deaths)
}


InMAP_grid_population_mat <- matrix(InMAP_grid_population$population, ncol = 1, dimnames = list(as.character(InMAP_grid_population$cell_id)))
InMAP_grid_mortality_mat <- matrix(InMAP_grid_mortality$mortality_rate_per_1000, ncol = 1, dimnames = list(as.character(InMAP_grid_mortality$cell_id)))


rm(pyromes_emissions, pyromes_emissions_area)

gc()
x <- 16
all_pyromes_deaths <- 
  1:nrow(pyromes) %>% 
  lapply(function(x){
    
    pyrome_name <- pyromes$NAME[x]
    print(paste0(x, ": ", pyrome_name))
    
    # filter concentrations to just those from a single pyrome
    air_quality_gridded_pryome <- air_quality_gridded %>%
      filter(PyromeName == pyrome_name) %>%
      st_transform(crs("EPSG:5070")) %>%
      mutate(total_pm25_concentration_estimated_baseline = TotalPM25 * 
               (pyromes_emissions_multiplier %>% 
                  filter(PyromeName == pyrome_name) %>% 
                  pull(emissions_multiplier_baseline)),
             total_pm25_concentration_estimated_Rx_fire = TotalPM25 * 
               (pyromes_emissions_multiplier %>% 
                  filter(PyromeName == pyrome_name) %>% 
                  pull(emissions_multiplier_Rx_fire)),
             total_pm25_concentration_estimated_thin_burn = TotalPM25 * 
               (pyromes_emissions_multiplier %>% 
                  filter(PyromeName == pyrome_name) %>% 
                  pull(emissions_multiplier_thin_burn))) %>%
      mutate(geom = as.character(geometry)) %>% 
      merge(., InMAP_grid_population, by = "geom") %>%
      merge(., InMAP_grid_mortality, by = "geom") 
    
    air_quality_gridded_pryome_deaths <- air_quality_gridded_pryome %>% 
      mutate(deaths_baseline = mortality_function(TotalPM25 = total_pm25_concentration_estimated_baseline, 
                                                  TotalPop = population, 
                                                  MortalityRate = mortality_rate_per_1000),
             deaths_Rx_fire = mortality_function(TotalPM25 = total_pm25_concentration_estimated_Rx_fire, 
                                                 TotalPop = population, 
                                                 MortalityRate = mortality_rate_per_1000),
             deaths_thin_burn = mortality_function(TotalPM25 = total_pm25_concentration_estimated_thin_burn, 
                                                   TotalPop = population, 
                                                   MortalityRate = mortality_rate_per_1000)) %>%
      as.data.frame() %>%
      dplyr::select(geom, PyromeName, PlumeRiseCode, 
                    total_pm25_concentration_estimated_baseline, 
                    total_pm25_concentration_estimated_Rx_fire,
                    total_pm25_concentration_estimated_thin_burn,
                    population, mortality_rate_per_1000, 
                    deaths_baseline, deaths_Rx_fire, deaths_thin_burn) 
    
    
    return(air_quality_gridded_pryome_deaths)
    
    gc()
    
  }) %>% bind_rows()

gc()
saveRDS(all_pyromes_deaths, "R_objects/all_pyromes_deaths_FlamStat")


all_pyromes_deaths_0 <- all_pyromes_deaths %>% filter(PlumeRiseCode == 0) %>% mutate(deaths_baseline_0 = deaths_baseline) %>% dplyr::select(geom, PyromeName,deaths_baseline_0)
all_pyromes_deaths_1 <- all_pyromes_deaths %>% filter(PlumeRiseCode == 1) %>% mutate(deaths_baseline_1 = deaths_baseline) %>% dplyr::select(geom, PyromeName,deaths_baseline_1)

all_pyromes_deaths_compare <- all_pyromes_deaths_0 %>%
  merge(., all_pyromes_deaths_1, by = c("geom", "PyromeName"))

(all_pyromes_deaths_compare$deaths_baseline_0 >= all_pyromes_deaths_compare$deaths_baseline_1) %>% mean(na.rm = T)

min(c(all_pyromes_deaths_compare$deaths_baseline_0, all_pyromes_deaths_compare$deaths_baseline_1), na.rm = T)


all_pyromes_deaths_compare %>%
  na.omit() %>%
  sample_n(10000) %>%
  ggplot() + 
  geom_point(aes(x = deaths_baseline_1,
                 y = deaths_baseline_0), alpha = 0.03) + 
  theme_classic() + 
  geom_abline(slope = 1, intercept = 0, color = "red") + 
  scale_x_log10() + 
  scale_y_log10() + 
  coord_equal() + 
  labs(x = "Estimated deaths in grid cells (plume rise 1)",
       y = "Estimated deaths in grid cells (plume rise 0")

all_pyromes_deaths_compare %>%
  na.omit() %>%
  sample_n(10000) %>%
  ggplot() + 
  geom_density(aes(x = deaths_baseline_0)) + 
  geom_density(aes(x = deaths_baseline_1), color = "red") + 
  theme_classic() + 
  scale_x_log10() + 
  labs(x = "Estimated deaths in grid cells")

all_pyromes_deaths_compare %>%
  reframe(deaths_baseline_0 = sum(deaths_baseline_0, na.rm = T),
          deaths_baseline_1 = sum(deaths_baseline_1, na.rm = T))


# summary stats ----

all_pyromes_deaths <- readRDS("R_objects/all_pyromes_deaths_FlamStat")

nrow(all_pyromes_deaths)/ 128 / 2

all_pyromes_deaths %>% group_by(PlumeRiseCode) %>% reframe(total_deaths = sum(deaths_baseline, na.rm = T)) 
all_pyromes_deaths %>% group_by(PlumeRiseCode) %>% reframe(total_deaths = sum(deaths_Rx_fire, na.rm = T)) 
all_pyromes_deaths %>% group_by(PlumeRiseCode) %>% reframe(total_deaths = sum(deaths_thin_burn, na.rm = T)) 





example_name <- "Southern Rockies Front Range"

all_pyromes_deaths_example <- all_pyromes_deaths %>%
  filter(PyromeName == example_name) %>%
  merge(InMAP_grid_CONUS,.,  by = "geom")

pm_concetration_fig_example <- ggplot() + 
  geom_sf(data = all_pyromes_deaths_example %>% filter(PlumeRiseCode == 1), 
          aes(fill = total_pm25_concentration_estimated_baseline), color = NA) + 
  geom_sf(data = us_states, fill = NA) + 
  scale_fill_viridis_c(option = "plasma") + 
  theme_void()

ggsave("pm_concetration_fig_example.pdf", plot = pm_concetration_fig_example)

deaths_fig_example <- ggplot() + 
  geom_sf(data = air_quality_gridded_pryome_deaths, 
          aes(fill = deaths), color = NA) + 
  geom_sf(data = us_states, fill = NA) + 
  scale_fill_viridis_c(option = "plasma") +
  theme_void()

ggsave("deaths_fig_example.pdf", plot = deaths_fig_example)


all_pyromes_deaths

grid_deaths <- all_pyromes_deaths %>% 
  group_by(PlumeRiseCode, geom) %>%
  reframe(total_deaths_baseline = sum(deaths_baseline, na.rm = T),
          total_deaths_Rx_fire = sum(deaths_Rx_fire, na.rm = T),
          total_deaths_thin_burn = sum(deaths_thin_burn, na.rm = T),
          total_pm25_concentration_estimated_baseline = sum(total_pm25_concentration_estimated_baseline, na.rm = T),
          total_pm25_concentration_estimated_Rx_fire = sum(total_pm25_concentration_estimated_Rx_fire, na.rm = T),
          total_pm25_concentration_estimated_thin_burn = sum(total_pm25_concentration_estimated_thin_burn, na.rm = T)) %>%
  merge(InMAP_grid_CONUS,.,  by = "geom")

saveRDS(grid_deaths, "R_objects/grid_deaths_FlamStat")
writeVector(grid_deaths %>% rename("geometry" = "geom"), "R_objects/grid_deaths_FlamStat.gpkg", overwrite = T)


grid_deaths <- vect("R_objects/grid_deaths_FlamStat.gpkg")

statistical_value_of_life <- 13.6e6

grid_deaths_cost <- grid_deaths %>%
  mutate(total_death_reduction_Rx_fire = total_deaths_Rx_fire - total_deaths_baseline,
         total_death_reduction_thin_burn = total_deaths_thin_burn - total_deaths_baseline) %>%
  mutate(cost_death_baseline = total_deaths_baseline * statistical_value_of_life,
         cost_death_Rx_fire = total_deaths_Rx_fire * statistical_value_of_life,
         cost_death_thin_burn = total_deaths_thin_burn * statistical_value_of_life,
         cost_reduction_death_Rx_fire = total_death_reduction_Rx_fire * statistical_value_of_life,
         cost_reduction_death_thin_burn = total_death_reduction_thin_burn * statistical_value_of_life)

# deaths by plume rise
death_summary <- grid_deaths %>%
  as.data.frame() %>%
  group_by(PlumeRiseCode) %>%
  reframe(n_deaths_baseline = sum(total_deaths_baseline, na.rm = T),
          n_deaths_Rx_fire = sum(total_deaths_Rx_fire, na.rm = T),
          n_deaths_thin_burn = sum(total_deaths_thin_burn, na.rm = T)) %>%
  mutate(total_death_reduction_Rx_fire = n_deaths_Rx_fire - n_deaths_baseline,
         total_death_reduction_thin_burn = n_deaths_thin_burn - n_deaths_baseline) %>%
  mutate(cost_death_baseline = n_deaths_baseline * statistical_value_of_life,
         cost_death_Rx_fire = n_deaths_Rx_fire * statistical_value_of_life,
         cost_death_thin_burn = n_deaths_thin_burn * statistical_value_of_life,
         cost_reduction_death_Rx_fire = total_death_reduction_Rx_fire * statistical_value_of_life,
         cost_reduction_death_thin_burn = total_death_reduction_thin_burn * statistical_value_of_life)

death_summary$cost_reduction_death_Rx_fire
death_summary %>% 
  mutate(deaths_baseline = round(n_deaths_baseline, 0),
         change_in_deaths_Rx_fire = round(total_death_reduction_Rx_fire, 0),
         change_in_deaths_thin_burn = round(total_death_reduction_thin_burn, 0),
         change_in_cost_Rx_fire_billions = round((cost_reduction_death_Rx_fire / 1e9), 2),
         change_in_cost_thin_burn_billions = round((cost_reduction_death_thin_burn / 1e9), 2)) %>%
  dplyr::select(PlumeRiseCode, deaths_baseline, change_in_deaths_Rx_fire, change_in_deaths_thin_burn,
                change_in_cost_Rx_fire_billions, change_in_cost_thin_burn_billions) %>%
  as.data.frame() 


round((cost_reduction_death_Rx_fire / 1e9), 2)


# deaths by plume rise & pyrome
all_pyromes_deaths %>%
  as.data.frame() %>%
  group_by(PlumeRiseCode, PyromeName) %>%
  reframe(n_deaths_baseline = sum(deaths_baseline, na.rm = T)) %>%
  arrange(desc(n_deaths_baseline))

low_plume_pyromes_death <- all_pyromes_deaths %>%
  as.data.frame() %>%
  filter(PlumeRiseCode == 0) %>%
  group_by(PyromeName) %>%
  reframe(n_deaths_baseline = sum(deaths_baseline, na.rm = T),
          n_deaths_Rx_fire = sum(deaths_Rx_fire, na.rm = T),
          n_deaths_thin_burn = sum(deaths_thin_burn, na.rm = T)) %>%
  mutate(n_death_reduction_Rx_fire = n_deaths_Rx_fire - n_deaths_baseline,
         n_death_reduction_thin_burn = n_deaths_thin_burn - n_deaths_baseline) %>%
  mutate(n_death_cost_reduction_Rx_fire = n_death_reduction_Rx_fire * statistical_value_of_life,
         n_death_cost_reduction_thin_burn = n_death_reduction_thin_burn * statistical_value_of_life) %>%
  arrange(desc(n_deaths_baseline)) %>%
  merge(pyromes %>% st_as_sf() %>% rename("PyromeName" = "NAME"), .,  by = "PyromeName")

high_plume_pyromes_death <- all_pyromes_deaths %>%
  as.data.frame() %>%
  filter(PlumeRiseCode == 1) %>%
  group_by(PyromeName) %>%
  reframe(n_deaths_baseline = sum(deaths_baseline, na.rm = T),
          n_deaths_Rx_fire = sum(deaths_Rx_fire, na.rm = T),
          n_deaths_thin_burn = sum(deaths_thin_burn, na.rm = T)) %>%
  mutate(n_death_reduction_Rx_fire = n_deaths_Rx_fire - n_deaths_baseline,
         n_death_reduction_thin_burn = n_deaths_thin_burn - n_deaths_baseline) %>%
  mutate(n_death_cost_reduction_Rx_fire = n_death_reduction_Rx_fire * statistical_value_of_life,
         n_death_cost_reduction_thin_burn = n_death_reduction_thin_burn * statistical_value_of_life) %>%
  arrange(desc(n_deaths_baseline)) %>%
  merge(pyromes %>% st_as_sf() %>% rename("PyromeName" = "NAME"), .,  by = "PyromeName")


## baseline deaths; Plume 0 ##
ggplot() + 
  geom_sf(data = low_plume_pyromes_death, 
          aes(fill = n_deaths_baseline), 
          color = "grey") + 
  scale_fill_viridis_c(name = "Estimated annual number of deaths", option = "inferno") +
  ggtitle("Baseline scenario (no treatment) | low plume rise") + 
  theme_void()
## baseline deaths cost; Plume 0 ##
ggplot() + 
  geom_sf(data = low_plume_pyromes_death, 
          aes(fill = n_deaths_baseline * statistical_value_of_life / 1e9), 
          color = "grey") + 
  scale_fill_viridis_c(name = "Estimated annual cost of deaths/n(Billions USD)", option = "inferno") +
  ggtitle("Baseline scenario (no treatment) | Plume rise = 0") + 
  theme_void()


## Rx fire; Plume 0 ##
ggplot() + 
  geom_sf(data = low_plume_pyromes_death, 
          aes(fill = n_death_cost_reduction_Rx_fire / 1e6), 
          color = "grey") + 
  scale_fill_gradient2(
    name = "Reduction in costs of death/n(Millions USD)",
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    limits = c(min(low_plume_pyromes_death$n_death_cost_reduction_Rx_fire / 1e6, na.rm = T), 
               max(low_plume_pyromes_death$n_death_cost_reduction_Rx_fire / 1e6, na.rm = T))) +
  ggtitle("After prescribed burning (everywhere) | Plume rise = 0") + 
  theme_void()

ggplot() + 
  geom_sf(data = low_plume_pyromes_death, 
          aes(fill = n_death_reduction_Rx_fire), 
          color = "grey") + 
  ggtitle("After prescribed burning (everywhere) | Plume rise = 0") + 
  scale_fill_gradient2(
    name = "Reduction in deaths",
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    limits = c(min(low_plume_pyromes_death$n_death_reduction_Rx_fire, na.rm = T), 
               max(low_plume_pyromes_death$n_death_reduction_Rx_fire, na.rm = T))) +
  theme_void()

## Thin burn; Plume 0 ##
ggplot() + 
  geom_sf(data = low_plume_pyromes_death, 
          aes(fill = n_death_cost_reduction_thin_burn / 1e6), 
          color = "grey") + 
  scale_fill_gradient2(
    name = "Reduction in costs of death/n(Millions USD)",
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    limits = c(min(low_plume_pyromes_death$n_death_cost_reduction_Rx_fire / 1e6, na.rm = T), 
               max(low_plume_pyromes_death$n_death_cost_reduction_Rx_fire / 1e6, na.rm = T))) +
  ggtitle("After thin & burn (everywhere) | Plume rise = 0") + 
  theme_void()

ggplot() + 
  geom_sf(data = low_plume_pyromes_death, 
          aes(fill = n_death_reduction_thin_burn), 
          color = "grey") + 
  ggtitle("After thin & burn (everywhere) | Plume rise = 0") + 
  scale_fill_gradient2(
    name = "Reduction in deaths",
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    limits = c(min(low_plume_pyromes_death$n_death_reduction_Rx_fire, na.rm = T), 
               max(low_plume_pyromes_death$n_death_reduction_Rx_fire, na.rm = T))) +
  theme_void()






options(scipen = 999)

low_plume_pyromes_death %>%
  as.data.frame() %>%
  select(PyromeName, n_deaths) %>%
  mutate(n_deaths = round(n_deaths, 0)) %>%
  arrange(desc(n_deaths))


high_plume_pyromes_death <- all_pyromes_deaths %>%
  as.data.frame() %>%
  filter(PlumeRiseCode == 1) %>%
  group_by(, PyromeName) %>%
  reframe(n_deaths = sum(deaths, na.rm = T)) %>%
  arrange(desc(n_deaths)) %>%
  merge(pyromes %>% st_as_sf() %>% rename("PyromeName" = "NAME"), ., by = "PyromeName")


high_plume_pyromes_death %>%
  as.data.frame() %>%
  select(PyromeName, n_deaths) %>%
  mutate(n_deaths = round(n_deaths, 0)) %>%
  arrange(desc(n_deaths))

low_plume_pyromes_death_fig_log <- ggplot() + 
  geom_sf(data = low_plume_pyromes_death, 
          aes(fill = n_deaths)) +
  scale_fill_viridis_c(option = "inferno", trans = "log", name = "Deaths (log)") +
  theme_void()

low_plume_pyromes_death_fig <- ggplot() + 
  geom_sf(data = low_plume_pyromes_death, 
          aes(fill = n_deaths)) +
  scale_fill_viridis_c(option = "inferno", name = "Deaths") +
  theme_void()


ggsave("low_plume_pyromes_death_fig_log.pdf", plot = low_plume_pyromes_death_fig_log)
ggsave("low_plume_pyromes_death_fig.pdf", plot = low_plume_pyromes_death_fig)

high_plume_pyromes_death_fig_log <- ggplot() + 
  geom_sf(data = high_plume_pyromes_death, 
          aes(fill = n_deaths)) +
  scale_fill_viridis_c(option = "inferno", trans = "log", name = "Deaths (log)") +
  theme_void()

high_plume_pyromes_death_fig <- ggplot() + 
  geom_sf(data = high_plume_pyromes_death, 
          aes(fill = n_deaths)) +
  scale_fill_viridis_c(option = "inferno", name = "Deaths") +
  theme_void()


ggsave("high_plume_pyromes_death_fig_log.pdf", plot = high_plume_pyromes_death_fig_log)
ggsave("high_plume_pyromes_death_fig.pdf", plot = high_plume_pyromes_death_fig)



### pm2.5 concentration ###
# plumerise 0
pm_concetration_plume0_fig <- ggplot() + 
  geom_sf(data = grid_deaths %>% filter(PlumeRiseCode == 0), 
          aes(fill = total_pm25_concentration_estimated), color = NA) + 
  geom_sf(data = us_states, fill = NA) + 
  scale_fill_viridis_c(option = "plasma") + 
  theme_void()
ggsave("pm_concentration_plume0_fig.pdf", plot = pm_concetration_plume0_fig)

# plumerise 1
pm_concetration_plume1_fig <- ggplot() + 
  geom_sf(data = grid_deaths %>% filter(PlumeRiseCode == 1), 
          aes(fill = total_pm25_concentration_estimated), color = NA) + 
  geom_sf(data = us_states, fill = NA) + 
  scale_fill_viridis_c(option = "plasma") + 
  theme_void()
ggsave("pm_concentration_plume1_fig.pdf", plot = pm_concetration_plume1_fig)


### deaths ###

grid_deaths %>% 
  as.data.frame() %>%
  group_by(PlumeRiseCode) %>% 
  reframe(deaths = sum(total_deaths, na.rm = T))


deaths_plume0_fig <- ggplot() + 
  geom_sf(data = grid_deaths %>% filter(PlumeRiseCode == 0), 
          aes(fill = total_deaths), color = NA) + 
  geom_sf(data = us_states, fill = NA) + 
  scale_fill_viridis_c(option = "plasma", trans = "log") +
  theme_void()
ggsave("deaths_plume0_fig.pdf", plot = deaths_plume0_fig)

deaths_plume1_fig <- ggplot() + 
  geom_sf(data = grid_deaths %>% filter(PlumeRiseCode == 1), 
          aes(fill = total_deaths), color = NA) + 
  geom_sf(data = us_states, fill = NA) + 
  scale_fill_viridis_c(option = "plasma", trans = "log") +
  theme_void()
ggsave("deaths_plume1_fig.pdf", plot = deaths_plume1_fig)



# Define the bounding box for CONUS
bbox <- st_bbox(c(xmin = -125, xmax = -66.5, ymin = 24.5, ymax = 49.5), crs = st_crs(4326))

# Calculate the cell size
cell_size <- (bbox$xmax - bbox$xmin) / 100

# Create a grid
grid <- st_make_grid(st_as_sfc(bbox), cellsize = cell_size, square = TRUE)

# Convert the grid to an sf object
grid_sf <- st_sf(geometry = grid) %>% st_transform(st_crs("EPSG:5070")) %>%
  mutate(grid_id = 1:n())

# Plot the grid
plot(grid_sf)

ggplot() + 
  geom_sf(data = grid_sf) + 
  geom_sf(data = us_states, fill = NA) + 
  theme_void()

grid_deaths_centroids <- grid_deaths %>% 
  terra::centroids() %>%
  merge(., InMAP_grid_population, by = "geom") %>%
  merge(., InMAP_grid_mortality, by = "geom")

grid_deaths_centroids_sf <- grid_deaths_centroids %>% st_as_sf()

x <- 1560
mortality_grid_summary <- 1:nrow(grid_sf) %>% lapply(function(x){
  
  print(x)
  grid_individual <- grid_sf[x,]
  
  
  grid_index <- st_intersects(grid_individual, grid_deaths_centroids_sf, sparse = TRUE) %>% unlist()
  
  grid_deaths_centroids_subset <- grid_deaths_centroids_sf[grid_index,]
  
  mortality_rate <-  weighted.mean(x = grid_deaths_centroids_subset$mortality_rate_per_1000, 
                                   w = grid_deaths_centroids_subset$population, na.rm = T)
  
  grid_summary <- grid_deaths_centroids_subset %>% 
    group_by(PlumeRiseCode) %>%
    reframe(total_deaths = sum(total_deaths, na.rm = T),
            population = sum(population, na.rm = T)) %>%
    mutate(mortality_rate_per_100000 = mortality_rate) %>%
    mutate(grid = grid_individual$grid_id, 
           inMAP_grid_index = paste(grid_deaths_centroids_subset, collapse = "|"))
  
  return(grid_summary)
  
})

mortality_grid_summary_bind_rows <- mortality_grid_summary %>% bind_rows()

saveRDS(mortality_grid_summary_bind_rows, "R_objects/mortality_grid_summary_bind_rows")
mortality_grid_summary_bind_rows <- readRDS("R_objects/mortality_grid_summary_bind_rows")

grid_with_mortality_centroids <- grid_sf %>% 
  merge(., mortality_grid_summary_bind_rows %>% 
          rename("grid_id" = grid), by = "grid_id") %>%
  st_centroid() %>%
  mutate(fire_emissions_deaths_per_100000 = total_deaths / population * 100000) %>%
  st_intersection(us_states)


# total deaths
ggplot() + 
  geom_sf(data = us_states, fill = NA) +
  geom_sf(data = grid_with_mortality_centroids %>% filter(PlumeRiseCode == 0), 
          aes(size = total_deaths , 
              color = total_deaths ,
              alpha = total_deaths),
          shape = 16) + 
  scale_color_viridis_c(option = "inferno") +
  scale_size_continuous(name = "Total deaths", range = c(1, 10)) +  # Adjust the range to make circles smaller
  theme_void() + 
  ggtitle("Low plume rise")

ggplot() + 
  geom_sf(data = us_states, fill = NA) +
  geom_sf(data = grid_with_mortality_centroids %>% filter(PlumeRiseCode == 1), 
          aes(size = total_deaths , 
              color = total_deaths ,
              alpha = total_deaths),
          shape = 16) + 
  scale_color_viridis_c(option = "inferno") +
  scale_size_continuous(name = "Total deaths", range = c(1, 10)) +  # Adjust the range to make circles smaller
  theme_void() + 
  ggtitle("High plume rise")

# deaths per 100000
ggplot() + 
  geom_sf(data = us_states, fill = NA) +
  geom_sf(data = grid_with_mortality_centroids %>% filter(PlumeRiseCode == 0), 
          aes(size = fire_emissions_deaths_per_100000 , 
              color = fire_emissions_deaths_per_100000,
              alpha = fire_emissions_deaths_per_100000 ),
          shape = 16) + 
  scale_color_viridis_c(option = "inferno") +
  scale_size_continuous(name = "Deaths per 100,000", range = c(0.01, 10)) +  # Adjust the range to make circles smaller
  theme_void() + 
  ggtitle("Low plume rise")

ggplot() + 
  geom_sf(data = us_states, fill = NA) +
  geom_sf(data = grid_with_mortality_centroids %>% filter(PlumeRiseCode == 1), 
          aes(size = fire_emissions_deaths_per_100000 ^ 1.3, 
              color = fire_emissions_deaths_per_100000,
              alpha = fire_emissions_deaths_per_100000 ^ 1.3 ),
          shape = 16) + 
  scale_color_viridis_c(option = "inferno") +
  scale_size_continuous(name = "Deaths per 100,000", range = c(0.01, 10)) +  # Adjust the range to make circles smaller
  theme_void() + 
  ggtitle("High plume rise")



leaflet() %>%
  addTiles() %>%
  addPolygons(data = grid_individual %>% st_transform(st_crs("WGS84"))) %>%
  addCircleMarkers(data = test %>% st_transform(st_crs("WGS84")))


# find which grid cells intersect with CONUS
bbox_us_states <- us_states %>% st_bbox %>% st_as_sfc()
intersecting_indices <- st_intersects(air_quality_gridded_example, us_states, sparse = FALSE)

# filter to just intersecting grids
air_quality_gridded_CONUS <- air_quality_gridded_example[apply(intersecting_indices, 1, any), ]


InMAP_grid_CONUS <- air_quality_gridded_CONUS %>%
  filter(PlumeRiseCode == 1) %>%
  mutate(grid_temp_id = 1:n()) %>%
  dplyr::select(grid_temp_id) %>%
  vect()



data.frame(vec = 1:1000)


# combining low / high plume rise from each pyrome



# look at deaths attributable to a single pyrome -------


InMAP_grid_population_mat %>% rownames()

## example case ##

x <- 1


all_pyromes_deaths



single_pyrome <- all_pyromes_deaths %>%
  filter(PyromeName == pyrome) %>%
  filter(PlumeRiseCode == 0) %>%
  merge(InMAP_grid_CONUS, ., by = "geom")


# PM2.5 concentrations
ggplot() + 
  geom_sf(data = single_pyrome, aes(fill = total_pm25_concentration_estimated_baseline), color = NA) + 
  geom_sf(data = us_states, fill = NA) + 
  scale_fill_viridis_c(option = "plasma", na.value = NA, ) + 
  geom_sf(data = pyromes %>% filter(PYROME == pyrome) %>% st_as_sf(), color = "white", 
          fill = NA) + 
  theme_void()

x <- 1


gc()



pyrome <- "Marine Northwest Coast Forest"

rm(air_quality_gridded, air_quality_gridded_example)
rm(pyromes_emissions)


all_pyromes_deaths <- readRDS("R_objects/all_pyromes_deaths_FlamStat")


gc()
x <- 121
for(x in 1:nrow(pyromes)){
  
  print(x)
  time1 <- Sys.time()
  
  single_pyrome <- all_pyromes_deaths %>% 
    filter(PyromeName == pyromes$NAME[x]) %>%
    merge(InMAP_grid_CONUS, ., by = "geom")
  
  ## Plume Rise Code meaning: ##
  # Low Plume Rise: 500m (PlumeRiseCode = 0)
  # High Plume Rise: 3000m (PlumeRiseCode = 1)
  
  
  # total number of deaths
  single_pyrome_num_deaths <- single_pyrome %>% as.data.frame() %>%
    group_by(PlumeRiseCode) %>%
    reframe(deaths_baseline = sum(deaths_baseline, na.rm = T),
            deaths_Rx_fire = sum(deaths_Rx_fire, na.rm = T),
            deaths_thin_burn = sum(deaths_thin_burn, na.rm = T))
  
  # get polygon of pyrome
  single_pyrome_polygon <- pyromes[x,]
  
  
  ### PLUME 0 ###
  
  ## baseline ##
  
  # get emissions for just single pyrome
  pyrome_estimated_annual_emission_baseline <- rast(paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/baseline/pyrome_estimated_annual_emission_baseline_pyrome_", single_pyrome_polygon$PYROME, ".tif"))
  
  # get proportion that each pixel contributes to total pyrome emission
  pyrome_estimated_annual_emission_baseline_proportion <- pyrome_estimated_annual_emission_baseline / sum(values(pyrome_estimated_annual_emission_baseline), na.rm = T)
  
  # allocate risk (number of deaths) by the proportion of emissions
  pyrome_deaths_baseline_0 <- pyrome_estimated_annual_emission_baseline_proportion * (single_pyrome_num_deaths %>% filter(PlumeRiseCode == 0) %>% pull(deaths_baseline))
  
  # write raster
  writeRaster(pyrome_deaths_baseline_0, paste0("R_objects/allocated_risk_pyromes_plume_0/baseline/pyrome_deaths_baseline_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  # remove files
  rm(pyrome_deaths_baseline_0)
  gc()
  
  # allocate risk (number of deaths) by the proportion of emissions
  pyrome_deaths_baseline_1 <- pyrome_estimated_annual_emission_baseline_proportion * (single_pyrome_num_deaths %>% filter(PlumeRiseCode == 1) %>% pull(deaths_baseline))
  
  # write raster
  writeRaster(pyrome_deaths_baseline_1, paste0("R_objects/allocated_risk_pyromes_plume_1/baseline/pyrome_deaths_baseline_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  
  rm(pyrome_estimated_annual_emission_baseline, pyrome_estimated_annual_emission_baseline_proportion, pyrome_deaths_baseline_1)
  gc()
  
  ## Rx fire ##
  
  # get emissions for just single pyrome
  pyrome_estimated_annual_emission_Rx_fire <- rast(paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/Rx_fire/pyrome_estimated_annual_emission_Rx_fire_pyrome_", single_pyrome_polygon$PYROME, ".tif"))
  
  # get proportion that each pixel contributes to total pyrome emission
  pyrome_estimated_annual_emission_Rx_fire_proportion <- pyrome_estimated_annual_emission_Rx_fire / sum(values(pyrome_estimated_annual_emission_Rx_fire), na.rm = T)
  
  # allocate risk (number of deaths) by the proportion of emissions
  pyrome_deaths_Rx_fire_0 <- pyrome_estimated_annual_emission_Rx_fire_proportion * (single_pyrome_num_deaths %>% filter(PlumeRiseCode == 0) %>% pull(deaths_Rx_fire))
  
  # write raster
  writeRaster(pyrome_deaths_Rx_fire_0, paste0("R_objects/allocated_risk_pyromes_plume_0/Rx_fire/pyrome_deaths_Rx_fire_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  # remove files
  rm(pyrome_deaths_Rx_fire_0)
  gc()
  
  # allocate risk (number of deaths) by the proportion of emissions
  pyrome_deaths_Rx_fire_1 <- pyrome_estimated_annual_emission_Rx_fire_proportion * (single_pyrome_num_deaths %>% filter(PlumeRiseCode == 1) %>% pull(deaths_Rx_fire))
  
  # write raster
  writeRaster(pyrome_deaths_Rx_fire_1, paste0("R_objects/allocated_risk_pyromes_plume_1/Rx_fire/pyrome_deaths_Rx_fire_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  # remove files
  rm(pyrome_estimated_annual_emission_Rx_fire, pyrome_estimated_annual_emission_Rx_fire_proportion, pyrome_deaths_Rx_fire_1)
  gc()
  
  ## Rx fire ##
  
  # get emissions for just single pyrome
  pyrome_estimated_annual_emission_thin_burn <- rast(paste0("pyrome_level_flamstat_output/annual_estimated_emissions_pyromes/thin_burn/pyrome_estimated_annual_emission_thin_burn_pyrome_", single_pyrome_polygon$PYROME, ".tif"))
  
  # get proportion that each pixel contributes to total pyrome emission
  pyrome_estimated_annual_emission_thin_burn_proportion <- pyrome_estimated_annual_emission_thin_burn / sum(values(pyrome_estimated_annual_emission_thin_burn), na.rm = T)
  
  # allocate risk (number of deaths) by the proportion of emissions
  pyrome_deaths_thin_burn_0 <- pyrome_estimated_annual_emission_thin_burn_proportion * (single_pyrome_num_deaths %>% filter(PlumeRiseCode == 0) %>% pull(deaths_thin_burn))
  
  # write raster
  writeRaster(pyrome_deaths_thin_burn_0, paste0("R_objects/allocated_risk_pyromes_plume_0/thin_burn/pyrome_deaths_thin_burn_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  # remove files
  rm(pyrome_deaths_thin_burn_0)
  gc()
  
  # allocate risk (number of deaths) by the proportion of emissions
  pyrome_deaths_thin_burn_1 <- pyrome_estimated_annual_emission_thin_burn_proportion * (single_pyrome_num_deaths %>% filter(PlumeRiseCode == 1) %>% pull(deaths_thin_burn))
  
  # write raster
  writeRaster(pyrome_deaths_thin_burn_1, paste0("R_objects/allocated_risk_pyromes_plume_1/thin_burn/pyrome_deaths_thin_burn_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  rm(pyrome_estimated_annual_emission_thin_burn, pyrome_estimated_annual_emission_thin_burn_proportion, pyrome_deaths_thin_burn_1)
  gc()
  
  
  time2 <- Sys.time()
  print(time2 - time1)
  
  rm(single_pyrome, single_pyrome_polygon)
  gc()
  
}

# integrate plume height (single split for each pyrome) ------

# FRP data
afd_clusters <- read.csv("data/plume_rise/frp_dataset_2012-2024/afd_clusters_2012-2024.csv")


## clusters ##
# Variable	Description
# key1	year_fid_doy_cluster (unique cluster ID)
# FID	Fire ID  (annual assignment)
# clust	Cluster ID for year, fid and doy
# FRP_MW	Sum of FRP (MW)
# agg_n	Number of afd pixels in cluster, nominal pixle size is 375 m x 375 m
# year	year
# doy	Day of year
# key0	year_fid_doy
# ForFrac	Forest fraction of entire fire perimeter
# Pyrome	Pyrome number
# Final_Fire_Acres	Area of final fire perimeter in acres
# Longitude	centroid x-coordinate (WGS84)
# Latitude	centroid y-coordinate (WGS84)


# convert to spatial
afd_clusters_points <- st_as_sf(afd_clusters, coords = c("Longitude", "Latitude"), crs = 4326) %>% vect()

# plume rise codes: 
# Low Plume Rise: 500m (PlumeRiseCode = 0)
# High Plume Rise: 3000m (PlumeRiseCode = 1)

# converting plume height to low (500 m) or high (3000 m) plume rise

k <- 0.003     # steeper = bigger
t <- 1750      # midpoint between 500 and 3000

plume_height_vec <- 1:4000
high_plume_prob <- 1 / (1 + exp(-k * (plume_height_vec - t)))

ggplot() + 
  geom_line(aes(x = plume_height_vec, y = high_plume_prob)) +
  labs(x = "Modeled plume height (m)",
       y = "Proportion of emissions at high plume") + 
  geom_vline(xintercept = 500, linetype = "dashed", color = "blue") + 
  geom_vline(xintercept = 3000, linetype = "dashed", color = "red") + 
  theme_classic()

# load in plume rise data
plume_rise_data_files <- list.files("data/plume_rise/plume_rise_data/", full.names = T)
plume_height <- 
  plume_rise_data_files %>%
  lapply(function(x){
    read.csv(x)
  }) %>%
  bind_rows() %>%
  mutate(plume_height_log = Plume_Height %>% log(),
         FRP_MW_log = FRP_MW %>% log()) %>%
  mutate(high_plume_prob = 1 / (1 + exp(-k * (Plume_Height - t))))

# calculate for each pyrome the mean probability of area burning at high plume 
pyrome_plume_heights <- plume_height %>%
  group_by(Pyrome) %>% 
  reframe(mean_plume_height = weighted.mean(Plume_Height, w = agg_n),
          mean_high_plume_prob = weighted.mean(high_plume_prob, w = agg_n)) %>%
  merge(pyromes %>% rename("Pyrome" = "PYROME"), ., by = "Pyrome", all.x = T) %>%
  st_as_sf() %>%
  mutate(mean_high_plume_prob = ifelse(is.na(mean_high_plume_prob),
                                       min(mean_high_plume_prob, na.rm = T),
                                       mean_high_plume_prob)) # for pyromes without any fires, assign minimum plume height

saveRDS(pyrome_plume_heights, "R_objects/pyrome_plume_heights")

# load pyrome plume height summary back in
pyrome_plume_heights <- readRDS("R_objects/pyrome_plume_heights")

getwd()
# loop through pyromes and combine pixel-level risk based on proportion of emissions going to low vs. high plume

x <- 1
for(x in 121:nrow(pyromes)){
  
  print(pyromes$NAME[x])
  time1 <- Sys.time()
  
  # load proportion of emissions coming from high plume rise
  pyrome_high_plume_prob <- pyrome_plume_heights %>% filter(Pyrome == pyromes$PYROME[x]) %>% pull(mean_high_plume_prob)
  pyrome_low_plume_prob <- 1 - pyrome_high_plume_prob
  
  
  ## Baseline
  
  # weight each raster by the proportion coming from the respective plume height
  pyrome_deaths_baseline_0 <- rast(paste0("R_objects/allocated_risk_pyromes_plume_0/baseline/pyrome_deaths_baseline_", pyromes$PYROME[x], ".tif")) * pyrome_low_plume_prob
  pyrome_deaths_baseline_1 <- rast(paste0("R_objects/allocated_risk_pyromes_plume_1/baseline/pyrome_deaths_baseline_", pyromes$PYROME[x], ".tif")) * pyrome_high_plume_prob
  
  # calculate total deaths by adding together
  pyrome_deaths_baseline <- pyrome_deaths_baseline_0 + pyrome_deaths_baseline_1
  
  # write raster
  writeRaster(pyrome_deaths_baseline, paste0("R_objects/allocated_risk_pyromes_combined/baseline/pyrome_deaths_baseline_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  # clean up objects
  rm(pyrome_deaths_baseline_0, pyrome_deaths_baseline_1, pyrome_deaths_baseline)
  gc() 
  
  ## Rx fire
  
  # weight each raster by the proportion coming from the respective plume height
  pyrome_deaths_Rx_fire_0 <- rast(paste0("R_objects/allocated_risk_pyromes_plume_0/Rx_fire/pyrome_deaths_Rx_fire_", pyromes$PYROME[x], ".tif")) * pyrome_low_plume_prob
  pyrome_deaths_Rx_fire_1 <- rast(paste0("R_objects/allocated_risk_pyromes_plume_1/Rx_fire/pyrome_deaths_Rx_fire_", pyromes$PYROME[x], ".tif")) * pyrome_high_plume_prob
  
  # calculate total deaths by adding together
  pyrome_deaths_Rx_fire <- pyrome_deaths_Rx_fire_0 + pyrome_deaths_Rx_fire_1
  
  # write raster
  writeRaster(pyrome_deaths_Rx_fire, paste0("R_objects/allocated_risk_pyromes_combined/Rx_fire/pyrome_deaths_Rx_fire_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  # clean up objects
  rm(pyrome_deaths_Rx_fire_0, pyrome_deaths_Rx_fire_1, pyrome_deaths_Rx_fire)
  gc() 
  
  ## Thin & burn
  
  # weight each raster by the proportion coming from the respective plume height
  pyrome_deaths_thin_burn_0 <- rast(paste0("R_objects/allocated_risk_pyromes_plume_0/thin_burn/pyrome_deaths_thin_burn_", pyromes$PYROME[x], ".tif")) * pyrome_low_plume_prob
  pyrome_deaths_thin_burn_1 <- rast(paste0("R_objects/allocated_risk_pyromes_plume_1/thin_burn/pyrome_deaths_thin_burn_", pyromes$PYROME[x], ".tif")) * pyrome_high_plume_prob
  
  # calculate total deaths by adding together
  pyrome_deaths_thin_burn <- pyrome_deaths_thin_burn_0 + pyrome_deaths_thin_burn_1
  
  # write raster
  writeRaster(pyrome_deaths_thin_burn, paste0("R_objects/allocated_risk_pyromes_combined/thin_burn/pyrome_deaths_thin_burn_", pyromes$PYROME[x], ".tif"), overwrite = T)
  
  # clean up objects
  rm(pyrome_deaths_thin_burn_0, pyrome_deaths_thin_burn_1, pyrome_deaths_thin_burn)
  gc() 
  
  time2 <- Sys.time()
  print(time2 - time1)
}

# combine things into single raster --------



### Baseline risk ###
allocated_risk_pyromes_baseline_files <- list.files("R_objects/allocated_risk_pyromes_combined/baseline/", full.names = T)

# Read in the raster files
allocated_risk_pyromes_baseline_rasters <- 1:length(allocated_risk_pyromes_baseline_files) %>% lapply(function(x){
  print(x)
  if(x %% 25 == 0){gc()}
  rast(allocated_risk_pyromes_baseline_files[x])
  
})

# Merge the rasters and save as .tif file
writeRaster(
  do.call(merge, allocated_risk_pyromes_baseline_rasters),
  filename = "Output_objects/allocated_risk_baseline_deaths.tif",
  overwrite = TRUE
)

rm(allocated_risk_pyromes_baseline_rasters)
gc()


### Rx risk (from post-treatment wildfire only) ###
allocated_risk_pyromes_Rx_fire_files <- list.files("R_objects/allocated_risk_pyromes_combined/Rx_fire/", full.names = T)

# Read in the raster files
allocated_risk_pyromes_Rx_fire_rasters <- 1:length(allocated_risk_pyromes_Rx_fire_files) %>% lapply(function(x){
  print(x)
  if(x %% 25 == 0){gc()}
  rast(allocated_risk_pyromes_Rx_fire_files[x])
  
})

# Merge the rasters and save as .tif file
writeRaster(
  do.call(merge, allocated_risk_pyromes_Rx_fire_rasters),
  filename = "Output_objects/allocated_risk_Rx_fire_deaths.tif",
  overwrite = TRUE
)

rm(allocated_risk_pyromes_Rx_fire_rasters)
gc()

### Thin & burn risk ###
#allocated_risk_pyromes_thin_burn_files <- list.files("R_objects/allocated_risk_pyromes_combined/thin_burn/", full.names = T)
allocated_risk_pyromes_thin_burn_files <- list.files("D:/TNC_box_backup/AirQuality/Analysis/R_objects/allocated_risk_pyromes_combined/thin_burn/", full.names = T)


# Read in the raster files
allocated_risk_pyromes_thin_burn_rasters <- 1:length(allocated_risk_pyromes_thin_burn_files) %>% lapply(function(x){
  print(x)
  if(x %% 25 == 0){gc()}
  rast(allocated_risk_pyromes_thin_burn_files[x])
})

# Merge the rasters and save as .tif file
writeRaster(
  do.call(merge, allocated_risk_pyromes_thin_burn_rasters),
  #filename = "Output_objects/allocated_risk_thin_burn_deaths.tif",
  filename = "C:/Users/mk164814/Documents/allocated_risk_thin_burn_deaths.tif",
  overwrite = TRUE
)



rm(allocated_risk_pyromes_thin_burn_rasters)
gc()


getwd()
### Rx fire (treatments itself) ###
#allocated_risk_pyromes_Rx_fire_from_treatment_files <- list.files("R_objects/allocated_risk_from_treatments_plume_0/from_Rx_fire/", full.names = T)
allocated_risk_pyromes_Rx_fire_from_treatment_files <- list.files("D:/TNC_box_backup/AirQuality/Analysis/R_objects/allocated_risk_from_treatments_plume_0/from_Rx_fire/", full.names = T)


# Read in the raster files
allocated_risk_pyromes_Rx_fire_from_treatment_rasters <- 1:length(allocated_risk_pyromes_Rx_fire_from_treatment_files) %>% lapply(function(x){
  print(x)
  if(x %% 25 == 0){gc()}
  rast(allocated_risk_pyromes_Rx_fire_from_treatment_files[x])
  
})

# Merge the rasters and save as .tif file
writeRaster(
  do.call(merge, allocated_risk_pyromes_Rx_fire_from_treatment_rasters),
  #filename = "Output_objects/allocated_risk_from_Rx_fire_trt_deaths.tif",
  filename = "C:/Users/mk164814/Documents/allocated_risk_from_Rx_fire_trt_deaths.tif",
  overwrite = TRUE
)





### Thin & burn (treatments itself) ###
# allocated_risk_pyromes_thin_burn_from_treatment_files <- list.files("R_objects/allocated_risk_from_treatments_plume_0/from_thin_burn/", full.names = T)
allocated_risk_pyromes_thin_burn_from_treatment_files <- list.files("D:/TNC_box_backup/AirQuality/Analysis/R_objects/allocated_risk_from_treatments_plume_0/from_thin_burn/", full.names = T)



# Read in the raster files
allocated_risk_pyromes_thin_burn_from_treatment_rasters <- 1:length(allocated_risk_pyromes_thin_burn_from_treatment_files) %>% lapply(function(x){
  print(x)
  if(x %% 25 == 0){gc()}
  rast(allocated_risk_pyromes_thin_burn_from_treatment_files[x])
  
})

# Merge the rasters and save as .tif file
writeRaster(
  do.call(merge, allocated_risk_pyromes_thin_burn_from_treatment_rasters),
  #filename = "Output_objects/allocated_risk_from_thin_burn_trt_deaths.tif",
  filename = "C:/Users/mk164814/Documents/allocated_risk_from_thin_burn_trt_deaths.tif",
  overwrite = TRUE
)

rm(allocated_risk_pyromes_thin_burn_from_treatment_rasters)
gc()


# calculate change in risk (delta) ---------

# load US states
us_states <- st_read("US_states/cb_2018_us_state_20m.shp") %>%
  filter(!STUSPS %in% c("AK", "PR", "HI")) %>%
  st_transform(crs("EPSG:5070"))

# for testing purposes
# load pyromes
pyromes <- vect("pyromes/Data/Pyromes_CONUS_20200206.shp")

pyromes$NAME
# "Middle Rockies (Yellowstone)"
"Southern Rockies (Upper Colorado River Basin)"
pyrome <- pyromes %>% filter(NAME == "Flint Hills")

leaflet() %>%
  addTiles() %>%
  addPolygons(data = pyrome %>% project("WGS84"))

# yearly estimated emissions from wildfires
yearly_deaths_baseline <- rast("Output_objects/allocated_risk_baseline_deaths.tif")
yearly_deaths_Rx_fire <- rast("Output_objects/allocated_risk_Rx_fire_deaths.tif")
yearly_deaths_thin_burn <- rast("Output_objects/allocated_risk_thin_burn_deaths.tif")

# emissions from treatments themselves
trt_deaths_Rx_fire <- rast("Output_objects/allocated_risk_from_Rx_fire_trt_deaths.tif")
trt_deaths_thin_burn <- rast("Output_objects/allocated_risk_from_thin_burn_trt_deaths.tif")


# calculate change in yearly estimated deaths (delta) from treatments
yearly_deaths_delta_Rx_fire <- yearly_deaths_Rx_fire - yearly_deaths_baseline
writeRaster(yearly_deaths_delta_Rx_fire, "Output_objects/yearly_deaths_delta_Rx_fire.tif", overwrite = T)

yearly_deaths_delta_thin_burn <- yearly_deaths_thin_burn - yearly_deaths_baseline
writeRaster(yearly_deaths_delta_thin_burn, "Output_objects/yearly_deaths_delta_thin_burn.tif")

yearly_deaths_delta_Rx_fire <- rast("Output_objects/yearly_deaths_delta_Rx_fire.tif")
yearly_deaths_delta_thin_burn <- rast("Output_objects/yearly_deaths_delta_thin_burn.tif")


# calculate % change in yearly estimated deaths from treatments
perc_change_yearly_deaths_Rx_fire <- yearly_deaths_delta_Rx_fire / yearly_deaths_baseline * 100
perc_change_yearly_deaths_thin_burn <- yearly_deaths_delta_thin_burn / yearly_deaths_baseline * 100

perc_change_yearly_deaths_Rx_fire_pyrome <- perc_change_yearly_deaths_Rx_fire %>% crop(pyrome, mask = T)


yearly_deaths_delta_Rx_fire_pyrome <- yearly_deaths_delta_Rx_fire %>% crop(pyrome, mask = T)

leaflet() %>%
  addTiles() %>%
  addRasterImage(yearly_deaths_delta_Rx_fire_pyrome %>% 
                   aggregate(10, sum, na.rm = T), opacity = 0.5)

ggplot() + 
  geom_spatraster(data = yearly_deaths_delta_Rx_fire_pyrome %>% aggregate(100, sum, na.rm = T)) +
  scale_fill_gradient2(
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    na.value = NA,
    transform = pseudo_log_trans()
  )

inf_mask <- is.infinite(perc_change_yearly_deaths_Rx_fire)
true_cells <- cells(inf_mask, 1)

# Keep only those that are TRUE in the mask
sample_points <- sample_points[ inf_mask[sample_points][,1] == 1 ]




# calculate the number of years treatment would have to provide benefits for to offset initial treatment risk
years_to_break_even_Rx_fire <-  -trt_deaths_Rx_fire / yearly_deaths_delta_Rx_fire
writeRaster(years_to_break_even_Rx_fire, "Output_objects/years_to_break_even_Rx_fire.tif", overwrite = T)

years_to_break_even_thin_burn <-  -trt_deaths_thin_burn / yearly_deaths_delta_thin_burn
writeRaster(years_to_break_even_thin_burn, "Output_objects/years_to_break_even_thin_burn.tif", overwrite = T)




pyrome_years_to_break_even_Rx_fire <- years_to_break_even_Rx_fire %>% crop(pyrome, mask = T)

pyrome_years_to_break_even_Rx_fire_masked <- pyrome_years_to_break_even_Rx_fire
pyrome_years_to_break_even_Rx_fire_masked[pyrome_years_to_break_even_Rx_fire_masked < 0] <- NA
pyrome_years_to_break_even_Rx_fire_masked[pyrome_years_to_break_even_Rx_fire_masked >= 100] <- NA

pyrome_years_to_break_even_Rx_fire_masked

ggplot() +
  geom_sf(data = pyrome, fill = NA) + 
  geom_spatraster(data = pyrome_years_to_break_even_Rx_fire_masked) +
  scale_fill_viridis_c(
    na.value = NA,
    name = "Years to break even"
  ) +
  theme_void()

# aggregate to smaller resolution
years_to_break_even_Rx_fire_agg100 <- years_to_break_even_Rx_fire %>% terra::aggregate(100, mean, na.rm = T)
years_to_break_even_thin_burn_agg100 <- years_to_break_even_thin_burn %>% terra::aggregate(100, mean, na.rm = T)


# Replace all values less than 0 (including -Inf) with NA
years_to_break_even_Rx_fire_agg100_masked <- years_to_break_even_Rx_fire_agg100
years_to_break_even_Rx_fire_agg100_masked[years_to_break_even_Rx_fire_agg100_masked < 0] <- NA

years_to_break_even_Rx_fire_agg100_masked_log10 <- years_to_break_even_Rx_fire_agg100_masked %>% log(10)

# keep only values where benefit is greater for 1 year than treatment impacts
years_to_break_even_Rx_fire_agg100_benefit <- years_to_break_even_Rx_fire_agg100_masked
years_to_break_even_Rx_fire_agg100_benefit[years_to_break_even_Rx_fire_agg100_benefit >= 100] <- NA


non_na_cells <- which(!is.na(values(years_to_break_even_Rx_fire_agg100_benefit)))

# Convert to spatial points
sample_points <- xyFromCell(years_to_break_even_Rx_fire_agg100, non_na_cells)
sample_points <- vect(sample_points, crs = crs(years_to_break_even_Rx_fire_agg100))
sample_points <- sample_points %>%
  project("EPSG:4326")

pyromes


leaflet() %>%
  addTiles() %>%
  addRasterImage(years_to_break_even_Rx_fire_agg100_benefit %>% project("WGS84"))

ggplot() +
  geom_spatraster(data = years_to_break_even_Rx_fire_agg100_benefit ) +
  scale_fill_viridis_c(na.value = NA) + 
  theme_void()

vals_test <- data.frame(years = years_to_break_even_Rx_fire_agg100 %>% values() %>% na.omit() %>% as.numeric())

vals_test %>%
  filter(years < 1e2 & years > -1e2) %>%
  ggplot() +
  geom_density(aes(x = years))




ggplot() +
  geom_spatraster(data = years_to_break_even_Rx_fire_agg100_masked_log10) +
  scale_fill_gradient2(
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    na.value = NA
  )




years_to_break_even_thin_burn <-  -trt_deaths_thin_burn / yearly_deaths_delta_thin_burn
writeRaster(years_to_break_even_thin_burn, "Output_objects/years_to_break_even_thin_burn.tif", overwrite = T)







# aggregate by 100x 
yearly_deaths_baseline_agg_100 <- yearly_deaths_baseline %>% terra::aggregate(100, fun="sum", na.rm = T)
yearly_deaths_Rx_fire_agg_100 <- yearly_deaths_Rx_fire %>% terra::aggregate(100, fun="sum", na.rm = T)
yearly_deaths_thin_burn_agg_100 <- yearly_deaths_thin_burn %>% terra::aggregate(100, fun="sum", na.rm = T)


writeRaster(yearly_deaths_baseline_agg_100, "Output_objects/allocated_risk_agg100/yearly_deaths_baseline_agg_100.tif")
writeRaster(yearly_deaths_Rx_fire_agg_100, "Output_objects/allocated_risk_agg100/yearly_deaths_Rx_fire_agg_100.tif")
writeRaster(yearly_deaths_thin_burn_agg_100, "Output_objects/allocated_risk_agg100/yearly_deaths_thin_burn_agg_100.tif")

trt_deaths_Rx_fire_agg_100 <- trt_deaths_Rx_fire %>% terra::aggregate(100, fun="sum", na.rm = T)
trt_deaths_thin_burn_agg_100 <- trt_deaths_thin_burn %>% terra::aggregate(100, fun="sum", na.rm = T)

writeRaster(trt_deaths_Rx_fire_agg_100, "Output_objects/allocated_risk_agg100/trt_deaths_Rx_fire_agg_100.tif", overwrite = T)
writeRaster(trt_deaths_thin_burn_agg_100, "Output_objects/allocated_risk_agg100/trt_deaths_thin_burn_agg_100.tif", overwrite = T)

# plot agg x 100

yearly_deaths_baseline_agg_100 <- rast("Output_objects/allocated_risk_agg100/yearly_deaths_baseline_agg_100.tif")
yearly_deaths_Rx_fire_agg_100  <- rast("Output_objects/allocated_risk_agg100/yearly_deaths_Rx_fire_agg_100.tif")
yearly_deaths_thin_burn_agg_100 <- rast("Output_objects/allocated_risk_agg100/yearly_deaths_thin_burn_agg_100.tif")

trt_deaths_Rx_fire_agg_100  <- rast("Output_objects/allocated_risk_agg100/trt_deaths_Rx_fire_agg_100.tif")
trt_deaths_thin_burn_agg_100 <- rast("Output_objects/allocated_risk_agg100/trt_deaths_thin_burn_agg_100.tif")

yearly_deaths_delta_Rx_fire_agg_100 <- yearly_deaths_Rx_fire_agg_100 - yearly_deaths_baseline_agg_100
yearly_deaths_delta_thin_burn_agg_100 <- yearly_deaths_thin_burn_agg_100 - yearly_deaths_baseline_agg_100

yearly_deaths_perc_reduction_Rx_fire_agg_100 <- yearly_deaths_delta_Rx_fire_agg_100 / yearly_deaths_baseline_agg_100
yearly_deaths_perc_reduction_thin_burn_agg_100 <- yearly_deaths_delta_thin_burn_agg_100 / yearly_deaths_baseline_agg_100





# Function to convert raster to percentiles (0-100)
raster_to_percentile <- function(r, step = 0.01) {
  # Ensure single layer
  if (nlyr(r) > 1) r <- r[[1]]
  
  # Extract all values (in chunks if needed)
  vals <- values(r, mat = FALSE)
  
  # Remove NAs
  vals <- vals[!is.na(vals)]
  
  # Compute quantile breaks
  qs <- quantile(vals, probs = seq(0, 1, step))
  
  # Map raster values to percentiles
  percentile_fun <- function(x) {
    cut(x, breaks = qs, labels = FALSE, include.lowest = TRUE) - 1
  }
  
  app(r, percentile_fun)
}

yearly_deaths_baseline_agg_100_percentile <- yearly_deaths_baseline_agg_100 %>% raster_to_percentile()


# deaths per year (raw)
yearly_deaths_baseline_agg_100 %>% res()
ggplot() + 
  geom_spatraster(data = yearly_deaths_baseline_agg_100 / (3000*3000) * 1e6) + 
  scale_fill_viridis_c(
    name = "Deaths per year (per km2)",
    na.value = NA, option = "turbo"
  ) + 
  geom_sf( data = us_states, 
           fill = NA, 
           color = scales::alpha("grey75", 0.25)  # makes borders semi-transparent
  ) +
  theme_void()

# deaths per year (percentile)
ggplot() + 
  geom_spatraster(data = yearly_deaths_baseline_agg_100_percentile) + 
  scale_fill_viridis_c(
    name = "Deaths per year (percentile)",
    na.value = NA, option = "inferno"
  ) + 
  theme_void()

# change in deaths (rx fire)
ggplot() + 
  geom_spatraster(data = yearly_deaths_delta_Rx_fire_agg_100 / (3000*3000) * 1e6) + 
  scale_fill_gradient2(
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    na.value = NA,
    name = "Change in yearly estimated \ndeaths (per km2) following \n Rx fire (does not include \n treatment emissions)"
  ) + 
  geom_sf( data = us_states, 
           fill = NA, 
           color = scales::alpha("grey75", 1.0)  # makes borders semi-transparent
  ) +
  theme_void()

# treatment deaths (rx fire)

trt_deaths_Rx_fire_agg_100_plotting <- trt_deaths_Rx_fire_agg_100
trt_deaths_Rx_fire_agg_100_plotting[trt_deaths_Rx_fire_agg_100_plotting > 15] <- 15
ggplot() + 
  geom_spatraster(data = trt_deaths_Rx_fire_agg_100_plotting / (3000*3000) * 1e6) + 
  scale_fill_viridis_c(
    name = "Deaths from Rx \nfire treatment (per km2)",
    na.value = NA, option = "turbo"
  ) + 
  geom_sf( data = us_states, 
           fill = NA, 
           color = scales::alpha("grey50", 1.0)  # makes borders semi-transparent
  ) +
  theme_void()


# how much more is treatment than baseline yearly? 
prop_Rx_trt_deaths_vs_baseline <- trt_deaths_Rx_fire_agg_100 / yearly_deaths_baseline_agg_100
prop_Rx_trt_deaths_vs_baseline[prop_Rx_trt_deaths_vs_baseline > 50] <- 50

ggplot() + 
  geom_spatraster(data = prop_Rx_trt_deaths_vs_baseline) + 
  scale_fill_viridis_c(
    name = "# of times higher\nRx treatment deaths are than \nbaseline yearly emissions",
    na.value = NA,
    option = "plasma"
  ) + 
  geom_sf( data = us_states, 
           fill = NA, 
           color = scales::alpha("grey75", 0.5)  # makes borders semi-transparent
  ) +
  theme_void()

prop_Rx_trt_deaths_vs_baseline_vals <- 
  data.frame(prop_Rxfire_vs_baseline = (trt_deaths_Rx_fire_agg_100 / yearly_deaths_baseline_agg_100) %>% values() %>% unlist() %>% as.numeric()) %>%
  na.omit()

prop_Rx_trt_deaths_vs_baseline_vals %>%
  filter(prop_Rxfire_vs_baseline > 1000000000000)


prop_Rx_trt_deaths_vs_baseline_vals %>%
  filter(prop_Rxfire_vs_baseline < 1e7) %>%
  sample_n(10000) %>%
  ggplot() + 
  geom_density(aes(x = prop_Rxfire_vs_baseline)) +
  scale_x_log10(labels = label_number(), 
                breaks = c(10, 100, 1000, 10000, 100000, 1000000)) + # forces standard decimal notation
  labs(x = "# of times higher risk of ")


yearly_deaths_baseline_agg_100 %>% values() %>% sum(na.rm = T)
yearly_deaths_Rx_fire_agg_100 %>% values() %>% sum(na.rm = T)
yearly_deaths_thin_burn_agg_100 %>% values() %>% sum(na.rm = T)

yearly_deaths_delta_Rx_fire_agg_100 <- yearly_deaths_Rx_fire_agg_100 - yearly_deaths_baseline_agg_100
yearly_deaths_delta_thin_burn_agg_100 <- yearly_deaths_thin_burn_agg_100 - yearly_deaths_baseline_agg_100



# compare to pyrome summaries
all_pyromes_deaths <- readRDS("R_objects/all_pyromes_deaths_FlamStat")
pyrome_plume_heights <- readRDS("R_objects/pyrome_plume_heights")
pyrome_plume_heights_df <- pyrome_plume_heights %>% as.data.frame() %>%
  dplyr::select(NAME, mean_high_plume_prob) %>%
  rename("PyromeName" = "NAME")

#make matrix of high plume probability
pyrome_plume_prob_mat <- matrix(pyrome_plume_heights_df$mean_high_plume_prob, ncol = 1)
rownames(pyrome_plume_prob_mat) = pyrome_plume_heights_df$PyromeName

all_pyromes_deaths_plume <- all_pyromes_deaths %>%
  as.data.frame() %>%
  mutate(high_plume_prob = pyrome_plume_prob_mat[PyromeName,]) %>%
  mutate(deaths_baseline_plume_adj = ifelse(PlumeRiseCode == 1, deaths_baseline * high_plume_prob,
                                            deaths_baseline * (1 - high_plume_prob)),
         deaths_Rx_fire_plume_adj = ifelse(PlumeRiseCode == 1, deaths_Rx_fire * high_plume_prob,
                                           deaths_Rx_fire * (1 - high_plume_prob)),
         deaths_thin_burn_plume_adj = ifelse(PlumeRiseCode == 1, deaths_thin_burn * high_plume_prob,
                                             deaths_thin_burn * (1 - high_plume_prob)))

all_pyromes_deaths_plume$deaths_baseline_plume_adj %>% sum(na.rm = T)
all_pyromes_deaths_plume$deaths_Rx_fire_plume_adj %>% sum(na.rm = T)
all_pyromes_deaths_plume$deaths_thin_burn_plume_adj %>% sum(na.rm = T)


all_pyromes_deaths_from_treatments <- readRDS("R_objects/all_pyromes_deaths_from_treatments_FlamStat")

all_pyromes_deaths_from_treatments$deaths_from_Rx_fire %>% sum(na.rm = T)
all_pyromes_deaths_from_treatments$deaths_from_thin_burn %>% sum(na.rm = T)

(trt_deaths_thin_burn_agg_100 %>% values() %>% sum(na.rm = T)) / (all_pyromes_deaths_from_treatments$deaths_from_thin_burn %>% sum(na.rm = T)
)
(trt_deaths_Rx_fire_agg_100 %>% values() %>% sum(na.rm = T)) / (all_pyromes_deaths_from_treatments$deaths_from_Rx_fire %>% sum(na.rm = T))




# Reduction in deaths from Rx fire

cell_size_km2 <- (res(yearly_deaths_delta_Rx_fire_agg_100)[1] * 
  res(yearly_deaths_delta_Rx_fire_agg_100)[2]) / (1000*1000)




ggplot() +
  geom_spatraster(data = yearly_deaths_delta_Rx_fire_agg_100 / cell_size_ha) +
  scale_fill_gradient2(
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    trans = pseudo_log_trans(base = 10, sigma = 0.000001),  # smaller sigma -> more log-like
    na.value = NA
  )

# Reduction in deaths from thin & burn
ggplot() +
  geom_spatraster(data = yearly_deaths_delta_thin_burn_agg_100) +
  scale_fill_gradient2(
    low = "blue", mid = "white", high = "red",
    midpoint = 0,
    trans = pseudo_log_trans(base = 10, sigma = 0.001),  # smaller sigma -> more log-like
    na.value = NA
  )

leaflet() %>% 
  addTiles() %>% 
  addRasterImage(yearly_deaths_delta_Rx_fire_agg_100 %>% project(crs("WGS84")),
                 opacity = 0.8)

# Reproject raster to WGS84
r_proj <- yearly_deaths_delta_Rx_fire_agg_100 %>% project(crs("WGS84"))

# Get range and make symmetric around 0
r_vals <- terra::values(r_proj, na.rm = TRUE)
max_abs <- max(abs(r_vals), na.rm = TRUE)

# Create a diverging palette centered on 0
pal <- colorNumeric(
  palette = colorRampPalette(c("blue", "white", "red"))(256),
  domain  = c(-max_abs, max_abs),
  na.color = NA
)

# Plot in leaflet
leaflet() %>%
  addTiles() %>%
  addRasterImage(r_proj, colors = pal, opacity = 0.8) %>%
  addLegend(
    pal = pal,
    values = r_vals,
    title = "Change from Baseline",
    labFormat = labelFormat()
  )


#####

allocated_risk_rasters_merged_agg <- allocated_risk_rasters_merged %>% terra::aggregate(100, fun="sum")

writeRaster(allocated_risk_rasters_merged_agg, "Output_objects/allocated_risk_rasters_merged_agg.tif")








allocated_risk_rasters_merged_agg_dollars <- 
  allocated_risk_rasters_merged_agg * statistical_value_of_life


allocated_risk_rasters_merged_agg_log10 <- allocated_risk_rasters_merged_agg %>% log(10)
allocated_risk_rasters_merged_agg_dollars_log10 <- allocated_risk_rasters_merged_agg_dollars %>% log(10)

