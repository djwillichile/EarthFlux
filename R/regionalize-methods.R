# Spatial forcing: regionalization methods and prediction control ---------------
#
# Purpose: validated objects that describe how a station variable is
#   regionalized (C1 representative station, C2 global regression or IDW, C3
#   GWR; dev/VALIDATION_PLAN.md section 2.2) and how the grid is predicted,
#   plus the internal dispatch that fits a method at the stations and
#   predicts it at new locations with one common interface
#   (dev/specs/gwr-forcing.md section 5.1).
#
# Specification: dev/specs/gwr-forcing.md sections 5 (common interface, C1,
#   C2, C3), 6.1 (exact block prediction) and 9.1 (signatures); names from
#   dev/NAMING.md (regionalization table: ef_predict_control() replaces
#   ef_prediction_control()).
#
# Files of the orchestration:
#   regionalize-methods.R    ef_method_*(), ef_predict_control(), dispatch
#                            of fit and prediction (this file)
#   regionalize-baselines.R  C1 (representative station, with an optional
#                            lapse rate) and C2 (global OLS, IDW) engines
#   regionalize.R            ef_regionalize(): data, projection, covariate
#                            extraction, exclusions, block prediction with
#                            terra, earthflux_surface
#   regionalize-cv.R         ef_spatial_folds(), ef_regionalize_cv()
#
# The scientific choices of every method have no default (decisions GW-04,
# GW-05, GW-21; T-15): kernel, bandwidth type, criterion or bandwidth, the
# representative station, the lapse rate and the IDW power are always given
# by the user.

# Method objects ---------------------------------------------------------------------

#' Build a regionalization method object
#'
#' @param method Character. Exact method name recorded in the provenance.
#' @param ... Settings of the method.
#' @return A list of class
#'   `c("earthflux_regionalization_method", "list")`.
#' @noRd
new_rgn_method <- function(method, ...) {
  structure(list(method = method, ...),
            class = c("earthflux_regionalization_method", "list"))
}

