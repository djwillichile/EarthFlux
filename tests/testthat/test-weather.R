# Tests for the standard station table (R/io-weather.R) and the interface
# helpers of the forcing module (R/prep-weather.R)
#
# Specification: dev/specs/weather-forcing.md sections 2.1-2.6 (contract,
# time, provenance, validators and errors) and 7.2 (interface forcing ->
# spatial). Synthetic data: tests/testthat/helper-stations.R.

# Constructor: structure ---------------------------------------------------------

test_that("ef_station_table() builds the documented object", {
  st <- syn_table()
  expect_s3_class(st, "earthflux_station_table")
  expect_identical(class(st), c("earthflux_station_table", "list"))
  expect_named(st, c("stations", "observations", "provenance", "qc",
                     "flags"))
  expect_identical(class(st$stations), "data.frame")
  expect_identical(class(st$observations), "data.frame")
  expect_identical(nrow(st$observations), 6L)
  expect_identical(st$flags, list())
  expect_identical(nrow(st$qc), 0L)
  expect_named(st$qc, c("row", "station_id", "timestamp", "variable",
                        "flag_code", "severity", "test_id", "value",
                        "threshold", "parameters"))
  expect_identical(attr(st$observations$timestamp, "tzone"), "UTC")

  prov <- st$provenance
  expect_identical(prov$timestamp_convention, "end")
  expect_identical(prov$interval, 3600)
  expect_identical(prov$crs, "EPSG:4326")
  expect_identical(prov$source, "synthetic test data")
  expect_identical(prov$source_tz, "UTC")
  expect_identical(prov$duplicates_removed, 0L)
  expect_identical(prov$package_version,
                   as.character(utils::packageVersion("EarthFlux")))
  expect_identical(prov$units$variable,
                   c("air_temperature", "relative_humidity",
                     "dewpoint_temperature", "wind_speed", "solar_radiation"))
  expect_identical(prov$units$source_unit, prov$units$unit)
  expect_identical(prov$operations$step, "ef_station_table")

  # Values are not modified.
  obs <- syn_observations()
  expect_identical(st$observations$air_temperature, obs$air_temperature)
  expect_identical(st$stations, syn_stations())
  expect_invisible(ef_validate_stations(st))
})

test_that("inputs inheriting from data.frame become plain data frames", {
  stations <- syn_stations()
  obs <- syn_observations()
  class(stations) <- c("tbl_df", "tbl", "data.frame")
  class(obs) <- c("tbl_df", "tbl", "data.frame")
  st <- syn_table(stations = stations, observations = obs)
  expect_identical(class(st$stations), "data.frame")
  expect_identical(class(st$observations), "data.frame")
  expect_identical(rownames(st$observations), as.character(1:6))
})

test_that("measured columns are stored as double; all-NA logical is accepted", {
  obs <- syn_observations()
  obs$relative_humidity <- as.integer(obs$relative_humidity)
  obs$air_pressure <- NA
  st <- syn_table(observations = obs)
  expect_type(st$observations$relative_humidity, "double")
  expect_identical(st$observations$relative_humidity,
                   as.double(syn_observations()$relative_humidity))
  expect_identical(st$observations$air_pressure, rep(NA_real_, 6L))
})

test_that("surface_type becomes a factor with the contract levels", {
  stations <- syn_stations()
  stations$surface_type <- c("reference_grass", "non_reference")
  st <- syn_table(stations = stations)
  expect_s3_class(st$stations$surface_type, "factor")
  expect_identical(levels(st$stations$surface_type),
                   c("reference_grass", "reference_alfalfa",
                     "irrigated_other", "non_reference", "unknown"))
  stations$surface_type <- c("grass", "unknown")
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_field_error")
})

# Time (section 2.4) ------------------------------------------------------------

