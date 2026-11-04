# Automatic selection of the cold and hot anchor pixels

Selects the cold and hot anchor pixels used by METRIC to calibrate the
near-surface temperature difference dT as a function of the surface
temperature, following explicit criteria built with
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md).
The selection uses surface variables only (no net radiation, soil heat
flux or weather; stage \[A\] of dev/specs/anchor-pixels.md section 1.3),
is deterministic and returns a complete audit trail: the anchor pixels
and their attributes, one calibration point per class, the computed
thresholds, the funnel of candidates, the flags and the provenance. The
boundary conditions of the anchors are added afterwards by
[`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md).

## Usage

``` r
ef_select_anchors(
  lst,
  ndvi,
  albedo,
  lai = NULL,
  land_cover = NULL,
  qa = NULL,
  elevation = NULL,
  utc_hour = NULL,
  search_area = NULL,
  criteria,
  relax = NULL,
  aggregate,
  cell_size = NULL,
  origin = NULL,
  crs = NULL,
  station = NULL,
  inherited_flags = NULL
)
```

## Arguments

- lst:

  Numeric vector or matrix. Surface temperature \[K\], `> 0`. Defines
  the grid: every other layer must have its length and `dim`.

- ndvi:

  Numeric vector or matrix. NDVI \[-\], in \[-1, 1\].

- albedo:

  Numeric vector or matrix. Broadband surface albedo \[-\], in \[0, 1\].

- lai:

  Numeric vector or matrix or `NULL`. Leaf area index \[m2 m-2\],
  `>= 0`. Required if a criterion uses it.

- land_cover:

  Numeric vector or matrix of class codes, or `NULL`. Required if a
  criterion uses it.

- qa:

  Logical vector or matrix or `NULL`. `TRUE` for usable cells (quality
  control of the surface module); `NULL` means all cells are usable. No
  missing values.

- elevation:

  Numeric vector or matrix or `NULL`. Elevation \[m\]; recorded and
  aggregated for the sensible heat calibration, not used by the
  selection.

- utc_hour:

  Numeric vector or matrix or `NULL`. Overpass time of each cell as a
  decimal UTC hour, in \[0, 24). Recorded; anchors of one class with
  different overpass times are flagged with `EF_ANCHOR_OVERPASS_SPREAD`.

- search_area:

  Logical vector or matrix (one search domain), an ordered list of them
  (staged search, e.g. a radius around a station and then the whole
  scene), or `NULL` (the whole grid). No missing values.

- criteria:

  An
  [`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md)
  object. No default.

- relax:

  `NULL` (no relaxation; the default, decision D-AP-02) or an ordered
  list of further
  [`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md)
  objects, tried in order for a class that has no candidate with
  `criteria`.

- aggregate:

  Character. How the anchor pixels of one class are reduced to the
  single calibration point of that class (decision P0-9): `"mean"`,
  `"median"` or `"none"` (exactly one pixel per class is required). No
  default.

- cell_size:

  Numeric or `NULL`. Side of the (square) cells \[m\]; recorded (window
  size in metres) and needed with `origin`.

- origin:

  Numeric `c(x, y)` or `NULL`. Coordinates of the top left corner of the
  grid in a projected CRS in metres; gives the coordinates of the anchor
  cell centres.

- crs:

  Character or `NULL`. Coordinate reference system of `origin` and
  `station` (recorded only).

- station:

  Numeric `c(x, y)` or `NULL`. Coordinates of the weather station; gives
  the distance from each anchor to the station \[m\]. Needs `origin`.

- inherited_flags:

  `NULL` or a list of cell-scope `earthflux_flag` records evaluated
  upstream on the grid of `lst` (indices are positions of the R layers).
  The codes active at each anchor cell are recorded in
  `pixels$inherited_flags` (inheritance rule, dev/specs/flags.md section
  3.4).

## Value

An object of class `c("earthflux_anchors", "list")` with elements:

- `pixels`: data frame, one row per anchor pixel, ordered by class
  (cold, hot) and cell: `id`, `type`, `cell` (terra cell number), `row`,
  `col`, `x`, `y` \[m\], `lst` \[K\], `ndvi`, `albedo`, `lai`,
  `land_cover`, `elevation` \[m\], `utc_hour` \[h\], `qa`,
  `window_stat`, `window_n_valid`, `window_n`, `window_complete`,
  `lst_rank`, `ndvi_rank`, `albedo_rank`, `lai_rank` (empirical
  cumulative fraction in the grid), `distance_to_station` \[m\] and
  `inherited_flags` (codes separated by `;`).

- `calibration_points`: data frame with exactly one row per class
  (`"cold"`, `"hot"`): `anchor_id`, `type`, `n_pixels`, `aggregate`,
  `lst` \[K\], `ndvi`, `albedo`, `lai`, `elevation` \[m\], `utc_hour`
  \[h\];
  [`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md)
  adds the energy columns.

- `dispersion`: data frame (`type`, `variable`, `n`, `mean`, `median`,
  `sd`, `min`, `max`) of the anchor values of each class.

