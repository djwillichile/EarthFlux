# Design and development status

This page describes the planned design of EarthFlux and the development
status of each component. **Only the functions marked as available can
be used today.** All other functions are planned: their names, arguments
and behaviour may still change, and none of their results should be
used.

Each component is implemented only after its equations, units, domain of
validity and test cases are specified and, where possible, verified
against the primary sources. The internal specifications are linked
below for readers who want the full detail.

## Processing chain

``` text
MODIS products            weather stations
      |                         |
 surface state           quality control, reference ET
 (LST, albedo,                  |
  NDVI, LAI, emissivity)  spatial forcing (C1 single station,
      |                    C2 simple interpolation, C3 GWR)
      |                         |
      +------------+------------+
                   |
   METRIC: Rn -> G -> anchor pixels -> rah, dT -> H -> LE
                   |
          ETinst -> ETrF -> ETa  (+ diagnostic flags and provenance)
```

The use of geographically weighted regression (GWR) for the
meteorological forcing is a research hypothesis that EarthFlux is
designed to test, not an established result.

## Verification status

| Status | Meaning |
|----|----|
| Verified | The equation was checked against the primary source (equation and page or table). |
| Verified (SEBAL Idaho manual) | The equation was checked word for word against the SEBAL Idaho manual of the METRIC authors (Waters et al., 2002), with page and equation; the cross-check with Allen, Tasumi & Trezza (2007) remains desirable. Likewise “Verified (IAHS 2012)” for Allen et al. (2012). |
| Candidate | Known form, corroborated by secondary sources, pending verification against the primary source. |

## Components

### Radiation (milestone M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md) | Surface net radiation | **Available**; verified (SEBAL Idaho manual) |
| [`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md) | Solar angles and incidence on sloping terrain | **Available**; calendar terms and hour angle verified (FAO-56), incidence on a tilted plane candidate |
| [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md) | Atmospheric pressure from elevation | **Available**; verified (FAO-56, Eq. 7) |
| [`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md), [`ef_tau_sw_allen()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md), [`ef_tau_sw_elevation()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md) | Broadband shortwave transmissivity, with beam/diffuse partition (`"allen"`) or from elevation | **Available**; `"elevation"` verified (SEBAL Idaho manual), `"allen"` candidate |
| [`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md), [`ef_rs_in_modelled()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md), [`ef_rs_in_measured()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md) | Incoming shortwave radiation on the pixel plane (slope and aspect), clear-sky or measured | **Available**; modelled on flat terrain verified (SEBAL Idaho manual), on slopes candidate |
| [`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md) | Clear-sky atmospheric emissivity | **Available**; verified (SEBAL Idaho manual) |
| [`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md), [`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md) | Incoming and emitted longwave radiation | **Available**; verified (SEBAL Idaho manual); the temperature of [`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md) is chosen by the caller |

Specifications:
[ef_net_radiation.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/ef_net_radiation.md),
[radiation-components.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/radiation-components.md).

### Soil heat flux (M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_g()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md), [`ef_g_bastiaanssen()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md), [`ef_g_tasumi()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md) | Soil heat flux with an explicit method | **Available**; Bastiaanssen verified (SEBAL Idaho manual), Tasumi candidate |

Specification:
[soil-heat-flux.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/soil-heat-flux.md).

### Anchor pixels (M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md), [`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md), [`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md), [`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md) | Explicit, documented selection criteria (no default thresholds) | **Available**; every value is a user choice |
| [`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md) | Automatic, deterministic and auditable selection of hot and cold pixels | **Available**; candidate |
| [`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md) | Anchors chosen explicitly by the user | **Available** |
| [`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md) | Boundary conditions (target LE and H) at the anchors | **Available**; forms verified (SEBAL Idaho manual), coefficients explicit |

Specification:
[anchor-pixels.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/anchor-pixels.md).

### Sensible heat flux (M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md), [`ef_zom_lai()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md), [`ef_zom_ndvi()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md), [`ef_zom_perrier()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md), [`ef_zom_height()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md) | Momentum roughness length | **Available**; `"lai"` and `"ndvi"` verified (SEBAL Idaho manual), `"perrier"` verified (IAHS 2012), `"height"` verified as FAO-56 content |
| [`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md) | Wind speed at the blending height | **Available**; verified (SEBAL Idaho manual) |
| [`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md), [`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md) | Friction velocity and aerodynamic resistance with stability correction | **Available**; verified (SEBAL Idaho manual) |
| [`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md) | Air density | **Available**; FAO-56 form verified, use in METRIC candidate |
| [`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md), [`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md) | Datum surface temperature and coefficients of dT from the anchors | **Available**; verified (SEBAL Idaho manual) |
| [`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md) | Sensible heat flux | **Available**; verified (SEBAL Idaho manual) |
| [`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md), [`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md) | Iterative calibration of dT and H with stability correction | **Available**; forms verified (SEBAL Idaho manual), including the stable momentum correction (decision SH-11, default 2 m) |

