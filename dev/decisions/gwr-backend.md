# Decisión: backend de GWR para el módulo `spatial`

Estado: **DECIDIDA** (2026-11-04; ver "Decisiones del autor") ·
Fecha de observación: **2026-11-04** ·
Autor: Guillermo Servando Fuentes-Jaque ·
Relacionado: `ARCHITECTURE.md` §6.1 y §6.3, `SCIENTIFIC_SPEC.md` §1.2, §5 y
§6, `VALIDATION_PLAN.md` §1.1 y §2.3, `DEVELOPMENT.md` §4.

> Este documento reúne evidencia para decidir el backend de GWR. **No es una
> decisión tomada.** Todo dato de metadatos proviene de observaciones
> realizadas el 2026-11-04 (CRAN y pruebas locales); lo no observado se marca
> `TODO`. Las fórmulas se marcan `CANDIDATA` según la convención de
> `SCIENTIFIC_SPEC.md`: ninguna está `VERIFICADA` contra la fuente primaria.

## Decisiones del autor

| Fecha | Decisión | Fundamento |
|---|---|---|
| 2026-11-04 | **`spgwr` se descarta** como backend y como referencia de verificación cruzada. Solo se menciona como antecedente histórico (prototipo previo del autor, `antecedente-metric-modis.md`) y como evidencia de esta evaluación. | Paquete en modo de mantenimiento (0.6-37, 2024), dependiente de `sp`, sin MGWR; en la evaluación empírica falló la selección de bandwidth por AIC con 15 estaciones y no expone residuos *leave-one-out* por estación (secciones 3-4). Existen alternativas más actuales (`GWmodel`, `mgwrsar`). |

| 2026-11-04 | **Núcleo GWR interno** (R base, matrices) como motor de cálculo: WLS local, tr(S), AICc y CV, residuos LOO, convenciones documentadas y flags. | Los tres paquetes y el prototipo dan el mismo estimador (coeficientes ~1e-12); las diferencias son convenciones y límites ocultos que conviene controlar; evita dependencias pesadas en `Imports` (sección 8). |
| 2026-11-04 | **`GWmodel` solo en `Suggests`**, como referencia de verificación cruzada en tests (omitidos si no está instalado). | Paquete más completo y mantenido de los evaluados; coincidencia numérica demostrada con el prototipo (sección 4). |
| 2026-11-04 | **`mgwrsar`** queda como opción a evaluar si en el futuro se requiere MGWR. | MGWR disponible y desarrollo activo, pero dependencias muy pesadas y comportamiento de CV no explicado (sección 4). |

Las secciones siguientes conservan la evaluación original que sustentó estas
decisiones.

---

## 0. Resumen

- Búsqueda en CRAN: 30 paquetes mencionan GWR; 6 son implementaciones de
  propósito general (§3.1). Se evaluaron empíricamente `GWmodel` 2.4-1,
  `spgwr` 0.6-37 y `mgwrsar` 1.4.1, más un prototipo interno en base R.
- Con kernel fijo, los cuatro **coinciden numéricamente** en coeficientes
  locales (≤ 3 × 10⁻¹²), RSS, LOOCV, tr(S) (donde se expone) y predicción
  en 10⁵ celdas (≤ 6 × 10⁻¹¹). Las diferencias están en las
  **convenciones**: al menos **tres valores distintos llamados "AICc"**
  para el mismo ajuste, dos convenciones de k en el kernel adaptativo y
  dos definiciones de "número efectivo de parámetros".
- Hallazgos que afectan a EarthFlux: `GWmodel::bw.gwr()` fija en 20 el
  límite inferior del bandwidth adaptativo (sin argumento para cambiarlo);
  `GWmodel::gwr.predict()` falla si n + N > 10 000 y no se entrega la
  matriz de distancias, y su memoria crece como O(n·N); `spgwr` falla en la
  selección por AIC con 15 estaciones; `mgwrsar` tiene 153 dependencias
  duras recursivas.
- **Propuesta:** implementar internamente el núcleo GWR (WLS por punto,
  traza de S, AICc y CV, predicción por bloques) y usar `GWmodel` **solo
  en `Suggests`** como referencia cruzada en tests (con `spgwr` como
  segunda referencia ligera opcional). MGWR se difiere; si se necesita, se
  reevalúa como backend opcional externo en vez de implementarlo.

---

## 1. Contexto y requisitos

El módulo `spatial` regionaliza variables meteorológicas de estaciones
(`SCIENTIFIC_SPEC.md` §5) para forzar METRIC en cada píxel. Uso típico:

| Aspecto | Valor esperado |
|---|---|
| Estaciones por fecha | decenas a unos pocos cientos (redes chilenas poco densas: riesgo de n pequeño, §6 de la SPEC) |
| Respuestas | Ta, ea, u, Rs, ETr (según decisión metodológica 5.1) |
| Covariables | elevación, distancia a la costa, LST/NDVI (grilladas) |
| Predicción | grillas de hasta ~10⁶–10⁷ celdas, con covariables grilladas |
| Repetición | muchas fechas → paralelismo **entre fechas** (`ARCHITECTURE.md` §6.3) |

Requisitos funcionales (R) derivados de `SCIENTIFIC_SPEC.md` §6 y
`VALIDATION_PLAN.md`:

| Id | Requisito |
|---|---|
| R1 | Selección de bandwidth por AICc |
| R2 | Selección de bandwidth por validación cruzada (CV) |
| R3 | Kernel fijo y adaptativo |
| R4 | Kernels gaussiano y bicuadrado como mínimo |
| R5 | Predicción en ubicaciones no observadas usando covariables grilladas |
| R6 | Residuos, AICc, número efectivo de parámetros (traza de S), R² local |
| R7 | LOOCV (puntaje y residuos por estación) |
| R8 | MGWR (posible, no inmediato) |
| R9 | Caso límite verificable: bandwidth → ∞ ≈ OLS global (`VALIDATION_PLAN.md` §1.1) |
| R10 | Paralelismo entre fechas con `future`; resultado secuencial = paralelo |
| R11 | Integración con `terra` (backend espacial aceptado, §6.2) sin forzar `sp`/`sf` al usuario |
| R12 | Validación por bloques espaciales (`VALIDATION_PLAN.md` §2.3), no solo LOOCV |

