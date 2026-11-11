# Download: MODIS granules of the surface state --------------------------------
#
# Purpose: find and download the MODIS granules that the surface state
#   (modis_surface_state(), R/modis-surface.R) needs for an area of interest
#   and a date, so that the basic level of the user API only asks for an
#   area, a date and the weather forcing (dev/ARCHITECTURE.md section 6.7;
#   dev/DECISIONS.md M5-03, building on the procedure of M4-26 and
#   data-raw/modis-example.R).
#
# Specification: dev/specs/modis-products.md sections 4 (sinusoidal grid),
#   11.4 (tiles and AOI), 11.5 (credentials and downloads) and 12 (the
#   procedure of the example scene); decisions M4-19 (one tile per source),
#   M4-23 and A-M4-5 (composite period from the granule metadata), M4-26,
#   M5-03.
#
# Implemented (all internal, `modis_` prefix):
#   modis_tiles_for_aoi()    sinusoidal tiles (h, v) under an AOI
#   modis_search()           NASA CMR granule search, one granule per
#                            product and tile
#   modis_download()         download from LP DAAC with the Earthdata token,
#                            validated cache
#   modis_fetch()            AOI + date -> the `files` of
#                            modis_surface_state() + provenance; with
#                            lst_product = "auto_view_angle", the choice
#                            between Terra and Aqua (decision M5-27)
#   modis_lst_view_stats()   valid LST coverage and median absolute view
#                            zenith angle of one LST source over the AOI
#   modis_choose_lst()       the Terra/Aqua choice from those statistics
#   Network layer (the only code that touches the network; tests replace
#   modis_curl() and modis_sleep() with testthat::local_mocked_bindings()):
#   modis_curl()             one utils::download.file() call (libcurl)
#   modis_http()             headers, token, status code, scrubbed messages
#   modis_http_retry()       one bounded retry after HTTP 429
#
# Official documentation used (consulted 2026-11-06):
#   [CMR]  NASA CMR Search API, https://cmr.earthdata.nasa.gov/search/site/
#          docs/search/api.html: "Granule Search By Parameters" (short_name,
#          version, provider; "Find granules matching either granule ur or
#          producer granule id" = readable_granule_name; "Find granules with
#          temporal": bounds inclusive by default), "Parameter Options"
#          (options[<parameter>][pattern]=true, `*` wildcard), "Paging
#          Details" (page_size, default 10, max 2000; header CMR-Hits),
#          "Moderating Client Request Traffic" (HTTP 429 with a retry-after
#          header). Granule searches need no credential.
#   [EDL]  NASA Earthdata Login, "User Token Management",
#          https://urs.earthdata.nasa.gov/documentation/for_users/user_token
#          (tokens generated in the profile page, "Generate Token", valid 60
#          days; sent as `Authorization: Bearer <user token>`).
#   [HDF4] HDF4 library sources, hdf/src/hfile_priv.h (HDFMAGIC
#          "\016\003\023\001" = 0e 03 13 01, MAGICLEN 4),
#          https://github.com/HDFGroup/hdf4; an HDF4 file starts with it.
#   The LP DAAC data URLs are the `.../data#` https links of the CMR JSON
#   entries (provider LPCLOUD); the bearer token on those URLs is the
#   procedure that built the example scene (M4-26, 2026-11-05).
#
# Credentials: the Earthdata token is read ONLY from the environment
#   variable EARTHDATA_TOKEN, inside modis_http(), and only for the LP DAAC
#   downloads; it lives in the HTTP header of the request and is never
#   returned, printed, logged, stored in the provenance, written to disk or
#   put in a condition message (messages are scrubbed of it). CMR searches
#   are sent without it.
#
# Cache: files go to <cache_dir>/modis/ (default
#   tools::R_user_dir("EarthFlux", "cache")); each download is written to
#   a per-call <file>.<random>.part file and renamed only after the HDF4 magic number is checked, so
#   an interrupted or refused download never leaves a cache entry. Valid
#   entries are reused without network access.
#
# Condition classes introduced here (all inherit `earthflux_error`):
#   earthflux_credentials_error    EARTHDATA_TOKEN missing (instructions in
#                                  the message)
#   earthflux_download_error       HTTP failure (fields `status`, `url`
#                                  without query), a response that is not
#                                  JSON (CMR) or not HDF4 (LP DAAC)
#   earthflux_modis_granule_error  CMR did not return exactly one granule of
#                                  a product, tile and date (fields
#                                  `product`, `tile`, `date`, `n_granules`)
#   earthflux_method_not_implemented is reused for AOIs that need more than
#                                  one tile in modis_fetch() (no mosaic of
#                                  the surface state, M4-19; continuity
#                                  between tiles TODO, section 11.4).
#   earthflux_lst_choice_warning   (warning) no LST candidate of the
#                                  automatic choice reached the minimum
#                                  valid coverage (fields `candidates`,
#                                  `min_lst_coverage`, `product`).
#   TODO(shared): list these classes in the catalogue of R/utils.R and in
#   dev/ARCHITECTURE.md section 3.3.

# Products ---------------------------------------------------------------------

#' MODIS products that the download supports
#'
#' The products of the surface state (`modis_surface_state()`, M4-19) and
#' how their granule for a date is found:
#' * `"day"`: daily products (MOD11A1/MYD11A1, dev/specs/modis-products.md
#'   5.1; MCD43A3, 5.6, whose file of day D is weighted to D): the granule
#'   whose name carries the date tag `AYYYYDDD` of the date (file name
#'   convention, section 4, `VERIFICADA`).
#' * `"period"`: composites (MOD13A2, 16 days, 5.5; MCD15A2H, 8 days, 5.7):
#'   the granule whose time range contains the date, found with a CMR
#'   temporal query; the period is taken from the granule metadata (the
#'   relation between the name date and the period is not stated in the
#'   specification, A-M4-5, M4-23).
#'
#' @return A data frame with `product`, `role` (element of the `files` of
#'   `modis_surface_state()`), `match` (`"day"` or `"period"`) and `spec`.
#' @noRd
modis_download_products <- function() {
  data.frame(
    product = c("MOD11A1", "MYD11A1", "MCD43A3", "MOD13A2", "MCD15A2H"),
    role = c("lst", "lst", "albedo", "ndvi", "lai"),
    match = c("day", "day", "day", "period", "period"),
    spec = c("modis-products.md 5.1", "modis-products.md 5.1",
             "modis-products.md 5.6", "modis-products.md 5.5",
             "modis-products.md 5.7"),
    stringsAsFactors = FALSE
  )
}

