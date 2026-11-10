# Verificación cruzada con el paquete `water`: ejemplo METRIC de Talca

Fecha: **2026-11-10**. Autor: Guillermo Servando Fuentes-Jaque.
Script reproducible: `dev/verification/water-comparison.R`. Registro de
verificación: `VERIFICATION.md`. Especificaciones: `specs/sensible-heat.md`
(§8 y tabla de contraste con `water`), `specs/radiation-components.md`,
`specs/presets.md` §4.

> **Verificación entre implementaciones, no validación.** Se compara el
> núcleo numérico de EarthFlux con otra implementación de METRIC (`water`,
> Olmedo et al.) sobre las mismas entradas. Ninguna cifra de este
> documento se contrasta con flujos medidos: una coincidencia indica que
> las dos implementaciones aplican las mismas fórmulas, no que el
> resultado sea correcto. `water` es una implementación, no una fuente
> primaria (`VERIFICATION.md` §1).

## 1. Datos y versiones

| Elemento | Valor |
|---|---|
| Escena | Landsat 7 ETM+ `LE72330852013046EDC00` (path 233, row 85), recorte de 417 × 508 celdas de 30 m (UTM 19 S), Talca, Región del Maule; objeto `L7_Talca` de `water` (ND), nubosidad 1 % |
| Fecha y hora | 2013-02-15, 14:30:40 UTC (`SCENE_CENTER_TIME`), día juliano 46; 11:30:40 hora local (CLST, UTC−3) |
| DEM | `DEM_Talca` de `water` (131–643 m), en la grilla de la imagen |
| Estación | `apples.csv` de `water`: registros cada 15 min del 15-02-2013, lat −35,42222, lon −71,38639, 201 m, sensores a 2,2 m; viento convertido de km/h a m/s (`cf = 0.2777778`) |
| Meteorología a la pasada (`at.sat`) | T = 22,59 °C, HR = 68,86 %, u = 0,31 m/s a 2,2 m, Rs = 752,92 W m⁻² (interpolación lineal entre registros, redondeada a 2 decimales, `water_WeatherStation.R` l. 326) |
| ETr | ETr horaria de la hora centrada en la pasada 0,53132 mm/h; ETr diaria 6,53360 mm/d (23 períodos horarios: falta el registro de 24:00) |
| Celdas válidas | 211 836 en total; 198 926 con todas las capas definidas (el borde de `terrain()` y las celdas sin Ts quedan `NA` en ambos paquetes) |
| R / terra / sf | 4.3.3 / 1.9.50 / 1.1.3 |
| `water` | 1.0 (2026-10-19, basado en terra), instalado desde el código fuente en una biblioteca privada; no se modificó |
| EarthFlux | 0.1.0.9000, `main` en `c64246f` (rama `docs/water-comparison`), `pkgload::load_all()` |

## 2. El ejemplo de `water` (viñeta `METRIC_advanced`)

Se ejecutó la viñeta `vignettes/METRIC_advanced.Rmd` completa y se
guardaron todos sus productos intermedios. Configuración y fórmulas
aplicadas (archivo y función de `water`, líneas de la versión 1.0):

