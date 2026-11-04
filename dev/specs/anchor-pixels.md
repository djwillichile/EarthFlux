# EarthFlux — Especificación: píxeles ancla (frío/caliente)

Estado: **borrador M1** · Componente: `metric` · Archivo de destino:
`R/metric-anchors.R` · Tests: `tests/testthat/test-anchors.R` (por crear) ·
Complementa `SCIENTIFIC_SPEC.md` (§1.2, §2.1, §2.2, §2.3, §7),
`ARCHITECTURE.md` (§1, §3, §4, §6.3, §6.4) y `VALIDATION_PLAN.md` (§1.1,
§1.2, §2.1).

> **Regla fundamental.** Ningún criterio, coeficiente ni umbral de este
> documento está en estado `VERIFICADA`. No se consultó el texto completo de
> ninguna fuente primaria de METRIC (ver §0.2). Ninguna función descrita aquí
> puede implementarse hasta cumplir la Definition of Done
> (`DEVELOPMENT.md` §3). `SCIENTIFIC_SPEC.md` sigue siendo la fuente de
> verdad: cuando un elemento pase a `VERIFICADA`, su estado, referencia y
> caso numérico se trasladan a la sección 7 de ese documento.

Convención de estados: la misma de `SCIENTIFIC_SPEC.md` (`TODO`,
`CANDIDATA`, `VERIFICADA`).

---

## 0. Resumen y trazabilidad

### 0.1 Resumen

| Tema | Estado | Decisión o propuesta | Sección |
|---|---|---|---|
| Rol de las anclas: calibrar dT–Ts; no cierran el balance; no particionan Rs↓ | Conceptual (registrado en SPEC §2.1–2.2) | Se reafirma y se fija la separación de etapas selección → condiciones de borde → calibración de dT | §1 |
| Ancla fría: LE = k · λ · ETr_inst | `CANDIDATA` (forma); k = 1.05 `CANDIDATA` | k sin valor por defecto en el núcleo; registrado con fuente y estado | §2.2 |
| Ancla caliente: LE ≈ 0 o desde balance hídrico del suelo | `CANDIDATA` (LE = 0); balance hídrico `TODO` | `etrf_hot` / `le_hot` explícitos; balance hídrico fuera de alcance por ahora | §2.3 |
| ETr_inst en la ubicación y hora del ancla | Requisito de diseño | Punto de entrada de H1 en la calibración | §2.4 |
| Criterios automáticos (percentiles, homogeneidad, cobertura, buffer, QA) | `CANDIDATA` (los de `water`) / `TODO` (literatura) | Criterios explícitos en un objeto; sin umbrales numéricos implícitos | §3 |
| Aplicabilidad a MODIS 1 km | Abierta | Preguntas de evaluación, no decisiones | §4 |
| API `ef_select_anchors()`, `ef_anchors()`, clase `earthflux_anchors` | Propuesta | Determinista; semilla explícita si hay azar; error con diagnóstico si no hay candidatos | §5 |
| Flags | Propuestos, no registrados | Solo se registran los de condición inequívoca | §6 |
| Tests | Diseñados | Escenas sintéticas con anclas conocidas; determinismo; manual ≡ automático | §7 |

### 0.2 Fuentes consultadas y nivel de evidencia

| Fuente | Tipo | Qué se leyó en esta redacción | Qué aporta | Limitación |
|---|---|---|---|---|
| Allen, Tasumi & Trezza (2007), *METRIC — Model* | Primaria | Solo metadatos (Crossref) | — | Texto completo **no consultado** (`ascelibrary.org` bloqueado). |
| Allen et al. (2013), *Automated calibration of the METRIC-Landsat evapotranspiration process* | Primaria | Metadatos y **resumen** (depositado en Crossref) | Nombre del procedimiento (CIMEC), enfoque estadístico basado en la relación cantidad de vegetación–Ts, existencia de requisitos del área de interés y de un ajuste para climas desérticos | Texto completo no consultado (`onlinelibrary.wiley.com` bloqueado). Ningún umbral ni percentil verificado. |
| Morton et al. (2013), *Assessing calibration uncertainty and automation…* | Primaria | Metadatos y **resumen** (Crossref) | Calibración automática que imita la manual; habilita análisis de incertidumbre y sensibilidad; incertidumbre mayor en campos de baja ET | Texto completo no consultado. Ningún criterio verificado. |
| Allen et al. (2011), *Satellite-based ET estimation in agriculture using SEBAL and METRIC* | Primaria | Metadatos y **resumen** (Crossref) | Qué sesgos absorbe la calibración; dT indexado a Ts; la calibración con ETr compensa advección regional | Texto completo no consultado. |
| Trezza, Allen & Tasumi (2013), *…Middle Rio Grande… Using MODIS and Landsat Imagery with the METRIC Model* | Primaria (MODIS) | Metadatos y **resumen** (Crossref) | El principal desafío de METRIC con MODIS es la selección de las dos condiciones de calibración; existe un procedimiento específico para MODIS y una calibración cruzada con Landsat | Artículo de acceso abierto, pero `mdpi.com` bloqueado; procedimiento no leído. |
| Long & Singh (2013); Sharma, Kilic & Irmak (2016) | Primaria (sensibilidad / escala) | Metadatos; *key points* / resumen (Crossref) | Los extremos (*end-members*) determinan en gran medida la magnitud de la fracción evaporativa; efectos de escala Landsat vs. MODIS (con SEBS, no METRIC) | Texto completo no consultado. |
| Bhattarai et al. (2017); Silva et al. (2019) | Primaria (automatización) | Solo metadatos (Crossref; sin resumen depositado) | Existencia de algoritmos de selección automática, uno de ellos aplicado a MODIS (SEBAL) | Contenido no consultado. |
| `water` v1.0 (2026-10-19; commit `3c94630`, GPL ≥ 2): `R/water_sensibleHeatFlux.R` (`calcAnchors()`, `anchorsPercentile()`, `calcH()`), `R/water_controls.R` (`anchors.control()`, `calcH.control()`), `R/water_internals.R` (`anchorCells()`, `sampleOne()`, `checkRecentRain()`, `waterChoices`), `R/water_METRIC.R` (`METRIC.EB()`) | Secundaria (implementación) | Código y roxygen | Métodos, criterios, valores por defecto y validaciones de una implementación existente | Una implementación no es una fuente científica. **No se copia código** (GPL vs. MIT); se describe con palabras propias. |
| Olmedo et al. (2016), *The R Journal* 8(2) | Secundaria (describe `water`) | Texto completo (`journal.r-project.org`) | Tabla 2 (p. 356) con los rangos del método "CITRA-MCB"; descripción de `calcAnchors()` y `calcH()` (p. 356) | Describe una versión antigua de `water`; atribuye los criterios a Allen et al. (2011) y Tasumi (2003) sin número de página. |
| Notas de revisión del directorio `roadto1/` del repositorio `water` | Terciaria | Texto | Afirman páginas y números de ecuación de Allen et al. (2007) para las condiciones de borde | No verificable; solo orienta qué buscar en la fuente primaria (§8). |

Convención de trazabilidad (igual a `radiation-components.md`):

- **"Observado en `water`"**: el criterio aparece en el código de `water`
  v1.0. Que `water` lo use **no** lo verifica.
- **"Resumen leído"**: la afirmación está en el resumen del artículo,
  leído en esta redacción vía Crossref. Verifica que el artículo **trata**
  el tema, no el detalle (criterios, valores, ecuaciones).
- **"Terciaria"**: afirmación de las notas de revisión de `water` sobre una
  fuente primaria. No verificada.

Metadatos de citas verificados vía `api.crossref.org` el 2026-11-04 (lista
en §8.1). Esto verifica la **cita**, no el contenido.

---

## 1. Rol de las anclas en la calibración interna de METRIC

### 1.1 Qué hacen las anclas

- METRIC obtiene LE como **residuo** (LE = Rn − G − H; SPEC §3). H se
  calcula como H = ρ_air·c_p·dT/r_ah (SPEC §3, `CANDIDATA`), con
  dT = a + b·Ts,datum (SPEC §3, `CANDIDATA`).
- Los píxeles ancla fijan los dos parámetros (a, b) de la relación dT–Ts:
  en cada ancla se **supone** un LE (condición de borde, §2), se despeja
  H_ancla = (Rn − G)_ancla − LE_ancla y de ahí dT_ancla = H_ancla·r_ah/(ρ_air·c_p).
  Dos puntos (frío, caliente) determinan la recta; la estabilidad
  atmosférica obliga a iterar r_ah y dT (especificación futura de
  `metric-dt.R` / `metric-aerodynamics.R`; fuera de alcance aquí).
- Resumen leído (Allen et al., 2011): la calibración "en condiciones
  extremas" busca **eliminar sesgos sistemáticos** de Rn, G, temperatura
  radiométrica y estimaciones aerodinámicas, y expresar dT como función
  **indexada** de Ts, lo que elimina la necesidad de una Ts absolutamente
  exacta y de medir la temperatura del aire. Resumen leído (Allen et al.,
  2013): el procedimiento se denomina CIMEC (*calibration using inverse
  modeling at extreme conditions*) y los dos extremos representan los
  extremos seco y húmedo del espectro de ET.

### 1.2 Aclaraciones obligatorias (consistentes con SPEC §2.1 y §2.2)

1. **Calibración ≠ cierre del balance de energía.** El "cierre" por píxel es
   una identidad (LE se calcula por diferencia), no un logro de las anclas.
   El problema de cierre micrometeorológico (torres eddy covariance)
   pertenece a la **validación** (`VALIDATION_PLAN.md` §2.2). La
   documentación pública no debe decir que las anclas "logran una buena
   clausura".
