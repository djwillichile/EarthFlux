# EarthFlux — Proceso de release

Las versiones siguen versionado semántico. Una versión se publica solo si,
en el commit que se etiqueta, se cumple todo lo siguiente:

- [ ] Tests unitarios, de aceptación (historias de usuario) e integración en
      verde, incluidos los grupos opcionales cuando existan.
- [ ] `R CMD check` en verde en Ubuntu (release, devel, oldrel), Windows,
      macOS y con el `terra` mínimo (job `min-terra`) (CI). macOS no corre en los PR: se exige la ejecución en `main`
      del commit que se etiqueta (o una ejecución manual del workflow
      `R-CMD-check` sobre ese commit, *Run workflow* en Actions).
- [ ] Documentación regenerada (`devtools::document()`, `README.md`) y
      sitio pkgdown construido sin errores (CI `document` y `pkgdown`).
- [ ] `NEWS.md` tiene una sección `# EarthFlux X.Y.Z` con un párrafo de
      resumen y las secciones que correspondan: `## Breaking changes`,
      `## New features`, `## Changes`, `## Documentation`.
- [ ] Las funciones científicas incluidas cumplen la *Definition of Done*
      (`DEVELOPMENT.md` §3) y su estado de verificación está declarado en la
      documentación pública.

## Pasos

1. En una rama `code/release-vX.Y.Z`, fijar `Version: X.Y.Z` en
   `DESCRIPTION`, `version` en `CITATION.cff` y en `.zenodo.json`, y
   convertir el encabezado de desarrollo de `NEWS.md` en
   `# EarthFlux X.Y.Z` con su resumen. `inst/CITATION` toma la versión de
   `DESCRIPTION` (`meta$Version`) y no se edita. Abrir un PR hacia `main`
   (commit `release: EarthFlux X.Y.Z`).

   `date-released` de `CITATION.cff` no se fija en este paso: el formato
   CFF 1.2.0 no lo exige y la fecha real solo se conoce al publicar. Se
   agrega con la fecha del GitHub Release (`date-released: "YYYY-MM-DD"`)
   en el commit posterior al release que registra el DOI (paso 4).
2. Tras la fusión, crear el tag `vX.Y.Z` sobre el commit de merge de `main`:

   ```sh
   git checkout main && git pull
   git tag -a vX.Y.Z -m "EarthFlux X.Y.Z"
   git push origin vX.Y.Z
   ```

   o desde GitHub (*Releases → Draft a new release → tag vX.Y.Z, target
   `main` → Publish release*), o ejecutando manualmente el workflow
   `release` desde `main` (crea el tag `vX.Y.Z` a partir de `DESCRIPTION`).
3. El workflow `release` comprueba que el tag coincide con `DESCRIPTION`,
   construye y verifica el paquete y crea o actualiza el GitHub Release con
   el tarball adjunto. Las notas escritas en GitHub al publicar se
   conservan; solo un release sin notas recibe la sección de `NEWS.md`
   (extensa: conviene escribir un resumen al publicar).
4. **Zenodo**: con la integración de GitHub activada (*zenodo.org →
   Account → GitHub*, interruptor del repositorio `djwillichile/EarthFlux`
   en *On*; debe hacerse **antes** de publicar el release, Zenodo solo
   archiva los releases publicados después de activarla), cada release
   publicado se archiva y obtiene un DOI de versión. Los metadatos salen de
   `.zenodo.json` (tiene prioridad sobre `CITATION.cff`; excluido del
   paquete en `.Rbuildignore`): título, descripción de `DESCRIPTION`,
   autor con nombre y ORCID, licencia MIT, tipo `software`, palabras clave
   de `CITATION.cff` y enlaces al repositorio y al sitio pkgdown. El DOI de
   concepto (siempre la última versión) se usa en `CITATION.cff`,
   `inst/CITATION` y el badge del README; el DOI de versión se agrega a la
   sección de `NEWS.md` y a `identifiers` en `CITATION.cff`.

   **Afiliación pendiente:** `.zenodo.json` no incluye `affiliation`
   porque el autor no la ha confirmado. Si la quiere, la agrega como
   `"affiliation": "..."` en `creators` **antes** del release (PR aparte
   antes de crear el tag) o **después**, editando el registro en Zenodo y
   `.zenodo.json` para las versiones siguientes.
5. En `main`, abrir la siguiente versión de desarrollo en una rama
   `code/dev-X.Y.Z.9000` (`Version: X.Y.Z.9000`, encabezado
   `# EarthFlux X.Y.Z.9000 (development version)` en `NEWS.md`; commit
   `dev: start X.Y.Z.9000`).

El paquete no se envía a CRAN sin autorización explícita del mantenedor.

## Estado de 0.1.0 (rama `code/release-v0.1.0`)

