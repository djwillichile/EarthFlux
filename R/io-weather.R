# I/O: standard station table --------------------------------------------------
#
# Purpose: the standard table of weather station data of the `forcing` module
# (dev/specs/weather-forcing.md section 2): station metadata and observations
# in two plain data frames joined by `station_id`, with the provenance of the
# data. It is the input of the station quality control (R/prep-qc.R), of the
# reference ET at the stations and of the spatial regionalization
# (R/prep-weather.R, dev/specs/weather-forcing.md section 7.2;
# dev/specs/gwr-forcing.md section 2.1).
#
# Contents:
#   ef_station_table()      exported constructor (normalises, validates)
#   ef_validate_stations()  internal validator of an earthflux_station_table
#                           (also of the QC result, earthflux_station_qc)
#   print method of earthflux_station_table
#   contract tables (fields, variables, units) and their checks
#
# Conventions (provisional decisions P0-4 and WF-02 to WF-04):
#   - plain data frames (no tibble or data.table dependency);
#   - timestamps are POSIXct stored in UTC; character timestamps need an
#     explicit format and IANA time zone; the period semantics
#     (`timestamp_convention`, `interval`) are mandatory provenance fields;
#   - air temperature in degrees Celsius (forcing boundary, P0-4); other
#     units as in the contract tables below; declared conversions only, never
#     guessed, and recorded in the provenance;
#   - coordinates in decimal degrees, WGS84, with the explicit CRS string
#     "EPSG:4326" in the provenance;
#   - impossible metadata (stations) are classed errors; impossible
#     observations are kept and flagged by ef_station_qc() with a critical
#     flag (decision WF-04; dev/specs/flags.md class III).
#
# Condition classes raised here (all inherit `earthflux_input_error`, and
# therefore `earthflux_error`; dev/specs/weather-forcing.md section 2.6):
#   earthflux_station_field_error       missing, unknown or mistyped field,
#                                       missing value in a required field
#   earthflux_station_time_error        timestamp without explicit time zone,
#                                       unparsable timestamp, missing or
#                                       invalid period semantics
#   earthflux_station_unknown_id        observation of a station that is not
#                                       in `stations`
#   earthflux_station_duplicate         duplicated station id, or duplicated
#                                       (station_id, timestamp) records with
#                                       different values
#   earthflux_station_provenance_error  malformed provenance (CRS, reserved
#                                       fields)
#   earthflux_domain_error              impossible metadata (coordinates,
#                                       elevation, heights) or infinite values

# Contract tables --------------------------------------------------------------

#' Fields of the `stations` table
#'
#' dev/specs/weather-forcing.md section 2.2.
#'
#' @return A data frame with columns `field`, `type` (`"character"`,
#'   `"numeric"` or `"factor"`), `required` and `unit`.
#' @noRd
station_fields <- function() {
  data.frame(
    field = c("station_id", "lon", "lat", "elevation", "height_wind",
              "height_temp_rh", "surface_type", "network", "provider",
              "license", "terms_url", "name", "notes"),
    type = c("character", "numeric", "numeric", "numeric", "numeric",
             "numeric", "factor", rep("character", 6L)),
    required = c(TRUE, TRUE, TRUE, TRUE, rep(FALSE, 9L)),
    unit = c("", "degree (WGS84, east positive)",
             "degree (WGS84, north positive)", "m above sea level",
             "m above ground", "m above ground", rep("", 7L)),
    stringsAsFactors = FALSE
  )
}

#' Categories of the surrounding surface of a station
#'
#' dev/specs/weather-forcing.md section 2.2 (FAO-56 Annex 6; QC-08).
#'
#' @return A character vector.
#' @noRd
station_surface_types <- function() {
  c("reference_grass", "reference_alfalfa", "irrigated_other",
    "non_reference", "unknown")
}

#' Measured variables of the `observations` table
#'
#' dev/specs/weather-forcing.md section 2.3. `height` names the measurement
#' height field of `stations` that applies to the variable (`NA` if none);
#' `quantity` selects the unit conversions that may be declared.
#'
#' @return A data frame with columns `variable`, `unit`, `quantity` and
#'   `height`.
#' @noRd
station_variables <- function() {
  data.frame(
    variable = c("air_temperature", "relative_humidity",
                 "dewpoint_temperature", "vapour_pressure", "wind_speed",
                 "solar_radiation", "air_pressure", "precipitation",
                 "net_radiation", "tmax", "tmin", "rh_max", "rh_min"),
    unit = c("degC", "%", "degC", "kPa", "m/s", "W/m2", "kPa", "mm", "W/m2",
             "degC", "degC", "%", "%"),
    quantity = c("temperature", "humidity", "temperature", "pressure",
                 "wind", "radiation", "pressure", "precipitation",
                 "radiation", "temperature", "temperature", "humidity",
                 "humidity"),
    height = c("height_temp_rh", "height_temp_rh", "height_temp_rh",
               "height_temp_rh", "height_wind", NA, NA, NA, NA,
               "height_temp_rh", "height_temp_rh", "height_temp_rh",
               "height_temp_rh"),
    stringsAsFactors = FALSE
  )
}

