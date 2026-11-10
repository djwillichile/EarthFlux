# EarthFlux — Verificación de formulaciones contra fuentes primarias

Fecha: **2026-11-05** · Autor y mantenedor: Guillermo Servando
Fuentes-Jaque · Política: `DECISIONS.md` §1.2, **M2-08** · Estados:
`SCIENTIFIC_SPEC.md`, convención de estados.

Este documento registra, formulación por formulación, el contraste del
núcleo METRIC (y de las piezas relacionadas del preprocesamiento) con las
fuentes primarias disponibles localmente. Cada fila da la función o
constante, la formulación implementada, el estado anterior, el estado
nuevo, la fuente (documento, página, ecuación) y las notas o discrepancias.
Las páginas son las impresas en cada documento (en el manual coinciden con
las del PDF). Cada ecuación usada se leyó **como imagen** de la página (la
extracción de texto altera las ecuaciones).

## 1. Fuentes

| Clave | Referencia | Tipo | Uso |
|---|---|---|---|
| **SEBAL-Idaho 2002** | Waters, R., Allen, R., Bastiaanssen, W., Tasumi, M., & Trezza, R. (2002). *SEBAL: Surface Energy Balance Algorithms for Land. Idaho implementation. Advanced training and users manual* (Versión 1.0, agosto de 2002). University of Idaho e Idaho Department of Water Resources. 97 p. Sin DOI. | Primaria: manual de los autores, antecesor directo de METRIC (mismo esquema aerodinámico y de estabilidad, rah entre 0,1 m y 2 m, viento a 200 m, anclas con dT = a + b·Ts, G/Rn de Bastiaanssen, 2000, τ_sw, ε_a, ε₀, Rn) | Verificación palabra por palabra (forma, coeficientes, alturas) |
| **IAHS 2012** | Allen, R. G., Kjaersgaard, J. H., Trezza, R., Oliveira, A., Robison, C., & Lorite-Torres, I. (2012). Refining components of a satellite-based surface energy balance model to complex land-use systems. En *Remote Sensing and Hydrology* (IAHS Publ. 352, pp. 73–75). IAHS Press. Sin DOI impreso. | Primaria (METRIC): rugosidad de Perrier, ajustes de montaña, temperatura de referencia de RL↓ | Verificación de la función de Perrier; evidencia para SH-03, SH-07, SH-13 y RC-12 |
| Hong et al. (suplemento) | Hong, S.-h., Hendrickx, J. M. H., Kleissl, J., Allen, R. G., Bastiaanssen, W. G. M., Scott, R. L., & Steinwand, A. L. *Evaluation of an extreme-condition-inverse calibration remote sensing model for mapping energy balance fluxes in arid riparian areas*. Manuscrito de 59 p. obtenido como material suplementario; el PDF imprime título, autores y afiliaciones, pero no revista, año ni DOI. | Secundaria (descripción de SEBAL/METRIC con coautores del método) | Corroboración: z₁ = 0,10 m y z₂ = 2 m, H = ρ c_p ΔT / rah₁₂, ΔT lineal en Ts, H_hot = Rn − G y H_cold de METRIC (Ecs. [3]–[4], pp. 7–8) |
| FAO-56; ASCE-EWRI (2005) | Ya `VERIFICADA` en el paquete (`REFERENCES.md`) | Primaria | Magnitudes compartidas |
| `water` v1.0 (Olmedo et al.) | Código fuente | Secundaria (implementación) | Contraste; no es fuente primaria |

Siguen **sin acceso**: Allen, Tasumi & Trezza (2007, partes I y II),
Bastiaanssen (2000), Tasumi et al. (2008), Allen et al. (2011, 2013),
Paulson (1970), Webb (1970), Duffie & Beckman (1991). Este registro no
afirma nada sobre su contenido. El contraste con Allen et al. (2007) es
**deseable pero ya no bloqueante** para las formas marcadas
`VERIFICADA (SEBAL-Idaho 2002)` o `VERIFICADA (IAHS 2012)` (M2-08).

