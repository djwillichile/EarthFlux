# Sensible heat flux

Computes the sensible heat flux \\H\\ \[W m-2\] from the air density,
the near-surface temperature difference and the aerodynamic resistance
to heat transport (bulk transfer equation of METRIC).

## Usage

``` r
ef_sensible_heat(air_density, dt, rah, cp)
```

## Arguments

- air_density:

  Numeric. Air density \[kg m-3\] (see
  [`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md)).
  Must be finite and `> 0`.

- dt:

  Numeric. Near-surface temperature difference \\dT\\ \[K\] (from \\dT =
  a + b\\T\_{s,datum}\\). Must be finite; negative values are allowed.

- rah:

  Numeric. Aerodynamic resistance to heat transport \[s m-1\] (see
  [`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md)).
  Must be finite and `> 0`.

- cp:

  Numeric. Specific heat of air at constant pressure \[J kg-1 K-1\].
  Must be finite and `> 0`. No default: the METRIC value (1004 J kg-1
  K-1, `CANDIDATA`, decision SH-09) is the one used and recorded by
  [`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md)
  (element `constants$cp`); FAO-56 uses 1013 J kg-1 K-1.

## Value

A numeric vector of sensible heat flux \\H\\ \[W m-2\], with the common
length of the inputs and keeping their `dim`. Negative values (\\dT \<
0\\, e.g. advection) are physically possible and are returned unchanged.

## Details

\$\$H = \frac{\rho\_{air}\\ c_p\\ dT}{r\_{ah}}\$\$

Within the METRIC calibration, \\dT\\ at the anchors is proportional to
\\1/c_p\\, so that, for a given \\r\_{ah}\\, the sensible heat flux of a
pixel does not depend on \\c_p\\; it enters only through the
Monin-Obukhov length (`dev/specs/sensible-heat.md` section 8.3).

Missing values propagate. Infinite values and values outside the domain
raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`).

Verification status: `CANDIDATA` (form of `dev/SCIENTIFIC_SPEC.md`
section 3 and METRIC implementations; Allen et al., 2007, not
consulted).

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
[`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md),
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)

## Examples

``` r
ef_sensible_heat(air_density = 1.069979, dt = 5.789273, rah = 28.1850,
                 cp = 1004)
#> [1] 220.6556
```
