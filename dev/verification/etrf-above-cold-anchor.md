# ETrF > 1,05: celdas más frías que el ancla fría (diagnóstico)

Fecha: **2026-11-11**. Autor: Guillermo Servando Fuentes-Jaque.
Presets: versión 5 (`idaho2002_elev`, `idaho2002_flat`). Especificación:
`specs/presets.md` §4 (criterios de anclas, M5-23). Antecedentes:
`verification/anchors-m5-23.md`, `verification/terrain-rule.md`.
Estado: **pregunta abierta para el autor** (`DECISIONS.md` §1.5, A-M5-1);
no hay decisión nueva ni cambio de presets.

> **Diagnóstico de coherencia, no validación.** No hay datos de
> referencia para estas escenas. Las cifras explican *por qué* la cadena
> produce ETrF > 1,05, no si la ET es correcta. Ninguna cifra cambia el
> estado `CANDIDATA` de los criterios. No se versionan datos descargados
> (MODIS, NASADEM, ERA5, MCD12Q1): solo números.

## 1. Pregunta y respuesta corta

Con `earthflux()` (versión 5, ERA5, 2019-02-14, Terra a 12–18° del
nadir) el **19,2 %** de las celdas de la provincia de Cauquenes tiene
ETrF > 1,05 (p99 1,48). En METRIC la ETrF del ancla fría es 1,05 por
construcción (Hcold = Rn − G − 1,05 λETr; Waters et al., 2002, p. 30,
paso 5a), de modo que ETrF > 1,05 indica, en general, celdas más frías
(en Ts_datum) que el ancla fría, donde la recta dT(Ts_datum) se
extrapola por debajo del punto frío.

**Respuesta.** En Cauquenes el ancla fría no es un cultivo regado de
cobertura completa (no existe a 1 km en la provincia: 20 celdas
`CRO` en MCD12Q1), sino **un solo píxel de borde de bosque** (MCD12Q1
`EBF`, fracción forestal 1,0) cuyo albedo, 0,1403, apenas supera el límite
inferior de la banda fría (0,14). De las 314 celdas con NDVI ≥ p0,90,
**313 tienen albedo < 0,14** (plantaciones y bosque de la Cordillera de
la Costa) y quedan fuera de los candidatos; el ancla queda en la
**mediana** de ese conjunto (percentil 45 en `elev`, 64 en `flat`) y en
el **percentil 16,5** de Ts_datum de la escena. Las celdas más frías que
ella (607, el 16,5 %; ya marcadas con `EF_H_DT_EXTRAPOLATED_COLD`) son
bosques oscuros a menos de 20 km del mar: el 94 % de ellas tiene
ETrF > 1,05 y explican el **81 %** (`elev`) y el **86 %** (`flat`) de las
celdas con ETrF > 1,05. En el 56–60 % de las celdas con ETrF > 1,05 la
extrapolación da dT < 0 (H < 0, estable). El exceso medio de ETrF sobre
1,05 (0,15 en `elev`) viene en un 67 % de un H menor que el del ancla,
en un 23 % de más energía disponible (Rn − G: albedo más bajo) y en un
11 % de una ETr menor que la del ancla. La ETr (sesgo uniforme o variación
espacial del IDW) y la rugosidad de los bosques no lo explican.

En el **Maule** (rectángulo regional, misma fecha) el problema casi no
existe: **2,9 %** (`elev`) y **2,7 %** (`flat`). El ancla fría tiene 26–33
píxeles (bosque nativo de precordillera, ~560 m), en el percentil 6 del
conjunto de NDVI alto y en el percentil 2,5 de Ts_datum de la escena. Las
cifras de ~30 % de corridas anteriores eran del 2019-02-15 (Terra a
52–65°, ERA5 recortado a −35,87°) y ya no se reproducen.

## 2. Escenas, corridas y método

| | Cauquenes | Maule |
|---|---|---|
| AOI | polígono `inst/extdata/cauquenes-province.gpkg` | rectángulo −72,8 … −70,3 / −36,6 … −34,7 (EPSG:4326) |
| Fecha, LST | 2019-02-14, MOD11A1 (mediana \|ángulo\| 15°, 0 celdas > 40°) | 2019-02-14, MOD11A1 (22°, 0 celdas > 40°) |
| Celdas en el AOI / con ETa₂₄ (`elev`; `flat`) | 3779 / 3670; 3627 | 55 967 / 31 302; 29 821 |
| Meteorología | ERA5 vía Open-Meteo, 33 puntos (23 usados, 10 de mar excluidos) | ERA5 vía Open-Meteo, 107 estaciones virtuales (descarga del 2026-11-11) |
| Regla de terreno | `elev` 0 celdas; `flat` 43 | `elev` 17 855; `flat` 19 336 |

