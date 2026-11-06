# High-level API: presets of earthflux() ---------------------------------------
#
# Purpose: named, documented and versioned sets of every scientific option of
#   the workflow run by earthflux() (decision M5-04, dev/DECISIONS.md section
#   1.5; dev/ARCHITECTURE.md section 6.7; dev/specs/presets.md). A preset is
#   a specification object (a classed list without `flags`, built with
#   structure()): it records choices, it computes nothing.
#
# Rules (M5-04 and M5-08, which rewrites D-AP-01):
#   - earthflux() requires a preset (no default) and checks the name with
#     check_method() against workflow_preset_names();
#   - a preset is VERIFICADA only if every formulation and option is; the
#     status is declared in the documentation and in the provenance, not in
#     the name, and earthflux() warns once (class
#     earthflux_unverified_preset_warning) with the unverified elements;
#   - every effective option is recorded in the provenance of the result;
#   - presets are versioned internally (`version`); a change of any value is
#     a new version, recorded in NEWS.md and in dev/specs/presets.md.
#
# Contents:
#   ef_presets()                 exported: table of the registered presets
#   ef_preset()                  exported: the full option list of a preset
#   workflow_preset_names()      names accepted by earthflux()
#   workflow_preset_idaho2002()  builder of the two idaho2002 presets
#   workflow_anchor_criteria()   anchor criteria of dev/specs/presets.md 4

#' Names of the registered presets
#'
#' @return Character vector.
#' @noRd
workflow_preset_names <- function() {
  c("idaho2002_elev", "idaho2002_flat")
}

#' Anchor selection criteria of the idaho2002 presets
#'
#' Criteria of dev/specs/presets.md section 4 (decision M5-10, `CANDIDATA`):
#' the guides of Waters et al. (2002), appendix 7 (cold: albedo 0.22-0.24,
#' LAI 4-6, full cover with LAI > 3; hot: LAI 0-0.4), widened for mixed
#' 1 km pixels without a source (T-18).
#'
#' @param cold_lai Numeric. Minimum LAI of the cold candidates (3 in the
#'   criteria, 2 in the relaxation step).
#' @return An `ef_anchor_criteria()` object.
#' @noRd
workflow_anchor_criteria <- function(cold_lai = 3) {
  ef_anchor_criteria(
    cold = list(
      ef_anchor_rule("lai", ">=", cold_lai, scale = "absolute"),
      ef_anchor_rule("albedo", "between", c(0.18, 0.25), scale = "absolute"),
      ef_anchor_rule("ndvi", ">=", 0.90, scale = "percentile")
    ),
    hot = list(
      ef_anchor_rule("lai", "<=", 0.4, scale = "absolute"),
      ef_anchor_rule("ndvi", ">", 0, scale = "absolute"),
      ef_anchor_rule("albedo", "between", c(0.10, 0.35), scale = "absolute")
    ),
    homogeneity = ef_homogeneity("lst", window = 3, stat = "sd", max = 1.5,
                                 window_na = "exclude"),
    select = list(cold = ef_anchor_pick("lst", "lowest_fraction", 0.2),
                  hot = ef_anchor_pick("lst", "highest_fraction", 0.2)),
    percentile_domain = "land",
    quantile_type = 7,
    source = paste0(
      "EarthFlux preset idaho2002 v1 (dev/specs/presets.md 4; DECISIONS.md ",
      "M5-10): guides of Waters et al. (2002), appendix 7, widened for 1 km ",
      "MODIS pixels without a source"
    ),
    status = "CANDIDATA"
  )
}

