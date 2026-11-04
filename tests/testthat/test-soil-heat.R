# Tests for the soil heat flux (G) stage: ef_g(), ef_g_bastiaanssen(),
# ef_g_tasumi() and the cell diagnostics of the stage.
#
# Specification: dev/specs/soil-heat-flux.md (numeric cases in section 8,
# test design in section 9). Both formulations are CANDIDATA: the cases
# check the implementation of the candidate equations, not their scientific
# validity, and must be recomputed if the primary sources change them.
#
# Tolerance: the expected values below were recomputed from the inputs of
# section 8 with `bc -l` at 30 decimal digits (an arbitrary-precision
# calculation independent of the package code) and are written with 12 or
# more significant digits. Double-precision rounding in these few products
# is of order 1e-15 relative, so a relative tolerance of 1e-10 is far above
# rounding noise and far below any meaningful difference. The values printed
# in the specification are rounded to 5-6 significant digits (e.g. B2:
# 108.349 for 108.34938072), so they are checked after rounding to their
# printed precision (VALIDATION_PLAN.md section 1.2).

tol <- 1e-10

flag_codes <- function(x) vapply(x$flags, `[[`, character(1), "code")

flag_index <- function(x, code) {
  hit <- Filter(function(f) identical(f$code, code), x$flags)
  if (length(hit) == 0L) {
    return(NULL)
  }
  hit[[1L]]$index
}

# Section 8.1: Bastiaanssen (SEBAL) ----------------------------------------------

bast <- data.frame(
  id = c("B1", "B2", "B3", "B4", "B5"),
  rn = c(500, 450, 600, 400, 200),
  lst = c(303.15, 313.15, 298.15, 273.15, 268.15),
  albedo = c(0.20, 0.30, 0.18, 0.20, 0.60),
  ndvi = c(0.50, 0.10, 0.85, 0.30, 0.05),
  ratio = c(0.148698, 0.2407764016, 0.0626660661625, 0, -0.04119974765),
  g = c(74.349, 108.34938072, 37.5996396975, 0, -8.23994953)
)

test_that("Bastiaanssen cases B1-B5 match the hand computation", {
  for (i in seq_len(nrow(bast))) {
    b <- bast[i, ]
    g <- ef_g_bastiaanssen(rn = b$rn, lst = b$lst, albedo = b$albedo,
                           ndvi = b$ndvi)
    expect_type(g, "double")
    expect_length(g, 1L)
    expect_equal(g, b$g, tolerance = tol, info = b$id)
  }
  # Values as printed in the specification (rounded).
  g <- ef_g_bastiaanssen(bast$rn, bast$lst, bast$albedo, bast$ndvi)
  expect_equal(round(g[1:3], 3), c(74.349, 108.349, 37.600))
  expect_equal(round(g[5], 5), -8.23995)
  # B4: Ts = 273.15 K gives exactly zero.
  expect_identical(g[4], 0)
})

test_that("Bastiaanssen G/Rn of B1-B5 matches the hand computation", {
  out <- ef_g(rn = bast$rn, lst = bast$lst, albedo = bast$albedo,
              ndvi = bast$ndvi, method = "bastiaanssen")
  expect_equal(out$g_rn_ratio, bast$ratio, tolerance = tol)
  expect_equal(round(out$g_rn_ratio[c(1, 2, 3, 5)], 7),
                   c(0.1486980, 0.2407764, 0.0626661, -0.0411997))
})

test_that("B6: NDVI enters with an even power (limitation documented)", {
  g_pos <- ef_g_bastiaanssen(500, 303.15, 0.20, 0.50)
  g_neg <- ef_g_bastiaanssen(500, 303.15, 0.20, -0.50)
  expect_identical(g_neg, g_pos)
  expect_equal(g_neg, 74.349, tolerance = tol)
})

test_that("Bastiaanssen accepts the bounds of albedo and NDVI", {
  # albedo = 0 and 1 (Tc = 30, NDVI = 0: last factor = 1).
  expect_equal(ef_g_bastiaanssen(100, 303.15, 0, 0), 30 * 0.0038 * 100,
               tolerance = tol)
  expect_equal(ef_g_bastiaanssen(100, 303.15, 1, 0), 30 * 0.0112 * 100,
               tolerance = tol)
  # NDVI = -1 and 1 give the factor 0.02; NDVI = 0 gives 1.
  g <- ef_g_bastiaanssen(100, 303.15, 0.2, c(-1, 0, 1))
  expect_equal(g, 30 * 0.00528 * c(0.02, 1, 0.02) * 100, tolerance = tol)
})

