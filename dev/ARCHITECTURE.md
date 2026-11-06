# EarthFlux — Arquitectura

Estado: **borrador M0**; §3–§4 actualizadas para M2, M3 y M4 (contrato de
superficie), §6.3 con el estado de M3 (2026-11-04) · Complementa `SCIENTIFIC_SPEC.md`.

## 1. Principios

1. **METRIC no depende directamente de MODIS.** Las funciones físicas reciben
   variables físicas (p. ej., `rs_in`, `albedo`, `lst`) y nunca objetos o
   convenciones propias de un sensor.
2. **MODIS entrega variables físicas estandarizadas.** El módulo de sensor
   aplica escalas, valores de relleno, QA y hora de paso, y devuelve
   variables con unidades documentadas.
3. **GWR es independiente de METRIC.** Produce superficies meteorológicas
   mediante un contrato documentado; no conoce el balance de energía.
4. **La API simple reutiliza el núcleo.** `earthflux()` solo orquesta las
   mismas funciones de bajo nivel disponibles para usuarios avanzados; no
   duplica ecuaciones.
5. **Los diagnósticos son parte del resultado.** Cada etapa devuelve valores
   y flags.
6. **No corregir silenciosamente resultados físicamente anómalos.** Un ETa
   negativo se conserva y se marca (`EF_ET_NEGATIVE`), no se trunca a 0.
7. **Las unidades se documentan explícitamente** en cada argumento y salida.
8. **Los errores físicos generan errors, warnings o flags apropiados**,
   siempre con clase de condición (`earthflux_error`, `earthflux_warning`,
   subclases específicas).
9. **Lo que pide la validación no lo pide el producto.** Los datos que
   necesita la validación científica (muchas estaciones, torres EC,
   cobertura de suelo local) nunca son requisitos de `earthflux()`; el
   usuario básico entrega solo área, fecha y forzamiento meteorológico
   (§6.7).

## 2. Módulos

```text
            ┌──────────┐        ┌──────────┐
            │ surface  │        │ forcing  │
            │ (MODIS…) │        │ (station)│
            └────┬─────┘        └────┬─────┘
                 │                   │
                 │              ┌────▼─────┐
                 │              │ spatial  │  GWR / alternativas
                 │              └────┬─────┘
                 │                   │
                 └───────┬───────────┘
                         ▼
                   ┌──────────┐
                   │  metric  │  Rn → G → anchors → rah/dT → H → LE → ET
                   └────┬─────┘
                        ▼
          ┌─────────────┴─────────────┐
          ▼                           ▼
   ┌─────────────┐             ┌────────────┐
   │ diagnostics │             │ validation │
   └─────────────┘             └────────────┘
                        ▲
                   ┌────┴─────┐
                   │   api    │  earthflux(), prepare, run, validate
                   └──────────┘
```

| Módulo | Responsabilidad | Archivos | No hace |
|---|---|---|---|
| `surface` | Leer productos satelitales y convertirlos en variables físicas estandarizadas (Ts, α, NDVI, LAI, ε₀) con QA y procedencia | `io-modis.R` (tabla de producto, lectores, escalado), `modis-qa.R` (QA → flags, política QA), `prep-modis.R` (hora de paso, banda ancha, desfase, agregación), `modis-surface.R` (ensamblaje del estado de superficie), `io-aoi.R` | Ecuaciones de balance de energía |
| `forcing` | Leer, estandarizar y controlar calidad de datos de estaciones; derivar variables (ea, u a altura de referencia, ETr) | `io-weather.R`, `prep-qc.R`, `forcing-derived.R`, `reference-et.R`, `prep-weather.R` | Interpolación espacial |
| `spatial` | Regionalizar variables meteorológicas (GWR; alternativas de referencia) y conservar parámetros, kernel, bandwidth, criterios, residuos, AICc, CV, diagnósticos y flags | `gwr-fit.R`, `gwr-bandwidth.R`, `gwr-predict.R`, `gwr-diagnostics.R` (núcleo); `regionalize.R`, `regionalize-methods.R`, `regionalize-baselines.R`, `regionalize-cv.R` (orquestación, C1/C2, CV) | Conocer METRIC |
| `metric` | Núcleo físico modular: Rn, G, anclas, rah, dT, H, LE, ET_inst, ETrF, ETa | `metric-*.R` | Leer archivos o conocer el sensor |
| `diagnostics` | Registro de flags y su construcción; resúmenes de calidad | `diagnostics.R` | Modificar valores |
| `validation` | Métricas de concordancia y comparación entre configuraciones | `validation.R`, `api-validate.R` | Ajustar el modelo a los datos de validación |
| `api` | Orquestación de alto nivel | `api-earthflux.R`, `api-prepare.R`, `api-run.R` | Implementar ecuaciones |

Soporte transversal: `classes.R`, `print.R`, `plot.R`, `utils.R`,
`constants.R` (constantes físicas, una por magnitud) y `shared-physics.R`
(magnitudes usadas por varios módulos: P(z), λ; RC-17 = WF-01).

## 3. Núcleo físico: funciones numéricas vectorizadas

Estado: **DECIDIDA (provisional, 2026-11-04)**, P0-12 (`DECISIONS.md`
§1.0); revisable por el autor antes de `0.1.0`.

- Las funciones `ef_*()` del núcleo operan sobre **vectores numéricos**
  (o arreglos) y son puramente aritméticas.
- Los envoltorios espaciales aplican esas mismas funciones sobre rásteres
  (p. ej., capas de `terra`) sin reimplementarlas.

Ventajas: tests unitarios triviales y rápidos sin dependencias espaciales;
independencia del backend ráster; verificación numérica directa contra casos
de la literatura; compatibilidad CRAN.

### 3.1 Contrato de entrada del núcleo `metric` (P0-4, P0-5, P0-11, P0-12)

Modelo de referencia: `ef_net_radiation()` (`specs/ef_net_radiation.md`
§3.1, §5, §6).

