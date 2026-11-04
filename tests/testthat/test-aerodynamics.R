# Tests for momentum roughness, blending-height wind, friction velocity,
# aerodynamic resistance and Monin-Obukhov stability
#
# Specification: dev/specs/sensible-heat.md sections 5-7, 10 and 14.1, 14.4
# (case identifiers SH-14.x, dev/VALIDATION_PLAN.md section 1.3.0).
# Tolerances (section 14.7): values printed with 6 decimals are compared with
# half a unit of the last printed digit (5e-7); rah printed with 4 decimals
# with 5e-5. Values obtained by chaining rounded printed intermediates use a
# relative tolerance of 1e-6 (dev/VALIDATION_PLAN.md section 1.2).

# Full-precision wind at the blending height of the section 14.1 station
# (printed as 5.823611 m s-1); the chained values of section 14.4 were
# computed from it.
u_b_ref <- 3 * log(200 / 0.015) / log(2 / 0.015)

test_that("SH-14.1: wind speed at the blending height (neutral profile)", {
  u_b <- ef_blending_wind(3, height = 2, zom_station = 0.015, d_station = 0,
                          blending_height = 200)
  expect_lt(abs(u_b - 5.823611), 5e-7)
  # FAO-56 box 4 roughness and displacement for grass 0.12 m tall
  u_d <- ef_blending_wind(3, height = 2, zom_station = 0.01476,
                          d_station = 0.08, blending_height = 200)
  expect_lt(abs(u_d - 5.862843), 5e-7)
  # Proportional to the measured wind speed; calm gives zero
  u_v <- ef_blending_wind(c(0, 1.5, 3, 6), 2, 0.015, 0, 200)
  expect_equal(u_v, c(0, 0.5, 1, 2) * u_b, tolerance = 1e-12)
})

test_that("SH-14.1: neutral friction velocity and aerodynamic resistance", {
  zom <- c(0.06, 0.005, 0.02)
  u_star <- ef_ustar(u_b_ref, zom, blending_height = 200)
  expect_lt(max(abs(u_star - c(0.294349, 0.225324, 0.259239))), 5e-7)
  rah <- ef_rah(u_star, z1 = 0.1, z2 = 2)
  expect_lt(max(abs(rah - c(24.8231, 32.4273, 28.1850))), 5e-5)
  expect_equal(rah, log(20) / (EF_VON_KARMAN * u_star), tolerance = 1e-12)
})

test_that("momentum roughness methods give their equations", {
  expect_equal(ef_zom_lai(c(0, 0.5, 4)), c(0, 0.009, 0.072),
               tolerance = 1e-12)
  expect_equal(ef_zom_ndvi(0.6, 0.2, coef_1 = 0.5, coef_2 = -5),
               exp(0.5 * 0.6 / 0.2 - 5), tolerance = 1e-12)
  expect_equal(ef_zom_height(0.12), 0.01476, tolerance = 1e-12)
  # Perrier: hand-computed values (author's calculation) for LAI = 2,
  # h = 3 m: f = 0.25 (p = 2/3), f = 0.5 (p = 1), f = 0.6 (p = 1.2)
  z <- ef_zom_perrier(2, c(0.25, 0.5, 0.6), 3)
  p <- c(2 / 3, 1, 1.2)
  expect_equal(z, (1 - exp(-p)) * exp(-p) * 3, tolerance = 1e-12)
  expect_lt(abs(z[2] - 0.697632), 5e-7)
  # Continuity at f = 0.5 (both branches give p = 1)
  eps <- 1e-9
  expect_lt(abs(ef_zom_perrier(2, 0.5 - eps, 3) - ef_zom_perrier(2, 0.5, 3)),
            1e-8)
  # h = 0 or LAI = 0: z_om = 0 is returned unchanged (no minimum, SH-02)
  expect_identical(ef_zom_perrier(c(0, 2), 0.5, c(3, 0)), c(0, 0))
})