## 2. Resumen

Recuento por filas de la tabla de §3 (49 filas):

| Resultado | Filas | Números de fila |
|---|---|---|
| Promovidas a `VERIFICADA (SEBAL-Idaho 2002)` | 30 | 1, 2, 4, 5, 7, 8, 11, 14, 16, 17, 23–32, 34–41, 45, 46 |
| Promovidas a `VERIFICADA (IAHS 2012)` | 1 | 18 |
| Ya `VERIFICADA` (FAO-56) y además corroboradas por el manual | 3 | 13, 43, 44 |
| Sin cambio (constantes con redondeo distinto; z_om de FAO-56) | 3 | 9, 10, 19 |
| Formas documentadas por las fuentes, no implementadas | 3 | 21, 22, 47 |
| Siguen `CANDIDATA` | 9 | 3, 6, 12, 15, 20, 33, 42, 48, 49 |

En las filas 38, 40 y 41 lo verificado es la **forma**; el procedimiento
de calibración (fila 38) y los valores de las condiciones de borde (filas
40–41) siguen siendo decisiones explícitas (P0-8, P0-10).

**Discrepancias encontradas: 7.**

- Corregidas en el código (entran en `NEWS.md`, 0.1.0):
  1. **Longitud de Monin-Obukhov** (fila 29, Ec. 34): el manual usa la
     temperatura de superficie Ts; EarthFlux usaba T_a = Ts − dT (SH-10,
     provisional).
  2. **g** (fila 30, texto de la Ec. 34): 9,81 m s⁻²; EarthFlux usaba
     9,807.
- Documentadas sin cambio en el código:
  3. Rs↓ en laderas (fila 6): marco de los flujos y partición (RC-09,
     decisión del autor).
  4. Quinto término de cos θ en el plano inclinado (fila 12): errata
     aparente del manual.
  5. Notación de a y b en dT (fila 35): SH-12, decisión del autor.
  6. σ redondeado a 5,67·10⁻⁸ (fila 9): se mantiene CODATA (RC-07).
  7. Gsc redondeado a 1367 W m⁻² (fila 10): se mantiene FAO-56.

Además, **SH-11** (fila 28) no era una discrepancia de forma sino la falta
de defecto: `stable_psi_m_height` pasa a tener defecto 2 m (Ec. 38), y las
alturas z_b, z₁ y z₂ y c_p pasan a tener defecto (filas 24, 26, 32, 39).

## 3. Tabla de verificación

### 3.1 Radiación

