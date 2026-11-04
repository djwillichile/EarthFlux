# Extraterrestrial radiation of an hourly or shorter period

Computes the extraterrestrial radiation \\R_a\\ received on a horizontal
surface at the top of the atmosphere during a period of one hour or
less, from the latitude, the longitude, the day of year and the UTC time
of the midpoint of the period (FAO-56).

## Usage

``` r
ef_ra_period(lat, lon, doy, utc_mid, period_hours, standard)
```

## Arguments

- lat:

  Numeric. Latitude \\\phi\\ \[rad\], in \[-pi/2, pi/2\], positive
  north. Degrees must be converted (`deg * pi / 180`, FAO-56 Eq. 22).

- lon:

  Numeric. Longitude \\\lambda\\ \[rad\], **positive east**, in \[-pi,
  pi\].

- doy:

  Numeric. Day of year of the **UTC** date of the midpoint of the
  period, whole number in 1-366.

- utc_mid:

  Numeric. UTC time of the midpoint of the period \[h\], decimal hours
  in \[0, 24). For a period 14:00-15:00 UTC, 14.5.

- period_hours:

  Numeric. Length of the period \\t_1\\ \[h\], in (0, 1\] (1 for hourly,
  0.5 for 30 min).

- standard:

  Character, no default. Treatment of the periods that contain sunrise
  or sunset: `"fao56"` (midpoint criterion of FAO-56: \\R_a = 0\\ when
  the sun is below the horizon at the midpoint, otherwise the full
  integral) or `"asce"` (limits of integration set to the sunrise and
  sunset hour angles, ASCE-EWRI 2005 Eq. 56). See Details.

## Value

A numeric vector of extraterrestrial radiation of the period \\R_a\\
\[MJ m-2 per period\] with the common length of the inputs, keeping
their `dim`.

## Details

\$\$R_a = \frac{12 \cdot 60}{\pi} G\_{sc} d_r \left\[(\omega_2 -
\omega_1) \sin\phi \sin\delta + \cos\phi \cos\delta (\sin\omega_2 -
\sin\omega_1)\right\]\$\$ with \\\omega_1 = \omega - \pi t_1 / 24\\ and
\\\omega_2 = \omega + \pi t_1 / 24\\ (FAO-56, chapter 3, Eqs. 28-30).
The hour angle at the midpoint \\\omega\\ is FAO-56 Eq. 31 (with the
seasonal correction \\S_c\\ of Eqs. 32-33) written for UTC times and
east-positive longitudes, \$\$\omega =
\frac{\pi}{12}\left\[\left(t\_{UTC} + \frac{12}{\pi}\lambda + S_c\right)
\bmod 24 - 12\right\]\$\$ which equals FAO-56 Eq. 31 with \\L_z = 0\\
and \\L_m = -\lambda\\ (FAO-56 counts longitudes positive west), with
the exact 1/15 h per degree instead of 0.06667 (decision WF-10). It is
computed by the internal hour angle of
[`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md).

The same equations are ASCE-EWRI (2005) Eqs. 48 and 50-58 (pp. 39-42),
with \\G\_{sc}\\ = 4.92 MJ m-2 h-1 (= 0.0820 MJ m-2 min-1) and the same
coefficients of \\d_r\\, \\\delta\\, \\S_c\\ and \\b\\.

**Sunrise and sunset** (`standard`, decision WF-10). With
`standard = "fao56"`, when the hour angle of the midpoint lies outside
\\\[-\omega_s, \omega_s\]\\ (Eq. 25), \\R_a = 0\\ by definition (FAO-56
midpoint criterion); a period that contains sunrise or sunset gets
either its full integral or zero. With `standard = "asce"`, the limits
of integration are set with the conditionals of ASCE-EWRI (2005) Eq. 56
(p. 41): \\\omega_1\\ and \\\omega_2\\ are limited to \\\[-\omega_s,
\omega_s\]\\ and \\\omega_1 \le \omega_2\\, applied to every period as
the report allows ("can be applied for all timesteps"); a period
entirely below the horizon gets 0 and a period containing sunrise or
sunset gets the integral over its sunlit part. The report also states
(p. 41) that a midpoint outside \\\[-\omega_s, \omega_s\]\\ means \\R_a
= 0\\; for a period whose midpoint is below the horizon but which
contains sunrise or sunset the two statements differ, and Eq. 56 is
followed. In polar day (\\\omega_s = \pi\\) there is no sunrise or
sunset and the limits are not changed (the literal limitation to
\\\[-\pi, \pi\]\\ would cut the periods around solar midnight).

Missing values propagate. Values outside the domains above raise
`earthflux_domain_error`; a non-integer `doy` raises
`earthflux_input_error`.

## Verification status

`standard = "fao56"`: `VERIFICADA` (FAO-56, chapter 3, Eqs. 28-33; case
V15: 14:00-15:00 local standard time on 1 October at 16 degrees 13' N,
16 degrees 15' W gives 3.543 MJ m-2 h-1). `standard = "asce"`:
`VERIFICADA` (ASCE-EWRI, 2005, Eqs. 48, 53-58, pp. 39-42; Eq. 56 for the
limits of integration).

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
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md),
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)

## Examples

``` r
deg <- pi / 180
# FAO-56 example 19: 1 October, 14:00-15:00 local standard time in a
# time zone 15 degrees west of Greenwich, i.e. 15:00-16:00 UTC
ef_ra_period(lat = (16 + 13 / 60) * deg, lon = -(16 + 15 / 60) * deg,
             doy = 274, utc_mid = 15.5, period_hours = 1,
             standard = "fao56")
#> [1] 3.543414

# Hourly course of one day (midpoints 00:30 ... 23:30 UTC): the two
# standards differ only in the periods containing sunrise and sunset
fao <- ef_ra_period(lat = -35 * deg, lon = 0, doy = 15,
                    utc_mid = 0:23 + 0.5, period_hours = 1,
                    standard = "fao56")
asce <- ef_ra_period(lat = -35 * deg, lon = 0, doy = 15,
                     utc_mid = 0:23 + 0.5, period_hours = 1,
                     standard = "asce")
which(fao != asce)
#> [1]  6 20
```