test_that("Bastiaanssen vectorised result equals the case-by-case result", {
  g_vec <- ef_g_bastiaanssen(bast$rn, bast$lst, bast$albedo, bast$ndvi)
  g_one <- vapply(seq_len(nrow(bast)), function(i) {
    ef_g_bastiaanssen(bast$rn[i], bast$lst[i], bast$albedo[i], bast$ndvi[i])
  }, numeric(1))
  expect_identical(g_vec, g_one)
})

# Section 8.2: Tasumi (METRIC) ---------------------------------------------------

tas <- data.frame(
  id = c("T1", "T2", "T3", "T4", "T5", "T6a", "T6b", "T7", "T8"),
  lai = c(3.0, 0.5, 6.0, 0.2, 0, 0.4999, 0.5, 0.2, 0.2),
  lst = c(300, 300, 300, 318.15, 308.15, 318.15, 318.15, 318.15, 318.15),
  rn = c(550, 500, 600, 400, 350, 400, 400, 40, 0),
  g = c(48.2411541578034, 94.3599540738446, 34.7404460143004, 114.6, 92.4,
        114.6, 75.4879632590757, 84.36, 81)
)

test_that("Tasumi cases T1-T8 match the hand computation", {
  for (i in seq_len(nrow(tas))) {
    t <- tas[i, ]
    g <- ef_g_tasumi(rn = t$rn, lst = t$lst, lai = t$lai)
    expect_type(g, "double")
    expect_length(g, 1L)
    expect_equal(g, t$g, tolerance = tol, info = t$id)
  }
  # Values as printed in the specification (rounded).
  g <- ef_g_tasumi(tas$rn, tas$lst, tas$lai)
  expect_equal(round(g, 3),
                   c(48.241, 94.360, 34.740, 114.600, 92.400, 114.600,
                     75.488, 84.360, 81.000))
})

test_that("Tasumi G/Rn of T1-T7 matches the hand computation", {
  out <- ef_g(rn = tas$rn, lst = tas$lst, lai = tas$lai, method = "tasumi")
  expected <- c(0.0877111893778243, 0.188719908147689, 0.0579007433571674,
                0.2865, 0.264, 0.2865, 0.188719908147689, 2.109)
  expect_equal(out$g_rn_ratio[1:8], expected, tolerance = tol)
  expect_equal(round(out$g_rn_ratio[c(1:5, 8)], 6),
                   c(0.087711, 0.188720, 0.057901, 0.286500, 0.264000,
                     2.109000))
  # T8: Rn = 0, ratio undefined.
  expect_identical(out$g_rn_ratio[9], NA_real_)
})

test_that("T6: LAI = 0.5 belongs to the vegetated branch (discontinuity)", {
  g <- ef_g_tasumi(rn = 400, lst = 318.15, lai = c(0.4999, 0.5))
  expect_equal(g, c(114.6, 75.4879632590757), tolerance = tol)
  # The vegetated branch does not depend on Ts.
  expect_identical(ef_g_tasumi(400, 280, 0.5), ef_g_tasumi(400, 330, 0.5))
  out <- ef_g(rn = 400, lst = 318.15, lai = c(0.4999, 0.5),
              method = "tasumi")
  expect_identical(out$branch, c("lai_lt_0.5", "lai_ge_0.5"))
})

test_that("Tasumi vectorised result equals the case-by-case result", {
  g_vec <- ef_g_tasumi(tas$rn, tas$lst, tas$lai)
  g_one <- vapply(seq_len(nrow(tas)), function(i) {
    ef_g_tasumi(tas$rn[i], tas$lst[i], tas$lai[i])
  }, numeric(1))
  expect_identical(g_vec, g_one)
})

# Units -------------------------------------------------------------------------

