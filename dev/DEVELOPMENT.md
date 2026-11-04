# EarthFlux — Guía de desarrollo

Autor y mantenedor: **Guillermo Servando Fuentes-Jaque** (único autor) ·
ORCID [0000-0002-7864-4899](https://orcid.org/0000-0002-7864-4899) ·
`gfuentesj@correo.uss.cl`.

## 1. Convenciones generales

- Documentación interna (`dev/`): español, con términos técnicos en inglés.
- Documentación pública (README, vignettes, roxygen, DESCRIPTION, NEWS):
  inglés, para CRAN y publicación internacional.
- Código, nombres de funciones y comentarios técnicos: inglés.
- `dev/` está versionado en Git y excluido del tarball (`.Rbuildignore`).
- Prefijo de funciones públicas de bajo nivel: `ef_` (p. ej.,
  `ef_net_radiation()`). Función de alto nivel futura: `earthflux()`.
- API pública deliberadamente pequeña: no exportar funciones internas.
- Ninguna referencia a herramientas de asistencia en código, documentación,
  commits, ramas, issues, releases ni sitio pkgdown. No se agregan archivos de
  configuración de herramientas de asistencia al repositorio.

## 2. Flujo Git

### 2.1 Rama principal

`main` — estable. No se reescribe su historia ni se usa `git push --force`.

### 2.2 Ramas de trabajo

Nombres semánticos que describen **qué cambia en EarthFlux**:

| Prefijo | Uso | Ejemplo |
|---|---|---|
| `code/` | Desarrollo general (prefijo por defecto) | `code/package-foundation` |
| `feature/` | Nueva capacidad | `feature/modis-ingestion`, `feature/gwr-forcing` |
| `function/` | Una función científica | `function/net-radiation`, `function/soil-heat-flux` |
| `fix/` | Corrección | `fix/anchor-selection` |
| `error/` | Manejo de errores/condiciones | `error/gwr-convergence` |
| `docs/` | Documentación | `docs/scientific-spec` |
| `test/` | Tests | `test/energy-balance` |
| `refactor/` | Reestructuración sin cambio funcional | `refactor/metric-core` |
| `ci/` | Integración continua | `ci/cran-check` |
| `release/` | Preparación de versión | `release/0.1.0` |

Prohibido usar prefijos que aludan a herramientas, asistentes o servicios
utilizados durante el desarrollo (p. ej., `ai/`, `assistant/`, `agent/`,
`harness/` o nombres de productos). El nombre de la rama describe qué cambia
en EarthFlux, no qué herramienta intervino. Se pueden usar otros prefijos
semánticos si describen el trabajo con claridad.

### 2.3 Limpieza automática de ramas

- **Ajuste del repositorio:** *Automatically delete head branches* activado
  (`delete_branch_on_merge`): GitHub elimina la rama al fusionar su PR.
- **Workflow `cleanup-merged-branches`:** elimina además las ramas remotas
  que (a) ya están contenidas en `main`, (b) no tienen PR abierto y (c) no
  reciben commits hace al menos 7 días (margen para ramas recién creadas que
  aún no tienen commits propios). Se ejecuta tras cada push a `main`, una vez
  por semana y manualmente. Nunca elimina `main` ni `gh-pages`.
- **Local:** tras fusionar,

  ```bash
  git fetch --prune
  git branch --merged main | grep -v -E '^\*|^\s*main$' | xargs -r git branch -d
  ```

  (`-d` solo borra ramas completamente fusionadas).

### 2.4 Commits

Pequeños, descriptivos, en inglés, en modo imperativo:

```text
Initialize EarthFlux package structure
Add scientific specification
Add METRIC architecture
Implement net radiation calculation
Add net radiation unit tests
Add GWR diagnostics
```

No usar mensajes genéricos (`update`, `changes`, `fix stuff`, `test`) ni
trailers de coautoría o referencias a herramientas.

Identidad Git del repositorio (configuración local, no global):

```bash
git config user.name "Guillermo Servando Fuentes-Jaque"
git config user.email "32119499+djwillichile@users.noreply.github.com"
```

### 2.5 Integración

1. Rama de trabajo desde `main` actualizado.
2. `devtools::document()`, `devtools::test()`, `devtools::check()` locales.
3. PR hacia `main`; R-CMD-check en verde.
4. Fusión (preferir *squash* o *rebase* para historia limpia).
5. La rama se elimina automáticamente (2.3).

## 2.6 Documentación automática

| Elemento | Fuente de verdad | Automatización |
|---|---|---|
| Referencia de funciones (`man/`, `NAMESPACE`) | Bloques roxygen2 en `R/` | Workflow `document.yaml`: regenera con roxygen2 **8.1.1** (versión fijada) y falla si hay diferencias. No hace commits: se regenera localmente con `devtools::document()` |
| Sitio web | `README`, `man/`, vignettes, `NEWS.md`, `_pkgdown.yml` | Workflow `pkgdown.yaml`: construye y publica en `gh-pages` en cada push a `main` |
| About de GitHub (descripción, website, topics) | `DESCRIPTION`: `Title`, `URL`, `Config/github/topics` | Workflow `about.yaml` en cada cambio de `DESCRIPTION` en `main`; también activa Pages y el borrado automático de ramas fusionadas |

Configuración única de `about.yaml` (requisito de GitHub: el `GITHUB_TOKEN`
por defecto no puede modificar ajustes del repositorio):

1. Crear un *fine-grained personal access token* limitado al repositorio
   `EarthFlux`, con permisos *Administration: Read and write* y
   *Pages: Read and write*.
2. Guardarlo como secret del repositorio con el nombre `ABOUT_TOKEN`
   (*Settings → Secrets and variables → Actions*).
3. Ejecutar el workflow una vez desde *Actions → about.yaml → Run workflow*.

Sin el secret, el workflow se omite con un aviso y no falla. Para actualizar
roxygen2, cambiar la versión fijada en `document.yaml` y regenerar
localmente con la misma versión.

## 3. Definition of Done para funciones científicas

Una función científica solo se implementa cuando existe, en
`SCIENTIFIC_SPEC.md`:

1. ecuación documentada (estado `VERIFICADA`);
2. referencias verificadas (con DOI cuando exista);
3. definición de todas las entradas;
4. unidades de entrada y salida;
5. comportamiento con NA;
6. dominio esperado y comportamiento fuera de él (error, warning o flag);
7. caso numérico verificable;
8. tests diseñados.

Y se considera terminada cuando además:

- tiene documentación roxygen completa (`@description`, `@param` con
  unidades, `@return` con unidades, `@details` con supuestos,
  `@references`, `@examples` rápidos y sin internet, `@export` solo si es
  pública);
- sus tests verifican comportamiento real (nunca `expect_true(TRUE)`);
- `devtools::check()` no introduce errores, warnings ni notes nuevos;
- `NEWS.md` registra el cambio.

Primera candidata (tras M1): `ef_net_radiation()`.

## 4. Política de dependencias

Antes de agregar una dependencia:

1. inspeccionar alternativas;
2. revisar mantenimiento;
3. revisar disponibilidad en CRAN;
4. revisar compatibilidad multiplataforma (Linux, Windows, macOS);
5. justificarla en `ARCHITECTURE.md` (sección de decisiones).

Estado actual:

| Dependencia | Tipo | Estado |
|---|---|---|
| R (≥ 4.1.0) | Depends | Mínimo razonable para el ecosistema actual; revisar antes de CRAN |
| testthat (≥ 3.0.0), knitr, rmarkdown | Suggests | Infraestructura de tests y vignettes |
| `terra` | Imports | **Aceptada**; se declara con la primera función que la use |
| `future` / `future.apply` | Imports/Suggests | Aceptado el requisito de paralelismo; decisión de paquete en M1 |
| `sf` | – | Solo si se justifica |
| Backend GWR | – | Decisión abierta |
| `renv` | – | No en el paquete; posible en el repositorio de experimentos |

## 5. CRAN

Objetivo: `R CMD check` con 0 errors, 0 warnings, 0 notes injustificadas.

No usar: rutas absolutas; escritura fuera de `tempdir()`; internet
obligatorio en tests/ejemplos/vignettes; descargas grandes; credenciales;
código interactivo obligatorio; ejemplos lentos; más de 2 núcleos en checks.

Antes del envío a CRAN: confirmar que el correo del mantenedor en
`DESCRIPTION` siga vigente (CRAN exige un correo estable), retirar la frase "under active development" de la
descripción si ya no aplica y agregar DOI de referencias en `Description`
con el formato `<doi:...>`.

## 6. Datos y archivos sensibles

Nunca versionar: tokens, contraseñas, cookies, credenciales, `.Renviron`,
credenciales NASA Earthdata, datos privados, productos MODIS completos ni
rásteres grandes. Los datos de ejemplo deben ser pequeños y respetar los
límites de tamaño de CRAN; los datos crudos y su script de preparación irán
en `data-raw/` (excluido del tarball).

## 7. Reproducibilidad

Registrar para cada experimento: versiones de paquetes, versiones de datos,
parámetros, semillas, fechas, productos MODIS, identificadores de escenas,
estaciones utilizadas, criterios GWR, anclas y resultados intermedios. El
objeto de resultado futuro (`earthflux_result`) incluirá esta procedencia.

## 8. Versionado y releases

- Versionado semántico. Desarrollo: `0.0.0.9000`.
- Primer release experimental planificado: `0.1.0`, cuando exista un
  pipeline parcial funcional y testeado.
- No crear `1.0.0` hasta completar la validación científica y la
  preparación CRAN.

## 9. Roadmap

| Hito | Contenido | Estado |
|---|---|---|
| **M0 — Foundation** | Paquete creado con `usethis`; Git y GitHub; licencia MIT; autor; DESCRIPTION; roxygen2; testthat 3; pkgdown; README; NEWS; CITATION; `.gitignore`; `.Rbuildignore`; `dev/`; documentación científica inicial; estructura modular de `R/`; estructura inicial de tests; CI | En curso |
| **M1 — Scientific specification** | Ecuaciones METRIC verificadas; productos MODIS; unidades; GWR; variables meteorológicas; referencias; anclas; validación; criterios QA; diseño de paralelismo | Pendiente |
| **M2 — METRIC core physics** | Rn, G, rugosidad, rah, dT, H, LE, ET_inst, ETrF, ETa como funciones independientes y testeadas | Pendiente |
| **M3 — Spatial meteorological forcing / GWR** | Estaciones, QC, GWR (bandwidth, kernel, predicción, diagnósticos), alternativas de referencia | Pendiente |
| **M4 — MODIS preprocessing** | Lectura y conversión de productos a variables físicas estandarizadas | Pendiente |
| **M5 — Integrated pipeline** | `earthflux()` sobre el núcleo; objeto de resultado con diagnósticos y procedencia | Pendiente |
| **M6 — Scientific validation** | Experimento C1 vs. C2 vs. C3 (`VALIDATION_PLAN.md`) | Pendiente |
| **M7 — CRAN preparation** | Datos de ejemplo, checks multiplataforma, revisión de documentación | Pendiente |
| **M8 — Scientific publication** | Artículo de software y artículo metodológico (productos separados) | Pendiente |

No comenzar una implementación extensa de M2 antes de tener M1
suficientemente definido.

## 10. Dos productos separados

- **A. Software:** paquete EarthFlux (GitHub → CRAN → artículo de software).
- **B. Investigación:** evaluación metodológica de MODIS + METRIC + GWR → ETa.

Los resultados científicos no se mezclan con la documentación del paquete.
