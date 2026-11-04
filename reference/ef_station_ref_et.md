# Reference evapotranspiration at weather stations

Computes the reference evapotranspiration series of every station of a
station table (hourly or daily records), and from it the two quantities
that the METRIC chain needs: the instantaneous reference ET at given
overpass times (`etr_inst`, mm h-1, for the cold anchor condition) and
the daily reference ET of given dates (`etr_24`, mm d-1, for the
extrapolation to 24 hours). It orchestrates the derived variables
([`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md),
[`ef_ea_rh()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md),
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md),
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md),
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md),
...) and the reference surface functions
([`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md),
[`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md),
[`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md))
on the values allowed by the quality control. The choices that are still
open decisions of the specification (WF-09, WF-11, WF-15, WF-16) are
explicit arguments without defaults.

## Usage

``` r
ef_station_ref_et(
  x,
  reference,
  timestep,
  standard,
  humidity,
  day_definition,
  day_completeness,
  daytime_rule = NULL,
  night_cloudiness = NULL,
  night_ratio = NULL,
  overpass = NULL,
  inst_method = NULL,
  dates = NULL,
  utc_offset = NULL
)
```

## Arguments

- x:

  An `earthflux_station_qc`
  ([`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md))
  or an `earthflux_station_table`
  ([`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md)),
  which is then quality controlled with `ef_station_qc(x)` (policy
  `"exclude_critical"`; call
  [`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md)
  first to choose another policy). Only the values whose QC status is
  not `"excluded"` are used; the excluded ones are missing.

- reference:

  Character, no default. `"alfalfa"` (tall reference, ETr, the reference
  of METRIC) or `"grass"` (short reference, ETo). It must be the
  reference of the reference ET fraction of the cold anchor.

- timestep:

  Character, no default. `"hourly"` (records with `interval = 3600` s;
  FAO-56 Eq. 53 form) or `"daily"` (records with `interval = 86400` s;
  FAO-56 Eq. 6 form). The records must be period means
  (`timestamp_convention` `"end"` or `"start"`).

