
<!-- README.md is generated from README.Rmd. Please edit that file -->

# EarthFlux

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/djwillichile/EarthFlux/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/djwillichile/EarthFlux/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

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

- No scientific function is available yet. The current version contains
  the package architecture, internal diagnostics infrastructure and test
  scaffolding.
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
