# Blackfoot Watershed Leaflet Map
# Interactive map of FVS emissions modeling outputs
# Hosted on GitHub Pages: daniel-perret.github.io

library(leaflet)
library(terra)
library(sf)
library(tidyverse)
library(htmlwidgets)
library(shiny)

# ============================================================================
# CONFIGURATION
# ============================================================================

blackfoot_shp  <- '../blackfoot-watershed/data/spatial/bfws.shp'
raster_dir     <- 'data/dp_FVS_postprocess/CONUS_mosaic/'
flamelength_dir <- 'data/flamstat/flamelength_rasters/PreTreatment_CONUS/'
output_dir     <- '../daniel-perret.github.io-fresh/for_collaborators/'
output_file    <- paste0(output_dir, 'blackfoot_emissions.html')

# Raster layer specs — each layer belongs to a legend group
raster_specs <- tibble(
  filename = c(
    "Rx_WF_ratio_masked.tif",
    "Rx_WF_ratio_90p.tif",
    "Rx_CarbonReleasedFromFire.tif",
    "Rx_FlameLength.tif",
    "WF_Conditional_mean_CarbonReleasedFromFire.tif",
    "WF_90p_top10pct_mean_CarbonReleasedFromFire.tif",
    "CONUS_PreT_ConditionalFL.tif"
  ),
  layer_name = c(
    "Rx/WF Ratio",
    "Rx/WF Ratio (severe)",
    "Rx Carbon Released",
    "Rx Flame Length",
    "WF Carbon Released (Mean)",
    "WF Carbon Released (severe)",
    "PreTreatment Conditional FL"
  ),
  legend_group = c(
    "ratio", "ratio",
    "carbon",
    "flamelength",
    "carbon", "carbon",
    "flamelength"
  ),
  directory = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE)
)

# Shared color scale and display info per legend group
legend_group_specs <- tribble(
  ~group_id,     ~title,             ~palette,
  "ratio",       "Rx/WF Ratio",      "plasma",
  "carbon",      "Carbon Released",  "YlOrRd",
  "flamelength", "Flame Length",     "Reds"
)

# ============================================================================
# LOAD AND PREPARE DATA
# ============================================================================

cat("Loading blackfoot watershed boundary...\n")
bfws      <- st_read(blackfoot_shp, quiet = TRUE)
bfws_wgs84 <- st_transform(bfws, 4326)
bbox      <- st_bbox(bfws_wgs84)

cat("Loading and cropping rasters...\n")

rasters_list <- pmap(
  list(raster_specs$filename, raster_specs$layer_name, raster_specs$directory),
  function(filename, layer_name, use_flamelength_dir) {
    cat("  Processing:", layer_name, "\n")
    directory <- if (use_flamelength_dir) flamelength_dir else raster_dir
    r <- rast(paste0(directory, filename))
    bfws_proj <- st_transform(bfws, st_crs(r))
    mask(crop(r, bfws_proj), bfws_proj)
  }
)

names(rasters_list) <- raster_specs$layer_name

# ============================================================================
# COMPUTE SHARED COLOR SCALES PER LEGEND GROUP
# ============================================================================

cat("\nComputing shared color scales...\n")

group_pals <- setNames(
  lapply(legend_group_specs$group_id, function(grp_id) {
    grp_spec    <- legend_group_specs %>% filter(group_id == grp_id)
    member_layers <- raster_specs$layer_name[raster_specs$legend_group == grp_id]
    all_vals    <- unlist(lapply(member_layers, function(ln) values(rasters_list[[ln]], na.rm = TRUE)))
    min_val     <- min(all_vals, na.rm = TRUE)
    max_val     <- max(all_vals, na.rm = TRUE)
    pal         <- colorBin(palette = grp_spec$palette, domain = c(min_val, max_val),
                            bins = 5,
                            pretty = T,
                            na.color = NA)
    list(pal = pal, min = min_val, max = max_val)
  }),
  legend_group_specs$group_id
)

group_pals$ratio$max <- 1
group_pals$carbon$max <- 45
group_pals$flamelength$pal <- colorBin(palette = "Reds", domain = c(0,25),
                                       bins = c(0,2,4,6,8,12,20),
                                       na.color = NA)
group_pals$carbon$pal <- colorBin(palette = "YlOrRd", domain = c(0,40),
                                  bins = 5,
                                  pretty=T,
                                  na.color = NA)

# ============================================================================
# BUILD LEAFLET MAP
# ============================================================================

cat("\nBuilding leaflet map...\n")

m <- leaflet() %>%
  addProviderTiles("Esri.WorldStreetMap", group = "Map") %>%
  addProviderTiles("Esri.WorldImagery", group = "Satellite") %>%
  fitBounds(
    lng1 = bbox[["xmin"]], lat1 = bbox[["ymin"]],
    lng2 = bbox[["xmax"]], lat2 = bbox[["ymax"]]
  )

# Watershed boundary
m <- m %>%
  addPolylines(
    data    = bfws_wgs84,
    color   = "black",
    weight  = 4,
    opacity = 1,
    label   = "Blackfoot Watershed",
    group   = "Watershed Boundary"
  )

