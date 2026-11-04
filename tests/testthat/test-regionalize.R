# Regionalization orchestrator ef_regionalize() (dev/specs/gwr-forcing.md
# sections 2, 5, 6.1, 6.3, 8.3-8.4 and 11; dev/specs/parallel-processing.md
# section 6.3; dev/specs/flags.md sections 6.3-6.7). Synthetic data only
# (helper-regionalize.R).

rgn_run <- function(method, data = rgn_test_data(), grid = rgn_test_grid(),
                    ...) {
  ef_regionalize(data, "air_temperature", grid, method, use_qc = "ok",
                 surface_covariates = character(0), ...)
}

cell_xy <- function(grid) {
  terra::xyFromCell(grid, seq_len(terra::ncell(grid)))
}

surface_names <- c("surface", "flag_word", "flag_bits", "uncertainty",
                   "variable", "unit", "target_time", "method",
                   "method_settings", "diagnostics", "station_table",
                   "flags", "provenance")

test_that("every method returns the same earthflux_surface structure", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  methods <- list(
    gwr = ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 30000),
    global_ols = ef_method_ols(),
    idw = ef_method_idw(2),
    station = ef_method_station("S05"),
    station_lapse = ef_method_station("S05", lapse_rate = -0.0065)
  )
  classes <- c(gwr = "earthflux_gwr", global_ols = "earthflux_ols",
               idw = "earthflux_idw", station = "earthflux_station_forcing",
               station_lapse = "earthflux_station_forcing")
  for (nm in names(methods)) {
    s <- rgn_run(methods[[nm]], dat, grid)
    expect_s3_class(s, "earthflux_surface")
    expect_named(s, surface_names)
    expect_identical(s$method, nm)
    expect_identical(s$provenance$method, nm)
    expect_s4_class(s$surface, "SpatRaster")
    expect_equal(terra::nlyr(s$surface), 2)
    expect_identical(names(s$surface),
                     c("air_temperature_20240115T143000Z",
                       "air_temperature_20240115T153000Z"))
    expect_identical(names(s$flag_word), paste0("flags_", names(s$surface)))
    expect_true(terra::compareGeom(s$surface, grid))
    expect_null(s$uncertainty)
    expect_identical(s$unit, "degC")
    expect_length(s$diagnostics, 2L)
    expect_true(all(vapply(s$diagnostics, inherits, logical(1),
                           what = classes[[nm]])))
    expect_identical(nrow(s$station_table), nrow(dat))
    expect_true(all(c("fitted", "residual", "loo_fitted", "loo_residual",
                      "status", "exclusion_reason") %in%
                      names(s$station_table)))
    v <- rgn_values(s$surface)
    expect_false(anyNA(v))
    w <- rgn_values(s$flag_word)
    expect_false(anyNA(w))
    expect_true(all(w == round(w) & w >= 0))
    expect_output(print(s), "earthflux_surface")
    expect_identical(as.data.frame(s), s$station_table)
  }
})

test_that("GWR surfaces equal the numeric core at every cell", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  s <- rgn_run(ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 30000),
               dat, grid)
  st <- dat[dat$target_time == min(dat$target_time), ]
  x <- as.matrix(terra::extract(grid, attr(dat, "xy")))
  fit <- ef_gwr_fit(st$value, x, attr(dat, "xy"), 30000, "bisquare",
                    station_id = st$station_id)
  expect_equal(s$diagnostics[[1]]$coefficients, fit$coefficients,
               tolerance = 1e-8)
  p <- ef_gwr_predict(fit, rgn_values(grid), cell_xy(grid))
  expect_equal(rgn_values(s$surface)[, 1], p$value, tolerance = 1e-8)
  expect_identical(rgn_values(s$flag_word)[, 1],
                   as.numeric(EarthFlux:::gwr_flag_word(p$flags,
                                                        terra::ncell(grid))))
  expect_identical(s$diagnostics[[1]]$variable, "air_temperature")
  expect_identical(s$diagnostics[[1]]$target_time, min(dat$target_time))
  # station table: fitted values and LOO residuals of the core
  tab <- s$station_table[s$station_table$target_time == min(dat$target_time), ]
  expect_equal(tab$fitted, fit$stations$fitted, tolerance = 1e-8)
  expect_equal(tab$loo_residual, fit$stations$loo_residual, tolerance = 1e-8)
  expect_identical(s$provenance$covariates,
                   c("elevation", "distance_to_coast"))
  expect_identical(s$provenance$covariate_source, "raster")
})

