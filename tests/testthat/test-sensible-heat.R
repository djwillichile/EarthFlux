# Tests for air density, Ts_datum, dT coefficients, sensible heat flux and the
# calibration driver ef_calibrate_h()
#
# Specification: dev/specs/sensible-heat.md sections 8, 9, 11, 14.2-14.6 and
# 16; dev/specs/flags.md section 4.2 (EF_H_ codes). Case identifiers SH-14.x
# (dev/VALIDATION_PLAN.md section 1.3.0).
#
# Tolerances: printed 6-decimal values, half a unit of the last digit
# (section 14.7); calibration identities, relative 1e-12 / 1e-9 (section
# 14.6). The iteration values of section 14.5 were recomputed for 0.1.0
# with the forms of Waters et al. (2002), Eqs. 25-41 (T = Ts in the
# Monin-Obukhov length, g = 9.81 m s-2), by an independent script of the
# author (Python, not the package code); they are compared with half a unit
# of their last printed digit.

# Synthetic scene of section 14.3 / 14.5 -------------------------------------------

u_b <- ef_blending_wind(3, height = 2, zom_station = 0.015, d_station = 0,
                        blending_height = 200)
p_anchor <- ef_air_pressure(c(500, 700))
scene_anchors <- data.frame(
  anchor_id = c("c1", "h1"),
  type = c("cold", "hot"),
  lst = c(300, 316),
  elevation = c(500, 700),
  zom = c(0.06, 0.005),
  rn = c(600, 480),
  g = c(50, 110),
  le_target = c(520, 0),
  u_blend = u_b,
  pressure = p_anchor,
  stringsAsFactors = FALSE
)
interior <- list(lst = 308, elevation = 500, zom = 0.02, u_blend = u_b,
                 pressure = ef_air_pressure(500))
ctrl_for <- function(...) ef_h_control(stable_psi_m_height = 2,
                                       blending_height = 200, z1 = 0.1,
                                       z2 = 2, ...)
calibrate <- function(anchors = scene_anchors, control = ctrl_for(),
                      pixels = NULL, datum_elevation = 500) {
  ef_calibrate_h(anchors, control = control, lapse_rate = 0.00649,
                 datum_elevation = datum_elevation, pixels = pixels)
}
flag_of <- function(cal, code) {
  hit <- Filter(function(f) f$code == code, cal$flags)
  if (length(hit) == 1L) hit[[1L]] else NULL
}
# Evaluated but absent: no record, and the code is listed in the provenance
# (convention of every ef_diagnose_<stage>(), R/diagnostics.R).
expect_absent <- function(cal, code) {
  expect_null(flag_of(cal, code))
  expect_true(code %in% cal$provenance$flags_evaluated)
}

# Air density, Ts_datum and H ----------------------------------------------------------

test_that("SH-14.2: air density from pressure and temperature", {
  p500 <- ef_air_pressure(500)
  expect_lt(abs(p500 - 95.5276), 5e-5)
  rho <- ef_air_density(c(p500, ef_air_pressure(700), p500), c(300, 316, 308))
  expect_lt(max(abs(rho - c(1.098511, 1.018513, 1.069979))), 5e-7)
  expect_equal(ef_air_density(95.5276, 300), 95527.6 / 86961,
               tolerance = 1e-12)
})

test_that("air density, Ts_datum and H validate inputs and keep shape", {
  expect_error(ef_air_density(0, 300), class = "earthflux_domain_error")
  expect_error(ef_air_density(95, -1), class = "earthflux_domain_error")
  expect_error(ef_air_density(95, Inf), class = "earthflux_domain_error")
  expect_error(ef_air_density(numeric(0), 300),
               class = "earthflux_input_error")
  expect_identical(is.na(ef_air_density(c(95, NA), 300)), c(FALSE, TRUE))
  m <- matrix(c(295, 300, 305, 310), 2, 2)
  expect_identical(dim(ef_air_density(95, m)), c(2L, 2L))
  expect_identical(dim(ef_ts_datum(m, 500, 0, 0.0065)), c(2L, 2L))

  expect_error(ef_ts_datum(300, 500, 500, -0.001),
               class = "earthflux_domain_error")
  expect_error(ef_ts_datum(300, 500, c(0, 500), 0.0065),
               class = "earthflux_input_error")
  expect_error(ef_ts_datum(-300, 500, 0, 0.0065),
               class = "earthflux_domain_error")

  expect_error(ef_sensible_heat(1.1, 5, 0, 1004),
               class = "earthflux_domain_error")
  expect_error(ef_sensible_heat(0, 5, 20, 1004),
               class = "earthflux_domain_error")
  expect_error(ef_sensible_heat(1.1, 5, 20, -1),
               class = "earthflux_domain_error")
  expect_error(ef_sensible_heat(1.1, Inf, 20, 1004),
               class = "earthflux_domain_error")
  # Negative dT gives negative H, unchanged (advection is possible)
  expect_equal(ef_sensible_heat(1.1, -2, 20, 1004), -1.1 * 1004 * 2 / 20,
               tolerance = 1e-14)
  expect_identical(is.na(ef_sensible_heat(1.1, c(1, NA), 20, 1004)),
                   c(FALSE, TRUE))
})

