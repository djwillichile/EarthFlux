# Experiment R: does GWR regionalize the weather variables of METRIC better
# than the conventional alternatives? (question of section 11 of the study
# brief; distinct from whether it improves ETa).
#
# For every overpass target time of the study period (cfg$cv_period, hour
# cfg$cv_overpass_utc_hours, UTC) and every variable used by METRIC (air
# temperature, vapour pressure, wind speed at 2 m), the configurations
#   C1      representative station (rule D-02, fixed before looking at the
#           results)
#   C1-lap  representative station with a fixed lapse rate (air temperature)
#   C2-OLS  global regression on elevation and distance to the coast
#   C2-IDW  inverse distance weighting, power selected by LOOCV in {1, 2, 3}
#   C3-GWR  GWR, adaptive bisquare kernel, k selected by AICc
# are evaluated by spatial block cross-validation (ef_regionalize_cv()) with
# the bandwidth/power re-selected inside every training set (nested; no
# leakage). Outputs: results/validation/cv_predictions.csv (every held-out
# prediction) and results/tables/cv_metrics.csv (metrics with bootstrap
# confidence intervals over target times).

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))

qc <- readRDS(p("data", "processed", "stations_qc.rds"))
meta <- utils::read.csv(p("data", "processed", "stations_meta.csv"),
                        stringsAsFactors = FALSE)
cov_region <- terra::rast(p("data", "processed", "covariates_region.tif"))

# Long regionalization input (dev/specs/weather-forcing.md section 7.2).
obs <- qc$observations
st <- qc$qc_status
hours <- cfg$cv_overpass_utc_hours
keep <- as.integer(format(obs$timestamp, "%H", tz = "UTC")) %in% hours
obs <- obs[keep, ]
st <- st[keep, ]
hgt <- meta$height_wind[match(obs$station_id, meta$station_id)]
long <- function(var_obs, var_name, value) {
  data.frame(station_id = obs$station_id,
             lon = meta$lon[match(obs$station_id, meta$station_id)],
             lat = meta$lat[match(obs$station_id, meta$station_id)],
             elevation = meta$elevation[match(obs$station_id, meta$station_id)],
             target_time = obs$timestamp, variable = var_name, value = value,
             qc_status = st[[var_obs]], stringsAsFactors = FALSE)
}
inputs <- list(
  air_temperature = long("air_temperature", "air_temperature",
                         obs$air_temperature),
  vapour_pressure = long("vapour_pressure", "vapour_pressure",
                         obs$vapour_pressure),
  wind_speed_2m = long("wind_speed", "wind_speed_2m",
                       ef_wind_2m(obs$wind_speed, hgt))
)
inputs <- lapply(inputs, function(d) d[!is.na(d$value), ])

# Representative station (D-02): the station closest to the centroid of the
# Cauquenes province among those with >= 90 % of the overpass records of
# the period for all three variables.
aoi <- terra::vect(system.file("extdata", "cauquenes-province.gpkg",
                               package = "EarthFlux"))
cen <- terra::crds(terra::centroids(terra::project(aoi, "EPSG:4326")))
n_times <- length(unique(obs$timestamp))
complete <- Reduce(intersect, lapply(inputs, function(d) {
  tab <- table(d$station_id)
  names(tab)[tab >= 0.9 * n_times]
}))
cand <- meta[meta$station_id %in% complete, ]
dist_km <- terra::distance(cbind(cand$lon, cand$lat), cen, lonlat = TRUE) / 1000
rep_station <- cand$station_id[which.min(dist_km)]
writeLines(c(rep_station, sprintf("%.1f km", min(dist_km))),
           p("results", "diagnostics", "representative_station.txt"))

# Spatial blocks (D-03): side cfg$spatial_block_size_m in UTM 18S.
xy <- terra::project(cbind(meta$lon, meta$lat), from = "EPSG:4326",
                     to = study_crs)
folds <- ef_spatial_folds(data.frame(station_id = meta$station_id,
                                     x = xy[, 1], y = xy[, 2]),
                          block_size = cfg$spatial_block_size_m)
write_csv(data.frame(station_id = names(folds), fold = as.integer(folds)),
          p("results", "diagnostics", "cv_folds.csv"))

methods <- list(
  "C1" = ef_method_station(rep_station),
  "C1-lap" = ef_method_station(rep_station, lapse_rate = 0.0065),
  "C2-OLS" = ef_method_ols(),
  "C2-IDW" = ef_method_idw(power = c(1, 2, 3)),
  "C3-GWR" = ef_method_gwr(kernel = "bisquare", adaptive = TRUE,
                           criterion = "AICc", search = ef_gwr_search())
)

run_cv <- function(variable, label) {
  m <- methods[[label]]
  if (label == "C1-lap" && variable != "air_temperature") return(NULL)
  cvr <- tryCatch(
    ef_regionalize_cv(inputs[[variable]], variable, covariates = cov_region,
                      method = m, folds = folds, use_qc = c("ok", "warning"),
                      surface_covariates = character(0),
                      reselect_bandwidth = TRUE),
    error = function(e) e
  )
  if (inherits(cvr, "error")) {
    message(variable, " ", label, ": ", conditionMessage(cvr))
    return(data.frame(variable = variable, config = label,
                      status = "error", reason = conditionMessage(cvr)))
  }
  d <- as.data.frame(cvr)
  d$config <- label
  d
}

