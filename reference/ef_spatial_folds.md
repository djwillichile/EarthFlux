# Spatial block folds of stations

Deterministic folds for spatial block cross-validation
(dev/specs/gwr-forcing.md section 8.2): each station is assigned to the
square tile \$\$(i_x, i_y) = \left(\left\lfloor \frac{x - x_0}{L}
\right\rfloor, \left\lfloor \frac{y - y_0}{L} \right\rfloor\right)\$\$
of side L = `block_size` \[m\] and origin \\(x_0, y_0)\\; every
non-empty tile is a fold, numbered by \\i_y\\ and then \\i_x\\. No
random numbers are used.

## Usage

``` r
ef_spatial_folds(coords, block_size, origin = NULL)
```

## Arguments

- coords:

  Projected station coordinates \[m\]: a numeric matrix or data frame
  with two columns (x, y), optionally with the station identifiers as
  row names; a data frame with columns `station_id`, `x` and `y` (e.g.
  the `station_table` of an `earthflux_surface`); or a `terra`
  `SpatVector` of points (identifiers from its `station_id` attribute,
  if any).

- block_size:

  Positive number: side L of the tiles \[m\], no default (to be
  justified with the scale of the autocorrelation of the residuals,
  decision GW-20).

- origin:

  `NULL` or a numeric vector `c(x0, y0)` \[m\]; `NULL` uses the smallest
  x and y of the stations. Recorded in the result.

## Value

An integer vector of folds, one per station (named by station when
identifiers are available; a station listed more than once must have the
same coordinates), with attributes `block_size`, `origin` and `tile`
(data frame `ix`, `iy`).

## Details

Errors: `earthflux_input_error` (coordinates not numeric or missing,
inconsistent duplicates), `earthflux_domain_error` (non-positive or
infinite block size).

## References

Roberts, D. R., Bahn, V., Ciuti, S., Boyce, M. S., Elith, J.,
Guillera-Arroita, G., Hauenstein, S., Lahoz-Monfort, J. J., Schröder,
B., Thuiller, W., Warton, D. I., Wintle, B. A., Hartig, F., & Dormann,
C. F. (2017). Cross-validation strategies for data with temporal,
spatial, hierarchical, or phylogenetic structure. *Ecography*, 40(8),
913-929. [doi:10.1111/ecog.02881](https://doi.org/10.1111/ecog.02881)
(cited by the specification; not read).

## See also

Other spatial regionalization functions:
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md),
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md),
[`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md),
[`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md),
[`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md),
[`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md),
[`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md),
[`ef_predict_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_predict_control.md),
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md),
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md)

## Examples

``` r
xy <- data.frame(station_id = c("A", "B", "C", "D"),
                 x = c(1000, 4000, 12000, 26000),
                 y = c(2000, 9000, 3000, 21000))
ef_spatial_folds(xy, block_size = 10000)
#> A B C D 
#> 1 1 2 3 
#> attr(,"block_size")
#> [1] 10000
#> attr(,"origin")
#>    x    y 
#> 1000 2000 
#> attr(,"tile")
#>   ix iy
#> 1  0  0
#> 2  0  0
#> 3  1  0
#> 4  2  1
```
