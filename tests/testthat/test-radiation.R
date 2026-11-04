# Tests for ef_net_radiation() and its radiation components
#
# Specification: dev/specs/ef_net_radiation.md (test design in section 8);
# components and diagnostics: dev/specs/radiation-components.md (see the
# second part of this file). Solar geometry: test-solar-geometry.R.
#
# Tolerance of the ef_net_radiation() cases: the reference value is
# hand-computed with exact decimal arithmetic. The computation involves four
# additions/subtractions and two products of magnitudes below 1e3, so
# double-precision rounding error is of order 1e-13 W m-2. An absolute
# tolerance of 1e-10 W m-2 is therefore far above rounding noise and far
# below any physically meaningful difference.

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

# Radiation components ---------------------------------------------------------
#
# Specification: dev/specs/radiation-components.md sections 6.3-6.6 (cases
# T1-T3, S1-S4, L1, O1-O2) and section 7 (chain to ef_net_radiation()).
#
# Tolerances:
# - values printed in the specification with 7 significant digits:
#   relative 1e-6 (dev/VALIDATION_PLAN.md 1.2, "valores intermedios con
#   >= 6 cifras"); values printed with k decimals: half a unit of the last
#   printed digit;
# - algebraic identities (same quantity computed along two paths): relative
#   1e-12 (a few products and one division of numbers of order 1-1e3).
#
# The shortwave cases of the specification (S1-S4) use Gsc = 1367 W m-2 as a
# test value while decision RC-06 is open; the package uses the constant
# EF_SOLAR_CONSTANT (FAO-56, 1366.67 W m-2). Since Rs is proportional to
# Gsc, the results are rescaled by 1367 / EF_SOLAR_CONSTANT before
# comparing with the printed values.

deg <- pi / 180
rel <- function(x, ref) max(abs(x - ref) / abs(ref))
gsc_scale <- 1367 / EF_SOLAR_CONSTANT
cz35 <- cos(35 * deg)

# Shortwave transmissivity -----------------------------------------------------

test_that("T1-T3: partitioned transmissivity matches the hand computation", {
  t1 <- ef_tau_sw_allen(1, 101.3, 1.5, 1)
  expect_named(t1, c("beam", "diffuse", "total"))
  expect_lt(rel(t1$beam, 0.6487715), 1e-6)
  expect_lt(rel(t1$diffuse, 0.1164422), 1e-6)
  expect_lt(rel(t1$total, 0.7652138), 1e-6)

  t2 <- ef_tau_sw_allen(cz35, 101.3, 1.5, 1)
  expect_lt(rel(t2$beam, 0.6142806), 1e-6)
  expect_lt(rel(t2$diffuse, 0.1288590), 1e-6)
  expect_lt(rel(t2$total, 0.7431396), 1e-6)

  t3 <- ef_tau_sw_allen(cz35, ef_air_pressure(3000), 0.5, 1)
  expect_lt(rel(t3$beam, 0.7238591), 1e-6)
  expect_lt(rel(t3$diffuse, 0.0894107), 1e-6)
  expect_lt(rel(t3$total, 0.8132698), 1e-6)
  expect_lt(abs(t3$total - (t3$beam + t3$diffuse)), 1e-15)
})

test_that("both branches of the diffuse transmissivity are used as written", {
  high <- ef_tau_sw_allen(cz35, 101.3, 1.5, 1)
  expect_gte(high$beam, 0.15)
  expect_lt(abs(high$diffuse - (0.35 - 0.36 * high$beam)), 1e-15)
  # Low sun (cos = 0.1): tau_b = 0.1256464 < 0.15.
  low <- ef_tau_sw_allen(0.1, 101.3, 1, 1)
  expect_lt(low$beam, 0.15)
  expect_lt(abs(low$diffuse - (0.18 + 0.82 * low$beam)), 1e-15)
})

