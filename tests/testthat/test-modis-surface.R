# Tests for the assembly of the MODIS surface state
#
# Specification: dev/specs/modis-products.md sections 1 (contract), 6, 8, 9,
# 10 and 13.2 (modis_surface_state(), modis_provenance()); dev/specs/flags.md
# 4.2 (EF_SURF_OVERPASS_MISSING, EF_SURF_ALBEDO_GT1), 6.3-6.7.
#
# Every raster is SYNTHETIC (helper-modis-surface.R): tiny GeoTIFF files of
# hand-made DN in a temporary directory, declared as converted DN files. No
# real MODIS file or value is used.

# Sources ----------------------------------------------------------------------

test_that("modis_source() declares HDF4 and converted files", {
  s <- modis_source("MOD11A1.A2019015.h12v12.061.2019017041122.hdf")
  expect_s3_class(s, "earthflux_modis_source")
  expect_identical(s$type, "hdf4")
  expect_identical(s$product, "MOD11A1")
  expect_identical(s$date, as.Date("2019-01-15"))
  expect_identical(s$tile, "h12v12")
  expect_null(s$period)
  p <- modis_source("MOD13A2.A2019001.h12v12.061.2019017041122.hdf",
                    period = as.Date(c("2019-01-01", "2019-01-16")))
  expect_identical(p$period, as.Date(c("2019-01-01", "2019-01-16")))
  c1 <- modis_source(c(Lai_500m = "a.tif", FparLai_QC = "b.tif"),
                     product = "MCD15A2H", date = as.Date("2019-01-09"),
                     scaled = FALSE)
  expect_identical(c1$type, "converted")
  expect_true(is.na(c1$tile))

  err <- "earthflux_input_error"
  expect_error(modis_source(c("a.hdf", "b.hdf")), class = err)
  expect_error(modis_source("lst.tif"),
               class = "earthflux_modis_filename_error")
  expect_error(modis_source("MOD11A1.A2019015.h12v12.061.2019017041122.hdf",
                            product = "MYD11A1"), class = err)
  expect_error(modis_source("MOD11A1.A2019015.h12v12.061.2019017041122.hdf",
                            date = as.Date("2019-01-16")), class = err)
  expect_error(modis_source("MOD11A1.A2019015.h12v12.061.2019017041122.hdf",
                            scaled = FALSE), class = err)
  expect_error(modis_source(c(LST_Day_1km = "a.tif"), product = "MOD11A1",
                            date = as.Date("2019-01-15")),
               class = "earthflux_missing_input")
  expect_error(modis_source(c(LST_Night_1km = "a.tif"), product = "MOD11A1",
                            date = as.Date("2019-01-15"), scaled = FALSE),
               class = "earthflux_modis_unsupported")
  expect_error(modis_source(c(LST_Day_1km = "a.tif"), product = "MOD11A1",
                            date = "2019-01-15", scaled = FALSE), class = err)
  expect_error(modis_source(c(LST_Day_1km = "a.tif"), product = "MOD11A1",
                            date = as.Date("2019-01-15"), scaled = NA),
               class = err)
  expect_error(
    modis_source("MOD13A2.A2019001.h12v12.061.2019017041122.hdf",
                 period = as.Date(c("2019-01-16", "2019-01-01"))),
    class = err
  )
})

# Options -----------------------------------------------------------------------

test_that("modis_surface_options() has no defaults for scientific choices", {
  o <- ss_options()
  expect_s3_class(o, "earthflux_modis_surface_options")
  expect_identical(o$resampling_method, c(albedo = "mean", lai = "mean"))
  expect_identical(o$mask_codes, character(0))
  miss <- "earthflux_missing_input"
  expect_error(modis_surface_options(), class = miss)
  args <- list(lst_product = "MOD11A1", albedo_method = "white_sky",
               emissivity_method = "lai_empirical", ndvi_source = "MOD13A2",
               composite_method = c(albedo = "same_day", ndvi = "period",
                                    lai = "period"),
               resampling_method = "median", min_valid_fraction = 1,
               qa_policy = "flag")
  expect_s3_class(do.call(modis_surface_options, args),
                  "earthflux_modis_surface_options")
  for (nm in names(args)) {
    expect_error(do.call(modis_surface_options, args[names(args) != nm]),
                 class = miss)
  }
})

