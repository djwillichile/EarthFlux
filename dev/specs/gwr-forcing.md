# EarthFlux — Especificación: forzamiento meteorológico espacial (GWR y alternativas de referencia)

Estado: **borrador M1** · Módulo: `spatial` (`ARCHITECTURE.md` §2) ·
Archivos de destino: `R/gwr-fit.R`, `R/gwr-bandwidth.R`, `R/gwr-predict.R`,
`R/gwr-diagnostics.R` (y, propuesto, un archivo para las alternativas de
referencia, decisión GW-22) · Tests: `tests/testthat/test-gwr-*.R`
(nombres en §11) · Autor: Guillermo Servando Fuentes-Jaque.

> Este documento detalla `SCIENTIFIC_SPEC.md` §6 (GWR) y la parte espacial
> de §5, e implementa el contrato `forcing` → `spatial` → consumidores de
> `weather-forcing.md` §7.2 (con las enmiendas propuestas en §2.5).
> `SCIENTIFIC_SPEC.md` sigue siendo la fuente de verdad: cuando una
> formulación de este documento pase a `VERIFICADA`, su estado, referencia y
> caso numérico se trasladan allí. Nada de este documento puede
> implementarse hasta cumplir la Definition of Done (`DEVELOPMENT.md` §3).

> **Backend — DECIDIDO por el autor (2026-11-04).** (1) El motor de
> cálculo es un **núcleo GWR interno** en base R sobre matrices simples;
> (2) `GWmodel` se declara **solo en `Suggests`** como referencia cruzada en
> tests (omitidos si no está instalado); (3) `mgwrsar` es la opción a
> evaluar más adelante **solo si** se requiere MGWR; (4) `spgwr` queda
> descartado (mantenimiento de conservación): aquí se menciona solo como
> antecedente histórico (§1.4) y como evidencia de la evaluación del
> backend (`dev/decisions/gwr-backend.md`). Ver §1.2.

> **Estado de implementación — núcleo GWR interno (M3, 2026-11-04).**
> Implementados en `R/gwr-fit.R`, `R/gwr-bandwidth.R`, `R/gwr-predict.R`
> y `R/gwr-diagnostics.R`: `ef_gwr_fit()`, `ef_gwr_bandwidth()`,
> `ef_gwr_search()`, `ef_gwr_predict()`, `ef_gwr_diagnostics()` y las
> internas de §9.2 (`gwr_distance()`, `gwr_row_bandwidth()`,
> `gwr_kernel_weights()`, `gwr_check_design()`, `gwr_local_wls()` (QR de
> referencia), `gwr_local_solve()` (momentos + Cholesky vectorizado),
> `gwr_aicc()`, `gwr_cv_score()`, `gwr_scale_design()`,
> `gwr_unscale_coef()`, `gwr_extrapolation_flags()`,
> `gwr_predict_block()`, `gwr_flag_word()`). Tests:
> `tests/testthat/test-gwr.R`, `test-gwr-fit.R`, `test-gwr-bandwidth.R`,
> `test-gwr-predict.R`, `test-gwr-crosscheck.R` (con
> `skip_if_not_installed("GWmodel")`) y `helper-gwr.R` (datos de §10 y
> generador del sintético G7). Casos G1a–G7 reproducidos; verificación
> cruzada con `GWmodel` 2.4-1 a 1 × 10⁻¹⁰ (coeficientes, RSS, AICc, AIC,
> `enp_alt`, edf, CV, residuos LOO, R² local en su convención con kernel
> fijo, predicción). Pendiente para la fase de orquestación:
> `ef_regionalize()`, `ef_method_*()`, `ef_predict_control()`, modo
> grueso (§6.2), CV por bloques (§8.2), C1/C2 (§5), I de Moran (§7.3).
>
> Decisiones y desviaciones tomadas al implementar (para registrar en
> `DECISIONS.md`):
>
> 1. `kernel` (GW-04) y `criterion` (GW-05) sin defecto; `search` es
>    obligatorio en `ef_gwr_bandwidth()`. En `ef_gwr_search()` los
>    parámetros numéricos valen `NULL` ("no fijado") y se exigen
>    (`earthflux_missing_input`) solo cuando la búsqueda los usa: `n_grid`
>    y `tol` (fijo), `lower_offset` (límite inferior automático con
>    bicuadrado/tricúbico), `upper_factor` (límite superior automático).
>    `method_adaptive` solo admite `"exhaustive"` (la sección áurea
>    entera queda sin implementar).
> 2. Errores de dimensión: se usa `earthflux_input_error` (como el resto
>    del núcleo, p. ej. `check_same_dim()`); **no** se creó
>    `earthflux_dimension_error`. k no entero → `earthflux_domain_error`
>    (§9.3). Subclases nuevas: `earthflux_gwr_error` (padre),
>    `earthflux_gwr_insufficient_stations` (campos `n`, `p`),
>    `earthflux_gwr_no_feasible_bandwidth` (campo `profile`),
>    `earthflux_gwr_singular_error` (campo `stations`).
> 3. Argumentos añadidos a §9.1: `station_id` en `ef_gwr_fit()` y
>    `ef_gwr_bandwidth()`; `scale_covariates` en `ef_gwr_bandwidth()`;
>    `chunk_rows` en `ef_gwr_predict()` (solo memoria; el resultado no
>    cambia); `ef_gwr_predict()` devuelve además `bandwidth` (b_g en m).
>    `bandwidth` de `ef_gwr_fit()` acepta el objeto
>    `earthflux_gwr_bandwidth` (hereda kernel, tipo, `min_neighbours`,
>    perfil y flags de objeto). Se omitió `kappa_max`: su flag
>    (`EF_GWR_ILL_CONDITIONED`) es de clase II y no se evalúa; κ se reporta
>    por estación (`stations$kappa`) y no se incluye en el perfil.
> 4. Rango numérico: un pivote de Cholesky de la matriz de momentos
>    escalada ≤ 10⁻¹⁰ × su elemento diagonal marca rango deficiente; LOO
>    indefinido si 1 − s_ii ≤ 10⁻¹⁰; tolerancia de borde de la envolvente
>    10⁻⁹ × extensión de las estaciones. Convenciones numéricas registradas
>    en `conventions`, no constantes científicas. κ = número de condición
>    de W^{1/2}X en unidades originales con columnas de norma 1
>    (reproduce 3,2378 de G1b).
> 5. Sumas ponderadas con `colSums()` (no BLAS) para que el resultado de
>    una fila no dependa del bloque (test `identical()`); k-ésima distancia
>    por fila con `order(..., method = "radix")`.
> 6. `EF_GWR_EXTRAPOLATION_LOCAL` se evalúa solo con kernels compactos y
>    también se marca en celdas singulares si la condición se cumple;
>    `EF_GWR_AICC_UNDEFINED` se evalúa en la búsqueda solo con criterio
>    AICc y en `ef_gwr_fit()` con bandwidth del usuario.
>    `EF_INPUT_NA` (bit 0) lo levanta ya `ef_gwr_predict()`.
> 7. Hallazgos en los casos de §10: (a) G1b imprime ŷ₁ = 20,090654, pero
>    los coeficientes impresos dan 20,0906523 (errata de redondeo; el test
>    usa β̂₀ + 100 β̂₁); (b) G1a no admite el ajuste completo: con boxcar
>    15 km S6 queda sola (singular), y el test excluye S6 (respuesta `NA`)
>    sin cambiar el ajuste local en S1; (c) con gaussiano/exponencial la
>    regla de vecinos "dentro de un bandwidth" (§4.5) fija el límite
>    inferior automático: en G7 gaussiano fijo el mínimo queda en ese
>    límite (18 361 m, `EF_GWR_BW_AT_BOUND`) aunque b = 14 541 m tiene
>    AICc menor; en el caso pequeño hace no factible todo b < 28,3 km por
>    S6. (d) G7 adaptativo gaussiano: mínimo en k = 9 (perfil multimodal).
> 8. Hallazgos de la verificación cruzada con `GWmodel` 2.4-1: (a)
>    reporta un AICc aunque n − 2 − tr S ≤ 0 (−86 con k = 5 bicuadrado en
>    el caso pequeño), que EarthFlux deja `NA`; (b) su `Local_R2`
>    adaptativo usa los pesos transpuestos w_ji (bandwidth de la estación
>    j), además de ŷ global y media no ponderada; con kernel fijo coincide
>    con la variante de §3.8; (c) `enp + edf = n`, de modo que tr S no es
>    recuperable de esos dos campos; se recupera de su AICc y su RSS
>    (coincide a 10⁻¹⁰).
> 9. Rendimiento (R 4.3.3, un hilo, BLAS de referencia; mediana de 3
>    ejecuciones, orientativo): predicción exacta de 150 estaciones a
>    99 856 celdas en ≈ 2,6–3,0 s (bicuadrado fijo), ≈ 1,9–2,0 s
>    (gaussiano fijo) y ≈ 2,8–3,6 s (bicuadrado adaptativo); selección
>    AICc fija (30 valores + Brent) ≈ 0,2 s; adaptativa exhaustiva
>    ≈ 0,4 s. Benchmark: `dev/benchmarks/gwr-core.R`.

Convención de estados: la misma de `SCIENTIFIC_SPEC.md` (`TODO`,
`CANDIDATA`, `VERIFICADA`). Aquí `VERIFICADA` significa **contrastada en
esta redacción con la fuente leída**, con su ubicación exacta. Como en
`sensible-heat.md`, se distingue "`VERIFICADA` como contenido de la fuente
X" de su **uso** como definición de EarthFlux, que puede seguir
`CANDIDATA`. Los casos numéricos de §10 fueron calculados por el autor con
código propio (base R) y verifican aritmética y convenciones, no física.

---

## 0. Índice y resumen

1. Alcance, decisión de backend, fuentes y antecedente del autor
2. Contrato: entradas, salidas, configuración por variable
3. Modelo: GWR como mínimos cuadrados ponderados locales
4. Selección de bandwidth
5. Referencia global (OLS) y métodos de comparación C1, C2, C3
6. Predicción a grillas
7. Objeto de diagnóstico `earthflux_gwr`
8. Hooks de validación
9. Descomposición en funciones, errores con clase, NA y dominio
10. Casos numéricos verificables y plan de verificación cruzada
11. Tests planificados
12. Flags propuestos (no registrados)
13. Decisiones (GW-01 … ; cerradas y abiertas)
14. Ítems a verificar en fuentes primarias
15. Hallazgos que afectan a otros documentos (no editados aquí)
16. Registro de fuentes y accesos

Resumen de estados:

| Elemento | Forma adoptada | Estado | Evidencia |
|---|---|---|---|
| Estimador local | β̂ᵢ = (XᵀWᵢX)⁻¹XᵀWᵢy | `VERIFICADA` como contenido de Gollini et al. (2015), preprint arXiv:1306.0413v2, §6.1, p. 19; como definición de EarthFlux: `CANDIDATA (corroborada)` | Cuatro implementaciones coinciden a ≤ 3 × 10⁻¹² (`gwr-backend.md` §4.3); caso G2 (§10) |
| Kernels gaussiano, exponencial, bicuadrado, tricúbico, boxcar | §3.4 | `VERIFICADA` como contenido de Gollini et al. (preprint, Tabla 1, p. 5); uso: `CANDIDATA (corroborada)` | Coincidencia numérica con `GWmodel` (y con los demás paquetes de la evaluación del backend); diferencia documentada en el borde del boxcar (§3.4) |
| Convención de k adaptativo | b_i = distancia al k-ésimo punto más cercano **contando el propio punto** | Convención de EarthFlux (no es una fórmula) | Coincide con `GWmodel` 2.4-1 (caso G3); otros paquetes de la evaluación usan otras (§3.5) |
| Número efectivo de parámetros | tr(S) (usado en AICc); se reportan también tr(SᵀS), 2tr(S) − tr(SᵀS) y n − 2tr(S) + tr(SᵀS) | tr(S) en AICc: `VERIFICADA` como contenido de Gollini et al. (§6.1); resto: `CANDIDATA` | §3.6 |
| AICc | 2n ln σ̂ + n ln 2π + n (n + tr S)/(n − 2 − tr S), σ̂ = √(RSS/n), n = número de estaciones del ajuste | Forma `VERIFICADA` como contenido de Gollini et al. (§6.1, p. 20); σ̂ no especificado allí; como definición de EarthFlux: `CANDIDATA (corroborada)` | Reproduce exactamente el AICc de `GWmodel` (casos G2 y sintético) y la forma `AICb` de `spgwr` en la evaluación del backend (§4.1–4.2) |
| LOOCV | CV(b) = Σᵢ (yᵢ − ŷ≠ᵢ)², con wᵢᵢ = 0 al estimar en i | `CANDIDATA (corroborada)` | Coincide con `GWmodel` (`CV_Score`, `gwr.cv`) y `mgwrsar`; identidad de borrado verificada (§4.3) |
| R² local | R² del ajuste WLS local en i (media ponderada) | `CANDIDATA`; **tres convenciones distintas** observadas (§3.8) | Caso G2 |
| Búsqueda de bandwidth | Fijo: rejilla log + refinamiento de Brent (`stats::optimize`); adaptativo: exhaustiva en k | Diseño (no es fórmula) | Perfiles multimodales con pocas estaciones (§4.6) |
| Detección de extrapolación | Rango de covariables, envolvente convexa, distancia a la estación más cercana, vecinos con peso no nulo | Diseño; umbrales sin defecto | §6.3 |
| Varianza/incertidumbre de predicción | — | `TODO` (no se entrega en la primera versión) | §2.4, GW-19 |
| I de Moran de residuos | Diagnóstico opcional | `TODO` (fuente primaria no leída) | §7.3 |

---

## 1. Alcance, decisión de backend, fuentes y antecedente del autor

### 1.1 Alcance

Incluye: (i) la regionalización de variables meteorológicas de estación
sobre la grilla de trabajo mediante GWR (C3) y mediante las alternativas
de comparación de `VALIDATION_PLAN.md` §2.1 (C1 estación representativa,
C2 alternativa espacial de referencia), todas con la **misma interfaz**;
(ii) la selección de bandwidth; (iii) la predicción por bloques con
`terra`; (iv) los diagnósticos, flags y procedencia; (v) los hooks de
validación cruzada (LOOCV y por bloques espaciales).

No incluye: QC de estaciones y cálculo de variables derivadas y ETr
(`weather-forcing.md`); qué variables se regionalizan (decisión 5.1,
`weather-forcing.md` §6; este módulo las acepta todas); viento a altura de
mezcla y rugosidad de la estación (`sensible-heat.md` §6); ETr por píxel
en la opción C (funciones `ef_*()` de `weather-forcing.md` §4–5 aplicadas
sobre `SpatRaster`, orquestadas por `api`); MGWR (diferido, GW-16).

Regla de independencia (`ARCHITECTURE.md` principio 3): `spatial` no conoce
METRIC, ETr ni anclas. Trata cada variable como una respuesta numérica con
unidad y dominio físico declarados (§2.3).

### 1.2 Decisión de backend (DECIDIDA, 2026-11-04)

Decisión del autor sobre la evaluación de `gwr-backend.md`:

| Elemento | Decisión | Consecuencia en esta especificación |
|---|---|---|
| Motor de cálculo | **Núcleo GWR interno** en base R sobre `numeric`/`matrix` (WLS local, tr S, AICc, CV, predicción por bloques) | §3–4 y §6 se implementan con código propio desde las fuentes; ninguna dependencia nueva en `Imports` para GWR |
| Referencia cruzada | **`GWmodel` solo en `Suggests`**, en tests con `testthat::skip_if_not_installed("GWmodel")` | §10 (plan de verificación cruzada) y §11 usan únicamente `GWmodel` |
| MGWR | Fuera del alcance inicial; **`mgwrsar`** es la opción a evaluar más adelante si MGWR llega a requerirse | GW-16; si se adopta, sería un backend externo opcional detrás de un argumento explícito, con sus convenciones (k adaptativo, AICc) mapeadas y registradas |
| `spgwr` | **Descartado** (mantenimiento de conservación, más antiguo); no se usa ni siquiera como referencia opcional | Solo aparece como antecedente histórico (§1.4) y en la evidencia de la evaluación del backend (§3.5, §4.2) |

Pendiente como consecuencia (no editado aquí): registrar la decisión en
`ARCHITECTURE.md` §6.1 y `DEVELOPMENT.md` §4 (§15).

Condición de diseño que se mantiene: la **interfaz pública y los
contratos de §2, §7 y §9.1 no dependen del motor**, de modo que un backend
opcional futuro (p. ej., `mgwrsar` para MGWR) pueda añadirse sin tocar a
los consumidores. Diferencias que habría que mapear en ese caso:
convenciones de k y de AICc (§3.5, §4.2) y límites internos de búsqueda.

### 1.3 Fuentes y nivel de evidencia

| Fuente | Tipo | Acceso en esta redacción | Uso |
|---|---|---|---|
| Gollini, I., Lu, B., Charlton, M., Brunsdon, C., & Harris, P. (2015). GWmodel: An R package for exploring spatial heterogeneity using geographically weighted models. *Journal of Statistical Software*, 63(17). DOI `10.18637/jss.v063.i17` | Primaria (para las definiciones de `GWmodel`; secundaria respecto del AICc original) | **Leída** la versión preprint `arXiv:1306.0413v2` (17 mar 2014) en `arxiv.org`: §3.2 y Tabla 1 (kernels, p. 5), §6.1 (estimador WLS, p. 19; AICc, p. 20), §7 (colinealidad local, número de condición, pp. 25–27). La versión publicada en JSS **no** fue accesible (`www.jstatsoft.org` bloqueado): paginación y posibles cambios de texto `TODO` | Kernels, estimador, AICc, diagnóstico de condición |
| Brunsdon, Fotheringham & Charlton (1996), *Geographical Analysis* 28(4) | Primaria | Solo metadatos y **resumen** (Crossref) | Existencia del método y de las pruebas de no estacionariedad; ninguna fórmula verificada |
| Hurvich, Simonoff & Tsai (1998), *JRSS B* 60(2) | Primaria | Solo metadatos y **resumen** (Crossref): AICc para "any linear smoother" | El texto completo **no** fue accesible (`academic.oup.com` bloqueado); su ecuación sigue `TODO` |
| Fotheringham, Brunsdon & Charlton (2002), libro | Primaria | No accesible; Crossref no registra el libro (§16) | `TODO` en todo lo que se le atribuye |
| `GWmodel` 2.4-1 | Secundaria (implementación, GPL ≥ 2); **referencia cruzada decidida** | Ejecutado localmente (evaluación del backend y casos de §10) | Evidencia numérica de convenciones y referencia de tests. **No se copia ni se traduce código** |
| `spgwr` 0.6-37, `mgwrsar` 1.4.1 | Secundaria (implementaciones, GPL ≥ 2) | Resultados de la evaluación del backend (`gwr-backend.md` §4); `spgwr` también por el antecedente (§1.4) | Solo evidencia de convenciones; `spgwr` descartado; `mgwrsar` opción futura para MGWR |
| Documentación de `stats::optimize()` (R 4.3.3) | Documentación del software usado | Leída localmente | Algoritmo de Brent (sección golden + interpolación parabólica) y sus garantías |
| `dev/decisions/gwr-backend.md` y su prototipo desechable (no versionado) | Interna | Leídos | Requisitos R1–R12, números de referencia, tiempos |

Citas verificadas en Crossref (metadatos, **no contenido**), consultadas el
2026-11-04 en `api.crossref.org`:

| Referencia | DOI | Uso aquí |
|---|---|---|
| Brunsdon, C., Fotheringham, A. S., & Charlton, M. E. (1996). Geographically weighted regression: A method for exploring spatial nonstationarity. *Geographical Analysis*, 28(4), 281–298. | `10.1111/j.1538-4632.1996.tb00936.x` | Método base |
| Brunsdon, C., Fotheringham, S., & Charlton, M. (1998). Geographically weighted regression. *Journal of the Royal Statistical Society: Series D (The Statistician)*, 47(3), 431–443. | `10.1111/1467-9884.00145` | (nueva) a revisar para el estimador y kernels |
| Hurvich, C. M., Simonoff, J. S., & Tsai, C.-L. (1998). Smoothing parameter selection in nonparametric regression using an improved Akaike information criterion. *JRSS B*, 60(2), 271–293. | `10.1111/1467-9868.00125` | AICc |
| Gollini et al. (2015), *J. Stat. Softw.*, 63(17) (sin paginación en Crossref; número de artículo) | `10.18637/jss.v063.i17` | Kernels, AICc, colinealidad |
| Fotheringham, A. S., Yang, W., & Kang, W. (2017). Multiscale geographically weighted regression (MGWR). *Annals of the AAG*, 107(6), 1247–1265. | `10.1080/24694452.2017.1352480` | MGWR (diferido) |
| Páez, A., Farber, S., & Wheeler, D. (2011). A simulation-based study of geographically weighted regression as a method for investigating spatially varying relationships. *Environment and Planning A*, 43(12), 2992–3010. | `10.1068/a44111` | (nueva) riesgo de patrones espurios / n pequeño (citado por Gollini et al.) |
| Wheeler, D., & Tiefelsdorf, M. (2005). Multicollinearity and correlation among local regression coefficients in geographically weighted regression. *Journal of Geographical Systems*, 7(2), 161–187. | `10.1007/s10109-005-0155-6` | (nueva) colinealidad local |
| Belsley, D. A., Kuh, E., & Welsch, R. E. (1980). *Regression Diagnostics*. Wiley. ISBN 9780471058564 | `10.1002/0471725153` | (nueva) número de condición; umbral `TODO` |
| Bowman, A. W. (1984). An alternative method of cross-validation for the smoothing of density estimates. *Biometrika*, 71(2), 353–360. | `10.1093/biomet/71.2.353` | (nueva) citada por Gollini et al. para CV |
| Kiefer, J. (1953). Sequential minimax search for a maximum. *Proceedings of the AMS*, 4(3), 502–506. | `10.1090/S0002-9939-1953-0055639-3` | (nueva) búsqueda por sección áurea |
| Moran, P. A. P. (1950). Notes on continuous stochastic phenomena. *Biometrika*, 37(1–2), 17–23. | `10.1093/biomet/37.1-2.17` | (nueva) I de Moran (§7.3) |
| Roberts, D. R., Bahn, V., Ciuti, S., Boyce, M. S., Elith, J., Guillera-Arroita, G., Hauenstein, S., Lahoz-Monfort, J. J., Schröder, B., Thuiller, W., Warton, D. I., Wintle, B. A., Hartig, F., & Dormann, C. F. (2017). Cross-validation strategies for data with temporal, spatial, hierarchical, or phylogenetic structure. *Ecography*, 40(8), 913–929. | `10.1111/ecog.02881` | (nueva) CV por bloques (14 autores en Crossref) |
| Shepard, D. (1968). A two-dimensional interpolation function for irregularly-spaced data. *Proceedings of the 1968 23rd ACM National Conference*, 517–524. | `10.1145/800186.810616` | (nueva) IDW (C2) |
| Hengl, T., Heuvelink, G. B. M., & Rossiter, D. G. (2007). About regression-kriging: From equations to case studies. *Computers & Geosciences*, 33(10), 1301–1315. | `10.1016/j.cageo.2007.05.001` | (nueva) regresión-kriging/KED (C2 opcional) |
| Kalnay, E., et al. (1996). The NCEP/NCAR 40-year reanalysis project. *Bulletin of the AMS*, 77(3), 437–471. | `10.1175/1520-0477(1996)077<0437:TNYRP>2.0.CO;2` | (nueva) reanálisis (C2 opcional; antecedente §1.4) |
| Hersbach, H., et al. (2020). The ERA5 global reanalysis. *QJRMS*, 146(730), 1999–2049. | `10.1002/qj.3803` | (nueva) reanálisis (C2 opcional) |
| Kemp, M. U., van Loon, E. E., Shamoun-Baranes, J., & Bouten, W. (2012). RNCEP: global weather and climate data at your fingertips. *Methods in Ecology and Evolution*, 3(1), 65–70 (publicado en línea 2011-07-26). | `10.1111/j.2041-210X.2011.00138.x` | (nueva) paquete usado en el antecedente (§1.4) |

### 1.4 Antecedente del autor

El autor prototipó previamente una cadena MODIS/Landsat + METRIC + GWR con
`spgwr` (scripts propios, de solo lectura, no incluidos en el repositorio).
Se resumen como **evidencia de diseño**, sin adoptar ninguna elección en
silencio; cada punto se traslada a una opción o decisión abierta.

| Elección observada en el antecedente | Tratamiento en esta especificación |
|---|---|
| GWR con `spgwr`; bandwidth por `gwr.sel(method = "cv", RMSE = TRUE)`, seleccionando **a la vez** un bandwidth fijo y una proporción adaptativa, y pasando ambos a `gwr()`. Con `spgwr` 0.6-37, si `adapt` no es `NULL` el bandwidth fijo no interviene (comprobado: `gwr(bandwidth = b, adapt = q)` = `gwr(adapt = q)`) | Fijo **o** adaptativo, nunca ambos; la configuración efectiva se registra (§3.5, §7.1) |
| La función envolvente declaraba un argumento `gweight = gwr.tricube`, pero no lo pasaba a `gwr.sel()` ni a `gwr()`; el kernel efectivo fue el valor por defecto de `spgwr`, `gwr.Gauss` (formales de `spgwr` 0.6-37) | Kernel obligatorio y registrado; test de que el kernel pedido es el usado (§11). Tricúbico queda como candidato (§3.4) |
| Distancias de gran círculo (`longlat = TRUE`, km) | Opción documentada; por defecto distancia euclidiana en CRS proyectado (GW-09) |
| Modelos: `EA ~ EVI + ALT`; `TA ~ LST` (LST en °C); en otra versión `EA ~ EVI + e°(LST)`, `TA ~ LST + ALT`, `RS ~ HR + ALT` | Covariables por variable configurables (§2.3); **riesgo de circularidad** al usar LST (y, en menor grado, índices de vegetación) como covariable: §2.7 y GW-07 |
| eₐ calculada en la estación a partir de HR y T antes de interpolar | Coherente con `SCIENTIFIC_SPEC.md` §5 (regionalizar eₐ, no HR) |
| Estaciones del mismo día y **misma hora de reloj** que la pasada | La selección temporal la hace `forcing` (`target_time`, `weather-forcing.md` §5.5, WF-09) |
| Predicción en todas las celdas del ráster de covariables; opción de agregar las covariables por un factor (`fact = 3`), predecir y remuestrear la **predicción** a la resolución original | Antecedente del modo grueso de §6.2 (allí se interpolan **coeficientes**, no predicciones; ambas variantes se registran, GW-08) |
| Recortes posteriores: eₐ < 0,3 → 0,3; eₐ acotada a [0,25; 3,7] kPa; ET_inst < 0,1 → 0,1 | **No se adopta** (principio 6): valores conservados y marcados (`EF_GWR_PHYSICAL_RANGE`, §12) |
| Clúster `parallel::makeCluster(detectCores() − free)` | No apto para CRAN; paralelismo con `future`, plan elegido por el usuario, máximo 2 núcleos en checks (§6.5) |
| Función de atípicos por rango intercuartílico: fuera de [Q1 − 1,2·IQR, Q3 + 1,2·IQR] (`quantile(type = 8)`) → `NA`. Según indicación del autor se aplicó antes del ajuste; en los archivos leídos la función está definida, pero no se encontró su llamada | En EarthFlux, un atípico es un **flag de QC** de `forcing`, nunca un borrado; la exclusión de un ajuste es explícita y queda en la procedencia (§2.1). El factor 1,2 y el tipo de cuantil son elecciones del antecedente sin referencia: parámetros sin defecto (GW-17) |
| Estaciones con covariables `NA` eliminadas en silencio al extraer | Exclusión registrada por estación con motivo (§2.1, §7.1) |
| `library(RNCEP)` cargado en los ejemplos; según el autor, en algunas corridas el forzamiento provino del reanálisis NCEP (no se encontró la llamada en los archivos leídos) | Reanálisis como alternativa C2 **opcional**, entregada por el usuario como ráster; el paquete no descarga (§5.4) |

---

## 2. Contrato: entradas, salidas, configuración por variable

### 2.1 Entrada

Se implementa la tabla larga `ef_regionalization_input` de
`weather-forcing.md` §7.2 **sin cambios de campos**: `station_id`, `lon`,
`lat` (WGS84), `elevation` [m], `target_time` (`POSIXct` UTC),
`period_seconds`, `variable`, `value` (unidad del contrato), `qc_status`
(`ok`/`warning`/`excluded`), `reference`.

Reglas de este módulo:

1. **Unidad de ajuste.** Un ajuste = un par (`variable`, `target_time`).
   Para la opción C de la decisión 5.1 esto implica del orden de 100
   ajustes por fecha (`weather-forcing.md` §6); el diseño de §6.5 los trata
   como tareas independientes.
2. **Política de QC explícita.** `use_qc = c("ok", "warning")` (nombre
   provisional) indica qué estados entran al ajuste; `excluded` nunca entra.
   La política se registra en la procedencia. Sin valor implícito distinto
   del documentado.
3. **Exclusiones explícitas.** El usuario puede excluir estaciones con
   `exclude = <tabla station_id, motivo>`; también se excluyen, **con
   motivo registrado**, las estaciones con `value` o covariable `NA`, o
   fuera de la grilla de covariables. Nada se elimina en silencio (contraste
   con el antecedente, §1.4).
4. **Duplicados.** Más de una fila por (`station_id`, `variable`,
   `target_time`) → `earthflux_input_error` (no se promedia).
5. **Coordenadas.** `lon`/`lat` se proyectan al CRS de la grilla de trabajo
   (`terra::project()`); el CRS de distancias y el método de distancia se
   registran (§3.3, GW-09). Estaciones con coordenadas idénticas tras
   proyectar: permitidas solo si sus valores de covariables son
   distintos; en otro caso → error con clase (diseño local degenerado).

### 2.2 Covariables

- **En la grilla:** `SpatRaster` multicapa en la grilla de trabajo, una capa
  por covariable con nombre y unidad (atributo o tabla de metadatos):
  `elevation` [m], `distance_to_coast` [km], `slope`, `aspect` [rad],
  `lst` [K], `ndvi` [–] (lista de `weather-forcing.md` §7.2).
