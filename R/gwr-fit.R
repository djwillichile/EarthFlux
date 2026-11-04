# Spatial forcing: GWR model fitting --------------------------------------------
#
# Purpose: internal numeric core of geographically weighted regression (GWR)
#   used to regionalize meteorological variables (response) on spatial
#   covariates (e.g. elevation). The core works on plain numeric vectors and
#   matrices: response `y`, covariate matrix `x` and projected coordinates
#   `coords` in metres. It knows nothing about METRIC, rasters or terra; the
#   orchestrator (`ef_regionalize()`, later phase) projects, extracts and
#   writes blocks on top of this API.
#
# Specification: dev/specs/gwr-forcing.md sections 3 (model), 4 (bandwidth),
#   6.1/6.3/6.4 (prediction), 7 (object), 9 (functions, errors, NA) and 10
#   (numeric cases G1a-G7). Backend decision: dev/decisions/gwr-backend.md
#   (DECIDIDA: internal core in base R; GWmodel only in Suggests as the
#   cross-verification reference of the tests).
#
# Files of the module:
#   gwr-fit.R          ef_gwr_fit(), data checks, kernels, local WLS solver,
#                      hat statistics, earthflux_gwr object and its methods
#   gwr-bandwidth.R    ef_gwr_search(), ef_gwr_bandwidth(), AICc and CV,
#                      profile and refinement
#   gwr-predict.R      ef_gwr_predict(), block prediction, extrapolation
#                      flags, convex hull
#   gwr-diagnostics.R  ef_gwr_diagnostics(), local R2, condition number,
#                      ef_flags_gwr() (EF_GWR_* registry rows)
#
# Numerical solution (spec section 3.7): every local weighted least squares
#   problem is solved from its moments X'WX and X'Wy with a Cholesky
#   factorisation vectorised over the regression points, on internally
#   scaled covariates (centred and divided by their standard deviation over
#   the stations of the fit). Weighted sums are computed with rowSums(), so
#   the result at a regression point does not depend on the other points of
#   the same call (prediction is independent of the block size). A QR
#   reference solver (gwr_local_wls()) is kept for the tests.

# Conventions and constants ------------------------------------------------------

#' Kernels of the GWR core
#'
#' @return Character vector of the accepted kernel names
#'   (dev/specs/gwr-forcing.md section 3.4).
#' @noRd
gwr_kernels <- function() {
  c("gaussian", "exponential", "bisquare", "tricube", "boxcar")
}

#' Kernels with compact support
#'
#' @return Character vector: kernels whose weight is zero beyond the
#'   bandwidth.
#' @noRd
gwr_compact_kernels <- function() {
  c("bisquare", "tricube", "boxcar")
}

#' Numerical tolerances of the GWR core
#'
#' Numerical conventions, not scientific constants; they are recorded in the
#' `conventions` element of every fitted object.
#'
#' * `rank`: a local design is rank deficient when a pivot of the Cholesky
#'   factorisation of the (scaled) moment matrix is not larger than `rank`
#'   times its diagonal element, i.e. when a column of the weighted design
#'   is, up to a relative squared residual of `rank`, a combination of the
#'   previous ones.
#' * `loo`: the leave-one-out residual is undefined when `1 - s_ii` is not
#'   larger than `loo` (the fit interpolates the station).
#' * `hull`: distance tolerance, relative to the extent of the stations,
#'   below which a point on the boundary of the convex hull is inside it.
#'
#' @return A named list.
#' @noRd
gwr_tolerances <- function() {
  list(rank = 1e-10, loo = 1e-10, hull = 1e-9)
}

#' Conventions recorded in a fitted GWR object
#'
#' @param kernel Character. Kernel name.
#' @param scale_covariates Logical.
#' @return A named list (dev/specs/gwr-forcing.md section 7.1).
#' @noRd
gwr_conventions <- function(kernel, scale_covariates) {
  tol <- gwr_tolerances()
  list(
    k_convention = "kth_nearest_including_self",
    boxcar_support = "le",
    aicc_definition = "gollini2015_tr_S_sigma_ml",
    sigma_aicc = "ml",
    enp = "tr_S",
    local_r2_convention = "local_fit_weighted_mean",
    loo_convention = "zero_own_weight",
    neighbour_count = if (kernel %in% gwr_compact_kernels()) {
      "nonzero_weight"
    } else {
      "within_bandwidth"
    },
    distance_method = "euclidean_projected",
    covariate_scaling = if (scale_covariates) "center_sd" else "none",
    solver = "moments_cholesky",
    rank_tol = tol$rank,
    loo_tol = tol$loo
  )
}

# Conditions -----------------------------------------------------------------------

#' Signal a GWR error of a specific subclass
#'
#' Subclasses (dev/specs/gwr-forcing.md section 9.3) all inherit
#' `earthflux_gwr_error` and then `earthflux_error`:
#' `earthflux_gwr_insufficient_stations` (fields `n`, `p`),
#' `earthflux_gwr_no_feasible_bandwidth` (field `profile`) and
#' `earthflux_gwr_singular_error` (field `stations`).
#'
#' @param message Character.
#' @param class Character. The specific subclass.
#' @param ... Data fields of the condition.
#' @param call The call to report.
#' @return Never returns.
#' @noRd
gwr_abort <- function(message, class, ..., call = sys.call(-1)) {
  ef_abort(message, class = c(class, "earthflux_gwr_error"), ...,
           call = call)
}

# Input preparation -------------------------------------------------------------------

#' Validate and prepare the data of a GWR fit
#'
#' Checks types and dimensions, rejects infinite values and excludes (never
#' silently) the stations with a missing response, covariate or coordinate,
#' recording the reason (dev/specs/gwr-forcing.md section 9.4).
#'
#' @param y,x,coords,station_id See [ef_gwr_fit()].
#' @param call The call to report.
#' @return A list with `id` (character), `y`, `x` (matrix with column
#'   names), `coords` (n x 2 matrix) for all stations, `used` (logical) and
#'   `reason` (character, `NA` for used stations).
#' @noRd
gwr_prepare <- function(y, x, coords, station_id, call) {
  check_numeric(y, "y", call = call)
  if (!is.null(dim(y)) && length(dim(y)) > 1L) {
    ef_abort("`y` must be a numeric vector (one value per station).",
             class = "earthflux_input_error", call = call)
  }
  n <- length(y)
  if (n == 0L) {
    ef_abort("`y` must not be empty.", class = "earthflux_input_error",
             call = call)
  }
  x <- gwr_as_matrix(x, "x", call)
  coords <- gwr_as_coords(coords, "coords", call)
  if (nrow(x) != n || nrow(coords) != n) {
    ef_abort(
      sprintf(
        paste0("`x` and `coords` must have one row per element of `y` ",
               "(%d); found %d and %d rows."),
        n, nrow(x), nrow(coords)
      ),
      class = "earthflux_input_error", call = call
    )
  }
  check_in_range(y, "y", call = call)
  check_in_range(x, "x", call = call)
  check_in_range(coords, "coords", call = call)

  id <- gwr_station_id(station_id, y, x, n, call)

  reason <- rep(NA_character_, n)
  add_reason <- function(reason, mask, what) {
    reason[mask] <- ifelse(is.na(reason[mask]), what,
                           paste(reason[mask], what, sep = "; "))
    reason
  }
  reason <- add_reason(reason, rowSums(is.na(coords)) > 0L,
                       "missing_coordinates")
  reason <- add_reason(reason, is.na(y), "missing_response")
  for (nm in colnames(x)) {
    reason <- add_reason(reason, is.na(x[, nm]),
                         paste0("missing_covariate:", nm))
  }
  list(id = id, y = as.numeric(y), x = x, coords = coords,
       used = is.na(reason), reason = reason)
}

