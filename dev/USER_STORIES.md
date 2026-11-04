# EarthFlux — Historias de usuario

Estado: **borrador M1** · Complementa `ARCHITECTURE.md`, `VALIDATION_PLAN.md`
y `specs/parallel-processing.md`. Formato heredado de `thermify`
(`docs/USER_STORIES.md`, convención de la casa, `ARCHITECTURE.md` §6.6).

Cada historia tendrá un test de aceptación en
`tests/testthat/test-story-<id>.R`. Una historia está terminada cuando sus
criterios de aceptación pasan en `devtools::test()` (y en
`R CMD check --as-cran` para los que no dependen de grupos opcionales).

> **Estado actual.** Ningún test de aceptación existe todavía. Las historias
> describen comportamiento esperado, **no resultados**: no se afirma que
> EarthFlux cumpla ninguno de estos criterios ni que una configuración
> (C1, C2, C3) sea mejor que otra (`SCIENTIFIC_SPEC.md` §1.1). Los nombres de
> funciones distintos de `ef_net_radiation()` son **provisionales** y se
> fijarán en la especificación de cada módulo.

## Reglas para los tests de aceptación

1. Datos sintéticos o el dataset de ejemplo del paquete (US-10); sin
   internet, sin credenciales y escribiendo solo en `tempdir()`
   (`DEVELOPMENT.md` §5).
2. Cada test se encabeza con `# US-XX <título> (dev/USER_STORIES.md)`, como
   en `thermify`.
3. Los criterios numéricos usan tolerancias explícitas y justificadas
   (`VALIDATION_PLAN.md` §1.2).
4. Paralelismo en tests: como máximo 2 workers y solo en tests omitidos en
   CRAN o protegidos por variable de entorno
   (`specs/parallel-processing.md` §6).
5. Grupos opcionales (por definir, `ARCHITECTURE.md` §6.6):
   `EARTHFLUX_SLOW_TESTS`, `EARTHFLUX_ONLINE_TESTS`.

## Personas

* **Hidrólogo/a investigador/a**: estima ETa regional con MODIS para
  balances hídricos de cuencas en Chile central; trabaja en R y debe
  reproducir y publicar sus resultados.
* **Analista de riego**: produce mapas de ETa por fecha para una asociación
  de canalistas o un servicio público; usa SIG y scripts R simples.
* **Modelador/a avanzado/a**: usa los componentes de bajo nivel (`ef_*()`)
  para ensamblar variantes de METRIC, probar formulaciones o depurar una
  etapa.
* **Revisor/a científico/a**: evalúa un manuscrito o informe y necesita
  auditar parámetros, anclas, versiones y diagnósticos.
* **Mantenedor/a del paquete**: necesita ejemplos y tests rápidos que pasen
  en CRAN.

## Resumen

| ID | Título | Persona | Módulos | Hito | Test |
|---|---|---|---|---|---|
| US-01 | ETa de una fecha con estación única (C1) | Analista de riego | surface, forcing, metric, diagnostics, api | M5 | `test-story-01.R` |
| US-02 | Misma escena con forzamiento GWR (C3) y comparación con C1 | Hidrólogo/a | forcing, spatial, metric, validation, api | M5 (M3 para GWR) | `test-story-02.R` |
| US-03 | Componentes de bajo nivel | Modelador/a | metric | M2 | `test-story-03.R` |
| US-04 | Anclas manuales | Modelador/a | metric, diagnostics, api | M2/M5 | `test-story-04.R` |
| US-05 | Inspección de diagnósticos y flags | Revisor/a | diagnostics, todos | M2–M5 | `test-story-05.R` |
| US-06 | Procesamiento multifecha en paralelo | Hidrólogo/a | api, metric, spatial | M5 | `test-story-06.R` |
| US-07 | Validación contra una torre eddy covariance | Hidrólogo/a | validation | M5/M6 | `test-story-07.R` |
| US-08 | Reproducibilidad y procedencia | Revisor/a | api, diagnostics, todos | M5 | `test-story-08.R` |
| US-09 | Preparación de entradas MODIS | Analista de riego | surface | M4 | `test-story-09.R` |
| US-10 | Dataset de ejemplo apto para CRAN | Mantenedor/a | data, api | M7 | `test-story-10.R` |
| US-11 | Escenas grandes en hardware modesto | Analista de riego | metric (envoltorios ráster), api | M2/M5 | `test-story-11.R` |

