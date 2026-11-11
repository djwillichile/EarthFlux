# Evaluación de una regla de terreno para los presets (M5-25)

Fecha: **2026-11-10** (límite propio de `idaho2002_flat`: 2026-11-11,
§8; referencia de la regla cambiada al rango de elevación de las anclas:
2026-11-11, §10). Autor: Guillermo Servando Fuentes-Jaque.
Decisión: `DECISIONS.md` §1.5, M5-25. Especificación: `specs/presets.md`
§4.1. Antecedente: `verification/anchors-m5-23.md` (§4.3 y §5, punto 3).

> **Evaluación de coherencia, no validación.** No hay datos de referencia
> (torres de covarianza, lisímetros) para estas escenas: las cifras solo
> indican qué celdas excluye cada criterio y qué queda. Ninguna cifra de
> este documento cambia el estado `CANDIDATA` de la regla. No se versionan
> datos descargados: solo números.

## 1. Problema

Con los presets versión 3 y ERA5, la escena del Maule (2019-02-15) da en
la cordillera valores sin sentido físico: sobre 1000 m, ETrF mediana
−0,51 (1000–2000 m, 64,5 % < 0) y −2,93 (> 2000 m, 98,6 % < 0) con
`idaho2002_elev`; el 32,0 % de las celdas de la escena tiene ETrF < 0
(§4.3). El mínimo de z_om (M5-24) hizo calculables ~4259 celdas de roca
andina (~2700 m) que ya caían ahí. METRIC/SEBAL calibra **una** recta
dT = a + b·Ts_datum con dos anclas del valle y la aplica con **un**
forzamiento: extrapolarla a 2000–4000 m (otra temperatura del aire, otro
viento, otra radiación, otra superficie) no tiene base.

## 2. Qué dice el manual (Waters et al., 2002)

Texto leído en las páginas renderizadas del PDF local (número de página
impreso = página del PDF).

| Pasaje | Página | Texto |
|---|---|---|
| Alcance del modelo plano | p. 11 | "SEBAL can compute ET for flat, agricultural areas with the most accuracy and confidence. Appendix 12 describes additional SEBAL applications for mountain areas where elevation, slope, and aspect need to be considered." |
| Sub-imágenes | p. 39, punto 2 | "When the ETr at the weather station is not representative of the entire area (i.e., where the image spans many mountain valleys or includes both coastal and inland areas …), then the image should be broken down into sub-images, each with its own value of ETr. In this situation, simple SEBAL runs should be made for each sub-image." |
| Clima uniforme; partir la imagen | ap. 7, p. 70 | "… one basic assumption in SEBAL is that climate conditions are uniform within the area of interest. Where weather varies, one may consider splitting the image into two or more parts and apply SEBAL to each part separately, with unique cold and hot pixels for each part." |
| Ancla caliente | ap. 7, p. 72, pasos 2–3 | No usar "a south facing mountain slope, or other such extremely hot areas, since the relationship between dT and Ts may not follow the same linear relation as for agricultural and bare agricultural soils"; "In the Mountain Model, the 'hot' pixel should have a slope of less than one percent." |
| Región aparte | ap. 7, p. 79 | Sobre una región de la imagen con otro régimen térmico: "It would be best to separate this region into a separate SEBAL application. In our application, we will include this region, but we will ignore the ET estimates for this region …" |
| Modelo de montaña | ap. 12, p. 93 | "SEBAL provides accurate estimations of ET for relatively flat agricultural areas. For use in mountainous areas where there is significant relief and a wide range of slopes and aspects, the SEBAL Mountain Model was developed." Sin correcciones, "a higher than actual ET will be computed for north slopes and high elevations"; el viento sobre montaña es "much more difficult" de predecir |
| Gradiente | ap. 12, p. 95 (H) | "Generally, air temperature decreases 6.5 °C for each 1 km elevation increase **under neutral stability conditions**." |
| Datum | ap. 12, p. 96 (H) | Ec. 12-7, Ts_dem = Ts + 0,0065·Δz, con Δz respecto de un datum: "The representative elevation for the image, usually at the weather station, is used for the datum elevation." |
| Ajustes de montaña | ap. 12, p. 97 (N, O) | z_om(mnt) = z_om·[1 + (pendiente − 5)/20] (Ec. 12-9); viento ϖ = 1 + 0,1·(z − z_estación)/1000 (Ec. 12-10) |
| Precauciones | ap. 12, p. 97 (R) | "… the ET estimates in mountains have higher uncertainty than those for flatter areas." El modelo de montaña se ofrecía "for a purchase fee" |

Lectura: el manual trata la montaña con el **modelo de montaña** (pendiente
y orientación en Rs↓, Ec. 12-1; z_om y viento ajustados, Ecs. 12-9 y
12-10), que los presets no implementan (proyección plana, RC-09; SH-03,
SH-07). Para el modelo plano, la indicación es **separar** la región con
otro clima en otra aplicación (pp. 39, 70, 79) o **ignorar** su ET (p. 79).
Ningún pasaje da un umbral de elevación, de diferencia de elevación ni de
pendiente.

## 3. Candidatos y método

Entradas preparadas de las corridas de `anchors-m5-23.md` (mismas
escenas, AOI y limitaciones de ERA5 en el Maule: límite sur −35,87 y
ventana desde el 2019-02-14). Sobre esas entradas se corrió
`workflow_metric()` (la cadena de `earthflux()`) con cada preset y cada
regla: las celdas excluidas salen de los candidatos a ancla (QA) y quedan
`NA` en el resultado, como en la implementación. "Calculadas" = celdas con
ETa₂₄ sin regla (Cauquenes 6598, Maule 24 830).

- **(a) Elevación absoluta:** z > 1000 m; z > 1500 m.
- **(b) Pendiente efectiva** (`dem_terrain(method = "nasadem_normal_mean")`,
  media de normales de 3″ por celda de 1 km): > 5°; > 10°. Mediana de la
  pendiente de las celdas: Cauquenes 1,1°, Maule 6,5° (p75 13,3°, máx.
  45,9°).
- **(c) Diferencia con la elevación de referencia de la calibración**
  (z_ref = datum de Ts del preset: la estación representativa, o el punto
  de calibración frío de una selección preliminar sin la regla; aquí ERA5,
  sin estación: Cauquenes 419 m, Maule 260 m): |z − z_ref| > 500, 750 y
  1000 m.
