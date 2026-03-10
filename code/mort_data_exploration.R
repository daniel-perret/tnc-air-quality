### A little bit of code to play with relating fire intensity-mortality relationships to treatment types and other aspects
### 

mort.dat <- read.csv("data/flamstat/mortality/Mortality_Metrics_FlamStat.csv",
                     header = T, stringsAsFactors = F)

mort.dat.prop <- read.csv("data/flamstat/mortality/Mortality_Percent_FlamStat.csv",
                     header = T, stringsAsFactors = F)

mort.dat.rshp <- mort.dat %>% 
  rename_with(~str_replace_all(.x, "_WF", "WF")) %>% 
  pivot_longer(., cols = contains("kill"),
               names_to = c("metric","type","flamelength"),
               names_sep = "_", values_to = "mort") %>% 
  pivot_wider(.,values_from = "mort", names_from = "metric") %>% 
  mutate(flamelength = as.numeric(substr(flamelength,
                                         start = 1, 
                                         stop = nchar(flamelength)-2))) %>% 
  mutate(ba0 = case_when(type == "PostFire" ~ BA_0,
                         type == "PostRxWF" ~ BA_RxFire_0,
                         type == "PostMechWF" ~ BA_MechRL_0),
         vol0 = case_when(type == "PostFire" ~ TCuFt_0,
                          type == "PostRxWF" ~ TCuFt_RxFire_0,
                          type == "PostMechWF" ~ TCuFt_MechRL_0),
         Bakill.prop = Bakill/ba0,
         Volkill.prop = Volkill/vol0) %>% 

mort.dat.rshp %>%
  na.omit() %>% 
  ggplot(.,
         aes(x = flamelength,
             y = Bakill/ba0)) +
  geom_point() +
  facet_wrap(facets = ~type) +
  labs(x = "Conditional Flame Length",
       y = "Mortality (% BA)")
