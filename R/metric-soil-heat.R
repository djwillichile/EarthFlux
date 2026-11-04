# METRIC: soil heat flux (G) ---------------------------------------------------------
#
# Purpose: instantaneous soil heat flux at the satellite overpass from net
#   radiation and surface variables, with an explicit empirical method.
#
# Specification: dev/specs/soil-heat-flux.md (API option C, section 5.2;
#   decisions G-5.2, G-D3, G-D6 and G-D9 of dev/DECISIONS.md).
#
# Implemented:
#   - ef_g_bastiaanssen(): G/Rn as a function of Ts, albedo and NDVI (SEBAL).
#     Status: CANDIDATA (form and coefficients observed in a secondary
#     implementation; the primary reference was not consulted).
#   - ef_g_tasumi(): G/Rn as a function of LAI, with a bare-soil branch for
#     LAI < 0.5 that depends on Ts and Rn. Status: CANDIDATA (idem).
#   - ef_g(): thin dispatcher (method without default) that calls one of the
#     above, derives G/Rn, builds the cell flags with ef_diagnose_soil_heat()
#     and records the provenance.
#
# Not implemented (TODO in the specification): rules for water, snow and
#   impervious surfaces (decision G-D4), plausible range of G/Rn (G-D7).
#
# Design: sensor-independent, purely arithmetic and vectorised. Temperatures
#   are in K and converted to degrees Celsius inside the equations with
#   EF_KELVIN_OFFSET. Values of G are never truncated or replaced
#   (principle 6 of dev/ARCHITECTURE.md); anomalies are reported as flags.

# Coefficients of the candidate formulations -------------------------------------
#
# The empirical coefficients are literals of the equation they belong to
# (dev/DECISIONS.md, WF-14), kept in one place so that the method function
# and the provenance of the dispatcher use the same values. All of them are
# CANDIDATA (dev/specs/soil-heat-flux.md section 3).

#' Coefficients of the Bastiaanssen (SEBAL) G/Rn relation
#'
#' @return A named list: `c_t` and `c_albedo` \[degC-1\], `c_ndvi` \[-\] and
#'   the NDVI exponent `ndvi_exponent` (dev/specs/soil-heat-flux.md
#'   section 3.1; status CANDIDATA).
#' @noRd
ef_g_bastiaanssen_coefficients <- function() {
  list(c_t = 0.0038, c_albedo = 0.0074, c_ndvi = 0.98, ndvi_exponent = 4)
}

#' Coefficients of the Tasumi (METRIC) G relation
#'
#' @return A named list: `lai_threshold` \[m2 m-2\] (bare-soil branch for
#'   `lai < lai_threshold`), vegetated branch `veg_a` and `veg_b` \[-\] and
#'   `veg_k` \[(m2 m-2)-1\], bare-soil branch `bare_t` \[W m-2 degC-1\] and
#'   `bare_rn` \[-\] (dev/specs/soil-heat-flux.md section 3.2; status
#'   CANDIDATA).
#' @noRd
ef_g_tasumi_coefficients <- function() {
  list(
    lai_threshold = 0.5,
    veg_a = 0.05, veg_b = 0.18, veg_k = 0.521,
    bare_t = 1.80, bare_rn = 0.084
  )
}

