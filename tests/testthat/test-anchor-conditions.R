# Tests for the boundary conditions at the anchor pixels (stage [B]):
# ef_anchor_conditions().
#
# Specification: dev/specs/anchor-pixels.md sections 2.2-2.5 (numerical
# illustration of section 2.5), decisions D-AP-03 to D-AP-06 and P0-7 to P0-9
# (dev/DECISIONS.md); interface consumed by the sensible heat calibration:
# dev/specs/sensible-heat.md sections 2.2-2.3. Coefficients are test values
# (CANDIDATA), not defaults.

# lambda of section 2.5 (form observed in `water`, evaluated at Ts = 300 K):
# (2.501 - 0.002361 * (300 - 273.15)) * 1e6 J kg-1
lambda_25 <- 2.43760715e6

# One cold anchor (cell 1) and one hot anchor (cell 2) on a 3-cell transect.
cond_anchors <- function() {
  ef_anchors(cold = 1, hot = 2, lst = c(300, 321, 310),
             ndvi = c(0.85, 0.10, 0.40), albedo = c(0.20, 0.25, 0.20),
             elevation = c(500, 520, 510), aggregate = "none")
}

cond <- function(anchors = cond_anchors(), etr_inst = 0.80, ...) {
  args <- list(anchors = anchors, rn = c(700, 500, 600), g = c(100, 120, 110),
               etr_inst = etr_inst, lambda = lambda_25, etrf_cold = 1.05,
               reference = "alfalfa", source = "test values",
               status = "CANDIDATA")
  extra <- list(...)
  if (!any(c("etrf_hot", "le_hot") %in% names(extra))) {
    extra$etrf_hot <- 0
  }
  args[names(extra)] <- extra
  do.call(ef_anchor_conditions, args)
}

codes_of <- function(x) vapply(x$flags, `[[`, "", "code")

test_that("section 2.5: cold anchor targets and sensitivity to ETr_inst", {
  b <- cond()
  cp <- b$calibration_points
  cold <- cp[cp$type == "cold", ]
  # exact arithmetic, and the values of section 2.5 (printed to 3-4
  # decimals there, hence the looser tolerance)
  expect_equal(cold$le_target, 1.05 * 0.80 * lambda_25 / 3600,
               tolerance = 1e-12)
  expect_equal(cold$h_target, 600 - 1.05 * 0.80 * lambda_25 / 3600,
               tolerance = 1e-12)
  expect_equal(cold$le_target, 568.775, tolerance = 1e-6)
  expect_equal(cold$h_target, 31.225, tolerance = 1e-6)
  expect_identical(cold$etrf, 1.05)
  expect_false("EF_ANCHOR_COLD_H_NEGATIVE" %in% codes_of(b))

  up <- cond(etr_inst = 0.88)
  cold <- up$calibration_points[up$calibration_points$type == "cold", ]
  expect_equal(cold$le_target, 625.6525, tolerance = 1e-6)
  expect_equal(cold$h_target, -25.6525, tolerance = 1e-6)
  f <- up$flags[[match("EF_ANCHOR_COLD_H_NEGATIVE", codes_of(up))]]
  expect_identical(f$scope, "record")
  expect_identical(f$index, 1L)
  expect_identical(f$n_total, 2L)

  down <- cond(etr_inst = 0.72)
  cold <- down$calibration_points[down$calibration_points$type == "cold", ]
  expect_equal(cold$le_target, 511.8975, tolerance = 1e-6)
  expect_equal(cold$h_target, 88.1025, tolerance = 1e-6)
})

