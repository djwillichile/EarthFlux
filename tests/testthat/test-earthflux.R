# earthflux(), its presets and the result object (milestone M5, phase 2;
# replaces the placeholder test-pipeline.R of M0).
#
# Offline: modis_fetch(), modis_surface_state(), dem_fetch() and
# openmeteo_fetch() are replaced with testthat::local_mocked_bindings() that
# return the packaged example scene (real MODIS surface state of 2019-02-15)
# and SYNTHETIC elevation, station and ERA5 data (helper-earthflux.R). The
# values are not realistic results: the tests check the orchestration
# (equivalence with the chain run step by step, options, provenance,
# flags, masks, refusals), not the science.

# Mocks of the download and preparation steps. `calls` records the
# arguments each mock received.
ewf_mock <- function(st, ter, era = NULL, env = parent.frame()) {
  calls <- new.env()
  testthat::local_mocked_bindings(
    modis_fetch = function(aoi, date, lst_product, cache_dir, collection,
                           ...) {
      calls$modis_fetch <- list(date = date, lst_product = lst_product,
                                cache_dir = cache_dir,
                                collection = collection, ...)
      new_ef_object(list(files = list(lst = "x", albedo = "x", ndvi = "x",
                                      lai = "x"),
                         lst_product = st$provenance$methods$lst_product,
                         flags = list(),
                         provenance = list(source = "mock",
                                           granules = st$provenance$granules)),
                    "earthflux_modis_fetch")
    },
    modis_surface_state = function(files, aoi, options) {
      calls$modis_surface_state <- options
      st
    },
    dem_fetch = function(aoi, grid, method, water, cache_dir) {
      calls$dem_fetch <- list(method = method, water = water,
                              cache_dir = cache_dir)
      ter
    },
    openmeteo_fetch = function(aoi, date, elevation_adjust, instant_values,
                               apikey = NULL, cache_dir) {
      calls$openmeteo_fetch <- list(elevation_adjust = elevation_adjust,
                                    instant_values = instant_values,
                                    apikey_used = !is.null(apikey))
      era
    },
    .env = env
  )
  calls
}

# Mocks that fail if any download step is reached.
ewf_mock_no_network <- function(env = parent.frame()) {
  stop_net <- function(...) stop("network step reached")
  testthat::local_mocked_bindings(
    modis_fetch = stop_net, modis_surface_state = stop_net,
    dem_fetch = stop_net, openmeteo_fetch = stop_net, .env = env
  )
}

ewf_run <- function(...) {
  expect_warning(res <- earthflux(...),
                 class = "earthflux_unverified_preset_warning")
  res
}

st <- ewf_state()
ter <- ewf_terrain(st$lst)
aoi <- ewf_aoi()
sta1 <- ewf_stations()
val <- function(r) terra::values(r, mat = FALSE)

# The chain of preset `name` with one station, written step by step with the
# public and internal functions of the stages and without the workflow
# helpers (independent of R/api-*.R): C1 means the station values over the
# whole grid, so the regionalization is replaced by the station series
# interpolated (O3) to the overpass time of each cell. `exclude`: cells
# excluded by the terrain rule of the preset (M5-25), given here so that
# the check stays independent of the workflow helpers: no anchor there and
# NA in every returned layer.
ewf_manual <- function(st, ter, aoi, stations, name, exclude = NULL) {
  p <- ef_preset(name)
  grid <- st$lst
  nr <- terra::nrow(grid)
  nc <- terra::ncol(grid)
  mat <- function(v) matrix(v, nr, nc, byrow = TRUE)
  inside <- val(terra::rasterize(terra::project(aoi, terra::crs(grid)),
                                 grid, touches = TRUE, background = 0)) == 1
  cut <- function(v) {
    v[!inside] <- NA
    v
  }
  ex <- surface_exclusion(st)
  albedo <- val(st$albedo)
  albedo[ex$exclude] <- NA
  lst <- cut(val(st$lst))
  albedo <- cut(albedo)
  ndvi <- cut(val(st$ndvi))
  lai <- cut(val(st$lai))
  emis <- cut(val(st$emissivity))
  doy <- cut(val(st$overpass_time$doy))
  hour <- cut(val(st$overpass_time$utc_hour))
  lon <- cut(val(st$lonlat[["lon"]]))
  lat <- cut(val(st$lonlat[["lat"]]))
  z <- cut(val(ter$terrain[["elevation"]]))
  tt <- as.numeric(st$overpass_time$time)
  tt[!inside | is.na(lst)] <- NA

  # weather at the station
  qc <- ef_station_qc(stations, qc_policy = "exclude_critical")
  ctr <- terra::crds(terra::centroids(terra::project(aoi, "EPSG:4326")))
  off <- unname(ctr[1, 1]) / 15
  day <- as.Date(as.POSIXct(stats::median(tt, na.rm = TRUE) + off * 3600,
                            origin = "1970-01-01", tz = "UTC"))
  rng <- as.POSIXct(range(tt, na.rm = TRUE), origin = "1970-01-01",
                    tz = "UTC")
  ref <- ef_station_ref_et(
    qc, reference = "alfalfa", timestep = "hourly", standard = "asce",
    humidity = "dewpoint_temperature", day_definition = "local_standard",
    day_completeness = "all_periods", daytime_rule = "rn_positive",
    night_cloudiness = "low_sun", overpass = rng, inst_method = "O3",
    dates = day, utc_offset = off
  )
  s <- ref$series
  mid <- as.numeric(s$target_time)
  ok_t <- !is.na(tt)
  etr_inst <- wind <- rep(NA_real_, length(tt))
  etr_inst[ok_t] <- ef_ref_et_inst_interp(s$et_ref, mid, tt[ok_t])
  wind[ok_t] <- ef_ref_et_inst_interp(s$wind_speed_2m, mid, tt[ok_t])
  etr_24 <- ifelse(ok_t, ref$etr_24$etr_24, NA_real_)

  # core
  geo <- ef_solar_geometry(mat(doy), mat(hour), mat(lat) * pi / 180,
                           mat(lon) * pi / 180)
  pressure <- ef_air_pressure(mat(z))
  # minimum z_om of the preset (M5-24)
  zom <- pmax(ef_zom(lai = mat(lai), method = "lai")$zom,
              p$roughness$zom_min)
  u_b <- ef_blending_wind(mat(wind), height = 2, zom_station = 0.0144,
                          d_station = 0)
  # strict anchor QA, read from the registry by severity
  bits <- st$qa$flag_bits
  bad <- bits$bit[bits$severity %in% c("warning", "critical") |
                    bits$code == "EF_SURF_LAI_ASSIGNED"]
  words <- terra::values(st$qa$flag_word, mat = TRUE)
  good <- rep(TRUE, length(tt))
  for (l in paste0("flags_", c("lst", "albedo", "ndvi", "lai",
                               "emissivity"))) {
    w <- as.integer(words[, l])
    hit <- Reduce(`|`, lapply(bad, function(b) {
      bitwAnd(w, bitwShiftL(1L, b)) != 0L
    }))
    good <- good & !is.na(w) & !hit
  }
  vf <- terra::values(st$qa$valid_fraction, mat = TRUE)
  good <- good & rowSums(is.na(vf) | vf < 1) == 0
  qa <- mat(good & inside) & !is.na(mat(lst)) & !is.na(mat(albedo)) &
    !is.na(mat(ndvi)) & !is.na(mat(lai)) & !is.na(mat(emis)) &
    !is.na(mat(z)) & !is.na(zom) & !is.na(u_b) & !is.na(mat(etr_inst)) &
    !is.na(geo$cos_zenith) & !is.na(mat(etr_24))
  if (!is.null(exclude)) {
    qa <- qa & !mat(exclude)
  }
  d <- terra::distance(cbind(val(st$lonlat[["lon"]]),
                             val(st$lonlat[["lat"]])),
                       as.matrix(stations$stations[, c("lon", "lat")]),
                       lonlat = TRUE)[, 1]
  e <- terra::ext(grid)
  anchors <- ef_select_anchors(
    mat(lst), mat(ndvi), mat(albedo), lai = mat(lai), qa = qa,
    elevation = mat(z), utc_hour = mat(hour),
    search_area = list(mat(d <= 30000), mat(inside)),
    criteria = p$anchors$criteria, relax = p$anchors$relax,
    aggregate = "mean", cell_size = terra::res(grid)[1],
    origin = c(terra::xmin(e), terra::ymax(e)),
    crs = terra::crs(grid, proj = TRUE)
  )
  cp <- anchors$calibration_points
  t_cold <- cp$lst[cp$type == "cold"]
  z_cold <- cp$elevation[cp$type == "cold"]
  elev <- name == "idaho2002_elev"
  tau <- if (elev) {
    ef_tau_sw_elevation(mat(z))
  } else {
    ef_tau_sw_elevation(stations$stations$elevation)
  }
  rs <- ef_rs_in_modelled(geo$cos_zenith, geo$cos_incidence,
                          geo$inv_distance, tau_beam = tau, tau_diffuse = 0,
                          slope = 0)$total
  t_rl <- if (elev) t_cold + 0.0065 * (z_cold - mat(z)) else t_cold
  rl_in <- ef_rl_in(t_rl, ef_atm_emissivity(tau))
  rl_out <- ef_rl_out(mat(lst), mat(emis))
  rn <- ef_net_radiation(rs, mat(albedo), rl_in, rl_out, mat(emis))
  g <- ef_g_bastiaanssen(rn, mat(lst), mat(albedo), mat(ndvi))
  lambda <- ef_lambda(method = "constant")
  anchors <- ef_anchor_conditions(
    anchors, rn = rn, g = g, etr_inst = mat(etr_inst), lambda = lambda,
    etrf_cold = 1.05, etrf_hot = 0, reference = "alfalfa",
    source = "test", status = "VERIFICADA", zom = zom, u_blend = u_b,
    pressure = pressure
  )
  # convergence settings of the preset, version 3 (M2-11)
  cal <- ef_calibrate_h(
    anchors,
    control = list(tol = 1e-6, maxit = 100L, pixel_tol = 1e-5,
                   pixel_maxit = 100L),
    lapse_rate = if (elev) 0.0065 else 0,
    datum_elevation = stations$stations$elevation,
    pixels = list(lst = mat(lst), elevation = mat(z), zom = zom,
                  u_blend = u_b, pressure = pressure, rn = rn, g = g)
  )
  le <- ef_latent_heat(rn, g, cal$pixels$h)
  et_inst <- ef_et_inst(le, lambda)
  etrf <- ef_etrf(et_inst, mat(etr_inst), reference = "alfalfa")
  eta <- ef_et_daily_etrf(etrf, mat(etr_24), reference = "alfalfa")
  back <- function(m) {
    v <- if (is.null(dim(m))) rep(m, length(tt)) else as.vector(t(m))
    v[!inside] <- NA
    if (!is.null(exclude)) v[exclude] <- NA
    v
  }
  list(eta_24 = back(eta), etrf = back(etrf), h = back(cal$pixels$h),
       rn = back(rn), g = back(g), le = back(le), rl_in = back(rl_in),
       tau_sw = back(tau),
       etr_inst = back(mat(etr_inst)), etr_24 = back(mat(etr_24)),
       a = cal$a, b = cal$b, cold = t_cold)
}

