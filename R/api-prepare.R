# High-level API: input preparation of earthflux() ------------------------------
#
# Purpose: assemble validated, unit-consistent inputs of the METRIC chain on
#   the working grid (the native 1 km MODIS sinusoidal grid of the LST,
#   MP-08) from an area of interest, a date, a weather source and a preset
#   (dev/ARCHITECTURE.md sections 4 and 6.7; dev/specs/presets.md). No
#   science is written here: every quantity comes from the modis_*(),
#   dem_*(), openmeteo_*() and ef_*() functions; this file only adapts their
#   outputs to each other (gaps of dev/specs/presets.md section 6).
#
# Contents (all internal):
#   workflow_check_aoi()        AOI checks and single-tile refusal
#   workflow_surface()          modis_fetch() + modis_surface_state()
#   workflow_terrain()          dem_fetch() on the working grid
#   workflow_aoi_mask()         cells of the working grid in the AOI polygon
#   workflow_weather()          station table: user's, or ERA5 (Open-Meteo)
#   workflow_reference_et()     QC and hourly / daily reference ET
#   workflow_forcing()          regionalization + per-cell overpass values
#   workflow_regionalization_input()  ETr / wind series -> ef_regionalize()
#   workflow_interp_cells()     per-cell linear interpolation in time
#
# Conventions: layers of the working grid are handled as numeric vectors in
#   terra cell order (row-major from the top left cell); the METRIC core
#   receives wide matrices (rows and columns of the grid) built by
#   workflow_matrix() in R/api-run.R.

# Area of interest ----------------------------------------------------------------

#' Check the area of interest and refuse several MODIS tiles
#'
#' Runs before any download (dev/specs/presets.md 6, gap 8): the surface
#' state reads one tile per product and tile mosaics are not assembled
#' (M4-19), so an AOI over several sinusoidal tiles is refused here with the
#' error class of `modis_fetch()`.
#'
#' @param aoi The `aoi` argument of `earthflux()`.
#' @param call The call to report.
#' @return The tiles (`modis_tiles_for_aoi()`), invisibly.
#' @noRd
workflow_check_aoi <- function(aoi, call) {
  if (!inherits(aoi, "SpatVector") ||
      !identical(terra::geomtype(aoi), "polygons") || nrow(aoi) < 1L) {
    ef_abort("`aoi` must be a SpatVector of polygons (any CRS).",
             class = "earthflux_input_error", call = call)
  }
  if (!nzchar(terra::crs(aoi))) {
    ef_abort("`aoi` has no coordinate reference system.",
             class = "earthflux_input_error", call = call)
  }
  tiles <- modis_tiles_for_aoi(aoi)
  if (nrow(tiles) > 1L) {
    ef_abort(
      sprintf(paste0("The area of interest needs %d MODIS tiles (%s); ",
                     "earthflux() reads one tile and tile mosaics are not ",
                     "assembled yet (M4-19). Split the area by tile."),
              nrow(tiles), paste(tiles$tile, collapse = ", ")),
      class = c("earthflux_method_not_implemented",
                "earthflux_unknown_method", "earthflux_input_error"),
      method = "multi_tile", choices = "single_tile", call = call
    )
  }
  invisible(tiles)
}

#' Cells of the working grid inside the AOI polygon
#'
#' `modis_surface_state()` crops to the extent of the AOI only; the result of
#' `earthflux()` is `NA` outside the polygon (US-01, criterion 2). A cell is
#' inside when the polygon touches it (`terra::rasterize(touches = TRUE)`),
#' the rule of the example scene (M4-26).
#'
#' @param aoi A `SpatVector` of polygons.
#' @param grid The working grid (`SpatRaster`).
#' @return Logical vector in terra cell order.
#' @noRd
workflow_aoi_mask <- function(aoi, grid) {
  v <- terra::project(aoi, terra::crs(grid))
  r <- terra::rasterize(v, terra::rast(grid, nlyrs = 1L), field = 1,
                        touches = TRUE, background = 0)
  terra::values(r, mat = FALSE) == 1
}

# Surface state ---------------------------------------------------------------------