- **En las estaciones:** por defecto se **extraen** de los mismos rásteres
  (`terra::extract()`, celda que contiene la estación, sin interpolación),
  de modo que ajuste y predicción usen la misma fuente. Alternativa: tabla
  de covariables en estación entregada por el usuario (p. ej., elevación de
  metadatos). La fuente se registra (`covariate_source`). Decisión GW-10:
  para `elevation`, la elevación de metadatos (punto) y la del MDE (media
  de celda de ≈ 1 km) pueden diferir; ajustar con una y predecir con la otra
  introduce un error de escala. Recomendación provisional: usar el MDE en
  ambos y reportar `elevation_metadata − elevation_dem` por estación como
  diagnóstico (flag con umbral `TODO`).
- **Covariable categórica:** no se admite en la primera versión
  (`earthflux_input_error`).

### 2.3 Configuración por variable

Objeto de configuración (`ef_gwr_config()` o lista validada, nombre a
decidir en GW-23) con una entrada por variable. Valores **propuestos**, no
decididos; ninguna covariable entra por defecto sin aparecer en la
configuración registrada:

| Variable (`variable`) | Unidad | Covariables candidatas (SPEC §5) | Transformación | Dominio físico de la predicción (flag si se viola) | Consumidor |
|---|---|---|---|---|---|
| `air_temperature` | °C | `elevation`, `distance_to_coast`; `lst` solo con opción explícita (§2.7) | Ninguna | > −273,15 °C (imposible); plausibilidad `TODO` | RL↓ (RC-12 opción a); ETr (opción C); ρ_air si se usa Ta (`sensible-heat.md` §8.4) |
| `vapour_pressure` | kPa | `elevation`, `distance_to_coast` (antecedente: índice de vegetación, §2.7) | Ninguna por defecto; log como opción (GW-12) | > 0; y eₐ ≤ e°(Ta) por píxel cuando ambas superficies existen (control en `api`, `weather-forcing.md` §6) | ETr (opción C); ε_a si se usa eₐ (RC-13) |
| `wind_speed_2m` | m s⁻¹ | `elevation` (SPEC §5: "con cautela") | Ninguna por defecto; raíz o log como opción (GW-12) | ≥ 0 | ETr (opción C). La u de altura de mezcla es escalar de estación por defecto (`sensible-heat.md` §6, SH-05/SH-07) |
| `clearness` (Rs/Rso) | – | `elevation`; nubosidad satelital `TODO` | Ninguna | ≥ 0 (imposible si < 0); > 1 plausible solo con un margen `TODO` | Rs = (Rs/Rso)·Rso del píxel (opción C; RC-10) |
| `solar_radiation` | W m⁻² | `elevation` | Ninguna | ≥ 0 | Alternativa a `clearness` |
| `etr_inst` | mm h⁻¹ | según decisión 5.1 opción A | Ninguna | > 0 requerido por `evapotranspiration.md` §1.3 | Ancla fría (`anchor-pixels.md` §2.4) |
| `etr_24` | mm d⁻¹ | ídem | Ninguna | ≥ 0 requerido por `evapotranspiration.md` §1.3 | ETa = ETrF·ETr24 |

Reglas de transformación (GW-12): solo `identity` en la primera versión.
Si se adopta `log` u otra, la retrotransformación de una predicción de la
media en escala transformada no es la media en la escala original (sesgo
de retrotransformación); su corrección requiere referencia `TODO`. Toda
transformación se registra y genera `EF_GWR_TRANSFORMED`.

Valores fuera del dominio físico **se conservan** y se marcan
(`EF_GWR_PHYSICAL_RANGE`), igual que `EF_ET_NEGATIVE`; los consumidores
deciden (p. ej., `evapotranspiration.md` exige ETr_inst > 0 y fallará o
marcará según su propia especificación).

### 2.4 Salida

Clase propuesta `earthflux_surface` (común a C1, C2 y C3; §5.1), una por
variable, con los elementos de `weather-forcing.md` §7.2:

| Elemento | Tipo / unidad | Contenido |
|---|---|---|
| `surface` | `SpatRaster`, una capa por `target_time`, en la unidad de entrada | Nombre de capa: `<variable>_<YYYYmmddTHHMMSSZ>` |
| `uncertainty` | `NULL` en la primera versión | La varianza de predicción de GWR no está verificada (GW-19). El contrato lo permite ("u omitida") |
| `flags` | `SpatRaster` entero, una capa por `target_time`, **codificado por bits** (enmienda A1) + tabla `flag_bits` (`bit`, `code`, `severity`, `description`) | §12 |
| `diagnostics` | lista con un objeto por ajuste: `earthflux_gwr` (C3), `earthflux_ols` / `earthflux_idw` / `earthflux_station_forcing` (C1/C2) | §7 |
| `provenance` | lista | `method` (texto exacto: `"station"`, `"global_ols"`, `"idw"`, `"gwr"`, …), parámetros completos (kernel, tipo y valor de bandwidth, convención de k, criterio, límites y rejilla de búsqueda, vecinos mínimos, covariables y su fuente, transformación, modo de predicción y tamaño de bloque, política de QC), estaciones usadas y excluidas con motivo, `target_time`, CRS y método de distancia, versiones de EarthFlux, R y `terra`, semilla (`NULL` si no hubo azar) |
| `station_table` | `data.frame` | Por ajuste y estación: observado, ajustado, residuo, residuo LOO, s_ii, R² local, covariables usadas, estado (usada/excluida, motivo) |

### 2.5 Enmiendas propuestas a `weather-forcing.md` §7.2 (no editado aquí)

| Id | Enmienda | Motivo |
|---|---|---|
| A1 | "Flags por píxel: `SpatRaster` de códigos" → entero **codificado por bits**, con tabla bit ↔ código en `flags`/`diagnostics` | Un píxel puede tener varios flags simultáneos (p. ej., fuera de la envolvente y fuera del rango de covariables); una capa de "un código" pierde información. `terra` maneja enteros por bloques sin costo adicional |
| A2 | Añadir `covariate_source` (extraída del ráster / entregada en estación) y permitir una tabla de covariables en estación | GW-10 (elevación de metadatos vs MDE) |
| A3 | Añadir a la procedencia `distance_method` y `distance_crs` | GW-09; el antecedente usó gran círculo |
| A4 | `method` por **variable** (no solo por corrida) | Permite el diseño factorial de H1 (`weather-forcing.md` §6 punto 3; `anchor-pixels.md` §2.4): p. ej., GWR para Ta y estación única para u |
| A5 | Añadir `station_table` a la salida | Residuos y LOO por estación son requisito de validación (R7, `gwr-backend.md` §1) |

### 2.6 Dónde entran las superficies en METRIC (referencia cruzada)

`spatial` no conoce estos usos; se listan para dimensionar el efecto de las
decisiones de este documento sobre H1 (`SCIENTIFIC_SPEC.md` §1.2):

| Punto de entrada | Superficie | Especificación consumidora | Requisito que impone a `spatial` |
|---|---|---|---|
| RL↓ | `air_temperature` (si RC-12 = opción a) | `radiation-components.md` §6.5.B | Ta en K en la frontera (conversión explícita, WF-02); flag de extrapolación por píxel |
| Rs↓ | `clearness` o `solar_radiation` (RC-10) | `radiation-components.md` §6.4 | Coherencia con la Rs usada en ETr |
| Viento a altura de mezcla | `wind_speed_2m` (si se regionaliza) | `sensible-heat.md` §6.1 (SH-05, SH-07) | Entrega u₂; la conversión a u_b es de `metric` |
| Ancla fría | `etr_inst` (opción A) o insumos (opción C) evaluados en la celda del ancla | `anchor-pixels.md` §2.4 | Definición **inequívoca** de extrapolación para `EF_ANCHOR_FORCING_EXTRAPOLATED` (§6.3) |
| Extrapolación diaria | `etr_24` o insumos | `evapotranspiration.md` §1.3, §6.3 | ETr24 ≥ 0, misma referencia (`alfalfa`) que `etr_inst` |

### 2.7 Covariables derivadas del estado de superficie: riesgo de circularidad (GW-07)

El antecedente (§1.4) modeló `TA ~ LST` y `EA ~ EVI + …`. El mismo
LST/Ts del píxel es la variable que en METRIC fija dT = a + b·Ts_datum
(`sensible-heat.md` §9), que entra en RL↑ y en la selección de anclas
(`anchor-pixels.md` §3). Si Ta se predice a partir de LST y luego entra en
RL↓ (RC-12 opción a), en ETr (opción C) o en ρ_air:

1. **Acoplamiento RL↓–RL↑:** Ta(LST) hereda la estructura espacial de Ts;
   el efecto es cualitativamente similar al de la opción (c) de RC-12 (Ts
   por píxel en RL↓), que reduce artificialmente el contraste de Rn entre
   píxeles fríos y calientes.
2. **Referencia contaminada por el estado real:** ETr es una magnitud de
   **referencia**; con Ta(LST), un píxel seco y caliente recibe una ETr más
   alta, y ETrF = ET_inst/ETr_inst incorpora Ts en numerador y denominador
   (`weather-forcing.md` §6, fila "Condición de referencia").
3. **Endogeneidad en la validación:** la CV de Ta en estaciones puede
   mejorar con LST (LST explica Ta), mientras los errores de LST (nubes
   residuales, ángulo de visión, desfase horario LST–estación) se propagan
   **a la vez** a Ta y a dT, de forma correlacionada. Una mejor CV del
   forzamiento no implica entonces una mejor ETa.
4. Índices de vegetación (NDVI/EVI) como covariables de eₐ entran también
   en z_om, G y ε₀: acoplamiento más indirecto, pero del mismo tipo.

Detección (obligatoria cuando una covariable proviene de `surface`):

- flag `EF_GWR_SURFACE_COVARIATE` (lista de covariables) en el ajuste y en
  la procedencia;
- análisis de sensibilidad diseñado: misma corrida con y sin la covariable
  de superficie (solo `elevation`, `distance_to_coast`), comparando (i) CV
  del forzamiento, (ii) ETr_inst en las anclas y (iii) ETa
  (`VALIDATION_PLAN.md` §2.1, evaluación diferenciada);
- diagnóstico: correlación espacial (sobre la grilla) entre la diferencia
  de superficies Ta(con LST) − Ta(sin LST) y LST, y entre la diferencia de
  ETrF de ambas corridas y LST.

**Evidencia previa del autor (2026-11-04; nivel: resumen, texto completo
pendiente de acceso).**

- Galdón-Ruíz et al. (2023, *Revista de Teledetección* 61:59–71,
  doi:10.4995/raet.2023.18909): en Murcia (47 estaciones), regresiones
  geográficamente ponderadas entre temperatura del aire y LST MODIS dan
  R² = 0,69–0,82 (Tmin vs. LST nocturna) y 0,70–0,87 (Tmax vs. LST diurna),
  con RMSE de 1,0 °C y 0,8 °C; los coeficientes locales se interpolan luego
  con altitud y NDVI para obtener mapas de **medias mensuales**.
- Montaner-Fernández et al. (2020, *Remote Sensing* 12:3345,
  doi:10.3390/rs12203345): isla de calor de Santiago con MODIS, nueve
  estaciones, regresiones simples, GWR y geoestadística.

Lectura para EarthFlux: la evidencia respalda que **LST es un predictor
fuerte de la temperatura del aire**, incluso en Chile, lo que justifica
mantener LST como opción y no excluirla de forma rígida. No resuelve, sin
embargo, el problema de esta sección, que no es de capacidad predictiva sino
de **acoplamiento** dentro de METRIC (puntos 1–3). Además, la evidencia es
para **medias mensuales** de Tmin/Tmax, mientras METRIC necesita Ta
**instantánea** en la hora de paso; la transferencia de escala temporal
debe evaluarse.

Opciones (decisión GW-07, del autor): (a) solo covariables independientes
de la superficie (`elevation`, `distance_to_coast`, `slope`/`aspect`) —
recomendación provisional por defecto hasta contar con el experimento;
(b) LST permitida como opción explícita, respaldada por la evidencia previa
del autor, con flag y con la sensibilidad anterior como requisito de
reporte; (c) LST de otro instante (p. ej., nocturna o compuesto) para
reducir el acoplamiento — sin evidencia de que lo elimine (a evaluar).

---

## 3. Modelo: GWR como mínimos cuadrados ponderados locales

### 3.1 Notación

n estaciones del ajuste; p columnas del diseño (intercepto + covariables);
**X** (n × p), **y** (n); coordenadas proyectadas (uⱼ, vⱼ) en m; d_ij
distancia [m] entre el punto de regresión i (estación o celda) y la estación
j; Wᵢ = diag(w_i1, …, w_in); N celdas de la grilla.

### 3.2 Estimador local

Para cada punto de regresión i:

```text
β̂ᵢ = (Xᵀ Wᵢ X)⁻¹ Xᵀ Wᵢ y                     [unidades de β̂ᵢ: las de y / las de cada covariable]
ŷᵢ = xᵢᵀ β̂ᵢ                                   (punto de regresión = estación i)
ŷ_g = x_gᵀ β̂_g                                (celda g con covariables x_g; pesos respecto de las estaciones)
```

Estado: `VERIFICADA` como contenido de Gollini et al. (preprint
arXiv:1306.0413v2, §6.1, p. 19). Atribución original a Brunsdon et al.
(1996) y Fotheringham et al. (2002): `TODO` (no leídos). Como definición de
EarthFlux: `CANDIDATA (corroborada)` por la coincidencia ≤ 3 × 10⁻¹² de
cuatro implementaciones (`gwr-backend.md` §4.3) y por el caso G2 (§10).

### 3.3 Distancias y CRS (GW-09)

- Por defecto: distancia euclidiana en el CRS **proyectado** de la grilla de
  trabajo (unidades lineales en m). Grilla en coordenadas geográficas sin
  `distance_crs` explícito → `earthflux_input_error` (no se calcula
  distancia euclidiana en grados).
- Opción: distancia de gran círculo sobre lon/lat (como el antecedente);
  fórmula y radio terrestre a especificar con referencia (`TODO`) antes de
  habilitarla.
- El bandwidth fijo se expresa en m; el adaptativo, en número entero de
  estaciones (§3.5).

### 3.4 Kernels (`CANDIDATA (corroborada)`)

Con r = d_ij / b_i:

| Kernel | w(r) | Soporte | Estado |
|---|---|---|---|
| `gaussian` | exp(−½ r²) | Todo r | `VERIFICADA` como contenido de Gollini et al. (Tabla 1, p. 5) |
| `exponential` | exp(−r) | Todo r | Ídem |
| `bisquare` | (1 − r²)² si r < 1; 0 si no | Compacto | Ídem |
| `tricube` | (1 − r³)³ si r < 1; 0 si no | Compacto | Ídem (declarado en el antecedente, §1.4) |
| `boxcar` | 1 dentro del soporte; 0 fuera | Compacto | Ídem para la forma; **borde: ver abajo** |

- Requisito mínimo (R4): gaussiano y bicuadrado. Exponencial, tricúbico y
  boxcar: candidatos (boxcar imprescindible para el caso límite OLS y el
  caso G1a).