test_that("POSIXct timestamps are stored in UTC with their source zone", {
  obs <- syn_observations()
  local <- obs$timestamp
  attr(local, "tzone") <- "America/Santiago"
  obs$timestamp <- local
  st <- syn_table(observations = obs)
  expect_identical(attr(st$observations$timestamp, "tzone"), "UTC")
  expect_identical(as.numeric(st$observations$timestamp),
                   as.numeric(syn_observations()$timestamp))
  expect_identical(st$provenance$source_tz, "America/Santiago")
})

test_that("character timestamps need an explicit format and time zone", {
  obs <- syn_observations()
  # 10:00 at UTC-3 ("Etc/GMT+3") is 13:00 UTC.
  obs$timestamp <- rep(c("2024-01-15 10:00", "2024-01-15 11:00",
                         "2024-01-15 12:00"), 2L)
  st <- syn_table(observations = obs, timestamp_format = "%Y-%m-%d %H:%M",
                  tz = "Etc/GMT+3")
  expect_identical(as.numeric(st$observations$timestamp),
                   as.numeric(syn_observations()$timestamp))
  expect_identical(st$provenance$source_tz, "Etc/GMT+3")

  expect_error(syn_table(observations = obs),
               class = "earthflux_station_time_error")
  expect_error(syn_table(observations = obs, tz = "UTC"),
               class = "earthflux_station_time_error")
  expect_error(syn_table(observations = obs,
                         timestamp_format = "%Y-%m-%d %H:%M"),
               class = "earthflux_station_time_error")
  expect_error(syn_table(observations = obs, timestamp_format = "%Y-%m-%d %H:%M",
                         tz = ""),
               class = "earthflux_station_time_error")
  expect_error(syn_table(observations = obs, timestamp_format = "%Y-%m-%d %H:%M",
                         tz = "Mars/Olympus"),
               class = "earthflux_station_time_error")
  obs$timestamp[2L] <- "15/01/2024 11:00"
  expect_error(syn_table(observations = obs, timestamp_format = "%Y-%m-%d %H:%M",
                         tz = "UTC"),
               class = "earthflux_station_time_error")
})

test_that("timestamps without an explicit zone or of another type are errors", {
  obs <- syn_observations()
  attr(obs$timestamp, "tzone") <- NULL
  expect_error(syn_table(observations = obs),
               class = "earthflux_station_time_error")
  obs$timestamp <- syn_observations()$timestamp
  attr(obs$timestamp, "tzone") <- ""
  expect_error(syn_table(observations = obs), class = "earthflux_input_error")

  obs <- syn_observations()
  expect_error(syn_table(observations = obs, tz = "UTC"),
               class = "earthflux_station_time_error")
  obs$timestamp <- as.Date(obs$timestamp)
  expect_error(syn_table(observations = obs),
               class = "earthflux_station_time_error")
  obs <- syn_observations()
  obs$timestamp[3L] <- NA
  expect_error(syn_table(observations = obs),
               class = "earthflux_station_time_error")
})

test_that("the period semantics are mandatory provenance fields", {
  expect_error(syn_table(provenance = syn_provenance(timestamp_convention = NULL)),
               class = "earthflux_station_time_error")
  expect_error(syn_table(provenance = syn_provenance(timestamp_convention = "middle")),
               class = "earthflux_station_time_error")
  expect_error(syn_table(provenance = syn_provenance(interval = NULL)),
               class = "earthflux_station_time_error")
  expect_error(syn_table(provenance = syn_provenance(interval = 0)),
               class = "earthflux_station_time_error")
  expect_error(syn_table(provenance = syn_provenance(interval = 1800.5)),
               class = "earthflux_station_time_error")
  expect_error(syn_table(provenance = syn_provenance(interval = "3600")),
               class = "earthflux_station_time_error")
  for (conv in c("end", "start", "instant")) {
    st <- syn_table(provenance = syn_provenance(timestamp_convention = conv))
    expect_identical(st$provenance$timestamp_convention, conv)
  }
})