test_that("a bandwidth selected by criterion is recorded per fit", {
  s <- rgn_run(ef_method_gwr("gaussian", adaptive = TRUE, criterion = "AICc",
                             search = ef_gwr_search()))
  for (fit in s$diagnostics) {
    expect_identical(fit$bandwidth$selected_by, "AICc")
    expect_false(is.null(fit$profile))
  }
  fl <- s$provenance$flags$fits
  expect_s3_class(fl, "data.frame")
  obj <- unique(fl$code[fl$scope == "object"])
  expect_setequal(intersect(vapply(s$flags, `[[`, "", "code"), obj), obj)
})

test_that("the global regression reproduces the OLS reference of GWR", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  s <- rgn_run(ef_method_ols(), dat, grid)
  g <- rgn_run(ef_method_gwr("boxcar", adaptive = FALSE, bandwidth = 1e6),
               dat, grid)
  for (k in 1:2) {
    ols <- s$diagnostics[[k]]
    expect_equal(ols$coefficients,
                 g$diagnostics[[k]]$global_reference$coefficients,
                 tolerance = 1e-10)
    expect_equal(ols$fit$aicc, g$diagnostics[[k]]$global_reference$aicc,
                 tolerance = 1e-10)
    expect_equal(ols$fit$cv, g$diagnostics[[k]]$global_reference$cv,
                 tolerance = 1e-10)
    # boxcar with a bandwidth larger than every distance is exactly OLS
    expect_equal(rgn_values(s$surface)[, k], rgn_values(g$surface)[, k],
                 tolerance = 1e-10)
    # LOO residuals agree with an explicit refit without the station
    st <- ols$stations
    i <- 3L
    d <- data.frame(y = st$observed, e = st$elevation,
                    c = st$distance_to_coast)
    m <- stats::lm(y ~ e + c, data = d[-i, ])
    expect_equal(st$loo_fitted[i], unname(stats::predict(m, d[i, ])),
                 tolerance = 1e-10)
  }
  v <- rgn_values(grid)
  b <- s$diagnostics[[1]]$coefficients
  expect_equal(rgn_values(s$surface)[, 1],
               unname(b[1] + b[2] * v[, 1] + b[3] * v[, 2]),
               tolerance = 1e-10)
})

test_that("IDW interpolates with the given or selected power", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  s <- rgn_run(ef_method_idw(2), dat, grid)
  st <- dat[dat$target_time == min(dat$target_time), ]
  xy <- attr(dat, "xy")
  cells <- cell_xy(grid)[c(1, 1234, 3600), ]
  manual <- apply(cells, 1, function(p) {
    w <- sqrt((xy[, 1] - p[1])^2 + (xy[, 2] - p[2])^2)^-2
    sum(w * st$value) / sum(w)
  })
  expect_equal(rgn_values(s$surface)[c(1, 1234, 3600), 1], manual,
               tolerance = 1e-12)
  fit <- s$diagnostics[[1]]
  expect_identical(fit$power_selected_by, "user")
  # exact interpolator at the stations; LOO from the other stations
  expect_equal(fit$stations$fitted, st$value, tolerance = 1e-12)
  w <- sqrt((xy[-4, 1] - xy[4, 1])^2 + (xy[-4, 2] - xy[4, 2])^2)^-2
  expect_equal(fit$stations$loo_fitted[4],
               sum(w * st$value[-4]) / sum(w), tolerance = 1e-12)
  # power selected by LOOCV on a registered grid
  sel <- rgn_run(ef_method_idw(c(1, 2, 4)), dat, grid)
  f <- sel$diagnostics[[1]]
  expect_identical(f$power_selected_by, "CV")
  expect_identical(f$power, f$profile$power[which.min(f$profile$cv)])
  expect_identical(nrow(f$profile), 3L)
})

