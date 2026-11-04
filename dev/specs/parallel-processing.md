# EarthFlux — Especificación: procesamiento en paralelo

Estado: **borrador M1** · Requisito aceptado en `ARCHITECTURE.md` §6.3 ·
Complementa `ARCHITECTURE.md` §3, §6.2 y §6.6, `DEVELOPMENT.md` §4, §5 y §7,
`VALIDATION_PLAN.md` §1 y `USER_STORIES.md` (US-06, US-08, US-11).

> **Regla de evidencia.** Toda afirmación sobre la API o el comportamiento de
> un paquete proviene de (a) su documentación instalada, (b) los metadatos de
> CRAN o (c) código ejecutado el **2026-11-04** con las versiones de la
> sección 1. Lo que no pudo comprobarse se marca `TODO`. Este documento no
> define código del paquete: fija reglas y convenciones para cuando existan
> los envoltorios ráster (M2) y la orquestación (M5).

> **Estado de implementación (M3, 2026-11-04).** Primera función que
> paraleliza entre tareas: `ef_regionalize()` / `ef_regionalize_cv()`
> (`gwr-forcing.md`, bloque de estado de la orquestación). Aplicado:
> `future.apply` y `future` en `Imports` (D-PP-01; `future` por
> `nbrOfWorkers()` y `class(plan())` para la procedencia, P-11);
> `future_lapply(future.seed = TRUE)` solo si `nbrOfWorkers() > 1`, si no
> `lapply()` (P-01, P-05); sin `plan()`, sin cambios de `terraOptions()` ni
> `options()` (P-04); tareas con matrices y modelos, nunca `SpatRaster`
> (P-06); bucle propio por bloques con `block_rows` (no `max_cells`,
> nombre de `gwr-forcing.md` §9.1) y `filename`/`overwrite`/`wopt` (P-08,
> P-09); archivos de una llamada fallida eliminados con `on.exit()`; test
> secuencial = `multisession` (2 workers), omitido en CRAN. El benchmark
> quedó en `dev/benchmarks/regionalize.R` (carpeta existente
> `dev/benchmarks/`, no `dev/bench/`): 2 workers dieron 2,2× (2,5 × 10⁵
> celdas) y 1,6× (10⁶ celdas) con resultados `identical()`.

---

## 0. Resumen de decisiones propuestas

| ID | Propuesta | Estado |
|---|---|---|
| P-01 | **Secuencial por defecto** en ambos niveles | Propuesta (ya aceptada como regla en `ARCHITECTURE.md` §6.3) |
| P-02 | Intra-escena: **una sola pasada por bloque** que aplica el núcleo numérico `ef_*()` a las matrices del bloque (bucle `readStart()`/`writeStart()` o `app()`/`lapp()` con función vectorizada); álgebra encadenada de `terra` aceptable en memoria; **sin `cores > 1`** salvo benchmark favorable | Propuesta, respaldada por el micro-benchmark (§9); requiere que el autor revise `ARCHITECTURE.md` §6.2 (D-PP-09) |
| P-03 | Entre tareas: framework `future` mediante **`future.apply`** (no `furrr`) | Propuesta (§4.2) |
| P-04 | El paquete **nunca llama a `future::plan()`**; usa el plan del usuario | Propuesta (documentación de `future`, §4.3) |
| P-05 | `future.seed = TRUE` (o semilla explícita) en **toda** tarea paralela, use o no números aleatorios | Propuesta (§4.4, hallazgo §9.4) |
| P-06 | Las tareas reciben **rutas de archivo u objetos `wrap()`**, nunca `SpatRaster` vivos | Propuesta (hallazgo §3.5) |
| P-07 | Sin argumento `cores` en la API alta; `cores = 1L` solo en envoltorios de pasos por celda no vectorizables | Propuesta (§7.1) |
| P-08 | Envoltorios ráster con `filename = ""`, `overwrite = FALSE`, `wopt = list()` (convención de `terra`) | Propuesta (§7.2) |
| P-09 | Tamaño de bloque: `max_cells` solo en bucles por bloques propios (convención `thermify`); el resto lo gestiona `terra` | Propuesta (§7.3) |
| P-10 | Progreso con `progressr` (Suggests): el paquete solo **señala**; el usuario decide cómo mostrar | Propuesta (§4.5); decisión abierta D-PP-04 |
| P-11 | El plan de ejecución se registra en la procedencia | Propuesta (§8) |
| P-12 | Tests "secuencial = paralelo" y "tamaño de bloque no cambia el resultado", con ≤ 2 workers y fuera de CRAN | Propuesta (§6) |

---

## 1. Entorno y versiones observadas (2026-11-04)

| Elemento | Versión / valor | Fuente |
|---|---|---|
| R | 4.3.3 (Ubuntu 24.04.5 LTS, x86_64) | `sessionInfo()` |
| CPU / RAM | 4 núcleos lógicos (`parallel::detectCores()` = 4; `parallelly::availableCores()` = 4); 15 GB | Ejecución |
| GDAL / PROJ / GEOS | 3.8.4 / 9.4.0 / 3.12.1; TBB no disponible en este build de `terra` (`gdal(lib = "all")`) | Ejecución |
| `terra` | 1.9-50 (CRAN 2026-09-08; GPL ≥ 3) | Instalado desde CRAN; metadatos CRAN |
| `future` | 1.82.0 (CRAN 2026-11-02; Apache ≥ 2) | Instalado; metadatos CRAN |
| `future.apply` | 1.21.0 (CRAN 2026-10-16; GPL ≥ 2) | Instalado; metadatos CRAN |
| `furrr` | 0.4.0 (CRAN 2026-03-31; MIT) | Instalado; metadatos CRAN |
| `progressr` | 1.1.0 (CRAN 2026-10-18; Apache ≥ 2) | Instalado; metadatos CRAN |
| `parallelly` | 1.50.0 (CRAN 2026-10-31; LGPL ≥ 2.1) | Instalado; metadatos CRAN |
| Política CRAN | *CRAN Repository Policy*, revisión 6985 | `https://cran.r-project.org/web/packages/policies.html`, consultada 2026-11-04 |

Nota: la instalación de `terra` provista por el sistema (1.7-65) no era
legible con locale `C` (`packageVersion()` fallaba); se instaló 1.9-50 desde
CRAN en la biblioteca por defecto. Todos los resultados de este documento usan
1.9-50.

## 2. Dos niveles de paralelismo

| Nivel | Unidad de trabajo | Ejemplos en EarthFlux | Mecanismo propuesto | Riesgo principal |
|---|---|---|---|---|
| **Intra-escena** | Celdas o bloques de filas de una escena | Rn, G, H, LE, ET por píxel; corrección de estabilidad (rah); máscaras QA | Una pasada por bloque que aplica el núcleo numérico (bucle `readStart()`/`writeStart()`, o `app()`/`lapp()` con función vectorizada); álgebra encadenada de `terra` en memoria; **secuencial** | Sobrecosto de serialización mayor que el cálculo (§9) |
| **Entre tareas** | Unidades independientes y gruesas | Fechas/escenas; perfil de bandwidth GWR; validación cruzada (LOOCV o bloques espaciales); bootstrap de métricas; configuraciones C1–C3 | `future.apply::future_lapply()` con el plan del usuario | Memoria por worker; RNG; anidamiento con el nivel intra-escena |