test_that("beam transmissivity is monotonic in its inputs and below 0.98", {
  base <- ef_tau_sw_allen(0.8, 95, 1, 0.8)$beam
  expect_lt(ef_tau_sw_allen(0.8, 95, 2, 0.8)$beam, base)
  expect_lt(ef_tau_sw_allen(0.8, 100, 1, 0.8)$beam, base)
  expect_lt(ef_tau_sw_allen(0.6, 95, 1, 0.8)$beam, base)
  expect_gt(ef_tau_sw_allen(0.8, 95, 1, 1)$beam, base)
  grid <- expand.grid(cz = c(0.05, 0.5, 1), p = c(50, 101.3),
                      ea = c(0, 3), kt = c(0.5, 1))
  tau <- ef_tau_sw_allen(grid$cz, grid$p, grid$ea, grid$kt)
  expect_true(all(tau$beam < 0.98))
})

test_that("partitioned transmissivity: domain errors, NA and dim", {
  dom <- "earthflux_domain_error"
  expect_error(ef_tau_sw_allen(0, 101.3, 1.5, 1), class = dom)
  expect_error(ef_tau_sw_allen(-0.2, 101.3, 1.5, 1), "`cos_zenith`")
  expect_error(ef_tau_sw_allen(1.01, 101.3, 1.5, 1), class = dom)
  expect_error(ef_tau_sw_allen(0.8, 0, 1.5, 1), class = dom)
  expect_error(ef_tau_sw_allen(0.8, 101.3, -0.1, 1), class = dom)
  expect_error(ef_tau_sw_allen(0.8, 101.3, 1.5, 0), class = dom)
  expect_error(ef_tau_sw_allen(0.8, 101.3, 1.5, 1.1), "`turbidity`")
  expect_error(ef_tau_sw_allen(0.8, 101.3, 1.5), "turbidity")
  expect_silent(ef_tau_sw_allen(0.8, 101.3, 0, 1))

  tau <- expect_silent(ef_tau_sw_allen(c(0.8, NA, 0.8), 101.3,
                                       c(1.5, 1.5, NaN), 1))
  for (nm in names(tau)) {
    expect_identical(is.na(tau[[nm]]), c(FALSE, TRUE, TRUE), info = nm)
  }
  m <- ef_tau_sw_allen(matrix(c(0.5, 0.6, 0.7, 0.8), 2), 101.3, 1.5, 1)
  for (nm in names(m)) {
    expect_identical(dim(m[[nm]]), c(2L, 2L), info = nm)
  }
  expect_error(
    ef_tau_sw_allen(matrix(0.5, 2, 2), matrix(100, 1, 4), 1.5, 1),
    class = "earthflux_input_error"
  )
})

test_that("elevation transmissivity: values, linearity, domain and NA", {
  expect_identical(ef_tau_sw_elevation(0), 0.75)
  expect_lt(abs(ef_tau_sw_elevation(3000) - 0.81), 1e-15)
  z <- c(-400, 0, 1500, 4800)
  expect_lt(max(abs(diff(ef_tau_sw_elevation(z)) / diff(z) - 2e-5)), 1e-15)
  expect_error(ef_tau_sw_elevation(12500), class = "earthflux_domain_error")
  expect_error(ef_tau_sw_elevation(-37500), class = "earthflux_domain_error")
  expect_identical(ef_tau_sw_elevation(c(0, NA)), c(0.75, NA))
  expect_identical(dim(ef_tau_sw_elevation(matrix(0, 2, 3))), c(2L, 3L))
  expect_error(ef_tau_sw_elevation("0"), class = "earthflux_input_error")
})

test_that("ef_tau_sw() dispatches to its methods without changing results", {
  expect_identical(
    ef_tau_sw(cos_zenith = c(0.5, 0.9), pressure = 90,
              vapour_pressure = 1.2, turbidity = 0.9, method = "allen"),
    ef_tau_sw_allen(c(0.5, 0.9), 90, 1.2, 0.9)
  )
  expect_identical(
    ef_tau_sw(elevation = c(0, 2500), method = "elevation"),
    ef_tau_sw_elevation(c(0, 2500))
  )
  expect_error(ef_tau_sw(elevation = 0), class = "earthflux_missing_input")
  expect_error(ef_tau_sw(elevation = 0, method = "simple"),
               class = "earthflux_unknown_method")
  expect_error(ef_tau_sw(elevation = 0, method = c("allen", "elevation")),
               class = "earthflux_input_error")
})

