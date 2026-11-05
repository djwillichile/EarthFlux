# MODIS preparation steps (R/prep-modis.R): view time -> UTC, broadband
# conversions, NDVI, temporal matching and resampling.
#
# All inputs are SYNTHETIC numbers and tiny SYNTHETIC SpatRasters built in
# the tests; no real MODIS data, no files on disk, no network. Expected
# values are the arithmetic cases of dev/specs/modis-products.md (V1-V4 of
# section 6.2, N1 and G1 of section 14) or are computed by hand below.

# Synthetic sinusoidal grid (MODIS sphere, dev/specs/modis-products.md 4).
sinu_crs <- paste0("+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +R=6371007.181 ",
                   "+units=m +no_defs")

synthetic_raster <- function(values, nrow, ncol, cell = 500,
                             xmin = 0, ymin = -500, crs = sinu_crs) {
  r <- terra::rast(nrows = nrow, ncols = ncol, xmin = xmin,
                   xmax = xmin + ncol * cell, ymin = ymin,
                   ymax = ymin + nrow * cell, crs = crs)
  terra::values(r) <- values
  r
}

# modis_overpass_time() --------------------------------------------------------

test_that("view time -> UTC reproduces cases V1-V4 of section 6.2", {
  d <- as.Date("2019-01-15")
  res <- modis_overpass_time(
    view_time_h = c(10.6, 23.0, 1.0, NA),
    lon_deg = c(-71, -170, 170, -71),
    date_utc = d
  )
  expect_equal(res$utc_hour, c(10.6 + 71 / 15, 23 + 170 / 15 - 24,
                               1 - 170 / 15 + 24, NA),
               tolerance = 1e-12)
  expect_equal(res$utc_hour[1:3], c(15 + 20 / 60, 10 + 20 / 60,
                                    13 + 40 / 60), tolerance = 1e-12)
  expect_equal(res$doy, c(15, 15, 15, NA))
  expect_identical(res$missing, c(FALSE, FALSE, FALSE, TRUE))
  # The instant stays inside the UTC day of the file (no date shift).
  expect_equal(
    res$time[1:3],
    as.POSIXct(c("2019-01-15 15:20:00", "2019-01-15 10:20:00",
                 "2019-01-15 13:40:00"), tz = "UTC"),
    tolerance = 1e-6
  )
  expect_identical(attr(res$time, "tzone"), "UTC")
  expect_true(is.na(res$time[4]))
})

test_that("view time -> UTC handles the year boundary and per-pixel dates", {
  res <- modis_overpass_time(
    view_time_h = c(10.6, 1.0),
    lon_deg = c(-71, 170),
    date_utc = as.Date(c("2020-12-31", "2021-01-01"))
  )
  expect_equal(res$doy, c(366, 1))
  expect_equal(format(res$time, "%Y-%m-%d %H:%M", tz = "UTC"),
               c("2020-12-31 15:20", "2021-01-01 13:40"))
})

test_that("view time -> UTC keeps dim and recycles length-1 inputs", {
  vt <- matrix(c(10.6, 10.7, NA, 10.9), 2, 2)
  res <- modis_overpass_time(vt, lon_deg = -71,
                             date_utc = as.Date("2019-01-15"))
  expect_identical(dim(res$utc_hour), c(2L, 2L))
  expect_identical(dim(res$doy), c(2L, 2L))
  expect_identical(dim(res$missing), c(2L, 2L))
  expect_equal(res$utc_hour[1, 2], NA_real_)
  expect_length(res$time, 4L)
})

test_that("view time -> UTC result rounding to 24 h is set to 0 h", {
  # 0 - 1e-15 / 15 is a tiny negative number. Whether its %% 24 rounds to
  # exactly 24 depends on the platform's floating-point arithmetic (it does
  # on x86_64 but not on macOS arm64), so the test checks the result, which
  # must lie in [0, 24) and be 0 h up to the 24 h wrap-around.
  res <- modis_overpass_time(0, lon_deg = 1e-15,
                             date_utc = as.Date("2019-01-15"))
  expect_true(res$utc_hour >= 0 && res$utc_hour < 24)
  expect_lt(min(res$utc_hour, 24 - res$utc_hour), 1e-12)
  expect_equal(res$doy, 15)
})