test_that("ef_zom() dispatches identically to the method functions", {
  lai <- c(0.5, 2, 4)
  expect_identical(ef_zom(lai = lai, method = "lai")$zom, ef_zom_lai(lai))
  expect_identical(
    ef_zom(ndvi = c(0.2, 0.7), albedo = 0.18, coef_1 = 0.4, coef_2 = -4.5,
           method = "ndvi")$zom,
    ef_zom_ndvi(c(0.2, 0.7), 0.18, 0.4, -4.5)
  )
  expect_identical(
    ef_zom(lai = lai, f_lai = 0.6, height = 3, method = "perrier")$zom,
    ef_zom_perrier(lai, 0.6, 3)
  )
  expect_identical(ef_zom(height = 0.12, method = "height")$zom,
                   ef_zom_height(0.12))
  # Arguments not used by the method are ignored
  expect_identical(ef_zom(lai = lai, height = 3, method = "lai")$zom,
                   ef_zom_lai(lai))
  # `method` is the last argument
  expect_identical(utils::tail(names(formals(ef_zom)), 1L), "method")
})

test_that("ef_zom() returns a classed object with flags and provenance", {
  z <- ef_zom(lai = matrix(c(1, NA, 3, 4), 2, 2), method = "lai")
  expect_s3_class(z, "earthflux_roughness_length")
  expect_named(z, c("zom", "method", "flags", "provenance"))
  expect_identical(dim(z$zom), c(2L, 2L))
  expect_identical(vapply(z$flags, `[[`, "", "code"), "EF_INPUT_NA")
  expect_identical(z$flags[[1]]$index, 2L)
  expect_identical(z$provenance$fun, "ef_zom_lai")
  expect_identical(z$provenance$status, "CANDIDATA")
  expect_identical(z$provenance$flags_evaluated, "EF_INPUT_NA")
  h <- ef_zom(height = 0.12, method = "height")
  expect_length(h$flags, 0L)
  expect_match(h$provenance$status, "VERIFICADA (FAO-56)", fixed = TRUE)
})

test_that("ef_zom() requires an explicit, known method and its arguments", {
  expect_error(ef_zom(lai = 2), class = "earthflux_missing_input")
  expect_error(ef_zom(lai = 2, method = "LAI"),
               class = "earthflux_unknown_method")
  expect_error(ef_zom(lai = 2, method = "short.crops"),
               class = "earthflux_unknown_method")
  expect_error(ef_zom(lai = 2, height = 3, method = "perrier"),
               class = "earthflux_missing_input")
  expect_error(ef_zom(ndvi = 0.5, method = "ndvi"),
               class = "earthflux_missing_input")
})

test_that("roughness inputs are validated", {
  expect_error(ef_zom_lai(-0.1), class = "earthflux_domain_error")
  expect_error(ef_zom_lai(Inf), class = "earthflux_domain_error")
  expect_error(ef_zom_lai(numeric(0)), class = "earthflux_input_error")
  expect_error(ef_zom_lai("2"), class = "earthflux_input_error")
  expect_error(ef_zom_ndvi(0.5, 0, 1, 1), class = "earthflux_domain_error")
  expect_error(ef_zom_ndvi(1.2, 0.2, 1, 1), class = "earthflux_domain_error")
  expect_error(ef_zom_perrier(2, 1.1, 3), class = "earthflux_domain_error")
  expect_error(ef_zom_perrier(2, 0.5, -1), class = "earthflux_domain_error")
  expect_error(ef_zom_height(-0.1), class = "earthflux_domain_error")
  expect_error(ef_zom_perrier(1:3, c(0.2, 0.4), 3),
               class = "earthflux_input_error")
})

test_that("NA propagates and dim is kept in the aerodynamic functions", {
  expect_identical(is.na(ef_zom_lai(c(1, NA))), c(FALSE, TRUE))
  expect_identical(is.na(ef_zom_perrier(2, c(NA, 0.3), 3)), c(TRUE, FALSE))
  u <- ef_ustar(c(5, NA, 5), c(0.05, 0.05, NA), 200)
  expect_identical(is.na(u), c(FALSE, TRUE, TRUE))
  expect_identical(is.na(ef_rah(c(0.3, NA), 0.1, 2)), c(FALSE, TRUE))
  m <- matrix(c(0.01, 0.05, 0.1, 0.2), 2, 2)
  um <- ef_ustar(5, m, 200)
  expect_identical(dim(um), c(2L, 2L))
  expect_identical(dim(ef_rah(um, 0.1, 2)), c(2L, 2L))
  expect_identical(dim(ef_zom_lai(m)), c(2L, 2L))
  expect_error(ef_ustar(matrix(5, 2, 2), matrix(0.05, 4, 1), 200),
               class = "earthflux_input_error")
})