# Presets ------------------------------------------------------------------------------

test_that("ef_presets() and ef_preset() describe the registered presets", {
  tab <- ef_presets()
  expect_s3_class(tab, "data.frame")
  expect_identical(tab$name, c("idaho2002_elev", "idaho2002_flat"))
  expect_identical(tab$version, c("5", "5"))
  expect_identical(tab$status, c("CANDIDATA", "CANDIDATA"))
  e <- ef_preset("idaho2002_elev")
  f <- ef_preset("idaho2002_flat")
  expect_s3_class(e, "earthflux_preset")
  expect_s3_class(e$anchors$criteria, "earthflux_anchor_criteria")
  expect_identical(e$anchors$criteria$status, "CANDIDATA")
  # anchor criteria of version 2 (M5-23): NDVI percentiles and albedo bands
  rule <- function(cr, type, i) unclass(cr[[type]][[i]])[c("variable",
                                                           "operator",
                                                           "value", "scale")]
  cr <- e$anchors$criteria
  expect_identical(rule(cr, "cold", 1),
                   list(variable = "ndvi", operator = ">=", value = 0.9,
                        scale = "percentile"))
  expect_identical(rule(cr, "cold", 2)$value, c(0.14, 0.26))
  expect_identical(rule(cr, "hot", 1),
                   list(variable = "ndvi", operator = "<=", value = 0.1,
                        scale = "percentile"))
  expect_identical(rule(cr, "hot", 3)$value, c(0.18, 0.35))
  expect_false("lai" %in% c(vapply(cr$cold, `[[`, "", "variable"),
                            vapply(cr$hot, `[[`, "", "variable")))
  expect_length(e$anchors$relax, 1L)
  expect_identical(c(rule(e$anchors$relax[[1]], "cold", 1)$value,
                     rule(e$anchors$relax[[1]], "hot", 1)$value), c(0.8, 0.2))
  expect_identical(e$anchors$qa_exclude_codes,
                   c("EF_SURF_LAI_ASSIGNED", "EF_SURF_VIEW_ANGLE_HIGH"))
  expect_identical(names(e$changes), as.character(1:5))
  # version 5 (M5-26, M5-27): Terra/Aqua chosen by the view angle, cells
  # observed at more than 40 degrees flagged; both CANDIDATA
  expect_identical(e$modis$lst_product, "auto_view_angle")
  expect_identical(e$modis$lst_candidates, c("MOD11A1", "MYD11A1"))
  expect_identical(e$modis$min_lst_coverage, 0.8)
  expect_identical(e$modis$surface_options$view_angle_max, 40)
  expect_identical(f$modis, e$modis)
  expect_match(e$modis$lst_choice_status, "CANDIDATA")
  expect_match(e$modis$view_angle_status, "CANDIDATA")
  expect_true(all(c("M5-26", "M5-27") %in% e$decisions))
  expect_true("view_angle" %in% names(e$unverified))
  expect_match(e$changes[["5"]], "Aqua")
  # version 3 (M2-11): the convergence settings of H are written out in the
  # preset, one tolerance per phase
  expect_identical(
    e$sensible_heat$control,
    ef_h_control(stable_psi_m_height = 2, blending_height = 200, z1 = 0.1,
                 z2 = 2, tol = 1e-6, maxit = 100L, damping = 0,
                 pixel_tol = 1e-5, pixel_maxit = 100L)
  )
  expect_identical(f$sensible_heat$control, e$sensible_heat$control)
  expect_true("M2-11" %in% e$decisions)
  # version 4 (M5-25): the terrain rule, CANDIDATA, in both presets, with
  # the limit of each preset (error of Ts_datum of 1.5 K: 3.3 K per km with
  # the lapse correction, 6.5 K per km without it)
  expect_identical(e$terrain_rule$method, "anchor_elevation_range")
  expect_match(e$terrain_rule$reference, "cold and hot calibration points")
  expect_identical(e$terrain_rule$max_elevation_difference, 500)
  expect_identical(f$terrain_rule$max_elevation_difference, 250)
  expect_identical(e$terrain_rule$flag, "EF_H_TERRAIN_RULE_APPLIED")
  expect_match(e$terrain_rule$status, "CANDIDATA")
  same <- setdiff(names(e$terrain_rule), "max_elevation_difference")
  expect_identical(f$terrain_rule[same], e$terrain_rule[same])
  expect_match(e$unverified[["terrain_rule"]], "500 m")
  expect_match(f$unverified[["terrain_rule"]], "250 m")
  expect_true("M5-25" %in% e$decisions)
  expect_true("terrain_rule" %in% names(e$unverified))
  expect_identical(e$modis$surface_options$lai_nonveg, 0)
  expect_identical(e$modis$surface_options$albedo_method, "white_sky")
  expect_identical(c(e$sensible_heat$lapse_rate, f$sensible_heat$lapse_rate),
                   c(0.0065, 0))
  expect_identical(c(e$radiation$rl_in_lapse_rate,
                     f$radiation$rl_in_lapse_rate), c(0.0065, 0))
  expect_identical(e$terrain$slope, 0)
  expect_identical(e$weather$era5$elevation_adjust, FALSE)
  expect_identical(e$wind$zom_station, 0.0144)
  expect_true(length(e$unverified) > 0L)
  # the options of the MODIS surface state are accepted by its constructor
  # once the LST product of the scene is known (either candidate)
  for (lst in e$modis$lst_candidates) {
    o <- workflow_surface_options(e, lst)
    expect_s3_class(o, "earthflux_modis_surface_options")
    expect_identical(o$lst_product, lst)
  }
  expect_error(workflow_surface_options(e, "MOD21A1D"),
               class = "earthflux_unknown_method")
  expect_output(print(e), "idaho2002_elev")
  expect_error(ef_preset("metric_default"), class = "earthflux_unknown_method")
  expect_error(ef_preset(), class = "earthflux_missing_input")
})