- standard:

  Character, no default. `"fao56"` (grass only, `VERIFICADA`) or
  `"asce"` (ASCE-EWRI 2005 standardized constants, `CANDIDATA`); see
  [`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md).

- humidity:

  Character, no default. Source of the actual vapour pressure:
  `"vapour_pressure"` (column `vapour_pressure`),
  `"dewpoint_temperature"` (FAO-56 Eq. 14 on `dewpoint_temperature`) or
  `"relative_humidity"` (hourly: FAO-56 Eq. 54 with `air_temperature`
  and `relative_humidity`; daily: Eq. 17 with `tmin`, `tmax`, `rh_max`
  and `rh_min`).

- day_definition:

  Character, no default (decision WF-11). Day of the daily sums: `"utc"`
  (UTC calendar day) or `"local_standard"` (calendar day in the local
  standard time given by `utc_offset`, without daylight saving time). A
  period belongs to the day of its mid-point.

- day_completeness:

  Character, no default (decision WF-11, gap policy). Only
  `"all_periods"` is implemented: a day has a daily value only if all
  its periods (24 hourly periods, or the daily record) have a valid
  reference ET; otherwise `etr_24` is `NA` and flagged
  `EF_WS_INCOMPLETE_DAY`. No gap is filled.

- daytime_rule:

  Character or `NULL` (decision WF-15). Hourly only (required; `NULL`
  for daily): criterion of the daytime periods, which select the soil
  heat flux ratio and, with `standard = "asce"`, the denominator
  constant: `"ra_positive"` (extraterrestrial radiation of the period \>
  0, i.e. sun above the horizon at the mid-point, FAO-56 midpoint
  criterion) or `"rn_positive"` (net radiation of the reference surface
  \> 0, the criterion that secondary implementations attribute to
  ASCE-EWRI, `CANDIDATA`).

- night_cloudiness:

  Character or `NULL`. Hourly only (required; `NULL` for daily): the
  ratio \\R_s/R\_{so}\\ of the night-time periods (\\R\_{so} = 0\\),
  where it is undefined (FAO-56, chapter 4, hourly time step):
  `"before_sunset"` (the ratio of the last period of the same station,
  in the previous 24 hours, whose mid-point hour angle lies in
  \\\[\omega_s - 0.79, \omega_s - 0.52\]\\, i.e. 2-3 hours before
  sunset; `NA` if there is none or its ratio is missing) or `"fixed"`
  (the constant `night_ratio`).

- night_ratio:

  Numeric scalar in \[0, 1\] or `NULL`. The night-time ratio
  \\R_s/R\_{so}\\ for `night_cloudiness = "fixed"` (FAO-56 suggests
  0.4-0.6 in humid and sub-humid and 0.7-0.8 in arid and semi-arid
  climates; 0.3 means complete cloud cover). `NULL` otherwise.

- overpass:

  POSIXct or `NULL`. Overpass times at which the instantaneous reference
  ET is wanted (hourly only); converted to UTC. Every station gets every
  time.

- inst_method:

  Character or `NULL` (decision WF-09). Required with `overpass`: `"O1"`
  (reference ET of the hourly period that contains the overpass time,
  start included, end excluded) or `"O3"` (linear interpolation in time
  of the hourly reference ET between the mid-points of consecutive
  periods; no interpolation across a missing record and no
  extrapolation). Options O2, O4 and O5 of the specification are not
  implemented.

- dates:

  Date or `NULL`. Days of the daily sums (in the day definition).
  `NULL`: every day with at least one record, per station.

- utc_offset:

  Numeric or `NULL`. Required with `day_definition = "local_standard"`
  (`NULL` otherwise): offset of the local standard time from UTC \[h\],
  in \[-12, 14\] (e.g. `-4` for UTC-4), a single value for all stations
  or a vector named by `station_id`.

## Value

An object of class `earthflux_station_ref_et`: a list with

- `series`: one row per record of `x$observations` (same order) with
  `station_id`, `timestamp`, `target_time` (mid-point of the period,
  UTC), `date` (day of the period, see `day_definition`),
  `extraterrestrial_radiation`, `clear_sky_radiation`, `solar_radiation`
  (MJ m-2 per period: h-1 or d-1), `vapour_pressure`,
  `vapour_pressure_deficit` \[kPa\], `wind_speed_2m` \[m s-1\],
  `cloudiness` (the term \\1.35 R_s/R\_{so} - 0.35\\ used),
  `cloudiness_source` (`"ratio"`, `"before_sunset"`, `"fixed"`),
  `daytime` (hourly; `NA` for daily), `net_radiation`, `soil_heat_flux`
  (MJ m-2 per period) and `et_ref` (mm h-1 or mm d-1);

- `etr_inst`: one row per station and overpass time with `station_id`,
  `overpass_time` (UTC), `etr_inst` \[mm h-1\] and `method` (zero rows
  without `overpass`);

- `etr_24`: one row per station and day with `station_id`, `date`,
  `n_periods` (periods with a valid reference ET) and `etr_24` \[mm
  d-1\];

- `reference`, `timestep`, `standard`;

- `flags`: `earthflux_flag` records of scope `record` for the codes that
  hold somewhere, each with an element `target` naming the table whose
  rows `index` refers to (`"series"`, `"etr_inst"`, `"etr_24"`):
  `EF_INPUT_NA`, `EF_WS_RS_RSO_LIMITED` and `EF_WS_ETR_NEGATIVE`
  (series), `EF_WS_OVERPASS_OUTSIDE_RECORDS` and `EF_INPUT_NA`
  (`etr_inst`), `EF_WS_INCOMPLETE_DAY` (`etr_24`);

- `provenance`: the choices made, the verification status, the constants
  used, the QC policy and the values excluded by it, the provenance of
  the station table, `flags_evaluated` (and `flags_evaluated_by_target`)
  and the package version.

## Details

**Hourly records.** For each record, with \\t\\ the mid-point of the
period: \\R_a\\ of the period with
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md)
(FAO-56 Eq. 28, midpoint criterion, day of year of \\t\\ in UTC),
\\R\_{so}\\ with
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md)
(Eq. 37, decision WF-12), the air pressure from the station elevation
([`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md),
Eq. 7, decision WF-05; a measured `air_pressure` is not used),
\\\gamma\\, \\e^\circ(T)\\ and \\\Delta\\ at the hourly temperature, the
wind at 2 m from `height_wind` (Eq. 47), the solar radiation converted
from W m-2 to MJ m-2 h-1 (x 0.0036, FAO-56 Table 3), then
[`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md),
[`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md)
and
[`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md).
Periods with \\R\_{so} \> 0\\ use their own ratio \\R_s/R\_{so}\\
(limited to 1 inside the cloudiness term and flagged
`EF_WS_RS_RSO_LIMITED`); the others use `night_cloudiness`.

**Daily records.** Tmean = (Tmax + Tmin)/2 (Eq. 9), \\e_s\\ = mean of
\\e^\circ(T\_{max})\\ and \\e^\circ(T\_{min})\\ (Eq. 12), \\\Delta\\ at
Tmean, \\R_a\\ with
[`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md)
(day of year of the record's day), the solar radiation converted from W
m-2 (24-hour mean) to MJ m-2 d-1 (x 0.0864), \\G = 0\\ (Eq. 42). A day
with \\R\_{so} = 0\\ (polar night) has no defined cloudiness term and
gives `NA`.

**Daily sums** (option D1 of the specification for hourly records,
decision WF-16): `etr_24` is the sum of the 24 hourly depths of the day
(rate in mm h-1 times 1 h); FAO-56 (chapter 4) states that hourly sums
over 24 hours generally match the daily computation for the grass
reference; for the alfalfa reference and METRIC this is `CANDIDATA`. For
daily records `etr_24` is the daily value of the record (option D2 with
daily data).

**Instantaneous reference ET** (decision WF-09): `etr_inst` is a rate in
mm h-1. An overpass time outside the time covered by the records of a
station (option O1: from the start of its first period to the end of its
last period; option O3: from its first to its last mid-point) gives `NA`
and the flag `EF_WS_OVERPASS_OUTSIDE_RECORDS`; inside that range, a
missing record or a missing reference ET gives `NA` and `EF_INPUT_NA`.

Values are never filled, truncated or corrected: negative reference ET
is kept (`EF_WS_ETR_NEGATIVE`). Under `qc_policy = "keep_all"` an
impossible value reaches the numeric functions, which raise
`earthflux_domain_error`. Missing or unknown choices raise
`earthflux_missing_input` or `earthflux_unknown_method`; choices that do
not apply to the time step, a record interval that does not match
`timestep`, or a missing column raise `earthflux_input_error`
subclasses.

## Verification status

The physics is that of the functions called (FAO-56 grass: `VERIFICADA`;
ASCE-EWRI constants: `CANDIDATA`), reproduced through this function for
FAO-56 example 19. The orchestration choices are recorded in the
provenance; `"before_sunset"` follows FAO-56 (chapter 4) with the
selection of the last qualifying period as an implementation choice;
`"rn_positive"` and the daily sum of hourly ETr for the alfalfa
reference are `CANDIDATA`; the day definition and the completeness rule
are open decisions (WF-11).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
Equation*. American Society of Civil Engineers.
[doi:10.1061/9780784408056](https://doi.org/10.1061/9780784408056)

## See also

[`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md),
[`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md).

Other reference evapotranspiration functions:
[`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md),
[`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md),
[`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md)

## Examples

``` r
# One synthetic station (fictitious values), 48 hourly records in UTC.
times <- as.POSIXct("2024-01-15 01:00", tz = "UTC") + 3600 * (0:47)
mid <- as.numeric(times) / 3600 - 0.5
sun <- pmax(0, cos((mid %% 24 - 16.8) * pi / 12))
st <- ef_station_table(
  stations = data.frame(station_id = "ST01", lon = -71.5, lat = -35.4,
                        elevation = 150, height_wind = 2,
                        height_temp_rh = 2),
  observations = data.frame(
    station_id = "ST01", timestamp = times,
    air_temperature = 14 + 12 * sun, relative_humidity = 80 - 45 * sun,
    wind_speed = 1 + 2 * sun, solar_radiation = 850 * sun
  ),
  provenance = list(timestamp_convention = "end", interval = 3600,
                    crs = "EPSG:4326")
)
et <- ef_station_ref_et(
  st, reference = "alfalfa", timestep = "hourly", standard = "asce",
  humidity = "relative_humidity", day_definition = "utc",
  day_completeness = "all_periods", daytime_rule = "ra_positive",
  night_cloudiness = "before_sunset",
  overpass = as.POSIXct("2024-01-15 14:48", tz = "UTC"),
  inst_method = "O3"
)
et$etr_inst
#>   station_id       overpass_time  etr_inst method
#> 1       ST01 2024-01-15 14:48:00 0.6835128     O3
et$etr_24
#>   station_id       date n_periods   etr_24
#> 1       ST01 2024-01-15        14       NA
#> 2       ST01 2024-01-16        24 6.164534
```
