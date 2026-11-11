# EarthFlux — Registro de decisiones

Estado: **borrador M1** · Fecha de corte: **2026-11-04** · Autor y
mantenedor: Guillermo Servando Fuentes-Jaque.

Este documento es el **registro único** de las decisiones abiertas y
cerradas de EarthFlux. No crea decisiones nuevas: cada entrada cita el
documento y la sección (o el ID) donde la decisión está definida, y
reproduce la recomendación **tal como está escrita allí**. Cuando dos o más
documentos tratan la misma cuestión, la sección 4 las agrupa como
**decisiones transversales** y propone una única ruta de resolución,
identificada explícitamente como propuesta de este registro.

> **Fuente de verdad.** El documento dueño de cada decisión sigue siendo la
> fuente de verdad (`SCIENTIFIC_SPEC.md` para la ciencia, `ARCHITECTURE.md`
> para la arquitectura, cada `specs/*.md` para su módulo). Al decidir, se
> actualiza **primero** el documento dueño y luego este registro.

---

## 0. Convenciones

### 0.1 Estados

| Estado | Significado |
|---|---|
| `ABIERTA` | Hay opciones y, a lo sumo, una recomendación provisional. Incluye las marcadas "provisional", "propuesta" o "a confirmar" en su documento. |
| `DECIDIDA` | El autor la tomó (o quedó registrada como adoptada en el documento dueño). Se indica la fecha cuando el documento la registra; si no, "fecha no registrada". Puede ser revisable. |
| `CERRADA` | Resuelta y sin trabajo pendiente (p. ej., DOI verificado), o sustituida por una decisión del autor. |

### 0.2 Prioridades

| Prioridad | Criterio |
|---|---|
| **P0** | Bloquea la implementación en M2 de la cadena física METRIC: Rn → G → anclas → H → LE → ET (incluidos los componentes de radiación y las convenciones comunes del núcleo `ef_*()`). |
| **P1** | Bloquea M3 (forzamiento espacial / GWR, estaciones) o M4 (preprocesamiento MODIS). |
| **P2** | Posterior: M5 (pipeline integrado, `earthflux()`), M6 (validación), M7 (CRAN), M8 (publicación). |

Las decisiones `DECIDIDA` y `CERRADA` llevan prioridad "—".

### 0.3 Normalización de IDs

Los IDs originales se conservan en la columna **Orig.** Se añade prefijo
solo donde los IDs colisionan entre documentos:

| Prefijo normalizado | Documento | IDs originales |
|---|---|---|
| `NR-D1` … `NR-D7`, `NR-10.1` | `specs/ef_net_radiation.md` §10 | D1–D7; §10.1 "Tomadas" |
| `RC-01` … `RC-17` | `specs/radiation-components.md` §9 | RC-01–RC-17 (sin cambio) |
| `G-D1` … `G-D9`, `G-5.2` | `specs/soil-heat-flux.md` §11, §5.2 | D1–D9; "Decisión propuesta: opción C" |
| `D-AP-01` … `D-AP-12` | `specs/anchor-pixels.md` §9 | sin cambio (las preguntas Q-AP-01…10 de §4 se registran bajo D-AP-12) |
| `SH-01` … `SH-20` | `specs/sensible-heat.md` §18 | sin cambio |
| `ET-D1` … `ET-D16` | `specs/evapotranspiration.md` §13 | sin cambio |
| `WF-01` … `WF-16`, `SPEC-5.1` | `specs/weather-forcing.md` §11; `SCIENTIFIC_SPEC.md` §5 | WF-01–WF-16; "Decisión metodológica 5.1" |
| `GW-01` … `GW-23` | `specs/gwr-forcing.md` §13 | sin cambio |
| `MP-01` … `MP-14` | `specs/modis-products.md` §15 | sin cambio |
| `BK-1` … `BK-4` | `decisions/gwr-backend.md`, "Decisiones del autor" | filas de la tabla (sin ID original) |
| `ARCH-x` | `ARCHITECTURE.md` (número de sección) | sin ID original |
| `DEV-x` | `DEVELOPMENT.md` (número de sección) | sin ID original |
| `VP-x` | `VALIDATION_PLAN.md` (número de sección) | sin ID original |
| `SPEC-x` | `SCIENTIFIC_SPEC.md` (número de sección) | sin ID original |
| `T-01` … `T-22` | Este registro, §4 | grupos transversales (no son decisiones nuevas) |

**Colisiones detectadas (motivo de los prefijos).** "D1, D2, …" designa a
la vez: decisiones de `ef_net_radiation.md` (D1–D7), decisiones de
`soil-heat-flux.md` (D1–D9), las **opciones** D1/D2 de ETr24 en
`weather-forcing.md` §5.6 y los **documentos fuente** D1–D16 de
`modis-products.md` §2.1. Además, en `sensible-heat.md` §11.7 las
estrategias de Fase B se llaman "P1"/"P2", lo que choca con las etiquetas de
prioridad de este registro: aquí se escriben "estrategia P1/P2 de Fase B".
Otras etiquetas de opciones (O1–O5, T1–T5, A1–A6, E1–E4, V1…) son locales a
su documento y no se usan como IDs de decisión.

---

## 1. Decisiones P0 para el autor

### 1.0 Adopción provisional para M2 (2026-11-04)

Por indicación del autor (avanzar M2 sin haber respondido aún las preguntas
P0), se adoptan las **recomendaciones escritas abajo para P0-4 … P0-12**
con estado **`DECIDIDA (provisional)`, 2026-11-04**, revisables por el
autor antes de `0.1.0`. **P0-1, P0-2 y P0-3 siguen `ABIERTA`**: dependen de
leer Allen, Tasumi & Trezza (2007), aún no disponible. Se adopta además la
propuesta de severidad de `specs/flags.md` §5 (FL-05: tercer nivel
`critical`; FL-06: `critical` para `EF_H_CALIBRATION_NOT_CONVERGED` y
`EF_H_DT_SLOPE_NONPOSITIVE`).

Regla para M2 mientras P0-1 … P0-3 estén abiertas: las formulaciones no
verificadas quedan `CANDIDATA`, se exponen mediante **argumentos explícitos
sin valor por defecto** (p. ej., la altura de ψ_m estable de SH-11 como
control del tipo `stable_psi_m_height`; RL↓ mediante un argumento de
temperatura agnóstico, `ef_rl_in(temperature, …)`, RC-12) y se
rotulan como `CANDIDATA` en roxygen.

> **Actualización 2026-11-05 (M2-08 … M2-10, §1.2).** El manual SEBAL de
> Idaho (Waters et al., 2002), antecesor directo de METRIC, y Allen et al.
> (2012, IAHS Publ. 352) se contrastaron formulación por formulación
> ([`VERIFICATION.md`](VERIFICATION.md)). Las formas confirmadas palabra
> por palabra pasan a `VERIFICADA (SEBAL-Idaho 2002)` o
> `VERIFICADA (IAHS 2012)` (política M2-08) y dejan de estar sujetas a esta
> regla; las no cubiertas siguen `CANDIDATA` y sin defecto. **P0-2 queda
> RESUELTA** (SH-11: 2 m, Ec. 38 del manual, M2-09); P0-1 y P0-3 se
> actualizan en §1.1.

| P0 | Se adopta | Filas que pasan a `DECIDIDA (provisional)` (§5) | Sigue pendiente |
|---|---|---|---|
| P0-4 | K y radianes en el núcleo `metric`; °C en `forcing` y ET de referencia con conversión explícita en la frontera; `doy` + `utc_hour` numéricos | ARCH-4, WF-02, RC-01, RC-03 (convención) | *View time* de MOD21 (MP-01) |
| P0-5 | Una constante por magnitud (`R/constants.R`): 273.15 K, σ CODATA exacto, regla de Gsc; literales normativos solo en ET de referencia | G-D9, RC-07, WF-14; ET-D3 (ρ_w como constante, misma regla) | Valor de Gsc (RC-06: regla adoptada, valor sin verificar; constante `CANDIDATA`) |
| P0-6 | ρ_air de §8.1 con T_a = Ts − dT y P de `ef_air_pressure()` o medida; T_a y ρ iteradas en L; dT₀ = 0; c_p en una sola constante nombrada | SH-08, SH-10 (salvo g), SH-19 | SH-09 (valor de c_p, depende de P0-1): constante `CANDIDATA` 1004; g `CANDIDATA` |
| P0-7 | Una sola `ef_lambda()`, `method` sin defecto; `"constant"` como defecto futuro de `earthflux()` hasta V2; guarda [10⁶, 10⁷] J kg⁻¹ | ET-D1, ET-D2 | `"metric"` (`CANDIDATA`, no implementada hasta V2) |
| P0-8 | Núcleo de anclas sin umbrales ni k por defecto, sin relajación automática, `etrf_hot`/`le_hot` explícitos | D-AP-01, D-AP-02, D-AP-04, D-AP-05 | ~~Preset `VERIFICADA` para `earthflux()`~~: sustituido por M5-08 (presets `CANDIDATA` admitidos con estado declarado y aviso) |
| P0-9 | Un punto de calibración por clase con `aggregate` explícito; condiciones de borde en función propia de la etapa [B] | D-AP-06, SH-14, D-AP-03 | — |
| P0-10 | Fase B con estrategia P2, `tol` = 0.01 por ancla, `maxit` = 20, ω = 0, driver de calibración exportado. *Revisada por M2-11 (2026-11-10, §1.2):* una tolerancia por fase, `tol` = 10⁻⁶ y `maxit` = 100 en las anclas, `pixel_tol` = 10⁻⁵ y `pixel_maxit` = 100 por píxel | SH-15, SH-16, SH-17 | — |
| P0-11 | Entrada imposible → error con clase en el núcleo; la orquestación convierte en `NA` + flag lo marcado aguas arriba; `on_invalid` no adoptado | G-D6, ET-D6 | Política de la orquestación M2–M3 (T-13) |
| P0-12 | Núcleo vectorizado; longitud 0 rechazada; `dim` sin reciclar; una función por método + despachador delgado con `method` sin defecto; clases de retorno coordinadas (`ARCHITECTURE.md` §3.2); condiciones con datos (T-17) | ARCH-3, G-5.2, G-D3, D-AP-09, ET-D12, SH-18, D-AP-10 (NR-D5, NR-D6 confirmadas) | Revisión del tamaño de la API antes de `0.1.0` (T-16) |

Al implementar `ef_air_pressure()` se tomó además la ubicación compartida
recomendada por RC-17 = WF-01 (`R/shared-physics.R`), también
`DECIDIDA (provisional)`. El detalle de las convenciones vive en los
documentos dueños: `ARCHITECTURE.md` §3–§4, `specs/flags.md` §4.2, §5, §7
y §9, `R/constants.R` y `R/diagnostics.R`.

### 1.2 Decisiones de implementación y armonización de M2 (2026-11-04)

Tomadas al implementar los cinco módulos de M2 (radiación, G, anclas, H,
LE/ET) y al armonizarlos después de fusionarlos. Estado: **`DECIDIDA
(provisional)`, 2026-11-04**, revisables por el autor antes de `0.1.0`
(las tres primeras por indicación del autor de avanzar M2). Los documentos
dueños registran el detalle en sus secciones de estado de implementación.
M2-08 … M2-10 se tomaron el 2026-11-05, en la revisión de verificación
contra el manual SEBAL de Idaho (registro en
[`VERIFICATION.md`](VERIFICATION.md)); M2-08 y M2-09 son `DECIDIDA`
(regla de estados y resolución con fuente primaria) y M2-10 corrige una
decisión provisional (SH-10) para alinearla con la fuente. M2-11 se tomó
el 2026-11-10, tras la verificación cruzada con `water`
([`verification/water-comparison.md`](verification/water-comparison.md)
§5.3 y §12), y revisa la provisional P0-10 (SH-16); es `DECIDIDA
(provisional)`.

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M2-01 | `ef_etrf()` y `ef_et_daily_etrf()` (y el despachador `ef_et_daily()`) se implementaron como definiciones operativas `CANDIDATA (corroborada)` (Olmedo et al., 2016, Ec. 4) **antes** de verificar Allen et al. (2007). Es la "decisión explícita registrada" que pide P0-1 para adelantarlas | Indicación del autor de avanzar M2; la forma ETrF = ET_inst/ETr_inst y ETa = ETrF·ETr_24 es la definición operativa de METRIC en todas las fuentes secundarias consultadas; P0-1 sigue `ABIERTA` y el rótulo `CANDIDATA` se revisa al leer el artículo | `evapotranspiration.md` §14, §14.1 |
| M2-02 | Argumento `reference` (`"alfalfa"` / `"grass"`) **obligatorio y sin defecto** en `ef_etrf()`, `ef_et_daily_etrf()` y `ef_et_daily()` (y en `ef_anchor_conditions()`), validado por una sola función (`check_reference_type()`, con las clases de `check_method()`) | Una ETrF solo tiene sentido respecto de una referencia (T-12); hacer explícita la elección no cambia la aritmética; la comprobación de coherencia entre pasos sigue en la orquestación (ET-D9) | `evapotranspiration.md` §6.4, §14.1; `anchor-pixels.md` (nota de estado) |
| M2-03 | `EF_G_LOW_LAI_BRANCH` (clase I-m) registrado junto con `ef_g_tasumi()` `CANDIDATA`. **Excepción** a `flags.md` §7, punto 3 (I-m exige método `VERIFICADA`) | El flag solo informa qué rama de un método ya expuesto se aplicó (no corrige ni impone umbral propio: el umbral LAI < 0.5 es parte del método); ocultarlo haría menos auditable un método `CANDIDATA`. Se revisa al verificar Tasumi (2003) / Allen et al. (2007): si el método cambia, el código se retira o se redefine según `flags.md` §7.6 | `soil-heat-flux.md` §13; `flags.md` §4.2 |
| M2-04 | **Despachadores**: `ef_tau_sw()`, `ef_rs_in()`, `ef_g()`, `ef_zom()` y `ef_et_daily()` validan `method` (sin defecto, `check_method()`), llaman a la función del método, construyen los flags de celda de su etapa con `ef_diagnose_<etapa>()` más `EF_INPUT_NA` (`ef_input_na_flags()`) y devuelven `new_ef_object(list(<valores>, method, flags, provenance), "earthflux_<magnitud>")`: `earthflux_sw_transmissivity`, `earthflux_incoming_shortwave`, `earthflux_soil_heat_flux`, `earthflux_roughness_length`, `earthflux_daily_et`. Las funciones de método siguen devolviendo `numeric` (o una lista simple si producen varias magnitudes). `ef_tau_sw()` es de tipo estable (`total` siempre; `beam`/`diffuse` con nombre, `NULL` con `"elevation"`). `method` es el **último** argumento en todos (se corrigió `ef_zom()`). El test "despachador ≡ llamada directa" compara el elemento de valor. `ef_lambda()` es una función única con `method` (N6b) y sigue devolviendo `numeric` | Convención `ARCHITECTURE.md` §3.2 (punto 4), que solo `ef_g()` cumplía; antes `ef_tau_sw()` no era de tipo estable (lista con `allen`, numérico con `elevation`) y `ef_et_daily()`, `ef_rs_in()` y `ef_zom()` reenviaban el valor del método. **Cambio visible para el usuario**: el valor numérico se lee ahora en `$total`, `$g`, `$zom` o `$eta_24` | `ARCHITECTURE.md` §3.2; `NAMING.md` §2.1; especificaciones de cada módulo |
| M2-05 | **Diagnósticos**: toda `ef_diagnose_<etapa>()` devuelve una lista (posiblemente vacía) con registros solo para los códigos marcados en alguna posición (`n_flagged > 0`); los códigos evaluados viajan en el atributo `evaluated` y el despachador o procedimiento los registra en `provenance$flags_evaluated`. Se alinearon radiación y calor sensible (que devolvían todo código evaluado, con `n_flagged = 0`) y los flags de objeto de `ef_calibrate_h()` | Una sola convención para todas las etapas; los flags de un objeto se leen como "lo que ocurrió"; "evaluado y ausente" sigue distinguible de "no evaluado" (`flags.md` §6.7) | `R/diagnostics.R` (cabecera); `ARCHITECTURE.md` §3.2 |
| M2-06 | **Auxiliares en un solo lugar**: `check_core_args()`, `check_whole()`, `check_doy()`, `check_angle()`, `check_condition()`, `check_scalar()` (con cotas y `whole` opcionales; reemplaza a `anchor_check_scalar()`), `common_dim()` y `ef_reshape()` en `R/utils.R`; `ef_input_na_flags()` en `R/diagnostics.R`; `EF_SECONDS_PER_HOUR` y `EF_MM_PER_M` en `R/constants.R`. `stats` (paquete base) en `Imports`: las anclas usan `stats::quantile(type = )`, `stats::median()` y `stats::sd()` en lugar de reimplementaciones (resultados idénticos). Una sola conversión LE ↔ ET: las anclas usan la inversa interna `ef_et_inst_to_latent_heat()` | Eliminar duplicación y notas `TODO(shared)` tras fusionar los cinco módulos desarrollados en paralelo | `R/utils.R`, `R/diagnostics.R`, `R/constants.R`, `R/metric-anchors.R` |
| M2-07 | **Hallazgo SH-11** (no es una decisión): con el ancla fría estable de la especificación (H_target < 0), `stable_psi_m_height` = 200 m hace **divergir** la Fase A (rah del ancla fría sin cota → `earthflux_calibration_error`), mientras que 2 m converge. P0-2 sigue `ABIERTA` y ahora se sabe **decisiva** para cualquier escena con ancla fría estable (advección). *Resuelto el 2026-11-05 por M2-09 (2 m, fuente primaria).* | Observado en la escena de `sensible-heat.md` §14 (H_target = −50 y −5 W m⁻²) y en la variante estable del test de extremo a extremo (`tests/testthat/test-metric-chain.R`). Es un comportamiento de las formas `CANDIDATA`, no una validación | `sensible-heat.md` §21; P0-2 |
| M2-08 | **Política de verificación con el manual SEBAL de Idaho** (`DECIDIDA`, 2026-11-05). Nuevo estado **`VERIFICADA (SEBAL-Idaho 2002)`**: formulación confirmada palabra por palabra (forma, coeficientes, alturas) contra Waters et al. (2002), con página y número de ecuación; análogamente **`VERIFICADA (IAHS 2012)`** contra Allen et al. (2012, IAHS Publ. 352, pp. 73–75). Se registra fuente, página y ecuación en las tablas de las especificaciones y en `VERIFICATION.md`. El contraste con Allen, Tasumi & Trezza (2007) sigue siendo **deseable pero deja de ser bloqueante**. Si la forma de EarthFlux **difiere** del manual: se documenta la discrepancia; si la forma del manual es inequívoca, el código se alinea (pasa a `VERIFICADA` y se anota en `NEWS.md`); si es ambigua, sigue `CANDIDATA`. Lo propio de METRIC que el manual no cubre sigue `CANDIDATA`. Una formulación `VERIFICADA` deja de estar sujeta a la regla de §1.0: puede tener defecto **solo** donde la especificación o este registro decían que la falta de defecto se debía a la verificación pendiente; la regla de diseño T-15 (despachadores con `method` sin defecto) y los coeficientes sin defecto por diseño (P0-8: k del ancla fría, condición caliente, criterios de anclas; SH-13: Γ) no cambian | El manual es el documento de los autores de METRIC (Waters, Allen, Bastiaanssen, Tasumi, Trezza) con el mismo esquema aerodinámico y de estabilidad, anclas y dT = a + b·Ts; se leyeron como imagen todas las ecuaciones usadas. Sin DOI ni URL (PDF abierto) | `VERIFICATION.md`; `SCIENTIFIC_SPEC.md` (convención de estados); roxygen |
| M2-09 | **SH-11 / P0-2 resueltas** (`DECIDIDA`, 2026-11-05): ψ_m(200 m) estable = −5·(2/L) (Waters et al., 2002, p. 33, Ec. 38; también ψ_h(2 m) = −5·(2/L), Ec. 39a, y ψ_h(0,1 m) = −5·(0,1/L), Ec. 39b). `ef_h_control()` tiene defecto `stable_psi_m_height = 2` y conserva el argumento para elegir otra altura (p. ej., 200 m) explícitamente. Además, por la misma regla, `blending_height = 200` (p. 26), `z1 = 0.1` y `z2 = 2` (p. 30, Ec. 41) son defectos de `ef_h_control()`, `ef_blending_wind()`, `ef_ustar()` y `ef_rah()`, y `cp = 1004` J kg⁻¹ K⁻¹ (p. 25; SH-09) de `ef_sensible_heat()` | Coincide con `water` y con el hallazgo M2-07 (2 m converge con un ancla fría estable). La falta de defecto se debía solo a la verificación pendiente (§1.0) | `sensible-heat.md` §10.3, §18, §21; `NEWS.md` |
| M2-10 | **L con Ts y g = 9,81** (`DECIDIDA`, 2026-11-05; revisa SH-10): la longitud de Monin-Obukhov se calcula con la **temperatura de superficie** Ts (no con T_a = Ts − dT) y g = 9,81 m s⁻² (`EF_GRAVITY`), como en la Ec. 34 del manual (p. 32; el modelo F14 recibe Ts, ap. 8, p. 82); la densidad sigue siendo la de la iteración | Discrepancia con forma inequívoca en el manual: se alinea el código (M2-08). Cambia los valores de la escena sintética (`sensible-heat.md` §14.4–§14.5), recalculados con un script independiente | `sensible-heat.md` §10.1, §14; `R/constants.R`; `NEWS.md` |
| M2-11 | **Convergencia de la calibración de H, una tolerancia por fase** (`DECIDIDA (provisional)`, 2026-11-10; revisa P0-10 y SH-16). `ef_h_control()` separa la convergencia de la Fase A (`tol`, `maxit`: anclas) de la de la Fase B (argumentos nuevos `pixel_tol`, `pixel_maxit`: cada píxel), con defectos `tol` = 10⁻⁶, `maxit` = 100, `pixel_tol` = 10⁻⁵ y `pixel_maxit` = 100 (antes 0,01 y 20 para ambas fases; ω = 0 sigue común). Ambos criterios siguen siendo el **cambio relativo de rah** (por ancla y por píxel): adimensional, definido también con H ≈ 0 y, en la Fase B (ρ y dT fijos), igual al cambio relativo de H; no se adopta un criterio absoluto en W m⁻². Un píxel sin convergencia conserva su último iterado con `EF_H_PIXEL_NOT_CONVERGED` (sin código nuevo) y la llamada emite además un único `earthflux_convergence_warning` (campo `phase = "pixels"`; el de la Fase A lleva `phase = "anchors"`). Presets versión 3, con los cuatro valores escritos en el preset. El comportamiento anterior es `ef_h_control(tol = 0.01, maxit = 20, pixel_tol = 0.01, pixel_maxit = 20)` | Medición en la escena de Talca (Landsat 7, 2013-02-15, inestabilidad fuerte, viento bajo) y en la cadena de `earthflux()` de los tests con `cauquenes_modis` (`verification/water-comparison.md` §5.3): con tol = 0,01 la **Fase A** se detiene antes de su punto fijo y, con la estrategia P2, las anclas pasadas por la Fase B ya no reproducen su H objetivo; todos los píxeles heredan la desviación (Talca: H̄ −0,59 W m⁻² frente al punto fijo de ambas fases, máx. 1,29; Cauquenes: +0,42 a +0,43, máx. 1,25). Apretar solo la Fase B no la reduce (Talca: −0,61), contra lo supuesto en la primera versión del informe. Con los defectos nuevos máx.\|ΔH\| ≤ 4,7·10⁻⁴ W m⁻² frente a tol = `pixel_tol` = 10⁻¹⁰, con 15 a 26 iteraciones en las anclas y 1,5 a 2 veces el tiempo de `ef_calibrate_h()` (Talca: 0,30 → 0,44 s en 198 926 celdas). La diferencia de H con `water` pasa de −0,33 W m⁻² de media (máx. 2,04) a +0,27 (máx. 0,75), la de las fórmulas de ρ. El manual itera hasta que dT y rah del píxel caliente "se estabilizan", sin tolerancia numérica (Waters et al., 2002, p. 34): los valores son de diseño | `R/metric-sensible-heat.R` (`ef_h_control()`, `ef_calibrate_h()`); `R/api-presets.R`; `sensible-heat.md` §11.3–§11.7, §12, §13, §21; `presets.md` §3; `NEWS.md` |

### 1.3 Decisiones de implementación de M3 (2026-11-04)

Tomadas al implementar los módulos de M3 (tabla de estaciones y QC,
variables derivadas y ET de referencia, serie de referencia por estación,
núcleo GWR y orquestación de la regionalización) y al armonizarlos tras
fusionarlos en `main`. Estado de todas: **`DECIDIDA (provisional)`,
2026-11-04**, revisables por el autor antes de `0.1.0`; ninguna cierra una
decisión científica abierta: cuando la elección depende de una pregunta
abierta (WF-09, WF-11, WF-15 para FAO-56, WF-16, GW-04, GW-05, GW-07,
decisión 5.1), se expone como **argumento explícito sin defecto** (regla M2 de §1.0). Los
documentos dueños registran el detalle en sus secciones de estado:
`specs/weather-forcing.md` §2.7, §3.3, §13 y §13.4; `specs/gwr-forcing.md`
(bloques de estado del núcleo y de la orquestación);
`specs/parallel-processing.md` (nota de estado); `specs/flags.md` §4.4 y
§6.2.

