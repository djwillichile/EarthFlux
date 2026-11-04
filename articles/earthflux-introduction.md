# Introduction to EarthFlux

``` r

library(EarthFlux)
```

## Purpose

EarthFlux aims to provide a reproducible workflow to estimate spatially
distributed actual evapotranspiration (ETa) following the conceptual
chain

**MODIS + METRIC + GWR → ETa**

This vignette describes the planned workflow. EarthFlux is in early
development: the first METRIC component,
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md),
is available, and the remaining components are being specified. No
result shown in the package documentation should be interpreted as
validated.

## Conceptual workflow

1.  **Surface state.** Satellite products (MODIS first) are converted
    into sensor-independent physical variables: land surface temperature
    (K), broadband albedo, NDVI, leaf area index and surface emissivity.
2.  **Meteorological forcing.** Weather station data are quality
    controlled and, optionally, regionalised into spatial surfaces, for
    example with geographically weighted regression (GWR).
3.  **Surface energy balance (METRIC).** Net radiation (Rn), soil heat
    flux (G), anchor pixel calibration, aerodynamic resistance (rah),
    the near-surface temperature difference (dT) and sensible heat
    flux (H) are computed by separate functions. Latent heat flux is the
    residual LE = Rn - G - H.
4.  **Evapotranspiration.** LE is converted to instantaneous ET, to the
    reference ET fraction (ETrF) and finally to daily ETa using
    reference evapotranspiration.
5.  **Diagnostics.** Each step reports quality flags instead of silently
    modifying anomalous values.

## Research question

The use of spatially varying meteorological forcing in METRIC is treated
as a hypothesis. EarthFlux is designed so that the same METRIC chain can
be run with (i) a single representative weather station, (ii) a
reference spatial interpolation method and (iii) GWR, and compared
against independent observations.

## Net radiation

The surface net radiation is the first available component. All fluxes
are instantaneous at the satellite overpass, in W m-2; the input values
below are illustrative.

``` r

ef_net_radiation(
  rs_in = 800, albedo = 0.20, rl_in = 320,
  rl_out = 450.0846, emissivity = 0.98
)
#> [1] 503.5154
```

## Next steps

The METRIC components that follow net radiation (soil heat flux, anchor
pixels, aerodynamic resistance and sensible heat flux, latent heat flux
and evapotranspiration), the spatial forcing module and MODIS
preprocessing are being specified, with their equations, units and
domain of validity, before implementation.
