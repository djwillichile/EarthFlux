# Slope of the saturation vapour pressure curve

Computes the slope \\\Delta\\ of the saturation vapour pressure curve at
a given air temperature (FAO-56).

## Usage

``` r
ef_es_slope(air_temperature)
```

## Arguments

- air_temperature:

  Numeric. Air temperature \[degrees Celsius\]: the mean daily
  temperature \\(T\_{max} + T\_{min})/2\\ for a daily time step (FAO-56,
  Eq. 9), or the mean hourly temperature for an hourly time step. Must
  be finite and `> -237.3`.

## Value

A numeric vector of \\\Delta\\ \[kPa degC-1\] with the length of
`air_temperature`, keeping its `dim`.

## Details

\$\$\Delta = \frac{4098\\ e^\circ(T)}{(T + 237.3)^2}\$\$ with
\\e^\circ(T)\\ from
[`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md)
(FAO-56, chapter 3, Eq. 13).

Missing values propagate; the domain is that of
[`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md).

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eq. 13; case V14: 0.122 kPa degC-1 at
16.9 degrees C). FAO-56 annex 3, Eq. 3-9 writes the same quantity with
2504 and 237.2 in the exponent; the chapter 3 form is adopted. ASCE-EWRI
(2005) Eqs. 5 and 36 (pp. 10, 28) write \\\Delta = 2503 \exp(17.27 T /
(T + 237.3)) / (T + 237.3)^2\\: 2503 is the product 4098 x 0.6108 =
2503.06 rounded, so the two forms differ by a constant factor of 2.3e-5
(relative), far below the precision of the published values; the FAO-56
form is used for both standards (dev/specs/weather-forcing.md 4.3).

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
[`ef_psychrometric()`](https://djwillichile.github.io/EarthFlux/reference/ef_psychrometric.md),
[`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md),
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md),
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md),
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)

## Examples

``` r
# FAO-56 example 18: mean temperature (21.5 + 12.3) / 2 degrees C
ef_es_slope((21.5 + 12.3) / 2)
#> [1] 0.1221127
```
