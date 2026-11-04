# GWR prediction at new locations (dev/specs/gwr-forcing.md sections 6.1,
# 6.3, 9.4 and 11).

flag_of <- function(pred, code) {
  hit <- vapply(pred$flags, `[[`, "", "code") == code
  if (any(hit)) pred$flags[[which(hit)]] else NULL
}

test_that("prediction at the stations reproduces the fitted values", {
  dat <- gwr_synthetic(2L)
  for (cfg in list(list("bisquare", 40000, FALSE), list("gaussian", 12, TRUE),
                   list("boxcar", 30000, FALSE))) {
    fit <- ef_gwr_fit(dat$y, dat$x, dat$coords, cfg[[2]], cfg[[1]],
                      adaptive = cfg[[3]])
    p <- ef_gwr_predict(fit, dat$x, dat$coords)
    expect_equal(p$value, fit$stations$fitted, tolerance = 1e-10)
    expect_equal(p$coefficients, unname(fit$coefficients),
                 tolerance = 1e-10, ignore_attr = TRUE)
    expect_equal(p$bandwidth, fit$stations$bandwidth_i)
    expect_identical(p$n_nonzero, fit$stations$n_nonzero)
  }
})

test_that("the result does not depend on the block size", {
  dat <- gwr_synthetic(40L)
  for (cfg in list(list("bisquare", 35000, FALSE),
                   list("gaussian", 20, TRUE))) {
    fit <- ef_gwr_fit(dat$y, dat$x, dat$coords, cfg[[2]], cfg[[1]],
                      adaptive = cfg[[3]])
    whole <- ef_gwr_predict(fit, dat$grid_x, dat$grid_coords)
    small <- ef_gwr_predict(fit, dat$grid_x, dat$grid_coords,
                            chunk_rows = 37)
    expect_identical(small, whole)
    # calls on blocks of rows, as the raster orchestrator does
    n <- nrow(dat$grid_x)
    cuts <- list(1:250, 251:1013, 1014:n)
    parts <- lapply(cuts, function(r) {
      ef_gwr_predict(fit, dat$grid_x[r, ], dat$grid_coords[r, ])
    })
    expect_identical(unlist(lapply(parts, `[[`, "value")), whole$value)
    expect_identical(do.call(rbind, lapply(parts, `[[`, "coefficients")),
                     whole$coefficients)
    expect_identical(unlist(lapply(parts, `[[`, "n_nonzero")),
                     whole$n_nonzero)
    word_whole <- EarthFlux:::gwr_flag_word(whole$flags, n)
    word_parts <- unlist(Map(function(p, r) {
      EarthFlux:::gwr_flag_word(p$flags, length(r))
    }, parts, cuts))
    expect_identical(word_parts, word_whole)
  }
})

test_that("missing covariates or coordinates give NA and EF_INPUT_NA", {
  s <- gwr_small()
  fit <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian")
  newx <- cbind(elevation = c(250, NA, 400))
  newc <- cbind(c(5000, 6000, NA), c(5000, 6000, 1000))
  p <- ef_gwr_predict(fit, newx, newc)
  expect_true(is.finite(p$value[1]))
  expect_true(all(is.na(p$value[2:3])))
  expect_true(all(is.na(p$coefficients[2:3, ])))
  expect_identical(p$n_nonzero[2:3], c(NA_integer_, NA_integer_))
  expect_identical(flag_of(p, "EF_INPUT_NA")$index, 2:3)
  expect_null(flag_of(p, "EF_GWR_EXTRAPOLATION_COVARIATE"))
  expect_null(flag_of(p, "EF_GWR_OUTSIDE_HULL"))
})

test_that("covariate extrapolation and convex hull flags (section 6.3)", {
  s <- gwr_small()
  fit <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian")
  # 1: inside everything; 2: elevation above the station range;
  # 3: outside the hull; 4: on a hull vertex (a station); 5: on a hull edge
  newx <- cbind(elevation = c(300, 1500, 300, 100, 500))
  newc <- cbind(c(5000, 5000, 40000, 0, 10000), c(5000, 5000, 40000, 0, 0))
  p <- ef_gwr_predict(fit, newx, newc)
  expect_identical(flag_of(p, "EF_GWR_EXTRAPOLATION_COVARIATE")$index, 2L)
  expect_identical(flag_of(p, "EF_GWR_OUTSIDE_HULL")$index, 3L)
  # values are kept: extrapolation is flagged, not masked
  expect_true(all(is.finite(p$value)))
  # local range only evaluated for compact kernels
  expect_false("EF_GWR_EXTRAPOLATION_LOCAL" %in% attr(p$flags, "evaluated"))
  expect_true(all(c("EF_INPUT_NA", "EF_GWR_EXTRAPOLATION_COVARIATE",
                    "EF_GWR_OUTSIDE_HULL", "EF_GWR_FEW_NEIGHBOURS",
                    "EF_GWR_LOCAL_SINGULAR") %in% attr(p$flags, "evaluated")))
  # negative case: all locations inside
  q <- ef_gwr_predict(fit, cbind(elevation = c(300, 600)),
                      cbind(c(5000, 12000), c(5000, 8000)))
  expect_length(q$flags, 0L)
})

