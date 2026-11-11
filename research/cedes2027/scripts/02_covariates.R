# Terrain covariates on the study grids.
#
# Inputs (cache, see 01_download_data.R): Copernicus GLO-90 DEM tiles and the
# Natural Earth 1:10m land polygons.
# Outputs (data/processed/):
#   * covariates_region.tif: elevation [m] and distance_to_coast [km] on a
#     1 km grid in UTM 18S covering the station box (regionalization and
#     cross-validation domain);
#   * covariates_scene_utm.tif: the same covariates on a 1 km UTM 18S grid
#     covering the Cauquenes scene plus a 5 km margin (prediction grid for
#     the METRIC experiment);
#   * elevation_scene_modis.tif: mean elevation on the MODIS sinusoidal grid
#     of the example scene (surface pressure and datum correction of METRIC).

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))

dem_files <- list.files(file.path(cache_dir, "dem"), pattern = "DEM\\.tif$",
                        full.names = TRUE)
dem <- terra::vrt(dem_files)
land <- terra::vect(file.path(cache_dir, "ne", "ne_10m_land.shp"))

box <- cfg$station_box
box_ll <- terra::ext(box$lon_min, box$lon_max, box$lat_min, box$lat_max)

make_grid <- function(ext_ll, res) {
  poly <- terra::as.polygons(ext_ll, crs = "EPSG:4326")
  e <- terra::ext(terra::project(poly, study_crs))
  e <- terra::ext(floor(e$xmin / res) * res, ceiling(e$xmax / res) * res,
                  floor(e$ymin / res) * res, ceiling(e$ymax / res) * res)
  terra::rast(e, resolution = res, crs = study_crs)
}

covariates_on <- function(template) {
  # Mean elevation of the 90 m cells in each 1 km cell.
  dem_ll <- terra::crop(dem, terra::project(terra::as.polygons(
    terra::ext(template), crs = study_crs), "EPSG:4326"), snap = "out")
  elev <- terra::project(dem_ll, template, method = "average")
  names(elev) <- "elevation"
  # Land mask from Natural Earth; ocean cells are NA (outside the domain).
  land_p <- terra::project(terra::crop(land, terra::ext(dem_ll) + 1),
                           study_crs)
  is_land <- terra::rasterize(land_p, template, field = 1, touches = FALSE)
  # Distance to the coast: distance of each land cell to the nearest
  # non-land cell (km).
  sea <- terra::ifel(is.na(is_land), 1, NA)
  dist <- terra::distance(sea) / 1000
  dist <- terra::mask(dist, is_land)
  names(dist) <- "distance_to_coast"
  elev <- terra::mask(elev, is_land)
  out <- c(elev, dist)
  terra::units(out) <- c("m", "km")
  out
}

res <- cfg$grid_resolution_m
region <- covariates_on(make_grid(box_ll, res))
terra::writeRaster(region, p("data", "processed", "covariates_region.tif"),
                   overwrite = TRUE)

scene <- terra::unwrap(EarthFlux::cauquenes_modis)
scene_ll <- terra::ext(terra::project(terra::as.polygons(terra::ext(scene),
                                                         crs = terra::crs(scene)),
                                      "EPSG:4326"))
scene_utm <- covariates_on(make_grid(scene_ll + 0.06, res))
terra::writeRaster(scene_utm, p("data", "processed", "covariates_scene_utm.tif"),
                   overwrite = TRUE)

# Elevation on the MODIS grid of the scene (mean of the 90 m cells).
dem_scene <- terra::crop(dem, scene_ll + 0.1, snap = "out")
elev_modis <- terra::project(dem_scene, scene[["lst"]], method = "average")
names(elev_modis) <- "elevation"
terra::units(elev_modis) <- "m"
terra::writeRaster(elev_modis, p("data", "processed", "elevation_scene_modis.tif"),
                   overwrite = TRUE)

summ <- function(r) {
  g <- terra::global(r, c("min", "mean", "max"), na.rm = TRUE)
  data.frame(layer = rownames(g), g, n_cells = unlist(terra::global(!is.na(r), "sum")),
             row.names = NULL)
}
out <- rbind(cbind(grid = "region_utm18s_1km", summ(region)),
             cbind(grid = "scene_utm18s_1km", summ(scene_utm)),
             cbind(grid = "scene_modis_sinusoidal", summ(elev_modis)))
write_csv(out, p("results", "diagnostics", "covariates_summary.csv"))
print(out)
