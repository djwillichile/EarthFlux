# Elevation model and terrain on the working grid (R/dem.R; decision M5-06).
# Offline: synthetic rasters, synthetic CMR JSON and a mocked network call
# (dem_curl()). The optional live test at the end needs
# EARTHFLUX_LIVE_TESTS=true and EARTHDATA_TOKEN.

# Helpers ----------------------------------------------------------------------

# Temporary directory removed when the calling test ends.
dem_test_dir <- function(env = parent.frame()) {
  d <- tempfile("dem-test-")
  dir.create(d)
  do.call(on.exit, list(substitute(unlink(d, recursive = TRUE), list(d = d)),
                        add = TRUE), envir = env)
  d
}

# Set (or unset, value = NA) EARTHDATA_TOKEN until the calling test ends.
dem_local_token <- function(value, env = parent.frame()) {
  old <- Sys.getenv("EARTHDATA_TOKEN", unset = NA)
  if (is.na(value)) Sys.unsetenv("EARTHDATA_TOKEN") else
    Sys.setenv(EARTHDATA_TOKEN = value)
  restore <- if (is.na(old)) quote(Sys.unsetenv("EARTHDATA_TOKEN")) else
    substitute(Sys.setenv(EARTHDATA_TOKEN = v), list(v = old))
  do.call(on.exit, list(restore, add = TRUE), envir = env)
  invisible(NULL)
}

# A working grid of nc x nr MODIS 1 km cells (sinusoidal) whose upper-left
# corner is near (lon0, lat0).
dem_test_grid <- function(nc = 3, nr = 3, lon0 = -72, lat0 = -35.9) {
  g <- modis_sinusoidal_grid()
  R <- 6371007.181
  x0 <- R * lon0 * pi / 180 * cos(lat0 * pi / 180)
  y0 <- R * lat0 * pi / 180
  terra::rast(xmin = x0, xmax = x0 + nc * g$cell_1km,
              ymin = y0 - nr * g$cell_1km, ymax = y0,
              ncols = nc, nrows = nr, crs = g$crs)
}

# A 1 arc-second DEM over the window that dem_read() would build for `grid`,
# with elevation fun(lon, lat) at the pixel centres.
dem_test_dem <- function(grid, fun) {
  w <- dem_window(grid, n = 3601L)
  r <- terra::rast(nrows = w$j[2] - w$j[1] + 1, ncols = w$k[2] - w$k[1] + 1,
                   xmin = (w$k[1] - 0.5) / 3600, xmax = (w$k[2] + 0.5) / 3600,
                   ymin = (w$j[1] - 0.5) / 3600, ymax = (w$j[2] + 0.5) / 3600,
                   crs = "EPSG:4326", names = "elevation")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- fun(xy[, 1], xy[, 2])
  r
}

# Local east and north distances [m] on the WGS84 ellipsoid from (lon0,
# lat0), with the meridian and prime-vertical radii of curvature at lat0.
dem_test_en <- function(lon, lat, lon0, lat0) {
  a <- 6378137
  f <- 1 / 298.257223563
  e2 <- f * (2 - f)
  ph <- lat0 * pi / 180
  M <- a * (1 - e2) / (1 - e2 * sin(ph)^2)^1.5
  N <- a / sqrt(1 - e2 * sin(ph)^2)
  list(e = (lon - lon0) * pi / 180 * N * cos(ph),
       n = (lat - lat0) * pi / 180 * M)
}

terrain_quiet <- function(...) {
  suppressWarnings(dem_terrain(...),
                   classes = "earthflux_dem_incomplete_warning")
}

# Effective terrain algebra ----------------------------------------------------

test_that("normal components follow the GIS aspect of the core", {
  s <- 0.3
  n <- dem_normal_components(s, c(0, pi / 2, pi, 3 * pi / 2))
  # north-, east-, south- and west-facing planes
  expect_equal(n$nx, sin(s) * c(0, 1, 0, -1), tolerance = 1e-12)
  expect_equal(n$ny, sin(s) * c(1, 0, -1, 0), tolerance = 1e-12)
  expect_equal(n$nz, rep(cos(s), 4), tolerance = 1e-12)
  eff <- dem_effective_terrain(n$nx, n$ny, n$nz)
  expect_equal(eff$slope, rep(s, 4), tolerance = 1e-12)
  expect_equal(eff$aspect, c(0, pi / 2, pi, 3 * pi / 2), tolerance = 1e-12)
  expect_equal(eff$normal_length, rep(1, 4), tolerance = 1e-12)
})