---

## US-01 ETa de una fecha con estación única (C1)

Como **analista de riego**, quiero calcular ETa diaria para un área de
interés (AOI) y una fecha MODIS usando una única estación meteorológica
considerada representativa, para obtener un mapa base (configuración C1 de
`VALIDATION_PLAN.md` §2.1) con el que comparar otras configuraciones.

Criterios de aceptación:

1. Con un AOI, un estado de superficie y una estación (datos sintéticos o
   US-10), la función de alto nivel (provisional `earthflux()`) devuelve un
   objeto `earthflux_result` con las capas Rn, G, rah, dT, H, LE, ET_inst,
   ETrF y ETa, cada una con su unidad documentada (`ARCHITECTURE.md` §4).
2. Todas las capas conservan el CRS, la extensión, la resolución y la
   máscara de `NA` del estado de superficie; las celdas fuera del AOI son
   `NA`.
3. El método de forzamiento queda registrado como estación única, con el
   identificador de la estación, y el forzamiento es espacialmente
   uniforme (todas las celdas válidas reciben el mismo valor de cada
   variable meteorológica).
4. **Equivalencia API alta = cadena de bajo nivel**
   (`VALIDATION_PLAN.md` §1.1): encadenar manualmente las funciones `ef_*()`
   con las mismas entradas y anclas produce capas idénticas
   (`expect_identical()` o tolerancia documentada).
5. Un ETa negativo se conserva sin truncar y se marca con `EF_ET_NEGATIVE`
   (`ARCHITECTURE.md` §1, principio 6).

Módulos: `surface`, `forcing`, `metric`, `diagnostics`, `api`. Hito: M5.
Test: `tests/testthat/test-story-01.R`.

## US-02 Misma escena con forzamiento GWR (C3) y comparación con C1

Como **hidrólogo/a investigador/a**, quiero ejecutar la misma escena de
US-01 con forzamiento meteorológico regionalizado por GWR y comparar ambos
resultados píxel a píxel, para evaluar la hipótesis H1 sin suponer de
antemano cuál configuración es mejor.

Criterios de aceptación:

1. La configuración C3 se diferencia de C1 **solo** en el forzamiento: mismo
   estado de superficie, misma fecha y mismas anclas (o mismas reglas de
   anclas); el test verifica que las entradas no meteorológicas sean
   idénticas en ambos resultados.
2. El resultado C3 contiene los parámetros GWR por variable: kernel, tipo y
   valor del bandwidth, criterio de selección (AICc y/o CV), residuos en
   estaciones y flags (`ARCHITECTURE.md` §2, módulo `spatial`).
3. Caso con solución conocida: con un bandwidth muy grande, las predicciones
   GWR coinciden con una regresión global (OLS) dentro de una tolerancia
   documentada (`VALIDATION_PLAN.md` §1.1).
4. Si todas las estaciones tienen idénticos valores y covariables
   constantes, C3 reproduce el forzamiento uniforme y por tanto ETa de C1
   (tolerancia documentada).
5. Una función de comparación (provisional) devuelve, sobre los mismos
   píxeles válidos, la diferencia por capa (C3 − C1) y un resumen pareado;
   la salida no contiene juicios de superioridad.
6. Con menos estaciones que el mínimo documentado
   (`SCIENTIFIC_SPEC.md` §6) se produce un error o flag con clase, nunca un
   ajuste silencioso.

Módulos: `forcing`, `spatial`, `metric`, `validation`, `api`. Hito: M5
(depende de M3). Test: `tests/testthat/test-story-02.R`.

## US-03 Componentes de bajo nivel