#' Unit conversions that may be declared for the observations
#'
#' Each row converts a declared source unit to the contract unit of its
#' quantity as `value * scale + offset`. All factors are exact by definition
#' of the units, except the energy factors, which are those of FAO-56
#' chapter 3, Table 3 (1 W m-2 = 0.0864 MJ m-2 d-1 = 0.0036 MJ m-2 h-1),
#' themselves exact (dev/specs/weather-forcing.md section 2.3). Radiation in
#' energy per period (e.g. MJ m-2 accumulated over the record) is not a rate
#' and is not accepted: declare the rate.
#'
#' @return A data frame with columns `quantity`, `from`, `to`, `scale` and
#'   `offset`.
#' @noRd
station_unit_conversions <- function() {
  seconds_per_day <- 24 * EF_SECONDS_PER_HOUR
  joules_per_megajoule <- 1e6
  metres_per_kilometre <- 1000
  data.frame(
    quantity = c("temperature", "temperature", "humidity", "humidity",
                 "pressure", "pressure", "pressure", "wind", "wind",
                 "radiation", "radiation", "radiation", "precipitation"),
    from = c("degC", "K", "%", "fraction", "kPa", "hPa", "Pa", "m/s",
             "km/h", "W/m2", "MJ/m2/h", "MJ/m2/d", "mm"),
    to = c("degC", "degC", "%", "%", "kPa", "kPa", "kPa", "m/s", "m/s",
           "W/m2", "W/m2", "W/m2", "mm"),
    scale = c(1, 1, 1, 100, 1, 0.1, 1e-3, 1,
              metres_per_kilometre / EF_SECONDS_PER_HOUR,
              1, joules_per_megajoule / EF_SECONDS_PER_HOUR,
              joules_per_megajoule / seconds_per_day, 1),
    offset = c(0, -EF_KELVIN_OFFSET, rep(0, 11L)),
    stringsAsFactors = FALSE
  )
}

#' Lower bound of the anemometer height
#'
#' Domain of FAO-56 Eq. 47 (wind speed at 2 m), u2 = uz * 4.87 /
#' ln(67.8 z - 5.42), which needs 67.8 z - 5.42 > 1, i.e. z > 0.0947 m
#' (dev/specs/weather-forcing.md sections 2.2 and 4.5; VERIFICADA). The bound
#' is the one of [ef_wind_2m()] (`ef_wind_2m_min_height()`,
#' `R/forcing-derived.R`), the single source of the coefficients of Eq. 47.
#'
#' @return A numeric scalar \[m\].
#' @noRd
station_min_wind_height <- function() {
  ef_wind_2m_min_height()
}

#' Period semantics of the timestamps
#'
#' dev/specs/weather-forcing.md section 2.4.
#'
#' @return A character vector.
#' @noRd
station_timestamp_conventions <- function() {
  c("end", "start", "instant")
}

#' Provenance fields set by the package
#'
#' @return A character vector of names that the user may not supply.
#' @noRd
station_reserved_provenance <- function() {
  c("source_tz", "units", "duplicates_removed", "package_version",
    "operations", "qc", "flags", "flags_evaluated")
}

#' Measured variables present in an observations table
#'
#' @param observations A data frame.
#' @return Character vector of the contract variables among its columns, in
#'   contract order.
#' @noRd
station_measured_vars <- function(observations) {
  vars <- station_variables()$variable
  vars[vars %in% names(observations)]
}

# Conditions -------------------------------------------------------------------

#' Signal a classed error of the station table
#'
#' @param message Character. Error message.
#' @param subclass Character. Specific class (e.g.
#'   `"earthflux_station_field_error"`), or `NULL`.
#' @param call The call to report.
#' @param domain Logical. Whether the error is a domain error.
#' @return Never returns.
#' @noRd
station_abort <- function(message, subclass = NULL, call = NULL,
                          domain = FALSE) {
  class <- c(subclass, if (domain) "earthflux_domain_error",
             "earthflux_input_error")
  ef_abort(message, class = class, call = call)
}

#' Format a few elements for an error message
#'
#' @param x Vector.
#' @param max Integer. Maximum number of elements shown.
#' @return A single string.
#' @noRd
station_show <- function(x, max = 5L) {
  x <- unique(as.character(x))
  more <- if (length(x) > max) sprintf(" (and %d more)", length(x) - max) else ""
  paste0(paste0("'", utils::head(x, max), "'", collapse = ", "), more)
}

# Constructor ------------------------------------------------------------------