| Aspecto | Regla |
|---|---|
| Unidades | **K** para temperaturas y **radianes** para todos los ángulos, incluidas latitud y longitud (RC-01); SI para el resto (W m⁻², kPa para presiones, m, m s⁻¹, J kg⁻¹, kg m⁻³). °C solo en `forcing` y en las funciones de ET de referencia (FAO-56 formulada en °C), con conversión explícita a K en la frontera usando `EF_KELVIN_OFFSET` = 273.15 (WF-02, G-D9). Coordenadas en grados solo en contratos de entrada/salida (estaciones, *view time*), convertidas a radianes antes del núcleo |
| Tiempo | `doy` (día del año de la fecha **UTC**, 1–366) y `utc_hour` (h decimal, [0, 24)) **numéricos**; un envoltorio convierte desde `POSIXct` siempre con `tz = "UTC"` y rechaza fechas como texto (RC-03). MOD11A1: hora de paso = hora solar media (`specs/modis-products.md` §6.1–6.2); la ecuación del tiempo se aplica una sola vez, en `ef_solar_geometry()` |
| Tipo | `double` o `integer`; sin coerción silenciosa (`check_numeric()`) |
| Longitud | 1 o longitud común n (reciclaje de longitud 1); **longitud 0 rechazada** (`check_common_length()`, NR-D5) |
| `dim` | Los argumentos con `dim` no se reciclan y deben compartir `dim`; el resultado lo conserva (`check_same_dim()`, NR-D6; revisar con `SpatRaster`) |
| NA | `NA`/`NaN` se propagan sin error ni warning; la comprobación de dominio los ignora; `EF_INPUT_NA` lo construyen los despachadores y procedimientos (`ef_input_na_flags()`, `R/diagnostics.R`) y, más arriba, la orquestación |
| Dominio | Valor imposible o infinito → `earthflux_domain_error` (subclase de `earthflux_input_error`) con nombre del argumento y conteo (`check_in_range()`). Nunca se corrige, trunca ni recorta. Política única (P0-11, T-13): error por defecto en el núcleo; la orquestación convierte en `NA` + flag lo marcado aguas arriba (QA, QC, superficies GWR) **antes** de llamar al núcleo; no hay opción `on_invalid` |
| `method` | Sin valor por defecto y con coincidencia exacta (`check_method()`): faltante → `earthflux_missing_input`; desconocido → `earthflux_unknown_method` (ambas subclases de `earthflux_input_error`). `earthflux()` podrá fijar un defecto documentado solo para formulaciones `VERIFICADA` (T-15) |
| Formulaciones no verificadas | `CANDIDATA`, expuestas mediante argumentos explícitos **sin defecto** y rotuladas así en roxygen (p. ej., `ef_rl_in(temperature, …)` agnóstica, RC-12). Desde el 2026-11-05 (`DECISIONS.md` M2-08) las formas confirmadas en el manual SEBAL de Idaho (Waters et al., 2002) son `VERIFICADA (SEBAL-Idaho 2002)` y pueden tener defecto donde la falta de defecto se debía solo a la verificación: `stable_psi_m_height = 2` (SH-11 resuelta, M2-09), alturas z_b, z₁, z₂ y c_p. Registro: [`VERIFICATION.md`](VERIFICATION.md) |
| Constantes | Una por magnitud en `R/constants.R` (`EF_KELVIN_OFFSET`, `EF_STEFAN_BOLTZMANN`, `EF_SOLAR_CONSTANT`, `EF_VON_KARMAN`, `EF_GRAVITY`, `EF_SPECIFIC_HEAT_AIR`, `EF_WATER_DENSITY`, `EF_LATENT_HEAT_FAO56`), cada una con unidad, fuente y estado (P0-5). Los coeficientes normativos (FAO-56, ASCE-EWRI) quedan como literales solo dentro de la función que implementa esa ecuación (WF-14) |
| Magnitudes compartidas | `ef_air_pressure()` y `ef_lambda()` en `R/shared-physics.R`; ningún módulo las reimplementa. La misma λ (mismo `method`) se usa en el ancla fría y en LE → ET (P0-7) |

### 3.2 Objetos de retorno (convención M2; P0-12, T-17)

1. **Funciones numéricas** (una ecuación, p. ej., `ef_net_radiation()`,
   `ef_air_pressure()`): devuelven `numeric` simple, con la longitud común
   y el `dim` de las entradas; sin clase, sin atributos propios, sin flags
   ni procedencia. Si una función produce varias magnitudes inseparables
   (p. ej., geometría solar), devuelve una lista simple, sin clase, de
   arreglos numéricos de igual forma (RC-15, abierta).
2. **Diagnósticos por celda.** Los flags de ámbito `cell` de una etapa los
   construye una función interna `ef_diagnose_<etapa>()` (p. ej.,
   `ef_diagnose_soil_heat()`), que recibe las entradas y salidas numéricas y
   devuelve una lista (posiblemente vacía) de registros `earthflux_flag`
   creados con `ef_flag(mask, code, scope)` y máscaras
   `!is.na(x) & condición`. **La función numérica nunca construye flags.**
   Convención única (armonización M2, `DECISIONS.md` §1.2, M2-05): la
   lista contiene un registro **solo por código marcado en alguna posición**
   (`n_flagged > 0`); los códigos evaluados viajan en el atributo
   `evaluated` (`ef_flag_set()`), y el despachador o procedimiento que la
   llama los registra en `provenance$flags_evaluated` (`ef_flags_combine()`),
   de modo que "evaluado y ausente" se distingue de "no evaluado".
3. **Procedimientos de ámbito objeto** (selección de anclas, calibración de
   H) y **despachadores**: listas livianas con clase, creadas con
   `new_ef_object(x, class)` (`R/classes.R`): clase
   `c("earthflux_<tipo>", "list")` (`earthflux_anchors`,
   `earthflux_h_calibration`, …), elementos con nombre único y siempre un
   elemento `flags` (lista de `earthflux_flag`, posiblemente vacía); según
   el caso, además `method`, `provenance` y los valores numéricos. Cada tipo
   añade su validador junto a su constructor. Los flags de objeto usan una
   máscara de longitud 1 (`ef_flag(TRUE, code)`) y siguen la convención del
   punto 2 (solo los que se cumplen). `provenance` incluye siempre
   `flags_evaluated` (en `earthflux_anchors`, además, la procedencia
   completa de `specs/flags.md` §6.7 en `provenance$flags`). Las clases
   creadas se listan en la cabecera de `R/classes.R`.
