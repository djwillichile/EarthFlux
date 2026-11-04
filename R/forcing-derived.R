# Forcing: derived meteorological variables ---------------------------------------
#
# Purpose: the meteorological quantities derived from station (or
#   regionalised) observations that the reference evapotranspiration and the
#   METRIC forcing need: psychrometric constant, saturation vapour pressure
#   and its slope, actual vapour pressure, dew point, wind speed at 2 m,
#   extraterrestrial radiation (daily and per period) and clear-sky
#   radiation.
#
# Specification: dev/specs/weather-forcing.md section 4 (equations, units,
#   domains), section 8 (FAO-56 verification cases V1-V17 and errata) and
#   section 11 (open decisions). Names: dev/NAMING.md (forcing table).
#
# Implemented (all exported, numeric, VERIFICADA against FAO-56 unless
#   stated, and also against the ASCE-EWRI (2005) standardized procedure,
#   which uses the same forms except where noted in each function: the
#   daily ea forms "rhmin" and "rhmean_tmean" and the sunrise/sunset limits
#   of the hourly Ra, both selected explicitly):
#   - ef_psychrometric()  gamma, FAO-56 Eq. 8;
#   - ef_es()             saturation vapour pressure e°(T), Eq. 11 (with
#                         Eq. 12 for periods of a day or longer, in Details);
#   - ef_es_slope()       slope Delta of the saturation curve, Eq. 13;
#   - actual vapour pressure family (one Rd, topic `ef_ea`):
#       ef_ea_dewpoint() Eq. 14, ef_ea_rh() Eq. 54, ef_ea_tmin() Eq. 48,
#       ef_ea_daily(..., method) Eqs. 17-19 and ASCE-EWRI Eqs. 13-14 (rule
#       N6b: one function with `method`, no default, returns numeric);
#   - ef_dewpoint()       dew point from vapour pressure, annex 3 Eq. 3-11;
#   - ef_wind_2m()        logarithmic wind profile over short grass, Eq. 47;
#   - ef_ra_daily()       daily extraterrestrial radiation, Eqs. 21-25;
#   - ef_ra_period()      extraterrestrial radiation of an hourly or shorter
#                         period, Eqs. 28-33 (`standard`: FAO-56 midpoint
#                         criterion or ASCE-EWRI Eq. 56 limits, WF-10);
#   - ef_rso()            clear-sky radiation from elevation, Eq. 37.
#   Internal: sat_vp() (Eq. 11 without checks), ef_sunset_hour_angle()
#   (Eq. 25) and ef_daylight_hours() (Eq. 34).
#
# The atmospheric pressure is ef_air_pressure() (R/shared-physics.R, FAO-56
#   Eq. 7) and is not duplicated here. The declination, the inverse relative
#   distance, the equation of time and the hour angle are the internal
#   helpers of R/solar-geometry.R (FAO-56 Eqs. 23, 24, 31-33), reused, never
#   reimplemented (weather-forcing.md 4.6).
#
# Conventions (dev/ARCHITECTURE.md section 3.1, P0-4/WF-02): air and dew
#   point temperatures in degrees Celsius (FAO-56 is formulated in degrees
#   Celsius); angles, latitude and longitude included, in radians (RC-01);
#   pressures in kPa; radiation in MJ m-2 per day or per period, as in
#   FAO-56. Vectorised; length-1 arguments recycled; arrays with `dim` not
#   recycled and their `dim` kept; length 0 rejected; NA propagated; values
#   outside the domain raise `earthflux_domain_error`; nothing is truncated
#   or corrected. Normative coefficients of FAO-56 stay as literals inside
#   the function that implements the equation (decision WF-14).

# Shared internal helpers ------------------------------------------------------

#' Saturation vapour pressure without input checks
#'
#' FAO-56 Eq. 11 for already validated temperatures \[degrees C\].
#'
#' @param t Numeric temperature \[degrees C\], `> -237.3`.
#' @return Numeric e°(T) \[kPa\].
#' @noRd
sat_vp <- function(t) {
  # FAO-56, chapter 3, Eq. 11.
  0.6108 * exp(17.27 * t / (t + 237.3))
}

#' Check a temperature in degrees Celsius for the FAO-56 vapour equations
#'
#' FAO-56 Eq. 11 and Eq. 13 are defined only for T > -237.3 degrees C (the
#' denominator T + 237.3 must be positive); this also rejects the physically
#' impossible T <= -273.15 degrees C (weather-forcing.md 4.3).
#'
#' @param x Numeric temperature \[degrees C\].
#' @param arg Argument name.
#' @param call The call to report.
#' @return `x`, invisibly.
#' @noRd
check_celsius_vp <- function(x, arg, call = sys.call(-1)) {
  check_in_range(x, arg, lower = -237.3, lower_inclusive = FALSE,
                 call = call)
}

#' Sunset hour angle
#'
#' FAO-56, chapter 3, Eq. 25: \eqn{\omega_s = \arccos(-\tan\phi \tan\delta)}.
#' Where \eqn{|\tan\phi \tan\delta| > 1} (polar day or polar night) the
#' argument is limited to \[-1, 1\], which gives the geometric limits
#' \eqn{\omega_s = \pi} (sun always above the horizon) and
#' \eqn{\omega_s = 0} (sun always below). FAO-56 Eqs. 26-27 treat the same
#' case with X = 0.00001 and give nearly the same values.
#'
#' @param lat Numeric latitude \[rad\] (checked by the caller).
#' @param declination Numeric declination \[rad\].
#' @return Numeric \eqn{\omega_s} \[rad\], in \[0, pi\].
#' @noRd
ef_sunset_hour_angle <- function(lat, declination) {
  x <- -tan(lat) * tan(declination)
  acos(pmin(pmax(x, -1), 1))
}

#' Maximum possible duration of sunshine (daylight hours)
#'
#' FAO-56, chapter 3, Eq. 34: \eqn{N = (24/\pi)\,\omega_s}. Used by the
#' Angstrom relation (Eq. 35) when the solar radiation is estimated from
#' sunshine hours (not implemented; it belongs to the station preparation).
#'
#' @inheritParams ef_ra_daily
#' @return Numeric \eqn{N} \[h\], same length and `dim` as the inputs.
#' @section Verification status: `VERIFICADA` (FAO-56, chapter 3, Eq. 34;
#'   dev/specs/weather-forcing.md 4.6, case V8).
#' @noRd
ef_daylight_hours <- function(lat, doy) {
  call <- sys.call()
  args <- list(lat = lat, doy = doy)
  n <- check_core_args(args, call)
  check_angle(lat, "lat", "lat", call)
  check_doy(doy, call)
  ws <- ef_sunset_hour_angle(lat, ef_declination(doy))
  ef_reshape(24 / pi * ws, n, common_dim(args))
}

