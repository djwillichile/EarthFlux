# EarthFlux

**MODIS + METRIC + GWR → ETa**

Especificación científica interna · Estado: **borrador M0 → M1** · Versión del paquete: 0.0.0.9000

> **Regla fundamental.** Ninguna ecuación científica entra al código sin
> referencia, unidades, supuestos, dominio y un caso de prueba verificable.

Este documento es la fuente de verdad científica del paquete. El código
implementa lo que aquí está especificado y verificado; no al revés.

Convención de estados usados en este documento:

| Estado | Significado |
|---|---|
| `TODO` | Falta información o verificación bibliográfica. No implementar. |
| `CANDIDATA` | Forma conocida en la literatura, pendiente de verificar contra la fuente primaria (ecuación, página, constantes). No implementar. |
| `VERIFICADA` | Ecuación contrastada con la fuente primaria, con unidades, dominio y caso numérico. Puede implementarse. |

En M0 **ninguna** ecuación está en estado `VERIFICADA`.

---

## 1. Objetivo científico

Implementar un flujo reproducible para estimar evapotranspiración real (ETa)
espacialmente distribuida:

```text
MODIS (estado de superficie)  +  meteorología (estaciones)
                                        ↓
                    regionalización espacial (GWR u otra alternativa)
                                        ↓
                                     METRIC
                                        ↓
                           balance de energía superficial
                                        ↓
                                      ETrF
                                        ↓
                                       ETa
```

### 1.1 Hipótesis de investigación (no asumida)

> H1: Representar espacialmente el forzamiento meteorológico de METRIC
> mediante GWR, en lugar de una única estación considerada representativa,
> reduce el error de ETa frente a observaciones independientes.

H1 **no se asume verdadera**. El software debe permitir contrastarla contra
(a) METRIC + estación representativa y (b) METRIC + una alternativa espacial
de referencia (ver `VALIDATION_PLAN.md`). Un resultado nulo o negativo es un
resultado científico válido.

### 1.2 Dónde entra el forzamiento meteorológico en METRIC

Este punto condiciona el diseño experimental. La calibración interna de METRIC
(píxeles ancla) absorbe parte de los sesgos de forzamiento, por lo que el
efecto esperado de un forzamiento espacial **no es uniforme** a lo largo de la
cadena. Puntos de entrada a verificar en M1:

| Punto de entrada | Variable(s) meteorológica(s) | Efecto potencial de un forzamiento espacial | Estado |
|---|---|---|---|
| Radiación de onda corta entrante (Rs↓) | Rs o transmisividad atmosférica | Directo sobre Rn en todo el dominio | `TODO` |
| Radiación de onda larga entrante (RL↓) | Temperatura del aire, emisividad atmosférica | Directo sobre Rn | `TODO` |
| Velocidad del viento a altura de mezcla | u (estación) extrapolada | Afecta u*, rah y por tanto H en todo el dominio | `TODO` |
| Condición del píxel frío | ETr instantánea en el ancla frío | Fija la calibración de dT (afecta toda la escena) | `TODO` |
| Extrapolación diaria | ETr de 24 h | Directo sobre ETa = ETrF × ETr24 en cada píxel | `TODO` |

Consecuencia metodológica: deberá evaluarse por separado el efecto del
forzamiento espacial (i) en la calibración (anclas) y (ii) en la
extrapolación temporal (ETr24), porque pueden compensarse o no.

---

## 2. Aclaraciones conceptuales registradas

### 2.1 Calibración interna (píxel frío/caliente) ≠ cierre del balance de energía

- En METRIC, LE se obtiene como **residuo**: LE = Rn − G − H. Por
  construcción, el balance "cierra" en cada píxel; esto no es una propiedad
  que el método de anclas "logre", sino una consecuencia de calcular LE por
  diferencia.
