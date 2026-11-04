# Fit a geographically weighted regression

Fits a geographically weighted regression (GWR) of a station variable on
covariates for a given bandwidth: one weighted least squares (WLS) fit
per station, with the hat statistics, leave-one-out (LOO) residuals,
AICc, CV and the global (OLS) reference with the same design. This is
the internal numeric core of the spatial regionalization: inputs are
plain vectors and matrices in a projected coordinate reference system
(metres); no raster object is involved.

The local estimator at regression point \\i\\ is \$\$\hat\beta_i =
(X^\top W_i X)^{-1} X^\top W_i y, \qquad \hat y_i = x_i^\top
\hat\beta_i,\$\$ with \\W_i = \mathrm{diag}(w(d\_{ij}/b_i))\\. Row \\i\\
of the hat matrix is \\s_i = x_i^\top (X^\top W_i X)^{-1} X^\top W_i\\;
the effective number of parameters is \\\mathrm{tr}(S)\\.

## Usage

``` r
ef_gwr_fit(
  y,
  x,
  coords,
  bandwidth,
  kernel,
  adaptive = FALSE,
  min_neighbours = NULL,
  scale_covariates = TRUE,
  station_id = NULL
)
```

## Arguments

- y:

  Numeric vector: the response at each station, in the unit of the
  variable (e.g. degC for air temperature).

- x:

  Numeric matrix (or data frame of numeric columns) with one row per
  station and one column per covariate, with unique column names (e.g.
  `elevation` \[m\]). The intercept is added internally.

- coords:

  Numeric matrix with two columns: projected coordinates (x, y) of the
  stations \[m\]. Distances are Euclidean in this CRS (decision GW-09);
  geographic coordinates (degrees) must be projected first.

- bandwidth:

  Either a number, the fixed bandwidth \[m\] (when `adaptive = FALSE`)
  or the number of neighbours k, a whole number in \[1, n\] (when
  `adaptive = TRUE`); or an `earthflux_gwr_bandwidth` object returned by
  [`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
  whose kernel, bandwidth type, neighbour rule, profile and flags are
  then carried to the fit.

- kernel:

  Character, no default (decision GW-04 is open): one of `"gaussian"`,
  `"exponential"`, `"bisquare"`, `"tricube"`, `"boxcar"`. May be omitted
  when `bandwidth` is an `earthflux_gwr_bandwidth` object; if given it
  must match the object.

- adaptive:

  Logical. `FALSE` for a fixed bandwidth in metres, `TRUE` for an
  adaptive bandwidth given as k nearest stations (the k-th smallest
  distance, counting the regression point itself when it is a station).
  Taken from `bandwidth` when that is an `earthflux_gwr_bandwidth`
  object and `adaptive` is not supplied.

- min_neighbours:

  `NULL` or a whole number: minimum number of neighbours of a regression
  point (stations with a non-zero weight for compact kernels; stations
  within one bandwidth for the gaussian and exponential kernels). `NULL`
  uses the mathematical minimum p + 1 (p coefficients for the local fit
  plus one so that the LOO fit stays identifiable; decision GW-06).
  Larger values are accepted but should be justified by a reference;
  they are recorded in `config`.

- scale_covariates:

  Logical. Whether to centre and scale the covariates internally (by
  their mean and standard deviation over the stations of the fit) to
  condition the local systems. Coefficients are always reported in
  original units and predictions do not change.

- station_id:

  `NULL` or a vector of unique station identifiers. By default
  `names(y)`, `rownames(x)` or the row numbers.

## Value

An object of class
`c("earthflux_gwr", "earthflux_regionalization", "list")` with elements:

- `call`; `variable`, `target_time`, `unit`: `NULL` (set by the
  regionalization orchestrator);

- `stations`: data frame with one row per input station: `station_id`,
  `x`, `y` (coordinates \[m\]), the covariates, `observed`, `fitted`,
  `residual`, `loo_fitted`, `loo_residual`, `s_ii`, `local_r2`,
  `bandwidth_i` \[m\], `n_nonzero`, `kappa`, `rank_ok`, `status`
  (`"used"` or `"excluded"`) and `exclusion_reason`;

- `coefficients`: matrix (stations used x p) of local coefficients in
  original units (`(Intercept)` in the unit of `y`, slopes in unit of
  `y` per unit of each covariate);

- `kernel`; `bandwidth`: `list(type, value, unit, selected_by)`;

- `conventions`: the conventions applied (k including the point itself,
  boxcar support d \<= b, AICc definition, sigma, local R2, LOO,
  distance method, covariate scaling, numerical tolerances);

- `fit`: `n`, `p`, `rss`, `sigma_ml` = sqrt(RSS/n), `sigma_edf` =
  sqrt(RSS/edf), `enp` = tr(S), `tr_sts` = tr(S'S), `enp_alt` = 2
  tr(S) - tr(S'S), `edf` = n - 2 tr(S) + tr(S'S), `aicc`, `aic`
  (uncorrected, report only), `cv`, `rmse_loo` and `r2` (global, 1 -
  RSS/TSS);

- `global_reference`: OLS with the same design (`coefficients`, `rss`,
  `enp` = p, `aicc`, `cv`);

- `profile`, `search`: from the bandwidth selection, `NULL` when the
  bandwidth is given by the user;

- `flags`: list of `earthflux_flag` records (object and station scope);

- `config`: covariates, their units (attribute `"units"` of `x`, if
  any), `min_neighbours` and its source, scaling;

- `model`: what
  [`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md)
  needs (stations used, response, covariates, coordinates, scaling,
  covariate range and convex hull);

