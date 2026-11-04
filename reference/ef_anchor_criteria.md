# Selection criteria of anchor pixels

Gathers, in one explicit and auditable object, every criterion used by
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)
to select the cold and hot anchor pixels of the METRIC calibration: the
rules of each class, the homogeneity test, the final pick, the domain of
the percentiles, the quantile type, and the source and verification
status of the whole set. There are no default criteria (decision
D-AP-01): the values used must be stated, with their source.

## Usage

``` r
ef_anchor_criteria(
  cold,
  hot,
  homogeneity,
  select,
  percentile_domain,
  quantile_type,
  source,
  status
)
```

## Arguments

- cold, hot:

  Lists of
  [`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md)
  objects (at least one each): the rules a cell must satisfy (all of
  them) to be a cold or a hot candidate.

- homogeneity:

  An
  [`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md)
  object applied to the candidates of both classes, or `NULL` (no
  homogeneity test). Must be given explicitly.

- select:

  A list with elements `cold` and `hot`, each an
  [`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md)
  object.

- percentile_domain:

  Character. Cells on which percentile thresholds are computed:
  `"usable"` (usable cells, i.e. allowed by `qa` and the search area,
  with no missing value in a variable used by the criteria) or `"land"`
  (usable cells with NDVI \> 0, so that water does not shift the
  percentiles; the definition observed in `water`, `CANDIDATA`).

- quantile_type:

  Integer in 1-9. Quantile type (Hyndman and Fan, 1996; the same
  definitions as
  [`stats::quantile()`](https://rdrr.io/r/stats/quantile.html)), used
  for percentile rules and the fraction picks. The result depends on it.

- source:

  Character. Where the criteria come from (reference, preset or test
  parameters).

- status:

  Character. Verification status of the criteria: `"TODO"`,
  `"CANDIDATA"` or `"VERIFICADA"`.

## Value

A list of class `earthflux_anchor_criteria` with the arguments as
elements.

## Details

Invalid arguments raise errors of class `earthflux_input_error` (missing
arguments: `earthflux_missing_input`; unknown choices:
`earthflux_unknown_method`).

Verification status: no selection criterion is `VERIFICADA`. The
automated procedures of Allen et al. (2013) and Morton et al. (2013)
were only read in their abstracts; the criteria of the `water` package
are a secondary source (dev/specs/anchor-pixels.md section 3). A
criteria set labelled `"CANDIDATA"` must not become a silent default of
the high-level interface.

## References

Allen, R. G., Burnett, B., Kramber, W., Huntington, J., Kjaersgaard, J.,
Kilic, A., Kelly, C., & Trezza, R. (2013). Automated calibration of the
METRIC-Landsat evapotranspiration process. *Journal of the American
Water Resources Association*, 49(3), 563-576.
[doi:10.1111/jawr.12056](https://doi.org/10.1111/jawr.12056)

Morton, C. G., Huntington, J. L., Pohll, G. M., Allen, R. G., McGwire,
K. C., & Bassett, S. D. (2013). Assessing calibration uncertainty and
automation for estimating evapotranspiration from agricultural areas
using METRIC. *Journal of the American Water Resources Association*,
49(3), 549-562.
[doi:10.1111/jawr.12054](https://doi.org/10.1111/jawr.12054)

## See also

Other anchor pixel functions:
[`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md),
[`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md),
[`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md),
[`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md),
[`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md),
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)

## Examples

``` r
# Test parameters that reproduce the defaults observed in the `water`
# package (CANDIDATA; not defaults of EarthFlux)
crit <- ef_anchor_criteria(
  cold = list(
    ef_anchor_rule("ndvi", ">=", 0.95, scale = "percentile"),
    ef_anchor_rule("lai", ">=", 4, scale = "absolute")
  ),
  hot = list(
    ef_anchor_rule("ndvi", "<=", 0.10, scale = "percentile"),
    ef_anchor_rule("ndvi", ">", 0, scale = "absolute"),
    ef_anchor_rule("albedo", "between", c(0.10, 0.35), scale = "absolute")
  ),
  homogeneity = ef_homogeneity("lst", window = 5, stat = "sd", max = 1.5,
                               window_na = "available"),
  select = list(cold = ef_anchor_pick("lst", "lowest_fraction", 0.2),
                hot = ef_anchor_pick("lst", "highest_fraction", 0.2)),
  percentile_domain = "land",
  quantile_type = 7,
  source = "water v1.0 anchors.control() defaults",
  status = "CANDIDATA"
)
crit
#> <earthflux_anchor_criteria> CANDIDATA - water v1.0 anchors.control() defaults 
#>   cold: ndvi >= p0.95 & lai >= 4; pick: lowest_fraction lst 0.2
#>   hot: ndvi <= p0.1 & ndvi > 0 & albedo between [0.10, 0.35]; pick: highest_fraction lst 0.2
#>   homogeneity: sd(lst) <= 1.5 in 5 x 5 window (available)
#>   percentile domain: land; quantile type: 7
```