#' MODIS surface state of a scene
#'
#' @param aoi,date,cache_dir See `earthflux()`.
#' @param preset An `earthflux_preset`.
#' @return A list with `state` (`earthflux_surface_state`) and `fetch`
#'   (`earthflux_modis_fetch`).
#' @noRd
workflow_surface <- function(aoi, date, preset, cache_dir) {
  fetch <- modis_fetch(aoi, date, lst_product = preset$modis$lst_product,
                       cache_dir = cache_dir,
                       collection = preset$modis$collection)
  options <- do.call(modis_surface_options, preset$modis$surface_options)
  state <- modis_surface_state(fetch$files, aoi = aoi, options = options)
  list(state = state, fetch = fetch)
}

#' Check a surface state supplied by the user (expert route)
#'
#' @param surface The `surface` argument of `earthflux()`.
#' @param preset An `earthflux_preset`.
#' @param call The call to report.
#' @return `surface`, invisibly.
#' @noRd
workflow_check_surface <- function(surface, preset, call) {
  if (!inherits(surface, "earthflux_surface_state")) {
    ef_abort("`surface` must be an `earthflux_surface_state` or NULL.",
             class = "earthflux_input_error", call = call)
  }
  methods <- surface$provenance$methods
  if (!is.null(methods)) {
    want <- preset$modis$surface_options
    for (nm in c("lst_product", "albedo_method", "emissivity_method",
                 "ndvi_source", "qa_policy")) {
      if (!identical(methods[[nm]], want[[nm]])) {
        ef_abort(
          sprintf(paste0("`surface` was built with %s = \"%s\"; preset `%s` ",
                         "uses \"%s\"."), nm, format(methods[[nm]]),
                  preset$name, format(want[[nm]])),
          class = "earthflux_input_error", call = call
        )
      }
    }
  }
  invisible(surface)
}

# Terrain ------------------------------------------------------------------------------

#' Elevation model on the working grid
#'
#' `dem_fetch()` with the method and water treatment of the preset, then
#' the minimum valid fraction of the preset: cells whose elevation-model
#' support is below it are set to `NA` and counted (nothing is filled).
#' The slope and aspect used by the presets are 0 (flat projection,
#' RC-09).
#'
#' @param aoi,cache_dir See `earthflux()`.
#' @param grid The working grid.
#' @param preset An `earthflux_preset`.
#' @param terrain `NULL` or an `earthflux_terrain` supplied by the user.
#' @param in_aoi Logical per cell: the cells counted.
#' @param call The call to report.
#' @return A list with `object` (`earthflux_terrain`), `elevation` (numeric,
#'   terra cell order, `NA` where invalid) and `counts` (cells of the AOI).
#' @noRd
workflow_terrain <- function(aoi, grid, preset, cache_dir, terrain = NULL,
                             in_aoi = TRUE, call = NULL) {
  if (is.null(terrain)) {
    terrain <- dem_fetch(aoi, grid = grid, method = preset$terrain$dem_method,
                         water = preset$terrain$water, cache_dir = cache_dir)
  }
  if (!inherits(terrain, "earthflux_terrain") ||
      !inherits(terrain$terrain, "SpatRaster") ||
      !all(c("elevation", "valid_fraction") %in% names(terrain$terrain))) {
    ef_abort("`terrain` must be an `earthflux_terrain` (see dem_fetch()).",
             class = "earthflux_input_error", call = call)
  }
  if (!isTRUE(terra::compareGeom(terrain$terrain, grid, stopOnError = FALSE))) {
    ef_abort("The terrain is not on the working grid (the LST grid).",
             class = c("earthflux_modis_grid_error", "earthflux_input_error"),
             call = call)
  }
  z <- terra::values(terrain$terrain[["elevation"]], mat = FALSE)
  vf <- terra::values(terrain$terrain[["valid_fraction"]], mat = FALSE)
  low <- !is.na(z) & (is.na(vf) | vf < preset$terrain$min_valid_fraction)
  z[low] <- NA_real_
  list(object = terrain, elevation = z,
       counts = c(dem_na = sum(is.na(z) & !low & in_aoi),
                  dem_below_min_valid_fraction = sum(low & in_aoi)))
}