test_that("the normal convention matches ef_cos_incidence()", {
  # cos(incidence) is linear in the unit normal: cos = n . S, with S read
  # from a horizontal plane (up), and vertical planes facing east and north.
  set.seed(11)
  lat <- -36 * pi / 180
  dec <- runif(5, -0.4, 0.4)
  w <- runif(5, -1.2, 1.2)
  s_up <- ef_cos_incidence(lat, dec, w, 0, 0)
  s_e <- ef_cos_incidence(lat, dec, w, pi / 2, pi / 2)
  s_n <- ef_cos_incidence(lat, dec, w, pi / 2, 0)
  for (k in 1:6) {
    s <- runif(1, 0, 1.2)
    A <- runif(1, 0, 2 * pi - 1e-9)
    n <- dem_normal_components(s, A)
    # identity of the trigonometric form: absolute 1e-12
    expect_equal(ef_cos_incidence(lat, dec, w, s, A),
                 n$nx * s_e + n$ny * s_n + n$nz * s_up, tolerance = 1e-12)
  }
  # M5-06: the mean normal gives the mean cosine of incidence exactly,
  # mean(cos_i) = |n_mean| cos(incidence on the effective plane)
  sl <- c(0.1, 0.5, 0.3, 0.8)
  as <- c(0.2, 2.0, 4.0, 5.5)
  n <- dem_normal_components(sl, as)
  eff <- dem_effective_terrain(mean(n$nx), mean(n$ny), mean(n$nz))
  for (i in seq_along(dec)) {
    mean_cos <- mean(ef_cos_incidence(lat, dec[i], w[i], sl, as))
    expect_equal(mean_cos,
                 eff$normal_length *
                   ef_cos_incidence(lat, dec[i], w[i], eff$slope, eff$aspect),
                 tolerance = 1e-12)
  }
})

test_that("opposite facets give a vertical mean normal shorter than 1", {
  s <- 0.4
  n <- dem_normal_components(rep(s, 2), c(pi / 2, 3 * pi / 2))
  eff <- dem_effective_terrain(mean(n$nx), mean(n$ny), mean(n$nz))
  expect_equal(eff$slope, 0, tolerance = 1e-12)
  expect_identical(eff$aspect, 0) # undefined, set to 0 (RC-16)
  expect_equal(eff$normal_length, cos(s), tolerance = 1e-12)
  expect_true(all(is.na(unlist(dem_effective_terrain(NA, 0, 1)))))
})

# Terrain on the working grid --------------------------------------------------

test_that("a tilted plane gives its slope and aspect on the sinusoidal grid", {
  grid <- dem_test_grid()
  s <- 10 * pi / 180
  A <- 120 * pi / 180
  lon0 <- -71.98
  lat0 <- -35.92
  plane <- function(lon, lat) {
    d <- dem_test_en(lon, lat, lon0, lat0)
    500 - tan(s) * (d$e * sin(A) + d$n * cos(A))
  }
  dem <- dem_test_dem(grid, plane)
  res <- dem_terrain(dem, grid, method = "nasadem_normal_mean")
  expect_s3_class(res, "earthflux_terrain")
  tr <- res$terrain
  expect_true(terra::compareGeom(tr, grid, stopOnError = FALSE))
  expect_identical(names(tr), c("elevation", "slope", "aspect",
                                "normal_length", "valid_fraction"))
  v <- terra::values(tr)
  # Tolerance 3e-3 rad: terra measures the cell sizes of a lon/lat raster
  # geodesically row by row, while the synthetic plane uses the radii of
  # curvature at one latitude; over the ~0.05 degree window the scales
  # differ by ~1e-3 (relative), seen as up to ~1.5e-3 rad in the 90 m
  # slope and aspect.
  expect_lt(max(abs(v[, "slope"] - s)), 3e-3)
  expect_lt(max(abs(v[, "aspect"] - A)), 3e-3)
  # all 90 m normals of a plane are (almost) parallel
  expect_gt(min(v[, "normal_length"]), 1 - 1e-5)
  expect_equal(v[, "valid_fraction"], rep(1, 9))
  # Mean elevation vs the plane at the cell centre: the centre of the
  # assigned 90 m cells differs from the cell centre by at most about half
  # a 90 m cell, i.e. tan(10 deg) * 50 m ~ 9 m.
  ctr <- terra::project(terra::xyFromCell(grid, 1:9), from = terra::crs(grid),
                        to = "EPSG:4326")
  expect_lt(max(abs(v[, "elevation"] - plane(ctr[, 1], ctr[, 2]))), 9)
  expect_identical(res$provenance$method, "nasadem_normal_mean")
  expect_match(res$provenance$status[["method"]], "CANDIDATA")
  expect_identical(unname(res$units),
                   c("m", "rad", "rad", "-", "-"))
})