1. Corridas completas `earthflux(aoi, as.Date("2019-02-14"), "era5",
   preset)` sobre `main` (75a1f77). Las cifras de Cauquenes `elev`
   reproducen las de `specs/presets.md` §8, hallazgo 6 (ETrF > 1,05
   19,2 %, p99 1,48, anclas 302,16 K y 315,60 K).
2. Se capturaron las entradas de `workflow_metric()` (la cadena METRIC de
   `earthflux()`) y se volvió a correr la cadena con cada variante
   (código de evaluación fuera del paquete): la corrida base sobre esas
   entradas reproduce exactamente la de `earthflux()`.
3. **Cobertura MCD12Q1 2019** (C6.1, tesela h12v12, IGBP `LC_Type1`, LP
   DAAC con `EARTHDATA_TOKEN`): solo para este diagnóstico, no se agrega
   al paquete. Moda de los 2 × 2 píxeles de 463 m en cada celda de 1 km,
   fracción forestal (clases 1–5) y fracción de agua (17).
4. **Distancia al océano:** distancia a la mancha de agua de MCD12Q1
   conectada al borde oeste de la ventana (océano), a 463 m, interpolada a
   la grilla.
5. **Descomposición del exceso** respecto del punto de calibración frío
   (A = Rn − G, H, E = λ·ETr_inst en W m⁻²; subíndice c = ancla fría), exacta
   por celda (error máximo 4·10⁻¹⁶):
   ETrF − 1,05 = (A − A_c)/E − (H − H_c)/E + 1,05·(E_c/E − 1).

Figuras (PNG generadas por el código de evaluación; no se versionan):

- `f1_cauquenes_elev_mapas.png`: a la izquierda, ETrF de Cauquenes
  (`elev`) con las clases > 1,05 en rojo, el ancla fría (círculo), los
  36 píxeles del ancla caliente (triángulos) y las isolíneas de 10 y 20 km
  al océano; a la derecha, Ts_datum − Ts_datum,frío. Las celdas con
  ETrF > 1,05 forman la franja occidental (Cordillera de la Costa y
  litoral) y coinciden con las celdas azules (más frías que el ancla); el
  ancla fría está en el borde oriental de esa franja, a 25 km del mar, y
  el llano interior (secano) es 3–20 K más cálido.
- `f2_maule_elev_mapas.png`: lo mismo para el Maule. Las anclas frías
  están en el extremo sureste (precordillera, ~560 m); solo una franja
  litoral y algunos bosques de precordillera quedan más fríos que ellas.
- `f3_tsdatum_etrf.png`: ETrF frente a Ts_datum, por clase (otras;
  vegetación oscura, albedo < 0,14 y NDVI ≥ 0,7; con agua), con las anclas.
  En Cauquenes la nube es casi una recta (un solo forzamiento efectivo):
  todo lo que queda a la izquierda del ancla fría sube por encima de 1,05,
  y es vegetación oscura. En el Maule la nube es más ancha (Rn − G y ETr
  varían más) y el ancla queda en el extremo frío.
- `f4_descomposicion.png`: aporte medio de cada término al exceso, en las
  cuatro corridas.
- `f5_cauquenes_clases.png`: fracción de celdas con ETrF > 1,05 por
  distancia al océano y por cobertura MCD12Q1 (Cauquenes, `elev`).

## 3. Resultado base

| Escena, preset | n | ETrF > 1,05 | > 1,10 | < 0 | p50 / p90 / p99 / máx. | Ancla fría: píxeles, Ts, z, albedo, NDVI, LAI, MCD12Q1 | Ancla caliente | dT_frío | a; b |
|---|---|---|---|---|---|---|---|---|---|
| Cauquenes `elev` | 3670 | **19,2 %** | 14,1 % | 1,0 % | 0,57 / 1,14 / 1,48 / 1,67 | **1** (`EF_ANCHOR_SINGLE_PIXEL`), 302,16 K, 359 m, 0,140, 0,82, 6,2, EBF | 36 px, 315,60 K, 148 m | 0,28 K | −111,1; 0,369 |
| Cauquenes `flat` | 3627 | 19,2 % | 14,6 % | 1,1 % | 0,54 / 1,14 / 1,37 / 1,54 | el mismo píxel | 34 px, 315,64 K | 0,25 K | −99,3; 0,329 |
| Maule `elev` | 31 302 | **2,9 %** | 1,4 % | 0,9 % | 0,61 / 0,93 / 1,12 / 1,36 | 26, 298,01 K, 566 m, 0,145, 0,83, EBF | 233 px, 315,42 K | 1,39 K | −76,3; 0,261 |
| Maule `flat` | 29 821 | 2,7 % | 1,3 % | 1,1 % | 0,55 / 0,88 / 1,12 / 1,29 | 33, 298,18 K, 557 m, 0,146, 0,82, EBF | 224 px, 315,45 K | 1,32 K | −65,2; 0,223 |

