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

## M2 — METRIC core physics
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

## M3 — Spatial meteorological forcing / GWR
- [x] Tabla estándar de estaciones y QC (`ef_station_table()`,
      `ef_station_qc()`; pruebas de clase I y III; las de clase II quedan
      sin evaluar hasta tener umbral con referencia, WF-06).
- [x] Variables derivadas (FAO-56, `VERIFICADA`) y ETo/ETr de referencia
      (`ef_ref_et()`, FAO-56 y ASCE-EWRI) y serie por estación
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
- [x] Verificar la cadena ASCE-EWRI (2005) en la fuente primaria (cambio
      separado; `DECISIONS.md` §1.3, M3-01a … M3-01e). Pendiente: caso
      numérico publicado (Apéndice C, no disponible).
- [ ] Decisiones abiertas expuestas como argumentos sin defecto: WF-09,
      WF-11 (reloj del día), WF-15 (FAO-56), WF-16, GW-04, GW-05, GW-07,
      decisión 5.1; y abiertas para el autor: Rs nocturna y días
      incompletos, Ra de QC-05b frente a la de la ETr con FAO-56 (WF-10),
      regla de vecinos con kernels continuos (GW-06), umbrales de WF-06
      (`DECISIONS.md` §1.3, A-1 … A-6).
- [ ] Sin implementar: modo grueso (GW-08), I de Moran, KED/reanálisis,
      opciones O2/O4/O5 de ETr_inst, traspaso de `etr_inst`/`etr_24` a la
      tabla de regionalización, `datatype` en disco (D-PP-05).

## M4 — MODIS preprocessing (objetivo: 0.1.0)
- [x] Lectura y escalado de productos; QA como flags; conversión a UTC
      (tabla de producto, lectores HDF4 y convertidos, política QA,
      `EF_SURF_*`; `DECISIONS.md` §1.4, M4-01 … M4-18).
- [x] Conversiones a banda ancha, desfase de compuestos y agregación a la
      grilla de trabajo (opciones `CANDIDATA` sin defecto).
- [x] Ensamblaje del estado de superficie (`earthflux_surface_state`,
      contrato de `ARCHITECTURE.md` §4) con flags por capa y procedencia;
      armonización de M4 y test de extremo a extremo superficie → núcleo
      METRIC (`tests/testthat/test-surface-chain.R`; M4-19 … M4-25).
- [x] Decisiones del autor del 2026-11-04 (`DECISIONS.md` §1.4, M4-27 …
      M4-30): fecha de la escena **2019-02-15** (Terra, MP-12); LAI
      explícito en las clases no vegetadas (`lai_nonveg`, MP-06) con el
      flag `EF_SURF_LAI_ASSIGNED`; emisividades de banda 31/32 llevadas en
      el estado de superficie para E1 (lo que falta para E1/E2:
      `specs/modis-products.md` §8.2).
- [x] Dataset de ejemplo compatible con CRAN: `cauquenes_modis`
      (`data/cauquenes_modis.rda`, 58 KB), un `SpatRaster` empaquetado
      con `terra::wrap()` (convención del dataset `cauquenes` de
      thermify) con las 20 capas del estado de superficie del 2019-02-15
      (Terra, h12v12, C6.1) enmascaradas a la provincia de Cauquenes; LST
      válida en el 96,7 % de las 3.779 celdas de la provincia. Generado
      con `data-raw/modis-example.R` (M4-26, M4-27); procedencia en
      `?cauquenes_modis` y `data-raw/cauquenes_modis.yml`. El contraste
      con los granulos reales corrigió el lector HDF4 (`_FillValue` de
      `QC_Day`, grilla de MCD43A3, nombres SDS entre comillas, escala
      recíproca de MOD13, tolerancia de anidamiento 1 km/500 m; NEWS).
      Detalle en `specs/modis-products.md` §12.
- [ ] Primer release experimental `0.1.0` al cierre de M4, con la escena de
      ejemplo de Cauquenes (opción B, decisión del autor del 2026-11-04;
      `DECISIONS.md` §1.4, M4-00); antes previsto al cierre de M2 con el
      pipeline parcial testeado.

## M5 — Integrated pipeline
- [ ] `earthflux()` sobre el núcleo; objeto de resultado con diagnósticos y
      procedencia; paralelismo.
- [x] Diseño de la carga de entradas (decisión del autor, 2026-11-05;
      `ARCHITECTURE.md` §6.7, `DECISIONS.md` §1.5, M5-01 … M5-07): tres
      niveles de uso; nivel básico con área, fecha, una fuente
      meteorológica y un preset obligatorio; MODIS y MDE automáticos;
      cobertura de suelo opcional.
- [ ] Presets de `earthflux()` (M5-04): nombres, contenido y estado.
- [ ] Descarga y preparación automática del MDE (NASADEM, M5-06).
- [ ] Forzamiento sin estaciones (M5-07): evaluado el 2026-11-05
      (recomendación provisional: Open-Meteo ERA5, CR2MET diario en Chile,
      MCD18A1 v062 para Rs); falta la decisión del autor y evaluar viento y
      hora de paso con datos horarios de estaciones.

## M6 — Scientific validation
- [ ] Experimento C1 vs. C2 vs. C3 según `VALIDATION_PLAN.md`.

## M7 — CRAN preparation
- [ ] Checks multiplataforma, revisión de documentación y ejemplos.

## M8 — Scientific publication
- [ ] Artículo de software y artículo metodológico.
