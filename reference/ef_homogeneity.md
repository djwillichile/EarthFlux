# Homogeneity criterion of anchor pixels

Defines the spatial homogeneity test applied to anchor pixel candidates:
the dispersion of a variable (usually the surface temperature) in a
square moving window centred on the candidate must not exceed a maximum.
Used in
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md)
and, to audit user-supplied anchors, in
[`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md).

## Usage

``` r
ef_homogeneity(variable, window, stat, max, window_na)
```

## Arguments

- variable:

  Character. Layer whose dispersion is evaluated: `"lst"`, `"ndvi"`,
  `"albedo"` or `"lai"`.

- window:

  Integer. Side of the square window in cells: odd and `>= 3`.

- stat:

  Character. Dispersion statistic; only `"sd"` (sample standard
  deviation, denominator n - 1) is available.

- max:

  Numeric. Maximum dispersion for a homogeneous candidate, in the unit
  of `variable` (K for `"lst"`). Finite and `>= 0`.

- window_na:

  Character. Treatment of windows with missing values or that cross the
  grid border: `"exclude"` (the candidate is not homogeneous unless the
  window is complete) or `"available"` (the statistic uses the available
  cells, at least two; this is the treatment observed in the `water`
  package).

## Value

A list of class `earthflux_homogeneity` with the arguments as elements.

## Details

The window is defined in cells; its size in metres depends on the cell
size of the grid, which
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)
records (with MODIS 1 km cells a 5 x 5 window covers 5 km x 5 km,
against 150 m x 150 m for Landsat; dev/specs/anchor-pixels.md section 4,
Q-AP-03). Anchors whose window is incomplete are flagged with
`EF_ANCHOR_WINDOW_INCOMPLETE`. Errors are of class
`earthflux_input_error` (and subclasses).

Verification status: the window of 5 x 5 cells and the maximum of 1.5 K
observed in `water` are `CANDIDATA`; no value is a default here.

## See also

Other anchor pixel functions:
[`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md),
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md),
[`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md),
[`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md),
[`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md),
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)

## Examples

``` r
ef_homogeneity("lst", window = 3, stat = "sd", max = 0.5,
               window_na = "exclude")
#> $variable
#> [1] "lst"
#> 
#> $window
#> [1] 3
#> 
#> $stat
#> [1] "sd"
#> 
#> $max
#> [1] 0.5
#> 
#> $window_na
#> [1] "exclude"
#> 
#> attr(,"class")
#> [1] "earthflux_homogeneity" "list"                 
```
