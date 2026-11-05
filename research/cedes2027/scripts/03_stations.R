# Weather stations: parse, harmonise, quality control.
#
# Sources (cache; see 01_download_data.R and docs/data_sources.md):
#   * NOAA Integrated Surface Database (ISD, global-hourly CSV, 2019):
#     synoptic/METAR reports of the airports of the region (air temperature,
#     dew point, 10 m wind; no solar radiation).
#   * Other networks, when their files exist in the cache (see
#     read_network_extra() below).
#
# Output (data/processed/):
#   * stations_meta.csv: one row per station (id, name, lon, lat,
#     elevation, network, sensor heights);
#   * stations_hourly.csv: hourly records in the units of the EarthFlux
#     contract (air temperature degC, vapour pressure kPa, wind speed at the
#     measurement height m s-1, solar radiation W m-2 when observed);
#   * stations_qc.rds: the earthflux_station_qc object (ef_station_qc()).

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))

box <- cfg$station_box
period <- as.POSIXct(c(cfg$cv_period$start, cfg$cv_period$end), tz = "UTC") +
  c(0, 86400)

## NOAA ISD --------------------------------------------------------------------

isd_value <- function(x, scale, missing) {
  # ISD mandatory fields: "value,quality"; quality codes 2, 3, 6, 7 are
  # suspect or erroneous (ISD format document, section on quality codes).
  parts <- do.call(rbind, strsplit(ifelse(is.na(x) | x == "", "NA,9", x), ","))
  v <- suppressWarnings(as.numeric(parts[, 1]))
  q <- parts[, ncol(parts)]
  v[v == missing | q %in% c("2", "3", "6", "7")] <- NA
  v / scale
}

