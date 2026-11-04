# Spatial forcing: GWR prediction ---------------------------------------------------
#
# Purpose: predict a fitted GWR model at new locations (cells of the working
#   grid) from their covariates, exactly (one local WLS fit per location),
#   and flag extrapolation outside the support of the station network.
#
# Specification: dev/specs/gwr-forcing.md sections 6.1 (exact block
#   prediction), 6.3 (extrapolation flags), 6.4 (memory) and 9.4 (NA).
#
# Block design: ef_gwr_predict() works on rows. The result at a row depends
#   only on that row and on the fitted model (weighted sums with rowSums(),
#   vectorised Cholesky, per-row k-th distance), so the orchestrator can call
#   it once per raster block and the result does not depend on the block
#   size. Memory per internal chunk is O(chunk_rows x n).

#' Predict a geographically weighted regression at new locations
#'
#' @description
#' Exact GWR prediction: at each new location g with covariates
#' \eqn{x_g}, weights with respect to the stations of the fit (same kernel
#' and bandwidth; adaptive: the k-th smallest distance from g to the
#' stations), local WLS fit and
#' \deqn{\hat y_g = x_g^\top \hat\beta_g, \qquad \hat\beta_g = (X^\top W_g
#'   X)^{-1} X^\top W_g y}{yhat_g = x_g' beta_g, beta_g = (X' W_g X)^-1 X'
#'   W_g y}
#' (dev/specs/gwr-forcing.md sections 3.2 and 6.1). Designed to be called
#' on blocks of rows (e.g. one raster block at a time): rows are processed
#' independently, so the result does not depend on how the locations are
#' split into calls or chunks.
#'
#' @param object An `earthflux_gwr` object from [ef_gwr_fit()].
#' @param newx Numeric matrix (or data frame) of covariates at the new
#'   locations, one row per location, with the same column names (and
#'   units) as the covariates of the fit; column order may differ.
#' @param newcoords Numeric matrix with two columns: projected coordinates
#'   (x, y) of the new locations \[m\], in the CRS of the fit.
#' @param chunk_rows Whole number: rows processed together internally. It
#'   only bounds memory (about 8 x `chunk_rows` x n bytes per matrix of
#'   distances or weights) and never changes the result.
#'
#' @return A list with:
#'   * `value`: numeric vector of predictions, in the unit of the response;
#'     `NA` where a covariate or coordinate is missing or the local design
#'     is rank deficient;
#'   * `coefficients`: matrix (rows x p) of local coefficients in original
#'     units (`NA` rows as for `value`);
#'   * `bandwidth`: bandwidth used at each location \[m\];
#'   * `n_nonzero`: integer number of neighbours of each location (stations
#'     with a non-zero weight for compact kernels, within one bandwidth for
#'     the gaussian and exponential kernels);
#'   * `flags`: list of `earthflux_flag` records (cell scope; `index` =
#'     positions in the rows of this call) with the attribute `evaluated`.
#'
#' @details
#' Flags (cell scope, bits of the GWR flag word, dev/specs/flags.md 6.4):
#' * `EF_INPUT_NA` (bit 0): a covariate or coordinate is missing;
#' * `EF_GWR_EXTRAPOLATION_COVARIATE` (bit 1): some covariate is outside
#'   the range \[min, max\] of the stations used in the fit;
#' * `EF_GWR_EXTRAPOLATION_LOCAL` (bit 2): some covariate is outside the
#'   range of the stations with a non-zero weight at the location; evaluated
#'   only for the compact kernels (bisquare, tricube, boxcar);
#' * `EF_GWR_OUTSIDE_HULL` (bit 3): the location is outside the convex hull
#'   of the stations used (points on its boundary are inside);
#' * `EF_GWR_FEW_NEIGHBOURS` (bit 4): fewer neighbours than the
#'   `min_neighbours` of the fit; the value is kept;
#' * `EF_GWR_LOCAL_SINGULAR` (bit 5): the local design is rank deficient;
#'   the value and coefficients are `NA` (never replaced by OLS or a
#'   neighbour).
#'
#' The distance to the nearest station (`EF_GWR_FAR_FROM_STATIONS`) needs a
#' threshold without reference (class II) and is not evaluated.
#'
#' Errors: `earthflux_input_error` (columns of `newx` not matching the
#' covariates of the fit, `newcoords` not with two columns, row counts
#' differing, no rows); `earthflux_domain_error` (infinite values).
#'
#' @section Verification status:
#' As [ef_gwr_fit()]: estimator `CANDIDATA (corroborada)`; the predictions
#' agree with `GWmodel::gwr.predict()` to 1e-10 relative in the cross-check
#' tests. The extrapolation conditions are design definitions without
#' threshold (dev/specs/gwr-forcing.md section 6.3).
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
#' cells <- cbind(c(5000, 15000, 40000), c(5000, 5000, 40000))
#' pred <- ef_gwr_predict(fit, cbind(elevation = c(250, 600, 1500)), cells)
#' pred$value
#' vapply(pred$flags, `[[`, "", "code")
ef_gwr_predict <- function(object, newx, newcoords, chunk_rows = 10000L) {
  call <- sys.call()
  if (!inherits(object, "earthflux_gwr")) {
    ef_abort("`object` must be an `earthflux_gwr` object (see `ef_gwr_fit()`).",
             class = "earthflux_input_error", call = call)
  }
  check_scalar(chunk_rows, "chunk_rows", lower = 1, whole = TRUE, call = call)
  mod <- object$model
  covs <- colnames(mod$x)
  newx <- gwr_as_newx(newx, covs, call)
  newcoords <- gwr_as_coords(newcoords, "newcoords", call)
  m <- nrow(newx)
  if (m == 0L || nrow(newcoords) != m) {
    ef_abort(
      sprintf(
        "`newx` and `newcoords` must have the same, non-zero number of rows (%d and %d).",
        m, nrow(newcoords)
      ),
      class = "earthflux_input_error", call = call
    )
  }
  check_in_range(newx, "newx", call = call)
  check_in_range(newcoords, "newcoords", call = call)

  p <- length(covs) + 1L
  na_row <- rowSums(is.na(newx)) > 0L | rowSums(is.na(newcoords)) > 0L
  value <- rep(NA_real_, m)
  coef <- matrix(NA_real_, m, p, dimnames = list(NULL, c("(Intercept)", covs)))
  bw <- rep(NA_real_, m)
  nn <- rep(NA_integer_, m)
  singular <- rep(FALSE, m)
  local_out <- rep(FALSE, m)

  rows <- which(!na_row)
  chunks <- split(rows, ceiling(seq_along(rows) / chunk_rows))
  for (ii in chunks) {
    blk <- gwr_predict_block(object, newx[ii, , drop = FALSE],
                             newcoords[ii, , drop = FALSE])
    value[ii] <- blk$value
    coef[ii, ] <- blk$coefficients
    bw[ii] <- blk$bandwidth
    nn[ii] <- blk$n_nonzero
    singular[ii] <- blk$singular
    local_out[ii] <- blk$local_out
  }

  ext <- gwr_extrapolation_flags(newx, newcoords, object, na_row)
  masks <- list(EF_INPUT_NA = na_row,
                EF_GWR_EXTRAPOLATION_COVARIATE = ext$covariate)
  if (object$kernel %in% gwr_compact_kernels()) {
    masks$EF_GWR_EXTRAPOLATION_LOCAL <- local_out & !na_row
  }
  masks$EF_GWR_OUTSIDE_HULL <- ext$hull
  masks$EF_GWR_FEW_NEIGHBOURS <- !is.na(nn) &
    nn < object$config$min_neighbours
  masks$EF_GWR_LOCAL_SINGULAR <- singular
  flags <- ef_flag_set(masks, scope = "cell")

  list(value = value, coefficients = coef, bandwidth = bw, n_nonzero = nn,
       flags = flags)
}