test_that("G is returned in W m-2 and lst is read in K", {
  g <- ef_g_bastiaanssen(500, 303.15, 0.20, 0.50)
  expect_equal(g, 74.349, tolerance = tol)
  expect_gt(abs(g - 0.074349), 1)
  expect_gt(abs(g - 74349), 1)
  # lst given in degrees C (30) is accepted (> 0) but does not reproduce B1.
  expect_false(isTRUE(all.equal(ef_g_bastiaanssen(500, 30, 0.20, 0.50), g)))
  expect_false(isTRUE(all.equal(ef_g_tasumi(400, 45, 0.2), 114.6)))
})

# Edges ---------------------------------------------------------------------------

test_that("negative and zero Rn are accepted and returned unchanged", {
  g <- expect_silent(ef_g_tasumi(rn = c(-50, 0), lst = 290, lai = 3))
  expect_equal(g, c(-50, 0) * 0.0877111893778243, tolerance = tol)
  g <- expect_silent(ef_g_tasumi(rn = -50, lst = 318.15, lai = 0))
  expect_equal(g, 81 - 0.084 * 50, tolerance = tol)
  g <- expect_silent(ef_g_bastiaanssen(-100, 303.15, 0.2, 0.5))
  expect_equal(g, -100 * 0.148698, tolerance = tol)
})

test_that("integer inputs are accepted", {
  expect_equal(ef_g_tasumi(400L, 318.15, 0L), 114.6, tolerance = tol)
  expect_identical(ef_g_bastiaanssen(400L, 273.15, 0L, 0L), 0)
})

test_that("scalar arguments are recycled to the common length", {
  g <- ef_g_tasumi(rn = 400, lst = 318.15, lai = c(0.2, 0.5, 3))
  expect_length(g, 3L)
  expect_equal(g[1:2], c(114.6, 75.4879632590757), tolerance = tol)
})

# Missing values ------------------------------------------------------------------

test_that("NA in any Bastiaanssen input gives NA only at that position", {
  args <- list(rn = rep(500, 5), lst = rep(303.15, 5),
               albedo = rep(0.2, 5), ndvi = rep(0.5, 5))
  for (j in seq_along(args)) {
    a <- args
    a[[j]][j] <- NA
    g <- expect_silent(do.call(ef_g_bastiaanssen, a))
    expect_identical(which(is.na(g)), j, info = names(args)[j])
    expect_equal(g[-j], rep(74.349, 4), tolerance = tol)
  }
  expect_true(is.na(ef_g_bastiaanssen(NaN, 303.15, 0.2, 0.5)))
})

test_that("NA in any Tasumi input gives NA only at that position", {
  args <- list(rn = rep(400, 4), lst = rep(318.15, 4), lai = c(0.2, 3, 3, 3))
  for (j in seq_along(args)) {
    a <- args
    a[[j]][j] <- NA
    g <- expect_silent(do.call(ef_g_tasumi, a))
    expect_identical(which(is.na(g)), j, info = names(args)[j])
  }
  expect_true(is.na(ef_g_tasumi(400, NaN, 0.2)))
  expect_true(is.na(ef_g_tasumi(400, 318.15, NaN)))
})

test_that("Tasumi: NA lst gives NA also in the vegetated branch (G-D5)", {
  g <- ef_g_tasumi(rn = 550, lst = c(NA, 300), lai = 3)
  expect_identical(is.na(g), c(TRUE, FALSE))
  expect_equal(g[2], 48.2411541578034, tolerance = tol)
})

test_that("EF_INPUT_NA marks the positions with a missing required input", {
  out <- ef_g(rn = c(400, NA, 400, 400), lst = c(318.15, 318.15, NA, 318.15),
              lai = c(0.2, 3, 3, NaN), method = "tasumi")
  expect_identical(which(is.na(out$g)), 2:4)
  expect_identical(flag_index(out, "EF_INPUT_NA"), 2:4)
  expect_identical(out$branch, c("lai_lt_0.5", NA, NA, NA))
  # Arguments not used by the method do not raise EF_INPUT_NA.
  out <- ef_g(rn = 400, lst = 318.15, lai = 0.2, ndvi = NA_real_,
              method = "tasumi")
  expect_false("EF_INPUT_NA" %in% flag_codes(out))
})

# Classed errors ---------------------------------------------------------------

