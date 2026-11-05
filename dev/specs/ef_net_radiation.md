# Especificación: `ef_net_radiation()`

Función científica · Módulo `metric` (`R/metric-radiation.R`) · Hito M1/M2 ·
Rama `function/net-radiation`.

Estado de la ecuación: **`VERIFICADA (SEBAL-Idaho 2002)`** desde el
2026-11-05 — forma idéntica, término a término, a la Ec. 2 del manual SEBAL
de Idaho (Waters et al., 2002, pp. 10 y 14), que mantiene explícito el
término reflejado (1 − ε₀)RL↓ (`DECISIONS.md` M2-08; NR-D3 cerrada;
[`../VERIFICATION.md`](../VERIFICATION.md), fila 1). El contraste con Allen
et al. (2007) es deseable, no bloqueante. Antes: `CANDIDATA (corroborada)`,
forma corroborada por dos fuentes secundarias independientes (sección 2.3).

Complementa `SCIENTIFIC_SPEC.md` (sección 3, fila de radiación neta) y sigue
la *Definition of Done* de `DEVELOPMENT.md` (sección 3).

---

## 1. Propósito

Calcular la radiación neta instantánea en la superficie terrestre (Rn), es
decir, la energía radiante disponible para los flujos de calor del suelo (G),
sensible (H) y latente (LE), a partir de sus cuatro componentes y de las
propiedades radiativas de la superficie. Es el primer término del balance
de energía de METRIC (LE = Rn − G − H).

La función es de bajo nivel: aritmética, vectorizada e independiente del
sensor. No calcula sus entradas (ver sección 9).

## 2. Ecuación y referencias

### 2.1 Ecuación

```text
Rn = (1 − α)·Rs↓ + RL↓ − RL↑ − (1 − ε₀)·RL↓
```

| Término | Significado físico |
|---|---|
| (1 − α)·Rs↓ | Onda corta absorbida por la superficie |
| RL↓ | Onda larga entrante (atmosférica) |
| RL↑ | Onda larga **emitida** por la superficie (ε₀·σ·Ts⁴) |
| (1 − ε₀)·RL↓ | Onda larga entrante **reflejada** por la superficie |

Forma equivalente (útil para interpretar): Rn = (1 − α)·Rs↓ + ε₀·RL↓ − RL↑,
ya que RL↓ − (1 − ε₀)·RL↓ = ε₀·RL↓. La implementación conserva la forma
explícita de cuatro términos para que el término reflejado sea visible y
auditable.

### 2.2 Referencias

- **Fuente primaria (pendiente de verificación):** Allen, R. G., Tasumi, M.,
  & Trezza, R. (2007). Satellite-based energy balance for mapping
  evapotranspiration with internalized calibration (METRIC) — Model.
  *Journal of Irrigation and Drainage Engineering*, 133(4), 380–394.
  DOI `10.1061/(ASCE)0733-9437(2007)133:4(380)` (verificado con Crossref,
  2026-11-04; ver D4).
  Número de ecuación en el artículo: `TODO`.
- **Fuente secundaria 1:** paquete R `water` v1.0, función
  `netRadiation()`, que cita Allen, Tasumi y Trezza (2007). Implementa
  exactamente esta forma, con RL↑ = ε₀·σ·Ts⁴ (onda larga emitida) y ε₀
  derivada internamente desde LAI.
  - Observación adicional (no independiente: mismo paquete, versión
    anterior): en `water` 0.8 (archivo de CRAN,
    `water/R/water_netRadiation.G.R`, revisado 2026-11-04) la función
    `netRadiation()` tiene la misma forma y `outLWradiation()` calcula
    RL↑ = ε₀·σ·Ts⁴ con la misma ε₀ derivada de LAI. Esto respalda la
    convención de que `rl_out` es la onda larga emitida y de que la
    emisividad debe ser la misma en ambos términos. No se copió código
    (licencia GPL).