4. **Una función exportada por método** (aritmética pura, p. ej.,
   `ef_g_tasumi()`; devuelve `numeric` o, si produce varias magnitudes, una
   lista simple) más un **despachador delgado** (`ef_g(…, method)`) con
   `method` sin defecto y como **último argumento**, que valida `method`
   (`check_method()`), llama a la función del método, construye los flags
   de su etapa con `ef_diagnose_<etapa>()` más `EF_INPUT_NA`
   (`ef_input_na_flags()`) y devuelve
   `new_ef_object(list(<valores>, method = , flags = , provenance = ),
   "earthflux_<magnitud>")` (`specs/soil-heat-flux.md` §5.2, opción C;
   G-5.2, G-D3). Despachadores de M2 (armonización, `DECISIONS.md` §1.2,
   M2-04):

   | Despachador | Clase | Elementos de valor |
   |---|---|---|
   | `ef_tau_sw(..., method)` | `earthflux_sw_transmissivity` | `total`; `beam`, `diffuse` (con nombre siempre; `NULL` si el método no particiona) |
   | `ef_rs_in(..., method)` | `earthflux_incoming_shortwave` | `total`, `beam`, `diffuse`, `reflected`, `diffuse_fraction` (`NULL` en `"measured"`) |
   | `ef_g(rn, lst, albedo, ndvi, lai, method)` | `earthflux_soil_heat_flux` | `g`, `g_rn_ratio`, `branch` |
   | `ef_zom(lai, ndvi, albedo, coef_1, coef_2, f_lai, height, method)` | `earthflux_roughness_length` | `zom` |
   | `ef_et_daily(etrf, etr_24, reference, method)` | `earthflux_daily_et` | `eta_24` (y `reference`) |

   Los despachadores con `...` comparan los argumentos con los formales del
   método (`ef_dispatch_args()`): uno requerido ausente da
   `earthflux_missing_input`; uno desconocido, `earthflux_input_error`.
   Test obligatorio: despachador ≡ llamada directa, comparando el elemento
   de valor. `ef_lambda(temperature, method)` es una función única con
   `method` (regla N6b de `NAMING.md`), no un despachador, y devuelve
   `numeric`. Las auxiliares quedan internas; el tamaño de la API se revisa
   en conjunto antes de `0.1.0` (T-16).
5. **No convergencia**: el procedimiento devuelve el último iterado, emite
   `earthflux_convergence_warning` y agrega el flag de objeto
   correspondiente; nunca en silencio (`specs/sensible-heat.md` §11.6).

### 3.3 Condiciones con clase

`ef_abort(message, class = NULL, ..., call = sys.call(-1))` y
`ef_warn(message, class = NULL, ..., call = sys.call(-1))` (`R/utils.R`)
aceptan campos de datos opcionales con nombre en `...` (D-AP-10), que el
manejador lee como `cnd$campo` (p. ej., embudo y umbrales de una selección
de anclas fallida, último iterado de una calibración). Nombres únicos,
distintos de `message` y `call`.

| Clase | Hereda de | Uso |
|---|---|---|
| `earthflux_input_error` | `earthflux_error` | Tipo, longitud, `dim` o argumento inválido |
| `earthflux_domain_error` | `earthflux_input_error` | Valor fuera del dominio físico o infinito |
| `earthflux_missing_input` | `earthflux_input_error` | Argumento requerido no entregado (incl. `method`) |
| `earthflux_unknown_method` | `earthflux_input_error` | `method` fuera de los valores aceptados |
| `earthflux_unknown_flag` | `earthflux_error` | Código de flag no registrado |
| `earthflux_registry_error` | `earthflux_error` | Fila mal formada del registro de flags (error de desarrollo) |
| `earthflux_calibration_error` | `earthflux_error` | La calibración interna no puede continuar (p. ej., `NA` o valores no finitos en un ancla; SH-18) |
| `earthflux_convergence_warning` | `earthflux_warning` | Iteración detenida sin cumplir su criterio (SH-18) |

Las subclases específicas de un módulo se crean con la función que las
levanta y heredan de una de las clases anteriores (lista completa en la
cabecera de `R/utils.R`):

| Clase | Hereda de | Módulo | Uso |
|---|---|---|---|
| `earthflux_anchor_error` | `earthflux_error` | anclas | Padre de `earthflux_anchor_no_candidates` (campos `type`, `funnel`, `thresholds`), `earthflux_anchor_insufficient_domain`, `earthflux_anchor_inverted` y, con `earthflux_input_error`, `earthflux_anchor_na_input` y `earthflux_anchor_outside_grid` |
| `earthflux_station_field_error` | `earthflux_input_error` | estaciones | Campo faltante, desconocido o de tipo erróneo; tabla vacía; `NA` en un campo obligatorio |
| `earthflux_station_time_error` | `earthflux_input_error` | estaciones | `timestamp` sin zona horaria explícita, no interpretable o semántica de período inválida |
| `earthflux_station_unknown_id` | `earthflux_input_error` | estaciones | Observación de una estación ausente de `stations` |
| `earthflux_station_duplicate` | `earthflux_input_error` | estaciones | `station_id` duplicado o registros duplicados en conflicto |
| `earthflux_station_provenance_error` | `earthflux_input_error` | estaciones | Procedencia mal formada (CRS, campos reservados) |
| `earthflux_undefined_reference` | `earthflux_input_error` | ET de referencia | Referencia no definida por la norma (FAO-56 con `reference = "alfalfa"`); campos `reference`, `standard` |
| `earthflux_gwr_error` | `earthflux_error` | GWR | Padre de los errores del núcleo GWR (`gwr_abort()`) |
| `earthflux_gwr_insufficient_stations` | `earthflux_gwr_error` | GWR, C2 | Menos estaciones válidas que las necesarias (campos `n`, `p`); lo reutilizan OLS e IDW |
| `earthflux_gwr_no_feasible_bandwidth` | `earthflux_gwr_error` | GWR | Ningún bandwidth del perfil es factible (campo `profile`) |
| `earthflux_gwr_singular_error` | `earthflux_gwr_error` | GWR | Diseño local de rango deficiente en una estación con bandwidth del usuario (campo `stations`) |
| `earthflux_method_not_implemented` | `earthflux_unknown_method` (y `earthflux_input_error`) | MODIS (M4) | Opción listada en la especificación pero no implementable aún (hechos o coeficientes `TODO`): albedo A4–A6, emisividad E1/E2/E4, T3, `"bilinear"`, LST de MOD21A1D, NDVI de MOD13Q1/MOD09; campos `method` y `choices` (opciones disponibles) |
| `earthflux_modis_unsupported` | `earthflux_input_error` | MODIS (M4) | Producto, colección o capa sin ficha `VERIFICADA` (campos `product`, `collection`/`layer`) |
| `earthflux_modis_filename_error` | `earthflux_input_error` | MODIS (M4) | Nombre de archivo fuera de la convención MODIS (campo `file`) |
| `earthflux_modis_layer_error` | `earthflux_input_error` | MODIS (M4) | Capa ausente o ambigua en un archivo HDF4 (campo `layer`) |
| `earthflux_modis_dn_error` | `earthflux_input_error` | MODIS (M4) | Valores que no son DN crudos del tipo declarado (p. ej., ya escalados; MP-11) |
| `earthflux_modis_metadata_error` | `earthflux_input_error` | MODIS (M4) | Escala, offset o NoData del archivo en contradicción con la tabla de producto |
| `earthflux_modis_grid_error` | `earthflux_input_error` | MODIS (M4) | CRS, celda, extensión de tesela, solape con el AOI, mosaico o anidamiento de grillas inconsistente |
| `earthflux_modis_driver_error` | `earthflux_error` | MODIS (M4) | Driver GDAL HDF4 no disponible (usar archivos convertidos, MP-10) |
| `earthflux_credentials_error` | `earthflux_error` | descargas (M5) | Token de NASA Earthdata ausente de `EARTHDATA_TOKEN` (una sola clase para MODIS y MDE) |
| `earthflux_download_error` | `earthflux_error` | descargas (M5) | Fallo HTTP o de transferencia (campos `status` y `url` sin secretos; MODIS, MDE, Open-Meteo) |
| `earthflux_weather_coverage_error` | `earthflux_input_error` | `earthflux()` (M5) | La meteorología no cubre la hora de paso, el día de ETr₂₄ o las 24 h previas (campo `variables`; M5-22) |
| `earthflux_unverified_preset_warning` | `earthflux_warning` | `earthflux()` (M5) | Preset no `VERIFICADA`; campos `preset` y `unverified` (M5-08) |