- Los píxeles ancla (frío/caliente) **calibran la relación dT–Ts** para que
  H sea coherente con condiciones de borde supuestas (p. ej., LE ≈ 0 en el
  ancla caliente, LE ≈ k·ETr en el ancla frío, con k a verificar). Esta
  calibración compensa sesgos sistemáticos de Rn, G, rah y de la temperatura
  superficial.
- El "problema de cierre" en sentido micrometeorológico (Rn − G ≠ H + LE en
  torres eddy covariance) es un asunto de **validación**: cómo se corrigen o
  no las observaciones de referencia antes de comparar (ver
  `VALIDATION_PLAN.md`).
- Por lo tanto, la documentación pública no debe afirmar que el método de
  anclas "logra una buena clausura" sin precisar a cuál de estos sentidos se
  refiere.

### 2.2 Radiación directa y difusa

- La partición de la radiación de onda corta en componentes **directa
  (beam) y difusa** pertenece al módulo de radiación (`metric-radiation.R`),
  no a la selección de anclas. Los píxeles ancla no permiten obtener esa
  partición.
- Es relevante en terreno complejo (Andes, Cordillera de la Costa): METRIC
  corrige Rs↓ por pendiente y orientación, y esa corrección requiere tratar
  la componente directa (dependiente del ángulo de incidencia) y la difusa
  (dependiente del factor de visión del cielo) por separado.
- Fuente candidata: Allen, Trezza y Tasumi (2006) para funciones de
  radiación en pendientes; ASCE-EWRI (2005) para transmisividad y partición.
  `TODO: verificar ecuaciones y su uso en METRIC (Allen et al., 2007).`
- Implicancia de datos: requiere un MDE (pendiente, orientación) remuestreado
  de forma coherente a la grilla de trabajo.

### 2.3 Escala espacial: METRIC fue diseñado para Landsat

- METRIC fue formulado y aplicado principalmente con Landsat (≈30 m óptico,
  ≈60–120 m térmico remuestreado). MODIS LST tiene ≈1 km.
- A 1 km es difícil encontrar píxeles ancla **homogéneos** (cultivo pleno
  bien regado, suelo desnudo seco). Los píxeles mixtos sesgan la calibración.
- Esto debe tratarse como una **limitación explícita** y un objeto de
  evaluación, no como un detalle de implementación. Alternativas a considerar
  en M1: criterios de homogeneidad, desagregación térmica, o sensores de mayor
  resolución mediante la arquitectura independiente del sensor.

### 2.4 Continuidad de MODIS

- Las plataformas Terra y Aqua operan más allá de su vida de diseño y
  presentan deriva orbital (cambio progresivo de la hora de paso).
  `TODO: verificar estado actual de las misiones y fechas oficiales de fin de operación.`
- La hora de paso afecta directamente la ETr instantánea, la condición de
  las anclas y la comparación entre fechas. Debe leerse por píxel desde el
  producto (view time), no suponerse constante.
- Esto refuerza el principio arquitectónico de que METRIC no dependa de MODIS
  (posibles continuadores: VIIRS; alternativas: Landsat, Sentinel-3).

---

## 3. Tabla de variables

Columnas: Variable · Símbolo · Unidad · Fuente · Ecuación · Supuestos ·
Dominio · Referencia · Función EarthFlux · Test.

