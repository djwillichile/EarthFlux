# EarthFlux — Especificación: flujo de calor sensible (H), rugosidad, rah y calibración de dT

Estado: **borrador M1** · Componente: `metric` · Archivos de destino:
`R/metric-aerodynamics.R` (z_om, u*, rah, estabilidad), `R/metric-dt.R`
(Ts_datum, coeficientes de dT), `R/metric-sensible-heat.R` (ρ_air, H y
driver de calibración) · Tests: `tests/testthat/test-aerodynamics.R`,
`tests/testthat/test-sensible-heat.R`.

> Este documento detalla las filas **rah**, **dT** y **H** de la tabla de
> variables de `SCIENTIFIC_SPEC.md` (§3) y el punto de entrada "velocidad
> del viento a altura de mezcla" de `SCIENTIFIC_SPEC.md` §1.2.
> `SCIENTIFIC_SPEC.md` sigue siendo la fuente de verdad científica. Ninguna
> ecuación **de METRIC** de este documento está en estado `VERIFICADA`; solo
> están `VERIFICADA` algunas formas **tal como aparecen en FAO-56** (leídas
> en esta redacción), cuyo **uso dentro de METRIC** sigue siendo
> `CANDIDATA`. Nada de este documento puede implementarse hasta cumplir la
> Definition of Done (`DEVELOPMENT.md` §3).

Convención de estados: la misma de `SCIENTIFIC_SPEC.md` (`TODO`,
`CANDIDATA`, `VERIFICADA`). Convención de trazabilidad: la misma de
`radiation-components.md` ("forma observada en `water` v1.0, función X";
"fuente primaria citada allí"; casos numéricos calculados por el autor, que
verifican aritmética y no física).

---

## 0. Índice

1. Resumen
2. Alcance, contrato e interfaz con el módulo de anclas
3. Fuentes consultadas y nivel de evidencia
4. Convenciones (unidades, notación, constantes)
5. Longitud de rugosidad para momento (z_om) y desplazamiento (d)
6. Viento a altura de mezcla y velocidad de fricción (u*)
7. Resistencia aerodinámica neutral (rah)
8. Densidad del aire (ρ_air) y calor específico (c_p)
9. dT = a + b·Ts_datum: ajuste por elevación y solución desde las anclas
10. Estabilidad de Monin-Obukhov
11. Iteración de calibración (rah → H → L → ψ → u*, rah)
12. Descomposición en funciones y diseño vectorizado
13. NA, dominio y errores con clase
14. Casos numéricos
15. Tests planificados
16. Flags propuestos (no registrar todavía)
17. Verificación cruzada con `water`: diferencias esperadas
18. Decisiones abiertas
19. Qué verificar en las fuentes primarias
20. Fuera de alcance
21. Estado de implementación (M2)

---

## 1. Resumen

| Componente | Forma | Estado | Dónde se observó / leyó |
|---|---|---|---|
| z_om cultivos bajos | z_om = 0.018·LAI | `CANDIDATA` | `water` v1.0, `momentumRoughnessLength(method = "short.crops")`; fuente primaria citada allí: Allen et al. (2007), "Eq. 33" (no consultada) |
| z_om "custom" | z_om = exp(a·NDVI/α + b) | `CANDIDATA` | `water`, `method = "custom"`; Allen et al. (2007) |
| z_om Perrier | z_om = (1 − e^(−p·LAI/2))·e^(−p·LAI/2)·h | `CANDIDATA` | `water`, `method = "Perrier"`; Santos et al. (2012), Pôças et al. (2014) |
| z_om desde altura de cultivo | z_om = 0.123·h; d = 2/3·h | `VERIFICADA` como contenido de FAO-56 (Cap. 2, Recuadro 4); uso en METRIC `TODO` | FAO-56 |
| Mínimo de z_om | 0.005 m | `CANDIDATA` | `water` (comentario "Allen et al., 2007, after Eq. 33") |
| Ajuste por terreno de z_om | ×(1 + (s° − 5)/20) | `CANDIDATA` | `water` (comentario "Allen et al., 2007, Eq. 35") |
| Viento a altura de mezcla | u_b = u_x·ln(z_b/z_om,w)/ln(z_x/z_om,w), z_b = 200 m | `CANDIDATA` | `water`, `calcH()`; "Eq. 32" según su roxygen |
| Perfil logarítmico neutral | r_a = ln((z_m − d)/z_om)·ln((z_h − d)/z_oh)/(k²·u_z); k = 0.41 | `VERIFICADA` como contenido de FAO-56 (Cap. 2, Ec. 4) | FAO-56 |
| u* | u* = k·u_b/(ln(z_b/z_om) − ψ_m(z_b)) | `CANDIDATA` | `water`, `calcH()`, `rahStep()` |
| rah | rah = (ln(z₂/z₁) − ψ_h(z₂) + ψ_h(z₁))/(k·u*); z₁ = 0.1 m, z₂ = 2 m | `CANDIDATA` | `water`; `SCIENTIFIC_SPEC.md` §3 |
| ρ_air | ρ = P/(T_Kv·R), T_Kv = 1.01·(T + 273), R = 0.287 kJ kg⁻¹ K⁻¹ | `VERIFICADA` como contenido de FAO-56 (Cap. 2, Recuadro 6); uso en METRIC `CANDIDATA` | FAO-56; `water` |
| c_p | 1004 J kg⁻¹ K⁻¹ (`water`) o 1.013 × 10⁻³ MJ kg⁻¹ °C⁻¹ (FAO-56) | `CANDIDATA` / `VERIFICADA` (FAO-56) | §8.3 |
| Ts_datum | Ts_datum = Ts + Γ·(z − z_datum), Γ = 6.49 K km⁻¹ | `CANDIDATA` | `water`, `calcH()`, `calcH.control(lapse = )` |
| dT | dT = a + b·Ts_datum, a y b desde dos anclas | `CANDIDATA` | `SCIENTIFIC_SPEC.md` §3; `water` (notación invertida, §4.2) |
| H | H = ρ_air·c_p·dT/rah | `CANDIDATA` | `SCIENTIFIC_SPEC.md` §3; `water` |
| L, ψ_m, ψ_h | Paulson (inestable), log-lineal −5·z/L (estable) | `CANDIDATA` | `water`, `rahStep()`; `bigleaf` (rdrr.io); citas verificadas en Crossref, contenido no |

Recomendación de API (§12): seis funciones numéricas vectorizadas
(`ef_zom()`, `ef_ustar()`,
`ef_rah()`, `ef_air_density()`, `ef_dt_coef()`,
`ef_sensible_heat()`), auxiliares para viento a altura de mezcla,
Ts_datum y estabilidad, y un **driver de calibración** en dos fases
(iteración en anclas → (a*, b*); iteración por píxel con (a*, b*) fijos)
cuyo carácter exportado o interno es una decisión abierta (SH-17).

---

## 2. Alcance, contrato e interfaz con el módulo de anclas

### 2.1 Alcance

- **Dentro:** z_om y d; viento a altura de mezcla; u*; rah neutral y
  corregida; ρ_air y c_p; Ts_datum; inversión de dT desde H objetivo en las
  anclas; coeficientes a, b; corrección de estabilidad de Monin-Obukhov;
  iteración, convergencia, amortiguación y diagnósticos; H por píxel.
- **Fuera:** selección de anclas y cálculo de su LE objetivo (módulo de
  anclas, especificación en curso, `R/metric-anchors.R`); Rn
  (`ef_net_radiation.md`, `radiation-components.md`); G
  (`soil-heat-flux.md`); LE = Rn − G − H y ET (`metric-latent-heat.R`,
  `metric-et.R`); ETr instantánea (`metric-et.R` / `prep-weather.R`).
- Todas las magnitudes son **instantáneas a la hora de paso**.

### 2.2 Interfaz mínima requerida del módulo de anclas

Este módulo **no** selecciona anclas ni conoce ETr. Solo necesita, para cada
ancla, valores de píxel y su objetivo energético. Contrato propuesto (tabla
o `data.frame`, una fila por ancla):

| Columna | Unidad | Significado | Producido por |
|---|---|---|---|
| `anchor_id` | – | Identificador estable (celda, coordenadas) | Anclas |
| `type` | `"hot"` / `"cold"` | Clase del ancla | Anclas |
| `lst` | K | Ts del píxel | `surface` |
| `elevation` | m | z del píxel (para Ts_datum, P y, si aplica, ajuste de viento) | DEM |
| `zom` | m | z_om del píxel (salida de `ef_zom()`) | Este módulo |
| `rn` | W m⁻² | Rn del píxel | `ef_net_radiation()` |
| `g` | W m⁻² | G del píxel | `ef_g()` |
| `le_target` | W m⁻² | LE objetivo (p. ej., LE_cold = coeficiente·ETr_inst·λ; LE_hot = ETrF_hot·ETr_inst·λ, típicamente 0) | Anclas (coeficientes, λ y su referencia viven allí) |
| `u_blend` | m s⁻¹ | Viento a altura de mezcla en el ancla (escalar de escena o superficie espacial) | Este módulo / `forcing` |
| `pressure` | kPa | P en el ancla (medida/GWR o `ef_air_pressure()`) | `forcing` / `radiation-components.md` §6.2 |

Este módulo calcula, para cada ancla, el **H objetivo**:

```text
H_target = rn − g − le_target          [W m⁻²]
H_hot  = Rn_hot  − G_hot  − LE_hot
H_cold = Rn_cold − G_cold − LE_cold
```

y devuelve al registro de anclas: a, b, dT, rah, u*, L, ρ_air en cada ancla
por iteración, `converged`, número de iteraciones y la configuración usada
(procedencia). El registro de anclas (`SCIENTIFIC_SPEC.md` §7) es el lugar
donde se guardan los criterios de selección; aquí solo se agregan los
resultados de la calibración.

