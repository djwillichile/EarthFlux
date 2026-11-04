# Shared physical quantities --------------------------------------------------------
#
# Purpose: quantities needed by several modules, implemented once so that no
#   module duplicates an equation (dev/specs/radiation-components.md RC-17 =
#   dev/specs/weather-forcing.md WF-01; transversal groups T-05 and T-08 of
#   dev/DECISIONS.md).
#
# Implemented:
#   - ef_air_pressure(): atmospheric pressure from elevation (FAO-56 Eq. 7,
#     VERIFICADA). Used by the shortwave transmissivity, the air density of
#     the sensible heat module and the reference ET.
#   - ef_lambda(): latent heat of vaporization, one function
#     for the whole chain (cold anchor condition and LE -> ET conversion;
#     decision ET-D1 / P0-7). Methods "constant" and "fao56" (VERIFICADA as
#     FAO-56). The surface-temperature form used in METRIC implementations
#     ("metric") is CANDIDATA and is not implemented until item V2 of
#     dev/specs/evapotranspiration.md section 12 is verified.
#   - check_latent_heat_units() (internal): unit guard for lambda, [1e6, 1e7]
#     J kg-1 (decision ET-D2), for the functions that receive lambda.
#
# Not here: the psychrometric constant, the saturation vapour pressure and its
#   slope (gamma, e0 and Delta; FAO-56 Eqs. 8, 11-13) live in
#   R/forcing-derived.R with the other derived meteorological variables
#   (decision WF-01 as implemented, dev/specs/weather-forcing.md 13.2).
#
# Conventions: those of ef_net_radiation() (dev/ARCHITECTURE.md section 3.1):
#   numeric input, recycling of length-1 arguments, no recycling of arrays
#   with `dim`, length 0 rejected, NA propagated, classed domain errors.

#' Atmospheric pressure from elevation
#'
#' @description
#' Computes the mean atmospheric pressure \eqn{P}{P} at a given elevation
#' above sea level with the simplified ideal-gas relation of FAO-56 (standard
#' atmosphere at 20 degrees Celsius). It is used when no measured or
#' regionalised pressure is available, for example for the shortwave
#' transmissivity, the air density and the reference evapotranspiration.
#'
#' @param elevation Numeric. Elevation above sea level \[m\]. Must be finite
#'   and lower than 293 / 0.0065 = 45 076.92 m, where the base of the power
#'   law becomes non-positive. Negative elevations (below sea level) are
#'   allowed.
#'
#' @return A numeric vector of atmospheric pressure \eqn{P}{P} \[kPa\] with
#'   the length of `elevation`. If `elevation` is a matrix or array, the
#'   result keeps its `dim`.
#'
#' @details
#' The pressure is
#' \deqn{P = 101.3 \left(\frac{293 - 0.0065 z}{293}\right)^{5.26}}{P = 101.3
#'   * ((293 - 0.0065 * z) / 293)^5.26}
#' where \eqn{z}{z} is `elevation` \[m\] and \eqn{P}{P} is in kPa (FAO-56,
#' chapter 3, Eq. 7).
#'
#' Assumptions (FAO-56, chapter 3 and annex 3): standard atmosphere with a
#' reference temperature of 293 K at sea level and a constant lapse rate of
#' 0.0065 K m-1; the exponent 5.26 approximates \eqn{g / (\alpha_1 R)}{g /
#' (a1 * R)} with g = 9.807 m s-2, R = 287 J kg-1 K-1 and
#' \eqn{\alpha_1}{a1} = 0.0065 K m-1. The result is a mean pressure for the
#' site: synoptic pressure variations are not represented. FAO-56 states that
#' the effect of pressure on evapotranspiration is small and that the mean
#' value for a location is sufficient.
#'
#' Missing values (`NA`, `NaN`) propagate to the output without errors or
#' warnings. `elevation` must be numeric (double or integer) and non-empty.
#' Infinite values or elevations of 45 076.92 m or more raise an error of
#' class `earthflux_domain_error` (also `earthflux_input_error`). A plausible
#' elevation range for a study area is not checked here (no threshold has a
#' documented reference).
#'
#' Verification status: `VERIFICADA` (identical to FAO-56, chapter 3,
#' Eq. 7). Its attribution to ASCE-EWRI (2005) has not been verified.
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' @family shared physical quantities
#' @export
#'
#' @examples
#' # Sea level: 101.3 kPa
#' ef_air_pressure(0)
#'
#' # Several elevations (m)
#' ef_air_pressure(c(0, 1000, 1800, 3000))
ef_air_pressure <- function(elevation) {
  call <- sys.call()
  check_numeric(elevation, "elevation", call = call)
  check_common_length(list(elevation = elevation), call = call)
  # Base of the power law: 293 - 0.0065 * z > 0  <=>  z < 293 / 0.0065.
  check_in_range(elevation, "elevation", upper = 293 / 0.0065,
                 upper_inclusive = FALSE, call = call)

  # FAO-56, chapter 3, Eq. 7 (normative coefficients kept as literals, WF-14).
  101.3 * ((293 - 0.0065 * elevation) / 293)^5.26
}

