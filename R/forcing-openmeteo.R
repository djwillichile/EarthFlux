# Forcing: ERA5 via the Open-Meteo historical weather API -----------------------
#
# Purpose: station-free meteorological forcing (decision M5-07,
#   dev/DECISIONS.md section 1.5; dev/ARCHITECTURE.md section 6.7). Hourly
#   ERA5 values are downloaded from the Open-Meteo historical weather API for
#   the centres of the ERA5 grid cells that cover the area of interest (plus
#   a one-cell buffer), and every cell becomes a "virtual station" of the
#   standard station table (ef_station_table(), R/io-weather.R). The table
#   then goes through the existing chain unchanged: quality control
#   (ef_station_qc()), reference ET (ef_station_ref_et()) and
#   regionalization (ef_regionalize(), C1/C2).
#
# Contents (all internal; phase 2 of M5 decides the public API):
#   openmeteo_points()          ERA5 cell centres covering an AOI + buffer
#   openmeteo_query()           query parameters of one request (no key)
#   openmeteo_request()         HTTP request(s) -> earthflux_openmeteo_response
#   openmeteo_response()        parse and validate a JSON response
#   openmeteo_station_table()   response -> earthflux_station_table
#   openmeteo_fetch()           points + cache + request + station table
#   openmeteo_forcing_flags()   gridded-forcing flag derived from provenance
#   ef_flags_gridded_forcing()  registry row of EF_WS_GRIDDED_FORCING
#   openmeteo_http_get()        the only network call (mocked in tests)
#
# API facts (verified on 2026-11-06; URLs in the roxygen blocks):
#   - Historical Weather API, https://open-meteo.com/en/docs/historical-weather-api
#     ("API Documentation": parameter table, hourly parameter definition,
#     JSON return object, errors; "Data Sources" table);
#   - licence and attribution, https://open-meteo.com/en/licence;
#   - free / customer API, call limits, https://open-meteo.com/en/pricing
#     (FAQ "What sets apart the free API from the customer API?");
#   - server behaviour not stated in the documentation (ERA5 grid, number of
#     locations per request, elevation downscaling) was read in the source
#     code of the API, https://github.com/open-meteo/open-meteo (commit
#     97132c51bbb138c0041ebbbe6570e4140943eb03, 2026-11-04).
#
# Credentials: no key by default (free, non-commercial API). The optional
#   `apikey` (commercial use) is sent only as the query parameter of the
#   customer endpoint; it never enters the provenance, the cache key, the
#   cache path, an error or a warning (only `apikey_used = TRUE/FALSE` is
#   recorded).

# API and product facts ---------------------------------------------------------

#' Endpoints of the Open-Meteo historical weather API
#'
#' Free endpoint `https://archive-api.open-meteo.com/v1/archive` (the URL of
#' the documentation's request builder); the customer endpoint for
#' commercial use takes the prefix `customer-` and the parameter `apikey`
#' (https://open-meteo.com/en/docs/historical-weather-api, parameter
#' `apikey`: "The server URL requires the prefix customer-";
#' https://open-meteo.com/en/pricing, FAQ: "requests include &apikey=...
#' All parameters and response formats are otherwise identical to the free
#' API"). VERIFICADA.
#'
#' @return A named character vector (`free`, `customer`).
#' @noRd
openmeteo_endpoints <- function() {
  c(free = "https://archive-api.open-meteo.com/v1/archive",
    customer = "https://customer-archive-api.open-meteo.com/v1/archive")
}

#' ERA5 grid of Open-Meteo
#'
#' Regular latitude-longitude grid of 0.25 degrees, 1440 x 721 points from
#' latitude -90 and longitude -180, i.e. grid points at whole multiples of
#' 0.25 degrees (Open-Meteo source code, `Sources/App/Era5/Era5Domain.swift`,
#' `CdsDomain.grid`, case `.era5`: `RegularGrid(nx: 1440, ny: 721, latMin:
#' -90, lonMin: -180, dx: 0.25, dy: 0.25)`; the documentation gives the
#' resolution, "ERA5 ... 0.25 (~25 km), Hourly, 1940 to present, Daily with
#' 5 days delay", Data Sources table). The response coordinates are "WGS84
#' of the center of the weather grid-cell which was used" (JSON return
#' object). VERIFICADA.
#'
#' @return A list with `resolution`, `lat_min`, `lon_min`, `nx`, `ny` and
#'   `first_date`.
#' @noRd
openmeteo_grid <- function() {
  list(resolution = 0.25, lat_min = -90, lon_min = -180, nx = 1440L,
       ny = 721L, first_date = as.Date("1940-01-01"))
}

#' Maximum number of locations of one request
#'
#' The API rejects a request with more locations than its limit ("Only up
#' to N locations can be requested at once"): 1000 on the free endpoint (the
#' default of `LOCATIONS_LIMIT`, `Sources/App/configure.swift`,
#' `numberOfLocationsMaximum`) and 10 000 or more with an API key
#' (`Sources/App/Helper/Vapor/ApiKeyManager.swift`). Not stated in the
#' documentation, which only says that "Multiple coordinates can be comma
#' separated". The package sends at most `chunk_size` (default 100)
#' locations per request, well below the limit, so that the URL stays short.
#'
#' @return An integer.
#' @noRd
openmeteo_max_locations <- function() {
  1000L
}

#' Hourly variables requested and their mapping to the station contract
#'
#' Names, units and valid time from the hourly parameter definition of
#' https://open-meteo.com/en/docs/historical-weather-api ("Most weather
#' variables are given as an instantaneous value for the indicated hour"):
#' `temperature_2m` (Instant, degC, "Air temperature at 2 meters above
#' ground"), `dew_point_2m` (Instant, degC, at 2 m), `wind_speed_10m`
#' (Instant, km/h by default, m/s with `wind_speed_unit=ms`; "Wind speed on
#' 10 meters is the standard level"), `shortwave_radiation` (Preceding hour
#' mean, W/m2, "Shortwave solar radiation as average of the preceding hour.
#' This is equal to the total global horizontal irradiation") and
#' `surface_pressure` (Instant, hPa, "pressure at surface"). VERIFICADA.
#'
#' The API computes `surface_pressure` from `pressure_msl` and
#' `temperature_2m` at the target elevation (source code,
#' `Sources/App/Controllers/VariableHourly.swift`, case `.surface_pressure`,
#' and `Meteorology.surfacePressure()`); the reference ET at the stations
#' uses the pressure from the elevation (FAO-56 Eq. 7, decision WF-05)
#' anyway. `relative_humidity_2m` is not requested: the dew point is the
#' ERA5 field (`2m_dewpoint_temperature`, `Era5Variables.swift`) and gives
#' the vapour pressure directly (FAO-56 Eq. 14).
#'
#' @return A data frame with columns `api` (API name), `variable` (contract
#'   variable of the station table), `api_unit` (unit string of
#'   `hourly_units`), `source_unit` (unit declared to `ef_station_table()`),
#'   `valid_time` (`"instant"` or `"preceding_hour_mean"`) and `height`
#'   (measurement height above ground \[m\], `NA` if none).
#' @noRd
openmeteo_variables <- function() {
  data.frame(
    api = c("temperature_2m", "dew_point_2m", "wind_speed_10m",
            "shortwave_radiation", "surface_pressure"),
    variable = c("air_temperature", "dewpoint_temperature", "wind_speed",
                 "solar_radiation", "air_pressure"),
    api_unit = c("\u00b0C", "\u00b0C", "m/s", "W/m\u00b2", "hPa"),
    source_unit = c("degC", "degC", "m/s", "W/m2", "hPa"),
    valid_time = c("instant", "instant", "instant", "preceding_hour_mean",
                   "instant"),
    height = c(2, 2, 10, NA, NA),
    stringsAsFactors = FALSE
  )
}

