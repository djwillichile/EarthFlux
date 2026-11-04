# Incoming longwave radiation

Computes the incoming (downwelling) longwave radiation at the surface,
\\R\_{L\downarrow}\\, emitted by the atmosphere treated as a grey body
with an effective emissivity and an effective temperature. The result is
the `rl_in` argument of
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md).

## Usage

``` r
ef_rl_in(temperature, atm_emissivity)
```

## Arguments

- temperature:

  Numeric, no default. Effective temperature of the emitting atmosphere
  \[K\], `> 0`. The function is **agnostic** about which temperature is
  used: the air temperature at the overpass time (station or
  regionalised forcing), the surface temperature of the cold anchor
  pixel (a scene scalar) or the surface temperature of each pixel. The
  choice is open (decision RC-12) and must be made, and recorded, by the
  caller.

- atm_emissivity:

  Numeric. Effective atmospheric emissivity \\\varepsilon_a\\ \[-\],
  `> 0` (e.g.
  [`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md)).
  Values above 1 are accepted and reported by the diagnostics of the
  stage (`EF_RAD_ATM_EMISSIVITY_GT1`).

## Value

A numeric vector of \\R\_{L\downarrow}\\ \[W m-2\] with the common
length and `dim` of the inputs.

## Details

\$\$R\_{L\downarrow} = \varepsilon_a \sigma T^4\$\$ with \\\sigma\\ the
Stefan-Boltzmann constant (CODATA 2018 exact value, 5.670374419e-8 W m-2
K-4, decision RC-07).

Choice of the temperature (RC-12): with the air temperature, the
meteorological forcing (and GWR) enters the incoming longwave radiation;
with the cold-pixel surface temperature, the result is uniform in the
scene except through the emissivity; with the surface temperature of
each pixel, hot and dry pixels receive more longwave radiation, which
artificially reduces the contrast of net radiation. With which
temperature the coefficients of
[`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md)
were derived is not known (`TODO`).

Assumptions: grey-body atmosphere with effective emissivity and
temperature; clear sky; instantaneous value.

Arguments must be numeric and have length 1 or a common length (a scalar
temperature is recycled); matrix or array arguments must share their
`dim`. Non-positive or infinite values raise `earthflux_domain_error`
(also `earthflux_input_error`). Missing values propagate.

## Verification status

`CANDIDATA`. Stefan-Boltzmann law with an effective emissivity, form
observed in the `water` package (v1.0), attributed there to Allen et al.
(2007) (equation number and prescribed temperature not verified).

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
[`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md),
[`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md),
[`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md),
[`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)

## Examples

``` r
# Air temperature of 20 degrees C (293.15 K), transmissivity 0.75
ef_rl_in(temperature = 293.15, atm_emissivity = ef_atm_emissivity(0.75))
#> [1] 318.1943

# A scalar temperature recycled over several pixels
ef_rl_in(temperature = 290, atm_emissivity = c(0.72, 0.75, 0.78))
#> [1] 288.7595 300.7911 312.8228
```
