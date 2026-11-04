# Tests for the derived meteorological variables (R/forcing-derived.R):
# ef_psychrometric(), ef_es(), ef_es_slope(), the actual vapour pressure
# family (ef_ea_dewpoint(), ef_ea_rh(), ef_ea_tmin(), ef_ea_daily()),
# ef_dewpoint(), ef_wind_2m(), ef_ra_daily(), ef_ra_period(), ef_rso() and
# the internal ef_sunset_hour_angle() and ef_daylight_hours().
#
# Specification: dev/specs/weather-forcing.md section 4 and the FAO-56
# verification cases V1-V9, V12, V13 and V17 of section 8.1; errata of
# section 8.3 are not reproduced (e.g. example 8 calls dr "rad"; example 7
# writes the latitudes correctly and is used as published).
#
# Tolerances (dev/VALIDATION_PLAN.md section 1.2):
# - published FAO-56 values are rounded: they are compared with a tolerance
#   of half a unit of the last published digit (`half_unit()`), which also
#   covers the rounding of the published inputs (the examples give full
#   inputs here, so no further propagation is needed unless stated);
# - the "propio" values of section 8.1 are full-precision recomputations
#   printed with 4-6 significant digits: they are compared with half a unit
#   of their last printed digit; regressions on values recomputed here at
#   full precision use a relative tolerance of 1e-6 (constants published
#   exactly, no iteration).

deg <- pi / 180
half_unit <- function(digits) 0.5 * 10^(-digits)

expect_within <- function(object, expected, tol, info = NULL) {
  expect_lte(max(abs(object - expected)), tol,
             label = paste("max. abs. difference", info))
}

# V1: pressure and psychrometric constant (FAO-56 example 2) ------------------

test_that("V1: psychrometric constant at 1800 m (FAO-56 example 2)", {
  p <- ef_air_pressure(1800)
  expect_within(p, 81.8, half_unit(1))
  gamma <- ef_psychrometric(p)
  expect_within(gamma, 0.054, half_unit(3))
  # Own value: 0.05437 (5 decimals printed).
  expect_within(gamma, 0.05437, half_unit(5))
  # Eq. 8 with the published coefficient: exact product.
  expect_equal(ef_psychrometric(81.8), 0.665e-3 * 81.8, tolerance = 1e-12)
})

test_that("ef_psychrometric() checks the domain and keeps NA and dim", {
  expect_error(ef_psychrometric(0), class = "earthflux_domain_error")
  expect_error(ef_psychrometric(-1), class = "earthflux_domain_error")
  expect_error(ef_psychrometric(Inf), class = "earthflux_domain_error")
  expect_error(ef_psychrometric("100"), class = "earthflux_input_error")
  expect_error(ef_psychrometric(numeric(0)), class = "earthflux_input_error")
  expect_identical(is.na(ef_psychrometric(c(100, NA))), c(FALSE, TRUE))
  m <- matrix(c(90, 95, 100, 101.3), 2)
  expect_identical(dim(ef_psychrometric(m)), c(2L, 2L))
})

# V2: saturation vapour pressure (FAO-56 example 3) ----------------------------

test_that("V2: saturation vapour pressure (FAO-56 example 3)", {
  e <- ef_es(c(24.5, 15))
  expect_within(e, c(3.075, 1.705), half_unit(3))
  # es of the day (Eq. 12) = 2.39 kPa; e°(Tmean = 19.75) = 2.30 kPa
  # (FAO-56 shows the underestimation with the mean temperature).
  expect_within(mean(e), 2.39, half_unit(2))
  expect_within(ef_es(19.75), 2.30, half_unit(2))
  expect_lt(ef_es(19.75), mean(e))
  # Own full-precision values.
  expect_within(e, c(3.0746, 1.7053), half_unit(4))
  expect_within(ef_es(19.75), 2.3023, half_unit(4))
})

test_that("ef_es() and ef_es_slope() check the domain, NA and dim", {
  expect_error(ef_es(-237.3), class = "earthflux_domain_error")
  expect_error(ef_es(-300), class = "earthflux_domain_error")
  expect_error(ef_es_slope(-237.3), class = "earthflux_domain_error")
  expect_error(ef_es(TRUE), class = "earthflux_input_error")
  expect_error(ef_es_slope(numeric(0)), class = "earthflux_input_error")
  expect_identical(is.na(ef_es(c(NA, 20))), c(TRUE, FALSE))
  expect_identical(is.na(ef_es_slope(c(20, NaN))), c(FALSE, TRUE))
  a <- array(c(5, 10, 15, 20, 25, 30), c(1, 2, 3))
  expect_identical(dim(ef_es(a)), c(1L, 2L, 3L))
  expect_identical(dim(ef_es_slope(a)), c(1L, 2L, 3L))
  # Sub-zero temperatures are valid.
  expect_gt(ef_es(-10), 0)
})