#' Treatments of the instantaneous values
#'
#' The station table has one period semantics for all its variables, and the
#' hourly records of the reference ET are period means (FAO-56, chapter 4,
#' hourly time step). Open-Meteo gives the radiation as the mean of the
#' preceding hour (timestamp = end of the period) and the other variables as
#' instantaneous values at the timestamp. Both treatments of the
#' instantaneous values are `CANDIDATA` (no source reviewed for ERA5):
#' * `"end_of_period"`: the value at the end of the hour is taken as the
#'   value of the hourly period that ends at the timestamp (no change of the
#'   values; the effective time lags the mid-point of the period by 30 min);
#' * `"trapezoid"`: the mean of the values at the start and at the end of the
#'   hour (trapezoidal approximation of the period mean); `NA` when either is
#'   missing, so the first record of every series is `NA`.
#'
#' @return A character vector.
#' @noRd
openmeteo_instant_treatments <- function() {
  c("end_of_period", "trapezoid")
}

#' Licence and attribution of the Open-Meteo ERA5 data
#'
#' Open-Meteo: "API data are offered under Attribution 4.0 International (CC
#' BY 4.0) ... You must give appropriate credit, provide a link to the
#' licence, and indicate if changes were made ... You must include a link
#' next to any location Open-Meteo data are displayed", with the example
#' "Weather data by Open-Meteo.com" linked to https://open-meteo.com/
#' (https://open-meteo.com/en/licence). The free API is for non-commercial
#' use only (https://open-meteo.com/en/terms, "Non-Commercial Use";
#' https://open-meteo.com/en/pricing). ERA5 ("Weather reanalysis ... from
#' Copernicus Climate Change Service C3S", licence page) is under the
#' Licence to use Copernicus Products, clause 5.1.2: "Where the Licensee
#' makes or contributes to a publication or distribution containing adapted
#' or modified Copernicus Products, the Licensee shall provide the following
#' or any similar notice: 'Contains modified Copernicus Climate Change
#' Service information \[Year\]'", and clause 5.1.3: such a publication
#' "shall state that neither the European Commission nor ECMWF is
#' responsible for any use that may be made of the Copernicus information or
#' data it contains". Citations as given in the documentation (Citation &
#' Acknowledgement). VERIFICADA (2026-11-06).
#'
#' @param year Character. Year of the Copernicus notice (the year of
#'   retrieval; the licence does not define it further).
#' @param apikey_used Logical. Whether the customer API (commercial licence)
#'   was used.
#' @return A list with `license`, `license_url`, `terms_url`, `attribution`
#'   (named character vector), `usage` and `citation`.
#' @noRd
openmeteo_license <- function(year, apikey_used) {
  list(
    license = "CC BY 4.0",
    license_url = "https://creativecommons.org/licenses/by/4.0/",
    terms_url = "https://open-meteo.com/en/licence",
    attribution = c(
      open_meteo = paste0("Weather data by Open-Meteo.com ",
                          "(https://open-meteo.com/), CC BY 4.0"),
      copernicus = sprintf(
        "Contains modified Copernicus Climate Change Service information %s",
        year
      ),
      disclaimer = paste0(
        "Neither the European Commission nor ECMWF is responsible for any ",
        "use that may be made of the Copernicus information or data it ",
        "contains."
      ),
      changes = paste0(
        "Changed by EarthFlux: units converted (hPa to kPa), grid cells ",
        "turned into virtual stations, instantaneous values assigned to ",
        "hourly periods."
      )
    ),
    usage = if (isTRUE(apikey_used)) {
      "commercial (customer API with an API key)"
    } else {
      paste0("non-commercial only (free API without an API key; ",
             "https://open-meteo.com/en/terms)")
    },
    citation = c(
      open_meteo = paste0(
        "Zippenfenig, P. (2023). Open-Meteo.com Weather API [Computer ",
        "software]. Zenodo. https://doi.org/10.5281/ZENODO.7970649"
      ),
      era5 = paste0(
        "Hersbach, H., Bell, B., Berrisford, P., Biavati, G., Horanyi, A., ",
        "Munoz Sabater, J., Nicolas, J., Peubey, C., Radu, R., Rozum, I., ",
        "Schepers, D., Simmons, A., Soci, C., Dee, D., Thepaut, J-N. (2023). ",
        "ERA5 hourly data on single levels from 1940 to present [Data set]. ",
        "ECMWF. https://doi.org/10.24381/cds.adbb2d47"
      )
    )
  )
}

#' Default cache directory of the downloads
#'
#' @return A path (`tools::R_user_dir("EarthFlux", "cache")`); the
#'   Open-Meteo responses go to its subfolder `openmeteo/`.
#' @noRd
openmeteo_default_cache <- function() {
  tools::R_user_dir("EarthFlux", "cache")
}

# Flags ---------------------------------------------------------------------------

#' Flag code of the gridded forcing
#'
#' `EF_WS_GRIDDED_FORCING` (stage `WS`, class I, scope `object`, no bit):
#' the forcing comes from a gridded reanalysis (ERA5 via Open-Meteo) whose
#' cells act as virtual stations (decision M5-07: "el resultado lleva un
#' flag de forzamiento grillado"). Severity `warning` by dev/specs/flags.md
#' section 5.3: the values are usable but obtained under an assumption
#' (a 0.25 degree cell as a station; ERA5 compresses the daily amplitude,
#' Tmax 2-3 K low and Tmin 3-4 K high in the evaluation of M5-07), so the
#' result must be interpreted with care. It is computed from the provenance
#' (`provenance$forcing$type == "gridded"`; dev/specs/flags.md section 6.1,
#' test R19).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_gridded_forcing <- function() {
  ef_flag_rows(
    code = "EF_WS_GRIDDED_FORCING",
    stage = "WS",
    severity = "warning",
    scope = "object",
    bit = NA_integer_,
    error_class = NA_character_,
    description = paste0(
      "The weather forcing comes from a gridded reanalysis whose grid ",
      "cells act as virtual stations, not from weather stations."
    ),
    spec = paste0("dev/ARCHITECTURE.md 6.7; dev/DECISIONS.md M5-07; ",
                  "dev/specs/flags.md 4.2"),
    since = "0.1.0.9000"
  )
}

#' Gridded-forcing flag of a station table
#'
#' Derived from the provenance, the single source of truth
#' (dev/specs/flags.md section 6.1): the object-scope record of
#' `EF_WS_GRIDDED_FORCING` is present if and only if
#' `provenance$forcing$type` is `"gridded"`. The code is evaluated in both
#' cases.
#'
#' @param provenance The provenance list of a station table (or of a result
#'   that kept it).
#' @return A list as returned by `ef_flags_combine()`: `flags` (zero or one
#'   `earthflux_flag` record) and `evaluated` (`"EF_WS_GRIDDED_FORCING"`).
#' @noRd
openmeteo_forcing_flags <- function(provenance) {
  gridded <- is.list(provenance) && is.list(provenance$forcing) &&
    identical(provenance$forcing$type, "gridded")
  ef_flags_combine(
    ef_flag_set(list(EF_WS_GRIDDED_FORCING = gridded), scope = "object")
  )
}

# Conditions ----------------------------------------------------------------------