test_that("a symmetric ridge has a vertical mean normal and length < 1", {
  # Working grid in lon/lat: 2 x 2 cells of 30 x 30 blocks of 3", edges
  # between block centres. Ridges along the meridians, period 10 blocks
  # (3 periods per cell), heights 0, 1, ..., 5, 4, ..., 1 times dz.
  m0 <- -72 * 1200
  p0 <- -36 * 1200
  grid <- terra::rast(xmin = (3 * m0 - 1.5) / 3600,
                      xmax = (3 * m0 - 1.5 + 180) / 3600,
                      ymin = (3 * p0 - 1.5) / 3600,
                      ymax = (3 * p0 - 1.5 + 180) / 3600,
                      ncols = 2, nrows = 2, crs = "EPSG:4326")
  dz <- 30
  ridge <- function(lon, lat) {
    q <- round(lon * 1200) - m0 # block column, 0 = first inside the grid
    r <- q %% 10
    dz * pmin(r, 10 - r)
  }
  dem <- dem_test_dem(grid, ridge)
  tr <- dem_terrain(dem, grid, method = "nasadem_normal_mean")$terrain
  v <- terra::values(tr)
  # Horn's gradient is +k on 4 blocks, -k on 4 and 0 on 2 of each period,
  # k = dz / dx: the east components cancel exactly in every row.
  expect_lt(max(v[, "slope"]), 1e-9)
  dx <- dem_test_en(3 / 3600, -35.975, 0, -35.975)$e
  k <- dz / dx
  # Tolerance 1e-3: dx of terra (geodesic, per row) vs the local radius
  # used here differ by ~1e-3 (relative); d|n|/dk = -k / (1 + k^2)^1.5 / 1.25.
  expect_equal(v[, "normal_length"], rep((8 * cos(atan(k)) + 2) / 10, 4),
               tolerance = 1e-3)
  expect_true(all(v[, "normal_length"] < 0.99))
  expect_equal(v[, "elevation"], rep(dz * 2.5, 4), tolerance = 1e-12)
  expect_equal(v[, "valid_fraction"], rep(1, 4))
})

test_that("the flat option keeps the mean elevation, slope 0 and aspect 0", {
  grid <- dem_test_grid()
  const <- dem_test_dem(grid, function(lon, lat) rep(250, length(lon)))
  for (m in c("flat", "nasadem_normal_mean")) {
    v <- terra::values(dem_terrain(const, grid, method = m)$terrain)
    expect_equal(v[, "elevation"], rep(250, 9), tolerance = 1e-12)
    expect_lt(max(v[, "slope"]), 1e-12)
    expect_equal(v[, "normal_length"], rep(1, 9), tolerance = 1e-12)
    expect_equal(v[, "valid_fraction"], rep(1, 9))
  }
  # flat: exactly 0 slope and 0 aspect (RC-16), length 1 by definition
  bumpy <- dem_test_dem(grid, function(lon, lat) 100 + 50 * sin(lon * 900))
  fl <- dem_terrain(bumpy, grid, method = "flat")
  nm <- dem_terrain(bumpy, grid, method = "nasadem_normal_mean")
  vf <- terra::values(fl$terrain)
  expect_identical(vf[, "slope"], rep(0, 9))
  expect_identical(vf[, "aspect"], rep(0, 9))
  expect_identical(vf[, "normal_length"], rep(1, 9))
  # same elevation in both methods (same support: complete cells)
  expect_equal(vf[, "elevation"], terra::values(nm$terrain)[, "elevation"],
               tolerance = 1e-12)
  expect_gt(max(terra::values(nm$terrain)[, "slope"]), 0.01)
  expect_match(fl$provenance$status[["method"]], "flat-terrain")
})

