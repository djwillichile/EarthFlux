# Regionalization by inverse distance weighting (C2)

Describes configuration C2-IDW for
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md)
and
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md)
(dev/specs/gwr-forcing.md section 5.4): \$\$\hat y(x) = \sum_j \lambda_j
y_j, \qquad \lambda_j = \frac{d(x, j)^{-q}}{\sum_k d(x, k)^{-q}},\$\$
with q = `power`, without covariates; at a location that coincides with
stations, the mean of their values (the limit of the formula).

## Usage

``` r
ef_method_idw(power)
```

## Arguments

- power:

  Positive number, no default (the usual choice 2 is not verified): the
  power q. A vector of several values is a registered grid from which q
  is selected for every fit by leave-one-out cross-validation (smallest
  CV; ties to the smallest q).

## Value

A list of class `"earthflux_regionalization_method"` with
`method = "idw"`.

## Details

Distances are Euclidean in the projected CRS of the grid, divided
internally by the largest distance between the stations of the fit
(which does not change the weights). Errors: `earthflux_missing_input`
(`power`), `earthflux_input_error` (not numeric, duplicated values),
`earthflux_domain_error` (q \<= 0 or infinite).

## Verification status

`CANDIDATA`: Shepard (1968) is cited by the specification but was not
read.

## References

Shepard, D. (1968). A two-dimensional interpolation function for
irregularly-spaced data. *Proceedings of the 1968 23rd ACM National
Conference*, 517-524.
[doi:10.1145/800186.810616](https://doi.org/10.1145/800186.810616)

## See also

Other spatial regionalization functions:
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md),
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md),
[`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md),
[`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md),
[`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md),
[`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md),
[`ef_predict_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_predict_control.md),
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md),
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md),
[`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)

## Examples

``` r
ef_method_idw(2)
#> <earthflux_regionalization_method> idw 
#> power 2
ef_method_idw(c(1, 2, 3))
#> <earthflux_regionalization_method> idw 
#> power selected by LOOCV in {1, 2, 3}
```
