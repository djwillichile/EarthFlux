# Tests for the MODIS readers, tile mosaic and area of interest
#
# Specification: dev/specs/modis-products.md sections 4 (sinusoidal grid),
# 11 (I/O: HDF4 through terra/GDAL, converted formats with a mandatory
# declaration, scale/offset conventions, tiles and AOI) and 14.
#
# Every raster below is SYNTHETIC: tiny GeoTIFF/HDF4 files written with
# terra in a temporary directory (removed at the end of each test), with
# hand-made DN on the documented geometry of the sinusoidal grid. No real
# MODIS file or value is used, and nothing is downloaded.

sinu <- modis_sinusoidal_grid()$crs

# A temporary directory removed when the calling test ends.
local_test_dir <- function(env = parent.frame()) {
  d <- tempfile("modis-synthetic-")
  dir.create(d)
  do.call(on.exit, list(substitute(unlink(d, recursive = TRUE), list(d = d)),
                        add = TRUE), envir = env)
  d
}

# A synthetic window of tile h12v12 (1 km cells), upper-left corner of the
# tile, `nr` x `nc` cells.
tile_window <- function(nr = 3, nc = 4, h = 12, v = 12, cell = NULL) {
  g <- modis_sinusoidal_grid()
  if (is.null(cell)) cell <- g$cell_1km
  e <- as.vector(modis_tile_extent(h, v))
  terra::rast(nrows = nr, ncols = nc, xmin = e[["xmin"]],
              xmax = e[["xmin"]] + nc * cell, ymin = e[["ymax"]] - nr * cell,
              ymax = e[["ymax"]], crs = g$crs)
}

write_tif <- function(r, vals, dir, name, ...) {
  terra::values(r) <- vals
  f <- file.path(dir, name)
  terra::writeRaster(r, f, overwrite = TRUE, ...)
  f
}

# Converted files (MP-10) -------------------------------------------------------------

test_that("converted DN files are read with an explicit declaration", {
  dir <- local_test_dir()
  dn <- c(15000, 0, 7500, 65535, 14000, 7499, 15000, 15000, 15000, 15000,
          15000, 15000)
  f <- write_tif(tile_window(), dn, dir, "lst_dn.tif", datatype = "INT2U",
                 NAflag = NA)
  r <- modis_read_converted(f, "MOD11A1", "LST_Day_1km", scaled = FALSE)
  expect_s4_class(r, "SpatRaster")
  expect_identical(names(r), "LST_Day_1km")
  expect_equal(terra::values(r, mat = FALSE), dn)
  expect_identical(modis_get_tag(r, "input"), "converted_dn")
  expect_identical(modis_get_tag(r, "product"), "MOD11A1")
  x <- modis_lst(r, rep(0, 12), "MOD11A1", qa_policy = "flag")
  expect_equal(x$value[1:4], c(300, NA, 150, 1310.7), tolerance = 1e-12)
  expect_identical(which(x$masks$EF_SURF_FILL), 2L)
  expect_identical(which(x$masks$EF_SURF_DN_OUT_OF_RANGE), 6L)
})

test_that("a NoData equal to the fill value is read back as the fill DN", {
  dir <- local_test_dir()
  dn <- c(0, 15000, 15000, 15000)
  f <- write_tif(tile_window(2, 2), dn, dir, "lst_nd_fill.tif",
                 datatype = "INT2U", NAflag = 0)
  expect_true(is.na(terra::values(terra::rast(f), mat = FALSE)[1]))
  r <- modis_read_converted(f, "MOD11A1", "LST_Day_1km", scaled = FALSE)
  expect_equal(terra::values(r, mat = FALSE), dn)
  # another NoData value is missing data (EF_INPUT_NA downstream)
  g <- write_tif(tile_window(2, 2), c(15000, 15000, 15000, 15000), dir,
                 "lst_nd_other.tif", datatype = "INT2U", NAflag = 15000)
  r2 <- modis_read_converted(g, "MOD11A1", "LST_Day_1km", scaled = FALSE)
  expect_true(all(is.na(terra::values(r2, mat = FALSE))))
  x <- modis_lst(r2, rep(0, 4), "MOD11A1", qa_policy = "flag")
  expect_true(all(x$masks$EF_INPUT_NA))
  expect_false(any(x$masks$EF_SURF_FILL))
})

