# Incoming shortwave radiation on the pixel plane

Computes the instantaneous incoming (downwelling) shortwave radiation
\\R\_{s\downarrow}\\ on the plane of each pixel (horizontal or tilted)
at the overpass time, separating the direct beam, the diffuse sky
radiation and the radiation reflected by the surrounding ground. The
`total` element is the `rs_in` argument of
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md).

`ef_rs_in()` is the dispatcher of the family; it only forwards its
arguments to the method chosen with `method`, which has no default:

- `ef_rs_in_modelled()` (`method = "modelled"`): clear-sky radiation
  from the extraterrestrial irradiance and the partitioned
  transmissivity of
  [`ef_tau_sw_allen()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md);

- `ef_rs_in_measured()` (`method = "measured"`): measured (or
  regionalised) global radiation on the horizontal, split with a given
  diffuse fraction.

Both methods project the horizontal components onto the pixel plane in
the same way.

## Usage

``` r
ef_rs_in(..., method)

ef_rs_in_modelled(
  cos_zenith,
  cos_incidence,
  inv_distance,
  tau_beam,
  tau_diffuse,
  slope,
  ground_albedo = NULL
)

ef_rs_in_measured(
  rs_horizontal,
  diffuse_fraction,
  cos_zenith,
  cos_incidence,
  slope,
  ground_albedo = NULL
)
```

## Arguments

- ...:

  Arguments passed to the method selected by `method`.

- method:

  Character, no default. `"modelled"` or `"measured"`.

- cos_zenith:

  Numeric. Cosine of the solar zenith angle on the horizontal
  \\\cos\theta_h\\ \[-\], in (0, 1\] (`ef_solar_geometry()$cos_zenith`).

- cos_incidence:

  Numeric. Cosine of the solar incidence angle on the pixel plane
  \\\cos\theta\_{rel}\\ \[-\], in \[-1, 1\]
  (`ef_solar_geometry()$cos_incidence`, computed with the same `slope`).

- inv_distance:

  Numeric. Inverse relative Earth-Sun distance \\d_r\\ \[-\], `> 0`
  (`ef_solar_geometry()$inv_distance`).

- tau_beam, tau_diffuse:

  Numeric. Direct-beam and diffuse clear-sky transmissivities on the
  horizontal \[-\] (`ef_tau_sw_allen()$beam` and `$diffuse`), each in
  \[0, 1), with a sum in (0, 1).

- slope:

  Numeric, no default. Slope of the pixel plane \[rad\], in \[0, pi/2\];
  the same slope used to compute `cos_incidence` (0 for a horizontal
  plane).

- ground_albedo:

  Numeric or `NULL`. Albedo of the ground seen by the tilted plane
  \\\rho_g\\ \[-\], in \[0, 1\] (for example the albedo of the pixel
  itself or a neighbourhood mean, decision RC-09). Required when any
  `slope > 0`; may be `NULL` on flat terrain, where the reflected term
  is zero.

- rs_horizontal:

  Numeric. Measured or regionalised global shortwave radiation on the
  horizontal at the overpass time \[W m-2\], `>= 0`.

- diffuse_fraction:

  Numeric, no default. Diffuse fraction of `rs_horizontal` \\k_d\\
  \[-\], in \[0, 1\]. How to obtain it (clear-sky model, decomposition
  model or hybrid) is an open decision (RC-10).

## Value

A plain list (no class) of numeric vectors with the common length and
`dim` of the inputs:

- `total`: \\R\_{s\downarrow}\\ on the pixel plane \[W m-2\];

- `beam`, `diffuse`, `reflected`: its direct-beam, diffuse-sky and
  ground-reflected components \[W m-2\];

- `diffuse_fraction` (`ef_rs_in_modelled()` only): diffuse fraction of
  the clear-sky radiation on the horizontal, \\\tau_d / (\tau_b +
  \tau_d)\\ \[-\].

`ef_rs_in()` returns exactly the value of the selected method.

## Details

Components on the horizontal:

- `ef_rs_in_modelled()`: \\R\_{a,h} = G\_{sc} d_r \cos\theta_h\\,
  \\R\_{b,h} = \tau_b R\_{a,h}\\ and \\R\_{d,h} = \tau_d R\_{a,h}\\,
  with \\G\_{sc}\\ the solar constant of the package (1366.67 W m-2,
  FAO-56 Eq. 21; its adoption for METRIC is `CANDIDATA`, decision
  RC-06);

- `ef_rs_in_measured()`: \\R\_{b,h} = (1 - k_d) R\_{s,meas}\\ and
  \\R\_{d,h} = k_d R\_{s,meas}\\.

Projection onto the plane of slope \\s\\ (isotropic diffuse sky and
isotropic ground reflection, unobstructed horizon): \$\$R\_{b,s} =
R\_{b,h} \frac{\max(\cos\theta\_{rel}, 0)}{\cos\theta_h}, \quad R\_{d,s}
= R\_{d,h} \frac{1 + \cos s}{2}, \quad R\_{r,s} = \rho_g (R\_{b,h} +
R\_{d,h}) \frac{1 - \cos s}{2}\$\$ and \\R\_{s\downarrow} = R\_{b,s} +
R\_{d,s} + R\_{r,s}\\. In the modelled path \\R\_{b,s} = \tau_b G\_{sc}
d_r \max(\cos\theta\_{rel}, 0)\\. On flat terrain (\\s = 0\\,
\\\cos\theta\_{rel} = \cos\theta_h\\) the modelled radiation reduces to
\\G\_{sc} d_r \cos\theta_h \tau\_{sw}\\.

A plane facing away from the sun (\\\cos\theta\_{rel} \le 0\\) receives
no direct beam: \\\max(\cos\theta\_{rel}, 0)\\ is the physical
definition of the beam irradiance on that plane, not a correction, and
is reported by the diagnostics of the stage (`EF_RAD_SELF_SHADED`). The
resulting radiation is never truncated.

Unlike a common simplified form, \\G\_{sc} d_r \cos\theta\_{rel}
\tau\_{sw}\\, the diffuse component is not projected as if it were
direct beam; on slopes the two forms differ by tens to hundreds of W
m-2.

Assumptions: clear sky (modelled path); no cast shadows and no reduction
of the sky view by the surrounding relief; isotropic diffuse sky and
ground reflection; instantaneous values at the overpass time. Measured
radiation is usually a 10-60 min mean and must be interpolated to the
overpass time upstream.

Arguments must be numeric and have length 1 or a common length; length-1
arguments are recycled, matrix or array arguments must share their
`dim`. Values outside the domains above (including `cos_zenith <= 0`,
sun below the horizon) or infinite values raise `earthflux_domain_error`
(also `earthflux_input_error`). `ground_albedo = NULL` with a positive
slope raises `earthflux_missing_input`. A missing or unknown `method`
raises `earthflux_missing_input` or `earthflux_unknown_method`. Missing
values propagate arithmetically to the outputs that depend on them, and
always to `total`.

## Verification status

`CANDIDATA`. The flat-terrain modelled form is the one observed in the
`water` package (v1.0), attributed there to Allen et al. (2007) (not
verified). The isotropic projection onto tilted planes is the standard
form of solar engineering texts (Duffie and Beckman; isotropic model
attributed to Liu and Jordan; neither verified); whether Allen, Trezza
and Tasumi (2006) prescribe an anisotropic diffuse term is `TODO`
(decision RC-09). In the measured path, the source of the diffuse
fraction is `TODO` (decision RC-10). The solar constant is `CANDIDATA`
(RC-06).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

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
[`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md),
[`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md),
[`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)

## Examples

``` r
deg <- pi / 180
# Clear-sky radiation on a horizontal pixel and on a 20 degree
# north-facing slope (southern hemisphere)
geo <- ef_solar_geometry(doy = 15, utc_hour = 15.5, lat = -35 * deg,
                         lon = -71 * deg, slope = c(0, 20) * deg,
                         aspect = 0)
tau <- ef_tau_sw_allen(geo$cos_zenith, ef_air_pressure(500),
                       vapour_pressure = 1.2, turbidity = 1)
rs <- ef_rs_in(
  cos_zenith = geo$cos_zenith, cos_incidence = geo$cos_incidence,
  inv_distance = geo$inv_distance, tau_beam = tau$beam,
  tau_diffuse = tau$diffuse, slope = c(0, 20) * deg,
  ground_albedo = 0.2, method = "modelled"
)
rs$total
#> [1] 1001.852 1016.459

# Measured global radiation on the horizontal, projected to the slopes
ef_rs_in_measured(
  rs_horizontal = 950, diffuse_fraction = 0.15,
  cos_zenith = geo$cos_zenith, cos_incidence = geo$cos_incidence,
  slope = c(0, 20) * deg, ground_albedo = 0.2
)$total
#> [1] 950.0000 963.7109
```