# Provenance (section 2.5) ------------------------------------------------------

test_that("the CRS must be explicit and WGS84 geographic", {
  expect_error(syn_table(provenance = syn_provenance(crs = NULL)),
               class = "earthflux_station_provenance_error")
  expect_error(syn_table(provenance = syn_provenance(crs = "EPSG:32719")),
               class = "earthflux_station_provenance_error")
  expect_error(syn_table(provenance = syn_provenance(crs = c("EPSG:4326",
                                                           "EPSG:4326"))),
               class = "earthflux_station_provenance_error")
})

test_that("the provenance is a named list without reserved fields", {
  expect_error(syn_table(provenance = "end"),
               class = "earthflux_station_provenance_error")
  expect_error(syn_table(provenance = list("end", 3600, "EPSG:4326")),
               class = "earthflux_station_provenance_error")
  expect_error(syn_table(provenance = syn_provenance(units = "degC")),
               class = "earthflux_station_provenance_error")
  expect_error(syn_table(provenance = syn_provenance(qc = TRUE)),
               class = "earthflux_input_error")
  st <- syn_table(provenance = syn_provenance(license = "CC-BY-4.0",
                                              retrieved = "2026-11-04"))
  expect_identical(st$provenance$license, "CC-BY-4.0")
  expect_identical(st$provenance$retrieved, "2026-11-04")
})

# Fields and types (section 2.6) -------------------------------------------------

test_that("arguments and required fields must be supplied", {
  expect_error(ef_station_table(syn_stations(), syn_observations()),
               class = "earthflux_missing_input")
  for (nm in c("station_id", "lon", "lat", "elevation")) {
    stations <- syn_stations()
    stations[[nm]] <- NULL
    expect_error(syn_table(stations = stations),
                 class = "earthflux_station_field_error")
  }
  for (nm in c("station_id", "timestamp")) {
    obs <- syn_observations()
    obs[[nm]] <- NULL
    expect_error(syn_table(observations = obs),
                 class = "earthflux_station_field_error")
  }
  obs <- syn_observations()[c("station_id", "timestamp")]
  expect_error(syn_table(observations = obs),
               class = "earthflux_station_field_error")
  expect_error(syn_table(stations = syn_stations()[0, ]),
               class = "earthflux_station_field_error")
  expect_error(syn_table(observations = syn_observations()[0, ]),
               class = "earthflux_station_field_error")
  expect_error(syn_table(stations = as.list(syn_stations())),
               class = "earthflux_station_field_error")
})

test_that("columns outside the contract and wrong types are errors", {
  stations <- syn_stations()
  stations$altitude <- 1
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_field_error")
  obs <- syn_observations()
  obs$wind <- 1
  expect_error(syn_table(observations = obs),
               class = "earthflux_station_field_error")

  stations <- syn_stations()
  stations$station_id <- factor(stations$station_id)
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_field_error")
  stations <- syn_stations()
  stations$lat <- as.character(stations$lat)
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_field_error")
  obs <- syn_observations()
  obs$station_id <- factor(obs$station_id)
  expect_error(syn_table(observations = obs),
               class = "earthflux_station_field_error")
  obs <- syn_observations()
  obs$air_temperature <- as.character(obs$air_temperature)
  expect_error(syn_table(observations = obs),
               class = "earthflux_station_field_error")
})

test_that("required metadata values must not be missing", {
  stations <- syn_stations()
  stations$lat[2L] <- NA
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_field_error")
  stations <- syn_stations()
  stations$station_id[1L] <- ""
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_field_error")
  obs <- syn_observations()
  obs$station_id[2L] <- NA
  expect_error(syn_table(observations = obs), class = "earthflux_input_error")
})

