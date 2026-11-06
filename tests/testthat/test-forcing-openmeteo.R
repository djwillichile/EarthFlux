# ERA5 forcing via Open-Meteo (R/forcing-openmeteo.R). All tests are
# offline: the only network call, openmeteo_http_get(), is replaced with
# synthetic JSON responses (fictitious values) built below.

# Fixtures ------------------------------------------------------------------------

# Non-ASCII units are written as placeholders and turned into JSON escapes
# by om_json(), so that the fixtures do not depend on the locale.
om_units <- function() {
  list(time = "unixtime", temperature_2m = "DEG_C",
       dew_point_2m = "DEG_C", wind_speed_10m = "m/s",
       shortwave_radiation = "W_M2", surface_pressure = "hPa")
}

# Synthetic diurnal series for hours `t` (POSIXct UTC) at longitude `lon`.
om_series <- function(t, lon) {
  h <- as.numeric(format(t, "%H", tz = "UTC"))
  noon <- 12 - lon / 15
  sun <- pmax(0, cos((h - 0.5 - noon) * pi / 12))
  list(temperature_2m = round(14 + 12 * sun, 2),
       dew_point_2m = rep(8, length(t)),
       wind_speed_10m = round(2 + 2 * sun, 2),
       shortwave_radiation = round(800 * sun, 1),
       surface_pressure = rep(1000, length(t)))
}

# One location object (a list ready for jsonlite::toJSON()).
om_location <- function(lat, lon, elevation, start, end,
                        units = om_units(), offset = 0, iso = FALSE,
                        edit = NULL) {
  t <- seq(as.POSIXct(paste(start, "00:00"), tz = "UTC"),
           as.POSIXct(paste(end, "23:00"), tz = "UTC"), by = 3600)
  hourly <- c(list(time = if (iso) format(t, "%Y-%m-%dT%H:%M", tz = "UTC")
                   else as.numeric(t)),
              om_series(t, lon))
  if (iso) {
    units$time <- "iso8601"
  }
  if (!is.null(edit)) {
    hourly <- edit(hourly)
  }
  list(latitude = lat, longitude = lon, generationtime_ms = 1.5,
       utc_offset_seconds = offset, timezone = "GMT",
       timezone_abbreviation = "GMT", elevation = elevation,
       hourly_units = units, hourly = hourly)
}

om_json <- function(locations) {
  x <- if (length(locations) == 1L) locations[[1L]] else locations
  json <- as.character(jsonlite::toJSON(x, auto_unbox = TRUE, na = "null",
                                        digits = NA, null = "null"))
  json <- gsub('"DEG_C"', '"\\u00b0C"', json, fixed = TRUE)
  gsub('"W_M2"', '"W/m\\u00b2"', json, fixed = TRUE)
}

om_points <- function(lat = c(-35.25, -35.50), lon = c(-72.00, -72.25)) {
  data.frame(lat = lat, lon = lon, in_aoi = TRUE)
}

om_info <- function(points = om_points(), elevation_adjust = FALSE,
                    apikey_used = FALSE) {
  q <- openmeteo_query(points, as.Date("2019-02-14"), as.Date("2019-02-16"),
                       elevation_adjust)
  openmeteo_request_info(
    endpoint = openmeteo_endpoints()[["free"]], query = q,
    apikey_used = apikey_used, points = points,
    retrieved = as.POSIXct("2026-11-06 10:00", tz = "UTC"),
    urls = openmeteo_url(q)
  )
}

om_response <- function(points = om_points(), edit = NULL, ...) {
  locs <- lapply(seq_len(nrow(points)), function(i) {
    om_location(points$lat[i], points$lon[i], 100 * i, "2019-02-14",
                "2019-02-16", edit = edit)
  })
  openmeteo_response(om_json(locs), om_info(points, ...))
}