test_that("convex hull handles collinear and coincident stations", {
  pts <- cbind(c(0, 1, 2, 3), c(0, 1, 2, 3))
  h <- EarthFlux:::gwr_convex_hull(pts)
  expect_identical(nrow(h), 2L)
  inside <- EarthFlux:::gwr_in_hull(cbind(c(1.5, 1.5, 4), c(1.5, 1.6, 4)), h,
                                    pts)
  expect_identical(inside, c(TRUE, FALSE, FALSE))
  sq <- cbind(c(0, 1, 1, 0, 0.5, 0.5), c(0, 0, 1, 1, 0.5, 0))
  hs <- EarthFlux:::gwr_convex_hull(sq)
  expect_identical(nrow(hs), 4L)
  expect_identical(EarthFlux:::gwr_in_hull(cbind(c(0.5, 1, 1.2),
                                                 c(0.5, 0.3, 0.5)), hs, sq),
                   c(TRUE, TRUE, FALSE))
  one <- EarthFlux:::gwr_convex_hull(cbind(c(2, 2), c(3, 3)))
  expect_identical(EarthFlux:::gwr_in_hull(cbind(c(2, 2.5), c(3, 3)), one,
                                           cbind(2, 3)),
                   c(TRUE, FALSE))
})

test_that("local range, few neighbours and singular cells (compact kernel)", {
  s <- gwr_small()
  y <- s$y
  y[6] <- NA
  fit <- ef_gwr_fit(y, s$x, s$coords, 15000, "boxcar", station_id = s$id)
  # 1: near S1-S4, elevation inside their local range (100-500)
  # 2: same place, elevation 700 (inside the global range 100-800, outside
  #    the local one)
  # 3: near S5 only (S5 at 12 km, S2 at 22 km): rank-deficient design;
  #    600 m is also outside the local range (S5 only, 800 m)
  # 4: three stations within 15 km (S2, S4, S5) = p + 1: not flagged
  newx <- cbind(elevation = c(300, 700, 600, 500))
  newc <- cbind(c(5000, 5000, 32000, 20000), c(5000, 5000, 0, 10000))
  p <- ef_gwr_predict(fit, newx, newc)
  expect_identical(flag_of(p, "EF_GWR_EXTRAPOLATION_LOCAL")$index, 2:3)
  expect_null(flag_of(p, "EF_GWR_EXTRAPOLATION_COVARIATE"))
  expect_identical(p$n_nonzero[3], 1L)
  expect_identical(flag_of(p, "EF_GWR_LOCAL_SINGULAR")$index, 3L)
  expect_true(is.na(p$value[3]))
  expect_true(all(is.na(p$coefficients[3, ])))
  expect_true(all(is.finite(p$value[-3])))
  # few neighbours: n_nonzero < min_neighbours (3), value kept if full rank
  few <- flag_of(p, "EF_GWR_FEW_NEIGHBOURS")
  expect_identical(few$index, which(p$n_nonzero < 3L))
  expect_identical(few$scope, "cell")
  expect_identical(p$n_nonzero[4], 3L) # S2, S4, S5 within 15 km
  # a cell with two stations within 15 km (S2, S5): full rank, flagged
  q <- ef_gwr_predict(fit, cbind(elevation = 500),
                      cbind(15000, -8000))
  expect_identical(q$n_nonzero, 2L)
  expect_true(is.finite(q$value))
  expect_identical(flag_of(q, "EF_GWR_FEW_NEIGHBOURS")$index, 1L)
  expect_null(flag_of(q, "EF_GWR_LOCAL_SINGULAR"))
})

test_that("the flag word packs the registry bits", {
  s <- gwr_small()
  y <- s$y
  y[6] <- NA
  fit <- ef_gwr_fit(y, s$x, s$coords, 15000, "boxcar")
  p <- ef_gwr_predict(fit, cbind(elevation = c(300, 700, 600, NA)),
                      cbind(c(5000, 5000, 32000, 0), c(5000, 5000, 0, 0)))
  w <- EarthFlux:::gwr_flag_word(p$flags, 4L)
  # bit 2 local range; bits 2 (local range), 3 (outside hull: (32000, 0)
  # is beyond S5), 4 (few neighbours) and 5 (singular); bit 0 missing input
  expect_identical(w, c(0L, 4L, 4L + 8L + 16L + 32L, 1L))
})

test_that("prediction inputs are validated", {
  s <- gwr_small()
  fit <- ef_gwr_fit(s$y, s$x, s$coords, 20000, "gaussian")
  nc <- cbind(1000, 1000)
  expect_error(ef_gwr_predict(list(), cbind(elevation = 1), nc),
               class = "earthflux_input_error")
  expect_error(ef_gwr_predict(fit, cbind(elev = 1), nc),
               class = "earthflux_input_error")
  expect_error(ef_gwr_predict(fit, cbind(elevation = 1, z = 2), nc),
               class = "earthflux_input_error")
  expect_error(ef_gwr_predict(fit, cbind(elevation = c(1, 2)), nc),
               class = "earthflux_input_error")
  expect_error(ef_gwr_predict(fit, cbind(elevation = 1), cbind(1, 2, 3)),
               class = "earthflux_input_error")
  expect_error(ef_gwr_predict(fit, cbind(elevation = numeric(0)),
                              matrix(numeric(0), 0, 2)),
               class = "earthflux_input_error")
  expect_error(ef_gwr_predict(fit, cbind(elevation = Inf), nc),
               class = "earthflux_domain_error")
  expect_error(ef_gwr_predict(fit, cbind(elevation = 1), nc, chunk_rows = 0),
               class = "earthflux_domain_error")
  # data frames and reordered columns are accepted
  two <- ef_gwr_fit(s$y, cbind(s$x, slope = c(1, 3, 2, 5, 4, 6)), s$coords,
                    25000, "gaussian")
  a <- ef_gwr_predict(two, cbind(elevation = 300, slope = 2), nc)
  b <- ef_gwr_predict(two, data.frame(slope = 2, elevation = 300), nc)
  expect_identical(a$value, b$value)
})