test_that("measurement heights are required by the observed variables", {
  stations <- syn_stations()
  stations$height_wind <- NULL
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_field_error")
  stations <- syn_stations()
  stations$height_temp_rh <- NULL
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_field_error")
  # Not required when the variable is absent.
  obs <- syn_observations()[c("station_id", "timestamp", "solar_radiation")]
  stations <- syn_stations()[c("station_id", "lon", "lat", "elevation")]
  expect_s3_class(syn_table(stations = stations, observations = obs),
                  "earthflux_station_table")
  # An unknown height (NA) is allowed; it is flagged by the QC.
  stations <- syn_stations()
  stations$height_wind[1L] <- NA
  expect_s3_class(syn_table(stations = stations), "earthflux_station_table")
})

# Domain of the metadata and of the values ---------------------------------------

test_that("impossible metadata are domain errors", {
  cases <- list(
    list(lon = c(-71.5, 181)), list(lon = c(-180.5, -71.2)),
    list(lat = c(-90.1, -35.1)), list(lat = c(-35.4, 91)),
    list(elevation = c(150, Inf)),
    list(height_wind = c(2, 0)), list(height_wind = c(2, -1)),
    list(height_wind = c(0.09, 10)),
    list(height_temp_rh = c(0, 2))
  )
  for (case in cases) {
    stations <- utils::modifyList(syn_stations(), case)
    expect_error(syn_table(stations = stations),
                 class = "earthflux_domain_error")
  }
  # Bounds: the coordinate limits are valid, and the anemometer bound is
  # the domain of FAO-56 Eq. 47, 67.8 z - 5.42 > 1, i.e. z > 0.0947 m.
  stations <- utils::modifyList(syn_stations(),
                                list(lon = c(-180, 180), lat = c(-90, 90),
                                     height_wind = c(0.0947, 10)))
  expect_s3_class(syn_table(stations = stations), "earthflux_station_table")
  expect_equal(station_min_wind_height(), 6.42 / 67.8)
  expect_true(67.8 * 0.0947 - 5.42 > 1)
  expect_false(67.8 * 0.0946 - 5.42 > 1)
})

test_that("impossible observations are kept; infinite values are errors", {
  obs <- syn_observations()
  obs$relative_humidity[2L] <- -5
  obs$wind_speed[3L] <- -1
  st <- syn_table(observations = obs)
  expect_identical(st$observations$relative_humidity[2L], -5)
  expect_identical(st$observations$wind_speed[3L], -1)
  obs$air_temperature[1L] <- Inf
  expect_error(syn_table(observations = obs), class = "earthflux_domain_error")
})

# Keys ----------------------------------------------------------------------------

test_that("unknown and duplicated station ids are errors", {
  obs <- syn_observations()
  obs$station_id[6L] <- "ST99"
  expect_error(syn_table(observations = obs),
               class = "earthflux_station_unknown_id")
  stations <- syn_stations()
  stations$station_id[2L] <- "ST01"
  expect_error(syn_table(stations = stations),
               class = "earthflux_station_duplicate")
})

test_that("exact duplicates are kept once; conflicting ones are errors", {
  obs <- syn_observations()
  obs_dup <- rbind(obs, obs[c(2L, 5L), ])
  st <- syn_table(observations = obs_dup)
  expect_identical(nrow(st$observations), 6L)
  expect_identical(st$provenance$duplicates_removed, 2L)
  expect_identical(st$observations, syn_table()$observations)

  obs_conflict <- rbind(obs, obs[2L, ])
  obs_conflict$air_temperature[7L] <- 30
  expect_error(syn_table(observations = obs_conflict),
               class = "earthflux_station_duplicate")
})

# Units (section 2.3) -------------------------------------------------------------