test_that("ef_es_slope() reproduces FAO-56 examples 18 and 19", {
  # Example 18: Tmean = 16.9 degC -> 0.122; example 19: 38 and 28 degC ->
  # 0.358 and 0.220 kPa degC-1.
  expect_within(ef_es_slope((21.5 + 12.3) / 2), 0.122, half_unit(3))
  expect_within(ef_es_slope(c(38, 28)), c(0.358, 0.220), half_unit(3))
  expect_within(ef_es_slope(c(38, 28)), c(0.35820, 0.22008), half_unit(5))
  # Eq. 13 written out.
  t <- 23.4
  expect_equal(ef_es_slope(t), 4098 * ef_es(t) / (t + 237.3)^2,
               tolerance = 1e-12)
})

# V3-V4: actual vapour pressure and deficit (FAO-56 examples 5 and 6) ----------

test_that("V3: actual vapour pressure from daily data (FAO-56 example 5)", {
  expect_within(ef_es(c(18, 25)), c(2.064, 3.168), half_unit(3))
  ea17 <- ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82, rh_min = 54,
                      method = "rhmax_rhmin")
  ea19 <- ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82, rh_min = 54,
                      method = "rhmean")
  expect_within(ea17, 1.70, half_unit(2))
  expect_within(ea19, 1.78, half_unit(2))
  expect_within(c(ea17, ea19), c(1.7015, 1.7788), half_unit(4))
  # Eq. 18 written out.
  expect_equal(ef_ea_daily(tmin = 18, rh_max = 82, method = "rhmax"),
               ef_es(18) * 0.82, tolerance = 1e-12)
})

test_that("V4: vapour pressure deficit (FAO-56 example 6)", {
  ea <- ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82, rh_min = 54,
                    method = "rhmax_rhmin")
  vpd <- mean(ef_es(c(25, 18))) - ea
  expect_within(vpd, 0.91, half_unit(2))
  expect_within(vpd, 0.9143, half_unit(4))
})

test_that("ef_ea_daily() requires an explicit method and its inputs", {
  expect_error(ef_ea_daily(18, 25, 82, 54),
               class = "earthflux_missing_input")
  expect_error(ef_ea_daily(18, 25, 82, 54, method = "mean"),
               class = "earthflux_unknown_method")
  expect_error(ef_ea_daily(tmin = 18, rh_max = 82, method = "rhmax_rhmin"),
               class = "earthflux_missing_input")
  expect_error(ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82,
                           method = "rhmean"),
               class = "earthflux_missing_input")
  expect_error(ef_ea_daily(tmax = 25, rh_max = 82, method = "rhmax"),
               class = "earthflux_missing_input")
})

test_that("ef_ea_daily() checks the domain, NA, recycling and dim", {
  expect_error(ef_ea_daily(26, 25, 82, 54, method = "rhmax_rhmin"),
               class = "earthflux_domain_error")
  expect_error(ef_ea_daily(18, 25, -1, 54, method = "rhmean"),
               class = "earthflux_domain_error")
  expect_error(ef_ea_daily(18, 25, 82, -5, method = "rhmax_rhmin"),
               class = "earthflux_domain_error")
  expect_error(ef_ea_daily(18, 25, c(80, 82, 84), c(50, 54),
                           method = "rhmax_rhmin"),
               class = "earthflux_input_error")
  # RH above 100 % is computed, not truncated (QC flags it upstream).
  expect_gt(ef_ea_daily(18, rh_max = 103, method = "rhmax"), ef_es(18))
  out <- ef_ea_daily(c(18, NA, 10), 25, 82, 54, method = "rhmax_rhmin")
  expect_identical(is.na(out), c(FALSE, TRUE, FALSE))
  m <- matrix(c(10, 12, 14, 16), 2)
  expect_identical(dim(ef_ea_daily(m, 25, 80, 50, method = "rhmean")),
                   c(2L, 2L))
  expect_error(ef_ea_daily(m, matrix(25, 1, 4), 80, 50,
                           method = "rhmean"),
               class = "earthflux_input_error")
})

