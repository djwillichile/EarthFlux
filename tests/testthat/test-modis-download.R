# Tests for the automatic search and download of MODIS granules
#
# Specification: R/download-modis.R (header), dev/specs/modis-products.md
# sections 4, 11.4, 11.5 and 12; dev/DECISIONS.md M4-19, M4-23, M4-26,
# M5-03.
#
# No test touches the network: the only network call, modis_curl(), and the
# pause before a retry, modis_sleep(), are replaced with
# testthat::local_mocked_bindings(). The CMR responses are SYNTHETIC JSON
# written by the mock (granule names, concept ids and production stamps are
# made up in the MODIS naming convention), and the "granules" are a few
# bytes with or without the HDF4 magic number. The token used below is a
# fake string. An optional live test at the end runs only with
# EARTHFLUX_LIVE_TESTS=true (never on CRAN or CI).

# Helpers ----------------------------------------------------------------------

# A temporary directory removed when the calling test ends.
dl_test_dir <- function(env = parent.frame()) {
  d <- tempfile("modis-download-")
  dir.create(d)
  do.call(on.exit, list(substitute(unlink(d, recursive = TRUE), list(d = d)),
                        add = TRUE), envir = env)
  d
}

# Set (or unset, value = NA) an environment variable until the calling test
# ends (base R; withr is not a dependency). Restores run last-in first-out,
# so that several calls in one test restore the original value.
dl_local_envvar <- function(name, value, env = parent.frame()) {
  old <- Sys.getenv(name, unset = NA)
  if (is.na(value)) Sys.unsetenv(name) else
    do.call(Sys.setenv, stats::setNames(list(value), name))
  restore <- if (is.na(old)) substitute(Sys.unsetenv(n), list(n = name)) else
    substitute(do.call(Sys.setenv, stats::setNames(list(o), n)),
               list(o = old, n = name))
  do.call(on.exit, list(restore, add = TRUE, after = FALSE), envir = env)
  invisible(old)
}

hdf4_magic <- as.raw(c(0x0e, 0x03, 0x13, 0x01))

# A synthetic CMR granule entry (JSON feed format).
cmr_entry <- function(product, doy_tag, tile, start, end,
                      stamp = "2020001000000", links = NULL) {
  name <- sprintf("%s.%s.%s.061.%s", product, doy_tag, tile, stamp)
  base <- sprintf("https://data.example.test/lp-prod-protected/%s.061/%s/",
                  product, name)
  if (is.null(links)) {
    links <- list(
      list(rel = "http://esipfed.org/ns/fedsearch/1.1/data#",
           href = paste0(base, name, ".hdf")),
      list(rel = "http://esipfed.org/ns/fedsearch/1.1/s3#",
           href = sprintf("s3://lp-prod-protected/%s.hdf", name)),
      list(rel = "http://esipfed.org/ns/fedsearch/1.1/metadata#",
           href = paste0(base, name, ".cmr.xml")),
      list(rel = "http://esipfed.org/ns/fedsearch/1.1/data#",
           href = "https://search.example.test/granules?p=C1-LPCLOUD")
    )
  }
  list(id = sprintf("G%s-LPCLOUD", substr(stamp, 1, 9)), title = name,
       producer_granule_id = name, time_start = start, time_end = end,
       links = links)
}

cmr_json <- function(entries) {
  jsonlite::toJSON(list(feed = list(entry = entries)), auto_unbox = TRUE)
}

# Query parameters of a URL as a named character vector.
url_query <- function(url) {
  q <- strsplit(sub("^[^?]*\\?", "", url), "&", fixed = TRUE)[[1]]
  kv <- strsplit(q, "=", fixed = TRUE)
  stats::setNames(vapply(kv, function(x) utils::URLdecode(x[2]), ""),
                  vapply(kv, function(x) utils::URLdecode(x[1]), ""))
}

# The synthetic archive of 2019-02-15 (day 046): one granule per product
# and tile, composites with made-up periods that contain the day.
synthetic_archive <- function(product, tile) {
  switch(product,
    MOD11A1 = list(cmr_entry("MOD11A1", "A2019046", tile,
                             "2019-02-15T00:00:00.000Z",
                             "2019-02-15T23:59:59.000Z")),
    MYD11A1 = list(cmr_entry("MYD11A1", "A2019046", tile,
                             "2019-02-15T00:00:00.000Z",
                             "2019-02-15T23:59:59.000Z")),
    MCD43A3 = list(cmr_entry("MCD43A3", "A2019046", tile,
                             "2019-02-07T00:00:00.000Z",
                             "2019-02-22T23:59:59.999Z")),
    MOD13A2 = list(cmr_entry("MOD13A2", "A2019033", tile,
                             "2019-02-02T00:00:00.000Z",
                             "2019-02-17T23:59:59.000Z")),
    MCD15A2H = list(cmr_entry("MCD15A2H", "A2019041", tile,
                              "2019-02-10T00:00:00.000Z",
                              "2019-02-17T23:59:59.000Z"))
  )
}

