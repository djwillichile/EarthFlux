# Preprocessing: quality control of station data -------------------------------
#
# Purpose: quality control (QC) of the standard station table
# (dev/specs/weather-forcing.md section 3; dev/specs/flags.md sections 4.2,
# 5.3, 6.1, 6.6 and 6.7). QC marks records; it never deletes or modifies
# values:
#   - every condition that holds produces rows in the long audit table `$qc`
#     (one row per record, variable and code) and an `earthflux_flag` record
#     of scope `record` whose `index` is the set of rows of `observations`
#     (the two views are equivalent: dev/specs/flags.md test R16, FL-13);
#   - class III impossibilities are flags of severity `critical`, excluded
#     by the default policy `qc_policy = "exclude_critical"`; exclusion is a
#     status (`$qc_status`), never a deletion, and its counts are recorded in
#     the provenance (dev/specs/flags.md section 6.6);
#   - class II tests (they need a threshold with a documented reference)
#     are not evaluated and their codes are not registered (guard vector of
#     tests/testthat/test-diagnostics.R); they are listed as "not evaluated"
#     in the provenance.
#
# Contents:
#   ef_station_qc()          exported QC procedure (class
#                            earthflux_station_qc, inheriting
#                            earthflux_station_table)
#   ef_flags_stations()      registry rows of the EF_WS_ codes raised here
#                            (wired into ef_flag_registry())
#   QC tests, status by policy, provenance, validator of the QC result,
#   print method of earthflux_station_qc.

# Registry rows ----------------------------------------------------------------

#' Flag codes owned by the station quality control
#'
#' Codes of stage `WS` raised by `ef_station_qc()` (dev/specs/flags.md
#' section 4.2, `EF_WS_`; conditions of dev/specs/weather-forcing.md section
#' 3.2). All have the `record` scope (rows of `observations`) and no bit.
#' Class III codes (`EF_WS_OUT_OF_DOMAIN`, `EF_WS_TMIN_GT_TMAX`) are
#' `critical` with their error counterpart of the numeric core. The codes of
#' the reference ET at the stations (`EF_WS_RS_RSO_LIMITED`,
#' `EF_WS_ETR_NEGATIVE`, `EF_WS_INCOMPLETE_DAY`,
#' `EF_WS_OVERPASS_OUTSIDE_RECORDS`) are registered by
#' `ef_flags_reference_et()` (`R/reference-et.R`).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_stations <- function() {
  spec <- "dev/specs/weather-forcing.md 3.2; dev/specs/flags.md 4.2"
  ef_flag_rows(
    code = c(
      "EF_WS_OUT_OF_DOMAIN",
      "EF_WS_TMIN_GT_TMAX",
      "EF_WS_RH_GT100",
      "EF_WS_TDEW_GT_TAIR",
      "EF_WS_RS_GT_RA",
      "EF_WS_TIME_GAP",
      "EF_WS_TIME_IRREGULAR",
      "EF_WS_HEIGHT_MISSING",
      "EF_WS_HEIGHT_NONSTANDARD"
    ),
    stage = rep("WS", 9L),
    severity = c("critical", "critical", "info", "warning", "warning",
                 "warning", "warning", "warning", "warning"),
    scope = rep("record", 9L),
    bit = rep(NA_integer_, 9L),
    error_class = c("earthflux_domain_error", "earthflux_domain_error",
                    rep(NA_character_, 7L)),
    description = c(
      "An observed value is physically impossible and is excluded by the default quality control policy.",
      "The daily minimum air temperature is greater than the daily maximum.",
      "The relative humidity is greater than 100 percent.",
      "The dew point temperature is greater than the air temperature, or the vapour pressure is greater than the saturation vapour pressure at the air temperature.",
      "The mean solar radiation of the record is greater than the mean extraterrestrial radiation of its time window.",
      "The record follows a gap of one or more missing time steps.",
      "The time since the previous record is not a whole number of time steps.",
      "The measurement height of the variable is unknown.",
      "The temperature and humidity sensors are not at the standard height of 2 m."
    ),
    spec = rep(spec, 9L),
    since = rep("0.0.0.9000", 9L)
  )
}

# QC definitions ---------------------------------------------------------------

#' Quality control policies
#'
#' dev/specs/weather-forcing.md section 3.1 and dev/specs/flags.md section
#' 5.3: `"exclude_critical"` (default) excludes the values with a critical
#' flag; `"exclude_warning"` also those with a warning flag; `"keep_all"`
#' excludes nothing (audit; the numeric core still rejects impossible
#' values with an error).
#'
#' @return A character vector.
#' @noRd
station_qc_policies <- function() {
  c("exclude_critical", "exclude_warning", "keep_all")
}

#' Lowest numeric severity excluded by a policy
#'
#' @param qc_policy One of `station_qc_policies()`.
#' @return An integer (4 means nothing is excluded).
#' @noRd
station_qc_exclusion_level <- function(qc_policy) {
  switch(qc_policy, exclude_critical = 3L, exclude_warning = 2L,
         keep_all = 4L)
}

