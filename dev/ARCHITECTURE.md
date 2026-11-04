# EarthFlux — Arquitectura

Estado: **borrador M0**; §3–§4 actualizadas para M2 y M3, §6.3 con el
estado de M3 (2026-11-04) · Complementa `SCIENTIFIC_SPEC.md`.

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
| `surface` | Leer productos satelitales y convertirlos en variables físicas estandarizadas (Ts, α, NDVI, LAI, ε₀) con QA y procedencia | `io-modis.R`, `prep-modis.R`, `io-aoi.R` | Ecuaciones de balance de energía |
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
| Formulaciones no verificadas | Mientras P0-1 … P0-3 sigan abiertas: `CANDIDATA`, expuestas mediante argumentos explícitos **sin defecto** (p. ej., `stable_psi_m_height` en el control de H, SH-11; `ef_rl_in(temperature, …)` agnóstica, RC-12) y rotuladas como `CANDIDATA` en roxygen |
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

Cada función devuelve `ef_flag_rows(code, stage, severity, scope, bit,
error_class, description, spec, since)` (sin argumentos: tabla de cero
filas). Falta solo el módulo `surface`, que agregará su
`ef_flags_<etapa>()` con su primer código. Las columnas, la severidad
`critical` y las reglas de validación están en `specs/flags.md` §4.2, §5 y
§8. Recuento al 2026-11-04: 54 códigos (`INPUT` 1, `RAD` 4, `G` 4,
`ANCHOR` 10, `H` 8, `ET` 1, `WS` 13, `GWR` 13; `specs/flags.md` §4.4).

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
§1.3, M3-18). Los objetos con una sola tabla o vector no lo llevan. Los
flags de celda de las superficies regionalizadas no son registros con
índice: viven en la palabra de flags (`flag_word`, §4).

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

**Resultado** (`earthflux_result`, futuro): capas Rn, G, rah, dT, H, LE,
ET_inst, ETrF, ETa; registro de anclas; parámetros de GWR; flags;
procedencia (versiones, productos, escenas, estaciones, parámetros, semilla).

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
