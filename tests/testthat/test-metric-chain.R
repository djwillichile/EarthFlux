# End-to-end test of the METRIC core chain (milestone M2)
#
# A small deterministic synthetic scene (8 x 8 matrices of surface
# temperature, albedo, NDVI, LAI and elevation; scalar weather) is run
# through the public API only, in pipeline order:
#
#   ef_solar_geometry() -> ef_tau_sw() -> ef_rs_in() -> ef_atm_emissivity()
#   -> ef_rl_in() (air temperature, explicit) -> ef_rl_out()
#   -> ef_net_radiation() -> ef_g() -> ef_select_anchors()
#   -> ef_anchor_conditions() (with zom, u_blend, pressure) -> ef_calibrate_h()
#   -> ef_latent_heat() -> ef_et_inst() (lambda from ef_lambda("constant"))
#   -> ef_etrf() -> ef_et_daily()
#
# What is verified (structural invariants of the chain, no reference numbers):
#   * the stages connect: each output is accepted by the next stage and the
#     8 x 8 dim is preserved through the whole chain;
#   * energy closure at the anchors: the calibrated H of each anchor equals
#     its target H = Rn - G - LE_target (phase A closure) and, with a tight
#     tolerance of the stability iteration, the per-pixel H of phase B at the
#     anchor cells equals the same targets;
#   * LE = Rn - G - H in every pixel;
#   * ETrF at the cold anchor equals the imposed `etrf_cold`, and at the hot
#     anchor the imposed `etrf_hot` = 0 (to tolerance), i.e. the boundary
#     conditions survive the round trip LE -> ET_inst -> ETrF with the same
#     lambda (decision P0-7);
#   * the flags of every object are valid `earthflux_flag` records with
#     codes evaluated by their stage, and the negative ET cells are exactly
#     the cells where H exceeds the (positive) available energy;
#   * block invariance of the per-pixel phase: processing the pixels as two
#     halves gives results identical to the whole scene (strategy P2);
#   * both values of the open decision SH-11 (`stable_psi_m_height` 2 and
#     200 m) on this all-unstable scene, where they must coincide, and a
#     variant with a stable cold anchor where 2 m converges and 200 m stops
#     with `earthflux_calibration_error` (finding recorded with P0-2).
#
# What is NOT verified: the physical realism of any value (all METRIC forms
# are CANDIDATA and the coefficients of the anchor conditions and criteria
# are test values, not defaults), agreement with Allen et al. (2007) or any
# published case, terrain effects (flat scene), spatially varying weather,
# and the behaviour of real MODIS inputs.

deg <- pi / 180

chain_scene <- function() {
  nr <- 8L
  nc <- 8L
  r <- row(matrix(0, nr, nc))
  cc <- col(matrix(0, nr, nc))
  # Diagonal vegetation gradient: dry bare soil in the top left corner,
  # dense irrigated canopy in the bottom right corner.
  ndvi <- 0.10 + 0.75 * (r + cc - 2) / (nr + nc - 2)
  list(
    ndvi = ndvi,
    lai = 6 * ndvi^2,
    albedo = 0.30 - 0.12 * ndvi,
    elevation = 500 + 5 * (r - 1) + 2 * (cc - 1),
    # Small deterministic texture so that the extremes are unique.
    lst = 318 - 22 * (ndvi - 0.10) / 0.75 + 0.01 * ((3 * r + 5 * cc) %% 7)
  )
}

chain_weather <- list(
  air_temperature = 298, # K
  vapour_pressure = 1.5, # kPa
  wind_speed = 3, # m s-1 at 2 m
  etr_inst = 0.75, # mm h-1, alfalfa
  etr_24 = 7.5, # mm d-1, alfalfa
  doy = 15,
  utc_hour = 15.5,
  lat = -35 * deg,
  lon = -71 * deg
)

chain_criteria <- function() {
  ef_anchor_criteria(
    cold = list(ef_anchor_rule("ndvi", ">=", 0.7, scale = "absolute")),
    hot = list(ef_anchor_rule("ndvi", "<=", 0.2, scale = "absolute")),
    homogeneity = NULL,
    select = list(cold = ef_anchor_pick("lst", "lowest", 1),
                  hot = ef_anchor_pick("lst", "highest", 1)),
    percentile_domain = "land",
    quantile_type = 7,
    source = "test values for the synthetic chain scene",
    status = "CANDIDATA"
  )
}