test_that("SH-14.3: dT calibration from two anchors (neutral, first step)", {
  ts_datum <- ef_ts_datum(c(300, 316), c(500, 700), datum_elevation = 500,
                          lapse_rate = 0.00649)
  expect_equal(ts_datum, c(300, 317.298), tolerance = 1e-12)

  zom <- c(0.06, 0.005, 0.02)
  rah <- ef_rah(ef_ustar(u_b, zom, 200), 0.1, 2)
  rho <- ef_air_density(c(p_anchor, ef_air_pressure(500)), c(300, 316, 308))
  h_target <- c(600 - 50 - 520, 480 - 110 - 0)
  dt <- h_target * rah[1:2] / (rho[1:2] * EF_SPECIFIC_HEAT_AIR)
  expect_lt(max(abs(dt - c(0.675211, 11.733091))), 5e-7)

  co <- ef_dt_coef(ts_datum[2], ts_datum[1], dt[2], dt[1])
  expect_lt(abs(co$b - 0.63925775), 5e-9)
  expect_lt(abs(co$a - (-191.102115)), 5e-7)

  # Consistency: the line reproduces dT and H_target at both anchors
  expect_lt(max(abs((co$a + co$b * ts_datum) / dt - 1)), 1e-12)
  h_anchor <- ef_sensible_heat(rho[1:2], co$a + co$b * ts_datum, rah[1:2],
                               EF_SPECIFIC_HEAT_AIR)
  expect_lt(max(abs(h_anchor / h_target - 1)), 1e-12)

  # Interior pixel
  dt_p <- co$a + co$b * 308
  expect_lt(abs(dt_p - 5.789273), 5e-7)
  h_p <- ef_sensible_heat(rho[3], dt_p, rah[3], EF_SPECIFIC_HEAT_AIR)
  expect_lt(abs(h_p - 220.6552), 5e-5)

  # Datum invariance (section 9.1): z_datum = 0 changes a, not dT
  ts0 <- ef_ts_datum(c(300, 316, 308), c(500, 700, 500), 0, 0.00649)
  expect_equal(ts0 - c(ts_datum, 308), rep(3.245, 3), tolerance = 1e-12)
  co0 <- ef_dt_coef(ts0[2], ts0[1], dt[2], dt[1])
  expect_false(isTRUE(all.equal(co0$a, co$a)))
  expect_lt(abs((co0$a + co0$b * ts0[3]) / dt_p - 1), 1e-12)

  # c_p invariance with rah fixed (section 8.3)
  h_cp <- vapply(c(1004, 1013), function(cp) {
    dt_cp <- h_target * rah[1:2] / (rho[1:2] * cp)
    co_cp <- ef_dt_coef(ts_datum[2], ts_datum[1], dt_cp[2], dt_cp[1])
    ef_sensible_heat(rho[3], co_cp$a + co_cp$b * 308, rah[3], cp)
  }, numeric(1))
  expect_lt(abs(h_cp[2] / h_cp[1] - 1), 1e-12)
})

test_that("ef_dt_coef() rejects swapped or equal anchor temperatures", {
  expect_error(ef_dt_coef(300, 317, 1, 10),
               class = "earthflux_calibration_error")
  expect_error(ef_dt_coef(300, 300, 1, 10),
               class = "earthflux_calibration_error")
  expect_error(ef_dt_coef(317, 300, Inf, 1), class = "earthflux_domain_error")
  co <- ef_dt_coef(c(317, NA), 300, c(10, 10), 1)
  expect_identical(is.na(co$b), c(FALSE, TRUE))
  # A non-positive slope is returned unchanged (flagged by the driver)
  expect_lt(ef_dt_coef(317, 300, 1, 10)$b, 0)
})

# Control -----------------------------------------------------------------------------

test_that("ef_h_control() defaults follow the SEBAL Idaho manual (SH-11)", {
  # Waters et al. (2002): z_b = 200 m (p. 26), z1 = 0.1 m and z2 = 2 m
  # (p. 30, Eq. 41), stable psi_m(200 m) = -5 (2 / L) (p. 33, Eq. 38)
  defaults <- ef_h_control()
  expect_identical(defaults$stable_psi_m_height, 2)
  expect_identical(defaults$blending_height, 200)
  expect_identical(defaults$z1, 0.1)
  expect_identical(defaults$z2, 2)
  expect_identical(defaults, ctrl_for())
  # The blending height can still be chosen explicitly
  expect_identical(ef_h_control(stable_psi_m_height = 200)$stable_psi_m_height,
                   200)
  expect_error(ef_h_control(stable_psi_m_height = NULL),
               class = "earthflux_input_error")
  ctrl <- ctrl_for()
  # Convergence settings of decision M2-11: one tolerance per phase
  expect_identical(
    ctrl,
    list(stable_psi_m_height = 2, blending_height = 200, z1 = 0.1, z2 = 2,
         tol = 1e-6, maxit = 100L, damping = 0, pixel_tol = 1e-5,
         pixel_maxit = 100L)
  )
  expect_identical(ef_h_control(200, 200, 0.1, 2)$stable_psi_m_height, 200)
  expect_error(ctrl_for(tol = 0), class = "earthflux_domain_error")
  expect_error(ctrl_for(maxit = 0), class = "earthflux_domain_error")
  expect_error(ctrl_for(maxit = 2.5), class = "earthflux_domain_error")
  expect_error(ctrl_for(damping = 1), class = "earthflux_domain_error")
  expect_error(ctrl_for(tol = c(0.1, 0.2)), class = "earthflux_input_error")
  expect_error(ef_h_control(300, 200, 0.1, 2),
               class = "earthflux_domain_error")
  expect_error(ef_h_control(2, 200, 2, 0.1), class = "earthflux_domain_error")
  expect_error(ef_h_control(2, 1, 0.1, 2), class = "earthflux_domain_error")
})

