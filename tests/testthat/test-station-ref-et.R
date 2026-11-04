# Tests for the reference ET at the stations (R/prep-weather.R):
# ef_station_ref_et() and its internal helpers (night-time cloudiness,
# instantaneous reference ET at the overpass, daily sums), with the flags
# EF_WS_INCOMPLETE_DAY and EF_WS_OVERPASS_OUTSIDE_RECORDS.
#
# Specification: dev/specs/weather-forcing.md sections 4.8 (night-time
# cloudiness), 5.4-5.6 (orchestration, ETr_inst options O1 and O3, ETr_24
# option D1 and the day definition) and 8 (FAO-56 examples 18 and 19, cases
# V14-V16). Synthetic data are built here or in helper-stations.R; the
# stations and values are fictitious except the FAO-56 examples.
#
# Tolerances (dev/VALIDATION_PLAN.md section 1.2): published FAO-56 values
# with half a unit of their last digit; agreement with the same chain of
# functions called directly with a relative tolerance of 1e-12.

deg <- pi / 180
half_unit <- function(digits) 0.5 * 10^(-digits)

expect_within <- function(object, expected, tol) {
  expect_lte(max(abs(object - expected)), tol)
}

flags_of <- function(x, target) {
  Filter(function(f) identical(f$target, target), x$flags)
}

flag_index <- function(x, code, target) {
  hit <- Filter(function(f) identical(f$code, code), flags_of(x, target))
  if (length(hit) == 0L) {
    return(NULL)
  }
  hit[[1L]]$index
}

utc <- function(x) as.POSIXct(x, tz = "UTC")

prov_hourly <- list(timestamp_convention = "end", interval = 3600,
                    crs = "EPSG:4326")

# Hourly synthetic series of one or two stations: smooth diurnal cycles in
# UTC with a warming trend of 0.1 degC per hour (so that consecutive days
# differ), solar radiation 60 % of the extraterrestrial radiation of the
# sunlit part of the hour (ASCE-EWRI Eq. 56 limits; always below the
# clear-sky envelope of both standards and above zero only by day).
hourly_series <- function(start = "2024-01-15 01:00", n = 48L,
                          stations = syn_stations()[1L, , drop = FALSE]) {
  times <- utc(start) + 3600 * (seq_len(n) - 1L)
  rows <- lapply(seq_len(nrow(stations)), function(i) {
    s <- stations[i, ]
    mid <- times - 1800
    lt <- as.POSIXlt(mid, tz = "UTC")
    h <- lt$hour + lt$min / 60
    ra <- ef_ra_period(s$lat * deg, s$lon * deg, lt$yday + 1L, h, 1,
                       standard = "asce")
    sun <- ra / max(ra)
    data.frame(
      station_id = s$station_id, timestamp = times,
      air_temperature = 14 + 12 * sun + i + 0.1 * (seq_len(n) - 1L),
      relative_humidity = 85 - 45 * sun,
      wind_speed = 1.5 + 2 * sun,
      solar_radiation = 0.6 * ra / 0.0036,
      stringsAsFactors = FALSE
    )
  })
  ef_station_table(stations, do.call(rbind, rows), prov_hourly)
}

# Hourly call with the alfalfa reference; `...` overrides any argument.
run_hourly <- function(x, ..., reference = "alfalfa", standard = "asce",
                       night_cloudiness = "before_sunset",
                       day_definition = "utc") {
  args <- list(reference = reference, timestep = "hourly",
               standard = standard, humidity = "relative_humidity",
               day_definition = day_definition,
               day_completeness = "all_periods",
               daytime_rule = "ra_positive",
               night_cloudiness = night_cloudiness)
  if (night_cloudiness == "fixed") {
    args$night_ratio <- 0.7
  }
  do.call(ef_station_ref_et, c(list(x), utils::modifyList(args, list(...))))
}

# FAO-56 example 19 through the station table --------------------------------------

# N'Diaye, Senegal, 1 October (J = 274 in 2023), 16 13' N, 16 15' W, 8 m;
# local standard time is UTC - 1 h (Lz = 15 degrees W), so the periods
# 14:00-15:00 and 02:00-03:00 local end at 16:00 and 04:00 UTC. Rs is given
# in MJ m-2 h-1 (declared conversion); u2 = 3.3 and 1.9 m s-1 are taken as
# measured at 2 m (FAO-56 Eq. 47 gives the factor 1.00022).
ndiaye <- local({
  stations <- data.frame(station_id = "NDIAYE", lon = -(16 + 15 / 60),
                         lat = 16 + 13 / 60, elevation = 8, height_wind = 2,
                         height_temp_rh = 2)
  obs <- data.frame(
    station_id = "NDIAYE",
    timestamp = utc(c("2023-10-01 04:00", "2023-10-01 16:00")),
    air_temperature = c(28, 38), relative_humidity = c(90, 52),
    wind_speed = c(1.9, 3.3), solar_radiation = c(0, 2.450)
  )
  ef_station_table(stations, obs, prov_hourly,
                   units = list(solar_radiation = "MJ/m2/h"))
})

