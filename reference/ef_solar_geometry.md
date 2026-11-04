# Solar geometry at the overpass time

Computes, for each pixel and its overpass instant, the position of the
sun relative to the horizontal and to the tilted plane of the pixel: the
cosine of the solar zenith angle, the cosine of the solar incidence
angle on the pixel plane, the solar declination, the hour angle and the
inverse relative Earth-Sun distance. These are the geometric inputs of
the shortwave transmissivity
([`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md))
and of the incoming shortwave radiation
([`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md)).

## Usage

``` r
ef_solar_geometry(doy, utc_hour, lat, lon, slope = 0, aspect = 0)
```

## Arguments

- doy:

  Numeric. Day of year of the **UTC** date of the instant \[-\]: a whole
  number in 1-366.

- utc_hour:

  Numeric. UTC time of day of the instant \[h\], decimal hours in \[0,
  24). It must be a UTC time (see Details).

- lat:

  Numeric. Latitude \[rad\], in \[-pi/2, pi/2\] (pixel centre, WGS84).

- lon:

  Numeric. Longitude \[rad\], positive east, in \[-pi, pi\].

- slope:

  Numeric. Slope of the pixel plane \[rad\], in \[0, pi/2\]. Default `0`
  (horizontal plane).

- aspect:

  Numeric. Aspect of the pixel plane \[rad\], GIS convention (clockwise
  from geographic north: 0 north, pi/2 east, pi south, 3 pi/2 west), in
  \[0, 2 pi). Default `0`; irrelevant when `slope = 0`, but an `NA`
  aspect still propagates (decision RC-16).

## Value

A plain list (no class) of numeric vectors, all with the common length
of the inputs and, if the inputs include matrices or arrays, their
common `dim`:

- `cos_zenith`: cosine of the solar zenith angle on the horizontal
  \\\cos\theta_h\\ \[-\];

- `cos_incidence`: cosine of the solar incidence angle on the pixel
  plane \\\cos\theta\_{rel}\\ \[-\];

- `declination`: solar declination \\\delta\\ \[rad\];

- `hour_angle`: hour angle \\\omega\\ \[rad\], in \[-pi, pi), negative
  in the morning;

- `inv_distance`: inverse relative Earth-Sun distance \\d_r\\ \[-\].

Values of `cos_zenith` or `cos_incidence` \\\le 0\\ (sun below the
horizon, or plane facing away from the sun) are returned unchanged:
their treatment belongs to the consuming functions.

## Details

With \\J\\ = `doy`, \\\phi\\ = `lat`, \\\lambda\\ = `lon`, \\s\\ =
`slope` and \\A\\ = `aspect`: \$\$\delta = 0.409 \sin\left(\frac{2\pi
J}{365} - 1.39\right), \quad d_r = 1 + 0.033 \cos\left(\frac{2\pi
J}{365}\right)\$\$ \$\$b = \frac{2\pi (J - 81)}{364}, \quad S_c = 0.1645
\sin 2b - 0.1255 \cos b - 0.025 \sin b\$\$ \$\$t_s = \left(t\_{UTC} +
\frac{12}{\pi}\lambda + S_c\right) \bmod 24, \quad \omega =
\frac{\pi}{12}(t_s - 12)\$\$ \$\$\cos\theta_h = \sin\delta \sin\phi +
\cos\delta \cos\phi \cos\omega\$\$ and, with \\\gamma = A - \pi\\
(surface azimuth: 0 facing south, east negative, west positive),
\$\$\cos\theta\_{rel} = \sin\delta \sin\phi \cos s - \sin\delta \cos\phi
\sin s \cos\gamma + \cos\delta \cos\phi \cos s \cos\omega + \cos\delta
\sin\phi \sin s \cos\gamma \cos\omega + \cos\delta \sin\gamma \sin s
\sin\omega\$\$ which reduces to \\\cos\theta_h\\ when \\s = 0\\.

**Time.** The equation of time \\S_c\\ is applied exactly once, here.
`utc_hour` must therefore be a UTC time. The daytime view time of MODIS
MOD11A1/MYD11A1 is local **mean** solar time (UTC plus the longitude in
degrees divided by 15) and must be converted to UTC first, as \\t\_{UTC}
= (t\_{ls} - \lambda\_{deg}/15) \bmod 24\\, with `doy` the day of year
of the UTC date of the file. A local **apparent** solar time must not be
converted this way: the equation of time would be applied twice. The
declination and \\d_r\\ are evaluated at the UTC date, which can differ
by one day from the local solar date.

**Angles** are in radians throughout (decision RC-01). A latitude given
in degrees by mistake (e.g. -35) lies outside \[-pi/2, pi/2\] and raises
an error; a small slope given in degrees (e.g. 1) cannot be detected.

Assumptions: low-precision calendar formulae of FAO-56, with the same
365-day expressions in leap years; no atmospheric refraction; only
self-shading is represented (no cast shadows from surrounding relief,
and no reduction of the sky view by the horizon).

Arguments must be numeric and have length 1 or a common length; length-1
arguments are recycled, matrix or array arguments must share their
`dim`. A non-integer `doy` raises `earthflux_input_error`; values
outside the domains above, or infinite values, raise
`earthflux_domain_error` (also `earthflux_input_error`). Missing values
propagate to the outputs that depend on them.

## Verification status

The declination, the inverse relative distance, the equation of time and
the hour angle are `VERIFICADA` against FAO-56 (chapter 3, Eqs. 23, 24
and 31-33; the hour angle is Eq. 31 written for UTC times, with the
exact 1/15 h per degree instead of 0.06667). The zenith angle relation
is the standard spherical-trigonometry identity; the incidence angle on
a tilted plane is `CANDIDATA` (form from solar engineering texts;
primary reference and its use in Allen et al., 2007, to be verified).
The precision of the FAO-56 calendar formulae against a higher-precision
ephemeris has not been quantified (decision RC-04).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

## See also

Other radiation functions:
[`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md),
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md),
[`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md),
[`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md),
[`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md),
[`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)

## Examples

``` r
deg <- pi / 180
# Horizontal pixel in central Chile, 15 January, 14:30 UTC
ef_solar_geometry(doy = 15, utc_hour = 14.5, lat = -35 * deg,
                  lon = -71 * deg)
#> $cos_zenith
#> [1] 0.8267324
#> 
#> $cos_incidence
#> [1] 0.8267324
#> 
#> $declination
#> [1] -0.3702158
#> 
#> $hour_angle
#> [1] -0.6252064
#> 
#> $inv_distance
#> [1] 1.031906
#> 

# North- and south-facing 20 degree slopes at the same instant
geo <- ef_solar_geometry(doy = 15, utc_hour = 14.5, lat = -35 * deg,
                         lon = -71 * deg, slope = 20 * deg,
                         aspect = c(0, 180) * deg)
geo$cos_incidence
#> [1] 0.8237953 0.7299534

# MOD11A1 view time (local mean solar time, h) converted to UTC first
lon_deg <- -71
view_time <- 10.6
utc_hour <- (view_time - lon_deg / 15) %% 24
ef_solar_geometry(doy = 15, utc_hour = utc_hour, lat = -35 * deg,
                  lon = lon_deg * deg)$cos_zenith
#> [1] 0.9087903
```