test_that("C1 gives the representative station value, or the lapse rate", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  s <- rgn_run(ef_method_station("S05"), dat, grid)
  for (k in 1:2) {
    tk <- dat[dat$target_time == sort(unique(dat$target_time))[k], ]
    expect_true(all(rgn_values(s$surface)[, k] ==
                      tk$value[tk$station_id == "S05"]))
  }
  expect_true(all(rgn_values(s$flag_word) == 0))
  codes <- vapply(s$flags, `[[`, "", "code")
  expect_true("EF_GWR_SINGLE_STATION" %in% codes)
  tab <- s$station_table
  expect_true(all(is.na(tab$loo_residual[tab$station_id == "S05"])))
  expect_false(anyNA(tab$loo_residual[tab$station_id != "S05"]))

  gam <- -0.0065
  l <- rgn_run(ef_method_station("S05", lapse_rate = gam), dat, grid)
  z <- rgn_values(grid)[, "elevation"]
  t1 <- dat[dat$target_time == min(dat$target_time), ]
  z_s <- l$diagnostics[[1]]$elevation_station
  expect_equal(z_s, terra::extract(grid, attr(dat, "xy")[5, , drop = FALSE])[[
    "elevation"]])
  expect_equal(rgn_values(l$surface)[, 1],
               t1$value[t1$station_id == "S05"] + gam * (z - z_s),
               tolerance = 1e-12)
  expect_identical(l$provenance$covariates, "elevation")
  expect_true("EF_GWR_SINGLE_STATION" %in% vapply(l$flags, `[[`, "", "code"))
})

test_that("the block size does not change the result (exact blocks)", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  for (m in list(ef_method_gwr("bisquare", adaptive = FALSE,
                               bandwidth = 30000),
                 ef_method_gwr("gaussian", adaptive = TRUE, bandwidth = 10),
                 ef_method_idw(2), ef_method_ols())) {
    whole <- rgn_run(m, dat, grid)
    parts <- lapply(c(1L, 7L, 60L), function(b) {
      rgn_run(m, dat, grid,
              prediction = ef_predict_control(block_rows = b,
                                              chunk_rows = 97))
    })
    for (p in parts) {
      expect_identical(rgn_values(p$surface), rgn_values(whole$surface))
      expect_identical(rgn_values(p$flag_word), rgn_values(whole$flag_word))
      expect_identical(p$station_table, whole$station_table)
    }
    expect_identical(parts[[1]]$provenance$prediction$n_blocks, 60L)
    expect_identical(parts[[2]]$provenance$prediction$n_blocks, 9L)
    expect_identical(parts[[1]]$provenance$prediction$block_source, "user")
    expect_identical(whole$provenance$prediction$block_source, "terra")
  }
})

test_that("the result does not depend on the order of the stations", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  perm <- dat[rev(seq_len(nrow(dat))), ]
  m <- ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 30000)
  a <- rgn_run(m, dat, grid)
  b <- rgn_run(m, perm, grid)
  expect_equal(rgn_values(b$surface), rgn_values(a$surface),
               tolerance = 1e-12)
  expect_identical(rgn_values(b$flag_word), rgn_values(a$flag_word))
})