# Parse the query of a request URL into a named list.
om_parse_url <- function(url) {
  q <- sub("^[^?]*\\?", "", url)
  kv <- strsplit(strsplit(q, "&", fixed = TRUE)[[1L]], "=", fixed = TRUE)
  stats::setNames(lapply(kv, function(x) utils::URLdecode(x[2L])),
                  vapply(kv, `[`, "", 1L))
}

# A fake server: answers any request URL with a matching synthetic response.
om_server <- function(url) {
  q <- om_parse_url(url)
  lat <- as.numeric(strsplit(q$latitude, ",")[[1L]])
  lon <- as.numeric(strsplit(q$longitude, ",")[[1L]])
  elev <- if (is.null(q$elevation)) 350 else 120
  om_json(lapply(seq_along(lat), function(i) {
    om_location(lat[i], lon[i], elev + i, q$start_date, q$end_date)
  }))
}

# A small AOI in UTM zone 19S (inside one ERA5 cell centred on -35.25,
# -72.00).
om_aoi <- function() {
  ll <- cbind(c(-72.05, -71.95, -71.95, -72.05), c(-35.30, -35.30, -35.20,
                                                   -35.20))
  xy <- terra::project(ll, from = "EPSG:4326", to = "EPSG:32719")
  terra::vect(list(xy), type = "polygons", crs = "EPSG:32719")
}

# Grid points ------------------------------------------------------------------------

test_that("openmeteo_points() returns ERA5 cell centres with a one-cell buffer", {
  p <- openmeteo_points(om_aoi())
  expect_identical(nrow(p), 9L)
  expect_identical(sum(p$in_aoi), 1L)
  expect_equal(p[p$in_aoi, c("lat", "lon")],
               data.frame(lat = -35.25, lon = -72.00), ignore_attr = TRUE)
  expect_true(all(abs(p$lat / 0.25 - round(p$lat / 0.25)) < 1e-12))
  expect_true(all(abs(p$lon / 0.25 - round(p$lon / 0.25)) < 1e-12))
  expect_setequal(unique(p$lat), c(-35.00, -35.25, -35.50))
  expect_setequal(unique(p$lon), c(-72.25, -72.00, -71.75))
  # North to south, west to east.
  expect_identical(p$lat, sort(p$lat, decreasing = TRUE))

  # An AOI across two cells in longitude: 2 cells + 10 neighbours.
  ll <- cbind(c(-72.10, -71.80, -71.80, -72.10), c(-35.30, -35.30, -35.20,
                                                   -35.20))
  aoi <- terra::vect(list(ll), type = "polygons", crs = "EPSG:4326")
  p2 <- openmeteo_points(aoi)
  expect_identical(sum(p2$in_aoi), 2L)
  expect_identical(nrow(p2), 12L)
})

test_that("openmeteo_points() checks its inputs and caps the number of points", {
  expect_error(openmeteo_points(om_aoi(), resolution = 0.1),
               class = "earthflux_input_error")
  expect_error(openmeteo_points(terra::ext(0, 1, 0, 1)),
               class = "earthflux_input_error")
  big <- terra::vect(list(cbind(c(-74, -70, -70, -74), c(-37, -37, -33, -33))),
                     type = "polygons", crs = "EPSG:4326")
  expect_error(openmeteo_points(big),
               class = "earthflux_openmeteo_points_error")
  expect_identical(nrow(openmeteo_points(big, max_points = 400L)), 19L * 19L)
})

# Query and URL -----------------------------------------------------------------------

