# EarthFlux — Especificación: flags de diagnóstico (registro unificado)

Estado: **borrador M1** · Módulo: `diagnostics` (`ARCHITECTURE.md` §2) ·
Archivo de destino: `R/diagnostics.R` · Tests:
`tests/testthat/test-diagnostics.R` · Autor: Guillermo Servando
Fuentes-Jaque.

> Este documento unifica los flags propuestos en `dev/specs/*.md`
> (lectura del 2026-11-04). **No registra ningún código**: `R/diagnostics.R`
> sigue siendo la fuente de verdad de los códigos registrados (hoy solo
> `EF_INPUT_NA` y `EF_ET_NEGATIVE`; mecanismo del registro por etapa en
> §4.2 y §7). Los cambios que aquí se proponen a
> otras especificaciones se listan en §10 y no se editan aquí. Nada de este
> documento se implementa fuera de la Definition of Done
> (`DEVELOPMENT.md` §3).

Convención de estados: la misma de `SCIENTIFIC_SPEC.md` (`TODO`,
`CANDIDATA`, `VERIFICADA`). Los códigos de flag se escriben en inglés y en
mayúsculas (`EF_*`); las descripciones del registro, en inglés (en-GB,
`ARCHITECTURE.md` §6.6).

---

## 0. Resumen

| Concepto | Valor |
|---|---|
| Filas de inventario (propuestas por documento, §2) | 122 |
| Códigos/condiciones distintos inventariados | 120 (119 con nombre + 1 sin nombre: "Rn negativo") |
| Códigos tras normalizar (§3–§4) | **112** |
| Clase I — inequívocos, sin umbral: registrables con su módulo | **73** (2 ya registrados + 71 pendientes) |
| Clase II — requieren umbral (o verificación de fuente): `TODO`, no registrar | **35** |
| Clase III — imposibilidad física/lógica: **error** en el núcleo; flag `critical` solo en módulos de datos | **4** |
| Fusiones (mismo hecho, nombres distintos) | 5 (eliminan 5 códigos) |
| Retiros por herencia (anclas) | 4 |
| Divisiones (mismo nombre, condiciones distintas) | 1 (agrega 1 código) |
| Nueva severidad propuesta | `critical` (§5) |
| Representación ráster | Una palabra entera de 31 bits por capa de salida, tabla de bits por etapa, bit 0 = `EF_INPUT_NA` (§6) |

Decisiones principales (todas propuestas; §9):

1. **Un prefijo por módulo/etapa**, lista cerrada: `INPUT`, `SURF`, `WS`,
   `GWR`, `RAD`, `G`, `ANCHOR`, `H`, `ET` (§3.1). Resuelve WF-07
   (`weather-forcing.md`) y la nota "prefijos a unificar" de
   `gwr-forcing.md` §12.
2. **Un hecho, un código**: LE < 0 ≡ ET_inst < 0 → `EF_ET_NEGATIVE`;
   dT < 0 ≡ LE > Rn − G ≡ H < 0 → `EF_H_NEGATIVE`; Rn − G ≤ 0 →
   `EF_G_AVAILABLE_NONPOSITIVE` (§3.3).
3. **Herencia en anclas**: las condiciones de superficie y forzamiento
   evaluadas en un ancla no generan códigos `EF_ANCHOR_*` nuevos; se
   heredan de las palabras de flags aguas arriba (§3.4).
4. Tercera severidad **`critical`** con criterio cerrado (§5).
5. Flags ráster **codificados por bits por capa de salida** (enmienda A1 de
   `gwr-forcing.md` §2.5 generalizada), sin OR entre etapas; una capa
   derivada de severidad máxima resume el linaje (§6).

---

## 1. Alcance y principios

### 1.1 Documentos leídos

`R/diagnostics.R`; `tests/testthat/test-diagnostics.R`;
`dev/ARCHITECTURE.md` (principios 5–8); `dev/SCIENTIFIC_SPEC.md` §3 y §8;
`dev/DEVELOPMENT.md` §3; y todas las especificaciones de `dev/specs/`:
`anchor-pixels.md`, `ef_net_radiation.md`, `evapotranspiration.md`,
`gwr-forcing.md`, `modis-products.md`, `radiation-components.md`,
`sensible-heat.md`, `soil-heat-flux.md`, `weather-forcing.md`.

### 1.2 Principios que este documento aplica

| Principio (`ARCHITECTURE.md` §1) | Consecuencia para los flags |
|---|---|
| 5. Los diagnósticos son parte del resultado | Toda salida (vector, tabla, ráster, objeto) lleva sus flags y la procedencia de cómo se evaluaron (§6) |
| 6. No corregir silenciosamente | Un flag nunca modifica el valor; enmascarar por política se cuenta y se registra (§6.6) |
| 7. Unidades explícitas | Los parámetros de flags con umbral registran valor, unidad y referencia (§6.7) |
| 8. Errores, warnings o flags apropiados, con clase | Imposibilidad física en el núcleo → `earthflux_domain_error`; valor posible pero inusual → flag (`radiation-components.md` §4.7; `soil-heat-flux.md` §6.2). La clase III (§4.3) reconcilia esta regla con los módulos de datos |

### 1.3 Fuera de alcance

- Implementar o registrar códigos (ver §7).
- Fijar umbrales: ningún valor numérico de umbral se propone aquí.
- Métodos `print()`/`summary()` de flags (`R/print.R`), salvo los
  requisitos de §6.5.

---

## 2. Inventario de flags propuestos

Columnas: **Fuente** (documento y sección); **¿Umbral?** según la fuente;
**Sev.** = severidad propuesta en la fuente (`—` = no indicada); **Etapa**
= módulo de `ARCHITECTURE.md` §2 (y sub-etapa de `metric`). Las filas 30
y 45 son referencias cruzadas de `weather-forcing.md` a códigos ya
propuestos en `radiation-components.md` (por eso hay 122 filas y 120
códigos distintos).

### 2.1 `R/diagnostics.R` (registrados)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 1 | `EF_INPUT_NA` | `R/diagnostics.R`; citado en todas las specs | Entrada requerida `NA` → salida `NA` | No | info | orquestación (transversal) |
| 2 | `EF_ET_NEGATIVE` | `R/diagnostics.R`; `evapotranspiration.md` §7.1 | ET < 0 (ET_inst, ETa_24, ET_per), valor conservado | No | warning | metric/ET |

### 2.2 `modis-products.md` (§10.2; también §6.3, §9.1, §9.2)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 3 | `EF_MODIS_FILL` | §10.2 | DN = `_FillValue` → `NA` | No | — | surface |
| 4 | `EF_MODIS_CLOUD` | §10.2 | MODLAND 10 (no producido por nubes) → `NA` | No | — | surface |
| 5 | `EF_MODIS_NOT_PRODUCED` | §10.2 | MODLAND 11 (no producido, otras razones) → `NA` | No | — | surface |
| 6 | `EF_MODIS_OUT_OF_RANGE` | §10.2 | DN fuera del rango válido y ≠ relleno → `NA` | No | — | surface |
| 7 | `EF_MODIS_QA_OTHER` | §10.2, §10.3 | MODLAND 01 (producido, otra calidad); se conserva | No | — | surface |
| 8 | `EF_MODIS_LST_ERROR` | §10.2 | Categoría de error de LST (MOD11 bits 7–6 ≥ 10; MOD21 bits 15–14) | Sí (qué categoría) `TODO` | — | surface |
| 9 | `EF_MODIS_EMIS_ERROR` | §10.2 | Error de emisividad > 0.02 (MOD11 bits 5–4 ≥ 10) | Sí `TODO` | — | surface |
| 10 | `EF_MODIS_CLOUD_ADJACENT` | §10.2 | Nube adyacente / cirros (bits por producto) | No | — | surface |
| 11 | `EF_MODIS_SNOW` | §10.2 | Nieve/hielo (bits por producto) | No | — | surface |
| 12 | `EF_MODIS_WATER` | §10.2 | Tierra/agua ≠ tierra | No | — | surface |
| 13 | `EF_MODIS_LAI_NONVEG` | §10.2 | LAI con clase no vegetada (249–254) → `NA` en `lai` | No | — | surface |
| 14 | `EF_MODIS_LAI_BACKUP` | §10.2 | LAI de respaldo (SCF_QC 010/011) | No | — | surface |
| 15 | `EF_MODIS_ALBEDO_MAGNITUDE` | §10.2 | Albedo por inversión de magnitud (código 1, 3, 5, 7) | No | — | surface |
| 16 | `EF_MODIS_ALBEDO_GT1` | §10.2 | Albedo > 1 con DN válido; se conserva | No | — | surface |
| 17 | `EF_MODIS_VIEW_ANGLE_HIGH` | §10.2 | Ángulo de visión alto | Sí `TODO` | — | surface |
| 18 | `EF_MODIS_COMPOSITE_LAG` | §10.2, §9.1 (T2) | \|desfase compuesto–LST\| > umbral | Sí `TODO` | — | surface |
| 19 | `EF_MODIS_AGG_INCOMPLETE` | §10.2, §9.2 | Fracción de sub-celdas válidas < umbral → `NA` | Sí `TODO` | — | surface |
| 20 | `EF_OVERPASS_TIME_MISSING` | §10.2 | LST válida sin `view_time` válido | No | — | surface |
| 21 | `EF_OVERPASS_OUTSIDE_WINDOW` | §10.2, §6.3 | Hora de paso fuera de la ventana de validez de métodos "de mediodía" | Sí `TODO` | — | surface |
| 22 | `EF_MODIS_SALT_PAN` | §10.2 | Salar (MOD09 bit 14) | No | — | surface |

### 2.3 `weather-forcing.md` (§3.2; también §4.8, §5.4, §5.5)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 23 | `EF_WS_IMPOSSIBLE` | QC-01a | HR < 0; viento < 0; T ≤ −273.15 °C; P ≤ 0 | No | error | forcing |
| 24 | `EF_WS_IMPLAUSIBLE` | QC-01b, §4.3 | Fuera de límites plausibles / unidad sospechosa | Sí `TODO` | warning | forcing |
| 25 | `EF_WS_RH_GT100` | QC-02 | HR > 100 % | No | info | forcing |
| 26 | `EF_WS_RH_RECALIBRATE` | QC-02 | HR > 100 % + δ, δ ∈ [3, 5] % | δ por elegir (WF-06) | warning | forcing |
| 27 | `EF_WS_TMIN_GT_TMAX` | QC-03 | Tmin > Tmax | No | error | forcing |
| 28 | `EF_WS_TDEW_GT_TAIR` | QC-04 | Tdew > T | Tolerancia `TODO` (sin tolerancia: inequívoca) | warning | forcing |
| 29 | `EF_WS_RS_GT_RSO` | QC-05a | Rs > Rso | Margen `TODO` | warning | forcing |
| 30 | `EF_RS_EXCEEDS_EXTRATERRESTRIAL` (ref.) | QC-05b | Rs > Ra en la misma ventana (media horaria/diaria) | No | warning | forcing |
| 31 | `EF_WS_RS_CALIBRATION` | QC-05c | Máximos de Rs en días despejados sistemáticamente sobre/bajo Rso | Sí `TODO` | warning | forcing |
| 32 | `EF_WS_RS_NIGHT` | QC-05d | Ra = 0 y Rs ≠ 0 | Tolerancia `TODO` | info | forcing |
| 33 | `EF_WS_PERSISTENCE` | QC-06 | Valor constante durante N registros | N y tolerancia `TODO` | warning | forcing |
| 34 | `EF_WS_STEP` | QC-07 | \|x_t − x_{t−1}\| > umbral | Sí `TODO` | warning | forcing |
| 35 | `EF_WS_RHMAX_LOW` | QC-08a | HRmax consistentemente < 80–90 % | Valor y ventana (WF-06) | warning | forcing |
| 36 | `EF_WS_NONREFERENCE` | QC-08b | Tmin − Tdew o A_bi sobre valores de FAO-56 Anexo 6 | Valores FAO-56; uso horario `TODO` | info | forcing |
| 37 | `EF_WS_EA_DIURNAL` | QC-08c | Variación diurna de eₐ fuera de lo esperado | Sí `TODO` | info | forcing |
| 38 | `EF_WS_TIME_GAP` | QC-09 | Huecos en la serie | No | warning | forcing |
| 39 | `EF_WS_TIME_IRREGULAR` | QC-09 | Pasos de tiempo irregulares | No | warning | forcing |
| 40 | `EF_WS_TIME_SHIFT` | QC-09 | Desfase horario sospechoso | Tolerancia `TODO` | warning | forcing |
| 41 | `EF_WS_INCOMPLETE_DAY` | QC-10, §5.6 | Menos períodos que los del día → ETr24 `NA` | No (política de huecos `TODO`) | warning | forcing |
| 42 | `EF_WS_HEIGHT_MISSING` | QC-11 | Altura de medición `NA` | No | warning | forcing |
| 43 | `EF_WS_HEIGHT_NONSTANDARD` | QC-11 | Altura de T/HR ≠ 2 m | No | warning | forcing |
| 44 | `EF_WS_SPATIAL_OUTLIER` | QC-12 | Residuo frente a vecinos o superficie regional | Sí `TODO` | warning | forcing |
| 45 | `EF_STATION_CLOUDY` (ref.) | QC-13 | Rs/Rso a la hora de paso bajo un umbral | Sí `TODO` | warning | forcing |
| 46 | `EF_WS_RS_RSO_LIMITED` | §4.8 | Rs/Rso fuera del rango de la norma (> 1; con ASCE-EWRI también < 0,3) limitado dentro del término de nubosidad (FAO-56 Ec. 39; ASCE-EWRI 2005 Ec. 18 y 45) | No (definición de la norma) | info | forcing |
| 47 | `EF_ETREF_NEGATIVE` | §5.4 | ETr/ETo < 0, conservada | No | info | forcing |
| 48 | `EF_WS_OVERPASS_OUTSIDE_RECORDS` | §5.5 | Hora de paso fuera del rango de registros → `NA` | No | — | forcing |