test_that("cells with a missing covariate are NA with EF_INPUT_NA", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  na_cells <- c(1:5, 61:65, 3600)
  g <- grid
  v <- rgn_values(g)
  v[na_cells, "distance_to_coast"] <- NA
  terra::values(g) <- v
  for (m in list(ef_method_gwr("bisquare", adaptive = FALSE,
                               bandwidth = 30000),
                 ef_method_idw(2), ef_method_station("S05"))) {
    s <- rgn_run(m, dat, g)
    val <- rgn_values(s$surface)
    w <- rgn_values(s$flag_word)
    expect_true(all(is.na(val[na_cells, ])))
    expect_false(anyNA(val[-na_cells, ]))
    expect_true(all(w[na_cells, ] == 1))
    expect_true(all(bitwAnd(as.integer(w[-na_cells, ]), 1L) == 0L))
    cnt <- s$provenance$flags$counts
    expect_equal(cnt$n_flagged[cnt$code == "EF_INPUT_NA"],
                 rep(length(na_cells), 2))
    expect_true("EF_INPUT_NA" %in% s$provenance$flags_evaluated)
  }
})

test_that("extrapolation flags follow the bits of the registry", {
  s <- rgn_run(ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 30000))
  bits <- s$flag_bits
  expect_identical(bits$bit, 0:6)
  expect_identical(bits$code,
                   c("EF_INPUT_NA", "EF_GWR_EXTRAPOLATION_COVARIATE",
                     "EF_GWR_EXTRAPOLATION_LOCAL", "EF_GWR_OUTSIDE_HULL",
                     "EF_GWR_FEW_NEIGHBOURS", "EF_GWR_LOCAL_SINGULAR",
                     "EF_GWR_OUT_OF_DOMAIN"))
  w <- as.integer(rgn_values(s$flag_word))
  cnt <- s$provenance$flags$counts
  for (code in c("EF_GWR_EXTRAPOLATION_COVARIATE", "EF_GWR_OUTSIDE_HULL",
                 "EF_GWR_EXTRAPOLATION_LOCAL")) {
    b <- bits$bit[bits$code == code]
    expect_identical(sum(cnt$n_flagged[cnt$code == code]),
                     as.numeric(sum((w %/% 2^b) %% 2 == 1)))
    expect_true(sum(cnt$n_flagged[cnt$code == code]) > 0)
  }
  expect_identical(unique(cnt$n_total), 3600)
  # the C2 methods evaluate the conditions that apply to them
  ols <- rgn_run(ef_method_ols())
  expect_setequal(ols$provenance$flags$counts$code,
                  c("EF_INPUT_NA", "EF_GWR_EXTRAPOLATION_COVARIATE",
                    "EF_GWR_OUTSIDE_HULL", "EF_GWR_OUT_OF_DOMAIN"))
  idw <- rgn_run(ef_method_idw(2))
  expect_setequal(idw$provenance$flags$counts$code,
                  c("EF_INPUT_NA", "EF_GWR_OUTSIDE_HULL",
                    "EF_GWR_OUT_OF_DOMAIN"))
  expect_false("EF_GWR_LOCAL_SINGULAR" %in% idw$provenance$flags_evaluated)
})

test_that("values outside the physical domain are kept and flagged critical", {
  dat <- rgn_test_data(n_times = 1L)
  xy <- attr(dat, "xy")
  # vapour pressure decreasing with the distance to the coast: negative
  # predictions inland, which are impossible and must not be truncated
  dat$variable <- "vapour_pressure"
  dat$value <- 0.9 - 0.02 * (floor((xy[, 1] - 300000) / 1000) + 0.5)
  grid <- rgn_test_grid()[["distance_to_coast"]]
  s <- ef_regionalize(dat, "vapour_pressure", grid, ef_method_ols(),
                      use_qc = "ok", surface_covariates = character(0))
  v <- rgn_values(s$surface)[, 1]
  w <- as.integer(rgn_values(s$flag_word)[, 1])
  bad <- v <= 0
  expect_true(any(bad))
  expect_true(min(v) < 0)
  expect_identical((w %/% 64L) %% 2L == 1L, bad)
  cnt <- s$provenance$flags$counts
  expect_identical(cnt$n_flagged[cnt$code == "EF_GWR_OUT_OF_DOMAIN"],
                   as.numeric(sum(bad)))
  reg <- EarthFlux:::ef_flag_registry()
  row <- reg[reg$code == "EF_GWR_OUT_OF_DOMAIN", ]
  expect_identical(row$severity, "critical")
  expect_identical(row$bit, 6L)
  expect_identical(row$error_class, "earthflux_domain_error")
  expect_identical(s$unit, "kPa")
  expect_identical(s$provenance$flags$policies$out_of_domain,
                   "kept_and_flagged")
  # air temperature within its domain: never flagged
  ta <- rgn_run(ef_method_ols())
  cnt <- ta$provenance$flags$counts
  expect_true(all(cnt$n_flagged[cnt$code == "EF_GWR_OUT_OF_DOMAIN"] == 0))
})