test_that("impossible values raise a classed domain error", {
  expect_error(ef_g_bastiaanssen(500, 303.15, -0.01, 0.5),
               class = "earthflux_domain_error")
  expect_error(ef_g_bastiaanssen(500, 303.15, 1.01, 0.5),
               class = "earthflux_domain_error")
  expect_error(ef_g_bastiaanssen(500, 303.15, 1.01, 0.5), "`albedo`")
  expect_error(ef_g_bastiaanssen(500, 303.15, 0.2, -1.01),
               class = "earthflux_domain_error")
  expect_error(ef_g_bastiaanssen(500, 303.15, 0.2, 1.01), "`ndvi`")
  expect_error(ef_g_tasumi(400, 318.15, -0.1),
               class = "earthflux_domain_error")
  expect_error(ef_g_tasumi(400, 318.15, -0.1), "`lai`")
  for (lst in c(0, -10)) {
    expect_error(ef_g_tasumi(400, lst, 3), class = "earthflux_domain_error")
    expect_error(ef_g_bastiaanssen(500, lst, 0.2, 0.5),
                 class = "earthflux_domain_error")
  }
  expect_error(ef_g_tasumi(400, c(300, 0, -1), 3), "`lst`.*2 value")
})

test_that("the dispatcher propagates domain errors", {
  cnd <- tryCatch(
    ef_g(rn = 500, lst = 303.15, albedo = 2, ndvi = 0.5,
         method = "bastiaanssen"),
    error = identity
  )
  expect_s3_class(cnd, "earthflux_domain_error")
  expect_s3_class(cnd, "earthflux_input_error")
  expect_s3_class(cnd, "earthflux_error")
})

test_that("infinite values are rejected for every argument", {
  ref_b <- list(rn = 500, lst = 303.15, albedo = 0.2, ndvi = 0.5)
  for (nm in names(ref_b)) {
    a <- ref_b
    a[[nm]] <- Inf
    expect_error(do.call(ef_g_bastiaanssen, a),
                 class = "earthflux_domain_error", info = nm)
  }
  ref_t <- list(rn = 400, lst = 318.15, lai = 0.2)
  for (nm in names(ref_t)) {
    a <- ref_t
    a[[nm]] <- -Inf
    expect_error(do.call(ef_g_tasumi, a),
                 class = "earthflux_domain_error", info = nm)
  }
  expect_error(ef_g_tasumi(Inf, 318.15, 0.2), "infinite")
})

test_that("non-numeric inputs raise a classed input error", {
  expect_error(ef_g_tasumi("400", 318.15, 0.2),
               class = "earthflux_input_error")
  expect_error(ef_g_tasumi(400, 318.15, TRUE),
               class = "earthflux_input_error")
  expect_error(ef_g_bastiaanssen(500, 303.15, factor(1), 0.5),
               class = "earthflux_input_error")
  expect_error(ef_g_bastiaanssen(500, NA, 0.2, 0.5), "`lst` must be numeric")
})

test_that("incompatible or zero lengths raise a classed input error", {
  expect_error(ef_g_tasumi(c(400, 300, 200), c(300, 310), 3),
               class = "earthflux_input_error")
  expect_error(ef_g_tasumi(c(400, 300, 200), c(300, 310), 3),
               "common length")
  expect_error(ef_g_tasumi(numeric(0), 300, 3),
               class = "earthflux_input_error")
  expect_error(ef_g_bastiaanssen(500, 303.15, numeric(0), 0.5),
               class = "earthflux_input_error")
})

test_that("matrix inputs keep their dim; different dims are rejected", {
  lai <- matrix(c(0.2, 3, 0.5, 6), nrow = 2)
  g <- ef_g_tasumi(rn = 400, lst = 318.15, lai = lai)
  expect_identical(dim(g), c(2L, 2L))
  expect_equal(as.vector(g), ef_g_tasumi(400, 318.15, as.vector(lai)),
               tolerance = tol)
  out <- ef_g(rn = 400, lst = 318.15, lai = lai, method = "tasumi")
  expect_identical(dim(out$g), c(2L, 2L))
  expect_identical(dim(out$g_rn_ratio), c(2L, 2L))
  expect_identical(dim(out$branch), c(2L, 2L))
  expect_identical(out$branch[1, 1], "lai_lt_0.5")
  expect_identical(flag_index(out, "EF_G_LOW_LAI_BRANCH"), 1L)

  ndvi <- matrix(0.5, 2, 2)
  g <- ef_g_bastiaanssen(500, 303.15, 0.2, ndvi)
  expect_identical(dim(g), c(2L, 2L))
  expect_error(ef_g_bastiaanssen(500, 303.15, matrix(0.2, 1, 4), ndvi),
               class = "earthflux_input_error")
})