- **Borde del boxcar (decisión GW-03).** La Tabla 1 de Gollini et al. usa
  `|d| < b`, pero `GWmodel` 2.4-1 asigna peso 1 en d = b (observado:
  `gw.weight(c(0, 10000, 10001), bw = 10000, kernel = "boxcar")` →
  1, 1, 0). Para bicuadrado y tricúbico el borde es indiferente (w = 0 en
  r = 1). Propuesta: boxcar con soporte **d ≤ b**, para que el boxcar
  adaptativo con k incluya exactamente los k puntos más cercanos (más los
  empates); se documenta la diferencia con la tabla publicada.
- Escala del gaussiano: la forma exp(−½ r²) (b = desviación típica) coincide
  con `GWmodel` y con los demás paquetes de la evaluación del backend
  (`gwr-backend.md` §4.3). En esa evaluación se observó también una forma
  gaussiana histórica con otra escala en un paquete descartado; **no** se
  adopta: un bandwidth gaussiano no es comparable entre convenciones
  distintas.

### 3.5 Bandwidth fijo y adaptativo; convención de k (GW-03)

- **Fijo:** b_i = b [m] para todo i.
- **Adaptativo:** b_i = d_i,(k), la k-ésima distancia más pequeña desde el
  punto de regresión i a las estaciones del ajuste, **contando la del propio
  punto (d = 0) cuando i es una estación**. k entero, 1 ≤ k ≤ n. En las
  celdas de la grilla (sin estación propia) se usa la k-ésima distancia a
  las estaciones, de modo que en una celda que coincide con una estación el
  bandwidth es el mismo que en la estación. Los empates no cambian b_i (es
  un estadístico de orden, único como valor).
- Consecuencias que deben documentarse al usuario:
  - con bicuadrado o tricúbico, la estación a distancia exactamente b_i
    recibe peso 0: el número de pesos **no nulos** es (número de estaciones
    con d < b_i), que sin empates es k − 1 (incluido el propio punto) y con
    empates puede ser menor (caso G3: con k = 3 en S1 solo el propio punto
    tiene peso no nulo);
  - con boxcar (d ≤ b): exactamente k más los empates;
  - con gaussiano/exponencial todos los pesos son no nulos: k fija la escala,
    no el número de estaciones.
- Comparación de convenciones (evidencia): `GWmodel` coincide con esta
  convención (coeficientes a 3,6 × 10⁻¹⁴ con k = 5 bicuadrado, caso G3;
  7 × 10⁻¹¹ con k = 30 en el sintético, `gwr-backend.md` §4.3). En la
  evaluación del backend, `spgwr` (descartado) expresaba k como proporción
  q ∈ (0, 1], no convertible de forma directa a esta convención. `mgwrsar`
  (opción futura para MGWR) produce coeficientes distintos con k = 30
  (máx. |Δβ| = 0,86); su NEWS menciona el "(H + 2)-th neighbour"
  (`gwr-backend.md` §4.2, nota 2; `TODO`).
- Fijo **o** adaptativo por ajuste (nunca ambos; contraste con §1.4).

### 3.6 Matriz hat, tr(S) y número efectivo de parámetros

Fila i de la matriz hat S (n × n) en las estaciones:

```text
sᵢ = xᵢᵀ (Xᵀ Wᵢ X)⁻¹ Xᵀ Wᵢ          ŷ = S y          e = y − ŷ          RSS = eᵀe
s_ii = w_ii · xᵢᵀ (Xᵀ Wᵢ X)⁻¹ xᵢ
```

Magnitudes reportadas (todas en el objeto, §7.1):

| Nombre en EarthFlux | Definición | Uso | Estado |
|---|---|---|---|
| `enp` | tr(S) = Σ s_ii | **Único** número efectivo de parámetros usado en AICc | `VERIFICADA` como contenido de Gollini et al. (§6.1: "tr(S) denotes the trace of the hat matrix S") |
| `tr_sts` | tr(SᵀS) = Σᵢⱼ s_ij² | Diagnóstico | `CANDIDATA` |
| `enp_alt` | 2tr(S) − tr(SᵀS) | Solo reporte (lo que `GWmodel` llama `enp`) | `CANDIDATA`; definición original `TODO` (Fotheringham et al., 2002) |
| `edf` | n − 2tr(S) + tr(SᵀS) | Grados de libertad residuales para σ̂ "insesgado" de reporte | `CANDIDATA` (coincide con `edf` de `GWmodel`, caso G2) |

Por qué tr(S) en AICc: (i) es la magnitud que aparece en la expresión leída
(Gollini et al., §6.1); (ii) con ella el AICc de EarthFlux reproduce
**exactamente** el AICc de `GWmodel` en el sintético de 150 estaciones
(171,521589) y en el caso G2 (24,412005), y la forma `AICb` de `spgwr` en
la evaluación del backend; (iii) en el límite global
tr(S) = p (caso G4), de modo que el AICc de GWR converge al de la regresión
global con el mismo n (§5.2). Advertencia de nomenclatura: `GWmodel`
reporta `enp` = 2tr(S) − tr(SᵀS) aunque usa tr(S) en su AICc (por eso
EarthFlux llama `enp_alt` a esa cantidad).

### 3.7 Solución numérica y escalado interno

- La implementación puede resolver cada WLS local por QR de W^{1/2}X
  (referencia) o por momentos/Cholesky de XᵀWX (más rápido en predicción,
  `gwr-backend.md` §5.2); cualquier variante debe coincidir con la
  referencia QR con tolerancia relativa 1 × 10⁻¹⁰ en los tests (§11).
- **Escalado interno de covariables** (centrar y dividir por la desviación
  típica global de cada columna no constante) para el condicionamiento: en
  el caso G1b, cond₂(XᵀWX) = 3,7 × 10⁵ con elevación en m, frente a 3,24
  para W^{1/2}X con columnas equilibradas. Los coeficientes se reportan en
  unidades originales (retrotransformación exacta en un modelo lineal); la
  predicción no cambia (test con tolerancia 1 × 10⁻¹⁰).
- **Rango y condición** en cada punto de regresión: rango numérico de
  W^{1/2}X (QR con pivoteo) y número de condición κ de W^{1/2}X con columnas
  equilibradas (forma tipo Belsley; Belsley et al., 1980, no leído:
  `CANDIDATA`). Gollini et al. (§7.1, p. 25) mencionan una regla práctica
  "condition numbers greater than 30" tomada de la regresión global, y en
  §7.3 definen κ como cociente de autovalores de XᵀX: las dos definiciones
  difieren (κ de XᵀX = κ(X)²), por lo que **no** se adopta el 30. Umbral
  de flag sin defecto (`kappa_max = NULL`, GW-06).

### 3.8 R² local (GW-13)

Definición adoptada (propuesta): R² del ajuste WLS local en i,

```text
R²ᵢ = 1 − Σⱼ w_ij (yⱼ − xⱼᵀβ̂ᵢ)² / Σⱼ w_ij (yⱼ − ȳ_w,i)²,      ȳ_w,i = Σⱼ w_ij yⱼ / Σⱼ w_ij
```

Es idéntica al `r.squared` de `summary(lm(y ~ x, weights = wᵢ))` de base R
(comprobado en el caso G2), lo que da un ancla verificable sin paquetes
externos. Estado: `CANDIDATA` (la definición de Fotheringham et al., 2002
no fue leída). Evidencia de que **no hay convención única** (caso G2,
gaussiano b = 20 km):

| Estación | EarthFlux (ajuste local, media ponderada) | Variante "ŷ global, media ponderada" | `GWmodel` (`Local_R2`) = variante "ŷ global, media no ponderada" |
|---|---|---|---|
| S1 | 0,99615697 | 0,99667790 | 0,99741850 |
| S6 | 0,99854899 | 0,99914970 | 0,99936410 |

`GWmodel` coincide (a 10⁻⁷ en el caso G2) con la variante que usa los
valores ajustados **globales** ŷⱼ = (Sy)ⱼ en lugar de xⱼᵀβ̂ᵢ y la media no
ponderada; la variante con media ponderada es la que reportaba un paquete
descartado en la evaluación. La convención se registra en el objeto
(`local_r2_convention`), y el test de referencia cruzada compara con la
variante equivalente de `GWmodel` (calculable con el núcleo interno).

---

## 4. Selección de bandwidth

### 4.1 AICc adoptado (GW-02)

```text
AICc(b) = 2n ln σ̂ + n ln(2π) + n · (n + tr S) / (n − 2 − tr S),      σ̂ = √(RSS/n)
```

- n: número de estaciones **del ajuste** (no un tamaño "local"). Gollini
  et al. escriben "n is the (local) sample size (according to b)", frase
  ambigua; con el n global se reproduce el AICc de `GWmodel` (171,521589
  con n = 150), por lo que esa es la convención implementada por ese
  paquete.
- σ̂: estimador de máxima verosimilitud √(RSS/n). Gollini et al. dicen
  solo "the estimated standard deviation of the error term"; con √(RSS/n)
  se reproduce `GWmodel` (y la forma `AICb` de `spgwr` en la evaluación
  del backend); con σ̂ = √(RSS/edf) el valor
  sería 190,698 en el sintético (no coincide con ninguno).
- **Dominio:** definido solo si n − 2 − tr(S) > 0. Si n − 2 − tr(S) ≤ 0 el
  término de penalización cambia de signo y produce valores espurios muy
  bajos (caso G6: b = 8 km da AICc = −120,9 con n − 2 − tr S = −0,68), que
  una minimización ingenua elegiría. Esos bandwidths son **no factibles**:
  AICc = `NA` en el perfil, excluidos de la búsqueda, y se marca
  `EF_GWR_AICC_UNDEFINED` (§12).
- Estado: forma `VERIFICADA` como contenido de Gollini et al. (preprint,
  §6.1, p. 20), que la atribuyen a "Hurvich and Simonoff 1998" (la cita
  verificada en Crossref es Hurvich, Simonoff & Tsai, 1998). Como
  definición de EarthFlux: `CANDIDATA (corroborada)` hasta leer Hurvich et
  al. (1998) y Fotheringham et al. (2002) (§14). Evidencia corroborante:
  coincidencia exacta con el AICc de `GWmodel` en dos casos independientes
  (G2 y sintético) y con `AICb` de `spgwr` en la evaluación del backend.
- Identidad algebraica (derivación propia, comprobada numéricamente a
  precisión de máquina): con K = tr(S) + 1,

  ```text
  n · (n + tr S)/(n − 2 − tr S) = n + 2K + 2K(K + 1)/(n − K − 1)
  ```

  es decir, la expresión adoptada es un AIC gaussiano con K "parámetros"
  (tr S coeficientes efectivos + σ²) más una corrección de muestra pequeña
  2K(K + 1)/(n − K − 1). Además, si la forma de Hurvich et al. (1998) es,
  como suele atribuirse, ln σ̂² + 1 + 2(tr S + 1)/(n − tr S − 2) (`TODO`:
  verificar en la fuente; **no** se afirma aquí), entonces la expresión
  adoptada es n veces esa forma más la constante n ln 2π (comprobado
  numéricamente: diferencia = n ln 2π = 275,6816 con n = 150): mismo
  minimizador en b.

### 4.2 Las tres "AICc" para el mismo ajuste (reconciliación)

Evidencia de la evaluación del backend (`gwr-backend.md` §4.3, §5.1) y,
para `GWmodel`, del caso G2:

| Implementación | Valor (sintético, bisquare fijo 40 km; RSS = 21,988635; tr S = 14,110126) | Valor (caso G2) | Relación con la forma adoptada |
|---|---|---|---|
| EarthFlux (adoptada), `GWmodel` `AICc` | 171,521589 | 24,412005 | Idéntica |
| `spgwr` `AICb` (evaluación; paquete descartado) | 171,521589 | – | Idéntica |
| `spgwr` `AICc` (evaluación; paquete descartado) | 172,449494 | – | Otra expresión basada en trazas δ₁, δ₂ de matrices derivadas de S; origen bibliográfico `TODO` |
| `mgwrsar` `AICc` | 170,1586 | no calculado | No reproducida con ninguna de las variantes probadas (σ̂ ML o insesgado; tr S o 2tr S − tr SᵀS; AIC sin corrección); `TODO` (relevante solo si se evalúa `mgwrsar` para MGWR) |
| `GWmodel` `AIC` (sin corrección) | – | −8,400076 | 2n ln σ̂ + n ln 2π + n + tr S (comprobado) |

Regla: la procedencia registra `criterion = "AICc"` **y**
`aicc_definition = "gollini2015_tr_S_sigma_ml"` (nombre a fijar); los tests
de referencia cruzada comparan con `GWmodel$GW.diagnostic$AICc`.

### 4.3 Validación cruzada (LOOCV)

```text
ŷ≠ᵢ(b) = xᵢᵀ β̂ᵢ⁽⁻ⁱ⁾,  con β̂ᵢ⁽⁻ⁱ⁾ = (Xᵀ Wᵢ⁽⁻ⁱ⁾ X)⁻¹ Xᵀ Wᵢ⁽⁻ⁱ⁾ y,  Wᵢ⁽⁻ⁱ⁾ = Wᵢ con w_ii = 0
e₋ᵢ = yᵢ − ŷ≠ᵢ          CV(b) = Σᵢ e₋ᵢ²   [unidad de y al cuadrado]          RMSE_LOO = √(CV/n)
```

- El bandwidth b_i (adaptativo) se calcula con la estación i incluida y
  luego se anula w_ii (convención de "anular el propio peso"); es la que
  reproduce `GWmodel` (CV = 27,491712 en el sintético; `CV_Score` por
  estación = e₋ᵢ en el caso G2). Alternativa no adoptada: recalcular el
  k-ésimo vecino sin la estación i (registrar si se ofrece).
- Atajo exacto (derivación propia por actualización de rango uno del WLS
  local en i; comprobado en el caso G2 a 10⁻⁸ y en G1a):
  e₋ᵢ = eᵢ / (1 − s_ii), con eᵢ = yᵢ − ŷᵢ del ajuste completo. Válido
  porque Wᵢ⁽⁻ⁱ⁾ solo difiere de Wᵢ en w_ii y el bandwidth no se recalcula.
  Si s_ii = 1 (p. ej., solo la propia estación tiene peso no nulo) el
  atajo no está definido y el ajuste LOO es singular → `NA` + flag. La
  implementación puede usar el atajo; los tests comparan con el cálculo
  por definición.
- Minimizar CV o RMSE_LOO da el mismo b (el antecedente del autor
  minimizaba RMSE, §1.4).
- Estado: `CANDIDATA (corroborada)` (Gollini et al. citan Bowman, 1984, para
  CV; definición exacta en GWR `TODO` en Fotheringham et al., 2002).
- Limitación: LOOCV puede ser optimista con autocorrelación espacial
  (`VALIDATION_PLAN.md` §2.3); la CV por bloques de §8.2 usa el mismo
  núcleo con particiones arbitrarias.

### 4.4 Algoritmo de búsqueda

Toda la búsqueda es determinista y queda registrada como **perfil**
(`bandwidth`, `criterion`, `feasible`, `enp`, `min_nonzero`, `kappa_max`)
en el objeto.

**Bandwidth fijo (m):**

