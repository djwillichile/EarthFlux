# Latent heat of vaporization

Returns the latent heat of vaporization of water \\\lambda\\, the energy
needed to evaporate a unit mass of water, in J kg-1. The same function
and the same `method` must be used everywhere in the METRIC chain (for
example in the boundary condition of the cold anchor pixel and in the
conversion of latent heat flux to evapotranspiration), so that the chain
is internally consistent.

## Usage

``` r
ef_latent_heat_vaporization(temperature = NULL, method)
```

## Arguments

- temperature:

  Numeric or `NULL`. Air temperature \[K\], required by
  `method = "fao56"`; ignored (and may be omitted) by
  `method = "constant"`. Must be finite and `> 0`.

- method:

  Character. The formulation, with no default: the choice is a
  scientific decision that must be explicit. One of:

  - `"constant"`: FAO-56 constant value, 2.45 MJ kg-1.

  - `"fao56"`: FAO-56 function of the air temperature.

## Value

Latent heat of vaporization \\\lambda\\ \[J kg-1\]. For
`method = "constant"`, a single number. For `method = "fao56"`, a
numeric vector with the length of `temperature`, keeping its `dim` if it
is a matrix or array.

## Details

`method = "constant"` returns \$\$\lambda = 2.45 \times 10^{6}\\
\mathrm{J\\kg^{-1}}\$\$ the value used by FAO-56 in the simplification
of the FAO Penman-Monteith equation, which corresponds to an air
temperature of about 20 degrees Celsius (FAO-56, chapter 3; annex 3).

`method = "fao56"` evaluates FAO-56, annex 3, Eq. 3-1, \$\$\lambda =
\left\[2.501 - 2.361 \times 10^{-3} (T - 273.15)\right\] \times
10^{6}\$\$ where \\T\\ is `temperature` \[K\] (the equation is
formulated with the air temperature in degrees Celsius; the conversion
uses the package constant 273.15 K). FAO-56 defines \\T\\ as the **air**
temperature. At 293.15 K (20 degrees Celsius) it gives 2 453 780 J kg-1.

The surface-temperature form used in METRIC implementations is not
available: its coefficient and its use of the surface temperature are
`CANDIDATA` and must first be verified against Allen, Tasumi and Trezza
(2007).

Missing values in `temperature` propagate to the output without errors
or warnings. A missing or unknown `method` raises an error of class
`earthflux_missing_input` or `earthflux_unknown_method` (both also
`earthflux_input_error`). With `method = "fao56"`, a missing or `NULL`
`temperature` raises `earthflux_missing_input`, and non-positive or
infinite temperatures raise `earthflux_domain_error`. A temperature
range of validity of the equation is not documented by FAO-56 and is not
checked.

Verification status: `"constant"` and `"fao56"` are `VERIFICADA` as
FAO-56 values and equation.

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

## See also

Other shared physical quantities:
[`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md)

## Examples

``` r
# FAO-56 constant value (J kg-1)
ef_latent_heat_vaporization(method = "constant")
#> [1] 2450000

# Function of the air temperature, given in K (20 and 30 degrees C)
ef_latent_heat_vaporization(c(293.15, 303.15), method = "fao56")
#> [1] 2453780 2430170
```