test_that("converted files declared as scaled are turned back into DN", {
  dir <- local_test_dir()
  phys <- c(300.02, 150, NA, 1310.7)
  f <- write_tif(tile_window(2, 2), phys, dir, "lst_k.tif",
                 datatype = "FLT4S")
  r <- modis_read_converted(f, "MOD11A1", "LST_Day_1km", scaled = TRUE)
  expect_equal(terra::values(r, mat = FALSE), c(15001, 7500, NA, 65535))
  expect_identical(modis_get_tag(r, "input"), "converted_scaled")
  # emissivity: physical = DN * 0.002 + 0.49
  g <- write_tif(tile_window(1, 2), c(1.0, 0.492), dir, "emis.tif",
                 datatype = "FLT4S")
  e <- modis_read_converted(g, "MOD11A1", "Emis_31", scaled = TRUE)
  expect_equal(terra::values(e, mat = FALSE), c(255, 1))
  # albedo: physical = (DN - 0) * 0.001
  a <- write_tif(tile_window(1, 2), c(0.18, 1.5), dir, "albedo.tif",
                 datatype = "FLT4S")
  expect_identical(
    terra::values(modis_read_converted(a, "MCD43A3", "Albedo_WSA_shortwave",
                                       scaled = TRUE), mat = FALSE),
    c(180, 1500)
  )
})

test_that("a wrong or missing declaration is refused (no double scaling)", {
  dir <- local_test_dir()
  phys <- write_tif(tile_window(2, 2), c(300.01, 300.03, 290.05, 280.07), dir,
                    "lst_k.tif", datatype = "FLT4S")
  dn <- write_tif(tile_window(2, 2), c(15000, 15000, 14000, 0), dir,
                  "lst_dn.tif", datatype = "INT2U", NAflag = NA)
  err <- "earthflux_modis_dn_error"
  expect_error(modis_read_converted(phys, "MOD11A1", "LST_Day_1km",
                                    scaled = FALSE), class = err)
  expect_error(modis_read_converted(dn, "MOD11A1", "LST_Day_1km",
                                    scaled = TRUE), class = err)
  expect_error(modis_read_converted(dn, "MOD11A1", "LST_Day_1km"),
               class = "earthflux_missing_input")
  expect_error(modis_read_converted(dn, "MOD11A1", "LST_Day_1km",
                                    scaled = NA),
               class = "earthflux_input_error")
  expect_error(modis_read_converted(dn, "MOD11A1", "LST_Night_1km",
                                    scaled = FALSE),
               class = "earthflux_modis_unsupported")
  expect_error(modis_read_converted(file.path(dir, "none.tif"), "MOD11A1",
                                    "LST_Day_1km", scaled = FALSE),
               class = "earthflux_input_error")
  two <- tile_window(2, 2)
  two <- c(two, two)
  f2 <- write_tif(two, cbind(1:4, 1:4), dir, "two.tif", datatype = "INT2U",
                  NAflag = NA)
  expect_error(modis_read_converted(f2, "MOD11A1", "QC_Day", scaled = FALSE),
               class = "earthflux_input_error")
})

test_that("file scale metadata is checked against the table, never applied", {
  dir <- local_test_dir()
  # synthetic file declaring scale 0.02 (written as physical / 0.02)
  ok <- write_tif(tile_window(1, 2), c(300, 150), dir, "lst_scoff.tif",
                  datatype = "INT2U", NAflag = NA, scale = 0.02, offset = 0)
  expect_equal(terra::scoff(terra::rast(ok))[1, "scale"], c(scale = 0.02))
  r <- modis_read_converted(ok, "MOD11A1", "LST_Day_1km", scaled = FALSE)
  expect_equal(terra::values(r, mat = FALSE), c(15000, 7500))
  meta <- "earthflux_modis_metadata_error"
  expect_error(modis_read_converted(ok, "MOD11A1", "LST_Day_1km",
                                    scaled = TRUE), class = meta)
  bad <- write_tif(tile_window(1, 2), c(30, 15), dir, "lst_bad.tif",
                   datatype = "INT2U", NAflag = NA, scale = 0.002, offset = 0)
  expect_error(modis_read_converted(bad, "MOD11A1", "LST_Day_1km",
                                    scaled = FALSE), class = meta)
  # a non-zero offset on a layer without offset in the table is refused
  off <- write_tif(tile_window(1, 2), c(0.06, 0.07), dir, "refl_off.tif",
                   datatype = "INT2S", NAflag = NA, scale = 0.0001,
                   offset = 0.01)
  expect_error(modis_read_converted(off, "MOD09GA", "sur_refl_b01_1",
                                    scaled = FALSE), class = meta)
})

