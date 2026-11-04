# End-to-end test of the meteorological forcing chain (milestone M3)
#
# A small deterministic synthetic network (fictitious stations on the grid of
# helper-regionalize.R, one UTC day of hourly records) is run through the
# public API, in pipeline order:
#
#   ef_station_table() -> ef_station_qc()
#     -> ef_regionalize() of air temperature and vapour pressure (GWR with an
#        explicit fixed bandwidth, the elevation and distance-to-coast
#        covariates, a coarse 20 x 20 grid of 3 km cells)
#     -> mask of the out-of-domain bit of the flag word, degrees Celsius to
#        kelvin at the METRIC boundary (EF_KELVIN_OFFSET)
#     -> one METRIC step: ef_tau_sw_allen() (regionalized vapour pressure),
#        ef_atm_emissivity(), ef_rl_in() (regionalized air temperature),
#        ef_air_density()
#   ef_station_qc() -> ef_station_ref_et() (explicit choices, FAO-56 grass)
#     -> ef_etrf() and ef_et_daily() on a few pixels, with ET_inst from
#        ef_et_inst() and ef_lambda() at the regionalized air temperature.
#
# What is verified (structural invariants, no reference numbers):
#   * the stages connect: each output is accepted by the next stage;
#   * units, dimensions, extent and CRS: the surfaces are on the grid, one
#     layer per target time, in the units of the contract (degC, kPa), and
#     the METRIC outputs keep the dim of the grid;
#   * flags and provenance: the flag word carries the bits of the registry,
#     no cell is outside the physical domain, the objects carry valid
#     `earthflux_flag` records and the codes evaluated, the station reference
#     ET records its choices and the `target` of each flag;
#   * block invariance: two block sizes give identical surfaces, flag words
#     and METRIC outputs;
#   * ETrF = ET_inst / ETr_inst and ETa = ETrF x ETr_24 on the pixels, with
#     the same reference type throughout.
#
# What is NOT verified: the realism of any value (synthetic weather; the
# METRIC forms used are CANDIDATA), the choice between regionalizing ETr or
# its inputs (decision 5.1 is open), and the alfalfa reference (ASCE-EWRI
# constants are being verified separately; the grass reference of FAO-56 is
# used here because it is VERIFICADA).

fc_deg <- pi / 180

# Fictitious network: the station positions and elevations of
# rgn_test_data() and one UTC day (2024-01-15) of hourly period means
# (timestamps mark the end of the period). Values depend on the hour (a
# smooth daily cycle), the elevation and the distance to the "coast".
fc_station_table <- function(n = 15L) {
  pos <- rgn_test_data(n = n, n_times = 1L)
  xy <- attr(pos, "xy")
  u <- (xy[, "x"] - 300000) / 1000
  stations <- data.frame(
    station_id = pos$station_id, lon = pos$lon, lat = pos$lat,
    elevation = pos$elevation, height_wind = 2, height_temp_rh = 2,
    stringsAsFactors = FALSE
  )
  times <- as.POSIXct("2024-01-15 01:00", tz = "UTC") + 3600 * (0:23)
  mid <- seq(0.5, 23.5, by = 1)
  obs <- do.call(rbind, lapply(seq_len(n), function(i) {
    # cosine of the solar zenith angle at the mid-point of each period (0
    # at night): a smooth daily cycle of the fictitious weather
    geo <- ef_solar_geometry(doy = 15, utc_hour = mid,
                             lat = stations$lat[i] * fc_deg,
                             lon = stations$lon[i] * fc_deg)
    sun <- pmax(geo$cos_zenith, 0)
    tair <- 12 + 12 * sun - 0.0065 * stations$elevation[i] + 0.03 * u[i]
    data.frame(
      station_id = stations$station_id[i], timestamp = times,
      air_temperature = tair,
      vapour_pressure = (0.45 + 0.002 * u[i]) * ef_es(tair),
      wind_speed = 1.5 + 2 * sun,
      solar_radiation = 0.5 * EF_SOLAR_CONSTANT * sun,
      stringsAsFactors = FALSE
    )
  }))
  ef_station_table(
    stations, obs,
    provenance = list(timestamp_convention = "end", interval = 3600,
                      crs = "EPSG:4326", source = "synthetic test data")
  )
}

fc_grid <- function() {
  rgn_test_grid(n = 20L, res = 3000)
}

fc_regionalize <- function(qc, variable, grid, block_rows) {
  ef_regionalize(
    qc, variable, covariates = grid,
    method = ef_method_gwr(kernel = "gaussian", adaptive = FALSE,
                           bandwidth = 20000),
    use_qc = "ok", surface_covariates = character(0),
    prediction = ef_predict_control(block_rows = block_rows)
  )
}

# Layer of a surface (or of its flag word) at a target time, as a matrix
# with the rows and columns of the grid.
fc_layer <- function(s, time, what = "surface") {
  k <- which(s$target_time == time)
  terra::as.matrix(s[[what]][[k]], wide = TRUE)
}

