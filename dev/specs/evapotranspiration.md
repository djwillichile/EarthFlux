# EarthFlux — Especificación: flujo de calor latente, ET instantánea, ETrF y extrapolación temporal

Estado: **borrador M1** · Componente: `metric` · Archivos de destino:
`R/metric-latent-heat.R` (LE), `R/metric-et.R` (λ, ET_inst, ETrF, ETa
diaria y de período) · Tests: `tests/testthat/test-latent-heat.R`,
`tests/testthat/test-et.R`, `tests/testthat/test-et-period.R` (nombres a
confirmar, decisión ET-D13).

> Este documento detalla las filas **LE, ET_inst, ETr, ETrF y ETa** de la
> tabla de variables de `SCIENTIFIC_SPEC.md` (§3) y la fila *Extrapolación
> diaria* de §1.2. `SCIENTIFIC_SPEC.md` sigue siendo la fuente de verdad
> científica: cuando una formulación de este documento pase a `VERIFICADA`,
> su estado, referencia y caso numérico deben trasladarse allí. Sigue la
> *Definition of Done* de `DEVELOPMENT.md` §3 y las convenciones de
> `dev/specs/ef_net_radiation.md` (errores con clase, reciclaje, NA).

Convención de estados: la misma de `SCIENTIFIC_SPEC.md` (`TODO`,
`CANDIDATA`, `VERIFICADA`). Aquí `VERIFICADA` significa **contrastada en la
fuente primaria durante la redacción de este documento**, con la ubicación
exacta indicada (capítulo, recuadro, ecuación, tabla o página).

> **Estado de implementación (M2, 2026-11-04).** Implementadas:
> `ef_latent_heat()` (`R/metric-latent-heat.R`), `ef_et_inst()`,
> `ef_etrf()`, el despachador `ef_et_daily(method = )` con su único método
> `"etrf"` (`ef_et_daily_etrf()`), la inversa interna
> `ef_et_inst_to_latent_heat()` y el diagnóstico interno `ef_diagnose_et()`
> (`R/metric-et.R`); tests en `tests/testthat/test-latent-heat.R` y
> `tests/testthat/test-et.R` (ET-D13). No implementadas (posteriores u
> opcionales): `ef_et_daily_evapfrac()` (ET-D8) y `ef_et_period()` (§8).
> Decisiones tomadas al implementar: ver §14.1.

---

## 0. Resumen

| Magnitud | Ecuación (notación propia) | Estado | Evidencia | Función |
|---|---|---|---|---|
| Flujo de calor latente | LE = Rn − G − H | **`VERIFICADA`** como balance de energía (FAO-56, cap. 1, Ec. 1, reordenada). Número de ecuación en Allen et al. (2007): `TODO` | §3 | `ef_latent_heat()` |
| Calor latente de vaporización, constante | λ = 2.45 MJ kg⁻¹ (≈ 20 °C) | **`VERIFICADA`** (FAO-56, cap. 3 y anexo 3) | §4.1 | `ef_lambda(method = "constant")` |
| λ dependiente de la temperatura del aire | λ = 2.501 − 2.361 × 10⁻³·T [MJ kg⁻¹], T en °C | **`VERIFICADA`** como ecuación de FAO-56 (anexo 3, Ec. 3-1). Su uso en METRIC: no aplica (ver fila siguiente) | §4.2 | `method = "fao56"` |
| λ dependiente de Ts, forma METRIC | λ = 2.501 − 0.00236·(Ts − 273.15) [MJ kg⁻¹] | `CANDIDATA` (paquete `water` v1.0; número de ecuación atribuido por notas terciarias) | §4.3 | `method = "metric"` |
| Densidad del agua | ρ_w = 1000 kg m⁻³ | **`VERIFICADA`** (FAO-56, cap. 3, recuadro 8; cap. 1, nota de la tabla 1) | §4.4 | constante interna |
| Conversión energía → lámina | lámina [m] = energía por área [J m⁻²] / (λ·ρ_w) | **`VERIFICADA`** (FAO-56, cap. 3, recuadro 8 y Ec. 20) | §5 | — |
| ET instantánea | ET_inst = 1000·3600·LE / (λ·ρ_w) [mm h⁻¹] | **`VERIFICADA`** como conversión de unidades (FAO-56, recuadro 8, + 3600 s h⁻¹). Notación METRIC "3600·LE/(λ·ρ_w)": `CANDIDATA (corroborada)`, con observación dimensional (§5.2) | §5, §6.1 | `ef_et_inst()` |
| Fracción de ET de referencia | ETrF = ET_inst / ETr_inst | `CANDIDATA (corroborada)` | §6.2 | `ef_etrf()` |
| ETa diaria | ETa_24 = ETrF · ETr_24 | `CANDIDATA (corroborada)` | §6.3 | `ef_et_daily_etrf()` |
| Corrección por pendiente de ETa_24 | ETa_24 = C_rad · ETrF · ETr_24 | `CANDIDATA` (una fuente secundaria; número de ecuación contradictorio) | §6.3 | decisión ET-D7 |
| ET de período | ET_per = Σ_d ETrF_d · ETr_24,d con ETrF_d interpolada | `CANDIDATA` (una fuente secundaria) | §8 | `ef_et_period()` (posterior, opcional) |
| Rango plausible de ETrF | — | `TODO` (indicio terciario) | §7 | flag no registrado |

Hallazgo dimensional (§5.2): la fila ET_inst de `SCIENTIFIC_SPEC.md` §3
escribe `ET_inst = 3600·LE / (λ·ρ_w)` con unidad mm h⁻¹. Con λ en J kg⁻¹ y
ρ_w en kg m⁻³, esa expresión da **m h⁻¹**; para mm h⁻¹ falta el factor
1000 mm m⁻¹. Numéricamente, con ρ_w = 1000 kg m⁻³, `1000·3600·LE/(λ·ρ_w) =
3600·LE/λ`. Debe corregirse la fila de `SCIENTIFIC_SPEC.md` cuando se
fusione esta especificación (ítem V3, §12).

---

## 1. Alcance, definiciones e interfaz con otros módulos

### 1.1 Definiciones

- **LE**: flujo de calor latente **instantáneo a la hora de paso** del
  satélite, en W m⁻², positivo cuando la superficie pierde energía por
  evaporación (convención de FAO-56, cap. 1, Ec. 1; §3.1).
- **ET_inst**: tasa de evapotranspiración instantánea expresada como lámina
  por hora, en mm h⁻¹. Es una **tasa** evaluada en un instante, no una
  lámina acumulada durante una hora.
- **ETr_inst**: ET de referencia a la hora de paso, en mm h⁻¹ (entregada
  por el módulo de forzamiento, §1.3).
- **ETrF**: fracción de ET de referencia, adimensional. Está definida
  **respecto de un cultivo de referencia concreto** (alfalfa alta, `ETr`, o
  pasto corto, `ETo`); una ETrF con base alfalfa no es comparable con una
  con base pasto (§6.4).
- **ETr_24**: ET de referencia acumulada en el día de la imagen, en mm d⁻¹.
- **ETa_24**: ET real diaria, en mm d⁻¹.
- **ET_per**: ET real acumulada en un período (varios días), en mm.

### 1.2 Fuera de alcance

- Cálculo de Rn, G y H (especificaciones `ef_net_radiation.md`,
  `soil-heat-flux.md` y futuras de H).
- Cálculo de ETr_inst y ETr_24 (especificación de forzamiento meteorológico,
  en redacción paralela). Aquí solo se define la **interfaz** que este
  módulo necesita (§1.3).
- Cálculo de C_rad (módulo de radiación, si se adopta; decisión ET-D7).
- Radiación neta diaria Rn_24 (solo necesaria para la alternativa de
  fracción evaporativa, §6.6).
- Conversión de ETrF a coeficiente de cultivo con base pasto (§6.4, solo
  como nota).

### 1.3 Interfaz requerida al módulo de forzamiento (ET de referencia)

Contrato mínimo; los nombres `etr_inst` y `etr_24` ya figuran en
`ARCHITECTURE.md` §4 (forzamiento meteorológico). El método de cálculo de la
ET de referencia (ASCE-EWRI, FAO-56, horario/diario) lo define la
especificación de forzamiento, no esta.

| Elemento | Unidad | Forma | Requisito para este módulo |
|---|---|---|---|
| `etr_inst` | mm h⁻¹ | escalar (estación única) o vector/ráster por píxel (GWR; hora de paso por píxel, `SCIENTIFIC_SPEC.md` §2.4) | Finita y > 0 donde no es `NA` (§9.3). Debe referirse **al mismo instante** que LE (hora de paso del píxel). La base temporal (tasa instantánea vs. ET horaria de un período centrado en la hora de paso) debe quedar documentada en la procedencia (ítem V5) |
| `etr_24` | mm d⁻¹ | escalar o vector/ráster por píxel | Finita y ≥ 0 donde no es `NA`. "Día" definido por la especificación de forzamiento (día local; `TODO` allí) |
| Serie diaria de ETr_24 (solo para ET de período, §8) | mm d⁻¹ | vector por día (estación única) o matriz píxel × día (GWR) | Un valor por cada día del período, sin huecos implícitos |
| Tipo de referencia | texto, p. ej. `"alfalfa"` (alta, `ETr`) / `"grass"` (corta, `ETo`) (nombres a fijar en la especificación de forzamiento) | atributo/metadato | **Explícito e idéntico** para `etr_inst`, `etr_24` y la condición del ancla fría (§6.4) |
| Método de forzamiento | texto (estación única / GWR / alternativa) | metadato | Necesario para la comparación C1–C3 de `VALIDATION_PLAN.md` §2.1 |

---

## 2. Fuentes consultadas y nivel de evidencia

