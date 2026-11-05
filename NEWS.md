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
scientific production use**: no result has been validated yet, and
interfaces may change. The integrated `earthflux()` workflow, its presets,
the automatic download of MODIS products, elevation models and weather
forcing, and validation results are not part of this release.

## Verification

* Reference evapotranspiration (FAO-56, worked examples 18 and 19
  reproduced; ASCE-EWRI 2005), unit conversions and MODIS product facts are
  `VERIFICADA` against their primary sources.
* Most METRIC formulations are `VERIFICADA (SEBAL-Idaho 2002)`: checked,
  with page and equation, against the SEBAL Idaho manual of the METRIC
  authors (Waters et al., 2002); the Perrier roughness against Allen et al.
  (2012, IAHS Publ. 352). The cross-check with Allen, Tasumi & Trezza (2007)
  remains desirable.
* The stable momentum correction at the blending height is
  psi_m(200 m) = -5 (2 / L) (Eq. 38), so `ef_h_control()` defaults
  `stable_psi_m_height` to 2 m; the verified heights (200, 0.1 and 2 m) and
  c_p = 1004 J kg-1 K-1 are defaults too. The Monin-Obukhov length uses the
  surface temperature and g = 9.81 m s-2 (Eq. 34).
* Still `CANDIDATA`, as explicit arguments without defaults: the
  partitioned shortwave transmissivity, the terrain projection of the
  incoming shortwave radiation, the incidence angle on a tilted plane, G of
  Tasumi, the FAO-56 air density in METRIC, the anchor selection criteria
  and `ef_lambda(method = "metric")`. Open: the temperature of the incoming
  longwave radiation (`ef_rl_in()`) and the emissivity of non-vegetated
  pixels (`lai_nonveg`). The register is `dev/VERIFICATION.md` in the source
  repository.

## New features

* **METRIC core.** The chain as numeric functions, from solar geometry to
  daily actual ET: radiation components and `ef_net_radiation()`, soil heat
  flux (`ef_g()`), anchor pixels (`ef_select_anchors()`, `ef_anchors()`,
  `ef_anchor_conditions()`), roughness, wind, friction velocity and
  aerodynamic resistance (`ef_zom()`, `ef_ustar()`, `ef_rah()`), the dT
  calibration and sensible heat (`ef_calibrate_h()`, `ef_sensible_heat()`),
  latent heat and ET (`ef_latent_heat()`, `ef_et_inst()`, `ef_etrf()`,
  `ef_et_daily()`).
* **Method families.** Each family has a dispatcher with an explicit
  `method` and no default (e.g. `ef_g(method = "bastiaanssen")`), returning
  a classed object with the value, the method, diagnostic flags and
  provenance; the method functions return plain numerics.
* **Meteorological forcing.** Weather station tables (`ef_station_table()`)
  with quality control (`ef_station_qc()`), derived variables verified
  against FAO-56 (vapour pressure, dew point, psychrometric constant, wind
  at 2 m, extraterrestrial and clear-sky radiation) and reference ET at the
  stations (`ef_ref_et()`, `ef_station_ref_et()`).
* **Spatial regionalization.** `ef_regionalize()` maps a station variable
  onto the working grid by a representative station, global regression,
  inverse distance weighting or geographically weighted regression on an
  internal GWR core (`ef_gwr_fit()`, `ef_gwr_predict()`), with exact block
  prediction, spatial block cross-validation (`ef_spatial_folds()`,
  `ef_regionalize_cv()`) and optional parallel execution under a `future`
  plan.
* **MODIS surface state** (internal, not exported yet): reading of local
  MODIS files, scaling, QA bits as flags, view time to UTC, broadband
  albedo and emissivity, temporal matching and aggregation to the native
  1 km grid of the land surface temperature.
* **Example data.** `cauquenes_modis`: the MODIS surface state of the
  Cauquenes province (Maule Region, Chile) on 15 February 2019.

## Changes

* Results are flagged, never silently corrected: one registry of
  diagnostic flags per stage (69 codes), classed conditions for errors and
  warnings.
* Physical constants are defined once, with unit, source and verification
  status.
* End-to-end tests run synthetic scenes through the METRIC chain, the
  forcing and the MODIS surface state.
* EarthFlux imports `terra`, `future`, `future.apply` and `stats`;
  `GWmodel` is suggested for the cross-verification of the GWR core.

## Documentation

* README with the status of the release and an example on
  `cauquenes_modis`; introductory vignette; website articles *Design and
  development status* and *Example scene: Cauquenes*.
* pkgdown site at <https://djwillichile.github.io/EarthFlux/>.
* Continuous integration on Linux, Windows and macOS; GitHub releases built
  from the version tag; Zenodo archive of each release.
