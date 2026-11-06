# Elevation model and terrain on the working grid ------------------------------
#
# Purpose: automatic download of the elevation model and preparation of the
#   terrain (elevation, slope, aspect) on the 1 km working grid, decision
#   M5-06 (DECIDIDA, provisional; dev/DECISIONS.md section 1.5;
#   dev/ARCHITECTURE.md section 6.7; T-20, RC-11, MP-08). Elevation is
#   required by the chain (air pressure, Ts datum); slope and aspect only
#   matter with relief, and the flat-terrain option stays explicit.
#
# Product: NASADEM_HGT version 001 (NASA MEaSUREs, LP DAAC), DOI
#   10.5067/MEASURES/NASADEM/NASADEM_HGT.001. Facts used here are listed in
#   dem_nasadem_facts() with their sources: the NASADEM User Guide V1.3
#   (January 2025; https://lpdaac.usgs.gov/documents/2237/
#   NASADEM_User_Guide_V13.pdf, sections 3, 3.1, Tables 1-2, 5.1.1-5.1.2)
#   and the CMR collection and variable records of the product
#   (https://cmr.earthdata.nasa.gov/search/collections.umm_json?
#   short_name=NASADEM_HGT&version=001; concept C2763264762-LPCLOUD).
#
# Implemented (all internal; phase 2 of M5 decides the public API):
#   dem_search()     granules of NASADEM_HGT over an area (NASA CMR)
#   dem_download()   download, validation and cache of the tiles (LP DAAC,
#                    Earthdata token from the environment)
#   dem_read()       1 arc-second elevation mosaic in lon/lat over a window,
#                    water pixels masked or kept (explicit)
#   dem_terrain()    terrain on the working grid: "flat" or the CANDIDATA
#                    chain "nasadem_normal_mean" of M5-06
#   dem_fetch()      search + download + read + terrain
#   Auxiliaries: dem_http_download() (the only network wrapper; reads the
#   token), dem_curl() (the raw call, replaced in tests), dem_parse_cmr(),
#   dem_window(), dem_read_tile(), dem_normal_components(),
#   dem_effective_terrain().
#
# Conventions: angles in radians; aspect in the GIS convention of the core
#   (clockwise from geographic north, [0, 2 pi): 0 north, pi/2 east;
#   R/solar-geometry.R, ef_cos_incidence() and ef_solar_geometry(); decision
#   RC-02), i.e. the azimuth of the downslope direction (the direction the
#   plane faces). Elevation in metres above the EGM96 geoid (orthometric).
#
# Condition classes introduced here (subclasses of earthflux_error /
#   earthflux_warning; to be listed in R/utils.R by the integrator):
#   earthflux_credentials_error     EARTHDATA_TOKEN not set
#   earthflux_download_error        HTTP failure, invalid response or
#                                   invalid downloaded file (fields status,
#                                   url without query)
#   earthflux_dem_coverage_error    no NASADEM granule over the area, or the
#                                   DEM does not cover the grid
#                                   (+ earthflux_input_error)
#   earthflux_dem_incomplete_warning  working cells with incomplete DEM
#                                   support (valid_fraction < 1; fields
#                                   n_partial, n_empty)

# Product facts ----------------------------------------------------------------

#' Facts of the NASADEM_HGT product used by the DEM module
#'
#' Every value carries its source; values that the official documentation
#' does not state are marked `TODO` in `status`.
#'
#' - CMR: short name `NASADEM_HGT`, version `001`, provider `LPCLOUD`,
#'   collection concept `C2763264762-LPCLOUD`, DOI
#'   10.5067/MEASURES/NASADEM/NASADEM_HGT.001, coverage 56 S - 60 N, one
#'   zip file per 1 x 1 degree tile (`GetData` format HGT, mime type
#'   application/zip), horizontal datum "WGS84/EGM96", use constraints: the
#'   NASA Earthdata data use policy (CMR collection record).
#' - User Guide V1.3, section 3: flat binary files in **big-endian** byte
#'   order with 3601 rows and 3601 columns; section 3.1: name
#'   `NASADEM_HGT_n04w075.zip`, `n04w075` = south-west corner of the tile;
#'   Table 1: `hgt` = void-filled merged DEM, 2-byte signed integer, metres
#'   relative to the **EGM96 geoid**, valid range -32767 to 32767, no fill
#'   value; `swb` = updated SRTM water body data, byte, 0 land, 255 water;
#'   Table 2: `num` 0 = water; section 5.1.4: 3601 x 3601 pixels per quad
#'   "with overlap at quad edges" (pixel centres on whole degrees; the
#'   granule boxes of CMR extend half a pixel beyond the whole degrees).
#' - Members of the zip (`<tile>.hgt`, `<tile>.num`, `<tile>.swb`, tile in
#'   lower case): observed in the granule NASADEM_HGT_s36w073 (2026-11-06);
#'   not stated in the guide (status `OBSERVADA`).
#' - Ocean pixels: the guide states that SRTM version 2 set the oceans to
#'   zero elevation with the water mask (section 5.1.2); NASADEM water
#'   pixels at 0 m were observed in s36w073 but the guide does not state it
#'   for NASADEM (`TODO`).
#'
#' @param n Integer. Pixels per tile side (3601; an argument so that tests
#'   can use small synthetic tiles).
#' @return A list of facts and a named `status` vector.
#' @noRd
dem_nasadem_facts <- function(n = dem_tile_n()) {
  list(
    short_name = "NASADEM_HGT",
    version = "001",
    provider = "LPCLOUD",
    collection_concept_id = "C2763264762-LPCLOUD",
    doi = "10.5067/MEASURES/NASADEM/NASADEM_HGT.001",
    cmr_url = "https://cmr.earthdata.nasa.gov/search/granules.json",
    n = n,
    hgt_bytes = 2 * n * n,
    swb_bytes = n * n,
    swb_water = 255L,
    valid_range = c(-32767L, 32767L),
    horizontal_crs = "EPSG:4326",
    vertical_datum = "EGM96 geoid",
    units = "m",
    lat_coverage = c(-56, 60),
    license = paste0("NASA Earthdata data use policy ",
                     "(https://earthdata.nasa.gov/earth-observation-data/",
                     "data-use-policy)"),
    sources = c(
      user_guide = paste0("NASADEM User Guide V1.3 (January 2025), ",
                          "https://lpdaac.usgs.gov/documents/2237/",
                          "NASADEM_User_Guide_V13.pdf, sections 3, 3.1, ",
                          "5.1.1, 5.1.2, 5.1.4, Tables 1-2"),
      cmr = paste0("https://cmr.earthdata.nasa.gov/search/",
                   "collections.umm_json?short_name=NASADEM_HGT&version=001")
    ),
    status = c(
      cmr_parameters = "VERIFICADA (CMR collection record)",
      file_format = "VERIFICADA (User Guide 3, Table 1)",
      vertical_datum = "VERIFICADA (User Guide Table 1, 5.1.1)",
      water_mask = "VERIFICADA (User Guide Table 1)",
      zip_members = "OBSERVADA (granule s36w073, 2026-11-06)",
      ocean_elevation = "TODO (0 m observed; stated only for SRTM v2)"
    )
  )
}

