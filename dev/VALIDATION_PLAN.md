# EarthFlux — Plan de verificación y validación

Estado: **borrador M1** (actualizado 2026-11-04) · Autor: Guillermo Servando
Fuentes-Jaque

Este plan separa dos actividades distintas:

| | Software verification | Scientific validation |
|---|---|---|
| Pregunta | ¿El código implementa correctamente lo especificado? | ¿Lo especificado representa adecuadamente la realidad? |
| Referencia | Ecuaciones de `SCIENTIFIC_SPEC.md` y `specs/`, casos calculados a mano o publicados, implementaciones independientes | Observaciones independientes |
| Dónde vive | `tests/testthat/` (corre en `R CMD check`); `inst/verification/` para cruces con código GPL (fuera del tarball) | Repositorio/proyecto de experimentos (fuera del tarball) |
| Hito | M2–M5 | M6 |

Regla común: ninguna de las dos actividades anticipa resultados. La parte 1
verifica que el código haga lo que dicen las especificaciones; la parte 2
contrasta la hipótesis H1 (`SCIENTIFIC_SPEC.md` §1.1) sin suponerla
verdadera.

---

## 1. Software verification

### 1.1 Niveles de prueba

| Nivel | Qué se verifica | Ejemplos (ID de caso, §1.3) |
|---|---|---|
| Ecuaciones individuales | Resultado numérico vs. caso de referencia publicado o calculado a mano | WF-V1…V17 (FAO-56); NR-ref; SG-B1 |
| Cadenas de ecuaciones | Integración de varias funciones con un caso conocido | WF-V14 (ETo diaria completa); RC-cadena (§7 de `radiation-components.md`); ET-A |
| Dimensiones | Longitudes/geometrías coherentes | Vectores de largo distinto → error con clase |
| Unidades | Conversiones y salidas en la unidad documentada | °C ↔ K; W m⁻² → mm h⁻¹ (ET-F detecta un factor 1000 omitido) |
| Valores límite | Comportamiento en bordes del dominio | α = 0, α = 1, NDVI = 1; SG-T6 (discontinuidad en LAI = 0,5) |
| NA | Propagación y flag `EF_INPUT_NA` | NA en una entrada → NA en salida |
| Errores de entrada | Tipos, rangos imposibles | Albedo = 1,3 → error |
| No corrección silenciosa | Valores fuera de rango conservados y marcados | ET-C (LE negativo); SG-B5; `EF_GWR_PHYSICAL_RANGE` |
| Invariantes | Identidades y propiedades que no dependen de un valor publicado | §1.3.4 |
| Anclas | Selección en escenas sintéticas con solución conocida | AP-P1, AP-S1 (15 × 15) |
| GWR | Casos con solución conocida | GW-G1a…G7; GW-G4 (límite OLS) |
| Verificación cruzada | Coincidencia con implementaciones independientes, con convenciones mapeadas | `GWmodel` (§1.3.3); `water` (§1.3.5) |
| Pipeline completo | Equivalencia API alta = cadena de bajo nivel | `earthflux()` ≡ encadenar `ef_*()` |

### 1.2 Tolerancias numéricas

- Comparaciones de punto flotante con `expect_equal(..., tolerance = )` o
  `expect_lt(abs(x - ref), tol)`, documentando en el test **por qué** se
  elige esa tolerancia.
- **LE ≈ Rn − G − H**: si LE se calcula como residuo, esta prueba solo
  verifica la implementación (es casi tautológica). Para que tenga valor,
  se verifica además la consistencia del ciclo completo: LE → ET_inst → LE
  (conversión inversa) acompañada de anclas numéricas independientes de la
  implementación (ET-F), y la reproducción de las condiciones de borde en
  los píxeles ancla (§1.3.4).
- Tolerancia base: del orden de `sqrt(.Machine$double.eps)` en escala
  relativa para identidades algebraicas; tolerancias mayores solo con
  justificación (iteraciones, redondeo de constantes o valores publicados).
- Reglas por tipo de caso (tomadas de cada especificación; no se redefinen
  aquí):

| Tipo de caso | Tolerancia | Fuente de la regla |
|---|---|---|
| Valor publicado redondeado (FAO-56) | Media unidad del último dígito publicado + propagación del redondeo de los insumos intermedios del ejemplo; justificar en cada test | `weather-forcing.md` §8.1 |
| Recálculo propio a precisión completa (regresión) | Relativa ~1 × 10⁻⁶ (constantes exactas, sin iteraciones) | `weather-forcing.md` §8.4 |
| Exacto en aritmética decimal | Absoluta 10⁻¹² (ET) o 10⁻¹⁰ W m⁻² (Rn) | `evapotranspiration.md` §11.1; `ef_net_radiation.md` §7.1 |
| Valores intermedios con ≥ 6 cifras | Relativa 10⁻⁶ | `soil-heat-flux.md` §9 |
| Valores impresos con 6 decimales | Media unidad del último dígito | `sensible-heat.md` §14.7 |
| Identidades de calibración (dT en anclas, H = H_target) | Relativa 10⁻¹² / 10⁻⁹ | `sensible-heat.md` §14.6 |
| Comparación con `GWmodel` | Relativa 10⁻¹⁰ (coeficientes, RSS, tr S, AICc, CV, predicción) | `gwr-forcing.md` §10 |
| Invariancia al orden de estaciones | Relativa 10⁻¹² (orden de las sumas) | `gwr-forcing.md` §8.3 |
| Secuencial = paralelo; tamaño de bloque | `identical()` (excepto marcas de tiempo de la procedencia) | `gwr-forcing.md` §8.4; `ARCHITECTURE.md` §6.3 |

### 1.3 Activos de verificación

#### 1.3.0 Convención de identificadores

Los casos de distintas especificaciones comparten nombres (p. ej., `S1`,
`T1`, `G1`, `V1` existen en varias). Para la trazabilidad, todo caso se
cita como `<prefijo>-<id>` y el mismo identificador aparece al inicio de la
descripción del `test_that()` (en inglés, `Language: en-GB`), p. ej.
`test_that("WF-V14: daily ETo of FAO-56 Example 18", ...)`.

| Prefijo | Especificación |
|---|---|
| `NR` | `specs/ef_net_radiation.md` |
| `RC` | `specs/radiation-components.md` |
| `SG` | `specs/soil-heat-flux.md` |
| `SH` | `specs/sensible-heat.md` |
| `ET` | `specs/evapotranspiration.md` |
| `AP` | `specs/anchor-pixels.md` |
| `WF` | `specs/weather-forcing.md` |
| `GW` | `specs/gwr-forcing.md` |
| `MP` | `specs/modis-products.md` |

Casos sin nombre propio en su especificación se nombran aquí: `NR-ref` y
`NR-d1…d4` (caso de referencia y casos derivados, en el orden de su tabla);
`RC-P` (presión), `RC-TE` (transmisividad simple por elevación),
`RC-cadena` (§7); `SH-14.x` (subsección de casos); `WF-O3` (caso
aritmético de §5.5) y `WF-D` (definición del día, §8.4). Al implementar,
estos nombres se trasladan a la especificación correspondiente.

#### 1.3.1 Ejemplos resueltos de FAO-56 como tests de referencia

Fuente: `weather-forcing.md` §8.1 (ecuaciones `VERIFICADA` contra la
edición abierta de FAO-56). Son los únicos casos del paquete que verifican
**física** contra una fuente primaria publicada; el resto verifica
aritmética de formas `CANDIDATA` o identidades. Columna "Esperado": valor
publicado por FAO-56 (redondeado). Para V14–V16 se indica además el valor
propio a precisión completa, usado como regresión; los demás valores
propios están en `weather-forcing.md` §8.1 y no se duplican.