test_that("declared unit conversions are applied and recorded", {
  obs <- syn_single(air_temperature = 293.15, relative_humidity = 0.5,
                    wind_speed = 36, solar_radiation = 3.6,
                    air_pressure = 1013, vapour_pressure = 1500)$observations
  st <- ef_station_table(
    syn_stations()[1L, ], obs, syn_provenance(),
    units = list(air_temperature = "K", relative_humidity = "fraction",
                 wind_speed = "km/h", solar_radiation = "MJ/m2/h",
                 air_pressure = "hPa", vapour_pressure = "Pa")
  )
  o <- st$observations
  # 293.15 K = 20 degC; 0.5 = 50 %; 36 km/h = 10 m/s;
  # 3.6 MJ m-2 h-1 = 3.6e6 J / 3600 s = 1000 W m-2 (FAO-56 Table 3);
  # 1013 hPa = 101.3 kPa; 1500 Pa = 1.5 kPa.
  expect_equal(o$air_temperature, 20, tolerance = 1e-12)
  expect_equal(o$relative_humidity, 50, tolerance = 1e-12)
  expect_equal(o$wind_speed, 10, tolerance = 1e-12)
  expect_equal(o$solar_radiation, 1000, tolerance = 1e-12)
  expect_equal(o$air_pressure, 101.3, tolerance = 1e-12)
  expect_equal(o$vapour_pressure, 1.5, tolerance = 1e-12)

  u <- st$provenance$units
  expect_identical(u$source_unit[u$variable == "wind_speed"], "km/h")
  expect_identical(u$unit[u$variable == "wind_speed"], "m/s")
  expect_identical(u$offset[u$variable == "air_temperature"], -273.15)
  expect_match(st$provenance$operations$detail, "wind_speed (km/h -> m/s)",
               fixed = TRUE)

  # 8.64 MJ m-2 d-1 = 100 W m-2 (1 W m-2 = 0.0864 MJ m-2 d-1).
  obs_d <- data.frame(station_id = "ST01", timestamp = syn_times(1L),
                      solar_radiation = 8.64)
  st_d <- ef_station_table(syn_stations()[1L, ], obs_d, syn_provenance(),
                           units = c(solar_radiation = "MJ/m2/d"))
  expect_equal(st_d$observations$solar_radiation, 100, tolerance = 1e-12)
})

test_that("undeclared or unsupported units are errors, never guessed", {
  expect_error(syn_table(units = list(wind_speed = "knots")),
               class = "earthflux_station_field_error")
  expect_error(syn_table(units = list(air_pressure = "hPa")),
               class = "earthflux_station_field_error")
  expect_error(syn_table(units = list("km/h")),
               class = "earthflux_station_field_error")
  expect_error(syn_table(units = list(wind_speed = c("km/h", "m/s"))),
               class = "earthflux_station_field_error")
  expect_error(syn_table(units = 3), class = "earthflux_station_field_error")
  # Declaring the contract unit is a no-op.
  st <- syn_table(units = list(wind_speed = "m/s"))
  expect_identical(st$observations$wind_speed, syn_observations()$wind_speed)
})

# Validator -----------------------------------------------------------------------

test_that("ef_validate_stations() rejects inconsistent objects", {
  st <- syn_table()
  expect_error(ef_validate_stations(list()), class = "earthflux_input_error")
  bad <- st
  bad$observations$station_id[1L] <- "ST99"
  expect_error(ef_validate_stations(bad),
               class = "earthflux_station_unknown_id")
  bad <- st
  bad$observations$timestamp[2L] <- bad$observations$timestamp[1L]
  expect_error(ef_validate_stations(bad),
               class = "earthflux_station_duplicate")
  bad <- st
  attr(bad$observations$timestamp, "tzone") <- "America/Santiago"
  expect_error(ef_validate_stations(bad),
               class = "earthflux_station_time_error")
  bad <- st
  bad$provenance$units <- NULL
  expect_error(ef_validate_stations(bad),
               class = "earthflux_station_provenance_error")
  bad <- st
  bad$qc <- ef_station_qc(syn_table(observations = within(
    syn_observations(), relative_humidity[1] <- 101)))$qc
  expect_error(ef_validate_stations(bad),
               class = "earthflux_station_field_error")
  bad <- st
  bad$stations$lat[1L] <- 95
  expect_error(ef_validate_stations(bad), class = "earthflux_domain_error")
})

