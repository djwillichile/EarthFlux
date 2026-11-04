# Tests for the reference evapotranspiration (R/reference-et.R):
# ef_ref_net_radiation(), ef_ref_soil_heat_flux(), ef_ref_et(), the internal
# constants table, the stage diagnostics (EF_INPUT_NA, EF_WS_RS_RSO_LIMITED,
# EF_WS_ETR_NEGATIVE) and the internal helpers of options O3 and D1.
#
# Specification: dev/specs/weather-forcing.md sections 4.8-4.9 and 5;
# verification cases V10, V11, V14-V16 (FAO-56 examples 11, 12, 18 and 19)
# and arithmetic cases A1-A4 of section 8; errata of section 8.3 are not
# reproduced (example 11 gives -22.70 degrees for 22 degrees 54' S and
# rounds sigma T^4 inconsistently; example 12 cites Eq. 39 for Rns;
# example 18 omits "/2" in es and writes n/N = 9.25/16.3).
#
# Tolerances (dev/VALIDATION_PLAN.md section 1.2): published FAO-56 values
# with half a unit of their last digit (plus, where stated, the propagation
# of the rounded intermediate values that the example itself uses); the
# full-precision "propio" values of section 8.1 with half a unit of their
# last printed digit; values recomputed here with a relative tolerance of
# 1e-6. Cases A1-A4 (ASCE-EWRI constants, CANDIDATA) verify arithmetic only.

deg <- pi / 180
half_unit <- function(digits) 0.5 * 10^(-digits)

expect_within <- function(object, expected, tol, info = NULL) {
  expect_lte(max(abs(object - expected)), tol,
             label = paste("max. abs. difference", info))
}

flag_codes <- function(x) vapply(x$flags, `[[`, character(1), "code")

flag_index <- function(x, code) {
  hit <- Filter(function(f) identical(f$code, code), x$flags)
  if (length(hit) == 0L) {
    return(NULL)
  }
  hit[[1L]]$index
}

# FAO-56 example 18 (Uccle, 6 July, daily) -----------------------------------

uccle <- local({
  lat <- (50 + 48 / 60) * deg
  doy <- 187
  pressure <- ef_air_pressure(100)
  gamma <- ef_psychrometric(pressure)
  tmean <- (21.5 + 12.3) / 2
  slope <- ef_es_slope(tmean)
  u2 <- ef_wind_2m(10 / 3.6, 10) # 10 km h-1 at 10 m
  es <- mean(ef_es(c(21.5, 12.3)))
  ea <- ef_ea_daily(tmin = 12.3, tmax = 21.5, rh_max = 84, rh_min = 63,
                    method = "rhmax_rhmin")
  ra <- ef_ra_daily(lat, doy)
  n_max <- ef_daylight_hours(lat, doy)
  # Angstrom relation, FAO-56 Eq. 35 with as = 0.25, bs = 0.50 (example
  # 18; not a package function).
  rs <- (0.25 + 0.50 * 9.25 / n_max) * ra
  rso <- ef_rso(ra, 100)
  rn <- ef_ref_net_radiation(rs, rso, ea, tmax = 21.5, tmin = 12.3,
                             timestep = "daily")
  list(pressure = pressure, gamma = gamma, tmean = tmean, slope = slope,
       u2 = u2, es = es, ea = ea, ra = ra, n_max = n_max, rs = rs,
       rso = rso, rn = rn)
})

test_that("V14: FAO-56 example 18, intermediate values", {
  with(uccle, {
    expect_within(pressure, 100.1, half_unit(1))
    expect_within(slope, 0.122, half_unit(3))
    expect_within(gamma, 0.0666, half_unit(4))
    expect_within(u2, 2.078, half_unit(3))
    expect_within(es, 1.997, half_unit(3))
    expect_within(ea, 1.409, half_unit(3))
    expect_within(ra, 41.09, half_unit(2))
    expect_within(n_max, 16.1, half_unit(1))
    expect_within(rs, 22.07, half_unit(2))
    expect_within(rso, 30.90, half_unit(2))
    expect_within(rn$rns, 17.00, half_unit(2))
    expect_within(rn$rnl, 3.71, half_unit(2))
    expect_within(rn$rn, 13.28, half_unit(2))
    # Own full-precision values (section 8.1).
    expect_within(pressure, 100.1235, half_unit(4))
    expect_within(c(slope, gamma), c(0.12211, 0.06658), half_unit(5))
    expect_within(c(u2, es, ea), c(2.0776, 1.9975, 1.4086), half_unit(4))
    expect_within(c(ra, n_max, rs, rso), c(41.088, 16.105, 22.072, 30.898),
                  half_unit(3))
    expect_within(c(rn$rns, rn$rnl, rn$rn), c(16.995, 3.712, 13.283),
                  half_unit(3))
  })
})

