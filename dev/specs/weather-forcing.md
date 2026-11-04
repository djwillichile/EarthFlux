# EarthFlux — Especificación: forzamiento meteorológico (estaciones, QC, variables derivadas y ET de referencia)

Estado: **borrador M1**; §4–§5 implementadas en M3 y verificadas contra FAO-56 y ASCE-EWRI 2005 (ver §13, §13.5) · Módulo: `forcing` (`ARCHITECTURE.md` §2) ·
Archivos de destino: `R/io-weather.R`, `R/prep-weather.R`, `R/prep-qc.R`
(ubicación de las funciones compartidas: decisión WF-01) · Tests:
`tests/testthat/test-weather.R` y, propuesto, `test-reference-et.R`.

> Este documento detalla `SCIENTIFIC_SPEC.md` §1.2 (puntos de entrada del
> forzamiento), §3 (fila ETr), §5 (variables meteorológicas y decisión 5.1)
> y §8 (QC de estaciones), y el contrato "Forzamiento meteorológico" de
> `ARCHITECTURE.md` §4. `SCIENTIFIC_SPEC.md` sigue siendo la fuente de
> verdad: cuando una ecuación de este documento esté `VERIFICADA`, su
> estado, referencia y caso numérico deben trasladarse allí.

Convención de estados: la misma de `SCIENTIFIC_SPEC.md` (`TODO`,
`CANDIDATA`, `VERIFICADA`). En este documento, `VERIFICADA` significa
**ecuación contrastada en esta redacción con la fuente primaria** (FAO-56,
leída en línea; y, desde 2026-11-04, el informe final de ASCE-EWRI de
enero de 2005 para la ecuación estandarizada; ver §1.2 y §13.5). La Definition of Done (`DEVELOPMENT.md` §3)
exige además referencia completa en `REFERENCES.md`, NA, dominio y tests
diseñados: este documento los especifica, pero la integración en
`SCIENTIFIC_SPEC.md` y `REFERENCES.md` queda pendiente (no se editan aquí).

---

## 0. Índice y resumen

1. Alcance, fuentes consultadas y nivel de evidencia
2. Contrato de la tabla estándar de estaciones
3. Control de calidad (QC) de estaciones
4. Variables derivadas (verificadas contra FAO-56)
5. ET de referencia: ETr (alfalfa, ASCE-EWRI) y ETo (pasto, FAO-56)
6. Decisión 5.1: interpolar y luego calcular vs calcular y luego interpolar
7. Variables espaciales vs escalares de estación; interfaz con `spatial`
8. Casos de verificación (ejemplos de FAO-56) y tests planificados
9. Contexto chileno (solo ítems abiertos)
10. Hallazgos que afectan a otros documentos (no editados aquí)
11. Registro de decisiones abiertas
12. Registro de fuentes y accesos
13. Estado de implementación (M3)

Resumen de estados:

| Bloque | Estado | Fuente |
|---|---|---|
| Presión atmosférica P(z), constante psicrométrica γ | `VERIFICADA` | FAO-56 Ec. 7, Ec. 8; ASCE-EWRI (2005) Ec. 3–4, 34–35 |
| e°(T), es, Δ, eₐ (Tdew, HR horaria, HRmax/HRmin, HRmax, HRmedia, Tmin), déficit | `VERIFICADA` | FAO-56 Ec. 11–14, 17–19, 48, 54; ASCE-EWRI Ec. 5–8, 11–14, 36–38, 41 (Δ con 2503: §4.3) |
| Viento a 2 m (perfil logarítmico sobre pasto) | `VERIFICADA` | FAO-56 Ec. 47; ASCE-EWRI Ec. 33, 67 |
| Ra diaria y por período (horaria o menor), dr, δ, ωs, ω, Sc | `VERIFICADA` | FAO-56 Ec. 21–33; ASCE-EWRI Ec. 21–29, 48–61 (límites de la Ec. 56 con `standard = "asce"`) |
| Rso (simple por elevación); variantes con turbidez y vapor | `VERIFICADA` (forma FAO-56) | FAO-56 Ec. 36–37; Anexo 3 Ec. 3-13 a 3-20; ASCE-EWRI Ec. 19, 47 |
| Rns, Rnl, Rn de la superficie de referencia (diaria y horaria) | `VERIFICADA` | FAO-56 Ec. 38–40 y §"Hourly time step"; ASCE-EWRI Ec. 15–18, 42–46 (σ y límites propios) |
| G de la superficie de referencia (pasto y alfalfa): diario 0; horario 0.1/0.5 Rn y 0.04/0.2 Rn | `VERIFICADA` | FAO-56 Ec. 42, 45, 46; ASCE-EWRI Ec. 30, 65a–b, 66a–b |
| ETo pasto FAO-56, diaria y horaria | `VERIFICADA` | FAO-56 Ec. 6, Ec. 53 |
| ETos/ETrs ASCE-EWRI (Cn, Cd, G por paso y día/noche) | `VERIFICADA` | ASCE-EWRI (2005) Ec. 1 y Tabla 1 (p. 4–5); ejemplos del Apéndice C no leídos (§8.2) |
| ETr instantánea a la hora de paso | `TODO` (método: decisión WF-09) | – |
| Umbrales numéricos de QC (rango, salto, persistencia) | `TODO` | Sin fuente primaria leída |

---

## 1. Alcance, fuentes consultadas y nivel de evidencia

### 1.1 Alcance

Incluye: (i) el contrato de datos de estaciones meteorológicas;
(ii) el QC de esas series; (iii) las variables derivadas necesarias para la
ET de referencia y para el forzamiento de METRIC; (iv) la ET de referencia
horaria e instantánea (ETr_inst) y diaria (ETr24); (v) la interfaz con el
módulo `spatial` (la especificación de GWR se redacta por separado).

No incluye: la regionalización (GWR y alternativas), el viento a la altura
de mezcla y la rugosidad de la estación para `rah` (módulo `metric`,
`metric-aerodynamics.R`), la radiación de onda corta/larga **del píxel**
(`radiation-components.md`), ni la ETrF y la ETa (`metric-et.R`).

Distinción que atraviesa todo el documento:

- **Superficie de referencia** (pasto o alfalfa hipotéticos, bien regados):
  su Rn, G y ET se calculan con las ecuaciones estandarizadas de §4–§5.
  Son definiciones convencionales, no observaciones del píxel.
- **Superficie del píxel** (METRIC): Rn, G, H y LE del píxel se especifican
  en `radiation-components.md`, `ef_net_radiation.md` y
  `soil-heat-flux.md`. No deben mezclarse funciones de ambos grupos
  (p. ej., G = 0.1·Rn de la referencia no es un método de G del píxel;
  ya registrado en `soil-heat-flux.md` §3.3).

### 1.2 Fuentes y nivel de evidencia

| Fuente | Tipo | Acceso en esta redacción | Uso |
|---|---|---|---|
| Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop evapotranspiration — Guidelines for computing crop water requirements*. FAO Irrigation and Drainage Paper 56. FAO, Roma. ISBN 92-5-104219-5 (datos de la portada de la versión HTML) | Primaria | **Leída** en `www.fao.org` (versión HTML, redirigida a `https://www.fao.org/4/x0490e/`): cap. 2 (`x0490e06.htm`), cap. 3 (`x0490e07.htm`), cap. 4 (`x0490e08.htm`), anexos 2, 3, 5 y 6 (`x0490e0j.htm`, `x0490e0k.htm`, `x0490e0m.htm`, `x0490e0n.htm`). Las ecuaciones están como imágenes y se leyeron una a una | Ecuaciones `VERIFICADA` y ejemplos numerados como casos de prueba |
| ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration Equation*. Task Committee on Standardization of Reference Evapotranspiration, Environmental and Water Resources Institute of the American Society of Civil Engineers. Informe final, enero de 2005 | Primaria | **Leído (2026-11-04)**: copia PDF del informe final del Task Committee (70 páginas: i–vii y 1–59; metadatos del PDF: creado 2005-02-28) descargada por el integrador junto con su texto (`pdftotext -layout`); la URL de descarga no quedó registrada en esta rama. La copia **no incluye los apéndices A–F** (solo su lista, p. vii), por lo que el Apéndice C (ejemplos de Greeley, Colorado) no se leyó. Portada (p. i): editores principales Allen, Walter, Elliott, Howell, Itenfisu y Jensen (Snyder figura entre los miembros del comité). Edición publicada por ASCE (metadatos vía Crossref, M3 previo): DOI `10.1061/9780784408056`, 2005-08-03, editores Allen, Walter, Elliott, Howell, Itenfisu, Jensen y Snyder, ISBN 9780784408056 / 9780784475638 | Ecuación estandarizada, constantes de ETos/ETrs y reglas de §4–§5: `VERIFICADA` con ecuación, tabla y página (§13.5) |
| `water` v1.0 (GPL ≥ 2), `R/water_ET.R` (`hourlyET()`, `asceHourly()`, `asceRa()`, `dailyET()`, `ET24h()`) y `R/water_WeatherStation.R` (`read.WSdata()`) | Secundaria (implementación) | Leído (clon de solo lectura) | Qué constantes y números de ecuación de ASCE-EWRI atribuye una implementación; diseño de manejo de estaciones. **No se copia código**. Sustituida por el informe primario (§13.5) |
| `SPEI` 1.8.1 (CRAN, GPL-2), `R/penman.R` | Secundaria (implementación) | Leído (fuente descargada de `cran.r-project.org`) | Corroboración independiente de Cn/Cd diarios de referencia alta/baja. **No se copia código**. Sustituida por el informe primario (§13.5) |
| `radiation-components.md`, `soil-heat-flux.md`, `ef_net_radiation.md` | Internas | Leídas | Coherencia de nombres, convenciones y decisiones (RC-xx, Dx) |

Limitaciones registradas:

- **Páginas de FAO-56:** la versión HTML no tiene numeración de páginas y
  no se encontró el PDF en `www.fao.org` (dos URL probadas devolvieron 404).
  Las citas usan número de ecuación + capítulo/anexo + archivo HTML.
  `TODO`: añadir número de página de la edición impresa/PDF.
- **Erratas de OCR:** la portada HTML declara que el documento electrónico
  fue digitalizado con OCR y corregido manualmente. Se detectaron erratas
  tipográficas en los ejemplos (§8.3). Las ecuaciones (imágenes) se leyeron
  directamente; los valores numéricos de los ejemplos se recalcularon.

---

## 2. Contrato de la tabla estándar de estaciones

### 2.1 Estructura

Se proponen **dos tablas** (data frames) unidas por `station_id`, más
atributos de procedencia. Separar metadatos de observaciones evita repetir
coordenadas y alturas en cada fila y permite validar cada una por separado.

```text
ef_station_table(stations, observations, provenance)   # constructor + validador
  → objeto de clase "earthflux_station_table"
     $stations       una fila por estación
     $observations   una fila por (station_id, timestamp)
     $provenance     lista (ver §2.5)
     $qc             tabla larga de flags (vacía hasta ef_station_qc(); §3)
```

Nombres propuestos (decisión WF-03): `ef_station_table()` (constructor y
validador; exportado) y `ef_validate_stations()` (interna).

### 2.2 Tabla `stations`

| Campo | Tipo | Unidad | Obligatorio | Validación | Comentario |
|---|---|---|---|---|---|
| `station_id` | character | – | Sí | No `NA`, único | Identificador estable del proveedor |
| `lon` | double | grados decimales, WGS84 (EPSG:4326), positiva al este | Sí | [−180, 180] | Conversión a radianes en el envoltorio (RC-01) |
| `lat` | double | grados decimales, WGS84, positiva al norte | Sí | [−90, 90] | Ídem |
| `elevation` | double | m sobre el nivel del mar | Sí | Finito | Datum vertical `TODO`. Se usa en P(z) (Ec. 7) y Rso (Ec. 37) |
| `height_wind` | double | m sobre el suelo | Sí (si hay viento) | > 0,0947 m (dominio de la Ec. 47, §4.5) | Altura del anemómetro (Ec. 47) |
| `height_temp_rh` | double | m sobre el suelo | Sí (si hay T/HR) | > 0 | FAO-56 supone 2 m (cap. 2, Ec. 6); otra altura → flag, sin corrección (no hay ecuación verificada) |
| `surface_type` | factor | – | No (recomendado) | `reference_grass`, `reference_alfalfa`, `irrigated_other`, `non_reference`, `unknown` | Condición del entorno (FAO-56 Anexo 6, §3.3 QC-08) |
| `network`, `provider` | character | – | No | – | Red y entidad responsable |
| `license`, `terms_url` | character | – | No (recomendado) | – | Licencia y condiciones de uso (§9) |
| `name`, `notes` | character | – | No | – | Libres |

### 2.3 Tabla `observations`

| Campo | Tipo | Unidad | Obligatorio | Comentario |
|---|---|---|---|---|
| `station_id` | character | – | Sí | Debe existir en `stations` |
| `timestamp` | `POSIXct` | segundos UTC | Sí | Ver §2.4 |
| `air_temperature` | double | °C | Sí (ETr) | Media del período (decisión WF-02, °C vs K) |
| `relative_humidity` | double | % | Uno de HR, Tdew o eₐ | Media del período (Ec. 54) |
| `dewpoint_temperature` | double | °C | Alternativa | Ec. 14 |
| `vapour_pressure` | double | kPa | Alternativa | Si el proveedor la entrega |
| `wind_speed` | double | m s⁻¹ | Sí (ETr) | A `height_wind`; media escalar del período |
| `solar_radiation` | double | W m⁻² | Sí (ETr) | Irradiancia global media del período, sobre horizontal |
| `air_pressure` | double | kPa | No | Medida; uso según RC-08 y WF-05 |
| `precipitation` | double | mm | No | Solo contexto de QC (QC-07, QC-08) |
| `net_radiation` | double | W m⁻² | No | Solo verificación/validación (FAO-56 Anexo 5) |

Para datos diarios (`interval` = 1 d) los campos son `tmax`, `tmin` [°C],
`rh_max`, `rh_min` [%] (u otra fuente de eₐ, Ec. 14, 17–19),
`wind_speed` [m s⁻¹] y `solar_radiation` [W m⁻², media de 24 h]. FAO-56
cap. 3 define Tmax y Tmin como los extremos del período de 24 h que
comienza a medianoche y Tmedia = (Tmax + Tmin)/2 (Ec. 9), no el promedio de
valores horarios.

**Unidades de energía.** El contrato usa W m⁻² (media del período) porque es
la convención de los registradores y de los módulos de radiación; las
funciones de ET de referencia trabajan en MJ m⁻² por período. Conversión
(FAO-56 cap. 3, Tabla 3, `VERIFICADA`): 1 W m⁻² = 0,0864 MJ m⁻² d⁻¹; por
hora, 1 W m⁻² = 0,0036 MJ m⁻² h⁻¹ (3600 s / 10⁶). Equivalente de
evaporación: 0,408 × MJ m⁻² d⁻¹ = mm d⁻¹ (Ec. 20; 1/λ con λ = 2,45 MJ kg⁻¹).

Sin conversiones implícitas: el constructor no adivina unidades. Las
conversiones se declaran (`units = list(wind_speed = "km/h", ...)`) y quedan
en la procedencia. Las heurísticas de detección de unidades erróneas
producen flags (QC-01b), nunca conversiones.

### 2.4 Tiempo

Coherente con `radiation-components.md` §4.4 (RC-03):

- `timestamp` debe ser `POSIXct`. Entrada de tipo carácter → error
  clasificado (`earthflux_input_error`), salvo que el usuario entregue el
  formato **y** la zona horaria explícita (`tz` obligatorio, sin valor por
  defecto; un `tz` vacío o ausente → error, no advertencia). Se almacena en
  UTC (`attr(, "tzone") <- "UTC"`).
- **Semántica del período** (atributo obligatorio de la tabla):
  `timestamp_convention ∈ {"end", "start", "instant"}` e `interval` (p. ej.,
  `3600` s). Para medias de período, el punto medio es
  `timestamp − interval/2` ("end") o `timestamp + interval/2` ("start").
  FAO-56 Ec. 31 usa la hora **en el punto medio** del período. Sin esta
  declaración no se puede calcular Ra horaria correctamente → error.
- Duplicados (`station_id`, `timestamp`): **error** si los valores difieren
  (no se promedian en silencio); duplicados exactos → se conservan una vez y
  se registra el hecho en la procedencia. (El paquete `water` promedia los
  duplicados con advertencia; EarthFlux no lo adopta: principio 6.)
- Huecos y pasos irregulares → flags (QC-09), no relleno.
- Horario de verano: al almacenar en UTC desaparece la ambigüedad, siempre
  que la conversión desde hora local use la zona IANA correcta (`TODO`
  verificar qué zona y convención usa cada red, §9).

### 2.5 Procedencia

Por tabla: fuente (archivo, URL o API), fecha de descarga/lectura, hash del
archivo de origen, red/proveedor, licencia, unidades de origen y
conversiones aplicadas, `timestamp_convention`, `interval`, zona horaria de
origen, versión de EarthFlux, y registro de operaciones posteriores (QC,
política de exclusión, interpolación temporal). Por estación: los campos de
§2.2. La procedencia viaja con todo producto derivado (ETr, superficies) y
se incorpora al `earthflux_result` (`ARCHITECTURE.md` §4).

### 2.6 Validadores y errores

| Situación | Clase | Ejemplo |
|---|---|---|
| Falta un campo obligatorio, tipo incorrecto, `timestamp` sin zona | `earthflux_input_error` | `timestamp` de tipo carácter sin `tz` |
| Valor físicamente imposible | `earthflux_domain_error` | HR < 0; viento < 0; altura ≤ 0; T ≤ −273,15 °C |
| `station_id` de observaciones ausente en `stations`; duplicados con valores distintos | `earthflux_input_error` | – |
| Valor posible pero sospechoso | **flag** de QC (§3), sin corrección | HR = 102 % |

