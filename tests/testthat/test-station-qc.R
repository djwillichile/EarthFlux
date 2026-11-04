# Tests for the quality control of the station table (R/prep-qc.R)
#
# Specification: dev/specs/weather-forcing.md section 3 (principles 3.1,
# tests 3.2) and dev/specs/flags.md (EF_WS_ codes of section 4.2, severity
# `critical` and the policy "exclude_critical" of section 5.3, record scope
# and the equivalence of `$qc` with the flag records, section 6.1, test R16,
# FL-13). Synthetic data: tests/testthat/helper-stations.R.

# Helpers ----------------------------------------------------------------------

qc_rows <- function(x, code, variable = NULL) {
  sel <- x$qc$flag_code == code
  if (!is.null(variable)) {
    sel <- sel & x$qc$variable == variable
  }
  x$qc$row[sel]
}

flag_of <- function(x, code) {
  codes <- vapply(x$flags, `[[`, "", "code")
  if (!code %in% codes) {
    return(NULL)
  }
  x$flags[[match(code, codes)]]
}

station_codes <- c("EF_WS_OUT_OF_DOMAIN", "EF_WS_TMIN_GT_TMAX",
                   "EF_WS_RH_GT100", "EF_WS_TDEW_GT_TAIR", "EF_WS_TIME_GAP",
                   "EF_WS_TIME_IRREGULAR", "EF_WS_HEIGHT_MISSING",
                   "EF_WS_HEIGHT_NONSTANDARD")

# Registry ---------------------------------------------------------------------

test_that("the station QC codes are registered with their class", {
  rows <- ef_flags_stations()
  reg <- ef_flag_registry()
  expect_identical(names(rows), names(reg))
  expect_identical(rows$code, station_codes)
  expect_true(all(station_codes %in% reg$code))
  expect_true(all(rows$stage == "WS"))
  expect_true(all(rows$scope == "record"))
  expect_true(all(is.na(rows$bit)))
  # Class III: critical, with the error counterpart of the numeric core.
  crit <- rows$code %in% c("EF_WS_OUT_OF_DOMAIN", "EF_WS_TMIN_GT_TMAX")
  expect_true(all(rows$severity[crit] == "critical"))
  expect_true(all(rows$error_class[crit] == "earthflux_domain_error"))
  expect_true(all(is.na(rows$error_class[!crit])))
  expect_identical(rows$severity[rows$code == "EF_WS_RH_GT100"], "info")
  expect_true(all(rows$severity[!crit & rows$code != "EF_WS_RH_GT100"] ==
                    "warning"))
})

test_that("class II station codes and not-evaluated codes stay unregistered", {
  reg <- ef_flag_registry()
  ne <- station_qc_not_evaluated()
  class_ii <- ne$code[grepl("^class II", ne$reason)]
  expect_length(class_ii, 13L)
  expect_identical(intersect(class_ii, reg$code), character(0))
  # Class I codes not raised by this module are not registered here either.
  expect_false(any(c("EF_WS_RS_GT_RA", "EF_WS_INCOMPLETE_DAY") %in%
                     ef_flags_stations()$code))
})

# Principle: mark, never modify ------------------------------------------------

test_that("ef_station_qc() never modifies the stations or the observations", {
  obs <- syn_observations()
  obs$relative_humidity[2L] <- -5
  obs$air_temperature[4L] <- -300
  st <- syn_table(observations = obs)
  qc <- ef_station_qc(st)
  expect_identical(qc$observations, st$observations)
  expect_identical(qc$stations, st$stations)
  expect_identical(qc$observations$relative_humidity[2L], -5)
  expect_s3_class(qc, "earthflux_station_qc")
  expect_s3_class(qc, "earthflux_station_table")
  expect_identical(class(qc), c("earthflux_station_qc",
                                "earthflux_station_table", "list"))
  expect_named(qc, c("stations", "observations", "provenance", "qc",
                     "qc_status", "flags"))
  expect_invisible(ef_validate_stations(qc))
})