test_that("planned options raise earthflux_method_not_implemented", {
  ni <- "earthflux_method_not_implemented"
  expect_error(ss_options(lst_product = "MOD21A1D"), class = ni)
  expect_error(ss_options(ndvi_source = "MOD13Q1"), class = ni)
  expect_error(ss_options(ndvi_source = "MOD09GA"), class = ni)
  expect_error(ss_options(albedo_method = "bsa_at_overpass",
                          diffuse_fraction = NULL), class = ni)
  expect_error(ss_options(emissivity_method = "split_window_regression"),
               class = ni)
  expect_error(ss_options(composite_method = c(albedo = "same_day",
                                               ndvi = "interpolate",
                                               lai = "period")),
               class = ni)
  expect_error(ss_options(resampling_method = "bilinear"), class = ni)
  cnd <- tryCatch(ss_options(lst_product = "MYD21A1D"), error = identity)
  expect_s3_class(cnd, "earthflux_unknown_method")
  expect_identical(cnd$choices, c("MOD11A1", "MYD11A1"))
  expect_match(conditionMessage(cnd), "lst_product")
})

test_that("modis_surface_options() checks the coupling of the choices", {
  err <- "earthflux_input_error"
  expect_error(ss_options(diffuse_fraction = NULL),
               class = "earthflux_missing_input")
  expect_error(ss_options(diffuse_fraction = 1.2),
               class = "earthflux_domain_error")
  expect_error(ss_options(albedo_method = "white_sky"), class = err)
  expect_s3_class(ss_options(albedo_method = "white_sky",
                             diffuse_fraction = NULL),
                  "earthflux_modis_surface_options")
  expect_error(ss_options(composite_method = c(albedo = "period_pixel_lag",
                                               ndvi = "period",
                                               lai = "period")),
               class = err)
  expect_error(ss_options(composite_method = c(albedo = "same_day",
                                               ndvi = "period")),
               class = err)
  expect_error(ss_options(resampling_method = "modal"), class = err)
  expect_error(ss_options(resampling_method = c(albedo = "mean")),
               class = err)
  expect_identical(
    ss_options(resampling_method = c(lai = "median",
                                     albedo = "mean"))$resampling_method,
    c(albedo = "mean", lai = "median")
  )
  expect_error(ss_options(min_valid_fraction = 0),
               class = "earthflux_domain_error")
  expect_error(ss_options(qa_policy = "mask"), class = err)
  expect_error(ss_options(qa_policy = "flag", mask_codes = "EF_SURF_SNOW"),
               class = err)
  expect_identical(ss_options(qa_policy = "mask",
                              mask_codes = "EF_SURF_QA_OTHER")$mask_codes,
                   "EF_SURF_QA_OTHER")
})

# Assembly ----------------------------------------------------------------------

