y3.bm.1ft <- extract_sqlite_tables("FVS_runs/full/Wildfire_Y3_09Jul26_1413/outputs/NoTreat_FlameAdjust_wildfire_1_BM.db")

y1.bm.1ft <- extract_sqlite_tables("FVS_runs/full/Wildfire_WetRun_21May26_0855/outputs/NoTreat_FlameAdjust_wildfire_1_BM.db")

View(y3.bm.1ft$FVS_Consumption)

plot(y1.bm.1ft$FVS_Consumption$Total_Consumption, y3.bm.1ft$FVS_Consumption$Total_Consumption)

library(ggplot2)
library(patchwork)

######################################################################
################## comparing consumption between Y1 and Y3 ###########
######################################################################

# Extract consumption columns (exclude derived metrics like percentages and smoke)
fuel_classes <- c("Litter_Consumption", "Duff_Consumption", "Consumption_lt3", 
                  "Consumption_ge3", "Consumption_3to6", "Consumption_6to12", 
                  "Consumption_ge12", "Consumption_Herb_Shrub", "Consumption_Crowns",
                  "Total_Consumption")

# Create a list of scatterplots
scatterplots <- lapply(fuel_classes, function(col) {
  y1_data <- y1.bm.1ft$FVS_Consumption[[col]]
  y3_data <- y3.bm.1ft$FVS_Consumption[[col]]
  
  df <- data.frame(Y1 = y1_data, Y3 = y3_data)
  
  max_val <- max(c(y1_data, y3_data), na.rm = TRUE)
  
  ggplot(data = df, aes(x = Y1, y = Y3)) +
    geom_point(alpha = 0.5, size = 1) +
    geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
    labs(title = col, x = "Y1 fire", y = "Y3 fire") +
    #theme_minimal() +
    theme(aspect.ratio = 1, 
          plot.title = element_text(size = 10, face = "bold")) +
    lims(x = c(0, max_val), y = c(0, max_val))
})

# Combine into a grid
combined <- wrap_plots(scatterplots, ncol = 3)
combined

######################################################################
################## comparing consumption between Y1 and Y3 ###########
################## now across all variants, in figures folder ########
######################################################################

library(dplyr)

# Define fuel classes to plot
fuel_classes <- c("Litter_Consumption", "Duff_Consumption", "Consumption_lt3", 
                  "Consumption_ge3", "Consumption_3to6", "Consumption_6to12", 
                  "Consumption_ge12", "Consumption_Herb_Shrub", "Consumption_Crowns",
                  "Total_Consumption")

# Find all variants from Y1 run
y1_run_dir <- "FVS_runs/full/Wildfire_WetRun_21May26_0855/outputs"
y3_run_dir <- "FVS_runs/full/Wildfire_Y3_09Jul26_1413/outputs"

y1_files <- list.files(y1_run_dir, pattern = "_5_.*\\.db$", full.names = TRUE)
variants <- sub(".*_5_([A-Z]+)\\.db$", "\\1", y1_files)

# Create one figure per variant
for (variant in variants) {
  
  # Load Y1 and Y3 databases for this variant
  y1_db_path <- file.path(y1_run_dir, paste0("NoTreat_FlameAdjust_wildfire_5_", variant, ".db"))
  y3_db_path <- file.path(y3_run_dir, paste0("NoTreat_FlameAdjust_wildfire_5_", variant, ".db"))
  
  if (!file.exists(y1_db_path) || !file.exists(y3_db_path)) {
    warning("Missing database for variant: ", variant)
    next
  }
  
  y1_data <- extract_sqlite_tables(y1_db_path)
  y3_data <- extract_sqlite_tables(y3_db_path)
  
  # Create a list of scatterplots for this variant
  scatterplots <- lapply(fuel_classes, function(col) {
    
    y1_vals <- y1_data$FVS_Consumption[[col]]
    y3_vals <- y3_data$FVS_Consumption[[col]]
    
    df <- data.frame(Y1 = y1_vals, Y3 = y3_vals) %>%
      filter(!is.na(Y1) & !is.na(Y3))
    
    max_val <- max(c(df$Y1, df$Y3), na.rm = TRUE)
    
    # Calculate statistics
    r2 <- cor(df$Y1, df$Y3)^2
    fit <- lm(Y3 ~ Y1, data = df)
    slope <- coef(fit)[2]
    mean_diff <- mean(df$Y3 - df$Y1, na.rm = TRUE)
    summed_diff <- sum(df$Y3 - df$Y1, na.rm = TRUE)
    
    # Format text for plot
    stats_text <- paste0(
      "r² = ", round(r2, 3), "\n",
      "slope = ", round(slope, 3), "\n",
      "mean diff = ", round(mean_diff, 2), "\n",
      "summed diff = ", round(summed_diff, 2)
    )
    
    ggplot(data = df, aes(x = Y1, y = Y3)) +
      geom_point(alpha = 0.5, size = 1) +
      geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
      annotate("text", x = Inf, y = -Inf, label = stats_text,
               hjust = 1.1, vjust = -0.5, size = 3, family = "monospace") +
      labs(title = col, x = "Y1 fire", y = "Y3 fire") +
      theme(aspect.ratio = 1, 
            plot.title = element_text(size = 10, face = "bold")) +
      lims(x = c(0, max_val), y = c(0, max_val))
  })
  
  # Combine into a grid with variant name at the top
  combined <- wrap_plots(scatterplots, ncol = 3) +
    plot_annotation(
      title = paste("Variant:", variant),
      theme = theme(plot.title = element_text(size = 14, face = "bold", hjust = 0.5))
    )  
  # Save to figures directory
  output_path <- file.path("figures/y1_y3_wf_comparisons", 
                           paste0("WF_5ft_Y1vsY3_", variant, ".png"))
  
  # Create directory if it doesn't exist
  dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
  
  ggsave(output_path, plot = combined, width = 12, height = 10, dpi = 300)
  
  cat("Saved:", output_path, "\n")
}