test_that("V14: FAO-56 example 18, daily grass ETo = 3.9 mm d-1", {
  g <- ef_ref_soil_heat_flux(uccle$rn$rn, reference = "grass",
                             timestep = "daily", standard = "fao56")
  expect_identical(g, 0)
  eto <- ef_ref_et(
    net_radiation = uccle$rn$rn, soil_heat_flux = g,
    air_temperature = uccle$tmean, wind_speed_2m = uccle$u2,
    vapour_pressure_deficit = uccle$es - uccle$ea, slope = uccle$slope,
    psychrometric = uccle$gamma, reference = "grass", timestep = "daily",
    standard = "fao56"
  )
  expect_s3_class(eto, c("earthflux_reference_et", "list"))
  expect_within(eto$et_ref, 3.9, half_unit(1))
  # FAO-56 also prints 3.88 before rounding.
  expect_within(eto$et_ref, 3.88, half_unit(2))
  expect_within(eto$et_ref, 3.8803, half_unit(4))
  expect_identical(eto$reference, "grass")
  expect_identical(eto$timestep, "daily")
  expect_identical(eto$standard, "fao56")
  expect_identical(eto$provenance$status, "VERIFICADA")
  expect_identical(eto$provenance$constants$cn, 900)
  expect_identical(eto$provenance$constants$cd, 0.34)
  expect_identical(eto$flags, list())
  expect_setequal(eto$provenance$flags_evaluated,
                  c("EF_INPUT_NA", "EF_WS_ETR_NEGATIVE"))
})

test_that("A4: daily tall reference with ASCE-EWRI constants (CANDIDATA)", {
  etr <- ef_ref_et(
    net_radiation = uccle$rn$rn, soil_heat_flux = 0,
    air_temperature = uccle$tmean, wind_speed_2m = uccle$u2,
    vapour_pressure_deficit = uccle$es - uccle$ea, slope = uccle$slope,
    psychrometric = uccle$gamma, reference = "alfalfa", timestep = "daily",
    standard = "asce"
  )
  expect_within(etr$et_ref, 4.6065, half_unit(4))
  expect_identical(etr$provenance$status, "CANDIDATA")
  expect_identical(etr$provenance$constants$cn, 1600)
  expect_identical(etr$provenance$constants$cd, 0.38)
  # Short reference with ASCE daily constants = FAO-56 Eq. 6.
  eto_asce <- ef_ref_et(uccle$rn$rn, 0, uccle$tmean, uccle$u2,
                        uccle$es - uccle$ea, uccle$slope, uccle$gamma,
                        reference = "grass", timestep = "daily",
                        standard = "asce")
  expect_within(eto_asce$et_ref, 3.8803, half_unit(4))
  expect_identical(eto_asce$provenance$status, "CANDIDATA")
})

# FAO-56 examples 11-12 (daily net radiation) -----------------------------------

test_that("V10-V11: daily Rnl and Rn (FAO-56 examples 11 and 12)", {
  # Inputs as given by the examples: Rs = 14.5, Rso = 0.75 * 25.1.
  rn <- ef_ref_net_radiation(14.5, 0.75 * 25.1, 2.1, tmax = 25.1,
                             tmin = 19.1, timestep = "daily")
  expect_within(rn$rnl, 3.5, half_unit(1))
  expect_within(rn$rn, 7.6, half_unit(1))
  expect_within(rn$rnl, 3.5270, half_unit(4))
  expect_within(rn$rn, 7.6380, half_unit(4))
  expect_equal(rn$rns, 0.77 * 14.5, tolerance = 1e-12)
  expect_equal(rn$cloudiness, 1.35 * 14.5 / (0.75 * 25.1) - 0.35,
               tolerance = 1e-12)
  expect_identical(rn$timestep, "daily")
  expect_identical(rn$provenance$status, "VERIFICADA")
  expect_identical(rn$flags, list())
})

# FAO-56 example 19 (N'Diaye, 1 October, hourly) ---------------------------------

