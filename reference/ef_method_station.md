# Regionalization by a representative station (C1)

Describes configuration C1 for
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md)
and
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md)
(dev/specs/gwr-forcing.md section 5.3): the surface is constant and
equal to the value of the station `station_id` at each target time,
\$\$v(x) = v_s,\$\$ or, for `air_temperature` only and with an explicit
lapse rate \\\Gamma\\ (variant `"station_lapse"`), \$\$v(x) = v_s +
\Gamma\\(z(x) - z_s),\$\$ with z the `elevation` layer of the covariates
(also at the station, decision GW-10).

## Usage

``` r
ef_method_station(station_id, lapse_rate = NULL)
```

## Arguments

- station_id:

  The identifier of the representative station; no automatic choice
  (dev/VALIDATION_PLAN.md section 2.2).

- lapse_rate:

  `NULL` or the vertical gradient \[unit of the variable per m, e.g.
  degC m-1\]. No default value exists (`TODO` in
  dev/specs/gwr-forcing.md section 5.3): its value and source are the
  user's responsibility and are recorded in the provenance.

## Value

A list of class `"earthflux_regionalization_method"` with
`method = "station"` or `"station_lapse"`.

## Details

The station-level diagnostic equivalent to cross-validation is the error
at the other stations; the representative station itself is not
evaluated. Surfaces carry the object flag `EF_GWR_SINGLE_STATION`.
Errors: `earthflux_missing_input` (`station_id`),
`earthflux_input_error` (not a single identifier),
`earthflux_domain_error` (infinite lapse rate).

## Verification status

The constant surface is a definition of the comparison configuration (no
formula to verify). The lapse-rate variant is `CANDIDATA`: its value has
no verified default (radiation-components.md RC-12, option a).

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
[`ef_predict_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_predict_control.md),
[`ef_regionalize()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize.md),
[`ef_regionalize_cv()`](https://djwillichile.github.io/EarthFlux/reference/ef_regionalize_cv.md),
[`ef_spatial_folds()`](https://djwillichile.github.io/EarthFlux/reference/ef_spatial_folds.md)

## Examples

``` r
ef_method_station("ST07")
#> <earthflux_regionalization_method> station 
#> representative station ST07
ef_method_station("ST07", lapse_rate = -0.0065)
#> <earthflux_regionalization_method> station_lapse 
#> representative station ST07, lapse rate -0.0065
```
