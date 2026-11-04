# METRIC: aerodynamic transport (rah, u*, roughness, stability) ------------------
#
# Purpose: momentum roughness length, wind speed at the blending height,
#   friction velocity, aerodynamic resistance to heat transport and
#   Monin-Obukhov stability corrections.
#
# Specification: dev/specs/sensible-heat.md sections 5-7 and 10 (names per
#   dev/NAMING.md). Every METRIC form here is CANDIDATA (observed in the
#   `water` package and in secondary sources; Allen, Tasumi and Trezza, 2007,
#   not yet consulted). Only the FAO-56 forms (z_om = 0.123 h and the neutral
#   logarithmic profile) are VERIFICADA as FAO-56 content.
#
# Implemented (exported):
#   - ef_zom() dispatcher (an earthflux_roughness_length object with the
#     EF_INPUT_NA flag and provenance) and its methods ef_zom_lai(),
#     ef_zom_ndvi(), ef_zom_perrier(), ef_zom_height() (plain numeric; one
#     Rd, rule N6 of dev/NAMING.md);
#   - ef_blending_wind(), ef_ustar(), ef_rah().
# Implemented (internal): ef_monin_obukhov_length(), ef_psi_m(), ef_psi_h()
#   (decision SH-17: stability helpers stay internal).
#
# Not implemented on purpose (decisions of section 18 of the spec):
#   - the 0.005 m minimum of z_om (SH-02, not verified): z_om = 0 is returned
#     unchanged and rejected downstream by ef_ustar();
#   - the mountainous-terrain factor of z_om (SH-03, disabled until verified);
#   - a wind floor (SH-06) and the elevation adjustment of the wind (SH-07).
#
# Conventions: those of ef_net_radiation() (dev/ARCHITECTURE.md section 3.1).
#   Unverified numeric choices (blending height, z1, z2, station roughness and
#   displacement) are explicit arguments without defaults (DECISIONS.md
#   section 1.0).

# Shared input checks (check_core_args(), check_condition(), check_scalar())
# are in R/utils.R.

# Momentum roughness length ----------------------------------------------------------