ndiaye <- local({
  lat <- (16 + 13 / 60) * deg
  lon <- -(16 + 15 / 60) * deg
  gamma <- ef_psychrometric(ef_air_pressure(8))
  day <- list(t = 38, rh = 52, u2 = 3.3, rs = 2.450, utc_mid = 15.5)
  night <- list(t = 28, rh = 90, u2 = 1.9, rs = 0, utc_mid = 3.5)
  for (nm in c("day", "night")) {
    p <- get(nm)
    p$slope <- ef_es_slope(p$t)
    p$e0 <- ef_es(p$t)
    p$ea <- ef_ea_rh(p$t, p$rh)
    p$ra <- ef_ra_period(lat, lon, 274, p$utc_mid, 1)
    assign(nm, p)
  }
  day$rso <- ef_rso(day$ra, 8)
  day$rn <- ef_ref_net_radiation(day$rs, day$rso, day$ea,
                                 air_temperature = day$t,
                                 timestep = "hourly")
  # Night: Rs/Rso = 0.8 assumed by the example, passed as the cloudiness
  # term 1.35 * 0.8 - 0.35.
  night$rn <- ef_ref_net_radiation(night$rs, NULL, night$ea,
                                   air_temperature = night$t,
                                   timestep = "hourly",
                                   cloudiness = 1.35 * 0.8 - 0.35)
  list(gamma = gamma, day = day, night = night)
})

hourly_et <- function(p, daytime, reference, standard, gamma) {
  g <- ef_ref_soil_heat_flux(p$rn$rn, reference = reference,
                             timestep = "hourly", standard = standard,
                             daytime = daytime)
  ef_ref_et(p$rn$rn, g, p$t, p$u2, p$e0 - p$ea, p$slope, gamma,
            reference = reference, timestep = "hourly", standard = standard,
            daytime = daytime)
}

test_that("V15: FAO-56 example 19, 14:00-15:00, ETo = 0.63 mm h-1", {
  d <- ndiaye$day
  expect_within(ndiaye$gamma, 0.0673, half_unit(4))
  expect_within(d$e0, 6.625, half_unit(3))
  expect_within(d$ra, 3.543, half_unit(3))
  expect_within(d$rso, 2.658, half_unit(3))
  expect_within(d$rn$rns, 1.887, half_unit(3))
  expect_within(d$rn$rnl, 0.137, half_unit(3))
  expect_within(d$rn$rn, 1.749, half_unit(3))
  expect_within(c(d$rn$rnl, d$rn$rn), c(0.1373, 1.7492), half_unit(4))
  g <- ef_ref_soil_heat_flux(d$rn$rn, "grass", "hourly", "fao56",
                             daytime = TRUE)
  expect_within(g, 0.175, half_unit(3))
  eto <- hourly_et(d, TRUE, "grass", "fao56", ndiaye$gamma)
  expect_within(eto$et_ref, 0.63, half_unit(2))
  expect_within(eto$et_ref, 0.6269, half_unit(4))
  expect_identical(eto$provenance$status, "VERIFICADA")
  expect_identical(eto$provenance$daytime, "not used")
})

test_that("V16: FAO-56 example 19, 02:00-03:00, ETo = 0.00 mm h-1", {
  n <- ndiaye$night
  expect_within(n$slope, 0.220, half_unit(3))
  expect_within(n$e0, 3.780, half_unit(3))
  expect_within(n$ea, 3.402, half_unit(3))
  expect_identical(n$ra, 0)
  expect_within(n$rn$rnl, 0.100, half_unit(3))
  expect_within(n$rn$rn, -0.100, half_unit(3))
  expect_within(n$rn$rns, 0, 0)
  expect_identical(n$rn$provenance$cloudiness, "supplied in `cloudiness`")
  g <- ef_ref_soil_heat_flux(n$rn$rn, "grass", "hourly", "fao56",
                             daytime = FALSE)
  expect_within(g, -0.050, half_unit(3))
  eto <- hourly_et(n, FALSE, "grass", "fao56", ndiaye$gamma)
  # Published 0.00 (rounded); own value 0.0043 as regression.
  expect_within(eto$et_ref, 0, 0.005)
  expect_within(eto$et_ref, 0.0043, half_unit(4))
})

