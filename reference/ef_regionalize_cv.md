# Cross-validate a regionalization at the stations

Out-of-fold predictions at the stations for one variable and method
(dev/specs/gwr-forcing.md section 8.2): for every target time and fold,
the method is fitted with the stations of the other folds and predicted
at the stations of the fold, with their own covariates and coordinates.
Inputs, QC policy and exclusions are those of
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md),
so the same call with another `method` gives paired predictions over the
same folds (configurations C1, C2 and C3 of dev/VALIDATION_PLAN.md
section 2.2).

## Usage

``` r
ef_regionalize_cv(
  data,
  variable,
  covariates,
  method,
  folds,
  use_qc,
  surface_covariates,
  reselect_bandwidth = TRUE,
  grid = NULL,
  exclude = NULL,
  station_covariates = NULL
)
```

## Arguments

- data:

  The regionalization input: a data frame with the columns `station_id`,
  `lon`, `lat` (decimal degrees, WGS84), `target_time` (POSIXct UTC),
  `variable`, `value` (unit of the contract), `qc_status` (`"ok"`,
  `"warning"`, `"excluded"`) and, optionally, `elevation` \[m\],
  `period_seconds` and `reference` (required for `etr_inst` and
  `etr_24`), as in dev/specs/weather-forcing.md section 7.2; or the
  result of
  [`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md)
  for a variable observed at the stations.

- variable:

  Character, one of `"air_temperature"` (degC), `"vapour_pressure"`
  (kPa), `"wind_speed_2m"` (m s-1), `"clearness"` (-),
  `"solar_radiation"` (W m-2), `"etr_inst"` (mm h-1), `"etr_24"` (mm
  d-1).

- covariates:

  `NULL` or a `SpatRaster` on the working grid, one named layer per
  covariate (e.g. `elevation` \[m\], `distance_to_coast` \[km\]). GWR
  and the global regression use all its layers; the lapse-rate variant
  of C1 uses `elevation`. Cells where any layer is `NA` are outside the
  domain for every method (value `NA`, flag `EF_INPUT_NA`), so that the
  surfaces of C1, C2 and C3 cover the same cells.

- method:

  A method object from
  [`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md),
  [`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md),
  [`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md)
  or
  [`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md);
  no default.

- folds:

  The folds of the stations: a whole-number vector named by station
  (e.g. from
  [`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md))
  or a data frame with `station_id` and `fold`. Every station used in a
  fit needs a fold; folds of size one give leave-one-out
  cross-validation with re-selection.

- use_qc:

  Character, no default: the QC statuses that enter the fits, among
  `"ok"` and `"warning"` (`"excluded"` never does). Recorded in the
  provenance.

- surface_covariates:

  Character, no default when the method uses covariates: the covariates
  derived from the surface state (e.g. `"lst"`, `"ndvi"`), or
  `character(0)` if none. Decision GW-07 is open: using them is allowed
  only when declared here, and they raise `EF_GWR_SURFACE_COVARIATE`
  (dev/specs/gwr-forcing.md section 2.7).

- reselect_bandwidth:

  Logical. `TRUE` (default of the specification): the GWR bandwidth
  (method with `criterion`) or the IDW power (several values) is
  selected again inside each training set (nested). `FALSE`: selected
  once per target time with all the stations and kept fixed in the
  folds; the CV is then conditional on that selection (optimistic), as
  recorded in the provenance. Without a selection it has no effect.

- grid:

  `NULL` or a `SpatRaster` template of the working grid (geometry only);
  required when `covariates` is `NULL`, and with the same geometry
  otherwise.

- exclude:

  `NULL` or a data frame with columns `station_id` and `reason`:
  stations excluded by the user.

- station_covariates:

  `NULL` or a data frame with `station_id` and the covariates used, to
  take the covariates at the stations from a table (e.g. elevation of
  the metadata) instead of extracting them from the rasters
  (dev/specs/gwr-forcing.md section 2.2, GW-10).

## Value

An object of class `c("earthflux_regionalization_cv", "list")` with:

