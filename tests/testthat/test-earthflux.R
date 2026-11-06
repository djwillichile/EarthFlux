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
                                collection = collection)
      new_ef_object(list(files = list(lst = "x", albedo = "x", ndvi = "x",
                                      lai = "x"),
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
# interpolated (O3) to the overpass time of each cell.
ewf_manual <- function(st, ter, aoi, stations, name) {
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
  zom <- ef_zom(lai = mat(lai), method = "lai")$zom
  zom[!is.na(zom) & zom == 0] <- NA
  u_b <- ef_blending_wind(mat(wind), height = 2, zom_station = 0.0144,
                          d_station = 0)
  # strict anchor QA, read from the registry by severity
  bits <- st$qa$flag_bits
  bad <- bits$bit[bits$severity %in% c("warning", "critical")]
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
  cal <- ef_calibrate_h(
    anchors, control = ef_h_control(),
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
    v
  }
  list(eta_24 = back(eta), etrf = back(etrf), h = back(cal$pixels$h),
       rn = back(rn), g = back(g), le = back(le), rl_in = back(rl_in),
       tau_sw = back(tau),
       etr_inst = etr_inst, etr_24 = etr_24, a = cal$a, b = cal$b,
       cold = t_cold)
}

# Presets ------------------------------------------------------------------------------

test_that("ef_presets() and ef_preset() describe the registered presets", {
  tab <- ef_presets()
  expect_s3_class(tab, "data.frame")
  expect_identical(tab$name, c("idaho2002_elev", "idaho2002_flat"))
  expect_identical(tab$version, c("1", "1"))
  expect_identical(tab$status, c("CANDIDATA", "CANDIDATA"))
  e <- ef_preset("idaho2002_elev")
  f <- ef_preset("idaho2002_flat")
  expect_s3_class(e, "earthflux_preset")
  expect_s3_class(e$anchors$criteria, "earthflux_anchor_criteria")
  expect_identical(e$anchors$criteria$status, "CANDIDATA")
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
  expect_s3_class(do.call(modis_surface_options, e$modis$surface_options),
                  "earthflux_modis_surface_options")
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
  expect_identical(calls_e$modis_fetch$lst_product, "MOD11A1")
  expect_identical(calls_e$modis_fetch$date, ewf_date())
  expect_identical(calls_e$modis_fetch$cache_dir, tempdir())
  o <- calls_e$modis_surface_state
  expect_s3_class(o, "earthflux_modis_surface_options")
  expect_identical(o$albedo_method, "white_sky")
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
  # to the per-pixel stability iteration of phase B (default tol = 0.01)
  px <- res_e$anchors$pixels
  etrf <- v[px$cell, "etrf"]
  expect_lt(abs(mean(etrf[px$type == "cold"]) - 1.05), 0.01)
  expect_lt(abs(mean(etrf[px$type == "hot"]) - 0), 0.01)
})

test_that("the flat preset uses one transmissivity and one longwave temperature", {
  calls <- ewf_mock(st, ter)
  res <- ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_flat",
                 cache_dir = tempdir())
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

test_that("z_om undefined at LAI = 0 is NA and flagged (EF_H_ZOM_UNDEFINED)", {
  lai <- val(st$lai)
  zom <- val(res_e$layers$zom)
  inside <- !is.na(val(res_e$layers$tau_sw))
  zero <- inside & !is.na(lai) & lai == 0
  expect_gt(sum(zero), 0L)
  expect_true(all(is.na(zom[zero])))
  rec <- Filter(function(f) f$code == "EF_H_ZOM_UNDEFINED", res_e$flags)
  expect_length(rec, 1L)
  expect_identical(rec[[1]]$index, which(zero))
  expect_identical(rec[[1]]$target, "zom")
  expect_identical(res_e$provenance$counts[["zom_undefined"]], sum(zero))
  w <- as.integer(val(res_e$qa$metric$flags_h))
  b <- ef_flag_registry()$bit[ef_flag_registry()$code == "EF_H_ZOM_UNDEFINED"]
  expect_identical(b, 10L)
  expect_identical(which(!is.na(w) & bitwAnd(w, bitwShiftL(1L, b)) != 0L),
                   which(zero))
  # negative case: no LAI = 0 in the AOI -> evaluated, no record
  st2 <- st
  l2 <- st2$lai
  terra::values(l2) <- ifelse(!is.na(lai) & lai == 0, 0.1, lai)
  st2$lai <- l2
  calls <- ewf_mock(st2, ter)
  res2 <- ewf_run(aoi, ewf_date(), weather = sta1, preset = "idaho2002_elev",
                  cache_dir = tempdir())
  expect_false("EF_H_ZOM_UNDEFINED" %in% vapply(res2$flags, `[[`, "", "code"))
  expect_true("EF_H_ZOM_UNDEFINED" %in%
                res2$provenance$flags_evaluated_by_stage$metric)
  expect_identical(res2$provenance$counts[["zom_undefined"]], 0L)
})

test_that("the provenance records every option of the preset", {
  pr <- res_e$provenance
  p <- ef_preset("idaho2002_elev")
  expect_identical(pr$preset$name, "idaho2002_elev")
  expect_identical(pr$preset$version, "1")
  expect_identical(pr$preset$status, "CANDIDATA")
  expect_identical(pr$preset$unverified, p$unverified)
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
})

# Several stations and ERA5 (C2) -------------------------------------------------------

test_that("several stations are interpolated by inverse distance weighting", {
  # A smaller AOI (the cold criteria find no candidate over the larger
  # one: the NDVI percentile of the whole area is above the NDVI of the
  # few cells with LAI >= 3 and albedo >= 0.18) and four stations around
  # it, so that no cell is outside their hull.
  aoi2 <- ewf_aoi(-72.5, -72.0, -36.2, -35.7)
  sta3 <- ewf_stations(lon = c(-72.6, -71.9, -72.6, -71.9),
                       lat = c(-35.6, -35.6, -36.3, -36.3),
                       elevation = c(120, 160, 220, 260))
  calls <- ewf_mock(st, ter)
  res <- ewf_run(aoi2, ewf_date(), weather = sta3, preset = "idaho2002_elev")
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