1. Límites. `lower` y `upper` explícitos o calculados así (convenciones de
   búsqueda, no constantes científicas; se registran):
   - `lower_auto` = maxᵢ d_i,(m_min) (la m_min-ésima distancia más pequeña
     desde cada estación, contando la propia, máxima sobre las estaciones),
     con m_min = `min_neighbours` (§4.5). Para kernels compactos, la
     factibilidad exige b estrictamente mayor que ese valor (pesos no
     nulos solo con d < b): la rejilla empieza en `lower_auto · (1 + δ)`,
     con δ = `lower_offset` (parámetro numérico registrado).
   - `upper_auto` = `upper_factor` × D_max, con D_max la mayor distancia
     entre estaciones del ajuste y `upper_factor` un parámetro registrado
     (valor por defecto a decidir, GW-05). Además del perfil finito, se
     evalúa siempre el **límite global** (b = ∞, OLS, §5.2) como referencia.
2. Rejilla de `n_grid` valores equiespaciados en log(b) entre los límites
   (valor por defecto a decidir, GW-05); se evalúa el criterio y se marcan
   los no factibles (rango deficiente en algún punto de regresión de las
   estaciones, n − 2 − tr S ≤ 0 para AICc, s_ii = 1 para CV, o menos de
   `min_neighbours` pesos no nulos).
3. Refinamiento: `stats::optimize()` (Brent: sección áurea + interpolación
   parabólica; documentación de R) restringido al intervalo entre los
   vecinos de rejilla del mínimo factible, con tolerancia `tol` registrada.
   Si el mínimo de la rejilla está en un extremo, no se extrapola: se
   devuelve el extremo y se marca `EF_GWR_BW_AT_BOUND`.
4. Si la rejilla muestra más de un mínimo local factible →
   `EF_GWR_BW_MULTIMODAL` (info) y el perfil completo queda en el objeto.
5. Si el criterio en b = ∞ (OLS) es menor o igual que el mínimo del perfil
   → `EF_GWR_GLOBAL_PREFERRED` (info); se devuelve igualmente el mínimo
   finito (la elección de usar el modelo global es del usuario o de `api`).

Justificación de rejilla + refinamiento frente a Brent solo: Brent puede
converger a un mínimo local si el criterio no es unimodal (lo advierte la
propia documentación de `optimize()`), y con pocas estaciones el perfil
no es unimodal (§4.6, n = 15: dos mínimos locales en una rejilla de 40
valores). La rejilla también deja el perfil auditable (requisito de
`R/gwr-bandwidth.R`). Costo: (n_grid + ≈ 15–25) evaluaciones de O(n²p +
np³); con n = 150 la selección completa tomó ≈ 0,1–0,2 s en el prototipo.
Referencia de la sección áurea: Kiefer (1953) (metadatos verificados;
contenido no leído).

**Bandwidth adaptativo (k entero):** búsqueda **exhaustiva** en
k ∈ [`k_min`, `k_max`], con `k_min` derivado de `min_neighbours` y del
kernel (para bicuadrado/tricúbico los pesos no nulos son a lo sumo k − 1,
§3.5, luego k_min ≥ min_neighbours + 1) y `k_max` = n por defecto. Costo
≈ n evaluaciones (≈ 0,9 s con n = 150 en el prototipo). Opción para n
grande: sección áurea sobre enteros, registrada. Mismas reglas de
factibilidad, extremo y multimodalidad.

**Empates en el criterio:** se elige el menor bandwidth (fijo) o el menor k
(adaptativo) entre valores exactamente iguales; regla registrada (determinismo).

### 4.5 Regla de vecinos mínimos y estaciones mínimas (GW-06)

- `min_neighbours` (entero): mínimo de estaciones con **peso no nulo**
  (incluida la propia) en cada punto de regresión de las estaciones para
  que un bandwidth sea factible, y en cada celda para que la predicción no
  se marque (`EF_GWR_FEW_NEIGHBOURS`). Mínimo matemático: p + 1 (p para la
  identificabilidad del WLS local; +1 para que el ajuste LOO en la estación
  siga identificable). EarthFlux usa ese mínimo matemático como valor por
  defecto y exige justificación (referencia) para cualquier valor mayor.
  Contraste: `GWmodel::bw.gwr()` fija en 20 el límite inferior adaptativo
  sin argumento para cambiarlo (`gwr-backend.md` §4.2), lo que con redes
  poco densas excluye bandwidths con AICc menor (gaussiano adaptativo: k = 8
  con AICc 173,35 frente a 194,49 en k = 20).
- Para kernels continuos todos los pesos son no nulos; `min_neighbours`
  se aplica entonces al número de estaciones con d ≤ b_i (estaciones
  "dentro de un bandwidth"), convención registrada.
- `n_min` (entero, sin defecto científico): número mínimo de estaciones
  para ajustar GWR. Regla matemática dura: n ≥ p + 3 (para que exista algún
  b con n − 2 − tr S > 0, ya que tr S → p en el límite global); por debajo
  → `earthflux_gwr_insufficient_stations`. Entre p + 3 y `n_min` (si el
  usuario lo fija) → ajuste con flag `EF_GWR_FEW_STATIONS` (no registrado:
  umbral `TODO`, pregunta 4 de `gwr-backend.md` §8).

### 4.6 Comportamiento con pocas estaciones (10–30) y modos de fallo

Evidencia (subconjuntos del sintético de `gwr-backend.md` §2, p = 3, código
propio):

| n | Bisquare fijo, AICc | Gaussiano adaptativo, AICc |
|---|---|---|
| 15 | Factible solo desde b ≈ 62 km (por debajo, rango deficiente o n − 2 − tr S ≤ 0); **dos mínimos locales** en la rejilla; mínimo ≈ 105–107 km con tr S ≈ 3,8 (cercano al global, p = 3) | Mínimo en k = 8 |
| 30 | Factible desde b ≈ 27 km; un mínimo local; Brent refina a 52 379 m (AICc 57,087) frente a 55 927 m en la rejilla | Mínimo en k = 5 (cerca del límite inferior) |

Paquetes con n = 15 (`gwr-backend.md` §4.2): `GWmodel` adaptativo AICc
devuelve k = 16 > n; `spgwr::gwr.sel(method = "aic")` falla con
*"non-conformable arguments"*.

Modos de fallo (nunca silenciosos):

| Situación | Respuesta |
|---|---|
| n < p + 3 | Error `earthflux_gwr_insufficient_stations` |
| Ningún bandwidth factible en el intervalo | Error `earthflux_gwr_no_feasible_bandwidth` con el perfil adjunto |
| Bandwidth elegido en el límite de búsqueda | Ajuste + `EF_GWR_BW_AT_BOUND` |
| Perfil multimodal | Ajuste + `EF_GWR_BW_MULTIMODAL` |
| AICc no definido para parte del intervalo | Ajuste + `EF_GWR_AICC_UNDEFINED` (info) |
| Diseño local de rango deficiente en una **estación** con el bandwidth final (entregado por el usuario) | Error `earthflux_gwr_singular_error` (S no está definida) |
| Diseño local de rango deficiente en una **celda** | `NA` en la celda + `EF_GWR_LOCAL_SINGULAR` |
| κ local sobre `kappa_max` (si se fija) | Valor conservado + `EF_GWR_ILL_CONDITIONED` |
| Covariable constante entre todas las estaciones del ajuste | Error `earthflux_input_error` (el diseño global ya es singular) |
| Menos estaciones que p + 1 con peso no nulo en una celda | `NA` + `EF_GWR_LOCAL_SINGULAR` (si el rango es deficiente) o valor + `EF_GWR_FEW_NEIGHBOURS` |

No se reemplaza nunca un ajuste local fallido por OLS, por un vecino ni por
una regularización (ridge) de forma implícita (contraste: `mgwrsar`
reemplaza por OLS los puntos aislados, según su NEWS). Una regresión GW con
compensación ridge local (Gollini et al., §7.3) queda fuera de alcance; si
se adopta, será una opción explícita con su propia especificación.

---

## 5. Referencia global (OLS) y métodos de comparación C1, C2, C3

### 5.1 Interfaz común

Todos los métodos consumen la misma entrada (§2.1–2.3) y devuelven
`earthflux_surface` (§2.4); el método es un argumento (switch), de modo que
los experimentos de `VALIDATION_PLAN.md` §2.1 solo cambian
`method = ef_method_*()`. Cada método implementa tres operaciones con la
misma firma conceptual: **ajuste** en estaciones (con residuos y LOO),
**predicción** en coordenadas + covariables, **diagnósticos**. Así la CV
(§8) y la predicción por bloques (§6) son comunes.

| Configuración | `method` | Estado | Parámetros obligatorios |
|---|---|---|---|
| C1 estación representativa | `"station"` | Requerido | `station_id` (sin elección automática por defecto) |
| C1 con ajuste por elevación | `"station_lapse"` | Opcional | `station_id`, `lapse_rate` con fuente y estado (`radiation-components.md` RC-12 opción a: valor `TODO`) |
| C2 regresión global | `"global_ols"` | Requerido (es además el límite de GWR) | Covariables (las mismas que GWR) |
| C2 IDW | `"idw"` | Requerido | `power` (sin defecto) o selección por LOOCV en una rejilla registrada |
| C2 kriging con deriva externa / regresión-kriging | `"ked"` | Opcional (posterior) | Variograma; dependencia (`gstat`, GPL ≥ 2, 2.1-6 en CRAN al 2026-11-04) en `Suggests` |
| C2 reanálisis u otro producto grillado | `"gridded"` | Opcional (posterior) | `SpatRaster` entregado por el usuario |
| C3 GWR | `"gwr"` | Requerido | Kernel, tipo de bandwidth, criterio o bandwidth fijo, covariables |

### 5.2 Regresión global (OLS) y caso límite

β̂ = (XᵀX)⁻¹Xᵀy con el mismo **X** que GWR. Diagnósticos con las mismas
definiciones (tr S = p, AICc de §4.1 con tr S = p, CV con e₋ᵢ =
eᵢ/(1 − h_ii)). Es la referencia "b = ∞" del perfil (§4.4).

Caso límite (R9; `VALIDATION_PLAN.md` §1.1): con boxcar y b mayor que toda
distancia, cada Wᵢ = I y GWR es exactamente OLS (caso G4: |Δβ| = 7,1 ×
10⁻¹⁵, tr S = 2, AICc idéntico al de OLS); con gaussiano, β̂ → β̂_OLS al
crecer b (caso G4: |Δβ| = 1,6 × 10⁻³, 1,6 × 10⁻⁵ y 1,6 × 10⁻⁹ con b = 10⁵,
10⁶ y 10⁸ m; observado: decrece ≈ 100 veces por cada factor 10 en b).

### 5.3 C1: estación representativa

- Superficie constante igual al valor de la estación `station_id`, para cada
  `target_time`. Elección de la estación: del usuario; reglas automáticas
  (p. ej., más cercana al centroide del AOI) solo como opción explícita
  registrada. `water` restringe las anclas a un radio de la estación
  (`anchor-pixels.md` §2.4): la coherencia entre la estación de C1 y las
  anclas se registra, no se impone aquí.
- Variante con gradiente vertical (solo `air_temperature`): T(x) = T_s +
  Γ·(z(x) − z_s) con Γ entregado con fuente y estado; no hay valor por
  defecto (`TODO`).
- Diagnóstico equivalente a la CV: error en las **demás** estaciones
  (predicción = valor de la estación representativa, o con gradiente);
  la estación representativa se excluye del conjunto de evaluación.
- Flag de procedencia `EF_FORCING_SINGLE_STATION` (info).

### 5.4 C2: alternativas

- **Regresión global con covariables** (§5.2): separa el aporte de la
  no estacionariedad (GWR) del aporte de las covariables.
- **IDW** (Shepard, 1968; contenido no leído, `CANDIDATA`): ŷ(x) =
  Σ λⱼ yⱼ con λⱼ ∝ d(x, j)^(−power), Σλⱼ = 1; en una ubicación que
  coincide con una estación, el valor de esa estación. `power` sin defecto
  (la elección habitual 2 no está verificada); opción de seleccionarlo por
  LOOCV en una rejilla registrada. Sin covariables; extrapolación marcada
  igual que GWR (§6.3, salvo el rango de covariables).
- **KED / regresión-kriging** (Hengl et al., 2007; no leído): opcional,
  posterior; requiere su propia especificación de variograma.
- **Reanálisis** (NCEP/NCAR, Kalnay et al., 1996; ERA5, Hersbach et al.,
  2020; usado en el antecedente vía `RNCEP`): opcional; el usuario entrega
  el campo como `SpatRaster` (EarthFlux no descarga datos, `DEVELOPMENT.md`
  §5); remuestreo a la grilla (método registrado) y, si se desea, ajuste por
  elevación con Γ explícito. Disponibilidad, licencias y resolución para
  Chile: `TODO` (`weather-forcing.md` §9). `RNCEP` (1.0.11, GPL ≥ 2) y
  `ecmwfr` (2.0.3, AGPL-3) existen en CRAN al 2026-11-04, pero no se
  proponen como dependencias.

### 5.5 C3: GWR

§3–4 y §6–7. La selección de bandwidth puede ser por ajuste (variable ×
`target_time`) o fija por variable a lo largo de las fechas (decisión
GW-11: la selección por ajuste maximiza el ajuste local pero hace que la
superficie de un día dependa de un bandwidth inestable con pocas
estaciones; la fija por variable estabiliza, a costa de no adaptarse).

---

## 6. Predicción a grillas

### 6.1 Modo exacto por bloques (por defecto)

- Para cada celda g con covariables completas: pesos respecto de las
  estaciones (bandwidth fijo o k-ésima distancia, §3.5), WLS local, ŷ_g =
  x_gᵀβ̂_g. Celdas con alguna covariable `NA` → `NA` (y `EF_INPUT_NA` desde
  la orquestación).
- Envoltorio `terra` por bloques (patrón de `thermify`, `ARCHITECTURE.md`
  §6.6): `readStart()`/`readValues()` de las covariables por filas,
  cálculo, `writeStart()`/`writeValues()` de la superficie, de la capa de
  flags y, opcionalmente, de las capas de coeficientes y del número de
  estaciones con peso no nulo. Tamaño de bloque desde `terra::blocks()` o
  argumento `block_rows`; se registra.
- Garantía (test): el tamaño de bloque no cambia el resultado
  (`identical()` o tolerancia 0 con el mismo algoritmo).
- Kernels compactos: cada celda puede restringirse a las estaciones con
  d < b_g (búsqueda de vecinos); resultado idéntico al cálculo con todos
  los pesos (los nulos no aportan).

### 6.2 Modo grueso + interpolación (opcional; GW-08)

- Estimar β̂ en una grilla gruesa alineada con la de trabajo (factor
  entero `coarse_factor`), extendida al menos una celda gruesa más allá de
  la grilla fina para que la interpolación bilineal no deje bordes `NA`
  (en el prototipo de la evaluación la grilla gruesa no se extendió);
  remuestrear cada capa de coeficientes con `terra::resample(method =
  "bilinear")` y calcular ŷ = Σₖ xₖ β̂ₖ con álgebra ráster.
- Registro: `prediction_mode = "coarse"`, `coarse_factor`, tamaño de celda
  gruesa, relación celda gruesa / bandwidth (fijo) o / mediana de b_g
  (adaptativo), flag `EF_GWR_COARSE_MODE` (info) en todas las celdas.
- **Control obligatorio:** cálculo exacto en una submuestra determinista de
  celdas (p. ej., cada m-ésima celda por fila y columna; m registrado) y
  reporte de la mediana y el máximo de |ŷ_coarse − ŷ_exacta| en los
  diagnósticos.
