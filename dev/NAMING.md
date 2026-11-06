# EarthFlux — Nombres de funciones

Estado: **DECIDIDA** (2026-11-04, aprobada por el autor con la opción B de §2.1).
Complementa `DEVELOPMENT.md` §1 y las especificaciones de `dev/specs/`.

## 1. Decisión de base

Se mantiene el prefijo `ef_` en toda función pública de bajo nivel (decisión
del autor, 2026-11-04). Motivos:

1. En hidrometeorología los nombres de función coinciden con los de las
   variables (`net_radiation`, `air_density`). Con prefijo, la función y el
   objeto no se confunden: `rn <- ef_net_radiation(...)`.
2. Evita choques con `terra`, `sf`, `water` y otros paquetes de
   micrometeorología y de ET, y con el código del usuario. R no ofrece un
   *import as* cómodo; el prefijo cumple ese papel.
3. `ef_` + Tab funciona como catálogo de la API en el autocompletado
   (convención de `stringr`, `forcats` y `sf`, y recomendada por la guía de
   rOpenSci para paquetes con muchas funciones).
4. La API simple (`earthflux()`) no lleva prefijo; `ef_*()` es la API
   avanzada.

El prefijo aporta 3 caracteres; la longitud excesiva venía de las raíces.
Este documento acorta las raíces.

## 2. Reglas

| # | Regla | Ejemplo |
|---|---|---|
| N1 | Toda función exportada de bajo nivel empieza por `ef_`. | `ef_net_radiation()` |
| N2 | Longitud máxima orientativa: **22 caracteres** con el prefijo. Una excepción se justifica en este documento. | — |
| N3 | Las magnitudes de la cadena principal **calculadas con un solo método** conservan su nombre completo, para que el flujo se lea sin glosario. | `ef_net_radiation()`, `ef_sensible_heat()`, `ef_latent_heat()` |
| N4 | Las magnitudes auxiliares usan el **símbolo estándar** de FAO-56 o METRIC cuando es inequívoco para el público del paquete. El título del `.Rd` siempre escribe el nombre completo. | `ef_rah()`, `ef_zom()`, `ef_ustar()`, `ef_ra_daily()`, `ef_ea_rh()` |
| N5 | Los nombres de funciones coinciden con los nombres de argumentos que alimentan. | `ef_rl_in()` → argumento `rl_in` de `ef_net_radiation()` |
| N6 | Familias con varios métodos de **argumentos distintos**: el despachador **es la raíz de la familia** y recibe `method` sin defecto; cada método es la raíz + sufijo del método. Todos se documentan en el mismo `.Rd` (`@rdname`), cuyo título nombra la magnitud completa. Ver §2.1. | `ef_g(method = )`, `ef_g_tasumi()`, `ef_g_bastiaanssen()` |
| N6b | Si los métodos comparten argumentos y solo cambia la fórmula, basta una función con `method` sin defecto (sin funciones por método). | `ef_lambda(temperature, method = )`, `ef_ea_daily(..., method = )` |
| N7 | Sin `_from_` ni palabras deducibles de los argumentos; el método o la entrada va como sufijo. | `ef_ea_dewpoint()`, `ef_dewpoint()` |
| N8 | Sufijos de escala temporal fijos: `_inst`, `_hourly`, `_daily`, `_period`. | `ef_et_inst()`, `ef_ra_daily()` |
| N9 | Objetos de control con sufijo `_control`; constructores de reglas con la raíz del módulo. | `ef_h_control()`, `ef_anchor_rule()` |
| N10 | Las funciones internas no se rigen por N2 (no son API), pero mantienen `ef_` cuando forman parte del núcleo. | `ef_flag_registry()` |

### 2.1 Despachadores (opción B)

Opciones evaluadas para nombrar el despachador de una familia (2026-11-04):

| Opción | Despachador | Métodos | Resultado |
|---|---|---|---|
| A | `ef_soil_heat_flux()` | `ef_g_tasumi()`, `ef_g_bastiaanssen()` | Descartada: la familia queda con dos raíces y `ef_g` + Tab no muestra el despachador |
| **B** | **`ef_g()`** | `ef_g_tasumi()`, `ef_g_bastiaanssen()` | **Adoptada**: familia coherente y corta; el título del `.Rd` ("Soil heat flux") compensa la brevedad |
| C | `ef_soil_heat_flux()` | `ef_soil_heat_flux_tasumi()`, … | Descartada: vuelve a nombres de 24–30 caracteres |

