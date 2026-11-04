# GWR bandwidth selection (dev/specs/gwr-forcing.md sections 4 and 11).

codes_of <- function(x) vapply(x$flags, `[[`, "", "code")

test_that("ef_gwr_search() validates its settings and has no hidden defaults", {
  s <- ef_gwr_search()
  expect_s3_class(s, "earthflux_gwr_search")
  expect_null(s$n_grid)
  expect_null(s$tol)
  expect_identical(s$method_adaptive, "exhaustive")
  expect_error(ef_gwr_search(n_grid = 2), class = "earthflux_domain_error")
  expect_error(ef_gwr_search(n_grid = 10.5), class = "earthflux_input_error")
  expect_error(ef_gwr_search(tol = 0), class = "earthflux_domain_error")
  expect_error(ef_gwr_search(lower = 10, upper = 5),
               class = "earthflux_domain_error")
  expect_error(ef_gwr_search(k_min = 10, k_max = 5),
               class = "earthflux_domain_error")
  expect_error(ef_gwr_search(lower_offset = -1),
               class = "earthflux_domain_error")
  expect_error(ef_gwr_search(method_adaptive = "golden"),
               class = "earthflux_unknown_method")
  dat <- gwr_small()
  # the fixed search needs n_grid, tol and the bound settings it uses
  expect_error(ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "gaussian",
                                criterion = "AICc", search = ef_gwr_search()),
               class = "earthflux_missing_input")
  expect_error(ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                                criterion = "AICc",
                                search = ef_gwr_search(n_grid = 10, tol = 1,
                                                       upper_factor = 2)),
               class = "earthflux_missing_input")
  expect_error(ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "gaussian",
                                criterion = "AICc",
                                search = ef_gwr_search(n_grid = 10, tol = 1)),
               class = "earthflux_missing_input")
  expect_error(ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "gaussian",
                                criterion = "AICc",
                                search = list(n_grid = 10)),
               class = "earthflux_missing_input")
  # the adaptive search needs none of them
  bw <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "gaussian",
                         adaptive = TRUE, criterion = "AICc",
                         search = ef_gwr_search())
  expect_identical(bw$search$k_min, 3L)
  expect_identical(bw$search$k_max, 6L)
  expect_error(ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "gaussian",
                                adaptive = TRUE, criterion = "AICc",
                                search = ef_gwr_search(k_max = 7)),
               class = "earthflux_domain_error")
})

test_that("G7: AICc and CV selection on the synthetic reference", {
  dat <- gwr_synthetic(2L)
  srch <- ef_gwr_search(n_grid = 30, tol = 1, lower_offset = 0.01,
                        upper_factor = 1.5)
  bw <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                         criterion = "AICc", search = srch)
  expect_s3_class(bw, "earthflux_gwr_bandwidth")
  # backend evaluation: prototype 36 409.36 m, GWmodel 36 414.55 m (search
  # tolerances differ); the criterion at the optimum is what matters
  expect_equal(bw$value, 36409.4, tolerance = 1e-4)
  fit <- ef_gwr_fit(dat$y, dat$x, dat$coords, bandwidth = bw)
  expect_equal(fit$fit$aicc, bw$criterion_value, tolerance = 1e-12)
  expect_lte(bw$criterion_value,
             min(bw$profile$criterion[bw$profile$feasible]))
  expect_identical(fit$bandwidth$selected_by, "AICc")
  expect_identical(fit$profile, bw$profile)
  expect_identical(codes_of(bw), character(0))
  expect_setequal(bw$provenance$flags_evaluated,
                  c("EF_GWR_BW_AT_BOUND", "EF_GWR_BW_MULTIMODAL",
                    "EF_GWR_AICC_UNDEFINED", "EF_GWR_GLOBAL_PREFERRED",
                    "EF_GWR_STATION_EXCLUDED"))
  # profile: grid, refinement and the global (b = Inf) reference
  expect_identical(unique(bw$profile$stage), c("grid", "refine", "global"))
  expect_identical(sum(bw$profile$stage == "grid"), 30L)
  expect_identical(bw$profile$bandwidth[nrow(bw$profile)], Inf)
  expect_equal(bw$profile$enp[nrow(bw$profile)], 3, tolerance = 1e-12)
  expect_identical(bw$search$n_evaluations, nrow(bw$profile))
  # automatic bounds
  d <- as.matrix(stats::dist(dat$coords))
  m4 <- max(apply(d, 1, function(r) sort(r)[4]))
  expect_equal(bw$search$lower_auto, m4)
  expect_equal(bw$search$lower, m4 * 1.01)
  expect_equal(bw$search$upper, 1.5 * max(d))

  cv <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                         criterion = "CV", search = srch)
  expect_equal(cv$value, 36785.8, tolerance = 1e-4)
  expect_equal(cv$criterion_value,
               ef_gwr_fit(dat$y, dat$x, dat$coords, cv$value,
                          "bisquare")$fit$cv, tolerance = 1e-12)

  ad <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                         adaptive = TRUE, criterion = "AICc",
                         search = ef_gwr_search(k_min = 10, k_max = 60))
  expect_identical(ad$value, 38L)
  expect_identical(ad$unit, "neighbours")
  expect_identical(ad$profile$bandwidth[ad$profile$stage == "grid"],
                   as.numeric(10:60))
})