### 2.4 `gwr-forcing.md` (§12; también §2.3, §2.7, §4.1, §4.4–§4.6, §5.3, §6.2–§6.3)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 49 | `EF_GWR_EXTRAPOLATION_COVARIATE` | §6.3, §12 | Covariable fuera del rango de las estaciones del ajuste (celda) | No | warning | spatial |
| 50 | `EF_GWR_EXTRAPOLATION_LOCAL` | §6.3, §12 | Ídem, solo estaciones con peso no nulo (celda) | No | info | spatial |
| 51 | `EF_GWR_OUTSIDE_HULL` | §6.3, §12 | Centro de celda fuera de la envolvente convexa de las estaciones | No | warning | spatial |
| 52 | `EF_GWR_FAR_FROM_STATIONS` | §6.3, §12 | Distancia a la estación más cercana > `d_max` | Sí `TODO` | warning | spatial |
| 53 | `EF_GWR_FEW_NEIGHBOURS` | §4.5, §6.3, §12 | Pesos no nulos < `min_neighbours` (celda/estación) | Mínimo matemático p + 1; mayores requieren referencia | warning | spatial |
| 54 | `EF_GWR_LOCAL_SINGULAR` | §4.6, §12 | Diseño local de rango deficiente en una celda → `NA` | No | warning | spatial |
| 55 | `EF_GWR_ILL_CONDITIONED` | §4.6, §12 | κ local > `kappa_max` | Sí `TODO` | warning | spatial |
| 56 | `EF_GWR_PHYSICAL_RANGE` | §2.3, §12 | Predicción fuera del dominio físico (eₐ ≤ 0, u < 0, clearness < 0, ETr_inst ≤ 0), conservada | No (imposibilidades) | warning | spatial |
| 57 | `EF_GWR_COARSE_MODE` | §6.2, §12 | Coeficientes interpolados desde grilla gruesa | No | info | spatial |
| 58 | `EF_GWR_TRANSFORMED` | §2.3, §12 | Respuesta transformada y retrotransformada | No | info | spatial |
| 59 | `EF_GWR_SURFACE_COVARIATE` | §2.7, §12 | Covariable derivada del estado de superficie | No | warning | spatial |
| 60 | `EF_GWR_BW_AT_BOUND` | §4.4, §12 | Bandwidth en el límite de búsqueda | No | warning | spatial |
| 61 | `EF_GWR_BW_MULTIMODAL` | §4.4, §12 | Más de un mínimo local factible en el perfil | No (dada la rejilla) | info | spatial |
| 62 | `EF_GWR_AICC_UNDEFINED` | §4.1, §12 | n − 2 − tr S ≤ 0 en parte del intervalo | No | info | spatial |
| 63 | `EF_GWR_GLOBAL_PREFERRED` | §4.4, §12 | Criterio del modelo global ≤ mínimo del perfil | No | info | spatial |
| 64 | `EF_GWR_STATION_EXCLUDED` | §12 | Estaciones excluidas (QC, `NA`, usuario) | No | info | spatial |
| 65 | `EF_GWR_FEW_STATIONS` | §4.5, §12 | p + 3 ≤ n < `n_min` | Sí `TODO` | warning | spatial |
| 66 | `EF_GWR_ELEVATION_MISMATCH` | §12 | \|z_metadatos − z_MDE\| > umbral | Sí `TODO` | warning | spatial |
| 67 | `EF_FORCING_SINGLE_STATION` | §5.3, §12 | Configuración C1 (estación representativa) | No | info | spatial |

### 2.5 `radiation-components.md` (§4.8)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 68 | `EF_SELF_SHADED` | §4.8, §6.4 | cos θ_rel ≤ 0 con cos θ_h > 0 | No | info | metric/Rn |
| 69 | `EF_ATM_EMISSIVITY_GT1` | §4.8, §6.5 | ε_a > 1 | No | warning | metric/Rn |
| 70 | `EF_RS_EXCEEDS_EXTRATERRESTRIAL` | §4.8, §6.4 B | Rs_meas > Gsc·dr·cos θ_h (instantánea, horizontal) | No | warning | metric/Rn |
| 71 | `EF_LOW_SUN` | §4.8, §6.3 | cos θ_h bajo un umbral | Sí `TODO` | warning | metric/Rn |
| 72 | `EF_LST_IMPLAUSIBLE` | §4.8, §6.6 | Ts fuera de un rango plausible | Sí `TODO` | warning | metric/Rn (entrada) |
| 73 | `EF_STATION_CLOUDY` | §4.8, §6.4 B | Rs_meas / Rso_modelada en la estación bajo un umbral | Sí `TODO` | warning | metric/Rn |

### 2.6 `ef_net_radiation.md` y `SCIENTIFIC_SPEC.md` §3

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 74 | (sin código) "Rn negativo" | `ef_net_radiation.md` §9, §10.1; SPEC §3 (fila Rn) | Rn < 0, permitido y conservado | No | — ("sin warning") | metric/Rn |

### 2.7 `soil-heat-flux.md` (§6.3)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 75 | `EF_G_RN_NONPOSITIVE` | §6.3 | R_n ≤ 0 (G/R_n indefinida o de significado invertido) | No | warning | metric/G |
| 76 | `EF_G_RATIO_NEGATIVE` | §6.3 | G/R_n < 0 | No | warning | metric/G |
| 77 | `EF_G_EXCEEDS_RN` | §6.3 | R_n > 0 y G > R_n | No | warning | metric/G |
| 78 | `EF_G_LOW_LAI_BRANCH` | §6.3 | Tasumi: rama LAI < 0.5 aplicada | No (umbral del método) | info | metric/G |
| 79 | `EF_G_NDVI_NONPOSITIVE` | §3.4, §6.3 | NDVI ≤ 0 | Condición sí; pertinencia desde fuente terciaria (`CANDIDATA`) | warning | metric/G |
| 80 | `EF_G_RATIO_IMPLAUSIBLE` | §6.3 (D7) | G/R_n fuera de [r_min, r_max] | Sí `TODO` | warning | metric/G |

### 2.8 `anchor-pixels.md` (§6; también §2.3, §2.4, §5.3, §5.7)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 81 | `EF_ANCHOR_USER_SUPPLIED` | §5.7, §6 | Anclas entregadas por el usuario | No | info | metric/anclas |
| 82 | `EF_ANCHOR_CRITERIA_RELAXED` | §5.3, §6 | Paso de relajación distinto del primero | No | warning | metric/anclas |
| 83 | `EF_ANCHOR_SEARCH_EXPANDED` | §6 | Candidatos fuera del primer dominio de búsqueda | No | warning | metric/anclas |
| 84 | `EF_ANCHOR_HOMOGENEITY_DROPPED` | §6 | Criterio de homogeneidad omitido (plan explícito) | No | warning | metric/anclas |
| 85 | `EF_ANCHOR_WINDOW_INCOMPLETE` | §5.3, §6 | Ventana de homogeneidad con `NA` o que cruza el borde | No | warning | metric/anclas |
| 86 | `EF_ANCHOR_TIES` | §6, §7.3 | Empates resueltos por índice de celda | No | info | metric/anclas |
| 87 | `EF_ANCHOR_SINGLE_PIXEL` | §6 | Un tipo representado por un solo píxel | No | info | metric/anclas |
| 88 | `EF_ANCHOR_COLD_H_NEGATIVE` | §2.5, §6 | Etapa [B]: H_frío < 0 | No | warning | metric/anclas |
| 89 | `EF_ANCHOR_HOT_LE_ASSUMED_ZERO` | §6 | Etapa [B]: LE_caliente = 0 por supuesto | No | info | metric/anclas |
| 90 | `EF_ANCHOR_FEW_CANDIDATES` | §5.6, §6 | Candidatos de un tipo bajo un mínimo | Sí `TODO` | warning | metric/anclas |
| 91 | `EF_ANCHOR_SMALL_CONTRAST` | §6 | Ts_caliente − Ts_frío bajo un mínimo | Sí `TODO` | warning | metric/anclas |
| 92 | `EF_ANCHOR_COLD_PARTIAL_COVER` | §6 | Ancla fría con NDVI/LAI bajo cobertura plena | Sí `TODO` | warning | metric/anclas |
| 93 | `EF_ANCHOR_HOT_RECENT_RAIN` | §2.3, §6 | Precipitación reciente con LE_caliente = 0 | Sí `TODO` (umbral y ventana) | warning | metric/anclas |
| 94 | `EF_ANCHOR_QA_DEGRADED` | §6 | QA del producto no óptimo en un ancla | Depende de QA de `surface` `TODO` | warning | metric/anclas |
| 95 | `EF_ANCHOR_HIGH_VIEW_ANGLE` | §6 (Q-AP-07) | Ángulo de visión del ancla sobre un umbral | Sí `TODO` | warning | metric/anclas |
| 96 | `EF_ANCHOR_COMPOSITE_LAG` | §6 (Q-AP-06) | Desfase compuesto–paso en el ancla sobre un umbral | Sí `TODO` | warning | metric/anclas |
| 97 | `EF_ANCHOR_FORCING_EXTRAPOLATED` | §2.4, §6; `gwr-forcing.md` §6.3 | ETr_inst del ancla desde superficie GWR marcada como extrapolación | No, si GWR la define (la define `gwr-forcing.md` §6.3) | warning | metric/anclas |
| 98 | `EF_ANCHOR_OVERPASS_SPREAD` | §6 | Anclas de un mismo tipo con horas de paso distintas | No (magnitud tolerable `TODO`) | info | metric/anclas |

### 2.9 `sensible-heat.md` (§16; también §2.2, §5.6, §6.2, §6.4, §9.3–§9.4, §10.3, §11.6)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 99 | `EF_ZOM_FLOOR_APPLIED` | §5.6, §16 | z_om elevada al mínimo del método | No "si se adopta el mínimo" (0.005 m no verificado) | info | metric/H |
| 100 | `EF_ZOM_TERRAIN_ADJUSTED` | §5.7, §16 | Factor de terreno aplicado | No | info | metric/H |
| 101 | `EF_LOW_WIND` | §6.2, §13, §16 | u_b bajo un umbral | Sí `TODO` | warning | metric/H |
| 102 | `EF_WIND_FLOOR_APPLIED` | §6.2, §16 | Piso explícito de u_b usado (SH-06) | No | warning | metric/H |
| 103 | `EF_USTAR_INVALID` | §6.4, §7.2, §16 | u* ≤ 0 o no finita en un píxel → `NA` | No | warning | metric/H |
| 104 | `EF_STRONGLY_STABLE` | §10.3, §16 | z/L sobre un umbral | Sí `TODO` | warning | metric/H |
| 105 | `EF_H_NOT_CONVERGED` | §11.6, §16 | Fase A sin convergencia en `maxit` (escena) | No | warning | metric/H |
| 106 | `EF_H_PIXEL_NOT_CONVERGED` | §11.6, §16 | Fase B sin convergencia en el píxel | No | warning | metric/H |
| 107 | `EF_DT_EXTRAPOLATED_HOT` | §9.4, §16 | Ts_datum > Ts_datum,hot | No | info | metric/H |
| 108 | `EF_DT_EXTRAPOLATED_COLD` | §9.4, §16 | Ts_datum < Ts_datum,cold | No | info | metric/H |
| 109 | `EF_DT_NEGATIVE` | §9.4, §16 | dT < 0 (H < 0) | No | info | metric/H |
| 110 | `EF_DT_SLOPE_NONPOSITIVE` | §9.3, §16 | b ≤ 0 con anclas bien ordenadas | No | warning | metric/H |
| 111 | `EF_H_EXCEEDS_AVAILABLE` | §16 | Rn − G > 0 y H > Rn − G | No | warning | metric/H |
| 112 | `EF_ANCHOR_DT_SMALL` | §2.2, §16 | Ts_datum,hot − Ts_datum,cold bajo un umbral | Sí `TODO` | warning | metric/H (compartido con anclas) |

### 2.10 `evapotranspiration.md` (§7.2; también §8.1, §8.3)

| # | Código | Fuente | Condición | ¿Umbral? | Sev. | Etapa |
|---|---|---|---|---|---|---|
| 113 | `EF_LE_NEGATIVE` | §7.2 (ET-D4) | LE < 0 | No | warning | metric/ET |
| 114 | `EF_LE_EXCEEDS_AVAILABLE` | §7.2 | LE > Rn − G (H < 0) | No | info | metric/ET |
| 115 | `EF_AVAILABLE_ENERGY_NONPOSITIVE` | §7.2 | Rn − G ≤ 0 | No | warning | metric/ET |
| 116 | `EF_ETRF_IMPLAUSIBLE` | §7.2, §7.3 (ET-D5) | ETrF fuera de [r_min, r_max] | Sí `TODO` | warning | metric/ET |
| 117 | `EF_ETRF_EXTRAPOLATED` | §7.2, §8.1 | ET_per: día fuera de [primera, última] fecha válida | No | warning | metric/ET |
| 118 | `EF_ETRF_SINGLE_DATE` | §7.2, §8.1 | ET_per: una sola fecha válida | No | warning | metric/ET |
| 119 | `EF_ETRF_NO_VALID_DATE` | §7.2, §8.1 | ET_per: ninguna fecha válida (resultado `NA`) | No | info | metric/ET |
| 120 | `EF_ETRF_SPLINE_OVERSHOOT` | §7.2, caso P5 | Spline: ETrF diaria fuera de [mín, máx] de las fechas vecinas | No | warning | metric/ET |
| 121 | `EF_ETRF_GAP_LONG` | §7.2 (ET-D10) | Intervalo entre fechas válidas > máximo | Sí `TODO` | warning | metric/ET |
| 122 | `EF_ETR24_FILLED` | §7.2, §8.1 | Días de ETr_24 rellenados (solo con relleno explícito) | No | info | metric/ET |