| Fuente | Tipo | Qué aporta | Ubicación consultada |
|---|---|---|---|
| Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop evapotranspiration — Guidelines for computing crop water requirements*. FAO Irrigation and Drainage Paper 56. FAO, Roma. ISBN 92-5-104219-5 (FAO-56) | **Primaria** (leída en www.fao.org, edición HTML, 2026-11-04) | Balance de energía y convención de signo; λ constante y λ(T); ρ_w; conversión energía → lámina; factores de conversión | Cap. 1, "Energy balance and microclimatological methods", Ec. 1; cap. 1, "Units", tabla 1 y ejemplo 1; cap. 3, "Latent heat of vaporization (λ)"; cap. 3, "Radiation — Units", Ec. 20, recuadro 8 y tabla 3; anexo 3, Ec. 3-1. La edición HTML no tiene números de página; el PDF no fue accesible (§2.1) |
| Olmedo, G. F., Ortega-Farías, S., de la Fuente-Sáiz, D., Fonseca-Luengo, D., & Fuentes-Peñailillo, F. (2016). water: Tools and functions to estimate actual evapotranspiration using land surface energy balance models in R. *The R Journal*, 8(2), 352–369. DOI `10.32614/RJ-2016-051` (metadatos verificados en api.crossref.org) | Secundaria (artículo) | Ecs. 1–4: LE residual, ET_inst, ET24 vía ETrF; supuesto de proporcionalidad respecto de ETr de la estación | p. 353 (Ecs. 1–4); pp. 356–357 (supuesto de proporcionalidad y cancelación de sesgos) |
| Paquete `water` v1.0 (2026-10-19; commit `3c94630`, GPL ≥ 2): `R/water_ET.R` (`ET24h()`, `hourlyET()`), `R/water_ETperiod.R` (`ETperiod()`), `R/water_LSEBclass.R`, `R/water_sensibleHeatFlux.R`, `R/water_METRIC.R` | Secundaria (implementación) | Forma λ(Ts); ET_inst; ETrF; ET24 con C_rad; truncamiento de negativos; interpolación de ETrF entre fechas (lineal / spline natural); diagnóstico ETrF > 1.1 | Funciones citadas. **No se copia código** (GPL vs. MIT); las ecuaciones se reescriben aquí en notación propia |
| Notas de revisión incluidas en el repositorio `water` (`roadto1/`; autoría y método no verificables) | Terciaria | Atribuyen números de ecuación y páginas de Allen et al. (2007) a λ, ETrF, ET24, C_rad, ET de período y al rango de ETrF | Solo orientan qué buscar en la fuente primaria |
| Wasti, S. (2020). *Estimation of land surface evapotranspiration in Nepal using Landsat based METRIC model* (tesis de maestría). arXiv:2007.13922 | Secundaria (aplicación) | Ecs. 2.45–2.48: ET_inst = 3600·LE/(λ·ρ_w) con ρ_w = 1000 kg m⁻³ y λ en J kg⁻¹, "mm/hr"; ETrF; ET24 | pp. 32–33 del documento |
| Allen, R. G., Tasumi, M., & Trezza, R. (2007). Satellite-based energy balance for mapping evapotranspiration with internalized calibration (METRIC)—Model. *Journal of Irrigation and Drainage Engineering*, 133(4), 380–394. DOI `10.1061/(ASCE)0733-9437(2007)133:4(380)` | Primaria | — | **No consultada** (ascelibrary.org bloqueado). Metadatos y DOI verificados en api.crossref.org |
| Allen, R. G., Tasumi, M., Morse, A., Trezza, R., Wright, J. L., Bastiaanssen, W., Kramber, W., Lorite, I., & Robison, C. W. (2007). …(METRIC)—Applications. *J. Irrig. Drain. Eng.*, 133(4), 395–406. DOI `10.1061/(ASCE)0733-9437(2007)133:4(395)` | Primaria | — | No consultada; metadatos verificados (Crossref) |
| Allen, R., Irmak, A., Trezza, R., Hendrickx, J. M. H., Bastiaanssen, W., & Kjaersgaard, J. (2011). Satellite-based ET estimation in agriculture using SEBAL and METRIC. *Hydrological Processes*, 25(26), 4011–4027. DOI `10.1002/hyp.8408` | Primaria | — | No consultada; metadatos verificados (Crossref) |
| Literatura sobre escalamiento temporal (§6.5): Crago (1996), DOI `10.1016/0022-1694(95)02903-6`; Colaizzi, Evett, Howell & Tolk (2006), DOI `10.13031/2013.22056`; Chávez, Neale, Prueger & Kustas (2008), DOI `10.1007/s00271-008-0122-3`; Ryu et al. (2012), DOI `10.1016/j.agrformet.2011.09.010` | Primaria | — | **No consultadas**. Solo metadatos verificados (Crossref); se citan por su tema según el título |
| Henderson-Sellers, B. (1984). A new formula for latent heat of vaporization of water as a function of temperature. *Q. J. R. Meteorol. Soc.*, 110(466), 1186–1190. DOI `10.1002/qj.49711046626` | Primaria | Alternativa a λ(T) | No consultada; metadatos verificados (Crossref) |

### 2.1 Hosts y recursos no accesibles durante la redacción

| Recurso | Resultado | Consecuencia |
|---|---|---|
| ascelibrary.org (Allen et al., 2007; ASCE-EWRI, 2005) | Bloqueado (no se intentó, conocido de antemano) | Ecuaciones METRIC quedan `CANDIDATA` |
| github.com | Bloqueado (no se intentó) | Se usó el clon local de `water` |
| PDF de FAO-56 (`www.fao.org/3/x0490e/x0490e.pdf`) | Redirección rechazada por el proxy (CONNECT 403); no se reintentó | Se citan ubicaciones (capítulo, recuadro, ecuación, tabla) de la edición HTML, sin páginas |
| export.arxiv.org (API de metadatos) | Rechazado por el proxy (CONNECT 403); no se reintentó | Metadatos de arXiv:2007.13922 tomados de la página `arxiv.org/abs` |

---

## 3. LE como residuo del balance de energía — `ef_latent_heat()`

### 3.1 Ecuación y estado

```text
LE = Rn − G − H
```

- **`VERIFICADA` como balance de energía de superficie:** FAO-56, cap. 1,
  "Energy balance and microclimatological methods", Ec. 1:
  `Rn − G − λET − H = 0`, con λET el flujo de calor latente. Convención de
  signo (misma fuente): "Positive Rn supplies energy to the surface and
  positive G, λET and H remove energy from the surface". Supuestos
  declarados allí: solo flujos verticales (se ignora la advección
  horizontal), superficies extensas y homogéneas, y se desprecian el
  almacenamiento de calor en la planta y la energía metabólica.
- Uso como residuo en METRIC: corroborado por Olmedo et al. (2016, Ec. 1,
  p. 353) y por `water::ET24h()`. Número de ecuación en Allen et al. (2007):
  `TODO` (ítem V1).
- Coherencia: la convención de G de `soil-heat-flux.md` §1 (G > 0 hacia el
  suelo) coincide con la de FAO-56 Ec. 1 (G positivo retira energía de la
  superficie).

Consecuencia ya registrada en `SCIENTIFIC_SPEC.md` §2.1: por construcción el
balance "cierra" en cada píxel; todo el error de Rn, G y H se transfiere a
LE. Los supuestos de FAO-56 Ec. 1 (sin advección, homogeneidad) son más
débiles en píxeles MODIS de 1 km (§6.5, L7).

### 3.2 Entradas y salida

Firma: `ef_latent_heat(rn, g, h)`.

| Argumento | Símbolo | Unidad | Definición |
|---|---|---|---|
| `rn` | Rn | W m⁻² | Radiación neta instantánea (salida de `ef_net_radiation()`) |
| `g` | G | W m⁻² | Flujo de calor del suelo instantáneo, positivo hacia el suelo |
| `h` | H | W m⁻² | Flujo de calor sensible instantáneo, positivo desde la superficie hacia el aire |

Salida: vector `double` (o arreglo con el `dim` de las entradas) con LE en
**W m⁻²**.

### 3.3 Dominio, NA y valores negativos

- Las tres entradas pueden ser **cualquier real finito**: Rn, G y H negativos
  son físicamente posibles (`ef_net_radiation.md` §4, `soil-heat-flux.md`
  §6.2, H negativo bajo advección). No hay comprobación de signo.
- `Inf`/`-Inf` → `earthflux_domain_error`.
- `NA`/`NaN` se propagan elemento a elemento, sin error ni warning; el flag
  `EF_INPUT_NA` lo construye la capa de orquestación
  (`ef_net_radiation.md` §5).
- **LE < 0 se devuelve sin cambios y sin warning** (principio 6 de
  `ARCHITECTURE.md`). Significa H > Rn − G (energía para H mayor que la
  disponible). La orquestación lo marca (§7; decisión ET-D4). Diferencia
  documentada con `water`: `METRIC.EB()` fija LE = 0 donde H > Rn − G y
  `ET24h()` trunca ET24 < 0 a 0 (`R/water_ET.R`, roxygen de `ET24h()`);
  EarthFlux no lo hace.
- LE > Rn − G (es decir, H < 0) tampoco se modifica; puede ser legítimo en
  condiciones advectivas (flag informativo propuesto, §7).

Limitación de los tests: LE = rn − g − h es simétrica en `g` y `h`; un
intercambio de esos dos argumentos no es detectable por valor. Se mitiga
con argumentos con nombre en la orquestación y en los ejemplos.

---

## 4. Calor latente de vaporización y densidad del agua — `ef_lambda()`

> **Implementada (2026-11-04)** en `R/shared-physics.R` (archivo compartido
> con `ef_air_pressure()`, porque la usan el módulo de anclas y la cadena
> de ET; P0-7), con los métodos `"constant"` y `"fao56"`; `"metric"` no se
> implementa hasta V2. La guarda de unidades de ET-D2 es el helper interno
> `check_latent_heat_units()`, para las funciones que reciben `lambda`.

