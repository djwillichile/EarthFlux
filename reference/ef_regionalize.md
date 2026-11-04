# Regionalize a station variable over the working grid

Fits a regionalization method to the station values of one variable at
each target time and predicts it exactly at every cell of the working
grid (dev/specs/gwr-forcing.md sections 2, 5 and 6). The method is
chosen with
[`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md)
(C3),
[`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md)
(C1),
[`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md)
or
[`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md)
(C2); all return the same `earthflux_surface`, so that the
configurations of dev/VALIDATION_PLAN.md section 2.2 differ only in
`method`.

Steps: (1) the station coordinates (WGS84 longitude and latitude) are
projected to the CRS of the grid, which must be projected in metres; (2)
the covariates are extracted at the stations from the same rasters (cell
containing the station, no interpolation) or taken from
`station_covariates`; (3) stations whose QC status is not in `use_qc`,
excluded by the user, or with a missing value, coordinate or covariate
are excluded with their reason (nothing is removed silently); (4) one
fit per target time; (5) block-wise prediction with `terra`, writing the
surface and a flag word per target time.

## Usage

``` r
ef_regionalize(
  data,
  variable,
  covariates,
  method,
  use_qc,
  surface_covariates,
  grid = NULL,
  exclude = NULL,
  station_covariates = NULL,
  prediction = ef_predict_control()
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

- prediction:

  Prediction settings from
  [`ef_predict_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_predict_control.md).

## Value

An object of class `c("earthflux_surface", "list")` with:

- `surface`: `SpatRaster`, one layer per target time, named
  `<variable>_<YYYYmmddTHHMMSSZ>`, in the unit of the variable (in
  memory or in `prediction$filename`);

- `flag_word`: integer `SpatRaster`, one layer per target time
  (`flags_<layer>`), with the bits of `flag_bits`: 0 = conditions
  evaluated and none active (dev/specs/flags.md section 6.3);

- `flag_bits`: data frame `bit`, `code`, `severity`, `description`;

- `uncertainty`: `NULL` (prediction variance not delivered, GW-19);

- `variable`, `unit`, `target_time` (POSIXct), `method` (exact name:
  `"gwr"`, `"global_ols"`, `"idw"`, `"station"`, `"station_lapse"`),
  `method_settings` (the method object);

- `diagnostics`: named list, one fitted object per target time
  (`earthflux_gwr`, `earthflux_ols`, `earthflux_idw` or
  `earthflux_station_forcing`);

- `station_table`: one row per target time and station: coordinates
  (WGS84 and projected \[m\]), metadata elevation, QC status, observed
  value, covariates used, `status` (`"used"`/`"excluded"`),
  `exclusion_reason`, `fitted`, `residual`, `loo_fitted` and
  `loo_residual` (C1: error at the other stations; the representative
  station has `NA`);

- `flags`: object and record flags (see Details);

- `provenance`: method and settings, variable, unit, reference, target
  times, covariates and their source, surface covariates, QC policy and
  exclusions, CRS and distance method, prediction settings (mode, block
  rows, number of blocks, chunk rows, file names without directories),
  execution plan (future backend and workers, versions, seed, terra
  options, elapsed time), package versions and `flags` (registry rows,
  bit table, counts per layer and code, policies, flags of each fit) and
  `flags_evaluated`.

## Details

**Flags.** Cell scope, in the flag word (bits of the GWR stage,
dev/specs/flags.md section 6.4): `EF_INPUT_NA` (bit 0, a covariate is
`NA`), `EF_GWR_EXTRAPOLATION_COVARIATE` (1; GWR and OLS),
`EF_GWR_EXTRAPOLATION_LOCAL` (2; GWR with compact kernels),
`EF_GWR_OUTSIDE_HULL` (3; GWR, OLS, IDW), `EF_GWR_FEW_NEIGHBOURS` (4)
and `EF_GWR_LOCAL_SINGULAR` (5; GWR), and `EF_GWR_OUT_OF_DOMAIN` (6,
class III, `critical`): the prediction is outside the physical domain of
the variable (air temperature \<= -273.15 degC, vapour pressure \<= 0,
wind speed, clearness, solar radiation or daily reference ET \< 0,
instantaneous reference ET \<= 0). Out-of-domain values are **kept** and
flagged, never truncated; their consumers reject them with
`earthflux_domain_error`. Counts per layer and code are in
`provenance$flags$counts`. Object scope: `EF_GWR_SINGLE_STATION` (C1),
`EF_GWR_SURFACE_COVARIATE` (declared surface covariates) and the object
flags of the fits (e.g. `EF_GWR_BW_AT_BOUND`); record scope:
`EF_GWR_STATION_EXCLUDED` (rows of `station_table`).