#' Coerce and check the covariates of new locations
#'
#' @param newx Matrix or data frame.
#' @param covs Covariate names of the fit.
#' @param call The call to report.
#' @return Numeric matrix with columns in the order of `covs`.
#' @noRd
gwr_as_newx <- function(newx, covs, call) {
  if (is.data.frame(newx)) {
    if (!all(vapply(newx, is.numeric, logical(1)))) {
      ef_abort("All columns of `newx` must be numeric.",
               class = "earthflux_input_error", call = call)
    }
    newx <- as.matrix(newx)
  }
  if (!is.matrix(newx) || !is.numeric(newx) || is.null(colnames(newx)) ||
      !setequal(colnames(newx), covs) || ncol(newx) != length(covs)) {
    ef_abort(
      sprintf("`newx` must be a numeric matrix with exactly the columns %s.",
              paste0("`", covs, "`", collapse = ", ")),
      class = "earthflux_input_error", call = call
    )
  }
  newx <- newx[, covs, drop = FALSE]
  storage.mode(newx) <- "double"
  newx
}

#' Predict one block of complete rows
#'
#' @param object An `earthflux_gwr` object.
#' @param newx Covariates (no `NA`), columns in the order of the fit.
#' @param newcoords Coordinates (no `NA`).
#' @return A list with `value`, `coefficients` (original units),
#'   `bandwidth`, `n_nonzero`, `singular` and `local_out` (some covariate
#'   outside the range of the stations with a non-zero weight).
#' @noRd
gwr_predict_block <- function(object, newx, newcoords) {
  mod <- object$model
  adaptive <- object$bandwidth$type == "adaptive"
  kernel <- object$kernel
  dist <- gwr_distance(newcoords, mod$coords)
  b <- gwr_row_bandwidth(dist, object$bandwidth$value, adaptive)
  w <- gwr_kernel_weights(dist, b, kernel)
  nn <- gwr_neighbours(dist, w, b, kernel)
  xs <- gwr_design(mod$x, mod$scaling)
  sol <- gwr_local_solve(w, xs, mod$y)
  xg <- gwr_design(newx, mod$scaling)
  value <- rowSums(xg * sol$beta)
  coef <- gwr_unscale_coef(sol$beta, mod$scaling)
  local_out <- rep(FALSE, nrow(newx))
  if (kernel %in% gwr_compact_kernels()) {
    local_out <- gwr_local_range_out(w, mod$x, newx)
  }
  list(value = value, coefficients = coef, bandwidth = b, n_nonzero = nn,
       singular = sol$singular, local_out = local_out)
}

