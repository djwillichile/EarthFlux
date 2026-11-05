# Momentum roughness length

Computes the surface roughness length for momentum transport \\z\_{om}\\
\[m\], which controls the friction velocity and the aerodynamic
resistance to heat transport of the METRIC energy balance. `ef_zom()` is
the dispatcher of the family: it checks `method` (no default), forwards
the arguments to one of the method functions (which can also be called
directly), builds the diagnostic flags and records the provenance.

- `ef_zom_lai()`: linear function of the leaf area index, for short
  (agricultural) crops.

- `ef_zom_ndvi()`: exponential function of NDVI / albedo with
  user-supplied coefficients (to be fitted to points of known
  roughness).

- `ef_zom_perrier()`: Perrier function of LAI, canopy height and the
  fraction of LAI above half the canopy height, for trees and tall
  crops.

- `ef_zom_height()`: FAO-56 function of the vegetation height, mainly
  for the surface around a weather station.

## Usage

``` r
ef_zom(
  lai = NULL,
  ndvi = NULL,
  albedo = NULL,
  coef_1 = NULL,
  coef_2 = NULL,
  f_lai = NULL,
  height = NULL,
  method
)

ef_zom_lai(lai)

ef_zom_ndvi(ndvi, albedo, coef_1, coef_2)

ef_zom_perrier(lai, f_lai, height)

ef_zom_height(height)
```

## Arguments

- lai:

  Numeric. Leaf area index \[m2 m-2\]. Must be finite and `>= 0`. Used
  by `"lai"` and `"perrier"`.

- ndvi:

  Numeric. Normalised difference vegetation index \[-\], in \[-1, 1\].
  Used by `"ndvi"`.

- albedo:

  Numeric. Broadband surface albedo \[-\], in (0, 1\]. Used by `"ndvi"`.

- coef_1, coef_2:

  Numeric. Coefficients \\c_1\\ \[-\] and \\c_2\\ \[-\] of the
  exponential relation, supplied by the user (no default exists). Must
  be finite. Used by `"ndvi"`.

- f_lai:

  Numeric. Fraction of the leaf area index located above half the canopy
  height \[-\], in \[0, 1\]. Used by `"perrier"`.

- height:

  Numeric. Canopy (vegetation) height \[m\]. Must be finite and `>= 0`.
  Used by `"perrier"` and `"height"`.

- method:

  Character. The formulation, with no default (the choice is a
  scientific decision; decision SH-01 is open). One of `"lai"`,
  `"ndvi"`, `"perrier"` or `"height"`. Matched exactly.

## Value

The method functions return a numeric vector of momentum roughness
length \\z\_{om}\\ \[m\] with the common length of the inputs, keeping
their `dim` if they are matrices or arrays. Zero values (e.g. `lai = 0`
or `height = 0`) are returned unchanged: no minimum roughness is applied
(see Details) and such values are rejected by
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md).

`ef_zom()` returns a list of class `earthflux_roughness_length` with
elements `zom` (identical to the method function), `method`, `flags`
(one record per code that holds somewhere: `EF_INPUT_NA`, a required
input is missing; no `EF_H_` code applies to \\z\_{om}\\ while no
minimum roughness or terrain factor is implemented) and `provenance`
(method, method function, verification status, inputs used, flag codes
evaluated in `flags_evaluated`, EarthFlux version).

## Details

`ef_zom_lai()` (`method = "lai"`): \$\$z\_{om} = 0.018\\\mathrm{LAI}\$\$

`ef_zom_ndvi()` (`method = "ndvi"`): \$\$z\_{om} =
\exp(c_1\\\mathrm{NDVI}/\alpha + c_2)\$\$

`ef_zom_perrier()` (`method = "perrier"`): \$\$z\_{om} = \left(1 -
e^{-p\\\mathrm{LAI}/2}\right) e^{-p\\\mathrm{LAI}/2}\\ h\$\$ with \\p =
1 / (2 (1 - f))\\ if \\f \< 0.5\\ and \\p = 2 f\\ otherwise (both
branches give \\p = 1\\ at \\f = 0.5\\), where \\f\\ is `f_lai` and
\\h\\ is `height`.

`ef_zom_height()` (`method = "height"`): \$\$z\_{om} = 0.123\\h\$\$
(FAO-56, chapter 2, box 4, which also gives the zero-plane displacement
\\d = 2 h / 3\\).

