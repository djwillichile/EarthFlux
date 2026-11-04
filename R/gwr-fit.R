# Spatial forcing: GWR model fitting --------------------------------------------
#
# Purpose: fit geographically weighted regression models of meteorological
#   variables (response) on spatial covariates (e.g. elevation), returning an
#   object that keeps coefficients, kernel, bandwidth, selection criterion,
#   fitted values, residuals and fit statistics.
#
# Independence rule: this module knows nothing about METRIC. It produces
#   meteorological surfaces that METRIC consumes through a documented contract.
#
# TODO(M1): document the backend decision (internal implementation vs GWmodel
#   vs others) in dev/ARCHITECTURE.md, section "Decisiones abiertas".
# TODO(M3): implement only after that decision.