**ET de referencia y variables derivadas** (`R/forcing-derived.R`,
`R/reference-et.R`; `weather-forcing.md` §13.2)

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M3-01 | **Sustituida por M3-01a.** Constantes estandarizadas de ASCE-EWRI (2005) (referencia alta/alfalfa, Cn/Cd diarios y horarios, Cd día/noche, G/Rn 0,04/0,2 y 0,1/0,5) implementadas inicialmente como `CANDIDATA` antes de leer la norma, rotuladas en roxygen, en `provenance$constants` y en la tabla interna (`ef_reference_constants()`) con su fuente secundaria (`SPEI` 1.8.1; `water` 1.0), sin defectos ocultos | Indicación del autor de avanzar M3 con la regla M2 de §1.0; METRIC requiere ETr de la referencia alta | `weather-forcing.md` §13.2, punto 1 |
| M3-01a | **Verificación ASCE-EWRI (2005)** (informe final de enero de 2005, pp. i–vii y 1–59; cambio separado): las seis filas de la Tabla 1 (p. 5) y G (Ecs. 30, 65a/b, 66a/b, p. 44) pasan a `VERIFICADA`. Sustituye a M3-01 | Lectura de la fuente primaria; el Apéndice C (ejemplos de Greeley) no estaba en el PDF leído, por lo que no hay caso numérico ASCE publicado reproducido | `weather-forcing.md` §13.5 |
| M3-01b | Lo que difiere entre normas se elige con un argumento explícito **`standard`**: σ (4,901 × 10⁻⁹ diario, 2,042 × 10⁻¹⁰ horario), límites de Rs/Rso (0,3–1; Ecs. 18 y 45) y límites de integración de Ra horaria en la salida y puesta del sol (Ec. 56). `ef_ref_net_radiation()` y `ef_ra_period()` exigen ahora `standard` | Una sola función por magnitud, sin defecto oculto (T-15); WF-10 queda resuelta a través de `standard` | `weather-forcing.md` §13.5 |
| M3-01c | Δ conserva la forma de FAO-56 para ambas normas (el coeficiente 2503 de ASCE difiere en 2,3 × 10⁻⁵ relativo) | Diferencia despreciable; una sola `ef_es_slope()` | `weather-forcing.md` §13.5 |
| M3-01d | Opciones nuevas de ASCE: `night_cloudiness = "low_sun"` (Ecs. 46/62, β ≤ 0,3 rad); métodos `"rhmin"` (Ec. 13) y `"rhmean_tmean"` (Ec. 14) de `ef_ea_daily()`; `daytime_rule = "rn_positive"` pasa a `VERIFICADA` para ASCE (WF-15 resuelta solo para ASCE); con `"asce"` y `"fixed"`, `night_ratio` debe estar en [0,3; 1] (p. 36) | Contenido leído de la norma; las opciones siguen siendo argumentos sin defecto | `weather-forcing.md` §13.5 |
| M3-01e | `EF_WS_RS_RSO_LIMITED` marca ambos límites del cociente Rs/Rso (inferior y superior) | Los límites de M3-01b dependen de la norma; el flag informa cuál se aplicó | `weather-forcing.md` §13.5; `flags.md` §4.2 |
| M3-02 | `ef_ref_et()` devuelve un objeto con clase `earthflux_reference_et` (`et_ref`, `reference`, `timestep`, `standard`, `flags`, `provenance` con las filas de constantes usadas), no un `numeric` con atributos como proponía §5.4; `ef_ref_net_radiation()` devuelve `earthflux_reference_net_radiation` (`rn`, `rns`, `rnl`, `cloudiness`) | Convención de objetos de `ARCHITECTURE.md` §3.2 (M2-04): flags y procedencia viajan con el resultado | `weather-forcing.md` §13.2, punto 2; `R/classes.R` |
| M3-03 | WF-13: `ef_ref_net_radiation()` y `ef_ref_soil_heat_flux()` se **exportan** (la especificación las preveía internas); `ef_etr_hourly()`/`ef_etr_daily()` no se crearon (no aportan sobre `ef_ref_et()`) | Sin ellas `ef_ref_et()` no era utilizable antes de existir `ef_station_ref_et()`; el tamaño de la API se revisa con T-16 antes de `0.1.0` | `weather-forcing.md` §13.2, punto 3; `NAMING.md` §3 |
| M3-04 | Argumentos sin defecto y contratos de la ET de referencia: `ef_ea_tmin(tmin, k0)` sin defecto para `k0` (FAO-56 Anexo 6: 0 o 2 °C según el clima; T-15); `ef_ref_soil_heat_flux()` recibe `standard`; `daytime` obligatorio en paso horario (G de ambas normas y Cd de ASCE) y `NULL` en paso diario; `cloudiness` = término f = 1,35·Rs/Rso − 0,35; FAO-56 con `reference = "alfalfa"` → error nuevo `earthflux_undefined_reference` (subclase de `earthflux_input_error`) | Elecciones científicas explícitas (T-15); FAO-56 solo define la referencia de pasto | `weather-forcing.md` §13.2, puntos 4–8; `ARCHITECTURE.md` §3.3 |
| M3-05 | Convenciones numéricas de las variables derivadas: argumento de arccos de la Ec. 25 limitado a [−1, 1] (ωs = π / 0 en día / noche polar); `ef_ra_period()` con `period_hours` ∈ (0, 1], criterio de punto medio y 1/15 h por grado exacto (WF-10; ahora elegido con `standard`, M3-01b); Gsc desde `EF_SOLAR_CONSTANT`; dominios de temperatura de cada ecuación; literales de la norma dentro de las funciones (WF-14); γ, e° y Δ en `R/forcing-derived.R` y no en `R/shared-physics.R` (WF-01) | Límites geométricos exactos en lugar del X = 0,00001 de FAO-56 Ec. 26–27; una sola fuente de Gsc (P0-5) | `weather-forcing.md` §13.2, puntos 9–12 y 14 |
| M3-06 | Flags de la ET de referencia en `ef_flags_reference_et()` (prefijo `EF_WS_`, ámbito `record`, sin bit): `EF_WS_RS_RSO_LIMITED` (I-m, info; el método —límite de la Ec. 39— es `VERIFICADA`) y `EF_WS_ETR_NEGATIVE` (I, info; nombre normalizado de `EF_ETREF_NEGATIVE`, cubre ETo y ETr) | `specs/flags.md` §7 (I-m con método verificado); la ET negativa se conserva (principio 6) | `weather-forcing.md` §13.2, punto 13; `flags.md` §4.2 |

**Tabla de estaciones y QC** (`R/io-weather.R`, `R/prep-qc.R`;
`weather-forcing.md` §2.7, §3.3)

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M3-07 | **WF-03** adoptada: dos `data.frame` base (`stations`, `observations`) + clase S3 `earthflux_station_table` (con `qc`, `flags` y `provenance`); entradas que heredan de `data.frame` se convierten a `data.frame` base; `ef_validate_stations()` queda **interna** (`NAMING.md` la listaba como pública) | Recomendación de WF-03; el validador lo llaman el constructor y el QC, el usuario no lo necesita | `weather-forcing.md` §2.7 |
| M3-08 | **WF-04** adoptada según `flags.md` (clase III): imposibles en `stations` → `earthflux_domain_error`; imposibles en `observations` → se conservan y `ef_station_qc()` los marca `critical`; infinitos en `observations` → error. Contrato: `provenance$crs` = `"EPSG:4326"` exacto; `timestamp` `POSIXct` con zona explícita (texto solo con `timestamp_format` y `tz` sin defecto); `timestamp_convention` e `interval` obligatorios; conversiones de unidades solo declaradas y registradas; columnas fuera del contrato → error; errores con clase `earthflux_station_*` | Recomendación de WF-04 (P0-11, T-13): un registro no detiene la serie; nada llega al núcleo en silencio | `weather-forcing.md` §2.7; `ARCHITECTURE.md` §3.3 |
| M3-09 | QC: `ef_station_qc(x, qc_policy = "exclude_critical")` (defecto de `flags.md` §5.3; coincidencia exacta) devuelve estado por valor (`ok`/`warning`/`excluded`) sin modificar `observations`, más la tabla de auditoría `$qc` equivalente a los registros `earthflux_flag` (R16). Se evalúan QC-01a, 02, 03, 04 (Tdew > T y eₐ > e°(T)), 05b (`EF_WS_RS_GT_RA`: Rs media > Ra de la **misma ventana**, integral de la Ec. 28 sobre la parte con sol), 09 y 11; los de clase II no se evalúan ni exponen umbrales (listados en `provenance$qc$not_evaluated`); QC-10 (`EF_WS_INCOMPLETE_DAY`) lo levanta `ef_station_ref_et()` sobre las sumas diarias | QC-05b con el criterio de punto medio marcaría registros válidos en las horas de salida y puesta del sol; QC-10 depende de la definición del día (WF-11) | `weather-forcing.md` §3.3, §13.4 punto 11 |
| M3-10 | **QC-01a extendido**: Rs < 0 y precipitación < 0 son imposibles (`EF_WS_OUT_OF_DOMAIN`, `critical`) | Sin ello una Rs nocturna negativa (desplazamiento del piranómetro) detiene `ef_station_ref_et()` con `earthflux_domain_error`; con la política por defecto se excluye y el período queda `NA` (ver abierta A-1) | `weather-forcing.md` §3.3, §13.4 punto 11 |

**Serie de referencia por estación: `ef_station_ref_et()`**
(`R/prep-weather.R`; las 12 decisiones de `weather-forcing.md` §13.4)

| ID | Decisión | Fundamento | Dónde (§13.4) |
|---|---|---|---|
| M3-11 | Firma: `reference`, `timestep`, `standard`, `humidity`, `day_definition` (WF-11) y `day_completeness` (WF-11) **sin defecto**; `daytime_rule` (WF-15), `night_cloudiness` (+ `night_ratio`) e `inst_method` (WF-09, con `overpass`) con `NULL` como marcador, obligatorios cuando aplican (`earthflux_missing_input`) y prohibidos en paso diario; `utc_offset` solo con `"local_standard"`; todas las elecciones en `provenance$choices` | WF-09, WF-11, WF-15 y WF-16 siguen `ABIERTA`: la orquestación no elige por el autor | 1 |
| M3-12 | Entrada `earthflux_station_qc` (se usa su política) o `earthflux_station_table` (se aplica `ef_station_qc()` con `"exclude_critical"`, registrado); los valores `"excluded"` entran como `NA` y se cuentan; con `"keep_all"`, un imposible llega al núcleo y da `earthflux_domain_error` | P0-11: la orquestación convierte en `NA` + flag lo marcado aguas arriba | 2 |
| M3-13 | Paso horario: Ra por período con `ef_ra_period()` (punto medio; WF-10), Rso Ec. 37 (WF-12), P(z) Ec. 7 sin usar la P medida (WF-05), u₂ Ec. 47; paso diario: Ec. 9, 12, 21, G = 0, `etr_24` = valor del registro (opción D2 con datos diarios), sin `overpass`; Rso = 0 → `NA`. Verificación: Ejemplos 18 y 19 de FAO-56 reproducidos a través de la orquestación; A3 (alfalfa horaria) solo como aritmética | Recomendaciones de WF-05, WF-12; usa solo funciones existentes | 3, 4, 12 |
| M3-14 | Nubosidad nocturna (Rso = 0): `"before_sunset"` = cociente del **último** registro de las 24 h previas con ω del punto medio en [ωs − 0,79; ωs − 0,52] (FAO-56 cap. 4; elegir el último es una elección de implementación), sin registro → `NA` + `EF_INPUT_NA`; `"fixed"` = `night_ratio` ∈ [0, 1]. La regla β de ASCE-EWRI se agregó después como `"low_sun"` (M3-01d) | FAO-56 cap. 4; la regla ASCE espera la lectura de la norma | 5 |
| M3-15 | WF-15 como argumento: `daytime_rule` ∈ {`"ra_positive"` (Ra del período > 0, punto medio, FAO-56), `"rn_positive"` (Rn > 0, ASCE-EWRI; `VERIFICADA` para ASCE desde M3-01d)}; selecciona G/Rn y, con `"asce"`, Cd | WF-15 resuelta solo para ASCE (M3-01d); sigue abierta para FAO-56 | 6 |
| M3-16 | WF-09 como argumento: `inst_method` ∈ {`"O1"` (período que contiene la hora de paso, [inicio, fin)), `"O3"` (interpolación lineal de la tasa entre puntos medios, con nodo `NA` tras un hueco)}; fuera del soporte → `NA` + `EF_WS_OVERPASS_OUTSIDE_RECORDS`. O2, O4 y O5 no se implementaron | WF-09 recomienda O3 por defecto y O2/O4 para sensibilidad; aquí no hay defecto | 7 |
| M3-17 | WF-16 y WF-11: paso horario → D1 (suma de las 24 láminas del día); un período pertenece al día de su punto medio en `"utc"` o `"local_standard"` (`utc_offset` en horas, sin horario de verano); `day_completeness = "all_periods"` (única opción): día incompleto → `NA` + `EF_WS_INCOMPLETE_DAY`, sin relleno | Recomendación D1 de WF-16 (coherencia con ETr_inst); WF-11 recomienda "sin relleno" (ver abierta A-1) | 8 |
| M3-18 | Objeto `earthflux_station_ref_et` (`series`, `etr_inst`, `etr_24`, `reference`, `timestep`, `standard`, `flags`, `provenance`); sus flags (ámbito `record`) llevan el campo **`target`** (`"series"`, `"etr_inst"`, `"etr_24"`) propuesto en `flags.md` §6.2, que se **adopta** para todo objeto con varias tablas a las que puede referirse `index`; `provenance$flags_evaluated_by_target` | Sin `target`, `index` sería ambiguo entre las tres tablas | 9; `ARCHITECTURE.md` §3.5; `flags.md` §6.2 |
| M3-19 | `EF_WS_INCOMPLETE_DAY` (I, warning; QC-10) y `EF_WS_OVERPASS_OUTSIDE_RECORDS` (I, info) se registran en `ef_flags_reference_et()`, no en el QC | Dependen de la definición del día y de las horas de paso, que solo conoce la orquestación | 10 |

**Núcleo GWR** (`R/gwr-*.R`; bloque de estado del núcleo en
`gwr-forcing.md`, puntos 1–7)

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M3-20 | `kernel` (GW-04) y `criterion` (GW-05) sin defecto; `search` obligatorio en `ef_gwr_bandwidth()`; en `ef_gwr_search()` los parámetros numéricos valen `NULL` y se exigen solo cuando la búsqueda los usa (`n_grid`, `tol`, `lower_offset`, `upper_factor`); `method_adaptive` solo `"exhaustive"` (sección áurea entera sin implementar) | GW-04 y GW-05 abiertas; T-15 | Punto 1 |
| M3-21 | Convenciones adoptadas: AICc de §4.1 (GW-02) con n estaciones, σ = √(RSS/n) y tr S (forma leída en Gollini et al., 2015; reproduce el AICc de `GWmodel`), **`NA` cuando n − 2 − tr S ≤ 0** (`GWmodel` reporta un valor); k incluye la propia estación y boxcar con soporte d ≤ b (GW-03); R² local de §3.8 (GW-13); distancia euclidiana proyectada (GW-09) | Recomendaciones de GW-02, GW-03, GW-09 y GW-13; verificación cruzada con `GWmodel` 2.4-1 a 10⁻¹⁰ | Puntos 7–8; `NEWS.md` |
| M3-22 | Errores: **no** se creó `earthflux_dimension_error` (§9.3); las dimensiones son `earthflux_input_error` como en el resto del núcleo; k no entero → `earthflux_domain_error`; subclases nuevas `earthflux_gwr_error` (padre), `earthflux_gwr_insufficient_stations` (`n`, `p`), `earthflux_gwr_no_feasible_bandwidth` (`profile`), `earthflux_gwr_singular_error` (`stations`) | Una sola clase de error de argumentos en todo el paquete (`check_same_dim()`) | Punto 2; `ARCHITECTURE.md` §3.3 |
| M3-23 | Argumentos añadidos a §9.1: `station_id` (`ef_gwr_fit()`, `ef_gwr_bandwidth()`), `scale_covariates`, `chunk_rows` (`ef_gwr_predict()`, solo memoria); `bandwidth` de `ef_gwr_fit()` acepta el objeto `earthflux_gwr_bandwidth`; `ef_gwr_predict()` devuelve también `bandwidth`. Se omitió `kappa_max` (su flag `EF_GWR_ILL_CONDITIONED` es de clase II): κ se reporta por estación | Auditabilidad; ningún umbral sin referencia | Punto 3 |
| M3-24 | Convenciones numéricas (no constantes científicas, registradas en `conventions`): pivote de Cholesky ≤ 10⁻¹⁰ × diagonal → rango deficiente; LOO indefinido si 1 − s_ii ≤ 10⁻¹⁰; tolerancia de envolvente 10⁻⁹ × extensión; κ con columnas de norma 1. Sumas ponderadas con `colSums()` y no BLAS, y k-ésima distancia con `order(method = "radix")`, para que una fila no dependa del bloque (≈ 7× más lento en esa operación) | Test `identical()` por bloques (`ARCHITECTURE.md` §6.3) | Puntos 4–5 |
| M3-25 | Evaluación de flags: `EF_GWR_EXTRAPOLATION_LOCAL` solo con kernels compactos (también en celdas singulares); `EF_GWR_AICC_UNDEFINED` en la búsqueda solo con criterio AICc y en `ef_gwr_fit()` con bandwidth del usuario; `EF_INPUT_NA` (bit 0) lo levanta `ef_gwr_predict()` | Un flag solo donde su condición está definida | Punto 6 |
| M3-26 | GW-06 (provisional): con kernels continuos (gaussiano, exponencial) la regla de vecinos "dentro de un bandwidth" (§4.5) fija el **límite inferior automático** de la búsqueda. Consecuencia observada: en G7 gaussiano fijo el óptimo queda en ese límite (18 361 m, `EF_GWR_BW_AT_BOUND`) aunque b = 14 541 m tiene AICc menor; en el caso pequeño hace no factible todo b < 28,3 km. Se registra con el flag, sin cambiar la regla (ver abierta A-3) | GW-06 recomienda "mínimo matemático"; la regla de §4.5 se aplicó tal como está escrita | Punto 7(c) |

**Orquestación de la regionalización** (`R/regionalize*.R`; bloque de
estado de la orquestación en `gwr-forcing.md`, puntos 1–15)

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M3-27 | GW-23 (parcial): `ef_regionalize(data, variable, covariates, method, use_qc, surface_covariates, grid = NULL, exclude = NULL, station_covariates = NULL, prediction = ef_predict_control())`. **Una llamada = una variable** (todas sus `target_time`), de modo que `method` es por variable (enmienda A4) y la **decisión 5.1** (A frente a C) queda en quien llama (una llamada por variable; para `etr_*`, un único `reference`). **No se creó `ef_gwr_config()`**: la configuración por variable es `variable` + capas de `covariates`. `data` acepta la tabla de §7.2 o un `earthflux_station_qc` | Decisión 5.1 abierta; evita un objeto de configuración que duplica argumentos | Puntos 1, 5; `NAMING.md` §3 |
| M3-28 | Sin defectos científicos: `method`, `use_qc` y `surface_covariates` obligatorios; constructores de método `ef_method_gwr()` (exige `kernel`, `adaptive` y exactamente uno de `bandwidth` o `criterion` + `search`; agrega `min_neighbours` y `scale_covariates`), `ef_method_station(station_id, lapse_rate = NULL)` (C1), `ef_method_ols()` y `ef_method_idw(power)` (C2; varias potencias = rejilla con selección LOOCV, empates a la menor), clase `earthflux_regionalization_method` | T-15; VP-2.1 (C1/C2/C3 con la misma interfaz) | Punto 2 |
| M3-29 | **GW-07** (abierta) como argumento explícito: `surface_covariates` declara las covariables derivadas del estado de superficie (`character(0)` si ninguna); una capa con nombre de variable de superficie conocida (`lst`, `ndvi`, …) no declarada es `earthflux_input_error`; si hay alguna, `EF_GWR_SURFACE_COVARIATE` y registro en la procedencia. No hay defecto que decida si se permiten | GW-07 recomienda (a) por defecto hasta el experimento C3; el autor decide | Punto 3 |
| M3-30 | **GW-08** (abierta): **sin modo grueso**. `ef_predict_control(mode = "exact")` solo admite `"exact"` (defecto de §6.1, no científico); `EF_GWR_COARSE_MODE` no se registra; sin `coarse_factor`, `check_every` ni `write_coefficients`; se agregaron `chunk_rows`, `flags_filename`, `overwrite` y `wopt` (P-08) | La predicción exacta es la referencia; el modo grueso necesita la decisión del autor | Punto 4 |
| M3-31 | Salida `earthflux_surface`: el ráster de flags de §2.4 se llama **`flag_word`** (no `flags`, nombre que `new_ef_object()` reserva para la lista de `earthflux_flag`), con la tabla `flag_bits` (enmienda A1); los flags de celda viven solo en `flag_word` (conteos en `provenance$flags$counts`), no como registros con índice de celda; `uncertainty = NULL` (GW-19) | Contrato único de objetos (`ARCHITECTURE.md` §3.2); un registro por celda no escala | Punto 6; `ARCHITECTURE.md` §4 |
| M3-32 | Dominios: celdas con alguna covariable `NA` → `NA` + `EF_INPUT_NA` para **todos** los métodos (C1, C2 y C3 cubren las mismas celdas); estaciones excluidas solo por `NA` en las covariables que usa el método, con motivo registrado. Dominio físico (§2.3): `EF_GWR_OUT_OF_DOMAIN` (III, `critical`, bit 6) marca Ta ≤ −273,15 °C, eₐ ≤ 0, `etr_inst` ≤ 0 y < 0 en u₂, `clearness`, Rs y `etr_24`; el valor se conserva y **el consumidor enmascara** antes del núcleo | P0-11, T-13; `flags.md` §6.6 | Puntos 7–9 |
| M3-33 | C1/C2 (GW-21, GW-22): archivo propio (`R/regionalize-baselines.R`), clases internas `earthflux_ols`, `earthflux_idw`, `earthflux_station_forcing`; OLS por QR con n ≥ p + 1 y AICc con tr S = p (reproduce `global_reference` de `ef_gwr_fit()`); IDW con distancias normalizadas y media en ubicaciones coincidentes, n ≥ 2; C1 constante o con gradiente sobre la elevación del MDE (GW-10); OLS/IDW con pocas estaciones reutilizan `earthflux_gwr_insufficient_stations`. `ef_ols_fit()`, `ef_idw_fit()`, `ef_station_forcing()` y `ef_spatial_forcing()` no se crearon como funciones públicas | Recomendaciones de GW-21 y GW-22; una sola puerta de entrada (`ef_regionalize()`) | Punto 10; `NAMING.md` §3 |
| M3-34 | Bloques: bucle propio `readStart()`/`writeStart()` con `block_rows` (no `max_cells`); con más de un worker y `block_rows = NULL`, al menos 4 bloques por worker; la superficie en disco usa el `datatype` de `wopt` (defecto de `terra`, `FLT4S`; **D-PP-05 sigue abierta**) y la palabra de flags `INT4S`; archivos de una llamada fallida eliminados | P-08, P-09 de `parallel-processing.md`; test `identical()` por bloques | Punto 11 |
| M3-35 | Paralelismo (ARCH-6.3b / D-PP-01 para M3): `future.apply::future_lapply(future.seed = TRUE)` solo si `future::nbrOfWorkers() > 1` (si no, `lapply()`) sobre ajustes, bloques y pliegues; `future` y `future.apply` en `Imports`; el paquete nunca llama a `plan()` (P-04); tareas con matrices y modelos, nunca `SpatRaster` (P-06); plan registrado en la procedencia (P-11) | `ARCHITECTURE.md` §6.3; benchmark 2,2× / 1,6× con 2 workers | Punto 12; `parallel-processing.md` |
| M3-36 | CV espacial (GW-20, parcial): `ef_spatial_folds()` con teselas cuadradas de lado dado (origen por defecto = mínimos de x e y; L lo elige el usuario) y `ef_regionalize_cv()` con `reselect_bandwidth = TRUE` por defecto (re-selección dentro de cada pliegue; con `FALSE` se registra `conditional_on_all_stations`); pliegues fallidos reportados, nunca descartados | Recomendación de GW-20 (teselas); evita fuga de información en la selección | Punto 13 |

**Armonización M3**

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M3-37 | `ef_flag_registry()` guarda el registro en un entorno del paquete la primera vez que se usa; `ef_flag_registry_build()` lo reconstruye sin caché (tests del registro). `ef_regionalize()` en la grilla de prueba de 60 × 60 con `block_rows = 1`: 4,37 s → 0,44 s | El registro es estático; se reconstruía en cada `ef_flag()` (≈ 9 ms) | `R/diagnostics.R`; `ARCHITECTURE.md` §3.4, §6.3 |

**Abiertas detectadas en M3 (requieren al autor).** No son decisiones
nuevas: se registran para que el autor las resuelva en el documento dueño.