# Weather ---------------------------------------------------------------------------------

#' Station table of the scene
#'
#' `weather = "era5"`: `openmeteo_fetch()` with the ERA5 options of the
#' preset (M5-15). Otherwise the user's `ef_station_table()`, which must be
#' hourly.
#'
#' @param weather,aoi,date,apikey,cache_dir See `earthflux()`.
#' @param preset An `earthflux_preset`.
#' @param call The call to report.
#' @return A list with `table` (`earthflux_station_table`) and `source`
#'   (`"era5"` or `"stations"`).
#' @noRd
workflow_weather <- function(weather, aoi, date, preset, apikey, cache_dir,
                             call) {
  if (is.character(weather)) {
    check_method(weather, "era5", arg = "weather", call = call)
    era5 <- preset$weather$era5
    table <- openmeteo_fetch(aoi, date,
                             elevation_adjust = era5$elevation_adjust,
                             instant_values = era5$instant_values,
                             apikey = apikey, cache_dir = cache_dir)
    return(list(table = table, source = "era5"))
  }
  if (!inherits(weather, "earthflux_station_table")) {
    ef_abort(
      paste0("`weather` must be \"era5\" or a station table built with ",
             "ef_station_table()."),
      class = "earthflux_input_error", call = call
    )
  }
  if (!is.null(apikey)) {
    ef_abort("`apikey` is used only with weather = \"era5\".",
             class = "earthflux_input_error", call = call)
  }
  interval <- weather$provenance$interval
  if (!is.numeric(interval) || length(interval) != 1L ||
      interval != EF_SECONDS_PER_HOUR) {
    ef_abort(
      paste0("The station table must have hourly records (provenance ",
             "`interval` = 3600 s): the instantaneous reference ET needs ",
             "hourly values (WF-09)."),
      class = "earthflux_input_error", call = call
    )
  }
  list(table = weather, source = "stations")
}

#' Humidity variable of a station table
#'
#' The first column available among those of the preset (vapour pressure,
#' dew point, relative humidity) with at least one value.
#'
#' @param table An `earthflux_station_table`.
#' @param preset An `earthflux_preset`.
#' @param call The call to report.
#' @return A single string.
#' @noRd
workflow_humidity <- function(table, preset, call) {
  obs <- table$observations
  for (v in preset$weather$humidity) {
    if (v %in% names(obs) && any(!is.na(obs[[v]]))) {
      return(v)
    }
  }
  ef_abort(
    sprintf("The station table has no humidity (%s).",
            paste0("`", preset$weather$humidity, "`", collapse = ", ")),
    class = c("earthflux_missing_input", "earthflux_input_error"),
    call = call
  )
}

#' Quality control and reference ET of the stations
#'
#' `ef_station_qc()` and `ef_station_ref_et()` with the options of the
#' preset. The day of the daily sum is the mean solar day of the AOI
#' centroid (`utc_offset` = longitude / 15 h, M5-16) that contains the
#' median overpass time; `overpass` is the range of the overpass times of
#' the scene (audit of the station values and of
#' `EF_WS_OVERPASS_OUTSIDE_RECORDS`; the cells take their own time in
#' `workflow_forcing()`).
#'
#' @param table An `earthflux_station_table`.
#' @param preset An `earthflux_preset`.
#' @param overpass POSIXct overpass times of the valid cells.
#' @param centroid_lon Longitude of the AOI centroid \[degrees\].
#' @param call The call to report.
#' @return A list with `qc`, `ref` (`earthflux_station_ref_et`), `day`
#'   (Date), `utc_offset` and `humidity`.
#' @noRd
workflow_reference_et <- function(table, preset, overpass, centroid_lon,
                                  call) {
  qc <- ef_station_qc(table, qc_policy = preset$weather$qc_policy)
  humidity <- workflow_humidity(qc, preset, call)
  utc_offset <- unname(as.numeric(centroid_lon)) / 15
  mid <- stats::median(as.numeric(overpass))
  day <- as.Date(as.POSIXct(mid + utc_offset * EF_SECONDS_PER_HOUR,
                            origin = "1970-01-01", tz = "UTC"))
  o <- preset$reference_et
  ref <- ef_station_ref_et(
    qc, reference = o$reference, timestep = o$timestep,
    standard = o$standard, humidity = humidity,
    day_definition = o$day_definition,
    day_completeness = o$day_completeness, daytime_rule = o$daytime_rule,
    night_cloudiness = o$night_cloudiness,
    overpass = range(overpass), inst_method = o$inst_method,
    dates = day, utc_offset = utc_offset
  )
  list(qc = qc, ref = ref, day = day, utc_offset = utc_offset,
       humidity = humidity)
}