Embudo del frío en Cauquenes `elev`: 3132 celdas utilizables → 314 con
NDVI ≥ p0,90 (0,800) → **1** con albedo en [0,14; 0,26] → 1 homogénea →
1 elegida (con `flat`: 310 → 3 → 2 → 1, el mismo píxel). En el Maule
`elev`: 28 261 → 2827 → 222 → 130 → 26.

## 4. Hipótesis

### H1. Posición del ancla fría — **apoyada** (Cauquenes); parcial (Maule)

| | Cauquenes `elev` | Cauquenes `flat` | Maule `elev` | Maule `flat` |
|---|---|---|---|---|
| Percentil de Ts_datum,frío en la escena | **16,5** | 16,9 | 2,5 | 1,2 |
| Percentil del ancla en el conjunto NDVI ≥ p0,90 | 45 | 64 | 6 | 6 |
| Celdas con Ts_datum < Ts_datum,frío (= `EF_H_DT_EXTRAPOLATED_COLD`) | 607 | 614 | 777 | 356 |
| … con ETrF > 1,05 | 93,9 % | 98,0 % | 55,3 % | 70,8 % |
| **Celdas con ETrF > 1,05 que son más frías que el ancla** | **80,7 %** | **86,4 %** | 46,7 % | 30,8 % |
| … más frías por más de 0,5 / 1 / 2 K | 61,8 / 51,1 / 36,4 % | 68,7 / 50,5 / 25,8 % | 39,6 / 33,7 / 25,3 % | 17,9 / 9,9 / 3,3 % |
| Ancla de un píxel | sí | sí | no (26) | no (33) |

"El 20 % más frío y luego la media" frente a los candidatos más fríos:
en Cauquenes no cambia nada (hay **un** candidato). En el Maule, el 5 %
más frío (7 píxeles, 297,49 K) baja ETrF > 1,05 de 2,9 a 2,3 % y el más
frío (1 píxel, 296,74 K) a 1,3 % (`elev`; §6, opciones a1 y a2). Lo que
decide la cifra es **a qué percentil de la escena cae el ancla**, y eso
lo fija el conjunto de candidatos, no la regla de elección dentro de él.

### H2. Superficies con ETrF > 1,05 — **apoyada** (vegetación oscura, bosque)

Cauquenes `elev` (fracción de la clase con ETrF > 1,05; parte de todas
las celdas > 1,05):

| Clase | n | > 1,05 en la clase | Parte del total > 1,05 |
|---|---|---|---|
| Albedo ≤ 0,12 / 0,12–0,14 / 0,14–0,16 / > 0,16 | 335 / 1110 / 614 / 1611 | 71,6 / 37,9 / 6,5 / 0,4 % | 34,0 / 59,6 / 5,7 / 0,7 % |
| NDVI > 0,8 / 0,7–0,8 / 0,5–0,7 / ≤ 0,5 | 428 / 556 / 888 / 1798 | 73,6 / 38,8 / 16,7 / 1,5 % | 44,6 / 30,6 / 21,0 / 3,8 % |
| LAI > 4 / 3–4 / ≤ 3 | 1060 / 194 / 2416 | 51,0 / 28,4 / 4,6 % | 76,6 / 7,8 / 15,6 % |
| **Vegetación oscura** (albedo < 0,14 y NDVI ≥ 0,7) | 937 | 56,6 % | **75,1 %** |
| Con agua (MCD12Q1 17 en la celda) | 13 | 100 % | 1,8 % |
| MCD12Q1 EBF / ENF / WSA / SAV / CRO | 1340 / 197 / 579 / 1437 / 20 | 44,6 / 22,3 / 6,6 / 0,1 / 0,0 % | 84,7 / 6,2 / 5,4 / 0,1 / 0 % |
| **Bosque MCD12Q1** (clases 1–5) | 1544 | — | **91,6 %** |
| Distancia al océano 0–5 / 5–10 / 10–20 / 20–40 / > 40 km | 321 / 371 / 608 / 1413 / 957 | 72,0 / 59,3 / 37,8 / 1,8 / 0,0 % | 32,7 / 31,2 / 32,6 / 3,5 / 0 % |
| Elevación ≤ 100 / 100–200 / 200–300 / 300–400 / 400–600 / > 600 m | 258 / 1811 / 734 / 360 / 454 / 53 | 67,4 / 7,9 / 11,0 / 23,9 / 42,5 / 54,7 % | 24,6 / 20,3 / 11,5 / 12,2 / 27,3 / 4,1 % |

