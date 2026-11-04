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
# Every dispatcher of the METRIC core returns one of these objects with its
# value element(s), `method`, `flags` (records only for codes flagged
# somewhere) and `provenance` (including `flags_evaluated`, the codes
# checked); the method functions return plain numeric values or plain lists.
#
# Classes created so far:
#   - earthflux_flag (R/diagnostics.R): one diagnostic flag record (a list,
#     not built with new_ef_object()).
#   - earthflux_sw_transmissivity (R/metric-radiation.R): output of
#     ef_tau_sw() (`total`, `beam`, `diffuse`).
#   - earthflux_incoming_shortwave (R/metric-radiation.R): output of
#     ef_rs_in() (`total`, `beam`, `diffuse`, `reflected`,
#     `diffuse_fraction`).
#   - earthflux_soil_heat_flux (R/metric-soil-heat.R): output of ef_g()
#     (`g`, `g_rn_ratio`, `branch`).
#   - earthflux_anchor_rule, earthflux_homogeneity, earthflux_anchor_pick
#     and earthflux_anchor_criteria (R/metric-anchors.R): specification
#     objects built by ef_anchor_rule(), ef_homogeneity(), ef_anchor_pick()
#     and ef_anchor_criteria() (classed lists without `flags`; they describe
#     a choice of the user, not a result).
#   - earthflux_anchors (R/metric-anchors.R): anchor pixel selection and its
#     audit trail (ef_select_anchors(), ef_anchors()), completed by
#     ef_anchor_conditions().
#   - earthflux_roughness_length (R/metric-aerodynamics.R): output of
#     ef_zom() (`zom`).
#   - earthflux_h_calibration (R/metric-sensible-heat.R): dT calibration of
#     the sensible heat flux (ef_calibrate_h()).
#   - earthflux_daily_et (R/metric-et.R): output of ef_et_daily()
#     (`eta_24`).
# Planned classes (created with their first constructor, not before):
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