test_that("the preset is required and checked before any download", {
  ewf_mock_no_network()
  expect_error(earthflux(aoi, ewf_date(), weather = sta1),
               class = "earthflux_missing_input")
  expect_error(earthflux(aoi, ewf_date(), weather = sta1,
                         preset = "idaho2002"),
               class = "earthflux_unknown_method")
  expect_error(earthflux(aoi, "2019-02-15", weather = sta1,
                         preset = "idaho2002_elev"),
               class = "earthflux_input_error")
  expect_error(earthflux(aoi, ewf_date(), weather = "merra2",
                         preset = "idaho2002_elev"),
               class = "earthflux_unknown_method")
})

test_that("an area over several MODIS tiles is refused before any download", {
  ewf_mock_no_network()
  two <- terra::vect(terra::ext(-75, -73, -36.4, -35.6), crs = "EPSG:4326")
  expect_identical(nrow(modis_tiles_for_aoi(two)), 2L)
  expect_error(earthflux(two, ewf_date(), weather = "era5",
                         preset = "idaho2002_elev"),
               class = "earthflux_method_not_implemented")
})

# One station (C1), downloads mocked ------------------------------------------------

calls_e <- NULL
res_e <- local({
  calls_e <<- ewf_mock(st, ter)
  ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_elev",
          cache_dir = tempdir())
})

test_that("earthflux() runs the download steps with the options of the preset", {
  expect_s3_class(res_e, "earthflux_result")
  expect_identical(calls_e$modis_fetch$lst_product, "auto_view_angle")
  expect_identical(calls_e$modis_fetch$min_lst_coverage, 0.8)
  expect_identical(calls_e$modis_fetch$date, ewf_date())
  expect_identical(calls_e$modis_fetch$cache_dir, tempdir())
  o <- calls_e$modis_surface_state
  expect_s3_class(o, "earthflux_modis_surface_options")
  expect_identical(o$albedo_method, "white_sky")
  expect_identical(o$lst_product, "MOD11A1") # the product of the scene
  expect_identical(o$view_angle_max, 40)
  expect_identical(o$min_valid_fraction, 1)
  expect_identical(o$qa_policy, "flag")
  expect_equal(unname(o$lai_nonveg), rep(0, 6))
  expect_identical(calls_e$dem_fetch[c("method", "water")],
                   list(method = "flat", water = "mask"))
  expect_null(calls_e$openmeteo_fetch)
})

test_that("the result equals the chain run step by step (elev preset, C1)", {
  man <- ewf_manual(st, ter, aoi, sta1, "idaho2002_elev")
  for (nm in c("eta_24", "etrf", "h", "rn", "g", "le", "rl_in", "tau_sw",
               "etr_inst", "etr_24")) {
    expect_equal(val(res_e$layers[[nm]]), man[[nm]], tolerance = 1e-8,
                 info = nm)
  }
  expect_equal(c(res_e$h_calibration$a, res_e$h_calibration$b),
               c(man$a, man$b), tolerance = 1e-10)
  expect_gt(sum(!is.na(man$eta_24)), 1000)
})

test_that("LE is the residual of the energy balance and ETa = ETrF x ETr_24", {
  v <- terra::values(res_e$layers, mat = TRUE)
  ok <- !is.na(v[, "le"])
  expect_gt(sum(ok), 1000)
  expect_equal(v[ok, "le"] + v[ok, "g"] + v[ok, "h"], v[ok, "rn"],
               tolerance = 1e-12)
  ok <- !is.na(v[, "eta_24"])
  expect_equal(v[ok, "eta_24"], v[ok, "etrf"] * v[ok, "etr_24"],
               tolerance = 1e-12)
  # ETrF at the anchors reproduces the boundary conditions (1.05 and 0) up
  # to the averaging of the anchor cells into one calibration point
  px <- res_e$anchors$pixels
  etrf <- v[px$cell, "etrf"]
  expect_lt(abs(mean(etrf[px$type == "cold"]) - 1.05), 0.01)
  expect_lt(abs(mean(etrf[px$type == "hot"]) - 0), 0.01)
})

test_that("the anchors satisfy the criteria of the preset (version 2)", {
  px <- res_e$anchors$pixels
  th <- res_e$anchors$thresholds
  used <- res_e$anchors$search$used
  for (t in c("cold", "hot")) {
    u <- used[used$type == t, ]
    tt <- th[th$type == t & th$stage == u$stage & th$step == u$step &
               th$target == "rule", ]
    p <- px[px$type == t, ]
    expect_gt(nrow(p), 0L)
    ndvi_thr <- tt$value_lower[tt$variable == "ndvi" & tt$scale ==
                                 "percentile"]
    if (t == "cold") {
      expect_true(all(p$ndvi >= ndvi_thr))
      expect_true(all(p$albedo >= 0.14 & p$albedo <= 0.26))
    } else {
      ndvi_thr <- tt$value_upper[tt$variable == "ndvi" & tt$scale ==
                                   "percentile"]
      expect_true(all(p$ndvi <= ndvi_thr & p$ndvi > 0))
      expect_true(all(p$albedo >= 0.18 & p$albedo <= 0.35))
    }
  }
  # the cold anchor is colder than the hot anchor and LAI is not a rule
  cp <- res_e$anchors$calibration_points
  expect_lt(cp$lst[cp$type == "cold"], cp$lst[cp$type == "hot"])
})

test_that("the flat preset uses one transmissivity and one longwave temperature", {
  calls <- ewf_mock(st, ter)
  res <- ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_flat",
                 cache_dir = tempdir())
  # the synthetic plane rises from 150 m (the station) to 582 m, within
  # 250 m of the elevation range of the calibration (the anchors and the
  # station): the terrain rule of the flat preset excludes nothing, also
  # the cells more than 250 m above the station (M5-25)
  grid <- st$lst
  in_aoi <- val(terra::rasterize(terra::project(aoi, terra::crs(grid)), grid,
                                 touches = TRUE, background = 0)) == 1
  z <- val(ter$terrain[["elevation"]])
  expect_identical(res$provenance$counts[["terrain_rule_excluded"]], 0L)
  far <- in_aoi & !is.na(z) & z - 150 > 250
  expect_gt(sum(far & !is.na(val(res$layers$eta_24))), 100L)
  man <- ewf_manual(st, ter, aoi, sta1, "idaho2002_flat")
  for (nm in c("eta_24", "etrf", "h", "rn", "rl_in", "tau_sw")) {
    expect_equal(val(res$layers[[nm]]), man[[nm]], tolerance = 1e-8,
                 info = nm)
  }
  inside <- !is.na(val(res$layers$rl_in))
  expect_length(unique(val(res$layers$tau_sw)[inside]), 1L)
  expect_length(unique(val(res$layers$rl_in)[inside & !is.na(val(st$lst))]),
                1L)
  expect_identical(res$provenance$scene$tau_elevation,
                   sta1$stations$elevation)
  # the elev preset varies both with the (tilted) elevation
  inside_e <- !is.na(val(res_e$layers$tau_sw))
  expect_gt(length(unique(val(res_e$layers$tau_sw)[inside_e])), 1L)
  # lapse rate of the datum temperature
  expect_identical(res$h_calibration$datum$lapse_rate, 0)
  expect_identical(res_e$h_calibration$datum$lapse_rate, 0.0065)
})

