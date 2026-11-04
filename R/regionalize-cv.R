# Spatial forcing: cross-validation of the regionalization ------------------------
#
# Purpose: deterministic spatial block folds and out-of-fold predictions at
#   the stations for every regionalization method, with the same folds for
#   C1, C2 and C3 so that their errors can be compared pairwise
#   (dev/VALIDATION_PLAN.md sections 2.2-2.6, level N1).
#
# Specification: dev/specs/gwr-forcing.md sections 8.1 (LOOCV: the
#   leave-one-out residuals of every method are in the station table of
#   ef_regionalize()), 8.2 (spatial block CV, re-selection of the bandwidth
#   inside each fold by default, failed folds reported) and 8.3
#   (reproducibility); dev/specs/parallel-processing.md (folds as tasks).
#   The metrics (RMSE, MAE, bias) belong to validation.R (M6); this file
#   returns the long table they consume.

#' Spatial block folds of stations
#'
#' @description
#' Deterministic folds for spatial block cross-validation
#' (dev/specs/gwr-forcing.md section 8.2): each station is assigned to the
#' square tile
#' \deqn{(i_x, i_y) = \left(\left\lfloor \frac{x - x_0}{L} \right\rfloor,
#'   \left\lfloor \frac{y - y_0}{L} \right\rfloor\right)}{(ix, iy) =
#'   (floor((x - x0) / L), floor((y - y0) / L))}
#' of side L = `block_size` \[m\] and origin \eqn{(x_0, y_0)}{(x0, y0)};
#' every non-empty tile is a fold, numbered by \eqn{i_y}{iy} and then
#' \eqn{i_x}{ix}. No random numbers are used.
#'
#' @param coords Projected station coordinates \[m\]: a numeric matrix or
#'   data frame with two columns (x, y), optionally with the station
#'   identifiers as row names; a data frame with columns `station_id`, `x`
#'   and `y` (e.g. the `station_table` of an `earthflux_surface`); or a
#'   `terra` `SpatVector` of points (identifiers from its `station_id`
#'   attribute, if any).
#' @param block_size Positive number: side L of the tiles \[m\], no default
#'   (to be justified with the scale of the autocorrelation of the residuals,
#'   decision GW-20).
#' @param origin `NULL` or a numeric vector `c(x0, y0)` \[m\]; `NULL` uses the
#'   smallest x and y of the stations. Recorded in the result.
#'
#' @return An integer vector of folds, one per station (named by station
#'   when identifiers are available; a station listed more than once must
#'   have the same coordinates), with attributes `block_size`, `origin` and
#'   `tile` (data frame `ix`, `iy`).
#'
#' @details
#' Errors: `earthflux_input_error` (coordinates not numeric or missing,
#' inconsistent duplicates), `earthflux_domain_error` (non-positive or
#' infinite block size).
#'
#' @references
#' Roberts, D. R., Bahn, V., Ciuti, S., Boyce, M. S., Elith, J.,
#' Guillera-Arroita, G., Hauenstein, S., Lahoz-Monfort, J. J., Schröder,
#' B., Thuiller, W., Warton, D. I., Wintle, B. A., Hartig, F., & Dormann,
#' C. F. (2017). Cross-validation strategies for data with temporal,
#' spatial, hierarchical, or phylogenetic structure. *Ecography*, 40(8),
#' 913-929. \doi{10.1111/ecog.02881} (cited by the specification; not
#' read).
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' xy <- data.frame(station_id = c("A", "B", "C", "D"),
#'                  x = c(1000, 4000, 12000, 26000),
#'                  y = c(2000, 9000, 3000, 21000))
#' ef_spatial_folds(xy, block_size = 10000)
ef_spatial_folds <- function(coords, block_size, origin = NULL) {
  call <- sys.call()
  if (missing(block_size)) {
    ef_abort("`block_size` [m] must be supplied explicitly.",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  check_scalar(block_size, "block_size", lower = 0, lower_inclusive = FALSE,
               call = call)
  pts <- rgn_fold_coords(coords, call)
  if (is.null(origin)) {
    origin <- c(min(pts$x), min(pts$y))
  } else {
    if (!is.numeric(origin) || length(origin) != 2L || anyNA(origin)) {
      ef_abort("`origin` must be NULL or two numbers c(x0, y0) [m].",
               class = "earthflux_input_error", call = call)
    }
    check_in_range(origin, "origin", call = call)
  }
  origin <- stats::setNames(as.numeric(origin), c("x", "y"))
  ix <- floor((pts$x - origin[["x"]]) / block_size)
  iy <- floor((pts$y - origin[["y"]]) / block_size)
  key <- paste(iy, ix)
  tiles <- unique(data.frame(ix = ix, iy = iy))
  tiles <- tiles[order(tiles$iy, tiles$ix), , drop = FALSE]
  fold <- as.integer(match(key, paste(tiles$iy, tiles$ix)))
  if (!is.null(pts$id)) names(fold) <- pts$id
  structure(fold,
            block_size = as.numeric(block_size),
            origin = origin,
            tile = data.frame(ix = as.integer(ix), iy = as.integer(iy)))
}

#' Coordinates of the stations for the folds
#'
#' @param coords See [ef_spatial_folds()].
#' @param call The call to report.
#' @return A list with `id` (or `NULL`), `x` and `y`.
#' @noRd
rgn_fold_coords <- function(coords, call) {
  id <- NULL
  if (inherits(coords, "SpatVector")) {
    if (terra::geomtype(coords) != "points") {
      ef_abort("A SpatVector `coords` must contain points.",
               class = "earthflux_input_error", call = call)
    }
    if ("station_id" %in% names(coords)) {
      id <- as.character(coords$station_id)
    }
    coords <- terra::crds(coords)
  } else if (is.data.frame(coords) &&
             all(c("station_id", "x", "y") %in% names(coords))) {
    id <- as.character(coords$station_id)
    coords <- as.matrix(coords[, c("x", "y")])
  } else if (is.data.frame(coords) || is.matrix(coords)) {
    id <- rownames(coords)
    if (is.data.frame(coords) && identical(id, as.character(seq_len(nrow(coords))))) {
      id <- NULL
    }
    if (is.data.frame(coords)) {
      if (!all(vapply(coords, is.numeric, logical(1)))) {
        ef_abort("All columns of `coords` must be numeric.",
                 class = "earthflux_input_error", call = call)
      }
      coords <- as.matrix(coords)
    }
  }
  if (!is.matrix(coords) || !is.numeric(coords) || ncol(coords) != 2L ||
      nrow(coords) == 0L) {
    ef_abort(
      "`coords` must give two projected coordinates (x, y) [m] per station.",
      class = "earthflux_input_error", call = call
    )
  }
  if (anyNA(coords)) {
    ef_abort("`coords` must not contain missing values.",
             class = "earthflux_input_error", call = call)
  }
  check_in_range(coords, "coords", call = call)
  x <- as.numeric(coords[, 1L])
  y <- as.numeric(coords[, 2L])
  if (!is.null(id)) {
    if (anyNA(id)) {
      ef_abort("Station identifiers must not be missing.",
               class = "earthflux_input_error", call = call)
    }
    first <- !duplicated(id)
    same <- x == x[first][match(id, id[first])] &
      y == y[first][match(id, id[first])]
    if (!all(same)) {
      ef_abort("A station is listed with different coordinates.",
               class = "earthflux_input_error", call = call)
    }
    id <- id[first]
    x <- x[first]
    y <- y[first]
  }
  list(id = id, x = x, y = y)
}

#' Check the folds of a cross-validation
#'
#' @param folds Named whole-number vector (names = station identifiers,
#'   e.g. from [ef_spatial_folds()]) or a data frame with `station_id` and
#'   `fold`.
#' @param call The call to report.
#' @return A data frame `station_id`, `fold` (integer).
#' @noRd
rgn_check_folds <- function(folds, call) {
  if (missing(folds) || is.null(folds)) {
    ef_abort(
      "`folds` must be supplied explicitly (e.g. from ef_spatial_folds()).",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (is.data.frame(folds)) {
    if (!all(c("station_id", "fold") %in% names(folds))) {
      ef_abort("A data frame `folds` needs columns `station_id` and `fold`.",
               class = "earthflux_input_error", call = call)
    }
    tab <- data.frame(station_id = as.character(folds$station_id),
                      fold = folds$fold, stringsAsFactors = FALSE)
  } else {
    if (!is.numeric(folds) || is.null(names(folds))) {
      ef_abort(
        "`folds` must be a vector of folds named by station, or a data frame.",
        class = "earthflux_input_error", call = call
      )
    }
    tab <- data.frame(station_id = names(folds), fold = as.vector(folds),
                      stringsAsFactors = FALSE)
  }
  if (!is.numeric(tab$fold) || anyNA(tab$fold) || anyNA(tab$station_id) ||
      any(tab$fold != round(tab$fold)) ||
      anyDuplicated(tab$station_id) > 0L) {
    ef_abort(
      "`folds` needs one whole-number fold per station, without missing values.",
      class = "earthflux_input_error", call = call
    )
  }
  tab$fold <- as.integer(tab$fold)
  tab
}

#' Cross-validate a regionalization at the stations
#'
#' @description
#' Out-of-fold predictions at the stations for one variable and method
#' (dev/specs/gwr-forcing.md section 8.2): for every target time and fold,
#' the method is fitted with the stations of the other folds and predicted
#' at the stations of the fold, with their own covariates and coordinates.
#' Inputs, QC policy and exclusions are those of [ef_regionalize()], so the
#' same call with another `method` gives paired predictions over the same
#' folds (configurations C1, C2 and C3 of dev/VALIDATION_PLAN.md section
#' 2.2).
#'
#' @inheritParams ef_regionalize
#' @param folds The folds of the stations: a whole-number vector named by
#'   station (e.g. from [ef_spatial_folds()]) or a data frame with
#'   `station_id` and `fold`. Every station used in a fit needs a fold;
#'   folds of size one give leave-one-out cross-validation with re-selection.
#' @param reselect_bandwidth Logical. `TRUE` (default of the specification):
#'   the GWR bandwidth (method with `criterion`) or the IDW power (several
#'   values) is selected again inside each training set (nested). `FALSE`:
#'   selected once per target time with all the stations and kept fixed in
#'   the folds; the CV is then conditional on that selection (optimistic),
#'   as recorded in the provenance. Without a selection it has no effect.
#'
#' @return An object of class `c("earthflux_regionalization_cv", "list")`
#'   with:
#'   * `predictions`: long data frame with one row per target time and
#'     station used: `station_id`, `fold`, `variable`, `target_time`,
#'     `observed`, `predicted`, `residual` (observed - predicted), `method`,
#'     `status` (`"ok"`, `"failed"`: the fold could not be fitted, with
#'     `reason`; or `"representative_station"`: C1 does not evaluate its own
#'     station), `reason`, `n_train` (stations of the training set),
#'     `tuning` (GWR bandwidth \[m or neighbours\] or IDW power used in the
#'     fold; `NA` otherwise) and `flag_word` (flag word of the prediction at
#'     the station, bits of [ef_regionalize()]);
#'   * `folds`: data frame `station_id`, `fold`;
#'   * `station_table`: stations used and excluded per target time, with the
#'     reason;
#'   * `variable`, `method`, `method_settings`, `reselect_bandwidth`;
#'   * `flags`, `provenance` (selection rule, folds rule, QC policy, number
#'     of folds and of failed folds, execution plan, versions,
#'     `flags_evaluated`).
#'   `as.data.frame()` returns `predictions`.
#'
#' @details
#' Failed folds (e.g. too few training stations for GWR,
#' `earthflux_gwr_insufficient_stations`, or no feasible bandwidth) are
#' reported in `predictions` with `status = "failed"` and the condition in
#' `reason`; they are never dropped silently. The metrics (RMSE, MAE, bias)
#' are computed by the validation module from this table.
#'
#' @section Parallel processing:
#' The (target time, fold) tasks are evaluated with
#' `future.apply::future_lapply()` when the user has set a `future` plan
#' with more than one worker, and with `lapply()` otherwise; the result is
#' identical. EarthFlux never sets a plan.
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' \donttest{
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
#'   target_time = as.POSIXct("2024-01-15 14:30", tz = "UTC"),
#'   variable = "air_temperature",
#'   value = 25 - 0.0065 * z + c(0.2, -0.1, 0.3, 0, -0.2, 0.1, 0, -0.3,
#'                               0.2, 0.1, -0.1, 0),
#'   qc_status = "ok"
#' )
#' folds <- ef_spatial_folds(data.frame(station_id = data$station_id,
#'                                      x = sx, y = sy), block_size = 10000)
#' cv <- ef_regionalize_cv(data, "air_temperature", covariates = grid,
#'                         method = ef_method_ols(), folds = folds,
#'                         use_qc = "ok", surface_covariates = character(0))
#' head(as.data.frame(cv))
#' }
ef_regionalize_cv <- function(data, variable, covariates, method, folds,
                              use_qc, surface_covariates,
                              reselect_bandwidth = TRUE, grid = NULL,
                              exclude = NULL, station_covariates = NULL) {
  call <- sys.call()
  start <- proc.time()[["elapsed"]]
  if (missing(covariates)) {
    ef_abort(
      "`covariates` must be supplied explicitly (a SpatRaster, or NULL with `grid`).",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  check_flag_scalar(reselect_bandwidth, "reselect_bandwidth", call)
  fold_tab <- rgn_check_folds(folds, call)
  prep <- rgn_prepare(data, variable, covariates, grid, method, use_qc,
                      surface_covariates, exclude, station_covariates, call)
  used_ids <- unique(prep$table$station_id[prep$table$status == "used"])
  lacking <- setdiff(used_ids, fold_tab$station_id)
  if (length(lacking) > 0L) {
    ef_abort(sprintf("`folds` has no fold for the station(s) %s.",
                     paste0("`", lacking, "`", collapse = ", ")),
             class = "earthflux_input_error", call = call)
  }

  selects <- (method$method == "gwr" && !is.null(method$criterion)) ||
    (method$method == "idw" && length(method$power) > 1L)
  selection <- if (!selects) {
    "not_applicable"
  } else if (reselect_bandwidth) {
    "nested_in_each_fold"
  } else {
    "conditional_on_all_stations"
  }
  representative <- if (method$method %in% c("station", "station_lapse")) {
    method$station_id
  } else {
    NULL
  }

  tasks <- list()
  for (k in seq_along(prep$inputs)) {
    st <- prep$inputs[[k]]
    if (length(st$id) == 0L) next
    m_k <- method
    if (selects && !reselect_bandwidth) {
      m_k <- rgn_fixed_selection(method, st)
    }
    fold_k <- fold_tab$fold[match(st$id, fold_tab$station_id)]
    for (f in sort(unique(fold_k))) {
      test <- fold_k == f & !st$id %in% representative
      train <- fold_k != f | st$id %in% representative
      if (!any(test)) next
      tasks[[length(tasks) + 1L]] <- list(
        target_time = st$target_time, fold = f, method = m_k,
        train = rgn_subset_input(st, train),
        test = rgn_subset_input(st, test)
      )
    }
  }
  bits <- rgn_bits()
  res <- rgn_lapply(tasks, rgn_cv_task, domain = prep$info, bits = bits)
  rows <- res
  if (!is.null(representative)) {
    for (k in seq_along(prep$inputs)) {
      st <- prep$inputs[[k]]
      s <- match(representative, st$id)
      if (is.na(s)) next
      rows[[length(rows) + 1L]] <- rgn_cv_rows(
        st$target_time, fold_tab$fold[fold_tab$station_id == representative],
        rgn_subset_input(st, seq_along(st$id) == s), NA_real_,
        "representative_station", NA_character_, NA_integer_, NA_real_,
        NA_integer_
      )
    }
  }
  pred <- do.call(rbind, rows)
  if (is.null(pred)) {
    pred <- rgn_cv_rows(prep$times[0], integer(0),
                        list(id = character(0), y = numeric(0)), numeric(0),
                        character(0), character(0), integer(0), numeric(0),
                        integer(0))
  }
  pred$variable <- variable
  pred$method <- method$method
  pred <- pred[order(pred$target_time, pred$fold, pred$station_id),
               c("station_id", "fold", "variable", "target_time", "observed",
                 "predicted", "residual", "method", "status", "reason",
                 "n_train", "tuning", "flag_word")]
  rownames(pred) <- NULL

  fl <- ef_flags_combine(
    ef_flag_set(list(
      EF_GWR_SINGLE_STATION = !is.null(representative),
      EF_GWR_SURFACE_COVARIATE = length(prep$surface_covariates) > 0L
    ), scope = "object"),
    ef_flag_set(list(EF_GWR_STATION_EXCLUDED =
                       prep$table$status == "excluded"), scope = "record")
  )
  execution <- rgn_execution(length(tasks))
  execution$elapsed_seconds <- proc.time()[["elapsed"]] - start
  fold_attr <- if (!is.data.frame(folds)) {
    list(block_size = attr(folds, "block_size"), origin = attr(folds, "origin"))
  } else {
    list(block_size = NULL, origin = NULL)
  }
  out <- list(
    predictions = pred,
    folds = fold_tab[fold_tab$station_id %in% used_ids, , drop = FALSE],
    station_table = prep$table,
    variable = variable,
    method = method$method,
    method_settings = method,
    reselect_bandwidth = reselect_bandwidth,
    flags = fl$flags,
    provenance = list(
      method = method$method,
      method_settings = unclass(method),
      variable = variable,
      unit = prep$info$unit,
      target_time = prep$times,
      covariates = prep$used,
      covariate_source = prep$source,
      surface_covariates = prep$surface_covariates,
      use_qc = prep$use_qc,
      exclude = prep$exclude,
      selection = selection,
      folds = c(list(rule = if (is.null(fold_attr$block_size)) "user" else
        "square_tiles"), fold_attr),
      n_folds = length(unique(fold_tab$fold[fold_tab$station_id %in% used_ids])),
      n_tasks = length(tasks),
      n_failed = sum(vapply(res, function(r) any(r$status == "failed"),
                            logical(1))),
      representative_station = representative,
      crs = terra::crs(prep$geom),
      distance_method = "euclidean_projected",
      execution = execution,
      versions = c(EarthFlux = as.character(getNamespaceVersion("EarthFlux")),
                   R = paste(R.version$major, R.version$minor, sep = "."),
                   terra = as.character(utils::packageVersion("terra"))),
      seed = NULL,
      flags_evaluated = fl$evaluated
    )
  )
  new_ef_object(out, "earthflux_regionalization_cv")
}

#' Subset the stations of a fit input
#'
#' @param st Fit input.
#' @param keep Logical vector.
#' @return Fit input with the stations kept.
#' @noRd
rgn_subset_input <- function(st, keep) {
  list(target_time = st$target_time, id = st$id[keep], y = st$y[keep],
       x = st$x[keep, , drop = FALSE],
       coords = st$coords[keep, , drop = FALSE])
}

#' Method with the selection fixed on all the stations of a fit
#'
#' Used with `reselect_bandwidth = FALSE`: the bandwidth (GWR) or power
#' (IDW) is selected once with all the stations and given to the folds.
#'
#' @param method A method object with a selection.
#' @param st Fit input with all the stations.
#' @return A method object with a fixed bandwidth or power.
#' @noRd
rgn_fixed_selection <- function(method, st) {
  fit <- rgn_fit(method, st, call = NULL)
  if (method$method == "gwr") {
    ef_method_gwr(method$kernel, adaptive = method$adaptive,
                  bandwidth = fit$bandwidth$value,
                  min_neighbours = method$search$min_neighbours,
                  scale_covariates = method$scale_covariates)
  } else {
    ef_method_idw(fit$power)
  }
}

#' Rows of the cross-validation table
#'
#' @return A data frame (without `variable` and `method`).
#' @noRd
rgn_cv_rows <- function(target_time, fold, test, predicted, status, reason,
                        n_train, tuning, flag_word) {
  n <- length(test$id)
  data.frame(
    station_id = test$id,
    fold = rep_len(as.integer(fold), n),
    target_time = rep(target_time, length.out = n),
    observed = test$y,
    predicted = rep_len(as.numeric(predicted), n),
    residual = test$y - rep_len(as.numeric(predicted), n),
    status = rep_len(as.character(status), n),
    reason = rep_len(as.character(reason), n),
    n_train = rep_len(as.integer(n_train), n),
    tuning = rep_len(as.numeric(tuning), n),
    flag_word = rep_len(as.integer(flag_word), n),
    stringsAsFactors = FALSE
  )
}

#' Fit one fold and predict its stations
#'
#' A failed fit (an `earthflux_error`) gives rows with `status = "failed"`
#' and the condition in `reason`.
#'
#' @param task A list with `target_time`, `fold`, `method`, `train`,
#'   `test`.
#' @param domain Row of `rgn_variable_info()`.
#' @param bits Named bits of the GWR stage.
#' @return A data frame (see `rgn_cv_rows()`).
#' @noRd
rgn_cv_task <- function(task, domain, bits) {
  n_train <- length(task$train$id)
  tryCatch({
    fit <- rgn_fit(task$method, task$train, call = NULL)
    p <- rgn_predict(fit, task$test$x, task$test$coords, bits = bits)
    out <- !is.na(p$value) & rgn_out_of_domain(p$value, domain)
    word <- p$word + as.integer(out) * 2L^bits[["EF_GWR_OUT_OF_DOMAIN"]]
    rgn_cv_rows(task$target_time, task$fold, task$test, p$value, "ok",
                NA_character_, n_train, rgn_tuning(fit), word)
  }, earthflux_error = function(e) {
    rgn_cv_rows(task$target_time, task$fold, task$test, NA_real_, "failed",
                paste0(class(e)[1L], ": ", conditionMessage(e)), n_train,
                NA_real_, NA_integer_)
  })
}

#' @export
print.earthflux_regionalization_cv <- function(x, ...) {
  p <- x$predictions
  cat("<earthflux_regionalization_cv>\n")
  cat(sprintf("Variable: %s; method: %s; %d fold(s); selection: %s\n",
              x$variable, x$method, x$provenance$n_folds,
              x$provenance$selection))
  ok <- p$status == "ok"
  cat(sprintf("Predictions: %d ok, %d failed, %d not evaluated\n",
              sum(ok), sum(p$status == "failed"),
              sum(p$status == "representative_station")))
  invisible(x)
}

#' @export
as.data.frame.earthflux_regionalization_cv <- function(x, ...) {
  x$predictions
}
