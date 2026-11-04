# Tests for ef_et_inst(), ef_etrf(), ef_et_daily(), ef_et_daily_etrf(),
# the internal inverse ef_et_inst_to_latent_heat() and the stage diagnostics
# ef_diagnose_et()
#
# Specification: dev/specs/evapotranspiration.md (unit chain in section 5,
# functions in section 6, flags in section 7, numeric cases A-F in section
# 10, test design in section 11.3).
#
# Tolerances (section 11.1):
# - cases exact in decimal arithmetic (A, C, D, E): absolute 1e-12 in the
#   output unit (few operations on magnitudes below 1e3; rounding error of
#   order 1e-15);
# - case B (lambda as a function of temperature, includes the K -> degrees C
#   conversion) and algebraic identities (round trip): relative
#   sqrt(.Machine$double.eps) (dev/VALIDATION_PLAN.md section 1.2);
# - case F (FAO-56 equivalences published rounded): absolute tolerance of
#   half a unit of the last published digit.

tol <- 1e-12
rel_tol <- sqrt(.Machine$double.eps)
lambda_fao <- 2.45e6

expect_rel_equal <- function(object, expected, tolerance = rel_tol) {
  expect_true(all(abs(object - expected) <= tolerance * abs(expected)))
}

# Instantaneous ET (section 6.1) -------------------------------------------------

test_that("case A2: 490 W m-2 with lambda = 2.45e6 J kg-1 is 0.72 mm h-1", {
  et <- ef_et_inst(le = 490, lambda = lambda_fao)
  expect_type(et, "double")
  expect_length(et, 1L)
  expect_lt(abs(et - 0.72), tol)
  # Same value with lambda from ef_lambda(method = "constant").
  expect_lt(abs(ef_et_inst(490, ef_lambda(method = "constant")) - 0.72), tol)
})

test_that("case B: temperature-dependent lambda from ef_lambda()", {
  # fao56 at 30 degrees C: lambda = 2 430 170 J kg-1;
  # ET_inst = 1 764 000 / 2 430 170 mm h-1 (0.725875 rounded).
  lambda_30 <- ef_lambda(303.15, method = "fao56")
  expect_rel_equal(lambda_30, 2430170)
  expect_rel_equal(ef_et_inst(490, lambda_30), 1764000 / 2430170)
  # fao56 at 20 degrees C: lambda = 2 453 780 J kg-1 (0.718891 rounded).
  lambda_20 <- ef_lambda(293.15, method = "fao56")
  expect_rel_equal(ef_et_inst(490, lambda_20), 1764000 / 2453780)
  # Vector of lambda matching a vector of LE.
  et <- ef_et_inst(c(490, 490), ef_lambda(c(293.15, 303.15), method = "fao56"))
  expect_rel_equal(et, c(1764000 / 2453780, 1764000 / 2430170))
})

test_that("case C2: negative LE gives negative ET, unchanged and silent", {
  expect_silent(et <- ef_et_inst(le = -49, lambda = lambda_fao))
  expect_lt(abs(et - (-0.072)), tol)
})

test_that("case D: LE = 612.5 W m-2 gives 0.9 mm h-1", {
  expect_lt(abs(ef_et_inst(612.5, lambda_fao) - 0.9), tol)
})

test_that("case E: recycling of lambda and NA propagation without warnings", {
  expect_silent(et <- ef_et_inst(le = c(490, -49, NA), lambda = lambda_fao))
  expect_length(et, 3L)
  expect_lt(max(abs(et[1:2] - c(0.72, -0.072))), tol)
  expect_true(is.na(et[3]))
  expect_true(is.na(ef_et_inst(490, NA_real_)))
  expect_true(is.na(ef_et_inst(NaN, lambda_fao)))
})