test_that("view time -> UTC validates its inputs with classed errors", {
  d <- as.Date("2019-01-15")
  expect_error(modis_overpass_time(24.1, -71, d),
               class = "earthflux_domain_error")
  expect_error(modis_overpass_time(-0.1, -71, d),
               class = "earthflux_domain_error")
  expect_error(modis_overpass_time(10, -181, d),
               class = "earthflux_domain_error")
  expect_error(modis_overpass_time(10, -71, "2019-01-15"),
               class = "earthflux_input_error")
  expect_error(modis_overpass_time(10, -71, as.POSIXct(d)),
               class = "earthflux_input_error")
  expect_error(modis_overpass_time(10, -71, as.Date(NA)),
               class = "earthflux_input_error")
  expect_error(modis_overpass_time(c(10, 11, 12), -71, rep(d, 2)),
               class = "earthflux_input_error")
  expect_error(modis_overpass_time(numeric(0), -71, d),
               class = "earthflux_input_error")
  expect_error(modis_overpass_time(10, date_utc = d),
               class = "earthflux_missing_input")
  expect_error(modis_overpass_time(c(10, 11), c(-71, -70, -69), d),
               class = "earthflux_input_error")
})

test_that("overpass -> solar geometry applies the equation of time once", {
  # Solar-hour round trip: the hour angle computed by ef_solar_geometry()
  # from the converted UTC hour must correspond to the apparent solar time
  # t_ls + Sc (mean solar time of the view time plus the equation of time
  # applied exactly once). Zero or two applications would shift it by Sc.
  view_time <- c(10.6, 11.3, 13.5, 12.0)
  lon <- c(-71, -70.2, 170, -170)
  dates <- as.Date(c("2019-02-10", "2019-11-03", "2019-10-20",
                     "2019-07-26"))
  ovp <- modis_overpass_time(view_time, lon, dates)
  geo <- ef_solar_geometry(doy = ovp$doy, utc_hour = ovp$utc_hour,
                           lat = -35 * pi / 180, lon = lon * pi / 180)
  solar_hour <- geo$hour_angle * 12 / pi + 12
  sc <- ef_equation_of_time(ovp$doy)
  expect_equal(solar_hour, (view_time + sc) %% 24, tolerance = 1e-10)
  # Sc is not negligible on these dates (|Sc| > 5 min), so the test would
  # detect a missing or a double equation of time.
  expect_true(all(abs(sc) > 5 / 60))
})

test_that("view time -> UTC on a SpatRaster equals the numeric path", {
  # SYNTHETIC 2 x 3 sinusoidal raster of view times [h].
  vt <- synthetic_raster(c(10.6, 10.7, 10.8, NA, 11.0, 11.1), 2, 3,
                         cell = 1000, xmin = -7.9e6)
  d <- as.Date("2019-01-15")
  ll <- modis_cell_lonlat(vt)
  res_r <- modis_overpass_time(vt, date_utc = d)
  res_n <- modis_overpass_time(terra::values(vt, mat = FALSE),
                               terra::values(ll[["lon"]], mat = FALSE), d)
  expect_s4_class(res_r$utc_hour, "SpatRaster")
  expect_true(terra::compareGeom(res_r$utc_hour, vt))
  expect_equal(terra::values(res_r$utc_hour, mat = FALSE), res_n$utc_hour)
  expect_equal(terra::values(res_r$doy, mat = FALSE), res_n$doy)
  expect_equal(as.logical(terra::values(res_r$missing, mat = FALSE)),
               res_n$missing)
  expect_equal(res_r$time, res_n$time)
  # An explicit longitude raster gives the same result.
  res_l <- modis_overpass_time(vt, lon_deg = ll[["lon"]], date_utc = d)
  expect_equal(terra::values(res_l$utc_hour), terra::values(res_r$utc_hour))
  expect_error(modis_overpass_time(vt, date_utc = rep(d, 2)),
               class = "earthflux_input_error")
})