2. **Las anclas no producen radiación directa ni difusa.** La partición de
   Rs↓ es una propiedad atmosférica y geométrica que se calcula antes y con
   independencia del balance de energía (SPEC §2.2;
   `radiation-components.md` §1.1). Uno o pocos píxeles ancla, a lo sumo,
   absorben parte de un sesgo **total** de Rn en esos píxeles; no separan
   componentes ni generan un campo espacial de partición.
3. **Qué sesgos puede absorber la calibración (hipótesis de trabajo).** Un
   sesgo **uniforme** en la escena (p. ej., en Rn o en Ts) puede quedar
   absorbido por (a, b); un sesgo con **patrón espacial** no puede ser
   absorbido por dos puntos (`radiation-components.md` §3). Esto se evalúa;
   no se afirma.
4. **La calibración transfiere errores de las condiciones de borde a toda
   la escena.** Un error en LE_frío o LE_caliente desplaza (a, b) y, con
   ello, H y LE en todos los píxeles (ver ilustración numérica, §2.5).
   Por eso la auditoría de las anclas es parte del resultado (principio 5
   de `ARCHITECTURE.md`).

### 1.3 Separación de etapas (propuesta de arquitectura)

```text
 surface (Ts, NDVI, α, LAI, cobertura, QA, elevación, hora de paso)
        │
        ▼
 [A] Selección de anclas           ef_select_anchors()  /  ef_anchors()
     solo variables de superficie        → earthflux_anchors (auditoría)
        │
        ▼
 [B] Condiciones de borde          LE_frío, LE_caliente en cada ancla
     requiere Rn, G (metric),            (función futura; ver D-AP-03)
     ETr_inst (forcing/spatial),
     k, ETrF_caliente (parámetros)
        │
        ▼
 [C] Calibración de dT             a, b (iterativa con r_ah)
     metric-dt.R / metric-aerodynamics.R  (especificación futura)
```

Justificación:

- **[A] no usa Rn, G ni meteorología.** Si se adopta T = Ts del píxel frío
  para RL↓ (`radiation-components.md`, decisión RC-12), la selección del
  ancla fría debe ocurrir **antes** de Rn; además, una selección
  independiente del forzamiento permite mantener **las mismas anclas**
  entre configuraciones C1–C3 (`VALIDATION_PLAN.md` §2.1) y aislar el
  efecto del forzamiento en [B].
- Excepción explícita: la distancia a una estación (criterio de búsqueda,
  §3.5) es geometría, no meteorología; se admite en [A] como criterio
  opcional y se registra.
- Las funciones de [A] no conocen el sensor (principios 1–2): reciben
  variables físicas, no bandas ni productos.

---

## 2. Condiciones de borde en cada ancla

### 2.1 Notación

`ETr_inst` (mm h⁻¹): ET de referencia instantánea a la hora de paso (SPEC
§3, fila ETr, `TODO`); `λ` (J kg⁻¹): calor latente de vaporización;
`ρ_w` (kg m⁻³): densidad del agua; `LE` (W m⁻²). Conversión
(SPEC §3, fila ET_inst, `CANDIDATA`): LE = ET_inst·λ·ρ_w/(3600·1000) con
ET_inst en mm h⁻¹ (1 mm de agua = 1 kg m⁻² con ρ_w = 1000 kg m⁻³).
Nota de unidades: la forma registrada en SPEC §3, ET_inst = 3600·LE/(λ·ρ_w)
con λ en J kg⁻¹, da m h⁻¹; para mm h⁻¹ falta el factor 1000. Debe
resolverse al verificar esa fila (no se edita aquí).

### 2.2 Ancla fría — `CANDIDATA`

```text
ET_frío  = k · ETr_inst(x_frío, t_frío)                [mm h⁻¹]
LE_frío  = ET_frío · λ(Ts_frío) / 3600                 [W m⁻²]   (λ en J kg⁻¹)
H_frío   = (Rn − G)_frío − LE_frío
```

| Elemento | Detalle |
|---|---|
| Forma | ET del ancla fría proporcional a la ETr instantánea de referencia **alfalfa**. Observado en `water`, `calcH()` (roxygen y código) y `METRIC.EB()`; fuente primaria citada allí: Allen et al. (2007). Terciaria: las notas de `roadto1/` la sitúan en Allen et al. (2007, p. 387). `CANDIDATA`. |
| Valor candidato de k | **1.05**. Observado en `water` como valor por defecto del argumento `ETp.coef` de `calcH()` y `METRIC.EB()`, con la frase "Allen et al. (2007) use 1.05". Terciaria: "Cold-pixel ET = 1.05·ETr (p. 387)". `CANDIDATA`; `TODO`: verificar valor, página, y si 1.05 está ligado a la referencia alfalfa (ETr) y no a pasto (ETo). |
| λ | En `water`, `calcH()`, λ = (2.501 − 0.002361·(Ts − 273.15))·10⁶ J kg⁻¹ evaluado con la **Ts media** de las anclas frías. En el mismo archivo, la variable de λ usada en otros términos emplea 0.00236 (inconsistencia menor observada). Fuente primaria de la forma de λ: `TODO`. |
| Cobertura parcial | Si el ancla fría no es cobertura plena: (a) observado en `water`: con `anchors.method = "flexible"` y criterios relajados, o con `calcH.control(cold.NDVI.rule = TRUE)`, si el NDVI medio de las anclas frías es < 0.8, k se reemplaza por Kc·ETo/ETr con Kc = 2.11·NDVI − 0.4989 (base pasto), atribuido a Reyes-González et al. (2015). (b) Terciaria: Allen et al. (2007, pp. 387–388) daría ETr,frío/ETr ≈ 1.25–1.30·NDVI con NDVI de techo de atmósfera. Ambas `CANDIDATA`/`TODO`. EarthFlux **no** adopta reglas automáticas de reemplazo de k (ver D-AP-04). |
| Supuestos | Vegetación agrícola de cobertura plena, bien regada; ETr_inst representativa de la ubicación y hora del ancla; referencia (alfalfa/pasto) **idéntica** a la usada para ETr24 en la extrapolación diaria (observado en `water`: misma referencia en `calcH()` y en la ET diaria). |

### 2.3 Ancla caliente — `CANDIDATA` / `TODO`

```text
LE_caliente = ETrF_caliente · ETr_inst(x_cal, t_cal) · λ(Ts_cal) / 3600
              con ETrF_caliente = 0 para suelo desnudo seco
H_caliente  = (Rn − G)_caliente − LE_caliente
```

| Elemento | Detalle |
|---|---|
| LE ≈ 0 (suelo desnudo agrícola seco) | Observado en `water`: `calcH.control(ETrF.hot = 0)` por defecto, comentado como "0 for dry bare soil (Allen et al., 2007, Eq. 47)". `CANDIDATA`. |
| Evaporación residual tras lluvia | Observado en `water`: el roxygen de `calcH.control()` indica que, tras lluvia, Allen et al. (2007, Eq. 47) calculan dT del píxel caliente desde Rn − G − LE_caliente; `water` solo permite una **fracción constante** `ETrF.hot` ∈ [0, 1) indicada por el usuario. Terciaria: Allen et al. (2007, p. 387) usarían un balance hídrico de suelo desnudo tipo FAO-56 para confirmar LE = 0 o aportar un valor no nulo. `TODO`: verificar Eq. 47 y el modelo de balance hídrico. |
| Advertencia por lluvia reciente | Observado en `water`, `checkRecentRain()`: advierte si la estación registró > 5 mm en los 3 días previos a la imagen y `ETrF.hot = 0`. Es una **elección de `water`** (sin referencia citada). EarthFlux no adopta umbrales sin referencia (flag `EF_ANCHOR_HOT_RECENT_RAIN`, umbral `TODO`, §6). |
| Supuestos | Suelo desnudo agrícola sin evaporación; ningún transporte lateral de calor relevante; LE_caliente no negativo. |

### 2.4 Qué necesita EarthFlux como entradas en cada ancla (vínculo con H1)

| Entrada en la ubicación del ancla | Unidad | Módulo de origen | ¿Depende del forzamiento espacial? | Comentario |
|---|---|---|---|---|
| Ts, NDVI, α, LAI, cobertura, QA | K, –, –, m² m⁻², clase, flags | `surface` | No | Selección [A] y auditoría |
| Elevación (para Ts,datum) | m | DEM | No | Ver D-AP-07 (seleccionar sobre Ts o Ts,datum) |
| Hora de paso por píxel | POSIXct UTC | `surface` (*view time*) | No | SPEC §2.4: la ETr_inst del ancla se evalúa a **su** hora de paso |
| Rn, G | W m⁻² | `metric` (`ef_net_radiation()`, G) | Indirecta (RL↓, Rs↓; `radiation-components.md` §3) | Etapa [B] |
| **ETr_inst(x_ancla, t_ancla)** | mm h⁻¹ | `forcing` (estación) **o** `spatial` (GWR) | **Sí** | **Punto de entrada de H1 en la calibración** (SPEC §1.2, fila "Condición del píxel frío") |
| k (ancla fría) | – | Parámetro con fuente y estado | No | Sin defecto en el núcleo (D-AP-04) |
| ETrF_caliente o LE_caliente | – o W m⁻² | Parámetro del usuario o balance hídrico (`TODO`) | Posible (precipitación espacial) | D-AP-05 |
| Viento a altura de mezcla | m s⁻¹ | `forcing` / `spatial` | **Sí** | Entra en r_ah de la etapa [C], no en [A]/[B] |
| Tipo de referencia (`"ETr"` alfalfa / `"ETo"` pasto) | texto | `forcing` | — | Obligatorio y registrado; debe coincidir con ETr24 |

