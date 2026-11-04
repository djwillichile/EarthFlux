# Cross-verification of the internal GWR core against GWmodel
# (dev/specs/gwr-forcing.md section 10, "Plan de verificación cruzada";
# dev/decisions/gwr-backend.md). GWmodel is only in Suggests: these tests are
# skipped when it is not installed. Tolerance: 1e-10 relative (mean relative
# difference, as testthat::expect_equal) on coefficients, RSS, AICc, CV,
# LOO residuals and predictions. Selected bandwidths are not compared
# (different search bounds and tolerances).
#
# Convention mapping (EarthFlux -> GWmodel 2.4-1):
#   coefficients          -> SDF columns Intercept, <covariates>
#   tr(S) (enp)           -> not exposed; GWmodel `enp` = 2 tr(S) - tr(S'S)
#                            (EarthFlux `enp_alt`)
#   aicc                  -> GW.diagnostic$AICc (same definition)
#   aic                   -> GW.diagnostic$AIC
#   edf                   -> GW.diagnostic$edf
#   loo_residual / cv     -> SDF$CV_Score (cv = TRUE) / its sum of squares
#   local R2              -> SDF$Local_R2 uses the global fitted values, the
#                            unweighted mean and, with an adaptive kernel, the
#                            transposed weights w_ji: compared only for fixed
#                            kernels, with the equivalent internal variant
#   adaptive k            -> adaptive = TRUE, bw = k (k counts the point)

gwmodel_fit <- function(dat, bw, kernel, adaptive) {
  # GWmodel works on sp objects; sp is attached by GWmodel (Depends)
  suppressPackageStartupMessages(library(GWmodel))
  df <- data.frame(y = dat$y, dat$x)
  pts <- SpatialPointsDataFrame(dat$coords, df)
  form <- stats::as.formula(paste("y ~", paste(colnames(dat$x),
                                               collapse = " + ")))
  list(
    fit = GWmodel::gwr.basic(form, data = pts, bw = bw, kernel = kernel,
                             adaptive = adaptive, cv = TRUE),
    pts = pts, form = form
  )
}

compare_fit <- function(dat, bw, kernel, adaptive) {
  g <- gwmodel_fit(dat, bw, kernel, adaptive)$fit
  f <- ef_gwr_fit(dat$y, dat$x, dat$coords, bw, kernel, adaptive = adaptive)
  tol <- 1e-10
  info <- paste(kernel, if (adaptive) "adaptive" else "fixed", bw)
  b <- as.matrix(g$SDF@data[, c("Intercept", colnames(dat$x))])
  expect_equal(unname(f$coefficients), unname(b), tolerance = tol,
               info = info)
  dg <- g$GW.diagnostic
  expect_equal(f$fit$rss, dg$RSS.gw, tolerance = tol, info = info)
  if (is.na(f$fit$aicc)) {
    # n - 2 - tr(S) <= 0: GWmodel reports the formula's (spurious) value,
    # EarthFlux reports NA (section 4.1, case G6)
    n <- length(dat$y)
    expect_lte(n - 2 - f$fit$enp, 0)
    raw <- 2 * n * log(sqrt(f$fit$rss / n)) + n * log(2 * pi) +
      n * (n + f$fit$enp) / (n - 2 - f$fit$enp)
    expect_equal(raw, dg$AICc, tolerance = tol, info = info)
  } else {
    expect_equal(f$fit$aicc, dg$AICc, tolerance = tol, info = info)
  }
  expect_equal(f$fit$aic, dg$AIC, tolerance = tol, info = info)
  expect_equal(f$fit$enp_alt, dg$enp, tolerance = tol, info = info)
  expect_equal(f$fit$edf, dg$edf, tolerance = tol, info = info)
  expect_equal(f$stations$loo_residual, g$SDF$CV_Score, tolerance = tol,
               info = info)
  expect_equal(f$fit$cv, sum(g$SDF$CV_Score^2), tolerance = tol, info = info)
  expect_equal(f$stations$residual, g$SDF$residual, tolerance = tol,
               info = info)
  if (!adaptive) {
    d <- EarthFlux:::gwr_distance(dat$coords, dat$coords)
    w <- EarthFlux:::gwr_kernel_weights(d, f$stations$bandwidth_i, kernel)
    r2 <- EarthFlux:::gwr_local_r2_global_fit(w, dat$y, f$stations$fitted)
    expect_equal(r2, g$SDF$Local_R2, tolerance = tol, info = info)
  }
  invisible(f)
}

test_that("G2 (six stations, gaussian 20 km) agrees with GWmodel", {
  skip_if_not_installed("GWmodel")
  s <- gwr_small()
  compare_fit(list(y = s$y, x = s$x, coords = s$coords), 20000, "gaussian",
              FALSE)
})

