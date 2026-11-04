# Actual vapour pressure

Computes the actual vapour pressure of the air \\e_a\\ from the humidity
data available, with the FAO-56 equations:

- `ef_ea_dewpoint()`: from the dew point temperature (any time step);

- `ef_ea_rh()`: from the air temperature and relative humidity of the
  same period (hourly or shorter);

- `ef_ea_daily()`: from the daily extreme temperatures and relative
  humidities, with an explicit `method` (`"rhmax_rhmin"`, `"rhmax"` or
  `"rhmean"`);

- `ef_ea_tmin()`: from the minimum temperature, only when humidity data
  are missing, with an explicit aridity correction `k0`.

## Usage

``` r
ef_ea_dewpoint(dewpoint_temperature)

ef_ea_rh(air_temperature, relative_humidity)

ef_ea_tmin(tmin, k0)

ef_ea_daily(tmin, tmax = NULL, rh_max, rh_min = NULL, method)
```

## Arguments

- dewpoint_temperature:

  Numeric. Dew point temperature \[degrees Celsius\], finite and
  `> -237.3`.

- air_temperature:

  Numeric. Air temperature of the period \[degrees Celsius\], finite and
  `> -237.3`.

- relative_humidity:

  Numeric. Relative humidity of the same period \[%\], finite and
  `>= 0`. Values above 100 % are computed (they are a quality-control
  matter, `EF_WS_RH_GT100`), never truncated.

- tmin, tmax:

  Numeric. Daily minimum and maximum air temperatures \[degrees
  Celsius\], finite and `> -237.3`; `tmin <= tmax`. `tmax` is not used
  by `method = "rhmax"` and may then be `NULL`.

- k0:

  Numeric. Aridity correction \\K_0\\ \[degC\] subtracted from `tmin` to
  approximate the dew point, finite and `>= 0`. FAO-56 (annex 6, Eq.
  6-6) gives 0 degC for humid and sub-humid climates and 2 degC for arid
  and semi-arid climates (chapter 3: 2-3 degC). No default: the choice
  depends on the climate of the site.

- rh_max, rh_min:

  Numeric. Daily maximum and minimum relative humidity \[%\], finite and
  `>= 0`. `rh_min` is not used by `method = "rhmax"` and may then be
  `NULL`.

- method:

  Character, no default. Formulation of `ef_ea_daily()`:

  - `"rhmax_rhmin"`: FAO-56 Eq. 17, from `tmin`, `tmax`, `rh_max` and
    `rh_min` (recommended by FAO-56);

  - `"rhmax"`: FAO-56 Eq. 18, from `tmin` and `rh_max` only (when
    `rh_min` is doubtful);

  - `"rhmean"`: FAO-56 Eq. 19, from the mean relative humidity
    `(rh_max + rh_min) / 2` and the mean saturation vapour pressure (the
    least desirable of the three, FAO-56).

## Value

A numeric vector of actual vapour pressure \\e_a\\ \[kPa\] with the
common length of the inputs, keeping their `dim`.

## Details

With \\e^\circ(T)\\ the saturation vapour pressure of
[`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md)
(FAO-56 Eq. 11): \$\$e_a = e^\circ(T\_{dew})\$\$ (Eq. 14;
`ef_ea_dewpoint()`), \$\$e_a = e^\circ(T\_{hr}) \frac{RH\_{hr}}{100}\$\$
(Eq. 54; annex 5, Eq. 5-3: temperature and humidity of the same period,
preferably one hour or less; `ef_ea_rh()`), \$\$e_a =
\frac{e^\circ(T\_{min}) \frac{RH\_{max}}{100} + e^\circ(T\_{max})
\frac{RH\_{min}}{100}}{2}\$\$ (Eq. 17; `"rhmax_rhmin"`), \$\$e_a =
e^\circ(T\_{min}) \frac{RH\_{max}}{100}\$\$ (Eq. 18; `"rhmax"`), \$\$e_a
= \frac{RH\_{mean}}{100} \frac{e^\circ(T\_{max}) +
e^\circ(T\_{min})}{2}, \quad RH\_{mean} = \frac{RH\_{max} +
RH\_{min}}{2}\$\$ (Eq. 19; `"rhmean"`), and \$\$e_a = e^\circ(T\_{min} -
K_0)\$\$ (Eq. 48; annex 6, Eq. 6-6; `ef_ea_tmin()`). The last one
assumes that the dew point is close to the minimum temperature, which
holds only at well-watered reference sites; FAO-56 recommends it only
when humidity data are missing.

FAO-56 and `dev/SCIENTIFIC_SPEC.md` section 5 recommend regionalising
the actual vapour pressure (nearly constant during the day), not the
relative humidity, which depends on the temperature.

Missing values propagate. Non-numeric, empty or incompatible inputs
raise `earthflux_input_error`; temperatures `<= -237.3`, negative
humidities, negative `k0`, `tmin > tmax` or infinite values raise
`earthflux_domain_error`. A missing or unknown `method` raises
`earthflux_missing_input` or `earthflux_unknown_method`; an input
required by the method and not supplied raises
`earthflux_missing_input`.

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eqs. 14, 17, 18, 19, 48 and 54; annex
6, Eq. 6-6; dev/specs/weather-forcing.md 4.4, cases V3 and V17).
`ef_ea_tmin()` is verified as an equation; its use is restricted to
missing humidity data and `k0` is always explicit.

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

## See also

Other derived meteorological variables:
[`ef_dewpoint()`](https://djwillichile.github.io/EarthFlux/reference/ef_dewpoint.md),
[`ef_es()`](https://djwillichile.github.io/EarthFlux/reference/ef_es.md),
[`ef_es_slope()`](https://djwillichile.github.io/EarthFlux/reference/ef_es_slope.md),
[`ef_psychrometric()`](https://djwillichile.github.io/EarthFlux/reference/ef_psychrometric.md),
[`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md),
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md),
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md),
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)

## Examples

``` r
# FAO-56 example 5: Tmin = 18, Tmax = 25 degrees C, RHmax = 82,
# RHmin = 54 %
ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82, rh_min = 54,
            method = "rhmax_rhmin")
#> [1] 1.701536
ef_ea_daily(tmin = 18, tmax = 25, rh_max = 82, rh_min = 54,
            method = "rhmean")
#> [1] 1.778801
ef_ea_daily(tmin = 18, rh_max = 82, method = "rhmax")
#> [1] 1.692471

# From the dew point, and from hourly temperature and humidity
ef_ea_dewpoint(15)
#> [1] 1.705346
ef_ea_rh(air_temperature = 38, relative_humidity = 52)
#> [1] 3.444874

# Minimum temperature, arid site (k0 = 2 degrees C)
ef_ea_tmin(tmin = 12, k0 = 2)
#> [1] 1.227963
```
