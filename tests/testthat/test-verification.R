# Verification of the METRIC core against the SEBAL Idaho manual
#
# Source: Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
# (2002). SEBAL: Surface Energy Balance Algorithms for Land. Idaho
# implementation. Advanced training and users manual, Version 1.0
# ("the manual"); and Allen et al. (2012), IAHS Publ. 352, pp. 73-75, for
# the Perrier roughness. Register: dev/VERIFICATION.md.
#
# Each test writes the equation of the manual literally (page and equation
# number in the test name) with hand-chosen inputs and compares it with the
# EarthFlux function. Expected values computed by hand (or by an independent
# script, said so) are printed with 7 significant digits and compared with
# half a unit of the last digit; identities between the literal equation and
# the function use a relative tolerance of 1e-12.

# Sensible heat: SH-11 and the heights -----------------------------------------

test_that("SEBAL-Idaho p. 33, Eq. 38: stable psi_m(200 m) = -5 (2 / L)", {
  # Hand value of DECISIONS.md P0-2: L = 41.97 m gives -5 * 2 / 41.97
  expect_lt(abs(ef_psi_m(2, 41.97) - (-0.2382654)), 5e-8)
  expect_equal(ef_psi_m(2, 41.97), -5 * (2 / 41.97), tolerance = 1e-12)
  # The default of ef_h_control() evaluates the stable branch at 2 m
  ctrl <- ef_h_control()
  expect_identical(ctrl$stable_psi_m_height, 2)
  step <- h_stability_step(air_density = 1.1, u_star = 0.3, lst = 300,
                           h = -50, u_blend = 6, log_blend = log(200 / 0.06),
                           control = ctrl, cp = 1004)
  l <- step$obukhov_length
  expect_gt(l, 0)
  expect_equal(step$u_star,
               6 * 0.41 / (log(200 / 0.06) - (-5 * (2 / l))),
               tolerance = 1e-12)
  # Eqs. 39a-39b: psi_h(2 m) = -5 (2 / L), psi_h(0.1 m) = -5 (0.1 / L)
  expect_equal(step$rah,
               (log(2 / 0.1) - (-5 * (2 / l)) + (-5 * (0.1 / l))) /
                 (step$u_star * 0.41),
               tolerance = 1e-12)
})

test_that("SEBAL-Idaho pp. 26, 30: heights z_b = 200 m, z1 = 0.1 m, z2 = 2 m", {
  ctrl <- ef_h_control()
  expect_identical(ctrl[c("blending_height", "z1", "z2")],
                   list(blending_height = 200, z1 = 0.1, z2 = 2))
  expect_identical(formals(ef_ustar)$blending_height, 200)
  expect_identical(formals(ef_blending_wind)$blending_height, 200)
  expect_identical(c(formals(ef_rah)$z1, formals(ef_rah)$z2), c(0.1, 2))
})

test_that("SEBAL-Idaho p. 32, Eqs. 35 and 37: unstable corrections", {
  l <- -2.484034
  x <- function(z) (1 - 16 * z / l)^0.25
  psi_m_200 <- 2 * log((1 + x(200)) / 2) + log((1 + x(200)^2) / 2) -
    2 * atan(x(200)) + 0.5 * pi
  expect_equal(ef_psi_m(200, l), psi_m_200, tolerance = 1e-12)
  expect_equal(ef_psi_h(2, l), 2 * log((1 + x(2)^2) / 2), tolerance = 1e-12)
  expect_equal(ef_psi_h(0.1, l), 2 * log((1 + x(0.1)^2) / 2),
               tolerance = 1e-12)
})