test_that("A1-A3: hourly constants of FAO-56 and ASCE-EWRI (CANDIDATA)", {
  d <- ndiaye$day
  n <- ndiaye$night
  # A1 (FAO-56 Eq. 53), A2 (ASCE short), A3 (ASCE tall); arithmetic only.
  cases <- list(
    A1 = list(ref = "grass", std = "fao56", day = 0.6269, night = 0.0043),
    A2 = list(ref = "grass", std = "asce", day = 0.6560, night = 0.0035),
    A3 = list(ref = "alfalfa", std = "asce", day = 0.8218, night = 0.0067)
  )
  for (id in names(cases)) {
    cs <- cases[[id]]
    et_d <- hourly_et(d, TRUE, cs$ref, cs$std, ndiaye$gamma)$et_ref
    et_n <- hourly_et(n, FALSE, cs$ref, cs$std, ndiaye$gamma)$et_ref
    expect_within(et_d, cs$day, half_unit(4), info = id)
    expect_within(et_n, cs$night, half_unit(4), info = id)
  }
  # `standard` matters for the grass reference: 0.627 versus 0.656.
  expect_gt(hourly_et(d, TRUE, "grass", "asce", ndiaye$gamma)$et_ref,
            hourly_et(d, TRUE, "grass", "fao56", ndiaye$gamma)$et_ref)
})

test_that("ef_ref_et() hourly ASCE uses Cd by day and night per position", {
  d <- ndiaye$day
  n <- ndiaye$night
  et <- ef_ref_et(
    net_radiation = c(d$rn$rn, n$rn$rn),
    soil_heat_flux = c(0.04 * d$rn$rn, 0.2 * n$rn$rn),
    air_temperature = c(d$t, n$t), wind_speed_2m = c(d$u2, n$u2),
    vapour_pressure_deficit = c(d$e0 - d$ea, n$e0 - n$ea),
    slope = c(d$slope, n$slope), psychrometric = ndiaye$gamma,
    reference = "alfalfa", timestep = "hourly", standard = "asce",
    daytime = c(TRUE, FALSE)
  )
  expect_within(et$et_ref, c(0.8218, 0.0067), half_unit(4))
  k <- et$provenance$constants
  expect_identical(k$cd[k$period == "day"], 0.25)
  expect_identical(k$cd[k$period == "night"], 1.7)
  expect_identical(et$provenance$status, "CANDIDATA")
  expect_identical(et$provenance$daytime, "supplied by the caller (WF-15)")
})

# Constants table ---------------------------------------------------------------------

test_that("the constants table records source and status per row", {
  k <- ef_reference_constants()
  expect_named(k, c("reference", "standard", "timestep", "period", "cn", "cd",
                    "g_rn", "status", "source"))
  expect_identical(anyDuplicated(k[c("reference", "standard", "timestep",
                                     "period")]), 0L)
  expect_true(all(nzchar(k$source)))
  expect_identical(unique(k$status[k$standard == "fao56"]), "VERIFICADA")
  expect_identical(unique(k$status[k$standard == "asce"]), "CANDIDATA")
  expect_false(any(k$standard == "fao56" & k$reference == "alfalfa"))
  # FAO-56 Eqs. 6 and 53 are the Cn/Cd form with 900/37 and 0.34.
  fao <- k[k$standard == "fao56", ]
  expect_identical(fao$cn, c(900, 37, 37))
  expect_identical(unique(fao$cd), 0.34)
  expect_identical(fao$g_rn, c(0, 0.1, 0.5))
})

# Choices and errors ----------------------------------------------------------------

ref_args <- list(net_radiation = 1.749, soil_heat_flux = 0.175,
                 air_temperature = 38, wind_speed_2m = 3.3,
                 vapour_pressure_deficit = 3.18, slope = 0.358,
                 psychrometric = 0.0673)
call_ref <- function(...) do.call(ef_ref_et, c(ref_args, list(...)))

test_that("ef_ref_et() requires explicit reference, timestep and standard", {
  expect_error(call_ref(timestep = "hourly", standard = "fao56"),
               class = "earthflux_missing_input")
  expect_error(call_ref(reference = "grass", standard = "fao56"),
               class = "earthflux_missing_input")
  expect_error(call_ref(reference = "grass", timestep = "hourly"),
               class = "earthflux_missing_input")
  expect_error(call_ref(reference = "Grass", timestep = "hourly",
                        standard = "fao56"),
               class = "earthflux_unknown_method")
  expect_error(call_ref(reference = "grass", timestep = "daily",
                        standard = "asce-ewri"),
               class = "earthflux_unknown_method")
})

