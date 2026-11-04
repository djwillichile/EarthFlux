# METRIC: radiation components and net radiation (Rn) ----------------------------
#
# Purpose: net radiation at the land surface and its components.
#
# Implemented:
#   - ef_net_radiation(): instantaneous surface radiation balance from its
#     four components. Specification: dev/specs/ef_net_radiation.md.
#     Equation status: CANDIDATA (corroborated by secondary sources);
#     verification against the primary reference is pending.
#   - Radiation components that produce its inputs
#     (dev/specs/radiation-components.md; solar geometry in
#     R/solar-geometry.R):
#       ef_tau_sw() dispatcher with ef_tau_sw_allen() and
#         ef_tau_sw_elevation() (clear-sky shortwave transmissivity);
#         returns an earthflux_sw_transmissivity object;
#       ef_atm_emissivity() (effective atmospheric emissivity);
#       ef_rs_in() dispatcher with ef_rs_in_modelled() and
#         ef_rs_in_measured() (incoming shortwave on the pixel plane), both
#         projected to the plane by the internal ef_rs_to_slope(); returns
#         an earthflux_incoming_shortwave object;
#       ef_rl_in() (incoming longwave; temperature input agnostic, decision
#         RC-12 open) and ef_rl_out() (longwave emitted by the surface).
#     Every form is CANDIDATA except where its roxygen says otherwise.
#   - ef_diagnose_radiation() (internal): cell-scope flags EF_RAD_* of this
#     stage, built from the numeric inputs and outputs (never by the numeric
#     functions themselves) and called by the dispatchers.
#
# Dispatchers (dev/ARCHITECTURE.md section 3.2, point 4): they check
#   `method`, call the method function, build the flags (EF_INPUT_NA and the
#   EF_RAD_ codes that apply) and return a classed object; the method
#   functions return plain numeric values or plain lists.
#
# Design: sensor-independent, purely arithmetic and vectorised. Emissivity is
#   an explicit input and the reflected incoming longwave term is kept
#   explicit (dev/SCIENTIFIC_SPEC.md, section 3, net radiation row).
#   Unverified choices (turbidity, temperature of the incoming longwave,
#   source of the diffuse fraction) are explicit arguments without defaults.