ndiaye_direct <- function(i, reference, standard, daytime, f = NULL) {
  p <- list(t = c(28, 38)[i], rh = c(90, 52)[i], u = c(1.9, 3.3)[i],
            rs = c(0, 2.45)[i], h = c(3.5, 15.5)[i])
  lat <- (16 + 13 / 60) * deg
  lon <- -(16 + 15 / 60) * deg
  ea <- ef_ea_rh(p$t, p$rh)
  rso <- ef_rso(ef_ra_period(lat, lon, 274, p$h, 1, standard = standard), 8)
  rn <- if (is.null(f)) {
    ef_ref_net_radiation(p$rs, rso, ea, air_temperature = p$t,
                         timestep = "hourly", standard = standard)$rn
  } else {
    ef_ref_net_radiation(p$rs, NULL, ea, air_temperature = p$t,
                         timestep = "hourly", standard = standard,
                         cloudiness = f)$rn
  }
  g <- ef_ref_soil_heat_flux(rn, reference, "hourly", standard,
                             daytime = daytime)
  ef_ref_et(rn, g, p$t, ef_wind_2m(p$u, 2), ef_es(p$t) - ea,
            ef_es_slope(p$t), ef_psychrometric(ef_air_pressure(8)),
            reference = reference, timestep = "hourly", standard = standard,
            daytime = daytime)$et_ref
}

test_that("V15-V16: FAO-56 example 19 through ef_station_ref_et()", {
  et <- run_hourly(ndiaye, reference = "grass", standard = "fao56",
                   night_cloudiness = "fixed", night_ratio = 0.8)
  s <- et$series
  expect_s3_class(et, "earthflux_station_ref_et")
  # 14:00-15:00 local (row 2): published values of example 19.
  expect_within(s$extraterrestrial_radiation[2], 3.543, half_unit(3))
  expect_within(s$clear_sky_radiation[2], 2.658, half_unit(3))
  expect_within(s$solar_radiation[2], 2.450, 1e-12)
  expect_within(s$vapour_pressure[2], 3.445, half_unit(3))
  expect_within(s$net_radiation[2], 1.749, half_unit(3))
  expect_within(s$soil_heat_flux[2], 0.175, half_unit(3))
  expect_within(s$et_ref[2], 0.63, half_unit(2))
  expect_within(s$et_ref[2], 0.6269, half_unit(4))
  expect_identical(s$daytime, c(FALSE, TRUE))
  expect_identical(s$cloudiness_source, c("fixed", "ratio"))
  # 02:00-03:00 local (row 1): Ra = 0, Rs/Rso = 0.8 assumed by the example.
  expect_identical(s$extraterrestrial_radiation[1], 0)
  expect_within(s$cloudiness[1], 1.35 * 0.8 - 0.35, 1e-15)
  expect_within(s$net_radiation[1], -0.100, half_unit(3))
  expect_within(s$soil_heat_flux[1], -0.050, half_unit(3))
  expect_within(s$et_ref[1], 0, 0.005)
  expect_within(s$et_ref[1], 0.0043, half_unit(4))
  # Same numbers as the chain of functions called directly.
  expect_equal(s$et_ref[2], ndiaye_direct(2, "grass", "fao56", TRUE),
               tolerance = 1e-12)
  expect_equal(s$et_ref[1],
               ndiaye_direct(1, "grass", "fao56", FALSE, 1.35 * 0.8 - 0.35),
               tolerance = 1e-12)
  expect_identical(et$provenance$status, "VERIFICADA")
})

test_that("A3: the tall reference through the station table", {
  et <- run_hourly(ndiaye, night_cloudiness = "fixed", night_ratio = 0.8)
  # Arithmetic case A3 of spec 8.2 (0.8218 and 0.0067 mm h-1 with u2 = 3.3
  # and 1.9 exactly); here u2 carries the factor 1.00022 of Eq. 47.
  expect_within(et$series$et_ref, c(0.0067, 0.8218), 2e-4)
  expect_equal(et$series$et_ref,
               c(ndiaye_direct(1, "alfalfa", "asce", FALSE,
                               1.35 * 0.8 - 0.35),
                 ndiaye_direct(2, "alfalfa", "asce", TRUE)),
               tolerance = 1e-12)
  expect_identical(et$reference, "alfalfa")
  expect_identical(et$provenance$status, "VERIFICADA")
  expect_identical(et$provenance$constants$cn, c(66, 66))
})

# FAO-56 example 18 through daily records ------------------------------------------

test_that("V14: FAO-56 example 18 through daily records", {
  # Uccle, 6 July (J = 187 in 2023), 50 48' N, 4 21' E, 100 m; wind of
  # 10 km/h at 10 m; Rs = 22.07 MJ m-2 d-1 (from sunshine hours in the
  # example); humidity from RHmax and RHmin (Eq. 17).
  st <- ef_station_table(
    data.frame(station_id = "UCCLE", lon = 4.35, lat = 50 + 48 / 60,
               elevation = 100, height_wind = 10, height_temp_rh = 2),
    data.frame(station_id = "UCCLE", timestamp = utc("2023-07-06 00:00"),
               tmax = 21.5, tmin = 12.3, rh_max = 84, rh_min = 63,
               wind_speed = 10, solar_radiation = 22.07),
    list(timestamp_convention = "start", interval = 86400,
         crs = "EPSG:4326"),
    units = list(wind_speed = "km/h", solar_radiation = "MJ/m2/d")
  )
  et <- ef_station_ref_et(st, reference = "grass", timestep = "daily",
                          standard = "fao56", humidity = "relative_humidity",
                          day_definition = "utc",
                          day_completeness = "all_periods")
  s <- et$series
  expect_within(s$extraterrestrial_radiation, 41.09, half_unit(2))
  expect_within(s$clear_sky_radiation, 30.90, half_unit(2))
  expect_within(s$vapour_pressure, 1.409, half_unit(3))
  expect_within(s$wind_speed_2m, 2.078, half_unit(3))
  expect_within(s$net_radiation, 13.28, half_unit(2) + 0.002)
  expect_identical(s$soil_heat_flux, 0)
  expect_within(s$et_ref, 3.9, half_unit(1))
  expect_within(s$et_ref, 3.88, half_unit(2))
  expect_identical(s$daytime, NA)
  # The daily value of the record is the daily sum of its day (option D2
  # with daily records).
  expect_identical(et$etr_24$date, as.Date("2023-07-06"))
  expect_identical(et$etr_24$n_periods, 1L)
  expect_identical(et$etr_24$etr_24, s$et_ref)
  expect_identical(nrow(et$etr_inst), 0L)
  expect_match(et$provenance$choices$daily_method, "^D2")
  # Same chain called directly.
  ea <- ef_ea_daily(12.3, 21.5, 84, 63, method = "rhmax_rhmin")
  rso <- ef_rso(ef_ra_daily((50 + 48 / 60) * deg, 187), 100)
  rn <- ef_ref_net_radiation(22.07, rso, ea, tmax = 21.5, tmin = 12.3,
                             timestep = "daily", standard = "fao56")$rn
  direct <- ef_ref_et(rn, 0, (21.5 + 12.3) / 2, ef_wind_2m(10 / 3.6, 10),
                      mean(ef_es(c(21.5, 12.3))) - ea,
                      ef_es_slope((21.5 + 12.3) / 2),
                      ef_psychrometric(ef_air_pressure(100)),
                      reference = "grass", timestep = "daily",
                      standard = "fao56")$et_ref
  expect_equal(s$et_ref, direct, tolerance = 1e-12)
})