#' Coerce and check a covariate matrix
#'
#' @param x A numeric matrix or a data frame of numeric columns, with unique
#'   non-empty column names.
#' @param arg Argument name.
#' @param call The call to report.
#' @return A numeric matrix with column names.
#' @noRd
gwr_as_matrix <- function(x, arg, call) {
  if (is.data.frame(x)) {
    if (!all(vapply(x, is.numeric, logical(1)))) {
      ef_abort(sprintf("All columns of `%s` must be numeric.", arg),
               class = "earthflux_input_error", call = call)
    }
    x <- as.matrix(x)
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    ef_abort(
      sprintf("`%s` must be a numeric matrix (or data frame) of covariates.",
              arg),
      class = "earthflux_input_error", call = call
    )
  }
  nms <- colnames(x)
  if (ncol(x) == 0L || is.null(nms) || anyNA(nms) || any(!nzchar(nms)) ||
      anyDuplicated(nms) > 0L) {
    ef_abort(
      sprintf(
        "`%s` must have at least one column, with unique non-empty names.",
        arg
      ),
      class = "earthflux_input_error", call = call
    )
  }
  reserved <- c("(Intercept)", gwr_station_columns())
  clash <- intersect(nms, reserved)
  if (length(clash) > 0L) {
    ef_abort(
      sprintf("Covariate names must not be %s.",
              paste0("`", clash, "`", collapse = ", ")),
      class = "earthflux_input_error", call = call
    )
  }
  storage.mode(x) <- "double"
  x
}

#' Coerce and check a coordinate matrix
#'
#' @param coords A numeric matrix or data frame with two columns (x, y)
#'   \[m\] in a projected CRS.
#' @param arg Argument name.
#' @param call The call to report.
#' @return A numeric matrix with two columns.
#' @noRd
gwr_as_coords <- function(coords, arg, call) {
  if (is.data.frame(coords)) {
    if (!all(vapply(coords, is.numeric, logical(1)))) {
      ef_abort(sprintf("All columns of `%s` must be numeric.", arg),
               class = "earthflux_input_error", call = call)
    }
    coords <- as.matrix(coords)
  }
  if (!is.matrix(coords) || !is.numeric(coords) || ncol(coords) != 2L) {
    ef_abort(
      sprintf(
        "`%s` must be a numeric matrix with two columns (x, y) in metres.",
        arg
      ),
      class = "earthflux_input_error", call = call
    )
  }
  storage.mode(coords) <- "double"
  dimnames(coords) <- NULL
  coords
}

#' Resolve station identifiers
#'
#' @param station_id `NULL` or a vector of unique, non-missing identifiers.
#' @param y,x The response and covariates (names used when `station_id` is
#'   `NULL`).
#' @param n Number of stations.
#' @param call The call to report.
#' @return A character vector of length `n`.
#' @noRd
gwr_station_id <- function(station_id, y, x, n, call) {
  if (is.null(station_id)) {
    station_id <- names(y)
    if (is.null(station_id)) station_id <- rownames(x)
    if (is.null(station_id)) station_id <- seq_len(n)
  }
  station_id <- as.character(station_id)
  if (length(station_id) != n || anyNA(station_id) ||
      any(!nzchar(station_id)) || anyDuplicated(station_id) > 0L) {
    ef_abort(
      sprintf(
        "`station_id` must have %d unique, non-missing, non-empty values.", n
      ),
      class = "earthflux_input_error", call = call
    )
  }
  station_id
}

#' Reserved column names of the station table
#'
#' @return Character vector.
#' @noRd
gwr_station_columns <- function() {
  c("station_id", "x", "y", "observed", "fitted", "residual", "loo_fitted",
    "loo_residual", "s_ii", "local_r2", "bandwidth_i", "n_nonzero", "kappa",
    "rank_ok", "status", "exclusion_reason")
}

#' Check the design of the stations used in a fit
#'
#' @param prep The list returned by `gwr_prepare()`.
#' @param call The call to report.
#' @return `prep$used`-subset data: a list with `id`, `y`, `x`, `coords`,
#'   `n` and `p`. Errors: `earthflux_gwr_insufficient_stations` when
#'   n < p + 3; `earthflux_input_error` for a covariate that is constant
#'   among the stations, or for stations with identical coordinates and
#'   covariates (degenerate local design).
#' @noRd
gwr_used_data <- function(prep, call) {
  u <- prep$used
  x <- prep$x[u, , drop = FALSE]
  coords <- prep$coords[u, , drop = FALSE]
  n <- sum(u)
  p <- ncol(x) + 1L
  if (n < p + 3L) {
    gwr_abort(
      sprintf(
        paste0("GWR needs at least p + 3 = %d stations with complete data ",
               "(p = %d coefficients); found %d."),
        p + 3L, p, n
      ),
      class = "earthflux_gwr_insufficient_stations",
      n = n, p = p, call = call
    )
  }
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
  key <- duplicated(cbind(coords, x))
  if (any(key)) {
    ef_abort(
      sprintf(
        paste0("Stations with identical coordinates and covariates give a ",
               "degenerate local design; duplicated: %s."),
        paste(prep$id[u][key], collapse = ", ")
      ),
      class = "earthflux_input_error", call = call
    )
  }
  list(id = prep$id[u], y = prep$y[u], x = x, coords = coords, n = n, p = p)
}

# Scaling of the design ---------------------------------------------------------------

#' Scale the covariates of the design
#'
#' Centres each covariate and divides it by its standard deviation over the
#' stations of the fit (dev/specs/gwr-forcing.md section 3.7), so that the
#' local moment matrices are well conditioned. With `scale = FALSE` the
#' design is used as given (centre 0, scale 1).
#'
#' @param x Covariate matrix of the stations of the fit.
#' @param scale Logical.
#' @return A list with `center` and `scale` (named numeric vectors).
#' @noRd
gwr_scale_design <- function(x, scale) {
  if (scale) {
    center <- colMeans(x)
    sds <- apply(x, 2L, stats::sd)
  } else {
    center <- stats::setNames(rep(0, ncol(x)), colnames(x))
    sds <- stats::setNames(rep(1, ncol(x)), colnames(x))
  }
  list(center = center, scale = sds)
}

#' Scaled design matrix with intercept
#'
#' @param x Covariate matrix.
#' @param scaling The list returned by `gwr_scale_design()`.
#' @return A matrix with an intercept column followed by the scaled
#'   covariates.
#' @noRd
gwr_design <- function(x, scaling) {
  xs <- sweep(sweep(x, 2L, scaling$center, "-"), 2L, scaling$scale, "/")
  cbind(1, xs)
}