---

## 2. Método de evaluación

- **Metadatos CRAN:** `tools::CRAN_package_db()` (25 236 filas en
  `available.packages()` el 2026-11-04), `tools::package_dependencies()`
  (recursivo, `which = c("Depends", "Imports", "LinkingTo")`),
  dependencias inversas (directas, `Depends`/`Imports`/`LinkingTo`, y con
  `Suggests`), `tools::CRAN_check_results()` y el historial de versiones
  archivadas de CRAN. Repositorio: `https://cloud.r-project.org`.
- **Búsqueda de candidatos:** expresión regular
  `geographically[- ]?weighted|\bGWR\b|\bMGWR\b` (sin distinguir
  mayúsculas) sobre `Title` + `Description`: **30 paquetes**.
- **Pruebas empíricas:** instalación desde fuentes CRAN en Ubuntu 24.04.5,
  R 4.3.3, 4 núcleos, 15 GB RAM. Los tiempos son `system.time()`
  (tiempo transcurrido): la comparación principal entre backends es la
  mediana de 3 ejecuciones con la máquina sin otra carga; el resto son
  ejecuciones únicas, algunas medidas mientras otros paquetes compilaban,
  y se señalan como orientativas. No es un benchmark formal.
- **Datos sintéticos reproducibles** (`set.seed(20261104)`):
  - dominio 100 km × 100 km en coordenadas proyectadas (m);
  - 150 estaciones con posiciones uniformes;
  - elevación = colina gaussiana (máx. ≈ 1500 m) + rampa O–E (200 m) +
    ruido N(0, 30 m);
  - `coast` = distancia a la costa (km) = x/1000;
  - `ta = b0(x, y) + b1(x, y)·elev + b2·coast + ε`, con
    `b0 = 22 − 2·y/L`, **`b1 = −0.0065 + 0.003·(x/L − 0.5)` °C m⁻¹
    (gradiente térmico que varía O–E)**, `b2 = 0.03` °C km⁻¹ (global),
    `ε ~ N(0, 0.4)`;
  - grilla de predicción 316 × 316 = 99 856 celdas (≈10⁵) y, para escalado,
    1000 × 1000 = 10⁶ celdas.
- Los scripts de evaluación fueron desechables y **no forman parte del
  repositorio**; la descripción anterior basta para reproducirlos.
  `TODO`: si se adopta la propuesta, versionar un benchmark equivalente en
  `dev/` (regla 6 de `ARCHITECTURE.md` §6.3).

---

## 3. Candidatos en CRAN (observado 2026-11-04)

### 3.1 Paquetes de GWR de propósito general

| Paquete | Versión | Publicado | Licencia | Mantenedor | NeedsCompilation | SystemRequirements |
|---|---|---|---|---|---|---|
| `GWmodel` | 2.4-1 | 2024-09-07 | GPL (≥ 2) | Binbin Lu | yes | GNU make |
| `spgwr` | 0.6-37 | 2024-06-10 | GPL (≥ 2) | Roger Bivand | yes | – |
| `mgwrsar` | 1.4.1 | 2026-10-01 | GPL (≥ 2) | Ghislain Geniaux | yes | C++17 (OpenMP opcional, `MGWRSAR_OPENMP=1`) |
| `gwrr` | 0.2-2 | 2022-05-10 | GPL (≥ 2) | David Wheeler | no | – |
| `scgwr` | 0.1.2-21 | 2021-11-11 | GPL (≥ 2) | Daisuke Murakami | no | – |
| `hgwrr` | 0.6-2 | 2025-09-28 | GPL (≥ 2) | Yigong Hu | yes | GNU make |

| Paquete | Depends | Imports | LinkingTo |
|---|---|---|---|
| `GWmodel` | R (≥ 3.0.0), robustbase, sp (> 1.4-0), Rcpp (≥ 1.0.12) | methods, sf, grDevices, spacetime, spdep, spatialreg, FNN | Rcpp, RcppArmadillo, RcppEigen |
| `spgwr` | R (≥ 2.14), sp (≥ 0.8-3), spData (≥ 2.3.1) | stats, methods | – |
| `mgwrsar` | R (≥ 3.5.0), sp, Matrix | Rcpp, ggplot2, sf, knitr, methods, doParallel, foreach, nabor, mapview, rlang, dplyr, gridExtra, grid, mboost, mgcv, caret, stringr, plotly, RhpcBLASctl, magrittr, lifecycle | Rcpp, RcppEigen, RcppArmadillo |
| `gwrr` | fields, lars | – | – |
| `scgwr` | – | FNN, spData, sp, dplyr, parallel, optimParallel | – |
| `hgwrr` | R (≥ 3.5.0), sf, stats, utils, MASS | Rcpp (≥ 1.0.8) | Rcpp, RcppArmadillo |

| Paquete | Dep. duras recursivas (sin base) | Sin base ni recomendados | ¿sp? | ¿sf? | ¿terra? | Rev. deps duras | Rev. deps (+Suggests) | Versiones archivadas (primera) | CRAN checks (13 sabores) |
|---|---|---|---|---|---|---|---|---|---|
| `GWmodel` | 46 | 37 | sí | sí | no | 4 (Compind, GeoWeightedModel, GWlasso, SpatialRegimes) | 5 | 31 (2013-06) | 13 OK |
| `spgwr` | 3 | 2 | sí | no | no | 2 (GWLelast, mgwrhw) | 2 | 44 (2006-01) | 13 OK |
| `mgwrsar` | 153 | 142 | sí | sí | sí | 1 (spboost) | 1 | 8 (2018-05) | 13 OK |
| `gwrr` | 8 | 8 | no | no | no | 0 | 0 | 3 (2011-11) | 11 OK, 2 NOTE |
| `scgwr` | 20 | 19 | sí | no | no | 0 | 0 | 4 (2019-05) | 11 OK, 2 NOTE |
| `hgwrr` | 13 | 10 | no | sí | no | 0 | 0 | 8 (2022-05) | 13 OK |

