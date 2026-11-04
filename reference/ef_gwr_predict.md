# Predict a geographically weighted regression at new locations

Exact GWR prediction: at each new location g with covariates \\x_g\\,
weights with respect to the stations of the fit (same kernel and
bandwidth; adaptive: the k-th smallest distance from g to the stations),
local WLS fit and \$\$\hat y_g = x_g^\top \hat\beta_g, \qquad
\hat\beta_g = (X^\top W_g X)^{-1} X^\top W_g y\$\$
(dev/specs/gwr-forcing.md sections 3.2 and 6.1). Designed to be called
on blocks of rows (e.g. one raster block at a time): rows are processed
independently, so the result does not depend on how the locations are
split into calls or chunks.

## Usage

``` r
ef_gwr_predict(object, newx, newcoords, chunk_rows = 10000L)
```

## Arguments

- object:

  An `earthflux_gwr` object from
  [`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md).

- newx:

  Numeric matrix (or data frame) of covariates at the new locations, one
  row per location, with the same column names (and units) as the
  covariates of the fit; column order may differ.

- newcoords:

  Numeric matrix with two columns: projected coordinates (x, y) of the
  new locations \[m\], in the CRS of the fit.

- chunk_rows:

  Whole number: rows processed together internally. It only bounds
  memory (about 8 x `chunk_rows` x n bytes per matrix of distances or
  weights) and never changes the result.

## Value

A list with:

- `value`: numeric vector of predictions, in the unit of the response;
  `NA` where a covariate or coordinate is missing or the local design is
  rank deficient;

- `coefficients`: matrix (rows x p) of local coefficients in original
  units (`NA` rows as for `value`);

- `bandwidth`: bandwidth used at each location \[m\];

- `n_nonzero`: integer number of neighbours of each location (stations
  with a non-zero weight for compact kernels, within one bandwidth for
  the gaussian and exponential kernels);

- `flags`: list of `earthflux_flag` records (cell scope; `index` =
  positions in the rows of this call) with the attribute `evaluated`.

## Details

Flags (cell scope, bits of the GWR flag word, dev/specs/flags.md 6.4):

- `EF_INPUT_NA` (bit 0): a covariate or coordinate is missing;

- `EF_GWR_EXTRAPOLATION_COVARIATE` (bit 1): some covariate is outside
  the range \[min, max\] of the stations used in the fit;

- `EF_GWR_EXTRAPOLATION_LOCAL` (bit 2): some covariate is outside the
  range of the stations with a non-zero weight at the location;
  evaluated only for the compact kernels (bisquare, tricube, boxcar);

- `EF_GWR_OUTSIDE_HULL` (bit 3): the location is outside the convex hull
  of the stations used (points on its boundary are inside);

- `EF_GWR_FEW_NEIGHBOURS` (bit 4): fewer neighbours than the
  `min_neighbours` of the fit; the value is kept;

- `EF_GWR_LOCAL_SINGULAR` (bit 5): the local design is rank deficient;
  the value and coefficients are `NA` (never replaced by OLS or a
  neighbour).

The distance to the nearest station (`EF_GWR_FAR_FROM_STATIONS`) needs a
threshold without reference (class II) and is not evaluated.

Errors: `earthflux_input_error` (columns of `newx` not matching the
covariates of the fit, `newcoords` not with two columns, row counts
differing, no rows); `earthflux_domain_error` (infinite values).

## Verification status

As
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md):
estimator `CANDIDATA (corroborada)`; the predictions agree with
[`GWmodel::gwr.predict()`](https://rdrr.io/pkg/GWmodel/man/gwr.predict.html)
to 1e-10 relative in the cross-check tests. The extrapolation conditions
are design definitions without threshold (dev/specs/gwr-forcing.md
section 6.3).

## See also

Other spatial regionalization functions:
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md),
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
[`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md)

## Examples

``` r
coords <- cbind(c(0, 10000, 0, 10000, 20000, 30000),
                c(0, 0, 10000, 10000, 0, 30000))
elev <- cbind(elevation = c(100, 300, 500, 200, 800, 1200))
ta <- c(20.0, 18.9, 17.5, 19.6, 15.4, 13.1)
fit <- ef_gwr_fit(ta, elev, coords, bandwidth = 20000,
                  kernel = "gaussian")
cells <- cbind(c(5000, 15000, 40000), c(5000, 5000, 40000))
pred <- ef_gwr_predict(fit, cbind(elevation = c(250, 600, 1500)), cells)
pred$value
#> [1] 19.14890 16.85496 11.16064
vapply(pred$flags, `[[`, "", "code")
#> [1] "EF_GWR_EXTRAPOLATION_COVARIATE" "EF_GWR_OUTSIDE_HULL"           
#> [3] "EF_GWR_FEW_NEIGHBOURS"         
```
