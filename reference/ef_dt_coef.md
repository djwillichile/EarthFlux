# Coefficients of the near-surface temperature difference

Solves the coefficients of the linear relation \\dT = a +
b\\T\_{s,datum}\\ of METRIC from the near-surface temperature
differences required at the hot and cold anchor pixels. The relation
reproduces both anchor values exactly.

## Usage

``` r
ef_dt_coef(ts_datum_hot, ts_datum_cold, dt_hot, dt_cold)
```

## Arguments

- ts_datum_hot, ts_datum_cold:

  Numeric. Datum temperature of the hot and cold anchor \[K\] (see
  [`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md)).
  Must be finite and `> 0`, with `ts_datum_hot > ts_datum_cold`.

- dt_hot, dt_cold:

  Numeric. Near-surface temperature difference required at the hot and
  cold anchor \[K\]. Must be finite.

## Value

A list with elements `a` (intercept \[K\]) and `b` (slope \[-\]),
numeric vectors with the common length of the inputs (one pair per
calibration, e.g. per scene) keeping their `dim`.

## Details

\$\$b = \frac{dT\_{hot} - dT\_{cold}}{T\_{s,datum,hot} -
T\_{s,datum,cold}}, \qquad a = dT\_{cold} - b\\T\_{s,datum,cold}\$\$

Notation: `a` is the intercept and `b` the slope, as in
`dev/SCIENTIFIC_SPEC.md`; the `water` package uses the opposite names.

Pixels outside the range of the anchors use the same line
(extrapolation, flagged by
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md)).
A slope `b <= 0` with well-ordered anchors contradicts the METRIC
assumption that \\dT\\ grows with the surface temperature: it is
returned unchanged here and flagged (`EF_H_DT_SLOPE_NONPOSITIVE`,
critical) by
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md).

Missing values propagate. `ts_datum_hot <= ts_datum_cold` (equal datum
temperatures leave `b` undefined; a lower hot temperature suggests
swapped anchors) raises an error of class `earthflux_calibration_error`.
Other values outside the domain raise `earthflux_domain_error` (also
`earthflux_input_error`).

Verification status: `CANDIDATA` (form observed in the `water` package
and in `dev/SCIENTIFIC_SPEC.md` section 3; Allen et al., 2007, not
consulted, including a reported erratum in its intercept equation).

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
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md),
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md),
[`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md),
[`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md),
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)

## Examples

``` r
ef_dt_coef(ts_datum_hot = 317.298, ts_datum_cold = 300,
           dt_hot = 11.733091, dt_cold = 0.675211)
#> $a
#> [1] -191.1021
#> 
#> $b
#> [1] 0.6392577
#> 
```
