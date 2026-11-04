# GWR fit at the stations: numeric cases G1a, G1b, G2, G4, G5, G6, G7 and
# identities (dev/specs/gwr-forcing.md sections 3, 4.1, 4.3, 10 and 11).

test_that("G1a: boxcar b = 15 km at S1 reproduces the hand computation", {
  s <- gwr_small()
  y <- s$y
  y[6] <- NA # S6 is isolated (only itself within 15 km): excluded here
  fit <- ef_gwr_fit(y, s$x, s$coords, bandwidth = 15000, kernel = "boxcar",
                    station_id = s$id)
  st <- fit$stations
  # weights S1-S4 = 1: OLS on four stations
  expect_identical(st$n_nonzero[1], 4L)
  expect_equal(unname(fit$coefficients["S1", ]), c(20.76, -0.0064),
               tolerance = 1e-8)
  expect_equal(st$fitted[1], 20.12, tolerance = 1e-8)
  expect_equal(st$s_ii[1], 0.60, tolerance = 1e-8)
  # LOO: OLS on S2-S4, beta = (21.0, -0.0070), prediction 20.3
  expect_equal(st$loo_fitted[1], 20.3, tolerance = 1e-8)
  expect_equal(st$loo_residual[1], (20.0 - 20.12) / (1 - 0.6),
               tolerance = 1e-8)
})

test_that("G1b: gaussian b = 10 km at S1 reproduces the hand computation", {
  s <- gwr_small()
  fit <- ef_gwr_fit(s$y, s$x, s$coords, bandwidth = 10000,
                    kernel = "gaussian")
  expect_equal(unname(fit$coefficients[1, ]),
               c(20.73642587, -0.0064577356), tolerance = 1e-8)
  # yhat_1 = beta_0 + 100 beta_1 = 20.09065231 (section 10 prints 20.090654,
  # a rounding slip: the two printed coefficients give 20.0906523)
  expect_equal(fit$stations$fitted[1], 20.73642587 - 100 * 0.0064577356,
               tolerance = 1e-8)
  expect_equal(fit$stations$s_ii[1], 0.6975606, tolerance = 1e-7)
  # condition number of W^(1/2) X with equilibrated columns
  expect_equal(fit$stations$kappa[1], 3.2378, tolerance = 1e-4)
  # the internal scaling conditions the system (section 3.7)
  w <- exp(-0.5 * (sqrt(rowSums(sweep(s$coords, 2, s$coords[1, ])^2)) /
                     10000)^2)
  xraw <- cbind(1, s$x)
  expect_equal(kappa(crossprod(sqrt(w) * xraw), exact = TRUE), 3.678e5,
               tolerance = 1e-3)
})

test_that("G2: full gaussian fit with b = 20 km matches section 10", {
  s <- gwr_small()
  fit <- ef_gwr_fit(s$y, s$x, s$coords, bandwidth = 20000,
                    kernel = "gaussian", station_id = s$id)
  f <- fit$fit
  expect_equal(f$rss, 0.05488621, tolerance = 1e-7)
  expect_equal(f$enp, 2.73817720, tolerance = 1e-8)
  expect_equal(f$tr_sts, 2.29531863, tolerance = 1e-8)
  expect_equal(f$enp_alt, 3.18103577, tolerance = 1e-8)
  expect_equal(f$edf, 2.818964, tolerance = 1e-6)
  expect_equal(f$aicc, 24.412005, tolerance = 1e-7)
  expect_equal(f$aic, -8.400076, tolerance = 1e-6)
  expect_equal(f$cv, 0.34958300, tolerance = 1e-7)
  st <- fit$stations
  expect_equal(unname(fit$coefficients[, 1]),
               c(20.78793, 20.79976, 20.78418, 20.79070, 20.80460, 20.77549),
               tolerance = 1e-6)
  expect_equal(unname(fit$coefficients[, 2]),
               c(-0.00658359, -0.00659954, -0.00654505, -0.00654500,
                 -0.00659823, -0.00643029), tolerance = 1e-6)
  expect_equal(st$residual,
               c(-0.12957310, 0.08010029, -0.01165763, 0.11829798,
                 -0.12601841, 0.04086582), tolerance = 1e-7)
  expect_equal(st$s_ii,
               c(0.4779725, 0.2467174, 0.2697879, 0.3295729, 0.5107340,
                 0.9033926), tolerance = 1e-6)
  expect_equal(st$loo_residual,
               c(-0.24821127, 0.10633498, -0.01596471, 0.17645165,
                 -0.25756623, 0.42300900), tolerance = 1e-7)
  # local R2: local WLS fit with weighted mean (= summary(lm(weights))),
  # section 3.8
  expect_equal(st$local_r2[c(1, 6)], c(0.99615697, 0.99854899),
               tolerance = 1e-7)
  d <- EarthFlux:::gwr_distance(s$coords, s$coords)
  w <- EarthFlux:::gwr_kernel_weights(d, rep(20000, 6), "gaussian")
  ref <- summary(stats::lm(s$y ~ s$x[, 1], weights = w[1, ]))$r.squared
  expect_equal(st$local_r2[1], ref, tolerance = 1e-10)
  # GWmodel's Local_R2 convention (global fitted values, unweighted mean)
  r2g <- EarthFlux:::gwr_local_r2_global_fit(w, s$y, st$fitted)
  expect_equal(r2g[c(1, 6)], c(0.99741850, 0.99936410), tolerance = 1e-7)
})