#' Net radiation at the land surface
#'
#' @description
#' Computes the instantaneous net radiation \eqn{R_n}{Rn} at the land surface,
#' i.e. the radiant energy available at the surface for the soil, sensible
#' and latent heat fluxes, as the balance between the absorbed incoming
#' shortwave radiation, the incoming longwave radiation, the longwave
#' radiation emitted by the surface and the part of the incoming longwave
#' radiation that the surface reflects. This is the surface radiation balance
#' used in the METRIC energy balance model.
#'
#' @param rs_in Numeric. Incoming (downwelling) shortwave radiation at the
#'   surface, instantaneous at the satellite overpass time \[W m-2\]. Must be
#'   finite and `>= 0`.
#' @param albedo Numeric. Broadband surface albedo \[-\]. Must lie in
#'   \[0, 1\].
#' @param rl_in Numeric. Incoming (downwelling) longwave radiation at the
#'   surface \[W m-2\]. Must be finite and `> 0`.
#' @param rl_out Numeric. Longwave radiation **emitted** by the surface
#'   \[W m-2\], i.e. \eqn{\varepsilon_0 \sigma T_s^4}{e0 * sigma * Ts^4}. It
#'   must not include the reflected incoming longwave component, which the
#'   function accounts for separately. Must be finite and `> 0`.
#' @param emissivity Numeric. Broadband surface emissivity
#'   \eqn{\varepsilon_0}{e0} \[-\]. Must lie in (0, 1\]. It must be the same
#'   emissivity used to compute `rl_out`; ensuring this consistency is the
#'   responsibility of the caller.
#'
#' @return A numeric vector of net radiation \eqn{R_n}{Rn} \[W m-2\] with the
#'   common length of the inputs. If the inputs include matrices or arrays
#'   (all with the same `dim`), the result keeps that `dim`. Negative values
#'   are physically possible (e.g. at night or over snow) and are returned
#'   unchanged.
#'
#' @details
#' The surface radiation balance is
#' \deqn{R_n = (1 - \alpha) R_{s\downarrow} + R_{L\downarrow} - R_{L\uparrow}
#'   - (1 - \varepsilon_0) R_{L\downarrow}}{Rn = (1 - albedo) * rs_in + rl_in
#'   - rl_out - (1 - emissivity) * rl_in}
#' where \eqn{\alpha}{albedo} is `albedo`, \eqn{R_{s\downarrow}}{rs_in} is
#' `rs_in`, \eqn{R_{L\downarrow}}{rl_in} is `rl_in`,
#' \eqn{R_{L\uparrow}}{rl_out} is `rl_out` and
#' \eqn{\varepsilon_0}{e0} is `emissivity`. The last term is the incoming
#' longwave radiation reflected by the surface.
#'
#' Assumptions:
#' * all fluxes are instantaneous and refer to the same time (the satellite
#'   overpass);
#' * the balance is one-dimensional (per pixel or per point), with no
#'   lateral exchange;
#' * `emissivity` is the emissivity used to obtain `rl_out` from the surface
#'   temperature.
#'
#' If `rl_out` already contains the total upwelling longwave radiation
#' (emitted plus reflected), for example from a radiometer measurement, the
#' equivalent call is `emissivity = 1`, which removes the reflected term and
#' avoids counting it twice.
#'
#' Missing values (`NA`, `NaN`) in any input propagate to the corresponding
#' output element, without errors or warnings. Diagnostic flags for missing
#' inputs are assembled by the orchestration layer, not by this function.
#'
#' Arguments must be numeric (double or integer) and have length 1 or a
#' common length; length-1 arguments are recycled. Values outside the domain
#' (`albedo` outside \[0, 1\], `emissivity` outside (0, 1\], negative `rs_in`,
#' non-positive `rl_in` or `rl_out`, or any infinite value) raise an error
#' of class `earthflux_domain_error` (also `earthflux_input_error`) that
#' names the argument and the number of offending values. Invalid inputs are
#' expected to be masked or flagged upstream by quality control; values are
#' never silently corrected.
#'
#' The form of the equation has been cross-checked against independent
#' secondary sources; verification against the primary reference (Allen et
#' al., 2007) is pending.
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @family radiation functions
#' @export
#'
#' @examples
#' # Single pixel: rl_out = 0.98 * 5.67e-8 * 300^4 (surface at 300 K)
#' ef_net_radiation(
#'   rs_in = 800, albedo = 0.20, rl_in = 320,
#'   rl_out = 450.0846, emissivity = 0.98
#' )
#'
#' # Several pixels sharing one incoming longwave value (recycled)
#' ef_net_radiation(
#'   rs_in = c(750, 800, 820),
#'   albedo = c(0.15, 0.20, 0.25),
#'   rl_in = 320,
#'   rl_out = c(440, 450, 470),
#'   emissivity = c(0.97, 0.98, 0.96)
#' )
#'
#' # rl_out given as total upwelling longwave (emitted + reflected)
#' ef_net_radiation(
#'   rs_in = 800, albedo = 0.20, rl_in = 320,
#'   rl_out = 456.4846, emissivity = 1
#' )
ef_net_radiation <- function(rs_in, albedo, rl_in, rl_out, emissivity) {
  call <- sys.call()
  args <- list(
    rs_in = rs_in,
    albedo = albedo,
    rl_in = rl_in,
    rl_out = rl_out,
    emissivity = emissivity
  )

  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)

  check_in_range(rs_in, "rs_in", lower = 0, call = call)
  check_in_range(albedo, "albedo", lower = 0, upper = 1, call = call)
  check_in_range(rl_in, "rl_in", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_in_range(rl_out, "rl_out", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_in_range(emissivity, "emissivity", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)

  (1 - albedo) * rs_in + rl_in - rl_out - (1 - emissivity) * rl_in
}

# Shortwave transmissivity -----------------------------------------------------

#' Broadband clear-sky shortwave atmospheric transmissivity
#'
#' @description
#' Computes the broadband transmissivity of a clear-sky atmosphere to
#' shortwave radiation on a horizontal surface, \eqn{\tau_{sw}}{tau_sw}: the
#' fraction of the extraterrestrial irradiance that reaches the surface.
#' `ef_tau_sw()` is the dispatcher of the family: it checks `method`
#' (no default), forwards the other arguments to the method function, builds
#' the diagnostic flags and records the provenance. The methods are:
#'
#' * `ef_tau_sw_allen()` (`method = "allen"`): partitioned form, function of
#'   the solar zenith angle, the air pressure, the vapour pressure and the
#'   turbidity, that separates the direct-beam (\eqn{\tau_b}{tau_b}) and
#'   diffuse (\eqn{\tau_d}{tau_d}) components needed for the terrain
#'   correction of `ef_rs_in()`;
#' * `ef_tau_sw_elevation()` (`method = "elevation"`): simple linear
#'   function of elevation, total transmissivity only (no direct/diffuse
#'   partition).
#'
#' @param ... Arguments passed to the method selected by `method`.
#' @param method Character, no default. `"allen"` or `"elevation"`.
#' @param cos_zenith Numeric. Cosine of the solar zenith angle on the
#'   horizontal \[-\], in (0, 1\] (e.g. `ef_solar_geometry()$cos_zenith`).
#'   The air mass does not depend on the slope of the pixel, so the
#'   horizontal angle is used, not the incidence angle on the pixel plane.
#' @param pressure Numeric. Atmospheric pressure \[kPa\], `> 0`: measured,
#'   regionalised or from `ef_air_pressure()` (decision RC-08).
#' @param vapour_pressure Numeric. Actual vapour pressure of the air
#'   \eqn{e_a}{ea} \[kPa\], `>= 0`.
#' @param turbidity Numeric, no default. Turbidity coefficient
#'   \eqn{K_t}{Kt} \[-\], in (0, 1\]: 1 for clean air and about 0.5 for
#'   extremely turbid, dusty or polluted air according to the secondary
#'   source; not verified. It is not the clearness index (measured over
#'   extraterrestrial radiation), also often written \eqn{K_t}{Kt}.
#' @param elevation Numeric. Elevation above sea level \[m\], in
#'   (-37 500, 12 500) so that the transmissivity lies in (0, 1).
#'
#' @return
#' * `ef_tau_sw_allen()`: a plain list (no class) with the numeric vectors
#'   `beam` (\eqn{\tau_b}{tau_b}), `diffuse` (\eqn{\tau_d}{tau_d}) and
#'   `total` (\eqn{\tau_{sw} = \tau_b + \tau_d}{tau_sw = tau_b + tau_d}),
#'   all dimensionless, with the common length and `dim` of the inputs.
#' * `ef_tau_sw_elevation()`: a numeric vector of \eqn{\tau_{sw}}{tau_sw}
#'   \[-\] with the length and `dim` of `elevation`.
#' * `ef_tau_sw()`: a list of class `earthflux_sw_transmissivity` with the
#'   same elements for both methods (type-stable):
#'   * `total`: \eqn{\tau_{sw}}{tau_sw} \[-\], identical to `$total` of
#'     `ef_tau_sw_allen()` or to the value of `ef_tau_sw_elevation()`;
#'   * `beam`, `diffuse`: \eqn{\tau_b}{tau_b} and \eqn{\tau_d}{tau_d}
#'     \[-\] when the method partitions the transmissivity (`"allen"`), and
#'     `NULL` otherwise (`"elevation"`); the names are always present;
#'   * `method`: the method name;
#'   * `flags`: list of diagnostic flag records, one per code that holds
#'     somewhere: `EF_INPUT_NA` (a required input is missing; no `EF_RAD_`
#'     code applies to the transmissivity);
#'   * `provenance`: list with the method, the method function, its
#'     verification status, the inputs used, the flag codes evaluated
#'     (`flags_evaluated`) and the EarthFlux version.
#'
#' @details
#' **Partitioned form** (`ef_tau_sw_allen()`), with \eqn{P}{P} = `pressure`
#' \[kPa\], \eqn{e_a}{ea} = `vapour_pressure` \[kPa\], \eqn{K_t}{Kt} =
#' `turbidity` and \eqn{\cos\theta_h}{cos(theta_h)} = `cos_zenith`:
#' \deqn{W = 0.14 e_a P + 2.1}{W = 0.14 * ea * P + 2.1}
#' \deqn{\tau_b = 0.98 \exp\left[\frac{-0.00146 P}{K_t \cos\theta_h} -
#'   0.075 \left(\frac{W}{\cos\theta_h}\right)^{0.4}\right]}{tau_b = 0.98 *
#'   exp(-0.00146 * P / (Kt * cos(theta_h)) - 0.075 * (W /
#'   cos(theta_h))^0.4)}
#' \deqn{\tau_d = 0.35 - 0.36 \tau_b \ (\tau_b \ge 0.15), \quad
#'   \tau_d = 0.18 + 0.82 \tau_b \ (\tau_b < 0.15)}{tau_d = 0.35 - 0.36 *
#'   tau_b if tau_b >= 0.15; tau_d = 0.18 + 0.82 * tau_b if tau_b < 0.15}
#' where \eqn{W}{W} is the precipitable water \[mm\]. The piecewise diffuse
#' term is discontinuous at \eqn{\tau_b = 0.15}{tau_b = 0.15} (0.296 versus
#' 0.303); the branch \eqn{\tau_b \ge 0.15}{tau_b >= 0.15} is used at the
#' break point, as written above.
#'
#' **Elevation form** (`ef_tau_sw_elevation()`), with \eqn{z}{z} =
#' `elevation` \[m\]:
#' \deqn{\tau_{sw} = 0.75 + 2 \times 10^{-5} z}{tau_sw = 0.75 + 2e-5 * z}
#' It does not depend on the solar angle nor on the humidity, and gives no
#' direct/diffuse partition, so it cannot feed the terrain correction of
#' `ef_rs_in_modelled()`; it is meant for flat terrain, sensitivity analyses
#' and the reproduction of published cases that use it.
#'
#' Assumptions: clear sky (consistent with valid MODIS LST pixels); the
#' coefficients of the partitioned form were derived for conditions in the
#' United States and for hourly or daily steps, and are applied here to an
#' instantaneous overpass (transferability to Chile, in particular at high
#' elevation in the Andes, and validity at low sun angles are `TODO`).
#'
#' Arguments must be numeric and have length 1 or a common length; length-1
#' arguments are recycled, matrix or array arguments must share their `dim`.
#' Values outside the domains above (including `cos_zenith <= 0`, where the
#' partitioned form is undefined: the sun is below the horizon) or infinite
#' values raise `earthflux_domain_error` (also `earthflux_input_error`);
#' they are never corrected. A missing or unknown `method` raises
#' `earthflux_missing_input` or `earthflux_unknown_method`; an argument
#' required by the chosen method but not supplied to the dispatcher raises
#' `earthflux_missing_input`, and one the method does not accept raises
#' `earthflux_input_error`. Missing values propagate to every output; the
#' dispatcher reports them with the flag `EF_INPUT_NA`.
#'
#' @section Verification status:
#' `ef_tau_sw_allen()` is `CANDIDATA`: form and coefficients observed in the
#' `water` package (v1.0), which attributes them to an extended equation of
#' Allen (1996) based on Majumdar et al. (1972), with coefficients of
#' ASCE-EWRI (2005); none of these has been verified. FAO-56 (annex 3,
#' Eqs. 3-18 and 3-20) gives a related form with different coefficients
#' (0.091 and exponent 0.25 in the beam term, 0.33 in the diffuse term); the
#' discrepancy is recorded under decision RC-08 and must be resolved against
#' ASCE-EWRI (2005) and Allen et al. (2007).
#'
#' `ef_tau_sw_elevation()` has the form of FAO-56 Eq. 37 (annex 3,
#' Eq. 3-13) for the ratio of clear-sky to extraterrestrial radiation, which
#' FAO-56 declares valid for daily and hourly periods, for elevations below
#' 6000 m and low turbidity; its use as an instantaneous transmissivity in
#' METRIC is `CANDIDATA`.
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
#' # Sea level, sun at 35 degrees from the zenith, ea = 1.5 kPa, clean air
#' tau <- ef_tau_sw(
#'   cos_zenith = cos(35 * pi / 180), pressure = ef_air_pressure(0),
#'   vapour_pressure = 1.5, turbidity = 1, method = "allen"
#' )
#' tau$total
#' tau$beam
#'
#' # Same values through the method function
#' ef_tau_sw_allen(cos(35 * pi / 180), ef_air_pressure(0), 1.5, 1)$beam
#'
#' # Elevation form (total only; `beam` and `diffuse` are NULL)
#' tau_z <- ef_tau_sw(elevation = c(0, 1000, 3000), method = "elevation")
#' tau_z$total
#' is.null(tau_z$beam)
ef_tau_sw <- function(..., method) {
  call <- sys.call()
  check_method(method, c("allen", "elevation"), call = call)
  fun_name <- switch(method,
                     allen = "ef_tau_sw_allen",
                     elevation = "ef_tau_sw_elevation")
  fun <- get(fun_name, mode = "function")
  inputs <- ef_dispatch_args(fun, fun_name, list(...), method, call = call)

  if (method == "allen") {
    value <- ef_tau_sw_allen(...)
  } else {
    value <- list(total = ef_tau_sw_elevation(...), beam = NULL,
                  diffuse = NULL)
  }
  n <- length(value$total)
  flags <- ef_flags_combine(
    ef_input_na_flags(inputs, n),
    ef_diagnose_radiation(
      cos_zenith = ef_rad_layer(inputs$cos_zenith, n)
    )
  )

  new_ef_object(
    list(
      total = value$total,
      beam = value$beam,
      diffuse = value$diffuse,
      method = method,
      flags = flags$flags,
      provenance = ef_rad_provenance(method, fun_name, inputs,
                                     flags$evaluated)
    ),
    "earthflux_sw_transmissivity"
  )
}

#' @rdname ef_tau_sw
#' @export
ef_tau_sw_allen <- function(cos_zenith, pressure, vapour_pressure,
                            turbidity) {
  call <- sys.call()
  args <- list(cos_zenith = cos_zenith, pressure = pressure,
               vapour_pressure = vapour_pressure, turbidity = turbidity)
  n <- check_core_args(args, call)
  check_in_range(cos_zenith, "cos_zenith", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)
  check_in_range(pressure, "pressure", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_in_range(vapour_pressure, "vapour_pressure", lower = 0, call = call)
  check_in_range(turbidity, "turbidity", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)
  d <- common_dim(args)

  # CANDIDATA coefficients (water v1.0; Allen, 1996; ASCE-EWRI, 2005),
  # kept as literals next to their equation (WF-14).
  precipitable_water <- 0.14 * vapour_pressure * pressure + 2.1
  beam <- 0.98 * exp(
    -0.00146 * pressure / (turbidity * cos_zenith) -
      0.075 * (precipitable_water / cos_zenith)^0.4
  )
  beam <- ef_reshape(beam, n, d)
  diffuse <- ifelse(beam >= 0.15, 0.35 - 0.36 * beam, 0.18 + 0.82 * beam)
  diffuse <- ef_reshape(diffuse, n, d)

  list(beam = beam, diffuse = diffuse, total = beam + diffuse)
}

#' @rdname ef_tau_sw
#' @export
ef_tau_sw_elevation <- function(elevation) {
  call <- sys.call()
  check_core_args(list(elevation = elevation), call)
  # tau_sw in (0, 1)  <=>  z in (-0.75 / 2e-5, 0.25 / 2e-5) m.
  check_in_range(elevation, "elevation", lower = -0.75 / 2e-5,
                 upper = 0.25 / 2e-5, lower_inclusive = FALSE,
                 upper_inclusive = FALSE, call = call)

  # Form of FAO-56 Eq. 37 (normative coefficients as literals, WF-14).
  0.75 + 2e-5 * elevation
}

# Effective atmospheric emissivity ---------------------------------------------

#' Effective atmospheric emissivity
#'
#' @description
#' Computes the effective broadband emissivity of a clear-sky atmosphere,
#' \eqn{\varepsilon_a}{ea}, from the clear-sky shortwave transmissivity. It
#' is the emissivity used by `ef_rl_in()` for the incoming longwave
#' radiation.
#'
#' @param tau_sw Numeric. Total clear-sky broadband shortwave transmissivity
#'   on the horizontal \eqn{\tau_{sw}}{tau_sw} \[-\], in the open interval
#'   (0, 1), normally `ef_tau_sw_allen()$total` (see Details).
#'
#' @return A numeric vector of \eqn{\varepsilon_a}{ea} \[-\] with the length
#'   and `dim` of `tau_sw`. Values above 1 (which occur only for
#'   \eqn{\tau_{sw} < 0.0022776}{tau_sw < 0.0022776}) are returned unchanged
#'   and are reported by the diagnostics of the stage
#'   (`EF_RAD_ATM_EMISSIVITY_GT1`).
#'
#' @details
#' \deqn{\varepsilon_a = 0.85 \left(-\ln \tau_{sw}\right)^{0.09}}{ea = 0.85
#'   * (-log(tau_sw))^0.09}
#' The emissivity decreases as the transmissivity increases. The input must
#' be the **modelled clear-sky** transmissivity, not an effective
#' transmissivity derived from measured radiation, unless this is decided
#' explicitly (decision RC-13): the empirical relation was proposed for
#' clear skies.
#'
#' `tau_sw` must be numeric and non-empty. Values outside (0, 1) (where the
#' logarithm is undefined or the emissivity is zero) or infinite values raise
#' `earthflux_domain_error` (also `earthflux_input_error`). Missing values
#' propagate.
#'
#' @section Verification status:
#' `CANDIDATA`. Form and coefficients (0.85, 0.09) observed in the `water`
#' package (v1.0), which attributes the form to Bastiaanssen (1995) and the
#' coefficients to an internal report of Allen (2000); neither has been
#' verified, nor its use in Allen et al. (2007), nor the range of
#' transmissivities over which the coefficients were derived. Formulations
#' in terms of vapour pressure and air temperature (e.g. Brutsaert) are an
#' open alternative (decision RC-13).
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @family radiation functions
#' @export
#'
#' @examples
#' ef_atm_emissivity(c(0.5, 0.7, 0.75, 0.9))
ef_atm_emissivity <- function(tau_sw) {
  call <- sys.call()
  check_core_args(list(tau_sw = tau_sw), call)
  check_in_range(tau_sw, "tau_sw", lower = 0, upper = 1,
                 lower_inclusive = FALSE, upper_inclusive = FALSE,
                 call = call)

  # CANDIDATA coefficients (water v1.0; Bastiaanssen, 1995; Allen, 2000).
  0.85 * (-log(tau_sw))^0.09
}

# Incoming shortwave radiation -------------------------------------------------

#' Project horizontal shortwave components onto the pixel plane
#'
#' Common core of `ef_rs_in_modelled()` and `ef_rs_in_measured()`
#' (dev/specs/radiation-components.md 6.4): isotropic diffuse sky and
#' isotropic ground reflection on an unobstructed tilted plane.
#'
#' Arguments are assumed checked by the caller.
#'
#' @param beam_h,diffuse_h Direct-beam and diffuse irradiance on the
#'   horizontal \[W m-2\].
#' @param cos_zenith Cosine of the solar zenith angle, in (0, 1\].
#' @param cos_incidence Cosine of the incidence angle on the plane.
#' @param slope Slope of the plane \[rad\].
#' @param ground_albedo Albedo of the surrounding ground \[-\] (0 when the
#'   reflected term vanishes, i.e. on flat terrain).
#' @param n,d Common length and `dim` of the outputs.
#' @return A list with `total`, `beam`, `diffuse` and `reflected`
#'   \[W m-2\].
#' @noRd
ef_rs_to_slope <- function(beam_h, diffuse_h, cos_zenith, cos_incidence,
                           slope, ground_albedo, n, d) {
  # A plane facing away from the sun receives no direct beam: physical
  # definition of the beam irradiance on that plane, not a correction
  # (flagged as EF_RAD_SELF_SHADED by ef_diagnose_radiation()).
  beam <- beam_h * pmax(cos_incidence, 0) / cos_zenith
  diffuse <- diffuse_h * (1 + cos(slope)) / 2
  reflected <- ground_albedo * (beam_h + diffuse_h) * (1 - cos(slope)) / 2
  beam <- ef_reshape(beam, n, d)
  diffuse <- ef_reshape(diffuse, n, d)
  reflected <- ef_reshape(reflected, n, d)
  list(
    total = beam + diffuse + reflected,
    beam = beam,
    diffuse = diffuse,
    reflected = reflected
  )
}

#' Resolve the ground albedo of the reflected term
#'
#' `ground_albedo = NULL` is accepted only when no slope is positive, where
#' the reflected term is identically zero; no default value is assumed
#' otherwise.
#'
#' @param ground_albedo `NULL` or numeric.
#' @param slope Numeric slope \[rad\] (already checked).
#' @param call The call to report.
#' @return `ground_albedo`, or `0` when it is `NULL` on flat terrain.
#' @noRd
resolve_ground_albedo <- function(ground_albedo, slope, call) {
  if (!is.null(ground_albedo)) {
    return(ground_albedo)
  }
  if (any(slope > 0, na.rm = TRUE)) {
    ef_abort(
      paste0(
        "`ground_albedo` is required when `slope > 0` (reflected radiation ",
        "from the surrounding ground); no default value is assumed."
      ),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  0
}

#' Incoming shortwave radiation on the pixel plane
#'
#' @description
#' Computes the instantaneous incoming (downwelling) shortwave radiation
#' \eqn{R_{s\downarrow}}{Rs_in} on the plane of each pixel (horizontal or
#' tilted) at the overpass time, separating the direct beam, the diffuse sky
#' radiation and the radiation reflected by the surrounding ground. The
#' `total` element is the `rs_in` argument of `ef_net_radiation()`.
#'
#' `ef_rs_in()` is the dispatcher of the family: it checks `method` (no
#' default), forwards the other arguments to the method function, builds the
#' diagnostic flags and records the provenance. The methods are:
#'
#' * `ef_rs_in_modelled()` (`method = "modelled"`): clear-sky radiation from
#'   the extraterrestrial irradiance and the partitioned transmissivity of
#'   `ef_tau_sw_allen()`;
#' * `ef_rs_in_measured()` (`method = "measured"`): measured (or
#'   regionalised) global radiation on the horizontal, split with a given
#'   diffuse fraction.
#'
#' Both methods project the horizontal components onto the pixel plane in
#' the same way.
#'
#' @param ... Arguments passed to the method selected by `method`.
#' @param method Character, no default. `"modelled"` or `"measured"`.
#' @param cos_zenith Numeric. Cosine of the solar zenith angle on the
#'   horizontal \eqn{\cos\theta_h}{cos(theta_h)} \[-\], in (0, 1\]
#'   (`ef_solar_geometry()$cos_zenith`).
#' @param cos_incidence Numeric. Cosine of the solar incidence angle on the
#'   pixel plane \eqn{\cos\theta_{rel}}{cos(theta_rel)} \[-\], in
#'   \[-1, 1\] (`ef_solar_geometry()$cos_incidence`, computed with the same
#'   `slope`).
#' @param inv_distance Numeric. Inverse relative Earth-Sun distance
#'   \eqn{d_r}{dr} \[-\], `> 0` (`ef_solar_geometry()$inv_distance`).
#' @param tau_beam,tau_diffuse Numeric. Direct-beam and diffuse clear-sky
#'   transmissivities on the horizontal \[-\] (`ef_tau_sw_allen()$beam` and
#'   `$diffuse`), each in \[0, 1), with a sum in (0, 1).
#' @param rs_horizontal Numeric. Measured or regionalised global shortwave
#'   radiation on the horizontal at the overpass time \[W m-2\], `>= 0`.
#' @param diffuse_fraction Numeric, no default. Diffuse fraction of
#'   `rs_horizontal` \eqn{k_d}{kd} \[-\], in \[0, 1\]. How to obtain it
#'   (clear-sky model, decomposition model or hybrid) is an open decision
#'   (RC-10).
#' @param slope Numeric, no default. Slope of the pixel plane \[rad\], in
#'   \[0, pi/2\]; the same slope used to compute `cos_incidence` (0 for a
#'   horizontal plane).
#' @param ground_albedo Numeric or `NULL`. Albedo of the ground seen by the
#'   tilted plane \eqn{\rho_g}{rho_g} \[-\], in \[0, 1\] (for example the
#'   albedo of the pixel itself or a neighbourhood mean, decision RC-09).
#'   Required when any `slope > 0`; may be `NULL` on flat terrain, where the
#'   reflected term is zero.
#'
#' @return A plain list (no class) of numeric vectors with the common length
#'   and `dim` of the inputs:
#'   * `total`: \eqn{R_{s\downarrow}}{Rs_in} on the pixel plane \[W m-2\];
#'   * `beam`, `diffuse`, `reflected`: its direct-beam, diffuse-sky and
#'     ground-reflected components \[W m-2\];
#'   * `diffuse_fraction` (`ef_rs_in_modelled()` only): diffuse fraction of
#'     the clear-sky radiation on the horizontal,
#'     \eqn{\tau_d / (\tau_b + \tau_d)}{tau_d / (tau_b + tau_d)} \[-\].
#'
#'   `ef_rs_in()` returns a list of class `earthflux_incoming_shortwave`
#'   with the same elements for both methods (type-stable): `total`, `beam`,
#'   `diffuse` and `reflected` (identical to those of the method function),
#'   `diffuse_fraction` (`NULL` for `"measured"`, where it is an input),
#'   `method`, `flags` (one record per code that holds somewhere:
#'   `EF_INPUT_NA` and `EF_RAD_SELF_SHADED`; see Details) and `provenance`
#'   (method, method function, verification status, inputs used, flag codes
#'   evaluated in `flags_evaluated`, EarthFlux version).
#'
#' @details
#' Components on the horizontal:
#' * `ef_rs_in_modelled()`: \eqn{R_{a,h} = G_{sc} d_r \cos\theta_h}{Ra_h =
#'   Gsc * dr * cos(theta_h)}, \eqn{R_{b,h} = \tau_b R_{a,h}}{Rb_h = tau_b *
#'   Ra_h} and \eqn{R_{d,h} = \tau_d R_{a,h}}{Rd_h = tau_d * Ra_h}, with
#'   \eqn{G_{sc}}{Gsc} the solar constant of the package (1366.67 W m-2,
#'   FAO-56 Eq. 21; its adoption for METRIC is `CANDIDATA`, decision RC-06);
#' * `ef_rs_in_measured()`: \eqn{R_{b,h} = (1 - k_d) R_{s,meas}}{Rb_h =
#'   (1 - kd) * Rs_meas} and \eqn{R_{d,h} = k_d R_{s,meas}}{Rd_h = kd *
#'   Rs_meas}.
#'
#' Projection onto the plane of slope \eqn{s}{s} (isotropic diffuse sky and
#' isotropic ground reflection, unobstructed horizon):
#' \deqn{R_{b,s} = R_{b,h} \frac{\max(\cos\theta_{rel}, 0)}{\cos\theta_h},
#'   \quad R_{d,s} = R_{d,h} \frac{1 + \cos s}{2}, \quad
#'   R_{r,s} = \rho_g (R_{b,h} + R_{d,h}) \frac{1 - \cos s}{2}}{Rb_s = Rb_h *
#'   max(cos(theta_rel), 0) / cos(theta_h), Rd_s = Rd_h * (1 + cos(s)) / 2,
#'   Rr_s = rho_g * (Rb_h + Rd_h) * (1 - cos(s)) / 2}
#' and \eqn{R_{s\downarrow} = R_{b,s} + R_{d,s} + R_{r,s}}{Rs_in = Rb_s +
#' Rd_s + Rr_s}. In the modelled path \eqn{R_{b,s} = \tau_b G_{sc} d_r
#' \max(\cos\theta_{rel}, 0)}{Rb_s = tau_b * Gsc * dr * max(cos(theta_rel),
#' 0)}. On flat terrain (\eqn{s = 0}{s = 0}, \eqn{\cos\theta_{rel} =
#' \cos\theta_h}{cos(theta_rel) = cos(theta_h)}) the modelled radiation
#' reduces to \eqn{G_{sc} d_r \cos\theta_h \tau_{sw}}{Gsc * dr *
#' cos(theta_h) * tau_sw}.
#'
#' A plane facing away from the sun (\eqn{\cos\theta_{rel} \le 0}{cos(theta_rel)
#' <= 0}) receives no direct beam: \eqn{\max(\cos\theta_{rel}, 0)}{max(.,
#' 0)} is the physical definition of the beam irradiance on that plane, not
#' a correction, and is reported by `ef_rs_in()` with the flag
#' `EF_RAD_SELF_SHADED`. The resulting radiation is never truncated.
#'
#' **Diagnostics** (`ef_rs_in()` only; the method functions return values
#' without flags). `EF_INPUT_NA`: a required input is missing at the
#' position; `EF_RAD_SELF_SHADED`: the sun is above the horizon but the
#' pixel plane faces away from it. A record is present only for a code that
#' holds somewhere; the codes evaluated are in
#' `provenance$flags_evaluated`.
#'
#' Unlike a common simplified form, \eqn{G_{sc} d_r \cos\theta_{rel}
#' \tau_{sw}}{Gsc * dr * cos(theta_rel) * tau_sw}, the diffuse component is
#' not projected as if it were direct beam; on slopes the two forms differ by
#' tens to hundreds of W m-2.
#'
#' Assumptions: clear sky (modelled path); no cast shadows and no reduction
#' of the sky view by the surrounding relief; isotropic diffuse sky and
#' ground reflection; instantaneous values at the overpass time. Measured
#' radiation is usually a 10-60 min mean and must be interpolated to the
#' overpass time upstream.
#'
#' Arguments must be numeric and have length 1 or a common length; length-1
#' arguments are recycled, matrix or array arguments must share their `dim`.
#' Values outside the domains above (including `cos_zenith <= 0`, sun below
#' the horizon) or infinite values raise `earthflux_domain_error` (also
#' `earthflux_input_error`). `ground_albedo = NULL` with a positive slope
#' raises `earthflux_missing_input`. A missing or unknown `method` raises
#' `earthflux_missing_input` or `earthflux_unknown_method`; an argument
#' required by the chosen method but not supplied to the dispatcher raises
#' `earthflux_missing_input`, and one the method does not accept raises
#' `earthflux_input_error`. Missing values propagate arithmetically to the
#' outputs that depend on them, and always to `total`.
#'
#' @section Verification status:
#' `CANDIDATA`. The flat-terrain modelled form is the one observed in the
#' `water` package (v1.0), attributed there to Allen et al. (2007) (not
#' verified). The isotropic projection onto tilted planes is the standard
#' form of solar engineering texts (Duffie and Beckman; isotropic model
#' attributed to Liu and Jordan; neither verified); whether Allen, Trezza
#' and Tasumi (2006) prescribe an anisotropic diffuse term is `TODO`
#' (decision RC-09). In the measured path, the source of the diffuse
#' fraction is `TODO` (decision RC-10). The solar constant is `CANDIDATA`
#' (RC-06).
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
#' # Clear-sky radiation on a horizontal pixel and on a 20 degree
#' # north-facing slope (southern hemisphere)
#' geo <- ef_solar_geometry(doy = 15, utc_hour = 15.5, lat = -35 * deg,
#'                          lon = -71 * deg, slope = c(0, 20) * deg,
#'                          aspect = 0)
#' tau <- ef_tau_sw_allen(geo$cos_zenith, ef_air_pressure(500),
#'                        vapour_pressure = 1.2, turbidity = 1)
#' rs <- ef_rs_in(
#'   cos_zenith = geo$cos_zenith, cos_incidence = geo$cos_incidence,
#'   inv_distance = geo$inv_distance, tau_beam = tau$beam,
#'   tau_diffuse = tau$diffuse, slope = c(0, 20) * deg,
#'   ground_albedo = 0.2, method = "modelled"
#' )
#' rs$total
#' rs$provenance$flags_evaluated
#'
#' # Measured global radiation on the horizontal, projected to the slopes
#' ef_rs_in_measured(
#'   rs_horizontal = 950, diffuse_fraction = 0.15,
#'   cos_zenith = geo$cos_zenith, cos_incidence = geo$cos_incidence,
#'   slope = c(0, 20) * deg, ground_albedo = 0.2
#' )$total
ef_rs_in <- function(..., method) {
  call <- sys.call()
  check_method(method, c("modelled", "measured"), call = call)
  fun_name <- switch(method,
                     modelled = "ef_rs_in_modelled",
                     measured = "ef_rs_in_measured")
  fun <- get(fun_name, mode = "function")
  inputs <- ef_dispatch_args(fun, fun_name, list(...), method, call = call)

  value <- switch(method,
    modelled = ef_rs_in_modelled(...),
    measured = ef_rs_in_measured(...)
  )
  n <- length(value$total)
  flags <- ef_flags_combine(
    ef_input_na_flags(inputs, n),
    ef_diagnose_radiation(
      cos_zenith = ef_rad_layer(inputs$cos_zenith, n),
      cos_incidence = ef_rad_layer(inputs$cos_incidence, n)
    )
  )

  new_ef_object(
    list(
      total = value$total,
      beam = value$beam,
      diffuse = value$diffuse,
      reflected = value$reflected,
      diffuse_fraction = value$diffuse_fraction,
      method = method,
      flags = flags$flags,
      provenance = ef_rad_provenance(method, fun_name, inputs,
                                     flags$evaluated)
    ),
    "earthflux_incoming_shortwave"
  )
}

#' @rdname ef_rs_in
#' @export
ef_rs_in_modelled <- function(cos_zenith, cos_incidence, inv_distance,
                              tau_beam, tau_diffuse, slope,
                              ground_albedo = NULL) {
  call <- sys.call()
  args <- list(cos_zenith = cos_zenith, cos_incidence = cos_incidence,
               inv_distance = inv_distance, tau_beam = tau_beam,
               tau_diffuse = tau_diffuse, slope = slope)
  if (!is.null(ground_albedo)) {
    args$ground_albedo <- ground_albedo
  }
  n <- check_core_args(args, call)
  check_in_range(cos_zenith, "cos_zenith", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)
  check_in_range(cos_incidence, "cos_incidence", lower = -1, upper = 1,
                 call = call)
  check_in_range(inv_distance, "inv_distance", lower = 0,
                 lower_inclusive = FALSE, call = call)
  check_in_range(tau_beam, "tau_beam", lower = 0, upper = 1,
                 upper_inclusive = FALSE, call = call)
  check_in_range(tau_diffuse, "tau_diffuse", lower = 0, upper = 1,
                 upper_inclusive = FALSE, call = call)
  check_in_range(tau_beam + tau_diffuse, "tau_beam + tau_diffuse",
                 lower = 0, upper = 1, lower_inclusive = FALSE,
                 upper_inclusive = FALSE, call = call)
  check_angle(slope, "slope", "slope", call)
  if (!is.null(ground_albedo)) {
    check_in_range(ground_albedo, "ground_albedo", lower = 0, upper = 1,
                   call = call)
  }
  ground_albedo <- resolve_ground_albedo(ground_albedo, slope, call)
  d <- common_dim(args)

  extraterrestrial_h <- EF_SOLAR_CONSTANT * inv_distance * cos_zenith
  out <- ef_rs_to_slope(
    beam_h = tau_beam * extraterrestrial_h,
    diffuse_h = tau_diffuse * extraterrestrial_h,
    cos_zenith = cos_zenith, cos_incidence = cos_incidence, slope = slope,
    ground_albedo = ground_albedo, n = n, d = d
  )
  out$diffuse_fraction <- ef_reshape(tau_diffuse / (tau_beam + tau_diffuse),
                                     n, d)
  out
}

#' @rdname ef_rs_in
#' @export
ef_rs_in_measured <- function(rs_horizontal, diffuse_fraction, cos_zenith,
                              cos_incidence, slope, ground_albedo = NULL) {
  call <- sys.call()
  args <- list(rs_horizontal = rs_horizontal,
               diffuse_fraction = diffuse_fraction, cos_zenith = cos_zenith,
               cos_incidence = cos_incidence, slope = slope)
  if (!is.null(ground_albedo)) {
    args$ground_albedo <- ground_albedo
  }
  n <- check_core_args(args, call)
  check_in_range(rs_horizontal, "rs_horizontal", lower = 0, call = call)
  check_in_range(diffuse_fraction, "diffuse_fraction", lower = 0, upper = 1,
                 call = call)
  check_in_range(cos_zenith, "cos_zenith", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)
  check_in_range(cos_incidence, "cos_incidence", lower = -1, upper = 1,
                 call = call)
  check_angle(slope, "slope", "slope", call)
  if (!is.null(ground_albedo)) {
    check_in_range(ground_albedo, "ground_albedo", lower = 0, upper = 1,
                   call = call)
  }
  ground_albedo <- resolve_ground_albedo(ground_albedo, slope, call)
  d <- common_dim(args)

  ef_rs_to_slope(
    beam_h = (1 - diffuse_fraction) * rs_horizontal,
    diffuse_h = diffuse_fraction * rs_horizontal,
    cos_zenith = cos_zenith, cos_incidence = cos_incidence, slope = slope,
    ground_albedo = ground_albedo, n = n, d = d
  )
}

# Longwave radiation -----------------------------------------------------------

#' Incoming longwave radiation
#'
#' @description
#' Computes the incoming (downwelling) longwave radiation at the surface,
#' \eqn{R_{L\downarrow}}{RL_in}, emitted by the atmosphere treated as a grey
#' body with an effective emissivity and an effective temperature. The
#' result is the `rl_in` argument of `ef_net_radiation()`.
#'
#' @param temperature Numeric, no default. Effective temperature of the
#'   emitting atmosphere \[K\], `> 0`. The function is **agnostic** about
#'   which temperature is used: the air temperature at the overpass time
#'   (station or regionalised forcing), the surface temperature of the cold
#'   anchor pixel (a scene scalar) or the surface temperature of each pixel.
#'   The choice is open (decision RC-12) and must be made, and recorded, by
#'   the caller.
#' @param atm_emissivity Numeric. Effective atmospheric emissivity
#'   \eqn{\varepsilon_a}{ea} \[-\], `> 0` (e.g. `ef_atm_emissivity()`).
#'   Values above 1 are accepted and reported by the diagnostics of the
#'   stage (`EF_RAD_ATM_EMISSIVITY_GT1`).
#'
#' @return A numeric vector of \eqn{R_{L\downarrow}}{RL_in} \[W m-2\] with
#'   the common length and `dim` of the inputs.
#'
#' @details
#' \deqn{R_{L\downarrow} = \varepsilon_a \sigma T^4}{RL_in = ea * sigma *
#'   T^4}
#' with \eqn{\sigma}{sigma} the Stefan-Boltzmann constant (CODATA 2018 exact
#' value, 5.670374419e-8 W m-2 K-4, decision RC-07).
#'
#' Choice of the temperature (RC-12): with the air temperature, the
#' meteorological forcing (and GWR) enters the incoming longwave radiation;
#' with the cold-pixel surface temperature, the result is uniform in the
#' scene except through the emissivity; with the surface temperature of each
#' pixel, hot and dry pixels receive more longwave radiation, which
#' artificially reduces the contrast of net radiation. With which
#' temperature the coefficients of `ef_atm_emissivity()` were derived is not
#' known (`TODO`).
#'
#' Assumptions: grey-body atmosphere with effective emissivity and
#' temperature; clear sky; instantaneous value.
#'
#' Arguments must be numeric and have length 1 or a common length (a scalar
#' temperature is recycled); matrix or array arguments must share their
#' `dim`. Non-positive or infinite values raise `earthflux_domain_error`
#' (also `earthflux_input_error`). Missing values propagate.
#'
#' @section Verification status:
#' `CANDIDATA`. Stefan-Boltzmann law with an effective emissivity, form
#' observed in the `water` package (v1.0), attributed there to Allen et al.
#' (2007) (equation number and prescribed temperature not verified).
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @family radiation functions
#' @export
#'
#' @examples
#' # Air temperature of 20 degrees C (293.15 K), transmissivity 0.75
#' ef_rl_in(temperature = 293.15, atm_emissivity = ef_atm_emissivity(0.75))
#'
#' # A scalar temperature recycled over several pixels
#' ef_rl_in(temperature = 290, atm_emissivity = c(0.72, 0.75, 0.78))
ef_rl_in <- function(temperature, atm_emissivity) {
  call <- sys.call()
  check_core_args(
    list(temperature = temperature, atm_emissivity = atm_emissivity), call
  )
  check_in_range(temperature, "temperature", lower = 0,
                 lower_inclusive = FALSE, call = call)
  check_in_range(atm_emissivity, "atm_emissivity", lower = 0,
                 lower_inclusive = FALSE, call = call)

  atm_emissivity * EF_STEFAN_BOLTZMANN * temperature^4
}

#' Longwave radiation emitted by the surface
#'
#' @description
#' Computes the longwave radiation **emitted** by the land surface,
#' \eqn{R_{L\uparrow}}{RL_out}, from its temperature and broadband
#' emissivity. The result is the `rl_out` argument of `ef_net_radiation()`
#' and does not include the reflected incoming longwave radiation, which
#' `ef_net_radiation()` accounts for separately.
#'
#' @param lst Numeric. Land surface temperature \eqn{T_s}{Ts} \[K\], `> 0`
#'   (e.g. MODIS LST with scale factor and quality control applied).
#' @param emissivity Numeric. Broadband surface emissivity
#'   \eqn{\varepsilon_0}{e0} \[-\], in (0, 1\]. It must be the same
#'   emissivity later passed to `ef_net_radiation()`.
#'
#' @return A numeric vector of \eqn{R_{L\uparrow}}{RL_out} \[W m-2\] with the
#'   common length and `dim` of the inputs.
#'
#' @details
#' \deqn{R_{L\uparrow} = \varepsilon_0 \sigma T_s^4}{RL_out = e0 * sigma *
#'   Ts^4}
#' with \eqn{\sigma}{sigma} the Stefan-Boltzmann constant (CODATA 2018 exact
#' value, decision RC-07). With the rounded 5.67e-8 W m-2 K-4 of some METRIC
#' implementations the result differs by about 6.6e-5 in relative terms.
#'
#' Consistency of the emissivity (decision RC-14, open): the broadband
#' emissivity should be consistent with the narrow-band emissivities assumed
#' by the LST retrieval; the same value must be used here and in
#' `ef_net_radiation()` (otherwise a spurious longwave term appears). A
#' radiometer measurement of the upwelling longwave radiation (emitted plus
#' reflected) is not interchangeable with this output.
#'
#' Assumptions: grey-body surface with broadband emissivity; `lst`
#' represents the radiating surface of the whole pixel; instantaneous value.
#'
#' Arguments must be numeric and have length 1 or a common length; matrix
#' or array arguments must share their `dim`. A non-positive or infinite
#' `lst`, or an `emissivity` outside (0, 1\], raises `earthflux_domain_error`
#' (also `earthflux_input_error`). Plausibility of `lst` (e.g. values in
#' degrees Celsius by mistake) needs a threshold without a documented
#' reference and is not checked. Missing values (e.g. cloudy MODIS pixels)
#' propagate.
#'
#' @section Verification status:
#' `CANDIDATA` (corroborated): the form \eqn{\varepsilon_0 \sigma
#' T_s^4}{e0 * sigma * Ts^4} is the one used by the `water` package (v1.0)
#' and by an independent secondary source (Wasti, 2020) together with the
#' net radiation of `ef_net_radiation()`; contrast with Allen et al. (2007)
#' is pending.
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @family radiation functions
#' @export
#'
#' @examples
#' # Surface at 300 K with emissivity 0.98
#' ef_rl_out(lst = 300, emissivity = 0.98)
#'
#' # Matrix input keeps its dim
#' ef_rl_out(lst = matrix(c(295, 300, 305, 310), 2), emissivity = 0.97)
ef_rl_out <- function(lst, emissivity) {
  call <- sys.call()
  check_core_args(list(lst = lst, emissivity = emissivity), call)
  check_in_range(lst, "lst", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(emissivity, "emissivity", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)

  emissivity * EF_STEFAN_BOLTZMANN * lst^4
}

# Helpers of the radiation dispatchers -------------------------------------------

#' A dispatcher input recycled to the length of the output
#'
#' @param x Numeric input of length 1 or `n`, or `NULL`.
#' @param n Integer. Length of the output.
#' @return `NULL`, or `x` as a plain vector of length `n`.
#' @noRd
ef_rad_layer <- function(x, n) {
  if (is.null(x)) NULL else rep_len(as.vector(x), n)
}

#' Provenance of a radiation dispatcher
#'
#' @param method,fun_name Method and name of the method function.
#' @param inputs Named list of the matched inputs (`NULL` elements are
#'   ignored).
#' @param flags_evaluated Character. Flag codes evaluated.
#' @return A list with `method`, `fun`, `status`, `inputs`,
#'   `flags_evaluated` and `earthflux_version`.
#' @noRd
ef_rad_provenance <- function(method, fun_name, inputs, flags_evaluated) {
  list(
    method = method,
    fun = fun_name,
    status = "CANDIDATA",
    inputs = names(inputs)[!vapply(inputs, is.null, logical(1))],
    flags_evaluated = flags_evaluated,
    earthflux_version = as.character(getNamespaceVersion("EarthFlux"))
  )
}

# Diagnostic flags of this stage -------------------------------------------------

#' Flag codes owned by the radiation (Rn and components) stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_RAD_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7).
#'
#' Registered (class I, raised by `ef_diagnose_radiation()`):
#' `EF_RAD_SELF_SHADED` (bit 1), `EF_RAD_ATM_EMISSIVITY_GT1` (bit 2),
#' `EF_RAD_RS_GT_RA` (bit 3) and `EF_RAD_RN_NEGATIVE` (bit 4). The class II
#' code `EF_RAD_SUN_LOW` needs a referenced threshold and is not registered.
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_radiation <- function() {
  ef_flag_rows(
    code = c(
      "EF_RAD_SELF_SHADED",
      "EF_RAD_ATM_EMISSIVITY_GT1",
      "EF_RAD_RS_GT_RA",
      "EF_RAD_RN_NEGATIVE"
    ),
    stage = rep("RAD", 4L),
    severity = c("info", "warning", "warning", "info"),
    scope = c("cell", "cell", "cell,record", "cell"),
    bit = c(1L, 2L, 3L, 4L),
    error_class = rep(NA_character_, 4L),
    description = c(
      paste0(
        "The pixel plane faces away from the sun while the sun is above the ",
        "horizon; its direct-beam irradiance is zero by definition."
      ),
      paste0(
        "The effective atmospheric emissivity of the empirical model ",
        "exceeds 1; the value is kept."
      ),
      paste0(
        "Measured shortwave radiation on the horizontal exceeds the ",
        "instantaneous extraterrestrial radiation on the horizontal."
      ),
      "Net radiation is negative; the value is physically possible and kept."
    ),
    spec = c(
      "dev/specs/radiation-components.md 6.4; dev/specs/flags.md 4.2",
      "dev/specs/radiation-components.md 6.5; dev/specs/flags.md 4.2",
      "dev/specs/radiation-components.md 6.4; dev/specs/flags.md 4.2",
      "dev/specs/ef_net_radiation.md 10.1; dev/specs/flags.md 4.2"
    ),
    since = rep("0.0.0.9000", 4L)
  )
}

#' Cell-scope diagnostics of the radiation stage
#'
#' Builds the `EF_RAD_*` flag records from the numeric inputs and outputs of
#' the radiation functions (dev/ARCHITECTURE.md section 3.2; the numeric
#' functions never build flags). Every argument is optional: a code is
#' evaluated only when all the arguments it needs are supplied. As for every
#' stage (R/diagnostics.R), a record is returned only for the codes flagged
#' in at least one position; the codes evaluated are attached as the
#' attribute `evaluated`, so that "evaluated and absent" differs from "not
#' evaluated". Masks are built as `!is.na(x) & condition`, so missing values
#' are never flagged here (`EF_INPUT_NA` is built by the dispatchers with
#' `ef_input_na_flags()`).
#'
#' Codes and conditions:
#' * `EF_RAD_SELF_SHADED`: `cos_incidence <= 0` and `cos_zenith > 0`
#'   (needs `cos_zenith`, `cos_incidence`);
#' * `EF_RAD_ATM_EMISSIVITY_GT1`: `atm_emissivity > 1`;
#' * `EF_RAD_RS_GT_RA`: `rs_horizontal > Gsc * inv_distance *
#'   max(cos_zenith, 0)` (needs `rs_horizontal`, `inv_distance`,
#'   `cos_zenith`; scope `"cell"`);
#' * `EF_RAD_RN_NEGATIVE`: `rn < 0`.
#'
#' @param cos_zenith,cos_incidence,inv_distance Outputs of
#'   `ef_solar_geometry()`.
#' @param atm_emissivity Output of `ef_atm_emissivity()` (or any effective
#'   atmospheric emissivity passed to `ef_rl_in()`).
#' @param rs_horizontal Measured shortwave radiation on the horizontal
#'   \[W m-2\] (input of `ef_rs_in_measured()`).
#' @param rn Net radiation \[W m-2\] (output of `ef_net_radiation()`).
#' @return A list (possibly empty) of `earthflux_flag` records, in the order
#'   of the codes above, with the attribute `evaluated`. Inputs must be
#'   numeric with length 1 or a common length (classed input errors
#'   otherwise).
#' @noRd
ef_diagnose_radiation <- function(cos_zenith = NULL, cos_incidence = NULL,
                                  inv_distance = NULL, atm_emissivity = NULL,
                                  rs_horizontal = NULL, rn = NULL) {
  call <- sys.call()
  args <- list(cos_zenith = cos_zenith, cos_incidence = cos_incidence,
               inv_distance = inv_distance, atm_emissivity = atm_emissivity,
               rs_horizontal = rs_horizontal, rn = rn)
  args <- args[!vapply(args, is.null, logical(1))]
  if (length(args) == 0L) {
    return(ef_flag_set(list()))
  }
  n <- check_core_args(args, call)
  has <- function(...) all(c(...) %in% names(args))
  mask <- function(x) rep_len(as.vector(x), n)

  masks <- list()
  if (has("cos_zenith", "cos_incidence")) {
    masks$EF_RAD_SELF_SHADED <- mask(
      !is.na(cos_incidence) & !is.na(cos_zenith) &
        cos_incidence <= 0 & cos_zenith > 0
    )
  }
  if (has("atm_emissivity")) {
    masks$EF_RAD_ATM_EMISSIVITY_GT1 <- mask(
      !is.na(atm_emissivity) & atm_emissivity > 1
    )
  }
  if (has("rs_horizontal", "inv_distance", "cos_zenith")) {
    extraterrestrial_h <- EF_SOLAR_CONSTANT * inv_distance *
      pmax(cos_zenith, 0)
    masks$EF_RAD_RS_GT_RA <- mask(
      !is.na(rs_horizontal) & !is.na(extraterrestrial_h) &
        rs_horizontal > extraterrestrial_h
    )
  }
  if (has("rn")) {
    masks$EF_RAD_RN_NEGATIVE <- mask(!is.na(rn) & rn < 0)
  }
  ef_flag_set(masks, scope = "cell")
}
