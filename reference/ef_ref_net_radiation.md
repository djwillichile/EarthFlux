# Net radiation of the reference surface

Computes the net radiation \\R_n\\ of the hypothetical reference surface
(albedo 0.23) and its components, the net shortwave radiation
\\R\_{ns}\\ and the net outgoing longwave radiation \\R\_{nl}\\, for a
daily or an hourly time step and the explicit standard (FAO-56 or the
ASCE-EWRI standardized procedure). It is the net radiation entering
[`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md)
and
[`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md);
it is **not** the net radiation of a pixel
([`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)).

## Usage

``` r
ef_ref_net_radiation(
  solar_radiation,
  clear_sky_radiation,
  vapour_pressure,
  air_temperature = NULL,
  tmax = NULL,
  tmin = NULL,
  timestep,
  standard,
  cloudiness = NULL
)
```

## Arguments

- solar_radiation:

  Numeric. Measured (or estimated) solar radiation \\R_s\\ of the period
  \[MJ m-2 d-1 or MJ m-2 h-1\]. Must be finite and `>= 0`.

- clear_sky_radiation:

  Numeric or `NULL`. Clear-sky radiation \\R\_{so}\\ of the same period
  and unit, from
  [`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md).
  Must be finite and `> 0` where the cloudiness term is computed from
  \\R_s/R\_{so}\\. May be `NULL` only when `cloudiness` is supplied.

- vapour_pressure:

  Numeric. Actual vapour pressure \\e_a\\ \[kPa\] of the period (from
  [`ef_ea_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md)
  or
  [`ef_ea_rh()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md)).
  Must be finite and `>= 0`.

- air_temperature:

  Numeric or `NULL`. Mean hourly air temperature \[degrees Celsius\],
  required for `timestep = "hourly"` (and `NULL` for `"daily"`). Must be
  finite and `> -273.16`.

- tmax, tmin:

  Numeric or `NULL`. Daily maximum and minimum air temperatures
  \[degrees Celsius\], required for `timestep = "daily"` (and `NULL` for
  `"hourly"`). Finite, `> -273.16` and `tmin <= tmax`.

- timestep:

  Character, no default. `"daily"` (FAO-56 Eq. 39; ASCE-EWRI Eq. 17) or
  `"hourly"` (FAO-56 chapter 4, "Hourly time step"; ASCE-EWRI Eq. 44).

- standard:

  Character, no default. `"fao56"` or `"asce"` (ASCE-EWRI 2005
  standardized procedure). It selects the Stefan-Boltzmann constant and
  the limits of the relative solar radiation (see Details).

- cloudiness:

  Numeric or `NULL`. The cloudiness term \\f = 1.35 R_s/R\_{so} - 0.35\\
  \[-\] to use instead of computing it from `solar_radiation` and
  `clear_sky_radiation`, in \[-0.35, 1\] for `"fao56"` and in \[0.05,
  1\] for `"asce"` (the ranges of each standard). It serves night-time
  (and, for ASCE-EWRI, low sun angle) periods, where the ratio is
  undefined or unreliable and is carried from an earlier period (see
  Details). When supplied it is used at every position. Default `NULL`:
  computed from the radiation.

## Value

An object of class `earthflux_reference_net_radiation`: a list with

- `rn`: net radiation of the reference surface \\R_n\\;

- `rns`: net shortwave radiation \\R\_{ns}\\;

- `rnl`: net outgoing longwave radiation \\R\_{nl}\\;

- `cloudiness`: the cloudiness term \\f\\ used \[-\];

all numeric \[MJ m-2 d-1 or MJ m-2 h-1, the unit of `solar_radiation`\]
with the common length (and `dim`) of the inputs;

- `timestep`, `standard`;

- `flags`: list of `earthflux_flag` records (record scope) for the codes
  that hold somewhere: `EF_INPUT_NA` (a required input is missing) and
  `EF_WS_RS_RSO_LIMITED` (\\R_s/R\_{so}\\ outside the range of the
  standard, limited inside the cloudiness term);

- `provenance`: time step, standard, verification status, constants,
  source of the cloudiness term, references, `flags_evaluated` and
  package version.

## Details

\$\$R\_{ns} = (1 - \alpha) R_s, \quad \alpha = 0.23\$\$ (FAO-56, chapter
3, Eq. 38; ASCE-EWRI, 2005, Eqs. 16 and 43: albedo fixed at 0.23 for the
short and the tall reference, daily and hourly), \$\$R\_{nl} = \sigma
\frac{T\_{max,K}^4 + T\_{min,K}^4}{2} (0.34 - 0.14 \sqrt{e_a})
\left(1.35 \frac{R_s}{R\_{so}} - 0.35\right)\$\$ with \\T_K = T +
273.16\\ (FAO-56, chapter 3, Eq. 39; ASCE-EWRI Eqs. 17-18), and \\R_n =
R\_{ns} - R\_{nl}\\ (FAO-56 Eq. 40; ASCE-EWRI Eqs. 15 and 42). For the
hourly time step (FAO-56, chapter 4, "Hourly time step"; ASCE-EWRI Eqs.
44-45) the mean of the fourth powers is replaced by \\T\_{hr,K}^4\\.

**Constants and limits of each standard** (decision WF-14: the literals
of each standard are used as written):

|  |  |  |
|----|----|----|
|  | `"fao56"` | `"asce"` |
| \\\sigma\\, daily \[MJ K-4 m-2 d-1\] | 4.903e-9 (Eq. 39) | 4.901e-9 (Eq. 17, p. 19) |
| \\\sigma\\, hourly \[MJ K-4 m-2 h-1\] | 4.903e-9 / 24 | 2.042e-10 (Eq. 44, p. 34) |
| \\R_s/R\_{so}\\ in the cloudiness term | \\\le 1\\ (Eq. 39) | in \[0.3, 1\] (Eqs. 18 and 45, pp. 20 and 35) |
| cloudiness term \\f\\ | \[-0.35, 1\] | \[0.05, 1\] (Eqs. 17 and 44) |

The limits act only inside the cloudiness term; `solar_radiation` and
`rns` are not modified, and the positions where a limit acts are flagged
`EF_WS_RS_RSO_LIMITED`. The report is not consistent here: it states
that the ratio limits \\0.3 \le R_s/R\_{so} \le 1\\ give \\0.05 \le f
\le 1\\ (pp. 20 and 35), but \\1.35 \times 0.3 - 0.35 = 0.055\\. The
ratio limit is applied (so a computed term is at least 0.055), and a
supplied `cloudiness` is accepted in the stated range \[0.05, 1\]. The
two Stefan-Boltzmann values differ by 0.04 % (daily); the ASCE-EWRI
hourly value is the published one (4.901e-9 / 24 = 2.04208e-10).

**Night-time and low sun angle.** With \\R\_{so} = 0\\ the ratio is
undefined. FAO-56 sets it to the value of a period 2-3 hours before
sunset, identified by \\\omega_s - 0.79 \le \omega \le \omega_s -
0.52\\, or, approximately, to 0.4-0.6 in humid and sub-humid and 0.7-0.8
in arid and semi-arid climates (0.3 means complete cloud cover).
ASCE-EWRI (2005, Eq. 46, pp. 35-36) uses, for every period whose sun
angle at the midpoint is below 0.3 rad (night, dusk and dawn), the
cloudiness term of the last period before the sun angle fell below 0.3
rad. Selecting that value is the task of the station orchestration
([`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md),
argument `night_cloudiness`); here the resulting term is passed as
`cloudiness` (for a ratio \\r\\, `cloudiness = 1.35 * r - 0.35`).

**Normative constants.** \\\sigma\\ of each standard (FAO-56 4.903e-9 MJ
m-2 d-1 K-4, about 5.6748e-8 W m-2 K-4, 0.08 % below the CODATA value
used elsewhere in the package) and 273.16 in the conversion to kelvin,
as written in both standards; the package constants
(`EF_STEFAN_BOLTZMANN`, 273.15) are not used inside the reference
surface equations. \\R\_{nl}\\ is an empirical longwave balance of the
reference surface and is not interchangeable with the incoming and
emitted longwave radiation of a pixel.

Missing values propagate (and are flagged `EF_INPUT_NA`). Missing,
unknown or inconsistent `timestep`, `standard` and temperature arguments
raise `earthflux_missing_input`, `earthflux_unknown_method` or
`earthflux_input_error`; values outside the domains above (including
\\R\_{so} = 0\\ without `cloudiness`, and `tmin > tmax`) raise
`earthflux_domain_error`.

## Verification status

`standard = "fao56"`: `VERIFICADA` (FAO-56, chapter 3, Eqs. 38-40;
chapter 4, hourly time step; cases V10, V11, V14, V15 and V16 of
dev/specs/weather-forcing.md 8.1). `standard = "asce"`: `VERIFICADA`
(ASCE-EWRI, 2005, Eqs. 15-18, pp. 17-20, and Eqs. 42-45, pp. 32-35).

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
[`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md),
[`ef_station_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_station_ref_et.md)

## Examples

``` r
# FAO-56 example 18 (Uccle, 6 July): daily step
rn <- ef_ref_net_radiation(
  solar_radiation = 22.07, clear_sky_radiation = 30.90,
  vapour_pressure = 1.409, tmax = 21.5, tmin = 12.3, timestep = "daily",
  standard = "fao56"
)
rn$rn
#> [1] 13.28291

# Same inputs with the ASCE-EWRI constants (sigma = 4.901e-9)
ef_ref_net_radiation(
  solar_radiation = 22.07, clear_sky_radiation = 30.90,
  vapour_pressure = 1.409, tmax = 21.5, tmin = 12.3, timestep = "daily",
  standard = "asce"
)$rn
#> [1] 13.28443

# FAO-56 example 19, 02:00-03:00: night, Rs/Rso = 0.8 carried
ef_ref_net_radiation(
  solar_radiation = 0, clear_sky_radiation = NULL,
  vapour_pressure = 3.402, air_temperature = 28, timestep = "hourly",
  standard = "fao56", cloudiness = 1.35 * 0.8 - 0.35
)$rn
#> [1] -0.1003213
```
