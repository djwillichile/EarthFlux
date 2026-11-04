# Select the bandwidth of a geographically weighted regression

Selects a fixed (metres) or adaptive (k nearest stations) bandwidth by
minimising AICc or the leave-one-out cross-validation score over a
recorded search, and returns the full profile of the criterion
(dev/specs/gwr-forcing.md section 4).

AICc (decision GW-02): \$\$AICc = 2n\ln\hat\sigma + n\ln(2\pi) +
n\\\frac{n + tr(S)}{n - 2 - tr(S)}, \qquad \hat\sigma =
\sqrt{RSS/n},\$\$ with n the number of stations of the fit and tr(S) the
trace of the hat matrix; defined only when \\n - 2 - tr(S) \> 0\\.
Leave-one-out cross-validation: \$\$CV = \sum_i (y_i - \hat y\_{\ne
i})^2,\$\$ where \\\hat y\_{\ne i}\\ is the local fit at station i with
its own weight set to zero (the bandwidth \\b_i\\ is computed with the
station included), obtained exactly as \\e_i / (1 - s\_{ii})\\.

## Usage

``` r
ef_gwr_bandwidth(
  y,
  x,
  coords,
  kernel,
  adaptive = FALSE,
  criterion,
  search,
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

- kernel:

  Character, no default (decision GW-04 is open): one of `"gaussian"`,
  `"exponential"`, `"bisquare"`, `"tricube"`, `"boxcar"`.

- adaptive:

  Logical. `FALSE` for a fixed bandwidth in metres, `TRUE` for an
  adaptive bandwidth given as k nearest stations (the k-th smallest
  distance, counting the regression point itself when it is a station).
  Taken from `bandwidth` when that is an `earthflux_gwr_bandwidth`
  object and `adaptive` is not supplied.

- criterion:

  Character, no default (decision GW-05 is open): `"AICc"` or `"CV"`.

- search:

  The settings returned by
  [`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md).

- scale_covariates:

  Logical. Whether to centre and scale the covariates internally (by
  their mean and standard deviation over the stations of the fit) to
  condition the local systems. Coefficients are always reported in
  original units and predictions do not change.

- station_id:

  `NULL` or a vector of unique station identifiers. By default
  `names(y)`, `rownames(x)` or the row numbers.

## Value

An object of class `c("earthflux_gwr_bandwidth", "list")` with elements
`value` (b \[m\] or k), `type` (`"fixed"` or `"adaptive"`), `unit`
(`"m"` or `"neighbours"`), `kernel`, `criterion`, `criterion_value`,
`global` (criterion, AICc and CV of the global OLS model, the b = Inf
reference), `profile` (data frame with one row per evaluation:
`bandwidth`, `criterion`, `feasible`, `reason` of infeasibility, `aicc`,
`cv`, `enp` = tr(S), `rss`, `min_nonzero` (smallest number of neighbours
over the stations) and `stage`: `"grid"`, `"refine"` or `"global"`),
`search` (effective bounds and settings, number of evaluations, tie
rule), `stations` (`station_id`, `status`, `exclusion_reason`), `flags`
and `provenance`. Pass it to
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md)
as `bandwidth`.

## Details

A bandwidth is infeasible when, at some station, the local design is
rank deficient (`"rank_deficient"`) or has fewer than `min_neighbours`
neighbours (`"few_neighbours"`), when AICc is undefined
(`"aicc_undefined"`: n - 2 - tr(S) \<= 0, where the formula would give
spuriously low values) or when a LOO residual is undefined
(`"loo_undefined"`: s_ii = 1). Infeasible bandwidths are kept in the
profile and never selected. Ties of the criterion are resolved by the
smallest bandwidth. The search is deterministic.

Flags (object scope): `EF_GWR_BW_AT_BOUND` (the best grid value is at a
search bound; it is returned, not extrapolated), `EF_GWR_BW_MULTIMODAL`
(more than one local minimum among the feasible grid values),
`EF_GWR_AICC_UNDEFINED` (criterion AICc undefined in part of the
interval) and `EF_GWR_GLOBAL_PREFERRED` (the global OLS model has a
criterion not larger than the selected bandwidth; the finite optimum is
still returned). Excluded stations: `EF_GWR_STATION_EXCLUDED` (record).