test_that("a minimum at a search bound is returned and flagged", {
  dat <- gwr_synthetic(2L)
  # gaussian kernel: the neighbour rule (stations within one bandwidth) sets
  # the lower bound, where the profile is still decreasing
  bw <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "gaussian",
                         criterion = "AICc",
                         search = ef_gwr_search(n_grid = 15, tol = 1,
                                                upper_factor = 1.5))
  expect_true("EF_GWR_BW_AT_BOUND" %in% codes_of(bw))
  expect_identical(bw$value, bw$search$lower)
  expect_false("refine" %in% bw$profile$stage)
  # adaptive: optimum at k_max
  ad <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                         adaptive = TRUE, criterion = "AICc",
                         search = ef_gwr_search(k_min = 20, k_max = 30))
  expect_identical(ad$value, 30L)
  expect_true("EF_GWR_BW_AT_BOUND" %in% codes_of(ad))
  fit <- ef_gwr_fit(dat$y, dat$x, dat$coords, bandwidth = ad)
  expect_true("EF_GWR_BW_AT_BOUND" %in% codes_of(fit))
  f <- fit$flags[[which(codes_of(fit) == "EF_GWR_BW_AT_BOUND")]]
  expect_identical(c(f$n_total, f$scope), c("1", "object"))
})

test_that("a multimodal profile is flagged and the profile kept", {
  dat <- gwr_synthetic(2L)
  bw <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "gaussian",
                         adaptive = TRUE, criterion = "AICc",
                         search = ef_gwr_search())
  expect_identical(bw$value, 9L)
  expect_true("EF_GWR_BW_MULTIMODAL" %in% codes_of(bw))
  expect_gt(EarthFlux:::gwr_count_minima(bw$profile$criterion[
    bw$profile$stage == "grid"], bw$profile$feasible[
      bw$profile$stage == "grid"]), 1L)
  expect_equal(nrow(bw$profile), 150 - 4 + 1 + 1)
  expect_identical(EarthFlux:::gwr_count_minima(c(3, 2, 1, 2, 3),
                                                rep(TRUE, 5)), 1L)
  expect_identical(EarthFlux:::gwr_count_minima(c(3, 1, 2, 1, 3),
                                                rep(TRUE, 5)), 2L)
  expect_identical(EarthFlux:::gwr_count_minima(c(3, 1, 2, 1, 3),
                                                c(TRUE, TRUE, TRUE, FALSE,
                                                  TRUE)), 1L)
})