Los imposibles se tratan como errores **en el constructor** solo cuando la
imposibilidad es inequívoca. Decisión WF-04: en series largas un único
valor imposible detendría todo; alternativa: marcarlo con flag de severidad
`error` y excluirlo por política. Recomendación provisional: flag (no
error) en `observations`; error solo en `stations` (metadatos).

### 2.7 Estado de implementación (M3, 2026-11-04)

Implementado en `R/io-weather.R` (`ef_station_table()`, exportada;
`ef_validate_stations()`, interna) con tests en
`tests/testthat/test-weather.R` y datos sintéticos en
`tests/testthat/helper-stations.R`. Decisiones tomadas al implementar
(provisionales, registradas en `DECISIONS.md` §1.3, M3-07 y M3-08):

- **WF-03** adoptada: dos `data.frame` base + clase S3
  `earthflux_station_table` (`new_ef_object()`), con elementos `stations`,
  `observations`, `provenance`, `qc` (tabla vacía hasta el QC) y `flags`
  (lista vacía). Entradas que heredan de `data.frame` (p. ej., tibble) se
  convierten a `data.frame` base.
- **WF-04** adoptada según `flags.md` (clase III): imposibles en
  `stations` → `earthflux_domain_error`; imposibles en `observations` → se
  conservan y `ef_station_qc()` los marca con severidad `critical`. Valores
  infinitos en `observations` → `earthflux_domain_error` (no son medidas).
- **Altura del anemómetro:** dominio > (1 + 5,42)/67,8 = 0,0947 m (Ec. 47).
  La cota tiene una sola fuente, `ef_wind_2m_min_height()` (interna, en
  `R/forcing-derived.R`), que usan `ef_wind_2m()` y el validador de la
  tabla (resuelto el antiguo `TODO(shared)`). Alturas `NA` permitidas (flag
  QC-11); la columna es obligatoria si se observa la variable.
- **CRS:** campo obligatorio `provenance$crs`, que debe ser exactamente
  `"EPSG:4326"` (la proyección la hace `spatial`).
- **Tiempo:** `POSIXct` con `tzone` explícito no vacío (si no →
  `earthflux_station_time_error`); carácter solo con `timestamp_format` y
  `tz` (zona IANA de `OlsonNames()`), ambos sin defecto; cadenas no
  interpretables (incluidas horas locales inexistentes por cambio de
  horario) → error. `timestamp_convention` e `interval` (s, entero positivo)
  son campos obligatorios de `provenance`.
- **Unidades:** conversiones solo declaradas (`units =`), con factores
  exactos (K → °C con `EF_KELVIN_OFFSET`; km/h; hPa, Pa; fracción → %;
  MJ m⁻² h⁻¹ y MJ m⁻² d⁻¹ → W m⁻², Tabla 3 de FAO-56), registradas en
  `provenance$units`. Energía acumulada por período no se acepta (declarar
  la tasa).
- **Columnas fuera del contrato** → error (evita que un nombre mal escrito
  quede sin validar). Columnas numéricas se guardan como `double`; una
  columna lógica completamente `NA` se acepta como `NA_real_`.
- **Procedencia** añadida por el paquete (campos reservados): `source_tz`,
  `units`, `duplicates_removed`, `package_version` y `operations`
  (registro `step`/`detail`); `ef_station_qc()` añade `qc`, `flags` y
  `flags_evaluated`.
- **Errores** (todas subclases de `earthflux_input_error`):
  `earthflux_station_field_error`, `earthflux_station_time_error`,
  `earthflux_station_unknown_id`, `earthflux_station_duplicate`,
  `earthflux_station_provenance_error`, más `earthflux_domain_error`.
- **Pendiente:** lectores por red (§9), datum vertical, `ef_validate_stations()`
  sigue interna (§2.1).

---

## 3. Control de calidad (QC) de estaciones

### 3.1 Principios

1. **Marcar, nunca borrar ni corregir.** `ef_station_qc()` agrega filas a
   la tabla larga `$qc` (`station_id`, `timestamp`, `variable`,
   `flag_code`, `test_id`, `value`, `threshold`, `parameters`) y no
   modifica `observations`.
2. **La exclusión es una política explícita** del consumidor
   (`qc_policy = c("exclude_error", "exclude_warning", "keep_all")`, nombre
   a decidir), registrada en la procedencia.
3. Los umbrales sin fuente primaria se exponen como **parámetros sin valor
   por defecto** o con valor `NULL` (test desactivado) hasta documentarlos.
   No se inventan umbrales.
4. Los flags siguen la regla de `R/diagnostics.R`: solo se registran en
   `ef_flag_registry()` los de condición inequívoca y cuando esta
   especificación esté fusionada.

FAO-56 Anexo 5 (basado en Allen, 1996, según su nota 2) establece el marco:
"no data are better than bad data", evaluar la integridad antes de usar los
datos, y usar modelos (p. ej., Rso) para detectar errores y sesgos. Cita
también FAO 27 (Doorenbos, 1976) y las guías WMO (1981, 1983) para
instrumentación (`TODO`: no leídas).

### 3.2 Tabla de tests

| ID | Test | Variables | Escala | Condición | Fuente / estado | Flag propuesto | Severidad | ¿Umbral? |
|---|---|---|---|---|---|---|---|---|
| QC-01a | Rango físico imposible | HR, viento, Rs, T, P | Todas | HR < 0; viento < 0; T ≤ −273,15 °C; P ≤ 0 | Imposibilidad física (definición) | `EF_WS_IMPOSSIBLE` | error | No |
| QC-01b | Rango plausible / unidad sospechosa | T, viento, Rs, HR | Todas | Fuera de límites plausibles (p. ej., T en K pasada como °C; viento en km h⁻¹; Rs en MJ m⁻² h⁻¹ o kW m⁻²) | **Sin fuente primaria leída.** `water` v1.0 usa límites propios (−60–60 °C; HR 0–110 %; viento 0–75 m s⁻¹; Rs −50–2000 W m⁻²) sin cita: no se adoptan. `TODO`: guía WMO o literatura de QC de redes | `EF_WS_IMPLAUSIBLE` | warning | **Sí** `TODO` |
| QC-02 | HR > 100 % | HR | Todas | HR > 100 | FAO-56 Anexo 5: registros que **superan 100 % en más de 3–5 %** (madrugada o lluvia) indican necesidad de recalibración. `VERIFICADA` como criterio | `EF_WS_RH_GT100` (HR > 100) y `EF_WS_RH_RECALIBRATE` (HR > 100 + δ, δ ∈ [3, 5] %) | info / warning | δ: elegir en [3, 5] (WF-06) |
| QC-03 | Coherencia Tmin ≤ Tmax | Tmin, Tmax | Diaria | Tmin > Tmax | Definición (FAO-56 cap. 3) | `EF_WS_TMIN_GT_TMAX` | error | No |
| QC-04 | Coherencia Tdew ≤ T (eₐ ≤ e°(T)) | Tdew o eₐ, T | Todas | Tdew > T (equivalente a HR > 100 por Ec. 10) | Definición (FAO-56 Ec. 10, 14) | `EF_WS_TDEW_GT_TAIR` | warning | Tolerancia instrumental `TODO` |
| QC-05a | Rs sobre la envolvente de cielo despejado | Rs | Horaria, diaria | Rs > Rso (Rso = K_T·Ra, Anexo 5 Ec. 5-1; Rso por Ec. 37 o Anexo 3 Ec. 3-14/3-17) | FAO-56 Anexo 5: Rso debe ser **envolvente superior** de Rs medida; Rs puede superar Rso por reflexión de nubes cercanas (sin sombra sobre el sensor). `VERIFICADA` como criterio | `EF_WS_RS_GT_RSO` | warning | Margen `TODO` |
| QC-05b | Rs sobre la extraterrestre | Rs | Horaria, diaria | Rs > Ra (misma ventana) | Criterio propio, sin fuente leída: físicamente improbable para medias horarias o diarias; la condición es inequívoca de evaluar | `EF_RS_EXCEEDS_EXTRATERRESTRIAL` (ya propuesto en `radiation-components.md` §4.8) | warning | No |
| QC-05c | Calibración del piranómetro en días despejados | Rs | Diaria/horaria, multi-día | Máximos de Rs en días despejados sistemáticamente sobre o bajo Rso | FAO-56 Anexo 5 (corrección multiplicativa/aditiva posible, pero EarthFlux **no corrige**: solo diagnostica) | `EF_WS_RS_CALIBRATION` | warning | **Sí** `TODO` |
| QC-05d | Rs nocturna | Rs | Sub-diaria | Ra = 0 y Rs ≠ 0 | Desplazamiento (offset) del sensor; criterio físico | `EF_WS_RS_NIGHT` | info | Tolerancia `TODO` |
| QC-06 | Persistencia / línea plana | Viento, HR, T, Rs | Sub-diaria | Valor constante durante N registros | FAO-56 Anexo 5 (viento): revisar registros **consistentemente bajos y constantes** (offset del calibrado o falla del sensor; calma < 0,5 m s⁻¹ durante todo el período de muestreo es rara). `VERIFICADA` como criterio cualitativo para viento; para otras variables, `TODO` | `EF_WS_PERSISTENCE` | warning | N y tolerancia `TODO` |
| QC-07 | Salto / tasa de cambio | T, HR, viento, Rs | Sub-diaria | \|x_t − x_{t−1}\| > umbral | **Sin fuente primaria leída** | `EF_WS_STEP` | warning | **Sí** `TODO` |
| QC-08a | HRmax baja en entorno regado | HRmax | Diaria | HRmax consistentemente < 80–90 % en entorno regado | FAO-56 Anexo 5: indica problema de calibración **o** aridez del sitio (desviación de condición de referencia). `VERIFICADA` como criterio | `EF_WS_RHMAX_LOW` | warning | Elegir en [80, 90] % y ventana (WF-06) |
| QC-08b | Condición no-referencia (aridez) | Tmin, Tdew | Diaria/mensual | ΔT = Tmin − Tdew sistemáticamente mayor que ≈ 2 °C respecto de un sitio de referencia (Anexo 6 Ec. 6-2), o mayor que K₀ = 2 °C sin sitio de referencia (Ec. 6-1); o índice A_bi consistentemente > 0,05 (Ec. 6-7) | FAO-56 Anexo 6. `VERIFICADA` como diagnóstico | `EF_WS_NONREFERENCE` | info | Valores de FAO-56; aplicación a datos horarios `TODO` |
| QC-08c | Estabilidad diaria de Tdew/eₐ | Tdew, eₐ | Sub-diaria | Variación diurna de eₐ fuera de lo esperado con masa de aire estable | FAO-56 Anexo 5: eₐ y Tdew deben ser "algo constantes" en 24 h con masa de aire estable; el aumento diurno suele ser < 10–20 %; los errores de calibración de HR producen variación espuria de eₐ con T. Criterio cualitativo | `EF_WS_EA_DIURNAL` | info | **Sí** `TODO` |
| QC-09 | Integridad temporal | `timestamp` | Todas | Huecos, pasos irregulares, desfase horario sospechoso (p. ej., máximo de Rs lejos del mediodía solar) | Criterio propio (geometría FAO-56 Ec. 31) | `EF_WS_TIME_GAP`, `EF_WS_TIME_IRREGULAR`, `EF_WS_TIME_SHIFT` | warning | Tolerancia de desfase `TODO` |
| QC-10 | Día incompleto para ETr24 | todas las de ETr | Diaria | Menos períodos que los del día | Necesario para sumar 24 h (§5.6) | `EF_WS_INCOMPLETE_DAY` | warning | Política de huecos `TODO` (WF-11) |
| QC-11 | Metadatos de altura ausentes o atípicos | `height_*` | Estación | Altura `NA`; T/HR ≠ 2 m | FAO-56 cap. 2–3 (medición a 2 m o convertida) | `EF_WS_HEIGHT_MISSING`, `EF_WS_HEIGHT_NONSTANDARD` | warning | No |
| QC-12 | Consistencia espacial entre estaciones | todas | Todas | Residuo frente a vecinos o a la superficie regional | `TODO` (se coordinará con la especificación GWR; los residuos de validación cruzada sirven de insumo) | `EF_WS_SPATIAL_OUTLIER` | warning | **Sí** `TODO` |
| QC-13 | Estación nublada a la hora de paso | Rs/Rso | Hora de paso | Rs/Rso bajo un umbral | Ya propuesto en `radiation-components.md` §4.8 | `EF_STATION_CLOUDY` | warning | **Sí** `TODO` |

Notas:

- **Flags no registrados.** Ningún código de esta tabla se agrega todavía a
  `ef_flag_registry()`. Candidatos inequívocos al fusionar: `EF_WS_IMPOSSIBLE`,
  `EF_WS_RH_GT100`, `EF_WS_TMIN_GT_TMAX`, `EF_WS_TDEW_GT_TAIR` (sin
  tolerancia), `EF_RS_EXCEEDS_EXTRATERRESTRIAL`, `EF_WS_TIME_GAP`,
  `EF_WS_HEIGHT_MISSING`, `EF_WS_INCOMPLETE_DAY`. Los demás esperan umbral.
- **Prefijo** `EF_WS_` (weather station) para distinguirlos de los flags de
  píxel. `EF_RS_EXCEEDS_EXTRATERRESTRIAL` y `EF_STATION_CLOUDY` conservan el
  nombre ya propuesto en `radiation-components.md` (decisión WF-07:
  unificar prefijos antes de registrar).
- **Corrección por aridez (Anexo 6, Ec. 6-3 a 6-6):** FAO-56 la propone
  para calcular ETo en sitios no-referencia, advierte que **no** debe
  aplicarse cuando se busca ET real en hidrología, que los datos corregidos
  no deben reintroducirse en la serie histórica y que su incertidumbre es
  desconocida. EarthFlux **no la aplica por defecto** (principio 6); su uso
  para ETr en METRIC es la decisión abierta WF-08.
- `water` v1.0 advierte cuando Rs/Rso a la hora de paso es < 0,8 o > 1,1 y
  no lo evalúa con Rso < 200 W m⁻²; son umbrales propios sin cita. No se
  adoptan; quedan como referencia para la discusión de QC-13.

### 3.3 Estado de implementación (M3, 2026-11-04)

Implementado en `R/prep-qc.R` (`ef_station_qc(x, qc_policy =
"exclude_critical")`, exportada) con tests en
`tests/testthat/test-station-qc.R`; registro en `ef_flags_stations()`
(etapa `WS`, unido a `ef_flag_registry()`).

- **Códigos registrados** (nombres de `flags.md` §4.2, ámbito `record`,
  sin bit): `EF_WS_OUT_OF_DOMAIN` (QC-01a; clase III, `critical`,
  contraparte `earthflux_domain_error`; HR, `rh_max`, `rh_min` < 0;
  viento < 0; T, Tdew, `tmax`, `tmin` ≤ −273,15 °C; P ≤ 0; eₐ < 0;
  Rs < 0 y precipitación < 0, agregados con `ef_station_ref_et()`),
  `EF_WS_TMIN_GT_TMAX` (QC-03; clase III, `critical`), `EF_WS_RH_GT100`
  (QC-02, info), `EF_WS_TDEW_GT_TAIR` (QC-04, sin tolerancia; variantes
  Tdew > T y eₐ > e°(T) con `vapour_pressure` y `ef_es()`; T se marca una
  vez por registro), `EF_WS_RS_GT_RA` (QC-05b, warning; ver abajo),
  `EF_WS_TIME_GAP` y `EF_WS_TIME_IRREGULAR` (QC-09: paso múltiplo entero
  ≥ 2 de `interval` / no múltiplo; comparación exacta),
  `EF_WS_HEIGHT_MISSING` y `EF_WS_HEIGHT_NONSTANDARD` (QC-11; T/HR ≠ 2 m;
  el viento a otra altura no se marca: se convierte con la Ec. 47).
- **Tabla `$qc`:** una fila por registro × variable × código, con columnas
  `row` (fila de `observations`), `station_id`, `timestamp`, `variable`
  (`"timestamp"` para QC-09), `flag_code`, `severity`, `test_id`, `value`,
  `threshold` (cota, 100 %, la otra variable, 2 m o `interval`) y
  `parameters` (`NA`). Las pruebas de coherencia (QC-03, QC-04) marcan las
  dos variables. Equivalencia R16 verificada en el validador y en los
  tests: filas distintas por código = `index` del registro `earthflux_flag`.
- **Política:** `qc_policy ∈ {"exclude_critical", "exclude_warning",
  "keep_all"}`, coincidencia exacta, defecto `"exclude_critical"`
  (`flags.md` §5.3). El resultado es un estado por valor (`$qc_status`:
  `ok`/`warning`/`excluded`, el máximo de severidad de los flags del
  registro que afectan a la variable o al `timestamp`); `observations` no
  cambia; conteos en `provenance$qc` y `provenance$flags`.
- **Clase de resultado:** `c("earthflux_station_qc",
  "earthflux_station_table")`.
- **QC-05b (`EF_WS_RS_GT_RA`)**, evaluado desde la orquestación de ET de
  referencia (§13.4): Rs media del registro > Ra media de la **misma
  ventana** (`interval` segundos ubicados por `timestamp_convention`). Ra
  de la ventana = integral de la forma de la Ec. 28 con los límites
  restringidos a la parte con sol (−ωs ≤ ω ≤ ωs, Ec. 25), con δ y dr del día
  del punto medio; es la integral exacta de la irradiancia extraterrestre
  positiva (para 24 h coincide con la Ec. 21). No se usa el criterio de
  punto medio de `ef_ra_period()`, que en las horas de salida y puesta del
  sol subestima la ventana y marcaría registros válidos. Ventanas con
  Ra = 0 (noche completa) no se evalúan: corresponden a QC-05d (clase II).
  Solo para medias de período (`"end"`/`"start"`) con `interval` ≤ 1 d; si
  no, el código figura en `not_evaluated`.