| Variable | Símbolo | Unidad | Fuente | Ecuación | Supuestos | Dominio | Referencia | Función EarthFlux | Test |
|---|---|---|---|---|---|---|---|---|---|
| Temperatura superficial terrestre | Ts (LST) | K | MODIS LST (p. ej., MOD11A1/MYD11A1; alternativa MOD21) | Producto (escala + QA); `TODO` | Emisividad del producto coherente con la usada en Rn; hora de paso por píxel | > 0 K; rango plausible `TODO` | Guía de usuario del producto `TODO` | `prep-modis.R` (interna, por definir) | `test-modis.R` |
| Índice de vegetación de diferencia normalizada | NDVI | – | MODIS reflectancia superficial (p. ej., MOD09) o índices (MOD13) | NDVI = (ρNIR − ρRed)/(ρNIR + ρRed) — forma estándar | Reflectancia de superficie corregida atmosféricamente | [−1, 1] | Rouse et al. (1974) `TODO: verify full citation` | `prep-modis.R` | `test-modis.R` |
| Índice de área foliar | LAI | m² m⁻² | MODIS LAI (p. ej., MCD15A2H) **o** empírico desde SAVI | `CANDIDATA` (empírica METRIC desde SAVI, calibrada en Idaho) | Transferibilidad a Chile **no demostrada**; preferir producto o calibración local | ≥ 0; tope según método `TODO` | Allen et al. (2007) `TODO`; Myneni et al. (2002) `TODO` | `prep-modis.R` | `test-modis.R` |
| Albedo superficial de banda ancha | α | – | MODIS albedo (p. ej., MCD43A3, white/black-sky) o conversión banda angosta→ancha | `TODO` (blue-sky vs. white/black-sky; coeficientes de Liang) | Definición de albedo consistente con Rs↓ instantánea | [0, 1] | Schaaf et al. (2002) `TODO`; Liang (2001) `TODO` | `prep-modis.R` | `test-modis.R` |
| Emisividad superficial de banda ancha | ε₀ | – | MODIS (bandas 31/32 del producto LST) o empírica desde LAI/NDVI | `CANDIDATA` (empírica METRIC desde LAI) | Debe ser coherente con la emisividad usada para obtener Ts | (0, 1] | Allen et al. (2007) `TODO`; Tasumi (2003) `TODO` | `prep-modis.R` | `test-modis.R` |
| Radiación neta | Rn | W m⁻² | Calculada | `CANDIDATA (corroborada)`: Rn = (1 − α)·Rs↓ + RL↓ − RL↑ − (1 − ε₀)·RL↓ | Instantánea a la hora de paso; RL↑ desde Ts y ε₀ (Stefan-Boltzmann) | Real; valores negativos posibles (noche, nieve) → flag, no corrección | Allen et al. (2007) `TODO: verify equation number` | [`ef_net_radiation()`](specs/ef_net_radiation.md) | `test-radiation.R` |
| Flujo de calor del suelo | G | W m⁻² | Calculada | `CANDIDATA`: G/Rn = (Ts − 273.15)(0.0038 + 0.0074α)(1 − 0.98·NDVI⁴) | Empírica; mediodía; no válida para agua/nieve sin reglas específicas | Rango de G/Rn plausible `TODO` | Bastiaanssen (2000) `TODO`; alternativas METRIC (Tasumi, 2003) `TODO` | `ef_soil_heat_flux()` (futura) | `test-soil-heat.R` |
| Resistencia aerodinámica al transporte de calor | rah | s m⁻¹ | Calculada | `CANDIDATA`: rah = ln(z₂/z₁)/(u*·k), con z₁, z₂ alturas sobre el plano de desplazamiento | Corrección de estabilidad Monin-Obukhov iterativa; k = 0.41; z₁, z₂ `TODO` | > 0 | Allen et al. (2007) `TODO`; Paulson (1970) `TODO`; Webb (1970) `TODO` | `metric-aerodynamics.R` (por definir) | `test-aerodynamics.R` |
| Diferencia de temperatura cerca de la superficie | dT | K | Calibrada con anclas | `CANDIDATA`: dT = a + b·Ts,datum | Linealidad dT–Ts; Ts ajustada por elevación (datum) con gradiente `TODO` | Definido entre anclas; extrapolación → flag `TODO` | Allen et al. (2007) `TODO` | `metric-dt.R` (por definir) | `test-sensible-heat.R` |
| Flujo de calor sensible | H | W m⁻² | Calculada | `CANDIDATA`: H = ρ_air·c_p·dT / rah | ρ_air según presión y temperatura `TODO`; c_p ≈ 1004 J kg⁻¹ K⁻¹ `TODO` | Real; valores negativos posibles (advección) | Allen et al. (2007) `TODO` | `metric-sensible-heat.R` (por definir) | `test-sensible-heat.R` |
| Flujo de calor latente | LE | W m⁻² | Residuo | LE = Rn − G − H | Balance de energía 1D; sin almacenamiento en dosel ni advección explícita | Real; LE < 0 → flag | Allen et al. (2007) | `metric-latent-heat.R` (por definir) | `test-pipeline.R` |
| ET instantánea | ET_inst | mm h⁻¹ | Calculada | `CANDIDATA`: ET_inst = 3600·LE / (λ·ρ_w) | λ dependiente de Ts `TODO`; ρ_w ≈ 1000 kg m⁻³ | Real; < 0 → `EF_ET_NEGATIVE` | Allen et al. (2007) `TODO` | `metric-et.R` (por definir) | `test-et.R` |
| ET de referencia | ETr (inst, 24 h) | mm h⁻¹; mm d⁻¹ | Meteorología (estación o superficie GWR) | `TODO`: ecuación estandarizada ASCE-EWRI (alfalfa, `ETr`) vs. pasto (`ETo`) | METRIC usa típicamente referencia alfalfa; definición de cultivo de referencia **explícita** | ≥ 0 | ASCE-EWRI (2005) `TODO`; Allen et al. (1998) FAO-56 `TODO` | `metric-et.R` / `prep-weather.R` (por definir) | `test-et.R` |
| Fracción de ET de referencia | ETrF | – | Calculada | ETrF = ET_inst / ETr_inst | ETrF constante durante el día `TODO: documentar limitaciones` | Rango plausible `TODO`; fuera de rango → flag (no truncar) | Allen et al. (2007) `TODO` | `metric-et.R` (por definir) | `test-et.R` |
| Evapotranspiración real (diaria) | ETa | mm d⁻¹ | Calculada | ETa = ETrF · ETr24 | Conservación de ETrF; ETr24 espacialmente explícita (H1) | Real; < 0 → `EF_ET_NEGATIVE` | Allen et al. (2007) `TODO` | `metric-et.R` → `earthflux()` | `test-et.R`, `test-pipeline.R` |