- Evidencia empírica (**no es una cota de error**): en el sintético, 10⁴
  ajustes en celdas de 1 km + bilineal a 10⁶ celdas tomaron 0,4 s frente a
  ≈ 19 s del modo exacto, con diferencia en Ta de mediana 6 × 10⁻⁵ °C y
  máximo 0,014 °C, con bandwidth de 40 km (`gwr-backend.md` §5.3). No se
  generaliza a otros bandwidths, kernels ni redes.
- Variante del antecedente (agregar covariables, predecir y remuestrear la
  **predicción**): no equivalente, porque promedia la covariable antes de
  aplicar la relación local; si se ofrece, se registra como modo distinto.

### 6.3 Detección de extrapolación (flags por celda)

| Condición | Definición inequívoca | Flag | Umbral |
|---|---|---|---|
| Covariable fuera del rango de las estaciones del ajuste | x_g,k < minⱼ xⱼ,k o x_g,k > maxⱼ xⱼ,k para alguna covariable k (estaciones usadas) | `EF_GWR_EXTRAPOLATION_COVARIATE` | No (rango observado) |
| Covariable fuera del rango **local** | Ídem, restringido a las estaciones con peso no nulo en g (kernels compactos) | `EF_GWR_EXTRAPOLATION_LOCAL` | No |
| Fuera de la envolvente convexa de las estaciones | Centro de celda fuera del polígono convexo de las estaciones usadas (coordenadas proyectadas) | `EF_GWR_OUTSIDE_HULL` | No |
| Lejos de toda estación | Distancia a la estación más cercana > `d_max` | `EF_GWR_FAR_FROM_STATIONS` | Sí, sin defecto (no registrar) |
| Pocas estaciones con peso no nulo | < `min_neighbours` (§4.5) | `EF_GWR_FEW_NEIGHBOURS` | Parámetro (mínimo matemático por defecto) |

- Extensiones multivariadas (p. ej., distancia de Mahalanobis en el espacio
  de covariables) quedan `TODO` (sin referencia leída).
- La envolvente y el rango se calculan por ajuste (cambian si cambian las
  estaciones válidas entre fechas).
- Para `anchor-pixels.md` (`EF_ANCHOR_FORCING_EXTRAPOLATED`), la
  definición inequívoca que este módulo ofrece es: la celda del ancla tiene
  activado `EF_GWR_EXTRAPOLATION_COVARIATE` o `EF_GWR_OUTSIDE_HULL`
  (propuesta; la decisión es de esa especificación).

### 6.4 Memoria y tiempo

| Etapa | Costo | Memoria |
|---|---|---|
| Ajuste en estaciones + tr S + LOO | O(n²p + np³) por bandwidth | n × n distancias (n = 300 → 0,7 MB) |
| Búsqueda | × (n_grid + refinamiento) fijo; × ≈ n adaptativo | Igual |
| Predicción exacta | O(N·n·p² + N·p³) | Por bloque de B celdas: B × n distancias y pesos (8·B·n bytes cada matriz; B = 10⁴, n = 150 → 11 MB) |
| Modo grueso | O((N/f²)·n·p²) + remuestreo O(N·p) | Ídem por bloque grueso + p capas finas |

Tiempos medidos con el prototipo en base R, un hilo (`gwr-backend.md`
§5.2): 4,1 s para 10⁵ celdas y ≈ 19–20 s para 10⁶ (n = 150, p = 3);
extrapolado ≈ 3 min por fecha y variable para 10⁷ celdas. Con la opción C
(≈ 100 ajustes por fecha, §2.1) la predicción domina: el modo grueso o
el paralelismo entre ajustes (§6.5) son la palanca principal. Regla 6 de
`ARCHITECTURE.md` §6.3: benchmark reproducible en `dev/` antes de
optimizar.

### 6.5 Paralelismo (`ARCHITECTURE.md` §6.3)

- **Núcleo secuencial y puro** (matrices → matrices), sin estado global,
  sin RNG, sin plan propio.
- **Entre tareas** (nivel principal): ajustes (variable × `target_time`),
  bandwidth del perfil (opcional), pliegues de CV. Con
  `future.apply::future_lapply()` (o el mecanismo que fije la decisión de
  M1) **solo si** el usuario estableció un plan; por defecto `lapply()`.
  Medido en la evaluación: 8 fechas, secuencial 18,1 s frente a 9,3 s con 4
  workers, resultados `identical()`.
- **Intra-escena** (opcional): bloques de filas calculados por workers y
  escritos por el proceso principal **en orden** (la escritura de `terra`
  es secuencial); alternativa `terra::app(..., cores = )` sobre una función
  por celda. El resultado no depende del número de workers.
- Prohibido: `parallel::mclapply()` como mecanismo principal; fijar
  `detectCores()` o un plan global (contraste con el antecedente, §1.4).
  Tests y ejemplos: como máximo 2 workers.
- Semillas: GWR no usa azar. Solo la usan la asignación aleatoria de
  pliegues (no recomendada, §8.2) y el test de permutación de Moran
  (§7.3): `seed` explícita obligatoria (`earthflux_seed_required`,
  `anchor-pixels.md` §5.4) y `future.seed` en paralelo.

---

## 7. Objeto de diagnóstico `earthflux_gwr`

### 7.1 Campos

Lista con clase `c("earthflux_gwr", "earthflux_regionalization", "list")`
(una por ajuste):

| Elemento | Contenido |
|---|---|
| `call`, `variable`, `target_time`, `unit` | Identificación del ajuste |
| `stations` | `data.frame`: `station_id`, x, y (CRS de distancias), covariables usadas, `observed`, `fitted`, `residual`, `loo_fitted`, `loo_residual`, `s_ii`, `local_r2`, `bandwidth_i` [m] (= b o k-ésima distancia), `n_nonzero`, `kappa`, `rank_ok`, `status` (`used`/`excluded`), `exclusion_reason` |
| `coefficients` | Matriz n × p de β̂ᵢ en unidades originales (columnas nombradas con unidad) |
| `kernel` | Texto exacto (`"bisquare"`, …) |
| `bandwidth` | `list(type = "fixed"|"adaptive", value, unit = "m"|"neighbours", selected_by = "AICc"|"CV"|"user")` |
| `conventions` | `k_convention = "kth_nearest_including_self"`, `boxcar_support = "le"`, `aicc_definition`, `sigma_aicc = "ml"`, `local_r2_convention = "local_fit_weighted_mean"`, `loo_convention = "zero_own_weight"`, `distance_method`, `covariate_scaling` |
| `fit` | `n`, `p`, `rss`, `sigma_ml` = √(RSS/n), `sigma_edf` = √(RSS/edf) (`CANDIDATA`), `enp` = tr S, `tr_sts`, `enp_alt`, `edf`, `aicc`, `aic` (sin corrección, solo reporte), `cv`, `rmse_loo`, R² global 1 − RSS/TSS |
| `global_reference` | Ajuste OLS con el mismo X: coeficientes, RSS, AICc (tr S = p), CV |
| `profile` | `data.frame` del criterio vs bandwidth (§4.4), con `feasible` y motivo de no factibilidad; incluye la fila b = ∞ |
| `search` | Límites, `n_grid`, `tol`, `min_neighbours`, `lower_offset`, `upper_factor`, `k_min`, `k_max`, número de evaluaciones, regla de empates |
| `flags` | Lista de `earthflux_flag` a nivel de ajuste y de estación (§12) |
| `config` | Configuración de la variable (covariables, fuente, transformación) |
| `provenance` | Ver §2.4 |

### 7.2 `print()` y `summary()`

- `print()`: variable y tiempo; método, kernel, tipo y valor del
  bandwidth (con unidad), criterio y su valor; n usadas / excluidas; tr S,
  2tr S − tr SᵀS; RSS, RMSE_LOO; comparación con el global (AICc, CV);
  flags por severidad; y la línea "convenciones: k incluye el propio punto;
  AICc con σ̂ ML y tr(S)".
- `summary()`: cuantiles de los coeficientes locales y del R² local;
  tabla por estación (residuo, LOO, s_ii, κ); perfil (mínimos locales,
  posición del óptimo respecto de los límites); flags con descripción.
- `plot()` (M5, `plot.R`): perfil del criterio; coeficientes locales en las
  estaciones.
- `as.data.frame()`: `stations`.

### 7.3 Autocorrelación espacial de residuos (opcional; `TODO`)

- Estadístico candidato: I de Moran (Moran, 1950; metadatos verificados,
  contenido **no leído**) sobre los residuos LOO (o residuos del ajuste),
  con matriz de pesos espaciales declarada (p. ej., inversa de la distancia
  o k vecinos; su elección es una decisión, GW-18). Fórmula `TODO` hasta
  leer la fuente; verificación cruzada posible con `spdep` (instalado como
  dependencia de `GWmodel`; solo en tests).
- Inferencia: los residuos de regresión no son independientes; la prueba
  analítica clásica para residuos de regresión requiere una referencia no
  leída (`TODO`). Alternativa: prueba de permutación con `seed` obligatoria.
- Uso: diagnóstico descriptivo de la adecuación del modelo y argumento para
  la CV por bloques (§8.2); no interviene en la selección del bandwidth.

---

## 8. Hooks de validación

### 8.1 LOOCV

Los residuos LOO por estación (§4.3) se entregan para todos los métodos
(C1: error en las demás estaciones, §5.3; OLS e IDW: ajuste sin la
estación). Para GWR, el bandwidth se mantiene fijo en el LOO del objeto
(LOO "condicional al bandwidth"); la CV anidada (re-seleccionar el
bandwidth sin la estación) es opción de §8.2 con pliegues de tamaño 1.

### 8.2 CV por bloques espaciales (`VALIDATION_PLAN.md` §2.3)

- Función de pliegues **determinista** por teselas: cada estación se asigna
  a la tesela ⌊(x − x₀)/L⌋, ⌊(y − y₀)/L⌋ de lado L [m] (origen y L
  registrados); cada tesela (o grupo de teselas, por regla registrada) es
  un pliegue. Pliegues entregados por el usuario: también aceptados (vector
  `fold` por `station_id`). Sin azar por defecto (Roberts et al., 2017,
  discuten estrategias de bloques; contenido no leído).
- En cada pliegue: ajuste con las estaciones de entrenamiento,
  **re-selección del bandwidth** dentro del entrenamiento
  (`reselect_bandwidth = TRUE` por defecto; si `FALSE`, se registra que la
  CV es condicional a un bandwidth elegido con todos los datos, optimista),
  predicción en las estaciones del pliegue con sus covariables.
- Salida: tabla larga (`station_id`, `fold`, `variable`, `target_time`,
  `observed`, `predicted`, `method`), consumida por `validation.R`
  (RMSE, MAE, sesgo; `VALIDATION_PLAN.md` §2.3). Los **mismos pliegues**
  para C1, C2 y C3 (comparación pareada).
- Opción C de la decisión 5.1: `api` recalcula ETr en la estación omitida
  con los insumos predichos del mismo pliegue (`weather-forcing.md` §6);
  este módulo solo garantiza pliegues idénticos entre variables.
- Pliegues con menos de `n_min` estaciones de entrenamiento o sin bandwidth
  factible → el pliegue se reporta como fallido (no se omite en silencio).

### 8.3 Reproducibilidad

- Resultado invariante al orden de las estaciones (test: permutar filas →
  mismas predicciones con tolerancia relativa 1 × 10⁻¹², por el orden de
  las sumas).
- Determinismo completo sin semilla (búsqueda determinista, empates
  resueltos por regla). Semilla solo donde hay azar (§6.5).
- Procedencia completa (§2.4) y versiones de paquetes; el benchmark
  sintético de `gwr-backend.md` §2 se versiona en `dev/` (consecuencia de
  la decisión de backend, `gwr-backend.md` §8).

### 8.4 Secuencial = paralelo

Tests con `future::plan(sequential)` y `plan(multisession, workers = 2)`
sobre varios ajustes y sobre bloques: `identical()` en superficies,
flags y diagnósticos (excepto marcas de tiempo de la procedencia).

---

## 9. Descomposición en funciones, errores con clase, NA y dominio

### 9.1 Funciones propuestas (nombres a decidir en GW-23)

| Función | Argumentos principales (unidades) | Salida | Exportar |
|---|---|---|---|
| `ef_gwr_fit(y, x, coords, bandwidth, kernel, adaptive = FALSE, min_neighbours = NULL, scale_covariates = TRUE, kappa_max = NULL)` | `y` numérico (unidad de la variable); `x` matriz n × (p − 1) de covariables con nombres (unidades en atributo); `coords` matriz n × 2 [m, CRS proyectado]; `bandwidth` [m] o k entero; `kernel` texto | `earthflux_gwr` (sin perfil si el bandwidth lo da el usuario) | Sí |
| `ef_gwr_bandwidth(y, x, coords, kernel, adaptive = FALSE, criterion = c("AICc", "CV"), search = ef_gwr_search())` | Ídem | `earthflux_gwr_bandwidth`: óptimo, perfil, flags | Sí |
| `ef_gwr_search(lower = NULL, upper = NULL, n_grid, tol, min_neighbours = NULL, lower_offset, upper_factor, k_min = NULL, k_max = NULL, method_adaptive = c("exhaustive", "golden"))` | m o enteros | Lista validada | Sí (control) |
| `ef_gwr_predict(object, newx, newcoords)` | `newx` matriz N × (p − 1) mismas columnas y unidades; `newcoords` [m] | `list(value, coefficients, n_nonzero, flags)` (vectores/matrices) | Sí |
| `ef_gwr_diagnostics(object)` | `earthflux_gwr` | Lista/`data.frame` de §7.1 (`fit`, `stations`, `profile`, `flags`) | Sí |
| `ef_regionalize(data, covariates, method, config, grid, prediction = ef_predict_control(), use_qc, exclude = NULL)` | `ef_regionalization_input`; `SpatRaster` de covariables; `ef_method_*()` | `earthflux_surface` | Sí (orquestador del módulo; nombre GW-23) |
| `ef_regionalize_cv(data, covariates, method, config, folds, reselect_bandwidth = TRUE)` | Pliegues (§8.2) | Tabla larga de predicciones fuera de pliegue | Sí |
| `ef_spatial_folds(coords, block_size, origin = NULL)` | [m] | Vector entero de pliegues | Sí |
| `ef_method_gwr(kernel, adaptive, criterion = NULL, bandwidth = NULL, search)`, `ef_method_station(station_id, lapse_rate = NULL)`, `ef_method_ols()`, `ef_method_idw(power)` | – | Objetos de método validados | Sí |
| `ef_predict_control(mode = c("exact", "coarse"), coarse_factor = NULL, block_rows = NULL, check_every = NULL, write_coefficients = FALSE, filename = "")` | – | Lista validada | Sí |
| `ef_ols_fit()`, `ef_idw_fit()`, `ef_station_forcing()` + métodos `predict()` | Mismas firmas conceptuales que `ef_gwr_fit()`/`ef_gwr_predict()` | Objetos `earthflux_ols`, `earthflux_idw`, `earthflux_station_forcing` | Internas o exportadas (API pequeña: preferir internas tras `ef_regionalize()`) |
| `print()`, `summary()`, `as.data.frame()` para `earthflux_gwr`, `earthflux_gwr_bandwidth`, `earthflux_surface` | – | – | Métodos S3 |