test_that("the calibration points carry what the H calibration consumes", {
  b <- cond()
  cp <- b$calibration_points
  expect_named(cp, c("anchor_id", "type", "n_pixels", "aggregate", "lst",
                     "ndvi", "albedo", "lai", "elevation", "utc_hour", "rn",
                     "g", "etr_inst", "lambda", "etrf", "le_target",
                     "h_target"))
  expect_identical(cp$type, c("cold", "hot"))
  expect_identical(cp$lst, c(300, 321))
  expect_identical(cp$elevation, c(500, 520))
  expect_identical(cp$rn, c(700, 500))
  expect_identical(cp$g, c(100, 120))
  expect_identical(cp$h_target, cp$rn - cp$g - cp$le_target)
  # hot anchor: ETrF = 0, LE = 0, H = Rn - G
  expect_identical(cp$le_target[2L], 0)
  expect_identical(cp$h_target[2L], 380)
  expect_identical(b$conditions$reference, "alfalfa")
  expect_identical(b$conditions$hot_condition, "etrf")
  expect_identical(b$conditions$status, "CANDIDATA")
  expect_identical(nrow(b$conditions$pixels), 2L)
  expect_s3_class(b, "earthflux_anchors")
  expect_output(print(b), "H target cold = 31.22")
})

test_that("ETrF of the cold anchor is recovered with the same lambda", {
  # inverse conversion ET_inst = 1000 * 3600 * LE / (lambda * rho_w)
  b <- cond(lambda = ef_lambda(method = "constant"))
  cp <- b$calibration_points
  et_cold <- 1000 * 3600 * cp$le_target[1L] / (cp$lambda[1L] * 1000)
  expect_equal(et_cold / cp$etr_inst[1L], 1.05, tolerance = sqrt(.Machine$double.eps))
  expect_identical(cp$lambda, rep(2.45e6, 2L))
})

test_that("the hot condition is explicit: etrf_hot or le_hot", {
  zero <- cond(etrf_hot = 0)
  expect_true("EF_ANCHOR_HOT_LE_ASSUMED_ZERO" %in% codes_of(zero))

  wet <- cond(etrf_hot = 0.1)
  expect_false("EF_ANCHOR_HOT_LE_ASSUMED_ZERO" %in% codes_of(wet))
  hot <- wet$calibration_points[2L, ]
  expect_equal(hot$le_target, 0.1 * 0.8 * lambda_25 / 3600, tolerance = 1e-12)
  expect_identical(hot$h_target, 380 - hot$le_target)

  le <- cond(le_hot = 25)
  hot <- le$calibration_points[2L, ]
  expect_identical(hot$le_target, 25)
  expect_identical(hot$h_target, 355)
  expect_equal(hot$etrf, 25 / (0.8 * lambda_25 / 3600), tolerance = 1e-12)
  expect_identical(le$conditions$hot_condition, "le")
  expect_false("EF_ANCHOR_HOT_LE_ASSUMED_ZERO" %in% codes_of(le))
  expect_true("EF_ANCHOR_HOT_LE_ASSUMED_ZERO" %in%
                codes_of(cond(le_hot = 0)))

  expect_error(cond(etrf_hot = 0, le_hot = 0),
               class = "earthflux_missing_input")
  a <- cond_anchors()
  expect_error(
    ef_anchor_conditions(a, rn = c(700, 500, 600), g = c(100, 120, 110),
                         etr_inst = 0.8, lambda = lambda_25, etrf_cold = 1.05,
                         reference = "alfalfa", source = "test",
                         status = "CANDIDATA"),
    class = "earthflux_missing_input"
  )
  expect_error(cond(etrf_hot = -0.1), class = "earthflux_domain_error")
  expect_error(cond(le_hot = c(1, 2)), class = "earthflux_input_error")
})

