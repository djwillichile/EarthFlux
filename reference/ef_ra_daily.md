# Daily extraterrestrial radiation

Computes the daily extraterrestrial radiation \\R_a\\, the solar
radiation received on a horizontal surface at the top of the atmosphere
during one day, from the latitude and the day of year (FAO-56).

## Usage

``` r
ef_ra_daily(lat, doy)
```

## Arguments

- lat:

  Numeric. Latitude \\\phi\\ \[rad\], in \[-pi/2, pi/2\], positive
  north. Degrees must be converted (`deg * pi / 180`, FAO-56 Eq. 22).

- doy:

  Numeric. Day of year \\J\\, whole number in 1-366.

## Value

A numeric vector of daily extraterrestrial radiation \\R_a\\ \[MJ m-2
d-1\] with the common length of the inputs, keeping their `dim`.

## Details

\$\$R_a = \frac{24 \cdot 60}{\pi} G\_{sc} d_r \left\[\omega_s \sin\phi
\sin\delta + \cos\phi \cos\delta \sin\omega_s\right\]\$\$ with
\\G\_{sc}\\ = 0.0820 MJ m-2 min-1 (FAO-56, chapter 3, Eq. 21; the
package constant of the solar constant), the inverse relative distance
\\d_r\\ (Eq. 23), the declination \\\delta\\ (Eq. 24) and the sunset
hour angle \\\omega_s = \arccos(-\tan\phi \tan\delta)\\ (Eq. 25). The
declination and \\d_r\\ are the internal helpers shared with
[`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md).

Polar day and night: where \\\|\tan\phi \tan\delta\| \> 1\\ the argument
of the arc cosine is limited to \[-1, 1\], which gives the geometric
limits \\\omega_s = \pi\\ (24 h of sun) and \\\omega_s = 0\\ (no sun,
\\R_a = 0\\). FAO-56 (Eqs. 26-27) handles the same case with X = 0.00001
and notes that the daily equation has limited validity in winter at
latitudes above 55 degrees (north or south).

Missing values propagate. Latitudes outside \[-pi/2, pi/2\] (for example
given in degrees), `doy` outside 1-366 or infinite values raise
`earthflux_domain_error`; a non-integer `doy` raises
`earthflux_input_error`.

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eqs. 21-25; cases V7 and V9: 20 degrees
S on 3 September gives 32.2 MJ m-2 d-1). The same equations are
ASCE-EWRI (2005) Eqs. 21-24 and 27-29 (pp. 23-25), written with
\\G\_{sc}\\ = 4.92 MJ m-2 h-1 and the factor 24 / pi (identical to
0.0820 MJ m-2 min-1 and 24 \* 60 / pi). The limitation of the arc cosine
argument in polar conditions is an implementation choice
(dev/specs/weather-forcing.md 13).

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
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md),
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md),
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)

## Examples

``` r
# FAO-56 example 8: 20 degrees S, 3 September (J = 246)
ef_ra_daily(lat = -20 * pi / 180, doy = 246)
#> [1] 32.194

# Annual course in central Chile
ra <- ef_ra_daily(lat = -35 * pi / 180, doy = 1:365)
range(ra)
#> [1] 15.57067 44.42725
```