test_that("SEBAL-Idaho p. 32, Eq. 34: Monin-Obukhov length with Ts, g = 9.81", {
  # rho = 1.02 kg m-3, u* = 0.25 m s-1, Ts = 316 K, H = 370 W m-2
  l <- ef_monin_obukhov_length(1.02, 0.25, 316, 370, 1004)
  expect_equal(l, -1.02 * 1004 * 0.25^3 * 316 / (0.41 * 9.81 * 370),
               tolerance = 1e-12)
  expect_identical(EF_GRAVITY, 9.81)
  # The calibration evaluates L at the surface temperature of the anchor
  anchors <- data.frame(
    type = c("cold", "hot"), lst = c(300, 316), elevation = c(500, 700),
    zom = c(0.06, 0.005), rn = c(600, 480), g = c(50, 110),
    le_target = c(520, 0), u_blend = 5.823611,
    pressure = ef_air_pressure(c(500, 700))
  )
  # One iteration only (a convergence warning is expected)
  expect_warning(
    cal <- ef_calibrate_h(anchors, ef_h_control(maxit = 1L, tol = 1e-12),
                          lapse_rate = 0.00649, datum_elevation = 500),
    class = "earthflux_convergence_warning"
  )
  tr <- cal$trace
  u0 <- 0.41 * 5.823611 / log(200 / 0.005)
  h_hot <- 370 # the first H equals the target at the anchor
  expect_equal(tr$obukhov_length_hot,
               -tr$air_density_hot * 1004 * u0^3 * 316 /
                 (0.41 * 9.81 * h_hot),
               tolerance = 1e-9)
})

test_that("SEBAL-Idaho pp. 26-27, 33-34: wind, friction velocity and rah", {
  # Eq. 28 and 29: station surface h = 0.3 m, z_om,w = 0.12 h = 0.036 m,
  # u_x = 3 m s-1 at 2 m: u_200 = 6.438932 m s-1 (hand value)
  u200 <- ef_blending_wind(3, 2, zom_station = 0.12 * 0.3, d_station = 0)
  expect_lt(abs(u200 - 6.438932), 5e-7)
  # Eq. 30 (neutral) and Eq. 40 (with psi_m)
  expect_equal(ef_ustar(u200, 0.02), 0.41 * u200 / log(200 / 0.02),
               tolerance = 1e-12)
  expect_equal(ef_ustar(u200, 0.02, psi_m = 1.5),
               u200 * 0.41 / (log(200 / 0.02) - 1.5), tolerance = 1e-12)
  # Eq. 26 (neutral) and Eq. 41
  expect_equal(ef_rah(0.3), log(2 / 0.1) / (0.3 * 0.41), tolerance = 1e-12)
  expect_equal(ef_rah(0.3, psi_h_z2 = 1.2, psi_h_z1 = 0.2),
               (log(2 / 0.1) - 1.2 + 0.2) / (0.3 * 0.41), tolerance = 1e-12)
})

test_that("SEBAL-Idaho pp. 27-28, Eqs. 31a-31b, and IAHS 2012: roughness", {
  # Eq. 31a; with h = 0.15 LAI (appendix 2) it equals 0.12 h (Eq. 28)
  expect_equal(ef_zom_lai(c(0.5, 2, 4)), 0.018 * c(0.5, 2, 4),
               tolerance = 1e-12)
  expect_equal(ef_zom_lai(2), 0.12 * (0.15 * 2), tolerance = 1e-12)
  # Eq. 31b with fitted coefficients a and b
  expect_equal(ef_zom_ndvi(0.6, 0.2, coef_1 = 0.5, coef_2 = -5),
               exp(0.5 * 0.6 / 0.2 + -5), tolerance = 1e-12)
  # Allen et al. (2012), p. 73: a = 2 f for f >= 0.5; f = 0.6, LAI = 2,
  # h = 3 m: z_om = 0.6314288 m (hand value)
  expect_lt(abs(ef_zom_perrier(2, 0.6, 3) - 0.6314288), 5e-8)
  # a = (2 (1 - f))^-1 for f < 0.5
  a <- 1 / (2 * (1 - 0.3))
  expect_equal(ef_zom_perrier(2, 0.3, 3),
               (1 - exp(-a * 2 / 2)) * exp(-a * 2 / 2) * 3, tolerance = 1e-12)
})

