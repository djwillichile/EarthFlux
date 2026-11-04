# Dew point temperature from the actual vapour pressure

Computes the dew point temperature from the actual vapour pressure with
the explicit FAO-56 expression, used for quality control of humidity
data (for example to compare the dew point with the minimum
temperature).

## Usage

``` r
ef_dewpoint(vapour_pressure)
```

## Arguments

- vapour_pressure:

  Numeric. Actual vapour pressure \\e_a\\ \[kPa\]. Must be finite and
  `> 0` (logarithm), and below \\e^{16.78}\\ kPa (where the denominator
  vanishes; far outside any atmospheric value).

## Value

A numeric vector of dew point temperature \[degrees Celsius\] with the
length of `vapour_pressure`, keeping its `dim`.

## Details

\$\$T\_{dew} = \frac{116.91 + 237.3 \ln e_a}{16.78 - \ln e_a}\$\$
(FAO-56, annex 3, Eq. 3-11). It is not the exact inverse of
[`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md)
(FAO-56 Eq. 11): for \\e_a = e^\circ(15)\\ = 1.70535 kPa it returns
14.9926 degrees C (difference 0.0074 degrees C), which is sufficient for
quality control (dev/specs/weather-forcing.md 4.4).

Missing values propagate. Non-positive, too large or infinite values
raise `earthflux_domain_error`.

## Verification status

`VERIFICADA` as the FAO-56 form (annex 3, Eq. 3-11; case V17).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

## See also

Other derived meteorological variables:
[`ef_ea`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md),
[`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md),
[`ef_es_slope()`](https://djwillichile.github.io/EarthFlux/reference/ef_es_slope.md),
[`ef_psychrometric()`](https://djwillichile.github.io/EarthFlux/reference/ef_psychrometric.md),
[`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md),
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md),
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md),
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)

## Examples

``` r
ef_dewpoint(ef_ea_dewpoint(15))
#> [1] 14.9926
```
