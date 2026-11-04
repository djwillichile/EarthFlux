# Solar geometry ---------------------------------------------------------------
#
# Purpose: position of the sun relative to a horizontal or tilted pixel at a
#   given instant, shared by the radiation components of METRIC
#   (R/metric-radiation.R) and by the extraterrestrial radiation of the
#   reference ET (dev/specs/weather-forcing.md section 4.6, which requires
#   the declination, the inverse relative distance and the equation of time
#   to be implemented once and reused).
#
# Specification: dev/specs/radiation-components.md section 6.1; time inputs
#   dev/specs/modis-products.md section 6; FAO-56 verification of the
#   calendar terms in dev/specs/weather-forcing.md section 4.6.
#
# Implemented:
#   - ef_solar_geometry() (exported): cos of the solar zenith angle, cos of
#     the incidence angle on the pixel plane, declination, hour angle and
#     inverse relative Earth-Sun distance.
#   - Internal auxiliaries (decision RC-05: small public API), tested on
#     their own: ef_declination(), ef_inv_distance(), ef_equation_of_time(),
#     ef_hour_angle(), ef_cos_incidence().
#
# Conventions (decisions RC-01, RC-02, RC-03; dev/ARCHITECTURE.md 3.1):
#   - every angle in radians, latitude and longitude included (longitude
#     positive east); aspect in the GIS convention (clockwise from north,
#     [0, 2 pi)), converted internally to the solar azimuth of the surface
#     gamma = aspect - pi (0 = facing south, east negative, west positive);
#   - time as numeric `doy` (day of year of the UTC date) and `utc_hour`
#     (decimal hours, [0, 24)); the equation of time is applied exactly once,
#     in ef_hour_angle(). MODIS MOD11A1 view times are local MEAN solar time
#     (UTC + lon_deg / 15) and must be converted to UTC before reaching the
#     core (dev/specs/modis-products.md 6.1-6.2); apparent solar times must
#     not be passed (the equation of time would be applied twice).
#
# Verification status: declination, inverse relative distance, equation of
#   time and hour angle are VERIFICADA against FAO-56 (Eqs. 23, 24, 31-33;
#   dev/specs/weather-forcing.md 4.6). The cosine of the incidence angle on a
#   tilted plane is CANDIDATA (form attributed to solar engineering texts,
#   primary source and its use in Allen et al., 2007, not verified).

# Input checks of the geometry -------------------------------------------------

#' Check that the finite values of a numeric argument are whole numbers
#'
#' Missing and non-finite values are ignored here (they propagate or are
#' rejected by `check_in_range()`).
#'
#' @inheritParams check_numeric
#' @return `x`, invisibly, if the check passes; otherwise an error of class
#'   `earthflux_input_error`.
#' @noRd
check_whole <- function(x, arg = deparse(substitute(x)), call = sys.call(-1)) {
  vals <- x[is.finite(x)]
  n_bad <- sum(vals != round(vals))
  if (n_bad > 0L) {
    ef_abort(
      sprintf(
        "`%s` must contain whole numbers; found %d non-integer value(s).",
        arg, n_bad
      ),
      class = "earthflux_input_error",
      call = call
    )
  }
  invisible(x)
}

#' Validate the day of year
#'
#' @param doy Day of year of the UTC date, 1-366.
#' @param call The call to report.
#' @return `doy`, invisibly.
#' @noRd
check_doy <- function(doy, call) {
  check_whole(doy, "doy", call = call)
  check_in_range(doy, "doy", lower = 1, upper = 366, call = call)
  invisible(doy)
}

