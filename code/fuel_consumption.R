##### Here I'm digging into the FVS outputs for 2020 NT-wildfire and Rx fire runs to gain insight into how differential fuel consumption is related to emissions differences


# load up FVS output databases
rx.db <- dbConnect(SQLite(), 
                   "data/fvs_outputs/TreeMap2020_SimpleRxFire_Compute.db")
nt.1ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_1_ft_fl.db")
nt.3ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_3_ft_fl.db")
nt.5ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_5_ft_fl.db")
nt.7ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_7_ft_fl.db")
nt.10ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_10_ft_fl.db")
nt.20ft.db <- dbConnect(SQLite(), 
                       "data/fvs_outputs/TreeMap2020_20_ft_fl.db")



dbListTables(nt.20ft.db)

# pull fuel consumption tables

rx.consumption <- dbReadTable(rx.db, "FVS_Consumption")
rx.cases <- dbReadTable(rx.db,"FVS_Cases")
nt.1.consumption <- dbReadTable(nt.1ft.db, "FVS_Consumption")
nt.3.consumption <- dbReadTable(nt.3ft.db, "FVS_Consumption")
nt.5.consumption <- dbReadTable(nt.5ft.db, "FVS_Consumption")
nt.7.consumption <- dbReadTable(nt.7ft.db, "FVS_Consumption")
nt.10.consumption <- dbReadTable(nt.10ft.db, "FVS_Consumption")
nt.20.consumption <- dbReadTable(nt.20ft.db, "FVS_Consumption")

all.consume <- rx.consumption %>% 
  left_join(nt.1.consumption,
            suffix = c("",".nt1"),
            by = c("StandID","Year")) %>%
  left_join(nt.3.consumption,
            suffix = c("",".nt3"),
            by = c("StandID","Year")) %>% 
  left_join(nt.5.consumption,
            suffix = c("",".nt5"),
            by = c("StandID","Year")) %>% 
  left_join(nt.7.consumption,
            suffix = c("",".nt7"),
            by = c("StandID","Year")) %>% 
  left_join(nt.10.consumption,
            suffix = c("",".nt10"),
            by = c("StandID","Year")) %>% 
  left_join(nt.20.consumption,
            suffix = c(".rx",".nt20"),
            by = c("StandID","Year")) %>%
  left_join(rx.cases,
            by = "StandID")

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