test_that("clean data raise no flag but record the codes evaluated", {
  qc <- ef_station_qc(syn_table())
  expect_identical(qc$flags, list())
  expect_identical(nrow(qc$qc), 0L)
  expect_identical(qc$provenance$flags_evaluated,
                   c("EF_WS_OUT_OF_DOMAIN", "EF_WS_RH_GT100",
                     "EF_WS_TDEW_GT_TAIR", "EF_WS_TIME_GAP",
                     "EF_WS_TIME_IRREGULAR", "EF_WS_HEIGHT_MISSING",
                     "EF_WS_HEIGHT_NONSTANDARD"))
  # No daily fields: EF_WS_TMIN_GT_TMAX is not evaluated.
  expect_false("EF_WS_TMIN_GT_TMAX" %in% qc$provenance$flags_evaluated)
  for (v in c("air_temperature", "relative_humidity", "wind_speed")) {
    expect_true(all(qc$qc_status[[v]] == "ok"))
  }
})

# QC-01a: physical domain (class III) ------------------------------------------

test_that("EF_WS_OUT_OF_DOMAIN flags impossible values, not their bounds", {
  qc <- ef_station_qc(syn_single(
    relative_humidity = c(-0.1, 0, 50),
    wind_speed = c(0, -0.1, 2),
    air_temperature = c(20, -273.14, -273.15),
    dewpoint_temperature = c(-300, 5, -273.15),
    air_pressure = c(0, 0.1, 95),
    vapour_pressure = c(0, -0.01, 1)
  ))
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "relative_humidity"), 1L)
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "wind_speed"), 2L)
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "air_temperature"), 3L)
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "dewpoint_temperature"),
                   c(1L, 3L))
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "air_pressure"), 1L)
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "vapour_pressure"), 2L)
  sel <- qc$qc$flag_code == "EF_WS_OUT_OF_DOMAIN"
  expect_true(all(qc$qc$severity[sel] == "critical"))
  expect_true(all(qc$qc$test_id[sel] == "QC-01a"))
  t_row <- sel & qc$qc$variable == "air_temperature"
  expect_identical(qc$qc$value[t_row], -273.15)
  expect_identical(qc$qc$threshold[t_row], -273.15)
  f <- flag_of(qc, "EF_WS_OUT_OF_DOMAIN")
  expect_identical(f$index, 1:3)
  expect_identical(f$severity, "critical")
  expect_identical(f$scope, "record")
  expect_identical(f$n_total, 3L)
})

test_that("EF_WS_OUT_OF_DOMAIN covers the daily fields; NA is not flagged", {
  qc <- ef_station_qc(syn_single(
    tmax = c(30, -274, NA), tmin = c(-280, 10, 12),
    rh_max = c(90, NA, -1), rh_min = c(40, 35, 30),
    provenance = syn_provenance(interval = 86400)
  ))
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "tmax"), 2L)
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "tmin"), 1L)
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "rh_max"), 3L)
  expect_identical(qc_rows(qc, "EF_WS_OUT_OF_DOMAIN", "rh_min"), integer(0))
})

# QC-03: tmin > tmax (class III) -----------------------------------------------

test_that("EF_WS_TMIN_GT_TMAX flags both variables of the record", {
  qc <- ef_station_qc(syn_single(
    tmax = c(25, 10, 12, NA), tmin = c(12, 15, 12, 30),
    timestamp = as.POSIXct("2024-01-15", tz = "UTC") + 86400 * 0:3,
    provenance = syn_provenance(timestamp_convention = "start",
                                interval = 86400)
  ))
  expect_identical(qc_rows(qc, "EF_WS_TMIN_GT_TMAX", "tmin"), 2L)
  expect_identical(qc_rows(qc, "EF_WS_TMIN_GT_TMAX", "tmax"), 2L)
  rows <- qc$qc[qc$qc$flag_code == "EF_WS_TMIN_GT_TMAX", ]
  expect_identical(rows$value, c(15, 10))
  expect_identical(rows$threshold, c(10, 15))
  expect_identical(flag_of(qc, "EF_WS_TMIN_GT_TMAX")$severity, "critical")
  expect_identical(as.character(qc$qc_status$tmin),
                   c("ok", "excluded", "ok", "ok"))
  expect_identical(as.character(qc$qc_status$tmax),
                   c("ok", "excluded", "ok", "ok"))
})

# QC-02: relative humidity above 100 % (class I) -------------------------------

