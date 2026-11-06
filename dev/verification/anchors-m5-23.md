# Evaluación de los criterios de anclas de los presets (M5-23) y del mínimo de z_om (M5-24)

Fecha: **2026-11-06**. Autor: Guillermo Servando Fuentes-Jaque.
Decisiones: `DECISIONS.md` §1.5, M5-23 y M5-24. Especificación:
`specs/presets.md` §4.

> **Evaluación de coherencia, no validación.** No hay datos de referencia
> (torres de covarianza, lisímetros, balances de cultivo) para estas
> escenas: las cifras de abajo solo indican si las anclas elegidas
> responden a la intención física del manual y si las distribuciones de
> ETrF y ETa₂₄ son verosímiles. Ninguna cifra de este documento cambia el
> estado `CANDIDATA` de los criterios. No se versionan datos descargados:
> solo números.

## 1. Escenas y corridas

| | Cauquenes | Maule |
|---|---|---|
| AOI (lon/lat, EPSG:4326) | −72,8 … −71,9 / −36,3 … −35,6 | −72,8 … −70,3 / **−35,87** … −34,7 |
| Tesela MODIS | h12v12 | h12v12 (el bbox propuesto, hasta −36,6, también cae en una sola tesela: x sinusoidal mínima −6 655 256 m > −6 671 703 m, borde de h12) |
| Celdas en el AOI / con ETa₂₄ (v1 → v2) | 7492 / 6583 → 6598 | 34 768 / 20 571 → 24 830 |
| Fecha, producto | 2019-02-15, Terra (MOD11A1, MCD43A3, MOD13A2, MCD15A2H) | ídem |
| Meteorología | ERA5 vía Open-Meteo (caché de la corrida del 2026-11-06) | ERA5 vía Open-Meteo, 2019-02-14 … 16 |

Corridas completas de `earthflux(aoi, as.Date("2019-02-15"), "era5",
preset)` con `idaho2002_elev` (y `idaho2002_flat` como sensibilidad):
**v1** = `main` antes de este cambio (preset versión 1, criterios M5-10,
z_om `NA` donde LAI = 0); **v2** = esta rama (versión 2, criterios M5-23,
mínimo de z_om M5-24).

**Limitaciones de la escena del Maule (solo de esta evaluación).** El
límite diario de la API gratuita de Open-Meteo se agotó durante la
evaluación (HTTP 429, "Daily API request limit exceeded"): solo se pudo
descargar una petición de 100 puntos ERA5 para 2019-02-14 … 16. Por eso
(a) el límite sur del AOI se movió de −36,6 a −35,87 (todos los puntos
ERA5 necesarios, con el búfer de una celda, están en esa petición: filas
−34,5 … −36,0) y (b) la ventana de ERA5 empieza un día después del defecto
(`days_before = 1` en lugar de 2; el día omitido no entra en la ETr del
2019-02-15 ni en las 24 h previas que usan las reglas nocturnas). El AOI
evaluado cubre el valle central del Maule de Curicó a Talca y San Clemente,
la costa y la cordillera hasta ~4500 m; deja fuera Linares, Parral y
Cauquenes.

## 2. Intención física (manual SEBAL-Idaho, Waters et al., 2002)

- Ancla fría: "wet, well-irrigated crop surface having full ground cover by
  vegetation" (p. 23); campo agrícola bien regado de cobertura plena, "very
  cold, but not extremely cold" (ap. 7, pp. 66–67, pasos 5 y 7); guías:
  albedo 0,22–0,24 (alfalfa de referencia), LAI 4–6 (cobertura plena,
  LAI > 3), cerca de la estación.
- Ancla caliente: "dry, bare agricultural field where ET is assumed to be
  zero" (p. 23; p. 31, paso 5b); no un desierto, asfalto, techo o ladera de
  montaña (ap. 7, p. 72, paso 2); albedo "similar to other dry and bare
  fields", LAI 0–0,4 (paso 3); no el píxel más caliente (p. 73).

## 3. Lo que mostraron los datos

1. **Frío.** Las celdas con NDVI en el 10 % más alto de cada escena son
   sobre todo plantaciones forestales y bosque (cordillera de la Costa en
   Cauquenes, a ~450 m; precordillera andina en el Maule, a 600–1500 m),
   con albedo de cielo blanco 0,10–0,13 y LST 294–303 K. Las del valle
   (< 300 m), de cultivo, tienen albedo 0,14–0,21. El límite inferior de
   0,18 de v1 dejaba 3 (Cauquenes) y 6 (Maule) candidatos; 0,14 separa los
   doseles perennes oscuros de los cultivos. El LAI ≥ 3 absoluto no
   discrimina (el LAI MODIS de esas celdas es 3–6 en ambos grupos).
