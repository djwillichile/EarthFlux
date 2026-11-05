#' EarthFlux: Land-Surface Energy and Water Fluxes from Earth Observation Data
#'
#' @description
#' EarthFlux is an R package under active development that aims to provide a
#' reproducible, testable and auditable workflow for estimating spatially
#' distributed actual evapotranspiration (ETa) following the conceptual chain
#'
#' \deqn{\textrm{MODIS} + \textrm{METRIC} + \textrm{GWR} \rightarrow ET_a}{MODIS + METRIC + GWR -> ETa}
#'
#' where Earth observation data provide the land-surface state, the METRIC
#' surface energy balance framework provides the physical core, and
#' geographically weighted regression (GWR) is investigated as a way to
#' represent spatially varying meteorological forcing.
#'
#' @details
#' **Development status.** Version 0.1.0 is the first, experimental
#' release. It provides the METRIC core physics as numeric functions, from
#' net radiation to daily actual evapotranspiration; the meteorological
#' forcing (weather station tables, quality control, reference
#' evapotranspiration) and its regionalization over the working grid
#' (representative station, global regression, inverse distance weighting
#' and GWR); the internal MODIS preprocessing into the surface state; and
#' the example scene [cauquenes_modis]. The integrated workflow
#' `earthflux()` does not exist yet. Most METRIC formulations are candidates
#' pending verification against the primary reference (Allen et al., 2007);
#' the reference evapotranspiration (FAO-56, ASCE-EWRI 2005), the unit
#' conversions and the MODIS product facts are verified. No result has been
#' validated: EarthFlux is not for operational or scientific production
#' use. The use of GWR for meteorological forcing is treated as a research
#' hypothesis that has not been validated.
#'
#' **Design principles.**
#' * The physical core (METRIC) does not depend on any specific sensor.
#'   Sensor modules (MODIS first) convert products into standardised
#'   physical variables with documented units.
#' * Spatial regionalisation of weather data (GWR) is an independent module.
#' * Diagnostics are part of the result: physically anomalous values are
#'   flagged, never silently corrected.
#' * No equation enters the code without a reference, units, assumptions,
#'   domain of validity and a verifiable test case.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