test_that("the terrain rule has its own limit in each preset", {
  # a block at 850 m east of the anchors: more than 250 m and less than
  # 500 m above the elevation range of the calibration (the anchors of the
  # plane and the station at 150 m): excluded by the flat preset (limit
  # 250 m), kept by the elev preset (limit 500 m)
  cp <- res_e$anchors$calibration_points
  top <- max(cp$elevation, 150)
  expect_true(850 > top + 250 && 850 < top + 500)
  ter_b <- ewf_terrain_mountain(st$lst, height = 850)
  calls <- ewf_mock(st, ter_b)
  res <- ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_flat",
                 cache_dir = tempdir())
  res_b <- ewf_run(aoi, ewf_date(), weather = sta1,
                   preset = "idaho2002_elev", cache_dir = tempdir())
  grid <- st$lst
  in_aoi <- val(terra::rasterize(terra::project(aoi, terra::crs(grid)), grid,
                                 touches = TRUE, background = 0)) == 1
  z <- val(ter_b$terrain[["elevation"]])
  block <- in_aoi & !is.na(z) & z == 850
  expect_gt(sum(block & !is.na(val(res_b$layers$eta_24))), 100L)
  expect_true(all(is.na(terra::values(res$layers, mat = TRUE)[block, ])))
  expect_identical(res$provenance$counts[["terrain_rule_excluded"]],
                   sum(block))
  expect_identical(res$provenance$counts[["terrain_rule_excluded_above"]],
                   sum(block))
  expect_identical(res_b$provenance$counts[["terrain_rule_excluded"]], 0L)
  b <- ef_flag_registry()$bit[
    ef_flag_registry()$code == "EF_H_TERRAIN_RULE_APPLIED"]
  w <- as.integer(val(res$qa$metric$flags_h))
  expect_true(all(bitwAnd(w[block], bitwShiftL(1L, b)) != 0L))
  we <- as.integer(val(res_b$qa$metric$flags_h))
  expect_false(any(!is.na(we[block]) &
                     bitwAnd(we[block], bitwShiftL(1L, b)) != 0L))
  tr <- res$provenance$scene$terrain_rule
  tr_b <- res_b$provenance$scene$terrain_rule
  expect_identical(tr$max_elevation_difference, 250)
  expect_identical(tr_b$max_elevation_difference, 500)
  # the same references (the preliminary selection does not use the rule)
  expect_identical(tr$reference_elevations, tr_b$reference_elevations)
  expect_equal(tr$range, c(lower = 150 - 250, upper = top + 250))
  expect_equal(tr_b$range, c(lower = 150 - 500, upper = top + 500))
  expect_output(print(res), "more than 250 m outside the calibration range")
  expect_output(print(res_b), "more than 500 m outside the calibration range")
})

test_that("the result has layers, objects, flag words and units", {
  r <- res_e
  expect_true(inherits(r$layers, "SpatRaster"))
  expect_identical(names(r$layers)[1:7],
                   c("eta_24", "etrf", "et_inst", "le", "h", "g", "rn"))
  expect_true(terra::compareGeom(r$layers, st$lst, stopOnError = FALSE))
  expect_identical(names(r$units), names(r$layers))
  expect_s3_class(r$anchors, "earthflux_anchors")
  expect_s3_class(r$h_calibration, "earthflux_h_calibration")
  expect_s3_class(r$surface, "earthflux_surface_state")
  expect_s3_class(r$terrain, "earthflux_terrain")
  expect_s3_class(r$weather$reference_et, "earthflux_station_ref_et")
  expect_s3_class(r$forcing$surfaces$etr_inst, "earthflux_surface")
  expect_identical(r$forcing$method, "station")
  expect_identical(names(r$qa$metric),
                   c("flags_rad", "flags_g", "flags_h", "flags_et"))
  expect_identical(names(r$qa$forcing),
                   c("flags_etr_inst", "flags_wind_speed_2m", "flags_etr_24"))
  expect_invisible(check_flag_list(r$flags))
  codes <- vapply(r$flags, `[[`, "", "code")
  expect_true(all(codes %in% ef_flag_registry()$code))
  expect_true("EF_GWR_SINGLE_STATION" %in% codes)
  expect_false("EF_WS_GRIDDED_FORCING" %in% codes)
  expect_true(all(codes %in% r$provenance$flags_evaluated))
  # cell records refer to terra cells of the AOI and name their layer
  cell <- Filter(function(f) f$scope == "cell", r$flags)
  expect_true(all(vapply(cell, function(f) !is.null(f$target), TRUE)))
  expect_true(all(vapply(cell, `[[`, 0L, "n_total") == terra::ncell(st$lst)))
  # negative ET flagged in the ET word and as records, on the same cells
  neg <- Filter(function(f) f$code == "EF_ET_NEGATIVE", r$flags)
  idx <- if (length(neg)) neg[[1]]$index else integer(0)
  expect_identical(idx, which(val(r$layers$eta_24) < 0))
  w <- as.integer(val(r$qa$metric$flags_et))
  b <- r$qa$flag_bits$et$bit[r$qa$flag_bits$et$code == "EF_ET_NEGATIVE"]
  expect_identical(which(!is.na(w) & bitwAnd(w, bitwShiftL(1L, b)) != 0L),
                   idx)
  expect_output(print(r), "idaho2002_elev")
  sm <- summary(r)
  expect_s3_class(sm, "summary.earthflux_result")
  expect_identical(sm$layers$layer, names(r$layers))
  expect_output(print(sm), "Layers")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_invisible(plot(r))
  expect_error(plot(r, layer = "nope"), class = "earthflux_input_error")
})

test_that("cells outside the AOI polygon are NA in every layer and word", {
  grid <- st$lst
  inside <- val(terra::rasterize(terra::project(aoi, terra::crs(grid)), grid,
                                 touches = TRUE, background = 0)) == 1
  expect_true(any(!inside) && any(inside))
  # the scene has valid cells outside the AOI box
  expect_true(any(!is.na(val(st$lst))[!inside]))
  v <- terra::values(res_e$layers, mat = TRUE)
  expect_true(all(is.na(v[!inside, ])))
  expect_true(all(is.na(terra::values(res_e$qa$metric, mat = TRUE)[!inside, ])))
  expect_true(all(is.na(terra::values(res_e$qa$surface, mat = TRUE)[!inside, ])))
  expect_true(any(!is.na(v[inside, "eta_24"])))
  expect_identical(res_e$provenance$counts[["outside_aoi"]], sum(!inside))
  # the anchors lie inside the AOI
  expect_true(all(inside[res_e$anchors$pixels$cell]))
})

test_that("z_om below the minimum is raised and flagged (EF_H_ZOM_FLOOR_APPLIED)", {
  p <- ef_preset("idaho2002_elev")
  expect_identical(p$roughness$zom_min, 0.005)
  lai <- val(st$lai)
  zom <- val(res_e$layers$zom)
  inside <- !is.na(val(res_e$layers$tau_sw))
  low <- inside & !is.na(lai) & 0.018 * lai < 0.005
  expect_gt(sum(low & lai == 0), 0L)
  expect_identical(zom[low], rep(0.005, sum(low)))
  ok <- inside & !is.na(lai) & !low
  expect_equal(zom[ok], 0.018 * lai[ok], tolerance = 1e-12)
  rec <- Filter(function(f) f$code == "EF_H_ZOM_FLOOR_APPLIED", res_e$flags)
  expect_length(rec, 1L)
  expect_identical(rec[[1]]$index, which(low))
  expect_identical(rec[[1]]$target, "zom")
  expect_identical(rec[[1]]$severity, "info")
  expect_identical(res_e$provenance$counts[["zom_floor_applied"]], sum(low))
  w <- as.integer(val(res_e$qa$metric$flags_h))
  b <- ef_flag_registry()$bit[ef_flag_registry()$code ==
                                "EF_H_ZOM_FLOOR_APPLIED"]
  expect_identical(b, 1L)
  expect_identical(which(!is.na(w) & bitwAnd(w, bitwShiftL(1L, b)) != 0L),
                   which(low))
  # the cells with LAI = 0 now have an ETa where the rest of the chain is
  # defined (they were NA with the retired rule of M5-13)
  expect_true(any(!is.na(val(res_e$layers$eta_24))[low & lai == 0]))
  # no anchor on a cell whose LAI was assigned by `lai_nonveg`
  lw <- terra::values(st$qa$flag_word, mat = TRUE)[, "flags_lai"]
  bl <- st$qa$flag_bits$bit[st$qa$flag_bits$code == "EF_SURF_LAI_ASSIGNED"]
  assigned <- !is.na(lw) & bitwAnd(as.integer(lw), bitwShiftL(1L, bl)) != 0L
  expect_gt(sum(assigned & inside), 0L)
  expect_false(any(assigned[res_e$anchors$pixels$cell]))
  # negative case: no z_om below the minimum -> evaluated, no record
  st2 <- st
  l2 <- st2$lai
  terra::values(l2) <- ifelse(!is.na(lai) & lai < 0.3, 0.3, lai)
  st2$lai <- l2
  calls <- ewf_mock(st2, ter)
  res2 <- ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_elev",
                  cache_dir = tempdir())
  expect_false("EF_H_ZOM_FLOOR_APPLIED" %in%
                 vapply(res2$flags, `[[`, "", "code"))
  expect_true("EF_H_ZOM_FLOOR_APPLIED" %in%
                res2$provenance$flags_evaluated_by_stage$metric)
  expect_identical(res2$provenance$counts[["zom_floor_applied"]], 0L)
})