**Nombres `EF_*` que no son flags.** `evapotranspiration.md` (§4.2, §4.4,
§5.4) y `soil-heat-flux.md` (§4) proponen constantes internas
`EF_KELVIN_OFFSET`, `EF_WATER_DENSITY`, `EF_SECONDS_PER_HOUR` y
`EF_MM_PER_M`. No se inventarían como flags, pero comparten el espacio
de nombres `EF_*` (colisión C9, §3.3).

---

## 3. Normalización

### 3.1 Prefijos: uno por módulo/etapa (lista cerrada)

| Prefijo | Módulo (`ARCHITECTURE.md` §2) | Archivos | Qué marca |
|---|---|---|---|
| `EF_INPUT_` | orquestación (transversal) | `diagnostics.R`, `api-*.R` | Propagación de `NA` de entradas |
| `EF_SURF_` | `surface` | `io-modis.R`, `modis-qa.R`, `prep-modis.R`, `modis-surface.R`, `io-aoi.R` | QA del producto, plausibilidad y tiempo del estado de superficie |
| `EF_WS_` | `forcing` | `io-weather.R`, `prep-weather.R`, `prep-qc.R` | QC de estaciones y variables derivadas en estación (incluida ETr) |
| `EF_GWR_` | `spatial` | `gwr-*.R` (y alternativas C1/C2) | Ajuste, bandwidth, extrapolación y dominio de las superficies |
| `EF_RAD_` | `metric` (Rn y componentes) | `metric-radiation.R` | Geometría solar, onda corta/larga, Rn |
| `EF_G_` | `metric` (G) | `metric-soil-heat.R` | G, G/Rn y energía disponible |
| `EF_ANCHOR_` | `metric` (anclas) | `metric-anchors.R` | Selección y condiciones de borde de las anclas |
| `EF_H_` | `metric` (H) | `metric-aerodynamics.R`, `metric-dt.R`, `metric-sensible-heat.R` | z_om, viento, u*, estabilidad, dT, iteración, H |
| `EF_ET_` | `metric` (LE/ET) | `metric-latent-heat.R`, `metric-et.R` | ET_inst, ETrF, ETa, ET de período |

Justificación de las dos elecciones no obvias:

- **`EF_SURF_` en lugar de `EF_MODIS_`** (decisión FL-01). Principios 1–2:
  el módulo `surface` entrega variables físicas estandarizadas y la
  continuidad con VIIRS está prevista (`modis-products.md` §7.3). Un
  código como "no producido por nubes" debe sobrevivir a un cambio de
  sensor; la correspondencia bit QA del producto → código vive en
  `prep-modis.R` (tabla por producto) y el sensor queda en la procedencia.
  Los consumidores (`EF_ANCHOR_*`, resúmenes) no deben conocer el sensor.
- **`EF_GWR_` para todo el módulo `spatial`** (decisión FL-02). Los
  archivos del módulo son `gwr-*.R` y las salidas de C1, C2 y C3 comparten
  contrato (`gwr-forcing.md` §5.1); códigos como `EF_GWR_OUTSIDE_HULL` se
  aplican también a IDW u OLS. La alternativa `EF_SPATIAL_` es más
  precisa pero renombra 19 códigos ya usados en tres documentos.

El prefijo identifica la **etapa que evalúa la condición** (la función
que la levanta), no la variable afectada. Por eso Ts implausible pasa a
`EF_SURF_` (contrato del estado de superficie) aunque se propuso en
`radiation-components.md`, y ETr negativa pasa a `EF_WS_` (se calcula en
`prep-weather.R`; ver FL-09 para la opción C por píxel).

### 3.2 Vocabulario de sufijos

| Sufijo | Significado | Clase típica |
|---|---|---|
| `_OUT_OF_DOMAIN` | Imposibilidad física o lógica (coincide con `earthflux_domain_error`) | III |
| `_IMPLAUSIBLE` | Fuera de un rango plausible | II (requiere referencia) |
| `_NEGATIVE` / `_NONPOSITIVE` | < 0 / ≤ 0 | I |
| `_GT_<VAR>` / `_GT<N>` | Mayor que otra variable / que una constante de definición (`GT1`, `GT100`) | I |
| `_<SUJETO>_LOW` / `_<SUJETO>_HIGH` | Bajo/sobre un umbral (orden sustantivo → calificativo) | II |
| `_EXTRAPOLATED` | Fuera del soporte de datos | I |
| `_APPLIED` / `_ADJUSTED` | Regla de método aplicada (registro de auditoría) | I |
| `_MISSING` | Metadato o insumo ausente | I |
| `_NOT_CONVERGED` | Iteración sin cumplir su criterio | I |

Longitud máxima de un código: 40 caracteres.

### 3.3 Colisiones y duplicados resueltos

| Id | Tipo | Códigos afectados | Análisis | Resolución |
|---|---|---|---|---|
| C1 | Misma condición, nombres distintos | `EF_LE_NEGATIVE`, `EF_ET_NEGATIVE` | ET_inst = c·LE/λρ_w con λρ_w > 0 ⇒ LE < 0 ⇔ ET_inst < 0 (`evapotranspiration.md` §7.1) | Un solo código: `EF_ET_NEGATIVE` (registrado) sobre ET_inst, ETa_24 y ET_per. Resuelve ET-D4 a favor de reutilizar (FL-03). La **causa** de LE < 0 la explican `EF_G_AVAILABLE_NONPOSITIVE` y `EF_H_GT_AVAILABLE` |
| C2 | Misma condición, tres nombres | `EF_DT_NEGATIVE`, `EF_LE_EXCEEDS_AVAILABLE`, (H < 0) | H = ρ c_p dT / rah con ρ, c_p, rah > 0 ⇒ dT < 0 ⇔ H < 0; LE = (Rn − G) − H ⇒ LE > Rn − G ⇔ H < 0 | Un solo código en la etapa que calcula H: `EF_H_NEGATIVE` (info; advección posible) |
| C3 | Condiciones solapadas | `EF_G_EXCEEDS_RN` (Rn > 0 ∧ G > Rn), `EF_AVAILABLE_ENERGY_NONPOSITIVE` (Rn − G ≤ 0) | El segundo contiene al primero (salvo G = Rn) y además los casos Rn ≤ 0; ambos describen el mismo hecho físico (energía disponible no positiva). `evapotranspiration.md` §7.2 pide coordinar | Un solo código, levantado en la etapa G (primera que conoce Rn y G): `EF_G_AVAILABLE_NONPOSITIVE`, condición Rn − G ≤ 0. Con `EF_G_RN_NONPOSITIVE` el usuario separa los casos Rn ≤ 0 |
| C4 | Misma condición, dos documentos | `EF_ANCHOR_SMALL_CONTRAST` (Ts), `EF_ANCHOR_DT_SMALL` (Ts_datum) | Mismo diagnóstico (contraste térmico entre anclas) con Ts o Ts referida al datum; ambos con umbral `TODO` | `EF_ANCHOR_CONTRAST_LOW` (clase II); la condición se evalúa sobre la temperatura que use la calibración (Ts_datum si hay datum) y la procedencia registra cuál |
| C5 | Mismo nombre, condiciones distintas | `EF_RS_EXCEEDS_EXTRATERRESTRIAL` | `radiation-components.md`: Rs_meas > Gsc·dr·cos θ_h **instantánea**; `weather-forcing.md` QC-05b: Rs > Ra **integrada en la ventana** del registro | División: `EF_RAD_RS_GT_RA` (instantánea, etapa Rn) y `EF_WS_RS_GT_RA` (QC de la serie) |
| C6 | Mismo nombre y condición en dos documentos | `EF_STATION_CLOUDY` | Idéntica (Rs/Rso a la hora de paso bajo un umbral) | Un código: `EF_WS_CLOUDY_OVERPASS` (se evalúa en la estación, módulo `forcing`) |
| C7 | Misma condición en dos etapas | `EF_MODIS_COMPOSITE_LAG` / `EF_ANCHOR_COMPOSITE_LAG`; `EF_MODIS_VIEW_ANGLE_HIGH` / `EF_ANCHOR_HIGH_VIEW_ANGLE` (además con orden de palabras inconsistente); QA de superficie / `EF_ANCHOR_QA_DEGRADED`; `EF_GWR_EXTRAPOLATION_COVARIATE` ∨ `EF_GWR_OUTSIDE_HULL` / `EF_ANCHOR_FORCING_EXTRAPOLATED` | La condición en el ancla es la condición de la celda evaluada aguas arriba | Retiro de los 4 `EF_ANCHOR_*` y **herencia** (§3.4) |
| C8 | Misma semántica que un código registrado | `EF_ETRF_NO_VALID_DATE`, `EF_INPUT_NA` | Sin fechas válidas, ET_per es `NA` porque todas sus entradas son `NA`: es exactamente `EF_INPUT_NA` (alternativa ya anotada en `evapotranspiration.md` §7.2) | `EF_INPUT_NA` |
| C9 | Espacio de nombres compartido | `EF_KELVIN_OFFSET`, `EF_WATER_DENSITY`, `EF_SECONDS_PER_HOUR`, `EF_MM_PER_M` (constantes) | No son flags, pero coinciden con el patrón `^EF_[A-Z0-9_]+$` del test actual y con la búsqueda de códigos en el código fuente | La expresión regular cerrada de §8 (prefijos de §3.1) impide que un flag se llame así; test R15 (§8) impide que un código coincida con un objeto del paquete. Nombre de las constantes: decisión FL-08 |
| C10 | Palabras distintas, mismo concepto | `EF_WS_IMPOSSIBLE`, `EF_GWR_PHYSICAL_RANGE` | Ambas son imposibilidades físicas; "RANGE" además se confunde con rango plausible y con el rango válido de DN | Vocabulario `_OUT_OF_DOMAIN`: `EF_WS_OUT_OF_DOMAIN`, `EF_GWR_OUT_OF_DOMAIN`; el rango válido de DN pasa a `EF_SURF_DN_OUT_OF_RANGE` |
| C11 | Ámbito ambiguo | `EF_H_NOT_CONVERGED` (escena) vs `EF_H_PIXEL_NOT_CONVERGED` (píxel) | El nombre del primero no indica que es de la calibración | `EF_H_CALIBRATION_NOT_CONVERGED` (objeto) y `EF_H_PIXEL_NOT_CONVERGED` (celda) |
| C12 | Valor conservado aguas arriba que el núcleo rechaza | `EF_MODIS_ALBEDO_GT1` ("conservar") vs `albedo > 1` → `earthflux_domain_error` en G y Rn (`soil-heat-flux.md` §6.2; `radiation-components.md` §4.7) | Con la política por defecto, un solo píxel con albedo > 1 detendría la escena en G | Clase III (§4.3): `EF_SURF_ALBEDO_GT1` con severidad `critical`; la orquestación excluye por defecto los valores `critical` antes del núcleo, contando cada exclusión (FL-10) |

Relaciones que **no** son colisiones (se conservan ambos códigos):

- `EF_SURF_FILL`/`EF_SURF_CLOUD`/… y `EF_INPUT_NA`: los primeros explican
  la **causa** del `NA` en la capa de superficie; `EF_INPUT_NA` marca la
  propagación del `NA` en las salidas aguas abajo.
- `EF_H_GT_AVAILABLE` (Rn − G > 0 ∧ H > Rn − G) y `EF_ET_NEGATIVE`: el
  primero es una causa de LE < 0; el segundo, la consecuencia.
- `EF_ANCHOR_COLD_H_NEGATIVE` y `EF_H_NEGATIVE`: el primero es el H
  **objetivo** de la calibración en el ancla fría (LE impuesto); el
  segundo, el H **calculado** en un píxel.
- `EF_G_RN_NONPOSITIVE` y `EF_G_RATIO_NEGATIVE`: se solapan (Rn < 0 con
  G > 0), pero diagnostican cosas distintas (dominio de la razón vs signo
  de G/Rn).
- `EF_RAD_SUN_LOW` y `EF_SURF_OVERPASS_OUTSIDE_WINDOW`: ambos aparecen con
  pasadas tempranas, pero uno es geométrico (cos θ_h) y el otro es la
  ventana de validez de métodos "de mediodía".
- `EF_WS_INCOMPLETE_DAY` (estación) y `EF_ET_PERIOD_ETR24_FILLED`
  (período): el primero produce `NA`; el segundo registra un relleno
  explícito.

### 3.4 Regla de herencia (anclas)

**R-HER.** Una condición evaluada en un ancla que es idéntica a una
condición por celda ya evaluada aguas arriba **no** recibe un código
`EF_ANCHOR_*`. En su lugar:

1. `anchors$pixels` incluye la columna `inherited_flags` (lista de
   códigos activos en la celda del ancla en las palabras de flags de
   `lst`, `ndvi`, `albedo`, `lai` y de las superficies de forzamiento usadas
   en el ancla, §6.3).
2. `print()`/`summary()` del objeto de anclas cuentan los flags heredados
   por severidad.
3. Para el resumen de severidad del resultado (§6.5), los flags heredados
   cuentan como flags de **objeto** del conjunto de anclas: afectan a toda
   la escena porque la calibración se propaga a todos los píxeles.

Si en el futuro un ancla requiere un umbral **más estricto** que el de la
celda general (p. ej., ángulo de visión), ese es otro diagnóstico con su
propia referencia y su propio código `EF_ANCHOR_*` (clase II). La
selección estricta de anclas de `modis-products.md` §10.3 (solo MODLAND 00,
sin nieve, agua, nube adyacente ni salar) es un **criterio de selección**,
no un flag.

---

## 4. Catálogo normalizado y clasificación

### 4.1 Clases

- **Clase I — inequívoca, sin umbral.** Se registra cuando se implemente
  la función que la levanta (§7). Marca **I-m**: el único umbral es
  interno del método (forma parte de su ecuación, p. ej., LAI < 0.5 en
  Tasumi); el flag hereda el estado de verificación del método y no puede
  registrarse antes que el método (`DEVELOPMENT.md` §3).
