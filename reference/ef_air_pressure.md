# Atmospheric pressure from elevation

Computes the mean atmospheric pressure \\P\\ at a given elevation above
sea level with the simplified ideal-gas relation of FAO-56 (standard
atmosphere at 20 degrees Celsius). It is used when no measured or
regionalised pressure is available, for example for the shortwave
transmissivity, the air density and the reference evapotranspiration.

## Usage

``` r
ef_air_pressure(elevation)
```

## Arguments

- elevation:

  Numeric. Elevation above sea level \[m\]. Must be finite and lower
  than 293 / 0.0065 = 45 076.92 m, where the base of the power law
  becomes non-positive. Negative elevations (below sea level) are
  allowed.

## Value

A numeric vector of atmospheric pressure \\P\\ \[kPa\] with the length
of `elevation`. If `elevation` is a matrix or array, the result keeps
its `dim`.

## Details

The pressure is \$\$P = 101.3 \left(\frac{293 - 0.0065
z}{293}\right)^{5.26}\$\$ where \\z\\ is `elevation` \[m\] and \\P\\ is
in kPa (FAO-56, chapter 3, Eq. 7).

Assumptions (FAO-56, chapter 3 and annex 3): standard atmosphere with a
reference temperature of 293 K at sea level and a constant lapse rate of
0.0065 K m-1; the exponent 5.26 approximates \\g / (\alpha_1 R)\\ with g
= 9.807 m s-2, R = 287 J kg-1 K-1 and \\\alpha_1\\ = 0.0065 K m-1. The
result is a mean pressure for the site: synoptic pressure variations are
not represented. FAO-56 states that the effect of pressure on
evapotranspiration is small and that the mean value for a location is
sufficient.

Missing values (`NA`, `NaN`) propagate to the output without errors or
warnings. `elevation` must be numeric (double or integer) and non-empty.
Infinite values or elevations of 45 076.92 m or more raise an error of
class `earthflux_domain_error` (also `earthflux_input_error`). A
plausible elevation range for a study area is not checked here (no
threshold has a documented reference).

Verification status: `VERIFICADA` (identical to FAO-56, chapter 3, Eq.
7). Its attribution to ASCE-EWRI (2005) has not been verified.

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

## See also

Other shared physical quantities:
[`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md)

## Examples

``` r
# Sea level: 101.3 kPa
ef_air_pressure(0)
#> [1] 101.3

# Several elevations (m)
ef_air_pressure(c(0, 1000, 1800, 3000))
#> [1] 101.30000  90.02462  81.75580  70.51497
```
