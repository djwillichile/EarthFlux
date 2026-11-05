# Tests for the MODIS product table, scaling and QA decoding
#
# Specification: dev/specs/modis-products.md sections 4, 5, 10, 11.3, 13
# and 14 (cases S1-S10, Q1-Q5); dev/specs/flags.md sections 4.2, 6.4, 7.
#
# All DN and QA values below are SYNTHETIC: they are built by hand from the
# product sheets (scale, offset, valid range, fill, bit layout) to exercise
# each documented case. No real MODIS value is used.

tol <- 1e-12 # arithmetic from VERIFICADA values, machine tolerance

row_of <- function(product, layer) modis_layer_spec(product, layer)

# Product table -----------------------------------------------------------------

test_that("the product table covers the verified products of collection 6.1", {
  tab <- modis_product_table()
  expect_setequal(
    unique(tab$product),
    c("MOD11A1", "MYD11A1", "MOD21A1D", "MYD21A1D", "MOD09GA", "MOD09GQ",
      "MOD13Q1", "MOD13A2", "MCD43A3", "MCD43A2", "MCD15A2H", "MCD12Q1")
  )
  expect_identical(unique(tab$collection), "061")
  expect_true(all(tab$status == "VERIFICADA"))
  expect_true(all(nzchar(tab$source)))
  expect_true(all(grepl("^D[0-9]+", tab$source)))
  expect_identical(anyDuplicated(paste(tab$product, tab$layer)), 0L)
  expect_true(all(tab$conversion %in%
                    c("scale_offset", "offset_scale", "scale_only", "none")))
  expect_true(all(is.na(tab$scale) == (tab$conversion == "none")))
  qa <- tab$kind %in% c("qa_bits", "qa_code")
  expect_true(all(!is.na(tab$qa_table[qa])))
  expect_true(all(tab$qa_table[qa] %in% names(modis_qa_layouts())))
  expect_true(all(names(modis_qa_layouts()) %in% names(modis_qa_rules())))
})

test_that("modis_product_spec() returns one sheet and refuses unverified ones", {
  spec <- modis_product_spec("MOD11A1")
  expect_true(all(spec$product == "MOD11A1"))
  expect_true(all(c("LST_Day_1km", "QC_Day", "Day_view_time",
                    "Day_view_angl", "Emis_31", "Emis_32") %in% spec$layer))
  err <- "earthflux_modis_unsupported"
  expect_error(modis_product_spec("MOD11A1", "006"), class = err)
  expect_error(modis_product_spec("MOD11A1", "070"), class = err)
  expect_error(modis_product_spec("VNP21A1D"), class = err)
  expect_error(modis_product_spec("MOD11A1", "006"),
               class = "earthflux_input_error")
  # TODO facts are not implemented: night layers, Fpar, LAI std. dev.
  expect_error(modis_layer_spec("MOD11A1", "LST_Night_1km"), class = err)
  expect_error(modis_layer_spec("MCD15A2H", "Fpar_500m"), class = err)
  expect_error(modis_layer_spec("MCD15A2H", "LaiStdDev_500m"), class = err)
  expect_error(modis_layer_spec("MOD11A1", "Emis_29"), class = err)
})

test_that("rows carry the verified facts of the sheets", {
  r <- row_of("MOD11A1", "LST_Day_1km")
  expect_identical(r$grid, "MODIS_Grid_Daily_1km_LST")
  expect_identical(c(r$scale, r$offset, r$valid_min, r$valid_max, r$fill),
                   c(0.02, 0, 7500, 65535, 0))
  expect_identical(r$conversion, "scale_offset")
  expect_identical(row_of("MOD21A1D", "LST_1KM")$grid,
                   "MODIS_Grid_Daily_1km_LST21")
  a <- row_of("MCD43A3", "Albedo_WSA_shortwave")
  expect_identical(a$conversion, "offset_scale")
  expect_identical(a$grid, "MOD_Grid_BRDF")
  expect_identical(c(a$scale, a$valid_max, a$fill), c(0.001, 32766, 32767))
  q <- row_of("MOD09GA", "QC_500m_1")
  expect_identical(q$data_type, "uint32")
  expect_identical(q$fill, 787410671)
  expect_true(is.na(q$valid_min) && is.na(q$valid_max)) # d6b
  expect_true(is.na(row_of("MOD09GA", "state_1km_1")$valid_max)) # d6
  expect_identical(row_of("MOD13A2", "1 km 16 days NDVI")$sds_alternatives,
                   "1km 16 days NDVI")
  lai <- row_of("MCD15A2H", "Lai_500m")
  expect_identical(c(lai$special_min, lai$special_max), c(249, 254))
  expect_identical(lai$special_flag, "EF_SURF_LAI_NONVEG")
  expect_true(is.na(row_of("MOD09GQ", "sur_refl_b01_1")$cells_per_tile))
})

test_that("DERIVADA physical ranges follow from the verified values", {
  phys <- function(p, l) {
    r <- row_of(p, l)
    c(r$physical_min, r$physical_max)
  }
  expect_equal(phys("MOD11A1", "LST_Day_1km"), c(150, 1310.70), tolerance = tol)
  expect_equal(phys("MOD21A1D", "LST_1KM"), c(150, 1310.70), tolerance = tol)
  expect_equal(phys("MOD11A1", "Emis_31"), c(0.492, 1.000), tolerance = tol)
  expect_equal(phys("MOD11A1", "Day_view_angl"), c(-65, 65), tolerance = tol)
  expect_equal(phys("MOD11A1", "Day_view_time"), c(0, 24), tolerance = tol)
  expect_equal(phys("MOD13Q1", "250m 16 days NDVI"), c(-0.2, 1.0),
               tolerance = tol)
  expect_equal(phys("MCD15A2H", "Lai_500m"), c(0, 10), tolerance = tol)
  expect_equal(phys("MCD43A3", "Albedo_BSA_shortwave"), c(0, 32.766),
               tolerance = tol)
})