#' Signal a download error of the Open-Meteo module
#'
#' @param message Character. Error message (never contains the API key).
#' @param subclass Character or `NULL`. Specific class.
#' @param ... Data fields of the condition (e.g. `status`, `url`).
#' @return Never returns.
#' @noRd
openmeteo_abort <- function(message, subclass = NULL, ...) {
  ef_abort(message, class = c(subclass, "earthflux_download_error"), ...,
           call = NULL)
}

#' Signal an error in the Open-Meteo response
#'
#' @inheritParams openmeteo_abort
#' @return Never returns; class `earthflux_openmeteo_response_error`
#'   (inherits `earthflux_download_error`).
#' @noRd
openmeteo_response_abort <- function(message, ...) {
  openmeteo_abort(message, "earthflux_openmeteo_response_error", ...)
}

#' Signal an input error of the Open-Meteo module
#'
#' @param message Character. Error message.
#' @param subclass Character or `NULL`. Specific class.
#' @return Never returns.
#' @noRd
openmeteo_input_abort <- function(message, subclass = NULL) {
  ef_abort(message, class = c(subclass, "earthflux_input_error"), call = NULL)
}

# Grid points ---------------------------------------------------------------------

#' ERA5 grid cells covering an area of interest
#'
#' Returns the centres of the ERA5 grid cells (0.25 degrees; grid points at
#' whole multiples of 0.25 degrees, see `openmeteo_grid()`) whose cell
#' (centre +- 0.125 degrees) touches the area of interest, plus every cell
#' adjacent to them (a one-cell buffer, 8 neighbours), so that the
#' regionalization has neighbours outside the area. The AOI is projected to
#' WGS84 longitude-latitude first (lines and polygons in a projected CRS are
#' densified every 1000 m so that curved edges are respected). Grid points
#' beyond the poles are dropped and longitudes are wrapped to \[-180, 180).
#'
#' The number of points is capped by `max_points` (default 250, about a
#' 3.5 x 3.5 degree area with its buffer, i.e. a large Chilean region):
#' above it the call fails instead of truncating the area. The cap keeps the
#' request reasonable for the free API (each location counts towards its
#' call limits, https://open-meteo.com/en/pricing, FAQ "How is one API call
#' defined?") and below the server limit of locations per request
#' (`openmeteo_max_locations()`); split a larger area.
#'
#' @param aoi A `SpatVector` (points, lines or polygons) with a CRS.
#' @param resolution Numeric. Grid spacing in degrees; only the ERA5 grid,
#'   0.25, is implemented.
#' @param max_points Whole number. Maximum number of grid points.
#' @return A data frame with `lat`, `lon` (degrees, WGS84, multiples of
#'   0.25) and `in_aoi` (`TRUE` for the cells that touch the AOI, `FALSE`
#'   for the buffer), ordered from north to south and west to east.
#' @noRd
openmeteo_points <- function(aoi, resolution = 0.25, max_points = 250L) {
  grid <- openmeteo_grid()
  if (!is.numeric(resolution) || length(resolution) != 1L ||
      !isTRUE(all.equal(resolution, grid$resolution))) {
    openmeteo_input_abort(sprintf(
      "`resolution` must be %s (the ERA5 grid of Open-Meteo); other grids are not implemented.",
      format(grid$resolution)
    ))
  }
  if (!is.numeric(max_points) || length(max_points) != 1L ||
      !is.finite(max_points) || max_points < 1 ||
      max_points != round(max_points)) {
    openmeteo_input_abort("`max_points` must be a positive whole number.")
  }
  if (!inherits(aoi, "SpatVector")) {
    openmeteo_input_abort("`aoi` must be a SpatVector with a CRS.")
  }
  if (!nzchar(terra::crs(aoi)) || terra::nrow(aoi) == 0L) {
    openmeteo_input_abort("`aoi` must be a non-empty SpatVector with a CRS.")
  }
  res <- grid$resolution
  if (!terra::is.lonlat(aoi)) {
    if (terra::geomtype(aoi) %in% c("lines", "polygons")) {
      aoi <- terra::densify(aoi, 1000)
    }
    aoi <- terra::project(aoi, "EPSG:4326")
  }
  e <- as.vector(terra::ext(aoi))
  if (any(!is.finite(e)) || e[["xmin"]] < -180 || e[["xmax"]] > 180 ||
      e[["ymin"]] < -90 || e[["ymax"]] > 90) {
    openmeteo_input_abort(
      "The area of interest must lie within longitude [-180, 180] and latitude [-90, 90]."
    )
  }
  # Grid indices of the cells containing the extent, plus one cell each side.
  ix <- seq(round(e[["xmin"]] / res) - 1, round(e[["xmax"]] / res) + 1)
  iy <- seq(round(e[["ymax"]] / res) + 1, round(e[["ymin"]] / res) - 1)
  r <- terra::rast(
    nrows = length(iy), ncols = length(ix),
    xmin = (min(ix) - 0.5) * res, xmax = (max(ix) + 0.5) * res,
    ymin = (min(iy) - 0.5) * res, ymax = (max(iy) + 0.5) * res,
    crs = "EPSG:4326"
  )
  touched <- terra::rasterize(aoi, r, field = 1, background = 0,
                              touches = TRUE)
  m <- matrix(terra::values(touched, mat = FALSE) > 0, nrow = length(iy),
              ncol = length(ix), byrow = TRUE)
  m[is.na(m)] <- FALSE
  if (!any(m)) {
    openmeteo_input_abort("The area of interest does not touch any ERA5 grid cell.")
  }
  # One-cell buffer: dilation with the 3 x 3 neighbourhood.
  buffered <- m
  nr <- nrow(m)
  nc <- ncol(m)
  for (dr in -1:1) {
    for (dc in -1:1) {
      rows <- seq_len(nr)
      cols <- seq_len(nc)
      src_r <- rows - dr
      src_c <- cols - dc
      ok_r <- src_r >= 1L & src_r <= nr
      ok_c <- src_c >= 1L & src_c <= nc
      buffered[rows[ok_r], cols[ok_c]] <- buffered[rows[ok_r], cols[ok_c]] |
        m[src_r[ok_r], src_c[ok_c]]
    }
  }
  idx <- which(buffered, arr.ind = TRUE)
  idx <- idx[order(idx[, 1L], idx[, 2L]), , drop = FALSE]
  lat <- iy[idx[, 1L]] * res
  lon <- ix[idx[, 2L]] * res
  in_aoi <- m[idx]
  lon <- ((lon + 180) %% 360) - 180
  keep <- abs(lat) <= 90
  out <- data.frame(lat = lat[keep], lon = lon[keep], in_aoi = in_aoi[keep])
  out <- out[!duplicated(out[c("lat", "lon")]), , drop = FALSE]
  rownames(out) <- NULL
  if (nrow(out) > max_points) {
    openmeteo_input_abort(
      sprintf(paste0(
        "The area of interest needs %d ERA5 grid points (with the one-cell ",
        "buffer), more than `max_points` = %d; split the area or raise ",
        "`max_points`."
      ), nrow(out), as.integer(max_points)),
      "earthflux_openmeteo_points_error"
    )
  }
  out
}

