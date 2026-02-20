#### Exploring Rx permits data
#### 

rx.permits <- read.csv("data/rx_permits/analysis_final_22Dec2025.csv", header=T, stringsAsFactors = F) %>% 
  select(-geometry) %>% 
  filter(!is.na(LAT_ADJUSTED)) %>% 
  sf::st_as_sf(., coords = c("LON_ADJUSTED","LAT_ADJUSTED"),
               crs = 4326, remove = F)# %>% 
  #sf::st_transform(crs = "EPSG:8858")

# a couple issues right off the bat:
# 1) a couple thousand records have no coordinates
# 2) geometry column isn't interpretable without considerable messing around -- just using Lat/Long info and reprojecting
# 3) data are only for W.US
# 4) there are a bunch of clearly wrong coordinates -- will just crop those out using national shapefile

w.us <- sf::read_sf("/Users/daniel.perret/Box/DPerret_Workspace/base_spatialdata/state_boundaries/state_boundaries.shp") %>% 
  filter(STATE %in% c("WA","OR","CA","ID","NV","MT","WY","UT","AZ","CO","NM")) %>% 
  sf::st_transform(crs = "EPSG:4326")

rx.permits <- rx.permits %>% 
  sf::st_filter(st_union(w.us))

ggplot()+
  geom_sf(data=w.us)+
  geom_sf(data=rx.permits,
          aes(col = factor(burned)),
          pch = 19,
          alpha = 0.7) +
  scale_color_manual(name = "burned?",
                     values = c("1" = "firebrick3",
                                "0" = "dodgerblue3"))