test_that("LOO shortcut equals LOO by definition (own weight set to zero)", {
  s <- gwr_small()
  d <- EarthFlux:::gwr_distance(s$coords, s$coords)
  for (cfg in list(list("gaussian", 20000, FALSE), list("bisquare", 5, TRUE),
                   list("exponential", 8000, FALSE))) {
    fit <- ef_gwr_fit(s$y, s$x, s$coords, cfg[[2]], cfg[[1]],
                      adaptive = cfg[[3]])
    b <- fit$stations$bandwidth_i
    w <- EarthFlux:::gwr_kernel_weights(d, b, cfg[[1]])
    loo <- vapply(1:6, function(i) {
      wi <- w[i, ]
      wi[i] <- 0
      beta <- EarthFlux:::gwr_local_wls(cbind(1, s$x), s$y, wi)$beta
      s$y[i] - sum(c(1, s$x[i, ]) * beta)
    }, numeric(1))
    expect_equal(fit$stations$loo_residual, loo, tolerance = 1e-10,
                 info = cfg[[1]])
  }
})

test_that("moment/Cholesky solver equals the QR reference to 1e-10", {
  dat <- gwr_synthetic(2L)
  for (cfg in list(list("bisquare", 40000, FALSE), list("gaussian", 9, TRUE),
                   list("tricube", 30000, FALSE))) {
    fit <- ef_gwr_fit(dat$y, dat$x, dat$coords, cfg[[2]], cfg[[1]],
                      adaptive = cfg[[3]])
    d <- EarthFlux:::gwr_distance(dat$coords, dat$coords)
    w <- EarthFlux:::gwr_kernel_weights(d, fit$stations$bandwidth_i,
                                        cfg[[1]])
    xraw <- cbind(1, dat$x)
    for (i in c(1, 17, 80, 150)) {
      ref <- EarthFlux:::gwr_local_wls(xraw, dat$y, w[i, ], x0 = xraw[i, ])
      expect_equal(unname(fit$coefficients[i, ]), unname(ref$beta),
                   tolerance = 1e-10)
      expect_equal(fit$stations$s_ii[i], ref$hat_row[i], tolerance = 1e-10)
    }
  }
})

test_that("internal scaling changes neither coefficients nor predictions", {
  s <- gwr_small()
  a <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian")
  b <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian",
                  scale_covariates = FALSE)
  expect_equal(a$coefficients, b$coefficients, tolerance = 1e-10)
  expect_equal(a$stations$fitted, b$stations$fitted, tolerance = 1e-10)
  expect_equal(a$fit$aicc, b$fit$aicc, tolerance = 1e-10)
  expect_identical(b$conventions$covariate_scaling, "none")
  newx <- cbind(elevation = c(150, 900))
  newc <- cbind(c(2000, 25000), c(3000, 12000))
  expect_equal(ef_gwr_predict(a, newx, newc)$value,
               ef_gwr_predict(b, newx, newc)$value, tolerance = 1e-10)
})

test_that("AICc identity with K = tr(S) + 1 (section 4.1)", {
  s <- gwr_small()
  f <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian")$fit
  n <- f$n
  k <- f$enp + 1
  expect_equal(n * (n + f$enp) / (n - 2 - f$enp),
               n + 2 * k + 2 * k * (k + 1) / (n - k - 1), tolerance = 1e-12)
  expect_equal(f$aicc - f$aic,
               n * (n + f$enp) / (n - 2 - f$enp) - n - f$enp,
               tolerance = 1e-12)
  expect_equal(f$sigma_ml, sqrt(f$rss / n))
  expect_equal(f$sigma_edf, sqrt(f$rss / f$edf))
  expect_equal(f$rmse_loo, sqrt(f$cv / n))
})