test_that("SEBAL-Idaho pp. 25, 30-31: H, dT at the anchors and dT line", {
  # Eq. 25 with c_p = 1004 J kg-1 K-1 (the default)
  expect_equal(ef_sensible_heat(1.1, 5, 30), 1.1 * 1004 * 5 / 30,
               tolerance = 1e-12)
  expect_identical(EF_SPECIFIC_HEAT_AIR, 1004)
  # Eq. 33 and Eq. 32 (manual notation dT = b + a Ts: slope a, intercept b;
  # EarthFlux: intercept a, slope b)
  dt_cold <- 30 * 24.8 / (1.1 * 1004)
  dt_hot <- 370 * 32.4 / (1.02 * 1004)
  co <- ef_dt_coef(317.3, 300, dt_hot, dt_cold)
  slope <- (dt_hot - dt_cold) / (317.3 - 300)
  expect_equal(co$b, slope, tolerance = 1e-12)
  expect_equal(co$a + co$b * c(300, 317.3), c(dt_cold, dt_hot),
               tolerance = 1e-12)
  # Appendix 12, Eq. 12-7: Ts_dem = Ts + 0.0065 dz
  expect_equal(ef_ts_datum(300, 1200, 500, 0.0065), 300 + 0.0065 * 700,
               tolerance = 1e-12)
})

# Radiation -----------------------------------------------------------------------

test_that("SEBAL-Idaho pp. 10 and 14, Eq. 2: net radiation", {
  # (1 - 0.2) 800 + 320 - 450 - (1 - 0.98) 320 = 503.6 W m-2 (hand value)
  expect_equal(ef_net_radiation(800, 0.2, 320, 450, 0.98), 503.6,
               tolerance = 1e-12)
})

test_that("SEBAL-Idaho pp. 18-19, 22-23, Eqs. 11-12, 20-23: components", {
  # Eq. 11: tau_sw = 0.75 + 2e-5 z
  tau <- ef_tau_sw(elevation = 1000, method = "elevation")
  expect_equal(tau$total, 0.77, tolerance = 1e-12)
  expect_identical(tau$provenance$status, "VERIFICADA (SEBAL-Idaho 2002)")
  # Eq. 22: e_a = 0.85 (-ln tau_sw)^0.09 = 0.7533055 for tau_sw = 0.77
  ea <- ef_atm_emissivity(0.77)
  expect_lt(abs(ea - 0.7533055), 5e-8)
  # Eqs. 21 and 23 with T_cold = 300 K; Eq. 20 with e0 = 0.97, Ts = 310 K.
  # The manual uses sigma = 5.67e-8 (EarthFlux: exact CODATA value)
  expect_equal(ef_rl_in(300, ea), ea * EF_STEFAN_BOLTZMANN * 300^4,
               tolerance = 1e-12)
  expect_lt(abs(ef_rl_in(300, ea) / (ea * 5.67e-8 * 300^4) - 1), 7e-5)
  expect_lt(abs(ef_rl_out(310, 0.97) / (0.97 * 5.67e-8 * 310^4) - 1), 7e-5)
  # Eq. 12 on flat terrain: Gsc cos(theta) dr tau_sw (Gsc = 1367 rounded in
  # the manual; FAO-56 value 1366.67 in EarthFlux)
  rs <- ef_rs_in(cos_zenith = 0.8, cos_incidence = 0.8, inv_distance = 1.03,
                 tau_beam = 0.6, tau_diffuse = 0.17, slope = 0,
                 method = "modelled")
  expect_equal(rs$total, EF_SOLAR_CONSTANT * 0.8 * 1.03 * 0.77,
               tolerance = 1e-12)
  expect_lt(abs(rs$total / (1367 * 0.8 * 1.03 * 0.77) - 1), 2.5e-4)
  expect_match(rs$provenance$status, "VERIFICADA (SEBAL-Idaho 2002)",
               fixed = TRUE)
})

