# METRIC: sensible heat flux (H) ----------------------------------------------------
#
# Purpose: air density, sensible heat flux H = rho_air * c_p * dT / rah and
#   the internal calibration of dT from the hot and cold anchor pixels,
#   iterated with the Monin-Obukhov stability correction of rah. Anchor
#   selection and the anchor boundary conditions (LE targets) are NOT
#   performed here (R/metric-anchors.R).
#
# Specification: dev/specs/sensible-heat.md sections 2, 8, 11-13 and 16;
#   decisions SH-08, SH-10, SH-14 to SH-19 and P0-6, P0-9, P0-10 (provisional,
#   dev/DECISIONS.md section 1.0); SH-11 (P0-2) is resolved with the SEBAL
#   Idaho manual (Waters et al., 2002, p. 33, Eq. 38): `stable_psi_m_height`
#   of ef_h_control() defaults to 2 m. Flags:
#   dev/specs/flags.md section 4.2 (EF_H_).
#
# Implemented (exported): ef_air_density(), ef_sensible_heat(),
#   ef_h_control(), ef_calibrate_h() (calibration driver, SH-17).
# Implemented (internal): phase A (iteration at the anchors) and phase B
#   (strategy P2: per-pixel stability iteration with fixed a*, b*), the flag
#   rows of the stage (ef_flags_sensible_heat()) and the cell diagnostics
#   (ef_diagnose_sensible_heat()).

# Air density and sensible heat flux ---------------------------------------------