# Instantaneous reference ET at the overpass (options O1 and O3) -----------------

test_that("O1 takes the period that contains the overpass time", {
  x <- hourly_series()
  et <- run_hourly(x, overpass = utc(c("2024-01-15 14:48", "2024-01-15 14:00",
                                       "2024-01-15 15:00")),
                   inst_method = "O1")
  s <- et$series
  # Periods are [start, end): 14:48 and 14:00 are in the period ending at
  # 15:00, 15:00 is in the period ending at 16:00.
  end_15 <- which(s$timestamp == utc("2024-01-15 15:00"))
  end_16 <- which(s$timestamp == utc("2024-01-15 16:00"))
  expect_identical(et$etr_inst$etr_inst,
                   s$et_ref[c(end_15, end_15, end_16)])
  expect_identical(et$etr_inst$method, rep("O1", 3L))
  expect_identical(attr(et$etr_inst$overpass_time, "tzone"), "UTC")
  expect_named(et$etr_inst, c("station_id", "overpass_time", "etr_inst",
                              "method"))
  expect_true(all(et$etr_inst$etr_inst > 0))
  expect_null(flag_index(et, "EF_WS_OVERPASS_OUTSIDE_RECORDS", "etr_inst"))
  expect_true("EF_WS_OVERPASS_OUTSIDE_RECORDS" %in%
                et$provenance$flags_evaluated_by_target$etr_inst)
})

test_that("O3 interpolates the hourly rates between mid-points", {
  x <- hourly_series()
  et <- run_hourly(x, overpass = utc(c("2024-01-15 14:48", "2024-01-15 15:30")),
                   inst_method = "O3")
  s <- et$series
  a <- s$et_ref[s$target_time == utc("2024-01-15 14:30")]
  b <- s$et_ref[s$target_time == utc("2024-01-15 15:30")]
  # 14:48 is 0.3 h after the mid-point 14:30; at a mid-point, its rate.
  expect_equal(et$etr_inst$etr_inst, c(a + 0.3 * (b - a), b),
               tolerance = 1e-12)
  expect_identical(et$provenance$choices$inst_method, "O3")
  # The two options differ off the mid-points.
  et1 <- run_hourly(x, overpass = utc("2024-01-15 14:48"), inst_method = "O1")
  expect_false(isTRUE(all.equal(et1$etr_inst$etr_inst,
                                et$etr_inst$etr_inst[1])))
})

test_that("an overpass outside the records gives NA and the flag", {
  x <- hourly_series(n = 24L) # periods from 00:00 to 24:00 UTC, 15 January
  times <- utc(c("2024-01-14 23:59", "2024-01-15 00:10", "2024-01-15 12:00",
                 "2024-01-15 23:50", "2024-01-16 00:00"))
  o1 <- run_hourly(x, overpass = times, inst_method = "O1",
                   night_cloudiness = "fixed")
  expect_identical(is.na(o1$etr_inst$etr_inst),
                   c(TRUE, FALSE, FALSE, FALSE, TRUE))
  expect_identical(flag_index(o1, "EF_WS_OVERPASS_OUTSIDE_RECORDS",
                              "etr_inst"), c(1L, 5L))
  # O3 covers only from the first to the last mid-point (00:30-23:30).
  o3 <- run_hourly(x, overpass = times, inst_method = "O3",
                   night_cloudiness = "fixed")
  expect_identical(flag_index(o3, "EF_WS_OVERPASS_OUTSIDE_RECORDS",
                              "etr_inst"), c(1L, 2L, 4L, 5L))
  expect_identical(is.na(o3$etr_inst$etr_inst),
                   c(TRUE, TRUE, FALSE, TRUE, TRUE))
  # Outside is not a missing input.
  expect_null(flag_index(o3, "EF_INPUT_NA", "etr_inst"))
  f <- Filter(function(f) f$code == "EF_WS_OVERPASS_OUTSIDE_RECORDS",
              o3$flags)[[1L]]
  expect_identical(f$severity, "info")
  expect_identical(f$scope, "record")
  expect_identical(f$n_total, 5L)
})

