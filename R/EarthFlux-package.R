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
#' **Development status.** The first METRIC component,
#' [ef_net_radiation()], is available; its equation form is corroborated by
#' secondary sources and verification against the primary reference is
#' pending. The remaining components are being specified. The use of GWR for
#' meteorological forcing is treated as a research hypothesis that has not
#' been validated.
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
