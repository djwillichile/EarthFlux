# METRIC: anchor (hot/cold) pixels ---------------------------------------------
#
# Purpose: auditable selection of the cold and hot anchor pixels used for the
#   internal calibration of dT, and the boundary conditions (target LE and H)
#   at those anchors. Kept separate from the sensible heat module
#   (dev/specs/anchor-pixels.md section 1.3):
#
#     [A] selection          ef_select_anchors() / ef_anchors()
#                            surface variables only (no Rn, G or weather)
#     [B] boundary cond.     ef_anchor_conditions()   (decision D-AP-03)
#                            Rn, G, ETr_inst, lambda, explicit coefficients
#     [C] dT calibration     sensible heat module (reads `calibration_points`)
#
# Specification: dev/specs/anchor-pixels.md. Provisional decisions adopted
#   for M2 (dev/DECISIONS.md section 1.0): P0-8 (no default thresholds or
#   coefficients, no automatic relaxation, explicit `etrf_hot` / `le_hot`)
#   and P0-9 (exactly one calibration point per class with an explicit
#   `aggregate`; dispersion recorded; boundary conditions in a stage [B]
#   function; ETr_inst evaluated at each anchor pixel).
#
# Verification status: no selection criterion, threshold or boundary
#   condition of this file is VERIFICADA (Allen, Tasumi and Trezza, 2007 and
#   Allen et al., 2013 were not available). Every numerical value is an
#   explicit argument of the user; the forms of the boundary conditions are
#   CANDIDATA.
#
# Design (D-AP-09): the core works on numeric vectors or matrices sharing one
#   grid (no terra). Cells are numbered as in terra: row by row from the top
#   left corner (row-major), whatever the storage order of R matrices.
#   Neighbourhood operations (homogeneity windows) need matrix layers.
#
# Statistics: percentile thresholds use stats::quantile() with the explicit
#   `quantile_type` of the criteria (Hyndman and Fan types 1-9); medians and
#   sample standard deviations use stats::median() and stats::sd() (stats is
#   in Imports since the M2 harmonisation).

# Vocabulary -------------------------------------------------------------------

anchor_types <- function() c("cold", "hot")

anchor_layer_variables <- function() c("lst", "ndvi", "albedo", "lai")

anchor_rule_variables <- function() c(anchor_layer_variables(), "land_cover")

anchor_statuses <- function() c("TODO", "CANDIDATA", "VERIFICADA")

# Codes raised by the boundary-condition stage [B]; removed when the
# conditions are recomputed on an object.
anchor_condition_codes <- function() {
  c("EF_ANCHOR_COLD_H_NEGATIVE", "EF_ANCHOR_HOT_LE_ASSUMED_ZERO")
}