#' Physical domain of the observed variables (test QC-01a)
#'
#' Physically impossible values by definition (dev/specs/weather-forcing.md
#' section 3.2, QC-01a; class III in dev/specs/flags.md section 4.2):
#' relative humidity below 0 %, wind speed below 0, temperature at or below
#' absolute zero (-273.15 degC), air pressure at or below 0. The same
#' definitions apply to the daily fields (`rh_max`, `rh_min`, `tmax`,
#' `tmin`), to the dew point temperature and to the vapour pressure (below
#' 0), and to the global solar radiation and the precipitation (below 0: an
#' irradiance on a horizontal surface and a depth of water are not
#' negative). No plausibility limit is applied (class II, QC-01b).
#'
#' @return A data frame with columns `variable`, `strict` (`TRUE`: the
#'   condition is `value < bound`; `FALSE`: `value <= bound`) and `bound`.
#' @noRd
station_domain_rules <- function() {
  absolute_zero <- -EF_KELVIN_OFFSET
  data.frame(
    variable = c("relative_humidity", "rh_max", "rh_min", "wind_speed",
                 "air_temperature", "dewpoint_temperature", "tmax", "tmin",
                 "air_pressure", "vapour_pressure", "solar_radiation",
                 "precipitation"),
    strict = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
               TRUE, TRUE, TRUE),
    bound = c(0, 0, 0, 0, absolute_zero, absolute_zero, absolute_zero,
              absolute_zero, 0, 0, 0, 0),
    stringsAsFactors = FALSE
  )
}

#' Standard measurement height of air temperature and humidity
#'
#' FAO-56 (Allen et al., 1998, chapters 2 and 3): the reference equations
#' assume temperature and humidity measured at 2 m above the ground
#' (dev/specs/weather-forcing.md section 2.2 and QC-11; VERIFICADA as a
#' criterion). A different height is flagged; no correction is applied.
#'
#' @return A numeric scalar \[m\].
#' @noRd
station_standard_height <- function() {
  2
}

#' Station QC tests that are not evaluated
#'
#' Class II tests (dev/specs/flags.md section 4.1: they need a threshold
#' with a documented reference, not available) and the class I test of
#' complete days (QC-10), which is evaluated by the daily sums of
#' `ef_station_ref_et()` because it depends on the definition of the day
#' (decision WF-11). When `x` is given, `EF_WS_RS_GT_RA` (QC-05b) is added
#' if the table has solar radiation that cannot be tested (instantaneous
#' values or periods longer than one day).
#'
#' @param x An `earthflux_station_table` or `NULL`.
#' @return A data frame with columns `code`, `test_id` and `reason`.
#' @noRd
station_qc_not_evaluated <- function(x = NULL) {
  class_ii <- "class II: needs a threshold with a documented reference (dev/specs/flags.md 7)"
  out <- data.frame(
    code = c("EF_WS_IMPLAUSIBLE", "EF_WS_RH_RECALIBRATE", "EF_WS_RS_GT_RSO",
             "EF_WS_RS_CALIBRATION", "EF_WS_RS_NIGHT",
             "EF_WS_PERSISTENCE", "EF_WS_STEP", "EF_WS_RHMAX_LOW",
             "EF_WS_NONREFERENCE", "EF_WS_EA_DIURNAL", "EF_WS_TIME_SHIFT",
             "EF_WS_INCOMPLETE_DAY", "EF_WS_SPATIAL_OUTLIER",
             "EF_WS_CLOUDY_OVERPASS"),
    test_id = c("QC-01b", "QC-02", "QC-05a", "QC-05c", "QC-05d",
                "QC-06", "QC-07", "QC-08a", "QC-08b", "QC-08c", "QC-09",
                "QC-10", "QC-12", "QC-13"),
    reason = c(
      class_ii,
      paste(class_ii, "(margin in [3, 5] %, WF-06)"),
      class_ii, class_ii, class_ii, class_ii, class_ii,
      paste(class_ii, "(value in [80, 90] % and window, WF-06)"),
      class_ii, class_ii, class_ii,
      "class I: evaluated by ef_station_ref_et() on the daily sums (definition of the day, WF-11)",
      class_ii, class_ii
    ),
    stringsAsFactors = FALSE
  )
  if (!is.null(x) && "solar_radiation" %in% names(x$observations) &&
      !station_rs_ra_testable(x$provenance)) {
    out <- rbind(out, data.frame(
      code = "EF_WS_RS_GT_RA", test_id = "QC-05b",
      reason = "class I: needs period means of at most one day (instantaneous values or longer periods)",
      stringsAsFactors = FALSE
    ))
  }
  out
}

#' Whether the solar radiation of a table can be compared with Ra
#'
#' QC-05b compares period means: it needs `timestamp_convention` `"end"` or
#' `"start"` and an `interval` of at most one day.
#'
#' @param provenance The provenance of a station table.
#' @return A logical scalar.
#' @noRd
station_rs_ra_testable <- function(provenance) {
  provenance$timestamp_convention %in% c("end", "start") &&
    provenance$interval <= 24 * EF_SECONDS_PER_HOUR
}

#' Mid-points of the averaging periods of the records
#'
#' `timestamp - interval / 2` for `"end"`, `timestamp + interval / 2` for
#' `"start"`, the timestamp itself for `"instant"`
#' (dev/specs/weather-forcing.md section 2.4).
#'
#' @param timestamp POSIXct (UTC).
#' @param provenance The provenance of a station table.
#' @return POSIXct (UTC).
#' @noRd
station_period_mid <- function(timestamp, provenance) {
  timestamp + switch(provenance$timestamp_convention,
                     end = -provenance$interval / 2,
                     start = provenance$interval / 2,
                     instant = 0)
}