test_that("cell centre coordinates follow the sinusoidal definition", {
  # On the equator (cell centres at y = 0) the sinusoidal x is R * lon.
  r <- synthetic_raster(1:3, 1, 3, cell = 1000, xmin = -7.9e6)
  ll <- modis_cell_lonlat(r)
  x <- terra::xFromCell(r, 1:3)
  expect_equal(terra::values(ll[["lon"]], mat = FALSE),
               x / 6371007.181 * 180 / pi, tolerance = 1e-9)
  expect_equal(terra::values(ll[["lat"]], mat = FALSE), rep(0, 3),
               tolerance = 1e-9)
  # Geographic rasters are returned unchanged.
  g <- synthetic_raster(1:2, 1, 2, cell = 1, xmin = -72, ymin = -36,
                        crs = "EPSG:4326")
  expect_equal(terra::values(modis_cell_lonlat(g)[["lon"]], mat = FALSE),
               c(-71.5, -70.5))
  expect_error(modis_cell_lonlat(1), class = "earthflux_input_error")
  expect_error(modis_cell_lonlat(terra::rast(nrows = 1, ncols = 1, crs = "")),
               class = "earthflux_input_error")
})

# modis_albedo() ---------------------------------------------------------------

test_that("broadband albedo options A1-A3 follow their formulas", {
  bsa <- c(0.15, 0.20, NA)
  wsa <- c(0.18, 0.22, 0.25)
  s <- 0.2
  a1 <- modis_albedo(bsa, wsa, diffuse_fraction = s, method = "blue_sky")
  expect_equal(a1$albedo, c(0.8 * 0.15 + 0.2 * 0.18, 0.8 * 0.20 + 0.2 * 0.22,
                            NA))
  expect_equal(a1$albedo[1], 0.156)
  expect_identical(a1$gt1, c(FALSE, FALSE, FALSE))
  expect_equal(modis_albedo(wsa = wsa, method = "white_sky")$albedo, wsa)
  expect_equal(modis_albedo(bsa = bsa, method = "black_sky")$albedo, bsa)
  # Limits of the diffuse fraction.
  expect_equal(modis_albedo(bsa, wsa, 0, method = "blue_sky")$albedo, bsa)
  # NA propagates even when its weight is zero.
  expect_equal(modis_albedo(bsa, wsa, 1, method = "blue_sky")$albedo,
               c(0.18, 0.22, NA))
})

test_that("albedo > 1 is kept and returned in the gt1 mask", {
  res <- modis_albedo(bsa = c(0.3, 1.2), method = "black_sky")
  expect_equal(res$albedo, c(0.3, 1.2))
  expect_identical(res$gt1, c(FALSE, TRUE))
  m <- modis_albedo(wsa = matrix(c(0.1, 1.5, 0.2, NA), 2), method = "white_sky")
  expect_identical(dim(m$albedo), c(2L, 2L))
  expect_identical(dim(m$gt1), c(2L, 2L))
  expect_identical(as.vector(m$gt1), c(FALSE, TRUE, FALSE, FALSE))
})

test_that("albedo method and inputs are checked with classed errors", {
  expect_error(modis_albedo(0.2, 0.2, 0.3), class = "earthflux_missing_input")
  expect_error(modis_albedo(0.2, 0.2, 0.3, method = "blue"),
               class = "earthflux_unknown_method")
  for (m in c("bsa_at_overpass", "narrow_to_broadband", "metric_tasumi")) {
    cnd <- expect_error(modis_albedo(bsa = 0.2, method = m),
                        class = "earthflux_method_not_implemented")
    expect_s3_class(cnd, "earthflux_unknown_method")
    expect_identical(cnd$choices, c("blue_sky", "white_sky", "black_sky"))
  }
  expect_error(modis_albedo(0.2, 0.2, method = "blue_sky"),
               class = "earthflux_missing_input")
  expect_error(modis_albedo(0.2, 0.2, method = "white_sky"),
               class = "earthflux_input_error")
  expect_error(modis_albedo(wsa = 0.2, diffuse_fraction = 0.3,
                            method = "white_sky"),
               class = "earthflux_input_error")
  expect_error(modis_albedo(-0.01, 0.2, 0.3, method = "blue_sky"),
               class = "earthflux_domain_error")
  expect_error(modis_albedo(0.2, 0.2, 1.1, method = "blue_sky"),
               class = "earthflux_domain_error")
  expect_error(modis_albedo(c(0.2, 0.3), c(0.2, 0.3, 0.4), 0.3,
                            method = "blue_sky"),
               class = "earthflux_input_error")
  expect_error(modis_albedo(bsa = "0.2", method = "black_sky"),
               class = "earthflux_input_error")
})