test_that("ef_ea_rh() reproduces FAO-56 example 19", {
  # 38 degC, 52 % -> 3.445 kPa; 28 degC, 90 % -> 3.402 kPa.
  ea <- ef_ea_rh(c(38, 28), c(52, 90))
  expect_within(ea, c(3.445, 3.402), half_unit(3))
  expect_within(ea, c(3.4449, 3.4019), half_unit(4))
  expect_error(ef_ea_rh(20, -1), class = "earthflux_domain_error")
  expect_gt(ef_ea_rh(20, 102), ef_es(20))
  expect_identical(is.na(ef_ea_rh(20, c(50, NA))), c(FALSE, TRUE))
  m <- matrix(c(10, 20, 30, 40), 2)
  expect_identical(dim(ef_ea_rh(m, 60)), c(2L, 2L))
})

test_that("ef_ea_tmin() needs an explicit k0 (FAO-56 Eq. 48)", {
  expect_error(ef_ea_tmin(12), class = "earthflux_missing_input")
  expect_equal(ef_ea_tmin(12, k0 = 0), ef_es(12), tolerance = 1e-12)
  expect_equal(ef_ea_tmin(12, k0 = 2), ef_es(10), tolerance = 1e-12)
  expect_error(ef_ea_tmin(12, k0 = -1), class = "earthflux_domain_error")
  expect_error(ef_ea_tmin(-236, k0 = 2), class = "earthflux_domain_error")
  expect_identical(is.na(ef_ea_tmin(c(NA, 5), 0)), c(TRUE, FALSE))
  expect_identical(dim(ef_ea_tmin(matrix(1:4, 2), 2)), c(2L, 2L))
})

# V17: dew point ----------------------------------------------------------------

test_that("V17: dew point and FAO-56 annex 3 Eq. 3-11", {
  ea <- ef_ea_dewpoint(15)
  expect_equal(ea, ef_es(15), tolerance = 1e-12)
  expect_within(ea, 1.70535, half_unit(5))
  expect_within(ef_dewpoint(ea), 14.9926, half_unit(4))
  expect_error(ef_dewpoint(0), class = "earthflux_domain_error")
  expect_error(ef_dewpoint(-1), class = "earthflux_domain_error")
  expect_error(ef_dewpoint(exp(16.78)), class = "earthflux_domain_error")
  expect_error(ef_ea_dewpoint(-240), class = "earthflux_domain_error")
  expect_identical(is.na(ef_dewpoint(c(1, NA))), c(FALSE, TRUE))
  expect_identical(dim(ef_dewpoint(matrix(1:4, 2))), c(2L, 2L))
})

# V12-V13: wind at 2 m -----------------------------------------------------------

test_that("V12-V13: wind at 2 m (FAO-56 example 14, annex 2 table 2.9)", {
  expect_within(ef_wind_2m(1, c(2, 10)), c(1.000, 0.748), half_unit(3))
  expect_within(ef_wind_2m(1, c(2, 10)), c(1.00022, 0.74795), half_unit(5))
  u2 <- ef_wind_2m(3.2, 10)
  expect_within(u2, 2.4, half_unit(1))
  expect_within(u2, 2.3934, half_unit(4))
})

test_that("ef_wind_2m() checks the domain, NA, recycling and dim", {
  expect_error(ef_wind_2m(2, 0.09), class = "earthflux_domain_error")
  expect_error(ef_wind_2m(2, 6.42 / 67.8), class = "earthflux_domain_error")
  expect_error(ef_wind_2m(-1, 10), class = "earthflux_domain_error")
  expect_error(ef_wind_2m(c(1, 2), c(2, 3, 10)),
               class = "earthflux_input_error")
  expect_identical(is.na(ef_wind_2m(c(1, NA), 10)), c(FALSE, TRUE))
  expect_identical(ef_wind_2m(0, 10), 0)
  m <- matrix(1:4, 2)
  expect_identical(dim(ef_wind_2m(m, 10)), c(2L, 2L))
  expect_error(ef_wind_2m(m, matrix(10, 4, 1)),
               class = "earthflux_input_error")
})

# V6-V9: extraterrestrial radiation, daily ---------------------------------------

test_that("V6: latitude conversion to radians (FAO-56 example 7)", {
  expect_within(c(13 + 44 / 60, -(22 + 54 / 60)) * deg, c(0.240, -0.400),
                half_unit(3))
})