test_that("FAO-56 with the alfalfa reference is a classed error", {
  cnd <- expect_error(call_ref(reference = "alfalfa", timestep = "hourly",
                               standard = "fao56"),
                      class = "earthflux_undefined_reference")
  expect_s3_class(cnd, "earthflux_input_error")
  expect_identical(cnd$reference, "alfalfa")
  expect_error(ef_ref_soil_heat_flux(1, "alfalfa", "daily", "fao56"),
               class = "earthflux_undefined_reference")
})

test_that("daytime is required for hourly ASCE and refused for daily", {
  expect_error(call_ref(reference = "grass", timestep = "hourly",
                        standard = "asce"),
               class = "earthflux_missing_input")
  expect_error(call_ref(reference = "grass", timestep = "daily",
                        standard = "fao56", daytime = TRUE),
               class = "earthflux_input_error")
  expect_error(call_ref(reference = "grass", timestep = "hourly",
                        standard = "asce", daytime = 1),
               class = "earthflux_input_error")
  expect_error(
    ef_ref_et(c(1, 2), 0, 30, 2, 2, 0.25, 0.067, reference = "grass",
              timestep = "hourly", standard = "asce",
              daytime = c(TRUE, FALSE, TRUE)),
    class = "earthflux_input_error"
  )
  # Hourly FAO-56: daytime not needed and not used (same result).
  a <- call_ref(reference = "grass", timestep = "hourly", standard = "fao56")
  b <- call_ref(reference = "grass", timestep = "hourly", standard = "fao56",
                daytime = FALSE)
  expect_identical(a$et_ref, b$et_ref)
  # G of the reference: daytime required for hourly, refused for daily.
  expect_error(ef_ref_soil_heat_flux(1, "grass", "hourly", "fao56"),
               class = "earthflux_missing_input")
  expect_error(ef_ref_soil_heat_flux(1, "grass", "daily", "fao56",
                                     daytime = TRUE),
               class = "earthflux_input_error")
})

test_that("ef_ref_et() checks the domain of its inputs", {
  ok <- list(reference = "grass", timestep = "hourly", standard = "fao56")
  bad <- list(slope = 0, psychrometric = -0.06, wind_speed_2m = -1,
              air_temperature = -273, net_radiation = Inf)
  for (nm in names(bad)) {
    args <- utils::modifyList(ref_args, bad[nm])
    expect_error(do.call(ef_ref_et, c(args, ok)),
                 class = "earthflux_domain_error", info = nm)
  }
  args <- utils::modifyList(ref_args, list(slope = "0.3"))
  expect_error(do.call(ef_ref_et, c(args, ok)),
               class = "earthflux_input_error")
  args <- utils::modifyList(ref_args, list(slope = c(0.3, 0.4, 0.5),
                                           psychrometric = c(0.06, 0.07)))
  expect_error(do.call(ef_ref_et, c(args, ok)),
               class = "earthflux_input_error")
  # A negative deficit (ea above es) is kept.
  args <- utils::modifyList(ref_args, list(vapour_pressure_deficit = -0.1))
  expect_type(do.call(ef_ref_et, c(args, ok))$et_ref, "double")
})

# NA, dim and flags ------------------------------------------------------------------

test_that("ef_ref_et() propagates NA, keeps dim and flags EF_INPUT_NA", {
  et <- ef_ref_et(
    net_radiation = matrix(c(1.7, NA, 1.5, 1.2), 2), soil_heat_flux = 0.1,
    air_temperature = 30, wind_speed_2m = 2, vapour_pressure_deficit = 2,
    slope = 0.25, psychrometric = 0.067, reference = "alfalfa",
    timestep = "hourly", standard = "asce",
    daytime = matrix(c(TRUE, TRUE, NA, TRUE), 2)
  )
  expect_identical(dim(et$et_ref), c(2L, 2L))
  expect_identical(which(is.na(et$et_ref)), c(2L, 3L))
  expect_identical(flag_codes(et), "EF_INPUT_NA")
  expect_identical(flag_index(et, "EF_INPUT_NA"), c(2L, 3L))
  expect_identical(et$flags[[1L]]$scope, "record")
  expect_error(
    ef_ref_et(matrix(1, 2, 2), 0, 30, 2, 2, 0.25, 0.067, "grass", "hourly",
              "asce", daytime = c(TRUE, FALSE, TRUE, FALSE, TRUE)),
    class = "earthflux_input_error"
  )
})

