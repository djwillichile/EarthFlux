# METRIC: instantaneous ET, ETrF and daily ETa -----------------------------------
#
# Purpose: conversion of LE to instantaneous ET, reference ET fraction
#   (ETrF = ETinst / ETr_inst) and extrapolation to daily ETa
#   (ETa = ETrF * ETr_24), with explicit reference-crop definition.
#
# Specification: dev/specs/evapotranspiration.md (sections 5, 6, 7, 9-11).
#
# Implemented:
#   - ef_et_inst(): LE [W m-2] -> instantaneous ET [mm h-1] with lambda from
#     ef_lambda() (R/shared-physics.R) and rho_w = EF_WATER_DENSITY.
#     VERIFICADA as a unit conversion (FAO-56, chapter 3, box 8, plus
#     3600 s h-1); the METRIC notation 3600 * LE / (lambda * rho_w) is
#     CANDIDATA (corroborated) and lacks the factor 1000 mm m-1 (item V3,
#     section 5.2). The dimensionally explicit form of section 5.1 is used.
#   - ef_et_inst_to_latent_heat() (internal): exact inverse of ef_et_inst(),
#     for tests and for the cold anchor boundary condition.
#   - ef_etrf(): reference ET fraction. CANDIDATA (corroborated; items V4,
#     V5).
#   - ef_et_daily(): dispatcher of the daily ET family (rule N6 of
#     dev/NAMING.md); only method "etrf" is implemented.
#   - ef_et_daily_etrf(): ETa_24 = ETrF * ETr_24. CANDIDATA (corroborated;
#     item V6). No slope correction C_rad (decision ET-D7, open).
#   - ef_diagnose_et() (internal): cell-scope flags of the stage
#     (EF_ET_NEGATIVE on each ET output layer).
#
# Not implemented (future, optional): ef_et_daily_evapfrac() (decision
#   ET-D8, specification pending) and ef_et_period() (section 8, CANDIDATA).
#
# Reference crop (section 6.4): ef_etrf() and ef_et_daily_etrf() take the
#   reference type ("alfalfa" or "grass") as a required argument without
#   default. It does not change the arithmetic; the consistency check
#   between etr_inst, etr_24 and the cold anchor belongs to the
#   orchestration layer (decision ET-D9, earthflux_reference_mismatch).
#
# Conventions: those of ef_net_radiation() (dev/ARCHITECTURE.md section 3.1).

# Unit conversion factors (EF_SECONDS_PER_HOUR, EF_MM_PER_M) are defined in
# R/constants.R.

# Reference crop types accepted by ef_etrf() and ef_et_daily_etrf(); names as
# in dev/specs/weather-forcing.md section 5 (`reference`).
ef_et_reference_types <- function() {
  c("alfalfa", "grass")
}

#' Check the reference crop type of a reference ET argument
#'
#' The reference type must be given explicitly (no default;
#' dev/specs/evapotranspiration.md section 6.4). Shared by the ET functions
#' and the anchor boundary conditions (`ef_anchor_conditions()`), so that
#' both report a missing or unknown reference with the same classes as a
#' `method` (`check_method()`).
#'
#' @param reference The value to check, or `NULL` when it was not supplied.
#' @param call The call to report in the error.
#' @return `reference`, invisibly, if the check passes. Errors of class
#'   `earthflux_missing_input` (missing or `NULL`), `earthflux_input_error`
#'   (not a single string) or `earthflux_unknown_method` (not one of
#'   `ef_et_reference_types()`), all also `earthflux_input_error`.
#' @noRd
check_reference_type <- function(reference, call = sys.call(-1)) {
  check_method(reference, ef_et_reference_types(), arg = "reference",
               call = call)
}