test_that("V7-V8: daily Ra and daylight hours (FAO-56 examples 8-9)", {
  lat <- -20 * deg
  doy <- 246
  delta <- ef_declination(doy)
  ws <- ef_sunset_hour_angle(lat, delta)
  expect_within(ef_inv_distance(doy), 0.985, half_unit(3))
  expect_within(delta, 0.120, half_unit(3))
  expect_within(ws, 1.527, half_unit(3))
  ra <- ef_ra_daily(lat, doy)
  expect_within(ra, 32.2, half_unit(1))
  expect_within(ra, 32.1940, half_unit(4))
  n <- ef_daylight_hours(lat, doy)
  expect_within(n, 11.7, half_unit(1))
  expect_within(n, 11.6656, half_unit(4))
})

test_that("V9: daily Ra at 22 degrees 54' S on 15 May (FAO-56 ex. 10-11)", {
  lat <- -(22 + 54 / 60) * deg
  expect_within(ef_ra_daily(lat, 135), 25.1, half_unit(1))
  expect_within(ef_ra_daily(lat, 135), 25.1110, half_unit(4))
  expect_within(ef_daylight_hours(lat, 135), 10.9, half_unit(1))
})

test_that("ef_ra_daily() handles polar day and night without NaN", {
  # 80 N at the June solstice: 24 h of sun (ws = pi); in December: no sun.
  expect_equal(ef_sunset_hour_angle(80 * deg, ef_declination(172)), pi)
  expect_identical(ef_sunset_hour_angle(80 * deg, ef_declination(355)), 0)
  expect_identical(ef_ra_daily(80 * deg, 355), 0)
  expect_gt(ef_ra_daily(80 * deg, 172), 0)
  expect_equal(ef_daylight_hours(80 * deg, 172), 24)
  expect_false(anyNA(ef_ra_daily(seq(-90, 90, 10) * deg, 172)))
})

test_that("ef_ra_daily() checks the domain, NA, recycling and dim", {
  expect_error(ef_ra_daily(-35, 10), class = "earthflux_domain_error")
  expect_error(ef_ra_daily(0, 367), class = "earthflux_domain_error")
  expect_error(ef_ra_daily(0, 10.5), class = "earthflux_input_error")
  expect_error(ef_ra_daily(c(0, 0.1), 1:3), class = "earthflux_input_error")
  expect_identical(is.na(ef_ra_daily(c(0, NA), 10)), c(FALSE, TRUE))
  expect_identical(is.na(ef_ra_daily(0, c(10, NA))), c(FALSE, TRUE))
  m <- matrix(c(-0.6, -0.3, 0, 0.3), 2)
  expect_identical(dim(ef_ra_daily(m, 100)), c(2L, 2L))
})

# V15-V16 (radiation part): extraterrestrial radiation per period -------------------

ndiaye_lat <- (16 + 13 / 60) * deg
ndiaye_lon <- -(16 + 15 / 60) * deg # east-positive

test_that("V15: Ra of 14:00-15:00 local standard time (FAO-56 example 19)", {
  # Lz = 15 degrees W: local standard time = UTC - 1 h, so 14:30 local is
  # 15:30 UTC.
  doy <- 274
  expect_within(ef_inv_distance(doy), 1.0001, half_unit(4))
  expect_within(ef_declination(doy), -0.0753, half_unit(4))
  expect_within(ef_equation_of_time(doy), 0.1889, half_unit(4))
  omega <- ef_hour_angle(doy, 15.5, ndiaye_lon)
  expect_within(omega, 0.682, half_unit(3))
  expect_within(omega + c(-1, 1) * pi / 24, c(0.5512, 0.8130),
                half_unit(4) + 1e-6)
  ra <- ef_ra_period(ndiaye_lat, ndiaye_lon, doy, utc_mid = 15.5,
                     period_hours = 1)
  expect_within(ra, 3.543, half_unit(3))
  expect_within(ra, 3.5434, half_unit(4))
})

test_that("V16: night period 02:00-03:00 has Ra = 0 (midpoint criterion)", {
  omega <- ef_hour_angle(274, 3.5, ndiaye_lon)
  expect_within(omega, -2.46, half_unit(2))
  expect_identical(ef_ra_period(ndiaye_lat, ndiaye_lon, 274, 3.5, 1), 0)
})

