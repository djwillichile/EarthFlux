# Spatial forcing: GWR bandwidth selection --------------------------------------
#
# Purpose: bandwidth selection (fixed or adaptive) by an explicit criterion
#   (AICc or leave-one-out cross-validation), keeping the full criterion
#   profile so that the selection is auditable.
#
# Specification: dev/specs/gwr-forcing.md section 4 (AICc adopted, decision
#   GW-02; reconciliation of the AICc of other implementations; LOOCV;
#   search algorithm; minimum neighbours and stations, GW-06; behaviour with
#   few stations). The criterion and the search settings have no defaults
#   (decision GW-05 is open).

# Criteria ------------------------------------------------------------------------

#' AICc of a GWR fit
#'
#' \deqn{AICc = 2n\ln\hat\sigma + n\ln(2\pi) + n\,\frac{n + tr(S)}{n - 2 -
#' tr(S)}, \qquad \hat\sigma = \sqrt{RSS/n}}
#' (dev/specs/gwr-forcing.md section 4.1). Defined only when
#' \eqn{n - 2 - tr(S) > 0}; `NA` otherwise.
#'
#' @param rss Residual sum of squares.
#' @param enp tr(S).
#' @param n Number of stations of the fit.
#' @return Numeric scalar or `NA`.
#' @noRd
gwr_aicc <- function(rss, enp, n) {
  den <- n - 2 - enp
  if (!(den > 0)) {
    return(NA_real_)
  }
  2 * n * log(sqrt(rss / n)) + n * log(2 * pi) + n * (n + enp) / den
}

#' Uncorrected AIC of a GWR fit (report only)
#'
#' \eqn{2n\ln\hat\sigma + n\ln(2\pi) + n + tr(S)}, the quantity `GWmodel`
#' reports as `AIC` (dev/specs/gwr-forcing.md section 4.2).
#'
#' @inheritParams gwr_aicc
#' @return Numeric scalar.
#' @noRd
gwr_aic <- function(rss, enp, n) {
  2 * n * log(sqrt(rss / n)) + n * log(2 * pi) + n + enp
}

#' Leave-one-out cross-validation score
#'
#' \eqn{CV = \sum_i e_{-i}^2} (dev/specs/gwr-forcing.md section 4.3); `NA`
#' if some LOO residual is undefined.
#'
#' @param e_loo LOO residuals.
#' @return Numeric scalar \[unit of y squared\].
#' @noRd
gwr_cv_score <- function(e_loo) {
  if (anyNA(e_loo)) NA_real_ else sum(e_loo^2)
}

#' Criteria of the bandwidth selection
#'
#' @return Character vector.
#' @noRd
gwr_criteria <- function() {
  c("AICc", "CV")
}

# Search control ------------------------------------------------------------------