#' Back-transform local coefficients to the original units
#'
#' Exact for a linear model: \eqn{\beta_k = \beta^s_k / s_k} and
#' \eqn{\beta_0 = \beta^s_0 - \sum_k \beta^s_k c_k / s_k}.
#'
#' @param beta Matrix of coefficients in the scaled design (rows = points).
#' @param scaling The list returned by `gwr_scale_design()`.
#' @return Matrix of coefficients in the units of the response and of each
#'   covariate, with column names `(Intercept)` and the covariates.
#' @noRd
gwr_unscale_coef <- function(beta, scaling) {
  slope <- sweep(beta[, -1L, drop = FALSE], 2L, scaling$scale, "/")
  # Row-wise sum with rowSums() instead of `%*%`: a BLAS matrix product may
  # round differently depending on the number of rows (optimised BLAS
  # kernels), which would make the coefficients depend on the block size of
  # the prediction (dev/specs/parallel-processing.md, rule 2).
  intercept <- beta[, 1L] -
    rowSums(slope * rep(scaling$center, each = nrow(slope)))
  out <- cbind(intercept, slope)
  colnames(out) <- c("(Intercept)", names(scaling$scale))
  out
}

# Distances, bandwidths and kernels --------------------------------------------------

#' Euclidean distances between points of a projected CRS
#'
#' @param from Matrix m x 2 of regression points \[m\].
#' @param to Matrix n x 2 of stations \[m\].
#' @param method Character. Only `"euclidean_projected"` (decision GW-09).
#' @return Matrix m x n of distances \[m\].
#' @noRd
gwr_distance <- function(from, to, method = "euclidean_projected") {
  dx <- outer(from[, 1L], to[, 1L], "-")
  dy <- outer(from[, 2L], to[, 2L], "-")
  sqrt(dx * dx + dy * dy)
}

#' Bandwidth of each regression point
#'
#' Fixed: \eqn{b_i = b}. Adaptive: \eqn{b_i} is the k-th smallest distance
#' from the regression point to the stations of the fit, counting the point
#' itself (distance 0) when it is a station (dev/specs/gwr-forcing.md
#' section 3.5).
#'
#' @param dist Matrix of distances (rows = regression points).
#' @param bandwidth Numeric: b \[m\] (fixed) or k (adaptive).
#' @param adaptive Logical.
#' @return Numeric vector, one bandwidth per row \[m\].
#' @noRd
gwr_row_bandwidth <- function(dist, bandwidth, adaptive) {
  if (!adaptive) {
    return(rep(bandwidth, nrow(dist)))
  }
  k <- as.integer(bandwidth)
  m <- nrow(dist)
  n <- ncol(dist)
  o <- order(rep.int(seq_len(m), n), dist, method = "radix")
  dist[o[(seq_len(m) - 1L) * n + k]]
}

#' Kernel weights
#'
#' With \eqn{r = d / b}: gaussian \eqn{\exp(-r^2/2)}, exponential
#' \eqn{\exp(-r)}, bisquare \eqn{(1 - r^2)^2} for \eqn{d < b}, tricube
#' \eqn{(1 - r^3)^3} for \eqn{d < b}, boxcar 1 for \eqn{d \le b} (decision
#' GW-03); 0 otherwise (dev/specs/gwr-forcing.md section 3.4).
#'
#' @param dist Matrix of distances \[m\] (rows = regression points).
#' @param b Numeric vector of row bandwidths \[m\] (length `nrow(dist)`).
#' @param kernel Character. One of `gwr_kernels()`.
#' @return Matrix of weights with the dimensions of `dist`.
#' @noRd
gwr_kernel_weights <- function(dist, b, kernel) {
  r <- dist / b
  w <- switch(kernel,
    gaussian = exp(-0.5 * r * r),
    exponential = exp(-r),
    bisquare = {
      v <- (1 - r * r)^2
      v[dist >= b] <- 0
      v
    },
    tricube = {
      v <- (1 - r * r * r)^3
      v[dist >= b] <- 0
      v
    },
    boxcar = {
      v <- r
      v[] <- as.numeric(dist <= b)
      v
    }
  )
  dim(w) <- dim(dist)
  w
}

#' Number of neighbours of each regression point
#'
#' Compact kernels: stations with a non-zero weight. Continuous kernels
#' (all weights non-zero): stations within one bandwidth, \eqn{d \le b_i}
#' (dev/specs/gwr-forcing.md section 4.5).
#'
#' @param dist,w Matrices of distances and weights.
#' @param b Row bandwidths.
#' @param kernel Character.
#' @return Integer vector.
#' @noRd
gwr_neighbours <- function(dist, w, b, kernel) {
  if (kernel %in% gwr_compact_kernels()) {
    as.integer(rowSums(w > 0))
  } else {
    as.integer(rowSums(dist <= b))
  }
}

# Local weighted least squares ----------------------------------------------------

#' Weighted sums over stations, independent of the other rows
#'
#' @param w Matrix m x n of weights.
#' @param z Matrix n x q of station quantities.
#' @return Matrix m x q with entries \eqn{\sum_j w_{ij} z_{jc}}. Each entry
#'   is computed with `colSums()` over the stations in a fixed order, so it
#'   does not depend on the other rows (block-size invariance, section 6.1).
#'   A BLAS matrix product would be faster but its summation order may
#'   depend on the dimensions of the block.
#' @noRd
gwr_wsum <- function(w, z) {
  m <- nrow(w)
  wt <- t(w)
  out <- vapply(seq_len(ncol(z)), function(cl) {
    colSums(wt * z[, cl])
  }, numeric(m))
  matrix(out, nrow = m)
}

#' Solve the local WLS problems of many regression points
#'
#' Moments \eqn{M_i = X^\top W_i X} and \eqn{X^\top W_i y} for every row of
#' `w`, Cholesky factorisation of \eqn{M_i} vectorised over the rows, and
#' \eqn{\hat\beta_i = M_i^{-1} X^\top W_i y} (dev/specs/gwr-forcing.md
#' sections 3.2 and 3.7). A pivot not larger than `gwr_tolerances()$rank`
#' times its diagonal element marks the local design as rank deficient.
#'
#' @param w Matrix m x n of weights.
#' @param xs Scaled design n x p (with intercept).
#' @param y Response of the stations.
#' @return A list with `beta` (m x p, `NA` rows where singular), `chol`
#'   (the factor, a list of lists of vectors) and `singular` (logical).
#' @noRd
gwr_local_solve <- function(w, xs, y) {
  p <- ncol(xs)
  m <- nrow(w)
  idx <- which(lower.tri(diag(p), diag = TRUE), arr.ind = TRUE)
  z <- cbind(xs[, idx[, 1L], drop = FALSE] * xs[, idx[, 2L], drop = FALSE],
             xs * y)
  sums <- gwr_wsum(w, z)
  mom <- matrix(list(), p, p)
  for (r in seq_len(nrow(idx))) {
    mom[[idx[r, 1L], idx[r, 2L]]] <- sums[, r]
  }
  xty <- lapply(seq_len(p), function(a) sums[, nrow(idx) + a])

  ch <- gwr_chol(mom, p, m)
  beta <- gwr_chol_solve(ch$l, xty, p)
  beta <- do.call(cbind, beta)
  beta[ch$singular, ] <- NA_real_
  list(beta = matrix(beta, nrow = m), chol = ch$l, singular = ch$singular)
}