#' Instantaneous evapotranspiration from the latent heat flux
#'
#' @description
#' Converts the instantaneous latent heat flux \eqn{LE}{LE} into the
#' instantaneous evapotranspiration rate \eqn{ET_{inst}}{ET_inst}, expressed
#' as a depth of water per hour. The result is a rate evaluated at the
#' satellite overpass time, not a depth accumulated over an hour.
#'
#' @param le Numeric. Instantaneous latent heat flux \eqn{LE}{LE}
#'   \[W m-2\], for example from [ef_latent_heat()]. Any finite value;
#'   negative values are allowed and kept.
#' @param lambda Numeric. Latent heat of vaporization \eqn{\lambda}{lambda}
#'   \[J kg-1\], from [ef_lambda()]. Must lie in \[1e6, 1e7\] J kg-1 (unit
#'   guard, see Details). The same `lambda` (same `method` of [ef_lambda()])
#'   must be used for the cold anchor boundary condition.
#'
#' @return A numeric vector of instantaneous evapotranspiration
#'   \eqn{ET_{inst}}{ET_inst} \[mm h-1\] with the common length of the
#'   inputs. If the inputs include matrices or arrays (all with the same
#'   `dim`), the result keeps that `dim`. Negative values (negative `le`) are
#'   returned unchanged.
#'
#' @details
#' A depth of water equals the energy per unit area divided by
#' \eqn{\lambda \rho_w}{lambda * rho_w} (FAO-56, chapter 3, box 8). For a
#' flux \eqn{LE}{LE} in W m-2 = J s-1 m-2, the energy accumulated at that
#' rate during one hour is \eqn{3600 LE}{3600 * LE}, so
#' \deqn{ET_{inst} = \frac{1000 \cdot 3600 \cdot LE}{\lambda \rho_w}}{ET_inst
#'   = 1000 * 3600 * LE / (lambda * rho_w)}
#' where 1000 is mm m-1, 3600 is s h-1, \eqn{\lambda}{lambda} is `lambda`
#' \[J kg-1\] and \eqn{\rho_w}{rho_w} = 1000 kg m-3 is the density of water
#' (FAO-56, chapter 3, box 8; internal constant, not an argument). With
#' \eqn{\rho_w}{rho_w} = 1000 kg m-3 this is numerically
#' \eqn{3600 LE / \lambda}{3600 * LE / lambda}.
#'
#' The notation \eqn{3600 LE / (\lambda \rho_w)}{3600 * LE / (lambda *
#' rho_w)} attributed to METRIC by secondary sources gives m h-1, not
#' mm h-1, with \eqn{\lambda}{lambda} in J kg-1; the factor 1000 mm m-1 is
#' written explicitly here. How the primary reference resolves that factor
#' is pending verification.
#'
#' Unit guard: a `lambda` given in MJ kg-1 (about 2.45) instead of J kg-1
#' would silently give an evapotranspiration 1e6 times too large. Values of
#' `lambda` outside \[1e6, 1e7\] J kg-1 therefore raise an error of class
#' `earthflux_domain_error`. The interval is a control of units, not a
#' physical range.
#'
#' A negative `le` gives a negative evapotranspiration (condensation or an
#' energy balance in which \eqn{H > R_n - G}{H > Rn - G}); it is returned
#' unchanged and without a warning, never set to zero. The diagnostic flag
#' `EF_ET_NEGATIVE` is assembled by the orchestration layer.
#'
#' Missing values (`NA`, `NaN`) in any input propagate to the corresponding
#' output element, without errors or warnings. Arguments must be numeric
#' (double or integer) and have length 1 or a common length; length-1
#' arguments are recycled, arrays with a `dim` are not. Infinite values
#' raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`).
#'
#' Verification status: `VERIFICADA` as a unit conversion (FAO-56, chapter
#' 3, box 8 and Eq. 20, plus 3600 s h-1); checked against the FAO-56
#' equivalences 1 mm d-1 = 2.45 MJ m-2 d-1 (chapter 1, table 1) and
#' 1 W m-2 = 0.035 mm d-1 (chapter 3, table 3). Its notation in Allen et al.
#' (2007) is `CANDIDATA` (corroborated by secondary sources).
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
#' @family latent heat and evapotranspiration functions
#' @export
#'
#' @examples
#' # 490 W m-2 with the FAO-56 constant lambda: 0.72 mm h-1
#' ef_et_inst(le = 490, lambda = ef_lambda(method = "constant"))
#'
#' # Temperature-dependent lambda (air temperature in K)
#' ef_et_inst(le = 490, lambda = ef_lambda(303.15, method = "fao56"))
#'
#' # Negative LE is kept: -0.072 mm h-1
#' ef_et_inst(le = c(490, -49, NA), lambda = 2.45e6)
ef_et_inst <- function(le, lambda) {
  call <- sys.call()
  args <- list(le = le, lambda = lambda)

  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)

  check_in_range(le, "le", call = call)
  # Unit guard for lambda (decision ET-D2); also rejects infinite values.
  check_latent_heat_units(lambda, "lambda", call = call)

  EF_MM_PER_M * EF_SECONDS_PER_HOUR * le / (lambda * EF_WATER_DENSITY)
}

