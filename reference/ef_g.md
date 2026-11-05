# Soil heat flux

Estimates the instantaneous soil heat flux \\G\\ at the satellite
overpass, i.e. the part of the net radiation \\R_n\\ conducted into the
ground, with an empirical relation between the ratio \\G/R_n\\ and
surface variables. \\G\\ is the second term of the METRIC surface energy
balance \\LE = R_n - G - H\\.

- `ef_g()` is the dispatcher: it calls the method chosen with `method`
  (no default), derives \\G/R_n\\, builds the diagnostic flags and
  records the provenance.

- `ef_g_bastiaanssen()` evaluates the SEBAL relation of
  Bastiaanssen (2000) as a function of surface temperature, albedo and
  NDVI.

- `ef_g_tasumi()` evaluates the relation attributed to Tasumi (2003) and
  used in METRIC as a function of LAI, with a bare-soil branch for LAI
  \< 0.5.

The method functions are purely arithmetic and return \\G\\ only.

## Usage

``` r
ef_g(rn, lst = NULL, albedo = NULL, ndvi = NULL, lai = NULL, method)

ef_g_bastiaanssen(rn, lst, albedo, ndvi)

ef_g_tasumi(rn, lst, lai)
```

## Arguments

- rn:

  Numeric. Net radiation \\R_n\\ at the satellite overpass \[W m-2\],
  positive towards the surface (e.g. from
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)).
  Any finite value is accepted; negative values are physically possible.

- lst:

  Numeric. Land surface temperature \\T_s\\ \[K\]. Must be finite and
  `> 0`. Converted internally to degrees Celsius with the package
  constant 273.15 K. For `ef_g_tasumi()` it is required in every
  position, not only where the bare-soil branch applies (see Details).

- albedo:

  Numeric. Broadband surface albedo \\\alpha\\ \[-\]. Must lie in \[0,
  1\].

- ndvi:

  Numeric. Normalised difference vegetation index \[-\]. Must lie in
  \[-1, 1\].

- lai:

  Numeric. Leaf area index \[m2 m-2\]. Must be finite and `>= 0`.

- method:

  Character. The formulation, with no default: the choice of \\G\\ is a
  scientific decision that must be explicit. One of `"bastiaanssen"`
  (requires `lst`, `albedo`, `ndvi`) or `"tasumi"` (requires `lst`,
  `lai`). Matched exactly (no abbreviation, no change of case).
  Arguments not used by the chosen method are ignored.

## Value

`ef_g_bastiaanssen()` and `ef_g_tasumi()` return a numeric vector of
soil heat flux \\G\\ \[W m-2\] with the common length of the inputs,
keeping the `dim` of matrix or array inputs. Negative values and values
larger than `rn` are possible and returned unchanged.

`ef_g()` returns a list of class `earthflux_soil_heat_flux` with
elements:

- `g`:

  \\G\\ \[W m-2\], identical to the method function.

- `g_rn_ratio`:

  \\G/R_n\\ \[-\], computed as `g / rn`; `NA` where `rn` is 0.

- `method`:

  The method name.

- `branch`:

  For `"tasumi"`, a character vector with the branch applied in each
  position (`"lai_ge_0.5"` or `"lai_lt_0.5"`; `NA` where `g` is `NA`),
  with the shape of `g`; `NULL` for `"bastiaanssen"`.

- `flags`:

  A list of diagnostic flag records (see Diagnostics).

- `provenance`:

  A list with the method, the method function, the verification status,
  the references, the Kelvin offset, the coefficients of the equation,
  the inputs used, the flag codes evaluated (`flags_evaluated`) and the
  EarthFlux version.

## Details

**Bastiaanssen (SEBAL).** \$\$\frac{G}{R_n} = T_c \\ (0.0038 +
0.0074\\\alpha)\\ (1 - 0.98\\\mathrm{NDVI}^4), \qquad G = R_n
\frac{G}{R_n}\$\$ with \\T_c = T_s - 273.15\\ in degrees Celsius. The
ratio is negative for \\T_s \< 273.15\\ K and NDVI enters with an even
power, so negative NDVI (water) gives the same result as the opposite
positive NDVI.

**Tasumi (METRIC).** \$\$\frac{G}{R_n} = 0.05 + 0.18\\
e^{-0.521\\\mathrm{LAI}}, \qquad G = R_n \frac{G}{R_n} \qquad
(\mathrm{LAI} \ge 0.5)\$\$ \$\$G = 1.80\\ T_c + 0.084\\ R_n \qquad
(\mathrm{LAI} \< 0.5)\$\$ The bare-soil branch is evaluated directly,
without dividing by \\R_n\\. The relation is discontinuous at LAI = 0.5,
which belongs to the vegetated branch. Missing `lst` gives a missing
\\G\\ in both branches (decision G-D5, provisional), so the result does
not depend on which branch a position falls in.

Assumptions: \\G\\ and \\R_n\\ are instantaneous at the overpass; \\G \>
0\\ when heat flows from the surface into the ground. Both relations are
empirical, developed for land surfaces near midday; no rule is applied
for water, snow or impervious surfaces, which must be masked or treated
separately by the user.