#' Check a table of grid points
#'
#' @param points Object to check.
#' @return `points`, invisibly.
#' @noRd
openmeteo_check_points <- function(points) {
  ok <- is.data.frame(points) && all(c("lat", "lon") %in% names(points)) &&
    nrow(points) > 0L && is.numeric(points$lat) && is.numeric(points$lon) &&
    all(is.finite(points$lat)) && all(is.finite(points$lon)) &&
    all(abs(points$lat) <= 90) && all(abs(points$lon) <= 180)
  if (!ok) {
    openmeteo_input_abort(paste0(
      "`points` must be a non-empty data frame with finite `lat` and `lon` ",
      "in degrees (see openmeteo_points())."
    ))
  }
  if (anyDuplicated(points[c("lat", "lon")]) > 0L) {
    openmeteo_input_abort("`points` has duplicated locations.")
  }
  invisible(points)
}

# Request ---------------------------------------------------------------------------

#' Query parameters of a request
#'
#' Builds the documented query parameters of the historical weather API
#' (https://open-meteo.com/en/docs/historical-weather-api, parameter table):
#' `latitude`, `longitude` (comma-separated for several locations; "the JSON
#' output changes to a list of structures"), `start_date`, `end_date`
#' (`yyyy-mm-dd`), `hourly` (see `openmeteo_variables()`), `models=era5`
#' (ERA5 only, never `era5_land`, which has no radiation, wind or pressure;
#' M5-07), `cell_selection=nearest` ("selects the nearest possible
#' grid-cell"; the default `land` may pick another cell with a similar
#' elevation, which would break the cell-centre virtual station),
#' `wind_speed_unit=ms`, `timezone=GMT` (UTC; "utc_offset_seconds" is then
#' 0) and `timeformat=unixtime` ("seconds since 1970-01-01 00:00 UTC").
#'
#' Elevation (decision M5-07, explicit option): with `elevation_adjust =
#' TRUE` the parameter `elevation` is omitted, so the API uses "a 90 meter
#' digital elevation model" at the requested point and applies its
#' "statistical downscaling" (in the source code, `GenericReader.scale()`,
#' a correction of 0.0065 K m-1 of `temperature_2m` and `dew_point_2m` from
#' the cell elevation to the target elevation, and the surface pressure at
#' the target elevation); with `FALSE`, `elevation=nan` for every location:
#' "downscaling will be disabled and the API uses the average grid-cell
#' height". VERIFICADA (documentation and source code).
#'
#' @param points A data frame with `lat` and `lon` (see `openmeteo_points()`).
#' @param start_date,end_date `Date` (UTC days).
#' @param elevation_adjust Logical, no default.
#' @return A named list of single strings, in a fixed order, without the API
#'   key (also the canonical form of the cache key).
#' @noRd
openmeteo_query <- function(points, start_date, end_date, elevation_adjust) {
  openmeteo_check_points(points)
  if (missing(elevation_adjust) || is.null(elevation_adjust)) {
    ef_abort(
      "`elevation_adjust` must be supplied explicitly (TRUE or FALSE; no default).",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = NULL
    )
  }
  if (!is.logical(elevation_adjust) || length(elevation_adjust) != 1L ||
      is.na(elevation_adjust)) {
    openmeteo_input_abort("`elevation_adjust` must be TRUE or FALSE.")
  }
  dates <- openmeteo_check_dates(start_date, end_date)
  n <- nrow(points)
  q <- list(
    latitude = paste(sprintf("%.2f", points$lat), collapse = ","),
    longitude = paste(sprintf("%.2f", points$lon), collapse = ","),
    elevation = if (elevation_adjust) NULL else
      paste(rep("nan", n), collapse = ","),
    start_date = format(dates[[1L]], "%Y-%m-%d"),
    end_date = format(dates[[2L]], "%Y-%m-%d"),
    hourly = paste(openmeteo_variables()$api, collapse = ","),
    models = "era5",
    cell_selection = "nearest",
    wind_speed_unit = "ms",
    timezone = "GMT",
    timeformat = "unixtime"
  )
  q[!vapply(q, is.null, logical(1))]
}

#' Check the dates of a request
#'
#' @param start_date,end_date Objects to check.
#' @return A list of two `Date`.
#' @noRd
openmeteo_check_dates <- function(start_date, end_date) {
  ok <- function(d) inherits(d, "Date") && length(d) == 1L && !is.na(d)
  if (!ok(start_date) || !ok(end_date)) {
    openmeteo_input_abort("`start_date` and `end_date` must be single `Date` values.")
  }
  if (end_date < start_date) {
    openmeteo_input_abort("`end_date` must not be before `start_date`.")
  }
  if (start_date < openmeteo_grid()$first_date) {
    openmeteo_input_abort(
      "ERA5 on Open-Meteo starts on 1940-01-01; `start_date` is earlier."
    )
  }
  list(start_date, end_date)
}

#' Check an API key argument
#'
#' @param apikey Object to check.
#' @return `apikey`, invisibly.
#' @noRd
openmeteo_check_apikey <- function(apikey) {
  if (!is.null(apikey) &&
      (!is.character(apikey) || length(apikey) != 1L || is.na(apikey) ||
         !nzchar(apikey))) {
    # The value is never echoed.
    openmeteo_input_abort("`apikey` must be NULL or a single non-empty string.")
  }
  invisible(apikey)
}

#' URL of a request
#'
#' @param query Named list from `openmeteo_query()`.
#' @param apikey `NULL` or the API key; with a key, the customer endpoint is
#'   used and the key is appended as the last parameter.
#' @param redact Logical. `TRUE` leaves the key out (the endpoint still
#'   follows `apikey`): the form for messages and provenance.
#' @return A single string. Never print or store it when `apikey` is given
#'   and `redact` is `FALSE`.
#' @noRd
openmeteo_url <- function(query, apikey = NULL, redact = FALSE) {
  endpoint <- openmeteo_endpoints()[[if (is.null(apikey)) "free" else
    "customer"]]
  values <- vapply(query, utils::URLencode, "", reserved = FALSE)
  url <- paste0(endpoint, "?",
                paste0(names(query), "=", values, collapse = "&"))
  if (!is.null(apikey) && !redact) {
    url <- paste0(url, "&apikey=", utils::URLencode(apikey, reserved = TRUE))
  }
  url
}

#' Extract the HTTP status code from a libcurl condition message
#'
#' `utils::download.file(method = "libcurl")` reports an HTTP error as a
#' warning "cannot open URL '...': HTTP status was '429 ...'" followed by an
#' error. The message contains the URL (with the key, if any), so it is never
#' re-emitted.
#'
#' @param message Character.
#' @return An integer status code or `NA`.
#' @noRd
openmeteo_status_code <- function(message) {
  m <- regmatches(message,
                  regexpr("HTTP status was '[0-9]{3}", message))
  if (length(m) == 0L) {
    return(NA_integer_)
  }
  as.integer(sub("HTTP status was '", "", m, fixed = TRUE))
}

#' HTTP GET of an Open-Meteo URL (the only network call of the module)
#'
#' Downloads `url` to `destfile` with `utils::download.file(method =
#' "libcurl")`. Conditions raised by libcurl contain the URL (and therefore
#' the API key, if any): they are caught and muffled here, and only the
#' status code leaves the function. Tests replace this function with
#' `testthat::local_mocked_bindings()`.
#'
#' @param url Character. The request URL.
#' @param destfile Character. Destination file.
#' @return An integer: `200L` on success, the HTTP status code of a failed
#'   request, or `NA` when there was no HTTP response.
#' @noRd
openmeteo_http_get <- function(url, destfile) {
  status <- NA_integer_
  note <- function(cnd) {
    s <- openmeteo_status_code(conditionMessage(cnd))
    if (!is.na(s)) {
      status <<- s
    }
  }
  result <- withCallingHandlers(
    tryCatch(
      utils::download.file(url, destfile, method = "libcurl", mode = "wb",
                           quiet = TRUE,
                           headers = c(Accept = "application/json")),
      error = function(e) {
        note(e)
        -1L
      }
    ),
    warning = function(w) {
      note(w)
      invokeRestart("muffleWarning")
    }
  )
  if (identical(as.integer(result), 0L)) 200L else status
}