- **Combinaciones:** (c) 1000 m o (b) 10°; (a) 1000 m o (b) 10°.

## 4. Resultados

Frío y caliente: candidatos tras la homogeneidad (antes del 20 % más frío
/ caliente), elevación del punto de calibración (mín.–máx. de sus píxeles)
y Ts. Ningún caso necesitó relajación.

### 4.1 Maule, `idaho2002_elev`

| Regla | Excluidas (de las calculadas) | n con ETa | ETrF > 1,05 | ETrF < 0 | ETrF p1 / p50 / p99 | Frío: cand., z (mín.–máx.), Ts | Caliente: cand., z (mín.–máx.), Ts | a; b |
|---|---|---|---|---|---|---|---|---|
| ninguna (v3) | 0 (0,0 %) | 24 830 | 20,0 % | 32,0 % | −4,81 / 0,72 / 1,64 | 20, 260 m (122–523), 299,71 K | 235, 303 m (115–2450), 307,24 K | −173,8; 0,5830 |
| (a) z > 1000 m | 9195 (37,0 %) | 15 635 | 29,6 % | 2,3 % | −0,23 / 0,91 / 1,74 | 46, 281 m (118–523), 299,50 K | 378, 149 m (107–243), 306,98 K | −199,2; 0,6685 |
| (a) z > 1500 m | 7237 (29,1 %) | 17 593 | 29,8 % | 8,0 % | −2,10 / 0,91 / 1,75 | 14, 224 m (122–523), 299,95 K | 411, 164 m (107–1414), 307,04 K | −206,4; 0,6908 |
| (b) pendiente > 5° | 13 607 (54,8 %) | 11 223 | 23,2 % | 7,5 % | −4,38 / 0,88 / 1,73 | 155, 257 m (118–523), 299,47 K | 299, 151 m (115–243), 307,03 K | −193,8; 0,6502 |
| (b) pendiente > 10° | 8431 (34,0 %) | 16 399 | 25,0 % | 14,5 % | −4,77 / 0,87 / 1,70 | 40, 326 m (118–523), 299,42 K | 319, 205 m (109–2450), 307,12 K | −186,2; 0,6258 |
| **(c) \|z − z_ref\| > 500 m** | 10 151 (40,9 %) | 14 679 | 28,8 % | 0,9 % | 0,01 / 0,91 / 1,73 | 118, 271 m (118–523), 299,41 K | 355, 150 m (109–243), 307,00 K | −193,4; 0,6492 |
| (c) \|z − z_ref\| > 750 m | 9164 (36,9 %) | 15 666 | 29,1 % | 2,3 % | −0,25 / 0,91 / 1,73 | 45, 315 m (118–523), 299,39 K | 379, 149 m (107–243), 306,98 K | −197,6; 0,6637 |
| (c) \|z − z_ref\| > 1000 m | 8147 (32,8 %) | 16 683 | 29,3 % | 5,1 % | −1,17 / 0,91 / 1,74 | 20, 260 m (122–523), 299,71 K | 406, 149 m (107–243), 306,99 K | −204,0; 0,6837 |
| (c) 1000 m o (b) 10° | 10 769 (43,4 %) | 14 061 | 27,5 % | 2,4 % | −0,31 / 0,90 / 1,73 | 53, 310 m (118–523), 299,31 K | 356, 150 m (109–243), 307,00 K | −194,4; 0,6530 |
| (a) 1000 m o (b) 10° | 11 103 (44,7 %) | 13 727 | 28,6 % | 1,5 % | −0,04 / 0,91 / 1,74 | 103, 248 m (118–523), 299,51 K | 351, 150 m (109–243), 307,00 K | −196,0; 0,6575 |

### 4.2 Maule, `idaho2002_flat`

| Regla | Excluidas | n con ETa | ETrF > 1,05 | ETrF < 0 | ETrF p1 / p50 / p99 | a; b |
|---|---|---|---|---|---|---|
| ninguna (v3) | 0 (0,0 %) | 24 830 | 28,7 % | 14,1 % | −1,17 / 0,85 / 1,63 | −179,9; 0,6034 |
| (a) z > 1000 m | 9195 (37,0 %) | 15 635 | 33,3 % | 0,5 % | 0,05 / 0,94 / 1,66 | −175,2; 0,5882 |
| (a) z > 1500 m | 7237 (29,1 %) | 17 593 | 41,4 % | 2,0 % | −0,26 / 1,00 / 1,71 | −193,9; 0,6491 |
| (b) pendiente > 5° | 13 607 (54,8 %) | 11 223 | 24,6 % | 2,9 % | −0,47 / 0,90 / 1,66 | −174,9; 0,5873 |
| (b) pendiente > 10° | 8431 (34,0 %) | 16 399 | 26,7 % | 5,5 % | −0,73 / 0,88 / 1,62 | −166,2; 0,5589 |
| **(c) \|z − z_ref\| > 500 m** | 10 151 (40,9 %) | 14 679 | 30,9 % | 0,3 % | 0,06 / 0,93 / 1,65 | −172,1; 0,5782 |
| (c) \|z − z_ref\| > 750 m | 9164 (36,9 %) | 15 666 | 30,9 % | 0,5 % | 0,05 / 0,92 / 1,63 | −168,2; 0,5654 |
| (c) \|z − z_ref\| > 1000 m | 8147 (32,8 %) | 16 683 | 36,6 % | 1,0 % | −0,00 / 0,96 / 1,67 | −182,6; 0,6123 |
| (c) 1000 m o (b) 10° | 10 769 (43,4 %) | 14 061 | 28,9 % | 0,6 % | 0,04 / 0,90 / 1,63 | −166,7; 0,5606 |
| (a) 1000 m o (b) 10° | 11 103 (44,7 %) | 13 727 | 32,0 % | 0,5 % | 0,05 / 0,94 / 1,68 | −178,0; 0,5975 |

Las anclas de `flat` son las de `elev` en cada regla (la selección no
depende de Γ).

### 4.3 Cauquenes (ambos presets)

Elevación de las celdas calculadas: 5–787 m; z_ref = 419 m. Las reglas
(a) y (c) no excluyen ninguna celda (|z − 419| ≤ 415 m): resultado
idéntico al de la versión 3. Solo la pendiente excluye celdas (cordillera
de la Costa):