# Dispatcher ---------------------------------------------------------------------

test_that("a missing or unknown method raises a classed error", {
  expect_error(ef_g(rn = 400, lst = 318.15, lai = 0.2),
               class = "earthflux_missing_input")
  for (m in c("Tasumi", "tas", "metric", "Bastiaanssen")) {
    expect_error(ef_g(rn = 400, lst = 318.15, lai = 0.2, method = m),
                 class = "earthflux_unknown_method", info = m)
  }
  expect_error(ef_g(rn = 400, lst = 318.15, lai = 0.2, method = "tas"),
               class = "earthflux_input_error")
  expect_error(ef_g(rn = 400, lai = 0.2, method = c("tasumi", "x")),
               class = "earthflux_input_error")
})

test_that("an input required by the method raises earthflux_missing_input", {
  expect_error(ef_g(rn = 400, lai = 0.2, method = "tasumi"),
               class = "earthflux_missing_input")
  expect_error(ef_g(rn = 400, lai = 0.2, method = "tasumi"), "`lst`")
  expect_error(ef_g(lst = 318.15, lai = 0.2, method = "tasumi"),
               class = "earthflux_missing_input")
  expect_error(ef_g(rn = NULL, lst = 318.15, lai = 0.2, method = "tasumi"),
               class = "earthflux_missing_input")
  expect_error(ef_g(rn = 500, lst = 303.15, albedo = 0.2,
                    method = "bastiaanssen"),
               class = "earthflux_missing_input")
  expect_error(ef_g(rn = 500, lst = 303.15, albedo = 0.2,
                    method = "bastiaanssen"),
               "`ndvi`")
  # lai is not required by Bastiaanssen, nor albedo/ndvi by Tasumi.
  expect_error(ef_g(rn = 400, lst = 318.15, albedo = 0.2, ndvi = 0.5,
                    method = "tasumi"),
               class = "earthflux_missing_input")
})

test_that("the dispatcher is identical to the direct call", {
  out <- ef_g(rn = bast$rn, lst = bast$lst, albedo = bast$albedo,
              ndvi = bast$ndvi, method = "bastiaanssen")
  expect_identical(
    out$g,
    ef_g_bastiaanssen(bast$rn, bast$lst, bast$albedo, bast$ndvi)
  )
  out <- ef_g(rn = tas$rn, lst = tas$lst, lai = tas$lai, method = "tasumi")
  expect_identical(out$g, ef_g_tasumi(tas$rn, tas$lst, tas$lai))
})

test_that("arguments not used by the method do not alter the result", {
  a <- ef_g(rn = 400, lst = 318.15, lai = c(0.2, 3), method = "tasumi")
  b <- ef_g(rn = 400, lst = 318.15, lai = c(0.2, 3), albedo = 0.9,
            ndvi = -0.8, method = "tasumi")
  expect_identical(a, b)
  a <- ef_g(rn = 500, lst = 303.15, albedo = 0.2, ndvi = 0.5,
            method = "bastiaanssen")
  b <- ef_g(rn = 500, lst = 303.15, albedo = 0.2, ndvi = 0.5, lai = 99,
            method = "bastiaanssen")
  expect_identical(a, b)
})