# Area of interest ---------------------------------------------------------------------

test_that("the AOI is cropped in the native grid of the raster", {
  dir <- local_test_dir()
  w <- tile_window(4, 5)
  f <- write_tif(w, seq_len(20) + 7500, dir, "lst.tif", datatype = "INT2U",
                 NAflag = NA)
  g <- modis_sinusoidal_grid()
  e <- as.vector(terra::ext(w))
  # SpatExtent: taken in the CRS of the file; snapped outwards
  aoi <- terra::ext(e[["xmin"]] + 0.5 * g$cell_1km, e[["xmin"]] + 1.5 * g$cell_1km,
                    e[["ymax"]] - 1.2 * g$cell_1km, e[["ymax"]] - 0.2 * g$cell_1km)
  r <- modis_read_converted(f, "MOD11A1", "LST_Day_1km", scaled = FALSE,
                            aoi = aoi)
  expect_equal(dim(r)[1:2], c(2L, 2L))
  expect_equal(terra::values(r, mat = FALSE), c(7501, 7502, 7506, 7507))
  expect_true(terra::same.crs(r, sinu))
  # SpatVector in geographic coordinates, projected to the sinusoidal grid
  ctr <- terra::project(terra::vect(cbind(e[["xmin"]] + 2.5 * g$cell_1km,
                                          e[["ymax"]] - 2.5 * g$cell_1km),
                                    crs = sinu), "EPSG:4326")
  pol <- terra::buffer(ctr, 300)
  r2 <- modis_read_converted(f, "MOD11A1", "LST_Day_1km", scaled = FALSE,
                             aoi = pol)
  expect_equal(terra::values(r2, mat = FALSE), 7500 + 13)
  # no overlap, wrong type, no CRS
  far <- terra::ext(0, 1000, 0, 1000)
  expect_error(modis_read_converted(f, "MOD11A1", "LST_Day_1km",
                                    scaled = FALSE, aoi = far),
               class = "earthflux_modis_grid_error")
  expect_error(aoi_extent("Cauquenes", w), class = "earthflux_input_error")
  expect_error(aoi_extent(terra::vect(cbind(0, 0)), w),
               class = "earthflux_input_error")
})

# Mosaic --------------------------------------------------------------------------------

test_that("adjacent tiles are mosaicked; incompatible tiles are refused", {
  g <- modis_sinusoidal_grid()
  a <- tile_window(2, 2)
  terra::values(a) <- 1:4
  e <- as.vector(terra::ext(a))
  b <- terra::shift(a, dx = 2 * g$cell_1km)
  terra::values(b) <- 5:8
  a <- modis_tag(a, c(product = "MOD11A1", date = "2019-01-01",
                      tile = "h12v12"))
  b <- modis_tag(b, c(product = "MOD11A1", date = "2019-01-01",
                      tile = "h13v12"))
  names(a) <- names(b) <- "LST_Day_1km"
  m <- modis_mosaic_tiles(list(a, b))
  expect_equal(dim(m)[1:2], c(2L, 4L))
  expect_equal(terra::values(m, mat = FALSE), c(1, 2, 5, 6, 3, 4, 7, 8))
  expect_identical(modis_get_tag(m, "tile"), "h12v12,h13v12")
  expect_identical(modis_get_tag(m, "product"), "MOD11A1")
  expect_identical(names(m), "LST_Day_1km")
  expect_identical(modis_mosaic_tiles(list(a)), a)
  err <- "earthflux_modis_grid_error"
  over <- terra::shift(a, dx = g$cell_1km)
  expect_error(modis_mosaic_tiles(list(a, over)), class = err)
  half <- terra::shift(a, dx = 2.5 * g$cell_1km)
  expect_error(modis_mosaic_tiles(list(a, half)), class = err)
  other_day <- modis_tag(b, c(product = "MOD11A1", date = "2019-01-02"))
  expect_error(modis_mosaic_tiles(list(a, other_day)), class = err)
  renamed <- b
  names(renamed) <- "QC_Day"
  expect_error(modis_mosaic_tiles(list(a, renamed)), class = err)
  coarse <- terra::aggregate(b, 2)
  names(coarse) <- "LST_Day_1km"
  expect_error(modis_mosaic_tiles(list(a, coarse)), class = err)
  expect_error(modis_mosaic_tiles(list()), class = "earthflux_input_error")
})

# HDF4 (official format) ------------------------------------------------------------------

