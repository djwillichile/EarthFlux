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

- Radiation components that produce the inputs of
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md)
  (all `CANDIDATA` except where stated; unverified choices are explicit
  arguments without defaults):

  - [`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md)
    returns, per pixel and overpass instant (numeric `doy` of the UTC
    date and `utc_hour`, angles in radians), the cosines of the solar
    zenith angle and of the incidence angle on the tilted pixel plane
    (GIS aspect), the declination, the hour angle and the inverse
    relative Earth-Sun distance. The calendar terms and the hour angle
    are verified against FAO-56; the equation of time is applied exactly
    once.
  - [`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md)
    (with an explicit `method`) dispatches to
    [`ef_tau_sw_allen()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md),
    the clear-sky shortwave transmissivity split into direct-beam and
    diffuse parts (function of zenith angle, pressure, vapour pressure
    and an explicit turbidity), and
    [`ef_tau_sw_elevation()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md),
    the simple elevation form.
  - [`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md)
    computes the effective atmospheric emissivity from the clear-sky
    transmissivity.
  - [`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md)
    (with an explicit `method`) dispatches to
    [`ef_rs_in_modelled()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md)
    (clear-sky) and
    [`ef_rs_in_measured()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md)
    (measured radiation with a given diffuse fraction); both project the
    direct-beam, diffuse and ground-reflected components onto the pixel
    plane.
  - [`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md)
    computes the incoming longwave radiation from an effective
    atmospheric emissivity and a temperature whose choice (air,
    cold-pixel or pixel surface temperature) is left to the caller, and
    [`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md)
    the longwave radiation emitted by the surface.

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

- Aerodynamics of the METRIC sensible heat flux:
  [`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)
  dispatches, with an explicit `method` and no default, to the momentum
  roughness length methods
  [`ef_zom_lai()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md),
  [`ef_zom_ndvi()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md),
  [`ef_zom_perrier()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md)
  and
  [`ef_zom_height()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md);
  [`ef_blending_wind()`](https://djwillichile.github.io/EarthFlux/reference/ef_blending_wind.md)
  extrapolates the station wind to the blending height;
  [`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md)
  and
  [`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md)
  compute the friction velocity and the aerodynamic resistance to heat
  transport, with optional stability corrections. No minimum roughness,
  terrain factor or wind floor is applied (not verified). All forms are
  `CANDIDATA`; the heights (blending height, z1, z2) and the station
  roughness have no defaults.

- [`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md)
  (FAO-56 form, temperature in K),
  [`ef_ts_datum()`](https://djwillichile.github.io/EarthFlux/reference/ef_ts_datum.md)
  (surface temperature referred to an elevation datum),
  [`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md)
  (coefficients of dT = a + b Ts_datum from the hot and cold anchors)
  and
  [`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md)
  (H = rho cp dT / rah).

- [`ef_calibrate_h()`](https://djwillichile.github.io/EarthFlux/reference/ef_calibrate_h.md)
  calibrates dT from one calibration point per anchor class, iterating
  the aerodynamic resistance with the Monin-Obukhov stability correction
  at the anchors (phase A, with a closure so that the anchors reproduce
  their target H exactly) and, optionally, per pixel with the calibrated
  coefficients (phase B). It returns an `earthflux_h_calibration` object
  with the coefficients, the convergence trace, the anchor state, the
  pixel results and diagnostic flags. Non-convergence returns the last
  iterate with an `earthflux_convergence_warning` and the critical flag
  `EF_H_CALIBRATION_NOT_CONVERGED`; invalid anchor states raise
  `earthflux_calibration_error`.
  [`ef_h_control()`](https://djwillichile.github.io/EarthFlux/reference/ef_h_control.md)
  sets the convergence settings (`tol = 0.01`, `maxit = 20`,
  `damping = 0`) and requires the height of the stable momentum
  correction, `stable_psi_m_height`, because that choice is still open
  (decision SH-11).

- New diagnostic flags of the sensible heat stage: `EF_H_USTAR_INVALID`,
  `EF_H_PIXEL_NOT_CONVERGED`, `EF_H_DT_EXTRAPOLATED_HOT`,
  `EF_H_DT_EXTRAPOLATED_COLD`, `EF_H_NEGATIVE`, `EF_H_GT_AVAILABLE`
  (cell) and `EF_H_CALIBRATION_NOT_CONVERGED`,
  `EF_H_DT_SLOPE_NONPOSITIVE` (object, critical).

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
- Diagnostic flags of the radiation stage registered:
  `EF_RAD_SELF_SHADED`, `EF_RAD_ATM_EMISSIVITY_GT1`, `EF_RAD_RS_GT_RA`
  and `EF_RAD_RN_NEGATIVE`. They are computed from the numeric inputs
  and outputs, never by the numeric functions, which return values
  unchanged.
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