test_that("ef_h_control() checks the convergence settings of phase B", {
  ctrl <- ctrl_for(pixel_tol = 1e-8, pixel_maxit = 50)
  expect_identical(ctrl$pixel_tol, 1e-8)
  expect_identical(ctrl$pixel_maxit, 50L)
  # The two phases are set independently
  expect_identical(ctrl$tol, 1e-6)
  expect_identical(ctrl$maxit, 100L)
  expect_identical(ctrl_for(tol = 0.01)$pixel_tol, 1e-5)
  expect_error(ctrl_for(pixel_tol = 0), class = "earthflux_domain_error")
  expect_error(ctrl_for(pixel_tol = -1e-5), class = "earthflux_domain_error")
  expect_error(ctrl_for(pixel_tol = Inf), class = "earthflux_domain_error")
  expect_error(ctrl_for(pixel_tol = NA_real_),
               class = "earthflux_input_error")
  expect_error(ctrl_for(pixel_tol = c(1e-5, 1e-6)),
               class = "earthflux_input_error")
  expect_error(ctrl_for(pixel_tol = "1e-5"), class = "earthflux_input_error")
  expect_error(ctrl_for(pixel_maxit = 0), class = "earthflux_domain_error")
  expect_error(ctrl_for(pixel_maxit = 2.5), class = "earthflux_domain_error")
  expect_error(ctrl_for(pixel_maxit = NULL), class = "earthflux_input_error")
})

# Calibration: properties of section 14.5 ----------------------------------------------

test_that("SH-14.5: iteration with tol = 0.01 and damping 0 or 0.5", {
  # The values of section 14.5 are for tol = 0.01 (the default until M2-11)
  cal <- calibrate(control = ctrl_for(tol = 0.01, maxit = 20L))
  expect_s3_class(cal, "earthflux_h_calibration")
  expect_true(cal$converged)
  expect_identical(cal$iterations, 6L)
  last <- cal$trace[nrow(cal$trace), ]
  expect_identical(nrow(cal$trace), 6L)
  expect_lt(abs(last$a - (-86.74)), 5e-3)
  expect_lt(abs(last$b - 0.29093), 5e-6)
  expect_lt(abs(last$rah_cold - 19.8294), 5e-5)
  expect_lt(abs(last$rah_hot - 15.7863), 5e-5)
  expect_lt(last$max_rel_change, 0.01)
  expect_true(is.na(cal$trace$delta_a[1]))
  expect_equal(cal$trace$delta_a[-1], diff(cal$trace$a), tolerance = 1e-12)

  cal_d <- calibrate(control = ctrl_for(tol = 0.01, maxit = 20L,
                                        damping = 0.5))
  last_d <- cal_d$trace[nrow(cal_d$trace), ]
  expect_identical(cal_d$iterations, 7L)
  expect_lt(abs(last_d$a - (-88.570)), 5e-4)
  expect_lt(abs(last_d$b - 0.29703), 5e-6)
  expect_lt(abs(last_d$rah_cold - 19.8593), 5e-5)
  expect_lt(abs(last_d$rah_hot - 15.8685), 5e-5)
})

test_that("SH-14.5: fixed point, independent of damping (properties 1-2)", {
  ctrl <- ctrl_for(tol = 1e-10, maxit = 100L)
  cal0 <- calibrate(control = ctrl)
  ctrl$damping <- 0.5
  cal5 <- calibrate(control = ctrl)
  expect_true(cal0$converged)
  expect_true(cal5$converged)
  expect_identical(cal0$iterations, 23L)
  expect_identical(cal5$iterations, 34L)
  for (cal in list(cal0, cal5)) {
    expect_lt(abs(cal$a - (-87.26315)), 5e-6)
    expect_lt(abs(cal$b - 0.2926717), 5e-8)
    expect_lt(abs(cal$anchors$rah[cal$anchors$type == "cold"] - 19.82799),
              5e-6)
    expect_lt(abs(cal$anchors$rah[cal$anchors$type == "hot"] - 15.75910),
              5e-6)
  }
  expect_lt(abs(cal0$a - cal5$a), 1e-7)
  expect_lt(abs(cal0$b - cal5$b), 1e-9)
})

