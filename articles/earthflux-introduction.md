# Introduction to EarthFlux

``` r

library(EarthFlux)
```

## Purpose

*Land-Surface Energy and Water Fluxes from Earth Observation Data*

EarthFlux aims to provide a reproducible workflow to estimate spatially
distributed actual evapotranspiration (ETa) following the conceptual
chain

**MODIS + METRIC + GWR → ETa**

This vignette describes the workflow that EarthFlux implements step by
step. Version 0.1.0 is the first, experimental release: the METRIC core
physics (net radiation, soil heat flux, anchor pixels, sensible and
latent heat flux, instantaneous and daily ET), the meteorological
forcing (station tables, quality control, reference ET) and its
regionalization (including GWR) are available as functions, and the
MODIS preprocessing is internal, with an example scene shipped as the
dataset `cauquenes_modis`. The integrated `earthflux()` workflow does
not exist yet. Most METRIC formulations are verified against the SEBAL
Idaho manual of the METRIC authors (Waters et al., 2002), the direct
predecessor of METRIC; the others remain candidates. No result shown in
the package documentation should be interpreted as validated.

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

## Example scene

The dataset `cauquenes_modis` holds the MODIS surface state of the
Cauquenes province (Maule Region, Chile) for 15 February 2019. The
emitted longwave radiation of its cells follows from the land surface
temperature (K) and the broadband emissivity:

``` r

r <- terra::unwrap(cauquenes_modis)
rl_out <- ef_rl_out(
  lst = terra::values(r[["lst"]], mat = FALSE),
  emissivity = terra::values(r[["emissivity"]], mat = FALSE)
)
summary(rl_out) # W m-2; NA outside the province and where LST is missing
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.     NAs 
#>   383.4   444.1   467.8   458.1   476.2   489.6    5937
```

## Next steps

The integrated `earthflux()` workflow (milestone M5) will chain these
components with automatic inputs (MODIS products, elevation model and
gridded weather forcing) and documented presets. The scientific
comparison of a single station, simple interpolation and GWR as
meteorological forcing (milestone M6) comes after it.