test_that("albedo on SpatRasters equals the numeric path", {
  # SYNTHETIC 2 x 2 albedo rasters.
  b <- synthetic_raster(c(0.15, 0.2, NA, 1.1), 2, 2)
  w <- synthetic_raster(c(0.18, 0.22, 0.25, 1.2), 2, 2)
  res_r <- modis_albedo(b, w, diffuse_fraction = 0.3, method = "blue_sky")
  res_n <- modis_albedo(terra::values(b, mat = FALSE),
                        terra::values(w, mat = FALSE), 0.3,
                        method = "blue_sky")
  expect_s4_class(res_r$albedo, "SpatRaster")
  expect_equal(terra::values(res_r$albedo, mat = FALSE), res_n$albedo)
  expect_equal(as.logical(terra::values(res_r$gt1, mat = FALSE)), res_n$gt1)
  w2 <- synthetic_raster(c(0.18, 0.22, 0.25, 1.2), 2, 2, xmin = 1000)
  expect_error(modis_albedo(b, w2, 0.3, method = "blue_sky"),
               class = "earthflux_input_error")
})

# modis_broadband_emissivity() -------------------------------------------------

test_that("broadband emissivity E3 follows 0.95 + 0.01 LAI capped at 0.98", {
  lai <- c(0, 1.5, 3, 6, NA)
  expect_equal(modis_broadband_emissivity(lai = lai, method = "lai_empirical"),
               c(0.95, 0.965, 0.98, 0.98, NA))
  m <- modis_broadband_emissivity(lai = matrix(c(0, 1, 2, 4), 2),
                                  method = "lai_empirical")
  expect_identical(dim(m), c(2L, 2L))
  r <- synthetic_raster(c(0, 1, 2, 4), 2, 2)
  er <- modis_broadband_emissivity(lai = r, method = "lai_empirical")
  expect_s4_class(er, "SpatRaster")
  expect_equal(terra::values(er, mat = FALSE), c(0.95, 0.96, 0.97, 0.98))
})

test_that("broadband emissivity rejects TODO methods and misuse", {
  expect_error(modis_broadband_emissivity(lai = 1),
               class = "earthflux_missing_input")
  for (m in c("split_window_regression", "tes_regression", "camel")) {
    cnd <- expect_error(
      modis_broadband_emissivity(e31 = 0.97, e32 = 0.98, method = m),
      class = "earthflux_method_not_implemented"
    )
    expect_identical(cnd$choices, "lai_empirical")
  }
  expect_error(modis_broadband_emissivity(lai = 1, method = "lai"),
               class = "earthflux_unknown_method")
  expect_error(modis_broadband_emissivity(method = "lai_empirical"),
               class = "earthflux_missing_input")
  expect_error(modis_broadband_emissivity(e31 = 0.97, lai = 1,
                                          method = "lai_empirical"),
               class = "earthflux_input_error")
  expect_error(modis_broadband_emissivity(lai = -0.1,
                                          method = "lai_empirical"),
               class = "earthflux_domain_error")
})

# modis_ndvi_from_reflectance() ------------------------------------------------

test_that("NDVI from reflectance reproduces case N1 and its masks", {
  expect_equal(modis_ndvi_from_reflectance(0.05, 0.45)$ndvi, 0.8)
  res <- modis_ndvi_from_reflectance(
    red = c(0.05, 0.1, 0, -0.01, -0.005, NA),
    nir = c(0.45, 0.1, 0, 0.3, 0.003, 0.3)
  )
  expect_equal(res$ndvi, c(0.8, 0, NA, 0.31 / 0.29, NA, NA))
  expect_identical(res$undefined, c(FALSE, FALSE, TRUE, FALSE, TRUE, FALSE))
  expect_identical(res$outside_unit,
                   c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE))
  m <- modis_ndvi_from_reflectance(matrix(0.1, 2, 2), 0.3)
  expect_identical(dim(m$ndvi), c(2L, 2L))
  expect_error(modis_ndvi_from_reflectance(0.1, Inf),
               class = "earthflux_domain_error")
  expect_error(modis_ndvi_from_reflectance(c(0.1, 0.2), c(0.1, 0.2, 0.3)),
               class = "earthflux_input_error")
})

