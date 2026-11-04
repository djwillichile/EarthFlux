# Spatial forcing: GWR diagnostics -------------------------------------------------
#
# Purpose: diagnostics of fitted GWR models (fit statistics, station table,
#   criterion profile, flags), the local R2, and the registry rows of the
#   EF_GWR_* flag codes raised by the GWR core.
#
# Specification: dev/specs/gwr-forcing.md sections 3.6, 3.8, 7 and 12;
#   dev/specs/flags.md sections 4.2, 6.4 and 7. Spatial autocorrelation of
#   the residuals (Moran's I, section 7.3) stays TODO: its source was not
#   read.

#' Diagnostics of a geographically weighted regression
#'
#' @description
#' Collects the diagnostics of a fitted GWR model (dev/specs/gwr-forcing.md
#' section 7.1) in plain R objects: global fit statistics, the global (OLS)
#' reference, the station table (observed, fitted, residuals, leave-one-out
#' residuals, \eqn{s_{ii}}{s_ii}, local R2, bandwidth, neighbours, condition
#' number, status), the bandwidth profile and a table of the flags.
#'
#' @param object An `earthflux_gwr` object from [ef_gwr_fit()].
#'
#' @return A list with:
#'   * `fit`: list of fit statistics (`n`, `p`, `rss`, `sigma_ml`,
#'     `sigma_edf`, `enp` = tr(S), `tr_sts`, `enp_alt` = 2 tr(S) - tr(S'S),
#'     `edf` = n - 2 tr(S) + tr(S'S), `aicc`, `aic`, `cv`, `rmse_loo`, `r2`);
#'   * `global_reference`: OLS with the same design;
#'   * `stations`: the station table (see [ef_gwr_fit()]);
#'   * `profile`: the bandwidth profile, or `NULL` for a bandwidth given by
#'     the user;
#'   * `flags`: data frame with one row per flag record (`code`,
#'     `severity`, `scope`, `n_flagged`, `n_total`, `description`).
#'
#' @details
#' The local R2 at station i is that of the local WLS fit,
#' \deqn{R^2_i = 1 - \frac{\sum_j w_{ij} (y_j - x_j^\top\hat\beta_i)^2}
#'   {\sum_j w_{ij} (y_j - \bar y_{w,i})^2}, \qquad \bar y_{w,i} = \frac{\sum_j
#'   w_{ij} y_j}{\sum_j w_{ij}},}{R2_i = 1 - sum_j w_ij (y_j - x_j' beta_i)^2
#'   / sum_j w_ij (y_j - ybar_w,i)^2,}
#' identical to `summary(lm(y ~ x, weights = w_i))$r.squared` (decision
#' GW-13). Other software reports other conventions; `GWmodel` 2.4-1
#' `Local_R2` uses the global fitted values \eqn{\hat y_j = (Sy)_j}{yhat_j}
#' and the unweighted mean of y.
#'
#' @section Verification status:
#' tr(S) in AICc: `VERIFICADA` as content of Gollini et al. (2015, section
#' 6.1). tr(S'S), 2 tr(S) - tr(S'S), edf, sigma_edf, the local R2 and the
#' condition number: `CANDIDATA` (original definitions in Fotheringham et
#' al., 2002, and Belsley et al., 1980, not read).
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' coords <- cbind(c(0, 10000, 0, 10000, 20000, 30000),
#'                 c(0, 0, 10000, 10000, 0, 30000))
#' elev <- cbind(elevation = c(100, 300, 500, 200, 800, 1200))
#' ta <- c(20.0, 18.9, 17.5, 19.6, 15.4, 13.1)
#' fit <- ef_gwr_fit(ta, elev, coords, bandwidth = 20000,
#'                   kernel = "gaussian")
#' d <- ef_gwr_diagnostics(fit)
#' d$fit$aicc
#' d$stations[, c("station_id", "residual", "loo_residual", "s_ii")]
ef_gwr_diagnostics <- function(object) {
  if (!inherits(object, "earthflux_gwr")) {
    ef_abort("`object` must be an `earthflux_gwr` object (see `ef_gwr_fit()`).",
             class = "earthflux_input_error", call = sys.call())
  }
  flags <- object$flags
  ftab <- data.frame(
    code = vapply(flags, `[[`, "", "code"),
    severity = vapply(flags, `[[`, "", "severity"),
    scope = vapply(flags, `[[`, "", "scope"),
    n_flagged = vapply(flags, `[[`, 0L, "n_flagged"),
    n_total = vapply(flags, `[[`, 0L, "n_total"),
    description = vapply(flags, `[[`, "", "description"),
    stringsAsFactors = FALSE
  )
  list(
    fit = object$fit,
    global_reference = object$global_reference,
    stations = object$stations,
    profile = object$profile,
    flags = ftab
  )
}

