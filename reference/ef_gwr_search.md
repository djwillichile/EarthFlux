# Search settings of the GWR bandwidth selection

Builds the validated list of settings used by
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md)
(dev/specs/gwr-forcing.md section 4.4). The numerical settings of the
fixed-bandwidth search have no default (decision GW-05 is open): a value
left `NULL` is required only when the search needs it, and
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md)
then raises `earthflux_missing_input`.

**Fixed bandwidth \[m\].** The search interval is \[`lower`, `upper`\].
When `lower` is `NULL` it is computed as \\\max_i d\_{i,(m)}\\, the
largest over the stations of the distance to their m-th nearest station
counting themselves (m = `min_neighbours`), multiplied by
`1 + lower_offset` for the bisquare and tricube kernels (whose weight
vanishes at the bandwidth, so feasibility needs b strictly larger). When
`upper` is `NULL` it is `upper_factor` times the largest distance
between stations. The criterion is evaluated on `n_grid` values equally
spaced in log(b), then refined with
[`stats::optimize()`](https://rdrr.io/r/stats/optimize.html) (Brent)
between the grid neighbours of the best feasible grid value, with
absolute tolerance `tol` \[m\]. The global (OLS) model is always
evaluated as the b = Inf reference.

**Adaptive bandwidth (k neighbours).** Exhaustive search over the whole
numbers \[`k_min`, `k_max`\]; by default `k_min` is `min_neighbours` + 1
for the bisquare and tricube kernels and `min_neighbours` otherwise, and
`k_max` is the number of stations.

## Usage

``` r
ef_gwr_search(
  lower = NULL,
  upper = NULL,
  n_grid = NULL,
  tol = NULL,
  min_neighbours = NULL,
  lower_offset = NULL,
  upper_factor = NULL,
  k_min = NULL,
  k_max = NULL,
  method_adaptive = "exhaustive"
)
```

## Arguments

- lower, upper:

  `NULL` or positive numbers: bounds of the fixed bandwidth \[m\].

- n_grid:

  `NULL` or a whole number \>= 3: number of grid values of the
  fixed-bandwidth search.

- tol:

  `NULL` or a positive number: tolerance of the refinement \[m\].

- min_neighbours:

  `NULL` or a whole number: minimum number of neighbours at every
  station for a bandwidth to be feasible (see
  [`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md));
  `NULL` uses the mathematical minimum p + 1.

- lower_offset:

  `NULL` or a number \>= 0 (delta of the automatic lower bound for the
  bisquare and tricube kernels).

- upper_factor:

  `NULL` or a positive number (factor of the largest inter-station
  distance for the automatic upper bound).

- k_min, k_max:

  `NULL` or whole numbers \>= 1: bounds of the adaptive search
  (neighbours).

- method_adaptive:

  Character. Search over k: only `"exhaustive"` is implemented.

## Value

A list of class `earthflux_gwr_search` with the settings.

## Details

These values are search conventions, not scientific constants; they are
recorded in the selection object. Invalid values raise
`earthflux_domain_error` or `earthflux_input_error`.

## See also

Other spatial regionalization functions:
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md),
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md)

## Examples

``` r
ef_gwr_search(n_grid = 30, tol = 1, lower_offset = 0.01, upper_factor = 2)
#> $lower
#> NULL
#> 
#> $upper
#> NULL
#> 
#> $n_grid
#> [1] 30
#> 
#> $tol
#> [1] 1
#> 
#> $min_neighbours
#> NULL
#> 
#> $lower_offset
#> [1] 0.01
#> 
#> $upper_factor
#> [1] 2
#> 
#> $k_min
#> NULL
#> 
#> $k_max
#> NULL
#> 
#> $method_adaptive
#> [1] "exhaustive"
#> 
#> attr(,"class")
#> [1] "earthflux_gwr_search" "list"                
```