#' Cholesky factorisation vectorised over regression points
#'
#' @param mom Lower triangle of the moment matrices: `mom[[a, b]]` (a >= b)
#'   is the vector of entries over the regression points.
#' @param p Number of coefficients.
#' @param m Number of regression points.
#' @return A list with `l` (lower factor, same layout as `mom`) and
#'   `singular` (logical, length `m`).
#' @noRd
gwr_chol <- function(mom, p, m) {
  tol <- gwr_tolerances()$rank
  l <- matrix(list(), p, p)
  singular <- rep(FALSE, m)
  for (j in seq_len(p)) {
    s <- mom[[j, j]]
    for (k in seq_len(j - 1L)) s <- s - l[[j, k]]^2
    ratio <- s / mom[[j, j]]
    bad <- is.na(ratio) | !(ratio > tol)
    singular <- singular | bad
    s[bad] <- NA_real_
    l[[j, j]] <- sqrt(s)
    if (j < p) {
      for (i in (j + 1L):p) {
        v <- mom[[i, j]]
        for (k in seq_len(j - 1L)) v <- v - l[[i, k]] * l[[j, k]]
        l[[i, j]] <- v / l[[j, j]]
      }
    }
  }
  list(l = l, singular = singular)
}

#' Solve with a vectorised Cholesky factor
#'
#' @param l Lower factor from `gwr_chol()`.
#' @param rhs List of p vectors (right-hand side over the regression
#'   points).
#' @param p Number of coefficients.
#' @return List of p vectors: the solution of \eqn{M c = rhs}.
#' @noRd
gwr_chol_solve <- function(l, rhs, p) {
  u <- vector("list", p)
  for (i in seq_len(p)) {
    v <- rhs[[i]]
    for (k in seq_len(i - 1L)) v <- v - l[[i, k]] * u[[k]]
    u[[i]] <- v / l[[i, i]]
  }
  out <- vector("list", p)
  for (i in rev(seq_len(p))) {
    v <- u[[i]]
    for (k in seq_len(p - i) + i) v <- v - l[[k, i]] * out[[k]]
    out[[i]] <- v / l[[i, i]]
  }
  out
}

#' Reference local WLS solution by QR
#'
#' QR decomposition of \eqn{W^{1/2}X} (dev/specs/gwr-forcing.md section
#' 3.7): reference against which the moment/Cholesky solver is tested.
#'
#' @param x Design matrix n x p (with intercept).
#' @param y Response.
#' @param w Weights of the regression point.
#' @param x0 Design row of the regression point (defaults to none).
#' @return A list with `beta`, `rank` and, when `x0` is given, `hat_row`
#'   (the row \eqn{x_0^\top (X^\top W X)^{-1} X^\top W} of the hat matrix).
#' @noRd
gwr_local_wls <- function(x, y, w, x0 = NULL) {
  sw <- sqrt(w)
  qa <- qr(sw * x)
  out <- list(beta = qr.coef(qa, sw * y), rank = qa$rank)
  if (!is.null(x0) && qa$rank == ncol(x)) {
    r <- qr.R(qa)
    a <- backsolve(r, x0[qa$pivot], transpose = TRUE)
    out$hat_row <- as.vector(qr.Q(qa) %*% a) * sw
  }
  out
}

#' Rank, condition number and neighbours of a local design
#'
#' The condition number is that of \eqn{W^{1/2}X} with the columns of the
#' design in original units scaled to unit length (a Belsley-type form;
#' Belsley et al., 1980, not read: CANDIDATA; dev/specs/gwr-forcing.md
#' section 3.7). Reported only; no threshold is applied (class II flag
#' `EF_GWR_ILL_CONDITIONED`).
#'
#' @param x Design matrix in original units (with intercept).
#' @param w Weights of the regression point.
#' @return A list with `rank`, `kappa` (`Inf` if rank deficient) and
#'   `n_nonzero` (weights > 0).
#' @noRd
gwr_check_design <- function(x, w) {
  a <- sqrt(w) * x
  norms <- sqrt(colSums(a * a))
  rank <- qr(a)$rank
  kappa <- if (all(norms > 0)) {
    d <- svd(sweep(a, 2L, norms, "/"), nu = 0L, nv = 0L)$d
    if (min(d) > 0) max(d) / min(d) else Inf
  } else {
    Inf
  }
  list(rank = rank, kappa = kappa, n_nonzero = sum(w > 0))
}

# Fit at the stations ---------------------------------------------------------------

#' Context of a GWR fit: data, design and distances
#'
#' @param data The list returned by `gwr_used_data()`.
#' @param kernel Character.
#' @param adaptive Logical.
#' @param scale_covariates Logical.
#' @return A list with the data, `scaling`, `xs` (scaled design), `xraw`
#'   (design in original units), `dist` (n x n) and `dist_sorted` (each row
#'   sorted increasingly).
#' @noRd
gwr_context <- function(data, kernel, adaptive, scale_covariates) {
  scaling <- gwr_scale_design(data$x, scale_covariates)
  dist <- gwr_distance(data$coords, data$coords)
  c(data, list(
    kernel = kernel,
    adaptive = adaptive,
    scale_covariates = scale_covariates,
    scaling = scaling,
    xs = gwr_design(data$x, scaling),
    xraw = cbind(1, data$x),
    dist = dist,
    dist_sorted = t(apply(dist, 1L, sort.int))
  ))
}

#' Row bandwidths at the stations
#'
#' @param ctx The context.
#' @param bandwidth b \[m\] or k.
#' @return Numeric vector of length n \[m\].
#' @noRd
gwr_station_bandwidth <- function(ctx, bandwidth) {
  if (ctx$adaptive) {
    ctx$dist_sorted[, as.integer(bandwidth)]
  } else {
    rep(bandwidth, ctx$n)
  }
}

#' Fit GWR at the stations for one bandwidth
#'
#' Local fits at every station, hat statistics (dev/specs/gwr-forcing.md
#' section 3.6), leave-one-out residuals by the exact deletion identity
#' \eqn{e_{-i} = e_i / (1 - s_{ii})} (section 4.3), AICc (section 4.1) and
#' CV.
#'
#' @param ctx The context.
#' @param bandwidth b \[m\] or k; `Inf` gives the global (OLS) fit.
#' @param full Logical. Whether to compute tr(S'S) and the local R2.
#' @return A list of station-level vectors (`b`, `n_nonzero`, `singular`,
#'   `fitted`, `residual`, `s_ii`, `loo_residual`, `local_r2`), `beta`
#'   (scaled design) and the scalars `rss`, `enp`, `tr_sts`, `aicc`, `aic`
#'   and `cv`.
#' @noRd
gwr_fit_core <- function(ctx, bandwidth, full = FALSE) {
  n <- ctx$n
  global <- is.infinite(bandwidth)
  if (global) {
    b <- rep(Inf, n)
    w <- matrix(1, n, n)
    nn <- rep(n, n)
  } else {
    b <- gwr_station_bandwidth(ctx, bandwidth)
    w <- gwr_kernel_weights(ctx$dist, b, ctx$kernel)
    nn <- gwr_neighbours(ctx$dist, w, b, ctx$kernel)
  }
  sol <- gwr_local_solve(w, ctx$xs, ctx$y)
  singular <- sol$singular
  out <- list(b = b, n_nonzero = nn, singular = singular, beta = sol$beta)
  if (any(singular)) {
    return(out)
  }
  p <- ctx$p
  cvec <- gwr_chol_solve(sol$chol, lapply(seq_len(p), function(a) {
    ctx$xs[, a]
  }), p)
  cmat <- do.call(cbind, cvec)
  s_ii <- diag(w) * rowSums(cmat * ctx$xs)
  fitted <- rowSums(ctx$xs * sol$beta)
  residual <- ctx$y - fitted
  one_minus <- 1 - s_ii
  loo <- residual / one_minus
  loo[!(one_minus > gwr_tolerances()$loo)] <- NA_real_
  rss <- sum(residual^2)
  enp <- sum(s_ii)
  out <- c(out, list(
    fitted = fitted,
    residual = residual,
    s_ii = s_ii,
    loo_residual = loo,
    rss = rss,
    enp = enp,
    aicc = gwr_aicc(rss, enp, n),
    aic = gwr_aic(rss, enp, n),
    cv = gwr_cv_score(loo)
  ))
  if (full) {
    smat <- w * (cmat %*% t(ctx$xs))
    out$tr_sts <- sum(smat^2)
    out$local_r2 <- gwr_local_r2(w, ctx$y, sol$beta %*% t(ctx$xs))
  }
  out
}