test_that("no interpolation across a missing or excluded record", {
  x <- hourly_series()
  obs <- x$observations
  gap <- obs[obs$timestamp != utc("2024-01-15 15:00"), ]
  xg <- ef_station_table(x$stations, gap, prov_hourly)
  times <- utc(c("2024-01-15 14:20", "2024-01-15 14:40", "2024-01-15 15:20",
                 "2024-01-15 16:00"))
  o1 <- run_hourly(xg, overpass = times, inst_method = "O1")
  # 14:20 and 14:40 fall in the missing period 14:00-15:00.
  expect_identical(is.na(o1$etr_inst$etr_inst), c(TRUE, TRUE, FALSE, FALSE))
  expect_identical(flag_index(o1, "EF_INPUT_NA", "etr_inst"), 1:2)
  o3 <- run_hourly(xg, overpass = times, inst_method = "O3")
  # Mid-points 13:30, (14:30 missing), 15:30, 16:30: 14:20 to 15:20 cannot
  # be interpolated; 16:00 can.
  expect_identical(is.na(o3$etr_inst$etr_inst), c(TRUE, TRUE, TRUE, FALSE))
  expect_identical(flag_index(o3, "EF_INPUT_NA", "etr_inst"), 1:3)
  expect_null(flag_index(o3, "EF_WS_OVERPASS_OUTSIDE_RECORDS", "etr_inst"))
  # An excluded value (impossible humidity) acts like a missing record.
  obs$relative_humidity[obs$timestamp == utc("2024-01-15 15:00")] <- -5
  xe <- ef_station_table(x$stations, obs, prov_hourly)
  oe <- run_hourly(xe, overpass = times[3:4], inst_method = "O3")
  expect_identical(is.na(oe$etr_inst$etr_inst), c(TRUE, FALSE))
  i <- which(oe$series$timestamp == utc("2024-01-15 15:00"))
  expect_true(is.na(oe$series$et_ref[i]))
  expect_true(i %in% flag_index(oe, "EF_INPUT_NA", "series"))
  expect_identical(oe$provenance$qc$qc_policy, "exclude_critical")
  ex <- oe$provenance$qc$excluded
  expect_identical(ex$n_excluded[ex$variable == "relative_humidity"], 1L)
  # The observations are not modified.
  expect_identical(oe$provenance$station_table$operations$step,
                   c("ef_station_table", "ef_station_qc"))
})

test_that("each station gets every overpass time", {
  x <- hourly_series(stations = syn_stations())
  et <- run_hourly(x, overpass = utc(c("2024-01-15 14:48", "2024-01-15 15:12")),
                   inst_method = "O3")
  expect_identical(et$etr_inst$station_id, rep(c("ST01", "ST02"), each = 2L))
  expect_false(anyNA(et$etr_inst$etr_inst))
  # Different stations, different values.
  expect_false(isTRUE(all.equal(et$etr_inst$etr_inst[1:2],
                                et$etr_inst$etr_inst[3:4])))
})

# Daily sums (option D1) and the day definition ------------------------------------

test_that("D1: complete UTC days are the sum of their 24 hourly values", {
  x <- hourly_series(start = "2024-01-15 01:00", n = 48L)
  et <- run_hourly(x)
  s <- et$series
  d <- et$etr_24
  expect_named(d, c("station_id", "date", "n_periods", "etr_24"))
  expect_identical(d$date, as.Date(c("2024-01-15", "2024-01-16")))
  day1 <- s$date == as.Date("2024-01-15")
  day2 <- s$date == as.Date("2024-01-16")
  expect_identical(c(sum(day1), sum(day2)), c(24L, 24L))
  # The first night of the series has no period before sunset to carry
  # (night_cloudiness = "before_sunset"): those periods are NA, so the first
  # day is incomplete; the second day is complete.
  expect_true(anyNA(s$et_ref[day1]))
  expect_false(anyNA(s$et_ref[day2]))
  expect_identical(d$n_periods, c(sum(!is.na(s$et_ref[day1])), 24L))
  expect_true(is.na(d$etr_24[1]))
  expect_equal(d$etr_24[2], sum(s$et_ref[day2]), tolerance = 1e-12)
  expect_identical(flag_index(et, "EF_WS_INCOMPLETE_DAY", "etr_24"), 1L)
})

test_that("D1: incomplete days give NA and EF_WS_INCOMPLETE_DAY", {
  # 60 hourly periods ending 2024-01-15 01:00 ... 2024-01-17 12:00 UTC, with
  # a fixed night ratio so that every period has a value.
  x <- hourly_series(start = "2024-01-15 01:00", n = 60L)
  obs <- x$observations
  drop <- obs$timestamp == utc("2024-01-16 06:00")
  xg <- ef_station_table(x$stations, obs[!drop, ], prov_hourly)
  et <- run_hourly(xg, night_cloudiness = "fixed", night_ratio = 0.7)
  s <- et$series
  d <- et$etr_24
  expect_false(anyNA(s$et_ref))
  expect_identical(d$date, as.Date(c("2024-01-15", "2024-01-16",
                                     "2024-01-17")))
  expect_identical(d$n_periods, c(24L, 23L, 12L))
  expect_equal(d$etr_24[1], sum(s$et_ref[s$date == as.Date("2024-01-15")]),
               tolerance = 1e-12)
  expect_identical(is.na(d$etr_24), c(FALSE, TRUE, TRUE))
  expect_identical(flag_index(et, "EF_WS_INCOMPLETE_DAY", "etr_24"), 2:3)
  f <- Filter(function(f) f$code == "EF_WS_INCOMPLETE_DAY", et$flags)[[1L]]
  expect_identical(f$severity, "warning")
  expect_identical(f$target, "etr_24")
  # A missing value inside a day also makes it incomplete (no filling).
  obs2 <- obs
  obs2$wind_speed[obs2$timestamp == utc("2024-01-15 12:00")] <- NA
  et2 <- run_hourly(ef_station_table(x$stations, obs2, prov_hourly),
                    night_cloudiness = "fixed", night_ratio = 0.7)
  expect_identical(et2$etr_24$n_periods[1], 23L)
  expect_true(is.na(et2$etr_24$etr_24[1]))
})