test_that("the dispatcher returns the documented object", {
  out <- ef_g(rn = tas$rn, lst = tas$lst, lai = tas$lai, method = "tasumi")
  expect_s3_class(out, "earthflux_soil_heat_flux")
  expect_true(is.list(out))
  expect_named(out, c("g", "g_rn_ratio", "method", "branch", "flags",
                      "provenance"))
  expect_identical(out$method, "tasumi")
  expect_identical(
    out$branch,
    ifelse(tas$lai < 0.5, "lai_lt_0.5", "lai_ge_0.5")
  )
  p <- out$provenance
  expect_identical(p$method, "tasumi")
  expect_identical(p$fun, "ef_g_tasumi")
  expect_identical(p$status, "CANDIDATA")
  expect_identical(p$kelvin_offset, 273.15)
  expect_identical(p$coefficients$lai_threshold, 0.5)
  expect_identical(p$inputs, c("rn", "lst", "lai"))
  expect_true(any(grepl("Tasumi (2003)", p$references, fixed = TRUE)))
  expect_identical(p$earthflux_version,
                   as.character(utils::packageVersion("EarthFlux")))

  out <- ef_g(rn = 500, lst = 303.15, albedo = 0.2, ndvi = 0.5,
              method = "bastiaanssen")
  expect_named(out, c("g", "g_rn_ratio", "method", "branch", "flags",
                      "provenance"))
  expect_null(out$branch)
  expect_identical(out$provenance$fun, "ef_g_bastiaanssen")
  expect_identical(out$provenance$inputs, c("rn", "lst", "albedo", "ndvi"))
  expect_identical(out$provenance$coefficients$c_ndvi, 0.98)
  expect_true(any(grepl("10.1016/S0022-1694(99)00202-4",
                        out$provenance$references, fixed = TRUE)))
})

test_that("g_rn_ratio * rn equals g where rn != 0 and is NA where rn = 0", {
  rn <- c(400, -50, 0, 40)
  out <- ef_g(rn = rn, lst = 318.15, lai = c(3, 3, 0.2, 0.2),
              method = "tasumi")
  nz <- rn != 0
  expect_equal(out$g_rn_ratio[nz] * rn[nz], out$g[nz])
  expect_identical(out$g_rn_ratio[!nz], NA_real_)
  out <- ef_g(rn = 0, lst = 303.15, albedo = 0.2, ndvi = 0.5,
              method = "bastiaanssen")
  expect_identical(out$g, 0)
  expect_identical(out$g_rn_ratio, NA_real_)
})

# Flags -------------------------------------------------------------------------

test_that("the stage registers its class I codes with the documented bits", {
  reg <- ef_flag_registry()
  g_rows <- reg[reg$stage == "G", ]
  expect_identical(
    g_rows$code,
    c("EF_G_RN_NONPOSITIVE", "EF_G_RATIO_NEGATIVE",
      "EF_G_AVAILABLE_NONPOSITIVE", "EF_G_LOW_LAI_BRANCH")
  )
  expect_identical(g_rows$bit, 1:4)
  expect_identical(g_rows$severity, c("warning", "warning", "warning", "info"))
  expect_true(all(g_rows$scope == "cell"))
  # Class II codes stay unregistered (decisions G-D4 and G-D7).
  expect_false(any(c("EF_G_NDVI_NONPOSITIVE", "EF_G_RATIO_IMPLAUSIBLE",
                     "EF_G_EXCEEDS_RN") %in% reg$code))
  expect_error(ef_flag(TRUE, "EF_G_RATIO_IMPLAUSIBLE"),
               class = "earthflux_unknown_flag")
})

test_that("B5: a negative ratio is flagged and kept unchanged", {
  out <- ef_g(rn = c(200, 500), lst = c(268.15, 303.15),
              albedo = c(0.60, 0.20), ndvi = c(0.05, 0.50),
              method = "bastiaanssen")
  expect_identical(flag_codes(out), "EF_G_RATIO_NEGATIVE")
  expect_identical(flag_index(out, "EF_G_RATIO_NEGATIVE"), 1L)
  expect_equal(out$g[1], -8.23994953, tolerance = tol)
  f <- out$flags[[1]]
  expect_s3_class(f, "earthflux_flag")
  expect_identical(f$stage, "G")
  expect_identical(f$scope, "cell")
  expect_identical(f$n_total, 2L)
})

test_that("B4 and B6 raise no flag (EF_G_NDVI_NONPOSITIVE is class II)", {
  out <- ef_g(rn = c(400, 500), lst = c(273.15, 303.15),
              albedo = 0.2, ndvi = c(0.3, -0.5), method = "bastiaanssen")
  expect_identical(out$flags, list())
})

test_that("T7: available energy Rn - G <= 0 is flagged and kept", {
  out <- ef_g(rn = c(400, 40), lst = 318.15, lai = 0.2, method = "tasumi")
  expect_identical(flag_index(out, "EF_G_AVAILABLE_NONPOSITIVE"), 2L)
  expect_null(flag_index(out, "EF_G_RN_NONPOSITIVE"))
  expect_equal(out$g[2], 84.36, tolerance = tol)
  expect_equal(out$g_rn_ratio[2], 2.109, tolerance = tol)
})