Referencia: `terra` tiene 1 dependencia dura recursiva no base (observado
el mismo día).

Estado de orfandad/archivo: ninguno de los candidatos figura como
`ORPHANED` en el campo `Maintainer` ni tiene `X-CRAN-Comment` en la base
de CRAN; todos están publicados actualmente (no archivados).

Observaciones cualitativas (de DESCRIPTION/NEWS/mensajes al cargar):

- `spgwr`: NEWS de 0.6-36 (2023-06-14) registra "drop retiring spatial
  packages"; la versión 0.6-37 aparece como "(development)" en su NEWS.md
  instalado. Al cargar imprime: *"This package does not constitute approval
  of GWR as a method of spatial analysis"*. Mantenimiento aparente de
  conservación (sin nuevas funcionalidades observadas). `TODO`: confirmar
  la política de su mantenedor sobre el futuro del paquete.
- `GWmodel`: el campo URL apunta a `http://gwr.nuim.ie/` (no verificado).
  Última versión hace ~26 meses respecto de la fecha de observación.
  `GWmodel3` **no** está en CRAN (comprobado en `available.packages()`).
- `mgwrsar`: la más reciente (2026-10-01), pero con 153 dependencias duras
  recursivas, que incluyen paquetes de visualización interactiva y
  aprendizaje automático (`mapview`, `plotly`, `leaflet`, `caret`,
  `ggplot2`, `raster`, `terra`).
- `gwrr` y `scgwr`: sin actualizaciones desde 2022 y 2021; `scgwr` es GWR
  regularizada/escalable para n grande (no es el caso de EarthFlux).
- `hgwrr`: modelo jerárquico (HGWR), no GWR básica.

### 3.2 Otros paquetes encontrados (no candidatos)

GWR especializadas o aplicaciones: `GWlasso`, `GWLelast`, `GWRLASSO`,
`GWPR.light` (panel), `gwrf` (random forest), `gwzinbr`, `mgwnbr`
(binomial negativa), `MARSGWR`, `StepGWR`, `SpatialML`, `lctools`,
`GWpcor`, `gwpcormapper`, `GWnnegPCA`; interfaces (`GeoWeightedModel`,
Shiny sobre GWmodel, 115 dep. recursivas; `mgwrhw`, salida/mapas sobre
spgwr); simulación (`SpatialPOP`, `SpPOP`); y coincidencias no relevantes
de la búsqueda (`btb`, `geopsych`, `naspaclust`, `SSIMmap`,
`spatstat.local`, `spatialkit`). Ninguno aporta un núcleo de GWR gaussiana
más adecuado que los de §3.1.

---

## 4. Evaluación empírica

### 4.1 Instalación

| Paquete | Resultado | Observaciones |
|---|---|---|
| `spgwr` | Instalado desde fuentes sin incidencias | Solo requiere `sp` y `spData` (+ `lattice`, recomendado) |
| `GWmodel` | Instalado desde fuentes | Requiere `sf` (y con él `s2`, `units`), `spdep`, `spatialreg`: 37 paquetes no base/no recomendados. En Linux exige cabeceras de GDAL, GEOS, PROJ y udunits-2 (`SystemRequirements` de `sf` y `units`; `s2` además pide Abseil y OpenSSL); hubo que instalarlas antes de compilar. Compilación: un primer intento fue interrumpido al alcanzar el límite de 600 s; la reanudación tardó 208 s más (4 núcleos) |
| `mgwrsar` | Instalado desde fuentes | Sobre lo ya instalado necesitó 75 paquetes adicionales (`ggplot2`, `plotly`, `mapview`, `leaflet`, `caret`, `raster`, …) y actualizó `terra` a 1.9-50: 782 s (3 núcleos) |

Nota: `terra` ya exige GDAL, GEOS y PROJ, de modo que el requisito de
sistema **marginal** de `GWmodel` para EarthFlux sería udunits-2 y
Abseil/OpenSSL (`s2`). En Windows y macOS CRAN distribuye binarios; los
`CRAN_check_results()` de los tres paquetes están OK en los 13 sabores
(incluye Windows y macOS), pero la instalación en esas plataformas **no**
se probó aquí (`TODO`).

### 4.2 Funcionalidades (observado ejecutando código)