#' Search settings of the GWR bandwidth selection
#'
#' @description
#' Builds the validated list of settings used by [ef_gwr_bandwidth()]
#' (dev/specs/gwr-forcing.md section 4.4). The numerical settings of the
#' fixed-bandwidth search have no default (decision GW-05 is open): a value
#' left `NULL` is required only when the search needs it, and
#' [ef_gwr_bandwidth()] then raises `earthflux_missing_input`.
#'
#' **Fixed bandwidth \[m\].** The search interval is \[`lower`, `upper`\].
#' When `lower` is `NULL` it is computed as
#' \eqn{\max_i d_{i,(m)}}, the largest over the stations of the distance to
#' their m-th nearest station counting themselves (m = `min_neighbours`),
#' multiplied by `1 + lower_offset` for the bisquare and tricube kernels
#' (whose weight vanishes at the bandwidth, so feasibility needs b strictly
#' larger). When `upper` is `NULL` it is `upper_factor` times the largest
#' distance between stations. The criterion is evaluated on `n_grid` values
#' equally spaced in log(b), then refined with [stats::optimize()] (Brent)
#' between the grid neighbours of the best feasible grid value, with
#' absolute tolerance `tol` \[m\]. The global (OLS) model is always
#' evaluated as the b = Inf reference.
#'
#' **Adaptive bandwidth (k neighbours).** Exhaustive search over the whole
#' numbers \[`k_min`, `k_max`\]; by default `k_min` is `min_neighbours` + 1
#' for the bisquare and tricube kernels and `min_neighbours` otherwise, and
#' `k_max` is the number of stations.
#'
#' @param lower,upper `NULL` or positive numbers: bounds of the fixed
#'   bandwidth \[m\].
#' @param n_grid `NULL` or a whole number >= 3: number of grid values of the
#'   fixed-bandwidth search.
#' @param tol `NULL` or a positive number: tolerance of the refinement \[m\].
#' @param min_neighbours `NULL` or a whole number: minimum number of
#'   neighbours at every station for a bandwidth to be feasible (see
#'   [ef_gwr_fit()]); `NULL` uses the mathematical minimum p + 1.
#' @param lower_offset `NULL` or a number >= 0 (delta of the automatic lower
#'   bound for the bisquare and tricube kernels).
#' @param upper_factor `NULL` or a positive number (factor of the largest
#'   inter-station distance for the automatic upper bound).
#' @param k_min,k_max `NULL` or whole numbers >= 1: bounds of the adaptive
#'   search (neighbours).
#' @param method_adaptive Character. Search over k: only `"exhaustive"` is
#'   implemented.
#'
#' @return A list of class `earthflux_gwr_search` with the settings.
#'
#' @details
#' These values are search conventions, not scientific constants; they are
#' recorded in the selection object. Invalid values raise
#' `earthflux_domain_error` or `earthflux_input_error`.
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' ef_gwr_search(n_grid = 30, tol = 1, lower_offset = 0.01, upper_factor = 2)
ef_gwr_search <- function(lower = NULL, upper = NULL, n_grid = NULL,
                          tol = NULL, min_neighbours = NULL,
                          lower_offset = NULL, upper_factor = NULL,
                          k_min = NULL, k_max = NULL,
                          method_adaptive = "exhaustive") {
  call <- sys.call()
  opt <- function(x, arg, lower = -Inf, lower_inclusive = TRUE,
                  whole = FALSE) {
    if (!is.null(x)) {
      check_scalar(x, arg, lower = lower, lower_inclusive = lower_inclusive,
                   whole = whole, call = call)
    }
  }
  opt(lower, "lower", 0, FALSE)
  opt(upper, "upper", 0, FALSE)
  opt(n_grid, "n_grid", 3, whole = TRUE)
  opt(tol, "tol", 0, FALSE)
  opt(min_neighbours, "min_neighbours", 1, whole = TRUE)
  opt(lower_offset, "lower_offset", 0)
  opt(upper_factor, "upper_factor", 0, FALSE)
  opt(k_min, "k_min", 1, whole = TRUE)
  opt(k_max, "k_max", 1, whole = TRUE)
  if (!is.null(lower) && !is.null(upper)) {
    check_condition(lower < upper, "`lower` must be smaller than `upper`",
                    call)
  }
  if (!is.null(k_min) && !is.null(k_max)) {
    check_condition(k_min <= k_max, "`k_min` must not exceed `k_max`", call)
  }
  check_method(method_adaptive, "exhaustive", arg = "method_adaptive",
               call = call)
  as_int <- function(v) if (is.null(v)) NULL else as.integer(v)
  as_num <- function(v) if (is.null(v)) NULL else as.numeric(v)
  structure(
    list(
      lower = as_num(lower), upper = as_num(upper),
      n_grid = as_int(n_grid), tol = as_num(tol),
      min_neighbours = as_int(min_neighbours),
      lower_offset = as_num(lower_offset),
      upper_factor = as_num(upper_factor),
      k_min = as_int(k_min), k_max = as_int(k_max),
      method_adaptive = method_adaptive
    ),
    class = c("earthflux_gwr_search", "list")
  )
}