#' Extraterrestrial radiation of the time window of a record
#'
#' Integral of the extraterrestrial radiation on a horizontal surface over
#' the window of `period_seconds` centred on `mid` (test QC-05b), with the
#' form of FAO-56 Eq. 28 (chapter 3) and the limits of integration restricted
#' to the part of the window with the sun above the horizon
#' (\eqn{-\omega_s \le \omega \le \omega_s}, Eq. 25), which makes it the
#' exact integral of the positive extraterrestrial irradiance for any window
#' up to 24 h (for a 24 h window it equals FAO-56 Eq. 21). Declination and
#' inverse relative distance are those of the day of the mid-point (Eqs. 23
#' and 24), the hour angle that of the mid-point in UTC (Eq. 31 through
#' `ef_hour_angle()`). The midpoint criterion of
#' `ef_ra_period(standard = "fao56")` (Ra = 0 when the sun is below the
#' horizon at the mid-point) is not used here: at sunrise and sunset it
#' would underestimate the window and flag valid records. For windows of
#' up to 1 h this integral equals `ef_ra_period(standard = "asce")`
#' (limits of ASCE-EWRI 2005 Eq. 56).
#'
#' @param lat,lon Numeric latitude and east-positive longitude \[rad\].
#' @param mid POSIXct mid-points of the windows (UTC).
#' @param period_seconds Numeric scalar length of the windows \[s\], in
#'   (0, 86400\].
#' @return Numeric extraterrestrial radiation of each window \[MJ m-2\].
#' @section Verification status: `VERIFICADA` as the integral of FAO-56
#'   Eqs. 21-33 (the restriction of the limits is the definition of the
#'   integral of the positive irradiance, not a method choice).
#' @noRd
station_ra_window <- function(lat, lon, mid, period_seconds) {
  t <- as.POSIXlt(mid, tz = "UTC")
  doy <- t$yday + 1L
  utc_hour <- t$hour + t$min / 60 + t$sec / EF_SECONDS_PER_HOUR
  dr <- ef_inv_distance(doy)
  delta <- ef_declination(doy)
  omega <- ef_hour_angle(doy, utc_hour, lon)
  ws <- ef_sunset_hour_angle(lat, delta)
  half <- pi * period_seconds / (24 * EF_SECONDS_PER_HOUR)
  sunlit <- function(a, b) {
    lo <- pmax(a, -ws)
    hi <- pmin(b, ws)
    ifelse(hi > lo,
           (hi - lo) * sin(lat) * sin(delta) +
             cos(lat) * cos(delta) * (sin(hi) - sin(lo)),
           0)
  }
  w1 <- omega - half
  w2 <- omega + half
  # The window may cross omega = +-pi (around midnight): its parts shifted
  # by one turn are added.
  gsc <- EF_SOLAR_CONSTANT * 60 / 1e6 # W m-2 to MJ m-2 min-1 (0.0820)
  # FAO-56, chapter 3, Eq. 28 with sunlit limits.
  12 * 60 / pi * gsc * dr *
    (sunlit(w1, w2) + sunlit(w1 - 2 * pi, w2 - 2 * pi) +
       sunlit(w1 + 2 * pi, w2 + 2 * pi))
}

#' Zero-row audit table of the station QC
#'
#' @return A data frame with columns `row` (integer, row of
#'   `observations`), `station_id`, `timestamp` (POSIXct UTC), `variable`,
#'   `flag_code`, `severity`, `test_id`, `value`, `threshold` (double) and
#'   `parameters` (character).
#' @noRd
station_qc_template <- function() {
  data.frame(
    row = integer(0),
    station_id = character(0),
    timestamp = structure(numeric(0), class = c("POSIXct", "POSIXt"),
                          tzone = "UTC"),
    variable = character(0),
    flag_code = character(0),
    severity = character(0),
    test_id = character(0),
    value = numeric(0),
    threshold = numeric(0),
    parameters = character(0),
    stringsAsFactors = FALSE
  )
}

# Procedure --------------------------------------------------------------------

