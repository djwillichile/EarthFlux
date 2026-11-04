# EarthFlux — Especificación: flujo de calor del suelo (G)

Estado: **borrador M1** · Componente: `metric` · Archivo de destino:
`R/metric-soil-heat.R` · Tests: `tests/testthat/test-soil-heat.R`

> Este documento detalla la fila **G** de la tabla de variables de
> `SCIENTIFIC_SPEC.md` (§3). `SCIENTIFIC_SPEC.md` sigue siendo la fuente de
> verdad científica: cuando una formulación de este documento pase a
> `VERIFICADA`, su estado, referencia y caso numérico deben trasladarse allí.
> Mientras tanto **ninguna** ecuación de este documento puede implementarse
> (Definition of Done, `DEVELOPMENT.md` §3).

Convención de estados: la misma de `SCIENTIFIC_SPEC.md` (`TODO`,
`CANDIDATA`, `VERIFICADA`).

---

## 0. Resumen

| Formulación | Estado | Entradas | Fuente primaria citada (no consultada) | Dónde se observó |
|---|---|---|---|---|
| Bastiaanssen (SEBAL): G/Rn = f(Ts, α, NDVI) | `CANDIDATA` | `rn`, `lst`, `albedo`, `ndvi` | Bastiaanssen (2000) | `SCIENTIFIC_SPEC.md` §3; `water` v1.0, `soilHeatFlux(method = "Bastiaanssen")` |
| Tasumi / METRIC: G/Rn = f(LAI); rama de suelo desnudo con Ts y Rn | `CANDIDATA` | `rn`, `lai`, `lst` | Tasumi (2003); Allen et al. (2007) | `water` v1.0, `soilHeatFlux(method = "Tasumi")` |
| Cuerpos de agua y nieve: G/Rn constante | `TODO` | `rn` + criterio de clasificación | Allen et al. (2007), según una fuente terciaria | Notas de revisión del repositorio `water` (no implementado en `water`) |
| Superficies impermeables | `TODO` | – | Ninguna identificada | – |

Recomendación de API (sección 5): **una función de bajo nivel por método**
(`ef_soil_heat_flux_bastiaanssen()`, `ef_soil_heat_flux_tasumi()`) más un
**despachador delgado** `ef_soil_heat_flux(..., method)` que valida, llama a
la función del método, calcula diagnósticos y registra el método en la
procedencia.

---

## 1. Alcance y definiciones

- **G**: flujo de calor del suelo **instantáneo a la hora de paso** del
  satélite, en W m⁻². No es un valor diario.
- **Convención de signo** (`CANDIDATA`, coherente con LE = Rn − G − H de
  `SCIENTIFIC_SPEC.md` §2.1): G > 0 cuando el calor fluye de la superficie
  hacia el suelo. `TODO: confirmar que la fuente primaria usa la misma
  convención.`
- **Rn**: radiación neta instantánea en W m⁻² (salida de `ef_net_radiation()`,
  `SCIENTIFIC_SPEC.md` §3), positiva hacia la superficie.
- Todas las formulaciones candidatas son **empíricas**: estiman la razón
  G/Rn (o G directamente) a partir de variables de superficie. Ninguna
  resuelve la conducción de calor en el suelo.
- Fuera de alcance: G nocturno, G diario, G de la superficie de referencia
  usada en ETr (ver §3.3).

---

## 2. Fuentes consultadas y nivel de evidencia

| Fuente | Tipo | Qué aporta | Limitación |
|---|---|---|---|
| Bastiaanssen (2000), Tasumi (2003), Allen et al. (2007) | Primaria | — | **No consultadas** en esta redacción (no disponibles en el entorno de trabajo). |
| `water` v1.0 (2026-10-19; commit `3c94630`, GPL ≥ 2), `R/water_netRadiation.G.R`, función `soilHeatFlux()` y su roxygen; `R/water_internals.R` (`waterChoices$G.method`); `R/water_METRIC.R` (`METRIC.G()`, `METRIC.EB()`) | Secundaria (implementación) | Qué ecuaciones, coeficientes, umbrales y referencias usa una implementación existente | Una implementación no es una fuente científica. **No se copia código** (GPL vs. MIT); las ecuaciones se reescriben aquí en notación propia. |
| `water`, `roadto1/Sam-review.md` (notas de revisión incluidas en el repositorio; autoría y método no verificables) | Terciaria | Afirma números de ecuación y página de Allen et al. (2007) para G y para agua/nieve | No verificable; solo sirve para orientar qué buscar en la fuente primaria. |
| `SCIENTIFIC_SPEC.md` §3 (fila G) | Interna | Forma `CANDIDATA` de Bastiaanssen ya registrada | Mismo estado `CANDIDATA`. |

Intento de verificación de metadatos de citas vía `api.crossref.org`:
**bloqueado** por el proxy de salida (no se reintentó). Ningún DOI de este
documento está verificado.

---

## 3. Formulaciones candidatas

Notación: `T_s` temperatura superficial en K (`lst`); `T_c = T_s − 273.15`
en °C; `α` albedo de banda ancha (–); `NDVI` (–); `LAI` (m² m⁻²);
`R_n` (W m⁻²); `G` (W m⁻²).

### 3.1 Bastiaanssen (SEBAL) — `CANDIDATA`

**Ecuación** (reescrita en notación propia):

```text
G / R_n = T_c · (0.0038 + 0.0074 · α) · (1 − 0.98 · NDVI⁴)
G       = R_n · (G / R_n)
T_c     = T_s − 273.15
```