#' Resolve the search settings for a data set
#'
#' @param search An `earthflux_gwr_search` object.
#' @param ctx The fit context.
#' @param nb Resolved minimum neighbours.
#' @param call The call to report.
#' @return A plain list with the effective bounds and settings.
#' @noRd
gwr_resolve_search <- function(search, ctx, nb, call) {
  need <- function(fields) {
    absent <- fields[vapply(fields, function(f) is.null(search[[f]]),
                            logical(1))]
    if (length(absent) > 0L) {
      ef_abort(
        sprintf(
          paste0("The search needs %s in `ef_gwr_search()` (no default: ",
                 "decision GW-05 is open)."),
          paste0("`", absent, "`", collapse = ", ")
        ),
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
  }
  common <- list(
    min_neighbours = nb$value,
    min_neighbours_source = nb$source,
    method_adaptive = search$method_adaptive,
    tie_rule = "smallest_bandwidth"
  )
  if (ctx$adaptive) {
    k_min <- search$k_min
    if (is.null(k_min)) {
      k_min <- nb$value +
        as.integer(ctx$kernel %in% c("bisquare", "tricube"))
    }
    k_max <- if (is.null(search$k_max)) ctx$n else search$k_max
    check_in_range(k_max, "k_max", upper = ctx$n, call = call)
    check_condition(k_min <= k_max,
                    sprintf("`k_min` (%d) must not exceed `k_max` (%d)",
                            k_min, k_max), call)
    return(c(list(type = "adaptive", k_min = as.integer(k_min),
                  k_max = as.integer(k_max)), common))
  }
  need(c("n_grid", "tol"))
  compact0 <- ctx$kernel %in% c("bisquare", "tricube")
  lower_auto <- max(ctx$dist_sorted[, nb$value])
  upper_auto <- NULL
  lower <- search$lower
  if (is.null(lower)) {
    if (compact0) need("lower_offset")
    lower <- lower_auto * (1 + if (compact0) search$lower_offset else 0)
  }
  upper <- search$upper
  d_max <- max(ctx$dist)
  if (is.null(upper)) {
    need("upper_factor")
    upper_auto <- search$upper_factor * d_max
    upper <- upper_auto
  }
  if (!(lower < upper)) {
    ef_abort(
      sprintf("The fixed-bandwidth search interval is empty: lower = %s m, upper = %s m.",
              format(lower), format(upper)),
      class = c("earthflux_domain_error", "earthflux_input_error"),
      call = call
    )
  }
  c(list(type = "fixed", lower = lower, upper = upper,
         n_grid = search$n_grid, tol = search$tol,
         lower_auto = lower_auto, upper_auto = upper_auto,
         lower_offset = search$lower_offset,
         upper_factor = search$upper_factor, d_max = d_max), common)
}

# Profile ----------------------------------------------------------------------------

#' Evaluate the criterion at one bandwidth
#'
#' @param ctx The fit context.
#' @param bandwidth b \[m\], k, or `Inf` (global model).
#' @param nb Minimum neighbours (integer).
#' @param criterion `"AICc"` or `"CV"`.
#' @return A one-row data frame with `bandwidth`, `criterion`, `feasible`,
#'   `reason`, `aicc`, `cv`, `enp`, `rss` and `min_nonzero`.
#' @noRd
gwr_evaluate <- function(ctx, bandwidth, nb, criterion) {
  core <- gwr_fit_core(ctx, bandwidth)
  min_nn <- min(core$n_nonzero)
  if (any(core$singular)) {
    enp <- rss <- aicc <- cv <- NA_real_
    reason <- "rank_deficient"
  } else {
    enp <- core$enp
    rss <- core$rss
    aicc <- core$aicc
    cv <- core$cv
    reason <- NA_character_
    if (min_nn < nb) {
      reason <- "few_neighbours"
    } else if (criterion == "AICc" && is.na(aicc)) {
      reason <- "aicc_undefined"
    } else if (criterion == "CV" && is.na(cv)) {
      reason <- "loo_undefined"
    }
  }
  crit <- if (criterion == "AICc") aicc else cv
  if (is.na(reason) && !is.finite(crit)) reason <- "criterion_not_finite"
  data.frame(
    bandwidth = as.numeric(bandwidth),
    criterion = if (is.na(reason)) crit else NA_real_,
    feasible = is.na(reason),
    reason = reason,
    aicc = aicc, cv = cv, enp = enp, rss = rss,
    min_nonzero = as.integer(min_nn),
    stringsAsFactors = FALSE
  )
}

#' Number of local minima of a profile
#'
#' Over the feasible values in increasing order of bandwidth, a value is a
#' local minimum when it is strictly smaller than the previous feasible
#' value and not larger than the next one (end points compare with their
#' only neighbour).
#'
#' @param criterion Criterion values in order of bandwidth.
#' @param feasible Logical.
#' @return Integer.
#' @noRd
gwr_count_minima <- function(criterion, feasible) {
  v <- criterion[feasible]
  m <- length(v)
  if (m == 0L) return(0L)
  if (m == 1L) return(1L)
  prev_ok <- c(TRUE, v[-1L] < v[-m])
  next_ok <- c(v[-m] <= v[-1L], TRUE)
  sum(prev_ok & next_ok)
}

#' Best feasible row of a profile
#'
#' Smallest criterion; ties resolved by the smallest bandwidth.
#'
#' @param prof A profile data frame.
#' @return Row index, or `NA` if no row is feasible.
#' @noRd
gwr_best_row <- function(prof) {
  ok <- which(prof$feasible)
  if (length(ok) == 0L) return(NA_integer_)
  best <- min(prof$criterion[ok])
  cand <- ok[prof$criterion[ok] == best]
  cand[which.min(prof$bandwidth[cand])]
}

#' Profile and refinement of a fixed-bandwidth search
#'
#' @param ctx,res,nb,criterion Context, resolved search, minimum neighbours
#'   and criterion.
#' @return A list with `profile` (data frame, column `stage`) and `best`
#'   (row index of the selected bandwidth) and `at_bound`.
#' @noRd
gwr_profile_fixed <- function(ctx, res, nb, criterion) {
  grid <- exp(seq(log(res$lower), log(res$upper), length.out = res$n_grid))
  prof <- do.call(rbind, lapply(grid, gwr_evaluate, ctx = ctx, nb = nb,
                                criterion = criterion))
  prof$stage <- "grid"
  j <- gwr_best_row(prof)
  if (is.na(j)) {
    return(list(profile = prof, best = NA_integer_, at_bound = FALSE))
  }
  at_bound <- j == 1L || j == nrow(prof)
  if (!at_bound) {
    refine <- gwr_refine(ctx, c(grid[j - 1L], grid[j + 1L]), res$tol, nb,
                         criterion)
    prof <- rbind(prof, refine)
  }
  list(profile = prof, best = gwr_best_row(prof), at_bound = at_bound)
}

#' Brent refinement of a fixed bandwidth
#'
#' [stats::optimize()] on the interval between the grid neighbours of the
#' best grid value. Infeasible bandwidths return the largest double (no
#' warning, never selected).
#'
#' @param ctx,nb,criterion Context, minimum neighbours, criterion.
#' @param interval Numeric of length 2 \[m\].
#' @param tol Tolerance \[m\].
#' @return Data frame of the evaluations (stage `"refine"`).
#' @noRd
gwr_refine <- function(ctx, interval, tol, nb, criterion) {
  rows <- list()
  f <- function(b) {
    r <- gwr_evaluate(ctx, b, nb, criterion)
    rows[[length(rows) + 1L]] <<- r
    if (r$feasible) r$criterion else .Machine$double.xmax
  }
  stats::optimize(f, interval = interval, tol = tol)
  out <- do.call(rbind, rows)
  out$stage <- "refine"
  out
}

#' Profile of an adaptive-bandwidth search
#'
#' @param ctx,res,nb,criterion Context, resolved search, minimum neighbours
#'   and criterion.
#' @return A list with `profile`, `best` and `at_bound`.
#' @noRd
gwr_profile_adaptive <- function(ctx, res, nb, criterion) {
  ks <- seq.int(res$k_min, res$k_max)
  prof <- do.call(rbind, lapply(ks, gwr_evaluate, ctx = ctx, nb = nb,
                                criterion = criterion))
  prof$stage <- "grid"
  j <- gwr_best_row(prof)
  at_bound <- !is.na(j) && (j == 1L || j == nrow(prof))
  list(profile = prof, best = j, at_bound = at_bound)
}

# Selection ---------------------------------------------------------------------------

#' Select the bandwidth of a geographically weighted regression
#'
#' @description
#' Selects a fixed (metres) or adaptive (k nearest stations) bandwidth by
#' minimising AICc or the leave-one-out cross-validation score over a
#' recorded search, and returns the full profile of the criterion
#' (dev/specs/gwr-forcing.md section 4).
#'
#' AICc (decision GW-02):
#' \deqn{AICc = 2n\ln\hat\sigma + n\ln(2\pi) + n\,\frac{n + tr(S)}{n - 2 -
#'   tr(S)}, \qquad \hat\sigma = \sqrt{RSS/n},}{AICc = 2 n ln(sigma) +
#'   n ln(2 pi) + n (n + tr(S)) / (n - 2 - tr(S)), sigma = sqrt(RSS / n),}
#' with n the number of stations of the fit and tr(S) the trace of the hat
#' matrix; defined only when \eqn{n - 2 - tr(S) > 0}. Leave-one-out
#' cross-validation:
#' \deqn{CV = \sum_i (y_i - \hat y_{\ne i})^2,}{CV = sum_i (y_i -
#'   yhat_(-i))^2,}
#' where \eqn{\hat y_{\ne i}}{yhat_(-i)} is the local fit at station i with
#' its own weight set to zero (the bandwidth \eqn{b_i} is computed with the
#' station included), obtained exactly as \eqn{e_i / (1 - s_{ii})}{e_i /
#' (1 - s_ii)}.
#'
#' @inheritParams ef_gwr_fit
#' @param kernel Character, no default (decision GW-04 is open): one of
#'   `"gaussian"`, `"exponential"`, `"bisquare"`, `"tricube"`, `"boxcar"`.
#' @param criterion Character, no default (decision GW-05 is open): `"AICc"`
#'   or `"CV"`.
#' @param search The settings returned by [ef_gwr_search()].
#'
#' @return An object of class `c("earthflux_gwr_bandwidth", "list")` with
#'   elements `value` (b \[m\] or k), `type` (`"fixed"` or `"adaptive"`),
#'   `unit` (`"m"` or `"neighbours"`), `kernel`, `criterion`,
#'   `criterion_value`, `global` (criterion, AICc and CV of the global OLS
#'   model, the b = Inf reference), `profile` (data frame with one row per
#'   evaluation: `bandwidth`, `criterion`, `feasible`, `reason` of
#'   infeasibility, `aicc`, `cv`, `enp` = tr(S), `rss`, `min_nonzero`
#'   (smallest number of neighbours over the stations) and `stage`:
#'   `"grid"`, `"refine"` or `"global"`), `search` (effective bounds and
#'   settings, number of evaluations, tie rule), `stations` (`station_id`,
#'   `status`, `exclusion_reason`), `flags` and `provenance`. Pass it to
#'   [ef_gwr_fit()] as `bandwidth`.
#'
#' @details
#' A bandwidth is infeasible when, at some station, the local design is
#' rank deficient (`"rank_deficient"`) or has fewer than `min_neighbours`
#' neighbours (`"few_neighbours"`), when AICc is undefined
#' (`"aicc_undefined"`: n - 2 - tr(S) <= 0, where the formula would give
#' spuriously low values) or when a LOO residual is undefined
#' (`"loo_undefined"`: s_ii = 1). Infeasible bandwidths are kept in the
#' profile and never selected. Ties of the criterion are resolved by the
#' smallest bandwidth. The search is deterministic.
#'
#' Flags (object scope): `EF_GWR_BW_AT_BOUND` (the best grid value is at a
#' search bound; it is returned, not extrapolated), `EF_GWR_BW_MULTIMODAL`
#' (more than one local minimum among the feasible grid values),
#' `EF_GWR_AICC_UNDEFINED` (criterion AICc undefined in part of the
#' interval) and `EF_GWR_GLOBAL_PREFERRED` (the global OLS model has a
#' criterion not larger than the selected bandwidth; the finite optimum is
#' still returned). Excluded stations: `EF_GWR_STATION_EXCLUDED` (record).
#'
#' Errors: `earthflux_gwr_insufficient_stations` (n < p + 3),
#' `earthflux_gwr_no_feasible_bandwidth` (field `profile`),
#' `earthflux_missing_input` (a search setting needed and not given),
#' `earthflux_unknown_method` (kernel or criterion).
#'
#' @section AICc conventions and other implementations:
#' Three different quantities are called "AICc" for the same fit by GWR
#' software (dev/specs/gwr-forcing.md section 4.2). EarthFlux uses n = number
#' of stations of the fit, \eqn{\hat\sigma}{sigma} the maximum likelihood
#' estimate sqrt(RSS/n) and tr(S) (`aicc_definition =
#' "gollini2015_tr_S_sigma_ml"`). This is exactly `GW.diagnostic$AICc` of
#' `GWmodel` 2.4-1, checked in the tests. `GWmodel` reports as `enp` the
#' quantity 2 tr(S) - tr(S'S) (EarthFlux `enp_alt`), although its AICc uses
#' tr(S). Algebraically, with K = tr(S) + 1, the penalty
#' n (n + tr S)/(n - 2 - tr S) equals n + 2K + 2K(K + 1)/(n - K - 1): a
#' Gaussian AIC with K parameters plus a small-sample correction.
#'
#' @section Verification status:
#' AICc form: `VERIFICADA` as content of Gollini et al. (2015; preprint
#' arXiv:1306.0413v2, section 6.1, p. 20), who attribute it to Hurvich and
#' Simonoff (Hurvich, Simonoff & Tsai, 1998; not read); sigma is not
#' specified there. As an EarthFlux definition: `CANDIDATA (corroborada)`,
#' reproduced by `GWmodel`. LOOCV: `CANDIDATA (corroborada)`. The search
#' (log grid plus Brent refinement; exhaustive search over k) is a design
#' choice; its settings have no default (GW-05).
#'
#' @references
#' Gollini, I., Lu, B., Charlton, M., Brunsdon, C., & Harris, P. (2015).
#' GWmodel: An R package for exploring spatial heterogeneity using
#' geographically weighted models. *Journal of Statistical Software*,
#' 63(17). \doi{10.18637/jss.v063.i17}
#'
#' Hurvich, C. M., Simonoff, J. S., & Tsai, C.-L. (1998). Smoothing
#' parameter selection in nonparametric regression using an improved Akaike
#' information criterion. *Journal of the Royal Statistical Society: Series
#' B*, 60(2), 271-293. \doi{10.1111/1467-9868.00125}
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' coords <- cbind(c(0, 10000, 0, 10000, 20000, 30000, 25000, 5000),
#'                 c(0, 0, 10000, 10000, 0, 30000, 15000, 25000))
#' elev <- cbind(elevation = c(100, 300, 500, 200, 800, 1200, 650, 900))
#' ta <- c(20.0, 18.9, 17.5, 19.6, 15.4, 13.1, 16.2, 14.6)
#' bw <- ef_gwr_bandwidth(ta, elev, coords, kernel = "gaussian",
#'                        criterion = "AICc",
#'                        search = ef_gwr_search(n_grid = 20, tol = 10,
#'                                               upper_factor = 2))
#' bw
#' fit <- ef_gwr_fit(ta, elev, coords, bandwidth = bw)
ef_gwr_bandwidth <- function(y, x, coords, kernel, adaptive = FALSE,
                             criterion, search, scale_covariates = TRUE,
                             station_id = NULL) {
  call <- sys.call()
  check_method(kernel, gwr_kernels(), arg = "kernel", call = call)
  check_method(criterion, gwr_criteria(), arg = "criterion", call = call)
  if (missing(search) || !inherits(search, "earthflux_gwr_search")) {
    ef_abort(
      "`search` must be supplied explicitly, as returned by `ef_gwr_search()`.",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  check_flag_scalar(adaptive, "adaptive", call)
  check_flag_scalar(scale_covariates, "scale_covariates", call)
  prep <- gwr_prepare(y, x, coords, station_id, call)
  data <- gwr_used_data(prep, call)
  nb <- gwr_min_neighbours(search$min_neighbours, data$p, data$n, call)
  ctx <- gwr_context(data, kernel, adaptive, scale_covariates)
  res <- gwr_resolve_search(search, ctx, nb, call)

  sel <- if (adaptive) {
    gwr_profile_adaptive(ctx, res, nb$value, criterion)
  } else {
    gwr_profile_fixed(ctx, res, nb$value, criterion)
  }
  glob <- gwr_evaluate(ctx, Inf, nb$value, criterion)
  glob$stage <- "global"
  prof <- rbind(sel$profile, glob)
  rownames(prof) <- NULL
  res$n_evaluations <- nrow(prof)

  if (is.na(sel$best)) {
    gwr_abort(
      sprintf(
        paste0("No feasible bandwidth in the search interval (%d ",
               "evaluations); see the `profile` field of the condition."),
        nrow(sel$profile)
      ),
      class = "earthflux_gwr_no_feasible_bandwidth",
      profile = prof, call = call
    )
  }
  best <- sel$profile[sel$best, ]
  grid <- sel$profile[sel$profile$stage == "grid", , drop = FALSE]
  undefined <- any(!is.na(sel$profile$enp) &
                     ctx$n - 2 - sel$profile$enp <= 0)
  global_pref <- !is.na(glob$criterion) && glob$criterion <= best$criterion

  masks <- list(
    EF_GWR_BW_AT_BOUND = sel$at_bound,
    EF_GWR_BW_MULTIMODAL =
      gwr_count_minima(grid$criterion, grid$feasible) > 1L,
    EF_GWR_AICC_UNDEFINED = undefined,
    EF_GWR_GLOBAL_PREFERRED = global_pref
  )
  # AICc feasibility is evaluated only when AICc is the criterion
  if (criterion != "AICc") masks$EF_GWR_AICC_UNDEFINED <- NULL
  fl <- ef_flags_combine(
    ef_flag_set(masks, scope = "object"),
    ef_flag_set(list(EF_GWR_STATION_EXCLUDED = !prep$used), scope = "record")
  )

  out <- list(
    value = if (adaptive) as.integer(best$bandwidth) else best$bandwidth,
    type = if (adaptive) "adaptive" else "fixed",
    unit = if (adaptive) "neighbours" else "m",
    kernel = kernel,
    criterion = criterion,
    criterion_value = best$criterion,
    global = list(criterion = glob$criterion, aicc = glob$aicc, cv = glob$cv),
    profile = prof,
    search = res,
    stations = data.frame(
      station_id = prep$id,
      status = ifelse(prep$used, "used", "excluded"),
      exclusion_reason = prep$reason,
      stringsAsFactors = FALSE
    ),
    flags = fl$flags,
    provenance = list(
      call = call,
      n = ctx$n, p = ctx$p,
      scale_covariates = scale_covariates,
      conventions = gwr_conventions(kernel, scale_covariates),
      package_version = as.character(getNamespaceVersion("EarthFlux")),
      flags_evaluated = fl$evaluated
    )
  )
  new_ef_object(out, "earthflux_gwr_bandwidth")
}

#' @export
print.earthflux_gwr_bandwidth <- function(x, ...) {
  cat("<earthflux_gwr_bandwidth>\n")
  cat(sprintf("Kernel: %s; %s bandwidth = %s %s\n", x$kernel, x$type,
              format(x$value, digits = 8), x$unit))
  cat(sprintf("Criterion: %s = %s (global OLS: %s)\n", x$criterion,
              format(x$criterion_value, digits = 8),
              format(x$global$criterion, digits = 8)))
  s <- x$search
  if (x$type == "fixed") {
    cat(sprintf("Search: [%s, %s] m, %d grid values, tol = %s m; %d evaluations\n",
                format(s$lower, digits = 8), format(s$upper, digits = 8),
                s$n_grid, format(s$tol), s$n_evaluations))
  } else {
    cat(sprintf("Search: k in [%d, %d] (exhaustive); %d evaluations\n",
                s$k_min, s$k_max, s$n_evaluations))
  }
  cat(sprintf("Minimum neighbours: %d (%s); feasible evaluations: %d of %d\n",
              s$min_neighbours, s$min_neighbours_source,
              sum(x$profile$feasible), nrow(x$profile)))
  gwr_print_flags(x$flags)
  invisible(x)
}