Como **modelador/a avanzado/a**, quiero llamar directamente a
`ef_net_radiation()` y a otros componentes (provisionales
`ef_soil_heat_flux()`, `ef_longwave_out()`, ...) con vectores, matrices o
rásteres, para ensamblar variantes de METRIC o depurar una etapa sin usar
la API de alto nivel.

Criterios de aceptación:

1. `ef_net_radiation()` reproduce el caso numérico de
   `specs/ef_net_radiation.md` §7 (Rn = 503.5154 W m⁻², tolerancia absoluta
   10⁻¹⁰) y sus casos derivados.
2. La misma llamada con `numeric` y con `matrix` y, cuando `terra` esté en
   `Imports`, el cálculo sobre `SpatRaster` de 3 × 3 (directo o mediante su
   envoltorio ráster, según la decisión D-PP-09 de
   `specs/parallel-processing.md`) devuelven los mismos valores; la salida
   conserva `dim` o geometría (`ARCHITECTURE.md` §3, §6.2).
3. Entradas inválidas producen errores con las clases documentadas
   (`earthflux_domain_error` ⊂ `earthflux_input_error` ⊂ `earthflux_error`).
4. Las funciones de bajo nivel no leen ni escriben archivos, no construyen
   flags y no cambian opciones globales (`terraOptions()`, `future::plan()`,
   `options()`): el test compara el estado antes y después de la llamada.
5. Componer `ef_*()` en cadena (Rn → G → ...) da el mismo resultado que el
   despachador correspondiente (p. ej., `ef_soil_heat_flux(method = )` ≡
   función del método; `specs/soil-heat-flux.md` §9.6).

Módulos: `metric`. Hito: M2. Test: `tests/testthat/test-story-03.R`.

## US-04 Anclas manuales

Como **modelador/a avanzado/a**, quiero indicar explícitamente los píxeles
ancla frío y caliente (por coordenadas o por celda), para reproducir una
calibración publicada o corregir una selección automática que considero
inadecuada a 1 km (`SCIENTIFIC_SPEC.md` §2.3).

Criterios de aceptación:

1. Las anclas pueden darse como coordenadas en el CRS de la escena o como
   números de celda; ambas formas producen el mismo registro de anclas.
2. El registro de anclas indica `source = "manual"` y conserva ubicación,
   Ts, NDVI, α, cobertura (si existe), coeficiente del ancla frío y su
   referencia (`SCIENTIFIC_SPEC.md` §7).
3. Si se pasan como anclas manuales los mismos píxeles que eligió la
   selección automática, los coeficientes de dT y las capas H, LE y ETa son
   idénticos a los de la ejecución automática.
4. Un ancla fuera del AOI, sobre una celda `NA` o con QA inválido produce un
   error con clase (no se reemplaza por otra celda).
5. Anclas con Ts frío ≥ Ts caliente producen un error o flag con clase, sin
   corrección silenciosa.

Módulos: `metric`, `diagnostics`, `api`. Hito: M2 (núcleo de anclas) y M5
(API). Test: `tests/testthat/test-story-04.R`.

## US-05 Inspección de diagnósticos y flags

Como **revisor/a científico/a**, quiero inspeccionar qué celdas y etapas
tienen flags y por qué, para juzgar la calidad del mapa antes de aceptarlo.

Criterios de aceptación:

1. Cada flag del resultado es un objeto `earthflux_flag` cuyo código figura
   en `ef_flag_registry()`; no existen flags con códigos no registrados.
2. Un resumen (provisional `summary()` del resultado) devuelve, por etapa y
   por código, el número de celdas marcadas; en una escena sintética con
   flags conocidos los conteos coinciden con los esperados.
3. Los valores de una capa con flags son idénticos a los calculados sin
   construir diagnósticos (los flags no modifican valores;
   `ARCHITECTURE.md` §1, principio 5 y 6).
4. Una celda con `NA` en una entrada requerida tiene `NA` en la salida y
   `EF_INPUT_NA` en la etapa correspondiente.
5. Los flags de cada etapa pueden extraerse como capa ráster o máscara
   lógica alineada con la geometría del resultado.

Módulos: `diagnostics` y todos los que emiten flags. Hito: M2–M5
(incremental). Test: `tests/testthat/test-story-05.R`.