# Tiles ------------------------------------------------------------------------

#' MODIS sinusoidal tiles under an area of interest
#'
#' The tiles whose extent overlaps the bounding box of the AOI in the
#' sinusoidal CRS, which is the box the readers crop
#' (`aoi_crop_extent()`, `modis_read_raw()`): a `SpatVector` in any CRS is
#' projected with `aoi_extent()` (geographic lines and polygons densified
#' every 1000 m first, so that curved edges are inside the box). Tile
#' extents come from `modis_tile_extent()` and the grid constants of
#' `modis_sinusoidal_grid()` (`DERIVADA` from `VERIFICADA` facts,
#' modis-products.md section 4). A box edge within 1e-3 of a 1 km cell of a
#' tile edge does not add the neighbouring tile (the tolerance of
#' `aoi_crop_extent()`).
#'
#' An AOI near the antimeridian or the edges of the sinusoid gives a wide
#' box (many tiles); tiles without land have no granules and fail in
#' `modis_search()`.
#'
#' @param aoi A `SpatVector` with a CRS, or a `SpatExtent` in the
#'   sinusoidal CRS of the MODIS grid.
#' @return A data frame with integer `h`, `v` and character `tile`
#'   (`"hXXvYY"`), one row per tile, ordered by `v` and `h`. Errors:
#'   `earthflux_input_error` for a malformed AOI,
#'   `earthflux_modis_grid_error` when the box lies outside the grid.
#' @noRd
modis_tiles_for_aoi <- function(aoi) {
  g <- modis_sinusoidal_grid()
  template <- terra::rast(nrows = 1, ncols = 1, xmin = g$ulx,
                          xmax = g$ulx + g$n_h * g$tile_size,
                          ymin = g$uly - g$n_v * g$tile_size, ymax = g$uly,
                          crs = g$crs)
  e <- as.vector(aoi_extent(aoi, template))
  if (any(!is.finite(e))) {
    ef_abort("The area of interest has no finite extent in the MODIS grid.",
             class = c("earthflux_modis_grid_error", "earthflux_input_error"))
  }
  eps <- 1e-3 * g$cell_1km / g$tile_size
  hx <- (e[c("xmin", "xmax")] - g$ulx) / g$tile_size
  vy <- (g$uly - e[c("ymax", "ymin")]) / g$tile_size
  h_lo <- floor(hx[[1L]] + eps)
  h_hi <- max(h_lo, ceiling(hx[[2L]] - eps) - 1)
  v_lo <- floor(vy[[1L]] + eps)
  v_hi <- max(v_lo, ceiling(vy[[2L]] - eps) - 1)
  if (h_hi < 0 || h_lo > g$n_h - 1L || v_hi < 0 || v_lo > g$n_v - 1L) {
    ef_abort("The area of interest lies outside the MODIS sinusoidal grid.",
             class = c("earthflux_modis_grid_error", "earthflux_input_error"))
  }
  hs <- seq.int(max(0L, h_lo), min(g$n_h - 1L, h_hi))
  vs <- seq.int(max(0L, v_lo), min(g$n_v - 1L, v_hi))
  out <- data.frame(h = rep(as.integer(hs), times = length(vs)),
                    v = rep(as.integer(vs), each = length(hs)))
  out$tile <- sprintf("h%02dv%02d", out$h, out$v)
  out
}

#' Check and normalise a set of tile identifiers
#'
#' @param tiles Character vector `"hXXvYY"` or a data frame with a `tile`
#'   column (`modis_tiles_for_aoi()`).
#' @return Unique character tile identifiers.
#' @noRd
modis_check_tiles <- function(tiles, call = sys.call(-1)) {
  if (is.data.frame(tiles)) tiles <- tiles$tile
  g <- modis_sinusoidal_grid()
  ok <- is.character(tiles) && length(tiles) > 0L && !anyNA(tiles) &&
    all(grepl("^h[0-9]{2}v[0-9]{2}$", tiles))
  if (ok) {
    h <- as.integer(substr(tiles, 2L, 3L))
    v <- as.integer(substr(tiles, 5L, 6L))
    ok <- all(h <= g$n_h - 1L & v <= g$n_v - 1L)
  }
  if (!ok) {
    ef_abort(
      paste0("`tiles` must be MODIS tile identifiers \"hXXvYY\" (h 00-35, ",
             "v 00-17) or the result of modis_tiles_for_aoi()."),
      class = "earthflux_input_error", call = call
    )
  }
  unique(tiles)
}

# Network layer ----------------------------------------------------------------

#' One HTTP GET to a file (the only network call of the module)
#'
#' `utils::download.file()` with the libcurl method, binary mode and a
#' timeout of at least 600 s (granules are tens of MB). Replaced in tests.
#'
#' @param url Character. URL.
#' @param destfile Character. Destination path.
#' @param headers Named character vector of HTTP headers, or `NULL`.
#' @return The value of `utils::download.file()` (0 on success); errors and
#'   warnings of libcurl propagate.
#' @noRd
modis_curl <- function(url, destfile, headers = NULL) {
  op <- options(timeout = max(600, getOption("timeout", 60)))
  on.exit(options(op), add = TRUE)
  utils::download.file(url, destfile, method = "libcurl", mode = "wb",
                       quiet = TRUE, headers = headers)
}

#' Pause before a retry (replaced in tests)
#' @noRd
modis_sleep <- function(seconds) {
  Sys.sleep(seconds)
}

#' A URL without its query string (for messages and provenance)
#' @noRd
modis_url_no_query <- function(url) {
  sub("[?#].*$", "", url)
}