test_that("workflow_zom_floor() raises z_om to the minimum and keeps NA", {
  z <- matrix(c(0, 0.004, 0.005, 0.02, NA, 0.1), 2, 3)
  f <- workflow_zom_floor(z, 0.005)
  expect_identical(dim(f$zom), dim(z))
  expect_identical(f$zom, matrix(c(0.005, 0.005, 0.005, 0.02, NA, 0.1), 2, 3))
  expect_identical(f$floored,
                   matrix(c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE), 2, 3))
  rec <- f$flags[[1]]
  expect_identical(rec$code, "EF_H_ZOM_FLOOR_APPLIED")
  expect_identical(rec$index, 1:2)
  expect_identical(attr(f$flags, "evaluated"), "EF_H_ZOM_FLOOR_APPLIED")
  none <- workflow_zom_floor(c(0.01, NA), 0.005)
  expect_length(none$flags, 0L)
  expect_identical(none$zom, c(0.01, NA))
  expect_error(workflow_zom_floor(z, 0), class = "earthflux_input_error")
  expect_error(workflow_zom_floor(z, NA_real_),
               class = "earthflux_input_error")
})

test_that("the terrain rule excludes cells beyond the calibration range (EF_H_TERRAIN_RULE_APPLIED)", {
  ter_m <- ewf_terrain_mountain(st$lst)
  calls <- ewf_mock(st, ter_m)
  res <- ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_elev",
                 cache_dir = tempdir())
  grid <- st$lst
  inside <- val(terra::rasterize(terra::project(aoi, terra::crs(grid)), grid,
                                 touches = TRUE, background = 0)) == 1
  z <- val(ter_m$terrain[["elevation"]])
  # references: the anchors of a preliminary selection without the rule
  # (those of the plane: the mountain holds no anchor) and the station at
  # 150 m, the datum of Ts; limit 500 m
  cp0 <- res_e$anchors$calibration_points
  refs <- c(cold = cp0$elevation[cp0$type == "cold"],
            hot = cp0$elevation[cp0$type == "hot"], station = 150)
  excl <- inside & !is.na(z) & (z < min(refs) - 500 | z > max(refs) + 500)
  expect_gt(sum(excl), 100L)
  expect_true(any(!is.na(val(st$lst))[excl]))
  tr <- res$provenance$scene$terrain_rule
  expect_identical(tr$method, "anchor_elevation_range")
  expect_equal(tr$reference_elevations, refs, tolerance = 1e-12)
  expect_match(tr$reference_source, "preliminary anchor selection")
  expect_match(tr$reference_source, "representative station")
  expect_identical(tr$max_elevation_difference, 500)
  expect_equal(tr$range, c(lower = min(refs) - 500, upper = max(refs) + 500),
               tolerance = 1e-12)
  # the final anchors lie inside the kept range
  cp <- res$anchors$calibration_points
  expect_identical(tr$anchor_elevations,
                   c(cold = cp$elevation[cp$type == "cold"],
                     hot = cp$elevation[cp$type == "hot"]))
  expect_true(tr$anchors_in_range)
  expect_true(all(tr$anchor_elevations >= tr$range[["lower"]] &
                    tr$anchor_elevations <= tr$range[["upper"]]))
  expect_identical(res$provenance$counts[["terrain_rule_excluded"]],
                   sum(excl))
  expect_identical(res$provenance$counts[["terrain_rule_excluded_below"]], 0L)
  expect_identical(res$provenance$counts[["terrain_rule_excluded_above"]],
                   sum(excl))
  expect_output(print(res), sprintf("terrain rule: %d cells excluded",
                                    sum(excl)))
  expect_output(print(ef_preset("idaho2002_elev")), "anchor_elevation_range")
  # NA in every layer of the result, computed elsewhere
  v <- terra::values(res$layers, mat = TRUE)
  expect_true(all(is.na(v[excl, ])))
  expect_gt(sum(!is.na(v[inside & !excl, "eta_24"])), 1000L)
  expect_identical(res$provenance$counts[["eta_24_valid"]],
                   sum(!is.na(v[, "eta_24"])))
  # no anchor on an excluded cell
  expect_false(any(excl[res$anchors$pixels$cell]))
  # the record, the bit of the H word and no other word on those cells
  rec <- Filter(function(f) f$code == "EF_H_TERRAIN_RULE_APPLIED", res$flags)
  expect_length(rec, 1L)
  expect_identical(rec[[1]]$index, which(excl))
  expect_identical(rec[[1]]$target, "h")
  expect_identical(rec[[1]]$severity, "info")
  expect_identical(rec[[1]]$n_total, as.integer(terra::ncell(grid)))
  reg <- ef_flag_registry()
  b <- reg$bit[reg$code == "EF_H_TERRAIN_RULE_APPLIED"]
  expect_identical(b, 11L)
  expect_identical(reg$stage[reg$code == "EF_H_TERRAIN_RULE_APPLIED"], "H")
  w <- as.integer(val(res$qa$metric$flags_h))
  expect_identical(which(!is.na(w) & bitwAnd(w, bitwShiftL(1L, b)) != 0L),
                   which(excl))
  expect_true(all(w[excl] == bitwShiftL(1L, b)))
  for (nm in c("flags_rad", "flags_g", "flags_et")) {
    expect_true(all(is.na(val(res$qa$metric[[nm]])[excl])), info = nm)
  }
  # the other cell records never point at an excluded cell
  other <- Filter(function(f) f$scope == "cell" &&
                    f$code != "EF_H_TERRAIN_RULE_APPLIED", res$flags)
  expect_true(all(vapply(other, function(f) !any(excl[f$index]), TRUE)))
  expect_true("EF_H_TERRAIN_RULE_APPLIED" %in%
                res$provenance$flags_evaluated_by_stage$metric)
  # the cells kept equal the chain run step by step without anchors on
  # the excluded cells
  man <- ewf_manual(st, ter_m, aoi, sta1, "idaho2002_elev", exclude = excl)
  for (nm in c("eta_24", "etrf", "h", "rn", "g", "le", "rl_in", "tau_sw",
               "etr_inst", "etr_24")) {
    expect_equal(val(res$layers[[nm]]), man[[nm]], tolerance = 1e-8,
                 info = nm)
  }
  expect_equal(c(res$h_calibration$a, res$h_calibration$b),
               c(man$a, man$b), tolerance = 1e-10)
  # negative case: no cell beyond the range -> evaluated, no record
  expect_false("EF_H_TERRAIN_RULE_APPLIED" %in%
                 vapply(res_e$flags, `[[`, "", "code"))
  expect_true("EF_H_TERRAIN_RULE_APPLIED" %in%
                res_e$provenance$flags_evaluated_by_stage$metric)
  expect_identical(res_e$provenance$counts[["terrain_rule_excluded"]], 0L)
  wh <- as.integer(val(res_e$qa$metric$flags_h))
  expect_false(any(!is.na(wh) & bitwAnd(wh, bitwShiftL(1L, b)) != 0L))
})

