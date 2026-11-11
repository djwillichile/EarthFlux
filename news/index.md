# Changelog

## EarthFlux 0.1.0.9000 (development version)

### New features

- Automatic search and download of the MODIS granules of the surface
  state (internal, for the coming
  [`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md)):
  the sinusoidal tiles under an area of interest, one NASA CMR granule
  per product, tile and date (MOD11A1/MYD11A1, MCD43A3, MOD13A2,
  MCD15A2H; composite periods from the granule metadata), and the LP
  DAAC download with the NASA Earthdata token read only from
  `EARTHDATA_TOKEN`, into a validated cache
  (`tools::R_user_dir("EarthFlux", "cache")` by default). Areas that
  need more than one tile are not assembled yet.

- Automatic elevation model (internal, for the coming
  [`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md);
  decision M5-06): NASADEM_HGT v001 tiles are found with NASA CMR,
  downloaded from LP DAAC with the Earthdata token of the environment,
  validated and cached, and turned into elevation, slope, aspect, mean
  normal length and valid fraction on the 1 km working grid, either flat
  or with the `CANDIDATA` mean-normal chain (3 arc-second slopes
  averaged as unit normal vectors). Water and missing tiles are never
  filled.

- Station-free weather forcing (decision M5-07, internal for now):
  hourly ERA5 data from the Open-Meteo historical weather API
  (`models=era5`) for the ERA5 cells covering an area of interest plus a
  one-cell buffer, each cell a virtual station of
  [`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md)
  (wind at 10 m, elevation from the API, UTC), so that QC, reference ET
  and regionalization work unchanged. Explicit choices without defaults
  for the elevation adjustment and the treatment of the instantaneous
  values; optional `apikey` for the customer (commercial) API, never
  stored; JSON cache; CC BY 4.0 and Copernicus attribution in the
  provenance. New flag `EF_WS_GRIDDED_FORCING` (warning, object scope).
  Adds `jsonlite` to Imports.

- `earthflux(aoi, date, weather, preset)`, the integrated workflow
  (decisions M5-04 and M5-08 to M5-22): MODIS surface state and NASADEM
  elevation downloaded and prepared on the 1 km MODIS grid, weather from
  a station table (one station: its values everywhere; several: inverse
  distance weighting) or from ERA5 via Open-Meteo, hourly alfalfa
  reference ET and wind regionalized and interpolated to the overpass
  time of each cell, anchors selected before the net radiation (incoming
  longwave from the cold anchor), calibration of dT and daily ETa.
  Returns an `earthflux_result` with every intermediate layer, the
  objects of each stage, flag words per stage, flags and a provenance
  with every effective option
  ([`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html) and
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods). Two
  presets, `idaho2002_elev` and `idaho2002_flat` (SEBAL Idaho manual
  forms with and without its elevation adjustments, both `CANDIDATA`,
  version 1), listed by
  [`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md)
  and shown in full by
  [`ef_preset()`](https://djwillichile.github.io/EarthFlux/reference/ef_preset.md);
  a preset that is not verified raises one
  `earthflux_unverified_preset_warning` listing its unverified elements.
  New flag `EF_H_ZOM_UNDEFINED` (info, cell scope, bit 10 of the H
  word): the momentum roughness length is 0 where LAI is 0 and no
  minimum is applied, so the cell is `NA` from the sensible heat flux
  on. New error class `earthflux_weather_coverage_error`.

- Presets `idaho2002_elev` and `idaho2002_flat` version 2 (decisions
  M5-23 and M5-24; the changes are listed in `ef_preset(name)$changes`
  and in the provenance). Anchor criteria recalibrated for 1 km MODIS
  pixels on the Cauquenes and Maule scenes of 2019-02-15: cold
  candidates with NDVI at or above the 90th percentile and white-sky
  albedo in \[0.14, 0.26\], hot candidates with NDVI at or below the
  10th percentile and albedo in \[0.18, 0.35\] (no absolute LAI
  thresholds), one relaxation step (percentiles 0.80 and 0.20), and no
  anchor on cells whose LAI was assigned by `lai_nonveg`; still
  `CANDIDATA`. The momentum roughness length now has a minimum of 0.005
  m (`CANDIDATA`) where 0.018 LAI is below it, flagged with the new
  `EF_H_ZOM_FLOOR_APPLIED` (info, cell scope, bit 1 of the H word), so
  cells with LAI = 0 get an ETa. `EF_H_ZOM_UNDEFINED` is retired (no
  function raises it any more); its bit 10 stays reserved and the
  registry refuses retired codes and bits.

### Changes

- [`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md)
  has one convergence control per phase of
  [`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md)
  (decision M2-11): `tol` and `maxit` now apply to the calibration at
  the anchors only, with defaults `1e-6` and 100 (were 0.01 and 20), and
  the new `pixel_tol` (default `1e-5`) and `pixel_maxit` (default 100)
  to the per-pixel stability iteration. With the former shared 1 %
  tolerance the anchors stopped short of their fixed point, so the
  anchors run through the pixel phase no longer reproduced their target
  H and every pixel inherited the offset: in a strongly unstable,
  low-wind Landsat scene (the Talca example of the `water` package) H
  was 0.59 W m-2 below the fixed point on average (up to 1.3 W m-2);
  with the new defaults it is within 5e-4 W m-2, at about 1.5 times the
  run time. Pixels that do not converge keep their flag
  `EF_H_PIXEL_NOT_CONVERGED` and now also raise one
  `earthflux_convergence_warning` (field `phase = "pixels"`). The former
  behaviour is
  `ef_h_control(tol = 0.01, maxit = 20, pixel_tol = 0.01, pixel_maxit = 20)`.

- Presets `idaho2002_elev` and `idaho2002_flat` version 3: the
  convergence settings of the calibration of H are written out in the
  preset (`tol = 1e-6`, `maxit = 100`, `pixel_tol = 1e-5`,
  `pixel_maxit = 100`; decision M2-11) and recorded in the provenance
  with every other option. H changes by up to about 1.3 W m-2.

- Presets `idaho2002_elev` and `idaho2002_flat` version 4: a terrain
  rule (decision M5-25, `CANDIDATA`). One linear dT calibrated between
  two anchors with one weather forcing only holds over the elevations of
  the calibration, so cells more than the limit of the preset below or
  above the elevation range of the calibration hold no anchor and are
  `NA` in every layer of the result. The range spans the cold and hot
  anchors of a preliminary anchor selection without the rule and, with
  one station, the station (the datum of the surface temperature and the
  site of the forcing); cells between the anchors are kept, however far
  from each. The limits differ per preset: 500 m for `idaho2002_elev`,
  whose lapse correction leaves an error of about 3.3 K per km in the
  datum surface temperature, and 250 m for `idaho2002_flat`, which has
  no lapse correction (6.5 K per km); both keep that error within the
  1.5 K homogeneity tolerance of the anchors. They are flagged with the
  new `EF_H_TERRAIN_RULE_APPLIED` (info, cell scope, bit 11 of the H
  word; the other words are `NA` there) and counted in the provenance
  (`terrain_rule_excluded`, below and above the range, with the
  reference elevations, the kept range and the final anchors in
  `scene$terrain_rule`). On the Maule scene of 2019-02-15 the elev
  preset loses the Andes above about 800 m (40 % of the computed cells),
  where ETrF was mostly negative, and keeps the hot anchor in valley
  fields; the flat preset loses 46 %. On the Cauquenes scene the elev
  preset is unchanged and the flat preset loses 18 cells above 669 m.
  The excluded cells get no ETa.

### Bug fixes

- The MODIS readers and `modis_provenance()` now work with older and
  newer terra alike.
  [`terra::metags()`](https://rspatial.github.io/terra/reference/metags.html)
  returns a named character vector up to terra 1.8-29 and a data frame
  (with metadata domains) from 1.8-42, and `terra::gdal(lib = "all")`
  returns a named character vector up to 1.9-45 and a data frame from
  1.9-46; both shapes are now handled. With terra 1.7-65 the tag lookup
  failed (“missing value where TRUE/FALSE needed”) and the provenance
  record failed on `$`.

- `DESCRIPTION` now requires `terra (>= 1.7-65)`, the oldest release on
  which the test suite has been run (`metags()` itself exists from
  1.7-55). A new CI job (`min-terra`) runs `R CMD check` with R 4.3 and
  that terra release, so regressions on the minimum are caught.

### Documentation

- [`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md):
  the daily sum of the hourly reference ET is the daily reference ET of
  the METRIC extrapolation verified against the SEBAL Idaho manual
  (Waters et al., 2002, Eq. 44); the documentation said it was still to
  be checked.

