# EarthFlux — Roadmap

Seguimiento por hito y versión. Ver también `DEVELOPMENT.md` §9 y el índice
de especificaciones en `SCIENTIFIC_SPEC.md` §0.

## M0 — Foundation (0.0.0.9000)
- [x] Paquete creado con `usethis`; licencia MIT; autoría y metadatos.
- [x] roxygen2 (Markdown, versión fijada), testthat 3, pkgdown, README,
      NEWS, CITATION, `CITATION.cff`.
- [x] Estructura modular de `R/` y de tests; diagnósticos con flags.
- [x] CI: R CMD check multiplataforma, pkgdown, control de documentación,
      sincronización del About, limpieza de ramas fusionadas.
- [x] Proceso de release documentado (`RELEASING.md`) y automatizado.
- [ ] Integración con Zenodo (primer release).

## M1 — Scientific specification
- [x] Radiación neta (`ef_net_radiation()` implementada; ecuación
      `CANDIDATA`).
- [x] Componentes de radiación, G, anclas, H y estabilidad, cadena de ET.
- [x] Forzamiento meteorológico y ETo FAO-56 (verificada).
- [x] Productos MODIS (metadatos verificados con guías oficiales).
- [x] Backend GWR decidido y especificación del módulo GWR.
- [x] Auditoría de referencias.
- [ ] Diseño de paralelismo e historias de usuario.
- [ ] Registro consolidado de decisiones y decisiones P0 del autor.
- [ ] Registro unificado de flags.
- [ ] Diseño experimental de validación (C1/C2/C3).
- [ ] Verificar Allen et al. (2007) y ASCE-EWRI (2005) en la fuente
      primaria.

## M2 — METRIC core physics (objetivo: 0.1.0)
- [ ] Componentes de radiación (RL↑, RL↓, Rs↓, geometría solar).
- [ ] Flujo de calor del suelo.
- [ ] Píxeles ancla (selección automática y explícita, auditable).
- [ ] Rugosidad, rah, estabilidad, dT y H con calibración iterativa.
- [ ] LE, ET instantánea, ETrF y ETa diaria.
- [ ] Primer release experimental `0.1.0` con pipeline parcial testeado.

## M3 — Spatial meteorological forcing / GWR
- [ ] Tabla estándar de estaciones y QC.
- [ ] ETo/ETr de referencia.
- [ ] Núcleo GWR interno (AICc, CV, LOO), baselines C1/C2, predicción por
      bloques.

## M4 — MODIS preprocessing
- [ ] Lectura y escalado de productos; QA como flags; conversión a UTC.
- [ ] Dataset de ejemplo compatible con CRAN.

## M5 — Integrated pipeline
- [ ] `earthflux()` sobre el núcleo; objeto de resultado con diagnósticos y
      procedencia; paralelismo.

## M6 — Scientific validation
- [ ] Experimento C1 vs. C2 vs. C3 según `VALIDATION_PLAN.md`.

## M7 — CRAN preparation
- [ ] Checks multiplataforma, revisión de documentación y ejemplos.

## M8 — Scientific publication
- [ ] Artículo de software y artículo metodológico.