#' Latent heat flux from the instantaneous evapotranspiration
#'
#' Exact inverse of `ef_et_inst()` (dev/specs/evapotranspiration.md section
#' 9.1): \eqn{LE = ET_{inst} \lambda \rho_w / (1000 \cdot 3600)}. Used by
#' the round-trip tests and by `ef_anchor_conditions()`, which turns the
#' target evapotranspiration of the anchors into a target latent heat flux
#' with the same `lambda` as the conversion (section 11.4): the package has
#' a single LE <-> ET conversion.
#'
#' @param et_inst Numeric. Instantaneous evapotranspiration \[mm h-1\]. Any
#'   finite value.
#' @inheritParams ef_et_inst
#' @return Latent heat flux \[W m-2\], with the conventions of
#'   `ef_et_inst()`.
#' @noRd
ef_et_inst_to_latent_heat <- function(et_inst, lambda) {
  call <- sys.call()
  args <- list(et_inst = et_inst, lambda = lambda)

  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)

  check_in_range(et_inst, "et_inst", call = call)
  check_latent_heat_units(lambda, "lambda", call = call)

  et_inst * lambda * EF_WATER_DENSITY / (EF_MM_PER_M * EF_SECONDS_PER_HOUR)
}

#' Reference evapotranspiration fraction
#'
#' @description
#' Computes the reference evapotranspiration fraction \eqn{ETrF}{ETrF} at
#' the satellite overpass time: the ratio of the instantaneous actual
#' evapotranspiration to the reference evapotranspiration at the same
#' instant. In METRIC this fraction is assumed constant during the day and
#' is used to extrapolate the instantaneous estimate to a daily value (see
#' [ef_et_daily()]).
#'
#' @param et_inst Numeric. Instantaneous evapotranspiration
#'   \eqn{ET_{inst}}{ET_inst} \[mm h-1\], for example from [ef_et_inst()].
#'   Any finite value; negative values are allowed and kept.
#' @param etr_inst Numeric. Reference evapotranspiration at the same instant
#'   (the overpass time of each pixel) \[mm h-1\]. Must be finite and `> 0`.
#' @param reference Character. The reference crop of `etr_inst`, with no
#'   default: `"alfalfa"` (tall reference, ETr) or `"grass"` (short
#'   reference, ETo). An ETrF is defined only with respect to one reference;
#'   see Details.
#'
#' @return A numeric vector of the reference evapotranspiration fraction
#'   \eqn{ETrF}{ETrF} \[-\] with the common length of the inputs. If the
#'   inputs include matrices or arrays (all with the same `dim`), the result
#'   keeps that `dim`. Values are returned unchanged, whatever their sign or
#'   magnitude.
#'
#' @details
#' The fraction is
#' \deqn{ETrF = \frac{ET_{inst}}{ETr_{inst}}}{ETrF = ET_inst / ETr_inst}
#' where \eqn{ET_{inst}}{ET_inst} is `et_inst` and
#' \eqn{ETr_{inst}}{ETr_inst} is `etr_inst`, both in mm h-1 at the same
#' instant.
#'
#' Reference crop: an ETrF based on alfalfa is not comparable with one based
#' on grass. `etr_inst`, the daily reference evapotranspiration used by
#' [ef_et_daily()] and the boundary condition of the cold anchor pixel must
#' all refer to the same reference crop; otherwise the daily estimate is
#' wrong without any arithmetic error. `reference` does not change the
#' computation: it makes the choice explicit. The consistency check between
#' the steps is made by the orchestration layer.
#'
#' The temporal basis of `etr_inst` (instantaneous rate or hourly reference
#' ET of a period centred on the overpass time) is defined by the
#' meteorological forcing and must be recorded in the provenance.
#'
#' Negative values of `et_inst` give a negative ETrF, returned unchanged and
#' without a warning. No plausible range of ETrF is checked or flagged: the
#' upper limit has no verified reference yet. Values are never truncated.
#'
#' Missing values (`NA`, `NaN`) in any input propagate to the corresponding
#' output element, without errors or warnings. Arguments must be numeric
#' (double or integer) and have length 1 or a common length; length-1
#' arguments are recycled, arrays with a `dim` are not. A non-positive
#' `etr_inst` (it would give an infinite or meaningless fraction) or any
#' infinite value raises an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`). A missing `reference` raises
#' `earthflux_missing_input`; an unknown one, `earthflux_input_error`.
#'
#' Verification status: `CANDIDATA` (corroborated by secondary sources,
#' Olmedo et al., 2016, Eq. 4). It is implemented as an operational
#' definition; its form and equation number in Allen et al. (2007) have not
#' been verified.
#'
#' @references
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
#' @family latent heat and evapotranspiration functions
#' @export
#'
#' @examples
#' # 0.72 mm h-1 against an alfalfa reference of 0.80 mm h-1: 0.9
#' ef_etrf(et_inst = 0.72, etr_inst = 0.80, reference = "alfalfa")
#'
#' # Negative and high fractions are returned unchanged
#' ef_etrf(et_inst = c(-0.072, 0.9), etr_inst = c(0.80, 0.75),
#'         reference = "alfalfa")
ef_etrf <- function(et_inst, etr_inst, reference) {
  call <- sys.call()
  check_reference_type(if (missing(reference)) NULL else reference,
                       call = call)
  args <- list(et_inst = et_inst, etr_inst = etr_inst)

  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)

  check_in_range(et_inst, "et_inst", call = call)
  # Decision ET-D6: at the daytime overpass the reference ET must be > 0.
  check_in_range(etr_inst, "etr_inst", lower = 0, lower_inclusive = FALSE,
                 call = call)

  et_inst / etr_inst
}