Un nombre con verbo (`get_g()`) se descartó: pierde el prefijo `ef_` y, en
R, *get* sugiere recuperar un valor existente (`get()`, *getters*), no
calcular una magnitud.

Comportamiento común de los despachadores:

- `method` sin valor por defecto (P0-12, T-15); se valida con
  `check_method()`.
- Solo reenvía los argumentos al método elegido; no contiene ecuaciones.
  `method` es su **último** argumento.
- Devuelve un objeto con clase (`ARCHITECTURE.md` §3.2, punto 4): los
  valores del método, `method`, `flags` (de su etapa más `EF_INPUT_NA`) y
  `provenance` (armonización M2, `DECISIONS.md` §1.2, M2-04).
- Un test verifica que el elemento de valor del despachador y la llamada
  directa al método son idénticos.
- Cuando el método que hoy lleva el nombre de la raíz pasa a ser uno de
  varios, recibe su propio sufijo (`ef_tau_sw_allen()`,
  `ef_rs_in_modelled()`, `ef_et_daily_etrf()`). Los sufijos `_allen` y
  `_modelled` son provisionales hasta verificar Allen et al. (2007).
- Una familia con un solo método implementado tiene igualmente su
  despachador, para que la API no cambie al agregar métodos.

## 3. Tabla de nombres

Se listan las 81 funciones públicas o candidatas a públicas que nombran las
especificaciones, más 3 despachadores nuevos (—) de `dev/specs/` y las
funciones nuevas agregadas al implementar (regla §6.4; p. ej.,
`ef_anchor_conditions()`) (se excluyen las internas `ef_abort()`,
`ef_flag()`, `ef_flag_bits()` y `ef_flag_registry()`). "=" indica que el
nombre se mantiene.

### Radiación (`radiation-components.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_net_radiation()` | 16 | = | 16 | Ya exportada; nombre de la cadena principal |
| `ef_solar_geometry()` | 17 | = | 17 |  |
| `ef_solar_declination()` | 20 | **`ef_declination()`** | 14 | "solar" es redundante en el contexto |
| `ef_equation_of_time()` | 19 | = | 19 |  |
| `ef_hour_angle()` | 13 | = | 13 |  |
| `ef_inverse_relative_distance()` | 28 | **`ef_inv_distance()`** | 15 | Inverso de la distancia relativa Tierra–Sol, d_r (FAO-56) |
| `ef_cos_incidence()` | 16 | = | 16 |  |
| — | — | **`ef_tau_sw()`** | 9 | Despachador nuevo (N6); símbolo τ_sw de METRIC |
| `ef_sw_transmissivity()` | 20 | **`ef_tau_sw_allen()`** | 15 | Método completo (P, e_a, cos θ); sufijo tentativo |
| `ef_sw_transmissivity_elevation()` | 30 | **`ef_tau_sw_elevation()`** | 19 | Variante simplificada por elevación |
| `ef_atmospheric_emissivity()` | 25 | **`ef_atm_emissivity()`** | 17 |  |
| — | — | **`ef_rs_in()`** | 8 | Despachador nuevo (N6); coincide con el argumento `rs_in` de `ef_net_radiation()` |
| `ef_shortwave_in()` | 15 | **`ef_rs_in_modelled()`** | 17 | Rs↓ modelada; sufijo tentativo |
| `ef_shortwave_in_measured()` | 24 | **`ef_rs_in_measured()`** | 17 |  |
| `ef_sw_to_slope()` | 14 | **`ef_rs_to_slope()`** | 14 | Misma raíz `rs` que la familia |
| `ef_longwave_in()` | 14 | **`ef_rl_in()`** | 8 | Coincide con el argumento `rl_in` |
| `ef_longwave_out()` | 15 | **`ef_rl_out()`** | 9 | Coincide con el argumento `rl_out` |

### Flujo de calor del suelo (`soil-heat-flux.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_soil_heat_flux()` | 17 | **`ef_g()`** | 4 | Despachador (`method`); raíz de la familia (N6) |
| `ef_soil_heat_flux_tasumi()` | 24 | **`ef_g_tasumi()`** | 11 | Mismo `.Rd` que el despachador |
| `ef_soil_heat_flux_bastiaanssen()` | 30 | **`ef_g_bastiaanssen()`** | 17 |  |

