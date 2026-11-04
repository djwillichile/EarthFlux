# Package index

## METRIC

Physics core of the METRIC surface energy balance.

### Radiation components

Solar geometry, shortwave transmissivity, incoming shortwave and
longwave radiation and longwave radiation emitted by the surface: the
inputs of the net radiation.

- [`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md)
  : Solar geometry at the overpass time
- [`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)
  [`ef_tau_sw_allen()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)
  [`ef_tau_sw_elevation()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)
  : Broadband clear-sky shortwave atmospheric transmissivity
- [`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md)
  [`ef_rs_in_modelled()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md)
  [`ef_rs_in_measured()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md)
  : Incoming shortwave radiation on the pixel plane
- [`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md)
  : Effective atmospheric emissivity
- [`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md)
  : Incoming longwave radiation
- [`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md)
  : Longwave radiation emitted by the surface

### Net radiation

- [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
  : Net radiation at the land surface

### Soil heat flux

- [`ef_g()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md)
  [`ef_g_bastiaanssen()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md)
  [`ef_g_tasumi()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md)
  : Soil heat flux

### Anchor pixels

- [`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)
  : Automatic selection of the cold and hot anchor pixels
- [`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md)
  : Explicit (user-supplied) anchor pixels
- [`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md)
  : Selection criteria of anchor pixels
- [`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md)
  : Rule of an anchor pixel selection criterion
- [`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md)
  : Homogeneity criterion of anchor pixels
- [`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md)
  : Final pick of anchor pixels among the candidates
- [`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md)
  : Boundary conditions at the anchor pixels

### Aerodynamics and sensible heat

Momentum roughness, wind at the blending height, friction velocity,
aerodynamic resistance, air density, dT calibration from the anchor
pixels and sensible heat flux.

- [`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)
  [`ef_zom_lai()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)
  [`ef_zom_ndvi()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)
  [`ef_zom_perrier()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)
  [`ef_zom_height()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)
  : Momentum roughness length
- [`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md)
  : Wind speed at the blending height
- [`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md)
  : Friction velocity
- [`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md)
  : Aerodynamic resistance to heat transport
- [`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md)
  : Air density
- [`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md)
  : Surface temperature referred to an elevation datum
- [`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md)
  : Coefficients of the near-surface temperature difference
- [`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md)
  : Sensible heat flux
- [`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md)
  : Control parameters of the sensible heat flux calibration
- [`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md)
  : Calibrate the sensible heat flux from the anchor pixels

### Latent heat and evapotranspiration

- [`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md)
  : Latent heat flux as the residual of the surface energy balance
- [`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md)
  : Instantaneous evapotranspiration from the latent heat flux
- [`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md)
  : Reference evapotranspiration fraction
- [`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md)
  [`ef_et_daily_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md)
  : Daily actual evapotranspiration

## Meteorological forcing

Meteorological forcing of the METRIC chain from weather stations: the
standard station table and its quality control, the variables derived
from the observations and the reference evapotranspiration (grass ETo of
FAO-56, alfalfa ETr of the ASCE-EWRI standardized equation).

### Station data and quality control

Standard table of station metadata and observations (UTC timestamps,
contract units, provenance) and its quality control, which flags records
without modifying them.

- [`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md)
  : Standard table of weather station data
- [`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md)
  : Quality control of the standard station table

### Derived variables

Psychrometric constant, saturation and actual vapour pressure, dew
point, wind speed at 2 m, extraterrestrial and clear-sky radiation
(FAO-56).

- [`ef_psychrometric()`](https://djwillichile.github.io/EarthFlux/reference/ef_psychrometric.md)
  : Psychrometric constant
- [`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md)
  : Saturation vapour pressure
- [`ef_es_slope()`](https://djwillichile.github.io/EarthFlux/reference/ef_es_slope.md)
  : Slope of the saturation vapour pressure curve
- [`ef_ea_dewpoint()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md)
  [`ef_ea_rh()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md)
  [`ef_ea_tmin()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md)
  [`ef_ea_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md)
  : Actual vapour pressure
- [`ef_dewpoint()`](https://djwillichile.github.io/EarthFlux/reference/ef_dewpoint.md)
  : Dew point temperature from the actual vapour pressure
- [`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)
  : Wind speed at 2 m above short grass
- [`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md)
  : Daily extraterrestrial radiation
- [`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md)
  : Extraterrestrial radiation of an hourly or shorter period
- [`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md)
  : Clear-sky solar radiation

### Reference evapotranspiration

Net radiation and soil heat flux of the reference surface and the
reference evapotranspiration, with explicit reference crop, time step
and standard.

- [`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md)
  : Net radiation of the reference surface
- [`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md)
  : Soil heat flux of the reference surface
- [`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md)
  : Reference evapotranspiration (grass ETo, alfalfa ETr)

## Spatial regionalization (GWR)

Regionalization of meteorological station variables over the working
grid: an orchestrator that projects the stations, extracts the
covariates and predicts by blocks with terra, the comparison
configurations (representative station, global regression, inverse
distance weighting) and geographically weighted regression with one
common interface, the numeric GWR core (plain vectors and matrices in a
projected CRS, explicit kernel, bandwidth and criterion, auditable
bandwidth profiles, extrapolation flags) and spatial block
cross-validation.

### Regionalization

One surface per variable and target time, with a flag word per cell, the
fitted models, the station table and the provenance (including the
execution plan).

- [`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md)
  : Regionalize a station variable over the working grid

### Methods and control

Configurations C1 (representative station), C2 (global regression,
inverse distance weighting) and C3 (GWR), without defaults for the
scientific choices, and the settings of the block prediction.

- [`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md)
  : Regionalization by geographically weighted regression (C3)
- [`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md)
  : Regionalization by a representative station (C1)
- [`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md)
  : Regionalization by global linear regression (C2)
- [`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md)
  : Regionalization by inverse distance weighting (C2)
- [`ef_predict_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_predict_control.md)
  : Control of the prediction of a regionalized surface

### Fit and bandwidth selection

- [`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md)
  : Fit a geographically weighted regression
- [`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md)
  : Select the bandwidth of a geographically weighted regression
- [`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md)
  : Search settings of the GWR bandwidth selection

### Prediction and diagnostics

- [`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md)
  : Predict a geographically weighted regression at new locations
- [`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md)
  : Diagnostics of a geographically weighted regression

### Validation

Deterministic spatial block folds and out-of-fold predictions at the
stations, with the same folds for every method.

- [`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)
  : Spatial block folds of stations
- [`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md)
  : Cross-validate a regionalization at the stations

## Shared physical quantities

Atmospheric and thermodynamic quantities used by several modules
(radiation, sensible heat, evapotranspiration and reference ET).

- [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md)
  : Atmospheric pressure from elevation
- [`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md)
  : Latent heat of vaporization
