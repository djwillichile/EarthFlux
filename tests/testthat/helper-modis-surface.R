# Synthetic MODIS scene for the surface state tests
#
# Everything here is SYNTHETIC: tiny GeoTIFF "granules" written with terra
# in a temporary directory, holding hand-made raw DN on the documented
# geometry of the sinusoidal grid (upper-left corner of tile h12v12; 3 x 4
# cells of 1 km and 6 x 8 cells of 500 m). They are declared as converted
# DN files (modis_source(..., scaled = FALSE)); no real MODIS file or value
# is used and nothing is downloaded. The dates and composite periods are
# made up for the test.

# Grid of the synthetic scene: `nr` x `nc` cells of `cell` metres at the
# upper-left corner of tile h12v12.
ss_grid <- function(nr, nc, cell) {
  g <- modis_sinusoidal_grid()
  e <- as.vector(modis_tile_extent(12, 12))
  terra::rast(nrows = nr, ncols = nc, xmin = e[["xmin"]],
              xmax = e[["xmin"]] + nc * cell, ymin = e[["ymax"]] - nr * cell,
              ymax = e[["ymax"]], crs = g$crs)
}

# Write `vals` (terra cell order) as a GeoTIFF without NoData.
ss_write <- function(r, vals, dir, name, datatype) {
  terra::values(r) <- vals
  f <- file.path(dir, name)
  terra::writeRaster(r, f, overwrite = TRUE, datatype = datatype,
                     NAflag = NA)
  f
}

# Expand a 1 km field (3 x 4, cell order) to the 2 x 2 sub-cells of the
# 500 m grid (6 x 8, cell order).
ss_to_500m <- function(v1km, nr = 3L, nc = 4L) {
  m <- matrix(v1km, nrow = nr, ncol = nc, byrow = TRUE)
  m2 <- m[rep(seq_len(nr), each = 2L), rep(seq_len(nc), each = 2L)]
  as.vector(t(m2))
}

# Index (cell order) of sub-cell `k` (1-4) of 1 km cell `i` on the 500 m grid.
ss_subcell <- function(i, k, nc = 4L) {
  row <- (i - 1L) %/% nc
  col <- (i - 1L) %% nc
  r2 <- 2L * row + (k - 1L) %/% 2L
  c2 <- 2L * col + (k - 1L) %% 2L
  r2 * (2L * nc) + c2 + 1L
}

# Write the synthetic scene and return the `files` list of
# modis_surface_state(). Cells of the 1 km grid (cell order 1-12):
#   1  good everywhere                 7  albedo DN 1500 (albedo 1.5 > 1)
#   2  LST fill + cloud, view time fill 8  albedo mandatory quality 1
#   3  LST other quality (QC 01)        9  one albedo sub-cell is fill
#   4  good                            10  LAI class 253 (barren)
#   5  view time fill, LST valid       11  NDVI VI Quality MODLAND 01
#   6  good                            12  good
ss_scene <- function(dir, lst_date = as.Date("2019-01-15")) {
  g1 <- ss_grid(3, 4, modis_sinusoidal_grid()$cell_1km)
  g5 <- ss_grid(6, 8, modis_sinusoidal_grid()$cell_500m)

  lst <- c(15000, 0, 14500, 15100, 15050, 14900, 15200, 15000, 14950,
           15300, 15000, 14800)
  qc <- c(0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  vt <- c(105, 255, 106, 105, 255, 104, 105, 105, 106, 105, 105, 104)

  bsa1 <- c(180, 190, 185, 175, 200, 170, 1500, 182, 188, 210, 176, 181)
  wsa1 <- bsa1 + 10
  bsa <- ss_to_500m(bsa1)
  wsa <- ss_to_500m(wsa1)
  fill_sub <- ss_subcell(9L, 1L)
  bsa[fill_sub] <- 32767
  wsa[fill_sub] <- 32767
  aq <- ss_to_500m(c(0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0))
  aq[fill_sub] <- 255

  ndvi <- c(5000, 4000, 6000, 5500, 5200, 4800, 3000, 5100, 4900, 1000,
            4500, 5300)
  viq <- c(rep(2048, 10), 2049, 2048) # land (bits 13-11 = 001); 11: MODLAND 01
  cdoy <- c(10, 11, 12, 9, 10, 13, 14, 10, 11, 12, 15, 1)

  lai1 <- c(20, 25, 30, 15, 22, 18, 5, 21, 19, 253, 24, 26)
  lai <- ss_to_500m(lai1)
  lqc <- rep(0, 48)
  lex <- rep(0, 48)

  w1 <- function(v, name, type) ss_write(g1, v, dir, name, type)
  w5 <- function(v, name, type) ss_write(g5, v, dir, name, type)
  list(
    lst = modis_source(
      c(LST_Day_1km = w1(lst, "lst.tif", "INT2U"),
        QC_Day = w1(qc, "qc_day.tif", "INT1U"),
        Day_view_time = w1(vt, "view_time.tif", "INT1U")),
      product = "MOD11A1", date = lst_date, scaled = FALSE
    ),
    albedo = modis_source(
      c(Albedo_BSA_shortwave = w5(bsa, "bsa.tif", "INT2S"),
        Albedo_WSA_shortwave = w5(wsa, "wsa.tif", "INT2S"),
        BRDF_Albedo_Band_Mandatory_Quality_shortwave =
          w5(aq, "albedo_qa.tif", "INT1U")),
      product = "MCD43A3", date = lst_date, scaled = FALSE
    ),
    ndvi = modis_source(
      c("1 km 16 days NDVI" = w1(ndvi, "ndvi.tif", "INT2S"),
        "1 km 16 days VI Quality" = w1(viq, "vi_quality.tif", "INT2U"),
        "1 km 16 days composite day of the year" =
          w1(cdoy, "composite_doy.tif", "INT2S")),
      product = "MOD13A2", date = as.Date("2019-01-01"), scaled = FALSE,
      period = as.Date(c("2019-01-01", "2019-01-16"))
    ),
    lai = modis_source(
      c(Lai_500m = w5(lai, "lai.tif", "INT1U"),
        FparLai_QC = w5(lqc, "lai_qc.tif", "INT1U"),
        FparExtra_QC = w5(lex, "lai_extra_qc.tif", "INT1U")),
      product = "MCD15A2H", date = as.Date("2019-01-09"), scaled = FALSE,
      period = as.Date(c("2019-01-09", "2019-01-16"))
    )
  )
}

# Options of the synthetic scene (explicit choices; the diffuse fraction is
# a made-up number for the test, not a model).
ss_options <- function(...) {
  args <- list(
    lst_product = "MOD11A1", albedo_method = "blue_sky",
    diffuse_fraction = 0.2, emissivity_method = "lai_empirical",
    ndvi_source = "MOD13A2",
    composite_method = c(albedo = "same_day", ndvi = "period_pixel_lag",
                         lai = "period"),
    resampling_method = "mean", min_valid_fraction = 0.75,
    qa_policy = "flag"
  )
  new <- list(...)
  for (nm in names(new)) args[nm] <- list(new[[nm]])
  do.call(modis_surface_options, args)
}

# A temporary directory removed when the calling test ends.
ss_dir <- function(env = parent.frame()) {
  d <- tempfile("modis-surface-synthetic-")
  dir.create(d)
  do.call(on.exit, list(substitute(unlink(d, recursive = TRUE), list(d = d)),
                        add = TRUE), envir = env)
  d
}