Con `flat`: vegetación oscura 80,5 %, bosque 94,8 %, < 20 km del mar
94,3 % del total > 1,05. Maule `elev`/`flat`: vegetación oscura 81,5 / 82,8 %,
bosque 89,8 / 93,4 %, < 20 km del mar 30,9 / 11,6 % (el resto, bosques de
precordillera a 400–1065 m cerca de las anclas frías).

- **Bosque y plantaciones oscuros** (albedo < 0,14, excluidos de los
  candidatos por la banda de albedo y más fríos que el ancla de tipo
  cultivo): son la superficie dominante. En la franja litoral de
  Cauquenes (< 20 km) la LST media es 301,6–303,0 K y el albedo medio
  0,12–0,13, frente a 309,4–310,9 K y 0,16–0,19 en el llano.
- **Agua:** 13 celdas (1,8 % del total); no explica la cifra.
- **Costa y aire marino:** la elevación ≤ 100 m y la distancia < 10 km
  concentran la ETrF más alta (mediana 1,18–1,20), pero allí casi todo es
  bosque (fracción forestal 0,63–0,85): costa y cobertura están
  confundidas. La temperatura del aire ERA5 a las 15 UTC (IDW de las celdas
  de tierra) es solo 1,3 K más baja en la costa (22,0 °C a < 5 km frente a
  23,3 °C a > 40 km; 22,35 °C en el ancla fría); medida contra Ts − Ta en
  lugar de Ts, la parte de las celdas > 1,05 más frías que el ancla baja
  apenas de 80,7 a 77,5 % (`elev`) y de 86,4 a 80,9 % (`flat`). Las celdas
  ERA5 de mar (15–17 °C, excluidas por M5-15) muestran que el gradiente
  real puede ser mayor y que la resolución de 0,25° no lo resuelve: con
  estos datos el efecto marino **no se puede separar** del de la
  cobertura.

### H3. Meteorología y ETr — **no apoyada** (Cauquenes); parcial (Maule)

- Variación espacial de ETr_inst en las celdas (IDW, C2): Cauquenes p1 /
  p50 / p99 0,737 / 0,792 / 0,842 mm h⁻¹ (ancla fría 0,777); Maule 0,692 /
  0,743 / 0,819 (0,726). ETr₂₄: 8,0 / 9,0 / 9,7 y 6,6 / 8,0 / 9,4 mm d⁻¹.
- Término de ETr en la descomposición: 10,6 % (`elev`) y 11,3 % (`flat`)
  del exceso en Cauquenes; 11,9 y 34,2 % en el Maule.
- **ETr uniforme** (mediana de la escena; cadena completa): ETrF > 1,05
  19,2 → 18,3 % (Cauquenes `elev`), 2,9 → 2,5 % (Maule `elev`). Con la
  misma LE y ETr = ETr del ancla, dejan de pasar 1,05 el 5,2–5,5 % de las
  celdas > 1,05 en Cauquenes y el 22–24 % en el Maule.
- **Sesgo uniforme de ETr** (×1,10 y ×0,90, cadena completa): 18,6 y
  20,4 % (Cauquenes `elev`). El sesgo no se cancela del todo porque
  cambia Hcold = Rn − G − 1,05 λETr y con él la pendiente de la recta
  (b = 0,369 → 0,423 y 0,323), pero el efecto es de ±1 punto. En ETa₂₄ el
  sesgo pasa casi entero (media 5,64 → 6,21 y 5,11 mm d⁻¹).
- Nota para la ETa, no para la ETrF: la franja costera recibe por IDW la
  ETr₂₄ de las celdas ERA5 de tierra (8,3 mm d⁻¹ a < 5 km del mar; las
  celdas de mar excluidas tenían 3,7–6,9 mm d⁻¹), de modo que la ETa₂₄
  media allí llega a 9,8 mm d⁻¹ (ETrF 1,20 × 8,3).
- Con `flat` las cifras son las mismas (ETr no depende del preset).

### H4. Linealidad dT–Ts y estabilidad — **apoyada** (Cauquenes); no (Maule)

