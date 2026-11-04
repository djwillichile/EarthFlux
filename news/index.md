# Changelog

## EarthFlux 0.0.0.9000 (development version)

First development version. It sets up the package infrastructure and
provides the first component of the METRIC surface energy balance chain.
No scientific result has been validated yet.

### New features

- [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
  computes the instantaneous net radiation at the land surface from
  incoming shortwave radiation, albedo, incoming longwave radiation,
  emitted longwave radiation and surface emissivity (METRIC surface
  radiation balance), keeping the reflected incoming longwave term
  explicit. Inputs are validated (type, recycling and physical domain,
  with classed errors) and missing values propagate. The form of the
  equation is corroborated by secondary sources; verification against
  the primary reference (Allen et al., 2007) is pending.

- [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md)
  computes the mean atmospheric pressure from elevation (FAO-56 Eq. 7),
  shared by the radiation, sensible heat and reference
  evapotranspiration modules.

- [`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md)
  returns the latent heat of vaporization in J kg-1 with an explicit
  `method` and no default: the FAO-56 constant (`"constant"`) or the
  FAO-56 function of the air temperature in K (`"fao56"`). The same
  function is meant to be used throughout the METRIC chain.

- [`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md)
  computes the instantaneous latent heat flux as the residual of the
  surface energy balance, LE = Rn - G - H (FAO-56, chapter 1, Eq. 1).
  Negative values are returned unchanged, never set to zero.

- [`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md)
  converts the latent heat flux (W m-2) into instantaneous
  evapotranspiration (mm h-1) with the latent heat of vaporization from
  [`ef_lambda()`](https://djwillichile.github.io/EarthFlux/reference/ef_lambda.md)
  and the density of water, writing the factor 1000 mm m-1 explicitly. A
  unit guard rejects `lambda` outside \[1e6, 1e7\] J kg-1 (for example a
  value given in MJ kg-1).

- [`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md)
  computes the reference evapotranspiration fraction ET_inst / ETr_inst,
  and
  [`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md)
  extrapolates it to daily actual evapotranspiration with an explicit
  `method` and no default; the only method is `"etrf"`
  ([`ef_et_daily_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md),
  ETa_24 = ETrF \* ETr_24). Both require the reference crop (`"alfalfa"`
  or `"grass"`) explicitly. A non-positive instantaneous reference ET or
  a negative daily reference ET is a classed domain error. These
  formulations are corroborated by secondary sources; verification
  against Allen et al. (2007) is pending.

- Negative evapotranspiration is reported with the diagnostic flag
  `EF_ET_NEGATIVE`, evaluated separately on the instantaneous and daily
  layers; values are never truncated.

- [`ef_g()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md)
  estimates the instantaneous soil heat flux with an explicit `method`
  and no default, returning G, the ratio G/Rn, the branch applied,
  diagnostic flags and provenance. The methods are also available as
  [`ef_g_bastiaanssen()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md)
  (SEBAL, function of surface temperature, albedo and NDVI) and
  [`ef_g_tasumi()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md)
  (METRIC, function of LAI, with a bare-soil branch for LAI \< 0.5).
  Both formulations are candidates: verification against the primary
  references is pending. Impossible inputs raise classed errors; values
  of G are never truncated.

### Changes

- Modular source layout for the surface, forcing, spatial (GWR), METRIC,
  diagnostics, validation and API modules.
- Internal infrastructure for classed conditions and diagnostic flags:
  results are flagged, never silently corrected.
- Physical constants (Kelvin offset, Stefan-Boltzmann constant, solar
  constant, von Karman constant, gravity, specific heat of air, density
  of water and the FAO-56 latent heat of vaporization) are defined once,
  with their unit, source and verification status.
- The registry of diagnostic flags is assembled from one table per
  METRIC stage and records, for each code, its stage, severity (now
  including `critical`), scope, bit, error counterpart, specification
  and version. Flag records also carry their stage and scope.
- New diagnostic flags of the soil heat flux stage:
  `EF_G_RN_NONPOSITIVE`, `EF_G_RATIO_NEGATIVE`,
  `EF_G_AVAILABLE_NONPOSITIVE` and `EF_G_LOW_LAI_BRANCH`.
- Classed conditions can carry optional data fields (for example the
  diagnostics of a failed calibration); new condition classes for
  calibration errors and convergence warnings.

### Documentation

- README and introductory vignette describe the development status, show
  the package title from `DESCRIPTION` and include an executable
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
  example.
- pkgdown site at <https://djwillichile.github.io/EarthFlux/>, rebuilt
  on every change to `main`.
- Continuous integration: `R CMD check` on Linux (release, devel,
  oldrel), Windows and macOS; a check that the roxygen2 documentation
  and `README.md` are up to date; repository settings synchronised from
  `DESCRIPTION`.