`ef_gwr_fit()` y `ef_gwr_predict()` operan sobre `numeric`/`matrix`, sin
objetos espaciales (`ARCHITECTURE.md` §3); `ef_regionalize()` es el único
punto que toca `terra` (proyección, extracción, bloques).

### 9.2 Internas

| Función interna | Propósito |
|---|---|
| `gwr_distance(coords_from, coords_to, method)` | Matriz de distancias [m] (bloques de filas) |
| `gwr_row_bandwidth(dist, bandwidth, adaptive)` | b_i por fila (fijo o k-ésima distancia, §3.5) |
| `gwr_kernel_weights(dist, b, kernel)` | w(d/b) de §3.4 (boxcar con d ≤ b) |
| `gwr_check_design(x, w, kappa_max)` | Rango, κ, `n_nonzero` |
| `gwr_local_wls(x, y, w)` | β̂ y fila de S (QR de referencia) |
| `gwr_hat_stats(...)` | s_ii, tr S, tr SᵀS, LOO (atajo de §4.3) |
| `gwr_aicc(rss, enp, n)` | §4.1; `NA` si n − 2 − enp ≤ 0 |
| `gwr_cv_score(e_loo)` | §4.3 |
| `gwr_profile(...)`, `gwr_refine(...)` | §4.4 |
| `gwr_scale_design()`, `gwr_unscale_coef()` | §3.7 |
| `gwr_extrapolation_flags(newx, newcoords, fit)` | §6.3 (incluye envolvente convexa) |
| `gwr_predict_block(...)` | Núcleo de predicción por bloque (§6.1) |
| `gwr_flag_bits()` | Tabla bit ↔ código (enmienda A1) |

### 9.3 Errores con clase

Siguiendo `R/utils.R` (`ef_abort()`, `check_numeric()`,
`check_common_length()`, `check_in_range()`, `check_string()`):

| Situación | Clase | Detalle adjunto (requiere D-AP-10 de `anchor-pixels.md`: campos extra en la condición) |
|---|---|---|
| Tipos, columnas faltantes, duplicados, covariable sin nombre, CRS geográfico sin `distance_crs` | `earthflux_input_error` | Argumento |
| Dimensiones incoherentes (`nrow(x) != length(y)`, `ncol(coords) != 2`, columnas de `newx` distintas) | `earthflux_dimension_error` (subclase de `earthflux_input_error`) | – |
| Bandwidth ≤ 0, k fuera de [1, n] o no entero, `power` ≤ 0, `Inf` | `earthflux_domain_error` (vía `check_in_range()`) | – |
| Kernel desconocido, criterio desconocido | `earthflux_input_error` | Valores admitidos |
| n < p + 3 | `earthflux_gwr_insufficient_stations` (subclase de `earthflux_gwr_error` → `earthflux_error`) | n, p |
| Sin bandwidth factible | `earthflux_gwr_no_feasible_bandwidth` | Perfil |
| Diseño local singular en una estación con bandwidth del usuario | `earthflux_gwr_singular_error` | Estaciones afectadas |
| Covariable constante entre estaciones | `earthflux_input_error` | Covariable |
| Método con azar sin semilla | `earthflux_seed_required` | – |

Las condiciones físicas de la predicción (valores fuera de dominio) son
**flags**, no errores (§2.3).

### 9.4 NA y dominio

- `y` o covariables `NA` en una estación → estación excluida con motivo
  (no error); si tras excluir quedan n < p + 3 → error de §9.3.
- Covariable `NA` en una celda → `NA` en la superficie y en coeficientes;
  el flag `EF_INPUT_NA` lo construye la orquestación.
- `Inf` en cualquier entrada → `earthflux_domain_error`.
- Ningún valor se trunca ni reemplaza (principio 6).

---

## 10. Casos numéricos verificables y plan de verificación cruzada

Datos del caso pequeño (coordenadas proyectadas en m; p = 2: intercepto +
elevación):

| Estación | x [m] | y [m] | z [m] | Ta [°C] | d a S1 [m] |
|---|---|---|---|---|---|
| S1 | 0 | 0 | 100 | 20,0 | 0 |
| S2 | 10 000 | 0 | 300 | 18,9 | 10 000 |
| S3 | 0 | 10 000 | 500 | 17,5 | 10 000 |
| S4 | 10 000 | 10 000 | 200 | 19,6 | 14 142,136 |
| S5 | 20 000 | 0 | 800 | 15,4 | 20 000 |
| S6 | 30 000 | 30 000 | 1 200 | 13,1 | 42 426,407 |

### G1a — boxcar fijo b = 15 000 m en S1 (a mano)

1. Pesos (d ≤ b): S1–S4 = 1; S5, S6 = 0 → OLS sobre 4 estaciones.
2. z̄ = 275 m; T̄ = 19,0 °C; Sxx = 175² + 25² + 225² + 75² = 87 500 m²;
   Sxy = (−175)(1,0) + (25)(−0,1) + (225)(−1,5) + (−75)(0,6) = −560 °C m.
3. β̂₁ = −560/87 500 = **−0,0064 °C m⁻¹**; β̂₀ = 19,0 + 0,0064·275 =
   **20,76 °C**; ŷ₁ = 20,76 − 0,64 = **20,12 °C**.
4. s₁₁ = 1/4 + (100 − 275)²/87 500 = 0,25 + 0,35 = **0,60**.
5. LOO (w₁₁ = 0, OLS sobre S2–S4): β̂ = (21,0; −0,0070), ŷ≠₁ = **20,3 °C**;
   e₋₁ = −0,3 = (20,0 − 20,12)/(1 − 0,6) (atajo de §4.3).

### G1b — gaussiano fijo b = 10 000 m en S1 (a mano con calculadora)

1. r = d/b = 0, 1, 1, √2, 2, 3√2 → w = 1; e^(−0,5) = 0,60653066 (×2);
   e^(−1) = 0,36787944; e^(−2) = 0,13533528; e^(−9) = 1,234098 × 10⁻⁴.
2. Σw = 2,71639945; z̄_w = 282,438849 m; T̄_w = 18,91251046 °C;
   Sxx_w = Σw(z − z̄_w)² = 101 036,082165; Sxy_w = −652,46430252.
3. β̂₁ = Sxy_w/Sxx_w = **−0,0064577356 °C m⁻¹**; β̂₀ = T̄_w − β̂₁ z̄_w =
   **20,73642587 °C**; ŷ₁ = **20,090654 °C**.
4. s₁₁ = w₁₁ (1/Σw + (z₁ − z̄_w)²/Sxx_w) = **0,6975606**.
5. Condición: cond₂(XᵀW₁X) = 3,678 × 10⁵ (z en m); κ de W^{1/2}X con
   columnas equilibradas = 3,2378 (§3.7).

### G2 — ajuste completo, gaussiano fijo b = 20 000 m (referencia y verificación cruzada)

Valores de código propio (base R):

| Magnitud | Valor |
|---|---|
| RSS | 0,05488621 °C² |
| tr S | 2,73817720 |
| tr SᵀS | 2,29531863 |
| 2 tr S − tr SᵀS | 3,18103577 |
| edf = n − 2tr S + tr SᵀS | 2,818964 |
| AICc (§4.1) | 24,412005 |
| CV (Σ e₋ᵢ²) | 0,34958300 °C² |

| Estación | β̂₀ [°C] | β̂₁ [°C m⁻¹] | e [°C] | s_ii | e₋ᵢ [°C] |
|---|---|---|---|---|---|
| S1 | 20,78793 | −0,00658359 | −0,12957310 | 0,4779725 | −0,24821127 |
| S2 | 20,79976 | −0,00659954 | 0,08010029 | 0,2467174 | 0,10633498 |
| S3 | 20,78418 | −0,00654505 | −0,01165763 | 0,2697879 | −0,01596471 |
| S4 | 20,79070 | −0,00654500 | 0,11829798 | 0,3295729 | 0,17645165 |
| S5 | 20,80460 | −0,00659823 | −0,12601841 | 0,5107340 | −0,25756623 |
| S6 | 20,77549 | −0,00643029 | 0,04086582 | 0,9033926 | 0,42300900 |

Comprobaciones observadas: e₋ᵢ por definición = eᵢ/(1 − s_ii) (8
decimales). `GWmodel` 2.4-1 (`gwr.basic(..., cv = TRUE)`): AICc 24,412005,
`enp` 3,18103577 (= 2tr S − tr SᵀS), `edf` 2,818964, RSS 0,05488621,
`CV_Score` = e₋ᵢ, máx. |Δβ| 1,8 × 10⁻¹⁴, `AIC` −8,400076. R² local:
§3.8. Nota: en esta ejecución `GWmodel::gwr.cv()` sin matriz de
distancias falló con *"object 'DM.given' not found"* (otra fragilidad del
mismo tipo que la de `gwr.predict()`; el valor por estación se obtuvo de
`CV_Score`).

### G3 — convención de k adaptativo (bicuadrado, en S1)

| k | b₁ = d₁,(k) [m] | Pesos no nulos | Pesos (S1…S6) |
|---|---|---|---|
| 2 | 10 000 | 1 | 1, 0, 0, 0, 0, 0 |
| 3 | 10 000 | 1 | ídem (empate S2/S3 en el borde) → diseño singular en S1 |
| 4 | 14 142,136 | 3 | 1; 0,25; 0,25; 0; 0; 0 |
| 5 | 20 000 | 4 | 1; 0,5625; 0,5625; 0,25; 0; 0 |

Con k = 5 en todas las estaciones, los coeficientes de esta convención
coinciden con `GWmodel` (`adaptive = TRUE, bw = 5`) a 3,6 × 10⁻¹⁴. Boxcar
adaptativo en `GWmodel` con bw = 3 en S1: pesos 1, 1, 1, 0, 0, 0 (incluye
el empate en d = b).

### G4 — límite OLS

β̂_OLS = (20,75566218809981; −0,00646257197697); RSS_OLS = 0,08253359;
AICc_OLS (§4.1 con tr S = p = 2) = 9,309406.

| Configuración | máx. \|β̂ − β̂_OLS\| | tr S |
|---|---|---|
| Boxcar b = 10⁶ m | 7,1 × 10⁻¹⁵ | 2,000000000000 (AICc = 9,309406) |
| Gaussiano b = 10⁵ m | 1,615 × 10⁻³ | 2,0295722 |
| Gaussiano b = 10⁶ m | 1,599 × 10⁻⁵ | 2,0002954 |
| Gaussiano b = 10⁸ m | 1,599 × 10⁻⁹ | 2,0000000 |

Tolerancias de test: boxcar, `sqrt(.Machine$double.eps)` relativa
(identidad algebraica, `VALIDATION_PLAN.md` §1.2); gaussiano, monotonía
del error al crecer b y error < 1 × 10⁻⁸ con b = 10⁸ m (justificación: el
error observado escala como b⁻²).

### G5 — diseño local singular

Boxcar b = 5 000 m en S1: solo S1 tiene peso; XᵀW₁X = [[1, 100], [100,
10 000]], rango 1 → en una estación: `earthflux_gwr_singular_error` (si el
bandwidth lo fija el usuario) o bandwidth no factible (en la búsqueda); en
una celda: `NA` + `EF_GWR_LOCAL_SINGULAR`.

### G6 — dominio del AICc

Gaussiano fijo, n = 6, p = 2:

| b [m] | tr S | n − 2 − tr S | "AICc" por la fórmula | Tratamiento |
|---|---|---|---|---|
| 6 000 | 5,252969 | −1,252969 | −87,6071 | No factible (`NA`) |
| 8 000 | 4,683610 | −0,683610 | −120,8977 | No factible (`NA`) |
| 12 000 | 3,758735 | 0,241265 | 221,3354 | Factible |

Con b = 3 000 m el sistema local es numéricamente singular en `solve()`
(pesos ≈ 4 × 10⁻³ a 10 km): no factible por rango/condición.

### G7 — referencia sintética de 150 estaciones (integración)

Datos de `gwr-backend.md` §2 (`set.seed(20261104)`), bicuadrado fijo
b = 40 000 m: RSS 21,988635; tr S 14,110126; tr SᵀS 10,218746; AICc
171,521589; CV 27,491712; adaptativo k = 30: AICc 173,128323, tr S
22,265331 (`gwr-backend.md` §4.3). Uso: test de integración con tolerancia
1 × 10⁻⁶ relativa (valores impresos a 6 decimales) y benchmark de `dev/`.

### Plan de verificación cruzada en tests

Decidido (§1.2): **solo `GWmodel`**, declarado en `Suggests`, en
`tests/testthat/test-gwr-crosscheck.R` con
`testthat::skip_if_not_installed("GWmodel")`; el resto de los tests (casos
G1–G7, identidades, límites) no depende de ningún paquete externo. Si en
el futuro se evalúa `mgwrsar` para MGWR (GW-16), sus convenciones de k y
de AICc (§3.5, §4.2) deberán mapearse antes de compararlo.

Equivalencias de convención a respetar en cada comparación:

| Magnitud EarthFlux | `GWmodel` 2.4-1 |
|---|---|
| β̂ local (fijo) | `gwr.basic()$SDF` (columnas de coeficientes) |
| β̂ local (adaptativo k) | `adaptive = TRUE, bw = k` (misma convención, caso G3) |
| tr S | No expuesto directamente; su `enp` = 2tr S − tr SᵀS (comparar con `enp_alt`) |
| AICc | `GW.diagnostic$AICc` |
| AIC sin corrección | `GW.diagnostic$AIC` |
| edf | `GW.diagnostic$edf` |
| LOO por estación / CV | `SDF$CV_Score` (con `cv = TRUE`) / su suma de cuadrados |
| R² local | `SDF$Local_R2` = variante "ŷ global, media no ponderada" (§3.8), no la convención por defecto de EarthFlux |
| Predicción | `gwr.predict(..., dMat1 = gw.dist(...))` (sin `dMat1` falla si n + N > 10 000) |
| Boxcar en d = b | Peso 1 (= EarthFlux) |
| Gaussiano | `"gaussian"` (misma escala) |
| Límite inferior adaptativo de `bw.gwr()` | Fijo en 20: no comparar bandwidths seleccionados con n pequeño |

- Tolerancias: 1 × 10⁻¹⁰ relativa en coeficientes, RSS, tr S, AICc, CV y
  predicción (diferencias observadas ≤ 6 × 10⁻¹¹, `gwr-backend.md` §4.3);
  el bandwidth seleccionado **no** se compara de forma estricta (límites y
  tolerancias de búsqueda distintos, `gwr-backend.md` §4.2), solo el
  criterio evaluado en un mismo bandwidth.

---

## 11. Tests planificados

`tests/testthat/test-gwr-kernel.R`, `test-gwr-fit.R`,
`test-gwr-bandwidth.R`, `test-gwr-predict.R`, `test-gwr-diagnostics.R`,
`test-regionalize.R`, `test-gwr-crosscheck.R` (nombres a confirmar):

- **Kernels:** valores en r = 0, 0,5, 1, 2 para cada kernel; w(1) = 0 en
  bicuadrado/tricúbico; boxcar d = b → 1; monotonía no creciente; el kernel
  pedido es el usado (registro en el objeto; contraste con §1.4).
