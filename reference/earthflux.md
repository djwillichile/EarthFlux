# Actual evapotranspiration of a scene with a preset

Runs the complete METRIC workflow for one area and one date: downloads
and prepares the MODIS surface state (LST of Terra or Aqua, whichever
was observed closer to nadir, albedo, NDVI, LAI) and the NASADEM
elevation model on the native 1 km MODIS grid, prepares the weather
forcing from a station table or from ERA5 (Open-Meteo), regionalizes the
reference evapotranspiration and the wind, selects the anchor pixels,
calibrates the sensible heat flux and returns the daily actual
evapotranspiration with every intermediate layer, the objects of each
stage, flags and provenance.

Every scientific option is set by the **preset** (no default, decision
M5-04): see
[`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md)
for the list and
[`ef_preset()`](https://djwillichile.github.io/EarthFlux/reference/ef_preset.md)
for every option of one preset. The same computation can be run step by
step with the `ef_*()` functions (expert level).

## Usage

``` r
earthflux(
  aoi,
  date,
  weather,
  preset,
  cache_dir = tools::R_user_dir("EarthFlux", "cache"),
  apikey = NULL,
  surface = NULL,
  terrain = NULL
)
```

## Arguments

- aoi:

  Area of interest: a `SpatVector` of polygons in any CRS (e.g. read
  with
  [`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html)).
  It must lie in one MODIS sinusoidal tile (tile mosaics are not
  assembled yet); the result is `NA` outside the polygon.

- date:

  `Date` of the scene (UTC day of the MODIS LST). No default.

- weather:

  The weather source, no default: `"era5"` for hourly ERA5 data
  downloaded from the Open-Meteo historical weather API (no credential;
  CC BY 4.0, non-commercial use of the free API, decision M5-07), or an
  hourly station table built with
  [`ef_station_table()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_table.md).
  With one station its values are used over the whole area (C1); with
  several stations (or ERA5 cells) they are interpolated by inverse
  distance weighting as the preset says (C2). The stations must cover
  the overpass time, the local day of the scene and the 24 hours before
  it.

- preset:

  Character, no default: the name of a preset (`"idaho2002_elev"` or
  `"idaho2002_flat"`, see
  [`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md)).

- cache_dir:

  Character. Directory of the download cache (MODIS, NASADEM and
  Open-Meteo files), default `tools::R_user_dir("EarthFlux", "cache")`.
  Valid cached files are reused without network access.

- apikey:

  `NULL` (default) or the key of the Open-Meteo customer API (commercial
  use), used only with `weather = "era5"`. It is sent only to the API
  and never stored: the provenance records `apikey_used`.

- surface:

  `NULL` (default: downloaded and prepared) or an
  `earthflux_surface_state` prepared beforehand with the MODIS options
  of the preset (expert route).

- terrain:

  `NULL` (default: downloaded and prepared) or an `earthflux_terrain` on
  the working grid of `surface` (expert route).

## Value

An object of class `earthflux_result` (a list):

- `layers`: `SpatRaster` on the working grid (MODIS sinusoidal, about 1
  km), `NA` outside the AOI polygon and on the cells excluded by the
  terrain rule of the preset, with the layers `eta_24` (daily actual ET,
  mm d-1), `etrf` (-), `et_inst` (mm h-1), `le`, `h`, `g`, `rn` (W m-2),
  `rah` (s m-1), `dt` (K), `rs_in`, `rl_in`, `rl_out` (W m-2), `tau_sw`
  (-), `zom` (m), `u_blend`, `u_star` (m s-1), `ts_datum` (K),
  `air_density` (kg m-3), `pressure` (kPa), `etr_inst` (mm h-1) and
  `etr_24` (mm d-1) of the reference (alfalfa);

- `units`: named character vector of the units of `layers`;

