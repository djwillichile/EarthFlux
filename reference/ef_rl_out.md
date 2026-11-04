# Longwave radiation emitted by the surface

Computes the longwave radiation **emitted** by the land surface,
\\R\_{L\uparrow}\\, from its temperature and broadband emissivity. The
result is the `rl_out` argument of
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
and does not include the reflected incoming longwave radiation, which
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
accounts for separately.

## Usage

``` r
ef_rl_out(lst, emissivity)
```

## Arguments

- lst:

  Numeric. Land surface temperature \\T_s\\ \[K\], `> 0` (e.g. MODIS LST
  with scale factor and quality control applied).

- emissivity:

  Numeric. Broadband surface emissivity \\\varepsilon_0\\ \[-\], in (0,
  1\]. It must be the same emissivity later passed to
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md).

## Value

A numeric vector of \\R\_{L\uparrow}\\ \[W m-2\] with the common length
and `dim` of the inputs.

## Details

\$\$R\_{L\uparrow} = \varepsilon_0 \sigma T_s^4\$\$ with \\\sigma\\ the
Stefan-Boltzmann constant (CODATA 2018 exact value, decision RC-07).
With the rounded 5.67e-8 W m-2 K-4 of some METRIC implementations the
result differs by about 6.6e-5 in relative terms.

Consistency of the emissivity (decision RC-14, open): the broadband
emissivity should be consistent with the narrow-band emissivities
assumed by the LST retrieval; the same value must be used here and in
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
(otherwise a spurious longwave term appears). A radiometer measurement
of the upwelling longwave radiation (emitted plus reflected) is not
interchangeable with this output.

Assumptions: grey-body surface with broadband emissivity; `lst`
represents the radiating surface of the whole pixel; instantaneous
value.

Arguments must be numeric and have length 1 or a common length; matrix
or array arguments must share their `dim`. A non-positive or infinite
`lst`, or an `emissivity` outside (0, 1\], raises
`earthflux_domain_error` (also `earthflux_input_error`). Plausibility of
`lst` (e.g. values in degrees Celsius by mistake) needs a threshold
without a documented reference and is not checked. Missing values (e.g.
cloudy MODIS pixels) propagate.

## Verification status

`CANDIDATA` (corroborated): the form \\\varepsilon_0 \sigma T_s^4\\ is
the one used by the `water` package (v1.0) and by an independent
secondary source (Wasti, 2020) together with the net radiation of
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md);
contrast with Allen et al. (2007) is pending.

## References

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

## See also

Other radiation functions:
[`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md),
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md),
[`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md),
[`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md),
[`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md),
[`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)

## Examples

``` r
# Surface at 300 K with emissivity 0.98
ef_rl_out(lst = 300, emissivity = 0.98)
#> [1] 450.1143

# Matrix input keeps its dim
ef_rl_out(lst = matrix(c(295, 300, 305, 310), 2), emissivity = 0.97)
#>          [,1]     [,2]
#> [1,] 416.5542 475.9736
#> [2,] 445.5213 507.9609
```