Requisitos que este módulo verifica sobre las anclas (errores con clase,
§13): al menos un ancla `hot` y una `cold`; entradas no `NA` en las anclas;
Ts_datum(hot) > Ts_datum(cold) (si no, la pendiente b es indefinida o de
signo invertido). Un umbral mínimo de diferencia (p. ej., los 5 K de
`water`, que son una elección de ese paquete) **requiere justificación**
(flag `EF_ANCHOR_DT_SMALL`, §16; coordinar con la especificación de anclas).

### 2.3 Varias anclas por clase

`water` ofrece dos modos (`calcH(method = )`): `"mean"` promedia, por
clase, Ts_datum, Rn, G, rah y ρ de las anclas y resuelve un único par;
`"lm"` itera cada par hot/cold por turno y devuelve a, b del **último** par.
Ninguno está respaldado aquí por una fuente primaria. Caso base de esta
especificación: **exactamente un valor por clase** (un ancla, o el promedio
de varias definido por el módulo de anclas). Agregación con varias anclas:
decisión abierta SH-14.

---

## 3. Fuentes consultadas y nivel de evidencia

| Fuente | Tipo | Qué aporta | Limitación |
|---|---|---|---|
| Allen, Tasumi & Trezza (2007), METRIC — Model | Primaria | — | **No consultada** (ascelibrary.org bloqueado en el entorno). Metadatos verificados en Crossref (§3.1). |
| Paulson (1970); Webb (1970) | Primaria | — | **No consultadas** (journals.ametsoc.org y rmets.onlinelibrary.wiley.com bloqueados). Metadatos verificados en Crossref. |
| FAO-56 (Allen, Pereira, Raes & Smith, 1998), edición web en `www.fao.org/4/x0490e/` | Primaria (para su propio contenido) | **Leída en esta redacción:** Cap. 2 (`x0490e06.htm`): Ec. 4 (r_a neutral, k = 0.41, restricción a estabilidad neutral), Recuadro 4 (d = 2/3·h, z_om = 0.123·h, z_oh = 0.1·z_om), Recuadro 6 (ρ_a = P/(T_Kv·R), T_Kv = 1.01·(T + 273), R = 0.287 kJ kg⁻¹ K⁻¹). Cap. 3 (`x0490e07.htm`): Ec. 7 (P(z)), texto de Ec. 8 (c_p = 1.013 × 10⁻³ MJ kg⁻¹ °C⁻¹ "for average atmospheric conditions"), Ec. 47 (perfil de viento sobre pasto corto) | Las ecuaciones de la edición web son imágenes; se leyeron como imagen. La edición web no tiene número de página: se cita capítulo, ecuación y recuadro. FAO-56 no trata METRIC: verifica formas compartidas, no su uso en METRIC. |
| `water` v1.0 (2026-10-19; commit `3c94630`; GPL ≥ 2): `R/water_sensibleHeatFlux.R` (`momentumRoughnessLength()`, `airDensity()`, `rahStep()`, `calcH()`), `R/water_controls.R` (`calcH.control()`), `R/water_internals.R` (`anchorCells()`, `checkIteration()`), `NEWS` | Secundaria (implementación) | Formas, coeficientes, valores por defecto, estructura de la iteración y su manejo de errores | Una implementación no es una fuente científica. **No se copia código** (GPL vs MIT); las formas se reescriben con notación propia. |
| `water`, `roadto1/*.md` (notas de revisión incluidas en el repositorio; autoría y método no verificables) | Terciaria | Atribuye números de ecuación y página de Allen et al. (2007) (Ec. 32–51, p. 386, p. 389) y señala desviaciones de `water` respecto del artículo | Solo orienta qué buscar en la fuente primaria. |
| Paquete R `bigleaf` (documentación y código en `rdrr.io/cran/bigleaf`, `stability.correction()`, `Monin.Obukhov.length()`) | Secundaria | Corrobora independientemente las formas integradas de ψ (coeficientes 16 y −5, forma con arctan "after Paulson 1970") y la definición de L con T_aire | Implementación de otro dominio (eddy covariance). En su código la línea de ψ_m inestable está partida, de modo que el término −2·arctan(x) + π/2 queda como expresión separada y no se suma (observación de lectura; muestra que una fuente secundaria también puede contener errores). |

### 3.1 Citas verificadas en Crossref (metadatos, no contenido)

Consultadas en `api.crossref.org` el 2026-11-04:

| Referencia | Metadatos confirmados | DOI |
|---|---|---|
| Paulson, C. A. (1970). The mathematical representation of wind speed and temperature profiles in the unstable atmospheric surface layer. *Journal of Applied Meteorology*, 9(6), 857–861. | Autor, título, revista, volumen, número, páginas, año | `10.1175/1520-0450(1970)009<0857:TMROWS>2.0.CO;2` |
| Webb, E. K. (1970). Profile relationships: The log-linear range, and extension to strong stability. *Quarterly Journal of the Royal Meteorological Society*, 96(407), 67–90. | Ídem | `10.1002/qj.49709640708` |
| Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy balance for mapping evapotranspiration with internalized calibration (METRIC)—Model. *Journal of Irrigation and Drainage Engineering*, 133(4), 380–394. | Ídem | `10.1061/(ASCE)0733-9437(2007)133:4(380)` |
| Allen, R. G., Tasumi, M., Morse, A., Trezza, R., Wright, J. L., Bastiaanssen, W., Kramber, W., Lorite, I., & Robison, C. W. (2007). … (METRIC)—Applications. *J. Irrig. Drain. Eng.*, 133(4), 395–406. | Ídem | `10.1061/(ASCE)0733-9437(2007)133:4(395)` |
| Santos, C., Lorite, I. J., Allen, R. G., & Tasumi, M. (2012). Aerodynamic parameterization of the satellite-based energy balance (METRIC) model for ET estimation in rainfed olive orchards of Andalusia, Spain. *Water Resources Management*, 26(11), 3267–3283. | Ídem | `10.1007/s11269-012-0071-8` |
| Pôças, I., Paço, T. A., Cunha, M., Andrade, J. A., Silvestre, J., Sousa, A., Santos, F. L., Pereira, L. S., & Allen, R. G. (2014). Satellite-based evapotranspiration of a super-intensive olive orchard: Application of METRIC algorithms. *Biosystems Engineering*, 128, 69–81. | Ídem | `10.1016/j.biosystemseng.2014.06.019` |
| Allen, R., Irmak, A., Trezza, R., Hendrickx, J. M. H., Bastiaanssen, W., & Kjaersgaard, J. (2011). Satellite-based ET estimation in agriculture using SEBAL and METRIC. *Hydrological Processes*, 25(26), 4011–4027. | Ídem | `10.1002/hyp.8408` |
| Bastiaanssen, W. G. M., et al. (1998). A remote sensing surface energy balance algorithm for land (SEBAL). 1. Formulation. *Journal of Hydrology*, 212–213, 198–212. | Título, volumen, páginas, año | `10.1016/S0022-1694(98)00253-4` |
| Brutsaert, W. (1982). *Evaporation into the Atmosphere*. Springer (Reidel). | Libro, autor, año | `10.1007/978-94-017-1497-6` |

Estas verificaciones confirman **que la cita existe y es correcta**, no el
contenido. `REFERENCES.md` debe actualizarse al integrar este documento
(no se edita aquí).

### 3.2 Hosts no accesibles durante la redacción

`ascelibrary.org` y `github.com` (bloqueados por política; no se
intentaron); `journals.ametsoc.org` y `rmets.onlinelibrary.wiley.com`
(rechazados por el proxy, HTTP 403 en el túnel; no se reintentó). `doi.org`
responde pero redirige a hosts bloqueados.

---

## 4. Convenciones

### 4.1 Unidades

| Magnitud | Unidad en el núcleo | Nota |
|---|---|---|
| Temperaturas (Ts, Ts_datum, T_aire) | K | `radiation-components.md` §4.1 |
| dT | K | Diferencia de temperatura (K = °C en diferencias) |
| Alturas, z_om, d, elevación | m | |
| Velocidades (u_x, u_b, u*) | m s⁻¹ | |
| rah | s m⁻¹ | |
| P | kPa | Coherente con `ef_air_pressure()` |
| ρ_air | kg m⁻³ | |
| c_p | J kg⁻¹ K⁻¹ | FAO-56 lo da en MJ kg⁻¹ °C⁻¹: ×10⁶ |
| Flujos (Rn, G, H, LE) | W m⁻² | |
| Pendiente | rad (RC-01) | El ajuste por terreno de `water` usa grados: conversión interna |
| Γ (gradiente de Ts con la elevación) | K m⁻¹ en el núcleo | `water` lo expone en K km⁻¹ |

### 4.2 Notación de dT: **atención al intercambio a ↔ b**

- `SCIENTIFIC_SPEC.md` §3 escribe **dT = a + b·Ts_datum** (a = intercepto
  [K], b = pendiente [–]). Esta especificación conserva esa notación.
- `water` escribe `dT = a * Ts.datum + b` (a = pendiente, b = intercepto).
- Consecuencia: en la verificación cruzada (§17) y al leer la fuente
  primaria se debe **mapear explícitamente** a_EarthFlux = b_water y
  b_EarthFlux = a_water. `TODO`: confirmar la notación de Allen et al.
  (2007) y, si difiere, decidir si se adopta la del artículo (SH-12).

### 4.3 Constantes

Cada constante vive en un único lugar del código (constante interna
nombrada, con referencia en roxygen), como en `radiation-components.md` §5.