test_that("negative reference ET is kept and flagged EF_WS_ETR_NEGATIVE", {
  # Case A1 at night with a more negative Rn (spec 8.4, "No truncar").
  n <- ndiaye$night
  rn <- c(n$rn$rn, -0.5)
  g <- ef_ref_soil_heat_flux(rn, "grass", "hourly", "fao56",
                             daytime = FALSE)
  et <- ef_ref_et(rn, g, n$t, n$u2, n$e0 - n$ea, n$slope, ndiaye$gamma,
                  reference = "grass", timestep = "hourly",
                  standard = "fao56")
  expect_gt(et$et_ref[1], 0)
  expect_lt(et$et_ref[2], 0)
  manual <- (0.408 * n$slope * (-0.5 - 0.5 * -0.5) +
               ndiaye$gamma * 37 / (n$t + 273) * n$u2 * (n$e0 - n$ea)) /
    (n$slope + ndiaye$gamma * (1 + 0.34 * n$u2))
  expect_equal(et$et_ref[2], manual, tolerance = 1e-12)
  expect_identical(flag_codes(et), "EF_WS_ETR_NEGATIVE")
  expect_identical(flag_index(et, "EF_WS_ETR_NEGATIVE"), 2L)
  expect_identical(et$flags[[1L]]$severity, "info")
  # Negative case: no flag where the value is positive.
  pos <- ef_ref_et(rn[1], g[1], n$t, n$u2, n$e0 - n$ea, n$slope,
                   ndiaye$gamma, reference = "grass", timestep = "hourly",
                   standard = "fao56")
  expect_identical(pos$flags, list())
  expect_true("EF_WS_ETR_NEGATIVE" %in% pos$provenance$flags_evaluated)
})

# Net radiation of the reference surface ---------------------------------------------

test_that("Rs/Rso is limited to 1 only in the cloudiness term (flagged)", {
  rn <- ef_ref_net_radiation(
    solar_radiation = c(2.0, 3.0, NA), clear_sky_radiation = 2.5,
    vapour_pressure = 2, air_temperature = 30, timestep = "hourly"
  )
  # Rs is not modified: Rns = 0.77 Rs.
  expect_equal(rn$rns, 0.77 * c(2.0, 3.0, NA), tolerance = 1e-12)
  expect_equal(rn$cloudiness[1:2], c(1.35 * 0.8 - 0.35, 1),
               tolerance = 1e-12)
  expect_identical(flag_codes(rn), c("EF_INPUT_NA", "EF_WS_RS_RSO_LIMITED"))
  expect_identical(flag_index(rn, "EF_WS_RS_RSO_LIMITED"), 2L)
  expect_identical(flag_index(rn, "EF_INPUT_NA"), 3L)
  expect_true(is.na(rn$rn[3]))
  # Rs = Rso exactly: no limitation, no flag.
  eq <- ef_ref_net_radiation(2.5, 2.5, 2, air_temperature = 30,
                             timestep = "hourly")
  expect_identical(eq$flags, list())
  expect_setequal(eq$provenance$flags_evaluated,
                  c("EF_INPUT_NA", "EF_WS_RS_RSO_LIMITED"))
})

test_that("hourly Rnl uses sigma / 24 and T_hr; daily the mean of T^4", {
  rn_h <- ef_ref_net_radiation(1, 2, 1.5, air_temperature = 20,
                               timestep = "hourly")
  expected <- 4.903e-9 / 24 * (20 + 273.16)^4 * (0.34 - 0.14 * sqrt(1.5)) *
    (1.35 * 0.5 - 0.35)
  expect_equal(rn_h$rnl, expected, tolerance = 1e-12)
  rn_d <- ef_ref_net_radiation(20, 25, 1.5, tmax = 25, tmin = 15,
                               timestep = "daily")
  expected <- 4.903e-9 * ((25 + 273.16)^4 + (15 + 273.16)^4) / 2 *
    (0.34 - 0.14 * sqrt(1.5)) * (1.35 * 0.8 - 0.35)
  expect_equal(rn_d$rnl, expected, tolerance = 1e-12)
  expect_equal(rn_d$rn, 0.77 * 20 - expected, tolerance = 1e-12)
})