######################################################################
############## comparing Carbon Released From Fire ####################
############## across flame length classes and variants ###############
######################################################################

# Define flame lengths to compare
flame_lengths <- c(1, 3, 5, 7, 10, 20)

# Find all variants from Y1 run
y1_run_dir <- "FVS_runs/full/Wildfire_WetRun_21May26_0855/outputs"
y3_run_dir <- "FVS_runs/full/Wildfire_Y3_09Jul26_1413/outputs"

y1_files <- list.files(y1_run_dir, pattern = "_1_.*\\.db$", full.names = TRUE)
variants <- sub(".*_1_([A-Z]+)\\.db$", "\\1", y1_files)

# Create one figure per variant
for (variant in variants) {
  
  scatterplots <- list()
  
  # Create a scatterplot for each flame length
  for (fl in flame_lengths) {
    
    # Load Y1 and Y3 databases for this variant and flame length
    y1_db_path <- file.path(y1_run_dir, paste0("NoTreat_FlameAdjust_wildfire_", fl, "_", variant, ".db"))
    y3_db_path <- file.path(y3_run_dir, paste0("NoTreat_FlameAdjust_wildfire_", fl, "_", variant, ".db"))
    
    if (!file.exists(y1_db_path) || !file.exists(y3_db_path)) {
      warning("Missing database for variant: ", variant, ", flame length: ", fl)
      scatterplots[[paste0("FL_", fl)]] <- ggplot() + 
        geom_text(aes(x = 0.5, y = 0.5, label = "Data not available"),
                  size = 5) +
        theme_void()
      next
    }
    
    y1_data <- extract_sqlite_tables(y1_db_path)
    y3_data <- extract_sqlite_tables(y3_db_path)
    
    # Extract Carbon_Released_From_Fire for burn year (2020 for Y1, 2022 for Y3)
    y1_crf <- y1_data$FVS_Carbon %>%
      filter(Year == 2020) %>%
      pull(Carbon_Released_From_Fire)
    
    y3_crf <- y3_data$FVS_Carbon %>%
      filter(Year == 2022) %>%
      pull(Carbon_Released_From_Fire)
    
    df <- data.frame(Y1 = y1_crf, Y3 = y3_crf) %>%
      filter(!is.na(Y1) & !is.na(Y3))
    
    max_val <- max(c(df$Y1, df$Y3), na.rm = TRUE)
    
    # Calculate statistics
    r2 <- cor(df$Y1, df$Y3)^2
    fit <- lm(Y3 ~ Y1, data = df)
    slope <- coef(fit)[2]
    mean_diff <- mean(df$Y3 - df$Y1, na.rm = TRUE)
    summed_diff <- sum(df$Y3 - df$Y1, na.rm = TRUE)
    
    # Format text for plot
    stats_text <- paste0(
      "r² = ", round(r2, 3), "\n",
      "slope = ", round(slope, 3), "\n",
      "mean diff = ", round(mean_diff, 2), "\n",
      "summed diff = ", round(summed_diff, 2)
    )
    
    p <- ggplot(data = df, aes(x = Y1, y = Y3)) +
      geom_point(alpha = 0.5, size = 1) +
      geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
      annotate("text", x = Inf, y = -Inf, label = stats_text,
               hjust = 1.1, vjust = -0.5, size = 3, family = "monospace") +
      labs(title = paste("Flame Length", fl, "ft"), x = "Y1 fire", y = "Y3 fire") +
      theme(aspect.ratio = 1, 
            plot.title = element_text(size = 10, face = "bold")) +
      lims(x = c(0, max_val), y = c(0, max_val))
    
    scatterplots[[paste0("FL_", fl)]] <- p
  }
  
  # Combine into a grid with variant name at the top
  combined <- wrap_plots(scatterplots, ncol = 3) +
    plot_annotation(
      title = paste("Variant:", variant, "| Carbon Released From Fire (Y1: 2020, Y3: 2022)"),
      theme = theme(plot.title = element_text(size = 14, face = "bold", hjust = 0.5))
    )
  
  # Save to figures directory
  output_path <- file.path("figures/y1_y3_wf_comparisons/carbon", 
                           paste0("WF_CRF_Y1vsY3_", variant, ".png"))
  
  # Create directory if it doesn't exist
  dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
  
  ggsave(output_path, plot = combined, width = 12, height = 8, dpi = 300)
  
  cat("Saved:", output_path, "\n")
}
