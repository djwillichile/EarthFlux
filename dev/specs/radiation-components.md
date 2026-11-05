# EarthFlux — Especificación: componentes de radiación para `ef_net_radiation()`

Estado: **borrador M1** · Complementa `SCIENTIFIC_SPEC.md` (§1.2, §2.2, §2.3,
§3) y `ARCHITECTURE.md` (§1, §3, §4, §6).

> **Regla fundamental.** Ninguna ecuación de este documento está en estado
> `VERIFICADA`. Todas son `CANDIDATA` (forma conocida, sin contrastar con la
> fuente primaria) o `TODO` (falta información). Ninguna función descrita
> aquí puede implementarse hasta cumplir la Definition of Done
> (`DEVELOPMENT.md` §3).

Convención de estados: la misma de `SCIENTIFIC_SPEC.md` (`TODO`,
`CANDIDATA`, `VERIFICADA`).

> **Verificación (2026-11-05, `DECISIONS.md` M2-08).** Contraste con el
> manual SEBAL de Idaho (Waters et al., 2002), registro en
> [`../VERIFICATION.md`](../VERIFICATION.md) (filas 2–13). Pasan a
> `VERIFICADA (SEBAL-Idaho 2002)`: τ_sw = 0,75 + 2·10⁻⁵·z como τ
> instantánea (p. 18, Ec. 11), ε_a = 0,85·(−ln τ_sw)^0,09 (p. 23, Ec. 22),
> Rs↓ = Gsc·cos θ·d_r·τ_sw en terreno plano (p. 19, Ec. 12), RL↓ =
> ε_a·σ·T⁴ (p. 23, Ec. 21) y RL↑ = ε₀·σ·Ts⁴ (p. 22, Ec. 20); ε₀ desde LAI
> (E3, p. 20, Ec. 16b) como forma para NDVI > 0. **RC-12:** el manual usa
> la Ts del píxel frío (Ec. 23) con ajuste por elevación en montaña
> (Ec. 12-8), y Allen et al. (2012, p. 74) lo confirma para METRIC
> (opción (b)); `ef_rl_in()` sigue agnóstica (P0-3). **RC-06:** el manual
> usa Gsc = 1367 W m⁻² (el de FAO-56 redondeado) con la τ de FAO-56.
> Siguen `CANDIDATA`: τ particionada (RC-08), Rs↓ en laderas (el modelo de
> montaña del manual usa cos θ / cos s, "equivalente horizontal", y una τ
> total: discrepancia de marco, RC-09) y cos θ en plano inclinado (el
> quinto término de la Ec. 12-1 está impreso con sen φ en lugar de sen γ,
> errata aparente). El resto del documento conserva la redacción de M1.

Convención de trazabilidad usada en este documento:

- **"Forma observada en `water` v1.0, función X"**: la ecuación aparece en
  el código del paquete `water` (GPL ≥ 2), revisado como fuente
  **secundaria**. No se copia su código; las ecuaciones se reescriben con
  notación propia. Que `water` use una forma **no** la verifica.
- **"Fuente primaria citada allí"**: referencia que `water` atribuye a esa
  forma en su documentación. Tampoco está verificada.
- Los casos numéricos fueron calculados a mano por el autor (pasos
  explícitos) a partir de las formas candidatas; verifican aritmética, no
  la física.

> **Estado de implementación (M2, 2026-11-04).** Implementado en
> `R/solar-geometry.R` (§6.1) y `R/metric-radiation.R` (§6.3–§6.6), con
> tests en `tests/testthat/test-solar-geometry.R` y `test-radiation.R`.
> Detalle de las decisiones tomadas al implementar en §12.

---

## 0. Índice

1. Alcance y contrato con `ef_net_radiation()`
2. Diagrama de dependencias
3. Tabla de entradas por módulo (dónde entra el forzamiento GWR)
4. Convenciones transversales (unidades, ángulos, tiempo, NA, errores, flags)
5. Constantes
6. Funciones
   - 6.1 `ef_solar_geometry()` y auxiliares geométricas
   - 6.2 `ef_air_pressure()`
   - 6.3 `ef_tau_sw_allen()` y `ef_tau_sw_elevation()`
   - 6.4 `ef_rs_in_modelled()` y `ef_rs_in_measured()`
   - 6.5 `ef_atm_emissivity()` y `ef_rl_in()`
   - 6.6 `ef_rl_out()`
7. Caso integrado de cadena (Rn)
8. Verificación cruzada con `water`: diferencias esperadas
9. Registro de decisiones abiertas
10. Referencias primarias que el autor debe verificar
11. Fuera de alcance

---

## 1. Alcance y contrato con `ef_net_radiation()`

`ef_net_radiation()` (primera candidata, `SCIENTIFIC_SPEC.md` §3) recibe:

```text
ef_net_radiation(rs_in, albedo, rl_in, rl_out, emissivity)

Rn = (1 − α)·Rs↓ + RL↓ − RL↑ − (1 − ε₀)·RL↓          [W m⁻²]
```

Este documento especifica las funciones que **producen** `rs_in` (Rs↓),
`rl_in` (RL↓) y `rl_out` (RL↑). `albedo` (α) y `emissivity` (ε₀) provienen
del módulo `surface` y no se especifican aquí, salvo los requisitos de
coherencia que imponen sobre estas funciones (§6.4, §6.6).

Requisitos de contrato que estas funciones deben respetar:

| # | Requisito | Motivo |
|---|---|---|
| C1 | `rl_out` es la onda larga **emitida** por la superficie, ε₀·σ·Ts⁴. **No** incluye la onda larga reflejada. | `ef_net_radiation()` resta la reflejada explícitamente con el término (1 − ε₀)·RL↓; incluirla en `rl_out` la contaría dos veces. Un RL↑ **medido** con pirgeómetro (torres de validación) es emitida + reflejada y no es intercambiable con `rl_out`. |
| C2 | La `emissivity` pasada a `ef_rl_out()` y a `ef_net_radiation()` es **el mismo objeto** (ε₀ de banda ancha). | Si difieren, el balance de onda larga deja de ser ε₀·(RL↓ − σTs⁴) y aparece un término espurio. El orquestador (`earthflux()`) debe garantizarlo. |
| C3 | `rs_in` es la irradiancia de onda corta **instantánea** sobre el plano del píxel (horizontal o inclinado, según se haya pedido corrección topográfica), a la hora de paso de ese píxel. | α es una propiedad del plano del píxel; Rn es instantánea (SPEC §3). |
| C4 | Todas las salidas en W m⁻²; temperaturas en K. | `ARCHITECTURE.md` §5. |
| C5 | Las funciones son aritméticas y vectorizadas (`ARCHITECTURE.md` §3): no leen archivos ni conocen el sensor. | Principios 1–2. |

### 1.1 La partición directa/difusa pertenece a este módulo

Se registra explícitamente (consistente con `SCIENTIFIC_SPEC.md` §2.2):

- La partición de Rs↓ en componente **directa (beam)** y **difusa** es una
  propiedad de la atmósfera (presión, vapor de agua, aerosoles, nubes) y de
  la geometría solar. Se determina **antes** y con independencia del balance
  de energía.
- Los píxeles ancla (frío/caliente) calibran la relación dT–Ts para H
  (SPEC §2.1). No contienen información sobre la distribución angular de la
  radiación incidente: a lo sumo absorben parte de un sesgo **total** de Rn
  en esos píxeles, pero no pueden separar directa de difusa ni producir un
  campo espacial de esa partición (son uno o pocos píxeles).
- Por lo tanto, la partición se calcula en `ef_tau_sw_allen()` (§6.3)
  o se obtiene de un modelo de descomposición aplicado a radiación medida
  (§6.4.B), y se usa en `ef_rs_in_modelled()` para la corrección por
  pendiente y orientación.

---

## 2. Diagrama de dependencias

```text
 DEM ────────────────► elevation [m], slope [rad], aspect [rad]
 surface (MODIS…) ───► lst [K], emissivity [–], albedo [–],
                       overpass time per pixel → doy, utc_hour; lat, lon [rad]
 forcing / spatial ──► vapour_pressure [kPa], air_temperature [K],
 (estación o GWR)      pressure [kPa] (opcional), rs_measured [W m⁻²] (opcional)

            doy, utc_hour, lat, lon, slope, aspect
                         │
                         ▼
               ┌────────────────────┐
               │ ef_solar_geometry  │──► cos_zenith, cos_incidence,
               └────────────────────┘    inv_rel_distance (dr)
                         │
 elevation ─► ┌─────────────────┐        │
              │ ef_air_pressure │─► P ───┤ (o P medida desde forcing)
              └─────────────────┘        │
 vapour_pressure, turbidity ─────────────┤
                                         ▼
                           ┌──────────────────────────┐
                           │ ef_tau_sw_allen     │──► tau_beam, tau_diffuse,
                           └──────────────────────────┘    tau_sw (horizontal)
                              │                    │
         ┌────────────────────┘                    └───────────────┐
         ▼                                                         ▼
 ┌──────────────────┐  ◄── slope, albedo (ρ_g)            ┌────────────────────────────┐
 │ ef_rs_in_modelled  │                                     │ ef_atm_emissivity  │──► ε_a
 └──────────────────┘                                     └────────────────────────────┘
   (alternativa: ef_rs_in_measured                            │
    ◄── rs_measured, diffuse_fraction)          T (decisión RC-12) ──┤
         │                                                           ▼
         │ rs_in                                            ┌─────────────────┐
         │                                                  │ ef_rl_in  │
         │                                                  └─────────────────┘
         │                                                           │ rl_in
         │      lst, emissivity ─► ┌─────────────────┐               │
         │                         │ ef_rl_out │── rl_out      │
         │                         └─────────────────┘     │         │
         ▼                                                 ▼         ▼
 ┌───────────────────────────────────────────────────────────────────────┐
 │ ef_net_radiation(rs_in, albedo, rl_in, rl_out, emissivity)  ──► Rn    │
 └───────────────────────────────────────────────────────────────────────┘
```

Notas:

- Si se elige T = Ts del píxel frío para RL↓ (RC-12), aparece una
  dependencia del módulo de anclas **antes** de Rn: la selección del píxel
  frío debe hacerse sin usar Rn (solo Ts, NDVI, α, cobertura), y luego se
  calcula Rn en toda la escena. Debe documentarse en el orden de la cadena
  del pipeline.
- La fracción difusa que produce `ef_rs_in_modelled()` puede alimentar la
  combinación white-sky/black-sky del albedo en `surface` (SPEC §3, fila
  albedo: "blue-sky vs. white/black-sky", `TODO`). Es una dependencia
  opcional que no crea ciclo (α no interviene en la partición).

---

## 3. Tabla de entradas por módulo

Esta tabla hace explícito **dónde entra el forzamiento meteorológico
espacial** (GWR), es decir, dónde puede actuar la hipótesis H1
(SPEC §1.1, §1.2).