Los errores de dimensión son `earthflux_input_error` en todo el paquete
(como `check_same_dim()`); **no** se creó `earthflux_dimension_error`, que
proponía `specs/gwr-forcing.md` §9.3 (`DECISIONS.md` §1.3, M3-22).

### 3.4 Registro de flags por etapa

Cada etapa es dueña de sus filas del registro, en su propio archivo, para
evitar conflictos al desarrollar los módulos en paralelo
(`specs/flags.md` §7). `ef_flag_registry()` (`R/diagnostics.R`) une:

| Función | Archivo | Prefijo |
|---|---|---|
| `ef_flags_core()` | `diagnostics.R` | `EF_INPUT_` |
| `ef_flags_radiation()` | `metric-radiation.R` | `EF_RAD_` |
| `ef_flags_soil_heat()` | `metric-soil-heat.R` | `EF_G_` |
| `ef_flags_anchors()` | `metric-anchors.R` | `EF_ANCHOR_` |
| `ef_flags_sensible_heat()` | `metric-sensible-heat.R` | `EF_H_` |
| `ef_flags_et()` | `metric-et.R` | `EF_ET_` |
| `ef_flags_reference_et()` | `reference-et.R` | `EF_WS_` (ET de referencia y serie por estación) |
| `ef_flags_stations()` | `prep-qc.R` | `EF_WS_` (QC de estaciones) |
| `ef_flags_gwr()` | `gwr-diagnostics.R` | `EF_GWR_` (núcleo GWR y orquestación) |
| `ef_flags_surface()` | `modis-qa.R` | `EF_SURF_` (QA de productos MODIS y estado de superficie, M4) |
| `ef_flags_gridded_forcing()` | `forcing-openmeteo.R` | `EF_WS_` (forzamiento grillado, M5-07) |
| `ef_flags_workflow()` | `api-run.R` | `EF_H_ZOM_FLOOR_APPLIED` (mínimo de z_om de los presets de `earthflux()`, M5-24; reemplaza `EF_H_ZOM_UNDEFINED`, M5-13, retirado) |

Cada función devuelve `ef_flag_rows(code, stage, severity, scope, bit,
error_class, description, spec, since)` (sin argumentos: tabla de cero
filas). Las nueve etapas de la lista cerrada de `specs/flags.md` §3.1
tienen ya su función. Las columnas, la severidad `critical` y las reglas
de validación están en `specs/flags.md` §4.2, §5 y §8. Recuento al
2026-11-04 (M4, tras la opción `lai_nonveg`): 69 códigos (`INPUT` 1,
`RAD` 4, `G` 4, `ANCHOR` 10, `H` 8, `ET` 1, `WS` 13, `GWR` 13, `SURF` 15;
`specs/flags.md` §4.4). En M5: `EF_WS_GRIDDED_FORCING` (M5-07) y
`EF_H_ZOM_UNDEFINED` (M5-13): 71 códigos (`WS` 14, `H` 9). M5-24 cambia
`EF_H_ZOM_UNDEFINED` por `EF_H_ZOM_FLOOR_APPLIED` (siguen 71); los códigos
retirados, con su bit ocupado, están en `ef_flag_retired()`
(`diagnostics.R`; `specs/flags.md` §7, punto 6).

El registro es estático: `ef_flag_registry_build()` une y valida las filas
y `ef_flag_registry()` lo guarda en un entorno del paquete la primera vez
que se usa (armonización M3, `DECISIONS.md` §1.3, M3-37). Antes se
reconstruía en cada `ef_flag()` (≈ 9 ms por registro de flag), lo que
dominaba el tiempo de `ef_regionalize()` con bloques pequeños. Los tests
del registro usan la versión sin caché.

### 3.5 Registro `earthflux_flag` y campo `target`

Campos de todo registro: `code`, `stage`, `severity`, `scope`,
`description`, `index` (entero 1-based), `n_flagged` y `n_total`
(`ef_flag()`). Un objeto con **varias tablas o capas** a las que puede
referirse `index` agrega el campo `target` con el nombre de esa tabla o
capa (`specs/flags.md` §6.2). Primer uso, `ef_station_ref_et()`:
`target` ∈ {`"series"`, `"etr_inst"`, `"etr_24"`}, y la procedencia
registra `flags_evaluated` y `flags_evaluated_by_target` (`DECISIONS.md`
§1.3, M3-18). Desde M4, los registros de `earthflux_surface_state` llevan
`target` = capa (`"lst"`, `"overpass_time"`, `"albedo"`, `"ndvi"`,
`"lai"`, `"emissivity"` y, con las emisividades de banda, `"emis_31"`,
`"emis_32"`), con `index` = celda de la grilla de trabajo, y
la procedencia registra `flags_evaluated_by_target`; el mismo contenido
está en la palabra de flags de cada capa (`qa$flag_word`, §4). Los
objetos con una sola tabla o vector no lo llevan. Los flags de celda de
las superficies regionalizadas no son registros con índice: viven en la
palabra de flags (`flag_word`, §4).