#' Soil heat flux
#'
#' @description
#' Estimates the instantaneous soil heat flux \eqn{G}{G} at the satellite
#' overpass, i.e. the part of the net radiation \eqn{R_n}{Rn} conducted into
#' the ground, with an empirical relation between the ratio
#' \eqn{G/R_n}{G/Rn} and surface variables. \eqn{G}{G} is the second term of
#' the METRIC surface energy balance
#' \eqn{LE = R_n - G - H}{LE = Rn - G - H}.
#'
#' * `ef_g()` is the dispatcher: it calls the method chosen with `method`
#'   (no default), derives \eqn{G/R_n}{G/Rn}, builds the diagnostic flags
#'   and records the provenance.
#' * `ef_g_bastiaanssen()` evaluates the SEBAL relation of Bastiaanssen
#'   (2000) as a function of surface temperature, albedo and NDVI.
#' * `ef_g_tasumi()` evaluates the relation attributed to Tasumi (2003) and
#'   used in METRIC as a function of LAI, with a bare-soil branch for
#'   LAI < 0.5.
#'
#' The method functions are purely arithmetic and return \eqn{G}{G} only.
#'
#' @param rn Numeric. Net radiation \eqn{R_n}{Rn} at the satellite overpass
#'   \[W m-2\], positive towards the surface (e.g. from
#'   [ef_net_radiation()]). Any finite value is accepted; negative values are
#'   physically possible.
#' @param lst Numeric. Land surface temperature \eqn{T_s}{Ts} \[K\]. Must be
#'   finite and `> 0`. Converted internally to degrees Celsius with the
#'   package constant 273.15 K. For `ef_g_tasumi()` it is required in every
#'   position, not only where the bare-soil branch applies (see Details).
#' @param albedo Numeric. Broadband surface albedo \eqn{\alpha}{albedo}
#'   \[-\]. Must lie in \[0, 1\].
#' @param ndvi Numeric. Normalised difference vegetation index \[-\]. Must
#'   lie in \[-1, 1\].
#' @param lai Numeric. Leaf area index \[m2 m-2\]. Must be finite and
#'   `>= 0`.
#' @param method Character. The formulation, with no default: the choice of
#'   \eqn{G}{G} is a scientific decision that must be explicit. One of
#'   `"bastiaanssen"` (requires `lst`, `albedo`, `ndvi`) or `"tasumi"`
#'   (requires `lst`, `lai`). Matched exactly (no abbreviation, no change of
#'   case). Arguments not used by the chosen method are ignored.
#'
#' @return
#' `ef_g_bastiaanssen()` and `ef_g_tasumi()` return a numeric vector of soil
#' heat flux \eqn{G}{G} \[W m-2\] with the common length of the inputs,
#' keeping the `dim` of matrix or array inputs. Negative values and values
#' larger than `rn` are possible and returned unchanged.
#'
#' `ef_g()` returns a list of class `earthflux_soil_heat_flux` with
#' elements:
#' \describe{
#'   \item{`g`}{\eqn{G}{G} \[W m-2\], identical to the method function.}
#'   \item{`g_rn_ratio`}{\eqn{G/R_n}{G/Rn} \[-\], computed as `g / rn`;
#'     `NA` where `rn` is 0.}
#'   \item{`method`}{The method name.}
#'   \item{`branch`}{For `"tasumi"`, a character vector with the branch
#'     applied in each position (`"lai_ge_0.5"` or `"lai_lt_0.5"`; `NA`
#'     where `g` is `NA`), with the shape of `g`; `NULL` for
#'     `"bastiaanssen"`.}
#'   \item{`flags`}{A list of diagnostic flag records (see Diagnostics).}
#'   \item{`provenance`}{A list with the method, the method function, the
#'     verification status, the references, the Kelvin offset, the
#'     coefficients of the equation, the inputs used and the EarthFlux
#'     version.}
#' }
#'
#' @details
#' **Bastiaanssen (SEBAL).**
#' \deqn{\frac{G}{R_n} = T_c \, (0.0038 + 0.0074\,\alpha)\,
#'   (1 - 0.98\,\mathrm{NDVI}^4), \qquad G = R_n \frac{G}{R_n}}{G/Rn = Tc *
#'   (0.0038 + 0.0074 * albedo) * (1 - 0.98 * NDVI^4), G = Rn * G/Rn}
#' with \eqn{T_c = T_s - 273.15}{Tc = Ts - 273.15} in degrees Celsius. The
#' ratio is negative for \eqn{T_s < 273.15}{Ts < 273.15} K and NDVI enters
#' with an even power, so negative NDVI (water) gives the same result as the
#' opposite positive NDVI.
#'
#' **Tasumi (METRIC).**
#' \deqn{\frac{G}{R_n} = 0.05 + 0.18\, e^{-0.521\,\mathrm{LAI}}, \qquad
#'   G = R_n \frac{G}{R_n} \qquad (\mathrm{LAI} \ge 0.5)}{G/Rn = 0.05 + 0.18
#'   * exp(-0.521 * LAI), G = Rn * G/Rn (LAI >= 0.5)}
#' \deqn{G = 1.80\, T_c + 0.084\, R_n \qquad (\mathrm{LAI} < 0.5)}{G = 1.80
#'   * Tc + 0.084 * Rn (LAI < 0.5)}
#' The bare-soil branch is evaluated directly, without dividing by
#' \eqn{R_n}{Rn}. The relation is discontinuous at LAI = 0.5, which belongs
#' to the vegetated branch. Missing `lst` gives a missing \eqn{G}{G} in both
#' branches (decision G-D5, provisional), so the result does not depend on
#' which branch a position falls in.
#'
#' Assumptions: \eqn{G}{G} and \eqn{R_n}{Rn} are instantaneous at the
#' overpass; \eqn{G > 0}{G > 0} when heat flows from the surface into the
#' ground. Both relations are empirical, developed for land surfaces near
#' midday; no rule is applied for water, snow or impervious surfaces, which
#' must be masked or treated separately by the user.
#'
#' **Inputs.** Arguments must be numeric and have length 1 or a common
#' length; length-1 arguments are recycled; matrix or array arguments must
#' share their `dim` and are not recycled. Missing values (`NA`, `NaN`)
#' propagate to the corresponding output element without errors or
#' warnings. Physically impossible values (`albedo` outside \[0, 1\], `ndvi`
#' outside \[-1, 1\], negative `lai`, non-positive `lst`, or any infinite
#' value) raise an error of class `earthflux_domain_error` (also
#' `earthflux_input_error`) naming the argument; values are never corrected.
#' A missing or unknown `method` raises `earthflux_missing_input` or
#' `earthflux_unknown_method`, and an input required by the chosen method
#' that is missing or `NULL` raises `earthflux_missing_input` (all also
#' `earthflux_input_error`).
#'
#' **Diagnostics.** `ef_g()` returns, in `flags`, one record per condition
#' that holds in at least one position: `EF_INPUT_NA` (a required input is
#' missing), `EF_G_RN_NONPOSITIVE` (\eqn{R_n \le 0}{Rn <= 0}),
#' `EF_G_RATIO_NEGATIVE` (\eqn{G/R_n < 0}{G/Rn < 0}),
#' `EF_G_AVAILABLE_NONPOSITIVE` (\eqn{R_n - G \le 0}{Rn - G <= 0}) and, for
#' `"tasumi"`, `EF_G_LOW_LAI_BRANCH` (bare-soil branch applied). No
#' plausible range of \eqn{G/R_n}{G/Rn} is checked until one is documented
#' with a reference.
#'
#' @section Verification status:
#' Both formulations are `CANDIDATA`. Their form, coefficients and the
#' LAI threshold were observed in a secondary implementation (the `water`
#' R package, version 1.0) and are rewritten here; the primary references
#' were not consulted. The sign convention, the Kelvin offset used by the
#' sources (273.15 is used here) and whether the bare-soil condition is
#' `LAI < 0.5` or `LAI <= 0.5` remain to be verified. No default method is
#' offered for this reason. Applying the relations to 1 km MODIS pixels
#' (mixed cover, composite NDVI and LAI) is not validated.
#'
#' @references
#' Bastiaanssen, W. G. M. (2000). SEBAL-based sensible and latent heat
#' fluxes in the irrigated Gediz Basin, Turkey. *Journal of Hydrology*,
#' 229(1-2), 87-100. \doi{10.1016/S0022-1694(99)00202-4}
#'
#' Tasumi, M. (2003). *Progress in operational estimation of regional
#' evapotranspiration using satellite imagery* (PhD dissertation).
#' University of Idaho.
#'
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @seealso [ef_net_radiation()] for \eqn{R_n}{Rn}.
#'
#' @export
#'
#' @examples
#' # Tasumi: dense canopy (vegetated branch) and bare soil (LAI < 0.5)
#' ef_g_tasumi(rn = c(550, 400), lst = c(300, 318.15), lai = c(3, 0.2))
#'
#' # Bastiaanssen: intermediate vegetation
#' ef_g_bastiaanssen(rn = 500, lst = 303.15, albedo = 0.20, ndvi = 0.50)
#'
#' # Dispatcher: G, G/Rn, branch, flags and provenance
#' g <- ef_g(rn = c(550, 40), lst = 318.15, lai = c(3, 0.2),
#'           method = "tasumi")
#' g$g
#' g$g_rn_ratio
#' g$branch
#' vapply(g$flags, `[[`, character(1), "code")
#'
#' # Chained with the net radiation
#' rn <- ef_net_radiation(rs_in = 800, albedo = 0.20, rl_in = 320,
#'                        rl_out = 450.0846, emissivity = 0.98)
#' ef_g(rn, lst = 303.15, albedo = 0.20, ndvi = 0.50,
#'      method = "bastiaanssen")$g
ef_g <- function(rn, lst = NULL, albedo = NULL, ndvi = NULL, lai = NULL,
                 method) {
  call <- sys.call()
  check_method(method, c("bastiaanssen", "tasumi"), call = call)

  required <- switch(
    method,
    bastiaanssen = c("rn", "lst", "albedo", "ndvi"),
    tasumi = c("rn", "lst", "lai")
  )
  if (missing(rn)) {
    rn <- NULL
  }
  inputs <- list(rn = rn, lst = lst, albedo = albedo, ndvi = ndvi,
                 lai = lai)[required]
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

  if (method == "bastiaanssen") {
    g <- ef_g_bastiaanssen(rn = rn, lst = lst, albedo = albedo, ndvi = ndvi)
    low_lai <- NULL
    branch <- NULL
    fun <- "ef_g_bastiaanssen"
    coefficients <- ef_g_bastiaanssen_coefficients()
    references <- c(
      "Bastiaanssen (2000), J. Hydrol. 229(1-2), 87-100, doi:10.1016/S0022-1694(99)00202-4"
    )
  } else {
    g <- ef_g_tasumi(rn = rn, lst = lst, lai = lai)
    coefficients <- ef_g_tasumi_coefficients()
    threshold <- coefficients$lai_threshold
    low_lai <- !is.na(g) & rep_len(lai < threshold, length(g))
    branch <- rep_len(NA_character_, length(g))
    branch[!is.na(g)] <- paste0("lai_ge_", format(threshold))
    branch[low_lai] <- paste0("lai_lt_", format(threshold))
    dim(branch) <- dim(g)
    fun <- "ef_g_tasumi"
    references <- c(
      "Tasumi (2003), PhD dissertation, University of Idaho",
      "Allen, Tasumi & Trezza (2007), J. Irrig. Drain. Eng. 133(4), 380-394, doi:10.1061/(ASCE)0733-9437(2007)133:4(380)"
    )
  }

  g_rn_ratio <- ef_g_rn_ratio(g, rn)

  flags <- c(
    ef_input_na_flags(inputs, length(g)),
    ef_diagnose_soil_heat(rn = rn, g = g, g_rn_ratio = g_rn_ratio,
                          low_lai = low_lai)
  )

  new_ef_object(
    list(
      g = g,
      g_rn_ratio = g_rn_ratio,
      method = method,
      branch = branch,
      flags = flags,
      provenance = list(
        method = method,
        fun = fun,
        status = "CANDIDATA",
        references = references,
        kelvin_offset = EF_KELVIN_OFFSET,
        coefficients = coefficients,
        inputs = required,
        earthflux_version = as.character(getNamespaceVersion("EarthFlux"))
      )
    ),
    "earthflux_soil_heat_flux"
  )
}

