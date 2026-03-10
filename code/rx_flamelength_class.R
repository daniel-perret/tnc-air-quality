###### exploring NT-Rx-Tx emissions data to attempt to track down an explanation for why Rx emissions are greater than wildfire emissions
###### 

# first goal: compare flame lengths between prescribed fire 2020 and NT wildfire 2020

# Need to first join data from the flame length csv to the cell ids in FVSVariant_key raster

rx_fl <- read.csv("data/flamstat/flamelength_rasters/Flame_Length_Rx_Fire.csv",
                  header = T, stringsAsFactors = F)

key_ras <- terra::rast("data/flamstat/metadata/TMFM2020_FVSVariant_key/TMFM2020_FVSVariant_Key.tif")

terra::activeCat(key_ras) <- "Key"

rx_ras <- terra::classify(key_ras, as.matrix(rx_fl))

########
########

rx_fl <- rx_fl %>% 
  mutate(fl_class = cut(Flame_length, breaks = c(0,2,4,6,8,12,999),))

rx_fl %>% 
  ggplot(.,
         aes(x = fl_class,
             y = after_stat(prop),
             group=1)) +
  geom_bar() +
  labs(x = "Flame Length bin",
       y = "Proportion of all stands",
       title = "Rx fire intensity (FVS)")

rx_fl %>% 
  select(StandID, Flame_length) %>% 
  mutate(Flame_length_int = round(Flame_length,3)*1e3) %>% 
  write.table(., file = "data/flamstat/flamelength_rasters/Flame_Length_Rx_Fire_int.csv",
              sep=",", row.names=F)