| ID | Ejemplo FAO-56 | Entradas | Esperado (FAO-56) | Ecuaciones |
|---|---|---|---|---|
| WF-V1 | Ej. 2 | z = 1800 m | P = 81,8 kPa; γ = 0,054 kPa °C⁻¹ | 7, 8 |
| WF-V2 | Ej. 3 | Tmax = 24,5; Tmin = 15 °C | e°(Tmax) = 3,075; e°(Tmin) = 1,705; es = 2,39 kPa; e°(19,75) = 2,30 | 11, 12 |
| WF-V3 | Ej. 5 | Tmin = 18 °C, HRmax = 82 %; Tmax = 25 °C, HRmin = 54 % | e°(Tmin) = 2,064; e°(Tmax) = 3,168; eₐ = 1,70 (Ec. 17); 1,78 (Ec. 19) | 11, 17, 19 |
| WF-V4 | Ej. 6 | Las de V3 | es − eₐ = 0,91 kPa | 12, 17 |
| WF-V5 | Ej. 4 (opcional) | z = 1200 m; T_dry = 25,6; T_wet = 19,5 °C; a_psy = 0,000662 | eₐ = 1,91 kPa | 7, 11, 15, 16 |
| WF-V6 | Ej. 7 | 13°44'N; 22°54'S | +0,240; −0,400 rad | 22 |
| WF-V7 | Ej. 8 | 3 sep (J = 246), 20°S | dr = 0,985; δ = 0,120 rad; ωs = 1,527 rad; Ra = 32,2 MJ m⁻² d⁻¹ | 21–25 |
| WF-V8 | Ej. 9 | Las de V7 | N = 11,7 h | 34 |
| WF-V9 | Ej. 10–11 (parcial) | 22°54'S, 15 may (J = 135) | Ra = 25,1; N = 10,9 | 21, 34 |
| WF-V10 | Ej. 11 | Rs = 14,5; Rso = 0,75·25,1; Tmax = 25,1; Tmin = 19,1 °C; eₐ = 2,1 kPa | Rnl = 3,5 MJ m⁻² d⁻¹ | 39 |
| WF-V11 | Ej. 12 | Las de V10, α = 0,23 | Rn = 7,6 MJ m⁻² d⁻¹ | 38–40 |
| WF-V12 | Ej. 14 | u = 3,2 m s⁻¹ a 10 m | factor 0,75; u₂ = 2,4 m s⁻¹ | 47 |
| WF-V13 | Anexo 2, Tabla 2.9 | z = 2; 10 m | 1,000; 0,748 | 47 |
| WF-V14 | **Ej. 18 (ETo diaria)** | Uccle, 6 jul (J = 187), 50°48'N, 100 m; Tmax = 21,5; Tmin = 12,3 °C; HRmax = 84; HRmin = 63 %; u₁₀ = 10 km h⁻¹; n = 9,25 h | P = 100,1; Δ = 0,122; γ = 0,0666; u₂ = 2,078; es = 1,997; eₐ = 1,409; Ra = 41,09; N = 16,1; Rs = 22,07; Rso = 30,90; Rns = 17,00; Rnl = 3,71; Rn = 13,28; **ETo = 3,9 mm d⁻¹** (3,88). Propio: ETo = 3,8803 | 6, 7, 8, 11–13, 17, 21–24, 34, 35, 37–40, 42, 47 |
| WF-V15 | **Ej. 19 (ETo horaria), 14:00–15:00** | N'Diaye, 1 oct (J = 274), 16°13'N, 16°15'W, 8 m; Lz = 15, Lm = 16,25; T_hr = 38 °C; HR = 52 %; u₂ = 3,3 m s⁻¹; Rs = 2,450 MJ m⁻² h⁻¹ | Δ = 0,358; γ = 0,0673; e° = 6,625; eₐ = 3,445; dr = 1,0001; δ = −0,0753; b = 3,3315; Sc = 0,1889; ω = 0,682; ω₁ = 0,5512; ω₂ = 0,8130; Ra = 3,543; Rso = 2,658; Rns = 1,887; Rnl = 0,137; Rn = 1,749; G = 0,175; **ETo = 0,63 mm h⁻¹**. Propio: ETo = 0,6269 | 8, 11, 13, 22–24, 28–33, 37–40, 45, 53, 54 |
| WF-V16 | **Ej. 19, 02:00–03:00** | T_hr = 28 °C; HR = 90 %; u₂ = 1,9; Rs = 0; Rs/Rso = 0,8 (supuesto por el ejemplo) | Δ = 0,220; e° = 3,780; eₐ = 3,402; ω = −2,46 (Ra = 0); Rnl = 0,100; Rn = −0,100; G = −0,050; **ETo = 0,00 mm h⁻¹**. Propio: ETo = 0,0043 (publicado con tolerancia 0,005) | Las de V15 + 46 |
| WF-V17 | Cap. 3 / Anexo 3 | Tdew = 15 °C | eₐ = e°(15) (Ec. 14); propio: 1,70535 kPa; inversa Ec. 3-11 → 14,9926 °C | 14; 3-11 |

Reglas asociadas:

- V14–V16 son los tests de integración principales de la superficie de
  referencia (cadena completa).
- Las erratas de los ejemplos (`weather-forcing.md` §8.3) **no** se
  reproducen en los tests.
- Los casos WF-A1…A4 (`weather-forcing.md` §8.2: constantes ASCE-EWRI
  `CANDIDATA` con los insumos de V14–V16) verifican solo aritmética y no
  sustituyen un caso de verificación de ETr alfalfa, que requiere los
  ejemplos de ASCE-EWRI (2005) (`TODO`; no se afirma su contenido).
- Archivo: `test-weather.R` (derivadas) y `test-reference-et.R`
  (propuesto) o `test-et.R`, según WF-01.

#### 1.3.2 Casos calculados a mano por especificación

Se citan por ID; los valores viven en cada especificación (fuente única) y
no se duplican aquí. Advertencia común: salvo FAO-56 (§1.3.1), los casos
verifican la **aritmética de formas `CANDIDATA`**, no su validez científica,
y deben recalcularse cuando la forma pase a `VERIFICADA`
(`DEVELOPMENT.md` §3).

| Especificación | Casos (ID) | Qué cubren | Sección |
|---|---|---|---|
| `ef_net_radiation.md` | NR-ref (Rn = valor de referencia exacto); NR-d1…d4 (ε₀ = 1, α = 0 y ε₀ = 1, RL↓ = RL↑, nocturno) | Ecuación de Rn y formas equivalentes | §7 |
| `radiation-components.md` | RC-G1…G6 (geometría solar, laderas N/S, simetría E/O, ángulo horario, calendario); RC-P (presión z = 0 y 1000 m); RC-T1…T3 (transmisividad, incl. Andes); RC-TE (forma simple por elevación); RC-S1…S4 (Rs↓ plano, laderas, autosombra); RC-L1 y valores de ε_a(τ_sw); RC-O1, O2 (RL↑); RC-cadena (Rn integrado) | Componentes de Rn; terreno complejo | §6.1–6.6, §7 |
| `soil-heat-flux.md` | SG-B1…B6 (Bastiaanssen); SG-T1…T8 (Tasumi/METRIC); SG-W1 solo plantilla (no implementar) | G y G/Rn, bordes y ramas | §8 |
| `sensible-heat.md` | SH-14.1 (u_b, u*, rah neutral); SH-14.2 (P, ρ_air); SH-14.3 (calibración dT); SH-14.4 (un paso de estabilidad); SH-14.5 (iteración, propiedades 1–7; valores provisionales **no** son referencia); SH-14.6 (consistencia) | Rugosidad, rah, dT, H, iteración | §14 |
| `evapotranspiration.md` | ET-A (cadena completa y vuelta); ET-B (λ(T)); ET-C (LE negativo); ET-D (ETrF alta); ET-E (reciclaje y NA); ET-F (anclas de magnitud FAO-56); ET-P1…P5 (ET de período, spline) | LE, ET_inst, ETrF, ETa, ET de período | §10 |
| `anchor-pixels.md` | AP-P1 (12 celdas, cuantil tipo 7); AP-P1-q6 (tipo 6); AP-S1 (escena 15 × 15 con trampas) | Selección, embudo, dominio | §7.1–7.2 |
| `weather-forcing.md` | WF-V1…V17 (§1.3.1); WF-A1…A4 (aritmética `CANDIDATA`); WF-O3 (ETr_inst interpolada a la hora de paso); WF-D (día UTC vs local estándar, sintético) | Variables derivadas, ETo, ETr_inst, ETr24 | §5.5, §8 |
| `gwr-forcing.md` | GW-G1a (boxcar a mano); GW-G1b (gaussiano a mano); GW-G2 (ajuste completo y cruce con `GWmodel`); GW-G3 (k adaptativo); GW-G4 (límite OLS); GW-G5 (diseño singular); GW-G6 (dominio de AICc); GW-G7 (150 estaciones, integración) | Estimador local, LOO, AICc, bandwidth | §10 |
| `modis-products.md` | MP-S1…S10 (escalado y relleno); MP-Q1…Q5 (bits QA); MP-V1…V4 (view time → UTC); MP-N1 (NDVI); MP-G1 (agregación 2 × 2) | Conversión de productos | §6.2, §14 |

