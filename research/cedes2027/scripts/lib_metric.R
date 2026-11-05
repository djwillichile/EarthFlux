# METRIC on the Cauquenes MODIS scene with an exchangeable weather forcing.
#
# Only exported EarthFlux functions are used (public API of 0.1.0.9000), in
# the order of tests/testthat/test-metric-chain.R. Every scientific choice
# that EarthFlux leaves without default is set in `metric_options()` and
# documented in docs/decisions.md (study decisions D-xx).
#
# The forcing is a list of matrices on the MODIS grid of the scene (same dim
# as the LST layer):
#   ta      air temperature at the overpass [degC]
#   ea      vapour pressure at the overpass [kPa]
#   u2      wind speed at 2 m at the overpass [m s-1]
#   etr_inst  hourly alfalfa reference ET at the overpass [mm h-1]
#   etr_24    daily alfalfa reference ET [mm d-1]
# A scalar (one station, C1) is a matrix with a constant value.

metric_options <- function(...) {
  o <- list(
    turbidity = 1,                 # Kt of Allen (1996) / ASCE: clean air
    g_method = "tasumi",           # soil heat flux (D-05)
    zom_method = "lai",            # momentum roughness from LAI (D-06)
    zom_station = 0.015,           # weather station (grass) roughness [m]
    zom_min = 0.005,               # bare-soil floor of zom [m] (D-06)
    blending_height = 200,         # [m]
    etrf_cold = 1.05,              # ETrF of the cold anchor (D-07)
    etrf_hot = 0,                  # ETrF of the hot anchor (D-07)
    lapse_rate = 0.0065,           # datum correction of Ts [K m-1]
    cold_ndvi_p = 0.95,            # cold candidates: NDVI >= Q(0.95)
    hot_ndvi_p = 0.10,             # hot candidates:  NDVI <= Q(0.10)
    cold_pick = 0.20,              # coolest 20 % of the cold candidates
    hot_pick = 0.20,               # hottest 20 % of the hot candidates
    aggregate = "median",          # one calibration point per class (P0-9)
    lambda_method = "constant"     # P0-7
  )
  mod <- list(...)
  o[names(mod)] <- mod
  o
}

# Static part of the scene: surface state, geometry and terrain.
scene_inputs <- function(scene, elevation) {
  m <- function(name) terra::as.matrix(scene[[name]], wide = TRUE)
  ll <- terra::project(terra::crds(scene[["lst"]], na.rm = FALSE),
                       from = terra::crs(scene), to = "EPSG:4326")
  dims <- c(terra::nrow(scene), terra::ncol(scene))
  lat <- matrix(ll[, 2], dims[1], dims[2], byrow = TRUE)
  lon <- matrix(ll[, 1], dims[1], dims[2], byrow = TRUE)
  s <- list(lst = m("lst"), albedo = m("albedo"), ndvi = m("ndvi"),
            lai = m("lai"), emissivity = m("emissivity"),
            utc_hour = m("utc_hour"), doy = m("doy"),
            elevation = terra::as.matrix(elevation, wide = TRUE),
            lat = lat, lon = lon)
  # Cells processed: every surface input and the elevation available.
  s$valid <- Reduce(`&`, lapply(s[c("lst", "albedo", "ndvi", "lai",
                                    "emissivity", "utc_hour", "elevation")],
                                function(x) !is.na(x)))
  s
}

deg2rad <- pi / 180
kelvin_offset <- 273.15 # = EarthFlux:::EF_KELVIN_OFFSET (internal constant)

