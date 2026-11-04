# Spatial block folds and cross-validation of the regionalization
# (dev/specs/gwr-forcing.md sections 8.1-8.4 and 11; dev/VALIDATION_PLAN.md
# sections 2.2 and 2.6). Synthetic data only (helper-regionalize.R).

cv_run <- function(method, folds, data = rgn_test_data(),
                   grid = rgn_test_grid(), ...) {
  ef_regionalize_cv(data, "air_temperature", grid, method, folds = folds,
                    use_qc = "ok", surface_covariates = character(0), ...)
}

test_that("ef_spatial_folds() assigns square tiles deterministically", {
  xy <- data.frame(station_id = c("A", "B", "C", "D", "E"),
                   x = c(1000, 4000, 12000, 26000, 9999),
                   y = c(2000, 9000, 3000, 21000, 10001))
  f <- ef_spatial_folds(xy, block_size = 10000)
  # origin = (1000, 2000): tiles (ix, iy) = (0,0) (0,0) (1,0) (2,1) (0,0)
  expect_identical(as.vector(f), c(1L, 1L, 2L, 3L, 1L))
  expect_named(f, xy$station_id)
  expect_identical(attr(f, "block_size"), 10000)
  expect_identical(attr(f, "origin"), c(x = 1000, y = 2000))
  expect_identical(attr(f, "tile")$ix, c(0L, 0L, 1L, 2L, 0L))
  g <- ef_spatial_folds(xy, block_size = 10000, origin = c(0, 0))
  # tiles (0,0) (0,0) (1,0) (2,2) (0,1): ordered by iy, then ix
  expect_identical(as.vector(g), c(1L, 1L, 2L, 4L, 3L))
  expect_identical(ef_spatial_folds(xy, 10000), f)
  # matrix with row names, data frame of two columns, SpatVector
  m <- as.matrix(xy[, c("x", "y")])
  rownames(m) <- xy$station_id
  expect_identical(ef_spatial_folds(m, 10000), f)
  expect_null(names(ef_spatial_folds(xy[, c("x", "y")], 10000)))
  v <- terra::vect(xy, geom = c("x", "y"), crs = "EPSG:32719")
  expect_identical(ef_spatial_folds(v, 10000), f)
  # duplicated station rows (several target times) give one fold each
  expect_identical(ef_spatial_folds(rbind(xy, xy), 10000), f)
})

test_that("ef_spatial_folds() rejects invalid inputs", {
  xy <- cbind(c(0, 1), c(0, 1))
  expect_error(ef_spatial_folds(xy), class = "earthflux_missing_input")
  expect_error(ef_spatial_folds(xy, 0), class = "earthflux_domain_error")
  expect_error(ef_spatial_folds(xy, Inf), class = "earthflux_domain_error")
  expect_error(ef_spatial_folds(cbind(1:3), 10),
               class = "earthflux_input_error")
  expect_error(ef_spatial_folds(cbind(c(0, NA), c(0, 1)), 10),
               class = "earthflux_input_error")
  expect_error(ef_spatial_folds(xy, 10, origin = 0),
               class = "earthflux_input_error")
  dup <- data.frame(station_id = c("A", "A"), x = c(0, 1), y = c(0, 0))
  expect_error(ef_spatial_folds(dup, 10), class = "earthflux_input_error")
  expect_error(ef_spatial_folds(data.frame(x = "a", y = 1), 10),
               class = "earthflux_input_error")
})