test_that("EF_WS_RH_GT100 flags values above 100 % as info", {
  qc <- ef_station_qc(syn_single(relative_humidity = c(100, 100.5, 102)))
  expect_identical(qc_rows(qc, "EF_WS_RH_GT100"), 2:3)
  f <- flag_of(qc, "EF_WS_RH_GT100")
  expect_identical(f$severity, "info")
  expect_identical(qc$qc$threshold[qc$qc$flag_code == "EF_WS_RH_GT100"],
                   c(100, 100))
  # Info does not change the status.
  expect_true(all(qc$qc_status$relative_humidity == "ok"))
  qc_ok <- ef_station_qc(syn_single(relative_humidity = c(99, 100, NA)))
  expect_null(flag_of(qc_ok, "EF_WS_RH_GT100"))
  expect_true("EF_WS_RH_GT100" %in% qc_ok$provenance$flags_evaluated)
})

# QC-04: dew point above air temperature (class I) -----------------------------

test_that("EF_WS_TDEW_GT_TAIR flags Tdew > T without tolerance", {
  qc <- ef_station_qc(syn_single(air_temperature = c(20, 20, 20, NA),
                                 dewpoint_temperature = c(20, 20.1, 15, 30)))
  expect_identical(qc_rows(qc, "EF_WS_TDEW_GT_TAIR", "dewpoint_temperature"),
                   2L)
  expect_identical(qc_rows(qc, "EF_WS_TDEW_GT_TAIR", "air_temperature"), 2L)
  f <- flag_of(qc, "EF_WS_TDEW_GT_TAIR")
  expect_identical(f$severity, "warning")
  expect_identical(f$index, 2L)
  expect_identical(as.character(qc$qc_status$air_temperature),
                   c("ok", "warning", "ok", "ok"))
  # Not evaluated without both variables.
  qc_t <- ef_station_qc(syn_single(air_temperature = 20))
  expect_false("EF_WS_TDEW_GT_TAIR" %in% qc_t$provenance$flags_evaluated)
})

# QC-09: time integrity (class I) ----------------------------------------------

test_that("EF_WS_TIME_GAP and EF_WS_TIME_IRREGULAR follow the declared step", {
  t0 <- as.POSIXct("2024-01-15 13:00", tz = "UTC")
  # Steps after the first record: 3600 (regular), 7200 (gap of one step),
  # 1800 (irregular), 5400 (irregular), 10800 (gap of two steps).
  times <- t0 + c(0, 3600, 10800, 12600, 18000, 28800)
  qc <- ef_station_qc(syn_single(air_temperature = rep(20, 6),
                                 timestamp = times))
  expect_identical(qc_rows(qc, "EF_WS_TIME_GAP"), c(3L, 6L))
  expect_identical(qc_rows(qc, "EF_WS_TIME_IRREGULAR"), c(4L, 5L))
  gap <- qc$qc[qc$qc$flag_code == "EF_WS_TIME_GAP", ]
  expect_identical(gap$variable, c("timestamp", "timestamp"))
  expect_identical(gap$value, c(7200, 10800))
  expect_identical(gap$threshold, c(3600, 3600))
  # The time flags concern every variable of the record.
  expect_identical(as.character(qc$qc_status$air_temperature),
                   c("ok", "ok", "warning", "warning", "warning", "warning"))
})

test_that("time steps are evaluated per station and in time order", {
  obs <- syn_observations()[c(6, 2, 4, 1, 5, 3), ]
  qc <- ef_station_qc(syn_table(observations = obs))
  expect_null(flag_of(qc, "EF_WS_TIME_GAP"))
  expect_null(flag_of(qc, "EF_WS_TIME_IRREGULAR"))
  obs2 <- syn_observations()[-2, ]
  qc2 <- ef_station_qc(syn_table(observations = obs2))
  # Row 2 of obs2 is ST01 at 15:00, after the missing 14:00 record.
  expect_identical(qc_rows(qc2, "EF_WS_TIME_GAP"), 2L)
  expect_identical(qc2$qc$station_id, "ST01")
})

# QC-11: measurement heights (class I) -----------------------------------------

test_that("EF_WS_HEIGHT_MISSING flags values measured at an unknown height", {
  stations <- syn_stations()
  stations$height_wind[2L] <- NA
  obs <- syn_observations()
  obs$wind_speed[5L] <- NA
  qc <- ef_station_qc(syn_table(stations = stations, observations = obs))
  expect_identical(qc_rows(qc, "EF_WS_HEIGHT_MISSING", "wind_speed"),
                   c(4L, 6L))
  expect_identical(unique(qc$qc$variable[qc$qc$flag_code ==
                                           "EF_WS_HEIGHT_MISSING"]),
                   "wind_speed")
  expect_identical(flag_of(qc, "EF_WS_HEIGHT_MISSING")$severity, "warning")
  expect_identical(as.character(qc$qc_status$wind_speed),
                   c("ok", "ok", "ok", "warning", "ok", "warning"))
  expect_identical(as.character(qc$qc_status$air_temperature),
                   rep("ok", 6L))
})

