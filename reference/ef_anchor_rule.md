# Rule of an anchor pixel selection criterion

Builds one rule of the selection criteria of anchor pixels, for example
"NDVI at or above the 95th percentile of the scene" or "albedo between
0.10 and 0.35". Rules are combined in
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md).
A rule states its variable, operator, threshold and whether the
threshold is an absolute value or a percentile of the scene; nothing has
a default value, because no threshold for anchor selection has been
verified against a primary source.

## Usage

``` r
ef_anchor_rule(variable, operator, value, scale)
```

## Arguments

- variable:

  Character. Layer the rule applies to: `"lst"` (surface temperature
  \[K\]), `"ndvi"` \[-\], `"albedo"` \[-\], `"lai"` \[m2 m-2\] or
  `"land_cover"` (integer class codes).

- operator:

  Character. One of `">="`, `">"`, `"<="`, `"<"`, `"between"` (closed
  interval, `value = c(lower, upper)`) or `"in"` (membership in a set of
  class codes; only for `"land_cover"`, which only accepts `"in"`).

- value:

  Numeric. Threshold, in the unit of `variable` when
  `scale = "absolute"`, or a probability in (0, 1\] when
  `scale = "percentile"`. Length 2 for `"between"`, one or more class
  codes for `"in"`, length 1 otherwise. Missing and infinite values are
  not allowed.

- scale:

  Character. `"absolute"` (the threshold is `value`) or `"percentile"`
  (the threshold is the quantile of `variable` at probability `value`,
  computed in the percentile domain and with the quantile type set in
  [`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md)).

## Value

A list of class `earthflux_anchor_rule` with elements `variable`,
`operator`, `value` and `scale`.

## Details

A cell satisfies the rule when `variable` (at the cell) compared with
the threshold by `operator` is `TRUE`; a missing value never satisfies a
rule. Invalid arguments raise errors of class `earthflux_input_error`
(missing arguments: `earthflux_missing_input`; unknown variable,
operator or scale: `earthflux_unknown_method`).

Verification status: the rule is a container; the thresholds a user
passes are not verified by the package. Values observed in the `water`
package (for example NDVI percentile 0.95 and LAI \>= 4 for the cold
anchor) are `CANDIDATA` without a verified primary source
(dev/specs/anchor-pixels.md section 3).

## See also

Other anchor pixel functions:
[`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md),
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md),
[`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md),
[`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md),
[`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md),
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)

## Examples

``` r
# Cold anchor candidates: NDVI at or above the scene's 95th percentile
ef_anchor_rule("ndvi", ">=", 0.95, scale = "percentile")
#> $variable
#> [1] "ndvi"
#> 
#> $operator
#> [1] ">="
#> 
#> $value
#> [1] 0.95
#> 
#> $scale
#> [1] "percentile"
#> 
#> attr(,"class")
#> [1] "earthflux_anchor_rule" "list"                 

# Hot anchor candidates: albedo between 0.10 and 0.35 (absolute)
ef_anchor_rule("albedo", "between", c(0.10, 0.35), scale = "absolute")
#> $variable
#> [1] "albedo"
#> 
#> $operator
#> [1] "between"
#> 
#> $value
#> [1] 0.10 0.35
#> 
#> $scale
#> [1] "absolute"
#> 
#> attr(,"class")
#> [1] "earthflux_anchor_rule" "list"                 
```
