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

## Shared physical quantities

Atmospheric and thermodynamic quantities used by several modules
(radiation, sensible heat, evapotranspiration and reference ET).

- [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md)
  : Atmospheric pressure from elevation
- [`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md)
  : Latent heat of vaporization
