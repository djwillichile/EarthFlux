# Wind speed at the blending height

Extrapolates the wind speed measured at a weather station to the
blending height \\z_b\\ with the neutral logarithmic wind profile over
the surface around the station. METRIC assumes that the wind at the
blending height is approximately uniform over the scene; a spatial wind
surface is also accepted (vectors per pixel).

## Usage

``` r
ef_blending_wind(
  wind_speed,
  height,
  zom_station,
  d_station,
  blending_height = 200
)
```

## Arguments

- wind_speed:

  Numeric. Wind speed measured at `height` \[m s-1\]. Must be finite and
  `>= 0`.

- height:

  Numeric. Measurement height \\z_x\\ \[m\]. Must be finite and greater
  than `d_station + zom_station`.

- zom_station:

  Numeric. Momentum roughness length of the surface around the station
  \\z\_{om,w}\\ \[m\]. Must be finite and `> 0`. No default: METRIC
  implementations use 0.015 m (clipped grass 0.12 m tall), FAO-56 box 4
  gives 0.123 h = 0.01476 m for the same grass (see
  [`ef_zom_height()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md));
  decision SH-04 is open.

- d_station:

  Numeric. Zero-plane displacement of the station surface \\d_w\\ \[m\].
  Must be finite and `>= 0`. No default: METRIC implementations use 0,
  FAO-56 gives 2 h / 3 = 0.08 m for grass 0.12 m tall (SH-04).

- blending_height:

  Numeric. Blending height \\z_b\\ \[m\]. Must be finite and greater
  than `d_station + zom_station`. Default 200 m (Waters et al., 2002, p.
  26, Eq. 29).

## Value

A numeric vector of wind speed at the blending height \\u_b\\ \[m s-1\],
with the common length of the inputs and keeping their `dim`.

## Details

\$\$u_b = u_x \frac{\ln\left((z_b - d_w)/z\_{om,w}\right)}
{\ln\left((z_x - d_w)/z\_{om,w}\right)}\$\$

Assumptions: neutral stability over the station surface and a
logarithmic profile up to the blending height. No minimum wind speed is
imposed (decision SH-06): low wind is reported, not replaced. No
elevation adjustment of the wind is applied (SH-07, not verified).

Missing values propagate. Infinite values and values outside the domain
raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`).

Verification status: with \\d_w = 0\\, `VERIFICADA (SEBAL-Idaho 2002)`:
Waters et al. (2002), p. 26, Eqs. 27 and 29 (neutral friction velocity
at the station and wind at 200 m), which use no displacement for the
station surface and estimate its roughness as \\z\_{om,w} = 0.12 h\\
(Eq. 28; h = 0.3 m at Kimberly). A positive \\d_w\\ is an extension of
the package (`CANDIDATA` in METRIC, decision SH-04): with \\d_w\\ and
\\z\_{om,w}\\ from FAO-56 box 4, the normalised profile coincides with
FAO-56, chapter 3, Eq. 47 (author's calculation).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

## See also

Other aerodynamics and sensible heat functions:
[`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md),
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md),
[`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md),
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md),
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md),
[`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md),
[`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md),
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)

## Examples

``` r
# 3 m s-1 at 2 m over grass (z_om,w = 0.015 m, d_w = 0), z_b = 200 m
ef_blending_wind(3, height = 2, zom_station = 0.015, d_station = 0)
#> [1] 5.823611

# Same grass with the FAO-56 displacement and roughness (h = 0.12 m)
ef_blending_wind(3, height = 2, zom_station = 0.01476, d_station = 0.08,
                 blending_height = 200)
#> [1] 5.862843
```