- **Fuente secundaria 2:** Wasti, S. (2020). Tesis de maestría
  (University of Chinese Academy of Sciences), arXiv:2007.13922 v2,
  Ec. (2.6), p. 24: misma forma de la ecuación, con RL↑ = ε₀·σ·Ts⁴
  (Ec. 2.16) y la misma ε₀. La tesis atribuye la ecuación a Brunsell &
  Gillies (2002) y Hipps (1989), no a Allen et al. (2007). Fuente
  independiente de `water`; corrobora la forma pero no es fuente primaria
  (revisada 2026-11-04; ver `verification/reference-audit.md`).
- **Nota:** el artículo de `water` en The R Journal (Olmedo et al., 2016)
  **no** imprime la ecuación de Rn; la "fuente secundaria 1" corresponde al
  **código** de `water`, no al artículo.

### 2.3 Estado de verificación

| Aspecto | Estado |
|---|---|
| Forma de la ecuación | Corroborada por dos fuentes secundarias independientes |
| Contraste con Allen et al. (2007) | **Pendiente** |
| Número de ecuación | `TODO` |
| DOI | Verificado con Crossref (2026-11-04) |
| Constantes | La ecuación no contiene constantes numéricas |

Por lo tanto el estado es **`CANDIDATA (corroborada)`** y no `VERIFICADA`.
El punto 1 de la *Definition of Done* exige `VERIFICADA`: la implementación
se adelanta en esta rama para revisión, pero **la fusión a `main` requiere
que el autor confirme la ecuación (forma, notación y número) contra el
artículo** y actualice esta sección, `SCIENTIFIC_SPEC.md` y
`REFERENCES.md`.

## 3. Entradas

Firma: `ef_net_radiation(rs_in, albedo, rl_in, rl_out, emissivity)`.

| Argumento | Símbolo | Unidad | Definición |
|---|---|---|---|
| `rs_in` | Rs↓ | W m⁻² | Radiación de onda corta entrante (descendente) en la superficie, **instantánea a la hora de paso** del satélite |
| `albedo` | α | – | Albedo superficial de banda ancha |
| `rl_in` | RL↓ | W m⁻² | Radiación de onda larga entrante (descendente) en la superficie |
| `rl_out` | RL↑ | W m⁻² | Radiación de onda larga **emitida** por la superficie, ε₀·σ·Ts⁴. **No** incluye la componente reflejada |
| `emissivity` | ε₀ | – | Emisividad superficial de banda ancha |

Notas de diseño:

- **Coherencia de la emisividad.** `emissivity` debe ser la misma ε₀ usada
  para calcular `rl_out`. La función no puede comprobarlo (no recibe Ts);
  la coherencia es responsabilidad de quien llama y se documenta en roxygen.
- **Caso ε₀ = 1.** Si el usuario dispone de la onda larga ascendente
  **total** (emitida + reflejada), p. ej., medida con un radiómetro, la
  llamada equivalente es `emissivity = 1` con `rl_out` = onda larga total:
  el término reflejado se anula y no se cuenta dos veces. Documentado en
  roxygen y verificado en tests.
- **Independencia del sensor.** La emisividad es una entrada explícita y no
  se deriva de LAI dentro de la función (a diferencia de
  `water::netRadiation()`, que la deriva de LAI internamente). Así la
  función sirve con emisividad de producto MODIS, de otro sensor o de una
  relación empírica calculada aguas arriba.
- **Término reflejado explícito.** (1 − ε₀)·RL↓ se mantiene como término
  propio (ver `ARCHITECTURE.md` §6.4).

### 3.1 Tipo, longitud y forma

- Cada argumento debe ser numérico (`double` o `integer`); `logical`,
  `character`, `complex`, factores y otros objetos con clase no numérica se
  rechazan con error de clase `earthflux_input_error`. No hay coerción
  silenciosa.
- Reciclaje: cada argumento debe tener longitud 1 o una longitud común n;
  en caso contrario, `earthflux_input_error`. Los argumentos de longitud 1
  se reciclan.