| Regla | Excluidas | ETrF > 1,05 / < 0 (`elev`) | ETrF > 1,05 / < 0 (`flat`) | Frío: cand., z, Ts | a; b (`elev`) |
|---|---|---|---|---|---|
| ninguna, (a), (c) | 0 (0,0 %) | 20,6 % / 1,9 % | 19,8 % / 1,1 % | 22, 419 m (303–471), 299,43 K | −206,2; 0,6929 |
| (b) pendiente > 5° | 1369 (20,7 %) | 19,3 % / 2,2 % | 20,3 % / 1,5 % | 68, 318 m (131–610), 301,02 K | −269,2; 0,8975 |
| (b) pendiente > 10° | 280 (4,2 %) | 19,0 % / 1,9 % | 18,0 % / 1,2 % | 26, 430 m (303–484), 299,22 K | −200,6; 0,6749 |

El ancla caliente no cambia (145–146 m, 307,1 K) en ningún caso.

### 4.4 ETrF según la distancia en elevación al datum (sin regla)

Maule, datum = 260 m (punto frío); n, mediana de ETrF, > 1,05, < 0:

| z − z_datum (m) | n | `elev`: mediana, > 1,05, < 0 | `flat`: mediana, > 1,05, < 0 |
|---|---|---|---|
| < −250 | 48 | 1,45; 100 %; 0,0 % | 1,39; 89,6 %; 0,0 % |
| −250 … 0 | 8108 | 0,97; 33,9 %; 0,0 % | 0,91; 28,0 %; 0,5 % |
| 0 … 250 | 5012 | 0,95; 31,2 %; 0,0 % | 1,00; 40,4 %; 0,0 % |
| 250 … 500 | 1511 | 0,85; 25,7 %; 1,2 % | 1,07; 53,1 %; 0,1 % |
| 500 … 750 | 987 | 0,69; 16,6 %; 14,1 % | 1,10; 56,1 %; 2,8 % |
| 750 … 1000 | 1017 | 0,29; 4,4 %; 35,4 % | 0,95; 43,3 %; 8,3 % |
| 1000 … 1500 | 1862 | −0,57; 0,3 %; 67,9 % | 0,62; 27,0 %; 26,1 % |
| > 1500 | 6285 | −2,85; 0,1 %; 98,0 % | 0,07; 7,7 %; 45,4 % |

Con `elev` la ETrF cae con Δz (Ts_datum crece 6,5 K km⁻¹ y supera la del
ancla caliente); con `flat` (sin corrección) sube primero —las celdas
altas parecen frías, es decir, húmedas: el error que describe el manual en
la p. 93— y cae después. En ambos casos el comportamiento cambia con Δz,
no con la elevación absoluta.

### 4.5 Costo de la pendiente

Leer los MDE ya en caché y calcular el terreno (`dem_read()` +
`dem_terrain()`): Cauquenes (12 835 celdas, 5 teselas) lectura 4,5 s,
`"flat"` 0,8 s, `"nasadem_normal_mean"` 1,5 s; Maule (49 274 celdas, 8
teselas) 12,7 s, 3,6 s y 4,6 s. Una regla de pendiente con la proyección
plana de los presets (RC-09) exigiría un segundo terreno solo para la
máscara (+1–5 s con la lectura reutilizada; +5–17 s con un segundo
`dem_fetch()`). Cambiar el `dem_method` del preset no sirve: la elevación
de `"nasadem_normal_mean"` difiere de la de `"flat"` hasta 36 m
(Cauquenes) y 54 m (Maule) en celdas de soporte parcial, porque su soporte
válido exige pendiente definida.

## 5. Elección

1. **(a) Elevación absoluta.** Funciona en el Maule (1000 m: 2,3 % < 0),
   pero el umbral es regional: en un valle andino a 2500 m o en el
   altiplano excluiría la escena entera, y en una costa baja dejaría
   pasar laderas de 900 m sobre un datum de 50 m. No dice nada de la
   calibración.
2. **(b) Pendiente.** Por sí sola no aborda el problema: excluye laderas,
   pero deja las mesetas y fondos altos (con > 10° quedan 2672 celdas
   sobre 1000 m, con 61 % y 99 % de ETrF < 0 en las bandas 1000–2000 y
   > 2000 m en `elev`, 14,5 % en toda la escena, y el ancla caliente
   sigue llegando a 2450 m) y en Cauquenes quita el 4–21 % de las celdas,
   de baja elevación, sin cambio útil. La pendiente pertenece a otra
   validez (la radiación en proyección plana, RC-09; el ancla caliente del
   modelo de montaña con pendiente < 1 %, p. 72), y su costo y el cambio
   de elevación de §4.5 no se justifican aquí. Las combinaciones con (b)
   no mejoran a (c) sola.
3. **(c) Diferencia con la referencia de la calibración** (adoptada). El
   dominio de validez de una sola recta dT(Ts_datum) con forzamiento
   uniforme está definido por la calibración, no por una cota fija: el
   datum del preset (M5-12) es la elevación a la que el manual refiere
   Ts_dem ("usually at the weather station", p. 96), y tanto la Ec. 12-7
   como la ponderación del viento de la Ec. 12-10 dependen de z −
   z_estación. La regla vale igual en un valle a 200 m que a 2500 m y no
   excluye nada en Cauquenes.
4. **Límite de 500 m.** No hay fuente primaria. Argumento físico,
   independiente de ETrF: Ts_datum usa
   6,5 K km⁻¹, que el manual da "under neutral stability conditions"
   (p. 95); a la hora de paso sobre superficies secas el perfil es
   inestable, cercano al adiabático seco g/c_p ≈ 9,8 K km⁻¹. La diferencia,
   3,3 K km⁻¹, hace que el error de Ts_datum alcance 1,5 K —la tolerancia
   de homogeneidad de LST de las anclas (`specs/presets.md` §4), la mayor
   variación de Ts que el preset ya acepta como ruido— a unos 450 m;
   se redondea a 500 m. Con 1000 m el error posible sería ~3,3 K, del
   orden de la mitad del contraste entre anclas (7,5–7,7 K en ambas
   escenas). **Advertencia:** 500 m también es, de los tres límites
   evaluados, el que deja menos ETrF < 0 en el Maule (§4.1); quien revise
   la decisión debe saber que el argumento y las cifras coinciden, y que
   las cifras solas no bastarían para elegirlo. Este límite es el de
   `idaho2002_elev`; `idaho2002_flat`, sin corrección por gradiente, usa
   250 m por el mismo argumento (decisión del autor del 2026-11-11, §8).
