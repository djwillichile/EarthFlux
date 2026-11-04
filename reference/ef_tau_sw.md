# Broadband clear-sky shortwave atmospheric transmissivity

Computes the broadband transmissivity of a clear-sky atmosphere to
shortwave radiation on a horizontal surface, \\\tau\_{sw}\\: the
fraction of the extraterrestrial irradiance that reaches the surface.
`ef_tau_sw()` is the dispatcher of the family: it checks `method` (no
default), forwards the other arguments to the method function, builds
the diagnostic flags and records the provenance. The methods are:

- `ef_tau_sw_allen()` (`method = "allen"`): partitioned form, function
  of the solar zenith angle, the air pressure, the vapour pressure and
  the turbidity, that separates the direct-beam (\\\tau_b\\) and diffuse
  (\\\tau_d\\) components needed for the terrain correction of
  [`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md);

- `ef_tau_sw_elevation()` (`method = "elevation"`): simple linear
  function of elevation, total transmissivity only (no direct/diffuse
  partition).

## Usage

``` r
ef_tau_sw(..., method)

ef_tau_sw_allen(cos_zenith, pressure, vapour_pressure, turbidity)

ef_tau_sw_elevation(elevation)
```

## Arguments

- ...:

  Arguments passed to the method selected by `method`.

- method:

  Character, no default. `"allen"` or `"elevation"`.

- cos_zenith:

  Numeric. Cosine of the solar zenith angle on the horizontal \[-\], in
  (0, 1\] (e.g. `ef_solar_geometry()$cos_zenith`). The air mass does not
  depend on the slope of the pixel, so the horizontal angle is used, not
  the incidence angle on the pixel plane.

- pressure:

  Numeric. Atmospheric pressure \[kPa\], `> 0`: measured, regionalised
  or from
  [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md)
  (decision RC-08).

- vapour_pressure:

  Numeric. Actual vapour pressure of the air \\e_a\\ \[kPa\], `>= 0`.

- turbidity:

  Numeric, no default. Turbidity coefficient \\K_t\\ \[-\], in (0, 1\]:
  1 for clean air and about 0.5 for extremely turbid, dusty or polluted
  air according to the secondary source; not verified. It is not the
  clearness index (measured over extraterrestrial radiation), also often
  written \\K_t\\.

- elevation:

  Numeric. Elevation above sea level \[m\], in (-37 500, 12 500) so that
  the transmissivity lies in (0, 1).

## Value

- `ef_tau_sw_allen()`: a plain list (no class) with the numeric vectors
  `beam` (\\\tau_b\\), `diffuse` (\\\tau_d\\) and `total` (\\\tau\_{sw}
  = \tau_b + \tau_d\\), all dimensionless, with the common length and
  `dim` of the inputs.

- `ef_tau_sw_elevation()`: a numeric vector of \\\tau\_{sw}\\ \[-\] with
  the length and `dim` of `elevation`.

- `ef_tau_sw()`: a list of class `earthflux_sw_transmissivity` with the
  same elements for both methods (type-stable):

  - `total`: \\\tau\_{sw}\\ \[-\], identical to `$total` of
    `ef_tau_sw_allen()` or to the value of `ef_tau_sw_elevation()`;

  - `beam`, `diffuse`: \\\tau_b\\ and \\\tau_d\\ \[-\] when the method
    partitions the transmissivity (`"allen"`), and `NULL` otherwise
    (`"elevation"`); the names are always present;

  - `method`: the method name;

  - `flags`: list of diagnostic flag records, one per code that holds
    somewhere: `EF_INPUT_NA` (a required input is missing; no `EF_RAD_`
    code applies to the transmissivity);

  - `provenance`: list with the method, the method function, its
    verification status, the inputs used, the flag codes evaluated
    (`flags_evaluated`) and the EarthFlux version.

## Details

**Partitioned form** (`ef_tau_sw_allen()`), with \\P\\ = `pressure`
\[kPa\], \\e_a\\ = `vapour_pressure` \[kPa\], \\K_t\\ = `turbidity` and
\\\cos\theta_h\\ = `cos_zenith`: \$\$W = 0.14 e_a P + 2.1\$\$ \$\$\tau_b
= 0.98 \exp\left\[\frac{-0.00146 P}{K_t \cos\theta_h} - 0.075
\left(\frac{W}{\cos\theta_h}\right)^{0.4}\right\]\$\$ \$\$\tau_d =
0.35 - 0.36 \tau_b \\ (\tau_b \ge 0.15), \quad \tau_d = 0.18 + 0.82
\tau_b \\ (\tau_b \< 0.15)\$\$ where \\W\\ is the precipitable water
\[mm\]. The piecewise diffuse term is discontinuous at \\\tau_b = 0.15\\
(0.296 versus 0.303); the branch \\\tau_b \ge 0.15\\ is used at the
break point, as written above.

**Elevation form** (`ef_tau_sw_elevation()`), with \\z\\ = `elevation`
\[m\]: \$\$\tau\_{sw} = 0.75 + 2 \times 10^{-5} z\$\$ It does not depend
on the solar angle nor on the humidity, and gives no direct/diffuse
partition, so it cannot feed the terrain correction of
[`ef_rs_in_modelled()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md);
it is meant for flat terrain, sensitivity analyses and the reproduction
of published cases that use it.