#' Quality control of the standard station table
#'
#' @description
#' Runs the quality control tests of the station data
#' (dev/specs/weather-forcing.md section 3) on an
#' `earthflux_station_table` and returns the table with the audit of every
#' condition found, the diagnostic flag records and the status of each
#' observed value under an explicit QC policy. Values are **never** deleted
#' or modified: `observations` is returned unchanged.
#'
#' @param x An `earthflux_station_table` built with [ef_station_table()]
#'   (or the result of a previous `ef_station_qc()`, which is recomputed).
#' @param qc_policy Character. Which flagged values are excluded:
#'   `"exclude_critical"` (default; the values with a `critical` flag, i.e.
#'   physical or logical impossibilities), `"exclude_warning"` (values with
#'   a `critical` or `warning` flag) or `"keep_all"` (no exclusion; for
#'   audit). Exact match.
#'
#' @return An object of class
#'   `c("earthflux_station_qc", "earthflux_station_table", "list")`: the
#'   elements of `x` (`stations` and `observations` unchanged) plus
#'   * `qc`: the long audit table, one row per record, variable and flag
#'     code that holds, with columns `row` (row of `observations`),
#'     `station_id`, `timestamp` (UTC), `variable` (the observed variable,
#'     or `"timestamp"` for the time tests), `flag_code` (a registered code),
#'     `severity`, `test_id` (test of dev/specs/weather-forcing.md section
#'     3.2), `value` (the value tested: the variable, the height, or the
#'     seconds since the previous record), `threshold` (the bound it was
#'     compared with: a domain limit, 100 %, the other variable of a
#'     consistency test, the standard height or the time step; `NA` if
#'     none) and `parameters` (`NA`: no class II parameter is used);
#'   * `flags`: one `earthflux_flag` record (scope `record`, `index` = rows
#'     of `observations`, `n_total` = number of records) per code that
#'     holds somewhere; the rows of `qc` with that code are exactly its
#'     `index`;
#'   * `qc_status`: a data frame with `station_id`, `timestamp` and one
#'     factor column per observed variable (levels `"ok"`, `"warning"`,
#'     `"excluded"`), aligned with the rows of `observations`;
#'   * `provenance`: the provenance of `x` with `flags_evaluated` (codes
#'     evaluated), `flags` (registry rows of the codes evaluated, policy and
#'     counts; dev/specs/flags.md section 6.7), `qc` (policy, counts by
#'     code, values excluded by variable, tests not evaluated) and a new
#'     row in `operations`.
#'
#' @details
#' Tests evaluated (codes registered in the flag registry; severity in
#' brackets):
#' * `EF_WS_OUT_OF_DOMAIN` \[critical\] (QC-01a): physically impossible
#'   value: relative humidity (`relative_humidity`, `rh_max`, `rh_min`)
#'   `< 0`, `wind_speed < 0`, temperature (`air_temperature`,
#'   `dewpoint_temperature`, `tmax`, `tmin`) `<= -273.15` degC,
#'   `air_pressure <= 0`, `vapour_pressure < 0`, `solar_radiation < 0`,
#'   `precipitation < 0`. A negative solar radiation (for example the
#'   night-time offset of a thermopile pyranometer) is excluded by the
#'   default policy; it is not set to zero.
#' * `EF_WS_TMIN_GT_TMAX` \[critical\] (QC-03): `tmin > tmax` in the same
#'   record; both variables are flagged.
#' * `EF_WS_RH_GT100` \[info\] (QC-02): relative humidity `> 100` %.
#'   Values slightly above 100 % occur (e.g. early morning or rain); FAO-56
#'   Annex 5 relates records exceeding 100 % by more than 3-5 % to a need of
#'   recalibration, a class II test not evaluated until its margin is chosen
#'   (WF-06).
#' * `EF_WS_TDEW_GT_TAIR` \[warning\] (QC-04): `dewpoint_temperature >
#'   air_temperature`, or `vapour_pressure` greater than the saturation
#'   vapour pressure at `air_temperature` (\eqn{e_a > e^\circ(T)}{ea >
#'   e0(T)}, [ef_es()]), without tolerance (both are equivalent to a relative
#'   humidity above 100 %, FAO-56 Eqs. 10, 11 and 14); the variables
#'   compared are flagged (the air temperature once per record). The
#'   threshold is the air temperature for the dew point, \eqn{e^\circ(T)}{e0(T)}
#'   for the vapour pressure and the dew point of the vapour pressure
#'   ([ef_dewpoint()]) for the air temperature.
#' * `EF_WS_RS_GT_RA` \[warning\] (QC-05b): the mean `solar_radiation` of
#'   the record is greater than the mean extraterrestrial radiation of the
#'   same time window (the window of `interval` seconds of the record,
#'   located by `timestamp_convention`). The extraterrestrial radiation is
#'   the integral of FAO-56 Eq. 28 over the part of the window with the sun
#'   above the horizon (for a one-day window, Eq. 21). Windows with the sun
#'   below the horizon during the whole window (night-time radiation, test
#'   QC-05d, class II) are not tested. Evaluated for period means
#'   (`timestamp_convention` `"end"` or `"start"`) with an `interval` of at
#'   most one day.
#' * `EF_WS_TIME_GAP` \[warning\] and `EF_WS_TIME_IRREGULAR` \[warning\]
#'   (QC-09), per station in time order: the time since the previous record
#'   is a whole multiple (two or more) of the declared `interval` (gap: the
#'   record after the gap is flagged), or not a whole multiple (irregular
#'   step); variable `"timestamp"`. Missing time steps are never filled.
#' * `EF_WS_HEIGHT_MISSING` \[warning\] and `EF_WS_HEIGHT_NONSTANDARD`
#'   \[warning\] (QC-11): a non-missing value whose measurement height is
#'   `NA` (`height_wind` for `wind_speed`; `height_temp_rh` for temperature
#'   and humidity variables), or temperature and humidity measured at a
#'   height different from 2 m (FAO-56 chapters 2-3); no correction is
#'   applied.
#'
#' A code is evaluated only when the variables it needs are present; the
#' codes evaluated are listed in `provenance$flags_evaluated`, so that
#' "evaluated and absent" is distinguishable from "not evaluated".
#'
#' Not evaluated: the class II tests of dev/specs/weather-forcing.md
#' section 3.2 (plausible ranges, recalibration margin of the humidity
#' sensor, clear-sky envelope and calibration of the pyranometer, night
#' radiation, persistence, steps, low maximum humidity, non-reference
#' conditions, diurnal stability of the vapour pressure, time shift,
#' spatial consistency, cloudy overpass): they need thresholds with a
#' documented reference that are not available, so their codes are not
#' registered and no threshold is assumed. Also not evaluated here:
#' `EF_WS_INCOMPLETE_DAY` (QC-10), which depends on the definition of the
#' day and is raised by the daily sums of [ef_station_ref_et()]. They are
#' listed in `provenance$qc$not_evaluated` (with `EF_WS_RS_GT_RA` when the
#' table has solar radiation that cannot be tested).
#'
#' **Status and policy.** The status of an observed value is the highest
#' severity among the flags of its record that concern its variable or the
#' timestamp: `"excluded"` if that severity is excluded by `qc_policy`,
#' `"warning"` if it is `warning` (or `critical` under `"keep_all"`), and
#' `"ok"` otherwise (no flag or `info`). Missing values keep the status of
#' their record. Excluding is not deleting: `observations` keeps the value
#' and the flag that motivated the exclusion is kept; the counts are in
#' `provenance$qc`.
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration - Guidelines for computing crop water requirements*.
#' FAO Irrigation and Drainage Paper 56. FAO, Rome. ISBN 92-5-104219-5.
#'
#' @seealso [ef_station_table()], [ef_station_ref_et()].
#'
#' @examples
#' stations <- data.frame(
#'   station_id = "ST01", lon = -71.5, lat = -35.4, elevation = 150,
#'   height_wind = 2, height_temp_rh = 2
#' )
#' times <- as.POSIXct("2024-01-15 13:00", tz = "UTC") + 3600 * c(0, 1, 3)
#' observations <- data.frame(
#'   station_id = "ST01", timestamp = times,
#'   air_temperature = c(24.1, 25.3, 26.0),
#'   relative_humidity = c(45, -3, 101),
#'   wind_speed = c(2.1, 2.6, 3.0)
#' )
#' st <- ef_station_table(
#'   stations, observations,
#'   provenance = list(timestamp_convention = "end", interval = 3600,
#'                     crs = "EPSG:4326")
#' )
#' qc <- ef_station_qc(st)
#' qc
#' qc$qc
#' qc$qc_status
#' @export
ef_station_qc <- function(x, qc_policy = "exclude_critical") {
  call <- sys.call()
  if (!inherits(x, "earthflux_station_table")) {
    station_abort("`x` must be an `earthflux_station_table` (see ef_station_table()).",
                  call = call)
  }
  check_method(qc_policy, station_qc_policies(), arg = "qc_policy",
               call = call)
  ef_validate_stations(x, call = call)

  obs <- x$observations
  n <- nrow(obs)
  vars <- station_measured_vars(obs)
  tests <- station_qc_tests(x)
  qc <- tests$qc

  masks <- stats::setNames(
    lapply(tests$evaluated, function(code) {
      seq_len(n) %in% qc$row[qc$flag_code == code]
    }),
    tests$evaluated
  )
  flags <- ef_flags_combine(ef_flag_set(masks, scope = "record"))
  status <- station_qc_status(obs, qc, vars, qc_policy)

  prov <- x$provenance
  prov$flags_evaluated <- flags$evaluated
  prov$qc <- station_qc_provenance(qc, flags$flags, tests$evaluated, status,
                                   vars, qc_policy, n,
                                   station_qc_not_evaluated(x))
  prov$flags <- list(
    registry = {
      reg <- ef_flag_registry()
      reg[reg$code %in% flags$evaluated, , drop = FALSE]
    },
    evaluated = flags$evaluated,
    policies = list(
      qc_policy = qc_policy,
      excluded_codes = prov$qc$excluded_codes,
      counts = prov$qc$excluded
    ),
    counts = data.frame(code = prov$qc$counts$code,
                        n_flagged = prov$qc$counts$n_records,
                        n_total = prov$qc$counts$n_total,
                        stringsAsFactors = FALSE)
  )
  n_excluded <- sum(prov$qc$excluded$n_excluded)
  prov$operations <- rbind(
    prov$operations,
    data.frame(
      step = "ef_station_qc",
      detail = sprintf(
        "qc_policy = \"%s\"; %d code(s) evaluated, %d raised; %d value(s) excluded",
        qc_policy, length(flags$evaluated), length(flags$flags), n_excluded
      ),
      stringsAsFactors = FALSE
    )
  )

  out <- new_ef_object(
    list(
      stations = x$stations,
      observations = obs,
      provenance = prov,
      qc = qc,
      qc_status = status,
      flags = flags$flags
    ),
    c("earthflux_station_qc", "earthflux_station_table")
  )
  ef_validate_stations(out, call = call)
  out
}