| Requisito | `GWmodel` 2.4-1 | `spgwr` 0.6-37 | `mgwrsar` 1.4.1 | Prototipo interno |
|---|---|---|---|---|
| R1 AICc | `bw.gwr(approach = "AICc")` ✔ | `gwr.sel(method = "aic")` ✔ (minimiza la forma `AICb`, ver §5.1) | `search_bandwidths()` (AICc por defecto) ✔ | ✔ |
| R2 CV | `bw.gwr(approach = "CV")` ✔ | `gwr.sel(method = "cv")` ✔ (suma de cuadrados; `RMSE = FALSE`) | `search_bandwidths(control = list(criterion = "CV"))` ⚠ (ver nota 3) | ✔ |
| R3 fijo/adaptativo | `adaptive = TRUE` → k vecinos (entero). **Límite inferior de búsqueda fijo en 20** en `bw.gwr()` | `adapt` = proporción q ∈ (0, 1] de observaciones | `control$adaptive`; k con convención distinta (nota 2) | ✔ (k = k-ésimo vecino, incluido el propio punto) |
| R4 kernels | gaussian, exponential, bisquare, tricube, boxcar (fórmulas en la ayuda) | `gwr.Gauss`, `gwr.gauss`, `gwr.bisquare`, `gwr.tricube` | rectangle, bisq, tcub, epane, gauss | gaussian, exponential, bisquare, tricube, boxcar |
| R5 predicción con covariables | `gwr.predict(predictdata = )` → `prediction`, `prediction_var`, coeficientes. ⚠ nota 1 | `gwr(fit.points = <Spatial*DataFrame con covariables>, predictions = TRUE)` ✔ | `predict(model, newdata, newdata_coords)` ✔ | ✔ por bloques |
| R6 diagnósticos | `GW.diagnostic`: RSS.gw, AIC, AICc, enp, edf, gw.R2, gwR2.adj, BIC; `SDF`: residual, Stud_residual, SE, TV, Local_R2, CV_Score | `results`: v1 = tr(S), v2 = tr(SᵀS), AICb, AICh, AICc, edf, rss, sigma2; `SDF`: gwr.e, localR2, *_se, pred | slots: tS, edf, SSR, residuals, AICc, AIC, BIC, R2, R2_adj, se/sev, Shat | tr(S), tr(SᵀS), AICc, RSS, residuos (R² local no implementado en el prototipo) |
| R7 LOOCV | `gwr.basic(cv = TRUE)` → `CV_Score` por estación; `gwr.cv()`, `gwr.cv.contrib()` (exige `dMat`) ✔ | Solo devuelve el bandwidth; residuos LOO por estación no expuestos en la API exportada | `control$isgcv = TRUE` → slot `RMSE` (LOO) ✔ | ✔ |
| R8 MGWR | `gwr.multiscale()` ✔; `gwr.mixed()` | ✘ (`ggwr` es GWR generalizada) | `multiscale_gwr()`, `TDS_MGWR()`, modelos mixtos, GTWR, SAR ✔ | ✘ |
| R9 límite OLS | no probado | no probado | no probado | ✔ (máx. diferencia 2.1 × 10⁻¹⁴) |
| Entrada de datos | `Spatial*DataFrame` (`sp`) o `sf` (probado: `bw.gwr()` con `sf` funciona) | `data.frame` + matriz `coords`; `fit.points` como objeto `sp` | `data.frame` + matriz `coords` | matrices numéricas |
| Paralelismo propio | `parallel.method` = "omp", "cluster" o "cuda" | `cl =` (clúster `parallel`, solo con `fit.points` y sin hat matrix) | `ncore`, OpenMP opcional en compilación | ninguno (se paraleliza fuera con `future`) |
| n = 15 estaciones | adaptativo AICc devuelve k = 16 (> n); fijo funciona | `gwr.sel(method = "aic")` → error *"non-conformable arguments"*; CV adaptativo funciona | no probado | sin límite interno; requiere reglas explícitas (§5.4) |

Notas:

1. Sin `dMat1`, `gwr.predict()` con 150 estaciones y 99 856 celdas corrió
   127 s y terminó con el error *"object 'DM3.given' not found"*: al
   inspeccionar la función se observa que, si n + N > 10 000 y no se
   entrega `dMat1`, la variable no se define. Con
   `dMat1 = gw.dist(estaciones, celdas)` (114 MB para 150 × 99 856)
   funciona. La función además reserva una matriz de pesos n × N y un
   arreglo N × p × p: la memoria crece linealmente con N (estimado, no medido:
   150 × 10⁶ × 8 bytes ≈ 1.1 GB solo para la matriz de distancias a 10⁶
   celdas).
2. Con H = 30 adaptativo bisquare, `mgwrsar` produce coeficientes distintos
   (máx. |Δβ| = 0.86) de `GWmodel` y del prototipo, que coinciden entre sí
   (7 × 10⁻¹¹). La NEWS de 1.4.1 menciona el "(H + 2)-th neighbour" al
   describir el tope del bandwidth adaptativo de los kernels compactos, lo
   que sugiere una convención de k distinta (`TODO`: confirmar en su
   documentación). Con kernel fijo coincide.
3. `search_bandwidths(..., criterion = "CV")` con bisquare fijo devolvió
   H = 18 090 m con avisos *"Isolated points"*; el propio LOOCV de
   `mgwrsar` (`isgcv = TRUE`) en ese H es 37.21, peor que 27.37 en
   H = 36 786 m (el mínimo hallado por `spgwr` y por el prototipo). Causa
   no determinada (`TODO`); posiblemente relacionada con el reemplazo por
   OLS de los puntos aislados que documenta su NEWS.

Bandwidth seleccionado (bisquare salvo indicación; fijo en m, adaptativo
en número de vecinos):

| Configuración | Prototipo interno | `GWmodel` | `spgwr` | `mgwrsar` |
|---|---|---|---|---|
| AICc, fijo | 36 409.36 | 36 414.55 | 36 409.38 | 35 729.49 |
| CV, fijo | 36 785.73 | 36 664.15 | 36 785.73 | 18 090.17 (nota 3) |
| AICc, adaptativo | 38 (búsqueda exhaustiva 10–149) | 39 | – | 37 |
| CV, adaptativo | 38 | 39 | q = 0.2461 (≈ 36.9 de 150) | 11 |
| AICc, gaussiano fijo | 14 540.63 | 14 556.14 | 14 540.63 | – |
| AICc, gaussiano adaptativo | 10 (límite inferior de la búsqueda; k = 8 da AICc menor) | 20 (= límite inferior interno; AICc 194.49 vs. 173.35 en k = 8) | – | – |

Las diferencias pequeñas en el caso fijo provienen de la tolerancia y los
límites de cada búsqueda unidimensional; las grandes (adaptativo gaussiano,
CV de `mgwrsar`) provienen de límites o convenciones internas. Conclusión:
**los límites de búsqueda y la convención de k deben ser parámetros
explícitos y registrados** en EarthFlux.

### 4.3 Verificación cruzada numérica (bisquare fijo, bw = 40 000 m)

