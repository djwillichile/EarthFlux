# Extraterrestrial radiation of an hourly or shorter period

Computes the extraterrestrial radiation \\R_a\\ received on a horizontal
surface at the top of the atmosphere during a period of one hour or
less, from the latitude, the longitude, the day of year and the UTC time
of the midpoint of the period (FAO-56).

## Usage

``` r
ef_ra_period(lat, lon, doy, utc_mid, period_hours)
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

Sun below the horizon: when the hour angle of the midpoint lies outside
\\\[-\omega_s, \omega_s\]\\ (Eq. 25), \\R_a = 0\\ by definition (FAO-56
midpoint criterion). A period that contains sunrise or sunset therefore
gets either its full integral or zero; trimming \\\omega_1, \omega_2\\
to the sunrise and sunset angles, attributed to ASCE-EWRI (2005) by
secondary implementations, is `CANDIDATA` and is not applied (decision
WF-10).

Missing values propagate. Values outside the domains above raise
`earthflux_domain_error`; a non-integer `doy` raises
`earthflux_input_error`.

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eqs. 28-33; case V15: 14:00-15:00 local
standard time on 1 October at 16 degrees 13' N, 16 degrees 15' W gives
3.543 MJ m-2 h-1).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

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
             doy = 274, utc_mid = 15.5, period_hours = 1)
#> [1] 3.543414

# Hourly course of one day (midpoints 00:30 ... 23:30 UTC)
ef_ra_period(lat = -35 * deg, lon = 0, doy = 15,
             utc_mid = 0:23 + 0.5, period_hours = 1)
#>  [1] 0.0000000 0.0000000 0.0000000 0.0000000 0.0000000 0.3941523 1.4025501
#>  [8] 2.3871690 3.2809089 4.0228630 4.5624682 4.8629514 4.9038351 4.6823332
#> [15] 4.2135407 3.5294049 2.6765487 1.7130928 0.7046950 0.0000000 0.0000000
#> [22] 0.0000000 0.0000000 0.0000000
```
