# EarthFlux — Referencias

Estado: **en verificación (M1)**. Una referencia se considera verificada solo
cuando sus metadatos (autores, año, título, revista, volumen, número,
páginas, DOI) se contrastaron con evidencia obtenida directamente: registro
de Crossref, página oficial del editor o de la institución, o el documento
mismo. La auditoría completa, con evidencia y discrepancias, está en
[`verification/reference-audit.md`](verification/reference-audit.md).

Verificar la **cita** no equivale a verificar el **contenido** (ecuaciones,
números de ecuación, coeficientes): eso exige leer la fuente primaria y se
registra en cada especificación de `specs/`.

Convención:

- `TODO: verify full citation` — referencia conocida, cita completa sin verificar.
- `TODO: verify DOI` — cita probablemente correcta, DOI sin verificar.
- `TODO: identify ...` — la referencia primaria aún no se ha identificado.
- `VERIFIED (fecha, evidencia)` — metadatos contrastados; la evidencia es
  `Crossref` (registro en api.crossref.org), `página oficial` (editor o
  institución, con URL) o `documento` (texto completo leído).
- `PARCIAL (fecha, evidencia)` — solo parte de los metadatos pudo
  contrastarse; se indica qué falta.

---

## METRIC

- Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy
  balance for mapping evapotranspiration with internalized calibration
  (METRIC) — Model. *Journal of Irrigation and Drainage Engineering*,
  133(4), 380–394. https://doi.org/10.1061/(ASCE)0733-9437(2007)133:4(380)
  `VERIFIED (2026-11-04, Crossref)`. Texto completo **no** consultado
  (ascelibrary.org bloqueado; sin copia de autor o agencia accesible).
- Allen, R. G., Tasumi, M., Morse, A., Trezza, R., Wright, J. L.,
  Bastiaanssen, W., Kramber, W., Lorite, I., & Robison, C. W. (2007).
  Satellite-based energy balance for mapping evapotranspiration with
  internalized calibration (METRIC) — Applications. *Journal of Irrigation
  and Drainage Engineering*, 133(4), 395–406.
  https://doi.org/10.1061/(ASCE)0733-9437(2007)133:4(395)
  `VERIFIED (2026-11-04, Crossref)`
- Allen, R. G., Tasumi, M., Trezza, R., & Kjaersgaard, J. (2010). *METRIC:
  Mapping Evapotranspiration at High Resolution — Applications Manual for
  Landsat Satellite Imagery* (versión 2.0.5). University of Idaho,
  Kimberly, Idaho. Cita tomada de la bibliografía de Olmedo et al. (2016),
  p. 363. Sin DOI. `TODO: verify full citation` (sitio de la
  University of Idaho no accesible; existen versiones posteriores del
  manual citadas por terceros, no verificadas).
- Allen, R., Irmak, A., Trezza, R., Hendrickx, J. M. H., Bastiaanssen, W.,
  & Kjaersgaard, J. (2011). Satellite-based ET estimation in agriculture
  using SEBAL and METRIC. *Hydrological Processes*, 25(26), 4011–4027.
  https://doi.org/10.1002/hyp.8408 `VERIFIED (2026-11-04, Crossref)`
- Bastiaanssen, W. G. M., Menenti, M., Feddes, R. A., & Holtslag, A. A. M.
  (1998). A remote sensing surface energy balance algorithm for land
  (SEBAL). 1. Formulation. *Journal of Hydrology*, 212–213, 198–212.
  https://doi.org/10.1016/S0022-1694(98)00253-4
  `VERIFIED (2026-11-04, Crossref)`
- Tasumi, M. (2003). *Progress in operational estimation of regional
  evapotranspiration using satellite imagery* (PhD dissertation). University
  of Idaho. `TODO: verify full citation` (sin registro en Crossref; página
  institucional no accesible).
- Tasumi, M., Allen, R. G., & Trezza, R. (2008). At-surface reflectance and
  albedo from satellite for operational calculation of land surface energy
  balance. *Journal of Hydrologic Engineering*, 13(2), 51–63.
  https://doi.org/10.1061/(ASCE)1084-0699(2008)13:2(51)
  `VERIFIED (2026-11-04, Crossref)` (albedo de banda ancha en METRIC).

