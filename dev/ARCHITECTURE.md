# EarthFlux — Arquitectura

Estado: **borrador M0** · Complementa `SCIENTIFIC_SPEC.md`.

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
| `forcing` | Leer, estandarizar y controlar calidad de datos de estaciones; derivar variables (ea, u a altura de referencia, ETr) | `io-weather.R`, `prep-weather.R`, `prep-qc.R` | Interpolación espacial |
| `spatial` | Regionalizar variables meteorológicas (GWR; alternativas de referencia) y conservar parámetros, kernel, bandwidth, criterios, residuos, AICc, CV, diagnósticos y flags | `gwr-fit.R`, `gwr-bandwidth.R`, `gwr-predict.R`, `gwr-diagnostics.R` | Conocer METRIC |
| `metric` | Núcleo físico modular: Rn, G, anclas, rah, dT, H, LE, ET_inst, ETrF, ETa | `metric-*.R` | Leer archivos o conocer el sensor |
| `diagnostics` | Registro de flags y su construcción; resúmenes de calidad | `diagnostics.R` | Modificar valores |
| `validation` | Métricas de concordancia y comparación entre configuraciones | `validation.R`, `api-validate.R` | Ajustar el modelo a los datos de validación |
| `api` | Orquestación de alto nivel | `api-earthflux.R`, `api-prepare.R`, `api-run.R` | Implementar ecuaciones |

Soporte transversal: `classes.R`, `print.R`, `plot.R`, `utils.R`.

## 3. Núcleo físico: funciones numéricas vectorizadas

Recomendación de diseño (a confirmar en M1):

- Las funciones `ef_*()` del núcleo operan sobre **vectores numéricos**
  (o arreglos) y son puramente aritméticas.
- Los envoltorios espaciales aplican esas mismas funciones sobre rásteres
  (p. ej., capas de `terra`) sin reimplementarlas.

Ventajas: tests unitarios triviales y rápidos sin dependencias espaciales;
independencia del backend ráster; verificación numérica directa contra casos
de la literatura; compatibilidad CRAN.

## 4. Contratos de datos (borrador)

`TODO (M1)`: completar con nombres definitivos, unidades y validadores.

**Estado de superficie** (salida de `surface`):

| Nombre | Unidad | Obligatorio |
|---|---|---|
| `lst` | K | Sí |
| `albedo` | – | Sí |
| `ndvi` | – | Sí |
| `lai` | m² m⁻² | Según método de G/rugosidad |
| `emissivity` | – | Sí |
| `elevation`, `slope`, `aspect` | m, rad, rad | Para corrección por terreno |
| `overpass_time` | POSIXct (UTC) | Sí |
| `qa` | flags | Sí |

**Forzamiento meteorológico** (salida de `forcing`/`spatial`):

| Nombre | Unidad | Obligatorio |
|---|---|---|
| `air_temperature` | °C `TODO: decidir K vs °C` | Sí |
| `vapour_pressure` | kPa | Sí |
| `wind_speed` + altura de medición | m s⁻¹, m | Sí |
| `solar_radiation` | W m⁻² | Sí |
| `etr_inst`, `etr_24` | mm h⁻¹, mm d⁻¹ | Sí |
| `method` | texto (estación única / GWR / alternativa) | Sí |

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

## 6. Decisiones abiertas

### 6.1 Backend de GWR (no decidido)

Observado en CRAN el 2026-11-04 (verificar mantenimiento antes de decidir):

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
| Verificación cruzada contra implementaciones GPL sin empaquetarlas (`inst/verification/`) | Script de verificación contra `water` (GPL) fuera del tarball, cargado solo si está instalado |
| Grupos de tests opcionales por variable de entorno (online, lentos, referencias externas) | `EARTHFLUX_ONLINE_TESTS`, `EARTHFLUX_SLOW_TESTS` (por definir) |
| Historias de usuario con tests de aceptación (`docs/USER_STORIES.md`, `test-story-XX.R`) | A definir en M1 (`dev/USER_STORIES.md`) |
| Workflows `pkgdown` (gh-pages) y `release` (tag ↔ versión ↔ sección de NEWS) | Planificados para M0/M7 |
| `.zenodo.json`, `CITATION.cff`, `inst/WORDLIST` | `CITATION.cff` creado; `.zenodo.json` y `WORDLIST` con el primer release |
| `Language: en-GB` | Adoptado |
| Sin paralelismo explícito | EarthFlux lo incorpora (6.3) con verificación de equivalencia |