| Magnitud | Prototipo interno | `GWmodel` | `spgwr` | `mgwrsar` |
|---|---|---|---|---|
| máx. \|Δβ\| vs. prototipo | – | 1.9 × 10⁻¹² | 2.3 × 10⁻¹² | 2.3 × 10⁻¹² |
| RSS | 21.988635 | 21.988635 | 21.988635 | 21.98863 |
| tr(S) | 14.110126 | – (reporta `enp` = 18.001507 = 2 tr(S) − tr(SᵀS)) | `v1` = 14.110126 | `tS` = 14.11013 |
| tr(SᵀS) | 10.218746 | – | `v2` = 10.218746 | – |
| AICc | 171.521589 | 171.521589 | `AICb` = 171.521589; `AICc` = 172.449494 | 170.1586 |
| LOOCV (Σ e²₋ᵢ) | 27.491712 | 27.491712 (`gwr.cv`, `gwr.cv.contrib`, `CV_Score`) | no expuesto | 27.491712 (n · RMSE² con `isgcv`) |
| Predicción 99 856 celdas, máx. \|Δ\| | – | 5.2 × 10⁻¹¹ | 6.3 × 10⁻¹³ | 6.1 × 10⁻¹³ |
| Adaptativo k = 30: AICc / tr(S) | 173.128323 / 22.265331 | 173.128323 (\|Δβ\| 7 × 10⁻¹¹) | no comparable (q) | 169.9964 / 21.02526 (nota 2) |
| Gaussiano fijo 15 km, máx. \|Δβ\| | – | – | – | 4.5 × 10⁻¹² (misma forma `exp(−½(d/b)²)`) |

Lectura: el estimador local es el mismo en las cuatro implementaciones;
las diferencias son de **definición** de diagnósticos (AICc, enp) y de
convención del kernel adaptativo. Esto hace viable una verificación
cruzada automática del núcleo interno contra `GWmodel` y `spgwr`.

### 4.4 Tiempos (150 estaciones, 3 coeficientes)

Mediana de 3 ejecuciones con la máquina sin otra carga (bisquare fijo,
bw = 40 000 m para predicción):

| Operación | Interno (base R) | `GWmodel` | `spgwr` | `mgwrsar` |
|---|---|---|---|---|
| Selección de bandwidth AICc (fijo) | 0.12 s | 0.04 s | 0.94 s | 0.18 s |
| Predicción a 99 856 celdas | 4.11 s | 8.80 s (incluye `gw.dist()` de 150 × 99 856) | 12.25 s | 11.31 s |

Una sola ejecución (algunas con carga de compilación en paralelo; solo
orientativas):

| Operación | Tiempo |
|---|---|
| `GWmodel::gwr.basic(regression.points = 99 856 celdas)` (solo coeficientes): serial / `parallel.method = "omp"` con 4 hilos (máquina ociosa) | 12.81 s / 12.32 s (sin aceleración observable; la biblioteca compilada sí enlaza OpenMP) |
| `GWmodel::gwr.predict()` sin `dMat1` | error tras 127 s (nota 1) |
| `spgwr::gwr(fit.points = , predictions = TRUE)` serial / `cl` con 2 workers (con carga) | 11.06 s / 6.11 s, resultados iguales |
| MGWR: `GWmodel::gwr.multiscale()` (adaptativo bisquare) | 5.06 s; bandwidths 56/36/75 |
| MGWR: `mgwrsar::multiscale_gwr()` / `TDS_MGWR()` (adaptativo bisquare) | 7.59 s (18/148/148) / 2.12 s (29/150/73) |

Para 150 estaciones todos los backends seleccionan el bandwidth en menos de
1 s; el costo dominante es la **predicción a la grilla**, donde el
prototipo interno sin optimizar ya es el más rápido de los cuatro.

---

## 5. Opción de implementación interna

### 5.1 Formulación (`CANDIDATA`)

Para cada punto de regresión *i* con coordenadas (uᵢ, vᵢ), con matriz de
diseño **X** (n × p) y respuesta **y**:

- pesos `w_ij = K(d_ij / b_i)`; `b_i = b` (fijo) o `b_i` = distancia al
  k-ésimo vecino más cercano (adaptativo, k entero);
- kernels `CANDIDATA`: gaussiano `exp(−½ (d/b)²)`; bicuadrado
  `(1 − (d/b)²)²` si `d < b`, 0 si no; exponencial `exp(−d/b)`; tricúbico
  `(1 − (d/b)³)³` si `d < b`; boxcar `1` si `d < b`;
- `β̂(uᵢ, vᵢ) = (XᵀWᵢX)⁻¹ XᵀWᵢ y` (Brunsdon et al., 1996; Fotheringham et
  al., 2002) — `CANDIDATA`;
- fila *i* de la matriz hat: `sᵢ = xᵢᵀ (XᵀWᵢX)⁻¹ XᵀWᵢ`; `tr(S) = Σ sᵢᵢ`
  (número efectivo de parámetros) — `CANDIDATA`;
- `σ̂ = sqrt(RSS / n)` y
  `AICc = 2n ln σ̂ + n ln 2π + n (n + tr(S)) / (n − 2 − tr(S))`
  (forma atribuida a Fotheringham et al., 2002, a partir de Hurvich et al.,
  1998) — `CANDIDATA`, verificar ecuación y página en la fuente primaria;
- CV: `CV(b) = Σ (yᵢ − ŷ≠ᵢ(b))²`, con `w_ii = 0` al estimar en *i* —
  `CANDIDATA`;
- predicción en una celda *g* sin observación: `ŷ_g = x_gᵀ β̂(u_g, v_g)`,
  donde `β̂(u_g, v_g)` usa pesos respecto de las estaciones.

Observación importante para la SPEC: **existen al menos tres valores
distintos llamados "AICc"** en las implementaciones revisadas, para el
mismo ajuste (bisquare fijo, bw = 40 000 m, mismo RSS y mismo tr(S)):