- `surface` (`earthflux_surface_state`), `terrain`
  (`earthflux_terrain`), `weather` (the station table, its QC and the
  reference ET of the stations,
  [`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md)),
  `forcing` (the regionalized surfaces of `etr_inst`, `wind_speed_2m`
  and `etr_24` at their target times, the method and the mid-points),
  `anchors` (`earthflux_anchors` with their boundary conditions) and
  `h_calibration` (`earthflux_h_calibration`);

- `qa`: flag words per stage, never combined bit by bit: `surface` (the
  words of the surface state), `forcing` (GWR stage, one layer per
  variable at the overpass time of each cell), `metric` (`flags_rad`,
  `flags_g`, `flags_h`, `flags_et`) and their `flag_bits`; on the cells
  excluded by the terrain rule only `flags_h` is defined (bit of
  `EF_H_TERRAIN_RULE_APPLIED`);

- `flags`: `earthflux_flag` records of the run: object and record flags
  of the forcing (e.g. `EF_WS_GRIDDED_FORCING`,
  `EF_GWR_SINGLE_STATION`), the anchors and the calibration, and the
  cell flags of the METRIC chain on the cells of the grid (with `target`
  = layer);

- `provenance`: the preset (name, version, changes between versions,
  status, unverified elements), every effective option, the values
  derived for the scene (the LST product used and, with the automatic
  choice, the statistics of both candidates (`lst_choice`), the view
  angle of the LST (`view_angle`: median, threshold, flagged cells,
  warning), overpass times, day and UTC offset of the daily reference
  ET, regionalization method, datum elevation, the terrain rule: its
  method, reference elevations (anchors of the preliminary selection and
  the station), limit, kept range and the elevations of the final
  anchors, ...), the counts of excluded cells (among them
  `view_angle_high`, the cells of the AOI flagged
  `EF_SURF_VIEW_ANGLE_HIGH`, `terrain_rule_excluded`, split into
  `terrain_rule_excluded_below` and `terrain_rule_excluded_above` the
  range, and the cells raised to the minimum z_om), the MODIS granules,
  the NASADEM tiles, the Open-Meteo request (without key) or the station
  table, attributions, the codes evaluated, versions, the `future` plan
  and timings.

## Details

Order of the workflow (dev/specs/presets.md section 2): (1) area checks
and refusal of areas over several MODIS tiles **before any download**;
(2) MODIS search, download and surface state; the presets download the
LST of Terra (MOD11A1) and Aqua (MYD11A1) and use the one with the
lowest median absolute view zenith angle over the area among those with
at least 80 % of valid LST cells (decision M5-27); (3) cells outside the
AOI polygon and cells with a critical surface flag (albedo above 1) are
excluded and counted; the LST cells observed at more than the view angle
threshold of the preset (40 degrees) are flagged
`EF_SURF_VIEW_ANGLE_HIGH` and hold no anchor, and a warning of class
`earthflux_view_angle_warning` is emitted when the median of the scene
is above it (decision M5-26; if no cell is left for an anchor, the run
stops with an `earthflux_anchor_error`); (4) NASADEM elevation on the
working grid (cells below the minimum valid fraction excluded); (5)
weather table (station table or ERA5) and its quality control; (6)
hourly and daily alfalfa reference ET of the stations; (7)
regionalization of the hourly reference ET and wind at the hourly
mid-points around the overpass and of the daily reference ET; each cell
takes the values at its own overpass time (linear interpolation between
mid-points); (8) solar geometry, pressure, roughness and wind at 200 m;
(9) anchors, selected before the net radiation because the incoming
longwave uses the temperature of the cold anchor (P0-3), outside the
cells excluded by the terrain rule of the preset (decision M5-25:
elevation more than 500 m, `idaho2002_elev`, or 250 m, `idaho2002_flat`,
below or above the elevation range of the calibration, i.e. the cold and
hot anchors of a preliminary selection without the rule and, with one
station, the station; cells between the anchors are kept; the excluded
cells are not computed, are `NA` in every layer and are flagged with
`EF_H_TERRAIN_RULE_APPLIED`); (10) shortwave and longwave radiation, net
radiation, soil heat flux; (11) boundary conditions at the anchors and
calibration of dT; (12) LE, instantaneous ET, ETrF and daily ETa. Values
are never filled or truncated: excluded or undefined cells are `NA` and
flagged or counted.

Errors: missing or unknown `preset` (`earthflux_missing_input`,
`earthflux_unknown_method`), invalid inputs (`earthflux_input_error`),
an AOI over several tiles (`earthflux_method_not_implemented`), weather
that does not cover the scene (`earthflux_weather_coverage_error`),
missing Earthdata token (`earthflux_credentials_error`), download
failures (`earthflux_download_error`), anchors without candidates
(`earthflux_anchor_no_candidates`) and the errors of the stages.

## Verification status

The workflow only orchestrates; the status of each formulation is that
of the function used. The status of the preset as a whole (today
`CANDIDATA` for both) is recorded in the provenance and announced by a
warning of class `earthflux_unverified_preset_warning` that lists the
unverified elements (decision M5-08). Results are not validated
(milestone M6).

## Credentials and licences

MODIS and NASADEM need a NASA Earthdata token in the environment
variable `EARTHDATA_TOKEN` (generate it at urs.earthdata.nasa.gov). The
token is never printed, stored or written to the cache. ERA5 data from
Open-Meteo are licensed CC BY 4.0 (attribution in the provenance); the
free API is for non-commercial use.

## References

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

## See also

[`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md),
[`ef_preset()`](https://djwillichile.github.io/EarthFlux/reference/ef_preset.md);
the `ef_*()` functions for the expert level.

Other workflow functions:
[`ef_preset()`](https://djwillichile.github.io/EarthFlux/reference/ef_preset.md),
[`ef_presets()`](https://djwillichile.github.io/EarthFlux/reference/ef_presets.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Needs network access and EARTHDATA_TOKEN (NASA Earthdata).
aoi <- terra::vect(terra::ext(-72.8, -71.9, -36.3, -35.6),
                   crs = "EPSG:4326")
res <- earthflux(aoi, date = as.Date("2019-02-14"), weather = "era5",
                 preset = "idaho2002_elev")
res
summary(res)
plot(res)
} # }
```