- `citation("EarthFlux")` and `CITATION.cff` give the Zenodo DOI of the
  package (concept DOI 10.5281/zenodo.23981325, which resolves to the
  latest release; 0.1.0 is 10.5281/zenodo.23981326), and the README
  shows how to cite it.

- The maps of the README and of the *Example scene: Cauquenes* article
  are shown in geographic coordinates (EPSG:4326); the computations stay
  on the native MODIS grid.

- New website article *Hot and cold anchors and the Monin–Obukhov
  iteration*: why the sensible heat flux is calibrated with anchor
  pixels, how dT = a + b Ts_datum is solved, and the stability iteration
  of
  [`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md)
  written out step by step on the `cauquenes_modis` scene (with an
  illustrative weather station and elevation), checked against the
  function and with convergence, neutral versus stability corrected H
  and per-cell iteration figures.

- Spanish version of that article for university teaching, *Píxeles
  ancla y la iteración de Monin–Obukhov*, with the same code, data and
  verification and the figure labels in Spanish; the two versions link
  to each other.

## EarthFlux 0.1.0

First release of EarthFlux. It is **experimental and not for operational
or scientific production use**: no result has been validated yet, and
interfaces may change. The integrated
[`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md)
workflow, its presets, the automatic download of MODIS products,
elevation models and weather forcing, and validation results are not
part of this release.