#' Air density
#'
#' @description
#' Computes the density of moist air \eqn{\rho_{air}}{rho_air} \[kg m-3\]
#' from the atmospheric pressure and the air temperature with the ideal-gas
#' form of FAO-56, using the virtual temperature approximation
#' \eqn{T_{Kv} = 1.01\,T}{T_Kv = 1.01 * T}.
#'
#' @param pressure Numeric. Atmospheric pressure \eqn{P}{P} \[kPa\] (measured,
#'   regionalised or from [ef_air_pressure()]). Must be finite and `> 0`.
#' @param air_temperature Numeric. Air temperature \eqn{T}{T} \[K\]. Must be
#'   finite and `> 0`. In the METRIC calibration this is the near-surface
#'   air temperature \eqn{T_a = T_s - dT}{Ta = Ts - dT} (decision SH-08).
#'
#' @return A numeric vector of air density \[kg m-3\], with the common
#'   length of the inputs and keeping their `dim`.
#'
#' @details
#' \deqn{\rho_{air} = \frac{1000\, P}{1.01\, T\, R}}{rho_air = 1000 * P /
#'   (1.01 * T * R)}
#' with \eqn{R = 287}{R = 287} J kg-1 K-1 (specific gas constant of dry
#' air) and the factor 1000 converting kPa to Pa. FAO-56 (chapter 2, box 6)
#' writes \eqn{T_{Kv} = 1.01 (T + 273)}{T_Kv = 1.01 * (T + 273)} with
#' \eqn{T}{T} in degrees Celsius; EarthFlux takes \eqn{T}{T} in K, which is
#' equivalent to using 273.15 instead of 273 (relative difference about
#' 5e-4; decision SH-08). The normative coefficients 1.01 and 287 are kept
#' as literals of this equation (decision WF-14).
#'
#' Missing values propagate. Infinite values and values outside the domain
#' raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`).
#'
#' Verification status: `VERIFICADA` as the content of FAO-56 (chapter 2,
#' box 6). Its use in METRIC is `CANDIDATA`: the SEBAL Idaho manual
#' computes the air density at \eqn{T_a = T_s - dT}{Ta = Ts - dT}
#' (Waters et al., 2002, p. 31, step 6), which corroborates the temperature
#' used here, but it does not print the density equation (METRIC
#' implementations use a variant with the pressure of a standard atmosphere
#' at \eqn{T_a}{Ta}, about 0.6 % higher).
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' @family aerodynamics and sensible heat functions
#' @export
#'
#' @examples
#' # Air at 300 K and 500 m (pressure from elevation)
#' ef_air_density(ef_air_pressure(500), 300)
#'
#' ef_air_density(pressure = c(95.5276, 93.2947), air_temperature = c(300, 316))
ef_air_density <- function(pressure, air_temperature) {
  call <- sys.call()
  check_core_args(list(pressure = pressure, air_temperature = air_temperature),
                  call)
  check_in_range(pressure, "pressure", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_in_range(air_temperature, "air_temperature", lower = 0,
                 lower_inclusive = FALSE, call = call)
  air_density_core(pressure, air_temperature)
}

#' Air density without input checks
#'
#' @inheritParams ef_air_density
#' @return Air density \[kg m-3\].
#' @noRd
air_density_core <- function(pressure, air_temperature) {
  # FAO-56, chapter 2, box 6, with T in K (normative literals, WF-14).
  1000 * pressure / (1.01 * air_temperature * 287)
}

#' Sensible heat flux
#'
#' @description
#' Computes the sensible heat flux \eqn{H}{H} \[W m-2\] from the air
#' density, the near-surface temperature difference and the aerodynamic
#' resistance to heat transport (bulk transfer equation of METRIC).
#'
#' @param air_density Numeric. Air density \[kg m-3\] (see
#'   [ef_air_density()]). Must be finite and `> 0`.
#' @param dt Numeric. Near-surface temperature difference \eqn{dT}{dT} \[K\]
#'   (from \eqn{dT = a + b\,T_{s,datum}}{dT = a + b * Ts_datum}). Must be
#'   finite; negative values are allowed.
#' @param rah Numeric. Aerodynamic resistance to heat transport \[s m-1\]
#'   (see [ef_rah()]). Must be finite and `> 0`.
#' @param cp Numeric. Specific heat of air at constant pressure
#'   \[J kg-1 K-1\]. Must be finite and `> 0`. Default 1004 J kg-1 K-1 (the
#'   package constant `EF_SPECIFIC_HEAT_AIR`; Waters et al., 2002, p. 25,
#'   text of Eq. 25; decision SH-09), the value used and recorded by
#'   [ef_calibrate_h()] (element `constants$cp`); FAO-56 uses
#'   1013 J kg-1 K-1.
#'
#' @return A numeric vector of sensible heat flux \eqn{H}{H} \[W m-2\], with
#'   the common length of the inputs and keeping their `dim`. Negative values
#'   (\eqn{dT < 0}{dT < 0}, e.g. advection) are physically possible and are
#'   returned unchanged.
#'
#' @details
#' \deqn{H = \frac{\rho_{air}\, c_p\, dT}{r_{ah}}}{H = rho_air * cp * dT /
#'   rah}
#'
#' Within the METRIC calibration, \eqn{dT}{dT} at the anchors is
#' proportional to \eqn{1/c_p}{1/cp}, so that, for a given
#' \eqn{r_{ah}}{rah}, the sensible heat flux of a pixel does not depend on
#' \eqn{c_p}{cp}; it enters only through the Monin-Obukhov length
#' (`dev/specs/sensible-heat.md` section 8.3).
#'
#' Missing values propagate. Infinite values and values outside the domain
#' raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`).
#'
#' Verification status: `VERIFICADA (SEBAL-Idaho 2002)`: Waters et al.
#' (2002), p. 25, Eq. 25, with \eqn{c_p}{cp} = 1004 J kg-1 K-1. The
#' cross-check with Allen et al. (2007) remains desirable but is no longer
#' blocking.
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
#' (2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
#' implementation. Advanced training and users manual* (Version 1.0).
#' University of Idaho and Idaho Department of Water Resources.
#'
#' @family aerodynamics and sensible heat functions
#' @export
#'
#' @examples
#' ef_sensible_heat(air_density = 1.069979, dt = 5.789273, rah = 28.1850)
ef_sensible_heat <- function(air_density, dt, rah,
                             cp = EF_SPECIFIC_HEAT_AIR) {
  call <- sys.call()
  check_core_args(list(air_density = air_density, dt = dt, rah = rah, cp = cp),
                  call)
  check_in_range(air_density, "air_density", lower = 0,
                 lower_inclusive = FALSE, call = call)
  check_in_range(dt, "dt", call = call)
  check_in_range(rah, "rah", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(cp, "cp", lower = 0, lower_inclusive = FALSE, call = call)
  air_density * cp * dt / rah
}

# Control of the calibration ----------------------------------------------------------

#' Control parameters of the sensible heat flux calibration
#'
#' @description
#' Builds and validates the settings of [ef_calibrate_h()]: the heights of
#' the aerodynamic formulation, the height at which the stable stability
#' correction for momentum of the blending height is evaluated (decision
#' SH-11) and the convergence settings of the iteration.
#'
#' @param stable_psi_m_height Numeric scalar. Height \[m\] at which the
#'   stability correction for momentum \eqn{\psi_m}{psi_m} of the blending
#'   height is evaluated **under stable conditions** (\eqn{L > 0}{L > 0}).
#'   Default 2 m, i.e.
#'   \eqn{\psi_m(200\,m) = -5 \cdot 2/L}{psi_m(200 m) = -5 * 2 / L}, as
#'   written in Waters et al. (2002), p. 33, Eq. 38 (decision SH-11,
#'   resolved). Another height may still be chosen explicitly, e.g. the
#'   blending height itself (`stable_psi_m_height = 200`,
#'   \eqn{\psi_m = -5 \cdot 200/L}{psi_m = -5 * 200 / L}); with
#'   \eqn{L = 41.97}{L = 41.97} m the two choices give -0.238 and -23.8.
#'   Under unstable conditions \eqn{\psi_m}{psi_m} is always evaluated at
#'   `blending_height` (Eqs. 35 and 37a). Must be finite, `> 0` and
#'   `<= blending_height`.
#' @param blending_height Numeric scalar. Blending height \eqn{z_b}{z_b}
#'   \[m\]. Default 200 m (Waters et al., 2002, p. 26). Must be finite and
#'   greater than `z2`.
#' @param z1,z2 Numeric scalars. Lower and upper heights of the aerodynamic
#'   resistance \[m\], `0 < z1 < z2`. Defaults 0.1 m and 2 m (Waters et al.,
#'   2002, p. 30 and Eq. 41).
#' @param tol Numeric scalar. Convergence tolerance on the relative change
#'   of \eqn{r_{ah}}{rah} between iterations, applied to every anchor
#'   (phase A) and to every pixel (phase B). Must be `> 0`. Default 0.01
#'   (decision P0-10; value of METRIC implementations, without a primary
#'   source). The value matters: in the synthetic case of the specification,
#'   `tol = 0.01` stops 0.6 % away from the fixed point of the intercept.
#' @param maxit Integer scalar. Maximum number of iterations, `>= 1`.
#'   Default 20 (P0-10; a design choice).
#' @param damping Numeric scalar. Damping factor \eqn{\omega}{omega} in
#'   \[0, 1), \eqn{r_{ah,k} = (1 - \omega) r_{ah,new} + \omega
#'   r_{ah,k-1}}{rah_k = (1 - omega) * rah_new + omega * rah_(k-1)}. Default
#'   0 (P0-10). Damping does not change the fixed point; it can help when the
#'   iteration oscillates.
#'
#' @return A named list with elements `stable_psi_m_height`,
#'   `blending_height`, `z1`, `z2`, `tol`, `maxit` (integer) and `damping`.
#'
#' @details
#' Invalid values raise `earthflux_domain_error` or `earthflux_input_error`
#' (e.g. a `stable_psi_m_height` above the blending height, or `z2 <= z1`).
#'
#' Why 2 m under stable conditions: the manual evaluates the stable
#' correction of the momentum at the blending height with the ratio
#' \eqn{2/L}{2 / L}, not \eqn{200/L}{200 / L}; the `water` package does the
#' same. With a stable cold anchor (\eqn{H < 0}{H < 0}, advection) the
#' calibration converges with 2 m and diverges with 200 m in the synthetic
#' scene of the specification (finding M2-07 of `dev/DECISIONS.md`).
#'
#' Verification status: `blending_height`, `z1`, `z2` and
#' `stable_psi_m_height = 2` are `VERIFICADA (SEBAL-Idaho 2002)` (Waters et
#' al., 2002, pp. 26, 30 and 33, Eqs. 38-41); the cross-check with Allen,
#' Tasumi and Trezza (2007) is desirable but no longer blocking
#' (`dev/VERIFICATION.md`). `tol`, `maxit` and `damping` are design choices
#' adopted provisionally (P0-10).
#'
#' @references
#' Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
#' (2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
#' implementation. Advanced training and users manual* (Version 1.0).
#' University of Idaho and Idaho Department of Water Resources.
#'
#' @family aerodynamics and sensible heat functions
#' @export
#'
#' @examples
#' # Defaults of the SEBAL Idaho manual (z_b = 200 m, z1 = 0.1 m, z2 = 2 m,
#' # stable psi_m of the blending height with 2 / L)
#' ef_h_control()
#'
#' # The blending height in the stable correction, chosen explicitly
#' ef_h_control(stable_psi_m_height = 200)
ef_h_control <- function(stable_psi_m_height = 2, blending_height = 200,
                         z1 = 0.1, z2 = 2, tol = 0.01, maxit = 20L,
                         damping = 0) {
  call <- sys.call()
  required <- c("stable_psi_m_height", "blending_height", "z1", "z2")
  for (nm in c(required, "tol", "maxit", "damping")) {
    check_scalar(get(nm), nm, call = call)
  }
  check_in_range(z1, "z1", lower = 0, lower_inclusive = FALSE, call = call)
  check_condition(z2 > z1, "`z2` must be greater than `z1`", call)
  check_condition(blending_height > z2,
                  "`blending_height` must be greater than `z2`", call)
  check_in_range(stable_psi_m_height, "stable_psi_m_height", lower = 0,
                 upper = blending_height, lower_inclusive = FALSE,
                 call = call)
  check_in_range(tol, "tol", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(maxit, "maxit", lower = 1, call = call)
  check_condition(maxit == round(maxit), "`maxit` must be a whole number",
                  call)
  check_in_range(damping, "damping", lower = 0, upper = 1,
                 upper_inclusive = FALSE, call = call)
  list(
    stable_psi_m_height = as.numeric(stable_psi_m_height),
    blending_height = as.numeric(blending_height),
    z1 = as.numeric(z1),
    z2 = as.numeric(z2),
    tol = as.numeric(tol),
    maxit = as.integer(maxit),
    damping = as.numeric(damping)
  )
}

# Calibration driver ----------------------------------------------------------------------

#' Calibrate the sensible heat flux from the anchor pixels
#'
#' @description
#' Internal calibration of METRIC: finds the coefficients of
#' \eqn{dT = a + b\,T_{s,datum}}{dT = a + b * Ts_datum} such that the hot and
#' cold anchor pixels reproduce their target sensible heat flux
#' \eqn{H_{target} = R_n - G - LE_{target}}{H_target = Rn - G - LE_target},
#' iterating the aerodynamic resistance with the Monin-Obukhov stability
#' correction (phase A), and optionally computes the sensible heat flux of
#' every pixel with the calibrated coefficients (phase B, strategy P2).
#'
#' @param anchors The calibration points: a `data.frame` with exactly one
#'   row of `type` `"hot"` and one of `type` `"cold"` (one calibration point
#'   per anchor class, decision P0-9), or an `earthflux_anchors` object whose
#'   element `calibration_points` is such a data frame. Required columns
#'   (`dev/specs/sensible-heat.md` section 2.2):
#'   * `type`: `"hot"` or `"cold"`;
#'   * `lst`: land surface temperature \[K\];
#'   * `elevation`: elevation \[m\];
#'   * `zom`: momentum roughness length \[m\] (see [ef_zom()]);
#'   * `rn`: net radiation \[W m-2\];
#'   * `g`: soil heat flux \[W m-2\];
#'   * `le_target`: target latent heat flux of the anchor \[W m-2\] (its
#'     boundary condition, computed by the anchor module);
#'   * `u_blend`: wind speed at the blending height \[m s-1\] (see
#'     [ef_blending_wind()]);
#'   * `pressure`: atmospheric pressure \[kPa\].
#'
#'   An optional column `anchor_id` is carried to the result; other columns
#'   are ignored. Missing values at an anchor raise
#'   `earthflux_calibration_error`.
#' @param control The list returned by [ef_h_control()] (heights, the
#'   height of the stable momentum correction of decision SH-11 and the
#'   convergence settings), e.g. `ef_h_control()` for its defaults. It is
#'   validated again; elements not given take the defaults of
#'   [ef_h_control()].
#' @param lapse_rate Numeric scalar. Lapse rate of the surface temperature
#'   with elevation \[K m-1\] (see [ef_ts_datum()]). No default (SH-13).
#' @param datum_elevation Numeric scalar. Elevation of the temperature datum
#'   \[m\], a constant of the scene (see [ef_ts_datum()]).
#' @param pixels `NULL` (phase A only) or a list (or `data.frame`) of
#'   numeric vectors, matrices or arrays of length 1 or a common length, with
#'   elements `lst` \[K\], `elevation` \[m\], `zom` \[m\], `u_blend`
#'   \[m s-1\] and `pressure` \[kPa\], and optionally `rn` and `g`
#'   \[W m-2\] (used only to diagnose `EF_H_GT_AVAILABLE`). Missing values
#'   propagate to the outputs of the pixel.
#'
#' @return An object of class `earthflux_h_calibration`, a list with:
#'   * `a` \[K\], `b` \[-\]: calibrated coefficients (a*, b*), obtained by
#'     solving the anchor conditions once more with the final
#'     \eqn{r_{ah}}{rah} (closure), so that the anchors reproduce
#'     \eqn{H_{target}}{H_target} exactly;
#'   * `converged` (logical) and `iterations` (integer) of phase A;
#'   * `trace`: `data.frame` with one row per iteration: `iteration`, `a`,
#'     `b` (the iterate \eqn{a_k, b_k}{a_k, b_k}), `delta_a`, `delta_b`,
#'     `max_rel_change` (convergence statistic) and, for each anchor
#'     (`_hot`, `_cold`), `dt`, `air_density`, `obukhov_length`, `u_star`
#'     and `rah`;
#'   * `anchors`: `data.frame` with the final state of each anchor
#'     (`anchor_id`, `type`, `lst`, `elevation`, `ts_datum`, `h_target`,
#'     `dt`, `air_density`, `rah`, `u_star`, `obukhov_length`, `h`);
#'   * `pixels`: `NULL`, or a list with `h` \[W m-2\], `dt` \[K\],
#'     `ts_datum` \[K\], `air_density` \[kg m-3\], `rah` \[s m-1\],
#'     `u_star` \[m s-1\], `obukhov_length` \[m\], `converged` (logical) and
#'     `iterations` (integer), each with the shape of the pixel inputs;
#'   * `control`, `datum` (`lapse_rate`, `datum_elevation`), `constants`
#'     (`von_karman`, `gravity`, `cp` and their status) and `provenance`;
#'   * `flags`: list of `earthflux_flag` records, one per code that holds
#'     somewhere: the object flags `EF_H_CALIBRATION_NOT_CONVERGED` and
#'     `EF_H_DT_SLOPE_NONPOSITIVE` (both `critical`), and, with `pixels`,
#'     the cell flags `EF_H_USTAR_INVALID`, `EF_H_PIXEL_NOT_CONVERGED`,
#'     `EF_H_DT_EXTRAPOLATED_HOT`, `EF_H_DT_EXTRAPOLATED_COLD`,
#'     `EF_H_NEGATIVE` and (with `rn` and `g`) `EF_H_GT_AVAILABLE`. A code
#'     evaluated but absent has no record; the codes evaluated are listed
#'     in `provenance$flags_evaluated`.
#'
#' @details
#' **Phase A** (anchors). Start (k = 0): neutral \eqn{u_*}{u*} and
#' \eqn{r_{ah}}{rah} (see [ef_ustar()], [ef_rah()]) and
#' \eqn{dT_0 = 0}{dT_0 = 0} (SH-19). At each iteration k:
#' 1. \eqn{\rho_k}{rho_k} with [ef_air_density()] at
#'    \eqn{T_a = T_s - dT_{k-1}}{Ta = Ts - dT_(k-1)} (SH-08);
#' 2. \eqn{dT_k = H_{target} r_{ah,k-1} / (\rho_k c_p)}{dT_k = H_target *
#'    rah_(k-1) / (rho_k * cp)} at each anchor;
#' 3. \eqn{a_k, b_k}{a_k, b_k} with [ef_dt_coef()];
#' 4. \eqn{H_k = \rho_k c_p (a_k + b_k T_{s,datum}) / r_{ah,k-1}}{H_k =
#'    rho_k * cp * (a_k + b_k * Ts_datum) / rah_(k-1)} (equal to the target
#'    by construction);
#' 5. Monin-Obukhov length
#'    \eqn{L = -\rho c_p u_*^3 T_s / (k g H)}{L = -rho * cp * u*^3 * Ts /
#'    (k * g * H)} with \eqn{u_{*,k-1}}{u*_(k-1)}, the surface temperature
#'    \eqn{T_s}{Ts} and \eqn{\rho_k}{rho_k} (Waters et al., 2002, Eq. 34;
#'    SH-10; \eqn{L = \infty}{L = Inf}, neutral, when \eqn{H = 0}{H = 0});
#' 6. stability corrections (unstable: Paulson-type forms with coefficient
#'    16; stable: log-linear form \eqn{-5 z/L}{-5 * z / L}), with
#'    \eqn{\psi_m}{psi_m} at the blending height (or at
#'    `stable_psi_m_height` when \eqn{L > 0}{L > 0}: 2 m by default,
#'    Waters et al., 2002, Eq. 38, decision SH-11)
#'    and \eqn{\psi_h}{psi_h} at `z2` and `z1`; then \eqn{u_{*,k}}{u*_k} and
#'    the new \eqn{r_{ah}}{rah};
#' 7. damping: \eqn{r_{ah,k} = (1 - \omega) r_{ah,new} + \omega
#'    r_{ah,k-1}}{rah_k = (1 - omega) * rah_new + omega * rah_(k-1)};
#' 8. convergence when \eqn{\max_i |r_{ah,k} - r_{ah,k-1}| / r_{ah,k} <
#'    tol}{max_i |rah_k - rah_(k-1)| / rah_k < tol} over both anchors.
#'
#' Closure: steps 1-3 are repeated with the final \eqn{r_{ah}}{rah} to give
#' (a*, b*), and \eqn{r_{ah}}{rah} is not updated afterwards, so the anchors
#' reproduce \eqn{H_{target}}{H_target} exactly.
#'
#' **Phase B** (pixels, strategy P2, decision P0-10). With (a*, b*) fixed,
#' \eqn{dT = a^* + b^* T_{s,datum}}{dT = a* + b* * Ts_datum} and
#' \eqn{\rho}{rho} (at \eqn{T_a = T_s - dT}{Ta = Ts - dT}) are fixed; each
#' pixel iterates only its stability correction
#' (\eqn{H \to L \to \psi \to u_* \to r_{ah}}{H -> L -> psi -> u* -> rah})
#' from the neutral state until its own convergence (same `tol`, `maxit`
#' and `damping`). The result of a pixel depends only on its inputs and on
#' (a*, b*), not on the other pixels nor on the path of phase A, so the
#' computation can be split into blocks.
#'
#' **Failures are never silent.**
#' * Phase A without convergence after `maxit` iterations: the last iterate
#'   is returned with `converged = FALSE`, a warning of class
#'   `earthflux_convergence_warning` is signalled (fields `iterations` and
#'   `trace`) and the object flag `EF_H_CALIBRATION_NOT_CONVERGED`
#'   (`critical`) is set.
#' * Calibrated slope `b <= 0`: a warning of class `earthflux_warning` and
#'   the object flag `EF_H_DT_SLOPE_NONPOSITIVE` (`critical`).
#' * Missing values at an anchor, `u_blend = 0` at an anchor, datum
#'   temperature of the hot anchor not greater than that of the cold anchor,
#'   or non-finite \eqn{a}{a}, \eqn{b}{b}, \eqn{u_*}{u*}, \eqn{r_{ah}}{rah}
#'   or air density at an anchor during the iteration: error of class
#'   `earthflux_calibration_error` (fields `iteration` and `trace` when the
#'   failure occurs during the iteration).
#' * A pixel whose friction velocity becomes undefined (see [ef_ustar()]) or
#'   not positive: `NA` outputs for that pixel and the cell flag
#'   `EF_H_USTAR_INVALID`; a pixel without convergence keeps its last
#'   iterate and gets `EF_H_PIXEL_NOT_CONVERGED`.
#'
#' Constants: von Karman constant `EF_VON_KARMAN` (0.41), gravity
#' `EF_GRAVITY` (9.81 m s-2) and specific heat of air `EF_SPECIFIC_HEAT_AIR`
#' (1004 J kg-1 K-1), the values of Waters et al. (2002, pp. 25-26 and 32);
#' they are recorded in `constants`.
#'
#' Verification status: the forms are `VERIFICADA (SEBAL-Idaho 2002)`: the
#' iterative scheme of Waters et al. (2002), pp. 25-34 (figure 4, Eqs.
#' 25-41) and appendix 8 (anchor conditions of p. 30-31, dT from Eq. 33,
#' \eqn{dT}{dT} linear in the surface temperature, Eq. 32, Monin-Obukhov
#' length with \eqn{T_s}{Ts}, Eq. 34, stability corrections, Eqs. 35-39,
#' corrected \eqn{u_*}{u*} and \eqn{r_{ah}}{rah}, Eqs. 40-41). The
#' procedural choices are EarthFlux decisions (P0-10, `CANDIDATA` as
#' procedure): the manual iterates "until the successive values for dT_hot
#' and rah at the hot pixel have stabilized" (p. 34; 3 to 7 iterations,
#' appendix 8), whereas EarthFlux uses a relative tolerance on rah at both
#' anchors, the closure of the anchors and phase B with the per-pixel
#' strategy P2. Known differences with `water` are listed in section 17 of
#' `dev/specs/sensible-heat.md` (e.g. no wind floor, no substitute friction
#' velocity, per-anchor convergence, strategy P2). The cross-check with
#' Allen, Tasumi and Trezza (2007) remains desirable but is no longer
#' blocking; Paulson (1970) and Webb (1970) were not consulted.
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
#' (2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
#' implementation. Advanced training and users manual* (Version 1.0).
#' University of Idaho and Idaho Department of Water Resources.
#'
#' Paulson, C. A. (1970). The mathematical representation of wind speed and
#' temperature profiles in the unstable atmospheric surface layer. *Journal
#' of Applied Meteorology*, 9(6), 857-861.
#' \doi{10.1175/1520-0450(1970)009<0857:TMROWS>2.0.CO;2}
#'
#' Webb, E. K. (1970). Profile relationships: The log-linear range, and
#' extension to strong stability. *Quarterly Journal of the Royal
#' Meteorological Society*, 96(407), 67-90. \doi{10.1002/qj.49709640708}
#'
#' @family aerodynamics and sensible heat functions
#' @export
#'
#' @examples
#' # Synthetic scene of dev/specs/sensible-heat.md section 14
#' u_b <- ef_blending_wind(3, height = 2, zom_station = 0.015, d_station = 0,
#'                         blending_height = 200)
#' anchors <- data.frame(
#'   type = c("cold", "hot"),
#'   lst = c(300, 316),
#'   elevation = c(500, 700),
#'   zom = c(0.06, 0.005),
#'   rn = c(600, 480),
#'   g = c(50, 110),
#'   le_target = c(520, 0),
#'   u_blend = u_b,
#'   pressure = ef_air_pressure(c(500, 700))
#' )
#' # Heights of the SEBAL Idaho manual (the defaults of ef_h_control())
#' ctrl <- ef_h_control()
#' cal <- ef_calibrate_h(anchors, control = ctrl, lapse_rate = 0.00649,
#'                       datum_elevation = 500,
#'                       pixels = list(lst = 308, elevation = 500, zom = 0.02,
#'                                     u_blend = u_b,
#'                                     pressure = ef_air_pressure(500)))
#' c(a = cal$a, b = cal$b, iterations = cal$iterations)
#' cal$pixels$h
ef_calibrate_h <- function(anchors, control, lapse_rate, datum_elevation,
                           pixels = NULL) {
  call <- sys.call()
  if (missing(control) || !is.list(control)) {
    ef_abort("`control` must be the list returned by `ef_h_control()`.",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  unknown <- setdiff(names(control), names(formals(ef_h_control)))
  if (is.null(names(control)) || length(unknown) > 0L) {
    ef_abort("`control` must be the list returned by `ef_h_control()`.",
             class = "earthflux_input_error", call = call)
  }
  control <- do.call(ef_h_control, control)
  check_scalar(lapse_rate, "lapse_rate", call = call)
  check_in_range(lapse_rate, "lapse_rate", lower = 0, call = call)
  check_scalar(datum_elevation, "datum_elevation", call = call)
  cp <- EF_SPECIFIC_HEAT_AIR

  anc <- h_anchor_inputs(anchors, control, call)
  ts_datum <- anc$lst + lapse_rate * (anc$elevation - datum_elevation)
  if (!(ts_datum[["hot"]] > ts_datum[["cold"]])) {
    ef_abort(
      paste0(
        "The datum temperature of the hot anchor must be greater than that ",
        "of the cold anchor (swapped anchors or undefined slope of dT)."
      ),
      class = "earthflux_calibration_error",
      ts_datum = ts_datum,
      call = call
    )
  }
  h_target <- anc$rn - anc$g - anc$le_target

  fit <- h_phase_a(anc, ts_datum, h_target, control, cp, call)

  object_flags <- ef_flag_set(
    list(EF_H_CALIBRATION_NOT_CONVERGED = !fit$converged,
         EF_H_DT_SLOPE_NONPOSITIVE = fit$b <= 0),
    scope = "object"
  )
  cell_flags <- ef_flag_set(list())
  if (!fit$converged) {
    ef_warn(
      sprintf(
        paste0(
          "The calibration of dT did not converge in %d iteration(s) ",
          "(tol = %g); the last iterate is returned and flagged ",
          "EF_H_CALIBRATION_NOT_CONVERGED."
        ),
        fit$iterations, control$tol
      ),
      class = "earthflux_convergence_warning",
      iterations = fit$iterations,
      trace = fit$trace,
      call = call
    )
  }
  if (fit$b <= 0) {
    ef_warn(
      sprintf(
        paste0(
          "The calibrated slope of dT is not positive (b = %g): dT does not ",
          "grow with the surface temperature; flagged ",
          "EF_H_DT_SLOPE_NONPOSITIVE."
        ),
        fit$b
      ),
      call = call
    )
  }

  pix <- NULL
  if (!is.null(pixels)) {
    inp <- h_pixel_inputs(pixels, control, call)
    pts <- inp$lst + lapse_rate * (inp$elevation - datum_elevation)
    pix <- h_phase_b(inp, pts, fit$a, fit$b, control, cp)
    cell_flags <- ef_diagnose_sensible_heat(
      h = pix$h,
      ts_datum = pix$ts_datum,
      ts_datum_hot = ts_datum[["hot"]],
      ts_datum_cold = ts_datum[["cold"]],
      u_star = pix$u_star,
      converged = pix$converged,
      input_ok = inp$input_ok,
      rn = inp$rn,
      g = inp$g
    )
    if (!is.null(inp$dim)) {
      pix <- lapply(pix, function(x) {
        dim(x) <- inp$dim
        x
      })
    }
  }

  flags <- ef_flags_combine(object_flags, cell_flags)

  anchor_state <- data.frame(
    anchor_id = anc$anchor_id,
    type = c("hot", "cold"),
    lst = unname(anc$lst),
    elevation = unname(anc$elevation),
    ts_datum = unname(ts_datum),
    h_target = unname(h_target),
    dt = unname(fit$state$dt),
    air_density = unname(fit$state$air_density),
    rah = unname(fit$state$rah),
    u_star = unname(fit$state$u_star),
    obukhov_length = unname(fit$state$obukhov_length),
    h = unname(fit$state$h),
    stringsAsFactors = FALSE
  )

  new_ef_object(
    list(
      a = fit$a,
      b = fit$b,
      converged = fit$converged,
      iterations = fit$iterations,
      trace = fit$trace,
      anchors = anchor_state,
      pixels = pix,
      control = control,
      datum = list(lapse_rate = lapse_rate,
                   datum_elevation = datum_elevation),
      constants = list(
        von_karman = EF_VON_KARMAN,
        gravity = EF_GRAVITY,
        cp = cp,
        status = c(von_karman = "VERIFICADA (FAO-56; SEBAL-Idaho 2002)",
                   gravity = "VERIFICADA (SEBAL-Idaho 2002)",
                   cp = "VERIFICADA (SEBAL-Idaho 2002)")
      ),
      provenance = list(
        procedure = paste0(
          "METRIC dT calibration: phase A at the anchors with closure; ",
          "phase B strategy P2"
        ),
        status = paste0(
          "VERIFICADA (SEBAL-Idaho 2002) forms; ",
          "procedure: provisional decisions P0-10"
        ),
        specification = "dev/specs/sensible-heat.md sections 9-11",
        anchors_input = if (inherits(anchors, "earthflux_anchors")) {
          "earthflux_anchors$calibration_points"
        } else {
          "data.frame"
        },
        flags_evaluated = flags$evaluated,
        package_version = as.character(getNamespaceVersion("EarthFlux"))
      ),
      flags = flags$flags
    ),
    "earthflux_h_calibration"
  )
}

# Internal steps of the calibration ----------------------------------------------------

#' Validate the calibration points of the anchors
#'
#' Minimal input contract (dev/specs/sensible-heat.md sections 2.2-2.3,
#' decision P0-9): one row per anchor class.
#'
#' @param anchors A data frame or an `earthflux_anchors` object.
#' @param control Validated control list.
#' @param call The call to report.
#' @return A list of numeric vectors named `c("hot", "cold")` (`lst`,
#'   `elevation`, `zom`, `rn`, `g`, `le_target`, `u_blend`, `pressure`) and
#'   the character vector `anchor_id`.
#' @noRd
h_anchor_inputs <- function(anchors, control, call) {
  if (inherits(anchors, "earthflux_anchors")) {
    anchors <- anchors[["calibration_points"]]
  }
  if (!is.data.frame(anchors)) {
    ef_abort(
      paste0(
        "`anchors` must be a data frame of calibration points (or an ",
        "`earthflux_anchors` object whose `calibration_points` is one)."
      ),
      class = "earthflux_input_error",
      call = call
    )
  }
  num_cols <- c("lst", "elevation", "zom", "rn", "g", "le_target",
                "u_blend", "pressure")
  absent <- setdiff(c("type", num_cols), names(anchors))
  if (length(absent) > 0L) {
    ef_abort(
      sprintf("`anchors` lacks the column(s): %s.",
              paste0("`", absent, "`", collapse = ", ")),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  type <- as.character(anchors$type)
  if (anyNA(type) || !all(type %in% c("hot", "cold")) ||
      sum(type == "hot") != 1L || sum(type == "cold") != 1L) {
    ef_abort(
      paste0(
        "`anchors` must have exactly one row of type \"hot\" and one of ",
        "type \"cold\" (one calibration point per class; several anchors ",
        "are aggregated by the anchor module, decision P0-9)."
      ),
      class = "earthflux_input_error",
      call = call
    )
  }
  rows <- c(hot = which(type == "hot"), cold = which(type == "cold"))
  out <- list()
  for (nm in num_cols) {
    x <- anchors[[nm]]
    check_numeric(x, nm, call = call)
    x <- as.numeric(x[rows])
    names(x) <- names(rows)
    if (anyNA(x)) {
      ef_abort(
        sprintf(
          "Missing value of `%s` at an anchor: the calibration cannot proceed.",
          nm
        ),
        class = "earthflux_calibration_error",
        call = call
      )
    }
    out[[nm]] <- x
  }
  check_in_range(out$lst, "lst", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_in_range(out$elevation, "elevation", call = call)
  check_in_range(out$zom, "zom", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_condition(out$zom < control$blending_height,
                  "`zom` must be lower than the blending height", call)
  check_in_range(out$rn, "rn", call = call)
  check_in_range(out$g, "g", call = call)
  check_in_range(out$le_target, "le_target", call = call)
  check_in_range(out$u_blend, "u_blend", lower = 0, call = call)
  check_in_range(out$pressure, "pressure", lower = 0, lower_inclusive = FALSE,
                 call = call)
  if (any(out$u_blend == 0)) {
    ef_abort(
      paste0(
        "Wind speed at the blending height is 0 at an anchor: the friction ",
        "velocity is 0 and the aerodynamic resistance is infinite."
      ),
      class = "earthflux_calibration_error",
      call = call
    )
  }
  out$anchor_id <- if ("anchor_id" %in% names(anchors)) {
    as.character(anchors$anchor_id[rows])
  } else {
    c("hot", "cold")
  }
  out
}

#' Validate the pixel inputs of phase B
#'
#' @param pixels A list or data frame.
#' @param control Validated control list.
#' @param call The call to report.
#' @return A list of plain numeric vectors of common length (`lst`,
#'   `elevation`, `zom`, `u_blend`, `pressure`, and `rn`, `g` or `NULL`),
#'   `input_ok` (logical, no missing input) and `dim` (or `NULL`).
#' @noRd
h_pixel_inputs <- function(pixels, control, call) {
  if (!is.list(pixels)) {
    ef_abort("`pixels` must be a list or data frame of numeric inputs.",
             class = "earthflux_input_error", call = call)
  }
  required <- c("lst", "elevation", "zom", "u_blend", "pressure")
  absent <- setdiff(required, names(pixels))
  if (length(absent) > 0L) {
    ef_abort(
      sprintf("`pixels` lacks the element(s): %s.",
              paste0("`", absent, "`", collapse = ", ")),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  optional <- intersect(c("rn", "g"), names(pixels))
  if (length(optional) == 1L) {
    ef_abort("`pixels` must contain both `rn` and `g`, or neither.",
             class = "earthflux_input_error", call = call)
  }
  args <- as.list(pixels)[c(required, optional)]
  n <- check_core_args(args, call)
  check_in_range(args$lst, "lst", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_in_range(args$elevation, "elevation", call = call)
  check_in_range(args$zom, "zom", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_condition(args$zom < control$blending_height,
                  "`zom` must be lower than the blending height", call)
  check_in_range(args$u_blend, "u_blend", lower = 0, call = call)
  check_in_range(args$pressure, "pressure", lower = 0,
                 lower_inclusive = FALSE, call = call)
  for (nm in optional) {
    check_in_range(args[[nm]], nm, call = call)
  }
  dims <- Filter(Negate(is.null), lapply(args, dim))
  out <- lapply(args, function(x) rep_len(as.numeric(x), n))
  ok <- rep(TRUE, n)
  for (nm in required) {
    ok <- ok & !is.na(out[[nm]])
  }
  c(out[required],
    list(rn = out$rn, g = out$g, input_ok = ok,
         dim = if (length(dims) > 0L) dims[[1L]] else NULL))
}

#' One stability step: H -> L -> psi -> u* -> rah
#'
#' @param air_density Air density \[kg m-3\].
#' @param u_star Friction velocity of the previous step \[m s-1\].
#' @param lst Land surface temperature \[K\] (the temperature of the
#'   Monin-Obukhov length, Waters et al., 2002, p. 32, Eq. 34).
#' @param h Sensible heat flux \[W m-2\].
#' @param u_blend Wind speed at the blending height \[m s-1\].
#' @param log_blend `log(blending_height / zom)`.
#' @param control Validated control list.
#' @param cp Specific heat of air \[J kg-1 K-1\].
#' @return A list with `obukhov_length`, `u_star` and `rah` (undamped);
#'   `u_star` and `rah` are `NA` where they are not defined or not positive.
#' @noRd
h_stability_step <- function(air_density, u_star, lst, h, u_blend, log_blend,
                             control, cp) {
  obukhov <- ef_monin_obukhov_length(air_density, u_star, lst, h, cp)
  # Height of psi_m for the blending height: z_b when unstable or neutral,
  # `stable_psi_m_height` when stable (decision SH-11: 2 m by default, as in
  # Waters et al., 2002, p. 33, Eq. 38).
  z_m <- rep(control$blending_height, length(obukhov))
  z_m[!is.na(obukhov) & obukhov > 0] <- control$stable_psi_m_height
  u_new <- ustar_core(u_blend, log_blend, ef_psi_m(z_m, obukhov))
  u_new[!is.na(u_new) & !(is.finite(u_new) & u_new > 0)] <- NA_real_
  rah_new <- rah_core(u_new, log(control$z2 / control$z1),
                      ef_psi_h(control$z2, obukhov),
                      ef_psi_h(control$z1, obukhov))
  list(obukhov_length = obukhov, u_star = u_new, rah = rah_new)
}

#' Abort the calibration at an anchor
#'
#' @param what Character. Description of the failure.
#' @param iteration Integer. Iteration at which it occurred.
#' @param trace The trace so far.
#' @param call The call to report.
#' @noRd
h_anchor_abort <- function(what, iteration, trace, call) {
  ef_abort(
    sprintf("The calibration of dT failed at iteration %d: %s.", iteration,
            what),
    class = "earthflux_calibration_error",
    iteration = iteration,
    trace = trace,
    call = call
  )
}

#' Bind the rows of the calibration trace
#'
#' @param rows List of one-row data frames.
#' @return A data frame.
#' @noRd
h_bind_trace <- function(rows) {
  if (length(rows) == 0L) {
    return(NULL)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Phase A: iteration at the anchors and closure
#'
#' @param anc Output of `h_anchor_inputs()`.
#' @param ts_datum Datum temperatures, named `c("hot", "cold")` \[K\].
#' @param h_target Target sensible heat flux, named `c("hot", "cold")`.
#' @param control Validated control list.
#' @param cp Specific heat of air \[J kg-1 K-1\].
#' @param call The call to report.
#' @return A list with `a`, `b`, `converged`, `iterations`, `trace` and
#'   `state` (final anchor state, vectors named `c("hot", "cold")`).
#' @noRd
h_phase_a <- function(anc, ts_datum, h_target, control, cp, call) {
  log_blend <- log(control$blending_height / anc$zom)
  log_z <- log(control$z2 / control$z1)
  u_star <- ustar_core(anc$u_blend, log_blend, 0)
  rah <- rah_core(u_star, log_z, 0, 0)
  obukhov <- c(hot = Inf, cold = Inf)
  dt <- c(hot = 0, cold = 0)
  rows <- list()
  if (any(is.na(u_star) | is.na(rah))) {
    h_anchor_abort("invalid neutral friction velocity or resistance", 0L,
                   NULL, call)
  }

  converged <- FALSE
  a_prev <- NA_real_
  b_prev <- NA_real_
  k <- 0L
  for (k in seq_len(control$maxit)) {
    rho <- air_density_core(anc$pressure, anc$lst - dt)
    if (any(!is.finite(rho) | rho <= 0)) {
      h_anchor_abort("non-positive or non-finite air density", k,
                     h_bind_trace(rows), call)
    }
    dt <- h_target * rah / (rho * cp)
    co <- dt_coef_core(ts_datum[["hot"]], ts_datum[["cold"]], dt[["hot"]],
                       dt[["cold"]])
    if (!is.finite(co$a) || !is.finite(co$b)) {
      h_anchor_abort("non-finite coefficients a or b", k, h_bind_trace(rows),
                     call)
    }
    h <- rho * cp * (co$a + co$b * ts_datum) / rah
    step <- h_stability_step(rho, u_star, anc$lst, h, anc$u_blend,
                             log_blend, control, cp)
    if (anyNA(step$u_star) || anyNA(step$rah)) {
      h_anchor_abort(
        "undefined or non-positive friction velocity at an anchor",
        k, h_bind_trace(rows), call
      )
    }
    rah_new <- (1 - control$damping) * step$rah + control$damping * rah
    change <- max(abs(rah_new - rah) / rah_new)
    u_star <- step$u_star
    obukhov <- step$obukhov_length
    rah <- rah_new
    rows[[k]] <- data.frame(
      iteration = k, a = co$a, b = co$b,
      delta_a = co$a - a_prev, delta_b = co$b - b_prev,
      max_rel_change = change,
      dt_hot = dt[["hot"]], dt_cold = dt[["cold"]],
      air_density_hot = rho[["hot"]], air_density_cold = rho[["cold"]],
      obukhov_length_hot = obukhov[["hot"]],
      obukhov_length_cold = obukhov[["cold"]],
      u_star_hot = u_star[["hot"]], u_star_cold = u_star[["cold"]],
      rah_hot = rah[["hot"]], rah_cold = rah[["cold"]]
    )
    a_prev <- co$a
    b_prev <- co$b
    if (change < control$tol) {
      converged <- TRUE
      break
    }
  }
  trace <- h_bind_trace(rows)

  # Closure (dev/specs/sensible-heat.md section 11.2): steps 1-3 with the
  # final rah; rah is not updated afterwards.
  rho <- air_density_core(anc$pressure, anc$lst - dt)
  if (any(!is.finite(rho) | rho <= 0)) {
    h_anchor_abort("non-positive or non-finite air density at the closure",
                   k, trace, call)
  }
  dt <- h_target * rah / (rho * cp)
  co <- dt_coef_core(ts_datum[["hot"]], ts_datum[["cold"]], dt[["hot"]],
                     dt[["cold"]])
  if (!is.finite(co$a) || !is.finite(co$b)) {
    h_anchor_abort("non-finite coefficients a or b at the closure", k, trace,
                   call)
  }
  h <- rho * cp * (co$a + co$b * ts_datum) / rah

  list(
    a = co$a,
    b = co$b,
    converged = converged,
    iterations = as.integer(k),
    trace = trace,
    state = list(dt = dt, air_density = rho, rah = rah, u_star = u_star,
                 obukhov_length = obukhov, h = h)
  )
}

#' Phase B, strategy P2: per-pixel stability iteration with fixed a*, b*
#'
#' Element-wise: the result of a pixel depends only on its inputs, on `a`,
#' `b` and on `control` (block-size invariant). Converged pixels are frozen.
#'
#' @param inp Output of `h_pixel_inputs()`.
#' @param ts_datum Datum temperature of the pixels \[K\].
#' @param a,b Calibrated coefficients.
#' @param control Validated control list.
#' @param cp Specific heat of air \[J kg-1 K-1\].
#' @return A list of plain vectors: `h`, `dt`, `ts_datum`, `air_density`,
#'   `rah`, `u_star`, `obukhov_length`, `converged`, `iterations`.
#' @noRd
h_phase_b <- function(inp, ts_datum, a, b, control, cp) {
  n <- length(inp$lst)
  dt <- a + b * ts_datum
  rho <- air_density_core(inp$pressure, inp$lst - dt)
  log_blend <- log(control$blending_height / inp$zom)
  u_star <- ustar_core(inp$u_blend, log_blend, 0)
  u_star[!is.na(u_star) & !(u_star > 0)] <- NA_real_
  rah <- rah_core(u_star, log(control$z2 / control$z1), 0, 0)
  # A pixel whose near-surface air temperature Ts - dT is not positive (an
  # absurd extrapolation of dT) has no valid density: it is treated like an
  # invalid friction velocity (NA outputs, EF_H_USTAR_INVALID).
  valid <- inp$input_ok & !is.na(u_star) & !is.na(rah) &
    !is.na(rho) & rho > 0
  u_star[!valid] <- NA_real_
  rah[!valid] <- NA_real_
  obukhov <- rep(NA_real_, n)
  converged <- rep(NA, n)
  iterations <- rep(NA_integer_, n)
  converged[valid] <- FALSE
  iterations[valid] <- 0L
  active <- valid

  for (k in seq_len(control$maxit)) {
    idx <- which(active)
    if (length(idx) == 0L) {
      break
    }
    h <- rho[idx] * cp * dt[idx] / rah[idx]
    step <- h_stability_step(rho[idx], u_star[idx], inp$lst[idx], h,
                             inp$u_blend[idx], log_blend[idx], control, cp)
    bad <- is.na(step$u_star) | is.na(step$rah)
    rah_new <- (1 - control$damping) * step$rah + control$damping * rah[idx]
    change <- abs(rah_new - rah[idx]) / rah_new
    ok <- idx[!bad]
    u_star[ok] <- step$u_star[!bad]
    obukhov[ok] <- step$obukhov_length[!bad]
    rah[ok] <- rah_new[!bad]
    iterations[idx] <- k
    done <- idx[!bad & change < control$tol]
    converged[done] <- TRUE
    active[done] <- FALSE
    failed <- idx[bad]
    u_star[failed] <- NA_real_
    rah[failed] <- NA_real_
    obukhov[failed] <- NA_real_
    converged[failed] <- NA
    active[failed] <- FALSE
  }

  h <- rho * cp * dt / rah
  list(h = h, dt = dt, ts_datum = ts_datum, air_density = rho, rah = rah,
       u_star = u_star, obukhov_length = obukhov, converged = converged,
       iterations = iterations)
}

# Diagnostic flags of this stage -------------------------------------------------

#' Flag codes owned by the sensible heat (z_om, u*, rah, stability, dT and H) stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_H_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7).
#'
#' Not registered: `EF_H_ZOM_FLOOR_APPLIED` (I-m, minimum of z_om not
#' verified, SH-02), `EF_H_ZOM_TERRAIN_ADJUSTED` (terrain method not
#' implemented, SH-03), `EF_H_WIND_FLOOR_APPLIED` (no wind floor, SH-06),
#' and the class II codes `EF_H_WIND_LOW` and `EF_H_STABILITY_STRONG`.
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_sensible_heat <- function() {
  spec <- "dev/specs/flags.md 4.2; dev/specs/sensible-heat.md"
  ef_flag_rows(
    code = c(
      "EF_H_USTAR_INVALID",
      "EF_H_PIXEL_NOT_CONVERGED",
      "EF_H_DT_EXTRAPOLATED_HOT",
      "EF_H_DT_EXTRAPOLATED_COLD",
      "EF_H_NEGATIVE",
      "EF_H_GT_AVAILABLE",
      "EF_H_CALIBRATION_NOT_CONVERGED",
      "EF_H_DT_SLOPE_NONPOSITIVE"
    ),
    stage = rep("H", 8L),
    severity = c("warning", "warning", "info", "info", "info", "warning",
                 "critical", "critical"),
    scope = c(rep("cell", 6L), "object", "object"),
    bit = c(4L, 5L, 6L, 7L, 8L, 9L, NA, NA),
    error_class = c("earthflux_calibration_error", NA, NA, NA, NA, NA,
                    "earthflux_calibration_error",
                    "earthflux_calibration_error"),
    description = c(
      paste0("The friction velocity is undefined or not positive after the ",
             "stability correction; outputs are NA at this location."),
      paste0("The per-pixel stability iteration did not converge; the last ",
             "iterate is kept."),
      paste0("The datum surface temperature is above that of the hot ",
             "anchor; dT is extrapolated."),
      paste0("The datum surface temperature is below that of the cold ",
             "anchor; dT is extrapolated."),
      "The sensible heat flux is negative (dT < 0), e.g. by advection.",
      paste0("The sensible heat flux exceeds the positive available energy ",
             "Rn - G, so the residual LE is negative."),
      paste0("The calibration of dT at the anchors did not meet its ",
             "convergence criterion; the last iterate is returned."),
      paste0("The calibrated slope of dT is not positive with well-ordered ",
             "anchors.")
    ),
    spec = paste(spec, c("11.6", "11.6", "9.4", "9.4", "9.4", "16", "11.6",
                         "9.3")),
    since = rep("0.1.0", 8L)
  )
}

#' Cell diagnostics of the sensible heat stage
#'
#' Builds the cell-scope flags of the stage from the inputs and outputs of
#' phase B (dev/ARCHITECTURE.md section 3.2): the numeric functions never
#' build flags. As for every stage (R/diagnostics.R), a record is returned
#' only for the codes flagged in at least one position, and the codes
#' evaluated are attached as the attribute `evaluated`.
#' `EF_H_USTAR_INVALID` and `EF_H_PIXEL_NOT_CONVERGED` are evaluated only
#' when `u_star`/`input_ok` and `converged` are given, and
#' `EF_H_GT_AVAILABLE` only when `rn` and `g` are given.
#'
#' @param h Sensible heat flux \[W m-2\].
#' @param ts_datum Datum surface temperature of the pixels \[K\].
#' @param ts_datum_hot,ts_datum_cold Datum surface temperature of the hot
#'   and cold anchors \[K\] (scalars).
#' @param u_star Friction velocity \[m s-1\] or `NULL`.
#' @param converged Logical per-pixel convergence (`NA` where not
#'   evaluated) or `NULL`.
#' @param input_ok Logical, `TRUE` where no required input is missing, or
#'   `NULL` (then `EF_H_USTAR_INVALID` is not evaluated).
#' @param rn,g Net radiation and soil heat flux \[W m-2\], or `NULL`.
#' @return A (possibly empty) list of `earthflux_flag` records (scope
#'   `"cell"`) with the attribute `evaluated`.
#' @noRd
ef_diagnose_sensible_heat <- function(h, ts_datum, ts_datum_hot,
                                      ts_datum_cold, u_star = NULL,
                                      converged = NULL, input_ok = NULL,
                                      rn = NULL, g = NULL) {
  h <- as.vector(h)
  ts_datum <- as.vector(ts_datum)
  masks <- list()
  if (!is.null(u_star) && !is.null(input_ok)) {
    masks$EF_H_USTAR_INVALID <- as.vector(input_ok) &
      is.na(as.vector(u_star))
  }
  if (!is.null(converged)) {
    conv <- as.vector(converged)
    masks$EF_H_PIXEL_NOT_CONVERGED <- !is.na(conv) & !conv
  }
  known <- !is.na(ts_datum)
  masks$EF_H_DT_EXTRAPOLATED_HOT <- known & ts_datum > ts_datum_hot
  masks$EF_H_DT_EXTRAPOLATED_COLD <- known & ts_datum < ts_datum_cold
  masks$EF_H_NEGATIVE <- !is.na(h) & h < 0
  if (!is.null(rn) && !is.null(g)) {
    available <- as.vector(rn) - as.vector(g)
    masks$EF_H_GT_AVAILABLE <- !is.na(h) & !is.na(available) &
      available > 0 & h > available
  }
  ef_flag_set(masks, scope = "cell")
}