# Tests ------------------------------------------------------------------------

#' Rows of the audit table for one condition
#'
#' @param row Integer rows of `observations` where the condition holds.
#' @param variable Character (length 1 or `length(row)`).
#' @param code,test_id Character scalars.
#' @param value,threshold Numeric (length 1 or `length(row)`).
#' @return A data frame with columns `row`, `variable`, `flag_code`,
#'   `test_id`, `value`, `threshold`.
#' @noRd
station_qc_chunk <- function(row, variable, code, test_id, value, threshold) {
  n <- length(row)
  data.frame(
    row = as.integer(row),
    variable = rep_len(as.character(variable), n),
    flag_code = rep_len(code, n),
    test_id = rep_len(test_id, n),
    value = rep_len(as.double(value), n),
    threshold = rep_len(as.double(threshold), n),
    stringsAsFactors = FALSE
  )
}

#' Evaluate the QC tests of a station table
#'
#' @param x A valid `earthflux_station_table`.
#' @return A list with `qc` (the complete audit table, ordered by row and
#'   registry order of the codes) and `evaluated` (codes evaluated, in
#'   registry order).
#' @noRd
station_qc_tests <- function(x) {
  obs <- x$observations
  stations <- x$stations
  vars <- station_measured_vars(obs)
  chunks <- list()
  evaluated <- character(0)
  add <- function(chunk) chunks[[length(chunks) + 1L]] <<- chunk

  # QC-01a: physical domain (class III).
  rules <- station_domain_rules()
  rules <- rules[rules$variable %in% vars, , drop = FALSE]
  if (nrow(rules) > 0L) {
    evaluated <- c(evaluated, "EF_WS_OUT_OF_DOMAIN")
    for (i in seq_len(nrow(rules))) {
      v <- obs[[rules$variable[i]]]
      hit <- !is.na(v) &
        (if (rules$strict[i]) v < rules$bound[i] else v <= rules$bound[i])
      rows <- which(hit)
      add(station_qc_chunk(rows, rules$variable[i], "EF_WS_OUT_OF_DOMAIN",
                           "QC-01a", v[rows], rules$bound[i]))
    }
  }

  # QC-03: tmin > tmax (class III).
  if (all(c("tmin", "tmax") %in% vars)) {
    evaluated <- c(evaluated, "EF_WS_TMIN_GT_TMAX")
    rows <- which(!is.na(obs$tmin) & !is.na(obs$tmax) & obs$tmin > obs$tmax)
    add(station_qc_chunk(rows, "tmin", "EF_WS_TMIN_GT_TMAX", "QC-03",
                         obs$tmin[rows], obs$tmax[rows]))
    add(station_qc_chunk(rows, "tmax", "EF_WS_TMIN_GT_TMAX", "QC-03",
                         obs$tmax[rows], obs$tmin[rows]))
  }

  # QC-02: relative humidity above 100 % (class I).
  rh_vars <- intersect(c("relative_humidity", "rh_max", "rh_min"), vars)
  if (length(rh_vars) > 0L) {
    evaluated <- c(evaluated, "EF_WS_RH_GT100")
    for (v in rh_vars) {
      rows <- which(!is.na(obs[[v]]) & obs[[v]] > 100)
      add(station_qc_chunk(rows, v, "EF_WS_RH_GT100", "QC-02",
                           obs[[v]][rows], 100))
    }
  }

  # QC-04: dew point above air temperature (class I, no tolerance).
  if (all(c("dewpoint_temperature", "air_temperature") %in% vars)) {
    evaluated <- c(evaluated, "EF_WS_TDEW_GT_TAIR")
    td <- obs$dewpoint_temperature
    ta <- obs$air_temperature
    rows <- which(!is.na(td) & !is.na(ta) & td > ta)
    add(station_qc_chunk(rows, "dewpoint_temperature", "EF_WS_TDEW_GT_TAIR",
                         "QC-04", td[rows], ta[rows]))
    add(station_qc_chunk(rows, "air_temperature", "EF_WS_TDEW_GT_TAIR",
                         "QC-04", ta[rows], td[rows]))
  }

  # QC-04, vapour pressure variant: ea > e0(T) (class I, no tolerance; FAO-56
  # Eqs. 11 and 14). T must be in the domain of Eq. 11 (T > -237.3 degC).
  if (all(c("vapour_pressure", "air_temperature") %in% vars)) {
    evaluated <- c(evaluated, "EF_WS_TDEW_GT_TAIR")
    ea <- obs$vapour_pressure
    ta <- obs$air_temperature
    ok <- !is.na(ea) & !is.na(ta) & ta > -237.3
    es <- rep(NA_real_, length(ta))
    if (any(ok)) {
      es[ok] <- ef_es(ta[ok])
    }
    rows <- which(ok & ea > es)
    add(station_qc_chunk(rows, "vapour_pressure", "EF_WS_TDEW_GT_TAIR",
                         "QC-04", ea[rows], es[rows]))
    # The air temperature is flagged once per record: rows already flagged by
    # the dew point variant are not repeated. Threshold: the dew point of ea
    # (FAO-56 annex 3, Eq. 3-11).
    done <- rows %in% unlist(lapply(chunks, function(ch) {
      ch$row[ch$flag_code == "EF_WS_TDEW_GT_TAIR" &
               ch$variable == "air_temperature"]
    }))
    rows_t <- rows[!done]
    add(station_qc_chunk(rows_t, "air_temperature", "EF_WS_TDEW_GT_TAIR",
                         "QC-04", ta[rows_t],
                         if (length(rows_t) > 0L) ef_dewpoint(ea[rows_t]) else
                           numeric(0)))
  }

  # QC-05b: mean solar radiation above the mean extraterrestrial radiation of
  # the record window (class I). Windows with Ra = 0 (sun below the horizon
  # during the whole window) belong to QC-05d (class II, not evaluated).
  if ("solar_radiation" %in% vars && station_rs_ra_testable(x$provenance)) {
    evaluated <- c(evaluated, "EF_WS_RS_GT_RA")
    at <- match(obs$station_id, stations$station_id)
    period <- x$provenance$interval
    ra <- station_ra_window(stations$lat[at] * pi / 180,
                            stations$lon[at] * pi / 180,
                            station_period_mid(obs$timestamp, x$provenance),
                            period)
    # MJ m-2 per window to mean W m-2.
    ra_mean <- ra * 1e6 / period
    rs <- obs$solar_radiation
    rows <- which(!is.na(rs) & ra_mean > 0 & rs > ra_mean)
    add(station_qc_chunk(rows, "solar_radiation", "EF_WS_RS_GT_RA", "QC-05b",
                         rs[rows], ra_mean[rows]))
  }

  # QC-09: time integrity per station (class I).
  evaluated <- c(evaluated, "EF_WS_TIME_GAP", "EF_WS_TIME_IRREGULAR")
  time <- station_time_steps(obs, x$provenance$interval)
  add(station_qc_chunk(time$row[time$gap], "timestamp", "EF_WS_TIME_GAP",
                       "QC-09", time$step[time$gap], x$provenance$interval))
  add(station_qc_chunk(time$row[time$irregular], "timestamp",
                       "EF_WS_TIME_IRREGULAR", "QC-09",
                       time$step[time$irregular], x$provenance$interval))

  # QC-11: measurement heights (class I).
  defs <- station_variables()
  height_vars <- defs[defs$variable %in% vars & !is.na(defs$height), ,
                      drop = FALSE]
  if (nrow(height_vars) > 0L) {
    evaluated <- c(evaluated, "EF_WS_HEIGHT_MISSING")
    at <- match(obs$station_id, stations$station_id)
    for (i in seq_len(nrow(height_vars))) {
      v <- height_vars$variable[i]
      h <- stations[[height_vars$height[i]]][at]
      rows <- which(!is.na(obs[[v]]) & is.na(h))
      add(station_qc_chunk(rows, v, "EF_WS_HEIGHT_MISSING", "QC-11", NA, NA))
    }
    temp_rh <- height_vars$variable[height_vars$height == "height_temp_rh"]
    if (length(temp_rh) > 0L) {
      evaluated <- c(evaluated, "EF_WS_HEIGHT_NONSTANDARD")
      h <- stations$height_temp_rh[at]
      std <- station_standard_height()
      for (v in temp_rh) {
        rows <- which(!is.na(obs[[v]]) & !is.na(h) & h != std)
        add(station_qc_chunk(rows, v, "EF_WS_HEIGHT_NONSTANDARD", "QC-11",
                             h[rows], std))
      }
    }
  }

  qc_core <- do.call(rbind, c(list(station_qc_chunk(integer(0), character(0),
                                                    character(0),
                                                    character(0),
                                                    numeric(0), numeric(0))),
                              chunks))
  reg <- ef_flag_registry()
  order_codes <- reg$code[reg$code %in% evaluated]
  qc_core <- qc_core[order(qc_core$row,
                           match(qc_core$flag_code, order_codes)), ,
                     drop = FALSE]
  qc <- station_qc_template()
  if (nrow(qc_core) > 0L) {
    qc <- data.frame(
      row = qc_core$row,
      station_id = obs$station_id[qc_core$row],
      timestamp = obs$timestamp[qc_core$row],
      variable = qc_core$variable,
      flag_code = qc_core$flag_code,
      severity = reg$severity[match(qc_core$flag_code, reg$code)],
      test_id = qc_core$test_id,
      value = qc_core$value,
      threshold = qc_core$threshold,
      parameters = NA_character_,
      stringsAsFactors = FALSE
    )
  }
  rownames(qc) <- NULL
  list(qc = qc, evaluated = order_codes)
}

