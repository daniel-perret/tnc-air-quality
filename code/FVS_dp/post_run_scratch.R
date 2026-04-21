test <- dbConnect(SQLite(), "outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")

test.burn <- dbReadTable(test, "FVS_BurnReport")

test.consume <- dbReadTable(test, "FVS_Consumption")

test.carb <- dbReadTable(test, "FVS_Carbon")

test.fuel <- dbReadTable(test, "FVS_Fuels") %>% 
  filter(Year == 2020)

test.comp <- dbReadTable(test, "FVS_Compute") %>% 
  filter(Year == 2020)


rh.cases <- dbReadTable(nt.10ft.db,"FVS_Cases")
rh.burn <- nt.10.burn %>% 
  left_join(rh.cases %>% 
              select(StandID, Variant),
            by="StandID") %>% 
  filter(Variant == "IE")

rh.consume <- dbReadTable(nt.10ft.db, "FVS_Consumption") %>% 
  left_join(rh.cases %>% 
              select(StandID, Variant),
            by="StandID") %>% 
  filter(Variant == "IE")

rh.comp <- dbReadTable(nt.10ft.db, "FVS_Compute") %>% 
  left_join(rh.cases %>% 
              select(StandID, Variant),
            by="StandID") %>% 
  filter(Variant == "IE",
         Year == 2020)

rh.fuel <- dbReadTable(nt.10ft.db, "FVS_Fuels") %>% 
  left_join(rh.cases %>% 
              select(StandID, Variant),
            by="StandID") %>% 
  filter(Variant == "IE",
         Year == 2020)


nrow(rh.burn)  


in.db <- dbConnect(SQLite(), "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/TMFM_2020_PN.db")
standinit <- dbReadTable(in.db, "FVS_STANDINIT")


ow.db <- dbConnect(SQLite(), "/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM2020_OkaWen/TMFM_2020_OkaWen_Databases/TMFM_2020_PN.db")
standinit <- dbReadTable(ow.db, "FVS_STANDINIT")

####------
####

db <- dbConnect(SQLite(), "FVS_runs/RH_reptest_WF_VarIE_modCan08Apr26_1153/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")
adj.burn <- dbReadTable(db, "FVS_BurnReport")
adj.consume <- dbReadTable(db, "FVS_Consumption")


db <- dbConnect(SQLite(), "FVS_runs/RH_reptest_WF_VarIE_31Mar26_1806/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")
base.burn <- dbReadTable(db, "FVS_BurnReport")
base.consume <- dbReadTable(db, "FVS_Consumption")
dbDisconnect(db)


plot(base.consume$Total_Consumption, adj.consume$Total_Consumption); abline(0,1,col="red")
plot(base.consume$Consumption_Crowns, adj.consume$Consumption_Crowns); abline(0,1,col="red")
plot(base.consume$Consumption_3to6, adj.consume$Consumption_3to6); abline(0,1,col="red")
plot(base.consume$Percent_Trees_Crowning, adj.consume$Percent_Trees_Crowning); abline(0,1,col="red")

plot(base.burn$Scorch_height, adj.burn$Scorch_height); abline(0,1,col="red")


####

rh.run <- extract_sqlite_tables("data/fvs_outputs/TreeMap2020_10ft_fl.db")

rh.compute <- rh.run$FVS_Compute %>% 
  left_join(rh.run$FVS_Cases %>% 
              select(StandID, Variant)) %>% 
  filter(Variant == "IE")

rh.consumption <- rh.run$FVS_Consumption %>% 
  left_join(rh.run$FVS_Cases %>% 
              select(StandID, Variant)) %>% 
  filter(Variant == "IE")

adj.run <- extract_sqlite_tables("FVS_runs/RH_reptest_WF_VarIE_modCan08Apr26_1535/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")

base.run <- extract_sqlite_tables("FVS_runs/RH_reptest_WF_VarIE_31Mar26_1806/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")

plot(base.run$FVS_Consumption$Total_Consumption, adj.run$FVS_Consumption$Total_Consumption);abline(0,1,col="red")

plot(base.run$FVS_Carbon$Carbon_Released_From_Fire, adj.run$FVS_Carbon$Carbon_Released_From_Fire);abline(0,1,col="red")

plot(base.run$FVS_Consumption$Consumption_Crowns, adj.run$FVS_Consumption$Consumption_Crowns);abline(0,1,col="red")

plot(base.run$FVS_Consumption$Consumption_6to12, adj.run$FVS_Consumption$Consumption_6to12);abline(0,1,col="red")

plot(base.run$FVS_BurnReport$Scorch_height, adj.run$FVS_BurnReport$Scorch_height)

plot(base.run$FVS_BurnReport$Midflame_Wind, adj.run$FVS_BurnReport$Midflame_Wind)