# Values of a surface at a target time ready for the METRIC core: cells with
# the out-of-domain bit set are masked (NA) before the core, never passed on
# (dev/ARCHITECTURE.md section 4).
fc_core_input <- function(s, time) {
  v <- fc_layer(s, time)
  word <- fc_layer(s, time, "flag_word")
  bit <- s$flag_bits$bit[s$flag_bits$code == "EF_GWR_OUT_OF_DOMAIN"]
  v[bitwAnd(word, bitwShiftL(1L, bit)) != 0L] <- NA
  v
}

# One METRIC step with the regionalized forcing: atmospheric transmissivity
# (vapour pressure), incoming longwave radiation (air temperature, explicit
# temperature input of ef_rl_in()) and air density.
fc_metric_step <- function(ta_c, ea, elevation, time) {
  ta_k <- ta_c + EF_KELVIN_OFFSET
  pressure <- ef_air_pressure(elevation)
  geo <- ef_solar_geometry(
    doy = as.POSIXlt(time, tz = "UTC")$yday + 1,
    utc_hour = as.numeric(time) %% 86400 / 3600,
    lat = -35.6 * fc_deg, lon = -70.6 * fc_deg
  )
  tau <- ef_tau_sw_allen(cos_zenith = geo$cos_zenith, pressure = pressure,
                         vapour_pressure = ea, turbidity = 1)$total
  eps <- ef_atm_emissivity(tau)
  list(ta_k = ta_k, tau = tau,
       rl_in = ef_rl_in(temperature = ta_k, atm_emissivity = eps),
       rho = ef_air_density(pressure, ta_k))
}

test_that("stations, QC, regionalization and one METRIC step connect", {
  st <- fc_station_table()
  qc <- ef_station_qc(st)
  expect_s3_class(qc, c("earthflux_station_qc", "earthflux_station_table"))
  for (v in c("air_temperature", "vapour_pressure")) {
    expect_false(any(qc$qc_status[[v]] == "excluded"))
  }
  expect_true("EF_WS_OUT_OF_DOMAIN" %in% qc$provenance$flags_evaluated)

  grid <- fc_grid()
  elevation <- terra::as.matrix(grid[["elevation"]], wide = TRUE)
  times <- sort(unique(qc$observations$timestamp)) - 1800
  overpass <- as.POSIXct("2024-01-15 14:30", tz = "UTC")

  ta <- fc_regionalize(qc, "air_temperature", grid, block_rows = 3L)
  ea <- fc_regionalize(qc, "vapour_pressure", grid, block_rows = 3L)

  for (s in list(ta, ea)) {
    expect_s3_class(s, "earthflux_surface")
    expect_identical(s$method, "gwr")
    expect_equal(as.numeric(s$target_time), as.numeric(times))
    expect_equal(terra::nlyr(s$surface), length(times))
    expect_equal(terra::nlyr(s$flag_word), length(times))
    expect_true(terra::compareGeom(s$surface, grid, stopOnError = FALSE))
    expect_true(terra::compareGeom(s$flag_word, grid, stopOnError = FALSE))
    reg <- ef_flag_registry()
    expect_identical(s$flag_bits$bit,
                     reg$bit[match(s$flag_bits$code, reg$code)])
    expect_true(all(c("EF_INPUT_NA", "EF_GWR_OUT_OF_DOMAIN") %in%
                      s$flag_bits$code))
    expect_true("EF_GWR_OUT_OF_DOMAIN" %in% s$provenance$flags_evaluated)
    expect_invisible(check_flag_list(s$flags))
    # no surface covariate was used and every station entered the fits
    expect_false("EF_GWR_SURFACE_COVARIATE" %in%
                   vapply(s$flags, `[[`, "", "code"))
    expect_true(all(s$station_table$status == "used"))
  }
  expect_identical(ta$unit, "degC")
  expect_identical(ea$unit, "kPa")
  expect_identical(ta$variable, "air_temperature")
  expect_identical(ea$variable, "vapour_pressure")

  # Out-of-domain cells are masked before the core; here there are none.
  ta_c <- fc_core_input(ta, overpass)
  ea_k <- fc_core_input(ea, overpass)
  expect_identical(dim(ta_c), dim(elevation))
  expect_false(anyNA(ta_c))
  expect_false(anyNA(ea_k))
  expect_true(all(ea_k > 0))
  for (s in list(ta, ea)) {
    bit <- s$flag_bits$bit[s$flag_bits$code == "EF_GWR_OUT_OF_DOMAIN"]
    expect_false(any(bitwAnd(rgn_values(s$flag_word),
                             bitwShiftL(1L, bit)) != 0L))
  }

  # Degrees Celsius to kelvin at the METRIC boundary, then one METRIC step.
  step <- fc_metric_step(ta_c, ea_k, elevation, overpass)
  expect_equal(step$ta_k - ta_c, matrix(EF_KELVIN_OFFSET, 20L, 20L))
  for (nm in c("tau", "rl_in", "rho")) {
    expect_identical(dim(step[[nm]]), dim(elevation))
    expect_true(all(is.finite(step[[nm]]) & step[[nm]] > 0))
  }
  expect_true(all(step$tau < 1))

  # Block invariance through the METRIC step.
  ta1 <- fc_regionalize(qc, "air_temperature", grid, block_rows = 1L)
  ea1 <- fc_regionalize(qc, "vapour_pressure", grid, block_rows = 1L)
  expect_identical(rgn_values(ta1$surface), rgn_values(ta$surface))
  expect_identical(rgn_values(ta1$flag_word), rgn_values(ta$flag_word))
  expect_identical(rgn_values(ea1$surface), rgn_values(ea$surface))
  expect_identical(rgn_values(ea1$flag_word), rgn_values(ea$flag_word))
  step1 <- fc_metric_step(fc_core_input(ta1, overpass),
                          fc_core_input(ea1, overpass), elevation, overpass)
  expect_identical(step1, step)
})

