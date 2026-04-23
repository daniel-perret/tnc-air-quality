### This script explores how to match standIDs and LandFire FBFM40 assignments for the IE variation
### Key questions:
### 1 -- how much would this explode the number of necessary FVS runs?
### 2 -- what would the best way to implement this be? Somewhere in the key file?
### 3 ------ if there's a subset of FBFMs that are repeated, then maybe could just run the whole shebang a couple times and grab the combinations?

tm <- rast("data/dp_FVS_postprocess/DryRun_test_Cycle2_complete_20Apr26_1118/tm_ref_IE.tif")
tm.rat <- cats(tm) %>% as.data.frame()
activeCat(tm) <- 8

lf.fbfm <- rast("../../SHARED_DATA/LANDFIRE/LF2022_FBFM40_220_CONUS/Tif/LC22_F40_220.tif") %>% 
  crop(., tm, mask = T)

combos <- terra::crosstab(c(tm, lf.fbfm)) %>%
  as.data.frame()

combos2 <- combos %>% 
  filter(Freq>0)

combos2 %>% 
  group_by(StandID) %>% 
  summarise(n=n()) %>% 
  pull(n) %>% 
  hist()