test_that("missing DEM support gives valid_fraction < 1 and a warning", {
  grid <- dem_test_grid()
  x_edges <- terra::xFromCol(grid, 1:3)
  half <- terra::res(grid)[1] / 2
  R <- 6371007.181
  # NA (water or outside the tiles) west of the centre of the first column
  # of cells, and east of 150 m before the edge between columns 2 and 3
  dem <- dem_test_dem(grid, function(lon, lat) {
    x <- R * lon * pi / 180 * cos(lat * pi / 180)
    ifelse(x < x_edges[1] | x > x_edges[2] + half - 150, NA, 300)
  })
  expect_warning(res <- dem_terrain(dem, grid, method = "flat"),
                 class = "earthflux_dem_incomplete_warning")
  cnd <- tryCatch(dem_terrain(dem, grid, method = "flat"),
                  earthflux_dem_incomplete_warning = function(w) w)
  expect_identical(cnd$n_partial, 6L)
  expect_identical(cnd$n_empty, 3L)
  v <- terra::values(res$terrain)
  col <- rep(1:3, 3)
  expect_true(all(v[col == 1, "valid_fraction"] > 0.4 &
                    v[col == 1, "valid_fraction"] < 0.6))
  expect_true(all(v[col == 2, "valid_fraction"] > 0.75 &
                    v[col == 2, "valid_fraction"] < 0.9))
  expect_equal(v[col != 3, "elevation"], rep(300, 6)) # no filling
  expect_true(all(is.na(v[col == 3, c("elevation", "slope", "aspect",
                                      "normal_length")])))
  expect_equal(v[col == 3, "valid_fraction"], rep(0, 3))
})

test_that("dem_terrain() checks its inputs", {
  grid <- dem_test_grid()
  dem <- dem_test_dem(grid, function(lon, lat) rep(1, length(lon)))
  expect_error(dem_terrain(dem, grid), class = "earthflux_missing_input")
  expect_error(dem_terrain(dem, grid, method = "bilinear"),
               class = "earthflux_unknown_method")
  expect_error(dem_terrain(dem, grid, method = "Flat"),
               class = "earthflux_unknown_method")
  small <- terra::crop(dem, terra::ext(dem) - 0.01)
  expect_error(dem_terrain(small, grid, method = "flat"),
               class = "earthflux_dem_coverage_error")
  expect_error(dem_terrain(terra::aggregate(dem, 3), grid, method = "flat"),
               class = "earthflux_input_error")
  expect_error(dem_terrain(terra::project(dem, grid), grid, method = "flat"),
               class = "earthflux_input_error")
  expect_error(dem_terrain(c(dem, dem), grid, method = "flat"),
               class = "earthflux_input_error")
  expect_error(dem_terrain(dem, matrix(1:4, 2), method = "flat"),
               class = "earthflux_input_error")
})

# Tile reading -----------------------------------------------------------------

# Synthetic tiles of n = 7 pixels per side (6 pixels per degree), values
# row-major from the north edge, big-endian (User Guide V1.3, section 3).
dem_write_tile <- function(dir, tile, hgt, swb, n = 7L) {
  writeBin(as.integer(t(hgt)), file.path(dir, paste0(tile, ".hgt")),
           size = 2L, endian = "big")
  writeBin(as.integer(t(swb)), file.path(dir, paste0(tile, ".swb")),
           size = 1L)
  data.frame(tile = tile, hgt = file.path(dir, paste0(tile, ".hgt")),
             swb = file.path(dir, paste0(tile, ".swb")))
}

test_that("tiles are mosaicked on whole-degree pixel centres", {
  dir <- dem_test_dir()
  n <- 7L
  # s01w001 covers lon -1..0, lat -1..0; s01e000 covers lon 0..1
  h1 <- matrix(seq_len(n * n), n, n, byrow = TRUE)
  h2 <- h1 + 100L
  h2[, 1] <- h1[, n] # shared column (overlap at the tile edges)
  sw <- matrix(0L, n, n)
  sw[1, 2] <- 255L # one water pixel on the north edge of s01w001
  h2[2, 3] <- -32768L # one void pixel
  tiles <- rbind(dem_write_tile(dir, "s01w001", h1, sw),
                 dem_write_tile(dir, "s01e000", h2, matrix(0L, n, n)))
  # window: columns k = -6..8 (lon -1..1.33), rows j = -6..0 (lat -1..0)
  w <- list(k = c(-6, 8), j = c(-6, 0))
  keep <- dem_read(tiles, w, water = "keep", n = n)
  r <- keep$dem
  expect_equal(terra::res(r), c(1, 1) / 6)
  expect_equal(as.vector(terra::ext(r)),
               c(xmin = -6.5, xmax = 8.5, ymin = -6.5, ymax = 0.5) / 6)
  m <- terra::as.matrix(r, wide = TRUE)
  expect_equal(m[, 1:7], h1)
  expect_equal(m[, 8:13], {
    x <- h2[, 2:7]
    x[x == -32768L] <- NA
    x
  })
  # columns 14-15 (lon > 1) are outside every tile
  expect_true(all(is.na(m[, 14:15])))
  expect_equal(keep$counts[["outside_tiles"]], 14)
  expect_equal(keep$counts[["void"]], 1)
  expect_equal(keep$counts[["water_masked"]], 0)
  masked <- dem_read(tiles, w, water = "mask", n = n)
  expect_true(is.na(terra::as.matrix(masked$dem, wide = TRUE)[1, 2]))
  expect_equal(masked$counts[["water_masked"]], 1)
  expect_error(dem_read(tiles, w, n = n), class = "earthflux_missing_input")
  expect_error(dem_read(tiles, w, water = "fill", n = n),
               class = "earthflux_unknown_method")
})

