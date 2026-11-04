# Regionalization by global linear regression (C2)

Describes configuration C2-OLS for
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md)
and
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md)
(dev/specs/gwr-forcing.md sections 5.2 and 5.4): ordinary least squares
on the same covariates (all layers of `covariates`) as GWR,
\$\$\hat\beta = (X^\top X)^{-1} X^\top y, \qquad \hat y_g = x_g^\top
\hat\beta,\$\$ the limit of GWR for an infinite bandwidth. It separates
the contribution of the covariates from that of the non-stationarity.

## Usage

``` r
ef_method_ols()
```

## Value

A list of class `"earthflux_regionalization_method"` with
`method = "global_ols"`.

## Details

Diagnostics use the definitions of the GWR core with tr(S) = p: AICc of
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md)
and leave-one-out residuals \\e_i/(1 - h\_{ii})\\.

## Verification status

Ordinary least squares is standard; its use as the C2 reference is a
design choice (GW-21). It reproduces the global reference of
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md)
(tested).

## See also

Other spatial regionalization functions:
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md),
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md),
[`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md),
[`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md),
[`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md),
[`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md),
[`ef_predict_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_predict_control.md),
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md),
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md),
[`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)

## Examples

``` r
ef_method_ols()
#> <earthflux_regionalization_method> global_ols 
#> global ordinary least squares on all covariates
```
