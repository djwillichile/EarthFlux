# Spatial forcing: comparison configurations C1 and C2 ----------------------------
#
# Purpose: the reference regionalizations against which GWR (C3) is compared
#   (dev/VALIDATION_PLAN.md section 2.2): C1, a representative station
#   (constant surface, or with an explicit lapse rate for air temperature),
#   and C2, the global ordinary least squares regression on the same
#   covariates as GWR and inverse distance weighting. Each one has the three
#   operations of the common interface (dev/specs/gwr-forcing.md section
#   5.1): fit at the stations with leave-one-out residuals, prediction at
#   new locations (row by row, so that the result does not depend on the
#   block size) and diagnostics. They are internal: the user reaches them
#   through ef_regionalize() and ef_regionalize_cv() with ef_method_*()
#   (decision GW-22: own file, they are not GWR).
#
# Specification: dev/specs/gwr-forcing.md sections 5.2-5.4 and 8.1.

# C2: global ordinary least squares ------------------------------------------------

#' Fit the global regression at the stations
#'
#' @param st Stations of the fit (`id`, `y`, `x`, `coords`).
#' @param call The call to report.
#' @return An object of class `earthflux_ols`.
#' @noRd
rgn_ols_fit <- function(st, call) {
  x <- st$x
  n <- length(st$y)
  p <- ncol(x) + 1L
  if (ncol(x) == 0L) {
    ef_abort("The global regression needs at least one covariate layer.",
             class = "earthflux_input_error", call = call)
  }
  if (n < p + 1L) {
    gwr_abort(
      sprintf(
        paste0("The global regression needs at least p + 1 = %d stations ",
               "(p = %d coefficients); found %d."),
        p + 1L, p, n
      ),
      class = "earthflux_gwr_insufficient_stations", n = n, p = p,
      call = call
    )
  }
  rgn_check_constant(x, call)
  scaling <- gwr_scale_design(x, TRUE)
  xs <- gwr_design(x, scaling)
  q <- qr(xs)
  if (q$rank < p) {
    ef_abort("The covariates are collinear among the stations of the fit.",
             class = "earthflux_input_error", call = call)
  }
  beta <- qr.coef(q, st$y)
  fitted <- rowSums(xs * rep(beta, each = n))
  e <- st$y - fitted
  h <- rowSums(qr.Q(q)^2)
  e_loo <- ifelse(1 - h > gwr_tolerances()$loo, e / (1 - h), NA_real_)
  rss <- sum(e^2)
  tss <- sum((st$y - mean(st$y))^2)
  cv <- gwr_cv_score(e_loo)
  coef <- gwr_unscale_coef(matrix(beta, 1L), scaling)[1L, ]

  stations <- data.frame(station_id = st$id, x = st$coords[, 1L],
                         y = st$coords[, 2L], stringsAsFactors = FALSE)
  for (nm in colnames(x)) stations[[nm]] <- x[, nm]
  stations$observed <- st$y
  stations$fitted <- fitted
  stations$residual <- e
  stations$loo_fitted <- st$y - e_loo
  stations$loo_residual <- e_loo
  stations$h_ii <- h

  out <- list(
    method = "global_ols",
    coefficients = coef,
    stations = stations,
    fit = list(n = n, p = p, rss = rss, sigma_ml = sqrt(rss / n), enp = p,
               aicc = gwr_aicc(rss, p, n), cv = cv,
               rmse_loo = if (is.na(cv)) NA_real_ else sqrt(cv / n),
               r2 = 1 - rss / tss),
    model = list(station_id = st$id, y = st$y, x = x, coords = st$coords,
                 scaling = scaling, beta = beta,
                 covariate_range = rbind(min = apply(x, 2L, min),
                                         max = apply(x, 2L, max)),
                 hull = gwr_convex_hull(st$coords)),
    flags = list(),
    provenance = list(
      method = "global_ols",
      conventions = list(covariate_scaling = "center_sd", solver = "qr",
                         loo = "hat_diagonal", loo_tol = gwr_tolerances()$loo,
                         aicc_definition = "gollini2015_tr_S_sigma_ml",
                         enp = "p"),
      flags_evaluated = character(0)
    )
  )
  new_ef_object(out, "earthflux_ols")
}