test_that("QC policy and exclusions are explicit and recorded", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  dat$qc_status[dat$station_id == "S01"] <- "warning"
  dat$qc_status[dat$station_id == "S02"] <- "excluded"
  dat$value[dat$station_id == "S03" &
              dat$target_time == min(dat$target_time)] <- NA
  # S04 outside the grid
  far <- terra::project(cbind(250000, 6030000), from = "EPSG:32719",
                        to = "EPSG:4326")
  dat$lon[dat$station_id == "S04"] <- far[1, 1]
  dat$lat[dat$station_id == "S04"] <- far[1, 2]
  excl <- data.frame(station_id = "S06", reason = "maintenance")
  m <- ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 30000)
  s <- ef_regionalize(dat, "air_temperature", grid, m, use_qc = "ok",
                      surface_covariates = character(0), exclude = excl)
  tab <- s$station_table
  t1 <- tab$target_time == min(tab$target_time)
  reason <- function(id, first = TRUE) {
    tab$exclusion_reason[tab$station_id == id & t1 == first]
  }
  expect_identical(reason("S01"), "qc_status:warning")
  expect_identical(reason("S02"), "qc_status:excluded")
  expect_identical(reason("S03"), "missing_value")
  expect_identical(reason("S03", FALSE), NA_character_)
  expect_identical(reason("S04"), "outside_grid")
  expect_identical(reason("S06"), "user:maintenance")
  expect_identical(s$provenance$n_used, c(30L, 31L))
  ex <- s$flags[[which(vapply(s$flags, `[[`, "", "code") ==
                         "EF_GWR_STATION_EXCLUDED")]]
  expect_identical(ex$scope, "record")
  expect_identical(ex$index, which(tab$status == "excluded"))
  expect_identical(ex$n_total, nrow(tab))
  expect_identical(s$provenance$use_qc, "ok")
  expect_identical(s$provenance$exclude, excl)
  # "warning" admitted by the policy
  w <- ef_regionalize(dat, "air_temperature", grid, m,
                      use_qc = c("ok", "warning"),
                      surface_covariates = character(0), exclude = excl)
  expect_identical(w$station_table$status[w$station_table$station_id ==
                                            "S01"], c("used", "used"))
  # IDW does not use covariates: the station outside the grid is used
  i <- ef_regionalize(dat, "air_temperature", grid, ef_method_idw(2),
                      use_qc = "ok")
  expect_identical(unique(i$station_table$status[i$station_table$station_id ==
                                                   "S04"]), "used")
  # no exclusion: the record flag is evaluated and absent
  clean <- rgn_run(m)
  expect_false("EF_GWR_STATION_EXCLUDED" %in%
                 vapply(clean$flags, `[[`, "", "code"))
  expect_true("EF_GWR_STATION_EXCLUDED" %in% clean$provenance$flags_evaluated)
})

test_that("covariates at the stations can come from a table", {
  dat <- rgn_test_data(n_times = 1L)
  grid <- rgn_test_grid()
  xy <- attr(dat, "xy")
  sc <- data.frame(station_id = dat$station_id,
                   terra::extract(grid, xy))
  m <- ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 30000)
  a <- rgn_run(m, dat, grid)
  b <- rgn_run(m, dat, grid, station_covariates = sc)
  expect_identical(b$provenance$covariate_source, "station_table")
  expect_equal(rgn_values(b$surface), rgn_values(a$surface),
               tolerance = 1e-12)
  sc$elevation[3] <- NA
  c3 <- rgn_run(m, dat, grid, station_covariates = sc)
  expect_identical(c3$station_table$exclusion_reason[3],
                   "missing_covariate:elevation")
  expect_error(rgn_run(m, dat, grid, station_covariates = sc[, 1:2]),
               class = "earthflux_input_error")
})