#### 1.3.3 Verificación cruzada con `GWmodel` (en `tests/`)

Decidido (`gwr-forcing.md` §1.2, §10; `decisions/gwr-backend.md`):

- `GWmodel` solo en `Suggests` (GPL ≥ 2; se **llama**, no se copia ni se
  empaqueta su código). Versión en CRAN observada el 2026-11-04: 2.4-1.
- Archivo `tests/testthat/test-gwr-crosscheck.R` con
  `testthat::skip_if_not_installed("GWmodel")`. Ningún otro test depende de
  paquetes externos: G1–G7, identidades y límites corren siempre.
- Casos: GW-G2 (coeficientes, RSS, AICc, `enp`, `edf`, `CV_Score`) y GW-G3
  (k adaptativo, k = 5); GW-G7 opcional bajo `EARTHFLUX_SLOW_TESTS` si su
  tiempo excede el presupuesto de CRAN (`TODO`: medir).
- Tolerancia relativa 10⁻¹⁰; el bandwidth **seleccionado** no se compara
  estrictamente (límites y tolerancias de búsqueda distintos), solo el
  criterio evaluado en un mismo bandwidth.

Convenciones que el test debe mapear explícitamente (resumen de
`gwr-forcing.md` §10; la tabla completa vive allí):

| Magnitud | Mapeo |
|---|---|
| tr S | `GWmodel` no la expone; su `enp` = 2 tr S − tr SᵀS |
| k adaptativo | Misma convención (cuenta el propio punto): `adaptive = TRUE, bw = k` |
| LOO por estación | `SDF$CV_Score` con `cv = TRUE` |
| R² local | `SDF$Local_R2` usa otra convención (ŷ global, media no ponderada): comparar con esa variante, no con el R² local por defecto de EarthFlux (GW-13) |
| Predicción | `gwr.predict(..., dMat1 = gw.dist(...))` (sin `dMat1` falla con n + N > 10 000) |
| Boxcar en d = b | Peso 1 en ambos |
| `bw.gwr()` adaptativo | Límite inferior fijo en 20: no comparar bandwidths seleccionados con n pequeño |
| `gwr.cv()` sin matriz de distancias | Falló en la evaluación (`DM.given`); usar `CV_Score` |

#### 1.3.4 Invariantes

Propiedades que deben cumplirse con cualquier dato válido; se testean
sobre grillas de valores o escenas sintéticas, además de los casos de
§1.3.2.

| Invariante | Formulación | Alcance y limitación | Fuente | Archivo |
|---|---|---|---|---|
| Identidad del balance | `ef_latent_heat(rn, g, h) + g + h == rn` (signos mixtos) | Solo verifica la implementación (orden y signo de argumentos); casi tautológica | ET §11.2, §11.4.1 | `test-latent-heat.R` (propuesto) |
| Ida y vuelta LE → ET → LE | Grilla LE × λ; `et_inst_to_latent_heat(ef_et_instantaneous(le, λ), λ) = le` (relativa `sqrt(eps)`) | No detecta un error de escala compartido por ambas conversiones: va **siempre** acompañada de ET-F | ET §11.3, §11.4.2 | `test-et.R` |
| Anclas reproducen sus objetivos | dT = a + b·Ts_datum exacto en las anclas (10⁻¹²); H = H_target tras la convergencia (10⁻⁹) y tras la Fase B; ETrF_frío = k y ETrF_caliente = 0 en la cadena completa (`sqrt(eps)`), solo si anclas y conversión usan la misma λ | Requiere módulos de anclas, H y ET integrados | SH §14.5–14.6; ET §11.4.3 | `test-sensible-heat.R`, `test-pipeline.R` |
| Cancelación de un sesgo multiplicativo común de ETr en la extrapolación | `ef_et_daily(ef_etrf(et_inst, c·etr_inst), c·etr_24) = ef_et_daily(ef_etrf(et_inst, etr_inst), etr_24)` para c > 0 (relativa `sqrt(eps)`) | Válida **solo** para el paso de extrapolación con ET_inst fija; en METRIC completo ETr_inst también cambia la calibración del ancla fría (no es invariante) | ET §6.5 | `test-et.R` |
| Secuencial = paralelo | `future::plan(sequential)` vs `plan(multisession, workers = 2)`: `identical()` en superficies, flags y diagnósticos | Máximo 2 workers en tests; semillas con `future.seed` donde hay azar | `ARCHITECTURE.md` §6.3; GW §8.4; SH §14.5 (prop. 7); AP §7.3–7.4; ET §11.5 | todos los que paralelicen |
| Tamaño de bloque | Resultado por bloques de filas = resultado de una pasada (varios tamaños) | Envoltorios `terra` y predicción GWR por bloques | `ARCHITECTURE.md` §6.6; GW §11; SH §14.5 (prop. 7); AP §7.3; MP §14 | `test-gwr-predict.R`, `test-modis.R`, `test-anchors.R` |
| Vector ≡ `SpatRaster` | La misma función sobre `numeric` y sobre un `SpatRaster` pequeño da el mismo resultado | Núcleo aritmético independiente del contenedor | WF §8.4; MP §14; AP §7.3; RC §6.4–6.6 | por componente |
| Orden de estaciones | Permutar filas → mismas predicciones (relativa 10⁻¹²) | — | GW §8.3 | `test-gwr-fit.R` |
| Límite OLS de GWR | Boxcar con b mayor que toda distancia = OLS (`sqrt(eps)`); gaussiano: error monótono decreciente en b | — | GW-G4 | `test-gwr-fit.R` |
| Atajo LOO | e₋ᵢ = eᵢ/(1 − s_ii) = LOO por definición | No definido si s_ii = 1 → `NA` + flag | GW §4.3 | `test-gwr-bandwidth.R` |
| Kernel pedido = kernel usado | El objeto registra kernel, tipo y valor de bandwidth efectivos | Lección del antecedente (kernel declarado y no transmitido) | `decisions/antecedente-metric-modis.md` §2.6; GW §11 | `test-gwr-kernel.R` |
| Interfaz común C1/C2/C3 | `station`, `global_ols`, `idw`, `gwr` devuelven la misma estructura `earthflux_surface` | Condición para que los experimentos de la parte 2 solo cambien `method` | GW §5.1, §11 | `test-regionalize.R` |
| Determinismo y estado del RNG | Dos llamadas idénticas → `identical()`; `.Random.seed` del usuario sin cambios | Semilla obligatoria solo donde hay azar | AP §5.4, §7.3–7.4; GW §6.5 | `test-anchors.R`, `test-gwr-*.R` |
| Manual ≡ automático | `ef_anchors()` con las celdas de `ef_select_anchors()` reproduce `pixels` y `calibration_points` | — | AP §7.5 | `test-anchors.R` |
| Invariancias de calibración | Datum de elevación (dos z_datum → mismo H); c_p en neutral con rah fijo | — | SH §14.6 | `test-sensible-heat.R` |
| Propiedades de selección de anclas | Agregar celdas `NA`/agua o cambiar variables no usadas no cambia las anclas | — | AP §7.7 | `test-anchors.R` |
| Sin truncamiento | ET_inst, ETrF, ETa, G/Rn negativos o fuera de rango se devuelven sin cambios y con flag | Principio 6 de `ARCHITECTURE.md` | ET §11.3; SG §9.5; WF §8.4 | por componente |
| Pipeline | `earthflux()` ≡ cadena explícita de `ef_*()` con la misma configuración | M5 | ET §11.4.4 | `test-pipeline.R` |

