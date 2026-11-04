# Tests for ef_net_radiation()
#
# Specification: dev/specs/ef_net_radiation.md (test design in section 8).
#
# Tolerance: the reference value is hand-computed with exact decimal
# arithmetic. The computation involves four additions/subtractions and two
# products of magnitudes below 1e3, so double-precision rounding error is of
# order 1e-13 W m-2. An absolute tolerance of 1e-10 W m-2 is therefore far
# above rounding noise and far below any physically meaningful difference.

# Reference case (spec section 7):
#   rs_in = 800, albedo = 0.20, rl_in = 320, emissivity = 0.98,
#   rl_out = 450.0846 (= 0.98 * 5.67e-8 * 300^4, passed as a number)
#   Rn = 0.8 * 800 + 320 - 450.0846 - 0.02 * 320 = 503.5154 W m-2
ref <- list(rs_in = 800, albedo = 0.20, rl_in = 320, rl_out = 450.0846,
            emissivity = 0.98)
ref_rn <- 503.5154
tol <- 1e-10

call_ref <- function(...) {
  args <- utils::modifyList(ref, list(...))
  do.call(ef_net_radiation, args)
}

test_that("reference case matches the hand computation", {
  rn <- call_ref()
  expect_type(rn, "double")
  expect_length(rn, 1L)
  expect_lt(abs(rn - ref_rn), tol)
})

test_that("total upwelling longwave with emissivity = 1 is equivalent", {
  # rl_out_total = emitted (450.0846) + reflected (0.02 * 320 = 6.4)
  rn <- call_ref(rl_out = 456.4846, emissivity = 1)
  expect_lt(abs(rn - ref_rn), tol)
})

test_that("albedo = 0 and emissivity = 1 reduce to rs_in + rl_in - rl_out", {
  rn <- ef_net_radiation(
    rs_in = 800, albedo = 0, rl_in = 320, rl_out = 450, emissivity = 1
  )
  expect_lt(abs(rn - (800 + 320 - 450)), tol)
})

test_that("cancelling longwave terms leave the absorbed shortwave", {
  rs_in <- c(0, 250, 800)
  albedo <- c(0.1, 0.2, 0.3)
  rn <- ef_net_radiation(
    rs_in = rs_in, albedo = albedo, rl_in = 350, rl_out = 350,
    emissivity = 1
  )
  expect_lt(max(abs(rn - (1 - albedo) * rs_in)), tol)
})

test_that("scalar arguments are recycled to the common length", {
  rs_in <- c(700, 800, 900)
  rn <- ef_net_radiation(
    rs_in = rs_in, albedo = 0.20, rl_in = 320, rl_out = 450.0846,
    emissivity = 0.98
  )
  expect_length(rn, 3L)
  expected <- 0.8 * rs_in + 320 - 450.0846 - 0.02 * 320
  expect_lt(max(abs(rn - expected)), tol)
  expect_lt(abs(rn[2] - ref_rn), tol)
})

test_that("integer inputs are accepted", {
  rn <- ef_net_radiation(
    rs_in = 800L, albedo = 0, rl_in = 320L, rl_out = 450L, emissivity = 1L
  )
  expect_identical(rn, 670)
})

test_that("incompatible lengths raise a classed input error", {
  expect_error(
    call_ref(rs_in = c(800, 700), albedo = c(0.2, 0.2, 0.2)),
    class = "earthflux_input_error"
  )
  expect_error(
    call_ref(rs_in = c(800, 700), albedo = c(0.2, 0.2, 0.2)),
    "common length"
  )
  expect_error(call_ref(rl_in = numeric(0)), class = "earthflux_input_error")
})

test_that("NA and NaN propagate without warnings or errors", {
  rn <- expect_silent(
    ef_net_radiation(
      rs_in = c(800, NA, 800, 800, 800, 800),
      albedo = c(0.2, 0.2, NA, 0.2, 0.2, 0.2),
      rl_in = c(320, 320, 320, NaN, 320, 320),
      rl_out = c(450.0846, 450.0846, 450.0846, 450.0846, NA, 450.0846),
      emissivity = c(0.98, 0.98, 0.98, 0.98, 0.98, NA_real_)
    )
  )
  expect_identical(is.na(rn), c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE))
  expect_lt(abs(rn[1] - ref_rn), tol)
  expect_true(is.nan(rn[4]))
  expect_identical(call_ref(albedo = NA_real_), NA_real_)
})