test_that("surface covariates need an explicit declaration (GW-07)", {
  dat <- rgn_test_data(n_times = 1L)
  grid <- rgn_test_grid()
  lst <- 300 - 0.004 * grid[["elevation"]] +
    sin(grid[["distance_to_coast"]] / 7)
  names(lst) <- "lst"
  g <- c(grid, lst)
  m <- ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 40000)
  expect_error(ef_regionalize(dat, "air_temperature", g, m, use_qc = "ok"),
               class = "earthflux_missing_input")
  expect_error(ef_regionalize(dat, "air_temperature", g, m, use_qc = "ok",
                              surface_covariates = character(0)),
               class = "earthflux_input_error")
  expect_error(ef_regionalize(dat, "air_temperature", g, m, use_qc = "ok",
                              surface_covariates = "ndvi"),
               class = "earthflux_input_error")
  s <- ef_regionalize(dat, "air_temperature", g, ef_method_ols(),
                      use_qc = "ok", surface_covariates = "lst")
  codes <- vapply(s$flags, `[[`, "", "code")
  expect_true("EF_GWR_SURFACE_COVARIATE" %in% codes)
  expect_identical(s$provenance$surface_covariates, "lst")
  # flag <-> provenance coherence (dev/specs/flags.md section 6.1)
  for (x in list(s, rgn_run(ef_method_ols(), dat, grid))) {
    expect_identical(
      "EF_GWR_SURFACE_COVARIATE" %in% vapply(x$flags, `[[`, "", "code"),
      length(x$provenance$surface_covariates) > 0L
    )
    expect_identical(
      "EF_GWR_SINGLE_STATION" %in% vapply(x$flags, `[[`, "", "code"),
      x$provenance$method %in% c("station", "station_lapse")
    )
    expect_true(all(c("EF_GWR_SURFACE_COVARIATE", "EF_GWR_SINGLE_STATION") %in%
                      x$provenance$flags_evaluated))
  }
})

test_that("surfaces are written to files; files of a failed call are removed", {
  dat <- rgn_test_data()
  grid <- rgn_test_grid()
  dir <- tempfile("rgn-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  f <- file.path(dir, "ta.tif")
  m <- ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 30000)
  mem <- rgn_run(m, dat, grid)
  before <- list.files(tempdir(), recursive = TRUE)
  disk <- rgn_run(m, dat, grid,
                  prediction = ef_predict_control(
                    filename = f, block_rows = 13,
                    wopt = list(datatype = "FLT8S")))
  expect_true(file.exists(f))
  expect_true(file.exists(file.path(dir, "ta_flags.tif")))
  expect_false(any(terra::inMemory(disk$surface)))
  expect_identical(terra::datatype(disk$flag_word), rep("INT4S", 2))
  expect_identical(rgn_values(disk$surface), rgn_values(mem$surface))
  expect_identical(as.numeric(rgn_values(disk$flag_word)),
                   as.numeric(rgn_values(mem$flag_word)))
  expect_identical(disk$provenance$prediction$filename, "ta.tif")
  # no stray temporary files outside the output directory
  after <- list.files(tempdir(), recursive = TRUE)
  expect_true(all(startsWith(setdiff(after, before), basename(dir))))
  expect_error(rgn_run(m, dat, grid,
                       prediction = ef_predict_control(filename = f)),
               class = "earthflux_input_error")
  # a failure while writing removes the files of the call
  g <- file.path(dir, "fail.tif")
  testthat::local_mocked_bindings(
    rgn_block_task = function(...) {
      ef_abort("Injected failure.", class = "earthflux_input_error")
    }
  )
  expect_error(rgn_run(m, dat, grid,
                       prediction = ef_predict_control(filename = g)),
               "Injected failure")
  expect_false(file.exists(g))
  expect_false(file.exists(file.path(dir, "fail_flags.tif")))
})

