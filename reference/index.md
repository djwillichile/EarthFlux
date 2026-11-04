# Package index

## METRIC

Physics core of the METRIC surface energy balance.

### Net radiation

- [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
  : Net radiation at the land surface

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