Consecuencias para el diseño experimental (SPEC §1.2; `VALIDATION_PLAN.md`
§2.1):

- **C1 (estación representativa):** ETr_inst es un escalar por escena. Por
  eso `water` restringe la búsqueda a un radio de la estación (§3.5): la
  ETr de la estación debe representar a las anclas.
- **C3 (GWR):** ETr_inst se evalúa **en la celda de cada ancla** (o se
  agrega sobre el conjunto de anclas, D-AP-06). La restricción de radio a
  la estación pierde parte de su justificación, pero aparece otra: la
  incertidumbre de la superficie GWR en la celda del ancla (extrapolación
  geográfica o de covariables, SPEC §6) debe registrarse
  (`EF_ANCHOR_FORCING_EXTRAPOLATED`, §6).
- Para separar el efecto del forzamiento en la **calibración** de su efecto
  en la **extrapolación diaria** (SPEC §1.2) se proponen dos variantes por
  configuración: (i) mismas celdas ancla en C1–C3 (solo cambia ETr_inst en
  [B]); (ii) mismas **reglas** de selección, celdas posiblemente distintas.
  `VALIDATION_PLAN.md` §2.1 menciona "anclas o reglas de anclas": esta
  especificación propone evaluar ambas.

### 2.5 Ilustración numérica (sensibilidad; no es validación)

Cálculo propio con las formas `CANDIDATA` de §2.2 (λ de `water`), solo para
mostrar por qué la ETr en el ancla fría es un punto sensible de H1:

Datos supuestos: Ts_frío = 300 K, (Rn − G)_frío = 600 W m⁻², k = 1.05.

1. λ = 2.501 − 0.002361 × (300 − 273.15) = 2.501 − 0.06339285 =
   **2.43760715 MJ kg⁻¹**.
2. ETr_inst = 0.80 mm h⁻¹ → ET_frío = 0.840 mm h⁻¹ →
   LE_frío = 0.840 × 2.43760715 × 10⁶ / 3600 = **568.775 W m⁻²** →
   H_frío = **31.225 W m⁻²**.
3. ETr_inst = 0.88 mm h⁻¹ (+10 %) → LE_frío = **625.6525 W m⁻²** →
   H_frío = **−25.6525 W m⁻²** (cambia de signo).
4. ETr_inst = 0.72 mm h⁻¹ (−10 %) → LE_frío = **511.8975 W m⁻²** →
   H_frío = **88.1025 W m⁻²**.

Lectura: H_frío es una **diferencia pequeña de números grandes**; ±10 % en
ETr_inst cambia H_frío en ±56.9 W m⁻² (≈ ±182 %) y, con ello, el punto
frío de la recta dT–Ts. Un H_frío negativo no es un error por sí mismo
(advección, SPEC §3 fila H) pero debe quedar diagnosticado
(`EF_ANCHOR_COLD_H_NEGATIVE`, §6).

---

## 3. Criterios de selección

### 3.1 Familias de criterios

| Familia | Ejemplo de regla | Tipo de umbral | Estado |
|---|---|---|---|
| Vegetación (NDVI) | Frío: NDVI ≥ percentil alto; caliente: NDVI ≤ percentil bajo | Relativo a la escena (percentil) | `CANDIDATA` (observado en `water`); literatura `TODO` |
| LAI | Frío: LAI ≥ mínimo de cobertura plena | Absoluto | `CANDIDATA` (`water`); terciaria: LAI > 4 en Allen et al. (2007, pp. 387–388), `TODO` |
| Albedo | Caliente: rango que excluya superficies urbanas y roca brillante | Absoluto | `CANDIDATA` (`water`) |
| Temperatura (Ts) | Frío: fracción más fría de los candidatos; caliente: fracción más caliente | Relativo (percentil o extremo) | `CANDIDATA` (`water`) |
| Homogeneidad | Desviación estándar de Ts en una ventana n × n ≤ umbral | Absoluto (K) y tamaño de ventana | `CANDIDATA` (`water`) |
| Cobertura de suelo | Clases agrícolas para frío y caliente; exclusión de agua, urbano, nieve | Categórico | `TODO` (no implementado en `water`; MCD12Q1 o cobertura local, SPEC §4) |
| Agua | Excluir NDVI ≤ 0 del dominio de percentiles y de candidatos calientes | Absoluto | `CANDIDATA` (`water`) |
| Distancia a la estación | Buscar dentro de un radio; si no hay candidatos, en toda la escena | Absoluto (m) | `CANDIDATA` (`water`) |
| QA | Excluir píxeles con QA de LST/reflectancia degradada, cercanos a nubes o con ángulo de visión alto | Según producto | `TODO` (SPEC §4, §8) |
| Contraste térmico mínimo | Ts_caliente − Ts_frío ≥ umbral | Absoluto (K) | Observado en `water` como **error** (5 K); referencia `TODO` |
| Número mínimo de candidatos | Advertir si hay pocos candidatos | Absoluto | Observado en `water` como **warning** (20); referencia `TODO` |
| Requisitos del área de interés | Tamaño mínimo y presencia de ambos extremos | `TODO` | Resumen leído (Allen et al., 2013): el artículo describe "area of interest requirements"; contenido `TODO` |
| Climas desérticos | Ajuste del extremo seco | `TODO` | Resumen leído (Allen et al., 2013): "adjustment for dry conditions in desert climates"; contenido `TODO` |

### 3.2 Qué prescribe la literatura METRIC

`TODO` en su totalidad. Lo único leído son resúmenes (§0.2):

- Allen et al. (2013), resumen leído: un procedimiento **estadístico,
  consistente y reproducible** que usa relaciones entre **cantidad de
  vegetación y temperatura superficial** para identificar una
  **subpoblación** de píxeles que represente los extremos de calibración;
  incluye requisitos del área de interés, supuestos y un ajuste para
  condiciones secas en climas desérticos; implementado en ERDAS Imagine.
  No se leyeron percentiles, umbrales ni pasos.
- Morton et al. (2013), resumen leído: un algoritmo automático diseñado
  para **imitar el proceso manual** de un usuario entrenado; permite
  análisis de **incertidumbre y sensibilidad**; la variación entre
  calibraciones automáticas fue similar a la variación entre usuarios; la
  incertidumbre fue mayor en campos de ET baja y menor en campos de ET alta
  (≈ 5 % de incertidumbre media estacional). No se leyeron criterios.
- Terciaria (no verificada): Allen et al. (2007) definirían el ancla fría
  como vegetación agrícola de cobertura plena bien regada con LAI > 4
  (pp. 387–388), el ancla caliente como suelo agrícola desnudo y seco
  (p. 387), y advertirían que METRIC "no es un modelo de uso automático"
  y depende de la habilidad del operador (p. 393).

### 3.3 Qué implementa `water` v1.0 (evidencia secundaria)

Métodos disponibles (`waterChoices$anchors.method`): `"percentile"` (por
defecto), `"flexible"`, `"best"`, `"random"`. Los nombres antiguos
`"CITRA-MCB"`, `"CITRA-MCBbc"` (→ `"best"`) y `"CITRA-MCBr"` (→ `"random"`)
se aceptan con advertencia.

#### 3.3.1 Método `"percentile"` (por defecto)

El roxygen lo describe como "en el espíritu" de Allen et al. (2013) y
Morton et al. (2013); no afirma reproducirlos. Descripción con palabras
propias:

1. **Insumos.** NDVI se calcula **dentro** de la función desde las capas R
   y NIR (reflectancia de techo de atmósfera si hay imagen DN; de
   superficie si no); valores fuera de [−1, 1] pasan a `NA`. Usa además
   LAI, albedo y Ts (en K; la función se detiene si Ts parece estar en °C).
2. **Píxeles válidos.** Los que tienen NDVI, LAI, Ts y albedo no faltantes.
3. **Dominio de búsqueda.** Celdas a ≤ `WSbuffer` del centro de la celda de
   la estación (o de la estación, si cae fuera de la imagen). Si ninguna
   celda queda dentro, se usa toda la imagen con advertencia.
4. **Dominio de percentiles.** Píxeles válidos del dominio de búsqueda con
   **NDVI > 0** ("tierra"), para que el agua no desplace los percentiles.
   Si hay menos de 25 píxeles de tierra en el radio, se pasa directamente a
   toda la imagen.
5. **Candidatos fríos:** NDVI ≥ cuantil `cold.NDVI` del NDVI de tierra **y**
   LAI ≥ `cold.LAI`.
6. **Candidatos calientes:** NDVI ≤ cuantil `hot.NDVI`, NDVI > 0 y albedo
   en [0.10, 0.35] (rango fijo en el código; documentado como exclusión de
   superficies urbanas y roca brillante).
7. **Homogeneidad:** desviación estándar de Ts en la ventana de 5 × 5
   píxeles centrada en el candidato (con `na.rm = TRUE`) ≤ `homogeneity`.
   El comentario del código justifica la ventana porque el píxel térmico de
   100 m abarca ≈ 3 × 3 píxeles Landsat. Si **ningún** candidato de un tipo
   es homogéneo, el filtro se elimina para ese tipo y se registra.
8. **Relajación automática** si un conjunto queda vacío: frío, primero baja
   el mínimo de LAI en pasos de 0.25 hasta 3 y luego el cuantil de NDVI en
   pasos de 0.01 hasta 0.85; caliente, sube el cuantil de NDVI en pasos de
   0.01 hasta 0.30. Primero dentro del radio; si falla, en toda la imagen
   (con advertencia).