test_that("openmeteo_query() builds the documented parameters", {
  p <- om_points()
  q <- openmeteo_query(p, as.Date("2019-02-14"), as.Date("2019-02-16"),
                       elevation_adjust = FALSE)
  expect_identical(q$latitude, "-35.25,-35.50")
  expect_identical(q$longitude, "-72.00,-72.25")
  expect_identical(q$elevation, "nan,nan")
  expect_identical(q$start_date, "2019-02-14")
  expect_identical(q$end_date, "2019-02-16")
  expect_identical(q$hourly, paste0("temperature_2m,dew_point_2m,",
                                    "wind_speed_10m,shortwave_radiation,",
                                    "surface_pressure"))
  expect_identical(q$models, "era5")
  expect_identical(q$cell_selection, "nearest")
  expect_identical(q$wind_speed_unit, "ms")
  expect_identical(q$timezone, "GMT")
  expect_identical(q$timeformat, "unixtime")
  expect_false("apikey" %in% names(q))

  q2 <- openmeteo_query(p, as.Date("2019-02-14"), as.Date("2019-02-16"),
                        elevation_adjust = TRUE)
  expect_null(q2$elevation)

  expect_error(openmeteo_query(p, as.Date("2019-02-14"),
                               as.Date("2019-02-16")),
               class = "earthflux_missing_input")
  expect_error(openmeteo_query(p, as.Date("2019-02-14"),
                               as.Date("2019-02-16"), NA),
               class = "earthflux_input_error")
  expect_error(openmeteo_query(p, as.Date("2019-02-16"),
                               as.Date("2019-02-14"), TRUE),
               class = "earthflux_input_error")
  expect_error(openmeteo_query(p, as.Date("1939-12-31"),
                               as.Date("1940-01-02"), TRUE),
               class = "earthflux_input_error")
})

test_that("openmeteo_url() switches to the customer endpoint with a key", {
  q <- openmeteo_query(om_points(), as.Date("2019-02-14"),
                       as.Date("2019-02-16"), FALSE)
  free <- openmeteo_url(q)
  expect_true(startsWith(free, "https://archive-api.open-meteo.com/v1/archive?"))
  expect_false(grepl("apikey", free))
  paid <- openmeteo_url(q, apikey = "s3cr3t-KEY")
  expect_true(startsWith(
    paid, "https://customer-archive-api.open-meteo.com/v1/archive?"
  ))
  expect_true(endsWith(paid, "&apikey=s3cr3t-KEY"))
  shown <- openmeteo_url(q, apikey = "s3cr3t-KEY", redact = TRUE)
  expect_true(startsWith(shown, "https://customer-archive-api"))
  expect_false(grepl("s3cr3t", shown))
})

test_that("openmeteo_status_code() reads the libcurl status message", {
  msg <- paste0("cannot open URL 'https://archive-api.open-meteo.com/v1/",
                "archive?latitude=1': HTTP status was '429 Unknown Error'")
  expect_identical(openmeteo_status_code(msg), 429L)
  expect_identical(openmeteo_status_code("cannot open URL 'x'"), NA_integer_)
})

# Parsing ------------------------------------------------------------------------------

test_that("a single-location response becomes a valid station table", {
  # Hand-written JSON (ISO 8601 times) with a null value.
  json <- paste0(
    '{"latitude":-35.25,"longitude":-72.0,"generationtime_ms":0.5,',
    '"utc_offset_seconds":0,"timezone":"GMT","timezone_abbreviation":"GMT",',
    '"elevation":153.0,',
    '"hourly_units":{"time":"iso8601","temperature_2m":"\\u00b0C",',
    '"dew_point_2m":"\\u00b0C","wind_speed_10m":"m/s",',
    '"shortwave_radiation":"W/m\\u00b2","surface_pressure":"hPa"},',
    '"hourly":{"time":["2019-02-15T14:00","2019-02-15T15:00",',
    '"2019-02-15T16:00"],',
    '"temperature_2m":[20.0,22.0,null],"dew_point_2m":[9.0,9.5,10.0],',
    '"wind_speed_10m":[2.0,3.0,4.0],',
    '"shortwave_radiation":[500.0,700.0,800.0],',
    '"surface_pressure":[995.0,994.0,993.0]}}'
  )
  p <- data.frame(lat = -35.25, lon = -72.00, in_aoi = TRUE)
  resp <- openmeteo_response(json, om_info(p))
  st <- openmeteo_station_table(resp, instant_values = "end_of_period")
  expect_s3_class(st, "earthflux_station_table")
  expect_identical(st$stations$station_id, "era5_-35.25_-72.00")
  expect_equal(st$stations$elevation, 153)
  expect_equal(st$stations$height_wind, 10)
  expect_equal(st$stations$height_temp_rh, 2)
  expect_identical(as.character(st$stations$surface_type), "unknown")
  obs <- st$observations
  # The null is kept as NA; no record is dropped.
  expect_identical(nrow(obs), 3L)
  expect_equal(obs$air_temperature, c(20, 22, NA))
  expect_identical(attr(obs$timestamp, "tzone"), "UTC")
  expect_equal(obs$timestamp,
               as.POSIXct(c("2019-02-15 14:00", "2019-02-15 15:00",
                            "2019-02-15 16:00"), tz = "UTC"))
  # hPa -> kPa (declared conversion, recorded by ef_station_table()).
  expect_equal(obs$air_pressure, c(99.5, 99.4, 99.3))
  u <- st$provenance$units
  expect_identical(u$source_unit[u$variable == "air_pressure"], "hPa")
  expect_equal(obs$wind_speed, c(2, 3, 4))
  expect_equal(obs$solar_radiation, c(500, 700, 800))
  expect_identical(st$provenance$timestamp_convention, "end")
  expect_identical(st$provenance$interval, 3600)
  expect_identical(st$provenance$crs, "EPSG:4326")
  expect_false(st$provenance$elevation_adjust)
  expect_no_error(ef_validate_stations(st))
})

