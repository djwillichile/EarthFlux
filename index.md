# EarthFlux

**MODIS + METRIC + GWR → ETa**

EarthFlux is an R package for estimating spatially distributed actual
evapotranspiration (ETa) from Earth observation data with the METRIC
(Mapping EvapoTranspiration at high Resolution with Internalized
Calibration) surface energy balance framework.

Its methodological focus is the **meteorological forcing** of METRIC.
Instead of relying only on a single weather station assumed to be
representative of the whole scene, EarthFlux will make it possible to
represent weather variables as spatial surfaces, for example with
geographically weighted regression (GWR), and to compare that choice
against simpler alternatives.

``` text
MODIS surface state  +  weather stations
                              │
                 spatial forcing (GWR or alternatives)
                              │
     METRIC: Rn → G → anchor pixels → rah, dT → H → LE
                              │
                  ETinst → ETrF → ETa  (+ diagnostics)
```

Whether spatial forcing improves ETa estimates is a **research
question** that EarthFlux is designed to test. It is not a claim made by
this package.

## Status

EarthFlux is in **active early development** and is **not on CRAN**.

- The first METRIC component is available:
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md),
  the instantaneous surface net radiation. Its equation form is
  corroborated by secondary sources; verification against the primary
  reference (Allen et al., 2007) is pending.
- Soil heat flux, anchor pixel selection, sensible heat flux, the
  evapotranspiration chain, the spatial forcing module (GWR) and MODIS
  preprocessing are being specified before implementation.
- Equations are implemented only after their reference, units,
  assumptions, domain of validity and a verifiable test case are
  documented.
- No validation results exist yet. Do not use EarthFlux for operational
  or decision-making purposes.

## Design principles

- **Sensor-independent physics.** METRIC functions take physical
  variables with documented units; sensor modules (MODIS first) produce
  them.
- **Independent spatial forcing.** GWR is a separate module whose fitted
  models, bandwidths, residuals and diagnostics remain inspectable.
- **Modular METRIC.** Net radiation, soil heat flux, anchor pixel
  selection, aerodynamic resistance, dT, sensible and latent heat flux
  and ET are separate, individually tested components.
- **Diagnostics instead of silent corrections.** Physically anomalous
  values are reported and flagged, never silently modified.
- **Scalable.** Raster processing will be based on
  [terra](https://CRAN.R-project.org/package=terra), with optional
  parallel processing that gives identical results to sequential runs.

## Installation

You can install the development version of EarthFlux from GitHub with:

``` r

# install.packages("pak")
pak::pak("djwillichile/EarthFlux")
```

## Example

Net radiation for two pixels, with illustrative input values (not
observations). `rl_out` is the longwave radiation emitted by the surface
and `emissivity` must be the emissivity used to compute it; a scalar
`rl_in` is recycled.

``` r

library(EarthFlux)

ef_net_radiation(
  rs_in = c(800, 650),        # incoming shortwave [W m-2]
  albedo = c(0.20, 0.25),     # broadband albedo [-]
  rl_in = 320,                # incoming longwave [W m-2]
  rl_out = c(450.08, 430.50), # emitted longwave [W m-2]
  emissivity = c(0.98, 0.97)  # broadband emissivity [-]
)
#> [1] 503.52 367.40
```

Invalid inputs are rejected with classed errors instead of being
silently corrected:

``` r

ef_net_radiation(rs_in = 800, albedo = 1.2, rl_in = 320, rl_out = 450, emissivity = 0.98)
#> Error in `ef_net_radiation()`:
#> ! `albedo` must lie in [0, 1]; found 1 value(s) outside this interval.
```

## Related work

EarthFlux is conceptually inspired by the R package
[water](https://github.com/midraed/water) (Olmedo et al., 2016), which
implements METRIC for Landsat imagery. EarthFlux is an independent
implementation with a different scope: sensor-independent physics,
spatially varying meteorological forcing and diagnostics as part of the
results.

## Citation

Citation information is available with `citation("EarthFlux")`.

## License

MIT © Guillermo S. Fuentes-Jaque