#' One HTTP request to a file, with the Earthdata token when asked
#'
#' Reads the token from `Sys.getenv("EARTHDATA_TOKEN")` only when `auth` is
#' `TRUE` and passes it as `Authorization: Bearer` (header source EDL); it
#' is not returned, and any message of the request is scrubbed of it. The
#' HTTP status is read from the libcurl condition messages ("HTTP status
#' was 'NNN ...'"); it is `NA` when no status is reported (e.g. no
#' connection).
#'
#' @param url Character. URL.
#' @param dest Character. Destination path.
#' @param auth Logical. Send the Earthdata token.
#' @return A list with `ok` (logical), `status` (integer or `NA`) and
#'   `detail` (character, scrubbed message of the failure or `""`). Error
#'   `earthflux_credentials_error` when `auth` is `TRUE` and the variable
#'   is unset or empty.
#' @noRd
modis_http <- function(url, dest, auth) {
  headers <- NULL
  secret <- ""
  if (isTRUE(auth)) {
    secret <- Sys.getenv("EARTHDATA_TOKEN", unset = "")
    if (!nzchar(secret)) {
      ef_abort(
        paste0("The environment variable EARTHDATA_TOKEN is not set. ",
               "Downloading MODIS granules from NASA LP DAAC needs a NASA ",
               "Earthdata Login user token: log in at ",
               "https://urs.earthdata.nasa.gov, choose \"Generate Token\" ",
               "and set it in the environment (e.g. in your user-level ",
               ".Renviron as EARTHDATA_TOKEN=<token>, or ",
               "Sys.setenv(EARTHDATA_TOKEN = \"<token>\") in the session). ",
               "Never store it in a project file under version control."),
        class = "earthflux_credentials_error", call = NULL
      )
    }
    headers <- c(Authorization = paste("Bearer", secret))
  }
  scrub <- function(x) {
    x <- paste(x, collapse = " ")
    if (nzchar(secret)) x <- gsub(secret, "<redacted>", x, fixed = TRUE)
    x
  }
  notes <- character(0)
  res <- withCallingHandlers(
    tryCatch(modis_curl(url, dest, headers), error = function(e) e),
    warning = function(w) {
      notes <<- c(notes, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  failed <- inherits(res, "error") || !identical(as.integer(res), 0L)
  text <- c(notes, if (inherits(res, "error")) conditionMessage(res))
  m <- regmatches(text, regexpr("HTTP status was '[0-9]{3}", text))
  status <- if (length(m) > 0L) as.integer(sub(".*'", "", m[[1L]])) else
    NA_integer_
  list(ok = !failed, status = status,
       detail = if (failed) scrub(text) else "")
}

#' HTTP request with one bounded retry after HTTP 429
#'
#' CMR (and LP DAAC) may throttle a client with HTTP 429 (header source CMR,
#' "Moderating Client Request Traffic"); the retry-after header is not
#' visible through `utils::download.file()`, so the request is repeated
#' once after `wait` seconds and then fails.
#'
#' @inheritParams modis_http
#' @param what Character. What is being requested (for the message).
#' @param wait Numeric. Seconds before the retry.
#' @return `invisible(dest)`. Error `earthflux_download_error` (fields
#'   `status` and `url` without query) on failure.
#' @noRd
modis_http_retry <- function(url, dest, auth, what, wait = 10) {
  res <- modis_http(url, dest, auth)
  if (!res$ok && identical(res$status, 429L)) {
    modis_sleep(wait)
    res <- modis_http(url, dest, auth)
  }
  if (!res$ok) {
    shown <- modis_url_no_query(url)
    ef_abort(
      sprintf("Request for %s failed (%s): %s%s", what,
              if (is.na(res$status)) "no HTTP status" else
                sprintf("HTTP %d", res$status),
              shown,
              if (nzchar(res$detail)) paste0(" [", res$detail, "]") else ""),
      class = "earthflux_download_error", status = res$status, url = shown,
      call = NULL
    )
  }
  invisible(dest)
}

# Search (CMR) -----------------------------------------------------------------

#' CMR granule search endpoint and provider
#' @noRd
modis_cmr_endpoint <- function() {
  list(url = "https://cmr.earthdata.nasa.gov/search/granules.json",
       provider = "LPCLOUD")
}

#' Build a CMR granule search URL
#'
#' @param query Named character vector of query parameters.
#' @return Character URL (names and values percent-encoded).
#' @noRd
modis_cmr_url <- function(query) {
  enc <- function(x) vapply(x, utils::URLencode, character(1),
                            reserved = TRUE, USE.NAMES = FALSE)
  paste0(modis_cmr_endpoint()$url, "?",
         paste(enc(names(query)), enc(unname(query)), sep = "=",
               collapse = "&"))
}

#' Parse the entries of a CMR JSON granule response
#'
#' @param x The parsed JSON (`jsonlite::fromJSON(simplifyVector = FALSE)`).
#' @return A data frame with `granule_id` (title, the granule UR),
#'   `producer_granule_id`, `concept_id`, `time_start`, `time_end`, `url`
#'   (the single https `.hdf` data link, `NA` if none or several) and
#'   `n_links` (number of such links); zero rows for no entries. Error
#'   `earthflux_download_error` when the response is not a CMR feed.
#' @noRd
modis_cmr_entries <- function(x) {
  if (!is.list(x) || !is.list(x$feed)) {
    ef_abort("The CMR response is not a granule feed.",
             class = "earthflux_download_error", status = NA_integer_,
             url = modis_cmr_endpoint()$url, call = NULL)
  }
  entries <- x$feed$entry
  empty <- data.frame(granule_id = character(0),
                      producer_granule_id = character(0),
                      concept_id = character(0), time_start = character(0),
                      time_end = character(0), url = character(0),
                      n_links = integer(0), stringsAsFactors = FALSE)
  if (length(entries) == 0L) {
    return(empty)
  }
  str1 <- function(v) {
    if (is.null(v) || length(v) != 1L) NA_character_ else as.character(v)
  }
  rows <- lapply(entries, function(e) {
    hrefs <- vapply(e$links, function(l) {
      rel <- str1(l$rel)
      href <- str1(l$href)
      if (!is.na(rel) && grepl("/data#$", rel) && !is.na(href) &&
          startsWith(href, "https://") && grepl("\\.hdf$", href)) href else
        NA_character_
    }, character(1))
    hrefs <- unique(hrefs[!is.na(hrefs)])
    data.frame(
      granule_id = str1(e$title),
      producer_granule_id = str1(e$producer_granule_id),
      concept_id = str1(e$id),
      time_start = str1(e$time_start),
      time_end = str1(e$time_end),
      url = if (length(hrefs) == 1L) hrefs else NA_character_,
      n_links = length(hrefs),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' One CMR granule query
#'
#' @param query Named character vector of query parameters.
#' @param what Character. Description for messages.
#' @return The entries (`modis_cmr_entries()`).
#' @noRd
modis_cmr_query <- function(query, what) {
  url <- modis_cmr_url(query)
  tmp <- tempfile("cmr-", fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  modis_http_retry(url, tmp, auth = FALSE, what = what)
  parsed <- tryCatch(jsonlite::fromJSON(tmp, simplifyVector = FALSE),
                     error = function(e) NULL)
  if (is.null(parsed)) {
    ef_abort(sprintf("The CMR response for %s is not valid JSON.", what),
             class = "earthflux_download_error", status = NA_integer_,
             url = modis_cmr_endpoint()$url, call = NULL)
  }
  modis_cmr_entries(parsed)
}

#' Search NASA CMR for the MODIS granules of a date
#'
#' @description
#' One CMR granule search (header source CMR, no credential) per product
#' and tile, restricted to `short_name`, `version` (the collection) and the
#' provider `LPCLOUD`, with a `readable_granule_name` pattern:
#' * daily products (MOD11A1, MYD11A1, MCD43A3):
#'   `<product>.A<YYYYDDD>.<tile>.<collection>.*`, the file of the UTC day
#'   `date`;
#' * composites (MOD13A2, MCD15A2H): `<product>.A*.<tile>.<collection>.*`
#'   with the temporal range `date` 00:00:00Z to 23:59:59Z (bounds
#'   inclusive), keeping the granules whose period (`time_start` to
#'   `time_end` of the metadata, as calendar dates) contains `date`.
#'
#' Each entry is checked against the request through its file name
#' (`modis_parse_filename()`: product, tile, collection and, for daily
#' products, the date). Exactly one granule with exactly one https `.hdf`
#' data link must remain per product and tile; otherwise the search stops
#' with `earthflux_modis_granule_error` naming the product, tile and date
#' (never another day or composite in silence).
#'
#' @param products Character. Products among those of
#'   `modis_download_products()`.
#' @param date `Date`, length 1. UTC day of the data.
#' @param tiles Tile identifiers `"hXXvYY"` or the data frame of
#'   `modis_tiles_for_aoi()`.
#' @param collection Character. Collection (`"061"`, MP-13).
#' @return A data frame, one row per product and tile, with `product`,
#'   `tile`, `date`, `granule_id` (granule UR), `producer_granule_id`,
#'   `concept_id` (CMR), `url` (LP DAAC), `file` (base name of `url`),
#'   `period_start`, `period_end` (`Date`, from the metadata) and the raw
#'   `time_start`, `time_end`; attribute `provenance` (endpoint, provider,
#'   collection, date, search time and the query of each search).
#'   Errors: `earthflux_modis_unsupported` (product or collection),
#'   `earthflux_input_error` (arguments), `earthflux_download_error`
#'   (HTTP or response), `earthflux_modis_granule_error`.
#' @noRd
modis_search <- function(products, date, tiles, collection = "061") {
  call <- sys.call()
  known <- modis_download_products()
  if (!is.character(products) || length(products) == 0L || anyNA(products)) {
    ef_abort("`products` must be a non-empty character vector.",
             class = "earthflux_input_error", call = call)
  }
  products <- unique(products)
  bad <- setdiff(products, known$product)
  if (length(bad) > 0L) {
    ef_abort(
      sprintf(paste0("Product(s) %s cannot be downloaded; supported: %s."),
              paste0("\"", bad, "\"", collapse = ", "),
              paste(known$product, collapse = ", ")),
      class = c("earthflux_modis_unsupported", "earthflux_input_error"),
      product = bad, call = call
    )
  }
  modis_check_date(date, "date", scalar = TRUE, call = call)
  tiles <- modis_check_tiles(tiles, call = call)
  check_string(collection)
  for (p in products) modis_product_spec(p, collection)

  ep <- modis_cmr_endpoint()
  queries <- list()
  rows <- list()
  for (p in products) {
    match <- known$match[known$product == p]
    for (tile in tiles) {
      q <- c(short_name = p, version = collection, provider = ep$provider,
             "readable_granule_name[]" = if (match == "day")
               sprintf("%s.%s.%s.%s.*", p, format(date, "A%Y%j"), tile,
                       collection) else
               sprintf("%s.A*.%s.%s.*", p, tile, collection),
             "options[readable_granule_name][pattern]" = "true",
             page_size = "50")
      if (match == "period") {
        q["temporal"] <- sprintf("%sT00:00:00Z,%sT23:59:59Z", format(date),
                                 format(date))
      }
      what <- sprintf("the %s granule of tile %s for %s", p, tile,
                      format(date))
      queries[[length(queries) + 1L]] <- q
      e <- modis_cmr_query(q, what)
      rows[[length(rows) + 1L]] <- modis_select_granule(e, p, tile, date,
                                                        collection, match)
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "provenance") <- list(
    source = "NASA Common Metadata Repository (CMR) granule search",
    endpoint = ep$url,
    provider = ep$provider,
    collection = collection,
    date = format(date),
    search_time = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    queries = queries,
    documentation = paste0("https://cmr.earthdata.nasa.gov/search/site/docs/",
                           "search/api.html")
  )
  out
}

#' Select the one granule of a product, tile and date among CMR entries
#'
#' @param e Entries (`modis_cmr_entries()`).
#' @param product,tile,collection Character. The request.
#' @param date `Date`. The request.
#' @param match `"day"` or `"period"` (`modis_download_products()`).
#' @return A one-row data frame (see `modis_search()`).
#' @noRd
modis_select_granule <- function(e, product, tile, date, collection, match) {
  info <- lapply(seq_len(nrow(e)), function(i) {
    name <- if (!is.na(e$url[i])) basename(e$url[i]) else
      paste0(e$granule_id[i], ".hdf")
    tryCatch(modis_parse_filename(name), error = function(err) NULL)
  })
  start <- as.Date(substr(e$time_start, 1L, 10L), format = "%Y-%m-%d")
  end <- as.Date(substr(e$time_end, 1L, 10L), format = "%Y-%m-%d")
  keep <- vapply(seq_len(nrow(e)), function(i) {
    x <- info[[i]]
    if (is.null(x) || x$product != product || x$tile != tile ||
        x$collection != collection) {
      return(FALSE)
    }
    if (match == "day") {
      return(x$date == date)
    }
    !is.na(start[i]) && !is.na(end[i]) && start[i] <= date && date <= end[i]
  }, logical(1))
  n <- sum(keep)
  fail <- function(why) {
    ef_abort(
      sprintf(paste0("CMR search for %s, tile %s, collection %s, date %s: ",
                     "%s (exactly one granule is needed)."),
              product, tile, collection, format(date), why),
      class = "earthflux_modis_granule_error", product = product,
      tile = tile, date = date, n_granules = n, call = NULL
    )
  }
  if (n == 0L) fail("no granule found")
  if (n > 1L) {
    fail(sprintf("%d granules found (%s)", n,
                 paste(e$granule_id[keep], collapse = ", ")))
  }
  i <- which(keep)
  if (is.na(e$url[i])) {
    fail(sprintf("granule %s has %d https .hdf data links", e$granule_id[i],
                 e$n_links[i]))
  }
  data.frame(
    product = product, tile = tile, date = date,
    granule_id = e$granule_id[i],
    producer_granule_id = e$producer_granule_id[i],
    concept_id = e$concept_id[i], url = e$url[i],
    file = basename(e$url[i]),
    period_start = start[i], period_end = end[i],
    time_start = e$time_start[i], time_end = e$time_end[i],
    stringsAsFactors = FALSE
  )
}

# Download (LP DAAC) -----------------------------------------------------------

#' Does a file start with the HDF4 magic number?
#'
#' `0e 03 13 01` (header source HDF4, HDFMAGIC). A login page or an error
#' document does not.
#'
#' @param path Character. File path.
#' @return `TRUE` or `FALSE`.
#' @noRd
modis_is_hdf4 <- function(path) {
  if (!file.exists(path) || isTRUE(file.size(path) < 4)) {
    return(FALSE)
  }
  identical(readBin(path, "raw", n = 4L), as.raw(c(0x0e, 0x03, 0x13, 0x01)))
}

#' Download MODIS granules to the cache
#'
#' @description
#' Downloads each granule of `granules` (from `modis_search()`) from NASA
#' LP DAAC with the NASA Earthdata Login token of the environment variable
#' `EARTHDATA_TOKEN` (`Authorization: Bearer`, header source EDL) into
#' `<cache_dir>/modis/<file>`:
#' * a cached file that starts with the HDF4 magic number (header source
#'   HDF4) is reused without network access; any other file of that name
#'   is replaced;
#' * the download is written to a per-call `<file>.<random>.part` file,
#'   checked (download status and HDF4 magic number, which rejects the Earthdata login page that an
#'   invalid or expired token returns) and only then renamed; on any
#'   failure the `.part` file is removed and nothing is left in the cache.
#'
#' The token is never returned, stored or shown (see `modis_http()`).
#'
#' @param granules A data frame with at least `url` and `file` (the result
#'   of `modis_search()`).
#' @param cache_dir Character. Cache directory; files go to its subfolder
#'   `modis/`. Default `tools::R_user_dir("EarthFlux", "cache")`.
#' @return `granules` with the columns `path` (local file) and `from_cache`
#'   (logical), and the attribute `provenance` (that of the search, plus
#'   `download_source`, `download_time`, `cache_dir`, `credentials`).
#'   Errors: `earthflux_input_error` (arguments, file names outside the
#'   MODIS convention), `earthflux_credentials_error` (token missing, when a
#'   download is needed), `earthflux_download_error` (HTTP failure or a
#'   response that is not HDF4).
#' @noRd
modis_download <- function(granules,
                           cache_dir = tools::R_user_dir("EarthFlux",
                                                         "cache")) {
  call <- sys.call()
  if (!is.data.frame(granules) || nrow(granules) == 0L ||
      !all(c("url", "file") %in% names(granules)) ||
      !is.character(granules$url) || !is.character(granules$file) ||
      anyNA(granules$url) || anyNA(granules$file) ||
      !all(startsWith(granules$url, "https://"))) {
    ef_abort(
      paste0("`granules` must be the non-empty table of modis_search() ",
             "(https `url`, `file`)."),
      class = "earthflux_input_error", call = call
    )
  }
  for (f in granules$file) modis_parse_filename(f)
  if (any(granules$file != basename(granules$url))) {
    ef_abort("`granules$file` must be the base name of `granules$url`.",
             class = "earthflux_input_error", call = call)
  }
  check_string(cache_dir)
  dir <- file.path(cache_dir, "modis")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(dir)) {
    ef_abort(sprintf("Cannot create the cache directory \"%s\".", dir),
             class = "earthflux_input_error", call = call)
  }
  path <- file.path(dir, granules$file)
  from_cache <- logical(nrow(granules))
  for (i in seq_len(nrow(granules))) {
    if (modis_is_hdf4(path[i])) {
      from_cache[i] <- TRUE
      next
    }
    modis_download_one(granules$url[i], path[i])
  }
  prov <- attr(granules, "provenance")
  out <- granules
  out$path <- path
  out$from_cache <- from_cache
  attr(out, "provenance") <- c(
    if (is.list(prov)) prov else list(),
    list(
      download_source = "NASA LP DAAC (provider LPCLOUD)",
      download_time = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      cache_dir = normalizePath(dir, winslash = "/", mustWork = FALSE),
      credentials = paste0("NASA Earthdata Login token from the environment ",
                           "variable EARTHDATA_TOKEN (not recorded)")
    )
  )
  out
}

#' Download one granule through a `.part` file
#' @noRd
modis_download_one <- function(url, dest) {
  # A per-call temporary name: concurrent sessions fetching the same granule
  # into a shared cache never write, validate or rename each other's file.
  part <- tempfile(paste0(basename(dest), "."), tmpdir = dirname(dest),
                   fileext = ".part")
  on.exit(unlink(part), add = TRUE)
  modis_http_retry(url, part, auth = TRUE,
                   what = sprintf("granule %s", basename(dest)))
  if (!modis_is_hdf4(part)) {
    ef_abort(
      sprintf(paste0("The download of %s is not an HDF4 file (often the ",
                     "Earthdata login page: check that EARTHDATA_TOKEN is ",
                     "valid and not expired): %s"),
              basename(dest), modis_url_no_query(url)),
      class = "earthflux_download_error", status = NA_integer_,
      url = modis_url_no_query(url), call = NULL
    )
  }
  if (file.exists(dest)) unlink(dest)
  if (!file.rename(part, dest)) {
    ef_abort(sprintf("Cannot move the download of %s into the cache.",
                     basename(dest)),
             class = "earthflux_download_error", status = NA_integer_,
             url = modis_url_no_query(url), call = NULL)
  }
  invisible(dest)
}

# Choice between Terra and Aqua (M5-27) ------------------------------------------

#' Values of `lst_product` that choose the LST product automatically
#'
#' `"auto_view_angle"` (decision M5-27): download the LST granules of
#' Terra (MOD11A1) and Aqua (MYD11A1) for the date and tile and keep the
#' one observed closer to nadir over the AOI among those with enough valid
#' LST (`modis_choose_lst()`).
#'
#' @return A list with `choices` (character) and `candidates` (the LST
#'   products compared, in order of preference on ties).
#' @noRd
modis_lst_auto <- function() {
  list(choices = "auto_view_angle", candidates = c("MOD11A1", "MYD11A1"))
}

#' Cells of a grid covered by the area of interest
#'
#' A `SpatVector` covers the cells it touches (`terra::rasterize(touches =
#' TRUE)`, the rule of the example scene, M4-26, and of `earthflux()`,
#' M5-21); a `SpatExtent` (or `NULL`) covers every cell of the grid, which
#' the readers already cropped to it.
#'
#' @param aoi A `SpatVector`, a `SpatExtent` or `NULL`.
#' @param grid A `SpatRaster` (the cropped LST grid).
#' @return Logical vector in terra cell order.
#' @noRd
modis_aoi_cells <- function(aoi, grid) {
  if (!inherits(aoi, "SpatVector")) {
    return(rep(TRUE, terra::ncell(grid)))
  }
  v <- terra::project(aoi, terra::crs(grid))
  r <- terra::rasterize(v, terra::rast(grid, nlyrs = 1L), field = 1,
                        touches = TRUE, background = 0)
  terra::values(r, mat = FALSE) == 1
}

#' Valid LST coverage and view zenith angle of an LST source over the AOI
#'
#' Reads `LST_Day_1km`, `QC_Day` and `Day_view_angl` of a MOD11A1/MYD11A1
#' source on the AOI (product table, dev/specs/modis-products.md 5.1 b,
#' `VERIFICADA`: D1 p. 17, Table 9) and counts, over the cells covered by
#' the AOI (`modis_aoi_cells()`), the cells with a valid LST
#' (`modis_lst()` with `qa_policy = "flag"`: not fill, not out of range,
#' produced according to `QC_Day`) and the median of the absolute view
#' zenith angle of those cells (the sign of `Day_view_angl` is the side of
#' the swath, D1 p. 16-17).
#'
#' @param src An `earthflux_modis_source` of MOD11A1 or MYD11A1 (an HDF4
#'   file, or converted files declaring the three layers).
#' @param aoi The area of interest (see `modis_aoi_cells()`).
#' @return A one-row data frame: `product`, `file`, `n_cells`, `n_valid`,
#'   `valid_fraction` (`n_valid / n_cells`), `median_abs_view_angle`
#'   \[degrees\] (`NA` without valid cells) and `n_view_angle` (valid cells
#'   with a view angle).
#' @noRd
modis_lst_view_stats <- function(src, aoi) {
  call <- sys.call()
  if (!inherits(src, "earthflux_modis_source") ||
      !src$product %in% modis_lst_auto()$candidates) {
    ef_abort("`src` must be a modis_source() of MOD11A1 or MYD11A1.",
             class = "earthflux_input_error", call = call)
  }
  req <- c("LST_Day_1km", "QC_Day", "Day_view_angl")
  opt <- if (src$type == "hdf4") character(0) else
    setdiff(names(src$path), req)
  dn <- modis_read_source_layers(src, list(required = req, optional = opt),
                                 aoi, call)
  lst <- modis_lst(dn[["LST_Day_1km"]], dn[["QC_Day"]], src$product,
                   qa_policy = "flag", collection = src$collection)
  va <- modis_view_zenith(dn[["Day_view_angl"]], src$product,
                          collection = src$collection)
  inside <- modis_aoi_cells(aoi, dn[[1L]])
  valid <- inside & !is.na(lst$value)
  angle <- abs(va$value[valid & !is.na(va$value)])
  data.frame(
    product = src$product,
    file = paste(basename(unname(src$path)), collapse = ";"),
    n_cells = sum(inside),
    n_valid = sum(valid),
    valid_fraction = if (sum(inside) > 0L) sum(valid) / sum(inside) else 0,
    median_abs_view_angle = if (length(angle) > 0L) stats::median(angle) else
      NA_real_,
    n_view_angle = length(angle),
    stringsAsFactors = FALSE
  )
}

#' Choose the LST product observed closer to nadir
#'
#' Rule of `lst_product = "auto_view_angle"` (decision M5-27, `CANDIDATA`):
#' among the candidates whose valid LST coverage of the AOI is at least
#' `min_lst_coverage`, the one with the lowest median absolute view zenith
#' angle (ties: the first candidate, Terra). The footprint of a MODIS
#' observation grows with the view angle (dev/specs/modis-products.md 5.1
#' e), so the candidate closer to nadir has the sharper LST; the coverage
#' condition keeps a cloudier near-nadir scene from replacing a clear one.
#' When no candidate reaches the coverage, the one with the larger coverage
#' is kept and a warning of class `earthflux_lst_choice_warning` is
#' emitted.
#'
#' @param stats Data frame of `modis_lst_view_stats()` rows, one per
#'   candidate, in order of preference on ties.
#' @param min_lst_coverage Numeric in (0, 1\]: minimum fraction of AOI
#'   cells with a valid LST (no default).
#' @return A list: `method` (`"auto_view_angle"`), `product` (the choice),
#'   `rule` (the branch of the rule applied), `min_lst_coverage`,
#'   `candidates` (`stats` with the columns `eligible` and `chosen`) and
#'   `status`.
#' @noRd
modis_choose_lst <- function(stats, min_lst_coverage) {
  call <- sys.call()
  if (!is.data.frame(stats) || nrow(stats) == 0L ||
      !all(c("product", "valid_fraction", "median_abs_view_angle") %in%
           names(stats))) {
    ef_abort("`stats` must be rows of modis_lst_view_stats().",
             class = "earthflux_input_error", call = call)
  }
  check_scalar(min_lst_coverage, "min_lst_coverage", lower = 0, upper = 1,
               lower_inclusive = FALSE, call = call)
  eligible <- stats$valid_fraction >= min_lst_coverage &
    !is.na(stats$median_abs_view_angle)
  if (any(eligible)) {
    k <- which(eligible)[which.min(stats$median_abs_view_angle[eligible])]
    rule <- paste0("lowest median absolute view zenith angle among the ",
                   "candidates with a valid LST coverage of at least ",
                   "min_lst_coverage")
  } else {
    k <- which.max(stats$valid_fraction)
    rule <- paste0("no candidate reached min_lst_coverage: the candidate ",
                   "with the larger valid LST coverage")
  }
  stats$eligible <- eligible
  stats$chosen <- seq_len(nrow(stats)) == k
  rownames(stats) <- NULL
  if (!any(eligible)) {
    ef_warn(
      sprintf(paste0("No LST candidate covers %s of the area with valid ",
                     "LST (%s); %s is used."),
              format(min_lst_coverage),
              paste(sprintf("%s %.1f %%", stats$product,
                            100 * stats$valid_fraction), collapse = ", "),
              stats$product[k]),
      class = "earthflux_lst_choice_warning",
      candidates = stats, min_lst_coverage = min_lst_coverage,
      product = stats$product[k], call = call
    )
  }
  list(method = "auto_view_angle", product = stats$product[k], rule = rule,
       min_lst_coverage = min_lst_coverage, candidates = stats,
       status = "CANDIDATA (M5-27; minimum coverage without a source)")
}

# Composition ------------------------------------------------------------------

#' Fetch the MODIS files of the surface state for an AOI and a date
#'
#' @description
#' Composes `modis_tiles_for_aoi()`, `modis_search()` and
#' `modis_download()` for the four products of the surface state
#' (`modis_surface_state()`, M4-19): the LST product chosen explicitly
#' (`lst_product`, no default, MP-01/MP-02), MCD43A3 (albedo), MOD13A2
#' (NDVI, the only implemented source, MP-05) and MCD15A2H (LAI), and
#' returns the `files` argument of `modis_surface_state()`: `lst` and
#' `albedo` as `modis_source(path)`, `ndvi` and `lai` as
#' `modis_source(path, period = )` with the composite period of the granule
#' metadata (M4-23, A-M4-5), so that `"period"` and `"period_pixel_lag"`
#' can be used for them; the remaining choices (options) stay with the
#' caller.
#'
#' **One tile.** The surface state reads one tile per source and does not
#' assemble mosaics (M4-19); continuity between adjacent tiles is `TODO`
#' (modis-products.md 11.4). When the bounding box of the AOI in the
#' sinusoidal grid needs more than one tile, `modis_fetch()` stops before
#' any network access with `earthflux_method_not_implemented`, unless
#' `per_tile = TRUE`: then the granules of every tile are downloaded and
#' returned as one `files` list per tile (`files_by_tile`), and `files` is
#' `NULL` (no mosaic is made; each list can be passed to
#' `modis_surface_state()` with the part of the AOI in that tile).
#'
#' @param aoi Area of interest: `SpatVector` (any CRS) or `SpatExtent` in
#'   the sinusoidal CRS.
#' @param date `Date`, length 1. UTC day of the LST.
#' @param lst_product Character, no default: `"MOD11A1"` (Terra),
#'   `"MYD11A1"` (Aqua) or `"auto_view_angle"` (decision M5-27): the LST
#'   granules of both are downloaded, their valid LST coverage and median
#'   absolute view zenith angle over the AOI are computed
#'   (`modis_lst_view_stats()`) and the product observed closer to nadir
#'   among those with enough valid LST is kept (`modis_choose_lst()`); one
#'   tile only.
#' @param cache_dir Character. Cache directory (see `modis_download()`).
#' @param collection Character. Collection (`"061"`).
#' @param per_tile Logical. Allow AOIs over several tiles (see above).
#' @param min_lst_coverage With `lst_product = "auto_view_angle"`: numeric
#'   in (0, 1\], the minimum fraction of AOI cells with a valid LST of a
#'   candidate (no default; `CANDIDATA`, 0.8 in the presets); `NULL`
#'   otherwise.
#' @return An object of class `earthflux_modis_fetch` (`new_ef_object()`),
#'   a list with `files` (list `lst`, `albedo`, `ndvi`, `lai` of
#'   `earthflux_modis_source` objects, or `NULL` with several tiles),
#'   `files_by_tile` (one such list per tile, named by tile), `tiles` (data
#'   frame of `modis_tiles_for_aoi()`), `granules` (the table of
#'   `modis_download()` with the column `role`; with the automatic choice,
#'   only the chosen LST granule), `lst_product` (the LST product used),
#'   `flags` (empty) and
#'   `provenance` (sources, products by role, collection, date, tiles,
#'   granules with CMR concept ids and DOIs, search and download times,
#'   cache paths, licence; never the token; with the automatic choice,
#'   `lst_choice`: the result of `modis_choose_lst()`, both candidates'
#'   statistics and granules included).
#' @noRd
modis_fetch <- function(aoi, date, lst_product,
                        cache_dir = tools::R_user_dir("EarthFlux", "cache"),
                        collection = "061", per_tile = FALSE,
                        min_lst_coverage = NULL) {
  call <- sys.call()
  if (missing(aoi) || is.null(aoi)) {
    ef_abort("`aoi` must be supplied (a SpatVector or a SpatExtent).",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  if (missing(date)) {
    ef_abort("`date` must be supplied (the UTC day of the LST).",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  auto <- modis_lst_auto()
  check_method(lst_product, c(modis_lst_products()$available, auto$choices),
               arg = "lst_product", call = call)
  is_auto <- lst_product %in% auto$choices
  modis_check_date(date, "date", scalar = TRUE, call = call)
  if (!is.logical(per_tile) || length(per_tile) != 1L || is.na(per_tile)) {
    ef_abort("`per_tile` must be TRUE or FALSE.",
             class = "earthflux_input_error", call = call)
  }
  if (is_auto) {
    if (is.null(min_lst_coverage)) {
      ef_abort(
        sprintf(paste0("`lst_product = \"%s\"` needs `min_lst_coverage` ",
                       "(no default, decision M5-27)."), lst_product),
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
    check_scalar(min_lst_coverage, "min_lst_coverage", lower = 0, upper = 1,
                 lower_inclusive = FALSE, call = call)
  } else if (!is.null(min_lst_coverage)) {
    ef_abort(
      "`min_lst_coverage` is used only with `lst_product = \"auto_view_angle\"`.",
      class = "earthflux_input_error", call = call
    )
  }
  check_string(cache_dir)
  tiles <- modis_tiles_for_aoi(aoi)
  if (nrow(tiles) > 1L && !per_tile) {
    ef_abort(
      sprintf(paste0("The area of interest needs %d MODIS tiles (%s); the ",
                     "surface state reads one tile per product and tile ",
                     "mosaics are not assembled yet (M4-19; continuity ",
                     "between tiles TODO). Use per_tile = TRUE to download ",
                     "one file list per tile."),
              nrow(tiles), paste(tiles$tile, collapse = ", ")),
      class = c("earthflux_method_not_implemented",
                "earthflux_unknown_method", "earthflux_input_error"),
      method = "multi_tile", choices = "single_tile", call = call
    )
  }
  if (is_auto && nrow(tiles) > 1L) {
    ef_abort(
      sprintf(paste0("`lst_product = \"%s\"` compares the candidates over ",
                     "one tile; the area needs %d (%s)."), lst_product,
              nrow(tiles), paste(tiles$tile, collapse = ", ")),
      class = c("earthflux_method_not_implemented",
                "earthflux_unknown_method", "earthflux_input_error"),
      method = "multi_tile", choices = "single_tile", call = call
    )
  }
  others <- c(albedo = "MCD43A3", ndvi = "MOD13A2", lai = "MCD15A2H")
  lst_candidates <- if (is_auto) auto$candidates else lst_product
  missing_lst <- NULL
  if (is_auto) {
    # Each LST candidate is searched on its own: a satellite without a
    # granule for the date does not stop the choice among the others; the
    # missing candidates are recorded. The other products stay required.
    lst_found <- lapply(lst_candidates, function(p) {
      tryCatch(modis_search(p, date, tiles, collection = collection),
               earthflux_modis_granule_error = function(e) e)
    })
    is_missing <- vapply(lst_found, inherits, logical(1),
                         "earthflux_modis_granule_error")
    if (all(is_missing)) {
      stop(lst_found[[1L]])
    }
    missing_lst <- data.frame(
      product = lst_candidates[is_missing],
      reason = vapply(lst_found[is_missing], conditionMessage, character(1)),
      stringsAsFactors = FALSE
    )
    lst_candidates <- lst_candidates[!is_missing]
    rest <- modis_search(unname(others), date, tiles, collection = collection)
    parts <- c(lst_found[!is_missing], list(rest))
    found <- do.call(rbind, parts)
    pv <- attr(rest, "provenance")
    pv$queries <- do.call(c, lapply(parts, function(x)
      attr(x, "provenance")$queries))
    attr(found, "provenance") <- pv
  } else {
    found <- modis_search(c(lst_candidates, unname(others)), date, tiles,
                          collection = collection)
  }
  got <- modis_download(found, cache_dir = cache_dir)
  prov <- attr(got, "provenance")
  lst_choice <- NULL
  if (is_auto) {
    stats <- do.call(rbind, lapply(lst_candidates, function(p) {
      i <- which(got$product == p)
      cbind(modis_lst_view_stats(modis_source(got$path[i]), aoi),
            granule_id = got$granule_id[i], concept_id = got$concept_id[i],
            stringsAsFactors = FALSE)
    }))
    lst_choice <- modis_choose_lst(stats, min_lst_coverage)
    lst_choice$missing <- missing_lst
    lst_product <- lst_choice$product
    got <- got[!got$product %in% setdiff(lst_candidates, lst_product), ,
               drop = FALSE]
    rownames(got) <- NULL
  }
  roles <- c(lst = lst_product, others)
  got$role <- names(roles)[match(got$product, roles)]
  known <- modis_download_products()
  files_by_tile <- lapply(tiles$tile, function(tile) {
    out <- lapply(names(roles), function(role) {
      i <- which(got$tile == tile & got$role == role)
      composite <- known$match[known$product == roles[[role]]] == "period"
      modis_source(got$path[i],
                   period = if (composite) c(got$period_start[i],
                                             got$period_end[i]))
    })
    names(out) <- names(roles)
    out
  })
  names(files_by_tile) <- tiles$tile
  dois <- modis_product_doi()
  k <- match(paste(got$product, collection),
             paste(dois$product, dois$collection))
  table <- data.frame(
    role = got$role, product = got$product, tile = got$tile,
    granule_id = got$granule_id, concept_id = got$concept_id,
    file = got$file, url = got$url,
    period_start = format(got$period_start),
    period_end = format(got$period_end), doi = dois$doi[k],
    path = got$path, from_cache = got$from_cache, stringsAsFactors = FALSE
  )
  new_ef_object(
    list(
      files = if (length(files_by_tile) == 1L) files_by_tile[[1L]] else NULL,
      files_by_tile = files_by_tile,
      tiles = tiles,
      granules = got,
      lst_product = lst_product,
      flags = list(),
      provenance = list(
        source = paste0("NASA CMR granule search (provider LPCLOUD) and ",
                        "NASA LP DAAC download"),
        products = roles,
        collection = collection,
        date = format(date),
        tiles = tiles$tile,
        granules = table,
        search = prov[c("endpoint", "provider", "search_time", "queries",
                        "documentation")],
        download_time = prov$download_time,
        cache_dir = prov$cache_dir,
        credentials = prov$credentials,
        lst_choice = lst_choice,
        licence = paste0("MODIS data are shared openly without restriction ",
                         "(EOSDIS Data Use and Citation Guidance; ",
                         "modis-products.md 12); cite the DOI of each ",
                         "product. Citation requirements for redistribution ",
                         "TODO (modis-products.md 16)."),
        spec = paste0("dev/specs/modis-products.md 4, 11.4, 11.5, 12; ",
                      "DECISIONS.md M4-19, M4-23, M4-26, M5-03, M5-27")
      )
    ),
    "earthflux_modis_fetch"
  )
}