test_that("a multi-location response keeps the order and the elevations", {
  resp <- om_response()
  st <- openmeteo_station_table(resp, instant_values = "end_of_period")
  expect_identical(st$stations$station_id,
                   c("era5_-35.25_-72.00", "era5_-35.50_-72.25"))
  expect_equal(st$stations$elevation, c(100, 200))
  expect_identical(nrow(st$observations), 2L * 72L)
  expect_identical(unique(st$observations$station_id),
                   st$stations$station_id)
  # Unix time and ISO 8601 give the same UTC timestamps.
  loc <- om_location(-35.25, -72, 100, "2019-02-14", "2019-02-16",
                     iso = TRUE)
  expect_equal(openmeteo_times(loc), openmeteo_times(om_location(
    -35.25, -72, 100, "2019-02-14", "2019-02-16"
  )))
})

test_that("instantaneous values: end of period or trapezoid", {
  resp <- om_response()
  a <- openmeteo_station_table(resp, "end_of_period")$observations
  b <- openmeteo_station_table(resp, "trapezoid")$observations
  one <- a$station_id == "era5_-35.25_-72.00"
  t_end <- a$air_temperature[one]
  t_trap <- b$air_temperature[one]
  expect_true(is.na(t_trap[1L]))
  expect_equal(t_trap[-1L], (t_end[-1L] + t_end[-length(t_end)]) / 2)
  # The radiation (mean of the preceding hour) is never changed.
  expect_equal(a$solar_radiation, b$solar_radiation)
  expect_error(openmeteo_station_table(resp),
               class = "earthflux_missing_input")
  expect_error(openmeteo_station_table(resp, "midpoint"),
               class = "earthflux_unknown_method")
})

