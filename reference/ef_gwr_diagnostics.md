# Diagnostics of a geographically weighted regression

Collects the diagnostics of a fitted GWR model (dev/specs/gwr-forcing.md
section 7.1) in plain R objects: global fit statistics, the global (OLS)
reference, the station table (observed, fitted, residuals, leave-one-out
residuals, \\s\_{ii}\\, local R2, bandwidth, neighbours, condition
number, status), the bandwidth profile and a table of the flags.

## Usage

``` r
ef_gwr_diagnostics(object)
```

## Arguments

- object:

  An `earthflux_gwr` object from
  [`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md).

## Value

A list with:

- `fit`: list of fit statistics (`n`, `p`, `rss`, `sigma_ml`,
  `sigma_edf`, `enp` = tr(S), `tr_sts`, `enp_alt` = 2 tr(S) - tr(S'S),
  `edf` = n - 2 tr(S) + tr(S'S), `aicc`, `aic`, `cv`, `rmse_loo`, `r2`);

- `global_reference`: OLS with the same design;

- `stations`: the station table (see
  [`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md));

- `profile`: the bandwidth profile, or `NULL` for a bandwidth given by
  the user;

- `flags`: data frame with one row per flag record (`code`, `severity`,
  `scope`, `n_flagged`, `n_total`, `description`).

## Details

The local R2 at station i is that of the local WLS fit, \$\$R^2_i = 1 -
\frac{\sum_j w\_{ij} (y_j - x_j^\top\hat\beta_i)^2} {\sum_j w\_{ij}
(y_j - \bar y\_{w,i})^2}, \qquad \bar y\_{w,i} = \frac{\sum_j w\_{ij}
y_j}{\sum_j w\_{ij}},\$\$ identical to
`summary(lm(y ~ x, weights = w_i))$r.squared` (decision GW-13). Other
software reports other conventions; `GWmodel` 2.4-1 `Local_R2` uses the
global fitted values \\\hat y_j = (Sy)\_j\\ and the unweighted mean of
y.

## Verification status

tr(S) in AICc: `VERIFICADA` as content of Gollini et al. (2015, section
6.1). tr(S'S), 2 tr(S) - tr(S'S), edf, sigma_edf, the local R2 and the
condition number: `CANDIDATA` (original definitions in Fotheringham et
al., 2002, and Belsley et al., 1980, not read).

## See also

Other spatial regionalization functions:
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md),
[`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md),
[`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md),
[`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md),
[`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md),
[`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md),
[`ef_predict_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_predict_control.md),
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md),
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md),
[`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)

## Examples

``` r
coords <- cbind(c(0, 10000, 0, 10000, 20000, 30000),
                c(0, 0, 10000, 10000, 0, 30000))
elev <- cbind(elevation = c(100, 300, 500, 200, 800, 1200))
ta <- c(20.0, 18.9, 17.5, 19.6, 15.4, 13.1)
fit <- ef_gwr_fit(ta, elev, coords, bandwidth = 20000,
                  kernel = "gaussian")
d <- ef_gwr_diagnostics(fit)
d$fit$aicc
#> [1] 24.412
d$stations[, c("station_id", "residual", "loo_residual", "s_ii")]
#>   station_id    residual loo_residual      s_ii
#> 1          1 -0.12957310  -0.24821127 0.4779726
#> 2          2  0.08010029   0.10633498 0.2467174
#> 3          3 -0.01165763  -0.01596471 0.2697879
#> 4          4  0.11829798   0.17645165 0.3295729
#> 5          5 -0.12601841  -0.25756623 0.5107340
#> 6          6  0.04086582   0.42300900 0.9033926
```