# Effective atmospheric emissivity ---------------------------------------------

test_that("atmospheric emissivity matches the hand computation", {
  # tau_sw = 0.75 -> 0.7598381 (7 digits); others printed with 4 decimals.
  expect_lt(rel(ef_atm_emissivity(0.75), 0.7598381), 1e-6)
  expect_lt(
    max(abs(ef_atm_emissivity(c(0.5, 0.7, 0.8, 0.9)) -
              c(0.8224, 0.7747, 0.7427, 0.6942))),
    5e-5
  )
  ea <- ef_atm_emissivity(seq(0.05, 0.95, by = 0.05))
  expect_true(all(diff(ea) < 0))
})

test_that("atmospheric emissivity: domain, values above 1, NA and dim", {
  for (bad in c(0, 1, 1.2, -0.1, Inf)) {
    expect_error(ef_atm_emissivity(bad), class = "earthflux_domain_error",
                 info = bad)
  }
  # Above 1 for tau_sw < 0.0022776: returned unchanged (flagged elsewhere).
  high <- expect_silent(ef_atm_emissivity(0.001))
  expect_gt(high, 1)
  expect_lt(ef_atm_emissivity(0.0023), 1)
  expect_identical(ef_atm_emissivity(c(0.75, NA)) [2], NA_real_)
  expect_identical(dim(ef_atm_emissivity(matrix(0.7, 2, 2))), c(2L, 2L))
})

# Incoming shortwave radiation -------------------------------------------------

t2 <- ef_tau_sw_allen(cz35, 101.3, 1.5, 1)
rs_model <- function(cos_incidence, slope, ground_albedo = 0.2,
                     cos_zenith = cz35) {
  ef_rs_in_modelled(cos_zenith, cos_incidence, inv_distance = 1,
                    tau_beam = t2$beam, tau_diffuse = t2$diffuse,
                    slope = slope, ground_albedo = ground_albedo)
}

test_that("S1: flat terrain", {
  rs <- rs_model(cz35, 0)
  expect_named(rs, c("total", "beam", "diffuse", "reflected",
                     "diffuse_fraction"))
  expect_lt(abs(rs$beam * gsc_scale - 687.8597), 5e-5)
  expect_lt(abs(rs$diffuse * gsc_scale - 144.2938), 5e-5)
  expect_identical(rs$reflected, 0)
  expect_lt(abs(rs$total * gsc_scale - 832.1535), 5e-5)
  expect_lt(abs(rs$diffuse_fraction - 0.1734), 5e-5)
})

test_that("S2-S4: north, south and self-shaded south-facing slopes", {
  # S2: north-facing 35 degree slope, normal to the sun (cos = 1).
  s2 <- rs_model(1, 35 * deg)
  expect_lt(abs(s2$beam * gsc_scale - 839.7216), 5e-5)
  expect_lt(abs(s2$diffuse * gsc_scale - 131.2462), 5e-5)
  expect_lt(abs(s2$reflected * gsc_scale - 15.0493), 5e-5)
  expect_lt(abs(s2$total * gsc_scale - 986.0172), 5e-5)
  # S3: south-facing 35 degree slope (cos = cos 70 degrees).
  s3 <- rs_model(cos(70 * deg), 35 * deg)
  expect_lt(abs(s3$beam * gsc_scale - 287.2017), 5e-5)
  expect_lt(abs(s3$total * gsc_scale - 433.4972), 5e-5)
  # S4: south-facing 60 degree slope, cos = cos 95 degrees < 0.
  s4 <- expect_silent(rs_model(cos(95 * deg), 60 * deg))
  expect_identical(s4$beam, 0)
  expect_lt(abs(s4$diffuse * gsc_scale - 108.2204), 5e-5)
  expect_lt(abs(s4$reflected * gsc_scale - 41.6077), 5e-5)
  expect_lt(abs(s4$total * gsc_scale - 149.8280), 5e-5)
})