#### 1.3.5 Verificación cruzada con `water` (fuera del tarball)

- Script en `inst/verification/` (patrón de `thermify`,
  `ARCHITECTURE.md` §6.6) que use `water` solo si está instalado. `water`
  es GPL: no se copia ni se empaqueta su código. En CRAN figura archivado
  (`REFERENCES.md`, "Related software").
- Las diferencias se documentan y explican (constantes, formulaciones
  alternativas, orden de operaciones); no se fuerza la coincidencia. Las
  diferencias esperadas ya están listadas por componente: RC §8; SH §17;
  ET §11.6; AP §7.8; WF §8.4 (último punto).

#### 1.3.6 Trazabilidad especificación → archivo de test

Estado de los archivos observado en `tests/testthat/` el 2026-11-04:
"con tests" = contiene tests implementados; "placeholder" = existe con un
único test pendiente; "propuesto" = nombrado en una especificación, aún no
creado. Los nombres propuestos están sujetos a las decisiones citadas.

| Especificación | Casos / invariantes | Archivo(s) | Estado |
|---|---|---|---|
| `ef_net_radiation.md` | NR-ref, NR-d1…d4; dominio, NA, clases | `test-radiation.R` | con tests |
| (transversal) | Helpers de validación (`check_*()`, `ef_abort()`) | `test-utils.R` | con tests |
| (transversal) | Registro de flags, `ef_flag()` | `test-diagnostics.R` | con tests |
| `radiation-components.md` | RC-G1…G6, RC-P, RC-T1…T3, RC-TE, RC-S1…S4, RC-L1, RC-O1…O2, RC-cadena | `test-radiation.R` y/o `test-solar-geometry.R` (a decidir, RC §6.1) | placeholder / propuesto |
| `soil-heat-flux.md` | SG-B1…B6, SG-T1…T8; bordes, NA, flags | `test-soil-heat.R` | placeholder |
| `sensible-heat.md` | SH-14.1, SH-14.4 (z_om, viento, u*, rah, estabilidad) | `test-aerodynamics.R` | placeholder |
| `sensible-heat.md` | SH-14.2, SH-14.3, SH-14.5, SH-14.6 | `test-sensible-heat.R` | placeholder |
| `sensible-heat.md` | Cruce con `water` | `inst/verification/` | propuesto |
| `evapotranspiration.md` | ET-A1, ET-C1; identidad del residuo | `test-latent-heat.R` | propuesto |
| `evapotranspiration.md` | ET-A…F; ida y vuelta; cancelación del sesgo común de ETr | `test-et.R` | placeholder |
| `evapotranspiration.md` | ET-P1…P5 | `test-et-period.R` | propuesto (cuando se implemente) |
| `anchor-pixels.md` | AP-P1, AP-P1-q6, AP-S1; determinismo; semillas; manual ≡ automático; propiedades | `test-anchors.R` | placeholder |
| `weather-forcing.md` | Contrato, QC (§3.2), WF-V1…V13, WF-V17 | `test-weather.R` | placeholder |
| `weather-forcing.md` | WF-V14…V16, WF-A1…A4, WF-O3, WF-D | `test-reference-et.R` o `test-et.R` (WF-01) | propuesto |
| `gwr-forcing.md` | Kernels; kernel pedido = usado | `test-gwr-kernel.R` | propuesto (hoy `test-gwr.R`, placeholder) |
| `gwr-forcing.md` | GW-G1a, G1b, G2, G4, G5; orden de estaciones | `test-gwr-fit.R` | propuesto |
| `gwr-forcing.md` | GW-G3, G6; búsqueda; atajo LOO; pocas estaciones | `test-gwr-bandwidth.R` | propuesto |
| `gwr-forcing.md` | Predicción; tamaño de bloque; flags de extrapolación | `test-gwr-predict.R` | propuesto |
| `gwr-forcing.md` | Objeto `earthflux_gwr`; R² local | `test-gwr-diagnostics.R` | propuesto |
| `gwr-forcing.md` | Interfaz común C1/C2/C3; pliegues de CV idénticos | `test-regionalize.R` | propuesto |
| `gwr-forcing.md` | Cruce con `GWmodel` (G2, G3, G7 opcional) | `test-gwr-crosscheck.R` | propuesto |
| `modis-products.md` | MP-S1…S10, MP-Q1…Q5, MP-V1…V4, MP-N1, MP-G1 | `test-modis.R` | placeholder |
| (integración) | Anclas reproducen objetivos; `earthflux()` ≡ cadena; secuencial = paralelo de extremo a extremo | `test-pipeline.R` | placeholder |

Regla de mantenimiento: al implementar una función, su especificación,
esta tabla y los IDs de los `test_that()` se actualizan en el mismo
cambio; un caso sin test o un test sin caso se marca en la revisión.

### 1.4 Restricciones CRAN

Sin internet, sin credenciales, sin descargas, tiempos cortos, escritura solo
en `tempdir()`, datos de ejemplo pequeños, como máximo 2 núcleos
(`ARCHITECTURE.md` §6.3). Tests con paquetes de `Suggests` se omiten si el
paquete no está instalado; tests largos o con datos externos, detrás de
`EARTHFLUX_SLOW_TESTS` / `EARTHFLUX_ONLINE_TESTS` (`ARCHITECTURE.md` §6.6).

---

## 2. Scientific validation

### 2.1 Hipótesis, principio y condiciones previas

> H1 (`SCIENTIFIC_SPEC.md` §1.1): representar espacialmente el forzamiento
> meteorológico de METRIC mediante GWR, en lugar de una única estación
> considerada representativa, reduce el error de ETa frente a observaciones
> independientes.

- H1 **no se asume verdadera**. Un resultado nulo, inconcluso o contrario
  es un resultado científico válido y se reporta con el mismo detalle.
- **Pre-registro.** Antes de comparar cualquier ETa con observaciones de
  validación se congela (fecha y hash de commit en el repositorio de
  experimentos) un documento con: configuraciones, factores y niveles,
  configuración base, métrica primaria, contrastes primarios, δ_min, α,
  reglas de exclusión de sitios/fechas, tratamiento del cierre de EC,
  criterios de footprint y partición de fechas. Toda desviación posterior
  queda en un registro de desviaciones con su motivo.
- **Partición temporal.** Las fechas se dividen en un conjunto de
  desarrollo (ajuste de elementos de diseño: tamaño de bloque L de la CV,
  definición del conjunto de anclas, Δ de k) y un conjunto de confirmación
  (solo evaluación). Regla de partición y fechas: `TODO` en el pre-registro.
- **Condiciones previas (bloqueantes para M6):** parte 1 completa para las
  funciones de la cadena; decisión SH-11 resuelta (bloqueante en
  `sensible-heat.md`); referencia de ETr decidida: METRIC usa alfalfa
  (`weather-forcing.md` §5.1), pero ETr ASCE-EWRI es `CANDIDATA` y hoy solo
  ETo FAO-56 (pasto) es implementable (`weather-forcing.md` §5.4); el
  coeficiente del ancla fría depende de esa referencia (`anchor-pixels.md`
  §2.2). Toda forma `CANDIDATA` usada en M6 queda listada con su estado en
  el registro de reproducibilidad (§2.10).