#' Pause before a retry (wrapper so that tests do not wait)
#'
#' @param seconds Numeric.
#' @return `NULL`, invisibly.
#' @noRd
openmeteo_sleep <- function(seconds) {
  Sys.sleep(seconds)
  invisible(NULL)
}

#' Download one URL with one bounded retry on HTTP 429
#'
#' @param url Character. The request URL (may contain the key).
#' @param public_url Character. The same request without the key, for
#'   messages and provenance.
#' @param destfile Character. Destination file.
#' @param retry_wait Numeric. Seconds to wait before the single retry after
#'   an HTTP 429 (too many requests).
#' @return `destfile`, invisibly; otherwise an error of class
#'   `earthflux_download_error` with fields `status` and `url` (public).
#' @noRd
openmeteo_download <- function(url, public_url, destfile, retry_wait = 10) {
  status <- openmeteo_http_get(url, destfile)
  if (identical(status, 429L)) {
    openmeteo_sleep(retry_wait)
    status <- openmeteo_http_get(url, destfile)
  }
  if (!identical(status, 200L)) {
    unlink(destfile)
    hint <- if (identical(status, 429L)) {
      paste0(" (too many requests: the free API allows 600 calls per ",
             "minute, 5000 per hour and 10 000 per day; retried once; try ",
             "later or use an API key for commercial use)")
    } else if (identical(status, 400L)) {
      " (the API rejected the request parameters)"
    } else if (is.na(status)) {
      " (no HTTP response: network error)"
    } else {
      ""
    }
    shown <- if (nchar(public_url) > 300L) {
      paste0(substr(public_url, 1L, 300L), "...")
    } else {
      public_url
    }
    openmeteo_abort(
      sprintf("Open-Meteo request failed with HTTP status %s%s: %s",
              if (is.na(status)) "NA" else as.character(status), hint,
              shown),
      status = status, url = public_url
    )
  }
  invisible(destfile)
}

#' Request hourly ERA5 data for several locations
#'
#' Sends the request(s) to the free endpoint, or to the customer endpoint
#' with `apikey` (commercial use), with the parameters of
#' `openmeteo_query()`. Locations are sent in chunks of at most
#' `chunk_size` per HTTP request (comma-separated lists; the server accepts
#' up to `openmeteo_max_locations()`). An HTTP 429 is retried once after
#' `retry_wait` seconds; any other failure, a malformed response or a
#' response that does not match the request is a classed error: partial
#' data are never returned.
#'
#' @param points A data frame with `lat` and `lon` (see `openmeteo_points()`).
#' @param start_date,end_date `Date` (UTC days, both included).
#' @param apikey `NULL` (free, non-commercial API) or the API key of the
#'   customer API. Never stored.
#' @param elevation_adjust Logical, no default (see `openmeteo_query()`).
#' @param chunk_size Whole number of locations per HTTP request.
#' @param retry_wait Numeric. Seconds before the retry after an HTTP 429.
#' @return An `earthflux_openmeteo_response` (see `openmeteo_response()`).
#' @noRd
openmeteo_request <- function(points, start_date, end_date, apikey = NULL,
                              elevation_adjust, chunk_size = 100L,
                              retry_wait = 10) {
  openmeteo_check_apikey(apikey)
  query <- openmeteo_query(points, start_date, end_date, elevation_adjust)
  if (!is.numeric(chunk_size) || length(chunk_size) != 1L ||
      !is.finite(chunk_size) || chunk_size < 1 ||
      chunk_size > openmeteo_max_locations() ||
      chunk_size != round(chunk_size)) {
    openmeteo_input_abort(sprintf(
      "`chunk_size` must be a whole number in [1, %d].",
      openmeteo_max_locations()
    ))
  }
  n <- nrow(points)
  groups <- split(seq_len(n), ceiling(seq_len(n) / chunk_size))
  texts <- character(length(groups))
  public_urls <- character(length(groups))
  for (k in seq_along(groups)) {
    rows <- groups[[k]]
    q <- openmeteo_query(points[rows, , drop = FALSE], start_date, end_date,
                         elevation_adjust)
    public_urls[k] <- openmeteo_url(q, apikey, redact = TRUE)
    dest <- tempfile("openmeteo-", fileext = ".json")
    on.exit(unlink(dest), add = TRUE)
    openmeteo_download(openmeteo_url(q, apikey), public_urls[k], dest,
                       retry_wait = retry_wait)
    texts[k] <- openmeteo_read_text(dest)
  }
  json <- openmeteo_join_json(texts)
  info <- openmeteo_request_info(
    endpoint = openmeteo_endpoints()[[if (is.null(apikey)) "free" else
      "customer"]],
    query = query, apikey_used = !is.null(apikey), points = points,
    retrieved = Sys.time(), urls = public_urls
  )
  openmeteo_response(json, info)
}

#' Read a text file as one string
#'
#' @param path Character.
#' @return A single string (UTF-8).
#' @noRd
openmeteo_read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

#' Join the JSON responses of several requests into one array
#'
#' A single location is one JSON object; several are an array of objects
#' (documentation, parameter `latitude`). The pieces are joined without
#' re-encoding the numbers.
#'
#' @param texts Character vector of JSON documents.
#' @return A single string: a JSON array of location objects.
#' @noRd
openmeteo_join_json <- function(texts) {
  items <- vapply(texts, function(s) {
    s <- trimws(s)
    if (startsWith(s, "[")) {
      s <- trimws(sub("\\]$", "", sub("^\\[", "", s)))
    }
    s
  }, "", USE.NAMES = FALSE)
  paste0("[", paste(items, collapse = ","), "]")
}

#' Record of a request (without secrets)
#'
#' @param endpoint Character. Endpoint URL without query.
#' @param query Named list from `openmeteo_query()` (no key).
#' @param apikey_used Logical.
#' @param points Data frame of the requested grid points (`lat`, `lon`,
#'   optionally `in_aoi`) or `NULL`.
#' @param retrieved POSIXct. Time of the download.
#' @param urls Character. Request URLs without the key.
#' @param cache_path,cache_hit Cache file and whether it was reused.
#' @return A list.
#' @noRd
openmeteo_request_info <- function(endpoint, query, apikey_used, points,
                                   retrieved, urls = character(0),
                                   cache_path = NA_character_,
                                   cache_hit = FALSE) {
  list(
    endpoint = endpoint,
    query = query,
    apikey_used = isTRUE(apikey_used),
    points = points,
    retrieved = format(as.POSIXct(retrieved), "%Y-%m-%dT%H:%M:%SZ",
                       tz = "UTC"),
    urls = urls,
    cache_path = cache_path,
    cache_hit = cache_hit
  )
}

# Response ---------------------------------------------------------------------------