test_that("case F: FAO-56 magnitude anchors (detect a missing factor 1000)", {
  # Chapter 1, table 1: 1 mm d-1 = 2.45 MJ m-2 d-1.
  le_1mm <- lambda_fao / 86400
  et <- ef_et_inst(le_1mm, lambda_fao)
  expect_rel_equal(et, 1 / 24)
  expect_rel_equal(et * 24, 1)

  # Chapter 3, table 3: 1 W m-2 = 0.035 mm d-1 (three decimals).
  et_1w <- ef_et_inst(1, lambda_fao)
  expect_rel_equal(et_1w, 3600 / 2.45e6)
  expect_lt(abs(et_1w * 24 - 0.035), 5e-4)

  # Chapter 3, table 3: 1 mm d-1 = 28.4 W m-2 (one decimal).
  le_back <- ef_et_inst_to_latent_heat(1 / 24, lambda_fao)
  expect_rel_equal(le_back, 2.45e6 / 86400)
  expect_lt(abs(le_back - 28.4), 0.05)

  # Chapter 3, Eq. 20: depth = 0.408 * radiation [MJ m-2 d-1] (three
  # decimals); 1 MJ m-2 d-1 = 1e6 / 86400 W m-2.
  expect_lt(abs(ef_et_inst(1e6 / 86400, lambda_fao) * 24 - 0.408), 5e-4)
})

test_that("unit guard: lambda outside [1e6, 1e7] J kg-1 is rejected", {
  # lambda in MJ kg-1 or kJ kg-1 (decision ET-D2).
  expect_error(ef_et_inst(490, 2.45), class = "earthflux_domain_error")
  expect_error(ef_et_inst(490, 2450), class = "earthflux_domain_error")
  expect_error(ef_et_inst(490, 1.1e7), class = "earthflux_domain_error")
  expect_error(ef_et_inst(490, -2.45e6), class = "earthflux_domain_error")
  expect_error(ef_et_inst(490, Inf), class = "earthflux_domain_error")
  expect_error(ef_et_inst(490, c(2.45e6, 2.45)), class = "earthflux_input_error")
  # The bounds themselves are accepted.
  expect_silent(ef_et_inst(490, c(1e6, 1e7)))
})

test_that("ef_et_inst() rejects infinite LE, bad types, lengths and dims", {
  expect_error(ef_et_inst(Inf, lambda_fao), class = "earthflux_domain_error")
  expect_error(ef_et_inst(-Inf, lambda_fao), class = "earthflux_domain_error")
  expect_error(ef_et_inst("490", lambda_fao), class = "earthflux_input_error")
  expect_error(ef_et_inst(490, "2.45e6"), class = "earthflux_input_error")
  expect_error(ef_et_inst(numeric(0), lambda_fao),
               class = "earthflux_input_error")
  expect_error(ef_et_inst(c(490, 400), c(2.45e6, 2.45e6, 2.45e6)),
               class = "earthflux_input_error")
  le <- matrix(c(490, -49, 612.5, 0), nrow = 2)
  expect_error(ef_et_inst(le, matrix(lambda_fao, nrow = 1, ncol = 4)),
               class = "earthflux_input_error")
})

test_that("ef_et_inst() keeps the dim of matrix input", {
  le <- matrix(c(490, -49, 612.5, 0), nrow = 2)
  et <- ef_et_inst(le, lambda_fao)
  expect_identical(dim(et), c(2L, 2L))
  expect_lt(max(abs(et - matrix(c(0.72, -0.072, 0.9, 0), nrow = 2))), tol)
})

test_that("round trip LE -> ET_inst -> LE on the specified grid", {
  grid <- expand.grid(
    le = c(-200, -49, 0, 1, 490, 612.5, 800),
    lambda = c(2.38e6, 2.45e6, 2.52e6)
  )
  back <- ef_et_inst_to_latent_heat(ef_et_inst(grid$le, grid$lambda),
                                    grid$lambda)
  nonzero <- grid$le != 0
  expect_rel_equal(back[nonzero], grid$le[nonzero])
  expect_true(all(abs(back[!nonzero]) <= tol))
})

