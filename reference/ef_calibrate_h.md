# Calibrate the sensible heat flux from the anchor pixels

Internal calibration of METRIC: finds the coefficients of \\dT = a +
b\\T\_{s,datum}\\ such that the hot and cold anchor pixels reproduce
their target sensible heat flux \\H\_{target} = R_n - G -
LE\_{target}\\, iterating the aerodynamic resistance with the
Monin-Obukhov stability correction (phase A), and optionally computes
the sensible heat flux of every pixel with the calibrated coefficients
(phase B, strategy P2).

## Usage

``` r
ef_calibrate_h(anchors, control, lapse_rate, datum_elevation, pixels = NULL)
```

## Arguments

- anchors:

  The calibration points: a `data.frame` with exactly one row of `type`
  `"hot"` and one of `type` `"cold"` (one calibration point per anchor
  class, decision P0-9), or an `earthflux_anchors` object whose element
  `calibration_points` is such a data frame. Required columns
  (`dev/specs/sensible-heat.md` section 2.2):

  - `type`: `"hot"` or `"cold"`;

  - `lst`: land surface temperature \[K\];

  - `elevation`: elevation \[m\];

  - `zom`: momentum roughness length \[m\] (see
    [`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md));

  - `rn`: net radiation \[W m-2\];

  - `g`: soil heat flux \[W m-2\];

  - `le_target`: target latent heat flux of the anchor \[W m-2\] (its
    boundary condition, computed by the anchor module);

  - `u_blend`: wind speed at the blending height \[m s-1\] (see
    [`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md));

  - `pressure`: atmospheric pressure \[kPa\].

  An optional column `anchor_id` is carried to the result; other columns
  are ignored. Missing values at an anchor raise
  `earthflux_calibration_error`.

- control:

  The list returned by
  [`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md)
  (heights, the open decision SH-11 and the convergence settings). It is
  validated again.

- lapse_rate:

  Numeric scalar. Lapse rate of the surface temperature with elevation
  \[K m-1\] (see
  [`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md)).
  No default (SH-13).

- datum_elevation:

  Numeric scalar. Elevation of the temperature datum \[m\], a constant
  of the scene (see
  [`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md)).

- pixels:

  `NULL` (phase A only) or a list (or `data.frame`) of numeric vectors,
  matrices or arrays of length 1 or a common length, with elements `lst`
  \[K\], `elevation` \[m\], `zom` \[m\], `u_blend` \[m s-1\] and
  `pressure` \[kPa\], and optionally `rn` and `g` \[W m-2\] (used only
  to diagnose `EF_H_GT_AVAILABLE`). Missing values propagate to the
  outputs of the pixel.

## Value

An object of class `earthflux_h_calibration`, a list with:

- `a` \[K\], `b` \[-\]: calibrated coefficients (a\*, b\*), obtained by
  solving the anchor conditions once more with the final \\r\_{ah}\\
  (closure), so that the anchors reproduce \\H\_{target}\\ exactly;

- `converged` (logical) and `iterations` (integer) of phase A;

- `trace`: `data.frame` with one row per iteration: `iteration`, `a`,
  `b` (the iterate \\a_k, b_k\\), `delta_a`, `delta_b`, `max_rel_change`
  (convergence statistic) and, for each anchor (`_hot`, `_cold`), `dt`,
  `air_density`, `obukhov_length`, `u_star` and `rah`;

- `anchors`: `data.frame` with the final state of each anchor
  (`anchor_id`, `type`, `lst`, `elevation`, `ts_datum`, `h_target`,
  `dt`, `air_density`, `rah`, `u_star`, `obukhov_length`, `h`);

- `pixels`: `NULL`, or a list with `h` \[W m-2\], `dt` \[K\], `ts_datum`
  \[K\], `air_density` \[kg m-3\], `rah` \[s m-1\], `u_star` \[m s-1\],
  `obukhov_length` \[m\], `converged` (logical) and `iterations`
  (integer), each with the shape of the pixel inputs;

- `control`, `datum` (`lapse_rate`, `datum_elevation`), `constants`
  (`von_karman`, `gravity`, `cp` and their status) and `provenance`;

- `flags`: list of `earthflux_flag` records: the object flags
  `EF_H_CALIBRATION_NOT_CONVERGED` and `EF_H_DT_SLOPE_NONPOSITIVE` (both
  `critical`), and, with `pixels`, the cell flags `EF_H_USTAR_INVALID`,
  `EF_H_PIXEL_NOT_CONVERGED`, `EF_H_DT_EXTRAPOLATED_HOT`,
  `EF_H_DT_EXTRAPOLATED_COLD`, `EF_H_NEGATIVE` and (with `rn` and `g`)
  `EF_H_GT_AVAILABLE`. Every evaluated code is present, with
  `n_flagged = 0` when absent.

## Details

**Phase A** (anchors). Start (k = 0): neutral \\u\_\*\\ and \\r\_{ah}\\
(see
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md))
and \\dT_0 = 0\\ (SH-19). At each iteration k:

1.  \\\rho_k\\ with
    [`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md)
    at \\T_a = T_s - dT\_{k-1}\\ (SH-08);

2.  \\dT_k = H\_{target} r\_{ah,k-1} / (\rho_k c_p)\\ at each anchor;

3.  \\a_k, b_k\\ with
    [`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md);

4.  \\H_k = \rho_k c_p (a_k + b_k T\_{s,datum}) / r\_{ah,k-1}\\ (equal
    to the target by construction);

5.  Monin-Obukhov length \\L = -\rho c_p u\_\*^3 T_a / (k g H)\\ with
    \\u\_{\*,k-1}\\, \\T_a = T_s - dT_k\\ and \\\rho_k\\ (SH-10; \\L =
    \infty\\, neutral, when \\H = 0\\);

6.  stability corrections (unstable: Paulson-type forms with coefficient
    16; stable: log-linear form \\-5 z/L\\), with \\\psi_m\\ at the
    blending height (or at `stable_psi_m_height` when \\L \> 0\\, open
    decision SH-11) and \\\psi_h\\ at `z2` and `z1`; then \\u\_{\*,k}\\
    and the new \\r\_{ah}\\;

7.  damping: \\r\_{ah,k} = (1 - \omega) r\_{ah,new} + \omega
    r\_{ah,k-1}\\;

8.  convergence when \\\max_i \|r\_{ah,k} - r\_{ah,k-1}\| / r\_{ah,k} \<
    tol\\ over both anchors.

Closure: steps 1-3 are repeated with the final \\r\_{ah}\\ to give (a\*,
b\*), and \\r\_{ah}\\ is not updated afterwards, so the anchors
reproduce \\H\_{target}\\ exactly.

**Phase B** (pixels, strategy P2, decision P0-10). With (a\*, b\*)
fixed, \\dT = a^\* + b^\* T\_{s,datum}\\ and \\\rho\\ (at \\T_a = T_s -
dT\\) are fixed; each pixel iterates only its stability correction (\\H
\to L \to \psi \to u\_\* \to r\_{ah}\\) from the neutral state until its
own convergence (same `tol`, `maxit` and `damping`). The result of a
pixel depends only on its inputs and on (a\*, b\*), not on the other
pixels nor on the path of phase A, so the computation can be split into
blocks.

**Failures are never silent.**

- Phase A without convergence after `maxit` iterations: the last iterate
  is returned with `converged = FALSE`, a warning of class
  `earthflux_convergence_warning` is signalled (fields `iterations` and
  `trace`) and the object flag `EF_H_CALIBRATION_NOT_CONVERGED`
  (`critical`) is set.

- Calibrated slope `b <= 0`: a warning of class `earthflux_warning` and
  the object flag `EF_H_DT_SLOPE_NONPOSITIVE` (`critical`).

- Missing values at an anchor, `u_blend = 0` at an anchor, datum
  temperature of the hot anchor not greater than that of the cold
  anchor, or non-finite \\a\\, \\b\\, \\u\_\*\\, \\r\_{ah}\\ or air
  density at an anchor during the iteration: error of class
  `earthflux_calibration_error` (fields `iteration` and `trace` when the
  failure occurs during the iteration).

- A pixel whose friction velocity becomes undefined (see
  [`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md))
  or not positive: `NA` outputs for that pixel and the cell flag
  `EF_H_USTAR_INVALID`; a pixel without convergence keeps its last
  iterate and gets `EF_H_PIXEL_NOT_CONVERGED`.

