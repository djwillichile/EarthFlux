# Control of the prediction of a regionalized surface

Settings of the grid prediction of
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md)
(dev/specs/gwr-forcing.md section 6.1): exact prediction at every cell,
computed by blocks of raster rows. None of the settings changes the
values; they only bound memory and choose where the surfaces are
written.

## Usage

``` r
ef_predict_control(
  mode = "exact",
  block_rows = NULL,
  chunk_rows = 10000L,
  filename = "",
  flags_filename = NULL,
  overwrite = FALSE,
  wopt = list()
)
```

## Arguments

- mode:

  Character. Only `"exact"` (one local fit per cell) is implemented; the
  coarse mode of dev/specs/gwr-forcing.md section 6.2 (decision GW-08)
  is not.

- block_rows:

  `NULL` or a whole number: raster rows per block. `NULL` uses the
  blocks proposed by
  [`terra::writeStart()`](https://rspatial.github.io/terra/reference/readwrite.html)
  (split further, when a parallel plan is set, so that every worker
  receives blocks).

- chunk_rows:

  Whole number: cells processed together inside a block by
  [`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md)
  (memory only).

- filename:

  Character. File of the surface; `""` lets `terra` keep it in memory
  (or in its own temporary file when it does not fit).

- flags_filename:

  `NULL` or character: file of the flag word layers. `NULL` derives it
  from `filename` (`<name>_flags.<ext>`), or keeps the layers in memory
  when `filename` is `""`.

- overwrite:

  Logical. Overwrite existing files.

- wopt:

  List of write options passed to
  [`terra::writeStart()`](https://rspatial.github.io/terra/reference/readwrite.html)
  for the surface (e.g. `list(datatype = "FLT8S")`; `terra` writes
  `FLT4S` by default, decision D-PP-05). The flag words are always
  written as `INT4S`.

## Value

A list of class `"earthflux_predict_control"`.

## Details

Errors: `earthflux_unknown_method` (`mode`), `earthflux_input_error`
(types), `earthflux_domain_error` (non-positive sizes).

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
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md),
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md),
[`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)

## Examples

``` r
ef_predict_control()
#> <earthflux_predict_control>
#> Mode: exact; block rows: terra; chunk rows: 10000
#> Surface: memory; flags: memory
ef_predict_control(block_rows = 50,
                   filename = file.path(tempdir(), "ta.tif"),
                   wopt = list(datatype = "FLT8S"))
#> <earthflux_predict_control>
#> Mode: exact; block rows: 50; chunk rows: 10000
#> Surface: /tmp/RtmpO9Cfq7/ta.tif; flags: /tmp/RtmpO9Cfq7/ta_flags.tif
```