test_that("D1: requested dates, including days without records", {
  x <- hourly_series(start = "2024-01-15 01:00", n = 48L)
  et <- run_hourly(x, night_cloudiness = "fixed", night_ratio = 0.7,
                   dates = as.Date(c("2024-01-16", "2024-01-20")))
  d <- et$etr_24
  expect_identical(d$date, as.Date(c("2024-01-16", "2024-01-20")))
  expect_identical(d$n_periods, c(24L, 0L))
  expect_false(is.na(d$etr_24[1]))
  expect_true(is.na(d$etr_24[2]))
  expect_identical(flag_index(et, "EF_WS_INCOMPLETE_DAY", "etr_24"), 2L)
  # Negative case: complete days only, the code is evaluated and absent.
  et_ok <- run_hourly(x, night_cloudiness = "fixed", night_ratio = 0.7)
  expect_null(flag_index(et_ok, "EF_WS_INCOMPLETE_DAY", "etr_24"))
  expect_true("EF_WS_INCOMPLETE_DAY" %in% et_ok$provenance$flags_evaluated)
})

test_that("the local standard day and the UTC day give different sums", {
  # 72 periods; with UTC-4 the local days run from 04:00 to 04:00 UTC.
  x <- hourly_series(start = "2024-01-15 01:00", n = 72L)
  et_utc <- run_hourly(x, night_cloudiness = "fixed", night_ratio = 0.7)
  et_loc <- run_hourly(x, night_cloudiness = "fixed", night_ratio = 0.7,
                       day_definition = "local_standard", utc_offset = -4)
  s <- et_loc$series
  # Periods ending 01:00-04:00 UTC on 15 January belong to 14 January local.
  expect_identical(s$date[1:4], rep(as.Date("2024-01-14"), 4L))
  expect_identical(s$date[5], as.Date("2024-01-15"))
  d_loc <- et_loc$etr_24
  expect_identical(d_loc$date, as.Date(c("2024-01-14", "2024-01-15",
                                         "2024-01-16", "2024-01-17")))
  expect_identical(d_loc$n_periods, c(4L, 24L, 24L, 20L))
  local_15 <- d_loc$etr_24[d_loc$date == as.Date("2024-01-15")]
  utc_15 <- et_utc$etr_24$etr_24[et_utc$etr_24$date == as.Date("2024-01-15")]
  expect_equal(local_15, sum(s$et_ref[5:28]), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(local_15, utc_15)))
  expect_identical(et_loc$provenance$choices$day_definition,
                   "local_standard")
  expect_identical(et_loc$provenance$choices$utc_offset, c(ST01 = -4))
  # Offsets named by station.
  x2 <- hourly_series(stations = syn_stations())
  et2 <- run_hourly(x2, night_cloudiness = "fixed", night_ratio = 0.7,
                    day_definition = "local_standard",
                    utc_offset = c(ST02 = -3, ST01 = -4))
  first <- et2$series[!duplicated(et2$series$station_id), ]
  expect_identical(first$date, as.Date(c("2024-01-14", "2024-01-14")))
  expect_identical(et2$provenance$choices$utc_offset, c(ST01 = -4, ST02 = -3))
})

# Night-time cloudiness and day/night criterion ------------------------------------

test_that("night-time periods carry the ratio of 2-3 hours before sunset", {
  x <- hourly_series(start = "2024-01-15 01:00", n = 48L)
  et <- run_hourly(x)
  s <- et$series
  st <- x$stations
  lt <- as.POSIXlt(s$target_time, tz = "UTC")
  doy <- lt$yday + 1L
  h <- lt$hour + lt$min / 60
  omega <- ef_hour_angle(doy, h, st$lon * deg)
  ws <- acos(-tan(st$lat * deg) * tan(ef_declination(doy)))
  qualifies <- s$clear_sky_radiation > 0 & omega >= ws - 0.79 &
    omega <= ws - 0.52
  expect_gte(sum(qualifies), 2L)
  night <- which(s$clear_sky_radiation == 0)
  expect_identical(unique(s$cloudiness_source[night]), "before_sunset")
  expect_true(all(s$cloudiness_source[-night] == "ratio"))
  for (i in night) {
    q <- which(qualifies & s$target_time < s$target_time[i] &
                 s$target_time > s$target_time[i] - 86400)
    expected <- if (length(q) == 0L) NA_real_ else s$cloudiness[max(q)]
    expect_identical(s$cloudiness[i], expected)
  }
  # Nights before the first qualifying period have no ratio: NA, flagged.
  before <- night[s$target_time[night] < min(s$target_time[qualifies])]
  expect_gt(length(before), 0L)
  expect_true(all(is.na(s$net_radiation[before])))
  expect_true(all(before %in% flag_index(et, "EF_INPUT_NA", "series")))
  after <- setdiff(night, before)
  expect_false(anyNA(s$et_ref[after]))
  expect_identical(et$provenance$choices$night_cloudiness, "before_sunset")
})

