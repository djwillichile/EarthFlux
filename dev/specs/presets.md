# EarthFlux — Especificación: `earthflux()`, presets y objeto de resultado

Estado: **implementada (M5, fase 2, 2026-11-06)** · Autor y mantenedor:
Guillermo Servando Fuentes-Jaque · Decisiones: `DECISIONS.md` §1.5, M5-04
y **M5-08 … M5-24** (presets versión 2 desde M5-23 y M5-24), **M2-11**
(versión 3: convergencia de H por fase) · Documento
dueño de la arquitectura:
`ARCHITECTURE.md` §6.7.

Este documento fija la cadena que orquesta `earthflux()`, el contenido de
los dos presets iniciales, los criterios de anclas que usan, el objeto
`earthflux_result` y los adaptadores escritos para unir los módulos. Parte
de la propuesta de presets de la fase 2 (2026-11-06), con los valores que el
autor decidió ese mismo día (M5-08 … M5-17). Código: `R/api-presets.R`
(presets), `R/api-prepare.R` (entradas), `R/api-run.R` (cadena METRIC),
`R/api-earthflux.R` (`earthflux()` y resultado), `R/print.R`, `R/plot.R`;
tests: `tests/testthat/test-earthflux.R`.

Abreviaturas de estado: **V** = `VERIFICADA` (FAO-56/ASCE o producto),
**V-I** = `VERIFICADA (SEBAL-Idaho 2002)`, **V-IAHS** = `VERIFICADA (IAHS
2012)`, **C** = `CANDIDATA`, **D(p)** = `DECIDIDA (provisional)`, **T** =
`TODO`. `V#n` = fila n de `VERIFICATION.md`.

## 1. API

| Función | Firma | Devuelve |
|---|---|---|
| `earthflux()` | `earthflux(aoi, date, weather, preset, cache_dir = tools::R_user_dir("EarthFlux", "cache"), apikey = NULL, surface = NULL, terrain = NULL)` | `earthflux_result` |
| `ef_presets()` | `ef_presets()` | `data.frame` `name`, `version`, `status`, `description` |
| `ef_preset()` | `ef_preset(name)` (sin defecto) | `earthflux_preset` (todas las opciones; `print()` legible) |

- `aoi`: `SpatVector` de polígonos en cualquier CRS; una sola tesela MODIS.
- `date`: `Date` (día UTC de la LST).
- `weather`: `"era5"` (Open-Meteo, M5-07) o una tabla de `ef_station_table()`
  **horaria**. Una estación → C1 (`ef_method_station(id)`, sin gradiente);
  varias estaciones o celdas ERA5 → C2 (`ef_method_idw(power = 2)`).
- `preset`: sin defecto (M5-04), comprobado con `check_method()` contra
  `"idaho2002_elev"` y `"idaho2002_flat"`.
- `apikey`: solo con `weather = "era5"` (API comercial); nunca se guarda
  (`apikey_used`).
- `surface`, `terrain` (**ruta experta**, implementada porque es barata): un
  `earthflux_surface_state` y un `earthflux_terrain` ya preparados; el
  estado de superficie debe haberse construido con las opciones MODIS del
  preset (se comparan producto LST, albedo, emisividad, NDVI y `qa_policy`).

Errores con clase: preset ausente (`earthflux_missing_input`) o desconocido
(`earthflux_unknown_method`), AOI de varias teselas
(`earthflux_method_not_implemented`, **antes de cualquier descarga**),
meteorología que no cubre la escena (`earthflux_weather_coverage_error`,
nueva, subclase de `earthflux_input_error`, campo `variables`), credenciales
(`earthflux_credentials_error`), descargas (`earthflux_download_error`),
anclas sin candidatos (`earthflux_anchor_no_candidates`) y los de cada
etapa. Aviso con clase **`earthflux_unverified_preset_warning`** (nuevo,
M5-08; campos `preset` y `unverified`), una vez por llamada, si el preset no
es `VERIFICADA`.

## 2. Cadena que orquesta `earthflux()`

Orden real: con RL↓ en la configuración (b) de RC-12 (Ts del píxel frío,
V#7; M5-11) las anclas se seleccionan **antes** de Rn (P0-3;
`anchor-pixels.md` §1.3). `ef_select_anchors()` solo usa `lst`, `ndvi`,
`albedo` y `lai`: no hay circularidad.

