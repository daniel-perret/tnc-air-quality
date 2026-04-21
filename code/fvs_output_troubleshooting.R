##### Here I'm digging into the FVS outputs for 2020 NT-wildfire and Rx fire runs to gain insight into how differential fuel consumption is related to emissions differences


# rasters


fvs.info <- rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif")
# fvs.info <- classify(fvs.info, rcl = cats(fvs.info) %>% 
#                        as.data.frame() %>% 
#                        select(Value, Key) %>% 
#                        as.matrix())

nt.emissions <- rast("data/flamstat/emissions_rasters/dp_merged/2020_cond_baseline_conus.tif")

rx.emissions <- rast("data/flamstat/emissions_rasters/Rx_treatment_emissions.tif")

rx.nt.diff <- rast("data/flamstat/emissions_rasters/dp_merged/Rx_baseline_2020_difference.tif")

#grabbing only problem pixels
fvs.class <- fvs.info %>% 
  crop(.,rx.nt.diff,mask=T)

fvs.class[rx.nt.diff<=0] <- NA
fvs.class <- droplevels(fvs.class)

fvs.tab <- cats(fvs.class) %>% 
  as.data.frame()

#writeRaster(fvs.class, "data/troubleshooting/fvsTest.tif")

# load up FVS output databases
rx.db <- dbConnect(SQLite(), 
                   "data/fvs_outputs/TreeMap2020_RxFire_Onlyft_fl.db")
nt.1ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_1ft_fl.db")
nt.3ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_3ft_fl.db")
nt.5ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_5ft_fl.db")
nt.7ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_7ft_fl.db")
nt.10ft.db <- dbConnect(SQLite(), 
                        "data/fvs_outputs/TreeMap2020_10ft_fl.db")
nt.20ft.db <- dbConnect(SQLite(), 
                        "data/fvs_outputs/TreeMap2020_20ft_fl.db")


dbListTables(nt.20ft.db)

# pull compute tables
rx.compute <- dbReadTable(rx.db, "FVS_Compute") %>% 
  mutate(type = "rx")
nt.1.compute <- dbReadTable(nt.1ft.db, "FVS_Compute") %>% 
  mutate(type = "1ft")
nt.3.compute <- dbReadTable(nt.3ft.db, "FVS_Compute") %>% 
  mutate(type = "3ft")
nt.5.compute <- dbReadTable(nt.5ft.db, "FVS_Compute") %>% 
  mutate(type = "5ft")
nt.7.compute <- dbReadTable(nt.7ft.db, "FVS_Compute") %>% 
  mutate(type = "7ft")
nt.10.compute <- dbReadTable(nt.10ft.db, "FVS_Compute") %>% 
  mutate(type = "10ft")
nt.20.compute <- dbReadTable(nt.20ft.db, "FVS_Compute") %>% 
  mutate(type = "20ft")
compute.all <- bind_rows(rx.compute, nt.1.compute,
                         nt.3.compute, nt.5.compute,
                         nt.7.compute, nt.10.compute,
                         nt.20.compute) %>% 
  select(-contains("Variant")) %>% 
  filter(Year == 2020) %>% 
  left_join(rx.cases %>% 
              select(StandID, Variant),
            by = "StandID")


# pull fuel consumption tables
rx.cases <- dbReadTable(rx.db,"FVS_Cases")

rx.consumption <- dbReadTable(rx.db, "FVS_Consumption") %>% 
  mutate(type = "rx")
nt.1.consumption <- dbReadTable(nt.1ft.db, "FVS_Consumption") %>% 
  mutate(type = "1ft")
nt.3.consumption <- dbReadTable(nt.3ft.db, "FVS_Consumption") %>% 
  mutate(type = "3ft")
nt.5.consumption <- dbReadTable(nt.5ft.db, "FVS_Consumption") %>% 
  mutate(type = "5ft")
nt.7.consumption <- dbReadTable(nt.7ft.db, "FVS_Consumption") %>% 
  mutate(type = "7ft")
nt.10.consumption <- dbReadTable(nt.10ft.db, "FVS_Consumption") %>% 
  mutate(type = "10ft")
nt.20.consumption <- dbReadTable(nt.20ft.db, "FVS_Consumption") %>% 
  mutate(type = "20ft")
consume.all <- bind_rows(rx.consumption, nt.1.consumption,
                         nt.3.consumption, nt.5.consumption,
                         nt.7.consumption, nt.10.consumption,
                         nt.20.consumption) %>% 
  select(-contains("Variant")) %>% 
  left_join(rx.cases %>% 
              select(StandID, Variant),
            by = "StandID")

