# Reference evapotranspiration fraction

Computes the reference evapotranspiration fraction \\ETrF\\ at the
satellite overpass time: the ratio of the instantaneous actual
evapotranspiration to the reference evapotranspiration at the same
instant. In METRIC this fraction is assumed constant during the day and
is used to extrapolate the instantaneous estimate to a daily value (see
[`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md)).

## Usage

``` r
ef_etrf(et_inst, etr_inst, reference)
```

## Arguments

- et_inst:

  Numeric. Instantaneous evapotranspiration \\ET\_{inst}\\ \[mm h-1\],
  for example from
  [`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md).
  Any finite value; negative values are allowed and kept.

- etr_inst:

  Numeric. Reference evapotranspiration at the same instant (the
  overpass time of each pixel) \[mm h-1\]. Must be finite and `> 0`.

- reference:

  Character. The reference crop of `etr_inst`, with no default:
  `"alfalfa"` (tall reference, ETr) or `"grass"` (short reference, ETo).
  An ETrF is defined only with respect to one reference; see Details.

## Value

A numeric vector of the reference evapotranspiration fraction \\ETrF\\
\[-\] with the common length of the inputs. If the inputs include
matrices or arrays (all with the same `dim`), the result keeps that
`dim`. Values are returned unchanged, whatever their sign or magnitude.

## Details

The fraction is \$\$ETrF = \frac{ET\_{inst}}{ETr\_{inst}}\$\$ where
\\ET\_{inst}\\ is `et_inst` and \\ETr\_{inst}\\ is `etr_inst`, both in
mm h-1 at the same instant.

Reference crop: an ETrF based on alfalfa is not comparable with one
based on grass. `etr_inst`, the daily reference evapotranspiration used
by
[`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md)
and the boundary condition of the cold anchor pixel must all refer to
the same reference crop; otherwise the daily estimate is wrong without
any arithmetic error. `reference` does not change the computation: it
makes the choice explicit. The consistency check between the steps is
made by the orchestration layer.

The temporal basis of `etr_inst` (instantaneous rate or hourly reference
ET of a period centred on the overpass time) is defined by the
meteorological forcing and must be recorded in the provenance.

Negative values of `et_inst` give a negative ETrF, returned unchanged
and without a warning. No plausible range of ETrF is checked or flagged:
the upper limit has no verified reference yet. Values are never
truncated.

Missing values (`NA`, `NaN`) in any input propagate to the corresponding
output element, without errors or warnings. Arguments must be numeric
(double or integer) and have length 1 or a common length; length-1
arguments are recycled, arrays with a `dim` are not. A non-positive
`etr_inst` (it would give an infinite or meaningless fraction) or any
infinite value raises an error of class `earthflux_domain_error` (also
`earthflux_input_error`). A missing `reference` raises
`earthflux_missing_input`; an unknown one, `earthflux_input_error`.

Verification status: `VERIFICADA (SEBAL-Idaho 2002)`: Waters et al.
(2002), p. 35, Eq. 43 (ETrF = ET_inst / ETr, with ETr the alfalfa
reference ET at the image time, "similar to the well-known crop
coefficient"); also corroborated by Olmedo et al. (2016, Eq. 4). The
manual expects values between 0 and about 1.1 and notes that negative
values can occur (p. 35); no range is checked here (decision ET-D5). The
cross-check with Allen et al. (2007) remains desirable but is no longer
blocking.

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

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

## See also

Other latent heat and evapotranspiration functions:
[`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md),
[`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md),
[`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md)

## Examples

``` r
# 0.72 mm h-1 against an alfalfa reference of 0.80 mm h-1: 0.9
ef_etrf(et_inst = 0.72, etr_inst = 0.80, reference = "alfalfa")
#> [1] 0.9

# Negative and high fractions are returned unchanged
ef_etrf(et_inst = c(-0.072, 0.9), etr_inst = c(0.80, 0.75),
        reference = "alfalfa")
#> [1] -0.09  1.20
```