test_that("malformed or unexpected responses are classed errors", {
  p <- om_points()
  # Unit other than the documented one (km/h instead of m/s).
  units <- om_units()
  units$wind_speed_10m <- "km/h"
  bad_unit <- om_json(list(
    om_location(-35.25, -72, 1, "2019-02-14", "2019-02-16", units = units),
    om_location(-35.5, -72.25, 1, "2019-02-14", "2019-02-16")
  ))
  expect_error(
    openmeteo_station_table(openmeteo_response(bad_unit, om_info(p)),
                            "end_of_period"),
    class = "earthflux_openmeteo_response_error"
  )
  # Not in UTC.
  local <- om_json(list(
    om_location(-35.25, -72, 1, "2019-02-14", "2019-02-16", offset = -10800),
    om_location(-35.5, -72.25, 1, "2019-02-14", "2019-02-16")
  ))
  expect_error(
    openmeteo_station_table(openmeteo_response(local, om_info(p)),
                            "end_of_period"),
    class = "earthflux_openmeteo_response_error"
  )
  # Another grid cell than requested.
  moved <- om_json(list(
    om_location(-35.0, -72, 1, "2019-02-14", "2019-02-16"),
    om_location(-35.5, -72.25, 1, "2019-02-14", "2019-02-16")
  ))
  expect_error(
    openmeteo_station_table(openmeteo_response(moved, om_info(p)),
                            "end_of_period"),
    class = "earthflux_openmeteo_response_error"
  )
  # A variable without any value (e.g. dates within the ERA5 delay).
  no_rad <- function(h) {
    h$shortwave_radiation <- rep(NA, length(h$shortwave_radiation))
    h
  }
  expect_error(
    openmeteo_station_table(om_response(edit = no_rad), "end_of_period"),
    class = "earthflux_openmeteo_response_error"
  )
  # A missing variable.
  no_wind <- function(h) {
    h$wind_speed_10m <- NULL
    h
  }
  expect_error(
    openmeteo_station_table(om_response(edit = no_wind), "end_of_period"),
    class = "earthflux_openmeteo_response_error"
  )
  # Error object of the API, invalid JSON, count mismatch.
  expect_error(
    openmeteo_response('{"error":true,"reason":"Invalid parameter"}', list()),
    "Invalid parameter", class = "earthflux_openmeteo_response_error"
  )
  expect_error(openmeteo_response("<html>", list()),
               class = "earthflux_download_error")
  one <- openmeteo_response(om_json(list(om_location(
    -35.25, -72, 1, "2019-02-14", "2019-02-16"
  ))), om_info(p))
  expect_error(openmeteo_station_table(one, "end_of_period"),
               class = "earthflux_openmeteo_response_error")
})

# Downstream chain ----------------------------------------------------------------------

test_that("the virtual station table goes through QC, reference ET and regionalization", {
  st <- openmeteo_station_table(om_response(), "trapezoid")
  qc <- ef_station_qc(st)
  expect_s3_class(qc, "earthflux_station_qc")
  # The gridded-forcing provenance survives the QC.
  expect_identical(qc$provenance$forcing$type, "gridded")

  et <- ef_station_ref_et(
    qc, reference = "alfalfa", timestep = "hourly", standard = "asce",
    humidity = "dewpoint_temperature", day_definition = "utc",
    day_completeness = "all_periods", daytime_rule = "rn_positive",
    night_cloudiness = "low_sun",
    overpass = as.POSIXct("2019-02-15 14:48", tz = "UTC"),
    inst_method = "O3"
  )
  # Wind at 10 m converted to 2 m (FAO-56 Eq. 47) through `height_wind`.
  expect_equal(et$series$wind_speed_2m,
               ef_wind_2m(st$observations$wind_speed, 10))
  day <- et$etr_24[et$etr_24$date == as.Date("2019-02-15"), ]
  expect_identical(nrow(day), 2L)
  expect_true(all(is.finite(day$etr_24) & day$etr_24 > 0))
  expect_true(all(is.finite(et$etr_inst$etr_inst)))
  expect_identical(et$provenance$station_table$forcing$type, "gridded")

  grid <- terra::rast(nrows = 4, ncols = 4, xmin = 220000, xmax = 260000,
                      ymin = 6060000, ymax = 6100000, crs = "EPSG:32719")
  # Regionalization (C2, IDW) of the hours around the overpass: the input is
  # restricted to the target times needed (the first trapezoid record of
  # every series is NA, so all target times cannot be fitted).
  data <- station_regionalization_input(qc, "air_temperature")
  keep <- data$target_time %in%
    as.POSIXct(c("2019-02-15 14:30", "2019-02-15 15:30"), tz = "UTC")
  s <- ef_regionalize(
    data[keep, ], "air_temperature", covariates = NULL,
    method = ef_method_idw(2), use_qc = c("ok", "warning"),
    surface_covariates = character(0), grid = grid
  )
  expect_s3_class(s, "earthflux_surface")
  expect_equal(terra::nlyr(s$surface), 2)
  expect_true(all(is.finite(terra::values(s$surface))))
})