# pull fuels tables
rx.fuels <- dbReadTable(rx.db, "FVS_Fuels") %>% 
  mutate(type = "rx")
nt.1.fuels <- dbReadTable(nt.1ft.db, "FVS_Fuels") %>% 
  mutate(type = "1ft")
nt.3.fuels <- dbReadTable(nt.3ft.db, "FVS_Fuels") %>% 
  mutate(type = "3ft")
nt.5.fuels <- dbReadTable(nt.5ft.db, "FVS_Fuels") %>% 
  mutate(type = "5ft")
nt.7.fuels <- dbReadTable(nt.7ft.db, "FVS_Fuels") %>% 
  mutate(type = "7ft")
nt.10.fuels <- dbReadTable(nt.10ft.db, "FVS_Fuels") %>% 
  mutate(type = "10ft")
nt.20.fuels <- dbReadTable(nt.20ft.db, "FVS_Fuels") %>% 
  mutate(type = "20ft")
fuels.all <- bind_rows(rx.fuels, nt.1.fuels,
                         nt.3.fuels, nt.5.fuels,
                         nt.7.fuels, nt.10.fuels,
                         nt.20.fuels) %>% 
  select(-contains("Variant")) %>% 
  filter(Year==2020) %>% 
  left_join(rx.cases %>% 
              select(StandID, Variant),
            by = "StandID")

# pull burn reports
rx.burn <- dbReadTable(rx.db, "FVS_BurnReport") %>% 
  mutate(type = "rx")
nt.1.burn <- dbReadTable(nt.1ft.db, "FVS_BurnReport") %>% 
  mutate(type = "1ft")
nt.3.burn <- dbReadTable(nt.3ft.db, "FVS_BurnReport") %>% 
  mutate(type = "3ft")
nt.5.burn <- dbReadTable(nt.5ft.db, "FVS_BurnReport") %>% 
  mutate(type = "5ft")
nt.7.burn <- dbReadTable(nt.7ft.db, "FVS_BurnReport") %>% 
  mutate(type = "7ft")
nt.10.burn <- dbReadTable(nt.10ft.db, "FVS_BurnReport") %>% 
  mutate(type = "10ft")
nt.20.burn <- dbReadTable(nt.20ft.db, "FVS_BurnReport") %>% 
  mutate(type = "20ft")
burn.all <- bind_rows(rx.burn, nt.1.burn,
                      nt.3.burn, nt.5.burn,
                      nt.7.burn, nt.10.burn,
                      nt.20.burn) %>% 
  select(-contains("Variant")) %>% 
  left_join(rx.cases %>% 
              select(StandID, Variant),
            by = "StandID")

# pull C reports
rx.carbon <- dbReadTable(rx.db, "FVS_Carbon") %>% 
  mutate(type = "rx")
nt.1.carbon <- dbReadTable(nt.1ft.db, "FVS_Carbon") %>% 
  mutate(type = "1ft")
nt.3.carbon <- dbReadTable(nt.3ft.db, "FVS_Carbon") %>% 
  mutate(type = "3ft")
nt.5.carbon <- dbReadTable(nt.5ft.db, "FVS_Carbon") %>% 
  mutate(type = "5ft")
nt.7.carbon <- dbReadTable(nt.7ft.db, "FVS_Carbon") %>% 
  mutate(type = "7ft")
nt.10.carbon <- dbReadTable(nt.10ft.db, "FVS_Carbon") %>% 
  mutate(type = "10ft")
nt.20.carbon <- dbReadTable(nt.20ft.db, "FVS_Carbon") %>% 
  mutate(type = "20ft")
carbon.all <- bind_rows(rx.carbon, nt.1.carbon,
                        nt.3.carbon, nt.5.carbon,
                        nt.7.carbon, nt.10.carbon,
                        nt.20.carbon) %>% 
  filter(Year == 2020) %>% 
  select(-contains("Variant")) %>% 
  left_join(rx.cases %>% 
              select(StandID, Variant),
            by = "StandID")




### Consumption-emissions plots