- **No evaluados** (listados en `provenance$qc$not_evaluated`): todos los
  de clase II de §3.2 (ningún umbral tiene valor elegido con referencia;
  no se exponen argumentos de umbral porque su código no puede
  registrarse) y `EF_WS_INCOMPLETE_DAY` (QC-10): depende de la definición
  del día (WF-11), por lo que lo levanta `ef_station_ref_et()` sobre las
  sumas diarias (§13.4), no el QC.
- **Interfaz con `spatial`** (`R/prep-weather.R`, internas):
  `station_values()` (copia con `NA` en lo excluido) y
  `station_regionalization_input()` (tabla de §7.2 para `air_temperature`,
  `vapour_pressure` y `solar_radiation` observadas; `target_time` en el
  punto medio del período).

---

## 4. Variables derivadas (verificadas contra FAO-56)

Convenciones comunes a todas las funciones de esta sección:

- Aritméticas y vectorizadas (`ARCHITECTURE.md` §3); reciclado y `dim` según
  `radiation-components.md` §4.5; `NA` propaga (§4.6 de ese documento);
  errores clasificados (§4.7); sin truncar ni recortar.
- Temperatura del aire en **°C** (las ecuaciones de FAO-56 están
  formuladas en °C; decisión WF-02). Ángulos en radianes (RC-01).
- Cada constante vive en un único lugar del código, con su referencia.
- Citas: "FAO-56 Ec. n" = Allen et al. (1998), cap. 3 (`x0490e07.htm`)
  salvo indicación; página `TODO` (§1.2).

### 4.1 Presión atmosférica — `ef_air_pressure()` (referencia cruzada)

Definida en `radiation-components.md` §6.2; **no se duplica aquí**. Este
documento aporta su verificación y resuelve las diferencias:

```text
P = 101.3 · ((293 − 0.0065·z) / 293)^5.26          [kPa], z en m    (FAO-56 Ec. 7)
```

| Aspecto | En `radiation-components.md` §6.2 | Resultado de esta verificación |
|---|---|---|
| Forma y constantes | `CANDIDATA`, "atribuida a FAO-56 / ASCE-EWRI" | **Idéntica a FAO-56 Ec. 7. Estado propuesto: `VERIFICADA` (FAO-56 Ec. 7)**. También ASCE-EWRI (2005) Ec. 3 y 34 (p. 10 y 28), `VERIFICADA` (2026-11-04, §13.5) |
| Supuestos (`TODO` allí) | "Atmósfera estándar 293 K, gradiente constante" | FAO-56 cap. 3: simplificación de la ley de gases ideales suponiendo 20 °C en atmósfera estándar. Anexo 3 Ec. 3-2 da la forma general P = P₀·[(T_K0 − α₁(z − z₀))/T_K0]^(g/(α₁R)) con P₀ = 101,3 kPa, g = 9,807 m s⁻², R = 287 J kg⁻¹ K⁻¹, α₁ = 0,0065 K m⁻¹; con z₀ = 0 y T_K0 = 293 K se obtiene Ec. 3-4 = Ec. 7. Comprobación propia: 9,807/(0,0065·287) = 5,2570 ≈ 5,26 |
| Uso de un valor medio | – | FAO-56 cap. 3: el efecto de P en la ET es pequeño y "el valor medio para un lugar es suficiente" |
| Caso numérico | z = 1000 m → 90,0246 kPa | Recalculado: 90,0246 kPa (coincide). Además FAO-56 Ejemplo 2: z = 1800 m → 81,8 kPa (propio: 81,7558) |
| Ubicación (RC-17) | Archivo compartido recomendado | Coincide: la usan τ_sw, γ (Ec. 8), ρ_air y ETr. Ver WF-01 |

Diferencias de **uso** (no de ecuación) que deben quedar explícitas:

1. Para la **ET de referencia** se usa P(z) de la Ec. 7 con la elevación
   de la estación (o del píxel, según §6), no P medida: la ecuación
   estandarizada la define así y el efecto es pequeño. Para τ_sw del píxel,
   RC-08 sigue abierta (P medida/GWR vs P(z)). Si el camino de Rn usa P
   medida y el de ETr usa P(z), la cadena mezcla fuentes de P: se acepta y
   se registra en la procedencia (decisión WF-05).
2. La elevación del píxel (MDE) y la de la estación pueden diferir mucho en
   terreno complejo: la P usada en ETr por píxel (opción B de §6) debe ser
   la del píxel.

### 4.2 Constante psicrométrica — `ef_psychrometric(pressure)`

```text
γ = c_p·P / (ε·λ) = 0.665 × 10⁻³ · P          [kPa °C⁻¹], P en kPa      (FAO-56 Ec. 8)
c_p = 1.013 × 10⁻³ MJ kg⁻¹ °C⁻¹;  ε = 0.622;  λ = 2.45 MJ kg⁻¹
```

Estado: `VERIFICADA` (FAO-56 Ec. 8). Notas: (i) 1,013·10⁻³/(0,622·2,45) =
6,6475·10⁻⁴; FAO-56 publica el coeficiente redondeado 0,665·10⁻³ y lo usa
en sus ejemplos: se adopta el literal publicado. (ii) FAO-56 Anexo 3
Ec. 3-10 da la forma general γ = 0,00163·P/λ con λ variable (Anexo 3
Ec. 3-1: λ = 2,501 − 2,361·10⁻³·T, MJ kg⁻¹). La ecuación estandarizada usa
λ fijo; la λ dependiente de Ts para ET_inst del píxel pertenece a
`metric-et.R` (ver §10). Dominio: P > 0 (error). Caso: FAO-56 Ejemplo 2,
P = 81,8 kPa → γ = 0,054 kPa °C⁻¹ (propio: 0,05440 con P = 81,8).

### 4.3 Presión de vapor de saturación, pendiente y déficit

```text
e°(T) = 0.6108 · exp[17.27·T / (T + 237.3)]                 [kPa]   (Ec. 11)
es    = [e°(Tmax) + e°(Tmin)] / 2      (períodos ≥ 1 d)     [kPa]   (Ec. 12)
es    = e°(T_hr)                       (paso horario)       [kPa]   (Ec. 53, términos)
Δ     = 4098 · e°(T) / (T + 237.3)²                       [kPa °C⁻¹] (Ec. 13)
        con T = Tmedia = (Tmax + Tmin)/2 (Ec. 9) en 24 h; T = T_hr en paso horario
VPD   = es − eₐ                                             [kPa]   (Ejemplo 6; Ec. 6, 53)
```

Funciones propuestas: `ef_es(air_temperature)`,
`ef_es_slope(air_temperature)`. Estado: `VERIFICADA` (Ec. 11, 12,
13). El déficit es una resta y no requiere función exportada.

Inconsistencias internas de FAO-56 registradas (se adopta el capítulo 3):

- Anexo 3 Ec. 3-8 usa 0,611 en lugar de 0,6108.
- Anexo 3 Ec. 3-9 da Δ = 4098·e°(T)/(T + 237,3)² = 2504·exp(17,27T/(T +
  237,2))/(T + 237,3)²: el 237,2 del exponente y el 2504 difieren del
  cap. 3 (4098 × 0,6108 = 2503,06).

ASCE-EWRI (2005) (`VERIFICADA`, §13.5): e°(T) Ec. 7 y 37 (p. 11, 29), es
diaria Ec. 6 (p. 11, media de e°(Tmax) y e°(Tmin)), es horaria = e°(T_hr)
(Ec. 37), Tmedia Ec. 2 (p. 9): idénticas a FAO-56. Δ se escribe con 2503
(Ec. 5 y 36, p. 10 y 28), el producto 4098 × 0,6108 = 2503,06 redondeado:
factor constante de 2,3·10⁻⁵ (relativo) respecto de la Ec. 13 de FAO-56,
muy por debajo de la precisión de cualquier valor publicado. Se usa la
forma de FAO-56 para ambas normas (sin argumento `standard`).

Advertencia (FAO-56 cap. 3 y Recuadro 7): para períodos de 24 h o más, es
debe calcularse con Tmax y Tmin (Ec. 12), no con Tmedia; usar Tmedia
subestima es y la ETo.

Dominio: T > −237,3 °C para que la ecuación esté definida; físicamente T ≤
−273,15 °C es imposible → error. Valores de T compatibles con K pasados por
error (p. ej., 293) → flag `EF_WS_IMPLAUSIBLE` (umbral `TODO`, QC-01b).

### 4.4 Presión de vapor actual eₐ

| Función propuesta | Ecuación | Uso | Estado |
|---|---|---|---|
| `ef_ea_dewpoint(dewpoint_temperature)` | eₐ = e°(Tdew) (Ec. 14) | Cualquier paso | `VERIFICADA` |
| `ef_ea_rh(air_temperature, relative_humidity)` | eₐ = e°(T_hr)·HR_hr/100 (Ec. 54; Anexo 5 Ec. 5-3: T y HR del mismo período, preferentemente ≤ 1 h) | Horario / sub-horario | `VERIFICADA` |
| `ef_ea_daily(tmin, tmax, rh_max, rh_min, method)` | `"rhmax_rhmin"`: eₐ = [e°(Tmin)·HRmax/100 + e°(Tmax)·HRmin/100]/2 (Ec. 17; ASCE Ec. 11); `"rhmax"`: eₐ = e°(Tmin)·HRmax/100 (Ec. 18, cuando HRmin es dudosa; ASCE Ec. 12); `"rhmin"`: eₐ = e°(Tmax)·HRmin/100 (ASCE Ec. 13, p. 16); `"rhmean"`: eₐ = (HRmedia/100)·[e°(Tmax) + e°(Tmin)]/2 (Ec. 19, "menos deseable"; ASCE p. 17: "no recomendada en el procedimiento estandarizado"); `"rhmean_tmean"`: eₐ = (HRmedia/100)·e°(Tmedia) (ASCE Ec. 14 con Tmedia de la Ec. 2), HRmedia = (HRmax + HRmin)/2 | Diario o mayor | `VERIFICADA` (FAO-56; `"rhmin"` y `"rhmean_tmean"`: ASCE-EWRI 2005) |
| `ef_ea_tmin(tmin, k0 = 0)` | eₐ = e°(Tmin − K₀) (Ec. 48; Anexo 6 Ec. 6-6: K₀ = 0 °C húmedo/subhúmedo, 2 °C árido/semiárido; cap. 3: restar 2–3 °C en zonas áridas) | Solo datos faltantes | `VERIFICADA` (uso solo explícito) |
| `ef_dewpoint(vapour_pressure)` | Tdew = [116,91 + 237,3·ln eₐ] / [16,78 − ln eₐ] (Anexo 3 Ec. 3-11) | QC (QC-08b, QC-08c) | `VERIFICADA` (forma FAO-56) |
| Psicrómetro: eₐ = e°(T_wet) − γ_psy·(T_dry − T_wet), γ_psy = a_psy·P (Ec. 15–16) | – | Fuera del contrato (§2.3) | `VERIFICADA`, no se implementa por ahora |

ASCE-EWRI (2005) ordena los métodos por preferencia en la Tabla 3 (diaria,
p. 12: eₐ promediada o Tdew = 1; psicrómetro, Tdew a las 7–8 h, Ec. 11 =
2; Ec. 12 y 13 = 3; Tmin (Apéndice E) y Ec. 14 = 4) y la Tabla 4 (horaria,
p. 30: eₐ promediada, Tdew (Ec. 38) y HR con T (Ec. 41) = 1; psicrómetro = 2;
Tmin = 3). La estimación desde Tmin está en su Apéndice E (no leído):
`ef_ea_tmin()` sigue siendo la forma de FAO-56.

Notas: la Ec. 3-11 no es la inversa exacta de la Ec. 11 (comprobación
propia: eₐ = e°(15 °C) = 1,70535 kPa → Tdew = 14,9926 °C; diferencia
0,0074 °C). Para QC basta; si se necesitara la inversa exacta de la Ec. 11
se deriva algebraicamente (`TODO` decidir). SCIENTIFIC_SPEC §5 recomienda
regionalizar eₐ y no HR (HR depende de T): coherente con FAO-56 cap. 3
(eₐ casi constante en el día; HR oscila con T, Fig. 12).

Dominio: HR ∈ [0, 100] físico; HR > 100 → se calcula y se marca (QC-02),
no se recorta. eₐ ≤ 0 en la Ec. 3-11 → error (logaritmo).

### 4.5 Viento a 2 m — `ef_wind_2m(wind_speed, height)`

```text
u₂ = u_z · 4.87 / ln(67.8·z − 5.42)            [m s⁻¹], z en m      (FAO-56 Ec. 47)
```

Estado: `VERIFICADA` (también ASCE-EWRI 2005 Ec. 33, p. 26, y Ec. 67,
p. 44; el texto de la p. 44 la llama "Eq. 68", errata). Supuesto declarado
por FAO-56 y ASCE-EWRI: perfil logarítmico para mediciones **sobre una
superficie de pasto corto**; para viento medido sobre alfalfa u otra
superficie, ASCE-EWRI remite a la Ec. B.14 de su Apéndice B (no leído, no
implementado). Dominio:
67,8·z − 5,42 > 1 ⇔ z > 0,0947 m (para z menor el logaritmo es ≤ 0) →
`earthflux_domain_error`. Nota: en z = 2 m el factor es 1,00022, no
exactamente 1 (FAO-56 Anexo 2 Tabla 2.9 lo redondea a 1,000); en z = 10 m
es 0,74795 (Tabla 2.9: 0,748).

**No** es la extrapolación a la altura de mezcla de METRIC (perfil con la
rugosidad de la estación, `metric-aerodynamics.R`); esa función recibirá
`wind_speed` y `height_wind` crudos de la estación (§7), no u₂.

### 4.6 Radiación extraterrestre Ra

Geometría común (FAO-56; `VERIFICADA`):

```text
φ = (π/180)·[grados decimales]                                          (Ec. 22)
dr = 1 + 0.033·cos(2π·J/365)                                            (Ec. 23)
δ  = 0.409·sin(2π·J/365 − 1.39)                                [rad]    (Ec. 24)
ωs = arccos[−tan φ · tan δ]                                    [rad]    (Ec. 25)
     (alternativa con arctan, Ec. 26–27: X = 1 − tan²φ·tan²δ; X = 0.00001 si X ≤ 0)
Gsc = 0.0820 MJ m⁻² min⁻¹                                       (Ec. 21, definición)
J: día del año, 1 a 365 o 366
```

**Diaria** (Ec. 21), MJ m⁻² d⁻¹:

```text
Ra = (24·60/π)·Gsc·dr·[ωs·sin φ·sin δ + cos φ·cos δ·sin ωs]
N  = (24/π)·ωs        [h]                                               (Ec. 34)
```

FAO-56: validez limitada en invierno para latitudes > 55° (N o S).

**Por período (horario o menor)** (Ec. 28–33), MJ m⁻² por período:

```text
Ra = (12·60/π)·Gsc·dr·[(ω₂ − ω₁)·sin φ·sin δ + cos φ·cos δ·(sin ω₂ − sin ω₁)]   (Ec. 28)
ω₁ = ω − π·t₁/24 ;  ω₂ = ω + π·t₁/24                                     (Ec. 29, 30)
ω  = (π/12)·[(t + 0.06667·(Lz − Lm) + Sc) − 12]                          (Ec. 31)
Sc = 0.1645·sin(2b) − 0.1255·cos(b) − 0.025·sin(b)      [h]              (Ec. 32)
b  = 2π·(J − 81)/364                                                     (Ec. 33)
t: hora estándar en el punto medio del período [h]; t₁: largo del período [h]
Lz, Lm: longitud del centro de la zona horaria y del sitio, en grados AL OESTE
        de Greenwich (FAO-56: Lz = 0 para Greenwich, 330 para El Cairo)
Si ω < −ωs o ω > ωs (sol bajo el horizonte en el punto medio): Ra = 0 por definición.
```

Funciones propuestas: `ef_ra_daily(lat, doy)` y
`ef_ra_period(lat, lon, doy, utc_mid, period_hours)`.
Estado: `VERIFICADA` (Ec. 21–34).

Coherencia con `radiation-components.md` §6.1 (sin duplicar):

- δ, dr, b y Sc son las mismas formas que allí figuran como `CANDIDATA`:
  ahora verificadas (Ec. 24, 23, 33, 32). Deben implementarse **una vez**
  (auxiliares internas `ef_declination()`,
  `ef_inv_distance()`, `ef_equation_of_time()` de ese
  documento) y reutilizarse aquí.
- **Convención de longitud.** Con tiempos en UTC (Lz = 0) y longitud este
  positiva λ_E [grados], Lm = −λ_E (oeste positivo), y la Ec. 31 queda
  ω = (π/12)·[(t_UTC + λ_E/15 + Sc) − 12], que es la forma de
  `radiation-components.md` (t_s = utc_hour + λ·12/π + Sc, λ en rad). La
  equivalencia exige reducir t_s módulo 24 h (con la convención 0–360° de
  FAO-56, Lz − Lm puede valer cientos de grados). Test obligatorio.
- 0,06667 de FAO-56 vs 1/15 exacto: diferencia 3,3·10⁻⁶ h por grado
  (≈ 0,9 s para 72°). Recomendación: 1/15 exacto (forma de
  `radiation-components.md`) y tolerancia justificada al reproducir el
  Ejemplo 19 (decisión WF-10).