| # | Paso | Llamada | Notas de la implementación |
|---|---|---|---|
| 0 | Comprobaciones | `check_method(preset)`, `workflow_check_aoi()` (`modis_tiles_for_aoi()`) | Rechazo de varias teselas antes de descargar (hueco 8). Aviso de preset no verificado |
| 1 | MODIS | `modis_fetch(aoi, date, lst_product, cache_dir, collection)` | — |
| 2 | Superficie | `modis_surface_state(files, aoi, modis_surface_options(...))` | Grilla de trabajo = LST 1 km (MP-08) |
| 3 | Máscaras | `workflow_aoi_mask()` (`terra::rasterize(touches = TRUE)`), `surface_exclusion()` | Fuera del polígono → `NA` en todo (hueco 8); bits `critical` SURF → albedo `NA`, contados (P0-11) |
| 4 | MDE | `dem_fetch(aoi, grid, method = "flat", water = "mask", cache_dir)` | `valid_fraction < 1` → elevación `NA`, contada (M5-17); pendiente y orientación 0 (RC-09) |
| 5 | Meteorología | tabla del usuario o `openmeteo_fetch(aoi, date, elevation_adjust = FALSE, instant_values = "trapezoid", apikey, cache_dir)` | La tabla debe ser horaria (WF-09) |
| 6 | QC | `ef_station_qc(x, qc_policy = "exclude_critical")` | — |
| 7 | ETr de estaciones | `ef_station_ref_et(qc, "alfalfa", "hourly", "asce", humidity, "local_standard", "all_periods", "rn_positive", "low_sun", overpass = rango de horas de paso, inst_method = "O3", dates = día, utc_offset = λ_centroide/15)` | Humedad: primera columna disponible entre `vapour_pressure`, `dewpoint_temperature`, `relative_humidity`. Día = día solar medio que contiene la mediana de las horas de paso (M5-16) |
| 8 | Regionalización | `ef_regionalize()` de `etr_inst` (tasa horaria), `wind_speed_2m` y `etr_24`, sin covariables, `use_qc = c("ok", "warning")`, `exclude` = celdas ERA5 marinas | Ver §6 (huecos 1, 2, 11) |
| 9 | Hora de paso por celda | `workflow_interp_cells()` | Interpolación lineal por celda entre las capas de los puntos medios horarios que rodean su hora de paso (O3 por celda, M5-14, M5-18); bit 6 GWR → `NA`, contado |
| 10 | Geometría solar | `ef_solar_geometry(doy, utc_hour, lat, lon, slope = 0, aspect = 0)` | Grados → radianes |
| 11 | Presión | `ef_air_pressure(elevación)` | Por celda en ambos presets |
| 12 | Rugosidad, viento | `ef_zom(lai, method = "lai")`; z_om < 0,005 m → 0,005 m + `EF_H_ZOM_FLOOR_APPLIED` (`workflow_zom_floor()`); `ef_blending_wind(u2, height = 2, zom_station = 0.0144, d_station = 0)` | M5-24 (reemplaza M5-13), M5-14 |
| 13 | Anclas | `ef_select_anchors(..., qa = QA estricto, search_area, criteria, relax, aggregate = "mean", cell_size, origin, crs)` | §4 |
| 14 | Onda corta | `ef_tau_sw(elevation, method = "elevation")` → `ef_rs_in(..., tau_beam = τ_sw, tau_diffuse = 0, slope = 0, method = "modelled")` | Ec. 12 exacta en el plano (hueco 4, M5-19) |
| 15 | Onda larga | `ef_atm_emissivity(τ_sw)`, `ef_rl_in(T, ε_a)`, `ef_rl_out(lst, ε₀)` | T = T_cold (+ 0,0065·(z_frío − z) en `elev`, Ec. 12-8) |
| 16 | Rn, G | `ef_net_radiation()` (misma ε₀ que RL↑, RC-14), `ef_g(..., method = "bastiaanssen")` | — |
| 17 | λ | `ef_lambda(method = "constant")` | Misma λ en anclas y ET (P0-7) |
| 18 | Condiciones de borde | `ef_anchor_conditions(..., etrf_cold = 1.05, etrf_hot = 0, reference = "alfalfa", zom, u_blend, pressure)` | — |
| 19 | H | `ef_calibrate_h(anchors, preset$sensible_heat$control, lapse_rate, datum_elevation, pixels)` (control de la versión 3: §3.2) | Datum: elevación de la estación (C1) o del punto de calibración frío (C2) |
| 20 | LE → ETa | `ef_latent_heat()`, `ef_et_inst()`, `ef_etrf()`, `ef_et_daily(method = "etrf")` | `reference = "alfalfa"` en toda la cadena (ET-D9) |