#' Build an idaho2002 preset
#'
#' @param terrain `"elev"` (elevation adjustments of appendix 12 of the
#'   manual) or `"flat"` (base procedure of the manual).
#' @return An object of class `earthflux_preset`.
#' @noRd
workflow_preset_idaho2002 <- function(terrain) {
  elev <- identical(terrain, "elev")
  name <- paste0("idaho2002_", terrain)
  lapse <- if (elev) 0.0065 else 0
  unverified <- c(
    anchor_criteria = paste0(
      "anchor selection criteria (thresholds, widening for 1 km pixels, ",
      "relaxation step, strict QA of the anchors): CANDIDATA (VERIFICATION ",
      "row 42; M5-10)"
    ),
    modis_albedo = paste0(
      "MODIS broadband white-sky albedo as the albedo of the energy balance ",
      "and the view-time conversion of the overpass: CANDIDATA (MP-03, ",
      "modis_surface_state())"
    ),
    modis_matching = paste0(
      "temporal matching of the composites, aggregation to 1 km and ",
      "min_valid_fraction = 1: provisional decisions and a threshold ",
      "without source (MP-07, MP-08)"
    ),
    lai_nonveg = paste0(
      "LAI 0 assigned to the non-vegetated MCD15A2H classes: CANDIDATA ",
      "(MP-06, M4-28)"
    ),
    reference_et_time = paste0(
      "instantaneous reference ET by linear interpolation between hourly ",
      "mid-points (O3) and the day of the daily sum (mean solar day of the ",
      "AOI centroid): CANDIDATA / open (WF-09, WF-11)"
    ),
    regionalization = paste0(
      "regionalization of the reference ET and of the wind: inverse ",
      "distance weighting CANDIDATA (C2); one station (C1) by definition"
    ),
    era5 = paste0(
      "with weather = \"era5\": gridded forcing (EF_WS_GRIDDED_FORCING), ",
      "treatment of the instantaneous values CANDIDATA, native ERA5 cell ",
      "elevation and exclusion of sea cells (elevation 0 m) as preset ",
      "choices (M5-07, M5-15)"
    ),
    station_roughness = paste0(
      "roughness of the weather site z_om,w = 0.0144 m (0.12 x 0.12 m, Eq. ",
      "28 of the manual over a 0.12 m reference grass): height CANDIDATA ",
      "(SH-04)"
    ),
    zom_floor = paste0(
      "minimum z_om of 0.005 m where 0.018 LAI is below it ",
      "(EF_H_ZOM_FLOOR_APPLIED): value of METRIC implementations without a ",
      "consulted primary source; the SEBAL Idaho manual gives 0.018 LAI only ",
      "for agricultural areas and land-use values in its appendix 2 (water ",
      "0.0005 m, snow 0.005 m) with no bare-soil value: CANDIDATA (SH-02, ",
      "M5-24)"
    ),
    wind_time = paste0(
      "wind at the overpass time by linear interpolation between hourly ",
      "mid-points: design choice (M5-14)"
    ),
    flat_projection = paste0(
      "slope forced to 0 (flat projection) until RC-09 is resolved; ",
      "elevation used"
    )
  )
  structure(
    list(
      name = name,
      version = "1",
      status = "CANDIDATA",
      description = if (elev) {
        paste0(
          "SEBAL-Idaho 2002 forms with the elevation adjustments of ",
          "appendix 12 of the manual (datum surface temperature with a ",
          "lapse rate of 0.0065 K/m, cold-pixel temperature of the incoming ",
          "longwave adjusted by elevation, shortwave transmissivity per ",
          "pixel); flat projection (slope 0)."
        )
      } else {
        paste0(
          "Base procedure of the SEBAL-Idaho 2002 manual for low relief: ",
          "no lapse rate in the datum surface temperature, one cold-pixel ",
          "temperature for the incoming longwave and one shortwave ",
          "transmissivity for the scene; flat projection (slope 0)."
        )
      },
      source = paste0(
        "Waters et al. (2002), SEBAL Idaho manual (pp. 10-38; appendices 7, ",
        "8 and 12); dev/specs/presets.md; dev/DECISIONS.md M5-08 to M5-17"
      ),
      decisions = c("M5-04", "M5-08", "M5-09", "M5-10", "M5-11", "M5-12",
                    "M5-13", "M5-14", "M5-15", "M5-16", "M5-17"),
      modis = list(
        lst_product = "MOD11A1",
        collection = "061",
        surface_options = list(
          lst_product = "MOD11A1",
          albedo_method = "white_sky",
          diffuse_fraction = NULL,
          emissivity_method = "lai_empirical",
          ndvi_source = "MOD13A2",
          composite_method = c(albedo = "same_day",
                               ndvi = "period_pixel_lag", lai = "period"),
          resampling_method = "mean",
          min_valid_fraction = 1,
          qa_policy = "flag",
          mask_codes = NULL,
          lai_nonveg = 0
        )
      ),
      terrain = list(
        dem_method = "flat",
        water = "mask",
        min_valid_fraction = 1,
        slope = 0,
        aspect = 0,
        aoi_mask = "cells touched by the AOI polygon (terra::rasterize, touches = TRUE)"
      ),
      weather = list(
        timestep = "hourly",
        qc_policy = "exclude_critical",
        use_qc = c("ok", "warning"),
        era5 = list(elevation_adjust = FALSE, instant_values = "trapezoid",
                    exclude_sea_cells = TRUE, sea_elevation = 0),
        humidity = c("vapour_pressure", "dewpoint_temperature",
                     "relative_humidity"),
        one_station = "C1: ef_method_station(station_id), no lapse rate",
        several_stations = "C2: ef_method_idw(power = 2)",
        idw_power = 2,
        surface_covariates = character(0),
        variables = c("etr_inst", "etr_24", "wind_speed_2m"),
        hourly_to_overpass = paste0(
          "regionalize the hourly values at the period mid-points that ",
          "bracket the overpass times, then interpolate each cell linearly ",
          "in time to its own overpass time (O3; M5-14)"
        ),
        weather_site_roughness = 0.0144,
        weather_site_displacement = 0
      ),
      reference_et = list(
        reference = "alfalfa",
        timestep = "hourly",
        standard = "asce",
        day_definition = "local_standard",
        utc_offset = "longitude of the AOI centroid / 15 h (mean solar day)",
        day_completeness = "all_periods",
        daytime_rule = "rn_positive",
        night_cloudiness = "low_sun",
        inst_method = "O3"
      ),
      radiation = list(
        tau_method = "elevation",
        tau_elevation = if (elev) "pixel (elevation model)" else
          "scene: elevation of the station (one station) or median elevation of the AOI cells",
        rs_method = "modelled",
        tau_partition = "tau_beam = tau_sw, tau_diffuse = 0 (Eq. 12 on the horizontal)",
        slope = 0,
        rl_in_temperature = "cold_anchor",
        rl_in_lapse_rate = lapse
      ),
      soil_heat = list(method = "bastiaanssen"),
      roughness = list(method = "lai", zom_min = 0.005,
                       zom_min_flag = "EF_H_ZOM_FLOOR_APPLIED",
                       zom_min_status = "CANDIDATA (SH-02, M5-24)"),
      wind = list(zom_station = 0.0144, d_station = 0, height = 2,
                  blending_height = 200),
      lambda = list(method = "constant"),
      anchors = list(
        criteria = workflow_anchor_criteria(3),
        relax = list(workflow_anchor_criteria(2)),
        aggregate = "mean",
        search_radius_m = 30000,
        search_area = paste0(
          "one station: list(30 km around the station, whole AOI); ",
          "otherwise the whole AOI"
        ),
        qa = paste0(
          "strict: no warning or critical bit in flags_lst, flags_albedo, ",
          "flags_ndvi, flags_lai, flags_emissivity, and no ",
          "EF_SURF_LAI_ASSIGNED (LAI set by lai_nonveg, not retrieved); ",
          "valid_fraction == 1; no bit 1, 3 or 6 of the GWR words of the ",
          "forcing; elevation and z_om defined"
        ),
        qa_exclude_codes = "EF_SURF_LAI_ASSIGNED",
        etrf_cold = 1.05,
        etrf_hot = 0,
        conditions_source = "Waters et al. (2002), pp. 30-31 (steps 5a, 5b)",
        conditions_status = "VERIFICADA"
      ),
      sensible_heat = list(
        control = ef_h_control(),
        lapse_rate = lapse,
        datum_elevation = paste0(
          "elevation of the station (one station) or of the cold ",
          "calibration point"
        )
      ),
      et = list(method = "etrf", reference = "alfalfa"),
      unverified = unverified
    ),
    class = "earthflux_preset"
  )
}