# Radiation, G and anchors (stages up to the boundary conditions).
chain_surface <- function(scene = chain_scene(), weather = chain_weather) {
  geo <- ef_solar_geometry(weather$doy, weather$utc_hour, weather$lat,
                           weather$lon)
  pressure <- ef_air_pressure(scene$elevation)
  tau <- ef_tau_sw(cos_zenith = geo$cos_zenith, pressure = pressure,
                   vapour_pressure = weather$vapour_pressure, turbidity = 1,
                   method = "allen")
  rs <- ef_rs_in(cos_zenith = geo$cos_zenith,
                 cos_incidence = geo$cos_incidence,
                 inv_distance = geo$inv_distance, tau_beam = tau$beam,
                 tau_diffuse = tau$diffuse, slope = 0, method = "modelled")
  atm <- ef_atm_emissivity(tau$total)
  rl_in <- ef_rl_in(temperature = weather$air_temperature,
                    atm_emissivity = atm)
  rl_out <- ef_rl_out(scene$lst, emissivity = 0.98)
  rn <- ef_net_radiation(rs_in = rs$total, albedo = scene$albedo,
                         rl_in = rl_in, rl_out = rl_out, emissivity = 0.98)
  g <- ef_g(rn, lst = scene$lst, lai = scene$lai, method = "tasumi")
  zom <- ef_zom(lai = scene$lai, method = "lai")
  u_blend <- ef_blending_wind(weather$wind_speed, height = 2,
                              zom_station = 0.015, d_station = 0,
                              blending_height = 200)
  anchors <- ef_select_anchors(scene$lst, scene$ndvi, scene$albedo,
                               lai = scene$lai, elevation = scene$elevation,
                               criteria = chain_criteria(),
                               aggregate = "none")
  lambda <- ef_lambda(method = "constant")
  anchors <- ef_anchor_conditions(
    anchors, rn = rn, g = g$g, etr_inst = weather$etr_inst, lambda = lambda,
    etrf_cold = 1.05, etrf_hot = 0, reference = "alfalfa",
    source = "test values (CANDIDATA, not defaults)", status = "CANDIDATA",
    etr_source = "station", zom = zom$zom, u_blend = u_blend,
    pressure = pressure
  )
  list(scene = scene, geo = geo, pressure = pressure, tau = tau, rs = rs,
       atm = atm, rl_in = rl_in, rl_out = rl_out, rn = rn, g = g, zom = zom,
       u_blend = u_blend, anchors = anchors, lambda = lambda)
}

chain_control <- function(stable_psi_m_height = 2) {
  # Tight tolerance so that phase B reproduces the anchor closure closely.
  ef_h_control(stable_psi_m_height = stable_psi_m_height,
               blending_height = 200, z1 = 0.1, z2 = 2, tol = 1e-10,
               maxit = 200L)
}

chain_pixels <- function(s, rows = seq_len(nrow(s$rn))) {
  sub <- function(x) x[rows, , drop = FALSE]
  list(lst = sub(s$scene$lst), elevation = sub(s$scene$elevation),
       zom = sub(s$zom$zom), u_blend = s$u_blend,
       pressure = sub(s$pressure), rn = sub(s$rn), g = sub(s$g$g))
}

chain_calibrate <- function(s, control = chain_control(), rows = NULL) {
  pixels <- if (is.null(rows)) chain_pixels(s) else chain_pixels(s, rows)
  ef_calibrate_h(s$anchors, control = control, lapse_rate = 0.0065,
                 datum_elevation = 500, pixels = pixels)
}

# Latent heat and ET (per-pixel phase after the calibration).
chain_et <- function(s, h, weather = chain_weather) {
  le <- ef_latent_heat(s$rn, s$g$g, h)
  et_inst <- ef_et_inst(le, s$lambda)
  etrf <- ef_etrf(et_inst, weather$etr_inst, reference = "alfalfa")
  eta <- ef_et_daily(etrf, weather$etr_24, reference = "alfalfa",
                     method = "etrf")
  list(le = le, et_inst = et_inst, etrf = etrf, eta = eta)
}