# Flag ---------------------------------------------------------------------------------

test_that("EF_WS_GRIDDED_FORCING is registered and raised from the provenance", {
  reg <- ef_flag_registry_build()
  row <- reg[reg$code == "EF_WS_GRIDDED_FORCING", ]
  expect_identical(nrow(row), 1L)
  expect_identical(row$stage, "WS")
  expect_identical(row$severity, "warning")
  expect_identical(row$scope, "object")
  expect_true(is.na(row$bit))

  st <- openmeteo_station_table(om_response(), "end_of_period")
  f <- st$provenance$forcing
  expect_identical(f$flags_evaluated, "EF_WS_GRIDDED_FORCING")
  expect_length(f$flags, 1L)
  expect_s3_class(f$flags[[1L]], "earthflux_flag")
  expect_identical(f$flags[[1L]]$code, "EF_WS_GRIDDED_FORCING")
  expect_identical(f$flags[[1L]]$scope, "object")
  expect_identical(f$flags[[1L]]$n_total, 1L)
  # Positive and negative cases (R19: present iff the provenance says so).
  pos <- openmeteo_forcing_flags(st$provenance)
  expect_identical(pos$evaluated, "EF_WS_GRIDDED_FORCING")
  expect_length(pos$flags, 1L)
  neg <- openmeteo_forcing_flags(syn_table()$provenance)
  expect_identical(neg$evaluated, "EF_WS_GRIDDED_FORCING")
  expect_length(neg$flags, 0L)
  # The flags element of the table stays empty before QC.
  expect_length(st$flags, 0L)
})

test_that("the provenance carries licence, attribution and the request", {
  st <- openmeteo_station_table(om_response(), "end_of_period")
  p <- st$provenance
  expect_identical(p$license, "CC BY 4.0")
  expect_identical(p$model, "era5")
  expect_match(p$attribution[["open_meteo"]], "Open-Meteo.com")
  expect_identical(p$attribution[["copernicus"]],
                   "Contains modified Copernicus Climate Change Service information 2026")
  expect_match(p$usage, "non-commercial")
  expect_false(p$apikey_used)
  expect_identical(p$request$models, "era5")
  expect_identical(p$instant_values, "end_of_period")
  expect_true(all(c("station_id", "in_aoi") %in%
                    names(p$forcing$virtual_stations)))
})

# Network wrapper, retries and the API key -------------------------------------------------

test_that("HTTP 429 is retried once, then a classed error", {
  calls <- 0L
  sleeps <- 0L
  local_mocked_bindings(
    openmeteo_http_get = function(url, destfile) {
      calls <<- calls + 1L
      if (calls == 1L) {
        return(429L)
      }
      writeLines(om_server(url), destfile)
      200L
    },
    openmeteo_sleep = function(seconds) sleeps <<- sleeps + 1L
  )
  r <- openmeteo_request(om_points(), as.Date("2019-02-14"),
                         as.Date("2019-02-16"), elevation_adjust = FALSE)
  expect_s3_class(r, "earthflux_openmeteo_response")
  expect_identical(calls, 2L)
  expect_identical(sleeps, 1L)

  calls <- 0L
  local_mocked_bindings(openmeteo_http_get = function(url, destfile) {
    calls <<- calls + 1L
    429L
  })
  err <- expect_error(
    openmeteo_request(om_points(), as.Date("2019-02-14"),
                      as.Date("2019-02-16"), elevation_adjust = FALSE),
    class = "earthflux_download_error"
  )
  expect_identical(calls, 2L)
  expect_identical(err$status, 429L)
  expect_match(conditionMessage(err), "429")
  expect_true(startsWith(err$url, "https://archive-api.open-meteo.com"))
})