#' Registered presets of earthflux()
#'
#' Lists the presets that [earthflux()] accepts: a preset is a named,
#' documented and versioned set of every scientific option of the workflow
#' (decision M5-04). Use [ef_preset()] to see every option of one preset.
#'
#' @return A data frame with one row per preset: `name`, `version`,
#'   `status` (verification status of the preset as a whole: `"VERIFICADA"`
#'   only when every formulation and option is) and `description`.
#'
#' @section Verification status:
#' Both presets are `CANDIDATA` (decision M5-09): their forms are those of
#' the SEBAL Idaho manual (Waters et al., 2002), mostly `VERIFICADA
#' (SEBAL-Idaho 2002)`, but the anchor criteria, the MODIS albedo and the
#' regionalization, among others, are not verified. The unverified elements
#' are listed in `ef_preset(name)$unverified` and in the warning of
#' [earthflux()].
#'
#' @seealso [ef_preset()], [earthflux()].
#' @family workflow functions
#' @export
#'
#' @examples
#' ef_presets()
ef_presets <- function() {
  p <- lapply(workflow_preset_names(), ef_preset)
  data.frame(
    name = vapply(p, `[[`, "", "name"),
    version = vapply(p, `[[`, "", "version"),
    status = vapply(p, `[[`, "", "status"),
    description = vapply(p, `[[`, "", "description"),
    stringsAsFactors = FALSE
  )
}