#' Daily actual evapotranspiration
#'
#' @description
#' Extrapolates the instantaneous estimate at the satellite overpass time to
#' the daily actual evapotranspiration \eqn{ETa_{24}}{ETa_24} of the image
#' day.
#'
#' `ef_et_daily()` is the dispatcher of the family: it checks `method` and
#' forwards the arguments to the function of that method, without any
#' computation of its own. The methods are:
#'
#' * `"etrf"`: `ef_et_daily_etrf()`, the reference evapotranspiration
#'   fraction (ETrF) of the overpass time multiplied by the daily reference
#'   evapotranspiration (METRIC).
#'
#' Only `"etrf"` is implemented. The extrapolation by the evaporative
#' fraction (a future `ef_et_daily_evapfrac()`) and the accumulation over a
#' period between images (a future `ef_et_period()`) are not available yet:
#' they need their own specification and verification.
#'
#' @param etrf Numeric. Reference evapotranspiration fraction
#'   \eqn{ETrF}{ETrF} at the overpass time \[-\], from [ef_etrf()]. Any
#'   finite value; negative values are allowed and kept.
#' @param etr_24 Numeric. Reference evapotranspiration accumulated over the
#'   image day \eqn{ETr_{24}}{ETr_24} \[mm d-1\]. Must be finite and `>= 0`.
#' @param reference Character. The reference crop of `etr_24`, with no
#'   default: `"alfalfa"` (tall reference, ETr) or `"grass"` (short
#'   reference, ETo). It must be the reference used to compute `etrf`.
#' @param method Character. The extrapolation method, with no default (the
#'   choice is a scientific decision that must be explicit). Currently only
#'   `"etrf"`.
#'
#' @return A numeric vector of daily actual evapotranspiration
#'   \eqn{ETa_{24}}{ETa_24} \[mm d-1\] with the common length of the inputs.
#'   If the inputs include matrices or arrays (all with the same `dim`), the
#'   result keeps that `dim`. Negative values are returned unchanged.
#'   `ef_et_daily()` returns exactly the value of the method function.
#'
#' @details
#' Method `"etrf"` computes
#' \deqn{ETa_{24} = ETrF \cdot ETr_{24}}{ETa_24 = ETrF * ETr_24}
#' where \eqn{ETrF}{ETrF} is `etrf` and \eqn{ETr_{24}}{ETr_24} is `etr_24`,
#' the cumulative reference evapotranspiration of the image day.
#'
#' Assumption: the fraction \eqn{ETrF}{ETrF} at the overpass time is
#' constant during the whole day, i.e. the actual evapotranspiration changes
#' in proportion to the reference evapotranspiration. The assumption is
#' weakened by the diurnal variation of the ratio (stomatal closure, drying
#' of the soil surface after irrigation, increasing water stress), by the
#' overpass time, by clouds after the overpass, by the night hours included
#' in \eqn{ETr_{24}}{ETr_24}, by terrain (no slope correction is applied)
#' and by mixed pixels at about 1 km. A common multiplicative bias of the
#' instantaneous and daily reference evapotranspiration cancels: the result
#' depends on the ratio \eqn{ETr_{24} / ETr_{inst}}{ETr_24 / ETr_inst}.
#'
#' Reference crop: `etrf` and `etr_24` must refer to the same reference crop
#' (and to the same one as the cold anchor pixel). `reference` does not
#' change the computation: it makes the choice explicit. The consistency
#' check between the steps is made by the orchestration layer.
#'
#' Slope correction: the correction of the daily energy availability in
#' sloping terrain used by some METRIC implementations is not applied; its
#' form and source are pending verification.
#'
#' Negative values of `etrf` give a negative daily evapotranspiration,
#' returned unchanged and without a warning (never set to zero). With
#' `etr_24 = 0` the result is zero whatever the sign of `etrf`. The
#' diagnostic flag `EF_ET_NEGATIVE` is assembled by the orchestration layer
#' on this layer.
#'
#' Missing values (`NA`, `NaN`) in any input propagate to the corresponding
#' output element, without errors or warnings. Arguments must be numeric
#' (double or integer) and have length 1 or a common length; length-1
#' arguments are recycled, arrays with a `dim` are not. A negative `etr_24`
#' or any infinite value raises an error of class `earthflux_domain_error`
#' (also `earthflux_input_error`). A missing `method`, `reference` or
#' method argument raises `earthflux_missing_input`; an unknown `method`,
#' `earthflux_unknown_method`; an unknown `reference`,
#' `earthflux_input_error`.
#'
#' Verification status: method `"etrf"` is `CANDIDATA` (corroborated by
#' secondary sources, Olmedo et al., 2016, Eq. 4). It is implemented as an
#' operational definition; its form and equation number in Allen et al.
#' (2007) have not been verified.
#'
#' @references
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
#' @family latent heat and evapotranspiration functions
#' @export
#'
#' @examples
#' # ETrF 0.9 and 8 mm d-1 of alfalfa reference ET: 7.2 mm d-1
#' ef_et_daily(etrf = 0.9, etr_24 = 8, reference = "alfalfa",
#'             method = "etrf")
#'
#' # Same result calling the method directly
#' ef_et_daily_etrf(etrf = 0.9, etr_24 = 8, reference = "alfalfa")
#'
#' # Full chain from the energy balance (one pixel)
#' lambda <- ef_lambda(method = "constant")
#' le <- ef_latent_heat(rn = 600, g = 60, h = 50)
#' et_inst <- ef_et_inst(le, lambda)
#' etrf <- ef_etrf(et_inst, etr_inst = 0.80, reference = "alfalfa")
#' ef_et_daily(etrf, etr_24 = 8, reference = "alfalfa", method = "etrf")
ef_et_daily <- function(etrf, etr_24, reference, method) {
  call <- sys.call()
  check_method(if (missing(method)) NULL else method, "etrf", call = call)

  # Arguments required by each method (a missing one is reported here with
  # a classed condition, instead of a base R error inside the method).
  required <- list(etrf = c("etrf", "etr_24", "reference"))[[method]]
  supplied <- c(etrf = !missing(etrf), etr_24 = !missing(etr_24),
                reference = !missing(reference))
  absent <- required[!supplied[required]]
  if (length(absent) > 0L) {
    ef_abort(
      sprintf(
        "Method \"%s\" requires %s.",
        method, paste0("`", absent, "`", collapse = ", ")
      ),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }

  switch(
    method,
    etrf = ef_et_daily_etrf(etrf = etrf, etr_24 = etr_24,
                            reference = reference)
  )
}

#' @rdname ef_et_daily
#' @export
ef_et_daily_etrf <- function(etrf, etr_24, reference) {
  call <- sys.call()
  check_reference_type(if (missing(reference)) NULL else reference,
                       call = call)
  args <- list(etrf = etrf, etr_24 = etr_24)

  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)

  check_in_range(etrf, "etrf", call = call)
  # Decision ET-D6: daily reference ET must be >= 0.
  check_in_range(etr_24, "etr_24", lower = 0, call = call)

  etrf * etr_24
}