- prototipo interno y `GWmodel`: 171.521589 (fórmula anterior);
- `spgwr`: reporta `AICb` = 171.521589 (la misma fórmula) y, por separado,
  un `AICc` = 172.449494 basado en trazas δ₁, δ₂ de matrices derivadas de
  S; `gwr.sel(method = "aic")` minimiza la primera;
- `mgwrsar`: 170.1586.

Además, `GWmodel` llama `enp` a 2 tr(S) − tr(SᵀS) (18.0015), no a tr(S)
(14.1101). La SPEC (§6) debe fijar **una** expresión de AICc y una
definición de número efectivo de parámetros, con su referencia exacta,
antes de implementar.

### 5.2 Complejidad y memoria

Notación: n estaciones, p coeficientes (≈ 2–5), N celdas de la grilla,
m evaluaciones del criterio durante la búsqueda de bandwidth.

| Etapa | Costo | Memoria |
|---|---|---|
| Ajuste en estaciones + tr(S) | O(n²p + n p³) | matriz de distancias n × n (n = 300 → 0.7 MB) |
| Selección de bandwidth | m × ajuste (golden section: m ≈ 20–30; adaptativo por rejilla de k: m ≈ n) | igual |
| Predicción a N celdas | O(N n p² + N p³) | por bloque de B celdas: B × n pesos (B = 10⁴, n = 150 → 11 MB) |

Medido con el prototipo en base R (un hilo, sin optimizar). Las filas
marcadas con * se midieron con compilaciones en paralelo en la misma
máquina (orientativas); el resto, con la máquina sin otra carga:

| Operación | Tiempo |
|---|---|
| Selección AICc, bisquare fijo, n = 50 / 150 / 300 / 600 * | 0.07 / 0.17 / 0.20 / 0.97 s |
| Selección CV, bisquare fijo, n = 150 * | 0.08 s |
| Selección AICc o CV, bisquare adaptativo (k = 10…149, búsqueda exhaustiva), n = 150 * | ≈ 0.9 s |
| Predicción 99 856 celdas, bisquare fijo (mediana de 3) | 4.1 s |
| Predicción 99 856 celdas, bisquare fijo / adaptativo * | 2.5 s / 3.5 s |
| Predicción 10⁶ celdas, bisquare fijo, bloques de 2 000 / 10 000 | 19.3 s / 20.1 s |
| 8 fechas (selección AICc + predicción 10⁵ celdas): secuencial vs. `future::plan(multisession, workers = 4)` con `future.apply::future_lapply(..., future.seed = TRUE)` | 18.1 s vs. 9.3 s; resultados `identical()` |

Extrapolación (no medida): 10⁷ celdas ≈ 3 min por fecha y variable en un
hilo con el prototipo; el cuello de botella es la predicción, no el ajuste.

### 5.3 Estrategias para grillas grandes

1. **Bloques con `terra`** (patrón de `thermify`, `ARCHITECTURE.md` §6.6):
   leer covariables por bloques (`readStart()`/`readValues()`), predecir y
   escribir (`writeStart()`/`writeValues()`); memoria acotada por B × n. El
   test "el tamaño de bloque no cambia el resultado" aplica directamente.
2. **Coeficientes en grilla gruesa + interpolación** (los coeficientes
   locales son superficies suaves a escala del bandwidth, típicamente
   decenas de km): estimar β̂ en una grilla gruesa, remuestrear a la grilla
   fina (`terra::resample(method = "bilinear")`) y calcular
   `ŷ = Σ x_k · β̂_k` con álgebra ráster. Medido: 10⁴ ajustes locales
   (grilla 100 × 100, celdas de 1 km) + bilineal a 10⁶ celdas: **0.4 s vs.
   ≈ 19 s** exacto; diferencia en la predicción de Ta: mediana
   6 × 10⁻⁵ °C, máximo 0.014 °C. Requiere que la celda gruesa sea mucho
   menor que el bandwidth (documentar y verificar con test); debe ser
   opcional y quedar registrado en la procedencia.
3. **Kernels de soporte compacto** (bisquare/tricube): permiten restringir
   cada ajuste a las estaciones dentro de b (búsqueda de vecinos), útil
   si n crece.