fvs.out <- burn.all %>% 
  left_join(compute.all,
            by = c("StandID","type","Variant","Year")) %>% 
  left_join(consume.all,
            by = c("StandID","type","Variant","Year")) %>% 
  left_join(fuels.all, 
            by = c("StandID","type","Variant","Year")) %>% 
  left_join(carbon.all,
            by = c("StandID","type","Variant","Year")) %>% 
  left_join(cats(fvs.info) %>% 
              as.data.frame() %>% 
              select(StandID, PLT_CN, FM_CN, FVSVariant) %>% 
              mutate(StandID = as.character(StandID)), 
            by = "StandID") %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          1,0))

fvs.out %>% 
  ggplot(.,
         aes(x = Carbon_Released_From_Fire,
             y = Smoke_Production_25)) +
  geom_point(pch = 19, size = 2.5, alpha = 0.6) +
  facet_wrap(facets=~type)

fvs.out %>% 
  ggplot(.,
         aes(x = Total_Consumption,
             y = Carbon_Released_From_Fire)) +
  geom_point(pch = 19, size = 2.5, alpha = 0.6) +
  facet_wrap(facets=~type)


### consumption density plots

fvs.out %>% 
  filter(type %in% c("rx", "1ft")) %>% 
  ggplot(.,
         aes(x = Duff_Consumption)) +
  geom_density(aes(fill = type)) +
  facet_wrap(facets=~Variant,scales="free")


### Fuel plots

fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          1,0)) %>% 
  filter(problem==1) %>% 
  pivot_wider(names_from = type,
              values_from = CBH,
              id_cols = c(StandID,problem,Variant)) %>% 
  ggplot(.,
         aes(x = rx)) +
  geom_point(aes(y = `1ft`,
                 col = "1ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `3ft`,
                 col = "3ft"),
             pch = 19,
             alpha = 0.6) +
  geom_point(aes(y = `5ft`,
                 col = "5ft"),
             pch = 19,
             alpha = 0.6) +
  geom_point(aes(y = `10ft`,
                 col = "10ft"),
             pch = 19,
             alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "black") +
  facet_wrap(facets = ~problem) +
  scale_color_manual(name = "FL",
                     values = c("1ft" = "dodgerblue2",
                                "3ft" = "gold2",
                                "5ft" = "firebrick3",
                                "10ft" = "purple4")) +
  labs(x = "CBH (Rx)",
       y = "CBH (WF)",
       title = "") +
  facet_wrap(facets=~problem)

#### Fuel moisture plots ----

fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          1,0)) %>% 
  filter(problem==1) %>% 
  pivot_wider(names_from = type,
              values_from = Percent_Trees_Crowning,
              id_cols = c(StandID,problem,Variant)) %>% 
  ggplot(.,
         aes(x = rx)) +
  geom_point(aes(y = `1ft`,
                 col = "1ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `3ft`,
                 col = "3ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `5ft`,
                 col = "5ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `10ft`,
                 col = "10ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "black") +
  facet_wrap(facets = ~problem) +
  scale_color_manual(name = "FL",
                     values = c("1ft" = "dodgerblue2",
                                "3ft" = "gold2",
                                "5ft" = "firebrick3",
                                "10ft" = "purple4")) +
  labs(x = "Rx % crowning",
       y = "WF % crowning (by FL bin)",
       title = "")

fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          1,0)) %>% 
  filter(problem==1) %>% 
  pivot_wider(names_from = type,
              values_from = Scorch_height,
              id_cols = c(StandID,problem,Variant)) %>% 
  ggplot(.,
         aes(x = rx)) +
  geom_point(aes(y = `1ft`,
                 col = "1ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `3ft`,
                 col = "3ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `5ft`,
                 col = "5ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `10ft`,
                 col = "10ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "black") +
  facet_wrap(facets = ~problem) +
  scale_color_manual(name = "FL",
                     values = c("1ft" = "dodgerblue2",
                                "3ft" = "gold2",
                                "5ft" = "firebrick3",
                                "10ft" = "purple4")) +
  labs(x = "Rx scorch height (ft)",
       y = "WF scorch height (ft; by FL bin)",
       title = "")

fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          T,F)) %>% 
  ggplot(.,
         aes(x = Flame_length,
             y = Scorch_height,
             col = type=="rx")) +
  geom_point(pch = 19,
             size = 2.5,
             alpha = 0.6) +
  facet_wrap(facets = ~problem)


fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          T,F)) %>% 
  filter(type == "rx") %>% 
  ggplot(.,
         aes(x = Flame_length,
             y = Scorch_height,
             col = Consumption_Crowns)) +
  geom_point(pch = 19,
             size = 2.5,
             alpha = 0.6) +
  facet_wrap(facets = ~problem)



fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          1,0)) %>% 
  filter(problem==1) %>% 
  pivot_wider(names_from = type,
              values_from = Consumption_6to12,
              id_cols = c(StandID,problem,Variant)) %>% 
  ggplot(.,
         aes(x = rx)) +
  geom_point(aes(y = `1ft`,
                 col = "1ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `3ft`,
                 col = "3ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `5ft`,
                 col = "5ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `10ft`,
                 col = "10ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "black") +
  facet_wrap(facets = ~problem) +
  scale_color_manual(name = "FL",
                     values = c("1ft" = "dodgerblue2",
                                "3ft" = "gold2",
                                "5ft" = "firebrick3",
                                "10ft" = "purple4")) +
  labs(x = "Rx consumption",
       y = "WF consumption (by FL bin)",
       title = "6-12 consumption")


fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          1,0)) %>% 
  filter(problem==1) %>% 
  pivot_wider(names_from = type,
              values_from = Carbon_Released_From_Fire,
              id_cols = c(StandID,problem,Variant)) %>% 
  ggplot(.,
         aes(x = rx)) +
  geom_point(aes(y = `1ft`,
                 col = "1ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `3ft`,
                 col = "3ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `5ft`,
                 col = "5ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `10ft`,
                 col = "10ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "red") +
  facet_wrap(facets = ~problem) +
  scale_color_manual(name = "FL",
                     values = c("1ft" = "dodgerblue2",
                                "3ft" = "gold2",
                                "5ft" = "firebrick3",
                                "10ft" = "purple4")) +
  labs(x = "Rx C_emissions",
       y = "WF C_emissions (by FL bin)")

fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          1,0)) %>% 
  filter(problem==1) %>% 
  pivot_wider(names_from = type,
              values_from = Carbon_Released_From_Fire,
              id_cols = c(StandID,problem,Variant)) %>% 
  ggplot(.,
         aes(x = rx)) +
  geom_point(aes(y = `1ft`,
                 col = "1ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `3ft`,
                 col = "3ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `5ft`,
                 col = "5ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_point(aes(y = `10ft`,
                 col = "10ft"),
             pch = 19, 
             alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "black") +
  facet_wrap(facets = ~problem) +
  scale_color_manual(name = "FL",
                     values = c("1ft" = "dodgerblue2",
                                "3ft" = "gold2",
                                "5ft" = "firebrick3",
                                "10ft" = "purple4")) +
  labs(x = "Rx C_emissions",
       y = "WF C_emissions (by FL bin)") +
  facet_wrap(facets = ~Variant,
             scales = "free")


fvs.out %>% 
  mutate(problem = ifelse(StandID %in% fvs.tab$StandID,
                          1,0)) %>% 
  filter(type %in% c("rx","1ft","5ft")) %>% 
  #filter(problem==1) %>% 
  ggplot(.,
         aes(x = Total_Consumption/Flame_length)) +
  geom_density(aes(fill = type),
               alpha = 0.4)



## FM summary table
burn.all %>% 
  filter(type == "rx") %>% 
  select(-Variant) %>% 
  left_join(rx.cases, by = "CaseID") %>%
  select(Variant,contains("Moisture")) %>% 
  group_by(Variant) %>% 
  summarise(across(where(is.numeric),mean),
            Stand_count = n()) %>% view()



burn.all %>% 
  ggplot(.,aes(x = One_Hr_Moisture)) +
  geom_density(aes(fill = type),
               alpha = 0.5,
               position="dodge")

ggplot() +
  geom_point(aes(x = rx.burn$One_Hr_Moisture,
                 y = nt.1.burn$One_Hr_Moisture)) +
  geom_point() +
  geom_abline(slope = 1, col= "red")


burn.all %>% 
  filter(type == "rx") %>% 
  select(-Variant) %>% 
  left_join(rx.cases, by = "CaseID") %>%
  group_by(Variant) %>% view()

## plot consumption versus fuel moistures

fvs.out %>% 
  filter(type == "1ft") %>% 
  ggplot(.,
         aes(x = One_Hr_Moisture,
             y = Total_Consumption)) +
  geom_point()





### older code -------