test_that("flat-terrain identity: Rs = Gsc * dr * cos(theta_h) * tau_sw", {
  cz <- c(0.3, 0.6, 0.95)
  dr <- c(0.97, 1, 1.03)
  tau <- ef_tau_sw_allen(cz, 90, 1.2, 0.95)
  rs <- ef_rs_in_modelled(cz, cz, dr, tau$beam, tau$diffuse, slope = 0)
  expect_lt(rel(rs$total, EF_SOLAR_CONSTANT * dr * cz * tau$total), 1e-12)
  expect_identical(rs$reflected, c(0, 0, 0))
  # In the modelled path the beam on the plane is tau_b * Gsc * dr * cos_rel.
  s <- rs_model(0.9, 0.3)
  expect_lt(rel(s$beam, t2$beam * EF_SOLAR_CONSTANT * 0.9), 1e-12)
})

test_that("conservation: rho_g = 0 and slope -> 0 recover the horizontal", {
  rs <- rs_model(cz35, 1e-9, ground_albedo = 0)
  horizontal <- EF_SOLAR_CONSTANT * cz35 * (t2$beam + t2$diffuse)
  expect_lt(rel(rs$total, horizontal), 1e-12)
})

test_that("ground_albedo is required only on slopes", {
  expect_error(rs_model(0.9, 0.3, ground_albedo = NULL),
               class = "earthflux_missing_input")
  expect_error(rs_model(0.9, c(0, 0.3), ground_albedo = NULL),
               "ground_albedo")
  flat <- expect_silent(rs_model(cz35, 0, ground_albedo = NULL))
  expect_identical(flat, rs_model(cz35, 0, ground_albedo = 0.4))
  expect_error(rs_model(0.9, 0.3, ground_albedo = 1.2),
               class = "earthflux_domain_error")
})