5. **Referencia en C2 (ERA5 o varias estaciones).** El datum es el punto
   de calibración frío, que solo existe tras seleccionar las anclas. Se
   toma de una **selección preliminar** con los mismos criterios y sin la
   regla; la selección final corre sobre las celdas que la regla conserva.
   El datum final (Maule: 271 m) queda a ≤ 500 m de la referencia (260 m)
   por construcción, porque los píxeles fríos finales están dentro del
   dominio.

## 6. Efecto en las anclas (Maule)

- **Caliente:** de 235 candidatos con píxeles entre 115 y 2450 m (media
  303 m, 4 de 49 sobre 1000 m) a 355 candidatos entre 109 y 243 m (media
  150 m, Ts 307,00 K): todos en campos del valle, como pide el manual
  (p. 72).
- **Frío:** de 20 a 118 candidatos. Al salir la precordillera
  (bosque y matorral de NDVI alto) del dominio de percentiles (`"land"`),
  el percentil 0,90 del NDVI baja y entran más campos del valle; el punto
  frío pasa de 260 a 271 m y de 299,71 a 299,41 K.
- **Calibración:** a, b = −173,8; 0,583 → −193,4; 0,649 (`elev`).

## 7. Antes y después por banda de elevación (corridas completas)

`earthflux()` con los presets versión 3 (antes) y 4 (después, regla de
500 m); las corridas completas de la versión 4 reproducen exactamente las
cifras de §4 (mismas celdas, anclas, a y b).

| Escena | Preset | Banda (m) | Antes: n; ETrF p5 / p50 / p95; > 1,05; < 0; ETa₂₄ p50 | Después: n; ETrF p5 / p50 / p95; > 1,05; < 0; ETa₂₄ p50 |
|---|---|---|---|---|
| Maule | `elev` | 0–300 | 9449; 0,30 / 0,97 / 1,53; 34,0 %; 0,0 %; 6,7 | 9449; 0,18 / 0,93 / 1,54; 30,6 %; 0,8 %; 6,5 |
| Maule | `elev` | 300–1000 | 6186; 0,23 / 0,90 / 1,36; 27,4 %; 2,4 %; 6,0 | 5230; 0,28 / 0,86 / 1,37; 25,6 %; 1,1 %; 5,8 |
| Maule | `elev` | 1000–2000 | 3742; −3,28 / −0,51 / 0,90; 1,4 %; 64,5 %; −3,3 | 0 (excluidas) |
| Maule | `elev` | > 2000 | 5453; −4,76 / −2,93 / −0,82; 0,1 %; 98,6 %; −18,2 | 0 (excluidas) |
| Maule | `flat` | 0–300 | 9449; 0,20 / 0,93 / 1,50; 29,1 %; 0,4 %; 6,4 | 9449; 0,18 / 0,89 / 1,47; 26,3 %; 0,5 %; 6,2 |
| Maule | `flat` | 300–1000 | 6186; 0,53 / 1,03 / 1,42; 47,3 %; 0,4 %; 6,9 | 5230; 0,54 / 0,99 / 1,40; 39,4 %; 0,0 %; 6,6 |
| Maule | `flat` | 1000–2000 | 3742; −1,02 / 0,65 / 1,36; 27,9 %; 25,9 %; 4,1 | 0 (excluidas) |
| Maule | `flat` | > 2000 | 5453; −0,94 / 0,07 / 1,18; 7,2 %; 45,1 %; 0,4 | 0 (excluidas) |
| Cauquenes | `elev` | 0–300 | 4865; 0,05 / 0,36 / 1,78; 15,1 %; 2,0 %; 2,6 | sin cambio |
| Cauquenes | `elev` | 300–1000 | 1733; 0,15 / 0,84 / 1,59; 35,8 %; 1,6 %; 5,4 | sin cambio |
| Cauquenes | `flat` | 0–300 | 4865; 0,05 / 0,32 / 1,59; 13,2 %; 1,5 %; 2,3 | sin cambio |
| Cauquenes | `flat` | 300–1000 | 1733; 0,31 / 0,90 / 1,52; 38,2 %; 0,0 %; 5,9 | sin cambio |

Maule, toda la escena: ETrF < 0 de 32,0 % a 0,9 % (`elev`) y de 14,1 % a
0,3 % (`flat`); ETrF > 1,05 de 20,0 % a 28,8 % y de 28,7 % a 30,9 %
(sube porque salen celdas de ETrF baja; dentro de cada banda baja). Se
excluyen 10 460 celdas del AOI con elevación (36,8 % de 28 460; 10 151 de
ellas tenían ETa₂₄), todas sobre 760 m (z_ref + 500 m); máxima elevación
conservada 759,6 m. `EF_H_TERRAIN_RULE_APPLIED` marca las 10 460.

## 8. Límite propio de `idaho2002_flat` (2026-11-11)

**Decisión del autor (opción B):** `idaho2002_elev` conserva 500 m e
`idaho2002_flat` usa el límite que da el mismo argumento de §5, punto 4,
sin corrección por gradiente (Γ = 0). Las cifras de §4 y §7 para `flat`
son las de 500 m; esta sección da las de 250 m. Los presets siguen en la
versión 4 (la rama no estaba integrada).

### 8.1 Cálculo del límite

El argumento compara el error de Ts_datum acumulado con la distancia en
elevación al datum con la tolerancia de homogeneidad de LST de las anclas,
1,5 K (`specs/presets.md` §4):

| Preset | Corrección de Ts_datum | Error por km | 1,5 K / error | Límite | Error en el límite |
|---|---|---|---|---|---|
| `idaho2002_elev` | Γ = 6,5 K km⁻¹ (neutro, p. 95) frente a g/c_p ≈ 9,8 K km⁻¹ | 9,8 − 6,5 = 3,3 K km⁻¹ | 1,5 / 3,3 = 0,455 km = 455 m | **500 m** | 3,3 × 0,5 = 1,65 K |
| `idaho2002_flat` | ninguna (Γ = 0): el error es el gradiente completo del manual | 6,5 K km⁻¹ | 1,5 / 6,5 = 0,231 km = 231 m | **250 m** | 6,5 × 0,25 = 1,63 K |