test_that("the surface state holds the contract on the working grid", {
  dir <- ss_dir()
  files <- ss_scene(dir)
  st <- modis_surface_state(files, aoi = NULL, options = ss_options())
  expect_s3_class(st, c("earthflux_surface_state", "list"))
  expect_named(st, c("lst", "albedo", "ndvi", "lai", "emissivity",
                     "overpass_time", "lonlat", "qa", "units", "flags",
                     "provenance"))
  tmpl <- ss_grid(3, 4, modis_sinusoidal_grid()$cell_1km)
  for (v in c("lst", "albedo", "ndvi", "lai", "emissivity")) {
    expect_s4_class(st[[v]], "SpatRaster")
    expect_true(terra::compareGeom(st[[v]], tmpl))
    expect_identical(names(st[[v]]), v)
  }
  val <- function(x) terra::values(x, mat = FALSE)
  tol <- 1e-6
  # LST [K] = DN * 0.02; cell 2 is fill + cloud
  expect_equal(val(st$lst)[c(1, 2, 3)], c(300, NA, 290), tolerance = tol)
  # blue-sky albedo of the means of the 2 x 2 sub-cells (DN * 0.001)
  expect_equal(val(st$albedo)[1], 0.8 * 0.180 + 0.2 * 0.190,
               tolerance = tol)
  expect_equal(val(st$albedo)[7], 0.8 * 1.5 + 0.2 * 1.51, tolerance = tol)
  # cell 9: three valid sub-cells out of four (threshold 0.75)
  expect_equal(val(st$albedo)[9], 0.8 * 0.188 + 0.2 * 0.198,
               tolerance = tol)
  expect_equal(
    terra::values(st$qa$valid_fraction[["Albedo_BSA_shortwave_valid_fraction"]],
                  mat = FALSE)[9], 0.75)
  expect_equal(val(st$ndvi)[c(1, 10)], c(0.5, 0.1), tolerance = tol)
  expect_equal(val(st$lai)[c(1, 7, 10)], c(2, 0.5, NA), tolerance = tol)
  # E3: min(0.95 + 0.01 LAI, 0.98)
  expect_equal(val(st$emissivity)[c(1, 3, 10)], c(0.97, 0.98, NA),
               tolerance = tol)
  # overpass: doy and UTC hour of the core, POSIXct UTC instant
  ov <- st$overpass_time
  expect_identical(unique(stats::na.omit(val(ov$doy))), 15)
  lon <- val(st$lonlat[["lon"]])
  expect_equal(val(ov$utc_hour)[1], (10.5 - lon[1] / 15) %% 24,
               tolerance = 1e-9)
  expect_identical(attr(ov$time, "tzone"), "UTC")
  expect_equal(as.numeric(ov$time[1]),
               as.numeric(as.POSIXct("2019-01-15", tz = "UTC")) +
                 val(ov$utc_hour)[1] * 3600, tolerance = 1e-6)
  expect_true(all(is.na(c(val(ov$doy)[c(2, 5)], val(ov$utc_hour)[c(2, 5)],
                          ov$time[c(2, 5)]))))
  expect_identical(st$units[["lst"]], "K")
  expect_identical(st$units[["lai"]], "m2 m-2")
  # composites matched to the LST date
  expect_identical(st$qa$composite$albedo$lag_bound_days, 0)
  expect_identical(st$qa$composite$lai$lag_bound_days, 6)
  expect_equal(val(st$qa$composite$ndvi$lag_days)[c(1, 12)], c(5, 14))
})

test_that("the overpass flag is raised only where the LST is valid", {
  dir <- ss_dir()
  st <- modis_surface_state(ss_scene(dir), aoi = NULL,
                            options = ss_options())
  word <- terra::values(st$qa$flag_word, mat = TRUE)
  reg <- ef_flag_registry()
  bit <- function(code) bitwShiftL(1L, reg$bit[reg$code == code])
  has <- function(layer, code) {
    bitwAnd(as.integer(word[, paste0("flags_", layer)]), bit(code)) != 0L
  }
  # positive: cell 5 (view time fill, LST valid); negative: cell 2 (view
  # time fill where the LST is fill) and every cell with a view time
  expect_identical(which(has("overpass_time", "EF_SURF_OVERPASS_MISSING")),
                   5L)
  expect_identical(which(has("overpass_time", "EF_SURF_FILL")), c(2L, 5L))
  rec <- Filter(function(f) f$code == "EF_SURF_OVERPASS_MISSING", st$flags)
  expect_length(rec, 1L)
  expect_identical(rec[[1]]$index, 5L)
  expect_identical(rec[[1]]$target, "overpass_time")
  expect_identical(rec[[1]]$severity, "warning")
  # the LST of cell 5 is kept
  expect_false(is.na(terra::values(st$lst, mat = FALSE)[5]))
})