test_that("SH-14.5/14.6: anchors reproduce H_target (property 3)", {
  for (tol in c(0.01, 1e-10)) {
    cal <- calibrate(control = ctrl_for(tol = tol, maxit = 100L))
    anc <- cal$anchors
    expect_identical(anc$type, c("hot", "cold"))
    expect_identical(anc$anchor_id, c("h1", "c1"))
    expect_equal(anc$h_target, c(370, 30))
    # Closure: exact reproduction (relative 1e-9) and dT on the line (1e-12)
    expect_lt(max(abs(anc$h / anc$h_target - 1)), 1e-9)
    expect_lt(max(abs((cal$a + cal$b * anc$ts_datum) / anc$dt - 1)), 1e-12)
  }
  # Phase B (strategy P2) at the anchors themselves, with tight tolerances
  cal <- calibrate(
    control = ctrl_for(tol = 1e-10, maxit = 100L, pixel_tol = 1e-10),
    pixels = scene_anchors[c("lst", "elevation", "zom", "u_blend",
                             "pressure")]
  )
  expect_true(all(cal$pixels$converged))
  expect_lt(max(abs(cal$pixels$h / c(30, 370) - 1)), 1e-9)
})

test_that("SH-14.5: phase B of the interior pixel at the fixed point", {
  cal <- calibrate(control = ctrl_for(tol = 1e-10, maxit = 100L,
                                      pixel_tol = 1e-10),
                   pixels = interior)
  expect_true(cal$pixels$converged)
  expect_lt(abs(cal$pixels$dt - 2.879745), 5e-7)
  expect_lt(abs(cal$pixels$rah - 17.1702), 5e-5)
  expect_lt(abs(cal$pixels$h - 181.8722), 5e-5)
  expect_equal(cal$pixels$h,
               ef_sensible_heat(cal$pixels$air_density, cal$pixels$dt,
                                cal$pixels$rah, cal$constants$cp),
               tolerance = 1e-14)
  expect_equal(cal$pixels$air_density,
               ef_air_density(interior$pressure, 308 - cal$pixels$dt),
               tolerance = 1e-14)
})

# Strongly unstable, low-wind variant of the scene (wind of 1 m s-1 at 2 m;
# L of the hot anchor about -0.7 m, as in the Talca scene of
# dev/verification/water-comparison.md) and a range of interior pixels.
u_low <- ef_blending_wind(1, height = 2, zom_station = 0.015, d_station = 0,
                          blending_height = 200)
low_anchors <- transform(scene_anchors, u_blend = u_low)
low_pixels <- list(lst = seq(298, 318, by = 0.5), elevation = 500,
                   zom = rep(c(0.005, 0.02, 0.06, 0.2), length.out = 41),
                   u_blend = u_low, pressure = ef_air_pressure(500))
tight <- ctrl_for(tol = 1e-10, maxit = 500L, pixel_tol = 1e-10,
                  pixel_maxit = 500L)

test_that("M2-11: the defaults reach the fixed point in a low-wind case", {
  ref <- calibrate(low_anchors, control = tight, pixels = low_pixels)
  def <- calibrate(low_anchors, pixels = low_pixels)
  expect_true(ref$converged && def$converged)
  expect_true(all(ref$pixels$converged) && all(def$pixels$converged))
  expect_lt(ref$anchors$obukhov_length[ref$anchors$type == "hot"], -0.5)
  # H within 0.01 W m-2 of the fixed point of both phases at every pixel
  # (about 4e-4 W m-2 here)
  expect_lt(max(abs(def$pixels$h - ref$pixels$h)), 0.01)
  # Phase B alone, with the same (a*, b*): every pixel stops within
  # pixel_tol (relative) of its own fixed point
  same_ab <- calibrate(low_anchors,
                       control = ctrl_for(tol = 1e-10, maxit = 500L),
                       pixels = low_pixels)
  expect_identical(c(same_ab$a, same_ab$b), c(ref$a, ref$b))
  expect_lt(max(abs(same_ab$pixels$h / ref$pixels$h - 1)),
            same_ab$control$pixel_tol)
  expect_lte(max(same_ab$pixels$iterations), 20L)
  # Phase B at the anchors reproduces H_target (370 and 30 W m-2)
  at_anchors <- calibrate(
    low_anchors,
    pixels = low_anchors[c("lst", "elevation", "zom", "u_blend", "pressure")]
  )
  expect_lt(max(abs(at_anchors$pixels$h - c(30, 370))), 0.01)
})

