# Effective atmospheric emissivity

Computes the effective broadband emissivity of a clear-sky atmosphere,
\\\varepsilon_a\\, from the clear-sky shortwave transmissivity. It is
the emissivity used by
[`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md)
for the incoming longwave radiation.

## Usage

``` r
ef_atm_emissivity(tau_sw)
```

## Arguments

- tau_sw:

  Numeric. Total clear-sky broadband shortwave transmissivity on the
  horizontal \\\tau\_{sw}\\ \[-\], in the open interval (0, 1):
  [`ef_tau_sw_elevation()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)
  in the SEBAL Idaho manual, or `ef_tau_sw_allen()$total` (see Details).

## Value

A numeric vector of \\\varepsilon_a\\ \[-\] with the length and `dim` of
`tau_sw`. Values above 1 (which occur only for \\\tau\_{sw} \<
0.0022776\\) are returned unchanged and are reported by the diagnostics
of the stage (`EF_RAD_ATM_EMISSIVITY_GT1`).

## Details

\$\$\varepsilon_a = 0.85 \left(-\ln \tau\_{sw}\right)^{0.09}\$\$ The
emissivity decreases as the transmissivity increases. The input must be
the **modelled clear-sky** transmissivity, not an effective
transmissivity derived from measured radiation, unless this is decided
explicitly (decision RC-13): the empirical relation was proposed for
clear skies.

`tau_sw` must be numeric and non-empty. Values outside (0, 1) (where the
logarithm is undefined or the emissivity is zero) or infinite values
raise `earthflux_domain_error` (also `earthflux_input_error`). Missing
values propagate.

## Verification status

`VERIFICADA (SEBAL-Idaho 2002)`. Form and coefficients (0.85, 0.09) are
those of Waters et al. (2002), p. 23, Eq. 22: the empirical form of
Bastiaanssen (1995) refitted "using data from alfalfa fields in Idaho"
(the original coefficients for western Egypt were 1.08 and 0.265). In
the manual the transmissivity is that of Eq. 11
([`ef_tau_sw_elevation()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md));
its use with the partitioned transmissivity of
[`ef_tau_sw_allen()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)
is not covered by the manual (`CANDIDATA`). The range of
transmissivities over which the coefficients were fitted is not given.
The cross-check with Allen et al. (2007) remains desirable but is no
longer blocking. Formulations in terms of vapour pressure and air
temperature (e.g. Brutsaert) are an open alternative (decision RC-13).

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

## See also

Other radiation functions:
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md),
[`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md),
[`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md),
[`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md),
[`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md),
[`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)

## Examples

``` r
ef_atm_emissivity(c(0.5, 0.7, 0.75, 0.9))
#> [1] 0.8224192 0.7746820 0.7598381 0.6941606
```