#' Covariates constant among the stations of a fit
#'
#' @param x Covariate matrix of the stations.
#' @param call The call to report.
#' @return `TRUE`, invisibly; `earthflux_input_error` otherwise.
#' @noRd
rgn_check_constant <- function(x, call) {
  constant <- colnames(x)[apply(x, 2L, function(v) max(v) == min(v))]
  if (length(constant) > 0L) {
    ef_abort(
      sprintf(
        paste0("Covariate(s) %s are constant among the stations of the fit; ",
               "the global design is singular."),
        paste0("`", constant, "`", collapse = ", ")
      ),
      class = "earthflux_input_error", covariate = constant, call = call
    )
  }
  invisible(TRUE)
}

#' Predict the global regression at new locations
#'
#' @param fit An `earthflux_ols` object.
#' @param newx Covariates (complete rows).
#' @param newcoords Coordinates \[m\].
#' @param bits Named bits of the GWR stage.
#' @return A list with `value` and `word` (covariate range and convex hull
#'   conditions).
#' @noRd
rgn_ols_predict <- function(fit, newx, newcoords, bits) {
  mod <- fit$model
  newx <- newx[, colnames(mod$x), drop = FALSE]
  m <- nrow(newx)
  xg <- gwr_design(newx, mod$scaling)
  value <- rowSums(xg * rep(mod$beta, each = m))
  ext <- gwr_extrapolation_flags(newx, newcoords, fit, rep(FALSE, m))
  list(value = value,
       word = rgn_mask_word(list(EF_GWR_EXTRAPOLATION_COVARIATE = ext$covariate,
                                 EF_GWR_OUTSIDE_HULL = ext$hull), m, bits))
}

# C2: inverse distance weighting ------------------------------------------------------

#' Inverse distance weighted values
#'
#' @param d Matrix of scaled distances (rows = locations, columns =
#'   stations); `Inf` removes a station (leave-one-out).
#' @param y Values of the stations.
#' @param power The power q.
#' @return Numeric vector: weighted mean with weights d^-q, or the mean of
#'   the stations at distance 0 where there are any.
#' @noRd
rgn_idw_values <- function(d, y, power) {
  m <- nrow(d)
  yy <- rep(y, each = m)
  zero <- d == 0
  w <- d^(-power)
  w[zero] <- 0
  value <- rowSums(w * yy) / rowSums(w)
  at <- rowSums(zero) > 0L
  if (any(at)) {
    z <- zero[at, , drop = FALSE]
    value[at] <- rowSums(z * rep(y, each = sum(at))) / rowSums(z)
  }
  value
}

#' Fit inverse distance weighting at the stations
#'
#' @param st Stations of the fit.
#' @param power Power(s) q; several values: selection by LOOCV.
#' @param call The call to report.
#' @return An object of class `earthflux_idw`.
#' @noRd
rgn_idw_fit <- function(st, power, call) {
  n <- length(st$y)
  if (n < 2L) {
    gwr_abort(
      sprintf("IDW needs at least 2 stations; found %d.", n),
      class = "earthflux_gwr_insufficient_stations", n = n, p = NA_integer_,
      call = call
    )
  }
  d <- gwr_distance(st$coords, st$coords)
  dref <- max(d)
  if (!(dref > 0)) {
    ef_abort("All stations of the fit have the same coordinates.",
             class = "earthflux_input_error", call = call)
  }
  d <- d / dref
  d_loo <- d
  diag(d_loo) <- Inf
  profile <- data.frame(power = power, cv = NA_real_)
  loo <- vector("list", length(power))
  for (i in seq_along(power)) {
    loo[[i]] <- rgn_idw_values(d_loo, st$y, power[i])
    profile$cv[i] <- gwr_cv_score(st$y - loo[[i]])
  }
  best <- which.min(profile$cv)
  q <- power[best]
  fitted <- rgn_idw_values(d, st$y, q)
  e_loo <- st$y - loo[[best]]

  stations <- data.frame(station_id = st$id, x = st$coords[, 1L],
                         y = st$coords[, 2L], observed = st$y,
                         fitted = fitted, residual = st$y - fitted,
                         loo_fitted = loo[[best]], loo_residual = e_loo,
                         stringsAsFactors = FALSE)
  cv <- profile$cv[best]
  out <- list(
    method = "idw",
    power = q,
    power_selected_by = if (length(power) > 1L) "CV" else "user",
    profile = if (length(power) > 1L) profile else NULL,
    stations = stations,
    fit = list(n = n, cv = cv, rmse_loo = sqrt(cv / n)),
    model = list(station_id = st$id, y = st$y, coords = st$coords,
                 dref = dref, hull = gwr_convex_hull(st$coords)),
    flags = list(),
    provenance = list(
      method = "idw",
      conventions = list(distance_method = "euclidean_projected",
                         distance_scale = "max_station_distance",
                         coincident = "mean_of_coincident_stations",
                         ties = "smallest_power"),
      flags_evaluated = character(0)
    )
  )
  new_ef_object(out, "earthflux_idw")
}