- **Bordes de amanecer/atardecer.** FAO-56 anula Ra solo según el punto
  medio. Un período que contiene la salida o la puesta del sol queda con Ra
  completa o nula. ASCE-EWRI (2005) Ec. 56 (p. 41, `VERIFICADA`): si
  ω₁ < −ωs → ω₁ = −ωs; si ω₂ < −ωs → ω₂ = −ωs; si ω₁ > ωs → ω₁ = ωs; si
  ω₂ > ωs → ω₂ = ωs; si ω₁ > ω₂ → ω₁ = ω₂; "puede aplicarse a todos los
  pasos". Implementado como `ef_ra_period(..., standard = "asce")`
  (decisión WF-10 resuelta como elección explícita por norma). La suma de
  las 24 Ra horarias con la Ec. 56 es igual a la Ra diaria (Ec. 21)
  (comprobado en los tests). **Inconsistencia del informe:** la misma
  página dice que un punto medio fuera de [−ωs, ωs] implica Ra = 0 "por
  definición"; para un período con el punto medio bajo el horizonte que
  contiene la salida o la puesta, ambas frases difieren y se sigue la
  Ec. 56. En día polar (ωs = π) no se aplican límites (no hay salida ni
  puesta; el recorte literal a [−π, π] cortaría los períodos en torno a la
  medianoche solar). ASCE-EWRI usa 0,06667 (Ec. 55); se mantiene 1/15
  exacto (WF-10).

### 4.7 Radiación de cielo despejado Rso

```text
Rso = (as + bs)·Ra          (cerca del nivel del mar o con as, bs calibrados)   (Ec. 36)
Rso = (0.75 + 2×10⁻⁵·z)·Ra  (sin calibración), z en m                           (Ec. 37 = Anexo 3 Ec. 3-13)
```

Función propuesta: `ef_rso(extraterrestrial, elevation)`.
Estado: `VERIFICADA` (también ASCE-EWRI 2005 Ec. 19, p. 22, diaria, y
Ec. 47, p. 37, horaria; el informe reserva las formas de su Apéndice D
para evaluar la calidad de Rs y cita la Ec. 47 como "Eq. 48" en la p. 38,
errata). FAO-56 Anexo 3 (con base en Allen, 1996): Ec. 3-13 es
"una buena aproximación de Rso para períodos **diarios y horarios**",
válida para z < 6000 m y baja turbidez; se obtuvo linealizando la ley de
Beer con la elevación y suponiendo un ángulo solar medio de ≈ 50°.

Variantes (FAO-56 Anexo 3, `VERIFICADA` como formas de FAO-56), para alta
turbidez o ángulo solar bastante menor que 50°:

```text
Rso = Ra·exp[−0.0018·P / (K_t·sin ϕ)]                                    (3-14)
sin ϕ = sin φ·sin δ + cos φ·cos δ·cos ω       (horario, ω en el punto medio) (3-15)
sin ϕ₂₄ = sin[0.85 + 0.3·φ·sin(2π·J/365 − 1.39) − 0.42·φ²]  (24 h; ϕ₂₄ ≥ 0)  (3-16)
Rso = (K_B + K_D)·Ra                                                      (3-17)
K_B = 0.98·exp[−0.00146·P / (K_t·sin ϕ) − 0.091·(W / sin ϕ)^0.25]          (3-18)
W   = 0.14·eₐ·P + 2.1                       [mm]                          (3-19)
K_D = 0.35 − 0.33·K_B  si K_B ≥ 0.15 ;  K_D = 0.18 + 0.82·K_B  si K_B < 0.15  (3-20)
K_t: coeficiente de turbidez, 0 < K_t ≤ 1 (1 = aire limpio)
```

FAO-56 Anexo 5: Ec. 3-13, 3-14 o 3-17 a 3-20 sirven para la envolvente de
QC-05a; 3-14 o 3-17 a 3-20 en zonas turbias o con ángulo solar bajo.

**Discrepancia con `radiation-components.md` §6.3.A** (ver §10): allí τ_b
lleva −0,075·(W/cos θ)^0,4 y τ_d = 0,35 − 0,36·τ_b (forma observada en
`water`, atribuida a ASCE-EWRI 2005); FAO-56 Anexo 3 da −0,091·(W/sin ϕ)^0,25
y K_D = 0,35 − 0,33·K_B. No se resuelve aquí: requiere leer ASCE-EWRI
(2005). Para Rso de la superficie de referencia en ETr, la forma por
defecto es la Ec. 37 (WF-12).

### 4.8 Radiación neta de la superficie de referencia

```text
Rns = (1 − α)·Rs,  α = 0.23 (pasto de referencia)                         (Ec. 38)
Rnl = σ·[(T_max,K⁴ + T_min,K⁴)/2]·(0.34 − 0.14·√eₐ)·(1.35·Rs/Rso − 0.35)   (Ec. 39, 24 h)
      σ = 4.903 × 10⁻⁹ MJ K⁻⁴ m⁻² d⁻¹;  T_K = T[°C] + 273.16;  Rs/Rso ≤ 1.0
Rn  = Rns − Rnl                                                           (Ec. 40)
```

Paso horario (FAO-56 cap. 4, §"Hourly time step"): Ra horaria (Ec. 28); en
la Ec. 39 el promedio (σT_max,K⁴ + σT_min,K⁴)/2 se reemplaza por σT_hr,K⁴ y
σ = (4,903/24)·10⁻⁹ = 2,043·10⁻¹⁰ MJ m⁻² h⁻¹ K⁻⁴. **Noche:** Rs/Rso puede
igualarse al valor de un período 2–3 h antes de la puesta del sol,
identificado por (ωs − 0,79) ≤ ω ≤ (ωs − 0,52); alternativa aproximada:
Rs/Rso = 0,4–0,6 en climas húmedos y subhúmedos, 0,7–0,8 en áridos y
semiáridos; Rs/Rso = 0,3 supone cobertura nubosa total.

Funciones propuestas (internas salvo decisión WF-13):
`ef_ref_net_radiation(solar_radiation, clear_sky_radiation,
vapour_pressure, air_temperature | tmax + tmin, timestep, cloudiness = NULL)`
→ `list(rn, rns, rnl, cloudiness)`. El argumento `cloudiness` permite
inyectar el término (1,35·Rs/Rso − 0,35) arrastrado desde la tarde (noche).
Estado: `VERIFICADA` (Ec. 38–40 y adaptación horaria).

Notas de coherencia:

- **"Rs/Rso ≤ 1,0"** forma parte de la definición de la Ec. 39 (FAO-56 lo
  exige explícitamente). Aplicar ese límite no es una corrección silenciosa
  del dato: se aplica solo dentro del término de nubosidad y se registra
  con un flag informativo (`EF_WS_RS_RSO_LIMITED`); Rs no se modifica.
  ASCE-EWRI (2005) limita a 0,3 ≤ Rs/Rso ≤ 1,0 (Ec. 18, p. 20; Ec. 45,
  p. 35; `VERIFICADA`), con `standard = "asce"`; el mismo flag marca ambos
  límites. **Inconsistencia del informe:** afirma que esos límites dan
  0,05 ≤ f_cd ≤ 1,0, pero 1,35·0,3 − 0,35 = 0,055. Se aplica el límite del
  cociente (f calculado ≥ 0,055) y un `cloudiness` entregado se acepta en
  [0,05; 1] (rango declarado en las Ec. 17 y 44).
- **ASCE-EWRI (2005), `standard = "asce"`** (`VERIFICADA`): α = 0,23 para
  ambas referencias y ambos pasos (Ec. 16 y 43, p. 18 y 33); Rnl con
  σ = 4,901·10⁻⁹ MJ K⁻⁴ m⁻² d⁻¹ (Ec. 17, p. 19) y 2,042·10⁻¹⁰
  MJ K⁻⁴ m⁻² h⁻¹ (Ec. 44, p. 34; FAO-56 da 4,903·10⁻⁹ y 4,903/24·10⁻⁹ =
  2,043·10⁻¹⁰); T_K = T + 273,16. `ef_ref_net_radiation()` recibe
  `standard` sin defecto. Nubosidad con sol bajo y de noche (Ec. 46,
  p. 35–36): todo período cuyo ángulo solar β en el punto medio (Ec. 62,
  p. 43) sea menor que 0,3 rad usa el f_cd del último período con
  β > 0,3 rad ("un solo valor por día" para el anochecer, la noche y el
  amanecer); implementado como `night_cloudiness = "low_sun"` en
  `ef_station_ref_et()`. Sin períodos con β > 0,3 rad (latitudes altas en
  invierno) el informe admite Rs/Rso entre 0,3 y 1,0 (p. 36):
  `night_cloudiness = "fixed"` con `night_ratio` ∈ [0,3; 1]. El informe da
  "~17°" (p. 35) y "~15°" (p. 36) para 0,3 rad (= 17,2°): errata menor.
- **σ y 273,16.** σ = 4,903·10⁻⁹ MJ m⁻² d⁻¹ K⁻⁴ equivale a 5,6748·10⁻⁸
  W m⁻² K⁻⁴ (0,08 % menor que el valor CODATA de `radiation-components.md`
  §5, RC-07). La conversión a K usa 273,16 (Ec. 39 y cap. 3), mientras el
  paquete adopta 273,15 (`soil-heat-flux.md` D9). Resolución propuesta
  (WF-14): dentro de las funciones de **referencia** se usan los literales
  de la norma (σ de FAO-56, 273,16 en Rnl, 273 en el término aerodinámico
  de Ec. 6/53), porque la ecuación estandarizada es una definición
  convencional; fuera de ellas rigen RC-07 y D9. Efecto de 273,16 vs 273,15
  en T⁴: ≈ 4·0,01/293 ≈ 1,4·10⁻⁴ relativo.
- Rnl de la Ec. 39 es un balance **empírico** de onda larga de la
  superficie de referencia; no es intercambiable con RL↓ y RL↑ del píxel
  (`radiation-components.md` §6.5–6.6).

### 4.9 Flujo de calor del suelo de la superficie de referencia

```text
24 h (y 10 días):  G_day ≈ 0                                               (Ec. 42)
horario, día:      G_hr = 0.1·Rn                                           (Ec. 45)
horario, noche:    G_hr = 0.5·Rn                                           (Ec. 46)
mensual:           G = 0.07·(T_mes,i+1 − T_mes,i−1)  o  0.14·(T_mes,i − T_mes,i−1)   (Ec. 43, 44; fuera de alcance)
```

Estado: `VERIFICADA` para **pasto** (FAO-56) y para **pasto y alfalfa**
de ASCE-EWRI (2005): G diario = 0 (Ec. 30, p. 25); G horario 0,1·Rn día /
0,5·Rn noche (pasto, Ec. 65a–b) y 0,04·Rn / 0,2·Rn (alfalfa, Ec. 66a–b),
p. 44. Criterio día/noche: FAO-56 dice "daylight periods" sin definir el
umbral; ASCE-EWRI define el día como Rn horaria **positiva** (texto previo
a la Tabla 1 y Tabla 2, p. 5: día Rn > 0, noche Rn ≤ 0) → opción
`daytime_rule = "rn_positive"` (`VERIFICADA` para ASCE). **Inconsistencia
del informe:** la p. 44 (tras las Ec. 65–66) y el glosario (p. 58) definen
la noche como Rn < 0 y el día como Rn ≥ 0; en Rn = 0 exacto G = 0 en ambas
lecturas y solo cambia Cd; se sigue la Tabla 2. En el Ejemplo 19 de FAO-56
ambos criterios coinciden (noche con Rn < 0; día con Ra > 0 y Rn > 0).
Decisión WF-15 (abierta solo para FAO-56). Función propuesta (interna):
`ef_ref_soil_heat_flux(rn, reference, timestep, daytime)`.
Referencia cruzada: `soil-heat-flux.md` §3.3 (no es un método de G del
píxel). FAO-56 Anexo 5 Ec. 5-2 (Choudhury, 1989: G = 0,4·exp(−0,5·LAI)·Rn,
diurno) da 0,1·Rn con LAI = 2,8; solo como contexto.

---

## 5. ET de referencia: ETr (alfalfa, ASCE-EWRI) y ETo (pasto, FAO-56)

### 5.1 Por qué METRIC necesita ETr

METRIC calibra el ancla fría con ETr instantánea (LE ≈ k·ETr, k a
verificar; SPEC §2.1) y extrapola a 24 h con ETa = ETrF·ETr24 (SPEC §3).
La referencia usada por METRIC es la alfalfa (`ETr`) de la ecuación
estandarizada ASCE-EWRI (SPEC §3, fila ETr, `TODO: verificar` en Allen et
al., 2007). La definición del cultivo de referencia debe ser **explícita**
en toda salida (`reference = "alfalfa"`), porque ETrF y Kc (base pasto)
no son intercambiables.

### 5.2 Forma combinada común

FAO-56 (VERIFICADA) — pasto, 24 h (Ec. 6) y horaria (Ec. 53):

```text
ETo = [0.408·Δ·(Rn − G) + γ·(900/(T + 273))·u₂·(es − eₐ)] / [Δ + γ·(1 + 0.34·u₂)]   [mm d⁻¹]  (Ec. 6)
ETo = [0.408·Δ·(Rn − G) + γ·(37/(T_hr + 273))·u₂·(e°(T_hr) − eₐ)] / [Δ + γ·(1 + 0.34·u₂)]  [mm h⁻¹]  (Ec. 53)
```

Superficie: pasto hipotético de 0,12 m, r_s = 70 s m⁻¹, α = 0,23 (FAO-56
cap. 2); mediciones a 2 m (o convertidas). FAO-56 (cap. 4) advierte que
r_s constante puede subestimar la ETo horaria diurna y sobreestimarla al
atardecer, y que las sumas horarias de 24 h son en general equivalentes al
cálculo con paso de 24 h.

Forma general con constantes Cn y Cd (ASCE-EWRI 2005 Ec. 1, p. 4,
`VERIFICADA`; coincide con Ec. 6/53 cuando Cn = 900/37 y Cd = 0,34).
Unidades (p. 4): ETsz en mm d⁻¹ o mm h⁻¹; Rn y G en MJ m⁻² d⁻¹ o h⁻¹; T a
1,5–2,5 m en °C; u₂ en m s⁻¹; Cn en K mm s³ Mg⁻¹ d⁻¹ o h⁻¹ (absorbe el
K_time de 86 400 s d⁻¹ o 3600 s h⁻¹ de la forma completa, glosario
p. 56); Cd en s m⁻¹; 0,408 en m² mm MJ⁻¹ (1/λ con λ = 2,45 MJ kg⁻¹ y
ρ_w = 1 Mg m⁻³, p. 9 y 27). Tabla 2 (p. 5): alturas 0,12 m (corta) y
0,50 m (alta), z_w = 2 m, d = 0,08 m en ambas (viento medido sobre pasto),
r_s diaria 70 / 45 s m⁻¹, horaria diurna 50 / 30 s m⁻¹, nocturna
200 s m⁻¹:

```text
ET_ref = [0.408·Δ·(Rn − G) + γ·(Cn/(T + 273))·u₂·(es − eₐ)] / [Δ + γ·(1 + Cd·u₂)]
```

### 5.3 Tabla de constantes

| Referencia | Paso | Cn | Cd | G | Estado | Fuente / corroboración |
|---|---|---|---|---|---|---|
| Pasto, FAO-56 | 24 h | 900 | 0,34 | ≈ 0 (Ec. 42) | `VERIFICADA` | FAO-56 Ec. 6 |
| Pasto, FAO-56 | 1 h | 37 | 0,34 (día y noche) | 0,1·Rn día / 0,5·Rn noche | `VERIFICADA` | FAO-56 Ec. 53, 45, 46 |
| Pasto (ETos), ASCE-EWRI | 24 h | 900 | 0,34 | 0 (Ec. 30) | `VERIFICADA` | ASCE-EWRI (2005) Ec. 1 (p. 4), Tabla 1 (p. 5); G: Ec. 30 (p. 25). Coincide con FAO-56 Ec. 6 |
| Alfalfa (ETrs), ASCE-EWRI | 24 h | 1600 | 0,38 | 0 (Ec. 30) | `VERIFICADA` | ASCE-EWRI (2005) Ec. 1 (p. 4), Tabla 1 (p. 5); G: Ec. 30 (p. 25) |
| Pasto (ETos), ASCE-EWRI | 1 h | 37 | 0,24 día / 0,96 noche | 0,1·Rn / 0,5·Rn | `VERIFICADA` | ASCE-EWRI (2005) Tabla 1 (p. 5); G: Ec. 65a–b (p. 44) |
| Alfalfa (ETrs), ASCE-EWRI | 1 h | 66 | 0,25 día / 1,7 noche | 0,04·Rn / 0,2·Rn | `VERIFICADA` | ASCE-EWRI (2005) Tabla 1 (p. 5); G: Ec. 66a–b (p. 44) |

Las seis filas ASCE se implementaron primero como `CANDIDATA` desde
fuentes secundarias (`SPEI` 1.8.1; `water` 1.0, §13.2) y se verificaron el
2026-11-04 contra el informe final de enero de 2005: los valores
coinciden, no cambió ninguno. Día/noche: Rn > 0 (texto previo a la Tabla 1
y Tabla 2, p. 5; ver la inconsistencia de §4.9).