| | Cauquenes `elev` | Cauquenes `flat` | Maule `elev` | Maule `flat` |
|---|---|---|---|---|
| dT del ancla fría | 0,28 K | 0,25 K | 1,39 K | 1,32 K |
| Celdas > 1,05 con dT < 0, H < 0 y L > 0 (estable) | **55,8 %** | 60,4 % | 1,4 % | 0,0 % |
| Exceso medio sobre 1,05 | 0,151 | 0,120 | 0,060 | 0,056 |
| Parte del exceso por −ΔH (H menor que el del ancla) | **66,6 %** | 58,2 % | 34,5 % | 8,7 % |
| … por Δ(Rn − G) | 22,8 % | 30,4 % | 53,6 % | 57,0 % |
| … por ETr | 10,6 % | 11,3 % | 11,9 % | 34,2 % |
| Término dominante (celdas): H / Rn − G / ETr | 58 / 36 / 6 % | 64 / 28 / 8 % | 33 / 45 / 23 % | 6 / 54 / 41 % |

En Cauquenes el ancla fría tiene un dT casi nulo (0,28 K, H = 25 W m⁻²):
basta que una celda esté 0,75 K más fría para que la recta dé dT < 0 y
H < 0 (estable; las 398 celdas con `EF_H_NEGATIVE`). Las celdas > 1,05
tienen en media Rn = 654, G = 56 y H = −27 W m⁻² frente a 629, 50 y 25 en
el ancla. La extrapolación de la recta por debajo del punto frío produce
dos tercios del exceso; el resto es energía disponible (bosques más
oscuros que el ancla: más Rs absorbida) y ETr. Las 136 celdas > 1,05
que **no** son más frías que el ancla (3,7 % de las celdas) están cerca de
1,05 (exceso medio 0,03) y deben su exceso a Rn − G. En el Maule el ancla
tiene dT = 1,4 K y la escena no llega a la rama estable: el pequeño
exceso viene de Rn − G y ETr.

### H5. Mezcla a 1 km — **parcial**

- El ancla fría de Cauquenes pasa la homogeneidad con sd(LST, 3 × 3) =
  **1,32 K** (límite 1,5 K; mediana de la escena 1,17 K, p90 2,15 K). Su
  ventana va de 300,80 a 304,74 K: 3 de los 8 vecinos son más fríos
  (300,80–301,50 K; bosque con albedo 0,131–0,137, ETrF 1,09–1,13), uno
  igual (302,18 K) y 4 más cálidos y menos densos (302,60–304,74 K; NDVI
  0,54–0,74, albedo 0,148–0,158). Es un píxel de **transición**
  en el borde oriental del bosque: su albedo de 0,1403 (solo 0,0003 sobre
  el límite) y su Ts intermedia son las de una mezcla, no las del "centro
  de un campo" que pide el manual (p. 67, paso 7).
- A 500 m (MCD12Q1) la celda es bosque en sus 4 subpíxeles (fracción 1,0):
  la mezcla es de densidad y temperatura dentro del bosque y con el borde,
  no con un cultivo.
- En el Maule los 26 píxeles fríos tienen sd de 0,35 a 1,48 K, todos EBF.
- Elegir dentro de una ventana más homogénea no cambia el resultado de
  fondo: sin candidatos alternativos con albedo ≥ 0,14 el ancla sigue
  siendo de bosque (§6, a1–a4).

### Hipótesis adicional H6. Rugosidad de los bosques — **no apoyada**

z_om = 0,018·LAI (M5-24) da 0,11 m con LAI 6, frente a 0,5 m para
bosques en el apéndice 2 del manual (p. 44). Con z_om = 0,5 m en las celdas
MCD12Q1 1–5 (variante de diagnóstico) ETrF > 1,05 pasa de 19,2 a 18,9 %
(Cauquenes `elev`) y el p99 sube de 1,48 a 1,57: con dT < 0, una rah menor
hace H **más** negativo. La rugosidad no explica la cifra.

## 5. Tabla de hipótesis

Parte de las celdas con ETrF > 1,05 explicada (Cauquenes `elev` /
`flat`; Maule `elev` / `flat`):