test_that("Eq. 31 with Lz, Lm in local time equals the UTC form", {
  # FAO-56 Eq. 31 as published (west-positive longitudes, local standard
  # time, 0.06667) versus the UTC form with east-positive longitude: the
  # only difference is 0.06667 versus 1/15 h per degree (decision WF-10),
  # 3.3e-6 h per degree, i.e. 1.25 * 3.3e-6 * pi / 12 rad here.
  sc <- ef_equation_of_time(274)
  t_local <- 14.5
  omega_fao <- pi / 12 * ((t_local + 0.06667 * (15 - 16.25) + sc) - 12)
  omega_utc <- ef_hour_angle(274, t_local + 15 / 15, ndiaye_lon)
  expect_within(omega_utc, omega_fao, 1.25 * 3.5e-6 * pi / 12)
  # FAO-56 0-360 degree west convention: a site at 1 degree E in the
  # Greenwich zone has Lz = 0 and Lm = 359, so Lz - Lm = -359 degrees; with
  # the exact 1/15 h per degree, the reduction modulo 24 h makes the
  # published form equal to the UTC form with east-positive longitude.
  sc_100 <- ef_equation_of_time(100)
  omega_360 <- pi / 12 * (((10.5 + (0 - 359) / 15 + sc_100) %% 24) - 12)
  expect_equal(ef_hour_angle(100, 10.5, 1 * deg), omega_360,
               tolerance = 1e-12)
  # Cairo (FAO-56: Lz = 330): 31.25 degrees E, local standard time UTC + 2.
  omega_cairo <- pi / 12 * ((13.5 + (330 - (360 - 31.25)) / 15 + sc_100) -
                              12)
  expect_equal(ef_hour_angle(100, 13.5 - 2, 31.25 * deg), omega_cairo,
               tolerance = 1e-12)
})

test_that("sum of hourly Ra approximates the daily Ra", {
  # Differences come only from the periods containing sunrise and sunset
  # (FAO-56 midpoint criterion, WF-10). Observed below 0.4 % for these
  # cases; tolerance 1 % relative (two partial periods out of 9-15 daylight
  # hours could not differ more at these latitudes).
  for (lat in c(-35, 0, 50)) {
    for (doy in c(15, 180)) {
      hourly <- ef_ra_period(lat * deg, 0, doy, 0:23 + 0.5, 1)
      expect_equal(sum(hourly), ef_ra_daily(lat * deg, doy),
                   tolerance = 0.01, info = paste(lat, doy))
    }
  }
})

test_that("ef_ra_period() checks the domain, NA, recycling and dim", {
  expect_error(ef_ra_period(0, 0, 100, 24, 1), class = "earthflux_domain_error")
  expect_error(ef_ra_period(0, 0, 100, 12, 0), class = "earthflux_domain_error")
  expect_error(ef_ra_period(0, 0, 100, 12, 2), class = "earthflux_domain_error")
  expect_error(ef_ra_period(0, 200, 100, 12, 1),
               class = "earthflux_domain_error")
  expect_error(ef_ra_period(0, 0, 100.5, 12, 1),
               class = "earthflux_input_error")
  out <- ef_ra_period(0, 0, 100, c(12, NA, 13), 1)
  expect_identical(is.na(out), c(FALSE, TRUE, FALSE))
  m <- matrix(c(10.5, 11.5, 12.5, 13.5), 2)
  expect_identical(dim(ef_ra_period(0.3, 0, 100, m, 1)), c(2L, 2L))
  # Half-hour periods: about half of the hourly value at noon.
  ra1 <- ef_ra_period(0, 0, 80, 12, 1)
  ra05 <- ef_ra_period(0, 0, 80, 12, 0.5)
  expect_equal(ra05 / ra1, 0.5, tolerance = 0.01)
})

# Clear-sky radiation ------------------------------------------------------------

test_that("ef_rso() follows FAO-56 Eq. 37 (cases V14-V15)", {
  expect_identical(ef_rso(30, 0), 0.75 * 30)
  # Example 18: Ra = 41.09 at 100 m -> 30.90; example 19: Ra = 3.543 at
  # 8 m -> 2.658.
  expect_within(ef_rso(41.09, 100), 30.90, half_unit(2))
  expect_within(ef_rso(3.543, 8), 2.658, half_unit(3))
  expect_error(ef_rso(-1, 100), class = "earthflux_domain_error")
  expect_error(ef_rso(10, Inf), class = "earthflux_domain_error")
  expect_identical(is.na(ef_rso(c(10, NA), 0)), c(FALSE, TRUE))
  expect_identical(dim(ef_rso(matrix(1:4, 2), 500)), c(2L, 2L))
  # Below sea level is allowed.
  expect_lt(ef_rso(10, -400), 7.5)
})