---

## 4. Productos MODIS candidatos

`TODO (M1)`: confirmar colección vigente (6.1 / 7), resolución, frecuencia,
factores de escala, valores de relleno y bits QA desde las guías de usuario
oficiales. **No ingresar valores de memoria.**

| Variable | Producto candidato | Alternativa | Comentario |
|---|---|---|---|
| LST y emisividad | MOD11A1 / MYD11A1 | MOD21A1 | Hora de paso por píxel (view time); QA |
| Reflectancia superficial | MOD09GA / MOD09GQ | – | Base para NDVI/SAVI propios |
| NDVI / EVI | MOD13Q1 / MOD13A2 | Calculado desde MOD09 | Compuesto de 16 días: desfase temporal con LST diaria |
| LAI / FPAR | MCD15A2H | Empírico desde SAVI | Compuesto de 8 días |
| Albedo | MCD43A3 | Conversión banda angosta→ancha | white/black-sky; definir combinación |
| Cobertura de suelo | MCD12Q1 | Cobertura local (p. ej., catastros nacionales) | Para anclas y rugosidad |

---

## 5. Variables meteorológicas

`TODO (M1)`: conjunto mínimo, alturas de medición, resolución temporal,
ventana temporal alrededor de la hora de paso.

| Variable | Símbolo | Unidad | Uso en la cadena | Candidata a GWR | Covariables candidatas |
|---|---|---|---|---|---|
| Temperatura del aire | Ta | °C | RL↓, ETr | Sí | Elevación, distancia a la costa, LST |
| Humedad relativa / presión de vapor | HR / ea | % / kPa | ETr | Sí (preferir ea) | Elevación, distancia a la costa |
| Velocidad del viento | u | m s⁻¹ | u*, rah, ETr | Con cautela (alta variabilidad local) | Elevación, rugosidad, exposición |
| Radiación solar global | Rs | W m⁻² | Rs↓, ETr | Sí | Elevación, nubosidad satelital |
| Presión atmosférica | P | kPa | ρ_air, constante psicrométrica | Derivable de elevación | Elevación |
| ETr instantánea / diaria | ETr | mm h⁻¹ / mm d⁻¹ | Ancla fría, ETa | Ver decisión 5.1 | – |

