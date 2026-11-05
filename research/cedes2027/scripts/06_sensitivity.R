# Experiment S: sensitivity and robustness of ETa on the Cauquenes scene.
#
# Question: is the effect of the weather forcing configuration on ETa large
# compared with the uncertainty from other methodological choices and from
# the inputs? Four Monte Carlo / perturbation experiments, each run with the
# C1 and C3-GWR forcings of experiment M (05_metric_experiment.R):
#   S-A  anchor selection and boundary conditions: cold NDVI percentile
#        U(0.90, 0.98), hot NDVI percentile U(0.05, 0.20), fractions picked
#        U(0.10, 0.30), ETrF of the cold anchor U(1.00, 1.10);
#   S-B  MODIS inputs: LST + N(0, 1 K) spatially independent noise plus a
#        scene-wide bias N(0, 0.5 K) (MOD11 accuracy of about 1 K; Wan,
#        2014), albedo x (1 + N(0, 0.05)), NDVI and LAI unchanged;
#   S-C  structural alternatives (deterministic): soil heat flux of
#        Bastiaanssen vs Tasumi; zom floor 0.005 vs 0.01 m; aggregate mean vs
#        median;
#   S-D  station network (only when GWR is feasible): the forcing at the
#        overpass is regionalized again with a random 75 % of the stations
#        (C2-IDW and C3-GWR); ETr_24 kept from the full network.
# Replicates: cfg$monte_carlo_replicates (200; the standard error of a
# Monte Carlo mean is then sd/14, enough to resolve the differences of
# interest); seeds fixed per experiment.

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))
source(p("scripts", "lib_metric.R"))

mr <- readRDS(p("data", "processed", "metric_runs.rds"))
scene <- terra::unwrap(EarthFlux::cauquenes_modis)
elev_modis <- terra::rast(p("data", "processed", "elevation_scene_modis.tif"))
s0 <- scene_inputs(scene, elev_modis)
forc <- mr$forcings
cfgs <- intersect(c("C1", "C3-GWR"), names(forc))
if (!"C3-GWR" %in% cfgs) cfgs <- intersect(c("C1", "C2-IDW"), names(forc))
R <- as.integer(Sys.getenv("CEDES_MC_R", cfg$monte_carlo_replicates))

eta_stats <- function(res) {
  e <- res$layers$eta[res$valid]
  c(eta_mean = mean(e), eta_p05 = unname(stats::quantile(e, 0.05)),
    eta_p95 = unname(stats::quantile(e, 0.95)), a = res$a, b = res$b,
    converged = res$converged, n_neg = sum(e < 0))
}
safe_run <- function(s, f, o) {
  r <- tryCatch(run_metric(s, f, o), error = function(e) e)
  if (inherits(r, "error")) return(c(eta_mean = NA, eta_p05 = NA, eta_p95 = NA,
                                     a = NA, b = NA, converged = FALSE, n_neg = NA))
  eta_stats(r)
}
base_eta <- lapply(mr$runs[cfgs], function(r) r$layers$eta)

## S-A anchors and boundary conditions -----------------------------------------
set.seed(cfg$seed + 1)
par_a <- data.frame(cold_ndvi_p = stats::runif(R, 0.90, 0.98),
                    hot_ndvi_p = stats::runif(R, 0.05, 0.20),
                    cold_pick = stats::runif(R, 0.10, 0.30),
                    hot_pick = stats::runif(R, 0.10, 0.30),
                    etrf_cold = stats::runif(R, 1.00, 1.10))
sa <- do.call(rbind, lapply(seq_len(R), function(i) {
  o <- do.call(metric_options, as.list(par_a[i, ]))
  do.call(rbind, lapply(cfgs, function(cf)
    data.frame(experiment = "S-A", replicate = i, config = cf, par_a[i, ],
               t(safe_run(s0, forc[[cf]], o)))))
}))
write_csv(sa, p("results", "tables", "sensitivity_SA_anchors.csv"))

## S-B MODIS input noise --------------------------------------------------------
set.seed(cfg$seed + 2)
sb <- do.call(rbind, lapply(seq_len(R), function(i) {
  s <- s0
  bias <- stats::rnorm(1, 0, 0.5)
  s$lst <- s0$lst + bias + stats::rnorm(length(s0$lst), 0, 1)
  s$albedo <- s0$albedo * (1 + stats::rnorm(length(s0$albedo), 0, 0.05))
  do.call(rbind, lapply(cfgs, function(cf)
    data.frame(experiment = "S-B", replicate = i, config = cf, lst_bias = bias,
               t(safe_run(s, forc[[cf]], metric_options())))))
}))
write_csv(sb, p("results", "tables", "sensitivity_SB_modis.csv"))

## S-C structural alternatives ---------------------------------------------------
alts <- list(base = list(), g_bastiaanssen = list(g_method = "bastiaanssen"),
             zom_floor_0.01 = list(zom_min = 0.01), aggregate_mean = list(aggregate = "mean"))
sc <- do.call(rbind, lapply(names(alts), function(nm) {
  o <- do.call(metric_options, alts[[nm]])
  do.call(rbind, lapply(cfgs, function(cf)
    data.frame(experiment = "S-C", variant = nm, config = cf,
               t(safe_run(s0, forc[[cf]], o)))))
}))
write_csv(sc, p("results", "tables", "sensitivity_SC_structural.csv"))

## Summary: forcing effect vs other sources ---------------------------------------
summ <- function(d, label) {
  do.call(rbind, lapply(split(d, d$config), function(x) data.frame(
    source = label, config = x$config[1], n_ok = sum(!is.na(x$eta_mean)),
    eta_mean_mean = mean(x$eta_mean, na.rm = TRUE),
    eta_mean_sd = stats::sd(x$eta_mean, na.rm = TRUE),
    eta_mean_p025 = unname(stats::quantile(x$eta_mean, 0.025, na.rm = TRUE)),
    eta_mean_p975 = unname(stats::quantile(x$eta_mean, 0.975, na.rm = TRUE)),
    share_converged = mean(as.logical(x$converged), na.rm = TRUE))))
}
tab <- rbind(summ(sa, "S-A anchors/boundary"), summ(sb, "S-B MODIS noise"),
             summ(sc, "S-C structural"))
# Paired effect of the forcing within each replicate (same perturbation).
paired <- function(d, label) {
  w <- stats::reshape(d[, c("replicate", "config", "eta_mean")], idvar = "replicate",
                      timevar = "config", direction = "wide")
  dd <- w[[paste0("eta_mean.", cfgs[2])]] - w[[paste0("eta_mean.", cfgs[1])]]
  data.frame(source = label, contrast = paste(cfgs[2], "-", cfgs[1]),
             mean = mean(dd, na.rm = TRUE), sd = stats::sd(dd, na.rm = TRUE),
             p025 = unname(stats::quantile(dd, 0.025, na.rm = TRUE)),
             p975 = unname(stats::quantile(dd, 0.975, na.rm = TRUE)),
             share_same_sign = mean(sign(dd) == sign(mean(dd, na.rm = TRUE)), na.rm = TRUE))
}
pair_tab <- rbind(paired(sa, "S-A anchors/boundary"), paired(sb, "S-B MODIS noise"))
write_csv(tab, p("results", "tables", "sensitivity_summary.csv"))
write_csv(pair_tab, p("results", "tables", "sensitivity_forcing_effect.csv"))
print(tab, digits = 3)
print(pair_tab, digits = 3)