## 4. Contratos de datos (borrador)

`TODO`: completar con nombres definitivos y validadores. Unidades y
tiempo: **DECIDIDA (provisional, 2026-11-04)**, P0-4 (§3.1).

**Estado de superficie** (salida de `surface`):

| Nombre | Unidad | Obligatorio |
|---|---|---|
| `lst` | K | Sí |
| `albedo` | – | Sí |
| `ndvi` | – | Sí |
| `lai` | m² m⁻² | Según método de G/rugosidad |
| `emissivity` | – | Sí |
| `elevation`, `slope`, `aspect` | m, rad, rad | Para corrección por terreno |
| `overpass_time` | POSIXct (UTC); el núcleo recibe `doy` + `utc_hour` numéricos (§3.1) | Sí |
| `qa` | flags | Sí |

**Implementación MODIS (M4): `earthflux_surface_state`**, salida de
`modis_surface_state(files, aoi, options)` (interna, `R/modis-surface.R`;
`specs/modis-products.md` §13.2; `DECISIONS.md` §1.4, M4-19 …). Lista
creada con `new_ef_object()`; todas las capas en la **grilla de trabajo**
(grilla sinusoidal nativa de 1 km del archivo de LST recortada al AOI,
MP-08), orden de celdas de `terra`:

| Elemento | Contenido | Unidad |
|---|---|---|
| `lst` | `SpatRaster` (1 capa) | K |
| `albedo` | `SpatRaster`; albedo de banda ancha (`modis_albedo()`, método explícito), **valores > 1 conservados** | – |
| `ndvi` | `SpatRaster` (MOD13A2) | – |
| `lai` | `SpatRaster` (MCD15A2H agregado; clases no vegetadas `NA`, o el LAI asignado con la opción explícita `lai_nonveg` y `EF_SURF_LAI_ASSIGNED`, MP-06, `DECISIONS.md` M4-28) | m² m⁻² |
| `emissivity` | `SpatRaster`; ε₀ de banda ancha (E3, `VERIFICADA (SEBAL-Idaho 2002)` como forma; coherencia con la LST abierta, RC-14; `NA` donde LAI es `NA`) | – |
| `band_emissivity` | `SpatRaster` de dos capas `emis_31`, `emis_32` (MOD11A1/MYD11A1), o `NULL` si una fuente convertida no las declara; **no** es insumo del núcleo: reservado para la ε₀ split-window (E1, no implementada; M4-30) | – |
| `overpass_time` | Lista: `doy` y `utc_hour` (`SpatRaster`; día del año de la fecha UTC y hora UTC), `time` (`POSIXct` UTC, orden de celdas) | –, h |
| `lonlat` | `SpatRaster` `lon`, `lat` de los centros de celda (WGS84) | grados |
| `qa` | `flag_word` (`SpatRaster` entero, una capa por salida: `flags_lst`, `flags_overpass_time`, `flags_albedo`, `flags_ndvi`, `flags_lai`, `flags_emissivity` y, con `band_emissivity`, `flags_emis_31`, `flags_emis_32`; bits de la etapa `SURF`), `flag_bits` (vista del registro), `valid_fraction` (fracción de subceldas válidas de cada insumo agregado), `composite` (período, `lag_bound_days` y `lag_days` por píxel de NDVI con T2), `policy` (`qa_policy`, `mask_codes`, `n_masked`) | – |
| `units`, `flags`, `provenance` | Unidades; registros `earthflux_flag` con `target` = capa (§3.5); granulos, productos, colección, DOI, métodos, filas de la tabla de producto, versiones, `flags_evaluated(_by_target)` y `flags` (`specs/flags.md` §6.7) | – |

**Traspaso al núcleo `metric` (obligación de M5).** La orquestación:

1. Extrae vectores numéricos en orden de celdas (`terra::values(x, mat =
   FALSE)`) o aplica el núcleo por bloques; unidades del contrato: `lst`
   en K (sin conversión), `albedo`, `ndvi`, `emissivity` adimensionales,
   `lai` en m² m⁻²; `lon`/`lat` en grados → **radianes** (× π/180) antes de
   `ef_solar_geometry()` (RC-01).
2. Pasa `doy` y `utc_hour` de `overpass_time` tal cual a
   `ef_solar_geometry()`: son hora **UTC** derivada de la hora solar
   **media** (sin ecuación del tiempo); la ecuación del tiempo se aplica una
   sola vez, dentro de `ef_hour_angle()`. Donde falta la hora de paso
   (`EF_SURF_OVERPASS_MISSING`, bit 13 de `flags_overpass_time`, o `NA` en
   `doy`/`utc_hour`), la geometría solar es `NA` y con ella Rs↓, Rn, G y lo
   que sigue en esa celda; la LST se conserva.
3. **Excluye antes de `ef_net_radiation()` y `ef_g()`** las celdas con un
   bit `critical` de la etapa `SURF` activo en cualquier palabra
   (`surface_exclusion()`; hoy `EF_SURF_ALBEDO_GT1`, bit 14 de
   `flags_albedo`): pone su albedo (y lo que dependa de él) en `NA` y
   **cuenta** la exclusión (`counts`) en la procedencia del resultado; sin
   esa exclusión el núcleo da `earthflux_domain_error` (clase III, P0-11,
   `specs/flags.md` §6.6). Los bits se leen del registro, nunca por número.
4. Excluye también las celdas `NA` de cada capa (relleno, nubes, no
   producido, fuera de rango, clases no vegetadas, enmascaradas por
   `qa_policy = "mask"`): el núcleo las propaga como `NA` y sus
   despachadores marcan `EF_INPUT_NA`; la causa original queda en la palabra
   de la capa de superficie (`specs/flags.md` §6.5).
5. Usa la **misma** `emissivity` en `ef_rl_out()` y en `ef_net_radiation()`
   (RC-14, requisito C2), y conserva `qa$flag_word` completo en el
   resultado (las palabras de etapas distintas no se combinan bit a bit).

El test `tests/testthat/test-surface-chain.R` recorre exactamente estos
pasos con un granulo sintético.

**Forzamiento meteorológico** (salida de `forcing`/`spatial`):

| Nombre | Unidad | Obligatorio |
|---|---|---|
| `air_temperature` | °C en `forcing`/`spatial`; convertida explícitamente a K (`EF_KELVIN_OFFSET`) al entrar al núcleo `metric` (WF-02, §3.1) | Sí |
| `vapour_pressure` | kPa | Sí |
| `wind_speed` + altura de medición | m s⁻¹, m | Sí |
| `solar_radiation` | W m⁻² | Sí |
| `etr_inst`, `etr_24` | mm h⁻¹, mm d⁻¹ | Sí |
| `method` | texto (estación única / GWR / alternativa) | Sí |