test_that("cross-validation predicts each fold from the other folds", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  folds <- ef_spatial_folds(rgn_test_xy(dat), block_size = 20000)
  cv <- cv_run(ef_method_ols(), folds, dat, grid)
  expect_s3_class(cv, "earthflux_regionalization_cv")
  p <- as.data.frame(cv)
  expect_identical(p, cv$predictions)
  expect_named(p, c("station_id", "fold", "variable", "target_time",
                    "observed", "predicted", "residual", "method", "status",
                    "reason", "n_train", "tuning", "flag_word"))
  expect_identical(nrow(p), nrow(dat))
  expect_true(all(p$status == "ok"))
  expect_identical(p$fold, unname(folds[p$station_id]))
  expect_equal(p$residual, p$observed - p$predicted)
  # one fold by hand: OLS fitted without the fold, predicted at the fold
  t1 <- min(dat$target_time)
  st <- dat[dat$target_time == t1, ]
  x <- terra::extract(grid, attr(dat, "xy"))
  test <- folds[st$station_id] == 3L
  d <- data.frame(y = st$value, e = x$elevation, c = x$distance_to_coast)
  m <- stats::lm(y ~ e + c, data = d[!test, ])
  rows <- p$target_time == t1 & p$fold == 3L
  expect_equal(p$predicted[rows][order(p$station_id[rows])],
               unname(stats::predict(m, d[test, ]))[
                 order(st$station_id[test])],
               tolerance = 1e-10)
  expect_identical(unique(p$n_train[rows]), sum(!test))
  expect_identical(cv$provenance$selection, "not_applicable")
  expect_identical(cv$provenance$folds$rule, "square_tiles")
  expect_identical(cv$provenance$folds$block_size, 20000)
  expect_output(print(cv), "earthflux_regionalization_cv")
})

test_that("folds of size one give leave-one-out residuals", {
  dat <- rgn_test_data(n_times = 1L)
  grid <- rgn_test_grid()
  ids <- unique(dat$station_id)
  loo <- stats::setNames(seq_along(ids), ids)
  for (m in list(ef_method_ols(), ef_method_idw(2),
                 ef_method_gwr("bisquare", adaptive = FALSE,
                               bandwidth = 30000))) {
    cv <- cv_run(m, loo, dat, grid)
    s <- ef_regionalize(dat, "air_temperature", grid, m, use_qc = "ok",
                        surface_covariates = character(0))
    p <- cv$predictions[match(s$station_table$station_id,
                              cv$predictions$station_id), ]
    expect_equal(p$predicted, s$station_table$loo_fitted, tolerance = 1e-8)
  }
})

test_that("the same folds give paired predictions for C1, C2 and C3", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  folds <- ef_spatial_folds(rgn_test_xy(dat), block_size = 20000)
  runs <- list(
    c1 = cv_run(ef_method_station("S05"), folds, dat, grid),
    ols = cv_run(ef_method_ols(), folds, dat, grid),
    idw = cv_run(ef_method_idw(2), folds, dat, grid),
    gwr = cv_run(ef_method_gwr("gaussian", adaptive = TRUE,
                               criterion = "AICc",
                               search = ef_gwr_search()), folds, dat, grid)
  )
  key <- function(p) paste(p$station_id, p$target_time, p$fold)
  for (r in runs) {
    expect_identical(key(r$predictions), key(runs$ols$predictions))
    expect_identical(r$folds, runs$ols$folds)
  }
  c1 <- runs$c1$predictions
  rep_rows <- c1$station_id == "S05"
  expect_true(all(c1$status[rep_rows] == "representative_station"))
  expect_true(all(is.na(c1$predicted[rep_rows])))
  expect_true(all(c1$status[!rep_rows] == "ok"))
  # C1 predicts the representative value everywhere, also in its own fold
  for (t in unique(dat$target_time)) {
    v <- dat$value[dat$station_id == "S05" & dat$target_time == t]
    expect_true(all(c1$predicted[!rep_rows & c1$target_time == t] == v))
  }
  expect_true("EF_GWR_SINGLE_STATION" %in%
                vapply(runs$c1$flags, `[[`, "", "code"))
  expect_identical(runs$gwr$provenance$selection, "nested_in_each_fold")
  expect_true(all(!is.na(runs$gwr$predictions$tuning)))
  expect_true(all(runs$idw$predictions$tuning == 2))
})