test_that("NDVI on SpatRasters equals the numeric path", {
  red <- synthetic_raster(c(0.05, 0.1, 0, NA), 2, 2)
  nir <- synthetic_raster(c(0.45, 0.3, 0, 0.3), 2, 2)
  res_r <- modis_ndvi_from_reflectance(red, nir)
  res_n <- modis_ndvi_from_reflectance(terra::values(red, mat = FALSE),
                                       terra::values(nir, mat = FALSE))
  expect_equal(terra::values(res_r$ndvi, mat = FALSE), res_n$ndvi)
  expect_equal(as.logical(terra::values(res_r$undefined, mat = FALSE)),
               res_n$undefined)
})

# modis_match_composite() ------------------------------------------------------

test_that("composite matching T1 selects the period containing the date", {
  # SYNTHETIC 16-day periods.
  start <- as.Date(c("2019-01-01", "2019-01-17", "2019-02-02"))
  end <- start + 15
  res <- modis_match_composite(as.Date("2019-01-20"), start, end,
                               method = "period")
  expect_identical(res$index, 2L)
  expect_identical(res$start, as.Date("2019-01-17"))
  expect_identical(res$end, as.Date("2019-02-01"))
  expect_equal(res$lag_bound_days, 12)
  expect_null(res$lag_days)
  none <- modis_match_composite(as.Date("2019-03-01"), start, end,
                                method = "period")
  expect_identical(none$index, NA_integer_)
  expect_true(is.na(none$lag_bound_days))
  expect_error(modis_match_composite(as.Date("2019-01-18"), start,
                                     end + 3, method = "period"),
               class = "earthflux_input_error")
})

test_that("composite matching T2 returns the lag per pixel", {
  # SYNTHETIC period crossing the year boundary (19 Dec - 3 Jan).
  start <- as.Date(c("2018-12-03", "2018-12-19"))
  end <- start + 15
  doy <- matrix(c(353, 365, 1, 3, NA, 360), 2)
  res <- modis_match_composite(as.Date("2019-01-02"), start, end,
                               method = "period_pixel_lag",
                               composite_doy = doy)
  expect_identical(res$index, 2L)
  pixel <- as.Date(c("2018-12-19", "2018-12-31", "2019-01-01",
                     "2019-01-03", NA, "2018-12-26"))
  expect_equal(as.vector(res$lag_days),
               as.numeric(as.Date("2019-01-02") - pixel))
  expect_identical(dim(res$lag_days), c(2L, 3L))
  # Raster input equals the numeric path.
  r <- synthetic_raster(as.vector(t(doy)), 2, 3)
  rr <- modis_match_composite(as.Date("2019-01-02"), start, end,
                              method = "period_pixel_lag",
                              composite_doy = r)
  expect_s4_class(rr$lag_days, "SpatRaster")
  expect_equal(terra::values(rr$lag_days, mat = FALSE),
               as.numeric(as.Date("2019-01-02") - pixel[c(1, 3, 5, 2, 4, 6)]))
  # No composite: all lags NA.
  nr <- modis_match_composite(as.Date("2019-03-01"), start, end,
                              method = "period_pixel_lag",
                              composite_doy = c(1, 2))
  expect_identical(nr$lag_days, c(NA_real_, NA_real_))
  # Day of year outside the period, not whole or out of range.
  expect_error(modis_match_composite(as.Date("2019-01-02"), start, end,
                                     method = "period_pixel_lag",
                                     composite_doy = 100),
               class = "earthflux_domain_error")
  expect_error(modis_match_composite(as.Date("2019-01-02"), start, end,
                                     method = "period_pixel_lag",
                                     composite_doy = 1.5),
               class = "earthflux_input_error")
  expect_error(modis_match_composite(as.Date("2019-01-02"), start, end,
                                     method = "period_pixel_lag",
                                     composite_doy = 367),
               class = "earthflux_domain_error")
})