test_that("ETr_inst and lambda are evaluated at each anchor pixel", {
  lst <- matrix(c(300, 301, 320,
                  300, 310, 321,
                  305, 310, 315), nrow = 3, byrow = TRUE)
  a <- ef_anchors(cold = c(1, 4), hot = c(3, 6), lst = lst,
                  ndvi = matrix(0.5, 3, 3), albedo = matrix(0.2, 3, 3),
                  utc_hour = matrix(c(15.0, 15.0, 15.1,
                                      15.2, 15.0, 15.1,
                                      15.0, 15.0, 15.0), 3, byrow = TRUE),
                  aggregate = "mean")
  expect_true("EF_ANCHOR_OVERPASS_SPREAD" %in% codes_of(a))
  etr <- matrix(c(0.70, 0.80, 0.75,
                  0.90, 0.80, 0.85,
                  0.80, 0.80, 0.80), nrow = 3, byrow = TRUE)
  rn <- matrix(600, 3, 3)
  g <- matrix(80, 3, 3)
  b <- ef_anchor_conditions(a, rn = rn, g = g, etr_inst = etr,
                            lambda = 2.45e6, etrf_cold = 1.05, etrf_hot = 0,
                            reference = "grass", source = "test",
                            status = "TODO", etr_source = "gwr")
  px <- b$conditions$pixels
  expect_identical(px$cell, c(1L, 4L, 3L, 6L))
  expect_identical(px$etr_inst, c(0.70, 0.90, 0.75, 0.85))
  expect_identical(px$utc_hour, c(15.0, 15.2, 15.1, 15.1))
  le_px <- 1.05 * c(0.70, 0.90) * 2.45e6 / 3600
  expect_equal(px$le_target[1:2], le_px, tolerance = 1e-12)
  cp <- b$calibration_points
  expect_equal(cp$etr_inst[1L], 0.8, tolerance = 1e-12)
  expect_equal(cp$le_target[1L], mean(le_px), tolerance = 1e-12)
  expect_identical(cp$h_target, cp$rn - cp$g - cp$le_target)
  expect_true(b$conditions$etr_inst_layer)
  expect_false(b$conditions$lambda_layer)
  expect_identical(b$conditions$etr_source, "gwr")
  # dispersion of the boundary values is recorded
  d <- b$dispersion
  expect_equal(d$sd[d$type == "cold" & d$variable == "etr_inst"],
               sd(c(0.7, 0.9)), tolerance = 1e-12)
  expect_identical(d$max[d$type == "cold" & d$variable == "le_target"],
                   max(px$le_target[1:2]))

  # median aggregate keeps the identity h = rn - g - le at the point
  am <- ef_anchors(cold = c(1, 4, 2), hot = c(3, 6), lst = lst,
                   ndvi = matrix(0.5, 3, 3), albedo = matrix(0.2, 3, 3),
                   aggregate = "median")
  bm <- ef_anchor_conditions(am, rn = rn, g = g, etr_inst = etr,
                             lambda = 2.45e6, etrf_cold = 1.05, etrf_hot = 0,
                             reference = "alfalfa", source = "test",
                             status = "TODO")
  expect_identical(bm$calibration_points$etr_inst[1L], 0.8)
  expect_identical(bm$calibration_points$h_target,
                   bm$calibration_points$rn - bm$calibration_points$g -
                     bm$calibration_points$le_target)
})

test_that("recomputing the conditions replaces the stage [B] flags", {
  b <- cond(etr_inst = 0.88)
  b2 <- cond(b, etr_inst = 0.72)
  expect_false("EF_ANCHOR_COLD_H_NEGATIVE" %in% codes_of(b2))
  expect_identical(sum(codes_of(b2) == "EF_ANCHOR_HOT_LE_ASSUMED_ZERO"), 1L)
  expect_identical(sum(codes_of(b2) == "EF_ANCHOR_USER_SUPPLIED"), 1L)
  expect_identical(sum(b2$dispersion$variable == "h_target"), 2L)
  expect_equal(b2$calibration_points$h_target[1L], 88.1025, tolerance = 1e-6)
})