test_that("tile names and windows follow the NASADEM convention", {
  expect_identical(dem_tile_name(c(-73, 0, 12), c(-36, 4, -1)),
                   c("s36w073", "n04e000", "s01e012"))
  expect_equal(unname(dem_tile_corner(c("s36w073", "n04e012"))),
               cbind(c(-73, 12), c(-36, 4)))
  expect_error(dem_tile_corner("S36W073"), class = "earthflux_input_error")
  expect_setequal(dem_tiles_in_box(c(xmin = -72.8, xmax = -71.9,
                                     ymin = -36.3, ymax = -35.6)),
                  c("s37w073", "s37w072", "s36w073", "s36w072"))
  # an edge on a whole degree does not add the neighbouring tile
  expect_identical(dem_tiles_in_box(c(xmin = -73, xmax = -72, ymin = -36,
                                      ymax = -35)), "s36w073")
  w <- dem_window(dem_test_grid())
  expect_identical((w$k + c(1, -1)) %% 3, c(0, 0))
  expect_identical((w$j + c(1, -1)) %% 3, c(0, 0))
})

# CMR search -------------------------------------------------------------------

cmr_entry <- function(tile, https = TRUE) {
  title <- paste0("NASADEM_HGT_", tile)
  base <- "https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-protected"
  list(
    id = paste0("G-", tile, "-LPCLOUD"), title = title,
    time_start = "2000-02-11T00:00:00.000Z",
    links = c(
      if (https) list(list(rel = "http://esipfed.org/ns/fedsearch/1.1/data#",
                           href = sprintf("%s/NASADEM_HGT.001/%s/%s.zip", base,
                                          title, title))),
      list(list(rel = "http://esipfed.org/ns/fedsearch/1.1/s3#",
                href = sprintf("s3://lp-prod-protected/x/%s.zip", title)),
           list(rel = "http://esipfed.org/ns/fedsearch/1.1/data#",
                href = "https://search.earthdata.nasa.gov/search/granules"),
           list(rel = "http://esipfed.org/ns/fedsearch/1.1/browse#",
                href = sprintf("https://x/%s.1.jpg", title)))
    )
  )
}

cmr_json <- function(entries) {
  jsonlite::toJSON(list(feed = list(entry = entries)), auto_unbox = TRUE)
}

test_that("CMR responses are parsed into one row per tile", {
  json <- jsonlite::fromJSON(cmr_json(list(cmr_entry("s36w073"),
                                           cmr_entry("s37w072"))),
                             simplifyVector = FALSE)
  g <- dem_parse_cmr(json)
  expect_identical(g$tile, c("s36w073", "s37w072"))
  expect_identical(g$granule_ur, c("NASADEM_HGT_s36w073",
                                   "NASADEM_HGT_s37w072"))
  expect_identical(g$concept_id, c("G-s36w073-LPCLOUD", "G-s37w072-LPCLOUD"))
  expect_match(g$url, "^https://.*/NASADEM_HGT_s3[67]w07[23]\\.zip$")
  empty <- dem_parse_cmr(list(feed = list(entry = list())))
  expect_identical(nrow(empty), 0L)
  bad <- cmr_entry("s36w073")
  bad$title <- "SRTMGL1_s36w073"
  expect_error(dem_parse_cmr(list(feed = list(entry = list(bad)))),
               class = "earthflux_download_error")
  expect_error(dem_parse_cmr(list(feed = list(
    entry = list(cmr_entry("s36w073", https = FALSE))))),
    class = "earthflux_download_error")
  expect_error(dem_parse_cmr(list(error = "x")),
               class = "earthflux_download_error")
})