test_that("ef_ref_net_radiation() checks timestep, inputs and domain", {
  expect_error(ef_ref_net_radiation(1, 2, 1.5, air_temperature = 20),
               class = "earthflux_missing_input")
  expect_error(ef_ref_net_radiation(1, 2, 1.5, air_temperature = 20,
                                    timestep = "10min"),
               class = "earthflux_unknown_method")
  expect_error(ef_ref_net_radiation(1, 2, 1.5, air_temperature = 20,
                                    timestep = "daily"),
               class = "earthflux_missing_input")
  expect_error(ef_ref_net_radiation(1, 2, 1.5, tmax = 25, tmin = 15,
                                    timestep = "hourly"),
               class = "earthflux_missing_input")
  expect_error(ef_ref_net_radiation(1, NULL, 1.5, air_temperature = 20,
                                    timestep = "hourly"),
               class = "earthflux_missing_input")
  # Rso = 0 (night) without cloudiness: ratio undefined.
  expect_error(ef_ref_net_radiation(0, 0, 1.5, air_temperature = 20,
                                    timestep = "hourly"),
               class = "earthflux_domain_error")
  expect_error(ef_ref_net_radiation(1, 2, 1.5, tmax = 15, tmin = 25,
                                    timestep = "daily"),
               class = "earthflux_domain_error")
  expect_error(ef_ref_net_radiation(-1, 2, 1.5, air_temperature = 20,
                                    timestep = "hourly"),
               class = "earthflux_domain_error")
  expect_error(ef_ref_net_radiation(1, 2, -0.1, air_temperature = 20,
                                    timestep = "hourly"),
               class = "earthflux_domain_error")
  expect_error(ef_ref_net_radiation(1, 2, 1.5, air_temperature = -280,
                                    timestep = "hourly"),
               class = "earthflux_domain_error")
  expect_error(ef_ref_net_radiation(0, NULL, 1.5, air_temperature = 20,
                                    timestep = "hourly", cloudiness = 1.2),
               class = "earthflux_domain_error")
  expect_error(ef_ref_net_radiation(c(1, 2), 2, c(1, 1, 1),
                                    air_temperature = 20,
                                    timestep = "hourly"),
               class = "earthflux_input_error")
})

test_that("ef_ref_net_radiation() keeps dim and propagates NA", {
  m <- matrix(c(1, 2, NA, 1.5), 2)
  rn <- ef_ref_net_radiation(m, 2.5, 1.5, air_temperature = 25,
                             timestep = "hourly")
  for (nm in c("rn", "rns", "rnl", "cloudiness")) {
    expect_identical(dim(rn[[nm]]), c(2L, 2L), info = nm)
  }
  expect_identical(which(is.na(rn$rn)), 3L)
  # A supplied cloudiness with NA propagates.
  rn_c <- ef_ref_net_radiation(c(0, 0), NULL, 3.4, air_temperature = 28,
                               timestep = "hourly", cloudiness = c(0.73, NA))
  expect_identical(is.na(rn_c$rn), c(FALSE, TRUE))
  expect_identical(flag_index(rn_c, "EF_INPUT_NA"), 2L)
  expect_false("EF_WS_RS_RSO_LIMITED" %in% rn_c$provenance$flags_evaluated)
})

# Soil heat flux of the reference surface ---------------------------------------------

test_that("ef_ref_soil_heat_flux() uses the ratios of the constants table", {
  rn <- c(2, -0.2)
  dn <- c(TRUE, FALSE)
  expect_equal(ef_ref_soil_heat_flux(rn, "grass", "hourly", "fao56", dn),
               c(0.2, -0.1), tolerance = 1e-12)
  expect_equal(ef_ref_soil_heat_flux(rn, "grass", "hourly", "asce", dn),
               c(0.2, -0.1), tolerance = 1e-12)
  expect_equal(ef_ref_soil_heat_flux(rn, "alfalfa", "hourly", "asce", dn),
               c(0.08, -0.04), tolerance = 1e-12)
  expect_identical(ef_ref_soil_heat_flux(c(5, NA), "alfalfa", "daily",
                                         "asce"),
                   c(0, NA))
  expect_identical(
    is.na(ef_ref_soil_heat_flux(1, "grass", "hourly", "fao56",
                                c(TRUE, NA))),
    c(FALSE, TRUE)
  )
  m <- matrix(c(1, 2, 3, 4), 2)
  expect_identical(
    dim(ef_ref_soil_heat_flux(m, "grass", "hourly", "fao56", TRUE)),
    c(2L, 2L)
  )
  expect_error(ef_ref_soil_heat_flux(Inf, "grass", "daily", "fao56"),
               class = "earthflux_domain_error")
  expect_error(ef_ref_soil_heat_flux("1", "grass", "daily", "fao56"),
               class = "earthflux_input_error")
  expect_error(ef_ref_soil_heat_flux(1, timestep = "daily",
                                     standard = "fao56"),
               class = "earthflux_missing_input")
})

