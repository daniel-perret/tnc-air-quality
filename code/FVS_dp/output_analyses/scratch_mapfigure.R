# HUC 12

huc12.tab <- read.csv("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/huc12_WfCarbon.csv", header = T, stringsAsFactors = F) %>% 
  rename(huc12 = ID)

huc12 <- sf::read_sf("../../SHARED_DATA/HUC_boundaries/huc12_conus/WBDHU12 selection.shp") %>% 
  sf::st_transform(., crs(ratio.rast)) %>% 
  mutate(huc12 = as.numeric(huc12)) %>% 
  filter(!name %in% c("Lake Superior", "Lake Erie", "Lake Huron", "Lake Ontario", "Lake Michigan")) %>% 
  left_join(., huc12.tab, by = "huc12") %>% 
  sf::st_intersection(., states) %>% 
  filter(sd>0)

p3 <- ggplot() +
  geom_sf(data = huc12,
          aes(fill = mean),
          color = NA) +
  geom_sf(data = states, 
          fill = NA, 
          color = linecolor,
          size = linewidth) + 
  scale_fill_viridis_c(option = "plasma", na.value = NA, 
                       limits = c(0,40),
                       oob = scales::oob_squish) +
  labs(title = "Mean WF Carbon Emissions by HUC 12",
       fill = "Mean Carbon Emissions (tons/ac)") +
  theme_void() +
  theme(legend.position = "bottom")


ggsave(file.path(out_dir, "huc12_mean_WfCarbon_clip.png"), p3, 
       width = 10, height = 8, dpi = 300, bg = "white")