Constants: von Karman constant `EF_VON_KARMAN` (0.41), gravity
`EF_GRAVITY` (9.807 m s-2, `CANDIDATA`) and specific heat of air
`EF_SPECIFIC_HEAT_AIR` (1004 J kg-1 K-1, `CANDIDATA`, decision SH-09
open); they are recorded in `constants`.

Verification status: `CANDIDATA`. The procedure follows
`dev/specs/sensible-heat.md` section 11, written from the `water`
package and secondary sources; Allen, Tasumi and Trezza (2007), Paulson
(1970) and Webb (1970) have not been consulted. Known differences with
`water` are listed in section 17 of that specification (e.g. no wind
floor, no substitute friction velocity, density at \\T_a\\, per-anchor
convergence, strategy P2).

## References

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

Paulson, C. A. (1970). The mathematical representation of wind speed and
temperature profiles in the unstable atmospheric surface layer. *Journal
of Applied Meteorology*, 9(6), 857-861.
[doi:10.1175/1520-0450(1970)009\<0857:TMROWS\>2.0.CO;2](https://doi.org/10.1175/1520-0450%281970%29009%3C0857%3ATMROWS%3E2.0.CO%3B2)

Webb, E. K. (1970). Profile relationships: The log-linear range, and
extension to strong stability. *Quarterly Journal of the Royal
Meteorological Society*, 96(407), 67-90.
[doi:10.1002/qj.49709640708](https://doi.org/10.1002/qj.49709640708)

## See also

Other aerodynamics and sensible heat functions:
[`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md),
[`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md),
[`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md),
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md),
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md),
[`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md),
[`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md),
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)

## Examples

``` r
# Synthetic scene of dev/specs/sensible-heat.md section 14
u_b <- ef_blending_wind(3, height = 2, zom_station = 0.015, d_station = 0,
                        blending_height = 200)
anchors <- data.frame(
  type = c("cold", "hot"),
  lst = c(300, 316),
  elevation = c(500, 700),
  zom = c(0.06, 0.005),
  rn = c(600, 480),
  g = c(50, 110),
  le_target = c(520, 0),
  u_blend = u_b,
  pressure = ef_air_pressure(c(500, 700))
)
ctrl <- ef_h_control(stable_psi_m_height = 2, blending_height = 200,
                     z1 = 0.1, z2 = 2)
cal <- ef_calibrate_h(anchors, control = ctrl, lapse_rate = 0.00649,
                      datum_elevation = 500,
                      pixels = list(lst = 308, elevation = 500, zom = 0.02,
                                    u_blend = u_b,
                                    pressure = ef_air_pressure(500)))
c(a = cal$a, b = cal$b, iterations = cal$iterations)
#>           a           b  iterations 
#> -87.0441335   0.2919416   6.0000000 
cal$pixels$h
#> [1] 181.9003
```
