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
- [x] Diseño de paralelismo e historias de usuario.
- [x] Registro consolidado de decisiones (`DECISIONS.md`).
- [ ] Decisiones P0 del autor: P0-4 … P0-12 adoptadas como
      `DECIDIDA (provisional)` el 2026-11-04 por indicación del autor,
      revisables antes de `0.1.0` (`DECISIONS.md` §1.0); P0-1 … P0-3
      abiertas hasta leer Allen et al. (2007).
- [x] Registro unificado de flags (`specs/flags.md`).
- [x] Diseño experimental de validación (C1/C2/C3).
- [ ] Verificar Allen et al. (2007) y ASCE-EWRI (2005) en la fuente
      primaria.

## M2 — METRIC core physics (objetivo: 0.1.0)
- [x] Convenciones comunes del núcleo (`ARCHITECTURE.md` §3), constantes
      físicas, registro de flags por etapa, condiciones con datos,
      `ef_air_pressure()` y `ef_lambda()`.
- [x] Componentes de radiación (RL↑, RL↓, Rs↓, geometría solar).
- [x] Flujo de calor del suelo.
- [x] Píxeles ancla (selección automática y explícita, auditable).
- [x] Rugosidad, rah, estabilidad, dT y H con calibración iterativa.
- [x] LE, ET instantánea, ETrF y ETa diaria.
- [x] Armonización de los cinco módulos (despachadores con clase, flags y
      procedencia; una convención de diagnósticos; auxiliares compartidos;
      `DECISIONS.md` §1.2) y test de extremo a extremo de la cadena
      (`tests/testthat/test-metric-chain.R`).
- [ ] Primer release experimental `0.1.0` con pipeline parcial testeado.

## M3 — Spatial meteorological forcing / GWR
- [x] Tabla estándar de estaciones y QC (`ef_station_table()`,
      `ef_station_qc()`; pruebas de clase I y III; las de clase II quedan
      sin evaluar hasta tener umbral con referencia, WF-06).
- [x] Variables derivadas (FAO-56, `VERIFICADA`) y ETo/ETr de referencia
      (`ef_ref_et()`; constantes ASCE-EWRI `CANDIDATA`) y serie por estación
      con `etr_inst` y `etr_24` (`ef_station_ref_et()`).
- [x] Núcleo GWR interno (AICc, CV, LOO; verificación cruzada con
      `GWmodel`), baselines C1/C2, predicción exacta por bloques,
      CV espacial por teselas y paralelismo con `future.apply`
      (`ef_regionalize()`, `ef_regionalize_cv()`).
- [x] Armonización de M3 (`DECISIONS.md` §1.3; clases, condiciones y
      registro de flags documentados; caché del registro de flags; nombres
      reconciliados) y test de extremo a extremo estaciones → QC →
      regionalización → núcleo METRIC
      (`tests/testthat/test-forcing-chain.R`).
- [ ] Verificar las constantes ASCE-EWRI (2005) en la fuente primaria (en
      curso, cambio separado).
- [ ] Decisiones abiertas expuestas como argumentos sin defecto: WF-09,
      WF-11, WF-15, WF-16, GW-04, GW-05, GW-07, decisión 5.1; y abiertas
      para el autor: Rs nocturna y días incompletos, dos definiciones de Ra
      horaria (WF-10), regla de vecinos con kernels continuos (GW-06),
      umbrales de WF-06 (`DECISIONS.md` §1.3, A-1 … A-6).
- [ ] Sin implementar: modo grueso (GW-08), I de Moran, KED/reanálisis,
      opciones O2/O4/O5 de ETr_inst, traspaso de `etr_inst`/`etr_24` a la
      tabla de regionalización, `datatype` en disco (D-PP-05).

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