Primer release (`DECISIONS.md` §1.4, M4-00). **Publicado el 2026-11-05**:
tag `v0.1.0` sobre `13b6da8` (merge de la verificación contra el manual
SEBAL-Idaho), tarball adjunto por el workflow `release`. Zenodo:
DOI de la versión `10.5281/zenodo.23981326`, DOI de concepto
`10.5281/zenodo.23981325` (registrado en `CITATION.cff`, `inst/CITATION`
y el README). La integración con Zenodo se activó después de la primera
publicación, por lo que el release se volvió a publicar (borrador →
publicado) para que Zenodo lo archivara: activar Zenodo **antes** de
publicar (paso 4). Versión de desarrollo `0.1.0.9000` abierta.

Lista de verificación, comprobada localmente el 2026-11-05 (Linux, R 4.3.3,
roxygen2 8.1.1, terra 1.9.50):

- [x] Tests: `devtools::test()` con 4706 expectativas, 0 fallos, 0
      warnings y 3 omitidos (el test del pipeline, pendiente de M5, y dos
      de paralelismo que necesitan el paquete instalado y corren en
      `R CMD check`). Incluye los tests de extremo a extremo de la cadena
      METRIC, del forzamiento y de la superficie MODIS.
- [x] `R CMD check` multiplataforma: local `devtools::check()`
      (`_R_CHECK_SYSTEM_CLOCK_=FALSE`, `--no-manual`) con 0 errores,
      0 warnings y 0 notes; tarball de 0,75 MB. CI en verde en Ubuntu
      (release, devel, oldrel), Windows y macOS sobre `13b6da8`.
- [x] Documentación regenerada (`devtools::document()` sin cambios
      pendientes; `README.md` con `devtools::build_readme()`);
      `pkgdown::check_pkgdown()` sin problemas y `pkgdown::build_site()`
      local sin errores. Falta la CI `document` y `pkgdown` del PR.
- [x] `NEWS.md` con `# EarthFlux 0.1.0`, resumen y secciones
      `## Verification against the SEBAL Idaho manual` (2026-11-05),
      `## New features`, `## Changes`, `## Documentation` (sin cambios
      incompatibles: es la primera versión).
- [x] *Definition of Done*: el estado de verificación está declarado en
      roxygen (`CANDIDATA`/`VERIFICADA`), README, NEWS y artículos. Desde
      la revisión del 2026-11-05 ([`VERIFICATION.md`](VERIFICATION.md);
      `DECISIONS.md` M2-08 … M2-10) la mayoría de las formas del núcleo
      METRIC son `VERIFICADA (SEBAL-Idaho 2002)` y SH-11 está resuelta (2 m);
      la condición 1 de `DEVELOPMENT.md` §3 (ecuación `VERIFICADA`) **no**
      se cumple para las 9 formulaciones que siguen `CANDIDATA` (G de
      Tasumi, τ particionada, Rs↓ en laderas, cos θ en plano inclinado,
      ρ_air en METRIC, entre otras): se publican por la regla provisional
      de `DECISIONS.md` §1.0 y la decisión M4-00. Excepción confirmada por
      el autor el 2026-11-05 (`DECISIONS.md` M4-31).
- [x] Decisiones `DECIDIDA (provisional)` (P0-4 … P0-12, §1.2 – §1.4),
      declaradas "revisables por el autor antes de `0.1.0`": el autor
      confirma que se mantienen provisionales en 0.1.0 o las revisa.
      Confirmado el 2026-11-05: se mantienen provisionales (M4-31).

Pasos restantes para el autor, en este orden:

1. Revisar el PR de `code/release-v0.1.0` (confirmar las dos excepciones
   de arriba) y esperar la CI del PR en verde (R-CMD-check, document,
   pkgdown).
2. Activar el repositorio en Zenodo (paso 4) **antes** de publicar el
   release. Si se quiere la afiliación en el primer archivo, agregarla
   antes a `.zenodo.json` (PR aparte).
3. Fusionar el PR con commit de merge.
4. Comprobar en *Actions* que `R-CMD-check` del commit de merge en `main`
   está en verde **incluido macOS**; si macOS no corrió o se canceló por
   falta de runner, lanzarlo con *Run workflow* sobre `main` y esperar el
   verde antes de seguir.
5. Crear el tag y el release `v0.1.0` sobre el commit de merge (paso 2;
   desde *Releases → Draft a new release*, tag `v0.1.0`, target `main`,
   título `EarthFlux 0.1.0`, o con `git tag -a v0.1.0 -m "EarthFlux 0.1.0"`
   y `git push origin v0.1.0`).
6. Verificar que el workflow `release` terminó (notas de `NEWS.md` y
   `EarthFlux_0.1.0.tar.gz` adjunto), que el badge *GitHub release* del
   README muestra 0.1.0 y que Zenodo creó el registro con su DOI.
7. Abrir la versión de desarrollo (paso 5): rama `code/dev-0.1.0.9000`,
   `Version: 0.1.0.9000`, encabezado
   `# EarthFlux 0.1.0.9000 (development version)` en `NEWS.md`, commit
   `dev: start 0.1.0.9000`; en un commit `docs:` aparte, registrar el DOI
   (paso 4) y `date-released` en `CITATION.cff`, y marcar en `ROADMAP.md`
   el release 0.1.0 y la integración con Zenodo como hechos.