- **Clase II — requiere umbral referenciado** (o verificación de la
  fuente que da sentido a la condición). `TODO`; **no registrar** hasta
  que el umbral tenga referencia en `SCIENTIFIC_SPEC.md` /
  `REFERENCES.md`. Ningún umbral se propone aquí.
- **Clase III — imposibilidad física o lógica.** En el núcleo numérico es
  un **error** con clase (`earthflux_domain_error` o la indicada). En los
  módulos que entregan conjuntos de datos completos (QC de estaciones,
  capas de superficie, superficies espaciales), donde un registro no debe
  detener toda la serie o escena (`weather-forcing.md` WF-04;
  `soil-heat-flux.md` D6), el valor se conserva con un flag de severidad
  `critical` y la política por defecto lo excluye antes del núcleo,
  contando cada exclusión. Nunca llega al núcleo en silencio.

Columnas del catálogo: **Ámbito** `cell` (celda de ráster o posición de
vector), `record` (fila de una tabla: registro de estación, estación del
ajuste, píxel ancla), `object` (escena, ajuste, conjunto de anclas,
corrida); **Bit** = bit planificado en la palabra de la etapa (§6.4; solo
ámbito `cell`, clase I/III; `—` = sin bit; `libre` = recibe el siguiente
bit libre al registrarse). **Sev.** marcada con `*` = cambia respecto de
la fuente o la fuente no la indicaba (justificación en §5.4).

### 4.2 Catálogo (112 códigos)

**Estado de implementación (2026-11-04).** El registro se ensambla por
etapa: `ef_flag_registry()` (`R/diagnostics.R`) une las filas que cada
etapa declara en su propio archivo con el constructor `ef_flag_rows()`,
que valida cada fila (R2–R6, R9, R17); la unión comprueba unicidad de
códigos y de bits por etapa (R1, R7). Dueños: `ef_flags_core()`
(`diagnostics.R`, `EF_INPUT_`), `ef_flags_radiation()`
(`metric-radiation.R`, `EF_RAD_`), `ef_flags_soil_heat()`
(`metric-soil-heat.R`, `EF_G_`), `ef_flags_anchors()`
(`metric-anchors.R`, `EF_ANCHOR_`), `ef_flags_sensible_heat()`
(`metric-sensible-heat.R`, `EF_H_`), `ef_flags_et()` (`metric-et.R`,
`EF_ET_`), `ef_flags_reference_et()` (`reference-et.R`, `EF_WS_`),
`ef_flags_stations()` (`prep-qc.R`, `EF_WS_`), `ef_flags_gwr()`
(`gwr-diagnostics.R`, `EF_GWR_`) y, desde M4, `ef_flags_surface()`
(`modis-qa.R`, `EF_SURF_`). El registro es estático: `ef_flag_registry()` lo guarda la
primera vez que se usa y `ef_flag_registry_build()` lo reconstruye sin
caché para los tests de §8 (`DECISIONS.md` §1.3, M3-37). Registrados: `EF_INPUT_NA` (`INPUT`, info, `cell,record`, bit 0) y
`EF_ET_NEGATIVE` (`ET`, warning, `cell`, bit 1), ambos con las columnas de
§7, y los diez códigos de clase I de `EF_ANCHOR_` (ámbitos `object`/`record`,
sin bit), registrados con `ef_select_anchors()`, `ef_anchors()` y
`ef_anchor_conditions()` (`metric-anchors.R`). En M3, la etapa de ET de
referencia (`ef_flags_reference_et()`, `reference-et.R`, prefijo `EF_WS_`)
registra `EF_WS_RS_RSO_LIMITED` (I-m) y `EF_WS_ETR_NEGATIVE` (I), ambos
informativos, de ámbito `record` y sin bit (`weather-forcing.md` §13), y
además `EF_WS_INCOMPLETE_DAY` y `EF_WS_OVERPASS_OUTSIDE_RECORDS` (I,
levantados por `ef_station_ref_et()`, `weather-forcing.md` §13.4); el QC
de estaciones (`ef_flags_stations()`, `prep-qc.R`) registra 9 códigos
`EF_WS_` (incluido `EF_WS_RS_GT_RA`). El núcleo GWR y la orquestación de
la regionalización (`ef_flags_gwr()`, `gwr-diagnostics.R`) registran 13
códigos `EF_GWR_`. En M4, los decodificadores QA de MODIS
(`ef_flags_surface()`, `modis-qa.R`) registran 12 códigos `EF_SURF_` de
clase I (bits 1–12; `modis-products.md`, bloque de estado de M4), y el
ensamblaje del estado de superficie (`modis_surface_state()`,
`modis-surface.R`) levanta `EF_SURF_OVERPASS_MISSING` (clase I, bit 13) y
el de clase III `EF_SURF_ALBEDO_GT1` (bit 14, `critical`, contraparte
`earthflux_domain_error`), registrados en la misma función. Total
registrado: 68 códigos (§4.4). Las demás filas de
este catálogo siguen sin registrar y se registran según §7.

#### `EF_INPUT_` (1)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_INPUT_NA` | `EF_INPUT_NA`, `EF_ETRF_NO_VALID_DATE` | fusión (C8) | I (registrado; levantado por los despachadores de M2 con `ef_input_na_flags()`, tests en los módulos) | info | cell, record | 0 (en todas las palabras) | Construido por los despachadores y la orquestación con `!is.na()`; nunca por la función numérica |

#### `EF_SURF_` (21)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_SURF_FILL` | `EF_MODIS_FILL` | prefijo | I (registrado; `modis_apply_scale()`, `modis_variable()`) | info* | cell | 1 | Causa de `NA` |
| `EF_SURF_CLOUD` | `EF_MODIS_CLOUD` | prefijo | I (registrado; `modis_qa_masks()` (MODLAND 10)) | info* | cell | 2 | Causa de `NA`; ambigüedad MOD21 d4 (`modis-products.md` §5.2) se resuelve en la tabla de producto |
| `EF_SURF_NOT_PRODUCED` | `EF_MODIS_NOT_PRODUCED` | prefijo | I (registrado; `modis_qa_masks()` (MODLAND 11; MCD15 SCF_QC 100)) | info* | cell | 3 | Causa de `NA` |
| `EF_SURF_DN_OUT_OF_RANGE` | `EF_MODIS_OUT_OF_RANGE` | prefijo + renombre (C10) | I (registrado; `modis_apply_scale()`, `modis_variable()`) | info* | cell | 4 | Causa de `NA` (rango válido del producto, no dominio físico) |
| `EF_SURF_LAI_NONVEG` | `EF_MODIS_LAI_NONVEG` | prefijo | I (registrado; `modis_lai()`) | info* | cell | 5 | Causa de `NA` en `lai` |
| `EF_SURF_QA_OTHER` | `EF_MODIS_QA_OTHER` | prefijo | I (registrado; `modis_qa_masks()` (MODLAND 01)) | warning* | cell | 6 | Enmascarable con `qa_policy = "mask"` |
| `EF_SURF_CLOUD_ADJACENT` | `EF_MODIS_CLOUD_ADJACENT` | prefijo | I (registrado; `modis_qa_masks()`) | warning* | cell | 7 | – |
| `EF_SURF_SNOW` | `EF_MODIS_SNOW` | prefijo | I (registrado; `modis_qa_masks()`) | warning* | cell | 8 | Formulaciones de G/z_om no válidas sobre nieve |
| `EF_SURF_WATER` | `EF_MODIS_WATER` | prefijo | I (registrado; `modis_qa_masks()`) | warning* | cell | 9 | Ídem para agua |
| `EF_SURF_SALT_PAN` | `EF_MODIS_SALT_PAN` | prefijo | I (registrado; `modis_qa_masks()`) | warning* | cell | 10 | Relevante en salares altiplánicos |
| `EF_SURF_LAI_BACKUP` | `EF_MODIS_LAI_BACKUP` | prefijo | I (registrado; `modis_qa_masks()`) | warning* | cell | 11 | – |
| `EF_SURF_ALBEDO_MAGNITUDE` | `EF_MODIS_ALBEDO_MAGNITUDE` | prefijo | I (registrado; `modis_qa_masks()`) | warning* | cell | 12 | – |
| `EF_SURF_OVERPASS_MISSING` | `EF_OVERPASS_TIME_MISSING` | prefijo + renombre | I (registrado; `modis_surface_state()` con la máscara `missing` de `modis_overpass_time()`, solo donde la LST es válida) | warning* | cell | 13 | LST conservada; geometría solar `NA` aguas abajo |
| `EF_SURF_ALBEDO_GT1` | `EF_MODIS_ALBEDO_GT1` | prefijo | **III** (registrado; `modis_surface_state()` con la máscara `gt1` de `modis_albedo()`; exclusión antes del núcleo con `surface_exclusion()`) | critical* | cell | 14 | `earthflux_domain_error` en G y Rn (C12); valor conservado |
| `EF_SURF_LST_ERROR` | `EF_MODIS_LST_ERROR` | prefijo | II | warning* | cell | libre | Qué categoría de error `TODO` |
| `EF_SURF_EMIS_ERROR` | `EF_MODIS_EMIS_ERROR` | prefijo | II | warning* | cell | libre | `TODO` |
| `EF_SURF_VIEW_ANGLE_HIGH` | `EF_MODIS_VIEW_ANGLE_HIGH` | prefijo | II | warning* | cell | libre | Absorbe `EF_ANCHOR_HIGH_VIEW_ANGLE` por herencia |
| `EF_SURF_COMPOSITE_LAG` | `EF_MODIS_COMPOSITE_LAG` | prefijo | II | warning* | cell | libre | Absorbe `EF_ANCHOR_COMPOSITE_LAG` por herencia |
| `EF_SURF_AGG_INCOMPLETE` | `EF_MODIS_AGG_INCOMPLETE` | prefijo | II | info* | cell | libre | Causa de `NA` |
| `EF_SURF_OVERPASS_OUTSIDE_WINDOW` | `EF_OVERPASS_OUTSIDE_WINDOW` | prefijo | II | warning* | cell | libre | Ventana `TODO` (`soil-heat-flux.md` §3.1) |
| `EF_SURF_LST_IMPLAUSIBLE` | `EF_LST_IMPLAUSIBLE` | prefijo (de Rn a `surface`) | II | warning | cell | libre | `lst ≤ 0` K ya es `earthflux_domain_error`; el rango plausible es `TODO` |

#### `EF_WS_` (26)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_WS_OUT_OF_DOMAIN` | `EF_WS_IMPOSSIBLE` | renombre (C10) | **III** (registrado; `ef_station_qc()`) | critical* | record | — | En `stations` (metadatos) y en el núcleo: `earthflux_domain_error` (WF §2.6, WF-04). Incluye Rs < 0 y precipitación < 0 (M3, `ef_station_ref_et()`) |
| `EF_WS_TMIN_GT_TMAX` | `EF_WS_TMIN_GT_TMAX` | — | **III** (registrado; `ef_station_qc()`) | critical* | record | — | En funciones diarias de ETr: `earthflux_domain_error` |
| `EF_WS_RH_GT100` | `EF_WS_RH_GT100` | — | I (registrado; `ef_station_qc()`) | info | record | — | – |
| `EF_WS_TDEW_GT_TAIR` | `EF_WS_TDEW_GT_TAIR` | — | I (registrado; `ef_station_qc()`) | warning | record | — | Sin tolerancia (una tolerancia instrumental sería clase II). Dos variantes: Tdew > T y eₐ > e°(T) (`vapour_pressure`) |
| `EF_WS_RS_GT_RA` | `EF_RS_EXCEEDS_EXTRATERRESTRIAL` (QC-05b) | división (C5) | I (registrado; `ef_station_qc()`) | warning | record | — | Ra de la misma ventana (integral de la Ec. 28 sobre la parte con sol de la ventana); ventanas con Ra = 0 quedan para QC-05d (clase II) |
| `EF_WS_TIME_GAP` | `EF_WS_TIME_GAP` | — | I (registrado; `ef_station_qc()`) | warning | record | — | – |
| `EF_WS_TIME_IRREGULAR` | `EF_WS_TIME_IRREGULAR` | — | I (registrado; `ef_station_qc()`) | warning | record | — | Inequívoco dado el `timestep` declarado (no estaba en la lista de candidatos de WF §3.2) |
| `EF_WS_INCOMPLETE_DAY` | `EF_WS_INCOMPLETE_DAY` | — | I (registrado en `ef_flags_reference_et()`; lo levanta `ef_station_ref_et()`, tabla `etr_24`) | warning | record | — | Política de huecos (WF-11): solo `day_completeness = "all_periods"`; no cambia la condición |
| `EF_WS_HEIGHT_MISSING` | `EF_WS_HEIGHT_MISSING` | — | I (registrado; `ef_station_qc()`) | warning | record | — | – |
| `EF_WS_HEIGHT_NONSTANDARD` | `EF_WS_HEIGHT_NONSTANDARD` | — | I (registrado; `ef_station_qc()`) | warning | record | — | Altura ≠ 2 m exacta |
| `EF_WS_RS_RSO_LIMITED` | `EF_WS_RS_RSO_LIMITED` | — | I-m (registrado; `ef_ref_net_radiation()`, `R/reference-et.R`) | info | record | — | Límite 1.0 de FAO-56 Ec. 39 y límites 0,3–1,0 de ASCE-EWRI 2005 Ec. 18 y 45 (`VERIFICADA`) |
| `EF_WS_OVERPASS_OUTSIDE_RECORDS` | `EF_WS_OVERPASS_OUTSIDE_RECORDS` | — | I (registrado en `ef_flags_reference_et()`; lo levanta `ef_station_ref_et()`, tabla `etr_inst`) | info* | record | — | Causa de `NA`; el soporte depende de la opción (O1: inicio del primer período a fin del último; O3: primer a último punto medio) |
| `EF_WS_ETR_NEGATIVE` | `EF_ETREF_NEGATIVE` | prefijo + renombre | I (registrado; `ef_ref_et()`, `R/reference-et.R`) | info | record | — | Cubre ETr y ETo (tipo en la procedencia); ámbito `cell` si se adopta la opción C (FL-09) |
| `EF_WS_IMPLAUSIBLE` | `EF_WS_IMPLAUSIBLE` | — | II | warning | record | — | Límites de `water` sin cita: no se adoptan |
| `EF_WS_RH_RECALIBRATE` | `EF_WS_RH_RECALIBRATE` | — | II | warning | record | — | Rango [3, 5] % de FAO-56; falta elegir δ (WF-06) |
| `EF_WS_RS_GT_RSO` | `EF_WS_RS_GT_RSO` | — | II | warning | record | — | Margen `TODO` |
| `EF_WS_RS_CALIBRATION` | `EF_WS_RS_CALIBRATION` | — | II | warning | record | — | `TODO` |
| `EF_WS_RS_NIGHT` | `EF_WS_RS_NIGHT` | — | II | info | record | — | Tolerancia de ruido `TODO` |
| `EF_WS_PERSISTENCE` | `EF_WS_PERSISTENCE` | — | II | warning | record | — | N y tolerancia `TODO` |
| `EF_WS_STEP` | `EF_WS_STEP` | — | II | warning | record | — | `TODO` |
| `EF_WS_RHMAX_LOW` | `EF_WS_RHMAX_LOW` | — | II | warning | record | — | Rango [80, 90] % de FAO-56; falta elegir valor y ventana (WF-06) |
| `EF_WS_NONREFERENCE` | `EF_WS_NONREFERENCE` | — | II | info | record | — | "Sistemáticamente" requiere ventana; uso horario `TODO` |
| `EF_WS_EA_DIURNAL` | `EF_WS_EA_DIURNAL` | — | II | info | record | — | `TODO` |
| `EF_WS_TIME_SHIFT` | `EF_WS_TIME_SHIFT` | — | II | warning | record | — | Tolerancia `TODO` |
| `EF_WS_SPATIAL_OUTLIER` | `EF_WS_SPATIAL_OUTLIER` | — | II | warning | record | — | `TODO` (insumo: residuos LOO de `spatial`) |
| `EF_WS_CLOUDY_OVERPASS` | `EF_STATION_CLOUDY` (dos documentos) | fusión (C6) + prefijo | II | warning | record | — | Umbrales de `water` sin cita: no se adoptan |