# A mock of modis_curl(): answers CMR queries from `archive(product, tile)`
# and downloads with `payload` bytes; records every call in `log`.
mock_network <- function(archive = synthetic_archive, payload = hdf4_magic,
                         env = parent.frame()) {
  log <- new.env()
  log$calls <- list()
  curl <- function(url, destfile, headers = NULL) {
    log$calls[[length(log$calls) + 1L]] <- list(url = url, headers = headers,
                                                destfile = destfile)
    if (startsWith(url, "https://cmr.earthdata.nasa.gov/")) {
      q <- url_query(url)
      tile <- regmatches(q[["readable_granule_name[]"]],
                         regexpr("h[0-9]{2}v[0-9]{2}",
                                 q[["readable_granule_name[]"]]))
      writeLines(cmr_json(archive(q[["short_name"]], tile)), destfile)
    } else {
      writeBin(c(payload, as.raw(1:16)), destfile)
    }
    0L
  }
  do.call(testthat::local_mocked_bindings,
          list(modis_curl = curl, modis_sleep = function(seconds) NULL,
               .env = env))
  log
}

cauquenes_bbox <- function() {
  terra::vect(terra::ext(-72.8, -71.9, -36.3, -35.6), crs = "EPSG:4326")
}

day <- as.Date("2019-02-15")

# Tiles ------------------------------------------------------------------------

test_that("the Cauquenes AOI lies in tile h12v12", {
  t1 <- modis_tiles_for_aoi(cauquenes_bbox())
  expect_identical(t1, data.frame(h = 12L, v = 12L, tile = "h12v12"))
  # same box in a projected CRS (UTM 19S)
  utm <- terra::project(cauquenes_bbox(), "EPSG:32719")
  expect_identical(modis_tiles_for_aoi(utm)$tile, "h12v12")
  # a point and the shipped province boundary
  pt <- terra::vect(cbind(-72.3, -35.9), crs = "EPSG:4326")
  expect_identical(modis_tiles_for_aoi(pt)$tile, "h12v12")
  expect_identical(modis_tiles_for_aoi(aoi_cauquenes())$tile, "h12v12")
})

test_that("an AOI across a tile edge needs both tiles", {
  # the h12/h13 edge at 35 S is near 61.04 W (sinusoidal x = ULX + 13 side)
  a <- terra::vect(terra::ext(-61.5, -60.5, -35.5, -35), crs = "EPSG:4326")
  t2 <- modis_tiles_for_aoi(a)
  expect_identical(t2$tile, c("h12v12", "h13v12"))
  # the v12/v13 edge is the parallel 40 S (y = ULY - 13 side)
  b <- terra::vect(terra::ext(-72, -71.5, -40.3, -39.7), crs = "EPSG:4326")
  expect_identical(modis_tiles_for_aoi(b)$tile, c("h12v12", "h12v13"))
})

test_that("a box edge on a tile edge does not add the neighbouring tile", {
  e <- as.vector(modis_tile_extent(12, 12))
  inner <- terra::ext(e[["xmin"]], e[["xmax"]], e[["ymin"]], e[["ymax"]])
  expect_identical(modis_tiles_for_aoi(inner)$tile, "h12v12")
  over <- terra::ext(e[["xmin"]], e[["xmax"]] + 2000, e[["ymin"]],
                     e[["ymax"]])
  expect_identical(modis_tiles_for_aoi(over)$tile, c("h12v12", "h13v12"))
})

test_that("malformed AOIs are refused", {
  expect_error(modis_tiles_for_aoi("h12v12"), class = "earthflux_input_error")
  far <- terra::ext(1e9, 1e9 + 10, 1e9, 1e9 + 10)
  expect_error(modis_tiles_for_aoi(far), class = "earthflux_modis_grid_error")
})

# Search (CMR) -----------------------------------------------------------------

