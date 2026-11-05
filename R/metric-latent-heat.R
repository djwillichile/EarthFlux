# METRIC: latent heat flux (LE) ------------------------------------------------------
#
# Purpose: latent heat flux as the residual of the surface energy balance,
#   LE = Rn - G - H, keeping negative or otherwise anomalous values and
#   flagging them (no silent truncation).
#
# Implemented:
#   - ef_latent_heat(): residual of the instantaneous surface energy balance.
#     Specification: dev/specs/evapotranspiration.md section 3.
#     Equation status: VERIFICADA as the FAO-56 surface energy balance
#     (chapter 1, Eq. 1, rearranged); its equation number in Allen, Tasumi
#     and Trezza (2007) is TODO (item V1).
#
# Diagnostics: LE < 0 is equivalent to ET_inst < 0 (lambda * rho_w > 0), so
#   no separate code is registered for LE (dev/specs/flags.md, C1 and FL-03);
#   EF_ET_NEGATIVE is evaluated on the ET layers by ef_diagnose_et()
#   (R/metric-et.R).
#
# Conventions: those of ef_net_radiation() (dev/ARCHITECTURE.md section 3.1).

#' Latent heat flux as the residual of the surface energy balance
#'
#' @description
#' Computes the instantaneous latent heat flux \eqn{LE}{LE} at the land
#' surface as the residual of the surface energy balance: the net radiation
#' minus the soil heat flux and the sensible heat flux. This is how the
#' METRIC model obtains the energy used for evapotranspiration at the
#' satellite overpass time.
#'
#' @param rn Numeric. Instantaneous net radiation \eqn{R_n}{Rn} \[W m-2\],
#'   for example from [ef_net_radiation()]. Positive when it supplies energy
#'   to the surface. Any finite value.
#' @param g Numeric. Instantaneous soil heat flux \eqn{G}{G} \[W m-2\],
#'   positive when heat flows from the surface into the soil. Any finite
#'   value.
#' @param h Numeric. Instantaneous sensible heat flux \eqn{H}{H} \[W m-2\],
#'   positive when heat flows from the surface into the air. Any finite
#'   value.
#'
#' @return A numeric vector of latent heat flux \eqn{LE}{LE} \[W m-2\] with
#'   the common length of the inputs, positive when the surface loses energy
#'   by evaporation. If the inputs include matrices or arrays (all with the
#'   same `dim`), the result keeps that `dim`. Negative values are returned
#'   unchanged (see Details).
#'
#' @details
#' The surface energy balance (FAO-56, chapter 1, Eq. 1) is
#' \eqn{R_n - G - \lambda ET - H = 0}{Rn - G - lambda * ET - H = 0}, where
#' \eqn{\lambda ET}{lambda * ET} is the latent heat flux. Solved for the
#' latent heat flux,
#' \deqn{LE = R_n - G - H}{LE = Rn - G - H}
#' with the FAO-56 sign convention: positive \eqn{R_n}{Rn} supplies energy to
#' the surface, and positive \eqn{G}{G}, \eqn{LE}{LE} and \eqn{H}{H} remove
#' energy from it.
#'
#' Assumptions (FAO-56, chapter 1): only vertical fluxes are considered
#' (horizontal advection is ignored), the surface is extensive and
#' homogeneous, and heat storage in the canopy and metabolic energy are
#' neglected. These assumptions are weaker in mixed pixels of about 1 km.
#' Because \eqn{LE}{LE} is a residual, the balance closes by construction in
#' every pixel and all the errors of \eqn{R_n}{Rn}, \eqn{G}{G} and
#' \eqn{H}{H} are transferred to \eqn{LE}{LE}.
#'
#' Negative values are physically possible inputs: \eqn{R_n}{Rn},
#' \eqn{G}{G} and \eqn{H}{H} may all be negative, and no sign check is made.
#' A negative \eqn{LE}{LE} (\eqn{H > R_n - G}{H > Rn - G}) is returned
#' unchanged and without a warning; it is never set to zero. It is flagged
#' downstream with `EF_ET_NEGATIVE` on the evapotranspiration layers
#' (\eqn{LE < 0}{LE < 0} is equivalent to \eqn{ET_{inst} < 0}{ET_inst < 0}).
#' An \eqn{LE}{LE} larger than \eqn{R_n - G}{Rn - G} (negative
#' \eqn{H}{H}, possible under advection) is not modified either.
#'
#' The function is symmetric in `g` and `h`: swapping them gives the same
#' result. Use named arguments.
#'
#' Missing values (`NA`, `NaN`) in any input propagate to the corresponding
#' output element, without errors or warnings. Arguments must be numeric
#' (double or integer) and have length 1 or a common length; length-1
#' arguments are recycled, arrays with a `dim` are not. Infinite values
#' raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`) that names the argument.
#'
#' Verification status: `VERIFICADA` as the FAO-56 surface energy balance
#' (chapter 1, Eq. 1, rearranged) and `VERIFICADA (SEBAL-Idaho 2002)` as the
#' residual of the energy balance, Waters et al. (2002), Eq. 1 (pp. 9, 24
#' and 34), with the same sign convention (G and H positive away from the
#' surface). Also corroborated by Olmedo et al. (2016, Eq. 1); the equation
#' number in Allen et al. (2007) has not been verified (desirable, not
#' blocking).
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
#' Olmedo, G. F., Ortega-Farias, S., de la Fuente-Saiz, D.,
#' Fonseca-Luengo, D., & Fuentes-Penailillo, F. (2016). water: Tools and
#' functions to estimate actual evapotranspiration using land surface energy
#' balance models in R. *The R Journal*, 8(2), 352-369.
#' \doi{10.32614/RJ-2016-051}
#'
#' Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
#' (2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
#' implementation. Advanced training and users manual* (Version 1.0).
#' University of Idaho and Idaho Department of Water Resources.
#'
#' @family latent heat and evapotranspiration functions
#' @export
#'
#' @examples
#' # Reference case: 600 - 60 - 50 = 490 W m-2
#' ef_latent_heat(rn = 600, g = 60, h = 50)
#'
#' # H larger than the available energy: LE is negative and kept
#' ef_latent_heat(rn = 400, g = 80, h = 369)
#'
#' # Several pixels sharing one soil heat flux value (recycled)
#' ef_latent_heat(rn = c(550, 600, 620), g = 60, h = c(40, 50, 300))
ef_latent_heat <- function(rn, g, h) {
  call <- sys.call()
  args <- list(rn = rn, g = g, h = h)

  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)

  # Any finite real is allowed; only infinite values are rejected.
  for (nm in names(args)) {
    check_in_range(args[[nm]], nm, call = call)
  }

  rn - g - h
}