**Errors.** `earthflux_missing_input` (method, `use_qc`,
`surface_covariates`, grid, columns of `data`), `earthflux_input_error`
(duplicated records per station and target time, inconsistent station
locations, geographic or non-metric CRS, undeclared surface covariates,
unknown representative station, files that exist without `overwrite`),
`earthflux_domain_error` (infinite values, longitude or latitude out of
range) and the errors of the methods (e.g.
`earthflux_gwr_insufficient_stations`). Files written by a call that
fails are removed.

## Parallel processing

Sequential by default. If the user has set a `future` plan with more
than one worker (e.g.
`future::plan(future::multisession, workers = 2)`), the fits (one per
target time) and the prediction blocks are evaluated with
[`future.apply::future_lapply()`](https://future.apply.futureverse.org/reference/future_lapply.html)
(`future.seed = TRUE`); EarthFlux never sets a plan nor changes `terra`
or R options. The results are identical for any plan, number of workers
and block size; the plan used is recorded in `provenance$execution`. A
`SpatRaster` keeps a pointer to `terra` memory: save the result with
`filename` or
[`terra::wrap()`](https://rspatial.github.io/terra/reference/wrap.html),
not with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) alone.

## Verification status

Methods: see
[`ef_method_gwr()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_gwr.md)
(C3, `CANDIDATA (corroborada)`),
[`ef_method_ols()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_ols.md),
[`ef_method_idw()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_idw.md)
(`CANDIDATA`) and
[`ef_method_station()`](https://djwillichile.github.io/EarthFlux/reference/ef_method_station.md).
Projection, extraction and block prediction are design choices
(dev/specs/gwr-forcing.md sections 2.1, 2.2, 6.1).

## See also

[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md)
for cross-validation with the same inputs;
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md)
and
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md)
for the numeric core.

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
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md),
[`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)

## Examples

``` r
# \donttest{
# Synthetic 20 x 20 km grid (UTM 19S) with elevation, and 12 stations
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
  elevation = z, target_time = as.POSIXct("2024-01-15 14:30", tz = "UTC"),
  period_seconds = 0L, variable = "air_temperature",
  value = 25 - 0.0065 * z + c(0.2, -0.1, 0.3, 0, -0.2, 0.1, 0, -0.3,
                              0.2, 0.1, -0.1, 0),
  qc_status = "ok", reference = NA_character_
)
ta <- ef_regionalize(data, "air_temperature", covariates = grid,
                     method = ef_method_ols(), use_qc = "ok",
                     surface_covariates = character(0))
ta
#> <earthflux_surface>
#> Variable: air_temperature [degC]; method: global_ols; 1 target time(s)
#> Grid: 20 x 20 cells (in memory)
#> Stations: 12 used, 0 excluded (records over all target times)
#> Cell flags (cells over all layers):
#>   EF_GWR_EXTRAPOLATION_COVARIATE: 40
#>   EF_GWR_OUTSIDE_HULL: 176
ta$surface
#> class       : SpatRaster
#> size        : 20, 20, 1  (nrow, ncol, nlyr)
#> resolution  : 1000, 1000  (x, y)
#> extent      : 300000, 320000, 6100000, 6120000  (xmin, xmax, ymin, ymax)
#> coord. ref. : WGS 84 / UTM zone 19S (EPSG:32719)
#> source(s)   : memory
#> name        : air_temperature_20240115T143000Z
#> min value   :                         21.14085
#> max value   :                        23.690391
# }
```
