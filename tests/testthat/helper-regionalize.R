# Synthetic grid and stations for the regionalization tests. Everything is
# fictitious: a 60 x 60 km grid of 1 km cells in UTM zone 19S with an
# elevation hill and a west-east distance to a straight "coast", and a set of
# stations with air temperature depending on both. No real data.

rgn_test_grid <- function(n = 60L, res = 1000) {
  grid <- terra::rast(nrows = n, ncols = n, xmin = 300000,
                      xmax = 300000 + n * res, ymin = 6000000,
                      ymax = 6000000 + n * res, crs = "EPSG:32719")
  xy <- terra::xyFromCell(grid, seq_len(terra::ncell(grid)))
  u <- (xy[, 1] - 300000) / 1000
  v <- (xy[, 2] - 6000000) / 1000
  r <- c(grid, grid)
  terra::values(r) <- cbind(rgn_test_elevation(u, v), u)
  names(r) <- c("elevation", "distance_to_coast")
  r
}

# Elevation [m] at (u, v) in km from the south-west corner.
rgn_test_elevation <- function(u, v) {
  1500 * exp(-((u - 40)^2 + (v - 30)^2) / (2 * 12^2)) + 8 * u
}

# Long regionalization input (dev/specs/weather-forcing.md section 7.2) for
# `n` stations and `n_times` hourly target times. Restores the RNG state.
rgn_test_data <- function(n = 35L, n_times = 2L, seed = 20261104L) {
  old <- if (exists(".Random.seed", envir = globalenv())) {
    get(".Random.seed", envir = globalenv())
  }
  on.exit({
    if (is.null(old)) {
      rm(".Random.seed", envir = globalenv())
    } else {
      assign(".Random.seed", old, envir = globalenv())
    }
  })
  set.seed(seed)
  u <- stats::runif(n, 2, 58)
  v <- stats::runif(n, 2, 58)
  # covariates at the centre of the cell containing the station, so that the
  # synthetic relation holds exactly for the extracted values
  uc <- floor(u) + 0.5
  vc <- floor(v) + 0.5
  elev <- rgn_test_elevation(uc, vc)
  ll <- terra::project(cbind(300000 + u * 1000, 6000000 + v * 1000),
                       from = "EPSG:32719", to = "EPSG:4326")
  t0 <- as.POSIXct("2024-01-15 14:30:00", tz = "UTC")
  rows <- lapply(seq_len(n_times), function(k) {
    lapse <- -0.0065 + 0.002 * (uc / 60 - 0.5)
    value <- 24 + k + lapse * elev + 0.03 * uc +
      stats::rnorm(n, 0, 0.3)
    data.frame(
      station_id = sprintf("S%02d", seq_len(n)),
      lon = ll[, 1], lat = ll[, 2], elevation = round(elev),
      target_time = t0 + 3600 * (k - 1),
      period_seconds = 0L, variable = "air_temperature",
      value = value, qc_status = "ok", reference = NA_character_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  attr(out, "xy") <- cbind(x = 300000 + u * 1000, y = 6000000 + v * 1000)
  out
}

# Projected coordinates of the stations, as a data frame for the folds.
rgn_test_xy <- function(data) {
  xy <- attr(data, "xy")
  data.frame(station_id = unique(data$station_id), x = xy[, 1],
             y = xy[, 2])
}

# Values of a SpatRaster as a plain matrix (cells x layers).
rgn_values <- function(r) {
  terra::values(r, mat = TRUE)
}

# Parallel tests need the installed package: the multisession workers load
# EarthFlux from the library, not from a development (load_all) session.
skip_unless_installed_namespace <- function() {
  installed <- find.package("EarthFlux", lib.loc = .libPaths(), quiet = TRUE)
  loaded <- getNamespaceInfo("EarthFlux", "path")
  same <- length(installed) == 1L &&
    normalizePath(installed[1L], mustWork = FALSE) ==
      normalizePath(loaded, mustWork = FALSE)
  testthat::skip_if_not(same, "the workers need the installed package")
}