#' Validate an angle argument against its domain in radians
#'
#' @param x Numeric angle \[rad\].
#' @param arg Argument name.
#' @param kind One of `"lat"` (\[-pi/2, pi/2\]), `"lon"` (\[-pi, pi\]),
#'   `"slope"` (\[0, pi/2\]), `"aspect"` (\[0, 2 pi)), `"hour_angle"`
#'   (\[-pi, pi\]).
#' @param call The call to report.
#' @return `x`, invisibly.
#' @noRd
check_angle <- function(x, arg, kind, call) {
  switch(kind,
    lat = check_in_range(x, arg, lower = -pi / 2, upper = pi / 2,
                         call = call),
    lon = check_in_range(x, arg, lower = -pi, upper = pi, call = call),
    slope = check_in_range(x, arg, lower = 0, upper = pi / 2, call = call),
    aspect = check_in_range(x, arg, lower = 0, upper = 2 * pi,
                            upper_inclusive = FALSE, call = call),
    hour_angle = check_in_range(x, arg, lower = -pi, upper = pi, call = call)
  )
  invisible(x)
}

#' Validate type, length and dim of a set of arguments
#'
#' @param args Named list of arguments.
#' @param call The call to report.
#' @return The common length `n`, invisibly.
#' @noRd
check_core_args <- function(args, call) {
  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)
  invisible(n)
}

#' Expand a result to the common length and dim of a call
#'
#' @param x Numeric vector of length 1 or `n`.
#' @param n Common length.
#' @param d The common `dim` (or `NULL`).
#' @return `x` recycled to length `n`, with `dim` `d`.
#' @noRd
ef_reshape <- function(x, n, d) {
  out <- rep_len(as.vector(x), n)
  dim(out) <- d
  out
}

#' Common dim of a list of arguments
#'
#' @param args Named list of arguments already checked with
#'   `check_same_dim()`.
#' @return The `dim` shared by the arguments that have one, or `NULL`.
#' @noRd
common_dim <- function(args) {
  dims <- lapply(args, dim)
  dims <- dims[!vapply(dims, is.null, logical(1))]
  if (length(dims) == 0L) NULL else dims[[1L]]
}

# Auxiliary geometric quantities (internal, RC-05) -----------------------------

#' Solar declination
#'
#' Solar declination \eqn{\delta} \[rad\] from the day of year (FAO-56,
#' chapter 3, Eq. 24):
#' \deqn{\delta = 0.409 \sin\left(\frac{2\pi J}{365} - 1.39\right)}
#'
#' @param doy Numeric. Day of year \eqn{J} of the UTC date, whole number in
#'   1-366. FAO-56 uses the same 365-day expression for \eqn{J = 366}.
#' @return Numeric declination \[rad\], same length and `dim` as `doy`.
#'   Errors: non-integer `doy` -> `earthflux_input_error`; outside 1-366 ->
#'   `earthflux_domain_error`. `NA` propagates.
#' @section Verification status: `VERIFICADA` (FAO-56, chapter 3, Eq. 24;
#'   dev/specs/weather-forcing.md 4.6).
#' @references Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998).
#'   FAO Irrigation and Drainage Paper 56. FAO, Rome.
#' @noRd
ef_declination <- function(doy) {
  call <- sys.call()
  check_core_args(list(doy = doy), call)
  check_doy(doy, call)
  # FAO-56, chapter 3, Eq. 24 (normative coefficients as literals, WF-14).
  0.409 * sin(2 * pi * doy / 365 - 1.39)
}

#' Inverse relative distance Earth-Sun
#'
#' Inverse relative distance Earth-Sun \eqn{d_r} \[-\] (FAO-56, chapter 3,
#' Eq. 23):
#' \deqn{d_r = 1 + 0.033 \cos\left(\frac{2\pi J}{365}\right)}
#'
#' @inheritParams ef_declination
#' @return Numeric \eqn{d_r} \[-\], same length and `dim` as `doy`. Errors and
#'   `NA` as in `ef_declination()`.
#' @section Verification status: `VERIFICADA` (FAO-56, chapter 3, Eq. 23).
#' @noRd
ef_inv_distance <- function(doy) {
  call <- sys.call()
  check_core_args(list(doy = doy), call)
  check_doy(doy, call)
  # FAO-56, chapter 3, Eq. 23.
  1 + 0.033 * cos(2 * pi * doy / 365)
}