test_that("dem_search() queries CMR without a token, keeps the box tiles", {
  dem_local_token("tok-SECRET-cmr")
  seen <- new.env()
  local_mocked_bindings(dem_curl = function(url, destfile, headers) {
    seen$url <- url
    seen$headers <- headers
    # CMR returns the neighbour tile s36w074 too (granule box overlap)
    writeLines(cmr_json(list(cmr_entry("s36w073"), cmr_entry("s36w074"),
                             cmr_entry("s37w073"))), destfile)
    0L
  })
  aoi <- terra::vect(terra::ext(-72.8, -72.1, -36.3, -35.6),
                     crs = "EPSG:4326")
  g <- dem_search(aoi)
  expect_null(seen$headers)
  expect_match(seen$url, paste0("^https://cmr\\.earthdata\\.nasa\\.gov/",
                                "search/granules\\.json\\?"))
  for (p in c("short_name=NASADEM_HGT", "version=001", "provider=LPCLOUD",
              "bounding_box=-72.8%2C-36.3%2C-72.1%2C-35.6")) {
    expect_match(seen$url, p, fixed = TRUE)
  }
  expect_identical(g$tile, c("s36w073", "s37w073"))
  expect_identical(attr(g, "missing_tiles"), character(0))
  expect_identical(attr(g, "query")$short_name, "NASADEM_HGT")
  # a projected AOI gives the same box
  g2 <- dem_search(terra::project(aoi, modis_sinusoidal_grid()$crs))
  expect_identical(g2$tile, g$tile)
  # outside the coverage, before any network access
  far <- terra::vect(terra::ext(10, 11, 70, 71), crs = "EPSG:4326")
  seen$url <- NULL
  expect_error(dem_search(far), class = "earthflux_dem_coverage_error")
  expect_null(seen$url)
})

test_that("an invalid CMR response is a download error", {
  local_mocked_bindings(dem_curl = function(url, destfile, headers) {
    writeLines("<html>maintenance</html>", destfile)
    0L
  })
  expect_error(dem_search(terra::ext(-73, -72, -36, -35)),
               class = "earthflux_download_error")
})

# Download and cache -----------------------------------------------------------

# A zip with the members of a synthetic NASADEM tile of n = 7 pixels.
dem_test_zip <- function(dir, tile, hgt_bytes = 98L, swb_bytes = 49L) {
  src <- file.path(dir, "src")
  dir.create(src, showWarnings = FALSE)
  writeBin(as.raw(rep(1L, hgt_bytes)), file.path(src, paste0(tile, ".hgt")))
  writeBin(as.raw(rep(0L, swb_bytes)), file.path(src, paste0(tile, ".swb")))
  writeBin(as.raw(rep(1L, swb_bytes)), file.path(src, paste0(tile, ".num")))
  zf <- file.path(dir, paste0("NASADEM_HGT_", tile, ".zip"))
  utils::zip(zf, file.path(src, paste0(tile, c(".hgt", ".swb", ".num"))),
             flags = "-j9Xq")
  zf
}

skip_if_no_zip <- function() {
  skip_if(!nzchar(Sys.which(Sys.getenv("R_ZIPCMD", "zip"))),
          "no zip program")
}

dem_test_tiles <- function(tile = "s36w073") {
  data.frame(tile = tile, url = sprintf(
    "https://data.example/NASADEM_HGT.001/NASADEM_HGT_%s/NASADEM_HGT_%s.zip",
    tile, tile))
}

test_that("a valid zip is extracted to the cache, which is then reused", {
  skip_if_no_zip()
  dir <- dem_test_dir()
  zf <- dem_test_zip(dir, "s36w073")
  dem_local_token("tok-SECRET-1")
  calls <- new.env()
  calls$n <- 0L
  local_mocked_bindings(
    dem_tile_n = function() 7L,
    dem_curl = function(url, destfile, headers) {
      calls$n <- calls$n + 1L
      calls$headers <- headers
      file.copy(zf, destfile, overwrite = TRUE)
      0L
    }
  )
  cache <- file.path(dir, "cache")
  out <- dem_download(dem_test_tiles(), cache)
  expect_identical(calls$n, 1L)
  expect_identical(calls$headers,
                   c(Authorization = "Bearer tok-SECRET-1"))
  expect_false(out$cached)
  expect_identical(out$download_date, Sys.Date())
  expect_identical(sort(list.files(file.path(cache, "dem"))),
                   c("s36w073.hgt", "s36w073.swb"))
  expect_identical(file.size(out$hgt), 98)
  # cached: no network call, even without a token
  dem_local_token(NA)
  local_mocked_bindings(dem_curl = function(...) stop("network used"))
  again <- dem_download(dem_test_tiles(), cache)
  expect_true(again$cached)
  expect_true(is.na(again$download_date))
})