test_that("EF_WS_HEIGHT_NONSTANDARD flags temperature and humidity off 2 m", {
  stations <- syn_stations()
  stations$height_temp_rh <- c(2, 1.5)
  qc <- ef_station_qc(syn_table(stations = stations))
  sel <- qc$qc$flag_code == "EF_WS_HEIGHT_NONSTANDARD"
  expect_identical(sort(unique(qc$qc$row[sel])), 4:6)
  expect_setequal(unique(qc$qc$variable[sel]),
                  c("air_temperature", "relative_humidity",
                    "dewpoint_temperature"))
  expect_true(all(qc$qc$value[sel] == 1.5))
  expect_true(all(qc$qc$threshold[sel] == 2))
  # The anemometer at 10 m (ST02) is not flagged: wind is converted to 2 m
  # by FAO-56 Eq. 47, not compared with the standard height.
  expect_false(any(qc$qc$variable[sel] == "wind_speed"))
  stations$height_temp_rh <- c(2, NA)
  qc_na <- ef_station_qc(syn_table(stations = stations))
  expect_null(flag_of(qc_na, "EF_WS_HEIGHT_NONSTANDARD"))
  expect_identical(qc_rows(qc_na, "EF_WS_HEIGHT_MISSING", "air_temperature"),
                   4:6)
})

# Equivalence of the audit table and the flag records (R16, FL-13) -------------

test_that("$qc and the record flags are equivalent views", {
  stations <- syn_stations()
  stations$height_temp_rh <- c(2, 1.5)
  stations$height_wind[1L] <- NA
  obs <- syn_observations()
  obs$relative_humidity[c(1, 5)] <- c(-2, 103)
  obs$dewpoint_temperature[2L] <- 40
  obs <- obs[-3, ]
  qc <- ef_station_qc(syn_table(stations = stations, observations = obs))
  reg <- ef_flag_registry()
  expect_true(all(qc$qc$flag_code %in% reg$code))
  expect_identical(qc$qc$severity,
                   reg$severity[match(qc$qc$flag_code, reg$code)])
  codes <- vapply(qc$flags, `[[`, "", "code")
  expect_setequal(codes, unique(qc$qc$flag_code))
  for (f in qc$flags) {
    expect_identical(f$index, sort(unique(qc$qc$row[qc$qc$flag_code ==
                                                      f$code])))
    expect_identical(f$n_total, nrow(qc$observations))
    expect_identical(f$scope, "record")
  }
  expect_identical(qc$qc$station_id, qc$observations$station_id[qc$qc$row])
  expect_identical(as.numeric(qc$qc$timestamp),
                   as.numeric(qc$observations$timestamp[qc$qc$row]))
  expect_true(all(is.na(qc$qc$parameters)))

  # A tampered object fails validation.
  bad <- qc
  bad$qc <- bad$qc[-1, ]
  expect_error(ef_validate_stations(bad),
               class = "earthflux_station_field_error")
  bad <- qc
  bad$qc$flag_code[1L] <- "EF_WS_STEP"
  expect_error(ef_validate_stations(bad),
               class = "earthflux_station_field_error")
  bad <- qc
  bad$qc_status <- bad$qc_status[-1, ]
  expect_error(ef_validate_stations(bad),
               class = "earthflux_station_field_error")
})

# Policies and provenance ------------------------------------------------------