test_that("without a station the terrain rule refers to the range of the anchors", {
  sta3 <- ewf_stations(lon = c(-72.9, -71.8, -72.9, -71.8),
                       lat = c(-35.5, -35.5, -36.4, -36.4),
                       elevation = c(120, 160, 220, 260))
  # a valley at 0 m (columns 1 to 12) and a mountain at 1200 m (columns
  # from 90), both away from the anchors
  ter_m <- ewf_terrain_mountain(st$lst, valley_to_col = 12L)
  calls <- ewf_mock(st, ter_m)
  res <- ewf_run(aoi, ewf_date(), weather = sta3, preset = "idaho2002_flat")
  tr <- res$provenance$scene$terrain_rule
  expect_match(tr$reference_source, "preliminary anchor selection")
  expect_no_match(tr$reference_source, "station")
  expect_identical(tr$max_elevation_difference, 250)
  # the preliminary selection is the selection without the rule: the same
  # criteria on the same cells (the elev preset on the plane, where its
  # limit of 500 m excludes nothing), its points on the terrain of the run
  calls0 <- ewf_mock(st, ter)
  res0 <- ewf_run(aoi, ewf_date(), weather = sta3, preset = "idaho2002_elev")
  expect_identical(res0$provenance$counts[["terrain_rule_excluded"]], 0L)
  px0 <- res0$anchors$pixels
  z_m <- val(ter_m$terrain[["elevation"]])
  refs <- c(cold = mean(z_m[px0$cell[px0$type == "cold"]]),
            hot = mean(z_m[px0$cell[px0$type == "hot"]]))
  expect_equal(tr$reference_elevations, refs, tolerance = 1e-12)
  inside <- val(terra::rasterize(terra::project(aoi, terra::crs(st$lst)),
                                 st$lst, touches = TRUE, background = 0)) == 1
  below <- inside & !is.na(z_m) & z_m < min(refs) - 250
  above <- inside & !is.na(z_m) & z_m > max(refs) + 250
  excl <- below | above
  expect_gt(sum(below), 50L)
  expect_gt(sum(above), 100L)
  expect_identical(res$provenance$counts[["terrain_rule_excluded"]],
                   sum(excl))
  expect_identical(res$provenance$counts[["terrain_rule_excluded_below"]],
                   sum(below))
  expect_identical(res$provenance$counts[["terrain_rule_excluded_above"]],
                   sum(above))
  expect_true(all(is.na(terra::values(res$layers, mat = TRUE)[excl, ])))
  expect_false(any(excl[res$anchors$pixels$cell]))
  # the datum of Ts is the cold point of the final selection, inside the
  # kept range
  cp <- res$anchors$calibration_points
  expect_identical(res$provenance$scene$datum_elevation,
                   cp$elevation[cp$type == "cold"])
  expect_true(tr$anchors_in_range)
  expect_true(all(tr$anchor_elevations >= tr$range[["lower"]] &
                    tr$anchor_elevations <= tr$range[["upper"]]))
})

test_that("with one station the station extends the calibration range", {
  # the station at 1000 m (datum of Ts and site of the forcing), the
  # anchors on the plane (about 350 to 460 m), a block at 725 m (more than
  # 250 m from the station and from either anchor) and a valley at 0 m
  sta_hi <- ewf_stations(elevation = 1000)
  ter_s <- ewf_terrain_mountain(st$lst, height = 725, valley_to_col = 12L)
  calls <- ewf_mock(st, ter_s)
  res <- ewf_run(aoi, ewf_date(), weather = sta_hi,
                 preset = "idaho2002_flat", cache_dir = tempdir())
  tr <- res$provenance$scene$terrain_rule
  cp0 <- res_e$anchors$calibration_points
  refs <- c(cold = cp0$elevation[cp0$type == "cold"],
            hot = cp0$elevation[cp0$type == "hot"], station = 1000)
  expect_true(all(abs(725 - refs) > 250))
  expect_gt(725, max(refs[c("cold", "hot")]) + 250)
  expect_equal(tr$reference_elevations, refs, tolerance = 1e-12)
  expect_equal(tr$range, c(lower = min(refs) - 250, upper = 1250),
               tolerance = 1e-12)
  expect_match(tr$reference_source, "representative station")
  z <- val(ter_s$terrain[["elevation"]])
  inside <- val(terra::rasterize(terra::project(aoi, terra::crs(st$lst)),
                                 st$lst, touches = TRUE, background = 0)) == 1
  excl <- inside & !is.na(z) & z < min(refs) - 250
  expect_gt(sum(excl), 50L)
  expect_identical(res$provenance$counts[["terrain_rule_excluded"]],
                   sum(excl))
  expect_identical(res$provenance$counts[["terrain_rule_excluded_below"]],
                   sum(excl))
  # the block between the anchors and the station is computed, and so is
  # the plane, which a rule centred on the station would exclude
  eta <- val(res$layers$eta_24)
  expect_gt(sum(inside & z == 725 & !is.na(eta)), 100L)
  expect_gt(sum(inside & z > 0 & abs(z - 1000) > 250 & !is.na(eta)), 1000L)
  expect_true(all(is.na(terra::values(res$layers, mat = TRUE)[excl, ])))
  expect_identical(res$provenance$scene$datum_elevation, 1000)
  man <- ewf_manual(st, ter_s, aoi, sta_hi, "idaho2002_flat", exclude = excl)
  for (nm in c("eta_24", "etrf", "h", "rn")) {
    expect_equal(val(res$layers[[nm]]), man[[nm]], tolerance = 1e-8,
                 info = nm)
  }
  expect_output(print(res),
                "outside the calibration range [0-9]+ to 1000 m; kept")
})