test_that("an HTML page or a wrong zip leaves no cache entry", {
  skip_if_no_zip()
  dir <- dem_test_dir()
  dem_local_token("tok-SECRET-2")
  cache <- file.path(dir, "cache")
  local_mocked_bindings(
    dem_tile_n = function() 7L,
    dem_curl = function(url, destfile, headers) {
      writeLines("<!DOCTYPE html><html>Earthdata Login</html>", destfile)
      0L
    }
  )
  cnd <- expect_error(dem_download(dem_test_tiles(), cache),
                      class = "earthflux_download_error")
  expect_false(grepl("tok-SECRET-2", conditionMessage(cnd), fixed = TRUE))
  expect_identical(list.files(file.path(cache, "dem"), all.files = TRUE,
                              no.. = TRUE), character(0))
  # a zip whose members have the wrong size (e.g. another product)
  zf <- dem_test_zip(dir, "s36w073", hgt_bytes = 50L)
  local_mocked_bindings(dem_curl = function(url, destfile, headers) {
    file.copy(zf, destfile, overwrite = TRUE)
    0L
  })
  expect_error(dem_download(dem_test_tiles(), cache),
               class = "earthflux_download_error")
  expect_identical(list.files(file.path(cache, "dem"), all.files = TRUE,
                              no.. = TRUE), character(0))
})

test_that("a missing token is a credentials error before any network call", {
  dir <- dem_test_dir()
  dem_local_token(NA)
  local_mocked_bindings(dem_curl = function(...) stop("network used"))
  expect_error(dem_download(dem_test_tiles(), file.path(dir, "cache")),
               class = "earthflux_credentials_error")
  expect_error(dem_http_download("https://x/y.zip", tempfile(), auth = TRUE),
               class = "earthflux_credentials_error")
})

test_that("HTTP errors carry the status, never the token or the query", {
  dem_local_token("tok-SECRET-3")
  local_mocked_bindings(dem_curl = function(url, destfile, headers) {
    warning("cannot open URL '", url, "': HTTP status was '401 Unauthorized'")
    stop("cannot open URL '", url, "'")
  })
  cnd <- tryCatch(
    dem_http_download("https://data.example/a.zip?sig=abc", tempfile(),
                      auth = TRUE),
    earthflux_download_error = function(e) e
  )
  expect_s3_class(cnd, "earthflux_download_error")
  expect_identical(cnd$status, 401L)
  expect_identical(cnd$url, "https://data.example/a.zip")
  everything <- paste(c(conditionMessage(cnd),
                        utils::capture.output(str(unclass(cnd)))),
                      collapse = "\n")
  expect_false(grepl("tok-SECRET-3", everything, fixed = TRUE))
  expect_false(grepl("sig=abc", everything, fixed = TRUE))
  # network failure without HTTP status
  local_mocked_bindings(dem_curl = function(...) stop("Could not resolve host"))
  cnd2 <- tryCatch(dem_http_download("https://x/b.zip", tempfile(),
                                     auth = FALSE),
                   earthflux_download_error = function(e) e)
  expect_true(is.na(cnd2$status))
})

test_that("HTTP 429 is retried once, then reported", {
  calls <- new.env()
  calls$n <- 0L
  too_many <- function() {
    warning("cannot open URL: HTTP status was '429 Too Many Requests'")
    stop("cannot open URL")
  }
  local_mocked_bindings(dem_curl = function(url, destfile, headers) {
    calls$n <- calls$n + 1L
    if (calls$n == 1L) too_many()
    writeLines("ok", destfile)
    0L
  })
  f <- tempfile()
  on.exit(unlink(f), add = TRUE)
  expect_identical(dem_http_download("https://x/c", f, auth = FALSE,
                                     retry_wait = 0), f)
  expect_identical(calls$n, 2L)
  calls$n <- 0L
  local_mocked_bindings(dem_curl = function(url, destfile, headers) {
    calls$n <- calls$n + 1L
    too_many()
  })
  cnd <- tryCatch(dem_http_download("https://x/c", f, auth = FALSE,
                                    retry_wait = 0),
                  earthflux_download_error = function(e) e)
  expect_identical(cnd$status, 429L)
  expect_identical(calls$n, 2L)
})