| Elemento | Detalle |
|---|---|
| Entradas | `rn` (W m⁻²), `lst` (K, convertida a °C dentro de la función), `albedo` (–), `ndvi` (–) |
| Coeficientes | 0.0038 (°C⁻¹), 0.0074 (°C⁻¹), 0.98 (–), exponente 4; unidades de los coeficientes inferidas de la homogeneidad dimensional (T_c en °C), `TODO: verificar` |
| Origen | Atribuida a Bastiaanssen (2000), *J. Hydrol.* 229, 87–100, DOI candidato `10.1016/S0022-1694(99)00202-4` (tomado del roxygen de `water`; no verificado). Misma forma registrada en `SCIENTIFIC_SPEC.md` §3. |
| Evidencia | Observada en el paquete `water` v1.0, función `soilHeatFlux()`, `method = "Bastiaanssen"`, con `T_s − 273.15` y NDVI calculado internamente desde reflectancias R y NIR. Fuente primaria citada: Bastiaanssen (2000). **No verificada.** |
| Dominio de validez | `TODO`. Empírica; presumiblemente condiciones cercanas al mediodía y superficies terrestres con vegetación/suelo. No hay base para aplicarla a agua, nieve o superficies impermeables. |
| Limitaciones conocidas | (a) NDVI aparece con potencia par: NDVI = −0.5 da el mismo resultado que NDVI = +0.5 (caso B6), por lo que la fórmula no distingue agua (NDVI < 0) de vegetación rala; (b) para T_s < 273.15 K la razón es negativa (caso B5); (c) T_s en °C hace que la razón dependa linealmente del clima local, no solo de la cobertura; (d) para NDVI = 1, (1 − 0.98) = 0.02: la razón no se anula. |

Preguntas abiertas para la fuente primaria (ver §10): si T_s es temperatura
superficial radiométrica en °C; si α es albedo de superficie (no TOA); si
la fuente presenta una forma factorizada distinta (p. ej., con α en el
denominador) que no sea algebraicamente equivalente en α → 0; si el NDVI
debe ser de superficie o TOA; y si la ecuación aparece en Bastiaanssen
(2000) o en Bastiaanssen et al. (1998).

### 3.2 Tasumi / METRIC — `CANDIDATA`

**Ecuación** (reescrita en notación propia; dos ramas según LAI):

```text
Si LAI ≥ 0.5:   G / R_n = 0.05 + 0.18 · exp(−0.521 · LAI)
                G       = R_n · (G / R_n)

Si LAI < 0.5:   G       = 1.80 · T_c + 0.084 · R_n
                (equivalente: G / R_n = 1.80 · T_c / R_n + 0.084)
```

| Elemento | Detalle |
|---|---|
| Entradas | `rn` (W m⁻²), `lai` (m² m⁻²); `lst` (K) solo en la rama LAI < 0.5 |
| Coeficientes | Rama vegetada: 0.05 (–), 0.18 (–), 0.521 (m² m⁻²)⁻¹. Rama de suelo desnudo: 1.80 (W m⁻² °C⁻¹, inferido por homogeneidad dimensional), 0.084 (–). Umbral: LAI = 0.5. `TODO: verificar todos` |
| Origen | `water` atribuye el método "Tasumi" a Tasumi (2003, tesis doctoral, University of Idaho) y cita también Allen et al. (2007, METRIC — Model). Las notas terciarias del repositorio `water` indican que corresponde a las Eq. 26–27 de Allen et al. (2007) y llaman "Eq. 27b" a la rama de suelo desnudo. **Números de ecuación no verificados.** |
| Evidencia | Observada en el paquete `water` v1.0, función `soilHeatFlux()`, `method = "Tasumi"` (método por defecto de `water`): calcula primero la rama vegetada en todos los píxeles y la reemplaza donde `LAI < 0.5` por la rama de suelo desnudo, escrita como `(1.8·(T_s − 273.16)/R_n + 0.084)·R_n`. Usa `e = 2.71828` en lugar de `exp()`. Fuentes primarias citadas: Tasumi (2003); Allen et al. (2007). **No verificada.** |
| Dominio de validez | `TODO`. Desarrollada en el contexto METRIC-Landsat (Idaho, según el origen citado; `TODO: verificar` cultivos, suelos, hora, LAI medido o derivado de SAVI). |
| Limitaciones conocidas | (a) **Discontinuidad en LAI = 0.5**: la rama vegetada da G/R_n ≈ 0.1887 independiente de T_s y R_n, mientras la rama de suelo desnudo depende de ambos (caso T6: salto de 114.6 a 75.5 W m⁻²); (b) en la rama de suelo desnudo G no es proporcional a R_n: con R_n pequeño la razón G/R_n puede superar 1 (caso T7: 2.109) y con R_n ≤ 0 deja de tener sentido como razón; (c) la rama vegetada tiende a 0.05 cuando LAI → ∞ y vale 0.23 en LAI = 0, pero esa rama no se usa bajo 0.5; (d) el significado de LAI depende del método con que se derivó la relación (ver §7.3). |

Detalles de implementación observados en `water` que **no** se adoptan:

| Observación en `water` | Decisión en EarthFlux | Efecto numérico |
|---|---|---|
| 273.16 en la rama de suelo desnudo; 273.15 en Bastiaanssen | Una sola constante, 273.15 K, para K → °C en todo el paquete (`TODO`: confirmar cuál usa la fuente primaria) | 1.8 × 0.01 = 0.018 W m⁻² |
| `e = 2.71828` | `exp()` | Relativo ≈ 4.5 × 10⁻⁷ en LAI = 3 (≈ 2 × 10⁻⁵ W m⁻² con R_n = 550) |
| Rama de suelo desnudo escrita como razón × R_n (división por R_n) | Calcular G directamente: `1.80·T_c + 0.084·R_n` (sin división; sin singularidad en R_n = 0) | Ninguno salvo en R_n = 0 |
| NDVI calculado dentro de la función desde bandas del sensor | `ndvi` como entrada física independiente del sensor | – |

### 3.3 Otros métodos presentes en `water`