test_that("T8: Rn = 0 is flagged; G is computed without division", {
  out <- ef_g(rn = 0, lst = 318.15, lai = 0.2, method = "tasumi")
  expect_equal(out$g, 81, tolerance = tol)
  expect_identical(
    flag_codes(out),
    c("EF_G_RN_NONPOSITIVE", "EF_G_AVAILABLE_NONPOSITIVE",
      "EF_G_LOW_LAI_BRANCH")
  )
  expect_false("EF_G_RATIO_NEGATIVE" %in% flag_codes(out))
})

test_that("negative Rn: RN_NONPOSITIVE, and RATIO_NEGATIVE only if G > 0", {
  out <- ef_g(rn = c(-50, -50), lst = 318.15, lai = c(3, 0.2),
              method = "tasumi")
  # Vegetated: G < 0, ratio > 0. Bare soil: G = 81 - 4.2 > 0, ratio < 0.
  expect_identical(flag_index(out, "EF_G_RN_NONPOSITIVE"), 1:2)
  expect_identical(flag_index(out, "EF_G_RATIO_NEGATIVE"), 2L)
  expect_identical(flag_index(out, "EF_G_AVAILABLE_NONPOSITIVE"), 1:2)
})

test_that("T4: the bare-soil branch is flagged only for Tasumi", {
  out <- ef_g(rn = 400, lst = 318.15, lai = c(3, 0.2, 0.5, 0),
              method = "tasumi")
  expect_identical(flag_codes(out), "EF_G_LOW_LAI_BRANCH")
  expect_identical(flag_index(out, "EF_G_LOW_LAI_BRANCH"), c(2L, 4L))
  expect_identical(out$flags[[1]]$severity, "info")
  out <- ef_g(rn = c(550, 600), lst = 300, lai = c(3, 6), method = "tasumi")
  expect_identical(out$flags, list())
})

test_that("flagged values are identical to the method function", {
  out <- ef_g(rn = tas$rn, lst = tas$lst, lai = tas$lai, method = "tasumi")
  expect_true(length(out$flags) > 0L)
  expect_identical(out$g, ef_g_tasumi(tas$rn, tas$lst, tas$lai))
})

test_that("cell diagnostics ignore missing values", {
  flags <- ef_diagnose_soil_heat(
    rn = c(NA, -1, 10), g = c(5, NA, 20), g_rn_ratio = c(NA, NA, 2),
    low_lai = c(FALSE, FALSE, TRUE)
  )
  codes <- vapply(flags, `[[`, character(1), "code")
  expect_identical(
    codes,
    c("EF_G_RN_NONPOSITIVE", "EF_G_AVAILABLE_NONPOSITIVE",
      "EF_G_LOW_LAI_BRANCH")
  )
  expect_identical(flags[[1]]$index, 2L)
  expect_identical(flags[[2]]$index, 3L)
  expect_identical(
    ef_diagnose_soil_heat(rn = 400, g = 50, g_rn_ratio = 0.125),
    list()
  )
})

# Chaining with the net radiation ---------------------------------------------------

test_that("G chains with ef_net_radiation()", {
  # Reference case of ef_net_radiation(): Rn = 503.5154 W m-2.
  rn <- ef_net_radiation(rs_in = c(800, 800), albedo = 0.20, rl_in = 320,
                         rl_out = 450.0846, emissivity = 0.98)
  expect_equal(rn, rep(503.5154, 2), tolerance = tol)

  out <- ef_g(rn = rn, lst = c(300, 318.15), lai = c(3, 0.2),
              method = "tasumi")
  expect_equal(out$g[1], 503.5154 * 0.0877111893778243, tolerance = tol)
  expect_equal(out$g[2], 81 + 0.084 * 503.5154, tolerance = tol)
  expect_identical(flag_codes(out), "EF_G_LOW_LAI_BRANCH")
  # Available energy for H and LE.
  expect_true(all(rn - out$g > 0))

  out <- ef_g(rn = rn[1], lst = 303.15, albedo = 0.20, ndvi = 0.50,
              method = "bastiaanssen")
  expect_equal(out$g, 503.5154 * 0.148698, tolerance = tol)
  expect_equal(out$g_rn_ratio, 0.148698, tolerance = tol)
})