Assumptions and limitations: the linear LAI relation is meant for short
crops; secondary sources report that it underestimates the roughness of
maize and that vines and trees need another function. With 1 km MODIS
pixels (mixed covers) the roughness of the mean LAI is not the mean
roughness of the covers. The Perrier function needs a canopy height map,
which MODIS does not provide.

No minimum roughness (0.005 m in METRIC implementations, decision SH-02)
and no mountainous-terrain adjustment (SH-03) are applied: both are
unverified and values are never silently modified.

Missing values propagate. Arguments must be numeric, of length 1 or a
common length (length 0 is rejected), and matrix or array arguments must
share their `dim`. Values outside the documented domain, or infinite
values, raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`). A missing or unknown `method` raises
`earthflux_missing_input` or `earthflux_unknown_method`; an argument
required by the chosen method but not supplied to the dispatcher raises
`earthflux_missing_input`. Arguments not used by the method are ignored.

Verification status:

- `"lai"`: `VERIFICADA (SEBAL-Idaho 2002)`, Waters et al. (2002), p. 27,
  Eq. 31a, "for agricultural areas" (consistent with their \\z\_{om} =
  0.12 h\\, Eq. 28, and \\h = 0.15\\\mathrm{LAI}\\, appendix 2);

- `"ndvi"`: `VERIFICADA (SEBAL-Idaho 2002)`, Waters et al. (2002), p.
  28, Eq. 31b, with coefficients fitted to sample pixels of known
  roughness (named `a` and `b` there);

- `"perrier"`: `VERIFICADA (IAHS 2012)`, Allen et al. (2012), p. 73
  (unnumbered equation; \\f\\ = 0.6 is suggested there for mixed
  forests);

- `"height"`: `VERIFICADA` as FAO-56 content; its use in METRIC is not
  verified (the SEBAL Idaho manual uses 0.12 h for the station surface,
  Eq. 28, after Brutsaert, 1982).

The cross-check with Allen et al. (2007) remains desirable but is no
longer blocking (`dev/VERIFICATION.md`).

## References

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

Santos, C., Lorite, I. J., Allen, R. G., & Tasumi, M. (2012).
Aerodynamic parameterization of the satellite-based energy balance
(METRIC) model for ET estimation in rainfed olive orchards of Andalusia,
Spain. *Water Resources Management*, 26(11), 3267-3283.
[doi:10.1007/s11269-012-0071-8](https://doi.org/10.1007/s11269-012-0071-8)

Pocas, I., Paco, T. A., Cunha, M., Andrade, J. A., Silvestre, J., Sousa,
A., Santos, F. L., Pereira, L. S., & Allen, R. G. (2014).
Satellite-based evapotranspiration of a super-intensive olive orchard:
Application of METRIC algorithms. *Biosystems Engineering*, 128, 69-81.
[doi:10.1016/j.biosystemseng.2014.06.019](https://doi.org/10.1016/j.biosystemseng.2014.06.019)

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

Allen, R. G., Kjaersgaard, J. H., Trezza, R., Oliveira, A., Robison, C.,
& Lorite-Torres, I. (2012). Refining components of a satellite-based
surface energy balance model to complex land-use systems. In *Remote
Sensing and Hydrology* (IAHS Publication 352, pp. 73-75). IAHS Press.

## See also

Other aerodynamics and sensible heat functions:
[`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md),
[`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md),
[`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md),
[`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md),
[`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md),
[`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md),
[`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md),
[`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md),
[`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md)

## Examples

``` r
# Short crops: z_om = 0.018 * LAI (m)
ef_zom(lai = c(0.5, 2, 4), method = "lai")$zom
#> [1] 0.009 0.036 0.072
ef_zom_lai(c(0.5, 2, 4))
#> [1] 0.009 0.036 0.072

# Exponential NDVI / albedo relation with user coefficients
ef_zom_ndvi(ndvi = 0.6, albedo = 0.2, coef_1 = 0.5, coef_2 = -5)
#> [1] 0.03019738

# Perrier function for an orchard 3 m tall
ef_zom_perrier(lai = 2, f_lai = 0.6, height = 3)
#> [1] 0.6314288

# FAO-56: clipped grass 0.12 m tall around a weather station
ef_zom_height(0.12)
#> [1] 0.01476
```
