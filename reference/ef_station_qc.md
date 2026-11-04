# Quality control of the standard station table

Runs the quality control tests of the station data
(dev/specs/weather-forcing.md section 3) on an `earthflux_station_table`
and returns the table with the audit of every condition found, the
diagnostic flag records and the status of each observed value under an
explicit QC policy. Values are **never** deleted or modified:
`observations` is returned unchanged.

## Usage

``` r
ef_station_qc(x, qc_policy = "exclude_critical")
```

## Arguments

- x:

  An `earthflux_station_table` built with
  [`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md)
  (or the result of a previous `ef_station_qc()`, which is recomputed).

- qc_policy:

  Character. Which flagged values are excluded: `"exclude_critical"`
  (default; the values with a `critical` flag, i.e. physical or logical
  impossibilities), `"exclude_warning"` (values with a `critical` or
  `warning` flag) or `"keep_all"` (no exclusion; for audit). Exact
  match.

## Value

An object of class
`c("earthflux_station_qc", "earthflux_station_table", "list")`: the
elements of `x` (`stations` and `observations` unchanged) plus

- `qc`: the long audit table, one row per record, variable and flag code
  that holds, with columns `row` (row of `observations`), `station_id`,
  `timestamp` (UTC), `variable` (the observed variable, or `"timestamp"`
  for the time tests), `flag_code` (a registered code), `severity`,
  `test_id` (test of dev/specs/weather-forcing.md section 3.2), `value`
  (the value tested: the variable, the height, or the seconds since the
  previous record), `threshold` (the bound it was compared with: a
  domain limit, 100 %, the other variable of a consistency test, the
  standard height or the time step; `NA` if none) and `parameters`
  (`NA`: no class II parameter is used);

- `flags`: one `earthflux_flag` record (scope `record`, `index` = rows
  of `observations`, `n_total` = number of records) per code that holds
  somewhere; the rows of `qc` with that code are exactly its `index`;

- `qc_status`: a data frame with `station_id`, `timestamp` and one
  factor column per observed variable (levels `"ok"`, `"warning"`,
  `"excluded"`), aligned with the rows of `observations`;

- `provenance`: the provenance of `x` with `flags_evaluated` (codes
  evaluated), `flags` (registry rows of the codes evaluated, policy and
  counts; dev/specs/flags.md section 6.7), `qc` (policy, counts by code,
  values excluded by variable, tests not evaluated) and a new row in
  `operations`.

## Details

Tests evaluated (codes registered in the flag registry; severity in
brackets):

- `EF_WS_OUT_OF_DOMAIN` \[critical\] (QC-01a): physically impossible
  value: relative humidity (`relative_humidity`, `rh_max`, `rh_min`)
  `< 0`, `wind_speed < 0`, temperature (`air_temperature`,
  `dewpoint_temperature`, `tmax`, `tmin`) `<= -273.15` degC,
  `air_pressure <= 0`, `vapour_pressure < 0`, `solar_radiation < 0`,
  `precipitation < 0`. A negative solar radiation (for example the
  night-time offset of a thermopile pyranometer) is excluded by the
  default policy; it is not set to zero.

- `EF_WS_TMIN_GT_TMAX` \[critical\] (QC-03): `tmin > tmax` in the same
  record; both variables are flagged.

- `EF_WS_RH_GT100` \[info\] (QC-02): relative humidity `> 100` %. Values
  slightly above 100 % occur (e.g. early morning or rain); FAO-56 Annex
  5 relates records exceeding 100 % by more than 3-5 % to a need of
  recalibration, a class II test not evaluated until its margin is
  chosen (WF-06).

- `EF_WS_TDEW_GT_TAIR` \[warning\] (QC-04):
  `dewpoint_temperature > air_temperature`, or `vapour_pressure` greater
  than the saturation vapour pressure at `air_temperature` (\\e_a \>
  e^\circ(T)\\,
  [`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md)),
  without tolerance (both are equivalent to a relative humidity above
  100 %, FAO-56 Eqs. 10, 11 and 14); the variables compared are flagged
  (the air temperature once per record). The threshold is the air
  temperature for the dew point, \\e^\circ(T)\\ for the vapour pressure
  and the dew point of the vapour pressure
  ([`ef_dewpoint()`](https://djwillichile.github.io/EarthFlux/reference/ef_dewpoint.md))
  for the air temperature.

- `EF_WS_RS_GT_RA` \[warning\] (QC-05b): the mean `solar_radiation` of
  the record is greater than the mean extraterrestrial radiation of the
  same time window (the window of `interval` seconds of the record,
  located by `timestamp_convention`). The extraterrestrial radiation is
  the integral of FAO-56 Eq. 28 over the part of the window with the sun
  above the horizon (for a one-day window, Eq. 21). Windows with the sun
  below the horizon during the whole window (night-time radiation, test
  QC-05d, class II) are not tested. Evaluated for period means
  (`timestamp_convention` `"end"` or `"start"`) with an `interval` of at
  most one day.

- `EF_WS_TIME_GAP` \[warning\] and `EF_WS_TIME_IRREGULAR` \[warning\]
  (QC-09), per station in time order: the time since the previous record
  is a whole multiple (two or more) of the declared `interval` (gap: the
  record after the gap is flagged), or not a whole multiple (irregular
  step); variable `"timestamp"`. Missing time steps are never filled.

- `EF_WS_HEIGHT_MISSING` \[warning\] and `EF_WS_HEIGHT_NONSTANDARD`
  \[warning\] (QC-11): a non-missing value whose measurement height is
  `NA` (`height_wind` for `wind_speed`; `height_temp_rh` for temperature
  and humidity variables), or temperature and humidity measured at a
  height different from 2 m (FAO-56 chapters 2-3); no correction is
  applied.

A code is evaluated only when the variables it needs are present; the
codes evaluated are listed in `provenance$flags_evaluated`, so that
"evaluated and absent" is distinguishable from "not evaluated".

Not evaluated: the class II tests of dev/specs/weather-forcing.md
section 3.2 (plausible ranges, recalibration margin of the humidity
sensor, clear-sky envelope and calibration of the pyranometer, night
radiation, persistence, steps, low maximum humidity, non-reference
conditions, diurnal stability of the vapour pressure, time shift,
spatial consistency, cloudy overpass): they need thresholds with a
documented reference that are not available, so their codes are not
registered and no threshold is assumed. Also not evaluated here:
`EF_WS_INCOMPLETE_DAY` (QC-10), which depends on the definition of the
day and is raised by the daily sums of
[`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md).
They are listed in `provenance$qc$not_evaluated` (with `EF_WS_RS_GT_RA`
when the table has solar radiation that cannot be tested).

**Status and policy.** The status of an observed value is the highest
severity among the flags of its record that concern its variable or the
timestamp: `"excluded"` if that severity is excluded by `qc_policy`,
`"warning"` if it is `warning` (or `critical` under `"keep_all"`), and
`"ok"` otherwise (no flag or `info`). Missing values keep the status of
their record. Excluding is not deleting: `observations` keeps the value
and the flag that motivated the exclusion is kept; the counts are in
`provenance$qc`.

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration - Guidelines for computing crop water requirements*.
FAO Irrigation and Drainage Paper 56. FAO, Rome. ISBN 92-5-104219-5.

## See also

[`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md),
[`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md).

## Examples

``` r
stations <- data.frame(
  station_id = "ST01", lon = -71.5, lat = -35.4, elevation = 150,
  height_wind = 2, height_temp_rh = 2
)
times <- as.POSIXct("2024-01-15 13:00", tz = "UTC") + 3600 * c(0, 1, 3)
observations <- data.frame(
  station_id = "ST01", timestamp = times,
  air_temperature = c(24.1, 25.3, 26.0),
  relative_humidity = c(45, -3, 101),
  wind_speed = c(2.1, 2.6, 3.0)
)
st <- ef_station_table(
  stations, observations,
  provenance = list(timestamp_convention = "end", interval = 3600,
                    crs = "EPSG:4326")
)
qc <- ef_station_qc(st)
qc
#> <earthflux_station_qc>
#> Stations: 1 (coordinates EPSG:4326)
#> Records: 3, 2024-01-15 13:00:00 to 2024-01-15 16:00:00 UTC (source time zone: UTC)
#> Time step: 3600 s; timestamps mark the end of each period
#> Variables: air_temperature [degC], relative_humidity [%], wind_speed [m/s] 
#> Quality control: policy "exclude_critical"; 6 code(s) evaluated
#>   EF_WS_OUT_OF_DOMAIN        critical 1 record(s), 1 value(s)
#>   EF_WS_RH_GT100             info     1 record(s), 1 value(s)
#>   EF_WS_TIME_GAP             warning  1 record(s), 1 value(s)
#> Values excluded: 1; with warning: 3 (see `qc_status`)
qc$qc
#>   row station_id           timestamp          variable           flag_code
#> 1   2       ST01 2024-01-15 14:00:00 relative_humidity EF_WS_OUT_OF_DOMAIN
#> 2   3       ST01 2024-01-15 16:00:00 relative_humidity      EF_WS_RH_GT100
#> 3   3       ST01 2024-01-15 16:00:00         timestamp      EF_WS_TIME_GAP
#>   severity test_id value threshold parameters
#> 1 critical  QC-01a    -3         0       <NA>
#> 2     info   QC-02   101       100       <NA>
#> 3  warning   QC-09  7200      3600       <NA>
qc$qc_status
#>   station_id           timestamp air_temperature relative_humidity wind_speed
#> 1       ST01 2024-01-15 13:00:00              ok                ok         ok
#> 2       ST01 2024-01-15 14:00:00              ok          excluded         ok
#> 3       ST01 2024-01-15 16:00:00         warning           warning    warning
```