# User-facing fit ----------------------------------------------------------------------

#' Fit a geographically weighted regression
#'
#' @description
#' Fits a geographically weighted regression (GWR) of a station variable on
#' covariates for a given bandwidth: one weighted least squares (WLS) fit per
#' station, with the hat statistics, leave-one-out (LOO) residuals, AICc, CV
#' and the global (OLS) reference with the same design. This is the internal
#' numeric core of the spatial regionalization: inputs are plain vectors and
#' matrices in a projected coordinate reference system (metres); no raster
#' object is involved.
#'
#' The local estimator at regression point \eqn{i} is
#' \deqn{\hat\beta_i = (X^\top W_i X)^{-1} X^\top W_i y,
#'   \qquad \hat y_i = x_i^\top \hat\beta_i,}{beta_i = (X' W_i X)^-1 X' W_i y,
#'   yhat_i = x_i' beta_i,}
#' with \eqn{W_i = \mathrm{diag}(w(d_{ij}/b_i))}{W_i = diag(w(d_ij / b_i))}.
#' Row \eqn{i} of the hat matrix is
#' \eqn{s_i = x_i^\top (X^\top W_i X)^{-1} X^\top W_i}{s_i = x_i' (X' W_i
#' X)^-1 X' W_i}; the effective number of parameters is
#' \eqn{\mathrm{tr}(S)}{tr(S)}.
#'
#' @param y Numeric vector: the response at each station, in the unit of the
#'   variable (e.g. degC for air temperature).
#' @param x Numeric matrix (or data frame of numeric columns) with one row
#'   per station and one column per covariate, with unique column names
#'   (e.g. `elevation` \[m\]). The intercept is added internally.
#' @param coords Numeric matrix with two columns: projected coordinates
#'   (x, y) of the stations \[m\]. Distances are Euclidean in this CRS
#'   (decision GW-09); geographic coordinates (degrees) must be projected
#'   first.
#' @param bandwidth Either a number, the fixed bandwidth \[m\] (when
#'   `adaptive = FALSE`) or the number of neighbours k, a whole number in
#'   \[1, n\] (when `adaptive = TRUE`); or an `earthflux_gwr_bandwidth`
#'   object returned by [ef_gwr_bandwidth()], whose kernel, bandwidth type,
#'   neighbour rule, profile and flags are then carried to the fit.
#' @param kernel Character, no default (decision GW-04 is open): one of
#'   `"gaussian"`, `"exponential"`, `"bisquare"`, `"tricube"`, `"boxcar"`.
#'   May be omitted when `bandwidth` is an `earthflux_gwr_bandwidth` object;
#'   if given it must match the object.
#' @param adaptive Logical. `FALSE` for a fixed bandwidth in metres, `TRUE`
#'   for an adaptive bandwidth given as k nearest stations (the k-th
#'   smallest distance, counting the regression point itself when it is a
#'   station). Taken from `bandwidth` when that is an
#'   `earthflux_gwr_bandwidth` object and `adaptive` is not supplied.
#' @param min_neighbours `NULL` or a whole number: minimum number of
#'   neighbours of a regression point (stations with a non-zero weight for
#'   compact kernels; stations within one bandwidth for the gaussian and
#'   exponential kernels). `NULL` uses the mathematical minimum p + 1 (p
#'   coefficients for the local fit plus one so that the LOO fit stays
#'   identifiable; decision GW-06). Larger values are accepted but should be
#'   justified by a reference; they are recorded in `config`.
#' @param scale_covariates Logical. Whether to centre and scale the
#'   covariates internally (by their mean and standard deviation over the
#'   stations of the fit) to condition the local systems. Coefficients are
#'   always reported in original units and predictions do not change.
#' @param station_id `NULL` or a vector of unique station identifiers. By
#'   default `names(y)`, `rownames(x)` or the row numbers.
#'
#' @return An object of class `c("earthflux_gwr",
#'   "earthflux_regionalization", "list")` with elements:
#'   * `call`; `variable`, `target_time`, `unit`: `NULL` (set by the
#'     regionalization orchestrator);
#'   * `stations`: data frame with one row per input station: `station_id`,
#'     `x`, `y` (coordinates \[m\]), the covariates, `observed`, `fitted`,
#'     `residual`, `loo_fitted`, `loo_residual`, `s_ii`, `local_r2`,
#'     `bandwidth_i` \[m\], `n_nonzero`, `kappa`, `rank_ok`, `status`
#'     (`"used"` or `"excluded"`) and `exclusion_reason`;
#'   * `coefficients`: matrix (stations used x p) of local coefficients in
#'     original units (`(Intercept)` in the unit of `y`, slopes in unit of
#'     `y` per unit of each covariate);
#'   * `kernel`; `bandwidth`: `list(type, value, unit, selected_by)`;
#'   * `conventions`: the conventions applied (k including the point itself,
#'     boxcar support d <= b, AICc definition, sigma, local R2, LOO,
#'     distance method, covariate scaling, numerical tolerances);
#'   * `fit`: `n`, `p`, `rss`, `sigma_ml` = sqrt(RSS/n), `sigma_edf` =
#'     sqrt(RSS/edf), `enp` = tr(S), `tr_sts` = tr(S'S), `enp_alt` =
#'     2 tr(S) - tr(S'S), `edf` = n - 2 tr(S) + tr(S'S), `aicc`, `aic`
#'     (uncorrected, report only), `cv`, `rmse_loo` and `r2` (global,
#'     1 - RSS/TSS);
#'   * `global_reference`: OLS with the same design (`coefficients`, `rss`,
#'     `enp` = p, `aicc`, `cv`);
#'   * `profile`, `search`: from the bandwidth selection, `NULL` when the
#'     bandwidth is given by the user;
#'   * `flags`: list of `earthflux_flag` records (object and station scope);
#'   * `config`: covariates, their units (attribute `"units"` of `x`, if
#'     any), `min_neighbours` and its source, scaling;
#'   * `model`: what [ef_gwr_predict()] needs (stations used, response,
#'     covariates, coordinates, scaling, covariate range and convex hull);
#'   * `provenance`: method, package and R versions, `flags_evaluated`.
#'
#' @details
#' **Stations with missing values.** A station with a missing response,
#' covariate or coordinate is excluded with its reason in `stations` and the
#' flag `EF_GWR_STATION_EXCLUDED`; nothing is removed silently. Infinite
#' values raise `earthflux_domain_error`.
#'
#' **Errors.** n < p + 3 stations with complete data:
#' `earthflux_gwr_insufficient_stations` (fields `n`, `p`). A local design of
#' deficient rank at a station (e.g. only the station itself has a non-zero
#' weight): `earthflux_gwr_singular_error` (field `stations`). A covariate
#' constant among the stations, or stations with identical coordinates and
#' covariates: `earthflux_input_error`. Inconsistent dimensions:
#' `earthflux_input_error` (the spec's `earthflux_dimension_error` is not a
#' separate class; dimension errors are input errors as in the rest of the
#' core). Unknown kernel: `earthflux_unknown_method`. Fixed bandwidth not
#' positive, or k outside \[1, n\] or not whole: `earthflux_domain_error`.
#' All `earthflux_gwr_*` errors inherit `earthflux_gwr_error`.
#'
#' **Flags.** `EF_GWR_STATION_EXCLUDED` (record), `EF_GWR_FEW_NEIGHBOURS`
#' (record: stations with fewer than `min_neighbours` neighbours; their LOO
#' residual is `NA` when the fit interpolates them), `EF_GWR_AICC_UNDEFINED`
#' (object: n - 2 - tr(S) <= 0, AICc is `NA`), plus the object flags of the
#' bandwidth selection when `bandwidth` is an `earthflux_gwr_bandwidth`
#' object.
#'
#' @section Kernels and conventions:
#' With \eqn{r = d/b_i}: gaussian \eqn{\exp(-r^2/2)}, exponential
#' \eqn{\exp(-r)}, bisquare \eqn{(1-r^2)^2} for \eqn{d < b_i}, tricube
#' \eqn{(1-r^3)^3} for \eqn{d < b_i}, boxcar 1 for \eqn{d \le b_i}; 0
#' otherwise. The boxcar support \eqn{d \le b} (decision GW-03) differs from
#' the strict inequality of Table 1 of Gollini et al. (2015) and matches
#' `GWmodel` 2.4-1. With an adaptive bandwidth and the bisquare or tricube
#' kernel, the station at distance exactly \eqn{b_i} has weight 0, so at
#' most k - 1 stations (including the point itself) have a non-zero weight.
#'
#' @section Verification status:
#' Local estimator and kernels: `VERIFICADA` as content of Gollini et al.
#' (2015; preprint arXiv:1306.0413v2, section 6.1 and Table 1); as EarthFlux
#' definitions `CANDIDATA (corroborada)`: reproduced to 1e-10 relative by
#' `GWmodel` 2.4-1 in the cross-check tests. The k convention and the boxcar
#' boundary are EarthFlux conventions (GW-03). AICc: see
#' [ef_gwr_bandwidth()]. Local R2 (weighted mean of the local fit, GW-13),
#' tr(S'S), 2 tr(S) - tr(S'S), edf and the condition number: `CANDIDATA`.
#' Original attributions (Brunsdon et al., 1996; Fotheringham et al., 2002)
#' not read.
#'
#' @references
#' Gollini, I., Lu, B., Charlton, M., Brunsdon, C., & Harris, P. (2015).
#' GWmodel: An R package for exploring spatial heterogeneity using
#' geographically weighted models. *Journal of Statistical Software*,
#' 63(17). \doi{10.18637/jss.v063.i17}
#'
#' Brunsdon, C., Fotheringham, A. S., & Charlton, M. E. (1996).
#' Geographically weighted regression: A method for exploring spatial
#' nonstationarity. *Geographical Analysis*, 28(4), 281-298.
#' \doi{10.1111/j.1538-4632.1996.tb00936.x}
#'
#' @seealso [ef_gwr_bandwidth()] to select the bandwidth,
#'   [ef_gwr_predict()] to predict at new locations,
#'   [ef_gwr_diagnostics()].
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' # Six stations (projected coordinates in m), air temperature (degC) and
#' # elevation (m)
#' coords <- cbind(c(0, 10000, 0, 10000, 20000, 30000),
#'                 c(0, 0, 10000, 10000, 0, 30000))
#' elev <- cbind(elevation = c(100, 300, 500, 200, 800, 1200))
#' ta <- c(20.0, 18.9, 17.5, 19.6, 15.4, 13.1)
#' fit <- ef_gwr_fit(ta, elev, coords, bandwidth = 20000,
#'                   kernel = "gaussian")
#' fit
#' fit$coefficients
ef_gwr_fit <- function(y, x, coords, bandwidth, kernel, adaptive = FALSE,
                       min_neighbours = NULL, scale_covariates = TRUE,
                       station_id = NULL) {
  call <- sys.call()
  if (missing(bandwidth)) {
    ef_abort("`bandwidth` must be supplied explicitly.",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  check_flag_scalar(scale_covariates, "scale_covariates", call)
  prep <- gwr_prepare(y, x, coords, station_id, call)
  data <- gwr_used_data(prep, call)

  sel <- NULL
  if (inherits(bandwidth, "earthflux_gwr_bandwidth")) {
    sel <- bandwidth
    if (missing(kernel)) kernel <- sel$kernel
    if (missing(adaptive)) adaptive <- sel$type == "adaptive"
    sel_nb <- is.null(min_neighbours)
  }
  check_method(kernel, gwr_kernels(), arg = "kernel", call = call)
  check_flag_scalar(adaptive, "adaptive", call)
  if (!is.null(sel)) {
    gwr_check_selection(sel, kernel, adaptive, data, call)
    bandwidth <- sel$value
  }
  gwr_check_bandwidth(bandwidth, adaptive, data$n, call)
  nb <- if (!is.null(sel) && sel_nb) {
    list(value = sel$search$min_neighbours,
         source = sel$search$min_neighbours_source)
  } else {
    gwr_min_neighbours(min_neighbours, data$p, data$n, call)
  }

  ctx <- gwr_context(data, kernel, adaptive, scale_covariates)
  core <- gwr_fit_core(ctx, bandwidth, full = TRUE)
  if (any(core$singular)) {
    bad <- data$id[core$singular]
    gwr_abort(
      sprintf(
        paste0("The local design is rank deficient at %d station(s) with ",
               "this bandwidth (%s); the hat matrix is not defined. Use a ",
               "larger bandwidth."),
        length(bad), paste(bad[seq_len(min(10L, length(bad)))], collapse = ", ")
      ),
      class = "earthflux_gwr_singular_error",
      stations = bad, call = call
    )
  }
  gwr_build_object(prep, ctx, core, bandwidth, sel, nb, call,
                   units = attr(x, "units"))
}

#' Check a logical scalar argument
#'
#' @param x Object to check.
#' @param arg Argument name.
#' @param call The call to report.
#' @return `x`, invisibly.
#' @noRd
check_flag_scalar <- function(x, arg, call) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    ef_abort(sprintf("`%s` must be TRUE or FALSE.", arg),
             class = "earthflux_input_error", call = call)
  }
  invisible(x)
}