test_that("M2-11: the bias of tol = 0.01 comes from phase A, not phase B", {
  ref <- calibrate(low_anchors, control = tight, pixels = low_pixels)
  # Settings of EarthFlux 0.1.0: about 1.2 W m-2 from the fixed point
  old <- calibrate(low_anchors,
                   control = ctrl_for(tol = 0.01, maxit = 20L,
                                      pixel_tol = 0.01, pixel_maxit = 20L),
                   pixels = low_pixels)
  expect_gt(max(abs(old$pixels$h - ref$pixels$h)), 0.5)
  # A tight pixel_tol alone does not remove it: the anchors run through
  # phase B no longer reproduce their target H
  pixel_only <- calibrate(low_anchors,
                          control = ctrl_for(tol = 0.01, maxit = 20L),
                          pixels = low_pixels)
  expect_gt(max(abs(pixel_only$pixels$h - ref$pixels$h)), 0.5)
  at_anchors <- calibrate(
    low_anchors, control = ctrl_for(tol = 0.01, maxit = 20L),
    pixels = low_anchors[c("lst", "elevation", "zom", "u_blend", "pressure")]
  )
  expect_gt(max(abs(at_anchors$pixels$h - c(30, 370))), 0.1)
})

test_that("SH-14.5: unstable correction lowers rah at both anchors (property 4)", {
  cal <- calibrate()
  neutral <- ef_rah(ef_ustar(u_b, c(0.005, 0.06), 200), 0.1, 2)
  expect_true(all(cal$anchors$rah < neutral))
  expect_true(all(cal$anchors$obukhov_length < 0))
})

test_that("SH-14.5: non-convergence is reported, never silent (property 5)", {
  ctrl <- ctrl_for(tol = 1e-12, maxit = 1L)
  expect_warning(
    cal <- calibrate(control = ctrl, pixels = interior),
    class = "earthflux_convergence_warning"
  )
  expect_false(cal$converged)
  expect_identical(cal$iterations, 1L)
  flag <- flag_of(cal, "EF_H_CALIBRATION_NOT_CONVERGED")
  expect_s3_class(flag, "earthflux_flag")
  expect_identical(flag$severity, "critical")
  expect_identical(flag$scope, "object")
  expect_identical(flag$n_flagged, 1L)
  # The last iterate is returned: anchors still reproduce H_target
  expect_lt(max(abs(cal$anchors$h / cal$anchors$h_target - 1)), 1e-9)
  # The warning carries the phase and the trace
  w <- tryCatch(calibrate(control = ctrl), warning = function(w) w)
  expect_identical(w$phase, "anchors")
  expect_identical(w$iterations, 1L)
  expect_s3_class(w$trace, "data.frame")
  # Negative case
  expect_absent(calibrate(), "EF_H_CALIBRATION_NOT_CONVERGED")
})

test_that("SH-14.5: swapped or equal anchors are calibration errors (property 6)", {
  swapped <- scene_anchors
  swapped$type <- c("hot", "cold")
  expect_error(calibrate(swapped), class = "earthflux_calibration_error")
  equal <- scene_anchors
  equal$lst <- c(300, 300)
  equal$elevation <- c(500, 500)
  expect_error(calibrate(equal), class = "earthflux_calibration_error")
})

test_that("SH-14.5: phase B is block-size invariant (property 7)", {
  n <- 12L
  pixels <- list(
    lst = seq(295, 320, length.out = n),
    elevation = rep(c(500, 650, 800), 4L),
    zom = rep(c(0.005, 0.02, 0.06, 0.1), 3L),
    u_blend = u_b,
    pressure = ef_air_pressure(rep(c(500, 650, 800), 4L))
  )
  full <- calibrate(pixels = pixels)$pixels
  blocks <- split(seq_len(n), rep(1:3, each = 4L))
  parts <- lapply(blocks, function(i) {
    sub <- lapply(pixels, function(x) if (length(x) == 1L) x else x[i])
    calibrate(pixels = sub)$pixels
  })
  for (nm in names(full)) {
    expect_identical(unname(unlist(lapply(parts, `[[`, nm))), full[[nm]])
  }
})

test_that("SH-11: both stable_psi_m_height options with a stable cold anchor", {
  stable <- scene_anchors
  stable$le_target <- c(600, 0) # H_target = -50 W m-2 at the cold anchor
  # Default of ef_h_control(): 2 m (Waters et al., 2002, Eq. 38)
  ctrl2 <- ef_h_control(tol = 1e-8, maxit = 100L)
  cal <- calibrate(stable, control = ctrl2)
  expect_true(cal$converged)
  # Values of the independent script of the author (forms of the manual)
  expect_identical(cal$iterations, 19L)
  expect_lt(abs(cal$a - (-120.328834)), 5e-6)
  expect_lt(abs(cal$b - 0.39688192), 5e-8)
  cold <- cal$anchors[cal$anchors$type == "cold", ]
  expect_gt(cold$obukhov_length, 0)
  expect_lt(abs(cold$h / -50 - 1), 1e-9)
  # Final cold-anchor state is a fixed point of the 2/L correction
  u_fix <- ef_ustar(u_b, 0.06, 200,
                    psi_m = ef_psi_m(2, cold$obukhov_length))
  expect_equal(cold$u_star, u_fix, tolerance = 1e-6)

  # With z_b / L the iteration of this synthetic scene diverges (finding
  # M2-07; reported with a classed error and the trace, never silently)
  ctrl200 <- ef_h_control(200, 200, 0.1, 2, tol = 1e-8, maxit = 100L)
  err <- tryCatch(calibrate(stable, control = ctrl200), error = function(e) e)
  expect_s3_class(err, "earthflux_calibration_error")
  expect_s3_class(err$trace, "data.frame")
  expect_gt(max(err$trace$rah_cold), 1e6)
})