## US-06 Procesamiento multifecha en paralelo

Como **hidrólogo/a investigador/a**, quiero procesar una temporada completa
(decenas de fechas) usando varios núcleos de mi equipo o un clúster, para
obtener series de ETa en tiempos razonables sin que el resultado dependa de
cómo se paraleliza.

Criterios de aceptación:

1. Sin configuración del usuario el procesamiento es secuencial.
2. Con `future::plan(future::multisession, workers = 2)` definido por el
   usuario, los resultados por fecha son **idénticos** a los secuenciales
   (`expect_identical()` sobre valores, flags y anclas), incluidos los pasos
   con números aleatorios (semillas por fecha mediante `future.seed`).
3. El paquete no modifica el plan del usuario: `future::plan()` antes y
   después de la llamada es el mismo, también si la llamada falla.
4. Un error en una fecha se informa con la fecha afectada (condición con
   clase); el comportamiento ante fallos parciales (abortar o continuar y
   registrar) es una decisión abierta de
   `specs/parallel-processing.md` §10.
5. La procedencia registra el plan de ejecución (clase del plan, número de
   workers, tamaño de bloque, semilla).
6. El test usa como máximo 2 workers y se omite en CRAN
   (`skip_on_cran()`).

Módulos: `api`, `metric`, `spatial`. Hito: M5. Test:
`tests/testthat/test-story-06.R`. Diseño: `specs/parallel-processing.md`.

## US-07 Validación contra una torre eddy covariance

Como **hidrólogo/a investigador/a**, quiero comparar la ETa estimada con
las observaciones de una torre eddy covariance en las fechas disponibles,
para cuantificar el error de cada configuración con métricas e
incertidumbre.

Criterios de aceptación:

1. Dadas una serie de la torre (fecha, ETa observada, unidad) y la
   ubicación del sitio, la función de validación (provisional
   `ef_validate()`) extrae los valores del píxel (o de una ventana
   documentada) y devuelve n, RMSE, MAE, MBE, R², KGE y d de Willmott
   (`VALIDATION_PLAN.md` §2.3).
2. Sobre datos sintéticos con valores calculados a mano, cada métrica
   coincide con su valor de referencia (tolerancia documentada).
3. El tratamiento del no cierre del balance en la torre (sin corregir,
   razón de Bowen, residuo) es un argumento **sin valor por defecto** y queda
   registrado en el resultado (`VALIDATION_PLAN.md` §2.2).
4. Los intervalos bootstrap son reproducibles con una semilla dada e
   idénticos en ejecución secuencial y paralela.
5. Las fechas sin observación o con ETa estimada `NA` se excluyen y se
   informa cuántas; nunca se imputan.
6. La comparación pareada C1 vs. C3 usa exactamente los mismos pares
   fecha–sitio.

Módulos: `validation`. Hito: M5 (funciones) y M6 (experimento, fuera del
tarball). Test: `tests/testthat/test-story-07.R`.

## US-08 Reproducibilidad y procedencia

Como **revisor/a científico/a**, quiero que cada resultado registre
versiones, datos, parámetros, semillas y el plan de ejecución, y que las
mismas entradas den resultados idénticos, para auditar y reproducir un
análisis publicado.

Criterios de aceptación:

1. La procedencia de `earthflux_result` incluye: versiones de EarthFlux, R
   y `terra` (y de `future`/`future.apply` si se usaron), productos y
   escenas MODIS, estaciones, parámetros de GWR, registro de anclas,
   métodos por etapa, semilla y plan de ejecución
   (`DEVELOPMENT.md` §7; `specs/parallel-processing.md` §8).
2. Cuando se escribe a disco, se crea un archivo de procedencia legible
   (JSON si `jsonlite` está disponible, texto en caso contrario, como en
   `thermify`).
3. Ejecutar dos veces con las mismas entradas y semilla da valores, flags y
   anclas idénticos.
4. Cambiar el tamaño de bloque o el número de workers no cambia los
   valores, pero sí queda registrado en la procedencia.