| Entrada | Símbolo | Unidad | Módulo de origen | Función que la usa | ¿Puede venir de GWR? | Comentario |
|---|---|---|---|---|---|---|
| Temperatura superficial | Ts | K | `surface` | `ef_rl_out()`; opción de T en `ef_rl_in()` | No | MODIS LST, por píxel; cielo despejado |
| Emisividad de banda ancha | ε₀ | – | `surface` | `ef_rl_out()`, `ef_net_radiation()` | No | Ver RC-14 |
| Albedo de banda ancha | α | – | `surface` | `ef_net_radiation()`; ρ_g en `ef_rs_in_modelled()` | No | |
| Hora de paso por píxel | doy, utc_hour | –, h | `surface` | `ef_solar_geometry()` | No | Desde el *view time* del producto (SPEC §2.4) |
| Latitud, longitud | φ, λ | rad | `surface` / grilla | `ef_solar_geometry()` | No | Centro de píxel en WGS84 |
| Elevación | z | m | DEM | `ef_air_pressure()`, `ef_tau_sw_elevation()` | No | Remuestreo coherente a la grilla (SPEC §2.2) |
| Pendiente, orientación | s, A | rad | DEM | `ef_solar_geometry()`, `ef_rs_in_modelled()` | No | Ver RC-02, RC-11 |
| Presión de vapor | eₐ | kPa | `forcing` / `spatial` | `ef_tau_sw_allen()` (vía W) | **Sí** | Efecto sobre Rs↓ pequeño pero espacial; ver §6.3 |
| Presión atmosférica | P | kPa | `forcing` / `spatial` **o** DEM vía `ef_air_pressure()` | `ef_tau_sw_allen()` | Derivable de z (SPEC §5) | RC-08 |
| Turbidez | K_t | – | parámetro de escena **o** `spatial` (calibrado con estaciones) | `ef_tau_sw_allen()` | **Sí** (opción híbrida, RC-10) | |
| Radiación global medida | Rs_meas | W m⁻² | `forcing` / `spatial` | `ef_rs_in_measured()` | **Sí** | Entrada fuerte de H1 en Rs↓; RC-10 |
| Fracción difusa | k_d | – | modelo de descomposición o modelado | `ef_rs_in_measured()` | Indirecta | `TODO` |
| Temperatura para RL↓ | T | K | `forcing` / `spatial` **o** `surface` / anclas | `ef_rl_in()` | **Sí**, solo si T = Ta | **Decisión RC-12**: es el punto donde el forzamiento espacial puede entrar en RL↓ |

Resumen para H1:

- **RL↓**: el forzamiento espacial entra **solo** si T = Ta (estación o
  GWR). Con T = Ts (píxel frío o por píxel) RL↓ no depende de la meteorología
  salvo vía eₐ → τ_sw → ε_a (efecto débil).
- **Rs↓**: entra débilmente vía eₐ (y P) en el camino modelado de cielo
  despejado; fuertemente si se usa radiación medida o turbidez calibrada
  (RC-10).
- La calibración interna (anclas) puede absorber parte de un sesgo
  **uniforme** de Rn en la escena; un sesgo con **patrón espacial** no es
  absorbible por dos anclas. Esto es una hipótesis de trabajo a evaluar,
  no un resultado.

---

## 4. Convenciones transversales

### 4.1 Unidades

| Magnitud | Unidad en el núcleo `ef_*()` | Nota |
|---|---|---|
| Temperaturas | K | Conversión desde °C en `forcing` (decisión K vs °C del contrato: `ARCHITECTURE.md` §4, `TODO`) |
| Presiones | kPa | eₐ y P |
| Flujos radiativos | W m⁻² | |
| Ángulos (φ, λ, s, A, δ, ω, θ) | **rad** (propuesta, RC-01) | |
| Tiempo | `doy` (1–366, día del año de la fecha **UTC**), `utc_hour` (h decimal, [0, 24)) | RC-03 |
| Elevación | m | |
| Agua precipitable W | mm | Variable interna de τ_sw |

### 4.2 Ángulos: radianes (decisión RC-01, recomendación)

Propuesta: **todos** los ángulos del núcleo en radianes, incluidas latitud y
longitud. Motivos:

- coherencia con el contrato de `surface` (`slope`, `aspect` en rad,
  `ARCHITECTURE.md` §4) y con `terra::terrain(..., unit = "radians")`;
- las funciones trigonométricas de R operan en radianes;
- **detección de errores de unidad en Chile**: |φ| en grados está entre ≈17
  y ≈56, siempre > π/2 ≈ 1.571, por lo que pasar grados por error produce un
  error de dominio clasificado. Lo mismo ocurre con la orientación en grados
  (casi siempre > 2π). Limitación: una pendiente pequeña en grados (p. ej.,
  1°) no se detecta; debe documentarse.

Alternativa: grados en latitud/longitud (convención geográfica) y radianes
en el resto. Se desaconseja por mezclar convenciones.

### 4.3 Orientación (aspect): convención (decisión RC-02)

- **Contrato de `surface`/DEM (propuesta):** convención SIG, la de
  `terra::terrain()`: A medido en sentido horario desde el norte geográfico,
  A ∈ [0, 2π) (0 = norte, π/2 = este, π = sur, 3π/2 = oeste).
- **Interno:** la ecuación de cos θ_rel candidata (§6.1) usa el ángulo
  azimutal de superficie γ con 0 = orientado al sur, este negativo, oeste
  positivo. Conversión: **γ = A − π**. La conversión se hace **dentro** de
  `ef_solar_geometry()` (no en el contrato), para que el usuario siempre
  entregue la convención SIG.
- Observado en `water` v1.0, función `METRICtopo()`: aplica el mismo
  desplazamiento (A − π) al construir el modelo de superficie. No verificado
  contra la fuente primaria.
- Celdas planas (s = 0): la orientación es indefinida; ver RC-16.

### 4.4 Tiempo y zona horaria (decisión RC-03)

- El núcleo recibe `doy` y `utc_hour` **numéricos** (no `POSIXct`) para que
  operen también sobre rásteres (la hora de paso varía por píxel en MODIS:
  SPEC §2.4).
- Un envoltorio (`surface`/`api`) convierte `POSIXct` → (`doy`, `utc_hour`)
  extrayendo siempre con `tz = "UTC"`. `POSIXct` almacena segundos UTC, por
  lo que la conversión es inequívoca; se rechazan entradas de tipo carácter
  (ambiguas respecto de la zona horaria) con error clasificado.
- `doy` es el día del año de la fecha **UTC** del instante. En Chile
  continental (UTC−3/−4) la pasada diurna de MODIS cae en la misma fecha UTC,
  pero el envoltorio debe tratar el cruce de medianoche UTC en general
  (test).
- **Hora de paso MODIS:** el producto LST entrega un *view time* por píxel.
  `TODO`: verificar en la guía de usuario (Wan, colección vigente) si es hora
  solar local **media** (UTC + λ/15 h) o **aparente** (incluye la ecuación
  del tiempo), su factor de escala y valor de relleno. Consecuencia:
  - si es hora solar media: utc_hour = t_solar − λ_deg/15 y se aplica la
    ecuación del tiempo en `ef_solar_geometry()`;
  - si es hora solar aparente: el ángulo horario sale directamente
    (ω = π/12·(t_solar − 12)) y aplicar la ecuación del tiempo **otra vez**
    sería un error. Alternativa de interfaz: aceptar `solar_hour` como
    entrada excluyente de (`utc_hour`, `lon`).

### 4.5 Vectorización y reciclado

- Todas las funciones aceptan vectores, matrices o arreglos numéricos.
- Regla de reciclado: cada argumento tiene largo 1 o el largo común n; otro
  largo → `earthflux_input_error`. Argumentos con `dim` deben compartir
  `dim`. Alinear con los helpers de validación previstos para
  `ef_net_radiation()` (en desarrollo: comprobación numérica, largo común,
  `dim` común y rango).
- Envoltorios ráster: las mismas funciones sobre `SpatRaster` (álgebra de
  `terra`), sin reimplementar (`ARCHITECTURE.md` §6.2).

### 4.6 NA

- `NA`/`NaN` en cualquier entrada → `NA` en la salida correspondiente
  (propagación aritmética natural). No se imputan ni se sustituyen.
- La validación de dominio ignora `NA` (no lanza error por `NA`).
- El flag `EF_INPUT_NA` (ya registrado) lo construye la capa de
  orquestación, no la función numérica.
- Excepción discutida: orientación `NA` en celdas planas (RC-16).

### 4.7 Errores clasificados

| Situación | Clase | Ejemplo |
|---|---|---|
| Tipo no numérico, largo incompatible, `dim` incompatible | `earthflux_input_error` | `lst = "300"` |
| Valor imposible (fuera del dominio físico) o infinito | `earthflux_domain_error` (subclase de `earthflux_input_error`) | `lst = -5`, `emissivity = 1.2`, `cos_zenith = 0` en τ_sw |
| Valor posible pero inusual | **flag** (no error, no corrección) | ε_a > 1 |

Ningún valor se trunca, recorta (*clamp*) ni corrige silenciosamente
(principio 6). Excepción **física**, no corrección: la irradiancia directa
sobre un plano autosombreado es 0 por definición (max(cos θ_rel, 0)); se
documenta y se marca con flag (§6.4).

### 4.8 Flags propuestos (no registrar todavía)

Se registran en `ef_flag_registry()` solo cuando la condición sea
inequívoca y esta especificación esté fusionada; los que requieren umbral
esperan su justificación (`R/diagnostics.R`).

| Código propuesto | Condición | Severidad | ¿Umbral? |
|---|---|---|---|
| `EF_SELF_SHADED` | cos θ_rel ≤ 0 con cos θ_h > 0 (plano de espaldas al sol) | info | No (inequívoca) |
| `EF_ATM_EMISSIVITY_GT1` | ε_a > 1 | warning | No (inequívoca) |
| `EF_RS_EXCEEDS_EXTRATERRESTRIAL` | Rs_meas > Gsc·dr·cos θ_h | warning | No (inequívoca) |
| `EF_LOW_SUN` | cos θ_h bajo un umbral (validez de τ_sw; mal condicionamiento de la proyección de Rs medida) | warning | **Sí** `TODO` |
| `EF_LST_IMPLAUSIBLE` | Ts fuera de un rango plausible (p. ej., detectar °C por error) | warning | **Sí** `TODO` |
| `EF_STATION_CLOUDY` | Rs_meas / Rso_modelada en la estación bajo un umbral | warning | **Sí** `TODO` |

---

## 5. Constantes