| Hipótesis | Veredicto | Parte explicada |
|---|---|---|
| H1 Posición del ancla (celdas más frías que el ancla en Ts_datum) | **Apoyada** en Cauquenes; parcial en el Maule | 80,7 / 86,4 %; 46,7 / 30,8 % |
| H2 Vegetación oscura (albedo < 0,14, NDVI ≥ 0,7) / bosque MCD12Q1 | **Apoyada** | 75,1 / 80,5 %; 81,5 / 82,8 % (bosque: 91,6 / 94,8 %; 89,8 / 93,4 %) |
| H2 Agua | No apoyada | 1,8 / 1,9 %; 3,2 / 2,1 % |
| H2 Costa (< 20 km) | Confundida con el bosque; efecto marino no separable con ERA5 a 0,25° | 96,5 / 94,3 %; 30,9 / 11,6 % (frías también en Ts − Ta: 77,5 / 80,9 %) |
| H3 ETr (variación espacial; sesgo uniforme ±10 %) | **No apoyada** en Cauquenes; parcial en el Maule | caen bajo 1,05 con ETr uniforme: 5,2 / 5,5 %; 22,2 / 23,7 %; ±10 % → ±1 punto |
| H4 Extrapolación (H menor que el del ancla; rama estable) | **Apoyada** en Cauquenes; no en el Maule | parte del exceso: 66,6 / 58,2 %; 34,5 / 8,7 % (H < 0: 55,8 / 60,4 %; 1,4 / 0 %) |
| H4' Rn − G mayor que en el ancla | Parcial | 22,8 / 30,4 %; 53,6 / 57,0 % del exceso |
| H5 Mezcla a 1 km del ancla | Parcial: el ancla es un píxel de borde (sd 1,32 K, albedo 0,1403) | sin cifra propia: el efecto es el de H1 |
| H6 Rugosidad de bosque | No apoyada | −0,3 puntos con z_om = 0,5 m |

## 6. Qué dice el manual

Leído en las páginas renderizadas del PDF (número impreso = página del
PDF).

| Pasaje | Página | Texto |
|---|---|---|
| Rango esperado de ETrF | p. 35 | "One should generally expect ETrF values to range from 0 to 1. At a totally dry pixel, ET = 0 and ETrF = 0. A pixel in a well established field of alfalfa or corn can occasionally have an ET slightly greater than ETr and therefore ETrF > 1, perhaps up to 1.1. However, ETr generally represents an upper bound on ET for large expanses of well-watered vegetation. Negative values for ETrF can occur in SEBAL due to systematic errors caused by various assumptions made earlier in the energy balance process." |
| Ancla fría = 1,05 ETr | p. 30, paso 5a | "Experience in Idaho shows that the most 'cold' (wet) agricultural fields have an ET rate about 5% larger than the reference ET (ETr). Hence, ETcold is assumed to be 1.05 × ETr" |
| Filosofía del frío | ap. 7, p. 66 | "The cold pixel should therefore be selected to represent an agricultural area that has vegetation at 'full cover' and that is well irrigated. Full cover means that the LAI is greater than about 3." |
| Selección | ap. 7, p. 67, pasos 5 y 7 | "Do not select an extreme cold point but one that is representative of a well-watered full cover crop. For the best results, the cold pixel should have a surface albedo in the range of 0.22 to 0.24 …"; "Select Tcold from a pixel in the center of the chosen field that represents a very cold, but not extremely cold, point in the image." |
| Ejemplo | ap. 7, p. 71 | "If this image was for July or early August rather than early April, more fields would be well-watered. In this case, we would not select this field because this may represent an extremely cold condition (the coldest in the region)." y "If the 'cold' pixel is far from the weather station, it is possible that the field is 'cold' because of varying weather conditions." |
| Clima uniforme | ap. 7, p. 70 | "… one basic assumption in SEBAL is that climate conditions are uniform within the area of interest. Where weather varies, one may consider splitting the image into two or more parts and apply SEBAL to each part separately, with unique cold and hot pixels for each part." |
| Bosques | p. 28; ap. 2, p. 44 | "trees generally have smaller albedo than agricultural crops" (p. 28); "Forests; zom = 0.5 m" (p. 44) |

