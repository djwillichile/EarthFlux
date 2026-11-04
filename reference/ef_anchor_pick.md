# Final pick of anchor pixels among the candidates

Defines how the anchor pixels of one class are picked among the
candidates that passed the rules and the homogeneity test: a fraction of
the coldest (or hottest) candidates, or a fixed number of them.

## Usage

``` r
ef_anchor_pick(variable, method, value)
```

## Arguments

- variable:

  Character. Layer used to rank the candidates: `"lst"`, `"ndvi"`,
  `"albedo"` or `"lai"` (usually `"lst"`).

- method:

  Character. One of:

  - `"lowest_fraction"`: candidates with `variable <= Q(value)`, the
    quantile of the candidates at probability `value`;

  - `"highest_fraction"`: candidates with `variable >= Q(1 - value)`;

  - `"lowest"`: the `value` candidates with the lowest `variable`;

  - `"highest"`: the `value` candidates with the highest `variable`.

- value:

  Numeric. A fraction in (0, 1\] for the `*_fraction` methods, a whole
  number `>= 1` for `"lowest"` and `"highest"`.

## Value

A list of class `earthflux_anchor_pick` with elements `variable`,
`method` and `value`.

## Details

The pick is deterministic. The `*_fraction` methods keep every candidate
equal to the threshold. `"lowest"` and `"highest"` order the candidates
by `variable` and then by ascending cell number (row by row from the top
left corner); when equal values straddle the limit, the tie is resolved
by cell number and the anchor set is flagged with `EF_ANCHOR_TIES`.

Verification status: the fractions of 0.2 observed in `water` are
`CANDIDATA`; no value is a default here.

## See also

Other anchor pixel functions:
[`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md),
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md),
[`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md),
[`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md),
[`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md),
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)

## Examples

``` r
# The coldest 20 % of the cold candidates
ef_anchor_pick("lst", "lowest_fraction", 0.2)
#> $variable
#> [1] "lst"
#> 
#> $method
#> [1] "lowest_fraction"
#> 
#> $value
#> [1] 0.2
#> 
#> attr(,"class")
#> [1] "earthflux_anchor_pick" "list"                 

# The single hottest hot candidate
ef_anchor_pick("lst", "highest", 1)
#> $variable
#> [1] "lst"
#> 
#> $method
#> [1] "highest"
#> 
#> $value
#> [1] 1
#> 
#> attr(,"class")
#> [1] "earthflux_anchor_pick" "list"                 
```