### Verification

- Reference evapotranspiration (FAO-56, worked examples 18 and 19
  reproduced; ASCE-EWRI 2005), unit conversions and MODIS product facts
  are `VERIFICADA` against their primary sources.
- Most METRIC formulations are `VERIFICADA (SEBAL-Idaho 2002)`: checked,
  with page and equation, against the SEBAL Idaho manual of the METRIC
  authors (Waters et al., 2002); the Perrier roughness against Allen et
  al. (2012, IAHS Publ. 352). The cross-check with Allen, Tasumi &
  Trezza (2007) remains desirable.
- The stable momentum correction at the blending height is psi_m(200 m)
  = -5 (2 / L) (Eq. 38), so
  [`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md)
  defaults `stable_psi_m_height` to 2 m; the verified heights (200, 0.1
  and 2 m) and c_p = 1004 J kg-1 K-1 are defaults too. The Monin-Obukhov
  length uses the surface temperature and g = 9.81 m s-2 (Eq. 34).
- Still `CANDIDATA`, as explicit arguments without defaults: the
  partitioned shortwave transmissivity, the terrain projection of the
  incoming shortwave radiation, the incidence angle on a tilted plane, G
  of Tasumi, the FAO-56 air density in METRIC, the anchor selection
  criteria and `ef_lambda(method = "metric")`. Open: the temperature of
  the incoming longwave radiation
  ([`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md))
  and the emissivity of non-vegetated pixels (`lai_nonveg`). The
  register is `dev/VERIFICATION.md` in the source repository.

### New features

- **METRIC core.** The chain as numeric functions, from solar geometry
  to daily actual ET: radiation components and
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md),
  soil heat flux
  ([`ef_g()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md)),
  anchor pixels
  ([`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md),
  [`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md),
  [`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md)),
  roughness, wind, friction velocity and aerodynamic resistance
  ([`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md),
  [`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
  [`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md)),
  the dT calibration and sensible heat
  ([`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md),
  [`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md)),
  latent heat and ET
  ([`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md),
  [`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md),
  [`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md),
  [`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md)).
- **Method families.** Each family has a dispatcher with an explicit
  `method` and no default (e.g. `ef_g(method = "bastiaanssen")`),
  returning a classed object with the value, the method, diagnostic
  flags and provenance; the method functions return plain numerics.
- **Meteorological forcing.** Weather station tables
  ([`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md))
  with quality control
  ([`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md)),
  derived variables verified against FAO-56 (vapour pressure, dew point,
  psychrometric constant, wind at 2 m, extraterrestrial and clear-sky
  radiation) and reference ET at the stations
  ([`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md),
  [`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md)).
- **Spatial regionalization.**
  [`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md)
  maps a station variable onto the working grid by a representative
  station, global regression, inverse distance weighting or
  geographically weighted regression on an internal GWR core
  ([`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
  [`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md)),
  with exact block prediction, spatial block cross-validation
  ([`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md),
  [`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md))
  and optional parallel execution under a `future` plan.
- **MODIS surface state** (internal, not exported yet): reading of local
  MODIS files, scaling, QA bits as flags, view time to UTC, broadband
  albedo and emissivity, temporal matching and aggregation to the native
  1 km grid of the land surface temperature.
- **Example data.** `cauquenes_modis`: the MODIS surface state of the
  Cauquenes province (Maule Region, Chile) on 15 February 2019.

### Changes

- Results are flagged, never silently corrected: one registry of
  diagnostic flags per stage (69 codes), classed conditions for errors
  and warnings.
- Physical constants are defined once, with unit, source and
  verification status.
- End-to-end tests run synthetic scenes through the METRIC chain, the
  forcing and the MODIS surface state.
- EarthFlux imports `terra`, `future`, `future.apply` and `stats`;
  `GWmodel` is suggested for the cross-verification of the GWR core.

### Documentation

- README with the status of the release and an example on
  `cauquenes_modis`; introductory vignette; website articles *Design and
  development status* and *Example scene: Cauquenes*.
- pkgdown site at <https://djwillichile.github.io/EarthFlux/>.
- Continuous integration on Linux, Windows and macOS; GitHub releases
  built from the version tag; Zenodo archive of each release.
