# Tests for the physical constants (R/constants.R)
#
# The values are those of the specifications (dev/specs/radiation-components.md
# section 5, sensible-heat.md section 4.3, evapotranspiration.md sections
# 4.1 and 4.4). Exact identity is required: a constant is never recomputed.

test_that("constants have the specified values", {
  expect_identical(EF_KELVIN_OFFSET, 273.15)
  expect_identical(EF_STEFAN_BOLTZMANN, 5.670374419e-8)
  expect_identical(EF_VON_KARMAN, 0.41)
  expect_identical(EF_GRAVITY, 9.807)
  expect_identical(EF_SPECIFIC_HEAT_AIR, 1004)
  expect_identical(EF_WATER_DENSITY, 1000)
  expect_identical(EF_LATENT_HEAT_FAO56, 2.45e6)
  expect_identical(EF_SECONDS_PER_HOUR, 3600)
  expect_identical(EF_MM_PER_M, 1000)
})

test_that("the solar constant is FAO-56 Eq. 21 converted to W m-2", {
  # 0.0820 MJ m-2 min-1 * 1e6 J MJ-1 / 60 s min-1 = 1366.666... W m-2.
  expect_lt(abs(EF_SOLAR_CONSTANT - 1366.6666666666667), 1e-9)
})

test_that("constants are single finite positive numbers", {
  consts <- list(EF_KELVIN_OFFSET, EF_STEFAN_BOLTZMANN, EF_SOLAR_CONSTANT,
                 EF_VON_KARMAN, EF_GRAVITY, EF_SPECIFIC_HEAT_AIR,
                 EF_WATER_DENSITY, EF_LATENT_HEAT_FAO56, EF_SECONDS_PER_HOUR,
                 EF_MM_PER_M)
  for (x in consts) {
    expect_type(x, "double")
    expect_length(x, 1L)
    expect_true(is.finite(x) && x > 0)
  }
})

test_that("constants are internal", {
  exported <- getNamespaceExports("EarthFlux")
  expect_false(any(startsWith(exported, "EF_")))
})