test_that("CMR responses are parsed into one granule per product and tile", {
  log <- mock_network()
  s <- modis_search(c("MOD11A1", "MCD43A3", "MOD13A2", "MCD15A2H"), day,
                    "h12v12")
  expect_identical(s$product, c("MOD11A1", "MCD43A3", "MOD13A2", "MCD15A2H"))
  expect_identical(unique(s$tile), "h12v12")
  expect_identical(s$file[1],
                   "MOD11A1.A2019046.h12v12.061.2020001000000.hdf")
  expect_true(all(grepl("^https://data\\.example\\.test/.*\\.hdf$", s$url)))
  expect_identical(s$file, basename(s$url))
  expect_identical(s$period_start,
                   as.Date(c("2019-02-15", "2019-02-07", "2019-02-02",
                             "2019-02-10")))
  expect_identical(s$period_end,
                   as.Date(c("2019-02-15", "2019-02-22", "2019-02-17",
                             "2019-02-17")))
  expect_identical(s$concept_id[1], "G202000100-LPCLOUD")
  # the queries: daily products by the name tag, composites by time range
  qs <- lapply(log$calls, function(x) url_query(x$url))
  expect_identical(qs[[1]][["readable_granule_name[]"]],
                   "MOD11A1.A2019046.h12v12.061.*")
  expect_false("temporal" %in% names(qs[[1]]))
  expect_identical(qs[[3]][["readable_granule_name[]"]],
                   "MOD13A2.A*.h12v12.061.*")
  expect_identical(qs[[3]][["temporal"]],
                   "2019-02-15T00:00:00Z,2019-02-15T23:59:59Z")
  expect_identical(qs[[1]][["provider"]], "LPCLOUD")
  expect_identical(qs[[1]][["version"]], "061")
  # CMR searches carry no credential
  expect_true(all(vapply(log$calls, function(x) is.null(x$headers), TRUE)))
  p <- attr(s, "provenance")
  expect_identical(p$provider, "LPCLOUD")
  expect_length(p$queries, 4L)
})

test_that("several tiles give one row per product and tile", {
  mock_network()
  s <- modis_search(c("MOD11A1", "MOD13A2"), day,
                    data.frame(tile = c("h12v12", "h13v12")))
  expect_identical(paste(s$product, s$tile),
                   c("MOD11A1 h12v12", "MOD11A1 h13v12", "MOD13A2 h12v12",
                     "MOD13A2 h13v12"))
})

test_that("zero or two granules stop with a classed error naming the request", {
  none <- function(product, tile) list()
  mock_network(archive = none)
  e <- expect_error(modis_search("MOD11A1", day, "h12v12"),
                    class = "earthflux_modis_granule_error")
  expect_match(conditionMessage(e), "MOD11A1, tile h12v12")
  expect_match(conditionMessage(e), "2019-02-15")
  expect_identical(e$n_granules, 0L)
  expect_identical(e$product, "MOD11A1")
  expect_identical(e$tile, "h12v12")
  expect_identical(e$date, day)
})

test_that("two granules of the same request are an error", {
  two <- function(product, tile) {
    c(synthetic_archive(product, tile),
      list(cmr_entry("MOD11A1", "A2019046", tile,
                     "2019-02-15T00:00:00.000Z", "2019-02-15T23:59:59.000Z",
                     stamp = "2021001000000")))
  }
  mock_network(archive = two)
  e <- expect_error(modis_search("MOD11A1", day, "h12v12"),
                    class = "earthflux_modis_granule_error")
  expect_identical(e$n_granules, 2L)
  expect_match(conditionMessage(e), "2 granules found")
})

test_that("entries of another day, tile or period are not used", {
  wrong <- function(product, tile) {
    switch(product,
      MOD11A1 = list(cmr_entry("MOD11A1", "A2019047", tile,
                               "2019-02-16T00:00:00.000Z",
                               "2019-02-16T23:59:59.000Z")),
      MOD13A2 = list(
        cmr_entry("MOD13A2", "A2019017", tile, "2019-01-17T00:00:00.000Z",
                  "2019-02-01T23:59:59.000Z"),
        cmr_entry("MOD13A2", "A2019033", "h13v12",
                  "2019-02-02T00:00:00.000Z", "2019-02-17T23:59:59.000Z")
      )
    )
  }
  mock_network(archive = wrong)
  expect_error(modis_search("MOD11A1", day, "h12v12"),
               class = "earthflux_modis_granule_error")
  expect_error(modis_search("MOD13A2", day, "h12v12"),
               class = "earthflux_modis_granule_error")
})

test_that("a granule without a single https .hdf data link is an error", {
  nolink <- function(product, tile) {
    list(cmr_entry("MOD11A1", "A2019046", tile, "2019-02-15T00:00:00.000Z",
                   "2019-02-15T23:59:59.000Z",
                   links = list(list(
                     rel = "http://esipfed.org/ns/fedsearch/1.1/s3#",
                     href = "s3://bucket/x.hdf"))))
  }
  mock_network(archive = nolink)
  e <- expect_error(modis_search("MOD11A1", day, "h12v12"),
                    class = "earthflux_modis_granule_error")
  expect_match(conditionMessage(e), "0 https .hdf data links")
})