Elementos que `water` atribuía a ASCE-EWRI, ahora contrastados (detalle en
§13.5): γ = 0,000665·P (Ec. 4 y 35) ✔; Δ con 2503 (Ec. 5 y 36) ✔,
equivalente a FAO-56 (§4.3); Rs/Rso acotada a [0,3; 1] (Ec. 18 y 45) ✔;
nubosidad de sol bajo y nocturna desde el último período con β > 0,3 rad
(Ec. 46, con β de la Ec. 62) ✔; Rso = (0,75 + 2·10⁻⁵z)·Ra (Ec. 19 y 47) ✔;
Ra horaria con límites de ω a la salida/puesta (Ec. 48 y 56; Sc y b son
las Ec. 57–58) ✔; σ horaria 2,042·10⁻¹⁰ (Ec. 44) ✔; α = 0,23 para ambas
referencias (Ec. 16 y 43) ✔; día de 24 períodos horarios que terminan a la
01:00 … 24:00: **no verificado** (el texto principal solo habla de sumar
"sobre el período de 24 horas", p. 45; el Apéndice C no se leyó).

Diferencia relevante: para pasto horario, FAO-56 usa Cd = 0,34
constante y ASCE-EWRI Cd = 0,24/0,96. Con los datos del
Ejemplo 19 (14:00–15:00) da 0,627 vs 0,656 mm h⁻¹ (§8.2, aritmética). Por
eso `standard` es un argumento explícito.

### 5.4 Interfaz propuesta

Una función pública, sin alias por referencia ni por paso (API pequeña;
decisión WF-13):

```text
ef_ref_et(net_radiation, soil_heat_flux, air_temperature, wind_speed_2m,
                vapour_pressure_deficit, slope, psychrometric,
                reference = c("alfalfa", "grass"),
                timestep  = c("hourly", "daily"),
                standard  = c("asce", "fao56"),
                daytime   = NULL)
  → numeric [mm h⁻¹ o mm d⁻¹], atributos: reference, timestep, standard, constants
```

- Bajo nivel y puramente aritmética: recibe Rn, G, Δ, γ, VPD de la
  superficie de referencia ya calculados (§4); `daytime` (lógico) es
  obligatorio con `timestep = "hourly"` y `standard = "asce"`.
- Constantes desde una tabla interna única (`.ef_reference_constants`) con
  la fuente de cada fila (§5.3). Combinaciones `CANDIDATA` no pueden
  implementarse hasta su verificación (DoD): mientras tanto solo
  `standard = "fao56"` + `reference = "grass"` es implementable
  (superado: §13.2 punto 1 y, desde 2026-11-04, todas las filas
  `VERIFICADA`, §13.5).
- `standard = "fao56"` + `reference = "alfalfa"` → error clasificado (FAO-56
  no define alfalfa).
- Orquestación para series de estación (en `prep-weather.R`):
  `ef_station_ref_et(station_table, reference, timestep, standard)` →
  serie horaria/diaria con procedencia y flags; incluye el arrastre de
  nubosidad nocturna (§4.8) y la definición del día (§5.6).
- ETr < 0 (posible de noche, Rn − G < 0 con poco déficit): se conserva, sin
  truncar (principio 6). Flag informativo propuesto `EF_ETREF_NEGATIVE`.
- Envoltorio `ef_etr_hourly()` / `ef_etr_daily()`: **no** se proponen como
  exportadas (duplicarían la API); pueden existir como internas.

### 5.5 ETr instantánea a la hora de paso (ETr_inst)

Problema: ETrF = ET_inst/ETr_inst exige ETr en el **mismo instante** que la
ET del píxel. Las estaciones entregan medias horarias (o de 10–15 min), y
la hora de paso MODIS varía por píxel y entre fechas (SPEC §2.4).
ETr_inst se expresa como tasa (mm h⁻¹).

| Opción | Descripción | A favor | En contra |
|---|---|---|---|
| O1 | ETr del período horario que contiene la hora de paso | Simple; sin interpolar | Desfase de hasta 30 min respecto del punto medio; salto discontinuo entre píxeles con horas de paso en períodos distintos |
| O2 | ETr para una ventana de 1 h **centrada** en la hora de paso, con insumos interpolados linealmente en el tiempo y Ra de esa ventana (Ec. 28 con t = hora de paso) | Geometría exacta en el instante; forma usada por `water` (`hourlyET(..., ET.instantaneous = TRUE)` desplaza la hora +0,5 h; `read.WSdata()` interpola con `approxfun()` lineal) | Interpolar Rs linealmente es frágil con nubes; nubosidad nocturna no aplica (paso diurno) |
| O3 | Calcular ETr horaria en la estación y **luego** interpolar linealmente la tasa ETr entre puntos medios de períodos (calcular-luego-interpolar en el tiempo) | Una serie única de ETr, coherente con ETr24 (misma serie); barato por píxel (hora de paso por píxel) | Interpola una función no lineal; ignora la geometría exacta del instante |
| O4 | Como O2 pero interpolando Rs/Rso (índice de nubosidad) en lugar de Rs, y Rso del instante | Separa la parte geométrica (exacta) de la nubosa (interpolada) | Más pasos; Rso es modelada |
| O5 | Usar datos sub-horarios (≤ 15 min) cuando existan, con O1–O4 a esa escala | Menor error de interpolación | No todas las redes lo ofrecen (§9) |

Caso aritmético (O3): períodos que terminan a las 15:00 y 16:00 UTC (puntos
medios 14:30 y 15:30) con ETr = 0,70 y 0,80 mm h⁻¹; paso a las 15:12 UTC →
fracción (15,2 − 14,5)/1 = 0,7 → ETr_inst = 0,70 + 0,7·0,10 = 0,77 mm h⁻¹.

Recomendación provisional (WF-09): O3 por defecto (coherencia con ETr24 y
costo por píxel), O2/O4 como análisis de sensibilidad; el método queda en
la procedencia. Requisitos comunes: hora de paso en UTC por píxel; si cae
fuera del rango de registros → `NA` + flag `EF_WS_OVERPASS_OUTSIDE_RECORDS`
(sin extrapolar); interpolación solo entre registros sin flags excluidos.

### 5.6 ETr diaria (ETr24)

| Opción | Descripción | Estado |
|---|---|---|
| D1 | Suma de 24 ETr horarias | FAO-56 cap. 4: las sumas horarias son en general equivalentes al cálculo de 24 h (`VERIFICADA` como afirmación para pasto). ASCE-EWRI (2005, p. 45): suma de ETos/ETrs horarias "sobre el período de 24 horas", conservando en general los valores negativos (`VERIFICADA` como procedimiento; EarthFlux conserva los negativos). Uso en METRIC: `TODO` (Allen et al., 2007) |
| D2 | Ecuación diaria (Cn = 1600, Cd = 0,38) con agregados diarios (Tmax, Tmin, eₐ, u₂, Rs) | Constantes `VERIFICADA` (ASCE-EWRI Tabla 1); agregación de datos horarios a diarios no implementada |

Definición del día (decisión WF-11): **día civil local** (24 períodos
horarios que terminan 01:00…24:00 en la hora estándar local, como describe
`water` para ASCE-EWRI; el texto principal del informe no lo define y el
Apéndice C no se leyó: `CANDIDATA`) vs **día UTC**. El informe usa la hora
estándar local (sin horario de verano) en el ángulo horario (Ec. 55,
p. 41), no en la definición del día. Para estaciones en
UTC−3/−4 el día UTC desplaza 3–4 h la ventana y cambia ETr24. EarthFlux
almacena UTC (§2.4), por lo que la definición debe ser un argumento
explícito (`day_definition = c("local_standard", "utc")`, con la zona
horaria estándar de la estación en `stations`). Días con huecos → `NA` +
`EF_WS_INCOMPLETE_DAY` (sin relleno implícito); política de tolerancia
`TODO`.

Coherencia ETr_inst–ETr24: con D1 y O3 ambas provienen de la **misma**
serie horaria, lo que garantiza que el cociente ETr24/ETr_inst sea el de
una curva diaria físicamente calculada. Con D2, ETr24 y ETr_inst provienen
de ecuaciones y agregaciones distintas. Recomendación provisional: D1.

---

## 6. Decisión 5.1: interpolar y luego calcular vs calcular y luego interpolar

Definiciones:

- **A — calcular y luego interpolar:** ETr_inst y ETr24 se calculan en cada
  estación (§5) y se regionalizan como variables respuesta.
- **B — interpolar y luego calcular:** se regionalizan los insumos (T, eₐ,
  u, Rs o Rs/Rso) para cada período necesario y ETr se calcula por píxel.
- **C — híbrida:** lo determinístico se calcula por píxel con exactitud
  (P(z) del MDE, Ec. 7; Ra y Rso por píxel, Ec. 28/37; geometría a la hora
  de paso del píxel) y solo se regionalizan las variables atmosféricas
  (T, eₐ, índice de nubosidad Rs/Rso; viento según §7).

| Criterio | A | B / C |
|---|---|---|
| No linealidad | ETr se calcula con datos observados coherentes entre sí en cada estación | ETr es no lineal (e°(T) exponencial; producto u₂·VPD): f(E[x]) ≠ E[f(x)]; el suavizado de cada insumo introduce un sesgo en ETr cuyo signo no está establecido |
| Covariables | Una relación ETr–covariables, menos interpretable físicamente | Covariables específicas por variable (p. ej., elevación para T; P exacta desde MDE en C) |
| Número de ajustes por fecha | 2 (ETr_inst, ETr24) | ≈ 4 variables × (1 período de paso + 24 períodos para ETr24) ≈ 100; más grados de libertad efectivos consumidos, más diagnósticos y más riesgo con redes poco densas (SPEC §6) |
| Validación cruzada | Directa sobre la magnitud usada | Por variable **y** sobre ETr recalculada en la estación omitida con insumos predichos (recomendado para comparar con A en los mismos pliegues) |
| Coherencia ETr_inst (ancla) vs ETr24 (píxel) | Dos superficies ajustadas por separado: el cociente ETr24/ETr_inst por píxel resulta de dos regresiones independientes y puede no corresponder a ninguna curva diaria físicamente posible | Ambas desde las mismas superficies de insumos: coherencia por construcción (sujeta al error de los insumos) |
| Restricciones físicas | La superficie GWR de ETr puede tomar valores negativos o fuera de rango sin que nada lo impida → flag | Cada insumo con su dominio (HR ≤ 100 no aplica si se regionaliza eₐ, pero eₐ ≤ e°(T) sí debe controlarse por píxel → flag) |
| Condición de referencia | Hereda la (no) condición de referencia de cada estación (FAO-56 Anexo 6) | Ídem, y además: usar LST como covariable de T introduce el **estado real** de la superficie en una magnitud de **referencia**, y acopla ETr con Ts, que METRIC ya usa en H (circularidad; riesgo a evaluar) |

Consecuencias para H1 (SPEC §1.1–1.2):

1. ETr entra por dos vías con efectos distintos: (i) **calibración**: ETr_inst
   en el ancla fría fija la condición de borde de dT para toda la escena
   (efecto casi uniforme, parcialmente absorbible); (ii) **extrapolación**:
   ETr24 multiplica ETrF en cada píxel (efecto espacial directo).
2. En la configuración espacial, ETr_inst del ancla debe evaluarse **en la
   ubicación y hora de paso del píxel ancla**, no en la estación.
3. Diseño sugerido para M6 (factorial, sin suponer resultado): fuente de
   ETr_inst del ancla ∈ {estación, espacial} × fuente de ETr24 ∈
   {estación, espacial}, con las demás piezas fijas. Separa los efectos (i)
   y (ii), como exige SPEC §1.2.
4. Con A, la incoherencia posible entre ETr_inst del ancla y ETr24 del
   mismo píxel puede introducir un sesgo que no proviene de la física sino
   del ajuste independiente de dos superficies; con B/C ese término
   desaparece, pero aparece el sesgo por no linealidad. Ambos deben
   cuantificarse con validación cruzada en estaciones antes de interpretar
   H1.

Recomendación provisional (no decisión): soportar A y C en el software
(misma interfaz de salida, §7.2), con C como candidata por defecto por la
coherencia ancla–ETr24 y por el cálculo exacto de lo determinístico; decidir
con evidencia de validación cruzada (VALIDATION_PLAN §2.1, punto 1). Una
variante de A que regionalice ETr24 y el cociente ETr24/ETr_inst en lugar
de ETr_inst se registra como **opción a evaluar**, sin respaldo
bibliográfico identificado.

---

## 7. Variables espaciales vs escalares de estación; interfaz con `spatial`

### 7.1 Tratamiento por variable

| Variable | Unidad | Tratamiento propuesto | Motivo |
|---|---|---|---|
| P | kPa | **Determinístico por píxel** (Ec. 7, MDE) | Ecuación verificada; FAO-56: valor medio del lugar suficiente |
| Ra, Rso (referencia) | MJ m⁻² por período | **Determinístico por píxel** (Ec. 28/21, 37) | Geometría y elevación conocidas |
| T del aire (hora de paso; serie horaria; Tmax/Tmin) | °C | Candidata a GWR (SPEC §5) | Covariables: elevación, distancia a la costa; LST con cautela (§6) |
| eₐ (o Tdew) | kPa (°C) | Candidata a GWR; **no** regionalizar HR | HR depende de T (FAO-56 cap. 3); SPEC §5 |
| Índice de nubosidad Rs/Rso (o Rs) | – (W m⁻²) | Candidata a GWR o escalar de escena | Rs = (Rs/Rso)·Rso del píxel separa lo geométrico de lo nuboso (C) |
| u (para ETr) | m s⁻¹ | Escalar de estación por defecto; GWR "con cautela" (SPEC §5) | Alta variabilidad local; dependencia de la exposición |
| u y rugosidad de la estación para la altura de mezcla de METRIC | m s⁻¹, m | **Escalar de estación** (decisión del módulo `metric`) | Fuera de alcance aquí; se entrega crudo |
| ETr_inst, ETr24 | mm h⁻¹, mm d⁻¹ | Según decisión 5.1 (§6) | – |
| Alturas de medición, tipo de superficie | m, – | Escalares de estación (metadatos) | No son campos espaciales |

### 7.2 Contrato de interfaz `forcing` → `spatial` → consumidores

Solo la interfaz; el método (GWR, IDW, regresión global, estación única)
se especifica en el documento de GWR.

**Entrada** (producida por `forcing`): tabla larga
`ef_regionalization_input`:

| Campo | Tipo / unidad | Comentario |
|---|---|---|
| `station_id` | character | – |
| `lon`, `lat` | grados decimales WGS84 | El módulo `spatial` proyecta si lo necesita (CRS en procedencia) |
| `elevation` | m | De `stations` |
| `target_time` | `POSIXct` UTC | Instante (hora de paso) o punto medio del período |
| `period_seconds` | entero | 0 para instantáneo |
| `variable` | factor: `air_temperature`, `vapour_pressure`, `wind_speed_2m`, `clearness` (Rs/Rso), `solar_radiation`, `etr_inst`, `etr_24` | Nombres del contrato de `ARCHITECTURE.md` §4 |
| `value` | double, en la unidad del contrato | °C, kPa, m s⁻¹, –, W m⁻², mm h⁻¹, mm d⁻¹ |
| `qc_status` | factor (`ok`, `warning`, `excluded`) | Resultado de la política de QC (§3.1) |
| `reference` | `alfalfa` / `grass` / `NA` | Obligatorio para `etr_*` |

**Covariables solicitadas** (rásteres en la grilla de trabajo, con nombre de
capa y unidad; `spatial` las extrae en las estaciones): `elevation` [m]
(MDE), `distance_to_coast` [km] (fuente `TODO`), `slope` y `aspect` [rad]
(MDE), `lst` [K] (solo si se acepta el riesgo de §6), `ndvi` [–]. La lista
definitiva por variable pertenece al documento de GWR.

**Salida** (de `spatial`, idéntica para C1 estación única, C2 alternativa y
C3 GWR, para que las configuraciones de `VALIDATION_PLAN.md` §2.1 sean
comparables):

| Elemento | Tipo / unidad | Comentario |
|---|---|---|
| Superficie de la variable | `SpatRaster` (una capa por `target_time`) en la unidad de entrada | Nombre de capa = `variable` + tiempo |
| Incertidumbre | `SpatRaster` (misma unidad) u omitida | Si el método la entrega |
| Flags por píxel | `SpatRaster` de códigos | Extrapolación fuera del soporte geográfico o del rango de covariables (SPEC §6) |
| Diagnósticos | lista | Residuos en estaciones, CV, R² local, ancho de banda, AICc, etc. (definidos en el documento de GWR) |
| Procedencia | lista | `method` (texto, `ARCHITECTURE.md` §4), estaciones usadas y excluidas, `target_time`, covariables, parámetros, versión, semilla |

Responsabilidades: `forcing` no conoce rásteres de salida ni métodos de
regionalización; `spatial` no conoce ETr ni METRIC (`ARCHITECTURE.md`
principio 3). En la opción C, el cálculo de ETr por píxel con las
superficies de insumos lo hacen las mismas funciones `ef_*()` de §4–§5 sobre
`SpatRaster` (`ARCHITECTURE.md` §6.2), orquestadas por `api`.

---

## 8. Casos de verificación (ejemplos de FAO-56) y tests planificados

### 8.1 Casos tomados de los ejemplos numerados de FAO-56

Valores "FAO-56" = publicados (redondeados). Valores "propio" = recálculo
de este documento con las ecuaciones verificadas, a precisión completa
(sirven como valores de regresión). Tolerancia para reproducir el valor
publicado: media unidad del último dígito publicado más la propagación del
redondeo de los insumos intermedios que el ejemplo usa (justificar en cada
test).