- `provenance`: method, package and R versions, `flags_evaluated`.

## Details

**Stations with missing values.** A station with a missing response,
covariate or coordinate is excluded with its reason in `stations` and
the flag `EF_GWR_STATION_EXCLUDED`; nothing is removed silently.
Infinite values raise `earthflux_domain_error`.

**Errors.** n \< p + 3 stations with complete data:
`earthflux_gwr_insufficient_stations` (fields `n`, `p`). A local design
of deficient rank at a station (e.g. only the station itself has a
non-zero weight): `earthflux_gwr_singular_error` (field `stations`). A
covariate constant among the stations, or stations with identical
coordinates and covariates: `earthflux_input_error`. Inconsistent
dimensions: `earthflux_input_error` (the spec's
`earthflux_dimension_error` is not a separate class; dimension errors
are input errors as in the rest of the core). Unknown kernel:
`earthflux_unknown_method`. Fixed bandwidth not positive, or k outside
\[1, n\] or not whole: `earthflux_domain_error`. All `earthflux_gwr_*`
errors inherit `earthflux_gwr_error`.

**Flags.** `EF_GWR_STATION_EXCLUDED` (record), `EF_GWR_FEW_NEIGHBOURS`
(record: stations with fewer than `min_neighbours` neighbours; their LOO
residual is `NA` when the fit interpolates them),
`EF_GWR_AICC_UNDEFINED` (object: n - 2 - tr(S) \<= 0, AICc is `NA`),
plus the object flags of the bandwidth selection when `bandwidth` is an
`earthflux_gwr_bandwidth` object.

## Kernels and conventions

With \\r = d/b_i\\: gaussian \\\exp(-r^2/2)\\, exponential \\\exp(-r)\\,
bisquare \\(1-r^2)^2\\ for \\d \< b_i\\, tricube \\(1-r^3)^3\\ for \\d
\< b_i\\, boxcar 1 for \\d \le b_i\\; 0 otherwise. The boxcar support
\\d \le b\\ (decision GW-03) differs from the strict inequality of Table
1 of Gollini et al. (2015) and matches `GWmodel` 2.4-1. With an adaptive
bandwidth and the bisquare or tricube kernel, the station at distance
exactly \\b_i\\ has weight 0, so at most k - 1 stations (including the
point itself) have a non-zero weight.

## Verification status

Local estimator and kernels: `VERIFICADA` as content of Gollini et al.
(2015; preprint arXiv:1306.0413v2, section 6.1 and Table 1); as
EarthFlux definitions `CANDIDATA (corroborada)`: reproduced to 1e-10
relative by `GWmodel` 2.4-1 in the cross-check tests. The k convention
and the boxcar boundary are EarthFlux conventions (GW-03). AICc: see
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md).
Local R2 (weighted mean of the local fit, GW-13), tr(S'S), 2 tr(S) -
tr(S'S), edf and the condition number: `CANDIDATA`. Original
attributions (Brunsdon et al., 1996; Fotheringham et al., 2002) not
read.

## References

Gollini, I., Lu, B., Charlton, M., Brunsdon, C., & Harris, P. (2015).
GWmodel: An R package for exploring spatial heterogeneity using
geographically weighted models. *Journal of Statistical Software*,
63(17).
[doi:10.18637/jss.v063.i17](https://doi.org/10.18637/jss.v063.i17)

Brunsdon, C., Fotheringham, A. S., & Charlton, M. E. (1996).
Geographically weighted regression: A method for exploring spatial
nonstationarity. *Geographical Analysis*, 28(4), 281-298.
[doi:10.1111/j.1538-4632.1996.tb00936.x](https://doi.org/10.1111/j.1538-4632.1996.tb00936.x)

## See also

[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md)
to select the bandwidth,
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md)
to predict at new locations,
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md).

Other spatial regionalization functions:
[`ef_gwr_bandwidth()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_bandwidth.md),
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md),
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md),
[`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md)

## Examples

``` r
# Six stations (projected coordinates in m), air temperature (degC) and
# elevation (m)
coords <- cbind(c(0, 10000, 0, 10000, 20000, 30000),
                c(0, 0, 10000, 10000, 0, 30000))
elev <- cbind(elevation = c(100, 300, 500, 200, 800, 1200))
ta <- c(20.0, 18.9, 17.5, 19.6, 15.4, 13.1)
fit <- ef_gwr_fit(ta, elev, coords, bandwidth = 20000,
                  kernel = "gaussian")
fit
#> <earthflux_gwr>
#> Method: gwr; kernel: gaussian; bandwidth (fixed): 20000 m; selected by: user
#> Stations: 6 used, 0 excluded; p = 2 coefficients
#> tr(S) = 2.7382; 2 tr(S) - tr(S'S) = 3.1810; RSS = 0.0548862; RMSE_LOO = 0.241379
#> AICc: GWR 24.412005, global OLS 9.309406; CV: GWR 0.349583, global OLS 0.254309
#> Flags (warning): EF_GWR_FEW_NEIGHBOURS [1/6]
#> Conventions: k includes the point itself; AICc with ML sigma and tr(S)
fit$coefficients
#>   (Intercept)    elevation
#> 1    20.78793 -0.006583592
#> 2    20.79976 -0.006599539
#> 3    20.78418 -0.006545054
#> 4    20.79070 -0.006545003
#> 5    20.80460 -0.006598231
#> 6    20.77549 -0.006430294
```
