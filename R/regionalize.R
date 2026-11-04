# Spatial forcing: regionalization orchestrator -----------------------------------
#
# Purpose: regionalize one meteorological station variable over the working
#   grid with a method chosen by the user (C1 representative station, C2
#   global regression or IDW, C3 GWR) and return an `earthflux_surface`: one
#   layer per target time, a flag word layer per target time, the fitted
#   models, the station table, flags and provenance. This is the only
#   function of the spatial module that touches terra: projection of the
#   station coordinates to the CRS of the grid, extraction of the covariates
#   at the stations and block-wise prediction (readStart/readValues,
#   writeStart/writeValues/writeStop).
#
# Specification: dev/specs/gwr-forcing.md sections 2 (contract), 5 (common
#   interface), 6.1, 6.3-6.5 (exact block prediction, extrapolation flags,
#   memory, parallelism) and 8.3-8.4; dev/specs/weather-forcing.md section
#   7.2 (input table); dev/specs/parallel-processing.md sections 3-8 (rules:
#   sequential by default, the plan belongs to the user, identical results
#   for any plan, block size and chunking, no live SpatRaster in workers,
#   future.seed, own files removed on error, execution plan in the
#   provenance); dev/specs/flags.md sections 6.3-6.7 (flag words).
#
# Parallelism: the fits (one per target time) and the prediction blocks are
#   independent tasks. When the user has set a future plan with more than
#   one worker they are evaluated with future.apply::future_lapply() (with
#   future.seed = TRUE); otherwise with lapply(). Workers receive plain
#   matrices and fitted models (top-level functions of the namespace, so
#   that no SpatRaster travels in a closure); the main process reads and
#   writes the raster blocks in order. Every value depends only on its cell
#   and on the fitted model, so the result is identical for any plan and
#   block size (benchmark: dev/benchmarks/regionalize.R).

# Variables of the regionalization ---------------------------------------------------

