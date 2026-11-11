# Experiment M: propagation of the weather forcing configurations through
# METRIC on the Cauquenes MODIS scene (2019-02-15, Terra overpass at about
# 14:08 UTC).
#
# 1. For each configuration (C1, C1-lap, C2-OLS, C2-IDW, C3-GWR) the hourly
#    air temperature, vapour pressure and 2 m wind speed of the local day of
#    the scene (UTC-3, 24 hours) are regionalized on a 1 km UTM 18S grid
#    around the scene with ef_regionalize() (same stations, QC, covariates
#    and times for every configuration), and projected (bilinear) to the
#    MODIS grid of the scene.
# 2. The alfalfa reference ET (ASCE-EWRI hourly) is computed per pixel from
#    the regionalized fields: ETr_inst at the hour of the overpass and ETr_24
#    as the sum of the 24 hourly values (decision 5.1 of EarthFlux:
#    regionalize the inputs; study decision D-04).
# 3. METRIC is run with every configuration (full substitution) and, from the
#    C1 baseline, with one forcing input replaced by its C3-GWR field at a
#    time (one-at-a-time substitution: Ta, ea, u2, ETr_inst, ETr_24).
#    The anchor cells are selected from the surface state only, so they are
#    identical in every run (checked); differences in the calibration (a, b)
#    are therefore caused by the forcing at the anchors.
# Outputs: results/maps/metric_<config>.tif, results/tables/metric_*.csv.

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))
source(p("scripts", "lib_metric.R"))

qc <- readRDS(p("data", "processed", "stations_qc.rds"))
meta <- utils::read.csv(p("data", "processed", "stations_meta.csv"),
                        stringsAsFactors = FALSE)
cov_scene <- terra::rast(p("data", "processed", "covariates_scene_utm.tif"))
scene <- terra::unwrap(EarthFlux::cauquenes_modis)
elev_modis <- terra::rast(p("data", "processed", "elevation_scene_modis.tif"))
s <- scene_inputs(scene, elev_modis)
rep_station <- readLines(p("results", "diagnostics", "representative_station.txt"))[1]

overpass_hour <- 14L
local_offset <- -3L # CLST (UTC-3) on 2019-02-15
day_start <- as.POSIXct(paste(cfg$scene_date, "00:00"), tz = "UTC") - local_offset * 3600
hours_utc <- day_start + 3600 * (0:23)
overpass_time <- as.POSIXct(paste(cfg$scene_date, sprintf("%02d:00", overpass_hour)),
                            tz = "UTC")
stopifnot(overpass_time %in% hours_utc)

obs <- qc$observations
st <- qc$qc_status
# Study decision D-09: gaps of at most `max_gap` hours in the hourly series
# of a station are filled by linear interpolation in time (values excluded
# by QC are treated as gaps); longer gaps stay missing. Every filled value
# is counted in results/diagnostics/scene_day_gap_filling.csv and gets the
# QC status "warning".
max_gap <- 6
win <- c(min(hours_utc) - 12 * 3600, max(hours_utc) + 12 * 3600)
grid_t <- seq(win[1], win[2], by = 3600)
vars <- c("air_temperature", "vapour_pressure", "wind_speed")
filled <- list(); gap_log <- list()
for (id in unique(obs$station_id)) {
  o <- obs[obs$station_id == id, ]; q <- st[st$station_id == id, ]
  out <- data.frame(station_id = id, timestamp = grid_t)
  qs <- data.frame(station_id = id, timestamp = grid_t)
  for (v in vars) {
    val <- o[[v]]; val[as.character(q[[v]]) == "excluded"] <- NA
    y <- val[match(grid_t, o$timestamp)]
    ok <- !is.na(y)
    yi <- y
    if (sum(ok) >= 2) {
      yi <- stats::approx(as.numeric(grid_t)[ok], y[ok], as.numeric(grid_t))$y
      # distance (h) to the nearest observed hour on each side
      run <- rle(!ok); ends <- cumsum(run$lengths); starts <- ends - run$lengths + 1
      for (j in which(run$values)) if (run$lengths[j] > max_gap) yi[starts[j]:ends[j]] <- NA
    }
    newly <- is.na(y) & !is.na(yi)
    out[[v]] <- yi
    qs[[v]] <- ifelse(newly, "warning", ifelse(ok, as.character(q[[v]])[match(grid_t, o$timestamp)], NA))
    in_day <- grid_t %in% hours_utc
    gap_log[[paste(id, v)]] <- data.frame(station_id = id, variable = v,
      observed = sum(ok & in_day), filled = sum(newly & in_day),
      missing = sum(is.na(yi) & in_day))
  }
  filled[[id]] <- list(obs = out, st = qs)
}
write_csv(do.call(rbind, gap_log), p("results", "diagnostics", "scene_day_gap_filling.csv"))
obs <- do.call(rbind, lapply(filled, `[[`, "obs"))
st <- do.call(rbind, lapply(filled, `[[`, "st"))
sel <- obs$timestamp %in% hours_utc
obs <- obs[sel, ]
st <- st[sel, ]
mi <- match(obs$station_id, meta$station_id)
long <- function(var_obs, var_name, value) {
  d <- data.frame(station_id = obs$station_id, lon = meta$lon[mi],
                  lat = meta$lat[mi], elevation = meta$elevation[mi],
                  target_time = obs$timestamp, variable = var_name,
                  value = value, qc_status = st[[var_obs]],
                  stringsAsFactors = FALSE)
  d[!is.na(d$value), ]
}
inputs <- list(
  air_temperature = long("air_temperature", "air_temperature", obs$air_temperature),
  vapour_pressure = long("vapour_pressure", "vapour_pressure", obs$vapour_pressure),
  wind_speed_2m = long("wind_speed", "wind_speed_2m",
                       ef_wind_2m(obs$wind_speed, meta$height_wind[mi]))
)
avail <- do.call(rbind, lapply(names(inputs), function(v) {
  d <- inputs[[v]]
  data.frame(variable = v, hour_utc = format(sort(unique(d$target_time)), "%H"),
             n_stations = as.integer(table(d$target_time)))
}))
write_csv(avail, p("results", "diagnostics", "scene_day_station_counts.csv"))