#' Momentum roughness length
#'
#' @description
#' Computes the surface roughness length for momentum transport
#' \eqn{z_{om}}{z_om} \[m\], which controls the friction velocity and the
#' aerodynamic resistance to heat transport of the METRIC energy balance.
#' `ef_zom()` is the dispatcher of the family: it checks `method` (no
#' default), forwards the arguments to one of the method functions (which can
#' also be called directly), builds the diagnostic flags and records the
#' provenance.
#'
#' * `ef_zom_lai()`: linear function of the leaf area index, for short
#'   (agricultural) crops.
#' * `ef_zom_ndvi()`: exponential function of NDVI / albedo with
#'   user-supplied coefficients (to be fitted to points of known roughness).
#' * `ef_zom_perrier()`: Perrier function of LAI, canopy height and the
#'   fraction of LAI above half the canopy height, for trees and tall crops.
#' * `ef_zom_height()`: FAO-56 function of the vegetation height, mainly for
#'   the surface around a weather station.
#'
#' @param lai Numeric. Leaf area index \[m2 m-2\]. Must be finite and `>= 0`.
#'   Used by `"lai"` and `"perrier"`.
#' @param ndvi Numeric. Normalised difference vegetation index \[-\], in
#'   \[-1, 1\]. Used by `"ndvi"`.
#' @param albedo Numeric. Broadband surface albedo \[-\], in (0, 1\]. Used
#'   by `"ndvi"`.
#' @param coef_1,coef_2 Numeric. Coefficients \eqn{c_1}{c1} \[-\] and
#'   \eqn{c_2}{c2} \[-\] of the exponential relation, supplied by the user
#'   (no default exists). Must be finite. Used by `"ndvi"`.
#' @param f_lai Numeric. Fraction of the leaf area index located above half
#'   the canopy height \[-\], in \[0, 1\]. Used by `"perrier"`.
#' @param height Numeric. Canopy (vegetation) height \[m\]. Must be finite
#'   and `>= 0`. Used by `"perrier"` and `"height"`.
#' @param method Character. The formulation, with no default (the choice is
#'   a scientific decision; decision SH-01 is open). One of `"lai"`,
#'   `"ndvi"`, `"perrier"` or `"height"`. Matched exactly.
#'
#' @return The method functions return a numeric vector of momentum
#'   roughness length \eqn{z_{om}}{z_om} \[m\] with the common length of
#'   the inputs, keeping their `dim` if they are matrices or arrays. Zero
#'   values (e.g. `lai = 0` or `height = 0`) are returned unchanged: no
#'   minimum roughness is applied (see Details) and such values are rejected
#'   by [ef_ustar()].
#'
#'   `ef_zom()` returns a list of class `earthflux_roughness_length` with
#'   elements `zom` (identical to the method function), `method`, `flags`
#'   (one record per code that holds somewhere: `EF_INPUT_NA`, a required
#'   input is missing; no `EF_H_` code applies to \eqn{z_{om}}{z_om} while
#'   no minimum roughness or terrain factor is implemented) and `provenance`
#'   (method, method function, verification status, inputs used, flag codes
#'   evaluated in `flags_evaluated`, EarthFlux version).
#'
#' @details
#' `ef_zom_lai()` (`method = "lai"`):
#' \deqn{z_{om} = 0.018\,\mathrm{LAI}}{z_om = 0.018 * LAI}
#'
#' `ef_zom_ndvi()` (`method = "ndvi"`):
#' \deqn{z_{om} = \exp(c_1\,\mathrm{NDVI}/\alpha + c_2)}{z_om = exp(c1 *
#'   NDVI / albedo + c2)}
#'
#' `ef_zom_perrier()` (`method = "perrier"`):
#' \deqn{z_{om} = \left(1 - e^{-p\,\mathrm{LAI}/2}\right)
#'   e^{-p\,\mathrm{LAI}/2}\, h}{z_om = (1 - exp(-p * LAI / 2)) *
#'   exp(-p * LAI / 2) * h}
#' with \eqn{p = 1 / (2 (1 - f))}{p = 1 / (2 * (1 - f))} if
#' \eqn{f < 0.5}{f < 0.5} and \eqn{p = 2 f}{p = 2 * f} otherwise (both
#' branches give \eqn{p = 1}{p = 1} at \eqn{f = 0.5}{f = 0.5}), where
#' \eqn{f}{f} is `f_lai` and \eqn{h}{h} is `height`.
#'
#' `ef_zom_height()` (`method = "height"`):
#' \deqn{z_{om} = 0.123\,h}{z_om = 0.123 * h}
#' (FAO-56, chapter 2, box 4, which also gives the zero-plane displacement
#' \eqn{d = 2 h / 3}{d = 2 * h / 3}).
#'
#' Assumptions and limitations: the linear LAI relation is meant for short
#' crops; secondary sources report that it underestimates the roughness of
#' maize and that vines and trees need another function. With 1 km MODIS
#' pixels (mixed covers) the roughness of the mean LAI is not the mean
#' roughness of the covers. The Perrier function needs a canopy height map,
#' which MODIS does not provide.
#'
#' No minimum roughness (0.005 m in METRIC implementations, decision SH-02)
#' and no mountainous-terrain adjustment (SH-03) are applied: both are
#' unverified and values are never silently modified.
#'
#' Missing values propagate. Arguments must be numeric, of length 1 or a
#' common length (length 0 is rejected), and matrix or array arguments must
#' share their `dim`. Values outside the documented domain, or infinite
#' values, raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`). A missing or unknown `method` raises
#' `earthflux_missing_input` or `earthflux_unknown_method`; an argument
#' required by the chosen method but not supplied to the dispatcher raises
#' `earthflux_missing_input`. Arguments not used by the method are ignored.
#'
#' Verification status: `"lai"`, `"ndvi"` and `"perrier"` are `CANDIDATA`
#' (observed in the `water` package, which cites Allen et al., 2007, and
#' Santos et al., 2012, and Pocas et al., 2014, for Perrier; the primary
#' sources have not been consulted). `"height"` is `VERIFICADA` as FAO-56
#' content; its use in METRIC is not verified.
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
#' Santos, C., Lorite, I. J., Allen, R. G., & Tasumi, M. (2012). Aerodynamic
#' parameterization of the satellite-based energy balance (METRIC) model for
#' ET estimation in rainfed olive orchards of Andalusia, Spain. *Water
#' Resources Management*, 26(11), 3267-3283.
#' \doi{10.1007/s11269-012-0071-8}
#'
#' Pocas, I., Paco, T. A., Cunha, M., Andrade, J. A., Silvestre, J., Sousa,
#' A., Santos, F. L., Pereira, L. S., & Allen, R. G. (2014). Satellite-based
#' evapotranspiration of a super-intensive olive orchard: Application of
#' METRIC algorithms. *Biosystems Engineering*, 128, 69-81.
#' \doi{10.1016/j.biosystemseng.2014.06.019}
#'
#' @family aerodynamics and sensible heat functions
#' @export
#'
#' @examples
#' # Short crops: z_om = 0.018 * LAI (m)
#' ef_zom(lai = c(0.5, 2, 4), method = "lai")$zom
#' ef_zom_lai(c(0.5, 2, 4))
#'
#' # Exponential NDVI / albedo relation with user coefficients
#' ef_zom_ndvi(ndvi = 0.6, albedo = 0.2, coef_1 = 0.5, coef_2 = -5)
#'
#' # Perrier function for an orchard 3 m tall
#' ef_zom_perrier(lai = 2, f_lai = 0.6, height = 3)
#'
#' # FAO-56: clipped grass 0.12 m tall around a weather station
#' ef_zom_height(0.12)
ef_zom <- function(lai = NULL, ndvi = NULL, albedo = NULL, coef_1 = NULL,
                   coef_2 = NULL, f_lai = NULL, height = NULL, method) {
  call <- sys.call()
  check_method(method, c("lai", "ndvi", "perrier", "height"), call = call)
  args <- switch(
    method,
    lai = list(lai = lai),
    ndvi = list(ndvi = ndvi, albedo = albedo, coef_1 = coef_1,
                coef_2 = coef_2),
    perrier = list(lai = lai, f_lai = f_lai, height = height),
    height = list(height = height)
  )
  absent <- names(args)[vapply(args, is.null, logical(1))]
  if (length(absent) > 0L) {
    ef_abort(
      sprintf(
        "`method = \"%s\"` requires: %s.",
        method, paste0("`", absent, "`", collapse = ", ")
      ),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  zom <- switch(
    method,
    lai = ef_zom_lai(lai),
    ndvi = ef_zom_ndvi(ndvi, albedo, coef_1, coef_2),
    perrier = ef_zom_perrier(lai, f_lai, height),
    height = ef_zom_height(height)
  )
  flags <- ef_flags_combine(ef_input_na_flags(args, length(zom)))

  new_ef_object(
    list(
      zom = zom,
      method = method,
      flags = flags$flags,
      provenance = list(
        method = method,
        fun = paste0("ef_zom_", method),
        status = if (method == "height") {
          "VERIFICADA (FAO-56); CANDIDATA in METRIC"
        } else {
          "CANDIDATA"
        },
        inputs = names(args),
        flags_evaluated = flags$evaluated,
        earthflux_version = as.character(getNamespaceVersion("EarthFlux"))
      )
    ),
    "earthflux_roughness_length"
  )
}

#' @rdname ef_zom
#' @export
ef_zom_lai <- function(lai) {
  call <- sys.call()
  check_core_args(list(lai = lai), call)
  check_in_range(lai, "lai", lower = 0, call = call)
  # CANDIDATA: `water` v1.0 (method "short.crops"), citing Allen et al.
  # (2007), "Eq. 33" (not consulted).
  0.018 * lai
}

#' @rdname ef_zom
#' @export
ef_zom_ndvi <- function(ndvi, albedo, coef_1, coef_2) {
  call <- sys.call()
  check_core_args(
    list(ndvi = ndvi, albedo = albedo, coef_1 = coef_1, coef_2 = coef_2),
    call
  )
  check_in_range(ndvi, "ndvi", lower = -1, upper = 1, call = call)
  check_in_range(albedo, "albedo", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)
  check_in_range(coef_1, "coef_1", call = call)
  check_in_range(coef_2, "coef_2", call = call)
  # CANDIDATA: `water` v1.0 (method "custom"), citing Allen et al. (2007).
  exp(coef_1 * ndvi / albedo + coef_2)
}

#' @rdname ef_zom
#' @export
ef_zom_perrier <- function(lai, f_lai, height) {
  call <- sys.call()
  check_core_args(list(lai = lai, f_lai = f_lai, height = height), call)
  check_in_range(lai, "lai", lower = 0, call = call)
  check_in_range(f_lai, "f_lai", lower = 0, upper = 1, call = call)
  check_in_range(height, "height", lower = 0, call = call)
  # CANDIDATA: Perrier function as in Santos et al. (2012) and Pocas et al.
  # (2014), observed in `water` v1.0 (method "Perrier"). Branches combined
  # by mask (no ifelse), so that NA in f_lai propagates.
  p <- 2 * f_lai
  low <- !is.na(f_lai) & f_lai < 0.5
  p[low] <- 1 / (2 * (1 - f_lai[low]))
  e <- exp(-p * lai / 2)
  (1 - e) * e * height
}

#' @rdname ef_zom
#' @export
ef_zom_height <- function(height) {
  call <- sys.call()
  check_core_args(list(height = height), call)
  check_in_range(height, "height", lower = 0, call = call)
  # FAO-56, chapter 2, box 4 (normative coefficient kept as a literal).
  0.123 * height
}

# Wind and friction velocity -------------------------------------------------------

#' Wind speed at the blending height
#'
#' @description
#' Extrapolates the wind speed measured at a weather station to the
#' blending height \eqn{z_b}{z_b} with the neutral logarithmic wind profile
#' over the surface around the station. METRIC assumes that the wind at the
#' blending height is approximately uniform over the scene; a spatial wind
#' surface is also accepted (vectors per pixel).
#'
#' @param wind_speed Numeric. Wind speed measured at `height` \[m s-1\].
#'   Must be finite and `>= 0`.
#' @param height Numeric. Measurement height \eqn{z_x}{z_x} \[m\]. Must be
#'   finite and greater than `d_station + zom_station`.
#' @param zom_station Numeric. Momentum roughness length of the surface
#'   around the station \eqn{z_{om,w}}{z_om,w} \[m\]. Must be finite and
#'   `> 0`. No default: METRIC implementations use 0.015 m (clipped grass
#'   0.12 m tall), FAO-56 box 4 gives 0.123 h = 0.01476 m for the same grass
#'   (see [ef_zom_height()]); decision SH-04 is open.
#' @param d_station Numeric. Zero-plane displacement of the station surface
#'   \eqn{d_w}{d_w} \[m\]. Must be finite and `>= 0`. No default: METRIC
#'   implementations use 0, FAO-56 gives 2 h / 3 = 0.08 m for grass 0.12 m
#'   tall (SH-04).
#' @param blending_height Numeric. Blending height \eqn{z_b}{z_b} \[m\]. Must
#'   be finite and greater than `d_station + zom_station`. No default: the
#'   METRIC value of 200 m is `CANDIDATA`.
#'
#' @return A numeric vector of wind speed at the blending height
#'   \eqn{u_b}{u_b} \[m s-1\], with the common length of the inputs and
#'   keeping their `dim`.
#'
#' @details
#' \deqn{u_b = u_x \frac{\ln\left((z_b - d_w)/z_{om,w}\right)}
#'   {\ln\left((z_x - d_w)/z_{om,w}\right)}}{u_b = u_x * log((z_b - d_w) /
#'   z_om,w) / log((z_x - d_w) / z_om,w)}
#'
#' Assumptions: neutral stability over the station surface and a
#' logarithmic profile up to the blending height. No minimum wind speed is
#' imposed (decision SH-06): low wind is reported, not replaced. No
#' elevation adjustment of the wind is applied (SH-07, not verified).
#'
#' Missing values propagate. Infinite values and values outside the domain
#' raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`).
#'
#' Verification status: `CANDIDATA` (form observed in the `water` package,
#' which attributes it to Allen et al., 2007, "Eq. 32", with
#' \eqn{d_w = 0}{d_w = 0}). With \eqn{d_w}{d_w} and
#' \eqn{z_{om,w}}{z_om,w} from FAO-56 box 4, the normalised profile
#' coincides with FAO-56, chapter 3, Eq. 47 (author's calculation).
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
#' @family aerodynamics and sensible heat functions
#' @export
#'
#' @examples
#' # 3 m s-1 at 2 m over grass (z_om,w = 0.015 m, d_w = 0), z_b = 200 m
#' ef_blending_wind(3, height = 2, zom_station = 0.015, d_station = 0,
#'                  blending_height = 200)
#'
#' # Same grass with the FAO-56 displacement and roughness (h = 0.12 m)
#' ef_blending_wind(3, height = 2, zom_station = 0.01476, d_station = 0.08,
#'                  blending_height = 200)
ef_blending_wind <- function(wind_speed, height, zom_station, d_station,
                             blending_height) {
  call <- sys.call()
  check_core_args(
    list(wind_speed = wind_speed, height = height, zom_station = zom_station,
         d_station = d_station, blending_height = blending_height),
    call
  )
  check_in_range(wind_speed, "wind_speed", lower = 0, call = call)
  check_in_range(height, "height", call = call)
  check_in_range(zom_station, "zom_station", lower = 0,
                 lower_inclusive = FALSE, call = call)
  check_in_range(d_station, "d_station", lower = 0, call = call)
  check_in_range(blending_height, "blending_height", call = call)
  check_condition(
    height - d_station > zom_station,
    "`height - d_station` must exceed `zom_station` (positive logarithm)",
    call
  )
  check_condition(
    blending_height - d_station > zom_station,
    "`blending_height - d_station` must exceed `zom_station`",
    call
  )

  wind_speed * log((blending_height - d_station) / zom_station) /
    log((height - d_station) / zom_station)
}

#' Friction velocity
#'
#' @description
#' Computes the friction velocity \eqn{u_*}{u*} \[m s-1\] of each pixel from
#' the wind speed at the blending height and the momentum roughness length,
#' with an optional Monin-Obukhov stability correction for momentum at the
#' blending height (neutral when `psi_m = 0`).
#'
#' @param u_blend Numeric. Wind speed at the blending height \eqn{u_b}{u_b}
#'   \[m s-1\] (see [ef_blending_wind()]). Must be finite and `>= 0`.
#' @param zom Numeric. Momentum roughness length \eqn{z_{om}}{z_om} \[m\]
#'   (see [ef_zom()]). Must be finite, `> 0` and lower than
#'   `blending_height`.
#' @param blending_height Numeric. Blending height \eqn{z_b}{z_b} \[m\].
#'   Must be finite and `> 0`. No default: the METRIC value of 200 m is
#'   `CANDIDATA`.
#' @param psi_m Numeric. Stability correction for momentum at the blending
#'   height \eqn{\psi_m(z_b)}{psi_m(z_b)} \[-\]. Must be finite. The default
#'   0 is the neutral case.
#'
#' @return A numeric vector of friction velocity \eqn{u_*}{u*} \[m s-1\],
#'   with the common length of the inputs and keeping their `dim`. Where
#'   \eqn{\ln(z_b/z_{om}) - \psi_m \le 0}{log(z_b / z_om) - psi_m <= 0} (very
#'   unstable conditions over a rough surface) the friction velocity is not
#'   defined and `NA` is returned; the calibration of the sensible heat flux
#'   flags such pixels with `EF_H_USTAR_INVALID`. `u_blend = 0` gives
#'   \eqn{u_* = 0}{u* = 0}, which [ef_rah()] rejects.
#'
#' @details
#' \deqn{u_* = \frac{k\, u_b}{\ln(z_b / z_{om}) - \psi_m(z_b)}}{u* = k * u_b
#'   / (log(z_b / z_om) - psi_m(z_b))}
#' with the von Karman constant \eqn{k = 0.41}{k = 0.41} (FAO-56, chapter 2,
#' Eq. 4). The zero-plane displacement is not used for the pixel (heights
#' are taken above it), as in METRIC implementations.
#'
#' Missing values propagate. Infinite values and values outside the domain
#' raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`).
#'
#' Verification status: `CANDIDATA` (observed in the `water` package; the
#' value of \eqn{k}{k} is `VERIFICADA` as the FAO-56 value, its use in
#' METRIC is `CANDIDATA`).
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
#' # Neutral friction velocity of three pixels (z_b = 200 m)
#' ef_ustar(u_blend = 5.823611, zom = c(0.06, 0.005, 0.02),
#'          blending_height = 200)
#'
#' # With an unstable correction psi_m(z_b) = 4.18
#' ef_ustar(5.823611, zom = 0.005, blending_height = 200, psi_m = 4.178174)
ef_ustar <- function(u_blend, zom, blending_height, psi_m = 0) {
  call <- sys.call()
  check_core_args(
    list(u_blend = u_blend, zom = zom, blending_height = blending_height,
         psi_m = psi_m),
    call
  )
  check_in_range(u_blend, "u_blend", lower = 0, call = call)
  check_in_range(zom, "zom", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(blending_height, "blending_height", lower = 0,
                 lower_inclusive = FALSE, call = call)
  check_in_range(psi_m, "psi_m", call = call)
  check_condition(zom < blending_height,
                  "`zom` must be lower than `blending_height`", call)
  ustar_core(u_blend, log(blending_height / zom), psi_m)
}

#' Friction velocity without input checks
#'
#' @param u_blend Wind speed at the blending height \[m s-1\].
#' @param log_blend `log(blending_height / zom)` \[-\].
#' @param psi_m Stability correction for momentum \[-\].
#' @return Friction velocity \[m s-1\]; `NA` where the denominator is not
#'   positive.
#' @noRd
ustar_core <- function(u_blend, log_blend, psi_m) {
  denom <- log_blend - psi_m
  out <- EF_VON_KARMAN * u_blend / denom
  out[!is.na(denom) & denom <= 0] <- NA_real_
  out
}

#' Aerodynamic resistance to heat transport
#'
#' @description
#' Computes the aerodynamic resistance to heat transport \eqn{r_{ah}}{rah}
#' \[s m-1\] between two heights \eqn{z_1}{z1} and \eqn{z_2}{z2} above the
#' zero-plane displacement, from the friction velocity, with optional
#' Monin-Obukhov stability corrections for heat at both heights (neutral when
#' both are 0).
#'
#' @param u_star Numeric. Friction velocity \eqn{u_*}{u*} \[m s-1\] (see
#'   [ef_ustar()]). Must be finite and `> 0`.
#' @param z1,z2 Numeric. Lower and upper heights of the resistance
#'   \[m\]. Must be finite with `0 < z1 < z2`. No defaults: the METRIC
#'   values 0.1 m and 2 m are `CANDIDATA`.
#' @param psi_h_z2,psi_h_z1 Numeric. Stability corrections for heat at
#'   `z2` and `z1` \[-\]. Must be finite. The default 0 is the neutral case.
#'
#' @return A numeric vector of aerodynamic resistance \eqn{r_{ah}}{rah}
#'   \[s m-1\], with the common length of the inputs and keeping their
#'   `dim`. Non-positive results (not reachable with the stability functions
#'   of the calibration) are returned as `NA`.
#'
#' @details
#' \deqn{r_{ah} = \frac{\ln(z_2/z_1) - \psi_h(z_2) + \psi_h(z_1)}
#'   {k\, u_*}}{rah = (log(z2 / z1) - psi_h(z2) + psi_h(z1)) / (k * u*)}
#' with \eqn{k = 0.41}{k = 0.41}. In the neutral case
#' \eqn{r_{ah} = \ln(z_2/z_1)/(k u_*)}{rah = log(z2 / z1) / (k * u*)}. This is
#' not the FAO-56 resistance of chapter 2, Eq. 4: METRIC uses fixed heights
#' \eqn{z_1}{z1} and \eqn{z_2}{z2} instead of the roughness length for heat,
#' and takes the roughness into account through \eqn{u_*}{u*}.
#'
#' Missing values propagate. Infinite values and values outside the domain
#' raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`).
#'
#' Verification status: `CANDIDATA` (observed in the `water` package and in
#' `dev/SCIENTIFIC_SPEC.md` section 3; primary source not consulted).
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
#' # Neutral resistance between 0.1 m and 2 m
#' ef_rah(u_star = c(0.294349, 0.225324), z1 = 0.1, z2 = 2)
#'
#' # Unstable corrections at both heights
#' ef_rah(0.372002, z1 = 0.1, z2 = 2, psi_h_z2 = 1.719595,
#'        psi_h_z1 = 0.263944)
ef_rah <- function(u_star, z1, z2, psi_h_z2 = 0, psi_h_z1 = 0) {
  call <- sys.call()
  check_core_args(
    list(u_star = u_star, z1 = z1, z2 = z2, psi_h_z2 = psi_h_z2,
         psi_h_z1 = psi_h_z1),
    call
  )
  check_in_range(u_star, "u_star", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_in_range(z1, "z1", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(z2, "z2", call = call)
  check_in_range(psi_h_z2, "psi_h_z2", call = call)
  check_in_range(psi_h_z1, "psi_h_z1", call = call)
  check_condition(z2 > z1, "`z2` must be greater than `z1`", call)
  rah_core(u_star, log(z2 / z1), psi_h_z2, psi_h_z1)
}

#' Aerodynamic resistance without input checks
#'
#' @param u_star Friction velocity \[m s-1\].
#' @param log_z `log(z2 / z1)` \[-\].
#' @param psi_h_z2,psi_h_z1 Stability corrections for heat \[-\].
#' @return Aerodynamic resistance \[s m-1\]; `NA` where it is not positive
#'   and finite.
#' @noRd
rah_core <- function(u_star, log_z, psi_h_z2, psi_h_z1) {
  out <- (log_z - psi_h_z2 + psi_h_z1) / (EF_VON_KARMAN * u_star)
  out[!is.na(out) & (!is.finite(out) | out <= 0)] <- NA_real_
  out
}

# Monin-Obukhov stability (internal, decision SH-17) --------------------------------

#' Monin-Obukhov length
#'
#' \deqn{L = -\rho c_p u_*^3 T / (k g H)}
#'
#' Status: `CANDIDATA` (observed in `water`, `rahStep()`; `bigleaf` uses the
#' air temperature). EarthFlux uses the near-surface air temperature
#' \eqn{T_a = T_s - dT} and the air density of the iteration (decision
#' SH-10, provisional); \eqn{g}{g} = `EF_GRAVITY` (`CANDIDATA`).
#'
#' `H = 0` (neutral) is treated explicitly: \eqn{L = +\infty}, without
#' dividing by zero; the stability functions then return 0.
#'
#' @param air_density Air density \[kg m-3\].
#' @param u_star Friction velocity \[m s-1\].
#' @param air_temperature Air temperature \[K\].
#' @param h Sensible heat flux \[W m-2\].
#' @param cp Specific heat of air \[J kg-1 K-1\].
#' @return Monin-Obukhov length \[m\]: negative when unstable (`h > 0`),
#'   positive when stable (`h < 0`), `Inf` when neutral (`h == 0`).
#' @noRd
ef_monin_obukhov_length <- function(air_density, u_star, air_temperature, h,
                                    cp) {
  out <- -air_density * cp * u_star^3 * air_temperature /
    (EF_VON_KARMAN * EF_GRAVITY * h)
  out[!is.na(h) & h == 0] <- Inf
  out
}

#' Stability correction for momentum
#'
#' Unstable (\eqn{z/L < 0}), Paulson-type integrated form:
#' \eqn{x = (1 - 16 z/L)^{1/4}},
#' \eqn{\psi_m = 2 \ln((1 + x)/2) + \ln((1 + x^2)/2) - 2 \arctan(x) + \pi/2}.
#' Stable (\eqn{z/L > 0}), Webb-type log-linear form:
#' \eqn{\psi_m = -5 z/L}. Neutral (\eqn{z/L = 0}, including \eqn{L = \infty}):
#' 0.
#'
#' The height at which the caller evaluates the stable branch for the
#' blending height is the open decision SH-11 (`stable_psi_m_height` of
#' `ef_h_control()`); this function evaluates whatever `z` it receives.
#'
#' Status: `CANDIDATA` (`water`, `rahStep()`; corroborated by `bigleaf`;
#' Paulson, 1970, and Webb, 1970, not consulted).
#'
#' @param z Height \[m\].
#' @param obukhov_length Monin-Obukhov length \[m\].
#' @return \eqn{\psi_m} \[-\].
#' @noRd
ef_psi_m <- function(z, obukhov_length) {
  zeta <- z / obukhov_length
  out <- zeta * 0
  unstable <- !is.na(zeta) & zeta < 0
  stable <- !is.na(zeta) & zeta > 0
  x <- (1 - 16 * zeta[unstable])^0.25
  out[unstable] <- 2 * log((1 + x) / 2) + log((1 + x^2) / 2) -
    2 * atan(x) + pi / 2
  out[stable] <- -5 * zeta[stable]
  out
}

#' Stability correction for heat
#'
#' Unstable: \eqn{\psi_h = 2 \ln((1 + x^2)/2)} with
#' \eqn{x = (1 - 16 z/L)^{1/4}}; stable: \eqn{\psi_h = -5 z/L}; neutral: 0.
#' Status: `CANDIDATA` (as `ef_psi_m()`).
#'
#' @inheritParams ef_psi_m
#' @return \eqn{\psi_h} \[-\].
#' @noRd
ef_psi_h <- function(z, obukhov_length) {
  zeta <- z / obukhov_length
  out <- zeta * 0
  unstable <- !is.na(zeta) & zeta < 0
  stable <- !is.na(zeta) & zeta > 0
  x2 <- sqrt(1 - 16 * zeta[unstable])
  out[unstable] <- 2 * log((1 + x2) / 2)
  out[stable] <- -5 * zeta[stable]
  out
}