#### `EF_GWR_` (19)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_GWR_EXTRAPOLATION_COVARIATE` | ídem | — | I (registrado) | warning | cell | 1 | Heredado por anclas (C7) |
| `EF_GWR_EXTRAPOLATION_LOCAL` | ídem | — | I (registrado) | info | cell | 2 | – |
| `EF_GWR_OUTSIDE_HULL` | ídem | — | I (registrado) | warning | cell | 3 | Heredado por anclas (C7) |
| `EF_GWR_FEW_NEIGHBOURS` | ídem | — | I (registrado) | warning | cell, record | 4 | Con el mínimo matemático p + 1; un mínimo mayor exige referencia y se registra como parámetro |
| `EF_GWR_LOCAL_SINGULAR` | ídem | — | I (registrado) | warning | cell | 5 | En una **estación**: `earthflux_gwr_singular_error` |
| `EF_GWR_OUT_OF_DOMAIN` | `EF_GWR_PHYSICAL_RANGE` | renombre (C10) | **III** (registrado; `ef_regionalize()`) | critical* | cell | 6 | Consumidores (`evapotranspiration.md` §1.3, ETr) rechazan con `earthflux_domain_error`; la plausibilidad (p. ej., clearness > 1 + margen) queda `TODO` sin código |
| `EF_GWR_COARSE_MODE` | ídem | — | I | info | object | — | Derivado de `provenance$prediction_mode` |
| `EF_GWR_TRANSFORMED` | ídem | — | I | info | object | — | Solo si GW-12 admite transformaciones |
| `EF_GWR_SURFACE_COVARIATE` | ídem | — | I (registrado) | warning | object | — | Derivado de la lista de covariables en la procedencia |
| `EF_GWR_BW_AT_BOUND` | ídem | — | I (registrado) | warning | object | — | – |
| `EF_GWR_BW_MULTIMODAL` | ídem | — | I (registrado) | info | object | — | Dada la rejilla registrada |
| `EF_GWR_AICC_UNDEFINED` | ídem | — | I (registrado) | info | object | — | Sin bandwidth factible: `earthflux_gwr_no_feasible_bandwidth` |
| `EF_GWR_GLOBAL_PREFERRED` | ídem | — | I (registrado) | info | object | — | – |
| `EF_GWR_STATION_EXCLUDED` | ídem | — | I (registrado) | info | record | — | `index` = estaciones excluidas en `station_table` |
| `EF_GWR_SINGLE_STATION` | `EF_FORCING_SINGLE_STATION` | prefijo + renombre | I (registrado) | info | object | — | Derivado de `provenance$method == "station"` |
| `EF_GWR_FAR_FROM_STATIONS` | ídem | — | II | warning | cell | libre | `d_max` `TODO` |
| `EF_GWR_ILL_CONDITIONED` | ídem | — | II | warning | cell, record | libre | `kappa_max` `TODO` |
| `EF_GWR_FEW_STATIONS` | ídem | — | II | warning | object | — | n < p + 3: `earthflux_gwr_insufficient_stations`; `n_min` `TODO` |
| `EF_GWR_ELEVATION_MISMATCH` | ídem | — | II | warning | record | — | `TODO` |

#### `EF_RAD_` (5)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_RAD_SELF_SHADED` | `EF_SELF_SHADED` | prefijo | I (registrado) | info | cell | 1 | Irradiancia directa = 0 por definición, no por corrección |
| `EF_RAD_ATM_EMISSIVITY_GT1` | `EF_ATM_EMISSIVITY_GT1` | prefijo | I (registrado) | warning | cell | 2 | Salida de modelo empírico; sin recorte |
| `EF_RAD_RS_GT_RA` | `EF_RS_EXCEEDS_EXTRATERRESTRIAL` (radiación) | división (C5) | I (registrado) | warning | cell, record | 3 | Instantánea, plano horizontal |
| `EF_RAD_RN_NEGATIVE` | "Rn negativo" (sin código) | nombrado | I (registrado) | info* | cell | 4 | Rn < 0 es posible; `ef_net_radiation.md` §10.1: sin warning (el flag no emite warning) |
| `EF_RAD_SUN_LOW` | `EF_LOW_SUN` | prefijo + orden | II | warning | cell | libre | `TODO` |

#### `EF_G_` (6)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_G_RN_NONPOSITIVE` | ídem | — | I (registrado) | warning | cell | 1 | `g_rn_ratio = NA` si Rn = 0 |
| `EF_G_RATIO_NEGATIVE` | ídem | — | I (registrado) | warning | cell | 2 | – |
| `EF_G_AVAILABLE_NONPOSITIVE` | `EF_G_EXCEEDS_RN`, `EF_AVAILABLE_ENERGY_NONPOSITIVE` | fusión (C3) | I (registrado) | warning | cell | 3 | Condición Rn − G ≤ 0 (incluye G = Rn y Rn ≤ 0) |
| `EF_G_LOW_LAI_BRANCH` | ídem | — | I-m (registrado) | info | cell | 4 | LAI < 0.5 es parte de Tasumi (`CANDIDATA`); registrado con `ef_g_tasumi()` `CANDIDATA` (regla M2, `DECISIONS.md` §1.0) |
| `EF_G_NDVI_NONPOSITIVE` | ídem | — | II | warning | cell | libre | Condición sin umbral numérico, pero su significado (agua/nieve) proviene de una fuente terciaria: registrar al verificar D4 |
| `EF_G_RATIO_IMPLAUSIBLE` | ídem | — | II | warning | cell | libre | D7 `TODO` |

#### `EF_ANCHOR_` (14)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_ANCHOR_USER_SUPPLIED` | ídem | — | I (registrado) | info | object | — | Derivado de `origin == "user"` |
| `EF_ANCHOR_CRITERIA_RELAXED` | ídem | — | I (registrado) | warning | object | — | Sin candidatos: `earthflux_anchor_no_candidates` |
| `EF_ANCHOR_SEARCH_EXPANDED` | ídem | — | I (registrado) | warning | object | — | – |
| `EF_ANCHOR_HOMOGENEITY_DROPPED` | ídem | — | I (registrado) | warning | object | — | – |
| `EF_ANCHOR_WINDOW_INCOMPLETE` | ídem | — | I (registrado) | warning | record | — | `index` = filas de `pixels` (D-AP-10) |
| `EF_ANCHOR_TIES` | ídem | — | I (registrado) | info | object | — | – |
| `EF_ANCHOR_SINGLE_PIXEL` | ídem | — | I (registrado) | info | object | — | – |
| `EF_ANCHOR_COLD_H_NEGATIVE` | ídem | — | I (registrado) | warning | record | — | – |
| `EF_ANCHOR_HOT_LE_ASSUMED_ZERO` | ídem | — | I (registrado) | info | object | — | Derivado de `conditions` |
| `EF_ANCHOR_OVERPASS_SPREAD` | ídem | — | I (registrado) | info | object | — | Diferencia exacta de horas; la magnitud tolerable sería otro código (II) |
| `EF_ANCHOR_FEW_CANDIDATES` | ídem | — | II | warning | object | — | `TODO` (20 de `water` sin referencia) |
| `EF_ANCHOR_CONTRAST_LOW` | `EF_ANCHOR_SMALL_CONTRAST`, `EF_ANCHOR_DT_SMALL` | fusión (C4) | II | warning | object | — | Ts_hot ≤ Ts_cold: `earthflux_anchor_inverted` |
| `EF_ANCHOR_COLD_PARTIAL_COVER` | ídem | — | II | warning | record | — | `TODO` |
| `EF_ANCHOR_HOT_RECENT_RAIN` | ídem | — | II | warning | object | — | Umbral y ventana `TODO` |

#### `EF_H_` (13)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_H_ZOM_FLOOR_APPLIED` | `EF_ZOM_FLOOR_APPLIED` | prefijo | I-m | info | cell | 1 | Mínimo 0.005 m no verificado (SH-02): no se registra antes de verificarlo |
| `EF_H_ZOM_TERRAIN_ADJUSTED` | `EF_ZOM_TERRAIN_ADJUSTED` | prefijo | I | info | cell | 2 | Solo con el método de terreno |
| `EF_H_WIND_FLOOR_APPLIED` | `EF_WIND_FLOOR_APPLIED` | prefijo + orden | I | warning | cell, object | 3 | Solo si SH-06 admite el piso; valor del usuario en la procedencia |
| `EF_H_USTAR_INVALID` | `EF_USTAR_INVALID` | prefijo | I (registrado) | warning | cell | 4 | En un ancla: `earthflux_calibration_error` |
| `EF_H_PIXEL_NOT_CONVERGED` | ídem | — | I (registrado) | warning | cell | 5 | – |
| `EF_H_DT_EXTRAPOLATED_HOT` | `EF_DT_EXTRAPOLATED_HOT` | prefijo | I (registrado) | info | cell | 6 | – |
| `EF_H_DT_EXTRAPOLATED_COLD` | `EF_DT_EXTRAPOLATED_COLD` | prefijo | I (registrado) | info | cell | 7 | – |
| `EF_H_NEGATIVE` | `EF_DT_NEGATIVE`, `EF_LE_EXCEEDS_AVAILABLE` | fusión (C2) | I (registrado) | info | cell | 8 | – |
| `EF_H_GT_AVAILABLE` | `EF_H_EXCEEDS_AVAILABLE` | renombre (vocabulario) | I (registrado) | warning | cell | 9 | Causa de `EF_ET_NEGATIVE` cuando Rn − G > 0 |
| `EF_H_CALIBRATION_NOT_CONVERGED` | `EF_H_NOT_CONVERGED` | renombre (C11) | I (registrado) | critical* | object | — | Además `earthflux_convergence_warning`; a, b o u* no finitos en un ancla: `earthflux_calibration_error` |
| `EF_H_DT_SLOPE_NONPOSITIVE` | `EF_DT_SLOPE_NONPOSITIVE` | prefijo | I (registrado) | critical* | object | — | Ts_hot ≤ Ts_cold: error (anclas invertidas / b indefinida) |
| `EF_H_WIND_LOW` | `EF_LOW_WIND` | prefijo + orden | II | warning | cell, object | libre | u_b = 0 en un ancla: `earthflux_calibration_error` |
| `EF_H_STABILITY_STRONG` | `EF_STRONGLY_STABLE` | prefijo + orden | II | warning | cell | libre | `TODO` |

#### `EF_ET_` (7)

| Código | Anterior(es) | Cambio | Clase | Sev. | Ámbito | Bit | Contraparte de error / nota |
|---|---|---|---|---|---|---|---|
| `EF_ET_NEGATIVE` | `EF_ET_NEGATIVE`, `EF_LE_NEGATIVE` | fusión (C1) | I (registrado; levantado por `ef_diagnose_et()` desde M2, test en `test-et.R`) | warning | cell | 1 | Se evalúa sobre cada capa (ET_inst, ETa_24, ET_per): con ETr_24 = 0 pueden diferir |
| `EF_ET_PERIOD_EXTRAPOLATED` | `EF_ETRF_EXTRAPOLATED` | prefijo + renombre | I | warning | cell | 2 | Por defecto **error** si el período excede las fechas; flag solo con `extrapolation = "constant"` |
| `EF_ET_PERIOD_SINGLE_DATE` | `EF_ETRF_SINGLE_DATE` | prefijo + renombre | I | warning | cell | 3 | Ídem |
| `EF_ET_PERIOD_SPLINE_OVERSHOOT` | `EF_ETRF_SPLINE_OVERSHOOT` | prefijo + renombre | I | warning | cell | 4 | Solo con interpolación spline |
| `EF_ET_PERIOD_ETR24_FILLED` | `EF_ETR24_FILLED` | prefijo + renombre | I | info | cell, object | 5 | Sin `fill.gaps`: `earthflux_missing_input` |
| `EF_ET_ETRF_IMPLAUSIBLE` | `EF_ETRF_IMPLAUSIBLE` | prefijo | II | warning | cell | libre | ET-D5; indicios terciarios/secundarios no bastan |
| `EF_ET_PERIOD_GAP_LONG` | `EF_ETRF_GAP_LONG` | prefijo + renombre | II | warning | cell | libre | ET-D10 |

