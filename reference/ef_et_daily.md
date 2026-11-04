# Daily actual evapotranspiration

Extrapolates the instantaneous estimate at the satellite overpass time
to the daily actual evapotranspiration \\ETa\_{24}\\ of the image day.

`ef_et_daily()` is the dispatcher of the family: it checks `method` (no
default), forwards the arguments to the function of that method, builds
the diagnostic flags and records the provenance, without any computation
of its own. The methods are:

- `"etrf"`: `ef_et_daily_etrf()`, the reference evapotranspiration
  fraction (ETrF) of the overpass time multiplied by the daily reference
  evapotranspiration (METRIC).

Only `"etrf"` is implemented. The extrapolation by the evaporative
fraction (a future `ef_et_daily_evapfrac()`) and the accumulation over a
period between images (a future `ef_et_period()`) are not available yet:
they need their own specification and verification.

## Usage

``` r
ef_et_daily(etrf, etr_24, reference, method)

ef_et_daily_etrf(etrf, etr_24, reference)
```

## Arguments

- etrf:

  Numeric. Reference evapotranspiration fraction \\ETrF\\ at the
  overpass time \[-\], from
  [`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md).
  Any finite value; negative values are allowed and kept.

- etr_24:

  Numeric. Reference evapotranspiration accumulated over the image day
  \\ETr\_{24}\\ \[mm d-1\]. Must be finite and `>= 0`.

- reference:

  Character. The reference crop of `etr_24`, with no default:
  `"alfalfa"` (tall reference, ETr) or `"grass"` (short reference, ETo).
  It must be the reference used to compute `etrf`.

- method:

  Character. The extrapolation method, with no default (the choice is a
  scientific decision that must be explicit). Currently only `"etrf"`.

## Value

A numeric vector of daily actual evapotranspiration \\ETa\_{24}\\ \[mm
d-1\] with the common length of the inputs. If the inputs include
matrices or arrays (all with the same `dim`), the result keeps that
`dim`. Negative values are returned unchanged (`ef_et_daily_etrf()`).

`ef_et_daily()` returns a list of class `earthflux_daily_et` with
elements `eta_24` (identical to the value of the method function),
`method`, `reference`, `flags` (one record per code that holds
somewhere: `EF_INPUT_NA`, a required input is missing, and
`EF_ET_NEGATIVE`, negative daily ET) and `provenance` (method, method
function, verification status, reference, inputs used, flag codes
evaluated in `flags_evaluated`, EarthFlux version).

## Details

Method `"etrf"` computes \$\$ETa\_{24} = ETrF \cdot ETr\_{24}\$\$ where
\\ETrF\\ is `etrf` and \\ETr\_{24}\\ is `etr_24`, the cumulative
reference evapotranspiration of the image day.

Assumption: the fraction \\ETrF\\ at the overpass time is constant
during the whole day, i.e. the actual evapotranspiration changes in
proportion to the reference evapotranspiration. The assumption is
weakened by the diurnal variation of the ratio (stomatal closure, drying
of the soil surface after irrigation, increasing water stress), by the
overpass time, by clouds after the overpass, by the night hours included
in \\ETr\_{24}\\, by terrain (no slope correction is applied) and by
mixed pixels at about 1 km. A common multiplicative bias of the
instantaneous and daily reference evapotranspiration cancels: the result
depends on the ratio \\ETr\_{24} / ETr\_{inst}\\.

Reference crop: `etrf` and `etr_24` must refer to the same reference
crop (and to the same one as the cold anchor pixel). `reference` does
not change the computation: it makes the choice explicit. The
consistency check between the steps is made by the orchestration layer.

Slope correction: the correction of the daily energy availability in
sloping terrain used by some METRIC implementations is not applied; its
form and source are pending verification.

Negative values of `etrf` give a negative daily evapotranspiration,
returned unchanged and without a warning (never set to zero). With
`etr_24 = 0` the result is zero whatever the sign of `etrf`. The
diagnostic flag `EF_ET_NEGATIVE` is set by `ef_et_daily()` on this
layer.

Missing values (`NA`, `NaN`) in any input propagate to the corresponding
output element, without errors or warnings. Arguments must be numeric
(double or integer) and have length 1 or a common length; length-1
arguments are recycled, arrays with a `dim` are not. A negative `etr_24`
or any infinite value raises an error of class `earthflux_domain_error`
(also `earthflux_input_error`). A missing `method`, `reference` or
method argument raises `earthflux_missing_input`; an unknown `method`,
`earthflux_unknown_method`; an unknown `reference`,
`earthflux_input_error`.

Verification status: method `"etrf"` is `CANDIDATA` (corroborated by
secondary sources, Olmedo et al., 2016, Eq. 4). It is implemented as an
operational definition; its form and equation number in Allen et al.
(2007) have not been verified.

## References

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
[`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md),
[`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md),
[`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md)

## Examples

``` r
# ETrF 0.9 and 8 mm d-1 of alfalfa reference ET: 7.2 mm d-1
eta <- ef_et_daily(etrf = c(0.9, -0.05), etr_24 = 8,
                   reference = "alfalfa", method = "etrf")
eta$eta_24
#> [1]  7.2 -0.4
vapply(eta$flags, `[[`, character(1), "code")
#> [1] "EF_ET_NEGATIVE"

# Same values calling the method directly
ef_et_daily_etrf(etrf = c(0.9, -0.05), etr_24 = 8, reference = "alfalfa")
#> [1]  7.2 -0.4

# Full chain from the energy balance (one pixel)
lambda <- ef_lambda(method = "constant")
le <- ef_latent_heat(rn = 600, g = 60, h = 50)
et_inst <- ef_et_inst(le, lambda)
etrf <- ef_etrf(et_inst, etr_inst = 0.80, reference = "alfalfa")
ef_et_daily(etrf, etr_24 = 8, reference = "alfalfa", method = "etrf")$eta_24
#> [1] 7.2
```