methods <- function(variable) {
  m <- list(
    "C1" = ef_method_station(rep_station),
    "C1-lap" = if (variable == "air_temperature")
      ef_method_station(rep_station, lapse_rate = 0.0065) else
      ef_method_station(rep_station),
    "C2-OLS" = ef_method_ols(),
    "C2-IDW" = ef_method_idw(power = c(1, 2, 3)),
    "C3-GWR" = ef_method_gwr(kernel = "bisquare", adaptive = TRUE,
                             criterion = "AICc", search = ef_gwr_search())
  )
  m
}
configs <- names(methods("air_temperature"))

# Regionalize one variable for one configuration; returns an array
# [row, col, hour] on the MODIS grid, plus the fit diagnostics.
# Covariates at the stations from the regional grid (the same values as in
# experiment R): most stations lie outside the prediction grid of the scene,
# so they must not be extracted from it (they would be excluded with a
# missing covariate).
cov_region <- terra::rast(p("data", "processed", "covariates_region.tif"))
st_xy <- terra::project(cbind(meta$lon, meta$lat), from = "EPSG:4326", to = study_crs)
station_cov <- data.frame(station_id = meta$station_id,
                          terra::extract(cov_region, st_xy))
station_cov <- station_cov[stats::complete.cases(station_cov), ]
regionalize_scene <- function(variable, config) {
  r <- ef_regionalize(inputs[[variable]], variable, covariates = cov_scene,
                      method = methods(variable)[[config]],
                      use_qc = c("ok", "warning"),
                      surface_covariates = character(0),
                      station_covariates = station_cov)
  surf <- r$surface
  # Out-of-domain predictions are masked before the core (flag bit 6).
  bit <- r$flag_bits$bit[r$flag_bits$code == "EF_GWR_OUT_OF_DOMAIN"]
  ood <- terra::app(r$flag_word, function(w) bitwAnd(w, bitwShiftL(1L, bit)) != 0L)
  n_ood <- sum(terra::values(ood), na.rm = TRUE)
  surf <- terra::mask(surf, ood, maskvalues = 1)
  modis <- terra::project(surf, scene[["lst"]], method = "bilinear")
  times <- r$target_time
  arr <- array(NA_real_, c(terra::nrow(modis), terra::ncol(modis), length(hours_utc)))
  for (k in seq_along(hours_utc)) {
    j <- which(times == hours_utc[k])
    if (length(j) == 1) arr[, , k] <- terra::as.matrix(modis[[j]], wide = TRUE)
  }
  diag <- r$station_table
  diag$config <- config
  fits <- do.call(rbind, lapply(seq_along(r$diagnostics), function(k) {
    d <- r$diagnostics[[k]]
    bw <- if (!is.null(d$bandwidth)) {
      if (is.list(d$bandwidth)) d$bandwidth$value else d$bandwidth
    } else NA_real_
    data.frame(variable = variable, config = config,
               target_time = format(times[k], "%H", tz = "UTC"),
               n_used = sum(r$station_table$status == "used" &
                              r$station_table$target_time == times[k]),
               tuning = if (is.null(bw)) NA_real_ else as.numeric(bw)[1])
  }))
  list(arr = arr, n_ood = n_ood, stations = diag, fits = fits,
       surface_utm = surf[[which(times == overpass_time)]])
}