#' Units and physical domain of the regionalized variables
#'
#' Units of the contract (dev/specs/weather-forcing.md section 7.2) and the
#' physical domain of the predictions (dev/specs/gwr-forcing.md section 2.3;
#' impossibilities only): a prediction outside it is kept and flagged
#' `EF_GWR_OUT_OF_DOMAIN`.
#'
#' @return A data frame with `variable`, `unit`, `lower` and
#'   `lower_inclusive`.
#' @noRd
rgn_variable_info <- function() {
  data.frame(
    variable = regionalization_variables(),
    unit = c("degC", "kPa", "m s-1", "1", "W m-2", "mm h-1", "mm d-1"),
    lower = c(-EF_KELVIN_OFFSET, 0, 0, 0, 0, 0, 0),
    lower_inclusive = c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
}

#' Values outside the physical domain of a variable
#'
#' @param v Numeric vector (no `NA`).
#' @param domain One row of `rgn_variable_info()`.
#' @return Logical vector.
#' @noRd
rgn_out_of_domain <- function(v, domain) {
  if (domain$lower_inclusive) v < domain$lower else v <= domain$lower
}

#' Names of covariates derived from the surface state
#'
#' Layer names that, used as covariates, must be declared in
#' `surface_covariates` (dev/specs/gwr-forcing.md section 2.7, GW-07).
#'
#' @return Character vector (lower case).
#' @noRd
rgn_surface_state_names <- function() {
  c("lst", "ts", "surface_temperature", "ndvi", "evi", "savi", "lai",
    "albedo", "emissivity", "fvc")
}

# Input preparation --------------------------------------------------------------------

#' Validate and prepare the inputs of a regionalization
#'
#' Common to ef_regionalize() and ef_regionalize_cv(): checks the method,
#' the variable, the input table and the grid; projects the station
#' coordinates to the CRS of the grid; extracts the covariates at the
#' stations (cell containing the station, no interpolation); applies the QC
#' policy and the exclusions with their reason; and splits the stations by
#' target time (one fit per target time).
#'
#' @return A list (see the code) with the grid, the covariates, the fit
#'   inputs per target time and the station table.
#' @noRd
rgn_prepare <- function(data, variable, covariates, grid, method, use_qc,
                        surface_covariates, exclude, station_covariates,
                        call) {
  check_rgn_method(method, call)
  check_method(variable, regionalization_variables(), arg = "variable",
               call = call)
  use_qc <- rgn_check_use_qc(use_qc, call)
  if (inherits(data, "earthflux_station_qc")) {
    data <- station_regionalization_input(data, variable)
  }
  tab <- rgn_check_data(data, variable, call)
  info <- rgn_variable_info()
  info <- info[info$variable == variable, , drop = FALSE]
  reference <- NULL
  if (variable %in% c("etr_inst", "etr_24")) {
    ref <- unique(tab$reference)
    if (anyNA(ref) || length(ref) != 1L) {
      ef_abort(
        sprintf("`%s` needs a single, non-missing `reference` (alfalfa or grass).",
                variable),
        class = "earthflux_input_error", call = call
      )
    }
    reference <- ref
  }

  geom <- rgn_check_grid(covariates, grid, call)
  layers <- if (is.null(covariates)) character(0) else names(covariates)
  used <- rgn_method_covariates(method, layers)
  if (method$method == "station_lapse") {
    if (!"elevation" %in% layers) {
      ef_abort(
        "The lapse-rate variant needs a covariate layer named `elevation` [m].",
        class = "earthflux_missing_input", call = call
      )
    }
    if (variable != "air_temperature") {
      ef_abort("A lapse rate applies only to `air_temperature`.",
               class = "earthflux_input_error", call = call)
    }
  }
  if (method$method %in% c("gwr", "global_ols") && length(used) == 0L) {
    ef_abort(
      sprintf("Method \"%s\" needs `covariates` (a SpatRaster with at least one layer).",
              method$method),
      class = "earthflux_missing_input", call = call
    )
  }
  surface_covariates <- rgn_check_surface(surface_covariates, used, call)

  if (method$method %in% c("station", "station_lapse") &&
      !method$station_id %in% tab$station_id) {
    ef_abort(
      sprintf("The representative station `%s` has no record of `%s` in `data`.",
              method$station_id, variable),
      class = "earthflux_input_error", station_id = method$station_id,
      call = call
    )
  }
  exclude <- rgn_check_exclude(exclude, unique(as.character(data$station_id)),
                               call)

  # one row per station: coordinates and covariates
  sta <- tab[!duplicated(tab$station_id),
             intersect(c("station_id", "lon", "lat", "elevation"), names(tab)),
             drop = FALSE]
  rownames(sta) <- NULL
  ok_xy <- !is.na(sta$lon) & !is.na(sta$lat)
  xy <- matrix(NA_real_, nrow(sta), 2L)
  if (any(ok_xy)) {
    xy[ok_xy, ] <- terra::project(cbind(sta$lon[ok_xy], sta$lat[ok_xy]),
                                  from = "EPSG:4326", to = terra::crs(geom))
  }
  sta$x <- xy[, 1L]
  sta$y <- xy[, 2L]
  cell <- rep(NA_real_, nrow(sta))
  if (any(ok_xy)) cell[ok_xy] <- terra::cellFromXY(geom, xy[ok_xy, , drop = FALSE])
  sta$outside_grid <- ok_xy & is.na(cell)

  source <- if (length(used) == 0L) {
    "none"
  } else if (is.null(station_covariates)) {
    "raster"
  } else {
    "station_table"
  }
  covs <- matrix(NA_real_, nrow(sta), length(used),
                 dimnames = list(NULL, used))
  if (source == "raster") {
    inside <- !is.na(cell)
    if (any(inside)) {
      ext <- terra::extract(covariates[[used]], xy[inside, , drop = FALSE])
      covs[inside, ] <- as.matrix(ext[, used, drop = FALSE])
    }
  } else if (source == "station_table") {
    covs[] <- rgn_station_covariates(station_covariates, sta$station_id, used,
                                     call)
  }

  times <- sort(unique(tab$target_time))
  labels <- paste0(variable, "_", format(times, "%Y%m%dT%H%M%SZ", tz = "UTC"))
  inputs <- vector("list", length(times))
  rows <- vector("list", length(times))
  for (k in seq_along(times)) {
    tk <- tab[tab$target_time == times[k], , drop = FALSE]
    at <- match(tk$station_id, sta$station_id)
    reason <- rep(NA_character_, nrow(tk))
    add <- function(reason, mask, what) {
      what <- rep_len(what, length(reason))
      reason[mask] <- ifelse(is.na(reason[mask]), what[mask],
                             paste(reason[mask], what[mask], sep = "; "))
      reason
    }
    reason <- add(reason, !tk$qc_status %in% use_qc,
                  paste0("qc_status:", tk$qc_status))
    if (!is.null(exclude)) {
      ex <- match(tk$station_id, exclude$station_id)
      reason <- add(reason, !is.na(ex), paste0("user:", exclude$reason[ex]))
    }
    reason <- add(reason, !ok_xy[at], "missing_coordinates")
    reason <- add(reason, is.na(tk$value), "missing_value")
    if (source == "raster") {
      reason <- add(reason, sta$outside_grid[at], "outside_grid")
    }
    if (length(used) > 0L) {
      for (nm in used) {
        reason <- add(reason, !sta$outside_grid[at] & is.na(covs[at, nm]),
                      paste0("missing_covariate:", nm))
      }
    }
    is_used <- is.na(reason)
    st_rows <- data.frame(
      target_time = tk$target_time, station_id = tk$station_id,
      lon = sta$lon[at], lat = sta$lat[at],
      elevation_metadata = if ("elevation" %in% names(sta)) {
        sta$elevation[at]
      } else {
        NA_real_
      },
      x = sta$x[at], y = sta$y[at],
      qc_status = as.character(tk$qc_status),
      observed = tk$value, stringsAsFactors = FALSE
    )
    for (nm in used) st_rows[[nm]] <- covs[at, nm]
    st_rows$status <- ifelse(is_used, "used", "excluded")
    st_rows$exclusion_reason <- reason
    rows[[k]] <- st_rows
    u <- which(is_used)
    inputs[[k]] <- list(
      target_time = times[k],
      id = tk$station_id[u],
      y = tk$value[u],
      x = covs[at[u], , drop = FALSE],
      coords = cbind(sta$x[at[u]], sta$y[at[u]])
    )
  }
  table <- do.call(rbind, rows)
  rownames(table) <- NULL

  list(geom = geom, covariates = covariates, layers = layers, used = used,
       times = times, labels = labels, inputs = inputs, table = table,
       variable = variable, info = info, reference = reference,
       use_qc = use_qc, exclude = exclude, source = source,
       surface_covariates = surface_covariates)
}

#' Check the QC policy
#'
#' @param use_qc The `use_qc` argument (possibly missing).
#' @param call The call to report.
#' @return Character vector.
#' @noRd
rgn_check_use_qc <- function(use_qc, call) {
  if (missing(use_qc) || is.null(use_qc)) {
    ef_abort(
      paste0("`use_qc` must be supplied explicitly: the QC statuses that ",
             "enter the fit, among \"ok\" and \"warning\"."),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (!is.character(use_qc) || length(use_qc) == 0L || anyNA(use_qc) ||
      anyDuplicated(use_qc) > 0L || !all(use_qc %in% c("ok", "warning"))) {
    ef_abort(
      paste0("`use_qc` must contain distinct values among \"ok\" and ",
             "\"warning\" (\"excluded\" never enters a fit)."),
      class = "earthflux_input_error", call = call
    )
  }
  use_qc
}

#' Check the regionalization input table
#'
#' @param data A data frame with the columns of the regionalization input
#'   (dev/specs/weather-forcing.md section 7.2).
#' @param variable The variable to regionalize.
#' @param call The call to report.
#' @return The rows of `variable`, with `station_id` and `qc_status` as
#'   character.
#' @noRd
rgn_check_data <- function(data, variable, call) {
  if (!is.data.frame(data)) {
    ef_abort(
      paste0("`data` must be the regionalization input table (a data frame) ",
             "or the result of ef_station_qc()."),
      class = "earthflux_input_error", call = call
    )
  }
  required <- c("station_id", "lon", "lat", "target_time", "variable",
                "value", "qc_status")
  miss <- setdiff(required, names(data))
  if (length(miss) > 0L) {
    ef_abort(sprintf("`data` lacks the column(s) %s.",
                     paste0("`", miss, "`", collapse = ", ")),
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  tab <- data[as.character(data$variable) == variable, , drop = FALSE]
  if (nrow(tab) == 0L) {
    ef_abort(sprintf("`data` has no record of `%s`.", variable),
             class = "earthflux_input_error", call = call)
  }
  rownames(tab) <- NULL
  tab$station_id <- as.character(tab$station_id)
  if (anyNA(tab$station_id) || any(!nzchar(tab$station_id))) {
    ef_abort("`station_id` must not be missing or empty.",
             class = "earthflux_input_error", call = call)
  }
  if (!inherits(tab$target_time, "POSIXct") || anyNA(tab$target_time)) {
    ef_abort("`target_time` must be a POSIXct (UTC) without missing values.",
             class = "earthflux_input_error", call = call)
  }
  for (nm in c("lon", "lat", "value")) {
    check_numeric(tab[[nm]], nm, call = call)
  }
  check_in_range(tab$lon, "lon", lower = -180, upper = 180, call = call)
  check_in_range(tab$lat, "lat", lower = -90, upper = 90, call = call)
  check_in_range(tab$value, "value", call = call)
  tab$qc_status <- as.character(tab$qc_status)
  if (anyNA(tab$qc_status) ||
      !all(tab$qc_status %in% c("ok", "warning", "excluded"))) {
    ef_abort("`qc_status` must be \"ok\", \"warning\" or \"excluded\".",
             class = "earthflux_input_error", call = call)
  }
  key <- paste(tab$station_id, format(tab$target_time, "%Y%m%d%H%M%OS6",
                                      tz = "UTC"))
  if (anyDuplicated(key) > 0L) {
    ef_abort(
      sprintf(
        paste0("More than one record per station, variable and target time ",
               "(e.g. station `%s`); records are never averaged."),
        tab$station_id[anyDuplicated(key)]
      ),
      class = "earthflux_input_error", call = call
    )
  }
  coord <- unique(tab[, c("station_id", "lon", "lat")])
  if (anyDuplicated(coord$station_id) > 0L) {
    ef_abort(
      sprintf("Station `%s` has more than one location in `data`.",
              coord$station_id[anyDuplicated(coord$station_id)]),
      class = "earthflux_input_error", call = call
    )
  }
  tab
}

#' Check the grid and the covariates
#'
#' @param covariates `NULL` or a `SpatRaster`.
#' @param grid `NULL` or a `SpatRaster` template.
#' @param call The call to report.
#' @return The `SpatRaster` that defines the grid (geometry only).
#' @noRd
rgn_check_grid <- function(covariates, grid, call) {
  is_rast <- function(x) inherits(x, "SpatRaster")
  if (!is.null(covariates) && !is_rast(covariates)) {
    ef_abort("`covariates` must be NULL or a terra SpatRaster.",
             class = "earthflux_input_error", call = call)
  }
  if (!is.null(grid) && !is_rast(grid)) {
    ef_abort("`grid` must be NULL or a terra SpatRaster.",
             class = "earthflux_input_error", call = call)
  }
  if (is.null(covariates) && is.null(grid)) {
    ef_abort("Give the working grid: `covariates` or `grid`.",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  if (!is.null(covariates)) {
    nms <- names(covariates)
    if (anyNA(nms) || any(!nzchar(nms)) || anyDuplicated(nms) > 0L) {
      ef_abort("The layers of `covariates` must have unique, non-empty names.",
               class = "earthflux_input_error", call = call)
    }
    reserved <- c("(Intercept)", gwr_station_columns(), "target_time",
                  "lon", "lat", "elevation_metadata", "qc_status")
    clash <- intersect(nms, reserved)
    if (length(clash) > 0L) {
      ef_abort(sprintf("Covariate layers must not be named %s.",
                       paste0("`", clash, "`", collapse = ", ")),
               class = "earthflux_input_error", call = call)
    }
    if (!is.null(grid) &&
        !isTRUE(terra::compareGeom(covariates, grid, stopOnError = FALSE))) {
      ef_abort("`covariates` and `grid` must have the same geometry.",
               class = "earthflux_input_error", call = call)
    }
  }
  geom <- terra::rast(if (is.null(covariates)) grid else covariates,
                      nlyrs = 1L)
  if (!nzchar(terra::crs(geom))) {
    ef_abort("The grid has no coordinate reference system.",
             class = "earthflux_input_error", call = call)
  }
  if (terra::is.lonlat(geom)) {
    ef_abort(
      paste0("The grid is in geographic coordinates; Euclidean distances in ",
             "degrees are not computed. Project the grid to a CRS in metres ",
             "(decision GW-09)."),
      class = "earthflux_input_error", call = call
    )
  }
  if (!isTRUE(all.equal(terra::linearUnits(geom), 1))) {
    ef_abort("The linear unit of the CRS of the grid must be the metre.",
             class = "earthflux_input_error", call = call)
  }
  geom
}

#' Check the declaration of covariates derived from the surface state
#'
#' Decision GW-07 is open: whether covariates derived from the surface
#' state (LST, NDVI, ...) may be used has no default. The user declares
#' them explicitly; a covariate whose name is a known surface-state variable
#' and is not declared is an error.
#'
#' @param surface_covariates The argument (possibly missing).
#' @param used Covariates used by the method.
#' @param call The call to report.
#' @return Character vector of the declared covariates.
#' @noRd
rgn_check_surface <- function(surface_covariates, used, call) {
  if (missing(surface_covariates)) {
    if (length(used) > 0L) {
      ef_abort(
        paste0("`surface_covariates` must be supplied explicitly: the ",
               "covariates derived from the surface state (e.g. \"lst\"), or ",
               "character(0) if none (decision GW-07)."),
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
    return(character(0))
  }
  if (is.null(surface_covariates)) surface_covariates <- character(0)
  if (!is.character(surface_covariates) || anyNA(surface_covariates) ||
      anyDuplicated(surface_covariates) > 0L) {
    ef_abort("`surface_covariates` must be a character vector of distinct names.",
             class = "earthflux_input_error", call = call)
  }
  unknown <- setdiff(surface_covariates, used)
  if (length(unknown) > 0L) {
    ef_abort(
      sprintf("`surface_covariates` names covariates not used by the method: %s.",
              paste0("`", unknown, "`", collapse = ", ")),
      class = "earthflux_input_error", call = call
    )
  }
  undeclared <- setdiff(used[tolower(used) %in% rgn_surface_state_names()],
                        surface_covariates)
  if (length(undeclared) > 0L) {
    ef_abort(
      sprintf(
        paste0("Covariate(s) %s look derived from the surface state; declare ",
               "them in `surface_covariates` (decision GW-07, circularity risk ",
               "of dev/specs/gwr-forcing.md section 2.7)."),
        paste0("`", undeclared, "`", collapse = ", ")
      ),
      class = "earthflux_input_error", call = call
    )
  }
  surface_covariates
}

#' Check the table of stations excluded by the user
#'
#' @param exclude `NULL` or a data frame with `station_id` and `reason`.
#' @param ids Station identifiers present in `data`.
#' @param call The call to report.
#' @return `NULL` or the data frame (character columns).
#' @noRd
rgn_check_exclude <- function(exclude, ids, call) {
  if (is.null(exclude)) return(NULL)
  if (!is.data.frame(exclude) ||
      !all(c("station_id", "reason") %in% names(exclude))) {
    ef_abort(
      "`exclude` must be NULL or a data frame with columns `station_id` and `reason`.",
      class = "earthflux_input_error", call = call
    )
  }
  exclude <- data.frame(station_id = as.character(exclude$station_id),
                        reason = as.character(exclude$reason),
                        stringsAsFactors = FALSE)
  if (anyNA(exclude$station_id) || anyNA(exclude$reason) ||
      any(!nzchar(exclude$reason)) ||
      anyDuplicated(exclude$station_id) > 0L) {
    ef_abort(
      "`exclude` needs one row per station with a non-empty `reason`.",
      class = "earthflux_input_error", call = call
    )
  }
  unknown <- setdiff(exclude$station_id, ids)
  if (length(unknown) > 0L) {
    ef_abort(sprintf("`exclude` names stations absent from `data`: %s.",
                     paste0("`", unknown, "`", collapse = ", ")),
             class = "earthflux_input_error", call = call)
  }
  exclude
}

#' Covariates at the stations given by the user
#'
#' @param station_covariates A data frame with `station_id` and the
#'   covariates used.
#' @param ids Station identifiers (in order).
#' @param used Covariates used.
#' @param call The call to report.
#' @return Numeric matrix (stations x covariates), `NA` for stations absent
#'   from the table.
#' @noRd
rgn_station_covariates <- function(station_covariates, ids, used, call) {
  if (!is.data.frame(station_covariates) ||
      !all(c("station_id", used) %in% names(station_covariates))) {
    ef_abort(
      sprintf(
        "`station_covariates` must be a data frame with `station_id` and %s.",
        paste0("`", used, "`", collapse = ", ")
      ),
      class = "earthflux_input_error", call = call
    )
  }
  sid <- as.character(station_covariates$station_id)
  if (anyNA(sid) || anyDuplicated(sid) > 0L) {
    ef_abort("`station_covariates` needs one row per station.",
             class = "earthflux_input_error", call = call)
  }
  for (nm in used) {
    check_numeric(station_covariates[[nm]], nm, call = call)
    check_in_range(station_covariates[[nm]], nm, call = call)
  }
  at <- match(ids, sid)
  as.matrix(station_covariates[at, used, drop = FALSE])
}

# Task evaluation ---------------------------------------------------------------------

#' Apply a function over independent tasks
#'
#' Sequential `lapply()` unless the user has set a future plan with more
#' than one worker; then `future.apply::future_lapply()` with
#' `future.seed = TRUE` (dev/specs/parallel-processing.md, P-04 and P-05).
#' `FUN` must be a top-level function of the namespace and receive plain R
#' objects (never a live SpatRaster, P-06).
#'
#' @param X List of tasks.
#' @param FUN Function.
#' @param ... Further arguments of `FUN`.
#' @return A list.
#' @noRd
rgn_lapply <- function(X, FUN, ...) {
  if (length(X) > 1L && future::nbrOfWorkers() > 1L) {
    future.apply::future_lapply(X, FUN, ..., future.seed = TRUE)
  } else {
    lapply(X, FUN, ...)
  }
}

#' Fit one regionalization task
#'
#' @param st Fit input (one target time).
#' @param method A method object.
#' @return The fitted object.
#' @noRd
rgn_fit_task <- function(st, method) {
  rgn_fit(method, st, call = NULL)
}

#' Execution plan of a call (provenance)
#'
#' dev/specs/parallel-processing.md section 8; no host name, user or
#' absolute path is recorded.
#'
#' @param n_tasks Number of tasks.
#' @return A list.
#' @noRd
rgn_execution <- function(n_tasks) {
  topt <- terra::terraOptions(print = FALSE)
  list(
    backend = class(future::plan()),
    workers = as.integer(future::nbrOfWorkers()),
    parallel = future::nbrOfWorkers() > 1L,
    future_versions = c(
      future = as.character(utils::packageVersion("future")),
      future.apply = as.character(utils::packageVersion("future.apply"))
    ),
    seed = NULL,
    rng = paste0("No random numbers are used; parallel tasks run with ",
                 "future.seed = TRUE."),
    n_tasks = as.integer(n_tasks),
    terra_options = topt[intersect(c("memfrac", "memmax", "todisk",
                                     "datatype", "threads", "parallel"),
                                   names(topt))]
  )
}

# Block prediction ----------------------------------------------------------------------

#' Predict one block of cells for every target time
#'
#' Worker of the block prediction: plain matrices in, plain matrices out.
#'
#' @param block A list with `vals` (matrix cells x covariate layers, or
#'   `NULL`) and `xy` (cell centres \[m\]).
#' @param fits Fitted objects, one per target time.
#' @param used Covariates used by the method.
#' @param domain Row of `rgn_variable_info()`.
#' @param bits Named bits of the GWR stage (`rgn_bits()`).
#' @param chunk_rows Rows per internal chunk.
#' @return A list with `value` (cells x times) and `word` (integer, cells x
#'   times).
#' @noRd
rgn_block_task <- function(block, fits, used, domain, bits, chunk_rows) {
  n <- nrow(block$xy)
  nt <- length(fits)
  na_cell <- if (is.null(block$vals)) {
    rep(FALSE, n)
  } else {
    rowSums(is.na(block$vals)) > 0L
  }
  value <- matrix(NA_real_, n, nt)
  word <- matrix(0L, n, nt)
  word[na_cell, ] <- as.integer(2^bits[["EF_INPUT_NA"]])
  ok <- which(!na_cell)
  if (length(ok) == 0L) {
    return(list(value = value, word = word))
  }
  newx <- if (length(used) > 0L) {
    block$vals[ok, used, drop = FALSE]
  } else {
    matrix(numeric(0), length(ok), 0L)
  }
  newcoords <- block$xy[ok, , drop = FALSE]
  ood <- 2^bits[["EF_GWR_OUT_OF_DOMAIN"]]
  for (k in seq_len(nt)) {
    p <- rgn_predict(fits[[k]], newx, newcoords, chunk_rows, bits)
    out <- !is.na(p$value) & rgn_out_of_domain(p$value, domain)
    value[ok, k] <- p$value
    word[ok, k] <- as.integer(p$word + ood * out)
  }
  list(value = value, word = word)
}

#' Rows of the prediction blocks
#'
#' @param nr Number of raster rows.
#' @param block_rows User block size or `NULL`.
#' @param terra_blocks Blocks proposed by `terra::writeStart()`.
#' @param workers Number of workers of the plan.
#' @return A list with `row` and `nrows` (integer vectors) and `size`.
#' @noRd
rgn_blocks <- function(nr, block_rows, terra_blocks, workers) {
  size <- if (!is.null(block_rows)) {
    block_rows
  } else {
    s <- max(terra_blocks$nrows)
    if (workers > 1L) s <- min(s, ceiling(nr / (4L * workers)))
    s
  }
  size <- as.integer(max(1L, min(size, nr)))
  row <- seq.int(1L, nr, by = size)
  list(row = row, nrows = as.integer(pmin(size, nr - row + 1L)), size = size)
}

#' Write the surfaces and the flag words block by block
#'
#' @param prep The prepared inputs.
#' @param fits Fitted objects, one per target time.
#' @param ctrl An `earthflux_predict_control` object.
#' @param call The call to report.
#' @return A list with `surface`, `flag_word`, `counts` (matrix times x
#'   codes) and `blocks`.
#' @noRd
rgn_write_surfaces <- function(prep, fits, ctrl, call) {
  geom <- prep$geom
  nt <- length(fits)
  nr <- terra::nrow(geom)
  nc <- terra::ncol(geom)
  for (f in c(ctrl$filename, ctrl$flags_filename)) {
    if (nzchar(f) && file.exists(f) && !ctrl$overwrite) {
      ef_abort(sprintf("File `%s` exists; use `overwrite = TRUE`.",
                       basename(f)),
               class = "earthflux_input_error", call = call)
    }
  }
  out_s <- terra::rast(geom, nlyrs = nt)
  names(out_s) <- prep$labels
  out_f <- terra::rast(geom, nlyrs = nt)
  names(out_f) <- paste0("flags_", prep$labels)

  done <- FALSE
  opened <- list()
  created <- character(0)
  on.exit({
    if (!done) {
      for (r in opened) try(terra::writeStop(r), silent = TRUE)
      if (length(created) > 0L) unlink(created)
    }
  }, add = TRUE)

  wopt <- ctrl$wopt
  tb <- do.call(terra::writeStart,
                c(list(out_s, filename = ctrl$filename,
                       overwrite = ctrl$overwrite), wopt))
  opened <- list(out_s)
  if (nzchar(ctrl$filename)) created <- c(created, ctrl$filename)
  fopt <- wopt
  fopt$datatype <- "INT4S"
  do.call(terra::writeStart,
          c(list(out_f, filename = ctrl$flags_filename,
                 overwrite = ctrl$overwrite), fopt))
  opened <- list(out_s, out_f)
  if (nzchar(ctrl$flags_filename)) {
    created <- c(created, ctrl$flags_filename)
  }

  cov <- prep$covariates
  if (!is.null(cov)) {
    terra::readStart(cov)
    on.exit(terra::readStop(cov), add = TRUE)
  }
  workers <- as.integer(future::nbrOfWorkers())
  blocks <- rgn_blocks(nr, ctrl$block_rows, tb, workers)
  xs <- terra::xFromCol(geom, seq_len(nc))
  bits <- rgn_bits()
  codes <- rgn_cell_codes_all()
  counts <- matrix(0, nt, length(codes), dimnames = list(prep$labels, codes))
  batch <- if (workers > 1L) workers else 1L
  idx <- seq_along(blocks$row)
  groups <- split(idx, ceiling(idx / batch))
  read_block <- function(b) {
    row <- blocks$row[b]
    nrows <- blocks$nrows[b]
    vals <- NULL
    if (!is.null(cov)) {
      vals <- terra::readValues(cov, row = row, nrows = nrows, mat = TRUE)
      colnames(vals) <- names(cov)
    }
    ys <- terra::yFromRow(geom, seq.int(row, length.out = nrows))
    list(vals = vals, xy = cbind(rep(xs, times = nrows), rep(ys, each = nc)))
  }
  for (g in groups) {
    inputs <- lapply(g, read_block)
    res <- rgn_lapply(inputs, rgn_block_task, fits = fits, used = prep$used,
                      domain = prep$info, bits = bits,
                      chunk_rows = ctrl$chunk_rows)
    for (j in seq_along(g)) {
      b <- g[j]
      terra::writeValues(out_s, as.vector(res[[j]]$value), blocks$row[b],
                         blocks$nrows[b])
      terra::writeValues(out_f, as.vector(res[[j]]$word), blocks$row[b],
                         blocks$nrows[b])
      w <- res[[j]]$word
      for (code in codes) {
        hit <- bitwAnd(w, as.integer(2^bits[[code]])) > 0L
        dim(hit) <- dim(w)
        counts[, code] <- counts[, code] + colSums(hit)
      }
    }
  }
  surface <- terra::writeStop(out_s)
  flag_word <- terra::writeStop(out_f)
  done <- TRUE
  list(surface = surface, flag_word = flag_word, counts = counts,
       blocks = list(block_rows = blocks$size, n_blocks = length(blocks$row),
                     source = if (is.null(ctrl$block_rows)) "terra" else "user",
                     chunk_rows = ctrl$chunk_rows))
}

#' All cell-scope codes of the GWR flag word
#'
#' @return Character vector of codes ordered by bit.
#' @noRd
rgn_cell_codes_all <- function() {
  b <- rgn_bits()
  names(sort(b))
}

#' Table of bits of the GWR flag word
#'
#' A view of the registry (dev/specs/flags.md section 6.3, point 2).
#'
#' @return A data frame with `bit`, `code`, `severity` and `description`.
#' @noRd
rgn_flag_bits <- function() {
  reg <- ef_flag_registry()
  reg <- reg[reg$stage %in% c("INPUT", "GWR") & !is.na(reg$bit), ,
             drop = FALSE]
  reg <- reg[order(reg$bit), c("bit", "code", "severity", "description")]
  rownames(reg) <- NULL
  reg
}

# Orchestrator ---------------------------------------------------------------------------

#' Regionalize a station variable over the working grid
#'
#' @description
#' Fits a regionalization method to the station values of one variable at
#' each target time and predicts it exactly at every cell of the working
#' grid (dev/specs/gwr-forcing.md sections 2, 5 and 6). The method is chosen
#' with [ef_method_gwr()] (C3), [ef_method_station()] (C1),
#' [ef_method_ols()] or [ef_method_idw()] (C2); all return the same
#' `earthflux_surface`, so that the configurations of
#' dev/VALIDATION_PLAN.md section 2.2 differ only in `method`.
#'
#' Steps: (1) the station coordinates (WGS84 longitude and latitude) are
#' projected to the CRS of the grid, which must be projected in metres;
#' (2) the covariates are extracted at the stations from the same rasters
#' (cell containing the station, no interpolation) or taken from
#' `station_covariates`; (3) stations whose QC status is not in `use_qc`,
#' excluded by the user, or with a missing value, coordinate or covariate
#' are excluded with their reason (nothing is removed silently); (4) one fit
#' per target time; (5) block-wise prediction with `terra`, writing the
#' surface and a flag word per target time.
#'
#' @param data The regionalization input: a data frame with the columns
#'   `station_id`, `lon`, `lat` (decimal degrees, WGS84), `target_time`
#'   (POSIXct UTC), `variable`, `value` (unit of the contract), `qc_status`
#'   (`"ok"`, `"warning"`, `"excluded"`) and, optionally, `elevation` \[m\],
#'   `period_seconds` and `reference` (required for `etr_inst` and
#'   `etr_24`), as in dev/specs/weather-forcing.md section 7.2; or the
#'   result of [ef_station_qc()] for a variable observed at the stations.
#' @param variable Character, one of `"air_temperature"` (degC),
#'   `"vapour_pressure"` (kPa), `"wind_speed_2m"` (m s-1), `"clearness"`
#'   (-), `"solar_radiation"` (W m-2), `"etr_inst"` (mm h-1), `"etr_24"`
#'   (mm d-1).
#' @param covariates `NULL` or a `SpatRaster` on the working grid, one named
#'   layer per covariate (e.g. `elevation` \[m\], `distance_to_coast`
#'   \[km\]). GWR and the global regression use all its layers; the
#'   lapse-rate variant of C1 uses `elevation`. Cells where any layer is
#'   `NA` are outside the domain for every method (value `NA`, flag
#'   `EF_INPUT_NA`), so that the surfaces of C1, C2 and C3 cover the same
#'   cells.
#' @param method A method object from [ef_method_gwr()],
#'   [ef_method_station()], [ef_method_ols()] or [ef_method_idw()]; no
#'   default.
#' @param use_qc Character, no default: the QC statuses that enter the fits,
#'   among `"ok"` and `"warning"` (`"excluded"` never does). Recorded in the
#'   provenance.
#' @param surface_covariates Character, no default when the method uses
#'   covariates: the covariates derived from the surface state (e.g.
#'   `"lst"`, `"ndvi"`), or `character(0)` if none. Decision GW-07 is open:
#'   using them is allowed only when declared here, and they raise
#'   `EF_GWR_SURFACE_COVARIATE` (dev/specs/gwr-forcing.md section 2.7).
#' @param grid `NULL` or a `SpatRaster` template of the working grid
#'   (geometry only); required when `covariates` is `NULL`, and with the same
#'   geometry otherwise.
#' @param exclude `NULL` or a data frame with columns `station_id` and
#'   `reason`: stations excluded by the user.
#' @param station_covariates `NULL` or a data frame with `station_id` and
#'   the covariates used, to take the covariates at the stations from a
#'   table (e.g. elevation of the metadata) instead of extracting them from
#'   the rasters (dev/specs/gwr-forcing.md section 2.2, GW-10).
#' @param prediction Prediction settings from [ef_predict_control()].
#'
#' @return An object of class `c("earthflux_surface", "list")` with:
#'   * `surface`: `SpatRaster`, one layer per target time, named
#'     `<variable>_<YYYYmmddTHHMMSSZ>`, in the unit of the variable (in
#'     memory or in `prediction$filename`);
#'   * `flag_word`: integer `SpatRaster`, one layer per target time
#'     (`flags_<layer>`), with the bits of `flag_bits`: 0 = conditions
#'     evaluated and none active (dev/specs/flags.md section 6.3);
#'   * `flag_bits`: data frame `bit`, `code`, `severity`, `description`;
#'   * `uncertainty`: `NULL` (prediction variance not delivered, GW-19);
#'   * `variable`, `unit`, `target_time` (POSIXct), `method` (exact name:
#'     `"gwr"`, `"global_ols"`, `"idw"`, `"station"`, `"station_lapse"`),
#'     `method_settings` (the method object);
#'   * `diagnostics`: named list, one fitted object per target time
#'     (`earthflux_gwr`, `earthflux_ols`, `earthflux_idw` or
#'     `earthflux_station_forcing`);
#'   * `station_table`: one row per target time and station: coordinates
#'     (WGS84 and projected \[m\]), metadata elevation, QC status,
#'     observed value, covariates used, `status` (`"used"`/`"excluded"`),
#'     `exclusion_reason`, `fitted`, `residual`, `loo_fitted` and
#'     `loo_residual` (C1: error at the other stations; the representative
#'     station has `NA`);
#'   * `flags`: object and record flags (see Details);
#'   * `provenance`: method and settings, variable, unit, reference, target
#'     times, covariates and their source, surface covariates, QC policy and
#'     exclusions, CRS and distance method, prediction settings (mode, block
#'     rows, number of blocks, chunk rows, file names without directories),
#'     execution plan (future backend and workers, versions, seed, terra
#'     options, elapsed time), package versions and `flags` (registry rows,
#'     bit table, counts per layer and code, policies, flags of each fit) and
#'     `flags_evaluated`.
#'
#' @details
#' **Flags.** Cell scope, in the flag word (bits of the GWR stage,
#' dev/specs/flags.md section 6.4): `EF_INPUT_NA` (bit 0, a covariate is
#' `NA`), `EF_GWR_EXTRAPOLATION_COVARIATE` (1; GWR and OLS),
#' `EF_GWR_EXTRAPOLATION_LOCAL` (2; GWR with compact kernels),
#' `EF_GWR_OUTSIDE_HULL` (3; GWR, OLS, IDW), `EF_GWR_FEW_NEIGHBOURS` (4) and
#' `EF_GWR_LOCAL_SINGULAR` (5; GWR), and `EF_GWR_OUT_OF_DOMAIN` (6, class
#' III, `critical`): the prediction is outside the physical domain of the
#' variable (air temperature <= -273.15 degC, vapour pressure <= 0, wind
#' speed, clearness, solar radiation or daily reference ET < 0,
#' instantaneous reference ET <= 0). Out-of-domain values are **kept** and
#' flagged, never truncated; their consumers reject them with
#' `earthflux_domain_error`. Counts per layer and code are in
#' `provenance$flags$counts`. Object scope: `EF_GWR_SINGLE_STATION` (C1),
#' `EF_GWR_SURFACE_COVARIATE` (declared surface covariates) and the object
#' flags of the fits (e.g. `EF_GWR_BW_AT_BOUND`); record scope:
#' `EF_GWR_STATION_EXCLUDED` (rows of `station_table`).
#'
#' **Errors.** `earthflux_missing_input` (method, `use_qc`,
#' `surface_covariates`, grid, columns of `data`), `earthflux_input_error`
#' (duplicated records per station and target time, inconsistent station
#' locations, geographic or non-metric CRS, undeclared surface covariates,
#' unknown representative station, files that exist without `overwrite`),
#' `earthflux_domain_error` (infinite values, longitude or latitude out of
#' range) and the errors of the methods (e.g.
#' `earthflux_gwr_insufficient_stations`). Files written by a call that
#' fails are removed.
#'
#' @section Parallel processing:
#' Sequential by default. If the user has set a `future` plan with more than
#' one worker (e.g. `future::plan(future::multisession, workers = 2)`), the
#' fits (one per target time) and the prediction blocks are evaluated with
#' `future.apply::future_lapply()` (`future.seed = TRUE`); EarthFlux never
#' sets a plan nor changes `terra` or R options. The results are identical
#' for any plan, number of workers and block size; the plan used is recorded
#' in `provenance$execution`. A `SpatRaster` keeps a pointer to `terra`
#' memory: save the result with `filename` or `terra::wrap()`, not with
#' `saveRDS()` alone.
#'
#' @section Verification status:
#' Methods: see [ef_method_gwr()] (C3, `CANDIDATA (corroborada)`),
#' [ef_method_ols()], [ef_method_idw()] (`CANDIDATA`) and
#' [ef_method_station()]. Projection, extraction and block prediction are
#' design choices (dev/specs/gwr-forcing.md sections 2.1, 2.2, 6.1).
#'
#' @seealso [ef_regionalize_cv()] for cross-validation with the same
#'   inputs; [ef_gwr_fit()] and [ef_gwr_predict()] for the numeric core.
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' \donttest{
#' # Synthetic 20 x 20 km grid (UTM 19S) with elevation, and 12 stations
#' grid <- terra::rast(nrows = 20, ncols = 20, xmin = 300000, xmax = 320000,
#'                     ymin = 6100000, ymax = 6120000, crs = "EPSG:32719")
#' xy <- terra::crds(grid)
#' terra::values(grid) <- 200 + 0.02 * (xy[, 1] - 300000)
#' names(grid) <- "elevation"
#' sx <- 300500 + 1000 * c(1, 4, 8, 12, 17, 2, 6, 10, 15, 18, 5, 13)
#' sy <- 6100500 + 1000 * c(2, 15, 6, 11, 3, 9, 18, 1, 16, 8, 12, 5)
#' ll <- terra::project(cbind(sx, sy), from = "EPSG:32719", to = "EPSG:4326")
#' z <- 200 + 0.02 * (sx - 300000)
#' data <- data.frame(
#'   station_id = sprintf("S%02d", 1:12), lon = ll[, 1], lat = ll[, 2],
#'   elevation = z, target_time = as.POSIXct("2024-01-15 14:30", tz = "UTC"),
#'   period_seconds = 0L, variable = "air_temperature",
#'   value = 25 - 0.0065 * z + c(0.2, -0.1, 0.3, 0, -0.2, 0.1, 0, -0.3,
#'                               0.2, 0.1, -0.1, 0),
#'   qc_status = "ok", reference = NA_character_
#' )
#' ta <- ef_regionalize(data, "air_temperature", covariates = grid,
#'                      method = ef_method_ols(), use_qc = "ok",
#'                      surface_covariates = character(0))
#' ta
#' ta$surface
#' }
ef_regionalize <- function(data, variable, covariates, method, use_qc,
                           surface_covariates, grid = NULL, exclude = NULL,
                           station_covariates = NULL,
                           prediction = ef_predict_control()) {
  call <- sys.call()
  start <- proc.time()[["elapsed"]]
  if (missing(covariates)) {
    ef_abort(
      "`covariates` must be supplied explicitly (a SpatRaster, or NULL with `grid`).",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (!inherits(prediction, "earthflux_predict_control")) {
    ef_abort("`prediction` must be built with ef_predict_control().",
             class = "earthflux_input_error", call = call)
  }
  prep <- rgn_prepare(data, variable, covariates, grid, method, use_qc,
                      surface_covariates, exclude, station_covariates, call)

  fits <- rgn_lapply(prep$inputs, rgn_fit_task, method = method)
  names(fits) <- prep$labels
  for (k in seq_along(fits)) {
    if (inherits(fits[[k]], "earthflux_gwr")) {
      fits[[k]]$variable <- variable
      fits[[k]]$target_time <- prep$times[k]
      fits[[k]]$unit <- prep$info$unit
    }
  }
  stab <- rgn_fill_table(prep$table, fits, prep$times)

  pred <- rgn_write_surfaces(prep, fits, prediction, call)

  flags <- rgn_surface_flags(prep, method, fits, stab)
  cell_codes <- rgn_cell_codes(method)
  evaluated <- unique(c(flags$evaluated, cell_codes))
  counts <- rgn_counts_table(pred$counts, cell_codes, terra::ncell(prep$geom))
  reg <- ef_flag_registry()
  execution <- rgn_execution(length(fits))
  execution$elapsed_seconds <- proc.time()[["elapsed"]] - start

  provenance <- list(
    method = method$method,
    method_settings = unclass(method),
    variable = variable,
    unit = prep$info$unit,
    reference = prep$reference,
    target_time = prep$times,
    covariates = prep$used,
    covariate_layers = prep$layers,
    covariate_source = prep$source,
    surface_covariates = prep$surface_covariates,
    transformation = "identity",
    use_qc = prep$use_qc,
    exclude = prep$exclude,
    n_used = vapply(prep$inputs, function(st) length(st$id), integer(1)),
    n_excluded = sum(stab$status == "excluded"),
    crs = terra::crs(prep$geom),
    distance_method = "euclidean_projected",
    distance_crs = "grid",
    prediction = list(
      mode = prediction$mode,
      block_rows = pred$blocks$block_rows,
      block_source = pred$blocks$source,
      n_blocks = pred$blocks$n_blocks,
      chunk_rows = pred$blocks$chunk_rows,
      filename = basename(prediction$filename),
      flags_filename = basename(prediction$flags_filename),
      wopt = prediction$wopt
    ),
    execution = execution,
    versions = c(EarthFlux = as.character(getNamespaceVersion("EarthFlux")),
                 R = paste(R.version$major, R.version$minor, sep = "."),
                 terra = as.character(utils::packageVersion("terra"))),
    seed = NULL,
    flags = list(
      package_version = as.character(getNamespaceVersion("EarthFlux")),
      registry = reg[reg$code %in% evaluated, , drop = FALSE],
      evaluated = evaluated,
      bit_tables = rgn_flag_bits(),
      counts = counts,
      policies = list(use_qc = prep$use_qc,
                      out_of_domain = "kept_and_flagged"),
      fits = rgn_fit_flag_table(fits, prep$times)
    ),
    flags_evaluated = evaluated
  )

  out <- list(
    surface = pred$surface,
    flag_word = pred$flag_word,
    flag_bits = rgn_flag_bits(),
    uncertainty = NULL,
    variable = variable,
    unit = prep$info$unit,
    target_time = prep$times,
    method = method$method,
    method_settings = method,
    diagnostics = fits,
    station_table = stab,
    flags = flags$flags,
    provenance = provenance
  )
  new_ef_object(out, "earthflux_surface")
}

#' Fill the station table with the results of the fits
#'
#' @param table Station table of `rgn_prepare()`.
#' @param fits Fitted objects, one per target time.
#' @param times Target times.
#' @return The table with `fitted`, `residual`, `loo_fitted` and
#'   `loo_residual`.
#' @noRd
rgn_fill_table <- function(table, fits, times) {
  table$fitted <- NA_real_
  table$residual <- NA_real_
  table$loo_fitted <- NA_real_
  table$loo_residual <- NA_real_
  for (k in seq_along(fits)) {
    res <- rgn_station_results(fits[[k]])
    rows <- which(table$target_time == times[k])
    at <- match(res$station_id, table$station_id[rows])
    r <- rows[at]
    for (nm in c("fitted", "residual", "loo_fitted", "loo_residual")) {
      table[[nm]][r] <- res[[nm]]
    }
  }
  table
}

#' Object and record flags of a surface
#'
#' Derived from the provenance (single source of truth,
#' dev/specs/flags.md section 6.1): `EF_GWR_SINGLE_STATION` from the
#' method, `EF_GWR_SURFACE_COVARIATE` from the declared surface covariates,
#' `EF_GWR_STATION_EXCLUDED` from the station table, plus the object flags
#' raised by any fit.
#'
#' @return A list with `flags` and `evaluated`.
#' @noRd
rgn_surface_flags <- function(prep, method, fits, stab) {
  obj <- list(
    EF_GWR_SINGLE_STATION = method$method %in% c("station", "station_lapse"),
    EF_GWR_SURFACE_COVARIATE = length(prep$surface_covariates) > 0L
  )
  fit_codes <- character(0)
  fit_eval <- character(0)
  for (f in fits) {
    fit_eval <- c(fit_eval, f$provenance$flags_evaluated)
    for (fl in f$flags) {
      if (fl$scope == "object") fit_codes <- c(fit_codes, fl$code)
    }
  }
  fit_eval <- setdiff(unique(fit_eval), names(obj))
  reg <- ef_flag_registry()
  for (code in setdiff(fit_eval, "EF_GWR_STATION_EXCLUDED")) {
    if (grepl("object", reg$scope[reg$code == code], fixed = TRUE)) {
      obj[[code]] <- code %in% fit_codes
    }
  }
  ef_flags_combine(
    ef_flag_set(obj, scope = "object"),
    ef_flag_set(list(EF_GWR_STATION_EXCLUDED = stab$status == "excluded"),
                scope = "record")
  )
}

#' Counts of cell flags per layer and code
#'
#' @param counts Matrix times x codes.
#' @param codes Codes evaluated by the method.
#' @param n_total Cells per layer.
#' @return A data frame `layer`, `code`, `n_flagged`, `n_total`.
#' @noRd
rgn_counts_table <- function(counts, codes, n_total) {
  counts <- counts[, codes, drop = FALSE]
  data.frame(
    layer = rep(rownames(counts), times = ncol(counts)),
    code = rep(colnames(counts), each = nrow(counts)),
    n_flagged = as.numeric(counts),
    n_total = n_total,
    stringsAsFactors = FALSE
  )
}

#' Flags of the fits as a table
#'
#' @param fits Fitted objects.
#' @param times Target times.
#' @return A data frame `target_time`, `code`, `severity`, `scope`,
#'   `n_flagged`, `n_total`.
#' @noRd
rgn_fit_flag_table <- function(fits, times) {
  rows <- lapply(seq_along(fits), function(k) {
    fl <- fits[[k]]$flags
    if (length(fl) == 0L) return(NULL)
    data.frame(
      target_time = times[k],
      code = vapply(fl, `[[`, "", "code"),
      severity = vapply(fl, `[[`, "", "severity"),
      scope = vapply(fl, `[[`, "", "scope"),
      n_flagged = vapply(fl, `[[`, 0L, "n_flagged"),
      n_total = vapply(fl, `[[`, 0L, "n_total"),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    out <- data.frame(target_time = times[0], code = character(0),
                      severity = character(0), scope = character(0),
                      n_flagged = integer(0), n_total = integer(0),
                      stringsAsFactors = FALSE)
  }
  rownames(out) <- NULL
  out
}

#' @export
print.earthflux_surface <- function(x, ...) {
  cat("<earthflux_surface>\n")
  cat(sprintf("Variable: %s [%s]; method: %s; %d target time(s)\n",
              x$variable, x$unit, x$method, length(x$target_time)))
  r <- x$surface
  cat(sprintf("Grid: %d x %d cells (%s)\n", terra::nrow(r), terra::ncol(r),
              if (all(terra::inMemory(r))) "in memory" else "on disk"))
  st <- x$station_table
  cat(sprintf("Stations: %d used, %d excluded (records over all target times)\n",
              sum(st$status == "used"), sum(st$status == "excluded")))
  cnt <- x$provenance$flags$counts
  hit <- cnt[cnt$n_flagged > 0, , drop = FALSE]
  if (nrow(hit) > 0L) {
    agg <- stats::aggregate(n_flagged ~ code, data = hit, FUN = sum)
    cat("Cell flags (cells over all layers):\n")
    for (i in seq_len(nrow(agg))) {
      cat(sprintf("  %s: %d\n", agg$code[i], as.integer(agg$n_flagged[i])))
    }
  }
  if (length(x$flags) > 0L) {
    cat("Flags:\n")
    for (f in x$flags) {
      cat(sprintf("  [%s] %s (%d/%d)\n", f$severity, f$code, f$n_flagged,
                  f$n_total))
    }
  }
  invisible(x)
}

#' @export
as.data.frame.earthflux_surface <- function(x, ...) {
  x$station_table
}