# Regionalization ---------------------------------------------------------------------

#' Regionalization input from the reference ET of the stations
#'
#' Adapter of dev/specs/presets.md 6 (gap 2): `ef_station_ref_et()` gives
#' series and daily sums, `ef_regionalize()` takes the long table of
#' dev/specs/weather-forcing.md section 7.2. Hourly values (reference ET
#' rate in mm h-1 as `etr_inst`, wind at 2 m as `wind_speed_2m`) are taken
#' at the mid-points `times` of their periods (`period_seconds` = 3600);
#' the daily sum (`etr_24`) at the middle of the day in the day definition
#' (`period_seconds` = 86400). `qc_status` is `"ok"`: the values excluded by
#' the QC policy are already `NA` in the series and missing values are
#' excluded by `ef_regionalize()` with their reason.
#'
#' @param ref An `earthflux_station_ref_et`.
#' @param stations The stations data frame of the station table.
#' @param variable `"etr_inst"`, `"wind_speed_2m"` or `"etr_24"`.
#' @param times POSIXct mid-points (hourly variables).
#' @param day_time POSIXct target time of the daily sum.
#' @return A data frame.
#' @noRd
workflow_regionalization_input <- function(ref, stations, variable, times,
                                           day_time) {
  if (variable == "etr_24") {
    d <- ref$etr_24
    tab <- data.frame(station_id = d$station_id, target_time = day_time,
                      period_seconds = 86400L, value = d$etr_24,
                      stringsAsFactors = FALSE)
  } else {
    s <- ref$series
    keep <- s$target_time %in% times
    col <- if (variable == "etr_inst") "et_ref" else "wind_speed_2m"
    tab <- data.frame(station_id = s$station_id[keep],
                      target_time = s$target_time[keep],
                      period_seconds = 3600L, value = s[[col]][keep],
                      stringsAsFactors = FALSE)
    # every station gets every time: a missing record is a missing value
    grid <- expand.grid(station_id = unique(stations$station_id),
                        target_time = times, stringsAsFactors = FALSE)
    key <- paste(tab$station_id, as.numeric(tab$target_time))
    at <- match(paste(grid$station_id, as.numeric(grid$target_time)), key)
    tab <- data.frame(station_id = grid$station_id,
                      target_time = grid$target_time,
                      period_seconds = 3600L, value = tab$value[at],
                      stringsAsFactors = FALSE)
  }
  i <- match(tab$station_id, stations$station_id)
  tab$lon <- stations$lon[i]
  tab$lat <- stations$lat[i]
  tab$elevation <- stations$elevation[i]
  tab$variable <- variable
  tab$qc_status <- "ok"
  tab$reference <- if (variable == "wind_speed_2m") NA_character_ else
    ref$reference
  tab[, c("station_id", "lon", "lat", "elevation", "target_time",
          "period_seconds", "variable", "value", "qc_status", "reference")]
}