test_that("low_sun: ASCE-EWRI Eq. 46 carries fcd of the last beta > 0.3 rad", {
  x <- hourly_series(start = "2024-01-15 01:00", n = 48L)
  et <- run_hourly(x, night_cloudiness = "low_sun",
                   daytime_rule = "rn_positive")
  s <- et$series
  st <- x$stations
  lt <- as.POSIXlt(s$target_time, tz = "UTC")
  doy <- lt$yday + 1L
  h <- lt$hour + lt$min / 60
  lat <- st$lat * deg
  delta <- ef_declination(doy)
  omega <- ef_hour_angle(doy, h, st$lon * deg)
  # Sun angle above the horizon at the mid-point, ASCE-EWRI Eq. 62.
  beta <- asin(sin(lat) * sin(delta) + cos(lat) * cos(delta) * cos(omega))
  high <- s$clear_sky_radiation > 0 & beta > 0.3
  low <- which(!high)
  # Low sun with Rso > 0 (dusk and dawn) also takes the carried value.
  expect_gt(sum(s$clear_sky_radiation[low] > 0), 0L)
  expect_true(all(s$cloudiness_source[high] == "ratio"))
  expect_identical(unique(s$cloudiness_source[low]), "low_sun")
  # Own ratio, limited to [0.3, 1] (ASCE-EWRI Eq. 45).
  ratio <- s$solar_radiation / s$clear_sky_radiation
  expect_equal(s$cloudiness[high],
               1.35 * pmin(pmax(ratio[high], 0.3), 1) - 0.35,
               tolerance = 1e-12)
  for (i in low) {
    q <- which(high & s$target_time < s$target_time[i] &
                 s$target_time > s$target_time[i] - 86400)
    expected <- if (length(q) == 0L) NA_real_ else s$cloudiness[max(q)]
    expect_identical(s$cloudiness[i], expected)
  }
  # One value per day: the term of the last high-sun period of the
  # afternoon is used until the sun angle exceeds 0.3 rad again.
  first_high <- min(which(high))
  before <- low[low < first_high]
  expect_gt(length(before), 0L)
  expect_true(all(is.na(s$net_radiation[before])))
  expect_true(all(before %in% flag_index(et, "EF_INPUT_NA", "series")))
  after <- setdiff(low, before)
  expect_false(anyNA(s$et_ref[after]))
  # Extraterrestrial radiation with the limits of Eq. 56 and daytime by
  # Rn > 0.
  expect_equal(s$extraterrestrial_radiation,
               ef_ra_period(lat, st$lon * deg, doy, h, 1, standard = "asce"),
               tolerance = 1e-12)
  expect_identical(s$daytime, s$net_radiation > 0)
  expect_identical(et$provenance$choices$night_cloudiness, "low_sun")
  expect_match(et$provenance$derived$extraterrestrial_radiation, "Eq. 56")
  expect_match(et$provenance$derived$net_radiation, "ASCE-EWRI")
})

test_that("the fixed night ratio is used at every night-time period", {
  x <- hourly_series()
  et <- run_hourly(x, night_cloudiness = "fixed", night_ratio = 0.5)
  s <- et$series
  night <- s$clear_sky_radiation == 0
  expect_true(all(s$cloudiness[night] == 1.35 * 0.5 - 0.35))
  expect_true(all(s$cloudiness_source[night] == "fixed"))
  expect_false(anyNA(s$et_ref))
  expect_identical(et$provenance$choices$night_ratio, 0.5)
})

test_that("the daytime rule selects G and Cd by Ra > 0 or Rn > 0", {
  x <- hourly_series()
  obs <- x$observations
  # First and last daylight hours, clear, hot and dry: Ra > 0 but the net
  # longwave loss exceeds the net shortwave, Rn < 0.
  ra <- ef_ra_period(-35.4 * deg, -71.5 * deg, rep(15:16, each = 2),
                     rep(c(10.5, 23.5), 2), 1, standard = "asce")
  edge <- obs$timestamp %in% utc(c("2024-01-15 11:00", "2024-01-16 00:00",
                                   "2024-01-16 11:00", "2024-01-17 00:00"))
  expect_true(all(ra > 0))
  obs$solar_radiation[edge] <- 0.99 * ef_rso(ra, 150) / 0.0036
  obs$air_temperature[edge] <- 30
  obs$relative_humidity[edge] <- 12
  x <- ef_station_table(x$stations, obs, prov_hourly)
  args <- list(x, reference = "alfalfa", timestep = "hourly",
               standard = "asce", humidity = "relative_humidity",
               day_definition = "utc", day_completeness = "all_periods",
               night_cloudiness = "fixed", night_ratio = 0.7)
  ra <- do.call(ef_station_ref_et, c(args, daytime_rule = "ra_positive"))
  rn <- do.call(ef_station_ref_et, c(args, daytime_rule = "rn_positive"))
  expect_identical(ra$series$daytime, ra$series$extraterrestrial_radiation > 0)
  expect_identical(rn$series$daytime, rn$series$net_radiation > 0)
  # Same net radiation; different day/night split near sunrise and sunset.
  expect_identical(ra$series$net_radiation, rn$series$net_radiation)
  differ <- ra$series$daytime != rn$series$daytime
  expect_true(any(differ))
  expect_false(any(ra$series$et_ref[differ] == rn$series$et_ref[differ]))
  expect_identical(ra$series$et_ref[!differ], rn$series$et_ref[!differ])
  # G ratios of the tall reference (ASCE-EWRI Eqs. 66a-b): 0.04 by day,
  # 0.2 by night.
  s <- ra$series
  expect_equal(s$soil_heat_flux,
               ifelse(s$daytime, 0.04, 0.2) * s$net_radiation,
               tolerance = 1e-12)
})

# Flags and object ----------------------------------------------------------------

