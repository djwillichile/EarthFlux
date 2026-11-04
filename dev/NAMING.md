# EarthFlux — Nombres de funciones

Estado: **PROPUESTA** (2026-11-04) · pendiente de aprobación del autor.
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
| N3 | Las magnitudes de la cadena principal conservan su nombre completo, para que el flujo se lea sin glosario. | `ef_net_radiation()`, `ef_soil_heat_flux()`, `ef_sensible_heat()`, `ef_latent_heat()` |
| N4 | Las magnitudes auxiliares usan el **símbolo estándar** de FAO-56 o METRIC cuando es inequívoco para el público del paquete. El título del `.Rd` siempre escribe el nombre completo. | `ef_rah()`, `ef_zom()`, `ef_ustar()`, `ef_ra_daily()`, `ef_ea_rh()` |
| N5 | Los nombres de funciones coinciden con los nombres de argumentos que alimentan. | `ef_rl_in()` → argumento `rl_in` de `ef_net_radiation()` |
| N6 | Familias con varios métodos: despachador con el nombre de la magnitud y `method` sin defecto; funciones por método con raíz corta + sufijo del método, documentadas en el mismo `.Rd` (`@rdname`). | `ef_soil_heat_flux(method = )`, `ef_g_tasumi()`, `ef_g_bastiaanssen()` |
| N7 | Sin `_from_` ni palabras deducibles de los argumentos; el método o la entrada va como sufijo. | `ef_ea_dewpoint()`, `ef_dewpoint()` |
| N8 | Sufijos de escala temporal fijos: `_inst`, `_hourly`, `_daily`, `_period`. | `ef_et_inst()`, `ef_ra_daily()` |
| N9 | Objetos de control con sufijo `_control`; constructores de reglas con la raíz del módulo. | `ef_h_control()`, `ef_anchor_rule()` |
| N10 | Las funciones internas no se rigen por N2 (no son API), pero mantienen `ef_` cuando forman parte del núcleo. | `ef_flag_registry()` |

## 3. Tabla de nombres