#' Validate a bandwidth value
#'
#' @param bandwidth Fixed b \[m\] or adaptive k.
#' @param adaptive Logical.
#' @param n Number of stations of the fit.
#' @param call The call to report.
#' @return `bandwidth`, invisibly. Errors of class `earthflux_domain_error`
#'   (b not positive or infinite; k outside \[1, n\] or not whole).
#' @noRd
gwr_check_bandwidth <- function(bandwidth, adaptive, n, call) {
  if (!is.numeric(bandwidth) || length(bandwidth) != 1L || is.na(bandwidth)) {
    ef_abort("`bandwidth` must be a single non-missing number.",
             class = "earthflux_input_error", call = call)
  }
  if (adaptive) {
    check_in_range(bandwidth, "bandwidth", lower = 1, upper = n, call = call)
    if (bandwidth != round(bandwidth)) {
      ef_abort(
        "An adaptive `bandwidth` (k nearest stations) must be a whole number.",
        class = c("earthflux_domain_error", "earthflux_input_error"),
        call = call
      )
    }
  } else {
    check_in_range(bandwidth, "bandwidth", lower = 0, lower_inclusive = FALSE,
                   call = call)
  }
  invisible(bandwidth)
}

#' Resolve the minimum number of neighbours
#'
#' @param min_neighbours `NULL` or a whole number in \[p + 1, n\].
#' @param p Number of coefficients.
#' @param n Number of stations of the fit.
#' @param call The call to report.
#' @return A list with `value` (integer) and `source`
#'   (`"mathematical_minimum"` or `"user"`).
#' @noRd
gwr_min_neighbours <- function(min_neighbours, p, n, call) {
  if (is.null(min_neighbours)) {
    return(list(value = as.integer(p + 1L), source = "mathematical_minimum"))
  }
  check_scalar(min_neighbours, "min_neighbours", whole = TRUE, call = call)
  check_in_range(min_neighbours, "min_neighbours", lower = p + 1, upper = n,
                 call = call)
  list(value = as.integer(min_neighbours), source = "user")
}