## 3. Presets

Dos presets (M5-09), **`CANDIDATA`**, versión interna **`"3"`** (registrada
en la procedencia; un cambio de cualquier valor es una versión nueva).
Versiones (elemento `changes` del preset y `provenance$preset$changes`):

| Versión | Fecha | Cambios |
|---|---|---|
| `"1"` | 2026-11-06 | Primera versión (M5-08 … M5-22) |
| `"2"` | 2026-11-06 | Criterios de anclas recalibrados para MODIS a 1 km (M5-23, reemplaza M5-10; §4); mínimo de z_om de 0,005 m con `EF_H_ZOM_FLOOR_APPLIED` (M5-24, reemplaza M5-13); ninguna ancla en celdas con LAI asignado (`EF_SURF_LAI_ASSIGNED`) |
| `"3"` | 2026-11-10 | Convergencia de la calibración de H con una tolerancia por fase (M2-11): `tol` = 10⁻⁶ y `maxit` = 100 en las anclas, `pixel_tol` = 10⁻⁵ y `pixel_maxit` = 100 por píxel (antes 0,01 y 20 en ambas fases), escritos en el preset para que un cambio de los defectos de `ef_h_control()` no lo cambie en silencio. H cambia hasta ~1,3 W m⁻² (en Cauquenes, −0,43 W m⁻² de media) |
 El
estado va en la documentación y en la procedencia, **no en el nombre**
(M5-08, que reescribe D-AP-01). Ninguno usa la pendiente: se fuerza a 0
(proyección plana) hasta resolver RC-09; ambos usan la elevación del MDE.

### 3.1 Diferencias