test_that("wind, friction velocity and resistance inputs are validated", {
  expect_error(ef_blending_wind(-1, 2, 0.015, 0, 200),
               class = "earthflux_domain_error")
  expect_error(ef_blending_wind(3, 2, 0, 0, 200),
               class = "earthflux_domain_error")
  # Measurement height not above d + z_om (non-positive logarithm)
  expect_error(ef_blending_wind(3, 0.09, 0.015, 0.08, 200),
               class = "earthflux_domain_error")
  expect_error(ef_blending_wind(3, 2, 0.015, -0.1, 200),
               class = "earthflux_domain_error")
  expect_error(ef_blending_wind(3, 2, 0.015, 0), "blending_height")
  expect_error(ef_ustar(-1, 0.05, 200), class = "earthflux_domain_error")
  expect_error(ef_ustar(5, 0, 200), class = "earthflux_domain_error")
  expect_error(ef_ustar(5, 250, 200), class = "earthflux_domain_error")
  expect_error(ef_ustar(5, 0.05, 200, psi_m = Inf),
               class = "earthflux_domain_error")
  expect_error(ef_rah(0, 0.1, 2), class = "earthflux_domain_error")
  expect_error(ef_rah(0.3, 2, 0.1), class = "earthflux_domain_error")
  expect_error(ef_rah(0.3, 0, 2), class = "earthflux_domain_error")
})

test_that("friction velocity is NA where its denominator is not positive", {
  # log(200 / 0.5) - 7 < 0: u* undefined (very unstable, rough surface)
  u <- ef_ustar(5, c(0.5, 0.5), 200, psi_m = c(7, 1))
  expect_true(is.na(u[1]))
  expect_equal(u[2], EF_VON_KARMAN * 5 / (log(400) - 1), tolerance = 1e-12)
  # Calm: u* = 0 is returned and rejected by ef_rah()
  expect_identical(ef_ustar(0, 0.05, 200), 0)
})

test_that("SH-14.4: one unstable stability step at the hot anchor", {
  u_star0 <- ef_ustar(u_b_ref, 0.005, 200)
  obukhov <- ef_monin_obukhov_length(1.018513, u_star0, 316, 370, 1004)
  # Printed -2.484793 (the value is -2.4847936: last digit truncated in the
  # spec), so one unit of the last digit
  expect_lt(abs(obukhov - (-2.484793)), 1e-6)
  psi_m <- ef_psi_m(200, obukhov)
  psi_h2 <- ef_psi_h(2, obukhov)
  psi_h1 <- ef_psi_h(0.1, obukhov)
  expect_lt(abs(psi_m - 4.178174), 5e-7)
  expect_lt(abs(psi_h2 - 1.719595), 5e-7)
  expect_lt(abs(psi_h1 - 0.263944), 5e-7)
  u_star <- ef_ustar(u_b_ref, 0.005, 200, psi_m = psi_m)
  expect_lt(abs(u_star - 0.372002), 5e-7)
  rah <- ef_rah(u_star, 0.1, 2, psi_h_z2 = psi_h2, psi_h_z1 = psi_h1)
  # Printed reference chained from rounded intermediates: relative 1e-6
  expect_equal(rah, 10.097518, tolerance = 1e-6)
  # Unstable correction lowers rah with respect to the neutral value
  expect_lt(rah, 32.4273)
})