# A synthetic HDF4 file named like tile h12v12 of MOD11A1, with the full
# 1200 x 1200 geometry of the 1 km grid. GDAL writes plain HDF4 SDS (not
# HDF-EOS grids) whose SDS names are indices, so the listing of the file is
# replaced by one with the SDS names of the sheet; the reading itself goes
# through the real HDF4 driver.
write_hdf4_tile <- function(dir, vals, nodata = NA,
                            file = "MOD11A1.A2019001.h12v12.061.2019002123456.hdf") {
  g <- modis_sinusoidal_grid()
  r <- terra::rast(nrows = 1200, ncols = 1200, nlyrs = ncol(vals),
                   extent = modis_tile_extent(12, 12), crs = g$crs)
  terra::values(r) <- vals
  f <- file.path(dir, file)
  terra::writeRaster(r, f, filetype = "HDF4Image", datatype = "INT2U",
                     NAflag = nodata, gdal = "RANK=2")
  f
}

fake_listing <- function(path, sds) {
  if (length(sds) == 1L) {
    # a one-band HDF4 file written by GDAL has no subdatasets
    return(data.frame(sds = sds, grid = NA_character_, name = path,
                      nrow = 1200, ncol = 1200, stringsAsFactors = FALSE))
  }
  d <- terra::describe(path, sds = TRUE)
  data.frame(sds = sds, grid = NA_character_, name = d$name, nrow = d$nrow,
             ncol = d$ncol, stringsAsFactors = FALSE)
}

test_that("subdataset names are split into grid and SDS name", {
  p <- modis_parse_sds_name(c(
    'HDF4_EOS:EOS_GRID:"/x/MOD11A1.hdf":MODIS_Grid_Daily_1km_LST:LST_Day_1km',
    'HDF4_EOS:EOS_GRID:"/x/MOD13A2.hdf":MODIS_Grid_16DAY_1km_VI:1 km 16 days NDVI',
    'HDF4_SDS:UNKNOWN:"/x/file.hdf":0'
  ))
  expect_identical(p$grid, c("MODIS_Grid_Daily_1km_LST",
                             "MODIS_Grid_16DAY_1km_VI", NA))
  expect_identical(p$sds, c("LST_Day_1km", "1 km 16 days NDVI", "0"))
})

test_that("layers are matched exactly, with official alternatives", {
  rows <- rbind(modis_layer_spec("MOD13A2", "1 km 16 days NDVI"),
                modis_layer_spec("MOD13A2", "1 km 16 days VI Quality"))
  listing <- data.frame(sds = c("1km 16 days NDVI", "1km 16 days VI Quality",
                                "1km 16 days EVI"),
                        grid = "G", name = c("n1", "n2", "n3"))
  expect_identical(modis_match_layers(rows, listing), c("n1", "n2"))
  err <- "earthflux_modis_layer_error"
  expect_error(modis_match_layers(rows, listing[2:3, ]), class = err)
  both <- rbind(listing, data.frame(sds = "1 km 16 days NDVI", grid = "G",
                                    name = "n4"))
  expect_error(modis_match_layers(rows[1, ], both), class = err)
  lst <- modis_layer_spec("MOD11A1", "LST_Day_1km")
  wrong_grid <- data.frame(sds = "LST_Day_1km", grid = "OtherGrid",
                           name = "x")
  expect_error(modis_match_layers(lst, wrong_grid), class = err)
})

test_that("raw DN are read from HDF4 without GDAL scaling and cropped", {
  skip_if_not(modis_has_hdf4(), "GDAL driver HDF4 not available")
  dir <- local_test_dir()
  n <- 1200 * 1200
  lst <- rep(15000, n)
  lst[1:3] <- c(0, 7500, 65535) # first row of the tile, synthetic
  qc <- rep(0, n)
  qc[1:3] <- c(2, 1, 0)
  f <- write_hdf4_tile(dir, cbind(lst, qc))
  expect_identical(modis_list_layers(f)$sds, c("0", "1"))
  local_mocked_bindings(
    modis_list_layers = function(path) fake_listing(path, c("LST_Day_1km",
                                                           "QC_Day"))
  )
  g <- modis_sinusoidal_grid()
  e <- as.vector(modis_tile_extent(12, 12))
  aoi <- terra::ext(e[["xmin"]], e[["xmin"]] + 3 * g$cell_1km,
                    e[["ymax"]] - g$cell_1km, e[["ymax"]])
  r <- modis_read_raw(f, c("LST_Day_1km", "QC_Day"), aoi = aoi)
  expect_identical(names(r), c("LST_Day_1km", "QC_Day"))
  expect_equal(dim(r), c(1L, 3L, 2L))
  expect_equal(terra::values(r[[1]], mat = FALSE), c(0, 7500, 65535))
  expect_identical(modis_get_tag(r, "date"), "2019-01-01")
  expect_identical(modis_get_tag(r, "tile"), "h12v12")
  expect_identical(modis_get_tag(r, "input"), "dn")
  x <- modis_lst(r[[1]], r[[2]], "MOD11A1", qa_policy = "flag")
  expect_equal(x$value, c(NA, 150, 1310.7), tolerance = 1e-12)
  expect_identical(which(x$masks$EF_SURF_CLOUD), 1L)
  expect_identical(which(x$masks$EF_SURF_QA_OTHER), 2L)
  # whole tile without AOI
  full <- modis_read_raw(f, "QC_Day")
  expect_equal(dim(full), c(1200L, 1200L, 1L))
})

