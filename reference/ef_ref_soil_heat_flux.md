# Soil heat flux of the reference surface

Computes the soil heat flux \\G\\ of the hypothetical reference surface
from its net radiation, with the ratios of the reference
evapotranspiration standards: zero for daily periods, and a fixed
fraction of the net radiation, different by day and by night, for hourly
periods. It is the soil heat flux entering
[`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md);
it is **not** a method for the soil heat flux of a pixel
([`ef_g()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md)).

## Usage

``` r
ef_ref_soil_heat_flux(
  net_radiation,
  reference,
  timestep,
  standard,
  daytime = NULL
)
```

## Arguments

- net_radiation:

  Numeric. Net radiation of the reference surface \\R_n\\ \[MJ m-2 d-1
  or MJ m-2 h-1\], for example `ef_ref_net_radiation()$rn`. Any finite
  value.

- reference:

  Character, no default. Reference crop: `"grass"` (short reference,
  0.12 m) or `"alfalfa"` (tall reference, about 0.5 m).

- timestep:

  Character, no default. `"daily"` or `"hourly"`.

- standard:

  Character, no default. `"fao56"` (FAO-56, grass only) or `"asce"`
  (ASCE-EWRI 2005 standardized equation).

- daytime:

  Logical or `NULL`. For `timestep = "hourly"`, `TRUE` for daytime and
  `FALSE` for night-time periods (required); must be `NULL` for
  `"daily"`. `NA` gives `NA`. The criterion is the caller's choice
  (decision WF-15): FAO-56 speaks of "daylight periods" without a
  threshold; ASCE-EWRI (2005) defines daytime as a positive hourly net
  radiation, `daytime = net_radiation > 0` (see Details).

## Value

A numeric vector of soil heat flux of the reference surface \\G\\ in the
unit of `net_radiation`, with the common length of the inputs, keeping
their `dim`. For daily periods it is 0 (and `NA` where `net_radiation`
is `NA`).

## Details

\\G = c_G R_n\\ with \\c_G\\ from the internal constants table of the
reference equations (dev/specs/weather-forcing.md 5.3):

|                     |            |                |               |              |
|---------------------|------------|----------------|---------------|--------------|
| Reference, standard | Daily      | Hourly, day    | Hourly, night | Status       |
| grass, `"fao56"`    | 0 (Eq. 42) | 0.1 (Eq. 45)   | 0.5 (Eq. 46)  | `VERIFICADA` |
| grass, `"asce"`     | 0 (Eq. 30) | 0.1 (Eq. 65a)  | 0.5 (Eq. 65b) | `VERIFICADA` |
| alfalfa, `"asce"`   | 0 (Eq. 30) | 0.04 (Eq. 66a) | 0.2 (Eq. 66b) | `VERIFICADA` |

FAO-56 (Eq. 42) and ASCE-EWRI (2005, Eq. 30, p. 25) state that the daily
soil heat flux beneath the reference surface is small and is ignored (G
= 0). The monthly forms (FAO-56 Eqs. 43-44; ASCE-EWRI Eqs. 31-32) are
out of scope.

**Day and night in ASCE-EWRI (2005).** The report defines daytime as a
positive mean net radiation of the hourly period (text before Table 1,
p. 5; Table 2, p. 5: daytime \\R_n \> 0\\, night-time \\R_n \le 0\\),
which `daytime = net_radiation > 0` follows (option `"rn_positive"` of
[`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md)).
The report is not consistent at \\R_n = 0\\: p. 44 (after Eqs. 65-66)
and the glossary (p. 58) define night-time as \\R_n \< 0\\ and daytime
as \\R_n \ge 0\\. At \\R_n = 0\\ G is 0 under both readings; only
\\C_d\\ of
[`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md)
depends on it.

`standard = "fao56"` with `reference = "alfalfa"` raises
`earthflux_undefined_reference` (also `earthflux_input_error`): FAO-56
does not define the tall reference.

Missing values propagate. Missing or unknown choices raise
`earthflux_missing_input` or `earthflux_unknown_method`; a missing or
non-logical `daytime` where required, or a `daytime` given for a daily
step, raise `earthflux_input_error` (or `earthflux_missing_input`);
infinite `net_radiation` raises `earthflux_domain_error`.

## Verification status

FAO-56 grass rows: `VERIFICADA` (FAO-56, chapter 4, Eqs. 42, 45, 46;
cases V15 and V16). ASCE-EWRI rows: `VERIFICADA` (ASCE-EWRI, 2005, Eq.
30, p. 25; Eqs. 65a-b and 66a-b, p. 44).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
Equation*. Task Committee on Standardization of Reference
Evapotranspiration, Environmental and Water Resources Institute of the
American Society of Civil Engineers. Final report, January 2005.
Published as Allen, R. G., Walter, I. A., Elliott, R. L., Howell, T. A.,
Itenfisu, D., Jensen, M. E., & Snyder, R. L. (Eds.), American Society of
Civil Engineers, Reston, VA.
[doi:10.1061/9780784408056](https://doi.org/10.1061/9780784408056)

## See also

Other reference evapotranspiration functions:
[`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md),
[`ef_ref_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_net_radiation.md),
[`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md)

## Examples

``` r
# FAO-56 example 19: daytime (Rn = 1.749) and night (Rn = -0.100) hours
ef_ref_soil_heat_flux(c(1.749, -0.100), reference = "grass",
                      timestep = "hourly", standard = "fao56",
                      daytime = c(TRUE, FALSE))
#> [1]  0.1749 -0.0500

# Tall reference, ASCE-EWRI daytime rule (Rn > 0)
rn <- c(1.749, -0.100)
ef_ref_soil_heat_flux(rn, reference = "alfalfa", timestep = "hourly",
                      standard = "asce", daytime = rn > 0)
#> [1]  0.06996 -0.02000

# Daily step: G = 0
ef_ref_soil_heat_flux(13.28, reference = "grass", timestep = "daily",
                      standard = "fao56")
#> [1] 0
```