- Argumentos de longitud 0: se rechazan (`earthflux_input_error`).
  *Decisión tomada al implementar* (sección 10, D5).
- Matrices/arreglos: si los argumentos no escalares son matrices o arreglos
  con idéntico `dim`, el resultado conserva ese `dim` (aritmética natural
  de R). Los argumentos con `dim` no se reciclan: deben compartir el mismo
  `dim` y tener la longitud común; si no, `earthflux_input_error` (evita el
  error sin clase "non-conformable arrays" y el warning de R por reciclar un
  arreglo de longitud 1). Una matriz combinada con vectores simples de
  longitud n conserva su `dim`. *Decisión tomada al implementar* (D6).

## 4. Salida

Vector numérico (`double`) de longitud n con Rn en **W m⁻²**. Si las
entradas incluyen matrices/arreglos con el mismo `dim`, la salida conserva
ese `dim`. Los atributos `names` pueden propagarse según las reglas de la
aritmética de R, pero no forman parte del contrato de la función.

Rn negativo **se devuelve sin cambios y sin warning**: es físicamente
posible (noche, nieve, superficies muy frías o de alto albedo). Si se marca
o no en escenas diurnas es una decisión abierta de la capa de orquestación
(D2).

## 5. Comportamiento con NA

- `NA` y `NaN` en cualquier entrada se propagan al elemento correspondiente
  de la salida por aritmética. Sin error y sin warning.
- Los valores faltantes se ignoran en la comprobación de dominio.
- Los flags de diagnóstico (`EF_INPUT_NA`) **no** se construyen en esta
  función de bajo nivel: los ensambla la capa de orquestación (futura
  `earthflux()` / `api-run.R`) a partir de las máscaras de entrada, de
  acuerdo con el principio de diagnósticos como parte del resultado
  (`ARCHITECTURE.md` §1, principio 5).

## 6. Dominio y comportamiento fuera de él

Comprobación ignorando NA/NaN:

| Argumento | Dominio aceptado | Bordes |
|---|---|---|
| `rs_in` | ≥ 0 | 0 permitido (noche) |
| `albedo` | [0, 1] | 0 y 1 permitidos |
| `rl_in` | > 0 | 0 rechazado |
| `rl_out` | > 0 | 0 rechazado |
| `emissivity` | (0, 1] | 0 rechazado; 1 permitido |
| todos | finitos | `Inf`/`-Inf` rechazados |