Unidad de salida propuesta: **J kg⁻¹** (SI), para que la conversión de §5
opere con W m⁻² sin factores ocultos. Las fuentes expresan λ en MJ kg⁻¹; la
conversión ×10⁶ es interna y está documentada.

### 4.1 Constante FAO-56 — `VERIFICADA`

λ = 2.45 MJ kg⁻¹ = 2.45 × 10⁶ J kg⁻¹.

- FAO-56, cap. 3, "Latent heat of vaporization (λ)": "As λ varies only
  slightly over normal temperature ranges a single value of 2.45 MJ kg⁻¹ is
  taken in the simplification of the FAO Penman-Monteith equation. This is
  the latent heat for an air temperature of about 20°C."
- FAO-56, anexo 3: "A single value may be taken (for T = 20 °C):
  λ = 2.45 MJ kg⁻¹."
- FAO-56, cap. 1, "Units": "at 20°C, λ is about 2.45 MJ kg⁻¹ … 1 mm of
  water is equivalent to 2.45 MJ m⁻²".

### 4.2 Forma dependiente de la temperatura del aire (FAO-56) — `VERIFICADA` como ecuación de FAO-56

```text
λ [MJ kg⁻¹] = 2.501 − (2.361 × 10⁻³) · T,     T = temperatura del aire [°C]
```

- FAO-56, anexo 3 ("Background on physical parameters used in
  evapotranspiration computations"), Ec. 3-1, con T definida como "air
  temperature [°C]". Referencia que FAO-56 cita para esta ecuación:
  Harrison (1963) (`TODO: verify full citation`; no consultada).
- Comprobación: T = 20 °C → 2.501 − 0.04722 = 2.45378 MJ kg⁻¹, coherente
  con el valor constante redondeado 2.45 (diferencia relativa 0.15 %).
- Dominio de validez declarado: FAO-56 solo dice que λ "varies only slightly
  over normal temperature ranges". Rango de T de validez: `TODO` (no se
  inventa).
- En EarthFlux el núcleo recibe temperaturas en K (`radiation-components.md`
  §4.1); la función convierte con `EF_KELVIN_OFFSET` (273.15, constante
  compartida, `soil-heat-flux.md` D9).

### 4.3 Forma usada en implementaciones METRIC (temperatura de superficie) — `CANDIDATA`

```text
λ [MJ kg⁻¹] = 2.501 − 0.00236 · (Ts − 273.15),     Ts = temperatura de superficie [K]
```

| Elemento | Detalle |
|---|---|
| Evidencia | `water` v1.0, `ET24h()` (`R/water_ET.R`) y `print()` del resultado de `METRIC.EB()` (`R/water_LSEBclass.R`): `(2.501 − 0.00236·(Ts − 273.15))·10⁶` J kg⁻¹, con Ts de la superficie. Atribución en el roxygen: Allen et al. (2007). Notas terciarias del repositorio: "λ (Eq. 53)". **No verificada** contra la fuente primaria |
| Diferencias con FAO-56 Ec. 3-1 | (a) temperatura de **superficie** en vez de la del aire; (b) coeficiente 0.00236 en vez de 2.361 × 10⁻³ (diferencia de 10⁻⁶ MJ kg⁻¹ °C⁻¹: 3 × 10⁻⁵ MJ kg⁻¹ a 30 °C, relativo 1.2 × 10⁻⁵) |
| Inconsistencia interna observada en `water` | La calibración del ancla fría en `calcH()` (`R/water_sensibleHeatFlux.R`) usa 0.002361, mientras `ET24h()` usa 0.00236. Con dos λ distintos la ETrF del ancla fría no reproduce exactamente el coeficiente impuesto en la calibración (§11.4). **EarthFlux debe usar una sola función λ en toda la cadena** (anclas y conversión) |
| Preguntas para la fuente primaria | ítem V2 (§12) |

### 4.4 Densidad del agua — `VERIFICADA`

ρ_w = 1000 kg m⁻³.

- FAO-56, cap. 3, recuadro 8: "ρ_W density of water, i.e., 1000 kg m⁻³".
- FAO-56, cap. 1, tabla 1, nota: "For water with a density of 1000 kg m⁻³
  and at 20°C".
- Corroborado (secundario): Olmedo et al. (2016, p. 353) y Wasti (2020,
  p. 33), ambos "1000 kg m⁻³".
- Propuesta: constante interna nombrada (`EF_WATER_DENSITY`), no argumento
  (decisión ET-D3). Una densidad dependiente de la temperatura no se adopta:
  FAO-56 usa el valor fijo y la sensibilidad es menor que la de λ (sin cifra
  porque requeriría una tabla de densidad que no se consultó; `TODO` si se
  reabre).

### 4.5 Firma propuesta

```r
ef_lambda(temperature = NULL, method)
```

| `method` | `temperature` | Ecuación | Estado |
|---|---|---|---|
| `"constant"` | ignorada (puede omitirse); devuelve un escalar | 2.45 × 10⁶ J kg⁻¹ | `VERIFICADA` |
| `"fao56"` | temperatura del **aire** [K] | (2.501 − 2.361 × 10⁻³·(T − 273.15)) × 10⁶ | `VERIFICADA` (FAO-56) |
| `"metric"` | temperatura de **superficie** [K] | (2.501 − 0.00236·(Ts − 273.15)) × 10⁶ | `CANDIDATA` (no implementar hasta V2) |

- `method` **sin valor por defecto** y con coincidencia exacta (igual que
  `soil-heat-flux.md` §5.4): elegir λ es una decisión científica
  explícita. Valor desconocido → `earthflux_unknown_method`
  (+ `earthflux_input_error`). El valor por defecto de `earthflux()` es la
  decisión ET-D1.
- Dominio: `temperature` finita y > 0 K; si no → `earthflux_domain_error`.
  `NA` se propaga. Un rango plausible de temperatura para la validez de
  λ(T) es `TODO` (sin umbral inventado; no se registra flag).
- Salida: λ en J kg⁻¹, con la forma de `temperature` (o escalar para
  `"constant"`).

---

## 5. Cadena de unidades: W m⁻² → mm h⁻¹

### 5.1 Análisis dimensional

Base (FAO-56, cap. 3, recuadro 8, `VERIFICADA`):

```text
lámina [m] = energía por unidad de área [J m⁻²] / (λ [J kg⁻¹] · ρ_w [kg m⁻³])
```

Comprobación de dimensiones: J m⁻² / (J kg⁻¹ · kg m⁻³) = J m⁻² / (J m⁻³) = m.

Para una tasa instantánea LE [W m⁻² = J s⁻¹ m⁻²], la energía por área
acumulada a esa tasa durante una hora es `3600 [s h⁻¹] · LE`. Entonces:

```text
ET_inst [mm h⁻¹] = 1000 [mm m⁻¹] · 3600 [s h⁻¹] · LE [J s⁻¹ m⁻²]
                   / ( λ [J kg⁻¹] · ρ_w [kg m⁻³] )

dimensiones:  mm m⁻¹ · s h⁻¹ · J s⁻¹ m⁻² / (J m⁻³)
            = mm m⁻¹ · h⁻¹ · m⁻² · m³
            = mm m⁻¹ · m h⁻¹
            = mm h⁻¹                                   ✓
```

Con ρ_w = 1000 kg m⁻³ los factores 1000 se cancelan numéricamente:

```text
ET_inst [mm h⁻¹] = 3600 · LE / λ        (λ en J kg⁻¹)
```

