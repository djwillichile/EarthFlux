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
2504 and 237.2 in the exponent; the chapter 3 form is adopted. The
coefficient 2503 attributed to ASCE-EWRI (2005) by secondary
implementations is `CANDIDATA` and not used (weather-forcing.md 4.3).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

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
