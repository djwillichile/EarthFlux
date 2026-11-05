# Boundary conditions at the anchor pixels

Completes an anchor set
([`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)
or
[`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md))
with the boundary conditions of the METRIC calibration (stage \[B\] of
dev/specs/anchor-pixels.md section 1.3, decision D-AP-03): at each
anchor pixel, the target latent heat flux \\LE\\ and the target sensible
heat flux \\H = R_n - G - LE\\, from the net radiation, the soil heat
flux and the instantaneous reference evapotranspiration at that pixel;
then one calibration point per class, which is what the sensible heat
calibration consumes.

## Usage

``` r
ef_anchor_conditions(
  anchors,
  rn,
  g,
  etr_inst,
  lambda,
  etrf_cold,
  etrf_hot = NULL,
  le_hot = NULL,
  reference,
  source,
  status,
  etr_source = NULL,
  zom = NULL,
  u_blend = NULL,
  pressure = NULL
)
```

## Arguments

- anchors:

  An `earthflux_anchors` object.

- rn:

  Numeric vector or matrix on the grid of the anchors. Net radiation \[W
  m-2\] (e.g.
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)).
  Finite where not missing; must not be missing at an anchor pixel.

- g:

  Numeric vector or matrix on the same grid. Soil heat flux \[W m-2\].
  Same conditions as `rn`.

- etr_inst:

  Numeric. Instantaneous reference evapotranspiration \[mm h-1\], `> 0`:
  a single value for the scene (one station) or a layer on the grid
  (e.g. a regionalised surface), evaluated at the overpass time of each
  pixel. Its value at each anchor pixel is used.