- `predictions`: long data frame with one row per target time and
  station used: `station_id`, `fold`, `variable`, `target_time`,
  `observed`, `predicted`, `residual` (observed - predicted), `method`,
  `status` (`"ok"`, `"failed"`: the fold could not be fitted, with
  `reason`; or `"representative_station"`: C1 does not evaluate its own
  station), `reason`, `n_train` (stations of the training set), `tuning`
  (GWR bandwidth \[m or neighbours\] or IDW power used in the fold; `NA`
  otherwise) and `flag_word` (flag word of the prediction at the
  station, bits of
  [`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md));

- `folds`: data frame `station_id`, `fold`;

- `station_table`: stations used and excluded per target time, with the
  reason;

- `variable`, `method`, `method_settings`, `reselect_bandwidth`;

- `flags`, `provenance` (selection rule, folds rule, QC policy, number
  of folds and of failed folds, execution plan, versions,
  `flags_evaluated`).
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
  `predictions`.

## Details

Failed folds (e.g. too few training stations for GWR,
`earthflux_gwr_insufficient_stations`, or no feasible bandwidth) are
reported in `predictions` with `status = "failed"` and the condition in
`reason`; they are never dropped silently. The metrics (RMSE, MAE, bias)
are computed by the validation module from this table.

## Parallel processing

The (target time, fold) tasks are evaluated with
[`future.apply::future_lapply()`](https://future.apply.futureverse.org/reference/future_lapply.html)
when the user has set a `future` plan with more than one worker, and
with [`lapply()`](https://rdrr.io/r/base/lapply.html) otherwise; the
result is identical. EarthFlux never sets a plan.

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
[`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)

## Examples

``` r
# \donttest{
grid <- terra::rast(nrows = 20, ncols = 20, xmin = 300000, xmax = 320000,
                    ymin = 6100000, ymax = 6120000, crs = "EPSG:32719")
xy <- terra::crds(grid)
terra::values(grid) <- 200 + 0.02 * (xy[, 1] - 300000)
names(grid) <- "elevation"
sx <- 300500 + 1000 * c(1, 4, 8, 12, 17, 2, 6, 10, 15, 18, 5, 13)
sy <- 6100500 + 1000 * c(2, 15, 6, 11, 3, 9, 18, 1, 16, 8, 12, 5)
ll <- terra::project(cbind(sx, sy), from = "EPSG:32719", to = "EPSG:4326")
z <- 200 + 0.02 * (sx - 300000)
data <- data.frame(
  station_id = sprintf("S%02d", 1:12), lon = ll[, 1], lat = ll[, 2],
  target_time = as.POSIXct("2024-01-15 14:30", tz = "UTC"),
  variable = "air_temperature",
  value = 25 - 0.0065 * z + c(0.2, -0.1, 0.3, 0, -0.2, 0.1, 0, -0.3,
                              0.2, 0.1, -0.1, 0),
  qc_status = "ok"
)
folds <- ef_spatial_folds(data.frame(station_id = data$station_id,
                                     x = sx, y = sy), block_size = 10000)
cv <- ef_regionalize_cv(data, "air_temperature", covariates = grid,
                        method = ef_method_ols(), folds = folds,
                        use_qc = "ok", surface_covariates = character(0))
head(as.data.frame(cv))
#>   station_id fold        variable         target_time observed predicted
#> 1        S01    1 air_temperature 2024-01-15 14:30:00   23.705  23.41521
#> 2        S03    1 air_temperature 2024-01-15 14:30:00   22.895  22.55799
#> 3        S06    1 air_temperature 2024-01-15 14:30:00   23.475  23.29275
#> 4        S08    1 air_temperature 2024-01-15 14:30:00   22.035  22.31307
#> 5        S05    2 air_temperature 2024-01-15 14:30:00   21.225  21.44684
#> 6        S10    2 air_temperature 2024-01-15 14:30:00   21.395  21.31569
#>      residual     method status reason n_train tuning flag_word
#> 1  0.28979118 global_ols     ok   <NA>       8     NA        10
#> 2  0.33700696 global_ols     ok   <NA>       8     NA         8
#> 3  0.18225058 global_ols     ok   <NA>       8     NA        10
#> 4 -0.27807425 global_ols     ok   <NA>       8     NA         8
#> 5 -0.22183908 global_ols     ok   <NA>       9     NA        10
#> 6  0.07931034 global_ols     ok   <NA>       9     NA        10
# }
```