test_that("G4: GWR tends to the global OLS fit", {
  s <- gwr_small()
  box <- ef_gwr_fit(s$y, s$x, s$coords, 1e6, "boxcar")
  g <- box$global_reference
  expect_equal(unname(g$coefficients),
               c(20.75566218809981, -0.00646257197697), tolerance = 1e-12)
  expect_equal(g$rss, 0.08253359, tolerance = 1e-7)
  expect_equal(g$aicc, 9.309406, tolerance = 1e-7)
  expect_equal(g$enp, 2, tolerance = 1e-12)
  ols <- stats::lm(s$y ~ s$x[, 1])
  expect_equal(g$cv, sum((stats::residuals(ols) /
                            (1 - stats::hatvalues(ols)))^2),
               tolerance = 1e-10)
  tol <- sqrt(.Machine$double.eps)
  for (i in 1:6) {
    expect_equal(unname(box$coefficients[i, ]), unname(g$coefficients),
                 tolerance = tol)
  }
  expect_equal(box$fit$enp, 2, tolerance = tol)
  expect_equal(box$fit$aicc, g$aicc, tolerance = tol)
  err <- vapply(c(1e5, 1e6, 1e8), function(b) {
    f <- ef_gwr_fit(s$y, s$x, s$coords, b, "gaussian")
    max(abs(sweep(f$coefficients, 2, f$global_reference$coefficients)))
  }, numeric(1))
  expect_true(all(diff(err) < 0))
  expect_lt(err[3], 1e-8)
  expect_equal(err[1], 1.615e-3, tolerance = 1e-3)
})

test_that("G5: a rank-deficient station design is an error, not a fallback", {
  s <- gwr_small()
  err <- expect_error(ef_gwr_fit(s$y, s$x, s$coords, 5000, "boxcar",
                                 station_id = s$id),
                      class = "earthflux_gwr_singular_error")
  expect_s3_class(err, "earthflux_gwr_error")
  expect_identical(err$stations, s$id)
  # G3: k = 3 bisquare, only the station itself has a non-zero weight at S1
  err3 <- expect_error(ef_gwr_fit(s$y, s$x, s$coords, 3, "bisquare",
                                  adaptive = TRUE, station_id = s$id),
                       class = "earthflux_gwr_singular_error")
  expect_true("S1" %in% err3$stations)
})

test_that("G6: AICc is undefined when n - 2 - tr(S) <= 0", {
  s <- gwr_small()
  f6 <- ef_gwr_fit(s$y, s$x, s$coords, 6000, "gaussian")
  f8 <- ef_gwr_fit(s$y, s$x, s$coords, 8000, "gaussian")
  f12 <- ef_gwr_fit(s$y, s$x, s$coords, 12000, "gaussian")
  expect_equal(c(f6$fit$enp, f8$fit$enp, f12$fit$enp),
               c(5.252969, 4.683610, 3.758735), tolerance = 1e-6)
  expect_true(is.na(f6$fit$aicc))
  expect_true(is.na(f8$fit$aicc))
  expect_equal(f12$fit$aicc, 221.3354, tolerance = 1e-6)
  codes <- function(f) vapply(f$flags, `[[`, "", "code")
  expect_true("EF_GWR_AICC_UNDEFINED" %in% codes(f8))
  expect_false("EF_GWR_AICC_UNDEFINED" %in% codes(f12))
  expect_true("EF_GWR_AICC_UNDEFINED" %in% f12$provenance$flags_evaluated)
  # b = 3 km: numerically singular at the isolated station S6
  expect_error(ef_gwr_fit(s$y, s$x, s$coords, 3000, "gaussian"),
               class = "earthflux_gwr_singular_error")
})