test_that("ties of the criterion select the smallest bandwidth", {
  prof <- data.frame(bandwidth = c(4, 1, 2, 3), criterion = c(1, 2, 1, 1),
                     feasible = c(TRUE, TRUE, TRUE, FALSE))
  expect_identical(EarthFlux:::gwr_best_row(prof), 3L)
  prof$feasible <- FALSE
  expect_identical(EarthFlux:::gwr_best_row(prof), NA_integer_)
})

test_that("G6: bandwidths with undefined AICc are infeasible, not selected", {
  s <- gwr_small()
  srch <- ef_gwr_search(lower = 2500, upper = 60000, n_grid = 25, tol = 1)
  bw <- ef_gwr_bandwidth(s$y, s$x, s$coords, "gaussian", criterion = "AICc",
                         search = srch)
  p <- bw$profile
  # 6-8 km: n - 2 - tr(S) <= 0 (infeasible; also too few stations within
  # one bandwidth of S6); about 3 km: numerically singular at S6
  undefined <- !is.na(p$enp) & 6 - 2 - p$enp <= 0
  expect_true(any(undefined))
  expect_false(any(p$feasible[undefined]))
  expect_identical(p$reason[1], "rank_deficient")
  expect_true(all(is.na(p$criterion[!p$feasible])))
  expect_true("EF_GWR_AICC_UNDEFINED" %in% codes_of(bw))
  # the formula would give spuriously low values there (-120.9 at 8 km)
  expect_gt(bw$criterion_value, 0)
  expect_gt(bw$value, 8000)
  # negative: the CV criterion does not evaluate AICc feasibility
  cv <- ef_gwr_bandwidth(s$y, s$x, s$coords, "gaussian", criterion = "CV",
                         search = srch)
  expect_false("EF_GWR_AICC_UNDEFINED" %in% codes_of(cv))
  expect_false("EF_GWR_AICC_UNDEFINED" %in% cv$provenance$flags_evaluated)
})

test_that("no feasible bandwidth raises a classed error with the profile", {
  s <- gwr_small()
  err <- expect_error(
    ef_gwr_bandwidth(s$y, s$x, s$coords, "boxcar", criterion = "AICc",
                     search = ef_gwr_search(lower = 3000, upper = 9000,
                                            n_grid = 5, tol = 1)),
    class = "earthflux_gwr_no_feasible_bandwidth"
  )
  expect_s3_class(err, "earthflux_gwr_error")
  expect_true(is.data.frame(err$profile))
  expect_false(any(err$profile$feasible[err$profile$stage == "grid"]))
})

test_that("the global model preferred is flagged (and the optimum returned)", {
  # a stationary relationship: deterministic residuals, no spatial trend
  n <- 30
  i <- seq_len(n)
  coords <- cbind((i * 7919) %% 100000, (i * 104729) %% 100000)
  x <- cbind(elevation = (i * 37) %% 1500)
  y <- 20 - 0.0065 * x[, 1] + 0.3 * sin(i * 2.7)
  bw <- ef_gwr_bandwidth(y, x, coords, "gaussian", criterion = "AICc",
                         search = ef_gwr_search(n_grid = 20, tol = 1,
                                                upper_factor = 3))
  expect_true("EF_GWR_GLOBAL_PREFERRED" %in% codes_of(bw))
  expect_lte(bw$global$criterion, bw$criterion_value)
  expect_true(is.finite(bw$value))
  # negative: the spatially varying synthetic reference
  dat <- gwr_synthetic(2L)
  bw2 <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                          criterion = "CV",
                          search = ef_gwr_search(n_grid = 10, tol = 10,
                                                 lower_offset = 0.01,
                                                 upper_factor = 1.5))
  expect_false("EF_GWR_GLOBAL_PREFERRED" %in% codes_of(bw2))
})