### 2.2 Configuraciones de forzamiento

Todas comparten la interfaz común de `gwr-forcing.md` §5.1 (misma entrada,
salida `earthflux_surface`; solo cambia `method`), y se mantienen
constantes: producto y colección MODIS, plataforma, escenas y fechas,
QA, grilla, MDE, reglas o conjunto de anclas, parámetros de METRIC,
conjunto de estaciones disponibles y política de QC.

| Config. | `method` | Requerida | Especificación de la configuración en el experimento |
|---|---|---|---|
| **C1** | `"station"` | Sí | Superficie constante igual a la estación representativa. La estación primaria se elige con una regla fijada en el pre-registro, sin mirar datos de validación (`gwr-forcing.md` §5.3: sin elección automática por defecto). Variante C1-ens: cada estación elegible como representativa (distribución de resultados; ver §2.4) |
| C1-lapse | `"station_lapse"` | Opcional | C1 con gradiente vertical Γ para `air_temperature` (valor con fuente y estado; `TODO`) |
| **C2-OLS** | `"global_ols"` | Sí | Regresión lineal global con las **mismas** covariables que C3; con `elevation` como covariable mínima. Separa el aporte de la no estacionariedad (GWR) del aporte de las covariables (`gwr-forcing.md` §5.4) |
| **C2-IDW** | `"idw"` | Sí | IDW sin covariables; `power` seleccionado por LOOCV en una rejilla registrada o fijado en el pre-registro (sin defecto, `gwr-forcing.md` §5.4) |
| C2-KED | `"ked"` | Opcional (posterior) | Kriging con deriva externa / regresión-kriging; requiere especificación de variograma propia (`gstat` en `Suggests`) |
| C2-grid | `"gridded"` | Opcional (posterior) | Reanálisis u otro producto grillado entregado por el usuario como `SpatRaster`; remuestreo registrado; ajuste por elevación opcional con Γ explícito. Disponibilidad y licencias para Chile: `TODO` |
| **C3** | `"gwr"` | Sí | GWR con kernel, tipo de bandwidth y criterio fijados en el pre-registro (GW-04, GW-05; sin defecto en el núcleo); bandwidth por ajuste (GW-11) |

Variables regionalizadas: `air_temperature`, `vapour_pressure`, `clearness`
(o `solar_radiation`) y, según la decisión 5.1, `etr_inst` y `etr_24`. El
viento de altura de mezcla se mantiene como escalar de estación en todas
las configuraciones (decisión por defecto de `sensible-heat.md` §6, SH-05);
Rs↓ de METRIC usa el camino modelado de cielo despejado por defecto
(RC-10). Con esto, en la configuración base el forzamiento espacial entra
por ETr_inst en el ancla fría, ETr24 y RL↓ (y ε_a si se usa Brutsaert);
los otros puntos de entrada de `SCIENTIFIC_SPEC.md` §1.2 (Rs↓, viento) se
dejan para una extensión registrada.

### 2.3 Factores de sensibilidad

| Factor | Niveles | Fuente | Qué separa | Observaciones |
|---|---|---|---|---|
| **B. Covariables** (GW-07) | S: independientes de la superficie (`elevation`, `distance_to_coast`) · S+LST | `gwr-forcing.md` §2.7 | Efecto de usar LST como covariable de Ta | Solo aplica a métodos con covariables (C2-OLS, C2-KED, C3). La evidencia previa del autor (Galdón-Ruíz et al., 2023) indica capacidad predictiva de LST para **medias mensuales** de Tmin/Tmax; no resuelve el acoplamiento con dT ni la escala instantánea. Diagnósticos obligatorios de §2.7 de esa especificación |
| **C. Decisión 5.1** | A: calcular y luego interpolar (ETr_inst, ETr24 regionalizadas) · C: híbrida (P, Ra, Rso exactos por píxel; regionalizar T, eₐ, Rs/Rso) | `weather-forcing.md` §6 | No linealidad vs coherencia ancla–ETr24 | B pura queda fuera del diseño base (opcional). En A, Ta y eₐ se regionalizan igualmente para RL↓/ε_a: A solo cambia cómo se obtiene ETr |
| **D. Temperatura de RL↓** (RC-12) | (a) Ta del forzamiento · (b) Ts del ancla fría | `radiation-components.md` §6.5.B | Si el forzamiento entra en RL↓ | (c) Ts por píxel solo para el cruce con `water`, no en el diseño |
| **E. Emisividad atmosférica** (RC-13) | τ: 0,85·(−ln τ_sw)^0,09 (`CANDIDATA`) · Bru: forma de Brutsaert en eₐ y Ta con coeficiente calibrado explícito | `radiation-components.md` §6.5.A | Forma empírica en τ vs forma conectada al forzamiento | Evidencia previa del autor (Morales-Salinas et al., 2023): coeficiente variable en el tiempo y el espacio. Forma, coeficientes por zona y fuente original: `TODO: verify` antes de M6. Con Bru, eₐ y Ta del forzamiento entran en ε_a con cualquier nivel de D |
| **F. Coeficiente del ancla fría** k | k_ref − Δ · k_ref · k_ref + Δ | `anchor-pixels.md` §2.2, D-AP-04 | Sensibilidad de la calibración | k_ref = valor verificado en Allen et al. (2007) (hoy `CANDIDATA` 1,05, ligado a la referencia alfalfa, `TODO`). Δ fijado en el pre-registro. El valor 0,5 del antecedente del autor (`antecedente-metric-modis.md` §2.3) se registra como caso diagnóstico, no como nivel |
| **Conjunto de anclas** (Q-AP-08) | M miembros: selecciones alternativas dentro del conjunto de candidatos aceptables (enumeración determinista de presets o pares; o muestreo con `seed` explícita) | `anchor-pixels.md` §4, §5.4 | Incertidumbre de calibración | No es un factor con niveles fijos: cada configuración se evalúa sobre **los mismos** M miembros (comparación pareada dentro de miembro). M: `TODO` (pre-registro) |
| **Variante de anclas** | (i) mismas celdas en C1–C3 · (ii) mismas reglas | `anchor-pixels.md` §2.4 | Efecto vía ETr_inst solo vs vía selección | La selección [A] usa solo variables de superficie: sin restricción de radio a la estación (D-AP-11), (i) y (ii) coinciden. Se distinguen solo si se activa esa restricción; entonces se corren ambas |

### 2.4 Diseño experimental

El diseño se organiza en tres bloques para mantener tractable el número de
corridas y para que cada pregunta tenga un contraste propio. "Corrida" =
una configuración completa de METRIC sobre una escena, para un miembro del
conjunto de anclas.

**Configuración base** (pre-registrada; propuesta provisional, no
decisión): B = S; C = C (recomendación provisional de
`weather-forcing.md` §6); D = (a) (única opción en que el forzamiento entra
en RL↓); E = τ (recomendación provisional de RC-13); k = k_ref; viento de
altura de mezcla escalar; Rs↓ modelado.

**Bloque A — contraste principal (responde H1).** Factor único: método de
forzamiento, con todo lo demás en la base.

| Niveles | Requeridos | Opcionales |
|---|---|---|
| C1, C2-OLS, C2-IDW, C3 | 4 | C1-lapse, C2-KED, C2-grid (+3) |
| C1-ens (cada estación elegible como representativa) | S_e − 1 adicionales | — |

**Bloque B — descomposición por punto de entrada** (`weather-forcing.md`
§6 punto 3; `SCIENTIFIC_SPEC.md` §1.2). Factorial completo 2³ sobre la
fuente de cada entrada ∈ {C1, C3}, con la base para lo demás:

| Factor | Entrada | Niveles |
|---|---|---|
| E1 | ETr_inst en el ancla fría (calibración) | C1 · C3 |
| E2 | ETr24 en la extrapolación diaria | C1 · C3 |
| E3 | Ta (y eₐ si E = Bru) en RL↓ | C1 · C3 |