### 4.3 Códigos retirados por herencia (R-HER, C7)

| Código propuesto | Fuente | Sustituto |
|---|---|---|
| `EF_ANCHOR_QA_DEGRADED` | `anchor-pixels.md` §6 | Códigos `EF_SURF_*` activos en la celda del ancla (`inherited_flags`) |
| `EF_ANCHOR_HIGH_VIEW_ANGLE` | `anchor-pixels.md` §6 | `EF_SURF_VIEW_ANGLE_HIGH` heredado |
| `EF_ANCHOR_COMPOSITE_LAG` | `anchor-pixels.md` §6 | `EF_SURF_COMPOSITE_LAG` heredado |
| `EF_ANCHOR_FORCING_EXTRAPOLATED` | `anchor-pixels.md` §6; `gwr-forcing.md` §6.3 | `EF_GWR_EXTRAPOLATION_COVARIATE` o `EF_GWR_OUTSIDE_HULL` heredados (la definición de `gwr-forcing.md` §6.3 se conserva como regla de lectura) |

Cada uno de los 120 códigos inventariados aparece exactamente una vez en la
columna "Anterior(es)" de §4.2 o en esta tabla (salvo
`EF_RS_EXCEEDS_EXTRATERRESTRIAL`, que aparece en las dos filas de su
división).

### 4.4 Recuento por clase y etapa

| Prefijo | I | II | III | Total | Registrados |
|---|---|---|---|---|---|
| `INPUT` | 1 | 0 | 0 | 1 | 1 |
| `SURF` | 13 | 7 | 1 | 21 | 14 |
| `WS` | 11 | 13 | 2 | 26 | 13 |
| `GWR` | 14 | 4 | 1 | 19 | 13 |
| `RAD` | 4 | 1 | 0 | 5 | 4 |
| `G` | 4 | 2 | 0 | 6 | 4 |
| `ANCHOR` | 10 | 4 | 0 | 14 | 10 |
| `H` | 11 | 2 | 0 | 13 | 8 |
| `ET` | 5 | 2 | 0 | 7 | 1 |
| **Total** | **73** | **35** | **4** | **112** | **68** |

Registrados (armonización M4, 2026-11-04; recuento de
`ef_flag_registry()`): **68 códigos** — `INPUT` 1, `RAD` 4, `G` 4,
`ANCHOR` 10, `H` 8, `ET` 1 (los 28 de M2), `WS` 13 y `GWR` 13 (los 26 de
M3) y `SURF` 14 (M4); 64 de clase I y 4 de clase III
(`EF_WS_OUT_OF_DOMAIN`, `EF_WS_TMIN_GT_TMAX`, `EF_GWR_OUT_OF_DOMAIN`,
`EF_SURF_ALBEDO_GT1`), todos ejercitados por un test de su módulo (R11,
sin excepciones); ningún código de clase II (los 35 siguen en la guardia
de `test-diagnostics.R`).

Superficie (M4, 2026-11-04): los 13 `EF_SURF_*` de clase I y el de clase
III están registrados en `ef_flags_surface()` (`R/modis-qa.R`): 12
levantados por los decodificadores (bits 1–12), `EF_SURF_OVERPASS_MISSING`
(bit 13) y `EF_SURF_ALBEDO_GT1` (bit 14, `critical`) levantados por
`modis_surface_state()` (`R/modis-surface.R`). Los 7 de clase II siguen en
la guardia; `EF_SURF_AGG_INCOMPLETE` y `EF_SURF_COMPOSITE_LAG` tienen ya
sus insumos (`modis_to_grid()$incomplete`, `lag_days`) a la espera de un
umbral con referencia.

M2 (armonización M2): 28 códigos, todos de clase I: `EF_INPUT_NA` y
`EF_ET_NEGATIVE` (registrados en M0 y levantados desde M2), los 4 `EF_RAD_*` de clase I, los 4 `EF_G_*` de clase
I (incluido el I-m `EF_G_LOW_LAI_BRANCH`, registrado con su método
`CANDIDATA` como excepción a §7, punto 3; `DECISIONS.md` §1.2, M2-03), los
10 `EF_ANCHOR_*` de clase I y 8 de los 11 `EF_H_*` de clase I. Sin
registrar en M2: `EF_H_ZOM_FLOOR_APPLIED` (I-m, SH-02),
`EF_H_ZOM_TERRAIN_ADJUSTED` (método de terreno no implementado),
`EF_H_WIND_FLOOR_APPLIED` (SH-06) y los 4 `EF_ET_PERIOD_*` de clase I
(`ef_et_period()` no implementada).

Estaciones y ET de referencia (M3, 2026-11-04): los 13 `EF_WS_*` de
clase I y III están registrados: 9 en `ef_flags_stations()` (`ef_station_qc()`;
los 2 de clase III con severidad `critical`) y 4 en
`ef_flags_reference_et()` (`EF_WS_RS_RSO_LIMITED`, `EF_WS_ETR_NEGATIVE`,
`EF_WS_INCOMPLETE_DAY`, `EF_WS_OVERPASS_OUTSIDE_RECORDS`); los 13 de clase
II siguen en la guardia.

Núcleo GWR (M3, 2026-11-04): 10 `EF_GWR_*` de clase I registrados en
`ef_flags_gwr()` (`R/gwr-diagnostics.R`) y levantados por `ef_gwr_fit()`,
`ef_gwr_bandwidth()` y `ef_gwr_predict()`: los 5 de ámbito `cell` (bits
1–5) y `EF_GWR_BW_AT_BOUND`, `EF_GWR_BW_MULTIMODAL`,
`EF_GWR_AICC_UNDEFINED`, `EF_GWR_GLOBAL_PREFERRED`,
`EF_GWR_STATION_EXCLUDED`. Orquestación (`ef_regionalize()`,
`ef_regionalize_cv()`, M3): se registran `EF_GWR_SURFACE_COVARIATE` y
`EF_GWR_SINGLE_STATION` (clase I, objeto, derivados de la procedencia) y el
de clase III `EF_GWR_OUT_OF_DOMAIN` (celda, bit 6, `critical`, contraparte
`earthflux_domain_error`; el valor se conserva). Siguen sin registrar
`EF_GWR_COARSE_MODE` (modo grueso no implementado, GW-08) y
`EF_GWR_TRANSFORMED` (solo identidad, GW-12); los 4 de clase II siguen en
la guardia.

De la clase I, 3 son I-m (`EF_WS_RS_RSO_LIMITED`, `EF_G_LOW_LAI_BRANCH`,
`EF_H_ZOM_FLOOR_APPLIED`). Varios de clase I están además **condicionados
a una decisión** de su especificación (el flag solo existe si se adopta
la opción): `EF_GWR_TRANSFORMED` (GW-12), `EF_H_WIND_FLOOR_APPLIED`
(SH-06), `EF_H_ZOM_TERRAIN_ADJUSTED` (método de terreno),
`EF_ET_PERIOD_*` (`ef_et_period()` es opcional y posterior).

---

## 5. Severidad

### 5.1 Situación actual

`R/diagnostics.R` admite `"info"` y `"warning"`, y el test
`flag registry has unique codes and valid severities` lo verifica.
`weather-forcing.md` §3.2 ya propone una tercera severidad, `error`, para
`EF_WS_IMPOSSIBLE` y `EF_WS_TMIN_GT_TMAX`, y `qc_policy =
"exclude_error"`; es decir, el sistema ya necesita un tercer nivel, pero
sin definirlo.

### 5.2 Evaluación

| Argumento | A favor de un tercer nivel | En contra |
|---|---|---|
| Clase III (§4.3) | Los valores imposibles conservados en módulos de datos necesitan un nivel que la política excluya **por defecto**; "warning" significa "usable con cuidado", que no es el caso | – |
| Fallos de procedimiento | Una calibración que no cumple su propio criterio (`EF_H_CALIBRATION_NOT_CONVERGED`) o una recta dT con pendiente ≤ 0 invalidan **todo** el objeto, no un valor | Se podría resolver solo con errores, pero el principio 6 y `sensible-heat.md` §11.6 piden devolver el último iterado para auditoría |
| Resumen | La capa de severidad máxima (§6.5) necesita distinguir "usar con cuidado" de "no usar" | – |
| Nombre | – | Un nivel llamado `error` se confunde con las condiciones R `earthflux_error`: un flag nunca detiene la ejecución |
| Inflación | – | Riesgo de escalar flags a `critical` sin criterio |

Conclusión: **se propone un tercer nivel, `critical`** (no `error`), con
criterio cerrado para evitar inflación.

### 5.3 Definiciones (orden `info` < `warning` < `critical`)

| Nivel | Código numérico (§6.5) | Significado | Criterio de asignación |
|---|---|---|---|
| `info` | 1 | Auditoría o contexto; el valor es utilizable sin acción | Registro de una regla de método aplicada; causa de un `NA` (el `NA` ya impide el uso; el flag explica por qué, como `EF_INPUT_NA`); condición posible y esperable (p. ej., H < 0 por advección) |
| `warning` | 2 | Valor utilizable, pero obtenido fuera de condiciones típicas, por extrapolación o bajo un supuesto; interpretar con cuidado | Valor conservado anómalo pero físicamente posible (principio 6); extrapolación; calidad de producto no óptima |
| `critical` | 3 | El valor (u objeto) **no** debe usarse para cálculo ni interpretación sin acción explícita del usuario; se conserva solo para auditoría | Solo si (a) la condición es una imposibilidad física o lógica que el núcleo rechaza con error (clase III), o (b) un procedimiento no cumplió su propio criterio de validez e invalida el objeto completo. Toda fila `critical` del registro declara su contraparte de error o su procedimiento (§8, R9) |

Políticas: `qc_policy` y `qa_policy` (nombres por decidir en sus
especificaciones) excluyen `critical` por defecto (`"exclude_critical"`,
en lugar de `"exclude_error"`), cuentan cada exclusión y la registran en
la procedencia (§6.6). `"keep_all"` permite auditar, pero el núcleo sigue
rechazando valores fuera de dominio con error.

La tercera severidad entra a `R/diagnostics.R` **junto con el primer
código que la use** (§7), no antes. *Enmienda (2026-11-04):* con la
adopción provisional de FL-05 y FL-06 (`DECISIONS.md` §1.0), `critical` ya
es un nivel válido del registro (`ef_flag_severity_levels()`), aunque
todavía ningún código registrado lo usa.

### 5.4 Cambios de severidad respecto de las fuentes

| Código | Fuente | Propuesta | Justificación |
|---|---|---|---|
| `EF_WS_OUT_OF_DOMAIN`, `EF_WS_TMIN_GT_TMAX` | `error` | `critical` | Mismo significado sin confundirse con condiciones R |
| `EF_GWR_OUT_OF_DOMAIN` | warning | `critical` | Imposibilidad (eₐ ≤ 0, u < 0, …) que los consumidores rechazan |
| `EF_SURF_ALBEDO_GT1` | — | `critical` | Imposible por definición; G y Rn lo rechazan con error (C12) |
| `EF_H_CALIBRATION_NOT_CONVERGED` | warning (escena) | `critical` | La calibración no cumplió su propio criterio; H, LE y ET de toda la escena dependen de ella. Se conserva el `earthflux_convergence_warning` |
| `EF_H_DT_SLOPE_NONPOSITIVE` | warning | `critical` | Con anclas bien ordenadas, b ≤ 0 hace que H no crezca con Ts: la calibración contradice el supuesto de linealidad dT–Ts de METRIC |
| `EF_SURF_*` (resto) | — | info (causas de `NA`) / warning (valores conservados) | `modis-products.md` §10.2 no indicaba severidades; se aplica §5.3 |
| `EF_WS_OVERPASS_OUTSIDE_RECORDS` | — | info | Causa de `NA` |
| `EF_RAD_RN_NEGATIVE` | "sin warning" | info | Coherente: el flag no emite `warning()` |

Los dos cambios de `EF_H_*` contradicen `sensible-heat.md` §16 y quedan
como decisión FL-06.

---

## 6. Representación: cómo viajan los flags con los resultados

### 6.1 Tres ámbitos, una representación canónica cada uno

| Ámbito | Elemento | Representación canónica | Ejemplos |
|---|---|---|---|
| `cell` | Posición de un vector o celda de un `SpatRaster` | **Vector numérico**: registros `earthflux_flag` (índices, como hoy `ef_flag()`). **Ráster**: palabra entera de bits por capa de salida (§6.3) | `EF_ET_NEGATIVE`, `EF_SURF_CLOUD`, `EF_GWR_OUTSIDE_HULL` |
| `record` | Fila de una tabla | Registro `earthflux_flag` con `index` = filas de la tabla (`observations`, `station_table`, `anchors$pixels`) | `EF_WS_TIME_GAP`, `EF_GWR_STATION_EXCLUDED`, `EF_ANCHOR_WINDOW_INCOMPLETE` |
| `object` | Escena, ajuste, conjunto de anclas, corrida | Registro `earthflux_flag` con `n_total = 1` (`ef_flag(TRUE, code)`) en el elemento `flags` del objeto | `EF_H_CALIBRATION_NOT_CONVERGED`, `EF_GWR_BW_AT_BOUND`, `EF_ANCHOR_TIES` |