# Alfalfa reference ET (ASCE-EWRI, hourly) at given times from the forcing
# fields: Rs is the modelled clear-sky-type shortwave of the METRIC radiation
# chain (Allen, 1996 transmissivity) because the stations of the study do not
# all measure solar radiation (D-04).
etr_hourly <- function(ta, ea, u2, elevation, lat, lon, doy, utc_mid,
                       turbidity = 1) {
  pressure <- ef_air_pressure(elevation)
  geo <- ef_solar_geometry(doy, utc_mid, lat * deg2rad, lon * deg2rad)
  cz <- pmax(geo$cos_zenith, 0)
  day <- geo$cos_zenith > 0.0
  rs <- array(0, dim(as.matrix(ta)))
  if (any(day)) {
    tau <- ef_tau_sw(cos_zenith = pmax(cz, 1e-3), pressure = pressure,
                     vapour_pressure = ea, turbidity = turbidity,
                     method = "allen")
    rsi <- ef_rs_in(cos_zenith = pmax(cz, 1e-3), cos_incidence = pmax(cz, 1e-3),
                    inv_distance = geo$inv_distance, tau_beam = tau$beam,
                    tau_diffuse = tau$diffuse, slope = 0, method = "modelled")
    rs <- ifelse(day, rsi$total, 0)
  }
  # Hourly radiation in MJ m-2 h-1; clear-sky radiation from Ra of the hour.
  rs_mj <- rs * 0.0036
  ra <- ef_ra_period(lat * deg2rad, lon * deg2rad, doy, utc_mid, 1, "asce")
  rso <- ef_rso(ra, elevation)
  rn <- ef_ref_net_radiation(rs_mj, rso, ea, air_temperature = ta,
                             timestep = "hourly", standard = "asce",
                             cloudiness = if (all(!day)) 0.7 else NULL)
  rn <- rn$rn
  g <- ef_ref_soil_heat_flux(rn, reference = "alfalfa", timestep = "hourly",
                             standard = "asce", daytime = rs_mj > 0)
  vpd <- pmax(ef_es(ta) - ea, 0)
  ef_ref_et(rn, g, ta, u2, vpd, ef_es_slope(ta), ef_psychrometric(pressure),
            reference = "alfalfa", timestep = "hourly", standard = "asce",
            daytime = rs_mj > 0)$et_ref
}

anchor_criteria <- function(o) {
  ef_anchor_criteria(
    cold = list(ef_anchor_rule("ndvi", ">=", o$cold_ndvi_p,
                               scale = "percentile")),
    hot = list(ef_anchor_rule("ndvi", "<=", o$hot_ndvi_p,
                              scale = "percentile")),
    homogeneity = NULL,
    select = list(cold = ef_anchor_pick("lst", "lowest_fraction", o$cold_pick),
                  hot = ef_anchor_pick("lst", "highest_fraction", o$hot_pick)),
    percentile_domain = "land", quantile_type = 7L,
    source = "CEDES 2027 study, decision D-08 (after Allen et al., 2007; Bhattarai et al., 2017)",
    status = "CANDIDATA"
  )
}