test_that("case A5: inverse of 0.72 mm h-1 is 490 W m-2", {
  expect_lt(abs(ef_et_inst_to_latent_heat(0.72, lambda_fao) - 490), tol)
  expect_error(ef_et_inst_to_latent_heat(0.72, 2.45),
               class = "earthflux_domain_error")
})

# Reference ET fraction (section 6.2) ---------------------------------------------

test_that("case A3 and C3: ETrF = ET_inst / ETr_inst", {
  expect_lt(abs(ef_etrf(0.72, 0.80, reference = "alfalfa") - 0.9), tol)
  expect_silent(etrf <- ef_etrf(-0.072, 0.80, reference = "alfalfa"))
  expect_lt(abs(etrf - (-0.09)), tol)
  # The reference type does not change the arithmetic.
  expect_identical(ef_etrf(0.72, 0.80, reference = "grass"),
                   ef_etrf(0.72, 0.80, reference = "alfalfa"))
})

test_that("case D: a high ETrF (1.2) is returned unchanged", {
  et <- ef_et_inst(612.5, lambda_fao)
  etrf <- ef_etrf(et, 0.75, reference = "alfalfa")
  expect_lt(abs(etrf - 1.2), tol)
})

test_that("etr_inst <= 0 raises a classed domain error (ET-D6)", {
  expect_error(ef_etrf(0.72, 0, reference = "alfalfa"),
               class = "earthflux_domain_error")
  expect_error(ef_etrf(0.72, -0.1, reference = "alfalfa"),
               class = "earthflux_domain_error")
  expect_error(ef_etrf(0.72, Inf, reference = "alfalfa"),
               class = "earthflux_domain_error")
  expect_error(ef_etrf(Inf, 0.8, reference = "alfalfa"),
               class = "earthflux_domain_error")
})

test_that("ef_etrf() recycles, keeps dim and propagates NA", {
  expect_silent(
    etrf <- ef_etrf(c(0.72, -0.072, NA, 0.6), c(0.8, 0.8, 0.8, NA),
                    reference = "alfalfa")
  )
  expect_lt(max(abs(etrf[1:2] - c(0.9, -0.09))), tol)
  expect_true(all(is.na(etrf[3:4])))

  et <- matrix(c(0.72, -0.072, 0.9, 0), nrow = 2)
  out <- ef_etrf(et, 0.8, reference = "alfalfa")
  expect_identical(dim(out), c(2L, 2L))
  expect_error(ef_etrf(et, matrix(0.8, 1, 4), reference = "alfalfa"),
               class = "earthflux_input_error")
  expect_error(ef_etrf(c(0.7, 0.8), c(0.8, 0.8, 0.8), reference = "alfalfa"),
               class = "earthflux_input_error")
  expect_error(ef_etrf("0.72", 0.8, reference = "alfalfa"),
               class = "earthflux_input_error")
})

test_that("the reference type is required and checked (section 6.4)", {
  expect_error(ef_etrf(0.72, 0.80), class = "earthflux_missing_input")
  expect_error(ef_etrf(0.72, 0.80, reference = NULL),
               class = "earthflux_missing_input")
  expect_error(ef_etrf(0.72, 0.80, reference = "ETr"),
               class = "earthflux_input_error")
  expect_error(ef_etrf(0.72, 0.80, reference = NA_character_),
               class = "earthflux_input_error")
  expect_error(ef_etrf(0.72, 0.80, reference = c("alfalfa", "grass")),
               class = "earthflux_input_error")
  expect_error(ef_et_daily_etrf(0.9, 8), class = "earthflux_missing_input")
  expect_error(ef_et_daily_etrf(0.9, 8, reference = "Alfalfa"),
               class = "earthflux_input_error")
})

# Daily ET (section 6.3) ----------------------------------------------------------

