# Preprocessing: station values for the consumers of the forcing ---------------
#
# Purpose: hand the quality-controlled station data to their consumers
# without modifying the observations (dev/specs/weather-forcing.md sections
# 3.1 and 7.2; dev/specs/gwr-forcing.md section 2.1):
#   - station_values()                  values of one variable with the QC
#                                       exclusions applied as NA (copy);
#   - station_regionalization_input()   the long table
#                                       `ef_regionalization_input` of the
#                                       interface forcing -> spatial, for the
#                                       variables observed directly.
#
# Derived variables (vapour pressure from humidity, wind at 2 m, clearness
# index) and the reference ET are computed by the reference ET module
# (dev/specs/weather-forcing.md sections 4-5); their values enter the
# regionalization input with the same contract.

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