- Violación → error con clases
  `c("earthflux_domain_error", "earthflux_input_error", "earthflux_error")`,
  cuyo mensaje nombra el argumento y el número de valores fuera de dominio
  (p. ej., "`albedo` must lie in [0, 1]; found 2 value(s) outside this
  interval."). La llamada reportada es la de `ef_net_radiation()`.
- Justificación: las entradas inválidas deben enmascararse o marcarse
  aguas arriba por QA (productos MODIS, QC de estaciones). El núcleo físico
  **nunca corrige silenciosamente** (`ARCHITECTURE.md` §1, principio 6).
- RL↓ y RL↑ estrictamente positivos: toda superficie y atmósfera reales
  emiten (temperatura > 0 K); un valor 0 indica relleno o error de unidades.
- Cotas superiores de plausibilidad (p. ej., Rs↓ mayor que la constante
  solar, RL fuera de un rango físico, emisividad terrestre por debajo de un
  umbral): **decisión abierta**, requiere referencia (D1). **No se
  implementan.**

Implementación de las comprobaciones: helpers internos en `R/utils.R`
(`check_numeric()`, `check_common_length()`, `check_same_dim()`,
`check_in_range()`), con tests propios en `tests/testthat/test-utils.R`.

## 7. Caso numérico verificable

Cálculo a mano, independiente de cualquier software.

Entradas:

| Argumento | Valor |
|---|---|
| `rs_in` | 800 W m⁻² |
| `albedo` | 0.20 |
| `rl_in` | 320 W m⁻² |
| `emissivity` | 0.98 |
| `rl_out` | 450.0846 W m⁻² |

Construcción de `rl_out` (solo para justificar el valor; en el test se pasa
directamente el número 450.0846, de modo que ninguna constante interviene):
Ts = 300 K, σ = 5.67 × 10⁻⁸ W m⁻² K⁻⁴ (valor redondeado, usado solo para
construir el caso; la constante y su referencia se especificarán con la
función de RL↑, `TODO`).

1. 300⁴ = 8.1 × 10⁹ K⁴.
2. σ·Ts⁴ = 5.67 × 10⁻⁸ × 8.1 × 10⁹ = 5.67 × 81 = 459.27 W m⁻².
3. ε₀·σ·Ts⁴ = 0.98 × 459.27 = 450.0846 W m⁻² (exacto en aritmética
   decimal: 459.27 − 0.02 × 459.27 = 459.27 − 9.1854 = 450.0846).

Cálculo de Rn:

1. 1 − α = 1 − 0.20 = 0.80.
2. (1 − α)·Rs↓ = 0.80 × 800 = 640 W m⁻².
3. 1 − ε₀ = 1 − 0.98 = 0.02.
4. (1 − ε₀)·RL↓ = 0.02 × 320 = 6.4 W m⁻².
5. Onda larga neta: RL↓ − RL↑ − (1 − ε₀)·RL↓ = 320 − 450.0846 − 6.4 =
   −136.4846 W m⁻².
6. **Rn = 640 + 320 − 450.0846 − 6.4 = 640 − 136.4846 = 503.5154 W m⁻².**

Comprobación con la forma equivalente: ε₀·RL↓ = 0.98 × 320 = 313.6;
Rn = 640 + 313.6 − 450.0846 = 503.5154 W m⁻². Coincide.

Casos derivados (también exactos a mano):

| Caso | Entradas modificadas | Rn esperado (W m⁻²) |
|---|---|---|
| Onda larga total con ε₀ = 1 | `rl_out` = 450.0846 + 6.4 = 456.4846, `emissivity` = 1 | 640 + 320 − 456.4846 = 503.5154 |
| α = 0, ε₀ = 1 | `rs_in` 800, `rl_in` 320, `rl_out` 450 | 800 + 320 − 450 = 670 |
| RL↓ = RL↑, ε₀ = 1 | `rl_in` = `rl_out` = 350 | (1 − α)·Rs↓ |
| Nocturno | `rs_in` 0, α 0.2, `rl_in` 280, `rl_out` 400, ε₀ 0.98 | 280 − 400 − 5.6 = −125.6 |

### 7.1 Tolerancia

El valor de referencia es exacto en aritmética decimal. La evaluación en
doble precisión implica dos productos y cuatro sumas/restas con magnitudes
menores que 10³, por lo que el error de redondeo es del orden de
10⁻¹³ W m⁻². Se usa una **tolerancia absoluta de 10⁻¹⁰ W m⁻²**
(`expect_lt(abs(rn - 503.5154), 1e-10)`): muy por encima del ruido de
redondeo y muy por debajo de cualquier diferencia físicamente relevante. Se
prefiere una tolerancia absoluta explícita a la tolerancia relativa por
defecto de `expect_equal()` para que el criterio quede documentado en el
propio test.

## 8. Diseño de tests (`tests/testthat/test-radiation.R`)

| Test | Qué verifica |
|---|---|
| Caso de referencia | Rn = 503.5154 ± 10⁻¹⁰; tipo `double`, longitud 1 |
| Onda larga total con ε₀ = 1 | Equivalencia con el caso de referencia |
| α = 0 y ε₀ = 1 | Rn = Rs↓ + RL↓ − RL↑ |
| Onda larga que se cancela | RL↓ = RL↑ y ε₀ = 1 → Rn = (1 − α)·Rs↓ (vector) |
| Reciclaje de escalares | Vector `rs_in` con el resto escalar |
| Entradas enteras | `integer` aceptado |
| Longitudes incompatibles | `earthflux_input_error`; longitud 0 rechazada |
| NA/NaN | Propagación elemento a elemento, sin warnings (`expect_silent`) |
| Dominio de `albedo` | −0.01 y 1.01 rechazados; 0 y 1 permitidos; mensaje con nombre y conteo |
| Dominio de `emissivity` | 0, −0.5 y 1.02 rechazados; 1 permitido |
| Dominio de `rs_in` | −1 rechazado; 0 permitido |
| Dominio de `rl_in`, `rl_out` | 0 y negativos rechazados |
| Valores infinitos | `Inf` rechazado en cada argumento; `-Inf` también |
| Clases de condición | `earthflux_domain_error` ⊂ `earthflux_input_error` ⊂ `earthflux_error`; llamada reportada `ef_net_radiation()` |
| Tipos no numéricos | `character`, `logical` (incl. `NA` lógico) y factor rechazados |
| Matrices | `dim` conservado; valores correctos |
| `dim` distintos | `earthflux_input_error` |
| Rn negativo | Devuelto sin cambios y sin warning |

Helpers (`tests/testthat/test-utils.R`): tests de `check_numeric()`,
`check_common_length()`, `check_same_dim()` y `check_in_range()` (bordes
abiertos/cerrados, NA ignorado, infinitos, conteo y nombre en el mensaje,
clase del error, llamada reportada).

## 9. Fuera de alcance

- Cálculo de `rs_in` (transmisividad, partición directa/difusa, corrección
  por pendiente y orientación), de `rl_in` (emisividad atmosférica) y de
  `rl_out` (Stefan-Boltzmann con Ts y ε₀): funciones compañeras futuras,
  cada una con su propia especificación.
- Derivación de α o ε₀ desde productos o índices (módulo `surface`).
- Soporte de `SpatRaster`: M2, una vez que `terra` se agregue como
  dependencia. El diseño aritmético es compatible (la aritmética de `terra`
  es vectorizada por capas), pero las comprobaciones de tipo/dominio deberán
  adaptarse.
- Construcción de flags de diagnóstico (`EF_INPUT_NA`, Rn negativo): capa de
  orquestación.
- Radiación neta diaria (Rn24) para extrapolación temporal.

## 10. Decisiones

### 10.1 Tomadas

- Firma y unidades de la sección 3; ε₀ explícita; término reflejado
  explícito; `rl_out` = onda larga emitida.
- Propagación de NA sin flags en la función de bajo nivel.
- Errores de dominio con clase; sin corrección silenciosa; Rn negativo
  permitido sin warning.

### 10.2 Abiertas

- **D1.** Cotas superiores de plausibilidad (Rs↓ vs. constante solar, rango
  de RL↓/RL↑, emisividad mínima para superficies terrestres). `TODO`:
  requiere referencia; no implementado.
- **D2.** ¿Marcar Rn < 0 en escenas diurnas? Corresponde a la capa de
  orquestación; requiere criterio documentado.
- **D3.** Número de ecuación y notación exacta en Allen et al. (2007):
  `TODO` (bloquea la fusión, sección 2.3).
- **D4.** ~~Confirmar DOI de Allen et al. (2007).~~ **Cerrada
  (2026-11-04):** DOI 10.1061/(ASCE)0733-9437(2007)133:4(380) verificado
  con Crossref (`verification/reference-audit.md`).
- **D5.** (Provisional, tomada al implementar) Rechazar argumentos de
  longitud 0 en lugar de devolver `numeric(0)`. Revisable si algún
  envoltorio necesita procesar bloques vacíos.
- **D6.** (Provisional, tomada al implementar) Los argumentos con `dim` no
  se reciclan y deben compartir `dim`. Revisar al diseñar el soporte de
  `SpatRaster`.
- **D7.** ¿Debe una futura función de alto nivel aceptar Ts en lugar de
  `rl_out` para garantizar por construcción la coherencia de ε₀? Se
  decidirá al especificar la función de RL↑.