test_that("malformed CMR responses and HTTP failures are classed", {
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      writeLines("<html>maintenance</html>", destfile)
      0L
    }
  )
  expect_error(modis_search("MOD11A1", day, "h12v12"),
               class = "earthflux_download_error")
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      warning("cannot open URL 'x': HTTP status was '503 Service Unavailable'")
      stop("cannot open URL")
    }
  )
  e <- expect_error(modis_search("MOD11A1", day, "h12v12"),
                    class = "earthflux_download_error")
  expect_identical(e$status, 503L)
  expect_identical(e$url, "https://cmr.earthdata.nasa.gov/search/granules.json")
  expect_false(grepl("?", e$url, fixed = TRUE))
})

test_that("HTTP 429 is retried once, then fails", {
  n <- 0L
  slept <- numeric(0)
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      n <<- n + 1L
      if (n == 1L) {
        warning("cannot open URL: HTTP status was '429 Too Many Requests'")
        stop("cannot open URL")
      }
      writeLines(cmr_json(synthetic_archive("MOD11A1", "h12v12")), destfile)
      0L
    },
    modis_sleep = function(seconds) slept <<- c(slept, seconds)
  )
  s <- modis_search("MOD11A1", day, "h12v12")
  expect_identical(nrow(s), 1L)
  expect_identical(n, 2L)
  expect_length(slept, 1L)
  n <- 0L
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      n <<- n + 1L
      warning("cannot open URL: HTTP status was '429 Too Many Requests'")
      stop("cannot open URL")
    }
  )
  e <- expect_error(modis_search("MOD11A1", day, "h12v12"),
                    class = "earthflux_download_error")
  expect_identical(e$status, 429L)
  expect_identical(n, 2L)
})

test_that("search arguments are checked", {
  expect_error(modis_search("MOD09GA", day, "h12v12"),
               class = "earthflux_modis_unsupported")
  expect_error(modis_search("MOD11A1", "2019-02-15", "h12v12"),
               class = "earthflux_input_error")
  expect_error(modis_search("MOD11A1", day, "h40v12"),
               class = "earthflux_input_error")
  expect_error(modis_search("MOD11A1", day, "h12v12", collection = "006"),
               class = "earthflux_modis_unsupported")
})

# Download (LP DAAC) -----------------------------------------------------------

test_that("each download writes its own temporary file", {
  # Two sessions fetching the same granule into a shared cache must not
  # write, validate or rename each other's partial file.
  dl_local_envvar("EARTHDATA_TOKEN", "fake-token-for-tests-0123")
  log <- mock_network()
  s <- modis_search("MOD11A1", day, "h12v12")
  cache <- dl_test_dir()
  dest <- file.path(cache, "modis", s$file)
  dir.create(dirname(dest), recursive = TRUE)
  modis_download_one(s$url, dest)
  unlink(dest)
  modis_download_one(s$url, dest)
  parts <- vapply(Filter(function(x) !startsWith(x$url, "https://cmr."),
                         log$calls), `[[`, character(1), "destfile")
  expect_length(parts, 2L)
  expect_false(identical(parts[1], parts[2]))
  expect_true(all(dirname(parts) == dirname(dest)))
  expect_true(all(endsWith(parts, ".part")))
  expect_true(all(startsWith(basename(parts), paste0(basename(dest), "."))))
  expect_true(file.exists(dest))
})

test_that("a valid HDF4 download is cached through a .part file", {
  dl_local_envvar("EARTHDATA_TOKEN", "fake-token-for-tests-0123")
  log <- mock_network()
  s <- modis_search(c("MOD11A1", "MOD13A2"), day, "h12v12")
  cache <- dl_test_dir()
  d <- modis_download(s, cache_dir = cache)
  expect_identical(d$path, file.path(cache, "modis", s$file))
  expect_true(all(file.exists(d$path)))
  expect_false(any(d$from_cache))
  expect_identical(readBin(d$path[1], "raw", n = 4L), hdf4_magic)
  expect_length(list.files(file.path(cache, "modis"), pattern = "\\.part$"),
                0L)
  dl <- Filter(function(x) !startsWith(x$url, "https://cmr."), log$calls)
  expect_length(dl, 2L)
  expect_identical(dl[[1]]$headers,
                   c(Authorization = "Bearer fake-token-for-tests-0123"))
  p <- attr(d, "provenance")
  expect_identical(p$provider, "LPCLOUD")
  expect_true(all(c("download_time", "cache_dir", "credentials") %in%
                    names(p)))
})