lo que equivale a leer `3600·LE/λ` en kg m⁻² h⁻¹ y usar 1 kg m⁻² ≡ 1 mm
(FAO-56, cap. 1, "Units": "2.45 MJ are needed to vaporize 1 kg or
0.001 m³ of water … 0.001 m or 1 mm").

### 5.2 Observación sobre la notación METRIC (`CANDIDATA (corroborada)`)

Olmedo et al. (2016, Ec. 3, p. 353) y Wasti (2020, Ec. 2.45, p. 33)
presentan, atribuyéndola a Allen et al. (2007):

```text
ET_inst = 3600 · LE / (λ · ρ_w)      "mm h⁻¹", ρ_w = 1000 kg m⁻³, λ en J kg⁻¹
```

Con esas unidades la expresión da **m h⁻¹**, no mm h⁻¹ (§5.1). La
implementación de `water` usa `3600·LE/λ` (sin ρ_w), que sí da mm h⁻¹ con λ
en J kg⁻¹. EarthFlux implementa la forma dimensionalmente explícita de §5.1
(`1000·3600·LE/(λ·ρ_w)`), que coincide numéricamente con `water`. Cómo
resuelve la fuente primaria el factor (p. ej., otra unidad de λ o de ρ_w)
queda como ítem V3; la fila de `SCIENTIFIC_SPEC.md` §3 debe corregirse.

### 5.3 Anclas numéricas independientes (FAO-56)

| Equivalencia publicada | Ubicación | Valor reproducido con §5.1 (λ = 2.45 × 10⁶ J kg⁻¹) |
|---|---|---|
| 1 mm d⁻¹ ≡ 2.45 MJ m⁻² d⁻¹ | Cap. 1, tabla 1 | LE = 2.45 × 10⁶ / 86400 = 28.3565 W m⁻² → ET_inst = 1/24 mm h⁻¹ = 0.041667 mm h⁻¹ → × 24 h = 1 mm d⁻¹ |
| 1 W m⁻² → 0.035 mm d⁻¹ (redondeado) | Cap. 3, tabla 3 | 3600 / 2.45 × 10⁶ = 1.469388 × 10⁻³ mm h⁻¹ → × 24 = 0.035265 mm d⁻¹ |
| 1 mm d⁻¹ → 28.4 W m⁻² (redondeado) | Cap. 3, tabla 3 | 28.3565 W m⁻² |
| equivalente en lámina = 0.408 × radiación [MJ m⁻² d⁻¹] | Cap. 3, Ec. 20 (0.408 = 1/2.45 redondeado) | 1/2.45 = 0.408163 |

Estas equivalencias sirven como test de magnitud **independiente** de la
implementación (§11.3), que detecta un factor 1000 omitido o duplicado
(algo que un test de ida y vuelta por sí solo no detecta).

---

## 6. ET instantánea, ETrF y extrapolación diaria

### 6.1 `ef_et_inst(le, lambda)`

```text
ET_inst = 1000 · 3600 · LE / (λ · ρ_w)       [mm h⁻¹]
```

| Argumento | Unidad | Dominio |
|---|---|---|
| `le` | W m⁻² | real finito (negativos permitidos) |
| `lambda` | J kg⁻¹ | finito y > 0 (salida de `ef_lambda()`) |

- Constantes internas nombradas: `EF_SECONDS_PER_HOUR = 3600` (exacta por
  definición), `EF_MM_PER_M = 1000` (exacta), `EF_WATER_DENSITY = 1000`
  kg m⁻³ (FAO-56).
- **Guarda de unidades de λ** (decisión ET-D2): pasar λ en MJ kg⁻¹ (p. ej.
  2.45) en vez de J kg⁻¹ produce ET 10⁶ veces mayor sin error. Con la
  Ec. 3-1 de FAO-56, λ entre −10 °C y 50 °C va de 2.5246 a 2.3830 MJ kg⁻¹.
  Propuesta: error de clase `earthflux_domain_error` si `lambda` está fuera
  de un intervalo amplio de órdenes de magnitud (p. ej., [10⁶, 10⁷] J kg⁻¹),
  justificado como control de **unidades**, no como umbral físico. Pendiente
  de aprobación (ET-D2).
- ET_inst < 0 (porque LE < 0) se devuelve sin cambios → `EF_ET_NEGATIVE`
  (existente) en la orquestación.

### 6.2 `ef_etrf(et_inst, etr_inst)` — `CANDIDATA (corroborada)`

```text
ETrF = ET_inst / ETr_inst          [–]
```

- Evidencia: Olmedo et al. (2016, Ec. 4 y texto, p. 353); Wasti (2020,
  Ec. 2.46, p. 33); `water::ET24h()` (`ETr.Fr <- ET.inst/ETr.hourly`).
  Número de ecuación en Allen et al. (2007): notas terciarias indican
  "Eq. 54" (ítem V4).
- `et_inst`: real finito (negativos permitidos). `etr_inst`: finito y
  **> 0**; `etr_inst ≤ 0` → `earthflux_domain_error` (decisión ET-D6): a la
  hora de paso diurna la ET de referencia debe ser positiva y un cero
  produciría `Inf`.
- Base temporal de `etr_inst`: en `water`, `hourlyET(..., ET.instantaneous =
  TRUE)` suma 0.5 h a la hora para calcular la ET de referencia horaria del
  período **centrado** en la hora de paso (roxygen y código de
  `hourlyET()`). Es una aproximación de la tasa instantánea; la definición
  que adopte EarthFlux la fija la especificación de forzamiento (ítem V5).
- ETrF < 0 (ET_inst < 0) se devuelve sin cambios; ETrF fuera de un rango
  plausible → flag (§7), nunca truncamiento.

### 6.3 `ef_et_daily_etrf(etrf, etr_24)` — `CANDIDATA (corroborada)`

```text
ETa_24 = ETrF · ETr_24             [mm d⁻¹]
```

- Evidencia: Olmedo et al. (2016, Ec. 4, p. 353: "ETr_24 is the cumulative
  24 h ETr for the image day"); Wasti (2020, Ec. 2.48, p. 33: ETr_24
  "calculated by summing hourly ETr values over the day of image");
  `water::ET24h()`. Notas terciarias: "Eq. 55".
- `etrf`: real finito. `etr_24`: finito y ≥ 0 (negativo →
  `earthflux_domain_error`; ET-D6).
- **No** se truncan los negativos (diferencia con `water`, que hace
  `ET.24[ET.24 < 0] <- 0`).
- **Corrección por pendiente C_rad** (`CANDIDATA`, una sola fuente
  secundaria): `water::ET24h()` multiplica por `C.rad`, "correction term
  used in sloping terrain to correct for variation in 24 h versus
  instantaneous energy availability", citando Allen et al. (2007, Eq. 56);
  el roxygen de `water::ETperiod()` cita la misma corrección como "Eq. 55".
  Las notas terciarias la describen como Eqs. 56–57, p. 390. Es relevante en
  terreno andino (`SCIENTIFIC_SPEC.md` §2.2), pero su definición y número de
  ecuación deben verificarse (ítem V6). Propuesta: `ef_et_daily_etrf()` no lo
  incluye en la primera implementación; se reserva el argumento `c_rad`
  (decisión ET-D7).

### 6.4 Tipo de referencia (alfalfa vs. pasto)

- ETrF es una razón respecto de **una** referencia. Mezclar `etr_inst` con
  base alfalfa y `etr_24` con base pasto (o una condición de ancla fría con
  otra base) produce un ETa_24 incorrecto sin error aritmético.
- Las funciones `ef_*()` son aritméticas y no ven el tipo de referencia. La
  comprobación es de la capa de orquestación: si los tipos de `etr_inst`,
  `etr_24` y la calibración del ancla fría no coinciden → error de clase
  `earthflux_reference_mismatch` (+ `earthflux_input_error`) (ET-D9).
- Nota (no implementar en M1): `water::ET24h()` documenta que para comparar
  ETrF (base alfalfa) con un Kc de base pasto se multiplica por
  ETr_24/ETo_24; las notas terciarias insisten en usar razones **diarias**,
  no instantáneas. Fuera de alcance; `TODO` si se requiere.

### 6.5 Supuesto de ETrF constante durante el día y sus limitaciones

Supuesto (formulado por Olmedo et al., 2016, pp. 356–357, atribuyéndolo a
Allen et al., 2007): ETa en toda el área cambia en proporción al cambio de
ETr en la estación; ETr se usa como **índice del cambio relativo**, y los
sesgos por variación del tiempo atmosférico "should be canceled by using
the same ETrF for both instantaneous and 24 h period". La misma fuente
recomienda una máscara espacial cuando las condiciones meteorológicas son
heterogéneas (p. ej., riego rodeado de desierto).

Formalmente, ETa_24 = ETrF · ETr_24 es exacto si y solo si
ET(t)/ETr(t) = ETrF para todo t del día (o, más débilmente, si la ETrF
instantánea es igual al cociente de integrales diarias). Limitaciones a
documentar y evaluar (razonadas aquí; la evidencia cuantitativa se buscará
en la literatura de §2, no consultada):

| Id | Limitación | Comentario |
|---|---|---|
| L1 | Variación diurna real de ET/ETr | Cierre estomático por la tarde, secado de la superficie del suelo después de un riego, estrés hídrico creciente durante el día: la razón deja de ser constante |
| L2 | Hora de paso | MODIS no pasa a la hora de Landsat y su hora varía por píxel y con la deriva orbital (`SCIENTIFIC_SPEC.md` §2.4). La representatividad de una ETrF instantánea depende de la hora |
| L3 | Nubosidad posterior a la hora de paso | ETr_24 la incorpora (bien), pero se supone que el estado de la superficie (ETrF) persiste |
| L4 | Horas nocturnas | ETr_24 suma todas las horas del día (Wasti, 2020, p. 33; `water::dailyET()`); ETrF diurna se aplica también a la parte nocturna |
| L5 | Terreno | Sin C_rad, una ladera orientada al sol a la hora de paso no representa su energía diaria (ítem V6) |
| L6 | Base temporal de ETr_inst | Tasa instantánea vs. ET horaria centrada (§6.2): diferencia sistemática en ETrF |
| L7 | Escala 1 km | Píxeles mixtos; los supuestos de FAO-56 Ec. 1 (homogeneidad, sin advección) son más débiles (`SCIENTIFIC_SPEC.md` §2.3) |

**Propagación de errores de ETr (álgebra propia, relevante para H1).**
Sustituyendo §6.2 en §6.3:

```text
ETa_24 = ET_inst · (ETr_24 / ETr_inst)
δETa_24/ETa_24 ≈ δET_inst/ET_inst + δETr_24/ETr_24 − δETr_inst/ETr_inst   (primer orden)
```

Un sesgo **multiplicativo común** a ETr_inst y ETr_24 (p. ej., ambos de la
misma estación con el mismo error relativo) se cancela en el paso de
extrapolación; ETa_24 depende del **cociente** ETr_24/ETr_inst, no del
nivel. Un forzamiento espacial (GWR) influye en la extrapolación solo a
través de la variación espacial de ese cociente, y en la calibración a
través de ETr_inst en el ancla fría (que cambia H y por tanto ET_inst).
Esto refuerza la evaluación separada (i) calibración / (ii) extrapolación
de `SCIENTIFIC_SPEC.md` §1.2 y debe trasladarse allí al fusionar.

### 6.6 Alternativas de extrapolación (opciones, decisión ET-D8)

| Opción | Forma | Estado | Requiere |
|---|---|---|---|
| A. ETrF (METRIC) | §6.2–6.3 | `CANDIDATA (corroborada)` | ETr_inst, ETr_24 |
| B. Fracción evaporativa | EF = LE/(Rn − G) instantánea, conservada durante el día; ETa_24 a partir de EF y de la energía disponible diaria convertida con §5.1 (86400 s d⁻¹ en lugar de 3600 s h⁻¹) | `TODO`: forma, supuesto sobre G diario y fuente primaria sin verificar. Literatura a consultar: Crago (1996) (conservación de la EF durante el día, según el título); Bastiaanssen et al. (1998) (`REFERENCES.md`) | Rn_24 (especificación nueva), G_24 |
| C. Otros modelos de escalamiento desde una medición de una hora del día | — | `TODO`. Colaizzi et al. (2006) comparan cinco modelos (según el título); Chávez et al. (2008) y Ryu et al. (2012) tratan la extrapolación diaria y a sumas de 8 días (según el título). Contenido no consultado | Según el modelo |

Recomendación provisional: implementar solo A en M2. B y C como funciones
separadas futuras (p. ej., `ef_et_daily_evapfrac()`, nombre a
decidir), cada una con su propia especificación, para permitir comparar
métodos de extrapolación como parte de la validación (no como sustitución
silenciosa).

---

## 7. Rangos plausibles y diagnósticos (flags)

Ningún valor de LE, ET_inst, ETrF, ETa_24 ni ET_per se trunca, recorta ni
reemplaza (principio 6). Los flags los construye la capa de orquestación con
`ef_flag(mask, code)` (`R/diagnostics.R`). Como `ef_flag()` exige máscara
sin `NA`, las máscaras se construyen como `!is.na(x) & condición`.

### 7.1 Flag existente

| Código | Se aplica a | Condición |
|---|---|---|
| `EF_ET_NEGATIVE` (registrado, severidad `warning`) | ET_inst, ETa_24, ET_per | valor < 0 |

Nota: como λ·ρ_w > 0, LE < 0 ⇔ ET_inst < 0; con ETr_inst > 0, ⇔ ETrF < 0;
con ETr_24 > 0, ⇔ ETa_24 < 0. Con ETr_24 = 0, ETa_24 = 0 (o −0) aunque
ETrF < 0: el flag de ETa_24 se evalúa sobre ETa_24, y el de ET_inst lo
conserva.

### 7.2 Flags propuestos (no registrar todavía)

Se registran en `ef_flag_registry()` solo cuando se implemente la función
correspondiente y, si dependen de un umbral, cuando el umbral tenga
referencia (`R/diagnostics.R`).

| Código propuesto | Condición | Severidad | ¿Inequívoca? |
|---|---|---|---|
| `EF_LE_NEGATIVE` | LE < 0 (H > Rn − G) | warning | Sí. Alternativa: reutilizar `EF_ET_NEGATIVE` (ET-D4) |
| `EF_LE_EXCEEDS_AVAILABLE` | LE > Rn − G (H < 0; posible advección) | info | Sí |
| `EF_AVAILABLE_ENERGY_NONPOSITIVE` | Rn − G ≤ 0 | warning | Sí. Se solapa con `EF_G_EXCEEDS_RN` de `soil-heat-flux.md` §6.3 (coordinar) |
| `EF_ETRF_IMPLAUSIBLE` | ETrF fuera de [r_min, r_max] | warning | **No**: rango `TODO` (ET-D5) |
| `EF_ETRF_EXTRAPOLATED` | ET_per: algún día del período fuera del intervalo entre la primera y la última fecha válida del píxel (§8) | warning | Sí |
| `EF_ETRF_SINGLE_DATE` | ET_per: una sola fecha válida en el píxel | warning | Sí |
| `EF_ETRF_NO_VALID_DATE` | ET_per: ninguna fecha válida (resultado `NA`) | info | Sí (alternativa: `EF_INPUT_NA`) |
| `EF_ETRF_SPLINE_OVERSHOOT` | ET_per con spline: ETrF diaria fuera de [mín, máx] de las dos fechas válidas que la encierran | warning | Sí (ver caso P4) |
| `EF_ETRF_GAP_LONG` | ET_per: intervalo entre fechas válidas consecutivas mayor que un máximo | warning | **No**: máximo `TODO` (ET-D10) |
| `EF_ETR24_FILLED` | ET_per: días de ETr_24 rellenados (si se permite) | info | Sí |

### 7.3 Rango plausible de ETrF — `TODO`

- Indicio **terciario** (no verificado): las notas de revisión del
  repositorio `water` citan a Allen et al. (2007, después de la Ec. 54,
  p. 389) indicando que ETrF debería ir de 0 a cerca de 1.0, "perhaps up to
  1.1" si la superficie se mojó recientemente.
- Indicio **secundario**: `water` usa 1.05 como ETrF del ancla fría
  (`ETp.coef`, "Allen et al. (2007) use 1.05", `R/water_METRIC.R`) y
  reporta la fracción de píxeles con ETrF > 1.1 como diagnóstico de
  calibración (`R/water_LSEBclass.R`), atribuyéndolo a Allen et al. (2007).
- Hasta verificar (ítem V7) **no** se fija ningún umbral ni se registra
  `EF_ETRF_IMPLAUSIBLE`. Si se adopta, debe documentarse que el límite
  superior depende de la referencia (alfalfa vs. pasto) y del coeficiente
  del ancla fría.

---

## 8. ET de período entre imágenes — `ef_et_period()` (opcional, posterior)

Prioridad: después de `ef_et_daily_etrf()`. Útil para ET mensual o de temporada
y para validación contra balance hídrico (`VALIDATION_PLAN.md` §2.2).

### 8.1 Formulación — `CANDIDATA` (una fuente secundaria)

Observada en `water::ETperiod()` (`R/water_ETperiod.R`), que cita Allen et
al. (2007), Eqs. 58 y 59 (no verificado, ítem V8):

```text
Para cada píxel y cada día d del período [d_ini, d_fin]:
  ETrF_d  = interpolación de ETrF entre las fechas de imagen válidas del píxel
  ETa_d   = ETrF_d · ETr_24,d
ET_per    = Σ_d ETa_d                         [mm]
ETrF_per  = ET_per / Σ_d ETr_24,d             [–]   (ETrF del período ponderada por ETr)
```

Se interpola **ETrF**, no ETa: ETr_24,d aporta la variación meteorológica
diaria y ETrF la del estado de la superficie (práctica de `water` y de sus
notas terciarias: "Interpolate ETrF, never ET"). Interpolar ETa directamente
perdería esa variación diaria (alternativa no recomendada, ET-D14).

### 8.2 Comportamiento observado en `water` (referencia, no adopción automática)

| Aspecto | `water::ETperiod()` | Propuesta EarthFlux |
|---|---|---|
| Interpolación | `"linear"` (defecto) o `"spline"` natural (solo con ≥ 3 fechas válidas; dentro del intervalo entre fechas válidas) | `method` **obligatorio**: `"linear"` o `"spline"` (ET-D10) |
| Fuera de la primera/última fecha válida | Constante (valor más cercano, `rule = 2`) | Por defecto **error** si el período excede las fechas de imagen; `extrapolation = "constant"` explícito con flag `EF_ETRF_EXTRAPOLATED` (ET-D10) |
| Fechas nubladas (`NA`) | Se interpola entre las fechas válidas más cercanas; capa `n.valid` | Igual; devolver `n_valid`; flag de huecos largos cuando exista umbral |
| Una sola fecha válida | Esa ETrF para todo el período | Igual, con `EF_ETRF_SINGLE_DATE` |
| Ninguna fecha válida | `NA` | `NA` + `EF_ETRF_NO_VALID_DATE` |
| ETr_24 faltante en algún día | Error, salvo `fill.gaps = TRUE` (interpolación lineal) | Error de clase `earthflux_missing_input` por defecto; relleno solo explícito, con `EF_ETR24_FILLED` |
| ETrF < 0 o > 1.1 | No se recorta ("mask or clip them before if needed") | No se recorta; los flags de la imagen se conservan |
| ETr_24 | Una serie (una estación) | Vector por día (estación) **o matriz píxel × día** (forzamiento espacial, necesario para H1) |
| C_rad | Un único valor o ráster para todo el período | Pendiente (ET-D7); C_rad varía con la fecha, por lo que un único valor para el período es una aproximación a documentar |

### 8.3 Firma propuesta (núcleo numérico)

```r
ef_et_period(etrf, image_dates, etr_24, days, method,
             extrapolation = c("none", "constant"))
```

| Argumento | Forma | Unidad | Definición |
|---|---|---|---|
| `etrf` | matriz n × m (filas = píxeles, columnas = fechas de imagen) o vector de largo m (un píxel) | – | ETrF de cada imagen; `NA` = fecha no válida (nubes, QA) |
| `image_dates` | `Date`, largo m, sin duplicados ni `NA` | – | Fecha de cada columna; el orden se normaliza internamente |
| `etr_24` | vector de largo d o matriz n × d | mm d⁻¹ | ETr_24 de cada día del período |
| `days` | `Date`, largo d, secuencia diaria contigua | – | Días del período (ambos extremos incluidos) |
| `method` | `"linear"` / `"spline"` | – | Interpolación de ETrF |
| `extrapolation` | `"none"` / `"constant"` | – | Tratamiento fuera de las fechas válidas |

Salida (estructura exacta: ET-D12): lista con `et_period` [mm] (largo n),
`etrf_period` [–] (largo n), `n_valid` (entero, largo n) y, opcionalmente,
la matriz n × d de ETrF diaria para auditoría. Los flags los construye la
orquestación a partir de esa salida. El envoltorio ráster aplica la misma
función por bloques (`terra::app()`), y es candidato a paralelismo entre
bloques (`ARCHITECTURE.md` §6.3).

### 8.4 Decisiones abiertas específicas

- Eventos de lluvia o riego entre imágenes: la interpolación de ETrF no los
  ve (la ETrF sube tras mojarse la superficie y luego decae). Sin
  corrección en M1; documentar como limitación; si Allen et al. (2007)
  propone un ajuste, incorporarlo tras verificar (ítem V8).
- Espaciamiento entre imágenes: MODIS ofrece pasadas diarias, pero las
  nubes generan huecos irregulares; umbral de hueco máximo `TODO`.
- Spline: puede producir ETrF diaria fuera del rango de las observaciones
  vecinas (caso P4) e incluso negativa; se marca, no se recorta.

---

## 9. Descomposición de funciones y convenciones comunes

### 9.1 Funciones

| Función | Firma | Salida | Estado de la ecuación | Exportar (ET-D11) |
|---|---|---|---|---|
| `ef_latent_heat()` | `(rn, g, h)` | LE [W m⁻²] | `VERIFICADA` (FAO-56 Ec. 1) | Sí (API avanzada) |
| `ef_lambda()` | `(temperature = NULL, method)` | λ [J kg⁻¹] | `"constant"` y `"fao56"`: `VERIFICADA`; `"metric"`: `CANDIDATA` | Sí |
| `ef_et_inst()` | `(le, lambda)` | ET_inst [mm h⁻¹] | `VERIFICADA` como conversión (FAO-56 recuadro 8) | Sí |
| `ef_etrf()` | `(et_inst, etr_inst)` | ETrF [–] | `CANDIDATA (corroborada)` | Sí |
| `ef_et_daily_etrf()` | `(etrf, etr_24)` | ETa_24 [mm d⁻¹] | `CANDIDATA (corroborada)` | Sí |
| `ef_et_period()` | §8.3 | lista | `CANDIDATA` | Sí (posterior) |
| inversa interna `et_inst_to_latent_heat()` (nombre a decidir) | `(et_inst, lambda)` | LE [W m⁻²] | álgebra de §5.1 | No (`@noRd`; para tests y para la condición del ancla fría) |

Orden de la cadena en la orquestación:

```text
rn, g, h ──► ef_latent_heat() ──► le
temperature ──► ef_lambda(method) ──► lambda
le, lambda ──► ef_et_inst() ──► et_inst
et_inst, etr_inst ──► ef_etrf() ──► etrf
etrf, etr_24 ──► ef_et_daily_etrf() ──► eta_24
[etrf de varias fechas, serie de etr_24] ──► ef_et_period() ──► et_period
```

La misma λ (mismo `method` y misma temperatura) debe usarse en la condición
del ancla fría (módulo de anclas) y en `ef_et_inst()` (§4.3,
§11.4). La orquestación registra `method` de λ en la procedencia.

### 9.2 Tipo, longitud, forma y NA (como `ef_net_radiation.md` §3.1 y §5)

- Argumentos numéricos (`double` o `integer`); `logical`, `character`,
  factores, etc. → `earthflux_input_error`. Sin coerción silenciosa.
- Reciclaje: longitud 1 o longitud común n; otra → `earthflux_input_error`.
  Longitud 0 → `earthflux_input_error` (D5 de `ef_net_radiation.md`).
- Matrices/arreglos: mismo `dim` obligatorio; el resultado lo conserva (D6
  de `ef_net_radiation.md`).
- `NA`/`NaN` se propagan sin error ni warning; la comprobación de dominio
  los ignora. `EF_INPUT_NA` lo construye la orquestación.
- Helpers: `check_numeric()`, `check_common_length()`, `check_same_dim()`,
  `check_in_range()` de `R/utils.R`.
- `ef_et_period()` usa validaciones propias de estructura (matriz/fechas),
  con las mismas clases de error.

### 9.3 Dominio y errores

| Función | Argumento | Dominio | Fuera de dominio |
|---|---|---|---|
| `ef_latent_heat()` | `rn`, `g`, `h` | reales finitos | `earthflux_domain_error` (solo `Inf`) |
| `ef_lambda()` | `temperature` | finita, > 0 K | `earthflux_domain_error` |
|  | `method` | `"constant"`, `"fao56"`, `"metric"` | `earthflux_unknown_method` |
| `ef_et_inst()` | `le` | real finito | `earthflux_domain_error` (solo `Inf`) |
|  | `lambda` | finita, > 0; guarda de unidades (ET-D2) | `earthflux_domain_error` |
| `ef_etrf()` | `et_inst` | real finito | `earthflux_domain_error` (solo `Inf`) |
|  | `etr_inst` | finita, > 0 | `earthflux_domain_error` |
| `ef_et_daily_etrf()` | `etrf` | real finito | `earthflux_domain_error` (solo `Inf`) |
|  | `etr_24` | finita, ≥ 0 | `earthflux_domain_error` |
| `ef_et_period()` | estructura | §8.3 | `earthflux_input_error`; días sin ETr_24 → `earthflux_missing_input` |

Jerarquía: `earthflux_domain_error` ⊂ `earthflux_input_error` ⊂
`earthflux_error`; la llamada reportada es la de la función pública
(`ef_abort()` en `R/utils.R`). Mensajes con nombre del argumento y número de
valores fuera de dominio, como en `ef_net_radiation()`.

---

## 10. Casos numéricos verificables (cálculo a mano)

Constantes: λ = 2.45 × 10⁶ J kg⁻¹ (FAO-56) salvo indicación; ρ_w = 1000
kg m⁻³; 3600 s h⁻¹; 1000 mm m⁻¹.

### Caso A — cadena completa, caso de referencia

| Paso | Cálculo | Resultado |
|---|---|---|
| A1. LE | Rn = 600, G = 60, H = 50 → 600 − 60 − 50 | **490 W m⁻²** |
| A2. ET_inst | 1000·3600·490 / (2.45 × 10⁶ · 1000) = 1 764 000 / 2 450 000 | **0.72 mm h⁻¹** (exacto en aritmética decimal) |
| A3. ETrF | ETr_inst = 0.80 mm h⁻¹ → 0.72 / 0.80 | **0.9** |
| A4. ETa_24 | ETr_24 = 8.0 mm d⁻¹ → 0.9 · 8.0 | **7.2 mm d⁻¹** |
| A5. Ida y vuelta | 0.72 · 2.45 × 10⁶ · 1000 / (1000 · 3600) = 1 764 000 / 3600 | **490 W m⁻²** |

### Caso B — λ dependiente de la temperatura (mismo LE = 490 W m⁻²)

| Método | Cálculo de λ | λ [J kg⁻¹] | ET_inst = 3600·490/λ [mm h⁻¹] |
|---|---|---|---|
| `"constant"` | — | 2 450 000 | 0.72 |
| `"fao56"`, T_aire = 303.15 K (30 °C) | 2.501 − 0.002361·30 = 2.501 − 0.07083 = 2.43017 MJ kg⁻¹ | 2 430 170 | 1 764 000 / 2 430 170 = 0.725875 |
| `"metric"` (`CANDIDATA`), Ts = 303.15 K (30 °C) | 2.501 − 0.00236·30 = 2.501 − 0.0708 = 2.4302 MJ kg⁻¹ | 2 430 200 | 1 764 000 / 2 430 200 = 0.725866 |
| `"fao56"`, T = 293.15 K (20 °C) | 2.501 − 0.04722 = 2.45378 MJ kg⁻¹ | 2 453 780 | 0.718891 |

Diferencia "metric" vs. "constant" a 30 °C: +0.81 % en ET_inst. En los
tests, T − 273.15 en doble precisión no es exactamente 30 (error ~10⁻¹⁴ K);
la tolerancia de §11.1 lo cubre.

### Caso C — LE negativo, conservado y marcado

| Paso | Cálculo | Resultado |
|---|---|---|
| C1. LE | Rn = 400, G = 80, H = 369 → 400 − 80 − 369 | **−49 W m⁻²** (H > Rn − G = 320) |
| C2. ET_inst | 3600·(−49) / 2.45 × 10⁶ = −176 400 / 2 450 000 | **−0.072 mm h⁻¹** |
| C3. ETrF | −0.072 / 0.80 | **−0.09** |
| C4. ETa_24 | −0.09 · 8.0 | **−0.72 mm d⁻¹** |
| Flags | `EF_ET_NEGATIVE` en ET_inst y ETa_24; `EF_LE_NEGATIVE` (propuesto) en LE | ningún valor truncado |

### Caso D — ETrF alta (ilustra el flag pendiente de umbral)

LE = 612.5 W m⁻² → ET_inst = 3600·612.5 / 2.45 × 10⁶ = 2 205 000 /
2 450 000 = **0.9 mm h⁻¹**; ETr_inst = 0.75 → **ETrF = 1.2**. Se devuelve
sin cambios. Si se verifica el indicio de §7.3, se marcaría
`EF_ETRF_IMPLAUSIBLE`; hoy no se marca.

### Caso E — reciclaje y NA

`le = c(490, -49, NA)`, `lambda = 2.45e6` → `c(0.72, -0.072, NA)`, sin
warnings.

### Caso F — anclas de magnitud FAO-56 (§5.3)

- LE = 2.45 × 10⁶ / 86 400 = 28.356481 W m⁻² → ET_inst = 28.356481·3600 /
  2.45 × 10⁶ = **1/24 mm h⁻¹** → × 24 = 1 mm d⁻¹ (tabla 1).
- LE = 1 W m⁻² → ET_inst = 1.469388 × 10⁻³ mm h⁻¹ → × 24 = 0.035265
  mm d⁻¹ ≈ 0.035 (tabla 3, redondeada a tres decimales).

### Casos P — ET de período

Fechas de imagen: día 1 (ETrF 0.4) y día 5 (ETrF 0.8). Período: días 1–5.
ETr_24 = (5, 6, 7, 6, 5) mm d⁻¹.

| Caso | Detalle | Cálculo | Resultado |
|---|---|---|---|
| P1. Lineal | ETrF_d = 0.4 + 0.1·(d − 1) = (0.4, 0.5, 0.6, 0.7, 0.8) | ETa_d = (2.0, 3.0, 4.2, 4.2, 4.0); ΣETr_24 = 29 | **ET_per = 17.4 mm**; ETrF_per = 17.4/29 = **0.6**; n_valid = 2 |
| P2. Nube | Tres fechas (días 1, 3, 5) con ETrF (0.4, `NA`, 0.8) | igual que P1 | ET_per = 17.4 mm; **n_valid = 2** |
| P3. Extrapolación | Período días 0–5, ETr_24 del día 0 = 4 | sin `extrapolation`: error; con `"constant"`: ETrF_0 = 0.4, ETa_0 = 1.6 | ET_per = 19.0 mm; `EF_ETRF_EXTRAPOLATED` |
| P4. Spline sin sobrepaso | Fechas días 0, 2, 4 con ETrF (0.4, 0.8, 0.4); spline natural (M₀ = M₂ = 0, h = 2) | 2·(2+2)·M₁ = 6·[(0.4−0.8)/2 − (0.8−0.4)/2] = −2.4 → M₁ = −0.3. En x = 1: S = M₁·1³/(6·2) + 0.4·(1/2) + (0.8 − M₁·4/6)·(1/2) = −0.025 + 0.2 + 0.5 | **ETrF(1) = ETrF(3) = 0.675** (lineal: 0.6); dentro de [0.4, 0.8], sin flag |
| P5. Spline con sobrepaso | Fechas días 0, 1, 4 con ETrF (0.4, 0.8, 0.8); h₀ = 1, h₁ = 3 | 2·(1+3)·M₁ = 6·[(0.8−0.8)/3 − (0.8−0.4)/1] = −2.4 → M₁ = −0.3. En x = 2.5 (tramo [1, 4]): S = M₁·(4−2.5)³/(6·3) + (0.8 − M₁·9/6)·(1.5/3) + 0.8·(1.5/3) = −0.05625 + 0.625 + 0.4 | **ETrF(2.5) = 0.96875** > 0.8 = máx. de las fechas vecinas → `EF_ETRF_SPLINE_OVERSHOOT`; no se recorta |

P4 y P5 se contrastaron además con `stats::spline(method = "natural")` de R
(0.675; 0.966667, 0.96875 y 0.933333 en x = 2, 2.5 y 3). El test usa los
valores calculados a mano.

---

## 11. Diseño de tests

### 11.1 Tolerancias

- Casos exactos en aritmética decimal (A, C, D, E, P1–P3): **tolerancia
  absoluta 10⁻¹²** en la unidad de salida. Valores < 10³ con pocas
  operaciones: el error de redondeo en doble precisión es ~10⁻¹⁵; la
  tolerancia está muy por encima del ruido y muy por debajo de cualquier
  diferencia física (mismo criterio que `ef_net_radiation.md` §7.1).
- Casos B (λ(T)): tolerancia relativa `sqrt(.Machine$double.eps)` (incluye
  la conversión K → °C).
- Identidades algebraicas (ida y vuelta, LE + G + H = Rn): tolerancia
  relativa `sqrt(.Machine$double.eps)` (`VALIDATION_PLAN.md` §1.2).
- Caso F (tabla 3 de FAO-56, redondeada a tres decimales): tolerancia
  absoluta 5 × 10⁻⁴ mm d⁻¹, justificada por el redondeo publicado.

### 11.2 `test-latent-heat.R`

| Test | Qué verifica |
|---|---|
| Caso A1 y C1 | LE = 490 y −49 W m⁻² |
| Identidad | `ef_latent_heat(rn, g, h) + g + h == rn` en una grilla de valores con signos mixtos |
| LE negativo | Devuelto sin cambios y sin warning (`expect_silent`) |
| Reciclaje, longitudes incompatibles, longitud 0, `dim` | Como `ef_net_radiation()` |
| NA/NaN | Propagación elemento a elemento |
| `Inf` | `earthflux_domain_error` en cada argumento |
| Tipos no numéricos | `earthflux_input_error` |

### 11.3 `test-et.R`

| Test | Qué verifica |
|---|---|
| λ `"constant"` | 2.45e6 exacto |
| λ `"fao56"` y `"metric"` | Caso B; `"metric"` solo cuando pase a `VERIFICADA` (hasta entonces el método no existe) |
| `method` ausente o desconocido | Error (sin defecto; `earthflux_unknown_method`) |
| `temperature` ≤ 0 K | `earthflux_domain_error` |
| ET_inst | Casos A2, C2, D, E |
| Anclas FAO-56 | Caso F (detecta un factor 1000 omitido o duplicado) |
| Guarda de unidades de λ | `lambda = 2.45` → error (si se aprueba ET-D2) |
| Ida y vuelta | Grilla LE ∈ {−200, −49, 0, 1, 490, 612.5, 800} × λ ∈ {2.38e6, 2.45e6, 2.52e6}: `et_inst_to_latent_heat(ef_et_inst(le, lambda), lambda)` = LE (relativa `sqrt(eps)`, absoluta en LE = 0) |
| ETrF | Casos A3, C3; `etr_inst` = 0 o < 0 → `earthflux_domain_error` |
| ETa_24 | Casos A4, C4; `etr_24` < 0 → error; `etr_24` = 0 permitido |
| Negativos | ET_inst, ETrF y ETa_24 negativos devueltos sin cambios y sin warning |
| Cadena | `ef_et_daily_etrf(ef_etrf(ef_et_inst(ef_latent_heat(...), λ), etr_inst), etr_24)` = caso A completo |
| Flags (orquestación) | Caso C: máscaras `EF_ET_NEGATIVE` con índices correctos; con `NA` en la entrada, la máscara no contiene `NA` |

### 11.4 Coherencia con `VALIDATION_PLAN.md` §1.2

`VALIDATION_PLAN.md` §1.2 advierte que LE ≈ Rn − G − H es casi tautológico
si LE es residuo, y pide verificar (a) la ida y vuelta LE → ET_inst → LE y
(b) la reproducción de las condiciones de borde en los anclas. Diseño:

1. **Identidad del residuo** (§11.2): verifica solo la implementación
   (orden y signo de argumentos, salvo la simetría g ↔ h, §3.3).
2. **Ida y vuelta** (§11.3): verifica la coherencia de la conversión y de
   su inversa. Por sí sola no detecta un error de escala compartido por
   ambas (p. ej., omitir el factor 1000 en las dos); por eso va
   **acompañada** de las anclas FAO-56 (caso F), que son independientes de
   la implementación.
3. **Condiciones de borde de las anclas** (test de integración, cuando
   exista el módulo de anclas): si la calibración impone en el ancla fría
   LE_frío = k · ETr_inst · λ · ρ_w / (1000 · 3600) (k = coeficiente del
   ancla fría, valor `TODO` en `SCIENTIFIC_SPEC.md` §2.1), la cadena debe
   devolver **ETrF_frío = k** con tolerancia `sqrt(eps)`, y en el ancla
   caliente con LE objetivo 0, **ETrF_caliente = 0**. Este test solo pasa
   si anclas y conversión usan la misma λ (§4.3): con dos coeficientes
   distintos (0.002361 vs. 0.00236, como en `water`), a Ts = 300 K el
   cociente de λ es ≈ 1 − 1.1 × 10⁻⁵, error que el test detecta.
4. **Pipeline**: `earthflux()` ≡ cadena de `ef_*()` (`VALIDATION_PLAN.md`
   §1.1).

### 11.5 `test-et-period.R` (cuando se implemente)

Casos P1–P5; orden de columnas irrelevante; fechas duplicadas → error;
`days` no contiguos → error; ETr_24 matriz píxel × día vs. vector (mismo
resultado cuando las filas son iguales); spline con puntos colineales =
lineal; spline con < 3 fechas válidas → lineal (como `water`) o error
(ET-D10); `n_valid`; flags `EF_ETRF_*`; mismo resultado secuencial y en
paralelo (`ARCHITECTURE.md` §6.3).

### 11.6 Verificación cruzada con `water` (fuera del tarball, `VALIDATION_PLAN.md` §1.3)

Diferencias esperadas y explicadas: (a) `water` trunca ET24 < 0 a 0 y
`METRIC.EB()` fija LE = 0 donde H > Rn − G → enmascarar esos píxeles;
(b) λ: `water` usa la forma `"metric"` con 0.00236 (y 0.002361 en anclas);
(c) ETr_inst de `water` es la ET horaria centrada en la hora de paso;
(d) `ETperiod()` extrapola constante fuera de las fechas y acepta un único
C_rad.

---

## 12. Ítems a verificar en las fuentes primarias

**Allen, Tasumi & Trezza (2007), METRIC — Model** (DOI verificado,
§2):

- **V1.** Número de ecuación y notación de LE = Rn − G − H; convención de
  signo de G y H.
- **V2.** Ecuación de λ (notas terciarias: "Eq. 53"): coeficiente (0.00236
  vs. 2.361 × 10⁻³), temperatura usada (superficie Ts vs. aire), unidades
  (MJ kg⁻¹ o J kg⁻¹) y referencia original.
- **V3.** Ecuación de ET_inst: cómo se obtiene mm h⁻¹ a partir de
  3600·LE/(λ·ρ_w) (§5.2). Corregir la fila ET_inst de `SCIENTIFIC_SPEC.md`
  §3 en consecuencia.
- **V4.** Ecuación de ETrF (notas terciarias: "Eq. 54").
- **V5.** Definición de ETr_inst: tasa instantánea o ET horaria de un
  período (¿centrado en la hora de paso?); referencia alfalfa ASCE-EWRI
  (2005). Coordinar con la especificación de forzamiento.
- **V6.** ETa_24 (notas terciarias: "Eq. 55") y C_rad (roxygen de `water`:
  "Eq. 56" en `ET24h()` y "Eq. 55" en `ETperiod()`; notas terciarias:
  Eqs. 56–57, p. 390): forma, número y dependencia de Rso instantánea y
  diaria.
- **V7.** Rango esperado de ETrF (notas terciarias: p. 389, "0 to about
  1.0 … perhaps up to 1.1"); coeficiente del ancla fría (1.05 según
  `water`).
- **V8.** ET de período (Eqs. 58–59 según `water`): método de
  interpolación recomendado, tratamiento de nubes, de lluvias entre
  imágenes y de días fuera de las fechas de imagen.
- **V9.** Tratamiento de LE < 0 y ETrF < 0 en METRIC (¿se fijan a 0?).
- **V10.** Supuesto de ETrF constante: evidencia y condiciones de validez
  citadas por los autores (también en *Applications*, DOI verificado).

**Otras:**

- **V11.** ASCE-EWRI (2005): definición de referencia alta (alfalfa) y corta
  (pasto), ET horaria y diaria (para la especificación de forzamiento).
- **V12.** Harrison (1963), fuente que FAO-56 cita para λ(T): cita completa
  y rango de validez en T.
- **V13.** Henderson-Sellers (1984) como alternativa de λ(T): solo si se
  decide ofrecerla (ET-D1).
- **V14.** Literatura de §6.6 (Crago, 1996; Colaizzi et al., 2006; Chávez
  et al., 2008; Ryu et al., 2012; Allen et al., 2011): formas de la
  alternativa por fracción evaporativa, supuestos sobre G diario, evidencia
  sobre L1–L4.
- **V15.** FAO-56 en edición impresa/PDF: números de página de las
  ubicaciones citadas en §2 (la edición HTML no los tiene).

Para `REFERENCES.md` (al fusionar): DOIs verificados en api.crossref.org el
2026-11-04 para Allen et al. (2007, *Model* y *Applications*), Allen et al.
(2011) y Olmedo et al. (2016) (`10.32614/RJ-2016-051`, que resuelve el
`TODO: verify DOI` actual); FAO-56 contrastada en www.fao.org (ISBN
92-5-104219-5).

---

## 13. Decisiones abiertas

| Id | Decisión | Opción recomendada (provisional) | Requiere |
|---|---|---|---|
| ET-D1 | Método de λ por defecto en `earthflux()` y temperatura (aire vs. superficie) | `"constant"` (FAO-56, `VERIFICADA`) hasta verificar V2; luego evaluar `"metric"` por fidelidad a METRIC. La función de bajo nivel sin defecto | V2 |
| ET-D2 | Guarda de unidades de λ (rechazar valores fuera de [10⁶, 10⁷] J kg⁻¹) | Adoptar como control de unidades, documentado como tal | Aprobación del autor |
| ET-D3 | ρ_w: constante interna o argumento | Constante interna `EF_WATER_DENSITY` | — |
| ET-D4 | Flag de LE negativo: código nuevo `EF_LE_NEGATIVE` o reutilizar `EF_ET_NEGATIVE` | Código nuevo (diagnostica H > Rn − G en la etapa de balance) | Revisión del registro |
| ET-D5 | Rango plausible de ETrF | Ninguno hasta verificar V7; flag no registrado | V7 |
| ET-D6 | `etr_inst` ≤ 0 y `etr_24` < 0 | Error de dominio (no `NA` + flag) | Especificación de forzamiento |
| ET-D7 | C_rad en `ef_et_daily_etrf()` / `ef_et_period()` | Reservar argumento `c_rad`; implementar tras V6 y con la función que lo calcule en el módulo de radiación | V6 |
| ET-D8 | Métodos de extrapolación alternativos (fracción evaporativa, otros) | Solo ETrF en M2; alternativas como funciones separadas con especificación propia | V14 |
| ET-D9 | Dónde y cómo se comprueba el tipo de referencia | Orquestación; atributo explícito; error `earthflux_reference_mismatch` | Especificación de forzamiento |
| ET-D10 | ET de período: `method` sin defecto; extrapolación fuera de fechas; hueco máximo; spline con < 3 fechas; ETr_24 faltante | `method` obligatorio; `extrapolation = "none"` por defecto (error); hueco máximo `TODO`; spline con < 3 fechas → error; ETr_24 faltante → error | V8 |
| ET-D11 | Exportar las seis funciones | Sí, como API avanzada; la inversa es interna | Tamaño de la API pública (`DEVELOPMENT.md` §1) |
| ET-D12 | Estructura de salida de `ef_et_period()` | Lista liviana; clase final coordinada con `earthflux_result` | Diseño de clases (M2) |
| ET-D13 | Archivos de test | `test-latent-heat.R`, `test-et.R`, `test-et-period.R` (`SCIENTIFIC_SPEC.md` §3 menciona `test-pipeline.R` para LE; actualizar) | — |
| ET-D14 | Variable interpolada entre imágenes | ETrF (no ETa) | V8 |
| ET-D15 | Lluvia o riego entre imágenes | Sin corrección; documentar como limitación | V8 |
| ET-D16 | Definición del "día" de ETr_24 (zona horaria, completitud) | Delegada a la especificación de forzamiento | V11 |

---

## 14. Paso a `VERIFICADA` e implementación

- Implementables tras la fusión de esta especificación (ecuaciones
  `VERIFICADA` contra FAO-56): `ef_latent_heat()`,
  `ef_lambda()` con `"constant"` y `"fao56"`, y
  `ef_et_inst()`. Requisitos restantes de la *Definition of Done*
  (`DEVELOPMENT.md` §3): entradas y unidades (§3.2, §4.5, §6.1), NA (§9.2),
  dominio (§9.3), casos (§10) y tests (§11) están definidos aquí.
- `ef_etrf()` y `ef_et_daily_etrf()` son definiciones aritméticas simples, pero
  su estado es `CANDIDATA (corroborada)` hasta V4–V6: **no implementar**
  hasta que el autor confirme contra Allen et al. (2007), o hasta que se
  decida explícitamente registrarlas como definiciones operativas con su
  justificación.
- `method = "metric"` de λ y `ef_et_period()`: `CANDIDATA`; no implementar.
- Al fusionar: actualizar en `SCIENTIFIC_SPEC.md` §3 las filas LE (estado y
  referencia FAO-56), ET_inst (factor 1000 mm m⁻¹, §5.2; λ), ETrF y ETa
  (limitaciones §6.5) y en §1.2 la fila *Extrapolación diaria* (álgebra de
  cancelación, §6.5); y en `REFERENCES.md` los DOIs de §12.


### 14.1 Implementación M2 (2026-11-04)

- **`ef_etrf()` y `ef_et_daily_etrf()` se implementaron como definiciones
  operativas** por instrucción del hito M2, rotuladas `CANDIDATA
  (corroborada)` en roxygen (Olmedo et al., 2016, Ec. 4). La decisión
  explícita que pide P0-1 / este §14 quedó registrada en la armonización
  M2 (`DECISIONS.md` §1.2, M2-01).
- **Tipo de referencia (§6.4):** `ef_etrf(et_inst, etr_inst, reference)` y
  `ef_et_daily_etrf(etrf, etr_24, reference)` (y el despachador
  `ef_et_daily(etrf, etr_24, reference, method)`) reciben `reference`
  **obligatorio, sin defecto**, con valores `"alfalfa"` / `"grass"`
  (nombres de `weather-forcing.md` §5). No cambia la aritmética: hace
  explícita la elección. Ausente → `earthflux_missing_input`; otro valor →
  `earthflux_unknown_method` (subclase de `earthflux_input_error`; desde la
  armonización M2 la comprobación es `check_method()` y la comparte
  `ef_anchor_conditions()`; `DECISIONS.md` §1.2, M2-02). La comprobación de coherencia entre `etr_inst`,
  `etr_24` y el ancla fría sigue en la orquestación (ET-D9,
  `earthflux_reference_mismatch`). Desviación de la firma de §6.2–6.3.
- **Despachador `ef_et_daily()`** (regla N6 de `NAMING.md`): `method` sin
  defecto (`check_method()`), único valor `"etrf"`; solo valida la
  presencia de los argumentos del método (`earthflux_missing_input`) y
  reenvía. *Armonización M2 (`DECISIONS.md` §1.2, M2-04):* devuelve un
  objeto `earthflux_daily_et` (`eta_24`, idéntico a `ef_et_daily_etrf()`
  —test—, `method`, `reference`, `flags` con `EF_INPUT_NA` y
  `EF_ET_NEGATIVE`, `provenance`).
  `"evapfrac"` → `earthflux_unknown_method` hasta que exista su
  especificación.
- **C_rad** (ET-D7): no se reservó el argumento `c_rad` (se agregará con su
  función, tras V6); la ausencia de corrección por pendiente está
  documentada.
- **Constantes de unidades**: `EF_SECONDS_PER_HOUR` y `EF_MM_PER_M` se
  definieron primero en `R/metric-et.R` y la armonización M2 las trasladó a
  `R/constants.R`; ρ_w es `EF_WATER_DENSITY` y la guarda de λ es
  `check_latent_heat_units()` (ET-D2).
- **Flags:** `ef_diagnose_et(et_inst = NULL, eta_24 = NULL)` devuelve una
  lista con nombre (posiblemente vacía) de registros `EF_ET_NEGATIVE`, uno
  por capa con al menos un elemento marcado; el nombre del elemento es la
  capa (`"et_inst"`, `"eta_24"`) a la que se refiere `index` (hasta que el
  registro tenga el campo `target`, `flags.md` §6.2). LE < 0 no se evalúa
  aparte (C1/FL-03). ETrF no se evalúa (ET-D5; `EF_ET_ETRF_IMPLAUSIBLE`
  sigue en la guardia de clase II).
- **Inversa interna:** `ef_et_inst_to_latent_heat(et_inst, lambda)`
  (`@noRd`); desde la armonización M2 es la única conversión LE ↔ ET del
  paquete y la usa `ef_anchor_conditions()` para la condición de las
  anclas (§11.4; `DECISIONS.md` §1.2, M2-06).