| Constante | Símbolo | Valor | Fuente | Estado |
|---|---|---|---|---|
| Constante de Stefan-Boltzmann | σ | 5.670374419 × 10⁻⁸ W m⁻² K⁻⁴ | Valores recomendados CODATA 2018; **exacto** en el SI revisado de 2019 (derivado de h, k y c, que son exactos). `TODO: verify full citation` (publicación CODATA/NIST) | Valor cierto; **adopción** pendiente (RC-07) |
| Constante de Stefan-Boltzmann (forma usada en literatura METRIC) | σ | 5.67 × 10⁻⁸ W m⁻² K⁻⁴ | Forma observada en `water` v1.0, funciones `outLWradiation()` e `incLWradiation()`. `TODO`: verificar el valor usado en Allen et al. (2007) | `CANDIDATA` (alternativa de reproducibilidad) |
| Constante solar | Gsc | 1367 W m⁻² (≈ 0.0820 MJ m⁻² min⁻¹ × 10⁶/60 = 1366.67 W m⁻²) | Forma observada en `water` v1.0, `incSWradiation()`; valor en MJ m⁻² min⁻¹ atribuido a FAO-56 (Allen et al., 1998) `TODO: verify equation/page` | `TODO` (RC-06) |
| Constante solar (TSI reciente) | Gsc | ≈ 1361 W m⁻² | Literatura reciente de irradiancia solar total `TODO: identificar fuente primaria` | `TODO` (RC-06) |
| Coeficientes de τ_b, τ_d, W | – | 0.98; 0.00146; 0.075; 0.4; 0.35; 0.36; 0.15; 0.18; 0.82; 0.14; 2.1 | Forma observada en `water` v1.0, `SWtransmissivity()`; fuente primaria citada allí: ASCE-EWRI (2005), Majumdar et al. (1972), Allen (1996) | `CANDIDATA` |
| Coeficientes de P(z) | – | 101.3; 293; 0.0065; 5.26 | Forma observada en `water` v1.0, `SWtransmissivity()`; atribuida en general a FAO-56 / ASCE-EWRI `TODO: verify equation number` | `CANDIDATA` |
| Coeficientes de ε_a | – | 0.85; 0.09 | Forma observada en `water` v1.0, `incLWradiation()`; fuente primaria citada allí: Bastiaanssen (1995) (forma) y Allen (2000, informe interno) (coeficientes) | `CANDIDATA` |
| Coeficientes de τ_sw simple | – | 0.75; 2 × 10⁻⁵ m⁻¹ | Forma atribuida a FAO-56 (Rso diaria de cielo despejado) `TODO: verify equation number` | `CANDIDATA` |
| Coeficientes geométricos (δ, dr, Sc) | – | 0.409; 1.39; 0.033; 0.1645; 0.1255; 0.025; 81; 364; 365 | Formas observadas en `water` v1.0, `solarAngles()` e `incSWradiation()`; atribuidas en general a FAO-56 `TODO: verify equation numbers` | `CANDIDATA` |

Regla de implementación: cada constante vive en **un único lugar** del
código (constante interna nombrada, con su referencia en roxygen), nunca
repetida como literal.

Sensibilidad a σ (cálculo propio): con ε₀ = 0.98 y Ts = 300 K,
0.98·σ·Ts⁴ = 450.1143 W m⁻² (σ exacto) frente a 450.0846 W m⁻² (5.67e-8);
diferencia 0.0297 W m⁻² (6.6 × 10⁻⁵ relativo). Irrelevante físicamente,
pero relevante para tests de reproducción contra casos publicados.

---

## 6. Funciones

Orden de presentación: por dependencia (geometría → presión →
transmisividad → onda corta → onda larga entrante → onda larga emitida).
Los nombres son propuestas.

### 6.1 `ef_solar_geometry()` y auxiliares geométricas

**Propósito.** Calcular, para cada píxel y su hora de paso, el coseno del
ángulo cenital (incidencia sobre horizontal), el coseno del ángulo de
incidencia sobre el plano inclinado del píxel y la inversa de la distancia
relativa Tierra-Sol.

**Interfaz propuesta.**

```text
ef_solar_geometry(doy, utc_hour, lat, lon, slope = 0, aspect = 0)
  → list(cos_zenith, cos_incidence, declination, hour_angle, inv_rel_distance)
```

Auxiliares internas (no exportadas, testeadas por separado; RC-05):
`ef_declination(doy)`, `ef_inv_distance(doy)`,
`ef_equation_of_time(doy)`, `ef_hour_angle(doy, utc_hour, lon)`,
`ef_cos_incidence(lat, declination, hour_angle, slope, aspect)`.

**Ecuaciones candidatas** (`CANDIDATA`; formas observadas en `water` v1.0,
función `solarAngles()` e `incSWradiation()`; fuente citada allí: Allen et
al., 2007; las formas de δ, dr y Sc coinciden con las que se atribuyen
habitualmente a FAO-56; `TODO: verify equation numbers` en Allen et al.,
1998, y en Allen et al., 2007):

```text
Declinación solar:            δ  = 0.409 · sin(2π·J/365 − 1.39)                [rad]
Inversa de distancia relativa: dr = 1 + 0.033 · cos(2π·J/365)                   [–]
Ecuación del tiempo:          b  = 2π·(J − 81)/364
                              Sc = 0.1645·sin(2b) − 0.1255·cos(b) − 0.025·sin(b) [h]
Hora solar:                   t_s = utc_hour + λ·(12/π) + Sc                    [h]
                              (λ en rad, positiva al este; equivale a λ_deg/15)
Ángulo horario:               ω  = (π/12)·(t_s − 12)          (negativo en la mañana) [rad]
Coseno cenital (horizontal):  cos θ_h = sin δ·sin φ + cos δ·cos φ·cos ω
Coseno de incidencia (plano inclinado), con γ = A − π:
  cos θ_rel = sin δ·sin φ·cos s
            − sin δ·cos φ·sin s·cos γ
            + cos δ·cos φ·cos s·cos ω
            + cos δ·sin φ·sin s·cos γ·cos ω
            + cos δ·sin γ·sin s·sin ω
```

La forma de cos θ_rel es la del ángulo de incidencia sobre una superficie de
orientación arbitraria que aparece en textos de ingeniería solar (fuente
candidata: Duffie & Beckman, *Solar Engineering of Thermal Processes*,
`TODO: verify full citation, edition and equation number`; no figura en
`REFERENCES.md`). `TODO`: identificar qué fuente primaria cita Allen et al.
(2007) para su ecuación de cos θ_rel y verificar que la convención de γ
coincide (los comentarios de `water` la refieren como "Eq. 7" de Allen et
al., 2007; no verificado).

Con s = 0, cos θ_rel se reduce a cos θ_h (identidad algebraica: test).

**Entradas.**

| Argumento | Unidad | Dominio | Fuente |
|---|---|---|---|
| `doy` | – | entero 1–366 | `surface` (fecha UTC de la hora de paso) |
| `utc_hour` | h | [0, 24) | `surface` (view time → UTC, §4.4) |
| `lat` | rad | [−π/2, π/2] | grilla (centro de píxel, WGS84) |
| `lon` | rad | [−π, π] (positiva al este) | grilla |
| `slope` | rad | [0, π/2] | DEM |
| `aspect` | rad | [0, 2π) (SIG: horario desde el norte) | DEM |

**Constantes.** Las de la fila "coeficientes geométricos" (§5).

**Supuestos.** Fórmulas aproximadas de baja precisión (adecuadas para
estimación de ET según la literatura FAO, `TODO: cuantificar error frente a
un algoritmo de efemérides de mayor precisión`); año de 365 días en las
fórmulas también en años bisiestos (`TODO`: verificar tratamiento de
J = 366 en la fuente); refracción atmosférica ignorada; solo
**autosombreado** (sin sombras proyectadas por el relieve vecino, §11).

**Dominio y comportamiento fuera de él.** Valores fuera de los intervalos de
la tabla → `earthflux_domain_error`. `doy` no entero → `earthflux_input_error`.
Salidas: cos θ_h, cos θ_rel ∈ [−1, 1]; valores ≤ 0 se devuelven tal cual
(el tratamiento corresponde a las funciones consumidoras).

**NA.** Propaga. Ver RC-16 para `aspect` NA con `slope = 0`.

**Estado.** `CANDIDATA` (todas las formas). Precisión y alternativa de mayor
exactitud: `TODO` (RC-04). Alternativa candidata de mayor precisión para δ:
series de Fourier (p. ej., la atribuida a Spencer, 1971,
`TODO: verify full citation`; no figura en `REFERENCES.md`).

**Referencias.** Allen et al. (1998) FAO-56 `TODO: verify equation numbers`;
Allen, Tasumi & Trezza (2007) `TODO: verify equation numbers`; Allen,
Trezza & Tasumi (2006) `TODO`; Duffie & Beckman `TODO` (no en
`REFERENCES.md`).

**Caso numérico verificable** (calculado a mano).

*G1 — superficie normal al sol (prueba de convenciones de signo).* φ = −35°
= −0.6108652 rad, δ = 0 (equinoccio), ω = 0 (mediodía solar), s = 35° =
0.6108652 rad, orientación norte A = 0 → γ = −π.
sin δ = 0 anula los dos primeros términos; cos δ = 1, cos ω = 1, sin ω = 0:

```text
cos θ_rel = cos φ·cos s + sin φ·sin s·cos γ
          = cos(35°)·cos(35°) + sin(−35°)·sin(35°)·(−1)
          = cos²(35°) + sin²(35°) = 1   (exacto)
```

En el hemisferio sur, una ladera orientada al norte con pendiente igual a
|φ| recibe el sol perpendicular al mediodía del equinoccio. El resultado
debe ser idéntico con A = 0 y con A → 2π (γ = ±π).

*G2 — ladera al sur.* Igual que G1 con A = π → γ = 0:
cos θ_rel = cos²(35°) − sin²(35°) = cos(70°) = 0.3420201.

*G3 — horizontal.* s = 0: cos θ_rel = cos θ_h = cos(35°) = 0.8191520.

*G4 — simetría este/oeste.* φ = −35°, δ = 0.2 rad, s = 20°: ladera al este
(A = π/2) con ω = −30° y ladera al oeste (A = 3π/2) con ω = +30° dan el
mismo cos θ_rel (0.7138573, cálculo propio).

*G5 — ángulo horario.* J = 81: b = 0 → Sc = −0.1255 h. Con utc_hour = 16.8 h
y λ = −72° (λ_deg/15 = −4.8 h): t_s = 16.8 − 4.8 − 0.1255 = 11.8745 h;
ω = (π/12)·(11.8745 − 12) = −0.0328558 rad.

*G6 — valores de calendario.* δ(J = 172) = 0.4090 rad (máximo, solsticio
de junio); δ(J = 355) = −0.40898 rad; dr(J = 1) = 1 + 0.033·cos(2π/365) =
1.0329951; dr(J = 182) = 0.9670012.

**Tests planificados** (`tests/testthat/test-radiation.R` o
`test-solar-geometry.R`, a decidir):

- G1–G6 con tolerancia del orden de `sqrt(.Machine$double.eps)` (identidades
  algebraicas, sin constantes redondeadas).
- Identidad cos θ_rel(s = 0) = cos θ_h para una grilla de (φ, δ, ω).
- Simetría este/oeste (G4) sobre una grilla de ω.
- Simetría hemisférica (reflexión norte-sur): (φ, δ, A) ↔ (−φ, −δ,
  (π − A) mod 2π) da el mismo cos θ_rel (comprobado numéricamente por el
  autor; la reflexión intercambia norte y sur y conserva este y oeste; la
  transformación A + π **no** es una simetría y no debe usarse).
- Ladera al norte en el hemisferio sur > horizontal > ladera al sur al
  mediodía (propiedad cualitativa).
- Latitud en grados por error (p. ej., −35) → `earthflux_domain_error`.
- `doy` no entero, fuera de 1–366 → error clasificado.
- `NA` en cualquier entrada → `NA` en las salidas afectadas.
- Comparación contra un valor de efemérides independiente para 2–3 fechas
  `TODO` (identificar fuente y justificar tolerancia por la aproximación).

**Decisiones abiertas.** RC-01, RC-02, RC-03, RC-04, RC-05, RC-16.

---

### 6.2 `ef_air_pressure()`

**Propósito.** Presión atmosférica a partir de la elevación, cuando no hay
presión medida o regionalizada. Es insumo de τ_sw (y, fuera de este
documento, de ρ_air y de la constante psicrométrica de ETr).