| # | Función / constante | Formulación en EarthFlux | Estado anterior | Estado nuevo | Fuente (doc., pág., ec.) | Notas / discrepancias |
|---|---|---|---|---|---|---|
| 1 | `ef_net_radiation()` | Rn = (1 − α)Rs↓ + RL↓ − RL↑ − (1 − ε₀)RL↓ | `CANDIDATA (corroborada)` | `VERIFICADA (SEBAL-Idaho 2002)` | SEBAL-Idaho 2002, pp. 10 y 14, Ec. 2 | Idéntica término a término, con el término reflejado (1 − ε₀)RL↓ explícito. Cierra NR-D3 respecto del manual |
| 2 | `ef_tau_sw_elevation()` | τ_sw = 0,75 + 2·10⁻⁵·z | `CANDIDATA` (uso instantáneo en METRIC) | `VERIFICADA (SEBAL-Idaho 2002)` | p. 18, Ec. 11 | Forma de FAO-56 Ec. 37 usada como τ instantánea de Rs↓ (Ec. 12); z: elevación representativa del área (estación); por píxel en el modelo de montaña (ap. 12, p. 95, E) |
| 3 | `ef_tau_sw_allen()` | τ_b, τ_d particionadas (Allen, 1996; ASCE-EWRI) | `CANDIDATA` | `CANDIDATA` | — | No cubierta: el manual usa solo la Ec. 11. RC-08 sigue abierta |
| 4 | `ef_atm_emissivity()` | ε_a = 0,85·(−ln τ_sw)^0,09 | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 23, Ec. 22 | Coeficientes ajustados "using data from alfalfa fields in Idaho"; los originales de Bastiaanssen (1995) para Egipto eran 1,08 y 0,265. En el manual τ_sw es la de la Ec. 11; su uso con τ de `ef_tau_sw_allen()` no está cubierto. RC-13 (Brutsaert) sigue abierta |
| 5 | `ef_rs_in_modelled()` (terreno plano) | Rs↓ = Gsc·cos θ·d_r·τ_sw | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 19, Ec. 12; d_r: p. 17, Ec. 7 | El manual redondea Gsc = 1367 W m⁻² (fila 10) |
| 6 | `ef_rs_in_modelled()`, `ef_rs_in_measured()` (laderas) | Proyección isotrópica de las componentes directa, difusa y reflejada al plano del píxel | `CANDIDATA` | `CANDIDATA` | Ap. 12, pp. 93–95 | **Discrepancia de modelo.** El modelo de montaña aplica la Ec. 12 con el cos θ de la ladera (Ec. 12-1) dividido por cos(pendiente) ("equivalente horizontal": todos los flujos por unidad de área horizontal) y una τ total sin partición. EarthFlux expresa los flujos en el plano del píxel y separa directa y difusa. No se alinea: cambia el marco de referencia de los flujos y es decisión del autor (RC-09) |
| 7 | `ef_rl_in()` | RL↓ = ε_a·σ·T⁴ | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` (forma) | p. 23, Ecs. 21 y 23; ap. 12, p. 96, Ec. 12-8 | El manual usa como T la Ts del píxel frío ("using T_cold ... for T_a", Ec. 23), con T_cold + 0,0065·Δz por píxel en montaña (Δz = z_frío − z_píxel). IAHS 2012 (p. 74) describe lo mismo para METRIC: "a lapse rate is applied to a reference surface temperature, generally representing a well-watered vegetated condition, to estimate downwelling long-wave radiation". La función sigue agnóstica (P0-3, RC-12) |
| 8 | `ef_rl_out()` | RL↑ = ε₀·σ·Ts⁴ | `CANDIDATA (corroborada)` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 22, Ec. 20 | ε₀ de banda ancha |
| 9 | `EF_STEFAN_BOLTZMANN` | 5,670374419·10⁻⁸ (CODATA) | `DECIDIDA (provisional)` (RC-07) | Sin cambio | pp. 22–23 (texto de Ecs. 20–21): 5,67·10⁻⁸ | Diferencia de redondeo 6,6·10⁻⁵ relativa; se mantiene el valor exacto (RC-07) |
| 10 | `EF_SOLAR_CONSTANT` | 1366,67 W m⁻² (FAO-56 Ec. 21) | `VERIFICADA` (FAO-56); `CANDIDATA` para METRIC (RC-06) | `VERIFICADA` (FAO-56); regla de RC-06 cumplida para la τ por elevación | p. 19, texto de Ec. 12: 1367 W m⁻² | Misma constante redondeada (2,4·10⁻⁴); la τ de la Ec. 11 es la de FAO-56 Ec. 37, derivada con el Gsc de FAO-56. No se alinea: la constante también sirve a Ra de FAO-56 (`VERIFICADA`). Con τ particionada (ASCE-EWRI) sigue `CANDIDATA` |
| 11 | `modis_broadband_emissivity(method = "lai_empirical")` (E3) | ε₀ = min(0,95 + 0,01·LAI, 0,98) | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` (forma, NDVI > 0) | p. 20, Ec. 16b | Idéntica: 0,95 + 0,01·LAI para LAI < 3 y 0,98 para LAI ≥ 3, "where NDVI > 0". El manual fija ε₀ = 0,985 para agua y nieve (NDVI < 0); ese filtro no se aplica (las clases no vegetadas llegan como `NA` o con LAI explícito, MP-06). La coherencia con la emisividad del producto LST sigue abierta (RC-14, MP-04) |
| 12 | `ef_cos_incidence()` (interna; `ef_solar_geometry()`) | cos θ_rel = sen δ sen φ cos s − sen δ cos φ sen s cos γ + cos δ cos φ cos s cos ω + cos δ sen φ sen s cos γ cos ω + cos δ **sen γ** sen s sen ω | `CANDIDATA` | `CANDIDATA` | Ap. 12, p. 94, Ec. 12-1 (cita Duffie & Beckman, 1991) | **Discrepancia.** Los cuatro primeros términos y la convención de orientación (γ = 0 sur, este −π/2, oeste +π/2) coinciden; el quinto término está impreso con **sen φ** en lugar de sen γ. Con sen φ, un plano vertical orientado al este en el ecuador no recibiría nunca radiación directa: errata aparente. No se alinea; confirmar con Duffie & Beckman (1991) |
| 13 | `ef_declination()`, `ef_inv_distance()` (internas) | FAO-56 Ecs. 24 y 23 | `VERIFICADA` (FAO-56) | `VERIFICADA` (FAO-56); corroboradas | p. 94, Ec. 12-2; p. 17, Ec. 7 | Mismas expresiones. La hora solar del manual (Ecs. 12-4 a 12-6) usa la corrección estacional de FAO-56 |