#' Covariates outside the range of the stations with non-zero weight
#'
#' @param w Matrix of weights (rows = locations).
#' @param x Covariates of the stations.
#' @param newx Covariates of the locations.
#' @return Logical vector (`FALSE` where no station has a non-zero weight:
#'   that case is reported by `EF_GWR_LOCAL_SINGULAR`).
#' @noRd
gwr_local_range_out <- function(w, x, newx) {
  pos <- w > 0
  any_pos <- rowSums(pos) > 0L
  out <- rep(FALSE, nrow(w))
  for (k in seq_len(ncol(x))) {
    ord <- order(x[, k])
    lo <- x[ord, k][max.col(pos[, ord, drop = FALSE], ties.method = "first")]
    rev_ord <- rev(ord)
    hi <- x[rev_ord, k][max.col(pos[, rev_ord, drop = FALSE],
                                ties.method = "first")]
    out <- out | (any_pos & (newx[, k] < lo | newx[, k] > hi))
  }
  out
}

#' Extrapolation conditions of new locations
#'
#' @param newx,newcoords Covariates and coordinates.
#' @param object An `earthflux_gwr` object.
#' @param na_row Logical: rows with missing input (never flagged here).
#' @return A list with logical vectors `covariate` (outside the range of
#'   the stations used) and `hull` (outside their convex hull).
#' @noRd
gwr_extrapolation_flags <- function(newx, newcoords, object, na_row) {
  rng <- object$model$covariate_range
  cov_out <- rep(FALSE, nrow(newx))
  for (k in seq_len(ncol(newx))) {
    cov_out <- cov_out | newx[, k] < rng["min", k] | newx[, k] > rng["max", k]
  }
  cov_out[na_row] <- FALSE
  hull_out <- rep(FALSE, nrow(newx))
  ok <- !na_row
  hull_out[ok] <- !gwr_in_hull(newcoords[ok, , drop = FALSE],
                               object$model$hull, object$model$coords)
  list(covariate = cov_out, hull = hull_out)
}