# Diagnostics of this stage -------------------------------------------------------

#' Cell-scope diagnostic flags of the latent heat and ET stage
#'
#' Builds the `earthflux_flag` records of the stage from the numeric output
#' layers (dev/ARCHITECTURE.md section 3.2). `EF_ET_NEGATIVE` is evaluated
#' separately on each layer supplied (dev/specs/flags.md section 4.2:
#' with `etr_24 = 0`, ET_inst and ETa_24 may differ), with masks
#' `!is.na(x) & x < 0`. Values are never modified. `LE < 0` needs no
#' separate evaluation: it is equivalent to `ET_inst < 0` (flags.md C1).
#' ETrF is not evaluated (no verified plausible range, decision ET-D5;
#' `EF_ET_ETRF_IMPLAUSIBLE` is class II).
#'
#' @param et_inst Numeric or `NULL`. Instantaneous ET \[mm h-1\], output of
#'   `ef_et_inst()`. `NULL` if not evaluated.
#' @param eta_24 Numeric or `NULL`. Daily actual ET \[mm d-1\], output of
#'   `ef_et_daily()`. `NULL` if not evaluated.
#' @return A named list (possibly empty) of `earthflux_flag` records, one
#'   per layer with at least one flagged element (the convention of every
#'   stage, R/diagnostics.R); the name of each element is the layer
#'   (`"et_inst"`, `"eta_24"`) to which its `index` refers. The attribute
#'   `evaluated` is `"EF_ET_NEGATIVE"` when at least one layer is given.
#' @noRd
ef_diagnose_et <- function(et_inst = NULL, eta_24 = NULL) {
  call <- sys.call()
  layers <- list(et_inst = et_inst, eta_24 = eta_24)
  layers <- layers[!vapply(layers, is.null, logical(1))]

  flags <- list()
  for (nm in names(layers)) {
    x <- layers[[nm]]
    check_numeric(x, nm, call = call)
    flag <- ef_flag_set(list(EF_ET_NEGATIVE = !is.na(x) & x < 0))
    if (length(flag) > 0L) {
      flags[[nm]] <- flag[[1L]]
    }
  }
  attr(flags, "evaluated") <- if (length(layers) > 0L) {
    "EF_ET_NEGATIVE"
  } else {
    character(0)
  }
  flags
}

# Diagnostic flags of this stage -------------------------------------------------

#' Flag codes owned by the latent heat and evapotranspiration stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_ET_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7).
#'
#' `EF_ET_NEGATIVE` is raised by `ef_diagnose_et()`. The class II code
#' `EF_ET_ETRF_IMPLAUSIBLE` is not registered (no verified threshold).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_et <- function() {
  ef_flag_rows(
    code = "EF_ET_NEGATIVE",
    stage = "ET",
    severity = "warning",
    scope = "cell",
    bit = 1L,
    error_class = NA_character_,
    description = paste(
      "Estimated evapotranspiration is negative;",
      "the value is reported unchanged."
    ),
    spec = "dev/specs/evapotranspiration.md 7.1",
    since = "0.0.0.9000"
  )
}