#' Standard table of weather station data
#'
#' @description
#' Builds the standard station table of EarthFlux: the metadata of the
#' weather stations (`stations`, one row per station) and their
#' observations (`observations`, one row per station and timestamp), joined
#' by `station_id`, together with the provenance of the data. The
#' constructor normalises the inputs (plain data frames, timestamps in UTC,
#' declared unit conversions), removes exact duplicated records and
#' validates the contract. It never guesses units or time zones and never
#' corrects values: impossible metadata are errors, while impossible or
#' suspicious observations are kept and flagged by [ef_station_qc()].
#'
#' @param stations A data frame with one row per station. Required columns:
#'   `station_id` (character, unique, not missing), `lon` and `lat`
#'   (decimal degrees, WGS84; longitude in \[-180, 180\], east positive;
#'   latitude in \[-90, 90\], north positive) and `elevation` (finite, m
#'   above sea level). Conditionally required: `height_wind` (anemometer
#'   height \[m above ground\], `> 0.0947` m, the domain of FAO-56 Eq. 47)
#'   when `observations` has `wind_speed`, and `height_temp_rh` (height of
#'   the temperature and humidity sensors \[m above ground\], `> 0`) when
#'   `observations` has any temperature or humidity variable. Heights may be
#'   `NA` (unknown); such records are flagged by [ef_station_qc()].
#'   Optional columns: `surface_type` (one of `"reference_grass"`,
#'   `"reference_alfalfa"`, `"irrigated_other"`, `"non_reference"`,
#'   `"unknown"`; stored as a factor), and the character columns `network`,
#'   `provider`, `license`, `terms_url`, `name` and `notes`. Other columns
#'   are rejected.
#' @param observations A data frame with one row per station and timestamp.
#'   Required columns: `station_id` (character, present in `stations`) and
#'   `timestamp` (`POSIXct` with an explicit time zone, or character with
#'   `timestamp_format` and `tz`), plus at least one measured variable.
#'   Measured variables (numeric; contract units): `air_temperature`
#'   \[degC\], `relative_humidity` \[%\], `dewpoint_temperature` \[degC\],
#'   `vapour_pressure` \[kPa\], `wind_speed` \[m s-1\] (at `height_wind`),
#'   `solar_radiation` \[W m-2\] (global irradiance on a horizontal plane,
#'   mean of the period), `air_pressure` \[kPa\], `precipitation` \[mm\],
#'   `net_radiation` \[W m-2\], and for daily data `tmax`, `tmin` \[degC\],
#'   `rh_max`, `rh_min` \[%\]. Missing values are allowed. Other columns are
#'   rejected.
#' @param provenance A named list describing the data. Required fields:
#'   `timestamp_convention` (`"end"`, `"start"` or `"instant"`: whether the
#'   timestamp marks the end or the start of the averaging period, or an
#'   instantaneous value), `interval` (time step of the records in seconds,
#'   a positive whole number, e.g. `3600`) and `crs` (the coordinate
#'   reference system of `lon`/`lat`; must be `"EPSG:4326"`). Recommended
#'   fields: `source` (file, URL or API), `retrieved` (date of download or
#'   reading), `source_hash`, `network`, `provider`, `license`. Any other
#'   named field is kept; the fields `source_tz`, `units`,
#'   `duplicates_removed`, `package_version`, `operations`, `qc`, `flags`
#'   and `flags_evaluated` are reserved (set by the package).
#' @param units `NULL` (all variables already in contract units) or a named
#'   list (or named character vector) declaring the source unit of some
#'   measured variables, which are then converted to the contract unit and
#'   recorded in the provenance. Accepted declarations: temperatures
#'   `"degC"` or `"K"`; humidities `"%"` or `"fraction"`; pressures `"kPa"`,
#'   `"hPa"` or `"Pa"`; `wind_speed` `"m/s"` or `"km/h"`; radiation
#'   `"W/m2"`, `"MJ/m2/h"` or `"MJ/m2/d"` (rates); `precipitation` `"mm"`.
#' @param timestamp_format,tz Only for character timestamps, and then both
#'   required (no default): the format passed to [as.POSIXct()] (e.g.
#'   `"%Y-%m-%d %H:%M"`) and the IANA time zone of the strings (e.g.
#'   `"UTC"`, `"Etc/GMT+4"`, `"America/Santiago"`; see [OlsonNames()]).
#'
#' @return An object of class `c("earthflux_station_table", "list")` with
#'   elements:
#'   * `stations`: data frame of the stations, with the columns supplied
#'     (`surface_type` as a factor with the five levels above);
#'   * `observations`: data frame of the records, in the order supplied
#'     (exact duplicates removed), `timestamp` as `POSIXct` in UTC and the
#'     measured variables as double in contract units;
#'   * `provenance`: the list supplied plus `source_tz` (time zone of the
#'     input timestamps), `units` (data frame `variable`, `source_unit`,
#'     `unit`, `scale`, `offset`), `duplicates_removed` (number of exact
#'     duplicated records removed), `package_version` and `operations` (a
#'     data frame log with columns `step` and `detail`);
#'   * `qc`: the long audit table of quality control flags, with zero rows
#'     until [ef_station_qc()] is run (columns described there);
#'   * `flags`: an empty list of diagnostic flag records.
#'
#' @details
#' **Time** (dev/specs/weather-forcing.md section 2.4). Timestamps are
#' stored as `POSIXct` in UTC. A `POSIXct` input must carry an explicit time
#' zone (a non-empty `tzone` attribute); character input is parsed with the
#' declared `timestamp_format` and `tz`, and any string that does not parse
#' (including local times that do not exist because of a daylight saving
#' change) is an error. Local times that occur twice at the end of daylight
#' saving time are resolved by [as.POSIXct()]; to avoid the ambiguity give
#' UTC or a fixed-offset zone such as `"Etc/GMT+4"`. For averages over a
#' period the mid-point is `timestamp - interval / 2` (`"end"`) or
#' `timestamp + interval / 2` (`"start"`); FAO-56 Eq. 31 uses the time at
#' the mid-point of the period.
#'
#' **Duplicates.** Records with the same `station_id` and `timestamp` and
#' identical values are kept once and counted in
#' `provenance$duplicates_removed`; duplicates with different values are an
#' error (they are never averaged).
#'
#' **Domain.** Impossible metadata are errors of class
#' `earthflux_domain_error`: coordinates out of range, non-finite
#' elevation, heights at or below their bound. Infinite observed values are
#' also errors. Physically impossible observations (e.g. a negative
#' relative humidity) are not errors here: they are kept and flagged with
#' severity `critical` by [ef_station_qc()] (decision WF-04), so that one
#' record does not stop a long series.
#'
#' **Errors.** All errors inherit `earthflux_input_error`. Specific classes:
#' `earthflux_station_field_error` (missing, unknown or mistyped field, zero
#' rows, missing value in a required field), `earthflux_station_time_error`
#' (timestamp without explicit time zone, unparsable timestamp, invalid
#' `timestamp_convention` or `interval`), `earthflux_station_unknown_id`
#' (observations of a station not in `stations`),
#' `earthflux_station_duplicate` (duplicated `station_id` in `stations`,
#' or duplicated records with different values),
#' `earthflux_station_provenance_error` (provenance not a named list,
#' missing or unsupported `crs`, reserved fields) and
#' `earthflux_domain_error`.
#'
#' Not covered yet: readers for the files or services of specific networks
#' (their access, licences, time zones and sensor heights are open items,
#' dev/specs/weather-forcing.md section 9) and the vertical datum of the
#' elevation.
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration - Guidelines for computing crop water requirements*.
#' FAO Irrigation and Drainage Paper 56. FAO, Rome. ISBN 92-5-104219-5.
#'
#' @seealso [ef_station_qc()] for the quality control of the table.
#'
#' @examples
#' # A tiny synthetic data set (fictitious stations).
#' stations <- data.frame(
#'   station_id = c("ST01", "ST02"),
#'   lon = c(-71.50, -71.20), lat = c(-35.40, -35.10),
#'   elevation = c(150, 420),
#'   height_wind = c(2, 10), height_temp_rh = c(2, 2)
#' )
#' times <- as.POSIXct("2024-01-15 13:00", tz = "UTC") + 3600 * 0:2
#' observations <- data.frame(
#'   station_id = rep(c("ST01", "ST02"), each = 3),
#'   timestamp = rep(times, 2),
#'   air_temperature = c(24.1, 25.3, 26.0, 21.8, 22.9, 23.5),
#'   relative_humidity = c(45, 41, 38, 52, 48, 46),
#'   wind_speed = c(2.1, 2.6, 3.0, 3.4, 3.9, 4.1)
#' )
#' st <- ef_station_table(
#'   stations, observations,
#'   provenance = list(timestamp_convention = "end", interval = 3600,
#'                     crs = "EPSG:4326", source = "synthetic example")
#' )
#' st
#'
#' # Declared conversion: wind speed recorded in km/h.
#' obs_kmh <- observations
#' obs_kmh$wind_speed <- obs_kmh$wind_speed * 3.6
#' st2 <- ef_station_table(
#'   stations, obs_kmh,
#'   provenance = list(timestamp_convention = "end", interval = 3600,
#'                     crs = "EPSG:4326"),
#'   units = list(wind_speed = "km/h")
#' )
#' st2$provenance$units
#' @export
ef_station_table <- function(stations, observations, provenance,
                             units = NULL, timestamp_format = NULL,
                             tz = NULL) {
  call <- sys.call()
  if (missing(stations) || missing(observations) || missing(provenance)) {
    ef_abort(
      "`stations`, `observations` and `provenance` must all be supplied.",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  stations <- station_plain_df(stations, "stations", call)
  observations <- station_plain_df(observations, "observations", call)
  provenance <- station_check_provenance(provenance, call, user = TRUE)

  if ("surface_type" %in% names(stations)) {
    stations$surface_type <- station_surface_factor(stations$surface_type,
                                                    call)
  }

  station_check_columns(observations, "observations",
                        c("station_id", "timestamp",
                          station_variables()$variable),
                        c("station_id", "timestamp"), call)
  time <- station_timestamp(observations$timestamp, timestamp_format, tz,
                            call)
  observations$timestamp <- time$timestamp

  vars <- station_measured_vars(observations)
  if (length(vars) == 0L) {
    station_abort(
      sprintf("`observations` must contain at least one measured variable: %s.",
              paste(station_variables()$variable, collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }
  for (v in vars) {
    observations[[v]] <- station_numeric_column(observations[[v]], v, call)
  }
  conv <- station_convert_units(observations, units, call)
  observations <- conv$observations

  if (!is.character(observations$station_id)) {
    station_abort("`observations$station_id` must be character.",
                  "earthflux_station_field_error", call)
  }
  dup <- station_remove_duplicates(observations, call)

  provenance$source_tz <- time$source_tz
  provenance$units <- conv$units
  provenance$duplicates_removed <- dup$removed
  provenance$package_version <- as.character(utils::packageVersion("EarthFlux"))
  provenance$operations <- data.frame(
    step = "ef_station_table",
    detail = sprintf(
      "%d station(s), %d record(s); %d exact duplicate(s) removed; %s",
      nrow(stations), nrow(dup$observations), dup$removed,
      if (any(conv$units$source_unit != conv$units$unit)) {
        sub <- conv$units[conv$units$source_unit != conv$units$unit, ]
        paste0("converted ",
               paste0(sub$variable, " (", sub$source_unit, " -> ", sub$unit,
                      ")", collapse = ", "))
      } else {
        "no unit conversion"
      }
    ),
    stringsAsFactors = FALSE
  )

  out <- new_ef_object(
    list(
      stations = stations,
      observations = dup$observations,
      provenance = provenance,
      qc = station_qc_template(),
      flags = list()
    ),
    "earthflux_station_table"
  )
  ef_validate_stations(out, call = call)
  out
}

# Normalisation helpers --------------------------------------------------------

#' Convert a data frame input to a plain data frame
#'
#' Accepts any object inheriting from `data.frame` (e.g. a tibble) and
#' returns a base data frame with default row names; columns are not
#' modified.
#'
#' @param x Object to convert.
#' @param arg Name of the argument.
#' @param call The call to report.
#' @return A data frame.
#' @noRd
station_plain_df <- function(x, arg, call) {
  if (!is.data.frame(x)) {
    station_abort(sprintf("`%s` must be a data frame, not %s.", arg,
                          class(x)[1L]),
                  "earthflux_station_field_error", call)
  }
  if (nrow(x) == 0L) {
    station_abort(sprintf("`%s` must have at least one row.", arg),
                  "earthflux_station_field_error", call)
  }
  out <- as.list(x)
  attributes(out) <- NULL
  names(out) <- names(x)
  out <- structure(out, class = "data.frame", row.names = seq_len(nrow(x)))
  out
}

#' Check the columns of a table against the contract
#'
#' @param x A data frame.
#' @param arg Name of the table.
#' @param allowed Character vector of accepted columns.
#' @param required Character vector of required columns.
#' @param call The call to report.
#' @return `TRUE`, invisibly.
#' @noRd
station_check_columns <- function(x, arg, allowed, required, call) {
  nms <- names(x)
  if (anyNA(nms) || any(!nzchar(nms)) || anyDuplicated(nms) > 0L) {
    station_abort(sprintf("`%s` must have unique, non-empty column names.",
                          arg),
                  "earthflux_station_field_error", call)
  }
  missing_cols <- setdiff(required, nms)
  if (length(missing_cols) > 0L) {
    station_abort(
      sprintf("`%s` lacks required column(s): %s.", arg,
              paste0("`", missing_cols, "`", collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }
  unknown <- setdiff(nms, allowed)
  if (length(unknown) > 0L) {
    station_abort(
      sprintf(paste0("`%s` has column(s) outside the contract: %s. ",
                     "Accepted columns: %s."),
              arg, paste0("`", unknown, "`", collapse = ", "),
              paste(allowed, collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }
  invisible(TRUE)
}

#' Normalise the `surface_type` column
#'
#' @param x Character or factor.
#' @param call The call to report.
#' @return A factor with the levels of `station_surface_types()`.
#' @noRd
station_surface_factor <- function(x, call) {
  if (!(is.character(x) || is.factor(x))) {
    station_abort("`stations$surface_type` must be character or factor.",
                  "earthflux_station_field_error", call)
  }
  x <- as.character(x)
  bad <- !is.na(x) & !x %in% station_surface_types()
  if (any(bad)) {
    station_abort(
      sprintf("`stations$surface_type` has unknown value(s): %s; accepted: %s.",
              station_show(x[bad]),
              paste(station_surface_types(), collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }
  factor(x, levels = station_surface_types())
}

#' Normalise a measured variable column
#'
#' Numeric (double or integer) columns are stored as double; a logical
#' column whose values are all missing (as produced by readers for an empty
#' column) becomes a double column of `NA`. Anything else is an error: no
#' silent coercion of physical values.
#'
#' @param x Column.
#' @param name Variable name.
#' @param call The call to report.
#' @return A double vector.
#' @noRd
station_numeric_column <- function(x, name, call) {
  if (is.logical(x) && all(is.na(x))) {
    return(rep(NA_real_, length(x)))
  }
  if (!is.numeric(x) || is.object(x)) {
    station_abort(
      sprintf("`observations$%s` must be numeric, not %s.", name,
              class(x)[1L]),
      "earthflux_station_field_error", call
    )
  }
  as.double(x)
}

#' Convert timestamps to POSIXct in UTC
#'
#' @param ts The `timestamp` column.
#' @param timestamp_format,tz See `ef_station_table()`.
#' @param call The call to report.
#' @return A list with `timestamp` (POSIXct, `tzone` "UTC") and `source_tz`.
#' @noRd
station_timestamp <- function(ts, timestamp_format, tz, call) {
  time_abort <- function(message) {
    station_abort(message, "earthflux_station_time_error", call)
  }
  if (inherits(ts, "POSIXct")) {
    if (!is.null(timestamp_format) || !is.null(tz)) {
      time_abort(paste0(
        "`timestamp_format` and `tz` apply only to character timestamps; ",
        "a POSIXct timestamp carries its own time zone."
      ))
    }
    source_tz <- attr(ts, "tzone", exact = TRUE)
    if (is.null(source_tz) || is.na(source_tz[1L]) || !nzchar(source_tz[1L])) {
      time_abort(paste0(
        "`observations$timestamp` has no explicit time zone (empty `tzone` ",
        "attribute); create it with an explicit `tz`, e.g. ",
        "as.POSIXct(..., tz = \"UTC\")."
      ))
    }
    source_tz <- source_tz[1L]
  } else if (is.character(ts)) {
    if (is.null(timestamp_format) || is.null(tz)) {
      time_abort(paste0(
        "Character timestamps need both `timestamp_format` and `tz` ",
        "(no default time zone is assumed)."
      ))
    }
    if (!is.character(timestamp_format) || length(timestamp_format) != 1L ||
        is.na(timestamp_format) || !nzchar(timestamp_format)) {
      time_abort("`timestamp_format` must be a single non-empty string.")
    }
    if (!is.character(tz) || length(tz) != 1L || is.na(tz) || !nzchar(tz) ||
        !tz %in% OlsonNames()) {
      time_abort("`tz` must be a single IANA time zone name (see OlsonNames()).")
    }
    parsed <- as.POSIXct(ts, format = timestamp_format, tz = tz)
    bad <- !is.na(ts) & is.na(parsed)
    if (any(bad)) {
      time_abort(sprintf(
        paste0("%d timestamp(s) could not be parsed with format \"%s\" in ",
               "time zone \"%s\": %s."),
        sum(bad), timestamp_format, tz, station_show(ts[bad], 3L)
      ))
    }
    ts <- parsed
    source_tz <- tz
  } else {
    time_abort(sprintf(
      paste0("`observations$timestamp` must be POSIXct (or character with ",
             "`timestamp_format` and `tz`), not %s."),
      class(ts)[1L]
    ))
  }
  if (anyNA(ts)) {
    time_abort(sprintf("`observations$timestamp` has %d missing value(s).",
                       sum(is.na(ts))))
  }
  attr(ts, "tzone") <- "UTC"
  list(timestamp = ts, source_tz = source_tz)
}

#' Apply the declared unit conversions
#'
#' @param observations Data frame of observations (measured columns double).
#' @param units `NULL`, named list or named character vector.
#' @param call The call to report.
#' @return A list with `observations` (converted) and `units` (data frame
#'   `variable`, `source_unit`, `unit`, `scale`, `offset` for every measured
#'   variable present).
#' @noRd
station_convert_units <- function(observations, units, call) {
  vars <- station_measured_vars(observations)
  defs <- station_variables()
  conv <- station_unit_conversions()
  if (is.null(units)) {
    units <- list()
  }
  if (!(is.list(units) || is.character(units)) || is.object(units)) {
    station_abort("`units` must be NULL, a named list or a named character vector.",
                  "earthflux_station_field_error", call)
  }
  units <- as.list(units)
  if (length(units) > 0L) {
    nms <- names(units)
    if (is.null(nms) || anyNA(nms) || any(!nzchar(nms)) ||
        anyDuplicated(nms) > 0L) {
      station_abort("`units` must have unique, non-empty names.",
                    "earthflux_station_field_error", call)
    }
    unknown <- setdiff(nms, vars)
    if (length(unknown) > 0L) {
      station_abort(
        sprintf("`units` names variable(s) not in `observations`: %s.",
                paste0("`", unknown, "`", collapse = ", ")),
        "earthflux_station_field_error", call
      )
    }
  }

  rows <- lapply(vars, function(v) {
    quantity <- defs$quantity[defs$variable == v]
    unit <- defs$unit[defs$variable == v]
    from <- units[[v]]
    if (is.null(from)) {
      from <- unit
    }
    if (!is.character(from) || length(from) != 1L || is.na(from)) {
      station_abort(sprintf("`units$%s` must be a single string.", v),
                    "earthflux_station_field_error", call)
    }
    k <- which(conv$quantity == quantity & conv$from == from)
    if (length(k) != 1L) {
      station_abort(
        sprintf("Unsupported unit \"%s\" for `%s`; accepted: %s.", from, v,
                paste0("\"", conv$from[conv$quantity == quantity], "\"",
                       collapse = ", ")),
        "earthflux_station_field_error", call
      )
    }
    data.frame(variable = v, source_unit = from, unit = unit,
               scale = conv$scale[k], offset = conv$offset[k],
               stringsAsFactors = FALSE)
  })
  table <- do.call(rbind, rows)
  for (i in seq_len(nrow(table))) {
    v <- table$variable[i]
    if (table$source_unit[i] != table$unit[i]) {
      observations[[v]] <- observations[[v]] * table$scale[i] +
        table$offset[i]
    }
  }
  rownames(table) <- NULL
  list(observations = observations, units = table)
}

#' Remove exact duplicated records and reject conflicting ones
#'
#' @param observations Data frame of observations.
#' @param call The call to report.
#' @return A list with `observations` (exact duplicates removed, first
#'   occurrence kept, row names reset) and `removed` (integer count).
#' @noRd
station_remove_duplicates <- function(observations, call) {
  key <- data.frame(id = observations$station_id,
                    t = as.numeric(observations$timestamp))
  dup_key <- duplicated(key)
  if (!any(dup_key)) {
    return(list(observations = observations, removed = 0L))
  }
  dup_full <- duplicated(observations)
  conflict <- dup_key & !dup_full
  if (any(conflict)) {
    labels <- paste(observations$station_id[conflict],
                    format(observations$timestamp[conflict],
                           "%Y-%m-%d %H:%M:%S UTC"))
    station_abort(
      sprintf(
        paste0("Duplicated records (station_id, timestamp) with different ",
               "values: %s. They are never averaged; resolve them before ",
               "building the table."),
        station_show(labels, 3L)
      ),
      "earthflux_station_duplicate", call
    )
  }
  out <- observations[!dup_full, , drop = FALSE]
  rownames(out) <- NULL
  list(observations = out, removed = sum(dup_full))
}

# Validator --------------------------------------------------------------------

#' Validate a standard station table
#'
#' Checks the structure and the contract of an `earthflux_station_table`
#' (dev/specs/weather-forcing.md sections 2.2-2.6): elements, column names
#' and types, required values, metadata domain, UTC timestamps, known and
#' unique keys, provenance fields; and, for the result of `ef_station_qc()`
#' (class `earthflux_station_qc`), the consistency of the audit table `qc`
#' with the flag records (dev/specs/flags.md test R16, decision FL-13) and
#' of `qc_status` with the observations. Called by `ef_station_table()` and
#' `ef_station_qc()`; it never modifies the object.
#'
#' @param x Object to validate.
#' @param call The call to report.
#' @return `x`, invisibly, if it is valid; otherwise a classed error
#'   (subclasses of `earthflux_input_error`, see `ef_station_table()`).
#' @noRd
ef_validate_stations <- function(x, call = sys.call(-1)) {
  if (!inherits(x, "earthflux_station_table") || !is.list(x)) {
    station_abort("`x` must be an `earthflux_station_table` object.",
                  call = call)
  }
  needed <- c("stations", "observations", "provenance", "qc", "flags")
  if (!all(needed %in% names(x))) {
    station_abort(
      sprintf("An `earthflux_station_table` must contain: %s.",
              paste0("`", needed, "`", collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }
  stations <- x$stations
  observations <- x$observations
  if (!is.data.frame(stations) || !is.data.frame(observations) ||
      nrow(stations) == 0L || nrow(observations) == 0L) {
    station_abort("`stations` and `observations` must be non-empty data frames.",
                  "earthflux_station_field_error", call)
  }
  station_check_provenance(x$provenance, call, user = FALSE)
  station_check_stations(stations, observations, call)
  station_check_observations(observations, stations, call)
  check_flag_list(x$flags, "flags", call = call)
  if (inherits(x, "earthflux_station_qc")) {
    station_check_qc(x, call)
  } else if (!identical(names(x$qc), names(station_qc_template())) ||
             nrow(x$qc) != 0L || length(x$flags) != 0L) {
    station_abort(paste0(
      "A station table without quality control must have an empty `qc` ",
      "table and no flags; run ef_station_qc()."
    ), "earthflux_station_field_error", call)
  }
  invisible(x)
}

#' Check the provenance list
#'
#' @param provenance Object to check.
#' @param call The call to report.
#' @param user Logical. `TRUE` for the list supplied by the user (reserved
#'   fields are rejected); `FALSE` for the stored provenance (package fields
#'   are required).
#' @return `provenance`, a list.
#' @noRd
station_check_provenance <- function(provenance, call, user) {
  prov_abort <- function(message) {
    station_abort(message, "earthflux_station_provenance_error", call)
  }
  if (!is.list(provenance) || is.object(provenance)) {
    prov_abort("`provenance` must be a named list.")
  }
  nms <- names(provenance)
  if (length(provenance) > 0L &&
      (is.null(nms) || anyNA(nms) || any(!nzchar(nms)) ||
         anyDuplicated(nms) > 0L)) {
    prov_abort("`provenance` must have unique, non-empty names.")
  }
  if (user) {
    reserved <- intersect(nms, station_reserved_provenance())
    if (length(reserved) > 0L) {
      prov_abort(sprintf("`provenance` field(s) reserved for the package: %s.",
                         paste0("`", reserved, "`", collapse = ", ")))
    }
  } else {
    absent <- setdiff(c("source_tz", "units", "duplicates_removed",
                        "package_version", "operations"), nms)
    if (length(absent) > 0L) {
      prov_abort(sprintf("`provenance` lacks package field(s): %s.",
                         paste0("`", absent, "`", collapse = ", ")))
    }
  }

  conv <- provenance$timestamp_convention
  if (is.null(conv) || !is.character(conv) || length(conv) != 1L ||
      is.na(conv) || !conv %in% station_timestamp_conventions()) {
    station_abort(
      sprintf(paste0("`provenance$timestamp_convention` is required and must ",
                     "be one of %s (no default)."),
              paste0("\"", station_timestamp_conventions(), "\"",
                     collapse = ", ")),
      "earthflux_station_time_error", call
    )
  }
  interval <- provenance$interval
  if (is.null(interval) || !is.numeric(interval) || length(interval) != 1L ||
      !is.finite(interval) || interval <= 0 || interval != round(interval)) {
    station_abort(paste0(
      "`provenance$interval` is required: the time step of the records in ",
      "seconds, a positive whole number (no default)."
    ), "earthflux_station_time_error", call)
  }
  crs <- provenance$crs
  if (is.null(crs) || !is.character(crs) || length(crs) != 1L ||
      is.na(crs) || crs != "EPSG:4326") {
    prov_abort(paste0(
      "`provenance$crs` is required and must be \"EPSG:4326\": station ",
      "coordinates are decimal degrees in WGS84 (projection is done by the ",
      "spatial module)."
    ))
  }
  provenance
}

#' Check the stations table
#'
#' @param stations,observations Data frames.
#' @param call The call to report.
#' @return `TRUE`, invisibly.
#' @noRd
station_check_stations <- function(stations, observations, call) {
  fields <- station_fields()
  station_check_columns(stations, "stations", fields$field,
                        fields$field[fields$required], call)

  # Heights required by the measured variables.
  defs <- station_variables()
  vars <- station_measured_vars(observations)
  needs <- unique(stats::na.omit(defs$height[defs$variable %in% vars]))
  absent <- setdiff(needs, names(stations))
  if (length(absent) > 0L) {
    station_abort(
      sprintf(paste0("`stations` lacks column(s) %s required by the ",
                     "observed variables (use NA for an unknown height)."),
              paste0("`", absent, "`", collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }

  for (i in seq_len(nrow(fields))) {
    nm <- fields$field[i]
    if (!nm %in% names(stations)) {
      next
    }
    col <- stations[[nm]]
    ok <- switch(fields$type[i],
      character = is.character(col),
      numeric = is.numeric(col) && !is.object(col),
      factor = is.factor(col) &&
        identical(levels(col), station_surface_types())
    )
    if (!ok) {
      station_abort(sprintf("`stations$%s` must be %s.", nm, fields$type[i]),
                    "earthflux_station_field_error", call)
    }
    if (fields$required[i] && anyNA(col)) {
      station_abort(sprintf("`stations$%s` has %d missing value(s).", nm,
                            sum(is.na(col))),
                    "earthflux_station_field_error", call)
    }
  }
  if (any(!nzchar(stations$station_id))) {
    station_abort("`stations$station_id` must not contain empty strings.",
                  "earthflux_station_field_error", call)
  }
  dup <- duplicated(stations$station_id)
  if (any(dup)) {
    station_abort(sprintf("Duplicated `stations$station_id`: %s.",
                          station_show(stations$station_id[dup])),
                  "earthflux_station_duplicate", call)
  }
  check_in_range(stations$lon, "stations$lon", -180, 180, call = call)
  check_in_range(stations$lat, "stations$lat", -90, 90, call = call)
  check_in_range(stations$elevation, "stations$elevation", call = call)
  if ("height_wind" %in% names(stations)) {
    check_in_range(stations$height_wind, "stations$height_wind",
                   lower = station_min_wind_height(), lower_inclusive = FALSE,
                   call = call)
  }
  if ("height_temp_rh" %in% names(stations)) {
    check_in_range(stations$height_temp_rh, "stations$height_temp_rh",
                   lower = 0, lower_inclusive = FALSE, call = call)
  }
  invisible(TRUE)
}

#' Check the observations table
#'
#' @param observations,stations Data frames.
#' @param call The call to report.
#' @return `TRUE`, invisibly.
#' @noRd
station_check_observations <- function(observations, stations, call) {
  station_check_columns(observations, "observations",
                        c("station_id", "timestamp",
                          station_variables()$variable),
                        c("station_id", "timestamp"), call)
  vars <- station_measured_vars(observations)
  if (length(vars) == 0L) {
    station_abort("`observations` must contain at least one measured variable.",
                  "earthflux_station_field_error", call)
  }
  ids <- observations$station_id
  if (!is.character(ids) || anyNA(ids)) {
    station_abort("`observations$station_id` must be character without missing values.",
                  "earthflux_station_field_error", call)
  }
  ts <- observations$timestamp
  if (!inherits(ts, "POSIXct") || !identical(attr(ts, "tzone"), "UTC") ||
      anyNA(ts)) {
    station_abort(paste0(
      "`observations$timestamp` must be POSIXct in UTC without missing ",
      "values."
    ), "earthflux_station_time_error", call)
  }
  unknown <- !ids %in% stations$station_id
  if (any(unknown)) {
    station_abort(
      sprintf("Observations of station(s) not in `stations`: %s.",
              station_show(ids[unknown])),
      "earthflux_station_unknown_id", call
    )
  }
  if (anyDuplicated(data.frame(ids, as.numeric(ts))) > 0L) {
    station_abort("Duplicated records (station_id, timestamp).",
                  "earthflux_station_duplicate", call)
  }
  for (v in vars) {
    col <- observations[[v]]
    if (!is.double(col) || is.object(col)) {
      station_abort(sprintf("`observations$%s` must be double.", v),
                    "earthflux_station_field_error", call)
    }
    n_inf <- sum(is.infinite(col))
    if (n_inf > 0L) {
      station_abort(
        sprintf("`observations$%s` must be finite or NA; found %d infinite value(s).",
                v, n_inf),
        call = call, domain = TRUE
      )
    }
  }
  invisible(TRUE)
}

# Methods ----------------------------------------------------------------------

#' @export
print.earthflux_station_table <- function(x, ...) {
  cat(sprintf("<%s>\n", class(x)[1L]))
  station_print_body(x)
  cat("Quality control: not run (see ef_station_qc())\n")
  invisible(x)
}

#' Print the common part of a station table
#'
#' @param x An `earthflux_station_table`.
#' @return `NULL`, invisibly.
#' @noRd
station_print_body <- function(x) {
  prov <- x$provenance
  obs <- x$observations
  cat(sprintf("Stations: %d (coordinates %s)\n", nrow(x$stations), prov$crs))
  rng <- range(obs$timestamp)
  cat(sprintf("Records: %d, %s to %s UTC (source time zone: %s)\n", nrow(obs),
              format(rng[1L], "%Y-%m-%d %H:%M:%S", tz = "UTC"),
              format(rng[2L], "%Y-%m-%d %H:%M:%S", tz = "UTC"),
              prov$source_tz))
  cat(sprintf("Time step: %s s; timestamps mark %s\n", format(prov$interval),
              switch(prov$timestamp_convention,
                     end = "the end of each period",
                     start = "the start of each period",
                     instant = "instantaneous values")))
  u <- prov$units
  cat("Variables:", paste0(u$variable, " [", u$unit, "]", collapse = ", "),
      "\n")
  if (prov$duplicates_removed > 0L) {
    cat(sprintf("Exact duplicated records removed: %d\n",
                prov$duplicates_removed))
  }
  invisible(NULL)
}
