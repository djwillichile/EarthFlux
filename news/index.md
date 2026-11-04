# Changelog

## EarthFlux 0.0.0.9000 (development version)

- New
  [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md):
  instantaneous net radiation at the land surface from incoming
  shortwave, albedo, incoming longwave, emitted longwave and surface
  emissivity (METRIC surface radiation balance), with the reflected
  incoming longwave term kept explicit. Inputs are validated (type,
  recycling and physical domain, with classed errors) and missing values
  propagate. The form of the equation has been cross-checked against
  secondary sources; verification against the primary reference (Allen
  et al., 2007) is still pending.
- Initial package infrastructure: package skeleton, MIT license,
  testthat (3rd edition), roxygen2 with Markdown, pkgdown, README,
  citation and an introductory vignette.
- Modular source layout for the planned surface, forcing, spatial (GWR),
  METRIC, diagnostics, validation and API modules. No scientific
  function is implemented yet.
- Internal infrastructure for classed conditions and diagnostic flags
  (results are flagged, never silently corrected).
