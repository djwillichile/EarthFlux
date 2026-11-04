# Reference evapotranspiration (grass ETo, alfalfa ETr)

Computes the reference evapotranspiration with the combination
(Penman-Monteith) equation of a hypothetical reference surface, for the
grass reference of FAO-56 (ETo) or the tall alfalfa reference of the
ASCE-EWRI standardized equation (ETr, the reference used by METRIC),
with a daily or an hourly time step. All choices are explicit arguments
without defaults. The inputs are the reference-surface quantities
already computed (net radiation, soil heat flux, slope of the saturation
curve, psychrometric constant, vapour pressure deficit, wind at 2 m).

## Usage

``` r
ef_ref_et(
  net_radiation,
  soil_heat_flux,
  air_temperature,
  wind_speed_2m,
  vapour_pressure_deficit,
  slope,
  psychrometric,
  reference,
  timestep,
  standard,
  daytime = NULL
)
```

## Arguments

- net_radiation:

  Numeric. Net radiation of the reference surface \\R_n\\ \[MJ m-2 d-1
  or MJ m-2 h-1\], from
  [`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md).
  Any finite value.

- soil_heat_flux:

  Numeric. Soil heat flux of the reference surface \\G\\ in the same
  unit, from
  [`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md)
  (0 for daily steps). Any finite value.

- air_temperature:

  Numeric. Air temperature \[degrees Celsius\]: the daily mean
  \\(T\_{max} + T\_{min})/2\\ for daily steps, the hourly mean for
  hourly steps. Finite and `> -273`.

- wind_speed_2m:

  Numeric. Wind speed at 2 m \\u_2\\ \[m s-1\], from
  [`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md).
  Finite and `>= 0`.

- vapour_pressure_deficit:

  Numeric. Vapour pressure deficit \\e_s - e_a\\ \[kPa\]
  ([`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md)
  and the
  [ef_ea](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md)
  functions). Any finite value: a negative deficit (actual above
  saturation vapour pressure) is kept.

