# S3 classes ----------------------------------------------------------------------
#
# Purpose: lightweight S3 classes for EarthFlux objects.
#
# Convention for M2 (dev/ARCHITECTURE.md section 3.2; DECISIONS.md P0-12,
# T-17): numeric core functions return plain numeric values; only
# procedures whose result describes a whole object (anchor selection, H
# calibration, dispatchers that record method and provenance) return a
# lightweight classed list built with new_ef_object(). Such lists always
# carry a `flags` element (a list of `earthflux_flag`, possibly empty).
#
# Classes created so far:
#   - earthflux_flag (R/diagnostics.R).
#   - earthflux_soil_heat_flux (R/metric-soil-heat.R): output of ef_g().
# Planned classes (created with their first constructor, not before):
#   - earthflux_anchors        : anchor pixel selection and its audit trail;
#   - earthflux_h_calibration  : dT calibration of the sensible heat flux;
#   - earthflux_result         : all intermediate layers + diagnostics +
#                                provenance (M5);
#   - earthflux_gwr            : fitted GWR model (M3).
#
# Avoid premature class hierarchies: one class per object kind, inheriting
# only from "list".

#' Construct a lightweight EarthFlux object
#'
#' Low-level constructor shared by all classed list results. It only checks
#' structure; each object kind adds its own validator next to its
#' constructor.
#'
#' @param x A named list. Names must be unique and non-empty, and `x` must
#'   contain an element `flags`: a list (possibly empty) of `earthflux_flag`
#'   records.
#' @param class Character. Class of the object, most specific first; each
#'   element must start with `earthflux_` (e.g. `"earthflux_anchors"`).
#' @return `x` with class `c(class, "list")`.
#' @noRd
new_ef_object <- function(x, class) {
  call <- sys.call(-1)
  if (!is.list(x) || is.object(x)) {
    ef_abort("`x` must be a plain list.", class = "earthflux_input_error",
             call = call)
  }
  nms <- names(x)
  if (length(x) > 0L &&
      (is.null(nms) || any(is.na(nms) | !nzchar(nms)) ||
         anyDuplicated(nms) > 0L)) {
    ef_abort("`x` must have unique, non-empty names.",
             class = "earthflux_input_error", call = call)
  }
  if (!is.character(class) || length(class) < 1L || anyNA(class) ||
      !all(grepl("^earthflux_[a-z0-9_]+$", class))) {
    ef_abort("`class` must be one or more `earthflux_*` class names.",
             class = "earthflux_input_error", call = call)
  }
  if (!"flags" %in% nms) {
    ef_abort("`x` must contain a `flags` element (possibly an empty list).",
             class = "earthflux_input_error", call = call)
  }
  check_flag_list(x$flags, "flags", call = call)
  structure(x, class = c(class, "list"))
}