test_that("composite matching same_day selects the daily file of the date", {
  dates <- as.Date(c("2019-01-14", "2019-01-15", "2019-01-16"))
  res <- modis_match_composite(as.Date("2019-01-15"), dates,
                               method = "same_day")
  expect_identical(res$index, 2L)
  expect_identical(res$start, res$end)
  expect_equal(res$lag_bound_days, 0)
  none <- modis_match_composite(as.Date("2019-01-20"), dates,
                                method = "same_day")
  expect_identical(none$index, NA_integer_)
  expect_error(modis_match_composite(as.Date("2019-01-15"),
                                     c(dates, dates[2]), method = "same_day"),
               class = "earthflux_input_error")
})

test_that("composite matching checks its method and inputs", {
  start <- as.Date("2019-01-01")
  end <- start + 15
  lst <- as.Date("2019-01-05")
  expect_error(modis_match_composite(lst, start, end),
               class = "earthflux_missing_input")
  cnd <- expect_error(modis_match_composite(lst, start, end,
                                            method = "interpolate"),
                      class = "earthflux_method_not_implemented")
  expect_identical(cnd$choices, c("period", "period_pixel_lag", "same_day"))
  expect_error(modis_match_composite(lst, start, method = "period"),
               class = "earthflux_missing_input")
  expect_error(modis_match_composite(lst, start, end, method = "same_day"),
               class = "earthflux_input_error")
  expect_error(modis_match_composite(lst, start, end, method = "period",
                                     composite_doy = 3),
               class = "earthflux_input_error")
  expect_error(modis_match_composite(lst, start, end,
                                     method = "period_pixel_lag"),
               class = "earthflux_missing_input")
  expect_error(modis_match_composite("2019-01-05", start, end,
                                     method = "period"),
               class = "earthflux_input_error")
  expect_error(modis_match_composite(c(lst, lst), start, end,
                                     method = "period"),
               class = "earthflux_input_error")
  expect_error(modis_match_composite(lst, start, start - 1,
                                     method = "period"),
               class = "earthflux_input_error")
  expect_error(modis_match_composite(lst, c(start, start + 16), end,
                                     method = "period"),
               class = "earthflux_input_error")
})

# modis_to_grid() --------------------------------------------------------------

# SYNTHETIC 500 m layer (4 x 4) nested in a 1 km working grid (2 x 2).
fine_values <- c(0.10, 0.20, 0.30, NA,
                 0.30, NA,   0.50, NA,
                 NA,   NA,   0.40, 0.40,
                 NA,   0.80, 0.40, 0.40)
fine <- synthetic_raster(fine_values, 4, 4, cell = 500, ymin = -1000)
grid_1km <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2000,
                        ymin = -1000, ymax = 1000, crs = sinu_crs)

test_that("aggregation G1: mean of the valid sub-cells and valid fraction", {
  res <- modis_to_grid(fine, grid_1km, method = "mean",
                       min_valid_fraction = 0.75)
  expect_true(terra::compareGeom(res$value, grid_1km))
  # Blocks (row-major): {0.1, 0.2, 0.3, NA} -> 3/4 valid, mean 0.2;
  # {0.3, NA, 0.5, NA} -> 1/2; {NA, NA, NA, 0.8} -> 1/4; {0.4 x 4} -> 1.
  expect_equal(terra::values(res$valid_fraction, mat = FALSE),
               c(0.75, 0.5, 0.25, 1))
  expect_equal(terra::values(res$value, mat = FALSE), c(0.2, NA, NA, 0.4))
  expect_equal(as.logical(terra::values(res$incomplete, mat = FALSE)),
               c(FALSE, TRUE, TRUE, FALSE))
  # A lower threshold keeps the half-valid block.
  low <- modis_to_grid(fine, grid_1km, method = "mean",
                       min_valid_fraction = 0.5)
  expect_equal(terra::values(low$value, mat = FALSE), c(0.2, 0.4, NA, 0.4))
})

