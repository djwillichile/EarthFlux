# GWR core: kernels, conventions, input checks and flag registry
# (dev/specs/gwr-forcing.md sections 3.4, 3.5, 9.3, 9.4, 11 and 12).

test_that("kernel values at r = 0, 0.5, 1, 2 follow section 3.4", {
  d <- matrix(c(0, 0.5, 1, 2), nrow = 1)
  w <- function(k) as.vector(EarthFlux:::gwr_kernel_weights(d, 1, k))
  expect_equal(w("gaussian"), exp(-0.5 * c(0, 0.25, 1, 4)))
  expect_equal(w("exponential"), exp(-c(0, 0.5, 1, 2)))
  expect_equal(w("bisquare"), c(1, (1 - 0.25)^2, 0, 0))
  expect_equal(w("tricube"), c(1, (1 - 0.125)^3, 0, 0))
  # boxcar support d <= b (decision GW-03)
  expect_equal(w("boxcar"), c(1, 1, 1, 0))
  for (k in EarthFlux:::gwr_kernels()) {
    expect_true(all(diff(w(k)) <= 0), info = k)
  }
})

test_that("compact kernels give zero weight beyond the bandwidth", {
  d <- matrix(c(0.999, 1, 1.001, 50), nrow = 1)
  for (k in c("bisquare", "tricube")) {
    w <- as.vector(EarthFlux:::gwr_kernel_weights(d, 1, k))
    expect_gt(w[1], 0)
    expect_identical(w[2:4], c(0, 0, 0))
  }
})

test_that("G3: adaptive bandwidth counts the point itself (bisquare at S1)", {
  s <- gwr_small()
  d1 <- EarthFlux:::gwr_distance(s$coords[1, , drop = FALSE], s$coords)
  b <- vapply(2:5, function(k) {
    EarthFlux:::gwr_row_bandwidth(d1, k, adaptive = TRUE)
  }, numeric(1))
  expect_equal(b, c(10000, 10000, 10000 * sqrt(2), 20000))
  w <- lapply(b, function(bi) {
    as.vector(EarthFlux:::gwr_kernel_weights(d1, bi, "bisquare"))
  })
  expect_equal(w[[1]], c(1, 0, 0, 0, 0, 0))
  expect_equal(w[[2]], c(1, 0, 0, 0, 0, 0))
  expect_equal(w[[3]], c(1, 0.25, 0.25, 0, 0, 0))
  expect_equal(w[[4]], c(1, 0.5625, 0.5625, 0.25, 0, 0))
  # boxcar adaptive with k = 3 includes the tie at d = b (as GWmodel)
  bx <- EarthFlux:::gwr_kernel_weights(d1, b[2], "boxcar")
  expect_equal(as.vector(bx), c(1, 1, 1, 0, 0, 0))
})

test_that("the kernel requested is the kernel used and recorded", {
  s <- gwr_small()
  for (k in c("gaussian", "exponential")) {
    fit <- ef_gwr_fit(s$y, s$x, s$coords, bandwidth = 20000, kernel = k)
    expect_identical(fit$kernel, k)
    d <- EarthFlux:::gwr_distance(s$coords, s$coords)
    w <- EarthFlux:::gwr_kernel_weights(d, rep(20000, 6), k)
    ref <- EarthFlux:::gwr_local_wls(cbind(1, s$x), s$y, w[1, ])$beta
    expect_equal(unname(fit$coefficients[1, ]), unname(ref),
                 tolerance = 1e-10)
  }
  fit <- ef_gwr_fit(s$y, s$x, s$coords, bandwidth = 5, kernel = "bisquare",
                    adaptive = TRUE)
  expect_identical(fit$bandwidth$type, "adaptive")
  expect_identical(fit$bandwidth$unit, "neighbours")
  expect_identical(fit$conventions$k_convention,
                   "kth_nearest_including_self")
  expect_identical(fit$conventions$boxcar_support, "le")
  expect_identical(fit$conventions$aicc_definition,
                   "gollini2015_tr_S_sigma_ml")
})

