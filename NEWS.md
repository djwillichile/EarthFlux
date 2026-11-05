# EarthFlux 0.1.0.9000 (development version)

## Documentation

* `citation("EarthFlux")` and `CITATION.cff` give the Zenodo DOI of the
  package (concept DOI 10.5281/zenodo.23981325, which resolves to the
  latest release; 0.1.0 is 10.5281/zenodo.23981326), and the README shows
  how to cite it.

* The maps of the README and of the *Example scene: Cauquenes* article are
  shown in geographic coordinates (EPSG:4326); the computations stay on the
  native MODIS grid.

# EarthFlux 0.1.0

First release of EarthFlux. It is **experimental and not for operational or
scientific production use**: no result has been validated. It includes the
METRIC core physics as numeric functions, from net radiation to daily
actual evapotranspiration (milestone M2); the meteorological forcing of
that chain, with weather station tables and their quality control, derived
variables and reference evapotranspiration at the stations, and the
regionalization of station variables over the working grid by a
representative station (C1), global regression and inverse distance
weighting (C2) and geographically weighted regression on an internal GWR
core (C3), with exact block prediction, optional parallel execution and
spatial block cross-validation (milestone M3); and the preprocessing of
MODIS products into the surface state of the chain (internal, not exported
yet) with the example dataset `cauquenes_modis`, the MODIS surface state of
the Cauquenes province (Chile) on 15 February 2019 (milestone M4). The
integrated `earthflux()` workflow, its presets, the automatic download of
MODIS products, elevation model and weather forcing, and any validation
results are not part of this release.

Verified against the primary sources (`VERIFICADA`): the reference
evapotranspiration of FAO-56 (worked examples 18 and 19 reproduced) and of
the ASCE-EWRI (2005) standardized equation (equations and constants checked
against the 2005 Task Committee report; its worked examples are not
reproduced yet), the unit conversions and the MODIS product facts, each
with its citation to the official user guide or file specification. Most
METRIC formulations are verified against the SEBAL Idaho manual of the
METRIC authors (Waters et al., 2002), the direct predecessor of METRIC,
with page and equation (`VERIFICADA (SEBAL-Idaho 2002)`; see the next
section); the cross-check with Allen, Tasumi & Trezza (2007) remains
desirable. The formulations not covered by that manual stay candidates
(`CANDIDATA`). The key open items are the temperature used in the incoming
longwave radiation (left to the caller of `ef_rl_in()`; the manual uses
the cold-pixel surface temperature), the terrain projection of the
incoming shortwave radiation, and the emissivity of non-vegetated pixels,
derived from a LAI assigned with the option `lai_nonveg` of the surface
state.

## Verification against the SEBAL Idaho manual

* The METRIC formulations were checked one by one against Waters et al.
  (2002), *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
  implementation. Advanced training and users manual* (version 1.0), and
  the Perrier roughness against Allen et al. (2012, IAHS Publ. 352,
  pp. 73-75). Roxygen, provenance status strings and constants cite the
  page and equation of each verified form (`VERIFICADA (SEBAL-Idaho 2002)`
  or `VERIFICADA (IAHS 2012)`).

* Decision SH-11 is resolved: the stable momentum correction of the
  blending height is psi_m(200 m) = -5 (2 / L) (Eq. 38), so
  `ef_h_control()` now defaults `stable_psi_m_height` to 2 m; 200 m can
  still be chosen explicitly. The blending height and the heights of the
  aerodynamic resistance are now defaults (200 m, 0.1 m and 2 m) of
  `ef_h_control()`, `ef_blending_wind()`, `ef_ustar()` and `ef_rah()`, and
  `ef_sensible_heat()` defaults `cp` to 1004 J kg-1 K-1.

* The Monin-Obukhov length of `ef_calibrate_h()` now uses the surface
  temperature and g = 9.81 m s-2, as written in the manual (Eq. 34); it
  used the near-surface air temperature Ts - dT and g = 9.807. The
  calibrated coefficients of the synthetic test scene change by less than
  0.5 %.

* Promoted to `VERIFICADA (SEBAL-Idaho 2002)`: net radiation; the
  elevation shortwave transmissivity, the atmospheric emissivity, the
  incoming shortwave radiation on flat terrain and the incoming and
  emitted longwave radiation; G of Bastiaanssen; the LAI and NDVI/albedo
  roughness, the blending-height wind, the friction velocity, the
  aerodynamic resistance, the stability corrections and the Monin-Obukhov
  length; c_p, g and the von Karman constant; H, dT and the datum surface
  temperature; the forms of the anchor boundary conditions; LE,
  instantaneous ET, ETrF and daily ETa; and the LAI emissivity of the
  MODIS surface state. The Perrier roughness is `VERIFICADA (IAHS 2012)`.