| Paso | Función (`water/R/…`) | Configuración y fórmula |
|---|---|---|
| Geometría | `solarAngles()` (`water_netRadiation.G.R` l. 278) | Latitud por fila; declinación FAO-56 Ec. 24 con el día UTC; ángulo horario con la **longitud de la estación** para todos los píxeles y Sc de FAO-56 (l. 307); cos θ_rel con la convención γ = aspecto − π (l. 316, quinto término con sen γ) |
| τ_sw | `SWtransmissivity()` (l. 720) | τ_B = 0,98·exp(−0,00146·P/(K_t·cos θ_hor) − 0,075·(W/cos θ_hor)^0,4), W = 0,14·e_a·P + 2,1; τ_D = 0,35 − 0,36·τ_B (0,18 + 0,82·τ_B si τ_B < 0,15); K_t = 1; P de FAO-56 Ec. 7 con el DEM |
| Rs↓ | `incSWradiation()` (l. 367) | Rs↓ = **1367**·max(cos θ_rel, 0)·τ_sw/d², 1/d² = 1 + 0,033·cos(2πJ/365) (l. 375–379): τ total sobre el haz, sin difusa ni reflejada |
| Albedo, LAI, Ts | `albedo(coeff = "Tasumi")`, `LAI("metric2010", L = 0.1)` sobre reflectancia TOA, `surfaceTemperature()` (τ_NB 0,866, R_p 0,91, R_sky 1,32, ε_NB = 0,97 + 0,0033·LAI) | Entradas comunes: se pasan tal cual a EarthFlux |
| ε₀ | `outLWradiation()`, `netRadiation()` | ε₀ = 0,95 + 0,01·LAI (0,98 si LAI > 3) |
| RL↓ | `incLWradiation()` (l. 995–1007) | RL↓ = 0,85·(−ln τ_sw)^0,09·5,67·10⁻⁸·**Ts⁴, con la Ts de cada píxel** |
| RL↑, Rn | `outLWradiation()` (l. 936), `netRadiation()` (l. 1060) | RL↑ = ε₀·5,67·10⁻⁸·Ts⁴; Rn = (1 − α)Rs↓ + RL↓ − RL↑ − (1 − ε₀)RL↓ |
| G | `soilHeatFlux(method = "Tasumi")` (l. 1120–1133) | G/Rn = 0,05 + 0,18·**2,71828**^(−0,521·LAI); si LAI < 0,5: G = 1,8·(Ts − **273,16**) + 0,084·Rn |
| z_om | `momentumRoughnessLength("short.crops", mountainous = TRUE)` (`water_sensibleHeatFlux.R` l. 65–122) | z_om = 0,018·LAI·[1 + (pendiente° − 5)/20] **sin mínimo 1** (`slope.min1 = FALSE`), luego mínimo 0,005 m |
| Anclas | `calcAnchors(anchors.method = "best", n = 5, deltaTemp = 5)` (l. 264) | Frío: LAI 3–6, α 0,18–0,25, NDVI ≥ máx − 0,15, z_om 0,03–0,08, Ts < T_min + 5; caliente: α 0,13–0,15, NDVI 0,10–0,28, z_om ≤ 0,005, Ts > T_max − 5; los 5 más fríos y los 5 más calientes, separados ≥ 500 m, dentro de 30 km de la estación. NDVI de reflectancia TOA |
| Viento | `calcH()` (l. 931–940) | u₂₀₀ = u·ln(200/z_om,w)/ln(2,2/z_om,w) con z_om,w = 0,03 m: **0,636 m/s**, elevado al mínimo `u200.min` = **2 m/s** (con aviso) |
| Ts_datum | `calcH()` (l. 920) | Ts + (z − 201)·6,49/1000 |
| Condiciones de borde | `calcH()` (l. 952–960) | LE_frío = 1,05·ETr·λ(Ts̄_frío), λ = (2,501 − 0,002361·(T − 273,15))·10⁶; LE_caliente = 0 (`ETrF.hot = 0`); H = Rn − G − LE con medias de las anclas |
| Iteración | `calcH()` (l. 1023–1086), `rahStep()` (l. 729–752), `airDensity()` (l. 720) | dT = a·Ts_datum + b (a = pendiente); ρ en H: 349,467·((T_a − 0,0065z)/T_a)^5,26/T_a con T_a = Ts − dT; ρ en L: 1000·P/(1,01·**Ts**·287), fija; L con g = **9,807**; ψ estables −5·2/L (también para ψ_m a 200 m); rah entre 0,1 y 2 m; convergencia: |Δrah|/rah < 1 % de la media de cada clase, más una pasada |
| Píxeles | `replay()` dentro de `calcH()` (l. 1089) | Cada píxel repite la **misma secuencia** de (a, b) de las anclas desde rah neutra |
| ET | `ET24h()` (`water_ET.R` l. 263–293) | ET_inst = 3600·LE/((2,501 − **0,00236**·(Ts − 273,15))·10⁶); ETrF = ET_inst/ETr; ET₂₄ = ETrF·ETr₂₄·C_rad (C_rad = 1); **ET₂₄ < 0 → 0** |
| ETr | `hourlyET()`, `asceHourly()`, `dailyET()` (`water_ET.R` l. 62–140, 373) | ASCE-EWRI (2005) horaria, alfalfa; Δ con 2503; f_cd arrastrada de noche (sol < 0,3 rad, Ec. 46) |

`ET24h()` con capas sueltas devuelve solo ET₂₄; el script recalcula
ET_inst y ETrF con sus expresiones (l. 288–290) y comprueba que
max(ETrF·ETr₂₄, 0) reproduce exactamente el ET₂₄ devuelto.

Resultado de `water`: anclas calientes Ts̄ = 315,78 K, frías 298,55 K;
H_frío = 111,20 W m⁻², H_caliente = 416,39 W m⁻²; **a = 0,195092,
b = −55,8181 K** (notación de `water`), 12 pasadas, convergió; ET₂₄ media
5,229 mm/d en 198 926 celdas.

## 3. Mapeo de opciones