- `soilHeatFlux()` acepta solo dos métodos: `"Tasumi"` y `"Bastiaanssen"`
  (`waterChoices$G.method` en `R/water_internals.R`). `METRIC.G()` y
  `METRIC.EB()` solo los reenvían (`G.method`).
- `asceHourly()` (`R/water_ET.R`) usa G = c · R_n para la **superficie de
  referencia** de la ETr horaria: c = 0.04 (día) / 0.2 (noche) para
  referencia alfalfa (`ETr`) y c = 0.1 / 0.5 para pasto (`ETo`), con "día"
  definido como R_n > 0; el comentario de código lo atribuye a ASCE-EWRI
  (2005), Tabla 1 (`TODO: verificar`). **No** es un método de G del píxel:
  pertenece al módulo de ETr (`metric-et.R` / `prep-weather.R`) y no debe
  ofrecerse en `ef_soil_heat_flux()`.
- En `METRIC.EB()` hay una línea comentada que truncaría G negativo a 0; no
  está activa. EarthFlux no trunca G (principio 6 de `ARCHITECTURE.md`).
- `LAI()` de `water` trunca LAI < 0 a 0 y fija LAI = 6 cuando SAVI > 0.687;
  eso pertenece al método de LAI, no a G (ver §6.2: EarthFlux no corrige
  entradas).

### 3.4 Superficies especiales — `TODO`

| Superficie | Regla candidata | Fuente y estado | Propuesta mientras sea `TODO` |
|---|---|---|---|
| Cuerpos de agua | G/R_n = 0.5 para píxeles con NDVI ≤ 0 clasificados como agua | Afirmado por las notas terciarias del repositorio `water`, que lo atribuyen a Allen et al. (2007, p. 385). **No implementado en `water`** (allí el agua recibe la fórmula de Tasumi). No verificado. | No aplicar regla. Marcar píxeles con `ndvi ≤ 0` (flag candidato `EF_G_NDVI_NONPOSITIVE`) para que el usuario los enmascare o trate aparte. |
| Nieve / hielo | G/R_n = 0.5 para NDVI ≤ 0 con criterio adicional de albedo y T_s < 277 K | Misma fuente terciaria (p. 385). Umbral de albedo no indicado. No verificado. | Igual que agua. |
| Suelo desértico / muy seco | "Limitación de G en desierto" | Mencionada en la misma fuente terciaria (p. 385) sin detalle. | `TODO`: identificar en la fuente primaria. |
| Superficies impermeables (urbano, roca) | Ninguna | No se identificó fuente. | `TODO`. Documentar como fuera de dominio; candidato a máscara externa por cobertura de suelo (MCD12Q1 o cobertura local, `SCIENTIFIC_SPEC.md` §4). |

Decisión de diseño (independiente de la verificación): la clasificación de
superficies especiales (agua, nieve, impermeable) **no** se hace dentro de
la función de G con umbrales implícitos. Si se adopta una regla verificada,
se implementará como un método o una capa explícita (p. ej., un argumento
`surface_class` o una máscara) cuyo criterio quede registrado en la
procedencia. Ver decisión abierta D4.

### 3.5 Comparación

| Aspecto | Bastiaanssen | Tasumi / METRIC |
|---|---|---|
| Depende de T_s | Siempre | Solo LAI < 0.5 |
| Depende de α | Sí | No |
| Índice de vegetación | NDVI (potencia par) | LAI |
| G proporcional a R_n | Sí | Solo LAI ≥ 0.5 |
| Continuidad | Continua | Discontinua en LAI = 0.5 |
| Signo de G/R_n | Negativo si T_s < 273.15 K | Rama de suelo desnudo: según T_c y R_n |
| Contexto de origen | SEBAL | METRIC |

---

## 4. Entradas, unidades y conversiones

Todas las entradas son **variables físicas independientes del sensor**
(principios 1–2 de `ARCHITECTURE.md`; contrato de estado de superficie,
`ARCHITECTURE.md` §4). Ninguna función de G recibe bandas, factores de
escala, objetos MTL ni nombres de producto.

| Argumento | Unidad | Usado por | Origen típico en el pipeline |
|---|---|---|---|
| `rn` | W m⁻² | Ambos | `ef_net_radiation()` |
| `lst` | K | Bastiaanssen; Tasumi (rama LAI < 0.5) | `surface$lst` (p. ej., MOD11A1/MYD11A1 tras escala y QA) |
| `albedo` | – | Bastiaanssen | `surface$albedo` |
| `ndvi` | – | Bastiaanssen | `surface$ndvi` |
| `lai` | m² m⁻² | Tasumi | `surface$lai` |

Conversión explícita K → °C: `T_c = lst − 273.15`, realizada **dentro** de
la función con una constante interna nombrada (p. ej.,
`EF_KELVIN_OFFSET <- 273.15`, nombre a decidir) compartida por todo el
paquete. La API nunca recibe °C. Salida: `G` en W m⁻²; razón `G/R_n`
adimensional (diagnóstico).

---

## 5. Diseño de API

### 5.1 Opciones evaluadas

| Opción | Ventajas | Desventajas |
|---|---|---|
| A. Una función única con `method` y ramas internas | Un solo punto de entrada | Argumentos condicionales al método (difícil de documentar en roxygen: qué es obligatorio depende de `method`); tests mezclados; cada nuevo método modifica una función existente |
| B. Solo funciones por método | Firmas explícitas; tests y documentación por ecuación | `earthflux()` necesitaría su propia lógica de selección; riesgo de duplicar validaciones y diagnósticos |
| **C. Funciones por método + despachador delgado** | Lo mejor de A y B | Una función más que mantener |

### 5.2 Decisión propuesta: opción C