test_that("an existing cache entry is reused without any call", {
  dl_local_envvar("EARTHDATA_TOKEN", NA)
  mock_network()
  s <- modis_search("MOD11A1", day, "h12v12")
  cache <- dl_test_dir()
  dir.create(file.path(cache, "modis"))
  writeBin(c(hdf4_magic, as.raw(9:1)), file.path(cache, "modis", s$file))
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      stop("no network call expected")
    }
  )
  d <- modis_download(s, cache_dir = cache)
  expect_true(d$from_cache)
  expect_identical(readBin(d$path, "raw", n = 13L),
                   c(hdf4_magic, as.raw(9:1)))
})

test_that("an HTML login page is rejected and leaves no cache entry", {
  dl_local_envvar("EARTHDATA_TOKEN", "fake-token-for-tests-0123")
  login <- charToRaw("<!DOCTYPE html><html><title>Earthdata Login</title>")
  mock_network(payload = login)
  s <- modis_search("MOD11A1", day, "h12v12")
  cache <- dl_test_dir()
  e <- expect_error(modis_download(s, cache_dir = cache),
                    class = "earthflux_download_error")
  expect_match(conditionMessage(e), "not an HDF4 file")
  expect_length(list.files(file.path(cache, "modis"), all.files = TRUE,
                           no.. = TRUE), 0L)
})

test_that("a failed transfer leaves no cache entry", {
  dl_local_envvar("EARTHDATA_TOKEN", "fake-token-for-tests-0123")
  mock_network()
  s <- modis_search("MOD11A1", day, "h12v12")
  cache <- dl_test_dir()
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      writeBin(hdf4_magic, destfile) # partial file, then the transfer fails
      warning("cannot open URL: HTTP status was '500 Internal Server Error'")
      stop("download interrupted")
    }
  )
  e <- expect_error(modis_download(s, cache_dir = cache),
                    class = "earthflux_download_error")
  expect_identical(e$status, 500L)
  expect_length(list.files(file.path(cache, "modis"), all.files = TRUE,
                           no.. = TRUE), 0L)
})

test_that("a missing token is a credentials error before any request", {
  dl_local_envvar("EARTHDATA_TOKEN", NA)
  mock_network()
  s <- modis_search("MOD11A1", day, "h12v12")
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      stop("no network call expected")
    }
  )
  cache <- dl_test_dir()
  e <- expect_error(modis_download(s, cache_dir = cache),
                    class = "earthflux_credentials_error")
  expect_match(conditionMessage(e), "EARTHDATA_TOKEN")
  expect_match(conditionMessage(e), "urs.earthdata.nasa.gov", fixed = TRUE)
  dl_local_envvar("EARTHDATA_TOKEN", "")
  expect_error(modis_download(s, cache_dir = cache),
               class = "earthflux_credentials_error")
})

test_that("the token never appears in conditions, results or provenance", {
  token <- "EF-FAKE-SECRET-7f3a9c"
  dl_local_envvar("EARTHDATA_TOKEN", token)
  mock_network()
  s <- modis_search("MOD11A1", day, "h12v12")
  cache <- dl_test_dir()
  # a transport layer that echoes the header in its messages
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      warning(paste("request header:", headers[["Authorization"]],
                    "HTTP status was '401 Unauthorized'"))
      stop(paste("failed with", headers[["Authorization"]]))
    }
  )
  e <- expect_error(modis_download(s, cache_dir = cache),
                    class = "earthflux_download_error")
  expect_identical(e$status, 401L)
  shown <- c(conditionMessage(e),
             unlist(lapply(unclass(e)[setdiff(names(e), "call")],
                           as.character)))
  expect_false(any(grepl(token, shown, fixed = TRUE)))
  expect_match(conditionMessage(e), "<redacted>", fixed = TRUE)
  # a login page
  testthat::local_mocked_bindings(
    modis_curl = function(url, destfile, headers = NULL) {
      writeLines("<html>login</html>", destfile)
      0L
    }
  )
  e2 <- expect_error(modis_download(s, cache_dir = cache),
                     class = "earthflux_download_error")
  expect_false(grepl(token, conditionMessage(e2), fixed = TRUE))
  # a successful download: result and provenance
  mock_network()
  d <- modis_download(s, cache_dir = cache)
  txt <- c(capture.output(str(unclass(d))),
           capture.output(str(attr(d, "provenance"))))
  expect_false(any(grepl(token, txt, fixed = TRUE)))
  expect_false(any(grepl(token, readLines(d$path, warn = FALSE),
                         fixed = TRUE, useBytes = TRUE)))
})

test_that("download arguments are checked", {
  expect_error(modis_download(data.frame()), class = "earthflux_input_error")
  bad <- data.frame(url = "https://x.test/../evil.hdf", file = "../evil.hdf",
                    stringsAsFactors = FALSE)
  expect_error(modis_download(bad, cache_dir = tempdir()),
               class = "earthflux_modis_filename_error")
})