#' Check that a bandwidth selection matches a fit
#'
#' @param sel An `earthflux_gwr_bandwidth` object.
#' @param kernel,adaptive The kernel and type of the fit.
#' @param data The stations of the fit.
#' @param call The call to report.
#' @return `TRUE`, invisibly.
#' @noRd
gwr_check_selection <- function(sel, kernel, adaptive, data, call) {
  if (!identical(sel$kernel, kernel) ||
      !identical(sel$type == "adaptive", adaptive)) {
    ef_abort(
      sprintf(
        paste0("The bandwidth was selected for kernel \"%s\" (%s); the fit ",
               "asks for kernel \"%s\" (%s)."),
        sel$kernel, sel$type, kernel, if (adaptive) "adaptive" else "fixed"
      ),
      class = "earthflux_input_error", call = call
    )
  }
  if (!identical(sel$stations$station_id[sel$stations$status == "used"],
                 data$id)) {
    ef_abort(
      "The bandwidth was selected with a different set of stations.",
      class = "earthflux_input_error", call = call
    )
  }
  invisible(TRUE)
}

#' Build the earthflux_gwr object
#'
#' @param prep,ctx,core Data, context and core fit.
#' @param bandwidth The bandwidth value.
#' @param sel `NULL` or the `earthflux_gwr_bandwidth` object.
#' @param nb Resolved minimum neighbours (`gwr_min_neighbours()`).
#' @param call The call.
#' @param units `NULL` or the units attribute of `x`.
#' @return An `earthflux_gwr` object.
#' @noRd
gwr_build_object <- function(prep, ctx, core, bandwidth, sel, nb, call,
                             units) {
  n <- ctx$n
  p <- ctx$p
  coef <- gwr_unscale_coef(core$beta, ctx$scaling)
  rownames(coef) <- ctx$id

  checks <- lapply(seq_len(n), function(i) {
    w <- gwr_kernel_weights(ctx$dist[i, , drop = FALSE], core$b[i],
                            ctx$kernel)
    gwr_check_design(ctx$xraw, as.vector(w))
  })

  n_all <- length(prep$y)
  st <- data.frame(station_id = prep$id, x = prep$coords[, 1L],
                   y = prep$coords[, 2L], stringsAsFactors = FALSE)
  for (nm in colnames(prep$x)) st[[nm]] <- prep$x[, nm]
  fill <- function(v, type = NA_real_) {
    out <- rep(type, n_all)
    out[prep$used] <- v
    out
  }
  st$observed <- prep$y
  st$fitted <- fill(core$fitted)
  st$residual <- fill(core$residual)
  st$loo_fitted <- fill(ctx$y - core$loo_residual)
  st$loo_residual <- fill(core$loo_residual)
  st$s_ii <- fill(core$s_ii)
  st$local_r2 <- fill(core$local_r2)
  st$bandwidth_i <- fill(core$b)
  st$n_nonzero <- fill(core$n_nonzero, NA_integer_)
  st$kappa <- fill(vapply(checks, `[[`, numeric(1), "kappa"))
  st$rank_ok <- fill(vapply(checks, `[[`, numeric(1), "rank") == p, NA)
  st$status <- ifelse(prep$used, "used", "excluded")
  st$exclusion_reason <- prep$reason

  rss <- core$rss
  enp <- core$enp
  tr_sts <- core$tr_sts
  edf <- n - 2 * enp + tr_sts
  tss <- sum((ctx$y - mean(ctx$y))^2)
  fit <- list(
    n = n, p = p, rss = rss,
    sigma_ml = sqrt(rss / n),
    sigma_edf = if (edf > 0) sqrt(rss / edf) else NA_real_,
    enp = enp, tr_sts = tr_sts, enp_alt = 2 * enp - tr_sts, edf = edf,
    aicc = core$aicc, aic = core$aic, cv = core$cv,
    rmse_loo = sqrt(core$cv / n),
    r2 = 1 - rss / tss
  )

  glob <- gwr_fit_core(ctx, Inf)
  global_reference <- list(
    coefficients = gwr_unscale_coef(glob$beta[1L, , drop = FALSE],
                                    ctx$scaling)[1L, ],
    rss = glob$rss, enp = glob$enp, aicc = glob$aicc, cv = glob$cv
  )

  row_used <- which(prep$used)
  few <- rep(FALSE, n_all)
  few[row_used] <- core$n_nonzero < nb$value
  flag_parts <- list(
    ef_flag_set(list(EF_GWR_STATION_EXCLUDED = !prep$used), scope = "record"),
    ef_flag_set(list(EF_GWR_FEW_NEIGHBOURS = few), scope = "record")
  )
  if (is.null(sel)) {
    flag_parts <- c(flag_parts, list(ef_flag_set(
      list(EF_GWR_AICC_UNDEFINED = is.na(core$aicc)), scope = "object"
    )))
  } else {
    flag_parts <- c(flag_parts, list(sel_object_flags(sel)))
  }
  fl <- do.call(ef_flags_combine, flag_parts)

  model <- list(
    station_id = ctx$id, y = ctx$y, x = ctx$x, coords = ctx$coords,
    scaling = ctx$scaling,
    covariate_range = rbind(min = apply(ctx$x, 2L, min),
                            max = apply(ctx$x, 2L, max)),
    hull = gwr_convex_hull(ctx$coords)
  )

  out <- list(
    call = call,
    variable = NULL,
    target_time = NULL,
    unit = NULL,
    stations = st,
    coefficients = coef,
    kernel = ctx$kernel,
    bandwidth = list(
      type = if (ctx$adaptive) "adaptive" else "fixed",
      value = if (ctx$adaptive) as.integer(bandwidth) else bandwidth,
      unit = if (ctx$adaptive) "neighbours" else "m",
      selected_by = if (is.null(sel)) "user" else sel$criterion
    ),
    conventions = gwr_conventions(ctx$kernel, ctx$scale_covariates),
    fit = fit,
    global_reference = global_reference,
    profile = if (is.null(sel)) NULL else sel$profile,
    search = if (is.null(sel)) NULL else sel$search,
    flags = fl$flags,
    config = list(
      covariates = colnames(ctx$x),
      covariate_units = units,
      min_neighbours = nb$value,
      min_neighbours_source = nb$source,
      scale_covariates = ctx$scale_covariates
    ),
    model = model,
    provenance = list(
      method = "gwr",
      package_version = as.character(getNamespaceVersion("EarthFlux")),
      r_version = R.version.string,
      n_used = n,
      n_excluded = sum(!prep$used),
      seed = NULL,
      flags_evaluated = fl$evaluated
    )
  )
  new_ef_object(out, c("earthflux_gwr", "earthflux_regionalization"))
}