**Interfaz propuesta.** `ef_air_pressure(elevation)` → P [kPa].
**Implementada (2026-11-04)** en `R/shared-physics.R` (RC-17, archivo
compartido), exportada.

**Ecuación** (`VERIFICADA` 2026-11-04: idéntica a FAO-56, Cap. 3, Ec. 7,
leída en la edición abierta de FAO; ver `weather-forcing.md` §4; también
observada en `water` v1.0, función `SWtransmissivity()`):

```text
P = 101.3 · ((293 − 0.0065·z) / 293)^5.26          [kPa], z en m
```

**Entradas.** `elevation` z [m], desde DEM.

**Supuestos.** Atmósfera estándar con temperatura de referencia 293 K y
gradiente térmico constante (`TODO`: verificar en la fuente qué supuestos
declara). No representa variaciones sinópticas de presión.

**Dominio.** La base debe ser positiva: 293 − 0.0065·z > 0 ⇔ z < 45 076.9 m;
fuera → `earthflux_domain_error` (imposible). Rango plausible de z para
el área de estudio (p. ej., bajo el nivel del mar o sobre cumbres andinas) →
flag con umbral `TODO`; no error.

**NA.** Propaga.

**Estado.** `VERIFICADA` (FAO-56 Ec. 7). Supuestos según FAO-56 Anexo 3
(Ec. 3-2): 9.807/(0.0065·287) = 5.257 ≈ 5.26.

**Referencias.** Allen et al. (1998) FAO-56, Cap. 3, Ec. 7; ASCE-EWRI (2005)
`TODO` (sin acceso).

**Caso numérico.** z = 0 → P = 101.3 kPa (exacto). z = 1000 m:
(293 − 6.5)/293 = 0.9778157; 0.9778157^5.26 = 0.8886932;
P = 101.3 × 0.8886932 = 90.0246 kPa. z = 3000 m → P = 70.5150 kPa.

**Tests planificados.** Valores anteriores; monotonía decreciente; z = 50 000
→ error clasificado; `NA` propaga.

**Decisiones abiertas.** RC-08 (P medida/GWR vs derivada de z), RC-17
(ubicación de la función, compartida con ETr y H).

---

### 6.3 `ef_tau_sw_allen()` y `ef_tau_sw_elevation()`

**Propósito.** Transmisividad atmosférica de banda ancha para onda corta, de
cielo despejado, **sobre superficie horizontal**, separada en componente
directa (τ_b) y difusa (τ_d). τ_sw = τ_b + τ_d alimenta también ε_a (§6.5).

Se proponen **dos funciones** en lugar de un argumento `method` cuyo
conjunto de entradas obligatorias cambie según el método (firmas honestas,
tests separados).

#### A. Forma tipo ASCE-EWRI, particionada — `ef_tau_sw_allen()`

**Interfaz propuesta.**

```text
ef_tau_sw_allen(cos_zenith, pressure, vapour_pressure, turbidity = 1)
  → list(beam = τ_b, diffuse = τ_d, total = τ_sw)
```