read_isd <- function(file) {
  d <- utils::read.csv(file, stringsAsFactors = FALSE, colClasses = "character")
  d <- d[d$REPORT_TYPE %in% c("FM-15", "FM-12", "SAO  ", "FM-16"), ]
  time <- as.POSIXct(d$DATE, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  wnd <- do.call(rbind, strsplit(d$WND, ","))
  ws <- suppressWarnings(as.numeric(wnd[, 4]))
  ws[ws == 9999 | wnd[, 5] %in% c("2", "3", "6", "7")] <- NA
  out <- data.frame(
    station_id = paste0("ISD", d$STATION),
    name = d$NAME, lat = as.numeric(d$LATITUDE),
    lon = as.numeric(d$LONGITUDE), elevation = as.numeric(d$ELEVATION),
    time = time,
    air_temperature = isd_value(d$TMP, 10, 9999),
    dewpoint = isd_value(d$DEW, 10, 9999),
    wind_speed = ws / 10,
    report = d$REPORT_TYPE, stringsAsFactors = FALSE
  )
  # Keep the reports on the hour (METAR at hh:00, SYNOP at hh:00); several
  # reports at the same hour are averaged (METAR and SYNOP coincide at
  # synoptic hours, rounding of the METAR aside).
  out <- out[format(out$time, "%M") == "00" & out$time >= period[1] &
               out$time < period[2], ]
  out
}

isd_files <- list.files(file.path(cache_dir, "isd"), pattern = "\\.csv$",
                        full.names = TRUE)
isd <- do.call(rbind, lapply(isd_files, read_isd))
isd <- isd[isd$lat >= box$lat_min & isd$lat <= box$lat_max &
             isd$lon >= box$lon_min & isd$lon <= box$lon_max, ]
agg <- stats::aggregate(
  cbind(air_temperature, dewpoint, wind_speed) ~ station_id + time,
  data = isd, FUN = mean, na.action = stats::na.pass
)
meta_isd <- unique(isd[, c("station_id", "name", "lon", "lat", "elevation")])
meta_isd <- meta_isd[!duplicated(meta_isd$station_id), ]
meta_isd$network <- "NOAA ISD (DMC/DGAC airports)"
meta_isd$height_temp_rh <- 2
meta_isd$height_wind <- 10 # WMO standard height of airport anemometers
obs_isd <- data.frame(
  station_id = agg$station_id, time = agg$time,
  air_temperature = agg$air_temperature,
  vapour_pressure = ef_ea_dewpoint(agg$dewpoint),
  wind_speed = agg$wind_speed,
  solar_radiation = NA_real_,
  stringsAsFactors = FALSE
)

## DMC SACLIM (DMC, INIA and FDF automatic stations) -------------------------------

# Hourly sheet RE1022: values at HH:00 UTC (treated as spot values, like
# the airport reports). Air temperature (degC), dew point (degC), relative
# humidity (%), wind speed (kt, DMC airports only). Vapour pressure from the
# dew point when reported, else from RH and air temperature (FAO-56 Eq. 10,
# ef_es()). Radiation (RE1019) is the hourly MAXIMUM of instantaneous
# readings, not an hourly mean: it is not used as forcing (D-04).
read_dmc <- function(dir) {
  st <- utils::read.csv(file.path(dir, "dmc_stations_box.csv"),
                        stringsAsFactors = FALSE)
  files <- list.files(dir, pattern = "^dmc_RE1022_hourly_2019\\d{2}\\.csv$",
                      full.names = TRUE)
  h <- do.call(rbind, lapply(files, utils::read.csv, stringsAsFactors = FALSE,
                             colClasses = "character"))
  num <- function(x) suppressWarnings(as.numeric(x))
  time <- as.POSIXct(paste(h$date_utc, h$hour_utc), format = "%Y-%m-%d %H:%M",
                     tz = "UTC")
  ta <- num(h$t_air_c); td <- num(h$t_dew_c); rh <- num(h$rh_pct)
  ea <- ifelse(!is.na(td), ef_ea_dewpoint(td),
               ifelse(!is.na(rh) & !is.na(ta) & rh > 0 & rh <= 100,
                      rh / 100 * ef_es(ta), NA_real_))
  ws <- num(h$wind_speed_kt) * 0.514444
  obs <- data.frame(station_id = paste0("DMC", h$station_id), time = time,
                    air_temperature = ta, vapour_pressure = ea,
                    wind_speed = ws, solar_radiation = NA_real_,
                    stringsAsFactors = FALSE)
  obs <- obs[!is.na(obs$time) & (!is.na(obs$air_temperature) |
                                  !is.na(obs$vapour_pressure)), ]
  obs <- obs[!duplicated(obs[, c("station_id", "time")]), ]
  meta <- data.frame(station_id = paste0("DMC", st$id), name = st$name,
                     lon = st$lon, lat = st$lat, elevation = st$elevation_m,
                     network = paste0("DMC SACLIM (", st$owner, ")"),
                     height_temp_rh = 2,
                     height_wind = ifelse(st$owner == "DMC", 10, NA_real_),
                     stringsAsFactors = FALSE)
  meta <- meta[meta$station_id %in% obs$station_id, ]
  list(meta = meta, obs = obs)
}
dmc_dir <- file.path(cache_dir, "dmc")
dmc <- if (file.exists(file.path(dmc_dir, "dmc_stations_box.csv"))) read_dmc(dmc_dir) else NULL
if (!is.null(dmc)) {
  # Airports reported by both sources: keep the DMC record (complete hours).
  d <- terra::distance(cbind(meta_isd$lon, meta_isd$lat),
                       cbind(dmc$meta$lon, dmc$meta$lat), lonlat = TRUE)
  dup <- apply(d, 1, min) < 3000
  meta_isd <- meta_isd[!dup, , drop = FALSE]
  obs_isd <- obs_isd[obs_isd$station_id %in% meta_isd$station_id, , drop = FALSE]
}

## Other networks (optional) ----------------------------------------------------

# A network enters the study only if its harmonised files exist:
#   cache/<network>/meta.csv  (station_id, name, lon, lat, elevation,
#                              network, height_temp_rh, height_wind)
#   cache/<network>/hourly.csv (station_id, time [UTC, end of the hourly
#                              period], air_temperature degC,
#                              vapour_pressure kPa, wind_speed m s-1,
#                              solar_radiation W m-2)
# built by 01_download_data.R from the provider files.
read_network_extra <- function(dir) {
  m <- utils::read.csv(file.path(dir, "meta.csv"), stringsAsFactors = FALSE)
  h <- utils::read.csv(file.path(dir, "hourly.csv"), stringsAsFactors = FALSE)
  h$time <- as.POSIXct(h$time, tz = "UTC")
  list(meta = m, obs = h[, names(obs_isd)])
}
extra_dirs <- list.dirs(cache_dir, recursive = FALSE)
extra_dirs <- extra_dirs[file.exists(file.path(extra_dirs, "hourly.csv")) &
                           basename(extra_dirs) != "dmc"]
extra <- lapply(extra_dirs, read_network_extra)

meta <- do.call(rbind, c(list(meta_isd), if (!is.null(dmc)) list(dmc$meta),
                         lapply(extra, `[[`, "meta")))
obs <- do.call(rbind, c(list(obs_isd), if (!is.null(dmc)) list(dmc$obs),
                        lapply(extra, `[[`, "obs")))
meta <- meta[meta$lat >= box$lat_min & meta$lat <= box$lat_max &
               meta$lon >= box$lon_min & meta$lon <= box$lon_max, ]
obs <- obs[obs$station_id %in% meta$station_id & obs$time >= period[1] &
             obs$time < period[2], ]
obs <- obs[order(obs$station_id, obs$time), ]

## EarthFlux station table and QC ------------------------------------------------

stations <- data.frame(
  station_id = meta$station_id, lon = meta$lon, lat = meta$lat,
  elevation = meta$elevation, height_wind = meta$height_wind,
  height_temp_rh = meta$height_temp_rh, stringsAsFactors = FALSE
)
has_rs <- any(!is.na(obs$solar_radiation))
obs_ef <- obs[, c("station_id", "time", "air_temperature", "vapour_pressure",
                  "wind_speed", if (has_rs) "solar_radiation")]
names(obs_ef)[2] <- "timestamp"
st <- ef_station_table(
  stations, obs_ef,
  provenance = list(timestamp_convention = "instant", interval = 3600,
                    crs = "EPSG:4326",
                    source = paste(unique(meta$network), collapse = "; "))
)
qc <- ef_station_qc(st)
saveRDS(qc, p("data", "processed", "stations_qc.rds"))
write_csv(meta, p("data", "processed", "stations_meta.csv"))
write_csv(transform(obs, time = format(time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
          p("data", "processed", "stations_hourly.csv"))

# Inventory: completeness at the overpass hours of the study period.
hours <- cfg$cv_overpass_utc_hours
at_hours <- obs[as.integer(format(obs$time, "%H", tz = "UTC")) %in% hours, ]
inv <- do.call(rbind, lapply(split(at_hours, at_hours$station_id), function(d) {
  data.frame(station_id = d$station_id[1], n_records = nrow(d),
             ta_valid = sum(!is.na(d$air_temperature)),
             ea_valid = sum(!is.na(d$vapour_pressure)),
             ws_valid = sum(!is.na(d$wind_speed)),
             rs_valid = sum(!is.na(d$solar_radiation)))
}))
inv <- merge(meta, inv, all.x = TRUE)
write_csv(inv, p("results", "tables", "station_inventory.csv"))
print(inv[, c("station_id", "name", "lat", "lon", "elevation", "network",
              "ta_valid", "ea_valid", "ws_valid", "rs_valid")])
