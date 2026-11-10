# Control parameters of the sensible heat flux calibration

Builds and validates the settings of
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md):
the heights of the aerodynamic formulation, the height at which the
stable stability correction for momentum of the blending height is
evaluated (decision SH-11) and the convergence settings of the two
iterations: the calibration of dT at the anchors (phase A: `tol`,
`maxit`) and the per-pixel stability iteration with the calibrated
coefficients (phase B: `pixel_tol`, `pixel_maxit`).

## Usage

``` r
ef_h_control(
  stable_psi_m_height = 2,
  blending_height = 200,
  z1 = 0.1,
  z2 = 2,
  tol = 1e-06,
  maxit = 100L,
  damping = 0,
  pixel_tol = 1e-05,
  pixel_maxit = 100L
)
```

## Arguments

- stable_psi_m_height:

  Numeric scalar. Height \[m\] at which the stability correction for
  momentum \\\psi_m\\ of the blending height is evaluated **under stable
  conditions** (\\L \> 0\\). Default 2 m, i.e. \\\psi_m(200\\m) = -5
  \cdot 2/L\\, as written in Waters et al. (2002), p. 33, Eq. 38
  (decision SH-11, resolved). Another height may still be chosen
  explicitly, e.g. the blending height itself
  (`stable_psi_m_height = 200`, \\\psi_m = -5 \cdot 200/L\\); with \\L =
  41.97\\ m the two choices give -0.238 and -23.8. Under unstable
  conditions \\\psi_m\\ is always evaluated at `blending_height` (Eqs.
  35 and 37a). Must be finite, `> 0` and `<= blending_height`.

- blending_height:

  Numeric scalar. Blending height \\z_b\\ \[m\]. Default 200 m (Waters
  et al., 2002, p. 26). Must be finite and greater than `z2`.

- z1, z2:

  Numeric scalars. Lower and upper heights of the aerodynamic resistance
  \[m\], `0 < z1 < z2`. Defaults 0.1 m and 2 m (Waters et al., 2002, p.
  30 and Eq. 41).

- tol:

  Numeric scalar. Convergence tolerance of the calibration of dT at the
  anchors (phase A): the iteration stops when the relative change of
  \\r\_{ah}\\ between iterations is below `tol` at every anchor. Must be
  `> 0`. Default `1e-6` (decision M2-11; EarthFlux 0.1.0 used 0.01, the
  value of METRIC implementations). See Details.

- maxit:

  Integer scalar. Maximum number of iterations of phase A, `>= 1`.
  Default 100 (M2-11; 20 in EarthFlux 0.1.0).

- damping:

  Numeric scalar. Damping factor \\\omega\\ in \[0, 1), \\r\_{ah,k} =
  (1 - \omega) r\_{ah,new} + \omega r\_{ah,k-1}\\, used by both phases.
  Default 0 (P0-10). Damping does not change the fixed point; it can
  help when the iteration oscillates.

- pixel_tol:

  Numeric scalar. Convergence tolerance of the per-pixel stability
  iteration with the calibrated coefficients (phase B): a pixel stops
  when the relative change of its \\r\_{ah}\\ is below `pixel_tol`. Must
  be `> 0`. Default `1e-5` (M2-11; in EarthFlux 0.1.0 phase B used
  `tol`).

- pixel_maxit:

  Integer scalar. Maximum number of iterations of a pixel in phase B,
  `>= 1`. Default 100 (M2-11; in EarthFlux 0.1.0 phase B used `maxit`).

## Value

A named list with elements `stable_psi_m_height`, `blending_height`,
`z1`, `z2`, `tol`, `maxit` (integer), `damping`, `pixel_tol` and
`pixel_maxit` (integer).

## Details

Invalid values raise `earthflux_domain_error` or `earthflux_input_error`
(e.g. a `stable_psi_m_height` above the blending height, or `z2 <= z1`).

Why the tolerances are tight (decision M2-11): the result of a pixel is
the fixed point of its own stability iteration with (a\*, b\*), while
(a\*, b\*) come from the last iterate at the anchors. If phase A stops
early, the anchors run through phase B no longer reproduce their target
\\H\\, and the pixels inherit that offset. With `tol = pixel_tol = 0.01`
(the former settings) the mean \\H\\ of a strongly unstable, low-wind
Landsat scene (Talca, 2013-02-15) was 0.59 W m-2 below the fixed point
of both phases (maximum 1.29 W m-2), and 0.43 W m-2 above it (maximum
1.25 W m-2) in the packaged Cauquenes MODIS scene; a tight tolerance of
phase B alone did not reduce it. With the defaults the largest
difference is below 5e-4 W m-2 in both scenes, for 15 to 26 iterations
at the anchors and 1.5 to 2 times the former run time of the calibration
(`dev/verification/water-comparison.md`, section 5.3). Both criteria are
relative changes of \\r\_{ah}\\: dimensionless, and defined also where
\\H \approx 0\\; in phase B \\\rho\\ and dT are fixed, so the relative
change of \\r\_{ah}\\ of a pixel is also the relative change of its
\\H\\. The former behaviour is
`ef_h_control(tol = 0.01, maxit = 20, pixel_tol = 0.01, pixel_maxit = 20)`.

Why 2 m under stable conditions: the manual evaluates the stable
correction of the momentum at the blending height with the ratio
\\2/L\\, not \\200/L\\; the `water` package does the same. With a stable
cold anchor (\\H \< 0\\, advection) the calibration converges with 2 m
and diverges with 200 m in the synthetic scene of the specification
(finding M2-07 of `dev/DECISIONS.md`).

Verification status: `blending_height`, `z1`, `z2` and
`stable_psi_m_height = 2` are `VERIFICADA (SEBAL-Idaho 2002)` (Waters et
al., 2002, pp. 26, 30 and 33, Eqs. 38-41); the cross-check with Allen,
Tasumi and Trezza (2007) is desirable but no longer blocking
(`dev/VERIFICATION.md`). `tol`, `maxit`, `damping`, `pixel_tol` and
`pixel_maxit` are design choices (P0-10, M2-11), not values of a source:
the manual iterates until dT and rah of the hot pixel "have stabilized"
(Waters et al., 2002, p. 34).

## References

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

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
# Defaults of the SEBAL Idaho manual (z_b = 200 m, z1 = 0.1 m, z2 = 2 m,
# stable psi_m of the blending height with 2 / L)
ef_h_control()
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
#> [1] 1e-06
#> 
#> $maxit
#> [1] 100
#> 
#> $damping
#> [1] 0
#> 
#> $pixel_tol
#> [1] 1e-05
#> 
#> $pixel_maxit
#> [1] 100
#> 

# The blending height in the stable correction, chosen explicitly
ef_h_control(stable_psi_m_height = 200)
#> $stable_psi_m_height
#> [1] 200
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
#> [1] 1e-06
#> 
#> $maxit
#> [1] 100
#> 
#> $damping
#> [1] 0
#> 
#> $pixel_tol
#> [1] 1e-05
#> 
#> $pixel_maxit
#> [1] 100
#> 

# The convergence settings of EarthFlux 0.1.0
ef_h_control(tol = 0.01, maxit = 20, pixel_tol = 0.01, pixel_maxit = 20)
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
#> $pixel_tol
#> [1] 0.01
#> 
#> $pixel_maxit
#> [1] 20
#> 
```
