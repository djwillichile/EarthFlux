# Informe de reproducibilidad

## Entorno de ejecución

| Componente | Versión |
|---|---|
| Sistema | Linux (contenedor), 4 núcleos, 15 GB de RAM |
| R | 4.3.3 (2024-02-29) |
| EarthFlux | 0.1.0.9000, instalado con `R CMD INSTALL .` desde el commit del estudio (rama `claude/peaceful-goldberg-ptl19f`) |
| terra | 1.7-65 |
| future / future.apply | instalados desde CRAN el 5 de noviembre de 2026 |
| ggplot2, patchwork, data.table, scico | CRAN, 5 de noviembre de 2026 (solo figuras) |
| LaTeX | TeX Live (Ubuntu) con `biblatex` + `biber` 2.19, `siunitx`, `tikz`, `beamer` |
| Python | 3, solo biblioteca estándar (`01_download_dmc.py`) |

No se usó `renv` porque el contenedor no lo tenía instalado y el plazo del
congreso no permitía fijar un `renv.lock` verificado. Las versiones quedan
registradas aquí y en `results/diagnostics/` (procedencia de cada objeto de
EarthFlux). Recomendación pendiente: `renv::init()` antes de la versión
para revista.

## Semillas y determinismo

- Semilla global: `20270121` (`config/study.json`). Además, cada
  experimento aleatorio usa una semilla derivada (`+1` S-A, `+2` S-B, `+10`
  permutaciones de Moran, `+11` densidad de estaciones).
- La regionalización y la validación cruzada usan un plan `future` con 4
  procesos (`CEDES_WORKERS=4`). EarthFlux garantiza resultados idénticos
  para cualquier plan (`dev/specs/parallel-processing.md`), y la verificación
  de abajo lo confirma para este estudio.

## Verificación de la reproducción

Después de la corrida principal se borraron todas las tablas CSV de
`results/tables/` y `results/validation/`. Luego se ejecutó de nuevo la
cadena completa, sin descargas (`CEDES_SKIP_DOWNLOAD=1 Rscript
research/cedes2027/scripts/run_all.R`), y se compararon las sumas MD5 de los
17 archivos. El resultado está en `results/diagnostics/reproducibility_check.txt`.

## Pruebas

- **Paquete:** `testthat::test_local()` en este entorno ejecutó 614 bloques
  y 4473 expectativas: 0 fallos, 9 omitidos y 17 errores. Los 17 errores
  ocurren en la lectura de archivos HDF de MODIS (`test-modis-io.R`,
  `test-modis-surface.R`, `test-surface-chain.R`) y se deben a la versión
  local de `terra` (1.7-65), en la que `terra::gdal(lib = "all")` y las
  etiquetas de metadatos se comportan de otra forma. El estudio no usa esa
  lectura. Detalle en `results/diagnostics/package_tests.csv`.
- **Estudio:** `tests/test_study.R` comprueba que toda macro usada en los
  documentos esté definida, que el registro de afirmaciones cubra todas las
  macros y apunte a archivos existentes, el cierre $LE = R_n - G - H$ en
  todos los mapas, la identidad de las anclas, la completitud de la
  validación cruzada y el límite del resumen de 250 palabras.

## Incidencias corregidas durante el estudio

Se registran para la trazabilidad. Ninguna modifica el paquete.

1. **Covariables de las estaciones en el experimento M.** En la primera
   versión de `05_metric_experiment.R`, las covariables se extraían del
   ráster de predicción de la escena, que no cubre la mayoría de las
   estaciones. OLS y GWR se ajustaban entonces con 25 de las 62
   estaciones. EarthFlux registró las exclusiones con su motivo en
   `station_table`, lo que permitió detectarlo. Se corrigió pasando
   `station_covariates` desde la grilla regional, la misma de la validación
   cruzada. Todos los resultados reportados son posteriores a la
   corrección.
2. **Edición de un script durante su ejecución.** `Rscript` lee el script
   de forma incremental: una edición durante una corrida de prueba produjo
   un error de sintaxis. Esa corrida se descartó.
3. **Locale.** Con el locale `C`, los caracteres no ASCII de las figuras se
   perdían. `run_all.R` fija `C.UTF-8`.
4. **Identidad de las anclas.** C2-OLS pierde la mayoría de las celdas
   porque su viento sale del dominio físico, de modo que sus anclas se
   seleccionan en un dominio menor. Se registra por corrida
   (`metric_calibration.csv`) y se declara en el texto.

## Trazabilidad de las cifras

`results/tables/numbers.tex` (macros LaTeX) y
`results/tables/claims_register.csv` (macro, valor, archivo de origen,
selección y cálculo) se generan con `scripts/08_numbers.R`. El manuscrito,
el resumen extendido y las diapositivas solo usan esas macros. El resumen
de 250 palabras se genera desde `extended-abstract/resumen_250_template.md`
con las mismas macros.