test_that("albedo outside [0, 1] raises a domain error; bounds are allowed", {
  expect_error(call_ref(albedo = -0.01), class = "earthflux_domain_error")
  expect_error(call_ref(albedo = 1.01), class = "earthflux_domain_error")
  expect_error(call_ref(albedo = c(0.2, 1.5, -1)), "`albedo`.*2 value")
  expect_lt(abs(call_ref(albedo = 0) - (800 + 320 - 450.0846 - 6.4)), tol)
  expect_lt(abs(call_ref(albedo = 1) - (320 - 450.0846 - 6.4)), tol)
})

test_that("emissivity outside (0, 1] raises a domain error; 1 is allowed", {
  expect_error(call_ref(emissivity = 0), class = "earthflux_domain_error")
  expect_error(call_ref(emissivity = -0.5), class = "earthflux_domain_error")
  expect_error(call_ref(emissivity = 1.02), class = "earthflux_domain_error")
  expect_error(call_ref(emissivity = 0), "`emissivity`.*1 value")
  expect_lt(abs(call_ref(emissivity = 1) - (640 + 320 - 450.0846)), tol)
})

test_that("negative rs_in raises a domain error; zero is allowed", {
  expect_error(call_ref(rs_in = -1), class = "earthflux_domain_error")
  expect_error(call_ref(rs_in = -1), "`rs_in`")
  expect_lt(abs(call_ref(rs_in = 0) - (320 - 450.0846 - 6.4)), tol)
})

test_that("non-positive rl_in raises a domain error", {
  expect_error(call_ref(rl_in = 0), class = "earthflux_domain_error")
  expect_error(call_ref(rl_in = -10), class = "earthflux_domain_error")
  expect_error(call_ref(rl_in = 0), "`rl_in`")
})

test_that("non-positive rl_out raises a domain error", {
  expect_error(call_ref(rl_out = 0), class = "earthflux_domain_error")
  expect_error(call_ref(rl_out = -450), class = "earthflux_domain_error")
  expect_error(call_ref(rl_out = 0), "`rl_out`")
})

test_that("infinite values are rejected for every argument", {
  for (nm in names(ref)) {
    bad <- list(Inf)
    names(bad) <- nm
    expect_error(
      do.call(call_ref, bad),
      class = "earthflux_domain_error",
      info = nm
    )
  }
  expect_error(call_ref(rl_in = -Inf), "infinite")
})

test_that("domain errors are also input errors", {
  cnd <- tryCatch(
    ef_net_radiation(
      rs_in = 800, albedo = 2, rl_in = 320, rl_out = 450, emissivity = 0.98
    ),
    error = identity
  )
  expect_s3_class(cnd, "earthflux_domain_error")
  expect_s3_class(cnd, "earthflux_input_error")
  expect_s3_class(cnd, "earthflux_error")
  expect_identical(cnd$call[[1]], as.name("ef_net_radiation"))
})

test_that("non-numeric inputs raise a classed input error", {
  expect_error(call_ref(rs_in = "800"), class = "earthflux_input_error")
  expect_error(call_ref(albedo = TRUE), class = "earthflux_input_error")
  expect_error(call_ref(emissivity = factor(1)), class = "earthflux_input_error")
  expect_error(call_ref(rl_in = NA), "`rl_in` must be numeric")
})

test_that("matrix inputs keep their dim", {
  rs_in <- matrix(c(700, 800, 900, 1000), nrow = 2)
  albedo <- matrix(c(0.1, 0.2, 0.3, 0.4), nrow = 2)
  rn <- ef_net_radiation(
    rs_in = rs_in, albedo = albedo, rl_in = 320, rl_out = 450.0846,
    emissivity = 0.98
  )
  expect_true(is.matrix(rn))
  expect_identical(dim(rn), c(2L, 2L))
  expected <- (1 - albedo) * rs_in + 320 - 450.0846 - 0.02 * 320
  expect_lt(max(abs(rn - expected)), tol)
})

test_that("arrays with different dim raise a classed input error", {
  expect_error(
    call_ref(rs_in = matrix(800, 2, 2), albedo = matrix(0.2, 1, 4)),
    class = "earthflux_input_error"
  )
})

test_that("negative net radiation is returned unchanged", {
  # Night-time-like case: no shortwave, surface emits more than it receives.
  rn <- expect_silent(
    ef_net_radiation(
      rs_in = 0, albedo = 0.2, rl_in = 280, rl_out = 400, emissivity = 0.98
    )
  )
  expect_lt(abs(rn - (280 - 400 - 0.02 * 280)), tol)
  expect_lt(rn, 0)
})