# Psychrometric constant, saturation and actual vapour pressure -----------------

#' Psychrometric constant
#'
#' @description
#' Computes the psychrometric constant \eqn{\gamma}{gamma} of FAO-56 from
#' the atmospheric pressure, with the latent heat of vaporization fixed at
#' 2.45 MJ kg-1 as in the standardized reference evapotranspiration
#' equation.
#'
#' @param pressure Numeric. Atmospheric pressure \eqn{P}{P} \[kPa\], for
#'   example from [ef_air_pressure()]. Must be finite and `> 0`.
#'
#' @return A numeric vector of the psychrometric constant
#'   \eqn{\gamma}{gamma} \[kPa degC-1\] with the length of `pressure`,
#'   keeping its `dim`.
#'
#' @details
#' \deqn{\gamma = \frac{c_p P}{\varepsilon \lambda} = 0.665 \times 10^{-3}
#'   P}{gamma = cp * P / (epsilon * lambda) = 0.665e-3 * P}
#' with \eqn{c_p}{cp} = 1.013e-3 MJ kg-1 degC-1, \eqn{\varepsilon}{epsilon}
#' = 0.622 and \eqn{\lambda}{lambda} = 2.45 MJ kg-1 (FAO-56, chapter 3,
#' Eq. 8). The coefficient published by FAO-56, 0.665e-3, is the rounded
#' value of 1.013e-3 / (0.622 * 2.45) = 6.6475e-4 and is used as published
#' (it is the one used in the FAO-56 examples).
#'
#' Assumption: constant latent heat of vaporization (2.45 MJ kg-1, about
#' 20 degrees C), as in the standardized equation. The general form with a
#' temperature-dependent \eqn{\lambda}{lambda} (FAO-56 annex 3, Eq. 3-10)
#' is not implemented here.
#'
#' Missing values propagate. Non-numeric or empty input raises
#' `earthflux_input_error`; non-positive or infinite pressures raise
#' `earthflux_domain_error`.
#'
#' @section Verification status:
#' `VERIFICADA` (FAO-56, chapter 3, Eq. 8; dev/specs/weather-forcing.md
#' 4.2, case V1: P = 81.8 kPa gives 0.054 kPa degC-1). The same
#' coefficient, \eqn{\gamma = 0.000665 P}{gamma = 0.000665 * P}, is
#' ASCE-EWRI (2005) Eqs. 4 and 35 (pp. 10, 28), with \eqn{\lambda}{lambda}
#' = 2.45 MJ kg-1 (pp. 9, 27); the pressure of [ef_air_pressure()] is its
#' Eqs. 3 and 34.
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
#' @family derived meteorological variables
#' @export
#'
#' @examples
#' # FAO-56 example 2: elevation 1800 m
#' ef_psychrometric(ef_air_pressure(1800))
ef_psychrometric <- function(pressure) {
  call <- sys.call()
  check_core_args(list(pressure = pressure), call)
  check_in_range(pressure, "pressure", lower = 0, lower_inclusive = FALSE,
                 call = call)
  # FAO-56, chapter 3, Eq. 8 (published coefficient, WF-14).
  0.665e-3 * pressure
}

#' Saturation vapour pressure
#'
#' @description
#' Computes the saturation vapour pressure \eqn{e^\circ(T)}{e0(T)} at a
#' given air temperature with the FAO-56 equation.
#'
#' @param air_temperature Numeric. Air temperature \eqn{T}{T}
#'   \[degrees Celsius\]. Must be finite and `> -237.3`, where the equation
#'   is defined.
#'
#' @return A numeric vector of saturation vapour pressure \[kPa\] with the
#'   length of `air_temperature`, keeping its `dim`.
#'
#' @details
#' \deqn{e^\circ(T) = 0.6108 \exp\left(\frac{17.27\,T}{T + 237.3}\right)}{
#'   e0(T) = 0.6108 * exp(17.27 * T / (T + 237.3))}
#' (FAO-56, chapter 3, Eq. 11).
#'
#' **Mean saturation vapour pressure.** For periods of one day or longer the
#' saturation vapour pressure of the period is the mean of the values at the
#' daily maximum and minimum temperatures (FAO-56, Eq. 12):
#' `(ef_es(tmax) + ef_es(tmin)) / 2`. Using the mean temperature instead
#' underestimates it and the reference evapotranspiration (FAO-56,
#' chapter 3 and box 7). For hourly periods, `ef_es()` of the hourly mean
#' temperature is used (FAO-56, Eq. 53). The vapour pressure deficit is
#' the difference between this value and the actual vapour pressure
#' ([ef_ea_daily()] and related functions).
#'
#' Temperatures are in degrees Celsius (decision WF-02): a temperature
#' passed in kelvin (for example 293) gives a meaningless value and is not
#' detected here (it is a quality-control matter, flag `EF_WS_IMPLAUSIBLE`,
#' not registered).
#'
#' Missing values propagate. Non-numeric or empty input raises
#' `earthflux_input_error`; temperatures `<= -237.3` or infinite raise
#' `earthflux_domain_error`.
#'
#' @section Verification status:
#' `VERIFICADA` (FAO-56, chapter 3, Eqs. 11 and 12; case V2:
#' e°(24.5) = 3.075 kPa, e°(15) = 1.705 kPa). FAO-56 annex 3, Eq. 3-8 uses
#' 0.611 instead of 0.6108; the chapter 3 form is adopted
#' (dev/specs/weather-forcing.md 4.3). The same function and the same
#' daily mean (Tmax and Tmin) and hourly forms are ASCE-EWRI (2005)
#' Eqs. 6-7 (p. 11) and Eq. 37 (p. 29).
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
#' @family derived meteorological variables
#' @export
#'
#' @examples
#' # FAO-56 example 3: Tmax = 24.5 and Tmin = 15 degrees C
#' ef_es(c(24.5, 15))
#' # Mean saturation vapour pressure of the day (Eq. 12)
#' mean(ef_es(c(24.5, 15)))
ef_es <- function(air_temperature) {
  call <- sys.call()
  check_core_args(list(air_temperature = air_temperature), call)
  check_celsius_vp(air_temperature, "air_temperature", call)
  sat_vp(air_temperature)
}