Principio: **paralelizar donde la unidad de trabajo es gruesa** (segundos o
más por tarea) y la comunicación es pequeña (rutas, parámetros). El cálculo
por píxel de las ecuaciones METRIC es aritmética vectorizada; en el
micro-benchmark (§9) el paralelismo explícito sobre ella fue siempre más
lento que la versión secuencial.

---

## 3. Nivel intra-escena (`terra`)

### 3.1 Orden de preferencia

1. **Una pasada por bloque con el núcleo numérico**: el envoltorio lee cada
   bloque como matriz, llama a la función `ef_*()` numérica (una llamada por
   bloque, no por celda) y escribe el resultado. Formas equivalentes: bucle
   propio `readStart()`/`readValues()`/`writeStart()`/`writeValues()`/
   `writeStop()` (patrón de `thermify_rast()` y `engine.R`), o `app()` con
   una función que opere sobre la matriz del bloque, o `lapp()` con la
   función vectorizada. Ventajas: fue el camino secuencial más rápido con
   entradas en archivo (§9: 10,9–16,9 s frente a 31,3 s de la álgebra
   encadenada); las validaciones del núcleo (`check_numeric()`,
   `check_same_dim()`, ...) siguen operando sobre matrices sin adaptarse a
   `SpatRaster` (`specs/ef_net_radiation.md` §9, D6); varias salidas (Rn, G,
   H, ...) pueden escribirse en la misma pasada.
2. **Álgebra ráster encadenada** con las mismas funciones `ef_*()`
   aplicadas a `SpatRaster` (`ARCHITECTURE.md` §6.2): resultado idéntico y
   tiempo comparable en memoria (§9: 5,2 s), pero cada operador produce un
   ráster intermedio; con entradas en archivo fue 1,9–2,9 veces más lenta.
   Aceptable para escenas pequeñas, ejemplos y prototipos.
3. `cores > 1` en `lapp()`/`app()`/`tile_apply()` **solo** si un benchmark
   en `dev/bench/` demuestra ganancia para ese paso (P-02). Ninguna variante
   paralela fue más rápida que la mejor secuencial en §9.