8 configuraciones, de las cuales 2 coinciden con el bloque A (todo C1 =
C1; todo C3 = C3): **6 nuevas**. Requiere `method` por variable (enmienda
A4 de `gwr-forcing.md` §2.5). Con la opción C de la decisión 5.1, mezclar
fuentes para E1 y E2 rompe la coherencia ancla–ETr24 que C da por
construcción: es justamente lo que el bloque mide. Lectura esperada del
álgebra de `evapotranspiration.md` §6.5 (no un resultado): un sesgo
multiplicativo común de ETr se cancela en la extrapolación, de modo que E2
actúa a través de la variación espacial del cociente ETr24/ETr_inst y E1 a
través de H en el ancla fría (`anchor-pixels.md` §2.5).

**Bloque C — robustez del contraste ante decisiones de modelado.** Dos
fracciones factoriales a dos niveles (Box & Hunter, 1961), con k en
k_ref ± Δ (los bloques A y B, en k_ref, actúan como puntos centrales solo
para k):

| Fracción | Factores (2 niveles) | Diseño | Corridas | Qué estima |
|---|---|---|---|---|
| C-I | M: {C2-OLS, C3}; B; C; D; E; F | 2⁶⁻¹, resolución VI, generador F = MBCDE (I = MBCDEF) | 32 | Efectos principales e interacciones de dos factores sin alias entre sí (alias con interacciones de 4 y 5 factores). Interés: M×B, M×C, M×D, M×E, M×F (¿depende la diferencia GWR vs OLS de estas decisiones?) |
| C-II | M′: {C1, C3}; C; D; E; F (B = S) | 2⁵⁻¹, resolución V, generador F = M′CDE (I = M′CDEF) | 16 | Ídem para el contraste de H1; B no se incluye porque C1 no tiene covariables |

**Número de corridas.**

| Bloque | Configuraciones únicas |
|---|---|
| A (requeridas) | 4 |
| B (nuevas) | 6 |
| C-I + C-II | 48 |
| **Total requerido** | **58** |
| Opcionales | +3 (bloque A) y + (S_e − 1) (C1-ens) |

Corridas de METRIC = 58 × D × M (D = escenas de confirmación; M =
miembros del conjunto de anclas), más las opcionales. D, M y S_e: `TODO`
(pre-registro; dependen del área de estudio, §2.11). El costo dominante
(ajustes de forzamiento) no escala con M ni con D/E/F: por fecha se
necesitan 12 conjuntos de superficies — {C1, C2-OLS-S, C2-OLS-S+LST,
C2-IDW, C3-S, C3-S+LST} × {A, C} — que se calculan una vez y se reutilizan
en todas las corridas (procedencia con hash de configuración). Tiempos:
`TODO` (medir con el benchmark de `dev/`, `ARCHITECTURE.md` §6.3).

### 2.5 Comparaciones que responden H1

| Tipo | Contraste | Bloque | Pregunta |
|---|---|---|---|
| **Primario** | Δ₁ = error(C3) − error(C1) | A | H1 tal como está formulada |
| Co-primario | Δ₂ = error(C3) − error(C2-OLS) | A | ¿El efecto es atribuible a la no estacionariedad (GWR) y no solo a las covariables? |
| Co-primario | Δ₃ = error(C3) − error(C2-IDW) | A | ¿El efecto es específico de GWR frente a una interpolación espacial sin covariables? |
| Secundario | Efectos de E1, E2, E3 y sus interacciones | B | ¿Por qué vía actúa el forzamiento (calibración, extrapolación, RL↓)? |
| Secundario | Interacciones M×{B, C, D, E, F} y M′×{C, D, E, F} | C | ¿El signo y la magnitud de Δ₁ y Δ₂ dependen de decisiones de modelado? |
| Secundario | Distribución de Δ₁ sobre C1-ens | A | ¿Cuánto depende el resultado de la estación elegida como representativa? |
| Exploratorio | C2-KED, C2-grid, C1-lapse | A | Alternativas adicionales |

"Error" = métrica primaria (§2.8) de ETa diaria en los sitios de
validación del nivel N3 (§2.6). Las diferencias se calculan **pareadas**:
mismos sitios, fechas, miembros del conjunto de anclas y pliegues.

### 2.6 Niveles de evaluación

La evaluación se separa en tres niveles (`SCIENTIFIC_SPEC.md` §1.2). Una
mejora en N1 **no** cuenta como evidencia de H1: con LST como covariable,
la CV del forzamiento puede mejorar mientras los errores de LST se
propagan de forma correlacionada a Ta y a dT (`gwr-forcing.md` §2.7 punto
3), y el sesgo común de ETr se cancela en la extrapolación
(`evapotranspiration.md` §6.5).

**N1 — Forzamiento en estaciones (validación cruzada).**

- Variables: `air_temperature`, `vapour_pressure`, `clearness` (o
  `solar_radiation`), y ETr_inst, ETr24 en la estación omitida (con la
  opción C, recalculadas con los insumos predichos del mismo pliegue,
  `gwr-forcing.md` §8.2).
- Esquemas: LOOCV (condicional al bandwidth; `gwr-forcing.md` §8.1) y CV
  por bloques espaciales con teselas deterministas de lado L y
  re-selección del bandwidth dentro del entrenamiento (`gwr-forcing.md`
  §8.2; Roberts et al., 2017). L se justifica con la escala de
  autocorrelación de residuos (GW-20) en el conjunto de desarrollo y se
  reporta con al menos un valor adicional como sensibilidad (`TODO`).
- Los **mismos pliegues** para todos los métodos y variables. C1: error en
  las demás estaciones, excluida la representativa (`gwr-forcing.md` §5.3).
- Se reporta la diferencia LOOCV − bloques como indicador de optimismo, y
  los pliegues fallidos (no se omiten en silencio).
- Estaciones de validación de N3 con meteorología propia: excluidas del
  conjunto de ajuste del forzamiento en la evaluación primaria
  (independencia); su inclusión, como sensibilidad.

**N2 — Efecto en la calibración.** Sin observaciones en las anclas, se
mide como diferencia entre configuraciones (pareada por escena y miembro):
ETr_inst en las celdas ancla; H_frío y H_caliente; coeficientes (a, b) de
dT; rah en las anclas; convergencia; flags (`EF_ANCHOR_FORCING_EXTRAPOLATED`,
`EF_ANCHOR_COLD_H_NEGATIVE`, `EF_H_NOT_CONVERGED`); campo de ETrF. Cuando
una estación (no usada en el ajuste) cae en la celda de un ancla, ETr_inst
se compara además con la calculada en esa estación.

**N3 — ETa frente a observaciones independientes.**

- Primaria: ETa diaria (mm d⁻¹) en las fechas con escena válida, contra EC
  y lisímetros (§2.7).
- Secundaria instantánea: LE (o ET_inst) a la hora de paso del píxel contra
  el intervalo de EC que la contiene (diagnóstico de la etapa instantánea,
  separado de la extrapolación).
- Secundaria agregada: ET de período (`ef_et_period()`, ET-D8) a escala
  mensual/anual contra balance hídrico de cuencas. La interpolación temporal
  entre fechas añade un error propio, común a todas las configuraciones
  (se compara pareado).

### 2.7 Fuentes de datos de validación

| Fuente | Escala | Uso | Problemas a tratar |
|---|---|---|---|
| Torres eddy covariance | Footprint de cientos de metros; 30 min | N3 primaria y secundaria instantánea | Cierre del balance; footprint vs píxel |
| Lisímetros de pesada | Puntual (m²) | N3 primaria donde existan | Representatividad aún menor que EC; solo en campos homogéneos extensos |
| Balance hídrico de cuencas | Cuenca; mensual/anual | N3 secundaria agregada | ET ≈ P − Q − ΔS: errores de precipitación (orografía), almacenamiento, aguas subterráneas e intervención antrópica |
| Productos de ET de terceros | Grilla | **Solo intercomparación**, nunca validación | No son observaciones independientes; comparten supuestos y forzamientos |

