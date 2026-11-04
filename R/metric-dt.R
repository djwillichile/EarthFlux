# METRIC: near-surface temperature difference (dT) --------------------------------
#
# Purpose: surface temperature referred to an elevation datum and the
#   coefficients of the internally calibrated linear relation
#   dT = a + b * Ts_datum, solved from the hot and cold anchor pixels.
#
# Specification: dev/specs/sensible-heat.md section 9 (notation of
#   dev/SCIENTIFIC_SPEC.md section 3: a = intercept [K], b = slope [-]; the
#   `water` package swaps a and b, section 4.2). Status: CANDIDATA.
#
# Implemented (exported): ef_ts_datum(), ef_dt_coef(). The iterative
#   calibration that uses them lives in R/metric-sensible-heat.R
#   (ef_calibrate_h()).

#' Surface temperature referred to an elevation datum
#'
#' @description
#' Adjusts the land surface temperature to a common elevation datum with a
#' constant lapse rate of the surface temperature with elevation, so that
#' the near-surface temperature difference \eqn{dT}{dT} of METRIC is
#' calibrated and applied on temperatures that are comparable across
#' elevations. The datum temperature is used only for \eqn{dT}{dT}; air
#' density, pressure, roughness and wind use the actual elevation.
#'
#' @param lst Numeric. Land surface temperature \eqn{T_s}{Ts} \[K\]. Must be
#'   finite and `> 0`.
#' @param elevation Numeric. Elevation of the pixel \eqn{z}{z} \[m\]. Must be
#'   finite.
#' @param datum_elevation Numeric scalar. Elevation of the datum
#'   \eqn{z_{datum}}{z_datum} \[m\]. Must be finite. A constant of the scene,
#'   recorded with the calibration: it changes the reported intercept `a`,
#'   not the sensible heat flux (see Details).
#' @param lapse_rate Numeric scalar. Lapse rate of the surface temperature
#'   with elevation \eqn{\Gamma}{Gamma} \[K m-1\] (note: per metre, not per
#'   kilometre). Must be finite and `>= 0`. No default: the value
#'   0.00649 K m-1 (6.49 K km-1) observed in METRIC implementations is
#'   `CANDIDATA` (decision SH-13).
#'
#' @return A numeric vector of datum temperature
#'   \eqn{T_{s,datum}}{Ts_datum} \[K\], with the common length of `lst` and
#'   `elevation` and keeping their `dim`.
#'
#' @details
#' \deqn{T_{s,datum} = T_s + \Gamma\,(z - z_{datum})}{Ts_datum = Ts + Gamma *
#'   (z - z_datum)}
#'
#' The value of \eqn{z_{datum}}{z_datum} does not affect the calibrated
#' \eqn{dT}{dT} nor the sensible heat flux (author's derivation,
#' `dev/specs/sensible-heat.md` section 9.1): shifting the datum shifts every
#' datum temperature by the same amount, which the two-anchor linear
#' relation absorbs in its intercept. Only \eqn{\Gamma}{Gamma} matters.
#'
#' Missing values propagate. Infinite values and values outside the domain
#' raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`).
#'
#' Verification status: `CANDIDATA` (observed in the `water` package; the
#' "customized lapse rate" attributed to Allen et al., 2007, has not been
#' verified).
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @family aerodynamics and sensible heat functions
#' @export
#'
#' @examples
#' # Pixels at 500 m and 700 m referred to a 500 m datum
#' ef_ts_datum(lst = c(300, 316), elevation = c(500, 700),
#'             datum_elevation = 500, lapse_rate = 0.00649)
ef_ts_datum <- function(lst, elevation, datum_elevation, lapse_rate) {
  call <- sys.call()
  check_core_args(list(lst = lst, elevation = elevation), call)
  check_scalar(datum_elevation, "datum_elevation", call)
  check_scalar(lapse_rate, "lapse_rate", call)
  check_in_range(lst, "lst", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(elevation, "elevation", call = call)
  check_in_range(lapse_rate, "lapse_rate", lower = 0, call = call)
  lst + lapse_rate * (elevation - datum_elevation)
}

#' Coefficients of the near-surface temperature difference
#'
#' @description
#' Solves the coefficients of the linear relation
#' \eqn{dT = a + b\,T_{s,datum}}{dT = a + b * Ts_datum} of METRIC from the
#' near-surface temperature differences required at the hot and cold anchor
#' pixels. The relation reproduces both anchor values exactly.
#'
#' @param ts_datum_hot,ts_datum_cold Numeric. Datum temperature of the hot
#'   and cold anchor \[K\] (see [ef_ts_datum()]). Must be finite and `> 0`,
#'   with `ts_datum_hot > ts_datum_cold`.
#' @param dt_hot,dt_cold Numeric. Near-surface temperature difference
#'   required at the hot and cold anchor \[K\]. Must be finite.
#'
#' @return A list with elements `a` (intercept \[K\]) and `b` (slope
#'   \[-\]), numeric vectors with the common length of the inputs (one pair
#'   per calibration, e.g. per scene) keeping their `dim`.
#'
#' @details
#' \deqn{b = \frac{dT_{hot} - dT_{cold}}{T_{s,datum,hot} - T_{s,datum,cold}},
#'   \qquad a = dT_{cold} - b\,T_{s,datum,cold}}{b = (dT_hot - dT_cold) /
#'   (Ts_datum_hot - Ts_datum_cold); a = dT_cold - b * Ts_datum_cold}
#'
#' Notation: `a` is the intercept and `b` the slope, as in
#' `dev/SCIENTIFIC_SPEC.md`; the `water` package uses the opposite names.
#'
#' Pixels outside the range of the anchors use the same line
#' (extrapolation, flagged by [ef_calibrate_h()]). A slope `b <= 0` with
#' well-ordered anchors contradicts the METRIC assumption that \eqn{dT}{dT}
#' grows with the surface temperature: it is returned unchanged here and
#' flagged (`EF_H_DT_SLOPE_NONPOSITIVE`, critical) by [ef_calibrate_h()].
#'
#' Missing values propagate. `ts_datum_hot <= ts_datum_cold` (equal datum
#' temperatures leave `b` undefined; a lower hot temperature suggests swapped
#' anchors) raises an error of class `earthflux_calibration_error`. Other
#' values outside the domain raise `earthflux_domain_error` (also
#' `earthflux_input_error`).
#'
#' Verification status: `CANDIDATA` (form observed in the `water` package
#' and in `dev/SCIENTIFIC_SPEC.md` section 3; Allen et al., 2007, not
#' consulted, including a reported erratum in its intercept equation).
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @family aerodynamics and sensible heat functions
#' @export
#'
#' @examples
#' ef_dt_coef(ts_datum_hot = 317.298, ts_datum_cold = 300,
#'            dt_hot = 11.733091, dt_cold = 0.675211)
ef_dt_coef <- function(ts_datum_hot, ts_datum_cold, dt_hot, dt_cold) {
  call <- sys.call()
  check_core_args(
    list(ts_datum_hot = ts_datum_hot, ts_datum_cold = ts_datum_cold,
         dt_hot = dt_hot, dt_cold = dt_cold),
    call
  )
  check_in_range(ts_datum_hot, "ts_datum_hot", lower = 0,
                 lower_inclusive = FALSE, call = call)
  check_in_range(ts_datum_cold, "ts_datum_cold", lower = 0,
                 lower_inclusive = FALSE, call = call)
  check_in_range(dt_hot, "dt_hot", call = call)
  check_in_range(dt_cold, "dt_cold", call = call)
  n_bad <- sum(ts_datum_hot <= ts_datum_cold, na.rm = TRUE)
  if (n_bad > 0L) {
    ef_abort(
      sprintf(
        paste0(
          "The datum temperature of the hot anchor must be greater than ",
          "that of the cold anchor (swapped anchors or undefined slope); ",
          "found %d violation(s)."
        ),
        n_bad
      ),
      class = "earthflux_calibration_error",
      call = call
    )
  }
  dt_coef_core(ts_datum_hot, ts_datum_cold, dt_hot, dt_cold)
}

#' Coefficients of dT without input checks
#'
#' @inheritParams ef_dt_coef
#' @return `list(a, b)`.
#' @noRd
dt_coef_core <- function(ts_datum_hot, ts_datum_cold, dt_hot, dt_cold) {
  b <- (dt_hot - dt_cold) / (ts_datum_hot - ts_datum_cold)
  a <- dt_cold - b * ts_datum_cold
  list(a = a, b = b)
}