#' Predict inverse distance weighting at new locations
#'
#' @param fit An `earthflux_idw` object.
#' @param newcoords Coordinates \[m\].
#' @param bits Named bits of the GWR stage.
#' @return A list with `value` and `word` (convex hull condition).
#' @noRd
rgn_idw_predict <- function(fit, newcoords, bits) {
  mod <- fit$model
  d <- gwr_distance(newcoords, mod$coords) / mod$dref
  value <- rgn_idw_values(d, mod$y, fit$power)
  outside <- !gwr_in_hull(newcoords, mod$hull, mod$coords)
  list(value = value,
       word = rgn_mask_word(list(EF_GWR_OUTSIDE_HULL = outside),
                            nrow(newcoords), bits))
}

# C1: representative station -----------------------------------------------------------

#' Fit the representative station configuration
#'
#' @param st Stations of the fit (`x` holds `elevation` for the lapse-rate
#'   variant).
#' @param method A `"station"` or `"station_lapse"` method object.
#' @param call The call to report.
#' @return An object of class `earthflux_station_forcing`.
#' @noRd
rgn_station_fit <- function(st, method, call) {
  s <- match(method$station_id, st$id)
  if (is.na(s)) {
    ef_abort(
      sprintf(
        paste0("The representative station `%s` has no usable value in this ",
               "fit (excluded by QC, by the user or by a missing value)."),
        method$station_id
      ),
      class = "earthflux_input_error", station_id = method$station_id,
      call = call
    )
  }
  n <- length(st$y)
  value <- st$y[s]
  lapse <- method$lapse_rate
  z_s <- NULL
  pred <- rep(value, n)
  if (!is.null(lapse)) {
    z_s <- unname(st$x[s, "elevation"])
    pred <- value + lapse * (st$x[, "elevation"] - z_s)
  }
  rep_st <- seq_len(n) == s
  loo <- ifelse(rep_st, NA_real_, pred)
  stations <- data.frame(station_id = st$id, x = st$coords[, 1L],
                         y = st$coords[, 2L], stringsAsFactors = FALSE)
  for (nm in colnames(st$x)) stations[[nm]] <- st$x[, nm]
  stations$observed <- st$y
  stations$fitted <- pred
  stations$residual <- st$y - pred
  stations$loo_fitted <- loo
  stations$loo_residual <- st$y - loo
  stations$representative <- rep_st
  e <- stations$loo_residual[!rep_st]
  fl <- ef_flags_combine(
    ef_flag_set(list(EF_GWR_SINGLE_STATION = TRUE), scope = "object")
  )
  out <- list(
    method = method$method,
    station_id = method$station_id,
    value = value,
    lapse_rate = lapse,
    elevation_station = z_s,
    stations = stations,
    fit = list(n = n, n_evaluated = length(e),
               cv = if (length(e) > 0L) sum(e^2) else NA_real_,
               rmse_loo = if (length(e) > 0L) sqrt(mean(e^2)) else NA_real_),
    model = list(value = value, lapse_rate = lapse, elevation_station = z_s),
    flags = fl$flags,
    provenance = list(
      method = method$method,
      lapse_rate_source = if (is.null(lapse)) NULL else "user",
      flags_evaluated = fl$evaluated
    )
  )
  new_ef_object(out, "earthflux_station_forcing")
}

#' Predict the representative station configuration
#'
#' @param fit An `earthflux_station_forcing` object.
#' @param newx Covariates (`elevation` for the lapse-rate variant).
#' @param m Number of locations.
#' @return A list with `value` and `word` (no condition of its own).
#' @noRd
rgn_station_predict <- function(fit, newx, m) {
  mod <- fit$model
  value <- if (is.null(mod$lapse_rate)) {
    rep(mod$value, m)
  } else {
    mod$value + mod$lapse_rate * (newx[, "elevation"] - mod$elevation_station)
  }
  list(value = value, word = integer(m))
}