# Inputs of the driver -------------------------------------------------------------------

test_that("ef_calibrate_h() accepts an earthflux_anchors object", {
  obj <- new_ef_object(list(calibration_points = scene_anchors, flags = list()),
                       "earthflux_anchors")
  cal_obj <- calibrate(obj)
  cal_df <- calibrate()
  expect_identical(cal_obj$a, cal_df$a)
  expect_identical(cal_obj$anchors, cal_df$anchors)
  expect_identical(cal_obj$provenance$anchors_input,
                   "earthflux_anchors$calibration_points")
  # Without anchor_id, the type is used
  cal_id <- calibrate(scene_anchors[setdiff(names(scene_anchors),
                                            "anchor_id")])
  expect_identical(cal_id$anchors$anchor_id, c("hot", "cold"))
})

test_that("ef_calibrate_h() validates the calibration points", {
  expect_error(calibrate(as.list(scene_anchors)),
               class = "earthflux_input_error")
  expect_error(calibrate(scene_anchors[setdiff(names(scene_anchors), "g")]),
               class = "earthflux_missing_input")
  two_hot <- rbind(scene_anchors, scene_anchors[2, ])
  expect_error(calibrate(two_hot), class = "earthflux_input_error")
  odd <- scene_anchors
  odd$type <- c("cold", "warm")
  expect_error(calibrate(odd), class = "earthflux_input_error")
  na_anchor <- scene_anchors
  na_anchor$rn[1] <- NA
  expect_error(calibrate(na_anchor), class = "earthflux_calibration_error")
  calm <- scene_anchors
  calm$u_blend <- c(5, 0)
  expect_error(calibrate(calm), class = "earthflux_calibration_error")
  bad <- scene_anchors
  bad$zom[1] <- 0
  expect_error(calibrate(bad), class = "earthflux_domain_error")
  bad <- scene_anchors
  bad$lst <- c("300", "316")
  expect_error(calibrate(bad), class = "earthflux_input_error")
})

test_that("ef_calibrate_h() validates control, lapse rate and datum", {
  expect_error(ef_calibrate_h(scene_anchors, lapse_rate = 0.0065,
                              datum_elevation = 500),
               class = "earthflux_missing_input")
  # A partial control list is completed with the defaults of ef_h_control()
  expect_identical(calibrate(control = list(tol = 0.01))$control,
                   ctrl_for(tol = 0.01))
  # A list saved before pixel_tol and pixel_maxit existed (EarthFlux 0.1.0)
  # gets their defaults
  old <- list(stable_psi_m_height = 2, blending_height = 200, z1 = 0.1,
              z2 = 2, tol = 0.01, maxit = 20L, damping = 0)
  expect_identical(calibrate(control = old)$control,
                   ctrl_for(tol = 0.01, maxit = 20L))
  expect_error(calibrate(control = c(ctrl_for(), list(foo = 1))),
               class = "earthflux_input_error")
  expect_error(ef_calibrate_h(scene_anchors, ctrl_for(), lapse_rate = -1,
                              datum_elevation = 500),
               class = "earthflux_domain_error")
  expect_error(ef_calibrate_h(scene_anchors, ctrl_for(), lapse_rate = 0.0065,
                              datum_elevation = NA_real_),
               class = "earthflux_input_error")
})

test_that("ef_calibrate_h() validates pixels, propagates NA and keeps dim", {
  expect_error(calibrate(pixels = interior[-1]),
               class = "earthflux_missing_input")
  expect_error(calibrate(pixels = c(interior, list(rn = 500))),
               class = "earthflux_input_error")
  expect_error(calibrate(pixels = 1:3), class = "earthflux_input_error")
  bad <- interior
  bad$zom <- -1
  expect_error(calibrate(pixels = bad), class = "earthflux_domain_error")
  bad <- interior
  bad$lst <- c(300, 301)
  bad$zom <- c(0.01, 0.02, 0.03)
  expect_error(calibrate(pixels = bad), class = "earthflux_input_error")

  pix <- interior
  pix$lst <- c(308, NA)
  cal <- calibrate(pixels = pix)
  expect_identical(is.na(cal$pixels$h), c(FALSE, TRUE))
  expect_identical(cal$pixels$converged, c(TRUE, NA))
  expect_absent(cal, "EF_H_USTAR_INVALID")

  pix <- interior
  pix$lst <- matrix(c(290, 305, 310, 315), 2, 2)
  cal <- calibrate(pixels = pix)
  for (nm in names(cal$pixels)) {
    expect_identical(dim(cal$pixels[[nm]]), c(2L, 2L))
  }
  expect_identical(flag_of(cal, "EF_H_DT_EXTRAPOLATED_COLD")$n_total, 4L)
  expect_identical(flag_of(cal, "EF_H_DT_EXTRAPOLATED_COLD")$index, 1L)
})

