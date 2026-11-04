# Tests for ef_latent_heat()
#
# Specification: dev/specs/evapotranspiration.md (section 3; cases A1 and C1
# of section 10; test design in section 11.2).
#
# Tolerances (section 11.1): cases exact in decimal arithmetic use an
# absolute tolerance of 1e-12 W m-2 (two subtractions of magnitudes below
# 1e3: rounding error of order 1e-13); algebraic identities use a relative
# tolerance of sqrt(.Machine$double.eps) (dev/VALIDATION_PLAN.md section
# 1.2).

tol <- 1e-12
rel_tol <- sqrt(.Machine$double.eps)

test_that("case A1: LE = 600 - 60 - 50 = 490 W m-2", {
  le <- ef_latent_heat(rn = 600, g = 60, h = 50)
  expect_type(le, "double")
  expect_length(le, 1L)
  expect_lt(abs(le - 490), tol)
})

test_that("case C1: negative LE is returned unchanged and silently", {
  # H = 369 > Rn - G = 320: LE = -49 W m-2, never set to zero.
  expect_silent(le <- ef_latent_heat(rn = 400, g = 80, h = 369))
  expect_lt(abs(le - (-49)), tol)
})

test_that("identity: LE + G + H equals Rn on a grid with mixed signs", {
  grid <- expand.grid(
    rn = c(-80, 0, 150.5, 600, 820),
    g = c(-30, 0, 45.2, 120),
    h = c(-60, 0, 50, 369, 700)
  )
  le <- ef_latent_heat(rn = grid$rn, g = grid$g, h = grid$h)
  recon <- le + grid$g + grid$h
  scale <- pmax(abs(grid$rn), abs(grid$g), abs(grid$h), 1)
  expect_true(all(abs(recon - grid$rn) <= rel_tol * scale))
})

test_that("negative H (advection) gives LE above Rn - G, unchanged", {
  le <- ef_latent_heat(rn = 500, g = 50, h = -40)
  expect_lt(abs(le - 490), tol)
})

test_that("scalar arguments are recycled to the common length", {
  le <- ef_latent_heat(rn = c(550, 600, 620), g = 60, h = c(40, 50, 300))
  expect_length(le, 3L)
  expect_lt(max(abs(le - c(450, 490, 260))), tol)
})

test_that("integer inputs are accepted", {
  expect_identical(ef_latent_heat(rn = 600L, g = 60L, h = 50L), 490L)
})

test_that("matrices keep their dim; mismatched dims are rejected", {
  rn <- matrix(c(600, 400, 500, 650), nrow = 2)
  h <- matrix(c(50, 369, 100, 20), nrow = 2)
  le <- ef_latent_heat(rn = rn, g = 60, h = h)
  expect_identical(dim(le), c(2L, 2L))
  expect_lt(max(abs(le - (rn - 60 - h))), tol)

  expect_error(
    ef_latent_heat(rn = rn, g = 60, h = matrix(c(50, 369, 100, 20), nrow = 1)),
    class = "earthflux_input_error"
  )
})

test_that("incompatible and zero lengths raise classed input errors", {
  expect_error(
    ef_latent_heat(rn = c(600, 500), g = c(60, 50, 40), h = 50),
    class = "earthflux_input_error"
  )
  expect_error(
    ef_latent_heat(rn = numeric(0), g = 60, h = 50),
    class = "earthflux_input_error"
  )
})

test_that("missing values propagate element by element without warnings", {
  expect_silent(
    le <- ef_latent_heat(rn = c(600, NA, 600, 600), g = c(60, 60, NaN, 60),
                         h = c(50, 50, 50, NA))
  )
  expect_lt(abs(le[1] - 490), tol)
  expect_true(all(is.na(le[2:4])))
  expect_true(is.na(ef_latent_heat(rn = NA_real_, g = 60, h = 50)))
})

test_that("infinite values raise a domain error in each argument", {
  for (arg in c("rn", "g", "h")) {
    args <- list(rn = 600, g = 60, h = 50)
    args[[arg]] <- Inf
    expect_error(do.call(ef_latent_heat, args),
                 class = "earthflux_domain_error")
    args[[arg]] <- -Inf
    expect_error(do.call(ef_latent_heat, args),
                 class = "earthflux_domain_error")
  }
})

test_that("non-numeric inputs raise a classed input error", {
  expect_error(ef_latent_heat(rn = "600", g = 60, h = 50),
               class = "earthflux_input_error")
  expect_error(ef_latent_heat(rn = 600, g = TRUE, h = 50),
               class = "earthflux_input_error")
  expect_error(ef_latent_heat(rn = 600, g = 60, h = factor(50)),
               class = "earthflux_input_error")
})