#' Equation of time (seasonal correction for solar time)
#'
#' Seasonal correction for solar time \eqn{S_c} \[h\] (FAO-56, chapter 3,
#' Eqs. 32-33):
#' \deqn{b = \frac{2\pi (J - 81)}{364}, \quad
#'   S_c = 0.1645 \sin(2b) - 0.1255 \cos b - 0.025 \sin b}
#'
#' @inheritParams ef_declination
#' @return Numeric \eqn{S_c} \[h\], same length and `dim` as `doy`. Errors
#'   and `NA` as in `ef_declination()`.
#' @section Verification status: `VERIFICADA` (FAO-56, chapter 3, Eqs. 32
#'   and 33).
#' @noRd
ef_equation_of_time <- function(doy) {
  call <- sys.call()
  check_core_args(list(doy = doy), call)
  check_doy(doy, call)
  # FAO-56, chapter 3, Eq. 33 (b) and Eq. 32 (Sc).
  b <- 2 * pi * (doy - 81) / 364
  0.1645 * sin(2 * b) - 0.1255 * cos(b) - 0.025 * sin(b)
}

#' Solar hour angle
#'
#' Hour angle \eqn{\omega} \[rad\] at a UTC instant and an east-positive
#' longitude. The local apparent solar time is
#' \deqn{t_s = \left(t_{UTC} + \lambda \frac{12}{\pi} + S_c\right) \bmod 24}
#' and \eqn{\omega = \frac{\pi}{12}(t_s - 12)}, negative in the morning,
#' in \[-pi, pi). This is FAO-56 Eq. 31 written for UTC times (\eqn{L_z = 0})
#' with \eqn{L_m = -\lambda} (FAO-56 counts longitudes positive west) and the
#' exact 1/15 h per degree in place of the rounded 0.06667 (decision WF-10;
#' dev/specs/weather-forcing.md 4.6). The reduction modulo 24 h makes the
#' result independent of the longitude convention.
#'
#' The equation of time \eqn{S_c} is applied here and only here: `utc_hour`
#' must be a UTC time, not a local (mean or apparent) solar time.
#'
#' @inheritParams ef_declination
#' @param utc_hour Numeric. UTC time of day \[h\], in \[0, 24).
#' @param lon Numeric. Longitude \[rad\], positive east, in \[-pi, pi\].
#' @return Numeric \eqn{\omega} \[rad\] with the common length (and `dim`) of
#'   the inputs. Classed errors for type, length, `dim` and domain; `NA`
#'   propagates.
#' @section Verification status: `VERIFICADA` (algebraic rewriting of FAO-56,
#'   chapter 3, Eqs. 31-33).
#' @noRd
ef_hour_angle <- function(doy, utc_hour, lon) {
  call <- sys.call()
  check_core_args(list(doy = doy, utc_hour = utc_hour, lon = lon), call)
  check_doy(doy, call)
  check_in_range(utc_hour, "utc_hour", lower = 0, upper = 24,
                 upper_inclusive = FALSE, call = call)
  check_angle(lon, "lon", "lon", call)

  # Longitude in radians to hours: lambda * 180 / pi / 15 = lambda * 12 / pi.
  solar_time <- (utc_hour + lon * 12 / pi + ef_equation_of_time(doy)) %% 24
  pi / 12 * (solar_time - 12)
}