Los flags de objeto derivados de la configuración (`EF_GWR_COARSE_MODE`,
`EF_GWR_SINGLE_STATION`, `EF_ANCHOR_USER_SUPPLIED`, …) se **calculan desde
la procedencia** (fuente única de verdad) y un test verifica la
coherencia flag ↔ campo de procedencia.

La tabla larga `$qc` de `ef_station_qc()` (`weather-forcing.md` §3.1) es
la vista de auditoría del ámbito `record` para estaciones; su columna
`flag_code` solo admite códigos registrados y debe ser equivalente
(test R16) al conjunto de registros `earthflux_flag` sobre las filas de
`observations` (FL-13).

### 6.2 Registro `earthflux_flag` (extensión propuesta)

**Estado de implementación (M3, 2026-11-04).** Implementados: `stage` y
`scope` (en todo registro, desde M2, `ef_flag()`) y **`target`**, adoptado
(`DECISIONS.md` §1.3, M3-18; `ARCHITECTURE.md` §3.5) para los objetos con
varias tablas a las que puede referirse `index`: primer uso,
`ef_station_ref_et()` (`"series"`, `"etr_inst"`, `"etr_24"`, con
`provenance$flags_evaluated_by_target`). Los objetos de una sola tabla o
vector no lo llevan, y las superficies regionalizadas no usan registros
con índice de celda (los flags de celda viven en `flag_word`, §6.3). Sin
implementar: `time` (una superficie lleva sus `target_time` en el objeto y
en los nombres de capa) y `parameters` (ningún código con parámetro está
registrado).

Campos de M0: `code`, `severity`, `description`, `index`, `n_flagged`,
`n_total`. Se proponen, para cuando se implemente la primera función
espacial:

| Campo | Contenido |
|---|---|
| `stage` | Prefijo/etapa (copiado del registro) |
| `scope` | `"cell"`, `"record"` u `"object"` |
| `target` | Capa o tabla a la que se refiere `index` (p. ej., `"eta_24"`, `"observations"`, `"pixels"`) |
| `time` | `target_time`/fecha de escena (`POSIXct` UTC) o `NULL` |
| `parameters` | `NULL` para clase I/III; para flags con parámetro: valor, unidad, clave de referencia y estado (§6.7) |

`index` sigue siendo entero 1-based: posición del vector, fila de la
tabla o número de celda del ráster (el mismo que devuelve `which()` sobre
los valores de la capa). La máscara se construye siempre como
`!is.na(x) & condición` (`ef_flag()` exige máscara sin `NA`).

### 6.3 Ráster: palabra de flags por capa de salida

Generaliza la enmienda A1 de `gwr-forcing.md` §2.5 y la política QA de
`modis-products.md` §10 a todo el paquete:

1. **Una palabra por capa de salida.** Cada capa de resultado `L` tiene una
   capa compañera entera `flags_<L>` (p. ej., `flags_lst`, `flags_albedo`,
   `flags_air_temperature_<YYYYmmddTHHMMSSZ>`, `flags_rn`, `flags_g`,
   `flags_h`, `flags_et_inst`, `flags_etrf`, `flags_eta_24`). Motivo: una
   misma condición puede diferir entre capas de la misma etapa
   (`EF_ET_NEGATIVE` en ET_inst y ETa_24 cuando ETr_24 = 0,
   `evapotranspiration.md` §7.1; `EF_SURF_FILL` en LST y en albedo).
2. **Tabla de bits por etapa.** La palabra de `L` usa la tabla de bits de
   la etapa que produce `L` (§6.4). La tabla es una vista del registro
   (`ef_flag_registry()` columnas `stage` y `bit`); `gwr_flag_bits()`
   (`gwr-forcing.md` §9.2) se reemplaza por esa vista (una sola fuente).
3. **Bits disponibles: 0–30 (31 bits).** El bit 31 queda prohibido: los
   enteros de R son de 32 bits con signo, `NA_integer_` es exactamente el
   patrón con solo el bit 31 activo, y `bitwAnd()`/`bitwOr()` operan sobre
   enteros de R. Valor máximo de una palabra: 2³¹ − 1 = 2 147 483 647,
   exacto también en `double` (lo que usa `terra` en memoria).
4. **Bit 0 reservado para `EF_INPUT_NA`** en todas las palabras: es el
   único código compartido entre etapas.
5. **Semántica de valores.** `0` = condiciones evaluadas y ninguna activa;
   `NA` = no evaluado (fuera del AOI o del dominio de cálculo). Una palabra
   nunca es `NA` donde la capa `L` fue evaluada.
6. **Tipo en disco:** entero de 32 bits con signo (`INT4S` en `terra`),
   cuyo valor `NA` por defecto coincide con `NA_integer_`. La tabla de bits
   viaja con el archivo (metadatos del archivo o archivo acompañante; el
   mecanismo concreto en `terra` es `TODO` verificar).
7. **Construcción** (orquestación, no funciones numéricas):
   `w = Σ_k 2^bit_k · m_k` con máscaras `m_k` ∈ {0, 1} sin `NA`; exacto
   porque los bits son distintos. **Lectura:** `(w %/% 2^k) %% 2`, la misma
   aritmética de `modis-products.md` §10.4 (disponibilidad de `%/%` y `%%`
   como álgebra de `terra`: `TODO` verificar).
8. **Capacidad.** Si una etapa llegara a 30 códigos de ámbito `cell`, se
   abre una segunda palabra para esa etapa (`flags_<L>_2`) en lugar de usar
   el bit 31; el plan de §6.4 deja holgura amplia en todas.

### 6.4 Tabla de asignación de bits (plan)

Los bits de esta tabla son el **plan**; solo son vinculantes cuando el
código entra al registro (§7). Los códigos de clase II con ámbito `cell`
reciben el siguiente bit libre al registrarse. Un bit asignado nunca se
reutiliza ni se renumera (aunque el código se retire).

| Bit | `SURF` (lst, emissivity, albedo, ndvi, lai, overpass_time) | `GWR` (cada variable × `target_time`) | `RAD` (rn y componentes) | `G` (g, g_rn_ratio) | `H` (h, rah, dt) | `ET` (et_inst, etrf, eta_24, et_period) |
|---|---|---|---|---|---|---|
| 0 | `EF_INPUT_NA` | `EF_INPUT_NA` | `EF_INPUT_NA` | `EF_INPUT_NA` | `EF_INPUT_NA` | `EF_INPUT_NA` |
| 1 | `EF_SURF_FILL` | `EF_GWR_EXTRAPOLATION_COVARIATE` | `EF_RAD_SELF_SHADED` | `EF_G_RN_NONPOSITIVE` | `EF_H_ZOM_FLOOR_APPLIED` | `EF_ET_NEGATIVE` |
| 2 | `EF_SURF_CLOUD` | `EF_GWR_EXTRAPOLATION_LOCAL` | `EF_RAD_ATM_EMISSIVITY_GT1` | `EF_G_RATIO_NEGATIVE` | `EF_H_ZOM_TERRAIN_ADJUSTED` | `EF_ET_PERIOD_EXTRAPOLATED` |
| 3 | `EF_SURF_NOT_PRODUCED` | `EF_GWR_OUTSIDE_HULL` | `EF_RAD_RS_GT_RA` | `EF_G_AVAILABLE_NONPOSITIVE` | `EF_H_WIND_FLOOR_APPLIED` | `EF_ET_PERIOD_SINGLE_DATE` |
| 4 | `EF_SURF_DN_OUT_OF_RANGE` | `EF_GWR_FEW_NEIGHBOURS` | `EF_RAD_RN_NEGATIVE` | `EF_G_LOW_LAI_BRANCH` | `EF_H_USTAR_INVALID` | `EF_ET_PERIOD_SPLINE_OVERSHOOT` |
| 5 | `EF_SURF_LAI_NONVEG` | `EF_GWR_LOCAL_SINGULAR` | libre | libre | `EF_H_PIXEL_NOT_CONVERGED` | `EF_ET_PERIOD_ETR24_FILLED` |
| 6 | `EF_SURF_QA_OTHER` | `EF_GWR_OUT_OF_DOMAIN` | | | `EF_H_DT_EXTRAPOLATED_HOT` | libre |
| 7 | `EF_SURF_CLOUD_ADJACENT` | libre | | | `EF_H_DT_EXTRAPOLATED_COLD` | |
| 8 | `EF_SURF_SNOW` | | | | `EF_H_NEGATIVE` | |
| 9 | `EF_SURF_WATER` | | | | `EF_H_GT_AVAILABLE` | |
| 10 | `EF_SURF_SALT_PAN` | | | | libre | |
| 11 | `EF_SURF_LAI_BACKUP` | | | | | |
| 12 | `EF_SURF_ALBEDO_MAGNITUDE` | | | | | |
| 13 | `EF_SURF_OVERPASS_MISSING` | | | | | |
| 14 | `EF_SURF_ALBEDO_GT1` | | | | | |
| 15–30 | libres | 7–30 libres | 5–30 libres | 5–30 libres | 10–30 libres | 6–30 libres |

Ocupación si se registraran **todos** los códigos `cell` (incluidos los
de clase II): `SURF` 22/31, `GWR` 9/31, `RAD` 6/31, `G` 7/31, `H` 12/31,
`ET` 8/31 (contando el bit 0). Una sola palabra para toda la cadena
`metric` (RAD + G + H + ET) ocuparía 30/31 bits: por eso las palabras son
por etapa y por capa.

`EF_WS_*` y `EF_ANCHOR_*` no tienen bits (ámbitos `record`/`object`).
Si se adopta el cálculo de ETr por píxel (opción C, FL-09),
`EF_WS_ETR_NEGATIVE` gana ámbito `cell` y una palabra `WS` propia para las
capas de ETr.

### 6.5 Combinación entre etapas

- **Sin OR entre etapas.** Las palabras de etapas distintas usan tablas de
  bits distintas y nunca se combinan bit a bit. Cada etapa escribe solo
  las condiciones que evalúa; las condiciones de aguas arriba permanecen en
  sus propias palabras, que el resultado conserva completas
  (`earthflux_result$flags`: `SpatRaster` multicapa, una capa por palabra,
  más la lista de registros de objeto y de registro).
- **Linaje.** El linaje de una capa `L` es el conjunto de palabras y
  objetos de los que depende según el diagrama de `ARCHITECTURE.md` §2
  (p. ej., `eta_24` ← ET ← H ← {G, RAD, anclas, `spatial`, `surface`}). Los
  flags heredados por las anclas (§3.4) y los flags de objeto de las
  etapas del linaje (p. ej., `EF_H_CALIBRATION_NOT_CONVERGED`) se aplican a
  todas las celdas de `L`.
- **Resumen derivado** (no almacenado obligatoriamente):
  `flag_severity_<L>` = máximo, sobre todas las palabras del linaje de `L`
  y todos los flags de objeto del linaje, de la severidad numérica de los
  bits activos (0 sin flags, 1 info, 2 warning, 3 critical; `NA` no
  evaluado). Se calcula con tres máscaras por tabla de bits (una por
  severidad) y `bitwAnd()`. Es la capa que `plot()`/`summary()` muestran
  primero.
- **`EF_INPUT_NA` aguas abajo.** Cada etapa marca en su bit 0 las celdas
  cuya salida es `NA` porque una entrada lo era; la causa original queda
  en la palabra de aguas arriba (p. ej., `EF_SURF_CLOUD` en `flags_lst`).

### 6.6 Enmascarar y excluir no es borrar

Cuando una política (`qa_policy = "mask"`, `qc_policy =
"exclude_critical"`) pone un valor en `NA` o excluye un registro:

1. el bit o el registro del flag que motivó la acción **se conserva**;
2. el valor original se conserva en la capa/tabla de entrada (o en `qa`);
3. la procedencia registra la política, los códigos afectados y los
   conteos por código (§6.7).

### 6.7 Registro de procedencia de flags

Cada resultado (`earthflux_result`, `earthflux_surface`,
`earthflux_anchors`, objetos de ajuste) incluye
`provenance$flags` con:

| Campo | Contenido |
|---|---|
| `package_version` | Versión de EarthFlux |
| `registry` | Filas de `ef_flag_registry()` de los códigos evaluados (`code`, `stage`, `severity`, `scope`, `bit`, `description`, `since`): el resultado sigue siendo decodificable aunque el registro cambie |
| `evaluated` | Códigos **evaluados** por etapa y capa. Distingue "evaluado y ausente" de "no evaluado" (p. ej., todos los de clase II mientras no estén registrados) |
| `bit_tables` | Para cada palabra `flags_<L>`: etapa y tabla (`bit`, `code`, `severity`) |
| `parameters` | Para flags con parámetro (`min_neighbours`, `kappa_max`, `d_max`, y los de clase II cuando se registren): valor, unidad, clave de `REFERENCES.md`, estado (`VERIFICADA`/`CANDIDATA`) y origen (defecto/usuario) |
| `policies` | `qa_policy`, `qc_policy`, códigos enmascarados/excluidos y conteos |
| `inherited` | Para anclas: tabla ancla × código heredado (§3.4) |
| `counts` | `n_flagged`/`n_total` por código y capa (igual a la suma de bits) |

---

## 7. Política de registro

1. **Ningún código entra a `ef_flag_registry()` por adelantado.** Un
   código se registra solo en el mismo cambio que agrega (a) la función que
   lo levanta, (b) sus tests positivos y negativos (casos numéricos de su
   especificación), (c) la fila del registro con todas sus columnas, y
   (d) la entrada en `NEWS.md` (Definition of Done, `DEVELOPMENT.md` §3).
   Lo mismo valía para la severidad `critical` y para las columnas nuevas
   del registro; *enmienda (2026-11-04):* ambas se introdujeron como
   infraestructura antes del primer código nuevo, para que las cinco
   etapas de M2 registren sus códigos de forma uniforme (`DECISIONS.md`
   §1.0). La regla sigue vigente para los **códigos**.
