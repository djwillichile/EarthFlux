# Standard table of weather station data

Builds the standard station table of EarthFlux: the metadata of the
weather stations (`stations`, one row per station) and their
observations (`observations`, one row per station and timestamp), joined
by `station_id`, together with the provenance of the data. The
constructor normalises the inputs (plain data frames, timestamps in UTC,
declared unit conversions), removes exact duplicated records and
validates the contract. It never guesses units or time zones and never
corrects values: impossible metadata are errors, while impossible or
suspicious observations are kept and flagged by
[`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md).

## Usage

``` r
ef_station_table(
  stations,
  observations,
  provenance,
  units = NULL,
  timestamp_format = NULL,
  tz = NULL
)
```

## Arguments

- stations:

  A data frame with one row per station. Required columns: `station_id`
  (character, unique, not missing), `lon` and `lat` (decimal degrees,
  WGS84; longitude in \[-180, 180\], east positive; latitude in \[-90,
  90\], north positive) and `elevation` (finite, m above sea level).
  Conditionally required: `height_wind` (anemometer height \[m above
  ground\], `> 0.0947` m, the domain of FAO-56 Eq. 47) when
  `observations` has `wind_speed`, and `height_temp_rh` (height of the
  temperature and humidity sensors \[m above ground\], `> 0`) when
  `observations` has any temperature or humidity variable. Heights may
  be `NA` (unknown); such records are flagged by
  [`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md).
  Optional columns: `surface_type` (one of `"reference_grass"`,
  `"reference_alfalfa"`, `"irrigated_other"`, `"non_reference"`,
  `"unknown"`; stored as a factor), and the character columns `network`,
  `provider`, `license`, `terms_url`, `name` and `notes`. Other columns
  are rejected.

- observations:

  A data frame with one row per station and timestamp. Required columns:
  `station_id` (character, present in `stations`) and `timestamp`
  (`POSIXct` with an explicit time zone, or character with
  `timestamp_format` and `tz`), plus at least one measured variable.
  Measured variables (numeric; contract units): `air_temperature`
  \[degC\], `relative_humidity` \[%\], `dewpoint_temperature` \[degC\],
  `vapour_pressure` \[kPa\], `wind_speed` \[m s-1\] (at `height_wind`),
  `solar_radiation` \[W m-2\] (global irradiance on a horizontal plane,
  mean of the period), `air_pressure` \[kPa\], `precipitation` \[mm\],
  `net_radiation` \[W m-2\], and for daily data `tmax`, `tmin` \[degC\],
  `rh_max`, `rh_min` \[%\]. Missing values are allowed. Other columns
  are rejected.

- provenance:

  A named list describing the data. Required fields:
  `timestamp_convention` (`"end"`, `"start"` or `"instant"`: whether the
  timestamp marks the end or the start of the averaging period, or an
  instantaneous value), `interval` (time step of the records in seconds,
  a positive whole number, e.g. `3600`) and `crs` (the coordinate
  reference system of `lon`/`lat`; must be `"EPSG:4326"`). Recommended
  fields: `source` (file, URL or API), `retrieved` (date of download or
  reading), `source_hash`, `network`, `provider`, `license`. Any other
  named field is kept; the fields `source_tz`, `units`,
  `duplicates_removed`, `package_version`, `operations`, `qc`, `flags`
  and `flags_evaluated` are reserved (set by the package).

- units:

  `NULL` (all variables already in contract units) or a named list (or
  named character vector) declaring the source unit of some measured
  variables, which are then converted to the contract unit and recorded
  in the provenance. Accepted declarations: temperatures `"degC"` or
  `"K"`; humidities `"%"` or `"fraction"`; pressures `"kPa"`, `"hPa"` or
  `"Pa"`; `wind_speed` `"m/s"` or `"km/h"`; radiation `"W/m2"`,
  `"MJ/m2/h"` or `"MJ/m2/d"` (rates); `precipitation` `"mm"`.

