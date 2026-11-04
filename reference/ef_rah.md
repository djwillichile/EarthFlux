# Aerodynamic resistance to heat transport

Computes the aerodynamic resistance to heat transport \\r\_{ah}\\ \[s
m-1\] between two heights \\z_1\\ and \\z_2\\ above the zero-plane
displacement, from the friction velocity, with optional Monin-Obukhov
stability corrections for heat at both heights (neutral when both are
0).

## Usage

``` r
ef_rah(u_star, z1, z2, psi_h_z2 = 0, psi_h_z1 = 0)
```

## Arguments

- u_star:

  Numeric. Friction velocity \\u\_\*\\ \[m s-1\] (see
  [`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md)).
  Must be finite and `> 0`.

- z1, z2:

  Numeric. Lower and upper heights of the resistance \[m\]. Must be
  finite with `0 < z1 < z2`. No defaults: the METRIC values 0.1 m and 2
  m are `CANDIDATA`.

- psi_h_z2, psi_h_z1:

  Numeric. Stability corrections for heat at `z2` and `z1` \[-\]. Must
  be finite. The default 0 is the neutral case.

## Value

A numeric vector of aerodynamic resistance \\r\_{ah}\\ \[s m-1\], with
the common length of the inputs and keeping their `dim`. Non-positive
results (not reachable with the stability functions of the calibration)
are returned as `NA`.

## Details

\$\$r\_{ah} = \frac{\ln(z_2/z_1) - \psi_h(z_2) + \psi_h(z_1)} {k\\
u\_\*}\$\$ with \\k = 0.41\\. In the neutral case \\r\_{ah} =
\ln(z_2/z_1)/(k u\_\*)\\. This is not the FAO-56 resistance of chapter
2, Eq. 4: METRIC uses fixed heights \\z_1\\ and \\z_2\\ instead of the
roughness length for heat, and takes the roughness into account through
\\u\_\*\\.

Missing values propagate. Infinite values and values outside the domain
raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`).

Verification status: `CANDIDATA` (observed in the `water` package and in
`dev/SCIENTIFIC_SPEC.md` section 3; primary source not consulted).

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
[`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md),
[`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md),
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)

## Examples

``` r
# Neutral resistance between 0.1 m and 2 m
ef_rah(u_star = c(0.294349, 0.225324), z1 = 0.1, z2 = 2)
#> [1] 24.82313 32.42737

# Unstable corrections at both heights
ef_rah(0.372002, z1 = 0.1, z2 = 2, psi_h_z2 = 1.719595,
       psi_h_z1 = 0.263944)
#> [1] 10.09752
```
