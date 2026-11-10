# Cross-implementation verification: EarthFlux core vs the `water` package
# ===========================================================================
#
# Runs the METRIC example of `water` (Olmedo et al.; vignette
# "METRIC_advanced", Landsat 7 scene of Talca, Maule Region, Chile,
# 2013-02-15) and feeds exactly the same inputs to the numeric core of
# EarthFlux (`ef_*()` functions), stage by stage. Report:
# dev/verification/water-comparison.md (Spanish).
#
# This is a cross-implementation verification, not a validation: neither
# package is compared with measured fluxes.
#
# Requirements: the `water` package (version 1.0, terra based) installed in
# some library, and the EarthFlux source tree. No data file is read except
# the example data distributed with `water`; nothing is downloaded.
#
# Configuration (environment variables):
#   WATER_LIB       library where `water` is installed (default: the usual
#                   library paths).
#   EARTHFLUX_PATH  EarthFlux source tree (default: the working directory).
#   WATER_CMP_OUT   folder for the CSV tables and the RDS of results
#                   (default: a folder in tempdir()).
#   WATER_CMP_SIMPLE  "false" to skip the METRIC_simple run (default: run).
#
# Usage, from the root of the EarthFlux source tree:
#   WATER_LIB=/path/to/lib Rscript dev/verification/water-comparison.R
# Run time: about one minute.