test_that("the input of ef_station_qc() is accepted", {
  qc <- ef_station_qc(syn_table())
  grid <- rgn_test_grid()
  s <- ef_regionalize(qc, "air_temperature", covariates = NULL,
                      method = ef_method_station("ST01"), use_qc = "ok",
                      grid = grid)
  expect_equal(terra::nlyr(s$surface), 3)
  expect_identical(s$provenance$covariate_source, "none")
  obs <- syn_observations()
  expect_identical(unname(rgn_values(s$surface)[1, ]),
                   obs$air_temperature[obs$station_id == "ST01"])
})

test_that("ef_regionalize() rejects invalid inputs with classed errors", {
  dat <- rgn_test_data(n_times = 1L)
  grid <- rgn_test_grid()
  m <- ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 30000)
  run <- function(...) {
    args <- list(data = dat, variable = "air_temperature", covariates = grid,
                 method = m, use_qc = "ok", surface_covariates = character(0))
    new <- list(...)
    for (nm in names(new)) args[nm] <- list(new[[nm]])
    do.call(ef_regionalize, args)
  }
  expect_error(ef_regionalize(dat, "air_temperature", grid, use_qc = "ok",
                              surface_covariates = character(0)),
               class = "earthflux_missing_input")
  expect_error(ef_regionalize(dat, "air_temperature", grid, m,
                              surface_covariates = character(0)),
               class = "earthflux_missing_input")
  expect_error(ef_regionalize(dat, "air_temperature", method = m,
                              use_qc = "ok"),
               class = "earthflux_missing_input")
  expect_error(run(method = list(method = "gwr")),
               class = "earthflux_input_error")
  expect_error(run(variable = "air_temp"), class = "earthflux_unknown_method")
  expect_error(run(variable = "vapour_pressure"),
               class = "earthflux_input_error")
  expect_error(run(use_qc = c("ok", "excluded")),
               class = "earthflux_input_error")
  expect_error(run(data = rbind(dat, dat[1, ])),
               class = "earthflux_input_error")
  moved <- dat
  moved$lon[1] <- moved$lon[1] + 0.01
  expect_error(run(data = rbind(moved[1, ], transform(dat[1, ], target_time =
                                                        target_time + 60))),
               class = "earthflux_input_error")
  expect_error(run(data = dat[, -1]), class = "earthflux_missing_input")
  bad <- dat
  bad$value[2] <- Inf
  expect_error(run(data = bad), class = "earthflux_domain_error")
  bad <- dat
  bad$lat[2] <- -95
  expect_error(run(data = bad), class = "earthflux_domain_error")
  bad <- dat
  bad$target_time <- as.character(bad$target_time)
  expect_error(run(data = bad), class = "earthflux_input_error")
  bad <- dat
  bad$qc_status[1] <- "good"
  expect_error(run(data = bad), class = "earthflux_input_error")
  expect_error(run(prediction = list()), class = "earthflux_input_error")
  geo <- terra::rast(nrows = 10, ncols = 10, xmin = -72, xmax = -70,
                     ymin = -37, ymax = -35, crs = "EPSG:4326")
  terra::values(geo) <- 1
  names(geo) <- "elevation"
  expect_error(run(covariates = geo), class = "earthflux_input_error")
  expect_error(run(grid = terra::rast(nrows = 5, ncols = 5)),
               class = "earthflux_input_error")
  g2 <- grid
  names(g2) <- c("elevation", "elevation")
  expect_error(run(covariates = g2), class = "earthflux_input_error")
  g3 <- grid
  names(g3)[2] <- "residual"
  expect_error(run(covariates = g3), class = "earthflux_input_error")
  expect_error(run(covariates = NULL), class = "earthflux_missing_input")
  expect_error(run(covariates = "grid"), class = "earthflux_input_error")
  expect_error(run(exclude = data.frame(station_id = "X99", reason = "x")),
               class = "earthflux_input_error")
  expect_error(run(exclude = data.frame(station_id = "S01")),
               class = "earthflux_input_error")
  expect_error(run(method = ef_method_station("X99")),
               class = "earthflux_input_error")
  expect_error(run(method = ef_method_station("S05", lapse_rate = -0.0065),
                   covariates = grid[["distance_to_coast"]]),
               class = "earthflux_missing_input")
  vp <- dat
  vp$variable <- "vapour_pressure"
  expect_error(run(data = vp, variable = "vapour_pressure",
                   method = ef_method_station("S05", lapse_rate = -0.0065)),
               class = "earthflux_input_error")
  et <- dat
  et$variable <- "etr_24"
  expect_error(run(data = et, variable = "etr_24"),
               class = "earthflux_input_error")
  # the representative station excluded at a target time
  q <- dat
  q$qc_status[q$station_id == "S05"] <- "excluded"
  expect_error(run(data = q, method = ef_method_station("S05")),
               class = "earthflux_input_error")
  # too few stations for GWR
  few <- dat[dat$station_id %in% sprintf("S%02d", 1:5), ]
  expect_error(run(data = few),
               class = "earthflux_gwr_insufficient_stations")
  expect_error(run(data = few[1:2, ], method = ef_method_ols()),
               class = "earthflux_gwr_insufficient_stations")
  expect_error(run(data = few[1, ], method = ef_method_idw(2)),
               class = "earthflux_gwr_insufficient_stations")
})