# all.consume <- rx.consumption %>% 
#   left_join(nt.1.consumption,
#             suffix = c("",".nt1"),
#             by = c("StandID","Year")) %>%
#   left_join(nt.3.consumption,
#             suffix = c("",".nt3"),
#             by = c("StandID","Year")) %>% 
#   left_join(nt.5.consumption,
#             suffix = c("",".nt5"),
#             by = c("StandID","Year")) %>% 
#   left_join(nt.7.consumption,
#             suffix = c("",".nt7"),
#             by = c("StandID","Year")) %>% 
#   left_join(nt.10.consumption,
#             suffix = c("",".nt10"),
#             by = c("StandID","Year")) %>% 
#   left_join(nt.20.consumption,
#             suffix = c(".rx",".nt20"),
#             by = c("StandID","Year")) %>%
#   left_join(rx.cases,
#             by = "StandID")

# quick plots -----

rx.consumption %>% 
  ggplot(.,
         aes(x = Total_Consumption,
             y = Smoke_Production_25)) +
  geom_point(pch = 19,
             size = 2.5,
             alpha = 0.7)

nt.1.consumption %>% 
  ggplot(.,
         aes(x = Total_Consumption,
             y = Smoke_Production_25)) +
  geom_point(pch = 19,
             size = 2.5,
             alpha = 0.7)

ggplot() +
  geom_point(data = rx.consumption,
             aes(x = Total_Consumption,
                 y = Smoke_Production_25,
                 col = "Rx"),
             pch = 19, 
             size = 3,
             alpha = 0.6) +
  geom_point(data = nt.1.consumption,
             aes(x = Total_Consumption,
                 y = Smoke_Production_25,
                 col = "NT"),
             pch = 19, 
             size = 3,
             alpha = 0.6) +
  scale_color_manual(name="",
                     values=c("Rx" = "dodgerblue3",
                              "NT" = "firebrick2"))
ggplot() +
  geom_point(data = rx.consumption,
             aes(x = Percent_Consumption_Duff,
                 y = Smoke_Production_25,
                 col = "Rx"),
             pch = 19, 
             size = 3,
             alpha = 0.6) +
  geom_point(data = nt.1.consumption,
             aes(x = Percent_Consumption_Duff,
                 y = Smoke_Production_25,
                 col = "NT"),
             pch = 19, 
             size = 3,
             alpha = 0.6) +
  scale_color_manual(name="",
                     values=c("Rx" = "dodgerblue3",
                              "NT" = "firebrick2"))

all.consume %>% 
  ggplot(.,
         aes(x = Smoke_Production_25.rx,
             y = Smoke_Production_25.nt)) +
  geom_point(pch = 19, 
             size = 3,
             alpha = 0.7) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "red")

all.consume %>% 
  ggplot(.,
         aes(x = Duff_Consumption.rx,
             y = Duff_Consumption.nt)) +
  geom_point(pch = 19, 
             size = 3,
             alpha = 0.7) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "red")

# Now we're only looking at stands with Rx>NT conditional2020 emissions ------------
# 
# 
# 
problem.stands <- fl.df %>% 
  filter(rx_nt_e_ratio>1) %>% 
  pull(StandID) %>% 
  unique()

all.consume %>% 
  filter(StandID %in% problem.stands) %>%
  ggplot(.,
         aes(x = Total_Consumption.rx,
             y = Total_Consumption.nt)) +
  geom_point(pch = 19, 
             size = 3,
             alpha = 0.7) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "red")

all.consume %>% 
  filter(StandID %in% problem.stands) %>%
  ggplot(.,
         aes(x = Total_Consumption.rx,
             y = Smoke_Production_25.rx)) +
  geom_point(pch = 19, 
             size = 3,
             alpha = 0.7) +
  geom_abline(slope = 1,
              intercept = 0,
              col = "red")

## now looking at more than 1 flame length...

all.consume %>% 
  ggplot(.,
         aes(x = Smoke_Production_25.rx,
             y = Smoke_Production_25.nt20)) +
  geom_point(aes(col = StandID %in% problem.stands),
             pch = 19,
             size = 3,
             alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0)+
  scale_color_manual(name="problem",
                     values=c("TRUE" = "firebrick2",
                              "FALSE" = "dodgerblue3"))

all.consume %>% 
  ggplot(.,
         aes(x = Smoke_Production_25.nt1,
             y = Smoke_Production_25.nt3)) +
  geom_point(#aes(col = StandID %in% problem.stands),
    pch = 19,
    size = 3,
    alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0,
              col="red")

all.consume %>% 
  ggplot(.,
         aes(x = Duff_Consumption.nt1,
             y = Duff_Consumption.nt3)) +
  geom_point(#aes(col = StandID %in% problem.stands),
    pch = 19,
    size = 3,
    alpha = 0.6) +
  geom_abline(slope = 1,
              intercept = 0,
              col="red")