Se listan las 81 funciones públicas o candidatas a públicas que nombran las
especificaciones de `dev/specs/` (se excluyen las internas `ef_abort()`,
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
| `ef_sw_transmissivity()` | 20 | **`ef_tau_sw()`** | 9 | Símbolo τ_sw de METRIC |
| `ef_sw_transmissivity_elevation()` | 30 | **`ef_tau_sw_elevation()`** | 19 | Variante simplificada por elevación |
| `ef_atmospheric_emissivity()` | 25 | **`ef_atm_emissivity()`** | 17 |  |
| `ef_shortwave_in()` | 15 | **`ef_rs_in()`** | 8 | Coincide con el argumento `rs_in` de `ef_net_radiation()` |
| `ef_shortwave_in_measured()` | 24 | **`ef_rs_in_measured()`** | 17 |  |
| `ef_sw_to_slope()` | 14 | **`ef_rs_to_slope()`** | 14 | Misma raíz `rs` que la familia |
| `ef_longwave_in()` | 14 | **`ef_rl_in()`** | 8 | Coincide con el argumento `rl_in` |
| `ef_longwave_out()` | 15 | **`ef_rl_out()`** | 9 | Coincide con el argumento `rl_out` |

### Flujo de calor del suelo (`soil-heat-flux.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_soil_heat_flux()` | 17 | = | 17 | Despachador (`method`) |
| `ef_soil_heat_flux_tasumi()` | 24 | **`ef_g_tasumi()`** | 11 | Métodos con la raíz del símbolo G; mismo `.Rd` que el despachador |
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

### Aerodinámica y calor sensible (`sensible-heat.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_sensible_heat()` | 16 | = | 16 | Nombre de la cadena principal |
| `ef_calibrate_sensible_heat()` | 26 | **`ef_calibrate_h()`** | 14 | Coherente con la clase `earthflux_h_calibration` |
| `ef_sensible_heat_control()` | 24 | **`ef_h_control()`** | 12 | Objeto de control, como `glm.control()` |
| `ef_roughness_length()` | 19 | **`ef_zom()`** | 6 | Símbolo z_om de METRIC |
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
| `ef_et_daily()` | 11 | = | 11 |  |
| `ef_et_daily_evaporative_fraction()` | 32 | **`ef_et_daily_evapfrac()`** | 20 | Alternativa futura (ET-D8) |
| `ef_et_period()` | 12 | = | 12 |  |

### Forzamiento meteorológico y ET de referencia (`weather-forcing.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_air_pressure()` | 15 | = | 15 | Ya implementada en la base de M2 |
| `ef_station_table()` | 16 | = | 16 |  |
| `ef_validate_station_table()` | 25 | **`ef_validate_stations()`** | 20 |  |
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
| `ef_reference_net_radiation()` | 26 | **`ef_ref_net_radiation()`** | 20 | Prefijo `ref_` para la superficie de referencia |
| `ef_reference_soil_heat_flux()` | 27 | **`ef_ref_soil_heat_flux()`** | 21 |  |
| `ef_reference_et()` | 15 | **`ef_ref_et()`** | 9 |  |
| `ef_station_reference_et()` | 23 | **`ef_station_ref_et()`** | 17 |  |
| `ef_etr_hourly()` | 13 | = | 13 |  |
| `ef_etr_daily()` | 12 | = | 12 |  |

### Regionalización y GWR (`gwr-forcing.md`)

| Nombre en las especificaciones | Car. | Nombre propuesto | Car. | Nota |
|---|---:|---|---:|---|
| `ef_regionalize()` | 14 | = | 14 |  |
| `ef_regionalize_cv()` | 17 | = | 17 |  |
| `ef_method_gwr()` | 13 | = | 13 |  |
| `ef_method_idw()` | 13 | = | 13 |  |
| `ef_method_ols()` | 13 | = | 13 |  |
| `ef_method_station()` | 17 | = | 17 |  |
| `ef_gwr_config()` | 13 | = | 13 |  |
| `ef_gwr_fit()` | 10 | = | 10 |  |
| `ef_gwr_bandwidth()` | 16 | = | 16 |  |
| `ef_gwr_search()` | 13 | = | 13 |  |
| `ef_gwr_predict()` | 14 | = | 14 |  |
| `ef_gwr_diagnostics()` | 18 | = | 18 |  |
| `ef_idw_fit()` | 10 | = | 10 |  |
| `ef_ols_fit()` | 10 | = | 10 |  |
| `ef_prediction_control()` | 21 | **`ef_predict_control()`** | 18 | Simetría con `ef_h_control()` |
| `ef_spatial_folds()` | 16 | = | 16 |  |
| `ef_spatial_forcing()` | 18 | = | 18 |  |
| `ef_station_forcing()` | 18 | = | 18 |  |

## 4. Resumen

| | Especificaciones | Propuesta |
|---|---:|---:|
| Funciones | 81 | 81 |
| Nombres que cambian | — | 42 |
| Mediana de caracteres | 17 | 14 |
| Máximo de caracteres | 36 | 21 |
| Nombres con más de 22 caracteres | 23 | 0 |

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

1. El autor aprueba la tabla (con o sin ajustes); el estado pasa a
   **DECIDIDA**.
2. En un mismo cambio se renombran las funciones en `dev/specs/`,
   `dev/SCIENTIFIC_SPEC.md`, `dev/DECISIONS.md` y `dev/ARCHITECTURE.md`, y
   `ef_latent_heat_vaporization()` pasa a `ef_lambda()` en el código (no hay
   release, por lo que no se necesita alias ni deprecación).
3. Los módulos de M2 se implementan directamente con los nombres de la
   columna "Nombre propuesto".
4. Un nombre nuevo no previsto aquí sigue las reglas de §2 y se agrega a la
   tabla en el mismo cambio que crea la función.