#' Parse and validate an Open-Meteo JSON response
#'
#' Accepts one location (a JSON object) or several (an array of objects).
#' Each location must have numeric `latitude`, `longitude` and `elevation`
#' ("WGS84 of the center of the weather grid-cell"; elevation used for the
#' downscaling or, with `elevation=nan`, "the average grid-cell elevation"),
#' `utc_offset_seconds`, and the objects `hourly` (with `time`) and
#' `hourly_units` (JSON return object of the documentation). An error object
#' (`"error": true` with a `reason`; documentation, Errors) is a classed
#' error.
#'
#' @param json A single string (JSON text).
#' @param request A list from `openmeteo_request_info()`.
#' @return An object of class `earthflux_openmeteo_response`: a list with
#'   `locations` (list of parsed location objects, JSON `null` kept as
#'   `NULL`), `json` (the text) and `request`.
#' @noRd
openmeteo_response <- function(json, request) {
  if (!is.character(json) || length(json) != 1L || is.na(json)) {
    openmeteo_response_abort("The Open-Meteo response must be a single JSON string.")
  }
  parsed <- tryCatch(
    jsonlite::parse_json(json, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed)) {
    openmeteo_response_abort("The Open-Meteo response is not valid JSON.")
  }
  if (!is.null(names(parsed))) {
    parsed <- list(parsed)
  }
  if (length(parsed) == 0L) {
    openmeteo_response_abort("The Open-Meteo response contains no location.")
  }
  for (loc in parsed) {
    if (!is.list(loc)) {
      openmeteo_response_abort("The Open-Meteo response has a malformed location.")
    }
    if (isTRUE(loc$error)) {
      reason <- if (is.character(loc$reason)) loc$reason[1L] else "unknown"
      openmeteo_response_abort(sprintf("Open-Meteo returned an error: %s",
                                       reason))
    }
    scalar <- function(x) is.numeric(x) && length(x) == 1L
    if (!scalar(loc$latitude) || !scalar(loc$longitude) ||
        !is.list(loc$hourly) || !is.list(loc$hourly_units) ||
        is.null(loc$hourly$time)) {
      openmeteo_response_abort(paste0(
        "The Open-Meteo response lacks `latitude`, `longitude`, `hourly` ",
        "(with `time`) or `hourly_units`."
      ))
    }
  }
  structure(list(locations = parsed, json = json, request = request),
            class = "earthflux_openmeteo_response")
}

#' Numeric series of a JSON array (null -> NA)
#'
#' @param x A list parsed from a JSON array.
#' @param what Name for the error message.
#' @return A double vector; JSON `null` gives `NA` (the record is kept).
#' @noRd
openmeteo_series <- function(x, what) {
  if (!is.list(x)) {
    x <- as.list(x)
  }
  ok <- vapply(x, function(v) {
    is.null(v) || (is.numeric(v) && length(v) == 1L)
  }, logical(1))
  if (!all(ok)) {
    openmeteo_response_abort(sprintf(
      "The Open-Meteo series `%s` has non-numeric values.", what
    ))
  }
  vapply(x, function(v) if (is.null(v)) NA_real_ else as.double(v),
         numeric(1))
}

#' Timestamps of a location (UTC)
#'
#' `timeformat=unixtime` gives seconds since 1970-01-01 00:00 UTC; the ISO
#' 8601 form (`"2019-02-15T00:00"`, the default) is local to
#' `utc_offset_seconds`, which must then be 0 (`timezone=GMT`).
#'
#' @param loc A parsed location.
#' @return POSIXct in UTC.
#' @noRd
openmeteo_times <- function(loc) {
  offset <- loc$utc_offset_seconds
  if (!is.numeric(offset) || length(offset) != 1L || offset != 0) {
    openmeteo_response_abort(paste0(
      "The Open-Meteo response is not in UTC (`utc_offset_seconds` must be ",
      "0; request timezone=GMT)."
    ))
  }
  raw <- loc$hourly$time
  unit <- loc$hourly_units$time
  if (identical(unit, "unixtime")) {
    t <- openmeteo_series(raw, "time")
    out <- as.POSIXct(t, origin = "1970-01-01", tz = "UTC")
  } else if (identical(unit, "iso8601")) {
    ok <- vapply(raw, function(v) is.character(v) && length(v) == 1L,
                 logical(1))
    if (!all(ok)) {
      openmeteo_response_abort("The Open-Meteo `time` series is malformed.")
    }
    out <- as.POSIXct(unlist(raw), format = "%Y-%m-%dT%H:%M", tz = "UTC")
  } else {
    openmeteo_response_abort(
      "The Open-Meteo `hourly_units$time` must be \"unixtime\" or \"iso8601\"."
    )
  }
  if (anyNA(out)) {
    openmeteo_response_abort("The Open-Meteo `time` series has missing or unparsable values.")
  }
  attr(out, "tzone") <- "UTC"
  out
}

#' Hourly values of one API variable of a location
#'
#' The key is the API name, or the name with the suffix `_era5` (the form of
#' multi-model responses). The unit in `hourly_units` must be the documented
#' one: units are never guessed.
#'
#' @param loc A parsed location.
#' @param api,api_unit API name and expected unit.
#' @param n Number of timestamps.
#' @return A double vector of length `n`.
#' @noRd
openmeteo_values <- function(loc, api, api_unit, n) {
  key <- intersect(c(api, paste0(api, "_era5")), names(loc$hourly))
  if (length(key) == 0L) {
    openmeteo_response_abort(sprintf(
      "The Open-Meteo response lacks the hourly variable `%s`.", api
    ))
  }
  key <- key[1L]
  unit <- loc$hourly_units[[key]]
  if (!is.character(unit) || length(unit) != 1L ||
      !identical(enc2utf8(unit), enc2utf8(api_unit))) {
    openmeteo_response_abort(sprintf(
      "Unexpected unit of `%s` in the Open-Meteo response (expected the documented unit).",
      api
    ))
  }
  v <- openmeteo_series(loc$hourly[[key]], api)
  if (length(v) != n) {
    openmeteo_response_abort(sprintf(
      "The Open-Meteo series `%s` and `time` have different lengths.", api
    ))
  }
  v
}

#' Apply the treatment of the instantaneous values to one series
#'
#' @param v Double vector (one location, regular hourly times).
#' @param treatment One of `openmeteo_instant_treatments()`.
#' @return A double vector of the same length.
#' @noRd
openmeteo_instant <- function(v, treatment) {
  switch(treatment,
    end_of_period = v,
    trapezoid = (v + c(NA_real_, v[-length(v)])) / 2
  )
}