test_that("the HDF4 reader restores the fill and checks the file", {
  skip_if_not(modis_has_hdf4(), "GDAL driver HDF4 not available")
  dir <- local_test_dir()
  n <- 1200 * 1200
  lst <- rep(15000, n)
  lst[1] <- 0
  f <- write_hdf4_tile(dir, cbind(lst), nodata = 0)
  local_mocked_bindings(
    modis_list_layers = function(path) fake_listing(path, "LST_Day_1km")
  )
  g <- modis_sinusoidal_grid()
  e <- as.vector(modis_tile_extent(12, 12))
  aoi <- terra::ext(e[["xmin"]], e[["xmin"]] + 2 * g$cell_1km,
                    e[["ymax"]] - g$cell_1km, e[["ymax"]])
  r <- modis_read_raw(f, "LST_Day_1km", aoi = aoi)
  expect_equal(terra::values(r, mat = FALSE), c(0, 15000))

  # NoData that contradicts the table (QC_Day has no fill value)
  local_mocked_bindings(
    modis_list_layers = function(path) fake_listing(path, "QC_Day")
  )
  expect_error(modis_read_raw(f, "QC_Day", aoi = aoi),
               class = "earthflux_modis_metadata_error")

  # the tile named in the file must match the extent of the data
  wrong <- file.path(dir, "MOD11A1.A2019001.h11v12.061.2019002123456.hdf")
  file.copy(f, wrong)
  local_mocked_bindings(
    modis_list_layers = function(path) fake_listing(path, "LST_Day_1km")
  )
  expect_error(modis_read_raw(wrong, "LST_Day_1km"),
               class = "earthflux_modis_grid_error")
  # layers of different resolution, unsupported layers and collections
  expect_error(modis_read_raw(f, c("LST_Day_1km", "QC_Night")),
               class = "earthflux_modis_unsupported")
  old <- file.path(dir, "MOD11A1.A2019001.h12v12.006.2019002123456.hdf")
  file.copy(f, old)
  expect_error(modis_read_raw(old, "LST_Day_1km"),
               class = "earthflux_modis_unsupported")
  expect_error(modis_read_raw(f, character(0)),
               class = "earthflux_input_error")
})

test_that("the HDF4 reader checks the cell size of the sinusoidal grid", {
  skip_if_not(modis_has_hdf4(), "GDAL driver HDF4 not available")
  dir <- local_test_dir()
  g <- modis_sinusoidal_grid()
  r <- terra::rast(nrows = 600, ncols = 600,
                   extent = modis_tile_extent(12, 12), crs = g$crs)
  terra::values(r) <- 15000
  f <- file.path(dir, "MOD11A1.A2019001.h12v12.061.2019002123456.hdf")
  terra::writeRaster(r, f, filetype = "HDF4Image", datatype = "INT2U",
                     NAflag = NA, gdal = "RANK=2")
  local_mocked_bindings(
    modis_list_layers = function(path) fake_listing(path, "LST_Day_1km")
  )
  expect_error(modis_read_raw(f, "LST_Day_1km"),
               class = "earthflux_modis_grid_error")
})

test_that("reading HDF4 needs the driver; a missing driver is a classed error", {
  dir <- local_test_dir()
  f <- file.path(dir, "MOD11A1.A2019001.h12v12.061.2019002123456.hdf")
  file.create(f)
  local_mocked_bindings(modis_has_hdf4 = function() FALSE)
  expect_error(modis_list_layers(f), class = "earthflux_modis_driver_error")
  expect_error(modis_read_raw(f, "LST_Day_1km"),
               class = "earthflux_modis_driver_error")
})
