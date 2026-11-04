# Psychrometric constant

Computes the psychrometric constant \\\gamma\\ of FAO-56 from the
atmospheric pressure, with the latent heat of vaporization fixed at 2.45
MJ kg-1 as in the standardized reference evapotranspiration equation.

## Usage

``` r
ef_psychrometric(pressure)
```

## Arguments

- pressure:

  Numeric. Atmospheric pressure \\P\\ \[kPa\], for example from
  [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md).
  Must be finite and `> 0`.

## Value

A numeric vector of the psychrometric constant \\\gamma\\ \[kPa degC-1\]
with the length of `pressure`, keeping its `dim`.

## Details

\$\$\gamma = \frac{c_p P}{\varepsilon \lambda} = 0.665 \times 10^{-3}
P\$\$ with \\c_p\\ = 1.013e-3 MJ kg-1 degC-1, \\\varepsilon\\ = 0.622
and \\\lambda\\ = 2.45 MJ kg-1 (FAO-56, chapter 3, Eq. 8). The
coefficient published by FAO-56, 0.665e-3, is the rounded value of
1.013e-3 / (0.622 \* 2.45) = 6.6475e-4 and is used as published (it is
the one used in the FAO-56 examples).

Assumption: constant latent heat of vaporization (2.45 MJ kg-1, about 20
degrees C), as in the standardized equation. The general form with a
temperature-dependent \\\lambda\\ (FAO-56 annex 3, Eq. 3-10) is not
implemented here.

Missing values propagate. Non-numeric or empty input raises
`earthflux_input_error`; non-positive or infinite pressures raise
`earthflux_domain_error`.

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eq. 8; dev/specs/weather-forcing.md
4.2, case V1: P = 81.8 kPa gives 0.054 kPa degC-1). The same
coefficient, \\\gamma = 0.000665 P\\, is ASCE-EWRI (2005) Eqs. 4 and 35
(pp. 10, 28), with \\\lambda\\ = 2.45 MJ kg-1 (pp. 9, 27); the pressure
of
[`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md)
is its Eqs. 3 and 34.

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
Equation*. Task Committee on Standardization of Reference
Evapotranspiration, Environmental and Water Resources Institute of the
American Society of Civil Engineers. Final report, January 2005.
Published as Allen, R. G., Walter, I. A., Elliott, R. L., Howell, T. A.,
Itenfisu, D., Jensen, M. E., & Snyder, R. L. (Eds.), American Society of
Civil Engineers, Reston, VA.
[doi:10.1061/9780784408056](https://doi.org/10.1061/9780784408056)

## See also

Other derived meteorological variables:
[`ef_dewpoint()`](https://djwillichile.github.io/EarthFlux/reference/ef_dewpoint.md),
[`ef_ea`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md),
[`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md),
[`ef_es_slope()`](https://djwillichile.github.io/EarthFlux/reference/ef_es_slope.md),
[`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md),
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md),
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md),
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)

## Examples

``` r
# FAO-56 example 2: elevation 1800 m
ef_psychrometric(ef_air_pressure(1800))
#> [1] 0.0543676
```