#' Object-scope flags inherited from a bandwidth selection
#'
#' @param sel An `earthflux_gwr_bandwidth` object.
#' @return A list of flag records with the attribute `evaluated`.
#' @noRd
sel_object_flags <- function(sel) {
  keep <- vapply(sel$flags, function(f) f$scope == "object", logical(1))
  flags <- sel$flags[keep]
  evaluated <- setdiff(sel$provenance$flags_evaluated,
                       "EF_GWR_STATION_EXCLUDED")
  attr(flags, "evaluated") <- evaluated
  flags
}

# Methods ------------------------------------------------------------------------------

#' @export
print.earthflux_gwr <- function(x, ...) {
  f <- x$fit
  bw <- x$bandwidth
  cat("<earthflux_gwr>\n")
  if (!is.null(x$variable)) {
    cat(sprintf("Variable: %s%s\n", x$variable,
                if (is.null(x$target_time)) "" else
                  paste0(" at ", format(x$target_time, tz = "UTC",
                                        usetz = TRUE))))
  }
  cat(sprintf("Method: gwr; kernel: %s; bandwidth (%s): %s %s; selected by: %s\n",
              x$kernel, bw$type, format(bw$value, digits = 8), bw$unit,
              bw$selected_by))
  cat(sprintf("Stations: %d used, %d excluded; p = %d coefficients\n",
              f$n, x$provenance$n_excluded, f$p))
  cat(sprintf("tr(S) = %.4f; 2 tr(S) - tr(S'S) = %.4f; RSS = %.6g; RMSE_LOO = %s\n",
              f$enp, f$enp_alt, f$rss, format(f$rmse_loo, digits = 6)))
  g <- x$global_reference
  cat(sprintf("AICc: GWR %s, global OLS %s; CV: GWR %s, global OLS %s\n",
              format(f$aicc, digits = 8), format(g$aicc, digits = 8),
              format(f$cv, digits = 6), format(g$cv, digits = 6)))
  gwr_print_flags(x$flags)
  cat("Conventions: k includes the point itself; AICc with ML sigma and tr(S)\n")
  invisible(x)
}

#' Print flag records grouped by severity
#'
#' @param flags List of `earthflux_flag` records.
#' @return `NULL`, invisibly.
#' @noRd
gwr_print_flags <- function(flags) {
  if (length(flags) == 0L) {
    cat("Flags: none\n")
    return(invisible(NULL))
  }
  sev <- vapply(flags, `[[`, "", "severity")
  for (s in rev(names(ef_flag_severity_levels()))) {
    hit <- flags[sev == s]
    if (length(hit) > 0L) {
      cat(sprintf("Flags (%s): %s\n", s, paste(vapply(hit, function(f) {
        sprintf("%s [%d/%d]", f$code, f$n_flagged, f$n_total)
      }, ""), collapse = ", ")))
    }
  }
  invisible(NULL)
}

#' @export
summary.earthflux_gwr <- function(object, ...) {
  st <- object$stations
  used <- st[st$status == "used", , drop = FALSE]
  probs <- c(0, 0.25, 0.5, 0.75, 1)
  coef_q <- apply(object$coefficients, 2L, stats::quantile, probs = probs,
                  names = FALSE)
  rownames(coef_q) <- c("min", "q25", "median", "q75", "max")
  r2_q <- stats::quantile(used$local_r2, probs = probs, names = FALSE)
  names(r2_q) <- rownames(coef_q)
  prof <- NULL
  if (!is.null(object$profile)) {
    pr <- object$profile[object$profile$stage == "grid", , drop = FALSE]
    prof <- list(
      n_evaluations = nrow(object$profile),
      n_local_minima = gwr_count_minima(pr$criterion, pr$feasible),
      at_bound = any(vapply(object$flags, function(f) {
        f$code == "EF_GWR_BW_AT_BOUND"
      }, logical(1)))
    )
  }
  flags <- if (length(object$flags) == 0L) NULL else data.frame(
    code = vapply(object$flags, `[[`, "", "code"),
    severity = vapply(object$flags, `[[`, "", "severity"),
    n_flagged = vapply(object$flags, `[[`, 0L, "n_flagged"),
    description = vapply(object$flags, `[[`, "", "description"),
    stringsAsFactors = FALSE
  )
  structure(
    list(
      kernel = object$kernel,
      bandwidth = object$bandwidth,
      fit = object$fit,
      coefficients = coef_q,
      local_r2 = r2_q,
      stations = st[, c("station_id", "status", "residual", "loo_residual",
                        "s_ii", "kappa")],
      profile = prof,
      flags = flags
    ),
    class = "summary.earthflux_gwr"
  )
}

#' @export
print.summary.earthflux_gwr <- function(x, ...) {
  cat("<summary of earthflux_gwr>\n")
  cat(sprintf("Kernel: %s; bandwidth (%s): %s %s (selected by %s)\n",
              x$kernel, x$bandwidth$type, format(x$bandwidth$value, digits = 8),
              x$bandwidth$unit, x$bandwidth$selected_by))
  cat(sprintf("n = %d, tr(S) = %.4f, AICc = %s, CV = %s, R2 = %.4f\n",
              x$fit$n, x$fit$enp, format(x$fit$aicc, digits = 8),
              format(x$fit$cv, digits = 6), x$fit$r2))
  cat("\nLocal coefficients (original units):\n")
  print(x$coefficients)
  cat("\nLocal R2 (local fit, weighted mean):\n")
  print(x$local_r2)
  cat("\nStations:\n")
  print(x$stations, row.names = FALSE)
  if (!is.null(x$profile)) {
    cat(sprintf(
      "\nProfile: %d evaluations; %d local minima on the grid; optimum at a search bound: %s\n",
      x$profile$n_evaluations, x$profile$n_local_minima,
      if (x$profile$at_bound) "yes" else "no"
    ))
  }
  cat("\nFlags:\n")
  if (is.null(x$flags)) cat("  none\n") else print(x$flags, row.names = FALSE)
  invisible(x)
}

#' @export
as.data.frame.earthflux_gwr <- function(x, ...) {
  x$stations
}