Assumptions: clear sky (consistent with valid MODIS LST pixels); the
coefficients of the partitioned form were derived for conditions in the
United States and for hourly or daily steps, and are applied here to an
instantaneous overpass (transferability to Chile, in particular at high
elevation in the Andes, and validity at low sun angles are `TODO`).

Arguments must be numeric and have length 1 or a common length; length-1
arguments are recycled, matrix or array arguments must share their
`dim`. Values outside the domains above (including `cos_zenith <= 0`,
where the partitioned form is undefined: the sun is below the horizon)
or infinite values raise `earthflux_domain_error` (also
`earthflux_input_error`); they are never corrected. A missing or unknown
`method` raises `earthflux_missing_input` or `earthflux_unknown_method`;
an argument required by the chosen method but not supplied to the
dispatcher raises `earthflux_missing_input`, and one the method does not
accept raises `earthflux_input_error`. Missing values propagate to every
output; the dispatcher reports them with the flag `EF_INPUT_NA`.

## Verification status

`ef_tau_sw_allen()` is `CANDIDATA`: form and coefficients observed in
the `water` package (v1.0), which attributes them to an extended
equation of Allen (1996) based on Majumdar et al. (1972), with
coefficients of ASCE-EWRI (2005); none of these has been verified.
FAO-56 (annex 3, Eqs. 3-18 and 3-20) gives a related form with different
coefficients (0.091 and exponent 0.25 in the beam term, 0.33 in the
diffuse term); the discrepancy is recorded under decision RC-08 and must
be resolved against ASCE-EWRI (2005) and Allen et al. (2007).

`ef_tau_sw_elevation()` has the form of FAO-56 Eq. 37 (annex 3, Eq.
3-13) for the ratio of clear-sky to extraterrestrial radiation, which
FAO-56 declares valid for daily and hourly periods, for elevations below
6000 m and low turbidity; its use as an instantaneous transmissivity in
METRIC is `CANDIDATA`.

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
[`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md),
[`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md)

## Examples

``` r
# Sea level, sun at 35 degrees from the zenith, ea = 1.5 kPa, clean air
tau <- ef_tau_sw(
  cos_zenith = cos(35 * pi / 180), pressure = ef_air_pressure(0),
  vapour_pressure = 1.5, turbidity = 1, method = "allen"
)
tau$total
#> [1] 0.7431396
tau$beam
#> [1] 0.6142806

# Same values through the method function
ef_tau_sw_allen(cos(35 * pi / 180), ef_air_pressure(0), 1.5, 1)$beam
#> [1] 0.6142806

# Elevation form (total only; `beam` and `diffuse` are NULL)
tau_z <- ef_tau_sw(elevation = c(0, 1000, 3000), method = "elevation")
tau_z$total
#> [1] 0.75 0.77 0.81
is.null(tau_z$beam)
#> [1] TRUE
```