## MODIS

- Wan, Z. (2019). *Collection-6 MODIS Land Surface Temperature Products
  Users' Guide*. ERI, University of California, Santa Barbara. Distribuida
  por LP DAAC como guía de la colección 6.1 (C61; misma ciencia que C6):
  https://lpdaac.usgs.gov/documents/715/MOD11_User_Guide_V61.pdf
  `VERIFIED (2026-11-04, documento)`
  - Conjunto de datos: Wan, Z., Hook, S., & Hulley, G. (2021).
    *MODIS/Terra Land Surface Temperature/Emissivity Daily L3 Global 1km SIN
    Grid V061* [Data set]. NASA LP DAAC.
    https://doi.org/10.5067/MODIS/MOD11A1.061
    `VERIFIED (2026-11-04, página oficial NASA Earthdata)`
  - Guía de usuario de MOD21 (alternativa de LST/emisividad).
    `TODO: verify full citation`
- Wan, Z. (2014). New refinements and validation of the collection-6 MODIS
  land-surface temperature/emissivity product. *Remote Sensing of
  Environment*, 140, 36–45. https://doi.org/10.1016/j.rse.2013.08.027
  `VERIFIED (2026-11-04, Crossref)` (artículo de la colección 6).
- Schaaf, C. B., Gao, F., Strahler, A. H., Lucht, W., Li, X., Tsang, T.,
  Strugnell, N. C., Zhang, X., Jin, Y., Muller, J.-P., et al. (2002). First
  operational BRDF, albedo nadir reflectance products from MODIS. *Remote
  Sensing of Environment*, 83(1–2), 135–148.
  https://doi.org/10.1016/S0034-4257(02)00091-3
  `VERIFIED (2026-11-04, Crossref)`
- Myneni, R. B., Hoffman, S., Knyazikhin, Y., Privette, J. L., Glassy, J.,
  Tian, Y., et al. (2002). Global products of vegetation leaf area and
  fraction absorbed PAR from year one of MODIS data. *Remote Sensing of
  Environment*, 83(1–2), 214–231.
  https://doi.org/10.1016/S0034-4257(02)00074-3
  `VERIFIED (2026-11-04, Crossref)`
- Huete, A., Didan, K., Miura, T., Rodriguez, E. P., Gao, X., & Ferreira,
  L. G. (2002). Overview of the radiometric and biophysical performance of
  the MODIS vegetation indices. *Remote Sensing of Environment*, 83(1–2),
  195–213. https://doi.org/10.1016/S0034-4257(02)00096-2
  `VERIFIED (2026-11-04, Crossref)`
- Liang, S. (2001). Narrowband to broadband conversions of land surface
  albedo I: Algorithms. *Remote Sensing of Environment*, 76(2), 213–238.
  https://doi.org/10.1016/S0034-4257(00)00205-4
  `VERIFIED (2026-11-04, Crossref)` (Crossref registra el título sin el
  subtítulo "Algorithms").
- Rouse, J. W., Haas, R. H., Schell, J. A., & Deering, D. W. (1974).
  Monitoring vegetation systems in the Great Plains with ERTS. En *Third
  Earth Resources Technology Satellite-1 Symposium* (NASA SP-351).
  `TODO: verify full citation` (sin registro en Crossref; ntrs.nasa.gov no
  accesible). Citada para NDVI en `SCIENTIFIC_SPEC.md`.
- Estado de las misiones Terra/Aqua y deriva orbital: NASA Earthdata (2025,
  2 de mayo). *Transition from MODIS to VIIRS* [Data alert]. LAADS DAAC.
  https://www.earthdata.nasa.gov/data/alerts-outages/transition-from-modis-viirs
  `VERIFIED (2026-11-04, página oficial NASA Earthdata)`. Indica que Terra
  y Aqua comenzarán a cesar operaciones a fines de 2026 o inicios de 2027 y
  que ambas plataformas derivan de sus órbitas de diseño, lo que afecta las
  horas de paso.

## GWR

- Brunsdon, C., Fotheringham, A. S., & Charlton, M. E. (1996).
  Geographically weighted regression: A method for exploring spatial
  nonstationarity. *Geographical Analysis*, 28(4), 281–298.
  https://doi.org/10.1111/j.1538-4632.1996.tb00936.x
  `VERIFIED (2026-11-04, Crossref)`