| ID | Pregunta | Situación actual | Documento dueño |
|---|---|---|---|
| A-1 | Rs nocturna ligeramente negativa o positiva (QC-05d, clase II) y la regla `"all_periods"` | Rs < 0 se excluye (M3-10) y el día entero queda `NA` (`EF_WS_INCOMPLETE_DAY`); hace falta la tolerancia de QC-05d o otra política de huecos (WF-11) | `weather-forcing.md` §13.4 (pregunta a), §3.2, WF-11 |
| A-2 | Dos definiciones de Ra horaria en las horas de salida y puesta del sol (WF-10) | **Resuelta para la ET de referencia** a través de `standard` (M3-01b; `weather-forcing.md` §13.5). Queda por confirmar que QC-05b (integral sobre la parte con sol) y la Ra de la ETr con `"fao56"` (punto medio) puedan diferir en esas horas | `weather-forcing.md` §13.4 (pregunta b), §13.5, WF-10 |
| A-3 | GW-06: regla de vecinos y límite inferior de la búsqueda con kernels continuos | El óptimo gaussiano queda en el límite (`EF_GWR_BW_AT_BOUND`) aunque existe un AICc menor por debajo (M3-26) | `gwr-forcing.md` §4.5, GW-06 |
| A-4 | WF-06: umbrales con intervalo publicado (δ ∈ [3, 5] % para QC-02; HRmax ∈ [80, 90] % para QC-08a) | Sin valor elegido: `EF_WS_RH_RECALIBRATE` y `EF_WS_RHMAX_LOW` siguen sin evaluar (guardia de clase II) | `weather-forcing.md` §3.2, WF-06 |
| A-5 | WF-09, WF-11 (reloj del día de las sumas horarias), WF-15 (para FAO-56), WF-16, GW-04, GW-05, GW-07, GW-08 y decisión 5.1 | Expuestas como argumentos sin defecto (M3-11 … M3-17, M3-20, M3-27 … M3-30); `earthflux()` necesitará defectos documentados | Especificaciones respectivas |
| A-6 | Otros pendientes: caso numérico ASCE publicado (Apéndice C de ASCE-EWRI, 2005, no disponible); elección del último período en `"before_sunset"` (M3-14); D-PP-05 (`datatype` en disco); traspaso de `etr_inst`, `etr_24`, u₂ y `clearness` de `ef_station_ref_et()` a la tabla de regionalización (`station_regionalization_input()`) | Sin implementar o provisional | `weather-forcing.md` §13.3, §13.4; `parallel-processing.md` |

### 1.4 Decisiones de M4 (2026-11-04)

Tomadas al planificar e implementar M4 (preprocesamiento MODIS). M4-00,
M4-27 y M4-28 son decisiones del autor (`DECIDIDA`); las demás son
decisiones de implementación con estado **`DECIDIDA (provisional)`,
2026-11-04**, revisables por el autor antes de `0.1.0`. Ninguna cierra una
decisión científica abierta: cuando la elección depende de una pregunta
abierta (MP-01, MP-04, MP-09), se expone como **argumento explícito sin
defecto** (regla M2 de §1.0); la de MP-06 (M4-28) es una opción explícita
cuyo defecto (`NULL`) conserva el comportamiento documentado (`NA`). El documento dueño registra el detalle en su
bloque de estado de M4 (`specs/modis-products.md`, al inicio; un solo
bloque desde la armonización de M4).

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M4-00 | **Primer release experimental `0.1.0` al cierre de M4**, con la escena de ejemplo de Cauquenes (opción B, decisión del autor, 2026-11-04). El ítem pasa de M2 a M4 en `ROADMAP.md`; el release incluye el núcleo METRIC (M2), el forzamiento y la regionalización (M3), el preprocesamiento MODIS y el conjunto de datos de ejemplo compatible con CRAN (M4) | Decisión del autor; el AOI de ejemplo ya estaba decidido (MP-12: provincia de Cauquenes, Región del Maule) | `ROADMAP.md` (M2, M4); `specs/modis-products.md` §12, MP-12 |

**Tabla de productos, lectura, escalado y QA** (`R/io-modis.R`,
`R/modis-qa.R`, `R/io-aoi.R`; `specs/modis-products.md` §3–§5, §10, §11,
§13.1–§13.2)

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M4-01 | **Una tabla interna de producto** (`modis_product_table()`; `modis_product_spec(product, collection = "061")`, `modis_layer_spec()`), única fuente de constantes MODIS: solo filas `VERIFICADA` de §5, cada una con su cita `[Dn, p., Tabla]`; rango físico `DERIVADA`. Productos: MOD11A1/MYD11A1, MOD21A1D/MYD21A1D, MOD09GA, MOD09GQ, MOD13Q1, MOD13A2, MCD43A3, MCD15A2H, MCD12Q1 y MCD43A2 (solo `Snow_BRDF_Albedo`, D9). Solo colección 061 (**MP-13** adoptada: otra colección → `earthflux_modis_unsupported`). Fuera de la tabla (hechos `TODO` o incompletos): capas nocturnas de MOD11A1 ("equivalentes" sin valores por capa), `Fpar_500m`, `LaiStdDev_500m`, calidades de MCD43A3 distintas de `shortwave` (tipo y rango solo dados para `shortwave`), demás capas de MCD43A2, productos MYD09/MYD13 (D12 leído solo para MOD) | Regla de hechos de producto (§0.1); MP-13 | §13.1; bloque de estado |
| M4-02 | **Convenciones de escala** por fila: `scale_offset` (DN · escala + offset; MOD11 según D10, MOD21 según D2/D11), `offset_scale` ((DN − offset) · escala; MCD43 según D8/D9) y `scale_only` (DN · escala) para las fichas que declaran escala y **ningún offset** (MOD09 —D12 "N/A"—, MOD13, MCD15). **MP-11** adoptada: lectura con `raw = TRUE`, verificación de que los valores son DN enteros dentro del tipo de dato (`earthflux_modis_dn_error`) y escala/offset aplicados solo desde la tabla. La escala declarada por el archivo debe coincidir con la tabla y, en capas sin offset, el offset del archivo debe ser 0 (contraste en tiempo de lectura de §16, punto 15); un offset no nulo de una capa con offset (Emis, ángulo de visión) solo se registra, porque la convención de GDAL para HDF4 es `TODO` (§16, punto 12) | §11.3; MP-11 | §11.3; bloque de estado |
| M4-03 | **QA → flags** según §10.2, por tabla QA (`modis_qa_rules()`): MODLAND 01 → `EF_SURF_QA_OTHER`, 10 → `EF_SURF_CLOUD`, 11 → `EF_SURF_NOT_PRODUCED`; nube adyacente/cirros (MOD21 bits 5–4 = 01 o 10; MOD09 bits 13 y 9–8 ≠ 00; MOD13 bit 8) → `EF_SURF_CLOUD_ADJACENT`; nieve (MOD09 bits 12 y 15; MOD13 bit 14; MCD15 extra bit 2; MCD43A2 = 1) → `EF_SURF_SNOW`; tierra/agua ≠ tierra (literal de §10.2: incluye costas) → `EF_SURF_WATER`; MOD09 bit 14 → `EF_SURF_SALT_PAN`; MCD15 SCF_QC 010/011 → `EF_SURF_LAI_BACKUP`, 100 → `EF_SURF_NOT_PRODUCED` y MODLAND de 1 bit = 1 → `EF_SURF_QA_OTHER`; MCD43 calidad 1, 3, 5, 7 → `EF_SURF_ALBEDO_MAGNITUDE`. MODLAND 10 de MOD13 ("producido, probablemente nuboso") y de MOD21 (discrepancia d4) se tratan como `EF_SURF_CLOUD` (causa obligatoria de `NA`) | Transcripción de §10.2 y de las tablas QA de §5; d4 | §10.2; bloque de estado |
| M4-04 | **Campos QA sin código**: se decodifican y se conservan, pero no levantan flag porque §10.2 no tiene fila para ellos: estado de nubes, sombra, nube interna, fuego y aerosol de MOD09 `state_1km_1`; nubes = 11 de MOD21; estado de nubes, aerosol, cirros, nube interna y sombra de MCD15; *pixel reliability* de MOD13; `QC` de MCD12Q1. Los bits 3–2 de `QC_Day` (MOD11) **no se decodifican** (discrepancia d2) | No inventar correspondencias; ver abiertas A-M4-1 y A-M4-2 | §5, §10.2 |
| M4-05 | **Política QA** (`qa_policy`, §10.3): `"flag"` o `"mask"`, **sin defecto** en las funciones internas (la recomendación `"flag"` de **MP-09 es provisional**; MP-09 sigue `ABIERTA`). Bajo ambas, `NA` solo por las causas obligatorias de §10.2: relleno, DN fuera del rango válido, MODLAND 10/11 y clases LAI 249–254. `"mask"` exige `mask_codes` explícitos (subconjunto de los códigos *warning*: `QA_OTHER`, `CLOUD_ADJACENT`, `SNOW`, `WATER`, `SALT_PAN`, `LAI_BACKUP`, `ALBEDO_MAGNITUDE`), conserva los flags y cuenta las celdas enmascaradas (`policy$n_masked`). El nivel "Anclas" de §10.3 no es una política de valores: queda para la especificación de anclas. **MP-06**: LAI de clase no vegetada → `NA` + `EF_SURF_LAI_NONVEG` + clase conservada; la asignación explícita (p. ej., 0) no se implementó en esta fila: se agregó después como opción `lai_nonveg` (M4-28) | §10.2–§10.3; `flags.md` §6.6; T-15 | §10.3; bloque de estado |
| M4-06 | **Formatos convertidos** (**MP-10** adoptada): `modis_read_converted(path, product, layer, scaled)` exige declarar `scaled` (faltante → `earthflux_missing_input`). Con `scaled = TRUE` el valor se devuelve a DN invirtiendo la conversión de la tabla y debe quedar a ≤ 0,01 DN de un entero dentro del tipo (convención numérica: el almacenamiento en precisión simple queda en ~10⁻³ DN); un archivo con escala declarada y `scaled = TRUE` es ambiguo y se rechaza. Con `scaled = FALSE`, un NoData igual al relleno de la capa vuelve a ser el DN de relleno (y se marca); otro NoData es dato faltante (`EF_INPUT_NA`). La geometría de un convertido no se contrasta con la grilla sinusoidal (pudo reproyectarse) | §11.2; MP-10 | §11.2; bloque de estado |
| M4-07 | **Lectura HDF4** (`modis_read_raw(path, layers, aoi = NULL)`): producto, fecha UTC, tesela y colección desde el nombre (§4); capas resueltas por **coincidencia exacta** del nombre de SDS contra la lista de subdatasets, con las grafías oficiales alternativas (MOD13A2 "1 km"/"1km") y la grilla HDF-EOS cuando se conoce; el NoData del archivo debe ser el relleno de la tabla (si no, `earthflux_modis_metadata_error`). Geometría contrastada en cada lectura: CRS sinusoidal, tamaño de celda = lado de tesela / celdas por tesela y extensión = la de la tesela del nombre (`modis_tile_extent()`, `DERIVADA`), tolerancia 10⁻³ celda; 250 m sin contraste (`TODO`). Driver HDF4 ausente → `earthflux_modis_driver_error` (usar convertidos). AOI (`SpatVector` en cualquier CRS, densificado cada 1000 m si es geográfico, o `SpatExtent` en el CRS del ráster) recortado en la grilla nativa antes de cualquier reproyección, con `snap = "out"`. Mosaico (`modis_mosaic_tiles()`): mismas capas, CRS, celda, alineación y etiquetas de producto/fecha; teselas solapadas rechazadas (la continuidad entre teselas es `TODO`) | §4, §11.1, §11.4; MP-08 (grilla nativa) | §11; bloque de estado |
| M4-08 | **Flags de `surface`**: `ef_flags_surface()` (`R/modis-qa.R`) registra los 12 códigos de clase I que levantan los decodificadores, con los bits de `flags.md` §6.4 (1–12) y las severidades de §4.2; `EF_INPUT_NA` (bit 0) marca DN faltantes. `EF_SURF_OVERPASS_MISSING` (bit 13) y `EF_SURF_ALBEDO_GT1` (bit 14, clase III) quedan para las funciones que producen hora de paso y albedo de banda ancha; los de clase II siguen en la guardia. Un QA en relleno no se evalúa (sin código). `modis_flag_word()` arma la palabra de bits leyendo el registro. `R/modis-qa.R` se suma a los archivos MODIS de la regla arquitectónica (§1) | `flags.md` §4.2, §6.4, §7 | `flags.md` §3.1, §4.2, §4.4 |
| M4-09 | **Interfaz común de los conversores** (`modis_variable()`, base de `modis_lst()`, `modis_view_zenith()`, `modis_band_emissivity()`, `modis_lai()`, `modis_land_cover()`): lista simple con `value` (unidad de la capa), `product`, `layer`, `unit`, `masks` (máscaras lógicas por código, en orden de bit), `na`, `flags` (registros con atributo `evaluated`), `qa` (QA decodificado), `policy` y `source` (filas de la tabla con sus citas). Núcleo numérico sobre vectores (orden de celdas) con adaptadores `SpatRaster` (`modis_values()`, `modis_as_raster()`); las capas QA deben estar en las mismas celdas (remuestrear QA es tarea de quien llama, nunca por interpolación, §9.2) | `ARCHITECTURE.md` §3.2; §14 ("mismo resultado en vector y `SpatRaster`") | §13.2; bloque de estado |
| M4-10 | **Condiciones nuevas** (todas `earthflux_error`): `earthflux_modis_unsupported`, `earthflux_modis_filename_error`, `earthflux_modis_layer_error`, `earthflux_modis_dn_error`, `earthflux_modis_metadata_error`, `earthflux_modis_grid_error` (subclases de `earthflux_input_error`) y `earthflux_modis_driver_error` | `ARCHITECTURE.md` §3.3 | Cabecera de `R/io-modis.R` |

**Preparación independiente de las fichas** (`R/prep-modis.R`;
`specs/modis-products.md` §6, §8, §9; trasladadas desde el bloque de
estado del final de §13.2 en la armonización de M4)

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M4-11 | **Hora de paso** (`modis_overpass_time()`, `CANDIDATA`; RC-03, MP-01, MP-02): entrada en horas ya escaladas (`Day_view_time`; el relleno llega como `NA`); t_utc = (t_ls − λ/15) mod 24 con la longitud del centro de celda (`modis_cell_lonlat()`); la fecha UTC del archivo nunca se desplaza (la fecha solar local puede diferir en ±1 día; casos V2/V3) y `doy` es el día del año de esa fecha. **Sin ecuación del tiempo**: es hora solar media (§6.1); la ecuación del tiempo se aplica una sola vez, en `ef_hour_angle()` (test que encadena con `ef_solar_geometry()` y comprueba t_ls + S_c). Un resultado que por redondeo vale 24 h pasa a 0 h de la misma fecha. Sin hora → `doy`, `utc_hour` y `POSIXct` `NA` y máscara `missing`. Solo MOD11A1/MYD11A1 (§6.4 sigue `TODO`); Terra y Aqua se tratan igual | §6.1–§6.2; RC-03 | §6; `radiation-components.md` §4.4 |
| M4-12 | **Albedo de banda ancha** (`modis_albedo()`, MP-03): A1 `"blue_sky"` con `diffuse_fraction` explícita, sin defecto (circularidad con `ef_tau_sw_allen()`, T-11), A2 `"white_sky"` y A3 `"black_sky"`, todas `CANDIDATA`; A4–A6 → `earthflux_method_not_implemented` (A4 `TODO`; coeficientes de A5 y fórmula de A6 no dados). Albedo > 1 se conserva con la máscara `gt1`. Los insumos no usados por el método deben ser `NULL` | §8.1; T-11 | §8.1 |
| M4-13 | **Emisividad de banda ancha** (`modis_broadband_emissivity()`, MP-04, RC-14): solo E3 `"lai_empirical"` (ε₀ = min(0.95 + 0.01·LAI, 0.98), `CANDIDATA`, desacoplada de la LST); E1 (coeficientes `TODO`), E2 y E4 (`TODO`) → `earthflux_method_not_implemented`; `e31`/`e32` reservados para E1; las clases no vegetadas de LAI llegan como `NA` (MP-06) o con el LAI asignado por el usuario (M4-28) | §8.2; RC-14 | §8.2 |
| M4-14 | **NDVI desde reflectancia** (`modis_ndvi_from_reflectance()`; D4 ec. 1, forma `VERIFICADA`; MP-05): denominador ≤ 0 → `NA` + máscara `undefined`; \|NDVI\| > 1 (posible con reflectancias válidas negativas) se conserva con máscara `outside_unit`; ninguna tiene código (A-M4-4). El orden agregar-luego-NDVI o NDVI-luego-agregar queda a cargo del llamador y se registra en la procedencia | §5.5; MP-05 | §5.5, §9.2 |
| M4-15 | **Desfase temporal** (`modis_match_composite()`, MP-07): `method` sin defecto: `"period"` (T1), `"period_pixel_lag"` (T2, desfase `lst_date − fecha del píxel` [días], positivo si el compuesto es anterior; períodos que cruzan el año se resuelven dentro del período) y `"same_day"` (T4/T5, por fecha nominal); T3 `"interpolate"` → `earthflux_method_not_implemented` (instante de referencia no definido). Los períodos los entrega el llamador (relación fecha del nombre ↔ período de MOD13/MCD15 no especificada, A-M4-5); períodos solapados o fechas duplicadas → error; sin compuesto → índice `NA`; cota `lag_bound_days`. No se calcula máscara de `EF_SURF_COMPOSITE_LAG` (clase II) | §9.1; MP-07 | §9.1 |
| M4-16 | **Remuestreo** (`modis_to_grid()`, MP-08): solo agregación por factor entero entre grillas anidadas (mismo CRS y extensión; si no, error: regla de alineación `TODO`); `"mean"`, `"median"`, `"modal"` (empates al valor menor) y `"any"` (capas 0/1 de condiciones QA: peor caso); `"bilinear"` → `earthflux_method_not_implemented`. `min_valid_fraction` explícito en (0, 1], sin defecto (umbral `TODO`); devuelve `value`, `valid_fraction` e `incomplete` (→ `EF_SURF_AGG_INCOMPLETE`, clase II, no registrable) | §9.2; MP-08 | §9.2 |
| M4-17 | **Rásteres** en la preparación: `modis_overpass_time()`, `modis_albedo()`, `modis_broadband_emissivity()`, `modis_ndvi_from_reflectance()` y el `composite_doy` de T2 aceptan `SpatRaster` de una capa con geometría común; se aplica el mismo código numérico a los valores de celda (tests vector = ráster) | §14; M4-09 | §13.2 |
| M4-18 | **Clase `earthflux_method_not_implemented`** (subclase de `earthflux_unknown_method` y `earthflux_input_error`; campos `method` y `choices` = opciones disponibles) para opciones de la especificación no implementables (`TODO`). Las opciones disponibles y previstas de cada paso viven en una sola lista (`modis_albedo_methods()`, `modis_emissivity_methods()`, `modis_composite_methods()`, `modis_grid_methods()`), compartida con las opciones del estado de superficie; listada en el catálogo de `R/utils.R` y en `ARCHITECTURE.md` §3.3 | `ARCHITECTURE.md` §3.3; T-15 | §8, §9; `R/utils.R` |

**Estado de superficie, flags y datos de ejemplo** (`R/modis-surface.R`,
`R/modis-qa.R`, `R/io-aoi.R`, `data-raw/`; `specs/modis-products.md` §1,
§12, §13.2; `ARCHITECTURE.md` §4)

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M4-19 | **Estado de superficie** (`modis_surface_state(files, aoi, options)`, interna): `files` = lista `lst`, `albedo`, `ndvi`, `lai`, cada una un archivo HDF4 oficial (una tesela; producto, fecha UTC, tesela y colección desde el nombre) o archivos convertidos declarados con `modis_source(path, product, date, scaled, period)` (clase `earthflux_modis_source`); `aoi` explícito (`NULL` = archivo completo); `options` = `modis_surface_options()` (clase `earthflux_modis_surface_options`) **sin defecto** para producto LST, método de albedo y fracción difusa, método de emisividad, fuente de NDVI, método de desfase por producto, método de agregación, fracción válida mínima y `qa_policy`/`mask_codes`, comprobadas antes de leer archivos. Grilla de trabajo: la grilla de 1 km del archivo de LST recortada al AOI (MP-08); los demás productos se leen sobre la extensión de esa grilla. Salida `earthflux_surface_state` (`new_ef_object()`): `lst`, `albedo`, `ndvi`, `lai`, `emissivity` (`SpatRaster`), `overpass_time` (`doy`, `utc_hour`, `time`), `lonlat`, `qa`, `units`, `flags`, `provenance` (`ARCHITECTURE.md` §4). Productos: LST solo MOD11A1/MYD11A1 (MOD21A1D/MYD21A1D → `earthflux_method_not_implemented`: §6.4 `TODO`); NDVI solo MOD13A2 (MOD13Q1: grilla de 250 m `TODO`; MOD09GA/GQ: orden agregación/NDVI y QA de `state_1km` a 500 m no especificados → `earthflux_method_not_implemented`); albedo MCD43A3; LAI MCD15A2H. Mosaicos de varias teselas no se ensamblan aquí | §1, §13.2; T-15; MP-01, MP-05, MP-08 | §13.2; `ARCHITECTURE.md` §4 |
| M4-20 | **Orden de las conversiones**: BSA/WSA (500 m) se agregan a la grilla de trabajo **antes** de combinarlos en albedo de banda ancha (así la fracción difusa puede ser un ráster de la grilla de trabajo); `EF_SURF_ALBEDO_GT1` se evalúa sobre el albedo final, que es el que recibe el núcleo. LAI se agrega y E3 se calcula sobre el LAI agregado (efectos no lineales `TODO`, §9.2). MOD13A2 ya está en la grilla (factor 1). Un solo `resampling_method` (`"mean"` o `"median"`; `"modal"`/`"any"` no valen para variables continuas) o uno por insumo (`c(albedo = , lai = )`) | §8.1, §9.2; MP-03, MP-08 | §9.2 |
| M4-21 | **QA de subceldas en la celda agregada**: cada máscara se agrega con `"any"` (peor caso); las de causas de `NA` (`EF_INPUT_NA`, `FILL`, `CLOUD`, `NOT_PRODUCED`, `DN_OUT_OF_RANGE`, `LAI_NONVEG`) se conservan **solo donde el valor agregado es `NA`** (explican por qué la celda no tiene valor; una subcelda de relleno en una celda con valor no la marca); las de valores conservados (*warning*) conservan el peor caso. `qa_policy = "mask"` actúa en la resolución nativa y `n_masked` se cuenta en subceldas | §9.2, §10.2; `flags.md` §6.5 | §9.2 |
| M4-22 | **Flags del estado de superficie** (`ef_flags_surface()` completa la etapa: 14 códigos): `EF_SURF_OVERPASS_MISSING` (bit 13, clase I, *warning*) en `flags_overpass_time` donde la máscara `missing` de `modis_overpass_time()` es verdadera **y la LST final es válida** (no donde la LST ya es `NA` por su propia causa); `EF_SURF_ALBEDO_GT1` (bit 14, clase III, `critical`, contraparte `earthflux_domain_error`) en `flags_albedo` con la máscara `gt1` de `modis_albedo()`, valor conservado. Una palabra de flags por capa de salida y registros con `target` = capa; `EF_INPUT_NA` en `flags_emissivity` donde el LAI es `NA` y en `flags_albedo` donde una fracción difusa ráster es `NA`. La exclusión antes del núcleo la identifica `surface_exclusion()` leyendo los bits `critical` del registro; la ejecuta y la cuenta la orquestación (M5) | `flags.md` §4.1 (clase III), §6.3–§6.6, §7; C12; P0-11 | `flags.md` §4.2, §4.4; `ARCHITECTURE.md` §4 |
| M4-23 | **Períodos de compuestos y emparejamiento**: `"same_day"` compara la fecha nominal de la fuente con la fecha de la LST; `"period"`/`"period_pixel_lag"` exigen `period` en `modis_source()` (lo entrega quien llama; el script de ejemplo lo toma de `RangeBeginningDate`/`RangeEndingDate` de los metadatos CMR del granulo); `"period_pixel_lag"` solo para NDVI (MCD43A3 y MCD15A2H no tienen día de compuesto por píxel). Compuesto que no contiene la fecha de la LST → `earthflux_input_error` (nunca se usa otro en silencio) | §9.1; MP-07; A-M4-5 | §9.1 |
| M4-24 | **Fuentes convertidas**: capas nombradas con el nombre de SDS de la tabla de producto; `scaled` se aplica a las capas de valor; las capas sin conversión (QA, día del compuesto) se leen siempre como DN; capa requerida ausente → `earthflux_missing_input`; capa no usada por las opciones → error (nada se ignora en silencio); `FparExtra_QC` es opcional en convertidos y se lee siempre de un HDF4 | §11.2; MP-10; M4-06 | §11.2 |
| M4-25 | **Procedencia** (`modis_provenance()`): tabla de granulos (rol, producto, colección, fecha UTC, período, tesela, archivo, tipo de entrada, marca de producción, DOI y su estado), métodos, estado de verificación de cada paso, filas de la tabla de producto usadas (con citas) y versiones de EarthFlux, `terra`, GDAL, PROJ, GEOS y R. DOI (`modis_product_doi()`): `VERIFICADA` donde la ficha lo da (MOD11A1, MYD11A1, MOD21A1D, MYD21A1D, MCD43A3); `DERIVADA` para los demás productos de D12 por el patrón `10.5067/MODIS/<producto>.061` (§3); MCD43A2 sin DOI. La tabla de producto se construye una vez por sesión (caché, como el registro de flags) | §3, §12, §13.2; `flags.md` §6.7 | §13.2 |
| M4-26 | **Datos de ejemplo (preparación, MP-12)**: AOI = límite oficial de la **provincia de Cauquenes** (DPA 2023, SUBDERE, publicado vía IDE Chile; circulación autorizada por Res. DIFROL N° 87/2023), tomado sin cambios de la geometría original del dataset `cauquenes` del paquete `thermify` del autor; se distribuye en `inst/extdata/cauquenes-province.gpkg` (una entidad, atributos `CUT_REG`, `CUT_PROV`, `PROVINCIA`, `REGION`, `SUPERFICIE`, EPSG:5360, sin índice espacial, ≈ 190 KB) con su nota de procedencia `cauquenes-province.yml`, el script `data-raw/cauquenes-province.R` y el lector interno `aoi_cauquenes()`. La escena se construye con `data-raw/modis-example.R` (excluido del tarball): búsqueda CMR (proveedor `LPCLOUD`, tesela h12v12, colección 061), descarga de LP DAAC con un token Earthdata leído **solo** de la variable de entorno `EARTHDATA_TOKEN` (nunca escrito ni impreso; el script falla con un mensaje claro si falta), caché en `data-raw/private/` (ignorado por git), `modis_surface_state()` con opciones explícitas (MOD11A1 Terra, albedo A2 `"white_sky"`, E3, MOD13A2 con T2, MCD43A3 con T5, LAI con T1, `"mean"`, `min_valid_fraction = 1`, `qa_policy = "flag"`), celdas fuera de la provincia `NA` (palabras `NA` = no evaluado, `flags.md` §6.3), GeoTIFF DEFLATE, control de tamaño < 500 KB y procedencia CSV/YAML. Fecha: **2019-02-15** (M4-27); la escena no se incluye todavía (falta ejecutar el script, M4-30) | §12; MP-12; `DEVELOPMENT.md` §6 | §12, §15 |