#' Signal a missing explicit argument
#' @noRd
anchor_require <- function(is_missing, arg, call) {
  if (is_missing) {
    ef_abort(
      sprintf("`%s` must be supplied explicitly (it has no default).", arg),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  invisible(TRUE)
}

# Criteria constructors --------------------------------------------------------

#' Rule of an anchor pixel selection criterion
#'
#' @description
#' Builds one rule of the selection criteria of anchor pixels, for example
#' "NDVI at or above the 95th percentile of the scene" or "albedo between
#' 0.10 and 0.35". Rules are combined in [ef_anchor_criteria()]. A rule
#' states its variable, operator, threshold and whether the threshold is an
#' absolute value or a percentile of the scene; nothing has a default value,
#' because no threshold for anchor selection has been verified against a
#' primary source.
#'
#' @param variable Character. Layer the rule applies to: `"lst"` (surface
#'   temperature \[K\]), `"ndvi"` \[-\], `"albedo"` \[-\], `"lai"`
#'   \[m2 m-2\] or `"land_cover"` (integer class codes).
#' @param operator Character. One of `">="`, `">"`, `"<="`, `"<"`,
#'   `"between"` (closed interval, `value = c(lower, upper)`) or `"in"`
#'   (membership in a set of class codes; only for `"land_cover"`, which
#'   only accepts `"in"`).
#' @param value Numeric. Threshold, in the unit of `variable` when
#'   `scale = "absolute"`, or a probability in (0, 1\] when
#'   `scale = "percentile"`. Length 2 for `"between"`, one or more class
#'   codes for `"in"`, length 1 otherwise. Missing and infinite values are
#'   not allowed.
#' @param scale Character. `"absolute"` (the threshold is `value`) or
#'   `"percentile"` (the threshold is the quantile of `variable` at
#'   probability `value`, computed in the percentile domain and with the
#'   quantile type set in [ef_anchor_criteria()]).
#'
#' @return A list of class `earthflux_anchor_rule` with elements
#'   `variable`, `operator`, `value` and `scale`.
#'
#' @details
#' A cell satisfies the rule when `variable` (at the cell) compared with the
#' threshold by `operator` is `TRUE`; a missing value never satisfies a rule.
#' Invalid arguments raise errors of class `earthflux_input_error` (missing
#' arguments: `earthflux_missing_input`; unknown variable, operator or
#' scale: `earthflux_unknown_method`).
#'
#' Verification status: the rule is a container; the thresholds a user
#' passes are not verified by the package. Values observed in the `water`
#' package (for example NDVI percentile 0.95 and LAI >= 4 for the cold
#' anchor) are `CANDIDATA` without a verified primary source
#' (dev/specs/anchor-pixels.md section 3).
#'
#' @family anchor pixel functions
#' @export
#'
#' @examples
#' # Cold anchor candidates: NDVI at or above the scene's 95th percentile
#' ef_anchor_rule("ndvi", ">=", 0.95, scale = "percentile")
#'
#' # Hot anchor candidates: albedo between 0.10 and 0.35 (absolute)
#' ef_anchor_rule("albedo", "between", c(0.10, 0.35), scale = "absolute")
ef_anchor_rule <- function(variable, operator, value, scale) {
  call <- sys.call()
  check_method(variable, anchor_rule_variables(), arg = "variable", call = call)
  check_method(operator, c(">=", ">", "<=", "<", "between", "in"),
               arg = "operator", call = call)
  anchor_require(missing(value), "value", call)
  check_method(scale, c("absolute", "percentile"), arg = "scale", call = call)
  check_numeric(value, "value", call = call)
  if (length(value) == 0L || anyNA(value)) {
    ef_abort("`value` must be non-empty and must not contain missing values.",
             class = "earthflux_input_error", call = call)
  }
  check_in_range(value, "value", call = call)
  if (identical(variable, "land_cover") != identical(operator, "in")) {
    ef_abort(
      "`\"land_cover\"` is categorical: it takes `operator = \"in\"`, which applies to no other variable.",
      class = "earthflux_input_error", call = call
    )
  }
  if (operator == "in" && scale != "absolute") {
    ef_abort("`operator = \"in\"` needs `scale = \"absolute\"`.",
             class = "earthflux_input_error", call = call)
  }
  if (operator == "between") {
    if (length(value) != 2L || value[1L] > value[2L]) {
      ef_abort(
        "`operator = \"between\"` needs `value = c(lower, upper)` with lower <= upper.",
        class = "earthflux_input_error", call = call
      )
    }
  } else if (operator != "in" && length(value) != 1L) {
    ef_abort(sprintf("`operator = \"%s\"` needs a single `value`.", operator),
             class = "earthflux_input_error", call = call)
  }
  if (scale == "percentile") {
    check_in_range(value, "value", lower = 0, upper = 1,
                   lower_inclusive = FALSE, call = call)
  }
  structure(
    list(variable = variable, operator = operator, value = as.numeric(value),
         scale = scale),
    class = c("earthflux_anchor_rule", "list")
  )
}

#' Homogeneity criterion of anchor pixels
#'
#' @description
#' Defines the spatial homogeneity test applied to anchor pixel candidates:
#' the dispersion of a variable (usually the surface temperature) in a
#' square moving window centred on the candidate must not exceed a maximum.
#' Used in [ef_anchor_criteria()] and, to audit user-supplied anchors, in
#' [ef_anchors()].
#'
#' @param variable Character. Layer whose dispersion is evaluated: `"lst"`,
#'   `"ndvi"`, `"albedo"` or `"lai"`.
#' @param window Integer. Side of the square window in cells: odd and
#'   `>= 3`.
#' @param stat Character. Dispersion statistic; only `"sd"` (sample
#'   standard deviation, denominator n - 1) is available.
#' @param max Numeric. Maximum dispersion for a homogeneous candidate, in the
#'   unit of `variable` (K for `"lst"`). Finite and `>= 0`.
#' @param window_na Character. Treatment of windows with missing values or
#'   that cross the grid border: `"exclude"` (the candidate is not
#'   homogeneous unless the window is complete) or `"available"` (the
#'   statistic uses the available cells, at least two; this is the
#'   treatment observed in the `water` package).
#'
#' @return A list of class `earthflux_homogeneity` with the arguments as
#'   elements.
#'
#' @details
#' The window is defined in cells; its size in metres depends on the cell
#' size of the grid, which [ef_select_anchors()] records (with MODIS 1 km
#' cells a 5 x 5 window covers 5 km x 5 km, against 150 m x 150 m for
#' Landsat; dev/specs/anchor-pixels.md section 4, Q-AP-03). Anchors whose
#' window is incomplete are flagged with `EF_ANCHOR_WINDOW_INCOMPLETE`.
#' Errors are of class `earthflux_input_error` (and subclasses).
#'
#' Verification status: the window of 5 x 5 cells and the maximum of 1.5 K
#' observed in `water` are `CANDIDATA`; no value is a default here.
#'
#' @family anchor pixel functions
#' @export
#'
#' @examples
#' ef_homogeneity("lst", window = 3, stat = "sd", max = 0.5,
#'                window_na = "exclude")
ef_homogeneity <- function(variable, window, stat, max, window_na) {
  call <- sys.call()
  check_method(variable, anchor_layer_variables(), arg = "variable",
               call = call)
  anchor_require(missing(window), "window", call)
  check_scalar(window, "window", lower = 3, whole = TRUE, call = call)
  if (window %% 2 != 1) {
    ef_abort("`window` must be an odd number of cells.",
             class = "earthflux_input_error", call = call)
  }
  check_method(stat, "sd", arg = "stat", call = call)
  anchor_require(missing(max), "max", call)
  check_scalar(max, "max", lower = 0, call = call)
  check_method(window_na, c("exclude", "available"), arg = "window_na",
               call = call)
  structure(
    list(variable = variable, window = as.integer(window), stat = stat,
         max = as.numeric(max), window_na = window_na),
    class = c("earthflux_homogeneity", "list")
  )
}

#' Final pick of anchor pixels among the candidates
#'
#' @description
#' Defines how the anchor pixels of one class are picked among the
#' candidates that passed the rules and the homogeneity test: a fraction of
#' the coldest (or hottest) candidates, or a fixed number of them.
#'
#' @param variable Character. Layer used to rank the candidates: `"lst"`,
#'   `"ndvi"`, `"albedo"` or `"lai"` (usually `"lst"`).
#' @param method Character. One of:
#'   * `"lowest_fraction"`: candidates with `variable <= Q(value)`, the
#'     quantile of the candidates at probability `value`;
#'   * `"highest_fraction"`: candidates with `variable >= Q(1 - value)`;
#'   * `"lowest"`: the `value` candidates with the lowest `variable`;
#'   * `"highest"`: the `value` candidates with the highest `variable`.
#' @param value Numeric. A fraction in (0, 1\] for the `*_fraction`
#'   methods, a whole number `>= 1` for `"lowest"` and `"highest"`.
#'
#' @return A list of class `earthflux_anchor_pick` with elements `variable`,
#'   `method` and `value`.
#'
#' @details
#' The pick is deterministic. The `*_fraction` methods keep every candidate
#' equal to the threshold. `"lowest"` and `"highest"` order the candidates by
#' `variable` and then by ascending cell number (row by row from the top
#' left corner); when equal values straddle the limit, the tie is resolved by
#' cell number and the anchor set is flagged with `EF_ANCHOR_TIES`.
#'
#' Verification status: the fractions of 0.2 observed in `water` are
#' `CANDIDATA`; no value is a default here.
#'
#' @family anchor pixel functions
#' @export
#'
#' @examples
#' # The coldest 20 % of the cold candidates
#' ef_anchor_pick("lst", "lowest_fraction", 0.2)
#'
#' # The single hottest hot candidate
#' ef_anchor_pick("lst", "highest", 1)
ef_anchor_pick <- function(variable, method, value) {
  call <- sys.call()
  check_method(variable, anchor_layer_variables(), arg = "variable",
               call = call)
  check_method(method, c("lowest_fraction", "highest_fraction", "lowest",
                         "highest"), call = call)
  anchor_require(missing(value), "value", call)
  if (method %in% c("lowest_fraction", "highest_fraction")) {
    check_scalar(value, "value", lower = 0, upper = 1,
                        lower_inclusive = FALSE, call = call)
  } else {
    check_scalar(value, "value", lower = 1, whole = TRUE, call = call)
  }
  structure(
    list(variable = variable, method = method, value = as.numeric(value)),
    class = c("earthflux_anchor_pick", "list")
  )
}

#' Selection criteria of anchor pixels
#'
#' @description
#' Gathers, in one explicit and auditable object, every criterion used by
#' [ef_select_anchors()] to select the cold and hot anchor pixels of the
#' METRIC calibration: the rules of each class, the homogeneity test, the
#' final pick, the domain of the percentiles, the quantile type, and the
#' source and verification status of the whole set. There are no default
#' criteria (decision D-AP-01): the values used must be stated, with their
#' source.
#'
#' @param cold,hot Lists of [ef_anchor_rule()] objects (at least one each):
#'   the rules a cell must satisfy (all of them) to be a cold or a hot
#'   candidate.
#' @param homogeneity An [ef_homogeneity()] object applied to the
#'   candidates of both classes, or `NULL` (no homogeneity test). Must be
#'   given explicitly.
#' @param select A list with elements `cold` and `hot`, each an
#'   [ef_anchor_pick()] object.
#' @param percentile_domain Character. Cells on which percentile thresholds
#'   are computed: `"usable"` (usable cells, i.e. allowed by `qa` and the
#'   search area, with no missing value in a variable used by the criteria)
#'   or `"land"` (usable cells with NDVI > 0, so that water does not shift the
#'   percentiles; the definition observed in `water`, `CANDIDATA`).
#' @param quantile_type Integer in 1-9. Quantile type (Hyndman and Fan,
#'   1996; the same definitions as `stats::quantile()`), used for percentile
#'   rules and the fraction picks. The result depends on it.
#' @param source Character. Where the criteria come from (reference, preset
#'   or test parameters).
#' @param status Character. Verification status of the criteria: `"TODO"`,
#'   `"CANDIDATA"` or `"VERIFICADA"`.
#'
#' @return A list of class `earthflux_anchor_criteria` with the arguments as
#'   elements.
#'
#' @details
#' Invalid arguments raise errors of class `earthflux_input_error`
#' (missing arguments: `earthflux_missing_input`; unknown choices:
#' `earthflux_unknown_method`).
#'
#' Verification status: no selection criterion is `VERIFICADA`. The
#' automated procedures of Allen et al. (2013) and Morton et al. (2013) were
#' only read in their abstracts; the criteria of the `water` package are a
#' secondary source (dev/specs/anchor-pixels.md section 3). A criteria set
#' labelled `"CANDIDATA"` must not become a silent default of the high-level
#' interface.
#'
#' @references
#' Allen, R. G., Burnett, B., Kramber, W., Huntington, J., Kjaersgaard, J.,
#' Kilic, A., Kelly, C., & Trezza, R. (2013). Automated calibration of the
#' METRIC-Landsat evapotranspiration process. *Journal of the American Water
#' Resources Association*, 49(3), 563-576. \doi{10.1111/jawr.12056}
#'
#' Morton, C. G., Huntington, J. L., Pohll, G. M., Allen, R. G., McGwire,
#' K. C., & Bassett, S. D. (2013). Assessing calibration uncertainty and
#' automation for estimating evapotranspiration from agricultural areas
#' using METRIC. *Journal of the American Water Resources Association*,
#' 49(3), 549-562. \doi{10.1111/jawr.12054}
#'
#' @family anchor pixel functions
#' @export
#'
#' @examples
#' # Test parameters that reproduce the defaults observed in the `water`
#' # package (CANDIDATA; not defaults of EarthFlux)
#' crit <- ef_anchor_criteria(
#'   cold = list(
#'     ef_anchor_rule("ndvi", ">=", 0.95, scale = "percentile"),
#'     ef_anchor_rule("lai", ">=", 4, scale = "absolute")
#'   ),
#'   hot = list(
#'     ef_anchor_rule("ndvi", "<=", 0.10, scale = "percentile"),
#'     ef_anchor_rule("ndvi", ">", 0, scale = "absolute"),
#'     ef_anchor_rule("albedo", "between", c(0.10, 0.35), scale = "absolute")
#'   ),
#'   homogeneity = ef_homogeneity("lst", window = 5, stat = "sd", max = 1.5,
#'                                window_na = "available"),
#'   select = list(cold = ef_anchor_pick("lst", "lowest_fraction", 0.2),
#'                 hot = ef_anchor_pick("lst", "highest_fraction", 0.2)),
#'   percentile_domain = "land",
#'   quantile_type = 7,
#'   source = "water v1.0 anchors.control() defaults",
#'   status = "CANDIDATA"
#' )
#' crit
ef_anchor_criteria <- function(cold, hot, homogeneity, select,
                               percentile_domain, quantile_type, source,
                               status) {
  call <- sys.call()
  anchor_require(missing(cold), "cold", call)
  anchor_require(missing(hot), "hot", call)
  anchor_require(missing(homogeneity), "homogeneity", call)
  anchor_require(missing(select), "select", call)
  anchor_require(missing(quantile_type), "quantile_type", call)
  anchor_require(missing(source), "source", call)

  for (type in anchor_types()) {
    rules <- if (type == "cold") cold else hot
    ok <- is.list(rules) && !inherits(rules, "earthflux_anchor_rule") &&
      length(rules) > 0L &&
      all(vapply(rules, inherits, logical(1), what = "earthflux_anchor_rule"))
    if (!ok) {
      ef_abort(
        sprintf("`%s` must be a non-empty list of `ef_anchor_rule()` objects.",
                type),
        class = "earthflux_input_error", call = call
      )
    }
  }
  if (!is.null(homogeneity) &&
      !inherits(homogeneity, "earthflux_homogeneity")) {
    ef_abort("`homogeneity` must be an `ef_homogeneity()` object or NULL.",
             class = "earthflux_input_error", call = call)
  }
  ok <- is.list(select) && setequal(names(select), anchor_types()) &&
    length(select) == 2L &&
    all(vapply(select, inherits, logical(1), what = "earthflux_anchor_pick"))
  if (!ok) {
    ef_abort(
      "`select` must be a list with elements `cold` and `hot`, each an `ef_anchor_pick()` object.",
      class = "earthflux_input_error", call = call
    )
  }
  check_method(percentile_domain, c("usable", "land"),
               arg = "percentile_domain", call = call)
  check_scalar(quantile_type, "quantile_type", lower = 1, upper = 9,
                      whole = TRUE, call = call)
  check_string(source, "source")
  check_method(status, anchor_statuses(), arg = "status", call = call)

  structure(
    list(cold = unname(cold), hot = unname(hot), homogeneity = homogeneity,
         select = list(cold = select$cold, hot = select$hot),
         percentile_domain = percentile_domain,
         quantile_type = as.integer(quantile_type), source = source,
         status = status),
    class = c("earthflux_anchor_criteria", "list")
  )
}

#' Short label of a rule (for the funnel and messages)
#' @noRd
anchor_rule_label <- function(rule) {
  val <- if (rule$scale == "percentile") {
    paste0("p", format(rule$value))
  } else {
    format(rule$value)
  }
  if (rule$operator == "between") {
    sprintf("%s between [%s, %s]", rule$variable, val[1L], val[2L])
  } else if (rule$operator == "in") {
    sprintf("%s in {%s}", rule$variable, paste(val, collapse = ", "))
  } else {
    sprintf("%s %s %s", rule$variable, rule$operator, val)
  }
}

#' Variables (layers) used by a criteria set
#' @noRd
anchor_used_variables <- function(criteria) {
  rules <- c(criteria$cold, criteria$hot)
  vars <- c("lst", vapply(rules, `[[`, "", "variable"),
            criteria$select$cold$variable, criteria$select$hot$variable)
  if (!is.null(criteria$homogeneity)) {
    vars <- c(vars, criteria$homogeneity$variable)
  }
  pct <- any(vapply(rules, function(r) r$scale == "percentile", logical(1)))
  if (pct && criteria$percentile_domain == "land") {
    vars <- c(vars, "ndvi")
  }
  unique(vars)
}

# Grid and layers --------------------------------------------------------------

#' Grid description from the reference layer
#' @noRd
anchor_grid <- function(lst, cell_size, origin, crs, call) {
  check_numeric(lst, "lst", call = call)
  d <- dim(lst)
  if (length(lst) == 0L) {
    ef_abort("`lst` must not be empty.", class = "earthflux_input_error",
             call = call)
  }
  if (!is.null(d) && length(d) != 2L) {
    ef_abort("Layers must be vectors or matrices (two dimensions).",
             class = "earthflux_input_error", call = call)
  }
  if (!is.null(cell_size)) {
    check_scalar(cell_size, "cell_size", lower = 0,
                        lower_inclusive = FALSE, call = call)
  }
  if (!is.null(origin)) {
    if (is.null(d) || is.null(cell_size)) {
      ef_abort("`origin` needs matrix layers and `cell_size`.",
               class = "earthflux_input_error", call = call)
    }
    if (!is.numeric(origin) || length(origin) != 2L || anyNA(origin)) {
      ef_abort("`origin` must be c(x, y) of the top left corner of the grid.",
               class = "earthflux_input_error", call = call)
    }
    check_in_range(origin, "origin", call = call)
  }
  if (!is.null(crs)) {
    check_string(crs, "crs")
  }
  list(
    n = length(lst),
    nrow = if (is.null(d)) NA_integer_ else as.integer(d[1L]),
    ncol = if (is.null(d)) NA_integer_ else as.integer(d[2L]),
    dim = d,
    cell_size = cell_size,
    origin = if (is.null(origin)) NULL else as.numeric(origin),
    crs = crs
  )
}

#' Layer as a row-major (terra cell order) plain vector
#' @noRd
anchor_cells_of <- function(x, grid) {
  if (is.null(grid$dim)) {
    as.vector(x)
  } else {
    as.vector(t(x))
  }
}

#' Check that a layer matches the grid
#' @noRd
anchor_check_layer <- function(x, arg, grid, logical = FALSE, call) {
  if (logical) {
    if (!is.logical(x) || anyNA(x)) {
      ef_abort(sprintf("`%s` must be a logical layer without missing values.",
                       arg),
               class = "earthflux_input_error", call = call)
    }
  } else {
    check_numeric(x, arg, call = call)
  }
  if (length(x) != grid$n || !identical(dim(x), grid$dim)) {
    ef_abort(
      sprintf("`%s` must have the length and `dim` of `lst` (same grid).", arg),
      class = "earthflux_input_error", call = call
    )
  }
  invisible(x)
}

#' Validate the surface layers and return them in cell order
#' @noRd
anchor_layers <- function(lst, ndvi, albedo, lai, land_cover, elevation,
                          utc_hour, grid, call) {
  given <- list(lst = lst, ndvi = ndvi, albedo = albedo, lai = lai,
                land_cover = land_cover, elevation = elevation,
                utc_hour = utc_hour)
  for (nm in names(given)) {
    if (!is.null(given[[nm]])) {
      anchor_check_layer(given[[nm]], nm, grid, call = call)
    }
  }
  check_in_range(lst, "lst", lower = 0, lower_inclusive = FALSE, call = call)
  check_in_range(ndvi, "ndvi", lower = -1, upper = 1, call = call)
  check_in_range(albedo, "albedo", lower = 0, upper = 1, call = call)
  if (!is.null(lai)) check_in_range(lai, "lai", lower = 0, call = call)
  if (!is.null(land_cover)) {
    check_in_range(land_cover, "land_cover", call = call)
  }
  if (!is.null(elevation)) check_in_range(elevation, "elevation", call = call)
  if (!is.null(utc_hour)) {
    check_in_range(utc_hour, "utc_hour", lower = 0, upper = 24,
                   upper_inclusive = FALSE, call = call)
  }
  lapply(given, function(x) if (is.null(x)) NULL else anchor_cells_of(x, grid))
}

#' Check inherited cell-scope flags (dev/specs/flags.md section 3.4)
#'
#' @return The list of flags (possibly empty), invisibly checked: each must
#'   be a cell-scope record evaluated on the whole grid.
#' @noRd
anchor_check_inherited <- function(inherited_flags, grid, call) {
  if (is.null(inherited_flags)) {
    return(list())
  }
  check_flag_list(inherited_flags, "inherited_flags", call = call)
  ok <- vapply(inherited_flags, function(f) {
    identical(f$scope, "cell") && f$n_total == grid$n
  }, logical(1))
  if (!all(ok)) {
    ef_abort(
      "`inherited_flags` must hold cell-scope flags evaluated on the grid of `lst`.",
      class = "earthflux_input_error", call = call
    )
  }
  inherited_flags
}

#' Cell numbers (terra order) of R positions of a layer
#' @noRd
anchor_position_to_cell <- function(pos, grid) {
  if (is.null(grid$dim)) {
    return(as.integer(pos))
  }
  row <- (pos - 1L) %% grid$nrow + 1L
  col <- (pos - 1L) %/% grid$nrow + 1L
  as.integer((row - 1L) * grid$ncol + col)
}

#' Codes inherited by each cell
#' @noRd
anchor_inherited_codes <- function(cells, inherited, grid) {
  out <- rep("", length(cells))
  for (f in inherited) {
    hit <- cells %in% anchor_position_to_cell(f$index, grid)
    out[hit] <- ifelse(nzchar(out[hit]), paste(out[hit], f$code, sep = ";"),
                       f$code)
  }
  out
}

# Neighbourhood statistics -----------------------------------------------------

#' Window statistics at given cells
#' @noRd
anchor_window_stats <- function(v, cells, homogeneity, grid) {
  n_cells <- length(cells)
  stat <- rep(NA_real_, n_cells)
  n_valid <- integer(n_cells)
  half <- homogeneity$window %/% 2L
  rows <- (cells - 1L) %/% grid$ncol + 1L
  cols <- (cells - 1L) %% grid$ncol + 1L
  for (i in seq_len(n_cells)) {
    rr <- max(1L, rows[i] - half):min(grid$nrow, rows[i] + half)
    cc <- max(1L, cols[i] - half):min(grid$ncol, cols[i] + half)
    vals <- v[as.vector(outer((rr - 1L) * grid$ncol, cc, "+"))]
    vals <- vals[!is.na(vals)]
    n_valid[i] <- length(vals)
    stat[i] <- stats::sd(vals)
  }
  n_window <- homogeneity$window^2
  data.frame(
    window_stat = stat,
    window_n_valid = n_valid,
    window_n = rep(as.integer(n_window), n_cells),
    window_complete = n_valid == n_window
  )
}

#' Homogeneity decision from window statistics
#' @noRd
anchor_is_homogeneous <- function(ws, homogeneity) {
  ok <- !is.na(ws$window_stat) & ws$window_stat <= homogeneity$max
  if (homogeneity$window_na == "exclude") {
    ok & ws$window_complete
  } else {
    ok & ws$window_n_valid >= 2L
  }
}

# Selection engine -------------------------------------------------------------

anchor_empty_thresholds <- function() {
  data.frame(
    type = character(0), stage = integer(0), step = integer(0),
    target = character(0), rule = integer(0), variable = character(0),
    operator = character(0), scale = character(0),
    prob_lower = numeric(0), prob_upper = numeric(0),
    value_lower = numeric(0), value_upper = numeric(0),
    domain = character(0), domain_n = integer(0),
    quantile_type = integer(0)
  )
}

anchor_threshold_row <- function(type, stage, step, target, rule, variable,
                                 operator, scale, prob, value, domain,
                                 domain_n, quantile_type) {
  lower <- operator %in% c(">=", ">", "between")
  upper <- operator %in% c("<=", "<", "between")
  pick <- function(x, side) {
    if (is.null(x) || operator == "in") return(NA_real_)
    if (operator == "between") return(x[if (side == "lower") 1L else 2L])
    keep <- (side == "lower" && lower) || (side == "upper" && upper)
    if (keep) x[1L] else NA_real_
  }
  data.frame(
    type = type, stage = as.integer(stage), step = as.integer(step),
    target = target, rule = as.integer(rule), variable = variable,
    operator = operator, scale = scale,
    prob_lower = pick(prob, "lower"), prob_upper = pick(prob, "upper"),
    value_lower = pick(value, "lower"), value_upper = pick(value, "upper"),
    domain = domain, domain_n = as.integer(domain_n),
    quantile_type = as.integer(quantile_type)
  )
}

anchor_funnel_rows <- function(type, stage, step, filter, n) {
  data.frame(type = type, stage = as.integer(stage), step = as.integer(step),
             filter = filter, n = as.integer(n))
}

#' Pick the anchor cells among the candidates
#' @noRd
anchor_pick_cells <- function(v, idx, pick, quantile_type) {
  n_cand <- length(idx)
  if (n_cand == 0L) {
    return(list(cells = integer(0), ties = FALSE, prob = NULL, value = NULL,
                operator = NA_character_, scale = NA_character_))
  }
  ties <- FALSE
  prob <- NULL
  if (pick$method == "lowest_fraction") {
    prob <- pick$value
    thr <- stats::quantile(v, prob, type = quantile_type, names = FALSE)
    sel <- idx[v <= thr]
    operator <- "<="
    scale <- "percentile"
  } else if (pick$method == "highest_fraction") {
    prob <- 1 - pick$value
    thr <- stats::quantile(v, prob, type = quantile_type, names = FALSE)
    sel <- idx[v >= thr]
    operator <- ">="
    scale <- "percentile"
  } else {
    o <- if (pick$method == "lowest") order(v, idx) else order(-v, idx)
    k <- min(as.integer(pick$value), n_cand)
    sel <- idx[o[seq_len(k)]]
    thr <- v[o[k]]
    ties <- k < n_cand && v[o[k + 1L]] == thr
    operator <- if (pick$method == "lowest") "<=" else ">="
    scale <- "rank"
  }
  list(cells = sort(sel), ties = ties, prob = prob, value = thr,
       operator = operator, scale = scale)
}

#' Run one criteria step for one class on one search domain
#' @noRd
anchor_run <- function(type, criteria, layers, usable, grid, stage, step) {
  vars <- anchor_used_variables(criteria)
  valid <- usable
  for (v in vars) {
    valid <- valid & !is.na(layers[[v]])
  }
  domain <- valid
  if (criteria$percentile_domain == "land") {
    domain <- domain & !is.na(layers$ndvi) & layers$ndvi > 0
  }
  qt <- criteria$quantile_type
  funnel <- anchor_funnel_rows(
    type, stage, step,
    c("total", "usable", "valid", "percentile_domain"),
    c(grid$n, sum(usable), sum(valid), sum(domain))
  )
  thresholds <- list()
  rules <- criteria[[type]]
  needs_pct <- any(vapply(rules, function(r) r$scale == "percentile",
                          logical(1)))
  if (needs_pct && !any(domain)) {
    return(list(cells = integer(0), ties = FALSE, empty_domain = TRUE,
                funnel = funnel, thresholds = anchor_empty_thresholds(),
                homogeneity = criteria$homogeneity))
  }

  cand <- valid
  for (i in seq_along(rules)) {
    r <- rules[[i]]
    x <- layers[[r$variable]]
    if (r$scale == "percentile") {
      thr <- stats::quantile(x[domain], r$value, type = qt, names = FALSE)
      thresholds[[length(thresholds) + 1L]] <- anchor_threshold_row(
        type, stage, step, "rule", i, r$variable, r$operator, r$scale,
        r$value, thr, criteria$percentile_domain, sum(domain), qt
      )
    } else {
      thr <- r$value
      thresholds[[length(thresholds) + 1L]] <- anchor_threshold_row(
        type, stage, step, "rule", i, r$variable, r$operator, r$scale,
        NULL, thr, NA_character_, NA_integer_, NA_integer_
      )
    }
    test <- switch(r$operator,
                   ">=" = x >= thr, ">" = x > thr,
                   "<=" = x <= thr, "<" = x < thr,
                   "between" = x >= thr[1L] & x <= thr[2L],
                   "in" = x %in% thr)
    cand <- cand & !is.na(test) & test
    funnel <- rbind(funnel, anchor_funnel_rows(type, stage, step,
                                               anchor_rule_label(r),
                                               sum(cand)))
  }

  h <- criteria$homogeneity
  if (!is.null(h)) {
    idx <- which(cand)
    if (length(idx) > 0L) {
      ws <- anchor_window_stats(layers[[h$variable]], idx, h, grid)
      cand[idx[!anchor_is_homogeneous(ws, h)]] <- FALSE
    }
    funnel <- rbind(funnel, anchor_funnel_rows(type, stage, step,
                                               "homogeneity", sum(cand)))
  }

  idx <- which(cand)
  p <- criteria$select[[type]]
  pk <- anchor_pick_cells(layers[[p$variable]][idx], idx, p, qt)
  if (length(idx) > 0L) {
    thresholds[[length(thresholds) + 1L]] <- anchor_threshold_row(
      type, stage, step, "pick", NA_integer_, p$variable, pk$operator,
      pk$scale, pk$prob, pk$value, "candidates", length(idx),
      if (pk$scale == "percentile") qt else NA_integer_
    )
  }
  funnel <- rbind(funnel, anchor_funnel_rows(type, stage, step, "selected",
                                             length(pk$cells)))
  list(
    cells = pk$cells, ties = pk$ties, empty_domain = FALSE, funnel = funnel,
    thresholds = if (length(thresholds) > 0L) {
      do.call(rbind, thresholds)
    } else {
      anchor_empty_thresholds()
    },
    homogeneity = h
  )
}

# Anchor table and calibration points ------------------------------------------

#' Per-pixel audit table
#' @noRd
anchor_pixel_table <- function(cells, types, layers, usable, grid,
                               homogeneity, inherited, station) {
  o <- order(match(types, anchor_types()), cells)
  cells <- as.integer(cells[o])
  types <- types[o]
  n_pix <- length(cells)
  get <- function(nm) {
    if (is.null(layers[[nm]])) rep(NA_real_, n_pix) else layers[[nm]][cells]
  }
  if (is.null(grid$dim)) {
    row <- col <- rep(NA_integer_, n_pix)
  } else {
    row <- as.integer((cells - 1L) %/% grid$ncol + 1L)
    col <- as.integer((cells - 1L) %% grid$ncol + 1L)
  }
  if (is.null(grid$origin)) {
    x <- y <- rep(NA_real_, n_pix)
  } else {
    x <- grid$origin[1L] + (col - 0.5) * grid$cell_size
    y <- grid$origin[2L] - (row - 0.5) * grid$cell_size
  }
  dist <- if (is.null(station)) {
    rep(NA_real_, n_pix)
  } else {
    sqrt((x - station[1L])^2 + (y - station[2L])^2)
  }
  rank_of <- function(nm) {
    v <- layers[[nm]]
    if (is.null(v)) return(rep(NA_real_, n_pix))
    ref <- v[!is.na(v)]
    vapply(v[cells], function(z) {
      if (is.na(z)) NA_real_ else sum(ref <= z) / length(ref)
    }, numeric(1))
  }

  ws <- data.frame(window_stat = rep(NA_real_, n_pix),
                   window_n_valid = rep(NA_integer_, n_pix),
                   window_n = rep(NA_integer_, n_pix),
                   window_complete = rep(NA, n_pix))
  for (type in anchor_types()) {
    h <- homogeneity[[type]]
    sel <- types == type
    if (!is.null(h) && any(sel)) {
      ws[sel, ] <- anchor_window_stats(layers[[h$variable]], cells[sel], h,
                                       grid)
    }
  }

  data.frame(
    id = seq_len(n_pix),
    type = types,
    cell = cells,
    row = row,
    col = col,
    x = x,
    y = y,
    lst = get("lst"),
    ndvi = get("ndvi"),
    albedo = get("albedo"),
    lai = get("lai"),
    land_cover = get("land_cover"),
    elevation = get("elevation"),
    utc_hour = get("utc_hour"),
    qa = usable[cells],
    ws,
    lst_rank = rank_of("lst"),
    ndvi_rank = rank_of("ndvi"),
    albedo_rank = rank_of("albedo"),
    lai_rank = rank_of("lai"),
    distance_to_station = dist,
    inherited_flags = anchor_inherited_codes(cells, inherited, grid)
  )
}

#' Aggregate the values of one class
#' @noRd
anchor_aggregate <- function(x, aggregate) {
  switch(aggregate,
         mean = mean(x),
         median = stats::median(x),
         none = x[1L])
}

#' One calibration point per class from the per-pixel table
#' @noRd
anchor_calibration_points <- function(pixels, aggregate, call) {
  n_by_type <- vapply(anchor_types(), function(t) sum(pixels$type == t),
                      integer(1))
  if (aggregate == "none" && any(n_by_type != 1L)) {
    ef_abort(
      sprintf(
        paste0("`aggregate = \"none\"` needs exactly one anchor pixel per ",
               "class; found %d cold and %d hot. Choose \"mean\" or ",
               "\"median\"."),
        n_by_type[["cold"]], n_by_type[["hot"]]
      ),
      class = "earthflux_input_error", call = call
    )
  }
  vars <- c("lst", "ndvi", "albedo", "lai", "elevation", "utc_hour")
  rows <- lapply(anchor_types(), function(t) {
    sub <- pixels[pixels$type == t, , drop = FALSE]
    vals <- lapply(vars, function(v) anchor_aggregate(sub[[v]], aggregate))
    names(vals) <- vars
    data.frame(anchor_id = t, type = t, n_pixels = nrow(sub),
               aggregate = aggregate, vals)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Dispersion of the anchor values of each class (long table)
#' @noRd
anchor_dispersion <- function(table, vars) {
  rows <- list()
  for (t in anchor_types()) {
    sub <- table[table$type == t, , drop = FALSE]
    for (v in vars) {
      x <- sub[[v]]
      rows[[length(rows) + 1L]] <- data.frame(
        type = t, variable = v, n = length(x), mean = mean(x),
        median = stats::median(x), sd = stats::sd(x),
        min = if (anyNA(x)) NA_real_ else min(x),
        max = if (anyNA(x)) NA_real_ else max(x)
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Consistency check: the hot point must be hotter than the cold point
#' @noRd
anchor_check_inverted <- function(points, call) {
  ts_cold <- points$lst[points$type == "cold"]
  ts_hot <- points$lst[points$type == "hot"]
  if (!(ts_hot > ts_cold)) {
    ef_abort(
      sprintf(
        paste0("The hot anchor surface temperature (%s K) is not above the ",
               "cold one (%s K); are the classes inverted?"),
        format(ts_hot), format(ts_cold)
      ),
      class = c("earthflux_anchor_inverted", "earthflux_anchor_error"),
      lst_cold = ts_cold, lst_hot = ts_hot, call = call
    )
  }
  invisible(TRUE)
}

#' Object-scope and record-scope flags of a selection (stage A)
#' @noRd
anchor_selection_flags <- function(pixels, origin, relaxed, expanded,
                                   dropped, ties) {
  flags <- list()
  add <- function(cond, code) {
    if (cond) flags[[length(flags) + 1L]] <<- ef_flag(TRUE, code)
  }
  add(origin == "user", "EF_ANCHOR_USER_SUPPLIED")
  add(relaxed, "EF_ANCHOR_CRITERIA_RELAXED")
  add(expanded, "EF_ANCHOR_SEARCH_EXPANDED")
  add(dropped, "EF_ANCHOR_HOMOGENEITY_DROPPED")
  add(ties, "EF_ANCHOR_TIES")
  add(any(table(factor(pixels$type, anchor_types())) == 1L),
      "EF_ANCHOR_SINGLE_PIXEL")
  spread <- vapply(anchor_types(), function(t) {
    u <- pixels$utc_hour[pixels$type == t]
    any(!is.na(u)) && length(unique(u)) > 1L
  }, logical(1))
  add(any(spread), "EF_ANCHOR_OVERPASS_SPREAD")
  incomplete <- !is.na(pixels$window_complete) & !pixels$window_complete
  if (any(incomplete)) {
    flags[[length(flags) + 1L]] <- ef_flag(incomplete,
                                           "EF_ANCHOR_WINDOW_INCOMPLETE")
  }
  flags
}

#' Flag provenance (dev/specs/flags.md section 6.7)
#' @noRd
anchor_flag_provenance <- function(flags, evaluated, pixels) {
  reg <- ef_flag_registry()
  inherited <- if (nrow(pixels) > 0L && any(nzchar(pixels$inherited_flags))) {
    codes <- strsplit(pixels$inherited_flags, ";", fixed = TRUE)
    data.frame(id = rep(pixels$id, lengths(codes)), code = unlist(codes))
  } else {
    data.frame(id = integer(0), code = character(0))
  }
  list(
    registry = reg[reg$code %in% evaluated, , drop = FALSE],
    evaluated = evaluated,
    inherited = inherited,
    counts = data.frame(
      code = vapply(flags, `[[`, "", "code"),
      n_flagged = vapply(flags, `[[`, 0L, "n_flagged"),
      n_total = vapply(flags, `[[`, 0L, "n_total")
    )
  )
}

anchor_selection_codes <- function() {
  c("EF_ANCHOR_USER_SUPPLIED", "EF_ANCHOR_CRITERIA_RELAXED",
    "EF_ANCHOR_SEARCH_EXPANDED", "EF_ANCHOR_HOMOGENEITY_DROPPED",
    "EF_ANCHOR_TIES", "EF_ANCHOR_SINGLE_PIXEL", "EF_ANCHOR_OVERPASS_SPREAD",
    "EF_ANCHOR_WINDOW_INCOMPLETE")
}

#' Assemble an `earthflux_anchors` object
#' @noRd
anchor_object <- function(pixels, aggregate, criteria, thresholds, search,
                          funnel, relaxation, flags, method, origin, grid,
                          note, call, seed_note) {
  points <- anchor_calibration_points(pixels, aggregate, call = call)
  anchor_check_inverted(points, call = call)
  dispersion <- anchor_dispersion(
    pixels, c("lst", "ndvi", "albedo", "lai", "elevation", "utc_hour")
  )
  evaluated <- anchor_selection_codes()
  new_ef_object(
    list(
      pixels = pixels,
      calibration_points = points,
      dispersion = dispersion,
      aggregate = aggregate,
      criteria = criteria,
      thresholds = thresholds,
      search = search,
      funnel = funnel,
      relaxation = relaxation,
      flags = flags,
      method = method,
      origin = origin,
      grid = grid,
      conditions = NULL,
      note = note,
      provenance = list(
        package_version = getNamespaceVersion("EarthFlux")[[1L]],
        r_version = R.version.string,
        date = Sys.time(),
        call = call,
        selection_temperature = "lst",
        cell_order = "row-major from the top left cell (terra order)",
        rank_definition = paste0(
          "fraction of the non-missing cells of the grid with a value ",
          "lower than or equal to the anchor value"
        ),
        seed = seed_note,
        rng_kind = NULL,
        flags = anchor_flag_provenance(flags, evaluated, pixels)
      )
    ),
    "earthflux_anchors"
  )
}

# Stage [A]: automatic selection -----------------------------------------------

#' Automatic selection of the cold and hot anchor pixels
#'
#' @description
#' Selects the cold and hot anchor pixels used by METRIC to calibrate the
#' near-surface temperature difference dT as a function of the surface
#' temperature, following explicit criteria built with
#' [ef_anchor_criteria()]. The selection uses surface variables only (no net
#' radiation, soil heat flux or weather; stage \[A\] of
#' dev/specs/anchor-pixels.md section 1.3), is deterministic and returns a
#' complete audit trail: the anchor pixels and their attributes, one
#' calibration point per class, the computed thresholds, the funnel of
#' candidates, the flags and the provenance. The boundary conditions of
#' the anchors are added afterwards by [ef_anchor_conditions()].
#'
#' @param lst Numeric vector or matrix. Surface temperature \[K\], `> 0`.
#'   Defines the grid: every other layer must have its length and `dim`.
#' @param ndvi Numeric vector or matrix. NDVI \[-\], in \[-1, 1\].
#' @param albedo Numeric vector or matrix. Broadband surface albedo \[-\],
#'   in \[0, 1\].
#' @param lai Numeric vector or matrix or `NULL`. Leaf area index
#'   \[m2 m-2\], `>= 0`. Required if a criterion uses it.
#' @param land_cover Numeric vector or matrix of class codes, or `NULL`.
#'   Required if a criterion uses it.
#' @param qa Logical vector or matrix or `NULL`. `TRUE` for usable cells
#'   (quality control of the surface module); `NULL` means all cells are
#'   usable. No missing values.
#' @param elevation Numeric vector or matrix or `NULL`. Elevation \[m\];
#'   recorded and aggregated for the sensible heat calibration, not used by
#'   the selection.
#' @param utc_hour Numeric vector or matrix or `NULL`. Overpass time of each
#'   cell as a decimal UTC hour, in \[0, 24). Recorded; anchors of one class
#'   with different overpass times are flagged with
#'   `EF_ANCHOR_OVERPASS_SPREAD`.
#' @param search_area Logical vector or matrix (one search domain), an
#'   ordered list of them (staged search, e.g. a radius around a station and
#'   then the whole scene), or `NULL` (the whole grid). No missing values.
#' @param criteria An [ef_anchor_criteria()] object. No default.
#' @param relax `NULL` (no relaxation; the default, decision D-AP-02) or an
#'   ordered list of further [ef_anchor_criteria()] objects, tried in order
#'   for a class that has no candidate with `criteria`.
#' @param aggregate Character. How the anchor pixels of one class are
#'   reduced to the single calibration point of that class (decision P0-9):
#'   `"mean"`, `"median"` or `"none"` (exactly one pixel per class is
#'   required). No default.
#' @param cell_size Numeric or `NULL`. Side of the (square) cells \[m\];
#'   recorded (window size in metres) and needed with `origin`.
#' @param origin Numeric `c(x, y)` or `NULL`. Coordinates of the top left
#'   corner of the grid in a projected CRS in metres; gives the coordinates
#'   of the anchor cell centres.
#' @param crs Character or `NULL`. Coordinate reference system of `origin`
#'   and `station` (recorded only).
#' @param station Numeric `c(x, y)` or `NULL`. Coordinates of the weather
#'   station; gives the distance from each anchor to the station \[m\].
#'   Needs `origin`.
#' @param inherited_flags `NULL` or a list of cell-scope `earthflux_flag`
#'   records evaluated upstream on the grid of `lst` (indices are positions
#'   of the R layers). The codes active at each anchor cell are recorded in
#'   `pixels$inherited_flags` (inheritance rule, dev/specs/flags.md
#'   section 3.4).
#'
#' @return An object of class `c("earthflux_anchors", "list")` with
#'   elements:
#'   * `pixels`: data frame, one row per anchor pixel, ordered by class
#'     (cold, hot) and cell: `id`, `type`, `cell` (terra cell number), `row`,
#'     `col`, `x`, `y` \[m\], `lst` \[K\], `ndvi`, `albedo`, `lai`,
#'     `land_cover`, `elevation` \[m\], `utc_hour` \[h\], `qa`,
#'     `window_stat`, `window_n_valid`, `window_n`, `window_complete`,
#'     `lst_rank`, `ndvi_rank`, `albedo_rank`, `lai_rank` (empirical
#'     cumulative fraction in the grid), `distance_to_station` \[m\] and
#'     `inherited_flags` (codes separated by `;`).
#'   * `calibration_points`: data frame with exactly one row per class
#'     (`"cold"`, `"hot"`): `anchor_id`, `type`, `n_pixels`, `aggregate`,
#'     `lst` \[K\], `ndvi`, `albedo`, `lai`, `elevation` \[m\], `utc_hour`
#'     \[h\]; [ef_anchor_conditions()] adds the energy columns.
#'   * `dispersion`: data frame (`type`, `variable`, `n`, `mean`, `median`,
#'     `sd`, `min`, `max`) of the anchor values of each class.
#'   * `aggregate`, `criteria` (list with `criteria`, `relax` and the
#'     criteria step used per class), `thresholds` (computed thresholds),
#'     `search` (domains and where each class was found), `funnel` (cells
#'     left after each filter, per class, search stage and criteria step),
#'     `relaxation` (relaxation steps used), `flags` (list of
#'     `earthflux_flag`), `method` (`"criteria"`), `origin`
#'     (`"automatic"`), `grid`, `conditions` (`NULL` until
#'     [ef_anchor_conditions()]), `note` and `provenance`.
#'
#' @details
#' Order of operations (dev/specs/anchor-pixels.md section 5.3): (1)
#' validation; (2) usable cells (`qa` and the search domain); (3) valid cells
#' (no missing value in a variable used by the criteria); (4) percentile
#' domain and computed thresholds; (5) rules of each class (all must hold);
#' (6) homogeneity; (7) final pick; (8) one calibration point per class and
#' consistency check; (9) flags and audit trail. Each step adds a row to the
#' funnel.
#'
#' Search domains and relaxation: for each class, the search domains are
#' tried in order and, within each domain, `criteria` and then the steps of
#' `relax`; the first combination that leaves at least one anchor pixel is
#' used and recorded. Using a later domain raises
#' `EF_ANCHOR_SEARCH_EXPANDED`; using a relaxation step raises
#' `EF_ANCHOR_CRITERIA_RELAXED`, and `EF_ANCHOR_HOMOGENEITY_DROPPED` when that
#' step has no homogeneity test while `criteria` had one. Nothing is relaxed
#' without an explicit plan.
#'
#' Other flags: `EF_ANCHOR_SINGLE_PIXEL` (a class has one pixel),
#' `EF_ANCHOR_TIES` (a tie at the limit of a `"lowest"`/`"highest"` pick was
#' resolved by cell number), `EF_ANCHOR_WINDOW_INCOMPLETE` (record scope:
#' rows of `pixels` whose homogeneity window has missing cells or crosses
#' the grid border) and `EF_ANCHOR_OVERPASS_SPREAD`.
#'
#' Errors: no candidate for a class after every domain and step: class
#' `earthflux_anchor_no_candidates` with fields `type` (`"cold"`, `"hot"` or
#' `"both"`), `funnel` and `thresholds`; empty percentile domain:
#' `earthflux_anchor_insufficient_domain`; hot calibration point not hotter
#' than the cold one: `earthflux_anchor_inverted` (fields `lst_cold`,
#' `lst_hot`). All three also inherit `earthflux_anchor_error`. Invalid
#' layers or arguments: `earthflux_input_error`; out-of-domain values:
#' `earthflux_domain_error`. A small thermal contrast or few candidates are
#' not errors and are not flagged: their thresholds have no reference
#' (class II codes `EF_ANCHOR_CONTRAST_LOW`, `EF_ANCHOR_FEW_CANDIDATES`).
#'
#' The selection uses no random numbers and does not modify the random
#' number generator. Selection on the surface temperature referred to an
#' elevation datum (decision D-AP-07) is not available: `lst` is used as
#' given.
#'
#' Verification status: the procedure is a transparent container for
#' user-stated criteria; no criterion is `VERIFICADA`
#' (dev/specs/anchor-pixels.md sections 3 and 10).
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' Allen, R. G., Burnett, B., Kramber, W., Huntington, J., Kjaersgaard, J.,
#' Kilic, A., Kelly, C., & Trezza, R. (2013). Automated calibration of the
#' METRIC-Landsat evapotranspiration process. *Journal of the American Water
#' Resources Association*, 49(3), 563-576. \doi{10.1111/jawr.12056}
#'
#' @family anchor pixel functions
#' @export
#'
#' @examples
#' # A 1 x 12 transect (test case P1 of dev/specs/anchor-pixels.md)
#' lst <- c(321, 324, 318, 312, 309, 306, 303, 299, 297, 296, 291, 305)
#' ndvi <- c(0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90,
#'           -0.20, NA)
#' lai <- c(0.1, 0.2, 0.3, 0.8, 1.2, 1.8, 2.5, 4.0, 4.5, 5.0, 0.0, 1.0)
#' albedo <- c(0.25, 0.40, 0.22, 0.20, 0.19, 0.19, 0.18, 0.18, 0.19, 0.20,
#'             0.06, 0.20)
#' crit <- ef_anchor_criteria(
#'   cold = list(ef_anchor_rule("ndvi", ">=", 0.75, scale = "percentile"),
#'               ef_anchor_rule("lai", ">=", 4, scale = "absolute")),
#'   hot = list(ef_anchor_rule("ndvi", "<=", 0.2, scale = "percentile"),
#'              ef_anchor_rule("ndvi", ">", 0, scale = "absolute"),
#'              ef_anchor_rule("albedo", "between", c(0.10, 0.35),
#'                             scale = "absolute")),
#'   homogeneity = NULL,
#'   select = list(cold = ef_anchor_pick("lst", "lowest_fraction", 0.5),
#'                 hot = ef_anchor_pick("lst", "highest_fraction", 0.5)),
#'   percentile_domain = "land", quantile_type = 7,
#'   source = "test parameters (dev/specs/anchor-pixels.md 7.1)",
#'   status = "CANDIDATA"
#' )
#' anchors <- ef_select_anchors(lst, ndvi, albedo, lai = lai,
#'                              criteria = crit, aggregate = "mean")
#' anchors
#' anchors$calibration_points
ef_select_anchors <- function(lst, ndvi, albedo, lai = NULL, land_cover = NULL,
                              qa = NULL, elevation = NULL, utc_hour = NULL,
                              search_area = NULL, criteria, relax = NULL,
                              aggregate, cell_size = NULL, origin = NULL,
                              crs = NULL, station = NULL,
                              inherited_flags = NULL) {
  call <- sys.call()
  anchor_require(missing(lst), "lst", call)
  anchor_require(missing(ndvi), "ndvi", call)
  anchor_require(missing(albedo), "albedo", call)
  anchor_require(missing(criteria), "criteria", call)
  if (!inherits(criteria, "earthflux_anchor_criteria")) {
    ef_abort("`criteria` must be an `ef_anchor_criteria()` object.",
             class = "earthflux_input_error", call = call)
  }
  if (!is.null(relax)) {
    ok <- is.list(relax) && !is.object(relax) && length(relax) > 0L &&
      all(vapply(relax, inherits, logical(1),
                 what = "earthflux_anchor_criteria"))
    if (!ok) {
      ef_abort(
        "`relax` must be NULL or a non-empty list of `ef_anchor_criteria()` objects.",
        class = "earthflux_input_error", call = call
      )
    }
  }
  check_method(aggregate, c("mean", "median", "none"), arg = "aggregate",
               call = call)

  grid <- anchor_grid(lst, cell_size, origin, crs, call)
  layers <- anchor_layers(lst, ndvi, albedo, lai, land_cover, elevation,
                          utc_hour, grid, call)
  station <- anchor_check_station(station, grid, call)
  inherited <- anchor_check_inherited(inherited_flags, grid, call)

  usable <- rep(TRUE, grid$n)
  if (!is.null(qa)) {
    anchor_check_layer(qa, "qa", grid, logical = TRUE, call = call)
    usable <- anchor_cells_of(qa, grid)
  }
  stages <- if (is.null(search_area)) {
    list()
  } else if (is.list(search_area)) {
    if (length(search_area) == 0L) {
      ef_abort("`search_area` must not be an empty list.",
               class = "earthflux_input_error", call = call)
    }
    search_area
  } else {
    list(search_area)
  }
  for (s in seq_along(stages)) {
    anchor_check_layer(stages[[s]], "search_area", grid, logical = TRUE,
                       call = call)
    stages[[s]] <- anchor_cells_of(stages[[s]], grid)
  }
  if (length(stages) == 0L) {
    stages <- list(rep(TRUE, grid$n))
  }

  steps <- c(list(criteria), relax)
  for (st in steps) {
    if (!is.null(st$homogeneity) && is.null(grid$dim)) {
      ef_abort(
        "A homogeneity test needs matrix layers (cell neighbourhoods).",
        class = "earthflux_input_error", call = call
      )
    }
    for (v in anchor_used_variables(st)) {
      if (is.null(layers[[v]])) {
        ef_abort(
          sprintf("The criteria use `%s`, which was not supplied.", v),
          class = c("earthflux_missing_input", "earthflux_input_error"),
          call = call
        )
      }
    }
  }

  # Search: domains in order, criteria steps in order, per class.
  funnel <- list()
  thresholds <- list()
  found <- list()
  for (type in anchor_types()) {
    all_empty_domain <- TRUE
    for (s in seq_along(stages)) {
      for (k in seq_along(steps)) {
        res <- anchor_run(type, steps[[k]], layers, usable & stages[[s]],
                          grid, s, k)
        funnel[[length(funnel) + 1L]] <- res$funnel
        thresholds[[length(thresholds) + 1L]] <- res$thresholds
        all_empty_domain <- all_empty_domain && res$empty_domain
        if (length(res$cells) > 0L) {
          found[[type]] <- c(res, list(stage = s, step = k))
          break
        }
      }
      if (!is.null(found[[type]])) break
    }
    if (is.null(found[[type]])) {
      found[[type]] <- list(cells = integer(0), empty_domain = all_empty_domain)
    }
  }
  funnel <- do.call(rbind, funnel)
  rownames(funnel) <- NULL
  thresholds <- do.call(rbind, thresholds)
  rownames(thresholds) <- NULL

  missing_types <- anchor_types()[vapply(found, function(f) {
    length(f$cells) == 0L
  }, logical(1))]
  if (length(missing_types) > 0L) {
    anchor_abort_no_candidates(missing_types, found, funnel, thresholds,
                               call)
  }

  homog <- lapply(found, `[[`, "homogeneity")
  pixels <- anchor_pixel_table(
    cells = c(found$cold$cells, found$hot$cells),
    types = rep(anchor_types(), c(length(found$cold$cells),
                                  length(found$hot$cells))),
    layers = layers, usable = usable, grid = grid, homogeneity = homog,
    inherited = inherited, station = station
  )
  used <- data.frame(type = anchor_types(),
                     stage = c(found$cold$stage, found$hot$stage),
                     step = c(found$cold$step, found$hot$step))
  relaxed <- any(used$step > 1L)
  expanded <- any(used$stage > 1L)
  dropped <- !is.null(criteria$homogeneity) &&
    any(vapply(homog, is.null, logical(1)))
  ties <- isTRUE(found$cold$ties) || isTRUE(found$hot$ties)
  flags <- anchor_selection_flags(pixels, "automatic", relaxed, expanded,
                                  dropped, ties)

  search <- list(
    n_cells = grid$n,
    n_usable = sum(usable),
    stages = data.frame(stage = seq_along(stages),
                        n_cells = vapply(stages, sum, integer(1)),
                        n_usable = vapply(stages, function(s) {
                          sum(usable & s)
                        }, integer(1))),
    used = used,
    cell_size = cell_size,
    window_m = vapply(anchor_types(), function(t) {
      h <- homog[[t]]
      if (is.null(h) || is.null(cell_size)) NA_real_ else h$window * cell_size
    }, numeric(1)),
    crs = crs,
    station = station
  )
  relaxation <- used[used$step > 1L, c("type", "step"), drop = FALSE]
  rownames(relaxation) <- NULL

  anchor_object(
    pixels = pixels, aggregate = aggregate,
    criteria = list(criteria = criteria, relax = relax,
                    step_used = anchor_named(used$step, used$type)),
    thresholds = thresholds, search = search, funnel = funnel,
    relaxation = relaxation, flags = flags, method = "criteria",
    origin = "automatic", grid = grid, note = NULL, call = call,
    seed_note = NULL
  )
}

#' Named vector helper
#' @noRd
anchor_named <- function(x, nms) {
  names(x) <- nms
  x
}

#' Check station coordinates
#' @noRd
anchor_check_station <- function(station, grid, call) {
  if (is.null(station)) {
    return(NULL)
  }
  if (is.null(grid$origin)) {
    ef_abort("`station` needs `origin` and `cell_size` (grid coordinates).",
             class = "earthflux_input_error", call = call)
  }
  if (!is.numeric(station) || length(station) != 2L || anyNA(station)) {
    ef_abort("`station` must be c(x, y).", class = "earthflux_input_error",
             call = call)
  }
  check_in_range(station, "station", call = call)
  as.numeric(station)
}

#' Error for a class without candidates
#' @noRd
anchor_abort_no_candidates <- function(missing_types, found, funnel,
                                       thresholds, call) {
  type <- if (length(missing_types) == 2L) "both" else missing_types
  empty_domain <- all(vapply(found[missing_types], `[[`, logical(1),
                             "empty_domain"))
  where <- vapply(missing_types, function(t) {
    f <- funnel[funnel$type == t, , drop = FALSE]
    key <- paste(f$stage, f$step)
    last <- f[key == key[length(key)], , drop = FALSE]
    first_zero <- last$filter[last$n == 0L][1L]
    sprintf("%s: the set became empty at filter '%s' (search stage %d, criteria step %d)",
            t, first_zero, last$stage[1L], last$step[1L])
  }, character(1))
  if (empty_domain) {
    ef_abort(
      paste0("The percentile domain is empty; no threshold can be computed (",
             paste(where, collapse = "; "), ")."),
      class = c("earthflux_anchor_insufficient_domain",
                "earthflux_anchor_error"),
      type = type, funnel = funnel, thresholds = thresholds, call = call
    )
  }
  ef_abort(
    paste0("No anchor candidates for class ", type, " (",
           paste(where, collapse = "; "),
           "). Criteria are never relaxed without an explicit `relax` plan."),
    class = c("earthflux_anchor_no_candidates", "earthflux_anchor_error"),
    type = type, funnel = funnel, thresholds = thresholds, call = call
  )
}

# Stage [A]: explicit (user-supplied) anchors ----------------------------------

#' Explicit (user-supplied) anchor pixels
#'
#' @description
#' Builds the anchor pixels of the METRIC calibration from cells or
#' coordinates chosen by the user (manual selection, required by
#' dev/SCIENTIFIC_SPEC.md section 7). The result has the same class and the
#' same audit table as [ef_select_anchors()]: the attributes of each anchor
#' pixel are extracted from the same layers and the same statistics are
#' computed, so that a manual selection is auditable in the same way.
#'
#' @param cold,hot Cell numbers (whole numbers, numbered row by row from the
#'   top left cell, as in terra) or a two-column matrix or data frame of
#'   coordinates `x`, `y` (cell centres or any point in the cell; needs
#'   `origin`, `cell_size` and `crs`). At least one per class; no cell may
#'   appear twice.
#' @param aggregate Character. `"mean"`, `"median"` or `"none"`, as in
#'   [ef_select_anchors()]. No default.
#' @param homogeneity `NULL` or an [ef_homogeneity()] object whose window
#'   statistics are recorded for each anchor (anchors are never discarded).
#' @param note Character or `NULL`. Free text (reason for the selection).
#' @inheritParams ef_select_anchors
#'
#' @return An object of class `c("earthflux_anchors", "list")` with the
#'   elements described in [ef_select_anchors()]; `method = "manual"`,
#'   `origin = "user"`, `criteria`, `thresholds`, `search`, `funnel` and
#'   `relaxation` are `NULL`, and the flag `EF_ANCHOR_USER_SUPPLIED` is
#'   present.
#'
#' @details
#' Invariant: with the cells of an automatic selection, the same layers,
#' the same homogeneity object and the same `aggregate`, `pixels` and
#' `calibration_points` are identical to those of [ef_select_anchors()].
#'
#' Errors: a cell or coordinate outside the grid raises
#' `earthflux_anchor_outside_grid` (field `index`); a missing surface
#' temperature at an anchor raises `earthflux_anchor_na_input` (fields
#' `variable`, `index`); a hot calibration point not hotter than the cold
#' one raises `earthflux_anchor_inverted`. All also inherit
#' `earthflux_anchor_error`; the first two also `earthflux_input_error`.
#'
#' @family anchor pixel functions
#' @export
#'
#' @examples
#' lst <- matrix(c(300, 301, 299, 320,
#'                 298, 300, 302, 322,
#'                 297, 301, 300, 321), nrow = 3, byrow = TRUE)
#' ndvi <- matrix(c(0.5, 0.5, 0.6, 0.1,
#'                  0.8, 0.5, 0.4, 0.1,
#'                  0.9, 0.5, 0.5, 0.1), nrow = 3, byrow = TRUE)
#' albedo <- matrix(0.2, nrow = 3, ncol = 4)
#' # Cells are numbered row by row: cell 9 is row 3, column 1
#' anchors <- ef_anchors(cold = 9, hot = 8, lst = lst, ndvi = ndvi,
#'                       albedo = albedo, aggregate = "none",
#'                       note = "irrigated field and fallow plot")
#' anchors$pixels[, c("type", "cell", "row", "col", "lst")]
ef_anchors <- function(cold, hot, lst, ndvi, albedo, lai = NULL,
                       land_cover = NULL, qa = NULL, elevation = NULL,
                       utc_hour = NULL, homogeneity = NULL, aggregate,
                       cell_size = NULL, origin = NULL, crs = NULL,
                       station = NULL, inherited_flags = NULL, note = NULL) {
  call <- sys.call()
  anchor_require(missing(cold), "cold", call)
  anchor_require(missing(hot), "hot", call)
  anchor_require(missing(lst), "lst", call)
  anchor_require(missing(ndvi), "ndvi", call)
  anchor_require(missing(albedo), "albedo", call)
  check_method(aggregate, c("mean", "median", "none"), arg = "aggregate",
               call = call)
  if (!is.null(note)) check_string(note, "note")
  if (!is.null(homogeneity) &&
      !inherits(homogeneity, "earthflux_homogeneity")) {
    ef_abort("`homogeneity` must be an `ef_homogeneity()` object or NULL.",
             class = "earthflux_input_error", call = call)
  }

  grid <- anchor_grid(lst, cell_size, origin, crs, call)
  layers <- anchor_layers(lst, ndvi, albedo, lai, land_cover, elevation,
                          utc_hour, grid, call)
  station <- anchor_check_station(station, grid, call)
  inherited <- anchor_check_inherited(inherited_flags, grid, call)
  if (!is.null(homogeneity)) {
    if (is.null(grid$dim)) {
      ef_abort("A homogeneity test needs matrix layers (cell neighbourhoods).",
               class = "earthflux_input_error", call = call)
    }
    if (is.null(layers[[homogeneity$variable]])) {
      ef_abort(sprintf("The homogeneity test uses `%s`, which was not supplied.",
                       homogeneity$variable),
               class = c("earthflux_missing_input", "earthflux_input_error"),
               call = call)
    }
  }
  usable <- rep(TRUE, grid$n)
  if (!is.null(qa)) {
    anchor_check_layer(qa, "qa", grid, logical = TRUE, call = call)
    usable <- anchor_cells_of(qa, grid)
  }

  cells <- list(cold = anchor_user_cells(cold, "cold", grid, call),
                hot = anchor_user_cells(hot, "hot", grid, call))
  if (any(cells$cold %in% cells$hot)) {
    ef_abort("A cell cannot be both a cold and a hot anchor.",
             class = "earthflux_input_error",
             index = intersect(cells$cold, cells$hot), call = call)
  }
  all_cells <- c(cells$cold, cells$hot)
  na_lst <- is.na(layers$lst[all_cells])
  if (any(na_lst)) {
    ef_abort(
      sprintf("The surface temperature `lst` is missing at anchor cell(s) %s.",
              paste(all_cells[na_lst], collapse = ", ")),
      class = c("earthflux_anchor_na_input", "earthflux_anchor_error",
                "earthflux_input_error"),
      variable = "lst", index = all_cells[na_lst], call = call
    )
  }

  pixels <- anchor_pixel_table(
    cells = all_cells,
    types = rep(anchor_types(), lengths(cells)),
    layers = layers, usable = usable, grid = grid,
    homogeneity = list(cold = homogeneity, hot = homogeneity),
    inherited = inherited, station = station
  )
  flags <- anchor_selection_flags(pixels, "user", FALSE, FALSE, FALSE, FALSE)
  anchor_object(
    pixels = pixels, aggregate = aggregate, criteria = NULL,
    thresholds = NULL, search = NULL, funnel = NULL, relaxation = NULL,
    flags = flags, method = "manual", origin = "user", grid = grid,
    note = note, call = call, seed_note = NULL
  )
}

#' Convert user anchors (cells or coordinates) to cell numbers
#' @noRd
anchor_user_cells <- function(x, arg, grid, call) {
  if (is.data.frame(x) || is.matrix(x)) {
    if (ncol(x) != 2L) {
      ef_abort(sprintf("Coordinates in `%s` must have two columns (x, y).",
                       arg),
               class = "earthflux_input_error", call = call)
    }
    if (is.null(grid$origin) || is.null(grid$crs)) {
      ef_abort("Coordinates need `origin`, `cell_size` and `crs`.",
               class = c("earthflux_missing_input", "earthflux_input_error"),
               call = call)
    }
    xy <- as.matrix(x)
    if (!is.numeric(xy) || anyNA(xy)) {
      ef_abort(sprintf("Coordinates in `%s` must be numeric and complete.",
                       arg),
               class = "earthflux_input_error", call = call)
    }
    col <- floor((xy[, 1L] - grid$origin[1L]) / grid$cell_size) + 1
    row <- floor((grid$origin[2L] - xy[, 2L]) / grid$cell_size) + 1
    out <- row < 1 | row > grid$nrow | col < 1 | col > grid$ncol
    if (any(out)) {
      ef_abort(
        sprintf("%d %s anchor coordinate(s) fall outside the grid.",
                sum(out), arg),
        class = c("earthflux_anchor_outside_grid", "earthflux_anchor_error",
                  "earthflux_input_error"),
        index = which(out), call = call
      )
    }
    cells <- as.integer((row - 1) * grid$ncol + col)
  } else {
    if (!is.numeric(x) || length(x) == 0L || anyNA(x) ||
        any(x != round(x))) {
      ef_abort(sprintf("`%s` must be whole cell numbers or coordinates.", arg),
               class = "earthflux_input_error", call = call)
    }
    out <- x < 1 | x > grid$n
    if (any(out)) {
      ef_abort(
        sprintf("%s anchor cell(s) %s outside the grid (1 to %d).",
                arg, paste(x[out], collapse = ", "), grid$n),
        class = c("earthflux_anchor_outside_grid", "earthflux_anchor_error",
                  "earthflux_input_error"),
        index = which(out), call = call
      )
    }
    cells <- as.integer(x)
  }
  if (anyDuplicated(cells) > 0L) {
    ef_abort(sprintf("`%s` contains the same cell more than once.", arg),
             class = "earthflux_input_error", call = call)
  }
  cells
}

# Stage [B]: boundary conditions -----------------------------------------------

#' Boundary conditions at the anchor pixels
#'
#' @description
#' Completes an anchor set ([ef_select_anchors()] or [ef_anchors()]) with
#' the boundary conditions of the METRIC calibration (stage \[B\] of
#' dev/specs/anchor-pixels.md section 1.3, decision D-AP-03): at each anchor
#' pixel, the target latent heat flux \eqn{LE}{LE} and the target sensible
#' heat flux \eqn{H = R_n - G - LE}{H = Rn - G - LE}, from the net
#' radiation, the soil heat flux and the instantaneous reference
#' evapotranspiration at that pixel; then one calibration point per class,
#' which is what the sensible heat calibration consumes.
#'
#' @param anchors An `earthflux_anchors` object.
#' @param rn Numeric vector or matrix on the grid of the anchors. Net
#'   radiation \[W m-2\] (e.g. [ef_net_radiation()]). Finite where not
#'   missing; must not be missing at an anchor pixel.
#' @param g Numeric vector or matrix on the same grid. Soil heat flux
#'   \[W m-2\]. Same conditions as `rn`.
#' @param etr_inst Numeric. Instantaneous reference evapotranspiration
#'   \[mm h-1\], `> 0`: a single value for the scene (one station) or a layer
#'   on the grid (e.g. a regionalised surface), evaluated at the overpass time
#'   of each pixel. Its value at each anchor pixel is used.
#' @param lambda Numeric. Latent heat of vaporization \[J kg-1\] from
#'   [ef_lambda()], a single value or a layer on the grid. The same `lambda`
#'   (same method) must be used in the conversion of LE to ET (decision
#'   P0-7). Checked to lie in \[1e6, 1e7\] (unit guard).
#' @param etrf_cold Numeric. Reference ET fraction imposed at the cold
#'   anchor, the coefficient \eqn{k}{k} of \eqn{ET_{cold} = k \cdot
#'   ET_{r,inst}}{ET_cold = k * ETr_inst} \[-\]; finite and `> 0`. No default
#'   (decision D-AP-04).
#' @param etrf_hot,le_hot Numeric. Condition of the hot anchor; give exactly
#'   one: the reference ET fraction at the hot anchor (`etrf_hot`, finite and
#'   `>= 0`; 0 for dry bare soil) or its latent heat flux (`le_hot`
#'   \[W m-2\], finite and `>= 0`). No default (decision D-AP-05).
#' @param reference Character. Reference surface of `etr_inst`: `"alfalfa"`
#'   (ETr) or `"grass"` (ETo). Must be the reference of the daily
#'   extrapolation (checked by the orchestration).
#' @param source Character. Source of `etrf_cold` and of the hot condition.
#' @param status Character. Their verification status: `"TODO"`,
#'   `"CANDIDATA"` or `"VERIFICADA"`.
#' @param etr_source Character or `NULL`. Origin of `etr_inst` (e.g.
#'   `"station"`, `"gwr"`), recorded.
#' @param zom,u_blend,pressure Numeric or `NULL`. Optional inputs of the
#'   sensible heat calibration passed through to the calibration points, so
#'   that `ef_calibrate_h()` can read the anchor object directly: momentum
#'   roughness length \[m\] (`> 0`, e.g. from `ef_zom()` on the grid),
#'   wind speed at the blending height \[m s-1\] (`>= 0`) and atmospheric
#'   pressure \[kPa\] (`> 0`, e.g. [ef_air_pressure()]). Each is a single
#'   value or a layer on the grid; its value at each anchor pixel is
#'   aggregated with the `aggregate` of the anchor set. Not used in the
#'   boundary conditions.
#'
#' @return The `earthflux_anchors` object with:
#'   * `calibration_points` completed with the columns `rn`, `g` \[W m-2\],
#'     `etr_inst` \[mm h-1\], `lambda` \[J kg-1\], `etrf` \[-\],
#'     `le_target` and `h_target` \[W m-2\], with
#'     `h_target = rn - g - le_target` exactly in each row, followed by
#'     `zom` \[m\], `u_blend` \[m s-1\] and `pressure` \[kPa\] when
#'     given. With them, `calibration_points` has every column required by
#'     the sensible heat calibration (`type`, `lst`, `elevation`, `zom`,
#'     `rn`, `g`, `le_target`, `u_blend`, `pressure`; `anchor_id`
#'     optional), one row per class;
#'   * `conditions`: a list with `pixels` (per anchor pixel: `id`, `type`,
#'     `cell`, `utc_hour`, `rn`, `g`, `etr_inst`, `lambda`, `etrf`,
#'     `le_target`, `h_target`), `etrf_cold`, `hot_condition` (`"etrf"` or
#'     `"le"`), `etrf_hot`, `le_hot`, `reference`, `etr_source`,
#'     `etr_inst_layer` and `lambda_layer` (whether a layer was used),
#'     `source`, `status` and `equations`;
#'   * `dispersion` completed with the new variables;
#'   * `flags` completed with `EF_ANCHOR_COLD_H_NEGATIVE` (record scope:
#'     rows of `pixels` of the cold class with \eqn{H < 0}{H < 0}) and
#'     `EF_ANCHOR_HOT_LE_ASSUMED_ZERO` (object scope: the hot LE is 0 by
#'     assumption, not from a soil water balance).
#'
#' @details
#' At each anchor pixel \eqn{i}{i}:
#' \deqn{ET_i = ETrF_i \cdot ET_{r,inst,i}}{ET_i = ETrF_i * ETr_inst_i}
#' \deqn{LE_i = \frac{ET_i \, \lambda_i \, \rho_w}{3600 \times 1000}}{LE_i =
#'   ET_i * lambda_i * rho_w / (3600 * 1000)}
#' \deqn{H_i = R_{n,i} - G_i - LE_i}{H_i = Rn_i - G_i - LE_i}
#' with \eqn{ETrF_i}{ETrF_i} = `etrf_cold` for cold pixels and `etrf_hot`
#' for hot pixels (or \eqn{LE_i}{LE_i} = `le_hot`), \eqn{\rho_w}{rho_w} =
#' 1000 kg m-3, 3600 s h-1 and 1000 mm m-1. The calibration point of each
#' class aggregates `rn`, `g`, `etr_inst`, `lambda` and `le_target` with the
#' `aggregate` of the anchor set and sets `h_target = rn - g - le_target`
#' (for `"mean"` this equals the mean of the per-pixel targets).
#' `etrf` of the hot point is derived from `le_target` when `le_hot` is
#' given.
#'
#' Assumptions (`CANDIDATA`): the cold anchor is fully covered, well
#' watered agricultural vegetation evaporating at `etrf_cold` times the
#' reference; the hot anchor is dry agricultural bare soil; `etr_inst` is
#' representative of each anchor location and overpass time; no lateral
#' heat transport. A negative \eqn{H}{H} at the cold anchor is not an error
#' (advection) but it is flagged.
#'
#' Errors: a missing `rn`, `g`, `etr_inst` or `lambda` at an anchor pixel
#' raises `earthflux_anchor_na_input` (fields `variable`, `index` = rows of
#' `pixels`); invalid or out-of-domain arguments raise
#' `earthflux_input_error` / `earthflux_domain_error`; `etr_inst <= 0`
#' raises `earthflux_domain_error`.
#'
#' Verification status: `CANDIDATA`. The form of the cold condition is
#' attributed to Allen et al. (2007) by secondary sources; the value 1.05 of
#' \eqn{k}{k} with an alfalfa reference and \eqn{ETrF = 0}{ETrF = 0} for
#' dry bare soil are observed in the `water` package (no default here). The
#' unit conversion is `VERIFICADA` (FAO-56, box 8, with 3600 s h-1).
#'
#' @references
#' Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
#' balance for mapping evapotranspiration with internalized calibration
#' (METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
#' 133(4), 380-394. \doi{10.1061/(ASCE)0733-9437(2007)133:4(380)}
#'
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' @family anchor pixel functions
#' @export
#'
#' @examples
#' lst <- c(300, 321, 310)
#' anchors <- ef_anchors(cold = 1, hot = 2, lst = lst,
#'                       ndvi = c(0.85, 0.10, 0.4),
#'                       albedo = c(0.20, 0.25, 0.2), aggregate = "none")
#' # Coefficients are test values (CANDIDATA), not defaults
#' anchors <- ef_anchor_conditions(
#'   anchors, rn = c(700, 500, 600), g = c(100, 120, 110), etr_inst = 0.8,
#'   lambda = ef_lambda(method = "constant"), etrf_cold = 1.05,
#'   etrf_hot = 0, reference = "alfalfa",
#'   source = "test values observed in the water package",
#'   status = "CANDIDATA", etr_source = "station"
#' )
#' anchors$calibration_points[, c("type", "lst", "rn", "g", "le_target",
#'                                "h_target")]
ef_anchor_conditions <- function(anchors, rn, g, etr_inst, lambda, etrf_cold,
                                 etrf_hot = NULL, le_hot = NULL, reference,
                                 source, status, etr_source = NULL,
                                 zom = NULL, u_blend = NULL,
                                 pressure = NULL) {
  call <- sys.call()
  anchor_require(missing(anchors), "anchors", call)
  if (!inherits(anchors, "earthflux_anchors")) {
    ef_abort("`anchors` must be an `earthflux_anchors` object.",
             class = "earthflux_input_error", call = call)
  }
  anchor_require(missing(rn), "rn", call)
  anchor_require(missing(g), "g", call)
  anchor_require(missing(etr_inst), "etr_inst", call)
  anchor_require(missing(lambda), "lambda", call)
  anchor_require(missing(etrf_cold), "etrf_cold", call)
  anchor_require(missing(source), "source", call)
  grid <- anchors$grid
  anchor_check_layer(rn, "rn", grid, call = call)
  anchor_check_layer(g, "g", grid, call = call)
  check_in_range(rn, "rn", call = call)
  check_in_range(g, "g", call = call)
  check_numeric(etr_inst, "etr_inst", call = call)
  if (length(etr_inst) != 1L) {
    anchor_check_layer(etr_inst, "etr_inst", grid, call = call)
  }
  check_numeric(lambda, "lambda", call = call)
  if (length(lambda) != 1L) {
    anchor_check_layer(lambda, "lambda", grid, call = call)
  }
  check_in_range(etr_inst, "etr_inst", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_latent_heat_units(lambda, "lambda", call = call)
  check_scalar(etrf_cold, "etrf_cold", lower = 0,
                      lower_inclusive = FALSE, call = call)
  if (is.null(etrf_hot) == is.null(le_hot)) {
    ef_abort(
      "Give exactly one hot anchor condition: `etrf_hot` or `le_hot`.",
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (!is.null(etrf_hot)) {
    check_scalar(etrf_hot, "etrf_hot", lower = 0, call = call)
  } else {
    check_scalar(le_hot, "le_hot", lower = 0, call = call)
  }
  check_reference_type(if (missing(reference)) NULL else reference,
                       call = call)
  check_string(source, "source")
  check_method(status, anchor_statuses(), arg = "status", call = call)
  if (!is.null(etr_source)) check_string(etr_source, "etr_source")
  passthrough <- list(zom = zom, u_blend = u_blend, pressure = pressure)
  passthrough <- passthrough[!vapply(passthrough, is.null, logical(1))]
  for (nm in names(passthrough)) {
    x <- passthrough[[nm]]
    check_numeric(x, nm, call = call)
    if (length(x) != 1L) anchor_check_layer(x, nm, grid, call = call)
  }
  if (!is.null(zom)) {
    check_in_range(zom, "zom", lower = 0, lower_inclusive = FALSE,
                   call = call)
  }
  if (!is.null(u_blend)) {
    check_in_range(u_blend, "u_blend", lower = 0, call = call)
  }
  if (!is.null(pressure)) {
    check_in_range(pressure, "pressure", lower = 0, lower_inclusive = FALSE,
                   call = call)
  }

  px <- anchors$pixels
  cells <- px$cell
  at <- function(x) {
    if (length(x) == 1L) rep(as.numeric(x), length(cells))
    else anchor_cells_of(x, grid)[cells]
  }
  vals <- c(list(rn = at(rn), g = at(g), etr_inst = at(etr_inst),
                 lambda = at(lambda)), lapply(passthrough, at))
  for (nm in names(vals)) {
    miss <- is.na(vals[[nm]])
    if (any(miss)) {
      ef_abort(
        sprintf("`%s` is missing at anchor pixel(s) (rows of `pixels`) %s.",
                nm, paste(px$id[miss], collapse = ", ")),
        class = c("earthflux_anchor_na_input", "earthflux_anchor_error",
                  "earthflux_input_error"),
        variable = nm, index = px$id[miss], call = call
      )
    }
  }

  cold <- px$type == "cold"
  hot_mode <- if (is.null(etrf_hot)) "le" else "etrf"
  etrf <- ifelse(cold, etrf_cold, if (hot_mode == "etrf") etrf_hot else NA)
  le <- ef_et_inst_to_latent_heat(etrf * vals$etr_inst, vals$lambda)
  if (hot_mode == "le") {
    le[!cold] <- le_hot
    etrf[!cold] <- le_hot /
      ef_et_inst_to_latent_heat(vals$etr_inst[!cold], vals$lambda[!cold])
  }
  h <- vals$rn - vals$g - le
  cond_px <- data.frame(
    id = px$id, type = px$type, cell = px$cell, utc_hour = px$utc_hour,
    rn = vals$rn, g = vals$g, etr_inst = vals$etr_inst, lambda = vals$lambda,
    etrf = etrf, le_target = le, h_target = h
  )
  for (nm in names(passthrough)) {
    cond_px[[nm]] <- vals[[nm]]
  }

  points <- anchors$calibration_points[, c("anchor_id", "type", "n_pixels",
                                           "aggregate", "lst", "ndvi",
                                           "albedo", "lai", "elevation",
                                           "utc_hour")]
  agg <- anchors$aggregate
  for (v in c("rn", "g", "etr_inst", "lambda", "le_target",
              names(passthrough))) {
    points[[v]] <- vapply(points$type, function(t) {
      anchor_aggregate(cond_px[[v]][cond_px$type == t], agg)
    }, numeric(1), USE.NAMES = FALSE)
  }
  points$etrf <- ifelse(
    points$type == "cold", etrf_cold,
    if (hot_mode == "etrf") etrf_hot else
      points$le_target /
        ef_et_inst_to_latent_heat(points$etr_inst, points$lambda)
  )
  points$h_target <- points$rn - points$g - points$le_target
  points <- points[, c("anchor_id", "type", "n_pixels", "aggregate", "lst",
                       "ndvi", "albedo", "lai", "elevation", "utc_hour", "rn",
                       "g", "etr_inst", "lambda", "etrf", "le_target",
                       "h_target", names(passthrough))]

  flags <- Filter(function(f) !f$code %in% anchor_condition_codes(),
                  anchors$flags)
  h_neg <- cold & h < 0
  if (any(h_neg)) {
    flags[[length(flags) + 1L]] <- ef_flag(h_neg, "EF_ANCHOR_COLD_H_NEGATIVE")
  }
  hot_zero <- if (hot_mode == "etrf") etrf_hot == 0 else le_hot == 0
  if (hot_zero) {
    flags[[length(flags) + 1L]] <- ef_flag(TRUE,
                                           "EF_ANCHOR_HOT_LE_ASSUMED_ZERO")
  }

  b_vars <- c("rn", "g", "etr_inst", "lambda", "le_target", "h_target",
              "zom", "u_blend", "pressure")
  disp_a <- anchors$dispersion[!anchors$dispersion$variable %in% b_vars, ,
                               drop = FALSE]
  dispersion <- rbind(disp_a, anchor_dispersion(
    cond_px, intersect(b_vars, names(cond_px))
  ))
  rownames(dispersion) <- NULL

  out <- unclass(anchors)
  out$calibration_points <- points
  out$dispersion <- dispersion
  out$flags <- flags
  out$conditions <- list(
    pixels = cond_px,
    etrf_cold = etrf_cold,
    hot_condition = hot_mode,
    etrf_hot = etrf_hot,
    le_hot = le_hot,
    reference = reference,
    etr_source = etr_source,
    passthrough = names(passthrough),
    etr_inst_layer = length(etr_inst) > 1L,
    lambda_layer = length(lambda) > 1L,
    source = source,
    status = status,
    equations = c(
      cold = "le_target = etrf_cold * etr_inst * lambda * rho_w / (3600 * 1000)",
      hot = if (hot_mode == "etrf") {
        "le_target = etrf_hot * etr_inst * lambda * rho_w / (3600 * 1000)"
      } else {
        "le_target = le_hot"
      },
      h = "h_target = rn - g - le_target"
    )
  )
  out$provenance$flags <- anchor_flag_provenance(
    flags, c(anchor_selection_codes(), anchor_condition_codes()), px
  )
  out$provenance$conditions_call <- call
  new_ef_object(out, "earthflux_anchors")
}

# Methods ----------------------------------------------------------------------

#' @export
print.earthflux_anchors <- function(x, ...) {
  cp <- x$calibration_points
  cat("<earthflux_anchors>\n")
  cat(sprintf("Method: %s (origin: %s); aggregate: %s\n", x$method, x$origin,
              x$aggregate))
  status <- if (is.null(x$criteria)) "user-supplied" else
    x$criteria$criteria$status
  cat(sprintf("Criteria status: %s\n", status))
  for (i in seq_len(nrow(cp))) {
    cat(sprintf("  %-4s %3d pixel(s), Ts = %.2f K\n", cp$type[i],
                cp$n_pixels[i], cp$lst[i]))
  }
  cat(sprintf("Ts hot - Ts cold = %.2f K\n",
              cp$lst[cp$type == "hot"] - cp$lst[cp$type == "cold"]))
  if (!is.null(x$relaxation) && nrow(x$relaxation) > 0L) {
    cat("Relaxation steps used:", paste0(x$relaxation$type, " (step ",
                                         x$relaxation$step, ")",
                                         collapse = ", "), "\n")
  }
  if (!is.null(x$conditions)) {
    cat(sprintf("Boundary conditions (%s, %s): H target cold = %.2f, hot = %.2f W m-2\n",
                x$conditions$reference, x$conditions$status,
                cp$h_target[cp$type == "cold"], cp$h_target[cp$type == "hot"]))
  } else {
    cat("Boundary conditions: not set (see ef_anchor_conditions())\n")
  }
  if (length(x$flags) > 0L) {
    sev <- vapply(x$flags, `[[`, "", "severity")
    cat("Flags:", paste(vapply(x$flags, `[[`, "", "code"),
                        paste0("(", sev, ")"), collapse = ", "), "\n")
  } else {
    cat("Flags: none\n")
  }
  invisible(x)
}

#' @export
as.data.frame.earthflux_anchors <- function(x, ...) {
  x$pixels
}

#' @export
print.earthflux_anchor_criteria <- function(x, ...) {
  cat("<earthflux_anchor_criteria>", x$status, "-", x$source, "\n")
  for (type in anchor_types()) {
    cat(sprintf("  %s: %s; pick: %s %s %s\n", type,
                paste(vapply(x[[type]], anchor_rule_label, ""),
                      collapse = " & "),
                x$select[[type]]$method, x$select[[type]]$variable,
                format(x$select[[type]]$value)))
  }
  h <- x$homogeneity
  cat(sprintf("  homogeneity: %s\n", if (is.null(h)) "none" else
    sprintf("%s(%s) <= %s in %d x %d window (%s)", h$stat, h$variable,
            format(h$max), h$window, h$window, h$window_na)))
  cat(sprintf("  percentile domain: %s; quantile type: %d\n",
              x$percentile_domain, x$quantile_type))
  invisible(x)
}

# Diagnostic flags of this stage -----------------------------------------------

#' Flag codes owned by the anchor pixel stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_ANCHOR_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7). Class II
#' codes (`EF_ANCHOR_FEW_CANDIDATES`, `EF_ANCHOR_CONTRAST_LOW`,
#' `EF_ANCHOR_COLD_PARTIAL_COVER`, `EF_ANCHOR_HOT_RECENT_RAIN`) are never
#' registered here until their thresholds have a reference.
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_anchors <- function() {
  spec <- "dev/specs/anchor-pixels.md 6; dev/specs/flags.md 4.2"
  ef_flag_rows(
    code = c(
      "EF_ANCHOR_USER_SUPPLIED",
      "EF_ANCHOR_CRITERIA_RELAXED",
      "EF_ANCHOR_SEARCH_EXPANDED",
      "EF_ANCHOR_HOMOGENEITY_DROPPED",
      "EF_ANCHOR_WINDOW_INCOMPLETE",
      "EF_ANCHOR_TIES",
      "EF_ANCHOR_SINGLE_PIXEL",
      "EF_ANCHOR_COLD_H_NEGATIVE",
      "EF_ANCHOR_HOT_LE_ASSUMED_ZERO",
      "EF_ANCHOR_OVERPASS_SPREAD"
    ),
    stage = rep("ANCHOR", 10L),
    severity = c("info", "warning", "warning", "warning", "warning", "info",
                 "info", "warning", "info", "info"),
    scope = c("object", "object", "object", "object", "record", "object",
              "object", "record", "object", "object"),
    bit = rep(NA_integer_, 10L),
    error_class = rep(NA_character_, 10L),
    description = c(
      "The anchor pixels were supplied by the user.",
      "A class of anchors was found with a step of an explicit relaxation plan.",
      "A class of anchors was found outside the first search domain.",
      "The homogeneity test was dropped for a class by an explicit relaxation step.",
      "The homogeneity window of the anchor pixel has missing cells or crosses the grid border.",
      "Equal values at the limit of the anchor pick were resolved by cell number.",
      "A class of anchors is represented by a single pixel.",
      "The target sensible heat flux at the cold anchor pixel is negative.",
      "The latent heat flux of the hot anchor is zero by assumption, not from a soil water balance.",
      "Anchor pixels of one class have different overpass times."
    ),
    spec = rep(spec, 10L),
    since = rep("0.0.0.9000", 10L)
  )
}