9. **Selección final:** anclas frías = candidatos fríos con Ts ≤ cuantil
   `cold.fraction` de su Ts; anclas calientes = candidatos calientes con
   Ts ≥ cuantil (1 − `hot.fraction`). Pueden resultar **muchos** píxeles por
   tipo.
10. **Uso en la calibración:** `calcH(method = "mean")` (por defecto) usa
    las **medias** de Ts, Rn, G, etc. de cada conjunto; `method = "lm"`
    itera cada par y conserva solo el último.
11. **Fallo:** error si, tras relajar en toda la imagen, falta un tipo; el
    mensaje incluye la mediana del albedo como pista de escalado.
12. **Cuantiles:** `stats::quantile()` con su tipo por defecto (tipo 7); no
    se registra el tipo.

Valores por defecto (`anchors.control()`):

| Parámetro | Defecto | Significado en `water` |
|---|---|---|
| `cold.NDVI` | 0.95 | Cuantil mínimo de NDVI (tierra) para candidatos fríos |
| `cold.LAI` | 4 | LAI mínimo para candidatos fríos |
| `cold.fraction` | 0.2 | Fracción más fría de los candidatos fríos que se usa |
| `hot.NDVI` | 0.1 | Cuantil máximo de NDVI para candidatos calientes |
| `hot.fraction` | 0.2 | Fracción más caliente de los candidatos calientes que se usa |
| `homogeneity` | 1.5 K | Desviación estándar máxima de Ts en 5 × 5 |
| `WSbuffer` | 30 000 m | Radio de búsqueda alrededor de la estación |
| `min.candidates` | 20 | Bajo este número de candidatos (de cualquier tipo) → warning |
| `deltaTemp` | 5 K | Solo métodos no percentiles (ver 3.3.2) |
| `minDist` | 500 m | Solo métodos no percentiles: distancia mínima entre anclas del mismo tipo |

Validaciones posteriores (`anchorCells()`, llamada por `calcH()`): anclas
dentro de la imagen; Ts, Rn, G, Z.om y DEM no faltantes en ellas; tipo
`"hot"`/`"cold"`; al menos una de cada; Ts,datum media caliente > fría
(si ≤ 0: error que sugiere tipos invertidos) y diferencia ≥ 5 K (si no:
error que sugiere un área mayor). Control global posterior (`METRIC.EB()`):
warning si ETrF > 1.1 en más del 10 % de los píxeles.

#### 3.3.2 Métodos `"best"`, `"random"` y `"flexible"` (rangos fijos "CITRA-MCB")

- Rangos atribuidos en el roxygen a "CITRA and MCB (personal
  communication)"; el artículo de *The R Journal* (Olmedo et al., 2016,
  Tabla 2, p. 356) los atribuye a una adaptación de Allen et al. (2011) y
  Tasumi (2003).
- Frío (código v1.0): LAI 3–6; albedo 0.18–0.25; Z.om 0.03–0.08 m;
  NDVI ≥ máximo de NDVI de la imagen − 0.15; Ts < (cuantil 0.05 de Ts en
  un subconjunto vegetado) + `deltaTemp`, con piso de 288 K + `deltaTemp`.
- Caliente (código v1.0): albedo 0.13–0.15; NDVI 0.10–0.28;
  Z.om ≤ 0.005 m; Ts > (máximo de Ts en un subconjunto de suelo desnudo)
  − `deltaTemp`.
- Discrepancia documental: la Tabla 2 de 2016 da NDVI frío 0.76–0.84,
  mientras el código v1.0 usa "máximo − 0.15".
- `"best"`: el candidato más frío y el más caliente (y, con `n > 1`, los
  siguientes a ≥ `minDist`). `"flexible"`: igual, pero relaja los rangos
  en pasos de 1 % hasta 100 %, primero cerca de la estación y luego en toda
  la imagen; registra la relajación. `"random"`: elige al azar entre los
  candidatos (el caliente, entre los que superan el cuantil 0.75 de Ts de
  los candidatos calientes) con `sample.int()` **sobre el generador global
  y sin argumento de semilla**: el resultado depende del estado de
  `.Random.seed` del usuario.
- Salida común: `data.frame` con celda, X, Y, Ts, LAI, NDVI y tipo; para
  `"flexible"`, columna `flex`; atributos `candidates` (conteos) y
  `relaxation`. **No** registra albedo, cobertura, QA, percentiles
  calculados ni distancia a la estación.

#### 3.3.3 Lecciones para EarthFlux (sin reutilizar código)

| Observación en `water` | Decisión propuesta en EarthFlux |
|---|---|
| NDVI calculado dentro de la selección desde bandas del sensor | `ndvi` como entrada física independiente del sensor |
| Umbrales numéricos por defecto sin referencia primaria verificada | Sin defectos numéricos en el núcleo; criterios explícitos con fuente y estado (D-AP-01) |
| Relajación automática y silenciosa salvo advertencias | Relajación solo si el usuario entrega un plan de relajación explícito; cada paso se registra y se marca con flag (D-AP-02) |
| Tipo de cuantil implícito | `quantile_type` explícito y registrado |
| Azar sobre el generador global | Determinista por defecto; azar solo con `seed` explícita, sin alterar el generador global (§5.4) |
| Registro parcial (sin albedo, QA, cobertura, umbrales calculados) | Registro de auditoría completo (§5.5) |
| Ventana de homogeneidad en **píxeles** (5 × 5) justificada por la geometría Landsat | Ventana especificada en píxeles **y** registrada en metros; su significado a 1 km es una pregunta abierta (§4) |
| Selección sobre Ts, calibración sobre Ts,datum (modo montaña) | Decisión explícita y registrada (D-AP-07) |
| Contraste mínimo de 5 K como error | Error solo para Ts_caliente ≤ Ts_frío (inequívoco); contraste pequeño como flag con umbral `TODO` |

---

## 4. Problemas específicos de MODIS a 1 km (preguntas abiertas)

Contexto: SPEC §2.3 registra que METRIC se formuló para Landsat y que a
1 km es difícil encontrar anclas homogéneas. Resumen leído (Trezza et al.,
2013): el principal desafío de aplicar METRIC con MODIS es **la selección
de las dos condiciones de calibración** por la baja resolución; los autores
describen un procedimiento específico para MODIS que usa las áreas de
**mayor índice de vegetación** junto con una ubicación de **ET
consistentemente baja**, y concluyen que con un esquema de **calibración
cruzada** con Landsat se obtienen estimaciones mensuales y anuales similares,
con pérdida de fidelidad espacial. El procedimiento no se leyó (`TODO`).

| Id | Problema | Pregunta abierta | Propuestas a evaluar (no decididas) |
|---|---|---|---|
| Q-AP-01 | **Píxeles mixtos.** Un píxel de 1 km mezcla cultivo, suelo, caminos, canales y bordes. Ts, NDVI y LAI de 1 km no representan ninguna componente | ¿Qué sesgo introduce en (a, b) un ancla fría mixta? ¿Y una caliente mixta? | Cuantificar con agregación de escenas Landsat a 1 km donde las anclas Landsat son conocidas (experimento sintético-realista, M6) |
| Q-AP-02 | **Escasez de candidatos homogéneos.** En valles regados de Chile central, un campo de cultivo pleno de ≥ 1 km² puede no existir; un suelo desnudo seco agrícola de 1 km² tampoco | ¿Cuántos candidatos quedan con criterios estrictos? ¿Es preferible ampliar el área (más candidatos, menor representatividad de una estación) o relajar criterios? | Reportar siempre el embudo de candidatos (§5.5); la ampliación del área interactúa con H1 (con GWR la representatividad de ETr deja de exigir cercanía a una estación) |
| Q-AP-03 | **Significado de la ventana de homogeneidad.** 5 × 5 píxeles son 150 m × 150 m en Landsat 30 m y 5 km × 5 km en MODIS 1 km | ¿La homogeneidad debe definirse en píxeles o en metros? ¿Con qué umbral de dispersión de Ts? | Homogeneidad más estricta (ventanas mayores o dispersión menor) y su efecto en el número de candidatos; homogeneidad de NDVI además de Ts |
| Q-AP-04 | **Información subpíxel.** NDVI de 250 m (MOD09GQ/MOD13Q1) o de sensores de mayor resolución dentro de la celda de 1 km | ¿Puede usarse la dispersión de NDVI subpíxel como criterio de pureza? ¿Y una fracción de cobertura agrícola desde un mapa local? | Criterio de pureza subpíxel (umbral `TODO`); desagregación térmica (SPEC §2.3) como alternativa; arquitectura independiente del sensor para usar Landsat/Sentinel en la calibración |
| Q-AP-05 | **Calibración cruzada con Landsat.** (resumen leído, Trezza et al., 2013) | ¿Es viable y reproducible en el paquete? ¿Qué requiere (fechas coincidentes, escalado)? | Evaluar como modo alternativo; fuera del alcance de M2 |
| Q-AP-06 | **Desfase temporal de compuestos.** NDVI (16 d), LAI (8 d) y albedo (MCD43) no son del día de paso (SPEC §4) | ¿Un ancla fría puede estar recién cosechada dentro de la ventana del compuesto? | Registrar la fecha o ventana del compuesto por ancla; flag por desfase (umbral `TODO`) |
| Q-AP-07 | **Ángulo de visión.** El píxel MODIS crece fuera del nadir. Resumen leído (Trezza et al., 2013): hay imágenes con ángulo de visión < ~15° cada cuatro a cinco días | ¿Debe restringirse el ángulo de visión de las anclas (o de la escena)? | Criterio QA de ángulo de visión (umbral `TODO`; la cifra de ~15° es una observación de disponibilidad en el resumen, no un criterio verificado) |
| Q-AP-08 | **Sensibilidad.** Long & Singh (2013, *key points* leídos): los extremos determinan en gran medida la magnitud de la fracción evaporativa. Morton et al. (2013, resumen leído): la automatización permite análisis de incertidumbre | ¿Cuánto varía ETa al cambiar las anclas dentro del conjunto de candidatos aceptables? | Conjunto de selecciones alternativas (p. ej., todos los pares candidatos, o remuestreo con semilla explícita) y distribución de ETa resultante (§5.4) |
| Q-AP-09 | **Hora de paso.** La *view time* varía dentro de la escena y entre Terra/Aqua (SPEC §2.4) | ¿ETr_inst se evalúa a la hora de cada ancla o a una hora común? ¿Cómo se agregan anclas con horas distintas? | Evaluar a la hora de cada ancla (propuesta) y registrar la dispersión de horas (D-AP-06) |
| Q-AP-10 | **Terreno complejo.** Ts disminuye con la elevación; seleccionar sobre Ts favorece anclas frías en altura | ¿Seleccionar sobre Ts o sobre Ts,datum? ¿Con qué gradiente? | D-AP-07; `water` usa un gradiente configurable (`calcH.control(lapse = 6.49)` K km⁻¹, valor observado en `water`, `TODO` referencia) solo en la calibración |