test_that("aggregation: median, modal (ties to smallest) and any", {
  med <- modis_to_grid(fine, grid_1km, method = "median",
                       min_valid_fraction = 0.25)
  expect_equal(terra::values(med$value, mat = FALSE), c(0.2, 0.4, 0.8, 0.4))
  classes <- synthetic_raster(c(1, 1, 5, 7,
                                2, 3, 7, 5,
                                4, 4, NA, NA,
                                4, 2, NA, NA), 4, 4, ymin = -1000)
  mod <- modis_to_grid(classes, grid_1km, method = "modal",
                       min_valid_fraction = 0.5)
  expect_equal(terra::values(mod$value, mat = FALSE), c(1, 5, 4, NA))
  expect_equal(terra::values(mod$valid_fraction, mat = FALSE),
               c(1, 1, 1, 0))
  # A block without valid sub-cells is NA but not "incomplete".
  expect_equal(as.logical(terra::values(mod$incomplete, mat = FALSE)),
               rep(FALSE, 4))
  flags <- synthetic_raster(c(0, 0, 0, 1,
                              0, 0, NA, 0,
                              1, 0, 0, 0,
                              0, 0, 0, 0), 4, 4, ymin = -1000)
  any_res <- modis_to_grid(flags, grid_1km, method = "any",
                           min_valid_fraction = 0.5)
  expect_equal(terra::values(any_res$value, mat = FALSE), c(0, 1, 1, 0))
  expect_error(modis_to_grid(classes, grid_1km, method = "any",
                             min_valid_fraction = 0.5),
               class = "earthflux_domain_error")
})

test_that("aggregation by factor 1 keeps values and reports 0/1 fraction", {
  res <- modis_to_grid(fine, fine, method = "mean", min_valid_fraction = 1)
  expect_equal(terra::values(res$value, mat = FALSE), fine_values)
  expect_equal(terra::values(res$valid_fraction, mat = FALSE),
               as.numeric(!is.na(fine_values)))
})

test_that("aggregation handles several layers", {
  two <- c(fine, fine * 2)
  names(two) <- c("a", "b")
  res <- modis_to_grid(two, grid_1km, method = "mean",
                       min_valid_fraction = 0.75)
  expect_equal(terra::nlyr(res$value), 2)
  expect_identical(names(res$value), c("a", "b"))
  expect_identical(names(res$valid_fraction),
                   c("a_valid_fraction", "b_valid_fraction"))
  expect_equal(terra::values(res$value)[, "b"], c(0.4, NA, NA, 0.8))
})

test_that("aggregation rejects misaligned grids and bad arguments", {
  expect_error(modis_to_grid(fine, grid_1km, min_valid_fraction = 0.5),
               class = "earthflux_missing_input")
  expect_error(modis_to_grid(fine, grid_1km, method = "mean"),
               class = "earthflux_missing_input")
  cnd <- expect_error(modis_to_grid(fine, grid_1km, method = "bilinear",
                                    min_valid_fraction = 0.5),
                      class = "earthflux_method_not_implemented")
  expect_identical(cnd$choices, c("mean", "median", "modal", "any"))
  expect_error(modis_to_grid(fine, grid_1km, method = "mean",
                             min_valid_fraction = 0),
               class = "earthflux_domain_error")
  expect_error(modis_to_grid(fine, grid_1km, method = "mean",
                             min_valid_fraction = 1.2),
               class = "earthflux_domain_error")
  expect_error(modis_to_grid(fine, grid_1km, method = "mean",
                             min_valid_fraction = c(0.5, 0.6)),
               class = "earthflux_input_error")
  shifted <- terra::rast(nrows = 2, ncols = 2, xmin = 250, xmax = 2250,
                         ymin = -1000, ymax = 1000, crs = sinu_crs)
  expect_error(modis_to_grid(fine, shifted, method = "mean",
                             min_valid_fraction = 0.5),
               class = "earthflux_input_error")
  odd <- terra::rast(nrows = 2, ncols = 3, xmin = 0, xmax = 2000,
                     ymin = -1000, ymax = 1000, crs = sinu_crs)
  expect_error(modis_to_grid(fine, odd, method = "mean",
                             min_valid_fraction = 0.5),
               class = "earthflux_input_error")
  geo <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2000,
                     ymin = -1000, ymax = 1000, crs = "EPSG:32719")
  expect_error(modis_to_grid(fine, geo, method = "mean",
                             min_valid_fraction = 0.5),
               class = "earthflux_input_error")
  expect_error(modis_to_grid(fine_values, grid_1km, method = "mean",
                             min_valid_fraction = 0.5),
               class = "earthflux_input_error")
})