2. **Caliente.** Con v1 (LAI ≤ 0,4 absoluto), en el Maule los candidatos
   estaban casi todos en laderas andinas secas (1400–2300 m, albedo
   0,11–0,15), justo lo que el manual desaconseja; en Cauquenes había solo
   10 celdas con LAI ≤ 0,4. Las celdas de NDVI bajo del valle (< 300 m)
   tienen albedo mediano 0,19–0,20 (Cauquenes 0,204; Maule 0,191) y las
   laderas andinas secas, percentil 95 de 0,165: el límite inferior de 0,18
   deja fuera la roca oscura y conserva los campos secos.
3. El paso de relajación no se usó en ninguna escena (paso 1 para ambas
   clases en las cuatro corridas `elev`).

## 4. Resultados (`idaho2002_elev`)

Candidatos = celdas que pasan las reglas y la homogeneidad (antes de elegir
el 20 % más frío/caliente); rango = fracción de celdas de la escena con LST
≤ la del ancla.

### 4.1 Anclas

| Escena | Versión | Frío: cand. / sel. | Frío: Ts (rango), NDVI, α, LAI, z | Caliente: cand. / sel. | Caliente: Ts (rango), NDVI, α, LAI, z (mín.–máx.) |
|---|---|---|---|---|---|
| Cauquenes | v1 | 3 / 1 | 302,74 K (0,34), 0,785, 0,199, 4,78, 131 m | 9 / 2 | 307,17 K (0,99), 0,226, 0,209, 0,35, 151 m (131–172) |
| Cauquenes | v2 | 22 / 5 | 299,43 K (0,20), 0,814, 0,146, 6,40, 419 m | 447 / 92 | 307,14 K (0,99), 0,294, 0,202, 0,53, 145 m (115–234) |
| Maule | v1 | 6 / 3 | 299,97 K (0,26), 0,752, 0,190, 3,29, 125 m | 275 / 56 | 313,83 K (0,98), 0,248, 0,132, 0,34, 1931 m (1406–2309) |
| Maule | v2 | 20 / 5 | 299,71 K (0,24), 0,752, 0,173, 2,79, 260 m | 235 / 49 | 307,24 K (0,79), 0,293, 0,199, 0,51, 303 m (115–2450) |

### 4.2 ETrF y ETa₂₄ (todas las celdas con ETa₂₄)

| Escena | Versión | ETrF p1 / p5 / p50 / p95 / p99 | ETrF > 1,05 | ETrF < 0 | ETa₂₄ p1 / p5 / p50 / p95 / p99 (mm d⁻¹) |
|---|---|---|---|---|---|
| Cauquenes | v1 | −0,04 / 0,12 / 0,69 / 2,03 / 2,26 | 30,9 % | 1,6 % | −0,3 / 0,9 / 4,9 / 12,8 / 13,7 |
| Cauquenes | v1 + mínimo de z_om ¹ | −0,04 / 0,12 / 0,69 / 2,03 / 2,26 | 30,8 % | 1,6 % | −0,3 / 0,9 / 4,9 / 12,8 / 13,7 |
| Cauquenes | v2 | −0,03 / 0,07 / 0,45 / 1,73 / 1,92 | 20,6 % | 1,8 % | −0,2 / 0,5 / 3,2 / 10,9 / 11,9 |
| Maule | v1 | −0,13 / 0,14 / 1,02 / 1,32 / 1,49 | 41,3 % | 2,2 % | −0,8 / 0,9 / 6,9 / 8,7 / 9,6 |
| Maule | v1 + mínimo de z_om ¹ | −0,23 / −0,05 / 0,97 / 1,30 / 1,47 | 34,4 % | 6,5 % | −1,4 / −0,3 / 6,6 / 8,6 / 9,5 |
| Maule | v2 | −4,79 / −3,71 / 0,72 / 1,37 / 1,64 | 20,0 % | 31,9 % | −29,5 / −23,1 / 4,9 / 9,1 / 10,6 |

¹ Criterios v1 con el mínimo de z_om de v2, calculado con
`workflow_metric()` sobre las mismas entradas preparadas (no es un preset
publicado): separa el efecto del mínimo del de los criterios.

### 4.3 ETrF por banda de elevación (`elev`)

| Escena | Versión | z ≤ 300 m: mediana, > 1,05, < 0 | 300–1000 m | > 1000 m |
|---|---|---|---|---|
| Cauquenes | v1 | 0,57; 19,6 %; 1,6 % (n = 4850) | 1,26; 62,3 %; 1,6 % (n = 1733) | — |
| Cauquenes | v2 | 0,36; 15,1 %; 1,9 % (n = 4865) | 0,84; 35,8 %; 1,6 % (n = 1733) | — |
| Maule | v1 | 1,04; 47,0 %; 0,0 % (n = 9303) | 1,07; 57,8 %; 0,0 % (n = 6183) | 0,56; 11,0 %; 9,0 % (n = 5085) |
| Maule | v2 | 0,97; 34,0 %; 0,0 % (n = 9449) | 0,90; 27,4 %; 2,4 % (n = 6186) | −2,26; 0,6 %; 84,7 % (n = 9195) |

### 4.4 Sensibilidad: `idaho2002_flat` (mismas anclas)

