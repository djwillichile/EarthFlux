# Clear-sky solar radiation

Computes the clear-sky solar radiation \\R\_{so}\\, the solar radiation
that would reach a horizontal surface under a cloudless sky, from the
extraterrestrial radiation and the elevation (FAO-56). It is the
reference of the cloudiness term of the net longwave radiation of the
reference surface
([`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md)).

## Usage

``` r
ef_rso(extraterrestrial, elevation)
```

## Arguments

- extraterrestrial:

  Numeric. Extraterrestrial radiation \\R_a\\ \[MJ m-2 per day or per
  period\], from
  [`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md)
  or
  [`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md).
  Must be finite and `>= 0`.

- elevation:

  Numeric. Elevation of the site above sea level \\z\\ \[m\], finite.

## Value

A numeric vector of clear-sky radiation \\R\_{so}\\ in the unit of
`extraterrestrial` \[MJ m-2 per day or per period\], with the common
length of the inputs, keeping their `dim`.

## Details

\$\$R\_{so} = (0.75 + 2 \times 10^{-5} z) R_a\$\$ (FAO-56, chapter 3,
Eq. 37 = annex 3, Eq. 3-13). FAO-56 (annex 3, after Allen, 1996) states
that it is a good approximation for **daily and hourly** periods at
elevations below 6000 m and low turbidity, obtained by linearising
Beer's law with elevation for a mean sun angle of about 50 degrees.
Elevations outside that range are not rejected (the bound is a validity
statement, not a physical limit). The forms with turbidity and
precipitable water (annex 3, Eqs. 3-14 to 3-20), for high turbidity or
low sun angles, are not implemented (decision WF-12: Eq. 37 is the
standard form for the reference surface; the variants serve quality
control).

Missing values propagate. Negative or infinite radiation and infinite
elevations raise `earthflux_domain_error`.

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eq. 37; annex 3, Eq. 3-13; cases V14
and V15). The same equation is the default clear-sky radiation of the
ASCE-EWRI (2005) standardized procedure for daily (Eq. 19, p. 22) and
hourly periods (Eq. 47, p. 37); the report reserves the more complex
forms of its Appendix D for assessing the solar radiation data.

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
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)

## Examples

``` r
# FAO-56 example 18 (Uccle, 100 m): Ra = 41.09 MJ m-2 d-1
ef_rso(extraterrestrial = 41.09, elevation = 100)
#> [1] 30.89968
```