test_that("few stations (n = 15): feasible result and recorded profile", {
  dat <- gwr_synthetic(2L)
  k <- 1:15
  bw <- ef_gwr_bandwidth(dat$y[k], dat$x[k, ], dat$coords[k, ], "bisquare",
                         criterion = "AICc",
                         search = ef_gwr_search(n_grid = 40, tol = 1,
                                                lower_offset = 0.01,
                                                upper_factor = 1.5))
  expect_true(is.finite(bw$value))
  expect_gt(sum(bw$profile$feasible), 0L)
  expect_true(all(c("bandwidth", "criterion", "feasible", "reason", "aicc",
                    "cv", "enp", "rss", "min_nonzero", "stage") %in%
                    names(bw$profile)))
  ad <- ef_gwr_bandwidth(dat$y[k], dat$x[k, ], dat$coords[k, ], "gaussian",
                         adaptive = TRUE, criterion = "AICc",
                         search = ef_gwr_search())
  expect_lte(ad$value, 15L)
})

test_that("min_neighbours changes the bounds and the feasibility rule", {
  dat <- gwr_synthetic(2L)
  b4 <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                         criterion = "AICc",
                         search = ef_gwr_search(n_grid = 10, tol = 10,
                                                lower_offset = 0,
                                                upper_factor = 1.5))
  b8 <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                         criterion = "AICc",
                         search = ef_gwr_search(n_grid = 10, tol = 10,
                                                lower_offset = 0,
                                                upper_factor = 1.5,
                                                min_neighbours = 8))
  expect_identical(b4$search$min_neighbours, 4L)
  expect_identical(b4$search$min_neighbours_source, "mathematical_minimum")
  expect_identical(b8$search$min_neighbours_source, "user")
  expect_gt(b8$search$lower_auto, b4$search$lower_auto)
  # with delta = 0 the lower bound of a bisquare search is infeasible
  expect_identical(b4$profile$reason[1], "few_neighbours")
  expect_true(all(b8$profile$min_nonzero[b8$profile$feasible] >= 8L))
  a8 <- ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                         adaptive = TRUE, criterion = "CV",
                         search = ef_gwr_search(min_neighbours = 8,
                                                k_max = 20))
  expect_identical(a8$search$k_min, 9L)
  fit <- ef_gwr_fit(dat$y, dat$x, dat$coords, bandwidth = a8)
  expect_identical(fit$config$min_neighbours, 8L)
  expect_error(ef_gwr_search(min_neighbours = 0),
               class = "earthflux_domain_error")
  expect_error(ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                                adaptive = TRUE, criterion = "CV",
                                search = ef_gwr_search(min_neighbours = 3)),
               class = "earthflux_domain_error")
})

test_that("the search is deterministic", {
  s <- gwr_small()
  srch <- ef_gwr_search(n_grid = 12, tol = 1, upper_factor = 2)
  a <- ef_gwr_bandwidth(s$y, s$x, s$coords, "exponential",
                        criterion = "CV", search = srch)
  b <- ef_gwr_bandwidth(s$y, s$x, s$coords, "exponential",
                        criterion = "CV", search = srch)
  expect_identical(a, b)
})

test_that("a bandwidth object must match the fit", {
  s <- gwr_small()
  bw <- ef_gwr_bandwidth(s$y, s$x, s$coords, "gaussian", criterion = "CV",
                         search = ef_gwr_search(n_grid = 10, tol = 1,
                                                upper_factor = 2))
  expect_error(ef_gwr_fit(s$y, s$x, s$coords, bw, kernel = "bisquare"),
               class = "earthflux_input_error")
  expect_error(ef_gwr_fit(s$y, s$x, s$coords, bw, adaptive = TRUE),
               class = "earthflux_input_error")
  y <- s$y
  y[1] <- NA
  y <- c(y, 16)
  expect_error(ef_gwr_fit(y, rbind(s$x, 700), rbind(s$coords, c(0, 20000)),
                          bw),
               class = "earthflux_input_error")
  fit <- ef_gwr_fit(s$y, s$x, s$coords, bw)
  expect_identical(fit$kernel, "gaussian")
  expect_identical(fit$bandwidth$value, bw$value)
})
