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
development: **no scientific function is available yet**, and no result
shown in the package documentation should be interpreted as validated.

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

## Next steps

The next development stage documents and verifies the METRIC equations,
their units and their domain of validity before any implementation. The
first planned function is the computation of net radiation.