expect_valid_flags <- function(obj, n_total = NULL) {
  expect_invisible(check_flag_list(obj$flags))
  codes <- vapply(obj$flags, `[[`, "", "code")
  expect_true(all(codes %in% ef_flag_registry()$code))
  expect_true(all(codes %in% obj$provenance$flags_evaluated))
  expect_true(all(vapply(obj$flags, `[[`, 0L, "n_flagged") > 0L))
  if (!is.null(n_total)) {
    cell <- vapply(obj$flags, `[[`, "", "scope") == "cell"
    expect_true(all(vapply(obj$flags[cell], `[[`, 0L, "n_total") == n_total))
  }
}

s <- chain_surface()
cal <- chain_calibrate(s)
et <- chain_et(s, cal$pixels$h)
anchor_rc <- s$anchors$pixels[, c("type", "row", "col")]
at_anchor <- function(x, type) {
  i <- anchor_rc$type == type
  x[anchor_rc$row[i], anchor_rc$col[i]]
}

test_that("the chain runs end to end and keeps the dim of the scene", {
  d <- c(8L, 8L)
  layers <- list(s$tau$total, s$tau$beam, s$rs$total, s$atm, s$rl_out, s$rn,
                 s$g$g, s$g$g_rn_ratio, s$zom$zom, cal$pixels$h,
                 cal$pixels$dt, cal$pixels$rah, et$le, et$et_inst, et$etrf,
                 et$eta$eta_24)
  for (x in layers) {
    expect_identical(dim(x), d)
    expect_false(anyNA(x))
  }
  expect_s3_class(s$tau, "earthflux_sw_transmissivity")
  expect_s3_class(s$rs, "earthflux_incoming_shortwave")
  expect_s3_class(s$g, "earthflux_soil_heat_flux")
  expect_s3_class(s$zom, "earthflux_roughness_length")
  expect_s3_class(s$anchors, "earthflux_anchors")
  expect_s3_class(cal, "earthflux_h_calibration")
  expect_s3_class(et$eta, "earthflux_daily_et")
  expect_true(cal$converged)
  expect_gt(cal$b, 0)
  # The anchors are the unique extremes of the scene.
  expect_identical(anchor_rc$type, c("cold", "hot"))
  expect_identical(at_anchor(s$scene$lst, "cold"), min(s$scene$lst))
  expect_identical(at_anchor(s$scene$lst, "hot"), max(s$scene$lst))
})

test_that("energy closure holds at the anchors and in every pixel", {
  # Phase A closure: the calibrated anchors reproduce H_target exactly.
  expect_equal(cal$anchors$h, cal$anchors$h_target, tolerance = 1e-10)
  cp <- s$anchors$calibration_points
  for (type in c("cold", "hot")) {
    target <- cp$h_target[cp$type == type]
    expect_equal(cal$anchors$h[cal$anchors$type == type], target,
                 tolerance = 1e-10)
    expect_identical(target,
                     cp$rn[cp$type == type] - cp$g[cp$type == type] -
                       cp$le_target[cp$type == type])
    # Phase B at the anchor cell converges to the same H.
    expect_lt(abs(at_anchor(cal$pixels$h, type) - target), 1e-6)
  }
  # LE is the residual of the energy balance everywhere.
  expect_equal(et$le + s$g$g + cal$pixels$h, s$rn, tolerance = 1e-12)
})

test_that("ETrF at the anchors equals the imposed boundary conditions", {
  expect_lt(abs(at_anchor(et$etrf, "cold") - 1.05), 1e-8)
  expect_lt(abs(at_anchor(et$etrf, "hot") - 0), 1e-8)
  # Same check without the stability iteration of phase B: from the
  # calibrated anchor state, with the same lambda.
  st <- cal$anchors
  cp <- s$anchors$calibration_points[match(st$type,
                                           s$anchors$calibration_points$type), ]
  le_a <- cp$rn - cp$g - st$h
  etrf_a <- ef_etrf(ef_et_inst(le_a, s$lambda), cp$etr_inst,
                    reference = "alfalfa")
  expect_equal(etrf_a, cp$etrf, tolerance = 1e-10)
  # Daily ET is ETrF times the daily reference ET.
  expect_identical(et$eta$eta_24, et$etrf * chain_weather$etr_24)
})