#' Linear interpolation in time of regionalized layers, per cell
#'
#' Option O3 applied cell by cell (dev/specs/presets.md 6, gap 1): the
#' value of a cell at its own overpass time is interpolated linearly
#' between the layers of the two mid-points that bracket it. The layers of
#' the flag words of both mid-points are combined with a bitwise OR (the
#' worst case of the two fits). No extrapolation: a time outside the
#' mid-points gives `NA`.
#'
#' @param values Numeric matrix, cells x mid-points.
#' @param words Integer matrix of flag words, cells x mid-points.
#' @param mid Numeric mid-points (seconds), increasing.
#' @param t Numeric overpass time of each cell (seconds), `NA` allowed.
#' @return A list with `value` and `word` (one per cell).
#' @noRd
workflow_interp_cells <- function(values, words, mid, t) {
  n <- length(t)
  out <- rep(NA_real_, n)
  word <- rep(NA_integer_, n)
  k <- length(mid)
  if (k == 1L) {
    hit <- !is.na(t) & t == mid
    out[hit] <- values[hit, 1L]
    word[hit] <- words[hit, 1L]
    return(list(value = out, word = word))
  }
  j <- findInterval(t, mid, rightmost.closed = TRUE)
  ok <- !is.na(t) & j >= 1L & j < k
  cells <- which(ok)
  jj <- j[ok]
  w <- (t[ok] - mid[jj]) / (mid[jj + 1L] - mid[jj])
  v1 <- values[cbind(cells, jj)]
  v2 <- values[cbind(cells, jj + 1L)]
  out[ok] <- v1 + w * (v2 - v1)
  word[ok] <- bitwOr(words[cbind(cells, jj)], words[cbind(cells, jj + 1L)])
  list(value = out, word = word)
}

#' Mask of a bit in a flag word, read by code
#'
#' @param word Integer vector of flag words (`NA` allowed).
#' @param bits The `flag_bits` table of the word.
#' @param codes Codes whose bits are tested.
#' @return Logical vector (`FALSE` where `word` is `NA`).
#' @noRd
workflow_word_has <- function(word, bits, codes) {
  b <- bits$bit[bits$code %in% codes]
  hit <- rep(FALSE, length(word))
  for (x in b) {
    hit <- hit | (!is.na(word) & bitwAnd(word, bitwShiftL(1L, x)) != 0L)
  }
  hit
}