Errors: `earthflux_gwr_insufficient_stations` (n \< p + 3),
`earthflux_gwr_no_feasible_bandwidth` (field `profile`),
`earthflux_missing_input` (a search setting needed and not given),
`earthflux_unknown_method` (kernel or criterion).

## AICc conventions and other implementations

Three different quantities are called "AICc" for the same fit by GWR
software (dev/specs/gwr-forcing.md section 4.2). EarthFlux uses n =
number of stations of the fit, \\\hat\sigma\\ the maximum likelihood
estimate sqrt(RSS/n) and tr(S)
(`aicc_definition = "gollini2015_tr_S_sigma_ml"`). This is exactly
`GW.diagnostic$AICc` of `GWmodel` 2.4-1, checked in the tests. `GWmodel`
reports as `enp` the quantity 2 tr(S) - tr(S'S) (EarthFlux `enp_alt`),
although its AICc uses tr(S). Algebraically, with K = tr(S) + 1, the
penalty n (n + tr S)/(n - 2 - tr S) equals n + 2K + 2K(K + 1)/(n - K -
1): a Gaussian AIC with K parameters plus a small-sample correction.

## Verification status

AICc form: `VERIFICADA` as content of Gollini et al. (2015; preprint
arXiv:1306.0413v2, section 6.1, p. 20), who attribute it to Hurvich and
Simonoff (Hurvich, Simonoff & Tsai, 1998; not read); sigma is not
specified there. As an EarthFlux definition: `CANDIDATA (corroborada)`,
reproduced by `GWmodel`. LOOCV: `CANDIDATA (corroborada)`. The search
(log grid plus Brent refinement; exhaustive search over k) is a design
choice; its settings have no default (GW-05).

## References

Gollini, I., Lu, B., Charlton, M., Brunsdon, C., & Harris, P. (2015).
GWmodel: An R package for exploring spatial heterogeneity using
geographically weighted models. *Journal of Statistical Software*,
63(17).
[doi:10.18637/jss.v063.i17](https://doi.org/10.18637/jss.v063.i17)

Hurvich, C. M., Simonoff, J. S., & Tsai, C.-L. (1998). Smoothing
parameter selection in nonparametric regression using an improved Akaike
information criterion. *Journal of the Royal Statistical Society: Series
B*, 60(2), 271-293.
[doi:10.1111/1467-9868.00125](https://doi.org/10.1111/1467-9868.00125)

## See also

Other spatial regionalization functions:
[`ef_gwr_diagnostics()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_diagnostics.md),
[`ef_gwr_fit()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_fit.md),
[`ef_gwr_predict()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_predict.md),
[`ef_gwr_search()`](https://djwillichile.github.io/EarthFlux/reference/ef_gwr_search.md)

## Examples

``` r
coords <- cbind(c(0, 10000, 0, 10000, 20000, 30000, 25000, 5000),
                c(0, 0, 10000, 10000, 0, 30000, 15000, 25000))
elev <- cbind(elevation = c(100, 300, 500, 200, 800, 1200, 650, 900))
ta <- c(20.0, 18.9, 17.5, 19.6, 15.4, 13.1, 16.2, 14.6)
bw <- ef_gwr_bandwidth(ta, elev, coords, kernel = "gaussian",
                       criterion = "AICc",
                       search = ef_gwr_search(n_grid = 20, tol = 10,
                                              upper_factor = 2))
bw
#> <earthflux_gwr_bandwidth>
#> Kernel: gaussian; fixed bandwidth = 84852.814 m
#> Criterion: AICc = 7.0474135 (global OLS: 6.8436811)
#> Search: [25495.098, 84852.814] m, 20 grid values, tol = 10 m; 21 evaluations
#> Minimum neighbours: 3 (mathematical_minimum); feasible evaluations: 20 of 21
#> Flags (warning): EF_GWR_BW_AT_BOUND [1/1]
#> Flags (info): EF_GWR_GLOBAL_PREFERRED [1/1]
fit <- ef_gwr_fit(ta, elev, coords, bandwidth = bw)
```