test_that("case A4 and C4: ETa_24 = ETrF * ETr_24", {
  expect_lt(abs(ef_et_daily_etrf(0.9, 8, reference = "alfalfa") - 7.2), tol)
  expect_silent(eta <- ef_et_daily_etrf(-0.09, 8, reference = "alfalfa"))
  expect_lt(abs(eta - (-0.72)), tol)
})

test_that("etr_24 < 0 is a domain error; etr_24 = 0 is allowed", {
  expect_error(ef_et_daily_etrf(0.9, -0.1, reference = "alfalfa"),
               class = "earthflux_domain_error")
  expect_error(ef_et_daily_etrf(0.9, Inf, reference = "alfalfa"),
               class = "earthflux_domain_error")
  expect_error(ef_et_daily_etrf(-Inf, 8, reference = "alfalfa"),
               class = "earthflux_domain_error")
  expect_identical(ef_et_daily_etrf(0.9, 0, reference = "alfalfa"), 0)
  expect_identical(ef_et_daily_etrf(-0.09, 0, reference = "alfalfa") == 0,
                   TRUE)
})

test_that("ef_et_daily_etrf() recycles, keeps dim and propagates NA", {
  expect_silent(
    eta <- ef_et_daily_etrf(c(0.9, -0.09, NA), 8, reference = "grass")
  )
  expect_lt(max(abs(eta[1:2] - c(7.2, -0.72))), tol)
  expect_true(is.na(eta[3]))

  etrf <- matrix(c(0.9, -0.09, 1.2, 0), nrow = 2)
  out <- ef_et_daily_etrf(etrf, 8, reference = "alfalfa")
  expect_identical(dim(out), c(2L, 2L))
  expect_error(ef_et_daily_etrf(etrf, matrix(8, 4, 1), reference = "alfalfa"),
               class = "earthflux_input_error")
  expect_error(ef_et_daily_etrf(numeric(0), 8, reference = "alfalfa"),
               class = "earthflux_input_error")
  expect_error(ef_et_daily_etrf(0.9, "8", reference = "alfalfa"),
               class = "earthflux_input_error")
})

test_that("dispatcher ef_et_daily() is identical to the direct call", {
  etrf <- c(0.9, -0.09, NA, 1.2)
  etr_24 <- c(8, 8, 8, 0)
  expect_identical(
    ef_et_daily(etrf, etr_24, reference = "alfalfa", method = "etrf"),
    ef_et_daily_etrf(etrf, etr_24, reference = "alfalfa")
  )
  m <- matrix(etrf, nrow = 2)
  expect_identical(
    ef_et_daily(m, 8, reference = "grass", method = "etrf"),
    ef_et_daily_etrf(m, 8, reference = "grass")
  )
})

test_that("dispatcher: method has no default and is matched exactly", {
  expect_error(ef_et_daily(0.9, 8, reference = "alfalfa"),
               class = "earthflux_missing_input")
  expect_error(ef_et_daily(0.9, 8, reference = "alfalfa", method = "ETrF"),
               class = "earthflux_unknown_method")
  # Future methods are not available yet.
  expect_error(ef_et_daily(0.9, 8, reference = "alfalfa", method = "evapfrac"),
               class = "earthflux_unknown_method")
  expect_error(ef_et_daily(0.9, 8, reference = "alfalfa", method = NA),
               class = "earthflux_input_error")
})

test_that("dispatcher: missing method arguments raise a classed error", {
  expect_error(ef_et_daily(etr_24 = 8, reference = "alfalfa", method = "etrf"),
               class = "earthflux_missing_input")
  expect_error(ef_et_daily(etrf = 0.9, reference = "alfalfa", method = "etrf"),
               class = "earthflux_missing_input")
  expect_error(ef_et_daily(etrf = 0.9, etr_24 = 8, method = "etrf"),
               class = "earthflux_missing_input")
  # Domain errors of the method pass through the dispatcher.
  expect_error(
    ef_et_daily(0.9, -1, reference = "alfalfa", method = "etrf"),
    class = "earthflux_domain_error"
  )
})