Redondeo: al **múltiplo de 50 m superior**, la regla que reproduce los
500 m de `elev` (455 → 500). Se prefiere 250 m a 230 m porque (i) aplica a
ambos presets el mismo redondeo, que deja el mismo error en el límite
(~1,6 K en los dos); (ii) los datos del argumento (1,5 K, 6,5 K km⁻¹)
tienen una o dos cifras significativas, y 230 o 231 m sugerirían una
precisión que no tienen. Redondear a 100 m daría 200 m, más estricto
para `flat` (1,3 K en el límite) que para `elev`. Nota: el argumento de
`flat` toma como error el gradiente del propio manual (lo que `flat` omite
respecto de la Ec. 12-7); con el perfil adiabático seco de `elev` como
referencia el error sería 9,8 K km⁻¹ y el límite ~150 m (200 m con el
mismo redondeo). Ninguno de los dos límites tiene fuente primaria.

### 8.2 Resultados de `idaho2002_flat` con 250 m

`workflow_metric()` sobre las mismas entradas preparadas de §3, con la
regla del preset aplicada dentro de la cadena; las corridas completas de
`earthflux()` (versión 4, límite 250 m) reproducen exactamente las celdas
excluidas, las anclas, a y b. "Calculadas" = celdas con ETa₂₄ sin regla.

| Escena | Límite | Excluidas (de las calculadas) | n con ETa | ETrF > 1,05 | ETrF < 0 | ETrF p1 / p50 / p99 | ETa₂₄ p50 |
|---|---|---|---|---|---|---|---|
| Cauquenes | ninguno / 500 m | 0 (0,0 %) | 6598 | 19,8 % | 1,1 % | −0,01 / 0,42 / 1,71 | 3,0 |
| Cauquenes | **250 m** | 2933 (44,5 %): 2915 debajo (z 5–169 m), 18 encima (z 669–787 m) | 3665 | 29,0 % | 0,5 % | 0,03 / 0,62 / 1,77 | 4,2 |
| Maule | ninguno | 0 (0,0 %) | 24 830 | 28,7 % | 14,1 % | −1,17 / 0,85 / 1,63 | 5,8 |
| Maule | 500 m | 10 151 (40,9 %), todas encima (z ≥ 760 m) | 14 679 | 30,9 % | 0,3 % | 0,06 / 0,93 / 1,65 | 6,3 |
| Maule | **250 m** | 11 710 (47,2 %): 48 debajo (z 3–10 m), 11 662 encima (z 510–4491 m) | 13 120 | 31,2 % | 0,4 % | 0,05 / 0,94 / 1,69 | 6,4 |

Celdas del AOI con elevación marcadas con `EF_H_TERRAIN_RULE_APPLIED`:
Cauquenes 2948 de 6614 (44,6 %), Maule 12 167 de 28 460 (42,8 %; con
500 m, 10 460). Elevación conservada: Cauquenes 169–668 m, Maule
10–510 m.

Anclas (candidatos tras la homogeneidad, elevación del punto de
calibración con mín.–máx. de sus píxeles, Ts; ningún caso necesitó
relajación):

| Escena | Límite | Frío | Caliente | Datum final (z_ref) | a; b |
|---|---|---|---|---|---|
| Cauquenes | ninguno / 500 m | 22, 419 m (303–471), 299,43 K | 447, 145 m (115–234), 307,14 K | 419 m (419 m) | −157,4; 0,5299 |
| Cauquenes | **250 m** | **1**, 303 m (un píxel, `EF_ANCHOR_SINGLE_PIXEL`), 300,36 K | 95, 193 m (169–243), 306,87 K | 303 m (419 m) | −190,6; 0,6390 |
| Maule | 500 m | 118, 271 m (118–523), 299,41 K | 355, 150 m (109–243), 307,00 K | 271 m (260 m) | −172,1; 0,5782 |
| Maule | **250 m** | 288, 252 m (118–426), 299,56 K | 324, 150 m (109–243), 307,01 K | 252 m (260 m) | −178,3; 0,5985 |

Por banda de elevación (n; ETrF p5 / p50 / p95; > 1,05; < 0; ETa₂₄ p50,
mm d⁻¹):

| Escena | Banda (m) | Sin regla | 500 m | **250 m** |
|---|---|---|---|---|
| Cauquenes | 0–300 | 4865; 0,05 / 0,32 / 1,59; 13,2 %; 1,5 %; 2,3 | sin cambio | 1950; 0,07 / 0,41 / 1,65; 14,4 %; 1,0 %; 2,9 |
| Cauquenes | 300–1000 | 1733; 0,31 / 0,90 / 1,52; 38,2 %; 0,0 %; 5,9 | sin cambio | 1715; 0,31 / 0,99 / 1,63; 45,7 %; 0,0 %; 6,5 |
| Maule | 0–300 | 9449; 0,20 / 0,93 / 1,50; 29,1 %; 0,4 %; 6,4 | 9449; 0,18 / 0,89 / 1,47; 26,3 %; 0,5 %; 6,2 | 9401; 0,18 / 0,91 / 1,48; 27,7 %; 0,5 %; 6,3 |
| Maule | 300–1000 | 6186; 0,53 / 1,03 / 1,42; 47,3 %; 0,4 %; 6,9 | 5230; 0,54 / 0,99 / 1,40; 39,4 %; 0,0 %; 6,6 | 3719; 0,55 / 1,00 / 1,44; 40,2 %; 0,0 %; 6,7 |
| Maule | 1000–2000 | 3742; −1,02 / 0,65 / 1,36; 27,9 %; 25,9 %; 4,1 | 0 (excluidas) | 0 (excluidas) |
| Maule | > 2000 | 5453; −0,94 / 0,07 / 1,18; 7,2 %; 45,1 %; 0,4 | 0 (excluidas) | 0 (excluidas) |

ETrF de `flat` sin regla según z − z_ref (n; mediana; > 1,05; < 0):

