# Options of a preset of earthflux()

Returns every option that a preset sets, so that the choices made by
[`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md)
can be inspected before (and after) a run; the same list is recorded in
the provenance of the result.

## Usage

``` r
ef_preset(name)
```

## Arguments

- name:

  Character. Name of a registered preset (see
  [`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md)):
  `"idaho2002_elev"` or `"idaho2002_flat"`. No default.

## Value

An object of class `earthflux_preset` (a list): `name`, `version`,
`status`, `description`, `source`, `decisions` and the option blocks
`modis` (product and the options of the MODIS surface state), `terrain`,
`weather` (quality control, ERA5 options, regionalization),
`reference_et`, `radiation`, `soil_heat`, `roughness`, `wind`, `lambda`,
`anchors` (criteria built with
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md),
relaxation plan, aggregation, search area, anchor QA and boundary
conditions), `sensible_heat` (with an
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md)
list), `et`, and `unverified` (named character vector of the elements
that are not `VERIFICADA`).

## Details

The two presets (decisions M5-08 to M5-17, dev/specs/presets.md) share
every option except the treatment of elevation:

|  |  |  |
|----|----|----|
| Option | `idaho2002_elev` | `idaho2002_flat` |
| Lapse rate of the datum surface temperature (Eq. 12-7) | 0.0065 K m-1 | 0 |
| Temperature of the incoming longwave | cold-anchor Ts adjusted by elevation (Eq. 12-8) | cold-anchor Ts |
| Shortwave transmissivity (Eq. 11) | per pixel, from the elevation model | one for the scene |

Neither uses the slope (forced to 0, flat projection, until decision
RC-09 is resolved); both use the elevation of the elevation model for
the air pressure, the anchors and the datum temperature.

Common options: MODIS Terra LST (MOD11A1), white-sky albedo, emissivity
from LAI, NDVI of MOD13A2, LAI 0 assigned to the non-vegetated classes,
QA flagged (strict QA for the anchors), `min_valid_fraction = 1`;
NASADEM elevation with water masked; quality control
`"exclude_critical"`; ASCE alfalfa reference ET, hourly, with the
`"rn_positive"` daytime rule and `"low_sun"` night cloudiness, the
instantaneous value interpolated between hourly mid-points (O3) and the
daily sum over the mean solar day of the AOI centroid; one station: its
values over the whole grid (C1); several stations or ERA5: inverse
distance weighting with power 2 (C2); ERA5 with the native cell
elevation, trapezoid instantaneous values and the sea cells excluded;
anchors selected before the net radiation (incoming longwave from the
cold anchor, decision P0-3) with the criteria of dev/specs/presets.md
section 4, `etrf_cold = 1.05` and `etrf_hot = 0`; soil heat flux of
Bastiaanssen; z_om = 0.018 LAI, undefined where LAI = 0; wind at 200 m
from a weather site with z_om,w = 0.0144 m and d = 0; constant latent
heat; ETa_24 = ETrF x ETr_24.

## Verification status

`CANDIDATA` (see
[`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md));
the unverified elements are in the element `unverified`.

## References

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

## See also

[`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md),
[`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md).

Other workflow functions:
[`earthflux()`](https://djwillichile.github.io/EarthFlux/reference/earthflux.md),
[`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md)

## Examples

``` r
p <- ef_preset("idaho2002_elev")
p
#> <earthflux_preset> idaho2002_elev (version 1, CANDIDATA)
#>   SEBAL-Idaho 2002 forms with the elevation adjustments of appendix 12
#>   of the manual (datum surface temperature with a lapse rate of 0.0065
#>   K/m, cold-pixel temperature of the incoming longwave adjusted by
#>   elevation, shortwave transmissivity per pixel); flat projection
#>   (slope 0).
#> MODIS:
#>   lst_product            MOD11A1
#>   albedo_method          white_sky
#>   diffuse_fraction       NULL
#>   emissivity_method      lai_empirical
#>   ndvi_source            MOD13A2
#>   composite_method       same_day        , period_pixel_lag, period          
#>   resampling_method      mean
#>   min_valid_fraction     1
#>   qa_policy              flag
#>   mask_codes             NULL
#>   lai_nonveg             0
#> Terrain:
#>   dem_method             flat
#>   water                  mask
#>   min_valid_fraction     1
#>   slope                  0
#>   aspect                 0
#>   aoi_mask               cells touched by the AOI polygon (terra::rasterize, touches = TRUE)
#> Weather:
#>   qc_policy              exclude_critical
#>   use_qc                 ok     , warning
#>   one_station            C1: ef_method_station(station_id), no lapse rate
#>   several_stations       C2: ef_method_idw(power = 2)
#>   variables              etr_inst     , etr_24       , wind_speed_2m
#> ERA5:
#>   elevation_adjust       FALSE
#>   instant_values         trapezoid
#>   exclude_sea_cells      TRUE
#>   sea_elevation          0
#> Reference ET:
#>   reference              alfalfa
#>   timestep               hourly
#>   standard               asce
#>   day_definition         local_standard
#>   utc_offset             longitude of the AOI centroid / 15 h (mean solar day)
#>   day_completeness       all_periods
#>   daytime_rule           rn_positive
#>   night_cloudiness       low_sun
#>   inst_method            O3
#> Radiation:
#>   tau_method             elevation
#>   tau_elevation          pixel (elevation model)
#>   rs_method              modelled
#>   tau_partition          tau_beam = tau_sw, tau_diffuse = 0 (Eq. 12 on the horizontal)
#>   slope                  0
#>   rl_in_temperature      cold_anchor
#>   rl_in_lapse_rate       0.0065
#> Soil heat flux, roughness, wind, lambda:
#>   soil_heat              bastiaanssen
#>   zom                    lai
#>   zom_zero               NA + EF_H_ZOM_UNDEFINED
#>   zom_station            0.0144
#>   d_station              0
#>   lambda                 constant
#> Anchors:
#>   aggregate              mean
#>   search_area            one station: list(30 km around the station, whole AOI); otherwise the whole AOI
#>   etrf_cold              1.05
#>   etrf_hot               0
#> Sensible heat:
#>   lapse_rate             0.0065
#>   datum_elevation        elevation of the station (one station) or of the cold calibration point
#> ET:
#>   method                 etrf
#>   reference              alfalfa
#> Unverified elements (11): anchor_criteria, modis_albedo, modis_matching, lai_nonveg, reference_et_time, regionalization, era5, station_roughness, zom_zero, wind_time, flat_projection
#> Anchor criteria: x$anchors$criteria; relaxation: x$anchors$relax.
p$anchors$criteria
#> <earthflux_anchor_criteria> CANDIDATA - EarthFlux preset idaho2002 v1 (dev/specs/presets.md 4; DECISIONS.md M5-10): guides of Waters et al. (2002), appendix 7, widened for 1 km MODIS pixels without a source 
#>   cold: lai >= 3 & albedo between [0.18, 0.25] & ndvi >= p0.9; pick: lowest_fraction lst 0.2
#>   hot: lai <= 0.4 & ndvi > 0 & albedo between [0.10, 0.35]; pick: highest_fraction lst 0.2
#>   homogeneity: sd(lst) <= 1.5 in 3 x 3 window (exclude)
#>   percentile domain: land; quantile type: 7
names(p$unverified)
#>  [1] "anchor_criteria"   "modis_albedo"      "modis_matching"   
#>  [4] "lai_nonveg"        "reference_et_time" "regionalization"  
#>  [7] "era5"              "station_roughness" "zom_zero"         
#> [10] "wind_time"         "flat_projection"  
```