4. **Paralelismo:** entre fechas/variables con `future` (nivel "entre
   tareas" de §6.3); opcionalmente entre bloques de una escena. Medido:
   aceleración ≈ 1.9× con 4 workers (8 fechas) y resultados idénticos.

### 5.4 Testabilidad

- Núcleo matricial puro (`numeric`/`matrix`), sin objetos espaciales:
  tests rápidos y sin dependencias (`ARCHITECTURE.md` §3).
- Casos con solución conocida: **bandwidth → ∞ con kernel boxcar = OLS**
  (medido: máx. |β̂_GWR − β̂_OLS| = 2.1 × 10⁻¹⁴); coeficientes constantes
  recuperados; simetrías; tr(S) = p en el límite global.
- Verificación cruzada contra paquetes externos **solo en tests**
  (`Suggests` + `testthat::skip_if_not_installed()`), o fuera del tarball
  en `inst/verification/` (patrón de `thermify`). Medido: el prototipo
  coincide con `spgwr` (coeficientes 2 × 10⁻¹², tr(S), tr(SᵀS) y AICb a
  10⁻⁶; predicción a 10⁵ celdas 6 × 10⁻¹³) y con `GWmodel`
  (coeficientes 1.9 × 10⁻¹²; AICc y LOOCV a 10⁻⁶; predicción
  5 × 10⁻¹¹); ver §4.3.
- Riesgos propios: errores sutiles en convenciones (k del adaptativo con o
  sin el propio punto, distancia "≤" vs. "<" en el soporte, σ̂ con n o con
  n − 2tr(S) + tr(SᵀS)), matrices XᵀWX casi singulares con pocas
  estaciones dentro de b (requiere diagnóstico de condición y flag),
  y costo de mantener MGWR si se requiere.

---

## 6. Nota de licencias

- EarthFlux es MIT. Todos los candidatos de §3.1 son GPL (≥ 2).
- Declarar un paquete GPL en `Imports` o `Suggests` de un paquete MIT es
  práctica habitual en CRAN; la combinación distribuida/instalada queda
  sujeta a la GPL, pero el código fuente de EarthFlux puede permanecer MIT.
  `TODO`: confirmar la interpretación con la política de CRAN/OSI si se
  opta por `Imports`.
- **No se copia código** de ningún candidato (tampoco se "traduce" línea a
  línea). La implementación interna se escribe desde las fuentes primarias
  (Brunsdon et al., 1996; Fotheringham et al., 2002; Hurvich et al., 1998),
  igual que la política aplicada a `water` (`ARCHITECTURE.md` §6.4).
- Usar un paquete GPL solo como referencia en tests (`Suggests`) no
  incorpora su código al tarball.

---

## 7. Matriz comparativa

Escala: ++ muy favorable · + favorable · 0 neutro · − desfavorable ·
−− muy desfavorable. Criterios de `DEVELOPMENT.md` §4 más los del encargo.

| Criterio | Interna (+ `GWmodel` en Suggests) | `GWmodel` (Imports) | `spgwr` (Imports) | `mgwrsar` (Imports) |
|---|---|---|---|---|
| Mantenimiento | 0 — carga propia del autor | 0 — última versión 2024-09-07 (≈ 26 meses); 31 versiones archivadas desde 2013; 4 dependencias inversas duras | − — mantenimiento de conservación (NEWS: "drop retiring spatial packages"; 0.6-37 en 2024-06) | ++ — 1.4.1 del 2026-10-01; NEWS extensa con correcciones y tests de estrés |
| Disponibilidad CRAN | ++ — sin dependencia nueva | ++ — 13/13 OK | ++ — 13/13 OK | ++ — 13/13 OK |
| Multiplataforma | ++ — base R | + — compilado; arrastra `sf`/`s2`/`units` (GDAL, GEOS, PROJ, udunits-2, Abseil) | ++ — liviano | + — C++17; muchas dependencias compiladas |
| Peso de dependencias | ++ — ninguna en Imports | − — 46 recursivas (37 sin recomendados); `sp` + `sf` + `spdep` + `spatialreg` | + — 3 (`sp`, `spData`, `lattice`) | −− — 153 recursivas (visualización interactiva, ML) |
| Licencia | ++ — MIT, código propio | 0 — GPL (≥ 2), compatible vía Imports | 0 — GPL (≥ 2) | 0 — GPL (≥ 2) |
| Funcionalidades R1–R7 | + — cubiertas por el prototipo; falta R² local y diagnósticos de condición | ++ | + — sin residuos LOO expuestos; adaptativo como proporción | + — CV con comportamiento no explicado (nota 3) |
| MGWR (R8) | −− — no; requeriría backfitting propio | ++ — `gwr.multiscale()` | −− | ++ — varias variantes |
| Verificabilidad | ++ — ecuaciones de la SPEC + 3 referencias externas coincidentes | + — publicado (Gollini et al., 2015); coincide con el prototipo; `enp` con definición distinta | + — coincide exactamente; dos AICc | 0 — coincide con kernel fijo; adaptativo y AICc con convenciones propias |
| Rendimiento (predicción 10⁵) | + — 4.1 s; memoria acotada por bloque | 0 — 8.8 s; memoria O(n·N); error sin `dMat1` | − — 12.3 s | − — 11.3 s |
| Paralelismo (`future`, entre fechas) | ++ — funciones puras sobre matrices; secuencial = paralelo verificado | 0 — llamable desde workers, pero transporta objetos `sp`/`sf`; OpenMP sin ganancia observada | + — `cl` propio para `fit.points`; llamable desde workers | + — `ncore` propio; maneja su propio generador aleatorio |
| Integración `terra` / sin `sp`/`sf` | ++ | − — exige `sp` o `sf` | 0 — `data.frame` + coords, pero `fit.points` en `sp` | + — `data.frame` + coords |
| Pocas estaciones | + — reglas y flags explícitos bajo control propio | − — límite adaptativo fijo en 20; k > n con n = 15 | − — error con n = 15 (AIC) | 0 — reemplazo por OLS de puntos aislados con aviso (según su NEWS; no probado con n = 15) |

---

## 8. Recomendación (PROPUESTA para decisión del autor)

**Propuesta (opción A):** implementar internamente el núcleo de GWR
gaussiana y usar paquetes externos solo como referencia en tests.

1. Núcleo interno en `R/gwr-*.R` (archivos ya previstos en
   `ARCHITECTURE.md` §2), sobre `numeric`/`matrix`: pesos por kernel
   (gaussiano, bicuadrado; exponencial/tricúbico/boxcar opcionales), fijo y
   adaptativo con convención de k documentada, WLS local, tr(S), tr(SᵀS),
   AICc y CV (incluidos residuos LOO por estación), R² local, número de
   condición local y flags (pocos vecinos, extrapolación).
2. Envoltorio de predicción por bloques con `terra` (patrón de
   `thermify`), con opción explícita y registrada de "coeficientes en
   grilla gruesa + interpolación" para grillas de 10⁶–10⁷ celdas.
3. Paralelismo entre fechas/variables con `future` según `ARCHITECTURE.md`
   §6.3 (no dentro del núcleo).
4. `GWmodel` en `Suggests` como referencia cruzada
   (`testthat::skip_if_not_installed("GWmodel")`) para coeficientes, RSS,
   AICc, CV y predicción con kernel fijo y adaptativo; `spgwr` como segunda
   referencia ligera opcional (tr(S), tr(SᵀS)). Alternativamente, ambos
   solo en un script de verificación fuera del tarball
   (`inst/verification/`), si se quiere evitar que `R CMD check` dependa
   de ellos.
5. MGWR: **diferido**. Si llega a requerirse, evaluar primero un backend
   opcional externo (`GWmodel::gwr.multiscale()` o `mgwrsar`) declarado en
   `Suggests` y detrás de un argumento `backend =`, en lugar de
   implementarlo.

**Justificación:**

- Las pruebas muestran que el estimador es el mismo en todos los backends
  y que un prototipo de unas 70 líneas en base R lo reproduce (diferencias ≤ 10⁻¹⁰
  en coeficientes con kernel fijo y adaptativo), con predicción más rápida que los paquetes
  evaluados y memoria acotada.
- Las diferencias relevantes están en convenciones (tres AICc, dos
  convenciones de k, enp) y en límites internos no configurables (k ≥ 20
  en `GWmodel`) que, con redes poco densas, afectan precisamente el caso
  de uso de EarthFlux. Controlarlas y registrarlas en la procedencia
  (`DEVELOPMENT.md` §7) es más simple con código propio.
- Evita introducir `sp`, `sf`, `spdep` y `spatialreg` (o 153 dependencias
  en el caso de `mgwrsar`) en `Imports`, coherente con la decisión de
  `terra` (`ARCHITECTURE.md` §6.2) y la política de dependencias.
- El núcleo puro sobre matrices encaja con el principio de funciones
  vectorizadas testeables (`ARCHITECTURE.md` §3) y con el paralelismo vía
  `future` con resultados idénticos (verificado).

**Riesgos y mitigaciones:**

| Riesgo | Mitigación |
|---|---|
| Errores de implementación en diagnósticos (AICc, tr(S), LOO) | Ecuaciones `VERIFICADA` en la SPEC antes de implementar; tests contra casos límite (OLS) y contra `GWmodel`/`spgwr` |
| Elegir la "AICc equivocada" | Fijar en la SPEC §6 una única expresión con referencia exacta (ecuación y página); documentar su relación con las variantes de los paquetes |
| Rendimiento a 10⁷ celdas (extrapolado ≈ 3 min por fecha y variable, un hilo) | Bloques, interpolación de coeficientes (error medido ≤ 0.014 °C en el caso sintético), kernels compactos, paralelismo entre fechas; medir antes de optimizar |
| Sistemas locales mal condicionados con pocas estaciones | Umbral mínimo de vecinos/estaciones, número de condición y flag; nunca reemplazo silencioso (principio 6) |
| Carga de mantenimiento y eventual demanda de MGWR | Alcance acotado a GWR básica; MGWR vía backend externo opcional |
| LOOCV optimista con autocorrelación espacial | Diseñar el núcleo para aceptar particiones arbitrarias (CV por bloques espaciales, `VALIDATION_PLAN.md` §2.3) |

**Alternativas no propuestas (la decisión corresponde al autor):**

- **B. `GWmodel` en `Imports`:** máxima funcionalidad (incluye MGWR) y
  selección de bandwidth muy rápida, pero dependencias espaciales pesadas,
  memoria O(n·N) y fallo sin `dMat1` en predicción, límite adaptativo fijo
  y última versión de 2024. Sería razonable si MGWR pasara a ser requisito
  inmediato.
- **C. `spgwr` en `Imports`:** liviano y exacto, pero en mantenimiento de
  conservación, sin MGWR ni residuos LOO expuestos y con error en n pequeño.
- **D. `mgwrsar` en `Imports`:** el más activo y con más modelos, pero 153
  dependencias duras recursivas y convenciones propias (k adaptativo,
  AICc, CV) que exigirían verificación adicional.

**Preguntas para el autor:**

1. ¿MGWR es requisito de M3 o puede quedar fuera del alcance inicial?
2. ¿Referencia cruzada dentro de `tests/` (Suggests) o solo en
   `inst/verification/` fuera del tarball?
3. ¿Se acepta la interpolación de coeficientes desde grilla gruesa como
   opción documentada, o se exige predicción exacta por celda?
4. ¿Qué umbral mínimo de estaciones (o de vecinos efectivos) debe
   activar error o flag?

**Si se acepta:** actualizar `ARCHITECTURE.md` §6.1 y `DEVELOPMENT.md` §4
(no modificados en este documento), completar `SCIENTIFIC_SPEC.md` §6 con
las ecuaciones verificadas y crear un benchmark reproducible en `dev/`.

---

## 9. Registro de observaciones (2026-11-04)

| Elemento | Valor observado |
|---|---|
| Fecha | 2026-11-04 |
| Repositorio CRAN | `https://cloud.r-project.org` (`available.packages()`: 25 236 paquetes) |
| Sistema | Ubuntu 24.04.5 LTS, x86_64, 4 núcleos, 15 GB RAM, BLAS de referencia |
| R | 4.3.3 |
| Paquetes evaluados | `GWmodel` 2.4.1, `spgwr` 0.6.37, `mgwrsar` 1.4.1 |
| Paquetes de soporte | `sp` 2.2.4, `sf` 1.1.3, `spdep` 1.4.2, `spatialreg` 1.4.3, `terra` 1.9.50, `future` 1.82.0, `future.apply` 1.21.0, `Rcpp` 1.1.2, `RcppArmadillo` 15.6.2.1, `RcppEigen` 0.3.4.0.2 |
| Datos | sintéticos (§2), `set.seed(20261104)`; 150 estaciones; grillas de 99 856 y 10⁶ celdas |
| No verificado | instalación en Windows/macOS; ecuaciones contra fuentes primarias; causa de la anomalía de CV en `mgwrsar`; política futura de `spgwr`; vigencia de la URL de `GWmodel` |

## 10. Referencias

Ver `dev/REFERENCES.md`, sección GWR (Brunsdon et al., 1996; Fotheringham
et al., 2002; Hurvich et al., 1998; Gollini et al., 2015; Fotheringham et
al., 2017). Todas con `TODO: verify full citation`; ninguna fórmula de este
documento está `VERIFICADA`.