| Opción | `idaho2002_elev` | `idaho2002_flat` | Fuente / estado |
|---|---|---|---|
| Γ de Ts_datum (`lapse_rate` de `ef_calibrate_h()`) | 0,0065 K m⁻¹ (Ec. 12-7) | 0 (Ts_datum = Ts, Ec. 32) | V-I (V#37); M5-12 |
| Temperatura de RL↓ | T_cold + 0,0065·(z_frío − z_píxel) (Ecs. 23, 12-8) | T_cold escalar (Ec. 23) | V-I (V#7); M5-11 |
| τ_sw (Ec. 11) | Por píxel, elevación del MDE (ap. 12) | Una para la escena: elevación de la estación (C1) o **mediana** de la elevación de las celdas del AOI (C2, ERA5) | V-I (V#2); M5-09, M5-20 |

### 3.2 Opciones comunes

| Bloque | Opción | Valor | Estado |
|---|---|---|---|
| MODIS | `lst_product` | `"MOD11A1"` (Terra), colección 061 | V producto; hora de paso C |
| | `albedo_method` / `diffuse_fraction` | `"white_sky"` / `NULL` | C (MP-03) |
| | `emissivity_method` | `"lai_empirical"` (E3) | V-I forma (V#11) |
| | `ndvi_source`; `composite_method` | `"MOD13A2"`; `c(albedo = "same_day", ndvi = "period_pixel_lag", lai = "period")` | V; D(p) |
| | `resampling_method`; `min_valid_fraction` | `"mean"`; `1` | D(p); umbral sin fuente |
| | `qa_policy`; `mask_codes` | `"flag"`; `NULL` (QA estricto en anclas, §4) | D(p) |
| | `lai_nonveg` | **`0`** (como la escena M4-27; `EF_SURF_LAI_ASSIGNED` deja la traza) | C (MP-06, M4-28); M5-17 |
| MDE | `method`; `water` | `"flat"`; `"mask"` | D(p) (M5-06) |
| | fracción válida mínima | `1` (la propuesta no la fijaba; coherente con MODIS) | D(p); M5-17 |
| AOI | máscara | celdas tocadas por el polígono | D(p); M5-21 |
| Estaciones | QC; `use_qc` | `"exclude_critical"`; `c("ok", "warning")` | diseño |
| ERA5 | `elevation_adjust`; `instant_values` | **`FALSE`** (elevación nativa de la celda; EarthFlux aplica su propio tratamiento de la elevación); `"trapezoid"` | API V; elección C; M5-15 |
| | celdas marinas | estaciones virtuales con elevación 0 m excluidas de la regionalización (`exclude`, motivo registrado) | C; M5-15 |
| ETr | `reference`, `timestep`, `standard` | `"alfalfa"`, `"hourly"`, `"asce"` | V |
| | `daytime_rule`; `night_cloudiness` | `"rn_positive"`; `"low_sun"` | V |
| | `day_definition`; `utc_offset`; `day_completeness` | `"local_standard"`; λ_centroide/15 h (día solar medio); `"all_periods"` | abierta (WF-11); M5-16 |
| | `inst_method` | `"O3"` (en la estación y por celda) | C (WF-09) |
| | suma diaria | D1: suma de las 24 ETr horarias del día | V-I (V#46, Ec. 44) |
| Regionalización | una estación | C1 `ef_method_station(id)` sin gradiente | definición |
| | varias / ERA5 | C2 `ef_method_idw(power = 2)`, sin covariables | C; M5-15 |
| | variables | `etr_inst` (tasa horaria en los puntos medios), `etr_24`, `wind_speed_2m` (opción C de SPEC-5.1); `surface_covariates = character(0)` | C; GW-07 (a) |
| Radiación | `ef_tau_sw`; `ef_rs_in` | `"elevation"`; `"modelled"`, `slope = 0`, `tau_beam = τ_sw`, `tau_diffuse = 0` | V-I en plano (V#5) |
| G | `method` | `"bastiaanssen"` | V-I (V#14) |
| z_om | `method`; mínimo (`zom_min`) | `"lai"`; **0,005 m** donde 0,018·LAI < 0,005 m (LAI < 0,28), con `EF_H_ZOM_FLOOR_APPLIED` | V-I agrícola (V#16); mínimo **C** (SH-02, V#20; el manual no da z_om de suelo desnudo, ap. 2, p. 44); M5-24 |
| Viento | `zom_station`; `d_station`; altura | 0,0144 m (0,12·0,12 m, Ec. 28 sobre césped de 0,12 m); 0; u₂ a 2 m → u₂₀₀ por celda | V-I forma (V#23); h C (SH-04); M5-14 |
| λ | `method` | `"constant"` | V (P0-7) |
| Anclas | criterios, relajación, QA | §4 | **C** (M5-10) |
| | `aggregate`; `search_area` | `"mean"`; una estación: lista (30 km alrededor de la estación, AOI), si no: AOI | D(p) |
| | `etrf_cold`; `etrf_hot` | 1,05; 0 (`EF_ANCHOR_HOT_LE_ASSUMED_ZERO`) | valores del manual (V-I, V#40–41) |
| H | `ef_h_control()` | 200, 0,1, 2, ψ_m estable a 2 m (defectos); `tol` 10⁻⁶, `maxit` 100, `pixel_tol` 10⁻⁵, `pixel_maxit` 100, ω 0 (escritos en el preset; versión 3, M2-11; antes tol 0,01 y maxit 20 en ambas fases) | V-I / D(p) |
| | `datum_elevation` | estación (C1) o punto de calibración frío (C2) | no afecta a H (`sensible-heat.md` §9.1); M5-20 |
| ET | `ef_et_daily` | `"etrf"`, `reference = "alfalfa"` | V-I (V#46) |

### 3.3 Elementos no verificados (`ef_preset(name)$unverified`)

Listados en el aviso de `earthflux()` y en `provenance$preset$unverified`:
`anchor_criteria` (V#42), `modis_albedo` (MP-03 y conversión de la hora de
paso), `modis_matching` (MP-07, MP-08, umbral de `min_valid_fraction`),
`lai_nonveg` (MP-06), `reference_et_time` (WF-09, WF-11), `regionalization`
(IDW C), `era5` (forzamiento grillado, `instant_values`, elevación nativa,
exclusión de celdas marinas), `station_roughness` (h = 0,12 m, SH-04),
`zom_floor` (mínimo de 0,005 m, SH-02, M5-24), `wind_time` (M5-14),
`flat_projection` (RC-09).

No bloquean (formas V-I/V): Rn, τ, ε_a, RL↓/RL↑, G, z_om por LAI, u*, rah,
ψ, L, dT, condiciones de borde, LE, ET_inst, ETrF, ETa₂₄, λ, Ecs. 12-7 y
12-8, ETr₂₄ como suma horaria (Ec. 44).

## 4. Criterios de anclas (ambos presets; `status = "CANDIDATA"`; M5-23)

Versión 2 (M5-23, reemplaza los criterios M5-10 de la versión 1).
Intención física del manual (Waters et al., 2002, pp. 23 y 30–31; ap. 7,
pp. 66–74; V#42): frío = vegetación agrícola de cobertura plena bien
regada, "very cold, but not extremely cold"; caliente = suelo agrícola
desnudo y seco, con albedo como el de otros campos secos, no desierto,
asfalto ni ladera de montaña. Los umbrales para píxeles de 1 km se fijaron
con la distribución de NDVI y albedo de las escenas de Cauquenes y del
Maule (2019-02-15; `verification/anchors-m5-23.md`), **sin fuente
primaria**.

| Elemento | Valor (v2) | v1 (M5-10) |
|---|---|---|
| Frío | `ndvi >= 0.90` (percentil), `albedo between c(0.14, 0.26)` (abs.) | `lai >= 3`, `albedo between c(0.18, 0.25)`, `ndvi >= 0.90` (percentil) |
| Caliente | `ndvi <= 0.10` (percentil), `ndvi > 0` (abs.), `albedo between c(0.18, 0.35)` (abs.) | `lai <= 0.4`, `ndvi > 0`, `albedo between c(0.10, 0.35)` |
| Homogeneidad | `ef_homogeneity("lst", window = 3, stat = "sd", max = 1.5, window_na = "exclude")` | igual |
| Selección | frío `ef_anchor_pick("lst", "lowest_fraction", 0.2)`; caliente `ef_anchor_pick("lst", "highest_fraction", 0.2)`; `aggregate = "mean"` | igual |
| Dominio / cuantil | `percentile_domain = "land"`, `quantile_type = 7` | igual |
| `relax` | **un** paso: frío `ndvi >= 0.80`, caliente `ndvi <= 0.20` (percentiles), el resto igual → `EF_ANCHOR_CRITERIA_RELAXED` | un paso: frío `lai >= 2` |
| QA de anclas (estricto, MP-09) | sin bits `warning`/`critical` en `flags_lst`, `flags_albedo`, `flags_ndvi`, `flags_lai`, `flags_emissivity` (bits leídos del registro por severidad) **ni `EF_SURF_LAI_ASSIGNED`** (LAI asignado por `lai_nonveg`, no recuperado: clases urbana, desnuda, agua, nieve; `anchors$qa_exclude_codes`); todas las `valid_fraction` = 1; sin bits 1, 3 o 6 GWR en las palabras del forzamiento a la hora de paso; y la cadena definida en la celda (elevación, z_om, forzamiento, hora de paso) — M5-22 | sin la exclusión de LAI asignado (lo hacía, de hecho, z_om `NA` en LAI = 0, M5-13) |

Motivos (evidencia en `verification/anchors-m5-23.md` §3):

- **Frío, albedo ≥ 0,14.** Las celdas de NDVI más alto de ambas escenas son
  bosques y plantaciones (albedo 0,10–0,13); las del valle, de cultivo,
  0,14–0,21. El manual pide cultivo agrícola (la rugosidad de los bosques,
  0,5 m en su ap. 2, tampoco es la de 0,018·LAI). El límite 0,26 ensancha
  la guía de 0,22–0,24 de la alfalfa.
- **Sin LAI absoluto.** El LAI MODIS de 1 km no discrimina el frío (3–6 en
  bosques y cultivos) y el LAI ≤ 0,4 del caliente lo alcanzan 1–3 % de las
  celdas utilizables, en el Maule casi solo laderas andinas.
- **Caliente, albedo ≥ 0,18.** Los campos secos de NDVI bajo del valle
  (< 300 m) tienen albedo mediano 0,19–0,20; las laderas andinas secas,
  percentil 95 de 0,165.

Resultado (coherencia, no validación): las anclas de v2 caen en el valle en
ambas escenas; en Cauquenes 20,6 % de las celdas sigue con ETrF > 1,05 (el
ancla fría cae en el borde de plantaciones costeras: la escena casi no
tiene cultivo regado de cobertura plena) y en el Maule las laderas sobre
1000 m quedan con ETrF < 0 (Ts_datum extrapolado sobre el ancla caliente;
31,9 % de la escena con `elev`, 14,0 % con `flat`). Ver §8.

## 5. Objeto `earthflux_result`

`new_ef_object(..., "earthflux_result")` (lista con clase, `flags` y
`provenance`; `ARCHITECTURE.md` §3.2):

| Elemento | Contenido |
|---|---|
| `layers` | `SpatRaster` en la grilla de trabajo, `NA` fuera del polígono del AOI: `eta_24` (principal), `etrf`, `et_inst`, `le`, `h`, `g`, `rn`, `rah`, `dt`, `rs_in`, `rl_in`, `rl_out`, `tau_sw`, `zom`, `u_blend`, `u_star`, `ts_datum`, `air_density`, `pressure`, `etr_inst`, `etr_24` |
| `units` | Unidades de `layers` |
| `surface`, `terrain` | `earthflux_surface_state` completo (incl. `qa$flag_word`) y `earthflux_terrain` |
| `weather` | `source`, `table` (tabla de estaciones), `qc`, `reference_et` (`earthflux_station_ref_et`) |
| `forcing` | `surfaces` (`earthflux_surface` de `etr_inst`, `wind_speed_2m`, `etr_24`), `method`, `representative_station`, `mid_points`, `daily_target_time` |
| `anchors`, `h_calibration` | `earthflux_anchors` (con `conditions`) y `earthflux_h_calibration` |
| `qa` | Palabras de flags por etapa, **sin combinar bit a bit**: `surface` (las del estado), `forcing` (GWR: una capa por variable a la hora de paso de cada celda, OR de los dos puntos medios), `metric` (`flags_rad`, `flags_g`, `flags_h`, `flags_et`) y `flag_bits` por etapa. `NA` = no evaluado (fuera del AOI) |
| `flags` | Registros de objeto/registro del forzamiento (`EF_WS_GRIDDED_FORCING` subido desde `provenance$forcing`, hueco 9; `EF_GWR_*` con `target` = tabla de estaciones de la superficie), de las anclas y de la calibración, y los registros de celda de la cadena METRIC sobre las celdas de `terra` (`target` = capa, índices dentro del AOI). Los flags de registro del QC y de la ETr de estaciones quedan en `weather` |
| `date`, `preset` | Fecha y el `earthflux_preset` usado |
| `provenance` | `preset` (nombre, versión, estado, fuente, decisiones, elementos no verificados); `options` (**cada opción** del preset); `scene` (AOI, teselas, grilla, rango y número de horas de paso, fuente meteorológica, humedad, `utc_offset`, día de ETr₂₄, puntos medios, método y estación representativa, estaciones usadas y excluidas, elevación de τ y del datum, T_cold y z_frío de RL↓, λ, área de búsqueda, entradas del usuario); `counts` (celdas de la grilla y del AOI; dentro del AOI: críticas SURF, MDE sin dato o bajo la fracción válida mínima, fuera de dominio GWR, z_om indefinida, ETa válidas); `sources` (MODIS: granulos, DOI, caché; MDE: teselas, DOI, licencia; meteorología: petición Open-Meteo **sin clave**, `apikey_used`, licencia y atribución, o la procedencia de la tabla de estaciones); `attribution`; `flags_evaluated` y `flags_evaluated_by_stage`; `versions`; `execution` (plan `future`, inicio, duración) |

Métodos: `print()` (preset, grilla, meteorología, anclas, a y b, rangos
de ETa₂₄ y ETrF, flags), `summary()` (tabla de capas con unidad, n
válidas y cuantiles; tabla de flags) y `plot()` (`terra::plot()` de una o
más capas con las anclas marcadas). Ningún secreto en la procedencia: el
token de Earthdata nunca llega a ella y la clave de Open-Meteo solo como
`apikey_used`.

## 6. Huecos de la propuesta y cómo se cubrieron

| # | Hueco | Implementación |
|---|---|---|
| 1 | Hora de paso por píxel vs forzamiento horario | La hora UTC de paso es continua por celda (la escena de Cauquenes tiene 3656 horas distintas): regionalizar cada hora es inviable. Se regionalizan los valores horarios en los **puntos medios** que rodean el rango de horas de paso (4 en Cauquenes) y cada celda se interpola linealmente a su hora (O3 por celda; con C1 coincide exactamente con O3 en la estación). Viento: igual (M5-14). `ef_station_ref_et()` recibe el rango de horas como `overpass` (auditoría y `EF_WS_OVERPASS_OUTSIDE_RECORDS`). M5-18 |
| 2 | Adaptador ETr → regionalización | `workflow_regionalization_input()`: tabla larga de `weather-forcing.md` §7.2 con `period_seconds` (3600 / 86400), `reference`, `qc_status = "ok"` (lo excluido por el QC ya es `NA` y `ef_regionalize()` excluye los `NA` con su motivo); cada estación recibe cada tiempo |
| 3 | Orden anclas → Rn; Ec. 12-8 | §2, pasos 13–15 |
| 4 | τ "elevation" → Rs↓ | `tau_beam = τ_sw`, `tau_diffuse = 0`, `slope = 0`; la `diffuse_fraction` resultante no se reutiliza. M5-19 |
| 5 | MDE → núcleo | Presión, `pressure` de anclas y píxeles, τ por píxel (`elev`), Ts_datum; `NA` del MDE contados; `aspect` 0 |
| 6 | Exclusiones antes del núcleo | Críticos SURF y bit 6 GWR → `NA` contados; z_om bajo el mínimo → 0,005 m con `EF_H_ZOM_FLOOR_APPLIED` (contado en `counts$zom_floor_applied`; M5-24, que reemplaza el `NA` + `EF_H_ZOM_UNDEFINED` de M5-13). `EF_ANCHOR_FORCING_EXTRAPOLATED` **no** se registra: el QA estricto excluye de las anclas las celdas con bits 1/3 (no puede darse) |
| 7 | Ráster ↔ núcleo | Vectores en orden de celdas de `terra`; matrices anchas para el núcleo (`workflow_matrix()`); índices de flags convertidos a celdas de `terra` |
| 8 | AOI y multitesela | Máscara del polígono; rechazo de varias teselas en `workflow_check_aoi()` antes de descargar |
| 9 | Flags y procedencia | §5; `reference` única en ETr, anclas, ETrF y ETa por construcción (todas leen `preset$et$reference`) |
| 10 | Fusión de ramas | `earthflux_credentials_error` y `earthflux_download_error` son una sola clase para MODIS y MDE; listadas en `R/utils.R` y `ARCHITECTURE.md` §3.3 |
| 11 | Validación de `weather` | Tabla horaria obligatoria; cobertura de cada tiempo objetivo (≥ 1 estación en C1, ≥ 2 en IDW) comprobada antes de regionalizar → `earthflux_weather_coverage_error` |
| 12 | Test de equivalencia | `test-earthflux.R`: la cadena escrita paso a paso, sin las auxiliares del flujo, da el mismo resultado (tolerancia 1e-8) con ambos presets y una estación |

**Pendiente (`TODO`):** mosaicos de varias teselas (M4-19); pendiente y
orientación en la radiación (RC-09) y ajustes de montaña de z_om y viento
(SH-03, SH-07); flags heredados en las anclas (`inherited_flags`); GWR (C3)
como opción de un preset avanzado; distancia geodésica del ancla a la
estación en `anchors$pixels` (hoy solo se usa para el área de búsqueda);
regla de G y z_om para agua y nieve (G-D4); tratamiento del relieve en la
calibración (laderas andinas con ETrF < 0 en el Maule, M5-23) y selección
sobre Ts o Ts_datum (D-AP-07).

## 7. Tests (`tests/testthat/test-earthflux.R`, sin red)

`modis_fetch()`, `modis_surface_state()`, `dem_fetch()` y
`openmeteo_fetch()` se reemplazan con `local_mocked_bindings()`: estado de
superficie = escena de ejemplo `cauquenes_modis` (MODIS real); MDE,
estaciones y respuesta de Open-Meteo **sintéticos**
(`helper-earthflux.R`). Se comprueba: preset obligatorio y desconocido
(sin descargas); rechazo multitesela antes de descargar; opciones pasadas a
cada descarga; equivalencia con la cadena paso a paso (`elev` y `flat`);
τ y RL↓ constantes en `flat` y variables en `elev`; capas, objetos, palabras
y métodos `print()`, `summary()`, `plot()`; máscara del AOI; mínimo de
z_om (caso positivo y negativo de `EF_H_ZOM_FLOOR_APPLIED`, bit 1; ninguna
ancla en celdas con LAI asignado; `workflow_zom_floor()`); procedencia con
cada opción y los cambios entre versiones; criterios de anclas de la
versión 2 (reglas, paso de relajación, anclas que cumplen las bandas de
albedo y los umbrales de NDVI calculados); ruta experta; C2 con varias
estaciones sobre el AOI completo (con los criterios v1 el frío quedaba
vacío y se usaba un AOI menor); ERA5 (opciones,
celdas marinas excluidas, `EF_WS_GRIDDED_FORCING`, ni la clave ni el token
en la procedencia ni en los flags); meteorología insuficiente.

## 8. Hallazgos

1. **Criterios de anclas en Cauquenes (MODIS real, 2019-02-15).** Solo 5
   celdas de la escena tienen LAI ≥ 3 y albedo de cielo blanco en
   [0,18; 0,25]: el albedo MODIS de la vegetación densa queda por debajo de
   0,18. Sobre el AOI completo (C2) el percentil 0,90 del NDVI deja el
   conjunto frío vacío también con la relajación (LAI ≥ 2); en un AOI menor
   o con la búsqueda de 30 km alrededor de una estación se encuentra un
   píxel frío de 302,7 K, mucho más cálido que el mínimo de la escena
   (≈ 290 K), y muchas celdas quedan más frías que el ancla
   (`EF_H_DT_EXTRAPOLATED_COLD`), con ETrF > 1,05. Evidencia para revisar
   M5-10 (en especial el límite inferior del albedo frío) con la escena del
   Maule. *Revisado por M5-23 (versión 2, §4; evaluación en
   `verification/anchors-m5-23.md`).*
2. **Corrida real** (2026-11-06; AOI −72,8…−71,9 / −36,3…−35,6, ERA5 vía
   Open-Meteo, `idaho2002_elev`): 7492 celdas en el AOI, 6583 con ETa₂₄;
   ETa₂₄ de −3,6 a 15,5 mm d⁻¹ (mediana 4,9); ETrF de −0,53 a 2,71
   (mediana 0,69); anclas fría 302,74 K (LAI 4,8, NDVI 0,79, albedo 0,199)
   y caliente 307,17 K (LAI 0,35); 25 estaciones virtuales usadas y 11
   celdas marinas excluidas; `utc_offset` −4,82 h. Valores no realistas en
   los extremos, coherentes con el hallazgo 1: no es una validación.
3. **z_om indefinida con `lai_nonveg = 0`.** En la corrida real, 805
   celdas del AOI tienen LAI = 0 (clases no vegetadas asignadas y LAI
   recuperado nulo): z_om `NA` (`EF_H_ZOM_UNDEFINED`) y ETa₂₄ `NA` en ellas
   (M5-13 con M5-17). Si se quiere ETa en suelo desnudo, urbano o agua hace
   falta una regla de z_om para LAI = 0 (SH-02) o un `lai_nonveg` distinto.
   *Precisión (2026-11-06):* 789 de esas 805 celdas no tienen LST (mar y
   agua); solo 16 tenían LST y quedaban sin ETa por la rugosidad. Resuelto
   por M5-24 (mínimo de 0,005 m con flag).
4. **Evaluación de M5-23 y M5-24** (2026-11-06; Cauquenes y Maule
   −72,8…−70,3 / −35,87…−34,7, `verification/anchors-m5-23.md`; coherencia,
   no validación). Cauquenes v1 → v2: ancla fría 302,74 → 299,43 K (rango
   en la escena 0,34 → 0,20), caliente 307,17 → 307,14 K; ETrF > 1,05
   30,9 → 20,6 %, mediana 0,69 → 0,45, p99 2,26 → 1,92. Maule v1 → v2:
   ancla caliente de laderas andinas (1931 m, 313,83 K) → campos del valle
   (mediana 143 m, 307,24 K); ETrF del valle (< 300 m) mediana 1,04 → 0,97,
   > 1,05 47 → 34 %; sobre 1000 m mediana 0,56 → −2,26 (84,7 % < 0): una
   sola recta dT(Ts_datum) calibrada en el valle no representa la
   cordillera. El mínimo de z_om agrega 15 celdas con ETa en Cauquenes y
   4259 en el Maule (roca andina, ETrF mediana −2,97, marcadas).
