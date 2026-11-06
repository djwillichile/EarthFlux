# S3 classes ----------------------------------------------------------------------
#
# Purpose: lightweight S3 classes for EarthFlux objects.
#
# Convention (dev/ARCHITECTURE.md section 3.2; DECISIONS.md P0-12, T-17;
# harmonised for M2 in DECISIONS.md section 1.2 and kept for M3 and M4 in
# sections 1.3 and 1.4): numeric core functions return plain numeric values;
# only procedures whose result describes a whole object (anchor selection,
# H calibration, station tables, reference ET series, GWR fits,
# regionalized surfaces, the MODIS surface state, dispatchers that record
# method and provenance) return a lightweight classed list built with
# new_ef_object(). Such lists always carry a `flags` element (a list of
# `earthflux_flag`, possibly empty).
#
# Every dispatcher of the METRIC core returns one of these objects with its
# value element(s), `method`, `flags` (records only for codes flagged
# somewhere) and `provenance` (including `flags_evaluated`, the codes
# checked); the method functions return plain numeric values or plain lists.
#
# Specification objects (a choice of the user, not a result) are classed
# lists without `flags`, built with structure() next to their constructor.
#
# Classes created so far (most specific first when an object has two):
#
# Diagnostics
#   - earthflux_flag (R/diagnostics.R): one diagnostic flag record (a list,
#     not built with new_ef_object()); records of ef_station_ref_et() add
#     the field `target` (dev/specs/flags.md section 6.2).
#
# METRIC core (M2)
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
#     and ef_anchor_criteria().
#   - earthflux_anchors (R/metric-anchors.R): anchor pixel selection and its
#     audit trail (ef_select_anchors(), ef_anchors()), completed by
#     ef_anchor_conditions().
#   - earthflux_roughness_length (R/metric-aerodynamics.R): output of
#     ef_zom() (`zom`).
#   - earthflux_h_calibration (R/metric-sensible-heat.R): dT calibration of
#     the sensible heat flux (ef_calibrate_h()).
#   - earthflux_daily_et (R/metric-et.R): output of ef_et_daily()
#     (`eta_24`).
#
# Meteorological forcing (M3)
#   - earthflux_station_table (R/io-weather.R): standard station table of
#     ef_station_table() (`stations`, `observations`, `qc`, `flags`,
#     `provenance`).
#   - c(earthflux_station_qc, earthflux_station_table) (R/prep-qc.R): the
#     table after ef_station_qc() (adds `qc_status` and the audit table
#     `qc`).
#   - earthflux_reference_net_radiation (R/reference-et.R): output of
#     ef_ref_net_radiation() (`rn`, `rns`, `rnl`, `cloudiness`).
#   - earthflux_reference_et (R/reference-et.R): output of ef_ref_et()
#     (`et_ref`, `reference`, `timestep`, `standard`).
#   - earthflux_station_ref_et (R/prep-weather.R): output of
#     ef_station_ref_et() (`series`, `etr_inst`, `etr_24`).
#
# Spatial regionalization (M3)
#   - earthflux_gwr_search (R/gwr-bandwidth.R): specification object of
#     ef_gwr_search() (bandwidth search settings).
#   - earthflux_gwr_bandwidth (R/gwr-bandwidth.R): bandwidth selection of
#     ef_gwr_bandwidth() (selected value, criterion profile, flags).
#   - c(earthflux_gwr, earthflux_regionalization) (R/gwr-fit.R): fitted GWR
#     model of ef_gwr_fit() (station table, local coefficients, AICc, CV,
#     global OLS reference, conventions).
#   - earthflux_ols, earthflux_idw and earthflux_station_forcing
#     (R/regionalize-baselines.R): fitted baselines C2 (global regression,
#     inverse distance weighting) and C1 (representative station), internal
#     constructors used by ef_regionalize().
#   - earthflux_regionalization_method (R/regionalize-methods.R):
#     specification objects of ef_method_gwr(), ef_method_station(),
#     ef_method_ols() and ef_method_idw().
#   - earthflux_predict_control (R/regionalize-methods.R): specification
#     object of ef_predict_control() (blocks, files, write options).
#   - earthflux_surface (R/regionalize.R): output of ef_regionalize()
#     (`surface`, `flag_word`, `flag_bits`, `diagnostics`, `station_table`).
#   - earthflux_regionalization_cv (R/regionalize-cv.R): output of
#     ef_regionalize_cv() (long table of out-of-fold predictions).
#
# Surface state (M4)
#   - earthflux_modis_source (R/modis-surface.R): specification object of
#     modis_source() (one HDF4 file or declared converted files of a
#     product, with UTC date, scaling and composite period).
#   - earthflux_modis_surface_options (R/modis-surface.R): specification
#     object of modis_surface_options() (explicit choices of the assembly).
#   - earthflux_surface_state (R/modis-surface.R): output of
#     modis_surface_state(), the surface contract of dev/ARCHITECTURE.md
#     section 4 (`lst`, `albedo`, `ndvi`, `lai`, `emissivity`,
#     `overpass_time`, `lonlat`, `qa`, `units`, `flags`, `provenance`).
#
# Downloads and workflow (M5)
#   - earthflux_modis_fetch (R/download-modis.R): MODIS granules of a scene
#     (modis_fetch(); files of modis_surface_state() and provenance).
#   - earthflux_terrain (R/dem.R): elevation model on the working grid
#     (dem_terrain(), dem_fetch()).
#   - earthflux_openmeteo_response (R/forcing-openmeteo.R): parsed
#     Open-Meteo response (openmeteo_response()).
#   - earthflux_preset (R/api-presets.R): specification object of
#     ef_preset() (every option of a preset of earthflux(); no `flags`).
#   - earthflux_result (R/api-earthflux.R): output of earthflux() (`layers`,
#     `units`, the objects of each stage, `qa`, `date`, `preset`, `flags`,
#     `provenance`; dev/specs/presets.md section 5).
#
# Avoid premature class hierarchies: one class per object kind, inheriting
# only from "list". The two exceptions above add one parent: a QC result is
# still a station table, and the GWR fit carries the class
# `earthflux_regionalization` of dev/specs/gwr-forcing.md section 7 (no
# method is defined for it yet; the baselines C1/C2 do not carry it).

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