- timestamp_format, tz:

  Only for character timestamps, and then both required (no default):
  the format passed to
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) (e.g.
  `"%Y-%m-%d %H:%M"`) and the IANA time zone of the strings (e.g.
  `"UTC"`, `"Etc/GMT+4"`, `"America/Santiago"`; see
  [`OlsonNames()`](https://rdrr.io/r/base/timezones.html)).

## Value

An object of class `c("earthflux_station_table", "list")` with elements:

- `stations`: data frame of the stations, with the columns supplied
  (`surface_type` as a factor with the five levels above);

- `observations`: data frame of the records, in the order supplied
  (exact duplicates removed), `timestamp` as `POSIXct` in UTC and the
  measured variables as double in contract units;

- `provenance`: the list supplied plus `source_tz` (time zone of the
  input timestamps), `units` (data frame `variable`, `source_unit`,
  `unit`, `scale`, `offset`), `duplicates_removed` (number of exact
  duplicated records removed), `package_version` and `operations` (a
  data frame log with columns `step` and `detail`);

- `qc`: the long audit table of quality control flags, with zero rows
  until
  [`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md)
  is run (columns described there);

- `flags`: an empty list of diagnostic flag records.

## Details

**Time** (dev/specs/weather-forcing.md section 2.4). Timestamps are
stored as `POSIXct` in UTC. A `POSIXct` input must carry an explicit
time zone (a non-empty `tzone` attribute); character input is parsed
with the declared `timestamp_format` and `tz`, and any string that does
not parse (including local times that do not exist because of a daylight
saving change) is an error. Local times that occur twice at the end of
daylight saving time are resolved by
[`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html); to avoid the
ambiguity give UTC or a fixed-offset zone such as `"Etc/GMT+4"`. For
averages over a period the mid-point is `timestamp - interval / 2`
(`"end"`) or `timestamp + interval / 2` (`"start"`); FAO-56 Eq. 31 uses
the time at the mid-point of the period.

**Duplicates.** Records with the same `station_id` and `timestamp` and
identical values are kept once and counted in
`provenance$duplicates_removed`; duplicates with different values are an
error (they are never averaged).

**Domain.** Impossible metadata are errors of class
`earthflux_domain_error`: coordinates out of range, non-finite
elevation, heights at or below their bound. Infinite observed values are
also errors. Physically impossible observations (e.g. a negative
relative humidity) are not errors here: they are kept and flagged with
severity `critical` by
[`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md)
(decision WF-04), so that one record does not stop a long series.

**Errors.** All errors inherit `earthflux_input_error`. Specific
classes: `earthflux_station_field_error` (missing, unknown or mistyped
field, zero rows, missing value in a required field),
`earthflux_station_time_error` (timestamp without explicit time zone,
unparsable timestamp, invalid `timestamp_convention` or `interval`),
`earthflux_station_unknown_id` (observations of a station not in
`stations`), `earthflux_station_duplicate` (duplicated `station_id` in
`stations`, or duplicated records with different values),
`earthflux_station_provenance_error` (provenance not a named list,
missing or unsupported `crs`, reserved fields) and
`earthflux_domain_error`.

Not covered yet: readers for the files or services of specific networks
(their access, licences, time zones and sensor heights are open items,
dev/specs/weather-forcing.md section 9) and the vertical datum of the
elevation.

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration - Guidelines for computing crop water requirements*.
FAO Irrigation and Drainage Paper 56. FAO, Rome. ISBN 92-5-104219-5.

## See also

[`ef_station_qc()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_qc.md)
for the quality control of the table.

## Examples

``` r
# A tiny synthetic data set (fictitious stations).
stations <- data.frame(
  station_id = c("ST01", "ST02"),
  lon = c(-71.50, -71.20), lat = c(-35.40, -35.10),
  elevation = c(150, 420),
  height_wind = c(2, 10), height_temp_rh = c(2, 2)
)
times <- as.POSIXct("2024-01-15 13:00", tz = "UTC") + 3600 * 0:2
observations <- data.frame(
  station_id = rep(c("ST01", "ST02"), each = 3),
  timestamp = rep(times, 2),
  air_temperature = c(24.1, 25.3, 26.0, 21.8, 22.9, 23.5),
  relative_humidity = c(45, 41, 38, 52, 48, 46),
  wind_speed = c(2.1, 2.6, 3.0, 3.4, 3.9, 4.1)
)
st <- ef_station_table(
  stations, observations,
  provenance = list(timestamp_convention = "end", interval = 3600,
                    crs = "EPSG:4326", source = "synthetic example")
)
st
#> <earthflux_station_table>
#> Stations: 2 (coordinates EPSG:4326)
#> Records: 6, 2024-01-15 13:00:00 to 2024-01-15 15:00:00 UTC (source time zone: UTC)
#> Time step: 3600 s; timestamps mark the end of each period
#> Variables: air_temperature [degC], relative_humidity [%], wind_speed [m/s] 
#> Quality control: not run (see ef_station_qc())

# Declared conversion: wind speed recorded in km/h.
obs_kmh <- observations
obs_kmh$wind_speed <- obs_kmh$wind_speed * 3.6
st2 <- ef_station_table(
  stations, obs_kmh,
  provenance = list(timestamp_convention = "end", interval = 3600,
                    crs = "EPSG:4326"),
  units = list(wind_speed = "km/h")
)
st2$provenance$units
#>            variable source_unit unit     scale offset
#> 1   air_temperature        degC degC 1.0000000      0
#> 2 relative_humidity           %    % 1.0000000      0
#> 3        wind_speed        km/h  m/s 0.2777778      0
```
