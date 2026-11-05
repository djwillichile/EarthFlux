# Instantaneous evapotranspiration from the latent heat flux

Converts the instantaneous latent heat flux \\LE\\ into the
instantaneous evapotranspiration rate \\ET\_{inst}\\, expressed as a
depth of water per hour. The result is a rate evaluated at the satellite
overpass time, not a depth accumulated over an hour.

## Usage

``` r
ef_et_inst(le, lambda)
```

## Arguments

- le:

  Numeric. Instantaneous latent heat flux \\LE\\ \[W m-2\], for example
  from
  [`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md).
  Any finite value; negative values are allowed and kept.

- lambda:

  Numeric. Latent heat of vaporization \\\lambda\\ \[J kg-1\], from
  [`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md).
  Must lie in \[1e6, 1e7\] J kg-1 (unit guard, see Details). The same
  `lambda` (same `method` of
  [`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md))
  must be used for the cold anchor boundary condition.

## Value

A numeric vector of instantaneous evapotranspiration \\ET\_{inst}\\ \[mm
h-1\] with the common length of the inputs. If the inputs include
matrices or arrays (all with the same `dim`), the result keeps that
`dim`. Negative values (negative `le`) are returned unchanged.

## Details

A depth of water equals the energy per unit area divided by \\\lambda
\rho_w\\ (FAO-56, chapter 3, box 8). For a flux \\LE\\ in W m-2 = J s-1
m-2, the energy accumulated at that rate during one hour is \\3600 LE\\,
so \$\$ET\_{inst} = \frac{1000 \cdot 3600 \cdot LE}{\lambda \rho_w}\$\$
where 1000 is mm m-1, 3600 is s h-1, \\\lambda\\ is `lambda` \[J kg-1\]
and \\\rho_w\\ = 1000 kg m-3 is the density of water (FAO-56, chapter 3,
box 8; internal constant, not an argument). With \\\rho_w\\ = 1000 kg
m-3 this is numerically \\3600 LE / \lambda\\.

The SEBAL Idaho manual writes \\ET\_{inst} = 3600\\ \lambda ET /
\lambda\\ in mm h-1 (Waters et al., 2002, p. 34, Eq. 42), i.e. kg m-2
h-1, which is mm h-1 with \\\rho_w\\ = 1000 kg m-3: numerically
identical to the form above. The notation \\3600 LE / (\lambda \rho_w)\\
attributed to METRIC by secondary sources gives m h-1, not mm h-1, with
\\\lambda\\ in J kg-1; the factor 1000 mm m-1 is written explicitly
here.

Unit guard: a `lambda` given in MJ kg-1 (about 2.45) instead of J kg-1
would silently give an evapotranspiration 1e6 times too large. Values of
`lambda` outside \[1e6, 1e7\] J kg-1 therefore raise an error of class
`earthflux_domain_error`. The interval is a control of units, not a
physical range.

A negative `le` gives a negative evapotranspiration (condensation or an
energy balance in which \\H \> R_n - G\\); it is returned unchanged and
without a warning, never set to zero. The diagnostic flag
`EF_ET_NEGATIVE` is assembled by the orchestration layer.

Missing values (`NA`, `NaN`) in any input propagate to the corresponding
output element, without errors or warnings. Arguments must be numeric
(double or integer) and have length 1 or a common length; length-1
arguments are recycled, arrays with a `dim` are not. Infinite values
raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`).

Verification status: `VERIFICADA` as a unit conversion (FAO-56, chapter
3, box 8 and Eq. 20, plus 3600 s h-1); checked against the FAO-56
equivalences 1 mm d-1 = 2.45 MJ m-2 d-1 (chapter 1, table 1) and 1 W m-2
= 0.035 mm d-1 (chapter 3, table 3); and `VERIFICADA (SEBAL-Idaho 2002)`
(Waters et al., 2002, Eq. 42, see above). Its notation in Allen et al.
(2007) has not been verified (desirable, not blocking).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

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

Other latent heat and evapotranspiration functions:
[`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md),
[`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md),
[`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md)

## Examples

``` r
# 490 W m-2 with the FAO-56 constant lambda: 0.72 mm h-1
ef_et_inst(le = 490, lambda = ef_lambda(method = "constant"))
#> [1] 0.72

# Temperature-dependent lambda (air temperature in K)
ef_et_inst(le = 490, lambda = ef_lambda(303.15, method = "fao56"))
#> [1] 0.7258751

# Negative LE is kept: -0.072 mm h-1
ef_et_inst(le = c(490, -49, NA), lambda = 2.45e6)
#> [1]  0.720 -0.072     NA
```