test_that("the flags of every object are valid and consistent", {
  n <- 64L
  for (obj in list(s$tau, s$rs, s$g, s$zom, cal, et$eta)) {
    expect_valid_flags(obj, n_total = n)
  }
  expect_valid_flags(s$anchors)
  # Complete inputs: no EF_INPUT_NA anywhere.
  all_codes <- unlist(lapply(list(s$tau, s$rs, s$g, s$zom, et$eta),
                             function(o) vapply(o$flags, `[[`, "", "code")))
  expect_false("EF_INPUT_NA" %in% all_codes)
  # Bare-soil branch of Tasumi at the dry corner.
  low <- Filter(function(f) f$code == "EF_G_LOW_LAI_BRANCH", s$g$flags)
  expect_identical(low[[1]]$index, which(s$scene$lai < 0.5))
  # The hot anchor LE is zero by assumption.
  anchor_codes <- vapply(s$anchors$flags, `[[`, "", "code")
  expect_true("EF_ANCHOR_HOT_LE_ASSUMED_ZERO" %in% anchor_codes)
  # With Rn - G > 0 everywhere, negative ET occurs exactly where H exceeds
  # the available energy.
  expect_true(all(s$rn - s$g$g > 0))
  neg <- Filter(function(f) f$code == "EF_ET_NEGATIVE", et$eta$flags)
  gt <- Filter(function(f) f$code == "EF_H_GT_AVAILABLE", cal$flags)
  idx_neg <- if (length(neg) == 0L) integer(0) else neg[[1]]$index
  idx_gt <- if (length(gt) == 0L) integer(0) else gt[[1]]$index
  expect_gt(length(idx_neg), 0L)
  expect_identical(idx_neg, idx_gt)
  expect_identical(idx_neg, which(et$eta$eta_24 < 0))
})

test_that("the per-pixel phase is invariant to splitting the scene", {
  top <- chain_calibrate(s, rows = 1:4)
  bottom <- chain_calibrate(s, rows = 5:8)
  expect_identical(c(top$a, top$b), c(cal$a, cal$b))
  expect_identical(c(bottom$a, bottom$b), c(cal$a, cal$b))
  for (nm in c("h", "dt", "rah", "u_star", "converged", "iterations")) {
    expect_identical(rbind(top$pixels[[nm]], bottom$pixels[[nm]]),
                     cal$pixels[[nm]])
  }
  h_blocks <- rbind(top$pixels$h, bottom$pixels$h)
  expect_identical(chain_et(s, h_blocks)$eta$eta_24, et$eta$eta_24)
})

test_that("both values of SH-11 are run (open decision P0-2)", {
  # The scene is unstable everywhere (H > 0, Obukhov length < 0), where the
  # height of the stable momentum correction is not used: identical results.
  expect_true(all(cal$pixels$h > 0))
  expect_true(all(cal$pixels$obukhov_length < 0))
  cal_200 <- chain_calibrate(s, control = chain_control(200))
  expect_true(cal_200$converged)
  expect_identical(cal_200$pixels$h, cal$pixels$h)
  expect_identical(c(cal_200$a, cal_200$b), c(cal$a, cal$b))

  # Stable cold anchor (H_target < 0, a higher ETr_inst): 2 m converges and
  # 200 m makes phase A fail with a classed error. The choice is decisive.
  w <- chain_weather
  w$etr_inst <- 0.95
  s_stable <- chain_surface(weather = w)
  cp <- s_stable$anchors$calibration_points
  expect_lt(cp$h_target[cp$type == "cold"], 0)
  cal_2 <- chain_calibrate(s_stable, control = chain_control(2))
  expect_true(cal_2$converged)
  expect_equal(cal_2$anchors$h, cal_2$anchors$h_target, tolerance = 1e-10)
  expect_error(chain_calibrate(s_stable, control = chain_control(200)),
               class = "earthflux_calibration_error")
})
