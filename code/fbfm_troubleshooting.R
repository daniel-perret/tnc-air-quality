rx.wf.ratio <- rast("data/dp_FVS_postprocess/RxWetRun_fullLFmatch_FLENbin_13May26_0854/Rx_WF_ratio.tif")
names(rx.wf.ratio) <- "Rx_WF_Ratio"

rx.fl <- rast("data/dp_FVS_postprocess/RxWetRun_fullLFmatch_FLENbin_13May26_0854/Rx_FlameLength.tif")

tm <- rast("data/dp_FVS_postprocess/RxWetRun_fullLFmatch_12May26_1053/tmlf_key_IE.tif")

lf.fbfm <- rast("../../SHARED_DATA/LANDFIRE/LF2022_FBFM40_220_CONUS/Tif/LC22_F40_220.tif") %>% 
  crop(., tm, mask = T)
activeCat(lf.fbfm) <- 2

rx.fvs <- extract_sqlite_tables("FVS_runs/RxWetRun_fullLFmatch_FLENbin_13May26_0854/outputs/ModRxFire_NoWF_IE.db")

set.seed(4)
ratio.sample <- spatSample(rx.wf.ratio,size = 1e6,cells= T, na.rm=T) %>% na.omit()
fl.sample <- values(rx.fl)[ratio.sample$cell]
tm.sample <- values(tm)[ratio.sample$cell]
#lf.sample <- values(lf.fbfm)[ratio.sample$cell]

r.sample <- ratio.sample %>% 
  mutate(Rx_FlameLength = fl.sample,
         StandID = as.numeric(tm.sample)) %>% 
  # left_join(cats(lf.fbfm) %>% 
  #             as.data.frame() %>% 
  #             select(Value, FBFM40),
  mutate(Rx_FlameLength = fl.sample,
         StandID = as.numeric(tm.sample)) %>% 
  # left_join(cats(lf.fbfm) %>% 
  #             as.data.frame() %>% 
  #             select(Value, FBFM40),
  #           by=c("LF_FBFM" = "Value")) %>% 
  left_join(rx.fvs$FVS_BurnReport %>% 
              mutate(StandID = as.numeric(StandID)),
            by="StandID")

r.sample %>% 
  ggplot(.,aes(x = Rx_FlameLength,
               y = Rx_WF_Ratio)) + 
  geom_point(pch=19,
             alpha = 0.1)+
  geom_point(data = r.sample %>% filter(Rx_WF_Ratio>1),
             #aes(col = FBFM40),
             pch = 19,
             alpha = 0.8) +
  geom_hline(yintercept=1, col="red", lwd=1) + 
  scale_x_continuous(breaks = scales::breaks_width(2))

r.sample %>% 
  ggplot(.,aes(x = Rx_WF_Ratio)) + 
  geom_density(fill = "dodgerblue") +
  geom_vline(xintercept = 1, lwd = 1, col = "red") +
  labs(x = "Rx:WF emissions ratio") +
  lims(x=c(0,1.5))


r.sample %>% 
  #filter(Rx_WF_Ratio>1) %>% 
  ggplot(aes(x = LF_FBFM,
             y = FuelModl1))+
  geom_point(aes(col = Rx_WF_Ratio>1))+
  geom_abline(slope = 1, intercept = 0, col= "red")

expand.grid(LF = c(101:108,121:124,141:149,161:165,181:189,201:204),
            FVS = c(101:108,121:124,141:149,161:165,181:189,201:204)) %>% 
  left_join(r.sample %>% 
              group_by(LF_FBFM, FuelModl1) %>% 
              summarise(n = n()),
            by = c("LF" = "LF_FBFM",
                   "FVS" = "FuelModl1")) %>% 
  mutate(n = ifelse(is.na(n),0,n)) %>% 
  ggplot(., 
         aes(x = as.factor(LF), 
             y = as.factor(FVS), fill = n)) +
  geom_tile(color = "white") +
  scale_fill_gradient(low = "#f7fbff", high = "#08306b") +
  labs(x = "Landfire FBFM",
       y = "FVS FBFM",
       fill = "Count") +
  coord_fixed()+
  geom_abline(slope=1,intercept=0,col="red")+
  theme(axis.text.x = element_text(angle= 45,hjust=0.75))


# summaries

sum(r.sample$Rx_WF_Ratio>1.0001)/nrow(r.sample)

length(unique(r.sample$StandID[which(r.sample$Rx_WF_Ratio>1.0001)]))/length(unique(r.sample$StandID))

r.sample %>% 
  group_by(LF_FBFM) %>% 
  summarise(prop.gt1 = sum(Rx_WF_Ratio>1)/n()) %>% 
  view()

r.sample %>% 
  filter(Rx_WF_Ratio>1) %>% 
  group_by(FBFM40) %>% 
  summarise(prop = n()/nrow(.))

r.sample %>% 
  filter(Rx_WF_Ratio>1) %>% 
  group_by(FuelModl1) %>% 
  summarise(prop = n()/nrow(.))


r.sample %>% 
  filter(Rx_WF_Ratio>1) %>% 
  count(FuelModl1, LF_FBFM) %>% 
  mutate(prop = n/sum(n)) %>% view()


old.rat <- rast("data/dp_FVS_postprocess/original_rx_nt_ratio_IE.tif")
old.sample <- values(old.rat)[ratio.sample$cell]

sum(old.sample>1)/nrow(r.sample)

length(unique(r.sample$StandID[which(old.sample>1)]))/length(unique(r.sample$StandID))

r.sample %>% filter(Rx_WF_Ratio>1) %>% pull(Rx_WF_Ratio) %>% mean()




wf.list <- list.files("FVS_runs/dev/DryRun_test_Cycle2_complete_20Apr26_1118/outputs/",
                      full.names = T)
wf.compute <- data.frame()
for(path in wf.list){
  x <- extract_sqlite_tables(path)
  wf.compute <- wf.compute %>% 
    bind_rows(x$FVS_Compute)
}
wf.consume <- data.frame()
for(path in wf.list){
  x <- extract_sqlite_tables(path)
  wf.consume <- wf.consume %>% 
    bind_rows(x$FVS_Consumption)
}