test_that("workflow_terrain_rule() and workflow_terrain_reference() follow M5-25", {
  # one reference: the interval centred on it
  z <- matrix(c(100, 649.9, 650, 650.1, NA, -400, -350, 1200), 2, 4)
  r <- workflow_terrain_rule(z, reference = 150, max_difference = 500)
  expect_identical(dim(r$excluded), dim(z))
  expect_identical(as.vector(r$excluded),
                   c(FALSE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE))
  expect_identical(as.vector(r$below),
                   c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_identical(r$range, c(lower = -350, upper = 650))
  rec <- r$flags[[1]]
  expect_identical(rec$code, "EF_H_TERRAIN_RULE_APPLIED")
  expect_identical(rec$index, c(4L, 6L, 8L))
  expect_identical(rec$scope, "cell")
  expect_identical(attr(r$flags, "evaluated"), "EF_H_TERRAIN_RULE_APPLIED")
  none <- workflow_terrain_rule(c(140, NA, 600), 150, 500)
  expect_length(none$flags, 0L)
  expect_identical(none$excluded, c(FALSE, FALSE, FALSE))
  expect_identical(attr(none$flags, "evaluated"), "EF_H_TERRAIN_RULE_APPLIED")
  # the range of the anchors: a cell between them is kept however far it
  # is from each (800 m is 700 m from both); only the cells beyond the
  # range by more than the limit are excluded, the bounds are kept
  zz <- c(800, 100, 1500, -150.1, -150, 1750, 1750.1, NA)
  rr <- workflow_terrain_rule(zz, c(cold = 1500, hot = 100), 250)
  expect_identical(rr$range, c(lower = -150, upper = 1750))
  expect_identical(rr$excluded,
                   c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE))
  expect_identical(rr$below,
                   c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_identical(rr$flags[[1]]$index, c(4L, 7L))
  expect_identical(workflow_terrain_rule(zz, c(100, 1500), 250), rr)
  # the station extends the range
  zs <- c(1900, 2050, 2050.1)
  expect_identical(workflow_terrain_rule(zs, c(1500, 100), 250)$excluded,
                   c(TRUE, TRUE, TRUE))
  rs <- workflow_terrain_rule(zs, c(cold = 1500, hot = 100, station = 1800),
                              250)
  expect_identical(rs$excluded, c(FALSE, FALSE, TRUE))
  expect_identical(rs$range, c(lower = -150, upper = 2050))
  # the limits of the presets: 300 m beyond the range is excluded with the
  # limit of idaho2002_flat and kept with the one of idaho2002_elev
  lim <- vapply(c("idaho2002_elev", "idaho2002_flat"), function(n)
    ef_preset(n)$terrain_rule$max_elevation_difference, 0)
  expect_identical(unname(lim), c(500, 250))
  z3 <- c(275, 700, -150, 650, 650.1, -100.1)
  rule_e <- workflow_terrain_rule(z3, c(150, 400), lim[["idaho2002_elev"]])
  rule_f <- workflow_terrain_rule(z3, c(150, 400), lim[["idaho2002_flat"]])
  expect_identical(rule_e$excluded, rep(FALSE, 6L))
  expect_identical(rule_f$excluded, c(FALSE, TRUE, TRUE, FALSE, TRUE, TRUE))
  expect_identical(rule_f$flags[[1]]$index, c(2L, 3L, 5L, 6L))
  expect_identical(rule_e$range, c(lower = -350, upper = 900))
  expect_identical(rule_f$range, c(lower = -100, upper = 650))
  expect_error(workflow_terrain_rule(z, 150, 0), class = "earthflux_input_error")
  expect_error(workflow_terrain_rule(z, NA_real_, 500),
               class = "earthflux_input_error")
  expect_error(workflow_terrain_rule(z, c(150, NA), 500),
               class = "earthflux_input_error")
  expect_error(workflow_terrain_rule(z, numeric(0), 500),
               class = "earthflux_input_error")
  expect_error(workflow_terrain_rule(z, "150", 500),
               class = "earthflux_input_error")
  expect_error(workflow_terrain_rule(z, 150, Inf),
               class = "earthflux_input_error")
  # references: the cold and hot points of a selection on the QA it
  # receives, and the station when there is one
  qa <- matrix(TRUE, 2, 2)
  seen <- NULL
  sel <- function(qa) {
    seen <<- qa
    list(calibration_points = data.frame(type = c("cold", "hot"),
                                         elevation = c(310, 120)))
  }
  ref <- workflow_terrain_reference(NULL, sel, qa)
  expect_identical(ref$elevation, c(cold = 310, hot = 120))
  expect_match(ref$source, "cold and hot calibration points")
  expect_no_match(ref$source, "station")
  expect_identical(seen, qa)
  seen <- NULL
  ref_s <- workflow_terrain_reference(150, sel, qa)
  expect_identical(ref_s$elevation, c(cold = 310, hot = 120, station = 150))
  expect_match(ref_s$source, "representative station")
  expect_identical(seen, qa)
})

test_that("the provenance records every option of the preset", {
  pr <- res_e$provenance
  p <- ef_preset("idaho2002_elev")
  expect_identical(pr$preset$name, "idaho2002_elev")
  expect_identical(pr$preset$version, "5")
  expect_identical(pr$preset$status, "CANDIDATA")
  expect_identical(pr$preset$unverified, p$unverified)
  expect_identical(names(pr$preset$changes), as.character(1:5))
  # effective convergence settings of the calibration of H (M2-11)
  expect_identical(pr$options$sensible_heat$control[c("tol", "maxit",
                                                      "pixel_tol",
                                                      "pixel_maxit")],
                   list(tol = 1e-6, maxit = 100L, pixel_tol = 1e-5,
                        pixel_maxit = 100L))
  expect_identical(res_e$h_calibration$control,
                   pr$options$sensible_heat$control)
  expect_identical(names(pr$options), names(unclass(p)))
  for (nm in setdiff(names(unclass(p)), c("anchors", "sensible_heat"))) {
    expect_identical(pr$options[[nm]], unclass(p)[[nm]], info = nm)
  }
  expect_equal(pr$options$anchors, unclass(p)$anchors)
  sc <- pr$scene
  expect_identical(sc$weather_source, "stations")
  expect_identical(sc$regionalization_method, "station")
  expect_identical(sc$representative_station, "ST01")
  expect_identical(sc$humidity, "dewpoint_temperature")
  expect_equal(sc$utc_offset, sc$aoi$centroid_lonlat[1] / 15)
  expect_identical(sc$reference_et_day, "2019-02-15")
  expect_identical(sc$datum_elevation, 150)
  # terrain rule (M5-25): method, references, limit, kept range, final
  # anchors and counts
  tr <- sc$terrain_rule
  expect_identical(names(tr), c("method", "reference_elevations",
                                "reference_source",
                                "max_elevation_difference", "range",
                                "anchor_elevations", "anchors_in_range"))
  expect_identical(tr$method, p$terrain_rule$method)
  expect_identical(names(tr$reference_elevations),
                   c("cold", "hot", "station"))
  expect_identical(tr$reference_elevations[["station"]], 150)
  expect_true(all(c("terrain_rule_excluded", "terrain_rule_excluded_below",
                    "terrain_rule_excluded_above") %in% names(pr$counts)))
  expect_true(all(c("modis", "terrain", "weather") %in% names(pr$sources)))
  expect_true(all(c("earthflux", "terra") %in% names(pr$versions)))
})

test_that("the expert route takes a prepared surface and terrain", {
  ewf_mock_no_network()
  res <- ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_elev",
                 surface = st, terrain = ter)
  expect_equal(val(res$layers$eta_24), val(res_e$layers$eta_24))
  expect_identical(res$provenance$scene$user_supplied,
                   c(surface = TRUE, terrain = TRUE))
  bad <- st
  bad$provenance$methods$albedo_method <- "black_sky"
  expect_error(earthflux(aoi, ewf_date(), weather = sta1,
                         preset = "idaho2002_elev", surface = bad,
                         terrain = ter),
               class = "earthflux_input_error")
  # The aggregation threshold is checked too, not only the methods.
  loose <- st
  loose$provenance$methods$min_valid_fraction <- 0.5
  expect_error(earthflux(aoi, ewf_date(), weather = sta1,
                         preset = "idaho2002_elev", surface = loose,
                         terrain = ter),
               "min_valid_fraction", class = "earthflux_input_error")
  # A terrain prepared with another method is refused.
  other <- ter
  other$provenance$method <- "nasadem_normal_mean"
  expect_error(suppressWarnings(
    earthflux(aoi, ewf_date(), weather = sta1, preset = "idaho2002_elev",
              surface = st, terrain = other)
  ), "terrain", class = "earthflux_input_error")
  # A surface without a record of its options cannot be checked.
  bare <- st
  bare$provenance$methods <- NULL
  expect_error(earthflux(aoi, ewf_date(), weather = sta1,
                         preset = "idaho2002_elev", surface = bare,
                         terrain = ter),
               class = "earthflux_input_error")
})

# View angle of the LST and Aqua (M5-26, M5-27) ------------------------------------------

# The packaged state with a SYNTHETIC view angle layer (`angle`, degrees, in
# terra cell order) and the bit of EF_SURF_VIEW_ANGLE_HIGH set in
# flags_lst where the LST is valid and the angle is above `threshold`.
ewf_with_view_angle <- function(st, angle, threshold = 40) {
  va <- terra::setValues(terra::rast(st$lst), angle)
  names(va) <- "view_angle"
  st$view_angle <- va
  reg <- ef_flag_registry()
  b <- reg$bit[reg$code == "EF_SURF_VIEW_ANGLE_HIGH"]
  lst <- val(st$lst)
  w <- as.integer(val(st$qa$flag_word[["flags_lst"]]))
  hit <- !is.na(lst) & !is.na(w) & angle > threshold
  w[hit] <- bitwOr(w[hit], bitwShiftL(1L, b))
  terra::values(st$qa$flag_word[["flags_lst"]]) <- w
  st$qa$flag_bits <- reg[reg$stage %in% c("INPUT", "SURF") & !is.na(reg$bit),
                         c("bit", "code", "severity", "description")]
  st
}

# Run earthflux() and collect its warnings (the preset warning and others).
ewf_collect <- function(expr) {
  w <- list()
  value <- withCallingHandlers(
    tryCatch(expr, error = function(e) e),
    warning = function(cnd) {
      w[[length(w) + 1L]] <<- cnd
      invokeRestart("muffleWarning")
    }
  )
  list(value = value,
       classes = vapply(w, function(x) class(x)[1L], ""), warnings = w)
}

test_that("the view angle of the scene is recorded and cells above it hold no anchor", {
  ewf_mock_no_network()
  # angle 10 degrees except 50 degrees on the cells that held the anchors
  # of the reference run: the anchors move, no warning (median 10)
  px <- res_e$anchors$pixels
  angle <- rep(10, terra::ncell(st$lst))
  angle[px$cell] <- 50
  st_va <- ewf_with_view_angle(st, angle)
  out <- ewf_collect(earthflux(aoi, ewf_date(), weather = sta1,
                               preset = "idaho2002_elev", surface = st_va,
                               terrain = ter))
  expect_identical(out$classes, "earthflux_unverified_preset_warning")
  res <- out$value
  expect_s3_class(res, "earthflux_result")
  expect_false(any(res$anchors$pixels$cell %in% px$cell))
  va <- res$provenance$scene$view_angle
  expect_true(va$evaluated)
  expect_identical(va$lst_product, "MOD11A1")
  expect_identical(va$view_angle_max, 40)
  expect_identical(va$median_abs_view_angle, 10)
  n_flag <- sum(px$cell %in% which(!is.na(val(st$lst)) &
                                     workflow_aoi_mask(aoi, st$lst)))
  expect_identical(va$n_flagged, n_flag)
  expect_identical(res$provenance$counts[["view_angle_high"]], n_flag)
  expect_false(va$warned)
  expect_identical(res$provenance$scene$lst_product, "MOD11A1")
  expect_output(print(res), "LST: MOD11A1, median view angle 10 degrees")
  # the reference run has no view angle layer: recorded as not evaluated
  expect_false(res_e$provenance$scene$view_angle$evaluated)
  expect_true(is.na(res_e$provenance$counts[["view_angle_high"]]))
})

