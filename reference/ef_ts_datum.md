# Surface temperature referred to an elevation datum

Adjusts the land surface temperature to a common elevation datum with a
constant lapse rate of the surface temperature with elevation, so that
the near-surface temperature difference \\dT\\ of METRIC is calibrated
and applied on temperatures that are comparable across elevations. The
datum temperature is used only for \\dT\\; air density, pressure,
roughness and wind use the actual elevation.

## Usage

``` r
ef_ts_datum(lst, elevation, datum_elevation, lapse_rate)
```

## Arguments

- lst:

  Numeric. Land surface temperature \\T_s\\ \[K\]. Must be finite and
  `> 0`.

- elevation:

  Numeric. Elevation of the pixel \\z\\ \[m\]. Must be finite.

- datum_elevation:

  Numeric scalar. Elevation of the datum \\z\_{datum}\\ \[m\]. Must be
  finite. A constant of the scene, recorded with the calibration: it
  changes the reported intercept `a`, not the sensible heat flux (see
  Details).

- lapse_rate:

  Numeric scalar. Lapse rate of the surface temperature with elevation
  \\\Gamma\\ \[K m-1\] (note: per metre, not per kilometre). Must be
  finite and `>= 0`. No default (decision SH-13): the SEBAL Idaho manual
  uses 0.0065 K m-1 (Waters et al., 2002, Eq. 12-7), the `water` package
  0.00649 K m-1, and METRIC tailors the lapse rate to the scene, with
  separate rates for flat and mountainous terrain (Allen et al.,
  2012, p. 74).

## Value

A numeric vector of datum temperature \\T\_{s,datum}\\ \[K\], with the
common length of `lst` and `elevation` and keeping their `dim`.

## Details

\$\$T\_{s,datum} = T_s + \Gamma\\(z - z\_{datum})\$\$

The value of \\z\_{datum}\\ does not affect the calibrated \\dT\\ nor
the sensible heat flux (author's derivation,
`dev/specs/sensible-heat.md` section 9.1): shifting the datum shifts
every datum temperature by the same amount, which the two-anchor linear
relation absorbs in its intercept. Only \\\Gamma\\ matters.

Missing values propagate. Infinite values and values outside the domain
raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`).

Verification status: the form is `VERIFICADA (SEBAL-Idaho 2002)`: Waters
et al. (2002), appendix 12, p. 96, Eq. 12-7 (\\T\_{s,dem} = T_s +
0.0065\\\Delta z\\, with \\\Delta z\\ the elevation of the pixel minus
that of the datum, usually the weather station). The "dual-stage"
correction of METRIC for mountains (Allen et al., 2012, p. 74) is not
implemented. The cross-check with Allen et al. (2007) remains desirable
but is no longer blocking.

## References

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

Allen, R. G., Kjaersgaard, J. H., Trezza, R., Oliveira, A., Robison, C.,
& Lorite-Torres, I. (2012). Refining components of a satellite-based
surface energy balance model to complex land-use systems. In *Remote
Sensing and Hydrology* (IAHS Publication 352, pp. 73-75). IAHS Press.

## See also

Other aerodynamics and sensible heat functions:
[`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md),
[`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md),
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md),
[`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md),
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md),
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md),
[`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md),
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md),
[`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)

## Examples

``` r
# Pixels at 500 m and 700 m referred to a 500 m datum
ef_ts_datum(lst = c(300, 316), elevation = c(500, 700),
            datum_elevation = 500, lapse_rate = 0.00649)
#> [1] 300.000 317.298
```