| z − z_ref (m) | Cauquenes (z_ref = 419 m) | Maule (z_ref = 260 m) |
|---|---|---|
| < −250 | 2915; 0,25; 13,5 %; 2,5 % | 48; 1,39; 89,6 %; 0,0 % |
| −250 … −125 | 1880; 0,40; 12,5 %; 0,1 % | 3133; 0,87; 33,0 %; 0,3 % |
| −125 … 0 | 1065; 0,72; 27,6 %; 0,0 % | 4975; 0,93; 24,8 %; 0,6 % |
| 0 … 125 | 567; 1,04; 48,5 %; 0,0 % | 3362; 0,99; 36,1 %; 0,0 % |
| 125 … 250 | 153; 1,20; 61,4 %; 0,0 % | 1650; 1,04; 49,2 %; 0,0 % |
| 250 … 500 | 18; 1,32; 77,8 %; 0,0 % | 1511; 1,07; 53,1 %; 0,1 % |
| 500 … 750 | — | 987; 1,10; 56,1 %; 2,8 % |
| > 750 | — | 9164; 0,23; 15,5 %; 37,4 % |

### 8.3 Lectura

1. **Maule.** Pasar de 500 a 250 m excluye 1559 celdas calculadas más
   (la banda 300–1000 m baja de 5230 a 3719 celdas, más 48 celdas
   costeras bajo 10 m) y casi no cambia las cifras de la escena (ETrF < 0
   0,3 → 0,4 %, > 1,05 30,9 → 31,2 %). Sale la franja 250–500 m sobre el
   datum, donde `flat` sin corrección da ETrF mediana 1,07 y 53 % > 1,05
   (las celdas altas parecen frías, §4.4). El ancla caliente no cambia; el
   frío gana candidatos (288) y baja a 252 m.
2. **Cauquenes: la regla corta ahora el valle, no la cumbre.** z_ref es el
   punto frío de la selección preliminar (419 m, §4.3) y la escena llega
   a 787 m, pero también baja a 5 m: con 250 m solo 18 celdas quedan fuera por encima
   (669–787 m) y **2915 por debajo (z < 169 m, 44 % de las calculadas)**,
   incluida la zona del ancla caliente de la versión 4 (145 m). Es el caso
   de §9, punto 3: la referencia en C2 depende del frío preliminar, y con
   un límite de 250 m un frío en lomaje deja fuera el llano. Sin regla,
   esas celdas tienen ETrF mediana 0,25 y solo 2,5 % < 0: la exclusión
   viene del argumento (a 274 m bajo el datum, Ts sin corregir lleva un
   error de ~1,8 K hacia lo seco), no de valores sin sentido físico, y las
   cifras no permiten separar ese sesgo de la sequedad real del llano en
   verano.
3. **Anclas de Cauquenes con 250 m.** El dominio de percentiles queda en
   169–668 m; de 291 celdas con NDVI ≥ p0,90 solo 2 cumplen la banda de
   albedo y 1 la homogeneidad: el ancla fría es **un solo píxel** (303 m,
   300,36 K, `EF_ANCHOR_SINGLE_PIXEL`), sin relajación porque hay
   candidato. El contraste entre anclas baja de 7,71 a 6,51 K, y el datum
   final (303 m) queda a 116 m de la referencia (419 m). Una calibración
   que depende de un píxel es frágil.
4. Con `elev` nada cambia (límite 500 m, §4 y §7).

## 9. Limitaciones y pendientes

1. **Sin ETa en la montaña.** El 41 % de las celdas calculadas del Maule
   queda `NA`. El manual pide para ellas otra aplicación (sub-imagen con
   su propio clima y sus anclas, pp. 39, 70) o el modelo de montaña
   (ap. 12): ninguno está implementado.
2. **Los límites son `CANDIDATA`.** 500 m (`elev`) y 250 m (`flat`)
   salen de un argumento de orden de magnitud (error de Ts_datum frente a
   la tolerancia de homogeneidad, también sin fuente; §5, punto 4, y
   §8.1). Hasta el 2026-11-10 se usaba 500 m en ambos presets; desde el
   2026-11-11 cada preset tiene el suyo (decisión del autor).
3. **Referencia en C2** (resuelto por §10: la referencia es ahora el
   rango de las anclas). Depende del punto frío de la selección
   preliminar: si los criterios eligieran un frío de montaña, la regla
   excluiría el valle. En estas escenas el frío está en 260–419 m; con el
   límite de 250 m de `flat` esto ya ocurre en Cauquenes (§8.3: 44 % de
   las celdas calculadas, bajo 169 m, y un ancla fría de un píxel).
   Alternativas para el autor (no implementadas): una estación como
   referencia, una referencia entre el frío y el caliente preliminares, o
   `elev` en escenas con relieve.
4. **El valle no mejora en lo que la regla no toca.** En el Maule el 30,6 %
   de las celdas bajo 300 m sigue con ETrF > 1,05 (`elev`) y Cauquenes
   conserva 20,6 % (`verification/anchors-m5-23.md` §5): la regla no
   resuelve los criterios de anclas ni el clima no uniforme de la costa.
5. Evaluación en dos escenas de un solo día despejado de verano, una con
   ERA5 recortado por el límite de la API; sin datos de referencia.
6. **Rango de las anclas (§10).** El rango depende de los puntos de
   calibración *preliminares*, que promedian sus píxeles: un caliente
   preliminar con píxeles de montaña (Maule: 115–2450 m, media 303 m)
   ensancha el rango aunque el caliente final quede en el valle. Si los
   criterios eligieran un ancla preliminar en la montaña, el rango la
   incluiría entera (el riesgo inverso del punto 3). La extensión por la
   estación (C1) solo se probó con datos sintéticos: ninguna escena
   evaluada tiene una estación.

## 10. Referencia: rango de elevación de las anclas (2026-11-11)

**Decisión del autor (opción 1), que reemplaza la referencia de §5,
puntos 3 y 5:** la regla deja de medir la distancia a un punto (el datum)
y mide la distancia al **rango de elevación de la calibración**. Se
conservan las celdas con

min(z_frío, z_caliente[, z_estación]) − límite ≤ z ≤ max(z_frío, z_caliente[, z_estación]) + límite

