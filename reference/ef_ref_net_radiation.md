# Net radiation of the reference surface

Computes the net radiation \\R_n\\ of the hypothetical reference surface
of FAO-56 (albedo 0.23) and its components, the net shortwave radiation
\\R\_{ns}\\ and the net outgoing longwave radiation \\R\_{nl}\\, for a
daily or an hourly time step. It is the net radiation entering
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

  Character, no default. `"daily"` (FAO-56 Eq. 39) or `"hourly"` (FAO-56
  chapter 4, "Hourly time step").

- cloudiness:

  Numeric or `NULL`. The cloudiness term \\f = 1.35 R_s/R\_{so} - 0.35\\
  \[-\] to use instead of computing it from `solar_radiation` and
  `clear_sky_radiation`, in \[-0.35, 1\]. It serves night-time periods,
  where \\R\_{so} = 0\\ and FAO-56 carries the ratio of a period before
  sunset (see Details). When supplied it is used at every position.
  Default `NULL`: computed from the radiation.

## Value

An object of class `earthflux_reference_net_radiation`: a list with

- `rn`: net radiation of the reference surface \\R_n\\;

- `rns`: net shortwave radiation \\R\_{ns}\\;

- `rnl`: net outgoing longwave radiation \\R\_{nl}\\;

- `cloudiness`: the cloudiness term \\f\\ used \[-\];

all numeric \[MJ m-2 d-1 or MJ m-2 h-1, the unit of `solar_radiation`\]
with the common length (and `dim`) of the inputs;

- `timestep`;

- `flags`: list of `earthflux_flag` records (record scope) for the codes
  that hold somewhere: `EF_INPUT_NA` (a required input is missing) and
  `EF_WS_RS_RSO_LIMITED` (\\R_s/R\_{so} \> 1\\, limited to 1 in the
  cloudiness term);

- `provenance`: time step, verification status, constants, source of the
  cloudiness term, references, `flags_evaluated` and package version.

## Details

\$\$R\_{ns} = (1 - \alpha) R_s, \quad \alpha = 0.23\$\$ (FAO-56, chapter
3, Eq. 38; albedo of the grass reference), \$\$R\_{nl} = \sigma
\frac{T\_{max,K}^4 + T\_{min,K}^4}{2} (0.34 - 0.14 \sqrt{e_a})
\left(1.35 \frac{R_s}{R\_{so}} - 0.35\right)\$\$ with \\\sigma\\ =
4.903e-9 MJ K-4 m-2 d-1 and \\T_K = T + 273.16\\ (FAO-56, chapter 3, Eq.
39), and \\R_n = R\_{ns} - R\_{nl}\\ (Eq. 40). For the hourly time step
(FAO-56, chapter 4, "Hourly time step") the mean of the fourth powers is
replaced by \\T\_{hr,K}^4\\ and \\\sigma = 4.903 \times 10^{-9}/24\\ =
2.043e-10 MJ K-4 m-2 h-1.

**Limit Rs/Rso \<= 1.** FAO-56 defines Eq. 39 with \\R_s/R\_{so} \le
1\\. The limit is applied only inside the cloudiness term;
`solar_radiation` and `rns` are not modified, and the positions where it
acts are flagged `EF_WS_RS_RSO_LIMITED`. The lower limit of 0.3
attributed to ASCE-EWRI (2005) by secondary implementations is
`CANDIDATA` and is not applied.

**Night-time periods.** With \\R\_{so} = 0\\ the ratio is undefined.
FAO-56 sets it to the value of a period 2-3 hours before sunset,
identified by \\\omega_s - 0.79 \le \omega \le \omega_s - 0.52\\, or,
approximately, to 0.4-0.6 in humid and sub-humid and 0.7-0.8 in arid and
semi-arid climates (0.3 means complete cloud cover). Selecting that
value is the task of the station orchestration; here the resulting term
is passed as `cloudiness` (for a ratio \\r\\,
`cloudiness = 1.35 * r - 0.35`).

**Normative constants** (decision WF-14): \\\sigma\\ of FAO-56 (4.903e-9
MJ m-2 d-1 K-4, about 5.6748e-8 W m-2 K-4, 0.08 % below the CODATA value
used elsewhere in the package) and 273.16 in the conversion to kelvin,
as written in Eq. 39; the package constants (`EF_STEFAN_BOLTZMANN`,
273.15) are not used inside the reference surface equations. \\R\_{nl}\\
is an empirical longwave balance of the reference surface and is not
interchangeable with the incoming and emitted longwave radiation of a
pixel.

Missing values propagate (and are flagged `EF_INPUT_NA`). Missing,
unknown or inconsistent `timestep` and temperature arguments raise
`earthflux_missing_input`, `earthflux_unknown_method` or
`earthflux_input_error`; values outside the domains above (including
\\R\_{so} = 0\\ without `cloudiness`, and `tmin > tmax`) raise
`earthflux_domain_error`.

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eqs. 38-40; chapter 4, hourly time
step; cases V10, V11, V14, V15 and V16 of dev/specs/weather-forcing.md
8.1).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

## See also

Other reference evapotranspiration functions:
[`ef_ref_et()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_et.md),
[`ef_ref_soil_heat_flux()`](https://djwillichile.github.io/EarthFlux/reference/ef_ref_soil_heat_flux.md)

## Examples

``` r
# FAO-56 example 18 (Uccle, 6 July): daily step
rn <- ef_ref_net_radiation(
  solar_radiation = 22.07, clear_sky_radiation = 30.90,
  vapour_pressure = 1.409, tmax = 21.5, tmin = 12.3, timestep = "daily"
)
rn$rn
#> [1] 13.28291

# FAO-56 example 19, 02:00-03:00: night, Rs/Rso = 0.8 carried
ef_ref_net_radiation(
  solar_radiation = 0, clear_sky_radiation = NULL,
  vapour_pressure = 3.402, air_temperature = 28, timestep = "hourly",
  cloudiness = 1.35 * 0.8 - 0.35
)$rn
#> [1] -0.1003213
```