5. La procedencia no contiene rutas absolutas del usuario ni credenciales
   (solo nombres de archivo y metadatos).

Módulos: `api`, `diagnostics` y todos los que aportan procedencia. Hito:
M5. Test: `tests/testthat/test-story-08.R`.

## US-09 Preparación de entradas MODIS

Como **analista de riego**, quiero convertir los productos MODIS de mi
área (LST, albedo, NDVI, LAI, emisividad, hora de paso) en variables
físicas con unidades y máscaras de calidad, para alimentar METRIC sin
manipular factores de escala ni bits de QA a mano.

Criterios de aceptación:

1. Los factores de escala, valores de relleno y bits QA se aplican desde una
   tabla interna documentada con su fuente (guías de usuario oficiales,
   `SCIENTIFIC_SPEC.md` §4); el test verifica la conversión sobre un archivo
   de prueba pequeño con valores conocidos.
2. La salida es un estado de superficie con los nombres y unidades del
   contrato (`ARCHITECTURE.md` §4), incluida la hora de paso por píxel.
3. Los píxeles con QA inválido o relleno quedan `NA` y su motivo se
   conserva como flag; ningún valor se corrige silenciosamente.
4. Un producto o colección no soportados producen un error con clase que
   nombra los soportados.
5. Los tests no usan internet: la descarga (si existe) es opcional y está
   protegida por `EARTHFLUX_ONLINE_TESTS`.

Módulos: `surface`. Hito: M4. Test: `tests/testthat/test-story-09.R`.

## US-10 Dataset de ejemplo apto para CRAN

Como **mantenedor/a del paquete**, quiero un dataset de ejemplo pequeño
(estado de superficie de un AOI reducido, estaciones y una serie de torre
sintética o con licencia compatible), para que los ejemplos, vignettes y
tests de aceptación corran rápido y sin internet en CRAN.

Criterios de aceptación:

1. El dataset y su documentación cumplen la política de CRAN observada el
   2026-11-04 (revisión 6985: datos y documentación no deberían superar
   5 MB; tarball de preferencia ≤ 10 MB); el test verifica el tamaño
   instalado contra un umbral interno más estricto, por definir.
2. Su preparación es reproducible desde `data-raw/` (excluido del tarball;
   `DEVELOPMENT.md` §6) y su origen y licencia están documentados.
3. Cada ejemplo `@examples` que lo usa corre en pocos segundos, sin red, en
   un solo núcleo y escribiendo solo en `tempdir()`.
4. US-01 puede ejecutarse completamente con este dataset.
5. Los rásteres de ejemplo se cargan desde `inst/extdata` con
   `system.file()` (los `SpatRaster` no se pueden guardar directamente en
   `.rda`; ver `specs/parallel-processing.md` §3.5).

Módulos: datos del paquete, `api`. Hito: M7 (borrador desde M5). Test:
`tests/testthat/test-story-10.R`.

## US-11 Escenas grandes en hardware modesto

Como **analista de riego** con un portátil, quiero procesar una escena
grande por bloques, con límites de memoria que pueda ajustar y salidas en
disco, sin que el resultado dependa del tamaño de bloque, para producir
mapas regionales sin agotar la memoria.

Criterios de aceptación:

1. Los envoltorios ráster aceptan `filename` y `wopt` (opciones de
   escritura de `terra`); con `filename` la salida queda en disco y el
   objeto devuelto apunta al archivo.
2. El control del tamaño de bloque (por definir en
   `specs/parallel-processing.md` §7) cambia el número de bloques, que se
   registra en la procedencia.
3. Los resultados son idénticos para cualquier tamaño de bloque y para
   `cores = 1` vs. `cores = 2` en las etapas que lo admiten (patrón
   `test-story-07.R` de `thermify`).
4. Los archivos temporales creados por EarthFlux se eliminan al terminar,
   también si la ejecución falla.
5. El paquete no cambia `terraOptions()` globales: el estado antes y después
   de la llamada es el mismo.

Módulos: `metric` (envoltorios ráster), `api`. Hito: M2 (patrón) y M5
(pipeline). Test: `tests/testthat/test-story-11.R`.
