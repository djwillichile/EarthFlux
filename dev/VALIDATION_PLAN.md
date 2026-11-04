# EarthFlux — Plan de verificación y validación

Estado: **borrador M0**

Este plan separa dos actividades distintas:

| | Software verification | Scientific validation |
|---|---|---|
| Pregunta | ¿El código implementa correctamente lo especificado? | ¿Lo especificado representa adecuadamente la realidad? |
| Referencia | Ecuaciones de `SCIENTIFIC_SPEC.md`, casos calculados a mano o publicados | Observaciones independientes |
| Dónde vive | `tests/testthat/` (corre en `R CMD check`) | Repositorio/proyecto de experimentos (fuera del tarball) |
| Hito | M2–M5 | M6 |

---

## 1. Software verification

### 1.1 Niveles de prueba

| Nivel | Qué se verifica | Ejemplos |
|---|---|---|
| Ecuaciones individuales | Resultado numérico vs. caso de referencia | Rn con valores de un ejemplo publicado |
| Dimensiones | Longitudes/geometrías coherentes | Vectores de largo distinto → error con clase |
| Unidades | Conversiones y salidas en la unidad documentada | °C ↔ K; W m⁻² → mm h⁻¹ |
| Valores límite | Comportamiento en bordes del dominio | α = 0, α = 1, NDVI = 1 |
| NA | Propagación y flag `EF_INPUT_NA` | NA en una entrada → NA en salida |
| Errores de entrada | Tipos, rangos imposibles | Albedo = 1.3 → error |
| Balance energético | Coherencia de componentes | LE = Rn − G − H |
| Anclas | Selección en escenas sintéticas con solución conocida | Escena 5×5 con píxeles frío/caliente conocidos |
| GWR | Casos con solución conocida | Bandwidth muy grande ≈ OLS global |
| Pipeline completo | Equivalencia API alta = cadena de bajo nivel | `earthflux()` ≡ encadenar `ef_*()` |

### 1.2 Tolerancias numéricas

- Comparaciones de punto flotante con `expect_equal(..., tolerance = )`,
  documentando en el test **por qué** se elige esa tolerancia.
- **LE ≈ Rn − G − H**: si LE se calcula como residuo, esta prueba solo
  verifica la implementación (es casi tautológica). Para que tenga valor,
  se verificará además la consistencia del ciclo completo: LE → ET_inst →
  LE (conversión inversa) y la reproducción de las condiciones de borde en
  los píxeles ancla (p. ej., H en el ancla caliente coherente con su LE
  objetivo).
- Tolerancia base propuesta: del orden de `sqrt(.Machine$double.eps)` en
  escala relativa para identidades algebraicas; tolerancias mayores solo
  con justificación (iteraciones, redondeo de constantes publicadas).

### 1.3 Verificación cruzada con implementaciones independientes

- Comparar componentes (Rn, G, H, ETrF) con el paquete `water` sobre un mismo
  caso de entrada, mediante un script de verificación **fuera del tarball**
  (patrón `inst/verification/` de `thermify`) que use `water` solo si está
  instalado. `water` es GPL: no se copia ni se empaqueta su código.
- Las diferencias se documentan y explican (constantes, formulaciones
  alternativas, orden de operaciones); no se fuerza la coincidencia.

### 1.4 Restricciones CRAN

Sin internet, sin credenciales, sin descargas, tiempos cortos, escritura solo
en `tempdir()`, datos de ejemplo pequeños.

---

## 2. Scientific validation

### 2.1 Diseño comparativo (marco futuro)

Configuraciones mínimas, manteniendo constante todo lo demás (producto
satelital, fechas, anclas o reglas de anclas, parámetros):

```text
C1: METRIC + estación representativa
C2: METRIC + alternativa espacial de referencia
C3: METRIC + GWR
```

**No se afirma a priori cuál será superior.**

Alternativas espaciales de referencia candidatas para C2 (elegir y
justificar en M1): IDW; regresión lineal global con elevación (gradiente
térmico); kriging con deriva externa / regression-kriging; productos
grillados (reanálisis o productos nacionales). `TODO: evaluar disponibilidad
y licencias para Chile`.

Evaluación diferenciada (ver `SCIENTIFIC_SPEC.md`, sección 1.2):

1. Calidad del forzamiento meteorológico en sí (validación cruzada en
   estaciones).
2. Efecto en la calibración (anclas, ETr instantánea).
3. Efecto en ETa final.

### 2.2 Fuentes de validación candidatas

`TODO (M1)`: identificar sitios y acceso a datos.

- Torres eddy covariance (ET a escala de footprint): documentar el
  tratamiento del no cierre del balance (sin corregir, Bowen ratio,
  residuo) porque afecta directamente la comparación.
- Lisímetros de pesada.
- Balance hídrico de cuencas (escala mensual/anual; menor resolución).
- Productos de ET de terceros: solo **intercomparación**, no validación.

Problema de escala: footprint de torre (cientos de metros) vs. píxel MODIS
(≈1 km). Requiere análisis de representatividad/footprint.

### 2.3 Métricas candidatas

Las métricas definitivas dependerán del diseño experimental y de las fuentes
de validación.

| Métrica | Uso |
|---|---|
| RMSE | Error total en unidades de ET |
| MAE | Error robusto a valores extremos |
| Bias (MBE) | Sesgo sistemático |
| R² | Asociación lineal (no mide exactitud por sí solo) |
| KGE | Descomposición en correlación, sesgo y variabilidad |
| Índice de Willmott (d) | Concordancia |

Requisitos adicionales:

- Intervalos de incertidumbre (p. ej., bootstrap por sitio/fecha).
- Comparación pareada entre configuraciones C1–C3 sobre los mismos pares.
- Validación cruzada espacial para GWR: LOOCV puede ser optimista con
  autocorrelación espacial; considerar validación por bloques espaciales.
- Registro completo para reproducibilidad: versiones, productos, escenas,
  estaciones, parámetros, semillas, anclas y resultados intermedios.