- **G1a, G1b** (valores de §10; tolerancia 1 × 10⁻⁸ relativa por los
  dígitos impresos); **G2** (tabla completa); **G3** (b_i y pesos no
  nulos); **G4** (límite OLS); **G5, G6** (errores/flags/no factibles);
  **G7** (integración).
- **Identidades:** atajo LOO = LOO por definición; AICc ↔ AIC con K = tr S +
  1 + corrección (§4.1); retrotransformación del escalado (§3.7); QR =
  momentos (1 × 10⁻¹⁰).
- **Búsqueda:** perfil con mínimo en el extremo → flag; perfil multimodal
  sintético → flag; n = 15 → resultado factible y perfil registrado;
  `min_neighbours` cambia los límites como se espera; empates → menor
  bandwidth; determinismo (dos llamadas idénticas).
- **Pocas estaciones:** n = p + 2 → `earthflux_gwr_insufficient_stations`;
  intervalo sin bandwidth factible → `earthflux_gwr_no_feasible_bandwidth`.
- **Predicción:** coincidencia con el ajuste en estaciones cuando las
  celdas coinciden con estaciones; tamaño de bloque no cambia el resultado;
  modo grueso registra flag y control de submuestra; celdas `NA`
  propagan; flags de extrapolación en celdas construidas fuera de rango y
  de la envolvente.
- **Interfaz común:** C1, OLS, IDW y GWR devuelven la misma estructura
  `earthflux_surface`; C1 con estación inexistente → error.
- **CV:** pliegues por teselas deterministas; mismos pliegues para todos los
  métodos; `reselect_bandwidth` registrado.
- **Paralelo:** secuencial = `multisession` con 2 workers (`identical()`).
- **Orden:** permutar estaciones → mismo resultado (tolerancia 1 × 10⁻¹²).
- **Errores:** cada fila de §9.3 con su clase exacta.
- **Verificación cruzada** con `GWmodel` (§10; omitida si no está
  instalado).

---

## 12. Flags propuestos (no registrados)

Se registran en `ef_flag_registry()` solo cuando la función se implemente y,
si dependen de un umbral, cuando el umbral tenga referencia
(`R/diagnostics.R`). Prefijos a unificar con WF-07.

| Código propuesto | Nivel | Condición | Severidad | ¿Inequívoca? |
|---|---|---|---|---|
| `EF_GWR_EXTRAPOLATION_COVARIATE` | Celda | Covariable fuera del rango de las estaciones del ajuste | warning | Sí |
| `EF_GWR_EXTRAPOLATION_LOCAL` | Celda | Covariable fuera del rango de las estaciones con peso no nulo | info | Sí |
| `EF_GWR_OUTSIDE_HULL` | Celda | Fuera de la envolvente convexa de las estaciones | warning | Sí |
| `EF_GWR_FAR_FROM_STATIONS` | Celda | Distancia a la estación más cercana > `d_max` | warning | **No** (umbral `TODO`) |
| `EF_GWR_FEW_NEIGHBOURS` | Celda / estación | Pesos no nulos < `min_neighbours` | warning | Sí con el mínimo matemático; valores mayores requieren referencia |
| `EF_GWR_LOCAL_SINGULAR` | Celda | Diseño local de rango deficiente; valor `NA` | warning | Sí |
| `EF_GWR_ILL_CONDITIONED` | Celda / estación | κ > `kappa_max` | warning | **No** (umbral `TODO`, §3.7) |
| `EF_GWR_PHYSICAL_RANGE` | Celda | Predicción fuera del dominio físico de la variable (§2.3), conservada | warning | Sí para imposibilidades (eₐ ≤ 0, u < 0, clearness < 0, ETr_inst ≤ 0) |
| `EF_GWR_COARSE_MODE` | Superficie | Coeficientes interpolados desde grilla gruesa | info | Sí |
| `EF_GWR_TRANSFORMED` | Ajuste | Respuesta transformada y retrotransformada | info | Sí |
| `EF_GWR_SURFACE_COVARIATE` | Ajuste | Covariable derivada del estado de superficie (LST, NDVI/EVI) (§2.7) | warning | Sí |
| `EF_GWR_BW_AT_BOUND` | Ajuste | Bandwidth en el límite de búsqueda | warning | Sí |
| `EF_GWR_BW_MULTIMODAL` | Ajuste | Más de un mínimo local factible en el perfil | info | Sí (dada la rejilla) |
| `EF_GWR_AICC_UNDEFINED` | Ajuste | n − 2 − tr S ≤ 0 en parte del intervalo | info | Sí |
| `EF_GWR_GLOBAL_PREFERRED` | Ajuste | Criterio del modelo global ≤ mínimo del perfil | info | Sí |
| `EF_GWR_STATION_EXCLUDED` | Ajuste | Estaciones excluidas (QC, `NA`, usuario) | info | Sí |
| `EF_GWR_FEW_STATIONS` | Ajuste | n < `n_min` | warning | **No** (umbral `TODO`) |
| `EF_GWR_ELEVATION_MISMATCH` | Estación | \|z_metadatos − z_MDE\| > umbral | warning | **No** (umbral `TODO`) |
| `EF_FORCING_SINGLE_STATION` | Superficie | Configuración C1 | info | Sí |

---

## 13. Decisiones (cerradas y abiertas)

| ID | Decisión | Opciones | Recomendación provisional | Bloquea |
|---|---|---|---|---|
| GW-01 | Backend de GWR | — | **CERRADA (decisión del autor, 2026-11-04):** núcleo interno en base R como motor; `GWmodel` solo en `Suggests` como referencia de tests; `spgwr` descartado | — |
| GW-02 | Expresión de AICc | Forma de §4.1 / otra tras leer Hurvich et al. (1998) y Fotheringham et al. (2002) | §4.1 (`CANDIDATA (corroborada)`) | §4 |
| GW-03 | Convenciones del kernel | k incluye el propio punto (sí/no); boxcar d ≤ b vs d < b | Incluye; d ≤ b | §3.4–3.5 |
| GW-04 | Kernel por defecto en `api` | Sin defecto en el núcleo / bicuadrado / gaussiano | Sin defecto en el núcleo; el de `api` se fija con evidencia de CV | §5.5 |
| GW-05 | Criterio y búsqueda por defecto | AICc / CV; `n_grid`, `tol`, `upper_factor`, `lower_offset` | AICc; valores de búsqueda documentados como convenciones | §4.4 |
| GW-06 | `min_neighbours`, `n_min`, `kappa_max` | Mínimo matemático / umbrales con referencia | Mínimo matemático; umbrales sin defecto hasta tener referencia (pregunta 4 de `gwr-backend.md`) | §4.5 |
| GW-07 | Covariables de superficie (LST, NDVI/EVI) | Excluir / permitir con flag y sensibilidad / LST de otro instante | Opción (b) disponible (evidencia: Galdón-Ruíz et al., 2023); valor por defecto (a) hasta que el experimento de sensibilidad (C3 con y sin LST) muestre su efecto en ETa | §2.7 |
| GW-08 | Modo grueso | No ofrecer / coeficientes interpolados / predicción remuestreada (antecedente) | Coeficientes interpolados, opcional, con control de submuestra (pregunta 3 de `gwr-backend.md`) | §6.2 |
| GW-09 | Métrica de distancia | Euclidiana proyectada / gran círculo | Euclidiana proyectada; gran círculo cuando se especifique con referencia | §3.3 |
| GW-10 | Elevación en estaciones | Metadatos / MDE extraído | MDE en ajuste y predicción; diferencia como diagnóstico | §2.2 |
| GW-11 | Bandwidth por ajuste o por variable | Por (variable, tiempo) / fijo por variable / por período | Por ajuste en la primera versión; evaluar estabilidad en M6 | §5.5 |
| GW-12 | Transformaciones | Solo identidad / log, raíz con corrección de sesgo | Solo identidad | §2.3 |
| GW-13 | R² local | Ajuste local (media ponderada) / variantes con ŷ global (p. ej., la de `GWmodel`) | Ajuste local | §3.8 |
| GW-14 | Codificación de flags ráster | Bits en entero / una capa lógica por flag | Bits (enmienda A1) | §2.4 |
| GW-15 | Referencia cruzada | — | **CERRADA (decisión del autor, 2026-11-04):** solo `GWmodel`, en `tests/` con `Suggests` y `skip_if_not_installed("GWmodel")` | — |
| GW-16 | MGWR | Fuera de alcance / `mgwrsar` como backend externo opcional | Diferido; **`mgwrsar` es la opción decidida a evaluar** si MGWR llega a requerirse (decisión del autor, 2026-11-04) | – |
| GW-17 | Atípicos entre estaciones | Test de QC en `forcing` sobre valores / sobre residuos de un modelo con covariables; parámetros (factor, tipo de cuantil) | QC en `forcing`, sobre **residuos** de la regresión global con covariables (un IQR sobre valores crudos marcaría estaciones legítimamente frías por altitud); parámetros sin defecto | §1.4, §2.1 |
| GW-18 | I de Moran | No ofrecer / descriptivo / con permutación; matriz de pesos | Descriptivo tras leer la fuente; permutación con semilla | §7.3 |
| GW-19 | Incertidumbre de predicción | Omitida / varianza de predicción GWR (fuente `TODO`) / CV como proxy | Omitida en la primera versión | §2.4 |
| GW-20 | CV por bloques | Teselas deterministas (L) / pliegues del usuario / agrupamiento con semilla | Teselas; L a justificar con la escala de autocorrelación | §8.2 |
| GW-21 | Alternativa C2 principal | OLS global / IDW / KED / reanálisis | OLS e IDW requeridos; KED y reanálisis posteriores | §5 |
| GW-22 | Ubicación de las alternativas | `gwr-*.R` / archivo propio (p. ej., `spatial-baselines.R`) | Archivo propio (no son GWR) | §9 |
| GW-23 | Nombres de la API | `ef_regionalize()` / `ef_spatial_forcing()`; `ef_method_*()` | A decidir; mantener `ef_gwr_*()` para el núcleo | §9 |

---

## 14. Ítems a verificar en fuentes primarias

| Ítem | Fuente | Qué verificar |
|---|---|---|
| V1 | Hurvich, Simonoff & Tsai (1998), JRSS B 60(2):271–293 | Ecuación exacta de AICc para suavizadores lineales (número y página); definición de σ̂ y de tr(H); relación con la forma de §4.1 |
| V2 | Fotheringham, Brunsdon & Charlton (2002), libro | AICc para GWR (ecuación y página); definición de número efectivo de parámetros (tr S vs 2tr S − tr SᵀS); σ̂ y edf; R² local; varianza de predicción (GW-19); kernels y convención adaptativa; año, editorial e ISBN (`REFERENCES.md`: PARCIAL) |
| V3 | Brunsdon, Fotheringham & Charlton (1996), Geogr. Anal. 28(4):281–298; y (1998), The Statistician 47(3):431–443 | Estimador local, kernels originales, criterio de bandwidth (CV) |
| V4 | Gollini et al. (2015), JSS 63(17), versión publicada | Que §3.2/Tabla 1, §6.1 y §7 coinciden con el preprint leído; páginas definitivas; borde del boxcar (`<` vs comportamiento del paquete) |
| V5 | Belsley, Kuh & Welsch (1980) | Definición del número de condición (escalado de columnas) y origen de la regla 30 |
| V6 | Wheeler & Tiefelsdorf (2005); Páez, Farber & Wheeler (2011) | Riesgos con colinealidad local y con n pequeño; si proponen mínimos de estaciones |
| V7 | Moran (1950) | Definición del estadístico; inferencia para residuos de regresión (`TODO`: fuente adicional) |
| V8 | Roberts et al. (2017) | Recomendaciones de CV por bloques (tamaño de bloque) |
| V9 | Shepard (1968) | Forma de IDW y potencia |
| V10 | Hengl et al. (2007) | KED / regresión-kriging (si se adopta) |
| V11 | Kalnay et al. (1996); Hersbach et al. (2020) | Resolución, variables y licencia para usar reanálisis como C2 |
| V12 | Documentación de `mgwrsar` (solo si se evalúa para MGWR, GW-16) | Convención de k ("(H + 2)-th neighbour") y su AICc (170,1586 no reproducido) |

---

## 15. Hallazgos que afectan a otros documentos (no editados aquí)

| Documento | Hallazgo | Acción sugerida |
|---|---|---|
| `weather-forcing.md` §7.2 | Enmiendas A1–A5 (§2.5) | Incorporar al fusionar |
| `weather-forcing.md` §3.2 | Falta un test de consistencia espacial entre estaciones (antecedente IQR, GW-17) | Añadir QC-xx con parámetros sin defecto, sobre residuos |
| `SCIENTIFIC_SPEC.md` §6 | Esta especificación completa los puntos de §6 | Trasladar estados y casos al verificar V1–V2 |
| `REFERENCES.md` (GWR) | Nuevas citas verificadas en Crossref (§1.3); preprint arXiv:1306.0413v2 como versión leída de Gollini et al. | Añadir |
| `ARCHITECTURE.md` §4 | `method` por variable (A4); clase `earthflux_surface` | Actualizar contrato de forzamiento |
| `ARCHITECTURE.md` §6.1, `DEVELOPMENT.md` §4, `gwr-backend.md` (estado) | Decisión de backend tomada por el autor (GW-01, GW-15): núcleo interno; `GWmodel` en `Suggests`; `mgwrsar` para MGWR futuro; `spgwr` descartado | Registrar la decisión y cambiar el estado de la PROPUESTA |
| `anchor-pixels.md` §6 | Definición inequívoca de extrapolación ofrecida para `EF_ANCHOR_FORCING_EXTRAPOLATED` (§6.3) | Adoptar o ajustar |
| `radiation-components.md` RC-12 | Riesgo de circularidad si Ta se regionaliza con LST (§2.7), análogo a su opción (c) | Referenciar GW-07 |
| `R/gwr-*.R` | Encabezados con `TODO(M1)` | Actualizar referencias a este documento al implementar |

---

## 16. Registro de fuentes y accesos (2026-11-04)

| Host / recurso | Resultado |
|---|---|
| `api.crossref.org` | Accesible: metadatos de las 17 citas de §1.3; resúmenes de Brunsdon et al. (1996) y Hurvich et al. (1998). Búsqueda bibliográfica del libro de Fotheringham et al. (2002): sin registro (solo reseñas, p. ej., `10.1111/j.1538-4632.2003.tb01114.x`) |
| `arxiv.org` | Accesible: `arXiv:1306.0413v2` (preprint de Gollini et al.), leído |
| `academic.oup.com` (Hurvich et al., 1998, vía `doi.org`) | Bloqueado (CONNECT 403); no se reintentó |
| `www.jstatsoft.org` (Gollini et al., 2015) | Bloqueado (CONNECT 403); no se reintentó |
| `github.com`, `ascelibrary.org` | Bloqueados (informados de antemano); no se intentaron |
| Paquetes locales (`GWmodel` 2.4-1, `stats`, R 4.3.3; `spgwr` 0.6-37 solo para reconstruir el comportamiento del antecedente del autor, §1.4) | Ejecutados y ayuda leída localmente; solo para números y convenciones |
| Base de CRAN (`cloud.r-project.org`, observada el 2026-11-04 en la evaluación del backend) | Versiones citadas de `gstat`, `RNCEP`, `ecmwfr`, `spdep`, `future.apply` |