| Constante | Símbolo | Valor candidato | Fuente | Estado |
|---|---|---|---|---|
| Constante de von Kármán | k | 0.41 | FAO-56, Cap. 2, Ec. 4 ("von Karman's constant, 0.41"); `water` (`calcH()`, `rahStep()`); `SCIENTIFIC_SPEC.md` §3 | `VERIFICADA` como valor usado en FAO-56; uso en METRIC `CANDIDATA` |
| Calor específico del aire a presión constante | c_p | 1004 J kg⁻¹ K⁻¹ | `water` (`calcH()`, `rahStep()`); `SCIENTIFIC_SPEC.md` §3 ("≈ 1004 `TODO`") | `CANDIDATA` |
| Ídem (alternativa) | c_p | 1013 J kg⁻¹ K⁻¹ (= 1.013 × 10⁻³ MJ kg⁻¹ °C⁻¹) | FAO-56, Cap. 3, texto de Ec. 8 | `VERIFICADA` como valor de FAO-56 |
| Constante específica del aire seco | R | 287 J kg⁻¹ K⁻¹ (0.287 kJ kg⁻¹ K⁻¹) | FAO-56, Cap. 2, Recuadro 6; `water` | `VERIFICADA` como valor de FAO-56 |
| Factor de temperatura virtual | – | 1.01 (T_Kv = 1.01·(T + 273)) | FAO-56, Cap. 2, Recuadro 6; `water` | `VERIFICADA` como forma de FAO-56 |
| Aceleración de gravedad | g | 9.807 m s⁻² | `water` (`rahStep()`) | `CANDIDATA`; `TODO`: valor y referencia (gravedad estándar convencional vs 9.81) |
| Altura de mezcla (blending height) | z_b | 200 m | `water`; `SCIENTIFIC_SPEC.md` §1.2 | `CANDIDATA` |
| Alturas de rah | z₁, z₂ | 0.1 m, 2 m | `water` (`calcH()`, `rahStep()`) | `CANDIDATA` |
| Coeficientes de ψ inestable | – | 16; exponente 1/4 (momento) | `water`; `bigleaf` (formulación "Dyer_1970") | `CANDIDATA` |
| Coeficiente de ψ estable | – | −5 | `water`; `bigleaf` | `CANDIDATA` |
| Gradiente de Ts con la elevación | Γ | 6.49 K km⁻¹ | `water` (`calcH.control(lapse = 6.49)`) | `CANDIDATA` |
| Mínimo de z_om | z_om,min | 0.005 m | `water` | `CANDIDATA` |
| Coeficientes de P(z) | – | 101.3; 293; 0.0065; 5.26 | FAO-56, Cap. 3, Ec. 7 | `VERIFICADA` como contenido de FAO-56 (ver `radiation-components.md` §6.2, donde aún figura `TODO: verify equation number`: el número es Ec. 7) |
| Conversión K ↔ °C | – | 273.15 | Convención del paquete (`soil-heat-flux.md` §3.2) | FAO-56 usa 273 en T_Kv: diferencia relativa ≈ 5 × 10⁻⁴ en ρ (§8.1) |

---

## 5. Longitud de rugosidad para momento (z_om) y desplazamiento (d)

z_om [m] controla u* y, por tanto, rah. En METRIC (según `water`) **no** se
usa d en la rah del píxel: z₁ y z₂ se interpretan como alturas sobre el
plano de desplazamiento (`SCIENTIFIC_SPEC.md` §3). Métodos encontrados:

### 5.1 Cultivos bajos, lineal en LAI — `CANDIDATA`

```text
z_om = 0.018 · LAI          [m]
```

- Observada en `water` v1.0, `momentumRoughnessLength(method =
  "short.crops")` (método por defecto). Fuente primaria citada allí: Allen
  et al. (2007), "Eq. 33".
- Las notas terciarias citan del artículo (después de la Ec. 33) que la
  relación "tiende a subestimar z_om para maíz" y que "se requeriría otra
  función para viñas y árboles". **No verificado.** Relevante en Chile
  central (frutales, viñas).
- Con LAI MODIS a 1 km (píxeles mixtos), la linealidad en LAI medio no
  equivale al promedio de z_om de las coberturas del píxel (SPEC §2.3).

### 5.2 "Custom", exponencial en NDVI/α — `CANDIDATA`

```text
z_om = exp(c₁ · NDVI/α + c₂)          [m]
```

- Observada en `water`, `method = "custom"`, con c₁ y c₂ (allí `a`, `b`)
  **obligatorios y suministrados por el usuario**; fuente citada: Allen et
  al. (2007). Un comentario en el código sugiere ajustar c₁, c₂ con puntos
  de cobertura conocida y z_om tabulada: es el puente natural con una tabla
  por cobertura (§5.5).
- Para evitar confusión con los coeficientes de dT, EarthFlux usará otros
  nombres de argumento (p. ej., `coef_1`, `coef_2`).
- Dominio: α > 0 (división).

### 5.3 Perrier, para árboles y cultivos altos — `CANDIDATA`

```text
p = 1 / (2·(1 − f))     si f < 0.5
p = 2·f                 si f ≥ 0.5
z_om = (1 − exp(−p·LAI/2)) · exp(−p·LAI/2) · h          [m]
```

- f: fracción del LAI situada por encima de h/2 [–], en [0, 1]; h: altura
  del cultivo [m].
- Observada en `water`, `method = "Perrier"` ("Perrier equation as in
  Santos et al. (2012) and Pôças et al. (2014)"). Cita original de Perrier:
  `TODO` (no identificada).
- Continuidad en f = 0.5 (cálculo propio): ambas ramas dan p = 1.
- `water` acepta f y h escalares o rásteres; celdas con h = 0 o `NA` dentro
  de la escena terminan en el mínimo de 0.005 m (suelo desnudo).
- Requiere h por píxel: no disponible desde MODIS. Solo aplicable con un
  mapa de cultivos/alturas externo.

### 5.4 Desde la altura de la vegetación (FAO-56) — `VERIFICADA` como contenido de FAO-56; uso en METRIC `TODO`

```text
d    = 2/3 · h
z_om = 0.123 · h
z_oh = 0.1 · z_om
```

FAO-56, Cap. 2, Recuadro 4 ("For a wide range of crops…"). Se usa para la
superficie de la **estación** (§6.1). Su uso para píxeles de la escena
requiere h por cobertura (§5.5).

### 5.5 Tabla por cobertura de suelo — `TODO`

- `water` **no** implementa una tabla por cobertura.
- Opciones: (i) z_om tabulada por clase (MCD12Q1 o cobertura local,
  `SCIENTIFIC_SPEC.md` §4); (ii) h tabulada por clase y z_om = 0.123·h
  (§5.4); (iii) tabla usada para calibrar c₁, c₂ de §5.2.
- Ninguna tabla de valores se propone aquí: requiere fuente primaria.
  `TODO`: identificar la tabla de METRIC (si Allen et al., 2007, o el
  manual de METRIC la contienen) o una fuente regional.

### 5.6 Mínimo de z_om — `CANDIDATA`

- `water` aplica z_om = max(z_om, 0.005 m) a todos los métodos, comentado
  como "bare agricultural soil (Allen et al., 2007, after Eq. 33)"; las notas
  terciarias lo sitúan en la p. 386. **No verificado.**
- No es una corrección silenciosa si se documenta como regla del método:
  propuesta de aplicarlo como parte del método, con flag informativo
  `EF_ZOM_FLOOR_APPLIED` en los píxeles afectados (SH-02).
- Motivo físico adicional: con z_om → 0, ln(z_b/z_om) → ∞ y u* → 0. `water`
  reemplaza u* = 0 por 0.1 m s⁻¹; EarthFlux **no** sustituye valores (§13).

### 5.7 Ajuste por terreno montañoso — `CANDIDATA`

```text
f_terrain = 1 + (s_deg − 5)/20          (s_deg: pendiente en grados)
z_om,adj  = z_om · f_terrain
```

- Observada en `water` (`mountainous = TRUE`), comentada como "Allen et
  al., 2007, Eq. 35". Opción `slope.min1` de `water`: f_terrain = max(1,
  f_terrain), "as in the METRIC manual" (cita del manual: `TODO`).
- Sin el mínimo, en pendientes < 5° el factor **reduce** z_om hasta 25 %
  (s = 0 → 0.75; cálculo propio). Las notas terciarias señalan que esto
  afecta a la mayoría de los píxeles planos; la lectura correcta debe
  verificarse en la fuente (SH-03).
- En EarthFlux la pendiente llega en rad (RC-01): s_deg = s·180/π dentro de
  la función.
- Orden en `water`: primero el factor de terreno, después el mínimo de
  0.005 m. Se adopta el mismo orden salvo indicación contraria de la fuente.
- Escala: la pendiente media a 1 km subestima pendientes (RC-11 de
  `radiation-components.md`).

### 5.8 Desplazamiento d

- No interviene en rah del píxel según `water` (z₁, z₂ sobre d).
- Sí es relevante en el perfil de la **estación** (§6.1): `water` lo
  ignora; FAO-56 Ec. 47 lo incluye implícitamente (cálculo propio, §6.1).

---

## 6. Viento a altura de mezcla y velocidad de fricción (u*)

### 6.1 Extrapolación desde la estación — `CANDIDATA`

Perfil logarítmico neutral sobre la superficie de la estación:

```text
u*_w = k · u_x / ln((z_x − d_w)/z_om,w)
u_b  = (u*_w / k) · ln((z_b − d_w)/z_om,w)
     = u_x · ln((z_b − d_w)/z_om,w) / ln((z_x − d_w)/z_om,w)          [m s⁻¹]
```

- u_x: viento medido a la altura z_x [m] (contrato `forcing`:
  `wind_speed` + altura, `ARCHITECTURE.md` §4); z_b = 200 m.
- `water` (`calcH()`) usa esta forma **con d_w = 0** y z_om,w = 0.015 m
  por defecto, "about 0.123 times the height of the vegetation around the
  station (Allen et al., 1998)… 0.015 m for … clipped grass 0.12 m tall"
  (Allen et al., 2007, "Eq. 32", según su roxygen).
- **Contraste con FAO-56 (cálculo propio):** con h = 0.12 m, el Recuadro 4
  da z_om = 0.01476 m y d = 0.08 m. Entonces ln((2 − 0.08)/0.01476) =
  4.8682 ≈ 4.87, y ln((z − 0.08)/0.01476) = ln(67.75·z − 5.420) ≈
  ln(67.8·z − 5.42): **la Ec. 47 de FAO-56 es exactamente este perfil con
  d = 0.08 m y z_om = 0.01476 m**, normalizado a 2 m. Por tanto incluir d_w
  es coherente con FAO-56; omitirlo es la convención de `water`.