- Fotheringham, A. S., Brunsdon, C., & Charlton, M. (2002). *Geographically
  Weighted Regression: The Analysis of Spatially Varying Relationships*.
  Wiley. `PARCIAL (2026-11-04, Crossref)`: Crossref no tiene registro del
  libro; título y autores constan en una reseña registrada en Crossref
  (O'Sullivan, 2003, *Geographical Analysis*, 35(3), 272–275,
  https://doi.org/10.1111/j.1538-4632.2003.tb01114.x). Año, editorial e
  ISBN: `TODO: verify`.
- Hurvich, C. M., Simonoff, J. S., & Tsai, C.-L. (1998). Smoothing parameter
  selection in nonparametric regression using an improved Akaike information
  criterion. *Journal of the Royal Statistical Society: Series B
  (Statistical Methodology)*, 60(2), 271–293.
  https://doi.org/10.1111/1467-9868.00125 `VERIFIED (2026-11-04, Crossref)`
- Gollini, I., Lu, B., Charlton, M., Brunsdon, C., & Harris, P. (2015).
  GWmodel: An R package for exploring spatial heterogeneity using
  geographically weighted models. *Journal of Statistical Software*, 63(17).
  https://doi.org/10.18637/jss.v063.i17 `VERIFIED (2026-11-04, Crossref)`
  (sin paginación en Crossref; la revista usa número de artículo).
- Fotheringham, A. S., Yang, W., & Kang, W. (2017). Multiscale
  geographically weighted regression (MGWR). *Annals of the American
  Association of Geographers*, 107(6), 1247–1265.
  https://doi.org/10.1080/24694452.2017.1352480
  `VERIFIED (2026-11-04, Crossref)`

## Net radiation

- Allen et al. (2007), METRIC — Model (ver arriba).
- Allen, R. G., Trezza, R., & Tasumi, M. (2006). Analytical integrated
  functions for daily solar radiation on slopes. *Agricultural and Forest
  Meteorology*, 139(1–2), 55–73.
  https://doi.org/10.1016/j.agrformet.2006.05.012
  `VERIFIED (2026-11-04, Crossref)`
- Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
  evapotranspiration: Guidelines for computing crop water requirements*
  (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
  Edición electrónica de acceso abierto:
  https://www.fao.org/4/x0490e/x0490e00.htm (la URL antigua
  `/3/x0490e/` redirige a esta). `VERIFIED (2026-11-04, página oficial FAO)`.
  Sin DOI.
- Majumdar, N. C., Mathur, B. L., & Kaushik, S. B. (1972). Prediction of
  direct solar radiation for low atmospheric turbidity. *Solar Energy*,
  13(4), 383–394. https://doi.org/10.1016/0038-092X(72)90004-7
  `VERIFIED (2026-11-04, Crossref)` (citada por `water` para τ_b).
- Allen, R. G. (1996). Assessing integrity of weather data for reference
  evapotranspiration estimation. *Journal of Irrigation and Drainage
  Engineering*, 122(2), 97–106.
  https://doi.org/10.1061/(ASCE)0733-9437(1996)122:2(97)
  `VERIFIED (2026-11-04, Crossref)` (cita). `TODO: verify` que sea el
  documento al que `water` atribuye la ecuación "extendida" de
  transmisividad (identificación probable, no confirmada).
- Bastiaanssen, W. G. M. (1995). *Regionalization of surface flux densities
  and moisture indicators in composite terrain: A remote sensing approach
  under clear skies in Mediterranean climates* (PhD thesis). Wageningen
  Agricultural University. https://doi.org/10.18174/206553
  `VERIFIED (2026-11-04, Crossref)` (citada por `water` para la forma de
  ε_a).
- Allen, R., Hartogensis, O., & de Bruin, H. (2000). *Long-wave radiation
  over alfalfa during the RAPID field campaign in southern Idaho* (Research
  report). University of Idaho, Kimberly. Cita tomada de la bibliografía de
  Wasti (2020, arXiv:2007.13922); corresponde al "Allen (2000), informe
  interno RAPID" citado por `water` para los coeficientes de ε_a.
  `TODO: verify full citation` (informe sin DOI; no localizado).
- Liu, B. Y. H., & Jordan, R. C. (1960). The interrelationship and
  characteristic distribution of direct, diffuse and total solar radiation.
  *Solar Energy*, 4(3), 1–19. https://doi.org/10.1016/0038-092X(60)90062-1
  `VERIFIED (2026-11-04, Crossref)`
- Liu, B. Y. H., & Jordan, R. C. (1963). The long-term average performance
  of flat-plate solar-energy collectors. *Solar Energy*, 7(2), 53–74.
  https://doi.org/10.1016/0038-092X(63)90006-9
  `VERIFIED (2026-11-04, Crossref)`. `TODO: identify` cuál de las dos
  obras de Liu y Jordan es la fuente primaria del modelo isotrópico de
  difusa sobre superficies inclinadas.
- Duffie, J. A., & Beckman, W. A. (2013). *Solar Engineering of Thermal
  Processes*. Wiley. https://doi.org/10.1002/9781118671603
  `VERIFIED (2026-11-04, Crossref)`. Edición posterior: Duffie, J. A.,
  Beckman, W. A., & Blair, N. (2020). *Solar Engineering of Thermal
  Processes, Photovoltaics and Wind*. Wiley.
  https://doi.org/10.1002/9781119540328 `VERIFIED (2026-11-04, Crossref)`.
  `TODO`: fijar la edición y el número de ecuación usados.
- Spencer, J. W. (1971). Fourier series representation of the position of
  the sun. *Search*, 2(5), 172. `TODO: verify full citation` (sin registro
  en Crossref).
- Tiesinga, E., Mohr, P. J., Newell, D. B., & Taylor, B. N. (2021). CODATA
  recommended values of the fundamental physical constants: 2018. *Reviews
  of Modern Physics*, 93(2), 025010.
  https://doi.org/10.1103/RevModPhys.93.025010
  `VERIFIED (2026-11-04, Crossref)`. Misma obra en *Journal of Physical and
  Chemical Reference Data*, 50(3), 033105 (2021),
  https://doi.org/10.1063/5.0064853 `VERIFIED (2026-11-04, Crossref)`.
  Fuente del valor de σ.
- Fuentes citadas por Wasti (2020) para la forma de Rn (corroboración
  secundaria; ver `verification/reference-audit.md`):
  - Hipps, L. E. (1989). The infrared emissivities of soil and *Artemisia
    tridentata* and subsequent temperature corrections in a shrub-steppe
    ecosystem. *Remote Sensing of Environment*, 27(3), 337–342.
    https://doi.org/10.1016/0034-4257(89)90093-X
    `VERIFIED (2026-11-04, Crossref)`
  - Brunsell, N. A., & Gillies, R. R. (2002). Incorporating surface
    emissivity into a thermal atmospheric correction. *Photogrammetric
    Engineering and Remote Sensing*, 68(12), 1263–1270.
    `TODO: verify full citation` (sin registro en Crossref; número de
    fascículo no confirmado).
- Fuente reciente de la irradiancia solar total (≈ 1361 W m⁻²).
  `TODO: identify`
- Modelos de descomposición de la radiación global en directa y difusa.
  `TODO: identify`
- Regresión banda angosta → banda ancha de emisividad para MODIS.
  `TODO: identify`

## Soil heat flux

- Bastiaanssen, W. G. M. (2000). SEBAL-based sensible and latent heat fluxes
  in the irrigated Gediz Basin, Turkey. *Journal of Hydrology*, 229(1–2),
  87–100. https://doi.org/10.1016/S0022-1694(99)00202-4
  `VERIFIED (2026-11-04, Crossref)`
- Tasumi (2003) (ver METRIC). `TODO: identify the G formulation used in METRIC`

## Aerodynamic resistance

- Paulson, C. A. (1970). The mathematical representation of wind speed and
  temperature profiles in the unstable atmospheric surface layer. *Journal
  of Applied Meteorology*, 9(6), 857–861.
  https://doi.org/10.1175/1520-0450(1970)009<0857:TMROWS>2.0.CO;2
  `VERIFIED (2026-11-04, Crossref)`
- Webb, E. K. (1970). Profile relationships: The log-linear range, and
  extension to strong stability. *Quarterly Journal of the Royal
  Meteorological Society*, 96(407), 67–90.
  https://doi.org/10.1002/qj.49709640708 `VERIFIED (2026-11-04, Crossref)`
- Brutsaert, W. (1982). *Evaporation into the Atmosphere: Theory, History,
  and Applications*. D. Reidel, Dordrecht.
  https://doi.org/10.1007/978-94-017-1497-6
  `VERIFIED (2026-11-04, Crossref)` (Crossref registra el título sin
  subtítulo y como editorial a Springer Netherlands, sucesora de Reidel; el
  subtítulo se toma de la bibliografía de Wasti, 2020, y no está verificado).

## Sensible heat flux

- Allen et al. (2007), METRIC — Model (ver arriba).
- Bastiaanssen et al. (1998), SEBAL (ver arriba).

## Latent heat flux

- Allen et al. (2007), METRIC — Model (ver arriba).

## Reference evapotranspiration

- ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
  Equation* (R. G. Allen, I. A. Walter, R. L. Elliott, T. A. Howell,
  D. Itenfisu, M. E. Jensen, & R. L. Snyder, Eds.). Technical Committee on
  Standardization of Reference Evapotranspiration, Environmental and Water
  Resources Institute. American Society of Civil Engineers, Reston, VA.
  https://doi.org/10.1061/9780784408056 `VERIFIED (2026-11-04, Crossref)`
- Allen et al. (1998), FAO-56 (ver arriba).

## Anchor pixel selection

- Allen, R. G., Burnett, B., Kramber, W., Huntington, J., Kjaersgaard, J.,
  Kilic, A., Kelly, C., & Trezza, R. (2013). Automated calibration of the
  METRIC-Landsat evapotranspiration process. *Journal of the American Water
  Resources Association*, 49(3), 563–576.
  https://doi.org/10.1111/jawr.12056 `VERIFIED (2026-11-04, Crossref)`
- Morton, C. G., Huntington, J. L., Pohll, G. M., Allen, R. G., McGwire,
  K. C., & Bassett, S. D. (2013). Assessing calibration uncertainty and
  automation for estimating evapotranspiration from agricultural areas using
  METRIC. *Journal of the American Water Resources Association*, 49(3),
  549–562. https://doi.org/10.1111/jawr.12054
  `VERIFIED (2026-11-04, Crossref)`

## Scientific validation

- Twine, T. E., Kustas, W. P., Norman, J. M., Cook, D. R., Houser, P. R.,
  Meyers, T. P., Prueger, J. H., Starks, P. J., & Wesely, M. L. (2000).
  Correcting eddy-covariance flux underestimates over a grassland.
  *Agricultural and Forest Meteorology*, 103(3), 279–300.
  https://doi.org/10.1016/S0168-1923(00)00123-4
  `VERIFIED (2026-11-04, Crossref)`
- Wilson, K., Goldstein, A., Falge, E., Aubinet, M., Baldocchi, D.,
  Berbigier, P., et al. (2002). Energy balance closure at FLUXNET sites.
  *Agricultural and Forest Meteorology*, 113(1–4), 223–243.
  https://doi.org/10.1016/S0168-1923(02)00109-0
  `VERIFIED (2026-11-04, Crossref)`
- Gupta, H. V., Kling, H., Yilmaz, K. K., & Martinez, G. F. (2009).
  Decomposition of the mean squared error and NSE performance criteria:
  Implications for improving hydrological modelling. *Journal of
  Hydrology*, 377(1–2), 80–91. https://doi.org/10.1016/j.jhydrol.2009.08.003
  `VERIFIED (2026-11-04, Crossref)`
- Willmott, C. J. (1981). On the validation of models. *Physical
  Geography*, 2(2), 184–194. https://doi.org/10.1080/02723646.1981.10642213
  `VERIFIED (2026-11-04, Crossref)`
- Roberts, D. R., Bahn, V., Ciuti, S., Boyce, M. S., Elith, J.,
  Guillera-Arroita, G., et al. (2017). Cross-validation strategies for data
  with temporal, spatial, hierarchical, or phylogenetic structure.
  *Ecography*, 40(8), 913–929. https://doi.org/10.1111/ecog.02881
  `VERIFIED (2026-11-04, Crossref)`

## Author's prior work (antecedentes del autor)

Trabajos con participación del autor que aportan evidencia a decisiones de
EarthFlux. Metadatos `VERIFIED (2026-11-04, Crossref)`; contenido leído
**solo a nivel de resumen** (Crossref) hasta habilitar el acceso a los
textos completos (`polipapers.upv.es`, `www.mdpi.com`, `www.nature.com`).

- Galdón-Ruíz, A., Fuentes-Jaque, G., Soto, J., & Morales-Salinas, L.
  (2023). A simple method for the estimation of minimum and maximum air
  temperature monthly mean maps using MODIS images in the region of Murcia,
  Spain. *Revista de Teledetección*, (61), 59–71.
  https://doi.org/10.4995/raet.2023.18909 — GWR de Tmin/Tmax con LST MODIS
  como covariable (GW-07).
- Montaner-Fernández, D., Morales-Salinas, L., Rodriguez, J. S.,
  Cárdenas-Jirón, L., Huete, A., Fuentes-Jaque, G., Pérez-Martínez, W., &
  Cabezas, J. (2020). Spatio-temporal variation of the urban heat island in
  Santiago, Chile during summers 2005–2017. *Remote Sensing*, 12(20), 3345.
  https://doi.org/10.3390/rs12203345 — MODIS + estaciones + GWR en Santiago
  (GW-07).
- Morales-Salinas, L., Ortega-Farías, S., Riveros-Burgos, C., Chávez, J. L.,
  Wang, S., Tian, F., Carrasco-Benavides, M., Neira-Román, J.,
  López-Olivari, R., & Fuentes-Jaque, G. (2023). Assessment of atmospheric
  emissivity models for clear-sky conditions with reanalysis data.
  *Scientific Reports*, 13, 14465.
  https://doi.org/10.1038/s41598-023-40499-6 — modelos de emisividad
  atmosférica para RL↓ (RC-13).

## Related software

- Olmedo, G. F., Ortega-Farías, S., de la Fuente-Sáiz, D., Fonseca-Luengo,
  D., & Fuentes-Peñailillo, F. (2016). water: Tools and functions to
  estimate actual evapotranspiration using land surface energy balance
  models in R. *The R Journal*, 8(2), 352–369.
  https://doi.org/10.32614/RJ-2016-051
  `VERIFIED (2026-11-04, Crossref + página oficial)`: DOI y página inicial
  en Crossref; páginas 352–369, volumen, número y autores en
  https://journal.r-project.org/articles/RJ-2016-051/index.html (el PDF
  imprime "Fonseca-Luego", errata; la página del artículo usa
  "Fonseca-Luengo").
  - Software: `water` v1.0 (2026-10-19), https://github.com/midraed/water,
    licencia GPL (≥ 2) (datos registrados en una revisión previa;
    github.com no accesible el 2026-11-04 para reconfirmarlos). En CRAN el
    paquete figura como **archivado el 2021-10-05** ("check problems were
    not corrected in time"); última versión en CRAN: 0.8 (2018-04-24).
    `VERIFIED (2026-11-04, página oficial CRAN)`:
    https://CRAN.R-project.org/package=water
- DOI de las referencias de anclas (Allen et al., 2013; Morton et al., 2013)
  mencionados en el código de `water`: `10.1111/jawr.12056` corresponde a
  Allen et al. (2013) y `10.1111/jawr.12054` a Morton et al. (2013).
  `VERIFIED (2026-11-04, Crossref)`
- Wasti, S. (2020). *Estimation of land surface evapotranspiration in Nepal
  using Landsat based METRIC model* (tesis de maestría). University of
  Chinese Academy of Sciences, Institute of Tibetan Plateau Research.
  arXiv:2007.13922 [physics.geo-ph] (v1 2020-07-28; v2 2020-08-01).
  https://arxiv.org/abs/2007.13922 `VERIFIED (2026-11-04, documento)`.
  Corroboración secundaria de la forma de Rn (Ec. 2.6, p. 24 impresa;
  p. 38 del PDF).
- Otras implementaciones de balance de energía (p. ej., en Google Earth
  Engine y plataformas operacionales de ET). `TODO: identify and verify`
