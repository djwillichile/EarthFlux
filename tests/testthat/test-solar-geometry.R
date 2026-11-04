# Tests for the solar geometry (R/solar-geometry.R)
#
# Specification: dev/specs/radiation-components.md section 6.1 (cases
# G1-G6, planned tests); FAO-56 verification of the calendar terms in
# dev/specs/weather-forcing.md section 4.6 and dev/VALIDATION_PLAN.md
# (WF-V7, WF-V15, WF-V16).
#
# Tolerances:
# - algebraic identities and symmetries: 1e-12 (no rounded constants; a few
#   trigonometric evaluations of order 1, rounding error ~1e-15);
# - values printed in the specification with k decimals: half a unit of the
#   last printed digit;
# - FAO-56 published values (3-4 significant digits): half a unit of the
#   last published digit (dev/VALIDATION_PLAN.md 1.2). For the hour angle
#   the exact 1/15 h per degree replaces FAO-56's 0.06667, which changes the
#   solar time by 4.2e-6 h for 16.25 degrees, far below that tolerance.

deg <- pi / 180
tol_id <- 1e-12

test_that("G6: declination and inverse distance at calendar dates", {
  # Spec values: 0.4090 (4 decimals), -0.40898 (5), 1.0329951 and
  # 0.9670012 (7).
  expect_lt(abs(ef_declination(172) - 0.4090), 5e-5)
  expect_lt(abs(ef_declination(355) - (-0.40898)), 5e-6)
  expect_lt(abs(ef_inv_distance(1) - 1.0329951), 5e-8)
  expect_lt(abs(ef_inv_distance(182) - 0.9670012), 5e-8)
})

test_that("FAO-56 example 8 (J = 246): dr = 0.985, declination = 0.120", {
  expect_lt(abs(ef_inv_distance(246) - 0.985), 5e-4)
  expect_lt(abs(ef_declination(246) - 0.120), 5e-4)
})

test_that("FAO-56 example 19 (J = 274): dr, declination, Sc, hour angle", {
  expect_lt(abs(ef_inv_distance(274) - 1.0001), 5e-5)
  expect_lt(abs(ef_declination(274) - (-0.0753)), 5e-5)
  expect_lt(abs(ef_equation_of_time(274) - 0.1889), 5e-5)
  # N'Diaye, 16 deg 15' W; standard time of the zone Lz = 15 deg W, i.e.
  # UTC - 1 h. Mid-points 14:30 and 02:30 local standard time are 15:30 and
  # 03:30 UTC. Published: omega = 0.682 and -2.46 rad.
  lon <- -16.25 * deg
  expect_lt(abs(ef_hour_angle(274, 15.5, lon) - 0.682), 5e-4)
  expect_lt(abs(ef_hour_angle(274, 3.5, lon) - (-2.46)), 5e-3)
})

test_that("G5: equation of time and hour angle at J = 81", {
  # b = 0 -> Sc = -0.1255 h exactly (up to rounding).
  expect_lt(abs(ef_equation_of_time(81) - (-0.1255)), tol_id)
  # t_s = 16.8 - 4.8 - 0.1255 = 11.8745 h; omega = -0.0328558 rad
  # (7 significant digits printed).
  expect_lt(abs(ef_hour_angle(81, 16.8, -72 * deg) - (-0.0328558)), 5e-8)
})

test_that("hour angle equals FAO-56 Eq. 31 with west longitudes in 0-360", {
  # FAO-56 Eq. 31 with UTC times (Lz = 0) and Lm in degrees west, 0-360,
  # with the exact 1/15 (WF-10); reduction modulo 24 h makes both
  # conventions agree (dev/specs/weather-forcing.md 4.6, mandatory test).
  grid <- expand.grid(
    doy = c(1, 81, 172, 274, 366),
    utc = c(0, 3.25, 11.9, 17.5, 23.99),
    lon_deg = c(-179.5, -71.3, -16.25, 0, 45, 179.9)
  )
  lm <- (-grid$lon_deg) %% 360
  sc <- ef_equation_of_time(grid$doy)
  fao <- pi / 12 * (((grid$utc + (0 - lm) / 15 + sc) %% 24) - 12)
  ours <- ef_hour_angle(grid$doy, grid$utc, grid$lon_deg * deg)
  expect_lt(max(abs(ours - fao)), 1e-12)
  expect_true(all(ours >= -pi & ours < pi))
})