---

## 5. API propuesta

### 5.1 Principios

1. **Dos caminos con el mismo resultado:** automático
   (`ef_select_anchors()`) y explícito/manual (`ef_anchors()`), ambos
   devuelven un objeto `earthflux_anchors` con el mismo registro de
   auditoría (SPEC §7: la selección manual debe ser posible).
2. **Determinismo por defecto.** Mismas entradas y criterios → mismas
   celdas, en cualquier orden de ejecución, secuencial o paralelo
   (`ARCHITECTURE.md` §6.3, regla 2).
3. **Sin umbrales implícitos.** Los criterios se pasan como objeto
   explícito; el núcleo no tiene valores numéricos por defecto mientras no
   estén `VERIFICADA` (D-AP-01).
4. **Sin corrección silenciosa.** Nada se relaja, recorta ni reemplaza sin
   registro y flag (principio 6).
5. **Independencia del sensor y de la meteorología** en la selección (§1.3).

### 5.2 Criterios: `ef_anchor_criteria()`

```r
crit <- ef_anchor_criteria(
  cold = list(
    ef_rule("ndvi", ">=", 0.95, scale = "percentile", domain = "land"),
    ef_rule("lai",  ">=", 4,    scale = "absolute")
  ),
  hot = list(
    ef_rule("ndvi",   "<=", 0.10, scale = "percentile", domain = "land"),
    ef_rule("ndvi",   ">",  0,    scale = "absolute"),
    ef_rule("albedo", "between", c(0.10, 0.35), scale = "absolute")
  ),
  homogeneity = ef_homogeneity("lst", window = 5L, stat = "sd", max = 1.5),
  select = list(cold = ef_pick("lst", "lowest_fraction", 0.2),
                hot  = ef_pick("lst", "highest_fraction", 0.2)),
  percentile_domain = "land",        # NDVI > 0 y válidos (definición registrada)
  quantile_type = 7L,
  source = "water v1.0 anchors.control() defaults",
  status = "CANDIDATA"
)
```

- El ejemplo reproduce los valores observados en `water` **solo** para
  mostrar la forma y permitir la verificación cruzada; **no** son valores
  por defecto de EarthFlux.
- Cada regla registra variable, operador, valor, escala (`"absolute"` /
  `"percentile"`), dominio del percentil y, a nivel de objeto, `source`
  (texto con la referencia) y `status` (`"TODO"`, `"CANDIDATA"`,
  `"VERIFICADA"`). Los nombres `ef_rule()`, `ef_homogeneity()` y `ef_pick()`
  son provisionales (D-AP-08: exportarlos o aceptar listas validadas).
- Validación: variables conocidas; operadores de una lista cerrada;
  percentiles en (0, 1]; ventana impar ≥ 3; `quantile_type` en 1–9;
  error `earthflux_input_error` en otro caso.
- Presets con nombre (p. ej., uno que reproduzca `water` para la
  verificación cruzada, o uno de Allen et al., 2013, cuando se verifique)
  serían funciones que devuelven criterios con `source` y `status`
  rellenos; un preset `CANDIDATA` no debe usarse como defecto silencioso de
  `earthflux()` (D-AP-01).

### 5.3 Selección automática: `ef_select_anchors()`

```r
ef_select_anchors(
  lst, ndvi, albedo,              # obligatorios (K, –, –)
  lai = NULL,                     # m² m⁻²; obligatorio si un criterio lo usa
  land_cover = NULL,              # clases (entero o factor) + tabla de clases
  qa = NULL,                      # máscara lógica "píxel utilizable" del módulo surface
  elevation = NULL,               # m; solo si la selección usa Ts,datum (D-AP-07)
  search_area = NULL,             # máscara lógica o geometría (AOI, buffer a estación)
  criteria,                       # ef_anchor_criteria(); sin valor por defecto
  relax = NULL,                   # plan de relajación explícito o NULL (sin relajar)
  aggregate = "none",             # cómo se resumen varios píxeles por tipo (D-AP-06)
  seed = NULL                     # solo para métodos con azar (5.4)
)
```

| Aspecto | Especificación |
|---|---|
| Forma de las entradas | `SpatRaster` de una capa con geometría común (envoltorio `terra`) **o** matrices numéricas con la misma `dim` más resolución de celda en m (núcleo). La homogeneidad y las distancias requieren vecindad, por lo que el núcleo no puede operar sobre vectores sin geometría (D-AP-09) |
| Dominio | `lst > 0` K; `ndvi` ∈ [−1, 1]; `albedo` ∈ [0, 1]; `lai ≥ 0`; fuera → `earthflux_domain_error` (mismo criterio que `soil-heat-flux.md` §6.2). La limpieza por QA es del módulo `surface` |
| NA | Una celda con `NA` en cualquier variable usada por un criterio no es candidata; se cuenta en el embudo (`n_na`). Las ventanas de homogeneidad con celdas `NA` o que cruzan el borde de la grilla se registran (`EF_ANCHOR_WINDOW_INCOMPLETE`) y su tratamiento es explícito (`window_na = "exclude"` propuesto: el candidato no es homogéneo si la ventana está incompleta; `water` calcula con las celdas disponibles) |
| Orden de operaciones | (1) validación; (2) máscara de utilizables (`qa`, `search_area`, no `NA`); (3) dominio de percentiles; (4) umbrales calculados; (5) reglas por tipo; (6) homogeneidad; (7) selección final; (8) chequeos de consistencia; (9) flags y registro. Cada paso aporta una fila al embudo |
| Empates | Determinista: por la variable de selección y luego por **índice de celda ascendente** (orden de celdas de `terra`: por filas, desde arriba a la izquierda). Se registra si hubo empates |
| Búsqueda por etapas (radio → escena) | Solo si `search_area` se entrega como lista ordenada de dominios; se registra en qué dominio se encontraron candidatos y se marca con flag |
| Relajación | `relax = NULL` (defecto): no se relaja; si un tipo queda vacío → error con diagnóstico (5.6). Con un plan explícito (lista ordenada de criterios alternativos) se prueba cada paso, se registra el paso usado y se marca `EF_ANCHOR_CRITERIA_RELAXED` |
| Chequeos de consistencia | Ts media (o de cada par) caliente > fría: si no, `earthflux_anchor_inverted`. Contraste pequeño → flag con umbral `TODO` |
| Efectos colaterales | Ninguno: no escribe archivos, no grafica, no imprime, no altera el generador aleatorio global ni opciones |

### 5.4 Azar y semillas