test_that("SH-14.4: stable branch and the two options of SH-11", {
  obukhov <- ef_monin_obukhov_length(1.098511, 0.294349, 300, -50, 1004)
  # The spec prints L = 41.9718 m and psi_m(200) = -23.825502; the inputs
  # give L = 41.971746 m and psi_m(200) = -23.825552 (rounding of the hand
  # calculation in the spec). Tolerance: one unit of the 4th decimal.
  expect_lt(abs(obukhov - 41.9718), 1e-4)
  # psi_m of the blending height with 2/L (water) or with z_b/L = 200/L
  # -0.2382555 printed as -0.238255 (truncated): one unit of the last digit
  expect_lt(abs(ef_psi_m(2, obukhov) - (-0.238255)), 1e-6)
  expect_lt(abs(ef_psi_m(200, obukhov) - (-23.825502)), 1e-4)
  expect_equal(ef_psi_m(200, obukhov), -5 * 200 / obukhov, tolerance = 1e-12)
  expect_lt(abs(ef_psi_h(0.1, obukhov) - (-0.011913)), 5e-7)
  expect_equal(ef_psi_h(2, obukhov), -5 * 2 / obukhov, tolerance = 1e-12)
})

test_that("SH-11: the stability step uses stable_psi_m_height only if L > 0", {
  zom <- 0.06
  args <- list(air_density = 1.098511, u_star = 0.294349,
               air_temperature = 300, h = -50, u_blend = u_b_ref,
               log_blend = log(200 / zom), cp = 1004)
  step2 <- do.call(h_stability_step, c(args, list(
    control = ef_h_control(2, 200, 0.1, 2)
  )))
  step200 <- do.call(h_stability_step, c(args, list(
    control = ef_h_control(200, 200, 0.1, 2)
  )))
  expect_lt(abs(step2$obukhov_length - 41.9718), 1e-4)
  expect_equal(step2$u_star,
               ef_ustar(u_b_ref, zom, 200, psi_m = ef_psi_m(2, 41.97174594)),
               tolerance = 1e-8)
  expect_equal(step200$u_star,
               ef_ustar(u_b_ref, zom, 200,
                        psi_m = ef_psi_m(200, 41.97174594)),
               tolerance = 1e-8)
  # Spec magnitudes: psi_m = -0.238255 versus -23.825502
  expect_lt(abs(step2$u_star -
                  EF_VON_KARMAN * u_b_ref / (log(200 / zom) + 0.238255)), 1e-6)
  expect_lt(abs(step200$u_star -
                  EF_VON_KARMAN * u_b_ref / (log(200 / zom) + 23.825502)),
            1e-6)
  expect_gt(step200$rah, 3 * step2$rah)
  # Unstable case: the option does not matter (psi_m always at z_b)
  args$h <- 370
  u2 <- do.call(h_stability_step, c(args, list(
    control = ef_h_control(2, 200, 0.1, 2)
  )))
  u200 <- do.call(h_stability_step, c(args, list(
    control = ef_h_control(200, 200, 0.1, 2)
  )))
  expect_identical(u2, u200)
})

test_that("neutral stability (H = 0) gives L = Inf and zero corrections", {
  obukhov <- ef_monin_obukhov_length(1.1, 0.3, 300, c(0, 100, -100), 1004)
  expect_identical(obukhov[1], Inf)
  expect_lt(obukhov[2], 0)
  expect_gt(obukhov[3], 0)
  expect_identical(ef_psi_m(c(200, 2), Inf), c(0, 0))
  expect_identical(ef_psi_h(c(2, 0.1), Inf), c(0, 0))
  expect_true(is.na(ef_psi_m(200, NA_real_)))
  step <- h_stability_step(1.1, 0.3, 300, 0, u_b_ref, log(200 / 0.05),
                           ef_h_control(2, 200, 0.1, 2), 1004)
  expect_equal(step$u_star, ef_ustar(u_b_ref, 0.05, 200), tolerance = 1e-14)
  expect_equal(step$rah, ef_rah(step$u_star, 0.1, 2), tolerance = 1e-14)
})

test_that("an undefined friction velocity in the stability step is NA", {
  # L of about -0.15 m over z_om = 100 m: log(2) - psi_m(200) < 0
  step <- h_stability_step(1, 0.1, 300, 500, 5, log(200 / 100),
                           ef_h_control(2, 200, 0.1, 2), 1004)
  expect_true(is.na(step$u_star))
  expect_true(is.na(step$rah))
})