# Flags --------------------------------------------------------------------------------

test_that("the EF_H_ registry rows follow dev/specs/flags.md section 4.2", {
  rows <- ef_flags_sensible_heat()
  expect_identical(
    rows$code,
    c("EF_H_USTAR_INVALID", "EF_H_PIXEL_NOT_CONVERGED",
      "EF_H_DT_EXTRAPOLATED_HOT", "EF_H_DT_EXTRAPOLATED_COLD",
      "EF_H_NEGATIVE", "EF_H_GT_AVAILABLE",
      "EF_H_CALIBRATION_NOT_CONVERGED", "EF_H_DT_SLOPE_NONPOSITIVE")
  )
  expect_identical(rows$bit, c(4:9, NA, NA))
  expect_identical(rows$severity, c("warning", "warning", "info", "info",
                                    "info", "warning", "critical",
                                    "critical"))
  expect_identical(rows$scope, c(rep("cell", 6L), "object", "object"))
  reg <- ef_flag_registry()
  expect_true(all(rows$code %in% reg$code))
  # Not registered: no terrain method, no wind floor (SH-06). The minimum
  # of z_om (SH-02) is not part of the core: EF_H_ZOM_FLOOR_APPLIED is
  # registered by the presets of earthflux() (ef_flags_workflow(), M5-24)
  expect_false(any(c("EF_H_ZOM_TERRAIN_ADJUSTED",
                     "EF_H_WIND_FLOOR_APPLIED") %in% reg$code))
  expect_false("EF_H_ZOM_FLOOR_APPLIED" %in% rows$code)
  expect_identical(
    ef_flags_workflow()[, c("code", "stage", "severity", "scope", "bit")],
    data.frame(code = "EF_H_ZOM_FLOOR_APPLIED", stage = "H",
               severity = "info", scope = "cell", bit = 1L)
  )
})

test_that("EF_H_DT_SLOPE_NONPOSITIVE is a critical object flag", {
  inverted <- scene_anchors
  inverted$le_target <- c(300, 450) # H_cold = 250, H_hot = 20
  expect_warning(cal <- calibrate(inverted), class = "earthflux_warning")
  expect_lt(cal$b, 0)
  flag <- flag_of(cal, "EF_H_DT_SLOPE_NONPOSITIVE")
  expect_identical(flag$severity, "critical")
  expect_identical(flag$n_flagged, 1L)
  expect_absent(calibrate(), "EF_H_DT_SLOPE_NONPOSITIVE")
})

test_that("cell flags of phase B: extrapolation, negative H, H > Rn - G", {
  pixels <- list(lst = c(290, 295, 308, 320), elevation = 500, zom = 0.02,
                 u_blend = u_b, pressure = ef_air_pressure(500),
                 rn = 800, g = c(50, 50, 700, 50))
  cal <- calibrate(pixels = pixels)
  # Ts_datum of the anchors: cold 300 K, hot 317.298 K
  expect_identical(flag_of(cal, "EF_H_DT_EXTRAPOLATED_HOT")$index, 4L)
  expect_identical(flag_of(cal, "EF_H_DT_EXTRAPOLATED_COLD")$index, 1:2)
  expect_identical(which(cal$pixels$h < 0),
                   flag_of(cal, "EF_H_NEGATIVE")$index)
  expect_true(cal$pixels$h[1] < 0)
  expect_false(cal$pixels$h[3] < 0)
  # Pixel 3: H > 0 and Rn - G = 100 W m-2 < H
  expect_gt(cal$pixels$h[3], 100)
  expect_identical(flag_of(cal, "EF_H_GT_AVAILABLE")$index, 3L)
  expect_identical(flag_of(cal, "EF_H_GT_AVAILABLE")$severity, "warning")
  # Without rn and g the condition is not evaluated
  cal_no <- calibrate(pixels = pixels[1:5])
  expect_null(flag_of(cal_no, "EF_H_GT_AVAILABLE"))
  expect_false("EF_H_GT_AVAILABLE" %in% cal_no$provenance$flags_evaluated)
  expect_absent(cal_no, "EF_H_PIXEL_NOT_CONVERGED")
  expect_absent(cal_no, "EF_H_USTAR_INVALID")
})

