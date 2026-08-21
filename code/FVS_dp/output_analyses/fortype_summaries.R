fortype.r <- rast("../../SHARED_DATA/TREEMAP/TreeMap2020_CONUS_FORTYPCD.tif")

fortypes <- cats(fortype.r) %>%  as.data.frame() %>% 
  select(fortype_code = Value,
         fortype_name = Label)

fortypesgrp.ref <- read.csv("../../SHARED_DATA/FIA/FIADB_REFERENCE/REF_FOREST_TYPE_GROUP.csv")
fortype.groups <- read.csv("../../SHARED_DATA/FIA/FIADB_REFERENCE/REF_FOREST_TYPE.csv") %>% 
  left_join(fortypes.ref %>% 
              select(TYPGRPCD = VALUE,
                     fortypegrp_name = MEANING,
                     fortypegrp_abbr = ABBR))

rx.c <- read.csv("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/S_USA.EcoMapProvinces_fortypcd_RxCarbon.csv", header = TRUE, stringsAsFactors = FALSE) %>% 
  rename(fortype_code = category,
         rx_mean = mean,
         rx_median = median,
         rx_sd = sd)
wf.c <- read.csv("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/S_USA.EcoMapProvinces_fortypcd_WFCarbon.csv", header = TRUE, stringsAsFactors = FALSE) %>% 
  rename(fortype_code = category,
         wf_mean = mean,
         wf_median = median,
         wf_sd = sd)
t.c <- read.csv("data/dp_FVS_postprocess/CONUS_mosaic/zonal_summaries/S_USA.EcoMapProvinces_fortypcd_Tratio.csv", header = TRUE, stringsAsFactors = FALSE) %>% 
  rename(fortype_code = category,
         t_mean = mean,
         t_median = median,
         t_sd = sd)
         
fortype.summary <- rx.c %>% 
  left_join(wf.c, by = c("zone_id","fortype_code","n")) %>% 
  left_join(t.c, by = c("zone_id","fortype_code","n")) %>% 
  left_join(fortypes, by = "fortype_code") %>% 
  left_join(fortype.groups %>% 
              select(fortype_code = VALUE,
                     fortypegrp_name,
                     fortypegrp_abbr), 
            by = "fortype_code") %>% 
  arrange(fortype_code)

fortype.summary %>% 
  ggplot(.,
         aes(y = fortypegrp_name,
             x = t_mean)) +
  geom_boxplot()

fortype.summary %>% 
  ggplot(.,
         aes(y = fortypegrp_name,
             x = rx_mean)) +
  geom_boxplot()






fortype.summary %>% 
  ggplot(.,
         aes(y = zone_id,
             x = t_mean)) +
  geom_boxplot()

fortype.summary %>% 
  ggplot(.,
         aes(y = zone_id,
             x = t_mean)) +
  geom_boxplot()

fortype.summary %>% 
  ggplot(.,
         aes(y = zone_id,
             x = t_mean)) +
  geom_boxplot()