#' Slope of the saturation vapour pressure curve
#'
#' @description
#' Computes the slope \eqn{\Delta}{Delta} of the saturation vapour pressure
#' curve at a given air temperature (FAO-56).
#'
#' @param air_temperature Numeric. Air temperature \[degrees Celsius\]: the
#'   mean daily temperature \eqn{(T_{max} + T_{min})/2}{(Tmax + Tmin) / 2}
#'   for a daily time step (FAO-56, Eq. 9), or the mean hourly temperature
#'   for an hourly time step. Must be finite and `> -237.3`.
#'
#' @return A numeric vector of \eqn{\Delta}{Delta} \[kPa degC-1\] with the
#'   length of `air_temperature`, keeping its `dim`.
#'
#' @details
#' \deqn{\Delta = \frac{4098\, e^\circ(T)}{(T + 237.3)^2}}{Delta = 4098 *
#'   e0(T) / (T + 237.3)^2}
#' with \eqn{e^\circ(T)}{e0(T)} from [ef_es()] (FAO-56, chapter 3, Eq. 13).
#'
#' Missing values propagate; the domain is that of [ef_es()].
#'
#' @section Verification status:
#' `VERIFICADA` (FAO-56, chapter 3, Eq. 13; case V14: 0.122 kPa degC-1 at
#' 16.9 degrees C). FAO-56 annex 3, Eq. 3-9 writes the same quantity with
#' 2504 and 237.2 in the exponent; the chapter 3 form is adopted.
#' ASCE-EWRI (2005) Eqs. 5 and 36 (pp. 10, 28) write
#' \eqn{\Delta = 2503 \exp(17.27 T / (T + 237.3)) / (T + 237.3)^2}{Delta
#' = 2503 * exp(17.27 * T / (T + 237.3)) / (T + 237.3)^2}: 2503 is the
#' product 4098 x 0.6108 = 2503.06 rounded, so the two forms differ by a
#' constant factor of 2.3e-5 (relative), far below the precision of the
#' published values; the FAO-56 form is used for both standards
#' (dev/specs/weather-forcing.md 4.3).
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
#' @family derived meteorological variables
#' @export
#'
#' @examples
#' # FAO-56 example 18: mean temperature (21.5 + 12.3) / 2 degrees C
#' ef_es_slope((21.5 + 12.3) / 2)
ef_es_slope <- function(air_temperature) {
  call <- sys.call()
  check_core_args(list(air_temperature = air_temperature), call)
  check_celsius_vp(air_temperature, "air_temperature", call)
  # FAO-56, chapter 3, Eq. 13.
  4098 * sat_vp(air_temperature) / (air_temperature + 237.3)^2
}