### 3.2 Flujo de calor del suelo

| # | Función / constante | Formulación en EarthFlux | Estado anterior | Estado nuevo | Fuente (doc., pág., ec.) | Notas / discrepancias |
|---|---|---|---|---|---|---|
| 14 | `ef_g_bastiaanssen()` | G/Rn = T_c·(0,0038 + 0,0074·α)·(1 − 0,98·NDVI⁴), T_c en °C | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 24, Ec. 24 (de Bastiaanssen, 2000) | El manual imprime G/Rn = Ts/α·(0,0038·α + 0,0074·α²)·(1 − 0,98·NDVI⁴), Ts en °C, "values near midday": algebraicamente idéntica para α > 0 (EarthFlux queda definida en α = 0). El desplazamiento K → °C no se indica (el paquete usa 273,15). Reglas del manual no implementadas: G/Rn = 0,5 para agua (NDVI < 0) y nieve (Ts < 4 °C y α > 0,45) (p. 25; ap. 10, Ecs. 10.1–10.6), evidencia para G-D4 |
| 15 | `ef_g_tasumi()` | G/Rn = 0,05 + 0,18·e^(−0,521·LAI); rama de suelo desnudo | `CANDIDATA` | `CANDIDATA` | — | No cubierta por las fuentes locales |

### 3.3 Rugosidad, viento, u*, rah y estabilidad