#' Options of a preset of earthflux()
#'
#' Returns every option that a preset sets, so that the choices made by
#' [earthflux()] can be inspected before (and after) a run; the same list
#' is recorded in the provenance of the result.
#'
#' @param name Character. Name of a registered preset (see [ef_presets()]):
#'   `"idaho2002_elev"` or `"idaho2002_flat"`. No default.
#'
#' @return An object of class `earthflux_preset` (a list): `name`,
#'   `version`, `status`, `description`, `source`, `decisions` and the
#'   option blocks `modis` (product and the options of the MODIS surface
#'   state), `terrain`, `weather` (quality control, ERA5 options,
#'   regionalization), `reference_et`, `radiation`, `soil_heat`,
#'   `roughness`, `wind`, `lambda`, `anchors` (criteria built with
#'   [ef_anchor_criteria()], relaxation plan, aggregation, search area,
#'   anchor QA and boundary conditions), `sensible_heat` (with an
#'   [ef_h_control()] list), `et`, and `unverified` (named character vector
#'   of the elements that are not `VERIFICADA`).
#'
#' @details
#' The two presets (decisions M5-08 to M5-17, dev/specs/presets.md) share
#' every option except the treatment of elevation:
#'
#' | Option | `idaho2002_elev` | `idaho2002_flat` |
#' |---|---|---|
#' | Lapse rate of the datum surface temperature (Eq. 12-7) | 0.0065 K m-1 | 0 |
#' | Temperature of the incoming longwave | cold-anchor Ts adjusted by elevation (Eq. 12-8) | cold-anchor Ts |
#' | Shortwave transmissivity (Eq. 11) | per pixel, from the elevation model | one for the scene |
#'
#' Neither uses the slope (forced to 0, flat projection, until decision
#' RC-09 is resolved); both use the elevation of the elevation model for
#' the air pressure, the anchors and the datum temperature.
#'
#' Common options: MODIS Terra LST (MOD11A1), white-sky albedo, emissivity
#' from LAI, NDVI of MOD13A2, LAI 0 assigned to the non-vegetated classes,
#' QA flagged (strict QA for the anchors), `min_valid_fraction = 1`;
#' NASADEM elevation with water masked; quality control
#' `"exclude_critical"`; ASCE alfalfa reference ET, hourly, with the
#' `"rn_positive"` daytime rule and `"low_sun"` night cloudiness, the
#' instantaneous value interpolated between hourly mid-points (O3) and the
#' daily sum over the mean solar day of the AOI centroid; one station: its
#' values over the whole grid (C1); several stations or ERA5: inverse
#' distance weighting with power 2 (C2); ERA5 with the native cell
#' elevation, trapezoid instantaneous values and the sea cells excluded;
#' anchors selected before the net radiation (incoming longwave from the
#' cold anchor, decision P0-3) with the criteria of
#' dev/specs/presets.md section 4, `etrf_cold = 1.05` and `etrf_hot = 0`;
#' soil heat flux of Bastiaanssen; z_om = 0.018 LAI, undefined where
#' LAI = 0; wind at 200 m from a weather site with z_om,w = 0.0144 m and
#' d = 0; constant latent heat; ETa_24 = ETrF x ETr_24.
#'
#' @section Verification status:
#' `CANDIDATA` (see [ef_presets()]); the unverified elements are in the
#' element `unverified`.
#'
#' @references
#' Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
#' (2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
#' implementation. Advanced training and users manual* (Version 1.0).
#' University of Idaho and Idaho Department of Water Resources.
#'
#' @seealso [ef_presets()], [earthflux()].
#' @family workflow functions
#' @export
#'
#' @examples
#' p <- ef_preset("idaho2002_elev")
#' p
#' p$anchors$criteria
#' names(p$unverified)
ef_preset <- function(name) {
  check_method(name, workflow_preset_names(), arg = "name")
  switch(name,
         idaho2002_elev = workflow_preset_idaho2002("elev"),
         idaho2002_flat = workflow_preset_idaho2002("flat"))
}