#' Local R2 of the local WLS fits
#'
#' @param w Matrix n x n of weights (row i = regression point i).
#' @param y Response of the stations.
#' @param fit_mat Matrix n x n with entries \eqn{x_j^\top\hat\beta_i}.
#' @return Numeric vector of local R2 (convention
#'   `"local_fit_weighted_mean"`).
#' @noRd
gwr_local_r2 <- function(w, y, fit_mat) {
  n <- nrow(w)
  yy <- rep(y, each = n)
  num <- rowSums(w * (yy - fit_mat)^2)
  ybar <- rowSums(w * yy) / rowSums(w)
  den <- rowSums(w * (yy - ybar)^2)
  1 - num / den
}

#' Local R2 with the global fitted values and the unweighted mean
#'
#' The convention of `GWmodel` 2.4-1 (`Local_R2`), used only to cross-check
#' (dev/specs/gwr-forcing.md section 3.8).
#'
#' @param w Matrix n x n of weights.
#' @param y Response.
#' @param fitted Global fitted values (Sy).
#' @return Numeric vector.
#' @noRd
gwr_local_r2_global_fit <- function(w, y, fitted) {
  n <- nrow(w)
  num <- rowSums(w * rep((y - fitted)^2, each = n))
  den <- rowSums(w * rep((y - mean(y))^2, each = n))
  1 - num / den
}

# Diagnostic flags of this stage ---------------------------------------------------

#' Flag codes owned by the GWR stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_GWR_` raised
#' by the GWR core (dev/specs/flags.md section 4.2; bits of section 6.4).
#' Codes of the orchestration (`EF_GWR_COARSE_MODE`, `EF_GWR_TRANSFORMED`,
#' `EF_GWR_SURFACE_COVARIATE`, `EF_GWR_SINGLE_STATION`, class III
#' `EF_GWR_OUT_OF_DOMAIN`) are registered with the functions that raise
#' them. Class II codes (`EF_GWR_FAR_FROM_STATIONS`,
#' `EF_GWR_ILL_CONDITIONED`, `EF_GWR_FEW_STATIONS`,
#' `EF_GWR_ELEVATION_MISMATCH`) are never registered until their thresholds
#' have a reference.
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_gwr <- function() {
  spec <- "dev/specs/flags.md 4.2; dev/specs/gwr-forcing.md"
  ef_flag_rows(
    code = c(
      "EF_GWR_EXTRAPOLATION_COVARIATE",
      "EF_GWR_EXTRAPOLATION_LOCAL",
      "EF_GWR_OUTSIDE_HULL",
      "EF_GWR_FEW_NEIGHBOURS",
      "EF_GWR_LOCAL_SINGULAR",
      "EF_GWR_BW_AT_BOUND",
      "EF_GWR_BW_MULTIMODAL",
      "EF_GWR_AICC_UNDEFINED",
      "EF_GWR_GLOBAL_PREFERRED",
      "EF_GWR_STATION_EXCLUDED"
    ),
    stage = rep("GWR", 10L),
    severity = c("warning", "info", "warning", "warning", "warning",
                 "warning", "info", "info", "info", "info"),
    scope = c("cell", "cell", "cell", "cell,record", "cell", "object",
              "object", "object", "object", "record"),
    bit = c(1L, 2L, 3L, 4L, 5L, NA, NA, NA, NA, NA),
    error_class = c(NA, NA, NA, NA, "earthflux_gwr_singular_error", NA, NA,
                    "earthflux_gwr_no_feasible_bandwidth", NA, NA),
    description = c(
      paste0("A covariate is outside the range of the stations used in the ",
             "fit."),
      paste0("A covariate is outside the range of the stations with a ",
             "non-zero weight at this location."),
      "The location is outside the convex hull of the stations used.",
      paste0("Fewer stations than the minimum number of neighbours have a ",
             "non-zero weight (or lie within one bandwidth)."),
      paste0("The local design is rank deficient; the prediction is NA at ",
             "this location."),
      paste0("The selected bandwidth is at a bound of the search interval; ",
             "it is returned, not extrapolated."),
      "The bandwidth profile has more than one feasible local minimum.",
      paste0("AICc is undefined (n - 2 - tr(S) <= 0) for part of the ",
             "bandwidths evaluated."),
      paste0("The global regression has a criterion not larger than the ",
             "selected bandwidth."),
      paste0("The station was excluded from the fit (missing response, ",
             "covariate or coordinate).")
    ),
    spec = paste(spec, c("6.3", "6.3", "6.3", "4.5", "4.6", "4.4", "4.4",
                         "4.1", "4.4", "9.4")),
    since = rep("0.0.0.9000", 10L)
  )
}
