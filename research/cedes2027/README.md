# EarthFlux: Land-Surface Energy and Water Fluxes from Earth Observation Data — estudio CEDES 2027

Investigación metodológica presentada al *3rd International Workshop CEDES
2027 — Economics and Sustainability* (Universidad San Sebastián, Valdivia,
21–22 de enero de 2027). Autor: Guillermo S. Fuentes-Jaque.

**Pregunta.** ¿En qué medida la regionalización del forzamiento
meteorológico mediante regresión geográficamente ponderada (GWR) modifica la
evapotranspiración real (ETa) estimada con METRIC y MODIS, frente a una
estación representativa (C1) y a métodos convencionales (C2: regresión
global, IDW)?

**Alcance.** El estudio valida las variables meteorológicas regionalizadas
contra estaciones independientes (validación cruzada espacial anidada) y
cuantifica la propagación de las diferencias en METRIC. **No valida la
exactitud absoluta de ETa**, porque no existen mediciones públicas
independientes de flujos para el área y la fecha (ver
`docs/limitations.md`).

Este directorio no forma parte del paquete (`research/` está en
`.Rbuildignore`) y no modifica su código ni sus datos.

## Estructura

| Ruta | Contenido |
|---|---|
| `config/study.json` | Parámetros, semilla, período, CRS, tamaño de bloques, réplicas |
| `config/verification_map.csv` | Componentes de METRIC usados, estado de verificación y pruebas |
| `scripts/` | Etapas numeradas (ver abajo) y `lib_metric.R` (cadena METRIC con la API pública) |
| `data/raw/cache/` | Descargas (fuera de git); `data/raw/manifest.csv`, sumas MD5 |
| `data/processed/` | Covariables, estaciones armonizadas, objetos intermedios |
| `results/tables/` | Tablas CSV y LaTeX; `numbers.tex` y `claims_register.csv` |
| `results/figures/` | Figuras PDF/PNG y los datos de cada una |
| `results/maps/` | GeoTIFF de forzamientos y salidas de METRIC |
| `results/validation/` | Todas las predicciones fuera de muestra |
| `results/diagnostics/` | Pruebas del paquete, pliegues, rellenos, ajustes |
| `manuscript/` | Manuscrito LaTeX y PDF |
| `extended-abstract/` | Resumen extendido LaTeX y PDF; `resumen_250_palabras.md` |
| `presentation/` | Presentación oral (Beamer) |
| `references/references.bib` | Bibliografía verificada (Crossref/DataCite) |
| `docs/` | Decisiones, fuentes de datos, reproducibilidad, limitaciones |

## Reproducción

Desde la raíz de las fuentes de EarthFlux, con el paquete instalado desde
el mismo commit (`R CMD INSTALL .`):

```bash
Rscript research/cedes2027/scripts/run_all.R
```

`run_all.R` ejecuta, en orden: `01_download_data.R` (descargas y
manifiesto; llama a `01_download_dmc.py`), `02_covariates.R`,
`03_stations.R`, `04_regionalization_cv.R` (experimento R),
`05_metric_experiment.R` (experimento M), `06_sensitivity.R`
(experimento S), `07_figures_tables.R`, `08_numbers.R`, y compila el
manuscrito, el resumen extendido y la presentación con `latexmk`. Ver
`docs/reproducibility.md` para versiones, tiempos y verificaciones.