#' Convex hull of points (monotone chain)
#'
#' Andrew's monotone chain algorithm; collinear points on the boundary are
#' dropped.
#'
#' @param pts Matrix n x 2.
#' @return Matrix of hull vertices in counter-clockwise order (one or two
#'   rows if the points are coincident or collinear).
#' @noRd
gwr_convex_hull <- function(pts) {
  pts <- unique(pts)
  pts <- pts[order(pts[, 1L], pts[, 2L]), , drop = FALSE]
  n <- nrow(pts)
  if (n < 3L) return(pts)
  cross <- function(o, a, b) {
    (a[1L] - o[1L]) * (b[2L] - o[2L]) - (a[2L] - o[2L]) * (b[1L] - o[1L])
  }
  chain <- function(idx) {
    h <- integer(0)
    for (i in idx) {
      while (length(h) >= 2L &&
             cross(pts[h[length(h) - 1L], ], pts[h[length(h)], ],
                   pts[i, ]) <= 0) {
        h <- h[-length(h)]
      }
      h <- c(h, i)
    }
    h
  }
  lower <- chain(seq_len(n))
  upper <- chain(rev(seq_len(n)))
  h <- c(lower[-length(lower)], upper[-length(upper)])
  pts[h, , drop = FALSE]
}

#' Points inside (or on the boundary of) a convex hull
#'
#' @param pts Matrix m x 2 of points.
#' @param hull Hull vertices in counter-clockwise order.
#' @param ref Reference points (the stations), giving the length scale of
#'   the boundary tolerance.
#' @return Logical vector.
#' @noRd
gwr_in_hull <- function(pts, hull, ref) {
  extent <- max(diff(range(ref[, 1L])), diff(range(ref[, 2L])), 1)
  tol <- gwr_tolerances()$hull * extent
  nh <- nrow(hull)
  px <- pts[, 1L]
  py <- pts[, 2L]
  if (nh == 1L) {
    return(sqrt((px - hull[1L, 1L])^2 + (py - hull[1L, 2L])^2) <= tol)
  }
  if (nh == 2L) {
    ax <- hull[1L, 1L]; ay <- hull[1L, 2L]
    ex <- hull[2L, 1L] - ax; ey <- hull[2L, 2L] - ay
    len2 <- ex * ex + ey * ey
    t <- pmin(pmax(((px - ax) * ex + (py - ay) * ey) / len2, 0), 1)
    return(sqrt((px - ax - t * ex)^2 + (py - ay - t * ey)^2) <= tol)
  }
  inside <- rep(TRUE, length(px))
  for (i in seq_len(nh)) {
    a <- hull[i, ]
    b <- hull[if (i == nh) 1L else i + 1L, ]
    ex <- b[1L] - a[1L]
    ey <- b[2L] - a[2L]
    cr <- (ex * (py - a[2L]) - ey * (px - a[1L])) / sqrt(ex * ex + ey * ey)
    inside <- inside & cr >= -tol
  }
  inside
}

#' Flag word of a prediction
#'
#' Packs the cell-scope flag records of [ef_gwr_predict()] into one integer
#' per row, \eqn{w = \sum_k 2^{bit_k} m_k}, with the bits of the registry
#' (dev/specs/flags.md section 6.3). For the orchestrator, which writes the
#' word of each block; evaluated conditions that hold nowhere give 0 and the
#' word is never `NA` where the prediction was evaluated.
#'
#' @param flags The `flags` element of a prediction.
#' @param n Number of rows of the prediction.
#' @return Integer vector of length `n`.
#' @noRd
gwr_flag_word <- function(flags, n) {
  reg <- ef_flag_registry()
  word <- numeric(n)
  for (f in flags) {
    bit <- reg$bit[match(f$code, reg$code)]
    word[f$index] <- word[f$index] + 2^bit
  }
  as.integer(word)
}