# Full chain. `anchors` may be given to keep the anchor cells fixed across
# configurations (control of the experiment); otherwise they are selected
# from the surface state (identical for every forcing, since the criteria
# use surface variables only).
run_metric <- function(s, forcing, o = metric_options(), anchors = NULL) {
  v <- s$valid & Reduce(`&`, lapply(forcing, function(x) !is.na(x)))
  sub <- function(x) if (length(x) == 1) x else x[v]
  ta_k <- sub(forcing$ta) + kelvin_offset
  pressure <- ef_air_pressure(sub(s$elevation))
  geo <- ef_solar_geometry(sub(s$doy), sub(s$utc_hour), sub(s$lat) * deg2rad,
                           sub(s$lon) * deg2rad)
  tau <- ef_tau_sw(cos_zenith = geo$cos_zenith, pressure = pressure,
                   vapour_pressure = sub(forcing$ea), turbidity = o$turbidity,
                   method = "allen")
  rs <- ef_rs_in(cos_zenith = geo$cos_zenith, cos_incidence = geo$cos_incidence,
                 inv_distance = geo$inv_distance, tau_beam = tau$beam,
                 tau_diffuse = tau$diffuse, slope = 0, method = "modelled")
  atm <- ef_atm_emissivity(tau$total)
  rl_in <- ef_rl_in(temperature = ta_k, atm_emissivity = atm)
  rl_out <- ef_rl_out(sub(s$lst), emissivity = sub(s$emissivity))
  rn <- ef_net_radiation(rs_in = rs$total, albedo = sub(s$albedo),
                         rl_in = rl_in, rl_out = rl_out,
                         emissivity = sub(s$emissivity))
  g <- ef_g(rn, lst = sub(s$lst), albedo = sub(s$albedo), ndvi = sub(s$ndvi),
            lai = sub(s$lai), method = o$g_method)
  zom <- ef_zom(lai = sub(s$lai), method = o$zom_method)
  # Study decision D-06: floor of the momentum roughness of bare soil
  # (zom = 0.018 LAI is 0 for LAI = 0); counted, not silent.
  n_zom_floor <- sum(zom$zom < o$zom_min, na.rm = TRUE)
  zom$zom <- pmax(zom$zom, o$zom_min)
  u_blend <- ef_blending_wind(sub(forcing$u2), height = 2,
                              zom_station = o$zom_station, d_station = 0,
                              blending_height = o$blending_height)
  # Anchors are selected on the full grid (row/col of the scene).
  if (is.null(anchors)) {
    lst_g <- s$lst; lst_g[!v] <- NA
    anchors <- ef_select_anchors(lst_g, s$ndvi, s$albedo, lai = s$lai,
                                 elevation = s$elevation,
                                 criteria = anchor_criteria(o),
                                 aggregate = o$aggregate)
  }
  full <- function(x) { m <- matrix(NA_real_, nrow(s$lst), ncol(s$lst)); m[v] <- x; m }
  lambda <- ef_lambda(method = o$lambda_method)
  # Anchor conditions read the grid layers at the anchor cells.
  ac <- ef_anchor_conditions(
    anchors, rn = full(rn), g = full(g$g), etr_inst = full(sub(forcing$etr_inst)),
    lambda = lambda, etrf_cold = o$etrf_cold, etrf_hot = o$etrf_hot,
    reference = "alfalfa", source = "CEDES 2027 study, decision D-07",
    status = "CANDIDATA", etr_source = "forcing configuration",
    zom = full(zom$zom), u_blend = full(u_blend), pressure = full(pressure)
  )
  datum <- stats::median(sub(s$elevation))
  cal <- ef_calibrate_h(ac, control = ef_h_control(), lapse_rate = o$lapse_rate,
                        datum_elevation = datum,
                        pixels = list(lst = sub(s$lst), elevation = sub(s$elevation),
                                      zom = zom$zom, u_blend = u_blend,
                                      pressure = pressure, rn = rn, g = g$g))
  le <- ef_latent_heat(rn, g$g, cal$pixels$h)
  et_inst <- ef_et_inst(le, lambda)
  etrf <- ef_etrf(et_inst, sub(forcing$etr_inst), reference = "alfalfa")
  eta <- ef_et_daily(etrf, sub(forcing$etr_24), reference = "alfalfa",
                     method = "etrf")
  layers <- list(rs_in = rs$total, rl_in = rl_in, rl_out = rl_out, rn = rn,
                 g = g$g, h = cal$pixels$h, le = le, et_inst = et_inst,
                 etrf = etrf, eta = eta$eta_24, dt = cal$pixels$dt,
                 rah = cal$pixels$rah, u_blend = u_blend,
                 converged = as.numeric(cal$pixels$converged))
  list(layers = lapply(layers, full), valid = v, anchors = anchors,
       calibration = cal, a = cal$a, b = cal$b, converged = cal$converged,
       iterations = cal$iterations, datum_elevation = datum,
       n_zom_floor = n_zom_floor,
       anchor_points = ac$calibration_points)
}