**Decisiones del autor del 2026-11-04 tras la implementación de M4**
(`R/modis-qa.R`, `R/modis-surface.R`, `data-raw/modis-example.R`;
`specs/modis-products.md` §5.7, §8.2, §12, §15; `specs/flags.md` §4.2,
§6.4)

| ID | Decisión | Fundamento | Dónde |
|---|---|---|---|
| M4-27 | **Fecha de la escena de ejemplo** (decisión del autor, **MP-12** pasa a `DECIDIDA`: AOI, fecha y productos): **2019-02-15**, Terra (MOD11A1), tesela h12v12 con 3 % de nubosidad de tesela; día despejado del verano austral anterior a la deriva orbital de Terra (2020). `scene_date` fijada al inicio de `data-raw/modis-example.R` | Decisión del autor; §7 (deriva), §12 | `specs/modis-products.md` §12, §15 (MP-12); `data-raw/modis-example.R` |
| M4-28 | **LAI explícito en las clases no vegetadas** (decisión del autor; **MP-06** pasa a `DECIDIDA`: `NA` + flag por defecto, asignación solo como opción declarada; valor asignado `CANDIDATA`, práctica de implementaciones METRIC: E3 con LAI 0 da ε₀ = 0,95, la forma observada en `water`, `radiation-components.md` §6.6, RC-14). Opción `lai_nonveg` de `modis_surface_options()` y de `modis_lai()`: `NULL` (defecto) = comportamiento anterior (`NA` + `EF_SURF_LAI_NONVEG`); **un número** = LAI asignado a las seis clases 249–254; **un vector con nombre por código de clase** (`c("253" = 0, "250" = 0)`) = asignación por clase, las clases no nombradas siguen `NA` (implementado porque es simple: una búsqueda por código). Valores en [0, 10] m² m⁻² (rango físico `DERIVADA` de `Lai_500m` en la tabla de producto; fuera → `earthflux_domain_error`); sin `NA`. Se aplica a 500 m, antes de la agregación (una celda mixta promedia LAI asignado y recuperado). En la celda asignada la fuente del valor es el **código de clase**, no una recuperación: las causas de `NA` de la recuperación ausente (`EF_SURF_NOT_PRODUCED` por SCF_QC 100) no se levantan allí (como en M4-21: explican un valor faltante); los *warning* de QA se conservan; los códigos enmascarados por el usuario (`qa_policy = "mask"`) **prevalecen** (la celda queda `NA` con `EF_SURF_LAI_NONVEG` y se cuenta en `n_masked`). El valor por clase queda en la procedencia (`methods$lai_nonveg`; `status[["lai_nonveg"]]`). El script de ejemplo usa `lai_nonveg = 0` | MP-06; A-M4-6; T-15; `flags.md` §7 | `specs/modis-products.md` §5.7, §8.2, §15; `ARCHITECTURE.md` §4 |
| M4-29 | **Código `EF_SURF_LAI_ASSIGNED`** (clase I, `info`, ámbito `cell`, **bit 15** = siguiente bit libre de `SURF`, `flags.md` §6.4): ningún código existente significaba "valor asignado por una opción del usuario" y `EF_SURF_LAI_NONVEG` está documentado como causa de `NA` (un código registrado no cambia de significado, `flags.md` §7.6). `EF_SURF_LAI_NONVEG` **no** se levanta en las celdas asignadas y conserva su significado (LAI `NA`) en las no asignadas. `EF_SURF_LAI_ASSIGNED` va en `flags_lai` (peor caso de las subceldas: basta una asignada) y en `flags_emissivity` (donde ε₀ se calculó con un LAI asignado); no es causa de `NA` ni enmascarable. Solo se evalúa con la opción activa. Registro: 69 códigos (`SURF` 15) | `flags.md` §4.1, §5.3, §6.4, §7 | `flags.md` §4.2, §4.4, §6.4 |
| M4-30 | **Emisividades de banda 31/32 en el estado de superficie** (preparación de E1; MP-04 sigue `ABIERTA`): con LST MOD11A1/MYD11A1, `modis_surface_state()` lee `Emis_31` y `Emis_32` (filas `VERIFICADA` de la tabla de producto, D1 p. 17, Tabla 9; D10) con `modis_band_emissivity()` y las lleva como `band_emissivity` (`SpatRaster` de dos capas `emis_31`, `emis_32`, adimensional) con sus palabras `flags_emis_31`, `flags_emis_32` (`EF_INPUT_NA`, `EF_SURF_FILL`, `EF_SURF_DN_OUT_OF_RANGE`) y sus filas de la tabla en la procedencia. Siempre desde un HDF4; desde archivos convertidos solo si se declaran (como `FparExtra_QC`, M4-24; si no, `band_emissivity = NULL`), porque ningún método implementado las usa: E1 las hará obligatorias. `"split_window_regression"` sigue dando `earthflux_method_not_implemented`; lo que falta para E1/E2 está en `specs/modis-products.md` §8.2. El script de ejemplo escribe además `band_emissivity.tif`; **paso pendiente** de la escena: ejecutar el script con `EARTHDATA_TOKEN` y los dominios de Earthdata permitidos y versionar `inst/extdata/modis-example/` (comando y salidas en `ROADMAP.md` M4 y `specs/modis-products.md` §12) | §5.1, §8.2; MP-04; RC-14 | `specs/modis-products.md` §8.2, §12; `ARCHITECTURE.md` §4 |
| M4-31 | **Confirmación del autor para `0.1.0`** (2026-11-05): se publica con (a) las formulaciones que siguen `CANDIDATA` tras la verificación contra el manual SEBAL-Idaho (`VERIFICATION.md`; regla provisional §1.0, M4-00) y (b) las decisiones `DECIDIDA (provisional)` P0-4 … P0-12 y las de §1.2 – §1.4 **sin revisar**: siguen provisionales y revisables en versiones posteriores. Release publicado el mismo día (tag `v0.1.0`; DOI `10.5281/zenodo.23981326`, concepto `10.5281/zenodo.23981325`) | Aceptación del autor al fusionar el PR del release | `RELEASING.md`, "Estado de 0.1.0" |

**Abiertas detectadas en M4 (requieren al autor).**

| ID | Pregunta | Situación actual | Documento dueño |
|---|---|---|---|
| A-M4-1 | ¿Qué bits de nubosidad sin fila en §10.2 deben marcarse o enmascararse (MOD09 `state_1km_1` bits 1–0, 2 y 10; MOD21 nubes = 11; MCD15 bits 4–3)? Importa para NDVI diario y albedo banda angosta desde MOD09GA (T4, A5) | Decodificados, sin flag (M4-04) | `specs/modis-products.md` §10.2 |
| A-M4-2 | ¿`EF_SURF_WATER` debe incluir "costas y orillas" (MOD09/MOD13 clase 010; MCD15 01)? ¿MODLAND 10 de MOD13 ("producido, probablemente nuboso") debe ser `NA` obligatorio o conservarse con flag? | Literal de §10.2: ≠ tierra → agua; MODLAND 10 → `NA` (M4-03) | `specs/modis-products.md` §10.2 |
| A-M4-3 | Contraste con archivos reales (§16, puntos 1, 12, 13, 15 y 16): nombres de grilla de MOD09/MOD13/MCD15/MCD12, `add_offset` y NoData expuestos por GDAL, anidamiento 500 m/1 km | Los lectores los contrastan en cada lectura y fallan con error clasificado si difieren; falta un granulo real (MP-12) | `specs/modis-products.md` §16 |
| A-M4-4 | ¿Qué código (si alguno) deben levantar NDVI indefinido (denominador ≤ 0) y \|NDVI\| > 1 de `modis_ndvi_from_reflectance()`? | Máscaras `undefined` y `outside_unit` sin código (M4-14) | `specs/flags.md` §4.2 |
| A-M4-5 | Relación entre la fecha del nombre y el período de los compuestos MOD13 y MCD15 (¿primer día del período?) | El período lo entrega quien llama (M4-23); el script de ejemplo usa los metadatos CMR | `specs/modis-products.md` §5.5, §5.7, §9.1 |
| A-M4-6 | Emisividad en clases no vegetadas: E3 da `NA` donde el LAI es `NA` (clases 249–254: suelo desnudo, urbano, agua), y con ello Rn y G `NA` en esas celdas. **Actualizada 2026-11-04:** el autor adoptó la asignación explícita (M4-28, M4-29; la escena de Cauquenes usa `lai_nonveg = 0`, ε₀ = 0,95 en esas clases). **Sigue abierto:** (a) E1/E2 (MP-04): implementar la emisividad de banda ancha desde las emisividades del producto LST requiere la lista de §8.2 (forma funcional, coeficientes con su fuente primaria, intervalo espectral, rango de validez, casos de prueba); las bandas 31/32 ya viajan en el estado (M4-30); (b) si agua (254), nieve/hielo (252) y humedales (251) necesitan un valor o una regla propia en lugar del LAI 0 común (con LAI 0 también entran en la rama de suelo desnudo de G de Tasumi, `soil-heat-flux.md`), lo que la asignación por clase ya permite expresar | Sin la opción: `NA` + `EF_INPUT_NA` en `flags_emissivity` (M4-22); con `lai_nonveg`: valor asignado + `EF_SURF_LAI_ASSIGNED` (M4-28, M4-29); E1 → `earthflux_method_not_implemented` | `specs/modis-products.md` §8.2; MP-04, MP-06 |
| A-M4-7 | Umbral de `min_valid_fraction` (y de `EF_SURF_AGG_INCOMPLETE`, clase II) | Argumento sin defecto; el script de ejemplo usa 1 (solo celdas con todas las subceldas válidas) | `specs/modis-products.md` §9.2 |

### 1.5 Decisiones de diseño de la API de usuario (2026-11-05)

Tomadas por el autor al revisar la carga de entradas de la escena de
validación del Maule (2019-02-15). M5-01 … M5-05 son decisiones del autor
(`DECIDIDA`); M5-06 es `DECIDIDA (provisional)`; M5-07 es decisión del
autor (`DECIDIDA`, 2026-11-05) tras la evaluación registrada en su fila. Documento dueño: `ARCHITECTURE.md` §1 (principio 9)
y §6.7.

M5-08 … M5-17 son decisiones del autor del 2026-11-06 sobre `earthflux()` y
sus presets (fase 2 de M5), tomadas sobre la propuesta de presets; son
**`DECIDIDA (provisional)`** porque descansan en formas o valores
`CANDIDATA` y se revisan con la escena del Maule. M5-18 … M5-22 son
decisiones de implementación de la fase 2, `DECIDIDA (provisional)`,
2026-11-06. M5-23 y M5-24 son cambios aprobados por el autor el
2026-11-06 tras la primera corrida real (Cauquenes) y la evaluación con la
escena del Maule (`verification/anchors-m5-23.md`); son `DECIDIDA
(provisional)` con formas `CANDIDATA` y dan la versión 2 de los presets.
M5-25 es decisión del autor del 2026-11-10 (regla de terreno), `DECIDIDA
(provisional)` con un límite `CANDIDATA`, tras la evaluación de
`verification/terrain-rule.md`; da la versión 4 de los presets (la 3 es la
de M2-11); el 2026-11-11 el autor dio a `idaho2002_flat` un límite propio
(250 m; opción B), dentro de la misma versión, y cambió la referencia de
la regla al rango de elevación de las anclas (opción 1), también dentro de
la versión 4. Documento dueño del detalle: `specs/presets.md`.