#' Latent heat of vaporization
#'
#' @description
#' Returns the latent heat of vaporization of water \eqn{\lambda}{lambda},
#' the energy needed to evaporate a unit mass of water, in J kg-1. The same
#' function and the same `method` must be used everywhere in the METRIC chain
#' (for example in the boundary condition of the cold anchor pixel and in the
#' conversion of latent heat flux to evapotranspiration), so that the chain
#' is internally consistent.
#'
#' @param temperature Numeric or `NULL`. Air temperature \[K\], required by
#'   `method = "fao56"`; ignored (and may be omitted) by
#'   `method = "constant"`. Must be finite and `> 0`.
#' @param method Character. The formulation, with no default: the choice is
#'   a scientific decision that must be explicit. One of:
#'   * `"constant"`: FAO-56 constant value, 2.45 MJ kg-1.
#'   * `"fao56"`: FAO-56 function of the air temperature.
#'
#' @return Latent heat of vaporization \eqn{\lambda}{lambda} \[J kg-1\]. For
#'   `method = "constant"`, a single number. For `method = "fao56"`, a numeric
#'   vector with the length of `temperature`, keeping its `dim` if it is a
#'   matrix or array.
#'
#' @details
#' `method = "constant"` returns
#' \deqn{\lambda = 2.45 \times 10^{6}\ \mathrm{J\,kg^{-1}}}{lambda = 2.45e6 J
#'   kg-1}
#' the value used by FAO-56 in the simplification of the FAO Penman-Monteith
#' equation, which corresponds to an air temperature of about 20 degrees
#' Celsius (FAO-56, chapter 3; annex 3).
#'
#' `method = "fao56"` evaluates FAO-56, annex 3, Eq. 3-1,
#' \deqn{\lambda = \left[2.501 - 2.361 \times 10^{-3} (T - 273.15)\right]
#'   \times 10^{6}}{lambda = (2.501 - 2.361e-3 * (T - 273.15)) * 1e6}
#' where \eqn{T}{T} is `temperature` \[K\] (the equation is formulated with
#' the air temperature in degrees Celsius; the conversion uses the package
#' constant 273.15 K). FAO-56 defines \eqn{T}{T} as the **air** temperature.
#' At 293.15 K (20 degrees Celsius) it gives 2 453 780 J kg-1.
#'
#' The surface-temperature form used in METRIC implementations is not
#' available: its coefficient and its use of the surface temperature are
#' `CANDIDATA` and must first be verified against Allen, Tasumi and Trezza
#' (2007).
#'
#' Missing values in `temperature` propagate to the output without errors or
#' warnings. A missing or unknown `method` raises an error of class
#' `earthflux_missing_input` or `earthflux_unknown_method` (both also
#' `earthflux_input_error`). With `method = "fao56"`, a missing or `NULL`
#' `temperature` raises `earthflux_missing_input`, and non-positive or
#' infinite temperatures raise `earthflux_domain_error`. A temperature range
#' of validity of the equation is not documented by FAO-56 and is not
#' checked.
#'
#' Verification status: `"constant"` and `"fao56"` are `VERIFICADA` as
#' FAO-56 values and equation.
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' @family shared physical quantities
#' @export
#'
#' @examples
#' # FAO-56 constant value (J kg-1)
#' ef_lambda(method = "constant")
#'
#' # Function of the air temperature, given in K (20 and 30 degrees C)
#' ef_lambda(c(293.15, 303.15), method = "fao56")
ef_lambda <- function(temperature = NULL, method) {
  call <- sys.call()
  if (!missing(method) && identical(method, "metric")) {
    ef_abort(
      paste0(
        "`method = \"metric\"` (surface-temperature form) is CANDIDATA and ",
        "not available until verified against the primary reference; use ",
        "\"constant\" or \"fao56\"."
      ),
      class = c("earthflux_unknown_method", "earthflux_input_error"),
      method = method,
      choices = c("constant", "fao56"),
      call = call
    )
  }
  check_method(method, c("constant", "fao56"), call = call)

  if (method == "constant") {
    return(EF_LATENT_HEAT_FAO56)
  }

  if (is.null(temperature)) {
    ef_abort(
      "`temperature` (air temperature, K) is required by `method = \"fao56\"`.",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  check_numeric(temperature, "temperature", call = call)
  check_common_length(list(temperature = temperature), call = call)
  check_in_range(temperature, "temperature", lower = 0,
                 lower_inclusive = FALSE, call = call)

  # FAO-56, annex 3, Eq. 3-1 (MJ kg-1, T in degrees C), converted to J kg-1.
  (2.501 - 2.361e-3 * (temperature - EF_KELVIN_OFFSET)) * 1e6
}

#' Check the unit of a latent heat of vaporization argument
#'
#' Unit guard for functions that receive \eqn{\lambda}{lambda} (decision
#' ET-D2 of dev/specs/evapotranspiration.md): values must lie in
#' \[1e6, 1e7\] J kg-1. The interval is not a physical range but a control of
#' units: it rejects \eqn{\lambda}{lambda} given in MJ kg-1 (about 2.45) or
#' in kJ kg-1 (about 2450). Missing values are ignored (they propagate);
#' infinite values are rejected.
#'
#' @inheritParams check_in_range
#' @return `x`, invisibly, if the check passes; otherwise an error of class
#'   `c("earthflux_domain_error", "earthflux_input_error")`.
#' @noRd
check_latent_heat_units <- function(x, arg = deparse(substitute(x)),
                                    call = sys.call(-1)) {
  vals <- x[!is.na(x)]
  n_bad <- sum(!is.finite(vals) | vals < 1e6 | vals > 1e7)
  if (n_bad > 0L) {
    ef_abort(
      sprintf(
        paste0(
          "`%s` must be a latent heat of vaporization in J kg-1, within ",
          "[1e6, 1e7] (unit guard); found %d value(s) outside this interval. ",
          "Values in MJ kg-1 must be multiplied by 1e6."
        ),
        arg, n_bad
      ),
      class = c("earthflux_domain_error", "earthflux_input_error"),
      call = call
    )
  }
  invisible(x)
}