**Ecuaciones candidatas** (`CANDIDATA`; forma observada en `water` v1.0,
función `SWtransmissivity()`; fuente primaria citada allí: "ecuación
extendida desarrollada por Allen (1996), basada en Majumdar et al. (1972),
con coeficientes de ASCE-EWRI (2005)"; no verificada):

```text
Agua precipitable:  W   = 0.14 · eₐ · P + 2.1                                [mm]
Directa:            τ_b = 0.98 · exp[ −0.00146·P / (K_t · cos θ_h)
                                      − 0.075 · (W / cos θ_h)^0.4 ]           [–]
Difusa:             τ_d = 0.35 − 0.36·τ_b     si τ_b ≥ 0.15
                    τ_d = 0.18 + 0.82·τ_b     si τ_b < 0.15                  [–]
Total:              τ_sw = τ_b + τ_d
```

Observaciones registradas:

- En `water` hay comentada una variante τ_sw = 0.35 + 0.627·exp(...)
  atribuida allí a "METRIC 2007" (la activa, a "METRIC 2010"). Para
  τ_b ≥ 0.15 ambas son algebraicamente equivalentes salvo redondeo:
  0.35 − 0.36·τ_b + τ_b = 0.35 + 0.64·τ_b = 0.35 + 0.6272·exp(...). Cálculo
  propio con el caso T1: 0.35 + 0.6272·0.6620118 = 0.7652138 = τ_sw.
  `TODO`: identificar a qué documento se refiere "METRIC 2010" (no figura en
  `REFERENCES.md`).
- La línea comentada en `water` difiere además en la precedencia de
  operadores del primer término del exponente. Motivo adicional para **no
  transcribir ecuaciones desde código**: se transcriben desde la fuente
  primaria.
- La función por tramos de τ_d es **discontinua** en τ_b = 0.15:
  0.35 − 0.36·0.15 = 0.296 frente a 0.18 + 0.82·0.15 = 0.303 (salto 0.007).
  `TODO`: verificar en ASCE-EWRI si los coeficientes son exactamente estos
  y si la discontinuidad es intencional.
- `turbidity` K_t (no confundir con el índice de claridad Rs/Ra, a menudo
  también llamado K_t; por eso el argumento se llama `turbidity`): según la
  documentación de `water`, 1 para aire limpio y 0.5 para aire
  extremadamente turbio, polvoriento o contaminado. `TODO: verify` en
  ASCE-EWRI / Allen et al. (2007).
- Se evalúa con cos θ_h (ángulo sobre la **horizontal**), no con cos θ_rel:
  la masa de aire atravesada no depende de la pendiente del píxel. Así lo
  hace `water` (argumento `incidence.hor`).

**Entradas.**

| Argumento | Unidad | Dominio | Fuente |
|---|---|---|---|
| `cos_zenith` | – | (0, 1] | `ef_solar_geometry()` |
| `pressure` | kPa | (0, ∞) | `ef_air_pressure()` o `forcing`/`spatial` |
| `vapour_pressure` | kPa | [0, ∞) | `forcing`/`spatial` (**GWR**) |
| `turbidity` | – | (0, 1] | parámetro de escena o superficie calibrada (RC-10) |

**Supuestos.** Cielo despejado (coherente con píxeles válidos de MODIS LST,
que son de cielo despejado); coeficientes derivados para condiciones de
EE. UU. (`TODO`: verificar el contexto de calibración y su transferibilidad
a Chile, en especial a gran altitud en los Andes); aplicación
**instantánea** de coeficientes posiblemente desarrollados para pasos
horarios/diarios (`TODO`: verificar en ASCE-EWRI); validez a ángulos solares
bajos `TODO`.

**Dominio y comportamiento fuera de él.**
- cos θ_h ≤ 0 (sol bajo el horizonte): la ecuación se indefine (división por
  cos θ_h) → `earthflux_domain_error`. En una pasada diurna indica hora o
  coordenadas erróneas; no se devuelve 0 silenciosamente.
- P ≤ 0, eₐ < 0, K_t ∉ (0, 1] → `earthflux_domain_error`.
- cos θ_h pequeño pero positivo → flag `EF_LOW_SUN` (umbral `TODO`).

**NA.** Propaga a las tres salidas.

**Estado.** `CANDIDATA`.

**Referencias.** ASCE-EWRI (2005) `TODO: verify equation numbers and
coefficients`; Allen, Tasumi & Trezza (2007) `TODO: verify which τ_sw form
is used`; Majumdar et al. (1972) y Allen (1996) — citadas por `water`, **no
figuran en `REFERENCES.md`**, `TODO: identify and verify`.

**Caso numérico verificable T1** (calculado a mano). P = 101.3 kPa (z = 0),
eₐ = 1.5 kPa, cos θ_h = 1, K_t = 1.

```text
W        = 0.14·1.5·101.3 + 2.1         = 21.273 + 2.1 = 23.373 mm
W^0.4    = exp(0.4·ln 23.373)           = 3.5276524
término1 = 0.00146·101.3 / (1·1)        = 0.1478980
término2 = 0.075·3.5276524              = 0.2645739
exp(−(0.1478980 + 0.2645739)) = exp(−0.4124719) = 0.6620118
τ_b      = 0.98·0.6620118               = 0.6487715
τ_d      = 0.35 − 0.36·0.6487715         = 0.1164422   (rama τ_b ≥ 0.15)
τ_sw     = 0.7652138
```

**Caso T2.** Igual que T1 con cos θ_h = cos(35°) = 0.8191520:
W/cos θ_h = 28.5331645; (·)^0.4 = 3.8206739; término1 = 0.1805501;
término2 = 0.2865505; τ_b = 0.6142806; τ_d = 0.1288590; τ_sw = 0.7431396.

**Caso T3 (Andes).** z = 3000 m → P = 70.5150 kPa; eₐ = 0.5 kPa;
cos θ_h = cos(35°): W = 7.0360 mm; τ_b = 0.7238591; τ_d = 0.0894107;
τ_sw = 0.8132698.

**Tests planificados.** T1–T3 (tolerancia justificada por redondeo de los
valores intermedios mostrados, p. ej. 1e-6 relativo, o identidad si se
recalculan sin redondeo); ambas ramas de τ_d y el punto τ_b = 0.15 (que la
rama elegida sea la documentada); monotonía: τ_b decrece con eₐ, con P y con
el ángulo cenital, crece con K_t; cos θ_h = 0 y negativo → error clasificado;
K_t = 0 y K_t > 1 → error; `NA` propaga; τ_b < 0.98 siempre.

#### B. Forma simple por elevación — `ef_tau_sw_elevation()`

**Interfaz propuesta.** `ef_tau_sw_elevation(elevation)` →
τ_sw [–] (solo total).

**Ecuación candidata** (`CANDIDATA`; forma atribuida a FAO-56 para la
radiación de cielo despejado Rso = (0.75 + 2·10⁻⁵·z)·Ra, `TODO: verify
equation number`; `TODO`: verificar si Allen et al., 2007, la usa para
Rs↓ instantánea):

```text
τ_sw = 0.75 + 2 × 10⁻⁵ · z          z en m
```

**Limitaciones (decisivas).** No depende del ángulo solar ni de eₐ; fue
planteada para radiación **diaria**; **no entrega partición** directa/difusa,
por lo que **no permite** la corrección topográfica de §6.4 sin suponer una
partición fija (no se propone). Uso previsto: terreno plano, análisis de
sensibilidad y reproducción de casos publicados que la usen.

**Dominio.** z tal que τ_sw ∈ (0, 1): z < 12 500 m (τ_sw < 1) y
z > −37 500 m; fuera → `earthflux_domain_error`. `NA` propaga.

**Caso numérico.** z = 0 → 0.75; z = 3000 → 0.81 (comparar con T3: 0.8133
con la forma A para eₐ = 0.5 kPa y θ_h = 35°; coincidencia numérica de este
caso, no equivalencia general).

**Tests planificados.** Valores anteriores; linealidad; error fuera de
dominio; `NA`.

**Decisiones abiertas.** RC-08, RC-10.

---

### 6.4 `ef_rs_in_modelled()` y `ef_rs_in_measured()`

**Propósito.** Irradiancia de onda corta instantánea Rs↓ sobre el plano del
píxel a la hora de paso, con corrección por pendiente y orientación
separando directa, difusa y reflejada por el terreno.

Diseño: separar (a) la obtención de las componentes **horizontales**
(modeladas de cielo despejado o medidas + descomposición) de (b) su
**proyección al plano inclinado**. La proyección es un núcleo común interno
(`ef_rs_to_slope()`, no exportado) que usan ambos caminos.

#### A. Camino modelado de cielo despejado — `ef_rs_in_modelled()`

**Interfaz propuesta.**

```text
ef_rs_in_modelled(cos_zenith, cos_incidence, inv_rel_distance,
                tau_beam, tau_diffuse, slope = 0, ground_albedo = NULL)
  → list(total, beam, diffuse, reflected, diffuse_fraction)    [W m⁻²; – ]
```

`total` es el `rs_in` de `ef_net_radiation()`. Las componentes se devuelven
como diagnóstico y para el albedo blue-sky (§2). Tipo de retorno: RC-15.

**Ecuaciones candidatas.**

Término extraterrestre instantáneo sobre horizontal (`CANDIDATA`):

```text
R_a,h = Gsc · dr · cos θ_h                                       [W m⁻²]
```

Componentes horizontales:

```text
R_b,h = τ_b · R_a,h        R_d,h = τ_d · R_a,h
```

Proyección al plano inclinado (`CANDIDATA` en la forma; modelo de difusa
`TODO`, RC-09):

```text
Directa:   R_b,s = τ_b · Gsc · dr · max(cos θ_rel, 0)
                 (= R_b,h · max(cos θ_rel, 0) / cos θ_h)
Difusa:    R_d,s = R_d,h · F_sky,     F_sky = (1 + cos s) / 2     (cielo isotrópico, plano sin obstrucciones)
Reflejada: R_r,s = ρ_g · (R_b,h + R_d,h) · (1 − cos s) / 2        (suelo isotrópico)
Total:     Rs↓   = R_b,s + R_d,s + R_r,s
Fracción difusa (horizontal): k_d = R_d,h / (R_b,h + R_d,h) = τ_d / τ_sw
```

- Con s = 0: Rs↓ = Gsc·dr·cos θ_h·τ_sw (identidad: test). Esta es la forma
  plana.
- F_sky = (1 + cos s)/2 y el término reflejado con (1 − cos s)/2 son las
  formas isotrópicas estándar para un plano inclinado sin horizonte
  obstruido (fuente candidata: textos de ingeniería solar, Duffie & Beckman
  `TODO`; formulación isotrópica atribuida a Liu y Jordan `TODO: identify
  primary reference`; ninguna figura en `REFERENCES.md`).
- `TODO` (crítico): verificar si Allen, Trezza & Tasumi (2006) prescriben un
  tratamiento **anisotrópico** de la difusa (p. ej., una fracción
  circunsolar que sigue a cos θ_rel) y su forma para uso instantáneo; y qué
  forma usa Allen et al. (2007) para Rs↓ en pendientes.
- max(cos θ_rel, 0): un plano de espaldas al sol no recibe radiación
  directa. Es la definición física de la irradiancia directa sobre ese
  plano, no una corrección; se marca con `EF_SELF_SHADED`.
- ρ_g: albedo del terreno circundante. Por defecto propuesto: el albedo del
  propio píxel (simplificación habitual) o un promedio de vecindario
  (RC-09). Si `ground_albedo = NULL` y `slope > 0` → error clasificado
  (no se supone un valor por defecto silencioso); con `slope = 0` el término
  es nulo y no se requiere.

**Forma simplificada observada** (para comparación, no propuesta como
defecto): Rs↓ = Gsc·cos θ_rel·τ_sw·dr, con τ_sw evaluada con θ_h y cos θ_rel
llevado a 0 cuando es negativo. Forma observada en `water` v1.0, función
`incSWradiation()`; fuente citada allí: Allen et al. (2007), `TODO: verify
equation number` (los comentarios de `water` la refieren como "Eq. 3" en la
función `Crad()`). Esta forma aplica cos θ_rel también a la componente
difusa (la trata como si fuera directa): en terreno plano coincide con la
forma particionada; en pendiente no. Casos S2–S4 cuantifican la diferencia.

**Entradas.**

| Argumento | Unidad | Dominio | Fuente |
|---|---|---|---|
| `cos_zenith` | – | (0, 1] | `ef_solar_geometry()` |
| `cos_incidence` | – | [−1, 1] | `ef_solar_geometry()` |
| `inv_rel_distance` | – | (0.9, 1.1) aprox.; dominio físico `TODO` | `ef_solar_geometry()` |
| `tau_beam`, `tau_diffuse` | – | [0, 1), τ_b + τ_d < 1 | `ef_tau_sw_allen()` |
| `slope` | rad | [0, π/2] | DEM |
| `ground_albedo` | – | [0, 1] | `surface` |

**Constantes.** Gsc (RC-06).

**Supuestos.** Cielo despejado; plano sin obstrucción del horizonte (sin
sombras proyectadas ni reducción del factor de visión del cielo por el
relieve vecino); difusa isotrópica (si se adopta); hora de paso
instantánea.

**Dominio y comportamiento fuera de él.** cos θ_h ≤ 0 → error clasificado
(coherente con §6.3). τ_b + τ_d ≥ 1 o negativos → error. ρ_g ∉ [0, 1] →
error. Rs↓ resultante no se recorta.

**NA.** Propaga a todas las salidas.

**Estado.** Forma plana `CANDIDATA`; proyección a pendiente `CANDIDATA` en
la forma isotrópica, `TODO` en la elección del modelo de difusa y su
verificación contra Allen et al. (2006).

**Referencias.** Allen, Tasumi & Trezza (2007) `TODO`; Allen, Trezza &
Tasumi (2006) `TODO`; ASCE-EWRI (2005) `TODO`; Duffie & Beckman `TODO`
(no en `REFERENCES.md`).

**Casos numéricos verificables** (calculados a mano; Gsc = 1367 W m⁻²
usado **solo** como valor de prueba mientras RC-06 está abierta; dr = 1;
τ_b, τ_d del caso T2; ρ_g = 0.2 como valor de prueba, no como
recomendación).

*S1 — plano.* cos θ_h = 0.8191520: R_a,h = 1367·0.8191520 = 1119.7808;
R_b,h = 1119.7808·0.6142806 = 687.8597; R_d,h = 1119.7808·0.1288590 =
144.2938; Rs↓ = 832.1535 W m⁻². k_d = 0.1734.

*S2 — ladera norte 35° normal al sol* (geometría G1: cos θ_rel = 1,
cos θ_h = cos 35°, s = 35°): F_sky = 0.9095760, (1 − cos s)/2 = 0.0904240.

```text
R_b,s = 0.6142806·1367·1         = 839.7216
R_d,s = 144.2938·0.9095760       = 131.2462
R_r,s = 0.2·832.1535·0.0904240   =  15.0493
Rs↓   = 986.0172 W m⁻²      (forma simplificada: 1367·1·0.7431396 = 1015.8719)
```

*S3 — ladera sur 35°* (G2: cos θ_rel = 0.3420201): R_b,s = 287.2017;
R_d,s = 131.2462; R_r,s = 15.0493; Rs↓ = 433.4972 W m⁻² (simplificada:
347.4486).

*S4 — ladera sur 60° autosombreada* (φ = −35°, δ = 0, ω = 0, A = π,
s = 60°: cos θ_rel = cos(95°) = −0.0871557): R_b,s = 0 (flag
`EF_SELF_SHADED`); F_sky = 0.75 → R_d,s = 108.2204; (1 − cos s)/2 = 0.25 →
R_r,s = 41.6077; Rs↓ = 149.8280 W m⁻² (simplificada: 0).

Lectura: en laderas andinas la elección entre la forma particionada y la
simplificada cambia Rs↓ en decenas a cientos de W m⁻²; el caso S4 muestra
que la forma simplificada anula la difusa en laderas autosombreadas.

**Tests planificados.** S1–S4; identidad s = 0 → forma plana; R_b,s = 0 y
flag cuando cos θ_rel ≤ 0; conservación: con ρ_g = 0 y s → 0, total →
R_b,h + R_d,h; `ground_albedo = NULL` con `slope > 0` → error; cos θ_h ≤ 0 →
error; `NA` propaga; envoltorio ráster = vector (mismo resultado).

#### B. Camino con radiación medida — `ef_rs_in_measured()` (alternativa)

**Propósito.** Usar Rs global **medida** sobre horizontal (piranómetro de
estación, puntual, o superficie regionalizada por GWR) en lugar del valor
modelado de cielo despejado, y proyectarla al plano del píxel.

**Interfaz propuesta.**

```text
ef_rs_in_measured(rs_horizontal, diffuse_fraction, cos_zenith,
                         cos_incidence, slope = 0, ground_albedo = NULL)
  → list(total, beam, diffuse, reflected)
```

**Ecuaciones.** R_b,h = (1 − k_d)·Rs_meas; R_d,h = k_d·Rs_meas; luego la misma
proyección de A (R_b,s = R_b,h·max(cos θ_rel, 0)/cos θ_h).

**El problema central: k_d.** Una medición de Rs global no informa la
partición. Opciones (todas `TODO`):

1. k_d del modelo de cielo despejado (τ_d/τ_sw de §6.3): coherente solo si
   el cielo está efectivamente despejado; en ese caso Rs_meas ≈ Rso y la
   ganancia frente al camino A es corregir sesgos de turbidez.
2. Modelo empírico de descomposición k_d = f(índice de claridad Rs/R_a,h)
   (existen en la literatura de radiación solar; `TODO: identify primary
   references`, ninguna en `REFERENCES.md`). Escalar ambas componentes por
   Rs_meas/Rso **no** es aceptable sin justificación: las nubes aumentan la
   fracción difusa.
3. Híbrido (ver RC-10): usar Rs_meas en estaciones solo para **calibrar
   K_t** (escalar de escena o superficie GWR de K_t) y mantener el camino A.
   Requiere invertir τ_sw(K_t) numéricamente (`TODO`); K_t invertido > 1 →
   flag de inconsistencia, no recorte.

**Problemas a documentar.** Representatividad temporal (las estaciones
registran promedios de 10–60 min, no instantáneos: interpolación a la hora
de paso en `forcing`); representatividad espacial (estaciones en fondos de
valle, sensor horizontal); nubosidad local en la estación mientras el
píxel MODIS está despejado (o al revés) → QC con Rs_meas/Rso
(`EF_STATION_CLOUDY`, umbral `TODO`); mal condicionamiento de la proyección
de la directa cuando cos θ_h es pequeño (`EF_LOW_SUN`); Rs_meas > R_a,h →
`EF_RS_EXCEEDS_EXTRATERRESTRIAL`.

**Relación con ETr.** La ETr estandarizada ASCE-EWRI usa Rs medida. Si Rn
usa Rs modelada y ETr usa Rs medida (o al revés), la cadena mezcla fuentes;
debe decidirse y registrarse (relación con la decisión 5.1 de SPEC).

**Estado.** `TODO` (depende de k_d).

**Tests planificados** (cuando se resuelva k_d): con k_d = τ_d/τ_sw y
Rs_meas = Rso modelada, reproduce exactamente el camino A (test de
consistencia entre caminos); Rs_meas negativa → error; `NA` propaga.

**Decisiones abiertas.** RC-06, RC-09, RC-10, RC-11, RC-15.

---

### 6.5 `ef_atm_emissivity()` y `ef_rl_in()`

Se separa la emisividad atmosférica efectiva (empírica, con alternativas)
de la ley de Stefan-Boltzmann (forma física), para poder sustituir una sin
tocar la otra.

#### A. `ef_atm_emissivity(tau_sw)`

**Propósito.** Emisividad efectiva de la atmósfera ε_a a partir de la
transmisividad de onda corta.

**Ecuación candidata** (`CANDIDATA`; forma observada en `water` v1.0,
función `incLWradiation()`; fuente primaria citada allí: forma empírica de
Bastiaanssen (1995) con coeficientes de Allen (2000), informe interno de la
Universidad de Idaho; ninguna de las dos figura en `REFERENCES.md`;
`TODO: verify` también contra Allen et al., 2007):

```text
ε_a = 0.85 · (−ln τ_sw)^0.09                        [–]
```

**Entrada.** `tau_sw` [–]: la transmisividad **total, horizontal, de cielo
despejado** de `ef_tau_sw_allen()`. No la transmisividad efectiva
medida (Rs_meas/R_a,h) salvo decisión explícita (RC-13): la relación
empírica se planteó para cielo despejado (`TODO: verify`), y bajo nubes la
onda larga entrante aumenta, mientras que esta fórmula con τ efectiva baja
daría también ε_a mayor, pero sin base de calibración.

**Dominio.** τ_sw ∈ (0, 1) abierto: τ_sw = 1 → ε_a = 0 (no físico);
τ_sw ≤ 0 → logaritmo indefinido. Fuera → `earthflux_domain_error`.
ε_a > 1 ocurre si −ln τ_sw > (1/0.85)^(1/0.09), es decir τ_sw < 0.0022776
(cálculo propio): flag `EF_ATM_EMISSIVITY_GT1`, sin recorte. Rango de τ_sw
en que se calibraron los coeficientes: `TODO`.

**NA.** Propaga.

**Caso numérico.** τ_sw = 0.75: −ln 0.75 = 0.2876821; 0.2876821^0.09 =
exp(0.09·ln 0.2876821) = 0.8939272; ε_a = 0.85·0.8939272 = 0.7598381.
Otros valores (cálculo propio): τ_sw = 0.5 → 0.8224; 0.7 → 0.7747;
0.8 → 0.7427; 0.9 → 0.6942 (ε_a decrece con τ_sw: test de monotonía).

**Alternativas candidatas** (`TODO`, sin coeficientes hasta identificar
fuentes): formulaciones de emisividad atmosférica de cielo despejado en
función de eₐ y Ta (familia de ecuaciones de tipo Brutsaert; Brutsaert,
1982, figura en `REFERENCES.md` bajo resistencia aerodinámica,
`TODO: verify` si contiene esa formulación). Interés para H1: serían
funciones directas del forzamiento (eₐ, Ta) regionalizable por GWR.

#### B. `ef_rl_in(temperature, atm_emissivity)`

**Propósito.** Onda larga entrante RL↓ en la superficie.

**Ecuación candidata** (`CANDIDATA`; ley de Stefan-Boltzmann aplicada a la
atmósfera con emisividad efectiva; forma observada en `water` v1.0,
`incLWradiation()`; fuente citada allí: Allen et al., 2007, `TODO: verify
equation number`):

```text
RL↓ = ε_a · σ · T⁴                                  [W m⁻²]
```

**Entradas.**

| Argumento | Unidad | Dominio | Fuente |
|---|---|---|---|
| `temperature` | K | (0, ∞) | **Decisión RC-12** (ver abajo) |
| `atm_emissivity` | – | (0, ∞); > 1 flag | `ef_atm_emissivity()` u otra |

La función es **agnóstica** respecto de qué temperatura se pasa: la
elección es de configuración (pipeline), queda registrada en la
procedencia del resultado y permite comparar opciones sin cambiar código.

**Constante.** σ (RC-07).

**Supuestos.** Atmósfera tratada como cuerpo gris con temperatura efectiva
T y emisividad efectiva ε_a; cielo despejado; instantáneo.

**Dominio.** T ≤ 0 K o no finita → `earthflux_domain_error`; rango plausible
→ flag (umbral `TODO`). ε_a ≤ 0 → error.

**NA.** Propaga.

**Estado.** `CANDIDATA` (forma); la elección de T es `TODO` (RC-12).

**Referencias.** Allen, Tasumi & Trezza (2007) `TODO`; Bastiaanssen (1995)
y Allen (2000) — citadas por `water`, `TODO: identify, add to
REFERENCES.md and verify` (el informe de 2000 puede no ser accesible: en ese
caso, documentar la cadena de citas y buscar una fuente publicada que
reproduzca los coeficientes).

**Caso numérico verificable L1.** ε_a = 0.7598381, T = 293.15 K, σ exacto:
T⁴ = 7.385155 × 10⁹; σ·T⁴ = 418.7659 W m⁻²; RL↓ = 318.1943 W m⁻².
Con T = 288.15 K: 297.0348; T = 310 K: 397.9052.

**Decisión abierta RC-12: qué temperatura T usar en RL↓.** Es el punto
exacto donde el forzamiento meteorológico espacial puede entrar en RL↓.

| Opción | Descripción | A favor | En contra | Relación con H1 |
|---|---|---|---|---|
| (a) Ta del forzamiento | Temperatura del aire a la hora de paso, por píxel: estación única con ajuste por elevación (gradiente térmico, `TODO` valor y fuente) o superficie GWR | Variable físicamente pertinente (la atmósfera emite, no la superficie); independiente de Ts, evita el acoplamiento espurio RL↓–Ts; espacialmente explícita | Requiere Ta a la hora de paso (interpolación temporal); error de regionalización; Ta a 2 m no es la temperatura radiativa efectiva de la columna; **coherencia con la calibración de 0.85/0.09 desconocida** (`TODO`: ¿se derivaron con Ta o con Ts?) | **Única opción en que GWR entra en RL↓.** Estación única + gradiente = configuración C1 (variante C1-lapse); GWR = C3 (`VALIDATION_PLAN.md` §2.1) |
| (b) Ts del píxel frío | Escalar por escena: Ts del ancla fría (bien regada, Ts ≈ Ta) | Convención reportada para METRIC/SEBAL (`TODO: verify` en Allen et al., 2007); coherente con la calibración interna; no requiere estaciones | Uniforme en la escena (solo varía vía ε_a(τ_sw(z))); dependencia del módulo de anclas antes de Rn (§2); a 1 km el píxel frío suele ser mixto (SPEC §2.3) y su Ts sesga RL↓ en toda la escena | No hay entrada de forzamiento espacial |
| (c) Ts por píxel | Ts de cada píxel (forma activa en `water` v1.0, `incLWradiation()`; la variante con temperatura del aire ajustada por elevación aparece **comentada**) | Sin datos adicionales; espacialmente explícita | Físicamente cuestionable: en píxeles calientes y secos sobreestima RL↓ y compensa parcialmente RL↑, reduciendo artificialmente el contraste de Rn (cálculo propio con ε_a = 0.7598: T = 300 K → 348.99; T = 330 K → 510.96 W m⁻², +162 W m⁻², ≈ +159 W m⁻² en Rn con ε₀ = 0.98) | No hay entrada de forzamiento; además confunde el efecto de superficie con el atmosférico |

Recomendación provisional (a confirmar en M1): implementar la función
agnóstica; en el pipeline, ofrecer (a) y (b) como configuraciones
explícitas; (c) solo para verificación cruzada con `water`. Verificar
primero qué prescribe Allen et al. (2007) y con qué temperatura se
derivaron los coeficientes de ε_a.

**Tests planificados.** L1 (tolerancia ~1e-7 relativa por los valores
intermedios mostrados; identidad si se recalcula); ε_a = 1 → σT⁴;
proporcionalidad a T⁴ (duplicar T → ×16); T = 0 o negativa → error;
ε_a ≤ 0 → error; monotonía de ε_a en τ_sw; τ_sw ∈ {0, 1, 1.2} → error;
ε_a > 1 → flag y valor sin modificar; `NA` propaga; la función acepta T
escalar (opción b) o vector/ráster (opciones a, c) con el mismo resultado
que el reciclado explícito.

**Decisiones abiertas.** RC-07, RC-12, RC-13.

**Evidencia previa del autor para RC-13 (2026-11-04; nivel: resumen).**
Morales-Salinas et al. (2023, *Scientific Reports* 13:14465,
doi:10.1038/s41598-023-40499-6) evaluaron ocho modelos globales de
emisividad atmosférica de cielo despejado con datos de reanálisis
NCEP/NCAR: la ecuación de Brutsaert tuvo el mejor desempeño; su coeficiente
calibrado varió estacionalmente entre 1,2 y 1,4, con cinco zonas homogéneas
(K-means), y redujo el error de Rn en un 64 % a escala global (18–77 % por
zona). Conclusión de los autores: el coeficiente de Brutsaert no debe
tratarse como constante en el tiempo ni en el espacio. Implicancias para
EarthFlux:

- `ef_atm_emissivity()` debería admitir, además de la forma en τ_sw,
  la formulación de Brutsaert en función de eₐ y Ta, con coeficiente
  explícito y registrado (no fijo en el código);
- la formulación en eₐ y Ta conecta directamente RL↓ con el forzamiento
  meteorológico espacial (GWR), lo que es relevante para H1 y RC-12;
- verificación pendiente: leer el texto completo (ecuación, coeficientes por
  zona y datos) y la fuente original de Brutsaert (1975/1982).

---

### 6.6 `ef_rl_out()`

**Propósito.** Onda larga **emitida** por la superficie (requisito C1).

**Interfaz propuesta.** `ef_rl_out(lst, emissivity)` → RL↑ [W m⁻²].

**Ecuación candidata** (`CANDIDATA`; ley de Stefan-Boltzmann para cuerpo
gris; forma observada en `water` v1.0, `outLWradiation()`; fuente citada
allí: Allen et al., 2007, `TODO: verify equation number`):

```text
RL↑ = ε₀ · σ · Ts⁴                                  [W m⁻²]
```

**Entradas.**

| Argumento | Unidad | Dominio | Fuente |
|---|---|---|---|
| `lst` | K | (0, ∞); plausibilidad → flag | `surface` (MODIS LST con escala y QA aplicadas) |
| `emissivity` | – | (0, 1] | `surface` (ε₀ de banda ancha; RC-14) |

**Constante.** σ (RC-07).

**Supuestos.** Superficie como cuerpo gris de emisividad de banda ancha ε₀;
Ts representa la temperatura de la superficie radiante del píxel completo
(a 1 km, mezcla de coberturas: la media de Ts⁴ no es la cuarta potencia de
la media de Ts; `TODO` cuantificar si es relevante); instantáneo.

**Requisito de coherencia de emisividad** (`TODO`, RC-14):

1. **Con la recuperación de LST.** Los productos MODIS LST recuperan Ts
   suponiendo emisividades **de banda angosta** propias (bandas térmicas
   31/32 en el producto de ventana dividida; el producto alternativo MOD21
   estima emisividades con otro algoritmo; `TODO: verify` en las guías de
   usuario). EarthFlux no puede rehacer la recuperación de Ts. Si ε₀ se
   obtiene de una fórmula empírica independiente (p. ej., desde LAI), Ts y
   ε₀ quedan desacoplados. En METRIC con Landsat, en cambio, Ts se calcula
   con una emisividad de banda angosta derivada del mismo LAI (forma
   observada en `water` v1.0, `surfaceTemperature()`: ε_NB desde LAI), lo
   que mantiene la coherencia interna; con MODIS ese acoplamiento se pierde.
2. **Banda angosta → banda ancha.** RL↑ requiere ε₀ de banda ancha.
   Convertir las emisividades de banda del producto a banda ancha requiere
   una regresión publicada `TODO: identify primary reference` (no se
   proponen coeficientes).
3. **Mismo ε₀ en `ef_rl_out()` y `ef_net_radiation()`** (requisito C2).

Opciones para ε₀: (i) empírica METRIC desde LAI (forma observada en
`water` v1.0: ε₀ = 0.95 + 0.01·LAI para LAI ≤ 3 y 0.98 para LAI > 3;
atribuida a Allen et al., 2007 / Tasumi, 2003; `CANDIDATA`, `TODO:
verify`, incluido el tratamiento de agua y nieve); (ii) banda ancha desde
las emisividades del producto LST (`TODO`); (iii) desde MOD21 (`TODO`).
Recomendación provisional: preferir (ii)/(iii) por coherencia con Ts, y
registrar en la procedencia qué opción se usó.

Sensibilidad (cálculo propio, Ts = 300 K, ε₀ = 0.98, RL↓ = 318.19 W m⁻²):

- ∂RL↑/∂Ts = 4·ε₀·σ·Ts³ = 6.00 W m⁻² K⁻¹: un sesgo de 1 K en LST mueve RL↑ en
  ≈ 6 W m⁻².
- ∂Rn/∂ε₀ = RL↓ − σ·Ts⁴ = 318.19 − 459.30 = −141.1 W m⁻² por unidad de ε₀:
  Δε₀ = 0.01 → ≈ −1.4 W m⁻² en Rn (efecto directo, con ε₀ coherente en
  ambos términos). El efecto indirecto vía la recuperación de Ts (Δε → ΔTs)
  no se cuantifica aquí (`TODO`).

**Dominio y comportamiento fuera de él.** Ts ≤ 0 K o no finita →
`earthflux_domain_error`. ε₀ ≤ 0 o > 1 → `earthflux_domain_error`
(alinear con el dominio que adopte `ef_net_radiation()`; SPEC §3 indica
(0, 1]). Ts plausible pero inusual (p. ej., valores compatibles con °C
ingresados por error) → flag `EF_LST_IMPLAUSIBLE` (umbral `TODO`).

**NA.** Propaga (píxeles nublados de MODIS LST llegan como `NA`).

**Estado.** Forma `CANDIDATA`; valor de σ cierto, adopción pendiente
(RC-07); ε₀ de banda ancha y coherencia con LST `TODO` (RC-14).

**Referencias.** Allen, Tasumi & Trezza (2007) `TODO`; Tasumi (2003)
`TODO`; Wan, guía de usuario MODIS LST `TODO`; CODATA 2018 `TODO: verify
full citation`.

**Caso numérico verificable O1.** Ts = 300 K, ε₀ = 0.98:
Ts⁴ = 8.1 × 10⁹ K⁴; σ·Ts⁴ = 5.670374419e-8 × 8.1e9 = 459.3003279 W m⁻²;
RL↑ = 0.98 × 459.3003279 = 450.1143214 W m⁻² (con σ = 5.67e-8: 450.0846).

**Caso O2.** Ts = 273.15 K, ε₀ = 1: Ts⁴ = 5.566790 × 10⁹;
RL↑ = 315.6578 W m⁻² (con 5.67e-8: 315.6370).

**Tests planificados.** O1, O2 (tolerancia ~1e-10 relativa, identidad
aritmética con constantes exactas); ε₀ = 1 → σTs⁴; proporcionalidad a ε₀ y
a Ts⁴; Ts = 0, −1, `Inf` → error clasificado; ε₀ = 0, 1.01 → error; `NA`
propaga; matrices con `dim` incompatibles → error; mismo resultado en
vector y `SpatRaster`.

**Decisiones abiertas.** RC-07, RC-14.

---

## 7. Caso integrado de cadena (Rn)

Encadenamiento completo con valores de prueba (para un test de integración
`test-pipeline.R` o `test-radiation.R`; verifica aritmética y contrato, no
física):

```text
Geometría:   φ = −35°, δ = 0, ω = 0, s = 0       → cos θ_h = 0.8191520, dr = 1 (fijado)
Presión:     z = 0                               → P = 101.3 kPa
τ:           eₐ = 1.5 kPa, K_t = 1               → τ_b = 0.6142806, τ_d = 0.1288590, τ_sw = 0.7431396
Rs↓ (plano): Gsc = 1367 (valor de prueba)        → 832.1535 W m⁻²
ε_a:         con τ_sw fijado en 0.75 (caso L1)   → 0.7598381
RL↓:         T = 293.15 K (opción a)             → 318.1943 W m⁻²
RL↑:         Ts = 300 K, ε₀ = 0.98               → 450.1143 W m⁻²
Rn:          α = 0.2
  Rn = 0.8·832.1535 + 318.1943 − 450.1143 − 0.02·318.1943
     = 665.7228 + 318.1943 − 450.1143 − 6.3639
     = 527.4389 W m⁻²
```

Nota: para aislar casos, ε_a se toma de L1 (τ_sw = 0.75) y no de τ_sw =
0.7431 del mismo encadenamiento; el test de integración final debe usar un
único τ_sw coherente, recalculado.

---

## 8. Verificación cruzada con `water`: diferencias esperadas

Según `VALIDATION_PLAN.md` §1.3 (script fuera del tarball, `water` solo si
está instalado). Diferencias que deben esperarse y documentarse, no forzarse:

| Componente | `water` v1.0 (observado) | EarthFlux (propuesto) | Efecto |
|---|---|---|---|
| σ | 5.67e-8 | RC-07 | ≈ 6.6e-5 relativo |
| Rs↓ en pendiente | Gsc·cos θ_rel·τ_sw·dr (difusa tratada como directa) | Particionada: directa + difusa + reflejada | Grande en laderas (casos S2–S4) |
| T en RL↓ | Ts por píxel | RC-12 | Grande en píxeles calientes |
| ε₀ | Desde LAI | RC-14 | Pequeño a moderado |
| Geometría | Hora central de escena (MTL) y longitud de la estación, constantes en la escena | Hora de paso y longitud **por píxel** | Pequeño en Landsat; relevante en MODIS |
| Orientación | A − π en `METRICtopo()` | Conversión interna γ = A − π | Ninguno si ambas son correctas |

---

## 9. Registro de decisiones abiertas

| ID | Decisión | Opciones | Recomendación provisional | Bloquea |
|---|---|---|---|---|
| RC-01 | Unidad angular en el núcleo | Radianes en todo / grados en lat-lon | Radianes en todo (§4.2) | 6.1 |
| RC-02 | Convención de orientación | SIG (horario desde N) en contrato y γ = A − π interno / γ en contrato | SIG en contrato | 6.1 |
| RC-03 | Representación del tiempo y origen de la hora de paso | `doy` + `utc_hour` numéricos / `POSIXct`; *view time* MODIS medio vs aparente; aceptar `solar_hour` | Numéricos en el núcleo; envoltorio desde `POSIXct` UTC; verificar definición del *view time* | 6.1 |
| RC-04 | Precisión de la geometría solar | Formas FAO-56 / algoritmo de efemérides de mayor precisión | Cuantificar error antes de decidir | 6.1 |
| RC-05 | Exportar auxiliares geométricas | Solo `ef_solar_geometry()` / también `ef_cos_incidence()` | API pequeña: exportar solo la envolvente | 6.1 |
| RC-06 | Valor de Gsc | 1367 / ≈ 1361 | Usar el valor con que se derivaron los coeficientes de τ (cambiar Gsc sin recalibrar desplaza Rs↓ ≈ −0.44 %) | 6.4 |
| RC-07 | Valor de σ | Exacto CODATA 2018 / 5.67e-8 | Exacto; permitir reproducir casos publicados en tests con tolerancia justificada | 6.5, 6.6 |
| RC-08 | Formulación de τ_sw y origen de P | Particionada tipo ASCE / simple por elevación; P medida/GWR / P(z) | Particionada por defecto; simple solo en plano y sensibilidad | 6.3 |
| RC-09 | Modelo de difusa en pendiente y ρ_g | Isotrópico / anisotrópico (Allen et al., 2006); ρ_g de píxel / vecindario | Verificar Allen et al. (2006) primero | 6.4 |
| RC-10 | Fuente de Rs↓ | Modelada de cielo despejado / medida (estación o GWR) + descomposición / híbrido con K_t calibrado | Modelada por defecto; híbrido como entrada espacial para H1; registrar coherencia con Rs de ETr | 6.4, H1 |
| RC-11 | Escala de la corrección topográfica | MDE remuestreado a 1 km / cálculo a resolución del MDE y agregación de Rs↓ a 1 km | Evaluar; la pendiente media a 1 km subestima pendientes y Rs↓ no es lineal en s | 6.4 |
| RC-12 | Temperatura para RL↓ | Ta (estación/GWR) / Ts píxel frío / Ts por píxel | Función agnóstica; (a) y (b) como configuraciones; verificar Allen et al. (2007) | 6.5, H1 |
| RC-13 | Formulación de ε_a y τ de entrada | Empírica en τ_sw / alternativas en eₐ y Ta (p. ej., Brutsaert); τ modelada vs efectiva medida | τ_sw modelada de cielo despejado; evaluar Brutsaert calibrado como alternativa (Morales-Salinas et al., 2023) | 6.5 |
| RC-14 | ε₀ de banda ancha y coherencia con LST | Empírica desde LAI / desde emisividades del producto LST / MOD21 | Preferir derivada del producto; registrar procedencia | 6.6 |
| RC-15 | Tipo de retorno | Vector (solo total) / lista de componentes | Lista para `ef_rs_in_modelled()` y `ef_solar_geometry()`; vector para onda larga | 6.1, 6.4 |
| RC-16 | Orientación `NA` en celdas planas | Propagar `NA` siempre / aceptar `NA` si s = 0 | Propagar; el envoltorio del MDE asigna un valor definido a celdas planas y lo documenta | 6.1 |
| RC-17 | Ubicación de `ef_air_pressure()` | `metric-radiation.R` / módulo compartido con ETr y ρ_air | Archivo compartido (evita duplicar la ecuación) | 6.2 |

---

## 10. Referencias primarias que el autor debe verificar

Qué verificar exactamente en cada una. Las marcadas "(nueva)" **no**
figuran en `REFERENCES.md` y deben agregarse con `TODO: verify full
citation` cuando se integre este documento (no se editan aquí).

| Referencia | Qué verificar |
|---|---|
| Allen, Tasumi & Trezza (2007), METRIC — Model | (1) Ecuación de Rs↓ instantánea y si en pendiente aplica cos θ_rel a τ_sw completa o particiona directa/difusa (water la refiere como "Eq. 3"). (2) Ecuación de cos θ_rel, convención de γ y de ω (water: "Eq. 7"). (3) Forma de τ_sw usada (simple por elevación o tipo ASCE) y si se evalúa con θ_h. (4) Ecuación de RL↓, forma de ε_a y **qué temperatura** prescribe (Ta, Ts del píxel frío u otra). (5) Ecuación de RL↑ y fórmula de ε₀ (LAI, agua, nieve). (6) Valor de σ y Gsc. (7) Ecuaciones de C_rad (water: "Eqs. 55–57"), para el alcance futuro. |
| ASCE-EWRI (2005) | Ecuaciones y coeficientes de K_B (τ_b), K_D (τ_d) con su discontinuidad en 0.15, W = 0.14·eₐ·P + 2.1, P(z), definición y rango de K_t, Gsc; si las formas son para pasos horarios/diarios y su aplicabilidad instantánea; tratamiento de ángulos solares bajos. |
| Allen et al. (1998), FAO-56 | Números de ecuación de δ, dr, Sc (ecuación del tiempo), ω (convención de longitudes al oeste), P(z), Rso = (0.75 + 2·10⁻⁵·z)·Ra y Gsc = 0.0820 MJ m⁻² min⁻¹. |
| Allen, Trezza & Tasumi (2006) | Partición directa/difusa en pendientes; si la difusa es isotrópica o anisotrópica y su forma; término reflejado; uso instantáneo vs integrado diario; forma de cos θ en pendiente. |
| Majumdar, Mathur & Kaushik (1972) (nueva; citada por `water`) | Origen de la forma de τ_b; cita completa (water: *Solar Energy*, 13, 383–394). |
| Allen (1996) (nueva; citada por `water`, sin cita completa) | Identificar el documento ("extended equation" de transmisividad). |
| Bastiaanssen (1995), tesis doctoral (nueva; citada por `water`) | Forma ε_a = a·(−ln τ_sw)^b y con qué temperatura se usa. |
| Allen (2000), informe interno "RAPID" (nueva; citada por `water`) | Coeficientes 0.85 y 0.09; temperatura de calibración; accesibilidad del documento. |
| Duffie & Beckman, *Solar Engineering of Thermal Processes* (nueva; candidata) | Ecuación del ángulo de incidencia sobre plano arbitrario y convención de γ; formas isotrópicas de difusa y reflejada; edición y número de ecuación. |
| Liu y Jordan (formulación isotrópica) (nueva; candidata) | Identificar la referencia primaria del modelo isotrópico de difusa. |
| Modelos de descomposición de la radiación global en difusa (nuevas) | Identificar referencias primarias si se adopta el camino medido (RC-10). |
| Spencer (1971) (nueva; candidata) | Serie de Fourier para δ y ecuación del tiempo, si se elige mayor precisión (RC-04). |
| Wan, guía de usuario MODIS LST | Definición del *view time* (hora solar media o aparente; escala; relleno); emisividades de banda usadas en la recuperación (bandas 31/32); y guía de MOD21 para la alternativa. |
| Tasumi (2003) | Fórmula de ε₀ desde LAI y casos especiales (agua, nieve). |
| CODATA 2018 (nueva) | Cita completa del valor recomendado de σ (exacto en el SI de 2019). |
| Fuente de irradiancia solar total reciente (nueva) | Valor ≈ 1361 W m⁻² y su fuente primaria (RC-06). |
| Brutsaert (1982) | Si contiene la formulación de emisividad atmosférica de cielo despejado en función de eₐ y Ta (alternativa RC-13). |
| Regresión banda angosta → banda ancha de emisividad para MODIS (nueva) | Identificar fuente primaria y bandas requeridas (RC-14). |

---

## 11. Fuera de alcance (por ahora)

- Sombras proyectadas por el relieve vecino y factor de visión del cielo
  reducido por el horizonte real (requiere algoritmos de horizonte sobre el
  MDE a resolución fina). Se registra como limitación en Andes.
- Integración diaria de la radiación en pendientes y corrección C_rad de
  ETa diaria (relacionada, pero pertenece a la extrapolación temporal,
  `metric-et.R`).
- Condiciones nubladas: el flujo METRIC con MODIS LST opera sobre píxeles
  de cielo despejado; RL↓ y Rs↓ bajo nubes no se especifican.
- Radiación de onda corta reflejada por el terreno vecino con albedo
  espacialmente variable (más allá del ρ_g simple).
- Registro de los flags en `ef_flag_registry()` y actualización del índice
  de `SCIENTIFIC_SPEC.md` (se hará al integrar este documento).

---

## 12. Estado de implementación (M2, 2026-11-04)

Nombres según `NAMING.md` (tabla "Radiación"). Todas las formas siguen
`CANDIDATA` salvo lo indicado; las elecciones no verificadas son argumentos
explícitos sin defecto (`DECISIONS.md` §1.0).

| Función | Exportada | Estado | Notas de implementación |
|---|---|---|---|
| `ef_solar_geometry(doy, utc_hour, lat, lon, slope = 0, aspect = 0)` | Sí | δ, dr, Sc, ω `VERIFICADA` (FAO-56 Ec. 23, 24, 31–33; `weather-forcing.md` §4.6); cos θ_h identidad trigonométrica; cos θ_rel `CANDIDATA` | Devuelve lista simple `cos_zenith`, `cos_incidence`, `declination`, `hour_angle`, `inv_distance`, todas con la forma común (RC-15) |
| `ef_declination()`, `ef_inv_distance()`, `ef_equation_of_time()`, `ef_hour_angle()`, `ef_cos_incidence()` | No (RC-05) | Como arriba | Reutilizables por `ef_ra_daily()`/`ef_ra_period()` (`weather-forcing.md` §4.6) sin duplicar ecuaciones |
| `ef_tau_sw(..., method)` → `ef_tau_sw_allen(cos_zenith, pressure, vapour_pressure, turbidity)`, `ef_tau_sw_elevation(elevation)` | Sí | `allen` `CANDIDATA`; `elevation` con la forma de FAO-56 Ec. 37, uso instantáneo `CANDIDATA` | `turbidity` **sin defecto** (el valor 1 no está verificado). `allen` devuelve lista (`beam`, `diffuse`, `total`); `elevation`, numérico. Desde la armonización M2, el despachador devuelve un objeto `earthflux_sw_transmissivity` de tipo estable: `total` siempre; `beam` y `diffuse` presentes con nombre, `NULL` con `elevation`; más `method`, `flags` y `provenance` |
| `ef_atm_emissivity(tau_sw)` | Sí | `CANDIDATA` | Dominio (0, 1) abierto; ε_a > 1 se conserva y se marca |
| `ef_rs_in(..., method)` → `ef_rs_in_modelled(cos_zenith, cos_incidence, inv_distance, tau_beam, tau_diffuse, slope, ground_albedo = NULL)`, `ef_rs_in_measured(rs_horizontal, diffuse_fraction, cos_zenith, cos_incidence, slope, ground_albedo = NULL)` | Sí | `CANDIDATA` (proyección isotrópica; RC-09 abierta); en el camino medido la fuente de k_d sigue `TODO` (RC-10) | `slope` **sin defecto** (evita combinar un cos θ_rel de ladera con difusa de plano); `ground_albedo = NULL` solo si ninguna pendiente es > 0; τ_b + τ_d ∈ (0, 1) (suma 0 excluida: k_d indefinida); proyección común interna `ef_rs_to_slope()`. Desde la armonización M2, el despachador devuelve un objeto `earthflux_incoming_shortwave` (`total`, `beam`, `diffuse`, `reflected`, `diffuse_fraction` —`NULL` con `measured`—, `method`, `flags` con `EF_INPUT_NA` y `EF_RAD_SELF_SHADED`, `provenance`) |
| `ef_rl_in(temperature, atm_emissivity)` | Sí | `CANDIDATA`; T sin defecto (RC-12 / P0-3 abiertas) | Agnóstica respecto de la temperatura |
| `ef_rl_out(lst, emissivity)` | Sí | `CANDIDATA` (corroborada, como `ef_net_radiation()`) | Onda larga **emitida** (C1) |
| `ef_diagnose_radiation(...)` | No | — | Flags de celda de la etapa (ver abajo) |

Decisiones tomadas al implementar:

1. **Tiempo (RC-03).** El núcleo recibe `doy` de la fecha UTC y `utc_hour`
   UTC; la ecuación del tiempo se aplica una sola vez, en `ef_hour_angle()`,
   con t_s = (utc_hour + λ·12/π + Sc) mod 24 y ω ∈ [−π, π). La conversión
   del *view time* de MOD11A1 (hora solar media) a UTC queda fuera del
   núcleo (`modis-products.md` §6.2); no se acepta `solar_hour`. Test de
   equivalencia con FAO-56 Ec. 31 (longitudes al oeste, 0–360) y con los
   valores publicados de los Ejemplos 8 y 19.
2. **Argumento `inv_distance`** (no `inv_rel_distance`): coincide con
   `ef_inv_distance()` (regla N5 de `NAMING.md`).
3. **NA.** Propagación aritmética a las salidas que dependen de la entrada
   faltante (`total` siempre); no se fuerza `NA` en componentes calculables
   (p. ej., `diffuse_fraction` no depende de cos θ_h).
4. **Gsc** = `EF_SOLAR_CONSTANT` (1366,67 W m⁻², FAO-56 Ec. 21; adopción
   `CANDIDATA`, RC-06). Los casos S1–S4 (calculados con 1367) se verifican
   reescalando por 1367/Gsc, ya que Rs↓ es proporcional a Gsc.
5. **Caso integrado (§7)** con un único τ_sw coherente (0,7431396):
   Rs↓ = 831,9506; ε_a = 0,7619914; RL↓ = 319,0960; RL↑ = 450,1143;
   Rn = 528,1603 W m⁻² (α = 0,2; ε₀ = 0,98; T = 293,15 K).
6. **Discrepancia RC-08** (FAO-56 Anexo 3 Ec. 3-18/3-20 frente a la forma de
   §6.3.A) registrada en la documentación de `ef_tau_sw_allen()`.
7. **Flags registrados** (clase I, `flags.md` §4.2 y §6.4):
   `EF_RAD_SELF_SHADED` (bit 1), `EF_RAD_ATM_EMISSIVITY_GT1` (bit 2),
   `EF_RAD_RS_GT_RA` (bit 3; ámbitos `cell,record`, evaluado en `cell` con
   R_a,h = Gsc·dr·max(cos θ_h, 0)) y `EF_RAD_RN_NEGATIVE` (bit 4). Los
   construye `ef_diagnose_radiation()`, que evalúa cada código solo si
   recibe todas sus entradas. `EF_RAD_SUN_LOW` (clase II) no se registra.
   *Armonización M2 (2026-11-04, `DECISIONS.md` §1.2, M2-05):* como en
   todas las etapas, devuelve un registro solo por código marcado en al
   menos una posición; los códigos evaluados viajan en el atributo
   `evaluated` y los despachadores los registran en
   `provenance$flags_evaluated` (antes devolvía un registro por código
   evaluado, aunque no marcara celdas).
8. **Armonización M2** (`DECISIONS.md` §1.2): los auxiliares de
   validación (`check_core_args()`, `check_doy()`, `check_angle()`,
   `check_whole()`, `common_dim()`, `ef_reshape()`) pasaron a
   `R/utils.R`, compartidos por todo el núcleo.

Fuera de esta implementación: emisividad superficial ε₀ (módulo `surface`,
RC-14), formulación de Brutsaert para ε_a (RC-13), modelos de
descomposición para k_d (RC-10), corrección anisotrópica de la difusa
(RC-09) y comparación con efemérides de mayor precisión (RC-04).