Esta propuesta precisa la redacción de `ARCHITECTURE.md` §6.2 ("solo se usa
`terra::lapp()`/`terra::app()` cuando un cálculo no es expresable como
álgebra ráster"): el criterio pasa a ser de eficiencia y de reutilización de
las validaciones, no de expresabilidad. La decisión corresponde al autor
(D-PP-09).

### 3.2 Funciones de `terra` 1.9-50 con argumento `cores`

Según la documentación instalada (`?app`, `?lapp`, `?tapp`, `?predict`,
`?interpolate`, `?focal`, `?tile_apply`, `?sapp`):

| Función | Firma (extracto) | Semántica de `cores` | Observación ejecutada |
|---|---|---|---|
| `app()` | `app(x, fun, ..., cores=1, filename="", overwrite=FALSE, wopt=list())` | Entero > 1: crea un clúster de `parallel` con ese tamaño; o un objeto clúster. Ignorado para las funciones reimplementadas en C++ (`"sum"`, `"mean"`, `"min"`, `"max"`, etc.) | Con `cores = 1`, `fun` recibe la matriz del bloque si la acepta. Con `cores = 2`, una función escrita para matriz (`m[, 2]`) **falló** ("incorrect number of dimensions"): los workers la llaman por celda. La documentación advierte que la paralelización "is often not helpful, and it may actually be slower" |
| `lapp()` | `lapp(x, fun, ..., usenames=FALSE, cores=1, filename="", overwrite=FALSE, wopt=list())` | Igual que `app()`; "The benefit of using this option is often small, if it is even positive" | El código de 1.9-50 crea el clúster en cada llamada (`makeCluster()` + `on.exit(stopCluster())`), lee cada bloque como `data.frame`, lo divide por worker y usa `parLapply()` |
| `tapp()` | `tapp(x, index, fun, ..., cores=1, filename="", overwrite=FALSE, wopt=list())` | Igual que `app()` | No ejecutado |
| `predict()` | `predict(object, model, fun=predict, ..., cores=1, cpkgs=NULL, filename="", ...)` | Clúster de `parallel`; `cpkgs` carga paquetes en los nodos | No ejecutado. Relevante si una alternativa espacial (C2) se aplica como modelo sobre covariables ráster |
| `interpolate()` | `interpolate(object, model, ..., cores=1, cpkgs=NULL, ...)` | Igual que `predict()` | No ejecutado. Relevante para predicción espacial con modelos sobre coordenadas |
| `focal()` | `focal(x, w=3, fun="sum", ..., cores=1, cpkgs=NULL, ...)` | Solo para `fun` escrita en R: entero (workers PSOCK), clúster, la cadena `"future"` (plan registrado) o una estrategia de `future`. Las `fun` incorporadas ya son multihilo vía TBB e ignoran `cores` | No ejecutado. Relevante para criterios de homogeneidad de anclas |
| `tile_apply()` | `tile_apply(x, fun, cores=1, cpkgs=NULL, tiles=NULL, buffer=0, ..., filename="", overwrite=FALSE, wopt=list(), overlap_fun=NULL)` | Entero (PSOCK), clúster, `"future"` (usa `future_lapply()` con el plan activo) o un objeto de estrategia, **"which is set as the plan for the duration of the call"** | Ejecutado (§9). Con `filename = ""` devuelve un VRT cuyos archivos por tesela "are kept for the rest of the R session" |
| `sapp()` | `sapp(x, fun, ..., filename="", overwrite=FALSE, wopt=list())` | Sin `cores` | – |

Consecuencias para EarthFlux:

- `tile_apply(cores = <estrategia future>)` **cambia el plan** durante la
  llamada; EarthFlux no debe usar esa forma (P-04). Si alguna vez se usa
  `tile_apply()`, solo con `cores = "future"` (respeta el plan del usuario)
  y con `filename` explícito para no dejar archivos temporales sin dueño.
- En `app()`/`lapp()` 1.9-50 `cores` no acepta `"future"` (solo entero o
  clúster); un clúster creado por `terra` con `cores > 1` queda fuera del
  plan del usuario. Esta es otra razón para no exponer `cores` en la API
  alta (§7.1).

### 3.3 Paralelismo interno por hilos

`?terraOptions` (1.9-50) documenta:

- `parallel` (lógico): usa varios hilos mediante la biblioteca TBB "where
  that was implemented (including distance calculations on 'SpatVector' and
  some 'focal' computations)". En el build observado TBB no está
  disponible (`gdal(lib = "all")` → `TBB = FALSE`).
- `threads` (entero, por defecto 16): tope de hilos para el cómputo paralelo
  (`parallel = TRUE`), para el *warp* de GDAL (`project()`, `resample()` con
  `threads = TRUE`) y para la escritura de GeoTIFF comprimidos; "more
  threads rarely help as most parallel computations are limited by memory
  bandwidth".

Consecuencia: aun sin `cores`, algunas operaciones de `terra` (reproyección,
remuestreo, escritura comprimida, `focal` incorporado) pueden usar varios
hilos. En CRAN (≤ 2 núcleos) los ejemplos y tests que reproyecten o
escriban GeoTIFF comprimidos deberán fijar `threads` localmente o evitarlo.
`TODO (M4)`: comprobar empíricamente el número de hilos efectivos en
`project()`/`resample()` y en `writeRaster()` con compresión.

### 3.4 Procesamiento por bloques

Funciones documentadas en `?readStart` (1.9-50): `readStart()`,
`readStop()`, `readValues(x, row, nrows, col, ncols, mat = FALSE, ...)`,
`writeStart(x, filename = "", overwrite = FALSE, n = 4, sources = "", ...)`,
`writeValues(x, v, start, nrows)`, `writeStop()`, `blocks(x, n = 4)` y
`fileBlocksize()`.

- `writeStart()` devuelve la lista de bloques (`row`, `nrows`, `n`)
  calculada por `terra` según la memoria disponible y `n` ("how many copies
  the data may be in memory at any point in time").
- `blocks()` "only returns chunk size information. This can be useful when
  reading, but not writing".
- Observado: para un ráster de 5000 × 5000 × 5 capas con 15 GB de RAM,
  `blocks(r, n = 4)` devolvió **un único bloque** (`mem_info()`: 3,73 GB
  necesarios, 7,15 GB permitidos con `memfrac = 0.5`). Es decir, en equipos
  con memoria suficiente `terra` procesa todo en memoria y el tamaño de
  bloque no lo controla EarthFlux sino `terraOptions()`.
- Patrón obligatorio para un bucle propio (heredado de `thermify_rast()`):
  `readStart()` seguido de `on.exit(readStop(), add = TRUE)`;
  `writeStart()` con `wopt` explícito; escritura por bloque;
  `writeStop()`; registro de `n_blocks` y `max_cells` en la procedencia.
- El bucle por bloques es el camino preferido (§3.1): el bloque se pasa
  como matriz a una función `ef_*()` vectorizada (una llamada por bloque, no
  por celda), también para pasos iterativos vectorizados.

### 3.5 Objetos `SpatRaster` y procesos worker

Ejecutado con `future::plan(multisession, workers = 2)`:

| Caso | Resultado |
|---|---|
| `SpatRaster` en memoria usado como global en `future_sapply()` | **Error**: "NULL value passed as symbol address" |
| `SpatRaster` respaldado por archivo usado como global | **Error**: el mismo |
| `wrap()` en el proceso principal y `unwrap()` en el worker | Correcto |
| Pasar la **ruta** y llamar a `terra::rast()` en el worker | Correcto |
| `save()`/`load()` de un `SpatRaster` en un proceso nuevo | **Error**: el mismo |
| `saveRDS()`/`readRDS()` de un `SpatRaster` en un proceso nuevo | Correcto |

`?wrap`: "Packed objects can be passed over a connection that serializes
(e.g. to nodes on a computer cluster)"; con `proxy = FALSE` los valores se
fuerzan a memoria, con `proxy = TRUE` se guarda una referencia a los
archivos fuente.

Regla P-06: las tareas del nivel entre-tareas reciben **rutas de archivo**
(preferido: no copia valores) o, si el objeto está en memoria, un
`wrap()`. Para datos de ejemplo del paquete, rásteres en `inst/extdata`
leídos con `system.file()` (no `SpatRaster` en `.rda`; ver US-10).

### 3.6 `terraOptions()`: memoria, disco y temporales

Opciones documentadas relevantes (`?terraOptions`, 1.9-50): `memfrac`
(fracción de RAM, 0–0,9; por defecto observado 0,5), `memmin`, `memmax`
(GB), `tempdir` (por defecto `tempdir()`), `datatype` (por defecto
observado `"FLT4S"`), `todisk` ("For debugging"), `progress` (barra si el
número de bloques supera el valor; 0 la desactiva), `parallel`, `threads`.

Observaciones ejecutadas:

1. **Las opciones no se propagan a los workers**: con `memfrac = 0.3` en el
   proceso principal, `terraOptions()$memfrac` en dos workers
   `multisession` fue 0,5.
2. **Las opciones sí persisten dentro de un worker**: un `terraOptions()`
   ejecutado dentro de un *future* se mantuvo en el siguiente *future*
   resuelto por el mismo worker (mismo PID). Lo mismo ocurrió con
   `options()` de R. Un paquete que cambie opciones dentro de una tarea
   contamina tareas posteriores del usuario.
3. **Precisión en disco**: con `datatype` por defecto (`FLT4S`), los
   resultados escritos a disco o a archivos temporales difieren de los
   calculados en memoria (doble precisión): máx. |Δ| ≈ 3·10⁻⁵ W m⁻² para una
   escritura y ≈ 1,6–1,8·10⁻⁴ W m⁻² para álgebra encadenada con
   `todisk = TRUE` (intermedios redondeados a `float32`; §9). Con
   `wopt = list(datatype = "FLT8S")` los resultados fueron idénticos.
4. **Temporales**: con `todisk = TRUE` se crearon 9 (1000 × 1000) y 24
   (5000 × 5000) archivos temporales en la sesión;
   `tmpFiles(current = TRUE, orphan = TRUE, remove = TRUE)` los eliminó. `?tmpFiles`: se borran automáticamente al terminar una sesión
   que termina normalmente.

Reglas derivadas:

- EarthFlux **no modifica `terraOptions()` globales** (ni en el proceso
  principal ni en workers). Si un paso necesita una opción (p. ej.,
  `datatype`), la pasa por llamada (`wopt`). Si fuera inevitable cambiar
  una opción, se guarda y restaura con `on.exit()` en la misma función.
- **Memoria con workers**: cada worker `multisession` tiene su propio
  `memfrac` (0,5 por defecto) y cree disponer de la mitad de la RAM; con
  k workers el total puede superar la memoria física. La documentación de
  usuario recomendará fijar `memfrac`/`memmax` por worker (p. ej., en el
  `.Rprofile` del usuario o mediante un argumento explícito; decisión
  abierta D-PP-03) y el paquete registrará los valores efectivos.
- **Temporales propios**: los intermedios que EarthFlux escriba van a
  archivos con nombre explícito en un subdirectorio de `tempdir()` creado
  por la llamada y eliminado con `on.exit(unlink(dir, recursive = TRUE),
  add = TRUE)`. EarthFlux **no** llama a `tmpFiles(remove = TRUE)`: eliminaría
  también archivos temporales del usuario en la misma sesión.
- **Precisión**: los tests de equivalencia comparan resultados con el mismo
  tipo de almacenamiento, o fijan `datatype = "FLT8S"`. El tipo de dato por
  defecto de las salidas en disco es una decisión abierta (D-PP-05).

### 3.7 Cuándo basta la aritmética vectorizada

La aritmética vectorizada (núcleo numérico por bloque o álgebra ráster) es
suficiente, sin `app()` por celda ni paralelismo, cuando el paso:

1. es una expresión elemento a elemento sobre capas alineadas (todas las
   ecuaciones de Rn, G, H, LE, ET_inst, ETrF y ETa de `SCIENTIFIC_SPEC.md` §3);
2. tiene ramas expresables con máscaras (`ifel()`, combinación por máscara;
   `specs/soil-heat-flux.md` §5.3 ya exige evitar `ifelse()`);
3. es iterativo pero con el mismo número de iteraciones en todas las celdas,
   o con un criterio de parada global: cada iteración sigue siendo álgebra
   vectorizada sobre el bloque o la escena. **Hipótesis a medir** (B-04, §11): la
   corrección de estabilidad de Monin-Obukhov para rah puede escribirse así
   en lugar de una iteración por píxel.

Una función R **por celda** (p. ej., un solucionador de raíces por píxel
llamado celda a celda) solo se justifica si no hay forma vectorizada: en §9
`app()` con función por celda tardó 14,2 s por 10⁶ celdas, frente a 0,10 s
de la álgebra (unas 140 veces más). Solo en ese caso se evalúa
`cores > 1` o código compilado que trabaje sobre la matriz del bloque.

---

## 4. Nivel entre tareas (`future`)

### 4.1 Candidatos (metadatos CRAN al 2026-11-04)

| Paquete | Versión (publicación) | Licencia | Mantenimiento | Imports directos | Dependencias fuertes recursivas | Dependientes inversos fuertes (CRAN) |
|---|---|---|---|---|---|---|
| `future.apply` | 1.21.0 (2026-10-16) | GPL (≥ 2) | Mismo mantenedor que `future`, `parallelly` y `progressr` | Depends `future (≥ 1.80.0)`; Imports `globals`, `parallel`, `stats`, `utils` | 9: future, globals, parallel, stats, utils, listenv, parallelly, tools, codetools | 214 |
| `furrr` | 0.4.0 (2026-03-31) | MIT | Mantenedor distinto, mismo ecosistema (`BugReports` en futureverse) | Depends `future (≥ 1.70.0)`; Imports `globals`, `purrr (≥ 1.2.1)`, `rlang`, `vctrs` | 16: las anteriores salvo stats + purrr, rlang, vctrs, cli, lifecycle, magrittr, glue, methods | 131 |
| `doFuture` | 1.4.0 (2026-10-05) | Apache (≥ 2) | Mismo mantenedor que `future` | Depends `foreach`, `future`; Imports `future.apply`, ... | Incluye `future.apply` y `foreach`/`iterators` | No evaluado |
| `mirai` | 2.7.4 (2026-11-02) | MIT | Independiente de `future` | `nanonext` | No evaluado | No evaluado |
| `parallel` (base R) | R 4.3.3 | Parte de R | R Core | – | – | – |

Fuente: `tools::CRAN_package_db()` y `tools::package_dependencies()`
(`which = c("Depends", "Imports", "LinkingTo")`). `doFuture` y `mirai` se
listan por completitud y no se evalúan más: `doFuture` añade `foreach`
sobre `future.apply`; `mirai` es un backend alternativo que el usuario
puede usar a través de `future` (`?plan` documenta
`future.mirai::mirai_multisession`), sin que EarthFlux dependa de él.

### 4.2 Recomendación: `future.apply`

Ambos paquetes documentan la misma semántica de RNG paralelo
(`future.seed` / `furrr_options(seed =)`: semillas L'Ecuyer-CMRG
pregeneradas por elemento, resultado independiente del backend y del
*chunking*) y ambos son del ecosistema `future`. Se recomienda
**`future.apply`** porque:

1. **Peso de dependencias**: 9 dependencias recursivas, todas de R base o
   del propio ecosistema `future`, frente a 16 en `furrr` (añade la pila
   `purrr`/`rlang`/`vctrs`/`cli`/`lifecycle`/`magrittr`/`glue`)
   (`DEVELOPMENT.md` §4).
2. **Estilo**: interfaz equivalente a `lapply()`/`vapply()`, coherente con
   el estilo base-R de `thermify` y del núcleo `ef_*()`.
3. **Mantenimiento**: publicación más reciente (2026-10-16), mismo
   mantenedor que `future`, `parallelly` y `progressr`, y más dependientes
   inversos fuertes (214 frente a 131).
4. **Licencia**: GPL (≥ 2). Declararlo en `Imports` desde un paquete MIT es
   aceptable siempre que no se copie su código (`ARCHITECTURE.md` §6.1).
   `furrr` (MIT) no ofrece una ventaja funcional que compense el peso
   adicional.

`Imports` vs. `Suggests`: se propone `Imports` para `future.apply` (y
`future`, si se llama a `future::nbrOfWorkers()` para la procedencia) con la
**primera** función que paralelice entre tareas (`ARCHITECTURE.md` §6.3,
regla 5). Motivo: con `Suggests` y un camino alternativo `lapply()`, los
pasos con números aleatorios darían resultados distintos según esté o no
instalado el paquete (las semillas por elemento de `future.seed` no
coinciden con las de una secuencia `lapply()`), lo que rompe P-05 y US-08.
`progressr` iría en `Suggests` (§4.5). **No se modifica `DESCRIPTION` en
este documento.**

### 4.3 El plan pertenece al usuario

`?future::plan` (1.82.0), sección *For package developers*: "Please refrain
from modifying the future backend inside your packages / functions, i.e. do
not call 'plan()' in your code. Instead, leave the control on what backend
to use to the end user." Si fuera necesario, el patrón documentado para
restaurar es `with(plan(...), local = TRUE)`.

Reglas:

- EarthFlux no llama a `plan()`. Sin plan del usuario, `future` resuelve en
  forma secuencial (P-01). Verificado: una función que usa
  `future_lapply()` deja el plan del usuario sin cambios.
- `with(plan(...), local = TRUE)` no se usa en el paquete; solo se menciona
  porque es el único patrón aceptable si un caso futuro lo exigiera
  (verificado: restaura un plan `multisession` de 2 workers al salir).
- Los ejemplos, vignettes y tests que muestren paralelismo llaman a `plan()`
  al comienzo y restauran el plan previo (`plan()` devuelve el plan anterior
  de forma invisible cuando se fija uno nuevo, según `?plan`).
- `multicore` (fork) "is not supported on Windows" (`?plan`); la
  documentación de EarthFlux recomendará `multisession`.

### 4.4 Números aleatorios reproducibles

`?future_lapply` (1.21.0): "Unless 'future.seed' is 'FALSE' or 'NULL', this
function guarantees to generate the exact same sequence of random numbers
given the same initial seed / RNG state - this regardless of type of
futures, scheduling ('chunking') strategy, and number of workers."
Con `future.seed = FALSE`, si `FUN` usa números aleatorios "an informative
warning or error is produced"; con `NULL` no se comprueba.

Ejecutado (§9.4): `future_sapply(..., future.seed = 42L)` dio resultados
idénticos en secuencial, en `multisession` con 2 workers y con
`future.chunk.size = 1`; con `future.seed = FALSE` y uso de RNG se emitió
`RngFutureWarning`. Además, **cargar `terra` por primera vez en un worker
nuevo emitió `RngFutureWarning`** con `future.seed = FALSE` (causa no
investigada; en el proceso principal `loadNamespace("terra")` no alteró
`.Random.seed`).

Reglas (P-05):

- Toda llamada a `future_lapply()` del paquete usa `future.seed = TRUE` o
  una semilla entera derivada del argumento `seed` del usuario; nunca
  `FALSE`/`NULL`. El costo de pregenerar semillas es despreciable para
  decenas o cientos de tareas.
- Una semilla del usuario (`seed`) se registra en la procedencia; si es
  `NULL`, se registra la semilla efectiva usada.
- El bootstrap y la CV que muestreen al azar (`VALIDATION_PLAN.md` §2.3)
  generan sus índices **dentro** de la tarea con la semilla de la tarea, de
  modo que el resultado no dependa del orden de ejecución.

### 4.5 Progreso

`?progressr::with_progress` (1.1.0): "This function is meant for end users
only. It should not be used by R packages, whose only task is to signal
progress updates, not to decide if, when, and how progress should be
reported." `progressr` funciona con `future.apply::future_lapply()` (`?progressr`).
Sus dependencias son solo `tools` y `utils` (metadatos CRAN).

Propuesta (P-10): `progressr` en `Suggests`; dentro del paquete, si está
instalado, se crea un `progressr::progressor()` y se señala un paso por
tarea o por bloque; el usuario envuelve la llamada en `with_progress()` o
activa `handlers(global = TRUE)`. Sin `progressr`, no se informa progreso.
Decisión abierta D-PP-04: unificar con el sistema de progreso propio de
`thermify` (`progress.R`) o adoptar solo `progressr`.

### 4.6 Globals y tamaño de los datos enviados

- `future.apply` identifica y exporta los globals de `FUN`; argumentos
  adicionales se pasan por `...` (el ejemplo de `?future_lapply` advierte no
  usar `...` como global).
- Observado (§9.3): enviar 5 vectores de 25·10⁶ dobles (≈ 1 GB) a 2 workers
  funcionó con la configuración por defecto (`getOption(
  "future.globals.maxSize")` devolvió `Inf` en esta sesión), pero el envío
  dominó el tiempo (6,1 s frente a 0,5 s del cálculo vectorizado). Regla:
  las tareas reciben rutas y parámetros pequeños; cada worker lee su propia
  escena.
- El paquete no modifica `future.globals.maxSize` (opción del usuario).

### 4.7 Anidamiento

Paralelizar fechas con k workers y, dentro de cada fecha, usar
`terra::lapp(cores = m)` crearía k × m procesos y violaría el límite de
CRAN. Regla: cuando el nivel entre tareas se ejecuta en paralelo, los pasos
intra-escena usan `cores = 1`. `TODO (M5)`: verificar en la documentación
de `future` el comportamiento de los planes anidados (por defecto, qué plan
ven los workers) antes de fijar cómo se detecta.

---

## 5. Reglas

1. **Secuencial por defecto** (P-01): sin acción del usuario, ningún paso
   crea procesos ni hilos adicionales a los que use `terra` internamente.
2. **Resultados idénticos** en secuencial y en paralelo, para cualquier
   número de workers, *chunking* y tamaño de bloque (P-12; diseño en §6).
3. **El plan es del usuario** (P-04): el paquete no llama a `plan()` ni cambia
   `terraOptions()` u `options()` globales.
4. **Sin `parallel::mclapply()`** como mecanismo principal:
   `?parallel::mclapply` indica que "relies on forking and hence is not
   available on Windows unless 'mc.cores = 1'".
5. **Sin `parallel::detectCores()` a ciegas**: su documentación indica que
   "is not suitable for use directly for the 'mc.cores' argument of
   'mclapply' nor specifying the number of cores in 'makeCluster'" (puede
   devolver `NA` y no da el número de núcleos *permitidos*). Si alguna vez
   se necesita un número de núcleos, `parallelly::availableCores()`, que
   respeta cgroups, `mc.cores`, planificadores HPC y
   `_R_CHECK_LIMIT_CORES_` (ver §6.2). En la práctica el paquete no necesita
   conocer el número de núcleos: lo define el plan del usuario.
6. **CRAN**: ejemplos, tests y vignettes con como máximo 2 núcleos
   simultáneos y secuenciales por defecto (`DEVELOPMENT.md` §5).
7. **Datos a workers**: rutas o `wrap()`, nunca `SpatRaster` vivos (P-06).
8. **Semillas**: `future.seed` siempre activo (P-05).
9. **Memoria**: ninguna tarea carga más de una escena completa a la vez; los
   pasos sobre escenas grandes escriben a disco (`filename`) en lugar de
   devolver todo en memoria; la documentación indicará cómo repartir
   `memfrac`/`memmax` entre workers (§3.6).
10. **Temporales**: archivos propios con nombre explícito en un directorio
    de la llamada, eliminados con `on.exit()`, también si hay error.
11. **Medir antes de paralelizar** (`ARCHITECTURE.md` §6.3, regla 6): ningún
    paso recibe `cores` o paralelización entre tareas sin un benchmark en
    `dev/bench/` (§11) que muestre ganancia.
12. **Procedencia**: el plan de ejecución efectivo se registra (§8).

---

## 6. CRAN y diseño de tests

### 6.1 Política

*CRAN Repository Policy* (rev. 6985, consultada 2026-11-04): "If running a
package uses multiple threads/cores it must never use more than two
simultaneously: the check farm is a shared resource and will typically be
running many checks simultaneously." También: "Examples should run for no
more than a few seconds each" y los paquetes no deben escribir "anywhere
else on the file system apart from the R session's temporary directory".

### 6.2 `_R_CHECK_LIMIT_CORES_` (ejecutado)

- `?parallelly::availableCores` (1.50.0): la variable es usada por
  `R CMD check` y "set to true by R CMD check --as-cran"; si tiene un valor
  no falso, "a maximum of 2 cores is considered". Observado: con
  `_R_CHECK_LIMIT_CORES_=TRUE`, `availableCores()` devolvió 2 (4 sin ella).
- En R 4.3.3, la función interna `parallel:::.check_ncores()` produce un
  **error** "N simultaneous processes spawned" si la variable está activa y
  se piden más de 2 procesos (con valor `"warn"`, un warning). Observado:
  `parallel::makeCluster(3)`, `parallel::mclapply(..., mc.cores = 4)` y
  `terra::lapp(..., cores = 3)` fallaron; `terra::lapp(..., cores = 2)` no.

### 6.3 Tests de equivalencia (diseño)

| Test | Archivo propuesto | Qué verifica | Grupo |
|---|---|---|---|
| Bloques | `test-parallel.R` | Un envoltorio ráster da valores idénticos con `max_cells` pequeño (varios bloques) y grande (uno) | Siempre (ráster pequeño) |
| Álgebra vs. núcleo | `test-parallel.R` | `ef_*()` sobre `SpatRaster` ≡ `ef_*()` sobre `values()` como `numeric` | Siempre |
| Secuencial vs. `multisession` | `test-parallel.R`, `test-story-06.R` | Resultados por fecha idénticos con `plan(sequential)` y `plan(multisession, workers = 2)`, incluidos pasos con RNG | `skip_on_cran()`; `skip_if_not_installed("future.apply")` |
| Chunking | `test-parallel.R` | `future.chunk.size = 1` vs. por defecto: idéntico | Igual que el anterior |
| Plan intacto | `test-parallel.R` | `plan()` antes y después de la llamada es el mismo, también tras un error | Siempre (con `plan(sequential)`) |
| Opciones intactas | `test-parallel.R` | `terraOptions()` y `options()` relevantes iguales antes y después | Siempre |
| `cores` en `terra` | `test-parallel.R` | `cores = 1` vs. `cores = 2` idénticos en los envoltorios que lo exponen | `skip_on_cran()` |
| Temporales | `test-parallel.R` | El directorio temporal de la llamada no existe al terminar, también si la llamada falla | Siempre |

Detalles:

- Comparación con `expect_identical()` sobre `terra::values()` cuando ambos
  caminos usan el mismo almacenamiento; si uno escribe a disco, fijar
  `wopt = list(datatype = "FLT8S")` (hallazgo §3.6). Una tolerancia solo se
  admite con justificación escrita (`VALIDATION_PLAN.md` §1.2).
- Patrón de plan en tests:
  `oplan <- future::plan(future::multisession, workers = 2)` y
  `on.exit(future::plan(oplan), add = TRUE)` (o `withr::defer()` si `withr`
  llega a `Suggests`; no evaluado).
- Nunca más de 2 workers; los tests paralelos se omiten en CRAN, como en
  `thermify` (`NOT_CRAN`), y pueden agruparse bajo `EARTHFLUX_SLOW_TESTS`.

---

## 7. Convenciones de API propuestas

### 7.1 `cores` vs. plan de `future`

| Opción | Ventajas | Desventajas |
|---|---|---|
| A. Argumento `cores` en todas las funciones, pasado a `terra` | Familiar para usuarios de `terra` | `terra` crea su propio clúster PSOCK en cada llamada, fuera del plan del usuario; en §9 `lapp()`/`app()` con `cores = 2` fueron 2,4–7 veces más lentos que con `cores = 1`; riesgo de anidamiento (§4.7) |
| B. Solo el plan de `future` para todo | Un único control; respeta al usuario; funciona en clústeres/HPC sin cambios | `app()`/`lapp()` 1.9-50 no aceptan `"future"`; solo `focal()` y `tile_apply()` |
| **C. Plan de `future` entre tareas + `cores = 1L` solo en envoltorios de pasos por celda no vectorizables** | Control claro por nivel; la API alta no expone `cores`; los pasos que lo necesiten pueden ganarlo con benchmark | Dos mecanismos que documentar |

Propuesta (P-07): **opción C**.

- `earthflux()` y las funciones multifecha no tienen argumento `cores` ni
  `workers`: el paralelismo entre tareas lo define `future::plan()`. Se
  documenta en una sección roxygen `@section Parallel processing:`.
- Los envoltorios ráster de pasos vectorizados (todos los previstos hoy) no
  tienen `cores`.
- Un envoltorio de paso por celda no vectorizable (si existe tras B-04) puede
  exponer `cores = 1L` (entero positivo validado, o clúster), pasado a
  `terra`. La orquestación lo fija en 1 cuando el nivel entre tareas es
  paralelo.

### 7.2 Salidas en disco

Convención de `terra` (`app()`, `lapp()`, `predict()`): `filename = ""`,
`overwrite = FALSE`, `wopt = list()`.

- `filename = ""`: resultado en memoria si cabe (decisión de `terra`).
- Con `filename`, el objeto devuelto apunta al archivo; `overwrite = FALSE`
  produce un error con clase si existe.
- `wopt` se pasa intacto a `terra`; el paquete no fija `datatype` salvo
  decisión D-PP-05. Varias capas (Rn, G, H, ...) en un directorio de salida:
  `output_dir`, un archivo por capa y un archivo de procedencia (patrón de
  `thermify_rast()`).

### 7.3 Tamaño de bloque

- Bucle por bloques propio (camino preferido, §3.1 y §3.4): argumento
  `max_cells` (convención de `thermify_rast()`); con `max_cells = NULL` se
  usan los bloques que propone `writeStart()` según `memfrac`/`memmax`. El
  valor por defecto se fijará con B-02. Se registran `max_cells` y
  `n_blocks` (US-11).
- Envoltorios basados en álgebra, `app()` o `lapp()`: el tamaño lo decide
  `terra` según `terraOptions()` del usuario; EarthFlux no expone un
  argumento y registra los valores efectivos.

### 7.4 Semilla y progreso

- `seed = NULL` en funciones con pasos aleatorios (bootstrap, CV por
  bloques); se pasa a `future.seed` y se registra.
- Progreso: sin argumento propio si se adopta `progressr` (el usuario lo
  controla); si se adopta el patrón de `thermify`,
  `progress = getOption("earthflux.progress", interactive())`
  (D-PP-04).

## 8. Procedencia del plan de ejecución

Campos propuestos dentro de la procedencia de `earthflux_result`
(`DEVELOPMENT.md` §7; `USER_STORIES.md` US-08):

| Campo | Contenido | Obtención |
|---|---|---|
| `execution$tasks$backend` | Clases del plan activo (p. ej., `"sequential"`, `"multisession"`) | `class(future::plan())` |
| `execution$tasks$workers` | Número de workers del plan | `future::nbrOfWorkers()` |
| `execution$tasks$future_versions` | Versiones de `future` y `future.apply` | `utils::packageVersion()` |
| `execution$tasks$seed` | Semilla inicial y tipo de RNG (`RNGkind()`) | Argumento `seed` / semilla efectiva |
| `execution$tasks$n_tasks` | Número de tareas y su identificador (fechas) | Orquestación |
| `execution$intra$cores` | `cores` usado por paso (1 si no aplica) | Argumentos |
| `execution$intra$max_cells`, `n_blocks` | Solo en bucles propios | Bucle |
| `execution$intra$terra_options` | `memfrac`, `memmax`, `todisk`, `datatype`, `threads`, `parallel` efectivos | `terra::terraOptions(print = FALSE)` |
| `execution$intra$wopt` | Opciones de escritura usadas | Argumentos |
| `execution$elapsed_seconds` | Tiempo total y por tarea | `proc.time()` |

No se registran nombre de equipo, usuario ni rutas absolutas (US-08,
criterio 5).

---

## 9. Micro-benchmark empírico (2026-11-04)

### 9.1 Diseño

- Ecuación: Rn = (1 − α)·Rs↓ + RL↓ − RL↑ − (1 − ε₀)·RL↓
  (`specs/ef_net_radiation.md` §2.1), sin validaciones (solo aritmética).
- Entradas sintéticas: 5 capas de **5000 × 5000** celdas (25·10⁶ celdas por
  capa), valores uniformes en rangos plausibles, `set.seed(1)`, doble
  precisión, CRS EPSG:32719.
- Escenarios: (1) entradas en memoria, salida en memoria; (2) entradas en
  GeoTIFF `FLT8S`, salida a GeoTIFF `FLT8S`; (3) `terraOptions(todisk =
  TRUE)`.
- Métodos: álgebra ráster; `lapp()`; `app()` con función matricial;
  `app()` con función por celda (solo en un subconjunto de 1000 × 1000 por
  su costo); bucle propio por bloques; `tile_apply()`.
- Dos corridas: **completa** (todos los métodos; mediana de 3 repeticiones,
  `[1 rep]` en los métodos lentos; 06:37–07:05 UTC) y **limpia** (solo los
  métodos secuenciales rápidos; mediana de 5 repeticiones; 07:25–07:35 UTC,
  carga media inicial 0,43). Tiempo transcurrido con `system.time()`. Igualdad:
  `identical()` de `values()` contra la álgebra en memoria.
- Equipo compartido: durante parte de la corrida completa corrieron otros
  procesos (carga media registrada en las salidas); las cifras indican
  órdenes de magnitud y rangos, no valores de referencia.
- Scripts y salidas: aún no versionados; se trasladarán a `dev/bench/`
  como B-01 (§11).

### 9.2 Resultados `terra`

Tiempos en segundos. "–": no medido en esa corrida.

| Escenario | Método | Limpia (mediana de 5) | Completa (mediana de 3) | ¿Idéntico a la álgebra en memoria? |
|---|---|---|---|---|
| Memoria | Álgebra ráster (expresión directa) | 5,25 | 4,75 | Referencia |
| Memoria | Álgebra con la función estilo `ef_*()` sobre `SpatRaster` | 5,24 | 8,06 ¹ | Sí |
| Memoria | `lapp(cores = 1)` | 7,52 | 8,89 | Sí |
| Memoria | `lapp(cores = 2)` | – | 62,38 [1 rep] | Sí |
| Memoria | `app()` con función matricial, `cores = 1` | 5,17 | 4,26 | Sí |
| Memoria | `app()` con función matricial, `cores = 2` | – | Error ("incorrect number of dimensions") | – |
| Memoria | Bucle por bloques, bloques de `writeStart()` (1 bloque) | 5,24 | 4,14 | Sí |
| Memoria | Bucle por bloques, 500 filas (10 bloques) | 4,70 | 2,88 | Sí |
| Memoria | Bucle por bloques, 100 filas (50 bloques) | 3,56 | – | Sí |
| Memoria | Núcleo numérico sobre vectores ya extraídos + `setValues()` ² | 0,78 | – | Sí |
| Memoria | `tile_apply(cores = 1)`, `wopt` `FLT8S` | – | 29,44 | Sí |
| Memoria | `tile_apply(cores = 1)`, `wopt` por defecto | – | 27,43 | No: máx. \|Δ\| = 3,05·10⁻⁵ |
| Memoria | `tile_apply(cores = 2)`, `FLT8S` | – | 24,68 [1 rep] | Sí |
| Memoria | `tile_apply(cores = "future")`, `plan(multisession, workers = 2)` del usuario | – | 654,22 [1 rep] | Sí |
| Memoria, 1000 × 1000 | `app()` con función **por celda**, `cores = 1` | – | 14,21 [1 rep] | Sí |
| Memoria, 1000 × 1000 | `app()` con función por celda, `cores = 2` | – | 34,03 [1 rep] | Sí |
| Memoria, 1000 × 1000 | Álgebra ráster | – | 0,10 [1 rep] | Referencia del subconjunto |
| Archivo | Álgebra + `writeRaster()` | 31,29 | 27,41 | Sí |
| Archivo | `lapp(cores = 1, filename)` | 16,89 | 15,85 | Sí |
| Archivo | `lapp(cores = 2, filename)` | – | 73,72 [1 rep] | Sí |
| Archivo | `app()` con función matricial, `cores = 1`, `filename` | 12,26 | – | Sí |
| Archivo | Bucle por bloques, 500 filas, a archivo | 10,87 | 8,73 | Sí |
| `todisk = TRUE` | Álgebra (intermedios en temporales) | – | 33,16 | No: máx. \|Δ\| = 1,75·10⁻⁴ |
| `todisk = TRUE` | `lapp(cores = 1)` | – | 16,88 | No: máx. \|Δ\| = 3,05·10⁻⁵ |

¹ Valor afectado por procesos concurrentes; en la corrida limpia ambas
formas de álgebra tardaron lo mismo.
² Sin contar la extracción de `values()`, que se hizo fuera del cronómetro;
indica el costo de la aritmética pura en R, no un camino completo.

Otros datos: crear y detener un clúster PSOCK de 2 workers tomó 0,18 s; con
`todisk = TRUE` quedaron 24 archivos temporales, eliminados con
`tmpFiles(remove = TRUE)`. En una corrida previa de prueba a 1000 × 1000,
`lapp(cores = 2)` tardó 12,6 s frente a 0,47 s con `cores = 1`.

### 9.3 Resultados sobre vectores numéricos (`future.apply`)

Misma ecuación sobre 25·10⁶ dobles por argumento (sin `terra`); mediana de
3 repeticiones; segunda corrida con el equipo en reposo (primera corrida,
con carga concurrente, entre paréntesis):

| Método | Tiempo (s) | ¿Idéntico? |
|---|---|---|
| Vectorizado (una llamada) | 0,50 (0,47 en la primera corrida) | Referencia |
| `future_lapply()` en 4 trozos, `plan(sequential)` | 3,93 (5,54) | Sí (`identical()`) |
| `future_lapply()` en 2 trozos, `plan(multisession, workers = 2)` | 6,12 (9,74) | Sí (`identical()`) |

### 9.4 Reproducibilidad del RNG (`future.apply`)

| Caso | Resultado |
|---|---|
| `future_sapply(1:20, <muestreo>, future.seed = 42L)`: secuencial vs. `multisession` (2) | Idéntico |
| Lo mismo con `future.chunk.size = 1` | Idéntico |
| `future.seed = FALSE` con uso de RNG | `RngFutureWarning` |
| Primera carga de `terra` en un worker con `future.seed = FALSE` | `RngFutureWarning` |

### 9.5 Conclusiones

1. **El paralelismo intra-escena no compensó en ningún caso.**
   `lapp(cores = 2)` fue unas 7 veces más lento que `cores = 1` en memoria
   (62,4 frente a 8,9 s) y 4,6 veces más lento con archivos (73,7 frente a
   15,9 s); `app()` por celda fue 2,4 veces más lento con `cores = 2`; una
   función matricial no sirve con `cores > 1` porque los workers la llaman
   por celda; `tile_apply(cores = 2)` mejoró un 16 % frente a
   `tile_apply(cores = 1)`, pero siguió siendo unas 5 veces más lento que la
   álgebra; `tile_apply(cores = "future")` con un ráster en memoria tardó
   unas 140 veces más que la álgebra (654 frente a 4,75 s). El arranque del clúster (0,18 s) no explica
   la diferencia, que es coherente con el costo de dividir, serializar y
   reensamblar bloques frente a una aritmética muy barata.
2. **Las funciones R por celda son prohibitivas**: unas 140 veces más lentas
   que la álgebra (14,2 frente a 0,10 s por 10⁶ celdas). Extrapolación no
   medida: unos 6 minutos para 25·10⁶ celdas.
3. **Entre los caminos secuenciales**, en memoria todos quedaron entre 3,6 y
   7,5 s; con entradas en archivo, las variantes de una sola pasada (bucle
   por bloques 10,9 s; `app()` matricial 12,3 s; `lapp()` 16,9 s) fueron
   1,9–2,9 veces más rápidas que la álgebra encadenada con `writeRaster()`
   (31,3 s). La expectativa inicial ("la álgebra ráster es lo más rápido")
   **solo se confirma en parte**: es comparable en memoria y más lenta con
   archivos. De ahí la revisión de P-02 (§3.1).
4. **La aritmética en sí es barata**: 0,5–0,8 s para 25·10⁶ celdas en R; el
   costo dominante está en la gestión ráster y la E/S. Optimizar la ecuación
   no es prioritario; sí lo es minimizar pasadas sobre disco.
5. **Entre tareas, la granularidad fina no compensa**: dividir la misma
   aritmética en trozos para 2 workers fue unas 12 veces más lento que el
   cálculo vectorizado (6,1 frente a 0,5 s), por el envío de datos. El nivel
   entre tareas solo tiene sentido con tareas gruesas que lean sus propios
   datos (fechas, pliegues de CV); su ganancia está por medir (B-03, B-05).
6. **Equivalencia exacta factible**: todas las variantes, paralelas o por
   bloques, dieron valores idénticos con almacenamiento en doble precisión;
   las diferencias observadas se deben solo a `FLT4S`. Los tests de §6.3
   pueden usar `expect_identical()`.
7. **Límites**: una sola ecuación barata, un equipo de 4 núcleos sin TBB y
   carga compartida. Pasos más costosos por celda (B-04) o equipos con más
   núcleos podrían cambiar la conclusión para el nivel intra-escena; por eso
   la regla 11 (§5) exige un benchmark por paso.

---

## 10. Decisiones abiertas

| ID | Decisión | Opciones | Recomendación provisional | Bloquea |
|---|---|---|---|---|
| D-PP-01 | Paquete entre tareas | `future.apply` / `furrr` | `future.apply` en `Imports` con la primera función que lo use (§4.2) | M3 (CV de GWR) o M5 (multifecha) |
| D-PP-02 | Fallo parcial en multifecha | Abortar todo / continuar y registrar la fecha fallida con su condición | Continuar y registrar, con argumento explícito; confirmar con US-06 | M5 |
| D-PP-03 | Memoria por worker | Solo documentación / argumento `memfrac` por tarea aplicado y restaurado en el worker | Documentación + registro de valores efectivos; reevaluar con B-03 | M5 |
| D-PP-04 | Progreso | `progressr` (Suggests) / sistema propio de `thermify` / ambos | `progressr` para todo | M5 |
| D-PP-05 | `datatype` por defecto en salidas a disco | `FLT4S` (por defecto de `terra`) / `FLT8S` | Evaluar tamaño vs. precisión con B-02; documentar la diferencia (§3.6) | M2 |
| D-PP-06 | `cores` en pasos por celda no vectorizables | Exponer `cores` / solo plan de `future` (vía `tile_apply(cores = "future")`) | Decidir tras B-04 | M2 |
| D-PP-07 | Detección de anidamiento | Consultar `future::nbrOfWorkers()` / plan anidado de `future` | `TODO (M5)`: verificar documentación de planes anidados | M5 |
| D-PP-08 | Uso de `tile_apply()` | No usar / usar con `cores = "future"` y `filename` explícito | No usar (§9: más lento que la álgebra en todas las variantes) | – |
| D-PP-09 | Envoltorio ráster de las funciones `ef_*()` | (a) despacho de `ef_*()` sobre `SpatRaster` mediante álgebra (`ARCHITECTURE.md` §6.2 actual); (b) envoltorio por bloques que llama al núcleo numérico; (c) ambos, con (b) en la orquestación | (c): (b) para `earthflux()` y escenas en disco; (a) opcional para uso interactivo. Errores de dominio dentro de un bloque: decidir si se informa el conteo del bloque o se valida toda la escena antes de escribir | M2 |

## 11. Plan de benchmarks (`dev/bench/`, fuera del tarball)

`dev/` ya está excluido del tarball (`.Rbuildignore`: `^dev$`). Estructura
propuesta (solo descripción; no se crea en este documento):

```text
dev/bench/
├── README.md            # cómo correr, requisitos, interpretación
├── _setup.R             # datos sintéticos reproducibles (semilla fija)
├── B-01-rn-intra.R      # este micro-benchmark (§9), parametrizado por tamaño
├── B-02-blocks.R        # max_cells y datatype: tiempo, memoria, tamaño en disco
├── B-03-multidate.R     # n fechas × {sequential, multisession 2, 4}: tiempo y memoria pico
├── B-04-stability.R     # rah/Monin-Obukhov: álgebra iterativa vs. lapp/app por bloque vs. cores
├── B-05-gwr-cv.R        # perfil de bandwidth y CV de GWR: secuencial vs. future_lapply
└── results/             # salidas CSV con fecha, equipo (núcleos, RAM), versiones y carga media
```

Reglas:

- Cada script imprime versiones de R, `terra`, GDAL, `future`,
  `future.apply`, número de núcleos y RAM, fecha UTC y carga media al
  inicio y al final.
- Mediana de al menos 3 repeticiones; los métodos lentos pueden usar 1
  repetición marcada como tal.
- Todo resultado incluye la comprobación de igualdad con la referencia
  secuencial.
- Ningún benchmark corre en `R CMD check` ni en CI por defecto; un workflow
  manual (`workflow_dispatch`) puede ejecutarlos y adjuntar `results/`.
- Una decisión de paralelizar un paso cita el benchmark y su resultado en
  `ARCHITECTURE.md` §6.3.

## 12. Documentación consultada

| Documento | Paquete y versión |
|---|---|
| `?app`, `?lapp`, `?tapp`, `?sapp`, `?predict`, `?interpolate`, `?focal`, `?tile_apply`, `?readStart` (bloques), `?wrap`, `?terraOptions`, `?tmpFiles`, `?mem_info` | `terra` 1.9-50 |
| `?plan`, `?nbrOfWorkers` | `future` 1.82.0 |
| `?future_lapply` | `future.apply` 1.21.0 |
| `?future_map`, `?furrr_options` | `furrr` 0.4.0 |
| `?progressr`, `?with_progress`, `?progressor` | `progressr` 1.1.0 |
| `?availableCores` | `parallelly` 1.50.0 |
| `?detectCores`, `?mclapply`, `parallel:::.check_ncores` | `parallel` (R 4.3.3) |
| *CRAN Repository Policy* rev. 6985 | CRAN, consultada 2026-11-04 |
| `tools::CRAN_package_db()` | CRAN, consultada 2026-11-04 |
| `R/thermify_rast.R`, `R/engine.R`, `docs/USER_STORIES.md`, `docs/TESTING.md` | `thermify` 0.3.1 (patrones de la casa) |