```r
# Bajo nivel: aritmética pura, vectorizada, una ecuación por función.
ef_soil_heat_flux_bastiaanssen(rn, lst, albedo, ndvi)
ef_soil_heat_flux_tasumi(rn, lst, lai)

# Despachador: valida, despacha, diagnostica y registra procedencia.
ef_soil_heat_flux(rn, lst = NULL, albedo = NULL, ndvi = NULL, lai = NULL,
                  method)
```

Justificación:

1. **Testabilidad.** Cada ecuación se verifica contra su caso numérico
   (§8) sin pasar por la lógica de despacho; el despachador se prueba por
   equivalencia (`ef_soil_heat_flux(method = "x")` ≡ llamada directa).
2. **Documentación.** Cada función de bajo nivel tiene `@param` obligatorios
   y sin condicionales, `@references` propias y su dominio en `@details`.
   El despachador documenta solo la selección y los diagnósticos.
3. **Independencia del sensor.** Las firmas solo contienen variables
   físicas (§4).
4. **Principio 4 de `ARCHITECTURE.md`.** `earthflux()` llama al
   despachador; no duplica ecuaciones ni validaciones.
5. **Extensibilidad.** Un método nuevo (p. ej., una regla verificada para
   agua/nieve, o una calibración local) es una función nueva más una
   entrada en la tabla de métodos del despachador; las funciones
   existentes no cambian.

### 5.3 Reglas de las funciones de bajo nivel

- Puramente aritméticas y vectorizadas (`ARCHITECTURE.md` §3): operan
  sobre `numeric` y, sin reimplementación, sobre `SpatRaster` (§6.2 de
  `ARCHITECTURE.md`). La rama de Tasumi debe expresarse de forma que
  funcione en ambos (p. ej., combinación por máscara; evitar `ifelse()`,
  que no opera sobre `SpatRaster`), verificando que un `NA` en una rama no
  usada no contamine el resultado de forma distinta a lo especificado en
  §6.1.
- Devuelven G con la misma forma que las entradas (vector o `SpatRaster`).
- Validan dominio y dimensiones (§6) y señalan errores con clase.
- No calculan flags ni procedencia (eso es del despachador), para mantener
  la equivalencia numérica trivial.
- ¿Exportadas? Propuesta: sí, como API avanzada documentada (decisión
  abierta D2; la API pública debe ser pequeña, `DEVELOPMENT.md` §1).

### 5.4 Reglas del despachador

- `method` **sin valor por defecto** y con coincidencia exacta (sin
  abreviaturas ni cambios de mayúsculas): valores `"bastiaanssen"` y
  `"tasumi"`. Un valor desconocido → error de clase
  `earthflux_unknown_method` (+ `earthflux_input_error`). Justificación:
  la elección de G es una decisión científica que debe quedar explícita;
  `water` documenta errores de usuario por nombres de método parecidos.
  `earthflux()` podrá fijar un valor por defecto documentado (decisión D1).
- Comprueba que estén presentes los argumentos que el método requiere
  (error `earthflux_missing_input`). Los argumentos no usados por el método
  se ignoran sin warning (para que `earthflux()` pueda pasar todo el estado
  de superficie) y la procedencia registra cuáles se usaron.
- Devuelve un objeto liviano (estructura exacta: decisión D3, coordinada con
  `earthflux_result`, `R/classes.R`), con al menos:

| Elemento | Contenido |
|---|---|
| `g` | G (W m⁻²), misma forma que las entradas |
| `g_rn_ratio` | G/R_n (–); `NA` donde R_n = 0 |
| `method` | Nombre exacto del método (`"tasumi"` / `"bastiaanssen"`) |
| `branch` | Solo Tasumi: rama aplicada por píxel (`"lai_ge_0.5"` / `"lai_lt_0.5"`) o una máscara lógica |
| `flags` | Lista de objetos `earthflux_flag` (§6.3) |
| `provenance` | Método, referencia(s) bibliográfica(s), estado de verificación de la ecuación, constantes usadas (incluida 273.15 y el umbral de LAI), entradas usadas, versión de EarthFlux |

---

## 6. NA, dominio, errores y flags

### 6.1 Comportamiento con NA

- **Propagación:** si cualquier entrada **requerida por el método** es `NA`
  en una posición, `G` es `NA` en esa posición, y el despachador registra
  `EF_INPUT_NA` (ya existente en `R/diagnostics.R`).
- Para Tasumi, `lst` se considera requerida en todo el dominio (no solo en
  la rama LAI < 0.5). Justificación: resultado predecible e independiente de
  la rama; en el pipeline T_s es imprescindible aguas abajo (H, anclas), de
  modo que no se pierde información. Diferencia documentada con `water`, que
  devuelve G en píxeles LAI ≥ 0.5 aunque T_s sea `NA`; la verificación
  cruzada (§9.6) debe enmascarar esos píxeles. Decisión abierta D5.
- `NaN` se trata como `NA`. `Inf`/`-Inf` en cualquier entrada → error
  (`earthflux_domain_error`).

### 6.2 Dominio: errores con clase para entradas imposibles

Entradas físicamente imposibles **no** se corrigen (no se truncan ni se
reemplazan): se detienen con error de clase. Todas las clases heredan de
`earthflux_domain_error` → `earthflux_input_error` → `earthflux_error`
(nombres finales a confirmar con `R/utils.R`).

| Condición | Clase propuesta | Comentario |
|---|---|---|
| `albedo < 0` o `albedo > 1` | `earthflux_domain_error` | Imposible por definición |
| `ndvi < −1` o `ndvi > 1` | `earthflux_domain_error` | Imposible por definición |
| `lai < 0` | `earthflux_domain_error` | Imposible por definición |
| `lst ≤ 0` K | `earthflux_domain_error` | Imposible; detecta además °C pasados como K solo si ≤ 0 (ver nota) |
| Entrada no numérica | `earthflux_input_error` | – |
| Longitudes incompatibles (ni iguales ni 1) o geometrías `SpatRaster` distintas | `earthflux_dimension_error` | Solo se reciclan escalares |
| `rn` cualquier real finito | — | R_n negativo es físicamente posible; no es error (ver flags) |

