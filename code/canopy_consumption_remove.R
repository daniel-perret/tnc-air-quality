###### Canopy consumption troubleshooting code
###### 
###### The background is that we've noticed far more canopy fuel consumption from Rx fire than from WF in some cases -- we want to see if this accounts for the bulk of the Rx>WF emissions issue or if we need to tweak surface fuel consumption.

rx.db <- dbConnect(SQLite(), 
                   "data/fvs_outputs/TreeMap2020_RxFire_Onlyft_fl.db")

rx.consumption <- dbReadTable(rx.db, "FVS_Consumption") %>% 
  mutate(type = "rx")
rx.burn <- dbReadTable(rx.db, "FVS_BurnReport") %>% 
  mutate(type = "rx")
rx.carbon <- dbReadTable(rx.db, "FVS_Carbon") %>% 
  mutate(type = "rx") %>% 
  filter(Year == 2020)

rx.consumption <- rx.consumption %>% 
  mutate(NonCanopy_Consumption = Total_Consumption - Consumption_Crowns,
         Consumption_Carbon_ratio = rx.carbon$Carbon_Released_From_Fire/Total_Consumption,
         NonCanopy_Carbon = NonCanopy_Consumption*Consumption_Carbon_ratio)

write.table(rx.consumption,
            file = "data/troubleshooting/rx_consumption_table.csv",
            sep=",",
            row.names=F)

fvs.info <- rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif")

noncanopy.emissions <- fvs.info %>% 
  terra::classify(., rcl = rx.consumption %>% 
                    select(StandID, NonCanopy_Carbon) %>% 
                    mutate(NonCanopy_Carbon = round(NonCanopy_Carbon,4))
                    data.matrix())