test_that("inputs of the boundary conditions are validated", {
  a <- cond_anchors()
  expect_error(cond(lambda = 2.45), class = "earthflux_domain_error")
  expect_error(cond(etr_inst = 0), class = "earthflux_domain_error")
  expect_error(cond(etr_inst = c(0.8, -0.1, 0.8)),
               class = "earthflux_domain_error")
  expect_error(cond(etr_inst = c(0.8, 0.8)), class = "earthflux_input_error")
  expect_error(cond(rn = c(700, 500)), class = "earthflux_input_error")
  expect_error(cond(rn = matrix(c(700, 500, 600), 1)),
               class = "earthflux_input_error")
  expect_error(cond(g = c(100, Inf, 110)), class = "earthflux_domain_error")
  expect_error(cond(etrf_cold = 0), class = "earthflux_domain_error")
  expect_error(cond(etrf_cold = NA_real_), class = "earthflux_input_error")
  expect_error(cond(reference = "ETr"), class = "earthflux_unknown_method")
  expect_error(cond(status = "ok"), class = "earthflux_unknown_method")
  expect_error(cond(anchors = list()), class = "earthflux_input_error")
  expect_error(
    ef_anchor_conditions(a, rn = c(700, 500, 600), g = c(100, 120, 110),
                         etr_inst = 0.8, lambda = lambda_25, etrf_cold = 1.05,
                         etrf_hot = 0, source = "test", status = "CANDIDATA"),
    class = "earthflux_missing_input"
  )
  e <- expect_error(cond(rn = c(NA, 500, 600)),
                    class = "earthflux_anchor_na_input")
  expect_identical(e$variable, "rn")
  expect_identical(e$index, 1L)
  expect_s3_class(e, "earthflux_anchor_error")
  # a missing value away from the anchors is not an error
  expect_s3_class(cond(rn = c(700, 500, NA)), "earthflux_anchors")
  e <- expect_error(cond(etr_inst = c(0.8, NA, 0.8)),
                    class = "earthflux_anchor_na_input")
  expect_identical(e$variable, "etr_inst")
  expect_identical(e$index, 2L)
})

# Interface with the sensible heat calibration ----------------------------------
# ef_calibrate_h() (dev/specs/sensible-heat.md sections 2.2-2.3) reads
# `calibration_points`: one row per class with the columns below.
h_required <- c("type", "lst", "elevation", "zom", "rn", "g", "le_target",
                "u_blend", "pressure")

test_that("zom, u_blend and pressure are passed through to the points", {
  b <- cond(zom = c(0.08, 0.005, 0.03), u_blend = 4.2,
            pressure = ef_air_pressure(c(500, 520, 510)))
  cp <- b$calibration_points
  expect_true(all(c("anchor_id", h_required) %in% names(cp)))
  expect_identical(names(cp)[18:20], c("zom", "u_blend", "pressure"))
  expect_identical(nrow(cp), 2L)
  expect_identical(sort(cp$type), c("cold", "hot"))
  expect_identical(cp$zom, c(0.08, 0.005))
  expect_identical(cp$u_blend, c(4.2, 4.2))
  expect_identical(cp$pressure, ef_air_pressure(c(500, 520)))
  expect_identical(cp$elevation, c(500, 520))
  expect_identical(b$conditions$pixels$zom, c(0.08, 0.005))
  expect_identical(b$conditions$passthrough, c("zom", "u_blend", "pressure"))
  expect_true("zom" %in% b$dispersion$variable)
  # the boundary conditions do not depend on them
  ref <- cond()
  expect_identical(cp[, names(ref$calibration_points)], ref$calibration_points)
  expect_false(any(c("zom", "u_blend", "pressure") %in%
                     names(ref$calibration_points)))

  expect_error(cond(zom = 0), class = "earthflux_domain_error")
  expect_error(cond(u_blend = -1), class = "earthflux_domain_error")
  expect_error(cond(pressure = c(90, 90)), class = "earthflux_input_error")
  e <- expect_error(cond(zom = c(NA, 0.005, 0.03)),
                    class = "earthflux_anchor_na_input")
  expect_identical(e$variable, "zom")
})

test_that("a hand-built earthflux_anchors object has the H interface names", {
  cp <- data.frame(anchor_id = c("cold", "hot"), type = c("cold", "hot"),
                   lst = c(300, 321), elevation = c(500, 520),
                   zom = c(0.08, 0.005), rn = c(700, 500), g = c(100, 120),
                   le_target = c(568.775, 0), u_blend = c(4.2, 4.2),
                   pressure = c(95.5, 95.3))
  x <- new_ef_object(list(calibration_points = cp, flags = list()),
                     "earthflux_anchors")
  expect_s3_class(x, "earthflux_anchors")
  expect_true(all(h_required %in% names(x$calibration_points)))
  # the object built by the module carries the same names
  b <- cond(zom = 0.05, u_blend = 4, pressure = 95)
  expect_true(all(names(cp) %in% names(b$calibration_points)))
  expect_identical(vapply(b$calibration_points[names(cp)], class, ""),
                   vapply(cp, class, ""))
})