2. **Clase II**: además, el umbral debe estar documentado con referencia
   en `SCIENTIFIC_SPEC.md` (y `REFERENCES.md`) con estado `VERIFICADA`. El
   umbral se expone como parámetro registrado en la procedencia; sin
   referencia, el parámetro no tiene valor por defecto y el flag no se
   evalúa (`weather-forcing.md` §3.1, punto 3).
3. **Clase I-m**: se registra con el método, que a su vez exige `VERIFICADA`.
4. **Clase III**: se registra junto con la contraparte de error del núcleo
   y la política que excluye por defecto; los tests cubren ambos caminos.
5. **Nombres**: el código registrado es el de §4.2. Un nombre distinto
   exige actualizar este documento en el mismo cambio.
6. **Inmutabilidad**: un código registrado no cambia de significado. Un
   cambio de condición o de severidad es un código nuevo o una entrada
   explícita en `NEWS.md`; un código retirado conserva su bit como
   ocupado. La lista de retirados (código, etapa, bit, versión, sustituto)
   se crea con el primer retiro.
7. **Guardia**: los códigos de clase II se listan en un vector de guardia
   del test (§8, R10) que verifica su **ausencia** del registro; el cambio
   que registra uno lo quita de la guardia (`soil-heat-flux.md` §9.5 ya pide
   esta garantía para `EF_G_RATIO_IMPLAUSIBLE`).
8. **Estado de este documento**: la columna "Clase" de §4.2 se actualiza a
   "registrado" en el mismo cambio que registra el código.

Columnas del registro (implementadas el 2026-11-04):
`code`, `stage`, `severity`, `scope`, `bit` (`NA` si no hay ámbito
`cell`), `error_class` (`NA` salvo contraparte de error), `description`
(una oración en inglés), `spec` (documento y sección), `since` (versión).
`stage` es el prefijo sin `EF_` (p. ej., `"RAD"`); `scope` admite varios
ámbitos separados por comas sin espacios (`"cell,record"`); `bit` es
entero.

**Mecanismo (2026-11-04).** Cada etapa declara sus filas en su propio
archivo, en una función interna `ef_flags_<etapa>()` que devuelve
`ef_flag_rows(code, stage, severity, scope, bit, error_class, description,
spec, since)` (vectores de igual longitud, sin reciclaje; sin argumentos,
la tabla de cero filas), y `ef_flag_registry()` las une (ver §4.2). El
registro `earthflux_flag` incorpora `stage` y `scope` (§6.2);
`ef_flag(mask, code, scope = NULL)` exige `scope` explícito cuando el
código tiene más de un ámbito y una máscara de longitud 1 en el ámbito
`object` (R18). Los campos `target`, `time` y `parameters` de §6.2 entran
con la primera función espacial o con parámetro.

---

## 8. Tests del registro (`tests/testthat/test-diagnostics.R`)

| Id | Test | Comprobación |
|---|---|---|
| R1 | Unicidad | `anyDuplicated(reg$code) == 0` |
| R2 | Nombre | `grepl("^EF_(INPUT\|SURF\|WS\|GWR\|RAD\|G\|ANCHOR\|H\|ET)_[A-Z0-9]+(_[A-Z0-9]+)*$", code)` y `nchar(code) <= 40` |
| R3 | Prefijo ↔ etapa | El prefijo de `code` coincide con `stage` |
| R4 | Severidad | `severity %in% c("info", "warning", "critical")`; la función de niveles devuelve el orden `info` < `warning` < `critical` y los códigos 1, 2, 3 |
| R5 | Ámbito | Cada elemento de `scope` ∈ {`cell`, `record`, `object`} |
| R6 | Bits: rango y presencia | `bit` es `NA` si y solo si `"cell"` ∉ `scope`; `bit == 0` solo para `EF_INPUT_NA`; en los demás `1 <= bit <= 30` y entero |
| R7 | Bits: no solapamiento | Dentro de cada `stage`, los bits no `NA` son únicos; ningún código de otra etapa usa el bit 0 |
| R8 | Capacidad | Por etapa, número de códigos `cell` + 1 (bit 0) ≤ 31 |
| R9 | `critical` justificado | Toda fila `critical` tiene `error_class` no `NA` o ámbito `object` (fallo de procedimiento) |
| R10 | Guardia de clase II | Ningún código del vector de guardia (§7.7) está en el registro |
| R11 | Definition of Done | Cada código registrado aparece en al menos un archivo `test-*.R` distinto de `test-diagnostics.R` (lectura de los archivos de `test_path()`). La excepción temporal de `EF_INPUT_NA` y `EF_ET_NEGATIVE` (registrados en M0 antes de esta política) se retiró en la armonización M2: ambos los levantan funciones de M2 con tests en sus módulos |
| R12 | Ida y vuelta de bits | Para cada etapa, máscaras aleatorias con semilla fija → palabra → desempaquetado → máscaras idénticas; palabra ∈ [0, 2³¹ − 1]; la palabra con todos los bits de la etapa activos no es `NA` |
| R13 | Vista única | `ef_flag_bits(stage)` (nombre por decidir) es idéntica al subconjunto del registro; no existe otra tabla de bits mantenida a mano |
| R14 | Retirados | Ningún código o bit retirado reaparece en el registro (cuando exista la lista de retirados) |
| R15 | Espacio de nombres | Ningún código del registro coincide con el nombre de un objeto del paquete (`ls(asNamespace("EarthFlux"), all.names = TRUE)`) (C9) |
| R16 | Equivalencias de representación | Índices de `ef_flag()` ≡ bits desempaquetados de la palabra para la misma máscara (vector y `SpatRaster`, cuando `terra` esté en `Imports`); tabla `$qc` ≡ registros `record` |
| R17 | Descripción | No vacía, una oración que termina en punto |
| R18 | Flags de objeto | `n_total == 1` y `index ∈ {integer(0), 1L}` para ámbito `object` |
| R19 | Procedencia | Los flags de configuración (`EF_GWR_COARSE_MODE`, `EF_GWR_SINGLE_STATION`, `EF_ANCHOR_USER_SUPPLIED`, …) están presentes si y solo si el campo de procedencia correspondiente lo indica |

Notas:

- Implementados (2026-11-04) en `test-diagnostics.R`: R1–R11, R15, R17
  (con el vector de guardia de clase II, 35 códigos; la excepción
  temporal de R11 se retiró en la armonización M2), más tests de
  `ef_flag_rows()`, de `ef_flag()` y de los auxiliares de la convención de
  diagnósticos (`ef_flag_set()`, `ef_input_na_flags()`,
  `ef_flags_combine()`). R18 se garantiza en `ef_flag()`. R12–R14, R16 y R19 entran
  con la palabra de bits, la lista de retirados, `terra` y los flags de
  procedencia.
- La expresión regular `^EF_[A-Z0-9_]+$` se sustituyó por la de R2
  (cerrada), que excluye por construcción las constantes `EF_*` de C9
  (`R/constants.R`).

---

## 9. Decisiones abiertas

| Id | Decisión | Opciones | Recomendación |
|---|---|---|---|
| FL-01 | Prefijo del módulo `surface` | `EF_SURF_` / `EF_MODIS_` | `EF_SURF_` (principios 1–2; continuidad VIIRS) |
| FL-02 | Prefijo del módulo `spatial` | `EF_GWR_` / `EF_SPATIAL_` | `EF_GWR_` (menos renombres; nombre de los archivos) |
| FL-03 | ET-D4: LE < 0 | Código nuevo / reutilizar `EF_ET_NEGATIVE` | Reutilizar (equivalencia exacta, C1); la causa la dan `EF_G_AVAILABLE_NONPOSITIVE` y `EF_H_GT_AVAILABLE` |
| FL-04 | Herencia en anclas | Códigos `EF_ANCHOR_*` duplicados / herencia | Herencia (R-HER, §3.4) |
| FL-05 | Tercera severidad | Ninguna / `error` / `critical` | `critical` con el criterio cerrado de §5.3 → **DECIDIDA (provisional, 2026-11-04)** (`DECISIONS.md` §1.0) |
| FL-06 | Severidad de `EF_H_CALIBRATION_NOT_CONVERGED` y `EF_H_DT_SLOPE_NONPOSITIVE` | warning (`sensible-heat.md`) / critical | `critical` (§5.4) → **DECIDIDA (provisional, 2026-11-04)** (`DECISIONS.md` §1.0) |
| FL-07 | Representación ráster | Bits por capa / una capa lógica por flag / un código por píxel | Bits por capa de salida, 31 bits, `INT4S` (§6.3) |
| FL-08 | Constantes `EF_KELVIN_OFFSET`, `EF_WATER_DENSITY`, `EF_SECONDS_PER_HOUR`, `EF_MM_PER_M` | Mantener / renombrar a minúsculas internas | Decisión del autor; R2 y R15 evitan la colisión en cualquier caso |
| FL-09 | ETr por píxel (opción C de `weather-forcing.md` §6) | — | Si se adopta: `EF_WS_ETR_NEGATIVE` con ámbito `cell` y palabra `WS` para capas de ETr |
| FL-10 | Albedo > 1 (C12) | Error en la escena / `critical` + exclusión por defecto | `critical` + exclusión por defecto, coordinado con `soil-heat-flux.md` D6 |
| FL-11 | Severidades de `EF_SURF_*` | — | Las de §4.2 (regla de §5.3) |
| FL-12 | `EF_ETRF_NO_VALID_DATE` | Código propio / `EF_INPUT_NA` | `EF_INPUT_NA` (C8) |
| FL-13 | Ámbito `record` en estaciones | Tabla `$qc` / registros `earthflux_flag` | Ambos, con equivalencia verificada (R16); `$qc` como vista de auditoría |

---

## 10. Hallazgos que afectan a otros documentos (no editados aquí)

| Documento | Sección | Cambio propuesto |
|---|---|---|
| `R/diagnostics.R` | registro | Hecho (2026-11-04): columnas de §7, `critical`, regex cerrada y registro por etapa (`ef_flags_<etapa>()`, `ef_flag_rows()`) |
| `tests/testthat/test-diagnostics.R` | – | Hecho (2026-11-04) para R1–R11, R15, R17; R12–R14, R16, R19 pendientes (§8) |
| `weather-forcing.md` | §3.2, §3.1, §2.6, WF-07 | Severidad `error` → `critical`; `qc_policy = "exclude_error"` → `"exclude_critical"`; `EF_WS_IMPOSSIBLE` → `EF_WS_OUT_OF_DOMAIN`; `EF_STATION_CLOUDY` → `EF_WS_CLOUDY_OVERPASS`; QC-05b → `EF_WS_RS_GT_RA`; `EF_ETREF_NEGATIVE` → `EF_WS_ETR_NEGATIVE`; WF-07 resuelta por §3.1; §7.2 "SpatRaster de códigos" → palabra de bits (A1) |
| `gwr-forcing.md` | §2.3, §2.4, §5.3, §6.3, §9.2, §12 | `EF_GWR_PHYSICAL_RANGE` → `EF_GWR_OUT_OF_DOMAIN` (`critical`); `EF_FORCING_SINGLE_STATION` → `EF_GWR_SINGLE_STATION`; `gwr_flag_bits()` como vista del registro; definición de §6.3 para anclas pasa a regla de herencia |
| `anchor-pixels.md` | §6, §5.5 | Retirar `EF_ANCHOR_QA_DEGRADED`, `_HIGH_VIEW_ANGLE`, `_COMPOSITE_LAG`, `_FORCING_EXTRAPOLATED` (herencia; columna `inherited_flags` en `pixels`); `EF_ANCHOR_SMALL_CONTRAST` → `EF_ANCHOR_CONTRAST_LOW` |
| `sensible-heat.md` | §2.2, §5.6, §6.2, §6.4, §9.3–§9.4, §10.3, §11.6, §16 | Prefijo `EF_H_` y renombres de §4.2; `EF_DT_NEGATIVE` → `EF_H_NEGATIVE`; `EF_ANCHOR_DT_SMALL` → `EF_ANCHOR_CONTRAST_LOW`; severidades FL-06 |
| `evapotranspiration.md` | §7.2, §8, ET-D4 | `EF_LE_NEGATIVE` → `EF_ET_NEGATIVE`; `EF_LE_EXCEEDS_AVAILABLE` → `EF_H_NEGATIVE`; `EF_AVAILABLE_ENERGY_NONPOSITIVE` → `EF_G_AVAILABLE_NONPOSITIVE`; `EF_ETRF_NO_VALID_DATE` → `EF_INPUT_NA`; `EF_ETRF_*`/`EF_ETR24_FILLED` → `EF_ET_*` de §4.2 |
| `soil-heat-flux.md` | §6.3, §9.5, D6 | `EF_G_EXCEEDS_RN` → `EF_G_AVAILABLE_NONPOSITIVE` (condición Rn − G ≤ 0; el caso T7 sigue marcado); coordinar D6 con C12 |
| `radiation-components.md` | §4.8 | Prefijo `EF_RAD_`; `EF_LOW_SUN` → `EF_RAD_SUN_LOW`; `EF_LST_IMPLAUSIBLE` → `EF_SURF_LST_IMPLAUSIBLE`; `EF_STATION_CLOUDY` → `EF_WS_CLOUDY_OVERPASS`; división de `EF_RS_EXCEEDS_EXTRATERRESTRIAL` |
| `ef_net_radiation.md` | §9 | "Rn negativo" → `EF_RAD_RN_NEGATIVE` (info, sin `warning()`) |
| `modis-products.md` | §6.3, §9, §10.2–§10.3 | Prefijo `EF_SURF_`; severidades de §4.2; `EF_MODIS_OUT_OF_RANGE` → `EF_SURF_DN_OUT_OF_RANGE`; `EF_OVERPASS_*` → `EF_SURF_OVERPASS_*`; `EF_MODIS_ALBEDO_GT1` clase III |
| `SCIENTIFIC_SPEC.md` | §8 | Enlazar esta especificación como detalle de "Flags del resultado" |
| `evapotranspiration.md`, `soil-heat-flux.md` | constantes | FL-08 |