#' Regionalization by geographically weighted regression (C3)
#'
#' @description
#' Describes a GWR regionalization for [ef_regionalize()] and
#' [ef_regionalize_cv()] (configuration C3, dev/specs/gwr-forcing.md section
#' 5.5): local weighted least squares on the covariates of the grid, fitted
#' with [ef_gwr_fit()] and predicted exactly at every cell with
#' [ef_gwr_predict()]. The bandwidth is either given (`bandwidth`) or
#' selected for every fit by `criterion` over `search` with
#' [ef_gwr_bandwidth()] (one selection per variable and target time,
#' decision GW-11).
#'
#' @param kernel Character, no default (decision GW-04 is open):
#'   `"gaussian"`, `"exponential"`, `"bisquare"`, `"tricube"` or `"boxcar"`.
#' @param adaptive Logical, no default: `FALSE` for a fixed bandwidth
#'   \[m\], `TRUE` for an adaptive one (k nearest stations, counting the
#'   station itself).
#' @param criterion `NULL` or `"AICc"` / `"CV"`: select the bandwidth of
#'   every fit by this criterion (no default, decision GW-05). Give exactly
#'   one of `criterion` and `bandwidth`.
#' @param bandwidth `NULL` or a fixed bandwidth \[m\] (`adaptive = FALSE`)
#'   or a whole number of neighbours k (`adaptive = TRUE`), used for every
#'   fit.
#' @param search The settings of the selection, from [ef_gwr_search()];
#'   required with `criterion`, `NULL` with `bandwidth`.
#' @param min_neighbours `NULL` or a whole number: minimum number of
#'   neighbours (see [ef_gwr_fit()]) with a given `bandwidth`; with
#'   `criterion` it is set in [ef_gwr_search()].
#' @param scale_covariates Logical. Internal scaling of the covariates for
#'   numerical conditioning (results do not change; see [ef_gwr_fit()]).
#'
#' @return A list of class `"earthflux_regionalization_method"` with
#'   `method = "gwr"` and the settings.
#'
#' @details
#' Errors: `earthflux_missing_input` (kernel, `adaptive`, or both
#' `criterion` and `bandwidth` missing; `search` missing with `criterion`),
#' `earthflux_unknown_method` (kernel or criterion), `earthflux_input_error`
#' (both `criterion` and `bandwidth`, `search` with `bandwidth`,
#' `min_neighbours` with `criterion`), `earthflux_domain_error` (bandwidth
#' not positive, k not a whole number >= 1).
#'
#' @section Verification status:
#' See [ef_gwr_fit()] and [ef_gwr_bandwidth()]: estimator and kernels
#' `CANDIDATA (corroborada)`; AICc form `VERIFICADA` as content of Gollini et
#' al. (2015) and `CANDIDATA (corroborada)` as EarthFlux definition.
#'
#' @seealso [ef_method_station()], [ef_method_ols()], [ef_method_idw()]
#'   for the comparison configurations C1 and C2.
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 25000)
#' ef_method_gwr("gaussian", adaptive = TRUE, criterion = "AICc",
#'               search = ef_gwr_search())
ef_method_gwr <- function(kernel, adaptive, criterion = NULL, bandwidth = NULL,
                          search = NULL, min_neighbours = NULL,
                          scale_covariates = TRUE) {
  call <- sys.call()
  check_method(kernel, gwr_kernels(), arg = "kernel", call = call)
  if (missing(adaptive)) {
    ef_abort("`adaptive` must be supplied explicitly (TRUE or FALSE).",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  check_flag_scalar(adaptive, "adaptive", call)
  check_flag_scalar(scale_covariates, "scale_covariates", call)
  if (is.null(criterion) && is.null(bandwidth)) {
    ef_abort(
      paste0("Give either `bandwidth` (used for every fit) or `criterion` ",
             "and `search` (bandwidth selected for every fit)."),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (!is.null(criterion) && !is.null(bandwidth)) {
    ef_abort("Give only one of `bandwidth` and `criterion`.",
             class = "earthflux_input_error", call = call)
  }
  if (!is.null(criterion)) {
    check_method(criterion, gwr_criteria(), arg = "criterion", call = call)
    if (is.null(search) || !inherits(search, "earthflux_gwr_search")) {
      ef_abort(
        "`search` must be supplied with `criterion`, as returned by `ef_gwr_search()`.",
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
    if (!is.null(min_neighbours)) {
      ef_abort(
        "With `criterion`, set `min_neighbours` in `ef_gwr_search()`.",
        class = "earthflux_input_error", call = call
      )
    }
  } else {
    if (!is.null(search)) {
      ef_abort("`search` is used only with `criterion`; leave it NULL.",
               class = "earthflux_input_error", call = call)
    }
    gwr_check_bandwidth(bandwidth, adaptive, Inf, call)
    if (!is.null(min_neighbours)) {
      check_scalar(min_neighbours, "min_neighbours", lower = 2, whole = TRUE,
                   call = call)
      min_neighbours <- as.integer(min_neighbours)
    }
    bandwidth <- if (adaptive) as.integer(bandwidth) else as.numeric(bandwidth)
  }
  new_rgn_method(
    "gwr", kernel = kernel, adaptive = adaptive, criterion = criterion,
    bandwidth = bandwidth, search = search, min_neighbours = min_neighbours,
    scale_covariates = scale_covariates
  )
}

#' Regionalization by a representative station (C1)
#'
#' @description
#' Describes configuration C1 for [ef_regionalize()] and
#' [ef_regionalize_cv()] (dev/specs/gwr-forcing.md section 5.3): the
#' surface is constant and equal to the value of the station `station_id`
#' at each target time,
#' \deqn{v(x) = v_s,}
#' or, for `air_temperature` only and with an explicit lapse rate
#' \eqn{\Gamma}{Gamma} (variant `"station_lapse"`),
#' \deqn{v(x) = v_s + \Gamma\,(z(x) - z_s),}{v(x) = v_s + Gamma (z(x) -
#'   z_s),}
#' with z the `elevation` layer of the covariates (also at the station,
#' decision GW-10).
#'
#' @param station_id The identifier of the representative station; no
#'   automatic choice (dev/VALIDATION_PLAN.md section 2.2).
#' @param lapse_rate `NULL` or the vertical gradient \[unit of the variable
#'   per m, e.g. degC m-1\]. No default value exists (`TODO` in
#'   dev/specs/gwr-forcing.md section 5.3): its value and source are the
#'   user's responsibility and are recorded in the provenance.
#'
#' @return A list of class `"earthflux_regionalization_method"` with
#'   `method = "station"` or `"station_lapse"`.
#'
#' @details
#' The station-level diagnostic equivalent to cross-validation is the error
#' at the other stations; the representative station itself is not
#' evaluated. Surfaces carry the object flag `EF_GWR_SINGLE_STATION`.
#' Errors: `earthflux_missing_input` (`station_id`), `earthflux_input_error`
#' (not a single identifier), `earthflux_domain_error` (infinite lapse
#' rate).
#'
#' @section Verification status:
#' The constant surface is a definition of the comparison configuration
#' (no formula to verify). The lapse-rate variant is `CANDIDATA`: its value
#' has no verified default (radiation-components.md RC-12, option a).
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' ef_method_station("ST07")
#' ef_method_station("ST07", lapse_rate = -0.0065)
ef_method_station <- function(station_id, lapse_rate = NULL) {
  call <- sys.call()
  if (missing(station_id) || is.null(station_id)) {
    ef_abort(
      "`station_id` (the representative station) must be supplied explicitly.",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (!(is.character(station_id) || is.numeric(station_id)) ||
      length(station_id) != 1L || is.na(station_id) ||
      !nzchar(as.character(station_id))) {
    ef_abort("`station_id` must be a single station identifier.",
             class = "earthflux_input_error", call = call)
  }
  if (!is.null(lapse_rate)) {
    check_scalar(lapse_rate, "lapse_rate", call = call)
  }
  new_rgn_method(
    if (is.null(lapse_rate)) "station" else "station_lapse",
    station_id = as.character(station_id),
    lapse_rate = if (is.null(lapse_rate)) NULL else as.numeric(lapse_rate)
  )
}

#' Regionalization by global linear regression (C2)
#'
#' @description
#' Describes configuration C2-OLS for [ef_regionalize()] and
#' [ef_regionalize_cv()] (dev/specs/gwr-forcing.md sections 5.2 and 5.4):
#' ordinary least squares on the same covariates (all layers of
#' `covariates`) as GWR,
#' \deqn{\hat\beta = (X^\top X)^{-1} X^\top y, \qquad \hat y_g = x_g^\top
#'   \hat\beta,}{beta = (X'X)^-1 X'y, yhat_g = x_g' beta,}
#' the limit of GWR for an infinite bandwidth. It separates the contribution
#' of the covariates from that of the non-stationarity.
#'
#' @return A list of class `"earthflux_regionalization_method"` with
#'   `method = "global_ols"`.
#'
#' @details
#' Diagnostics use the definitions of the GWR core with tr(S) = p: AICc of
#' [ef_gwr_bandwidth()] and leave-one-out residuals
#' \eqn{e_i/(1 - h_{ii})}{e_i / (1 - h_ii)}.
#'
#' @section Verification status:
#' Ordinary least squares is standard; its use as the C2 reference is a
#' design choice (GW-21). It reproduces the global reference of
#' [ef_gwr_fit()] (tested).
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' ef_method_ols()
ef_method_ols <- function() {
  new_rgn_method("global_ols")
}

#' Regionalization by inverse distance weighting (C2)
#'
#' @description
#' Describes configuration C2-IDW for [ef_regionalize()] and
#' [ef_regionalize_cv()] (dev/specs/gwr-forcing.md section 5.4):
#' \deqn{\hat y(x) = \sum_j \lambda_j y_j, \qquad \lambda_j = \frac{d(x,
#'   j)^{-q}}{\sum_k d(x, k)^{-q}},}{yhat(x) = sum_j lambda_j y_j, lambda_j =
#'   d(x, j)^-q / sum_k d(x, k)^-q,}
#' with q = `power`, without covariates; at a location that coincides with
#' stations, the mean of their values (the limit of the formula).
#'
#' @param power Positive number, no default (the usual choice 2 is not
#'   verified): the power q. A vector of several values is a registered grid
#'   from which q is selected for every fit by leave-one-out
#'   cross-validation (smallest CV; ties to the smallest q).
#'
#' @return A list of class `"earthflux_regionalization_method"` with
#'   `method = "idw"`.
#'
#' @details
#' Distances are Euclidean in the projected CRS of the grid, divided
#' internally by the largest distance between the stations of the fit
#' (which does not change the weights). Errors: `earthflux_missing_input`
#' (`power`), `earthflux_input_error` (not numeric, duplicated values),
#' `earthflux_domain_error` (q <= 0 or infinite).
#'
#' @section Verification status:
#' `CANDIDATA`: Shepard (1968) is cited by the specification but was not
#' read.
#'
#' @references
#' Shepard, D. (1968). A two-dimensional interpolation function for
#' irregularly-spaced data. *Proceedings of the 1968 23rd ACM National
#' Conference*, 517-524. \doi{10.1145/800186.810616}
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' ef_method_idw(2)
#' ef_method_idw(c(1, 2, 3))
ef_method_idw <- function(power) {
  call <- sys.call()
  if (missing(power) || is.null(power)) {
    ef_abort("`power` must be supplied explicitly (no default).",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  if (!is.numeric(power) || length(power) == 0L || anyNA(power) ||
      anyDuplicated(power) > 0L) {
    ef_abort("`power` must be a numeric vector of distinct values.",
             class = "earthflux_input_error", call = call)
  }
  check_in_range(power, "power", lower = 0, lower_inclusive = FALSE,
                 call = call)
  new_rgn_method("idw", power = sort(as.numeric(power)))
}

#' @export
print.earthflux_regionalization_method <- function(x, ...) {
  cat("<earthflux_regionalization_method>", x$method, "\n")
  info <- switch(
    x$method,
    gwr = sprintf("kernel %s, %s bandwidth, %s", x$kernel,
                  if (x$adaptive) "adaptive" else "fixed",
                  if (is.null(x$criterion)) {
                    sprintf("given = %s %s", format(x$bandwidth),
                            if (x$adaptive) "neighbours" else "m")
                  } else {
                    sprintf("selected by %s for every fit", x$criterion)
                  }),
    station = sprintf("representative station %s", x$station_id),
    station_lapse = sprintf("representative station %s, lapse rate %s",
                            x$station_id, format(x$lapse_rate)),
    global_ols = "global ordinary least squares on all covariates",
    idw = if (length(x$power) == 1L) {
      sprintf("power %s", format(x$power))
    } else {
      sprintf("power selected by LOOCV in {%s}",
              paste(format(x$power), collapse = ", "))
    }
  )
  cat(info, "\n", sep = "")
  invisible(x)
}

#' Check a regionalization method argument
#'
#' @param method The `method` argument.
#' @param call The call to report.
#' @return `method`, invisibly.
#' @noRd
check_rgn_method <- function(method, call) {
  if (missing(method) || is.null(method)) {
    ef_abort(
      paste0("`method` must be supplied explicitly: ef_method_gwr(), ",
             "ef_method_station(), ef_method_ols() or ef_method_idw()."),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (!inherits(method, "earthflux_regionalization_method")) {
    ef_abort(
      paste0("`method` must be built with ef_method_gwr(), ",
             "ef_method_station(), ef_method_ols() or ef_method_idw()."),
      class = "earthflux_input_error", call = call
    )
  }
  invisible(method)
}

# Prediction control -------------------------------------------------------------------

#' Control of the prediction of a regionalized surface
#'
#' @description
#' Settings of the grid prediction of [ef_regionalize()]
#' (dev/specs/gwr-forcing.md section 6.1): exact prediction at every cell,
#' computed by blocks of raster rows. None of the settings changes the
#' values; they only bound memory and choose where the surfaces are written.
#'
#' @param mode Character. Only `"exact"` (one local fit per cell) is
#'   implemented; the coarse mode of dev/specs/gwr-forcing.md section 6.2
#'   (decision GW-08) is not.
#' @param block_rows `NULL` or a whole number: raster rows per block. `NULL`
#'   uses the blocks proposed by `terra::writeStart()` (split further, when a
#'   parallel plan is set, so that every worker receives blocks).
#' @param chunk_rows Whole number: cells processed together inside a block
#'   by [ef_gwr_predict()] (memory only).
#' @param filename Character. File of the surface; `""` lets `terra` keep it
#'   in memory (or in its own temporary file when it does not fit).
#' @param flags_filename `NULL` or character: file of the flag word layers.
#'   `NULL` derives it from `filename` (`<name>_flags.<ext>`), or keeps the
#'   layers in memory when `filename` is `""`.
#' @param overwrite Logical. Overwrite existing files.
#' @param wopt List of write options passed to `terra::writeStart()` for the
#'   surface (e.g. `list(datatype = "FLT8S")`; `terra` writes `FLT4S` by
#'   default, decision D-PP-05). The flag words are always written as
#'   `INT4S`.
#'
#' @return A list of class `"earthflux_predict_control"`.
#'
#' @details
#' Errors: `earthflux_unknown_method` (`mode`), `earthflux_input_error`
#' (types), `earthflux_domain_error` (non-positive sizes).
#'
#' @family spatial regionalization functions
#' @export
#'
#' @examples
#' ef_predict_control()
#' ef_predict_control(block_rows = 50,
#'                    filename = file.path(tempdir(), "ta.tif"),
#'                    wopt = list(datatype = "FLT8S"))
ef_predict_control <- function(mode = "exact", block_rows = NULL,
                               chunk_rows = 10000L, filename = "",
                               flags_filename = NULL, overwrite = FALSE,
                               wopt = list()) {
  call <- sys.call()
  check_method(mode, "exact", arg = "mode", call = call)
  if (!is.null(block_rows)) {
    check_scalar(block_rows, "block_rows", lower = 1, whole = TRUE,
                 call = call)
    block_rows <- as.integer(block_rows)
  }
  check_scalar(chunk_rows, "chunk_rows", lower = 1, whole = TRUE, call = call)
  is_file <- function(x) is.character(x) && length(x) == 1L && !is.na(x)
  if (!is_file(filename)) {
    ef_abort("`filename` must be a single string (\"\" for memory).",
             class = "earthflux_input_error", call = call)
  }
  if (!is.null(flags_filename) && !is_file(flags_filename)) {
    ef_abort("`flags_filename` must be NULL or a single string.",
             class = "earthflux_input_error", call = call)
  }
  if (is.null(flags_filename)) {
    flags_filename <- if (nzchar(filename)) {
      ext <- regmatches(filename, regexpr("\\.[^./\\\\]+$", filename))
      stem <- if (length(ext) == 1L) {
        substr(filename, 1L, nchar(filename) - nchar(ext))
      } else {
        filename
      }
      paste0(stem, "_flags", if (length(ext) == 1L) ext else "")
    } else {
      ""
    }
  }
  if (nzchar(filename) && identical(filename, flags_filename)) {
    ef_abort("`filename` and `flags_filename` must differ.",
             class = "earthflux_input_error", call = call)
  }
  check_flag_scalar(overwrite, "overwrite", call)
  if (!is.list(wopt) || (length(wopt) > 0L && is.null(names(wopt)))) {
    ef_abort("`wopt` must be a named list of terra write options.",
             class = "earthflux_input_error", call = call)
  }
  structure(
    list(mode = mode, block_rows = block_rows,
         chunk_rows = as.integer(chunk_rows), filename = filename,
         flags_filename = flags_filename, overwrite = overwrite,
         wopt = wopt),
    class = c("earthflux_predict_control", "list")
  )
}

#' @export
print.earthflux_predict_control <- function(x, ...) {
  cat("<earthflux_predict_control>\n")
  cat(sprintf("Mode: %s; block rows: %s; chunk rows: %d\n", x$mode,
              if (is.null(x$block_rows)) "terra" else x$block_rows,
              x$chunk_rows))
  cat(sprintf("Surface: %s; flags: %s\n",
              if (nzchar(x$filename)) x$filename else "memory",
              if (nzchar(x$flags_filename)) x$flags_filename else "memory"))
  invisible(x)
}

# Dispatch of fit and prediction --------------------------------------------------------

#' Covariates used by a method
#'
#' @param method A method object.
#' @param layers Names of the covariate layers.
#' @return Character vector of the covariates entering the fit.
#' @noRd
rgn_method_covariates <- function(method, layers) {
  switch(method$method,
         gwr = layers,
         global_ols = layers,
         station_lapse = "elevation",
         character(0))
}

#' Cell-scope codes evaluated by a method
#'
#' Bits of the GWR flag word (dev/specs/flags.md section 6.4) evaluated in
#' the surfaces of each method; `EF_INPUT_NA` and `EF_GWR_OUT_OF_DOMAIN` are
#' evaluated by the orchestrator for every method.
#'
#' @param method A method object.
#' @return Character vector of codes.
#' @noRd
rgn_cell_codes <- function(method) {
  own <- switch(
    method$method,
    gwr = c("EF_GWR_EXTRAPOLATION_COVARIATE",
            if (method$kernel %in% gwr_compact_kernels()) {
              "EF_GWR_EXTRAPOLATION_LOCAL"
            },
            "EF_GWR_OUTSIDE_HULL", "EF_GWR_FEW_NEIGHBOURS",
            "EF_GWR_LOCAL_SINGULAR"),
    global_ols = c("EF_GWR_EXTRAPOLATION_COVARIATE", "EF_GWR_OUTSIDE_HULL"),
    idw = "EF_GWR_OUTSIDE_HULL",
    character(0)
  )
  c("EF_INPUT_NA", own, "EF_GWR_OUT_OF_DOMAIN")
}

#' Fit a regionalization method at the stations of one fit
#'
#' @param method A method object.
#' @param st A list with `id` (station identifiers), `y` (response), `x`
#'   (matrix of the covariates used, possibly with zero columns) and
#'   `coords` (projected coordinates \[m\]) of the stations used.
#' @param call The call to report.
#' @return The fitted object: `earthflux_gwr`, `earthflux_ols`,
#'   `earthflux_idw` or `earthflux_station_forcing`.
#' @noRd
rgn_fit <- function(method, st, call = sys.call(-1)) {
  switch(
    method$method,
    gwr = {
      if (is.null(method$criterion)) {
        ef_gwr_fit(st$y, st$x, st$coords, bandwidth = method$bandwidth,
                   kernel = method$kernel, adaptive = method$adaptive,
                   min_neighbours = method$min_neighbours,
                   scale_covariates = method$scale_covariates,
                   station_id = st$id)
      } else {
        bw <- ef_gwr_bandwidth(st$y, st$x, st$coords, kernel = method$kernel,
                               adaptive = method$adaptive,
                               criterion = method$criterion,
                               search = method$search,
                               scale_covariates = method$scale_covariates,
                               station_id = st$id)
        ef_gwr_fit(st$y, st$x, st$coords, bandwidth = bw,
                   kernel = method$kernel, adaptive = method$adaptive,
                   scale_covariates = method$scale_covariates,
                   station_id = st$id)
      }
    },
    global_ols = rgn_ols_fit(st, call),
    idw = rgn_idw_fit(st, method$power, call),
    station = ,
    station_lapse = rgn_station_fit(st, method, call)
  )
}

#' Predict a fitted method at new locations
#'
#' @param fit A fitted object returned by `rgn_fit()`.
#' @param newx Matrix of the covariates used (complete rows; zero columns
#'   for methods without covariates).
#' @param newcoords Matrix of projected coordinates \[m\].
#' @param chunk_rows Rows per internal chunk (GWR).
#' @param bits Named bits of the GWR stage (`rgn_bits()`).
#' @return A list with `value` (numeric) and `word` (integer flag word of
#'   the method's own cell conditions, bits of the GWR stage).
#' @noRd
rgn_predict <- function(fit, newx, newcoords, chunk_rows = 10000L,
                        bits = rgn_bits()) {
  m <- nrow(newcoords)
  if (inherits(fit, "earthflux_gwr")) {
    p <- ef_gwr_predict(fit, newx, newcoords, chunk_rows = chunk_rows)
    return(list(value = p$value, word = gwr_flag_word(p$flags, m)))
  }
  if (inherits(fit, "earthflux_ols")) {
    return(rgn_ols_predict(fit, newx, newcoords, bits))
  }
  if (inherits(fit, "earthflux_idw")) {
    return(rgn_idw_predict(fit, newcoords, bits))
  }
  rgn_station_predict(fit, newx, m)
}

#' Flag word from named logical masks
#'
#' @param masks Named list of logical vectors (registered cell codes).
#' @param n Length of the masks.
#' @param bits Named bits of the GWR stage (`rgn_bits()`).
#' @return Integer vector \eqn{\sum_k 2^{bit_k} m_k}.
#' @noRd
rgn_mask_word <- function(masks, n, bits) {
  word <- numeric(n)
  for (code in names(masks)) {
    word <- word + 2^bits[[code]] * masks[[code]]
  }
  as.integer(word)
}

#' Bits of the cell-scope codes of the GWR stage
#'
#' @return A named integer vector (code -> bit) read from the registry.
#' @noRd
rgn_bits <- function() {
  reg <- ef_flag_registry()
  keep <- reg$stage %in% c("INPUT", "GWR") & !is.na(reg$bit)
  stats::setNames(reg$bit[keep], reg$code[keep])
}

#' Station-level results of a fitted method
#'
#' @param fit A fitted object returned by `rgn_fit()`.
#' @return A data frame with `station_id`, `fitted`, `residual`,
#'   `loo_fitted`, `loo_residual` for the stations of the fit.
#' @noRd
rgn_station_results <- function(fit) {
  st <- fit$stations
  if (inherits(fit, "earthflux_gwr")) {
    st <- st[st$status == "used", , drop = FALSE]
  }
  data.frame(station_id = st$station_id, fitted = st$fitted,
             residual = st$residual, loo_fitted = st$loo_fitted,
             loo_residual = st$loo_residual, stringsAsFactors = FALSE)
}

#' Tuning value of a fitted method (bandwidth or IDW power)
#'
#' @param fit A fitted object.
#' @return Numeric scalar or `NA`.
#' @noRd
rgn_tuning <- function(fit) {
  if (inherits(fit, "earthflux_gwr")) {
    return(as.numeric(fit$bandwidth$value))
  }
  if (inherits(fit, "earthflux_idw")) {
    return(fit$power)
  }
  NA_real_
}