**Superficie regionalizada** (`earthflux_surface`, salida de
`ef_regionalize()`; contrato para la orquestación de M5):

| Elemento | Contenido | Obligación del consumidor |
|---|---|---|
| `surface` | `SpatRaster`, una capa por `target_time`, en la unidad del contrato de la variable (°C para `air_temperature`, kPa para `vapour_pressure`, W m⁻² para `solar_radiation`, mm h⁻¹ / mm d⁻¹ para `etr_inst`/`etr_24`) | Convertir explícitamente a K (`+ EF_KELVIN_OFFSET`) la temperatura del aire **al entrar al núcleo `metric`** (P0-4, WF-02); el núcleo no acepta °C |
| `flag_word` | `SpatRaster` entero (`INT4S`), una capa por `target_time`, con los bits de `flag_bits` (etapa `GWR`): 0 `EF_INPUT_NA`, 1 `EF_GWR_EXTRAPOLATION_COVARIATE`, 2 `EF_GWR_EXTRAPOLATION_LOCAL`, 3 `EF_GWR_OUTSIDE_HULL`, 4 `EF_GWR_FEW_NEIGHBOURS`, 5 `EF_GWR_LOCAL_SINGULAR`, 6 `EF_GWR_OUT_OF_DOMAIN` | **Enmascarar** las celdas con el bit 6 (`EF_GWR_OUT_OF_DOMAIN`, `critical`: valor conservado fuera del dominio físico) **antes** de llamar al núcleo, que daría `earthflux_domain_error` (P0-11, T-13; `specs/flags.md` §6.6); contar la exclusión |
| `flag_bits` | Tabla `bit`, `code`, `severity`, `description` (vista del registro) | Leer los bits por código, nunca por número fijo |
| `diagnostics`, `station_table`, `provenance`, `flags` | Ajuste por `target_time`, tabla de estaciones (residuos, LOO, exclusiones), procedencia y flags de objeto/registro | Propagar a `earthflux_result` |

En las anclas (`anchor-pixels.md` §2.4, §6), la extrapolación del
forzamiento en la celda del ancla se lee en la palabra de flags: la
definición propuesta por `gwr-forcing.md` §6.3 es "bit 1
(`EF_GWR_EXTRAPOLATION_COVARIATE`) o bit 3 (`EF_GWR_OUTSIDE_HULL`)
activo", insumo de `EF_ANCHOR_FORCING_EXTRAPOLATED` (sin registrar; la
decisión es de `anchor-pixels.md`). Una llamada a `ef_regionalize()`
regionaliza **una** variable (decisión 5.1 abierta: la orquestación decide
si regionaliza ETr o sus insumos).

**Resultado** (`earthflux_result`, M5; `specs/presets.md` §5): `layers`
(`SpatRaster` en la grilla de trabajo, `NA` fuera del polígono del AOI:
`eta_24`, `etrf`, `et_inst`, `le`, `h`, `g`, `rn`, `rah`, `dt` e
intermedios), `units`, los objetos de cada etapa (`surface`, `terrain`,
`weather`, `forcing`, `anchors`, `h_calibration`), `qa` (palabras de flags
por etapa, sin combinar bit a bit, y sus `flag_bits`), `flags` (objeto,
registro y celda, con `target`), `preset` y `provenance` (preset, cada
opción efectiva, valores derivados de la escena, conteos de exclusiones,
fuentes sin secretos, atribuciones, códigos evaluados, versiones, plan
`future`).

## 5. Unidades

- Se documentan en roxygen (`@param`, `@return`) y en la tabla de
  `SCIENTIFIC_SPEC.md`.
- Opción evaluada y **no adoptada por ahora**: paquete `units` (añade
  dependencia y fricción en rásteres). Se prefieren nombres claros,
  documentación explícita y validación de rangos plausibles.
- Reevaluar en M2 si aparecen errores de unidades difíciles de prevenir.
- Convenciones de unidades del núcleo y constantes físicas: §3.1
  (`R/constants.R`).

## 6. Decisiones abiertas

### 6.1 Backend de GWR — **DECIDIDO** (2026-11-04)

Núcleo GWR **interno** (R base) como motor de cálculo; `GWmodel` solo en
`Suggests` como referencia de tests; `mgwrsar` como opción futura para MGWR;
`spgwr` descartado. Evaluación y fundamentos en
[`decisions/gwr-backend.md`](decisions/gwr-backend.md); especificación del
módulo en `specs/gwr-forcing.md`.

Tabla original de candidatos (observada en CRAN el 2026-11-04):

| Opción | Versión CRAN | Licencia | Comentario |
|---|---|---|---|
| Implementación interna (mínimos cuadrados ponderados) | – | MIT | Control total, sin dependencias; requiere verificación contra referencia |
| `GWmodel` | 2.4-1 | GPL (≥ 2) | Amplio (GWR, bandwidth, diagnósticos, MGWR); dependencias espaciales |
| `spgwr` | 0.6-37 | GPL (≥ 2) | Histórico; evaluar estado de mantenimiento |
| `mgwrsar` | 1.4.1 | GPL (≥ 2) | GWR/MGWR con componentes espaciales; evaluar |

Criterios: mantenimiento, disponibilidad CRAN, compatibilidad
multiplataforma, peso de dependencias, licencia, posibilidad de verificar
contra casos publicados. Una opción razonable es implementar internamente el
núcleo GWR y usar un paquete externo **solo en tests** (Suggests) como
referencia cruzada.

Nota de licencias: un paquete MIT puede declarar en `Imports` paquetes GPL
(práctica habitual en CRAN), pero no debe copiar su código.

### 6.2 Backend espacial — **ACEPTADO: `terra`** (2026-11-04)

- Ráster: **`terra`** (GPL ≥ 3; 1.9-50 en CRAN al 2026-11-04). Motivos:
  mantenimiento activo, procesamiento fuera de memoria por bloques, álgebra
  ráster en C++, multiplataforma, sucesor de `raster`.
- Vector (AOI, estaciones): `terra::vect()` cubre lo necesario; `sf`
  (GPL-2 | MIT; 1.1-3) se agregará solo si se justifica (p. ej., interoperar
  con objetos `sf` del usuario, que también pueden aceptarse vía `Suggests`).