- Ningún paso de la selección descrita en 5.3 usa azar.
- Usos posibles de azar (futuros): conjuntos de selecciones alternativas
  para análisis de sensibilidad (Q-AP-08) o un método de muestreo entre
  candidatos. Reglas:
  1. Un método con azar exige `seed` (entero) explícito; sin él →
     `earthflux_seed_required` (subclase de `earthflux_input_error`).
  2. El generador se usa de forma **local**: se guarda y restaura
     `.Random.seed` del usuario (o se usa un flujo L'Ecuyer independiente);
     el estado global queda idéntico tras la llamada (test 7.4).
  3. La procedencia registra `seed`, `RNGkind()` y la versión de R.
  4. En paralelo, semillas por tarea derivadas de forma reproducible
     (`future.seed`, `ARCHITECTURE.md` §6.3); resultado idéntico al
     secuencial.

### 5.5 Clase `earthflux_anchors` y registro de auditoría

Lista con clase `c("earthflux_anchors", "list")`:

| Elemento | Contenido |
|---|---|
| `pixels` | `data.frame`, una fila por píxel ancla: `id`, `type` (`"cold"`/`"hot"`), `cell`, `row`, `col`, `x`, `y`; `lst` (K), `lst_datum` (K, si aplica), `ndvi`, `albedo`, `lai`, `land_cover`, `qa` (resumen), `elevation`; estadístico de homogeneidad (`lst_sd_window`, K) y `window_n_valid`; `distance_to_station` (m, si hay estación); rangos percentiles del píxel en el dominio de percentiles para Ts, NDVI, albedo y LAI; `overpass_time` (si se entrega); `composite_dates` (si se entregan) |
| `calibration_points` | Valores por tipo que usará la etapa [B]/[C] según `aggregate` (p. ej., medias o medianas de Ts y otras variables), con el método de agregación |
| `criteria` | Objeto `ef_anchor_criteria` usado (incluye `source` y `status`) |
| `thresholds` | Umbrales **calculados** (p. ej., valor del cuantil 0.95 de NDVI = 0.81), `quantile_type`, tamaño del dominio de percentiles |
| `search` | Descripción del dominio: número de celdas totales, utilizables, de tierra; geometría o radio usado; estación (coordenadas, CRS); etapa de búsqueda en que se encontró cada tipo |
| `funnel` | Conteo de celdas por paso y tipo (válidas → dominio → cada regla → homogéneas → seleccionadas) |
| `relaxation` | Pasos de relajación aplicados (vacío si ninguno) |
| `flags` | Lista de `earthflux_flag` (§6) |
| `method` | `"percentile"` u otro nombre exacto; `"manual"` para `ef_anchors()` |
| `origin` | `"automatic"` o `"user"` |
| `conditions` | `NULL` hasta la etapa [B]; luego k, fuente y estado de k, tipo de referencia, ETr_inst en cada ancla y su origen (estación/GWR) y hora, ETrF_caliente o LE_caliente y su origen (D-AP-03) |
| `provenance` | Versión de EarthFlux y de R, fecha, llamada, procedencia de las capas de entrada (producto, fechas, compuestos), CRS, resolución, `seed` y `RNGkind()` (o `NULL`) |

Métodos:

- `print()`: método y origen; número de píxeles frío/caliente; Ts
  representativa de cada tipo y su diferencia (K); candidatos por tipo;
  dominio de búsqueda usado; si hubo relajación; número de flags por
  severidad; estado de los criterios (`CANDIDATA`/`VERIFICADA`).
- `summary()`: tabla por píxel; embudo de candidatos; umbrales calculados;
  rangos percentiles; distancias a la estación; flags con descripción.
- `as.data.frame()`: `pixels`. Exportación a vector espacial y `plot()`
  (Ts o RGB de fondo con anclas superpuestas) en `plot.R`, M5; la
  inspección visual de las anclas es parte de la auditoría.

### 5.6 Modos de fallo

Todas las clases heredan de `earthflux_anchor_error` → `earthflux_error`
(nombres finales a confirmar con `R/utils.R`). Los errores de selección
deben **transportar diagnósticos** (embudo, umbrales calculados, tipo
faltante), lo que requiere que `ef_abort()` acepte campos adicionales en la
condición (D-AP-10).

| Situación | Clase propuesta | Diagnóstico adjunto |
|---|---|---|
| Ningún candidato frío y/o caliente | `earthflux_anchor_no_candidates` | `type` (`"cold"`, `"hot"`, `"both"`), `funnel`, `thresholds`, dominio usado; mensaje con el paso del embudo que dejó el conjunto vacío |
| Dominio de percentiles vacío o insuficiente | `earthflux_anchor_insufficient_domain` | Tamaño del dominio; umbral mínimo `TODO` (water usa 25 píxeles de tierra, elección de `water`) |
| Ts caliente ≤ Ts fría | `earthflux_anchor_inverted` | Ts de cada tipo; sugerencia de tipos invertidos |
| Ancla manual fuera de la grilla | `earthflux_anchor_outside_grid` | Índices de las anclas afectadas |
| Variable requerida `NA` en un ancla manual | `earthflux_anchor_na_input` | Variable y ancla |
| Criterio inválido o variable requerida no entregada | `earthflux_input_error` / `earthflux_missing_input` | Regla o argumento |
| Método con azar sin semilla | `earthflux_seed_required` | — |
| Entradas fuera de dominio físico | `earthflux_domain_error` | — |
| Geometrías incompatibles | `earthflux_dimension_error` | — |

Pocos candidatos o contraste térmico pequeño **no** son errores: son flags
(con umbral `TODO`).

### 5.7 Constructor explícito: `ef_anchors()`

```r
ef_anchors(
  cold, hot,                 # celdas (enteros) o coordenadas (matriz x, y / data.frame)
  crs = NULL,                # obligatorio si se entregan coordenadas
  lst, ndvi, albedo,         # mismas capas que en la selección, para el registro
  lai = NULL, land_cover = NULL, qa = NULL, elevation = NULL,
  aggregate = "none",
  note = NULL                # texto libre del usuario (motivo de la selección)
)
```

- Valida: tipos; coordenadas → celdas con la grilla de `lst`; anclas dentro
  de la grilla; al menos una de cada tipo; sin celdas repetidas entre tipos;
  variables requeridas no `NA` en las anclas; Ts caliente > fría.
- Extrae de las capas los mismos atributos que la selección automática y
  calcula los mismos estadísticos (homogeneidad, rangos percentiles con un
  `quantile_type` y dominio registrados), de modo que una selección manual
  sea **auditable con la misma tabla**.
- `method = "manual"`, `origin = "user"`, flag `EF_ANCHOR_USER_SUPPLIED`;
  `criteria = NULL` (o los criterios con los que el usuario quiera
  contrastarla, que se evalúan y registran sin descartar anclas).
- Invariante (test 7.5): `ef_anchors()` con las celdas de una selección
  automática produce `pixels` y `calibration_points` idénticos.

---

## 6. Flags propuestos (no registrados)

Se registran en `ef_flag_registry()` solo cuando la función se implemente y,
para los que dependen de umbrales, cuando el umbral tenga referencia
(`R/diagnostics.R`; SPEC §8). En el objeto de anclas, `index` refiere a las
filas de `pixels` (o a celdas de la grilla, a decidir en D-AP-10).

| Código propuesto | Condición | Severidad | ¿Condición inequívoca? |
|---|---|---|---|
| `EF_ANCHOR_USER_SUPPLIED` | Anclas entregadas por el usuario (`ef_anchors()`) | info | Sí |
| `EF_ANCHOR_CRITERIA_RELAXED` | Se usó un paso del plan de relajación distinto del primero | warning | Sí |
| `EF_ANCHOR_SEARCH_EXPANDED` | Los candidatos de un tipo se encontraron fuera del primer dominio de búsqueda (p. ej., fuera del radio a la estación) | warning | Sí |
| `EF_ANCHOR_HOMOGENEITY_DROPPED` | Se omitió el criterio de homogeneidad para un tipo (solo posible mediante un plan de relajación explícito) | warning | Sí |
| `EF_ANCHOR_WINDOW_INCOMPLETE` | La ventana de homogeneidad de un ancla tiene celdas `NA` o cruza el borde de la grilla | warning | Sí |
| `EF_ANCHOR_TIES` | Hubo empates en la selección, resueltos por índice de celda | info | Sí |
| `EF_ANCHOR_SINGLE_PIXEL` | Un tipo quedó representado por un solo píxel | info | Sí |
| `EF_ANCHOR_COLD_H_NEGATIVE` | En la etapa [B], H_frío < 0 (LE_frío > Rn − G) | warning | Sí |
| `EF_ANCHOR_HOT_LE_ASSUMED_ZERO` | En la etapa [B], LE_caliente = 0 por supuesto (no por balance hídrico) | info | Sí (registro de auditoría) |
| `EF_ANCHOR_FEW_CANDIDATES` | Candidatos de un tipo bajo un mínimo | warning | **No**: el mínimo requiere referencia (`water` usa 20, elección propia) → no registrar |
| `EF_ANCHOR_SMALL_CONTRAST` | Ts_caliente − Ts_frío bajo un mínimo | warning | **No**: umbral `TODO` (`water` usa 5 K como error) → no registrar |
| `EF_ANCHOR_COLD_PARTIAL_COVER` | Ancla fría con NDVI o LAI bajo un umbral de cobertura plena | warning | **No**: umbral `TODO` (terciaria: LAI > 4) → no registrar |
| `EF_ANCHOR_HOT_RECENT_RAIN` | Precipitación reciente con LE_caliente = 0 supuesto | warning | **No**: umbral y ventana `TODO` (`water`: 5 mm / 3 d, elección propia) → no registrar |
| `EF_ANCHOR_QA_DEGRADED` | QA del producto no óptimo en un ancla | warning | Depende de la definición de QA del módulo `surface` (SPEC §8) → `TODO` |
| `EF_ANCHOR_HIGH_VIEW_ANGLE` | Ángulo de visión del ancla sobre un umbral | warning | **No**: umbral `TODO` (Q-AP-07) |
| `EF_ANCHOR_COMPOSITE_LAG` | Desfase entre compuesto (NDVI/LAI/albedo) y día de paso sobre un umbral | warning | **No**: umbral `TODO` (Q-AP-06) |
| `EF_ANCHOR_FORCING_EXTRAPOLATED` | ETr_inst en el ancla proviene de una superficie GWR marcada como extrapolación | warning | Sí, si la especificación GWR define la extrapolación de forma inequívoca (SPEC §6) |
| `EF_ANCHOR_OVERPASS_SPREAD` | Anclas de un mismo tipo con horas de paso distintas | info | Sí (la magnitud tolerable es `TODO`) |

---

## 7. Diseño de tests (`tests/testthat/test-anchors.R`)

> **Advertencia.** Los criterios usados en los tests son **parámetros de
> prueba**. Cuando coinciden con los observados en `water` es solo para
> permitir la verificación cruzada; no son valores por defecto de EarthFlux
> ni están verificados.

### 7.1 Caso P1 — vector de 12 celdas (umbral percentil y dominio)

Grilla de 1 × 12 (sin ventana de homogeneidad; `homogeneity = NULL`).
Criterios de prueba: dominio de percentiles = celdas válidas con NDVI > 0;
frío: NDVI ≥ Q(0.75) y LAI ≥ 4, selección Ts ≤ Q(0.5) de los candidatos;
caliente: NDVI ≤ Q(0.2), NDVI > 0, albedo ∈ [0.10, 0.35], selección
Ts ≥ Q(0.5) de los candidatos; `quantile_type = 7`.

| Celda | NDVI | LAI | α | Ts (K) | Comentario |
|---|---|---|---|---|---|
| 1 | 0.10 | 0.1 | 0.25 | 321 | Suelo desnudo |
| 2 | 0.15 | 0.2 | 0.40 | 324 | Brillante (excluida por α) |
| 3 | 0.20 | 0.3 | 0.22 | 318 | |
| 4 | 0.30 | 0.8 | 0.20 | 312 | |
| 5 | 0.40 | 1.2 | 0.19 | 309 | |
| 6 | 0.50 | 1.8 | 0.19 | 306 | |
| 7 | 0.60 | 2.5 | 0.18 | 303 | |
| 8 | 0.70 | 4.0 | 0.18 | 299 | |
| 9 | 0.80 | 4.5 | 0.19 | 297 | |
| 10 | 0.90 | 5.0 | 0.20 | 296 | |
| 11 | −0.20 | 0.0 | 0.06 | 291 | Agua (la celda más fría; fuera del dominio) |
| 12 | `NA` | 1.0 | 0.20 | 305 | Inválida |

Cálculo a mano (cuantil tipo 7: h = (n − 1)·p + 1, interpolación lineal
entre los valores ordenados x₍⌊h⌋₎ y x₍⌊h⌋₊₁₎):

1. Válidas: 11 (celda 12 excluida). Dominio de percentiles (NDVI > 0): 10
   celdas (1–10); NDVI ordenado 0.10, 0.15, …, 0.90.
2. Q(0.75): h = 9 × 0.75 + 1 = 7.75 → 0.60 + 0.75 × (0.70 − 0.60) =
   **0.675**. Candidatos fríos por NDVI: celdas 8, 9, 10; por LAI ≥ 4: las
   tres → **{8, 9, 10}**.
3. Ts de candidatos fríos: 299, 297, 296 → Q(0.5): h = 2 × 0.5 + 1 = 2 →
   **297**. Anclas frías: Ts ≤ 297 → **{9, 10}**; Ts media **296.5 K**.
4. Q(0.2): h = 9 × 0.2 + 1 = 2.8 → 0.15 + 0.8 × (0.20 − 0.15) = **0.19**.
   Candidatos calientes por NDVI: celdas 1, 2; por α ∈ [0.10, 0.35]: solo
   la 1 → **{1}**. Ancla caliente: **{1}**, Ts **321 K**
   (`EF_ANCHOR_SINGLE_PIXEL`).
5. Contraste: 321 − 296.5 = **24.5 K**.
6. Embudo esperado: total 12; válidas 11; dominio 10; frío NDVI 3, LAI 3,
   seleccionadas 2; caliente NDVI 2, α 1, seleccionadas 1.
7. La celda 11 (agua, la más fría) **no** es ancla.

Variante P1-q6 (sensibilidad al tipo de cuantil): con `quantile_type = 6`
(h = (n + 1)·p), Q(0.75) = 0.70 + 0.25 × 0.10 = **0.725** → candidatos
fríos {9, 10}; Q(0.5) de (297, 296) = 296.5 → ancla fría **{10}**. Los
valores se comprobaron con `stats::quantile()` (R 4.3.3). El test verifica
que el tipo de cuantil cambia el resultado y que queda registrado en
`thresholds`.

### 7.2 Caso S1 — escena 2-D con anclas conocidas por construcción

Escena de 15 × 15 celdas (tamaño de prueba; `VALIDATION_PLAN.md` §1.1 cita
una escena 5 × 5 como mínimo, insuficiente para ventanas de 5 × 5 con
interior):

- Fondo heterogéneo: Ts, NDVI, α y LAI variables (patrón determinista, p.
  ej., función de fila y columna), sin valores extremos.
- Bloque frío uniforme de 5 × 5 (Ts 295 K, NDVI 0.85, LAI 5, α 0.20).
- Bloque caliente uniforme de 5 × 5 (Ts 320 K, NDVI 0.10, LAI 0.1, α 0.25).
- Trampas: (a) una celda aislada más fría que el bloque frío con NDVI y LAI
  altos en el fondo (sin homogeneidad); (b) una celda aislada más caliente
  que el bloque caliente con α = 0.45 (urbana); (c) una celda de agua
  (NDVI < 0) más fría que todo.
- Criterio de homogeneidad de prueba: ventana 3 × 3, `max` positivo menor
  que la desviación estándar mínima de cualquier ventana que mezcle bloque y
  fondo (calculable y fijada en el test).

Esperado **por construcción** (no requiere cálculo publicado): los
candidatos homogéneos de cada tipo son exactamente las 3 × 3 celdas
interiores de cada bloque (desviación estándar 0); ninguna trampa es
seleccionada; los conteos del embudo coinciden con los calculados en el
test.

### 7.3 Determinismo

- Dos llamadas idénticas → `identical()` en `pixels`, `thresholds`,
  `funnel` y `flags` (la procedencia puede diferir solo en la fecha).
- Empates: dos celdas con Ts idéntica en el límite de selección → se
  resuelve por índice de celda ascendente; `EF_ANCHOR_TIES` presente.
- El orden de las capas en la llamada y el uso de `numeric`/matriz vs.
  `SpatRaster` no cambian el resultado.
- Tamaño de bloque del envoltorio `terra` y ejecución secuencial vs.
  paralela → resultado idéntico (`ARCHITECTURE.md` §6.3 y §6.6).
- `.Random.seed` del usuario idéntico antes y después de una selección
  determinista (y también de una con `seed`, ver 7.4).

### 7.4 Semillas (solo si se implementa un método con azar)

- Sin `seed` → `earthflux_seed_required`.
- Misma `seed` → resultado idéntico; la `seed` y `RNGkind()` quedan en
  `provenance`.
- El estado global del generador no cambia.
- Secuencial = paralelo con la misma `seed`.

### 7.5 Equivalencia manual ≡ automático

- `auto <- ef_select_anchors(...)`; `man <- ef_anchors(cold = celdas frías
  de auto, hot = celdas calientes de auto, mismas capas)`:
  `man$pixels` y `man$calibration_points` idénticos a los de `auto` salvo
  `origin`, `method` y flags de origen.
- Entrada por coordenadas de los centros de celda ≡ entrada por celdas.
- Cuando exista la calibración de dT, (a, b) idénticos con ambas.

### 7.6 Errores y flags

- P1 sin celdas con LAI ≥ 4 → `earthflux_anchor_no_candidates`, con
  `type = "cold"` y el embudo mostrando el paso que vació el conjunto.
- Ambos vacíos → `type = "both"`.
- `ef_anchors()` con tipos invertidos → `earthflux_anchor_inverted`; con una
  celda fuera de la grilla → `earthflux_anchor_outside_grid`; con `NA` en
  Ts del ancla → `earthflux_anchor_na_input`.
- Plan de relajación explícito que se usa → `EF_ANCHOR_CRITERIA_RELAXED` y
  `relaxation` no vacío; sin plan → error, nunca relajación.
- Los flags con umbral `TODO` **no** existen en el registro (test que lo
  confirme, como en `soil-heat-flux.md` §9.5).

### 7.7 Propiedades (invariantes)

- Agregar celdas `NA` o de agua (NDVI ≤ 0) en el fondo no cambia las anclas
  cuando el dominio de percentiles es "tierra" (propiedad del diseño
  observado en `water`).
- Cambiar valores fuera del dominio de búsqueda no cambia las anclas.
- Cambiar una variable no usada por ningún criterio no cambia las anclas.

### 7.8 Verificación cruzada con `water` (fuera del tarball)

Según `VALIDATION_PLAN.md` §1.3: script que use `water` solo si está
instalado, con criterios que reproduzcan `anchors.control()` y escenas
sintéticas `SpatRaster`. Diferencias esperadas y explicadas, no forzadas:
NDVI calculado por `water` desde capas R/NIR (proveer capas R/NIR
coherentes con el NDVI de EarthFlux); ventana de homogeneidad con celdas
disponibles (`na.rm = TRUE`) frente a `window_na = "exclude"`; relajación
automática de `water` (desactivar con escenas donde no se active);
búsqueda radio → escena automática.

---

## 8. Ítems a verificar en fuentes primarias

### 8.1 Metadatos verificados vía Crossref (2026-11-04)

Verifica la cita (autores, año, título, revista, volumen, páginas, DOI),
**no** el contenido.

| Referencia | DOI | En `REFERENCES.md` |
|---|---|---|
| Allen, R. G., Tasumi, M., & Trezza, R. (2007). *METRIC — Model*. J. Irrig. Drain. Eng., 133(4), 380–394 | `10.1061/(ASCE)0733-9437(2007)133:4(380)` | Sí (`TODO: verify DOI`) |
| Allen, R. G., Tasumi, M., Morse, A., Trezza, R., Wright, J. L., Bastiaanssen, W., Kramber, W., Lorite, I., & Robison, C. W. (2007). *METRIC — Applications*. J. Irrig. Drain. Eng., 133(4), 395–406 | `10.1061/(ASCE)0733-9437(2007)133:4(395)` | Sí |
| Allen, R., Irmak, A., Trezza, R., Hendrickx, J. M. H., Bastiaanssen, W., & Kjaersgaard, J. (2011). Hydrol. Process., 25(26), 4011–4027 | `10.1002/hyp.8408` | Sí |
| Allen, R. G., Burnett, B., Kramber, W., Huntington, J., Kjaersgaard, J., Kilic, A., Kelly, C., & Trezza, R. (2013). JAWRA, 49(3), 563–576 | `10.1111/jawr.12056` | Sí |
| Morton, C. G., Huntington, J. L., Pohll, G. M., Allen, R. G., McGwire, K. C., & Bassett, S. D. (2013). JAWRA, 49(3), 549–562 | `10.1111/jawr.12054` | Sí |
| Allen, R. G., Trezza, R., Kilic, A., Tasumi, M., & Li, H. (2013). *Sensitivity of Landsat-scale energy balance to aerodynamic variability in mountains and complex terrain*. JAWRA, 49(3), 592–604 (nueva) | `10.1111/jawr.12055` | No |
| Trezza, R., Allen, R., & Tasumi, M. (2013). Remote Sensing, 5(10), 5397–5423 (nueva) | `10.3390/rs5105397` | No |
| Long, D., & Singh, V. P. (2013). Water Resour. Res., 49(5), 2601–2618 (nueva) | `10.1002/wrcr.20208` | No |
| Bhattarai, N., Quackenbush, L. J., Im, J., & Shaw, S. B. (2017). Remote Sens. Environ., 196, 178–192 (nueva) | `10.1016/j.rse.2017.05.009` | No |
| Silva, A. M., da Silva, R. M., & Santos, C. A. G. (2019). Int. J. Appl. Earth Obs. Geoinf., 79, 1–11 (nueva) | `10.1016/j.jag.2019.02.012` | No |
| Sharma, V., Kilic, A., & Irmak, S. (2016). Water Resour. Res., 52(3), 1800–1819 (nueva) | `10.1002/2015WR017772` | No |
| Bastiaanssen, W. G. M., Menenti, M., Feddes, R. A., & Holtslag, A. A. M. (1998). J. Hydrol., 212–213, 198–212 | `10.1016/S0022-1694(98)00253-4` | Sí (`TODO: verify full citation`) |
| Olmedo, G. F., Ortega-Farías, S., de la Fuente-Sáiz, D., Fonseca-Luengo, D., & Fuentes-Peñailillo, F. (2016). The R Journal, 8(2), 352– (nueva; Crossref registra solo la página inicial) | `10.32614/RJ-2016-051` | No |
| *Use of Remote Sensing to Generate Crop Coefficient and Estimate Actual Crop Evapotranspiration*, 2015 ASABE International Meeting (nueva; citada por `water` como Reyes-González et al., 2015; Crossref no registra autores) | `10.13031/aim.20152190105` | No |

Las entradas "(nueva)" se agregan a `REFERENCES.md` al integrar este
documento (no se edita aquí).

### 8.2 Qué verificar en cada fuente

**Allen, Tasumi & Trezza (2007), METRIC — Model:**

1. Ecuación y página de la condición del ancla fría; valor de k (1.05,
   según `water` y la fuente terciaria) y si se define sobre ETr alfalfa.
2. Regla para ancla fría de cobertura parcial (terciaria: ≈ 1.25–1.30·NDVI
   con NDVI de techo de atmósfera, pp. 387–388): forma exacta y dominio.
3. Eq. 47 (según `water`): LE del ancla caliente; modelo de balance hídrico
   de suelo desnudo (¿FAO-56?), parámetros, ventana de lluvia.
4. Definición operativa de ancla fría (terciaria: LAI > 4, pp. 387–388) y
   caliente (suelo agrícola desnudo y seco, p. 387).
5. Forma de λ y de la conversión LE ↔ ET_inst (constantes 2.501 y 0.002361
   o 0.00236).
6. Si las anclas se seleccionan sobre Ts o sobre Ts,datum, y el gradiente
   de elevación usado (D-AP-07).
7. Cómo se combinan varios píxeles por tipo, si procede (D-AP-06).
8. Advertencias sobre dependencia del operador (terciaria: p. 393).

**Allen et al. (2013), automated calibration:**

9. Variables, percentiles y umbrales del procedimiento estadístico
   (relación vegetación–Ts); orden de los pasos.
10. Requisitos del área de interés (tamaño mínimo, presencia de extremos).
11. Ajuste para climas desérticos (extremo seco).
12. Tratamiento de agua, nubes, homogeneidad y QA.
13. Si define un número de candidatos y cómo se agregan.
14. Sensor y resolución para los que se desarrolló (Landsat) y comentarios
    sobre otros sensores.

**Morton et al. (2013):**

15. Algoritmo automático: criterios, percentiles, componente aleatorio (si
    lo hay) y cómo se reproduce.
16. Método de análisis de incertidumbre/sensibilidad (insumo para Q-AP-08).

**Trezza, Allen & Tasumi (2013), MODIS:**

17. Procedimiento de calibración específico para MODIS (áreas de mayor
    índice de vegetación + ubicación de ET consistentemente baja).
18. Esquema de calibración cruzada con Landsat (Q-AP-05).
19. Criterio de ángulo de visión y su justificación (Q-AP-07).

**Allen et al. (2011):**

20. Descripción de CIMEC y de qué sesgos se absorben (insumo para §1.2,
    punto 3).

**Otras:**

21. Long & Singh (2013): magnitud de la sensibilidad de la fracción
    evaporativa a los extremos; implicancias para 1 km.
22. Bhattarai et al. (2017); Silva et al. (2019): criterios de selección
    automática y su aplicabilidad a MODIS.
23. Sharma et al. (2016): efectos de escala (aunque con SEBS) relevantes
    para Q-AP-01.
24. ASCE-EWRI (2005): ETr horaria/instantánea (alfalfa) para la condición
    del ancla fría (fila ETr de SPEC §3).
25. Reyes-González et al. (2015): autores, relación Kc–NDVI, cultivo,
    sitio y base de referencia (solo si se considera D-AP-04).
26. Guías de usuario MODIS (LST, MOD09/MOD13, MCD15, MCD43, MCD12Q1): bits
    QA y *view time* usados como criterios de anclas (SPEC §4, §8).

---

## 9. Decisiones abiertas

| Id | Decisión | Opción recomendada (provisional) | Requiere |
|---|---|---|---|
| D-AP-01 | Valores por defecto de los criterios | Ninguno en el núcleo; presets con nombre, `source` y `status`; `earthflux()` solo podrá fijar un preset `VERIFICADA` | Ítems 9–14 |
| D-AP-02 | Relajación automática | No por defecto; solo con plan explícito registrado | Confirmación del autor |
| D-AP-03 | Dónde viven las condiciones de borde | Función propia de la etapa [B] (nombre a definir) que completa `conditions`; la selección no conoce la meteorología | Especificación de `metric-dt.R` |
| D-AP-04 | k del ancla fría y reglas de cobertura parcial | k explícito sin defecto en el núcleo; sin reemplazos automáticos (Kc–NDVI) | Ítems 1–2, 25 |
| D-AP-05 | LE del ancla caliente | `etrf_hot` o `le_hot` explícitos; balance hídrico como trabajo futuro | Ítem 3 |
| D-AP-06 | Agregación de varios píxeles por tipo (y de sus ETr_inst y horas de paso) | `aggregate` explícito; registrar dispersión; evaluar media de entradas vs. calibración por píxel | Ítem 7, Q-AP-09 |
| D-AP-07 | Seleccionar sobre Ts o Ts,datum | Configurable y registrado; recomendado evaluar en Andes | Ítem 6, Q-AP-10 |
| D-AP-08 | Exportar los constructores de reglas | Exportar solo `ef_anchor_criteria()`; reglas como listas validadas | Revisión del tamaño de la API pública |
| D-AP-09 | Núcleo sobre matrices + resolución vs. solo `SpatRaster` | Núcleo sobre matrices (tests sin dependencias espaciales); envoltorio `terra` | `ARCHITECTURE.md` §3 |
| D-AP-10 | Condiciones con datos adjuntos e `index` de flags en objetos no rasterizados | Extender `ef_abort()` con campos opcionales; `index` sobre filas de `pixels` | `R/utils.R`, `R/diagnostics.R` |
| D-AP-11 | Restricción por distancia a la estación con forzamiento GWR | Mantener como criterio opcional; en C3 registrar incertidumbre de GWR en el ancla en lugar de exigir cercanía | Especificación GWR (SPEC §6) |
| D-AP-12 | Estrategia para MODIS 1 km (homogeneidad estricta, información subpíxel, calibración cruzada, sensibilidad) | Ninguna decidida; evaluar en M6 | Q-AP-01 a Q-AP-08 |

---

## 10. Paso a `VERIFICADA`

Un criterio o condición de borde de este documento pasa a `VERIFICADA` (y
puede implementarse) solo cuando: se contrastó con la fuente primaria
(ítems de §8.2 que le correspondan, con página o número de ecuación); la
referencia tiene DOI en `REFERENCES.md`; sus entradas, unidades, NA y
dominio están definidos (§5.3); existe un caso numérico (§2.5, §7.1
recalculados si cambian las formas) y los tests están diseñados (§7). En
ese momento se actualizan SPEC §7 (y §1.2, fila "Condición del píxel frío")
y la sección *Anchor pixel selection* de `REFERENCES.md`.