# Optional parallel plan (EarthFlux never sets one; results are identical
# for any plan, dev/specs/parallel-processing.md).
workers <- as.integer(Sys.getenv("CEDES_WORKERS", "1"))
if (workers > 1) future::plan(future::multisession, workers = workers)

t0 <- Sys.time()
res <- list()
for (v in names(inputs)) for (lab in names(methods)) {
  message(format(Sys.time()), " ", v, " ", lab)
  res[[paste(v, lab)]] <- run_cv(v, lab)
}
cols <- c("station_id", "fold", "variable", "target_time", "observed",
          "predicted", "residual", "method", "status", "reason", "n_train",
          "tuning", "config")
pred <- do.call(rbind, lapply(res, function(d) {
  if (is.null(d)) return(NULL)
  for (cc in setdiff(cols, names(d))) d[[cc]] <- NA
  d[, cols]
}))
pred$target_time <- format(as.POSIXct(pred$target_time, origin = "1970-01-01",
                                      tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ",
                           tz = "UTC")
write_csv(pred, p("results", "validation", "cv_predictions.csv"))

## Metrics -------------------------------------------------------------------

# Point metrics over all held-out predictions; 95 % confidence intervals by a
# block bootstrap that resamples whole target times (days), which keeps the
# spatial dependence of the errors of one time together.
ok <- pred[pred$status == "ok" & !is.na(pred$residual), ]
metric_fun <- function(r) c(rmse = sqrt(mean(r^2)), mae = mean(abs(r)),
                            bias = mean(-r)) # bias = predicted - observed
boot_ci <- function(d, B) {
  times <- unique(d$target_time)
  idx <- split(seq_len(nrow(d)), d$target_time)
  bs <- replicate(B, {
    tt <- sample(times, length(times), replace = TRUE)
    metric_fun(d$residual[unlist(idx[tt], use.names = FALSE)])
  })
  apply(bs, 1, stats::quantile, probs = c(0.025, 0.975))
}
set.seed(cfg$seed)
met <- do.call(rbind, lapply(split(ok, list(ok$variable, ok$config), drop = TRUE),
                             function(d) {
  pt <- metric_fun(d$residual)
  ci <- boot_ci(d, cfg$bootstrap_replicates)
  data.frame(variable = d$variable[1], config = d$config[1],
             n_pred = nrow(d), n_times = length(unique(d$target_time)),
             n_stations = length(unique(d$station_id)),
             rmse = pt[["rmse"]], rmse_lo = ci[1, "rmse"], rmse_hi = ci[2, "rmse"],
             mae = pt[["mae"]], mae_lo = ci[1, "mae"], mae_hi = ci[2, "mae"],
             bias = pt[["bias"]], bias_lo = ci[1, "bias"], bias_hi = ci[2, "bias"],
             r = stats::cor(d$observed, d$predicted))
}))
fails <- stats::aggregate(status ~ variable + config, data = pred,
                          FUN = function(s) sum(s == "failed"))
names(fails)[3] <- "n_failed_folds"
met <- merge(met, fails, all.x = TRUE)
write_csv(met, p("results", "tables", "cv_metrics.csv"))

# Paired comparison against C3-GWR on the same held-out predictions:
# difference of squared errors, CI by the same time-block bootstrap.
paired <- list()
for (v in unique(ok$variable)) {
  g <- ok[ok$variable == v & ok$config == "C3-GWR", ]
  for (lab in setdiff(unique(ok$config[ok$variable == v]), "C3-GWR")) {
    o <- ok[ok$variable == v & ok$config == lab, ]
    mm <- merge(g[, c("station_id", "target_time", "residual")],
                o[, c("station_id", "target_time", "residual")],
                by = c("station_id", "target_time"), suffixes = c("_gwr", "_alt"))
    if (nrow(mm) == 0) next
    dse <- mm$residual_gwr^2 - mm$residual_alt^2
    idx <- split(seq_len(nrow(mm)), mm$target_time)
    bs <- replicate(cfg$bootstrap_replicates, {
      tt <- sample(names(idx), length(idx), replace = TRUE)
      mean(dse[unlist(idx[tt], use.names = FALSE)])
    })
    paired[[paste(v, lab)]] <- data.frame(
      variable = v, comparison = paste("C3-GWR vs", lab), n = nrow(mm),
      mean_dse = mean(dse), ci_lo = unname(stats::quantile(bs, 0.025)),
      ci_hi = unname(stats::quantile(bs, 0.975)),
      gwr_better_share = mean(abs(mm$residual_gwr) < abs(mm$residual_alt)))
  }
}
write_csv(do.call(rbind, paired), p("results", "tables", "cv_paired_vs_gwr.csv"))
message("elapsed: ", format(Sys.time() - t0))
print(met[, c("variable", "config", "n_pred", "rmse", "rmse_lo", "rmse_hi",
              "bias", "r", "n_failed_folds")], digits = 3)
