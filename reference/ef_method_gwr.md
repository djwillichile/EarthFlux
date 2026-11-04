# Regionalization by geographically weighted regression (C3)

Describes a GWR regionalization for
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md)
and
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md)
(configuration C3, dev/specs/gwr-forcing.md section 5.5): local weighted
least squares on the covariates of the grid, fitted with
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md)
and predicted exactly at every cell with
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md).
The bandwidth is either given (`bandwidth`) or selected for every fit by
`criterion` over `search` with
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md)
(one selection per variable and target time, decision GW-11).

## Usage

``` r
ef_method_gwr(
  kernel,
  adaptive,
  criterion = NULL,
  bandwidth = NULL,
  search = NULL,
  min_neighbours = NULL,
  scale_covariates = TRUE
)
```

## Arguments

- kernel:

  Character, no default (decision GW-04 is open): `"gaussian"`,
  `"exponential"`, `"bisquare"`, `"tricube"` or `"boxcar"`.

- adaptive:

  Logical, no default: `FALSE` for a fixed bandwidth \[m\], `TRUE` for
  an adaptive one (k nearest stations, counting the station itself).

- criterion:

  `NULL` or `"AICc"` / `"CV"`: select the bandwidth of every fit by this
  criterion (no default, decision GW-05). Give exactly one of
  `criterion` and `bandwidth`.

- bandwidth:

  `NULL` or a fixed bandwidth \[m\] (`adaptive = FALSE`) or a whole
  number of neighbours k (`adaptive = TRUE`), used for every fit.

- search:

  The settings of the selection, from
  [`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md);
  required with `criterion`, `NULL` with `bandwidth`.

- min_neighbours:

  `NULL` or a whole number: minimum number of neighbours (see
  [`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md))
  with a given `bandwidth`; with `criterion` it is set in
  [`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md).

- scale_covariates:

  Logical. Internal scaling of the covariates for numerical conditioning
  (results do not change; see
  [`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md)).

## Value

A list of class `"earthflux_regionalization_method"` with
`method = "gwr"` and the settings.

## Details

Errors: `earthflux_missing_input` (kernel, `adaptive`, or both
`criterion` and `bandwidth` missing; `search` missing with `criterion`),
`earthflux_unknown_method` (kernel or criterion),
`earthflux_input_error` (both `criterion` and `bandwidth`, `search` with
`bandwidth`, `min_neighbours` with `criterion`),
`earthflux_domain_error` (bandwidth not positive, k not a whole number
\>= 1).

## Verification status

See
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md)
and
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md):
estimator and kernels `CANDIDATA (corroborada)`; AICc form `VERIFICADA`
as content of Gollini et al. (2015) and `CANDIDATA (corroborada)` as
EarthFlux definition.

## See also

[`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md),
[`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md),
[`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md)
for the comparison configurations C1 and C2.

Other spatial regionalization functions:
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md),
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md),
[`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md),
[`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md),
[`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md),
[`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md),
[`ef_predict_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_predict_control.md),
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md),
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md),
[`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)

## Examples

``` r
ef_method_gwr("bisquare", adaptive = FALSE, bandwidth = 25000)
#> <earthflux_regionalization_method> gwr 
#> kernel bisquare, fixed bandwidth, given = 25000 m
ef_method_gwr("gaussian", adaptive = TRUE, criterion = "AICc",
              search = ef_gwr_search())
#> <earthflux_regionalization_method> gwr 
#> kernel gaussian, adaptive bandwidth, selected by AICc for every fit
```