test_that("SEBAL-Idaho p. 20, Eq. 16b: broadband emissivity from LAI", {
  lai <- c(0, 1, 2.5, 3, 5)
  expected <- ifelse(lai < 3, 0.95 + 0.01 * lai, 0.98)
  expect_equal(modis_broadband_emissivity(lai = lai, method = "lai_empirical"),
               expected, tolerance = 1e-12)
})

test_that("SEBAL-Idaho p. 24, Eq. 24: G / Rn of Bastiaanssen (2000)", {
  # Literal form Ts / alpha (0.0038 alpha + 0.0074 alpha^2)(1 - 0.98 NDVI^4)
  # with Ts in degrees C: 30 degrees C, alpha = 0.2, NDVI = 0.5,
  # Rn = 500 W m-2 gives G = 74.349 W m-2 (hand value)
  g <- ef_g_bastiaanssen(rn = 500, lst = 303.15, albedo = 0.2, ndvi = 0.5)
  expect_equal(g, 74.349, tolerance = 1e-12)
  literal <- function(tc, a, ndvi) {
    tc / a * (0.0038 * a + 0.0074 * a^2) * (1 - 0.98 * ndvi^4)
  }
  alb <- c(0.1, 0.25, 0.4)
  expect_equal(ef_g_bastiaanssen(1, 293.15 + c(5, 15, 25), alb, 0.3),
               literal(c(25, 35, 45), alb, 0.3), tolerance = 1e-12)
  out <- ef_g(rn = 500, lst = 303.15, albedo = 0.2, ndvi = 0.5,
              method = "bastiaanssen")
  expect_identical(out$provenance$status, "VERIFICADA (SEBAL-Idaho 2002)")
})

# Anchors, ET and the daily extrapolation ------------------------------------------

test_that("SEBAL-Idaho pp. 30-31: boundary conditions of the anchors", {
  anchors <- ef_anchors(cold = 1, hot = 2, lst = c(300, 321, 310),
                        ndvi = c(0.85, 0.10, 0.40),
                        albedo = c(0.20, 0.25, 0.20), aggregate = "none")
  b <- ef_anchor_conditions(
    anchors, rn = c(700, 500, 600), g = c(100, 120, 110), etr_inst = 0.8,
    lambda = 2.45e6, etrf_cold = 1.05, etrf_hot = 0, reference = "alfalfa",
    source = "Waters et al. (2002), pp. 30-31", status = "VERIFICADA"
  )
  cp <- b$calibration_points
  # H_cold = Rn - G - 1.05 lambda ETr, with lambda ETr = ETr lambda / 3600
  # (Eq. 42 inverted, ETr in mm h-1); H_hot = Rn - G (ET_hot = 0)
  expect_equal(cp$h_target[cp$type == "cold"],
               700 - 100 - 1.05 * 0.8 * 2.45e6 / 3600, tolerance = 1e-12)
  expect_equal(cp$h_target[cp$type == "hot"], 500 - 120, tolerance = 1e-12)
})

test_that("SEBAL-Idaho pp. 34-35, Eqs. 1, 42-44: LE, ET_inst, ETrF, ET_24", {
  le <- ef_latent_heat(rn = 600, g = 60, h = 50) # Eq. 1
  expect_identical(le, 490)
  et_inst <- ef_et_inst(le, 2.45e6)
  expect_equal(et_inst, 3600 * le / 2.45e6, tolerance = 1e-12) # Eq. 42
  etrf <- ef_etrf(et_inst, 0.8, reference = "alfalfa")
  expect_equal(etrf, et_inst / 0.8, tolerance = 1e-12) # Eq. 43
  eta <- ef_et_daily(etrf, etr_24 = 8.5, reference = "alfalfa",
                     method = "etrf")
  expect_equal(eta$eta_24, etrf * 8.5, tolerance = 1e-12) # Eq. 44
  expect_identical(eta$provenance$status, "VERIFICADA (SEBAL-Idaho 2002)")
})