test_that("fixed kernels on the synthetic reference agree with GWmodel", {
  skip_if_not_installed("GWmodel")
  dat <- gwr_synthetic(2L)
  compare_fit(dat, 40000, "bisquare", FALSE)
  compare_fit(dat, 15000, "gaussian", FALSE)
  compare_fit(dat, 40000, "tricube", FALSE)
  compare_fit(dat, 10000, "exponential", FALSE)
  # boxcar: GWmodel also gives weight 1 at d = b
  compare_fit(dat, 30000, "boxcar", FALSE)
})

test_that("adaptive kernels (k counting the point itself) agree", {
  skip_if_not_installed("GWmodel")
  dat <- gwr_synthetic(2L)
  f <- compare_fit(dat, 30, "bisquare", TRUE)
  expect_equal(f$fit$aicc, 173.128323, tolerance = 1e-6)
  compare_fit(dat, 20, "gaussian", TRUE)
  # six stations, k = 5: AICc undefined (n - 2 - tr(S) <= 0)
  s <- gwr_small()
  f5 <- compare_fit(list(y = s$y, x = s$x, coords = s$coords), 5,
                    "bisquare", TRUE)
  expect_true(is.na(f5$fit$aicc))
})

test_that("tr(S) recovered from GWmodel's AICc and RSS agrees", {
  skip_if_not_installed("GWmodel")
  # GWmodel does not expose tr(S) (its enp + edf = n); solving its AICc for
  # tr(S) given RSS: P = AICc - 2n ln(sigma) - n ln(2 pi),
  # tr(S) = (P (n - 2) - n^2) / (P + n)
  trs <- function(dg, n) {
    pen <- dg$AICc - 2 * n * log(sqrt(dg$RSS.gw / n)) - n * log(2 * pi)
    (pen * (n - 2) - n^2) / (pen + n)
  }
  dat <- gwr_synthetic(2L)
  for (cfg in list(list("bisquare", 40000, FALSE), list("bisquare", 30, TRUE),
                   list("gaussian", 15000, FALSE))) {
    g <- gwmodel_fit(dat, cfg[[2]], cfg[[1]], cfg[[3]])$fit$GW.diagnostic
    f <- ef_gwr_fit(dat$y, dat$x, dat$coords, cfg[[2]], cfg[[1]],
                    adaptive = cfg[[3]])
    expect_equal(f$fit$enp, trs(g, 150), tolerance = 1e-10)
    expect_equal(f$fit$tr_sts, 2 * f$fit$enp - g$enp, tolerance = 1e-10)
  }
})

test_that("block predictions agree with GWmodel::gwr.predict()", {
  skip_if_not_installed("GWmodel")
  dat <- gwr_synthetic(40L)
  for (cfg in list(list("bisquare", 40000, FALSE),
                   list("gaussian", 20, TRUE))) {
    gm <- gwmodel_fit(dat, cfg[[2]], cfg[[1]], cfg[[3]])
    grid <- SpatialPointsDataFrame(dat$grid_coords, data.frame(dat$grid_x))
    dm <- GWmodel::gw.dist(dp.locat = dat$coords, rp.locat = dat$grid_coords)
    utils::capture.output(
      gp <- GWmodel::gwr.predict(gm$form, data = gm$pts, predictdata = grid,
                                 bw = cfg[[2]], kernel = cfg[[1]],
                                 adaptive = cfg[[3]], dMat1 = dm)
    )
    f <- ef_gwr_fit(dat$y, dat$x, dat$coords, cfg[[2]], cfg[[1]],
                    adaptive = cfg[[3]])
    p <- ef_gwr_predict(f, dat$grid_x, dat$grid_coords, chunk_rows = 500)
    expect_equal(p$value, gp$SDF$prediction, tolerance = 1e-10)
    expect_equal(unname(p$coefficients),
                 unname(as.matrix(gp$SDF@data[, c("Intercept_coef",
                                                  "elev_coef",
                                                  "coast_coef")])),
                 tolerance = 1e-10)
  }
})

test_that("AICc evaluated in a common bandwidth agrees along the profile", {
  skip_if_not_installed("GWmodel")
  dat <- gwr_synthetic(2L)
  bw <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                         criterion = "AICc",
                         search = ef_gwr_search(n_grid = 6, tol = 10,
                                                lower_offset = 0.01,
                                                upper_factor = 1.5))
  grid <- bw$profile[bw$profile$stage == "grid", ]
  for (i in c(2L, 4L, 6L)) {
    g <- gwmodel_fit(dat, grid$bandwidth[i], "bisquare", FALSE)$fit
    expect_equal(grid$aicc[i], g$GW.diagnostic$AICc, tolerance = 1e-10)
    expect_equal(grid$cv[i], sum(g$SDF$CV_Score^2), tolerance = 1e-10)
  }
})