y se excluyen las demás (`EF_H_TERRAIN_RULE_APPLIED`, sin ancla, `NA` en
todas las capas). Los límites no cambian (500 m `elev`, 250 m `flat`,
§8.1). Motivo: la recta dT(Ts_datum) se calibra *entre* las dos anclas;
la regla debe excluir solo la extrapolación más allá del rango calibrado,
no las celdas entre las anclas. Las secciones 1–9 quedan como historia:
sus cifras son las de la referencia anterior (z_ref).

### 10.1 Implementación

- **Anclas de referencia:** puntos de calibración frío y caliente de una
  **selección preliminar** con los mismos criterios y sin la regla (como
  antes para z_ref en C2, ahora también con estación); la selección final
  corre sobre las celdas conservadas.
- **Estación (C1):** su elevación entra en el rango. Es el datum de
  Ts_datum (M5-12) y el sitio del forzamiento (ETr y viento de la estación
  sobre toda la grilla), es decir, la otra referencia de la calibración;
  incluirla hace que el rango contenga siempre el datum, como en C2 (donde
  el datum es el frío). Consecuencia: la regla nueva nunca excluye una
  celda que la regla anterior conservaba con las mismas anclas
  preliminares ([z_ref − límite, z_ref + límite] está dentro del rango).
  Sin estación (ERA5 o varias estaciones) el forzamiento se regionaliza a
  cada celda y no hay un sitio único.
- **Anclas finales dentro del rango:** se cumple por construcción. Cada
  punto de calibración agrega (media) píxeles conservados, y las celdas
  conservadas forman un intervalo de elevación; `anchors_in_range` lo
  registra. Las anclas finales pueden abarcar un rango **más estrecho**
  que las preliminares (los percentiles de los criterios cambian al
  quitar celdas). Se mantiene el **rango preliminar sin iterar**: una
  nueva selección sobre un nuevo rango no tiene punto fijo garantizado, y
  la diferencia en estas escenas es pequeña (§10.3). Se registran las
  elevaciones finales.
- **Opciones del preset:** `terrain_rule$method = "anchor_elevation_range"`
  (antes `"datum_elevation_difference"`), `reference` describe el rango.
  Versión de los presets: sigue siendo `"4"` (no publicada), con la nota
  `changes` actualizada.
- **Proveniencia** (`provenance$scene$terrain_rule`): `method`,
  `reference_elevations` (`cold`, `hot` y, con estación, `station`),
  `reference_source`, `max_elevation_difference`, `range` (`lower`,
  `upper`: elevaciones conservadas), `anchor_elevations` (anclas finales)
  y `anchors_in_range`; en `provenance$counts`, `terrain_rule_excluded`
  separado en `terrain_rule_excluded_below` y
  `terrain_rule_excluded_above`.

### 10.2 Resultados: z_ref frente al rango de las anclas

`workflow_metric()` sobre las mismas entradas preparadas de §3 y §8 (ERA5,
sin estación); las corridas completas de `earthflux()` reproducen las
celdas excluidas, las anclas, a y b. "Calculadas" = celdas con ETa₂₄ sin
regla (Cauquenes 6598, Maule 24 830). Referencias preliminares: Cauquenes
frío 418,7 m, caliente 145,2 m; Maule frío 259,7 m, caliente 303,0 m (sus
píxeles van de 115 a 2450 m, §6). Columna "z_ref": la regla anterior
(frío preliminar ± límite); "rango": la nueva.

| Escena | Preset | Regla | Elevación conservada (m) | Excluidas (de las calculadas) | n con ETa | ETrF > 1,05 | ETrF < 0 | ETrF p1 / p50 / p99 | ETa₂₄ p50 |
|---|---|---|---|---|---|---|---|---|---|
| Cauquenes | `elev` | z_ref | −81 … 919 | 0 (0,0 %) | 6598 | 20,6 % | 1,9 % | −0,04 / 0,45 / 1,92 | 3,2 |
| Cauquenes | `elev` | **rango** | −355 … 919 | 0 (0,0 %) | 6598 | 20,6 % | 1,9 % | −0,04 / 0,45 / 1,92 | 3,2 |
| Cauquenes | `flat` | z_ref | 169 … 669 | 2933 (44,5 %): 2915 debajo (5–169 m), 18 encima (669–787 m) | 3665 | 29,0 % | 0,5 % | 0,03 / 0,62 / 1,77 | 4,2 |
| Cauquenes | `flat` | **rango** | −105 … 669 | **18 (0,3 %)**: todas encima (669–787 m) | 6580 | 19,6 % | 1,1 % | −0,01 / 0,42 / 1,71 | 3,0 |
| Maule | `elev` | z_ref | −240 … 760 | 10 151 (40,9 %): todas encima (760–4491 m) | 14 679 | 28,8 % | 0,9 % | 0,01 / 0,91 / 1,73 | 6,2 |
| Maule | `elev` | **rango** | −240 … 803 | 9986 (40,2 %): todas encima (803–4491 m) | 14 844 | 29,8 % | 1,0 % | 0,00 / 0,92 / 1,74 | 6,3 |
| Maule | `flat` | z_ref | 10 … 510 | 11 710 (47,2 %): 48 debajo (3–10 m), 11 662 encima (510–4491 m) | 13 120 | 31,2 % | 0,4 % | 0,05 / 0,94 / 1,69 | 6,4 |
| Maule | `flat` | **rango** | 10 … 553 | 11 319 (45,6 %): 48 debajo (3–10 m), 11 271 encima (553–4491 m) | 13 511 | 30,7 % | 0,4 % | 0,05 / 0,93 / 1,67 | 6,4 |

Celdas del AOI con elevación marcadas (corridas completas, regla nueva):
Cauquenes 0 (`elev`) y 18 (`flat`) de 6614; Maule 10 295 (`elev`) y
11 735 (`flat`) de 28 460 (con z_ref: 10 460 y 12 167).

Anclas (candidatos tras la homogeneidad, elevación del punto de
calibración con mín.–máx. de sus píxeles, Ts; ningún caso necesitó
relajación):