test_that("the sinusoidal grid constants and tile extents are consistent", {
  g <- modis_sinusoidal_grid()
  expect_identical(g$cell_500m, 463.312716525)
  expect_equal(g$cell_1km, 926.62543305, tolerance = tol)
  expect_equal(g$tile_size / 1200, g$cell_1km, tolerance = tol)
  expect_equal(-2 * g$ulx, g$n_h * g$tile_size, tolerance = 1e-9)
  expect_equal(2 * g$uly, g$n_v * g$tile_size, tolerance = 1e-9)
  e <- as.vector(modis_tile_extent(0, 0))
  expect_equal(e[c("xmin", "ymax")], c(xmin = g$ulx, ymax = g$uly),
               tolerance = tol)
  e <- as.vector(modis_tile_extent(12, 12))
  expect_equal(e[["xmin"]], g$ulx + 12 * g$tile_size, tolerance = tol)
  expect_equal(e[["ymin"]], g$uly - 13 * g$tile_size, tolerance = tol)
  expect_error(modis_tile_extent(36, 0), class = "earthflux_domain_error")
})

# File names ----------------------------------------------------------------------

test_that("modis_parse_filename() follows the MODIS naming convention", {
  info <- modis_parse_filename(
    "/data/MOD11A1.A2019032.h12v12.061.2019034041122.hdf"
  )
  expect_identical(info$product, "MOD11A1")
  expect_identical(info$date, as.Date("2019-02-01"))
  expect_identical(c(info$year, info$doy, info$h, info$v),
                   c(2019L, 32L, 12L, 12L))
  expect_identical(info$tile, "h12v12")
  expect_identical(info$collection, "061")
  expect_identical(info$production,
                   as.POSIXct("2019-02-03 04:11:22", tz = "UTC"))
  expect_identical(modis_parse_filename(
    "MCD12Q1.A2020001.h12v12.061.2022169130310.hdf")$date,
    as.Date("2020-01-01"))
  expect_identical(modis_parse_filename(
    "MOD13A2.A2020366.h12v12.061.2021010101010.hdf")$date,
    as.Date("2020-12-31"))
  err <- "earthflux_modis_filename_error"
  expect_error(modis_parse_filename("MOD11A1.A2019032.h12v12.061.tif"),
               class = err)
  expect_error(modis_parse_filename(
    "MOD11A1.A2019366.h12v12.061.2019034041122.hdf"), class = err)
  expect_error(modis_parse_filename(
    "MOD11A1.A2019032.h36v12.061.2019034041122.hdf"), class = err)
  expect_error(modis_parse_filename(
    "MOD11A1.A2019032.h12v18.061.2019034041122.hdf"), class = err)
})

# Scaling (S1-S10) -------------------------------------------------------------------

test_that("S1-S3: LST DN is scaled with 0.02 and fill is NA with a mask", {
  r <- row_of("MOD11A1", "LST_Day_1km")
  s <- modis_apply_scale(c(15000, 7500, 65535, 0), r)
  expect_equal(s$value, c(300.00, 150.00, 1310.70, NA), tolerance = tol)
  expect_identical(s$fill, c(FALSE, FALSE, FALSE, TRUE))
  expect_identical(s$out_of_range, rep(FALSE, 4))
  # MOD21A1D LST_1KM, same scale
  s21 <- modis_apply_scale(c(15000, 0), row_of("MOD21A1D", "LST_1KM"))
  expect_equal(s21$value, c(300, NA), tolerance = tol)
})

test_that("DN outside the valid range and not fill are NA with their mask", {
  s <- modis_apply_scale(c(7499, 1, 7500), row_of("MOD11A1", "LST_Day_1km"))
  expect_identical(s$value[1:2], c(NA_real_, NA_real_))
  expect_identical(s$out_of_range, c(TRUE, TRUE, FALSE))
  expect_identical(s$fill, rep(FALSE, 3))
})

test_that("S4: band emissivity uses DN * 0.002 + 0.49", {
  s <- modis_apply_scale(c(255, 1, 0), row_of("MOD11A1", "Emis_31"))
  expect_equal(s$value, c(1.000, 0.492, NA), tolerance = tol)
  expect_identical(s$fill, c(FALSE, FALSE, TRUE))
  e <- modis_band_emissivity(c(255, 1, 0), "MOD21A1D", "29")
  expect_equal(e$value, c(1.000, 0.492, NA), tolerance = tol)
  expect_error(modis_band_emissivity(255, "MOD11A1", "29"),
               class = "earthflux_modis_unsupported")
  expect_error(modis_band_emissivity(255, "MOD11A1", "30"),
               class = "earthflux_unknown_method")
})

test_that("S5: view angle uses DN * 1 - 65 (signed)", {
  s <- modis_apply_scale(c(0, 65, 130, 255),
                         row_of("MOD11A1", "Day_view_angl"))
  expect_equal(s$value, c(-65, 0, 65, NA), tolerance = tol)
  v <- modis_view_zenith(c(0, 65, 130, 255), "MOD11A1")
  expect_equal(v$value, c(-65, 0, 65, NA), tolerance = tol)
  expect_identical(v$unit, "degree")
  v21 <- modis_view_zenith(c(0, 255), "MYD21A1D")
  expect_identical(v21$layer, "View_Angle")
  expect_equal(v21$value, c(-65, NA), tolerance = tol)
  expect_true(v21$masks$EF_SURF_FILL[2])
})