test_that("series flags: negative ETr and Rs/Rso limited, with their target", {
  x <- hourly_series()
  obs <- x$observations
  # One daytime record above its clear-sky radiation.
  noon <- which(obs$timestamp == utc("2024-01-15 17:00"))
  obs$solar_radiation[noon] <- 1050
  # Nearly saturated nights: the reference ET becomes negative.
  obs$relative_humidity[obs$solar_radiation == 0] <- 99
  xr <- ef_station_table(x$stations, obs, prov_hourly)
  et <- run_hourly(xr, night_cloudiness = "fixed", night_ratio = 0.7)
  s <- et$series
  expect_gt(s$solar_radiation[noon], s$clear_sky_radiation[noon])
  expect_identical(flag_index(et, "EF_WS_RS_RSO_LIMITED", "series"), noon)
  expect_identical(s$cloudiness[noon], 1)
  neg <- which(s$et_ref < 0)
  expect_gt(length(neg), 0L)
  expect_identical(flag_index(et, "EF_WS_ETR_NEGATIVE", "series"), neg)
  # Kept, not truncated.
  expect_true(all(s$et_ref[neg] < 0))
  for (f in et$flags) {
    expect_s3_class(f, "earthflux_flag")
    expect_true(f$target %in% c("series", "etr_inst", "etr_24"))
    n_target <- nrow(et[[f$target]])
    expect_identical(f$n_total, n_target)
  }
  expect_identical(
    sort(et$provenance$flags_evaluated_by_target$series),
    sort(c("EF_INPUT_NA", "EF_WS_RS_RSO_LIMITED", "EF_WS_ETR_NEGATIVE"))
  )
  expect_identical(et$provenance$flags_evaluated_by_target$etr_inst,
                   character(0))
  expect_identical(et$provenance$flags_evaluated_by_target$etr_24,
                   "EF_WS_INCOMPLETE_DAY")
  expect_setequal(et$provenance$flags_evaluated,
                  unlist(et$provenance$flags_evaluated_by_target))
})

test_that("the result object follows the contract", {
  x <- hourly_series()
  et <- run_hourly(x, night_cloudiness = "fixed", night_ratio = 0.7)
  expect_identical(class(et), c("earthflux_station_ref_et", "list"))
  expect_named(et, c("series", "etr_inst", "etr_24", "reference", "timestep",
                     "standard", "flags", "provenance"))
  s <- et$series
  expect_identical(nrow(s), nrow(x$observations))
  expect_identical(s$station_id, x$observations$station_id)
  expect_identical(s$timestamp, x$observations$timestamp)
  expect_identical(as.numeric(s$target_time),
                   as.numeric(x$observations$timestamp) - 1800)
  expect_named(s, c("station_id", "timestamp", "target_time", "date",
                    "extraterrestrial_radiation", "clear_sky_radiation",
                    "solar_radiation", "vapour_pressure",
                    "vapour_pressure_deficit", "wind_speed_2m", "cloudiness",
                    "cloudiness_source", "daytime", "net_radiation",
                    "soil_heat_flux", "et_ref"))
  # W m-2 to MJ m-2 h-1.
  expect_equal(s$solar_radiation, x$observations$solar_radiation * 0.0036,
               tolerance = 1e-12)
  p <- et$provenance
  expect_identical(p$fun, "ef_station_ref_et")
  expect_identical(p$choices$humidity, "relative_humidity")
  expect_identical(p$choices$daytime_rule, "ra_positive")
  expect_identical(p$choices$day_completeness, "all_periods")
  expect_null(p$choices$utc_offset)
  expect_match(p$choices$daily_method, "^D1")
  expect_true(p$qc$run_by_ef_station_ref_et)
  expect_identical(p$station_table$crs, "EPSG:4326")
  expect_type(p$earthflux_version, "character")
  # A QC result is used as is (its policy is kept).
  qc <- ef_station_qc(x, qc_policy = "exclude_warning")
  et_qc <- run_hourly(qc, night_cloudiness = "fixed", night_ratio = 0.7)
  expect_false(et_qc$provenance$qc$run_by_ef_station_ref_et)
  expect_identical(et_qc$provenance$qc$qc_policy, "exclude_warning")
  expect_identical(et_qc$series, et$series)
  expect_output(print(et), "<earthflux_station_ref_et>")
  expect_output(print(et), "Reference: alfalfa")
})

test_that("humidity sources give the same ETr for consistent inputs", {
  x <- hourly_series()
  obs <- x$observations
  ea <- ef_ea_rh(obs$air_temperature, obs$relative_humidity)
  obs$vapour_pressure <- ea
  obs$dewpoint_temperature <- ef_dewpoint(ea)
  xh <- ef_station_table(x$stations, obs, prov_hourly)
  base <- list(xh, reference = "alfalfa", timestep = "hourly",
               standard = "asce", day_definition = "utc",
               day_completeness = "all_periods", daytime_rule = "ra_positive",
               night_cloudiness = "fixed", night_ratio = 0.7)
  out <- lapply(c("relative_humidity", "vapour_pressure",
                  "dewpoint_temperature"), function(h) {
    do.call(ef_station_ref_et, c(base, humidity = h))$series$et_ref
  })
  expect_equal(out[[2]], out[[1]], tolerance = 1e-12)
  # FAO-56 annex 3 Eq. 3-11 is an approximate inverse of Eq. 11 (case V17:
  # 15 degC -> 14.9926 degC): agreement to about 1e-4 only.
  expect_equal(out[[3]], out[[1]], tolerance = 1e-3)
})

# Errors -----------------------------------------------------------------------