test_that("reselect_bandwidth = FALSE keeps the bandwidth of all stations", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  folds <- ef_spatial_folds(rgn_test_xy(dat), block_size = 20000)
  m <- ef_method_gwr("gaussian", adaptive = TRUE, criterion = "AICc",
                     search = ef_gwr_search())
  nested <- cv_run(m, folds, dat, grid)
  fixed <- cv_run(m, folds, dat, grid, reselect_bandwidth = FALSE)
  expect_identical(fixed$provenance$selection, "conditional_on_all_stations")
  expect_false(fixed$reselect_bandwidth)
  s <- ef_regionalize(dat, "air_temperature", grid, m, use_qc = "ok",
                      surface_covariates = character(0))
  for (k in seq_along(s$target_time)) {
    rows <- fixed$predictions$target_time == s$target_time[k]
    expect_true(all(fixed$predictions$tuning[rows] ==
                      s$diagnostics[[k]]$bandwidth$value))
  }
  expect_gt(length(unique(nested$predictions$tuning)), 1L)
  # IDW power grid: selected once per target time
  idw <- cv_run(ef_method_idw(c(1, 2, 3)), folds, dat, grid,
                reselect_bandwidth = FALSE)
  expect_identical(length(unique(idw$predictions$tuning[
    idw$predictions$target_time == min(dat$target_time)])), 1L)
  # without a selection the argument has no effect
  ols <- cv_run(ef_method_ols(), folds, dat, grid,
                reselect_bandwidth = FALSE)
  expect_identical(ols$provenance$selection, "not_applicable")
})

test_that("failed folds are reported, never dropped", {
  dat <- rgn_test_data(n = 12L, n_times = 1L)
  grid <- rgn_test_grid()
  ids <- unique(dat$station_id)
  # fold 1 leaves too few training stations for GWR (p + 3 = 6)
  folds <- stats::setNames(c(rep(1L, 8), rep(2L, 4)), ids)
  cv <- cv_run(ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 60000),
               folds, dat, grid)
  p <- cv$predictions
  expect_identical(nrow(p), 12L)
  failed <- p$fold == 1L
  expect_true(all(p$status[failed] == "failed"))
  expect_true(all(is.na(p$predicted[failed])))
  expect_true(all(grepl("earthflux_gwr_insufficient_stations",
                        p$reason[failed])))
  expect_true(all(p$status[!failed] == "ok"))
  expect_identical(cv$provenance$n_failed, 1L)
  expect_output(print(cv), "1 failed|8 failed")
})

test_that("cross-validation is reproducible and independent of the plan", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  folds <- ef_spatial_folds(rgn_test_xy(dat), block_size = 20000)
  m <- ef_method_idw(c(1, 2))
  a <- cv_run(m, folds, dat, grid)
  b <- cv_run(m, folds, dat, grid)
  expect_identical(a$predictions, b$predictions)
  # folds given as a data frame
  fd <- data.frame(station_id = names(folds), fold = unname(folds))
  c3 <- cv_run(m, fd, dat, grid)
  expect_identical(c3$predictions, a$predictions)
  expect_identical(c3$provenance$folds$rule, "user")
  skip_on_cran()
  skip_unless_installed_namespace()
  oplan <- future::plan(future::multisession, workers = 2)
  on.exit(future::plan(oplan), add = TRUE)
  par <- cv_run(m, folds, dat, grid)
  future::plan(oplan)
  expect_identical(par$predictions, a$predictions)
  expect_identical(par$provenance$execution$workers, 2L)
})

test_that("ef_regionalize_cv() rejects invalid inputs", {
  dat <- rgn_test_data(n_times = 1L)
  grid <- rgn_test_grid()
  folds <- ef_spatial_folds(rgn_test_xy(dat), block_size = 20000)
  expect_error(cv_run(ef_method_ols(), NULL, dat, grid),
               class = "earthflux_missing_input")
  expect_error(cv_run(ef_method_ols(), unname(folds), dat, grid),
               class = "earthflux_input_error")
  expect_error(cv_run(ef_method_ols(), folds[-1], dat, grid),
               class = "earthflux_input_error")
  expect_error(cv_run(ef_method_ols(), folds + 0.5, dat, grid),
               class = "earthflux_input_error")
  expect_error(cv_run(ef_method_ols(), data.frame(station_id = "S01"),
                      dat, grid),
               class = "earthflux_input_error")
  expect_error(cv_run(ef_method_ols(), folds, dat, grid,
                      reselect_bandwidth = NA),
               class = "earthflux_input_error")
  expect_error(ef_regionalize_cv(dat, "air_temperature",
                                 method = ef_method_ols(), folds = folds,
                                 use_qc = "ok"),
               class = "earthflux_missing_input")
})
