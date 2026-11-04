# Benchmark of the regionalization orchestrator ef_regionalize()
# (dev/specs/gwr-forcing.md sections 6.4-6.5; dev/specs/parallel-processing.md
# sections 5 (rule 11: measure before parallelizing) and 11).
#
# Synthetic data (fictitious): 150 stations on a 100 km x 100 km domain
# (UTM 19S), elevation hill + west-east ramp, distance to a straight coast,
# air temperature with a lapse rate varying west-east (set.seed(20261104)),
# two target times. GWR with a fixed bisquare bandwidth of 40 km, exact
# prediction on grids of 500 x 500 (200 m) and 1000 x 1000 (100 m) cells.
#
# Compares the sequential plan with future::plan(multisession, workers = 2)
# (the plan is set here, by the user, never by the package) and checks that
# surfaces and flag words are identical. The package is installed in a
# temporary library so that the workers load the same version.
#
# Run from the package root:
#   Rscript dev/benchmarks/regionalize.R
# Prints versions, cores, load average, the median elapsed time of the
# repetitions and the equality checks.

lib <- tempfile("earthflux-lib-")
dir.create(lib)
on.exit(unlink(lib, recursive = TRUE), add = TRUE)
utils::install.packages(".", lib = lib, repos = NULL, type = "source",
                        quiet = TRUE)
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(EarthFlux))

load_avg <- function() {
  if (file.exists("/proc/loadavg")) readLines("/proc/loadavg") else NA
}
cat("Date (UTC):", format(Sys.time(), tz = "UTC"), "\n")
cat("R", R.version$major, ".", R.version$minor, "; EarthFlux",
    as.character(utils::packageVersion("EarthFlux")), "; terra",
    as.character(utils::packageVersion("terra")), "; future",
    as.character(utils::packageVersion("future")), "; future.apply",
    as.character(utils::packageVersion("future.apply")), "\n", sep = " ")
cat("Available cores:", parallelly::availableCores(), "; load:",
    load_avg(), "\n")

make_grid <- function(n) {
  l <- 100000
  grid <- terra::rast(nrows = n, ncols = n, xmin = 300000, xmax = 300000 + l,
                      ymin = 6000000, ymax = 6000000 + l, crs = "EPSG:32719")
  xy <- terra::xyFromCell(grid, seq_len(terra::ncell(grid)))
  u <- xy[, 1] - 300000
  v <- xy[, 2] - 6000000
  r <- c(grid, grid)
  terra::values(r) <- cbind(elev_fun(u, v), u / 1000)
  names(r) <- c("elevation", "distance_to_coast")
  r
}
elev_fun <- function(u, v, l = 100000) {
  1500 * exp(-((u - 0.7 * l)^2 + (v - 0.5 * l)^2) / (2 * (0.25 * l)^2)) +
    200 * (u / l)
}
make_data <- function(n = 150L, n_times = 2L) {
  set.seed(20261104)
  l <- 100000
  u <- stats::runif(n, 0, l)
  v <- stats::runif(n, 0, l)
  elev <- elev_fun(u, v)
  ll <- terra::project(cbind(300000 + u, 6000000 + v), from = "EPSG:32719",
                       to = "EPSG:4326")
  t0 <- as.POSIXct("2024-01-15 14:30:00", tz = "UTC")
  do.call(rbind, lapply(seq_len(n_times), function(k) {
    b1 <- -0.0065 + 0.003 * (u / l - 0.5)
    data.frame(station_id = sprintf("S%03d", seq_len(n)), lon = ll[, 1],
               lat = ll[, 2], target_time = t0 + 3600 * (k - 1),
               variable = "air_temperature",
               value = 22 + k - 2 * (v / l) + b1 * elev + 0.03 * u / 1000 +
                 stats::rnorm(n, 0, 0.4),
               qc_status = "ok")
  }))
}

dat <- make_data()
method <- ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 40000)
run <- function(grid, prediction = ef_predict_control()) {
  ef_regionalize(dat, "air_temperature", grid, method, use_qc = "ok",
                 surface_covariates = character(0), prediction = prediction)
}
timed <- function(reps, grid, prediction = ef_predict_control()) {
  out <- NULL
  t <- replicate(reps, {
    tt <- system.time(out <<- run(grid, prediction))[["elapsed"]]
    tt
  })
  list(result = out, median = stats::median(t), times = t)
}
same <- function(a, b) {
  identical(terra::values(a$surface), terra::values(b$surface)) &&
    identical(terra::values(a$flag_word), terra::values(b$flag_word)) &&
    identical(a$station_table, b$station_table)
}

for (cfg in list(list(n = 500L, reps = 3L), list(n = 1000L, reps = 1L))) {
  grid <- make_grid(cfg$n)
  cat(sprintf("\nGrid %d x %d = %d cells, 150 stations, 2 target times\n",
              cfg$n, cfg$n, cfg$n^2))
  future::plan(future::sequential)
  seq_run <- timed(cfg$reps, grid)
  cat(sprintf("  sequential (terra blocks: %d): median %.2f s [%s]\n",
              seq_run$result$provenance$prediction$n_blocks, seq_run$median,
              paste(sprintf("%.2f", seq_run$times), collapse = ", ")))
  small <- timed(1L, grid, ef_predict_control(block_rows = 50L))
  cat(sprintf("  sequential, block_rows = 50 (%d blocks): %.2f s; identical: %s\n",
              small$result$provenance$prediction$n_blocks, small$median,
              same(seq_run$result, small$result)))
  oplan <- future::plan(future::multisession, workers = 2L)
  par_run <- timed(cfg$reps, grid)
  future::plan(oplan)
  cat(sprintf("  multisession, 2 workers (%d blocks): median %.2f s [%s]; identical: %s; speed-up %.2f\n",
              par_run$result$provenance$prediction$n_blocks, par_run$median,
              paste(sprintf("%.2f", par_run$times), collapse = ", "),
              same(seq_run$result, par_run$result),
              seq_run$median / par_run$median))
}
cat("\nLoad at the end:", load_avg(), "\n")
