################################################################################
################## Zonal summary figures for T ratio ###########################
################################################################################

source("code/FVS_dp/cleaned_workflow/0.0_setup.R")

ratio.rast <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked_FRG.tif")

states <- sf::read_sf("../../SHARED_DATA/base_spatialdata/state_boundaries/state_boundaries.shp") %>% 
  sf::st_transform(., crs(ratio.rast))

linecolor <- "grey25"
linewidth <- 0.6

out_dir <- "figures/zonal_T_maps"

# HUC 8

huc8.tab <- read.csv("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/huc8_Tratio.csv", header = T, stringsAsFactors = F)

huc8 <- sf::read_sf("../../SHARED_DATA/HUC_boundaries/huc8_conus/HUC8_US.shp") %>% 
  sf::st_transform(., crs(ratio.rast)) %>% 
  mutate(HUC8 = as.integer(HUC8)) %>% 
  filter(!NAME %in% c("Lake Superior", "Lake Erie", "Lake Huron", "Lake Ontario", "Lake Michigan")) %>% 
  left_join(., huc8.tab, by = "HUC8") %>% 
  sf::st_intersection(., states)

p1 <- ggplot() +
  geom_sf(data = huc8,
          aes(fill = mean),
          color = NA) +
  geom_sf(data = states, 
          fill = NA, 
          color = linecolor,
          size = linewidth) + 
  scale_fill_viridis_c(option = "plasma", na.value = NA) +
  labs(title = "Mean T ratio by HUC 8",
       fill = "Mean T ratio") +
  theme_void() +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "huc8_mean_tratio.png"), p1, 
       width = 10, height = 8, dpi = 300, bg = "white")

# HUC 10

huc10.tab <- read.csv("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/huc10_Tratio.csv", header = T, stringsAsFactors = F)

huc10 <- sf::read_sf("../../SHARED_DATA/HUC_boundaries/huc10_conus/WBDHU10 selection.shp") %>% 
  sf::st_transform(., crs(ratio.rast)) %>% 
  mutate(huc10 = as.integer(huc10)) %>% 
  filter(!name %in% c("Lake Superior", "Lake Erie", "Lake Huron", "Lake Ontario", "Lake Michigan")) %>% 
  left_join(., huc10.tab, by = "huc10") %>% 
  sf::st_intersection(., states)

p2 <- ggplot() +
  geom_sf(data = huc10 %>% 
            filter(!is.na(mean)),
          aes(fill = mean),
          color = NA) +
  geom_sf(data = states, 
          fill = NA, 
          color = linecolor,
          size = linewidth) + 
  scale_fill_viridis_c(option = "plasma") +
  labs(title = "Mean T ratio by HUC 10",
       fill = "Mean T ratio") +
  theme_void() +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "huc10_mean_tratio.png"), p2, 
       width = 10, height = 8, dpi = 300, bg = "white")

# HUC 12

huc12.tab <- read.csv("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/huc12_Tratio.csv", header = T, stringsAsFactors = F)

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
                       #limits = c(0,1),
                       oob = scales::oob_squish) +
  labs(title = "Mean T ratio by HUC 12",
       fill = "Mean T ratio") +
  theme_void() +
  theme(legend.position = "bottom")


ggsave(file.path(out_dir, "huc12_mean_tratio_clip.png"), p3, 
       width = 10, height = 8, dpi = 300, bg = "white")

# fireshed

fireshed.tab <- read.csv("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/firesheds_Tratio.csv", header = T, stringsAsFactors = F)

fireshed <- sf::read_sf("../../SHARED_DATA/firesheds/Fireshed_Registry%3A_Fireshed_(Feature_Layer).shp") %>% 
  sf::st_transform(., crs(ratio.rast)) %>% 
  left_join(., fireshed.tab, 
            by = c("FIRESHED_I" = "ID")) %>% 
  sf::st_intersection(., states)

p4 <- ggplot() +
  geom_sf(data = fireshed,
          aes(fill = mean),
          color = NA) +
  geom_sf(data = states, 
          fill = NA, 
          color = linecolor,
          size = linewidth) + 
  scale_fill_viridis_c(option = "plasma", na.value = NA) +
  labs(title = "Mean T ratio by fireshed",
       fill = "Mean T ratio") +
  theme_void() +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "firesheds_mean_tratio.png"), p4, 
       width = 10, height = 8, dpi = 300, bg = "white")
