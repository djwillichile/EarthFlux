# Tests for the shared physical quantities (R/shared-physics.R)
#
# Specifications: dev/specs/radiation-components.md section 6.2 and
# weather-forcing.md section 4.1 (air pressure); evapotranspiration.md
# section 4 (latent heat of vaporization).

# ef_air_pressure() ---------------------------------------------------------
#
# Reference values (radiation-components.md section 6.2; weather-forcing.md
# section 4.1) are hand-computed and published to 4 decimals, so the
# tolerance is half a unit in the last digit, 5e-5 kPa. z = 0 is exact.

test_that("air pressure matches the hand-computed FAO-56 Eq. 7 values", {
  expect_identical(ef_air_pressure(0), 101.3)
  p <- ef_air_pressure(c(1000, 1800, 3000))
  expect_lt(max(abs(p - c(90.0246, 81.7558, 70.5150))), 5e-5)
})

test_that("air pressure decreases monotonically with elevation", {
  z <- seq(-400, 6000, by = 100)
  p <- ef_air_pressure(z)
  expect_true(all(diff(p) < 0))
  expect_gt(ef_air_pressure(-400), 101.3)
})

test_that("air pressure keeps dim, accepts integers and propagates NA", {
  m <- matrix(c(0, 1000, NA, NaN), 2, 2)
  p <- ef_air_pressure(m)
  expect_identical(dim(p), c(2L, 2L))
  expect_identical(p[1, 1], 101.3)
  expect_true(is.na(p[1, 2]) && is.na(p[2, 2]))
  expect_identical(ef_air_pressure(0L), 101.3)
  expect_silent(ef_air_pressure(c(NA, 500)))
})

test_that("air pressure rejects invalid input with classed errors", {
  expect_error(ef_air_pressure(50000), class = "earthflux_domain_error")
  expect_error(ef_air_pressure(293 / 0.0065), class = "earthflux_domain_error")
  expect_error(ef_air_pressure(Inf), class = "earthflux_domain_error")
  expect_error(ef_air_pressure(-Inf), class = "earthflux_domain_error")
  expect_error(ef_air_pressure(numeric(0)), class = "earthflux_input_error")
  expect_error(ef_air_pressure("1000"), class = "earthflux_input_error")
  expect_error(ef_air_pressure(NA), class = "earthflux_input_error")
  cnd <- tryCatch(ef_air_pressure(c(1e5, 0, 6e4)), error = identity)
  expect_identical(cnd$call, quote(ef_air_pressure(c(1e5, 0, 6e4))))
  expect_match(conditionMessage(cnd), "`elevation`", fixed = TRUE)
  expect_match(conditionMessage(cnd), "found 2 value(s)", fixed = TRUE)
})

# ef_latent_heat_vaporization() ---------------------------------------------
#
# Case B of evapotranspiration.md section 10: lambda(20 C) = 2453780 and
# lambda(30 C) = 2430170 J kg-1. The tolerance is relative,
# sqrt(.Machine$double.eps), because T - 273.15 is not exact in double
# precision (section 11.1).

rel_tol <- sqrt(.Machine$double.eps)

test_that("the constant method returns the FAO-56 value", {
  expect_identical(ef_latent_heat_vaporization(method = "constant"), 2.45e6)
  # temperature is ignored by the constant method
  expect_identical(
    ef_latent_heat_vaporization(c(280, 300), method = "constant"),
    2.45e6
  )
})

test_that("the fao56 method matches case B", {
  lambda <- ef_latent_heat_vaporization(c(293.15, 303.15), method = "fao56")
  expected <- c(2453780, 2430170)
  expect_lt(max(abs(lambda / expected - 1)), rel_tol)
})

test_that("the fao56 method keeps dim and propagates NA", {
  temp <- matrix(c(293.15, NA, 303.15, NaN), 2, 2)
  lambda <- ef_latent_heat_vaporization(temp, method = "fao56")
  expect_identical(dim(lambda), c(2L, 2L))
  expect_true(is.na(lambda[2, 1]) && is.na(lambda[2, 2]))
  expect_silent(ef_latent_heat_vaporization(c(NA, 300), method = "fao56"))
})

test_that("method has no default and must match exactly", {
  expect_error(ef_latent_heat_vaporization(300),
               class = "earthflux_missing_input")
  expect_error(ef_latent_heat_vaporization(300, method = "FAO56"),
               class = "earthflux_unknown_method")
  expect_error(ef_latent_heat_vaporization(300, method = "const"),
               class = "earthflux_unknown_method")
  # The surface-temperature form is CANDIDATA and not available.
  cnd <- tryCatch(ef_latent_heat_vaporization(300, method = "metric"),
                  error = identity)
  expect_s3_class(cnd, "earthflux_unknown_method")
  expect_s3_class(cnd, "earthflux_input_error")
  expect_match(conditionMessage(cnd), "CANDIDATA", fixed = TRUE)
})

test_that("the fao56 method validates temperature", {
  expect_error(ef_latent_heat_vaporization(method = "fao56"),
               class = "earthflux_missing_input")
  expect_error(ef_latent_heat_vaporization(0, method = "fao56"),
               class = "earthflux_domain_error")
  expect_error(ef_latent_heat_vaporization(-5, method = "fao56"),
               class = "earthflux_domain_error")
  expect_error(ef_latent_heat_vaporization(Inf, method = "fao56"),
               class = "earthflux_domain_error")
  expect_error(ef_latent_heat_vaporization("300", method = "fao56"),
               class = "earthflux_input_error")
  expect_error(ef_latent_heat_vaporization(numeric(0), method = "fao56"),
               class = "earthflux_input_error")
  cnd <- tryCatch(ef_latent_heat_vaporization(-1, method = "fao56"),
                  error = identity)
  expect_identical(cnd$call,
                   quote(ef_latent_heat_vaporization(-1, method = "fao56")))
})

test_that("the lambda unit guard accepts J kg-1 and rejects other units", {
  expect_invisible(check_latent_heat_units(c(2.45e6, NA, 2.43e6), "lambda"))
  expect_invisible(check_latent_heat_units(c(1e6, 1e7), "lambda"))
  expect_error(check_latent_heat_units(2.45, "lambda"),
               class = "earthflux_domain_error")
  expect_error(check_latent_heat_units(2450, "lambda"),
               class = "earthflux_domain_error")
  expect_error(check_latent_heat_units(Inf, "lambda"),
               class = "earthflux_domain_error")
  expect_error(check_latent_heat_units(c(2.45, 2.45e6, 2450), "lambda"),
               "found 2 value(s)", fixed = TRUE)
  lambda <- ef_latent_heat_vaporization(c(273.15, 323.15), method = "fao56")
  expect_invisible(check_latent_heat_units(lambda, "lambda"))
})
