# Friction velocity

Computes the friction velocity \\u\_\*\\ \[m s-1\] of each pixel from
the wind speed at the blending height and the momentum roughness length,
with an optional Monin-Obukhov stability correction for momentum at the
blending height (neutral when `psi_m = 0`).

## Usage

``` r
ef_ustar(u_blend, zom, blending_height, psi_m = 0)
```

## Arguments

- u_blend:

  Numeric. Wind speed at the blending height \\u_b\\ \[m s-1\] (see
  [`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md)).
  Must be finite and `>= 0`.

- zom:

  Numeric. Momentum roughness length \\z\_{om}\\ \[m\] (see
  [`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)).
  Must be finite, `> 0` and lower than `blending_height`.

- blending_height:

  Numeric. Blending height \\z_b\\ \[m\]. Must be finite and `> 0`. No
  default: the METRIC value of 200 m is `CANDIDATA`.

- psi_m:

  Numeric. Stability correction for momentum at the blending height
  \\\psi_m(z_b)\\ \[-\]. Must be finite. The default 0 is the neutral
  case.

## Value

A numeric vector of friction velocity \\u\_\*\\ \[m s-1\], with the
common length of the inputs and keeping their `dim`. Where
\\\ln(z_b/z\_{om}) - \psi_m \le 0\\ (very unstable conditions over a
rough surface) the friction velocity is not defined and `NA` is
returned; the calibration of the sensible heat flux flags such pixels
with `EF_H_USTAR_INVALID`. `u_blend = 0` gives \\u\_\* = 0\\, which
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md)
rejects.

## Details

\$\$u\_\* = \frac{k\\ u_b}{\ln(z_b / z\_{om}) - \psi_m(z_b)}\$\$ with
the von Karman constant \\k = 0.41\\ (FAO-56, chapter 2, Eq. 4). The
zero-plane displacement is not used for the pixel (heights are taken
above it), as in METRIC implementations.

Missing values propagate. Infinite values and values outside the domain
raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`).

Verification status: `CANDIDATA` (observed in the `water` package; the
value of \\k\\ is `VERIFICADA` as the FAO-56 value, its use in METRIC is
`CANDIDATA`).

## References

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

## See also

Other aerodynamics and sensible heat functions:
[`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md),
[`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md),
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md),
[`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md),
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md),
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md),
[`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md),
[`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)

## Examples

``` r
# Neutral friction velocity of three pixels (z_b = 200 m)
ef_ustar(u_blend = 5.823611, zom = c(0.06, 0.005, 0.02),
         blending_height = 200)
#> [1] 0.2943492 0.2253244 0.2592391

# With an unstable correction psi_m(z_b) = 4.18
ef_ustar(5.823611, zom = 0.005, blending_height = 200, psi_m = 4.178174)
#> [1] 0.372002
```
