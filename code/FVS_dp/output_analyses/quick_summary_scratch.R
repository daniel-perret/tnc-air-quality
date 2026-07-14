ratio <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_masked.tif")
ratio.90 <- rast("data/dp_FVS_postprocess/CONUS_mosaic/Rx_WF_ratio_90p.tif")

n_above_1001 <- terra::global(ratio > 1.001, "sum")[1, 1]

# Total non-NA cells
n_above_1001 <- terra::global(ratio > 1.001, "sum", na.rm = TRUE)[1, 1]

# Percentage
pct_above_1001 <- (n_above_1001 / n_total) * 100

message("Cells with ratio > 1.001: ", format(n_above_1001, big.mark = ","))
message("Total non-NA cells: ", format(n_total, big.mark = ","))
message("Percentage: ", round(pct_above_1001, 2), "%")



hist(ratio)

hist(rast("data/dp_FVS_postprocess/RxWetRun_03Jun26_2229/BM/Rx_WF_ratio.tif"))
hist(rast("data/dp_FVS_postprocess/RxWetRun_03Jun26_2229/IE/Rx_WF_ratio.tif"))
hist(rast("data/dp_FVS_postprocess/RxWetRun_03Jun26_2229/NE/Rx_WF_ratio.tif"))
hist(rast("data/dp_FVS_postprocess/RxWetRun_03Jun26_2229//Rx_WF_ratio.tif"))

hist(rast("data/dp_FVS_postprocess/CONUS_mosaic/WF_Conditional_mean_CarbonReleasedFromFire.tif"))

summary <- terra::global(ratio, "summary", na.rm = TRUE)


# Calculate percentiles by processing in smaller chunks
set.seed(4)
samp <- spatSample(ratio, size = 1e5, method = "random", na.rm = TRUE)
samp.90 <- spatSample(ratio.90, size = 1e5, method = "random", na.rm = TRUE)

quantile(samp[,1], probs = c(0.50, 0.75, 0.90))


west <- sf::read_sf("../../SHARED_DATA/base_spatialdata/state_boundaries/state_boundaries.shp") %>% 
  filter(STATE %in% c("WA","OR","CA","ID","NV","MT","WY","UT","CO","AZ","NM")) %>% 
  sf::st_transform(crs(ratio))

west.ratio <- terra::crop(ratio, west, mask = T)
west.ratio.90 <- terra::crop(ratio.90, west, mask=T)

set.seed(4)
west.samp.90 <- spatSample(west.ratio.90, size = 1e5, cells=T, method = "random", na.rm = T)
west.samp <- spatSample(west.ratio, size = 1e5, cells=T, method = "random", na.rm = T)

quantile(west.samp[,2], probs = c(0.5, 0.75, 0.90))

west.samp %>% 
  mutate(`T` = Rx_CarbonReleasedFromFire) %>% 
  ggplot(.,
         aes(x = `T`)) +
  geom_density(fill = "dodgerblue4", alpha = 0.5) +
  geom_vline(xintercept = quantile(west.samp[,2], probs = c(0.5, 0.75, 0.90)), linetype = "dashed", color = "red") +
  labs(title = "Rx to untreated wildfire emissions ratio (T) \n Western US")

samp %>% 
  mutate(`T` = Rx_CarbonReleasedFromFire) %>% 
  ggplot(.,
         aes(x = `T`)) +
  geom_density(fill = "dodgerblue4", alpha = 0.5) +
  geom_vline(xintercept = quantile(samp[,1], probs = c(0.5, 0.75, 0.90)), linetype = "dashed", color = "red") +
  labs(title = "Rx to untreated wildfire emissions ratio (T) \n CONUS")
  
ggplot(data = west.samp %>% 
         filter(Rx_CarbonReleasedFromFire<1)) +
  geom_density(aes(x = Rx_CarbonReleasedFromFire,
                   fill = "Mean conditional FL")) + 
  geom_density(data = west.samp.90,
               aes(x = Rx_CarbonReleasedFromFire,
                   fill = "90th percentile conditional FL"),
               alpha = 0.6) +
  scale_fill_manual(name = "",
                    values = c("Mean conditional FL" = "dodgerblue4", 
                               "90th percentile conditional FL" = "orange")) +
  labs(x = "`T` ratio")



wf.ce <- rast("data/dp_FVS_postprocess/CONUS_mosaic/WF_Conditional_mean_CarbonReleasedFromFire.tif")
wf.ce.90 <- rast("data/dp_FVS_postprocess/CONUS_mosaic/WF_90p_top10pct_mean_CarbonReleasedFromFire.tif")

plot(wf.ce, wf.ce.90, maxcell = 1e6)




