t0 <- Sys.time()
fields <- list()
fit_tab <- list()
ood_tab <- list()
for (cf in configs) for (v in names(inputs)) {
  message(format(Sys.time()), " regionalize ", v, " ", cf)
  rr <- tryCatch(regionalize_scene(v, cf), error = function(e) e)
  if (inherits(rr, "error")) {
    message("  failed: ", conditionMessage(rr))
    ood_tab[[paste(cf, v)]] <- data.frame(config = cf, variable = v, n_ood = NA,
                                          error = conditionMessage(rr))
    next
  }
  fields[[cf]][[v]] <- rr$arr
  fit_tab[[paste(cf, v)]] <- rr$fits
  ood_tab[[paste(cf, v)]] <- data.frame(config = cf, variable = v,
                                        n_ood = rr$n_ood, error = "")
  terra::writeRaster(rr$surface_utm,
                     p("results", "maps", sprintf("forcing_%s_%s_utm.tif", v, cf)),
                     overwrite = TRUE)
}
write_csv(do.call(rbind, fit_tab), p("results", "diagnostics", "scene_regionalization_fits.csv"))
write_csv(do.call(rbind, ood_tab), p("results", "diagnostics", "scene_regionalization_status.csv"))

# Forcing of METRIC from the hourly fields of a configuration.
k_over <- which(hours_utc == overpass_time)
# Spot observations at hh:00 represent the hour centred on hh:00 (D-04).
mid_hour <- function(k) as.numeric(format(hours_utc[k], "%H", tz = "UTC"))
build_forcing <- function(f) {
  ta <- f$air_temperature; ea <- f$vapour_pressure; u2 <- f$wind_speed_2m
  etr <- array(NA_real_, dim(ta))
  for (k in seq_along(hours_utc)) {
    doy <- as.POSIXlt(hours_utc[k], tz = "UTC")$yday + 1
    etr[, , k] <- etr_hourly(ta[, , k], ea[, , k], pmax(u2[, , k], 0.5),
                             s$elevation, s$lat, s$lon, doy,
                             mid_hour(k))
  }
  list(ta = ta[, , k_over], ea = ea[, , k_over], u2 = pmax(u2[, , k_over], 0.5),
       etr_inst = etr[, , k_over], etr_24 = apply(etr, c(1, 2), sum))
}
# Study decision D-14: when a configuration cannot be fitted for a variable
# (e.g. too few stations measure wind for the global regression or GWR), the
# C1 field of that variable is used and the substitution is recorded in
# results/diagnostics/scene_forcing_fallbacks.csv; the configuration is then
# reported as such in the tables.
fallback <- list()
for (cf in setdiff(configs, "C1")) for (v in names(inputs)) {
  if (is.null(fields[[cf]][[v]]) && !is.null(fields[["C1"]][[v]])) {
    fields[[cf]][[v]] <- fields[["C1"]][[v]]
    fallback[[paste(cf, v)]] <- data.frame(config = cf, variable = v,
                                           used = "C1 field")
  }
}
write_csv(if (length(fallback)) do.call(rbind, fallback) else
            data.frame(config = character(), variable = character(), used = character()),
          p("results", "diagnostics", "scene_forcing_fallbacks.csv"))
complete_cfg <- names(fields)[vapply(fields, length, 1L) == 3L]
forcings <- lapply(fields[complete_cfg], build_forcing)

opts <- metric_options()
runs <- list()
for (cf in names(forcings)) {
  message(format(Sys.time()), " METRIC ", cf)
  runs[[cf]] <- run_metric(s, forcings[[cf]], opts)
}
# One-at-a-time substitution from the C1 baseline with the C3-GWR fields.
if (all(c("C1", "C3-GWR") %in% names(forcings))) {
  # Wind: GWR is not feasible with the stations that measure wind (D-14),
  # so the u2 substitution uses the C2-IDW field, the only spatial
  # alternative that could be fitted; recorded in the label.
  gwr_wind_fallback <- "C3-GWR wind_speed_2m" %in% names(fallback)
  for (v in c("ta", "ea", "u2", "etr_inst", "etr_24")) {
    f <- forcings[["C1"]]
    src <- if (v == "u2" && gwr_wind_fallback) "C2-IDW" else "C3-GWR"
    f[[v]] <- forcings[[src]][[v]]
    lab <- paste0("C1+GWR:", v)
    message(format(Sys.time()), " METRIC ", lab)
    runs[[lab]] <- run_metric(s, f, opts)
  }
}
saveRDS(list(forcings = forcings, runs = runs, hours_utc = hours_utc,
             overpass_time = overpass_time, options = opts,
             session = session_record()),
        p("data", "processed", "metric_runs.rds"))

## Tables ----------------------------------------------------------------------

anchor_cells <- lapply(runs, function(r) r$anchors$pixels[, c("type", "row", "col")])
same_anchors <- all(vapply(anchor_cells, function(a) identical(a, anchor_cells[[1]]), TRUE))

