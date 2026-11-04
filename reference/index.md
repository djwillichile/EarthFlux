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