# Flag registry ---------------------------------------------------------------------

test_that("the stage registers its two class I codes", {
  rows <- ef_flags_reference_et()
  expect_identical(rows$code, c("EF_WS_RS_RSO_LIMITED", "EF_WS_ETR_NEGATIVE"))
  expect_identical(names(rows), names(ef_flag_registry()))
  expect_identical(rows$stage, c("WS", "WS"))
  expect_identical(rows$severity, c("info", "info"))
  expect_identical(rows$scope, c("record", "record"))
  expect_identical(rows$bit, c(NA_integer_, NA_integer_))
  reg <- ef_flag_registry()
  expect_true(all(rows$code %in% reg$code))
  # The pre-normalisation name is not registered.
  expect_false("EF_ETREF_NEGATIVE" %in% reg$code)
})

# Options O3 and D1 (spec 5.5 and 5.6; internal) -------------------------------------

test_that("O3: reference ET at the overpass by linear interpolation", {
  # Spec 5.5: midpoints 14:30 and 15:30 UTC with 0.70 and 0.80 mm h-1;
  # overpass 15:12 UTC -> 0.70 + 0.7 * 0.10 = 0.77 mm h-1.
  expect_equal(ef_ref_et_inst_interp(c(0.70, 0.80), c(14.5, 15.5), 15.2),
               0.77, tolerance = 1e-12)
  # At a midpoint: the rate of that period; outside the records: NA.
  out <- ef_ref_et_inst_interp(c(0.70, 0.80), c(14.5, 15.5),
                               c(14.5, 15.5, 14.4, 15.6))
  expect_equal(out, c(0.70, 0.80, NA, NA), tolerance = 1e-12)
  # No interpolation across a missing record.
  expect_identical(
    ef_ref_et_inst_interp(c(0.7, NA, 0.9), c(14.5, 15.5, 16.5), c(15, 16.2)),
    c(NA_real_, NA_real_)
  )
  expect_error(ef_ref_et_inst_interp(c(0.7, 0.8), c(15.5, 14.5), 15),
               class = "earthflux_input_error")
  expect_error(ef_ref_et_inst_interp(0.7, 14.5, 15),
               class = "earthflux_input_error")
})

test_that("D1: daily sums of complete days and the day definition", {
  # 48 hourly values; a station in UTC-4: the local standard day and the
  # UTC day group different hours and give different sums (spec 8.4, WF-D).
  et <- (1:48) / 100
  hours_utc <- 0:47
  day_utc <- hours_utc %/% 24
  day_local <- (hours_utc - 4) %/% 24
  sums_utc <- ef_ref_et_daily_sum(et, day_utc, 24)
  expect_equal(unname(sums_utc), c(sum(et[1:24]), sum(et[25:48])),
               tolerance = 1e-12)
  sums_local <- ef_ref_et_daily_sum(et, day_local, 24)
  # Local days: day -1 has 4 periods (incomplete -> NA), day 0 is complete,
  # day 1 has 20 periods (incomplete -> NA).
  expect_identical(names(sums_local), c("-1", "0", "1"))
  expect_true(is.na(sums_local[["-1"]]))
  expect_true(is.na(sums_local[["1"]]))
  expect_equal(sums_local[["0"]], sum(et[5:28]), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(sums_local[["0"]], sums_utc[["0"]])))
  # A missing value makes the day NA (no filling).
  et_na <- et
  et_na[30] <- NA
  expect_true(is.na(ef_ref_et_daily_sum(et_na, day_utc, 24)[["1"]]))
  expect_error(ef_ref_et_daily_sum(et, day_utc[-1], 24),
               class = "earthflux_input_error")
  expect_error(ef_ref_et_daily_sum(et, day_utc, 23.5),
               class = "earthflux_input_error")
})
