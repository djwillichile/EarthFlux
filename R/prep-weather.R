# Preprocessing: station values for the consumers of the forcing ---------------
#
# Purpose: hand the quality-controlled station data to their consumers
# without modifying the observations (dev/specs/weather-forcing.md sections
# 3.1, 5.4-5.6 and 7.2; dev/specs/gwr-forcing.md section 2.1):
#   - station_values()                  values of one variable with the QC
#                                       exclusions applied as NA (copy);
#   - station_regionalization_input()   the long table
#                                       `ef_regionalization_input` of the
#                                       interface forcing -> spatial, for the
#                                       variables observed directly;
#   - ef_station_ref_et()               (exported) reference ET series of
#                                       each station (hourly or daily), the
#                                       instantaneous reference ET at given
#                                       overpass times and the daily sums
#                                       for given dates, with flags and
#                                       provenance (class
#                                       earthflux_station_ref_et).
#
# The physics is that of R/forcing-derived.R and R/reference-et.R; this file
# only orchestrates: it selects the values allowed by the QC policy, builds
# the time geometry of each record, carries the night-time cloudiness,
# defines the day and applies the open decisions WF-09, WF-11, WF-15 and
# WF-16 as explicit arguments without defaults.

#' Values of an observed variable with the QC policy applied
#'
#' Returns a copy of one variable of `observations` in which the values
#' whose status is `"excluded"` are `NA`: the orchestration converts what
#' QC excluded into `NA` before the numeric core (dev/ARCHITECTURE.md
#' section 3.1, P0-11). The observations themselves are not modified.
#'
#' @param x An `earthflux_station_qc` (result of `ef_station_qc()`).
#' @param variable Character. An observed variable of `x`.
#' @return A double vector aligned with the rows of `x$observations`.
#' @noRd
station_values <- function(x, variable) {
  call <- sys.call()
  if (!inherits(x, "earthflux_station_qc")) {
    station_abort("`x` must be the result of ef_station_qc().", call = call)
  }
  check_string(variable)
  vars <- station_measured_vars(x$observations)
  if (!variable %in% vars) {
    station_abort(
      sprintf("`variable` must be an observed variable of `x`: %s.",
              paste(vars, collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }
  value <- x$observations[[variable]]
  value[x$qc_status[[variable]] == "excluded"] <- NA_real_
  value
}

#' Variables of the regionalization input observed directly at stations
#'
#' Subset of the variables of dev/specs/weather-forcing.md section 7.2 that
#' are columns of the station contract with the same unit; the others
#' (`wind_speed_2m`, `clearness`, `etr_inst`, `etr_24`, and
#' `vapour_pressure` when it is derived) come from the reference ET module.
#'
#' @return A character vector.
#' @noRd
station_regionalization_vars <- function() {
  c("air_temperature", "vapour_pressure", "solar_radiation")
}

#' Levels of the `variable` column of the regionalization input
#'
#' dev/specs/weather-forcing.md section 7.2.
#'
#' @return A character vector.
#' @noRd
regionalization_variables <- function() {
  c("air_temperature", "vapour_pressure", "wind_speed_2m", "clearness",
    "solar_radiation", "etr_inst", "etr_24")
}

#' Regionalization input from a quality-controlled station table
#'
#' Builds the long table `ef_regionalization_input` of the interface
#' forcing -> spatial (dev/specs/weather-forcing.md section 7.2;
#' dev/specs/gwr-forcing.md section 2.1) for variables observed directly at
#' the stations. Values are those of `observations` (never modified); the QC
#' result travels in `qc_status`, and `spatial` decides which statuses
#' enter a fit (`excluded` never does).
#'
#' `target_time` is the mid-point of the averaging period
#' (`timestamp - interval / 2` for `"end"`, `timestamp + interval / 2` for
#' `"start"`) or the timestamp itself for instantaneous values, with
#' `period_seconds` = `interval` or 0.
#'
#' @param x An `earthflux_station_qc` (result of `ef_station_qc()`).
#' @param variables Character. Variables among
#'   `station_regionalization_vars()` present in `x$observations`.
#' @return A data frame with columns `station_id`, `lon`, `lat`
#'   (decimal degrees, WGS84), `elevation` \[m\], `target_time` (POSIXct
#'   UTC), `period_seconds` (integer), `variable` (factor with the levels of
#'   `regionalization_variables()`), `value` (contract unit), `qc_status`
#'   (factor `ok`, `warning`, `excluded`) and `reference` (`NA`: only the
#'   reference ET variables carry one). One row per record and variable,
#'   ordered by variable, then by the rows of `observations`.
#' @noRd
station_regionalization_input <- function(x, variables) {
  call <- sys.call()
  if (!inherits(x, "earthflux_station_qc")) {
    station_abort("`x` must be the result of ef_station_qc().", call = call)
  }
  if (!is.character(variables) || length(variables) == 0L ||
      anyNA(variables) || anyDuplicated(variables) > 0L) {
    station_abort("`variables` must be a character vector of distinct names.",
                  call = call)
  }
  obs <- x$observations
  ok <- variables %in% station_regionalization_vars() &
    variables %in% names(obs)
  if (!all(ok)) {
    station_abort(
      sprintf(paste0("Variable(s) not observed directly in `x`: %s. Derived ",
                     "variables come from the reference ET module."),
              paste0("`", variables[!ok], "`", collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }
  prov <- x$provenance
  shift <- switch(prov$timestamp_convention,
                  end = -prov$interval / 2,
                  start = prov$interval / 2,
                  instant = 0)
  period <- if (prov$timestamp_convention == "instant") 0L else
    as.integer(prov$interval)
  at <- match(obs$station_id, x$stations$station_id)
  rows <- lapply(variables, function(v) {
    data.frame(
      station_id = obs$station_id,
      lon = x$stations$lon[at],
      lat = x$stations$lat[at],
      elevation = x$stations$elevation[at],
      target_time = obs$timestamp + shift,
      period_seconds = period,
      variable = factor(v, levels = regionalization_variables()),
      value = obs[[v]],
      qc_status = x$qc_status[[v]],
      reference = NA_character_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# Reference ET at the stations ------------------------------------------------

#' Reference evapotranspiration at weather stations
#'
#' @description
#' Computes the reference evapotranspiration series of every station of a
#' station table (hourly or daily records), and from it the two quantities
#' that the METRIC chain needs: the instantaneous reference ET at given
#' overpass times (`etr_inst`, mm h-1, for the cold anchor condition) and the
#' daily reference ET of given dates (`etr_24`, mm d-1, for the extrapolation
#' to 24 hours). It orchestrates the derived variables ([ef_es()],
#' [ef_ea_rh()], [ef_wind_2m()], [ef_ra_period()], [ef_rso()], ...) and the
#' reference surface functions ([ef_ref_net_radiation()],
#' [ef_ref_soil_heat_flux()], [ef_ref_et()]) on the values allowed by the
#' quality control. The choices that are still open decisions of the
#' specification (WF-09, WF-11, WF-15, WF-16) are explicit arguments without
#' defaults.
#'
#' @param x An `earthflux_station_qc` ([ef_station_qc()]) or an
#'   `earthflux_station_table` ([ef_station_table()]), which is then quality
#'   controlled with `ef_station_qc(x)` (policy `"exclude_critical"`; call
#'   [ef_station_qc()] first to choose another policy). Only the values whose
#'   QC status is not `"excluded"` are used; the excluded ones are missing.
#' @param reference Character, no default. `"alfalfa"` (tall reference, ETr,
#'   the reference of METRIC) or `"grass"` (short reference, ETo). It must be
#'   the reference of the reference ET fraction of the cold anchor.
#' @param timestep Character, no default. `"hourly"` (records with
#'   `interval = 3600` s; FAO-56 Eq. 53 form) or `"daily"` (records with
#'   `interval = 86400` s; FAO-56 Eq. 6 form). The records must be period
#'   means (`timestamp_convention` `"end"` or `"start"`).
#' @param standard Character, no default. `"fao56"` (grass only) or
#'   `"asce"` (ASCE-EWRI 2005 standardized equation), both `VERIFICADA`;
#'   see [ef_ref_et()]. It also selects the constants and limits of the net
#'   radiation ([ef_ref_net_radiation()]) and the treatment of sunrise and
#'   sunset in the hourly extraterrestrial radiation ([ef_ra_period()]).
#' @param humidity Character, no default. Source of the actual vapour
#'   pressure: `"vapour_pressure"` (column `vapour_pressure`),
#'   `"dewpoint_temperature"` (FAO-56 Eq. 14 on `dewpoint_temperature`) or
#'   `"relative_humidity"` (hourly: FAO-56 Eq. 54 with `air_temperature` and
#'   `relative_humidity`; daily: Eq. 17 with `tmin`, `tmax`, `rh_max` and
#'   `rh_min`). The same forms are ASCE-EWRI (2005) Eqs. 8, 38, 41 and 11,
#'   ranked first or second in its Tables 3 and 4.
#' @param day_definition Character, no default (decision WF-11). Day of the
#'   daily sums: `"utc"` (UTC calendar day) or `"local_standard"` (calendar
#'   day in the local standard time given by `utc_offset`, without daylight
#'   saving time). A period belongs to the day of its mid-point.
#' @param day_completeness Character, no default (decision WF-11, gap
#'   policy). Only `"all_periods"` is implemented: a day has a daily value
#'   only if all its periods (24 hourly periods, or the daily record) have a
#'   valid reference ET; otherwise `etr_24` is `NA` and flagged
#'   `EF_WS_INCOMPLETE_DAY`. No gap is filled.
#' @param daytime_rule Character or `NULL` (decision WF-15). Hourly only
#'   (required; `NULL` for daily): criterion of the daytime periods, which
#'   select the soil heat flux ratio and, with `standard = "asce"`, the
#'   denominator constant: `"ra_positive"` (extraterrestrial radiation of
#'   the period > 0; with `standard = "fao56"`, sun above the horizon at the
#'   mid-point, FAO-56 midpoint criterion) or `"rn_positive"` (net radiation
#'   of the reference surface > 0, the definition of daytime of ASCE-EWRI
#'   2005, text before Table 1 and Table 2, p. 5; see
#'   [ef_ref_soil_heat_flux()] for the inconsistency of the report at
#'   \eqn{R_n = 0}{Rn = 0}).
#' @param night_cloudiness Character or `NULL`. Hourly only (required;
#'   `NULL` for daily): the cloudiness term of the periods where the ratio
#'   \eqn{R_s/R_{so}}{Rs/Rso} is not used:
#'   * `"before_sunset"` (FAO-56, chapter 4, hourly time step): night-time
#'     periods (\eqn{R_{so} = 0}{Rso = 0}) take the term of the last period
#'     of the same station, in the previous 24 hours, whose mid-point hour
#'     angle lies in \eqn{[\omega_s - 0.79, \omega_s - 0.52]}{[ws - 0.79, ws
#'     - 0.52]}, i.e. 2-3 hours before sunset;
#'   * `"low_sun"` (ASCE-EWRI 2005, Eq. 46, pp. 35-36): every period whose
#'     sun angle above the horizon at the mid-point (Eq. 62) is at most
#'     0.3 rad (night, dusk and dawn, including periods with
#'     \eqn{R_{so} > 0}{Rso > 0}) takes the term of the last period of the
#'     same station, in the previous 24 hours, with a sun angle above
#'     0.3 rad;
#'   * `"fixed"`: night-time periods take the constant ratio `night_ratio`.
#'
#'   With `"before_sunset"` and `"low_sun"` the result is `NA` if there is
#'   no qualifying period or its term is missing (e.g. the first night of a
#'   series, or a season without any period of sun angle above 0.3 rad).
#' @param night_ratio Numeric scalar or `NULL`. The night-time ratio
#'   \eqn{R_s/R_{so}}{Rs/Rso} for `night_cloudiness = "fixed"`, in \[0, 1\]
#'   for `"fao56"` and in \[0.3, 1\] for `"asce"` (FAO-56 suggests 0.4-0.6
#'   in humid and sub-humid and 0.7-0.8 in arid and semi-arid climates; 0.3
#'   means complete cloud cover; ASCE-EWRI, p. 36, allows a ratio from 0.3
#'   to 1 where no period has a sun angle of 0.3 rad). `NULL` otherwise.
#' @param overpass POSIXct or `NULL`. Overpass times at which the
#'   instantaneous reference ET is wanted (hourly only); converted to UTC.
#'   Every station gets every time.
#' @param inst_method Character or `NULL` (decision WF-09). Required with
#'   `overpass`: `"O1"` (reference ET of the hourly period that contains the
#'   overpass time, start included, end excluded) or `"O3"` (linear
#'   interpolation in time of the hourly reference ET between the mid-points
#'   of consecutive periods; no interpolation across a missing record and no
#'   extrapolation). Options O2, O4 and O5 of the specification are not
#'   implemented.
#' @param dates Date or `NULL`. Days of the daily sums (in the day
#'   definition). `NULL`: every day with at least one record, per station.
#' @param utc_offset Numeric or `NULL`. Required with
#'   `day_definition = "local_standard"` (`NULL` otherwise): offset of the
#'   local standard time from UTC \[h\], in \[-12, 14\] (e.g. `-4` for UTC-4),
#'   a single value for all stations or a vector named by `station_id`.
#'
#' @return An object of class `earthflux_station_ref_et`: a list with
#'   * `series`: one row per record of `x$observations` (same order) with
#'     `station_id`, `timestamp`, `target_time` (mid-point of the period,
#'     UTC), `date` (day of the period, see `day_definition`),
#'     `extraterrestrial_radiation`, `clear_sky_radiation`,
#'     `solar_radiation` (MJ m-2 per period: h-1 or d-1),
#'     `vapour_pressure`, `vapour_pressure_deficit` \[kPa\],
#'     `wind_speed_2m` \[m s-1\], `cloudiness` (the term \eqn{1.35
#'     R_s/R_{so} - 0.35}{1.35 Rs/Rso - 0.35} used), `cloudiness_source`
#'     (`"ratio"`, `"before_sunset"`, `"fixed"`), `daytime` (hourly; `NA`
#'     for daily), `net_radiation`, `soil_heat_flux` (MJ m-2 per period)
#'     and `et_ref` (mm h-1 or mm d-1);
#'   * `etr_inst`: one row per station and overpass time with
#'     `station_id`, `overpass_time` (UTC), `etr_inst` \[mm h-1\] and
#'     `method` (zero rows without `overpass`);
#'   * `etr_24`: one row per station and day with `station_id`, `date`,
#'     `n_periods` (periods with a valid reference ET) and `etr_24`
#'     \[mm d-1\];
#'   * `reference`, `timestep`, `standard`;
#'   * `flags`: `earthflux_flag` records of scope `record` for the codes
#'     that hold somewhere, each with an element `target` naming the table
#'     whose rows `index` refers to (`"series"`, `"etr_inst"`, `"etr_24"`):
#'     `EF_INPUT_NA`, `EF_WS_RS_RSO_LIMITED` and `EF_WS_ETR_NEGATIVE`
#'     (series), `EF_WS_OVERPASS_OUTSIDE_RECORDS` and `EF_INPUT_NA`
#'     (`etr_inst`), `EF_WS_INCOMPLETE_DAY` (`etr_24`);
#'   * `provenance`: the choices made, the verification status, the
#'     constants used, the QC policy and the values excluded by it, the
#'     provenance of the station table, `flags_evaluated` (and
#'     `flags_evaluated_by_target`) and the package version.
#'
#' @details
#' **Hourly records.** For each record, with \eqn{t} the mid-point of the
#' period: \eqn{R_a}{Ra} of the period with [ef_ra_period()] (FAO-56 Eq. 28
#' or ASCE-EWRI Eq. 48; the treatment of sunrise and sunset follows
#' `standard`; day of year of \eqn{t} in UTC),
#' \eqn{R_{so}}{Rso} with [ef_rso()] (Eq. 37, decision WF-12), the air
#' pressure from the station elevation ([ef_air_pressure()], Eq. 7, decision
#' WF-05; a measured `air_pressure` is not used), \eqn{\gamma}{gamma},
#' \eqn{e^\circ(T)}{e0(T)} and \eqn{\Delta}{Delta} at the hourly
#' temperature, the wind at 2 m from `height_wind` (Eq. 47), the solar
#' radiation converted from W m-2 to MJ m-2 h-1 (x 0.0036, FAO-56 Table 3),
#' then [ef_ref_net_radiation()], [ef_ref_soil_heat_flux()] and
#' [ef_ref_et()]. Periods with \eqn{R_{so} > 0}{Rso > 0} (with
#' `"low_sun"`: with a sun angle above 0.3 rad) use their own ratio
#' \eqn{R_s/R_{so}}{Rs/Rso} (limited to the range of the standard inside
#' the cloudiness term and flagged `EF_WS_RS_RSO_LIMITED`); the others use
#' `night_cloudiness`.
#'
#' **Daily records.** Tmean = (Tmax + Tmin)/2 (Eq. 9), \eqn{e_s}{es} =
#' mean of \eqn{e^\circ(T_{max})}{e0(Tmax)} and \eqn{e^\circ(T_{min})}{e0(Tmin)}
#' (Eq. 12), \eqn{\Delta}{Delta} at Tmean, \eqn{R_a}{Ra} with [ef_ra_daily()]
#' (day of year of the record's day), the solar radiation converted from W
#' m-2 (24-hour mean) to MJ m-2 d-1 (x 0.0864), \eqn{G = 0}{G = 0} (Eq. 42).
#' A day with \eqn{R_{so} = 0}{Rso = 0} (polar night) has no defined
#' cloudiness term and gives `NA`.
#'
#' **Daily sums** (option D1 of the specification for hourly records,
#' decision WF-16): `etr_24` is the sum of the 24 hourly depths of the day
#' (rate in mm h-1 times 1 h), negative values included; FAO-56 (chapter 4)
#' states that hourly sums over 24 hours generally match the daily
#' computation for the grass reference, and ASCE-EWRI (2005, p. 45) sums
#' hourly ETos or ETrs over the 24-hour period and recommends retaining the
#' negative values; neither source defines the clock of the day (UTC or
#' local standard time, WF-11). Its use for METRIC (Allen et al., 2007) is
#' `TODO`. For daily records `etr_24` is the daily value of the record
#' (option D2 with daily data).
#'
#' **Instantaneous reference ET** (decision WF-09): `etr_inst` is a rate in
#' mm h-1. An overpass time outside the time covered by the records of a
#' station (option O1: from the start of its first period to the end of its
#' last period; option O3: from its first to its last mid-point) gives `NA`
#' and the flag `EF_WS_OVERPASS_OUTSIDE_RECORDS`; inside that range, a
#' missing record or a missing reference ET gives `NA` and `EF_INPUT_NA`.
#'
#' Values are never filled, truncated or corrected: negative reference ET
#' is kept (`EF_WS_ETR_NEGATIVE`). Under `qc_policy = "keep_all"` an
#' impossible value reaches the numeric functions, which raise
#' `earthflux_domain_error`. Missing or unknown choices raise
#' `earthflux_missing_input` or `earthflux_unknown_method`; choices that do
#' not apply to the time step, a record interval that does not match
#' `timestep`, or a missing column raise `earthflux_input_error`
#' subclasses.
#'
#' @section Verification status:
#' The physics is that of the functions called (FAO-56 grass and ASCE-EWRI
#' 2005 short and tall reference: `VERIFICADA`), reproduced through this
#' function for FAO-56 examples 18 and 19. The orchestration choices are
#' recorded in the provenance: `"before_sunset"` follows FAO-56 (chapter 4)
#' with the selection of the last qualifying period as an implementation
#' choice; `"low_sun"` (ASCE-EWRI Eq. 46) and `"rn_positive"` (ASCE-EWRI
#' p. 5) are `VERIFICADA`; the day definition and the completeness rule are
#' open decisions (WF-11); the daily sum is `TODO` for METRIC. The worked
#' examples of ASCE-EWRI (2005), Appendix C, are not reproduced: the copy of
#' the report that was read does not include the appendices.
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
#' Equation*. Task Committee on Standardization of Reference
#' Evapotranspiration, Environmental and Water Resources Institute of the
#' American Society of Civil Engineers. Final report, January 2005.
#' Published as Allen, R. G., Walter, I. A., Elliott, R. L., Howell, T. A.,
#' Itenfisu, D., Jensen, M. E., & Snyder, R. L. (Eds.), American Society of
#' Civil Engineers, Reston, VA. \doi{10.1061/9780784408056}
#'
#' @family reference evapotranspiration functions
#' @seealso [ef_station_table()], [ef_station_qc()].
#' @export
#'
#' @examples
#' # One synthetic station (fictitious values), 48 hourly records in UTC.
#' times <- as.POSIXct("2024-01-15 01:00", tz = "UTC") + 3600 * (0:47)
#' mid <- as.numeric(times) / 3600 - 0.5
#' sun <- pmax(0, cos((mid %% 24 - 16.8) * pi / 12))
#' st <- ef_station_table(
#'   stations = data.frame(station_id = "ST01", lon = -71.5, lat = -35.4,
#'                         elevation = 150, height_wind = 2,
#'                         height_temp_rh = 2),
#'   observations = data.frame(
#'     station_id = "ST01", timestamp = times,
#'     air_temperature = 14 + 12 * sun, relative_humidity = 80 - 45 * sun,
#'     wind_speed = 1 + 2 * sun, solar_radiation = 850 * sun
#'   ),
#'   provenance = list(timestamp_convention = "end", interval = 3600,
#'                     crs = "EPSG:4326")
#' )
#' et <- ef_station_ref_et(
#'   st, reference = "alfalfa", timestep = "hourly", standard = "asce",
#'   humidity = "relative_humidity", day_definition = "utc",
#'   day_completeness = "all_periods", daytime_rule = "rn_positive",
#'   night_cloudiness = "low_sun",
#'   overpass = as.POSIXct("2024-01-15 14:48", tz = "UTC"),
#'   inst_method = "O3"
#' )
#' et$etr_inst
#' et$etr_24
ef_station_ref_et <- function(x, reference, timestep, standard, humidity,
                              day_definition, day_completeness,
                              daytime_rule = NULL, night_cloudiness = NULL,
                              night_ratio = NULL, overpass = NULL,
                              inst_method = NULL, dates = NULL,
                              utc_offset = NULL) {
  call <- sys.call()
  if (!inherits(x, "earthflux_station_table")) {
    station_abort(
      "`x` must be an `earthflux_station_table` or `earthflux_station_qc`.",
      call = call
    )
  }
  qc_here <- !inherits(x, "earthflux_station_qc")
  if (qc_here) {
    x <- ef_station_qc(x)
  }
  k <- check_reference_setup(
    if (missing(reference)) NULL else reference,
    if (missing(timestep)) NULL else timestep,
    if (missing(standard)) NULL else standard,
    call = call
  )
  check_method(if (missing(humidity)) NULL else humidity,
               c("vapour_pressure", "dewpoint_temperature",
                 "relative_humidity"),
               arg = "humidity", call = call)
  check_method(if (missing(day_definition)) NULL else day_definition,
               c("utc", "local_standard"), arg = "day_definition",
               call = call)
  check_method(if (missing(day_completeness)) NULL else day_completeness,
               "all_periods", arg = "day_completeness", call = call)
  station_ref_check_choices(timestep, standard, daytime_rule,
                            night_cloudiness, night_ratio, overpass,
                            inst_method, call)
  station_ref_check_records(x$provenance, timestep, call)
  offset <- station_ref_utc_offset(utc_offset, day_definition, x$stations,
                                   call)
  if (!is.null(dates) &&
      (!inherits(dates, "Date") || length(dates) == 0L || anyNA(dates))) {
    station_abort("`dates` must be a non-empty Date vector without NA.",
                  call = call)
  }
  inputs <- station_ref_inputs(x, timestep, humidity, call)

  obs <- x$observations
  st <- x$stations
  at <- match(obs$station_id, st$station_id)
  mid <- station_period_mid(obs$timestamp, x$provenance)
  date <- as.Date(mid + offset[at] * EF_SECONDS_PER_HOUR, tz = "UTC")

  core <- if (timestep == "hourly") {
    station_ref_hourly(inputs, st[at, , drop = FALSE], obs$station_id, mid,
                       reference, standard, daytime_rule, night_cloudiness,
                       night_ratio)
  } else {
    station_ref_daily(inputs, st[at, , drop = FALSE], date, reference,
                      standard)
  }

  series <- data.frame(
    station_id = obs$station_id,
    timestamp = obs$timestamp,
    target_time = mid,
    date = date,
    core$table,
    stringsAsFactors = FALSE
  )
  rownames(series) <- NULL

  inst <- station_ref_inst(series, overpass, inst_method)
  daily <- station_ref_daily_sums(series, dates, timestep)

  flags <- list(
    series = core$flags,
    etr_inst = inst$flags,
    etr_24 = daily$flags
  )
  all_flags <- unname(do.call(c, lapply(names(flags), function(target) {
    lapply(flags[[target]], function(f) {
      f$target <- target
      f
    })
  })))
  if (is.null(all_flags)) {
    all_flags <- list()
  }
  evaluated_by_target <- lapply(flags, ef_flags_evaluated)

  used <- unique(c(inputs$used, "wind_speed"))
  excluded <- data.frame(
    variable = used,
    n_excluded = vapply(used, function(v) {
      sum(x$qc_status[[v]] == "excluded")
    }, integer(1), USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
  new_ef_object(
    list(
      series = series,
      etr_inst = inst$table,
      etr_24 = daily$table,
      reference = reference,
      timestep = timestep,
      standard = standard,
      flags = all_flags,
      provenance = list(
        fun = "ef_station_ref_et",
        reference = reference,
        timestep = timestep,
        standard = standard,
        status = "VERIFICADA",
        constants = k,
        choices = list(
          humidity = humidity,
          daytime_rule = daytime_rule,
          night_cloudiness = night_cloudiness,
          night_ratio = night_ratio,
          inst_method = inst_method,
          day_definition = day_definition,
          utc_offset = if (day_definition == "utc") NULL else
            stats::setNames(offset, st$station_id),
          day_completeness = day_completeness,
          daily_method = if (timestep == "hourly") {
            "D1: sum of the 24 hourly values of the day"
          } else {
            "D2: daily equation with the daily records"
          }
        ),
        derived = list(
          air_pressure = "FAO-56 Eq. 7 from the station elevation (WF-05)",
          clear_sky_radiation = "FAO-56 Eq. 37 (WF-12)",
          extraterrestrial_radiation = if (timestep == "daily") {
            "FAO-56 Eq. 21 = ASCE-EWRI Eq. 21 (ef_ra_daily())"
          } else if (standard == "fao56") {
            "FAO-56 Eq. 28, midpoint criterion (ef_ra_period())"
          } else {
            "ASCE-EWRI Eq. 48 with the limits of Eq. 56 (ef_ra_period())"
          },
          net_radiation = if (standard == "fao56") {
            "FAO-56 Eqs. 38-40 (ef_ref_net_radiation())"
          } else {
            "ASCE-EWRI Eqs. 15-18 and 42-45 (ef_ref_net_radiation())"
          },
          wind_speed_2m = "FAO-56 Eq. 47 from height_wind",
          vapour_pressure = inputs$ea_source
        ),
        qc = list(
          qc_policy = x$provenance$qc$qc_policy,
          run_by_ef_station_ref_et = qc_here,
          excluded = excluded
        ),
        station_table = x$provenance,
        references = c(
          "FAO-56 (Allen et al., 1998), chapters 3-4",
          if (standard == "asce") {
            paste("ASCE-EWRI (2005), Task Committee final report,",
                  "January 2005, Eqs. 1-67 and Table 1",
                  "(doi:10.1061/9780784408056)")
          }
        ),
        flags_evaluated = unique(unlist(evaluated_by_target,
                                        use.names = FALSE)),
        flags_evaluated_by_target = evaluated_by_target,
        earthflux_version = as.character(getNamespaceVersion("EarthFlux"))
      )
    ),
    "earthflux_station_ref_et"
  )
}

#' Check the choices of ef_station_ref_et() that depend on the time step
#'
#' @inheritParams ef_station_ref_et
#' @param call The call to report.
#' @return `NULL`, invisibly.
#' @noRd
station_ref_check_choices <- function(timestep, standard, daytime_rule,
                                      night_cloudiness, night_ratio,
                                      overpass, inst_method, call) {
  if (timestep == "daily") {
    given <- c(daytime_rule = !is.null(daytime_rule),
               night_cloudiness = !is.null(night_cloudiness),
               night_ratio = !is.null(night_ratio),
               overpass = !is.null(overpass),
               inst_method = !is.null(inst_method))
    if (any(given)) {
      station_abort(
        sprintf(paste0("%s must be NULL for `timestep = \"daily\"` (no ",
                       "day/night split; the instantaneous reference ET ",
                       "needs hourly records)."),
                paste0("`", names(given)[given], "`", collapse = ", ")),
        call = call
      )
    }
    return(invisible(NULL))
  }
  check_method(daytime_rule, c("ra_positive", "rn_positive"),
               arg = "daytime_rule", call = call)
  check_method(night_cloudiness, c("before_sunset", "fixed", "low_sun"),
               arg = "night_cloudiness", call = call)
  if (night_cloudiness == "fixed") {
    if (is.null(night_ratio)) {
      ef_abort("`night_ratio` is required with `night_cloudiness = \"fixed\"`.",
               class = c("earthflux_missing_input", "earthflux_input_error"),
               call = call)
    }
    # Range of Rs/Rso of the standard: FAO-56 Eq. 39 (<= 1); ASCE-EWRI
    # (2005) Eqs. 18 and 45 ([0.3, 1]).
    check_scalar(night_ratio, "night_ratio",
                 lower = if (standard == "asce") 0.3 else 0, upper = 1,
                 call = call)
  } else if (!is.null(night_ratio)) {
    station_abort(
      "`night_ratio` must be NULL unless `night_cloudiness = \"fixed\"`.",
      call = call
    )
  }
  if (is.null(overpass)) {
    if (!is.null(inst_method)) {
      station_abort("`inst_method` must be NULL without `overpass`.",
                    call = call)
    }
  } else {
    if (!inherits(overpass, "POSIXct") || length(overpass) == 0L ||
        anyNA(overpass)) {
      station_abort("`overpass` must be a non-empty POSIXct vector without NA.",
                    "earthflux_station_time_error", call)
    }
    check_method(inst_method, c("O1", "O3"), arg = "inst_method",
                 call = call)
  }
  invisible(NULL)
}

#' Check that the records match the time step of ef_station_ref_et()
#'
#' @param provenance Provenance of the station table.
#' @param timestep `"hourly"` or `"daily"`.
#' @param call The call to report.
#' @return `NULL`, invisibly.
#' @noRd
station_ref_check_records <- function(provenance, timestep, call) {
  interval <- if (timestep == "hourly") EF_SECONDS_PER_HOUR else
    24 * EF_SECONDS_PER_HOUR
  if (!provenance$timestamp_convention %in% c("end", "start") ||
      provenance$interval != interval) {
    station_abort(
      sprintf(paste0("`timestep = \"%s\"` needs period means of %d s ",
                     "(`timestamp_convention` \"end\" or \"start\"); the ",
                     "table has \"%s\" records of %s s."),
              timestep, as.integer(interval),
              provenance$timestamp_convention, format(provenance$interval)),
      "earthflux_station_time_error", call
    )
  }
  invisible(NULL)
}

#' UTC offset of each station for the day definition
#'
#' @inheritParams ef_station_ref_et
#' @param stations The `stations` table.
#' @param call The call to report.
#' @return Numeric offsets \[h\] aligned with `stations` (0 for `"utc"`).
#' @noRd
station_ref_utc_offset <- function(utc_offset, day_definition, stations,
                                   call) {
  n <- nrow(stations)
  if (day_definition == "utc") {
    if (!is.null(utc_offset)) {
      station_abort(
        "`utc_offset` must be NULL with `day_definition = \"utc\"`.",
        call = call
      )
    }
    return(rep(0, n))
  }
  if (is.null(utc_offset)) {
    ef_abort(
      paste0("`utc_offset` (hours from UTC of the local standard time) is ",
             "required with `day_definition = \"local_standard\"`."),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (!is.numeric(utc_offset) || length(utc_offset) == 0L ||
      anyNA(utc_offset)) {
    station_abort("`utc_offset` must be numeric without NA.", call = call)
  }
  check_in_range(utc_offset, "utc_offset", lower = -12, upper = 14,
                 call = call)
  if (is.null(names(utc_offset))) {
    if (length(utc_offset) != 1L) {
      station_abort(
        "`utc_offset` must be a single value or a vector named by station_id.",
        call = call
      )
    }
    return(rep(as.double(utc_offset), n))
  }
  missing_id <- setdiff(stations$station_id, names(utc_offset))
  if (length(missing_id) > 0L) {
    station_abort(sprintf("`utc_offset` has no value for station(s) %s.",
                          station_show(missing_id)),
                  "earthflux_station_unknown_id", call)
  }
  as.double(unname(utc_offset[stations$station_id]))
}

#' Input values of ef_station_ref_et() with the QC policy applied
#'
#' @inheritParams ef_station_ref_et
#' @param call The call to report.
#' @return A list of numeric vectors aligned with the observations (missing
#'   where the QC excluded the value), plus `used` (variables used) and
#'   `ea_source` (description of the vapour pressure).
#' @noRd
station_ref_inputs <- function(x, timestep, humidity, call) {
  hum <- switch(
    humidity,
    vapour_pressure = "vapour_pressure",
    dewpoint_temperature = "dewpoint_temperature",
    relative_humidity = if (timestep == "hourly") "relative_humidity" else
      c("rh_max", "rh_min")
  )
  temp <- if (timestep == "hourly") "air_temperature" else c("tmax", "tmin")
  needed <- unique(c(temp, hum, "wind_speed", "solar_radiation"))
  absent <- setdiff(needed, names(x$observations))
  if (length(absent) > 0L) {
    station_abort(
      sprintf("`x$observations` lacks the column(s) %s needed for this call.",
              paste0("`", absent, "`", collapse = ", ")),
      "earthflux_station_field_error", call
    )
  }
  if (!"height_wind" %in% names(x$stations)) {
    station_abort("`x$stations` lacks the column `height_wind`.",
                  "earthflux_station_field_error", call)
  }
  out <- lapply(stats::setNames(needed, needed),
                function(v) station_values(x, v))
  out$used <- needed
  out$ea_source <- switch(
    humidity,
    vapour_pressure = "observed vapour_pressure",
    dewpoint_temperature = "FAO-56 Eq. 14 from dewpoint_temperature",
    relative_humidity = if (timestep == "hourly") {
      "FAO-56 Eq. 54 from air_temperature and relative_humidity"
    } else {
      "FAO-56 Eq. 17 from tmin, tmax, rh_max and rh_min"
    }
  )
  out$humidity <- humidity
  out
}

#' Flag masks of a sub-call mapped to the rows of a table
#'
#' @param masks Named list of logical masks (length `n`) or empty list.
#' @param flags Flags of the sub-call (`index` relative to `rows`).
#' @param evaluated Codes evaluated by the sub-call.
#' @param rows Integer rows of the table of the sub-call positions.
#' @param n Number of rows of the table.
#' @return The updated `masks`.
#' @noRd
station_ref_add_masks <- function(masks, flags, evaluated, rows, n) {
  for (code in evaluated) {
    if (is.null(masks[[code]])) {
      masks[[code]] <- logical(n)
    }
  }
  for (f in flags) {
    masks[[f$code]][rows[f$index]] <- TRUE
  }
  masks
}

#' Hourly reference ET of the records
#'
#' @param inputs Result of `station_ref_inputs()`.
#' @param st The `stations` rows aligned with the observations.
#' @param station_id Character station of each record.
#' @param mid POSIXct mid-points (UTC).
#' @inheritParams ef_station_ref_et
#' @return A list with `table` (data frame of the derived quantities) and
#'   `flags` (record flags over the records, with attribute `evaluated`).
#' @noRd
station_ref_hourly <- function(inputs, st, station_id, mid, reference,
                               standard, daytime_rule, night_cloudiness,
                               night_ratio) {
  n <- length(mid)
  lat <- st$lat * pi / 180
  lon <- st$lon * pi / 180
  lt <- as.POSIXlt(mid, tz = "UTC")
  doy <- lt$yday + 1L
  utc_hour <- lt$hour + lt$min / 60 + lt$sec / EF_SECONDS_PER_HOUR
  t_air <- inputs$air_temperature
  ea <- switch(
    inputs$humidity,
    vapour_pressure = inputs$vapour_pressure,
    dewpoint_temperature = ef_ea_dewpoint(inputs$dewpoint_temperature),
    relative_humidity = ef_ea_rh(t_air, inputs$relative_humidity)
  )
  es <- ef_es(t_air)
  slope <- ef_es_slope(t_air)
  gamma <- ef_psychrometric(ef_air_pressure(st$elevation))
  u2 <- ef_wind_2m(inputs$wind_speed, st$height_wind)
  ra <- ef_ra_period(lat, lon, doy, utc_hour, 1, standard = standard)
  rso <- ef_rso(ra, st$elevation)
  # W m-2 (mean of the hour) to MJ m-2 h-1 (FAO-56 chapter 3, Table 3).
  rs <- inputs$solar_radiation * EF_SECONDS_PER_HOUR / 1e6

  masks <- list()
  rn <- rep(NA_real_, n)
  f <- rep(NA_real_, n)
  source <- rep(NA_character_, n)
  own <- rso > 0
  if (night_cloudiness == "low_sun") {
    # ASCE-EWRI (2005), Eqs. 46 and 62: own ratio only with a sun angle at
    # the mid-point above 0.3 rad.
    beta <- asin(ef_solar_geometry(doy, utc_hour, lat, lon)$cos_zenith)
    own <- own & beta > 0.3
  }
  day <- which(own)
  night <- which(!own)
  if (length(day) > 0L) {
    r <- ef_ref_net_radiation(rs[day], rso[day], ea[day],
                              air_temperature = t_air[day],
                              timestep = "hourly", standard = standard)
    rn[day] <- r$rn
    f[day] <- r$cloudiness
    source[day] <- "ratio"
    masks <- station_ref_add_masks(masks, r$flags,
                                   r$provenance$flags_evaluated, day, n)
  }
  if (length(night) > 0L) {
    if (night_cloudiness == "fixed") {
      f[night] <- 1.35 * night_ratio - 0.35
    } else {
      if (night_cloudiness == "low_sun") {
        qualifies <- own & !is.na(f)
      } else {
        omega <- ef_hour_angle(doy, utc_hour, lon)
        ws <- ef_sunset_hour_angle(lat, ef_declination(doy))
        qualifies <- rso > 0 & !is.na(f) & omega >= ws - 0.79 &
          omega <= ws - 0.52
      }
      f[night] <- station_ref_carry(f, qualifies, station_id, mid, night)
    }
    source[night] <- night_cloudiness
    r <- ef_ref_net_radiation(rs[night], NULL, ea[night],
                              air_temperature = t_air[night],
                              timestep = "hourly", standard = standard,
                              cloudiness = f[night])
    rn[night] <- r$rn
    masks <- station_ref_add_masks(masks, r$flags,
                                   r$provenance$flags_evaluated, night, n)
  }

  daytime <- if (daytime_rule == "ra_positive") ra > 0 else rn > 0
  g <- ef_ref_soil_heat_flux(rn, reference = reference, timestep = "hourly",
                             standard = standard, daytime = daytime)
  et <- ef_ref_et(rn, g, t_air, u2, es - ea, slope, gamma,
                  reference = reference, timestep = "hourly",
                  standard = standard, daytime = daytime)
  masks <- station_ref_add_masks(masks, et$flags,
                                 et$provenance$flags_evaluated, seq_len(n), n)
  list(
    table = data.frame(
      extraterrestrial_radiation = ra,
      clear_sky_radiation = rso,
      solar_radiation = rs,
      vapour_pressure = ea,
      vapour_pressure_deficit = es - ea,
      wind_speed_2m = u2,
      cloudiness = f,
      cloudiness_source = source,
      daytime = daytime,
      net_radiation = rn,
      soil_heat_flux = g,
      et_ref = et$et_ref,
      stringsAsFactors = FALSE
    ),
    flags = ef_flag_set(masks, scope = "record")
  )
}

#' Night-time cloudiness carried from an earlier period
#'
#' For each night-time (or low sun angle) record, the cloudiness term of the
#' last record of the same station whose mid-point is in the previous 24
#' hours and that qualifies (2-3 hours before sunset, FAO-56 chapter 4; or
#' sun angle above 0.3 rad, ASCE-EWRI 2005 Eq. 46). Within 24 hours before
#' a night-time instant there is a single sunset, so the qualifying records
#' found belong to the last afternoon.
#'
#' @param f Numeric cloudiness term of every record.
#' @param qualifies Logical, records that may be carried.
#' @param station_id Character station of every record.
#' @param mid POSIXct mid-points.
#' @param night Integer rows of the night-time records.
#' @return Numeric cloudiness term of the `night` records (`NA` if none).
#' @noRd
station_ref_carry <- function(f, qualifies, station_id, mid, night) {
  t <- as.numeric(mid)
  out <- rep(NA_real_, length(night))
  for (id in unique(station_id[night])) {
    q <- which(qualifies & station_id == id)
    if (length(q) == 0L) {
      next
    }
    q <- q[order(t[q])]
    sel <- which(station_id[night] == id)
    tn <- t[night[sel]]
    i <- findInterval(tn, t[q], left.open = TRUE)
    ok <- i > 0L
    ok[ok] <- t[q[i[ok]]] > tn[ok] - 24 * EF_SECONDS_PER_HOUR
    out[sel[ok]] <- f[q[i[ok]]]
  }
  out
}

#' Daily reference ET of daily records
#'
#' @inheritParams station_ref_hourly
#' @param date Date of each record (day definition).
#' @return As `station_ref_hourly()`.
#' @noRd
station_ref_daily <- function(inputs, st, date, reference, standard) {
  n <- length(date)
  lat <- st$lat * pi / 180
  doy <- as.POSIXlt(date)$yday + 1L
  tmax <- inputs$tmax
  tmin <- inputs$tmin
  tmean <- (tmax + tmin) / 2
  ea <- switch(
    inputs$humidity,
    vapour_pressure = inputs$vapour_pressure,
    dewpoint_temperature = ef_ea_dewpoint(inputs$dewpoint_temperature),
    relative_humidity = ef_ea_daily(tmin, tmax, inputs$rh_max, inputs$rh_min,
                                    method = "rhmax_rhmin")
  )
  # FAO-56, chapter 3, Eq. 12 (mean of e0 at Tmax and Tmin).
  es <- (ef_es(tmax) + ef_es(tmin)) / 2
  slope <- ef_es_slope(tmean)
  gamma <- ef_psychrometric(ef_air_pressure(st$elevation))
  u2 <- ef_wind_2m(inputs$wind_speed, st$height_wind)
  ra <- ef_ra_daily(lat, doy)
  rso <- ef_rso(ra, st$elevation)
  # Polar night: the cloudiness term is undefined.
  rso_used <- ifelse(rso > 0, rso, NA_real_)
  # W m-2 (24-hour mean) to MJ m-2 d-1 (FAO-56 chapter 3, Table 3).
  rs <- inputs$solar_radiation * 24 * EF_SECONDS_PER_HOUR / 1e6
  r <- ef_ref_net_radiation(rs, rso_used, ea, tmax = tmax, tmin = tmin,
                            timestep = "daily", standard = standard)
  g <- ef_ref_soil_heat_flux(r$rn, reference = reference, timestep = "daily",
                             standard = standard)
  et <- ef_ref_et(r$rn, g, tmean, u2, es - ea, slope, gamma,
                  reference = reference, timestep = "daily",
                  standard = standard)
  masks <- station_ref_add_masks(list(), r$flags,
                                 r$provenance$flags_evaluated, seq_len(n), n)
  masks <- station_ref_add_masks(masks, et$flags,
                                 et$provenance$flags_evaluated, seq_len(n), n)
  list(
    table = data.frame(
      extraterrestrial_radiation = ra,
      clear_sky_radiation = rso,
      solar_radiation = rs,
      vapour_pressure = ea,
      vapour_pressure_deficit = es - ea,
      wind_speed_2m = u2,
      cloudiness = r$cloudiness,
      cloudiness_source = "ratio",
      daytime = NA,
      net_radiation = r$rn,
      soil_heat_flux = g,
      et_ref = et$et_ref,
      stringsAsFactors = FALSE
    ),
    flags = ef_flag_set(masks, scope = "record")
  )
}

#' Instantaneous reference ET at the overpass times
#'
#' @param series The `series` table of `ef_station_ref_et()` (hourly).
#' @inheritParams ef_station_ref_et
#' @return A list with `table` (`station_id`, `overpass_time`, `etr_inst`,
#'   `method`) and `flags` (with attribute `evaluated`).
#' @noRd
station_ref_inst <- function(series, overpass, inst_method) {
  empty <- data.frame(
    station_id = character(0),
    overpass_time = structure(numeric(0), class = c("POSIXct", "POSIXt"),
                              tzone = "UTC"),
    etr_inst = numeric(0),
    method = character(0),
    stringsAsFactors = FALSE
  )
  if (is.null(overpass)) {
    return(list(table = empty, flags = ef_flag_set(list())))
  }
  overpass <- as.POSIXct(as.numeric(overpass), origin = "1970-01-01",
                         tz = "UTC")
  ids <- unique(series$station_id)
  half <- EF_SECONDS_PER_HOUR / 2
  tp <- as.numeric(overpass)
  rows <- lapply(ids, function(id) {
    s <- series[series$station_id == id, , drop = FALSE]
    tm <- as.numeric(s$target_time)
    o <- order(tm)
    tm <- tm[o]
    et <- s$et_ref[o]
    if (inst_method == "O1") {
      outside <- tp < tm[1L] - half | tp >= tm[length(tm)] + half
      # Period containing the time: start <= t < end.
      i <- findInterval(tp, tm - half)
      value <- rep(NA_real_, length(tp))
      hit <- !outside & i > 0L
      hit[hit] <- tp[hit] < tm[i[hit]] + half
      value[hit] <- et[i[hit]]
    } else {
      outside <- tp < tm[1L] | tp > tm[length(tm)]
      value <- rep(NA_real_, length(tp))
      if (length(tm) == 1L) {
        value[!outside] <- et[1L]
      } else {
        # No interpolation across a missing record: a missing node is
        # inserted after each step longer than one period.
        gap <- which(diff(tm) > 2 * half)
        nodes_t <- c(tm, tm[gap] + 2 * half)
        nodes_v <- c(et, rep(NA_real_, length(gap)))
        o2 <- order(nodes_t)
        if (any(!outside)) {
          value[!outside] <- ef_ref_et_inst_interp(nodes_v[o2], nodes_t[o2],
                                                   tp[!outside])
        }
      }
    }
    data.frame(station_id = id, overpass_time = overpass, etr_inst = value,
               method = inst_method, outside = outside,
               stringsAsFactors = FALSE)
  })
  table <- do.call(rbind, rows)
  rownames(table) <- NULL
  masks <- list(
    EF_WS_OVERPASS_OUTSIDE_RECORDS = table$outside,
    EF_INPUT_NA = !table$outside & is.na(table$etr_inst)
  )
  table$outside <- NULL
  list(table = table, flags = ef_flag_set(masks, scope = "record"))
}

#' Daily sums of the reference ET
#'
#' @param series The `series` table of `ef_station_ref_et()`.
#' @inheritParams ef_station_ref_et
#' @return A list with `table` (`station_id`, `date`, `n_periods`,
#'   `etr_24`) and `flags` (with attribute `evaluated`).
#' @noRd
station_ref_daily_sums <- function(series, dates, timestep) {
  periods <- if (timestep == "hourly") 24L else 1L
  ids <- unique(series$station_id)
  grid <- do.call(rbind, lapply(ids, function(id) {
    d <- if (is.null(dates)) {
      sort(unique(series$date[series$station_id == id]))
    } else {
      sort(unique(dates))
    }
    data.frame(station_id = rep(id, length(d)), date = d,
               stringsAsFactors = FALSE)
  }))
  key_s <- paste(series$station_id, format(series$date))
  key_g <- paste(grid$station_id, format(grid$date))
  # Option D1 (hourly) or the daily record (daily): NA unless the day has
  # exactly its periods, all valid.
  sums <- ef_ref_et_daily_sum(series$et_ref, key_s, periods)
  etr_24 <- unname(sums[key_g])
  n_valid <- tapply(!is.na(series$et_ref), factor(key_s, levels = key_g),
                    sum)
  n_valid[is.na(n_valid)] <- 0L
  table <- data.frame(
    station_id = grid$station_id,
    date = grid$date,
    n_periods = as.integer(n_valid),
    etr_24 = as.double(etr_24),
    stringsAsFactors = FALSE
  )
  rownames(table) <- NULL
  list(
    table = table,
    flags = ef_flag_set(list(EF_WS_INCOMPLETE_DAY = is.na(table$etr_24)),
                        scope = "record")
  )
}

#' @export
print.earthflux_station_ref_et <- function(x, ...) {
  cat("<earthflux_station_ref_et>\n")
  cat(sprintf("Reference: %s; time step: %s; standard: %s (%s)\n",
              x$reference, x$timestep, x$standard, x$provenance$status))
  cat(sprintf("Series: %d record(s) at %d station(s); %d missing value(s)\n",
              nrow(x$series), length(unique(x$series$station_id)),
              sum(is.na(x$series$et_ref))))
  cat(sprintf("etr_inst: %d row(s) (%s); etr_24: %d day(s), %d complete\n",
              nrow(x$etr_inst),
              if (is.null(x$provenance$choices$inst_method)) "no overpass"
              else x$provenance$choices$inst_method,
              nrow(x$etr_24), sum(!is.na(x$etr_24$etr_24))))
  codes <- vapply(x$flags, function(f) {
    sprintf("%s (%s, %d)", f$code, f$target, f$n_flagged)
  }, character(1))
  cat("Flags:", if (length(codes) == 0L) "none" else
    paste(codes, collapse = "; "), "\n")
  invisible(x)
}