test_that("the API key goes only to the customer endpoint and nowhere else", {
  secret <- "s3cr3t-KEY-123"
  seen <- character(0)
  local_mocked_bindings(openmeteo_http_get = function(url, destfile) {
    seen <<- c(seen, url)
    writeLines(om_server(url), destfile)
    200L
  })
  r <- openmeteo_request(om_points(), as.Date("2019-02-14"),
                         as.Date("2019-02-16"), apikey = secret,
                         elevation_adjust = TRUE)
  expect_true(all(startsWith(
    seen, "https://customer-archive-api.open-meteo.com/v1/archive?"
  )))
  expect_true(all(grepl(secret, seen, fixed = TRUE)))
  st <- openmeteo_station_table(r, "end_of_period")
  dump <- paste(utils::capture.output(str(st, max.level = 10)),
                collapse = "\n")
  expect_false(grepl(secret, dump, fixed = TRUE))
  expect_false(grepl(secret, paste(deparse(st$provenance), collapse = ""),
                     fixed = TRUE))
  expect_true(st$provenance$apikey_used)
  expect_match(st$provenance$usage, "commercial")
  expect_true(st$provenance$elevation_adjust)
  expect_true(startsWith(st$provenance$endpoint,
                         "https://customer-archive-api"))
  expect_false(any(grepl(secret, st$provenance$request_urls, fixed = TRUE)))

  # Errors do not show the key.
  local_mocked_bindings(openmeteo_http_get = function(url, destfile) 500L)
  err <- expect_error(
    openmeteo_request(om_points(), as.Date("2019-02-14"),
                      as.Date("2019-02-16"), apikey = secret,
                      elevation_adjust = TRUE),
    class = "earthflux_download_error"
  )
  expect_false(grepl(secret, conditionMessage(err), fixed = TRUE))
  expect_false(grepl(secret, err$url, fixed = TRUE))
  expect_identical(err$status, 500L)
  expect_error(openmeteo_request(om_points(), as.Date("2019-02-14"),
                                 as.Date("2019-02-16"), apikey = "",
                                 elevation_adjust = TRUE),
               class = "earthflux_input_error")
})

test_that("locations are sent in chunks and joined", {
  calls <- 0L
  local_mocked_bindings(openmeteo_http_get = function(url, destfile) {
    calls <<- calls + 1L
    writeLines(om_server(url), destfile)
    200L
  })
  p <- openmeteo_points(om_aoi())
  r <- openmeteo_request(p, as.Date("2019-02-14"), as.Date("2019-02-16"),
                         elevation_adjust = FALSE, chunk_size = 4L)
  expect_identical(calls, 3L)
  expect_length(r$locations, 9L)
  st <- openmeteo_station_table(r, "end_of_period")
  expect_identical(st$stations$station_id,
                   sprintf("era5_%.2f_%.2f", p$lat, p$lon))
  # A one-location chunk (a JSON object, not an array) is joined too.
  calls <- 0L
  r1 <- openmeteo_request(p[1:2, ], as.Date("2019-02-14"),
                          as.Date("2019-02-16"), elevation_adjust = FALSE,
                          chunk_size = 1L)
  expect_identical(calls, 2L)
  expect_length(r1$locations, 2L)
})

# Cache ------------------------------------------------------------------------------------