test_that("qc_policy sets the status; the default excludes critical values", {
  obs <- syn_observations()
  obs$relative_humidity[2L] <- -5
  obs$dewpoint_temperature[3L] <- 30
  st <- syn_table(observations = obs)

  crit <- ef_station_qc(st)
  expect_identical(crit$provenance$qc$qc_policy, "exclude_critical")
  expect_identical(as.character(crit$qc_status$relative_humidity),
                   c("ok", "excluded", "ok", "ok", "ok", "ok"))
  expect_identical(as.character(crit$qc_status$dewpoint_temperature),
                   c("ok", "ok", "warning", "ok", "ok", "ok"))
  expect_identical(levels(crit$qc_status$wind_speed),
                   c("ok", "warning", "excluded"))

  warn <- ef_station_qc(st, qc_policy = "exclude_warning")
  expect_identical(as.character(warn$qc_status$relative_humidity),
                   c("ok", "excluded", "ok", "ok", "ok", "ok"))
  expect_identical(as.character(warn$qc_status$dewpoint_temperature),
                   c("ok", "ok", "excluded", "ok", "ok", "ok"))

  keep <- ef_station_qc(st, qc_policy = "keep_all")
  expect_false(any(unlist(lapply(keep$qc_status[-(1:2)], as.character)) ==
                     "excluded"))
  expect_identical(as.character(keep$qc_status$relative_humidity),
                   c("ok", "warning", "ok", "ok", "ok", "ok"))
  # Same flags whatever the policy.
  expect_identical(keep$qc, crit$qc)
  expect_identical(keep$flags, crit$flags)

  expect_error(ef_station_qc(st, qc_policy = "exclude_error"),
               class = "earthflux_unknown_method")
  expect_error(ef_station_qc(st, qc_policy = NULL),
               class = "earthflux_missing_input")
  expect_error(ef_station_qc(st, qc_policy = "exclude"),
               class = "earthflux_unknown_method")
})

test_that("exclusions are counted in the provenance", {
  obs <- syn_observations()
  obs$relative_humidity[2L] <- -5
  obs$wind_speed[c(1, 4)] <- c(-1, -2)
  qc <- ef_station_qc(syn_table(observations = obs))
  p <- qc$provenance
  expect_identical(p$flags_evaluated, p$flags$evaluated)
  expect_identical(p$flags$registry$code, p$flags_evaluated)
  expect_identical(p$flags$policies$qc_policy, "exclude_critical")
  expect_identical(p$qc$excluded_severities, "critical")
  expect_identical(p$qc$excluded_codes, "EF_WS_OUT_OF_DOMAIN")
  counts <- p$qc$counts
  expect_identical(counts$n_records[counts$code == "EF_WS_OUT_OF_DOMAIN"],
                   3L)
  expect_identical(counts$n_values[counts$code == "EF_WS_OUT_OF_DOMAIN"], 3L)
  expect_identical(counts$n_total, rep(6L, nrow(counts)))
  ex <- p$qc$excluded
  expect_identical(ex$n_excluded[ex$variable == "relative_humidity"], 1L)
  expect_identical(ex$n_excluded[ex$variable == "wind_speed"], 2L)
  expect_identical(ex$n_excluded[ex$variable == "air_temperature"], 0L)
  expect_identical(ex$n_ok + ex$n_warning + ex$n_excluded,
                   rep(6L, nrow(ex)))
  expect_identical(p$flags$counts$n_flagged, counts$n_records)
  expect_identical(p$operations$step, c("ef_station_table", "ef_station_qc"))
  expect_match(p$operations$detail[2L], "3 value(s) excluded", fixed = TRUE)
  ne <- p$qc$not_evaluated
  expect_named(ne, c("code", "test_id", "reason"))
  expect_true(all(c("EF_WS_IMPLAUSIBLE", "EF_WS_PERSISTENCE",
                    "EF_WS_RS_GT_RA") %in% ne$code))
})

test_that("ef_station_qc() can be rerun and checks its input", {
  obs <- syn_observations()
  obs$relative_humidity[2L] <- 101
  qc <- ef_station_qc(syn_table(observations = obs))
  qc2 <- ef_station_qc(qc, qc_policy = "keep_all")
  expect_identical(qc2$qc, qc$qc)
  expect_identical(qc2$flags, qc$flags)
  expect_identical(qc2$provenance$operations$step,
                   c("ef_station_table", "ef_station_qc", "ef_station_qc"))
  expect_error(ef_station_qc(syn_observations()),
               class = "earthflux_input_error")
})

test_that("print summarises the quality control", {
  obs <- syn_observations()
  obs$relative_humidity[2L] <- -5
  qc <- ef_station_qc(syn_table(observations = obs))
  expect_output(print(qc), "<earthflux_station_qc>")
  expect_output(print(qc), "policy \"exclude_critical\"")
  expect_output(print(qc), "EF_WS_OUT_OF_DOMAIN")
  expect_output(print(qc), "Values excluded: 1")
  expect_output(print(ef_station_qc(syn_table())), "no flags")
  capture.output(res <- withVisible(print(qc)))
  expect_false(res$visible)
})