test_that("albedo above 1 is kept with the critical flag and excluded", {
  dir <- ss_dir()
  st <- modis_surface_state(ss_scene(dir), aoi = NULL,
                            options = ss_options())
  alb <- terra::values(st$albedo, mat = FALSE)
  rec <- Filter(function(f) f$code == "EF_SURF_ALBEDO_GT1", st$flags)
  expect_length(rec, 1L)
  expect_identical(rec[[1]]$index, 7L)
  expect_identical(rec[[1]]$severity, "critical")
  expect_identical(rec[[1]]$target, "albedo")
  expect_gt(alb[7], 1) # value kept, never truncated
  expect_true(all(alb[-7] <= 1, na.rm = TRUE))
  ex <- surface_exclusion(st)
  expect_identical(which(ex$exclude), 7L)
  expect_identical(ex$counts, c(EF_SURF_ALBEDO_GT1 = 1L))
  reg <- ef_flag_registry()
  expect_identical(reg$error_class[reg$code == "EF_SURF_ALBEDO_GT1"],
                   "earthflux_domain_error")
  # the error counterpart: the core rejects the kept value
  expect_error(ef_net_radiation(rs_in = 800, albedo = alb[7], rl_in = 300,
                                rl_out = 450, emissivity = 0.97),
               class = "earthflux_domain_error")
  expect_error(surface_exclusion(list()), class = "earthflux_input_error")
})

test_that("flags of the inputs reach the layers of the state", {
  dir <- ss_dir()
  st <- modis_surface_state(ss_scene(dir), aoi = NULL,
                            options = ss_options())
  at <- function(code, target) {
    r <- Filter(function(f) f$code == code && f$target == target, st$flags)
    if (length(r) == 0L) integer(0) else r[[1]]$index
  }
  expect_identical(at("EF_SURF_FILL", "lst"), 2L)
  expect_identical(at("EF_SURF_CLOUD", "lst"), 2L)
  expect_identical(at("EF_SURF_QA_OTHER", "lst"), 3L)
  expect_identical(at("EF_SURF_ALBEDO_MAGNITUDE", "albedo"), 8L)
  # the fill sub-cell of cell 9 does not mark the cell: it has a value
  expect_identical(at("EF_SURF_FILL", "albedo"), integer(0))
  expect_identical(at("EF_SURF_QA_OTHER", "ndvi"), 11L)
  expect_identical(at("EF_SURF_WATER", "ndvi"), integer(0))
  expect_identical(at("EF_SURF_LAI_NONVEG", "lai"), 10L)
  expect_identical(at("EF_INPUT_NA", "emissivity"), 10L)
  ev <- st$provenance$flags_evaluated_by_target
  expect_named(ev, c("lst", "overpass_time", "albedo", "ndvi", "lai",
                     "emissivity"))
  expect_true("EF_SURF_ALBEDO_GT1" %in% ev$albedo)
  expect_true("EF_SURF_OVERPASS_MISSING" %in% ev$overpass_time)
  expect_identical(names(st$qa$flag_word), paste0("flags_", names(ev)))
  # the words are the sum of the bits of the records (one source of truth)
  word <- terra::values(st$qa$flag_word, mat = TRUE)
  for (f in st$flags) {
    b <- st$qa$flag_bits$bit[st$qa$flag_bits$code == f$code]
    w <- as.integer(word[, paste0("flags_", f$target)])
    expect_identical(which(bitwAnd(w, bitwShiftL(1L, b)) != 0L), f$index)
  }
  cnt <- st$provenance$flags$counts
  expect_identical(
    cnt$n_flagged[cnt$target == "albedo" & cnt$code == "EF_SURF_ALBEDO_GT1"],
    1L
  )
})