#' Pixels per side of a NASADEM tile
#'
#' 3601 (User Guide V1.3, section 3). A function so that tests can replace
#' it with a small synthetic size.
#' @return Integer.
#' @noRd
dem_tile_n <- function() 3601L

#' Name of the NASADEM tile that contains a south-west corner
#'
#' @param lon,lat Numeric. Whole degrees of the south-west corner.
#' @return Character, e.g. `"s36w073"` (User Guide 3.1; lower case as in the
#'   granule names of CMR).
#' @noRd
dem_tile_name <- function(lon, lat) {
  sprintf("%s%02d%s%03d", ifelse(lat < 0, "s", "n"), as.integer(abs(lat)),
          ifelse(lon < 0, "w", "e"), as.integer(abs(lon)))
}

#' South-west corner of a NASADEM tile from its name
#'
#' @param tile Character, e.g. `"s36w073"`.
#' @return A two-column numeric matrix `lon`, `lat` (whole degrees).
#' @noRd
dem_tile_corner <- function(tile) {
  ok <- grepl("^[ns][0-9]{2}[ew][0-9]{3}$", tile)
  if (!all(ok)) {
    ef_abort(sprintf("Invalid NASADEM tile name(s): %s.",
                     paste(tile[!ok], collapse = ", ")),
             class = "earthflux_input_error")
  }
  lat <- as.numeric(substr(tile, 2L, 3L)) *
    ifelse(substr(tile, 1L, 1L) == "s", -1, 1)
  lon <- as.numeric(substr(tile, 5L, 7L)) *
    ifelse(substr(tile, 4L, 4L) == "w", -1, 1)
  cbind(lon = lon, lat = lat)
}

#' Default cache directory of EarthFlux downloads
#'
#' `tools::R_user_dir("EarthFlux", "cache")`; the DEM goes to its `dem/`
#' subfolder. Never inside the package or the working directory.
#' @return Character.
#' @noRd
dem_cache_dir <- function() tools::R_user_dir("EarthFlux", "cache")

# Network ----------------------------------------------------------------------

#' Raw HTTP download (the only call that touches the network)
#'
#' Kept minimal so that tests replace it with
#' `testthat::local_mocked_bindings()`.
#' @param url Character. URL.
#' @param destfile Character. Destination file.
#' @param headers Named character vector of HTTP headers, or `NULL`.
#' @return The status of `utils::download.file()` (0 on success); errors and
#'   warnings of `download.file()` propagate.
#' @noRd
dem_curl <- function(url, destfile, headers) {
  utils::download.file(url, destfile, method = "libcurl", mode = "wb",
                       quiet = TRUE, headers = headers)
}

#' URL without its query string
#'
#' @param url Character.
#' @return Character.
#' @noRd
dem_url_public <- function(url) sub("[?#].*$", "", url)

#' HTTP download wrapper of the DEM module
#'
#' The NASA Earthdata token is read here, and only here, from
#' `Sys.getenv("EARTHDATA_TOKEN")` when `auth = TRUE`, and passed as an
#' `Authorization: Bearer` header: it is never returned, printed, logged,
#' stored or put in a condition message. HTTP 429 gets one retry after
#' `retry_wait` seconds; any other failure (or a second 429) is an
#' `earthflux_download_error` with the HTTP status (`NA` when unknown) and
#' the URL without query. The caller validates the content of `destfile`.
#'
#' @param url Character. URL.
#' @param destfile Character. Destination file (the caller uses a `.part`
#'   name and renames it after validation).
#' @param auth Logical. Whether to send the Earthdata token.
#' @param retry_wait Numeric. Seconds before the retry of a 429 response.
#' @return `destfile`, invisibly.
#' @noRd
dem_http_download <- function(url, destfile, auth, retry_wait = 5) {
  headers <- NULL
  if (isTRUE(auth)) {
    if (!nzchar(Sys.getenv("EARTHDATA_TOKEN", unset = ""))) {
      ef_abort(
        paste0(
          "The environment variable EARTHDATA_TOKEN is not set. Generate a ",
          "NASA Earthdata Login user token at https://urs.earthdata.nasa.gov ",
          "(\"Generate Token\") and set it, e.g. in ~/.Renviron ",
          "(EARTHDATA_TOKEN=...) or with Sys.setenv(), then restart the ",
          "download."
        ),
        class = "earthflux_credentials_error"
      )
    }
    headers <- c(Authorization = paste("Bearer",
                                       Sys.getenv("EARTHDATA_TOKEN")))
  }
  public <- dem_url_public(url)
  for (attempt in 1:2) {
    status <- dem_try_download(url, destfile, headers)
    if (identical(status, 0L)) {
      return(invisible(destfile))
    }
    unlink(destfile)
    if (attempt == 1L && identical(status, 429L)) {
      Sys.sleep(retry_wait)
      next
    }
    break
  }
  ef_abort(
    sprintf("Download failed (HTTP status %s): %s",
            if (is.na(status)) "unknown" else status, public),
    class = "earthflux_download_error",
    status = status,
    url = public,
    call = NULL # the call could show a URL with query parameters
  )
}