| # | Función / constante | Formulación en EarthFlux | Estado anterior | Estado nuevo | Fuente (doc., pág., ec.) | Notas / discrepancias |
|---|---|---|---|---|---|---|
| 16 | `ef_zom_lai()` | z_om = 0,018·LAI | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 27, Ec. 31a | "For agricultural areas". Coherente con z_om = 0,12·h (Ec. 28) y h = 0,15·LAI (ap. 2, p. 45): 0,12·0,15 = 0,018 |
| 17 | `ef_zom_ndvi()` | z_om = exp(c₁·NDVI/α + c₂) | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 28, Ec. 31b | Coeficientes (a, b en el manual) ajustados por el usuario con píxeles de rugosidad conocida |
| 18 | `ef_zom_perrier()` | z_om = (1 − e^(−p·LAI/2))·e^(−p·LAI/2)·h; p = 2f (f ≥ 0,5), 1/(2(1 − f)) (f < 0,5) | `CANDIDATA` | `VERIFICADA (IAHS 2012)` | IAHS 2012, p. 73 (ecuación sin número) | Idéntica (allí "a"). f = 0,6 sugerido para bosques mixtos; h = 2,5·LAI en Montana (no implementado) |
| 19 | `ef_zom_height()` | z_om = 0,123·h | `VERIFICADA` (FAO-56) | Sin cambio | p. 26, Ec. 28 | El manual usa 0,12·h (Brutsaert, 1982) para la superficie de la estación (h = 0,3 m en Kimberly). Tabla de z_om por cobertura: ap. 2, p. 44 (evidencia para SH-01 y §5.5 de `sensible-heat.md`; no implementada) |
| 20 | Mínimo de z_om (SH-02) | No implementado en el núcleo; desde el 2026-11-06, z_om = max(0,018·LAI; 0,005 m) en los presets de `earthflux()` con `EF_H_ZOM_FLOOR_APPLIED` (M5-24) | `CANDIDATA` | `CANDIDATA` | — | No cubierto: el manual da 0,018·LAI solo para áreas agrícolas (p. 27) y valores por uso del suelo en el ap. 2, p. 44 (agua 0,0005 m, nieve 0,005 m, …) **sin valor para suelo desnudo**; 0,005 m coincide solo con el de la nieve |
| 21 | Factor de terreno de z_om (SH-03) | No implementado | `CANDIDATA` | Forma `VERIFICADA (SEBAL-Idaho 2002)` e `(IAHS 2012)`, **no implementada** | Ap. 12, p. 97, Ec. 12-9; IAHS 2012, p. 74 | z_om,mnt = z_om·[1 + (pendiente − 5)/20]; IAHS precisa "slope_deg" y "for slope_deg ≥ 5°" (resuelve unidad y mínimo) |
| 22 | Ajuste del viento por elevación (SH-07) | No implementado | `CANDIDATA` | Forma `VERIFICADA (SEBAL-Idaho 2002)` e `(IAHS 2012)`, **no implementada** | Ap. 12, p. 97, Ec. 12-10; IAHS 2012, p. 74 | ϖ = 1 + 0,1·(z − z_estación)/1000, que multiplica u₂₀₀ |
| 23 | `ef_blending_wind()` | u_b = u_x·ln((z_b − d_w)/z_om,w)/ln((z_x − d_w)/z_om,w) | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` con d_w = 0 | p. 26, Ecs. 27 y 29 | El manual no usa desplazamiento en la estación; d_w > 0 es extensión del paquete coherente con FAO-56 Ec. 47 (SH-04) |
| 24 | z_b = 200 m (`ef_h_control()`, `ef_blending_wind()`, `ef_ustar()`) | Argumento | `CANDIDATA`, sin defecto | `VERIFICADA (SEBAL-Idaho 2002)`, **defecto 200 m** | p. 26 ("200 meters is used"); Ecs. 29, 30, 40 | — |
| 25 | `ef_ustar()` | u* = k·u_b/(ln(z_b/z_om) − ψ_m(z_b)) | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 27, Ec. 30; p. 33, Ec. 40 | k = 0,41 (fila 31) |
| 26 | `ef_rah()`; z₁ = 0,1 m, z₂ = 2 m | rah = (ln(z₂/z₁) − ψ_h(z₂) + ψ_h(z₁))/(k·u*) | `CANDIDATA`, alturas sin defecto | `VERIFICADA (SEBAL-Idaho 2002)`, **defectos 0,1 m y 2 m** | p. 26, Ec. 26; p. 30 (alturas); p. 34, Ec. 41 | El texto de la Ec. 41 dice "at 2 meters and 1 meters" por 0,1 m (errata evidente: la misma frase da z₁ = 0,1 m). Corroborado por Hong et al., p. 7 |
| 27 | `ef_psi_m()`, `ef_psi_h()` (inestable) | x = (1 − 16·z/L)^(1/4); ψ_m = 2 ln((1 + x)/2) + ln((1 + x²)/2) − 2 arctan x + π/2; ψ_h = 2 ln((1 + x²)/2) | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | pp. 32–33, Ecs. 35, 36a, 36b, 37a–37c | "Formulations by Paulson (1970) and Webb (1970)" (no consultados) |
| 28 | `ef_psi_m()`, `ef_psi_h()` (estable) y **SH-11** | ψ = −5·z/L; ψ_m(z_b) evaluada a `stable_psi_m_height` | `CANDIDATA`; SH-11 sin defecto | `VERIFICADA (SEBAL-Idaho 2002)`; **defecto 2 m** | p. 33, Ecs. 38, 39a, 39b | ψ_m(200 m) = −5·(2/L); ψ_h(2 m) = −5·(2/L); ψ_h(0,1 m) = −5·(0,1/L). Con L = 41,97 m: −0,2383. Coincide con `water` y con el hallazgo M2-07 |
| 29 | `ef_monin_obukhov_length()` (interna) | L = −ρ·c_p·u*³·**Ts**/(k·g·H) | `CANDIDATA` con T_a = Ts − dT (SH-10) | `VERIFICADA (SEBAL-Idaho 2002)` | p. 32, Ec. 34; p. 29, fig. 4; ap. 8, p. 82 (el modelo F14 recibe Ts y la densidad de cada iteración) | **Discrepancia corregida en el código**: T = Ts (antes T_a). ρ: la de la iteración (coincide) |
| 30 | `EF_GRAVITY` | 9,81 m s⁻² | `CANDIDATA` (9,807) | `VERIFICADA (SEBAL-Idaho 2002)` | p. 32, texto de Ec. 34 | **Discrepancia corregida**: 9,807 → 9,81 (3·10⁻⁴ relativo; solo entra en L) |
| 31 | `EF_VON_KARMAN` | 0,41 | `VERIFICADA` (FAO-56); `CANDIDATA` en METRIC | `VERIFICADA` (FAO-56) y `(SEBAL-Idaho 2002)` | p. 26, texto de Ec. 26; p. 33, texto de Ec. 40 | — |

### 3.4 Densidad del aire, H, dT y calibración

| # | Función / constante | Formulación en EarthFlux | Estado anterior | Estado nuevo | Fuente (doc., pág., ec.) | Notas / discrepancias |
|---|---|---|---|---|---|---|
| 32 | `EF_SPECIFIC_HEAT_AIR` | 1004 J kg⁻¹ K⁻¹ | `CANDIDATA` (SH-09) | `VERIFICADA (SEBAL-Idaho 2002)` | p. 25, texto de Ec. 25; p. 32, texto de Ec. 34 | Cierra SH-09. Pasa a ser el defecto de `cp` en `ef_sensible_heat()` |
| 33 | `ef_air_density()` | ρ = 1000·P/(1,01·T·287) | `VERIFICADA` (FAO-56); uso en METRIC `CANDIDATA` | Sin cambio | p. 31, paso 6 | El manual calcula ρ con T_a = Ts − dT (corrobora la temperatura de SH-08), pero no imprime la ecuación de ρ (planilla) |
| 34 | `ef_sensible_heat()` | H = ρ·c_p·dT/rah | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 25, Ec. 25 | — |
| 35 | `ef_dt_coef()` | dT = a + b·Ts_datum por las dos anclas | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 30, Ec. 32; p. 31; ap. 8, p. 82 | **Notación distinta** (sin efecto numérico): el manual escribe dT = b + a·Ts (a = pendiente, b = intercepto), como `water`; EarthFlux, a = intercepto, b = pendiente. Decisión del autor (SH-12) |
| 36 | Inversión de dT en las anclas (`ef_calibrate_h()`) | dT_i = H_i·rah_i/(ρ_i·c_p) | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 30, Ec. 33 | — |
| 37 | `ef_ts_datum()` | Ts_datum = Ts + Γ·(z − z_datum) | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` (forma); Γ sin defecto | Ap. 12, p. 96, Ec. 12-7 (Γ = 0,0065 K m⁻¹, datum = elevación de la estación) | IAHS 2012 (p. 74): METRIC usa una corrección "dual-stage" con tasas distintas para terreno plano y montañoso, ajustadas a la escena. Por eso Γ sigue sin defecto (SH-13), ahora por diseño y no por falta de fuente |
| 38 | `ef_calibrate_h()` (procedimiento) | Fase A en las anclas con cierre; Fase B por píxel (P2) | `CANDIDATA` | Formas `VERIFICADA (SEBAL-Idaho 2002)`; procedimiento: decisiones P0-10 y M2-11 (una tolerancia por fase) | pp. 25–34 (fig. 4, p. 29); ap. 8, pp. 81–82 | El manual itera "until the successive values for dT_hot and rah at the 'hot' pixel have stabilized" (3 a 7 iteraciones). Tolerancia relativa por ancla (`tol`) y por píxel (`pixel_tol`, M2-11), cierre y Fase B P2 son diseño de EarthFlux |
| 39 | `ef_h_control()` | Alturas y SH-11 | `CANDIDATA`, sin defectos | Defectos `stable_psi_m_height = 2`, `blending_height = 200`, `z1 = 0.1`, `z2 = 2` (`VERIFICADA (SEBAL-Idaho 2002)`) | pp. 26, 30, 33 | Otra altura (p. ej., 200 m en el caso estable) puede elegirse explícitamente |

