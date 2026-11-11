# High-level API: earthflux() ---------------------------------------------------
#
# Purpose: single entry point of the basic level of use (dev/ARCHITECTURE.md
#   section 6.7; decisions M5-01 ... M5-17): area, date, one weather source
#   and a preset -> actual evapotranspiration on the 1 km MODIS grid, with
#   every intermediate layer, the objects of each stage, the flags and the
#   provenance (class earthflux_result).
#
# Rules:
# - It does NOT duplicate scientific code: it orchestrates R/api-prepare.R
#   (inputs) and R/api-run.R (METRIC chain), which call the same modis_*(),
#   dem_*(), openmeteo_*() and ef_*() functions available to expert users.
#   The test "earthflux() equals the chain run step by step"
#   (tests/testthat/test-earthflux.R) checks it.
# - The preset is required (M5-04); its status, version and unverified
#   elements go to the provenance, and one classed warning lists the
#   unverified elements (M5-08).
# - Downloads are cached (`cache_dir`); the NASA Earthdata token is read
#   only from EARTHDATA_TOKEN by the download functions; the Open-Meteo key
#   (`apikey`) is never stored (only `apikey_used`).

#' Actual evapotranspiration of a scene with a preset
#'
#' @description
#' Runs the complete METRIC workflow for one area and one date: downloads
#' and prepares the MODIS surface state (Terra LST, albedo, NDVI, LAI) and
#' the NASADEM elevation model on the native 1 km MODIS grid, prepares the
#' weather forcing from a station table or from ERA5 (Open-Meteo),
#' regionalizes the reference evapotranspiration and the wind, selects the
#' anchor pixels, calibrates the sensible heat flux and returns the daily
#' actual evapotranspiration with every intermediate layer, the objects of
#' each stage, flags and provenance.
#'
#' Every scientific option is set by the **preset** (no default, decision
#' M5-04): see [ef_presets()] for the list and [ef_preset()] for every
#' option of one preset. The same computation can be run step by step with
#' the `ef_*()` functions (expert level).
#'
#' @param aoi Area of interest: a `SpatVector` of polygons in any CRS
#'   (e.g. read with `terra::vect()`). It must lie in one MODIS sinusoidal
#'   tile (tile mosaics are not assembled yet); the result is `NA` outside
#'   the polygon.
#' @param date `Date` of the scene (UTC day of the MODIS LST). No default.
#' @param weather The weather source, no default: `"era5"` for hourly ERA5
#'   data downloaded from the Open-Meteo historical weather API (no
#'   credential; CC BY 4.0, non-commercial use of the free API, decision
#'   M5-07), or an hourly station table built with [ef_station_table()].
#'   With one station its values are used over the whole area (C1); with
#'   several stations (or ERA5 cells) they are interpolated by inverse
#'   distance weighting as the preset says (C2). The stations must cover the
#'   overpass time, the local day of the scene and the 24 hours before it.
#' @param preset Character, no default: the name of a preset
#'   (`"idaho2002_elev"` or `"idaho2002_flat"`, see [ef_presets()]).
#' @param cache_dir Character. Directory of the download cache (MODIS,
#'   NASADEM and Open-Meteo files), default
#'   `tools::R_user_dir("EarthFlux", "cache")`. Valid cached files are
#'   reused without network access.
#' @param apikey `NULL` (default) or the key of the Open-Meteo customer API
#'   (commercial use), used only with `weather = "era5"`. It is sent only to
#'   the API and never stored: the provenance records `apikey_used`.
#' @param surface `NULL` (default: downloaded and prepared) or an
#'   `earthflux_surface_state` prepared beforehand with the MODIS options of
#'   the preset (expert route).
#' @param terrain `NULL` (default: downloaded and prepared) or an
#'   `earthflux_terrain` on the working grid of `surface` (expert route).
#'
#' @return An object of class `earthflux_result` (a list):
#'   * `layers`: `SpatRaster` on the working grid (MODIS sinusoidal, about
#'     1 km), `NA` outside the AOI polygon and on the cells excluded by the
#'     terrain rule of the preset, with the layers `eta_24` (daily
#'     actual ET, mm d-1), `etrf` (-), `et_inst` (mm h-1), `le`, `h`, `g`,
#'     `rn` (W m-2), `rah` (s m-1), `dt` (K), `rs_in`, `rl_in`, `rl_out`
#'     (W m-2), `tau_sw` (-), `zom` (m), `u_blend`, `u_star` (m s-1),
#'     `ts_datum` (K), `air_density` (kg m-3), `pressure` (kPa), `etr_inst`
#'     (mm h-1) and `etr_24` (mm d-1) of the reference (alfalfa);
#'   * `units`: named character vector of the units of `layers`;
#'   * `surface` (`earthflux_surface_state`), `terrain`
#'     (`earthflux_terrain`), `weather` (the station table, its QC and the
#'     reference ET of the stations, `ef_station_ref_et()`), `forcing` (the
#'     regionalized surfaces of `etr_inst`, `wind_speed_2m` and `etr_24` at
#'     their target times, the method and the mid-points), `anchors`
#'     (`earthflux_anchors` with their boundary conditions) and
#'     `h_calibration` (`earthflux_h_calibration`);
#'   * `qa`: flag words per stage, never combined bit by bit: `surface`
#'     (the words of the surface state), `forcing` (GWR stage, one layer per
#'     variable at the overpass time of each cell), `metric` (`flags_rad`,
#'     `flags_g`, `flags_h`, `flags_et`) and their `flag_bits`; on the
#'     cells excluded by the terrain rule only `flags_h` is defined (bit of
#'     `EF_H_TERRAIN_RULE_APPLIED`);
#'   * `flags`: `earthflux_flag` records of the run: object and record
#'     flags of the forcing (e.g. `EF_WS_GRIDDED_FORCING`,
#'     `EF_GWR_SINGLE_STATION`), the anchors and the calibration, and the
#'     cell flags of the METRIC chain on the cells of the grid (with
#'     `target` = layer);
#'   * `provenance`: the preset (name, version, changes between versions,
#'     status, unverified elements), every effective option, the values
#'     derived for the scene (overpass times, day and UTC offset of the
#'     daily reference ET, regionalization method, datum elevation, the
#'     reference elevation of the terrain rule, ...), the counts of excluded
#'     cells (among them `terrain_rule_excluded`, and the cells raised to
#'     the minimum z_om), the MODIS granules, the NASADEM tiles, the Open-Meteo request
#'     (without key) or the station table, attributions, the codes
#'     evaluated, versions, the `future` plan and timings.
#'
#' @details
#' Order of the workflow (dev/specs/presets.md section 2): (1) area checks
#' and refusal of areas over several MODIS tiles **before any download**;
#' (2) MODIS search, download and surface state; (3) cells outside the AOI
#' polygon and cells with a critical surface flag (albedo above 1) are
#' excluded and counted; (4) NASADEM elevation on the working grid (cells
#' below the minimum valid fraction excluded); (5) weather table (station
#' table or ERA5) and its quality control; (6) hourly and daily alfalfa
#' reference ET of the stations; (7) regionalization of the hourly
#' reference ET and wind at the hourly mid-points around the overpass and
#' of the daily reference ET; each cell takes the values at its own
#' overpass time (linear interpolation between mid-points); (8) solar
#' geometry, pressure, roughness and wind at 200 m; (9) anchors, selected
#' before the net radiation because the incoming longwave uses the
#' temperature of the cold anchor (P0-3), outside the cells excluded by the
#' terrain rule of the preset (decision M5-25: elevation more than 500 m,
#' `idaho2002_elev`, or 250 m, `idaho2002_flat`, above or below the datum
#' elevation of the calibration, i.e. the station,
#' or without one the cold calibration point of a preliminary selection;
#' those cells are not computed, are `NA` in every layer and are flagged
#' with `EF_H_TERRAIN_RULE_APPLIED`); (10) shortwave and longwave
#' radiation, net radiation, soil heat flux; (11) boundary conditions at the
#' anchors and calibration of dT; (12) LE, instantaneous ET, ETrF and daily
#' ETa. Values are never filled or truncated: excluded or undefined cells
#' are `NA` and flagged or counted.
#'
#' Errors: missing or unknown `preset` (`earthflux_missing_input`,
#' `earthflux_unknown_method`), invalid inputs (`earthflux_input_error`),
#' an AOI over several tiles (`earthflux_method_not_implemented`), weather
#' that does not cover the scene (`earthflux_weather_coverage_error`),
#' missing Earthdata token (`earthflux_credentials_error`), download
#' failures (`earthflux_download_error`), anchors without candidates
#' (`earthflux_anchor_no_candidates`) and the errors of the stages.
#'
#' @section Verification status:
#' The workflow only orchestrates; the status of each formulation is that
#' of the function used. The status of the preset as a whole (today
#' `CANDIDATA` for both) is recorded in the provenance and announced by a
#' warning of class `earthflux_unverified_preset_warning` that lists the
#' unverified elements (decision M5-08). Results are not validated
#' (milestone M6).
#'
#' @section Credentials and licences:
#' MODIS and NASADEM need a NASA Earthdata token in the environment
#' variable `EARTHDATA_TOKEN` (generate it at urs.earthdata.nasa.gov). The
#' token is never printed, stored or written to the cache. ERA5 data from
#' Open-Meteo are licensed CC BY 4.0 (attribution in the provenance); the
#' free API is for non-commercial use.
#'
#' @references
#' Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
#' (2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
#' implementation. Advanced training and users manual* (Version 1.0).
#' University of Idaho and Idaho Department of Water Resources.
#'
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' @seealso [ef_presets()], [ef_preset()]; the `ef_*()` functions for the
#'   expert level.
#' @family workflow functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Needs network access and EARTHDATA_TOKEN (NASA Earthdata).
#' aoi <- terra::vect(terra::ext(-72.8, -71.9, -36.3, -35.6),
#'                    crs = "EPSG:4326")
#' res <- earthflux(aoi, date = as.Date("2019-02-15"), weather = "era5",
#'                  preset = "idaho2002_elev")
#' res
#' summary(res)
#' plot(res)
#' }
earthflux <- function(aoi, date, weather, preset,
                      cache_dir = tools::R_user_dir("EarthFlux", "cache"),
                      apikey = NULL, surface = NULL, terrain = NULL) {
  call <- sys.call()
  started <- Sys.time()
  if (missing(preset) || is.null(preset)) {
    ef_abort(
      sprintf(paste0("`preset` must be supplied (no default, M5-04): one of ",
                     "%s; see ef_presets()."),
              paste0("\"", workflow_preset_names(), "\"", collapse = ", ")),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  check_method(preset, workflow_preset_names(), arg = "preset", call = call)
  for (nm in c("aoi", "date", "weather")) {
    if (do.call(missing, list(as.name(nm)))) {
      ef_abort(sprintf("`%s` must be supplied.", nm),
               class = c("earthflux_missing_input", "earthflux_input_error"),
               call = call)
    }
  }
  if (!inherits(date, "Date") || length(date) != 1L || is.na(date)) {
    ef_abort("`date` must be a single `Date`.",
             class = "earthflux_input_error", call = call)
  }
  if (!is.character(cache_dir) || length(cache_dir) != 1L ||
      is.na(cache_dir) || !nzchar(cache_dir)) {
    ef_abort("`cache_dir` must be a single directory path.",
             class = "earthflux_input_error", call = call)
  }
  if (!is.null(apikey)) {
    openmeteo_check_apikey(apikey)
    if (!identical(weather, "era5")) {
      ef_abort("`apikey` is used only with weather = \"era5\".",
               class = "earthflux_input_error", call = call)
    }
  }
  p <- ef_preset(preset)
  tiles <- workflow_check_aoi(aoi, call)
  if (is.character(weather)) {
    check_method(weather, "era5", arg = "weather", call = call)
  } else if (!inherits(weather, "earthflux_station_table")) {
    ef_abort(
      paste0("`weather` must be \"era5\" or a station table built with ",
             "ef_station_table()."),
      class = "earthflux_input_error", call = call
    )
  }
  if (!is.null(surface)) {
    workflow_check_surface(surface, p, call)
  }
  if (!identical(p$status, "VERIFICADA")) {
    ef_warn(
      sprintf(paste0("Preset `%s` (version %s) is %s: not every option is ",
                     "verified. Unverified elements: %s. See ",
                     "ef_preset(\"%s\")$unverified."),
              p$name, p$version, p$status,
              paste(names(p$unverified), collapse = ", "), p$name),
      class = "earthflux_unverified_preset_warning",
      preset = p$name, unverified = p$unverified, call = call
    )
  }

  # Surface state --------------------------------------------------------------
  fetch <- NULL
  if (is.null(surface)) {
    s <- workflow_surface(aoi, date, p, cache_dir)
    st <- s$state
    fetch <- s$fetch
  } else {
    st <- surface
  }
  gr <- st$provenance$granules
  if (is.data.frame(gr) && "lst" %in% gr$role &&
      !identical(gr$date[gr$role == "lst"][1L], format(date))) {
    ef_abort("The surface state is not of `date`.",
             class = "earthflux_input_error", call = call)
  }
  grid <- st$lst
  n <- terra::ncell(grid)
  val <- function(r) terra::values(r, mat = FALSE)
  in_aoi <- workflow_aoi_mask(aoi, grid)
  ex <- surface_exclusion(st)
  x <- list(lst = val(st$lst), albedo = val(st$albedo), ndvi = val(st$ndvi),
            lai = val(st$lai), emissivity = val(st$emissivity),
            doy = val(st$overpass_time$doy),
            utc_hour = val(st$overpass_time$utc_hour),
            lon = val(st$lonlat[["lon"]]), lat = val(st$lonlat[["lat"]]))
  x$albedo[ex$exclude] <- NA_real_
  for (v in names(x)) {
    x[[v]][!in_aoi] <- NA
  }
  time <- as.numeric(st$overpass_time$time)
  time[!in_aoi | is.na(x$lst)] <- NA_real_
  if (all(is.na(time))) {
    ef_abort("No cell of the area has a valid LST and overpass time.",
             class = "earthflux_input_error", call = call)
  }

  # Terrain --------------------------------------------------------------------
  ter <- workflow_terrain(aoi, grid, p, cache_dir, terrain = terrain,
                          in_aoi = in_aoi, call = call)
  x$elevation <- ter$elevation
  x$elevation[!in_aoi] <- NA_real_

  # Weather, reference ET and forcing ------------------------------------------
  wx_src <- workflow_weather(weather, aoi, date, p, apikey, cache_dir, call)
  aoi_ll <- terra::project(aoi, "EPSG:4326")
  centroid <- terra::crds(terra::centroids(terra::aggregate(aoi_ll)))
  overpass <- as.POSIXct(sort(unique(time[!is.na(time)])),
                         origin = "1970-01-01", tz = "UTC")
  wx <- workflow_reference_et(wx_src$table, p, overpass, centroid[1L, 1L],
                              call)
  fc <- workflow_forcing(wx, wx_src$table, wx_src$source, grid, time, p,
                         call)
  x$etr_inst <- fc$etr_inst
  x$etr_24 <- fc$etr_24
  x$wind_speed_2m <- fc$wind_speed_2m

  # Scene constants -------------------------------------------------------------
  stations <- wx_src$table$stations
  one <- !is.null(fc$station_id)
  sta <- if (one) stations[stations$station_id == fc$station_id, ] else NULL
  z_aoi <- x$elevation[in_aoi & !is.na(x$elevation)]
  tau_elevation <- if (one) sta$elevation else stats::median(z_aoi)
  x$search_area <- NULL
  if (one) {
    d <- terra::distance(cbind(x$lon, x$lat), cbind(sta$lon, sta$lat),
                         lonlat = TRUE)
    near <- !is.na(d[, 1L]) & d[, 1L] <= p$anchors$search_radius_m
    x$search_area <- list(near, in_aoi)
  }
  defined_forcing <- !is.na(x$etr_inst) & !is.na(x$etr_24) &
    !is.na(x$wind_speed_2m)
  x$anchor_qa <- workflow_anchor_qa(st, fc, in_aoi & defined_forcing,
                                    p$anchors$qa_exclude_codes)

  # METRIC chain (datum of Ts: the station, or the cold calibration point
  # when there is no representative station, set after the selection)
  scene <- list(tau_elevation = tau_elevation,
                datum_elevation = if (one) sta$elevation else NULL,
                etr_source = if (one) "station (C1)" else
                  paste0(fc$method, " (C2)"))
  mt <- workflow_metric(x, p, grid, scene)
  scene$datum_elevation <- mt$datum_elevation

  workflow_result(
    mt = mt, st = st, fetch = fetch, ter = ter, wx_src = wx_src, wx = wx,
    fc = fc, p = p, grid = grid, in_aoi = in_aoi, ex = ex, scene = scene,
    tiles = tiles, aoi_ll = aoi_ll, centroid = centroid, date = date,
    overpass = overpass, started = started, user_surface = !is.null(surface),
    user_terrain = !is.null(terrain)
  )
}

#' Build the earthflux_result
#'
#' @return An object of class `earthflux_result`.
#' @noRd
workflow_result <- function(mt, st, fetch, ter, wx_src, wx, fc, p, grid,
                            in_aoi, ex, scene, tiles, aoi_ll, centroid, date,
                            overpass, started, user_surface, user_terrain) {
  n <- terra::ncell(grid)
  template <- terra::rast(grid, nlyrs = 1L)
  as_layer <- function(v, name) {
    r <- terra::setValues(template, workflow_cells(v, n))
    names(r) <- name
    r
  }
  # every layer is NA outside the AOI polygon and on the cells excluded by
  # the terrain rule of the preset (scalars of the flat preset and forcing
  # layers included)
  excluded <- mt$terrain_rule$excluded & in_aoi
  computed <- in_aoi & !excluded
  layers <- terra::rast(unname(Map(function(v, nm) {
    v <- workflow_cells(v, n)
    v[!computed] <- NA_real_
    as_layer(v, nm)
  }, mt$layers, names(mt$layers))))
  units <- c(eta_24 = "mm d-1", etrf = "1", et_inst = "mm h-1",
             le = "W m-2", h = "W m-2", g = "W m-2", rn = "W m-2",
             rah = "s m-1", dt = "K", rs_in = "W m-2", rl_in = "W m-2",
             rl_out = "W m-2", tau_sw = "1", zom = "m", u_blend = "m s-1",
             u_star = "m s-1", ts_datum = "K", air_density = "kg m-3",
             pressure = "kPa", etr_inst = "mm h-1", etr_24 = "mm d-1")
  units <- units[names(mt$layers)]

  # Flag words per stage (never combined bit by bit) ---------------------------
  reg <- ef_flag_registry()
  bits_of <- function(stage) {
    b <- reg[reg$stage %in% c("INPUT", stage) & !is.na(reg$bit),
             c("bit", "code", "severity", "description")]
    b <- b[order(b$bit), ]
    rownames(b) <- NULL
    b
  }
  # the words are NA where a stage did not run (outside the AOI, cells
  # excluded by the terrain rule); the H word carries the bit of the rule
  # on the excluded cells (M5-25)
  r <- mt$records
  words <- list(
    flags_rad = workflow_flag_word(r$rs_in, computed),
    flags_g = workflow_flag_word(r$g, computed),
    flags_h = workflow_flag_word(c(r$zom, r$h), computed),
    flags_et = workflow_flag_word(r$eta_24, computed)
  )
  rule_word <- workflow_flag_word(r$terrain, excluded)
  words$flags_h[excluded] <- rule_word[excluded]
  metric_words <- terra::rast(unname(Map(as_layer, words, names(words))))
  fwords <- terra::rast(unname(Map(function(w, nm) {
    w[!in_aoi] <- NA_integer_
    as_layer(w, paste0("flags_", nm))
  }, fc$words, names(fc$words))))
  surf_words <- terra::mask(st$qa$flag_word,
                            as_layer(ifelse(in_aoi, 1, NA_real_), "aoi"))

  # Flags of the run -----------------------------------------------------------
  forcing_flags <- wx_src$table$provenance$forcing$flags
  if (is.null(forcing_flags)) forcing_flags <- list()
  gwr_flags <- list()
  seen <- character(0)
  for (v in names(fc$surfaces)) {
    for (f in fc$surfaces[[v]]$flags) {
      if (identical(f$scope, "object")) {
        if (f$code %in% seen) next
        seen <- c(seen, f$code)
      } else {
        f$target <- paste0("forcing$surfaces$", v, "$station_table")
      }
      gwr_flags <- c(gwr_flags, list(f))
    }
  }
  anchors <- mt$objects$anchors
  cal <- mt$objects$h_calibration
  obj_flags <- Filter(function(f) !identical(f$scope, "cell"), cal$flags)
  cell_flags <- unname(do.call(c, unname(r[setdiff(names(r), "terrain")])))
  cell_flags <- c(
    workflow_merge_records(if (is.null(cell_flags)) list() else cell_flags,
                           computed),
    workflow_merge_records(r$terrain, excluded)
  )
  flags <- c(unname(forcing_flags), gwr_flags, unname(anchors$flags),
             unname(obj_flags), cell_flags)
  evaluated_by_stage <- list(
    surface = st$provenance$flags_evaluated,
    weather = unique(c(wx_src$table$provenance$forcing$flags_evaluated,
                       wx$qc$provenance$flags_evaluated,
                       wx$ref$provenance$flags_evaluated)),
    forcing = unique(unlist(lapply(fc$surfaces, function(s)
      s$provenance$flags_evaluated))),
    anchors = anchors$provenance$flags_evaluated,
    metric = mt$evaluated
  )

  # Provenance -------------------------------------------------------------------
  tprov <- wx_src$table$provenance
  weather_prov <- if (wx_src$source == "era5") {
    list(source = tprov$source, endpoint = tprov$endpoint,
         model = tprov$model, product = tprov$product,
         product_doi = tprov$product_doi, request = tprov$request,
         request_urls = tprov$request_urls, apikey_used = tprov$apikey_used,
         retrieved = tprov$retrieved, cache = tprov$cache,
         elevation_adjust = tprov$elevation_adjust,
         instant_values = tprov$instant_values, license = tprov$license,
         attribution = tprov$attribution, citation = tprov$citation,
         usage = tprov$usage, forcing = tprov$forcing)
  } else {
    tprov
  }
  modis_prov <- if (is.null(fetch)) {
    list(source = "surface state supplied by the user (expert route)",
         granules = st$provenance$granules)
  } else {
    fetch$provenance
  }
  terrain_prov <- ter$object$provenance
  if (user_terrain) {
    terrain_prov <- c(list(supplied_by_user = TRUE), terrain_prov)
  }
  cnt_eta <- sum(!is.na(mt$layers$eta_24))
  attribution <- c(
    modis = paste0("MODIS collection 6.1 (NASA LP DAAC): ",
                   paste(unique(stats::na.omit(st$provenance$granules$doi)),
                         collapse = ", ")),
    nasadem = if (!is.null(terrain_prov$doi)) {
      paste0("NASADEM_HGT v001 (NASA LP DAAC), doi:", terrain_prov$doi)
    } else {
      NA_character_
    },
    weather = if (wx_src$source == "era5") {
      paste(tprov$attribution, collapse = " ")
    } else {
      paste0("Station table: ", if (is.null(tprov$source)) "user data" else
        tprov$source)
    }
  )
  options <- unclass(p)
  provenance <- list(
    fun = "earthflux",
    preset = list(name = p$name, version = p$version, status = p$status,
                  source = p$source, decisions = p$decisions,
                  changes = p$changes, unverified = p$unverified),
    options = options,
    scene = list(
      date = format(date),
      aoi = list(crs = terra::crs(aoi_ll, describe = TRUE)$code,
                 bbox_lonlat = as.vector(terra::ext(aoi_ll)),
                 centroid_lonlat = as.vector(centroid[1L, ])),
      tiles = tiles$tile,
      grid = list(nrow = terra::nrow(grid), ncol = terra::ncol(grid),
                  res = terra::res(grid),
                  extent = as.vector(terra::ext(grid)),
                  crs = terra::crs(grid, proj = TRUE)),
      overpass_range = format(range(overpass), "%Y-%m-%d %H:%M:%S UTC",
                              tz = "UTC"),
      n_overpass_times = length(overpass),
      weather_source = wx_src$source,
      humidity = wx$humidity,
      utc_offset = wx$utc_offset,
      reference_et_day = format(wx$day),
      hourly_mid_points = format(fc$mid, "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
      daily_target_time = format(fc$day_time, "%Y-%m-%d %H:%M:%S UTC",
                                 tz = "UTC"),
      regionalization_method = fc$method,
      representative_station = fc$station_id,
      stations_excluded = fc$excluded,
      stations_used = setdiff(wx_src$table$stations$station_id,
                              fc$excluded$station_id),
      tau_elevation = if (identical(p$radiation$tau_elevation,
                                    "pixel (elevation model)")) NULL else
        scene$tau_elevation,
      datum_elevation = scene$datum_elevation,
      terrain_rule = list(
        reference_elevation = mt$terrain_rule$reference_elevation,
        reference_source = mt$terrain_rule$reference_source,
        max_elevation_difference =
          mt$terrain_rule$max_elevation_difference
      ),
      rl_in_cold_temperature = unname(mt$t_rl[["t_cold"]]),
      rl_in_cold_elevation = unname(mt$t_rl[["z_cold"]]),
      lambda = mt$objects$lambda,
      search_area = if (is.null(fc$station_id)) "AOI" else
        sprintf("%g m around station %s, then the AOI",
                p$anchors$search_radius_m, fc$station_id),
      user_supplied = c(surface = user_surface, terrain = user_terrain)
    ),
    counts = c(
      cells = terra::ncell(grid),
      in_aoi = sum(in_aoi),
      outside_aoi = sum(!in_aoi),
      surface_critical_excluded = sum(ex$exclude & in_aoi),
      ter$counts,
      fc$counts,
      zom_floor_applied = mt$zom_floor_applied,
      terrain_rule_excluded = sum(excluded),
      eta_24_valid = cnt_eta
    ),
    surface_critical_by_code = ex$counts,
    sources = list(modis = modis_prov, terrain = terrain_prov,
                   weather = weather_prov),
    attribution = attribution,
    flags_evaluated = unique(unlist(evaluated_by_stage, use.names = FALSE)),
    flags_evaluated_by_stage = evaluated_by_stage,
    versions = list(
      earthflux = as.character(getNamespaceVersion("EarthFlux")),
      terra = as.character(utils::packageVersion("terra")),
      r = R.version.string
    ),
    execution = list(
      future_plan = class(future::plan())[1L],
      started = format(started, "%Y-%m-%d %H:%M:%S %Z"),
      elapsed_seconds = as.numeric(difftime(Sys.time(), started,
                                            units = "secs"))
    ),
    spec = "dev/specs/presets.md; dev/ARCHITECTURE.md 6.7"
  )
  storage.mode(provenance$counts) <- "integer"

  new_ef_object(
    list(
      layers = layers,
      units = units,
      surface = st,
      terrain = ter$object,
      weather = list(source = wx_src$source, table = wx_src$table,
                     qc = wx$qc, reference_et = wx$ref),
      forcing = list(surfaces = fc$surfaces, method = fc$method,
                     representative_station = fc$station_id,
                     mid_points = fc$mid, daily_target_time = fc$day_time),
      anchors = anchors,
      h_calibration = cal,
      qa = list(surface = surf_words, forcing = fwords,
                metric = metric_words,
                flag_bits = list(surface = st$qa$flag_bits,
                                 forcing = fc$flag_bits,
                                 rad = bits_of("RAD"), g = bits_of("G"),
                                 h = bits_of("H"), et = bits_of("ET"))),
      date = date,
      preset = p,
      flags = flags,
      provenance = provenance
    ),
    "earthflux_result"
  )
}
