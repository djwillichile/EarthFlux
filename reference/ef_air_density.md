# Air density

Computes the density of moist air \\\rho\_{air}\\ \[kg m-3\] from the
atmospheric pressure and the air temperature with the ideal-gas form of
FAO-56, using the virtual temperature approximation \\T\_{Kv} =
1.01\\T\\.

## Usage

``` r
ef_air_density(pressure, air_temperature)
```

## Arguments

- pressure:

  Numeric. Atmospheric pressure \\P\\ \[kPa\] (measured, regionalised or
  from
  [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md)).
  Must be finite and `> 0`.

- air_temperature:

  Numeric. Air temperature \\T\\ \[K\]. Must be finite and `> 0`. In the
  METRIC calibration this is the near-surface air temperature \\T_a =
  T_s - dT\\ (decision SH-08).

## Value

A numeric vector of air density \[kg m-3\], with the common length of
the inputs and keeping their `dim`.

## Details

\$\$\rho\_{air} = \frac{1000\\ P}{1.01\\ T\\ R}\$\$ with \\R = 287\\ J
kg-1 K-1 (specific gas constant of dry air) and the factor 1000
converting kPa to Pa. FAO-56 (chapter 2, box 6) writes \\T\_{Kv} = 1.01
(T + 273)\\ with \\T\\ in degrees Celsius; EarthFlux takes \\T\\ in K,
which is equivalent to using 273.15 instead of 273 (relative difference
about 5e-4; decision SH-08). The normative coefficients 1.01 and 287 are
kept as literals of this equation (decision WF-14).

Missing values propagate. Infinite values and values outside the domain
raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`).

Verification status: `VERIFICADA` as the content of FAO-56 (chapter 2,
box 6). Its use in METRIC is `CANDIDATA`: the SEBAL Idaho manual
computes the air density at \\T_a = T_s - dT\\ (Waters et al., 2002, p.
31, step 6), which corroborates the temperature used here, but it does
not print the density equation (METRIC implementations such as the
`water` package use a variant that evaluates the pressure of the
standard atmosphere with \\T_a\\ in place of 293 K: the two densities
coincide at sea level or at \\T_a\\ = 293 K, and the variant is higher
above 293 K, by about 0.6 % at 316 K and 700 m).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

## See also

Other aerodynamics and sensible heat functions:
[`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md),
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
# Air at 300 K and 500 m (pressure from elevation)
ef_air_density(ef_air_pressure(500), 300)
#> [1] 1.098511

ef_air_density(pressure = c(95.5276, 93.2947), air_temperature = c(300, 316))
#> [1] 1.098511 1.018513
```