Allen et al. (2012, IAHS Publ. 352), p. 74: en METRIC se fija un límite
inferior del albedo para vegetación alta o rala ("forest, riparian and
tall corn") porque la vista al nadir de Landsat subrepresenta el albedo
hemisférico por las sombras, y "A similar adjustment is sometimes made to
computed surface temperature (Ts) to account for the lowering effect of
nadir-viewed shadows in tall or semi-sparse vegetation where the computed
Ts may run cooler than bulk Ts."

Lectura: el manual **no** da una regla para las celdas más frías que el
ancla ni para recortar ETrF > 1; dice qué esperar (0 a 1, hasta ~1,1 en
alfalfa o maíz; ETr como cota superior para grandes extensiones de
vegetación bien regada), que el frío debe ser un cultivo regado de
cobertura completa "very cold, but not extremely cold", y que donde el
clima varía la imagen se parte. Ninguna fuente verificada disponible
respalda ETrF > 1,1 en bosques como hecho físico; Allen et al. (2012)
señala lo contrario: Ts y albedo de la vegetación alta pueden quedar
sesgados hacia lo frío y lo oscuro (con Landsat; MODIS de 1 km no se
evalúa allí).

## 7. Opciones y efecto estimado

Corridas de la cadena con cada variante (código de evaluación, no del
paquete). "Interior" = celdas a ≥ 20 km del océano (Cauquenes: secano
interior); en Cauquenes `elev` base: ETrF > 1,05 en la costa 52,4 %, en
el interior 1,1 %, ETrF mediana del interior 0,384, ETa₂₄ media del
interior 3,82 mm d⁻¹.

| Opción | Cauquenes `elev`: > 1,05 / p99 / ETa₂₄ media; ancla fría | Cauquenes `flat`: > 1,05 / p99 | Maule `elev`: > 1,05 / p99; ancla | Efecto colateral |
|---|---|---|---|---|
| Base | 19,2 % / 1,48 / 5,64; 1 px, 302,16 K, albedo 0,140 | 19,2 % / 1,37 | 2,9 % / 1,12; 26 px, 298,01 K | — |
| (a1) frío: el 5 % más frío de los candidatos | sin cambio (1 candidato) | sin cambio | 2,3 % / 1,10; 7 px, 297,49 K | contrario a "not extremely cold" (p. 67) |
| (a2) frío: el candidato más frío | sin cambio | sin cambio | 1,3 % / 1,07; 1 px, 296,74 K | ídem; ancla de un píxel |
| (a3) frío NDVI ≥ p0,80, 20 % | **21,6 %** / 1,51; 2 px, 302,17 K | 20,1 % | 7,7 % / 1,23; 139 px, 300,01 K | empeora: entran candidatos más cálidos |
| (b1) albedo frío [0,10; 0,26] | **8,4 %** / 1,35 / 4,99; 56 px, 300,35 K, albedo 0,121, EBF | 5,0 % / 1,20 | 2,6 % / 1,11; 470 px, 774 m | el ancla pasa a ser **bosque**; interior: ETrF mediana 0,384 → 0,336, ETa₂₄ 3,82 → 3,34 mm d⁻¹ (−13 %) |
| (b2) albedo frío [0,12; 0,26] | 7,7 % / 1,33; 36 px, 300,33 K | 5,5 % / 1,21 | 3,4 % / 1,13 | interior −14 % de ETa₂₄ |
| (b3) [0,10; 0,26] y 5 % más frío | 5,5 % / 1,24; 15 px, 299,63 K | 3,6 % / 1,17 | 1,2 % / 1,06 | interior −22 % de ETa₂₄ (2,98 mm d⁻¹) |
| (c1) recortar ETrF en 1,05 | 0 % (marca el 19,2 %) | 0 % | 0 % | quita el 4,3 % (`elev`), 3,6 % (`flat`) y 0,3 % (Maule) de la ETa₂₄ total; oculta el error (principio 6) |
| (c2) recortar en 1,10 (p. 35, "perhaps up to 1.1") | > 1,10: 0 % (marca el 14,1 %) | marca el 14,6 % | marca el 1,4 % | quita el 3,1 / 2,3 / 0,1 % de la ETa₂₄ |
| (d) calibración aparte costa (< 20 km) / interior, criterios actuales | **imposible**: en la costa 0 candidatos fríos con albedo ≥ 0,14 y 0 calientes | imposible | 7,3 % / 1,41 (costa 28,7 %) | en el Maule aparecen ETrF < 0 (2,5 %) |
| (d') frío por zona (< 20 km), caliente de toda la escena, albedo [0,14; 0,26] | 26,9 % / 1,62 (costa: 1 px, 303,14 K, con relajación) | 25,5 % | 6,4 % / 1,28 | empeora: el frío costero es otro borde |
| (d'') ídem con albedo [0,10; 0,26] (frío de bosque en cada zona) | 8,1 % / 1,34 (< 10 km: 6,0 %) | 5,0 % (3,8 %) | 3,3 % / 1,17 | necesita (b); costa 22 %, interior 0,5 % |
| (e) aceptar como físico en bosques | sin fuente verificada (p. 35 dice lo contrario; Allen et al., 2012, p. 74, apunta a un sesgo frío de Ts) | — | — | — |
| Diagnóstico: ETr uniforme | 18,3 % | 18,1 % | 2,5 % | la ETr no es la causa |
| Diagnóstico: z_om = 0,5 m en bosque | 18,9 % / 1,57 | 18,7 % | 2,8 % | la rugosidad no es la causa |

Lectura de las opciones:

1. **(a)** no actúa donde está el problema: con un candidato no hay nada
   que elegir. En el Maule baja la cifra, pero lleva el ancla hacia el
   extremo frío que el manual pide evitar (pp. 67 y 71).
2. **(b)** es la única variante que baja mucho la cifra en Cauquenes,
   porque cambia **qué es** el ancla fría: un bosque o plantación oscura
   a 1,05 ETr. Así la ETrF de todo el interior baja un 13–22 % (el frío
   pasa de 302,16 a 300,35 K). Sin una fuente que diga que esos bosques
   evapotranspiran a 1,05 ETr (alfalfa), es un cambio del significado de
   la calibración, no una corrección.
3. **(c)** no cambia el balance: recorta la salida. Va contra el
   principio de no corregir valores en silencio (`ARCHITECTURE.md`,
   principio 6). El marcado ya existe por celda: `EF_H_DT_EXTRAPOLATED_COLD`
   (607 celdas en Cauquenes `elev`, exactamente las más frías que el ancla)
   y `EF_H_NEGATIVE` (398). Un umbral de ETrF implausible
   (`EF_ET_ETRF_IMPLAUSIBLE`, clase II) podría apoyarse en el "perhaps up
   to 1.1" de la p. 35, pero es un rango esperado, no un umbral de
   control: decisión del autor.
4. **(d)** tiene apoyo en el manual (p. 70), pero en Cauquenes la franja
   costera no tiene anclas con los criterios actuales, y el gradiente
   meteorológico que la justificaría no está en ERA5 a 0,25°.
5. **(e)** no tiene fuente verificada.

## 8. Recomendación

1. **No cambiar los presets** con esta evidencia. La causa es conocida y
   ya está marcada por celda: en una escena sin cultivos regados de
   cobertura completa a 1 km (secano de Cauquenes), los criterios de M5-23
   dejan como ancla fría el único píxel de NDVI alto que cumple la banda
   de albedo: un borde de bosque en la mediana térmica de los bosques. Las
   celdas de bosque más frías (16,5 % de la escena) reciben ETrF > 1,05 por
   extrapolación, a menudo con H < 0. Ninguna de las opciones evaluadas lo
   corrige sin cambiar el significado del ancla (b) o esconder el valor (c).
2. **Documentar la limitación** en la interpretación de la escena de
   ejemplo (hecho aquí y en `specs/presets.md` §8, hallazgo 7): en
   Cauquenes la ETrF > 1,05 de los bosques costeros es extrapolación
   (marcada con `EF_H_DT_EXTRAPOLATED_COLD`), no un dato de ET de bosque.
3. **Para el autor** (`DECISIONS.md` §1.5, A-M5-1): (i) si una escena cuyo
   ancla fría queda en un píxel (`EF_ANCHOR_SINGLE_PIXEL`) y con más de una
   fracción dada de celdas más frías que ella debe avisar a nivel de
   escena (hoy solo hay flags `info`); (ii) si se quiere un preset o una
   opción para escenas forestales con el frío en vegetación oscura (b),
   con su propia fuente para la ETrF del bosque; (iii) si se registra
   `EF_ET_ETRF_IMPLAUSIBLE` con 1,1 (p. 35) como marca, nunca como
   recorte; (iv) si la costa debe tratarse como sub-imagen cuando haya un
   forzamiento que resuelva el aire marino (estaciones costeras).
4. **Mejora de salida, no implementada:** `summary()` podría mostrar la
   fracción de celdas más frías que el ancla fría (hoy está en el conteo
   de `EF_H_DT_EXTRAPOLATED_COLD` de `res$flags`, 607 de 3670). No se
   tocó el paquete en esta rama.

## 9. Limitaciones

- Un solo día (2019-02-14, verano seco) y dos áreas; sin datos de
  referencia de ET.
- MCD12Q1 2019 (500 m, clasificación IGBP) solo para el diagnóstico; en
  Chile central sus clases EBF/ENF incluyen plantaciones y bosque nativo y
  sus clases de sabana incluyen el secano. Las conclusiones no dependen de
  la clase exacta: la vegetación oscura definida con albedo y NDVI del
  propio estado de superficie da las mismas partes (75–83 %).
- La temperatura del aire ERA5 a 0,25° no resuelve la capa marina: la
  separación costa/cobertura queda abierta.
- La descomposición de §4, H4, es respecto del punto de calibración frío y
  usa la H de la cadena (con su estabilidad); no separa el efecto de la
  rah de cada celda del de dT.
- El Maule usa la descarga ERA5 del 2026-11-11 (107 estaciones virtuales,
  sin el recorte a −35,87° de las evaluaciones anteriores).