**Escala: footprint vs 1 km.** La celda MODIS de "1 km" mide
926,625433 m de lado (`modis-products.md` §4), ≈ 85,9 ha. Ejemplo de la
magnitud del problema (no un resultado): la parcela con EC descrita por
Carrasco-Benavides et al. (2014) tiene 4,25 ha (≈ 5 % de una celda).
Procedimiento pre-registrado:

1. Footprint por intervalo a la hora de paso con un modelo de footprint
   (p. ej., FFP, Kljun et al., 2015; contenido no leído, `TODO: verify`) y
   climatología de footprint del período.
2. Representatividad de la celda: fracción de la celda cubierta por la
   cobertura del footprint (mapa de cobertura local o MCD12Q1), dispersión
   de NDVI subpíxel de 250 m (Q-AP-04 de `anchor-pixels.md`), y diferencia
   entre la celda y la media de 3 × 3.
3. Criterios de exclusión o ponderación de sitios por representatividad:
   umbrales `TODO` en el pre-registro (sin defecto). Los sitios excluidos y
   el motivo se reportan.

**Cierre del balance de energía en EC.** El cierre micrometeorológico es un
asunto de validación, distinto de la calibración interna
(`SCIENTIFIC_SPEC.md` §2.1). Se reporta por sitio la razón de cierre
(H + LE)/(Rn − G) (Wilson et al., 2002) y se evalúan tres variantes de la
observación:

| Variante | Tratamiento | Comentario |
|---|---|---|
| EC-raw | LE medido sin corregir | Probable subestimación de la energía turbulenta |
| EC-BR | Cierre forzado conservando la razón de Bowen (Twine et al., 2000) | Supone que el déficit se reparte como H/LE |
| EC-res | LE = Rn − G − H medidos | Estructura de residuo análoga a METRIC: atribuye todo el déficit a LE |

La variante primaria se fija en el pre-registro (`TODO`); las otras dos se
reportan como sensibilidad, y la conclusión sobre H1 se acompaña de su
estabilidad entre variantes. Control de calidad de los flujos y relleno de
huecos de EC: se usan los del proveedor si están documentados; el
procesamiento propio, si existe, queda en el registro (§2.10).

### 2.8 Métricas, incertidumbre y comparación pareada

Notación: Pᵢ estimado, Oᵢ observado, i = 1…n pares (sitio, fecha).

| Métrica | Definición | Rol |
|---|---|---|
| **RMSE** | √(Σ(Pᵢ − Oᵢ)²/n) [mm d⁻¹] | **Métrica primaria** (pre-registrada) |
| MAE | Σ\|Pᵢ − Oᵢ\|/n | Secundaria; robusta a extremos |
| Bias (MBE) | Σ(Pᵢ − Oᵢ)/n (positivo = sobreestimación) | Secundaria; sesgo sistemático |
| R² | Cuadrado del coeficiente de correlación de Pearson entre P y O | Secundaria; asociación lineal (no mide exactitud) |
| KGE | 1 − √((r − 1)² + (α − 1)² + (β − 1)²), α = σ_P/σ_O, β = μ_P/μ_O | Secundaria; forma `CANDIDATA` atribuida a Gupta et al. (2009) (contenido no leído, `TODO: verify`); la variante modificada atribuida a Kling et al. (2012) solo si se verifica |
| Willmott d | 1 − Σ(Pᵢ − Oᵢ)² / Σ(\|Pᵢ − Ō\| + \|Oᵢ − Ō\|)² | Secundaria; forma `CANDIDATA` a verificar en Willmott (1981) |

Incertidumbre y comparación pareada:

- **Bootstrap por conglomerados** (Efron, 1979, para el bootstrap; el
  esquema por conglomerados se fija en el pre-registro): se remuestrean
  sitios y, dentro de cada sitio, bloques de fechas (para respetar la
  autocorrelación temporal; tamaño de bloque `TODO`); con M > 1, también los
  miembros del conjunto de anclas. Número de réplicas B: `TODO`, con
  comprobación de estabilidad del intervalo (p. ej., duplicar B).
- **Pareado:** en cada réplica se calcula la métrica de cada configuración
  sobre los **mismos** pares remuestreados y se toma la diferencia (Δ₁, Δ₂,
  Δ₃); el intervalo es el de la distribución de diferencias, no la
  comparación de intervalos separados.
- **Pocos sitios.** Con un número pequeño de sitios el bootstrap por sitio
  es poco fiable; se reportan además los resultados por sitio y un análisis
  dejando un sitio fuera. El número mínimo de sitios para usar el bootstrap
  por sitio como intervalo primario: `TODO` (pre-registro).
- **Multiplicidad:** tres contrastes primarios/co-primarios; intervalos
  ajustados por Bonferroni (nivel 1 − α/3). Alternativa menos conservadora:
  Holm (cita `TODO: verify full citation`).
- **Precisión esperada:** análisis de potencia o de ancho esperado del
  intervalo con datos de desarrollo (no de confirmación): `TODO`.

### 2.9 Criterios de apoyo o rechazo de H1 (pre-registrados)

δ_min: diferencia mínima relevante de RMSE de ETa diaria [mm d⁻¹], fijada
en el pre-registro antes de ver los datos de confirmación (`TODO`). Con
IC = intervalo de confianza ajustado de Δ₁ (configuración base, promedio
sobre los M miembros):

Las condiciones se evalúan en el orden de la tabla y se aplica la primera
que se cumple:

| Orden | Resultado | Condición | Lectura |
|---|---|---|---|
| 1 | Apoyo a H1 | IC completamente < 0 y Δ̂₁ ≤ −δ_min | C3 reduce el error de forma estadística y prácticamente relevante |
| 2 | Evidencia contraria | IC completamente > 0 | C3 aumenta el error: H1 se rechaza |
| 3 | Equivalencia práctica | IC ⊂ (−δ_min, δ_min) | No hay diferencia relevante: H1 no se apoya |
| 4 | Diferencia no relevante | IC completamente < 0 y Δ̂₁ > −δ_min | Mejora estadística sin relevancia práctica demostrada: H1 no se apoya en su forma práctica |
| 5 | Inconcluso | Cualquier otro caso | Datos insuficientes; no es evidencia a favor ni en contra |

Calificadores (se reportan siempre; no cambian la clasificación primaria):

- Atribución: Δ₂ y Δ₃ con la misma tabla. "Apoyo a H1" con Δ₂ inconcluso o
  equivalente indica que la mejora no es atribuible a GWR frente a una
  regresión global con las mismas covariables.
- Robustez: signo y clasificación de Δ₁ en cada miembro del conjunto de
  anclas, en cada variante de cierre de EC, en C1-ens y en el espacio del
  bloque C. Si el signo cambia dentro del espacio explorado, el resultado
  se reporta como **dependiente de la configuración**, identificando las
  interacciones responsables.
- N1 y N2 se reportan como mecanismo, no como criterio de apoyo.

### 2.10 Registro de reproducibilidad

Para cada corrida (`DEVELOPMENT.md` §7; `gwr-forcing.md` §2.4, §8.3):

- Versiones: EarthFlux (commit), R, `terra`, `GWmodel` y demás paquetes
  (archivo de bloqueo del entorno del repositorio de experimentos;
  `renv`, `ARCHITECTURE.md` §6.5).
- Datos: producto, colección, plataforma, tiles, fechas, identificadores de
  gránulos, view time por píxel, máscaras QA; MDE y cobertura; estaciones
  usadas y excluidas con motivo; política de QC; observaciones de
  validación (versión del archivo del proveedor, procesamiento, variante de
  cierre, footprint).
