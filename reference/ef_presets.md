# Registered presets of earthflux()

Lists the presets that
[`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md)
accepts: a preset is a named, documented and versioned set of every
scientific option of the workflow (decision M5-04). Use
[`ef_preset()`](https://djwillichile.github.io/EarthFlux/reference/ef_preset.md)
to see every option of one preset.

## Usage

``` r
ef_presets()
```

## Value

A data frame with one row per preset: `name`, `version`, `status`
(verification status of the preset as a whole: `"VERIFICADA"` only when
every formulation and option is) and `description`.

## Verification status

Both presets are `CANDIDATA` (decision M5-09): their forms are those of
the SEBAL Idaho manual (Waters et al., 2002), mostly
`VERIFICADA (SEBAL-Idaho 2002)`, but the anchor criteria, the MODIS
albedo and the regionalization, among others, are not verified. The
unverified elements are listed in `ef_preset(name)$unverified` and in
the warning of
[`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md).

## See also

[`ef_preset()`](https://djwillichile.github.io/EarthFlux/reference/ef_preset.md),
[`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md).

Other workflow functions:
[`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md),
[`ef_preset()`](https://djwillichile.github.io/EarthFlux/reference/ef_preset.md)

## Examples

``` r
ef_presets()
#>             name version    status
#> 1 idaho2002_elev       1 CANDIDATA
#> 2 idaho2002_flat       1 CANDIDATA
#>                                                                                                                                                                                                                                                                             description
#> 1 SEBAL-Idaho 2002 forms with the elevation adjustments of appendix 12 of the manual (datum surface temperature with a lapse rate of 0.0065 K/m, cold-pixel temperature of the incoming longwave adjusted by elevation, shortwave transmissivity per pixel); flat projection (slope 0).
#> 2                                         Base procedure of the SEBAL-Idaho 2002 manual for low relief: no lapse rate in the datum surface temperature, one cold-pixel temperature for the incoming longwave and one shortwave transmissivity for the scene; flat projection (slope 0).
```