test_that("G1: north-facing slope normal to the sun gives cos = 1", {
  phi <- -35 * deg
  s <- 35 * deg
  expect_lt(abs(ef_cos_incidence(phi, 0, 0, s, 0) - 1), tol_id)
  # Same result as the aspect tends to 2 pi (gamma = +/- pi).
  expect_lt(abs(ef_cos_incidence(phi, 0, 0, s, 2 * pi - 1e-9) - 1), 1e-8)
})

test_that("G2-G3: south-facing slope and horizontal plane", {
  phi <- -35 * deg
  expect_lt(
    abs(ef_cos_incidence(phi, 0, 0, 35 * deg, pi) - 0.3420201), 5e-8
  )
  expect_lt(abs(ef_cos_incidence(phi, 0, 0, 35 * deg, pi) - cos(70 * deg)),
            tol_id)
  expect_lt(abs(ef_cos_incidence(phi, 0, 0, 0, 0) - 0.8191520), 5e-8)
})

test_that("G4: east/west symmetry over a grid of hour angles", {
  phi <- -35 * deg
  s <- 20 * deg
  expect_lt(
    abs(ef_cos_incidence(phi, 0.2, -30 * deg, s, pi / 2) - 0.7138573), 5e-8
  )
  w <- seq(-170, 170, by = 10) * deg
  east <- ef_cos_incidence(phi, 0.2, -w, s, pi / 2)
  west <- ef_cos_incidence(phi, 0.2, w, s, 3 * pi / 2)
  expect_lt(max(abs(east - west)), tol_id)
})

test_that("slope = 0 gives cos_incidence = cos_zenith on a grid", {
  grid <- expand.grid(
    doy = c(15, 100, 200, 300), utc = c(10, 14.5, 18),
    lat = c(-55, -35, -17, 0, 30) * deg, lon = c(-75, -70, 10) * deg
  )
  geo <- ef_solar_geometry(grid$doy, grid$utc, grid$lat, grid$lon,
                           slope = 0, aspect = 0)
  expect_lt(max(abs(geo$cos_incidence - geo$cos_zenith)), tol_id)
  direct <- sin(geo$declination) * sin(grid$lat) +
    cos(geo$declination) * cos(grid$lat) * cos(geo$hour_angle)
  expect_lt(max(abs(geo$cos_zenith - direct)), tol_id)
  # Default slope and aspect describe the horizontal plane.
  geo0 <- ef_solar_geometry(grid$doy, grid$utc, grid$lat, grid$lon)
  expect_identical(geo0, geo)
})

test_that("north-south reflection is a symmetry; aspect + pi is not", {
  grid <- expand.grid(
    phi = c(-50, -35, -10) * deg, dec = c(-0.3, 0, 0.35),
    w = c(-60, -10, 0, 25) * deg, s = c(10, 30, 60) * deg,
    a = c(0, 40, 90, 200, 300) * deg
  )
  ref <- ef_cos_incidence(grid$phi, grid$dec, grid$w, grid$s, grid$a)
  mirrored <- ef_cos_incidence(-grid$phi, -grid$dec, grid$w, grid$s,
                               (pi - grid$a) %% (2 * pi))
  expect_lt(max(abs(ref - mirrored)), tol_id)
  shifted <- ef_cos_incidence(-grid$phi, -grid$dec, grid$w, grid$s,
                              (grid$a + pi) %% (2 * pi))
  expect_gt(max(abs(ref - shifted)), 0.1)
})

test_that("at noon in the south: north slope > horizontal > south slope", {
  phi <- -35 * deg
  north <- ef_cos_incidence(phi, -0.2, 0, 20 * deg, 0)
  flat <- ef_cos_incidence(phi, -0.2, 0, 0, 0)
  south <- ef_cos_incidence(phi, -0.2, 0, 20 * deg, pi)
  expect_gt(north, flat)
  expect_gt(flat, south)
})

test_that("ef_solar_geometry assembles its auxiliaries", {
  geo <- ef_solar_geometry(81, 16.8, -35 * deg, -72 * deg, 20 * deg, 1)
  expect_named(geo, c("cos_zenith", "cos_incidence", "declination",
                      "hour_angle", "inv_distance"))
  expect_identical(geo$declination, ef_declination(81))
  expect_identical(geo$inv_distance, ef_inv_distance(81))
  expect_identical(geo$hour_angle, ef_hour_angle(81, 16.8, -72 * deg))
  expect_identical(
    geo$cos_incidence,
    ef_cos_incidence(-35 * deg, geo$declination, geo$hour_angle, 20 * deg, 1)
  )
})

