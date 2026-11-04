# Tiny synthetic station data set shared by test-weather.R and
# test-station-qc.R. The stations and values are fictitious: they do not
# describe any real station or network.

# Two stations: ST01 with standard sensor heights, ST02 with the wind sensor
# at 10 m and the temperature and humidity sensors at 2 m.
syn_stations <- function() {
  data.frame(
    station_id = c("ST01", "ST02"),
    lon = c(-71.50, -71.20),
    lat = c(-35.40, -35.10),
    elevation = c(150, 420),
    height_wind = c(2, 10),
    height_temp_rh = c(2, 2),
    stringsAsFactors = FALSE
  )
}

# Three hourly records per station (timestamps mark the end of the period),
# all values physically possible and mutually consistent (the solar
# radiation stays below the extraterrestrial radiation of each hour, about
# 725, 965 and 1160 W m-2 at these mid-morning hours).
syn_times <- function(n = 3L) {
  as.POSIXct("2024-01-15 13:00", tz = "UTC") + 3600 * (seq_len(n) - 1L)
}

syn_observations <- function() {
  data.frame(
    station_id = rep(c("ST01", "ST02"), each = 3L),
    timestamp = rep(syn_times(), 2L),
    air_temperature = c(24.1, 25.3, 26.0, 21.8, 22.9, 23.5),
    relative_humidity = c(45, 41, 38, 52, 48, 46),
    dewpoint_temperature = c(11.2, 11.0, 10.6, 11.4, 11.3, 11.2),
    wind_speed = c(2.1, 2.6, 3.0, 3.4, 3.9, 4.1),
    solar_radiation = c(600, 760, 870, 580, 740, 860),
    stringsAsFactors = FALSE
  )
}

syn_provenance <- function(...) {
  utils::modifyList(
    list(timestamp_convention = "end", interval = 3600, crs = "EPSG:4326",
         source = "synthetic test data"),
    list(...)
  )
}

syn_table <- function(stations = syn_stations(),
                      observations = syn_observations(),
                      provenance = syn_provenance(), ...) {
  ef_station_table(stations, observations, provenance, ...)
}

# One station with arbitrary records: `...` are columns of observations.
syn_single <- function(..., timestamp = NULL, stations = NULL,
                       provenance = syn_provenance()) {
  cols <- list(...)
  n <- length(cols[[1L]])
  if (is.null(timestamp)) {
    timestamp <- syn_times(n)
  }
  if (is.null(stations)) {
    stations <- syn_stations()[1L, , drop = FALSE]
  }
  obs <- data.frame(station_id = stations$station_id[1L],
                    timestamp = timestamp, stringsAsFactors = FALSE)
  for (nm in names(cols)) {
    obs[[nm]] <- cols[[nm]]
  }
  ef_station_table(stations, obs, provenance)
}