- Configuración: hash de configuración por corrida; método por variable;
  covariables y su fuente; kernel, tipo y valor de bandwidth, criterio;
  pliegues de CV (L, origen, asignación); decisión 5.1; RC-12; RC-13 con
  coeficientes; k; criterios y miembro del conjunto de anclas; estado
  (`VERIFICADA`/`CANDIDATA`) de cada forma usada.
- Azar: semillas, `RNGkind()`, `future.seed`; resultado secuencial =
  paralelo (§1.3.4).
- Intermedios: superficies de forzamiento, anclas y embudo, (a, b), H,
  ETrF, ETa, flags; tablas de pares (sitio, fecha, configuración,
  observado, estimado).
- Documentos: pre-registro congelado (fecha, hash) y registro de
  desviaciones.

### 2.11 Áreas de estudio candidatas en Chile (`TODO`)

Criterios de selección: (1) densidad y distribución de estaciones con las
variables de ETr frente a los mínimos de GWR (`gwr-forcing.md` §4.5–4.6;
riesgo con 10–30 estaciones); (2) observaciones independientes de ET con
acceso verificado; (3) candidatos a anclas a 1 km (Q-AP-02); (4) gradiente
de terreno y distancia a la costa que justifique un forzamiento espacial;
(5) licencias que permitan el uso (y, si corresponde, la redistribución) de
los datos.

Lo verificado en esta sesión se limita a la **existencia de publicaciones**
(metadatos y resúmenes en Crossref); **ninguna disponibilidad o acceso a
datos está verificada**.

| Candidata | Evidencia verificada | Ítems abiertos (`TODO`) |
|---|---|---|
| Valle central del Maule | Carrasco-Benavides et al. (2014): torre EC en un viñedo Merlot con riego por goteo (35°25′S, 71°32′W, 125 m), parcela de 4,25 ha, 15 imágenes Landsat 2006–2009 (resumen en Crossref) | Acceso a los datos EC y su período; representatividad a 1 km (parcela ≈ 5 % de una celda); estaciones de la red regional; otros sitios EC del área |
| Valle de Aconcagua | Selles et al. (2011): requerimientos hídricos de uva de mesa medidos con EC en el valle de Aconcagua (título en Crossref) | Ubicación exacta, período, acceso a datos; representatividad a 1 km |
| Cuencas de CAMELS-CL | Alvarez-Garreton et al. (2018): 516 cuencas entre 17,8 y 55,0°S con caudal diario, precipitación de cuatro fuentes, ETP de dos fuentes y grado de intervención antrópica (resumen en Crossref) | Acceso al conjunto (hosts no accesibles en esta sesión); selección de cuencas con baja intervención y cierre de balance plausible; superposición temporal con MODIS |
| Región Metropolitana (Santiago) | Antecedente del autor: Montaner-Fernández et al. (2020) usaron nueve estaciones con MODIS y GWR (`gwr-forcing.md` §2.7) | Utilidad para N1 (CV del forzamiento); observaciones de ET para N3 |
| Transecto costa–Andes | — | Estaciones en altura; anclas en terreno complejo (D-AP-07, RC-09, RC-11) |
| Redes de estaciones (DMC, INIA Agromet, DGA, CEAZA-Met) | — | Todo lo listado en `weather-forcing.md` §9 |
| Sitios chilenos en redes de flujos (p. ej., FLUXNET2015, 212 sitios según Pastorello et al., 2020) | Existencia del conjunto (resumen en Crossref) | Si incluye sitios en Chile; lista de sitios no accesible en esta sesión |
| Lisímetros de pesada en Chile | — | Identificar instalaciones, período y acceso |

### 2.12 Fuentes y accesos de esta revisión (2026-11-04)

Citas usadas en esta parte que ya figuran en `REFERENCES.md` ("Scientific
validation", "Author's prior work"): Twine et al. (2000); Wilson et al.
(2002); Gupta et al. (2009); Willmott (1981); Roberts et al. (2017);
Galdón-Ruíz et al. (2023); Montaner-Fernández et al. (2020);
Morales-Salinas et al. (2023).

Citas nuevas, metadatos `VERIFIED (2026-11-04, Crossref)`; contenido leído
solo a nivel de título/resumen; incorporadas a `REFERENCES.md` ("Scientific
validation" → "Validation design"):

- Alvarez-Garreton, C., Mendoza, P. A., Boisier, J. P., Addor, N.,
  Galleguillos, M., Zambrano-Bigiarini, M., et al. (2018). The CAMELS-CL
  dataset: catchment attributes and meteorology for large sample studies –
  Chile dataset. *Hydrology and Earth System Sciences*, 22(11), 5817–5846.
  https://doi.org/10.5194/hess-22-5817-2018
- Box, G. E. P., & Hunter, J. S. (1961). The 2^(k−p) fractional factorial
  designs. *Technometrics*, 3(3), 311–351.
  https://doi.org/10.1080/00401706.1961.10489951
- Carrasco-Benavides, M., Ortega-Farías, S., Lagos, L., Kleissl, J.,
  Morales-Salinas, L., & Kilic, A. (2014). Parameterization of the
  satellite-based model (METRIC) for the estimation of instantaneous surface
  energy balance components over a drip-irrigated vineyard. *Remote
  Sensing*, 6(11), 11342–11371. https://doi.org/10.3390/rs61111342
- Efron, B. (1979). Bootstrap methods: another look at the jackknife. *The
  Annals of Statistics*, 7(1), 1–26. https://doi.org/10.1214/aos/1176344552
- Kling, H., Fuchs, M., & Paulin, M. (2012). Runoff conditions in the upper
  Danube basin under an ensemble of climate change scenarios. *Journal of
  Hydrology*, 424–425, 264–277. https://doi.org/10.1016/j.jhydrol.2012.01.011
- Kljun, N., Calanca, P., Rotach, M. W., & Schmid, H. P. (2015). A simple
  two-dimensional parameterisation for Flux Footprint Prediction (FFP).
  *Geoscientific Model Development*, 8(11), 3695–3713.
  https://doi.org/10.5194/gmd-8-3695-2015
- Pastorello, G., Trotta, C., Canfora, E., et al. (2020). The FLUXNET2015
  dataset and the ONEFlux processing pipeline for eddy covariance data.
  *Scientific Data*, 7, 225. https://doi.org/10.1038/s41597-020-0534-3
- Selles, G., Ferreyra, R., Aspillaga, C., Ortega-Farias, S., Villagra, P.,
  & García de Cortázar, V. (2011). Estimation of water requirements of
  'Thompson Seedless' trained on an overhead trellised system using an eddy
  covariance method in the Aconcagua Valley, Chile. *Acta Horticulturae*,
  889, 137–143. https://doi.org/10.17660/actahortic.2011.889.14

Sin verificar: Holm (1979) (no hallado en Crossref); FFP, KGE, KGE′ y d de
Willmott a nivel de contenido.

Búsquedas: Crossref (EC, lisímetros y METRIC/MODIS en Chile) y Zenodo
(conjuntos EC y lisimétricos en Chile; ningún conjunto chileno encontrado
en las consultas realizadas, lo que no prueba su inexistencia).

| Host | Resultado |
|---|---|
| `api.crossref.org`, `zenodo.org`, `cran.r-project.org` | Accesibles |
| `www.nature.com` | 429; no se reintentó |
| `www.mdpi.com` | 403 |
| `fluxnet.org`, `data.fluxnet.org`, `fluxnet.github.io`, `ameriflux.lbl.gov`, `www.fluxdata.org`, `www.icos-cp.eu` | Sin conexión (proxy) |
| `agromet.inia.cl`, `www.ceazamet.cl`, `explorador.cr2.cl`, `www.cr2.cl`, `camels.cr2.cl`, `dga.mop.gob.cl`, `climatologia.meteochile.gob.cl` | Sin conexión (proxy) |
| `doi.pangaea.de`, `cds.climate.copernicus.eu`, `www.sciencedirect.com`, `essd.copernicus.org`, `gmd.copernicus.org`, `www.osti.gov` | Sin conexión (proxy) |