Notas:

- `lst` en °C pasada por error como K (p. ej., 25) **no** se detecta con
  `lst ≤ 0`. Un rango plausible de T_s (p. ej., límites inferior/superior
  en K) requiere referencia: `TODO`. Mientras no exista, no se agrega un
  warning con umbral arbitrario.
- Un único píxel inválido detiene la escena completa. La limpieza de
  valores fuera de rango es responsabilidad del módulo `surface` (QA). Si se
  requiere otro comportamiento (p. ej., `on_invalid = "na_flag"`), es la
  decisión abierta D6.

### 6.3 Diagnósticos (flags) de G

Ningún valor de G se trunca ni se reemplaza (principio 6). Flags propuestos
(se registran en `ef_flag_registry()` **solo cuando se implemente** la
función y, para los que dependen de umbrales, cuando el umbral tenga
referencia):

| Código propuesto | Condición | Severidad | ¿Condición inequívoca? |
|---|---|---|---|
| `EF_INPUT_NA` (existente) | Alguna entrada requerida es `NA` | info | Sí |
| `EF_G_RN_NONPOSITIVE` | R_n ≤ 0: la razón G/R_n es indefinida (R_n = 0) o invierte su significado | warning | Sí |
| `EF_G_RATIO_NEGATIVE` | G/R_n < 0 (G y R_n de signo opuesto; p. ej., Bastiaanssen con T_s < 273.15 K) | warning | Sí |
| `EF_G_EXCEEDS_RN` | R_n > 0 y G > R_n (energía disponible R_n − G negativa) | warning | Sí |
| `EF_G_LOW_LAI_BRANCH` | Tasumi: se aplicó la rama LAI < 0.5 | info | Sí (registro de auditoría) |
| `EF_G_NDVI_NONPOSITIVE` | `ndvi ≤ 0` (posible agua/nieve tratada con fórmula terrestre) | warning | La condición sí; su pertinencia (umbral 0) proviene de una fuente terciaria → `CANDIDATA` |
| `EF_G_RATIO_IMPLAUSIBLE` | G/R_n fuera de un rango plausible [r_min, r_max] | warning | **No**: el rango requiere referencia → **no registrar** hasta documentarlo (decisión D7) |

El rango plausible de G/R_n es una **decisión abierta que requiere
referencia** (D7). No se propone ningún valor numérico en este documento.
Los casos T7 y B5 (§8) ilustran por qué el flag debe existir: la propia
ecuación candidata produce razones > 1 o < 0 en condiciones posibles.

---

## 7. Escala espacial y desajuste temporal (limitaciones y preguntas abiertas)

### 7.1 Píxeles mixtos de 1 km

- Las formulaciones candidatas se desarrollaron y aplicaron en contexto
  Landsat (`SCIENTIFIC_SPEC.md` §2.3; `TODO`: confirmar sensor y escala de
  derivación de cada una). Su aplicación a MODIS (~1 km) no está validada.
- **Sesgo de agregación (no linealidad).** Ambas funciones son no lineales
  en sus entradas, de modo que G evaluado con entradas promediadas en el
  píxel no es el promedio de G de las componentes. Ilustración aritmética
  con la ecuación candidata de Tasumi (no es validación; supone igual R_n
  en ambas componentes, lo cual es una simplificación):
  - Píxel 50 % LAI = 0.5 y 50 % LAI = 5.5 (rama vegetada en ambas):
    promedio de razones = (0.188720 + 0.060252)/2 = 0.124486; razón con
    LAI medio (3.0) = 0.087711 → **−29.5 %**. Como exp(−0.521·LAI) es
    convexa, la razón con LAI medio nunca supera el promedio de razones
    (desigualdad de Jensen) dentro de la rama vegetada.
  - Píxel 50 % suelo desnudo (LAI = 0, T_s = 318.15 K) y 50 % dosel
    (LAI = 4), R_n = 500 W m⁻²: G de componentes = 123.0 y 36.20 W m⁻²,
    promedio 79.60 W m⁻²; con LAI medio = 2 se aplica la rama vegetada:
    G = 0.113495 × 500 = 56.75 W m⁻² (**−28.7 %**). Además el **umbral**
    LAI = 0.5 se evalúa sobre un LAI agregado que no representa a ninguna
    componente.
- El NDVI y el LAI de 1 km mezclan coberturas; la rama de suelo desnudo de
  Tasumi y el término NDVI⁴ de Bastiaanssen pierden su interpretación
  física en píxeles mixtos.
- Pregunta abierta: ¿evaluar G a escala fina (si hay NDVI/LAI de 250–500 m)
  y agregar, o aceptar la evaluación a 1 km documentando el sesgo? Ligado a
  la estrategia de desagregación térmica de `SCIENTIFIC_SPEC.md` §2.3.

### 7.2 Desajuste temporal: compuestos de 8/16 días vs. LST diaria

- NDVI (p. ej., MOD13, 16 días) y LAI (MCD15A2H, 8 días) son compuestos;
  T_s y R_n son instantáneos del día de paso (`SCIENTIFIC_SPEC.md` §4).
- Cambios rápidos de superficie (cosecha, labranza, riego, nevadas, quemas)
  dentro de la ventana del compuesto hacen que NDVI/LAI no representen el
  estado del día de paso, y la rama de Tasumi puede cambiar de forma
  espuria.
- Propuesta: el módulo `surface` debe registrar por píxel la fecha (o
  ventana) del compuesto y el desfase en días respecto al paso; el
  despachador no lo usa, pero la procedencia lo conserva. Un flag por
  desfase excesivo requiere un umbral justificado (`TODO`).