* Still `CANDIDATA`: the partitioned shortwave transmissivity, the
  terrain projection of the incoming shortwave radiation, the incidence
  angle on a tilted plane (the manual prints an apparent misprint), G of
  Tasumi, the use of the FAO-56 air density in METRIC, the anchor
  selection criteria and `ef_lambda(method = "metric")`. The register,
  with every discrepancy, is `dev/VERIFICATION.md` in the source
  repository.

## New features

### METRIC core chain

* `ef_net_radiation()` computes the instantaneous net radiation at the land
  surface from incoming shortwave radiation, albedo, incoming longwave
  radiation, emitted longwave radiation and surface emissivity (METRIC
  surface radiation balance), keeping the reflected incoming longwave term
  explicit. Inputs are validated (type, recycling and physical domain, with
  classed errors) and missing values propagate. The form of the equation is
  verified against the SEBAL Idaho manual (Waters et al., 2002, Eq. 2).

* Radiation components that produce the inputs of `ef_net_radiation()`
  (verification status in the section above; unverified choices are
  explicit arguments without defaults):
  * `ef_solar_geometry()` returns, per pixel and overpass instant (numeric
    `doy` of the UTC date and `utc_hour`, angles in radians), the cosines of
    the solar zenith angle and of the incidence angle on the tilted pixel
    plane (GIS aspect), the declination, the hour angle and the inverse
    relative Earth-Sun distance. The calendar terms and the hour angle are
    verified against FAO-56; the equation of time is applied exactly once.
  * `ef_tau_sw()` (with an explicit `method`) dispatches to
    `ef_tau_sw_allen()`, the clear-sky shortwave transmissivity split into
    direct-beam and diffuse parts (function of zenith angle, pressure,
    vapour pressure and an explicit turbidity), and `ef_tau_sw_elevation()`,
    the simple elevation form.
  * `ef_atm_emissivity()` computes the effective atmospheric emissivity
    from the clear-sky transmissivity.
  * `ef_rs_in()` (with an explicit `method`) dispatches to
    `ef_rs_in_modelled()` (clear-sky) and `ef_rs_in_measured()` (measured
    radiation with a given diffuse fraction); both project the direct-beam,
    diffuse and ground-reflected components onto the pixel plane.
  * `ef_rl_in()` computes the incoming longwave radiation from an effective
    atmospheric emissivity and a temperature whose choice (air, cold-pixel
    or pixel surface temperature) is left to the caller, and `ef_rl_out()`
    the longwave radiation emitted by the surface.

* `ef_air_pressure()` computes the mean atmospheric pressure from elevation
  (FAO-56 Eq. 7), shared by the radiation, sensible heat and reference
  evapotranspiration modules.

* `ef_g()` estimates the instantaneous soil heat flux with an explicit
  `method` and no default, returning G, the ratio G/Rn and the branch
  applied. The methods are also available as `ef_g_bastiaanssen()` (SEBAL,
  function of surface temperature, albedo and NDVI) and `ef_g_tasumi()`
  (METRIC, function of LAI, with a bare-soil branch for LAI < 0.5). The
  Bastiaanssen formulation is verified against the SEBAL Idaho manual
  (Eq. 24); the Tasumi formulation is a candidate. Impossible inputs raise
  classed errors; values of G are never truncated.

* Anchor pixels of the METRIC calibration (stage [A], selection):
  `ef_select_anchors()` selects the cold and hot anchor pixels from
  numeric vectors or matrices of surface temperature, NDVI, albedo and,
  optionally, LAI and land cover, following explicit criteria built with
  `ef_anchor_criteria()`, `ef_anchor_rule()`, `ef_homogeneity()` and
  `ef_anchor_pick()`. There are no default thresholds and nothing is
  relaxed without an explicit plan. The result (class `earthflux_anchors`)
  records the anchor pixels and their attributes, exactly one calibration
  point per class with an explicit `aggregate`, the dispersion of the
  anchor values, the computed thresholds, the funnel of candidates, the
  search domain used, flags and provenance. `ef_anchors()` builds the same
  object from cells or coordinates chosen by the user. Missing candidates,
  an empty percentile domain, inverted anchors, anchors outside the grid
  and missing temperatures raise classed errors. No selection criterion is
  verified against a primary source (`CANDIDATA`).

* `ef_anchor_conditions()` adds the boundary conditions at the anchor pixels
  (stage [B]): target latent heat flux from an explicit cold-anchor reference
  ET fraction and an explicit hot-anchor condition (`etrf_hot` or `le_hot`),
  with the instantaneous reference ET and the latent heat of vaporization
  evaluated at each anchor pixel, and the target sensible heat flux
  H = Rn - G - LE consumed by the sensible heat calibration. The latent heat
  is obtained with the same conversion as `ef_et_inst()`. Optional
  roughness length, blending-height wind speed and pressure are passed
  through to the calibration points, which then hold every input of the
  sensible heat calibration. The forms are verified against the SEBAL
  Idaho manual; no coefficient has a default.

