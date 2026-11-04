# EarthFlux: Land-Surface Energy and Water Fluxes from Earth Observation Data

EarthFlux is an R package under active development that aims to provide
a reproducible, testable and auditable workflow for estimating spatially
distributed actual evapotranspiration (ETa) following the conceptual
chain

\$\$\textrm{MODIS} + \textrm{METRIC} + \textrm{GWR} \rightarrow ET_a\$\$

where Earth observation data provide the land-surface state, the METRIC
surface energy balance framework provides the physical core, and
geographically weighted regression (GWR) is investigated as a way to
represent spatially varying meteorological forcing.

## Details

**Development status.** The first METRIC component,
[`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md),
is available; its equation form is corroborated by secondary sources and
verification against the primary reference is pending. The remaining
components are being specified. The use of GWR for meteorological
forcing is treated as a research hypothesis that has not been validated.

**Design principles.**

- The physical core (METRIC) does not depend on any specific sensor.
  Sensor modules (MODIS first) convert products into standardised
  physical variables with documented units.

- Spatial regionalisation of weather data (GWR) is an independent
  module.

- Diagnostics are part of the result: physically anomalous values are
  flagged, never silently corrected.

- No equation enters the code without a reference, units, assumptions,
  domain of validity and a verifiable test case.

## See also

Useful links:

- <https://github.com/djwillichile/EarthFlux>

- <https://djwillichile.github.io/EarthFlux/>

- Report bugs at <https://github.com/djwillichile/EarthFlux/issues>

## Author

**Maintainer**: Guillermo Servando Fuentes-Jaque
<gfuentesj@correo.uss.cl>
([ORCID](https://orcid.org/0000-0002-7864-4899)) \[copyright holder\]

Authors:

- Guillermo Servando Fuentes-Jaque <gfuentesj@correo.uss.cl>
  ([ORCID](https://orcid.org/0000-0002-7864-4899)) \[copyright holder\]