- Efecto de d_w (cálculo propio, u_x = 3 m s⁻¹ a 2 m): u_b = 5.8236 m s⁻¹
  sin d (z_om,w = 0.015) frente a 5.8628 m s⁻¹ con d = 0.08 y z_om,w =
  0.01476 (+0.67 %). Pequeño, pero sistemático (SH-04).
- Supuesto: u_b es aproximadamente uniforme en la escena (concepto de
  altura de mezcla). Con forzamiento espacial (GWR, hipótesis H1), u_b puede
  ser una superficie: todas las funciones aceptan vectores por píxel
  (`SCIENTIFIC_SPEC.md` §1.2; SH-05).

### 6.2 Viento bajo — sin piso silencioso

- `water` impone u_b ≥ `u200.min` = 2 m s⁻¹ con warning, y documenta que es
  "a choice of this package, not of Allen et al. (2007)". Versiones previas
  reemplazaban u_b < 1 m s⁻¹ por 4 m s⁻¹ (discontinuo; `NEWS`).
- EarthFlux: **no** se aplica piso por defecto. Viento bajo → flag
  `EF_LOW_WIND` (umbral `TODO`, requiere referencia). Un piso opcional,
  explícito y registrado en la procedencia (`EF_WIND_FLOOR_APPLIED`) es
  decisión abierta (SH-06). La no convergencia a viento bajo se reporta por
  §11.6, no se oculta.

### 6.3 Ajuste del viento por elevación (montaña) — `CANDIDATA`

```text
u_b,adj = u_b · (1 + 0.1 · (z − z_w)/1000)          (z, z_w en m)
```

- Observada en `water` con `mountainous = TRUE` (z_w: elevación de la
  estación). Sin número de ecuación en su roxygen; fuente primaria `TODO`.
- Con forzamiento espacial, z_w deja de ser único: decisión SH-07.

### 6.4 u* por píxel — `CANDIDATA`

```text
u* = k · u_b / (ln(z_b / z_om) − ψ_m(z_b))          [m s⁻¹]
```

- Neutral: ψ_m = 0. Corregida: ψ_m(z_b) desde §10.
- Observada en `water` (`calcH()` para el valor inicial, `rahStep()` para
  la corregida).
- Si ln(z_b/z_om) − ψ_m(z_b) ≤ 0 (muy inestable sobre superficie rugosa),
  u* no es válida: `water` devuelve `NA`. EarthFlux: `NA` + flag
  `EF_USTAR_INVALID` en el píxel; en un ancla → error de calibración
  (§13).

---

## 7. Resistencia aerodinámica (rah)

### 7.1 Forma — `CANDIDATA`

```text
rah = (ln(z₂/z₁) − ψ_h(z₂) + ψ_h(z₁)) / (k · u*)          [s m⁻¹]
```

- z₁ = 0.1 m, z₂ = 2 m (`water`); neutral: ψ_h = 0 y rah = ln(20)/(k·u*).
- Forma neutral registrada en `SCIENTIFIC_SPEC.md` §3: rah = ln(z₂/z₁)/(u*·k).
- Comparación conceptual con FAO-56 Ec. 4 (`VERIFICADA` como contenido de
  FAO-56): allí r_a usa z_oh = 0.1·z_om como límite inferior para calor; en
  METRIC (según `water`) el límite inferior es una altura fija z₁ = 0.1 m y
  el producto de dos logaritmos se reemplaza por ln(z_b/z_om) dentro de u*.
  No son la misma formulación; FAO-56 solo verifica k y la forma
  logarítmica neutral, no z₁ ni z₂.
- FAO-56 advierte (Cap. 2, texto de Ec. 4) que la ecuación neutral está
  restringida a estabilidad neutral y que pasos horarios o menores "may
  require the inclusion of corrections for stability": motivación de §10.

### 7.2 Dominio

u* > 0 y finito; z₂ > z₁ > 0. rah ≤ 0 o no finita → no válida (`NA` +
`EF_USTAR_INVALID`, o error en anclas).

---

## 8. Densidad del aire (ρ_air) y calor específico (c_p)

### 8.1 Forma de FAO-56 — `VERIFICADA` como contenido de FAO-56; uso en METRIC `CANDIDATA`

```text
ρ_air = P / (T_Kv · R),   T_Kv = 1.01 · (T + 273)          (FAO-56, Cap. 2, Recuadro 6)
```

con P en kPa, R = 0.287 kJ kg⁻¹ K⁻¹, T en °C. Con T en K y unidades SI:

```text
ρ_air = 1000 · P / (1.01 · T_K · 287)          [kg m⁻³]
```

- `water` usa esta forma (`air.density` en `calcH()`), con T = Ts.
- Diferencia por el desplazamiento 273 (FAO-56) frente a 273.15 (convención
  del paquete): 0.15 K sobre ≈ 300 K → ≈ 5 × 10⁻⁴ relativo (cálculo
  propio). Decidir y documentar (SH-08).

### 8.2 Variante de `water` (`airDensity()`) — `CANDIDATA`

```text
T_a   = Ts − dT
ρ_air = 349.467 · ((T_a − 0.0065·z)/T_a)^5.26 / T_a
```

- Comentario de `water`: "Allen et al., 2007, Eq. 37": 1000·P/(1.01·T_a·287)
  con P "de la atmósfera estándar para esa temperatura". Equivale (cálculo
  propio: 1000·101.3/(1.01·287) = 349.467) a la forma 8.1 con T = T_a y con
  P(z) evaluada reemplazando 293 K por T_a.
- Las notas terciarias afirman que la Ec. 37 del artículo construye P con
  293 K (FAO-56 Ec. 7) y divide por T_a; si es así, la variante de `water`
  se desvía en la presión. **No verificado** (SH-08).
- Magnitud (cálculo propio): T = 316 K, z = 700 m → 1.018513 kg m⁻³ (8.1
  con P de FAO-56 Ec. 7) frente a 1.024679 kg m⁻³ (8.2), +0.6 %.

### 8.3 c_p

- 1004 J kg⁻¹ K⁻¹ (`water`; `SCIENTIFIC_SPEC.md`) frente a 1013 J kg⁻¹ K⁻¹
  (FAO-56, Cap. 3, texto de Ec. 8: "For average atmospheric conditions…").
  Fuente del valor METRIC: `TODO` (SH-09).
- **Sensibilidad (cálculo propio):** en la calibración, dT_i = H_i·rah_i/
  (ρ_i·c_p) en las anclas, de modo que a y b son proporcionales a 1/c_p;
  luego H_p = ρ_p·c_p·(a + b·Ts_datum,p)/rah_p **no depende de c_p** para
  un rah dado. c_p solo entra en H a través de L (§10.1). Del mismo modo, un
  factor multiplicativo común en ρ (p. ej., el 1.01 o el 273 vs 273.15) se
  cancela; solo importan las razones ρ_p/ρ_ancla. Esto no elimina la
  necesidad de una fuente, pero acota su efecto.

### 8.4 Presión y temperatura de entrada

- P: `ef_air_pressure(elevation)` (FAO-56 Ec. 7; `radiation-components.md`
  §6.2, archivo compartido según RC-17) o P medida/regionalizada (RC-08).
  `ef_air_density()` recibe `pressure` y `air_temperature`, no la
  elevación: es agnóstica al origen de P.
- Temperatura: T_a = Ts − dT (temperatura del aire cerca de la superficie,
  implícita en dT) o Ts. `water` usa T_a en la H de cada iteración, pero Ts
  en la densidad usada para L (§17). Propuesta: **T_a = Ts − dT en todo el
  módulo**, con dT de la iteración previa (dT₀ = 0 en la primera) (SH-08,
  SH-19). Ts (no T_a) en el primer paso implica ρ evaluada con Ts.

---

## 9. dT = a + b·Ts_datum: ajuste por elevación y solución desde las anclas

### 9.1 Ts referida a un datum de elevación — `CANDIDATA`

```text
Ts_datum = Ts + Γ · (z − z_datum)          [K]
```

- Observada en `water` (`calcH()`, `METRIC.EB()`), con Γ = 6.49 K km⁻¹
  ("lapse rate … of the surface temperature with elevation") y z_datum =
  elevación de la estación. Las notas terciarias afirman que Allen et al.
  (2007) usan un "customized lapse rate": **valor y fuente `TODO`** (SH-13).