# Composition ------------------------------------------------------------------

test_that("modis_fetch() returns the files of modis_surface_state()", {
  dl_local_envvar("EARTHDATA_TOKEN", "fake-token-for-tests-0123")
  mock_network()
  cache <- dl_test_dir()
  f <- modis_fetch(cauquenes_bbox(), day, lst_product = "MOD11A1",
                   cache_dir = cache)
  expect_s3_class(f, "earthflux_modis_fetch")
  expect_identical(names(f$files), c("lst", "albedo", "ndvi", "lai"))
  expect_true(all(vapply(f$files, inherits, TRUE,
                         what = "earthflux_modis_source")))
  expect_identical(vapply(f$files, `[[`, "", "product"),
                   c(lst = "MOD11A1", albedo = "MCD43A3", ndvi = "MOD13A2",
                     lai = "MCD15A2H"))
  expect_identical(f$files$lst$date, day)
  expect_null(f$files$lst$period)
  expect_null(f$files$albedo$period)
  expect_identical(f$files$ndvi$period, as.Date(c("2019-02-02", "2019-02-17")))
  expect_identical(f$files$lai$period, as.Date(c("2019-02-10", "2019-02-17")))
  expect_true(all(file.exists(vapply(f$files, `[[`, "", "path"))))
  expect_identical(names(f$files_by_tile), "h12v12")
  expect_identical(f$flags, list())
  p <- f$provenance
  expect_identical(p$tiles, "h12v12")
  expect_identical(p$granules$doi,
                   sprintf("10.5067/MODIS/%s.061",
                           c("MOD11A1", "MCD43A3", "MOD13A2", "MCD15A2H")))
  expect_identical(p$products[["lst"]], "MOD11A1")
  expect_false(any(grepl("fake-token", capture.output(str(unclass(f))),
                         fixed = TRUE)))
  # Aqua
  f2 <- modis_fetch(cauquenes_bbox(), day, lst_product = "MYD11A1",
                    cache_dir = cache)
  expect_identical(f2$files$lst$product, "MYD11A1")
  expect_true(all(f2$granules$from_cache[f2$granules$role != "lst"]))
})

test_that("the LST product is an explicit choice", {
  expect_error(modis_fetch(cauquenes_bbox(), day, cache_dir = tempdir()),
               class = "earthflux_missing_input")
  expect_error(modis_fetch(cauquenes_bbox(), day, lst_product = "MOD21A1D",
                           cache_dir = tempdir()),
               class = "earthflux_unknown_method")
  expect_error(modis_fetch(cauquenes_bbox(), "2019-02-15",
                           lst_product = "MOD11A1", cache_dir = tempdir()),
               class = "earthflux_input_error")
  expect_error(modis_fetch(date = day, lst_product = "MOD11A1",
                           cache_dir = tempdir()),
               class = "earthflux_missing_input")
})

test_that("an AOI over several tiles is refused unless per_tile = TRUE", {
  dl_local_envvar("EARTHDATA_TOKEN", "fake-token-for-tests-0123")
  log <- mock_network()
  a <- terra::vect(terra::ext(-61.5, -60.5, -35.5, -35), crs = "EPSG:4326")
  cache <- dl_test_dir()
  e <- expect_error(modis_fetch(a, day, lst_product = "MOD11A1",
                                cache_dir = cache),
                    class = "earthflux_method_not_implemented")
  expect_identical(e$method, "multi_tile")
  expect_match(conditionMessage(e), "h12v12, h13v12")
  expect_length(log$calls, 0L)
  f <- modis_fetch(a, day, lst_product = "MOD11A1", cache_dir = cache,
                   per_tile = TRUE)
  expect_null(f$files)
  expect_identical(names(f$files_by_tile), c("h12v12", "h13v12"))
  expect_identical(f$files_by_tile$h13v12$lst$tile, "h13v12")
  expect_identical(nrow(f$granules), 8L)
})

# Automatic choice between Terra and Aqua (M5-27) ----------------------------

# Statistics of two candidates; the values are those of the Cauquenes
# province on 2019-02-15 (Terra at 62 degrees, Aqua at 42 degrees) and
# 2019-02-14 (Terra at 15 degrees, Aqua at 47 degrees), rounded.
lst_stats <- function(valid, angle, products = c("MOD11A1", "MYD11A1")) {
  data.frame(product = products, file = paste0(products, ".hdf"),
             n_cells = 3779L, n_valid = as.integer(round(valid * 3779)),
             valid_fraction = valid, median_abs_view_angle = angle,
             n_view_angle = as.integer(round(valid * 3779)),
             stringsAsFactors = FALSE)
}