### Píxeles ancla (`anchor-pixels.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_select_anchors()` | 17 | = | 17 |  |
| `ef_anchors()` | 10 | = | 10 | Constructor de anclas explícitas |
| `ef_anchor_criteria()` | 18 | = | 18 |  |
| `ef_rule()` | 7 | **`ef_anchor_rule()`** | 14 | `ef_rule` es demasiado genérico (habrá reglas de QC) |
| `ef_pick()` | 7 | **`ef_anchor_pick()`** | 14 | Ídem |
| `ef_homogeneity()` | 14 | = | 14 | Nombre específico; no necesita la raíz `anchor` |
| — (función de la etapa [B], D-AP-03) | — | **`ef_anchor_conditions()`** | 20 | Nueva (2026-11-04, N4 §6): condiciones de borde en las anclas; raíz del módulo como `ef_anchor_rule()` (N9); completa el elemento `conditions` del objeto |

### Aerodinámica y calor sensible (`sensible-heat.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_sensible_heat()` | 16 | = | 16 | Nombre de la cadena principal |
| `ef_calibrate_sensible_heat()` | 26 | **`ef_calibrate_h()`** | 14 | Coherente con la clase `earthflux_h_calibration` |
| `ef_sensible_heat_control()` | 24 | **`ef_h_control()`** | 12 | Objeto de control, como `glm.control()` |
| `ef_roughness_length()` | 19 | **`ef_zom()`** | 6 | Símbolo z_om de METRIC; despachador (N6) |
| — | — | **`ef_zom_lai()`** | 10 | Método de `ef_zom()`: 0.018·LAI (agregado al implementar, §6.4) |
| — | — | **`ef_zom_ndvi()`** | 11 | Método de `ef_zom()`: exp(c₁·NDVI/α + c₂) ("custom" en `water`) |
| — | — | **`ef_zom_perrier()`** | 14 | Método de `ef_zom()`: Perrier |
| — | — | **`ef_zom_height()`** | 13 | Método de `ef_zom()`: 0.123·h (FAO-56, Recuadro 4) |
| `ef_friction_velocity()` | 20 | **`ef_ustar()`** | 8 | Símbolo u* |
| `ef_aerodynamic_resistance()` | 25 | **`ef_rah()`** | 6 | Símbolo r_ah |
| `ef_blending_wind()` | 16 | = | 16 |  |
| `ef_air_density()` | 14 | = | 14 |  |
| `ef_datum_temperature()` | 20 | **`ef_ts_datum()`** | 11 | Símbolo Ts_datum de METRIC |
| `ef_dt_coefficients()` | 18 | **`ef_dt_coef()`** | 10 |  |

### Calor latente y ET (`evapotranspiration.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_latent_heat()` | 14 | = | 14 | LE como residuo; cadena principal |
| `ef_latent_heat_vaporization()` | 27 | **`ef_lambda()`** | 9 | Símbolo λ; ya implementada en la base de M2 |
| `ef_et_instantaneous()` | 19 | **`ef_et_inst()`** | 10 | Sufijo de escala temporal `_inst` |
| `ef_etrf()` | 7 | = | 7 |  |
| — | — | **`ef_et_daily()`** | 11 | Despachador nuevo (N6) |
| `ef_et_daily()` | 11 | **`ef_et_daily_etrf()`** | 16 | ETa = ETrF × ETr_24; en las especificaciones era `ef_et_daily()` |
| `ef_et_daily_evaporative_fraction()` | 32 | **`ef_et_daily_evapfrac()`** | 20 | Método futuro del despachador (ET-D8) |
| `ef_et_period()` | 12 | = | 12 |  |