| Caso | Ejemplo FAO-56 | Entradas | Esperado FAO-56 | Propio | Ecuaciones |
|---|---|---|---|---|---|
| V1 | Ej. 2 | z = 1800 m | P = 81,8 kPa; γ = 0,054 kPa °C⁻¹ | P = 81,7558; γ = 0,05437 | 7, 8 |
| V2 | Ej. 3 | Tmax = 24,5; Tmin = 15 °C | e°(Tmax) = 3,075; e°(Tmin) = 1,705; es = 2,39 kPa; e°(19,75) = 2,30 | 3,0746; 1,7053; 2,3900; 2,3023 | 11, 12 |
| V3 | Ej. 5 | Tmin = 18 °C, HRmax = 82 %; Tmax = 25 °C, HRmin = 54 % | e°(Tmin) = 2,064; e°(Tmax) = 3,168; eₐ = 1,70 (Ec. 17); 1,78 (Ec. 19) | 2,0640; 3,1678; 1,7015; 1,7788 | 11, 17, 19 |
| V4 | Ej. 6 | V3 | es − eₐ = 0,91 kPa | 0,9143 | 12, 17 |
| V5 | Ej. 4 (opcional) | z = 1200 m; T_dry = 25,6; T_wet = 19,5 °C; a_psy = 0,000662 | eₐ = 1,91 kPa | 1,9119 | 7, 11, 15, 16 |
| V6 | Ej. 7 | 13°44'N; 22°54'S | +0,240; −0,400 rad | 0,23969; −0,39968 | 22 |
| V7 | Ej. 8 | 3 sep (J = 246), 20°S | dr = 0,985; δ = 0,120 rad; ωs = 1,527 rad; Ra = 32,2 MJ m⁻² d⁻¹ | 0,98483; 0,11966; 1,52702; 32,1940 | 21–25 |
| V8 | Ej. 9 | V7 | N = 11,7 h | 11,6656 | 34 |
| V9 | Ej. 10–11 (parcial) | 22°54'S, 15 may (J = 135) | Ra = 25,1; N = 10,9 | 25,1110; 10,8951 | 21, 34 |
| V10 | Ej. 11 | Rs = 14,5; Rso = 0,75·25,1; Tmax = 25,1; Tmin = 19,1 °C; eₐ = 2,1 kPa | Rnl = 3,5 MJ m⁻² d⁻¹ | 3,5270 | 39 |
| V11 | Ej. 12 | V10, α = 0,23 | Rn = 7,6 MJ m⁻² d⁻¹ | 7,6380 | 38–40 |
| V12 | Ej. 14 | u = 3,2 m s⁻¹ a 10 m | factor 0,75; u₂ = 2,4 m s⁻¹ | 0,74795; 2,3934 | 47 |
| V13 | Anexo 2, Tabla 2.9 | z = 2; 10 m | 1,000; 0,748 | 1,00022; 0,74795 | 47 |
| V14 | **Ej. 18 (ETo diaria)** | Uccle, 6 jul (J = 187), 50°48'N, 100 m; Tmax = 21,5; Tmin = 12,3 °C; HRmax = 84; HRmin = 63 %; u₁₀ = 10 km h⁻¹; n = 9,25 h | P = 100,1; Δ = 0,122; γ = 0,0666; u₂ = 2,078; es = 1,997; eₐ = 1,409; Ra = 41,09; N = 16,1; Rs = 22,07; Rso = 30,90; Rns = 17,00; Rnl = 3,71; Rn = 13,28; **ETo = 3,9 mm d⁻¹** (3,88) | P = 100,1235; Δ = 0,12211; γ = 0,06658; u₂ = 2,0776; es = 1,9975; eₐ = 1,4086; Ra = 41,088; N = 16,105; Rs = 22,072; Rso = 30,898; Rns = 16,995; Rnl = 3,712; Rn = 13,283; **ETo = 3,8803** | 6, 7, 8, 11–13, 17, 21–24, 34, 35, 37–40, 42, 47 |
| V15 | **Ej. 19 (ETo horaria), 14:00–15:00** | N'Diaye, 1 oct (J = 274), 16°13'N, 16°15'W, 8 m; Lz = 15, Lm = 16,25; T_hr = 38 °C; HR = 52 %; u₂ = 3,3 m s⁻¹; Rs = 2,450 MJ m⁻² h⁻¹ | Δ = 0,358; γ = 0,0673; e° = 6,625; eₐ = 3,445; dr = 1,0001; δ = −0,0753; b = 3,3315; Sc = 0,1889; ω = 0,682; ω₁ = 0,5512; ω₂ = 0,8130; Ra = 3,543; Rso = 2,658; Rns = 1,887; Rnl = 0,137; Rn = 1,749; G = 0,175; **ETo = 0,63 mm h⁻¹** | Δ = 0,35820; γ = 0,06730; e° = 6,6248; eₐ = 3,4449; dr = 1,00014; δ = −0,07527; Sc = 0,18894; ω = 0,6821; Ra = 3,5434; Rso = 2,6581; Rnl = 0,1373; Rn = 1,7492; G = 0,1749; **ETo = 0,6269** | 8, 11, 13, 22–24, 28–33, 37–40, 45, 53, 54 |
| V16 | **Ej. 19, 02:00–03:00** | T_hr = 28 °C; HR = 90 %; u₂ = 1,9; Rs = 0; Rs/Rso = 0,8 (supuesto por el ejemplo) | Δ = 0,220; e° = 3,780; eₐ = 3,402; ω = −2,46 (Ra = 0); Rnl = 0,100; Rn = −0,100; G = −0,050; **ETo = 0,00 mm h⁻¹** | Δ = 0,22008; e° = 3,7799; eₐ = 3,4019; ω = −2,4594; Rnl = 0,1003; Rn = −0,1003; G = −0,0502; **ETo = 0,0043** | ídem + 46 |
| V17 | Cap. 3 / Anexo 3 | Tdew = 15 °C | eₐ = e°(15) (Ec. 14) | 1,70535; Ec. 3-11 inversa → 14,9926 °C | 14; 3-11 |

Notas sobre V14–V16: son los casos de integración principales (cadena
completa de referencia). En V16 FAO-56 publica 0,00 por redondeo; el valor
propio 0,0043 mm h⁻¹ debe usarse como regresión y el publicado con
tolerancia 0,005.

### 8.2 Casos de la ecuación estandarizada ASCE-EWRI (2005)

**Aritmética con las constantes de la Tabla 1** (constantes `VERIFICADA`;
los casos verifican la aritmética, no reproducen un ejemplo publicado). Con
los insumos de V15/V16 (mismo Rn de FAO-56) y las constantes de §5.3:

| Caso | Constantes | 14:00–15:00 | 02:00–03:00 |
|---|---|---|---|
| A1 | FAO-56 Ec. 53 (37; 0,34; G 0,1/0,5) | 0,6269 | 0,0043 |
| A2 | ASCE ETos horaria (37; 0,24/0,96; G 0,1/0,5) | 0,6560 | 0,0035 |
| A3 | ASCE ETrs horaria (66; 0,25/1,7; G 0,04/0,2) | 0,8218 | 0,0067 |
| A4 | ASCE ETrs diaria (1600; 0,38) con los insumos de V14 | 4,6065 mm d⁻¹ | – |

A través de `ef_station_ref_et()` con `standard = "asce"`, A3 usa además
el Rn de ASCE (σ = 2,042·10⁻¹⁰): la diferencia con 0,8218/0,0067 queda bajo
2·10⁻⁴ mm h⁻¹ (test).

**Reglas propias de ASCE-EWRI, casos calculados a mano** (tests en
`test-forcing-derived.R`, `test-reference-et.R`, `test-station-ref-et.R`):

| Caso | Regla | Entradas | Esperado |
|---|---|---|---|
| S1 | Ec. 13 (`"rhmin"`) | Tmax = 25 °C, HRmin = 54 % | eₐ = 3,1678·0,54 = 1,7106 kPa |
| S2 | Ec. 14 (`"rhmean_tmean"`) | Tmin = 18, Tmax = 25 °C, HRmax = 82, HRmin = 54 % | eₐ = 0,68·e°(21,5) = 1,7438 kPa (Ec. 19 de FAO-56: 1,7788) |
| S3 | Ec. 48 + 56 | Greeley (40,41° N, 104,78° O), J = 183, 24 períodos horarios UTC | Σ Ra horaria = Ra diaria (Ec. 21), tolerancia relativa 1e-10; período de salida del sol = integral de −ωs a ω₂ |
| S4 | Ec. 56 en día polar | 80° N, J = 172 | Igual al criterio de punto medio (sin límites) |
| S5 | σ de las Ec. 17 y 44 | Rs = 20, Rso = 25, eₐ = 1,5, Tmax = 25, Tmin = 15 (diario); Rs = 1, Rso = 2, T = 20 (horario) | Rnl con 4,901·10⁻⁹ y 2,042·10⁻¹⁰; cociente ASCE/FAO = 4,901/4,903 |
| S6 | Ec. 18/45 | Rs/Rso = 0,2; 0,4; 1,2; 0,8 | f = 0,055; 0,19; 1; 0,73; flag en el 1.º y el 3.º |
| S7 | Ec. 46 + 62 (`"low_sun"`) | Serie sintética horaria (35,4° S) | Todo período con β ≤ 0,3 rad lleva el f del último período con β > 0,3 rad en las 24 h previas; `NA` antes del primero |
| S8 | Día Rn > 0 (Tabla 2) | Rn = 0,5; 0; −0,1 (alfalfa) | G = 0,02; 0; −0,02; Cd = 0,25; 1,7; 1,7 |

**Ejemplos publicados (Apéndice C, Greeley, Colorado): no reproducidos.**
El informe remite a su Apéndice C para ejemplos diarios (Tabla C-3, 1–10 de
julio de 2000) y horarios (Tabla C-4, 1–2 de julio de 2000), con las
características de la estación y las constantes en las Tablas C-1 y C-2
(lista de tablas, p. vi). La copia leída (70 páginas, §1.2) no contiene
los apéndices, por lo que no hay valores publicados de ETos/ETrs con los
que contrastar EarthFlux: `TODO`, al obtener los apéndices (tolerancia
prevista: media unidad del último dígito impreso más la propagación del
redondeo de los insumos impresos, como en §8.1). No se inventan valores.

### 8.3 Erratas detectadas en los ejemplos de FAO-56 (versión HTML)

No afectan a las ecuaciones; se registran para que los tests no las
reproduzcan:

- Ej. 11: "22°54'S (= −22,70°)" (debería ser −22,90°); la tabla usa
  σT⁴ = 38,8 y 35,8 y el cálculo final 38,7 y 35,7.
- Ej. 12: "From Eq. 39: Rns" (es la Ec. 38) y "0,408 (7,7)" con Rn = 7,6.
- Ej. 16: "+13,73° … = −0,24 radian" (signo erróneo).
- Ej. 18: "es = (2,564 + 1,431) = 1,997" (falta /2); "n/N = 9,25/16,3"
  con N = 16,1; "2,078" con coma decimal.
- Ej. 8: "dr = 0,985 rad" (dr es adimensional).

### 8.4 Tests planificados

`tests/testthat/test-weather.R` (contrato, QC, derivadas) y
`tests/testthat/test-reference-et.R` (propuesto; o `test-et.R`, WF-01):

- **Valores:** V1–V17 con tolerancias justificadas; valores propios como
  regresión con tolerancia relativa del orden de 1e-6 (constantes publicadas
  exactas, sin iteraciones).
- **Identidades:** Ec. 3-4 ≈ Ec. 3-2 con z₀ = 0, T_K0 = 293 K (exponente
  9,807/(0,0065·287) = 5,2570 frente al literal 5,26; tolerancia
  justificada por ese redondeo). Solo se testean equivalencias publicadas.
- **Equivalencia de longitud:** Ec. 31 con Lz = 15, Lm = 16,25 y hora local
  = Ec. 31 con Lz = 0 y hora UTC desplazada 1 h; y forma de
  `radiation-components.md` (λ este positiva) con reducción módulo 24 h.
- **Ra diaria vs suma de Ra por períodos** de 1 h en un día: deben
  aproximarse (`TODO` justificar tolerancia por el tratamiento de bordes
  de amanecer/atardecer, WF-10).
- **Rso:** Ec. 37 en z = 0 → 0,75·Ra; Ec. 3-14 con K_t = 1 y P, ϕ dados
  (valor calculado a mano a incluir al implementar).
- **Rs/Rso ≤ 1** aplicado solo en el término de nubosidad y flag
  `EF_WS_RS_RSO_LIMITED`; Rs sin modificar.
- **Bordes y dominio:** z = 0,09 m en Ec. 47 → error; P ≤ 0 → error;
  HR < 0 → error/flag según WF-04; HR = 102 → calcula y marca; eₐ ≤ 0 en
  Ec. 3-11 → error; latitud en grados por error → error (RC-01).
- **NA:** `NA` en cualquier insumo → `NA` en salidas afectadas.
- **No truncar:** ETo/ETr negativa nocturna se conserva (A1 con Rn más
  negativo).
- **Contrato:** `timestamp` carácter sin `tz` → error; duplicados con
  valores distintos → error; conversión declarada de unidades registrada en
  procedencia; `timestamp_convention` ausente → error.
- **QC:** cada test de §3.2 con casos sintéticos que activan y no activan el
  flag; `ef_station_qc()` no modifica `observations` (identidad de la
  tabla antes/después).
- **Interpolación a la hora de paso:** caso aritmético O3 (0,77 mm h⁻¹);
  hora fuera de registros → `NA` + flag.
- **Día ETr24:** misma serie con `day_definition = "utc"` y
  `"local_standard"` da sumas distintas (caso sintético); día incompleto →
  `NA` + flag.
- **Ráster:** las mismas funciones sobre `SpatRaster` pequeño = resultado
  `numeric` (`ARCHITECTURE.md` §6.2).
- **Verificación cruzada con `water`** (fuera del tarball,
  `VALIDATION_PLAN.md` §1.3): `hourlyET()`/`dailyET()` vs
  `ef_station_ref_et()`; con `standard = "asce"` ya coinciden el recorte de
  ω (Ec. 56), σ horaria 2,042·10⁻¹⁰ y el límite inferior 0,3 de Rs/Rso;
  diferencias esperadas: interpolación lineal de insumos (O2 vs O3),
  definición del día, Δ con 2503.
- **Apéndice C de ASCE-EWRI (2005)** (Tablas C-3 y C-4, Greeley): `TODO`
  hasta obtener los apéndices (§8.2).

---

## 9. Contexto chileno (solo ítems abiertos)

No se afirma ningún dato sobre las redes; todo es `TODO`.

| Red (nombre a verificar) | Ítems abiertos |
|---|---|
| Dirección Meteorológica de Chile (DMC) | Acceso (portal/API), licencia y condiciones de redistribución, variables y paso temporal, alturas de sensores, zona horaria y convención de las marcas de tiempo, metadatos de entorno (¿estaciones aeronáuticas? FAO-56 cap. 3 advierte sobre datos de aeropuertos) |
| Red agrometeorológica de INIA (Agromet) | Ídem; tipo de cubierta bajo la estación (¿condición de referencia?); disponibilidad de datos horarios |
| Dirección General de Aguas (DGA) | Ídem; qué estaciones miden las variables de ETr (Rs, HR, viento) además de precipitación y temperatura |
| CEAZA (CEAZA-Met) | Ídem; cobertura geográfica y altitudinal |
| Otras redes (regionales, privadas, universitarias) | Identificar y evaluar |

Ítems transversales (`TODO`):

- Licencias: si los datos pueden incluirse en ejemplos/tests del paquete
  (CRAN, `DEVELOPMENT.md` §5–6) o solo usarse en el repositorio de
  experimentos.
- Densidad y sesgo de ubicación de estaciones (valles vs laderas y altura)
  frente a los requisitos de GWR (SPEC §6) y a la extrapolación en
  covariables.
- Condición de referencia de las estaciones en zonas áridas y semiáridas
  (FAO-56 Anexo 6; QC-08b) y su efecto en ETr (WF-08).
- Zona horaria: verificar para cada red si las marcas de tiempo están en
  hora local (con o sin horario de verano) o UTC (§2.4).
- Productos grillados nacionales o reanálisis como alternativa C2
  (`VALIDATION_PLAN.md` §2.1): disponibilidad y licencias.

---

## 10. Hallazgos que afectan a otros documentos (no editados aquí)

| Documento | Hallazgo | Acción sugerida |
|---|---|---|
| `radiation-components.md` §6.2 | `ef_air_pressure()`: forma idéntica a FAO-56 Ec. 7; supuestos (20 °C, 0,0065 K m⁻¹) en cap. 3 y Anexo 3 Ec. 3-2/3-4 | Pasar a `VERIFICADA` (FAO-56 Ec. 7) al integrar; completar supuestos |
| `radiation-components.md` §5, §6.1 | δ (Ec. 24), dr (Ec. 23), Sc y b (Ec. 32–33), ω (Ec. 31, longitudes al oeste), Gsc = 0,0820 MJ m⁻² min⁻¹ (Ec. 21) verificados | Actualizar estados y números de ecuación; Gsc FAO-56 = 1366,67 W m⁻² aporta a RC-06 |
| `radiation-components.md` §6.3.B | Rso = (0,75 + 2·10⁻⁵z)·Ra es FAO-56 Ec. 37 = Anexo 3 Ec. 3-13, declarada válida para períodos **diarios y horarios** (allí se afirma "planteada para radiación diaria"); supuesto de ángulo solar medio ≈ 50° y z < 6000 m | Corregir la limitación y citar |
| `radiation-components.md` §6.3.A | FAO-56 Anexo 3 Ec. 3-18/3-20: K_B = 0,98·exp[−0,00146P/(K_t sin ϕ) − 0,091(W/sin ϕ)^0,25]; K_D = 0,35 − 0,33·K_B (K_B ≥ 0,15). Difiere de la forma registrada allí (0,075; 0,4; 0,36) | Registrar la discrepancia en RC-08; resolver contra ASCE-EWRI (2005) y Allen et al. (2007) |
| `radiation-components.md` RC-07 | σ de FAO-56 (4,903·10⁻⁹ MJ d⁻¹) = 5,6748·10⁻⁸ W m⁻² K⁻⁴ | Solo para funciones de referencia (WF-14) |
| `soil-heat-flux.md` §3.3, D9 | G de referencia verificado para pasto (Ec. 42, 45, 46); 273,16 en FAO-56 | Referenciar este documento; mantener D9 fuera de las funciones de referencia |
| `SCIENTIFIC_SPEC.md` §3 (fila ETr), §5, §8 | Estados y ecuaciones de §4–§5; QC de §3 | Actualizar al fusionar |
| `SCIENTIFIC_SPEC.md` §3 (fila ET_inst) | FAO-56 Anexo 3 Ec. 3-1: λ = 2,501 − 2,361·10⁻³·T (Harrison, 1963); `water` usa 0,00236 | Insumo para la especificación de `metric-et.R` |
| `REFERENCES.md` | FAO-56: ISBN 92-5-104219-5 (portada HTML); ASCE-EWRI (2005): DOI `10.1061/9780784408056` y editores (Crossref); informe final de enero de 2005 leído (§1.2, §13.5) | Completado en esta rama (entrada ASCE-EWRI 2005) |

