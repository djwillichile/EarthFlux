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
`status`, `description`, `source`, `decisions`, `changes` (what each
version changed) and the option blocks `modis` (product and the options
of the MODIS surface state), `terrain`, `weather` (quality control, ERA5
options, regionalization), `reference_et`, `radiation`, `soil_heat`,
`roughness`, `wind`, `lambda`, `anchors` (criteria built with
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md),
relaxation plan, aggregation, search area, anchor QA and boundary
conditions), `sensible_heat` (with an
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md)
list), `et`, `terrain_rule` (the terrain rule of version 4: method
`"anchor_elevation_range"`, limit `max_elevation_difference` in metres,
500 for `idaho2002_elev` and 250 for `idaho2002_flat`, reference
elevations, flag and status) and `unverified` (named character vector of
the elements that are not `VERIFICADA`).

## Details

The two presets (decisions M5-08 to M5-25 and M2-11,
dev/specs/presets.md) share every option except the treatment of
elevation:

|  |  |  |
|----|----|----|
| Option | `idaho2002_elev` | `idaho2002_flat` |
| Lapse rate of the datum surface temperature (Eq. 12-7) | 0.0065 K m-1 | 0 |
| Temperature of the incoming longwave | cold-anchor Ts adjusted by elevation (Eq. 12-8) | cold-anchor Ts |
| Shortwave transmissivity (Eq. 11) | per pixel, from the elevation model | one for the scene |
| Limit of the terrain rule (M5-25) | 500 m | 250 m |

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
calibration of H with the convergence settings of
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md)
(`tol = 1e-6`, `pixel_tol = 1e-5`, written out in the preset); anchors
selected before the net radiation (incoming longwave from the cold
anchor, decision P0-3) with the criteria of dev/specs/presets.md section
4, `etrf_cold = 1.05` and `etrf_hot = 0`; soil heat flux of
Bastiaanssen; z_om = 0.018 LAI with a minimum of 0.005 m (`CANDIDATA`,
flagged with `EF_H_ZOM_FLOOR_APPLIED`); wind at 200 m from a weather
site with z_om,w = 0.0144 m and d = 0; constant latent heat; ETa_24 =
ETrF x ETr_24.

Anchor criteria (version 2, decision M5-23, `CANDIDATA`): cold
candidates with NDVI at or above the 90th percentile of the usable land
cells and white-sky albedo in \[0.14, 0.26\]; hot candidates with NDVI
at or below the 10th percentile, NDVI \> 0 and albedo in \[0.18, 0.35\];
homogeneous LST (standard deviation \<= 1.5 K in 3 x 3 cells); the
coldest 20 % of the cold and the hottest 20 % of the hot candidates,
averaged; one relaxation step (percentiles 0.80 and 0.20), flagged with
`EF_ANCHOR_CRITERIA_RELAXED`; no anchor on cells with a warning or
critical surface flag or an assigned LAI.

Terrain rule (version 4, decision M5-25, `CANDIDATA`): one linear dT
calibrated between two anchors with one weather forcing holds only over
the elevations of the calibration (the manual assumes uniform climate,
Waters et al., 2002, p. 70, and gives its lapse rate of 6.5 K per km
under neutral conditions, appendix 12, p. 95). The reference is the
elevation range of the calibration: the cold and hot calibration points
of a preliminary anchor selection without the rule and, with one
station, the station (datum of Ts and site of the forcing). Cells more
than the limit of the preset below or above that range hold no anchor
and are `NA` in every layer, flagged with `EF_H_TERRAIN_RULE_APPLIED`;
cells between the anchors are kept, however far from each. The final
anchor selection runs on the kept cells; its anchors lie inside the kept
range by construction, and the range is not recomputed from them. The
limit keeps the error of the datum surface temperature beyond the
calibrated range within the 1.5 K of the homogeneity tolerance of the
anchors, rounded up to the next 50 m: with the lapse correction of
`idaho2002_elev` the error is the difference to a dry adiabatic profile,
9.8 - 6.5 = 3.3 K per km (1.5 / 3.3 = 455 m, limit 500 m); without it
(`idaho2002_flat`) the error is the whole lapse rate, 6.5 K per km (1.5
/ 6.5 = 231 m, limit 250 m). Neither limit has a primary source. The
slope is not used: the presets keep the flat projection.