#' Actual vapour pressure
#'
#' @description
#' Computes the actual vapour pressure of the air \eqn{e_a}{ea} from the
#' humidity data available, with the FAO-56 equations:
#'
#' * `ef_ea_dewpoint()`: from the dew point temperature (any time step);
#' * `ef_ea_rh()`: from the air temperature and relative humidity of the
#'   same period (hourly or shorter);
#' * `ef_ea_daily()`: from the daily extreme temperatures and relative
#'   humidities, with an explicit `method` (`"rhmax_rhmin"`, `"rhmax"`,
#'   `"rhmin"`, `"rhmean"` or `"rhmean_tmean"`);
#' * `ef_ea_tmin()`: from the minimum temperature, only when humidity data
#'   are missing, with an explicit aridity correction `k0`.
#'
#' @param dewpoint_temperature Numeric. Dew point temperature \[degrees
#'   Celsius\], finite and `> -237.3`.
#' @param air_temperature Numeric. Air temperature of the period \[degrees
#'   Celsius\], finite and `> -237.3`.
#' @param relative_humidity Numeric. Relative humidity of the same period
#'   \[%\], finite and `>= 0`. Values above 100 % are computed (they are a
#'   quality-control matter, `EF_WS_RH_GT100`), never truncated.
#' @param tmin,tmax Numeric. Daily minimum and maximum air temperatures
#'   \[degrees Celsius\], finite and `> -237.3`; `tmin <= tmax`. `tmax` is
#'   not used by `method = "rhmax"` and `tmin` not by `method = "rhmin"`;
#'   they may then be omitted (`NULL`).
#' @param rh_max,rh_min Numeric. Daily maximum and minimum relative humidity
#'   \[%\], finite and `>= 0`. `rh_min` is not used by `method = "rhmax"`
#'   and `rh_max` not by `method = "rhmin"`; they may then be omitted
#'   (`NULL`).
#' @param k0 Numeric. Aridity correction \eqn{K_0}{K0} \[degC\] subtracted
#'   from `tmin` to approximate the dew point, finite and `>= 0`. FAO-56
#'   (annex 6, Eq. 6-6) gives 0 degC for humid and sub-humid climates and
#'   2 degC for arid and semi-arid climates (chapter 3: 2-3 degC). No
#'   default: the choice depends on the climate of the site.
#' @param method Character, no default. Formulation of `ef_ea_daily()`:
#'   * `"rhmax_rhmin"`: FAO-56 Eq. 17, from `tmin`, `tmax`, `rh_max` and
#'     `rh_min` (recommended by FAO-56);
#'   * `"rhmax"`: FAO-56 Eq. 18, from `tmin` and `rh_max` only (when
#'     `rh_min` is doubtful);
#'   * `"rhmin"`: ASCE-EWRI (2005) Eq. 13, from `tmax` and `rh_min` only
#'     (when only good daily minimum humidities are available; less
#'     desirable than Eqs. 11-12 of the report);
#'   * `"rhmean"`: FAO-56 Eq. 19, from the mean relative humidity
#'     `(rh_max + rh_min) / 2` and the mean saturation vapour pressure (the
#'     least desirable of the FAO-56 forms; not recommended in the ASCE-EWRI
#'     standardized procedure);
#'   * `"rhmean_tmean"`: ASCE-EWRI (2005) Eq. 14, from the mean relative
#'     humidity `(rh_max + rh_min) / 2` and the saturation vapour pressure
#'     at the mean temperature `(tmax + tmin) / 2` (the form of the
#'     standardized procedure when only the mean humidity is usable).
#'
#' @return A numeric vector of actual vapour pressure \eqn{e_a}{ea} \[kPa\]
#'   with the common length of the inputs, keeping their `dim`.
#'
#' @details
#' With \eqn{e^\circ(T)}{e0(T)} the saturation vapour pressure of [ef_es()]
#' (FAO-56 Eq. 11):
#' \deqn{e_a = e^\circ(T_{dew})}{ea = e0(Tdew)}
#' (Eq. 14; `ef_ea_dewpoint()`),
#' \deqn{e_a = e^\circ(T_{hr}) \frac{RH_{hr}}{100}}{ea = e0(Thr) *
#'   RHhr / 100}
#' (Eq. 54; annex 5, Eq. 5-3: temperature and humidity of the same period,
#' preferably one hour or less; `ef_ea_rh()`),
#' \deqn{e_a = \frac{e^\circ(T_{min}) \frac{RH_{max}}{100} +
#'   e^\circ(T_{max}) \frac{RH_{min}}{100}}{2}}{ea = (e0(Tmin) * RHmax /
#'   100 + e0(Tmax) * RHmin / 100) / 2}
#' (Eq. 17; `"rhmax_rhmin"`),
#' \deqn{e_a = e^\circ(T_{min}) \frac{RH_{max}}{100}}{ea = e0(Tmin) *
#'   RHmax / 100}
#' (Eq. 18; `"rhmax"`),
#' \deqn{e_a = e^\circ(T_{max}) \frac{RH_{min}}{100}}{ea = e0(Tmax) *
#'   RHmin / 100}
#' (ASCE-EWRI 2005, Eq. 13; `"rhmin"`),
#' \deqn{e_a = \frac{RH_{mean}}{100} \frac{e^\circ(T_{max}) +
#'   e^\circ(T_{min})}{2}, \quad RH_{mean} = \frac{RH_{max} +
#'   RH_{min}}{2}}{ea = RHmean / 100 * (e0(Tmax) + e0(Tmin)) / 2, RHmean =
#'   (RHmax + RHmin) / 2}
#' (Eq. 19; `"rhmean"`),
#' \deqn{e_a = \frac{RH_{mean}}{100} e^\circ\left(\frac{T_{max} +
#'   T_{min}}{2}\right)}{ea = RHmean / 100 * e0((Tmax + Tmin) / 2)}
#' (ASCE-EWRI 2005, Eqs. 14 and 2; `"rhmean_tmean"`), and
#' \deqn{e_a = e^\circ(T_{min} - K_0)}{ea = e0(Tmin - K0)}
#' (Eq. 48; annex 6, Eq. 6-6; `ef_ea_tmin()`). The last one assumes that
#' the dew point is close to the minimum temperature, which holds only at
#' well-watered reference sites; FAO-56 recommends it only when humidity
#' data are missing.
#'
#' **ASCE-EWRI (2005).** The report gives the same forms for the
#' standardized equation: Eq. 8 and Eq. 38 (dew point; FAO-56 Eq. 14),
#' Eq. 41 (hourly relative humidity; FAO-56 Eq. 54), Eq. 11 (FAO-56
#' Eq. 17) and Eq. 12 (FAO-56 Eq. 18), with the preference rankings of its
#' Tables 3 (daily) and 4 (hourly) (pp. 12, 30). It adds Eq. 13
#' (`"rhmin"`) and replaces the mean-humidity form: Eq. 14
#' (`"rhmean_tmean"`) uses \eqn{e^\circ(T_{mean})}{e0(Tmean)}, and the
#' FAO-56 Eq. 19 form (`"rhmean"`) is "not recommended in the standardized
#' procedure" (p. 17). The estimate from the minimum temperature is
#' described in its Appendix E (not read; `ef_ea_tmin()` stays a FAO-56
#' form). The psychrometric forms (report Eqs. 9-10, 39-40) are not
#' implemented.
#'
#' FAO-56 and `dev/SCIENTIFIC_SPEC.md` section 5 recommend regionalising the
#' actual vapour pressure (nearly constant during the day), not the relative
#' humidity, which depends on the temperature.
#'
#' Missing values propagate. Non-numeric, empty or incompatible inputs
#' raise `earthflux_input_error`; temperatures `<= -237.3`, negative
#' humidities, negative `k0`, `tmin > tmax` or infinite values raise
#' `earthflux_domain_error`. A missing or unknown `method` raises
#' `earthflux_missing_input` or `earthflux_unknown_method`; an input
#' required by the method and not supplied raises `earthflux_missing_input`.
#'
#' @section Verification status:
#' `VERIFICADA` (FAO-56, chapter 3, Eqs. 14, 17, 18, 19, 48 and 54; annex 6,
#' Eq. 6-6; dev/specs/weather-forcing.md 4.4, cases V3 and V17).
#' `ef_ea_tmin()` is verified as an equation; its use is restricted to
#' missing humidity data and `k0` is always explicit. `"rhmin"` and
#' `"rhmean_tmean"`: `VERIFICADA` (ASCE-EWRI, 2005, Eqs. 13 and 14, pp.
#' 16-17); the forms shared with FAO-56 are also ASCE-EWRI (2005) Eqs. 8,
#' 11, 12, 38 and 41 (pp. 13, 15, 30, 32).
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
#' @family derived meteorological variables
#' @name ef_ea
#'
#' @examples
#' # FAO-56 example 5: Tmin = 18, Tmax = 25 degrees C, RHmax = 82,
#' # RHmin = 54 %
#' ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82, rh_min = 54,
#'             method = "rhmax_rhmin")
#' ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82, rh_min = 54,
#'             method = "rhmean")
#' ef_ea_daily(tmin = 18, rh_max = 82, method = "rhmax")
#' # ASCE-EWRI (2005) forms: Eq. 13 and Eq. 14
#' ef_ea_daily(tmax = 25, rh_min = 54, method = "rhmin")
#' ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82, rh_min = 54,
#'             method = "rhmean_tmean")
#'
#' # From the dew point, and from hourly temperature and humidity
#' ef_ea_dewpoint(15)
#' ef_ea_rh(air_temperature = 38, relative_humidity = 52)
#'
#' # Minimum temperature, arid site (k0 = 2 degrees C)
#' ef_ea_tmin(tmin = 12, k0 = 2)
NULL

#' @rdname ef_ea
#' @export
ef_ea_dewpoint <- function(dewpoint_temperature) {
  call <- sys.call()
  check_core_args(list(dewpoint_temperature = dewpoint_temperature), call)
  check_celsius_vp(dewpoint_temperature, "dewpoint_temperature", call)
  # FAO-56, chapter 3, Eq. 14.
  sat_vp(dewpoint_temperature)
}

#' @rdname ef_ea
#' @export
ef_ea_rh <- function(air_temperature, relative_humidity) {
  call <- sys.call()
  args <- list(air_temperature = air_temperature,
               relative_humidity = relative_humidity)
  n <- check_core_args(args, call)
  check_celsius_vp(air_temperature, "air_temperature", call)
  check_in_range(relative_humidity, "relative_humidity", lower = 0,
                 call = call)
  # FAO-56, chapter 3, Eq. 54 (annex 5, Eq. 5-3).
  ef_reshape(sat_vp(air_temperature) * relative_humidity / 100, n,
             common_dim(args))
}