test_that("the LST product observed closer to nadir is chosen", {
  ch <- modis_choose_lst(lst_stats(c(0.967, 0.933), c(62, 42)), 0.8)
  expect_identical(ch$product, "MYD11A1")
  expect_identical(ch$method, "auto_view_angle")
  expect_identical(ch$candidates$chosen, c(FALSE, TRUE))
  expect_identical(ch$candidates$eligible, c(TRUE, TRUE))
  expect_match(ch$rule, "lowest median absolute view zenith angle")
  expect_match(ch$status, "CANDIDATA")
  ch <- modis_choose_lst(lst_stats(c(0.981, 0.985), c(15, 47)), 0.8)
  expect_identical(ch$product, "MOD11A1")
  # a near-nadir candidate below the minimum coverage is not chosen
  ch <- modis_choose_lst(lst_stats(c(0.70, 0.95), c(5, 50)), 0.8)
  expect_identical(ch$product, "MYD11A1")
  expect_identical(ch$candidates$eligible, c(FALSE, TRUE))
  # ties go to the first candidate (Terra)
  expect_identical(modis_choose_lst(lst_stats(c(0.9, 0.9), c(20, 20)),
                                    0.8)$product, "MOD11A1")
  # no candidate reaches the coverage: the larger coverage, with a warning
  w <- expect_warning(ch <- modis_choose_lst(lst_stats(c(0.3, 0.6),
                                                       c(10, 50)), 0.8),
                      class = "earthflux_lst_choice_warning")
  expect_identical(ch$product, "MYD11A1")
  expect_identical(w$product, "MYD11A1")
  expect_match(ch$rule, "no candidate reached")
  # no valid LST at all: the coverage rule still gives a product
  expect_warning(ch <- modis_choose_lst(lst_stats(c(0, 0), c(NA, NA)), 0.8),
                 class = "earthflux_lst_choice_warning")
  expect_identical(ch$product, "MOD11A1")
  expect_error(modis_choose_lst(lst_stats(c(0.9, 0.9), c(1, 2)), 0),
               class = "earthflux_input_error")
  expect_error(modis_choose_lst(data.frame(), 0.8),
               class = "earthflux_input_error")
})

test_that("view statistics of an LST source are counted over the AOI", {
  dir <- ss_dir()
  src <- ss_scene(dir)$lst
  # synthetic scene: cell 2 is fill; angles 10 degrees except 50 (cell 6)
  # and 40 (cell 12)
  s <- modis_lst_view_stats(src, NULL)
  expect_identical(s$product, "MOD11A1")
  expect_identical(c(s$n_cells, s$n_valid, s$n_view_angle), c(12L, 11L, 11L))
  expect_equal(s$valid_fraction, 11 / 12)
  expect_identical(s$median_abs_view_angle, 10)
  # a polygon touching the three cells of the last column (4, 8, 12)
  g <- terra::rast(src$path[["LST_Day_1km"]])
  e <- terra::ext(g)
  res <- terra::res(g)[1]
  poly <- terra::vect(terra::ext(e$xmax - 0.5 * res, e$xmax - 0.2 * res,
                                 e$ymin + 0.1 * res, e$ymax - 0.1 * res),
                      crs = terra::crs(g))
  s2 <- modis_lst_view_stats(src, poly)
  expect_identical(c(s2$n_cells, s2$n_valid), c(3L, 3L))
  expect_identical(s2$median_abs_view_angle, 10)
  # the same files declared as Aqua
  aqua <- modis_source(src$path, product = "MYD11A1", date = src$date,
                       scaled = FALSE)
  expect_identical(modis_lst_view_stats(aqua, NULL)$product, "MYD11A1")
  expect_error(modis_lst_view_stats(ss_scene(dir)$albedo, NULL),
               class = "earthflux_input_error")
})