#' One download attempt, returning an HTTP status
#'
#' @inheritParams dem_curl
#' @return `0L` on success, else the HTTP status code read from the
#'   messages of `download.file()` (`NA` when there is none). The messages
#'   themselves are discarded (they are never shown to the user).
#' @noRd
dem_try_download <- function(url, destfile, headers) {
  msgs <- character(0)
  res <- tryCatch(
    withCallingHandlers(
      dem_curl(url, destfile, headers),
      warning = function(w) {
        msgs <<- c(msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      msgs <<- c(msgs, conditionMessage(e))
      NULL
    }
  )
  if (!is.null(res) && identical(as.integer(res), 0L)) {
    return(0L)
  }
  code <- regmatches(msgs, regexpr("HTTP status was '[0-9]{3}", msgs))
  if (length(code) > 0L) {
    return(as.integer(sub("^.*'", "", code[[1L]])))
  }
  NA_integer_
}

# Granule search (NASA CMR) ----------------------------------------------------

#' Bounding box of an area in geographic coordinates
#'
#' @param x A `SpatVector` or `SpatRaster` with a CRS (projected edges are
#'   densified before projection, so that the box contains the curved
#'   edges), or a `SpatExtent` taken as longitude/latitude (degrees).
#' @return A named numeric vector `xmin`, `xmax`, `ymin`, `ymax` (degrees).
#' @noRd
dem_lonlat_box <- function(x) {
  if (inherits(x, "SpatExtent")) {
    return(as.vector(x))
  }
  if (!inherits(x, c("SpatVector", "SpatRaster"))) {
    ef_abort("`aoi` must be a SpatVector, a SpatRaster or a SpatExtent.",
             class = "earthflux_input_error")
  }
  if (!nzchar(terra::crs(x))) {
    ef_abort("`aoi` must have a coordinate reference system.",
             class = "earthflux_input_error")
  }
  if (inherits(x, "SpatRaster")) {
    x <- terra::as.polygons(terra::ext(x), crs = terra::crs(x))
  }
  if (!terra::is.lonlat(x)) {
    if (terra::geomtype(x) %in% c("lines", "polygons")) {
      e <- as.vector(terra::ext(x))
      step <- max(e[["xmax"]] - e[["xmin"]], e[["ymax"]] - e[["ymin"]]) / 200
      x <- terra::densify(x, step)
    }
    x <- terra::project(x, "EPSG:4326")
  }
  as.vector(terra::ext(x))
}

#' Search the NASADEM_HGT granules over an area (NASA CMR)
#'
#' Queries the CMR granule search
#' (`https://cmr.earthdata.nasa.gov/search/granules.json`) with
#' `short_name = NASADEM_HGT`, `version = 001`, `provider = LPCLOUD` and the
#' `bounding_box` (west, south, east, north, degrees) of `aoi`, without
#' credentials (CMR search is public). Only the tiles whose 1 x 1 degree
#' cell intersects the box are kept (the CMR granule boxes extend half a
#' pixel beyond the whole degrees, so a box edge on a whole degree would
#' otherwise also return the neighbouring tile). Ocean-only tiles do not
#' exist in the product: an area partly over the sea returns fewer tiles
#' than the box spans (recorded in the attribute `missing_tiles`).
#'
#' @param aoi A `SpatVector` or `SpatRaster` (any CRS), or a `SpatExtent`
#'   in longitude/latitude.
#' @param page_size Integer. CMR page size (at most 2000); a result that
#'   fills the page is refused (area too large for one search).
#' @return A data frame with one row per tile: `tile`, `granule_ur`,
#'   `concept_id`, `time_start`, `url` (https data link of the zip), and
#'   attributes `query` (the CMR parameters, no credentials),
#'   `expected_tiles` and `missing_tiles`.
#' @noRd
dem_search <- function(aoi, page_size = 2000L) {
  box <- dem_lonlat_box(aoi)
  f <- dem_nasadem_facts()
  if (box[["ymax"]] < f$lat_coverage[1L] ||
      box[["ymin"]] > f$lat_coverage[2L]) {
    ef_abort("The area lies outside the NASADEM coverage (56 S to 60 N).",
             class = c("earthflux_dem_coverage_error", "earthflux_input_error"))
  }
  q <- c(
    short_name = f$short_name,
    version = f$version,
    provider = f$provider,
    bounding_box = paste(format(box[c("xmin", "ymin", "xmax", "ymax")],
                                digits = 10, trim = TRUE), collapse = ","),
    page_size = as.character(page_size)
  )
  url <- paste0(f$cmr_url, "?", paste(
    names(q), vapply(q, utils::URLencode, character(1), reserved = TRUE),
    sep = "=", collapse = "&"
  ))
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  dem_http_download(url, tmp, auth = FALSE)
  json <- tryCatch(jsonlite::fromJSON(tmp, simplifyVector = FALSE),
                   error = function(e) NULL)
  if (is.null(json)) {
    ef_abort(sprintf("The CMR response is not valid JSON: %s",
                     dem_url_public(url)),
             class = "earthflux_download_error", status = NA_integer_,
             url = dem_url_public(url))
  }
  granules <- dem_parse_cmr(json)
  if (nrow(granules) >= page_size) {
    ef_abort(sprintf(paste0("CMR returned a full page (%d granules): the ",
                            "area is too large for one search."), page_size),
             class = "earthflux_input_error")
  }
  expected <- dem_tiles_in_box(box)
  granules <- granules[granules$tile %in% expected, , drop = FALSE]
  rownames(granules) <- NULL
  attr(granules, "query") <- as.list(q)
  attr(granules, "expected_tiles") <- expected
  attr(granules, "missing_tiles") <- setdiff(expected, granules$tile)
  granules
}

#' NASADEM tiles whose 1 x 1 degree cell intersects a box
#'
#' @param box Named numeric `xmin`, `xmax`, `ymin`, `ymax` (degrees).
#' @return Character vector of tile names.
#' @noRd
dem_tiles_in_box <- function(box) {
  lon <- seq(floor(box[["xmin"]]), max(floor(box[["xmin"]]),
                                       ceiling(box[["xmax"]]) - 1))
  lat <- seq(floor(box[["ymin"]]), max(floor(box[["ymin"]]),
                                       ceiling(box[["ymax"]]) - 1))
  g <- expand.grid(lon = lon, lat = lat)
  dem_tile_name(g$lon, g$lat)
}

#' Parse a CMR granule search response of NASADEM_HGT
#'
#' @param json The parsed JSON (`jsonlite::fromJSON(simplifyVector =
#'   FALSE)`) of a `granules.json` response.
#' @return A data frame (see `dem_search()`); zero rows when the feed has no
#'   entries. Entries whose title is not `NASADEM_HGT_<tile>` or without a
#'   single https data link to `NASADEM_HGT_<tile>.zip` are an
#'   `earthflux_download_error`.
#' @noRd
dem_parse_cmr <- function(json) {
  if (!is.list(json) || !is.list(json$feed)) {
    ef_abort("The CMR response has no `feed`.",
             class = "earthflux_download_error", status = NA_integer_,
             url = dem_nasadem_facts()$cmr_url)
  }
  entries <- json$feed$entry
  empty <- data.frame(tile = character(0), granule_ur = character(0),
                      concept_id = character(0), time_start = character(0),
                      url = character(0), stringsAsFactors = FALSE)
  if (length(entries) == 0L) {
    return(empty)
  }
  rows <- lapply(entries, function(e) {
    title <- if (is.null(e$title)) NA_character_ else e$title
    if (is.na(title) || !grepl("^NASADEM_HGT_[ns][0-9]{2}[ew][0-9]{3}$",
                               title)) {
      ef_abort(sprintf("Unexpected NASADEM granule name in CMR: %s.", title),
               class = "earthflux_download_error", status = NA_integer_,
               url = dem_nasadem_facts()$cmr_url)
    }
    tile <- sub("^NASADEM_HGT_", "", title)
    hrefs <- vapply(e$links, function(l) {
      if (!is.null(l$rel) && grepl("/data#$", l$rel) && !is.null(l$href) &&
          startsWith(l$href, "https://") &&
          endsWith(l$href, paste0("/", title, ".zip"))) l$href else
        NA_character_
    }, character(1))
    hrefs <- unique(hrefs[!is.na(hrefs)])
    if (length(hrefs) != 1L) {
      ef_abort(sprintf("CMR granule %s has %d https data links (one expected).",
                       title, length(hrefs)),
               class = "earthflux_download_error", status = NA_integer_,
               url = dem_nasadem_facts()$cmr_url)
    }
    data.frame(tile = tile, granule_ur = title,
               concept_id = if (is.null(e$id)) NA_character_ else e$id,
               time_start = if (is.null(e$time_start)) NA_character_ else
                 e$time_start,
               url = hrefs, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out[!duplicated(out$tile), , drop = FALSE]
}

# Download and cache -----------------------------------------------------------

#' Whether a cached NASADEM tile is complete
#'
#' @param hgt,swb Character. Paths of the `.hgt` and `.swb` files.
#' @param f Facts from `dem_nasadem_facts()`.
#' @return Logical vector.
#' @noRd
dem_cache_valid <- function(hgt, swb, f) {
  file.exists(hgt) & file.exists(swb) &
    file.size(hgt) %in% f$hgt_bytes & file.size(swb) %in% f$swb_bytes
}

#' Download and cache NASADEM_HGT tiles
#'
#' For each tile, the zip of LP DAAC is downloaded with the Earthdata token
#' (`dem_http_download()`) to a per-call
#' `<cache_dir>/dem/NASADEM_HGT_<tile>.zip.<random>.part`,
#' validated (zip magic number `PK\\x03\\x04`; members `<tile>.hgt` of
#' `2 n^2` bytes and `<tile>.swb` of `n^2` bytes), extracted to a temporary
#' folder and only then moved to `<cache_dir>/dem/<tile>.hgt` and
#' `<tile>.swb`; the zip is removed. An invalid download leaves no cache
#' entry. Tiles whose `.hgt` and `.swb` are already cached with the right
#' sizes are reused without network access.
#'
#' @param tiles A data frame from `dem_search()` (columns `tile`, `url`).
#' @param cache_dir Character. Cache root (default
#'   `tools::R_user_dir("EarthFlux", "cache")`).
#' @return `tiles` with the columns `hgt`, `swb` (paths), `cached` (logical,
#'   reused without download) and `download_date` (`Date`, `NA` when
#'   cached). Errors: `earthflux_credentials_error`,
#'   `earthflux_download_error`.
#' @noRd
dem_download <- function(tiles, cache_dir = dem_cache_dir()) {
  if (!is.data.frame(tiles) || !all(c("tile", "url") %in% names(tiles))) {
    ef_abort("`tiles` must be a data frame from dem_search().",
             class = "earthflux_input_error")
  }
  check_string(cache_dir, "cache_dir")
  f <- dem_nasadem_facts()
  dir <- file.path(cache_dir, "dem")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  tiles$hgt <- file.path(dir, paste0(tiles$tile, ".hgt"))
  tiles$swb <- file.path(dir, paste0(tiles$tile, ".swb"))
  tiles$cached <- dem_cache_valid(tiles$hgt, tiles$swb, f)
  tiles$download_date <- as.Date(rep(NA_character_, nrow(tiles)))
  for (i in which(!tiles$cached)) {
    dem_download_tile(tiles$tile[i], tiles$url[i], tiles$hgt[i],
                      tiles$swb[i], dir, f)
    tiles$download_date[i] <- Sys.Date()
  }
  tiles
}

#' Download, validate and extract one NASADEM tile
#'
#' @param tile,url Character. Tile name and data URL.
#' @param hgt,swb Character. Final cache paths.
#' @param dir Character. Cache folder.
#' @param f Facts from `dem_nasadem_facts()`.
#' @return `NULL`, invisibly.
#' @noRd
dem_download_tile <- function(tile, url, hgt, swb, dir, f) {
  # Per-call temporary names: concurrent sessions fetching the same tile
  # into a shared cache never touch each other's partial files.
  part <- tempfile(paste0("NASADEM_HGT_", tile, ".zip."), tmpdir = dir,
                   fileext = ".part")
  tmpdir <- tempfile(paste0(tile, "."), tmpdir = dir, fileext = ".part")
  on.exit(unlink(c(part, tmpdir), recursive = TRUE), add = TRUE)
  public <- dem_url_public(url)
  bad <- function(why) {
    ef_abort(sprintf("Invalid NASADEM download for tile %s (%s): %s", tile,
                     why, public),
             class = "earthflux_download_error", status = NA_integer_,
             url = public)
  }
  dem_http_download(url, part, auth = TRUE)
  magic <- if (file.exists(part)) readBin(part, "raw", n = 4L) else raw(0)
  if (!identical(magic, as.raw(c(0x50, 0x4b, 0x03, 0x04)))) {
    bad(paste0("not a zip file; check that EARTHDATA_TOKEN is valid and ",
               "not expired"))
  }
  members <- paste0(tile, c(".hgt", ".swb"))
  listing <- tryCatch(utils::unzip(part, list = TRUE), error = function(e) NULL)
  if (is.null(listing)) {
    bad("unreadable zip")
  }
  sizes <- listing$Length[match(members, listing$Name)]
  if (anyNA(sizes) || sizes[1L] != f$hgt_bytes || sizes[2L] != f$swb_bytes) {
    bad(sprintf("members %s of %s and %s bytes expected",
                paste(members, collapse = " and "), f$hgt_bytes, f$swb_bytes))
  }
  dir.create(tmpdir, showWarnings = FALSE)
  out <- tryCatch(utils::unzip(part, files = members, exdir = tmpdir,
                               junkpaths = TRUE),
                  error = function(e) character(0))
  got <- file.path(tmpdir, members)
  if (length(out) != 2L ||
      !isTRUE(all(dem_cache_valid(got[1L], got[2L], f)))) {
    bad("extraction failed")
  }
  if (!all(file.rename(got, c(hgt, swb)))) {
    unlink(c(hgt, swb))
    bad("cannot write the cache")
  }
  invisible(NULL)
}

# Reading ----------------------------------------------------------------------

#' Read a window of rows and columns of one NASADEM tile file
#'
#' Reads only the needed rows (big-endian, row-major from the north edge,
#' User Guide 3).
#'
#' @param path Character. `.hgt` or `.swb` file.
#' @param n Integer. Pixels per side.
#' @param bytes Integer. Bytes per pixel (2 for `.hgt`, 1 for `.swb`).
#' @param rows,cols Integer. First and last row and column (1-based).
#' @return An integer matrix.
#' @noRd
dem_read_tile <- function(path, n, bytes, rows, cols) {
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  nr <- rows[2L] - rows[1L] + 1L
  seek(con, where = (rows[1L] - 1) * n * bytes, origin = "start")
  v <- readBin(con, "integer", n = nr * n, size = bytes,
               signed = bytes == 2L, endian = "big")
  if (length(v) != nr * n) {
    ef_abort(sprintf("Truncated NASADEM file: %s.", basename(path)),
             class = "earthflux_download_error", status = NA_integer_,
             url = NA_character_)
  }
  m <- matrix(v, nrow = nr, ncol = n, byrow = TRUE)
  m[, cols[1L]:cols[2L], drop = FALSE]
}

#' Window of the elevation model needed by a working grid
#'
#' The longitude/latitude box of `grid` (edges densified), widened by
#' `margin` pixels of 3 arc-seconds and snapped to whole blocks of 3 x 3
#' pixels centred on multiples of 3 pixels (so that the 3 x 3 mean of
#' `dem_terrain()` gives blocks centred on multiples of 3 arc-seconds).
#'
#' @param grid A `SpatRaster` with a CRS (the working grid).
#' @param n Integer. Pixels per tile side (`n - 1` pixels per degree).
#' @param margin Integer. Margin in blocks of 3 pixels.
#' @return A list with the pixel index ranges `k` (columns, longitude
#'   index = lon x (n - 1)) and `j` (rows, latitude index), and `box`.
#' @noRd
dem_window <- function(grid, n = dem_tile_n(), margin = 3L) {
  box <- dem_lonlat_box(grid)
  s <- n - 1
  m0 <- floor(box[["xmin"]] * s / 3) - margin
  m1 <- ceiling(box[["xmax"]] * s / 3) + margin
  p0 <- floor(box[["ymin"]] * s / 3) - margin
  p1 <- ceiling(box[["ymax"]] * s / 3) + margin
  list(k = c(3 * m0 - 1, 3 * m1 + 1), j = c(3 * p0 - 1, 3 * p1 + 1),
       box = box)
}

#' Elevation mosaic of NASADEM tiles over a window
#'
#' Builds the 1 arc-second elevation raster (longitude/latitude, WGS84,
#' metres above the EGM96 geoid) over `window` from the cached tiles. Pixel
#' centres are on multiples of 1/(n - 1) degree (tiles overlap by one row
#' and column at their edges, User Guide 5.1.4; the shared pixels are read
#' from either tile). Pixels outside every tile (ocean-only tiles, which
#' the product does not include) are `NA`. Values outside the documented
#' valid range (-32768) are voids and become `NA` (the merged DEM is
#' void-filled, User Guide Table 1, so none are expected).
#'
#' @param tiles A data frame from `dem_download()` (columns `tile`, `hgt`,
#'   `swb`).
#' @param window A list from `dem_window()`.
#' @param water Character, no default: `"mask"` sets the water pixels of
#'   the SRTM water body layer (`swb` = 255: ocean, lakes and rivers alike,
#'   which the layer does not distinguish) to `NA`; `"keep"` keeps them at
#'   the elevation of the file (ocean 0 m as observed, lakes and rivers
#'   flattened; User Guide 5.1.2).
#' @param n Integer. Pixels per tile side.
#' @return A list with `dem` (`SpatRaster`, one layer `elevation`) and
#'   `counts` (pixels: `total`, `outside_tiles`, `void`, `water_masked`).
#' @noRd
dem_read <- function(tiles, window, water, n = dem_tile_n()) {
  check_method(water, c("mask", "keep"), arg = "water")
  f <- dem_nasadem_facts(n)
  s <- n - 1
  k <- window$k
  j <- window$j
  nr <- j[2L] - j[1L] + 1
  nc <- k[2L] - k[1L] + 1
  z <- matrix(NA_integer_, nrow = nr, ncol = nc)
  wet <- matrix(FALSE, nrow = nr, ncol = nc)
  corner <- dem_tile_corner(tiles$tile)
  for (i in seq_len(nrow(tiles))) {
    k_t <- corner[i, "lon"] * s
    j_t <- corner[i, "lat"] * s
    kk <- c(max(k[1L], k_t), min(k[2L], k_t + s))
    jj <- c(max(j[1L], j_t), min(j[2L], j_t + s))
    if (kk[1L] > kk[2L] || jj[1L] > jj[2L]) {
      next
    }
    rows <- as.integer(c(j_t + s - jj[2L], j_t + s - jj[1L]) + 1)
    cols <- as.integer(kk - k_t + 1)
    out_r <- as.integer(j[2L] - jj[2L] + 1):as.integer(j[2L] - jj[1L] + 1)
    out_c <- as.integer(kk[1L] - k[1L] + 1):as.integer(kk[2L] - k[1L] + 1)
    z[out_r, out_c] <- dem_read_tile(tiles$hgt[i], n, 2L, rows, cols)
    wet[out_r, out_c] <- dem_read_tile(tiles$swb[i], n, 1L, rows, cols) ==
      f$swb_water
  }
  outside <- is.na(z)
  void <- !outside & (z < f$valid_range[1L] | z > f$valid_range[2L])
  z[void] <- NA_integer_
  masked <- 0
  if (water == "mask") {
    masked <- sum(wet & !is.na(z))
    z[wet] <- NA_integer_
  }
  r <- terra::rast(nrows = nr, ncols = nc,
                   xmin = (k[1L] - 0.5) / s, xmax = (k[2L] + 0.5) / s,
                   ymin = (j[1L] - 0.5) / s, ymax = (j[2L] + 0.5) / s,
                   crs = f$horizontal_crs, names = "elevation")
  terra::values(r) <- as.numeric(t(z))
  list(dem = r,
       counts = c(total = nr * nc, outside_tiles = sum(outside),
                  void = sum(void), water_masked = masked))
}

# Terrain ----------------------------------------------------------------------

#' Unit normal vector of a plane from its slope and aspect
#'
#' In the local east-north-up frame, a plane of slope \eqn{s} whose
#' downslope direction has azimuth \eqn{A} (GIS aspect, clockwise from
#' north) has the upward unit normal
#' \deqn{n = (\sin s \sin A, \sin s \cos A, \cos s).}
#' Example: a plane falling to the east (\eqn{A = \pi/2}) has \eqn{n_x > 0}.
#'
#' @param slope,aspect Numeric \[rad\].
#' @return A list `nx` (east), `ny` (north), `nz` (up) \[-\].
#' @noRd
dem_normal_components <- function(slope, aspect) {
  list(nx = sin(slope) * sin(aspect), ny = sin(slope) * cos(aspect),
       nz = cos(slope) + 0 * aspect)
}

#' Effective slope and aspect from a mean normal vector
#'
#' With the mean components \eqn{\bar n = (\bar n_x, \bar n_y, \bar n_z)}
#' and \eqn{L = |\bar n|} (\eqn{\le 1}):
#' \deqn{s_{eff} = \arccos(\bar n_z / L), \qquad
#'   A_{eff} = \mathrm{atan2}(\bar n_x, \bar n_y) \bmod 2\pi.}
#' The aspect follows the GIS convention of the core (clockwise from north,
#' \[0, 2 pi)). Where the horizontal components vanish (below 1e-12 of
#' \eqn{L}: round-off) the slope is set to 0 and the aspect, undefined, to
#' 0 (route proposed for RC-16: the
#' DEM wrapper assigns the value; every aspect term of the incidence angle
#' is multiplied by \eqn{\sin s = 0}).
#'
#' @param nx,ny,nz Numeric. Mean components \[-\].
#' @return A list `slope` \[rad\] in \[0, pi/2), `aspect` \[rad\] in
#'   \[0, 2 pi), `normal_length` \[-\].
#' @noRd
dem_effective_terrain <- function(nx, ny, nz) {
  len <- sqrt(nx^2 + ny^2 + nz^2)
  slope <- acos(pmin(1, nz / len))
  aspect <- atan2(nx, ny) %% (2 * pi)
  # horizontal component at round-off level (relative 1e-12): horizontal
  level <- !is.na(len) & sqrt(nx^2 + ny^2) <= 1e-12 * len
  slope[level] <- 0
  aspect[level | (!is.na(aspect) & aspect >= 2 * pi)] <- 0
  list(slope = slope, aspect = aspect, normal_length = len)
}

#' Terrain on the working grid
#'
#' Elevation, slope and aspect of every cell of the working grid (the 1 km
#' MODIS sinusoidal grid of the LST, MP-08) from a 1 arc-second elevation
#' model in longitude/latitude (decision M5-06).
#'
#' Both methods start from the 3 x 3 mean of the 1 arc-second DEM (3
#' arc-seconds, about 90 m; a block with any `NA` pixel is `NA`). The 3
#' arc-second cells are assigned to the working cell that contains their
#' centre (centres projected to the CRS of `grid`; `terra::cellFromXY()`),
#' and every working-cell value is the plain mean over its assigned valid
#' cells: an aggregation, never an interpolation. Each 3 arc-second cell
#' is used once and with equal weight; their areas differ by less than
#' 2e-4 (relative, cos(latitude) across 1 km) within a working cell, a
#' difference neglected. Projecting the 90 m raster to a sinusoidal grid
#' nested in the working grid would need a resampling step (nearest
#' neighbour duplicates or skips source cells), which the membership
#' assignment avoids.
#'
#' - `"flat"`: explicit flat-terrain option. Elevation = mean of the 3
#'   arc-second elevations; slope 0, aspect 0 (see below), normal length 1.
#' - `"nasadem_normal_mean"` (`CANDIDATA`, the chain of M5-06): slope and
#'   aspect of every 3 arc-second cell with `terra::terrain()` (8
#'   neighbours, Horn's method; on longitude/latitude rasters terra computes
#'   the cell sizes in metres for each row, so no reprojection is needed),
#'   unit normal components (east, north, up) per cell
#'   (`dem_normal_components()`), their mean per working cell, and from the
#'   mean normal the effective slope, aspect and length
#'   (`dem_effective_terrain()`). The mean normal gives the exact mean
#'   cosine of the solar incidence angle over the cell when no cell is
#'   self-shaded or cast-shaded (M5-06); `normal_length` < 1 measures the
#'   roughness lost by the averaging (1 on a plane).
#'
#' Aspect: GIS convention of the core (radians clockwise from geographic
#' north, \[0, 2 pi); `ef_cos_incidence()` in R/solar-geometry.R). Where the
#' slope is 0 it is undefined and set to 0 (RC-16, proposed route: the DEM
#' wrapper assigns a value so that the core does not propagate `NA`).
#'
#' Support: `valid_fraction` = valid 3 arc-second cells / all 3
#' arc-second cells assigned to the working cell (valid = elevation, and
#' for the normal-mean method also slope and aspect, not `NA`). Cells with
#' no valid support are `NA`; partial cells keep the mean over their valid
#' support and an `earthflux_dem_incomplete_warning` reports their number.
#' No value is filled.
#'
#' @param dem A one-layer `SpatRaster` of elevation \[m\] in
#'   longitude/latitude with 1 arc-second cells (from `dem_read()`), `NA`
#'   where there are no data. It must cover the box of `grid` with a margin
#'   of 2 cells of 3 arc-seconds.
#' @param grid A `SpatRaster` with a CRS: the working grid.
#' @param method Character, no default: `"flat"` or
#'   `"nasadem_normal_mean"`.
#' @return An `earthflux_terrain` object (`new_ef_object()`): `terrain`, a
#'   `SpatRaster` on exactly the geometry of `grid` with layers
#'   `elevation` \[m\], `slope` \[rad\], `aspect` \[rad\], `normal_length`
#'   \[-\] and `valid_fraction` \[-\]; `units`; `flags` (empty);
#'   `provenance` (`method`, `status`, steps, counts).
#' @noRd
dem_terrain <- function(dem, grid, method) {
  check_method(method, c("flat", "nasadem_normal_mean"))
  if (!inherits(grid, "SpatRaster") || !nzchar(terra::crs(grid))) {
    ef_abort("`grid` must be a SpatRaster with a coordinate reference system.",
             class = "earthflux_input_error")
  }
  if (!inherits(dem, "SpatRaster") || terra::nlyr(dem) != 1L ||
      !isTRUE(terra::is.lonlat(dem))) {
    ef_abort("`dem` must be a one-layer SpatRaster in longitude/latitude.",
             class = "earthflux_input_error")
  }
  res1 <- terra::res(dem)
  if (any(abs(res1 * 3600 - 1) > 1e-6)) {
    ef_abort("`dem` must have cells of 1 arc-second.",
             class = "earthflux_input_error")
  }
  box <- dem_lonlat_box(grid)
  de <- as.vector(terra::ext(dem))
  pad <- 2 * 3 / 3600
  if (box[["xmin"]] < de[["xmin"]] + pad ||
      box[["xmax"]] > de[["xmax"]] - pad ||
      box[["ymin"]] < de[["ymin"]] + pad ||
      box[["ymax"]] > de[["ymax"]] - pad) {
    ef_abort("`dem` does not cover the working grid (with its margin).",
             class = c("earthflux_dem_coverage_error", "earthflux_input_error"))
  }

  z3 <- terra::aggregate(dem, fact = 3, fun = "mean", na.rm = FALSE)
  z <- terra::values(z3, mat = FALSE)
  if (method == "nasadem_normal_mean") {
    # one variable per call: terra < 1.7-83 failed with several (#1561)
    sl <- terra::values(terra::terrain(z3, v = "slope", neighbors = 8,
                                       unit = "radians"), mat = FALSE)
    asp <- terra::values(terra::terrain(z3, v = "aspect", neighbors = 8,
                                        unit = "radians"), mat = FALSE)
    valid <- !is.na(z) & !is.na(sl) & !is.na(asp)
    nrm <- dem_normal_components(sl, asp)
  } else {
    valid <- !is.na(z)
  }
  xy <- terra::xyFromCell(z3, seq_len(terra::ncell(z3)))
  if (!isTRUE(terra::same.crs(z3, grid))) {
    xy <- terra::project(xy, from = terra::crs(z3), to = terra::crs(grid))
  }
  cell <- terra::cellFromXY(grid, xy)
  inside <- !is.na(cell)
  n_cells <- terra::ncell(grid)
  n_all <- tabulate(cell[inside], nbins = n_cells)
  use <- inside & valid
  n_val <- tabulate(cell[use], nbins = n_cells)
  cols <- if (method == "nasadem_normal_mean") {
    cbind(z = z[use], nx = nrm$nx[use], ny = nrm$ny[use], nz = nrm$nz[use])
  } else {
    cbind(z = z[use])
  }
  sums <- matrix(NA_real_, nrow = n_cells, ncol = ncol(cols),
                 dimnames = list(NULL, colnames(cols)))
  if (any(use)) {
    rs <- rowsum(cols, cell[use])
    sums[as.integer(rownames(rs)), ] <- rs
  }
  ok <- n_val > 0L
  mean_of <- function(v) ifelse(ok, sums[, v] / pmax(n_val, 1L), NA_real_)
  elevation <- mean_of("z")
  if (method == "nasadem_normal_mean") {
    eff <- dem_effective_terrain(mean_of("nx"), mean_of("ny"), mean_of("nz"))
  } else {
    eff <- list(slope = ifelse(ok, 0, NA_real_),
                aspect = ifelse(ok, 0, NA_real_),
                normal_length = ifelse(ok, 1, NA_real_))
  }
  valid_fraction <- ifelse(n_all > 0L, n_val / pmax(n_all, 1L), NA_real_)
  valid_fraction[!ok] <- 0

  out <- terra::rast(grid, nlyrs = 5L)
  names(out) <- c("elevation", "slope", "aspect", "normal_length",
                  "valid_fraction")
  terra::values(out) <- cbind(elevation, eff$slope, eff$aspect,
                              eff$normal_length, valid_fraction)

  n_partial <- sum(ok & valid_fraction < 1)
  n_empty <- sum(!ok)
  if (n_partial + n_empty > 0L) {
    ef_warn(
      sprintf(paste0("%d working cell(s) have partial elevation-model ",
                     "support (valid_fraction < 1) and %d none (NA): water ",
                     "masked, outside the NASADEM tiles or at the edge of ",
                     "the model. Values are means over the valid support; ",
                     "nothing is filled."), n_partial, n_empty),
      class = "earthflux_dem_incomplete_warning",
      n_partial = n_partial, n_empty = n_empty
    )
  }

  new_ef_object(list(
    terrain = out,
    units = c(elevation = "m", slope = "rad", aspect = "rad",
              normal_length = "-", valid_fraction = "-"),
    flags = list(),
    provenance = list(
      method = method,
      status = c(
        method = if (method == "flat")
          "DECIDIDA (provisional), M5-06: explicit flat-terrain option" else
          "CANDIDATA (M5-06 chain; Horn 8-neighbour slope and aspect of terra)",
        elevation = "mean of the 3 x 3 arc-second mean, M5-06",
        aspect_at_zero_slope = "0 (RC-16 ABIERTA, proposed route)"
      ),
      steps = c(
        "3 x 3 mean of the 1 arc-second DEM (any NA pixel -> NA block)",
        if (method == "nasadem_normal_mean") c(
          "slope and aspect at 3 arc-seconds: terra::terrain(neighbors = 8)",
          "unit normal (east, north, up) per 3 arc-second cell"
        ),
        paste0("assignment of the 3 arc-second cells to the working cell ",
               "containing their centre; plain mean per working cell"),
        if (method == "nasadem_normal_mean")
          "effective slope = acos(nz / |n|), aspect = atan2(nx, ny) mod 2 pi"
      ),
      aspect_convention = paste0("radians clockwise from geographic north, ",
                                 "[0, 2 pi) (R/solar-geometry.R)"),
      vertical_datum = "EGM96 geoid (NASADEM_HGT)",
      cells = c(total = n_cells, partial = n_partial, empty = n_empty),
      versions = list(
        earthflux = as.character(getNamespaceVersion("EarthFlux")),
        terra = as.character(utils::packageVersion("terra"))
      )
    )
  ), "earthflux_terrain")
}

# Composition ------------------------------------------------------------------

#' Elevation model and terrain on the working grid, from an area
#'
#' Search (`dem_search()`) of the NASADEM_HGT tiles over the box of the
#' working grid (which phase 2 crops to the AOI), download and cache
#' (`dem_download()`), mosaic (`dem_read()`) and terrain
#' (`dem_terrain()`).
#'
#' @param aoi A `SpatVector` (any CRS): the area of interest. It must
#'   overlap `grid`; it is recorded (box) in the provenance. The terrain is
#'   computed on the whole `grid`.
#' @param grid A `SpatRaster`: the working grid.
#' @param method Character, no default: see `dem_terrain()`.
#' @param water Character, no default: see `dem_read()`.
#' @param cache_dir Character. Cache root (default
#'   `tools::R_user_dir("EarthFlux", "cache")`).
#' @return The `earthflux_terrain` of `dem_terrain()` with its provenance
#'   completed: `source`, `product`, `version`, `doi`, `granules` (tile,
#'   granule id, concept id, URL, cache path, cached, download date),
#'   `search` (CMR parameters), `missing_tiles`, `water`, `counts`,
#'   `license`, `facts_status`. No credential is recorded.
#' @noRd
dem_fetch <- function(aoi, grid, method, water, cache_dir = dem_cache_dir()) {
  check_method(method, c("flat", "nasadem_normal_mean"))
  check_method(water, c("mask", "keep"), arg = "water")
  if (!inherits(aoi, "SpatVector")) {
    ef_abort("`aoi` must be a SpatVector.", class = "earthflux_input_error")
  }
  if (!inherits(grid, "SpatRaster") || !nzchar(terra::crs(grid))) {
    ef_abort("`grid` must be a SpatRaster with a coordinate reference system.",
             class = "earthflux_input_error")
  }
  aoi_box <- dem_lonlat_box(aoi)
  grid_box <- dem_lonlat_box(grid)
  if (aoi_box[["xmin"]] > grid_box[["xmax"]] ||
      aoi_box[["xmax"]] < grid_box[["xmin"]] ||
      aoi_box[["ymin"]] > grid_box[["ymax"]] ||
      aoi_box[["ymax"]] < grid_box[["ymin"]]) {
    ef_abort("The area of interest does not overlap the working grid.",
             class = "earthflux_input_error")
  }
  window <- dem_window(grid)
  s <- dem_tile_n() - 1
  search_box <- terra::ext((window$k[1L] - 0.5) / s, (window$k[2L] + 0.5) / s,
                           (window$j[1L] - 0.5) / s, (window$j[2L] + 0.5) / s)
  tiles <- dem_search(search_box)
  if (nrow(tiles) == 0L) {
    ef_abort("No NASADEM tile covers the working grid (ocean only?).",
             class = c("earthflux_dem_coverage_error", "earthflux_input_error"))
  }
  tiles <- dem_download(tiles, cache_dir)
  rd <- dem_read(tiles, window, water)
  res <- dem_terrain(rd$dem, grid, method)
  f <- dem_nasadem_facts()
  p <- res$provenance
  res$provenance <- c(
    list(
      source = "NASA LP DAAC cloud archive (LPCLOUD), found with NASA CMR",
      product = f$short_name,
      version = f$version,
      doi = f$doi,
      granules = tiles[, c("tile", "granule_ur", "concept_id", "url", "hgt",
                           "cached", "download_date")],
      search = attr(tiles, "query"),
      missing_tiles = attr(tiles, "missing_tiles"),
      aoi_box = aoi_box,
      water = water,
      counts = rd$counts,
      cache_dir = file.path(cache_dir, "dem"),
      license = f$license,
      facts_status = f$status,
      documentation = f$sources
    ),
    p
  )
  res
}