layers <- c("rn", "g", "h", "le", "et_inst", "etrf", "eta")
forc_names <- c("ta", "ea", "u2", "etr_inst", "etr_24")
stat_row <- function(x) {
  x <- x[!is.na(x)]
  c(mean = mean(x), sd = stats::sd(x), p05 = unname(stats::quantile(x, 0.05)),
    median = stats::median(x), p95 = unname(stats::quantile(x, 0.95)), n = length(x))
}
summ <- do.call(rbind, lapply(names(runs), function(cf) {
  r <- runs[[cf]]
  f <- if (cf %in% names(forcings)) forcings[[cf]] else NULL
  rows <- lapply(layers, function(l) data.frame(config = cf, variable = l,
                                                t(stat_row(r$layers[[l]][r$valid]))))
  if (!is.null(f)) rows <- c(rows, lapply(forc_names, function(l)
    data.frame(config = cf, variable = paste0("forcing_", l), t(stat_row(f[[l]][r$valid])))))
  do.call(rbind, rows)
}))
write_csv(summ, p("results", "tables", "metric_summary.csv"))

calib <- do.call(rbind, lapply(names(runs), function(cf) {
  r <- runs[[cf]]
  ap <- r$anchor_points
  data.frame(config = cf, a = r$a, b = r$b, converged = r$converged,
             iterations = r$iterations,
             pixels_converged = mean(r$layers$converged[r$valid] == 1),
             etr_inst_cold = ap$etr_inst[ap$type == "cold"],
             etr_inst_hot = ap$etr_inst[ap$type == "hot"],
             u_blend_cold = ap$u_blend[ap$type == "cold"],
             u_blend_hot = ap$u_blend[ap$type == "hot"],
             rn_cold = ap$rn[ap$type == "cold"], rn_hot = ap$rn[ap$type == "hot"],
             h_target_cold = ap$h_target[ap$type == "cold"],
             h_target_hot = ap$h_target[ap$type == "hot"],
             n_cells = sum(r$valid),
             n_eta_negative = sum(r$layers$eta[r$valid] < 0),
             n_h_gt_available = sum((r$layers$h > r$layers$rn - r$layers$g)[r$valid]),
             n_zom_floor = r$n_zom_floor,
             same_anchor_cells = identical(anchor_cells[[cf]], anchor_cells[["C1"]]))
}))
write_csv(calib, p("results", "tables", "metric_calibration.csv"))

# Differences against the C1 baseline, on the cells valid in both runs.
diff_tab <- do.call(rbind, lapply(setdiff(names(runs), "C1"), function(cf) {
  do.call(rbind, lapply(layers, function(l) {
    a <- runs[["C1"]]$layers[[l]]; b <- runs[[cf]]$layers[[l]]
    ok <- !is.na(a) & !is.na(b)
    d <- b[ok] - a[ok]
    data.frame(config = cf, variable = l, n = sum(ok), mean_diff = mean(d),
               mad = mean(abs(d)), p05 = unname(stats::quantile(d, 0.05)),
               p95 = unname(stats::quantile(d, 0.95)),
               rel_mean_diff_pct = 100 * mean(d) / mean(a[ok]),
               share_abs_gt = if (l == "eta") mean(abs(d) > 0.5) else NA_real_,
               spatial_r = stats::cor(a[ok], b[ok]))
  }))
}))
write_csv(diff_tab, p("results", "tables", "metric_differences_vs_C1.csv"))

# Rasters on the MODIS grid (float32, compressed).
for (cf in names(runs)) {
  r <- runs[[cf]]
  out <- terra::rast(c(lapply(c(layers, "h", "dt", "rah"), function(l) {
    x <- terra::rast(scene[["lst"]]); terra::values(x) <- as.vector(t(r$layers[[l]])); x
  })))
  names(out) <- c(layers, "h_dup", "dt", "rah")
  out <- out[[setdiff(names(out), "h_dup")]]
  if (cf %in% names(forcings)) {
    fr <- terra::rast(lapply(forc_names, function(l) {
      x <- terra::rast(scene[["lst"]]); terra::values(x) <- as.vector(t(forcings[[cf]][[l]])); x
    }))
    names(fr) <- paste0("forcing_", forc_names)
    out <- c(out, fr)
  }
  terra::writeRaster(out, p("results", "maps", sprintf("metric_%s.tif",
                                                        gsub("[:+]", "_", cf))),
                     overwrite = TRUE, datatype = "FLT4S",
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3"))
}
message("same anchor cells in every run: ", same_anchors)
message("elapsed: ", format(Sys.time() - t0))
print(calib[, c("config", "a", "b", "iterations", "etr_inst_cold", "u_blend_cold",
                "h_target_hot", "n_eta_negative")], digits = 4)
print(diff_tab[diff_tab$variable == "eta", ], digits = 3)