test_that("S6: view time uses DN * 0.1 h", {
  s <- modis_apply_scale(c(106, 255, 240, 241),
                         row_of("MOD11A1", "Day_view_time"))
  expect_equal(s$value, c(10.6, NA, 24.0, NA), tolerance = tol)
  expect_identical(s$fill, c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(s$out_of_range, c(FALSE, FALSE, FALSE, TRUE))
})

test_that("S7: NDVI of MOD13 uses DN * 0.0001 with fill -3000", {
  for (p in c("MOD13Q1", "MOD13A2")) {
    layer <- if (p == "MOD13Q1") "250m 16 days NDVI" else "1 km 16 days NDVI"
    s <- modis_apply_scale(c(-3000, -2000, 10000, -2001), row_of(p, layer))
    expect_equal(s$value, c(NA, -0.2, 1.0, NA), tolerance = tol)
    expect_identical(s$fill, c(TRUE, FALSE, FALSE, FALSE))
    expect_identical(s$out_of_range, c(FALSE, FALSE, FALSE, TRUE))
  }
})

test_that("S8: LAI uses DN * 0.1; classes 249-254 are NA, kept and flagged", {
  l <- modis_lai(c(35, 253, 249, 254, 255, 100, 101), rep(0, 7), NULL,
                 qa_policy = "flag")
  expect_equal(l$value, c(3.5, NA, NA, NA, NA, 10, NA), tolerance = tol)
  expect_identical(l$class, c(NA, 253L, 249L, 254L, NA, NA, NA))
  expect_identical(l$class_labels[["253"]],
                   "barren or sparse vegetation (rock, tundra, desert)")
  expect_identical(l$masks$EF_SURF_LAI_NONVEG,
                   c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_identical(l$masks$EF_SURF_FILL,
                   c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_identical(l$masks$EF_SURF_DN_OUT_OF_RANGE,
                   c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
  codes <- vapply(l$flags, `[[`, character(1), "code")
  expect_true(all(c("EF_SURF_LAI_NONVEG", "EF_SURF_FILL",
                    "EF_SURF_DN_OUT_OF_RANGE") %in% codes))
  nonveg <- l$flags[[match("EF_SURF_LAI_NONVEG", codes)]]
  expect_identical(nonveg$index, 2:4)
  expect_identical(nonveg$severity, "info")
})

test_that("lai_nonveg is checked: NULL, one number or a value per class", {
  expect_null(check_lai_nonveg(NULL))
  all6 <- check_lai_nonveg(0)
  expect_identical(all6, stats::setNames(rep(0, 6), as.character(249:254)))
  expect_identical(check_lai_nonveg(c("253" = 0.1, "250" = 0)),
                   c("250" = 0, "253" = 0.1))
  err <- "earthflux_input_error"
  expect_error(check_lai_nonveg(c(0, 1)), class = err)
  expect_error(check_lai_nonveg(c("248" = 0)), class = err)
  expect_error(check_lai_nonveg(c("253" = 0, "253" = 1)), class = err)
  expect_error(check_lai_nonveg(NA_real_), class = err)
  expect_error(check_lai_nonveg("0"), class = err)
  expect_error(check_lai_nonveg(numeric(0)), class = err)
  # physical range of Lai_500m (product table, DERIVADA): 0-10 m2 m-2
  expect_error(check_lai_nonveg(-0.1), class = "earthflux_domain_error")
  expect_error(check_lai_nonveg(c("253" = 10.5)),
               class = "earthflux_domain_error")
})

test_that("lai_nonveg assigns the non-vegetated classes with their own flag", {
  dn <- c(35, 253, 249, 254, 255, 100, 101)
  # positive: one value for every class; the classes are kept
  l <- modis_lai(dn, rep(0, 7), NULL, qa_policy = "flag", lai_nonveg = 0)
  expect_equal(l$value, c(3.5, 0, 0, 0, NA, 10, NA), tolerance = tol)
  expect_identical(l$class, c(NA, 253L, 249L, 254L, NA, NA, NA))
  expect_identical(l$masks$EF_SURF_LAI_ASSIGNED,
                   c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
  # EF_SURF_LAI_NONVEG keeps its meaning (LAI is NA): not raised where
  # the LAI was assigned
  expect_false(any(l$masks$EF_SURF_LAI_NONVEG))
  expect_identical(l$na, c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE))
  codes <- vapply(l$flags, `[[`, character(1), "code")
  rec <- l$flags[[match("EF_SURF_LAI_ASSIGNED", codes)]]
  expect_identical(rec$index, 2:4)
  expect_identical(rec$severity, "info")
  expect_identical(l$lai_nonveg[["253"]], 0)
  # per class: only the named classes are assigned, the others stay NA
  p <- modis_lai(dn, rep(0, 7), NULL, qa_policy = "flag",
                 lai_nonveg = c("253" = 0.2))
  expect_equal(p$value, c(3.5, 0.2, NA, NA, NA, 10, NA), tolerance = tol)
  expect_identical(which(p$masks$EF_SURF_LAI_ASSIGNED), 2L)
  expect_identical(which(p$masks$EF_SURF_LAI_NONVEG), 3:4)
  # negative: without the option nothing is assigned and the code is not
  # evaluated
  n <- modis_lai(dn, rep(0, 7), NULL, qa_policy = "flag")
  expect_null(n$masks$EF_SURF_LAI_ASSIGNED)
  expect_null(n$lai_nonveg)
  expect_false("EF_SURF_LAI_ASSIGNED" %in% ef_flags_evaluated(n$flags))
  expect_true("EF_SURF_LAI_ASSIGNED" %in% ef_flags_evaluated(l$flags))
  # the flag word uses bit 15 of the registry
  w <- modis_flag_word(l$masks)
  expect_identical(w[2], as.integer(2^15))
})

test_that("lai_nonveg: QA of the absent retrieval and masked codes", {
  # synthetic QA: SCF_QC 100 (not produced, DN 128) in a class cell and in
  # a vegetated cell; FparExtra_QC land/sea 10 (inland water, DN 2) in a
  # class cell
  dn <- c(253, 35, 254, 253)
  qc <- c(128, 128, 0, 0)
  ex <- c(0, 0, 2, 0)
  l <- modis_lai(dn, qc, ex, qa_policy = "flag", lai_nonveg = 0)
  # the class code, not a retrieval, is the source of the assigned LAI: the
  # cause of NA of the absent retrieval is not raised there (M4-21)
  expect_equal(l$value, c(0, NA, 0, 0))
  expect_identical(l$masks$EF_SURF_NOT_PRODUCED, c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(l$masks$EF_SURF_WATER, c(FALSE, FALSE, TRUE, FALSE))
  expect_identical(which(l$masks$EF_SURF_LAI_ASSIGNED), c(1L, 3L, 4L))
  # a code masked by the user wins over the assignment and is counted
  m <- modis_lai(dn, qc, ex, qa_policy = "mask", mask_codes = "EF_SURF_WATER",
                 lai_nonveg = 0)
  expect_equal(m$value, c(0, NA, NA, 0))
  expect_identical(which(m$masks$EF_SURF_LAI_ASSIGNED), c(1L, 4L))
  expect_identical(which(m$masks$EF_SURF_LAI_NONVEG), 3L)
  expect_identical(m$policy$n_masked, c(EF_SURF_WATER = 1L))
  u <- modis_lai(dn, qc, ex, qa_policy = "mask", mask_codes = "EF_SURF_WATER")
  expect_identical(u$policy$n_masked, c(EF_SURF_WATER = 0L))
})

test_that("S9: albedo uses (DN - 0) * 0.001; values above 1 are kept", {
  s <- modis_apply_scale(c(180, 32767, 1500, 32766),
                         row_of("MCD43A3", "Albedo_WSA_shortwave"))
  expect_equal(s$value, c(0.180, NA, 1.5, 32.766), tolerance = tol)
  expect_identical(s$fill, c(FALSE, TRUE, FALSE, FALSE))
})

test_that("S10: surface reflectance fill -28672 is NA", {
  s <- modis_apply_scale(c(-28672, -100, 16000, 500, -101),
                         row_of("MOD09GA", "sur_refl_b01_1"))
  expect_equal(s$value, c(NA, -0.01, 1.6, 0.05, NA), tolerance = tol)
  expect_identical(s$fill, c(TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_identical(s$out_of_range, c(FALSE, FALSE, FALSE, FALSE, TRUE))
  g <- modis_apply_scale(-28672, row_of("MOD09GQ", "sur_refl_b02_1"))
  expect_true(g$fill)
})

test_that("modis_apply_scale() keeps dim, propagates NA and checks DN", {
  r <- row_of("MOD11A1", "LST_Day_1km")
  dn <- matrix(c(15000, NA, 0, 7500), 2, 2)
  s <- modis_apply_scale(dn, r)
  expect_identical(dim(s$value), c(2L, 2L))
  expect_true(is.na(s$value[1, 2]))
  expect_identical(s$fill, c(FALSE, FALSE, TRUE, FALSE))
  expect_identical(s$out_of_range, rep(FALSE, 4))
  # integer storage gives the same result
  expect_identical(modis_apply_scale(c(15000L, 0L), r)$value,
                   modis_apply_scale(c(15000, 0), r)$value)
  # MP-11: values that are not raw DN of the data type are refused
  err <- "earthflux_modis_dn_error"
  expect_error(modis_apply_scale(300.02, r), class = err)
  expect_error(modis_apply_scale(-1, r), class = err)
  expect_error(modis_apply_scale(70000, r), class = err)
  expect_error(modis_apply_scale("15000", r), class = "earthflux_input_error")
  expect_error(modis_apply_scale(15000, modis_product_spec("MOD11A1")),
               class = "earthflux_input_error")
})

test_that("vector and SpatRaster inputs give the same result", {
  dn <- c(15000, 0, 7600, 14000, 65535, 7499)
  qc <- c(0, 2, 1, 81, 0, 3)
  r_dn <- terra::rast(nrows = 2, ncols = 3, vals = dn)
  r_qc <- terra::rast(nrows = 2, ncols = 3, vals = qc)
  a <- modis_lst(dn, qc, "MOD11A1", qa_policy = "flag")
  b <- modis_lst(r_dn, r_qc, "MOD11A1", qa_policy = "flag")
  expect_identical(b$value, a$value)
  expect_identical(b$masks, a$masks)
  back <- modis_as_raster(b$value, r_dn, "lst")
  expect_identical(terra::values(back, mat = FALSE), a$value)
  expect_identical(names(back), "lst")
  expect_error(modis_values(c(r_dn, r_qc)), class = "earthflux_input_error")
})

# QA decoding (Q1-Q5) ------------------------------------------------------------------

test_that("modis_qa_field() extracts bit fields with bit 0 least significant", {
  expect_identical(modis_qa_field(81, 0, 2), 1L)
  expect_identical(modis_qa_field(81, 4, 2), 1L)
  expect_identical(modis_qa_field(81, 6, 2), 1L)
  expect_identical(modis_qa_field(81, 2, 2), 0L)
  expect_identical(modis_qa_field(c(0, 255, NA), 0, 8), c(0L, 255L, NA))
  m <- matrix(c(1, 2, 3, 4), 2, 2)
  expect_identical(dim(modis_qa_field(m, 0, 1)), c(2L, 2L))
  # uint32 values above 2^31 without overflow
  expect_identical(modis_qa_field(4294967295, 31, 1), 1L)
  expect_identical(modis_qa_field(4294967295, 1, 31), 2147483647L)
  err <- "earthflux_input_error"
  expect_error(modis_qa_field(-1, 0, 1), class = err)
  expect_error(modis_qa_field(1.5, 0, 1), class = err)
  expect_error(modis_qa_field(2^32, 0, 1), class = err)
  expect_error(modis_qa_field(1, 32, 1), class = "earthflux_domain_error")
  expect_error(modis_qa_field(1, 30, 3), class = "earthflux_domain_error")
  expect_error(modis_qa_field(1, 0, 32), class = "earthflux_domain_error")
})

test_that("Q1-Q2: QC_Day decodes MODLAND and the error categories", {
  d <- modis_qa_decode(c(0, 81), "MOD11A1", "QC_Day")
  expect_named(d, c("mandatory", "emis_error", "lst_error", "fill"))
  expect_identical(d$mandatory, c(0L, 1L))
  expect_identical(d$emis_error, c(0L, 1L))
  expect_identical(d$lst_error, c(0L, 1L))
  expect_identical(d$fill, c(FALSE, FALSE)) # QC_Day has no fill value
  # bits 3-2 (discrepancy d2) are not decoded
  expect_false("data_quality" %in% names(d))
  expect_identical(attr(d, "qa_table"), "MOD11_QC")
  expect_error(modis_qa_decode(1, "MOD11A1", "LST_Day_1km"),
               class = "earthflux_input_error")
  expect_error(modis_qa_decode(256, "MOD11A1", "QC_Day"),
               class = "earthflux_modis_dn_error")
})

test_that("Q3: MOD21 QC = 2 is MODLAND 10 (cloud)", {
  d <- modis_qa_decode(c(2, 0, 1, 3), "MOD21A1D", "QC")
  expect_identical(d$mandatory, c(2L, 0L, 1L, 3L))
  m <- modis_qa_masks(d)
  expect_identical(m$EF_SURF_CLOUD, c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(m$EF_SURF_QA_OTHER, c(FALSE, FALSE, TRUE, FALSE))
  expect_identical(m$EF_SURF_NOT_PRODUCED, c(FALSE, FALSE, FALSE, TRUE))
  # cloud bits 5-4: 01 thin cirrus and 10 near cloud -> adjacent; 11 is not
  d2 <- modis_qa_decode(c(0, 16, 32, 48), "MOD21A1D", "QC")
  expect_identical(d2$cloud, 0:3)
  expect_identical(modis_qa_masks(d2)$EF_SURF_CLOUD_ADJACENT,
                   c(FALSE, TRUE, TRUE, FALSE))
  # all 16 bits of a uint16 QA
  d3 <- modis_qa_decode(65535, "MOD21A1D", "QC")
  expect_true(all(unlist(d3[setdiff(names(d3), "fill")]) == 3L))
})

test_that("Q4: the QC_500m_1 fill is recognised without uint32 overflow", {
  d <- modis_qa_decode(c(787410671, 4294966019, 0), "MOD09GA", "QC_500m_1")
  expect_identical(d$fill, c(TRUE, FALSE, FALSE))
  expect_true(all(is.na(unlist(d[1L, setdiff(names(d), "fill")]))))
  # 4294966019 = 0xFFFFFB03 (synthetic): bits 31, 30 set, MODLAND 11
  expect_identical(d$modland[2:3], c(3L, 0L))
  expect_identical(d$atmospheric_correction[2:3], c(1L, 0L))
  expect_identical(d$adjacency_correction[2:3], c(1L, 0L))
  expect_identical(d$band1_quality[2], 0L) # bits 5-2 of 0x03 = 0000
  expect_identical(d$band2_quality[2], 12L) # bits 9-6 of 0xB03 = 1100
  # bitwAnd() cross-check for a value below 2^31
  x <- 787410670
  expect_identical(modis_qa_field(x, 2, 4), bitwAnd(bitwShiftR(x, 2L), 15L))
})

test_that("Q5: FparLai_QC = 64 is SCF_QC 010 (backup method)", {
  d <- modis_qa_decode(c(64, 0, 96, 128, 1, 255), "MCD15A2H", "FparLai_QC")
  expect_identical(d$scf_qc, c(2L, 0L, 3L, 4L, 0L, NA))
  expect_identical(d$fill, c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
  m <- modis_qa_masks(d)
  expect_identical(m$EF_SURF_LAI_BACKUP,
                   c(TRUE, FALSE, TRUE, FALSE, FALSE, FALSE))
  expect_identical(m$EF_SURF_NOT_PRODUCED,
                   c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_identical(m$EF_SURF_QA_OTHER,
                   c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE))
})

test_that("MODLAND 00/01/10/11 map to none/QA_OTHER/CLOUD/NOT_PRODUCED", {
  for (key in list(c("MOD09GA", "QC_500m_1"), c("MOD09GQ", "QC_250m_1"),
                   c("MOD13A2", "1 km 16 days VI Quality"),
                   c("MOD11A1", "QC_Day"))) {
    m <- modis_qa_masks(modis_qa_decode(0:3, key[1], key[2]))
    expect_identical(m$EF_SURF_QA_OTHER, c(FALSE, TRUE, FALSE, FALSE))
    expect_identical(m$EF_SURF_CLOUD, c(FALSE, FALSE, TRUE, FALSE))
    expect_identical(m$EF_SURF_NOT_PRODUCED, c(FALSE, FALSE, FALSE, TRUE))
  }
})

test_that("MOD09 state bits raise adjacent cloud, snow, water and salt pan", {
  land <- 8 # land/water 001 in bits 5-3
  qa <- c(land, land + 2^13, land + 2^8, land + 3 * 2^8, land + 2^12,
          land + 2^15, 0, 5 * 8, land + 2^14, land + 1 + 2^2 + 2^10)
  d <- modis_qa_decode(qa, "MOD09GA", "state_1km_1")
  expect_identical(d$land_water, c(1L, 1L, 1L, 1L, 1L, 1L, 0L, 5L, 1L, 1L))
  expect_identical(d$cirrus[3:4], c(1L, 3L))
  m <- modis_qa_masks(d)
  expect_named(m, c("EF_SURF_CLOUD_ADJACENT", "EF_SURF_SNOW",
                    "EF_SURF_WATER", "EF_SURF_SALT_PAN"))
  expect_identical(which(m$EF_SURF_CLOUD_ADJACENT), 2:4)
  expect_identical(which(m$EF_SURF_SNOW), 5:6)
  expect_identical(which(m$EF_SURF_WATER), 7:8)
  expect_identical(which(m$EF_SURF_SALT_PAN), 9L)
  # cloud state, shadow and internal cloud raise no code (not in 10.2)
  expect_identical(d$cloud_state[10], 1L)
  expect_false(any(vapply(m, `[`, logical(1), 10L)))
  # the fill value of state_1km_1 is recognised
  expect_true(modis_qa_decode(65535, "MOD09GA", "state_1km_1")$fill)
})

test_that("MOD13 VI Quality bits and reliability codes are decoded", {
  land <- 2^11 # land/water 001 in bits 13-11
  d <- modis_qa_decode(c(land, land + 2^8, land + 2^14, 0, 65535),
                       "MOD13Q1", "250m 16 days VI Quality")
  m <- modis_qa_masks(d)
  expect_identical(m$EF_SURF_CLOUD_ADJACENT, c(FALSE, TRUE, FALSE, FALSE,
                                               FALSE))
  expect_identical(m$EF_SURF_SNOW, c(FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_identical(m$EF_SURF_WATER, c(FALSE, FALSE, FALSE, TRUE, FALSE))
  expect_identical(d$fill, c(FALSE, FALSE, FALSE, FALSE, TRUE))
  r <- modis_qa_decode(c(-1, 0, 1, 2, 3), "MOD13A2",
                       "1 km 16 days pixel reliability")
  expect_identical(r$code, c(NA, 0L, 1L, 2L, 3L))
  expect_identical(r$fill, c(TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_length(modis_qa_masks(r), 0L)
})

test_that("MCD15 extra QC, MCD43 mandatory quality and MCD43A2 snow", {
  e <- modis_qa_decode(c(0, 1, 2, 3, 4, 255), "MCD15A2H", "FparExtra_QC")
  m <- modis_qa_masks(e)
  expect_identical(m$EF_SURF_WATER, c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_identical(m$EF_SURF_SNOW, c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE))
  a <- modis_qa_decode(c(0:7, 255), "MCD43A3",
                       "BRDF_Albedo_Band_Mandatory_Quality_shortwave")
  expect_identical(modis_qa_masks(a)$EF_SURF_ALBEDO_MAGNITUDE,
                   c(FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE,
                     FALSE))
  expect_identical(a$fill, c(rep(FALSE, 8), TRUE))
  s <- modis_qa_decode(c(0, 1, 255), "MCD43A2", "Snow_BRDF_Albedo")
  expect_identical(modis_qa_masks(s)$EF_SURF_SNOW, c(FALSE, TRUE, FALSE))
})

# Flags and QA policy -------------------------------------------------------------------

test_that("the surface stage registers its codes with the bits of 6.4", {
  reg <- ef_flag_registry_build()
  surf <- reg[reg$stage == "SURF", ]
  expect_identical(
    stats::setNames(surf$bit, surf$code),
    c(EF_SURF_FILL = 1L, EF_SURF_CLOUD = 2L, EF_SURF_NOT_PRODUCED = 3L,
      EF_SURF_DN_OUT_OF_RANGE = 4L, EF_SURF_LAI_NONVEG = 5L,
      EF_SURF_QA_OTHER = 6L, EF_SURF_CLOUD_ADJACENT = 7L, EF_SURF_SNOW = 8L,
      EF_SURF_WATER = 9L, EF_SURF_SALT_PAN = 10L, EF_SURF_LAI_BACKUP = 11L,
      EF_SURF_ALBEDO_MAGNITUDE = 12L, EF_SURF_OVERPASS_MISSING = 13L,
      EF_SURF_ALBEDO_GT1 = 14L, EF_SURF_LAI_ASSIGNED = 15L)
  )
  expect_true(all(surf$scope == "cell"))
  expect_identical(surf$severity,
                   c(rep("info", 5), rep("warning", 8), "critical", "info"))
  expect_true(all(modis_na_codes() %in% surf$code[surf$severity == "info"]))
  expect_true(all(modis_maskable_codes() %in%
                    surf$code[surf$severity == "warning"]))
  # bit 14 (albedo > 1) is class III: critical with its error counterpart;
  # it is never maskable by the QA policy (the core excludes it)
  expect_identical(surf$error_class[surf$code == "EF_SURF_ALBEDO_GT1"],
                   "earthflux_domain_error")
  expect_true(all(is.na(surf$error_class[surf$code != "EF_SURF_ALBEDO_GT1"])))
  expect_false(any(c("EF_SURF_OVERPASS_MISSING", "EF_SURF_ALBEDO_GT1",
                     "EF_SURF_LAI_ASSIGNED") %in% modis_maskable_codes()))
  # the assigned LAI is a kept value, never a cause of NA
  expect_false("EF_SURF_LAI_ASSIGNED" %in% modis_na_codes())
  # every code that a QA rule raises is registered
  rule_codes <- unique(unlist(lapply(modis_qa_rules(), function(rs) {
    vapply(rs, `[[`, character(1), "code")
  })))
  expect_true(all(rule_codes %in% surf$code))
})

test_that("modis_lst() keeps values under 'flag' and NA only documented causes", {
  # synthetic: good, fill+cloud, other quality, not produced, out of range
  lst <- c(15000, 0, 14000, 0, 7000, NA)
  qc <- c(0, 2, 1, 3, 0, 0)
  x <- modis_lst(lst, qc, "MOD11A1", qa_policy = "flag")
  expect_equal(x$value, c(300, NA, 280, NA, NA, NA), tolerance = tol)
  expect_identical(x$unit, "K")
  expect_identical(x$na, c(FALSE, TRUE, FALSE, TRUE, TRUE, FALSE))
  expect_identical(which(x$masks$EF_INPUT_NA), 6L)
  expect_identical(which(x$masks$EF_SURF_FILL), c(2L, 4L))
  expect_identical(which(x$masks$EF_SURF_CLOUD), 2L)
  expect_identical(which(x$masks$EF_SURF_NOT_PRODUCED), 4L)
  expect_identical(which(x$masks$EF_SURF_DN_OUT_OF_RANGE), 5L)
  expect_identical(which(x$masks$EF_SURF_QA_OTHER), 3L)
  expect_identical(
    ef_flags_evaluated(x$flags),
    c("EF_INPUT_NA", "EF_SURF_FILL", "EF_SURF_CLOUD", "EF_SURF_NOT_PRODUCED",
      "EF_SURF_DN_OUT_OF_RANGE", "EF_SURF_QA_OTHER")
  )
  expect_true(all(vapply(x$flags, inherits, logical(1), "earthflux_flag")))
  expect_true(all(vapply(x$flags, `[[`, character(1), "scope") == "cell"))
  expect_identical(x$policy$qa_policy, "flag")
  expect_identical(x$source$layer, c("LST_Day_1km", "QC_Day"))
  # negative case: all good
  ok <- modis_lst(c(15000, 15500), c(0, 0), "MOD11A1", qa_policy = "flag")
  expect_length(ok$flags, 0L)
  expect_identical(length(ef_flags_evaluated(ok$flags)), 6L)
  # MOD21A1D: same engine, other layers
  y <- modis_lst(c(15000, 15000), c(2, 16), "MOD21A1D", qa_policy = "flag")
  expect_equal(y$value, c(NA, 300), tolerance = tol)
  expect_identical(which(y$masks$EF_SURF_CLOUD_ADJACENT), 2L)
})

test_that("qa_policy 'mask' sets the listed codes to NA and counts them", {
  lst <- c(15000, 14000, 0, 14500)
  qc <- c(0, 1, 3, 1)
  x <- modis_lst(lst, qc, "MOD11A1", qa_policy = "mask",
                 mask_codes = "EF_SURF_QA_OTHER")
  expect_equal(x$value, c(300, NA, NA, NA), tolerance = tol)
  expect_identical(x$policy$n_masked, c(EF_SURF_QA_OTHER = 2L))
  # the flag of the masked condition is kept
  codes <- vapply(x$flags, `[[`, character(1), "code")
  expect_true("EF_SURF_QA_OTHER" %in% codes)
  # a listed code that does not occur masks nothing
  z <- modis_lst(lst, qc, "MOD11A1", qa_policy = "mask",
                 mask_codes = "EF_SURF_SNOW")
  expect_identical(z$value, modis_lst(lst, qc, "MOD11A1", "flag")$value)
  expect_identical(z$policy$n_masked, c(EF_SURF_SNOW = 0L))
})

test_that("the QA policy has no default and is checked", {
  expect_error(modis_lst(15000, 0, "MOD11A1"),
               class = "earthflux_missing_input")
  expect_error(modis_lst(15000, 0, "MOD11A1", qa_policy = "anchors"),
               class = "earthflux_unknown_method")
  expect_error(modis_lst(15000, 0, "MOD11A1", qa_policy = "flag",
                         mask_codes = "EF_SURF_QA_OTHER"),
               class = "earthflux_input_error")
  expect_error(modis_lst(15000, 0, "MOD11A1", qa_policy = "mask"),
               class = "earthflux_input_error")
  expect_error(modis_lst(15000, 0, "MOD11A1", qa_policy = "mask",
                         mask_codes = "EF_SURF_FILL"),
               class = "earthflux_input_error")
  expect_error(modis_lst(15000, 0, "MOD13A2", qa_policy = "flag"),
               class = "earthflux_unknown_method")
  expect_error(modis_lst(15000, 0, qa_policy = "flag"),
               class = "earthflux_missing_input")
  d <- modis_qa_decode(1, "MOD11A1", "QC_Day")
  expect_error(modis_qa_flags(d), class = "earthflux_missing_input")
  f <- modis_qa_flags(d, "flag")
  expect_identical(f$na, FALSE)
  expect_identical(f$masks$EF_SURF_QA_OTHER, TRUE)
  expect_identical(f$flags[[1]]$code, "EF_SURF_QA_OTHER")
  g <- modis_qa_flags(d, "mask", "EF_SURF_QA_OTHER")
  expect_identical(g$na, TRUE)
  expect_identical(g$n_masked, c(EF_SURF_QA_OTHER = 1L))
})

test_that("modis_variable() checks the QA layers it receives", {
  expect_error(modis_variable(15000, "MOD11A1", "LST_Day_1km",
                              list(QC_Day = c(0, 0)), "flag"),
               class = "earthflux_input_error")
  expect_error(modis_variable(15000, "MOD11A1", "LST_Day_1km",
                              list(0), "flag"),
               class = "earthflux_input_error")
  expect_error(modis_variable(0, "MOD11A1", "QC_Day", list(), NULL),
               class = "earthflux_input_error")
  expect_error(modis_variable(15000, "MOD11A1", "LST_Day_1km",
                              list(QC_Night = 0), "flag"),
               class = "earthflux_modis_unsupported")
})

test_that("NDVI, albedo and reflectance go through the common engine", {
  ndvi <- modis_variable(
    c(8000, -3000, 5000, 6000), "MOD13A2", "1 km 16 days NDVI",
    list(`1 km 16 days VI Quality` = c(2^11, 0, 2^11 + 2, 2^11 + 2^14)),
    qa_policy = "flag"
  )
  expect_equal(ndvi$value, c(0.8, NA, NA, 0.6), tolerance = tol)
  expect_identical(which(ndvi$masks$EF_SURF_WATER), 2L)
  expect_identical(which(ndvi$masks$EF_SURF_CLOUD), 3L)
  expect_identical(which(ndvi$masks$EF_SURF_SNOW), 4L)
  alb <- modis_variable(
    c(180, 200, 32767), "MCD43A3", "Albedo_WSA_shortwave",
    list(BRDF_Albedo_Band_Mandatory_Quality_shortwave = c(0, 1, 255)),
    qa_policy = "flag"
  )
  expect_equal(alb$value, c(0.18, 0.2, NA), tolerance = tol)
  expect_identical(alb$masks$EF_SURF_ALBEDO_MAGNITUDE, c(FALSE, TRUE, FALSE))
  refl <- modis_variable(
    c(500, 600, -28672), "MOD09GA", "sur_refl_b01_1",
    list(QC_500m_1 = c(0, 1, 787410671)), qa_policy = "mask",
    mask_codes = "EF_SURF_QA_OTHER"
  )
  expect_equal(refl$value, c(0.05, NA, NA), tolerance = tol)
  expect_identical(refl$masks$EF_SURF_FILL, c(FALSE, FALSE, TRUE))
  # a QA fill is not evaluated (no code)
  expect_identical(refl$masks$EF_SURF_NOT_PRODUCED, c(FALSE, FALSE, FALSE))
})

test_that("modis_lai() combines both QC layers and states the extra one", {
  lai <- c(35, 40, 45, 50)
  qc <- c(0, 64, 0, 0)
  extra <- c(0, 0, 4, 2)
  x <- modis_lai(lai, qc, extra, qa_policy = "flag")
  expect_equal(x$value, c(3.5, 4.0, 4.5, 5.0), tolerance = tol)
  expect_identical(which(x$masks$EF_SURF_LAI_BACKUP), 2L)
  expect_identical(which(x$masks$EF_SURF_SNOW), 3L)
  expect_identical(which(x$masks$EF_SURF_WATER), 4L)
  y <- modis_lai(lai, qc, NULL, qa_policy = "mask",
                 mask_codes = "EF_SURF_LAI_BACKUP")
  expect_equal(y$value, c(3.5, NA, 4.5, 5.0), tolerance = tol)
  expect_false("EF_SURF_SNOW" %in% names(y$masks))
  expect_error(modis_lai(lai, qc, qa_policy = "flag"))
})

test_that("modis_land_cover() returns classes and the decoded QC", {
  x <- modis_land_cover(c(1, 17, 255, 18), c(0, 10, 255, 0), "LC_Type1")
  expect_identical(x$value, c(1, 17, NA, NA))
  expect_identical(x$masks$EF_SURF_FILL, c(FALSE, FALSE, TRUE, FALSE))
  expect_identical(x$masks$EF_SURF_DN_OUT_OF_RANGE, c(FALSE, FALSE, FALSE,
                                                      TRUE))
  expect_identical(x$qa$QC$code, c(0L, 10L, NA, 0L))
  expect_null(x$policy$qa_policy)
  expect_identical(modis_land_cover(0, 0, "LC_Type3")$value, 0)
  expect_error(modis_land_cover(1, 0, "LW"), class = "earthflux_unknown_method")
  expect_error(modis_land_cover(1, 0), class = "earthflux_missing_input")
})

test_that("modis_flag_word() sets the registry bits of the active codes", {
  x <- modis_lst(c(15000, 0, 14000, NA), c(0, 2, 1, 0), "MOD11A1",
                 qa_policy = "flag")
  w <- modis_flag_word(x$masks)
  reg <- ef_flag_registry()
  bit <- function(code) 2L^reg$bit[reg$code == code]
  expect_identical(w, as.integer(c(
    0L,
    bit("EF_SURF_FILL") + bit("EF_SURF_CLOUD"),
    bit("EF_SURF_QA_OTHER"),
    bit("EF_INPUT_NA")
  )))
  expect_identical(w[2], 6L) # bits 1 and 2
  l <- modis_lai(c(253, 35), c(0, 96), c(0, 0), qa_policy = "flag")
  expect_identical(modis_flag_word(l$masks), as.integer(c(2^5, 2^11)))
  a <- modis_variable(c(180, 200), "MCD43A3", "Albedo_BSA_shortwave",
                      list(), NULL)
  expect_identical(modis_flag_word(a$masks), c(0L, 0L))
  m <- modis_qa_masks(modis_qa_decode(8 + 2^14, "MOD09GA", "state_1km_1"))
  expect_identical(modis_flag_word(m), as.integer(2^10))
  expect_identical(
    modis_flag_word(modis_qa_masks(modis_qa_decode(
      5, "MCD43A3", "BRDF_Albedo_Band_Mandatory_Quality_shortwave"))),
    as.integer(2^12)
  )
  expect_error(modis_flag_word(list(EF_ET_NEGATIVE = TRUE)),
               class = "earthflux_unknown_flag")
  expect_error(modis_flag_word(list()), class = "earthflux_input_error")
})