- El albedo MCD43A3 (white-/black-sky) no es instantáneo
  (`SCIENTIFIC_SPEC.md` §3, fila α); afecta a Bastiaanssen.

### 7.3 Otras dependencias de escala/definición

- **Definición de LAI.** Si la relación de Tasumi se derivó con LAI
  estimado desde SAVI con la relación empírica de METRIC (`TODO: verificar`
  en Tasumi, 2003 / Allen et al., 2007), usar LAI de MODIS (MCD15A2H)
  cambia el significado de la entrada y del umbral 0.5. Debe registrarse el
  origen del LAI en la procedencia.
- **Hora de paso.** Las relaciones G/R_n empíricas dependen de la hora del
  día (G y R_n no están en fase a lo largo del día). La deriva orbital de
  Terra/Aqua (`SCIENTIFIC_SPEC.md` §2.4) modifica la hora de paso y, por
  tanto, la aplicabilidad de coeficientes derivados para una hora dada.
  `TODO`: referencia micrometeorológica para el desfase G–R_n y hora de
  derivación de cada fórmula.
- **T_s de MODIS.** La LST de 1 km y su emisividad deben ser coherentes con
  las usadas en R_n (`SCIENTIFIC_SPEC.md` §3); Bastiaanssen y la rama de
  suelo desnudo de Tasumi son sensibles a sesgos de T_s (1.8 W m⁻² por K en
  la rama de suelo desnudo, según la ecuación candidata).

---

## 8. Casos numéricos verificables

> **Advertencia.** Todos los casos son **cálculos a mano a partir de las
> ecuaciones `CANDIDATA`** de §3. Verifican la implementación de esas
> ecuaciones, no su validez científica. Deben **recalcularse** cuando la
> fuente primaria esté verificada (coeficientes, umbral, constante 273.15).
> Redondeo: valores intermedios con ≥ 6 cifras significativas.

### 8.1 Bastiaanssen

**B1 — vegetación intermedia.** `lst = 303.15` K, `albedo = 0.20`,
`ndvi = 0.50`, `rn = 500` W m⁻².

1. T_c = 303.15 − 273.15 = 30.00 °C
2. 0.0074 × 0.20 = 0.00148; 0.0038 + 0.00148 = 0.00528
3. T_c × 0.00528 = 0.158400
4. NDVI⁴ = 0.5⁴ = 0.0625; 0.98 × 0.0625 = 0.06125; 1 − 0.06125 = 0.93875
5. G/R_n = 0.158400 × 0.93875 = **0.148698**
6. G = 0.148698 × 500 = **74.349 W m⁻²**

**B2 — suelo casi desnudo y cálido.** `lst = 313.15` K, `albedo = 0.30`,
`ndvi = 0.10`, `rn = 450` W m⁻².

1. T_c = 40.00 °C
2. 0.0074 × 0.30 = 0.00222; 0.0038 + 0.00222 = 0.00602
3. T_c × 0.00602 = 0.240800
4. NDVI⁴ = 0.0001; 0.98 × 0.0001 = 0.000098; 1 − 0.000098 = 0.999902
5. G/R_n = 0.240800 × 0.999902 = **0.240776**
6. G = 0.240776 × 450 = **108.349 W m⁻²**

**B3 — dosel denso.** `lst = 298.15` K, `albedo = 0.18`, `ndvi = 0.85`,
`rn = 600` W m⁻².

1. T_c = 25.00 °C
2. 0.0074 × 0.18 = 0.001332; 0.0038 + 0.001332 = 0.005132
3. T_c × 0.005132 = 0.128300
4. NDVI⁴ = 0.85⁴ = 0.522006; 0.98 × 0.522006 = 0.511566; 1 − 0.511566 = 0.488434
5. G/R_n = 0.128300 × 0.488434 = **0.0626661**
6. G = 0.0626661 × 600 = **37.600 W m⁻²**

**B4 — borde T_s = 273.15 K.** `lst = 273.15`, `albedo = 0.20`,
`ndvi = 0.30`, `rn = 400` → T_c = 0 → G/R_n = **0**, G = **0 W m⁻²**
(exactamente; sin flags de razón).

**B5 — T_s bajo 0 °C (razón negativa).** `lst = 268.15` K, `albedo = 0.60`,
`ndvi = 0.05`, `rn = 200` W m⁻².

1. T_c = −5.00 °C
2. 0.0074 × 0.60 = 0.00444; 0.0038 + 0.00444 = 0.00824
3. T_c × 0.00824 = −0.041200
4. NDVI⁴ = 6.25 × 10⁻⁶; 1 − 0.98 × 6.25 × 10⁻⁶ = 0.999994
5. G/R_n = **−0.0411997**; G = **−8.23995 W m⁻²**
6. Esperado: valor conservado sin truncar; flag `EF_G_RATIO_NEGATIVE`.

**B6 — simetría en NDVI.** Igual a B1 con `ndvi = −0.50` → mismo resultado
(**74.349 W m⁻²**) porque (−0.5)⁴ = 0.0625. Esperado: flag
`EF_G_NDVI_NONPOSITIVE`. Documenta la limitación (a) de §3.1.

### 8.2 Tasumi / METRIC

**T1 — dosel (rama vegetada).** `lai = 3.0`, `rn = 550` W m⁻²
(`lst` cualquiera válida, p. ej., 300 K).

1. −0.521 × 3.0 = −1.563
2. exp(−1.563) = 0.209507
3. 0.18 × 0.209507 = 0.0377112
4. G/R_n = 0.05 + 0.0377112 = **0.0877112**
5. G = 0.0877112 × 550 = **48.241 W m⁻²**

**T2 — borde LAI = 0.5 (pertenece a la rama vegetada).** `lai = 0.5`,
`rn = 500` W m⁻².

