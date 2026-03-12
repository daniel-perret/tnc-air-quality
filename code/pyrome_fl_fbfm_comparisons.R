###### this script does emissions and fire intensity troubleshooting for a single pyrome -- here we're using pyrome 14, Idaho Batholith, as an example.

## loading up data

pyrome <- vect("../../SHARED_DATA/pyromes/Data/Pyromes_CONUS_20200206.shp")[14,] %>% project(crs("EPSG:5070"))


#conditional wildfire emissions following Rx treatment
# ce_diff_Rx_fire <- rast("data/flamstat/by_pyrome/emissions/conditional/differences/Rxfire_conditional_diff_pyrome_14.tif")

#conditional wildfire emissions 2020
ce_2020 <- rast("data/flamstat/by_pyrome/emissions/conditional/2020_baseline/ce_pyrome_14.tif")

#rx emissions 2020
rx_e_2020 <- rast("data/flamstat/by_pyrome/emissions/treatments/Rxfire/Rx_treat_pyrome_14.tif")

#rx-ce diff 2020
diff_2020 <- rast("data/flamstat/by_pyrome/emissions/treatments/Rx_NT_difference/rx_nt_diff_pyrome_14.tif")

lf_fbfm <- rast("../../SHARED_DATA/LANDFIRE/LF2022_FBFM40_220_CONUS/Tif/LC22_F40_220.tif") %>% 
  crop(pyrome, mask=T)

# fvs_fbfm <- rast("data/troubleshooting/fvs_fbfm.tif") %>%
#   crop(pyrome,mask=T)

rx_fl <- rast("data/flamstat/flamelength_rasters/Rx_fire_FVS_flamelength_masked.tif") %>% 
  crop(pyrome,mask=T)

nt_fl <- rast("data/flamstat/flamelength_rasters/PreTreatment_CONUS/CONUS_PreT_ConditionalFL.tif") %>% 
  crop(pyrome,mask=T)
names(nt_fl) <- "NT_fire_Flamstat_flamelength"
nt_fl[is.na(rx_fl)] <- NA

fvs.info <- rast("data/flamstat/metadata/TMFM2020_FVSVariant_Key/TMFM2020_FVSVariant_Key.tif") %>%
  crop(pyrome,mask=T)
activeCat(fvs.info) <- 8

gc()

## combining rasters into dataframe

fl.com <- c(rx_fl, nt_fl, rx_e_2020, ce_2020, diff_2020, lf_fbfm, fvs.info)
names(fl.com) <- c("rx_fl","nt_fl","rx_e","nt_e", "rx_nt_e_diff", "lf_fbfm", "StandID")

fl.df <- fl.com %>% 
  as.data.frame() %>% 
  na.omit() %>% 
  mutate(rx_fl = rx_fl/1000,
         rx_nt_fl_diff = rx_fl-nt_fl,
         rx_nt_e_ratio = rx_e/nt_e,
         rx_nt_fl_ratio = rx_fl/nt_fl)

fbfm.summary <- fl.df %>% 
  group_by(lf_fbfm, rx_nt_e_ratio>1) %>% 
  summarise(count = n()) %>% 
  group_by(lf_fbfm) %>% 
  mutate(prop = count/sum(count),
         pyrome.prop = count/nrow(fl.df))

## plots to get acquainted with the issue

# distribution of problematic emissions ratios
fl.df %>% 
  filter(rx_nt_e_ratio>1) %>% 
  ggplot(aes(x = rx_nt_e_ratio)) +
  geom_density() +
  geom_vline(aes(xintercept = mean(rx_nt_e_ratio)))

fl.df %>% 
  filter(rx_nt_e_ratio>1) %>% 
  summarize(mean = mean(rx_nt_e_ratio))

# distribution of problematic flame length differences
fl.df %>% 
  filter(rx_nt_e_ratio>1) %>% 
  ggplot(aes(x = rx_nt_fl_diff)) +
  geom_density(fill = "gray70",
               adjust = 2) +
  geom_vline(xintercept = 0, col= "red") +
  labs(x = "Rx FL - NT FL",
       title = "FL difference, problem pixels")

# plot Emissions diff vs FL diff
fl.df %>% 
  filter(rx_nt_e_ratio>1) %>% 
  sample_n(1e5) %>% 
  ggplot(aes(x = rx_nt_fl_ratio,
             y = rx_nt_e_ratio)) +
  geom_point(pch = 19,
             alpha = 0.3,
             size = 2.5) +
  facet_wrap(facets = ~lf_fbfm)