test_that("a scene observed far from nadir warns and, without anchors, stops", {
  ewf_mock_no_network()
  n <- terra::ncell(st$lst)
  # median 62 degrees: warning; the anchors of the reference run are at 10
  # degrees, so the run completes
  px <- res_e$anchors$pixels
  angle <- rep(62, n)
  angle[unique(c(px$cell, px$cell + 1L, px$cell - 1L))] <- 10
  out <- ewf_collect(earthflux(aoi, ewf_date(), weather = sta1,
                               preset = "idaho2002_elev",
                               surface = ewf_with_view_angle(st, angle),
                               terrain = ter))
  expect_setequal(out$classes, c("earthflux_unverified_preset_warning",
                                 "earthflux_view_angle_warning"))
  w <- out$warnings[[which(out$classes == "earthflux_view_angle_warning")]]
  expect_identical(w$median_abs_view_angle, 62)
  expect_identical(w$view_angle_max, 40)
  expect_identical(w$lst_product, "MOD11A1")
  expect_match(conditionMessage(w), "62 degrees")
  expect_true(out$value$provenance$scene$view_angle$warned)
  # every cell above the threshold: no anchor candidate is left
  out <- ewf_collect(earthflux(aoi, ewf_date(), weather = sta1,
                               preset = "idaho2002_elev",
                               surface = ewf_with_view_angle(st, rep(62, n)),
                               terrain = ter))
  expect_true("earthflux_view_angle_warning" %in% out$classes)
  # (the percentile domain of the strict QA is empty)
  expect_s3_class(out$value, "earthflux_anchor_error")
  # a threshold at the median: no warning (strictly above)
  st62 <- ewf_with_view_angle(st, angle, threshold = 62)
  st62$provenance$methods$view_angle_max <- 62
  expect_identical(workflow_view_angle(st62, workflow_aoi_mask(aoi, st$lst),
                                       NULL)$warned, FALSE)
})

test_that("an Aqua scene runs through the chain at its own overpass times", {
  # the packaged scene declared as Aqua (MYD11A1) with the overpass moved
  # 4.2 h later (about 13:30 local solar time instead of 9:20): SYNTHETIC
  aq <- st
  aq$provenance$methods$lst_product <- "MYD11A1"
  aq$provenance$granules$product <- "MYD11A1"
  hour <- val(st$overpass_time$utc_hour) + 4.2
  terra::values(aq$overpass_time$utc_hour) <- hour
  aq$overpass_time$time <- st$overpass_time$time + 4.2 * 3600
  calls <- ewf_mock(aq, ter)
  res <- ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_elev")
  expect_identical(calls$modis_fetch$lst_product, "auto_view_angle")
  expect_identical(calls$modis_surface_state$lst_product, "MYD11A1")
  expect_identical(res$provenance$scene$lst_product, "MYD11A1")
  # the hourly mid-points bracket the Aqua overpass times (M5-18)
  mid <- as.POSIXct(res$provenance$scene$hourly_mid_points,
                    format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  t <- aq$overpass_time$time[!is.na(val(res$layers$eta_24))]
  expect_true(min(mid) <= min(t) && max(mid) >= max(t))
  expect_gt(as.numeric(format(min(mid), "%H", tz = "UTC")), 16)
  expect_gt(res$provenance$counts[["eta_24_valid"]], 1000L)
  # the expert route accepts an Aqua state with the preset's other options
  ewf_mock_no_network()
  res2 <- ewf_run(aoi, ewf_date(), weather = sta1,
                  preset = "idaho2002_elev", surface = aq, terrain = ter)
  expect_equal(val(res2$layers$eta_24), val(res$layers$eta_24))
  other <- aq
  other$provenance$methods$lst_product <- "MOD21A1D"
  expect_error(earthflux(aoi, ewf_date(), weather = sta1,
                         preset = "idaho2002_elev", surface = other,
                         terrain = ter),
               class = "earthflux_input_error")
})

# Several stations and ERA5 (C2) -------------------------------------------------------

test_that("several stations are interpolated by inverse distance weighting", {
  # Four stations around the whole AOI, so that no cell is outside their
  # hull. (With the anchor criteria of preset version 1 the cold set was
  # empty over this AOI and a smaller one was used; version 2, M5-23,
  # finds both anchors.)
  sta3 <- ewf_stations(lon = c(-72.9, -71.8, -72.9, -71.8),
                       lat = c(-35.5, -35.5, -36.4, -36.4),
                       elevation = c(120, 160, 220, 260))
  calls <- ewf_mock(st, ter)
  res <- ewf_run(aoi, ewf_date(), weather = sta3, preset = "idaho2002_elev")
  expect_identical(res$forcing$method, "idw")
  expect_identical(res$forcing$surfaces$etr_inst$method_settings$power, 2)
  etr <- val(res$layers$etr_inst)
  expect_gt(length(unique(stats::na.omit(round(etr, 8)))), 1L)
  expect_null(res$provenance$scene$representative_station)
  # datum of Ts: the cold calibration point
  cp <- res$anchors$calibration_points
  expect_identical(res$provenance$scene$datum_elevation,
                   cp$elevation[cp$type == "cold"])
})

test_that("ERA5: options, sea cells excluded, gridded flag, no secret", {
  era <- ewf_era5(aoi)
  calls <- ewf_mock(st, ter, era = era)
  old <- Sys.getenv("EARTHDATA_TOKEN", unset = NA)
  Sys.setenv(EARTHDATA_TOKEN = "tok-not-a-real-token-123")
  on.exit(if (is.na(old)) Sys.unsetenv("EARTHDATA_TOKEN") else
    Sys.setenv(EARTHDATA_TOKEN = old), add = TRUE)
  key <- "sk-test-secret-0042"
  res <- ewf_run(aoi, ewf_date(), weather = "era5",
                 preset = "idaho2002_elev", apikey = key)
  expect_identical(calls$openmeteo_fetch,
                   list(elevation_adjust = FALSE,
                        instant_values = "trapezoid", apikey_used = TRUE))
  codes <- vapply(res$flags, `[[`, "", "code")
  expect_true("EF_WS_GRIDDED_FORCING" %in% codes)
  expect_identical(res$forcing$method, "idw")
  sea <- era$stations$station_id[era$stations$elevation == 0]
  expect_gt(length(sea), 0L)
  expect_setequal(res$provenance$scene$stations_excluded$station_id, sea)
  expect_false(any(sea %in% res$provenance$scene$stations_used))
  tab <- res$forcing$surfaces$etr_24$station_table
  expect_true(all(tab$status[tab$station_id %in% sea] == "excluded"))
  expect_identical(res$provenance$sources$weather$license, "CC BY 4.0")
  # no secret anywhere in the provenance or the flags
  text <- paste(utils::capture.output(str(res$provenance, list.len = 1e4,
                                          vec.len = 1e4, nchar.max = 1e5)),
                collapse = "\n")
  text <- paste(text, paste(deparse(res$provenance$sources), collapse = ""),
                paste(deparse(res$flags), collapse = ""))
  expect_false(grepl(key, text, fixed = TRUE))
  expect_false(grepl("tok-not-a-real-token-123", text, fixed = TRUE))
})

test_that("weather that does not cover the scene is refused clearly", {
  short <- sta1
  keep <- short$observations$timestamp <
    as.POSIXct("2019-02-15 12:00", tz = "UTC")
  short <- ef_station_table(sta1$stations, sta1$observations[keep, ],
                            provenance = list(timestamp_convention = "end",
                                              interval = 3600,
                                              crs = "EPSG:4326"))
  calls <- ewf_mock(st, ter)
  expect_warning(
    expect_error(earthflux(aoi, ewf_date(), weather = short,
                           preset = "idaho2002_elev"),
                 class = "earthflux_weather_coverage_error"),
    class = "earthflux_unverified_preset_warning"
  )
})