test_that("choices are explicit and checked", {
  x <- hourly_series(n = 24L)
  full <- list(x = x, reference = "alfalfa", timestep = "hourly",
               standard = "asce", humidity = "relative_humidity",
               day_definition = "utc", day_completeness = "all_periods",
               daytime_rule = "ra_positive", night_cloudiness = "fixed",
               night_ratio = 0.7)
  call_with <- function(...) {
    args <- utils::modifyList(full, list(...))
    do.call(ef_station_ref_et, args)
  }
  without <- function(name) {
    args <- full
    args[[name]] <- NULL
    do.call(ef_station_ref_et, args)
  }
  expect_s3_class(call_with(), "earthflux_station_ref_et")
  for (nm in c("reference", "timestep", "standard", "humidity",
               "day_definition", "day_completeness", "daytime_rule",
               "night_cloudiness", "night_ratio")) {
    expect_error(without(nm), class = "earthflux_missing_input")
  }
  expect_error(call_with(reference = "maize"),
               class = "earthflux_unknown_method")
  expect_error(call_with(standard = "fao56"),
               class = "earthflux_undefined_reference")
  expect_error(call_with(humidity = "rh"), class = "earthflux_unknown_method")
  expect_error(call_with(day_completeness = "fill"),
               class = "earthflux_unknown_method")
  expect_error(call_with(daytime_rule = "beta"),
               class = "earthflux_unknown_method")
  expect_error(call_with(night_ratio = 1.2), class = "earthflux_domain_error")
  # ASCE-EWRI: Rs/Rso in [0.3, 1] (Eqs. 18 and 45, p. 36).
  expect_error(call_with(night_ratio = 0.2), class = "earthflux_domain_error")
  expect_s3_class(call_with(reference = "grass", standard = "fao56",
                            night_ratio = 0.2),
                  "earthflux_station_ref_et")
  expect_error(call_with(night_cloudiness = "low_sun"),
               class = "earthflux_input_error")
  expect_error(call_with(night_cloudiness = "before_sunset"),
               class = "earthflux_input_error")
  # Overpass and method go together.
  expect_error(call_with(inst_method = "O3"), class = "earthflux_input_error")
  expect_error(call_with(overpass = utc("2024-01-15 15:00")),
               class = "earthflux_missing_input")
  expect_error(call_with(overpass = utc("2024-01-15 15:00"),
                         inst_method = "O2"),
               class = "earthflux_unknown_method")
  expect_error(call_with(overpass = "2024-01-15 15:00", inst_method = "O1"),
               class = "earthflux_station_time_error")
  # Day definition and offsets.
  expect_error(call_with(day_definition = "local_standard"),
               class = "earthflux_missing_input")
  expect_error(call_with(utc_offset = -4), class = "earthflux_input_error")
  expect_error(call_with(day_definition = "local_standard",
                         utc_offset = c(-4, -3)),
               class = "earthflux_input_error")
  expect_error(call_with(day_definition = "local_standard", utc_offset = -15),
               class = "earthflux_domain_error")
  expect_error(call_with(day_definition = "local_standard",
                         utc_offset = c(ST09 = -4)),
               class = "earthflux_station_unknown_id")
  expect_error(call_with(dates = "2024-01-15"),
               class = "earthflux_input_error")
  # Input object.
  expect_error(do.call(ef_station_ref_et,
                       c(list(x$observations), full[-1L])),
               class = "earthflux_input_error")
})

test_that("the records must match the time step and have the columns", {
  x <- hourly_series(n = 24L)
  args <- list(reference = "grass", timestep = "daily", standard = "fao56",
               humidity = "relative_humidity", day_definition = "utc",
               day_completeness = "all_periods")
  expect_error(do.call(ef_station_ref_et, c(list(x), args)),
               class = "earthflux_station_time_error")
  # Hourly-only choices are refused for daily records.
  daily <- syn_single(tmax = 25, tmin = 10, rh_max = 90, rh_min = 40,
                      wind_speed = 2, solar_radiation = 250,
                      timestamp = utc("2024-01-15"),
                      provenance = syn_provenance(timestamp_convention = "start",
                                                  interval = 86400))
  expect_s3_class(do.call(ef_station_ref_et, c(list(daily), args)),
                  "earthflux_station_ref_et")
  expect_error(do.call(ef_station_ref_et,
                       c(list(daily), args, daytime_rule = "ra_positive")),
               class = "earthflux_input_error")
  expect_error(do.call(ef_station_ref_et,
                       c(list(daily), args,
                         list(overpass = utc("2024-01-15 15:00"),
                              inst_method = "O3"))),
               class = "earthflux_input_error")
  inst <- syn_single(air_temperature = 20, relative_humidity = 50,
                     wind_speed = 2, solar_radiation = 300,
                     provenance = syn_provenance(timestamp_convention = "instant"))
  expect_error(run_hourly(inst, night_cloudiness = "fixed"),
               class = "earthflux_station_time_error")
  # Missing column.
  no_wind <- syn_single(air_temperature = 20, relative_humidity = 50,
                        solar_radiation = 300)
  expect_error(run_hourly(no_wind, night_cloudiness = "fixed"),
               class = "earthflux_station_field_error")
  expect_error(run_hourly(x, night_cloudiness = "fixed",
                          humidity = "vapour_pressure"),
               class = "earthflux_station_field_error")
})

test_that("keep_all lets impossible values reach the core, which errors", {
  x <- hourly_series(n = 24L)
  obs <- x$observations
  obs$relative_humidity[10] <- -5
  xe <- ef_station_table(x$stations, obs, prov_hourly)
  expect_s3_class(run_hourly(xe, night_cloudiness = "fixed"),
                  "earthflux_station_ref_et")
  expect_error(run_hourly(ef_station_qc(xe, qc_policy = "keep_all"),
                          night_cloudiness = "fixed"),
               class = "earthflux_domain_error")
})