* Aerodynamics of the METRIC sensible heat flux: `ef_zom()` dispatches, with
  an explicit `method` and no default, to the momentum roughness length
  methods `ef_zom_lai()`, `ef_zom_ndvi()`, `ef_zom_perrier()` and
  `ef_zom_height()`; `ef_blending_wind()` extrapolates the station wind to
  the blending height; `ef_ustar()` and `ef_rah()` compute the friction
  velocity and the aerodynamic resistance to heat transport, with optional
  stability corrections. No minimum roughness, terrain factor or wind floor
  is applied. The forms are verified against the SEBAL Idaho manual
  (Perrier: Allen et al., 2012); the heights default to the values of the
  manual and the station roughness has no default.

* `ef_air_density()` (FAO-56 form, temperature in K), `ef_ts_datum()`
  (surface temperature referred to an elevation datum), `ef_dt_coef()`
  (coefficients of dT = a + b Ts_datum from the hot and cold anchors) and
  `ef_sensible_heat()` (H = rho cp dT / rah).

* `ef_calibrate_h()` calibrates dT from one calibration point per anchor
  class, iterating the aerodynamic resistance with the Monin-Obukhov
  stability correction at the anchors (phase A, with a closure so that the
  anchors reproduce their target H exactly) and, optionally, per pixel with
  the calibrated coefficients (phase B, invariant to splitting the scene
  into blocks). It returns an `earthflux_h_calibration` object with the
  coefficients, the convergence trace, the anchor state, the pixel results,
  diagnostic flags and provenance. Non-convergence returns the last iterate
  with an `earthflux_convergence_warning` and the critical flag
  `EF_H_CALIBRATION_NOT_CONVERGED`; invalid anchor states raise
  `earthflux_calibration_error`. `ef_h_control()` sets the heights, the
  height of the stable momentum correction `stable_psi_m_height` (default
  2 m, decision SH-11; with a stable cold anchor 200 m makes the
  calibration diverge) and the convergence settings (`tol = 0.01`,
  `maxit = 20`, `damping = 0`).

* `ef_lambda()` returns the latent heat of vaporization in J kg-1 with an
  explicit `method` and no default: the FAO-56 constant (`"constant"`) or
  the FAO-56 function of the air temperature in K (`"fao56"`). The same
  function is meant to be used throughout the METRIC chain.

* `ef_latent_heat()` computes the instantaneous latent heat flux as the
  residual of the surface energy balance, LE = Rn - G - H (FAO-56, chapter
  1, Eq. 1). Negative values are returned unchanged, never set to zero.

* `ef_et_inst()` converts the latent heat flux (W m-2) into instantaneous
  evapotranspiration (mm h-1) with the latent heat of vaporization from
  `ef_lambda()` and the density of water, writing the factor 1000 mm m-1
  explicitly. A unit guard rejects `lambda` outside [1e6, 1e7] J kg-1 (for
  example a value given in MJ kg-1).

* `ef_etrf()` computes the reference evapotranspiration fraction
  ET_inst / ETr_inst, and `ef_et_daily()` extrapolates it to daily actual
  evapotranspiration with an explicit `method` and no default; the only
  method is `"etrf"` (`ef_et_daily_etrf()`, ETa_24 = ETrF * ETr_24). Both
  require the reference crop (`"alfalfa"` or `"grass"`) explicitly. A
  non-positive instantaneous reference ET or a negative daily reference ET
  is a classed domain error. These formulations are verified against the
  SEBAL Idaho manual (Eqs. 43-44).

### Dispatchers, flags and provenance

* Every dispatcher of a method family (`ef_tau_sw()`, `ef_rs_in()`,
  `ef_g()`, `ef_zom()`, `ef_et_daily()`) takes `method` as its last
  argument, with no default, and returns a classed list with the values of
  the method (`$total`, `$g`, `$zom`, `$eta_24`, ...), `method`, diagnostic
  `flags` and `provenance` (including the flag codes evaluated); the method
  functions (`ef_tau_sw_allen()`, `ef_g_tasumi()`, ...) return plain
  numeric values. The classes are `earthflux_sw_transmissivity` (always
  with `total`, and with `beam` and `diffuse` set to `NULL` when the method
  gives no partition), `earthflux_incoming_shortwave`,
  `earthflux_soil_heat_flux`, `earthflux_roughness_length` and
  `earthflux_daily_et`. A required input that is missing at a position is
  flagged `EF_INPUT_NA`.

* Results carry a flag record only for the conditions that hold somewhere;
  the codes that were evaluated are listed in `provenance$flags_evaluated`,
  so that "evaluated and absent" is distinguishable from "not evaluated".