#' Station table of virtual ERA5 stations from an Open-Meteo response
#'
#' Turns every location of the response (one ERA5 grid cell) into a virtual
#' station of the standard station table ([ef_station_table()]): station id
#' `era5_<lat>_<lon>` (cell centre, two decimals), coordinates of the cell
#' centre (WGS84), elevation reported by the API, `height_wind = 10` (wind
#' at 10 m, converted to 2 m downstream by [ef_wind_2m()], FAO-56 Eq. 47),
#' `height_temp_rh = 2`, `surface_type = "unknown"`. Observations: hourly
#' records with `timestamp` in UTC marking the end of each hour
#' (`timestamp_convention = "end"`, `interval = 3600`): `air_temperature`
#' and `dewpoint_temperature` \[degC\], `wind_speed` \[m s-1\],
#' `solar_radiation` \[W m-2\] (mean of the preceding hour, as the API
#' gives it) and `air_pressure` (hPa, converted to kPa by
#' [ef_station_table()] and recorded there). The instantaneous variables are
#' treated as `instant_values` says (`openmeteo_instant_treatments()`,
#' `CANDIDATA`). JSON `null` values become `NA` and the record is kept.
#'
#' No daily table is produced: [ef_station_ref_et()] builds the daily sums
#' from the hourly records (WF-11, WF-16).
#'
#' The gridded-forcing flag (`EF_WS_GRIDDED_FORCING`) is raised on the
#' table through its provenance: `provenance$forcing` = list(`type =
#' "gridded"`, `flags`, `flags_evaluated`, ...). It cannot go in the `flags`
#' element, which must stay empty before [ef_station_qc()], nor in
#' `provenance$flags`, which [ef_station_qc()] overwrites; the QC result and
#' [ef_station_ref_et()] keep `provenance$forcing` (the latter under
#' `provenance$station_table`).
#'
#' @param response An `earthflux_openmeteo_response`.
#' @param instant_values Character, no default: `"end_of_period"` or
#'   `"trapezoid"` (see `openmeteo_instant_treatments()`).
#' @return An `earthflux_station_table`.
#' @noRd
openmeteo_station_table <- function(response, instant_values) {
  if (!inherits(response, "earthflux_openmeteo_response")) {
    openmeteo_input_abort(
      "`response` must be an `earthflux_openmeteo_response` (see openmeteo_request())."
    )
  }
  check_method(instant_values, openmeteo_instant_treatments(),
               arg = "instant_values", call = NULL)
  req <- response$request
  locs <- response$locations
  points <- req$points
  if (!is.null(points) && nrow(points) != length(locs)) {
    openmeteo_response_abort(sprintf(
      "The Open-Meteo response has %d location(s) for %d requested.",
      length(locs), nrow(points)
    ))
  }
  vars <- openmeteo_variables()
  res <- openmeteo_grid()$resolution

  per_loc <- lapply(seq_along(locs), function(i) {
    loc <- locs[[i]]
    lat <- loc$latitude
    lon <- loc$longitude
    if (!is.null(points)) {
      if (abs(lat - points$lat[i]) > 0.01 || abs(lon - points$lon[i]) > 0.01) {
        openmeteo_response_abort(sprintf(
          paste0("Location %d of the Open-Meteo response (%.4f, %.4f) is ",
                 "not the requested grid cell (%.2f, %.2f)."),
          i, lat, lon, points$lat[i], points$lon[i]
        ))
      }
      lat <- points$lat[i]
      lon <- points$lon[i]
    } else {
      lat <- round(lat / res) * res
      lon <- round(lon / res) * res
    }
    elev <- loc$elevation
    if (!is.numeric(elev) || length(elev) != 1L || !is.finite(elev)) {
      openmeteo_response_abort(sprintf(
        "Location %d of the Open-Meteo response has no finite elevation.", i
      ))
    }
    time <- openmeteo_times(loc)
    n <- length(time)
    if (n > 1L && any(diff(as.numeric(time)) != EF_SECONDS_PER_HOUR)) {
      openmeteo_response_abort(sprintf(
        "Location %d of the Open-Meteo response is not a regular hourly series.",
        i
      ))
    }
    id <- sprintf("era5_%.2f_%.2f", lat, lon)
    obs <- data.frame(station_id = rep(id, n), timestamp = time,
                      stringsAsFactors = FALSE)
    for (k in seq_len(nrow(vars))) {
      v <- openmeteo_values(loc, vars$api[k], vars$api_unit[k], n)
      if (vars$valid_time[k] == "instant") {
        v <- openmeteo_instant(v, instant_values)
      }
      obs[[vars$variable[k]]] <- v
    }
    st <- data.frame(
      station_id = id, lon = lon, lat = lat, elevation = as.double(elev),
      height_wind = 10, height_temp_rh = 2, surface_type = "unknown",
      network = "ERA5", provider = "Open-Meteo", license = "CC BY 4.0",
      terms_url = "https://open-meteo.com/en/licence",
      name = sprintf("ERA5 cell %.2f, %.2f", lat, lon),
      notes = "Virtual station: centre of an ERA5 0.25 degree grid cell.",
      stringsAsFactors = FALSE
    )
    list(stations = st, observations = obs)
  })
  stations <- do.call(rbind, lapply(per_loc, `[[`, "stations"))
  observations <- do.call(rbind, lapply(per_loc, `[[`, "observations"))
  rownames(stations) <- NULL
  rownames(observations) <- NULL
  if (anyDuplicated(stations$station_id) > 0L) {
    openmeteo_response_abort("The Open-Meteo response repeats a grid cell.")
  }
  empty <- vapply(vars$variable, function(v) all(is.na(observations[[v]])),
                  logical(1))
  if (any(empty)) {
    openmeteo_response_abort(sprintf(
      paste0("The Open-Meteo response has no value of %s (ERA5 is published ",
             "with about 5 days of delay; check the dates)."),
      paste0("`", vars$api[empty], "`", collapse = ", ")
    ))
  }

  prov <- openmeteo_provenance(req, instant_values, stations, points)
  ef_station_table(stations, observations, prov,
                   units = list(air_pressure = "hPa"))
}

#' Provenance of a virtual station table
#'
#' @param req The request record of the response.
#' @param instant_values The treatment of the instantaneous values.
#' @param stations The stations data frame.
#' @param points The requested points (or `NULL`).
#' @return A named list (no reserved field of `ef_station_table()`, no
#'   secret).
#' @noRd
openmeteo_provenance <- function(req, instant_values, stations, points) {
  vars <- openmeteo_variables()
  retrieved <- req$retrieved
  year <- if (is.character(retrieved) && length(retrieved) == 1L &&
              !is.na(retrieved)) substr(retrieved, 1L, 4L) else
    format(Sys.Date(), "%Y")
  lic <- openmeteo_license(year, req$apikey_used)
  elevation_adjust <- is.null(req$query$elevation)
  vars$treatment <- ifelse(vars$valid_time == "instant", instant_values,
                           "as given (mean of the hour ending at timestamp)")
  in_aoi <- if (!is.null(points) && "in_aoi" %in% names(points)) {
    as.logical(points$in_aoi)
  } else {
    rep(NA, nrow(stations))
  }
  forcing <- list(
    type = "gridded",
    source = "ERA5 via Open-Meteo",
    decision = "M5-07 (dev/DECISIONS.md section 1.5)",
    virtual_stations = data.frame(
      station_id = stations$station_id, lat = stations$lat,
      lon = stations$lon, elevation = stations$elevation, in_aoi = in_aoi,
      stringsAsFactors = FALSE
    ),
    note = paste0(
      "Each station is the centre of a 0.25 degree ERA5 cell; ERA5 ",
      "compresses the daily amplitude and gives an almost uniform forcing ",
      "at valley scale (M5-07); wind and overpass-time values are not ",
      "evaluated against stations."
    )
  )
  ff <- openmeteo_forcing_flags(list(forcing = forcing))
  forcing$flags <- ff$flags
  forcing$flags_evaluated <- ff$evaluated
  list(
    timestamp_convention = "end",
    interval = EF_SECONDS_PER_HOUR,
    crs = "EPSG:4326",
    source = "Open-Meteo Historical Weather API",
    endpoint = req$endpoint,
    documentation = "https://open-meteo.com/en/docs/historical-weather-api",
    model = "era5",
    product = paste0("ERA5 hourly data on single levels from 1940 to present ",
                     "(ECMWF, Copernicus Climate Change Service), served by ",
                     "Open-Meteo"),
    product_doi = "10.24381/cds.adbb2d47",
    grid = paste0("regular longitude-latitude grid of 0.25 degree, cell ",
                  "centres at multiples of 0.25 degree"),
    request = req$query,
    request_urls = req$urls,
    apikey_used = isTRUE(req$apikey_used),
    usage = lic$usage,
    retrieved = retrieved,
    cache = list(path = req$cache_path, hit = isTRUE(req$cache_hit)),
    elevation_adjust = elevation_adjust,
    elevation_source = if (elevation_adjust) {
      paste0("90 m digital elevation model of Open-Meteo at the cell ",
             "centre; temperature and dew point downscaled to it by the API ",
             "(statistical downscaling)")
    } else {
      "mean elevation of the ERA5 grid cell (elevation=nan: no downscaling)"
    },
    instant_values = instant_values,
    variables = vars,
    network = "ERA5",
    provider = "Open-Meteo",
    license = lic$license,
    license_url = lic$license_url,
    terms_url = lic$terms_url,
    attribution = lic$attribution,
    citation = lic$citation,
    status = paste0(
      "API parameters and product facts VERIFICADA against the Open-Meteo ",
      "documentation and source code (2026-11-06); treatment of the ",
      "instantaneous values CANDIDATA"
    ),
    forcing = forcing
  )
}

