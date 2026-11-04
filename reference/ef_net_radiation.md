# Net radiation at the land surface

Computes the instantaneous net radiation \\R_n\\ at the land surface,
i.e. the radiant energy available at the surface for the soil, sensible
and latent heat fluxes, as the balance between the absorbed incoming
shortwave radiation, the incoming longwave radiation, the longwave
radiation emitted by the surface and the part of the incoming longwave
radiation that the surface reflects. This is the surface radiation
balance used in the METRIC energy balance model.

## Usage

``` r
ef_net_radiation(rs_in, albedo, rl_in, rl_out, emissivity)
```

## Arguments

- rs_in:

  Numeric. Incoming (downwelling) shortwave radiation at the surface,
  instantaneous at the satellite overpass time \[W m-2\]. Must be finite
  and `>= 0`.

- albedo:

  Numeric. Broadband surface albedo \[-\]. Must lie in \[0, 1\].

- rl_in:

  Numeric. Incoming (downwelling) longwave radiation at the surface \[W
  m-2\]. Must be finite and `> 0`.

- rl_out:

  Numeric. Longwave radiation **emitted** by the surface \[W m-2\], i.e.
  \\\varepsilon_0 \sigma T_s^4\\. It must not include the reflected
  incoming longwave component, which the function accounts for
  separately. Must be finite and `> 0`.

- emissivity:

  Numeric. Broadband surface emissivity \\\varepsilon_0\\ \[-\]. Must
  lie in (0, 1\]. It must be the same emissivity used to compute
  `rl_out`; ensuring this consistency is the responsibility of the
  caller.

## Value

A numeric vector of net radiation \\R_n\\ \[W m-2\] with the common
length of the inputs. If the inputs include matrices or arrays (all with
the same `dim`), the result keeps that `dim`. Negative values are
physically possible (e.g. at night or over snow) and are returned
unchanged.

## Details

The surface radiation balance is \$\$R_n = (1 - \alpha)
R\_{s\downarrow} + R\_{L\downarrow} - R\_{L\uparrow} - (1 -
\varepsilon_0) R\_{L\downarrow}\$\$ where \\\alpha\\ is `albedo`,
\\R\_{s\downarrow}\\ is `rs_in`, \\R\_{L\downarrow}\\ is `rl_in`,
\\R\_{L\uparrow}\\ is `rl_out` and \\\varepsilon_0\\ is `emissivity`.
The last term is the incoming longwave radiation reflected by the
surface.

Assumptions:

- all fluxes are instantaneous and refer to the same time (the satellite
  overpass);

- the balance is one-dimensional (per pixel or per point), with no
  lateral exchange;

- `emissivity` is the emissivity used to obtain `rl_out` from the
  surface temperature.

If `rl_out` already contains the total upwelling longwave radiation
(emitted plus reflected), for example from a radiometer measurement, the
equivalent call is `emissivity = 1`, which removes the reflected term
and avoids counting it twice.

Missing values (`NA`, `NaN`) in any input propagate to the corresponding
output element, without errors or warnings. Diagnostic flags for missing
inputs are assembled by the orchestration layer, not by this function.

Arguments must be numeric (double or integer) and have length 1 or a
common length; length-1 arguments are recycled. Values outside the
domain (`albedo` outside \[0, 1\], `emissivity` outside (0, 1\],
negative `rs_in`, non-positive `rl_in` or `rl_out`, or any infinite
value) raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`) that names the argument and the number of
offending values. Invalid inputs are expected to be masked or flagged
upstream by quality control; values are never silently corrected.

The form of the equation has been cross-checked against independent
secondary sources; verification against the primary reference (Allen et
al., 2007) is pending.

## References

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

## See also

Other radiation functions:
[`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md),
[`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md),
[`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md),
[`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md),
[`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md),
[`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)

## Examples

``` r
# Single pixel: rl_out = 0.98 * 5.67e-8 * 300^4 (surface at 300 K)
ef_net_radiation(
  rs_in = 800, albedo = 0.20, rl_in = 320,
  rl_out = 450.0846, emissivity = 0.98
)
#> [1] 503.5154

# Several pixels sharing one incoming longwave value (recycled)
ef_net_radiation(
  rs_in = c(750, 800, 820),
  albedo = c(0.15, 0.20, 0.25),
  rl_in = 320,
  rl_out = c(440, 450, 470),
  emissivity = c(0.97, 0.98, 0.96)
)
#> [1] 507.9 503.6 452.2

# rl_out given as total upwelling longwave (emitted + reflected)
ef_net_radiation(
  rs_in = 800, albedo = 0.20, rl_in = 320,
  rl_out = 456.4846, emissivity = 1
)
#> [1] 503.5154
```
