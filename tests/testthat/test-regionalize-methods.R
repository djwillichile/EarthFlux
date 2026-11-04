# Method objects and prediction control of the regionalization
# (dev/specs/gwr-forcing.md sections 5.1-5.5, 6.1, 9.1 and 9.3).

test_that("ef_method_gwr() validates a fixed bandwidth or a selection", {
  m <- ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 25000)
  expect_s3_class(m, "earthflux_regionalization_method")
  expect_identical(m$method, "gwr")
  expect_identical(m$bandwidth, 25000)
  expect_null(m$criterion)
  k <- ef_method_gwr("gaussian", adaptive = TRUE, bandwidth = 12)
  expect_identical(k$bandwidth, 12L)
  s <- ef_method_gwr("gaussian", adaptive = TRUE, criterion = "AICc",
                     search = ef_gwr_search(k_min = 5))
  expect_identical(s$criterion, "AICc")
  expect_s3_class(s$search, "earthflux_gwr_search")
  expect_output(print(m), "given = 25000 m")
  expect_output(print(s), "selected by AICc")
})

test_that("ef_method_gwr() has no defaults for the scientific choices", {
  expect_error(ef_method_gwr(adaptive = FALSE, bandwidth = 1000),
               class = "earthflux_missing_input")
  expect_error(ef_method_gwr("bisquare", bandwidth = 1000),
               class = "earthflux_missing_input")
  expect_error(ef_method_gwr("bisquare", adaptive = FALSE),
               class = "earthflux_missing_input")
  expect_error(ef_method_gwr("triangle", FALSE, bandwidth = 1000),
               class = "earthflux_unknown_method")
  expect_error(ef_method_gwr("bisquare", FALSE, criterion = "AIC",
                             search = ef_gwr_search()),
               class = "earthflux_unknown_method")
  expect_error(ef_method_gwr("bisquare", FALSE, criterion = "AICc"),
               class = "earthflux_missing_input")
  expect_error(ef_method_gwr("bisquare", FALSE, criterion = "AICc",
                             bandwidth = 1000, search = ef_gwr_search()),
               class = "earthflux_input_error")
  expect_error(ef_method_gwr("bisquare", FALSE, bandwidth = 1000,
                             search = ef_gwr_search()),
               class = "earthflux_input_error")
  expect_error(ef_method_gwr("bisquare", FALSE, criterion = "CV",
                             search = ef_gwr_search(), min_neighbours = 4),
               class = "earthflux_input_error")
  expect_error(ef_method_gwr("bisquare", FALSE, bandwidth = -5),
               class = "earthflux_domain_error")
  expect_error(ef_method_gwr("bisquare", TRUE, bandwidth = 2.5),
               class = "earthflux_domain_error")
  expect_error(ef_method_gwr("bisquare", NA, bandwidth = 1000),
               class = "earthflux_input_error")
})

test_that("ef_method_station() requires the representative station", {
  m <- ef_method_station("S05")
  expect_identical(m$method, "station")
  expect_null(m$lapse_rate)
  l <- ef_method_station("S05", lapse_rate = -0.0065)
  expect_identical(l$method, "station_lapse")
  expect_identical(l$lapse_rate, -0.0065)
  expect_identical(ef_method_station(7)$station_id, "7")
  expect_output(print(l), "lapse rate")
  expect_error(ef_method_station(), class = "earthflux_missing_input")
  expect_error(ef_method_station(c("A", "B")), class = "earthflux_input_error")
  expect_error(ef_method_station("A", lapse_rate = Inf),
               class = "earthflux_domain_error")
  expect_error(ef_method_station("A", lapse_rate = "x"),
               class = "earthflux_input_error")
})

test_that("ef_method_ols() and ef_method_idw() build C2 methods", {
  expect_identical(ef_method_ols()$method, "global_ols")
  expect_output(print(ef_method_ols()), "global ordinary least squares")
  m <- ef_method_idw(2)
  expect_identical(m$method, "idw")
  expect_identical(m$power, 2)
  g <- ef_method_idw(c(3, 1, 2))
  expect_identical(g$power, c(1, 2, 3))
  expect_output(print(g), "LOOCV")
  expect_error(ef_method_idw(), class = "earthflux_missing_input")
  expect_error(ef_method_idw(0), class = "earthflux_domain_error")
  expect_error(ef_method_idw(c(2, 2)), class = "earthflux_input_error")
  expect_error(ef_method_idw("2"), class = "earthflux_input_error")
})

test_that("ef_predict_control() validates the settings", {
  ctl <- ef_predict_control()
  expect_s3_class(ctl, "earthflux_predict_control")
  expect_identical(ctl$mode, "exact")
  expect_null(ctl$block_rows)
  expect_identical(ctl$flags_filename, "")
  f <- ef_predict_control(block_rows = 10, filename = "out/ta.tif")
  expect_identical(f$block_rows, 10L)
  expect_identical(f$flags_filename, "out/ta_flags.tif")
  expect_identical(ef_predict_control(filename = "ta")$flags_filename,
                   "ta_flags")
  expect_output(print(f), "block rows: 10")
  expect_error(ef_predict_control(mode = "coarse"),
               class = "earthflux_unknown_method")
  expect_error(ef_predict_control(block_rows = 0),
               class = "earthflux_domain_error")
  expect_error(ef_predict_control(chunk_rows = 1.5),
               class = "earthflux_input_error")
  expect_error(ef_predict_control(filename = NA_character_),
               class = "earthflux_input_error")
  expect_error(ef_predict_control(filename = "a.tif",
                                  flags_filename = "a.tif"),
               class = "earthflux_input_error")
  expect_error(ef_predict_control(wopt = list(1)),
               class = "earthflux_input_error")
})