---

## 11. Registro de decisiones abiertas

| ID | Decisión | Opciones | Recomendación provisional | Bloquea |
|---|---|---|---|---|
| WF-01 | Ubicación de funciones compartidas y tests | `ef_air_pressure()`, γ, e°, Δ en un archivo atmosférico compartido / en `prep-weather.R`; tests en `test-weather.R` + `test-reference-et.R` / `test-et.R` | Archivo compartido (coherente con RC-17); test propio para ET de referencia | §4, §8 |
| WF-02 | Unidad de temperatura del aire | °C en contrato y funciones de referencia; K en radiación / K en todo | °C en `forcing` y ET de referencia (ecuaciones FAO-56 en °C); conversión explícita a K en la frontera con radiación. Cierra el `TODO` de `ARCHITECTURE.md` §4 | §2, §4 |
| WF-03 | Representación de la tabla de estaciones | Dos tablas + clase / una tabla ancha / objeto `terra::vect` | Dos tablas + clase S3 liviana; conversión a `SpatVector` en `spatial` | §2 |
| WF-04 | Valores imposibles en `observations` | Error / flag de severidad error + exclusión por política | Flag (series largas); error solo en metadatos | §2.6, §3 |
| WF-05 | Origen de P | P(z) para ETr; P medida/GWR para τ_sw (RC-08) | P(z) en ETr (norma); registrar mezcla de fuentes | §4.1 |
| WF-06 | Umbrales con intervalo publicado | δ ∈ [3, 5] % (QC-02); HRmax ∈ [80, 90] % (QC-08a) | Exponer como parámetros con el intervalo documentado; sin defecto hasta decidir | §3 |
| WF-07 | Prefijos de flags | `EF_WS_*` / nombres de `radiation-components.md` | Unificar antes de registrar | §3 |
| WF-08 | Corrección por aridez (FAO-56 Anexo 6) en ETr para METRIC | No aplicar / aplicar como configuración explícita | No aplicar por defecto; evaluar como sensibilidad; requiere revisar qué hace Allen et al. (2007) | §3, §6, §9 |
| WF-09 | ETr instantánea a la hora de paso | O1–O5 (§5.5) | O3 por defecto; O2/O4 en sensibilidad | §5.5, H1 |
| WF-10 | Ra horaria en amanecer/atardecer y constante de longitud | Criterio de punto medio (FAO-56) / límites de ω (ASCE-EWRI Ec. 56, `VERIFICADA`); 0,06667 / 1/15 | **Resuelta en el código** como argumento `standard` de `ef_ra_period()` (punto medio con `"fao56"`, Ec. 56 con `"asce"`); 1/15 exacto | §4.6 |
| WF-11 | Definición del día de ETr24 y huecos | Día local estándar / UTC; tolerancia de huecos | Argumento explícito; sin relleno. El texto principal de ASCE-EWRI no define el reloj del día (Apéndice C no leído): sigue abierta | §5.6 |
| WF-12 | Rso de la referencia | Ec. 37 / Anexo 3 Ec. 3-14 o 3-17 | Ec. 37 (definición estándar); variantes solo para QC | §4.7 |
| WF-13 | API de ET de referencia | Una función con `reference`, `timestep`, `standard` / alias `ef_etr_hourly()`, `ef_etr_daily()`; exportar componentes | Una función exportada; componentes internos | §4.8, §5.4 |
| WF-14 | Constantes de la norma vs del paquete | Literales FAO-56/ASCE (σ, 273,16, 273) / constantes del paquete | Literales de cada norma dentro de funciones de referencia (σ = 4,903·10⁻⁹ FAO-56; 4,901·10⁻⁹ y 2,042·10⁻¹⁰ ASCE-EWRI) | §4.8 |
| WF-15 | Criterio día/noche para G y Cd horarios | Rn > 0 / Ra > 0 / ángulo solar | ASCE-EWRI: Rn > 0 (Tabla 2, p. 5; `"rn_positive"`, `VERIFICADA`; inconsistencia en Rn = 0, §4.9). FAO-56: sin umbral, sigue abierta (`"ra_positive"` o `"rn_positive"` explícitos) | §4.9, §5.3 |
| WF-16 | ETr24: suma horaria vs ecuación diaria | D1 / D2 | D1 (coherencia con ETr_inst) | §5.6 |
| 5.1 (SPEC) | Interpolar-calcular vs calcular-interpolar | A / B / C | Soportar A y C; decidir con validación cruzada | §6 |

---

## 12. Registro de fuentes y accesos (2026-11-04)

| Host / recurso | Resultado |
|---|---|
| `www.fao.org` (FAO-56 HTML, `https://www.fao.org/4/x0490e/`) | Accesible; capítulos 2–4 y anexos 2, 3, 5, 6 leídos; ecuaciones leídas como imágenes |
| `www.fao.org` (PDF de FAO-56: `/4/x0490e/x0490e.pdf`, `/4/x0490e/x0490e00.pdf`) | 404 (no hallado) |
| `api.crossref.org` | Accesible: metadatos de ASCE-EWRI (2005) obtenidos. Una segunda consulta (DOI de Allen et al., 2007) devolvió 429 (límite de tasa); no se reintentó |
| `cran.r-project.org` | Accesible: fuente de `SPEI` 1.8.1 |
| `zenodo.org` | Accesible; búsquedas sin copia del informe ASCE-EWRI |
| `ascelibrary.org` | Bloqueado (403, informado de antemano); no se intentó |
| `github.com` | Bloqueado (informado de antemano); no se intentó |
| `www.kimberly.uidaho.edu`, `www.mesonet.org` (posibles copias del informe ASCE-EWRI) | Bloqueados por el proxy (sin conexión); no se reintentó. 2026-11-04: `www.kimberly.uidaho.edu` (posible copia de los apéndices) sigue sin conexión |
| Informe final ASCE-EWRI, enero de 2005 (PDF de 70 páginas y su texto) | 2026-11-04: entregado por el integrador; leído completo (i–vii, 1–59). Sin apéndices A–F |
| `www.fao.org/3/...` (ruta antigua) | Redirige a `/4/`; la ruta `/3/x0490e/x0490e.pdf` sin conexión |
| `openknowledge.fao.org` | Sin conexión; no se reintentó |
| `export.arxiv.org` (API de búsqueda) | No resuelve; no se reintentó |

---

## 13. Estado de implementación (M3)

Fecha: 2026-11-04 · Rama `feature/m3-reference-et`. Alcance: §4 (variables
derivadas) y §5 (ET de referencia). El contrato de estaciones y el QC
(§2–§3) se implementaron por separado (§2.7, §3.3); `ef_station_ref_et()`
(orquestación por estación, §5.4) se implementó en la rama
`feature/m3-station-ref-et` (§13.4).

### 13.1 Archivos y funciones

| Archivo | Función | Exportada | Estado |
|---|---|---|---|
| `R/forcing-derived.R` | `ef_psychrometric(pressure)` | Sí | `VERIFICADA` (Ec. 8) |
| | `ef_es(air_temperature)`, `ef_es_slope(air_temperature)` | Sí | `VERIFICADA` (Ec. 11–13) |
| | `ef_ea_dewpoint(dewpoint_temperature)`, `ef_ea_rh(air_temperature, relative_humidity)`, `ef_ea_tmin(tmin, k0)`, `ef_ea_daily(tmin, tmax = NULL, rh_max, rh_min = NULL, method)` (un solo `.Rd`, tema `ef_ea`; `method` ∈ `"rhmax_rhmin"`, `"rhmax"`, `"rhmin"`, `"rhmean"`, `"rhmean_tmean"`) | Sí | `VERIFICADA` (Ec. 14, 17–19, 48, 54; ASCE-EWRI Ec. 13–14) |
| | `ef_dewpoint(vapour_pressure)` | Sí | `VERIFICADA` (Anexo 3 Ec. 3-11) |
| | `ef_wind_2m(wind_speed, height)` | Sí | `VERIFICADA` (Ec. 47) |
| | `ef_ra_daily(lat, doy)`, `ef_ra_period(lat, lon, doy, utc_mid, period_hours, standard)` | Sí | `VERIFICADA` (Ec. 21–33; ASCE-EWRI Ec. 21–29, 48–61) |
| | `ef_rso(extraterrestrial, elevation)` | Sí | `VERIFICADA` (Ec. 37) |
| | `sat_vp()`, `ef_sunset_hour_angle()`, `ef_daylight_hours()` (Ec. 11, 25, 34) | No | `VERIFICADA` |
| `R/reference-et.R` | `ef_ref_net_radiation(solar_radiation, clear_sky_radiation, vapour_pressure, air_temperature = NULL, tmax = NULL, tmin = NULL, timestep, standard, cloudiness = NULL)` → `earthflux_reference_net_radiation` (`rn`, `rns`, `rnl`, `cloudiness`, `timestep`, `standard`, `flags`, `provenance`) | Sí | `VERIFICADA` (Ec. 38–40 y paso horario; ASCE-EWRI Ec. 15–18, 42–45) |
| | `ef_ref_soil_heat_flux(net_radiation, reference, timestep, standard, daytime = NULL)` → `numeric` | Sí | `VERIFICADA` (FAO-56 Ec. 42, 45, 46; ASCE-EWRI Ec. 30, 65–66) |
| | `ef_ref_et(net_radiation, soil_heat_flux, air_temperature, wind_speed_2m, vapour_pressure_deficit, slope, psychrometric, reference, timestep, standard, daytime = NULL)` → `earthflux_reference_et` (`et_ref`, `reference`, `timestep`, `standard`, `flags`, `provenance`) | Sí | `VERIFICADA` (FAO-56 Ec. 6, 53; ASCE-EWRI Ec. 1, Tabla 1) |
| | `ef_reference_constants()` (tabla única de §5.3), `check_reference_setup()`, `check_daytime()`, `ef_diagnose_reference_et()`, `ef_flags_reference_et()` | No | – |
| | `ef_ref_et_inst_interp(et_ref, period_mid, overpass)` (opción O3, §5.5) y `ef_ref_et_daily_sum(et_ref, day, periods_per_day)` (opción D1, §5.6) | No | `TODO` (WF-09, WF-11, WF-16 abiertas); usadas por `ef_station_ref_et()` |
| `R/prep-weather.R` | `ef_station_ref_et(x, reference, timestep, standard, humidity, day_definition, day_completeness, daytime_rule = NULL, night_cloudiness = NULL, night_ratio = NULL, overpass = NULL, inst_method = NULL, dates = NULL, utc_offset = NULL)` → `earthflux_station_ref_et` | Sí | Física: la de las funciones llamadas; elecciones de orquestación en §13.4 |

Tests: `tests/testthat/test-forcing-derived.R` (V1–V9, V12, V13, V17,
equivalencia de longitud, Ra diaria vs suma horaria, bordes, NA, `dim`) y
`tests/testthat/test-reference-et.R` (V10, V11, V14–V16, A1–A4, constantes,
errores, flags, O3 y D1). `test-weather.R` queda para el contrato y el QC
(WF-01).

### 13.2 Decisiones tomadas al implementar

1. **Constantes ASCE-EWRI como `CANDIDATA` por indicación del autor**
   (superado el 2026-11-04: verificadas contra el informe final, §13.5;
   texto conservado como registro). Las
   constantes estandarizadas de ASCE-EWRI (2005) (referencia alta/alfalfa,
   Cn/Cd diarios y horarios, Cd día/noche, G/Rn 0,04/0,2 y 0,1/0,5) se
   implementaron como `CANDIDATA`, por indicación del autor de avanzar M3,
   bajo la regla M2 de `DECISIONS.md` §1.0: rótulo `CANDIDATA` en roxygen,
   en la procedencia y en cada fila de la tabla interna con su fuente
   secundaria (`SPEI` 1.8.1; `water` 1.0), sin defectos ocultos. Reemplaza,
   mientras se lee ASCE-EWRI (2005), la frase de §5.4 "mientras tanto solo
   `standard = "fao56"` + `reference = "grass"` es implementable". El
   integrador registra la decisión en `DECISIONS.md`.
2. **Objetos de retorno.** `ef_ref_et()` devuelve un objeto con clase
   `earthflux_reference_et` (no un `numeric` con atributos, §5.4), según
   `ARCHITECTURE.md` §3.2: el valor está en `$et_ref`; `reference`,
   `timestep` y `standard` como elementos; las filas de constantes usadas
   (con fuente y estado) en `provenance$constants`. `ef_ref_net_radiation()`
   devuelve `earthflux_reference_net_radiation` con los flags de §4.8.
3. **WF-13 (API).** `ef_ref_net_radiation()` y `ef_ref_soil_heat_flux()` se
   exportan (no internas, §4.8–§4.9): sin ellas `ef_ref_et()` no puede
   usarse mientras `ef_station_ref_et()` no exista. Revisar con T-16 antes
   de `0.1.0`. `ef_etr_hourly()`/`ef_etr_daily()` no se crearon (no aportan
   sobre `ef_ref_et()`).
4. **`ef_ref_soil_heat_flux()`** recibe `standard` (las razones G/Rn de la
   tabla dependen de la norma) y el argumento se llama `net_radiation`
   (regla N5, igual que en `ef_ref_et()`). `daytime` es obligatorio en paso
   horario (ambas normas) y debe ser `NULL` en paso diario; G diario = 0
   (`NA` donde Rn es `NA`).
5. **`daytime` en `ef_ref_et()`:** obligatorio con `timestep = "hourly"` y
   `standard = "asce"`; con FAO-56 horario no se usa (Cd = 0,34 de día y de
   noche) y se acepta sin efecto; debe ser `NULL` en paso diario. El
   criterio día/noche lo decide quien llama (WF-15 sigue abierta).
6. **`cloudiness`** es el término f = 1,35·Rs/Rso − 0,35 (no el cociente),
   en [−0,35; 1]; si se entrega, se usa en todas las posiciones y
   `clear_sky_radiation` puede ser `NULL`. Sin `cloudiness`, Rso = 0 es
   `earthflux_domain_error` (cociente indefinido). La selección del valor
   nocturno (§4.8) queda en la orquestación.
7. **`ef_ea_tmin(tmin, k0)` sin defecto para `k0`** (la propuesta era
   `k0 = 0`): K₀ depende del clima (FAO-56 Anexo 6: 0 o 2 °C) y es una
   elección científica explícita (T-15). `k0 ≥ 0`.
8. **`ef_ea_daily()`**: `tmax` y `rh_min` admiten `NULL` con
   `method = "rhmax"` (Ec. 18 no los usa); `tmin > tmax` →
   `earthflux_domain_error` (clase III `EF_WS_TMIN_GT_TMAX`).
9. **ωs en condiciones polares:** el argumento de arccos de la Ec. 25 se
   limita a [−1, 1] (ωs = π en día polar, 0 en noche polar), límites
   geométricos exactos; FAO-56 Ec. 26–27 trata el mismo caso con
   X = 0,00001. Evita `NaN` en latitudes > 66,5°.
10. **`ef_ra_period()`:** `period_hours` ∈ (0, 1] (dominio de la Ec. 28,
    "horario o menor"); `doy` es el de la fecha UTC del punto medio; criterio
    de punto medio de FAO-56 y 1/15 h por grado exacto (WF-10); ω se
    obtiene con `ef_hour_angle()` (reutilizado, no reimplementado).
11. **Gsc** se toma de `EF_SOLAR_CONSTANT` (W m⁻²) convertido a
    MJ m⁻² min⁻¹ (= 0,0820, Ec. 21), sin literal duplicado.
12. **Dominios de temperatura:** Ec. 11/13 exigen T > −237,3 °C; Rnl exige
    T > −273,16 °C (conversión de la Ec. 39); el término aerodinámico
    T > −273 °C. Los literales de la norma (0,23; 4,903·10⁻⁹; 273,16; 273;
    0,408; 0,665·10⁻³) quedan dentro de las funciones (WF-14).
13. **Flags registrados** (`ef_flags_reference_et()`, prefijo `EF_WS_`,
    ámbito `record`, sin bit): `EF_WS_RS_RSO_LIMITED` (I-m, info; el método
    —límite de la Ec. 39— es `VERIFICADA`) y `EF_WS_ETR_NEGATIVE` (I, info;
    nombre normalizado de `EF_ETREF_NEGATIVE`, cubre ETo y ETr). Con la
    orquestación por estación se agregaron `EF_WS_INCOMPLETE_DAY` (I,
    warning) y `EF_WS_OVERPASS_OUTSIDE_RECORDS` (I, info) (§13.4); las
    auxiliares O3 y D1 solo devuelven `NA`.
