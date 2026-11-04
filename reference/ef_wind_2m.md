# Wind speed at 2 m above short grass

Converts the wind speed measured at a given height above the ground to
the wind speed at 2 m with the logarithmic wind profile of FAO-56, valid
for measurements above a short grass surface. It is the wind speed
entering the reference evapotranspiration
([`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md)).

## Usage

``` r
ef_wind_2m(wind_speed, height)
```

## Arguments

- wind_speed:

  Numeric. Wind speed measured at `height` \\u_z\\ \[m s-1\]. Must be
  finite and `>= 0`.

- height:

  Numeric. Height of the measurement above the ground \\z\\ \[m\]. Must
  be finite and greater than 6.42 / 67.8 = 0.0947 m, where the logarithm
  becomes non-positive.

## Value

A numeric vector of wind speed at 2 m \\u_2\\ \[m s-1\] with the common
length of the inputs, keeping their `dim`.

## Details

\$\$u_2 = u_z \frac{4.87}{\ln(67.8 z - 5.42)}\$\$ (FAO-56, chapter 3,
Eq. 47). At `height = 2` the factor is 1.00022, not exactly 1 (FAO-56
annex 2, table 2.9 rounds it to 1.000); at 10 m it is 0.74795 (table
2.9: 0.748).

Assumption (FAO-56): logarithmic profile for measurements above a short
grass surface. This is **not** the extrapolation to the blending height
of METRIC, which uses the roughness of the station surface and the raw
station wind
([`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md)).

Missing values propagate. Negative wind speeds, heights `<= 0.0947` m or
infinite values raise `earthflux_domain_error`.

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eq. 47; cases V12 and V13). The same
equation is ASCE-EWRI (2005) Eq. 33 (p. 26) and Eq. 67 (p. 44; the text
on that page calls it "Eq. 68", a typographical error), for measurements
above clipped grass; the report directs wind measured above other
surfaces (e.g. alfalfa) to its Appendix B, not implemented here.

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
[`ef_psychrometric()`](https://djwillichile.github.io/EarthFlux/reference/ef_psychrometric.md),
[`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md),
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md),
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md)

## Examples

``` r
# FAO-56 example 14: 3.2 m s-1 measured at 10 m
ef_wind_2m(wind_speed = 3.2, height = 10)
#> [1] 2.393443
```