# Composition ------------------------------------------------------------------

test_that("dem_fetch() composes search, download, read and terrain", {
  dem_local_token("tok-SECRET-4")
  grid <- dem_test_grid(nc = 2, nr = 2, lon0 = -72.5, lat0 = -35.5)
  aoi <- terra::vect(terra::ext(-72.49, -72.48, -35.52, -35.51),
                     crs = "EPSG:4326")
  local_mocked_bindings(
    dem_search = function(aoi) {
      g <- data.frame(tile = "s36w073", granule_ur = "NASADEM_HGT_s36w073",
                      concept_id = "G1", time_start = "2000-02-11",
                      url = "https://x/NASADEM_HGT_s36w073.zip")
      attr(g, "query") <- list(short_name = "NASADEM_HGT")
      attr(g, "missing_tiles") <- character(0)
      g
    },
    dem_download = function(tiles, cache_dir) {
      tiles$hgt <- "s36w073.hgt"
      tiles$swb <- "s36w073.swb"
      tiles$cached <- TRUE
      tiles$download_date <- as.Date(NA)
      tiles
    },
    dem_read = function(tiles, window, water, n = 3601L) {
      r <- terra::rast(nrows = window$j[2] - window$j[1] + 1,
                       ncols = window$k[2] - window$k[1] + 1,
                       xmin = (window$k[1] - 0.5) / 3600,
                       xmax = (window$k[2] + 0.5) / 3600,
                       ymin = (window$j[1] - 0.5) / 3600,
                       ymax = (window$j[2] + 0.5) / 3600, crs = "EPSG:4326",
                       names = "elevation", vals = 123)
      list(dem = r, counts = c(total = terra::ncell(r), outside_tiles = 0,
                               void = 0, water_masked = 0))
    }
  )
  res <- dem_fetch(aoi, grid, method = "flat", water = "mask",
                   cache_dir = tempdir())
  expect_true(terra::compareGeom(res$terrain, grid, stopOnError = FALSE))
  expect_equal(terra::values(res$terrain)[, "elevation"], rep(123, 4))
  p <- res$provenance
  expect_identical(p$product, "NASADEM_HGT")
  expect_identical(p$doi, "10.5067/MEASURES/NASADEM/NASADEM_HGT.001")
  expect_identical(p$granules$tile, "s36w073")
  expect_identical(p$water, "mask")
  expect_identical(p$method, "flat")
  expect_false(grepl("tok-SECRET-4", paste(utils::capture.output(str(p)),
                                           collapse = ""), fixed = TRUE))
  expect_error(dem_fetch(aoi, grid, method = "flat"),
               class = "earthflux_missing_input")
  expect_error(dem_fetch(aoi, grid, water = "mask"),
               class = "earthflux_missing_input")
  far <- terra::vect(terra::ext(10, 11, 10, 11), crs = "EPSG:4326")
  expect_error(dem_fetch(far, grid, "flat", "mask"),
               class = "earthflux_input_error")
  expect_identical(dem_nasadem_facts()$n, 3601L)
})

# Live smoke test (opt-in) -----------------------------------------------------

test_that("live: NASADEM terrain of the Cauquenes scene", {
  skip_on_cran()
  skip_on_ci()
  skip_if_not(identical(Sys.getenv("EARTHFLUX_LIVE_TESTS"), "true"),
              "EARTHFLUX_LIVE_TESTS is not 'true'")
  skip_if_not(nzchar(Sys.getenv("EARTHDATA_TOKEN")), "no EARTHDATA_TOKEN")
  cache <- Sys.getenv("EARTHFLUX_LIVE_CACHE", file.path(tempdir(), "live"))
  aoi <- terra::vect(terra::ext(-72.8, -71.9, -36.3, -35.6), crs = "EPSG:4326")
  grid <- terra::unwrap(cauquenes_modis)[["lst"]]
  res <- suppressWarnings(
    dem_fetch(aoi, grid, method = "nasadem_normal_mean", water = "mask",
              cache_dir = cache),
    classes = "earthflux_dem_incomplete_warning"
  )
  expect_true(terra::compareGeom(res$terrain, grid, stopOnError = FALSE))
  z <- terra::values(res$terrain[["elevation"]], mat = FALSE)
  expect_gt(min(z, na.rm = TRUE), -50)
  expect_lt(max(z, na.rm = TRUE), 1500)
  expect_true(anyNA(z)) # sea west of the coast
})
