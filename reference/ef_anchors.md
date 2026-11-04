# Explicit (user-supplied) anchor pixels

Builds the anchor pixels of the METRIC calibration from cells or
coordinates chosen by the user (manual selection, required by
dev/SCIENTIFIC_SPEC.md section 7). The result has the same class and the
same audit table as
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md):
the attributes of each anchor pixel are extracted from the same layers
and the same statistics are computed, so that a manual selection is
auditable in the same way.

## Usage

``` r
ef_anchors(
  cold,
  hot,
  lst,
  ndvi,
  albedo,
  lai = NULL,
  land_cover = NULL,
  qa = NULL,
  elevation = NULL,
  utc_hour = NULL,
  homogeneity = NULL,
  aggregate,
  cell_size = NULL,
  origin = NULL,
  crs = NULL,
  station = NULL,
  inherited_flags = NULL,
  note = NULL
)
```

## Arguments

- cold, hot:

  Cell numbers (whole numbers, numbered row by row from the top left
  cell, as in terra) or a two-column matrix or data frame of coordinates
  `x`, `y` (cell centres or any point in the cell; needs `origin`,
  `cell_size` and `crs`). At least one per class; no cell may appear
  twice.

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

- homogeneity:

  `NULL` or an
  [`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md)
  object whose window statistics are recorded for each anchor (anchors
  are never discarded).

- aggregate:

  Character. `"mean"`, `"median"` or `"none"`, as in
  [`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md).
  No default.

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

- note:

  Character or `NULL`. Free text (reason for the selection).

## Value

An object of class `c("earthflux_anchors", "list")` with the elements
described in
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md);
`method = "manual"`, `origin = "user"`, `criteria`, `thresholds`,
`search`, `funnel` and `relaxation` are `NULL`, and the flag
`EF_ANCHOR_USER_SUPPLIED` is present.

## Details

Invariant: with the cells of an automatic selection, the same layers,
the same homogeneity object and the same `aggregate`, `pixels` and
`calibration_points` are identical to those of
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md).

Errors: a cell or coordinate outside the grid raises
`earthflux_anchor_outside_grid` (field `index`); a missing surface
temperature at an anchor raises `earthflux_anchor_na_input` (fields
`variable`, `index`); a hot calibration point not hotter than the cold
one raises `earthflux_anchor_inverted`. All also inherit
`earthflux_anchor_error`; the first two also `earthflux_input_error`.

## See also

Other anchor pixel functions:
[`ef_anchor_conditions()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_conditions.md),
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md),
[`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md),
[`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md),
[`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md),
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)

## Examples

``` r
lst <- matrix(c(300, 301, 299, 320,
                298, 300, 302, 322,
                297, 301, 300, 321), nrow = 3, byrow = TRUE)
ndvi <- matrix(c(0.5, 0.5, 0.6, 0.1,
                 0.8, 0.5, 0.4, 0.1,
                 0.9, 0.5, 0.5, 0.1), nrow = 3, byrow = TRUE)
albedo <- matrix(0.2, nrow = 3, ncol = 4)
# Cells are numbered row by row: cell 9 is row 3, column 1
anchors <- ef_anchors(cold = 9, hot = 8, lst = lst, ndvi = ndvi,
                      albedo = albedo, aggregate = "none",
                      note = "irrigated field and fallow plot")
anchors$pixels[, c("type", "cell", "row", "col", "lst")]
#>   type cell row col lst
#> 1 cold    9   3   1 297
#> 2  hot    8   2   4 322
```