- `terra` se declarará en `Imports` **cuando exista la primera función que
  lo use** (M2/M4); declararlo antes produce un NOTE de `R CMD check`
  ("Namespace in Imports field not imported from").
- El núcleo físico sigue siendo aritmético y vectorizado (sección 3): las
  mismas funciones `ef_*()` operan sobre `numeric` y sobre `SpatRaster`
  (la aritmética de `terra` es vectorizada por capas), y solo se usa
  `terra::lapp()`/`terra::app()` cuando un cálculo no es expresable como
  álgebra ráster (p. ej., iteraciones de estabilidad).

### 6.3 Procesamiento en paralelo — **ACEPTADO como requisito; diseño en M1**

Dos niveles, con responsabilidades separadas:

| Nivel | Qué se paraleliza | Mecanismo propuesto |
|---|---|---|
| Intra-escena (píxeles) | Funciones por píxel no expresables como álgebra ráster | `terra::app(..., cores = )` / `terra::lapp()` por bloques; la álgebra ráster ya es eficiente sin paralelizar |
| Entre tareas | Fechas/escenas, perfiles de bandwidth GWR, validación cruzada, bootstrap | Framework `future` (`future.apply` o `furrr`, a decidir) |

Reglas:

1. **Secuencial por defecto.** El usuario elige el plan (`future::plan()`)
   o el número de núcleos; el paquete nunca fija un plan global.
2. **Resultados idénticos en secuencial y en paralelo**, incluidas las
   semillas (`future.seed = TRUE` o equivalente); se verificará con tests.
3. **Sin `parallel::mclapply()`** como mecanismo principal (no funciona en
   Windows).
4. **CRAN:** los tests y ejemplos usan como máximo 2 núcleos y corren
   secuencialmente por defecto.
5. `future`/`future.apply` entran a `Imports` o `Suggests` solo con la
   primera función que los use, justificando la elección.
6. Medir antes de optimizar: benchmarks reproducibles en `dev/` (no en el
   tarball) antes de introducir paralelismo en una etapa.

**Estado M3 (2026-11-04).** Primera función paralela: `ef_regionalize()`
y `ef_regionalize_cv()` (`specs/parallel-processing.md`, nota de estado;
`specs/gwr-forcing.md`, estado de la orquestación, punto 12). ARCH-6.3b
resuelta para esta etapa con `future.apply` (`future_lapply(future.seed =
TRUE)` solo si `future::nbrOfWorkers() > 1`, si no `lapply()`); `future` y
`future.apply` en `Imports`. Las tareas son ajustes por `target_time`,
bloques de predicción y pliegues de CV, y reciben matrices y modelos,
nunca un `SpatRaster`; el proceso principal lee y escribe los bloques en
orden. Tests: `block_rows` = 1, 7, 60 y el de `terra` dan rásteres
`identical()`; secuencial = `multisession` (2 workers) `identical()`,
omitido en CRAN.

Benchmarks (R 4.3.3, 4 núcleos, BLAS de referencia; orientativos):

| Caso | Secuencial | 2 workers | Fuente |
|---|---|---|---|
| GWR bicuadrado fijo 40 km, 150 estaciones, 2 `target_time`, 2,5 × 10⁵ celdas | 16,0 s (13,4 s con `block_rows = 50`) | 7,4 s (2,2×) | `dev/benchmarks/regionalize.R` |
| Ídem, 10⁶ celdas | 46,8 s | 28,7 s (1,6×) | Ídem |
| Predicción exacta del núcleo, 150 estaciones → 99 856 celdas | 1,9–3,6 s según kernel | — | `dev/benchmarks/gwr-core.R` |
| `ef_regionalize()`, 35 estaciones, 60 × 60 celdas, `block_rows` = 1 / 5 / 60 (antes → después de la caché del registro de flags, §3.4) | 4,37 → 0,44 s / 0,91 → 0,12 s / 0,21 → 0,09 s | — | Armonización M3 (mediana de 3) |

Las sumas ponderadas del núcleo GWR usan `colSums()` y no un producto BLAS
(`crossprod()`), para que el valor de una celda no dependa del bloque en
que se calcula (los productos BLAS pueden cambiar el orden de suma con la
forma de la matriz); cuesta ≈ 7× en esa operación con el BLAS de
referencia y es la condición del test `identical()` por bloques
(`gwr-forcing.md`, estado del núcleo, punto 5). Abierto: el `datatype` de
la superficie en disco (D-PP-05; hoy el de `wopt`, por defecto `FLT4S`) y
la paralelización intra-escena del núcleo METRIC (M5).

### 6.4 Lecciones del paquete `water` (inspiración, sin reutilizar código)

Revisado: `midraed/water` v1.0 (2026-10-19), GPL (≥ 2), `terra` + `sf`.
**No se copia código** (GPL no es compatible con la licencia MIT de
EarthFlux); se reimplementa desde las fuentes primarias.

| Observación en `water` | Decisión en EarthFlux |
|---|---|
| Las funciones físicas reciben objetos del sensor (`MTL`, `image.DN`, `sat`) | Núcleo independiente del sensor (principios 1–2) |
| Un único objeto de estación meteorológica fuerza toda la escena | Forzamiento espacial como módulo propio (`spatial`), comparable con estación única (hipótesis H1) |
| Archivos de 700–1.100 líneas; envoltorio `METRIC.EB()` | Un archivo por componente; API alta que solo orquesta |
| `netRadiation()` recibe LAI (emisividad) además de Rs↓, RL↓, RL↑ | Tratar explícitamente el término de onda larga reflejada (SPEC §3) |
| Coeficiente del píxel frío expuesto como argumento (`ETp.coef`) | Registrar el coeficiente y su referencia en el registro de anclas |
| Descarga de MDE dentro del flujo | Descargas siempre opcionales y fuera de tests/ejemplos |
| 2 archivos de tests | Tests por componente desde M2 |
| Sin paralelismo explícito | Estrategia de paralelismo (sección 6.3) |

### 6.5 Gestión del entorno (no decidido)

`renv` se considera para el repositorio de experimentos científicos, no para
el paquete. No se agrega en M0.

### 6.6 Lecciones de `thermify` (paquete propio del autor)

Revisado: `djwillichile/thermify` v0.3.1 (MIT, `terra`). Al ser del mismo
autor y licencia, sus convenciones se adoptan como estilo de la casa.