* Diagnostic flags registered for the METRIC stages (values are never
  truncated or corrected):
  * radiation: `EF_RAD_SELF_SHADED`, `EF_RAD_ATM_EMISSIVITY_GT1`,
    `EF_RAD_RS_GT_RA` and `EF_RAD_RN_NEGATIVE`;
  * soil heat flux: `EF_G_RN_NONPOSITIVE`, `EF_G_RATIO_NEGATIVE`,
    `EF_G_AVAILABLE_NONPOSITIVE` and `EF_G_LOW_LAI_BRANCH`;
  * anchor pixels: `EF_ANCHOR_USER_SUPPLIED`, `EF_ANCHOR_CRITERIA_RELAXED`,
    `EF_ANCHOR_SEARCH_EXPANDED`, `EF_ANCHOR_HOMOGENEITY_DROPPED`,
    `EF_ANCHOR_WINDOW_INCOMPLETE`, `EF_ANCHOR_TIES`,
    `EF_ANCHOR_SINGLE_PIXEL`, `EF_ANCHOR_COLD_H_NEGATIVE`,
    `EF_ANCHOR_HOT_LE_ASSUMED_ZERO` and `EF_ANCHOR_OVERPASS_SPREAD`; flags
    evaluated upstream in an anchor cell are inherited, not duplicated;
  * sensible heat flux: `EF_H_USTAR_INVALID`, `EF_H_PIXEL_NOT_CONVERGED`,
    `EF_H_DT_EXTRAPOLATED_HOT`, `EF_H_DT_EXTRAPOLATED_COLD`,
    `EF_H_NEGATIVE`, `EF_H_GT_AVAILABLE` (cell) and
    `EF_H_CALIBRATION_NOT_CONVERGED`, `EF_H_DT_SLOPE_NONPOSITIVE` (object,
    critical);
  * evapotranspiration: `EF_ET_NEGATIVE`, evaluated on each ET layer.

### Meteorological forcing

* `ef_station_table()` builds the standard table of weather station data:
  station metadata and observations as two plain data frames joined by
  `station_id`, with timestamps stored in UTC (character timestamps need
  an explicit format and time zone), air temperature in degrees Celsius,
  the other variables in the units of the contract, coordinates in WGS84
  (`"EPSG:4326"`) and mandatory period semantics (`timestamp_convention`,
  `interval`) in the provenance. Unit conversions are applied only when
  declared and are recorded; exact duplicated records are kept once and
  conflicting ones are an error. Invalid metadata raise classed errors
  (`earthflux_station_field_error`, `earthflux_station_time_error`,
  `earthflux_station_unknown_id`, `earthflux_station_duplicate`,
  `earthflux_station_provenance_error`, all subclasses of
  `earthflux_input_error`, and `earthflux_domain_error`).

* `ef_station_qc()` runs the quality control of the station table and
  never modifies the observations: it returns the long audit table `$qc`,
  equivalent record-scope flag records, the status of each value
  (`ok`, `warning`, `excluded`) under an explicit `qc_policy` (default
  `"exclude_critical"`) and the counts in the provenance. Registered codes:
  `EF_WS_OUT_OF_DOMAIN` and `EF_WS_TMIN_GT_TMAX` (physical or logical
  impossibilities, severity `critical`), `EF_WS_RH_GT100`,
  `EF_WS_TDEW_GT_TAIR` (dew point above air temperature, or vapour
  pressure above the saturation vapour pressure), `EF_WS_RS_GT_RA` (mean
  solar radiation above the extraterrestrial radiation of the record
  window), `EF_WS_TIME_GAP`, `EF_WS_TIME_IRREGULAR`, `EF_WS_HEIGHT_MISSING`
  and `EF_WS_HEIGHT_NONSTANDARD`. Negative solar radiation and precipitation
  are physical impossibilities. Tests that need a threshold without a
  documented reference (plausible ranges, persistence, steps, ...) are not
  evaluated and are listed as such in the provenance.

* Derived meteorological variables, verified against the FAO-56 equations
  and worked examples (air temperature in degrees Celsius, angles in
  radians, radiation in MJ m-2 per day or per period):
  `ef_psychrometric()` (psychrometric constant), `ef_es()` and
  `ef_es_slope()` (saturation vapour pressure and the slope of its curve),
  the actual vapour pressure from the dew point (`ef_ea_dewpoint()`), from
  hourly temperature and relative humidity (`ef_ea_rh()`), from daily
  extremes with an explicit `method` (`ef_ea_daily()`: `"rhmax_rhmin"`,
  `"rhmax"`, `"rhmean"`, and the ASCE-EWRI (2005) forms `"rhmin"` and
  `"rhmean_tmean"`) and from the minimum temperature with an explicit
  aridity correction (`ef_ea_tmin()`), `ef_dewpoint()`, `ef_wind_2m()`
  (logarithmic profile over short grass), `ef_ra_daily()` and
  `ef_ra_period()` (extraterrestrial radiation per day and per hourly or
  shorter period, reusing the solar geometry of the METRIC core; an
  explicit `standard` selects the FAO-56 midpoint criterion or the
  ASCE-EWRI limits of integration at sunrise and sunset) and
  `ef_rso()` (clear-sky radiation from elevation). Relative humidities
  above 100 % are computed, never truncated.