test_that("kernel and criterion have no default", {
  s <- gwr_small()
  expect_error(ef_gwr_fit(s$y, s$x, s$coords, bandwidth = 20000),
               class = "earthflux_missing_input")
  expect_error(ef_gwr_fit(s$y, s$x, s$coords, 20000, kernel = "gauss"),
               class = "earthflux_unknown_method")
  expect_error(ef_gwr_fit(s$y, s$x, s$coords, kernel = "gaussian"),
               class = "earthflux_missing_input")
  srch <- ef_gwr_search(n_grid = 10, tol = 1, upper_factor = 2)
  expect_error(ef_gwr_bandwidth(s$y, s$x, s$coords, kernel = "gaussian",
                                search = srch),
               class = "earthflux_missing_input")
  expect_error(ef_gwr_bandwidth(s$y, s$x, s$coords, kernel = "gaussian",
                                criterion = "aicc", search = srch),
               class = "earthflux_unknown_method")
  expect_error(ef_gwr_bandwidth(s$y, s$x, s$coords, criterion = "AICc",
                                search = srch),
               class = "earthflux_missing_input")
  expect_error(ef_gwr_bandwidth(s$y, s$x, s$coords, kernel = "gaussian",
                                criterion = "AICc"),
               class = "earthflux_missing_input")
})

test_that("input errors carry the classes of section 9.3", {
  s <- gwr_small()
  fit <- function(...) ef_gwr_fit(...)
  # dimensions (earthflux_input_error; no separate dimension class)
  expect_error(fit(s$y[-1], s$x, s$coords, 20000, "gaussian"),
               class = "earthflux_input_error")
  expect_error(fit(s$y, s$x, s$coords[, 1, drop = FALSE], 20000, "gaussian"),
               class = "earthflux_input_error")
  expect_error(fit(s$y, unname(s$x), s$coords, 20000, "gaussian"),
               class = "earthflux_input_error")
  expect_error(fit(s$y, cbind(x = s$x[, 1]), s$coords, 20000, "gaussian"),
               class = "earthflux_input_error")
  expect_error(fit(as.character(s$y), s$x, s$coords, 20000, "gaussian"),
               class = "earthflux_input_error")
  expect_error(fit(numeric(0), s$x[0, , drop = FALSE], s$coords[0, ],
                   20000, "gaussian"),
               class = "earthflux_input_error")
  expect_error(fit(s$y, s$x, s$coords, 20000, "gaussian",
                   station_id = rep("a", 6)),
               class = "earthflux_input_error")
  # domain: Inf, bandwidth <= 0, k outside [1, n] or not whole
  y_inf <- s$y
  y_inf[2] <- Inf
  expect_error(fit(y_inf, s$x, s$coords, 20000, "gaussian"),
               class = "earthflux_domain_error")
  co_inf <- s$coords
  co_inf[1, 1] <- -Inf
  expect_error(fit(s$y, s$x, co_inf, 20000, "gaussian"),
               class = "earthflux_domain_error")
  expect_error(fit(s$y, s$x, s$coords, 0, "gaussian"),
               class = "earthflux_domain_error")
  expect_error(fit(s$y, s$x, s$coords, Inf, "gaussian"),
               class = "earthflux_domain_error")
  expect_error(fit(s$y, s$x, s$coords, 3.5, "gaussian", adaptive = TRUE),
               class = "earthflux_domain_error")
  expect_error(fit(s$y, s$x, s$coords, 7, "gaussian", adaptive = TRUE),
               class = "earthflux_domain_error")
  expect_error(fit(s$y, s$x, s$coords, 20000, "gaussian",
                   min_neighbours = 2),
               class = "earthflux_domain_error")
  expect_error(fit(s$y, s$x, s$coords, 20000, "gaussian", adaptive = NA),
               class = "earthflux_input_error")
  # constant covariate among the stations
  x2 <- cbind(s$x, flat = 5)
  expect_error(fit(s$y, x2, s$coords, 20000, "gaussian"),
               class = "earthflux_input_error")
  # identical coordinates and covariates: degenerate design
  co <- s$coords
  co[2, ] <- co[1, ]
  xx <- s$x
  xx[2, ] <- xx[1, ]
  expect_error(fit(s$y, xx, co, 20000, "gaussian"),
               class = "earthflux_input_error")
  # identical coordinates with distinct covariates are allowed
  expect_s3_class(fit(s$y, s$x, co, 20000, "gaussian"), "earthflux_gwr")
})