test_that("modelled shortwave: domain errors, NA and dim", {
  dom <- "earthflux_domain_error"
  expect_error(rs_model(0.5, 0, cos_zenith = 0), class = dom)
  expect_error(rs_model(0.5, 0, cos_zenith = -0.1), "`cos_zenith`")
  expect_error(rs_model(1.2, 0), class = dom)
  expect_error(rs_model(0.5, -0.1), class = dom)
  expect_error(rs_model(0.5, 2), class = dom)
  expect_error(
    ef_rs_in_modelled(0.8, 0.8, 1, tau_beam = 0.7, tau_diffuse = 0.3,
                      slope = 0),
    "tau_beam \\+ tau_diffuse"
  )
  expect_error(ef_rs_in_modelled(0.8, 0.8, 1, 0, 0, slope = 0),
               class = dom)
  expect_error(ef_rs_in_modelled(0.8, 0.8, 1, -0.1, 0.2, slope = 0),
               class = dom)
  expect_error(ef_rs_in_modelled(0.8, 0.8, 0, 0.6, 0.1, slope = 0),
               class = dom)
  expect_error(ef_rs_in_modelled(0.8, 0.8, 1, 0.6, 0.1),
               "slope")

  rs <- expect_silent(
    ef_rs_in_modelled(c(0.8, NA, 0.8, 0.8), 0.8, 1, 0.6,
                      c(0.1, 0.1, NA, 0.1), slope = c(0, 0, 0, NA),
                      ground_albedo = 0.2)
  )
  # NA propagates arithmetically to the outputs that depend on the missing
  # input; the total depends on all of them.
  expect_identical(is.na(rs$total), c(FALSE, TRUE, TRUE, TRUE))
  expect_identical(is.na(rs$beam), c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(is.na(rs$diffuse), c(FALSE, TRUE, TRUE, TRUE))
  expect_identical(is.na(rs$reflected), c(FALSE, TRUE, TRUE, TRUE))
  expect_identical(is.na(rs$diffuse_fraction), c(FALSE, FALSE, TRUE, FALSE))

  m <- ef_rs_in_modelled(matrix(0.8, 2, 2), matrix(0.7, 2, 2), 1, 0.6, 0.1,
                         slope = 0.1, ground_albedo = 0.2)
  for (nm in names(m)) {
    expect_identical(dim(m[[nm]]), c(2L, 2L), info = nm)
  }
})

test_that("measured path with the clear-sky partition reproduces the model", {
  slope <- c(0, 35, 35, 60) * deg
  cos_inc <- c(cz35, 1, cos(70 * deg), cos(95 * deg))
  modelled <- rs_model(cos_inc, slope)
  rso <- EF_SOLAR_CONSTANT * cz35 * t2$total
  measured <- ef_rs_in_measured(
    rs_horizontal = rso, diffuse_fraction = t2$diffuse / t2$total,
    cos_zenith = cz35, cos_incidence = cos_inc, slope = slope,
    ground_albedo = 0.2
  )
  expect_named(measured, c("total", "beam", "diffuse", "reflected"))
  for (nm in names(measured)) {
    expect_lt(max(abs(measured[[nm]] - modelled[[nm]])), 1e-9, label = nm)
  }
})

test_that("measured shortwave: components, domain errors and NA", {
  rs <- ef_rs_in_measured(800, 0.25, 0.8, 0.8, slope = 0)
  expect_lt(abs(rs$beam - 600), 1e-12)
  expect_lt(abs(rs$diffuse - 200), 1e-12)
  expect_identical(rs$reflected, 0)
  expect_lt(abs(rs$total - 800), 1e-12)

  dom <- "earthflux_domain_error"
  expect_error(ef_rs_in_measured(-1, 0.2, 0.8, 0.8, 0), class = dom)
  expect_error(ef_rs_in_measured(800, 1.1, 0.8, 0.8, 0), class = dom)
  expect_error(ef_rs_in_measured(800, 0.2, 0, 0.8, 0), class = dom)
  expect_error(ef_rs_in_measured(800, 0.2, 0.8, 0.8, 0.3),
               class = "earthflux_missing_input")
  rs_na <- expect_silent(ef_rs_in_measured(c(800, NA), 0.2, 0.8, 0.8, 0))
  expect_identical(is.na(rs_na$total), c(FALSE, TRUE))
})

test_that("ef_rs_in() dispatches to its methods without changing results", {
  expect_identical(
    ef_rs_in(cos_zenith = cz35, cos_incidence = 0.7, inv_distance = 1.01,
             tau_beam = t2$beam, tau_diffuse = t2$diffuse, slope = 0.3,
             ground_albedo = 0.15, method = "modelled"),
    ef_rs_in_modelled(cz35, 0.7, 1.01, t2$beam, t2$diffuse, 0.3, 0.15)
  )
  expect_identical(
    ef_rs_in(rs_horizontal = 850, diffuse_fraction = 0.2, cos_zenith = cz35,
             cos_incidence = 0.7, slope = 0.3, ground_albedo = 0.15,
             method = "measured"),
    ef_rs_in_measured(850, 0.2, cz35, 0.7, 0.3, 0.15)
  )
  expect_error(ef_rs_in(rs_horizontal = 850), class = "earthflux_missing_input")
  expect_error(ef_rs_in(rs_horizontal = 850, method = "clear_sky"),
               class = "earthflux_unknown_method")
})

# Longwave radiation -----------------------------------------------------------

test_that("L1: incoming longwave matches the hand computation", {
  ea <- 0.7598381
  expect_lt(rel(ef_rl_in(293.15, ea), 318.1943), 1e-6)
  expect_lt(rel(ef_rl_in(c(288.15, 310), ea), c(297.0348, 397.9052)), 1e-6)
})

test_that("incoming longwave: identities, recycling, domain and NA", {
  expect_lt(rel(ef_rl_in(300, 1), EF_STEFAN_BOLTZMANN * 300^4), 1e-15)
  expect_lt(rel(ef_rl_in(500, 0.8) / ef_rl_in(250, 0.8), 16), 1e-14)
  ea <- c(0.70, 0.75, 0.80)
  expect_identical(ef_rl_in(290, ea), ef_rl_in(rep(290, 3), ea))
  # Values above 1 are accepted (flagged elsewhere).
  expect_silent(ef_rl_in(290, 1.05))
  dom <- "earthflux_domain_error"
  expect_error(ef_rl_in(0, 0.8), class = dom)
  expect_error(ef_rl_in(-1, 0.8), "`temperature`")
  expect_error(ef_rl_in(290, 0), class = dom)
  expect_error(ef_rl_in(290, -0.5), "`atm_emissivity`")
  expect_error(ef_rl_in(Inf, 0.8), class = dom)
  expect_error(ef_rl_in(290), "atm_emissivity")
  expect_identical(is.na(ef_rl_in(c(290, NA), c(NA, 0.8))), c(TRUE, TRUE))
  expect_identical(dim(ef_rl_in(matrix(290, 2, 2), 0.8)), c(2L, 2L))
})

test_that("O1-O2: emitted longwave matches the hand computation", {
  # O1 printed with 7 decimals (exact decimal arithmetic with exact sigma).
  expect_lt(abs(ef_rl_out(300, 0.98) - 450.1143214), 5e-8)
  expect_lt(abs(ef_rl_out(273.15, 1) - 315.6578), 5e-5)
})

test_that("emitted longwave: identities, domain, NA and dim", {
  expect_lt(rel(ef_rl_out(300, 1), EF_STEFAN_BOLTZMANN * 300^4), 1e-15)
  expect_lt(rel(ef_rl_out(300, 0.5) * 2, ef_rl_out(300, 1)), 1e-15)
  expect_lt(rel(ef_rl_out(600, 0.9) / ef_rl_out(300, 0.9), 16), 1e-14)
  dom <- "earthflux_domain_error"
  for (bad in c(0, -1, Inf)) {
    expect_error(ef_rl_out(bad, 0.98), class = dom, info = bad)
  }
  expect_error(ef_rl_out(300, 0), class = dom)
  expect_error(ef_rl_out(300, 1.01), "`emissivity`")
  expect_identical(is.na(ef_rl_out(c(300, NA, 300), c(0.98, 0.98, NaN))),
                   c(FALSE, TRUE, TRUE))
  m <- ef_rl_out(matrix(c(295, 300, 305, 310), 2), 0.97)
  expect_identical(dim(m), c(2L, 2L))
  expect_error(ef_rl_out(matrix(300, 2, 2), matrix(0.98, 4, 1)),
               class = "earthflux_input_error")
  expect_error(ef_rl_out("300", 0.98), class = "earthflux_input_error")
})

# Chain to ef_net_radiation() (spec section 7) ---------------------------------

test_that("radiation components chain into ef_net_radiation()", {
  # Hand computation with a single, coherent tau_sw (spec section 7, note):
  #   geometry: phi = -35 deg, delta = 0, omega = 0, s = 0
  #             -> cos(theta_h) = cos 35 deg = 0.8191520; dr = 1 (fixed)
  #   pressure: z = 0 -> P = 101.3 kPa
  #   tau:      ea = 1.5 kPa, Kt = 1 -> tau_b = 0.6142806,
  #             tau_d = 0.1288590, tau_sw = 0.7431396 (case T2)
  #   Rs_in:    Gsc = 1366.667 (EF_SOLAR_CONSTANT)
  #             Ra_h = 1366.667 * 0.8191520 = 1119.5078
  #             Rs_in = 1119.5078 * 0.7431396 = 831.9506 W m-2
  #   eps_a:    -ln 0.7431396 = 0.2968713; ^0.09 = 0.8964605
  #             eps_a = 0.85 * 0.8964605 = 0.7619914
  #   RL_in:    T = 293.15 K: sigma T^4 = 418.7659
  #             RL_in = 0.7619914 * 418.7659 = 319.0960 W m-2
  #   RL_out:   Ts = 300 K, e0 = 0.98 -> 450.1143 W m-2 (case O1)
  #   Rn:       albedo = 0.2
  #             Rn = 0.8 * 831.9506 + 319.0960 - 450.1143 - 0.02 * 319.0960
  #                = 665.5605 + 319.0960 - 450.1143 - 6.3819 = 528.1603
  # Printed with 7 significant digits: relative tolerance 1e-6.
  cos_zenith <- ef_cos_incidence(-35 * deg, 0, 0, 0, 0)
  expect_lt(rel(cos_zenith, 0.8191520), 1e-6)
  tau <- ef_tau_sw(cos_zenith = cos_zenith, pressure = ef_air_pressure(0),
                   vapour_pressure = 1.5, turbidity = 1, method = "allen")
  rs <- ef_rs_in(cos_zenith = cos_zenith, cos_incidence = cos_zenith,
                 inv_distance = 1, tau_beam = tau$beam,
                 tau_diffuse = tau$diffuse, slope = 0, method = "modelled")
  expect_lt(rel(rs$total, 831.9506), 1e-6)
  atm <- ef_atm_emissivity(tau$total)
  expect_lt(rel(atm, 0.7619914), 1e-6)
  rl_in <- ef_rl_in(temperature = 293.15, atm_emissivity = atm)
  expect_lt(rel(rl_in, 319.0960), 1e-6)
  rl_out <- ef_rl_out(lst = 300, emissivity = 0.98)
  rn <- ef_net_radiation(rs_in = rs$total, albedo = 0.2, rl_in = rl_in,
                         rl_out = rl_out, emissivity = 0.98)
  expect_lt(rel(rn, 528.1603), 1e-6)
})

test_that("full chain from the overpass time keeps shape and propagates NA", {
  lat <- matrix(c(-33, -34, -35, NA), 2) * deg
  geo <- ef_solar_geometry(doy = 15, utc_hour = 15.5, lat = lat,
                           lon = -71 * deg, slope = 10 * deg, aspect = 0)
  tau <- ef_tau_sw_allen(geo$cos_zenith, ef_air_pressure(500), 1.2, 1)
  rs <- ef_rs_in_modelled(geo$cos_zenith, geo$cos_incidence,
                          geo$inv_distance, tau$beam, tau$diffuse,
                          slope = 10 * deg, ground_albedo = 0.2)
  rl_in <- ef_rl_in(295, ef_atm_emissivity(tau$total))
  rl_out <- ef_rl_out(305, 0.97)
  rn <- ef_net_radiation(rs$total, 0.2, rl_in, rl_out, 0.97)
  expect_identical(dim(rn), c(2L, 2L))
  expect_identical(is.na(rn), is.na(lat))
  expect_true(all(rn[!is.na(rn)] > 0))
})

# Diagnostics of the radiation stage -------------------------------------------

flag_of <- function(flags, code) {
  hit <- Filter(function(f) identical(f$code, code), flags)
  if (length(hit) == 0L) NULL else hit[[1L]]
}

test_that("EF_RAD_* codes are registered with the planned bits", {
  reg <- ef_flag_registry()
  rad <- reg[reg$stage == "RAD", ]
  expect_identical(
    rad$code,
    c("EF_RAD_SELF_SHADED", "EF_RAD_ATM_EMISSIVITY_GT1", "EF_RAD_RS_GT_RA",
      "EF_RAD_RN_NEGATIVE")
  )
  expect_identical(rad$bit, 1:4)
  expect_identical(rad$severity, c("info", "warning", "warning", "info"))
  expect_false("EF_RAD_SUN_LOW" %in% reg$code)
})

test_that("EF_RAD_SELF_SHADED marks planes facing away from the sun", {
  flags <- ef_diagnose_radiation(
    cos_zenith = c(0.8, 0.8, 0.8, -0.1, NA),
    cos_incidence = c(cos(95 * deg), 0, 0.3, -0.2, -0.5)
  )
  f <- flag_of(flags, "EF_RAD_SELF_SHADED")
  expect_s3_class(f, "earthflux_flag")
  expect_identical(f$index, c(1L, 2L))
  expect_identical(f$n_total, 5L)
  # Negative case: all planes lit.
  none <- flag_of(ef_diagnose_radiation(cos_zenith = 0.8,
                                        cos_incidence = c(0.2, 0.9)),
                  "EF_RAD_SELF_SHADED")
  expect_identical(none$n_flagged, 0L)
  # Consistency with the beam component of the S4 case.
  s4 <- rs_model(cos(95 * deg), 60 * deg)
  expect_identical(s4$beam, 0)
})

test_that("EF_RAD_ATM_EMISSIVITY_GT1 marks emissivities above 1", {
  ea <- ef_atm_emissivity(c(0.001, 0.75, NA))
  f <- flag_of(ef_diagnose_radiation(atm_emissivity = ea),
               "EF_RAD_ATM_EMISSIVITY_GT1")
  expect_identical(f$index, 1L)
  expect_identical(f$severity, "warning")
  none <- flag_of(ef_diagnose_radiation(atm_emissivity = c(0.7, 1)),
                  "EF_RAD_ATM_EMISSIVITY_GT1")
  expect_identical(none$n_flagged, 0L)
})

test_that("EF_RAD_RS_GT_RA compares measured Rs with the extraterrestrial", {
  ra <- EF_SOLAR_CONSTANT * 1.02 * 0.6
  flags <- ef_diagnose_radiation(
    rs_horizontal = c(ra - 1, ra + 1, ra, NA, 5, 0),
    inv_distance = 1.02,
    cos_zenith = c(0.6, 0.6, 0.6, 0.6, -0.1, -0.1)
  )
  f <- flag_of(flags, "EF_RAD_RS_GT_RA")
  expect_identical(f$index, c(2L, 5L))
  expect_identical(f$scope, "cell")
  # Not evaluated without inv_distance.
  expect_null(flag_of(
    ef_diagnose_radiation(rs_horizontal = 900, cos_zenith = 0.6),
    "EF_RAD_RS_GT_RA"
  ))
})

test_that("EF_RAD_RN_NEGATIVE marks negative net radiation", {
  rn <- ef_net_radiation(rs_in = c(0, 800), albedo = 0.2, rl_in = 280,
                         rl_out = 400, emissivity = 0.98)
  f <- flag_of(ef_diagnose_radiation(rn = c(rn, NA, 0)),
               "EF_RAD_RN_NEGATIVE")
  expect_identical(f$index, 1L)
  expect_identical(f$severity, "info")
  none <- flag_of(ef_diagnose_radiation(rn = c(10, 0)), "EF_RAD_RN_NEGATIVE")
  expect_identical(none$n_flagged, 0L)
})

test_that("diagnostics evaluate only the codes whose inputs are given", {
  expect_identical(ef_diagnose_radiation(), list())
  only_rn <- ef_diagnose_radiation(rn = 1)
  expect_identical(vapply(only_rn, `[[`, "", "code"), "EF_RAD_RN_NEGATIVE")
  all_codes <- ef_diagnose_radiation(
    cos_zenith = 0.8, cos_incidence = 0.5, inv_distance = 1,
    atm_emissivity = 0.75, rs_horizontal = 800, rn = 400
  )
  expect_length(all_codes, 4L)
  expect_error(ef_diagnose_radiation(rn = c(1, 2), atm_emissivity = c(1, 2, 3)),
               class = "earthflux_input_error")
  expect_error(ef_diagnose_radiation(rn = "1"),
               class = "earthflux_input_error")
})