* Reference evapotranspiration: `ef_ref_net_radiation()` (net radiation of
  the reference surface, daily or hourly, with an explicit `standard` for
  the Stefan-Boltzmann constant and the limits of Rs/Rso; a carried-over
  cloudiness term can be supplied for night-time periods) and
  `ef_ref_soil_heat_flux()` (soil
  heat flux of the reference surface) feed `ef_ref_et()`, which computes the
  grass (ETo) or alfalfa (ETr) reference evapotranspiration with explicit
  `reference`, `timestep` and `standard` and no defaults, and returns an
  `earthflux_reference_et` object with flags and provenance. The FAO-56
  grass equations reproduce FAO-56 examples 18 and 19. The constants of the
  ASCE-EWRI (2005) standardized equation (short and tall reference, daily
  and hourly day and night coefficients, soil heat flux ratios) and the
  rest of its reference ET chain are verified against the January 2005
  Task Committee report (equation, table and page cited in the
  documentation); its worked examples (Appendix C) are not reproduced yet,
  as the appendices were not available. FAO-56 with the alfalfa
  reference is a classed error (`earthflux_undefined_reference`). Negative
  reference ET is kept and flagged.

* Diagnostic flags of the reference ET stage: `EF_WS_RS_RSO_LIMITED` (the
  ratio Rs/Rso is limited to the range of the standard inside the
  cloudiness term, at most 1 for FAO-56 and between 0.3 and 1 for
  ASCE-EWRI; Rs is not modified) and `EF_WS_ETR_NEGATIVE` (negative
  reference ET, kept).

* `ef_station_ref_et()` computes the reference ET series of every station
  of a quality-controlled station table (hourly or daily records), using
  only the values not excluded by the QC policy, and from it the
  instantaneous reference ET at given overpass times (`etr_inst`, mm h-1;
  option `"O1"`, the period that contains the time, or `"O3"`, linear
  interpolation between period mid-points) and the daily reference ET of
  given dates (`etr_24`, mm d-1; sum of the 24 hourly values of complete
  days, or the daily record). The open choices are explicit arguments
  without defaults: humidity source, day definition (UTC or local standard
  time with a UTC offset) and completeness rule, day/night criterion
  (extraterrestrial or net radiation above zero, the latter the ASCE-EWRI
  definition), night-time cloudiness (ratio of the period 2-3 hours before
  sunset, the ASCE-EWRI rule of the last period with a sun angle above
  0.3 rad, or a fixed ratio) and the overpass method. It reproduces FAO-56 examples 18
  and 19 and returns an `earthflux_station_ref_et` object whose flags name
  the table they refer to; days without all their periods
  (`EF_WS_INCOMPLETE_DAY`) and overpass times outside the records
  (`EF_WS_OVERPASS_OUTSIDE_RECORDS`) give `NA` and are flagged.

### Spatial regionalization

* `ef_regionalize()` regionalizes one meteorological station variable over
  the working grid for every target time and returns an `earthflux_surface`:
  the surface (`SpatRaster`, one layer per target time, in memory or in a
  file), an integer flag word per cell and target time with its bit table,
  the fitted model of every target time, the station table (observed and
  fitted values, residuals, leave-one-out residuals, exclusions with their
  reason), flags and provenance. It projects the station coordinates
  (WGS84) to the projected CRS of the grid, extracts the covariates at the
  stations from the same rasters (or takes them from a table), applies an
  explicit QC policy (`use_qc`, no default) and user exclusions, and
  predicts exactly at every cell by blocks of raster rows with `terra`; the
  block size never changes the result. It accepts the regionalization input
  table or the result of `ef_station_qc()`.

* One interface for the configurations compared in the validation plan,
  with no default for any scientific choice: `ef_method_gwr()` (C3: kernel,
  fixed or adaptive bandwidth, either given or selected by AICc or CV for
  every fit), `ef_method_station()` (C1: representative station, optionally
  with an explicit lapse rate for air temperature), `ef_method_ols()` (C2:
  global regression on the same covariates) and `ef_method_idw()` (C2:
  inverse distance weighting with a given power or one selected by
  leave-one-out CV on a grid). `ef_predict_control()` sets the block size,
  the output files and the write options.

* Covariates derived from the surface state (LST, NDVI, ...) must be
  declared in `surface_covariates` (decision GW-07 is open, so there is no
  default) and raise `EF_GWR_SURFACE_COVARIATE`.

* `ef_spatial_folds()` builds deterministic spatial block folds (square
  tiles of a given side) and `ef_regionalize_cv()` returns the long table of
  out-of-fold predictions at the stations for any method, re-selecting the
  GWR bandwidth (or the IDW power) inside each fold by default; failed
  folds are reported, never dropped. The same folds serve C1, C2 and C3.