- Ts_datum se usa **solo** para dT; ρ, P, z_om y u_b usan la elevación real.
- **El valor de z_datum no afecta H (cálculo propio):** cambiar z_datum en Δ
  desplaza todas las Ts_datum en −Γ·Δ; el ajuste lineal con dos anclas lo
  absorbe en a (a' = a + b·Γ·Δ) y dT es idéntico en todos los píxeles. Solo
  Γ importa. Consecuencia para H1: con forzamiento espacial no hace falta
  una "elevación de estación"; basta un z_datum constante y explícito de
  escena (registrado en la procedencia, porque cambia el valor reportado
  de a).
- Selección de anclas: las notas terciarias señalan que `water` selecciona
  anclas sobre Ts y no sobre Ts_datum; corresponde a la especificación de
  anclas.

### 9.2 Inversión de dT en las anclas — `CANDIDATA`

```text
dT_i = H_target,i · rah_i / (ρ_air,i · c_p)          i ∈ {hot, cold}
```

### 9.3 Coeficientes — `CANDIDATA`

```text
b = (dT_hot − dT_cold) / (Ts_datum,hot − Ts_datum,cold)          [–]
a = dT_cold − b · Ts_datum,cold                                  [K]
```

- Observada en `water` (con nombres intercambiados, §4.2). Las notas
  terciarias indican que una ecuación del artículo para el intercepto
  ("Eq. 51") contiene una errata y que `water` ajusta el intercepto
  correctamente. **Verificar** (§19).
- Propiedad exacta (consistencia): a + b·Ts_datum,i = dT_i en ambas anclas
  y, con el mismo ρ_i y rah_i, H_i = ρ_i·c_p·dT_i/rah_i = H_target,i.
- Dominio: Ts_datum,hot ≠ Ts_datum,cold (si son iguales, b es indefinida →
  error). Ts_datum,hot < Ts_datum,cold → error ("¿anclas intercambiadas?",
  como en `water`). b ≤ 0 con anclas bien ordenadas (dT_hot ≤ dT_cold) →
  warning + flag `EF_DT_SLOPE_NONPOSITIVE`.

### 9.4 Fuera del rango de las anclas

- Píxeles con Ts_datum > Ts_datum,hot o < Ts_datum,cold usan la misma recta
  (extrapolación). No se recortan; se marcan (`EF_DT_EXTRAPOLATED_HOT`,
  `EF_DT_EXTRAPOLATED_COLD`). dT < 0 → H < 0 (posible, advección) → flag
  informativo `EF_DT_NEGATIVE`.
- Las notas terciarias mencionan una "pendiente de dT reducida por encima de
  Ts_hot" en el artículo (p. 389): `TODO` verificar; no se implementa sin
  fuente (SH-20).

---

## 10. Estabilidad de Monin-Obukhov

Todas las formas: `CANDIDATA` (observadas en `water`, `rahStep()`;
corroboradas por `bigleaf`; fuentes primarias Paulson, 1970, y Webb, 1970,
con citas verificadas en Crossref pero contenido no consultado).

### 10.1 Longitud de Monin-Obukhov

```text
L = − ρ_air · c_p · u*³ · T / (k · g · H)          [m]
```

- H > 0 (inestable) → L < 0; H < 0 (estable) → L > 0; H = 0 → neutral
  (|L| = ∞, ψ = 0): tratar explícitamente, sin dividir por cero.
- **Qué T y qué ρ:** `water` usa Ts y la densidad inicial (calculada con Ts,
  no actualizada); `bigleaf` usa T_aire. Propuesta: T = T_a = Ts − dT y la
  ρ de la iteración (SH-10). `TODO`: verificar en Allen et al. (2007).
- g: §4.3.

### 10.2 Inestable (L < 0) — forma tipo Paulson

```text
x(z)    = (1 − 16 · z/L)^(1/4)
ψ_m(z)  = 2·ln((1 + x)/2) + ln((1 + x²)/2) − 2·arctan(x) + π/2
ψ_h(z)  = 2·ln((1 + x²)/2)
```

- Evaluadas en z_b (ψ_m) y en z₂, z₁ (ψ_h).
- `bigleaf` escribe ψ_h = 2·ln((1 + y)/2) con y = (1 − 16ζ)^(1/2); como
  y = x², es la misma expresión (cálculo propio).

### 10.3 Estable (L > 0) — forma log-lineal tipo Webb

```text
ψ_h(z)   = −5 · z/L                 (z = z₂, z₁)
ψ_m(z_b) = −5 · (2/L)               ← tal como en `water`
```

- **Punto crítico a verificar (SH-11):** `water` evalúa ψ_m de la altura de
  mezcla con **2/L**, no con z_b/L = 200/L. Las notas terciarias afirman que
  el artículo especifica el caso estable "con z = 2 m". La diferencia es
  enorme (cálculo propio, §14.4): con L = 41.97 m, −5·(2/L) = −0.238 y
  −5·(200/L) = −23.8.
- Estabilidad fuerte: Webb (1970) trata la "extensión a estabilidad
  fuerte"; el rango de validez de la forma log-lineal y el comportamiento
  para z/L grandes son `TODO`. Flag propuesto `EF_STRONGLY_STABLE` (umbral
  `TODO`).

### 10.4 Alternativas no evaluadas

`bigleaf` ofrece también la formulación "Businger_1971" (coeficientes
distintos) y cita Dyer & Hicks (1970), Dyer (1974), Businger et al. (1971)
y Foken (2008). No se adoptan: METRIC (según `water`) usa la forma de
§10.2–10.3. Citas `TODO: verify full citation`.

---

## 11. Iteración de calibración

### 11.1 Por qué se itera

rah depende de L, que depende de H, que depende de dT y rah; dT a su vez se
calibra con rah en las anclas. Se resuelve por punto fijo.

### 11.2 Fase A — iteración en las anclas

Estado inicial (k = 0): u*_i y rah_i neutrales (§6.4, §7.1), dT_i = 0.

En cada iteración k = 1, 2, …:

1. ρ_i,k con T_a = Ts_i − dT_i,k−1 (§8.4).
2. dT_i,k = H_target,i · rah_i,k−1 / (ρ_i,k · c_p) (§9.2).
3. a_k, b_k (§9.3).
4. H_i,k = ρ_i,k · c_p · (a_k + b_k·Ts_datum,i)/rah_i,k−1 — **igual a
   H_target,i por construcción** (comprobación interna, no un ajuste).
5. L_i,k (§10.1) con H_i,k, u*_i,k−1, T_a = Ts_i − dT_i,k y ρ_i,k.
6. ψ_m(z_b), ψ_h(z₂), ψ_h(z₁) (§10.2–10.3) → u*_i,k (§6.4) → rah_new,i
   (§7.1).
7. Amortiguación (§11.4): rah_i,k = (1 − ω)·rah_new,i + ω·rah_i,k−1.
8. Criterio de convergencia (§11.3) sobre rah_i,k frente a rah_i,k−1.

**Cierre:** al converger, repetir los pasos 1–3 con el rah final para
obtener (a*, b*) y **no** actualizar rah después. Así las anclas reproducen
H_target exactamente con (a*, b*) (§14.6).

### 11.3 Criterio de convergencia

- `water`: |Δrah|/rah < 1 % en el promedio de las anclas calientes y en el
  de las frías, seguido de una iteración adicional.
- Propuesta: max_i |rah_i,k − rah_i,k−1| / rah_i,k < `tol` (por ancla, no
  por promedio), con `tol` por defecto `CANDIDATA` 0.01 (valor de `water`,
  sin fuente primaria) (SH-16). Registrar además |Δa|, |Δb| por iteración.
- Sensibilidad observada en el caso sintético (§14.5): con `tol` = 0.01 la
  iteración se detiene en k = 6 con a = −86.27 K, mientras el punto fijo es
  a* = −86.85 K (0.7 %). El valor de `tol` importa y debe documentarse.

### 11.4 Amortiguación

- `water`: `damping` ω ∈ [0, 1), por defecto 0; rah = (1 − ω)·nuevo +
  ω·anterior; documentado como "a choice of this package" que mantiene la
  misma solución y ayuda cuando la iteración oscila.
- Propiedad comprobada en el caso sintético (§14.5): ω = 0 y ω = 0.5
  convergen al mismo punto fijo (a*, b* coinciden hasta ≈ 10⁻⁷ en valor
  absoluto). Es un criterio de test.
- Alternativa mencionada en las notas terciarias (iterar sobre log rah): no
  evaluada.

### 11.5 Máximo de iteraciones

`maxit`, por defecto 20 en `water` (elección de diseño, no científica). Se
propone el mismo valor por defecto como argumento explícito (SH-16).

### 11.6 No convergencia y divergencia (nunca en silencio)

| Situación | Comportamiento propuesto |
|---|---|
| `maxit` alcanzado sin cumplir `tol` | Devolver el último iterado con `converged = FALSE`, historial completo; **warning** con clase `earthflux_convergence_warning`; flag de escena `EF_H_NOT_CONVERGED` en todos los píxeles |
| a, b o u* no finitos, o u* ≤ 0 en un ancla | **Error** con clase `earthflux_calibration_error` (`water` también detiene: `checkIteration()`) |
| u* inválida en un píxel (Fase B) | `NA` en ese píxel + flag `EF_USTAR_INVALID` |
| Píxel sin convergencia en Fase B | Último iterado + flag `EF_H_PIXEL_NOT_CONVERGED`; conteo en el resumen de diagnósticos |

### 11.7 Fase B — todos los píxeles

Dos estrategias:

- **P1 (como `water`):** reproducir en cada píxel la misma secuencia de
  (a_k, b_k) de la Fase A, con el mismo número de pasos, partiendo del
  estado neutral. La convergencia por píxel no se comprueba.
- **P2 (propuesta):** con (a*, b*) fijos, dT_p = a* + b*·Ts_datum,p y
  ρ_p (T_a = Ts_p − dT_p) quedan fijos; iterar por píxel solo la
  estabilidad (H_p → L → ψ → u* → rah) hasta su propia convergencia, con
  flag por píxel. Las anclas reproducen H_target (mismo punto fijo; §14.6).

Recomendación: **P2** (resultado depende solo de (a*, b*) y no del camino de
la Fase A; convergencia comprobada por píxel). P1 solo para la verificación
cruzada con `water` (SH-15).

---

## 12. Descomposición en funciones y diseño vectorizado

Todas las funciones numéricas: vectores/matrices `numeric`, reciclado de
longitud 1, `dim` común, NA propagado y errores con clase, igual que
`ef_net_radiation()` y `radiation-components.md` §4.5–4.7. Sin rásteres ni
objetos de sensor (`ARCHITECTURE.md` §1, §3).

| Función (propuesta) | Entradas (unidades) | Salida | ¿Exportar? |
|---|---|---|---|
| `ef_zom(method, lai, ndvi, albedo, coef_1, coef_2, f_lai, height, slope = NULL, terrain_min1, zom_min)` | LAI [m² m⁻²], NDVI [–], α [–], h [m], s [rad] | z_om [m] | Sí. Despachador delgado sobre funciones internas por método, como en `soil-heat-flux.md` §5 |
| `ef_blending_wind(wind_speed, height, zom_station, d_station = 0, blending_height = 200)` | u_x [m s⁻¹], z_x [m], z_om,w [m], d_w [m] | u_b [m s⁻¹] | Sí (lo usa también `forcing`) |
| `ef_ustar(u_blend, zom, psi_m = 0, blending_height = 200)` | m s⁻¹, m, – | u* [m s⁻¹] | Sí |
| `ef_rah(u_star, psi_h_z2 = 0, psi_h_z1 = 0, z1 = 0.1, z2 = 2)` | m s⁻¹, –, m | rah [s m⁻¹] | Sí |
| `ef_air_density(pressure, air_temperature)` | kPa, K | ρ_air [kg m⁻³] | Sí |
| `ef_ts_datum(lst, elevation, datum_elevation, lapse_rate)` | K, m, m, K m⁻¹ | Ts_datum [K] | Interna o exportada (SH-17) |
| `ef_dt_coef(ts_datum_hot, ts_datum_cold, dt_hot, dt_cold)` | K | `list(a [K], b [–])` | Sí |
| `ef_sensible_heat(air_density, dt, rah, cp)` | kg m⁻³, K, s m⁻¹, J kg⁻¹ K⁻¹ | H [W m⁻²] | Sí |
| `monin_obukhov_length()`, `stability_psi()` | ver §10 | L [m]; ψ_m, ψ_h [–] | Internas (API pequeña) |
| Driver de calibración (nombre provisional `ef_calibrate_h(anchors, pixels, control)`) | Tabla de anclas (§2.2) + vectores de píxel | Objeto con a*, b*, `converged`, `iterations`, historial, estado en anclas, configuración; y H, dT, rah, u*, L, flags por píxel | **Decisión abierta (SH-17)** |
| Control (nombre provisional `ef_h_control(tol, maxit, damping, stable_psi_m_height, …)`) | – | Lista validada | Según SH-17 |

Diseño para `terra`, bloques y paralelismo (`ARCHITECTURE.md` §6.2–6.3,
§6.6):

- La **Fase A** opera solo sobre los valores de las anclas (vectores
  cortos): secuencial, sin rásteres.
- La **Fase B** es una función interna puramente elemento a elemento
  (`sensible_heat_pixels(lst, ts_datum, elevation, zom, u_blend, pressure,
  a, b, control)`), sin dependencia entre píxeles. El envoltorio ráster la
  aplica con `terra::lapp()` por bloques (patrón `readStart()`/
  `writeStart()`) o con `terra::app(..., cores = )`.
- Garantías a testear: el tamaño de bloque no cambia el resultado;
  secuencial = paralelo (resultado determinista, sin semillas).
- Las constantes (k, c_p, g, z₁, z₂, z_b) son internas nombradas; el
  driver registra los valores usados en la procedencia.

---

## 13. NA, dominio y errores con clase

- `NA`/`NaN` se propagan en las funciones numéricas; el flag `EF_INPUT_NA`
  lo construye la orquestación (`radiation-components.md` §4.6).
- En las **anclas** un `NA` es un error (`earthflux_calibration_error`): la
  calibración no puede continuar (como `anchorCells()` de `water`).
- Dominio (error `earthflux_domain_error`, ignorando NA): z_om > 0;
  u_x ≥ 0; z_x > d_w ≥ 0; z_b > d_w; z_om,w > 0; u* > 0 como entrada de
  `ef_rah()`; z₂ > z₁ > 0; P > 0; T > 0 K; c_p > 0;
  rah > 0 en `ef_sensible_heat()`; LAI ≥ 0; α > 0 (método custom); f ∈
  [0, 1]; h ≥ 0; Γ ≥ 0 (`water` exige ≥ 0; un gradiente negativo requeriría
  justificación); `tol` > 0; `maxit` entero ≥ 1; ω ∈ [0, 1).
- `Inf` rechazado en todas las entradas.
- u_b = 0 es posible (calma) pero produce u* = 0 y rah infinita: flag
  `EF_LOW_WIND`; en anclas → error de calibración con mensaje explícito.
- No se truncan ni sustituyen valores (principio 6): no hay u* = 0.1
  sustituta, ni piso de viento implícito, ni recorte de dT o H.
- Clases nuevas propuestas: `earthflux_calibration_error` (subclase de
  `earthflux_error`) y `earthflux_convergence_warning` (subclase de
  `earthflux_warning`; constructor ya existente en `R/utils.R`).

---

## 14. Casos numéricos

Calculados por el autor a partir de las formas `CANDIDATA` de este
documento; verifican aritmética, no física. Constantes del caso: k = 0.41,
c_p = 1004 J kg⁻¹ K⁻¹, g = 9.807 m s⁻², z_b = 200 m, z₁ = 0.1 m, z₂ = 2 m,
Γ = 6.49 × 10⁻³ K m⁻¹, P desde FAO-56 Ec. 7, ρ por §8.1 con T en K.

### 14.1 Neutral: viento a altura de mezcla y u*

Estación: u_x = 3 m s⁻¹, z_x = 2 m, z_om,w = 0.015 m, d_w = 0.

1. ln(2/0.015) = ln(133.333) = 4.892852.
2. ln(200/0.015) = ln(13 333.33) = 9.498022.
3. u*_w = 0.41 × 3 / 4.892852 = 0.251387 m s⁻¹.
4. u_b = 3 × 9.498022 / 4.892852 = **5.823611 m s⁻¹**.

Variante con d_w = 0.08 m y z_om,w = 0.01476 m (FAO-56 Recuadro 4, h =
0.12 m): ln((200 − 0.08)/0.01476) = 9.513752; ln((2 − 0.08)/0.01476) =
4.868160; u_b = 5.862843 m s⁻¹.

Píxeles (neutral, ψ = 0), con ln(z₂/z₁) = ln 20 = 2.995732:

| z_om (m) | ln(200/z_om) | u* (m s⁻¹) | k·u* | rah (s m⁻¹) |
|---|---|---|---|---|
| 0.06 | 8.111728 | 0.294349 | 0.120683 | 24.8231 |
| 0.005 | 10.596635 | 0.225324 | 0.092383 | 32.4273 |
| 0.02 | 9.210340 | 0.259239 | 0.106288 | 28.1850 |

### 14.2 Presión y densidad

| z (m) | P (kPa) | T (K) | ρ_air §8.1 (kg m⁻³) | ρ_air §8.2 (kg m⁻³) |
|---|---|---|---|---|
| 500 | 95.5276 | 300 | 1.098511 | 1.100024 |
| 700 | 93.2947 | 316 | 1.018513 | 1.024679 |
| 500 | 95.5276 | 308 | 1.069979 | 1.073057 |

Ejemplo: 1000 × 95.5276 / (1.01 × 300 × 287) = 95 527.6 / 86 961 =
1.098511.

### 14.3 Calibración de dT (neutral, primer paso, ρ con T = Ts porque dT₀ = 0)

z_datum = 500 m.

| Ancla | Ts (K) | z (m) | z_om (m) | Rn | G | LE_target | H_target (W m⁻²) |
|---|---|---|---|---|---|---|---|
| cold | 300 | 500 | 0.06 | 600 | 50 | 520 | 30 |
| hot | 316 | 700 | 0.005 | 480 | 110 | 0 | 370 |

1. Ts_datum,cold = 300 K; Ts_datum,hot = 316 + 0.00649 × 200 = 317.298 K.
2. dT_cold = 30 × 24.823118 / (1.098511 × 1004) = 0.675211 K.
3. dT_hot = 370 × 32.427309 / (1.018513 × 1004) = 11.733091 K.
4. b = (11.733091 − 0.675211) / (317.298 − 300) = **0.63925775**.
5. a = 0.675211 − 0.63925775 × 300 = **−191.102115 K**.
6. Comprobación: H_cold = 1.098511 × 1004 × 0.675211 / 24.823118 = 30.000000;
   H_hot = 370.000000 W m⁻².
7. Píxel interior (Ts = 308 K, z = 500 m, z_om = 0.02 m): dT = −191.102115 +
   0.63925775 × 308 = 5.789273 K; H = 1.069979 × 1004 × 5.789273 /
   28.1850 = **220.6552 W m⁻²**.
8. Invariancia del datum: con z_datum = 0 m, todas las Ts_datum aumentan
   3.245 K (0.00649 × 500); a cambia, dT del paso 7 no.

### 14.4 Un paso de estabilidad (ancla caliente, inestable)

Con ρ = 1.018513, u* = 0.225324, T = 316 K (dT₀ = 0), H = 370:

1. L = −1.018513 × 1004 × 0.225324³ × 316 / (0.41 × 9.807 × 370) =
   **−2.484793 m**.
2. x(200) = (1 + 16 × 200/2.484793)^(1/4) = 5.991688; x(2) = 1.930120;
   x(0.1) = 1.132322.
3. ψ_m(200) = 4.178174; ψ_h(2) = 1.719595; ψ_h(0.1) = 0.263944.
4. u* = 0.41 × 5.823611 / (10.596635 − 4.178174) = 0.372002 m s⁻¹.
5. rah = (2.995732 − 1.719595 + 0.263944) / (0.41 × 0.372002) =
   **10.097518 s m⁻¹** (desde 32.4273 neutral).

Caso estable ilustrativo (ancla fría con H = −50 W m⁻², ρ = 1.098511, u* =
0.294349, T = 300 K): L = 41.9718 m; −5·(2/L) = −0.238255; −5·(200/L) =
−23.825502; −5·(0.1/L) = −0.011913. Muestra la magnitud de SH-11.

### 14.5 Diseño del test de iteración (escena sintética de 2 anclas)

Escena: las dos anclas de §14.3 y el píxel interior de §14.3, u_b =
5.823611 m s⁻¹ uniforme. Configuración: Fase A según §11.2 (ρ con T_a =
Ts − dT_{k−1}; L con T_a = Ts − dT_k y ρ de la iteración; ψ estable con
2/L, no activado porque ambas anclas son inestables).

Valores provisionales de orientación, obtenidos con un script propio de
trabajo (no versionado) que implementa las formas `CANDIDATA` de este
documento. **No son referencias independientes**: deben regenerarse cuando
las formas pasen a `VERIFICADA` y se usan para diseñar el test, no para
validar la física.

| Configuración | Iteraciones | a (K) | b (–) | rah_cold | rah_hot |
|---|---|---|---|---|---|
| ω = 0, tol = 0.01 | 6 | −86.27 | 0.28936 | 19.8266 | 15.7205 |
| ω = 0.5, tol = 0.01 | 7 | −88.133 | 0.29558 | 19.8564 | 15.7971 |
| ω = 0, tol = 10⁻¹⁰ | 24 | −86.84546 | 0.2912792 | 19.82518 | 15.68989 |
| ω = 0.5, tol = 10⁻¹⁰ | 34 | −86.84546 | 0.2912792 | 19.82518 | 15.68989 |

Fase B (P2) con (a*, b*) del punto fijo: el ancla fría vuelve a H = 30 y la
caliente a H = 370 W m⁻² (|error| < 10⁻⁹); el píxel interior converge a
dT = 2.868528 K, rah = 17.1505 s m⁻¹, H = 181.3655 W m⁻².

Propiedades que el test debe comprobar (independientes de los valores
provisionales):

1. Convergencia en ≤ `maxit` con `converged = TRUE`.
2. Mismo punto fijo con ω = 0 y ω = 0.5 (tolerancia ajustada).
3. H en las anclas = H_target tras el cierre (§11.2) y tras la Fase B.
4. Monotonía: con H > 0 en ambas anclas, rah corregida < rah neutral.
5. Forzando `maxit = 1` con `tol` muy pequeño: warning con clase
   `earthflux_convergence_warning`, `converged = FALSE`, flag
   `EF_H_NOT_CONVERGED`; nunca silencio.
6. Anclas intercambiadas o Ts_datum iguales → `earthflux_calibration_error`.
7. Bloques y paralelo: la Fase B sobre el vector completo = la Fase B por
   trozos (p. ej., 3 bloques) = en paralelo con 2 núcleos.

### 14.6 Comprobaciones de consistencia

- dT reproduce exactamente los objetivos de las anclas: a + b·Ts_datum,i =
  dT_i (tolerancia relativa 10⁻¹²).
- H en las anclas = H_target tras la convergencia (tolerancia relativa
  10⁻⁹; en la Fase B, la del criterio por píxel).
- Invariancia del datum (§9.1): H idéntico con dos valores de z_datum.
- Invariancia de c_p en neutral (§8.3): con rah fijo, H por píxel idéntico
  con c_p = 1004 y c_p = 1013.

### 14.7 Tolerancias

Valores de referencia impresos con 6 decimales: tolerancia absoluta igual a
media unidad del último dígito impreso (5 × 10⁻⁷ en la unidad de la
columna; 5 × 10⁻⁵ s m⁻¹ para rah con 4 decimales). Identidades exactas
(consistencia): tolerancia relativa explícita (10⁻¹² o 10⁻⁹), con
`expect_lt()` como en `ef_net_radiation.md` §7.1.

---

## 15. Tests planificados

| Archivo | Test | Qué verifica |
|---|---|---|
| `test-aerodynamics.R` | z_om por método | 0.018·LAI; exponencial custom; Perrier continuo en f = 0.5; mínimo aplicado y marcado; factor de terreno con y sin mínimo 1; pendiente en rad |
| `test-aerodynamics.R` | Viento | §14.1 con y sin d_w; u_b proporcional a u_x |
| `test-aerodynamics.R` | u*, rah neutral | Tabla §14.1 |
| `test-aerodynamics.R` | Estabilidad | §14.4; H = 0 → ψ = 0 sin división por cero; ramas estable/inestable; u* inválida → `NA` |
| `test-sensible-heat.R` | ρ_air | Tabla §14.2 |
| `test-sensible-heat.R` | dT y H | §14.3 completo; invariancias §14.6 |
| `test-sensible-heat.R` | Iteración | Propiedades 1–7 de §14.5 |
| ambos | Dominio, NA, clases | §13; `Inf`; tipos no numéricos; longitudes; `dim` |
| `inst/verification/` (fuera del tarball) | Cruce con `water` | Estrategia P1 con la configuración de `water` (§17), solo si `water` está instalado |

---

## 16. Flags propuestos (no registrar todavía)

Se registran en `ef_flag_registry()` solo al implementar y, si dependen de
un umbral, cuando el umbral tenga referencia (`R/diagnostics.R`).

| Código | Condición | Severidad | ¿Umbral? |
|---|---|---|---|
| `EF_ZOM_FLOOR_APPLIED` | z_om elevada al mínimo | info | No (si se adopta el mínimo) |
| `EF_ZOM_TERRAIN_ADJUSTED` | Se aplicó el factor de terreno | info | No |
| `EF_LOW_WIND` | u_b bajo un umbral | warning | **Sí** `TODO` |
| `EF_WIND_FLOOR_APPLIED` | Se usó un piso explícito de u_b (si SH-06 lo admite) | warning | No |
| `EF_USTAR_INVALID` | u* ≤ 0 o no finita tras la corrección | warning | No |
| `EF_STRONGLY_STABLE` | z/L sobre un umbral | warning | **Sí** `TODO` |
| `EF_H_NOT_CONVERGED` | Fase A sin convergencia en `maxit` | warning (escena) | No (dados `tol` y `maxit`) |
| `EF_H_PIXEL_NOT_CONVERGED` | Fase B sin convergencia en el píxel | warning | No |
| `EF_DT_EXTRAPOLATED_HOT` / `_COLD` | Ts_datum fuera de [Ts_datum,cold, Ts_datum,hot] | info | No |
| `EF_DT_NEGATIVE` | dT < 0 (H < 0) | info | No |
| `EF_DT_SLOPE_NONPOSITIVE` | b ≤ 0 con anclas bien ordenadas | warning | No |
| `EF_H_EXCEEDS_AVAILABLE` | Rn − G > 0 y H > Rn − G (LE < 0 aguas abajo; ver `EF_ET_NEGATIVE`) | warning | No |
| `EF_ANCHOR_DT_SMALL` | Ts_datum,hot − Ts_datum,cold bajo un umbral (compartido con anclas) | warning | **Sí** `TODO` (`water` usa 5 K por elección propia) |

---

## 17. Verificación cruzada con `water`: diferencias esperadas

Según `VALIDATION_PLAN.md` §1.3. Diferencias que deben documentarse, no
forzarse:

| Componente | `water` v1.0 (observado) | EarthFlux (propuesto) | Efecto |
|---|---|---|---|
| Notación de dT | dT = a·Ts_datum + b | dT = a + b·Ts_datum | Mapear a ↔ b |
| d en la estación | No | Opción d_w (SH-04) | +0.67 % en u_b (§14.1) |
| Piso de viento | u_b ≥ 2 m s⁻¹ con warning | Sin piso por defecto; flag | Grande a viento bajo |
| u* = 0 | Sustituida por 0.1 m s⁻¹ | `NA`/error, sin sustitución | Solo casos degenerados |
| ρ en H | §8.2 (P con T_a) | §8.1 con T_a (SH-08) | ≈ 0.6 % en ρ; en gran parte absorbido por la calibración (§8.3) |
| ρ y T en L | ρ inicial (con Ts) y Ts, no actualizadas | ρ y T_a de la iteración (SH-10) | Pequeño |
| ρ en dT de anclas vs en H | dT de anclas con ρ(dT_{k−1}); H con ρ(dT_k): H_ancla ≈ H_target | Mismo ρ en ambos: H_ancla = H_target exacto | Pequeño |
| Convergencia | Promedio por clase, 1 %, más una iteración | Por ancla (SH-16) | Pequeño |
| Fase B | P1 (reproduce secuencia de a, b) | P2 (convergencia por píxel) | Pequeño si converge; distinto si no |
| Varias anclas | `"mean"` / `"lm"` (último par) | SH-14 | Según escena |

---

## 18. Decisiones abiertas

| ID | Decisión | Opciones | Recomendación provisional | Bloquea |
|---|---|---|---|---|
| SH-01 | Método de z_om por defecto con MODIS 1 km | LAI lineal / custom NDVI-α / Perrier / tabla por cobertura | LAI lineal como base; tabla por cobertura cuando exista fuente; Perrier solo con mapa de alturas | §5 |
| SH-02 | Mínimo de z_om | Aplicar 0.005 m con flag / no aplicar | Aplicar con flag, tras verificar p. 386 | §5.6 |
| SH-03 | Ajuste por terreno | Sin ajuste / factor / factor con mínimo 1 | Desactivado por defecto hasta verificar Eq. 35 y el manual | §5.7 |
| SH-04 | Perfil de la estación | d_w = 0 (`water`) / d_w y z_om,w desde h (FAO-56) | Argumentos explícitos; defecto coherente con FAO-56 (h = 0.12 m) | §6.1 |
| SH-05 | u_b uniforme vs espacial | Escalar de escena / superficie (GWR) | Aceptar ambos; registrar cuál (H1) | §6.1 |
| SH-06 | Viento bajo | Sin piso + flag / piso explícito opcional | Sin piso por defecto; umbral del flag con referencia | §6.2 |
| SH-07 | Ajuste del viento por elevación | No / sí con z_w de estación / sí con datum de escena | No implementar hasta verificar fuente | §6.3 |
| SH-08 | Forma y temperatura de ρ_air; 273 vs 273.15 | §8.1 con T_a / §8.2 / con Ts | §8.1 con T_a y P de `ef_air_pressure()` o medida | §8 |
| SH-09 | c_p | 1004 / 1013 | Verificar en Allen et al. (2007) | §8.3 |
| SH-10 | T, ρ y g en L | Ts / T_a; ρ inicial / iterada; 9.807 / otro | T_a y ρ iterada; g con referencia | §10.1 |
| SH-11 | Altura de ψ_m estable en z_b | 2/L (`water`) / 200/L | **Bloqueante**: verificar en la fuente primaria | §10.3 |
| SH-12 | Notación de a y b | SPEC (a intercepto) / la del artículo | Mantener SPEC salvo que el artículo difiera | §4.2 |
| SH-13 | Γ y z_datum | 6.49 K km⁻¹ fijo / argumento; z_datum de estación / constante de escena | Γ como argumento con valor documentado; z_datum constante explícito | §9.1 |
| SH-14 | Agregación de varias anclas | Promedio de entradas / promedio de dT / por par / regresión | Coordinar con la especificación de anclas; caso base 1 valor por clase | §2.3 |
| SH-15 | Estrategia de Fase B | P1 / P2 | P2; P1 solo para verificación | §11.7 |
| SH-16 | `tol`, `maxit`, ω por defecto; criterio por ancla o promedio | – | 0.01, 20, 0 por ancla; reportar Δa, Δb | §11.3–11.5 |
| SH-17 | Driver exportado o interno; exportar `ef_ts_datum()` y auxiliares de estabilidad | – | Driver exportado (usuarios avanzados con anclas propias); auxiliares internas | §12 |
| SH-18 | Clases de condición nuevas | `earthflux_calibration_error`, `earthflux_convergence_warning` | Adoptar | §13 |
| SH-19 | Estado inicial | dT₀ = 0 (ρ con Ts) / otro | dT₀ = 0, documentado | §11.2 |
| SH-20 | Tratamiento de Ts_datum > Ts_datum,hot | Misma recta + flag / pendiente reducida (si la fuente lo indica) | Misma recta + flag hasta verificar p. 389 | §9.4 |

---

## 19. Qué verificar en las fuentes primarias

| Referencia | Qué verificar |
|---|---|
| Allen, Tasumi & Trezza (2007), METRIC — Model | (1) Ec. de u_b (citada como "Eq. 32") y si incluye d en la estación. (2) z_om = 0.018·LAI ("Eq. 33"), su dominio y la frase sobre maíz, viñas y árboles; mínimo 0.005 m (p. 386 según notas terciarias). (3) Ajuste por terreno ("Eq. 35"), unidades de pendiente y si existe mínimo 1. (4) Ajuste del viento por elevación. (5) ρ_air ("Eq. 37"): presión con 293 K o con T_a; temperatura usada. (6) c_p y g. (7) z₁, z₂, z_b. (8) L, ψ_m, ψ_h ("Eqs. 38–45" según notas terciarias), en particular **ψ_m(200 m) estable con 2/L o 200/L** y qué T y ρ entran en L. (9) Inversión de dT en anclas, a y b ("Eqs. 46, 48–50"), notación y la errata atribuida a "Eq. 51". (10) LE_hot/H_hot ("Eq. 47") — compartido con anclas. (11) Gradiente de Ts con la elevación ("customized lapse rate"), datum y su valor. (12) Criterio de convergencia y número de iteraciones, si los da. (13) Pendiente de dT por encima de Ts_hot (p. 389). |
| Paulson (1970) | Forma integrada de ψ_m y ψ_h inestables; coeficiente 16 y exponentes; funciones φ de partida y su origen. |
| Webb (1970) | Forma log-lineal estable, coeficiente 5, rango de validez y extensión a estabilidad fuerte. |
| Santos et al. (2012); Pôças et al. (2014) | Ecuación de Perrier, definición de f (LAI sobre h/2), ramas en f = 0.5, h, mínimo. |
| Perrier (cita original) | `TODO`: identificar. |
| Manual de METRIC | `TODO: verify full citation`; mínimo 1 del factor de terreno y otras prácticas operativas citadas por `water`. |
| FAO-56 (ya leída: Cap. 2 Ec. 4, Recuadros 4 y 6; Cap. 3 Ec. 7, Ec. 8, Ec. 47) | Pendiente: cita completa en `REFERENCES.md` y si la edición impresa usa la misma numeración. |
| Allen et al. (2011); Bastiaanssen et al. (1998) | Si la iteración de SEBAL/METRIC descrita allí coincide con §11 (forma, criterio, número de iteraciones). |
| Brutsaert (1982) | Formas de ψ, d y z_om; tablas de rugosidad por cobertura (insumo de §5.5). |
| Dyer & Hicks (1970); Dyer (1974); Businger et al. (1971); Foken (2008) | Solo si se evalúan alternativas de ψ (§10.4). |

Paso a `VERIFICADA` de una forma de este documento: fuente primaria
consultada (ecuación y página), referencia con DOI en `REFERENCES.md`,
caso numérico de §14 recalculado si cambian constantes, y traslado del
estado a `SCIENTIFIC_SPEC.md` §3.

---

## 20. Fuera de alcance

- Selección de anclas, coeficiente del ancla fría, ETrF_hot, λ y balance
  hídrico del suelo desnudo (especificación de anclas).
- H de superficies especiales (agua, nieve, urbano) con reglas propias.
- Desagregación térmica o tratamiento explícito de píxeles mixtos a 1 km
  (SPEC §2.3); aquí solo se documenta la limitación de z_om y de las anclas.
- Modelos de dos fuentes o rugosidad para calor distinta de z₁ fija.
- H diario o integración temporal.
- Registro de flags en `ef_flag_registry()` y actualización de
  `SCIENTIFIC_SPEC.md` y `REFERENCES.md` (al integrar este documento).

---

## 21. Estado de implementación (M2)

Implementado el 2026-11-04 (rama `feature/m2-sensible-heat`) con las
decisiones provisionales P0-6, P0-9 y P0-10. Todo sigue `CANDIDATA`
(salvo las formas de FAO-56 indicadas en §1).

| Elemento | Implementación |
|---|---|
| z_om | `ef_zom(..., method)` (despachador, N6; `method` último argumento y objeto `earthflux_roughness_length` desde la armonización M2) con `ef_zom_lai()`, `ef_zom_ndvi()` (§5.2, "custom"), `ef_zom_perrier()`, `ef_zom_height()` (§5.4). Sin mínimo de 0.005 m (SH-02) ni factor de terreno (SH-03): z_om = 0 se devuelve tal cual y `ef_ustar()` lo rechaza |
| Viento, u*, rah | `ef_blending_wind()`, `ef_ustar()`, `ef_rah()`. z_b, z₁, z₂, z_om,w y d_w son argumentos **sin valor por defecto** (valores `CANDIDATA`, SH-04). Sin piso de viento (SH-06) ni ajuste por elevación (SH-07). u* con denominador ≤ 0 → `NA` |
| Estabilidad | Internas (`ef_monin_obukhov_length()`, `ef_psi_m()`, `ef_psi_h()`); H = 0 → L = +∞ y ψ = 0. ψ_m(z_b) estable evaluada a `stable_psi_m_height` de `ef_h_control()`, **sin defecto** (SH-11) |
| ρ_air, Ts_datum, dT, H | `ef_air_density()` (§8.1 con T en K), `ef_ts_datum()` (exportada; Γ en K m⁻¹, sin defecto), `ef_dt_coef()` (Ts_datum,hot ≤ Ts_datum,cold → `earthflux_calibration_error`), `ef_sensible_heat()` (`cp` sin defecto; el driver usa `EF_SPECIFIC_HEAT_AIR`) |
| Driver | `ef_calibrate_h(anchors, control, lapse_rate, datum_elevation, pixels = NULL)` → `earthflux_h_calibration`. Fase A de §11.2 con cierre; Fase B estrategia P2 por píxel (píxeles convergidos se congelan: invariante al tamaño de bloque) |
| Contrato de anclas (§2.2–2.3, P0-9) | `data.frame` con exactamente una fila `type = "hot"` y una `"cold"` y columnas `lst`, `elevation`, `zom`, `rn`, `g`, `le_target`, `u_blend`, `pressure` (opcional `anchor_id`), o un objeto `earthflux_anchors` cuyo elemento `calibration_points` sea ese `data.frame`. H_target = rn − g − le_target |
| Flags registrados | `EF_H_USTAR_INVALID`, `EF_H_PIXEL_NOT_CONVERGED`, `EF_H_DT_EXTRAPOLATED_HOT`, `EF_H_DT_EXTRAPOLATED_COLD`, `EF_H_NEGATIVE`, `EF_H_GT_AVAILABLE` (celda, `ef_diagnose_sensible_heat()`), `EF_H_CALIBRATION_NOT_CONVERGED`, `EF_H_DT_SLOPE_NONPOSITIVE` (objeto, `critical`). Desde la armonización M2, `flags` contiene solo los códigos que se cumplen y `provenance$flags_evaluated` los evaluados (antes, todo código evaluado con `n_flagged = 0`) |

Observaciones al implementar:

- **a y b reportados.** Los valores de §14.5 con `tol` = 0.01 (a =
  −86.27, b = 0.28936) son el iterado a_k, b_k de la última iteración
  (calculado con rah_{k−1}); el objeto devuelve además el par del cierre
  (a = −87.04413, b = 0.2919416 con `tol` = 0.01, ω = 0), que es el que
  reproduce H_target. Ambos se conservan (`trace` y `a`, `b`).
- **Redondeo en §14.4.** Con las entradas impresas, L estable = 41.971746 m
  (§14.4 imprime 41.9718) y −5·(200/L) = −23.825552 (imprime −23.825502);
  L inestable = −2.4847936 y −5·(2/L) = −0.2382555 aparecen truncados
  (−2.484793, −0.238255). Los tests usan una unidad del último dígito.
- **SH-11, efecto observado.** En la escena sintética con el ancla fría
  estable (H_target = −50 W m⁻², y también con −5 W m⁻²), la Fase A
  converge con `stable_psi_m_height` = 2 m y **diverge** con 200 m (rah del
  ancla fría crece sin cota → `earthflux_calibration_error`). Es un
  comportamiento de las formas `CANDIDATA`, no una validación; refuerza que
  SH-11 es bloqueante. Registrado como hallazgo M2-07 en `DECISIONS.md`
  §1.2 (P0-2 sigue abierta y se sabe decisiva) y reproducido en el test de
  extremo a extremo `tests/testthat/test-metric-chain.R` (variante con el
  ancla fría estable).
- **Fase B en paralelo.** Probada la invariancia por bloques (propiedad 7);
  la comparación secuencial = paralelo queda para el envoltorio ráster.
- **Armonización M2 (2026-11-04).** `check_condition()` y `check_scalar()`
  pasaron a `R/utils.R` (este último con cotas y `whole` opcionales, y lo
  comparten las anclas); `ef_zom()` tiene `method` como último argumento y
  devuelve un objeto con `zom`, `method`, `flags` (`EF_INPUT_NA`) y
  `provenance` (`DECISIONS.md` §1.2, M2-04).
