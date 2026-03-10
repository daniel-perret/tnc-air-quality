##### Here I'm trying to build a cohesive table of all FlamStat/FVS inputs and outcomes attached to TREEMAP StandIDs and FIA PLT_CNs
##### The idea is that this will help troubleshoot cases of Rx>NT fire intensity, and figure out what kinds of comparisons we feel good about
##### Also will ease analysis, as things can be run aspatially and then re-associated with pixels
##### 

##### The strategy here will be to read in rasters and then grab attribute tables



# FVSVariant_key raster

key <- terra::rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif") %>% 
  terra::cats() %>% 
  as.data.frame() %>% 
  mutate(StandID = Key)


# now joining other csv files before wrangling with the raster sets

key <- key %>% 
  left_join(read.csv("data/flamstat/emissions_rasters/Total_Carbon_Emissions_FlamStat_2021.csv", header=T, stringsAsFactors = F),
            by = "StandID") %>% 
  left_join(read.csv("data/flamstat/emissions_rasters/Treatment_Emissions_FlamStat_2020.csv", header = T, stringsAsFactors = F),
            by = "StandID") %>% 
  left_join(read.csv("data/flamstat/flamelength_rasters/Flame_Length_Rx_Fire.csv", header=T, stringsAsFactors = F) %>% 
              rename(Rx_flame_length = Flame_length),
            by = "StandID")

## running plots
key %>% 
  ggplot(.,
         aes(x = Rx_flame_length,
             y = Carbon_Released_From_Fire_RxFire_0))+
  geom_point(pch = 19,
             alpha = 0.4) +
  facet_wrap(facets = ~FVSVariant)

key %>% 
  ggplot(.,
         aes(x = Em_NT_1ft,
             y = Em_Rx_1ft)) +
  geom_point(pch = 19,
             alpha = 0.4) +
  geom_abline(slope = 1, 
              intercept = 0,
              col = "red") +
  facet_wrap(facets = ~FVSVariant)
