# METRIC: radiation components and net radiation (Rn) ----------------------------
#
# Purpose: net radiation at the land surface and its components.
#
# Implemented:
#   - ef_net_radiation(): instantaneous surface radiation balance from its
#     four components. Specification: dev/specs/ef_net_radiation.md.
#     Equation status: CANDIDATA (corroborated by secondary sources);
#     verification against the primary reference is pending.
#
# Planned (specified separately before implementation): incoming shortwave
#   (including direct/diffuse partition and terrain correction for slope and
#   aspect), incoming longwave and longwave emitted by the surface.
#
# Design: sensor-independent, purely arithmetic and vectorised. Emissivity is
#   an explicit input and the reflected incoming longwave term is kept
#   explicit (dev/SCIENTIFIC_SPEC.md, section 3, net radiation row).

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