#' Cosine of the solar incidence angle on a tilted plane
#'
#' Cosine of the angle between the solar beam and the normal of a plane of
#' slope \eqn{s} and GIS aspect \eqn{A}, with
#' \eqn{\gamma = A - \pi} (0 = facing south, east negative, west positive):
#' \deqn{\cos\theta_{rel} = \sin\delta \sin\phi \cos s
#'   - \sin\delta \cos\phi \sin s \cos\gamma
#'   + \cos\delta \cos\phi \cos s \cos\omega
#'   + \cos\delta \sin\phi \sin s \cos\gamma \cos\omega
#'   + \cos\delta \sin\gamma \sin s \sin\omega}
#' With \eqn{s = 0} it reduces to the cosine of the solar zenith angle.
#' Values \eqn{\le 0} (plane facing away from the sun, or sun below the
#' horizon) are returned unchanged; the consumers decide their treatment.
#'
#' @param lat Numeric. Latitude \[rad\], in \[-pi/2, pi/2\].
#' @param declination Numeric. Solar declination \[rad\], in \[-pi/2, pi/2\].
#' @param hour_angle Numeric. Hour angle \[rad\], in \[-pi, pi\].
#' @param slope Numeric. Slope of the plane \[rad\], in \[0, pi/2\].
#' @param aspect Numeric. Aspect of the plane \[rad\], GIS convention
#'   (clockwise from north), in \[0, 2 pi).
#' @return Numeric \eqn{\cos\theta_{rel}} \[-\] with the common length (and
#'   `dim`) of the inputs.
#' @section Verification status: `CANDIDATA` (incidence angle on an
#'   arbitrarily oriented plane from solar engineering texts, e.g. Duffie and
#'   Beckman; primary reference, equation number and its use in Allen et
#'   al., 2007, not verified; dev/specs/radiation-components.md 6.1).
#' @noRd
ef_cos_incidence <- function(lat, declination, hour_angle, slope, aspect) {
  call <- sys.call()
  check_core_args(
    list(lat = lat, declination = declination, hour_angle = hour_angle,
         slope = slope, aspect = aspect),
    call
  )
  check_angle(lat, "lat", "lat", call)
  check_angle(declination, "declination", "lat", call)
  check_angle(hour_angle, "hour_angle", "hour_angle", call)
  check_angle(slope, "slope", "slope", call)
  check_angle(aspect, "aspect", "aspect", call)

  gamma <- aspect - pi
  sin_d <- sin(declination)
  cos_d <- cos(declination)
  sin_p <- sin(lat)
  cos_p <- cos(lat)
  sin_s <- sin(slope)
  cos_s <- cos(slope)
  cos_w <- cos(hour_angle)

  sin_d * sin_p * cos_s -
    sin_d * cos_p * sin_s * cos(gamma) +
    cos_d * cos_p * cos_s * cos_w +
    cos_d * sin_p * sin_s * cos(gamma) * cos_w +
    cos_d * sin(gamma) * sin_s * sin(hour_angle)
}

# Exported wrapper -------------------------------------------------------------