test_that("station reference ET feeds ETrF and daily ET on a few pixels", {
  qc <- ef_station_qc(fc_station_table())
  overpass <- as.POSIXct("2024-01-15 14:30", tz = "UTC")
  day <- as.Date("2024-01-15")
  ref <- ef_station_ref_et(
    qc, reference = "grass", timestep = "hourly", standard = "fao56",
    humidity = "vapour_pressure", day_definition = "utc",
    day_completeness = "all_periods", daytime_rule = "ra_positive",
    night_cloudiness = "fixed", night_ratio = 0.7, overpass = overpass,
    inst_method = "O3", dates = day
  )
  ids <- qc$stations$station_id
  expect_s3_class(ref, "earthflux_station_ref_et")
  expect_identical(ref$reference, "grass")
  expect_identical(nrow(ref$series), nrow(qc$observations))
  expect_identical(ref$etr_inst$station_id, ids)
  expect_identical(ref$etr_24$station_id, ids)
  expect_identical(ref$etr_24$n_periods, rep(24L, length(ids)))
  expect_true(all(is.finite(ref$etr_inst$etr_inst) &
                    ref$etr_inst$etr_inst > 0))
  expect_true(all(is.finite(ref$etr_24$etr_24) & ref$etr_24$etr_24 > 0))
  # a complete day of hourly rates (mm h-1 x 1 h) sums to the daily value
  sums <- tapply(ref$series$et_ref, ref$series$station_id, sum)
  expect_equal(as.vector(sums[ids]), ref$etr_24$etr_24)
  # every flag names the table its index refers to; choices are recorded
  expect_invisible(check_flag_list(ref$flags))
  targets <- vapply(ref$flags, `[[`, "", "target")
  expect_true(all(targets %in% c("series", "etr_inst", "etr_24")))
  expect_false("EF_WS_INCOMPLETE_DAY" %in%
                 vapply(ref$flags, `[[`, "", "code"))
  expect_named(ref$provenance$flags_evaluated_by_target,
               c("series", "etr_inst", "etr_24"))
  expect_identical(ref$provenance$choices$inst_method, "O3")
  expect_identical(ref$provenance$choices$day_definition, "utc")

  # A few pixels, each at the cell of a station (C1-like forcing of ETr):
  # the regionalized air temperature at the overpass gives lambda, a
  # synthetic LE gives ET_inst, and the station ETr_inst and ETr_24 give
  # ETrF and the daily ETa with the same reference type.
  grid <- fc_grid()
  ta <- fc_regionalize(qc, "air_temperature", grid, block_rows = NULL)
  k <- which(ta$target_time == overpass)
  xy <- terra::project(as.matrix(qc$stations[, c("lon", "lat")]),
                       from = "EPSG:4326", to = "EPSG:32719")
  pix <- 1:5
  ta_pix <- terra::extract(ta$surface[[k]], xy[pix, , drop = FALSE])[, 1]
  expect_false(anyNA(ta_pix))
  le <- c(50, 150, 250, 350, 450)
  lambda <- ef_lambda(ta_pix + EF_KELVIN_OFFSET, method = "fao56")
  et_inst <- ef_et_inst(le, lambda)
  etr_inst <- ref$etr_inst$etr_inst[pix]
  etr_24 <- ref$etr_24$etr_24[pix]
  etrf <- ef_etrf(et_inst, etr_inst, reference = "grass")
  expect_equal(etrf, et_inst / etr_inst)
  eta <- ef_et_daily(etrf, etr_24, reference = "grass", method = "etrf")
  expect_s3_class(eta, "earthflux_daily_et")
  expect_identical(eta$reference, "grass")
  expect_equal(eta$eta_24, etrf * etr_24)
  expect_identical(eta$eta_24,
                   ef_et_daily_etrf(etrf, etr_24, reference = "grass"))
  expect_true("EF_ET_NEGATIVE" %in% eta$provenance$flags_evaluated)
})