### Forzamiento meteorológico y ET de referencia (`weather-forcing.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_air_pressure()` | 15 | = | 15 | Ya implementada en la base de M2 |
| `ef_station_table()` | 16 | = | 16 |  |
| `ef_validate_station_table()` | 25 | **`ef_validate_stations()`** | 20 | Creada **interna** (M3; `DECISIONS.md` §1.3, M3-07): la llaman `ef_station_table()` y `ef_station_qc()` |
| `ef_station_qc()` | 13 | = | 13 |  |
| `ef_sat_vapour_pressure()` | 22 | **`ef_es()`** | 5 | Símbolo e_s (FAO-56) |
| `ef_sat_vapour_slope()` | 19 | **`ef_es_slope()`** | 11 | Pendiente Δ de la curva de saturación |
| `ef_vapour_pressure_from_dewpoint()` | 32 | **`ef_ea_dewpoint()`** | 14 | Familia e_a: método como sufijo, sin `_from_` |
| `ef_vapour_pressure_from_rh()` | 26 | **`ef_ea_rh()`** | 8 |  |
| `ef_vapour_pressure_from_tmin()` | 28 | **`ef_ea_tmin()`** | 10 |  |
| `ef_vapour_pressure_daily()` | 24 | **`ef_ea_daily()`** | 11 |  |
| `ef_dewpoint_from_vapour_pressure()` | 32 | **`ef_dewpoint()`** | 11 | Única vía de cálculo |
| `ef_psychrometric_constant()` | 25 | **`ef_psychrometric()`** | 16 | Constante psicrométrica γ |
| `ef_wind_speed_2m()` | 16 | **`ef_wind_2m()`** | 10 |  |
| `ef_extraterrestrial_radiation_daily()` | 35 | **`ef_ra_daily()`** | 11 | Símbolo R_a (FAO-56) |
| `ef_extraterrestrial_radiation_period()` | 36 | **`ef_ra_period()`** | 12 |  |
| `ef_clear_sky_radiation()` | 22 | **`ef_rso()`** | 6 | Símbolo R_so (FAO-56) |
| `ef_reference_net_radiation()` | 26 | **`ef_ref_net_radiation()`** | 20 | Prefijo `ref_` para la superficie de referencia; exportada (WF-13, M3-03) |
| `ef_reference_soil_heat_flux()` | 27 | **`ef_ref_soil_heat_flux()`** | 21 | Exportada (WF-13, M3-03) |
| `ef_reference_et()` | 15 | **`ef_ref_et()`** | 9 |  |
| `ef_station_reference_et()` | 23 | **`ef_station_ref_et()`** | 17 | Serie de ETr por estación, `etr_inst` y `etr_24` (M3) |
| `ef_etr_hourly()` | 13 | = | 13 | **No creada** (M3-03): no aporta sobre `ef_ref_et(timestep = "hourly")` |
| `ef_etr_daily()` | 12 | = | 12 | **No creada** (M3-03): ídem con `timestep = "daily"` |

### Regionalización y GWR (`gwr-forcing.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_regionalize()` | 14 | = | 14 |  |
| `ef_regionalize_cv()` | 17 | = | 17 |  |
| `ef_method_gwr()` | 13 | = | 13 | Constructor de método (C3), clase `earthflux_regionalization_method` |
| `ef_method_idw()` | 13 | = | 13 | Constructor de método (C2) |
| `ef_method_ols()` | 13 | = | 13 | Constructor de método (C2) |
| `ef_method_station()` | 17 | = | 17 | Constructor de método (C1) |
| `ef_gwr_config()` | 13 | = | 13 | **No creada** (M3-27): la configuración por variable es `variable` + capas de `covariates` de `ef_regionalize()` |
| `ef_gwr_fit()` | 10 | = | 10 |  |
| `ef_gwr_bandwidth()` | 16 | = | 16 |  |
| `ef_gwr_search()` | 13 | = | 13 |  |
| `ef_gwr_predict()` | 14 | = | 14 |  |
| `ef_gwr_diagnostics()` | 18 | = | 18 |  |
| `ef_idw_fit()` | 10 | = | 10 | **No creada** como pública (M3-33): ajuste interno `rgn_idw_fit()` (clase `earthflux_idw`), vía `ef_method_idw()` |
| `ef_ols_fit()` | 10 | = | 10 | **No creada** como pública (M3-33): ajuste interno `rgn_ols_fit()` (clase `earthflux_ols`), vía `ef_method_ols()` |
| `ef_prediction_control()` | 21 | **`ef_predict_control()`** | 18 | Simetría con `ef_h_control()`; clase `earthflux_predict_control` |
| `ef_spatial_folds()` | 16 | = | 16 |  |
| `ef_spatial_forcing()` | 18 | = | 18 | **No creada** (GW-23, M3-27): la regionalización es `ef_regionalize()` |
| `ef_station_forcing()` | 18 | = | 18 | **No creada** como pública (M3-33): C1 es `ef_method_station()` + `ef_regionalize()` (ajuste interno `rgn_station_fit()`, clase `earthflux_station_forcing`) |