test_that("openmeteo_fetch() caches the response under a key without the API key", {
  cache <- tempfile("om-cache-")
  dir.create(cache)
  on.exit(unlink(cache, recursive = TRUE), add = TRUE)
  secret <- "s3cr3t-KEY-123"
  calls <- 0L
  local_mocked_bindings(openmeteo_http_get = function(url, destfile) {
    calls <<- calls + 1L
    writeLines(om_server(url), destfile)
    200L
  })
  st <- openmeteo_fetch(om_aoi(), as.Date("2019-02-15"),
                        elevation_adjust = FALSE,
                        instant_values = "trapezoid", cache_dir = cache)
  expect_identical(calls, 1L)
  expect_s3_class(st, "earthflux_station_table")
  expect_identical(nrow(st$stations), 9L)
  rng <- range(st$observations$timestamp)
  expect_equal(rng, as.POSIXct(c("2019-02-13 00:00", "2019-02-16 23:00"),
                               tz = "UTC"))
  files <- list.files(file.path(cache, "openmeteo"))
  expect_length(files, 1L)
  expect_match(files, "^era5_[0-9a-f]{32}\\.json$")
  expect_false(st$provenance$cache$hit)
  expect_identical(st$provenance$cache$path,
                   file.path(cache, "openmeteo", files))

  # Second call: from the cache, also with an API key (same key).
  st2 <- openmeteo_fetch(om_aoi(), as.Date("2019-02-15"),
                         elevation_adjust = FALSE,
                         instant_values = "trapezoid", apikey = secret,
                         cache_dir = cache)
  expect_identical(calls, 1L)
  expect_true(st2$provenance$cache$hit)
  expect_equal(st2$observations, st$observations)
  expect_false(grepl(secret, paste(deparse(st2$provenance), collapse = ""),
                     fixed = TRUE))
  expect_false(any(grepl(secret, list.files(cache, recursive = TRUE),
                         fixed = TRUE)))

  # Another elevation option is another request.
  st3 <- openmeteo_fetch(om_aoi(), as.Date("2019-02-15"),
                         elevation_adjust = TRUE,
                         instant_values = "trapezoid", cache_dir = cache)
  expect_identical(calls, 2L)
  expect_true(st3$provenance$elevation_adjust)
  expect_length(list.files(file.path(cache, "openmeteo")), 2L)

  # A failed download leaves no cache entry and no partial file.
  local_mocked_bindings(openmeteo_http_get = function(url, destfile) 503L)
  expect_error(openmeteo_fetch(om_aoi(), as.Date("2019-03-15"),
                               elevation_adjust = FALSE,
                               instant_values = "trapezoid",
                               cache_dir = cache),
               class = "earthflux_download_error")
  expect_length(list.files(file.path(cache, "openmeteo")), 2L)
  expect_length(list.files(cache, pattern = "\\.part$", recursive = TRUE), 0L)
})

test_that("the cache key ignores the API key and the endpoint", {
  q <- openmeteo_query(om_points(), as.Date("2019-02-14"),
                       as.Date("2019-02-16"), FALSE)
  k <- openmeteo_cache_key(q)
  expect_match(k, "^[0-9a-f]{32}$")
  q2 <- openmeteo_query(om_points(), as.Date("2019-02-14"),
                        as.Date("2019-02-17"), FALSE)
  expect_false(identical(k, openmeteo_cache_key(q2)))
  expect_identical(k, openmeteo_cache_key(q))
})

test_that("openmeteo_fetch() checks its arguments", {
  expect_error(openmeteo_fetch(om_aoi(), "2019-02-15", FALSE, "trapezoid"),
               class = "earthflux_input_error")
  expect_error(openmeteo_fetch(om_aoi(), as.Date("2019-02-15"), FALSE),
               class = "earthflux_missing_input")
  expect_error(openmeteo_fetch(om_aoi(), as.Date("2019-02-15"), FALSE,
                               "trapezoid", days_before = -1),
               class = "earthflux_input_error")
})

# Optional live smoke test -----------------------------------------------------------------

test_that("live request to Open-Meteo (opt-in)", {
  skip_on_cran()
  skip_on_ci()
  skip_if_not(identical(Sys.getenv("EARTHFLUX_LIVE_TESTS"), "true"),
              "set EARTHFLUX_LIVE_TESTS=true to run live tests")
  st <- openmeteo_fetch(om_aoi(), as.Date("2019-02-15"),
                        elevation_adjust = FALSE,
                        instant_values = "end_of_period",
                        cache_dir = tempfile("om-live-"))
  expect_s3_class(st, "earthflux_station_table")
  expect_identical(nrow(st$stations), 9L)
})