test_that("print shows the contents of the table", {
  st <- syn_table()
  expect_output(print(st), "<earthflux_station_table>")
  expect_output(print(st), "Stations: 2")
  expect_output(print(st), "Records: 6")
  expect_output(print(st), "end of each period")
  expect_output(print(st), "not run")
  capture.output(res <- withVisible(print(st)))
  expect_false(res$visible)
  expect_identical(res$value, st)
})

# Interface forcing -> spatial (section 7.2) ---------------------------------------

test_that("station_values() applies the QC exclusions to a copy", {
  obs <- syn_observations()
  obs$relative_humidity[2L] <- -5
  qc <- ef_station_qc(syn_table(observations = obs))
  rh <- station_values(qc, "relative_humidity")
  expect_identical(rh, replace(obs$relative_humidity, 2L, NA_real_))
  expect_identical(qc$observations$relative_humidity[2L], -5)
  expect_identical(station_values(qc, "air_temperature"),
                   obs$air_temperature)
  expect_error(station_values(syn_table(), "air_temperature"),
               class = "earthflux_input_error")
  expect_error(station_values(qc, "air_pressure"),
               class = "earthflux_station_field_error")
})

test_that("station_regionalization_input() follows the contract of 7.2", {
  obs <- syn_observations()
  obs$air_temperature[4L] <- -300
  qc <- ef_station_qc(syn_table(observations = obs))
  ri <- station_regionalization_input(qc, c("air_temperature",
                                            "solar_radiation"))
  expect_named(ri, c("station_id", "lon", "lat", "elevation", "target_time",
                     "period_seconds", "variable", "value", "qc_status",
                     "reference"))
  expect_identical(nrow(ri), 12L)
  expect_identical(levels(ri$variable),
                   c("air_temperature", "vapour_pressure", "wind_speed_2m",
                     "clearness", "solar_radiation", "etr_inst", "etr_24"))
  # End of period: mid-point 30 min before the timestamp.
  expect_identical(as.numeric(ri$target_time[1:6]),
                   as.numeric(obs$timestamp) - 1800)
  expect_identical(attr(ri$target_time, "tzone"), "UTC")
  expect_identical(ri$period_seconds, rep(3600L, 12L))
  expect_identical(ri$value[1:6], obs$air_temperature)
  expect_identical(as.character(ri$qc_status[1:6]),
                   c("ok", "ok", "ok", "excluded", "ok", "ok"))
  expect_identical(ri$elevation[1:6], rep(c(150, 420), each = 3L))
  expect_true(all(is.na(ri$reference)))

  st_start <- syn_table(provenance = syn_provenance(timestamp_convention = "start"))
  ri <- station_regionalization_input(ef_station_qc(st_start),
                                      "air_temperature")
  expect_identical(as.numeric(ri$target_time),
                   as.numeric(syn_observations()$timestamp) + 1800)
  st_inst <- syn_table(provenance = syn_provenance(timestamp_convention = "instant"))
  ri <- station_regionalization_input(ef_station_qc(st_inst),
                                      "air_temperature")
  expect_identical(as.numeric(ri$target_time),
                   as.numeric(syn_observations()$timestamp))
  expect_identical(ri$period_seconds, rep(0L, 6L))

  expect_error(station_regionalization_input(qc, "wind_speed_2m"),
               class = "earthflux_station_field_error")
  expect_error(station_regionalization_input(qc, "vapour_pressure"),
               class = "earthflux_station_field_error")
  expect_error(station_regionalization_input(syn_table(), "air_temperature"),
               class = "earthflux_input_error")
  expect_error(station_regionalization_input(qc, character(0)),
               class = "earthflux_input_error")
})