# plot FL distributions by FBFM
fl.df %>% 
  #filter(rx_nt_e_ratio>1) %>% 
  sample_n(1e6) %>% 
  ggplot() +
  geom_density(aes(x = rx_fl,
                   fill = "Rx"),
               alpha = 0.7,
               adjust=2.5) +
  geom_density(aes(x = nt_fl,
                   fill = "NT"),
               alpha = 0.7,
               adjust=2.5) +
  facet_wrap(facets = ~lf_fbfm,
             scales = "free") +
  scale_fill_manual(name = "",
                    values= c("Rx" = "dodgerblue3",
                              "NT" = "firebrick3"))


# plot E distributions by FBFM
fl.df %>% 
  #filter(rx_nt_e_ratio>1) %>% 
  sample_n(1e6) %>% 
  ggplot() +
  geom_density(aes(x = rx_e,
                   fill = "Rx"),
               alpha = 0.7,
               adjust=2.5) +
  geom_density(aes(x = nt_e,
                   fill = "NT"),
               alpha = 0.7,
               adjust=2.5) +
  facet_wrap(facets = ~lf_fbfm,
             scales = "free") +
  labs(x = "Emissions") + 
  scale_fill_manual(name = "",
                    values= c("Rx" = "dodgerblue3",
                              "NT" = "firebrick3"))

fl.df %>% 
  filter(rx_nt_e_ratio>1) %>% 
  #sample_n(1e6) %>% 
  ggplot() +
  geom_density(aes(x = rx_nt_e_ratio,
                   fill = "Emissions"),
               alpha = 0.7,
               adjust=2.5) +
  geom_density(aes(x = rx_nt_fl_ratio,
                   fill = "Flame length"),
               alpha = 0.7,
               adjust=2.5) +
  facet_wrap(facets = ~lf_fbfm,
             scales = "free") +
  labs(x = "Rx:NT ratio") + 
  geom_vline(xintercept=1) +
  scale_fill_manual(name = "",
                    values= c("Emissions" = "dodgerblue3",
                              "Flame length" = "firebrick3"))


## bar chart of fbfm40

fbfm.summary %>% 
  filter(`rx_nt_e_ratio > 1`) %>% 
  ggplot(.,
         aes(x = reorder(lf_fbfm,-prop),
             y = prop)) +
  geom_col() +
  labs(x = "LF FBFM40",
       y = "Proportion pixels Rx>NT emissions")


fbfm.summary %>% 
  filter(`rx_nt_e_ratio > 1`) %>% 
  ggplot(.,
         aes(x = reorder(lf_fbfm,-pyrome.prop),
             y = pyrome.prop)) +
  geom_col() +
  labs(x = "LF FBFM40",
       y = "Proportion of pyrome w/ Rx>NT emissions")

# let's hone in on TL1 and TL3...

fl.df %>% 
  filter(lf_fbfm == "TL3") %>% 
  ggplot(aes(x = rx_nt_fl_diff)) +
  geom_density(aes(fill = rx_nt_e_ratio>1),
               alpha = 0.8,
               adjust = 2.5) +
  geom_vline(xintercept=0)

fl.df %>% 
  #sample_n(1e6) %>% 
  filter(lf_fbfm == "TL1") %>% 
  ggplot(aes(x = nt_fl)) +
  geom_density(aes(fill = rx_nt_e_ratio>1),
               alpha = 0.8,
               adjust = 2.5) 

fl.df %>% 
  sample_n(1e6) %>% 
  #filter(lf_fbfm == "TL1") %>% 
  ggplot(aes(x = rx_nt_e_ratio)) +
  geom_density(aes(fill = rx_nt_fl_ratio>1),
               alpha = 0.8,
               adjust = 2.5) +
  geom_vline(xintercept=1) + 
  labs(x = "Rx:NT emissions ratio",
       title = "Idaho Batholith \nFL-Em comps") +
  scale_fill_manual(name = "Rx > NT Flamelength",
                    values=c("FALSE" = "dodgerblue3",
                             "TRUE" = "firebrick2"))

fl.df %>% 
  group_by(rx_nt_e_ratio > 1,
           nt_fl < 1.05) %>% 
  summarise(count = n()) %>% 
  group_by(`rx_nt_e_ratio > 1`) %>% 
  mutate(prop = count/sum(count)) %>% view()