Specification:
[sensible-heat.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/sensible-heat.md).

### Evapotranspiration (M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md) | Latent heat of vaporization with an explicit method | **Available**; verified (FAO-56) |
| [`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md) | Latent heat flux as the energy balance residual | **Available**; balance verified (FAO-56) |
| [`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md) | Instantaneous ET from latent heat flux | **Available**; unit conversion verified (FAO-56) |
| [`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md), [`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md), [`ef_et_daily_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md) | Reference ET fraction and daily actual ET | **Available**; verified (SEBAL Idaho manual) |
| `ef_et_period()` | ET between image dates | Planned (later) |

Dispatchers
([`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md),
[`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md),
[`ef_g()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md),
[`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md))
take the method as their last argument, with no default, and return a
classed list with the values, the method, diagnostic flags and
provenance; the method functions return plain numeric values. An
end-to-end test runs a synthetic scene through the whole chain.

Specification:
[evapotranspiration.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/evapotranspiration.md).

### Weather stations and reference ET (milestone M3)

| Function | Purpose | Status |
|----|----|----|
| [`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md) | Standard station and observation tables (UTC timestamps, contract units, measurement heights, provenance) | **Available** |
| [`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md) | Station quality control (values are flagged, never deleted) | **Available**; tests that need a threshold without a documented reference are not evaluated |
| [`ef_psychrometric()`](https://djwillichile.github.io/EarthFlux/reference/ef_psychrometric.md), [`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md), [`ef_es_slope()`](https://djwillichile.github.io/EarthFlux/reference/ef_es_slope.md), [`ef_ea_dewpoint()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md), [`ef_ea_rh()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md), [`ef_ea_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md), [`ef_ea_tmin()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md), [`ef_dewpoint()`](https://djwillichile.github.io/EarthFlux/reference/ef_dewpoint.md), [`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md), [`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md), [`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md), [`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md) | Derived meteorological variables | **Available**; verified (FAO-56; ASCE-EWRI 2005 forms) |
| [`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md), [`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md), [`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md) | Grass (FAO-56, ASCE-EWRI) and alfalfa (ASCE-EWRI) reference ET, hourly and daily | **Available**; verified (FAO-56 examples 18 and 19 reproduced; ASCE-EWRI 2005 equations and constants checked, its worked examples not reproduced yet) |
| [`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md) | Reference ET series of every station, at the overpass and as daily sums | **Available**; open choices are explicit arguments |

Specification:
[weather-forcing.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/weather-forcing.md).

### Spatial forcing (M3)

| Function | Purpose | Status |
|----|----|----|
| [`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md) | One surface per variable and target time over the working grid, with a flag word per cell, the fitted models and provenance; exact prediction by raster blocks, optionally in parallel | **Available** |
| [`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md) | C3: geographically weighted regression (explicit kernel, bandwidth and criterion) | **Available**; candidate (agrees with `GWmodel`) |
| [`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md), [`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md) | C2: global regression and inverse distance weighting | **Available** |
| [`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md) | C1: single representative station | **Available** |
| [`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md), [`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md), [`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md), [`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md) | Numeric GWR core on plain vectors and matrices | **Available**; candidate |
| [`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md), [`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md) | Spatial block cross-validation with the same folds for every method | **Available** |

Specification:
[gwr-forcing.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/gwr-forcing.md).

### MODIS preprocessing (milestone M4)

Internal functions (not exported yet) read MODIS products from local
files, apply scale factors and quality flags, convert view times to UTC
and assemble the surface state (LST, albedo, NDVI, LAI, emissivity and
the overpass instant, each with a flag word). Product metadata (layers,
scale factors, fill values, quality bits) are verified against the
official user guides; the conversions (albedo, aggregation) are
candidates and the LAI-based emissivity follows the SEBAL Idaho manual.
The dataset `cauquenes_modis` is the output of this preprocessing for
the Cauquenes province on 15 February 2019; see the article [Example
scene:
Cauquenes](https://djwillichile.github.io/EarthFlux/articles/cauquenes-example.md).

Specification:
[modis-products.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/modis-products.md).

### Integrated workflow (milestone M5)

| Function | Purpose | Status |
|----|----|----|
| [`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md) | Complete workflow built on the same low-level functions, with automatic inputs (MODIS, elevation model, gridded weather forcing) and presets, returning all intermediate components, diagnostics and provenance | Planned |

## More information

- Scientific specification and index:
  [SCIENTIFIC_SPEC.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/SCIENTIFIC_SPEC.md)
- Roadmap:
  [ROADMAP.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/ROADMAP.md)
- Validation plan:
  [VALIDATION_PLAN.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/VALIDATION_PLAN.md)