| ID | Decisión | Motivo | Documento |
|---|---|---|---|
| M5-01 | **Producto ≠ validación.** Los datos que necesita la validación (muchas estaciones horarias, torres EC, cobertura de suelo local, control de metadatos de estaciones) no son requisitos de `earthflux()` | Exigirlos para obtener un mapa de ETa haría el paquete inutilizable fuera de la investigación | `ARCHITECTURE.md` §1 (9), §6.7 |
| M5-02 | **Tres niveles de uso** sobre el mismo núcleo: básico (`earthflux()` con área, fecha, una fuente meteorológica y un preset), avanzado (tabla de estaciones y GWR, C3) y experto (`ef_*()`, `modis_*()` con todas las opciones) | Separar la facilidad de uso del control fino sin duplicar ecuaciones (principio 4) | `ARCHITECTURE.md` §6.7 |
| M5-03 | **Entradas mínimas del nivel básico:** área, fecha y forzamiento meteorológico; el estado de superficie MODIS y el MDE los descarga y prepara el paquete (token Earthdata solo desde el entorno, como en M4-26) | El usuario no debe reunir productos satelitales a mano | `ARCHITECTURE.md` §6.7 |
| M5-04 | **Presets obligatorios en `earthflux()`:** un argumento `preset` nombra un conjunto documentado de todas las opciones científicas; cada opción efectiva queda en la procedencia; el núcleo mantiene métodos sin defecto (T-15); un preset es `VERIFICADA` solo si todas sus formulaciones lo son | Una elección explícita en lugar de ~15, sin defectos ocultos | `ARCHITECTURE.md` §6.7; T-15; P0-7, P0-8 |
| M5-05 | **Cobertura de suelo opcional**, solo como máscara de exclusión (agua, urbano, nieve); la selección de anclas usa criterios de superficie (NDVI, Ts, albedo; `anchor-pixels.md`) y el agua ya se marca con `EF_SURF_WATER`. Evidencia: MCD12Q1 2019 clasifica solo 1,6 % de la Región del Maule como cultivo (IGBP; 2,1 % en `LC_Prop2`, 1,9 % + 0,2 % en `LC_Type5`), lo que lo hace inadecuado como máscara agrícola de anclas en el valle central | Evitar una entrada costosa sin fuente global adecuada | `ARCHITECTURE.md` §6.7; `anchor-pixels.md` (cobertura `TODO`) |
| M5-06 | **MDE automático:** NASADEM_HGT v001 (1″, LP DAAC, DOI 10.5067/MEASURES/NASADEM/NASADEM_HGT.001, mismo token); cadena candidata del preset: media 3×3 a 3″ (~90 m) → pendiente y orientación a ~90 m → media de las componentes del vector normal por celda de 1 km (da el coseno de incidencia medio exacto, sin sombras) → pendiente y orientación efectivas más la longitud del normal medio; opción explícita de terreno plano | Elevación obligatoria (presión, Ts,datum, T-20); relieve solo donde importa | `ARCHITECTURE.md` §6.7; T-20 |
| M5-07 | **Forzamiento sin estaciones** (fuente grillada) como opción del nivel básico: **`DECIDIDA` (autor, 2026-11-05): ERA5 vía Open-Meteo (`archive-api.open-meteo.com`, modelo `era5`) es la fuente predeterminada sin estaciones**, con atribución CC BY 4.0, opción `apikey` para uso comercial, ajuste por elevación como opción registrada y flag de forzamiento grillado (`ARCHITECTURE.md` §6.7). Evaluación del 2026-11-05 (Región del Maule, 2019-02-15, contraste con 10–39 estaciones DMC/INIA/FDF; **un solo día despejado de verano: evidencia débil**; sesgo / RMSE, grillado − estación): Open-Meteo ERA5 (sin credencial, CC BY 4.0) Tmean +0,49 / 1,37 K, HR −4,3 / 7,7 %, Rs (solo piranómetros DMC + INIA, n = 14) +0,86 / 2,33 MJ m⁻² d⁻¹; ECMWF IFS 9 km Tmean +0,51 / 1,11 K, HR −8,3 / 11,2 %; ERA5-Land vía Open-Meteo **sin Rs, viento ni presión**; NASA POWER (MERRA-2 + CERES) HR −27,8 / 30,3 % (cálido y seco); CR2MET v2.5 (Chile, solo diario, CC BY 4.0) Tmean −0,59 / 1,19 K (no independiente: calibrado con estas redes); MCD18A1 v062 (token Earthdata; v061 retirado) Rs +1,78 / 2,83. Todas las fuentes comprimen la amplitud diaria (Tmax 2–3 K bajo, Tmin 3–4 K alto). MERRA-2 y GLDAS exigen además aprobar una vez la aplicación GES DISC en Earthdata Login; ERA5 en CDS exige cuenta y clave. **No evaluados:** viento y valores a la hora de paso (sin datos horarios de estaciones), días nublados, invierno, montaña. **Pendiente:** evaluar viento y hora de paso con datos horarios de estaciones; CR2MET (complemento diario en Chile) y MCD18A1 v062 (Rs con el token del paquete) quedan como alternativas evaluadas, no adoptadas | Permitir ETa sin datos de estaciones | `ARCHITECTURE.md` §6.7; `weather-forcing.md` |
| M5-08 | **M5-04 prevalece sobre D-AP-01** (que se reescribe): se admiten presets que no están completamente verificados; su estado se declara en su documentación y en la procedencia del resultado (**no en el nombre**), y `earthflux()` emite un aviso con clase, `earthflux_unverified_preset_warning` (campos `preset` y `unverified`), con la lista de los elementos no verificados del preset usado | Un preset `VERIFICADA` no es posible hoy (criterios de anclas `CANDIDATA` por construcción, V#42; albedo MODIS `CANDIDATA`); exigirlo dejaría `earthflux()` sin uso. El aviso y la procedencia mantienen la transparencia de T-15 | `specs/presets.md` §1, §3.3; `anchor-pixels.md` §9 (D-AP-01) |
| M5-09 | **Dos presets**, `idaho2002_elev` e `idaho2002_flat`, ambos `CANDIDATA`, con versión interna (`preset_version = "1"` en la procedencia; `"2"` desde M5-23 y M5-24). Ninguno usa la pendiente (forzada a 0, proyección plana, hasta resolver RC-09); ambos usan la elevación del MDE. `idaho2002_elev`: formas del manual SEBAL-Idaho 2002 con los ajustes por elevación del ap. 12 (Ts_datum con Γ = 0,0065 K m⁻¹, Ec. 12-7; T del píxel frío para RL↓ ajustada por elevación, Ec. 12-8; τ_sw por píxel). `idaho2002_flat`: procedimiento base del manual (Γ = 0; una T del píxel frío para RL↓; una τ_sw para la escena, con la elevación de la estación o la mediana de la elevación del AOI) | Formas `VERIFICADA (SEBAL-Idaho 2002)` en su mayoría; el ajuste por elevación es del propio manual | `specs/presets.md` §3; `R/api-presets.R` |
| M5-10 | ~~**Criterios de anclas** de la propuesta (frío: LAI ≥ 3, albedo 0,18–0,25, NDVI ≥ percentil 0,90; caliente: LAI ≤ 0,4, NDVI > 0, albedo 0,10–0,35; homogeneidad sd(LST) ≤ 1,5 K en 3 × 3; 20 % más frío / más caliente; dominio `"land"`; un paso de relajación con LAI ≥ 2; QA estricto), incluido el ensanche para píxeles de 1 km, `CANDIDATA`, a revisar con la escena del Maule~~ **Reemplazada por M5-23** (2026-11-06) | Guías del manual, ap. 7 (V#42); el ensanche no tiene fuente (T-18). Hallazgo en Cauquenes: `specs/presets.md` §8 | `specs/presets.md` §4 |
| M5-11 | **Temperatura de RL↓** (cierra P0-3 para los presets): opción (b), Ts del ancla fría; las anclas se seleccionan **antes** de Rn | Waters et al. (2002), Ecs. 21, 23 y 12-8 (V#7); Allen et al. (2012, p. 74) | `specs/presets.md` §2; P0-3 |
| M5-12 | **Γ de Ts_datum**: 0,0065 K m⁻¹ (`elev`) / 0 (`flat`); el datum es la elevación de la estación (C1) o del punto de calibración frío (sin estación representativa), que no cambia H | Ec. 12-7 del manual (V#37); "dual-stage" de METRIC queda futuro (SH-13) | `specs/presets.md` §3.1; `sensible-heat.md` §9.1 |
| M5-13 | ~~**z_om donde LAI = 0**: `NA` más un flag nuevo de clase I, **`EF_H_ZOM_UNDEFINED`** (etapa `H`, `info`, ámbito `cell`, bit 10, registrado en `ef_flags_workflow()` con sus tests); sin mínimo inventado. Consecuencia: el ancla caliente se busca entre 0 < LAI ≤ 0,4~~ **Reemplazada por M5-24** (2026-11-06): mínimo de z_om con flag; `EF_H_ZOM_UNDEFINED` retirado | Ningún mínimo de z_om está verificado (SH-02, V#20); `ef_ustar()` rechaza z_om = 0 | `specs/flags.md` §4.2, §6.4; `specs/presets.md` §3.2 |
| M5-14 | **Viento**: rugosidad del sitio meteorológico z_om,w = 0,0144 m (0,12 · 0,12 m) y d = 0; u₂₀₀ por celda desde el viento regionalizado a la hora de paso, interpolado linealmente en el tiempo entre los puntos medios horarios (análogo de O3) | Ecs. 27–29 del manual con d = 0 (V#23); h = 0,12 m `CANDIDATA` (SH-04) | `specs/presets.md` §3.2, §6 |
| M5-15 | **ERA5 sin estaciones**: `elevation_adjust = FALSE` (elevación nativa de la celda; EarthFlux aplica su propio tratamiento de la elevación), `instant_values = "trapezoid"`, regionalización C2 IDW con q = 2 para la ETr, el viento y las demás variables de la cadena; se **excluyen** las estaciones virtuales cuya celda ERA5 informa elevación 0 m (mar abierto), elección explícita del preset registrada en la procedencia (`CANDIDATA`) | M5-07; evita que celdas marinas entren en la interpolación de la costa | `specs/presets.md` §3.2 |
| M5-16 | **Día de ETr₂₄**: día solar medio del centroide del AOI (`utc_offset` = longitud/15 h), registrado (WF-11). La suma diaria de 24 ETr horarias es la ETr₂₄ de la Ec. 44 del manual (V#46): se sincronizaron la documentación de `ef_station_ref_et()` y `weather-forcing.md` §5.6, que decían "uso en METRIC `TODO`" | WF-11 sigue abierta como regla general; el preset fija una | `specs/presets.md` §3.2; `VERIFICATION.md` fila 46 |
| M5-17 | **Opciones MODIS y MDE**: Terra `MOD11A1`, albedo `"white_sky"`, `qa_policy = "flag"` con QA estricto para las anclas, `min_valid_fraction = 1`, **`lai_nonveg = 0`** (como la escena M4-27; `EF_SURF_LAI_ASSIGNED` deja la traza); MDE `water = "mask"` y fracción válida mínima 1 (la propuesta no la fijaba; coherente con MODIS) | Opciones de la escena de ejemplo (M4-26, M4-27) | `specs/presets.md` §3.2 |
| M5-18 | **Hora de paso por celda** (implementación): la hora UTC de paso es continua por celda (3656 valores distintos en Cauquenes); se regionalizan los valores horarios (ETr como tasa en mm h⁻¹ con `variable = "etr_inst"`, `period_seconds = 3600`, y viento) en los puntos medios que rodean el rango de horas de paso y cada celda se interpola linealmente a su hora; con C1 coincide con O3 en la estación. La palabra GWR de la celda es el OR de las de los dos puntos medios | IDW y C1 son lineales en los valores con las mismas estaciones; regionalizar cada hora sería inviable | `specs/presets.md` §6 (hueco 1) |
| M5-19 | **Rs↓ en terreno plano** con τ por elevación: `ef_rs_in(method = "modelled")` con `tau_beam = τ_sw`, `tau_diffuse = 0`, `slope = 0` (Ec. 12 exacta); la `diffuse_fraction` resultante no se reutiliza | `ef_rs_in_modelled()` exige τ particionada | `specs/presets.md` §6 (hueco 4) |
| M5-20 | **Elevaciones de escena**: τ_sw de `flat` con la elevación de la estación (C1) o la **mediana** de la elevación de las celdas del AOI (C2/ERA5, como en la propuesta); datum de Ts como en M5-12 | Propuesta §3.2 | `specs/presets.md` §3.1 |
| M5-21 | **Máscara del AOI**: celdas tocadas por el polígono (`terra::rasterize(touches = TRUE)`, la regla de la escena de ejemplo, M4-26); todo `NA` fuera; las palabras de flags `NA` = no evaluado. Rechazo multitesela antes de cualquier descarga | US-01 crit. 2; M4-19 | `specs/presets.md` §2 |
| M5-22 | **Resultado y QA de anclas**: el QA estricto de anclas exige además que la cadena esté definida en la celda (elevación, z_om > 0, forzamiento, hora de paso); `earthflux_result` según `specs/presets.md` §5 (palabras por etapa sin combinar, `EF_WS_GRIDDED_FORCING` subido a `flags`, registros de celda referidos a las celdas de `terra` con `target`); clase nueva `earthflux_weather_coverage_error` para meteorología que no cubre la escena | Un ancla con una entrada `NA` detiene la calibración (`earthflux_calibration_error`) | `specs/presets.md` §4, §5; `ARCHITECTURE.md` §3.3 |
| M5-23 | **Criterios de anclas recalibrados para MODIS a 1 km** (presets versión 2; reemplaza M5-10). Frío: NDVI ≥ percentil 0,90 del dominio `"land"` y albedo de cielo blanco en [0,14; 0,26] (sin LAI absoluto). Caliente: NDVI ≤ percentil 0,10, NDVI > 0 y albedo en [0,18; 0,35] (sin LAI absoluto). Sin cambio: homogeneidad sd(LST) ≤ 1,5 K en 3 × 3 con ventana completa, 20 % más frío / más caliente de los candidatos, media de los píxeles, tipo de cuantil 7. **Un** paso de relajación (frío NDVI ≥ p0,80, caliente NDVI ≤ p0,20, `EF_ANCHOR_CRITERIA_RELAXED`). QA estricto de M5-10/M5-22 más la exclusión de las celdas con `EF_SURF_LAI_ASSIGNED` (LAI asignado por `lai_nonveg`, no recuperado; opción `anchors$qa_exclude_codes`). Todo `CANDIDATA` | Intención del manual (Waters et al., 2002, pp. 23, 30–31; ap. 7, pp. 66–74): frío = vegetación de cobertura plena bien regada, agrícola, "very cold, but not extremely cold"; caliente = suelo agrícola desnudo y seco, no desierto, roca ni ladera. En Cauquenes y el Maule (2019-02-15) el NDVI más alto corresponde a bosques y plantaciones de albedo 0,10–0,13 (excluidos por 0,14), el LAI ≥ 3 no discrimina, el LAI ≤ 0,4 lo alcanzan 1–3 % de las celdas y en el Maule casi solo laderas andinas (albedo ≤ 0,165), y los campos secos del valle tienen albedo mediano 0,19–0,20 (límite 0,18). Umbrales fijados con la distribución de NDVI y albedo, no ajustando ETrF; sin fuente primaria. Evaluación de coherencia (no validación) en `verification/anchors-m5-23.md`: las anclas caen en el valle en ambas escenas, pero Cauquenes conserva 20,6 % de ETrF > 1,05 y en el Maule las laderas sobre 1000 m quedan con ETrF < 0 (Ts_datum extrapolado sobre el ancla caliente) | `specs/presets.md` §4; `anchor-pixels.md`; `verification/anchors-m5-23.md` |
| M5-24 | **Mínimo de z_om en los presets** (reemplaza M5-13): z_om = max(0,018·LAI; 0,005 m) con el flag **`EF_H_ZOM_FLOOR_APPLIED`** (I-m, `info`, `cell`, bit 1 de `H`, el del plan de `specs/flags.md` §6.4), registrado en `ef_flags_workflow()` con sus tests (excepción explícita a `specs/flags.md` §7, punto 3, como `EF_G_LOW_LAI_BRANCH`); opción `roughness$zom_min` del preset, `CANDIDATA` en la procedencia. El núcleo `ef_zom()` no cambia (sin mínimo). **`EF_H_ZOM_UNDEFINED` se retira** (nadie puede levantarlo: con el mínimo, z_om > 0): sale del registro, su bit 10 queda ocupado y entra en la lista de retirados `ef_flag_retired()` (`specs/flags.md` §7, punto 6; test R14), aunque solo existió en la versión de desarrollo | SH-02 (`sensible-heat.md` §5.6, V#20): el manual da 0,018·LAI solo para áreas agrícolas (p. 27, Ec. 31a) y valores por uso del suelo en el ap. 2, p. 44 (agua 0,0005 m, nieve 0,005 m, …) **sin valor de suelo desnudo**: 0,005 m sigue `CANDIDATA`. Sin mínimo, las celdas con LAI = 0 quedaban sin ETa (16 con LST en Cauquenes). Con él, en el Maule se calculan 4259 celdas de roca y suelo andino con ETrF mediana −2,97, marcadas (`verification/anchors-m5-23.md` §5) | `specs/sensible-heat.md` §5.6; `specs/flags.md` §4.2, §6.4, §7; `specs/presets.md` §3.2 |
| M5-25 | **Regla de terreno de los presets** (versión 4; `DECIDIDA (provisional)`, 2026-11-10; límite de `flat` y referencia = rango de las anclas, 2026-11-11): las celdas cuya elevación queda **más de 500 m en `idaho2002_elev` o 250 m en `idaho2002_flat` por debajo o por encima del rango de elevación de la calibración** se **excluyen**: se conservan las celdas con min(z_frío, z_caliente[, z_estación]) − límite ≤ z ≤ max(z_frío, z_caliente[, z_estación]) + límite; las excluidas no son candidatas a ancla y quedan `NA` en **todas** las capas del resultado (no se calculan). Rango: los puntos de calibración frío y caliente de una **selección preliminar** con los mismos criterios y sin la regla y, con una estación representativa (C1), la estación (datum de Ts, M5-12, y sitio del forzamiento; así el rango contiene siempre el datum); la selección final corre sobre las celdas conservadas y sus anclas quedan dentro del rango por construcción; el rango preliminar no se recalcula (sin iteración). **Enmienda del 2026-11-11 (opción 1 del autor):** hasta entonces la referencia era un punto, el datum de Ts (la estación o el frío preliminar), y se excluía \|z − z_ref\| > límite; con el límite de 250 m de `flat` eso cortaba en Cauquenes el llano bajo 169 m entre las anclas (44,5 % de las celdas calculadas, ancla fría de un píxel). La recta dT se calibra *entre* las anclas: la regla excluye solo la extrapolación más allá del rango calibrado, no las celdas entre ellas; con las mismas anclas preliminares nunca excluye una celda que la regla anterior conservaba. Flag nuevo **`EF_H_TERRAIN_RULE_APPLIED`** (I-m, `info`, ámbito `cell`, **bit 11 de `H`**, el siguiente libre de `specs/flags.md` §6.4), registrado en `ef_flags_workflow()` con tests positivo y negativo (excepción explícita a `specs/flags.md` §7, punto 3, como `EF_H_ZOM_FLOOR_APPLIED`); en las celdas excluidas solo `flags_h` está definida (ese bit) y las palabras `rad`, `g` y `et` son `NA` (no evaluado). Opción `terrain_rule` del preset (`method = "anchor_elevation_range"`, antes `"datum_elevation_difference"`; `max_elevation_difference` = 500 en `elev` y 250 en `flat`), `CANDIDATA`, en `unverified`; conteos `terrain_rule_excluded`, `terrain_rule_excluded_below` y `terrain_rule_excluded_above` y `scene$terrain_rule` (método, elevaciones de referencia, fuente, límite, rango conservado, anclas finales y `anchors_in_range`) en la procedencia. **Sin pendiente**: los presets siguen en proyección plana (RC-09) y el `dem_method` no cambia | El manual supone clima uniforme y pide partir la imagen o separar la región con otro clima (Waters et al., 2002, pp. 39, 70, 79; ap. 7), da Γ = 6,5 K km⁻¹ "under neutral stability conditions" (ap. 12, p. 95) con el datum en la estación (p. 96) y reserva la montaña al modelo de montaña (ap. 12, pp. 93–97), no implementado. Límites sin fuente primaria: el error de Ts_datum, que crece con la distancia en elevación al datum, se acota por la tolerancia de homogeneidad de las anclas (1,5 K) y se redondea al múltiplo de 50 m superior. `elev` (Γ = 6,5 K km⁻¹) frente al perfil adiabático seco (g/c_p ≈ 9,8 K km⁻¹): 3,3 K km⁻¹, 1,5/3,3 = 455 m → **500 m** (1,65 K en el límite); `flat` (Γ = 0): el error es el gradiente completo del manual, 6,5 K km⁻¹, 1,5/6,5 = 231 m → **250 m** (1,63 K en el límite; mismo redondeo y mismo error en el límite que `elev`, sin la precisión aparente de 230 m; decisión del autor del 2026-11-11, opción B; antes 500 m en ambos). Evaluación (`verification/terrain-rule.md`; coherencia, no validación): elevación absoluta (1000/1500 m), pendiente efectiva (5°/10°, `nasadem_normal_mean`), \|z − z_ref\| (500/750/1000 m) y combinaciones; en el Maule (`elev`) la regla adoptada excluye 10 151 de 24 830 celdas calculadas (40,9 %, todas sobre 760 m) y la ETrF < 0 de la escena pasa de 32,0 % a 0,9 % (`flat` con 500 m, el límite que tuvo hasta el 2026-11-11: 14,1 → 0,3 %), el ancla caliente queda en 109–243 m (antes hasta 2450 m); en Cauquenes no excluye ninguna celda con `elev`. Con `flat` y 250 m: Maule 11 710 celdas (47,2 %; ETrF < 0 0,4 %, > 1,05 31,2 %); Cauquenes 2933 (44,5 %), casi todas **debajo** de la referencia (z < 169 m; z_ref = 419 m, el frío preliminar), con un ancla fría de un solo píxel (`EF_ANCHOR_SINGLE_PIXEL`) y el ancla caliente movida de 145 a 193 m. La pendiente sola deja mesetas altas con ETrF < 0; la cota absoluta es regional. Con la referencia = rango de las anclas (`verification/terrain-rule.md` §10): Cauquenes `flat` excluye 18 celdas (0,3 %, sobre 669 m) en lugar de 2933 y sus anclas vuelven a las de la escena sin regla; Maule 9986 (40,2 %, sobre 803 m; `elev`) y 11 319 (45,6 %; `flat`), casi como con z_ref; Cauquenes `elev` sin cambio. Las celdas excluidas quedan sin ETa: una sub-imagen con su propio clima o el modelo de montaña siguen pendientes | `specs/presets.md` §4.1; `specs/flags.md` §4.2, §6.4, §7; `verification/terrain-rule.md` |

### 1.1 Preguntas P0

Doce preguntas concretas que desbloquean M2. Cada una da la recomendación
**tal como figura en su documento** y la consecuencia de adoptarla.

1. **P0-1 · Verificación METRIC (NR-D3; `DEVELOPMENT.md` §3; `evapotranspiration.md` §14).**
   ¿Se contrastan las ecuaciones METRIC contra Allen, Tasumi & Trezza (2007)
   antes de implementarlas, o se registran algunas como definiciones
   operativas? — *Recomendación:* verificar primero; `ef_net_radiation()` no
   se fusiona a `main` sin confirmar forma, notación y número de ecuación
   (NR-D3); `ef_etrf()` y `ef_et_daily_etrf()` solo se adelantan con una decisión
   explícita registrada. — *Consecuencia:* hasta entonces solo es
   implementable lo `VERIFICADA` contra FAO-56 (LE residual, λ `"constant"`
   y `"fao56"`, ET_inst, ρ_w, P(z)); una única lectura del artículo
   desbloquea a la vez NR-D3, SH-11, SH-09, SH-08, D-AP-04, D-AP-05, los
   ítems 8–18 de `soil-heat-flux.md` §10, V2 de λ y RC-12.
   — *Estado (2026-11-05):* **resuelta en lo que cubre el manual SEBAL de
   Idaho** (Waters et al., 2002), por la política M2-08: NR-D3 (Ec. 2),
   SH-09 (c_p = 1004) y SH-11 (M2-09) se cierran; las formas de Rn y sus
   componentes, G de Bastiaanssen, u*, rah, ψ, L, H, dT, las condiciones de
   borde de las anclas, ET_inst, ETrF y ETa_24 pasan a
   `VERIFICADA (SEBAL-Idaho 2002)` (`VERIFICATION.md`). Siguen `CANDIDATA`
   lo que el manual no cubre: G de Tasumi, τ particionada, λ `"metric"`
   (V2), la regla de cobertura parcial del ancla fría, C_rad, el mínimo de
   z_om, la forma de ρ_air en METRIC y la pendiente de dT sobre Ts_hot.
   El contraste con Allen et al. (2007) queda como deseable, no
   bloqueante.
2. **P0-2 · SH-11.** ¿ψ_m(z_b) en el caso estable se evalúa con 2/L (como
   `water`) o con z_b/L = 200/L? — *Recomendación:* **bloqueante**, verificar
   en la fuente primaria (`sensible-heat.md` §10.3, §18). — *Consecuencia:*
   con L = 41.97 m la corrección vale −0.238 o −23.8; cambia u*, rah y H en
   todo píxel estable. El control propuesto incluye `stable_psi_m_height`
   (§12), de modo que el resto de la iteración puede implementarse sin fijar
   el valor. *Hallazgo M2 (§1.2, M2-07):* con un ancla fría estable, 200 m
   hace divergir la calibración y 2 m converge: la decisión es decisiva.
   — **RESUELTA (2026-11-05, M2-09):** 2/L, con la fuente primaria Waters
   et al. (2002), p. 33, Ec. 38: ψ_m(200 m) = −5·(2/L). Defecto
   `stable_psi_m_height = 2` en `ef_h_control()`; 200 m sigue disponible
   como elección explícita.
3. **P0-3 · RC-12 (con RC-13, GW-07, SPEC-5.1; transversal T-01).** ¿Qué
   temperatura entra en RL↓? — *Recomendación:* función agnóstica
   `ef_rl_in(temperature, atm_emissivity)`; (a) Ta del forzamiento y
   (b) Ts del píxel frío como configuraciones explícitas; (c) Ts por píxel
   solo para verificación cruzada con `water`; verificar antes Allen et al.
   (2007) (`radiation-components.md` §6.5.B). — *Consecuencia:* (b) obliga a
   seleccionar anclas **antes** de Rn (`anchor-pixels.md` §1.3); (a) es la
   única vía por la que GWR entra en RL↓ y hereda el riesgo de circularidad
   Ta–LST (GW-07).
   — *Evidencia (2026-11-05):* el manual SEBAL de Idaho usa la opción
   **(b)**: RL↓ = ε_a·σ·T_cold⁴ con la Ts del píxel frío como temperatura
   del aire cerca de la superficie (Waters et al., 2002, p. 23, Ecs. 21 y
   23), corregida por elevación en cada píxel en el modelo de montaña
   (T_cold + 0,0065·Δz, Ec. 12-8); Allen et al. (2012, p. 74) describen lo
   mismo para METRIC (temperatura de referencia de una superficie bien
   regada, con gradiente por elevación). La forma de `ef_rl_in()` pasa a
   `VERIFICADA (SEBAL-Idaho 2002)` y la configuración verificada es (b);
   la función sigue agnóstica (argumento `temperature` explícito) y (a)
   sigue como configuración de investigación (H1). Queda para el autor
   fijar (b) como la del preset `VERIFICADA` de `earthflux()` y decidir si
   se implementa el ajuste por elevación de T_cold.
   — **Cerrada para los presets (2026-11-06, M5-11):** los presets de
   `earthflux()` usan (b), Ts del ancla fría, con las anclas seleccionadas
   antes de Rn; `idaho2002_elev` aplica el ajuste por elevación de la
   Ec. 12-8 y `idaho2002_flat` no. La función del núcleo sigue agnóstica y
   (a) sigue disponible en el nivel experto.
4. **P0-4 · Unidades y tiempo del núcleo (ARCH-4 = WF-02; RC-01; RC-03; T-09, T-02).**
   ¿K y radianes en todo el núcleo `metric`, °C solo en `forcing` y en la ET
   de referencia, y tiempo como `doy` + `utc_hour` numéricos? —
   *Recomendación:* °C en `forcing` y ET de referencia con conversión
   explícita a K en la frontera (WF-02); radianes en todo, incluida lat/lon
   (RC-01); `doy`/`utc_hour` numéricos con envoltorio desde `POSIXct` UTC
   (RC-03). — *Consecuencia:* cierra el `TODO` de `ARCHITECTURE.md` §4; los
   grados pasados por error se detectan en latitudes chilenas; para MOD11A1
   la hora de paso es hora solar media (`modis-products.md` §6.1) y la
   ecuación del tiempo se aplica una sola vez.
5. **P0-5 · Constantes físicas (G-D9, WF-14, RC-07, RC-06; T-06, T-07).**
   ¿Una sola constante por magnitud en el paquete (273.15 K; σ CODATA
   exacto; Gsc coherente con los coeficientes de τ), con literales de la
   norma solo dentro de las funciones de ET de referencia? —
   *Recomendación:* 273.15 en todo el paquete (G-D9); σ exacto (RC-07); Gsc
   "con que se derivaron los coeficientes de τ" (RC-06); literales FAO-56/ASCE
   dentro de las funciones de referencia (WF-14). — *Consecuencia:*
   diferencias con `water` documentadas (≈ 0.018 W m⁻² en G; 6.6 × 10⁻⁵
   relativo en RL↑); los tests que reproducen casos publicados necesitan
   tolerancia justificada.
6. **P0-6 · Densidad del aire y c_p (SH-08, SH-09, SH-10, SH-19; T-04).**
   ¿ρ_air con la forma de FAO-56 evaluada con T_a = Ts − dT, c_p único (1004
   o 1013 J kg⁻¹ K⁻¹), T_a y ρ iterada en L, y dT₀ = 0? —
   *Recomendación:* §8.1 con T_a y P de `ef_air_pressure()` o medida (SH-08);
   c_p: verificar en Allen et al. (2007) (SH-09); T_a y ρ iterada (SH-10);
   dT₀ = 0 (SH-19). — *Consecuencia:* c_p se cancela en H salvo a través de L
   (§8.3), por lo que una constante única nombrada no bloquea la
   implementación; diferencia con `water` ≈ 0.6 % en ρ.
7. **P0-7 · λ única en la cadena (ET-D1, ET-D2; T-05).** ¿Una sola función
   `ef_lambda()` para la condición del ancla fría y para la
   conversión LE → ET, con `method` explícito y `"constant"` como defecto de
   `earthflux()` hasta verificar V2? — *Recomendación:* `"constant"`
   (FAO-56) hasta V2; luego evaluar `"metric"`; función de bajo nivel sin
   defecto (ET-D1); guarda de unidades [10⁶, 10⁷] J kg⁻¹ (ET-D2). —
   *Consecuencia:* evita la inconsistencia observada en `water` (0.002361 en
   anclas frente a 0.00236 en ET diaria); la ETrF del ancla fría reproduce
   exactamente el coeficiente impuesto.
8. **P0-8 · Anclas sin defectos implícitos (D-AP-01, D-AP-02, D-AP-04, D-AP-05).**
   ¿Núcleo de anclas sin umbrales ni k por defecto, sin relajación
   automática, con `etrf_hot`/`le_hot` explícitos? — *Recomendación:* sí, en
   los cuatro casos (`anchor-pixels.md` §9). — *Consecuencia:* `earthflux()`
   no podrá seleccionar anclas automáticamente hasta disponer de un preset
   `VERIFICADA`; los tests usan parámetros explícitos; el antecedente del
   autor (k = 0.5 frente a ~1.05) justifica registrar k con fuente y estado.
9. **P0-9 · Agregación de anclas (D-AP-06 = SH-14; D-AP-03; T-03).** ¿El
   módulo de anclas entrega un único punto de calibración por clase
   (`aggregate` explícito, ETr_inst evaluada por ancla a su hora de paso) y
   el módulo de H consume ese único valor? — *Recomendación:* `aggregate`
   explícito y registro de la dispersión (D-AP-06); caso base "exactamente un
   valor por clase" en H (SH-14, `sensible-heat.md` §2.3); condiciones de
   borde en una función propia de la etapa [B] (D-AP-03). — *Consecuencia:*
   H no implementa los modos `"mean"`/`"lm"` de `water`; la calibración por
   píxel o por regresión queda para evaluación posterior.
10. **P0-10 · Iteración de H (SH-15, SH-16, SH-17).** ¿Fase B con la
    estrategia P2 (a*, b* fijos y convergencia por píxel), `tol` = 0.01 por
    ancla, `maxit` = 20, ω = 0, y driver de calibración exportado? —
    *Recomendación:* sí (`sensible-heat.md` §11.7, §18). — *Consecuencia:* el
    resultado depende solo de (a*, b*); la estrategia P1 (`water`) queda para
    verificación cruzada; `tol` importa (0.7 % en a en el caso sintético) y
    se documenta. — *Revisión 2026-11-10 (M2-11, §1.2):* con P2 una Fase A
    detenida con `tol` = 0.01 desplaza H de todos los píxeles (hasta
    ~1,3 W m⁻²); cada fase tiene ahora su tolerancia (`tol` = 10⁻⁶,
    `pixel_tol` = 10⁻⁵, `maxit` = `pixel_maxit` = 100).
11. **P0-11 · Valores imposibles en rásteres (G-D6, ET-D6, WF-04, GW §2.3; T-13).**
    ¿Entrada físicamente imposible → error con clase (y la limpieza es de QA
    aguas arriba), o se ofrece `on_invalid = "na_flag"`? —
    *Recomendación:* error por defecto; evaluar opción `on_invalid` (G-D6);
    `etr_inst` ≤ 0 → error de dominio (ET-D6). — *Consecuencia:* un único
    píxel inválido detiene la escena; choca con las superficies GWR, que
    conservan y marcan predicciones fuera de dominio (`gwr-forcing.md` §2.3),
    por lo que debe existir una política única antes de encadenar M2 con M3.
12. **P0-12 · Convenciones comunes del núcleo (ARCH-3, NR-D5, NR-D6, D-AP-09, G-5.2; T-16, T-17).**
    ¿Se confirman: funciones aritméticas vectorizadas sobre
    `numeric`/matrices con envoltorio `terra`; longitud 0 rechazada; `dim` sin
    reciclar; una función por método más despachador delgado con `method`
    sin defecto; diseño coordinado de las clases de retorno en M2? —
    *Recomendación:* sí (`ARCHITECTURE.md` §3; `ef_net_radiation.md` §10.2;
    D-AP-09; `soil-heat-flux.md` §5.2; G-D3; ET-D12). — *Consecuencia:* los
    helpers de `R/utils.R` se comparten en toda la cadena; NR-D6 debe
    revisarse al diseñar el soporte de `SpatRaster`.

---

## 2. Resumen cuantitativo

Recuento por filas del registro (sección 5; una fila por ID original o por
decisión sin ID). Las decisiones duplicadas entre documentos se cuentan en
cada documento y se agrupan en la sección 4.

| | ABIERTA | DECIDIDA | CERRADA | Total |
|---|---|---|---|---|
| Filas | 143 | 16 | 3 | **162** |

Recuento a la fecha de corte. La adopción provisional de §1.0 pasa
**34 filas** de `ABIERTA` a `DECIDIDA (provisional)` (con ellas: 109
`ABIERTA`, 50 `DECIDIDA`, 3 `CERRADA`); las decisiones de implementación
de M3 (§1.3) pasan **8 filas** más (WF-03, WF-04, WF-13, GW-02, GW-03,
GW-22, GW-23 y ARCH-6.3b para M3): 101 `ABIERTA`, 58 `DECIDIDA`, 3
`CERRADA`; las de M4 (§1.4) pasan **3 filas** más (MP-10, MP-11 y
MP-13): 98 `ABIERTA`, 61 `DECIDIDA`, 3 `CERRADA`; y las decisiones del
autor del 2026-11-04 posteriores a M4 (M4-27, M4-28) pasan **2 filas** más
(MP-06 y MP-12): 96 `ABIERTA`, 63 `DECIDIDA`, 3 `CERRADA`. Las decisiones de diseño de la API de usuario del 2026-11-05 (§1.5, M5-01 … M5-07) son nuevas y no cambian el recuento. La revisión de verificación del 2026-11-05 (§1.2, M2-08 … M2-10) pasa **3 filas** de `ABIERTA` a `CERRADA` (NR-D3, SH-09 y SH-11): 93 `ABIERTA`, 63 `DECIDIDA`, 6 `CERRADA`; SH-10 sigue `DECIDIDA` con contenido revisado. M2-11 (2026-11-10) revisa el contenido de SH-16, que sigue `DECIDIDA (provisional)`, sin cambiar el recuento. Las tablas de esta sección y de §5 conservan el recuento
original salvo en la columna de estado.

Decisiones abiertas por prioridad:

| Prioridad | Filas | Documentos con más filas |
|---|---|---|
| P0 | 65 | `sensible-heat.md` (20), `radiation-components.md` (14), `anchor-pixels.md` (10) |
| P1 | 56 | `gwr-forcing.md` (18), `weather-forcing.md` (15), `modis-products.md` (12) |
| P2 | 22 | `evapotranspiration.md` (7), `soil-heat-flux.md` (3), `VALIDATION_PLAN.md` (3) |

Por documento:

| Documento | Filas | ABIERTA (P0/P1/P2) | DECIDIDA | CERRADA |
|---|---|---|---|---|
| `ARCHITECTURE.md` | 12 | 6 (2/3/1) | 6 | 0 |
| `DEVELOPMENT.md` | 3 | 1 (0/0/1) | 2 | 0 |
| `VALIDATION_PLAN.md` | 5 | 5 (1/1/3) | 0 | 0 |
| `SCIENTIFIC_SPEC.md` (sin 5.1) | 1 | 1 (0/1/0) | 0 | 0 |
| `specs/ef_net_radiation.md` | 8 | 4 (2/0/2) | 3 | 1 |
| `specs/radiation-components.md` | 17 | 17 (14/3/0) | 0 | 0 |
| `specs/soil-heat-flux.md` | 10 | 10 (7/0/3) | 0 | 0 |
| `specs/anchor-pixels.md` | 12 | 12 (10/1/1) | 0 | 0 |
| `specs/sensible-heat.md` | 20 | 20 (20/0/0) | 0 | 0 |
| `specs/evapotranspiration.md` | 16 | 16 (7/2/7) | 0 | 0 |
| `specs/weather-forcing.md` (+ SPEC-5.1) | 17 | 17 (2/15/0) | 0 | 0 |
| `specs/gwr-forcing.md` | 23 | 20 (0/18/2) | 1 | 2 |
| `specs/modis-products.md` | 14 | 14 (0/12/2) | 0 | 0 |
| `decisions/gwr-backend.md` | 4 | 0 | 4 | 0 |

---

## 3. Decisiones ya tomadas por el autor

| ID | Decisión | Estado y fecha | Dónde está registrada | Pendiente asociado |
|---|---|---|---|---|
| BK-1 | `spgwr` descartado como backend y como referencia cruzada; solo antecedente histórico | DECIDIDA, 2026-11-04 | `decisions/gwr-backend.md` "Decisiones del autor"; `ARCHITECTURE.md` §6.1; `gwr-forcing.md` §1.2, GW-01 | Sincronizar textos que aún lo proponen como "segunda referencia" (§6, ítem 3) |
| BK-2 | Núcleo GWR **interno** (R base, matrices) como motor de cálculo | DECIDIDA, 2026-11-04 | Ídem | `DEVELOPMENT.md` §4 y `SCIENTIFIC_SPEC.md` §6 aún dicen "decisión abierta" |
| BK-3 | `GWmodel` solo en `Suggests`, como referencia de tests (`skip_if_not_installed`) | DECIDIDA, 2026-11-04 | Ídem; GW-15 | Resuelve la pregunta 2 de `gwr-backend.md` §8 (tests en `tests/`) |
| BK-4 | `mgwrsar` como opción futura **solo si** se requiere MGWR | DECIDIDA, 2026-11-04 | Ídem; GW-16 | Resuelve la pregunta 1 de `gwr-backend.md` §8 (MGWR fuera del alcance inicial) |
| ARCH-6.2 | `terra` como backend ráster; `sf` solo si se justifica; `terra` en `Imports` con la primera función que lo use | DECIDIDA (ACEPTADA), 2026-11-04 | `ARCHITECTURE.md` §6.2; `DEVELOPMENT.md` §4 | — |
| ARCH-6.3a | Procesamiento en paralelo como **requisito**, con reglas: secuencial por defecto, secuencial = paralelo (semillas), sin `mclapply()`, ≤ 2 núcleos en CRAN, dependencia con la primera función, medir antes de optimizar | DECIDIDA (ACEPTADO como requisito), fecha no registrada en el documento | `ARCHITECTURE.md` §6.3 (y §6.2 para el nivel intra-escena con `terra`); `DEVELOPMENT.md` §4 | Diseño y paquete (`future.apply` vs `furrr`): ARCH-6.3b, resuelta para M3 con `future.apply` (§1.3, M3-35); el resto del diseño sigue en `specs/parallel-processing.md` |
| DEV-2.6 | roxygen2 **8.1.1** fijado; workflow `document.yaml` que regenera y falla si hay diferencias (sin commits); `pkgdown.yaml`; `about.yaml` con `ABOUT_TOKEN` | DECIDIDA, fecha no registrada | `DEVELOPMENT.md` §2.6 | Actualizar roxygen2 = cambiar la versión fijada y regenerar localmente |
| ARCH-6.6a | `Language: en-GB` | DECIDIDA ("Adoptado"), fecha no registrada | `ARCHITECTURE.md` §6.6 | — |
| DEV-1 | `dev/` en español con términos en inglés; documentación pública, código y commits en inglés | DECIDIDA, fecha no registrada | `DEVELOPMENT.md` §1 | — |
| ARCH-5 | Paquete `units` no adoptado por ahora | DECIDIDA (provisional), fecha no registrada | `ARCHITECTURE.md` §5 | Reevaluar en M2 si aparecen errores de unidades |
| ARCH-6.6d | Verificación cruzada contra `water` (GPL) fuera del tarball, cargando `water` solo si está instalado | DECIDIDA, fecha no registrada | `ARCHITECTURE.md` §6.6; `VALIDATION_PLAN.md` §1.3 | Precisar la ubicación (§6, ítem 10) |
| ARCH-6.6e | `CITATION.cff` creado; `.zenodo.json` e `inst/WORDLIST` con el primer release; workflows `pkgdown` y `release` planificados | DECIDIDA (plan), fecha no registrada | `ARCHITECTURE.md` §6.6 | M0/M7 |
| NR-10.1 | Firma y unidades de `ef_net_radiation()`; ε₀ explícita; término reflejado explícito; `rl_out` = onda larga emitida; NA sin flags; errores de dominio con clase; Rn < 0 sin warning | DECIDIDA, fecha no registrada | `ef_net_radiation.md` §10.1 | — |
| NR-D5 | Argumentos de longitud 0 rechazados | DECIDIDA (provisional, "tomada al implementar") | `ef_net_radiation.md` §3.1, §10.2 | Revisable si un envoltorio procesa bloques vacíos |
| NR-D6 | Argumentos con `dim` no se reciclan y deben compartir `dim` | DECIDIDA (provisional, "tomada al implementar") | `ef_net_radiation.md` §3.1, §10.2 | Revisar al diseñar `SpatRaster` (P0-12) |
| GW-16 | MGWR diferido; `mgwrsar` como opción a evaluar | DECIDIDA, 2026-11-04 | `gwr-forcing.md` §13 | = BK-4 |
| NR-D4 | DOI de Allen et al. (2007): 10.1061/(ASCE)0733-9437(2007)133:4(380) | CERRADA, 2026-11-04 | `ef_net_radiation.md` §10.2; `verification/reference-audit.md` §8 | Quitar `TODO: confirmar DOI` de §2.2 y §2.3 (§6, ítem 9) |
| GW-01 | Backend de GWR | CERRADA, 2026-11-04 | `gwr-forcing.md` §13 | = BK-1, BK-2, BK-3 |
| GW-15 | Referencia cruzada solo con `GWmodel` en `tests/` | CERRADA, 2026-11-04 | `gwr-forcing.md` §13 | = BK-3 |
| MP-06 | LAI de clases no vegetadas: `NA` + flag por defecto; asignación explícita como opción declarada (`lai_nonveg`, un valor o uno por clase), con `EF_SURF_LAI_ASSIGNED`; la escena de ejemplo usa 0 | DECIDIDA, 2026-11-04 | §1.4, M4-28, M4-29; `specs/modis-products.md` §5.7, §15 | Valor asignado `CANDIDATA`; reglas propias para agua/nieve (A-M4-6) |
| MP-12 | Datos de ejemplo: provincia de Cauquenes; **2019-02-15**, Terra, MOD11A1/MCD43A3/MOD13A2/MCD15A2H, tesela h12v12 | DECIDIDA, 2026-11-04 | §1.4, M4-26, M4-27; `specs/modis-products.md` §12, §15 | Ejecutar `data-raw/modis-example.R` con token y versionar `inst/extdata/modis-example/` (`ROADMAP.md` M4) |
| M5-01 … M5-05, M5-07 | API de usuario en tres niveles; producto ≠ validación; nivel básico con área, fecha, una fuente meteorológica y `preset` obligatorio; MODIS y MDE automáticos; cobertura de suelo opcional; ERA5 vía Open-Meteo como forzamiento predeterminado sin estaciones (M5-06 provisional) | DECIDIDA, 2026-11-05 | §1.5; `ARCHITECTURE.md` §1 (9), §6.7 | Presets (contenido y estado); viento y hora de paso de ERA5 sin evaluar |
| M5-08 … M5-17 | `earthflux()` con presets no verificados declarados y avisados (D-AP-01 reescrita); presets `idaho2002_elev` e `idaho2002_flat` (`CANDIDATA`, versión 1); criterios de anclas; RL↓ con el ancla fría (cierra P0-3 para los presets); Γ; z_om indefinida con LAI = 0 (`EF_H_ZOM_UNDEFINED`); viento; ERA5; día de ETr₂₄; opciones MODIS y MDE | DECIDIDA (provisional), 2026-11-06 | §1.5; `specs/presets.md` | M5-10 y M5-13 reemplazadas por M5-23 y M5-24 |
| M5-23, M5-24 | Presets versión 2: criterios de anclas recalibrados para MODIS a 1 km (NDVI por percentiles, bandas de albedo, un paso de relajación, sin anclas en LAI asignado); mínimo de z_om de 0,005 m con `EF_H_ZOM_FLOOR_APPLIED` y retiro de `EF_H_ZOM_UNDEFINED` | DECIDIDA (provisional), 2026-11-06 (aprobadas por el autor) | §1.5; `specs/presets.md` §4; `verification/anchors-m5-23.md` | Relieve (laderas andinas con ETrF < 0), selección sobre Ts o Ts_datum (D-AP-07), z_om de coberturas no agrícolas, validación con datos de referencia |
| M5-25 | Presets versión 4: regla de terreno, celdas a más de 500 m (`idaho2002_elev`) o 250 m (`idaho2002_flat`, desde el 2026-11-11) del rango de elevación de la calibración (anclas preliminares y estación; desde el 2026-11-11, antes la elevación del datum) excluidas de las anclas y del resultado, con `EF_H_TERRAIN_RULE_APPLIED` (bit 11 de `H`) | DECIDIDA (provisional), 2026-11-10; enmendada 2026-11-11 (decisión del autor; límite `CANDIDATA`) | §1.5; `specs/presets.md` §4.1; `verification/terrain-rule.md` §10 | ETa de las celdas excluidas (sub-imagen o modelo de montaña), límites con fuente, rango que depende de anclas preliminares (un ancla preliminar de montaña lo ensancharía), extensión por la estación sin escena real, validación con datos de referencia |

**Evidencia previa del autor (registrada; las decisiones siguen abiertas).**

- **GW-07 (covariables de superficie, Ta–LST):** Galdón-Ruíz, Fuentes-Jaque
  et al. (2023), *Revista de Teledetección* 61:59–71 (GWR de Tmin/Tmax con
  LST MODIS; R² 0,69–0,87), y Montaner-Fernández et al. (2020), *Remote
  Sensing* 12:3345 (`gwr-forcing.md` §2.7; `REFERENCES.md`, *Author's prior
  work*). Leída solo a nivel de resumen. Respalda LST como predictor de Ta,
  pero para **medias mensuales**; no resuelve el **acoplamiento** dentro de
  METRIC. GW-07 sigue **ABIERTA** (defecto provisional: opción (a)).
- **RC-13 (emisividad atmosférica):** Morales-Salinas et al. (2023),
  *Scientific Reports* 13:14465 (Brutsaert con coeficiente variable en el
  tiempo y el espacio; −64 % de error de Rn) (`radiation-components.md`
  §6.5; `REFERENCES.md`). Leída a nivel de resumen; RC-13 sigue **ABIERTA**.
- **Antecedente MODIS + METRIC + GWR** (`decisions/antecedente-metric-modis.md`):
  evidencia para RC-12, GW-07, D-AP-04, MP-03, GW-08 y GW-17 (anclas
  manuales, k = 0,5, kernel declarado pero no transmitido, recortes
  silenciosos). No contiene decisiones con ID.

---

## 4. Decisiones transversales

Cada grupo reúne decisiones de varios documentos sobre la misma cuestión.
"Ruta propuesta" es una propuesta de **este registro** construida solo con
recomendaciones ya escritas en los documentos citados; el autor decide.

### T-01 · Temperatura del aire en RL↓ y punto de entrada del forzamiento espacial — P0 (núcleo) / P1 (defectos)

- **IDs:** RC-12, RC-13, RC-10, GW-07, SPEC-5.1, WF-09, SH-08/SH-10
  (T_a = Ts − dT), D-AP-03 y `anchor-pixels.md` §1.3; antecedente, lección 2.
- **Solape:** RC-12 decide qué T entra en RL↓; si es Ta regionalizada, GW-07
  decide si LST puede ser covariable (circularidad Ta–LST, análoga a la
  opción (c) de RC-12, `gwr-forcing.md` §2.7); SPEC-5.1 decide si se
  regionalizan los insumos (Ta, eₐ) o ETr; RC-13 (Brutsaert en eₐ y Ta) haría
  depender ε_a del mismo forzamiento. Si RC-12 = (b), las anclas deben
  seleccionarse antes de Rn.
- **Conflicto documental:** la tabla de RC-12 (`radiation-components.md`
  §6.5.B, opción (a)) dice "Estación única + gradiente = C1; **GWR = C2**",
  mientras `VALIDATION_PLAN.md` §2.1 define C2 = alternativa espacial de
  referencia y **C3 = GWR**.
- **Ruta propuesta:** (1) M2: implementar `ef_rl_in(temperature, …)`
  agnóstica y `ef_atm_emissivity()` con método explícito (forma en
  τ_sw; Brutsaert solo cuando se verifique, con coeficiente explícito y
  registrado, RC-13); (2) pipeline con RC-12 (a) y (b) como configuraciones
  registradas; (3) M3: GW-07 por defecto (a) y LST como opción (b) con
  `EF_GWR_SURFACE_COVARIATE` y sensibilidad obligatoria; SPEC-5.1 con A y C
  soportadas; (4) M6: diseño factorial de `weather-forcing.md` §6 punto 3.
  Corregir "GWR = C2" → "GWR = C3".
- **Evidencia (2026-11-05):** el manual SEBAL de Idaho y Allen et al.
  (2012) usan la opción (b) de RC-12 (Ts del píxel frío, con gradiente por
  elevación); ver P0-3 y `VERIFICATION.md`, fila 7.

### T-02 · Tiempo, hora de paso y definición del día — P0 (núcleo) / P1

- **IDs:** RC-03, MP-01, MP-02, `modis-products.md` §6.1–6.2, D-AP-06
  (Q-AP-09), WF-09, WF-11, ET-D16, `evapotranspiration.md` §1.3 (base
  temporal, ítem V5).
- **Solape:** RC-03 dejó abierta la semántica del *view time*;
  `modis-products.md` §6.1 la resuelve para MOD11A1 (hora solar **media**,
  UTC + λ/15) pero no para MOD21A1D (MP-01). La ETr_inst del ancla (WF-09,
  D-AP-06) y el día de ETr24 (WF-11 ↔ ET-D16) dependen del mismo instante
  UTC por píxel.
- **Ruta propuesta:** cerrar la parte MOD11A1 de RC-03 con
  `modis-products.md` §6.2 (t_utc = (t_ls − λ/15) mod 24; ecuación del
  tiempo una sola vez en `ef_solar_geometry()`); MOD21 exige declaración
  explícita (MP-01); WF-09 O3 por defecto y ETr24 por suma horaria (WF-16 D1)
  para coherencia ETr_inst–ETr24; `day_definition` explícito (WF-11), y
  ET-D16 se cierra por delegación a WF-11.

### T-03 · Agregación de varios píxeles ancla por clase — P0

- **IDs:** D-AP-06, SH-14, D-AP-03, `sensible-heat.md` §2.2–2.3,
  `anchor-pixels.md` §5.5 (`calibration_points`).
- **Solape:** ambos documentos abren la misma decisión (promedio de
  entradas, de dT, por par o regresión) y cada uno remite al otro.
- **Ruta propuesta:** dueño único = `anchor-pixels.md` (D-AP-06): el módulo
  de anclas produce un punto por clase en `calibration_points` con el método
  de agregación registrado; `sensible-heat.md` conserva el caso base "un
  valor por clase" y SH-14 se cierra por referencia a D-AP-06.

### T-04 · Calor específico del aire c_p — P0

- **IDs:** SH-09; `SCIENTIFIC_SPEC.md` §3 (fila H: "c_p ≈ 1004 `TODO`");
  `sensible-heat.md` §4.3, §8.3; FAO-56 (1013 J kg⁻¹ K⁻¹, cap. 3, texto de
  Ec. 8) usado implícitamente en γ de la ET de referencia (WF-14).
- **Solape:** 1004 (`water`, SPEC) frente a 1013 (FAO-56).
- **Ruta propuesta:** una constante interna nombrada para la cadena METRIC,
  con el valor que confirme Allen et al. (2007) (SH-09); las funciones de ET
  de referencia mantienen los literales de su norma (WF-14). La sensibilidad
  es baja (c_p se cancela en H salvo vía L, §8.3), por lo que no bloquea el
  código si la constante vive en un solo lugar.
- **Resuelto (2026-11-05, M2-08):** 1004 J kg⁻¹ K⁻¹ confirmado en el
  manual SEBAL de Idaho (Waters et al., 2002, pp. 25 y 32); SH-09 `CERRADA`.

### T-05 · Calor latente de vaporización λ — P0

- **IDs:** ET-D1, ET-D2, `evapotranspiration.md` §4.2–4.3,
  `anchor-pixels.md` §2.2 (λ(Ts) de `water` con 0.002361),
  `sensible-heat.md` §2.2 ("λ y su referencia viven" en anclas),
  `weather-forcing.md` §10 (FAO-56 Ec. 3-1).
- **Solape:** tres variantes (2.45 MJ kg⁻¹; 2.501 − 2.361·10⁻³·T con
  temperatura del **aire**; 2.501 − 0.00236·(Ts − 273.15) con temperatura de
  **superficie**) y un uso cruzado en anclas y en la conversión LE → ET.
- **Ruta propuesta:** la condición de borde del ancla fría llama a la misma
  `ef_lambda()` que la conversión de ET (regla de
  `evapotranspiration.md` §4.3); `method` explícito; defecto `"constant"`
  hasta verificar V2 (ET-D1).

### T-06 · Constante de conversión K ↔ °C (273.15 / 273.16 / 273) — P0

- **IDs:** G-D9, SH-08, WF-14, `soil-heat-flux.md` §3.2 (273.16 en la rama
  de suelo desnudo de `water`), `sensible-heat.md` §4.3 y §8.1 (273 en T_Kv
  de FAO-56), `weather-forcing.md` §4.8 (273.16 en Rnl de FAO-56),
  `evapotranspiration.md` §4.2 (`EF_KELVIN_OFFSET`).
- **Ruta propuesta:** `EF_KELVIN_OFFSET = 273.15` en todo el paquete (G-D9);
  dentro de las funciones normativas de ET de referencia, literales de la
  norma (WF-14); para ρ_air (SH-08), la forma de §8.1 reescrita con T en K
  usa el desplazamiento del paquete (diferencia ≈ 5 × 10⁻⁴ relativa,
  documentada). Confirmar en la fuente primaria la constante de la rama de
  Tasumi (ítem 12 de `soil-heat-flux.md` §10).

### T-07 · Constantes radiativas σ y Gsc — P0

- **IDs:** RC-07, RC-06, WF-14, `weather-forcing.md` §10 (σ de FAO-56 =
  5.6748 × 10⁻⁸; Gsc FAO-56 = 1366.67 W m⁻²), `ef_net_radiation.md` §7
  (caso con 5.67 × 10⁻⁸, solo para construir el número).
- **Ruta propuesta:** σ exacto CODATA 2018 en el núcleo (RC-07); σ de la
  norma solo en ET de referencia (WF-14); Gsc igual al valor con que se
  derivaron los coeficientes de τ (RC-06), con 1366.67 W m⁻² de FAO-56 como
  insumo documentado.

### T-08 · Presión atmosférica y archivo compartido — P0

- **IDs:** RC-08, RC-17, WF-01, WF-05, `sensible-heat.md` §8.4,
  `weather-forcing.md` §10 (discrepancia de K_B de FAO-56 Anexo 3
  Ec. 3-18/3-20 con la forma registrada en RC-08).
- **Ruta propuesta:** `ef_air_pressure()` (FAO-56 Ec. 7, `VERIFICADA`), γ, e°
  y Δ en un único archivo atmosférico compartido (RC-17 = WF-01); P(z) para
  ETr (WF-05); origen de P para τ_sw y ρ_air configurable y registrado
  (RC-08, SH-08). La discrepancia de K_B se resuelve dentro de RC-08 contra
  ASCE-EWRI (2005) y Allen et al. (2007).

### T-09 · Unidades de temperatura y de ángulos en los contratos — P0

- **IDs:** ARCH-4 (`ARCHITECTURE.md` §4, `TODO: decidir K vs °C`), WF-02,
  RC-01, `radiation-components.md` §4.1 (K en el núcleo), `gwr-forcing.md`
  §2.3 (`air_temperature` en °C), `evapotranspiration.md` §4.5 (λ
  `"fao56"` recibe temperatura del aire en K), `weather-forcing.md` §7.2
  (lon/lat en grados WGS84), `modis-products.md` §6.2 (λ en grados).
- **Ruta propuesta:** K y radianes en las funciones `ef_*()` del módulo
  `metric`; °C en `forcing` y en las funciones de ET de referencia (FAO-56
  formulada en °C); conversión explícita en la frontera (WF-02);
  coordenadas geográficas en grados solo en contratos de entrada/salida
  (estaciones, *view time*), convertidas a radianes antes del núcleo
  (RC-01). ARCH-4 se cierra con WF-02.

### T-10 · Emisividad superficial ε₀ — P0 (contrato) / P1 (fuente)

- **IDs:** RC-14, MP-04, NR-D7, contrato C2 de `radiation-components.md` §1.
- **Ruta propuesta:** la misma ε₀ en `ef_rl_out()` y
  `ef_net_radiation()` (C2, garantizado por el orquestador); preferir la ε₀
  derivada del producto LST (RC-14; MP-04 E1/E2) con referencia primaria;
  NR-D7 se decide junto con `ef_rl_out(lst, emissivity)`.

### T-11 · Albedo, fracción difusa y circularidad con Rs↓ — P1

- **IDs:** MP-03, RC-09 (ρ_g), `modis-products.md` §8.1 (opción A1),
  antecedente §3 (fuente del modelo de fracción difusa por tramos `TODO`).
- **Ruta propuesta:** A2/A3 explícitas mientras no se resuelva la
  circularidad (S de `ef_tau_sw_allen()`, que usa α como ρ_g); A1 solo
  con la solución documentada (MP-03).

### T-12 · Coeficiente del ancla fría, tipo de referencia y rango de ETrF — P0 / P1

- **IDs:** D-AP-04, ET-D5, ET-D9, `anchor-pixels.md` §2.4 (tipo de
  referencia `"ETr"`/`"ETo"`), `weather-forcing.md` §5.1 y §5.4
  (`reference = c("alfalfa", "grass")`), `evapotranspiration.md` §1.3
  ("nombres a fijar en la especificación de forzamiento"), §7.3; antecedente
  (k = 0,5).
- **Conflicto documental:** nombres del tipo de referencia distintos en
  anclas (`"ETr"`/`"ETo"`) y en forzamiento/ET (`"alfalfa"`/`"grass"`).
- **Ruta propuesta:** k explícito, con fuente y estado (D-AP-04); nombres de
  referencia los de `weather-forcing.md` §5.4, que es el documento designado
  por `evapotranspiration.md` §1.3; comprobación en la orquestación con
  `earthflux_reference_mismatch` (ET-D9); rango de ETrF sin umbral hasta V7
  (ET-D5), recordando que depende de la referencia y de k.

### T-13 · Valores fuera de dominio: error frente a NA + flag — P0

- **IDs:** G-D6, ET-D6, WF-04, `gwr-forcing.md` §2.3 (`EF_GWR_PHYSICAL_RANGE`,
  "los consumidores deciden"), `weather-forcing.md` §5.4 (ETr < 0 conservada
  con `EF_ETREF_NEGATIVE`), `ef_net_radiation.md` §6, `anchor-pixels.md` §5.3.
- **Conflicto:** el núcleo detiene la escena ante un valor imposible
  (G-D6, ET-D6), mientras GWR y ET de referencia conservan y marcan valores
  fuera de dominio; un ETr_inst ≤ 0 marcado en una celda detendría `ef_etrf()`.
- **Ruta propuesta:** una política única, documentada en `ARCHITECTURE.md`:
  error por defecto en las funciones de bajo nivel (G-D6) y responsabilidad
  explícita de la orquestación de convertir en `NA` + flag lo marcado aguas
  arriba antes de llamar al núcleo; la opción `on_invalid` de G-D6 es la
  única alternativa documentada y debería decidirse una sola vez para todos
  los módulos.

### T-14 · Nomenclatura y registro de flags — P0 (núcleo) / P1

- **IDs:** WF-07, ET-D4, GW-14; solapes de códigos propuestos:
  `EF_ANCHOR_DT_SMALL` (`sensible-heat.md` §16) frente a
  `EF_ANCHOR_SMALL_CONTRAST` (`anchor-pixels.md` §6);
  `EF_H_EXCEEDS_AVAILABLE` (§16 de H) frente a `EF_LE_NEGATIVE` (ET-D4) y
  `EF_ET_NEGATIVE` (registrado); `EF_AVAILABLE_ENERGY_NONPOSITIVE`
  (`evapotranspiration.md` §7.2) frente a `EF_G_EXCEEDS_RN`
  (`soil-heat-flux.md` §6.3); `EF_MODIS_COMPOSITE_LAG` frente a
  `EF_ANCHOR_COMPOSITE_LAG`; `EF_WS_*` frente a `EF_RS_EXCEEDS_EXTRATERRESTRIAL`
  y `EF_STATION_CLOUDY`.
- **Ruta propuesta:** antes de registrar cualquier flag nuevo en
  `ef_flag_registry()`, fijar una tabla de prefijos (WF-07) y la regla "un
  código por condición física, asignado a la etapa que la detecta primero";
  codificación por bits en rásteres (GW-14).

### T-15 · Valores por defecto de métodos y parámetros — P0 (regla) / P2 (`earthflux()`)

- **IDs:** G-D1, ET-D1, GW-04, GW-05, D-AP-01, SH-01, SH-16, MP-09.
- **Patrón común ya escrito en los documentos:** `method` sin defecto en el
  núcleo; `earthflux()` fija un defecto documentado solo si la formulación
  está `VERIFICADA` (D-AP-01, G-D1, ET-D1, GW-04).
- **Ruta propuesta:** adoptarlo como regla transversal en
  `ARCHITECTURE.md` y cerrar las variantes por referencia.
- **Actualización 2026-11-06 (M5-08):** `earthflux()` no tiene defectos
  científicos: exige un preset; los presets no verificados se admiten con
  su estado declarado y un aviso (D-AP-01 reescrita).

### T-16 · Tamaño de la API pública y exportación — P0

- **IDs:** G-5.2, G-D2, ET-D11, RC-05, SH-17, D-AP-08, WF-13, GW-23.
- **Ruta propuesta:** patrón de `soil-heat-flux.md` §5.2 (funciones por
  método exportadas como API avanzada + despachador delgado), auxiliares
  internas (RC-05, `sensible-heat.md` §12), una revisión conjunta del
  tamaño de la API antes de la primera release.

### T-17 · Objetos de retorno, clases y condiciones — P0

- **IDs:** G-D3, ET-D12, RC-15, SH-17, SH-18, D-AP-10, `gwr-forcing.md` §2.4
  (`earthflux_surface`), `earthflux_result` (`ARCHITECTURE.md` §4).
- **Ruta propuesta:** diseño de clases único en M2 (`R/classes.R`), con
  listas livianas coordinadas; extender `ef_abort()` con campos opcionales
  (D-AP-10); adoptar `earthflux_calibration_error` y
  `earthflux_convergence_warning` (SH-18).

### T-18 · Escala MODIS 1 km y píxeles mixtos — P2 (evaluación) / P1 (grilla)

- **IDs:** D-AP-12 (Q-AP-01…08), G-D8, MP-08, RC-11, SH-01,
  `SCIENTIFIC_SPEC.md` §2.3.
- **Ruta propuesta:** grilla de trabajo = grilla LST nativa de 1 km (MP-08);
  documentar el sesgo como limitación y evaluarlo en M6 (G-D8, D-AP-12).

### T-19 · Desfase temporal de compuestos — P1

- **IDs:** MP-07, `soil-heat-flux.md` §7.2, Q-AP-06 (D-AP-12).
- **Ruta propuesta:** T2 (desfase por píxel registrado, flag con umbral
  `TODO`) para NDVI y LAI, T5 para albedo (MP-07); un único flag (ver T-14).

### T-20 · Elevación, datum y gradiente de Ts — P0

- **IDs:** D-AP-07, SH-13, GW-10, Q-AP-10, `sensible-heat.md` §9.1.
- **Ruta propuesta:** Γ como argumento con valor documentado y z_datum
  constante explícito de escena (SH-13; z_datum no afecta H); selección de
  anclas sobre Ts o Ts_datum configurable y registrada (D-AP-07); MDE en
  ajuste y predicción GWR (GW-10).

### T-21 · Viento: altura de mezcla, estación y superficie espacial — P0 / P1

- **IDs:** SH-04, SH-05, SH-06, SH-07, `weather-forcing.md` §7.1,
  `gwr-forcing.md` §2.3 y enmienda A4 (`method` por variable).
- **Ruta propuesta:** escalar de estación por defecto para la altura de
  mezcla; aceptar superficie espacial y registrar cuál (SH-05); sin piso de
  viento (SH-06); sin ajuste por elevación hasta verificar (SH-07).

### T-22 · Paralelismo, semillas y verificación cruzada — P1

- **IDs:** ARCH-6.3a/6.3b, `gwr-forcing.md` §6.5, `anchor-pixels.md` §5.4,
  `sensible-heat.md` §12, `evapotranspiration.md` §8.3, ARCH-6.6d, GW-15,
  `VALIDATION_PLAN.md` §1.3, antecedente lección 7.
- **Ruta propuesta:** completar `specs/parallel-processing.md` (§7) con la
  elección `future.apply`/`furrr` y una sola regla de semillas
  (`earthflux_seed_required`, `future.seed`); precisar dónde vive el script
  de verificación contra `water` (§6, ítem 10).

Otros grupos menores, sin conflicto: **diseño experimental C1–C3** (VP-2.1
= GW-21; VP-2.1b; SPEC-5.1; `weather-forcing.md` §6 punto 3) y **datos de
ejemplo** (MP-12; `DEVELOPMENT.md` §6; `weather-forcing.md` §9, licencias).

---

## 5. Registro por documento

Columnas: **ID** normalizado · **Orig.** · **Título** · **Opciones** ·
**Recomendación** (tal como en el documento) · **Estado** · **Pr.**
(prioridad) · **Dónde** (sección del documento dueño) · **Depende de /
grupo**.

### 5.1 `ARCHITECTURE.md`, `DEVELOPMENT.md`, `VALIDATION_PLAN.md`, `SCIENTIFIC_SPEC.md`

| ID | Orig. | Título | Opciones | Recomendación | Estado | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|---|---|
| ARCH-3 | — | Núcleo físico de funciones numéricas vectorizadas | Vectorial `numeric` + envoltorio ráster / funciones sobre rásteres | Vectorial; envoltorios sin reimplementar ("a confirmar en M1") | DECIDIDA (provisional, 2026-11-04) | — | ARCH §3 | D-AP-09; T-16; P0-12 |
| ARCH-4 | — | Unidad de `air_temperature` en el contrato | K / °C | `TODO: decidir K vs °C` (WF-02 propone cerrarlo) | DECIDIDA (provisional, 2026-11-04) (= WF-02) | — | ARCH §4 | = WF-02; T-09 |
| ARCH-5 | — | Paquete `units` | Adoptar / nombres + documentación + rangos | No adoptado por ahora | DECIDIDA (provisional) | — | ARCH §5 | Reevaluar en M2 |
| ARCH-6.2 | — | Backend espacial | `terra`; `sf` | `terra`; `sf` solo si se justifica | DECIDIDA 2026-11-04 | — | ARCH §6.2; DEV §4 | — |
| ARCH-6.3a | — | Paralelismo como requisito y reglas | — | Secuencial por defecto; secuencial = paralelo; sin `mclapply()`; ≤ 2 núcleos en CRAN | DECIDIDA (fecha no registrada) | — | ARCH §6.3 | T-22 |
| ARCH-6.3b | — | Mecanismo entre tareas y tipo de dependencia | `future.apply` / `furrr`; `Imports` / `Suggests` | "a decidir"; "decisión de paquete en M1" | DECIDIDA (provisional, 2026-11-04) para M3: `future.apply` en `Imports` (§1.3, M3-35) | — | ARCH §6.3; DEV §4 | §7 (`parallel-processing.md`); GW §6.5 |
| ARCH-6.5 | — | `renv` | En el paquete / en el repositorio de experimentos | No en el paquete; posible en experimentos ("no decidido") | ABIERTA | P2 | ARCH §6.5; DEV §4 | — |
| ARCH-6.6a | — | Idioma del paquete | — | `Language: en-GB` (adoptado) | DECIDIDA (fecha no registrada) | — | ARCH §6.6 | DEV-1 |
| ARCH-6.6b | — | Grupos de tests opcionales por variable de entorno | `EARTHFLUX_ONLINE_TESTS`, `EARTHFLUX_SLOW_TESTS` | "por definir" | ABIERTA | P1 | ARCH §6.6 | MP-12; GW tests lentos |
| ARCH-6.6c | — | Historias de usuario con tests de aceptación | `dev/USER_STORIES.md`, `test-story-XX.R` | "A definir en M1" | ABIERTA | P1 | ARCH §6.6 | §7 (`USER_STORIES.md`) |
| ARCH-6.6d | — | Verificación cruzada contra `water` | Fuera del tarball, solo si está instalado | Adoptado | DECIDIDA (fecha no registrada) | — | ARCH §6.6; VP §1.3 | §6 ítem 10 |
| ARCH-6.6e | — | Metadatos y workflows de publicación | `.zenodo.json`, `WORDLIST`, `pkgdown`, `release` | Con el primer release; M0/M7 | DECIDIDA (plan) | — | ARCH §6.6 | — |
| DEV-1 | — | Idiomas de documentación y código | — | `dev/` en español; público, código y commits en inglés | DECIDIDA (fecha no registrada) | — | DEV §1 | ARCH-6.6a |
| DEV-2.6 | — | Documentación automática | — | roxygen2 8.1.1 fijado; `document.yaml`, `pkgdown.yaml`, `about.yaml` | DECIDIDA (fecha no registrada) | — | DEV §2.6 | — |
| DEV-4a | — | Versión mínima de R | R ≥ 4.1.0 / otra | "Revisar antes de CRAN" | ABIERTA | P2 | DEV §4 | — |
| VP-1.2 | — | Tolerancia numérica base de los tests | ~`sqrt(.Machine$double.eps)` relativa / mayores con justificación | Propuesta; mayores solo con justificación | ABIERTA | P0 | VP §1.2 | NR §7.1; SH §14.7; ET §11.1 |
| VP-2.1 | — | Alternativa espacial de referencia (C2) | IDW; regresión global con elevación; KED; productos grillados | "Elegir y justificar en M1" | ABIERTA | P1 | VP §2.1 | = GW-21 |
| VP-2.1b | — | Mismas anclas o mismas reglas entre C1–C3 | Mismas celdas / mismas reglas | Evaluar ambas (`anchor-pixels.md` §2.4) | ABIERTA | P2 | VP §2.1; AP §2.4 | SPEC-5.1; WF §6 |
| VP-2.2 | — | Fuentes de validación y no cierre en torres EC | Sin corregir / Bowen / residuo; lisímetros; balance hídrico | `TODO (M1)` | ABIERTA | P2 | VP §2.2 | — |
| VP-2.3 | — | Métricas definitivas y CV espacial | RMSE, MAE, MBE, R², KGE, d; LOOCV / bloques | Dependen del diseño; bloques espaciales recomendados | ABIERTA | P2 | VP §2.3 | GW-20 |
| SPEC-2.4 | — | Actualizar estado de Terra/Aqua | Trasladar hechos de MP §7.1 / mantener `TODO` | "cuando el autor lo apruebe" | ABIERTA | P1 | SPEC §2.4; MP §7.1 | MP-02 |

### 5.2 `specs/ef_net_radiation.md`

| ID | Orig. | Título | Opciones | Recomendación | Estado | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|---|---|
| NR-10.1 | §10.1 | Decisiones tomadas de diseño | — | Firma, unidades, ε₀ explícita, término reflejado, NA sin flags, errores con clase | DECIDIDA (fecha no registrada) | — | §10.1 | — |
| NR-D1 | D1 | Cotas superiores de plausibilidad | Con referencia / no implementar | No implementar; requiere referencia | ABIERTA | P2 | §6, §10.2 | T-14 (`EF_RS_EXCEEDS_EXTRATERRESTRIAL`, `EF_LST_IMPLAUSIBLE`) |
| NR-D2 | D2 | Marcar Rn < 0 en escenas diurnas | Flag / sin flag | Capa de orquestación; criterio documentado | ABIERTA | P2 | §4, §10.2 | T-14 |
| NR-D3 | D3 | Número de ecuación y notación en Allen et al. (2007) | — | `TODO`; bloquea la fusión a `main` | CERRADA (2026-11-05, M2-08): forma idéntica a la Ec. 2 de Waters et al. (2002), pp. 10 y 14; Allen et al. (2007) deseable, no bloqueante | — | §2.3, §10.2 | P0-1 |
| NR-D4 | D4 | DOI de Allen et al. (2007) | — | Verificado con Crossref | CERRADA 2026-11-04 | — | §10.2; audit §8 | §6 ítem 9 |
| NR-D5 | D5 | Argumentos de longitud 0 | Error / `numeric(0)` | Rechazar (provisional) | DECIDIDA (provisional; confirmada 2026-11-04 con P0-12) | — | §3.1, §10.2 | P0-12 |
| NR-D6 | D6 | `dim` sin reciclar | — | Deben compartir `dim` (provisional) | DECIDIDA (provisional; confirmada 2026-11-04 con P0-12) | — | §3.1, §10.2 | Revisar con `SpatRaster`; P0-12 |
| NR-D7 | D7 | Función alta con Ts en lugar de `rl_out` | Ts / `rl_out` | Se decide al especificar RL↑ | ABIERTA | P0 | §10.2 | RC-14; T-10 |

### 5.3 `specs/radiation-components.md`

| ID | Orig. | Título | Opciones | Recomendación | Estado | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|---|---|
| RC-01 | RC-01 | Unidad angular del núcleo | Radianes en todo / grados en lat-lon | Radianes en todo | DECIDIDA (provisional, 2026-11-04) | — | §4.2, §9 | T-09; P0-4 |
| RC-02 | RC-02 | Convención de orientación | SIG en contrato y γ = A − π interno / γ en contrato | SIG en contrato | ABIERTA | P0 | §4.3, §9 | RC-16 |
| RC-03 | RC-03 | Tiempo y origen de la hora de paso | `doy`+`utc_hour` / `POSIXct`; *view time* medio / aparente; `solar_hour` | Numéricos; envoltorio desde `POSIXct` UTC; verificar *view time* (resuelto para MOD11A1 en MP §6.1) | DECIDIDA (provisional, 2026-11-04) en la convención (`doy`/`utc_hour` numéricos, envoltorio `POSIXct` UTC); *view time* de MOD21: MP-01 | — | §4.4, §9 | MP-01; T-02; P0-4 |
| RC-04 | RC-04 | Precisión de la geometría solar | FAO-56 / efemérides | Cuantificar error antes de decidir | ABIERTA | P0 | §6.1, §9 | — |
| RC-05 | RC-05 | Exportar auxiliares geométricas | Solo envolvente / también `ef_cos_incidence()` | Exportar solo la envolvente | ABIERTA | P0 | §9 | T-16 |
| RC-06 | RC-06 | Valor de Gsc | 1367 / ≈ 1361 | El de los coeficientes de τ | ABIERTA (regla de P0-5 adoptada provisionalmente). Evidencia 2026-11-05: el manual SEBAL de Idaho usa 1367 W m⁻² con la τ de FAO-56 Ec. 37 (p. 19, Ec. 12), es decir, el Gsc de FAO-56 redondeado: la regla se cumple para la τ por elevación; para la τ particionada (ASCE-EWRI) sigue sin verificar | P0 | §5, §9 | T-07; P0-5 |
| RC-07 | RC-07 | Valor de σ | CODATA exacto / 5.67e-8 | Exacto; tests de reproducción con tolerancia | DECIDIDA (provisional, 2026-11-04) | — | §5, §9 | T-07; WF-14; P0-5 |
| RC-08 | RC-08 | τ_sw y origen de P | Particionada ASCE / simple; P medida/GWR / P(z) | Particionada por defecto; simple en plano y sensibilidad | ABIERTA | P0 | §6.3, §9 | WF-05; T-08; discrepancia K_B (WF §10) |
| RC-09 | RC-09 | Difusa en pendiente y ρ_g | Isotrópico / anisotrópico; ρ_g píxel / vecindario | Verificar Allen et al. (2006) primero | ABIERTA | P1 (P0 si M2 incluye corrección topográfica) | §6.4, §9 | MP-03; T-11 |
| RC-10 | RC-10 | Fuente de Rs↓ | Modelada / medida + descomposición / híbrida | Modelada por defecto; híbrida para H1; coherencia con Rs de ETr | ABIERTA | P0 | §6.4, §9 | SPEC-5.1; T-01 |
| RC-11 | RC-11 | Escala de la corrección topográfica | MDE a 1 km / MDE fino y agregación | Evaluar | ABIERTA | P1 | §6.4, §9 | MP-08; T-18 |
| RC-12 | RC-12 | Temperatura para RL↓ | Ta / Ts del píxel frío / Ts por píxel | Función agnóstica; (a) y (b) configuraciones; (c) solo verificación; verificar Allen 2007 | ABIERTA (defecto del preset). Evidencia 2026-11-05: el manual SEBAL de Idaho usa (b), Ts del píxel frío (Ecs. 21 y 23) con ajuste por elevación (Ec. 12-8); Allen et al. (2012, p. 74) lo confirma para METRIC (P0-3) | P0 | §6.5.B, §9 | GW-07; SPEC-5.1; D-AP-03; T-01; P0-3 |
| RC-13 | RC-13 | Formulación de ε_a y τ de entrada | τ_sw / Brutsaert (eₐ, Ta); τ modelada / efectiva | τ_sw modelada; evaluar Brutsaert calibrado (evidencia del autor, 2023) | ABIERTA | P0 | §6.5.A, §9 | RC-12; T-01 |
| RC-14 | RC-14 | ε₀ de banda ancha y coherencia con LST | Desde LAI / producto LST / MOD21 | Preferir derivada del producto; registrar procedencia | ABIERTA | P1 | §6.6, §9 | MP-04; NR-D7; T-10 |
| RC-15 | RC-15 | Tipo de retorno | Vector / lista | Lista en `ef_rs_in_modelled()` y `ef_solar_geometry()`; vector en onda larga | ABIERTA | P0 | §9 | T-17 |
| RC-16 | RC-16 | Orientación `NA` en celdas planas | Propagar / aceptar si s = 0 | Propagar; el envoltorio del MDE asigna valor | ABIERTA | P0 | §4.6, §9 | RC-02 |
| RC-17 | RC-17 | Ubicación de `ef_air_pressure()` | `metric-radiation.R` / módulo compartido | Archivo compartido | DECIDIDA (provisional, 2026-11-04), tomada al implementar `ef_air_pressure()` (`R/shared-physics.R`) | — | §6.2, §9 | = WF-01; T-08 |

### 5.4 `specs/soil-heat-flux.md`

| ID | Orig. | Título | Opciones | Recomendación | Estado | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|---|---|
| G-5.2 | §5.2 | Diseño de API de G | A función única / B por método / C por método + despachador | Opción C ("decisión propuesta") | DECIDIDA (provisional, 2026-11-04) | — | §5.1–5.4 | T-16; P0-12 |
| G-D1 | D1 | Método por defecto en `earthflux()` | Tasumi / Bastiaanssen | Tasumi solo si se verifica; despachador sin defecto | ABIERTA | P2 | §5.4, §11 | T-15; ítems §10 |
| G-D2 | D2 | Exportar funciones por método | Sí / no | Sí, como API avanzada | ABIERTA | P0 | §5.3, §11 | T-16 |
| G-D3 | D3 | Objeto devuelto por el despachador | Lista liviana / clase | Lista con `g`, `g_rn_ratio`, `method`, `branch`, `flags`, `provenance` | DECIDIDA (provisional, 2026-11-04) (convención de `ARCHITECTURE.md` §3.2) | — | §5.4, §11 | T-17 |
| G-D4 | D4 | Superficies especiales (agua, nieve, impermeable) | Regla / flag / capa explícita | Sin regla hasta verificar; flag `EF_G_NDVI_NONPOSITIVE`. Evidencia 2026-11-05: el manual SEBAL de Idaho asigna G/Rn = 0,5 a agua (NDVI < 0) y nieve (Ts < 4 °C y α > 0,45), p. 25 y ap. 10 | ABIERTA | P0 | §3.4, §11 | Ítems 15, 16, 19 de §10 |
| G-D5 | D5 | NA en `lst` con LAI ≥ 0.5 (Tasumi) | `NA` / calcular | `NA` (conservador); confirmación del autor | ABIERTA | P0 | §6.1, §11 | — |
| G-D6 | D6 | Entradas fuera de dominio en rásteres | Error / `on_invalid` | Error por defecto; evaluar `on_invalid` | DECIDIDA (provisional, 2026-11-04): error por defecto; `on_invalid` no adoptado | — | §6.2, §11 | T-13; P0-11 |
| G-D7 | D7 | Rango plausible de G/Rn | — | Ninguno hasta referencia; flag no registrado | ABIERTA | P2 | §6.3, §11 | Ítem 18 de §10 |
| G-D8 | D8 | Escala de evaluación con MODIS | 1 km / fino y agregación | Documentar como limitación; evaluar en M6 | ABIERTA | P2 | §7.1, §11 | T-18 |
| G-D9 | D9 | Constante K → °C | 273.15 / 273.16 | 273.15 en todo el paquete | DECIDIDA (provisional, 2026-11-04) | — | §3.2, §4, §11 | T-06; P0-5 |

### 5.5 `specs/anchor-pixels.md`

| ID | Orig. | Título | Opciones | Recomendación | Estado | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|---|---|
| D-AP-01 | D-AP-01 | Valores por defecto de los criterios | Presets / ninguno | Ninguno en el núcleo; presets con `source` y `status`; **reescrita por M5-08 (2026-11-06):** `earthflux()` admite presets no verificados, con el estado declarado en su documentación y procedencia (no en el nombre) y un aviso con los elementos no verificados | DECIDIDA (provisional, 2026-11-04; reescrita 2026-11-06, M5-08) | — | §5.2, §9 | Ítems 9–14 de §8.2; T-15; P0-8; M5-08 |
| D-AP-02 | D-AP-02 | Relajación automática | Sí / plan explícito | No por defecto; plan explícito registrado | DECIDIDA (provisional, 2026-11-04) | — | §5.3, §9 | P0-8 |
| D-AP-03 | D-AP-03 | Dónde viven las condiciones de borde | Selección / función propia [B] | Función propia de la etapa [B] | DECIDIDA (provisional, 2026-11-04) | — | §1.3, §9 | SH §2.2; T-03 |
| D-AP-04 | D-AP-04 | k del ancla fría y cobertura parcial | 1.05 por defecto / explícito; Kc–NDVI | k explícito sin defecto; sin reemplazos automáticos | DECIDIDA (provisional, 2026-11-04) | — | §2.2, §9 | Ítems 1–2, 25; antecedente; T-12; P0-8 |
| D-AP-05 | D-AP-05 | LE del ancla caliente | `etrf_hot`/`le_hot` / balance hídrico | Explícitos; balance hídrico futuro | DECIDIDA (provisional, 2026-11-04) | — | §2.3, §9 | Ítem 3; P0-8 |
| D-AP-06 | D-AP-06 | Agregación de varios píxeles por tipo | Media de entradas / por píxel / otras | `aggregate` explícito; registrar dispersión | DECIDIDA (provisional, 2026-11-04) | — | §2.4, §5.3, §9 | = SH-14; Q-AP-09; T-03; P0-9 |
| D-AP-07 | D-AP-07 | Seleccionar sobre Ts o Ts,datum | Ts / Ts,datum | Configurable y registrado; evaluar en Andes | ABIERTA | P0 | §3.3.3, §9 | SH-13; T-20 |
| D-AP-08 | D-AP-08 | Exportar constructores de reglas | Exportar / listas validadas | Solo `ef_anchor_criteria()` | ABIERTA | P0 | §5.2, §9 | T-16 |
| D-AP-09 | D-AP-09 | Núcleo sobre matrices o solo `SpatRaster` | Matrices + resolución / `SpatRaster` | Matrices; envoltorio `terra` | DECIDIDA (provisional, 2026-11-04) | — | §5.3, §9 | ARCH-3; P0-12 |
| D-AP-10 | D-AP-10 | Condiciones con datos e `index` de flags | Extender `ef_abort()` / otro | Campos opcionales; `index` sobre filas de `pixels` | DECIDIDA (provisional, 2026-11-04) (`ef_abort()`/`ef_warn()` con campos opcionales) | — | §5.6, §6, §9 | T-17 |
| D-AP-11 | D-AP-11 | Radio a la estación con forzamiento GWR | Exigir / opcional | Opcional; en C3 registrar incertidumbre GWR | ABIERTA | P1 | §2.4, §9 | GW §6.3 (`EF_ANCHOR_FORCING_EXTRAPOLATED`) |
| D-AP-12 | D-AP-12 (+ Q-AP-01…10) | Estrategia MODIS 1 km | Homogeneidad estricta, subpíxel, calibración cruzada, sensibilidad | Ninguna decidida; evaluar en M6 | ABIERTA | P2 | §4, §9 | T-18; T-19; VP-2.1b |

### 5.6 `specs/sensible-heat.md`

Todas `ABIERTA`, P0 (bloquean la calibración de dT y H en M2) a la fecha
de corte; las adoptadas provisionalmente el 2026-11-04 (§1.0) se marcan en
la columna Recomendación.

| ID | Título | Opciones | Recomendación | Dónde | Depende de / grupo |
|---|---|---|---|---|---|
| SH-01 | Método de z_om por defecto con MODIS 1 km | LAI lineal / custom / Perrier / tabla por cobertura | LAI lineal como base; tabla cuando exista fuente; Perrier con mapa de alturas | §5, §18 | T-15; T-18 |
| SH-02 | Mínimo de z_om | 0.005 m con flag / no aplicar | Aplicar con flag, tras verificar p. 386. *2026-11-06:* aplicado con `EF_H_ZOM_FLOOR_APPLIED` en los presets de `earthflux()` (M5-24), valor `CANDIDATA`; el núcleo sigue sin mínimo | §5.6 | — |
| SH-03 | Ajuste por terreno de z_om | Sin ajuste / factor / factor con mínimo 1 | Desactivado hasta verificar Eq. 35. Evidencia 2026-11-05: z_om·[1 + (pendiente_grados − 5)/20] para pendiente ≥ 5° (Waters et al., 2002, Ec. 12-9; Allen et al., 2012, p. 74); no implementado | §5.7 | — |
| SH-04 | Perfil de la estación | d_w = 0 / d_w y z_om,w desde h (FAO-56) | Argumentos explícitos; defecto FAO-56 (h = 0.12 m) | §6.1 | T-21 |
| SH-05 | u_b uniforme vs espacial | Escalar / superficie GWR | Aceptar ambos; registrar cuál | §6.1 | T-21; GW enmienda A4 |
| SH-06 | Viento bajo | Sin piso + flag / piso explícito | Sin piso por defecto | §6.2 | T-21 |
| SH-07 | Ajuste del viento por elevación | No / con z_w / con datum | No implementar hasta verificar. Evidencia 2026-11-05: ϖ = 1 + 0,1·(z − z_estación)/1000 sobre u₂₀₀ (Waters et al., 2002, Ec. 12-10; Allen et al., 2012, p. 74); no implementado | §6.3 | T-21 |
| SH-08 | Forma y temperatura de ρ_air; 273 vs 273.15 | §8.1 con T_a / §8.2 / con Ts | §8.1 con T_a y P de `ef_air_pressure()` o medida → **DECIDIDA (provisional, 2026-11-04)** | §8 | T-06; T-08; P0-6 |
| SH-09 | c_p | 1004 / 1013 | **CERRADA (2026-11-05, M2-08):** 1004 J kg⁻¹ K⁻¹, `VERIFICADA (SEBAL-Idaho 2002)` (Waters et al., 2002, p. 25 y p. 32); `EF_SPECIFIC_HEAT_AIR` y defecto de `cp` en `ef_sensible_heat()` (M2-09) | §8.3 | T-04; P0-6 |
| SH-10 | T, ρ y g en L | Ts / T_a; ρ inicial / iterada; 9.807 / otro | **DECIDIDA (2026-11-05, M2-10; revisa la provisional del 2026-11-04):** Ts, ρ de la iteración y g = 9,81 (`EF_GRAVITY`), `VERIFICADA (SEBAL-Idaho 2002)` (p. 32, Ec. 34) | §10.1 | P0-6 |
| SH-11 | Altura de ψ_m estable en z_b | 2/L / 200/L | **CERRADA (2026-11-05, M2-09):** 2/L, Waters et al. (2002), p. 33, Ec. 38; defecto `stable_psi_m_height = 2`. Hallazgo M2 (§1.2, M2-07): con ancla fría estable, 200/L diverge y 2/L converge | §10.3 | P0-2 |
| SH-12 | Notación de a y b | SPEC / artículo | Mantener SPEC salvo que el artículo difiera. Evidencia 2026-11-05: el manual SEBAL de Idaho escribe dT = b + a·Ts (a = pendiente), como `water`; decisión del autor | §4.2 | `water` invierte a ↔ b |
| SH-13 | Γ y z_datum | 6.49 K km⁻¹ fijo / argumento; z_datum estación / escena | Γ argumento documentado; z_datum constante explícito. Evidencia 2026-11-05: forma `VERIFICADA (SEBAL-Idaho 2002)` (Ec. 12-7, Γ = 0,0065 K m⁻¹, datum en la estación); METRIC ajusta Γ a la escena con doble tasa en montaña (Allen et al., 2012, p. 74): Γ sigue sin defecto por diseño | §9.1 | D-AP-07; T-20 |
| SH-14 | Agregación de varias anclas | Promedio entradas / dT / por par / regresión | Coordinar con anclas; caso base 1 valor por clase → **DECIDIDA (provisional, 2026-11-04)** | §2.3 | = D-AP-06; T-03; P0-9 |
| SH-15 | Estrategia de Fase B | Estrategia P1 (`water`) / estrategia P2 | Estrategia P2; P1 solo verificación → **DECIDIDA (provisional, 2026-11-04)** | §11.7 | P0-10 |
| SH-16 | `tol`, `maxit`, ω; criterio por ancla o promedio | — | 0.01, 20, 0, por ancla; reportar Δa, Δb → **DECIDIDA (provisional, 2026-11-04)**; *revisada por M2-11 (2026-11-10):* una tolerancia por fase, `tol` = 10⁻⁶ y `maxit` = 100 por ancla, `pixel_tol` = 10⁻⁵ y `pixel_maxit` = 100 por píxel, ω = 0 | §11.3–11.5 | T-15; P0-10; M2-11 |
| SH-17 | Driver exportado o interno; auxiliares | — | Driver exportado; auxiliares internas → **DECIDIDA (provisional, 2026-11-04)** | §12 | T-16; T-17; P0-10 |
| SH-18 | Clases de condición nuevas | `earthflux_calibration_error`, `earthflux_convergence_warning` | Adoptar → **DECIDIDA (provisional, 2026-11-04)** | §13 | T-17 |
| SH-19 | Estado inicial | dT₀ = 0 / otro | dT₀ = 0, documentado → **DECIDIDA (provisional, 2026-11-04)** | §11.2 | P0-6 |
| SH-20 | Ts_datum > Ts_datum,hot | Misma recta + flag / pendiente reducida | Misma recta + flag hasta verificar p. 389 | §9.4 | — |

### 5.7 `specs/evapotranspiration.md`

| ID | Título | Opciones | Recomendación | Estado | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|---|
| ET-D1 | λ por defecto y temperatura (aire/superficie) | `"constant"` / `"fao56"` / `"metric"` | `"constant"` hasta V2; luego evaluar `"metric"`; bajo nivel sin defecto | DECIDIDA (provisional, 2026-11-04) | — | §4.5, §13 | T-05; T-15; P0-7 |
| ET-D2 | Guarda de unidades de λ | [10⁶, 10⁷] J kg⁻¹ / ninguna | Adoptar como control de unidades | DECIDIDA (provisional, 2026-11-04) | — | §13 | P0-7 |
| ET-D3 | ρ_w constante o argumento | Constante / argumento | Constante interna `EF_WATER_DENSITY` | DECIDIDA (provisional, 2026-11-04) (`EF_WATER_DENSITY`, regla de P0-5) | — | §4.4, §13 | — |
| ET-D4 | Flag de LE negativo | `EF_LE_NEGATIVE` / reutilizar `EF_ET_NEGATIVE` | Código nuevo | ABIERTA | P0 | §7.2, §13 | T-14 |
| ET-D5 | Rango plausible de ETrF | — | Ninguno hasta V7 | ABIERTA | P2 | §7.3, §13 | T-12 |
| ET-D6 | `etr_inst` ≤ 0 y `etr_24` < 0 | Error / `NA` + flag | Error de dominio | DECIDIDA (provisional, 2026-11-04) | — | §9.3, §13 | T-13; P0-11 |
| ET-D7 | C_rad | Reservar / implementar | Reservar `c_rad`; implementar tras V6 | ABIERTA | P2 | §6.3, §13 | Radiación en pendientes |
| ET-D8 | Extrapolación alternativa | ETrF / fracción evaporativa / otros | Solo ETrF en M2; alternativas separadas | ABIERTA | P2 | §6.6, §13 | V14 |
| ET-D9 | Comprobación del tipo de referencia | Orquestación / funciones | Orquestación; `earthflux_reference_mismatch` | ABIERTA | P1 | §6.4, §13 | T-12 |
| ET-D10 | ET de período: método, extrapolación, huecos | — | `method` obligatorio; `extrapolation = "none"`; spline < 3 fechas → error | ABIERTA | P2 | §8, §13 | V8 |
| ET-D11 | Exportar las seis funciones | Sí / no | Sí; la inversa interna | ABIERTA | P0 | §9.1, §13 | T-16 |
| ET-D12 | Salida de `ef_et_period()` | — | Lista liviana coordinada con `earthflux_result` | DECIDIDA (provisional, 2026-11-04) (convención de `ARCHITECTURE.md` §3.2) | — | §8.3, §13 | T-17 |
| ET-D13 | Archivos de test | — | `test-latent-heat.R`, `test-et.R`, `test-et-period.R` | ABIERTA | P0 | §13 | SPEC §3 (`test-pipeline.R`) |
| ET-D14 | Variable interpolada entre imágenes | ETrF / ETa | ETrF | ABIERTA | P2 | §8.1, §13 | V8 |
| ET-D15 | Lluvia o riego entre imágenes | — | Sin corrección; limitación documentada | ABIERTA | P2 | §8.4, §13 | V8 |
| ET-D16 | Definición del "día" de ETr_24 | — | Delegada a forzamiento | ABIERTA | P1 | §1.3, §13 | = WF-11; T-02 |

### 5.8 `specs/weather-forcing.md` y decisión 5.1 de `SCIENTIFIC_SPEC.md`

Todas `ABIERTA` a la fecha de corte; las adoptadas provisionalmente el
2026-11-04 (§1.0) se marcan en la columna Recomendación.

| ID | Título | Opciones | Recomendación | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|
| WF-01 | Ubicación de funciones compartidas y tests | Archivo atmosférico compartido / `prep-weather.R` | Archivo compartido; test propio de ET de referencia → **DECIDIDA (provisional, 2026-11-04)**, tomada al implementar `ef_air_pressure()` (`R/shared-physics.R`) | — | §4, §11 | = RC-17; T-08 |
| WF-02 | Unidad de temperatura del aire | °C en `forcing` y referencia, K en radiación / K en todo | °C en `forcing` y ET de referencia; conversión a K en la frontera → **DECIDIDA (provisional, 2026-11-04)** | — | §2, §4, §11 | = ARCH-4; T-09; P0-4 |
| WF-03 | Representación de la tabla de estaciones | Dos tablas + clase / tabla ancha / `terra::vect` | Dos tablas + clase S3 → **DECIDIDA (provisional, 2026-11-04)**, M3-07 | — | §2, §11 | — |
| WF-04 | Valores imposibles en `observations` | Error / flag + exclusión | Flag; error solo en metadatos → **DECIDIDA (provisional, 2026-11-04)**, M3-08 | — | §2.6, §3, §11 | T-13 |
| WF-05 | Origen de P | P(z) para ETr; P medida/GWR para τ_sw | P(z) en ETr; registrar mezcla | P1 | §4.1, §11 | RC-08; T-08 |
| WF-06 | Umbrales con intervalo publicado | δ ∈ [3, 5] %; HRmax ∈ [80, 90] % | Parámetros sin defecto hasta decidir | P1 | §3, §11 | — |
| WF-07 | Prefijos de flags | `EF_WS_*` / nombres de RC | Unificar antes de registrar | P1 | §3, §11 | T-14 |
| WF-08 | Corrección por aridez (FAO-56 Anexo 6) | No aplicar / configuración explícita | No por defecto; sensibilidad | P1 | §3, §6, §9, §11 | — |
| WF-09 | ETr instantánea a la hora de paso | O1–O5 | O3 por defecto; O2/O4 en sensibilidad (M3: O1 y O3 como argumento sin defecto, M3-16) | P1 | §5.5, §11 | T-02; T-01 |
| WF-10 | Ra horaria en amanecer/atardecer; constante de longitud | Punto medio / recorte de ω; 0.06667 / 1/15 | 1/15 exacto; recorte solo si se verifica (M3: recorte de la Ec. 56 de ASCE verificado y elegido con `standard`, M3-01b) | P1 | §4.6, §11 | — |
| WF-11 | Día de ETr24 y huecos | Local estándar / UTC | Argumento explícito; local estándar si se verifica; sin relleno (M3: ambos como argumento sin defecto, `"all_periods"`, M3-17; abierta A-1) | P1 | §5.6, §11 | = ET-D16; T-02 |
| WF-12 | Rso de la referencia | Ec. 37 / Anexo 3 | Ec. 37; variantes solo para QC | P1 | §4.7, §11 | — |
| WF-13 | API de ET de referencia | Una función / alias | Una función exportada → **DECIDIDA (provisional, 2026-11-04)**: `ef_ref_et()` más `ef_ref_net_radiation()` y `ef_ref_soil_heat_flux()` exportadas, M3-03 | — | §5.4, §11 | T-16 |
| WF-14 | Constantes de la norma vs del paquete | Literales de la norma / constantes del paquete | Literales de la norma dentro de funciones de referencia → **DECIDIDA (provisional, 2026-11-04)** | — | §4.8, §11 | T-06; T-07 |
| WF-15 | Criterio día/noche para G y Cd horarios | Rn > 0 / Ra > 0 / ángulo solar | Pendiente de ASCE-EWRI (M3: Ra > 0 y Rn > 0 como argumento sin defecto, M3-15; Rn > 0 `VERIFICADA` para ASCE, M3-01d) | P1 | §4.9, §5.3, §11 | — |
| WF-16 | ETr24: suma horaria vs ecuación diaria | Opción D1 / opción D2 | D1 (coherencia con ETr_inst) (M3: D1 con registros horarios, D2 solo con registros diarios, M3-13, M3-17) | P1 | §5.6, §11 | T-02 |
| SPEC-5.1 | Interpolar-calcular vs calcular-interpolar | A / B / C | Soportar A y C; C candidata; decidir con CV | P1 | SPEC §5; WF §6, §11 | T-01; GW §2.1 |

### 5.9 `specs/gwr-forcing.md`

| ID | Título | Opciones | Recomendación | Estado | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|---|
| GW-01 | Backend de GWR | — | Núcleo interno; `GWmodel` en `Suggests`; `spgwr` descartado | CERRADA 2026-11-04 | — | §1.2, §13 | = BK-1…3 |
| GW-02 | Expresión de AICc | §4.1 / otra tras V1–V2 | §4.1 | DECIDIDA (provisional, 2026-11-04), M3-21 | — | §4.1, §13 | — |
| GW-03 | Convenciones del kernel | k incluye el punto; boxcar d ≤ b | Incluye; d ≤ b | DECIDIDA (provisional, 2026-11-04), M3-21 | — | §3.4–3.5, §13 | — |
| GW-04 | Kernel por defecto en `api` | Sin defecto / bicuadrado / gaussiano | Sin defecto en el núcleo; el de `api` con evidencia de CV | ABIERTA | P1 | §5.5, §13 | T-15 |
| GW-05 | Criterio y búsqueda por defecto | AICc / CV | AICc; valores de búsqueda como convenciones | ABIERTA | P1 | §4.4, §13 | T-15 |
| GW-06 | `min_neighbours`, `n_min`, `kappa_max` | Mínimo matemático / con referencia | Mínimo matemático; umbrales sin defecto | ABIERTA (hallazgo M3-26; abierta A-3) | P1 | §4.5, §13 | Pregunta 4 de `gwr-backend.md` §8 |
| GW-07 | Covariables de superficie (LST, NDVI/EVI) | (a) excluir / (b) con flag y sensibilidad / (c) LST de otro instante | (b) disponible; defecto (a) hasta el experimento C3 con y sin LST | ABIERTA (evidencia del autor 2023 registrada; M3: argumento `surface_covariates` sin defecto, M3-29) | P1 | §2.7, §13 | RC-12; T-01 |
| GW-08 | Modo grueso | No / coeficientes interpolados / predicción remuestreada | Coeficientes interpolados, opcional | ABIERTA (M3: no implementado, M3-30) | P1 | §6.2, §13 | Pregunta 3 de `gwr-backend.md` §8 |
| GW-09 | Métrica de distancia | Euclidiana / gran círculo | Euclidiana proyectada | ABIERTA | P1 | §3.3, §13 | — |
| GW-10 | Elevación en estaciones | Metadatos / MDE | MDE en ajuste y predicción | ABIERTA | P1 | §2.2, §13 | T-20 |
| GW-11 | Bandwidth por ajuste o por variable | Por (variable, tiempo) / por variable / por período | Por ajuste; evaluar en M6 | ABIERTA | P1 | §5.5, §13 | — |
| GW-12 | Transformaciones | Identidad / log, raíz | Solo identidad | ABIERTA | P1 | §2.3, §13 | — |
| GW-13 | R² local | Ajuste local / variantes | Ajuste local | ABIERTA | P1 | §3.8, §13 | — |
| GW-14 | Codificación de flags ráster | Bits / capas lógicas | Bits (enmienda A1) | ABIERTA | P1 | §2.4, §13 | T-14 |
| GW-15 | Referencia cruzada | — | Solo `GWmodel`, `Suggests` | CERRADA 2026-11-04 | — | §13 | = BK-3 |
| GW-16 | MGWR | Fuera de alcance / `mgwrsar` | Diferido; `mgwrsar` si se requiere | DECIDIDA 2026-11-04 | — | §13 | = BK-4 |
| GW-17 | Atípicos entre estaciones | Sobre valores / sobre residuos | QC en `forcing` sobre residuos de la regresión global; parámetros sin defecto | ABIERTA | P1 | §1.4, §2.1, §13 | Antecedente (IQR) |
| GW-18 | I de Moran | No / descriptivo / permutación | Descriptivo tras leer la fuente | ABIERTA | P2 | §7.3, §13 | — |
| GW-19 | Incertidumbre de predicción | Omitida / varianza GWR / CV | Omitida en la primera versión | ABIERTA | P2 | §2.4, §13 | — |
| GW-20 | CV por bloques | Teselas / pliegues del usuario / agrupamiento | Teselas; L justificado | ABIERTA (M3: teselas implementadas, L del usuario, M3-36) | P1 | §8.2, §13 | VP-2.3 |
| GW-21 | Alternativa C2 principal | OLS / IDW / KED / reanálisis | OLS e IDW requeridos | ABIERTA | P1 | §5, §13 | = VP-2.1 |
| GW-22 | Ubicación de las alternativas | `gwr-*.R` / archivo propio | Archivo propio | DECIDIDA (provisional, 2026-11-04), M3-33 | — | §9, §13 | — |
| GW-23 | Nombres de la API | `ef_regionalize()` / `ef_spatial_forcing()` | A decidir; `ef_gwr_*()` para el núcleo | DECIDIDA (provisional, 2026-11-04): `ef_regionalize()`, `ef_gwr_*()`, sin `ef_gwr_config()` ni `ef_spatial_forcing()`, M3-27 | — | §9, §13 | T-16 |

### 5.10 `specs/modis-products.md`

Todas `ABIERTA` salvo MP-10, MP-11 y MP-13, adoptadas provisionalmente al
implementar M4 (§1.4), y MP-06 y MP-12, decididas por el autor el
2026-11-04 (§1.4, M4-27, M4-28).

| ID | Título | Opciones | Recomendación | Pr. | Dónde | Depende de / grupo |
|---|---|---|---|---|---|---|
| MP-01 | Producto LST | MOD11A1/MYD11A1 / MOD21A1D/MYD21A1D | MOD11A1 por defecto; MOD21A1D cuando se resuelva §6.4 | P1 | §5.1–5.2, §15 | RC-03; T-02 |
| MP-02 | Plataforma | Terra / Aqua / ambas | Configurable; registrar; considerar deriva | P1 | §7, §15 | SPEC-2.4 |
| MP-03 | Albedo | A1–A6 | A1 si se resuelve la circularidad; si no, A2/A3 | P1 | §8.1, §15 | RC-09; T-11 |
| MP-04 | Emisividad de banda ancha | E1–E4 | Vinculada a RC-14; preferir E1/E2 | P1 | §8.2, §15 | RC-14; T-10 |
| MP-05 | Fuente de NDVI | MOD13A2 / MOD13Q1 agregado / MOD09GA/GQ | MOD13A2 + desfase por píxel (T2) | P1 | §15 | MP-07 |
| MP-06 | LAI y clases no vegetadas | `NA` + flag / asignación explícita / empírico | `NA` + flag por defecto; DECIDIDA (autor, 2026-11-04): `NA` + flag por defecto y asignación explícita como opción `lai_nonveg` (un valor o uno por clase) con `EF_SURF_LAI_ASSIGNED`, M4-28, M4-29 | P1 | §5.7, §15 | G (Tasumi usa LAI) |
| MP-07 | Desfase temporal | T1–T5 | T2 (NDVI/LAI), T5 (albedo) | P1 | §9.1, §15 | T-19 |
| MP-08 | Grilla y remuestreo | LST 1 km sinusoidal / otra | Grilla LST nativa; agregación por factor entero | P1 | §9.2, §15 | T-18 |
| MP-09 | Política QA por defecto | `"flag"` / `"mask"` | `"flag"`; anclas con filtro estricto | P1 | §10.3, §15 | D-AP-01 (QA de anclas `TODO`) |
| MP-10 | Formatos de entrada | Solo HDF4 / HDF4 + convertidos | HDF4 + convertidos con declaración; DECIDIDA (provisional, 2026-11-04): HDF4 + convertidos con `scaled` obligatorio, M4-06 | P1 | §11, §15 | — |
| MP-11 | Escala/offset | GDAL / ficha interna | Ficha interna; DECIDIDA (provisional, 2026-11-04): ficha interna, `raw = TRUE`, M4-02 | P1 | §11.3, §15 | — |
| MP-12 | Datos de ejemplo | AOI, fecha, productos | **AOI decidido por el autor (2026-11-04): provincia de Cauquenes, Región del Maule**, el área de estudio habitual del autor (también en `thermify`). Límite y script de la escena listos (M4-26); DECIDIDA (autor, 2026-11-04): fecha **2019-02-15**, Terra, tesela h12v12 (3 % de nubosidad), M4-27 | P1 | §12, §15 | ARCH-6.6b; DEV §6 |
| MP-13 | Migración a C7 de tierra | Esperar / ambas | Fichas por colección; C6.1 por ahora; DECIDIDA (provisional, 2026-11-04): solo 061, M4-01 | P2 | §3, §15 | — |
| MP-14 | Continuidad | VIIRS / Landsat / Sentinel-3 | Módulo de sensor separado; fuera de M4 | P2 | §7.3, §15 | — |

### 5.11 `decisions/gwr-backend.md`

Ver sección 3 (BK-1 … BK-4, `DECIDIDA` 2026-11-04). Las preguntas 3 y 4
de §8 siguen abiertas como GW-08 y GW-06.

---

## 6. Inconsistencias documentales detectadas (sincronización pendiente)

No son decisiones nuevas: son textos que contradicen decisiones ya
registradas o entre sí. Se corrigen en el documento dueño (no aquí).

1. `DEVELOPMENT.md` §4: "Backend GWR — Decisión abierta", frente a
   `ARCHITECTURE.md` §6.1 "DECIDIDO (2026-11-04)" (`gwr-forcing.md` §15
   pide registrarlo en `DEVELOPMENT.md` §4).
2. `SCIENTIFIC_SPEC.md` §6: "Backend: decisión abierta"; §0 indica
   `specs/gwr-forcing.md` "(en curso)", aunque el documento existe.
3. `decisions/gwr-backend.md`: estado `DECIDIDA`, pero el párrafo inicial
   dice "No es una decisión tomada", y §0/§8.4 proponen `spgwr` como
   "segunda referencia ligera opcional", sustituido por BK-1.
4. `SCIENTIFIC_SPEC.md` §0 atribuye "WF-07 (ETr en la hora de paso)"; en
   `weather-forcing.md` §11, WF-07 es "Prefijos de flags" y la ETr a la hora
   de paso es **WF-09**.
5. `radiation-components.md` §6.5.B (RC-12, opción (a)): "GWR = C2";
   `VALIDATION_PLAN.md` §2.1: **C3 = GWR** (C2 = alternativa de referencia).
6. `anchor-pixels.md` §2.1 indica que la fila ET_inst de `SCIENTIFIC_SPEC.md`
   §3 omite el factor 1000; esa fila ya fue corregida (2026-11-04).
7. Nombres del tipo de referencia: `"ETr"`/`"ETo"` en `anchor-pixels.md` §2.4
   frente a `"alfalfa"`/`"grass"` en `weather-forcing.md` §5.4 y
   `evapotranspiration.md` §1.3 (T-12).
8. `radiation-components.md` §5 mantiene `TODO: verify equation number` para
   P(z); `sensible-heat.md` §4.3, `weather-forcing.md` §10 y
   `SCIENTIFIC_SPEC.md` §0 la dan como FAO-56 Ec. 7 `VERIFICADA`.
9. `ef_net_radiation.md` §2.2 y §2.3 conservan `TODO: confirmar DOI`, aunque
   NR-D4 está cerrada (`verification/reference-audit.md` §8).
10. `VALIDATION_PLAN.md` §1.3, `ARCHITECTURE.md` §6.6 y `gwr-backend.md`
    §8.4 sitúan la verificación contra paquetes GPL "fuera del tarball" con
    el patrón `inst/verification/`; el contenido de `inst/` forma parte del
    paquete fuente salvo exclusión en `.Rbuildignore`. Precisar la
    ubicación (ARCH-6.6d).
11. `decisions/antecedente-metric-modis.md` §2, lección 7, remite a
    `parallel-processing.md`, que aún no existe (§7).
12. `SCIENTIFIC_SPEC.md` §3 menciona `test-pipeline.R` para LE;
    `evapotranspiration.md` propone `test-latent-heat.R` (ET-D13).

---

## 7. Pendientes de incorporar (documentos en redacción)

### 7.1 `dev/specs/parallel-processing.md` — *pendiente*

Documento en redacción; no presente a la fecha de corte. Al incorporarse,
registrar aquí sus decisiones (prefijo propuesto `PP-xx`) y revisar:

- ARCH-6.3b (`future.apply` frente a `furrr`; `Imports` frente a `Suggests`).
  *Nota M3 (2026-11-04):* el documento ya existe (IDs `P-01` … `P-12` y
  `D-PP-xx`); ARCH-6.3b quedó resuelta para M3 (§1.3, M3-35) y D-PP-05
  sigue abierta (M3-34). Su incorporación completa a este registro sigue
  pendiente.
- Coherencia con ARCH-6.3a (reglas ya decididas), `gwr-forcing.md` §6.5,
  `anchor-pixels.md` §5.4 (semillas), `sensible-heat.md` §12 (Fase B por
  bloques), `evapotranspiration.md` §8.3 y el grupo T-22.

### 7.2 `dev/USER_STORIES.md` — *pendiente*

Documento en redacción; no presente a la fecha de corte. Al incorporarse,
registrar aquí sus decisiones (prefijo propuesto `US-xx`), cerrar o
actualizar ARCH-6.6c y vincular cada historia con las decisiones P0/P1 que
la bloquean.

---

## 8. Mantenimiento

- Al tomar una decisión: actualizar el documento dueño (estado, fecha y
  fundamento), luego la fila correspondiente aquí y, si pertenece a un
  grupo, la sección 4.
- Al crear un documento nuevo con decisiones: usar IDs con prefijo propio
  (sección 0.3) para evitar nuevas colisiones.
- Este registro no contiene ecuaciones ni valores nuevos; cualquier valor
  citado proviene del documento indicado.