test_that("modis_fetch() chooses between Terra and Aqua by the view angle", {
  dl_local_envvar("EARTHDATA_TOKEN", "fake-token-for-tests-0123")
  log <- mock_network()
  seen <- new.env()
  # the synthetic granules are not HDF files: the statistics are mocked
  testthat::local_mocked_bindings(
    modis_lst_view_stats = function(src, aoi) {
      seen$products <- c(seen$products, src$product)
      st <- lst_stats(c(0.967, 0.933), c(62, 42))
      st[st$product == src$product, ]
    }
  )
  cache <- dl_test_dir()
  f <- modis_fetch(cauquenes_bbox(), day, lst_product = "auto_view_angle",
                   cache_dir = cache, min_lst_coverage = 0.8)
  expect_identical(seen$products, c("MOD11A1", "MYD11A1"))
  expect_identical(f$lst_product, "MYD11A1")
  expect_identical(f$files$lst$product, "MYD11A1")
  expect_identical(sort(f$granules$product),
                   sort(c("MYD11A1", "MCD43A3", "MOD13A2", "MCD15A2H")))
  expect_identical(f$provenance$products[["lst"]], "MYD11A1")
  ch <- f$provenance$lst_choice
  expect_identical(ch$product, "MYD11A1")
  expect_identical(ch$min_lst_coverage, 0.8)
  expect_identical(ch$candidates$product, c("MOD11A1", "MYD11A1"))
  expect_identical(ch$candidates$median_abs_view_angle, c(62, 42))
  expect_true(all(startsWith(ch$candidates$granule_id,
                             ch$candidates$product)))
  expect_true(all(grepl("^G[0-9]+-LPCLOUD$", ch$candidates$concept_id)))
  # both LST granules were searched and downloaded
  urls <- vapply(log$calls, `[[`, "", "url")
  expect_true(any(grepl("short_name=MOD11A1", urls, fixed = TRUE)))
  expect_true(any(grepl("short_name=MYD11A1", urls, fixed = TRUE)))
  expect_true(any(grepl("/MOD11A1.061/", urls, fixed = TRUE)))
  # a concrete product keeps the previous behaviour, with no choice
  f2 <- modis_fetch(cauquenes_bbox(), day, lst_product = "MOD11A1",
                    cache_dir = cache)
  expect_identical(f2$lst_product, "MOD11A1")
  expect_null(f2$provenance$lst_choice)
})

test_that("the automatic choice needs its coverage and one tile", {
  expect_error(modis_fetch(cauquenes_bbox(), day,
                           lst_product = "auto_view_angle",
                           cache_dir = tempdir()),
               class = "earthflux_missing_input")
  expect_error(modis_fetch(cauquenes_bbox(), day,
                           lst_product = "auto_view_angle",
                           cache_dir = tempdir(), min_lst_coverage = 1.5),
               class = "earthflux_input_error")
  expect_error(modis_fetch(cauquenes_bbox(), day, lst_product = "MOD11A1",
                           cache_dir = tempdir(), min_lst_coverage = 0.8),
               class = "earthflux_input_error")
  dl_local_envvar("EARTHDATA_TOKEN", "fake-token-for-tests-0123")
  log <- mock_network()
  a <- terra::vect(terra::ext(-61.5, -60.5, -35.5, -35), crs = "EPSG:4326")
  expect_error(modis_fetch(a, day, lst_product = "auto_view_angle",
                           cache_dir = tempdir(), per_tile = TRUE,
                           min_lst_coverage = 0.8),
               class = "earthflux_method_not_implemented")
  expect_length(log$calls, 0L)
})

# Live smoke test (opt-in) -----------------------------------------------------

test_that("live: Cauquenes 2019-02-15 is fetched and assembled", {
  skip_on_cran()
  skip_on_ci()
  skip_if_not(identical(Sys.getenv("EARTHFLUX_LIVE_TESTS"), "true"),
              "EARTHFLUX_LIVE_TESTS is not true")
  skip_if(!nzchar(Sys.getenv("EARTHDATA_TOKEN")), "EARTHDATA_TOKEN not set")
  skip_if_not(modis_has_hdf4(), "GDAL HDF4 driver not available")
  cache <- Sys.getenv("EARTHFLUX_LIVE_CACHE", unset = "")
  if (!nzchar(cache)) cache <- dl_test_dir()
  f <- modis_fetch(aoi_cauquenes(), day, lst_product = "MOD11A1",
                   cache_dir = cache)
  expect_identical(f$provenance$tiles, "h12v12")
  st <- modis_surface_state(
    f$files, aoi = aoi_cauquenes(),
    options = list(lst_product = "MOD11A1", albedo_method = "white_sky",
                   emissivity_method = "lai_empirical",
                   ndvi_source = "MOD13A2",
                   composite_method = c(albedo = "same_day",
                                        ndvi = "period_pixel_lag",
                                        lai = "period"),
                   resampling_method = "mean", min_valid_fraction = 1,
                   view_angle_max = 40, qa_policy = "flag", lai_nonveg = 0)
  )
  expect_s3_class(st, "earthflux_surface_state")
  # the packaged example scene was built from the same granules (M4-26)
  ex <- terra::unwrap(cauquenes_modis)
  expect_true(terra::compareGeom(st$lst, ex[["lst"]], stopOnError = FALSE))
  inside <- !is.na(terra::values(ex[["lst"]], mat = FALSE))
  for (v in c("lst", "albedo", "ndvi", "lai")) {
    expect_equal(terra::values(st[[v]], mat = FALSE)[inside],
                 terra::values(ex[[v]], mat = FALSE)[inside])
  }
})