#' Regionalized forcing of every cell at its overpass time
#'
#' Regionalizes the hourly reference ET and wind at the hourly mid-points
#' that bracket the overpass times of the scene, and the daily reference
#' ET, with the method of the preset (C1 with one usable station, C2 IDW
#' otherwise); then interpolates each cell to its own overpass time
#' (`workflow_interp_cells()`) and masks the out-of-domain bit of the
#' fits (`EF_GWR_OUT_OF_DOMAIN`, critical) before the core (P0-11),
#' counting the cells.
#'
#' @param wx Result of `workflow_reference_et()`.
#' @param table The station table (`earthflux_station_table`).
#' @param source `"era5"` or `"stations"`.
#' @param grid The working grid.
#' @param t Numeric overpass time of each cell (seconds, UTC), `NA` where
#'   the cell is not computed.
#' @param preset An `earthflux_preset`.
#' @param call The call to report.
#' @return A list: `etr_inst`, `wind_speed_2m`, `etr_24` (numeric per
#'   cell), `words` (integer per cell, one per variable), `flag_bits`,
#'   `surfaces` (the three `earthflux_surface`), `method` (`"station"` or
#'   `"idw"`), `station_id` (C1), `excluded` (stations excluded by the
#'   preset), `mid` (POSIXct mid-points), `day_time`, `counts`.
#' @noRd
workflow_forcing <- function(wx, table, source, grid, t, preset, call) {
  stations <- table$stations
  excluded <- NULL
  if (source == "era5" && isTRUE(preset$weather$era5$exclude_sea_cells)) {
    sea <- stations$elevation == preset$weather$era5$sea_elevation
    if (any(sea)) {
      excluded <- data.frame(
        station_id = stations$station_id[sea],
        reason = "ERA5 cell at elevation 0 m (open sea), preset choice M5-15",
        stringsAsFactors = FALSE
      )
    }
  }
  usable_ids <- setdiff(stations$station_id, excluded$station_id)

  tt <- t[!is.na(t)]
  if (length(tt) == 0L) {
    ef_abort("No cell of the scene has a valid overpass time.",
             class = "earthflux_input_error", call = call)
  }
  # hourly mid-points (hh:30 for hourly records ending at hh:00) bracketing
  # the overpass times of the scene
  series_mid <- sort(unique(as.numeric(wx$ref$series$target_time)))
  lo <- max(series_mid[series_mid <= min(tt)], -Inf)
  hi <- min(series_mid[series_mid >= max(tt)], Inf)
  if (!is.finite(lo) || !is.finite(hi)) {
    ef_abort(
      paste0("The weather records do not cover the overpass times of the ",
             "scene (no hourly mid-point before and after them)."),
      class = c("earthflux_weather_coverage_error", "earthflux_input_error"),
      call = call
    )
  }
  mid_num <- series_mid[series_mid >= lo & series_mid <= hi]
  mid <- as.POSIXct(mid_num, origin = "1970-01-01", tz = "UTC")
  day_time <- as.POSIXct(as.numeric(as.POSIXct(wx$day, tz = "UTC")) +
                           (12 - wx$utc_offset) * EF_SECONDS_PER_HOUR,
                         origin = "1970-01-01", tz = "UTC")

  inputs <- list(
    etr_inst = workflow_regionalization_input(wx$ref, stations, "etr_inst",
                                              mid, day_time),
    wind_speed_2m = workflow_regionalization_input(wx$ref, stations,
                                                   "wind_speed_2m", mid,
                                                   day_time),
    etr_24 = workflow_regionalization_input(wx$ref, stations, "etr_24", mid,
                                            day_time)
  )
  one <- length(usable_ids) == 1L
  # Coverage (dev/specs/presets.md 6, gap 11): every target time needs a
  # usable value at enough stations (1 for C1, 2 for IDW), checked here
  # with a clear message.
  n_needed <- if (one) 1L else 2L
  n_valid <- vapply(inputs, function(d) {
    d <- d[d$station_id %in% usable_ids, , drop = FALSE]
    if (nrow(d) == 0L) return(0L)
    as.integer(min(tapply(!is.na(d$value), as.numeric(d$target_time), sum)))
  }, integer(1))
  if (any(n_valid < n_needed)) {
    bad <- names(n_valid)[n_valid < n_needed]
    ef_abort(
      sprintf(paste0("No usable weather value of %s at some target time: ",
                     "the stations must cover the overpass time, the local ",
                     "day of the daily reference ET (%s, UTC offset %+.2f h) ",
                     "and the 24 hours before (night cloudiness)."),
              paste0("`", bad, "`", collapse = ", "), format(wx$day),
              wx$utc_offset),
      class = c("earthflux_weather_coverage_error", "earthflux_input_error"),
      variables = bad, call = call
    )
  }
  method <- if (one) {
    ef_method_station(usable_ids)
  } else {
    ef_method_idw(power = preset$weather$idw_power)
  }
  template <- terra::rast(grid, nlyrs = 1L)
  surfaces <- lapply(names(inputs), function(v) {
    ef_regionalize(inputs[[v]], v, covariates = NULL, method = method,
                   use_qc = preset$weather$use_qc,
                   surface_covariates = preset$weather$surface_covariates,
                   grid = template, exclude = excluded)
  })
  names(surfaces) <- names(inputs)

  bits <- surfaces$etr_inst$flag_bits
  out <- list()
  words <- list()
  counts <- integer(0)
  for (v in names(surfaces)) {
    s <- surfaces[[v]]
    vals <- terra::values(s$surface, mat = TRUE)
    wd <- terra::values(s$flag_word, mat = TRUE)
    storage.mode(wd) <- "integer"
    if (v == "etr_24") {
      x <- list(value = vals[, 1L], word = wd[, 1L])
      x$value[is.na(t)] <- NA_real_
      x$word[is.na(t)] <- NA_integer_
    } else {
      x <- workflow_interp_cells(vals, wd, mid_num, t)
    }
    ood <- workflow_word_has(x$word, bits, "EF_GWR_OUT_OF_DOMAIN")
    x$value[ood] <- NA_real_
    counts[[paste0(v, "_out_of_domain")]] <- sum(ood)
    out[[v]] <- x$value
    words[[v]] <- x$word
  }
  c(out, list(words = words, flag_bits = bits, surfaces = surfaces,
              method = method$method,
              station_id = if (one) usable_ids else NULL,
              excluded = excluded, mid = mid, day_time = day_time,
              counts = counts))
}