#' Time steps between consecutive records of each station
#'
#' @param obs Data frame of observations (UTC timestamps).
#' @param interval Numeric. Declared time step \[s\].
#' @return A data frame with one row per record that has a previous record
#'   at its station: `row` (row of `obs`), `step` (seconds since the
#'   previous record), `gap` (step is a whole multiple, two or more, of
#'   `interval`) and `irregular` (step is not a whole multiple of
#'   `interval`). The comparison is exact: timestamps are whole seconds in
#'   the usual case, and no tolerance (a threshold) is assumed.
#' @noRd
station_time_steps <- function(obs, interval) {
  ord <- order(obs$station_id, as.numeric(obs$timestamp))
  id <- obs$station_id[ord]
  t <- as.numeric(obs$timestamp[ord])
  same <- c(FALSE, id[-1L] == id[-length(id)])
  step <- c(NA_real_, diff(t))
  keep <- which(same)
  ratio <- step[keep] / interval
  whole <- ratio == round(ratio)
  data.frame(
    row = ord[keep],
    step = step[keep],
    gap = whole & ratio >= 2,
    irregular = !whole
  )
}

#' Status of the observed values under a QC policy
#'
#' @param obs Data frame of observations.
#' @param qc Audit table.
#' @param vars Character. Observed variables.
#' @param qc_policy One of `station_qc_policies()`.
#' @return A data frame with `station_id`, `timestamp` and one factor
#'   column per variable (levels `ok`, `warning`, `excluded`).
#' @noRd
station_qc_status <- function(obs, qc, vars, qc_policy) {
  n <- nrow(obs)
  levels <- c("ok", "warning", "excluded")
  excl <- station_qc_exclusion_level(qc_policy)
  sev <- ef_flag_severity_levels()[qc$severity]
  out <- data.frame(station_id = obs$station_id, timestamp = obs$timestamp,
                    stringsAsFactors = FALSE)
  for (v in vars) {
    worst <- integer(n)
    sel <- qc$variable %in% c(v, "timestamp")
    if (any(sel)) {
      mx <- tapply(sev[sel], qc$row[sel], max)
      worst[as.integer(names(mx))] <- as.integer(mx)
    }
    status <- ifelse(worst >= excl, "excluded",
                     ifelse(worst >= 2L, "warning", "ok"))
    out[[v]] <- factor(status, levels = levels)
  }
  out
}