Primera comparación: cada etapa de EarthFlux recibe **exactamente** las
entradas de `water` (incluidas las salidas de `water` de la etapa
anterior), de modo que cada diferencia se atribuye a una sola etapa.
Además se encadenan las etapas de EarthFlux (§4, filas "componentes de
EarthFlux" y "H de EarthFlux").

| Elección | `water` | EarthFlux (función y argumento) |
|---|---|---|
| Geometría | lat por fila, lon de la estación, aspecto − π | `ef_solar_geometry(doy = 46, utc_hour = 14.5112, lat, lon = lon estación, slope, aspect = Aspect_water + π)` |
| τ_sw | `SWtransmissivity(Kt = 1)` | `ef_tau_sw_allen(cos_zenith, pressure = ef_air_pressure(DEM), vapour_pressure = e_a, turbidity = 1)` |
| Rs↓ | τ total sobre el haz, cos θ_rel | `ef_rs_in_modelled(tau_beam = tau$total, tau_diffuse = 0, slope, ground_albedo = 0)` (reproduce la forma de `water`; la partición de EarthFlux se evalúa como sensibilidad) |
| ε_a, RL↓ | Ts del píxel | `ef_atm_emissivity(τ_sw)`, `ef_rl_in(temperature = Ts del píxel)` (RC-12: argumento explícito; el manual usa T_frío, sensibilidad en §8) |
| RL↑, Rn | ε₀ de `water` | `ef_rl_out(lst, emissivity = ε₀)`, `ef_net_radiation()` |
| G | Tasumi | `ef_g_tasumi()` |
| z_om | 0,018·LAI·factor de terreno, mín. 0,005 | **z_om de `water` como entrada** (EarthFlux no implementa el factor de terreno, SH-03; contraste aparte en §4) |
| Viento | u₂₀₀ = 2 m/s (piso) | `u_blend = 2` (EarthFlux no tiene piso, SH-06; `ef_blending_wind()` da 0,636 m/s) |
| Anclas | 5 + 5 celdas, medias | `ef_anchors(cold, hot, aggregate = "mean")` con las mismas celdas |
| Condiciones | ETrF_frío 1,05, ETrF_caliente 0, λ(Ts) | `ef_anchor_conditions(etrf_cold = 1.05, etrf_hot = 0, lambda = ef_lambda(Ts, "fao56"), etr_inst = 0.53132, reference = "alfalfa")` |
| Calibración | ψ_m estable a 2 m, z₁ 0,1, z₂ 2, z_b 200, 1 %, máx. 20, sin amortiguación | `ef_h_control(stable_psi_m_height = 2, z1 = 0.1, z2 = 2, blending_height = 200, tol = 0.01, maxit = 20, damping = 0)`; `ef_calibrate_h(lapse_rate = 0.00649, datum_elevation = 201)` |
| ET | λ(Ts), ETr de `water` | `ef_et_inst(le, ef_lambda(Ts, "fao56"))`, `ef_etrf(reference = "alfalfa")`, `ef_et_daily(method = "etrf")` |

## 4. Resultados por etapa

Diferencias EarthFlux − `water` por píxel. "rel." = máx|Δ| / media|water|.
En todas las filas la recta de ajuste EarthFlux ~ `water` tiene pendiente
1,0000 y r = 1,0000 salvo donde se indica.

| Etapa | Magnitud | n | Media `water` | Δ media | sd Δ | máx\|Δ\| | rel. | Causa |
|---|---|---|---|---|---|---|---|---|
| Geometría | cos θ_hor | 211 836 | 0,7630 | 0 | 0 | 0 | 0 | Idéntica |
| Geometría | cos θ_rel | 200 880 | 0,7558 | ≈ 0 | 5·10⁻¹⁸ | 1,1·10⁻¹⁶ | 1,5·10⁻¹⁶ | Idéntica (precisión de máquina) |
| Rs↓ | τ_sw | 202 686 | 0,7275 | 0 | 0 | 0 | 0 | Idéntica |
| Rs↓ | Rs↓ (W m⁻²) | 200 880 | 769,04 | −0,188 | 0,010 | 0,245 | 3,2·10⁻⁴ | Solo G_sc: cociente EF/`water` = 1366,67/1367 = 0,9997562 en todas las celdas (desviación máx. 8,9·10⁻¹⁶) |
| RL↓ | ε_a | 202 686 | 0,7667 | 0 | 0 | 0 | 0 | Idéntica |
| RL↓ | RL↓ (W m⁻²) | 198 926 | 370,11 | +0,024 | 0,001 | 0,029 | 7,8·10⁻⁵ | Solo σ: cociente = 1,0000660 (desviación máx. 4,4·10⁻¹⁶) |
| RL↑ | RL↑ (W m⁻²) | 198 926 | 464,84 | +0,031 | 0,001 | 0,036 | 7,7·10⁻⁵ | Solo σ |
| Rn | Rn, componentes de `water` | 198 926 | 556,19 | 0 | 0 | 0 | 0 | Idéntica |
| Rn | Rn, componentes de EarthFlux | 198 926 | 556,19 | −0,169 | 0,010 | 0,231 | 4,2·10⁻⁴ | G_sc y σ |
| G | G, LAI ≥ 0,5 | 148 768 | 72,33 | −2,2·10⁻⁵ | 3·10⁻⁶ | 3,5·10⁻⁵ | 4,9·10⁻⁷ | `water` usa e = 2,71828 |
| G | G, LAI < 0,5 | 50 158 | 108,25 | +0,018 | 0 | 0,018 | 1,7·10⁻⁴ | `water` usa 273,16: 1,8 × 0,01 = 0,018 W m⁻² exactos |
| z_om | 0,018·LAI, mín. 0,005 (EarthFlux) | 200 880 | 0,0218 | +0,0030 | 0,0055 | 0,085 | 3,9 | Factor de terreno de `water` (r = 0,950); con ese factor transcrito, idéntica (máx. 2,8·10⁻¹⁷) |
| Viento | u₂₀₀ extrapolado (m/s) | 1 | 0,63551 | 0 | — | 0 | 0 | Idéntico; `water` usa 2 m/s (piso) |
| Condiciones | LE_frío, H_frío, H_caliente (W m⁻²) | 1 | 378,28; 111,20; 416,39 | ≤ 6·10⁻¹⁴ | — | — | — | Idénticas |
| dT | dT (K) | 198 926 | 3,419 | +0,020 | 0,009 | 0,055 | 0,016 | Calibración (§5) |
| H | H (W m⁻²) | 198 926 | 187,68 | −0,327 | 0,125 | 2,04 | 0,011 | Calibración (§5) |
| Ts_datum | Ts_datum (K) | 198 926 | 303,64 | 0 | 0 | 0 | 0 | Idéntica |
| LE | LE con Rn, G, H de `water` | 198 926 | 287,12 | 0 | 0 | 0 | 0 | Idéntica |
| ET_inst | ET_inst (mm/h) | 198 926 | 0,4252 | +5,2·10⁻⁶ | 1,2·10⁻⁶ | 9,4·10⁻⁶ | 2,2·10⁻⁵ | λ de `ET24h()` con 0,00236 en vez de 0,002361 |
| ETrF | ETrF con ET_inst de `water` | 198 926 | 0,8002 | 0 | 0 | 0 | 0 | Idéntica |
| ET₂₄ | ET₂₄ con ETrF de `water` | 198 926 | 5,229 | −0,0005 | 0,019 | 2,14 | 0,41 | `water` trunca ET₂₄ < 0 a 0 (247 celdas, r = 0,99992); con ETrF ≥ 0, idéntica (0) |
| Cadena | LE con H de EarthFlux | 198 926 | 287,12 | +0,327 | 0,125 | 2,04 | 0,007 | De H |
| Cadena | ETrF con H de EarthFlux | 198 926 | 0,8002 | +0,0009 | 0,0004 | 0,0058 | 0,007 | De H |
| Cadena | ET₂₄ con H de EarthFlux | 198 926 | 5,229 | +0,0055 | 0,019 | 2,13 | 0,41 | De H y del truncamiento de `water` |

**Lectura.** Donde las fórmulas coinciden, EarthFlux reproduce `water` a
precisión de máquina (geometría, τ_sw, ε_a, Rn, Ts_datum, LE, ETrF, ET₂₄
sin truncamiento, condiciones de borde). Las demás diferencias de
radiación y G se explican en su totalidad por una constante (G_sc, σ,
273,16, e truncado), comprobado celda a celda con el cociente.

## 5. Calibración de H

### 5.1 Trazas

`water` (a = pendiente, b = intercepto; rah antes de la pasada) y
EarthFlux (a = intercepto, b = pendiente; rah después del paso). Las dos
oscilan de forma amortiguada (viento de 2 m/s: L ≈ −0,74 m en el ancla
caliente, inestabilidad fuerte) y se detienen con el mismo criterio
(cambio relativo de rah < 1 %).

| Iter. | `water` pendiente | `water` intercepto | EF pendiente | EF intercepto | EF rah cal./fría (s/m) | EF máx. cambio rah |
|---|---|---|---|---|---|---|
| 1 | 1,67537 | −492,78 | 1,67882 | −493,81 | 3,92 / 8,76 | 23,08 |
| 2 | 0,02323 | −6,116 | 0,02899 | −7,823 | 31,58 / 39,43 | 0,876 |
| 3 | 0,49927 | −145,10 | 0,47366 | −137,48 | 10,70 / 18,53 | 1,950 |
| 6 | 0,17072 | −48,750 | 0,17708 | −50,637 | 16,31 / 26,09 | 0,137 |
| 9 | 0,19900 | −56,941 | 0,20055 | −57,399 | 15,41 / 24,71 | 0,022 |
| 11 | 0,19639 | −56,189 | 0,19855 | −56,828 | 15,48 / 24,84 | 0,0067 → convergió |
| 12 / cierre | **0,19509** | **−55,818** | **0,19768** | **−56,585** | — | cierre |

Las 12 pasadas de `water` (11 iteraciones + la pasada final tras la
convergencia) equivalen a las 11 iteraciones + el cierre de EarthFlux
(12 pares (a, b) en ambos): la estructura de la fase de anclas es la
misma (`specs/sensible-heat.md` §11.2).

### 5.2 Descomposición de la diferencia de H

El script contiene un emulador transparente con las Ecs. 25–41 del manual
(Waters et al., 2002) y un interruptor por cada punto en que los paquetes
difieren. Con todos los interruptores en `water` reproduce `calcH()`
(máx.|ΔH| = 1,2·10⁻¹² W m⁻²); con todos en EarthFlux reproduce
`ef_calibrate_h()` (4,5·10⁻¹²). Los interruptores se cambian en orden,
acumulativamente:

| Paso (de `water` a EarthFlux) | Pendiente | Intercepto (K) | H̄ (W m⁻²) | ΔH̄ del paso | máx\|ΔH\| del paso | ET̄₂₄ (mm/d)ᵃ |
|---|---|---|---|---|---|---|
| `water` emulado | 0,19509 | −55,818 | 187,68 | — | — | 5,2285 |
| g = 9,807 → 9,81 | 0,19506 | −55,810 | 187,68 | +0,0003 | 0,006 | 5,2285 |
| ρ de L: ρ(Ts) fija → ρ(T_a) de la iteración | 0,19732 | −56,476 | 187,91 | +0,229 | 0,571 | 5,2243 |
| ρ de H: P(T_a) → P(z) de FAO-56 (293 K) | 0,19768 | −56,582 | 187,94 | +0,036 | 0,653 | 5,2237 |
| Medias de las anclas → un punto de calibración por clase | 0,19768 | −56,585 | 187,91 | −0,027 | 0,030 | 5,2242 |
| Fase B: repetición de la secuencia → convergencia por píxel con (a, b) finales (P2) | 0,19768 | −56,585 | 187,35 | −0,565 | 1,251 | 5,2345 |

ᵃ Sin truncar ET₂₄ < 0.

Fase B de EarthFlux: todos los píxeles convergen (mediana 4, máximo 5
iteraciones); en `water` ningún píxel cambia rah más de 1 % en el último
paso repetido. En total (todas las causas), el 6,6 % de las celdas
difiere en más de 0,5 W m⁻².

### 5.3 Punto fijo

Iterando ambos algoritmos hasta tol = 10⁻¹⁰ (43 pares (a, b)):

| Corrida | Pendiente | Intercepto (K) | H̄ (W m⁻²) |
|---|---|---|---|
| `water` (1 %) | 0,19509 | −55,818 | 187,68 |
| `water` emulado, 10⁻¹⁰ | 0,19552 | −55,941 | 187,71 |
| EarthFlux (tol 0,01) | 0,19768 | −56,585 | 187,35 |
| EarthFlux, tol 10⁻¹⁰ | 0,19796 | −56,662 | 187,94 |

En el punto fijo la diferencia de H es 0,23 W m⁻² de media (máx. 0,80):
solo las fórmulas de ρ (y g). El resto de la diferencia de §5.2 (fase B,
−0,57 W m⁻² de media) es el **criterio de parada**: en esta escena la
fase B de EarthFlux con tol = 0,01 se detiene, desde rah neutra, a unas
4 iteraciones y deja H 0,59 W m⁻² (0,3 %) por debajo de su propio punto
fijo; la repetición de las 12 pasadas en `water` queda a 0,03 W m⁻². Es
coherente con lo documentado en `ef_h_control()` ("`tol = 0.01` stops
0.6 % away from the fixed point of the intercept").

## 6. Meteorología y ETr

Con los mismos datos `at.sat` y las funciones de EarthFlux
(`ef_ra_period(standard = "asce")`, `ef_rso()`, `ef_ref_net_radiation()`,
`ef_ref_soil_heat_flux()`, `ef_ref_et(reference = "alfalfa", timestep =
"hourly", standard = "asce")`):

| Magnitud | `water` | EarthFlux | Δ | Causa |
|---|---|---|---|---|
| ETr de la hora centrada en la pasada (mm/h) | 0,531320 | 0,531324 | +4,5·10⁻⁶ | Redondeos de `water`: Δ con 2503 (= 4098 × 0,6108 = 2503,06) y 0,06667 h/° en vez de 1/15 |
| ETr diaria, 23 períodos con la f_cd de `water` (mm/d) | 6,533598 | 6,533593 | −5,1·10⁻⁶ | Ídem |

La ETr diaria de EarthFlux no se calculó con `ef_station_ref_et()`: con
`day_completeness = "all_periods"` el día de `apples.csv` (sin el registro
de 24:00 ni la noche previa para `night_cloudiness = "low_sun"`) daría
`NA`, mientras `water` suma 23 períodos. En la comparación del núcleo la
ETr es una entrada común.

## 7. Segunda comparación: anclas elegidas por EarthFlux

Criterios del preset `idaho2002_elev` (versión 2, `CANDIDATA`;
`ef_preset("idaho2002_elev")$anchors`, `workflow_anchor_criteria()` en
`R/api-presets.R` l. 66): frío NDVI ≥ p90 y albedo 0,14–0,26; caliente
NDVI ≤ p10, NDVI > 0 y albedo 0,18–0,35; homogeneidad sd(Ts) ≤ 1,5 K en
3 × 3 celdas; 20 % más frío y 20 % más caliente; búsqueda en 30 km de la
estación y luego en toda la escena; media. Mismas capas que `water` (NDVI
de reflectancia TOA, albedo de Tasumi, Ts, LAI), mismas Rn, G, z_om,
viento, ETr y condiciones. **Los criterios se fijaron para píxeles MODIS
de 1 km (`verification/anchors-m5-23.md`); aquí se aplican a Landsat de
30 m sin reajuste.**

| Fuente | Clase | n | Ts̄ (K) | NDVI | albedo | LAI | z (m) | Rn | G | z_om |
|---|---|---|---|---|---|---|---|---|---|---|
| `water` best, n = 5 | caliente | 5 | 315,78 | 0,200 | 0,140 | 0,053 | 185 | 538,3 | 121,9 | 0,0050 |
| `water` best, n = 5 | fría | 5 | 298,55 | 0,802 | 0,192 | 4,37 | 155 | 525,6 | 36,1 | 0,0646 |
| EarthFlux `idaho2002_elev` | caliente | 229 | 312,99 | 0,207 | 0,186 | 0,073 | 186 | 503,1 | 114,0 | 0,0050 |
| EarthFlux `idaho2002_elev` | fría | 2584 | 298,72 | 0,771 | 0,154 | 3,50 | 170 | 547,4 | 43,6 | 0,0524 |

Embudo: frío 198 877 → NDVI ≥ 0,7257 (p90): 19 957 → albedo: 13 688 →
homogeneidad: 12 918 → 20 % más frío (Ts ≤ 298,91 K): 2584; caliente
NDVI ≤ 0,2999 (p10): 19 945 → NDVI > 0: 19 896 → albedo 0,18–0,35: 1343
→ homogeneidad: 1144 → 20 % más caliente (Ts ≥ 311,85 K): 229. Ambas
clases dentro de 30 km de la estación (primera etapa, sin relajación).

| Resultado | `water` | EarthFlux, anclas de `water` | EarthFlux, anclas del preset |
|---|---|---|---|
| Pendiente / intercepto de dT | 0,19509 / −55,818 | 0,19768 / −56,585 | 0,20434 / −58,397 |
| H̄ (W m⁻²) | 187,68 | 187,35 | 205,21 (Δ +17,5; máx. 35,2) |
| ET̄₂₄ (mm/d) | 5,229 | 5,234 | 4,909 (Δ −0,33 frente a las anclas de `water` en EarthFlux; máx. 0,69) |

Las anclas calientes del preset son 2,8 K más frías: el albedo de 0,18–0,35
(pensado para el albedo de cielo blanco de MODIS sobre campos secos) excluye
los suelos más oscuros y calientes que `water` exige (0,13–0,15), y el
20 % más caliente promedia muchas celdas en vez de tomar las 5 más
calientes. La pendiente sube 4,7 %, H̄ sube 9 % y ET̄₂₄ baja 6 %. Es una
diferencia de criterio de selección (por diseño), no de fórmulas.

## 8. Sensibilidad: opciones de EarthFlux más cercanas a las fuentes

Cada corrida cambia una elección de `water` por la de las fuentes y
recalibra con las mismas anclas; Δ frente a la cadena de EarthFlux con
las entradas de `water` (ET̄₂₄ = 5,2345 mm/d).

| Cambio | Efecto |
|---|---|
| RL↓ con T_frío + 0,0065·(z_frío − z) (Waters et al., 2002, p. 23, Ec. 23; ap. 12, p. 96, Ec. 12-8; RC-12) en vez de la Ts de cada píxel | Rn: Δ̄ = −24,7 W m⁻², máx. 91 W m⁻² (r = 0,930); ET₂₄: Δ̄ = −0,072 mm/d, máx. 0,18 |
| z_om = máx(0,018·LAI, 0,005) sin el factor de terreno de `water` | ET₂₄: Δ̄ = +0,017 mm/d, máx. 0,24 |
| Ambos | ET₂₄: Δ̄ = −0,057 mm/d, máx. 0,30 |
| Rs↓ particionada (haz sobre la ladera + difusa isótropa + reflejada con el albedo medio; `ef_rs_in_modelled()` con τ_b, τ_d de `ef_tau_sw_allen()`) | Rs↓: Δ̄ = +1,1 W m⁻², máx. 105 W m⁻² en laderas (r = 0,99997) |
| Longitud de cada píxel en el ángulo horario (en vez de la de la estación) | cos θ_hor: máx. 9,7·10⁻⁴ |

La calibración interna absorbe casi todo el sesgo de Rn introducido por
RL↓ (−24,7 W m⁻² en Rn, −1,4 % en ET₂₄), como se espera de METRIC.

## 9. Viñeta `METRIC_simple`

`METRIC.EB(plain = TRUE, sat = "L7")` con los valores por defecto: DEM
constante (201 m), anclas `"percentile"` (2263 calientes, 225 frías),
z_om,w = 0,015 m, sin factor de terreno ni lapse rate. Resultado: a =
0,22690, b = −65,320 K, 13 pasadas, u₂₀₀ = 2 m/s (piso); ETrF > 1,1 en el
5,5 % de las celdas; ET̄₂₄ = 5,09 mm/d; `METRIC.EB()` pone LE < 0 a 0 en
1660 celdas (`water_METRIC.R` l. 649). No se comparó celda a celda: usa
las mismas funciones que la viñeta avanzada (salvo el DEM constante y las
anclas), cuyas fórmulas se contrastaron arriba.

## 10. Diferencias clasificadas

Categorías: **(a)** error de EarthFlux; **(b)** error o desviación de
`water` respecto de la fuente; **(c)** diferencia metodológica deliberada
y documentada; **(d)** sin resolver. Las líneas de EarthFlux son las de
esta rama.

| # | Diferencia | Magnitud en el ejemplo | `water` | EarthFlux | Fuente | Cat. |
|---|---|---|---|---|---|---|
| 1 | Constante solar: 1367 frente a 0,0820 MJ m⁻² min⁻¹ = 1366,67 W m⁻² | Rs↓ −0,024 % (máx. 0,25 W m⁻²) | `incSWradiation()`, `water_netRadiation.G.R` l. 379 | `EF_SOLAR_CONSTANT`, `R/constants.R` l. 56 | FAO-56 Ec. 21; Waters et al. (2002), p. 19, Ec. 12 (1367) | (c) |
| 2 | σ: 5,67·10⁻⁸ frente a CODATA 5,670374419·10⁻⁸ | RL +0,0066 % (máx. 0,036 W m⁻²) | l. 936, 1007 | `EF_STEFAN_BOLTZMANN`, `R/constants.R` l. 41 (RC-07) | Waters et al. (2002), pp. 22–23 | (c) |
| 3 | RL↓ con la Ts de cada píxel en vez de T_frío (+ lapse en montaña) | Rn 24,7 W m⁻² de media (máx. 91); ET₂₄ −1,4 % tras recalibrar | `incLWradiation()` l. 1007 (no documentado como elección; la línea alternativa comentada usa T_a) | `ef_rl_in(temperature)` explícito, `R/metric-radiation.R` l. 971 (RC-12); el flujo de trabajo usa T_frío (`workflow_metric()`, `R/api-run.R`; preset `rl_in_temperature = "cold_anchor"`) | Waters et al. (2002), p. 23, Ec. 23 ("using T_cold … for T_a"); ap. 12, p. 96, Ec. 12-8; IAHS 2012, p. 74 | (b) |
| 4 | Rs↓ en laderas: τ total sobre cos θ_rel frente a partición haz/difusa/reflejada | 0 con la opción equivalente; hasta 105 W m⁻² con la partición | `incSWradiation()` l. 377–379 | `ef_rs_in_modelled()` / `ef_rs_to_slope()`, `R/metric-radiation.R` l. 523, 810 (RC-09) | Waters et al. (2002), ap. 12, pp. 93–95 (Ec. 12 con cos θ de la ladera, τ total) | (c) |
| 5 | Ángulo horario con la longitud de la estación para toda la escena | cos θ_hor ≤ 9,7·10⁻⁴ | `solarAngles()` l. 304–307 (documentado) | `ef_solar_geometry(lon)` por píxel, `R/solar-geometry.R` l. 356 | FAO-56 Ec. 31 (longitud del lugar) | (c) |
| 6 | G de Tasumi con e = 2,71828 | 3,5·10⁻⁵ W m⁻² | `soilHeatFlux()` l. 1130 | `ef_g_tasumi()`, `exp()`, `R/metric-soil-heat.R` l. 360 | — | (b), despreciable |
| 7 | G de Tasumi (LAI < 0,5) con 273,16 K en vez de 273,15 | +0,018 W m⁻² exactos | `soilHeatFlux()` l. 1132 (el resto de `water` usa 273,15) | `EF_KELVIN_OFFSET`, `R/metric-soil-heat.R` l. 376 (G-D9) | Definición de la escala Celsius | (b), despreciable |
| 8 | Factor de terreno de z_om aplicado también con pendiente < 5° (reduce z_om hasta ×0,75 en llano) | z_om: r = 0,950, máx. 0,085 m; ET₂₄ ±0,02 mm/d de media (máx. 0,24) | `momentumRoughnessLength()` l. 117–118 (`slope.min1 = FALSE` por defecto, documentado) | No implementado (SH-03); la comparación usa la z_om de `water` | Waters et al. (2002), ap. 12, p. 97, Ec. 12-9; IAHS 2012, p. 74 ("for slope_deg ≥ 5°") | (c) |
| 9 | Piso de u₂₀₀ = 2 m/s | Viento usado 2 m/s frente a 0,636 m/s extrapolado | `calcH()` l. 935–940, `calcH.control(u200.min)` | Sin piso (SH-06); la comparación pasa 2 m/s | — (`water` cita METRIC) | (c) |
| 10 | g = 9,807 frente a 9,81 | máx. 0,006 W m⁻² en H | `rahStep()` l. 733 | `EF_GRAVITY`, `R/constants.R` l. 74 | Waters et al. (2002), p. 32, texto de la Ec. 34 (9,81) | (c) |
| 11 | ρ en L: ρ(Ts) con P(z) fija desde el inicio frente a la ρ(T_a) de cada iteración | H +0,23 W m⁻² de media, máx. 0,57 | `calcH()` l. 927; `rahStep()` l. 733 | `h_stability_step()`, `R/metric-sensible-heat.R` l. 826; ρ de l. 903 y 992 (SH-10) | Waters et al. (2002), p. 31, paso 6, y p. 34, pasos 12 y 14 (ρ recalculada con T_a en cada iteración); p. 32, Ec. 34 | (b) |
| 12 | ρ en H (y en la inversión de dT): P de la atmósfera estándar evaluada con T_a en vez de 293 K | ρ de −0,004 a +0,23 % en esta escena (mediana +0,05 %); H máx. 0,65 W m⁻² | `airDensity()` l. 720–722 (cita "Allen et al., 2007, Eq. 37") | `air_density_core()`, `R/metric-sensible-heat.R` l. 97 (FAO-56 recuadro 6 con P de FAO-56 Ec. 7; SH-08) | El manual no imprime la ecuación de ρ (p. 31); Allen et al. (2007) Ec. 37 no disponible | (d) |
| 13 | Anclas múltiples: media de rah y ρ de los píxeles frente a un punto de calibración (media de las entradas) | H máx. 0,03 W m⁻² | `calcH()` l. 1030–1041 | `anchor_calibration_points()`, `ef_anchor_conditions()`, `h_anchor_inputs()` (P0-9, D-AP) | El manual usa un píxel por clase (p. 23) | (c) |
| 14 | Fase B: repetición de la secuencia de (a, b) (P1) frente a convergencia por píxel con (a, b) finales (P2) | H −0,57 W m⁻² de media, máx. 1,25; casi todo es el criterio de parada (§5.3) | `replay()` l. 1089 | `h_phase_b()`, `R/metric-sensible-heat.R` l. 989 (P0-10) | Waters et al. (2002), p. 34, pasos 11–16 (dT de cada píxel revisado en cada iteración) | (c) |
| 15 | Tolerancia de la fase B: 1 % de cambio de rah desde rah neutra deja H a −0,3 % de su punto fijo con estabilidad fuerte | H̄ −0,59 W m⁻² frente al punto fijo; ET̄₂₄ +0,01 mm/d | — | `ef_h_control(tol = 0.01)` compartida por las fases A y B, `R/metric-sensible-heat.R` l. 256, 1027 | Waters et al. (2002), p. 34, paso 15 (sin tolerancia numérica) | (c), con acción recomendada |
| 16 | Notación de dT: a pendiente, b intercepto (`water` y manual) frente a a intercepto, b pendiente | Ninguna | `rahStep()` l. 730 | `dt_coef_core()`, `R/metric-dt.R` l. 204 (SH-12) | Waters et al. (2002), p. 31 | (c) |
| 17 | λ con 0,00236 en `ET24h()` y 0,002361 en `calcH()` | ET_inst 2,2·10⁻⁵ relativo | `ET24h()` `water_ET.R` l. 288 frente a `calcH()` l. 954 | Un solo λ de entrada (`ef_lambda()`, `R/shared-physics.R` l. 170; ET-D1) | FAO-56, anexo 3, Ec. 3-1 (2,361·10⁻³) | (b), despreciable |
| 18 | λ de la temperatura de superficie (`water`) frente a λ como entrada (constante en los presets) | 0 en la comparación (se pasó λ(Ts)) | `calcH()` l. 954, `ET24h()` l. 288 | `ef_lambda(method = "fao56")` espera temperatura del aire; `"metric"` no implementado (ET-D1, V2) | El manual no da λ(T) (`VERIFICATION.md` fila 48) | (c) |
| 19 | ET₂₄ < 0 → 0 (`ET24h()`) y LE < 0 → 0 (`METRIC.EB()`) | 247 celdas (máx. 2,14 mm/d) | `water_ET.R` l. 293; `water_METRIC.R` l. 649 | Sin corrección; se marca (principio 6; `EF_ET_NEGATIVE`) | Waters et al. (2002), p. 35 (ETrF negativos posibles; sin truncamiento) | (c) |
| 20 | ETr: Δ con 2503 y 0,06667 h/° | 4,5·10⁻⁶ mm/h; 5·10⁻⁶ mm/d | `asceHourly()`, `asceRa()` `water_ET.R` l. 108, 144 | `ef_es_slope()` (4098), `ef_ra_period()` (1/15) | ASCE-EWRI (2005) Ec. 36 (2503); FAO-56 Ecs. 13 y 31 | (c) |
| 21 | Criterios de selección de anclas | Pendiente +4,7 %, ET̄₂₄ −6 % | `calcAnchors("best")` l. 179–251 | Preset `idaho2002_elev` v2, `R/api-presets.R` l. 66 (M5-23, ajustado a MODIS 1 km) | Waters et al. (2002), p. 23 y ap. 7 (guías visuales) | (c) |

**No se encontró ningún error de EarthFlux (categoría a).**

Corrección de documentación hecha en esta rama: la documentación de
`ef_air_density()` decía que la variante de densidad de las
implementaciones de METRIC es "about 0.6 % higher", como si fuera una
diferencia constante. Es 0 a nivel del mar o con T_a = 293 K, crece con
la elevación y con T_a − 293 K, y es negativa por debajo de 293 K (0,6 %
es el caso T_a = 316 K, 700 m de `specs/sensible-heat.md` §8.2); en esta
escena va de −0,004 a +0,23 %. Se reescribió la frase (`R/metric-sensible-heat.R`,
`man/ef_air_density.Rd`).

## 11. Conclusiones

1. **Donde las fórmulas coinciden, EarthFlux reproduce `water` a
   precisión de máquina**: geometría solar, τ_sw, ε_a, Rn con los mismos
   componentes, Ts_datum, condiciones de borde de las anclas, LE, ETrF y
   ET₂₄ (sin truncamiento), ETr horaria y diaria (salvo redondeos de 10⁻⁶).
2. Las diferencias de Rs↓, RL↓, RL↑, Rn y G se deben enteramente a
   constantes (G_sc, σ, 273,16, e truncado), comprobado celda a celda:
   todas por debajo de 0,25 W m⁻².
3. La calibración de H difiere en 0,33 W m⁻² de media (máx. 2,0 W m⁻²,
   1 %) y la pendiente de dT en 1,3 %. Un emulador que reproduce ambos
   paquetes a 10⁻¹² W m⁻² reparte la diferencia: ρ de L (0,57), ρ de H
   (0,65), criterio de parada de la fase B (1,25), agregación de anclas
   (0,03) y g (0,006), en máx.|ΔH| por paso. En ET₂₄ el efecto conjunto es
   de 0,006 mm/d de media (máx. 0,038 mm/d sin contar el truncamiento).
4. Las diferencias grandes provienen de elecciones de `water` distintas de
   la fuente (RL↓ con la Ts de cada píxel: 25 W m⁻² en Rn) o de opciones
   de diseño (factor de terreno de z_om, partición de Rs↓ en laderas,
   piso de viento, truncamiento de ET, criterios de anclas). La
   calibración interna de METRIC absorbe casi todo el sesgo de Rn.
5. Con sus propios criterios (preset `idaho2002_elev`, ajustado a MODIS
   1 km), EarthFlux elige anclas calientes más frías (2,8 K) y da ET₂₄
   6 % menor que con las anclas de `water`. Es la mayor diferencia de
   resultado del ejemplo y no es de fórmulas.

## 12. Acciones recomendadas

1. **Tolerancia de la fase B** (fila 15): separar la tolerancia de la
   fase B de la de la fase A, o usar en la fase B una tolerancia menor
   (p. ej., 10⁻⁴; cuesta unas pocas iteraciones por píxel), o documentar
   en `ef_calibrate_h()` el sesgo de H frente al punto fijo con
   estabilidad fuerte. Decisión del autor (P0-10).
2. **ρ en H** (fila 12): mantener `CANDIDATA` hasta contrastar con Allen
   et al. (2007) Ec. 37 (pendiente de `VERIFICATION.md` §5).
3. **RL↓** (fila 3): la comparación confirma la magnitud del efecto de la
   temperatura de RL↓ (RC-12); el flujo de trabajo de EarthFlux ya sigue
   la Ec. 23 del manual.
4. **Factor de terreno de z_om** (SH-03): al implementarlo, seguir IAHS
   2012 (solo para pendiente ≥ 5°, factor ≥ 1), no el defecto de `water`.
5. **Anclas en Landsat** (fila 21): si se añade un preset para 30 m,
   revisar las bandas de albedo del ancla caliente (0,18–0,35 excluye los
   suelos desnudos oscuros de 0,13–0,15) y la ventana de homogeneidad
   (3 × 3 celdas = 90 m, frente al píxel térmico de 60 m de ETM+).
6. Comunicar a los autores de `water`, si se estima útil, las filas 3, 7,
   11 y 17 (desviaciones respecto del manual o incoherencias internas).

## 13. Reproducción

```sh
# water 1.0 instalado desde su código fuente en una biblioteca privada
R CMD INSTALL --no-build-vignettes -l /ruta/rlib /ruta/water
# desde la raíz del código de EarthFlux
WATER_LIB=/ruta/rlib WATER_CMP_OUT=/ruta/salida \
  Rscript dev/verification/water-comparison.R
```

Unos 40 s. Escribe en `WATER_CMP_OUT` las tablas CSV (`stages.csv`,
`scalars.csv`, `water-iterations.csv`, `earthflux-iterations.csv`,
`h-decomposition.csv`, `fixed-point.csv`, `anchors-*.csv`,
`settings-water.csv`, `versions.csv`) y `water-comparison.rds`. No se
versionan datos: solo se leen los datos de ejemplo que distribuye `water`.