* Optional parallelism with `future.apply` over target times, raster blocks
  and folds, only when the user has set a `future` plan; EarthFlux never
  sets a plan or changes `terra` options. Results are identical in
  sequential and parallel runs, and the execution plan is recorded in the
  provenance.

* Numeric core of geographically weighted regression (GWR), implemented in
  base R and used by `ef_regionalize()`. It works on plain vectors and
  matrices (response, named covariates and projected coordinates in
  metres) and knows nothing about rasters, so that the orchestrator can
  call it block by block:
  * `ef_gwr_fit()` fits the local weighted least squares models at the
    stations for a fixed (metres) or adaptive (k nearest stations, counting
    the station itself) bandwidth, with an explicit kernel and no default
    (`"gaussian"`, `"exponential"`, `"bisquare"`, `"tricube"`, `"boxcar"`
    with support d <= b). The result (class `earthflux_gwr`) keeps the
    station table (fitted values, residuals, leave-one-out residuals, s_ii,
    local R2, bandwidth, neighbours, condition number, exclusions with their
    reason), local coefficients in original units, tr(S), tr(S'S), AICc,
    CV, the global OLS reference, the conventions applied, flags and
    provenance. Covariates are scaled internally for conditioning;
    coefficients and predictions do not change.
  * `ef_gwr_bandwidth()` selects the bandwidth by AICc or leave-one-out CV
    (explicit criterion, no default) with a recorded search set by
    `ef_gwr_search()` (log grid plus Brent refinement for fixed bandwidths,
    exhaustive search over k), and returns the whole criterion profile
    including the global model. Infeasible bandwidths (rank-deficient local
    designs, too few neighbours, undefined AICc or LOO) are kept in the
    profile and never selected.
  * `ef_gwr_predict()` predicts exactly at new locations (one local fit per
    location); results do not depend on how locations are split into blocks
    or chunks.
  * `ef_gwr_diagnostics()` collects fit statistics, the station table, the
    profile and the flags.
  * AICc uses n stations, sigma = sqrt(RSS/n) and tr(S), the form read in
    Gollini et al. (2015); it reproduces `GWmodel`'s AICc. Coefficients,
    RSS, AICc, CV, leave-one-out residuals and predictions agree with
    `GWmodel` 2.4-1 to 1e-10 in tests that run when it is installed. The
    formulations are candidates pending the primary references.
  * Errors: `earthflux_gwr_insufficient_stations` (fewer than p + 3
    stations), `earthflux_gwr_no_feasible_bandwidth` (with the profile) and
    `earthflux_gwr_singular_error` (rank-deficient design at a station),
    all inheriting `earthflux_gwr_error`. Stations with missing values are
    excluded with their reason, never silently.

* Diagnostic flags registered for the GWR stage, in the flag word of every
  surface (cell) or in the flag records (object, record):
  `EF_GWR_EXTRAPOLATION_COVARIATE`, `EF_GWR_EXTRAPOLATION_LOCAL`,
  `EF_GWR_OUTSIDE_HULL`, `EF_GWR_FEW_NEIGHBOURS`, `EF_GWR_LOCAL_SINGULAR`
  (cell, bits 1-5), `EF_GWR_OUT_OF_DOMAIN` (cell, bit 6, critical: a
  prediction outside the physical domain of the variable is kept and
  flagged, never truncated, and must be masked before the METRIC core),
  `EF_GWR_BW_AT_BOUND`, `EF_GWR_BW_MULTIMODAL`, `EF_GWR_AICC_UNDEFINED`,
  `EF_GWR_GLOBAL_PREFERRED`, `EF_GWR_SURFACE_COVARIATE`,
  `EF_GWR_SINGLE_STATION` (object) and `EF_GWR_STATION_EXCLUDED` (record).

### Surface state (MODIS)

* MODIS surface state (internal, not exported yet): from the files of one
  scene (one tile and one LST date), an area of interest and explicit
  options, EarthFlux assembles on the working grid (the native 1 km
  sinusoidal grid of the LST) the variables that the METRIC core consumes:
  land surface temperature (K), broadband albedo, NDVI, LAI (m2 m-2),
  broadband surface emissivity and the overpass instant (UTC day of year
  and hour, and the instant as POSIXct), with one integer flag word per
  layer, flag records and provenance (granules, products, collection,
  DOIs, methods, product table rows and software versions). Every
  scientific choice is an explicit option without default: LST product
  (MOD11A1 or MYD11A1), albedo method and diffuse fraction, emissivity
  method, NDVI source, temporal matching of the composites, aggregation
  method and minimum valid fraction of the 500 m layers, and QA policy.
  The cells that the METRIC core must not receive (albedo above 1) are
  identified from the flag words so that the orchestration can exclude
  and count them before the soil heat flux and the net radiation.

* Explicit LAI for the non-vegetated MCD15A2H classes (codes 249-254:
  unclassified, urban, wetland, snow and ice, barren, water): by default
  their LAI stays `NA`, so the LAI-based emissivity (and the net radiation
  and soil heat flux downstream) is `NA` there; the new option
  `lai_nonveg` of the surface state assigns a declared LAI instead, one
  value for all six classes or one per class code. The assigned value is a
  candidate (practice of METRIC implementations), is recorded in the
  provenance and is never applied silently: the assigned cells are flagged
  in the LAI and emissivity layers, and QA conditions masked by the user
  still win.

* The MOD11A1/MYD11A1 band 31 and band 32 emissivities are read with the
  LST and carried in the surface state, with their own flag words, in
  preparation for a broadband emissivity from the LST product's
  emissivities; that method (split-window regression) is still not
  implemented, pending its primary reference and coefficients.

* Internal MODIS product table: one table holds the scale, offset and its
  convention, valid range, fill value, data type, HDF-EOS grid and QA
  layout of every supported layer of MOD11A1/MYD11A1, MOD21A1D/MYD21A1D,
  MOD09GA, MOD09GQ, MOD13Q1, MOD13A2, MCD43A3, MCD43A2 (snow), MCD15A2H
  and MCD12Q1, collection 6.1, each row with its citation to the official
  user guide or file specification, plus the data set DOI of each product.
  Layers whose facts are not verified are refused with a classed error
  (`earthflux_modis_unsupported`).

* Internal readers for local files only (no downloads, no credentials):
  raw digital numbers of official HDF4/HDF-EOS files through `terra`/GDAL,
  matched to the layer names of the table, never scaled by GDAL, with the
  sinusoidal geometry of the tile, the file's scale and its NoData checked
  against the table; converted rasters (e.g. GeoTIFF) only with an explicit
  declaration of their product, date and whether their values are already
  scaled; MODIS file name parsing (product, UTC date, tile, collection);
  cropping to an area of interest in the native sinusoidal grid; and
  mosaics of adjacent tiles.

* Scaling of digital numbers into physical values from the table (LST in
  K, emissivity, view angle, NDVI, albedo, LAI, reflectance), with fill
  values and values outside the valid range set to `NA` and returned as
  masks, and decoding of the QA bit fields and QA codes of every supported
  product (bit 0 least significant, exact for 32-bit QA).

* QA policy as an explicit argument without default (`"flag"` or
  `"mask"`): values are set to `NA` only for the documented causes (fill,
  out of range, not produced because of clouds or other reasons,
  non-vegetated LAI classes); `"mask"` additionally masks the conditions
  listed by the user, keeps their flags and counts them.

* Preparation steps: conversion of the MOD11A1/MYD11A1 day view time (local
  mean solar time) to UTC day of year and hour per pixel, with the
  equation of time left to the solar geometry so that it is applied
  exactly once; blue-, white- and black-sky albedo from MCD43A3 with an
  explicit diffuse fraction; broadband emissivity from LAI; NDVI from
  surface reflectance; matching of 8- and 16-day composites to the LST date
  with the lag in days; and integer-factor aggregation to the working grid
  with an explicit minimum valid fraction, the QA conditions of the
  sub-cells carried to the aggregated cell. Options of the specification
  whose formulas or product facts are not verified (e.g. albedo at the
  overpass time, emissivity from the band 31/32 emissivities, LST from
  MOD21A1D, NDVI from MOD13Q1 or daily reflectance) raise
  `earthflux_method_not_implemented`.

* Diagnostic flags registered for the surface stage (cell scope, bits 1-15
  of the surface flag word): `EF_SURF_FILL`, `EF_SURF_CLOUD`,
  `EF_SURF_NOT_PRODUCED`, `EF_SURF_DN_OUT_OF_RANGE`, `EF_SURF_LAI_NONVEG`
  (causes of `NA`), `EF_SURF_QA_OTHER`, `EF_SURF_CLOUD_ADJACENT`,
  `EF_SURF_SNOW`, `EF_SURF_WATER`, `EF_SURF_SALT_PAN`, `EF_SURF_LAI_BACKUP`,
  `EF_SURF_ALBEDO_MAGNITUDE` (values kept), `EF_SURF_OVERPASS_MISSING`
  (view time missing where the LST is valid; the solar geometry of the
  cell is `NA` downstream), `EF_SURF_ALBEDO_GT1` (broadband albedo
  above 1, kept with severity `critical` and excluded before the METRIC
  core, which rejects it with `earthflux_domain_error`) and
  `EF_SURF_LAI_ASSIGNED` (the LAI of a non-vegetated class was assigned by
  the option `lai_nonveg`, not retrieved; informative). `EF_SURF_LAI_NONVEG`
  keeps its meaning (LAI is `NA`) and is not raised where a value was
  assigned.

* Example area of interest: the official boundary of the Cauquenes
  province (Maule Region, Chile; DPA 2023, SUBDERE, published through IDE
  Chile; circulation authorised by DIFROL Resolution No 87 of 2023), taken
  from the author's package thermify, is shipped in `inst/extdata` with its
  provenance. A reproducible script (`data-raw/modis-example.R`, not part
  of the package) builds the example MODIS scene over it from NASA CMR and
  LP DAAC with an Earthdata token read from the environment, for 15
  February 2019 (Terra) with LAI 0 assigned to the non-vegetated classes;
  the scene is shipped as the dataset `cauquenes_modis` (below).

* `cauquenes_modis`: MODIS example scene of the Cauquenes province for 15
  February 2019 (collection 6.1, tile h12v12), one packed `terra` raster
  (58 KB) with LST, albedo, NDVI, LAI, emissivity, the band 31/32
  emissivities, the overpass instant, the NDVI composite lag, the valid
  fractions of the aggregated inputs and the flag words of every layer,
  masked to the province. Built from the official granules with
  `data-raw/modis-example.R`; granules, CMR identifiers, DOIs, options and
  software versions are documented in `?cauquenes_modis`.

* The HDF4 reader was checked against the official granules of the example
  scene and corrected where the files differ from the documentation: the
  `_FillValue` 0 that MOD11A1 files declare for `QC_Day` (a valid bit
  pattern, the best-quality code) no longer stops the reading and those
  cells keep their DN; the HDF-EOS grid of MCD43A3 is `MOD_Grid_BRDF`; SDS
  names that GDAL quotes (MOD13: `"1 km 16 days NDVI"`) are matched; the
  reciprocal scale factor declared by MOD13 files (10000) is accepted, as
  the declared scale is never applied; and the 1 km and 500 m grids of a
  tile, whose edges differ by floating point rounding in the files, are
  cropped and nested with a tolerance of 1e-3 cell.

## Changes

* Modular source layout for the surface, forcing, spatial (GWR), METRIC,
  diagnostics, validation and API modules.

* Internal infrastructure for classed conditions and diagnostic flags:
  results are flagged, never silently corrected.

* Physical constants (Kelvin offset, Stefan-Boltzmann constant, solar
  constant, von Karman constant, gravity, specific heat of air, density of
  water and the FAO-56 latent heat of vaporization) and the unit factors of
  the ET conversion are defined once, with their unit, source and
  verification status.

* The registry of diagnostic flags is assembled from one table per stage
  (METRIC, station forcing, reference ET, regionalization and surface) and
  records, for each code, its stage, severity (now including `critical`),
  scope, bit, error counterpart, specification and version. Flag records
  also carry their stage and scope, and the table or layer they refer to
  (`target`) when an object holds several. The registry is built and validated once
  per session instead of at every flag record, which makes the
  regionalization with small blocks about ten times faster.

* Classed conditions can carry optional data fields (for example the
  diagnostics of a failed calibration); new condition classes for
  calibration errors and convergence warnings.

* EarthFlux imports the base package stats (sample quantiles, medians and
  standard deviations of the anchor selection).

* An end-to-end test runs a synthetic scene through the whole METRIC core
  chain, from solar geometry to daily actual evapotranspiration; a second
  one runs synthetic stations through the quality control, the
  regionalization of air temperature and vapour pressure (converted to
  kelvin at the METRIC boundary) and the station reference ET into the
  METRIC core; and a third one runs tiny synthetic MODIS files through the
  surface state into the solar geometry at the overpass, the emitted
  longwave radiation, the net radiation and the soil heat flux, checking
  that the equation of time is applied exactly once.

* `GWmodel` is suggested (not imported) as the cross-verification reference
  of the GWR core tests, which are skipped when it is not installed.

* EarthFlux imports `terra` (raster input and output of the regionalization)
  and `future` and `future.apply` (optional parallel execution under the
  user's plan, and its record in the provenance).

## Documentation

* README with the status of 0.1.0 (what is included, what is not, and the
  verification status), an executable example on the packaged scene
  (`cauquenes_modis`: layers, units and a map of the emitted longwave
  radiation from `ef_rl_out()`) and the executable `ef_net_radiation()`
  example; the package title is read from `DESCRIPTION`.

* Package help (`?EarthFlux`), introductory vignette and the *Design and
  development status* article updated to the contents of 0.1.0.

* New website article *Example scene: Cauquenes* (not part of the package
  tarball): maps of the surface state, how to read the flag words, the
  provenance of the scene and what is not in 0.1.0.

* pkgdown site at <https://djwillichile.github.io/EarthFlux/>, rebuilt on
  every change to `main`.

* Continuous integration: `R CMD check` on Linux (release, devel, oldrel),
  Windows and macOS; a check that the roxygen2 documentation and
  `README.md` are up to date; repository settings synchronised from
  `DESCRIPTION`; GitHub releases built from the version tag with the
  `NEWS.md` section as notes.

* Zenodo metadata (`.zenodo.json`, excluded from the package build) for
  archiving the GitHub releases.
