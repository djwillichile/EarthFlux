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

**Development status.** Version 0.1.0 is the first, experimental
release. It provides the METRIC core physics as numeric functions, from
net radiation to daily actual evapotranspiration; the meteorological
forcing (weather station tables, quality control, reference
evapotranspiration) and its regionalization over the working grid
(representative station, global regression, inverse distance weighting
and GWR); the internal MODIS preprocessing into the surface state; and
the example scene
[cauquenes_modis](https://djwillichile.github.io/EarthFlux/reference/cauquenes_modis.md).
The integrated workflow `earthflux()` does not exist yet. Most METRIC
formulations are candidates pending verification against the primary
reference (Allen et al., 2007); the reference evapotranspiration
(FAO-56, ASCE-EWRI 2005), the unit conversions and the MODIS product
facts are verified. No result has been validated: EarthFlux is not for
operational or scientific production use. The use of GWR for
meteorological forcing is treated as a research hypothesis that has not
been validated.

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