### Flujo de trabajo (`specs/presets.md`, M5)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `earthflux()` | 9 | = | 9 | API simple sin prefijo (§1, punto 4); `ARCHITECTURE.md` §6.7; preset obligatorio (M5-04) |
| — | — | **`ef_presets()`** | 12 | Nueva (M5, fase 2): tabla de los presets registrados (nombre, versión, estado, descripción) |
| — | — | **`ef_preset()`** | 11 | Nueva (M5, fase 2): todas las opciones de un preset (`earthflux_preset`, imprimible); `name` sin defecto |

## 4. Resumen

| | Especificaciones | Decisión |
|---|---:|---:|
| Funciones | 81 | 84 (3 despachadores nuevos) + `ef_anchor_conditions()` (§6.4) + 4 métodos de `ef_zom()` = 89 filas |
| Nombres que cambian | — | 44 |
| Mediana de caracteres | 17 | 14 |
| Máximo de caracteres | 36 | 21 |
| Nombres con más de 22 caracteres | 23 | 0 |

Estado al cierre de M3 (armonización, 2026-11-04): de las **89 filas** de
§3, **73** funciones están exportadas (la API pública de `NAMESPACE`);
**7** existen como internas: la geometría solar y `ef_rs_to_slope()` de M2
(`ef_declination()`, `ef_inv_distance()`, `ef_equation_of_time()`,
`ef_hour_angle()`, `ef_cos_incidence()`, `ef_rs_to_slope()`) y
`ef_validate_stations()`; **9** no se crearon: futuras (`ef_et_period()`,
`ef_et_daily_evapfrac()`) o descartadas en M3 por no aportar sobre otra
función (`ef_etr_hourly()`, `ef_etr_daily()`, `ef_gwr_config()`,
`ef_spatial_forcing()`, `ef_station_forcing()`, `ef_ols_fit()`,
`ef_idw_fit()`). Por tabla de M3: forzamiento, 19 exportadas de 22 filas
(incluida `ef_air_pressure()`, de la base de M2); regionalización, 13
exportadas de 18 filas.

Fase 2 de M5 (2026-11-06): se agregan las 3 filas del flujo de trabajo
(`earthflux()`, `ef_presets()`, `ef_preset()`), las tres exportadas: **92
filas**, **76** funciones exportadas. Las auxiliares del flujo
(`workflow_*()`) y las de descarga (`modis_*()`, `dem_*()`,
`openmeteo_*()`) son internas y no se rigen por §2 (N10).

## 5. Alternativas consideradas

- **Quitar el prefijo.** Descartada (§1). `extraterrestrial_radiation_period`
  seguiría teniendo 33 caracteres.
- **Exportar solo los despachadores.** Acortaría la API, pero los métodos
  tienen argumentos distintos (`ef_g_tasumi(rn, lst, lai)` frente a
  `ef_g_bastiaanssen(rn, lst, albedo, ndvi)`); con `...` se pierde su
  documentación y validación (T-16 de `DECISIONS.md`).
- **Palabras en lugar de símbolos para las magnitudes auxiliares**
  (`ef_aero_resistance()`, `ef_vp_dewpoint()`, `ef_sat_vp()`). Más
  legibles para estudiantes, pero más largas y menos alineadas con la
  notación de los artículos. Si el autor prefiere esta línea, se aplica solo
  a las filas marcadas con N4.

## 6. Aplicación

1. Aprobada por el autor el 2026-11-04 con la opción B (§2.1).
2. En el mismo cambio que aprueba esta tabla se renombran las funciones en
   `dev/specs/`, `dev/SCIENTIFIC_SPEC.md`, `dev/DECISIONS.md`,
   `dev/ARCHITECTURE.md` y `dev/VALIDATION_PLAN.md`, y
   `ef_latent_heat_vaporization()` pasa a `ef_lambda()` en el código (no hay
   release, por lo que no se necesita alias ni deprecación).
3. Los módulos de M2 se implementan directamente con los nombres de la
   columna "Nombre propuesto".
4. Un nombre nuevo no previsto aquí sigue las reglas de §2 y se agrega a la
   tabla en el mismo cambio que crea la función.
