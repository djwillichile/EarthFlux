# Offline inputs of earthflux() (tests/testthat/test-earthflux.R).
#
# The surface state is the packaged example scene (cauquenes_modis, real
# MODIS data of 2019-02-15) turned into an earthflux_surface_state; the
# elevation model, the station tables and the Open-Meteo response are
# SYNTHETIC (fictitious values). modis_fetch(), modis_surface_state(),
# dem_fetch() and openmeteo_fetch() are replaced with
# testthat::local_mocked_bindings(), so no test touches the network.

ewf_date <- function() as.Date("2019-02-15")

# Surface state from the packaged scene, optionally cropped to rows and
# columns of the grid.
ewf_state <- function(rows = NULL, cols = NULL) {
  r <- terra::unwrap(cauquenes_modis)
  if (!is.null(rows) || !is.null(cols)) {
    rows <- if (is.null(rows)) seq_len(terra::nrow(r)) else rows
    cols <- if (is.null(cols)) seq_len(terra::ncol(r)) else cols
    e <- terra::ext(r, cells = terra::cellFromRowColCombine(r, rows, cols))
    r <- terra::crop(r, e)
  }
  template <- terra::rast(r, nlyrs = 1L)
  one <- function(nm) {
    x <- r[[nm]]
    names(x) <- nm
    x
  }
  doy <- terra::values(r[["doy"]], mat = FALSE)
  hour <- terra::values(r[["utc_hour"]], mat = FALSE)
  time <- as.POSIXct("2019-01-01", tz = "UTC") + (doy - 1) * 86400 +
    hour * 3600
  reg <- ef_flag_registry()
  bits <- reg[reg$stage %in% c("INPUT", "SURF") & !is.na(reg$bit),
              c("bit", "code", "severity", "description")]
  bits <- bits[order(bits$bit), ]
  rownames(bits) <- NULL
  words <- r[[grep("^flags_", names(r))]]
  options <- unclass(workflow_surface_options(ef_preset("idaho2002_elev"),
                                             "MOD11A1"))
  new_ef_object(
    list(
      lst = one("lst"), albedo = one("albedo"), ndvi = one("ndvi"),
      lai = one("lai"), emissivity = one("emissivity"),
      band_emissivity = r[[c("emis_31", "emis_32")]],
      view_angle = if ("view_angle" %in% names(r)) one("view_angle"),
      overpass_time = list(doy = one("doy"), utc_hour = one("utc_hour"),
                           time = time),
      lonlat = modis_cell_lonlat(template),
      qa = list(flag_word = words, flag_bits = bits,
                valid_fraction = r[[c("valid_fraction_albedo",
                                      "valid_fraction_lai")]],
                composite = list(), policy = list(qa_policy = "flag")),
      units = c(lst = "K", albedo = "1", ndvi = "1", lai = "m2 m-2",
                emissivity = "1"),
      flags = list(),
      provenance = list(
        granules = data.frame(role = "lst", product = "MOD11A1",
                              date = "2019-02-15",
                              doi = "10.5067/MODIS/MOD11A1.061",
                              stringsAsFactors = FALSE),
        methods = options,
        flags_evaluated = bits$code
      )
    ),
    "earthflux_surface_state"
  )
}

# Synthetic elevation model on the working grid: a plane rising to the east
# (`slope_m_per_cell` metres per column), or flat.
ewf_terrain <- function(grid, base = 150, slope_m_per_cell = 4) {
  col <- terra::colFromCell(grid, seq_len(terra::ncell(grid)))
  z <- base + slope_m_per_cell * (col - 1)
  out <- terra::rast(grid, nlyrs = 5L)
  names(out) <- c("elevation", "slope", "aspect", "normal_length",
                  "valid_fraction")
  n <- terra::ncell(grid)
  terra::values(out) <- cbind(z, 0, 0, 1, 1)
  new_ef_object(
    list(terrain = out,
         units = c(elevation = "m", slope = "rad", aspect = "rad",
                   normal_length = "-", valid_fraction = "-"),
         flags = list(),
         provenance = list(method = "flat", source = "synthetic test DEM",
                           doi = "10.5067/MEaSUREs/NASADEM/NASADEM_HGT.001")),
    "earthflux_terrain"
  )
}

# The same synthetic plane with a "mountain" block (the columns from
# `from_col` on at `height` metres) and, optionally, a "valley" block (the
# columns up to `valley_to_col` at `valley` metres), fictitious, for the
# terrain rule of the presets (M5-25). The anchors of the packaged scene lie
# in columns 52 to 86, so with the default `from_col` and `valley_to_col`
# the blocks hold no anchor and the anchors keep the elevations of the
# plane.
ewf_terrain_mountain <- function(grid, from_col = 90L, height = 1200,
                                 valley_to_col = 0L, valley = 0) {
  ter <- ewf_terrain(grid)
  z <- terra::values(ter$terrain[["elevation"]], mat = FALSE)
  col <- terra::colFromCell(grid, seq_len(terra::ncell(grid)))
  z[col >= from_col] <- height
  z[col <= valley_to_col] <- valley
  terra::values(ter$terrain[["elevation"]]) <- z
  ter
}