test_that("a cell without enough valid sub-cells is NA with its cause", {
  dir <- ss_dir()
  st <- modis_surface_state(ss_scene(dir), aoi = NULL,
                            options = ss_options(min_valid_fraction = 1))
  expect_true(is.na(terra::values(st$albedo, mat = FALSE)[9]))
  rec <- Filter(function(f) f$code == "EF_SURF_FILL" && f$target == "albedo",
                st$flags)
  expect_identical(rec[[1]]$index, 9L)
})

test_that("qa_policy = 'mask' sets the listed conditions to NA and counts", {
  dir <- ss_dir()
  st <- modis_surface_state(
    ss_scene(dir), aoi = NULL,
    options = ss_options(qa_policy = "mask", mask_codes = "EF_SURF_QA_OTHER")
  )
  expect_true(is.na(terra::values(st$lst, mat = FALSE)[3]))
  expect_true(is.na(terra::values(st$ndvi, mat = FALSE)[11]))
  # the flag is kept and the masked cells are counted
  rec <- Filter(function(f) f$code == "EF_SURF_QA_OTHER" && f$target == "lst",
                st$flags)
  expect_identical(rec[[1]]$index, 3L)
  expect_identical(st$qa$policy$n_masked$lst, c(EF_SURF_QA_OTHER = 1L))
  expect_identical(st$provenance$methods$mask_codes, "EF_SURF_QA_OTHER")
})

test_that("the area of interest crops every product to the same grid", {
  dir <- ss_dir()
  g <- ss_grid(3, 4, modis_sinusoidal_grid()$cell_1km)
  e <- as.vector(terra::ext(g))
  r <- terra::res(g)[1]
  # the two upper-left cells of 1 km, as a polygon in geographic coordinates
  sq <- terra::as.polygons(terra::ext(e[["xmin"]] + 0.1 * r,
                                      e[["xmin"]] + 1.9 * r,
                                      e[["ymax"]] - 0.9 * r,
                                      e[["ymax"]] - 0.1 * r),
                           crs = terra::crs(g))
  aoi <- terra::project(sq, "EPSG:4326")
  st <- modis_surface_state(ss_scene(dir), aoi = aoi, options = ss_options())
  expect_equal(dim(st$lst)[1:2], c(1, 2))
  for (v in c("albedo", "ndvi", "lai", "emissivity")) {
    expect_true(terra::compareGeom(st[[v]], st$lst))
  }
  expect_equal(terra::values(st$lai, mat = FALSE), c(2, 2.5))
  expect_equal(terra::ncell(st$qa$flag_word), 2)
})

test_that("modis_surface_state() refuses inconsistent inputs", {
  dir <- ss_dir()
  files <- ss_scene(dir)
  o <- ss_options()
  err <- "earthflux_input_error"
  expect_error(modis_surface_state(files, options = o),
               class = "earthflux_missing_input")
  expect_error(modis_surface_state(files[1:3], NULL, o), class = err)
  expect_error(modis_surface_state(files, NULL, "flag"), class = err)
  # options given as a plain list are checked by modis_surface_options()
  expect_error(modis_surface_state(files, NULL, list(qa_policy = "flag")),
               class = "earthflux_missing_input")
  # wrong product for the role
  bad <- files
  bad$lai <- files$albedo
  expect_error(modis_surface_state(bad, NULL, o), class = err)
  # composite that does not cover the LST date
  late <- files
  late$lai$period <- as.Date(c("2019-01-17", "2019-01-24"))
  expect_error(modis_surface_state(late, NULL, o), "does not match",
               class = err)
  # a period is needed for "period" matching
  nop <- files
  nop$lai$period <- NULL
  expect_error(modis_surface_state(nop, NULL, o),
               class = "earthflux_missing_input")
  # albedo of another day with "same_day"
  day <- files
  day$albedo$date <- as.Date("2019-01-14")
  expect_error(modis_surface_state(day, NULL, o), "does not match",
               class = err)
  # layers missing or not used by the options
  less <- files
  less$ndvi$path <- less$ndvi$path[1:2]
  expect_error(modis_surface_state(less, NULL, o),
               class = "earthflux_missing_input")
  expect_error(modis_surface_state(files, NULL,
                                   ss_options(albedo_method = "white_sky",
                                              diffuse_fraction = NULL)),
               "not used", class = err)
  # a diffuse fraction raster off the working grid
  df <- terra::rast(nrows = 2, ncols = 2, vals = 0.2,
                    crs = modis_sinusoidal_grid()$crs)
  expect_error(modis_surface_state(files, NULL,
                                   ss_options(diffuse_fraction = df)),
               class = "earthflux_modis_grid_error")
  # 500 m layers that do not nest in the LST grid
  shifted <- files
  g5 <- ss_grid(6, 8, modis_sinusoidal_grid()$cell_500m)
  g5 <- terra::shift(g5, dx = 100)
  shifted$lai$path[["Lai_500m"]] <- ss_write(g5, rep(20, 48), dir,
                                             "lai_shift.tif", "INT1U")
  expect_error(modis_surface_state(shifted, NULL, o), class = err)
})