#' Solar geometry at the overpass time
#'
#' @description
#' Computes, for each pixel and its overpass instant, the position of the
#' sun relative to the horizontal and to the tilted plane of the pixel: the
#' cosine of the solar zenith angle, the cosine of the solar incidence angle
#' on the pixel plane, the solar declination, the hour angle and the inverse
#' relative Earth-Sun distance. These are the geometric inputs of the
#' shortwave transmissivity (`ef_tau_sw()`) and of the incoming shortwave
#' radiation (`ef_rs_in()`).
#'
#' @param doy Numeric. Day of year of the **UTC** date of the instant
#'   \[-\]: a whole number in 1-366.
#' @param utc_hour Numeric. UTC time of day of the instant \[h\], decimal
#'   hours in \[0, 24). It must be a UTC time (see Details).
#' @param lat Numeric. Latitude \[rad\], in \[-pi/2, pi/2\] (pixel centre,
#'   WGS84).
#' @param lon Numeric. Longitude \[rad\], positive east, in \[-pi, pi\].
#' @param slope Numeric. Slope of the pixel plane \[rad\], in \[0, pi/2\].
#'   Default `0` (horizontal plane).
#' @param aspect Numeric. Aspect of the pixel plane \[rad\], GIS convention
#'   (clockwise from geographic north: 0 north, pi/2 east, pi south, 3 pi/2
#'   west), in \[0, 2 pi). Default `0`; irrelevant when `slope = 0`, but an
#'   `NA` aspect still propagates (decision RC-16).
#'
#' @return A plain list (no class) of numeric vectors, all with the common
#'   length of the inputs and, if the inputs include matrices or arrays,
#'   their common `dim`:
#'   * `cos_zenith`: cosine of the solar zenith angle on the horizontal
#'     \eqn{\cos\theta_h}{cos(theta_h)} \[-\];
#'   * `cos_incidence`: cosine of the solar incidence angle on the pixel
#'     plane \eqn{\cos\theta_{rel}}{cos(theta_rel)} \[-\];
#'   * `declination`: solar declination \eqn{\delta}{delta} \[rad\];
#'   * `hour_angle`: hour angle \eqn{\omega}{omega} \[rad\], in \[-pi, pi),
#'     negative in the morning;
#'   * `inv_distance`: inverse relative Earth-Sun distance
#'     \eqn{d_r}{dr} \[-\].
#'
#'   Values of `cos_zenith` or `cos_incidence` \eqn{\le 0}{<= 0} (sun below
#'   the horizon, or plane facing away from the sun) are returned unchanged:
#'   their treatment belongs to the consuming functions.
#'
#' @details
#' With \eqn{J}{J} = `doy`, \eqn{\phi}{phi} = `lat`, \eqn{\lambda}{lambda} =
#' `lon`, \eqn{s}{s} = `slope` and \eqn{A}{A} = `aspect`:
#' \deqn{\delta = 0.409 \sin\left(\frac{2\pi J}{365} - 1.39\right), \quad
#'   d_r = 1 + 0.033 \cos\left(\frac{2\pi J}{365}\right)}{delta = 0.409 *
#'   sin(2 * pi * J / 365 - 1.39), dr = 1 + 0.033 * cos(2 * pi * J / 365)}
#' \deqn{b = \frac{2\pi (J - 81)}{364}, \quad
#'   S_c = 0.1645 \sin 2b - 0.1255 \cos b - 0.025 \sin b}{b = 2 * pi *
#'   (J - 81) / 364, Sc = 0.1645 * sin(2b) - 0.1255 * cos(b) - 0.025 *
#'   sin(b)}
#' \deqn{t_s = \left(t_{UTC} + \frac{12}{\pi}\lambda + S_c\right) \bmod 24,
#'   \quad \omega = \frac{\pi}{12}(t_s - 12)}{ts = (utc_hour + 12 / pi *
#'   lambda + Sc) mod 24, omega = pi / 12 * (ts - 12)}
#' \deqn{\cos\theta_h = \sin\delta \sin\phi + \cos\delta \cos\phi
#'   \cos\omega}{cos(theta_h) = sin(delta) sin(phi) + cos(delta) cos(phi)
#'   cos(omega)}
#' and, with \eqn{\gamma = A - \pi}{gamma = A - pi} (surface azimuth: 0
#' facing south, east negative, west positive),
#' \deqn{\cos\theta_{rel} = \sin\delta \sin\phi \cos s - \sin\delta \cos\phi
#'   \sin s \cos\gamma + \cos\delta \cos\phi \cos s \cos\omega + \cos\delta
#'   \sin\phi \sin s \cos\gamma \cos\omega + \cos\delta \sin\gamma \sin s
#'   \sin\omega}{cos(theta_rel) = sin(delta) sin(phi) cos(s) - sin(delta)
#'   cos(phi) sin(s) cos(gamma) + cos(delta) cos(phi) cos(s) cos(omega) +
#'   cos(delta) sin(phi) sin(s) cos(gamma) cos(omega) + cos(delta)
#'   sin(gamma) sin(s) sin(omega)}
#' which reduces to \eqn{\cos\theta_h}{cos(theta_h)} when \eqn{s = 0}{s = 0}.
#'
#' **Time.** The equation of time \eqn{S_c}{Sc} is applied exactly once,
#' here. `utc_hour` must therefore be a UTC time. The daytime view time of
#' MODIS MOD11A1/MYD11A1 is local **mean** solar time (UTC plus the
#' longitude in degrees divided by 15) and must be converted to UTC first,
#' as \eqn{t_{UTC} = (t_{ls} - \lambda_{deg}/15) \bmod 24}{t_utc = (t_ls -
#' lon_deg / 15) mod 24}, with `doy` the day of year of the UTC date of the
#' file. A local **apparent** solar time must not be converted this way: the
#' equation of time would be applied twice. The declination and
#' \eqn{d_r}{dr} are evaluated at the UTC date, which can differ by one day
#' from the local solar date.
#'
#' **Angles** are in radians throughout (decision RC-01). A latitude given
#' in degrees by mistake (e.g. -35) lies outside \[-pi/2, pi/2\] and raises an
#' error; a small slope given in degrees (e.g. 1) cannot be detected.
#'
#' Assumptions: low-precision calendar formulae of FAO-56, with the same
#' 365-day expressions in leap years; no atmospheric refraction; only
#' self-shading is represented (no cast shadows from surrounding relief, and
#' no reduction of the sky view by the horizon).
#'
#' Arguments must be numeric and have length 1 or a common length; length-1
#' arguments are recycled, matrix or array arguments must share their `dim`.
#' A non-integer `doy` raises `earthflux_input_error`; values outside the
#' domains above, or infinite values, raise `earthflux_domain_error` (also
#' `earthflux_input_error`). Missing values propagate to the outputs that
#' depend on them.
#'
#' @section Verification status:
#' The declination, the inverse relative distance, the equation of time and
#' the hour angle are `VERIFICADA` against FAO-56 (chapter 3, Eqs. 23, 24
#' and 31-33; the hour angle is Eq. 31 written for UTC times, with the exact
#' 1/15 h per degree instead of 0.06667). The zenith angle relation is the
#' standard spherical-trigonometry identity; the incidence angle on a
#' tilted plane is `CANDIDATA` (form from solar engineering texts; primary
#' reference and its use in Allen et al., 2007, to be verified). The
#' precision of the FAO-56 calendar formulae against a higher-precision
#' ephemeris has not been quantified (decision RC-04).
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @family radiation functions
#' @export
#'
#' @examples
#' deg <- pi / 180
#' # Horizontal pixel in central Chile, 15 January, 14:30 UTC
#' ef_solar_geometry(doy = 15, utc_hour = 14.5, lat = -35 * deg,
#'                   lon = -71 * deg)
#'
#' # North- and south-facing 20 degree slopes at the same instant
#' geo <- ef_solar_geometry(doy = 15, utc_hour = 14.5, lat = -35 * deg,
#'                          lon = -71 * deg, slope = 20 * deg,
#'                          aspect = c(0, 180) * deg)
#' geo$cos_incidence
#'
#' # MOD11A1 view time (local mean solar time, h) converted to UTC first
#' lon_deg <- -71
#' view_time <- 10.6
#' utc_hour <- (view_time - lon_deg / 15) %% 24
#' ef_solar_geometry(doy = 15, utc_hour = utc_hour, lat = -35 * deg,
#'                   lon = lon_deg * deg)$cos_zenith
ef_solar_geometry <- function(doy, utc_hour, lat, lon, slope = 0,
                              aspect = 0) {
  call <- sys.call()
  args <- list(doy = doy, utc_hour = utc_hour, lat = lat, lon = lon,
               slope = slope, aspect = aspect)
  n <- check_core_args(args, call)
  check_doy(doy, call)
  check_in_range(utc_hour, "utc_hour", lower = 0, upper = 24,
                 upper_inclusive = FALSE, call = call)
  check_angle(lat, "lat", "lat", call)
  check_angle(lon, "lon", "lon", call)
  check_angle(slope, "slope", "slope", call)
  check_angle(aspect, "aspect", "aspect", call)
  d <- common_dim(args)

  declination <- ef_declination(doy)
  inv_distance <- ef_inv_distance(doy)
  hour_angle <- ef_hour_angle(doy, utc_hour, lon)

  cos_zenith <- sin(declination) * sin(lat) +
    cos(declination) * cos(lat) * cos(hour_angle)
  cos_incidence <- ef_cos_incidence(lat, declination, hour_angle, slope,
                                    aspect)

  list(
    cos_zenith = ef_reshape(cos_zenith, n, d),
    cos_incidence = ef_reshape(cos_incidence, n, d),
    declination = ef_reshape(declination, n, d),
    hour_angle = ef_reshape(hour_angle, n, d),
    inv_distance = ef_reshape(inv_distance, n, d)
  )
}