1. −0.521 × 0.5 = −0.2605
2. exp(−0.2605) = 0.770666
3. 0.18 × 0.770666 = 0.138720
4. G/R_n = **0.188720**
5. G = 0.188720 × 500 = **94.360 W m⁻²**

**T3 — LAI alto.** `lai = 6.0`, `rn = 600` W m⁻².

1. −0.521 × 6.0 = −3.126; exp(−3.126) = 0.0438930
2. 0.18 × 0.0438930 = 0.00790074
3. G/R_n = **0.0579007**; G = **34.740 W m⁻²**

**T4 — suelo desnudo.** `lai = 0.2`, `lst = 318.15` K, `rn = 400` W m⁻².

1. LAI < 0.5 → rama de suelo desnudo
2. T_c = 45.00 °C; 1.80 × 45.00 = 81.000 W m⁻²
3. 0.084 × 400 = 33.600 W m⁻²
4. G = 81.000 + 33.600 = **114.600 W m⁻²**; G/R_n = **0.286500**
5. Esperado: flag `EF_G_LOW_LAI_BRANCH`. (Con 273.16, como en `water`:
   114.582 W m⁻², diferencia 0.018 W m⁻².)

**T5 — LAI = 0.** `lai = 0`, `lst = 308.15` K, `rn = 350` W m⁻².

1. T_c = 35.00 °C; 1.80 × 35.00 = 63.000
2. 0.084 × 350 = 29.400
3. G = **92.400 W m⁻²**; G/R_n = **0.264000**

**T6 — discontinuidad en LAI = 0.5.** `lst = 318.15` K, `rn = 400` W m⁻².

- `lai = 0.4999` → rama de suelo desnudo: G = 81.000 + 33.600 = **114.600 W m⁻²**
- `lai = 0.5` → rama vegetada: G = 0.188720 × 400 = **75.488 W m⁻²**
- Salto de −39.1 W m⁻² por un cambio de 10⁻⁴ en LAI. El test debe fijar
  qué rama corresponde exactamente a 0.5 (según `water`: vegetada, pues la
  condición de suelo desnudo es `LAI < 0.5`; `TODO`: confirmar en la fuente
  primaria si es `<` o `≤`).

**T7 — R_n pequeño (razón > 1).** `lai = 0.2`, `lst = 318.15` K,
`rn = 40` W m⁻².

1. 1.80 × 45.00 = 81.000; 0.084 × 40 = 3.360
2. G = **84.360 W m⁻²**; G/R_n = **2.10900**
3. Esperado: valor conservado; flag `EF_G_EXCEEDS_RN`.

**T8 — R_n = 0 en rama de suelo desnudo.** `lai = 0.2`, `lst = 318.15` K,
`rn = 0` → G = **81.000 W m⁻²** (cálculo directo, sin división);
`g_rn_ratio = NA`; flag `EF_G_RN_NONPOSITIVE`.

### 8.3 Superficies especiales (solo si se verifica la regla)

**W1 (`TODO`, no implementar).** Si se verifica G/R_n = 0.5 para agua:
`rn = 600` → G = 300 W m⁻². Se incluye solo como plantilla.

---

## 9. Tests planificados (`tests/testthat/test-soil-heat.R`)

Tolerancias: `expect_equal(..., tolerance = 1e-6)` relativa para los casos
de §8 (justificación: los valores esperados se redondearon a ≥ 6 cifras
significativas); identidades algebraicas (equivalencias) con la tolerancia
por defecto de testthat (`VALIDATION_PLAN.md` §1.2).

### 9.1 Unitarios (valores)

- B1–B6 para `ef_soil_heat_flux_bastiaanssen()`.
- T1–T8 para `ef_soil_heat_flux_tasumi()`.
- Vectorización: los casos de un método en un solo vector dan el mismo
  resultado que caso por caso.
- Unidades: G en W m⁻² (p. ej., B1 = 74.349, no 0.0744 ni 7.43 × 10⁴);
  `lst` en K (pasar `lst = 30` no reproduce B1).

### 9.2 Bordes

- `albedo` = 0 y 1; `ndvi` = −1, 0 y 1; `lai` = 0 y 0.5 (T2, T6);
  `lst` = 273.15 (B4); `rn` = 0 (T8) y negativo (flag, sin error).

### 9.3 NA

- `NA` en cada entrada requerida → `NA` en esa posición y en ninguna otra;
  `EF_INPUT_NA` con los índices correctos.
- Tasumi: `NA` en `lst` con `lai ≥ 0.5` → `NA` (decisión §6.1).
- `NaN` se comporta como `NA`.

### 9.4 Errores con clase

- `albedo` = −0.01 y 1.01; `ndvi` = −1.01 y 1.01; `lai` = −0.1;
  `lst` = 0 y −10 → `earthflux_domain_error`.
- `Inf` en cualquier entrada → `earthflux_domain_error`.
- Entrada no numérica → `earthflux_input_error`.
- Longitudes 3 y 2 → `earthflux_dimension_error`; longitud 1 se recicla.
- Despachador: `method` ausente, `"Tasumi"`, `"tas"` o `"metric"` →
  `earthflux_unknown_method`; argumento requerido ausente →
  `earthflux_missing_input`.

### 9.5 Flags y no corrección

- B5 → `EF_G_RATIO_NEGATIVE`; T7 → `EF_G_EXCEEDS_RN`; T8 →
  `EF_G_RN_NONPOSITIVE`; T4 → `EF_G_LOW_LAI_BRANCH`; B6 →
  `EF_G_NDVI_NONPOSITIVE`.
- Los valores de G con flag son idénticos a los de la función de bajo nivel
  (nada se trunca).
- `EF_G_RATIO_IMPLAUSIBLE` **no** existe en el registro hasta que D7 se
  resuelva (test que lo confirme, para impedir umbrales sin referencia).

### 9.6 Equivalencia y procedencia