14. **Ubicación (WF-01):** γ, e° y Δ quedan en `R/forcing-derived.R` y no en
    `R/shared-physics.R` (la cabecera de este ya lo indica). Si otro módulo
    los necesita, el integrador puede moverlos sin cambiar su API.

### 13.3 Pendiente

- Opciones O2, O4 y O5 de ETr_inst (§5.5), D2 a partir de registros
  horarios (agregados diarios de datos horarios, §5.6) y tolerancias de
  huecos distintas de `"all_periods"` (WF-11). (El arrastre por ángulo
  solar β > 0,3 rad de ASCE-EWRI Ec. 46 se implementó: §13.5.)
- Interfaz `ef_station_ref_et()` → `station_regionalization_input()` para
  `etr_inst`, `etr_24`, `wind_speed_2m` y `clearness` (§7.2).
- Relación de Ångström (Ec. 35; usada solo en el test de V14) y Rs desde
  horas de sol; variantes de Rso (Anexo 3 Ec. 3-14 a 3-20, solo QC);
  psicrómetro (Ec. 15–16, caso V5 opcional); inversa exacta de la Ec. 11.
- Caso de verificación de ETr alfalfa con los ejemplos publicados de
  ASCE-EWRI (2005), Apéndice C (Tablas C-3 y C-4): la copia leída no
  incluye los apéndices (§8.2); A1–A4 y S1–S8 verifican aritmética y
  reglas.
- Test sobre `SpatRaster` (§8.4): `terra` no es dependencia de este módulo.

### 13.4 Orquestación por estación: `ef_station_ref_et()` (M3, 2026-11-04)

Rama `feature/m3-station-ref-et`. Archivo `R/prep-weather.R` (exportada,
clase `earthflux_station_ref_et`), tests en
`tests/testthat/test-station-ref-et.R`. Usa solo funciones existentes
(§4–§5); no agrega ecuaciones. Decisiones tomadas al implementar
(provisionales, registradas en `DECISIONS.md` §1.3, M3-11 … M3-19):

1. **Firma y decisiones abiertas como argumentos sin defecto.**
   `reference`, `timestep`, `standard`, `humidity`, `day_definition` (WF-11)
   y `day_completeness` (WF-11, política de huecos) no tienen defecto. Los
   que solo aplican al paso horario —`daytime_rule` (WF-15),
   `night_cloudiness` (+ `night_ratio`) (§4.8) y `inst_method` (WF-09, con
   `overpass`)— tienen `NULL` como marcador y son obligatorios cuando
   aplican (`earthflux_missing_input`); en paso diario deben ser `NULL`
   (`earthflux_input_error`). `utc_offset` es obligatorio solo con
   `day_definition = "local_standard"`. Todas las elecciones quedan en
   `provenance$choices`.
2. **Entrada y política de QC.** `x` es `earthflux_station_qc` (se usa su
   política) o `earthflux_station_table` (se aplica `ef_station_qc(x)` con
   `"exclude_critical"`, registrado en `provenance$qc`). Los valores
   `"excluded"` entran como `NA` (`station_values()`); se cuentan por
   variable. Con `"keep_all"`, un imposible llega al núcleo y produce
   `earthflux_domain_error` (§3.1, `flags.md` §5.3).
3. **Paso horario** (`interval` = 3600 s, medias de período): Ra por
   período con `ef_ra_period()` (criterio de punto medio, día del año UTC
   del punto medio), Rso Ec. 37 (WF-12), P(z) Ec. 7 (WF-05; la
   `air_pressure` medida no se usa), u₂ Ec. 47 con `height_wind`, Rs de
   W m⁻² a MJ m⁻² h⁻¹ (× 0,0036). eₐ según `humidity`:
   `"vapour_pressure"`, `"dewpoint_temperature"` (Ec. 14) o
   `"relative_humidity"` (Ec. 54).
4. **Paso diario** (`interval` = 86 400 s): Tmedia Ec. 9, es Ec. 12, Δ en
   Tmedia, Ra Ec. 21 con el día del registro (en la definición del día), Rs
   × 0,0864, G = 0; eₐ por Ec. 14, Ec. 17 (`rh_max`/`rh_min`) o
   `vapour_pressure`. Rso = 0 (noche polar) → `NA` (término de nubosidad
   indefinido). `etr_24` es el valor del registro (opción D2 con datos
   diarios); `overpass` no se admite.
5. **Nubosidad nocturna** (§4.8; registros con Rso = 0):
   `"before_sunset"` = cociente del **último** registro de la misma
   estación en las 24 h previas cuyo ω del punto medio cumple
   ωs − 0,79 ≤ ω ≤ ωs − 0,52 (FAO-56 cap. 4); elegir el último cuando dos
   períodos califican es una elección de implementación. Sin registro que
   califique (p. ej., la primera noche de la serie) → `NA` +
   `EF_INPUT_NA`. Se arrastra el término ya limitado (Rs/Rso ≤ 1).
   `"fixed"` = cociente constante `night_ratio` ∈ [0, 1] (FAO-56: 0,4–0,6
   húmedo, 0,7–0,8 árido, 0,3 cubierto; con `"asce"`, ∈ [0,3; 1]).
   `"low_sun"` = regla de ASCE-EWRI Ec. 46 (agregada el 2026-11-04,
   §13.5).
6. **Día/noche (WF-15):** `"ra_positive"` (Ra del período > 0; con
   `"fao56"`, criterio de punto medio) o `"rn_positive"` (Rn > 0,
   definición de ASCE-EWRI, Tabla 2, p. 5, `VERIFICADA`). Selecciona G/Rn
   y, con `"asce"`, Cd.
7. **ETr_inst (WF-09):** opciones `"O1"` (período que contiene la hora de
   paso, intervalo [inicio, fin)) y `"O3"` (interpolación lineal de la tasa
   entre puntos medios con `ef_ref_et_inst_interp()`; se inserta un nodo
   `NA` tras cada paso mayor que un período, para no interpolar a través de
   un registro faltante). Cada estación recibe todas las horas de
   `overpass` (UTC). Fuera del soporte (O1: inicio del primer período a fin
   del último; O3: primer a último punto medio) → `NA` +
   `EF_WS_OVERPASS_OUTSIDE_RECORDS`; dentro, un registro faltante o una ETr
   `NA` → `NA` + `EF_INPUT_NA`. O2, O4 y O5 no se implementaron (O2/O4
   exigen interpolar insumos y recalcular la geometría en el instante; queda
   para el análisis de sensibilidad).
8. **ETr_24 (WF-16, WF-11):** paso horario → D1 (suma de las 24 láminas
   horarias del día, con `ef_ref_et_daily_sum()`); un período pertenece al
   día de su punto medio en la definición elegida (`"utc"` o
   `"local_standard"` con `utc_offset` en horas, sin horario de verano).
   `day_completeness = "all_periods"` (única opción): el día necesita todos
   sus períodos con ETr válida; si no → `NA` + `EF_WS_INCOMPLETE_DAY`, sin
   relleno. `dates = NULL` → todos los días con registros; un día pedido
   sin registros tiene `n_periods = 0` y se marca.
9. **Objeto de resultado:** `series` (una fila por registro de
   `observations`, mismo orden, con las magnitudes intermedias), `etr_inst`
   (estación × hora de paso; mm h⁻¹), `etr_24` (estación × día; mm d⁻¹),
   `reference`, `timestep`, `standard`, `flags` y `provenance`. Los flags son
   de ámbito `record` y llevan el campo `target` (`"series"`, `"etr_inst"`,
   `"etr_24"`) propuesto en `flags.md` §6.2 para indicar la tabla a la que
   se refiere `index`; `provenance$flags_evaluated` (códigos) y
   `provenance$flags_evaluated_by_target`.
10. **Flags:** `EF_WS_INCOMPLETE_DAY` (warning) y
    `EF_WS_OVERPASS_OUTSIDE_RECORDS` (info) se registran en
    `ef_flags_reference_et()` (QC-10 pertenece a la suma diaria, no al QC:
    depende de la definición del día). En la serie se combinan los de
    `ef_ref_net_radiation()` y `ef_ref_et()` (`EF_INPUT_NA`,
    `EF_WS_RS_RSO_LIMITED`, `EF_WS_ETR_NEGATIVE`).
11. **QC completado:** `EF_WS_RS_GT_RA` (QC-05b) y la variante eₐ > e°(T) de
    QC-04 se evalúan en `ef_station_qc()` (§3.3). Rs < 0 y precipitación < 0
    se agregaron a QC-01a (`EF_WS_OUT_OF_DOMAIN`): sin ello, una Rs nocturna
    negativa (desplazamiento del piranómetro) detendría
    `ef_station_ref_et()` con `earthflux_domain_error`; con la política por
    defecto se excluye y el período queda `NA`.
12. **Verificación:** el Ejemplo 19 de FAO-56 (V15, V16 con Rs/Rso = 0,8
    vía `"fixed"`) y el Ejemplo 18 (V14, registros diarios) se reproducen a
    través de `ef_station_ref_et()`; A3 (alfalfa horaria) como aritmética.

Preguntas abiertas detectadas: (a) Rs nocturna ligeramente negativa o
positiva (QC-05d, clase II) hace que la regla `"all_periods"` pierda días
enteros; requiere la tolerancia de QC-05d o una política de huecos (WF-11);
(b) definición de Ra horaria en los períodos de salida y puesta del sol
para ETr (WF-10): la orquestación usa el criterio de punto medio de
`ef_ra_period()`, mientras que QC-05b usa la integral sobre la parte con
sol. (Actualización 2026-11-04: con `standard = "asce"` la orquestación
usa los límites de la Ec. 56, que coinciden con la integral de QC-05b
para períodos de 1 h; con `"fao56"`, el punto medio.)

### 13.5 Verificación contra ASCE-EWRI (2005) (M3, 2026-11-04)

Rama `feature/m3-station-ref-et`. Fuente: informe final del Task Committee
on Standardization of Reference Evapotranspiration (EWRI-ASCE), enero de
2005, 70 páginas (i–vii, 1–59), **sin apéndices** (§1.2). Cada ítem se
contrastó en el texto; "=" significa la misma forma y los mismos
coeficientes que la implementación.

| Ítem | ASCE-EWRI (2005) | EarthFlux | Resultado |
|---|---|---|---|
| Ecuación estandarizada | Ec. 1 (p. 4): forma Cn/Cd, 0,408 en m² mm MJ⁻¹, T + 273, unidades por paso | `ef_ref_et()` | = `VERIFICADA` |
| Cn, Cd | Tabla 1 (p. 5): 900/0,34 y 1600/0,38 (diario); 37/0,24 y 66/0,25 (día); 37/0,96 y 66/1,7 (noche) | `ef_reference_constants()` | = `VERIFICADA` (sin cambios de valor) |
| K_time | Glosario (p. 56): 86 400 s d⁻¹ / 3600 s h⁻¹; absorbido en Cn | – | = (sin uso explícito) |
| λ, 0,408 | p. 9 y 27: λ = 2,45 MJ kg⁻¹, ρ_w = 1 Mg m⁻³ | literal 0,408 | = `VERIFICADA` |
| T diaria | Ec. 2 (p. 9): (Tmax + Tmin)/2 | orquestación diaria | = `VERIFICADA` |
| P | Ec. 3 y 34 (p. 10, 28) | `ef_air_pressure()` | = `VERIFICADA` |
| γ | Ec. 4 y 35: 0,000665·P | `ef_psychrometric()` | = `VERIFICADA` |
| Δ | Ec. 5 y 36: 2503·exp(17,27T/(T + 237,3))/(T + 237,3)² | `ef_es_slope()` (4098·e°(T)/(T + 237,3)²) | Diferencia de redondeo 2,3·10⁻⁵ relativa; se mantiene la forma FAO-56 (§4.3) |
| e°, es | Ec. 6–7 (diaria, Tmax/Tmin), Ec. 37 (horaria) | `ef_es()`, orquestación | = `VERIFICADA` |
| eₐ | Tablas 3 y 4 (p. 12, 30); Ec. 8, 11, 12, 38, 41 = FAO-56 14, 17, 18, 54; Ec. 13 y 14 nuevas; FAO-56 Ec. 19 "no recomendada" (p. 17) | `ef_ea_*()` | = para las comunes; **agregadas** `"rhmin"` (Ec. 13) y `"rhmean_tmean"` (Ec. 14). Psicrómetro (Ec. 9–10, 39–40) y Tmin (Apéndice E) no implementados |
| Rn, Rns, α | Ec. 15–16, 42–43: α = 0,23 ambas referencias, ambos pasos | `ef_ref_net_radiation()` | = `VERIFICADA` |
| Rnl, σ | Ec. 17 (σ = 4,901·10⁻⁹ d⁻¹), Ec. 44 (2,042·10⁻¹⁰ h⁻¹), T_K = T + 273,16 | `ef_ref_net_radiation(standard)` | **Diferencia con FAO-56** (4,903·10⁻⁹): elección de norma con `standard` (argumento nuevo, sin defecto) |
| f_cd, límites | Ec. 18 y 45: 0,3 ≤ Rs/Rso ≤ 1; 0,05 ≤ f_cd ≤ 1 | `standard = "asce"` | **Diferencia con FAO-56** (sin límite inferior): elección de norma. **Inconsistencia del informe**: 1,35·0,3 − 0,35 = 0,055 ≠ 0,05 (§4.8) |
| f_cd con sol bajo y de noche | Ec. 46 (p. 35–36) con β de la Ec. 62 (p. 43): β < 0,3 rad → f_cd del último período con β > 0,3 rad; un valor por día | `night_cloudiness = "low_sun"` | **Agregada** (`VERIFICADA`). "~17°" (p. 35) vs "~15°" (p. 36) para 0,3 rad: errata |
| Rso | Ec. 19 (diaria), Ec. 47 (horaria) | `ef_rso()` | = `VERIFICADA` ("Eq. 48" en p. 38: errata) |
| Ra diaria | Ec. 21–24, 27–29 (Gsc = 4,92 MJ m⁻² h⁻¹, 24/π) | `ef_ra_daily()` (0,0820 MJ m⁻² min⁻¹, 24·60/π) | = `VERIFICADA` (Gsc idéntica) |
| Ra horaria | Ec. 48, 50–55, 57–61; límites Ec. 56 | `ef_ra_period(standard)` | = salvo la salida/puesta: **diferencia con FAO-56** (punto medio), elección de norma con `standard` (argumento nuevo). Inconsistencia de la p. 41 (punto medio vs Ec. 56) y día polar: §4.6 |
| Ángulo horario | Ec. 55: 0,06667, hora estándar local, Lz y Lm al oeste | `ef_hour_angle()` (UTC, 1/15 exacto) | Equivalente (WF-10) |
| G | Ec. 30 (diario 0), 65a–b, 66a–b (p. 44) | `ef_ref_soil_heat_flux()` | = `VERIFICADA` |
| Día/noche | Texto previo a la Tabla 1 y Tabla 2 (p. 5): día Rn > 0, noche Rn ≤ 0; p. 44 y glosario (p. 58): noche Rn < 0, día Rn ≥ 0 | `daytime_rule = "rn_positive"` (Rn > 0) | `VERIFICADA` con la Tabla 2; **inconsistencia del informe** en Rn = 0 documentada |
| Viento a 2 m | Ec. 33 (p. 26) y 67 (p. 44; "Eq. 68" en el texto: errata) | `ef_wind_2m()` | = `VERIFICADA`. Viento sobre alfalfa: Apéndice B, no implementado |
| Pasos sub-horarios | p. 27: tasa en mm h⁻¹ × fracción de hora | `period_hours` ∈ (0, 1] en Ra; la orquestación solo acepta 1 h | Coherente |
| ET negativa | p. 45: conservar en general los negativos en la suma de 24 h | flag `EF_WS_ETR_NEGATIVE`, sin truncar | = `VERIFICADA` |
| Día de la suma horaria | p. 45: suma "sobre el período de 24 horas" | D1, 24 períodos, día UTC o local estándar (WF-11) | Reloj del día **no definido** en el texto principal: WF-11 abierta |
| Ejemplos | Apéndice C, Tablas C-1 a C-4 (Greeley, Colorado, julio de 2000) | – | **No reproducidos**: apéndices ausentes de la copia (§8.2) |

Decisiones tomadas (para que el integrador las registre en `DECISIONS.md`):

1. Las diferencias FAO-56 vs ASCE-EWRI de σ, límites de Rs/Rso y límites
   de integración de Ra son **elecciones de norma** controladas por
   `standard`, sin defecto, en `ef_ref_net_radiation()` y
   `ef_ra_period()` (cambio de firma: ambos reciben `standard`).
   `ef_station_ref_et()` pasa su `standard`. El comportamiento con
   `"fao56"` y sus tests no cambian.
2. Δ: se mantiene la Ec. 13 de FAO-56 también para `"asce"` (diferencia
   de redondeo documentada, sin argumento nuevo).
3. Las reglas propias de ASCE-EWRI se agregan como opciones explícitas:
   `night_cloudiness = "low_sun"` (Ec. 46), `ef_ea_daily(method =
   "rhmin" | "rhmean_tmean")` (Ec. 13–14); `daytime_rule = "rn_positive"`
   pasa a `VERIFICADA` para ASCE.
4. `EF_WS_RS_RSO_LIMITED` cubre ambos límites del cociente (> 1 en
   ambas normas; < 0,3 en ASCE-EWRI); descripción del registro
   actualizada, sin código nuevo.
5. Con `standard = "asce"` y `night_cloudiness = "fixed"`, `night_ratio`
   debe estar en [0,3; 1] (ASCE-EWRI p. 36).

No se encontró ningún error de implementación (bug) en la cadena: todas
las diferencias son de norma o reglas ausentes, agregadas como opciones.
