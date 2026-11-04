# Latent heat flux as the residual of the surface energy balance

Computes the instantaneous latent heat flux \\LE\\ at the land surface
as the residual of the surface energy balance: the net radiation minus
the soil heat flux and the sensible heat flux. This is how the METRIC
model obtains the energy used for evapotranspiration at the satellite
overpass time.

## Usage

``` r
ef_latent_heat(rn, g, h)
```

## Arguments

- rn:

  Numeric. Instantaneous net radiation \\R_n\\ \[W m-2\], for example
  from
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md).
  Positive when it supplies energy to the surface. Any finite value.

- g:

  Numeric. Instantaneous soil heat flux \\G\\ \[W m-2\], positive when
  heat flows from the surface into the soil. Any finite value.

- h:

  Numeric. Instantaneous sensible heat flux \\H\\ \[W m-2\], positive
  when heat flows from the surface into the air. Any finite value.

## Value

A numeric vector of latent heat flux \\LE\\ \[W m-2\] with the common
length of the inputs, positive when the surface loses energy by
evaporation. If the inputs include matrices or arrays (all with the same
`dim`), the result keeps that `dim`. Negative values are returned
unchanged (see Details).

## Details

The surface energy balance (FAO-56, chapter 1, Eq. 1) is \\R_n - G -
\lambda ET - H = 0\\, where \\\lambda ET\\ is the latent heat flux.
Solved for the latent heat flux, \$\$LE = R_n - G - H\$\$ with the
FAO-56 sign convention: positive \\R_n\\ supplies energy to the surface,
and positive \\G\\, \\LE\\ and \\H\\ remove energy from it.

Assumptions (FAO-56, chapter 1): only vertical fluxes are considered
(horizontal advection is ignored), the surface is extensive and
homogeneous, and heat storage in the canopy and metabolic energy are
neglected. These assumptions are weaker in mixed pixels of about 1 km.
Because \\LE\\ is a residual, the balance closes by construction in
every pixel and all the errors of \\R_n\\, \\G\\ and \\H\\ are
transferred to \\LE\\.

Negative values are physically possible inputs: \\R_n\\, \\G\\ and \\H\\
may all be negative, and no sign check is made. A negative \\LE\\ (\\H
\> R_n - G\\) is returned unchanged and without a warning; it is never
set to zero. It is flagged downstream with `EF_ET_NEGATIVE` on the
evapotranspiration layers (\\LE \< 0\\ is equivalent to \\ET\_{inst} \<
0\\). An \\LE\\ larger than \\R_n - G\\ (negative \\H\\, possible under
advection) is not modified either.

The function is symmetric in `g` and `h`: swapping them gives the same
result. Use named arguments.

Missing values (`NA`, `NaN`) in any input propagate to the corresponding
output element, without errors or warnings. Arguments must be numeric
(double or integer) and have length 1 or a common length; length-1
arguments are recycled, arrays with a `dim` are not. Infinite values
raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`) that names the argument.

Verification status: `VERIFICADA` as the FAO-56 surface energy balance
(chapter 1, Eq. 1, rearranged). Its use as a residual in METRIC is
corroborated by secondary sources (Olmedo et al., 2016, Eq. 1); the
equation number in Allen et al. (2007) has not been verified.

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

Olmedo, G. F., Ortega-Farias, S., de la Fuente-Saiz, D., Fonseca-Luengo,
D., & Fuentes-Penailillo, F. (2016). water: Tools and functions to
estimate actual evapotranspiration using land surface energy balance
models in R. *The R Journal*, 8(2), 352-369.
[doi:10.32614/RJ-2016-051](https://doi.org/10.32614/RJ-2016-051)

## See also

Other latent heat and evapotranspiration functions:
[`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md),
[`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md),
[`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md)

## Examples

``` r
# Reference case: 600 - 60 - 50 = 490 W m-2
ef_latent_heat(rn = 600, g = 60, h = 50)
#> [1] 490

# H larger than the available energy: LE is negative and kept
ef_latent_heat(rn = 400, g = 80, h = 369)
#> [1] -49

# Several pixels sharing one soil heat flux value (recycled)
ef_latent_heat(rn = c(550, 600, 620), g = 60, h = c(40, 50, 300))
#> [1] 450 490 260
```