- slope:

  Numeric. Slope of the saturation vapour pressure curve \\\Delta\\
  \[kPa degC-1\], from
  [`ef_es_slope()`](https://djwillichile.github.io/EarthFlux/reference/ef_es_slope.md).
  Finite and `> 0`.

- psychrometric:

  Numeric. Psychrometric constant \\\gamma\\ \[kPa degC-1\], from
  [`ef_psychrometric()`](https://djwillichile.github.io/EarthFlux/reference/ef_psychrometric.md).
  Finite and `> 0`.

- reference:

  Character, no default. `"grass"` (ETo, short reference, 0.12 m) or
  `"alfalfa"` (ETr, tall reference, about 0.5 m). It is kept in the
  result, because a crop coefficient on a grass basis and a METRIC
  reference fraction on an alfalfa basis are not interchangeable.

- timestep:

  Character, no default. `"daily"` or `"hourly"`.

- standard:

  Character, no default. `"fao56"` (FAO-56 Eqs. 6 and 53; grass only,
  `VERIFICADA`) or `"asce"` (ASCE-EWRI 2005 standardized constants,
  `CANDIDATA`).

- daytime:

  Logical or `NULL`. Required for `timestep = "hourly"` with
  `standard = "asce"`, where \\C_d\\ differs by day and night: `TRUE`
  for daytime periods (`NA` gives `NA`); the day/night criterion is the
  caller's choice (decision WF-15). Not used with `standard = "fao56"`
  (\\C_d\\ = 0.34 day and night); must be `NULL` for daily steps.

## Value

An object of class `earthflux_reference_et`: a list with

- `et_ref`: reference evapotranspiration \[mm d-1 for daily steps, mm
  h-1 for hourly steps\], numeric with the common length (and `dim`) of
  the inputs; negative values are kept;

- `reference`, `timestep`, `standard`: the choices made;

- `flags`: list of `earthflux_flag` records (record scope) for the codes
  that hold somewhere: `EF_INPUT_NA` and `EF_WS_ETR_NEGATIVE` (negative
  reference ET, kept; the code covers ETo and ETr);

- `provenance`: the rows of the constants table used (`constants`, with
  source and status of each), the verification `status` (`"VERIFICADA"`
  for FAO-56 grass, `"CANDIDATA"` otherwise), references,
  `flags_evaluated` and package version.

## Details

\$\$ET\_{ref} = \frac{0.408\\\Delta (R_n - G) + \gamma \frac{C_n}{T +
273} u_2 (e_s - e_a)}{\Delta + \gamma (1 + C_d u_2)}\$\$ With \\C_n\\ =
900 and \\C_d\\ = 0.34 it is FAO-56 Eq. 6 (daily ETo, mm d-1); with
\\C_n\\ = 37 and \\C_d\\ = 0.34, FAO-56 Eq. 53 (hourly ETo, mm h-1). The
constants come from one internal table with the source and status of
each row (dev/specs/weather-forcing.md 5.3):

|                           |         |                       |              |
|---------------------------|---------|-----------------------|--------------|
| Reference, standard, step | \\C_n\\ | \\C_d\\               | Status       |
| grass, `"fao56"`, daily   | 900     | 0.34                  | `VERIFICADA` |
| grass, `"fao56"`, hourly  | 37      | 0.34                  | `VERIFICADA` |
| grass, `"asce"`, daily    | 900     | 0.34                  | `CANDIDATA`  |
| alfalfa, `"asce"`, daily  | 1600    | 0.38                  | `CANDIDATA`  |
| grass, `"asce"`, hourly   | 37      | 0.24 day / 0.96 night | `CANDIDATA`  |
| alfalfa, `"asce"`, hourly | 66      | 0.25 day / 1.7 night  | `CANDIDATA`  |

FAO-56 reference surface: hypothetical grass 0.12 m high, fixed surface
resistance 70 s m-1 and albedo 0.23, with measurements at 2 m (FAO-56,
chapter 2). The factor 0.408 (1 / 2.45 MJ kg-1) and 273 in the
aerodynamic term are the literals of the standard (decision WF-14).
FAO-56 (chapter 4) warns that the fixed surface resistance may
underestimate hourly ETo in daytime and overestimate it in the evening,
and that hourly values summed over 24 hours generally match the daily
computation.

**`standard` matters for the grass reference.** For hourly grass, FAO-56
uses \\C_d\\ = 0.34 day and night, while the ASCE-EWRI candidate
constants use 0.24 / 0.96: with the inputs of FAO-56 example 19
(14:00-15:00) they give 0.627 and 0.656 mm h-1.

`standard = "fao56"` with `reference = "alfalfa"` raises
`earthflux_undefined_reference` (also `earthflux_input_error`): FAO-56
does not define the tall reference. The constants of the alfalfa
reference verify only the arithmetic here: a verification case for ETr
requires the examples of ASCE-EWRI (2005), not yet read.

The instantaneous reference ET at the satellite overpass (spec 5.5) and
the daily ETr from hourly values (spec 5.6) belong to the station
orchestration
[`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md),
not to this function.

Missing values propagate (and are flagged `EF_INPUT_NA`). Negative
results (for example at night, when \\R_n - G \< 0\\ with a small
deficit) are kept and flagged `EF_WS_ETR_NEGATIVE` (principle 6), never
truncated. Missing or unknown choices raise `earthflux_missing_input` or
`earthflux_unknown_method`; values outside the domains above raise
`earthflux_domain_error`.

## Verification status

`standard = "fao56"`, `reference = "grass"`: `VERIFICADA` (FAO-56,
chapter 4, Eqs. 6 and 53; examples 18 and 19, cases V14-V16 of
dev/specs/weather-forcing.md 8.1). `standard = "asce"` (short and tall
reference, daily and hourly, day and night \\C_d\\): `CANDIDATA`
(ASCE-EWRI, 2005, was not accessible; constants from secondary
implementations; implemented as `CANDIDATA` by direction of the author
to advance milestone M3; dev/specs/weather-forcing.md 13).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
Equation*. American Society of Civil Engineers.
[doi:10.1061/9780784408056](https://doi.org/10.1061/9780784408056)

## See also

Other reference evapotranspiration functions:
[`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md),
[`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md),
[`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md)

## Examples

``` r
# FAO-56 example 18 (Uccle, 6 July, 100 m): daily grass ETo
tmean <- (21.5 + 12.3) / 2
ea <- ef_ea_daily(tmin = 12.3, tmax = 21.5, rh_max = 84, rh_min = 63,
                  method = "rhmax_rhmin")
es <- mean(ef_es(c(21.5, 12.3)))
rn <- ef_ref_net_radiation(solar_radiation = 22.07,
                           clear_sky_radiation = 30.90,
                           vapour_pressure = ea, tmax = 21.5, tmin = 12.3,
                           timestep = "daily")$rn
eto <- ef_ref_et(
  net_radiation = rn, soil_heat_flux = 0, air_temperature = tmean,
  wind_speed_2m = ef_wind_2m(10 / 3.6, 10),
  vapour_pressure_deficit = es - ea, slope = ef_es_slope(tmean),
  psychrometric = ef_psychrometric(ef_air_pressure(100)),
  reference = "grass", timestep = "daily", standard = "fao56"
)
eto$et_ref
#> [1] 3.880101

# Same inputs, tall reference with the ASCE-EWRI candidate constants
ef_ref_et(
  net_radiation = rn, soil_heat_flux = 0, air_temperature = tmean,
  wind_speed_2m = ef_wind_2m(10 / 3.6, 10),
  vapour_pressure_deficit = es - ea, slope = ef_es_slope(tmean),
  psychrometric = ef_psychrometric(ef_air_pressure(100)),
  reference = "alfalfa", timestep = "daily", standard = "asce"
)$et_ref
#> [1] 4.606384
```