**Inputs.** Arguments must be numeric and have length 1 or a common
length; length-1 arguments are recycled; matrix or array arguments must
share their `dim` and are not recycled. Missing values (`NA`, `NaN`)
propagate to the corresponding output element without errors or
warnings. Physically impossible values (`albedo` outside \[0, 1\],
`ndvi` outside \[-1, 1\], negative `lai`, non-positive `lst`, or any
infinite value) raise an error of class `earthflux_domain_error` (also
`earthflux_input_error`) naming the argument; values are never
corrected. A missing or unknown `method` raises
`earthflux_missing_input` or `earthflux_unknown_method`, and an input
required by the chosen method that is missing or `NULL` raises
`earthflux_missing_input` (all also `earthflux_input_error`).

**Diagnostics.** `ef_g()` returns, in `flags`, one record per condition
that holds in at least one position: `EF_INPUT_NA` (a required input is
missing), `EF_G_RN_NONPOSITIVE` (\\R_n \le 0\\), `EF_G_RATIO_NEGATIVE`
(\\G/R_n \< 0\\), `EF_G_AVAILABLE_NONPOSITIVE` (\\R_n - G \le 0\\) and,
for `"tasumi"`, `EF_G_LOW_LAI_BRANCH` (bare-soil branch applied). No
plausible range of \\G/R_n\\ is checked until one is documented with a
reference.

## Verification status

`"bastiaanssen"` is `VERIFICADA (SEBAL-Idaho 2002)`: Waters et al.
(2002), p. 24, Eq. 24, after Bastiaanssen (2000), print \\G/R_n =
T_s/\alpha\\ (0.0038\\\alpha + 0.0074\\\alpha^2)\\ (1 -
0.98\\\mathrm{NDVI}^4)\\ with \\T_s\\ in degrees Celsius, "representing
values near midday"; the expanded form above is algebraically identical
for \\\alpha \> 0\\ (and defined at \\\alpha = 0\\). The manual assigns
G/Rn = 0.5 to water (NDVI \< 0) and to snow (\\T_s\\ \< 4 degrees C and
albedo \> 0.45) (p. 25, appendix 10); these rules are not applied here
(decision G-D4). The cross-check with Allen et al. (2007) remains
desirable but is no longer blocking.

`"tasumi"` is `CANDIDATA`: its form, coefficients and the LAI threshold
were observed in a secondary implementation (the `water` R package,
version 1.0) and are rewritten here; the primary references (Tasumi,
2003; Allen et al., 2007) were not consulted. Whether its bare-soil
condition is `LAI < 0.5` or `LAI <= 0.5` remains to be verified.

The method has no default (dispatcher convention, decision T-15).
Applying the relations to 1 km MODIS pixels (mixed cover, composite NDVI
and LAI) is not validated.

## References

Bastiaanssen, W. G. M. (2000). SEBAL-based sensible and latent heat
fluxes in the irrigated Gediz Basin, Turkey. *Journal of Hydrology*,
229(1-2), 87-100.
[doi:10.1016/S0022-1694(99)00202-4](https://doi.org/10.1016/S0022-1694%2899%2900202-4)

Tasumi, M. (2003). *Progress in operational estimation of regional
evapotranspiration using satellite imagery* (PhD dissertation).
University of Idaho.

Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
balance for mapping evapotranspiration with internalized calibration
(METRIC) - Model. *Journal of Irrigation and Drainage Engineering*,
133(4), 380-394.
[doi:10.1061/(ASCE)0733-9437(2007)133:4(380)](https://doi.org/10.1061/%28ASCE%290733-9437%282007%29133%3A4%28380%29)

Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R.
(2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho
implementation. Advanced training and users manual* (Version 1.0).
University of Idaho and Idaho Department of Water Resources.

## See also

[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
for \\R_n\\.

## Examples

``` r
# Tasumi: dense canopy (vegetated branch) and bare soil (LAI < 0.5)
ef_g_tasumi(rn = c(550, 400), lst = c(300, 318.15), lai = c(3, 0.2))
#> [1]  48.24115 114.60000

# Bastiaanssen: intermediate vegetation
ef_g_bastiaanssen(rn = 500, lst = 303.15, albedo = 0.20, ndvi = 0.50)
#> [1] 74.349

# Dispatcher: G, G/Rn, branch, flags and provenance
g <- ef_g(rn = c(550, 40), lst = 318.15, lai = c(3, 0.2),
          method = "tasumi")
g$g
#> [1] 48.24115 84.36000
g$g_rn_ratio
#> [1] 0.08771119 2.10900000
g$branch
#> [1] "lai_ge_0.5" "lai_lt_0.5"
vapply(g$flags, `[[`, character(1), "code")
#> [1] "EF_G_AVAILABLE_NONPOSITIVE" "EF_G_LOW_LAI_BRANCH"       

# Chained with the net radiation
rn <- ef_net_radiation(rs_in = 800, albedo = 0.20, rl_in = 320,
                       rl_out = 450.0846, emissivity = 0.98)
ef_g(rn, lst = 303.15, albedo = 0.20, ndvi = 0.50,
     method = "bastiaanssen")$g
#> [1] 74.87173
```