# Add each raster layer using its group's shared color scale
for (i in seq_len(nrow(raster_specs))) {
  grp_pal <- group_pals[[raster_specs$legend_group[i]]]
  r_wgs84 <- project(rasters_list[[i]], "EPSG:4326")

  m <- m %>%
    addRasterImage(
      x        = r_wgs84,
      colors   = grp_pal$pal,
      opacity  = 0.9,
      group    = raster_specs$layer_name[i],
      maxBytes = Inf
    )
}

# Hide all raster layers by default; user toggles them on
for (ln in raster_specs$layer_name) {
  m <- m %>% hideGroup(ln)
}

# Show watershed boundary by default
m <- m %>% showGroup("Watershed Boundary")

# Add one shared legend per group, initially hidden via JS
for (i in seq_len(nrow(legend_group_specs))) {
  grp   <- legend_group_specs[i, ]
  pal_i <- group_pals[[grp$group_id]]

  m <- m %>%
    addLegend(
      position  = "bottomleft",
      pal       = pal_i$pal,
      values    = c(pal_i$min, pal_i$max),
      title     = grp$title,
      opacity   = 0.8,
      layerId   = paste0(grp$group_id, "_legend"),
      className = paste0("info legend ", grp$group_id, "-legend")
    )
}

# Layer control (topright by default)
m <- m %>%
  leaflet::addLayersControl(
    baseGroups    = c("OpenStreetMap", "Satellite"),
    overlayGroups = c("Watershed Boundary", raster_specs$layer_name),
    options       = layersControlOptions(collapsed = FALSE)
  )

# Title control (moved above zoom via JS below)
m <- m %>%
  addControl(
    html = shiny::HTML('
      <div class="map-title-control"
           style="background:white; padding:8px 12px; border-radius:4px;
                  box-shadow:0 1px 5px rgba(0,0,0,0.4);">
        <div style="font-size:14px; font-weight:bold; margin-bottom:2px;">
          Blackfoot Watershed
        </div>
        <div style="font-size:11px; color:#555;">
          Wildfire &amp; prescribed fire emissions
        </div>
      </div>'),
    position  = "topleft",
    className = "map-title-wrapper"
  )

# ============================================================================
# JAVASCRIPT: dynamic legend visibility, title position
# ============================================================================

js <- "
function(el, x) {
  var map = this;

  // Map each layer name to its legend group
  var layerGroupMap = {
    'Rx/WF Ratio':                        'ratio',
    'Rx/WF Ratio (severe)':               'ratio',
    'Rx Carbon Released':                  'carbon',
    'Rx Flame Length':                     'flamelength',
    'WF Carbon Released (Mean)':           'carbon',
    'WF Carbon Released (severe)':    'carbon',
    'PreTreatment Conditional FL':         'flamelength'
  };

  // Count of visible layers per group (all layers start hidden)
  var groupCounts = { ratio: 0, carbon: 0, flamelength: 0 };

  // Hide all legends on load
  ['ratio', 'carbon', 'flamelength'].forEach(function(grp) {
    var el = document.querySelector('.' + grp + '-legend');
    if (el) el.style.display = 'none';
  });

  // Show legend when a layer in its group is turned on
  map.on('overlayadd', function(e) {
    var grp = layerGroupMap[e.name];
    if (!grp) return;
    groupCounts[grp]++;
    var legendEl = document.querySelector('.' + grp + '-legend');
    if (legendEl) legendEl.style.display = 'block';

    // Apply current slider opacity to newly rendered images (slight delay for render)
    var slider = document.getElementById('opacity-slider');
    if (slider) {
      setTimeout(function() {
        var opacity = parseFloat(slider.value);
        document.querySelectorAll('.leaflet-overlay-pane img').forEach(function(img) {
          img.style.opacity = opacity;
        });
      }, 150);
    }
  });

  // Hide legend when all layers in its group are turned off
  map.on('overlayremove', function(e) {
    var grp = layerGroupMap[e.name];
    if (!grp) return;
    groupCounts[grp] = Math.max(0, groupCounts[grp] - 1);
    if (groupCounts[grp] === 0) {
      var legendEl = document.querySelector('.' + grp + '-legend');
      if (legendEl) legendEl.style.display = 'none';
    }
  });

  // Move title control above zoom controls in the DOM
  var titleEl = document.querySelector('.map-title-control');
  if (titleEl) {
    var titleWrapper = titleEl.parentElement;
    var zoomControl  = document.querySelector('.leaflet-control-zoom');
    if (zoomControl && titleWrapper.parentElement === zoomControl.parentElement) {
      zoomControl.parentElement.insertBefore(titleWrapper, zoomControl);
    }
  }
}
"

m <- m %>% onRender(js)

# ============================================================================
# SAVE MAP
# ============================================================================

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

cat("Saving map to:", output_file, "\n")

saveWidget(m, file = output_file, selfcontained = FALSE)

cat("Map created successfully!\n")
cat("  File:        file://", normalizePath(output_file), "\n")
cat("  GitHub URL:  https://daniel-perret.github.io/for_collaborators/blackfoot_emissions.html\n")
