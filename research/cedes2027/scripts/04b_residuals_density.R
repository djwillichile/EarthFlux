# Experiment R, continued.
# (1) Spatial dependence of the held-out residuals: Moran's I per target time
#     (inverse-distance weights within 100 km, row-standardised; permutation
#     test with 199 permutations), per variable and configuration.
# (2) Station density (hypothesis H3): the air temperature and vapour
#     pressure cross-validation is repeated with random subsets of 25, 50
#     and 75 % of the stations (10 subsets each, on 30 randomly chosen days),
#     for C2-OLS, C2-IDW and C3-GWR, with the same nested procedure.

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))

pred <- utils::read.csv(p("results", "validation", "cv_predictions.csv"),
                        stringsAsFactors = FALSE)
meta <- utils::read.csv(p("data", "processed", "stations_meta.csv"),
                        stringsAsFactors = FALSE)
xy <- terra::project(cbind(meta$lon, meta$lat), from = "EPSG:4326", to = study_crs)
rownames(xy) <- meta$station_id

moran <- function(z, coords, dmax = 100000) {
  d <- as.matrix(stats::dist(coords))
  w <- ifelse(d > 0 & d <= dmax, 1 / d, 0)
  rs <- rowSums(w); keep <- rs > 0
  if (sum(keep) < 5) return(c(I = NA, p = NA))
  w <- w[keep, keep] / rowSums(w[keep, keep]); z <- z[keep]
  zc <- z - mean(z)
  I <- sum(w * outer(zc, zc)) / sum(zc^2)
  perm <- replicate(199, { zp <- sample(zc); sum(w * outer(zp, zp)) / sum(zp^2) })
  c(I = I, p = (sum(perm >= I) + 1) / 200)
}
set.seed(cfg$seed + 10)
ok <- pred[pred$status == "ok" & !is.na(pred$residual), ]
mi <- do.call(rbind, lapply(split(ok, list(ok$variable, ok$config, ok$target_time), drop = TRUE),
                            function(d) {
  if (nrow(d) < 8) return(NULL)
  m <- moran(d$residual, xy[d$station_id, , drop = FALSE])
  data.frame(variable = d$variable[1], config = d$config[1], target_time = d$target_time[1],
             n = nrow(d), moran_I = m[["I"]], p = m[["p"]])
}))
write_csv(mi, p("results", "diagnostics", "cv_residual_moran.csv"))
mis <- do.call(rbind, lapply(split(mi, list(mi$variable, mi$config), drop = TRUE), function(d)
  data.frame(variable = d$variable[1], config = d$config[1], n_times = nrow(d),
             median_I = stats::median(d$moran_I, na.rm = TRUE),
             share_sig = mean(d$p < 0.05, na.rm = TRUE))))
write_csv(mis, p("results", "tables", "cv_residual_moran_summary.csv"))
print(mis, digits = 3)

## Station density -------------------------------------------------------------
qc <- readRDS(p("data", "processed", "stations_qc.rds"))
cov_region <- terra::rast(p("data", "processed", "covariates_region.tif"))
obs <- qc$observations; st <- qc$qc_status
keep <- as.integer(format(obs$timestamp, "%H", tz = "UTC")) %in% cfg$cv_overpass_utc_hours
obs <- obs[keep, ]; st <- st[keep, ]
mi_ <- match(obs$station_id, meta$station_id)
mk <- function(v) {
  d <- data.frame(station_id = obs$station_id, lon = meta$lon[mi_], lat = meta$lat[mi_],
                  elevation = meta$elevation[mi_], target_time = obs$timestamp,
                  variable = v, value = obs[[v]], qc_status = as.character(st[[v]]))
  d[!is.na(d$value), ]
}
folds_all <- utils::read.csv(p("results", "diagnostics", "cv_folds.csv"))
folds_all <- stats::setNames(folds_all$fold, folds_all$station_id)
days <- sort(unique(obs$timestamp))
set.seed(cfg$seed + 11)
days_sub <- sort(sample(days, min(30, length(days))))
methods <- list("C2-OLS" = ef_method_ols(),
                "C2-IDW" = ef_method_idw(power = c(1, 2, 3)),
                "C3-GWR" = ef_method_gwr(kernel = "bisquare", adaptive = TRUE,
                                         criterion = "AICc", search = ef_gwr_search()))
workers <- as.integer(Sys.getenv("CEDES_WORKERS", "1"))
if (workers > 1) future::plan(future::multisession, workers = workers)
fracs <- c(0.25, 0.50, 0.75, 1.00)
n_rep <- 10
dens <- list()
for (v in c("air_temperature", "vapour_pressure")) {
  dv <- mk(v); dv <- dv[dv$target_time %in% days_sub, ]
  ids <- unique(dv$station_id)
  for (f in fracs) for (r in seq_len(if (f == 1) 1 else n_rep)) {
    sub_ids <- if (f == 1) ids else sample(ids, round(f * length(ids)))
    d <- dv[dv$station_id %in% sub_ids, ]
    for (lab in names(methods)) {
      cvr <- tryCatch(ef_regionalize_cv(d, v, covariates = cov_region, method = methods[[lab]],
                                        folds = folds_all[sub_ids], use_qc = c("ok", "warning"),
                                        surface_covariates = character(0),
                                        reselect_bandwidth = TRUE), error = function(e) NULL)
      if (is.null(cvr)) {
        dens[[length(dens) + 1]] <- data.frame(variable = v, fraction = f, replicate = r,
                                               config = lab, n_stations = length(sub_ids),
                                               rmse = NA, n_pred = 0, share_failed = 1)
        next
      }
      x <- as.data.frame(cvr)
      okx <- x$status == "ok" & !is.na(x$residual)
      dens[[length(dens) + 1]] <- data.frame(
        variable = v, fraction = f, replicate = r, config = lab, n_stations = length(sub_ids),
        rmse = if (any(okx)) sqrt(mean(x$residual[okx]^2)) else NA,
        n_pred = sum(okx), share_failed = mean(x$status == "failed"))
    }
    message(v, " fraction ", f, " replicate ", r)
  }
}
dens <- do.call(rbind, dens)
write_csv(dens, p("results", "tables", "cv_station_density.csv"))
ds <- do.call(rbind, lapply(split(dens, list(dens$variable, dens$fraction, dens$config), drop = TRUE),
                            function(d) data.frame(variable = d$variable[1], fraction = d$fraction[1],
                                                   config = d$config[1], n_stations = round(mean(d$n_stations)),
                                                   rmse_mean = mean(d$rmse, na.rm = TRUE),
                                                   rmse_sd = stats::sd(d$rmse, na.rm = TRUE),
                                                   share_failed = mean(d$share_failed))))
write_csv(ds, p("results", "tables", "cv_station_density_summary.csv"))
print(ds, digits = 3)