cfg <- list(
  water_lib = Sys.getenv("WATER_LIB", ""),
  earthflux = Sys.getenv("EARTHFLUX_PATH", "."),
  out_dir = Sys.getenv("WATER_CMP_OUT",
                       file.path(tempdir(), "water-comparison")),
  run_simple = !identical(tolower(Sys.getenv("WATER_CMP_SIMPLE", "true")),
                          "false")
)
if (nzchar(cfg$water_lib)) .libPaths(c(cfg$water_lib, .libPaths()))
dir.create(cfg$out_dir, recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages({
  library(water)
  pkgload::load_all(cfg$earthflux, quiet = TRUE, export_all = FALSE)
})
ef <- asNamespace("EarthFlux")
wns <- asNamespace("water")

versions <- data.frame(
  item = c("R", "water", "terra", "sf", "EarthFlux"),
  version = c(paste(R.version$major, R.version$minor, sep = "."),
              as.character(utils::packageVersion("water")),
              as.character(utils::packageVersion("terra")),
              as.character(utils::packageVersion("sf")),
              as.character(getNamespaceVersion("EarthFlux")))
)
print(versions, row.names = FALSE)

# Helpers -------------------------------------------------------------------

v <- function(r) terra::values(r, mat = FALSE)  # terra cell order (row-major)

# Summary of the pixel differences EarthFlux - water
cmp <- function(stage, quantity, w, e, unit = "") {
  w <- as.vector(w)
  e <- as.vector(e)
  ok <- is.finite(w) & is.finite(e)
  d <- e[ok] - w[ok]
  fit <- if (sum(ok) > 2 && stats::sd(w[ok]) > 0) {
    stats::coef(stats::lm(e[ok] ~ w[ok]))
  } else {
    c(NA_real_, NA_real_)
  }
  data.frame(
    stage = stage, quantity = quantity, unit = unit, n = sum(ok),
    na_mismatch = sum(xor(is.na(w), is.na(e))),
    mean_water = mean(w[ok]), mean_ef = mean(e[ok]),
    mean_diff = mean(d), sd_diff = if (length(d) > 1) stats::sd(d) else 0,
    max_abs_diff = max(abs(d)),
    rel_max = max(abs(d)) / mean(abs(w[ok])),
    r = if (sum(ok) > 2 && stats::sd(w[ok]) > 0 && stats::sd(e[ok]) > 0) {
      stats::cor(w[ok], e[ok])
    } else {
      NA_real_
    },
    intercept = unname(fit[1]), slope = unname(fit[2]),
    stringsAsFactors = FALSE
  )
}
results <- list()
add <- function(...) results[[length(results) + 1L]] <<- cmp(...)
scalars <- list()
add_scalar <- function(item, water_value, ef_value, note = "") {
  scalars[[length(scalars) + 1L]] <<- data.frame(
    item = item, water = water_value, earthflux = ef_value,
    diff = ef_value - water_value, note = note, stringsAsFactors = FALSE
  )
}

# 1. The water example (vignette METRIC_advanced), every intermediate ---------

csvfile <- system.file("extdata", "apples.csv", package = "water")
MTLfile <- system.file("extdata", "L7.MTL.txt", package = "water")
WS <- read.WSdata(WSdata = csvfile, date.format = "%d/%m/%Y",
                  lat = -35.42222, long = -71.38639, elev = 201, height = 2.2,
                  columns = c("date" = 1, "time" = 2, "radiation" = 3,
                              "wind" = 4, "RH" = 6, "temp" = 7, "rain" = 8),
                  cf = c(1, 0.2777778, 1), MTL = MTLfile,
                  tz = "America/Santiago")
image.DN <- terra::rast(L7_Talca)
DEM <- terra::rast(DEM_Talca)
surface.model <- METRICtopo(DEM)
solar.angles <- solarAngles(surface.model = surface.model,
                            WeatherStation = WS, MTL = MTLfile)
Rs.inc <- incSWradiation(surface.model = surface.model,
                         solar.angles = solar.angles, WeatherStation = WS)
image.TOAr <- calcTOAr(image.DN = image.DN, sat = "L7", MTL = MTLfile,
                       incidence.rel = solar.angles$incidence.rel)
image.SR <- suppressWarnings(calcSR(image.TOAr = image.TOAr, sat = "L7",
                                    surface.model = surface.model,
                                    incidence.hor = solar.angles$incidence.hor,
                                    WeatherStation = WS))
alb <- albedo(image.SR = image.SR, coeff = "Tasumi", sat = "L7")
LAIr <- LAI(method = "metric2010", image = image.TOAr, L = 0.1)
Ts <- suppressWarnings(surfaceTemperature(image.DN = image.DN, LAI = LAIr,
                                          sat = "L7", WeatherStation = WS))
Rl.out <- outLWradiation(LAI = LAIr, Ts = Ts)
Rl.inc <- incLWradiation(WS, DEM = surface.model$DEM,
                         solar.angles = solar.angles, Ts = Ts)
Rn <- netRadiation(LAIr, alb, Rs.inc, Rl.inc, Rl.out)
G <- soilHeatFlux(image = image.SR, Ts = Ts, albedo = alb, Rn = Rn,
                  LAI = LAIr)
Z.om <- momentumRoughnessLength(LAI = LAIr, mountainous = TRUE,
                                method = "short.crops",
                                surface.model = surface.model)
anchors_w <- calcAnchors(image = image.TOAr, Ts = Ts, LAI = LAIr,
                         plots = FALSE, albedo = alb, Z.om = Z.om, n = 5,
                         anchors.method = "best", deltaTemp = 5,
                         WeatherStation = WS, verbose = FALSE)
h_log <- utils::capture.output(
  H <- withCallingHandlers(
    calcH(anchors = anchors_w, Ts = Ts, Z.om = Z.om, WeatherStation = WS,
          ETp.coef = 1.05, Z.om.ws = 0.03, DEM = DEM, Rn = Rn, G = G,
          verbose = TRUE, plots = FALSE),
    warning = function(w) {
      message("water calcH() warning: ", conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
)
ETr_24 <- suppressMessages(dailyET(WeatherStation = WS, MTL = MTLfile))
ET24 <- ET24h(Rn, G, H$H, Ts, WeatherStation = WS, ETr.daily = ETr_24,
              plots = FALSE)

nr <- terra::nrow(Ts)
nc <- terra::ncol(Ts)
m <- function(x) matrix(x, nrow = nr, ncol = nc, byrow = TRUE)

wsd <- getDataWS(WS)                       # weather at the overpass
ea <- (wsd$RH / 100) * 0.6108 * exp(17.27 * wsd$temp / (wsd$temp + 237.3))
ETr_inst <- hourlyET(WS, ET = "ETr")       # mm/h, hour centred on the overpass
sat_time <- wns$mtlDateTime(readLines(MTLfile, warn = FALSE))
sat_lt <- as.POSIXlt(sat_time, tz = "UTC")
doy <- sat_lt$yday + 1
utc_hour <- sat_lt$hour + sat_lt$min / 60 + sat_lt$sec / 3600

W <- list(
  dem = v(surface.model$DEM), slope = v(surface.model$Slope),
  aspect_w = v(surface.model$Aspect),       # terra aspect - pi (water)
  lat = v(solar.angles$latitude), dec = v(solar.angles$declination),
  hour_angle = v(solar.angles$hour.angle),
  cos_hor = cos(v(solar.angles$incidence.hor)),
  cos_rel = cos(v(solar.angles$incidence.rel)),
  rs_in = v(Rs.inc), albedo = v(alb), lai = v(LAIr), ts = v(Ts),
  rl_out = v(Rl.out), rl_in = v(Rl.inc), rn = v(Rn), g = v(G),
  zom = v(Z.om), h = v(H$H), dt = v(H$dT),
  ndvi_toa = v((image.TOAr$NIR - image.TOAr$R) /
                 (image.TOAr$NIR + image.TOAr$R)),
  ndvi_sr = v((image.SR$NIR - image.SR$R) / (image.SR$NIR + image.SR$R)),
  et24 = v(ET24)
)
# Emissivities of water: narrow band (thermal band, Ts) and broad band (RL)
W$eps_nb <- ifelse(W$lai > 3, 0.98, 0.97 + 0.0033 * W$lai)
W$eps_0 <- ifelse(W$lai > 3, 0.98, 0.95 + 0.01 * W$lai)
W$le <- W$rn - W$g - W$h
# ET24h() returns only ET_24 for layers (not a METRIC.EB() result): its
# ET_inst and ETrF are recomputed with its own expressions (water_ET.R,
# ET24h()) and checked against the ET_24 it returns
W$et_inst <- 3600 * W$le / ((2.501 - 0.00236 * (W$ts - 273.15)) * 1e6)
W$etrf <- W$et_inst / ETr_inst
stopifnot(isTRUE(all.equal(pmax(W$etrf * ETr_24, 0), W$et24)))
W$pressure <- ef$ef_air_pressure(W$dem)
W$tau_sw <- v(SWtransmissivity(Kt = 1, ea, surface.model$DEM,
                               solar.angles$incidence.hor))
W$atm_emis <- 0.85 * (-log(W$tau_sw))^0.09

# Calibration recorded by calcH(verbose = TRUE): a (slope), b (intercept),
# rah and dT at the anchors, per iteration
num_after <- function(lines, key) {
  x <- grep(paste0("^\\[1\\] \"", key, " "), lines, value = TRUE)
  as.numeric(sub(paste0("^\\[1\\] \"", key, " (.*)\"$"), "\\1", x))
}
water_iter <- data.frame(
  iteration = seq_along(num_after(h_log, "a")),
  slope_a = num_after(h_log, "a"), intercept_b = num_after(h_log, "b"),
  rah_cold_prev = num_after(h_log, "r.ah cold"),
  rah_hot_prev = num_after(h_log, "r.ah hot"),
  dt_cold = num_after(h_log, "dT cold"), dt_hot = num_after(h_log, "dT hot")
)
hot_cells <- anchors_w$pixel[anchors_w$type == "hot"]
cold_cells <- anchors_w$pixel[anchors_w$type == "cold"]
u200_used <- H$u200
lapse_w <- 6.49 / 1000                       # calcH(lapse = 6.49) K/m
W$ts_datum <- W$ts + (W$dem - WS$location$elev) * lapse_w
u200_raw <- wsd$wind * log(200 / 0.03) / log(wsd$height / 0.03)

settings_water <- data.frame(
  step = c("weather", "image", "albedo", "LAI", "Ts", "eps_NB / eps_0",
           "Rs_in", "RL_in", "Rn", "G", "z_om", "anchors", "H",
           "u200", "ETr", "ET_inst", "ET_24"),
  setting = c(
    "read.WSdata(apples.csv, height = 2.2, cf wind 0.2777778, tz America/Santiago), at.sat interpolated at the overpass",
    "L7_Talca (DN), DEM_Talca; METRICtopo(DEM), solarAngles(), calcTOAr(), calcSR()",
    "albedo(coeff = 'Tasumi', sat = 'L7') on surface reflectance",
    "LAI(method = 'metric2010', L = 0.1) on TOA reflectance",
    "surfaceTemperature(sat = 'L7', method 'METRIC': tau_NB 0.866, Rp 0.91, Rsky 1.32)",
    "eps_NB = 0.97 + 0.0033 LAI, eps_0 = 0.95 + 0.01 LAI (0.98 if LAI > 3)",
    "incSWradiation(Kt = 1): 1367 cos(theta_rel) tau_sw / d2, tau_sw = tau_B + tau_D from cos(theta_hor)",
    "incLWradiation(): 0.85 (-ln tau_sw)^0.09 sigma Ts^4, Ts of each pixel",
    "netRadiation(): (1 - albedo) Rs + RL_in - RL_out - (1 - eps_0) RL_in, sigma = 5.67e-8",
    "soilHeatFlux(method = 'Tasumi')",
    "momentumRoughnessLength('short.crops', mountainous = TRUE): 0.018 LAI (1 + (slope_deg - 5)/20), min 0.005",
    "calcAnchors(anchors.method = 'best', n = 5, deltaTemp = 5, WSbuffer 30 km)",
    "calcH(method 'mean', ETp.coef = 1.05, ETrF.hot = 0, Z.om.ws = 0.03, DEM, lapse 6.49 K/km, maxit 20, damping 0)",
    sprintf("calcH(u200.min = 2): %.3f m/s extrapolated, %.0f m/s used", u200_raw, u200_used),
    "hourlyET(ET = 'ETr', hour centred on the overpass); dailyET() (23 hourly periods)",
    "ET24h(): 3600 LE / ((2.501 - 0.00236 (Ts - 273.15)) 1e6)",
    "ET24h(): ETrF ETr_24 C.rad (C.rad = 1), negative values set to 0"
  )
)

# 2. Stage by stage, each EarthFlux stage fed with the water inputs ----------

deg <- pi / 180
# Solar geometry: latitude per row as water; longitude of the station (water)
geo <- ef_solar_geometry(doy = doy, utc_hour = utc_hour, lat = W$lat,
                         lon = WS$location$long * deg, slope = W$slope,
                         aspect = W$aspect_w + pi)
add("geometria", "cos(theta_hor)", W$cos_hor, geo$cos_zenith)
add("geometria", "cos(theta_rel)", W$cos_rel, geo$cos_incidence)
add("geometria", "hour angle", W$hour_angle, geo$hour_angle, "rad")
geo_pixlon <- ef_solar_geometry(
  doy = doy, utc_hour = utc_hour, lat = W$lat,
  lon = {
    xy <- terra::xyFromCell(Ts, seq_len(terra::ncell(Ts)))
    sf::st_coordinates(sf::st_transform(
      sf::st_as_sf(data.frame(x = xy[, 1], y = xy[, 2]), coords = c("x", "y"),
                   crs = terra::crs(Ts)), 4326))[, 1] * deg
  },
  slope = W$slope, aspect = W$aspect_w + pi
)
add("geometria (sensibilidad)", "cos(theta_hor), longitud del pixel",
    W$cos_hor, geo_pixlon$cos_zenith)

tau <- ef_tau_sw_allen(cos_zenith = geo$cos_zenith, pressure = W$pressure,
                       vapour_pressure = ea, turbidity = 1)
add("Rs_in", "tau_sw", W$tau_sw, tau$total)
# Closest option to water: total tau on the beam, no diffuse partition, no
# reflected term (ground_albedo = 0)
rs_ef <- ef_rs_in_modelled(cos_zenith = geo$cos_zenith,
                           cos_incidence = geo$cos_incidence,
                           inv_distance = geo$inv_distance,
                           tau_beam = tau$total, tau_diffuse = 0,
                           slope = W$slope, ground_albedo = 0)
add("Rs_in", "Rs_in (tau total al haz, sin difusa)", W$rs_in, rs_ef$total,
    "W m-2")
flat <- W$slope == 0
add("Rs_in", "Rs_in, pixeles planos", W$rs_in[flat], rs_ef$total[flat],
    "W m-2")
# The whole difference is the solar constant: the ratio is Gsc_EF / 1367
ratio_dev <- function(e, w, k) max(abs(e / w - k)[is.finite(e / w)])
add_scalar("max |Rs_in EF / water - Gsc_EF / 1367|",
           0, ratio_dev(rs_ef$total, W$rs_in, ef$EF_SOLAR_CONSTANT / 1367),
           sprintf("Gsc_EF / 1367 = %.7f", ef$EF_SOLAR_CONSTANT / 1367))
rs_part <- ef_rs_in_modelled(cos_zenith = geo$cos_zenith,
                             cos_incidence = geo$cos_incidence,
                             inv_distance = geo$inv_distance,
                             tau_beam = tau$beam, tau_diffuse = tau$diffuse,
                             slope = W$slope,
                             ground_albedo = mean(W$albedo, na.rm = TRUE))
add("Rs_in (sensibilidad)", "Rs_in particionada (haz + difusa + reflejada)",
    W$rs_in, rs_part$total, "W m-2")

atm <- ef_atm_emissivity(W$tau_sw)
add("RL_in", "eps_a", W$atm_emis, atm)
rl_in_ef <- ef_rl_in(temperature = W$ts, atm_emissivity = atm)
add("RL_in", "RL_in (T = Ts del pixel)", W$rl_in, rl_in_ef, "W m-2")
rl_out_ef <- ef_rl_out(lst = W$ts, emissivity = W$eps_0)
add("RL_out", "RL_out", W$rl_out, rl_out_ef, "W m-2")
add_scalar("max |RL EF / water - sigma_EF / 5.67e-8| (RL_in, RL_out)", 0,
           max(ratio_dev(rl_in_ef, W$rl_in, ef$EF_STEFAN_BOLTZMANN / 5.67e-8),
               ratio_dev(rl_out_ef, W$rl_out,
                         ef$EF_STEFAN_BOLTZMANN / 5.67e-8)),
           sprintf("sigma_EF / 5.67e-8 = %.7f", ef$EF_STEFAN_BOLTZMANN / 5.67e-8))
rn_iso <- ef_net_radiation(rs_in = W$rs_in, albedo = W$albedo,
                           rl_in = W$rl_in, rl_out = W$rl_out,
                           emissivity = W$eps_0)
add("Rn", "Rn (componentes de water)", W$rn, rn_iso, "W m-2")
rn_ch <- ef_net_radiation(rs_in = rs_ef$total, albedo = W$albedo,
                          rl_in = rl_in_ef, rl_out = rl_out_ef,
                          emissivity = W$eps_0)
add("Rn", "Rn (componentes de EarthFlux)", W$rn, rn_ch, "W m-2")

g_iso <- ef_g_tasumi(rn = W$rn, lst = W$ts, lai = W$lai)
add("G", "G Tasumi (Rn de water)", W$g, g_iso, "W m-2")
low <- W$lai < 0.5
add("G", "G Tasumi, LAI < 0.5", W$g[low], g_iso[low], "W m-2")
add("G", "G Tasumi, LAI >= 0.5", W$g[!low], g_iso[!low], "W m-2")

zom_lai <- ef_zom_lai(W$lai)
zom_floor <- pmax(zom_lai, 0.005)            # minimum of the presets (M5-24)
add("z_om", "z_om = 0.018 LAI, min 0.005 (sin factor de terreno)", W$zom,
    zom_floor, "m")
zom_terrain <- pmax(zom_lai * (1 + (W$slope / deg - 5) / 20), 0.005)
add("z_om", "z_om con factor de terreno de water (Ec. 12-9, sin minimo 1)",
    W$zom, zom_terrain, "m")

u_blend <- ef_blending_wind(wind_speed = wsd$wind, height = wsd$height,
                            zom_station = 0.03, d_station = 0)
add_scalar("u200 extrapolado [m/s]", u200_raw, u_blend,
           "water lo eleva a u200.min = 2 m/s; EarthFlux no tiene minimo (SH-06)")

# Anchors: the same cells as water, mean aggregation (water: method "mean")
anc <- ef_anchors(cold = cold_cells, hot = hot_cells, lst = m(W$ts),
                  ndvi = m(W$ndvi_toa), albedo = m(W$albedo), lai = m(W$lai),
                  elevation = m(W$dem), aggregate = "mean",
                  note = "anchor cells of water calcAnchors('best', n = 5)")
lambda_ts <- ef_lambda(temperature = W$ts, method = "fao56")
anc <- ef_anchor_conditions(
  anc, rn = m(W$rn), g = m(W$g), etr_inst = ETr_inst, lambda = m(lambda_ts),
  etrf_cold = 1.05, etrf_hot = 0, reference = "alfalfa",
  source = "water vignette METRIC_advanced (ETp.coef 1.05, ETrF.hot 0)",
  status = "CANDIDATA", zom = m(W$zom), u_blend = u200_used,
  pressure = m(W$pressure)
)
cp_pts <- anc$calibration_points
le_cold_w <- ETr_inst * 1.05 *
  (2.501 - 0.002361 * (mean(W$ts[cold_cells]) - 273.15)) * 1e6 / 3600
add_scalar("LE_cold objetivo [W/m2]", le_cold_w,
           cp_pts$le_target[cp_pts$type == "cold"])
add_scalar("H_cold objetivo [W/m2]",
           mean(W$rn[cold_cells]) - mean(W$g[cold_cells]) - le_cold_w,
           cp_pts$h_target[cp_pts$type == "cold"])
add_scalar("H_hot objetivo [W/m2]",
           mean(W$rn[hot_cells]) - mean(W$g[hot_cells]),
           cp_pts$h_target[cp_pts$type == "hot"])

# Convergence as in water (1 % change of rah, at most 20 iterations) in both
# phases: the settings of EarthFlux 0.1.0. Decision M2-11 changed the
# defaults (section 3b below compares them).
ctrl <- ef_h_control(stable_psi_m_height = 2, blending_height = 200,
                     z1 = 0.1, z2 = 2, tol = 0.01, maxit = 20L, damping = 0,
                     pixel_tol = 0.01, pixel_maxit = 20L)
pix <- list(lst = m(W$ts), elevation = m(W$dem), zom = m(W$zom),
            u_blend = m(rep(u200_used, length(W$ts))),
            pressure = m(W$pressure), rn = m(W$rn), g = m(W$g))
cal <- suppressWarnings(ef_calibrate_h(
  anc, control = ctrl, lapse_rate = lapse_w,
  datum_elevation = WS$location$elev, pixels = pix
))
add_scalar("pendiente de dT [-] (water a, EarthFlux b)", H$a, cal$b)
add_scalar("intercepto de dT [K] (water b, EarthFlux a)", H$b, cal$a)
add_scalar("iteraciones", max(water_iter$iteration), cal$iterations)
tv <- function(x) as.vector(t(x))             # EarthFlux matrix -> terra order
add("dT", "dT", W$dt, tv(cal$pixels$dt), "K")
add("H", "H (Rn, G, z_om, anclas de water)", W$h, tv(cal$pixels$h), "W m-2")
add("Ts_datum", "Ts_datum", W$ts_datum, tv(cal$pixels$ts_datum), "K")

le_iso <- ef_latent_heat(W$rn, W$g, W$h)
add("LE", "LE (Rn, G, H de water)", W$le, le_iso, "W m-2")
et_inst_iso <- ef_et_inst(W$le, ef_lambda(temperature = W$ts,
                                          method = "fao56"))
add("ET_inst", "ET_inst (lambda FAO-56 de Ts)", W$et_inst, et_inst_iso,
    "mm h-1")
etrf_iso <- ef_etrf(W$et_inst, ETr_inst, reference = "alfalfa")
add("ETrF", "ETrF (ET_inst de water)", W$etrf, etrf_iso)
et24_iso <- ef_et_daily(W$etrf, ETr_24, reference = "alfalfa",
                        method = "etrf")$eta_24
add("ET_24", "ET_24 (ETrF de water)", W$et24, et24_iso, "mm d-1")
pos <- W$etrf >= 0
add("ET_24", "ET_24, ETrF >= 0", W$et24[pos], et24_iso[pos], "mm d-1")

# Chain from H of EarthFlux with the water anchors
le_ch <- ef_latent_heat(W$rn, W$g, tv(cal$pixels$h))
et_inst_ch <- ef_et_inst(le_ch, lambda_ts)
etrf_ch <- ef_etrf(et_inst_ch, ETr_inst, reference = "alfalfa")
et24_ch <- ef_et_daily(etrf_ch, ETr_24, reference = "alfalfa",
                       method = "etrf")$eta_24
add("LE", "LE (H de EarthFlux)", W$le, le_ch, "W m-2")
add("ETrF", "ETrF (H de EarthFlux)", W$etrf, etrf_ch)
add("ET_24", "ET_24 (H de EarthFlux)", W$et24, et24_ch, "mm d-1")

# 3. Decomposition of the H differences: a transparent emulator ---------------
#
# One function with the formulas shared by both packages (SEBAL Idaho manual,
# Eqs. 25-41) and a switch for each point where they differ. With all
# switches on "water" it must reproduce calcH(); with all on "earthflux" it
# must reproduce ef_calibrate_h(). Switching one at a time, in order, gives
# the contribution of each difference.

rho_293 <- function(t, p) 1000 * p / (1.01 * t * 287)        # FAO-56 box 6
rho_pta <- function(ta, z) 349.467 * (((ta - 0.0065 * z) / ta)^5.26) / ta
psi_fun <- function(l, z, type, stable_height) {
  out <- rep(0, length(l))
  st <- !is.na(l) & l > 0
  un <- !is.na(l) & l < 0
  out[is.na(l)] <- NA
  zz <- if (type == "m") stable_height else z
  out[st] <- -5 * zz / l[st]
  x <- (1 - 16 * z / l[un])^0.25
  out[un] <- if (type == "m") {
    2 * log((1 + x) / 2) + log((1 + x^2) / 2) - 2 * atan(x) + pi / 2
  } else {
    2 * log((1 + x^2) / 2)
  }
  out
}
emu_step <- function(s, dt, sw) {
  k <- 0.41
  cp <- 1004
  rho_h <- if (sw$rho_h == "Ta_PTa") rho_pta(s$ts - dt, s$z) else
    rho_293(s$ts - dt, s$p)
  h <- rho_h * cp * dt / s$rah
  rho_l <- if (sw$rho_l == "Ts_P293") rho_293(s$ts, s$p) else
    rho_293(s$ts - dt, s$p)
  l <- -rho_l * cp * s$fv^3 * s$ts / (k * sw$g * h)
  psim <- psi_fun(l, 200, "m", 2)
  fv <- k * s$u / (log(200 / s$zom) - psim)
  fv[!is.na(fv) & fv <= 0] <- NA
  rah <- (log(2 / 0.1) - psi_fun(l, 2, "h") + psi_fun(l, 0.1, "h")) / (fv * k)
  list(h = h, fv = fv, rah = rah, rho_h = rho_h)
}
emu_init <- function(ts, tsd, z, p, zom, u) {
  fv <- 0.41 * u / log(200 / zom)
  list(ts = ts, tsd = tsd, z = z, p = p, zom = zom, u = u, fv = fv,
       rah = log(2 / 0.1) / (fv * 0.41))
}
emu_h <- function(sw, maxit = 20, tol = 0.01) {
  # Phase A: the anchors
  sel <- c(hot_cells, cold_cells)
  is_hot <- c(rep(TRUE, length(hot_cells)), rep(FALSE, length(cold_cells)))
  if (sw$agg == "pixels") {
    s <- emu_init(W$ts[sel], W$ts_datum[sel], W$dem[sel], W$pressure[sel],
                  W$zom[sel], u200_used)
  } else {
    mm <- function(x) c(mean(x[hot_cells]), mean(x[cold_cells]))
    s <- emu_init(mm(W$ts), mm(W$ts_datum), mm(W$dem), mm(W$pressure),
                  mm(W$zom), u200_used)
    is_hot <- c(TRUE, FALSE)
  }
  h_hot <- mean(W$rn[hot_cells]) - mean(W$g[hot_cells])
  h_cold <- mean(W$rn[cold_cells]) - mean(W$g[cold_cells]) - le_cold_w
  dt <- rep(0, length(s$ts))
  seq_ab <- list()
  last <- FALSE
  for (i in seq_len(maxit)) {
    rho <- if (sw$rho_h == "Ta_PTa") rho_pta(s$ts - dt, s$z) else
      rho_293(s$ts - dt, s$p)
    dt_c <- h_cold * mean(s$rah[!is_hot]) / (mean(rho[!is_hot]) * 1004)
    dt_h <- h_hot * mean(s$rah[is_hot]) / (mean(rho[is_hot]) * 1004)
    slope <- (dt_h - dt_c) / (mean(s$tsd[is_hot]) - mean(s$tsd[!is_hot]))
    icpt <- dt_c - slope * mean(s$tsd[!is_hot])
    seq_ab[[i]] <- c(icpt, slope)
    if (last) break
    prev <- s$rah
    dt <- icpt + slope * s$tsd
    st <- emu_step(s, dt, sw)
    s$fv <- st$fv
    s$rah <- st$rah
    ch <- c(abs(mean(s$rah[is_hot]) - mean(prev[is_hot])) / mean(s$rah[is_hot]),
            abs(mean(s$rah[!is_hot]) - mean(prev[!is_hot])) /
              mean(s$rah[!is_hot]))
    if (all(ch < tol)) last <- TRUE
  }
  fin <- seq_ab[[length(seq_ab)]]
  # Phase B: every pixel
  p <- emu_init(W$ts, W$ts_datum, W$dem, W$pressure, W$zom, u200_used)
  if (sw$pixel == "replay") {
    for (j in seq_along(seq_ab)) {
      dt <- seq_ab[[j]][1] + seq_ab[[j]][2] * p$tsd
      st <- emu_step(p, dt, sw)
      h <- st$h
      p$fv <- st$fv
      p$rah <- st$rah
    }
  } else {
    dt <- fin[1] + fin[2] * p$tsd
    active <- rep(TRUE, length(dt))
    for (k in seq_len(maxit)) {
      st <- emu_step(p, dt, sw)
      ch <- abs(st$rah - p$rah) / st$rah
      upd <- active & !is.na(st$rah)
      p$fv[upd] <- st$fv[upd]
      p$rah[upd] <- st$rah[upd]
      active <- active & !is.na(ch) & ch >= tol
      if (!any(active)) break
    }
    rho_h <- if (sw$rho_h == "Ta_PTa") rho_pta(p$ts - dt, p$z) else
      rho_293(p$ts - dt, p$p)
    h <- rho_h * 1004 * dt / p$rah
  }
  list(intercept = fin[1], slope = fin[2], n_ab = length(seq_ab), h = h)
}

sw_water <- list(g = 9.807, rho_l = "Ts_P293", rho_h = "Ta_PTa",
                 agg = "pixels", pixel = "replay")
steps <- list(
  list(label = "water (emulado)", change = NULL),
  list(label = "g = 9.81", change = list(g = 9.81)),
  list(label = "rho de L a Ta = Ts - dT", change = list(rho_l = "Ta_P293")),
  list(label = "rho de H con P(z) FAO-56 (293 K)",
       change = list(rho_h = "Ta_P293")),
  list(label = "un punto de calibracion por clase (media)",
       change = list(agg = "point")),
  list(label = "fase B por pixel con a, b finales (P2)",
       change = list(pixel = "converge"))
)
sw <- sw_water
emu_tab <- list()
prev_h <- NULL
for (st in steps) {
  sw[names(st$change)] <- st$change
  r <- emu_h(sw)
  et24_e <- ef_et_daily(
    ef_etrf(ef_et_inst(W$rn - W$g - r$h, lambda_ts), ETr_inst, "alfalfa"),
    ETr_24, "alfalfa", "etrf")$eta_24
  d_prev <- if (is.null(prev_h)) NA_real_ else r$h - prev_h
  emu_tab[[length(emu_tab) + 1L]] <- data.frame(
    step = st$label, slope = r$slope, intercept = r$intercept,
    n_ab = r$n_ab, mean_h = mean(r$h, na.rm = TRUE),
    mean_dh_vs_prev = if (is.null(prev_h)) NA else mean(d_prev, na.rm = TRUE),
    max_abs_dh_vs_prev = if (is.null(prev_h)) NA else
      max(abs(d_prev), na.rm = TRUE),
    max_abs_dh_vs_water = max(abs(r$h - W$h), na.rm = TRUE),
    mean_et24 = mean(et24_e, na.rm = TRUE)
  )
  prev_h <- r$h
  if (st$label == "water (emulado)") emu_water <- r
}
emu_ef <- r
emu_tab <- do.call(rbind, emu_tab)

# Pixel phase of EarthFlux: iterations and convergence (tol = pixel_tol =
# 0.01)
phase_b <- data.frame(
  converged = mean(cal$pixels$converged, na.rm = TRUE),
  iterations_median = stats::median(cal$pixels$iterations, na.rm = TRUE),
  iterations_max = max(cal$pixels$iterations, na.rm = TRUE)
)
# Water replay: change of rah in the last replayed step, per pixel
rep_change <- local({
  p <- emu_init(W$ts, W$ts_datum, W$dem, W$pressure, W$zom, u200_used)
  ab <- cbind(water_iter$intercept_b, water_iter$slope_a)
  prev <- p$rah
  for (j in seq_len(nrow(ab))) {
    prev <- p$rah
    st <- emu_step(p, ab[j, 1] + ab[j, 2] * p$tsd, sw_water)
    p$fv <- st$fv
    p$rah <- st$rah
  }
  abs(p$rah - prev) / p$rah
})
phase_b$water_last_step_change_gt_1pct <- mean(rep_change > 0.01,
                                               na.rm = TRUE)
dh_b <- tv(cal$pixels$h) - W$h
phase_b$share_abs_dh_gt_0.5 <- mean(abs(dh_b) > 0.5, na.rm = TRUE)

# The same algorithms iterated to the fixed point (tol = 1e-10): what the
# stopping rule (1 %) leaves, separately from the formulas
ctrl_tight <- ef_h_control(tol = 1e-10, maxit = 500L, pixel_tol = 1e-10,
                           pixel_maxit = 500L)
cal_tight <- suppressWarnings(ef_calibrate_h(
  anc, control = ctrl_tight, lapse_rate = lapse_w,
  datum_elevation = WS$location$elev, pixels = pix
))
emu_w_tight <- emu_h(sw_water, maxit = 500, tol = 1e-10)
fixed_point <- data.frame(
  run = c("water (calcH, 1 %)", "water emulado, tol 1e-10",
          "EarthFlux (tol 0.01)", "EarthFlux, tol 1e-10"),
  slope = c(H$a, emu_w_tight$slope, cal$b, cal_tight$b),
  intercept = c(H$b, emu_w_tight$intercept, cal$a, cal_tight$a),
  n_ab = c(nrow(water_iter), emu_w_tight$n_ab, cal$iterations + 1,
           cal_tight$iterations + 1),
  mean_h = c(mean(W$h, na.rm = TRUE), mean(emu_w_tight$h, na.rm = TRUE),
             mean(cal$pixels$h, na.rm = TRUE),
             mean(cal_tight$pixels$h, na.rm = TRUE))
)
add("H (punto fijo)", "H, ambos iterados a tol 1e-10", emu_w_tight$h,
    tv(cal_tight$pixels$h), "W m-2")
add("emulador", "H emulado (water) vs calcH()", W$h, emu_water$h, "W m-2")
add("emulador", "H emulado (EarthFlux) vs ef_calibrate_h()",
    tv(cal$pixels$h), emu_ef$h, "W m-2")

# 3b. Convergence settings of ef_calibrate_h() (decision M2-11) --------------
#
# Each phase has its own tolerance: `tol`/`maxit` at the anchors (phase A),
# `pixel_tol`/`pixel_maxit` per pixel (phase B). The runs separate the
# effect of each phase on H: distance to the fixed point of both phases
# (cal_tight), difference from water, H of phase B at the calibration
# points against H_target (the anchors reproduce their target in phase B
# only if phase A reached its fixed point) and run time of
# ef_calibrate_h() (median of 5 runs, all pixels).
cp_ab <- cp_pts[match(c("hot", "cold"), cp_pts$type), ]
pix_anchors <- list(lst = cp_ab$lst, elevation = cp_ab$elevation,
                    zom = cp_ab$zom, u_blend = cp_ab$u_blend,
                    pressure = cp_ab$pressure)
h_target_ab <- cp_ab$rn - cp_ab$g - cp_ab$le_target
conv_runs <- list(
  "0.1.0 / water: tol 0.01, pixel_tol 0.01" = ctrl,
  "tol 0.01, pixel_tol 1e-10" = ef_h_control(tol = 0.01, maxit = 20L,
                                             pixel_tol = 1e-10,
                                             pixel_maxit = 500L),
  "defectos M2-11: tol 1e-6, pixel_tol 1e-5" = ef_h_control(),
  "tol 1e-10, pixel_tol 1e-10" = ctrl_tight
)
run_cal <- function(control, pixels = pix) {
  suppressWarnings(ef_calibrate_h(anc, control = control,
                                  lapse_rate = lapse_w,
                                  datum_elevation = WS$location$elev,
                                  pixels = pixels))
}
convergence <- do.call(rbind, lapply(names(conv_runs), function(nm) {
  ct <- conv_runs[[nm]]
  r <- run_cal(ct)
  ra <- run_cal(ct, pix_anchors)
  secs <- stats::median(replicate(5, system.time(run_cal(ct))[["elapsed"]]))
  d_fp <- r$pixels$h - cal_tight$pixels$h
  d_w <- tv(r$pixels$h) - W$h
  data.frame(
    run = nm, slope = r$b, intercept = r$a, iterations_a = r$iterations,
    iterations_b_median = stats::median(r$pixels$iterations, na.rm = TRUE),
    iterations_b_max = max(r$pixels$iterations, na.rm = TRUE),
    not_converged = sum(!r$pixels$converged, na.rm = TRUE),
    mean_h = mean(r$pixels$h, na.rm = TRUE),
    mean_dh_fixed_point = mean(d_fp, na.rm = TRUE),
    max_abs_dh_fixed_point = max(abs(d_fp), na.rm = TRUE),
    max_abs_dh_anchors = max(abs(ra$pixels$h - h_target_ab)),
    mean_dh_water = mean(d_w, na.rm = TRUE),
    max_abs_dh_water = max(abs(d_w), na.rm = TRUE),
    seconds = secs
  )
}))
cal_def <- run_cal(ef_h_control())
add("H", "H con los defectos de ef_h_control() (M2-11)", W$h,
    tv(cal_def$pixels$h), "W m-2")
add("H (punto fijo)", "H, water emulado a 1e-10 vs EarthFlux con defectos",
    emu_w_tight$h, tv(cal_def$pixels$h), "W m-2")
et24_def <- ef_et_daily(
  ef_etrf(ef_et_inst(W$rn - W$g - tv(cal_def$pixels$h), lambda_ts),
          ETr_inst, "alfalfa"),
  ETr_24, "alfalfa", "etrf")$eta_24
add("ET_24", "ET_24 (H de EarthFlux con los defectos M2-11)", W$et24,
    et24_def, "mm d-1")

# 4. Weather and reference ET: the same records through EarthFlux -----------

ra <- ef_ra_period(lat = WS$location$lat * deg, lon = WS$location$long * deg,
                   doy = doy, utc_mid = utc_hour, period_hours = 1,
                   standard = "asce")
rso <- ef_rso(ra, elevation = WS$location$elev)
rs_mj <- wsd$radiation * 3600 / 1e6
ea_ws <- ef_ea_rh(wsd$temp, wsd$RH)
rnr <- ef_ref_net_radiation(rs_mj, rso, ea_ws, air_temperature = wsd$temp,
                            timestep = "hourly", standard = "asce")
gr <- ef_ref_soil_heat_flux(rnr$rn, reference = "alfalfa",
                            timestep = "hourly", standard = "asce",
                            daytime = rnr$rn > 0)
etr_ef <- ef_ref_et(rnr$rn, gr, wsd$temp,
                    ef_wind_2m(wsd$wind, wsd$height),
                    ef_es(wsd$temp) - ea_ws, ef_es_slope(wsd$temp),
                    ef_psychrometric(ef_air_pressure(WS$location$elev)),
                    reference = "alfalfa", timestep = "hourly",
                    standard = "asce", daytime = rnr$rn > 0)
etr_ef <- if (is.list(etr_ef)) etr_ef$et_ref else etr_ef
add_scalar("ETr a la pasada [mm/h]", ETr_inst, etr_ef,
           "hora centrada en la pasada, datos at.sat")

# Daily ETr: the 23 hourly periods of water, with water's cloudiness term
hourly <- WS$hourly
day <- format(sat_time, "%Y-%m-%d", tz = "America/Santiago")
start <- as.POSIXct(paste(day, "00:00:00"), tz = "America/Santiago")
rows <- hourly$datetime > start - 86400 & hourly$datetime <= start + 86400
d <- hourly[rows, ]
d$lat <- WS$location$lat; d$long <- WS$location$long
d$elev <- WS$location$elev; d$height <- WS$location$height
lt <- as.POSIXlt(d$datetime)
hrs <- lt$hour + lt$min / 60
first <- wns$asceHourly(d, hours = hrs, DOY = lt$yday + 1, long.z = -45,
                        ET = "ETr")
fcd <- first$fcd
sunny <- first$beta > 0.3
tgt <- d$datetime > start
cur <- if (any(sunny & tgt)) utils::tail(fcd[sunny & tgt], 1) else fcd[1]
for (i in seq_along(fcd)) if (sunny[i]) cur <- fcd[i] else fcd[i] <- cur
utc_mid <- as.POSIXlt(d$datetime - 1800, tz = "UTC")
ra_d <- ef_ra_period(lat = WS$location$lat * deg,
                     lon = WS$location$long * deg, doy = utc_mid$yday + 1,
                     utc_mid = utc_mid$hour + utc_mid$min / 60,
                     period_hours = 1, standard = "asce")
ea_d <- ef_ea_rh(d$temp, d$RH)
rn_d <- ef_ref_net_radiation(d$radiation * 3600 / 1e6,
                             ef_rso(ra_d, WS$location$elev), ea_d,
                             air_temperature = d$temp, timestep = "hourly",
                             standard = "asce", cloudiness = fcd)$rn
day_d <- rn_d > 0
g_d <- ef_ref_soil_heat_flux(rn_d, "alfalfa", "hourly", "asce",
                             daytime = day_d)
etr_d <- ef_ref_et(rn_d, g_d, d$temp, ef_wind_2m(d$wind, d$height),
                   ef_es(d$temp) - ea_d, ef_es_slope(d$temp),
                   ef_psychrometric(ef_air_pressure(WS$location$elev)),
                   "alfalfa", "hourly", "asce", daytime = day_d)
etr_d <- if (is.list(etr_d)) etr_d$et_ref else etr_d
add_scalar("ETr diaria [mm/d] (23 periodos, f_cd de water)", ETr_24,
           sum(etr_d[tgt]))

# 5. Second comparison: anchors selected by EarthFlux (preset criteria) ------

pre <- ef_preset("idaho2002_elev")
st_xy <- sf::st_coordinates(sf::st_transform(
  sf::st_as_sf(WS$location, coords = c("long", "lat"), crs = 4326),
  terra::crs(Ts)))
xy_all <- terra::xyFromCell(Ts, seq_len(terra::ncell(Ts)))
near <- sqrt((xy_all[, 1] - st_xy[1])^2 + (xy_all[, 2] - st_xy[2])^2) <= 30000
ok_all <- is.finite(W$ts) & is.finite(W$albedo) & is.finite(W$ndvi_toa) &
  is.finite(W$lai) & is.finite(W$dem) & is.finite(W$zom) &
  is.finite(W$rn) & is.finite(W$g)
ext <- terra::ext(Ts)
sel_ef <- ef_select_anchors(
  m(W$ts), m(W$ndvi_toa), m(W$albedo), lai = m(W$lai), qa = m(ok_all),
  elevation = m(W$dem), search_area = list(m(near), m(rep(TRUE, nr * nc))),
  criteria = pre$anchors$criteria, relax = pre$anchors$relax,
  aggregate = pre$anchors$aggregate, cell_size = terra::res(Ts)[1],
  origin = c(terra::xmin(ext), terra::ymax(ext)),
  station = as.numeric(st_xy), crs = "EPSG:32719"
)
sel_ef <- ef_anchor_conditions(
  sel_ef, rn = m(W$rn), g = m(W$g), etr_inst = ETr_inst,
  lambda = m(lambda_ts), etrf_cold = 1.05, etrf_hot = 0,
  reference = "alfalfa", source = "preset idaho2002_elev conditions",
  status = "CANDIDATA", zom = m(W$zom), u_blend = u200_used,
  pressure = m(W$pressure)
)
cal2 <- suppressWarnings(ef_calibrate_h(
  sel_ef, control = ctrl, lapse_rate = lapse_w,
  datum_elevation = WS$location$elev, pixels = pix
))
h2 <- tv(cal2$pixels$h)
et24_2 <- ef_et_daily(ef_etrf(ef_et_inst(W$rn - W$g - h2, lambda_ts),
                              ETr_inst, "alfalfa"),
                      ETr_24, "alfalfa", "etrf")$eta_24
add("anclas EarthFlux", "H (anclas del preset)", W$h, h2, "W m-2")
add("anclas EarthFlux", "ET_24 (anclas del preset)", W$et24, et24_2,
    "mm d-1")
add("anclas EarthFlux", "ET_24 (anclas del preset) vs anclas de water en EarthFlux",
    et24_ch, et24_2, "mm d-1")
sel_info <- list(
  found_in = sel_ef$search, relaxation = sel_ef$relaxation,
  thresholds = sel_ef$thresholds,
  n_candidates_funnel = sel_ef$funnel
)
summ_anchor <- function(cells_hot, cells_cold) {
  f <- function(cells) c(n = length(cells), ts = mean(W$ts[cells]),
                         ndvi = mean(W$ndvi_toa[cells]),
                         albedo = mean(W$albedo[cells]),
                         lai = mean(W$lai[cells]), dem = mean(W$dem[cells]),
                         rn = mean(W$rn[cells]), g = mean(W$g[cells]),
                         zom = mean(W$zom[cells]))
  rbind(hot = f(cells_hot), cold = f(cells_cold))
}
anchor_tab <- rbind(
  data.frame(source = "water best n = 5", type = c("hot", "cold"),
             summ_anchor(hot_cells, cold_cells)),
  data.frame(source = "EarthFlux preset idaho2002_elev",
             type = c("hot", "cold"),
             summ_anchor(sel_ef$pixels$cell[sel_ef$pixels$type == "hot"],
                         sel_ef$pixels$cell[sel_ef$pixels$type == "cold"]))
)
add_scalar("pendiente de dT, anclas del preset", H$a, cal2$b)
add_scalar("intercepto de dT, anclas del preset", H$b, cal2$a)

# 6. EarthFlux options closer to the sources (sensitivity of ET_24) ----------
#
# (i) RL_in with the cold anchor temperature (SEBAL Idaho manual, Eq. 23,
# with the lapse correction of Eq. 12-8) instead of the Ts of each pixel;
# (ii) z_om = max(0.018 LAI, 0.005) without the terrain factor of water;
# (iii) both. The anchors, ETr, lambda and wind are those of water; the
# calibration absorbs most of the change of Rn.
t_cold <- cp_pts$lst[cp_pts$type == "cold"]
z_cold <- cp_pts$elevation[cp_pts$type == "cold"]
rl_in_cold <- ef_rl_in(temperature = t_cold + 0.0065 * (z_cold - W$dem),
                       atm_emissivity = atm)
rn_cold <- ef_net_radiation(rs_in = W$rs_in, albedo = W$albedo,
                            rl_in = rl_in_cold, rl_out = W$rl_out,
                            emissivity = W$eps_0)
add("Rn (sensibilidad)", "Rn con RL_in de T_cold (Ec. 23 y 12-8)", W$rn,
    rn_cold, "W m-2")
g_cold <- ef_g_tasumi(rn = rn_cold, lst = W$ts, lai = W$lai)
run_et24 <- function(rn, g, zom) {
  a <- ef_anchor_conditions(
    ef_anchors(cold = cold_cells, hot = hot_cells, lst = m(W$ts),
               ndvi = m(W$ndvi_toa), albedo = m(W$albedo), lai = m(W$lai),
               elevation = m(W$dem), aggregate = "mean"),
    rn = m(rn), g = m(g), etr_inst = ETr_inst, lambda = m(lambda_ts),
    etrf_cold = 1.05, etrf_hot = 0, reference = "alfalfa",
    source = "sensitivity", status = "CANDIDATA", zom = m(zom),
    u_blend = u200_used, pressure = m(W$pressure)
  )
  px <- pix
  px$zom <- m(zom)
  px$rn <- m(rn)
  px$g <- m(g)
  cl <- suppressWarnings(ef_calibrate_h(a, control = ctrl,
                                        lapse_rate = lapse_w,
                                        datum_elevation = WS$location$elev,
                                        pixels = px))
  ef_et_daily(ef_etrf(ef_et_inst(rn - g - tv(cl$pixels$h), lambda_ts),
                      ETr_inst, "alfalfa"),
              ETr_24, "alfalfa", "etrf")$eta_24
}
add("ET_24 (sensibilidad)", "(i) RL_in de T_cold", et24_ch,
    run_et24(rn_cold, g_cold, W$zom), "mm d-1")
add("ET_24 (sensibilidad)", "(ii) z_om sin factor de terreno", et24_ch,
    run_et24(W$rn, W$g, zom_floor), "mm d-1")
add("ET_24 (sensibilidad)", "(iii) (i) + (ii)", et24_ch,
    run_et24(rn_cold, g_cold, zom_floor), "mm d-1")

# 7. METRIC_simple (flat terrain, percentile anchors) ------------------------

simple <- NULL
if (cfg$run_simple) {
  EB <- suppressWarnings(METRIC.EB(image.DN = image.DN, plain = TRUE,
                                   WeatherStation = WS, MTL = MTLfile,
                                   sat = "L7",
                                   thermalband = image.DN$Thermal1,
                                   plots = FALSE))
  ETs <- suppressWarnings(suppressMessages(ET24h(EB, plots = FALSE)))
  an <- EB$anchors
  simple <- list(
    a = EB$calibration$a, b = EB$calibration$b,
    iterations = EB$calibration$iterations, u200 = EB$calibration$u200,
    n_hot = sum(an$type == "hot"), n_cold = sum(an$type == "cold"),
    et24_mean = mean(v(ETs$ET24), na.rm = TRUE),
    etrf_gt_1.1 = mean(v(ETs$ETrF) > 1.1, na.rm = TRUE),
    le_negative_set_0 = sum(v(EB$EB$LatentHeat) == 0, na.rm = TRUE)
  )
}

# 8. Output -----------------------------------------------------------------

res <- do.call(rbind, results)
sca <- do.call(rbind, scalars)
anchors_out <- data.frame(anchors_w, row.names = NULL)
utils::write.csv(versions, file.path(cfg$out_dir, "versions.csv"),
                 row.names = FALSE)
utils::write.csv(settings_water, file.path(cfg$out_dir, "settings-water.csv"),
                 row.names = FALSE)
utils::write.csv(res, file.path(cfg$out_dir, "stages.csv"), row.names = FALSE)
utils::write.csv(sca, file.path(cfg$out_dir, "scalars.csv"), row.names = FALSE)
utils::write.csv(water_iter, file.path(cfg$out_dir, "water-iterations.csv"),
                 row.names = FALSE)
utils::write.csv(cal$trace, file.path(cfg$out_dir, "earthflux-iterations.csv"),
                 row.names = FALSE)
utils::write.csv(emu_tab, file.path(cfg$out_dir, "h-decomposition.csv"),
                 row.names = FALSE)
utils::write.csv(anchors_out, file.path(cfg$out_dir, "anchors-water.csv"),
                 row.names = FALSE)
utils::write.csv(anchor_tab, file.path(cfg$out_dir, "anchors-summary.csv"),
                 row.names = FALSE)
utils::write.csv(fixed_point, file.path(cfg$out_dir, "fixed-point.csv"),
                 row.names = FALSE)
utils::write.csv(convergence, file.path(cfg$out_dir, "convergence.csv"),
                 row.names = FALSE)
saveRDS(list(versions = versions, settings = settings_water, stages = res,
             scalars = sca, water_iterations = water_iter,
             earthflux_iterations = cal$trace, h_decomposition = emu_tab,
             anchors_water = anchors_out, anchors_summary = anchor_tab,
             phase_b = phase_b, fixed_point = fixed_point,
             convergence = convergence,
             earthflux_selection = sel_info,
             earthflux_anchor_pixels = sel_ef$pixels,
             calibration_points = cp_pts, simple = simple,
             weather_overpass = wsd, etr_inst = ETr_inst, etr_24 = ETr_24),
        file.path(cfg$out_dir, "water-comparison.rds"))

op <- options(width = 200, digits = 5)
print(sca, row.names = FALSE)
print(res[, c("stage", "quantity", "n", "na_mismatch", "mean_water",
              "mean_diff", "sd_diff", "max_abs_diff", "rel_max", "r")],
      row.names = FALSE)
print(emu_tab, row.names = FALSE)
print(phase_b, row.names = FALSE)
print(fixed_point, row.names = FALSE)
print(convergence, row.names = FALSE)
print(anchor_tab, row.names = FALSE)
if (!is.null(simple)) str(simple)
options(op)
message("Tables written to ", normalizePath(cfg$out_dir))