#' QC section of the provenance
#'
#' @param qc Audit table.
#' @param flags List of `earthflux_flag` records.
#' @param evaluated Character. Codes evaluated.
#' @param status Status table.
#' @param vars Character. Observed variables.
#' @param qc_policy Character.
#' @param n Integer. Number of records.
#' @param not_evaluated Data frame of the tests not evaluated (see
#'   `station_qc_not_evaluated()`).
#' @return A list with `qc_policy`, `excluded_severities`, `excluded_codes`
#'   (codes raised whose severity is excluded), `counts` (data frame `code`,
#'   `severity`, `n_records`, `n_values`, `n_total` for every code
#'   evaluated), `excluded` (data frame `variable`, `n_ok`, `n_warning`,
#'   `n_excluded`) and `not_evaluated` (see `station_qc_not_evaluated()`).
#' @noRd
station_qc_provenance <- function(qc, flags, evaluated, status, vars,
                                  qc_policy, n, not_evaluated) {
  reg <- ef_flag_registry()
  levels <- ef_flag_severity_levels()
  excluded_sev <- names(levels)[levels >= station_qc_exclusion_level(qc_policy)]
  raised <- vapply(flags, `[[`, "", "code")
  n_records <- vapply(evaluated, function(code) {
    k <- match(code, raised)
    if (is.na(k)) 0L else flags[[k]]$n_flagged
  }, integer(1), USE.NAMES = FALSE)
  counts <- data.frame(
    code = evaluated,
    severity = reg$severity[match(evaluated, reg$code)],
    n_records = n_records,
    n_values = vapply(evaluated, function(code) sum(qc$flag_code == code),
                      integer(1), USE.NAMES = FALSE),
    n_total = rep(as.integer(n), length(evaluated)),
    stringsAsFactors = FALSE
  )
  excluded <- data.frame(
    variable = vars,
    n_ok = vapply(vars, function(v) sum(status[[v]] == "ok"), integer(1),
                  USE.NAMES = FALSE),
    n_warning = vapply(vars, function(v) sum(status[[v]] == "warning"),
                       integer(1), USE.NAMES = FALSE),
    n_excluded = vapply(vars, function(v) sum(status[[v]] == "excluded"),
                        integer(1), USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
  list(
    qc_policy = qc_policy,
    excluded_severities = excluded_sev,
    excluded_codes = counts$code[counts$n_records > 0L &
                                   counts$severity %in% excluded_sev],
    counts = counts,
    excluded = excluded,
    not_evaluated = not_evaluated
  )
}

# Validation of the QC result --------------------------------------------------

#' Check the QC elements of an `earthflux_station_qc`
#'
#' Equivalence of the audit table and the flag records
#' (dev/specs/flags.md test R16, FL-13): every `flag_code` of `qc` is a
#' registered code with its registered severity; for every flag record, the
#' distinct rows of `qc` with its code are exactly its `index`; no code
#' appears in `qc` without a flag record. `qc_status` is aligned with
#' `observations`.
#'
#' @param x An `earthflux_station_qc`.
#' @param call The call to report.
#' @return `TRUE`, invisibly.
#' @noRd
station_check_qc <- function(x, call) {
  qc_abort <- function(message) {
    station_abort(message, "earthflux_station_field_error", call)
  }
  obs <- x$observations
  n <- nrow(obs)
  qc <- x$qc
  if (!is.data.frame(qc) || !identical(names(qc), names(station_qc_template()))) {
    qc_abort("`qc` must be the audit table of ef_station_qc().")
  }
  reg <- ef_flag_registry()
  k <- match(qc$flag_code, reg$code)
  if (anyNA(k)) {
    qc_abort(sprintf("`qc` contains unregistered flag code(s): %s.",
                     station_show(qc$flag_code[is.na(k)])))
  }
  if (!identical(qc$severity, reg$severity[k])) {
    qc_abort("`qc$severity` must be the registered severity of each code.")
  }
  if (!is.integer(qc$row) || anyNA(qc$row) || any(qc$row < 1L | qc$row > n) ||
      !identical(qc$station_id, obs$station_id[qc$row]) ||
      !identical(as.numeric(qc$timestamp), as.numeric(obs$timestamp[qc$row]))) {
    qc_abort("`qc` rows must refer to rows of `observations`.")
  }
  codes <- vapply(x$flags, `[[`, "", "code")
  if (!setequal(codes, unique(qc$flag_code)) || anyDuplicated(codes) > 0L) {
    qc_abort("`qc` and `flags` must contain the same codes.")
  }
  for (f in x$flags) {
    rows <- sort(unique(qc$row[qc$flag_code == f$code]))
    if (!identical(f$scope, "record") || f$n_total != n ||
        !identical(as.integer(f$index), rows)) {
      qc_abort(sprintf(
        "The flag record of %s is not equivalent to the rows of `qc`.",
        f$code
      ))
    }
  }
  status <- x$qc_status
  vars <- station_measured_vars(obs)
  if (!is.data.frame(status) ||
      !identical(names(status), c("station_id", "timestamp", vars)) ||
      nrow(status) != n || !identical(status$station_id, obs$station_id) ||
      !identical(as.numeric(status$timestamp), as.numeric(obs$timestamp)) ||
      !all(vapply(status[vars], function(s) {
        is.factor(s) && identical(levels(s), c("ok", "warning", "excluded")) &&
          !anyNA(s)
      }, logical(1)))) {
    qc_abort("`qc_status` must be aligned with `observations` (see ef_station_qc()).")
  }
  invisible(TRUE)
}

# Methods ----------------------------------------------------------------------

#' @export
print.earthflux_station_qc <- function(x, ...) {
  cat(sprintf("<%s>\n", class(x)[1L]))
  station_print_body(x)
  q <- x$provenance$qc
  cat(sprintf("Quality control: policy \"%s\"; %d code(s) evaluated\n",
              q$qc_policy, nrow(q$counts)))
  raised <- q$counts[q$counts$n_records > 0L, , drop = FALSE]
  if (nrow(raised) == 0L) {
    cat("  no flags\n")
  } else {
    for (i in seq_len(nrow(raised))) {
      cat(sprintf("  %-26s %-8s %d record(s), %d value(s)\n", raised$code[i],
                  raised$severity[i], raised$n_records[i],
                  raised$n_values[i]))
    }
  }
  ex <- q$excluded
  cat(sprintf("Values excluded: %d; with warning: %d (see `qc_status`)\n",
              sum(ex$n_excluded), sum(ex$n_warning)))
  invisible(x)
}