- `ef_soil_heat_flux(..., method = "bastiaanssen")$g` idéntico a
  `ef_soil_heat_flux_bastiaanssen(...)`; ídem Tasumi.
- `$method` igual al argumento; `$provenance` contiene referencia, estado
  de verificación, constantes (273.15, umbral 0.5) y entradas usadas.
- `$g_rn_ratio * rn == $g` donde `rn != 0`.
- Argumentos no requeridos (p. ej., `lai` con Bastiaanssen) no alteran el
  resultado.
- `SpatRaster` (cuando `terra` entre en `Imports`): mismo resultado que con
  `numeric` en un ráster pequeño; geometría preservada.
- Verificación cruzada con `water` (fuera del tarball, `VALIDATION_PLAN.md`
  §1.3): diferencias esperadas y explicadas (273.16 vs. 273.15; `e`
  aproximada; píxeles LAI ≥ 0.5 con T_s `NA`; NDVI calculado internamente
  por `water`).

---

## 10. Qué debe verificar el autor en las fuentes primarias

**Bastiaanssen (2000)** (y, si corresponde, Bastiaanssen et al., 1998):

1. Cita completa y DOI (`10.1016/S0022-1694(99)00202-4` es candidato).
2. Número de ecuación y página de la relación G/R_n.
3. Coeficientes exactos (0.0038, 0.0074, 0.98) y exponente de NDVI (4).
4. Forma exacta: ¿T_s en °C? ¿forma factorizada con α en el denominador?
   ¿equivalente a la de §3.1 para todo α ∈ [0, 1]?
5. Definición de T_s (radiométrica, superficie) y de α (superficie, banda
   ancha) y de NDVI (superficie o TOA).
6. Hora del día / condiciones para las que se derivó (mediodía, cielo
   despejado), sensor y resolución, superficies (Gediz, Turquía, según el
   título; confirmar).
7. Tratamiento de agua, nieve o NDVI < 0, si existe.

**Tasumi (2003)** y **Allen et al. (2007), METRIC — Model**:

8. Cita completa y DOI de Allen et al. (2007) (`REFERENCES.md`:
   `TODO: verify DOI`); cita completa de Tasumi (2003).
9. Números de ecuación de G (las notas terciarias indican Eq. 26–27 y
   "27b"; verificar) y página.
10. Coeficientes de la rama vegetada (0.05, 0.18, 0.521) y de la de suelo
    desnudo (1.80, 0.084).
11. Umbral de LAI (0.5) y si la condición es `LAI < 0.5` o `LAI ≤ 0.5`.
12. Constante K → °C en la rama de suelo desnudo (273.15 o 273.16) y
    unidades de 1.80.
13. Origen y definición del LAI con que se derivó la relación (medido o
    desde SAVI; reflectancia TOA o de superficie).
14. Sitios, cultivos, suelos y hora de las mediciones de derivación.
15. Reglas para agua y nieve (las notas terciarias indican G/R_n = 0.5 para
    NDVI ≤ 0, con discriminación de nieve por albedo y T_s < 277 K, p. 385):
    criterio exacto, umbral de albedo, página.
16. "Limitación de G en desierto" (p. 385 según la misma fuente terciaria):
    contenido exacto.
17. Convención de signo de G.
18. Cualquier rango plausible de G/R_n reportado (insumo para D7).

**Generales:**

19. Fuente para superficies impermeables (si existe).
20. Referencia sobre el desfase diurno G–R_n y su efecto en relaciones
    G/R_n instantáneas (insumo para §7.3).
21. Estudios que apliquen estas relaciones a MODIS ~1 km (insumo para §7.1).

---

## 11. Decisiones abiertas

| Id | Decisión | Opción recomendada (provisional) | Requiere |
|---|---|---|---|
| D1 | Método por defecto en `earthflux()` | Tasumi (formulación asociada a METRIC), pero solo si se verifica; el despachador de bajo nivel sin defecto | Verificación §10 |
| D2 | Exportar las funciones por método | Sí, como API avanzada | Revisión de tamaño de la API pública |
| D3 | Estructura del objeto devuelto por el despachador | Lista liviana con `g`, `g_rn_ratio`, `method`, `branch`, `flags`, `provenance`; clase final coordinada con `earthflux_result` | Diseño de clases (M2) |
| D4 | Superficies especiales (agua, nieve, impermeable) | Sin regla hasta verificar; flag `EF_G_NDVI_NONPOSITIVE`; si se adopta, como método/capa explícita | Verificación ítems 15, 16, 19 |
| D5 | NA en `lst` con LAI ≥ 0.5 (Tasumi) | `NA` (conservador) | Confirmación del autor |
| D6 | Entradas fuera de dominio en rásteres | Error (por defecto); evaluar opción `on_invalid` | Diseño del módulo `surface` |
| D7 | Rango plausible de G/R_n | Ninguno hasta tener referencia; flag no registrado | Referencia (ítem 18) |
| D8 | Escala de evaluación de G con MODIS (1 km vs. escala fina y agregación) | Documentar como limitación; evaluar en M6 | Diseño experimental (`VALIDATION_PLAN.md`) |
| D9 | Constante K → °C | 273.15 en todo el paquete | Ítem 12 |

---

## 12. Paso a `VERIFICADA`

Una formulación de este documento pasa a `VERIFICADA` (y puede
implementarse) solo cuando se cumplan los ítems de la Definition of Done
(`DEVELOPMENT.md` §3): ecuación contrastada con la fuente primaria (ítems
de §10 que le correspondan), referencia con DOI en `REFERENCES.md`,
entradas y unidades (§4), NA (§6.1), dominio (§6.2), casos numéricos
recalculados (§8) y tests diseñados (§9). En ese momento se actualiza la
fila G de `SCIENTIFIC_SPEC.md` §3 y la entrada de `REFERENCES.md`
(*Soil heat flux*).