# Composition with the cache ------------------------------------------------------

#' Cache key of a request
#'
#' MD5 of the canonical query (`name=value` lines in the fixed order of
#' `openmeteo_query()`), which contains neither the API key nor the
#' endpoint: the free and customer APIs return identical data.
#'
#' @param query Named list from `openmeteo_query()`.
#' @return A 32-character hexadecimal string.
#' @noRd
openmeteo_cache_key <- function(query) {
  f <- tempfile("openmeteo-key-")
  on.exit(unlink(f), add = TRUE)
  writeLines(paste0(names(query), "=", unlist(query, use.names = FALSE)), f,
             useBytes = TRUE)
  unname(tools::md5sum(f))
}

#' Hourly ERA5 forcing for a scene as a station table (with cache)
#'
#' Composition: grid points of the AOI (`openmeteo_points()`), the query for
#' the UTC days from `date - days_before` to `date + days_after`, a JSON
#' cache under `<cache_dir>/openmeteo/era5_<key>.json` keyed by the query
#' without the API key (`openmeteo_cache_key()`), the request when the
#' cache has no valid entry (written to `*.part`, parsed, then renamed), and
#' the station table (`openmeteo_station_table()`).
#'
#' The default window (two days before, one after) gives complete UTC and
#' local standard days around the scene for the daily reference ET with
#' any `utc_offset` in \[-12, 14\] h, the previous 24 hours that the
#' night-time cloudiness rules of [ef_station_ref_et()] need, and the hour
#' before the first record for `instant_values = "trapezoid"`.
#'
#' @param aoi A `SpatVector` with a CRS.
#' @param date `Date` of the scene.
#' @param elevation_adjust Logical, no default (see `openmeteo_query()`).
#' @param instant_values Character, no default (see
#'   `openmeteo_station_table()`).
#' @param apikey `NULL` or the key of the customer API (commercial use).
#' @param cache_dir Character. Cache directory (default
#'   `tools::R_user_dir("EarthFlux", "cache")`).
#' @param days_before,days_after Whole numbers of UTC days around `date`.
#' @param max_points,chunk_size,retry_wait See `openmeteo_points()` and
#'   `openmeteo_request()`.
#' @return An `earthflux_station_table` (see `openmeteo_station_table()`).
#' @noRd
openmeteo_fetch <- function(aoi, date, elevation_adjust, instant_values,
                            apikey = NULL,
                            cache_dir = openmeteo_default_cache(),
                            days_before = 2L, days_after = 1L,
                            max_points = 250L, chunk_size = 100L,
                            retry_wait = 10) {
  openmeteo_check_apikey(apikey)
  check_method(instant_values, openmeteo_instant_treatments(),
               arg = "instant_values", call = NULL)
  if (!inherits(date, "Date") || length(date) != 1L || is.na(date)) {
    openmeteo_input_abort("`date` must be a single `Date`.")
  }
  whole <- function(x) {
    is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 &&
      x == round(x)
  }
  if (!whole(days_before) || !whole(days_after)) {
    openmeteo_input_abort("`days_before` and `days_after` must be whole numbers >= 0.")
  }
  if (!is.character(cache_dir) || length(cache_dir) != 1L ||
      is.na(cache_dir) || !nzchar(cache_dir)) {
    openmeteo_input_abort("`cache_dir` must be a single directory path.")
  }
  points <- openmeteo_points(aoi, max_points = max_points)
  start_date <- date - days_before
  end_date <- date + days_after
  query <- openmeteo_query(points, start_date, end_date, elevation_adjust)
  dir <- file.path(cache_dir, "openmeteo")
  path <- file.path(dir, paste0("era5_", openmeteo_cache_key(query),
                                ".json"))
  response <- NULL
  if (file.exists(path)) {
    info <- openmeteo_request_info(
      endpoint = openmeteo_endpoints()[[if (is.null(apikey)) "free" else
        "customer"]],
      query = query, apikey_used = !is.null(apikey), points = points,
      retrieved = file.info(path)$mtime,
      urls = openmeteo_url(query, apikey, redact = TRUE),
      cache_path = path, cache_hit = TRUE
    )
    response <- tryCatch(
      openmeteo_response(openmeteo_read_text(path), info),
      earthflux_openmeteo_response_error = function(e) NULL
    )
    if (is.null(response) || length(response$locations) != nrow(points)) {
      # An invalid entry (it cannot come from this module, which validates
      # before renaming) is replaced.
      unlink(path)
      response <- NULL
    }
  }
  if (is.null(response)) {
    response <- openmeteo_request(points, start_date, end_date,
                                  apikey = apikey,
                                  elevation_adjust = elevation_adjust,
                                  chunk_size = chunk_size,
                                  retry_wait = retry_wait)
    response <- openmeteo_cache_write(response, dir, path)
  }
  openmeteo_station_table(response, instant_values)
}

#' Write a complete Open-Meteo response to the cache
#'
#' A response with any `null` value in an hourly series is returned without
#' being cached: ERA5 is published with a delay of about five days, and the
#' hours not yet available come back as `null`. Caching them would freeze
#' the gap; the next call requests the window again instead.
#'
#' @param response An `earthflux_openmeteo_response` from the API.
#' @param dir,path Cache directory and file.
#' @return The response, with `cache_path` and `cache_hit` set when cached.
#' @noRd
openmeteo_cache_write <- function(response, dir, path) {
  if (!openmeteo_response_complete(response)) {
    response$request$cache_path <- NA_character_
    response$request$cache_hit <- FALSE
    response$request$cache_skipped <- "incomplete series (null values)"
    return(response)
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  part <- paste0(path, ".part")
  on.exit(unlink(part), add = TRUE)
  writeLines(response$json, part, useBytes = TRUE)
  openmeteo_response(openmeteo_read_text(part), response$request)
  if (!file.rename(part, path)) {
    openmeteo_abort(sprintf("Could not write the cache file %s.", path))
  }
  response$request$cache_path <- path
  response$request$cache_hit <- FALSE
  response
}

#' Whether every hourly series of a response is complete (no `null`)
#'
#' @param response An `earthflux_openmeteo_response`.
#' @return `TRUE` when no hourly value of any location is `null`.
#' @noRd
openmeteo_response_complete <- function(response) {
  for (loc in response$locations) {
    for (nm in setdiff(names(loc$hourly), "time")) {
      if (any(vapply(loc$hourly[[nm]], is.null, logical(1)))) {
        return(FALSE)
      }
    }
  }
  TRUE
}