#' @rdname ef_g
#' @export
ef_g_bastiaanssen <- function(rn, lst, albedo, ndvi) {
  call <- sys.call()
  args <- list(rn = rn, lst = lst, albedo = albedo, ndvi = ndvi)
  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)

  check_in_range(rn, "rn", call = call)
  check_in_range(lst, "lst", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(albedo, "albedo", lower = 0, upper = 1, call = call)
  check_in_range(ndvi, "ndvi", lower = -1, upper = 1, call = call)

  k <- ef_g_bastiaanssen_coefficients()
  tc <- lst - EF_KELVIN_OFFSET
  ratio <- tc * (k$c_t + k$c_albedo * albedo) *
    (1 - k$c_ndvi * ndvi^k$ndvi_exponent)
  rn * ratio
}

#' @rdname ef_g
#' @export
ef_g_tasumi <- function(rn, lst, lai) {
  call <- sys.call()
  args <- list(rn = rn, lst = lst, lai = lai)
  for (nm in names(args)) {
    check_numeric(args[[nm]], nm, call = call)
  }
  n <- check_common_length(args, call = call)
  check_same_dim(args, n, call = call)

  check_in_range(rn, "rn", call = call)
  check_in_range(lst, "lst", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(lai, "lai", lower = 0, call = call)

  k <- ef_g_tasumi_coefficients()
  tc <- lst - EF_KELVIN_OFFSET
  g_veg <- rn * (k$veg_a + k$veg_b * exp(-k$veg_k * lai))
  g_bare <- k$bare_t * tc + k$bare_rn * rn
  # Combination by mask instead of ifelse(): keeps `dim`, and a missing
  # `lst` propagates in both branches (0 * NA is NA; decision G-D5).
  low <- lai < k$lai_threshold
  low * g_bare + (!low) * g_veg
}

#' Ratio G/Rn of the soil heat flux stage
#'
#' Computes `g / rn`, with `NA` where `rn` is 0 (the ratio is undefined;
#' dev/specs/soil-heat-flux.md section 5.4). Keeps the shape of `g`.
#'
#' @param g Numeric. Soil heat flux \[W m-2\].
#' @param rn Numeric. Net radiation \[W m-2\], of length 1 or the length of
#'   `g`.
#' @return Numeric G/Rn \[-\] with the shape of `g`.
#' @noRd
ef_g_rn_ratio <- function(g, rn) {
  ratio <- g / rn
  ratio[rep_len(rn %in% 0, length(ratio))] <- NA_real_
  ratio
}

#' Cell diagnostics of the soil heat flux stage
#'
#' Builds the cell-scope flag records of the G stage from the outputs of a
#' method function (dev/ARCHITECTURE.md section 3.2; dev/specs/flags.md
#' section 4.2). Only conditions that hold in at least one position produce
#' a record. Values are never modified.
#'
#' @param rn Numeric. Net radiation \[W m-2\] (length 1 or the length of
#'   `g`).
#' @param g Numeric. Soil heat flux \[W m-2\].
#' @param g_rn_ratio Numeric. G/Rn \[-\], `NA` where `rn` is 0.
#' @param low_lai Logical without `NA` or `NULL`. Positions where the
#'   bare-soil branch of the Tasumi method was applied; `NULL` for methods
#'   without branches.
#' @return A list (possibly empty) of `earthflux_flag` records with codes
#'   `EF_G_RN_NONPOSITIVE`, `EF_G_RATIO_NEGATIVE`,
#'   `EF_G_AVAILABLE_NONPOSITIVE` and `EF_G_LOW_LAI_BRANCH`.
#' @noRd
ef_diagnose_soil_heat <- function(rn, g, g_rn_ratio, low_lai = NULL) {
  n <- length(g)
  rn <- rep_len(as.vector(rn), n)
  g <- as.vector(g)
  ratio <- as.vector(g_rn_ratio)

  masks <- list(
    EF_G_RN_NONPOSITIVE = !is.na(rn) & rn <= 0,
    EF_G_RATIO_NEGATIVE = !is.na(ratio) & ratio < 0,
    EF_G_AVAILABLE_NONPOSITIVE = !is.na(rn) & !is.na(g) & rn - g <= 0
  )
  if (!is.null(low_lai)) {
    masks$EF_G_LOW_LAI_BRANCH <- as.vector(low_lai)
  }
  masks <- masks[vapply(masks, any, logical(1))]
  unname(Map(function(mask, code) ef_flag(mask, code), masks, names(masks)))
}

# Diagnostic flags of this stage -------------------------------------------------

#' Flag codes owned by the soil heat flux (G) stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_G_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7). The
#' class II codes `EF_G_NDVI_NONPOSITIVE` and `EF_G_RATIO_IMPLAUSIBLE` are
#' not registered (decisions G-D4 and G-D7).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_soil_heat <- function() {
  ef_flag_rows(
    code = c(
      "EF_G_RN_NONPOSITIVE",
      "EF_G_RATIO_NEGATIVE",
      "EF_G_AVAILABLE_NONPOSITIVE",
      "EF_G_LOW_LAI_BRANCH"
    ),
    stage = rep("G", 4L),
    severity = c("warning", "warning", "warning", "info"),
    scope = rep("cell", 4L),
    bit = 1:4,
    error_class = rep(NA_character_, 4L),
    description = c(
      paste(
        "Net radiation is zero or negative;",
        "the ratio G/Rn is undefined or of inverted meaning."
      ),
      "The ratio G/Rn is negative; the value is reported unchanged.",
      paste(
        "Available energy Rn - G is zero or negative;",
        "the values are reported unchanged."
      ),
      paste(
        "The bare-soil branch (LAI < 0.5) of the Tasumi soil heat flux",
        "method was applied."
      )
    ),
    spec = c(
      "dev/specs/soil-heat-flux.md 6.3",
      "dev/specs/soil-heat-flux.md 6.3",
      "dev/specs/flags.md 4.2",
      "dev/specs/soil-heat-flux.md 6.3"
    ),
    since = rep("0.0.0.9000", 4L)
  )
}