- lambda:

  Numeric. Latent heat of vaporization \[J kg-1\] from
  [`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md),
  a single value or a layer on the grid. The same `lambda` (same method)
  must be used in the conversion of LE to ET (decision P0-7). Checked to
  lie in \[1e6, 1e7\] (unit guard).

- etrf_cold:

  Numeric. Reference ET fraction imposed at the cold anchor, the
  coefficient \\k\\ of \\ET\_{cold} = k \cdot ET\_{r,inst}\\ \[-\];
  finite and `> 0`. No default (decision D-AP-04).

- etrf_hot, le_hot:

  Numeric. Condition of the hot anchor; give exactly one: the reference
  ET fraction at the hot anchor (`etrf_hot`, finite and `>= 0`; 0 for
  dry bare soil) or its latent heat flux (`le_hot` \[W m-2\], finite and
  `>= 0`). No default (decision D-AP-05).

- reference:

  Character. Reference surface of `etr_inst`: `"alfalfa"` (ETr) or
  `"grass"` (ETo). Must be the reference of the daily extrapolation
  (checked by the orchestration).

- source:

  Character. Source of `etrf_cold` and of the hot condition.

- status:

  Character. Their verification status: `"TODO"`, `"CANDIDATA"` or
  `"VERIFICADA"`.

- etr_source:

  Character or `NULL`. Origin of `etr_inst` (e.g. `"station"`, `"gwr"`),
  recorded.

- zom, u_blend, pressure:

  Numeric or `NULL`. Optional inputs of the sensible heat calibration
  passed through to the calibration points, so that
  [`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md)
  can read the anchor object directly: momentum roughness length \[m\]
  (`> 0`, e.g. from
  [`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)
  on the grid), wind speed at the blending height \[m s-1\] (`>= 0`) and
  atmospheric pressure \[kPa\] (`> 0`, e.g.
  [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md)).
  Each is a single value or a layer on the grid; its value at each
  anchor pixel is aggregated with the `aggregate` of the anchor set. Not
  used in the boundary conditions.

## Value

The `earthflux_anchors` object with:

- `calibration_points` completed with the columns `rn`, `g` \[W m-2\],
  `etr_inst` \[mm h-1\], `lambda` \[J kg-1\], `etrf` \[-\], `le_target`
  and `h_target` \[W m-2\], with `h_target = rn - g - le_target` exactly
  in each row, followed by `zom` \[m\], `u_blend` \[m s-1\] and
  `pressure` \[kPa\] when given. With them, `calibration_points` has
  every column required by the sensible heat calibration (`type`, `lst`,
  `elevation`, `zom`, `rn`, `g`, `le_target`, `u_blend`, `pressure`;
  `anchor_id` optional), one row per class;

- `conditions`: a list with `pixels` (per anchor pixel: `id`, `type`,
  `cell`, `utc_hour`, `rn`, `g`, `etr_inst`, `lambda`, `etrf`,
  `le_target`, `h_target`), `etrf_cold`, `hot_condition` (`"etrf"` or
  `"le"`), `etrf_hot`, `le_hot`, `reference`, `etr_source`,
  `etr_inst_layer` and `lambda_layer` (whether a layer was used),
  `source`, `status` and `equations`;

- `dispersion` completed with the new variables;

- `flags` completed with `EF_ANCHOR_COLD_H_NEGATIVE` (record scope: rows
  of `pixels` of the cold class with \\H \< 0\\) and
  `EF_ANCHOR_HOT_LE_ASSUMED_ZERO` (object scope: the hot LE is 0 by
  assumption, not from a soil water balance).

## Details

At each anchor pixel \\i\\: \$\$ET_i = ETrF_i \cdot ET\_{r,inst,i}\$\$
\$\$LE_i = \frac{ET_i \\ \lambda_i \\ \rho_w}{3600 \times 1000}\$\$
\$\$H_i = R\_{n,i} - G_i - LE_i\$\$ with \\ETrF_i\\ = `etrf_cold` for
cold pixels and `etrf_hot` for hot pixels (or \\LE_i\\ = `le_hot`),
\\\rho_w\\ = 1000 kg m-3, 3600 s h-1 and 1000 mm m-1. The calibration
point of each class aggregates `rn`, `g`, `etr_inst`, `lambda` and
`le_target` with the `aggregate` of the anchor set and sets
`h_target = rn - g - le_target` (for `"mean"` this equals the mean of
the per-pixel targets). `etrf` of the hot point is derived from
`le_target` when `le_hot` is given.

Assumptions (`CANDIDATA`): the cold anchor is fully covered, well
watered agricultural vegetation evaporating at `etrf_cold` times the
reference; the hot anchor is dry agricultural bare soil; `etr_inst` is
representative of each anchor location and overpass time; no lateral
heat transport. A negative \\H\\ at the cold anchor is not an error
(advection) but it is flagged.

Errors: a missing `rn`, `g`, `etr_inst` or `lambda` at an anchor pixel
raises `earthflux_anchor_na_input` (fields `variable`, `index` = rows of
`pixels`); invalid or out-of-domain arguments raise
`earthflux_input_error` / `earthflux_domain_error`; `etr_inst <= 0`
raises `earthflux_domain_error`.

Verification status: the forms are `VERIFICADA (SEBAL-Idaho 2002)`:
Waters et al. (2002), p. 30, step 5a (cold anchor: \\H\_{cold} = R_n -
G - 1.05\\\lambda ET_r\\, ETr being the alfalfa reference at the image
time, pp. 13 and 38) and p. 31, step 5b (hot anchor: \\H\_{hot} = R_n -
G - \lambda ET\_{hot}\\ with \\ET\_{hot} = 0\\ for a dry bare
agricultural field, or from a soil water balance after rain in the
previous 1-4 days). The values 1.05 and 0 are the ones of the manual
(also "generally" in appendix 8, p. 81), but they stay explicit
arguments without default (decisions D-AP-04 and D-AP-05, P0-8: no
coefficient by default in the anchor core). The unit conversion is
`VERIFICADA` (FAO-56, box 8, with 3600 s h-1; Eq. 42 of the manual). The
cross-check with Allen et al. (2007) remains desirable but is no longer
blocking.

## References

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
evapotranspiration: Guidelines for computing crop water requirements*
(FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.

## See also

Other anchor pixel functions:
[`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md),
[`ef_anchor_pick()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_pick.md),
[`ef_anchor_rule()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_rule.md),
[`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md),
[`ef_homogeneity()`](https://djwillichile.github.io/EarthFlux/reference/ef_homogeneity.md),
[`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md)

## Examples

``` r
lst <- c(300, 321, 310)
anchors <- ef_anchors(cold = 1, hot = 2, lst = lst,
                      ndvi = c(0.85, 0.10, 0.4),
                      albedo = c(0.20, 0.25, 0.2), aggregate = "none")
# Coefficients of the SEBAL Idaho manual, passed explicitly (no defaults)
anchors <- ef_anchor_conditions(
  anchors, rn = c(700, 500, 600), g = c(100, 120, 110), etr_inst = 0.8,
  lambda = ef_lambda(method = "constant"), etrf_cold = 1.05,
  etrf_hot = 0, reference = "alfalfa",
  source = "Waters et al. (2002), SEBAL Idaho manual, pp. 30-31",
  status = "VERIFICADA", etr_source = "station"
)
anchors$calibration_points[, c("type", "lst", "rn", "g", "le_target",
                               "h_target")]
#>   type lst  rn   g le_target  h_target
#> 1 cold 300 700 100  571.6667  28.33333
#> 2  hot 321 500 120    0.0000 380.00000
```