# Synthetic diurnal weather (fictitious) for hours `t` at longitude `lon`.
ewf_weather <- function(t, lon, k = 0) {
  h <- as.numeric(format(t, "%H", tz = "UTC"))
  noon <- 12 - lon / 15
  sun <- pmax(0, cos((h - 0.5 - noon) * pi / 12))
  list(air_temperature = 14 + 13 * sun + 0.3 * k,
       dewpoint_temperature = rep(8 + 0.2 * k, length(t)),
       wind_speed = 1.5 + 2 * sun + 0.1 * k,
       solar_radiation = 830 * sun)
}

# Hourly station table (UTC, end of period) from 2019-02-13 01:00 to
# 2019-02-17 00:00 for stations at lon, lat, elevation.
ewf_stations <- function(lon = -72.25, lat = -35.95, elevation = 150) {
  ids <- sprintf("ST%02d", seq_along(lon))
  stations <- data.frame(station_id = ids, lon = lon, lat = lat,
                         elevation = elevation, height_wind = 2,
                         height_temp_rh = 2, stringsAsFactors = FALSE)
  t <- as.POSIXct("2019-02-13 01:00", tz = "UTC") + 3600 * (0:95)
  obs <- do.call(rbind, lapply(seq_along(ids), function(i) {
    w <- ewf_weather(t, lon[i], k = i - 1)
    data.frame(station_id = ids[i], timestamp = t, w,
               stringsAsFactors = FALSE)
  }))
  ef_station_table(stations, obs,
                   provenance = list(timestamp_convention = "end",
                                     interval = 3600, crs = "EPSG:4326",
                                     source = "synthetic test stations"))
}

# Synthetic Open-Meteo response for the ERA5 points of `aoi` (one virtual
# station per cell; cells with lon < -72.6 reported at sea level), and the
# station table built from it by the module.
ewf_era5 <- function(aoi, date = ewf_date(), instant_values = "trapezoid",
                     sea_lon = -72.6) {
  points <- openmeteo_points(aoi)
  start <- date - 2
  end <- date + 1
  t <- seq(as.POSIXct(paste(start, "00:00"), tz = "UTC"),
           as.POSIXct(paste(end, "23:00"), tz = "UTC"), by = 3600)
  locs <- lapply(seq_len(nrow(points)), function(i) {
    w <- ewf_weather(t, points$lon[i], k = i %% 3)
    list(latitude = points$lat[i], longitude = points$lon[i],
         generationtime_ms = 1, utc_offset_seconds = 0, timezone = "GMT",
         timezone_abbreviation = "GMT",
         elevation = if (points$lon[i] < sea_lon) 0 else 100 + 10 * i,
         hourly_units = list(time = "unixtime", temperature_2m = "DEG_C",
                             dew_point_2m = "DEG_C", wind_speed_10m = "m/s",
                             shortwave_radiation = "W_M2",
                             surface_pressure = "hPa"),
         hourly = list(time = as.numeric(t),
                       temperature_2m = round(w$air_temperature, 2),
                       dew_point_2m = round(w$dewpoint_temperature, 2),
                       wind_speed_10m = round(w$wind_speed * 1.3, 2),
                       shortwave_radiation = round(w$solar_radiation, 1),
                       surface_pressure = rep(1005, length(t))))
  })
  json <- as.character(jsonlite::toJSON(locs, auto_unbox = TRUE,
                                        na = "null", digits = NA))
  json <- gsub('"DEG_C"', '"\\u00b0C"', json, fixed = TRUE)
  json <- gsub('"W_M2"', '"W/m\\u00b2"', json, fixed = TRUE)
  q <- openmeteo_query(points, start, end, elevation_adjust = FALSE)
  info <- openmeteo_request_info(
    endpoint = openmeteo_endpoints()[["free"]], query = q,
    apikey_used = FALSE, points = points,
    retrieved = as.POSIXct("2026-11-06 10:00", tz = "UTC"),
    urls = openmeteo_url(q)
  )
  openmeteo_station_table(openmeteo_response(json, info), instant_values)
}

# AOI: a box (lon/lat) inside the scene, as a polygon in EPSG:4326.
ewf_aoi <- function(xmin = -72.75, xmax = -72.05, ymin = -36.2,
                    ymax = -35.7) {
  terra::vect(terra::ext(xmin, xmax, ymin, ymax), crs = "EPSG:4326")
}