### 3.5 Anclas, LE, ET y extrapolación diaria

| # | Función / constante | Formulación en EarthFlux | Estado anterior | Estado nuevo | Fuente (doc., pág., ec.) | Notas / discrepancias |
|---|---|---|---|---|---|---|
| 40 | `ef_anchor_conditions()` (ancla fría) | H = Rn − G − LE, LE = k·ETr_inst·λ·ρ_w/(3600·1000) | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` (forma) | p. 30, paso 5a; ap. 7, p. 66; ap. 8, p. 81 | H_cold = Rn − G − 1,05·λETr, ETr de alfalfa (ASCE estandarizada, p. 66; pp. 13 y 38). k = 1,05 es el valor del manual, pero **sigue sin defecto** (D-AP-04, P0-8: diseño) |
| 41 | `ef_anchor_conditions()` (ancla caliente) | H = Rn − G − LE_hot, `etrf_hot` o `le_hot` | `CANDIDATA` | `VERIFICADA (SEBAL-Idaho 2002)` (forma) | p. 31, paso 5b; ap. 7, p. 72 | ET_hot = 0 en suelo agrícola desnudo y seco; tras lluvia en los 3–4 días previos, ET de suelo desnudo por balance hídrico (FAO-56, anexo 8) o ≈ 0,8; 0,5; 0,3; 0,2; 0,1·ETr a 1–5 días de una lluvia ≥ 15 mm (p. 72). Sin defecto (D-AP-05) |
| 42 | Criterios de selección de anclas (`ef_anchor_criteria()` y relacionadas) | Sin umbrales por defecto en el núcleo; los presets de `earthflux()` fijan criterios `CANDIDATA` (versión 2, M5-23: NDVI por percentiles y bandas de albedo, `specs/presets.md` §4) | `CANDIDATA` | `CANDIDATA` | Ap. 7, pp. 66–74; pp. 23, 30–31 | Selección visual con guías numéricas (frío: α 0,22–0,24, LAI 4–6, cobertura plena LAI > 3, "very cold, but not extremely cold"; caliente: suelo agrícola desnudo y seco, LAI 0–0,4, albedo como el de otros campos secos, no desierto ni ladera, pendiente < 1 % en montaña; ambos cerca de la estación). Los presets traducen la intención con umbrales para MODIS 1 km fijados en dos escenas, sin fuente (`verification/anchors-m5-23.md`) |
| 43 | `ef_latent_heat()` | LE = Rn − G − H | `VERIFICADA` (FAO-56) | `VERIFICADA` (FAO-56) y `(SEBAL-Idaho 2002)` | pp. 9, 24 y 34, Ec. 1 | Misma convención de signos (V1) |
| 44 | `ef_et_inst()` | ET_inst = 1000·3600·LE/(λ·ρ_w) | `VERIFICADA` (FAO-56) | `VERIFICADA` (FAO-56) y `(SEBAL-Idaho 2002)` | p. 34, Ec. 42 | El manual: ET_inst = 3600·λET/λ en mm/h (kg m⁻² h⁻¹), numéricamente idéntica con ρ_w = 1000. Resuelve V3: la forma con ρ_w en el denominador de fuentes secundarias es la que omite el factor 1000 |
| 45 | `ef_etrf()` | ETrF = ET_inst/ETr_inst | `CANDIDATA (corroborada)` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 35, Ec. 43 | ETr de referencia a la hora de la imagen (REF-ET, alfalfa). Rango esperado 0 a ~1,1; valores negativos posibles (evidencia para V7, V9 y ET-D5; no se fija umbral) |
| 46 | `ef_et_daily_etrf()` / `ef_et_daily(method = "etrf")` | ETa_24 = ETrF·ETr_24 | `CANDIDATA (corroborada)` | `VERIFICADA (SEBAL-Idaho 2002)` | p. 35, Ec. 44 | ETr_24 = suma de la ETr horaria del día (opción D1 de `ef_station_ref_et()`; su documentación y `weather-forcing.md` §5.6 decían "uso en METRIC `TODO`" y se sincronizaron el 2026-11-06, M5; el reloj del día sigue abierto, WF-11); supone ETrF instantánea = media de 24 h (fig. 5, p. 36). Sin corrección por pendiente C_rad (no aparece en el manual; ET-D7) |
| 47 | `ef_et_period()` (no implementada) | — | `CANDIDATA` | Forma `VERIFICADA (SEBAL-Idaho 2002)`, **no implementada** | p. 38, Ec. 45 | ET_período = ETrF_período·Σ ETr_24 (V8) |
| 48 | `ef_lambda(method = "metric")` | No implementada | `CANDIDATA` | `CANDIDATA` | — | El manual no da λ(T) |
| 49 | Ítems METRIC no cubiertos | Regla de cobertura parcial del ancla fría (1,25–1,30·NDVI), C_rad, mínimo de z_om, "pendiente reducida" sobre Ts_hot (SH-20), errata de la Ec. 51 | `CANDIDATA`/`TODO` | Sin cambio | — | Propios de Allen et al. (2007) según notas terciarias; no están en las fuentes locales |

## 4. Casos numéricos

Las formas verificadas se comprueban en
`tests/testthat/test-verification.R`, que escribe cada ecuación del manual
literalmente (página y ecuación en el nombre del test) con entradas
elegidas a mano. Los valores de la escena sintética de
`specs/sensible-heat.md` §14.4–§14.5 se recalcularon con un script
independiente del autor (Python, sin usar el código del paquete) que
implementa las Ecs. 25–41 del manual; el mismo script reproduce
exactamente los valores anteriores al cambiar T de L por Ts − dT y g por
9,807, lo que confirma que la diferencia se debe solo a esas dos
correcciones.

## 5. Pendiente

- Contrastar con Allen, Tasumi & Trezza (2007) cuando haya acceso
  (deseable, no bloqueante; M2-08): en especial ρ_air (Ec. 37 según notas
  terciarias), c_p y g en METRIC, la errata atribuida a la Ec. 51 y la
  pendiente de dT sobre Ts_hot (SH-20).
- Confirmar el quinto término de cos θ (fila 12) con Duffie & Beckman
  (1991).
- Decisiones del autor abiertas por esta revisión: RC-09 (marco de los
  flujos en laderas, fila 6), SH-12 (notación de a y b, fila 35), RC-12
  (configuración (b) verificada; defecto del preset, P0-3), implementar
  SH-03, SH-07 y G-D4 con las formas ahora documentadas.