test_that("EF_H_USTAR_INVALID and EF_H_PIXEL_NOT_CONVERGED in phase B", {
  pixels <- list(lst = c(308, 308), elevation = 500, zom = 0.02,
                 u_blend = c(u_b, 0), pressure = ef_air_pressure(500))
  cal <- calibrate(pixels = pixels)
  expect_true(is.na(cal$pixels$u_star[2]))
  expect_true(is.na(cal$pixels$h[2]))
  expect_true(is.na(cal$pixels$converged[2]))
  expect_identical(flag_of(cal, "EF_H_USTAR_INVALID")$index, 2L)
  expect_absent(cal, "EF_H_PIXEL_NOT_CONVERGED")

  # Phase B is limited by pixel_maxit and pixel_tol, not by maxit and tol:
  # phase A converges, the pixel does not
  ctrl <- ctrl_for(pixel_tol = 1e-12, pixel_maxit = 2L)
  w <- tryCatch(calibrate(control = ctrl, pixels = pixels),
                warning = function(w) w)
  expect_s3_class(w, "earthflux_convergence_warning")
  expect_identical(w$phase, "pixels")
  expect_identical(w$n_not_converged, 1L)
  expect_identical(w$iterations, 2L)
  expect_warning(cal <- calibrate(control = ctrl, pixels = pixels),
                 class = "earthflux_convergence_warning")
  expect_true(cal$converged)
  expect_null(flag_of(cal, "EF_H_CALIBRATION_NOT_CONVERGED"))
  expect_identical(cal$pixels$converged, c(FALSE, NA))
  expect_identical(cal$pixels$iterations, c(2L, NA))
  flag <- flag_of(cal, "EF_H_PIXEL_NOT_CONVERGED")
  expect_identical(flag$index, 1L)
  expect_identical(flag$severity, "warning")
  expect_identical(flag$scope, "cell")
  expect_false(is.na(cal$pixels$h[1]))
})

test_that("ef_diagnose_sensible_heat() builds cell flags from outputs", {
  flags <- ef_diagnose_sensible_heat(
    h = c(-5, 100, 300, NA),
    ts_datum = c(295, 305, 320, NA),
    ts_datum_hot = 317, ts_datum_cold = 300,
    u_star = c(0.2, 0.3, NA, NA),
    converged = c(TRUE, FALSE, NA, NA),
    input_ok = c(TRUE, TRUE, TRUE, FALSE),
    rn = c(500, 500, 400, 500), g = c(50, 450, 50, 50)
  )
  codes <- vapply(flags, `[[`, character(1), "code")
  expect_identical(codes, c("EF_H_USTAR_INVALID", "EF_H_PIXEL_NOT_CONVERGED",
                            "EF_H_DT_EXTRAPOLATED_HOT",
                            "EF_H_DT_EXTRAPOLATED_COLD", "EF_H_NEGATIVE",
                            "EF_H_GT_AVAILABLE"))
  idx <- lapply(flags, `[[`, "index")
  names(idx) <- codes
  expect_identical(idx$EF_H_USTAR_INVALID, 3L)
  expect_identical(idx$EF_H_PIXEL_NOT_CONVERGED, 2L)
  expect_identical(idx$EF_H_DT_EXTRAPOLATED_HOT, 3L)
  expect_identical(idx$EF_H_DT_EXTRAPOLATED_COLD, 1L)
  expect_identical(idx$EF_H_NEGATIVE, 1L)
  expect_identical(idx$EF_H_GT_AVAILABLE, 2L)
  expect_true(all(vapply(flags, `[[`, character(1), "scope") == "cell"))
  expect_identical(ef_flags_evaluated(flags), codes)
  # Minimal call: only the conditions computable from H and Ts_datum are
  # evaluated, and none holds, so no record is returned
  min_flags <- ef_diagnose_sensible_heat(c(1, 2), c(305, 306), 317, 300)
  expect_length(min_flags, 0L)
  expect_identical(ef_flags_evaluated(min_flags),
                   c("EF_H_DT_EXTRAPOLATED_HOT", "EF_H_DT_EXTRAPOLATED_COLD",
                     "EF_H_NEGATIVE"))
})

test_that("the calibration object records control, constants and provenance", {
  cal <- calibrate()
  expect_named(cal, c("a", "b", "converged", "iterations", "trace",
                      "anchors", "pixels", "control", "datum", "constants",
                      "provenance", "flags"))
  expect_null(cal$pixels)
  expect_identical(cal$control, ctrl_for())
  expect_identical(cal$datum, list(lapse_rate = 0.00649,
                                   datum_elevation = 500))
  expect_identical(cal$constants$cp, EF_SPECIFIC_HEAT_AIR)
  expect_identical(cal$constants$von_karman, EF_VON_KARMAN)
  expect_identical(cal$constants$gravity, EF_GRAVITY)
  expect_match(cal$provenance$status, "VERIFICADA (SEBAL-Idaho 2002)",
               fixed = TRUE)
  expect_identical(cal$constants$status[["cp"]],
                   "VERIFICADA (SEBAL-Idaho 2002)")
  expect_length(cal$flags, 0L)
  expect_identical(cal$provenance$flags_evaluated,
                   c("EF_H_CALIBRATION_NOT_CONVERGED",
                     "EF_H_DT_SLOPE_NONPOSITIVE"))
  # Datum invariance of the driver: z_datum changes a, not H of the pixels
  pix <- list(lst = c(298, 308, 318), elevation = c(450, 500, 900),
              zom = 0.02, u_blend = u_b,
              pressure = ef_air_pressure(c(450, 500, 900)))
  c500 <- calibrate(pixels = pix)
  c0 <- calibrate(pixels = pix, datum_elevation = 0)
  expect_false(isTRUE(all.equal(c500$a, c0$a)))
  expect_lt(max(abs(c0$pixels$h / c500$pixels$h - 1)), 1e-9)
})