plot(base.run$FVS_BurnReport$Flame_length, adj.run$FVS_BurnReport$Flame_length)

####

rx <- extract_sqlite_tables(paste0(here(),"/data/fvs_outputs/TreeMap2020_RxFire_Onlyft_fl.db"))

rx.FVS_Carbon <- rx$FVS_Carbon %>% 
  left_join(rx$FVS_Cases %>% 
              select(StandID,Variant)) %>% 
  filter(Year==2020,
         Variant=="IE")

rx.FVS_Consumption <- rx$FVS_Consumption %>% 
  left_join(rx$FVS_Cases %>% 
              select(StandID,Variant)) %>% 
  filter(Year==2020,
         Variant=="IE")

plot(adj.run$FVS_Consumption$Consumption_Crowns, rx$FVS_Consumption$Consumption_Crowns);abline(0,1,col="red")

plot(adj.run$FVS_Carbon %>% 
       filter(Year==2020) %>% 
       pull(Carbon_Released_From_Fire), 
     rx.FVS_Carbon$Carbon_Released_From_Fire);abline(0,1,col="red")

plot(adj.run$FVS_Consumption %>% 
       filter(Year==2020) %>% 
         pull(Consumption_6to12), 
     rx.FVS_Consumption$Consumption_6to12);abline(0,1,col="red")


######

new.run <- extract_sqlite_tables("FVS_runs/RH_reptest_WF_VarIE_modCan13Apr26_1510/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")

cpc100.run <- extract_sqlite_tables("FVS_runs/RH_reptest_WF_VarIE_modCan16Apr26_1308/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")

yr2.run <- extract_sqlite_tables("FVS_runs/RH_reptest_WF_VarIE_modCan_yr2fire_16Apr26_1352/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")

adj.run <- extract_sqlite_tables("FVS_runs/RH_reptest_WF_VarIE_modCan08Apr26_1535/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db")

base.run <- extract_sqlite_tables(paste0(here(),"/FVS_runs/RH_reptest_WF_VarIE_31Mar26_1806/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db"))

rh.run <- extract_sqlite_tables("data/fvs_outputs/TreeMap2020_10ft_fl.db")

plot(new.run$FVS_BurnReport$Scorch_height, adj.run$FVS_BurnReport$Scorch_height);abline(0,1,col="red")
plot(new.run$FVS_Compute$HS_, base.run$FVS_Compute$HS_);abline(0,1,col="red")

test <- extract_sqlite_tables(paste0(here(),"/FVS_runs/DryRun_test_Cycle2_complete_20Apr26_1118/outputs/NoTreat_FlameAdjust_wildfire_10_IE.db"))

View(test$FVS_Compute)

init <- extract_sqlite_tables("/Users/daniel.perret/LOCAL_WORKSPACE/SHARED_DATA/FVS_inputs/TMFM_2020_InputDatabases/TMFM_2020_IE.db")
names(init)

hist(test$FVS_Consumption$Percent_Trees_Crowning)

plot(base.run$FVS_Consumption$Total_Consumption, test$FVS_Consumption$Total_Consumption);abline(0,1,col="red")
plot(base.run$FVS_Consumption$Consumption_Crowns, test$FVS_Consumption$Consumption_Crowns);abline(0,1,col="red")

summary((test$FVS_Consumption$Consumption_Crowns-base.run$FVS_Consumption$Consumption_Crowns)/base.run$FVS_Consumption$Consumption_Crowns)

sum((test$FVS_Consumption$Consumption_Crowns-base.run$FVS_Consumption$Consumption_Crowns)/base.run$FVS_Consumption$Consumption_Crowns > 0.05)

384/nrow(test$FVS_BurnReport)

rx.test <- extract_sqlite_tables(paste0(here(),"/FVS_runs/RxWetRun_test_Cycle2_complete_20Apr26_1330/outputs/ModRxFire_NoWF_IE.db"))

View(rx.test$FVS_Compute)

plot(rx.test$FVS_BurnReport$Flame_length, rx.test$FVS_Compute %>% 
       filter(Year==2020) %>% 
       pull(FLEN_INI))
abline(0,1,col="red")

rx.test$FVS_BurnReport %>% 
  select(StandID, Flame_length) %>% 
  left_join(rx.test$FVS_Compute %>% 
              filter(Year==2020) %>% 
              select(StandID, FLEN_INI)) %>% 
  view()

plot(rx.FVS_Consumption$Total_Consumption, rx.test$FVS_Consumption$Total_Consumption)
abline(0,1,col="red")

plot(rx.test$FVS_Carbon %>% 
       filter(Year==2020) %>% 
       pull(Carbon_Released_From_Fire),
     rx.test$FVS_Consumption$Smoke_Production_25)