- `aggregate`, `criteria` (list with `criteria`, `relax` and the
  criteria step used per class), `thresholds` (computed thresholds),
  `search` (domains and where each class was found), `funnel` (cells
  left after each filter, per class, search stage and criteria step),
  `relaxation` (relaxation steps used), `flags` (list of
  `earthflux_flag`), `method` (`"criteria"`), `origin` (`"automatic"`),
  `grid`, `conditions` (`NULL` until
  [`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md)),
  `note` and `provenance`.

## Details

Order of operations (dev/specs/anchor-pixels.md section 5.3): (1)
validation; (2) usable cells (`qa` and the search domain); (3) valid
cells (no missing value in a variable used by the criteria); (4)
percentile domain and computed thresholds; (5) rules of each class (all
must hold); (6) homogeneity; (7) final pick; (8) one calibration point
per class and consistency check; (9) flags and audit trail. Each step
adds a row to the funnel.

Search domains and relaxation: for each class, the search domains are
tried in order and, within each domain, `criteria` and then the steps of
`relax`; the first combination that leaves at least one anchor pixel is
used and recorded. Using a later domain raises
`EF_ANCHOR_SEARCH_EXPANDED`; using a relaxation step raises
`EF_ANCHOR_CRITERIA_RELAXED`, and `EF_ANCHOR_HOMOGENEITY_DROPPED` when
that step has no homogeneity test while `criteria` had one. Nothing is
relaxed without an explicit plan.

Other flags: `EF_ANCHOR_SINGLE_PIXEL` (a class has one pixel),
`EF_ANCHOR_TIES` (a tie at the limit of a `"lowest"`/`"highest"` pick
was resolved by cell number), `EF_ANCHOR_WINDOW_INCOMPLETE` (record
scope: rows of `pixels` whose homogeneity window has missing cells or
crosses the grid border) and `EF_ANCHOR_OVERPASS_SPREAD`.

Errors: no candidate for a class after every domain and step: class
`earthflux_anchor_no_candidates` with fields `type` (`"cold"`, `"hot"`
or `"both"`), `funnel` and `thresholds`; empty percentile domain:
`earthflux_anchor_insufficient_domain`; hot calibration point not hotter
than the cold one: `earthflux_anchor_inverted` (fields `lst_cold`,
`lst_hot`). All three also inherit `earthflux_anchor_error`. Invalid
layers or arguments: `earthflux_input_error`; out-of-domain values:
`earthflux_domain_error`. A small thermal contrast or few candidates are
not errors and are not flagged: their thresholds have no reference
(class II codes `EF_ANCHOR_CONTRAST_LOW`, `EF_ANCHOR_FEW_CANDIDATES`).

The selection uses no random numbers and does not modify the random
number generator. Selection on the surface temperature referred to an
elevation datum (decision D-AP-07) is not available: `lst` is used as
given.

Verification status: the procedure is a transparent container for
user-stated criteria; no criterion is `VERIFICADA`
(dev/specs/anchor-pixels.md sections 3 and 10).

## References

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

Allen, R. G., Burnett, B., Kramber, W., Huntington, J., Kjaersgaard, J.,
Kilic, A., Kelly, C., & Trezza, R. (2013). Automated calibration of the
METRIC-Landsat evapotranspiration process. *Journal of the American
Water Resources Association*, 49(3), 563-576.
[doi:10.1111/jawr.12056](https://doi.org/10.1111/jawr.12056)

## See also

Other anchor pixel functions:
[`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md),
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md),
[`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md),
[`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md),
[`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md),
[`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md)

## Examples

``` r
# A 1 x 12 transect (test case P1 of dev/specs/anchor-pixels.md)
lst <- c(321, 324, 318, 312, 309, 306, 303, 299, 297, 296, 291, 305)
ndvi <- c(0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90,
          -0.20, NA)
lai <- c(0.1, 0.2, 0.3, 0.8, 1.2, 1.8, 2.5, 4.0, 4.5, 5.0, 0.0, 1.0)
albedo <- c(0.25, 0.40, 0.22, 0.20, 0.19, 0.19, 0.18, 0.18, 0.19, 0.20,
            0.06, 0.20)
crit <- ef_anchor_criteria(
  cold = list(ef_anchor_rule("ndvi", ">=", 0.75, scale = "percentile"),
              ef_anchor_rule("lai", ">=", 4, scale = "absolute")),
  hot = list(ef_anchor_rule("ndvi", "<=", 0.2, scale = "percentile"),
             ef_anchor_rule("ndvi", ">", 0, scale = "absolute"),
             ef_anchor_rule("albedo", "between", c(0.10, 0.35),
                            scale = "absolute")),
  homogeneity = NULL,
  select = list(cold = ef_anchor_pick("lst", "lowest_fraction", 0.5),
                hot = ef_anchor_pick("lst", "highest_fraction", 0.5)),
  percentile_domain = "land", quantile_type = 7,
  source = "test parameters (dev/specs/anchor-pixels.md 7.1)",
  status = "CANDIDATA"
)
anchors <- ef_select_anchors(lst, ndvi, albedo, lai = lai,
                             criteria = crit, aggregate = "mean")
anchors
#> <earthflux_anchors>
#> Method: criteria (origin: automatic); aggregate: mean
#> Criteria status: CANDIDATA
#>   cold   2 pixel(s), Ts = 296.50 K
#>   hot    1 pixel(s), Ts = 321.00 K
#> Ts hot - Ts cold = 24.50 K
#> Boundary conditions: not set (see ef_anchor_conditions())
#> Flags: EF_ANCHOR_SINGLE_PIXEL (info) 
anchors$calibration_points
#>   anchor_id type n_pixels aggregate   lst ndvi albedo  lai elevation utc_hour
#> 1      cold cold        2      mean 296.5 0.85  0.195 4.75        NA       NA
#> 2       hot  hot        1      mean 321.0 0.10  0.250 0.10        NA       NA
```
