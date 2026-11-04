# S3 classes ----------------------------------------------------------------------
#
# Purpose: lightweight S3 classes for EarthFlux objects. Planned (not yet
#   defined):
#   - earthflux_result : all intermediate layers + diagnostics + provenance;
#   - earthflux_anchors: anchor pixel selection and its audit trail;
#   - earthflux_gwr    : fitted GWR model, bandwidth profile and diagnostics.
#
# The only class currently created is `earthflux_flag` (R/diagnostics.R).
#
# TODO(M2/M3): define constructors and validators when the corresponding
#   modules are specified. Avoid premature class hierarchies.
