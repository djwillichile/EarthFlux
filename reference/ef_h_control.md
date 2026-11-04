# Control parameters of the sensible heat flux calibration

Builds and validates the settings of
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md):
the heights of the aerodynamic formulation, the height at which the
stable stability correction for momentum is evaluated (open decision
SH-11) and the convergence settings of the iteration.

## Usage

``` r
ef_h_control(
  stable_psi_m_height,
  blending_height,
  z1,
  z2,
  tol = 0.01,
  maxit = 20L,
  damping = 0
)
```

## Arguments

- stable_psi_m_height:

  Numeric scalar. Height \[m\] at which the stability correction for
  momentum \\\psi_m\\ of the blending height is evaluated **under stable
  conditions** (\\L \> 0\\). No default: this is the open and blocking
  decision SH-11 (P0-2). METRIC implementations (`water`) use 2 m, i.e.
  \\\psi_m = -5 \cdot 2/L\\; the alternative is the blending height
  itself (e.g. 200 m, \\\psi_m = -5 \cdot 200/L\\). With \\L = 41.97\\ m
  the two choices give -0.238 and -23.8. Under unstable conditions
  \\\psi_m\\ is always evaluated at `blending_height`. Must be finite,
  `> 0` and `<= blending_height`.

- blending_height:

  Numeric scalar. Blending height \\z_b\\ \[m\]. No default (200 m in
  METRIC, `CANDIDATA`). Must be finite and greater than `z2`.

- z1, z2:

  Numeric scalars. Lower and upper heights of the aerodynamic resistance
  \[m\], `0 < z1 < z2`. No defaults (0.1 m and 2 m in METRIC,
  `CANDIDATA`).

- tol:

  Numeric scalar. Convergence tolerance on the relative change of
  \\r\_{ah}\\ between iterations, applied to every anchor (phase A) and
  to every pixel (phase B). Must be `> 0`. Default 0.01 (decision P0-10;
  value of METRIC implementations, without a primary source). The value
  matters: in the synthetic case of the specification, `tol = 0.01`
  stops 0.7 % away from the fixed point of the intercept.

- maxit:

  Integer scalar. Maximum number of iterations, `>= 1`. Default 20
  (P0-10; a design choice).

- damping:

  Numeric scalar. Damping factor \\\omega\\ in \[0, 1), \\r\_{ah,k} =
  (1 - \omega) r\_{ah,new} + \omega r\_{ah,k-1}\\. Default 0 (P0-10).
  Damping does not change the fixed point; it can help when the
  iteration oscillates.

## Value

A named list with elements `stable_psi_m_height`, `blending_height`,
`z1`, `z2`, `tol`, `maxit` (integer) and `damping`.

## Details

A missing `stable_psi_m_height`, `blending_height`, `z1` or `z2` raises
an error of class `earthflux_missing_input`; invalid values raise
`earthflux_domain_error` or `earthflux_input_error`.

Verification status: all heights are `CANDIDATA`; `tol`, `maxit` and
`damping` are design choices adopted provisionally (P0-10).

## See also

Other aerodynamics and sensible heat functions:
[`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md),
[`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md),
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md),
[`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md),
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md),
[`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md),
[`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md),
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)

## Examples

``` r
# Explicit choice of the open decision SH-11 (2 m, as in `water`)
ef_h_control(stable_psi_m_height = 2, blending_height = 200,
             z1 = 0.1, z2 = 2)
#> $stable_psi_m_height
#> [1] 2
#> 
#> $blending_height
#> [1] 200
#> 
#> $z1
#> [1] 0.1
#> 
#> $z2
#> [1] 2
#> 
#> $tol
#> [1] 0.01
#> 
#> $maxit
#> [1] 20
#> 
#> $damping
#> [1] 0
#> 
```