test_that("a diffuse fraction raster on the working grid is used", {
  dir <- ss_dir()
  g <- ss_grid(3, 4, modis_sinusoidal_grid()$cell_1km)
  df <- terra::rast(g, vals = c(NA, rep(0.5, 11)))
  st <- modis_surface_state(ss_scene(dir), aoi = NULL,
                            options = ss_options(diffuse_fraction = df))
  alb <- terra::values(st$albedo, mat = FALSE)
  expect_true(is.na(alb[1]))
  expect_equal(alb[4], 0.5 * 0.175 + 0.5 * 0.185, tolerance = 1e-6)
  rec <- Filter(function(f) f$code == "EF_INPUT_NA" && f$target == "albedo",
                st$flags)
  expect_identical(rec[[1]]$index, 1L)
  expect_identical(st$provenance$methods$diffuse_fraction, "SpatRaster")
})

# Provenance ------------------------------------------------------------------------

test_that("the provenance records granules, DOIs, methods and versions", {
  dir <- ss_dir()
  st <- modis_surface_state(ss_scene(dir), aoi = NULL,
                            options = ss_options())
  p <- st$provenance
  expect_identical(p$granules$role, c("lst", "albedo", "ndvi", "lai"))
  expect_identical(p$granules$product,
                   c("MOD11A1", "MCD43A3", "MOD13A2", "MCD15A2H"))
  expect_identical(p$collection, "061")
  expect_identical(p$granules$doi[1], "10.5067/MODIS/MOD11A1.061")
  expect_identical(p$granules$doi_status,
                   c("VERIFICADA", "VERIFICADA", "DERIVADA", "DERIVADA"))
  expect_identical(p$granules$input, rep("converted_dn", 4))
  expect_identical(p$granules$period_end[3], "2019-01-16")
  expect_identical(p$methods$albedo_method, "blue_sky")
  expect_identical(p$methods$composite_method[["ndvi"]], "period_pixel_lag")
  expect_true(all(c("earthflux", "terra", "gdal", "proj", "r") %in%
                    names(p$versions)))
  expect_identical(p$status[["albedo"]], "CANDIDATA")
  expect_true(all(c("LST_Day_1km", "Day_view_time", "Albedo_BSA_shortwave",
                    "1 km 16 days NDVI", "Lai_500m") %in% p$product_rows$layer))
  expect_true(all(nzchar(p$product_rows$source)))
  expect_true(all(p$flags$registry$code %in% p$flags_evaluated))
})

test_that("the DOI table and the cached product table are consistent", {
  d <- modis_product_doi()
  expect_true(all(d$product %in% modis_supported_products()))
  expect_identical(d$doi, sprintf("10.5067/MODIS/%s.061", d$product))
  expect_false("MCD43A2" %in% d$product)
  expect_identical(modis_product_table(), modis_product_table_build())
})