test_that("stations with too few neighbours are flagged (record scope)", {
  s <- gwr_small()
  # gaussian b = 20 km: only S6 itself lies within one bandwidth of S6
  fit <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian")
  f <- fit$flags[[which(vapply(fit$flags, `[[`, "", "code") ==
                          "EF_GWR_FEW_NEIGHBOURS")]]
  expect_identical(f$scope, "record")
  expect_identical(f$index, 6L)
  expect_identical(fit$stations$n_nonzero[6], 1L)
  # negative: a larger bandwidth
  fit2 <- ef_gwr_fit(s$y, s$x, s$coords, 40000, "gaussian")
  expect_false("EF_GWR_FEW_NEIGHBOURS" %in%
                 vapply(fit2$flags, `[[`, "", "code"))
  # the LOO residual is NA where the fit interpolates the station
  y <- s$y
  y[6] <- NA
  fb <- ef_gwr_fit(y, s$x, s$coords, 15000, "boxcar", min_neighbours = 4)
  expect_identical(fb$config$min_neighbours, 4L)
  expect_identical(fb$config$min_neighbours_source, "user")
  ff <- fb$flags[[which(vapply(fb$flags, `[[`, "", "code") ==
                          "EF_GWR_FEW_NEIGHBOURS")]]
  expect_identical(ff$index, 5L)
})

test_that("G7: synthetic reference of 150 stations (integration)", {
  dat <- gwr_synthetic(2L)
  fit <- ef_gwr_fit(dat$y, dat$x, dat$coords, 40000, "bisquare")
  f <- fit$fit
  expect_equal(f$rss, 21.988635, tolerance = 1e-6)
  expect_equal(f$enp, 14.110126, tolerance = 1e-6)
  expect_equal(f$tr_sts, 10.218746, tolerance = 1e-6)
  expect_equal(f$aicc, 171.521589, tolerance = 1e-6)
  expect_equal(f$cv, 27.491712, tolerance = 1e-6)
  expect_equal(f$enp_alt, 18.001507, tolerance = 1e-6)
  fa <- ef_gwr_fit(dat$y, dat$x, dat$coords, 30, "bisquare", adaptive = TRUE)
  expect_equal(fa$fit$aicc, 173.128323, tolerance = 1e-6)
  expect_equal(fa$fit$enp, 22.265331, tolerance = 1e-6)
})

test_that("results do not depend on the order of the stations", {
  dat <- gwr_synthetic(10L)
  perm <- rev(seq_along(dat$y))
  perm <- c(perm[seq(1, 150, 2)], perm[seq(2, 150, 2)])
  id <- sprintf("st%03d", seq_along(dat$y))
  a <- ef_gwr_fit(dat$y, dat$x, dat$coords, 35000, "bisquare",
                  station_id = id)
  b <- ef_gwr_fit(dat$y[perm], dat$x[perm, ], dat$coords[perm, ], 35000,
                  "bisquare", station_id = id[perm])
  expect_equal(b$coefficients[id, ], a$coefficients, tolerance = 1e-12)
  expect_equal(b$fit$aicc, a$fit$aicc, tolerance = 1e-12)
  expect_equal(b$fit$cv, a$fit$cv, tolerance = 1e-12)
  pa <- ef_gwr_predict(a, dat$grid_x, dat$grid_coords)
  pb <- ef_gwr_predict(b, dat$grid_x, dat$grid_coords)
  expect_equal(pb$value, pa$value, tolerance = 1e-12)
})

test_that("the fit is deterministic and keeps the documented structure", {
  s <- gwr_small()
  a <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian")
  b <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian")
  expect_identical(a, b)
  expect_s3_class(a, c("earthflux_gwr", "earthflux_regionalization"))
  expect_named(a, c("call", "variable", "target_time", "unit", "stations",
                    "coefficients", "kernel", "bandwidth", "conventions",
                    "fit", "global_reference", "profile", "search", "flags",
                    "config", "model", "provenance"))
  expect_null(a$profile)
  expect_identical(a$bandwidth$selected_by, "user")
  expect_identical(colnames(a$coefficients), c("(Intercept)", "elevation"))
  expect_true(all(c("station_id", "x", "y", "elevation", "observed",
                    "fitted", "residual", "loo_fitted", "loo_residual",
                    "s_ii", "local_r2", "bandwidth_i", "n_nonzero", "kappa",
                    "rank_ok", "status", "exclusion_reason") %in%
                    names(a$stations)))
  d <- ef_gwr_diagnostics(a)
  expect_named(d, c("fit", "global_reference", "stations", "profile",
                    "flags"))
  expect_identical(d$flags$code, "EF_GWR_FEW_NEIGHBOURS")
  expect_error(ef_gwr_diagnostics(list()), class = "earthflux_input_error")
})