test_that("n < p + 3 raises earthflux_gwr_insufficient_stations", {
  s <- gwr_small()
  y <- s$y
  y[5:6] <- NA
  err <- expect_error(ef_gwr_fit(y, s$x, s$coords, 20000, "gaussian"),
                      class = "earthflux_gwr_insufficient_stations")
  expect_s3_class(err, "earthflux_gwr_error")
  expect_identical(c(err$n, err$p), c(4L, 2L))
  expect_error(
    ef_gwr_bandwidth(y, s$x, s$coords, "gaussian", criterion = "AICc",
                     search = ef_gwr_search(n_grid = 5, tol = 1,
                                            upper_factor = 2)),
    class = "earthflux_gwr_insufficient_stations"
  )
})

test_that("stations with NA are excluded with their reason, never silently", {
  s <- gwr_small()
  y <- c(s$y, 18, 17)
  x <- rbind(s$x, 400, NA)
  co <- rbind(s$coords, c(5000, 5000), c(15000, 15000))
  y[2] <- NA
  co[3, 2] <- NA
  fit <- ef_gwr_fit(y, x, co, 30000, "gaussian",
                    station_id = c(s$id, "S7", "S8"))
  st <- fit$stations
  expect_identical(st$status,
                   c("used", "excluded", "excluded", "used", "used", "used",
                     "used", "excluded"))
  expect_identical(st$exclusion_reason[c(2, 3, 8)],
                   c("missing_response", "missing_coordinates",
                     "missing_covariate:elevation"))
  expect_true(all(is.na(st$fitted[c(2, 3, 8)])))
  expect_identical(fit$fit$n, 5L)
  expect_identical(rownames(fit$coefficients),
                   c("S1", "S4", "S5", "S6", "S7"))
  f <- fit$flags[[which(vapply(fit$flags, `[[`, "", "code") ==
                          "EF_GWR_STATION_EXCLUDED")]]
  expect_identical(f$index, c(2L, 3L, 8L))
  expect_identical(f$scope, "record")
  expect_identical(f$n_total, 8L)
  # negative: complete data
  fit2 <- ef_gwr_fit(s$y, s$x, s$coords, 30000, "gaussian")
  expect_false("EF_GWR_STATION_EXCLUDED" %in%
                 vapply(fit2$flags, `[[`, "", "code"))
  expect_true("EF_GWR_STATION_EXCLUDED" %in%
                fit2$provenance$flags_evaluated)
})

test_that("ef_flags_gwr() registers class I codes with the planned bits", {
  reg <- EarthFlux:::ef_flag_registry()
  gwr <- reg[reg$stage == "GWR", ]
  expect_identical(
    gwr$bit[match(c("EF_GWR_EXTRAPOLATION_COVARIATE",
                    "EF_GWR_EXTRAPOLATION_LOCAL", "EF_GWR_OUTSIDE_HULL",
                    "EF_GWR_FEW_NEIGHBOURS", "EF_GWR_LOCAL_SINGULAR"),
                  gwr$code)],
    1:5
  )
  expect_false(any(c("EF_GWR_FAR_FROM_STATIONS", "EF_GWR_ILL_CONDITIONED",
                     "EF_GWR_FEW_STATIONS", "EF_GWR_ELEVATION_MISMATCH") %in%
                     reg$code))
  expect_identical(gwr$error_class[gwr$code == "EF_GWR_LOCAL_SINGULAR"],
                   "earthflux_gwr_singular_error")
})

test_that("print, summary and as.data.frame describe the fit", {
  s <- gwr_small()
  fit <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian",
                    station_id = s$id)
  expect_output(print(fit), "kernel: gaussian")
  expect_output(print(fit), "AICc with ML sigma and tr\\(S\\)")
  expect_output(print(fit), "EF_GWR_FEW_NEIGHBOURS")
  sm <- summary(fit)
  expect_s3_class(sm, "summary.earthflux_gwr")
  expect_output(print(sm), "Local coefficients")
  expect_identical(as.data.frame(fit), fit$stations)
  srch <- ef_gwr_search(n_grid = 10, tol = 1, upper_factor = 2)
  bw <- ef_gwr_bandwidth(s$y, s$x, s$coords, "gaussian", criterion = "CV",
                         search = srch)
  expect_output(print(bw), "earthflux_gwr_bandwidth")
  fit2 <- ef_gwr_fit(s$y, s$x, s$coords, bandwidth = bw)
  expect_output(print(summary(fit2)), "Profile:")
})
