# End-to-end test of the MODIS surface chain (milestone M4)
#
# A tiny SYNTHETIC scene (helper-modis-surface.R: GeoTIFF "granules" of
# hand-made DN for MOD11A1 LST + QC + view time, MCD43A3 albedo, MOD13A2
# NDVI and MCD15A2H LAI, declared as converted DN files, on the upper-left
# corner of tile h12v12) is run, in pipeline order, through:
#
#   modis_surface_state()  (scaling, QA, view time -> UTC, aggregation of
#                           the 500 m layers, blue-sky albedo, E3
#                           emissivity, composite matching, flag words)
#     -> hand-over to the METRIC core as described in dev/ARCHITECTURE.md
#        section 4: cell-order numeric vectors, degrees -> radians, the
#        cells with a critical surface bit (EF_SURF_ALBEDO_GT1) set to NA
#        and counted (surface_exclusion())
#     -> ef_solar_geometry() at the overpass instant (doy, utc_hour)
#     -> ef_rl_out() with lst and emissivity
#     -> ef_net_radiation() with synthetic forcing (clear-sky shortwave with
#        a made-up transmissivity, made-up incoming longwave) and the same
#        emissivity (RC-14, requirement C2)
#     -> ef_g() (method "bastiaanssen", lst, albedo, ndvi).
#
# What is verified (structural invariants, no reference numbers):
#   * the stages connect: each output is accepted by the next stage;
#   * units and dimensions: K, radians, W m-2; every output has one value
#     per cell of the working grid;
#   * the equation of time is applied exactly once: the solar hour of the
#     hour angle equals the view time (local mean solar time) plus the
#     equation of time of the UTC date;
#   * flags: the missing overpass gives NA solar geometry and NA Rn and G
#     in that cell only; the albedo above 1 is excluded before the core
#     (otherwise the core raises earthflux_domain_error); NA from QA
#     propagates.
#
# What is NOT verified: the realism of any value (synthetic DN and forcing;
# the conversions and METRIC forms used are CANDIDATA).

test_that("the surface state feeds one METRIC step with the core contract", {
  dir <- ss_dir()
  st <- modis_surface_state(ss_scene(dir), aoi = NULL,
                            options = ss_options())
  n <- terra::ncell(st$lst)
  val <- function(x) terra::values(x, mat = FALSE)

  # Hand-over (ARCHITECTURE section 4) --------------------------------------
  lst <- val(st$lst)
  albedo <- val(st$albedo)
  ndvi <- val(st$ndvi)
  emissivity <- val(st$emissivity)
  doy <- val(st$overpass_time$doy)
  utc_hour <- val(st$overpass_time$utc_hour)
  lon <- val(st$lonlat[["lon"]]) * pi / 180
  lat <- val(st$lonlat[["lat"]]) * pi / 180
  ex <- surface_exclusion(st)
  expect_identical(which(ex$exclude), 7L)
  albedo_core <- albedo
  albedo_core[ex$exclude] <- NA_real_
  expect_true(all(lengths(list(lst, albedo, ndvi, emissivity, doy, utc_hour,
                               lon, lat)) == n))
  expect_true(all(abs(lat) <= pi / 2) && all(abs(lon) <= pi))

  # Solar geometry at the overpass ------------------------------------------
  geo <- ef_solar_geometry(doy = doy, utc_hour = utc_hour, lat = lat,
                           lon = lon)
  # missing overpass (cells 2 and 5) -> NA geometry, nowhere else
  expect_identical(which(is.na(geo$cos_zenith)), c(2L, 5L))
  ok <- !is.na(geo$cos_zenith)
  expect_true(all(geo$cos_zenith[ok] > 0 & geo$cos_zenith[ok] <= 1))
  # equation of time applied once: solar hour = view time + Sc(doy)
  view_time <- c(10.5, NA, 10.6, 10.5, NA, 10.4, 10.5, 10.5, 10.6, 10.5,
                 10.5, 10.4)
  solar_hour <- (geo$hour_angle * 12 / pi + 12) %% 24
  sc <- ef_equation_of_time(15)
  expect_equal(solar_hour[ok], (view_time[ok] + sc) %% 24, tolerance = 1e-9)
  expect_gt(abs(sc), 5 / 60) # a missing or double Sc would be detected

  # Radiation -----------------------------------------------------------------
  rl_out <- ef_rl_out(lst, emissivity)
  expect_length(rl_out, n)
  expect_true(all(rl_out > 0, na.rm = TRUE))
  # synthetic forcing: clear-sky shortwave with a made-up transmissivity of
  # 0.75 and a made-up incoming longwave of 320 W m-2
  rs_in <- EF_SOLAR_CONSTANT * geo$inv_distance * geo$cos_zenith * 0.75
  rl_in <- rep(320, n)
  expect_error(ef_net_radiation(rs_in, albedo, rl_in, rl_out, emissivity),
               class = "earthflux_domain_error")
  rn <- ef_net_radiation(rs_in, albedo_core, rl_in, rl_out, emissivity)
  expect_length(rn, n)
  # NA where: LST cloud (2), overpass missing (5), albedo excluded (7),
  # emissivity from a non-vegetated LAI class (10)
  expect_identical(which(is.na(rn)), c(2L, 5L, 7L, 10L))
  expect_true(all(rn[!is.na(rn)] > 0 & rn[!is.na(rn)] < rs_in[!is.na(rn)]))
  # the emissivity of Rn is the one of RL_out (RC-14, C2)
  i <- 1L
  expect_equal(
    rn[i],
    (1 - albedo[i]) * rs_in[i] + rl_in[i] - rl_out[i] -
      (1 - emissivity[i]) * rl_in[i],
    tolerance = 1e-12
  )

  # Soil heat flux ------------------------------------------------------------
  g <- ef_g(rn, lst = lst, albedo = albedo_core, ndvi = ndvi,
            method = "bastiaanssen")
  expect_s3_class(g, "earthflux_soil_heat_flux")
  expect_length(g$g, n)
  expect_identical(which(is.na(g$g)), which(is.na(rn)))
  expect_true(all(g$g_rn_ratio > 0 & g$g_rn_ratio < 1, na.rm = TRUE))
  na_rec <- Filter(function(f) f$code == "EF_INPUT_NA", g$flags)
  expect_identical(na_rec[[1]]$index, c(2L, 5L, 7L, 10L))
})