| Escena | Versión | ETrF p1 / p5 / p50 / p95 / p99 | > 1,05 | < 0 |
|---|---|---|---|---|
| Cauquenes | v1 | −0,01 / 0,16 / 0,80 / 2,06 / 2,28 | 36,0 % | 1,1 % |
| Cauquenes | v2 | 0,00 / 0,07 / 0,42 / 1,56 / 1,70 | 19,8 % | 1,1 % |
| Maule | v1 | −0,08 / 0,33 / 1,05 / 1,42 / 1,61 | 49,2 % | 1,5 % |
| Maule | v2 | −1,16 / −0,56 / 0,85 / 1,40 / 1,63 | 28,7 % | 14,0 % |

## 5. Lectura

1. **Las anclas v2 responden mejor a la intención del manual**: el ancla
   caliente queda en campos secos de baja elevación en ambas escenas
   (mediana de los píxeles 141–143 m; en el Maule, 4 de sus 49 píxeles
   están sobre 1000 m, hasta 2450 m), y la fría, entre celdas de NDVI alto
   con albedo de dosel no forestal. Ninguna escena necesitó relajación.
2. **Cauquenes sigue siendo una escena difícil**: es secano costero; las
   celdas más frías de NDVI alto son plantaciones (albedo 0,11–0,13,
   excluidas) y el ancla fría v2 (299,4 K, rango 0,20) cae en el borde
   de esas plantaciones (albedo 0,146, píxeles a 303–471 m), no en un
   cultivo regado.
   Un 20,6 % de las celdas queda con ETrF > 1,05 (p99 1,92): las celdas más
   frías que el ancla son bosque costero, más frío también por la
   influencia marina, lo que contradice el supuesto de clima uniforme
   (manual, ap. 7, p. 70). Mejor que v1 (30,9 %, p99 2,26), pero **todavía
   no es verosímil**.
3. **Maule: el valle mejora, la cordillera empeora.** Con v1 el ancla
   caliente andina (Ts_datum ≈ 325,6 K con Γ = 0,0065 K m⁻¹ y 1931 m) dejaba
   ETrF ≈ 1 en todo el valle (mediana 1,04; 47 % > 1,05 bajo 300 m). Con
   v2 el valle baja a mediana 0,97 (34 % > 1,05), aún alto, y las laderas
   sobre 1000 m quedan muy por encima del ancla caliente en Ts_datum: H se
   extrapola y ETrF cae a −2,3 de mediana (84,7 % < 0). El 31,9 % de
   ETrF < 0 de toda la escena viene de ahí; con `flat` baja a 14,0 %.
4. **Mínimo de z_om (M5-24).** Hace calculables las celdas con LAI = 0:
   15 en Cauquenes (z ≈ 150 m, ETrF mediana 0,19) y **4259 en el Maule**,
   casi todas roca y suelo desnudo andino (mediana 2668 m), con ETrF
   mediana −2,97 (95 % < 0). Sobre las celdas que ya tenían ETa con v1, el
   Maule v2 da 18,8 % de ETrF < 0. Son valores con flags
   (`EF_H_ZOM_FLOOR_APPLIED`, `EF_H_DT_EXTRAPOLATED_HOT`,
   `EF_H_GT_AVAILABLE`, `EF_ET_NEGATIVE`), no correcciones; el ETa de
   montaña de una sola recta dT(Ts_datum) calibrada en el valle no es
   utilizable.
5. **Pendiente (no resuelto aquí):** una regla para el relieve (máscara o
   zonas de elevación, partir la escena como sugiere el manual en el ap. 7,
   p. 70, o el ajuste de montaña de METRIC), la selección sobre Ts o
   Ts_datum (D-AP-07), la rugosidad de coberturas no agrícolas (bosques
   0,5 m en el ap. 2 del manual frente a 0,018·LAI ≤ 0,12 m) y una escena
   con datos de referencia para validar.

## 6. Criterios adoptados (versión 2 de los presets, `CANDIDATA`)

| Elemento | v1 (M5-10) | v2 (M5-23) |
|---|---|---|
| Frío | `lai >= 3`, `albedo` [0,18; 0,25], `ndvi >= p0.90` | `ndvi >= p0.90`, `albedo` [0,14; 0,26] |
| Caliente | `lai <= 0.4`, `ndvi > 0`, `albedo` [0,10; 0,35] | `ndvi <= p0.10`, `ndvi > 0`, `albedo` [0,18; 0,35] |
| Relajación (un paso) | frío `lai >= 2` | frío `ndvi >= p0.80`, caliente `ndvi <= p0.20` |
| Homogeneidad, selección, dominio | sd(LST) ≤ 1,5 K en 3 × 3 (ventana completa); 20 % más frío / caliente; `"land"`, tipo 7 | sin cambio |
| QA de anclas | estricto (M5-10, M5-22) | + sin `EF_SURF_LAI_ASSIGNED` (LAI asignado por `lai_nonveg`) |

Los umbrales se fijaron con la distribución de NDVI y albedo de estas dos
escenas (§3), no ajustando ETrF; no tienen fuente primaria.
