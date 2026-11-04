# Saturation vapour pressure

Computes the saturation vapour pressure \\e^\circ(T)\\ at a given air
temperature with the FAO-56 equation.

## Usage

``` r
ef_es(air_temperature)
```

## Arguments

- air_temperature:

  Numeric. Air temperature \\T\\ \[degrees Celsius\]. Must be finite and
  `> -237.3`, where the equation is defined.

## Value

A numeric vector of saturation vapour pressure \[kPa\] with the length
of `air_temperature`, keeping its `dim`.

## Details

\$\$e^\circ(T) = 0.6108 \exp\left(\frac{17.27\\T}{T + 237.3}\right)\$\$
(FAO-56, chapter 3, Eq. 11).

**Mean saturation vapour pressure.** For periods of one day or longer
the saturation vapour pressure of the period is the mean of the values
at the daily maximum and minimum temperatures (FAO-56, Eq. 12):
`(ef_es(tmax) + ef_es(tmin)) / 2`. Using the mean temperature instead
underestimates it and the reference evapotranspiration (FAO-56, chapter
3 and box 7). For hourly periods, `ef_es()` of the hourly mean
temperature is used (FAO-56, Eq. 53). The vapour pressure deficit is the
difference between this value and the actual vapour pressure
([`ef_ea_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md)
and related functions).

Temperatures are in degrees Celsius (decision WF-02): a temperature
passed in kelvin (for example 293) gives a meaningless value and is not
detected here (it is a quality-control matter, flag `EF_WS_IMPLAUSIBLE`,
not registered).

Missing values propagate. Non-numeric or empty input raises
`earthflux_input_error`; temperatures `<= -237.3` or infinite raise
`earthflux_domain_error`.

## Verification status

`VERIFICADA` (FAO-56, chapter 3, Eqs. 11 and 12; case V2: e°(24.5) =
3.075 kPa, e°(15) = 1.705 kPa). FAO-56 annex 3, Eq. 3-8 uses 0.611
instead of 0.6108; the chapter 3 form is adopted
(dev/specs/weather-forcing.md 4.3).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

## See also

Other derived meteorological variables:
[`ef_dewpoint()`](https://djwillichile.github.io/EarthFlux/reference/ef_dewpoint.md),
[`ef_ea`](https://djwillichile.github.io/EarthFlux/reference/ef_ea.md),
[`ef_es_slope()`](https://djwillichile.github.io/EarthFlux/reference/ef_es_slope.md),
[`ef_psychrometric()`](https://djwillichile.github.io/EarthFlux/reference/ef_psychrometric.md),
[`ef_ra_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_daily.md),
[`ef_ra_period()`](https://djwillichile.github.io/EarthFlux/reference/ef_ra_period.md),
[`ef_rso()`](https://djwillichile.github.io/EarthFlux/reference/ef_rso.md),
[`ef_wind_2m()`](https://djwillichile.github.io/EarthFlux/reference/ef_wind_2m.md)

## Examples

``` r
# FAO-56 example 3: Tmax = 24.5 and Tmin = 15 degrees C
ef_es(c(24.5, 15))
#> [1] 3.074649 1.705346
# Mean saturation vapour pressure of the day (Eq. 12)
mean(ef_es(c(24.5, 15)))
#> [1] 2.389998
```