Versions: `"1"` (first presets); `"2"` (recalibrated anchor criteria,
M5-23; minimum z_om, M5-24); `"3"` (convergence of the calibration of H,
one tolerance per phase, M2-11); `"4"` (terrain rule, M5-25); see the
element `changes`.

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
#> <earthflux_preset> idaho2002_elev (version 4, CANDIDATA)
#>   SEBAL-Idaho 2002 forms with the elevation adjustments of appendix 12
#>   of the manual (datum surface temperature with a lapse rate of 0.0065
#>   K/m, cold-pixel temperature of the incoming longwave adjusted by
#>   elevation, shortwave transmissivity per pixel); flat projection
#>   (slope 0); cells more than 500 m above or below the elevation range
#>   of the calibration anchors excluded (M5-25).
#> MODIS:
#>   lst_product              MOD11A1
#>   albedo_method            white_sky
#>   diffuse_fraction         NULL
#>   emissivity_method        lai_empirical
#>   ndvi_source              MOD13A2
#>   composite_method         same_day        , period_pixel_lag, period          
#>   resampling_method        mean
#>   min_valid_fraction       1
#>   qa_policy                flag
#>   mask_codes               NULL
#>   lai_nonveg               0
#> Terrain:
#>   dem_method               flat
#>   water                    mask
#>   min_valid_fraction       1
#>   slope                    0
#>   aspect                   0
#>   aoi_mask                 cells touched by the AOI polygon (terra::rasterize, touches = TRUE)
#> Weather:
#>   qc_policy                exclude_critical
#>   use_qc                   ok     , warning
#>   one_station              C1: ef_method_station(station_id), no lapse rate
#>   several_stations         C2: ef_method_idw(power = 2)
#>   variables                etr_inst     , etr_24       , wind_speed_2m
#> ERA5:
#>   elevation_adjust         FALSE
#>   instant_values           trapezoid
#>   exclude_sea_cells        TRUE
#>   sea_elevation            0
#> Reference ET:
#>   reference                alfalfa
#>   timestep                 hourly
#>   standard                 asce
#>   day_definition           local_standard
#>   utc_offset               longitude of the AOI centroid / 15 h (mean solar day)
#>   day_completeness         all_periods
#>   daytime_rule             rn_positive
#>   night_cloudiness         low_sun
#>   inst_method              O3
#> Radiation:
#>   tau_method               elevation
#>   tau_elevation            pixel (elevation model)
#>   rs_method                modelled
#>   tau_partition            tau_beam = tau_sw, tau_diffuse = 0 (Eq. 12 on the horizontal)
#>   slope                    0
#>   rl_in_temperature        cold_anchor
#>   rl_in_lapse_rate         0.0065
#> Soil heat flux, roughness, wind, lambda:
#>   soil_heat                bastiaanssen
#>   zom                      lai
#>   zom_min                  0.005
#>   zom_station              0.0144
#>   d_station                0
#>   lambda                   constant
#> Anchors:
#>   aggregate                mean
#>   search_area              one station: list(30 km around the station, whole AOI); otherwise the whole AOI
#>   etrf_cold                1.05
#>   etrf_hot                 0
#> Sensible heat:
#>   lapse_rate               0.0065
#>   datum_elevation          elevation of the station (one station) or of the cold calibration point
#> ET:
#>   method                   etrf
#>   reference                alfalfa
#> Terrain rule:
#>   method                   anchor_elevation_range
#>   max_elevation_difference 500
#>   flag                     EF_H_TERRAIN_RULE_APPLIED
#>   status                   CANDIDATA (M5-25)
#> Unverified elements (12): anchor_criteria, modis_albedo, modis_matching, lai_nonveg, reference_et_time, regionalization, era5, station_roughness, zom_floor, wind_time, flat_projection, terrain_rule
#> Anchor criteria: x$anchors$criteria; relaxation: x$anchors$relax.
p$anchors$criteria
#> <earthflux_anchor_criteria> CANDIDATA - EarthFlux preset idaho2002 v2 (dev/specs/presets.md 4; DECISIONS.md M5-23): physical intent of Waters et al. (2002), pp. 23, 30-31 and appendix 7, with thresholds for 1 km MODIS pixels set from the Cauquenes and Maule scenes of 2019-02-15 (no primary source) 
#>   cold: ndvi >= p0.9 & albedo between [0.14, 0.26]; pick: lowest_fraction lst 0.2
#>   hot: ndvi <= p0.1 & ndvi > 0 & albedo between [0.18, 0.35]; pick: highest_fraction lst 0.2
#>   homogeneity: sd(lst) <= 1.5 in 3 x 3 window (exclude)
#>   percentile domain: land; quantile type: 7
names(p$unverified)
#>  [1] "anchor_criteria"   "modis_albedo"      "modis_matching"   
#>  [4] "lai_nonveg"        "reference_et_time" "regionalization"  
#>  [7] "era5"              "station_roughness" "zom_floor"        
#> [10] "wind_time"         "flat_projection"   "terrain_rule"     
```
