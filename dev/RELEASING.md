# EarthFlux — Proceso de release

Las versiones siguen versionado semántico. Una versión se publica solo si,
en el commit que se etiqueta, se cumple todo lo siguiente:

- [ ] Tests unitarios, de aceptación (historias de usuario) e integración en
      verde, incluidos los grupos opcionales cuando existan.
- [ ] `R CMD check` en verde en Ubuntu (release, devel, oldrel), Windows y
      macOS (CI). macOS no corre en los PR: se exige la ejecución en `main`
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
   `DESCRIPTION` y `version` en `CITATION.cff`, y convertir el encabezado de
   desarrollo de `NEWS.md` en `# EarthFlux X.Y.Z` con su resumen. Abrir un
   PR hacia `main` (commit `release: EarthFlux X.Y.Z`).
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
   la sección de `NEWS.md` como notas y el tarball adjunto.
4. **Zenodo** (pendiente de activar en el primer release): con la
   integración de GitHub activada, cada release publicado se archiva y
   obtiene un DOI de versión. El DOI de concepto (siempre la última
   versión) se usa en `CITATION.cff`, `inst/CITATION` y el badge del README;
   el DOI de versión se agrega a la sección de `NEWS.md` y a `identifiers`
   en `CITATION.cff`. Requiere un `.zenodo.json` con metadatos del autor
   (afiliación a confirmar por el autor).
5. En `main`, abrir la siguiente versión de desarrollo en una rama
   `code/dev-X.Y.Z.9000` (`Version: X.Y.Z.9000`, encabezado
   `# EarthFlux X.Y.Z.9000 (development version)` en `NEWS.md`; commit
   `dev: start X.Y.Z.9000`).

El paquete no se envía a CRAN sin autorización explícita del mantenedor.
