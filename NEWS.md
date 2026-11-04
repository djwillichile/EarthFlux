# EarthFlux 0.0.0.9000 (development version)

First development version. It sets up the package infrastructure and
provides the first component of the METRIC surface energy balance chain.
No scientific result has been validated yet.

## New features

* `ef_net_radiation()` computes the instantaneous net radiation at the land
  surface from incoming shortwave radiation, albedo, incoming longwave
  radiation, emitted longwave radiation and surface emissivity (METRIC
  surface radiation balance), keeping the reflected incoming longwave term
  explicit. Inputs are validated (type, recycling and physical domain, with
  classed errors) and missing values propagate. The form of the equation is
  corroborated by secondary sources; verification against the primary
  reference (Allen et al., 2007) is pending.

## Changes

* Modular source layout for the surface, forcing, spatial (GWR), METRIC,
  diagnostics, validation and API modules.
* Internal infrastructure for classed conditions and diagnostic flags:
  results are flagged, never silently corrected.
* Physical constants (Kelvin offset, Stefan-Boltzmann constant, solar
  constant, von Karman constant, gravity, specific heat of air, density of
  water and the FAO-56 latent heat of vaporization) are defined once, with
  their unit, source and verification status.
* The registry of diagnostic flags is assembled from one table per METRIC
  stage and records, for each code, its stage, severity (now including
  `critical`), scope, bit, error counterpart, specification and version.
  Flag records also carry their stage and scope.
* Classed conditions can carry optional data fields (for example the
  diagnostics of a failed calibration); new condition classes for
  calibration errors and convergence warnings.

## Documentation

* README and introductory vignette describe the development status, show
  the package title from `DESCRIPTION` and include an executable
  `ef_net_radiation()` example.
* pkgdown site at <https://djwillichile.github.io/EarthFlux/>, rebuilt on
  every change to `main`.
* Continuous integration: `R CMD check` on Linux (release, devel, oldrel),
  Windows and macOS; a check that the roxygen2 documentation and
  `README.md` are up to date; repository settings synchronised from
  `DESCRIPTION`.
