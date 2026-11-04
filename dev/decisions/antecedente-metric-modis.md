# Antecedente: prototipo previo MODIS + METRIC + GWR

Estado: **registro de antecedentes** (2026-11-04) · Autor del prototipo:
Guillermo Servando Fuentes-Jaque.

Este documento resume un prototipo exploratorio anterior del autor (scripts
en R, no versionados en este repositorio) que intentó la misma cadena
conceptual de EarthFlux. Se conserva como memoria del proyecto: qué se
probó, qué decisiones se tomaron entonces y qué lecciones condicionan el
diseño actual. **No se reutiliza su código**: gran parte deriva de funciones
del paquete `water` (GPL ≥ 2), incompatible con la licencia MIT de
EarthFlux; las ideas se reimplementan desde las fuentes primarias.

## 1. Qué hacía el prototipo

| Etapa | Implementación en el prototipo | Equivalente en EarthFlux |
|---|---|---|
| Albedo MODIS | Combinación lineal de reflectancias de bandas 1-7 (coeficientes tipo Liang, 2001) | `modis-products.md` §8 (MP-03) |
| Emisividad y RL↑ | `RL↑ = ε·σ·Ts⁴` con **emisividad MODIS como entrada** (no derivada de LAI) | `ef_longwave_out()`; principio de independencia del sensor |
| Rs↓ | Transmisividad con partición directa/difusa (forma tipo ASCE) y corrección por pendiente/orientación con MDE | `radiation-components.md` §6.3-6.4 |
| Radiación difusa | Fracción difusa empírica por tramos en función de la transmisividad (polinomio de 4º grado entre 0,17 y 0,75) | `radiation-components.md` (modelos de descomposición, `TODO`) |
| RL↓ | `εa·σ·Ta⁴` con **Ta del aire regionalizada por GWR** | Decisión RC-12 |
| Rn | Forma METRIC con término de onda larga reflejada | `ef_net_radiation()` |
| G | Métodos Bastiaanssen y Tasumi | `soil-heat-flux.md` |
| Anclas | Selección **manual** de píxeles frío/caliente (la selección automática quedó comentada) | `anchor-pixels.md` (`ef_anchors()` explícito) |
| H | Calibración dT con anclas e iteración de estabilidad; en una variante se reemplazó H por una regresión empírica sobre LST, G y Rn | `sensible-heat.md` |
| GWR | `spgwr`: kernel tricúbico **declarado pero no transmitido** (en la práctica se usó el kernel gaussiano por defecto); se pasaban a la vez un bandwidth fijo y una proporción adaptativa, y `spgwr` ignoraba el fijo (verificado en `gwr-forcing.md` §1.4); predicción en la grilla ráster; cluster paralelo | `gwr-forcing.md`, `decisions/gwr-backend.md` |
| Modelos GWR | `ea ~ EVI + elevación`; `Ta ~ LST` | `gwr-forcing.md` |
| QC de estaciones | Eliminación de atípicos por regla IQR (Q1/Q3 ± 1,2·IQR) | `weather-forcing.md` §3 (flags, no eliminación) |
| Meteorología | Estaciones y, en algunas corridas, reanálisis NCEP | Alternativas de forzamiento (C2) |

## 2. Lecciones que condicionan el diseño actual

1. **La intención de investigación ya existía y es coherente con H1:** el
   prototipo regionalizaba presión de vapor y temperatura del aire con GWR y
   las usaba en Rs↓ y RL↓. EarthFlux formaliza esto como hipótesis evaluable
   (C1 vs C2 vs C3), en lugar de asumir su beneficio.
2. **Circularidad Ta-LST (riesgo científico).** Usar LST como covariable de
   Ta y luego usar esa Ta en el balance de energía acopla el forzamiento a
   la misma temperatura superficial que gobierna la calibración dT-Ts. Debe
   tratarse como decisión explícita (`gwr-forcing.md`), con análisis de
   sensibilidad y alternativas basadas en covariables independientes
   (elevación, distancia a la costa).
3. **Dificultad de la calibración a escala MODIS.** El prototipo necesitó
   anclas manuales, un coeficiente del píxel frío muy distinto del valor
   típico de la literatura (0,5 frente a ~1,05) y, en una variante, una
   regresión empírica para H. Esto es evidencia empírica directa del
   problema identificado en `SCIENTIFIC_SPEC.md` §2.3 y en
   `anchor-pixels.md` §4: a 1 km la calibración interna es frágil y debe
   ser auditable, explícita y evaluada por sensibilidad.
4. **No corregir en silencio.** El prototipo truncaba el albedo a [0, 1] y
   eliminaba estaciones atípicas; EarthFlux registra flags y conserva los
   valores (principio 6 de `ARCHITECTURE.md`).
5. **Coeficientes a verificar.** Los coeficientes de albedo de banda ancha
   del prototipo difieren en la banda 7 de la forma habitualmente citada
   para MODIS (Liang, 2001): deben verificarse contra la fuente primaria
   antes de implementarse (`modis-products.md`, MP-03).
6. **Parámetros que no llegan a la función.** En el prototipo, el kernel
   declarado y el bandwidth fijo no eran los que realmente se usaban. En
   EarthFlux, el kernel, el tipo de bandwidth y su valor quedan registrados
   en el objeto de resultado y en la procedencia, y los tests verifican que
   el kernel solicitado sea el aplicado.
7. **Paralelismo y portabilidad.** El prototipo creaba clusters con
   `detectCores() - n` y usaba rutas absolutas; EarthFlux deja el número de
   núcleos al usuario (máximo 2 en checks de CRAN) y no usa rutas absolutas
   (`parallel-processing.md`, `DEVELOPMENT.md` §5).
8. **Radiación difusa.** El prototipo ya incluía una partición de la
   radiación de onda corta en componentes directa y difusa, coherente con la
   aclaración de `SCIENTIFIC_SPEC.md` §2.2: esa partición pertenece al
   módulo de radiación, no a la selección de anclas. La fuente del modelo de
   fracción difusa usado debe identificarse (`TODO`).

## 3. Pendientes derivados

- Identificar la fuente del modelo de fracción difusa por tramos (`TODO`).
- Verificar los coeficientes de albedo de banda ancha (Liang, 2001).
- Documentar el coeficiente del píxel frío como parámetro explícito con
  análisis de sensibilidad (`anchor-pixels.md`, D-AP-04).
- Registrar el reanálisis como alternativa de forzamiento en el diseño
  experimental (`VALIDATION_PLAN.md` §2.1).