#' @rdname ef_ea
#' @export
ef_ea_tmin <- function(tmin, k0) {
  call <- sys.call()
  if (missing(k0)) {
    ef_abort(
      paste0(
        "`k0` (aridity correction, degC) must be supplied explicitly: ",
        "FAO-56 gives 0 for humid and sub-humid and 2 for arid and ",
        "semi-arid climates."
      ),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  args <- list(tmin = tmin, k0 = k0)
  n <- check_core_args(args, call)
  check_in_range(k0, "k0", lower = 0, call = call)
  check_celsius_vp(tmin - k0, "tmin - k0", call)
  # FAO-56, chapter 3, Eq. 48; annex 6, Eq. 6-6.
  ef_reshape(sat_vp(tmin - k0), n, common_dim(args))
}

#' @rdname ef_ea
#' @export
ef_ea_daily <- function(tmin, tmax = NULL, rh_max, rh_min = NULL, method) {
  call <- sys.call()
  check_method(method,
               c("rhmax_rhmin", "rhmax", "rhmin", "rhmean", "rhmean_tmean"),
               call = call)

  required <- switch(
    method,
    rhmax_rhmin = c("tmin", "tmax", "rh_max", "rh_min"),
    rhmax = c("tmin", "rh_max"),
    rhmin = c("tmax", "rh_min"),
    rhmean = c("tmin", "tmax", "rh_max", "rh_min"),
    rhmean_tmean = c("tmin", "tmax", "rh_max", "rh_min")
  )
  if (missing(tmin)) {
    tmin <- NULL
  }
  if (missing(rh_max)) {
    rh_max <- NULL
  }
  inputs <- list(tmin = tmin, tmax = tmax, rh_max = rh_max,
                 rh_min = rh_min)[required]
  absent <- required[vapply(inputs, is.null, logical(1))]
  if (length(absent) > 0L) {
    ef_abort(
      sprintf(
        "`method = \"%s\"` requires %s; missing: %s.",
        method,
        paste0("`", required, "`", collapse = ", "),
        paste0("`", absent, "`", collapse = ", ")
      ),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }

  n <- check_core_args(inputs, call)
  if ("tmin" %in% required) {
    check_celsius_vp(tmin, "tmin", call)
  }
  if ("tmax" %in% required) {
    check_celsius_vp(tmax, "tmax", call)
  }
  if (all(c("tmin", "tmax") %in% required)) {
    check_condition(tmin <= tmax, "`tmin` must not exceed `tmax`", call)
  }
  if ("rh_max" %in% required) {
    check_in_range(rh_max, "rh_max", lower = 0, call = call)
  }
  if ("rh_min" %in% required) {
    check_in_range(rh_min, "rh_min", lower = 0, call = call)
  }

  ea <- switch(
    method,
    # FAO-56, chapter 3, Eq. 17.
    rhmax_rhmin = (sat_vp(tmin) * rh_max / 100 +
                     sat_vp(tmax) * rh_min / 100) / 2,
    # FAO-56, chapter 3, Eq. 18.
    rhmax = sat_vp(tmin) * rh_max / 100,
    # ASCE-EWRI (2005), Eq. 13.
    rhmin = sat_vp(tmax) * rh_min / 100,
    # FAO-56, chapter 3, Eq. 19 (RHmean = (RHmax + RHmin) / 2).
    rhmean = (rh_max + rh_min) / 2 / 100 *
      (sat_vp(tmax) + sat_vp(tmin)) / 2,
    # ASCE-EWRI (2005), Eq. 14 with Tmean of Eq. 2.
    rhmean_tmean = (rh_max + rh_min) / 2 / 100 * sat_vp((tmax + tmin) / 2)
  )
  ef_reshape(ea, n, common_dim(inputs))
}

#' Dew point temperature from the actual vapour pressure
#'
#' @description
#' Computes the dew point temperature from the actual vapour pressure with
#' the explicit FAO-56 expression, used for quality control of humidity
#' data (for example to compare the dew point with the minimum
#' temperature).
#'
#' @param vapour_pressure Numeric. Actual vapour pressure \eqn{e_a}{ea}
#'   \[kPa\]. Must be finite and `> 0` (logarithm), and below
#'   \eqn{e^{16.78}}{exp(16.78)} kPa (where the denominator vanishes; far
#'   outside any atmospheric value).
#'
#' @return A numeric vector of dew point temperature \[degrees Celsius\]
#'   with the length of `vapour_pressure`, keeping its `dim`.
#'
#' @details
#' \deqn{T_{dew} = \frac{116.91 + 237.3 \ln e_a}{16.78 - \ln e_a}}{Tdew =
#'   (116.91 + 237.3 * log(ea)) / (16.78 - log(ea))}
#' (FAO-56, annex 3, Eq. 3-11). It is not the exact inverse of [ef_es()]
#' (FAO-56 Eq. 11): for \eqn{e_a = e^\circ(15)}{ea = e0(15)} = 1.70535 kPa it
#' returns 14.9926 degrees C (difference 0.0074 degrees C), which is
#' sufficient for quality control (dev/specs/weather-forcing.md 4.4).
#'
#' Missing values propagate. Non-positive, too large or infinite values
#' raise `earthflux_domain_error`.
#'
#' @section Verification status:
#' `VERIFICADA` as the FAO-56 form (annex 3, Eq. 3-11; case V17).
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' @family derived meteorological variables
#' @export
#'
#' @examples
#' ef_dewpoint(ef_ea_dewpoint(15))
ef_dewpoint <- function(vapour_pressure) {
  call <- sys.call()
  check_core_args(list(vapour_pressure = vapour_pressure), call)
  check_in_range(vapour_pressure, "vapour_pressure", lower = 0,
                 upper = exp(16.78), lower_inclusive = FALSE,
                 upper_inclusive = FALSE, call = call)
  # FAO-56, annex 3, Eq. 3-11.
  log_ea <- log(vapour_pressure)
  (116.91 + 237.3 * log_ea) / (16.78 - log_ea)
}

# Wind ------------------------------------------------------------------------

#' Lower bound of the measurement height of FAO-56 Eq. 47
#'
#' Domain of the logarithmic wind profile of FAO-56 Eq. 47:
#' \eqn{\ln(67.8 z - 5.42) > 0}, i.e. \eqn{z > 6.42 / 67.8 = 0.0947} m. The
#' single source of the bound, used by [ef_wind_2m()] and by the validation
#' of the anemometer height of the station table (`R/io-weather.R`).
#'
#' @return A numeric scalar \[m\] (exclusive lower bound).
#' @section Verification status: `VERIFICADA` (FAO-56, chapter 3, Eq. 47).
#' @noRd
ef_wind_2m_min_height <- function() {
  # ln(67.8 z - 5.42) > 0  <=>  z > (1 + 5.42) / 67.8.
  6.42 / 67.8
}

#' Wind speed at 2 m above short grass
#'
#' @description
#' Converts the wind speed measured at a given height above the ground to
#' the wind speed at 2 m with the logarithmic wind profile of FAO-56, valid
#' for measurements above a short grass surface. It is the wind speed
#' entering the reference evapotranspiration ([ef_ref_et()]).
#'
#' @param wind_speed Numeric. Wind speed measured at `height`
#'   \eqn{u_z}{uz} \[m s-1\]. Must be finite and `>= 0`.
#' @param height Numeric. Height of the measurement above the ground
#'   \eqn{z}{z} \[m\]. Must be finite and greater than 6.42 / 67.8 =
#'   0.0947 m, where the logarithm becomes non-positive.
#'
#' @return A numeric vector of wind speed at 2 m \eqn{u_2}{u2} \[m s-1\]
#'   with the common length of the inputs, keeping their `dim`.
#'
#' @details
#' \deqn{u_2 = u_z \frac{4.87}{\ln(67.8 z - 5.42)}}{u2 = uz * 4.87 /
#'   log(67.8 * z - 5.42)}
#' (FAO-56, chapter 3, Eq. 47). At `height = 2` the factor is 1.00022, not
#' exactly 1 (FAO-56 annex 2, table 2.9 rounds it to 1.000); at 10 m it is
#' 0.74795 (table 2.9: 0.748).
#'
#' Assumption (FAO-56): logarithmic profile for measurements above a short
#' grass surface. This is **not** the extrapolation to the blending height
#' of METRIC, which uses the roughness of the station surface and the raw
#' station wind ([ef_blending_wind()]).
#'
#' Missing values propagate. Negative wind speeds, heights `<= 0.0947` m or
#' infinite values raise `earthflux_domain_error`.
#'
#' @section Verification status:
#' `VERIFICADA` (FAO-56, chapter 3, Eq. 47; cases V12 and V13). The same
#' equation is ASCE-EWRI (2005) Eq. 33 (p. 26) and Eq. 67 (p. 44; the text
#' on that page calls it "Eq. 68", a typographical error), for measurements
#' above clipped grass; the report directs wind measured above other
#' surfaces (e.g. alfalfa) to its Appendix B, not implemented here.
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
#' @family derived meteorological variables
#' @export
#'
#' @examples
#' # FAO-56 example 14: 3.2 m s-1 measured at 10 m
#' ef_wind_2m(wind_speed = 3.2, height = 10)
ef_wind_2m <- function(wind_speed, height) {
  call <- sys.call()
  args <- list(wind_speed = wind_speed, height = height)
  n <- check_core_args(args, call)
  check_in_range(wind_speed, "wind_speed", lower = 0, call = call)
  check_in_range(height, "height", lower = ef_wind_2m_min_height(),
                 lower_inclusive = FALSE, call = call)
  # FAO-56, chapter 3, Eq. 47.
  ef_reshape(wind_speed * 4.87 / log(67.8 * height - 5.42), n,
             common_dim(args))
}

# Extraterrestrial and clear-sky radiation -----------------------------------------

#' Daily extraterrestrial radiation
#'
#' @description
#' Computes the daily extraterrestrial radiation \eqn{R_a}{Ra}, the solar
#' radiation received on a horizontal surface at the top of the atmosphere
#' during one day, from the latitude and the day of year (FAO-56).
#'
#' @param lat Numeric. Latitude \eqn{\phi}{phi} \[rad\], in \[-pi/2, pi/2\],
#'   positive north. Degrees must be converted (`deg * pi / 180`, FAO-56
#'   Eq. 22).
#' @param doy Numeric. Day of year \eqn{J}{J}, whole number in 1-366.
#'
#' @return A numeric vector of daily extraterrestrial radiation
#'   \eqn{R_a}{Ra} \[MJ m-2 d-1\] with the common length of the inputs,
#'   keeping their `dim`.
#'
#' @details
#' \deqn{R_a = \frac{24 \cdot 60}{\pi} G_{sc} d_r \left[\omega_s \sin\phi
#'   \sin\delta + \cos\phi \cos\delta \sin\omega_s\right]}{Ra = 24 * 60 /
#'   pi * Gsc * dr * (ws * sin(phi) * sin(delta) + cos(phi) * cos(delta) *
#'   sin(ws))}
#' with \eqn{G_{sc}}{Gsc} = 0.0820 MJ m-2 min-1 (FAO-56, chapter 3,
#' Eq. 21; the package constant of the solar constant), the inverse relative
#' distance \eqn{d_r}{dr} (Eq. 23), the declination \eqn{\delta}{delta}
#' (Eq. 24) and the sunset hour angle
#' \eqn{\omega_s = \arccos(-\tan\phi \tan\delta)}{ws = acos(-tan(phi) *
#' tan(delta))} (Eq. 25). The declination and \eqn{d_r}{dr} are the
#' internal helpers shared with [ef_solar_geometry()].
#'
#' Polar day and night: where \eqn{|\tan\phi \tan\delta| > 1} the argument
#' of the arc cosine is limited to \[-1, 1\], which gives the geometric
#' limits \eqn{\omega_s = \pi}{ws = pi} (24 h of sun) and
#' \eqn{\omega_s = 0}{ws = 0} (no sun, \eqn{R_a = 0}{Ra = 0}). FAO-56
#' (Eqs. 26-27) handles the same case with X = 0.00001 and notes that the
#' daily equation has limited validity in winter at latitudes above 55
#' degrees (north or south).
#'
#' Missing values propagate. Latitudes outside \[-pi/2, pi/2\] (for example
#' given in degrees), `doy` outside 1-366 or infinite values raise
#' `earthflux_domain_error`; a non-integer `doy` raises
#' `earthflux_input_error`.
#'
#' @section Verification status:
#' `VERIFICADA` (FAO-56, chapter 3, Eqs. 21-25; cases V7 and V9: 20 degrees
#' S on 3 September gives 32.2 MJ m-2 d-1). The same equations are
#' ASCE-EWRI (2005) Eqs. 21-24 and 27-29 (pp. 23-25), written with
#' \eqn{G_{sc}}{Gsc} = 4.92 MJ m-2 h-1 and the factor 24 / pi (identical
#' to 0.0820 MJ m-2 min-1 and 24 * 60 / pi). The limitation of the arc
#' cosine argument in polar conditions is an implementation choice
#' (dev/specs/weather-forcing.md 13).
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
#' @family derived meteorological variables
#' @export
#'
#' @examples
#' # FAO-56 example 8: 20 degrees S, 3 September (J = 246)
#' ef_ra_daily(lat = -20 * pi / 180, doy = 246)
#'
#' # Annual course in central Chile
#' ra <- ef_ra_daily(lat = -35 * pi / 180, doy = 1:365)
#' range(ra)
ef_ra_daily <- function(lat, doy) {
  call <- sys.call()
  args <- list(lat = lat, doy = doy)
  n <- check_core_args(args, call)
  check_angle(lat, "lat", "lat", call)
  check_doy(doy, call)

  dr <- ef_inv_distance(doy)
  delta <- ef_declination(doy)
  ws <- ef_sunset_hour_angle(lat, delta)
  gsc <- EF_SOLAR_CONSTANT * 60 / 1e6 # W m-2 to MJ m-2 min-1 (0.0820)
  # FAO-56, chapter 3, Eq. 21.
  ra <- 24 * 60 / pi * gsc * dr *
    (ws * sin(lat) * sin(delta) + cos(lat) * cos(delta) * sin(ws))
  ef_reshape(ra, n, common_dim(args))
}

#' Extraterrestrial radiation of an hourly or shorter period
#'
#' @description
#' Computes the extraterrestrial radiation \eqn{R_a}{Ra} received on a
#' horizontal surface at the top of the atmosphere during a period of one
#' hour or less, from the latitude, the longitude, the day of year and the
#' UTC time of the midpoint of the period (FAO-56).
#'
#' @inheritParams ef_ra_daily
#' @param lon Numeric. Longitude \eqn{\lambda}{lambda} \[rad\], **positive
#'   east**, in \[-pi, pi\].
#' @param doy Numeric. Day of year of the **UTC** date of the midpoint of
#'   the period, whole number in 1-366.
#' @param utc_mid Numeric. UTC time of the midpoint of the period \[h\],
#'   decimal hours in \[0, 24). For a period 14:00-15:00 UTC, 14.5.
#' @param period_hours Numeric. Length of the period \eqn{t_1}{t1} \[h\], in
#'   (0, 1\] (1 for hourly, 0.5 for 30 min).
#' @param standard Character, no default. Treatment of the periods that
#'   contain sunrise or sunset: `"fao56"` (midpoint criterion of FAO-56:
#'   \eqn{R_a = 0}{Ra = 0} when the sun is below the horizon at the midpoint,
#'   otherwise the full integral) or `"asce"` (limits of integration set to
#'   the sunrise and sunset hour angles, ASCE-EWRI 2005 Eq. 56). See Details.
#'
#' @return A numeric vector of extraterrestrial radiation of the period
#'   \eqn{R_a}{Ra} \[MJ m-2 per period\] with the common length of the
#'   inputs, keeping their `dim`.
#'
#' @details
#' \deqn{R_a = \frac{12 \cdot 60}{\pi} G_{sc} d_r \left[(\omega_2 -
#'   \omega_1) \sin\phi \sin\delta + \cos\phi \cos\delta (\sin\omega_2 -
#'   \sin\omega_1)\right]}{Ra = 12 * 60 / pi * Gsc * dr * ((w2 - w1) *
#'   sin(phi) * sin(delta) + cos(phi) * cos(delta) * (sin(w2) - sin(w1)))}
#' with \eqn{\omega_1 = \omega - \pi t_1 / 24}{w1 = w - pi * t1 / 24} and
#' \eqn{\omega_2 = \omega + \pi t_1 / 24}{w2 = w + pi * t1 / 24} (FAO-56,
#' chapter 3, Eqs. 28-30). The hour angle at the midpoint
#' \eqn{\omega}{w} is FAO-56 Eq. 31 (with the seasonal correction
#' \eqn{S_c}{Sc} of Eqs. 32-33) written for UTC times and east-positive
#' longitudes,
#' \deqn{\omega = \frac{\pi}{12}\left[\left(t_{UTC} + \frac{12}{\pi}\lambda
#'   + S_c\right) \bmod 24 - 12\right]}{w = pi / 12 * ((t_utc + 12 / pi *
#'   lambda + Sc) mod 24 - 12)}
#' which equals FAO-56 Eq. 31 with \eqn{L_z = 0}{Lz = 0} and
#' \eqn{L_m = -\lambda}{Lm = -lambda} (FAO-56 counts longitudes positive
#' west), with the exact 1/15 h per degree instead of 0.06667 (decision
#' WF-10). It is computed by the internal hour angle of
#' [ef_solar_geometry()].
#'
#' The same equations are ASCE-EWRI (2005) Eqs. 48 and 50-58 (pp. 39-42),
#' with \eqn{G_{sc}}{Gsc} = 4.92 MJ m-2 h-1 (= 0.0820 MJ m-2 min-1) and
#' the same coefficients of \eqn{d_r}{dr}, \eqn{\delta}{delta},
#' \eqn{S_c}{Sc} and \eqn{b}{b}.
#'
#' **Sunrise and sunset** (`standard`, decision WF-10). With
#' `standard = "fao56"`, when the hour angle of the midpoint lies outside
#' \eqn{[-\omega_s, \omega_s]}{[-ws, ws]} (Eq. 25), \eqn{R_a = 0}{Ra = 0}
#' by definition (FAO-56 midpoint criterion); a period that contains sunrise
#' or sunset gets either its full integral or zero. With `standard =
#' "asce"`, the limits of integration are set with the conditionals of
#' ASCE-EWRI (2005) Eq. 56 (p. 41): \eqn{\omega_1}{w1} and
#' \eqn{\omega_2}{w2} are limited to \eqn{[-\omega_s, \omega_s]}{[-ws,
#' ws]} and \eqn{\omega_1 \le \omega_2}{w1 <= w2}, applied to every period
#' as the report allows ("can be applied for all timesteps"); a period
#' entirely below the horizon gets 0 and a period containing sunrise or
#' sunset gets the integral over its sunlit part. The report also states
#' (p. 41) that a midpoint outside \eqn{[-\omega_s, \omega_s]}{[-ws, ws]}
#' means \eqn{R_a = 0}{Ra = 0}; for a period whose midpoint is below the
#' horizon but which contains sunrise or sunset the two statements differ,
#' and Eq. 56 is followed. In polar day (\eqn{\omega_s = \pi}{ws = pi})
#' there is no sunrise or sunset and the limits are not changed (the
#' literal limitation to \eqn{[-\pi, \pi]}{[-pi, pi]} would cut the
#' periods around solar midnight).
#'
#' Missing values propagate. Values outside the domains above raise
#' `earthflux_domain_error`; a non-integer `doy` raises
#' `earthflux_input_error`.
#'
#' @section Verification status:
#' `standard = "fao56"`: `VERIFICADA` (FAO-56, chapter 3, Eqs. 28-33; case
#' V15: 14:00-15:00 local standard time on 1 October at 16 degrees 13' N,
#' 16 degrees 15' W gives 3.543 MJ m-2 h-1). `standard = "asce"`:
#' `VERIFICADA` (ASCE-EWRI, 2005, Eqs. 48, 53-58, pp. 39-42; Eq. 56 for the
#' limits of integration).
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
#' @family derived meteorological variables
#' @export
#'
#' @examples
#' deg <- pi / 180
#' # FAO-56 example 19: 1 October, 14:00-15:00 local standard time in a
#' # time zone 15 degrees west of Greenwich, i.e. 15:00-16:00 UTC
#' ef_ra_period(lat = (16 + 13 / 60) * deg, lon = -(16 + 15 / 60) * deg,
#'              doy = 274, utc_mid = 15.5, period_hours = 1,
#'              standard = "fao56")
#'
#' # Hourly course of one day (midpoints 00:30 ... 23:30 UTC): the two
#' # standards differ only in the periods containing sunrise and sunset
#' fao <- ef_ra_period(lat = -35 * deg, lon = 0, doy = 15,
#'                     utc_mid = 0:23 + 0.5, period_hours = 1,
#'                     standard = "fao56")
#' asce <- ef_ra_period(lat = -35 * deg, lon = 0, doy = 15,
#'                      utc_mid = 0:23 + 0.5, period_hours = 1,
#'                      standard = "asce")
#' which(fao != asce)
ef_ra_period <- function(lat, lon, doy, utc_mid, period_hours, standard) {
  call <- sys.call()
  check_method(if (missing(standard)) NULL else standard, c("asce", "fao56"),
               arg = "standard", call = call)
  args <- list(lat = lat, lon = lon, doy = doy, utc_mid = utc_mid,
               period_hours = period_hours)
  n <- check_core_args(args, call)
  check_angle(lat, "lat", "lat", call)
  check_angle(lon, "lon", "lon", call)
  check_doy(doy, call)
  check_in_range(utc_mid, "utc_mid", lower = 0, upper = 24,
                 upper_inclusive = FALSE, call = call)
  check_in_range(period_hours, "period_hours", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)

  dr <- ef_inv_distance(doy)
  delta <- ef_declination(doy)
  omega <- ef_hour_angle(doy, utc_mid, lon)
  ws <- ef_sunset_hour_angle(lat, delta)
  # FAO-56, chapter 3, Eqs. 29-30 (ASCE-EWRI 2005, Eqs. 53-54).
  w1 <- rep_len(as.vector(omega - pi * period_hours / 24), n)
  w2 <- rep_len(as.vector(omega + pi * period_hours / 24), n)
  if (standard == "asce") {
    # ASCE-EWRI (2005), Eq. 56: limits of integration within [-ws, ws] and
    # w1 <= w2 (not in polar day, ws = pi, where the sun does not set).
    ws_n <- rep_len(as.vector(ws), n)
    clip <- !is.na(ws_n) & ws_n < pi
    w1[clip] <- pmin(pmax(w1[clip], -ws_n[clip]), ws_n[clip])
    w2[clip] <- pmin(pmax(w2[clip], -ws_n[clip]), ws_n[clip])
    swap <- !is.na(w1) & !is.na(w2) & w1 > w2
    w1[swap] <- w2[swap]
  }
  gsc <- EF_SOLAR_CONSTANT * 60 / 1e6 # W m-2 to MJ m-2 min-1 (0.0820)
  # FAO-56, chapter 3, Eq. 28 (ASCE-EWRI 2005, Eq. 48).
  ra <- 12 * 60 / pi * gsc * dr *
    ((w2 - w1) * sin(lat) * sin(delta) +
       cos(lat) * cos(delta) * (sin(w2) - sin(w1)))
  if (standard == "fao56") {
    # Midpoint criterion: sun below the horizon at the midpoint -> Ra = 0.
    below <- !is.na(omega) & !is.na(ws) & (omega < -ws | omega > ws)
    ra[below & !is.na(ra)] <- 0
  }
  ef_reshape(as.vector(ra), n, common_dim(args))
}

#' Clear-sky solar radiation
#'
#' @description
#' Computes the clear-sky solar radiation \eqn{R_{so}}{Rso}, the solar
#' radiation that would reach a horizontal surface under a cloudless sky,
#' from the extraterrestrial radiation and the elevation (FAO-56). It is the
#' reference of the cloudiness term of the net longwave radiation of the
#' reference surface ([ef_ref_net_radiation()]).
#'
#' @param extraterrestrial Numeric. Extraterrestrial radiation
#'   \eqn{R_a}{Ra} \[MJ m-2 per day or per period\], from [ef_ra_daily()] or
#'   [ef_ra_period()]. Must be finite and `>= 0`.
#' @param elevation Numeric. Elevation of the site above sea level
#'   \eqn{z}{z} \[m\], finite.
#'
#' @return A numeric vector of clear-sky radiation \eqn{R_{so}}{Rso} in the
#'   unit of `extraterrestrial` \[MJ m-2 per day or per period\], with the
#'   common length of the inputs, keeping their `dim`.
#'
#' @details
#' \deqn{R_{so} = (0.75 + 2 \times 10^{-5} z) R_a}{Rso = (0.75 + 2e-5 * z)
#'   * Ra}
#' (FAO-56, chapter 3, Eq. 37 = annex 3, Eq. 3-13). FAO-56 (annex 3, after
#' Allen, 1996) states that it is a good approximation for **daily and
#' hourly** periods at elevations below 6000 m and low turbidity, obtained
#' by linearising Beer's law with elevation for a mean sun angle of about
#' 50 degrees. Elevations outside that range are not rejected (the bound is
#' a validity statement, not a physical limit). The forms with turbidity and
#' precipitable water (annex 3, Eqs. 3-14 to 3-20), for high turbidity or
#' low sun angles, are not implemented (decision WF-12: Eq. 37 is the
#' standard form for the reference surface; the variants serve quality
#' control).
#'
#' Missing values propagate. Negative or infinite radiation and infinite
#' elevations raise `earthflux_domain_error`.
#'
#' @section Verification status:
#' `VERIFICADA` (FAO-56, chapter 3, Eq. 37; annex 3, Eq. 3-13; cases V14
#' and V15). The same equation is the default clear-sky radiation of the
#' ASCE-EWRI (2005) standardized procedure for daily (Eq. 19, p. 22) and
#' hourly periods (Eq. 47, p. 37); the report reserves the more complex
#' forms of its Appendix D for assessing the solar radiation data.
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
#' @family derived meteorological variables
#' @export
#'
#' @examples
#' # FAO-56 example 18 (Uccle, 100 m): Ra = 41.09 MJ m-2 d-1
#' ef_rso(extraterrestrial = 41.09, elevation = 100)
ef_rso <- function(extraterrestrial, elevation) {
  call <- sys.call()
  args <- list(extraterrestrial = extraterrestrial, elevation = elevation)
  n <- check_core_args(args, call)
  check_in_range(extraterrestrial, "extraterrestrial", lower = 0,
                 call = call)
  check_in_range(elevation, "elevation", call = call)
  # FAO-56, chapter 3, Eq. 37 (annex 3, Eq. 3-13).
  ef_reshape((0.75 + 2e-5 * elevation) * extraterrestrial, n,
             common_dim(args))
}