**Decisión metodológica 5.1 (abierta):** ¿interpolar ETr directamente
("calcular y luego interpolar") o interpolar sus variables de entrada y
calcular ETr por píxel ("interpolar y luego calcular")? Ambas opciones son
defendibles y producen errores distintos; la elección debe justificarse y,
idealmente, evaluarse.

---

## 6. GWR

`TODO (M1)`: especificación completa antes de implementar.

- Variable respuesta y covariables por variable meteorológica (tabla 5).
- Kernel (gaussiano, bicuadrado, ...) y tipo de ancho de banda (fijo/adaptativo).
- Criterio de selección: AICc (Hurvich et al., 1998) y/o validación cruzada.
- Tamaño mínimo de muestra (número de estaciones) y comportamiento con pocas
  estaciones: **riesgo alto en redes chilenas poco densas**; documentar umbral.
- Diagnósticos: residuos, R² local, número efectivo de parámetros,
  autocorrelación espacial de residuos.
- Detección de extrapolación (fuera del soporte geográfico o del rango de
  covariables).
- Backend: decisión abierta (ver `ARCHITECTURE.md`, sección 6).

---

## 7. Píxeles ancla

`TODO (M1)`: reglas de selección referenciadas.

- Condiciones de borde (ancla caliente y fría) y coeficientes asociados.
- Criterios automáticos (percentiles de Ts, NDVI, albedo; homogeneidad;
  cobertura de suelo) — Allen et al. (2013), Morton et al. (2013) `TODO`.
- Selección manual/explícita por el usuario.
- Registro auditable: ubicación, Ts, NDVI, α, cobertura, criterios,
  percentiles, flags QA.
- Aplicabilidad a 1 km (sección 2.3).

---

## 8. Criterios QA

`TODO (M1)`.

- QA de productos MODIS (bits; nubes; ángulo de visión).
- QC de estaciones (rangos, persistencia, saltos, datos faltantes).
- Flags del resultado (`R/diagnostics.R`): solo se registran códigos con
  condición inequívoca. Umbrales que requieran justificación se agregan
  cuando estén documentados aquí.

---

## 9. Trabajo relacionado

- Paquete R **water** (Olmedo, Ortega-Farías, Fonseca-Luengo, de la
  Fuente-Sáiz y Fuentes-Peñailillo): herramientas para estimar ET real con
  modelos de balance de energía superficial (incluye METRIC) en R, con datos
  Landsat. Es una inspiración conceptual reconocida de EarthFlux. Versión
  revisada: v1.0 (2026-10-19), basada en `terra` y `sf`, licencia GPL (≥ 2);
  no figura en el índice activo de CRAN al 2026-11-04. Cita en
  `REFERENCES.md`; lecciones de diseño en `ARCHITECTURE.md` §6.4.
- **Licencias:** EarthFlux usa MIT. No se debe copiar código de otros
  paquetes sin verificar compatibilidad de licencia (p. ej., código GPL no
  puede reutilizarse bajo MIT). Reimplementar desde las fuentes primarias.
- Diferencias de alcance que EarthFlux pretende explorar (sin afirmar
  superioridad): sensor MODIS desacoplado del núcleo físico; forzamiento
  meteorológico espacial (GWR) como módulo independiente; diagnósticos como
  parte del resultado.