# Full chain (case A) ----------------------------------------------------------

test_that("case A: full chain Rn, G, H -> LE -> ET_inst -> ETrF -> ETa_24", {
  lambda <- ef_lambda(method = "constant")
  le <- ef_latent_heat(rn = 600, g = 60, h = 50)
  et_inst <- ef_et_inst(le, lambda)
  etrf <- ef_etrf(et_inst, etr_inst = 0.80, reference = "alfalfa")
  eta_24 <- ef_et_daily(etrf, etr_24 = 8.0, reference = "alfalfa",
                        method = "etrf")
  expect_lt(abs(le - 490), tol)
  expect_lt(abs(et_inst - 0.72), tol)
  expect_lt(abs(etrf - 0.9), tol)
  expect_lt(abs(eta_24 - 7.2), tol)
  expect_lt(abs(ef_et_inst_to_latent_heat(et_inst, lambda) - le), tol)

  # Case C through the same chain: every negative value is kept.
  le_c <- ef_latent_heat(rn = 400, g = 80, h = 369)
  eta_c <- ef_et_daily_etrf(
    ef_etrf(ef_et_inst(le_c, lambda), 0.80, reference = "alfalfa"),
    8.0, reference = "alfalfa"
  )
  expect_lt(abs(eta_c - (-0.72)), tol)
})

# Diagnostics (section 7) ---------------------------------------------------------

test_that("case C: EF_ET_NEGATIVE is raised on each layer with its indices", {
  # LE = (490, -49, NA, -10) W m-2 (case C at position 2).
  le <- ef_latent_heat(rn = c(600, 400, NA, 500), g = c(60, 80, 60, 60),
                       h = c(50, 369, 50, 450))
  et_inst <- ef_et_inst(le, lambda_fao)
  etrf <- ef_etrf(et_inst, 0.80, reference = "alfalfa")
  eta_24 <- ef_et_daily_etrf(etrf, c(8, 8, 8, 0), reference = "alfalfa")

  flags <- ef_diagnose_et(et_inst = et_inst, eta_24 = eta_24)
  expect_type(flags, "list")
  expect_true(all(vapply(flags, inherits, logical(1), "earthflux_flag")))
  # ETa_24 at position 4 is zero (ETr_24 = 0): flagged on et_inst only.
  expect_named(flags, c("et_inst", "eta_24"))
  expect_identical(flags$et_inst$code, "EF_ET_NEGATIVE")
  expect_identical(flags$et_inst$severity, "warning")
  expect_identical(flags$et_inst$scope, "cell")
  expect_identical(flags$et_inst$index, c(2L, 4L))
  expect_identical(flags$et_inst$n_total, 4L)
  expect_identical(flags$eta_24$index, 2L)

  # The mask ignores NA (position 3) and values are not modified.
  expect_true(is.na(et_inst[3]))
  expect_lt(abs(et_inst[2] - (-0.072)), tol)
  expect_lt(abs(eta_24[2] - (-0.72)), tol)
})

test_that("EF_ET_NEGATIVE is not raised without negative values", {
  et_inst <- ef_et_inst(c(490, 0, NA, 612.5), lambda_fao)
  none <- ef_diagnose_et(et_inst = et_inst)
  expect_type(none, "list")
  expect_length(none, 0L)
  expect_length(ef_diagnose_et(et_inst = et_inst, eta_24 = c(7.2, 0, NA)), 0L)
  expect_length(ef_diagnose_et(), 0L)
  # One layer flagged, the other not.
  flags <- ef_diagnose_et(et_inst = c(0.72, NA), eta_24 = c(-0.72, NA))
  expect_named(flags, "eta_24")
  expect_identical(flags$eta_24$index, 1L)
})

test_that("ef_diagnose_et() rejects non-numeric layers", {
  expect_error(ef_diagnose_et(et_inst = "0.72"),
               class = "earthflux_input_error")
})