| Escena | Preset | Regla | Frío | Caliente | Datum final | a; b |
|---|---|---|---|---|---|---|
| Cauquenes | `elev` | z_ref y rango | 22, 419 m (303–471), 299,43 K | 447, 145 m (115–234), 307,14 K | 419 m | −206,2; 0,6929 |
| Cauquenes | `flat` | z_ref | 1, 303 m (un píxel), 300,36 K | 95, 193 m (169–243), 306,87 K | 303 m | −190,6; 0,6390 |
| Cauquenes | `flat` | **rango** | 23, 419 m (303–471), 299,43 K | 446, 145 m (115–234), 307,14 K | 419 m | −157,4; 0,5299 |
| Maule | `elev` | z_ref | 118, 271 m (118–523), 299,41 K | 355, 150 m (109–243), 307,00 K | 271 m | −193,4; 0,6492 |
| Maule | `elev` | **rango** | 106, 250 m (118–523), 299,52 K | 357, 150 m (109–243), 307,00 K | 250 m | −196,7; 0,6598 |
| Maule | `flat` | z_ref | 288, 252 m (118–426), 299,56 K | 324, 150 m (109–243), 307,01 K | 252 m | −178,3; 0,5985 |
| Maule | `flat` | **rango** | 246, 262 m (118–523), 299,51 K | 328, 150 m (109–243), 307,01 K | 262 m | −175,6; 0,5895 |

Por banda de elevación (n; ETrF p5 / p50 / p95; > 1,05; < 0; ETa₂₄ p50,
mm d⁻¹). Las bandas 1000–2000 m y > 2000 m del Maule quedan excluidas
con ambas reglas y ambos presets.

| Escena | Preset | Banda (m) | z_ref | **Rango** |
|---|---|---|---|---|
| Cauquenes | `elev` | 0–300 | 4865; 0,05 / 0,36 / 1,78; 15,1 %; 2,0 %; 2,6 | sin cambio |
| Cauquenes | `elev` | 300–1000 | 1733; 0,15 / 0,84 / 1,59; 35,8 %; 1,6 %; 5,4 | sin cambio |
| Cauquenes | `flat` | 0–300 | 1950; 0,07 / 0,41 / 1,65; 14,4 %; 1,0 %; 2,9 | 4865; 0,05 / 0,32 / 1,59; 13,2 %; 1,5 %; 2,3 |
| Cauquenes | `flat` | 300–1000 | 1715; 0,31 / 0,99 / 1,63; 45,7 %; 0,0 %; 6,5 | 1715; 0,31 / 0,90 / 1,52; 37,8 %; 0,0 %; 5,8 |
| Maule | `elev` | 0–300 | 9449; 0,18 / 0,93 / 1,54; 30,6 %; 0,8 %; 6,5 | 9449; 0,18 / 0,94 / 1,55; 31,7 %; 0,8 %; 6,5 |
| Maule | `elev` | 300–1000 | 5230; 0,28 / 0,86 / 1,37; 25,6 %; 1,1 %; 5,8 | 5395; 0,25 / 0,87 / 1,37; 26,3 %; 1,4 %; 5,8 |
| Maule | `flat` | 0–300 | 9401; 0,18 / 0,91 / 1,48; 27,7 %; 0,5 %; 6,3 | 9401; 0,18 / 0,90 / 1,48; 27,0 %; 0,5 %; 6,3 |
| Maule | `flat` | 300–1000 | 3719; 0,55 / 1,00 / 1,44; 40,2 %; 0,0 %; 6,7 | 4110; 0,55 / 0,99 / 1,43; 39,3 %; 0,0 %; 6,6 |

### 10.3 Lectura

1. **Cauquenes `flat` recupera el valle.** El rango de las anclas
   preliminares (145–419 m) contiene el llano: con 250 m solo quedan fuera
   las 18 celdas sobre 669 m (cumbres de la Cordillera de la Costa). Las
   anclas vuelven a las de la escena sin regla (frío de 5 píxeles en lugar
   de uno, contraste 7,71 K) y las cifras de la escena son las de
   "sin regla" salvo esas 18 celdas (ETrF > 1,05 19,8 → 19,6 %). El
   problema de §8.3, puntos 2 y 3, y de §9, punto 3, desaparece.
2. **Maule: casi igual que con z_ref.** El caliente preliminar está a
   303 m (por encima del frío, 260 m), así que el rango sube el límite
   superior 43 m (760 → 803 m con `elev`, 510 → 553 m con `flat`) y
   conserva 165 (`elev`) y 391 (`flat`) celdas calculadas más, todas en
   la banda 300–1000 m; las cifras de la escena cambian menos de un punto
   (ETrF > 1,05: 28,8 → 29,8 % `elev`, 31,2 → 30,7 % `flat`). La montaña
   (z ≥ 803 m) sigue excluida.
3. **Rango preliminar y anclas finales.** En el Maule las anclas finales
   (frío 250 o 262 m, caliente 150 m) abarcan menos que las preliminares
   (260–303 m): el caliente preliminar promedia píxeles de 115 a 2450 m,
   y al excluirse la montaña el caliente final baja a 150 m. Quedan
   199 celdas (`elev`, z 750–803 m) y 362 (`flat`, z 513–553 m) a más del
   límite del rango de las anclas *finales*, como mucho 53 m y 41 m más
   allá. En Cauquenes, ninguna. Iterar no se justifica para esa
   diferencia (§10.1).
4. **`elev` en Cauquenes:** sin cambio (ninguna celda fuera con ninguna
   regla).

### 10.4 Pruebas

`tests/testthat/test-earthflux.R`, con el terreno sintético de
`helper-earthflux.R` (plano de 150 a 582 m; bloque de "montaña" desde la
columna 90 y "valle" hasta la columna 12, lejos de las anclas, que están
en las columnas 52–86): unidades de `workflow_terrain_rule()` (celda a
700 m de ambas anclas conservada; bordes inclusivos; exclusión por debajo
y por encima; extensión por la estación; límites de ambos presets;
errores) y de `workflow_terrain_reference()` (frío y caliente; estación
añadida); flujo completo con una estación (`elev`, montaña a 1200 m
excluida e igualdad con la cadena paso a paso), sin estación (`flat`,
valle y montaña excluidos, anclas finales dentro del rango), con una
estación a 1000 m (`flat`: bloque a 725 m, a más de 250 m de la estación
y de ambas anclas, conservado; el plano, que una regla centrada en la
estación excluiría, conservado; valle excluido) y un bloque a 850 m que
excluye `flat` y conserva `elev`.