| Patrón en `thermify` | Adopción en EarthFlux |
|---|---|
| Motor interno sobre matrices (celdas × tiempo) que nunca lee ni escribe archivos (`engine.R`) | Núcleo `ef_*()` aritmético y vectorizado (sección 3) |
| Envoltorio ráster por bloques con `terra::readStart()` / `writeStart()` y opciones de escritura explícitas | Patrón base para los envoltorios ráster (M2/M4); el paralelismo (6.3) se agrega sobre este patrón, no en su lugar |
| Test de integración "el tamaño de bloque no cambia el resultado" | Igual, más "secuencial = paralelo" |
| Verificación cruzada contra implementaciones GPL sin empaquetarlas (`inst/verification/`) | Script de verificación contra `water` (GPL) en `dev/verification/` (excluido del tarball porque `dev/` está en `.Rbuildignore`; `inst/` sí se incluiría), cargado solo si `water` está instalado |
| Grupos de tests opcionales por variable de entorno (online, lentos, referencias externas) | `EARTHFLUX_ONLINE_TESTS`, `EARTHFLUX_SLOW_TESTS` (por definir) |
| Historias de usuario con tests de aceptación (`docs/USER_STORIES.md`, `test-story-XX.R`) | A definir en M1 (`dev/USER_STORIES.md`) |
| Workflows `pkgdown` (gh-pages) y `release` (tag ↔ versión ↔ sección de NEWS) | Planificados para M0/M7 |
| `.zenodo.json`, `CITATION.cff`, `inst/WORDLIST` | `CITATION.cff` creado; `.zenodo.json` y `WORDLIST` con el primer release |
| `Language: en-GB` | Adoptado |
| Sin paralelismo explícito | EarthFlux lo incorpora (6.3) con verificación de equivalencia |

### 6.7 Carga de entradas de la API de usuario — **DECIDIDO** (2026-11-05)

Decisión del autor (`DECISIONS.md` §1.5, M5-01 … M5-07). Motivo: al
preparar la escena de validación del Maule (2019-02-15) se acumularon
MODIS, MDE, cobertura de suelo, ~40 estaciones horarias y ~15 opciones
científicas; exigir todo eso para obtener un mapa de ETa haría el paquete
inutilizable fuera de la investigación.

**Tres niveles de uso**, todos sobre el mismo núcleo (principio 4):

| Nivel | Llamada (forma prevista) | Entradas del usuario | Lo demás |
|---|---|---|---|
| Básico | `earthflux(aoi, date, weather, preset)` | Área, fecha, **una** fuente meteorológica (una estación o una fuente grillada, M5-07) y el nombre de un preset | MODIS y MDE descargados y preparados por el paquete |
| Avanzado | Ídem con `weather` = tabla de estaciones y forzamiento GWR | Tabla de estaciones (C3) | Covariables derivadas del MDE (elevación) |
| Experto | Funciones `ef_*()` y `modis_*()` | Todas las opciones explícitas, como hoy | — |

**Entradas mínimas del producto** (nivel básico):

| Entrada | Requisito | Fuente |
|---|---|---|
| Área y fecha | Sí | Usuario |
| Estado de superficie MODIS | Sí | Descarga automática (CMR + LP DAAC, token Earthdata del entorno; M4-26) |
| Elevación | Sí (presión, Ts,datum) | Descarga automática del MDE (M5-06) |
| Pendiente y orientación | Solo con relieve | Derivadas del mismo MDE; opción explícita de terreno plano |
| Meteorología a la hora de paso y diaria | Sí (ETr de calibración) | Usuario: una estación; o, sin estaciones, **ERA5 vía Open-Meteo** descargado por el paquete (M5-07) |
| Cobertura de suelo | **No** | Opcional, solo como máscara de exclusión (M5-05) |

**Forzamiento sin estaciones (M5-07, decisión del autor del 2026-11-05).**
La fuente predeterminada del nivel básico cuando el usuario no entrega
estaciones es **ERA5 vía la API histórica de Open-Meteo**
(`archive-api.open-meteo.com`, modelo `era5`; nunca `era5_land` solo, que
no entrega radiación, viento ni presión): temperatura y punto de rocío a
2 m, viento a 10 m, radiación de onda corta y presión en superficie,
horarios, sin credencial. Condiciones: (1) licencia CC BY 4.0 con
atribución en la procedencia; el plan gratuito es solo **no comercial**
(< 10 000 llamadas por día), por lo que `earthflux()` acepta una clave
opcional (`apikey`) para uso comercial; (2) el ajuste por elevación que
aplica la API es una opción explícita registrada en la procedencia;
(3) ERA5 comprime la amplitud diaria (en el contraste del 2019-02-15,
Tmax 2–3 K bajo y Tmin 3–4 K alto) y su celda (0,25°) da un forzamiento
casi uniforme a escala de valle: el resultado lleva un flag de forzamiento
grillado y no reemplaza a las estaciones en la validación; (4) viento y
valores a la hora de paso quedan sin evaluar hasta tener datos horarios de
estaciones.

**Presets (M5-04, M5-08 … M5-17; `specs/presets.md`).** Un preset es un
conjunto nombrado, documentado y versionado de todas las opciones
científicas de la cadena; `earthflux()` lo exige como argumento (una
elección explícita en lugar de ~15, sin defecto), y cada opción efectiva
queda en la procedencia del resultado. El núcleo conserva la regla de
métodos sin defecto (§3.1, T-15); un preset solo se rotula `VERIFICADA` si
todas sus formulaciones lo están. **M5-08** (2026-11-06; reescribe
D-AP-01): se admiten presets no verificados; su estado se declara en su
documentación y en la procedencia (**no en el nombre**), y `earthflux()`
emite un aviso `earthflux_unverified_preset_warning` con los elementos no
verificados. Presets implementados (ambos `CANDIDATA`, versión `"1"`):
`idaho2002_elev` (formas del manual SEBAL-Idaho 2002 con los ajustes por
elevación del ap. 12) e `idaho2002_flat` (procedimiento base del manual);
ninguno usa la pendiente hasta resolver RC-09. Se consultan con
`ef_presets()` y `ef_preset(name)`.

**Firma implementada** (M5, fase 2): `earthflux(aoi, date, weather, preset,
cache_dir = tools::R_user_dir("EarthFlux", "cache"), apikey = NULL,
surface = NULL, terrain = NULL)`; `weather` = `"era5"` o una tabla de
`ef_station_table()` (una estación → C1; varias → C2 IDW); `surface` y
`terrain` permiten la ruta experta con objetos ya preparados. Archivos:
`R/api-presets.R`, `R/api-prepare.R`, `R/api-run.R`, `R/api-earthflux.R`.