test_that("outputs share the common length and dim of the inputs", {
  lat <- matrix(c(-20, -30, -40, -50), 2) * deg
  geo <- ef_solar_geometry(doy = 15, utc_hour = 15, lat = lat,
                           lon = -70 * deg)
  for (nm in names(geo)) {
    expect_identical(dim(geo[[nm]]), c(2L, 2L), info = nm)
  }
  expect_true(all(geo$declination == ef_declination(15)))
  geo_v <- ef_solar_geometry(doy = c(1, 200, 365), utc_hour = 15,
                             lat = -0.6, lon = -1.2)
  expect_true(all(lengths(geo_v) == 3L))
})

test_that("NA propagates only to the outputs that depend on it", {
  geo <- expect_silent(
    ef_solar_geometry(doy = 100, utc_hour = c(14, NA), lat = -0.6,
                      lon = -1.2)
  )
  expect_identical(is.na(geo$hour_angle), c(FALSE, TRUE))
  expect_identical(is.na(geo$cos_zenith), c(FALSE, TRUE))
  expect_false(anyNA(geo$declination))
  expect_false(anyNA(geo$inv_distance))
  # RC-16: an NA aspect propagates to cos_incidence even when slope = 0.
  geo_a <- ef_solar_geometry(100, 14, -0.6, -1.2, slope = 0,
                             aspect = NA_real_)
  expect_true(is.na(geo_a$cos_incidence))
  expect_false(is.na(geo_a$cos_zenith))
  expect_true(is.na(ef_declination(NA_real_)))
})

test_that("angles in degrees and out-of-domain values raise domain errors", {
  dom <- "earthflux_domain_error"
  expect_error(ef_solar_geometry(100, 14, -35, -1.2), class = dom)
  expect_error(ef_solar_geometry(100, 14, -35, -1.2), "`lat`")
  expect_error(ef_solar_geometry(100, 14, -0.6, -72), class = dom)
  expect_error(ef_solar_geometry(100, 24, -0.6, -1.2), class = dom)
  expect_error(ef_solar_geometry(100, -0.1, -0.6, -1.2), class = dom)
  expect_error(ef_solar_geometry(0, 14, -0.6, -1.2), class = dom)
  expect_error(ef_solar_geometry(367, 14, -0.6, -1.2), class = dom)
  expect_error(ef_solar_geometry(100, 14, -0.6, -1.2, slope = 2),
               class = dom)
  expect_error(ef_solar_geometry(100, 14, -0.6, -1.2, slope = -0.1),
               class = dom)
  expect_error(ef_solar_geometry(100, 14, -0.6, -1.2, slope = 0.1,
                                 aspect = 2 * pi), class = dom)
  expect_error(ef_solar_geometry(100, 14, -0.6, -1.2, slope = 0.1,
                                 aspect = 270), class = dom)
  expect_error(ef_solar_geometry(100, Inf, -0.6, -1.2), class = dom)
  expect_error(ef_cos_incidence(0, 0, 4, 0, 0), class = dom)
  # Bounds are accepted.
  expect_silent(ef_solar_geometry(c(1, 366), 0, pi / 2, pi, pi / 2, 0))
})

test_that("non-integer doy is an input error, not a domain error", {
  cnd <- tryCatch(ef_solar_geometry(100.5, 14, -0.6, -1.2),
                  error = identity)
  expect_s3_class(cnd, "earthflux_input_error")
  expect_false(inherits(cnd, "earthflux_domain_error"))
  expect_identical(cnd$call[[1]], as.name("ef_solar_geometry"))
  expect_error(ef_declination(1.5), class = "earthflux_input_error")
  expect_error(ef_inv_distance(c(1, 2.2)), "non-integer")
  expect_silent(ef_equation_of_time(100L))
})

test_that("type, length and dim errors are classed", {
  inp <- "earthflux_input_error"
  expect_error(ef_solar_geometry("100", 14, -0.6, -1.2), class = inp)
  expect_error(ef_solar_geometry(100, 14, TRUE, -1.2), class = inp)
  expect_error(ef_solar_geometry(100, c(14, 15), c(-0.6, -0.5, -0.4), -1.2),
               class = inp)
  expect_error(ef_solar_geometry(numeric(0), 14, -0.6, -1.2), class = inp)
  expect_error(
    ef_solar_geometry(100, 14, matrix(-0.6, 2, 2), matrix(-1.2, 1, 4)),
    class = inp
  )
  expect_error(ef_hour_angle(100, "14", 0), class = inp)
  expect_error(ef_cos_incidence(0, 0, 0, 0, factor(1)), class = inp)
})