test_that("the execution plan is recorded and left untouched", {
  oplan <- future::plan()
  s <- rgn_run(ef_method_idw(2))
  expect_identical(future::plan(), oplan)
  ex <- s$provenance$execution
  expect_identical(ex$workers, 1L)
  expect_false(ex$parallel)
  expect_null(ex$seed)
  expect_true(all(c("future", "future.apply") %in% names(ex$future_versions)))
  expect_true(is.numeric(ex$elapsed_seconds))
  expect_true("memfrac" %in% names(ex$terra_options))
  expect_named(s$provenance$versions, c("EarthFlux", "R", "terra"))
  expect_identical(s$provenance$distance_method, "euclidean_projected")
})

test_that("sequential and parallel (2 workers) results are identical", {
  skip_on_cran()
  skip_if_not_installed("future")
  skip_unless_installed_namespace()
  dat <- rgn_test_data(n_times = 3L)
  grid <- rgn_test_grid()
  methods <- list(
    ef_method_gwr("bisquare", adaptive = FALSE, criterion = "AICc",
                  search = ef_gwr_search(n_grid = 15, tol = 10,
                                         lower_offset = 0.01,
                                         upper_factor = 1.5)),
    ef_method_idw(c(1, 2))
  )
  seq_res <- lapply(methods, rgn_run, data = dat, grid = grid)
  oplan <- future::plan(future::multisession, workers = 2)
  on.exit(future::plan(oplan), add = TRUE)
  par_res <- lapply(methods, rgn_run, data = dat, grid = grid)
  par_blk <- rgn_run(methods[[1]], dat, grid,
                     prediction = ef_predict_control(block_rows = 11))
  future::plan(oplan)
  for (k in seq_along(methods)) {
    a <- seq_res[[k]]
    b <- par_res[[k]]
    expect_identical(rgn_values(b$surface), rgn_values(a$surface))
    expect_identical(rgn_values(b$flag_word), rgn_values(a$flag_word))
    expect_identical(b$station_table, a$station_table)
    expect_identical(b$diagnostics, a$diagnostics)
    expect_identical(b$flags, a$flags)
    expect_identical(b$provenance$execution$workers, 2L)
    expect_true(b$provenance$execution$parallel)
  }
  expect_identical(rgn_values(par_blk$surface),
                   rgn_values(seq_res[[1]]$surface))
  expect_identical(rgn_values(par_blk$flag_word),
                   rgn_values(seq_res[[1]]$flag_word))
})
