# Auditoría de referencias

Fecha de la auditoría: **2026-11-04**. Autor: Guillermo Servando
Fuentes-Jaque.

Objeto: verificar los metadatos bibliográficos de todas las entradas de
[`../REFERENCES.md`](../REFERENCES.md), incorporar las referencias citadas en
`dev/specs/*.md` y `SCIENTIFIC_SPEC.md` que faltaban, y registrar la
evidencia disponible sobre la forma de la ecuación de radiación neta (Rn).

---

## 1. Método

- **Crossref:** consulta secuencial a `https://api.crossref.org/works/<DOI>`
  o, si no se conocía el DOI, a
  `https://api.crossref.org/works?query.bibliographic=...&rows=3`, con un
  identificador HTTP genérico del proyecto y pausas entre solicitudes. Se
  aceptó un registro solo si autores, título, revista, volumen y páginas
  coincidían con la entrada. Todo DOI registrado proviene de Crossref,
  salvo el DOI de conjunto de datos de MOD11A1 v061, tomado de la página
  oficial de NASA Earthdata.
- **Páginas oficiales:** FAO (edición electrónica de FAO-56), *The R
  Journal* (página del artículo y PDF), arXiv (página de resumen y PDF),
  CRAN (página del paquete y archivo), NASA Earthdata / LP DAAC (página del
  producto MOD11A1 v061, guía de usuario, aviso de transición MODIS→VIIRS).
- **Documentos leídos:** PDF de Olmedo et al. (2016); PDF de
  arXiv:2007.13922 v2; capítulo 3 de FAO-56 (HTML oficial); guía de
  usuario MODIS LST C6/C6.1.
- Verificar la cita **no** verifica el contenido científico: los números de
  ecuación y las formas se registran aparte (§4–§6).

## 2. Tabla de referencias

Estados: **V** = verificada; **P** = parcial; **T** = pendiente (`TODO`).
"Corrección" indica cambios de metadatos aplicados en `REFERENCES.md`
(además de agregar el DOI).

### 2.1 Entradas que ya estaban en `REFERENCES.md`

| Referencia | Evidencia (2026-11-04) | Estado | Corrección / observación |
|---|---|---|---|
| Allen, Tasumi & Trezza (2007), METRIC — Model, JIDE 133(4), 380–394 | Crossref `10.1061/(ASCE)0733-9437(2007)133:4(380)` | V | DOI agregado. Coincide con el DOI de `water` y del roxygen de `ef_net_radiation()`. Texto completo no consultado. |
| Allen et al. (2007), METRIC — Applications, JIDE 133(4), 395–406 | Crossref `10.1061/(ASCE)0733-9437(2007)133:4(395)` | V | Nueve autores confirmados en el orden registrado. |
| Allen et al. (2011), Hydrol. Process. 25, 4011–4027 | Crossref `10.1002/hyp.8408` | V | Agregado el número 26. |
| Bastiaanssen et al. (1998), SEBAL 1, J. Hydrol. 212–213, 198–212 | Crossref `10.1016/S0022-1694(98)00253-4` | V | Título: "(SEBAL). 1. Formulation" (puntuación). |
| Tasumi (2003), tesis doctoral, University of Idaho | Sin registro en Crossref; sitio institucional no accesible | T | Sin cambios. |
| Wan — guía de usuario MODIS LST | Documento: `https://lpdaac.usgs.gov/documents/715/MOD11_User_Guide_V61.pdf` | V | Entrada vaga reemplazada por la guía concreta: Wan (2019), *Collection-6 MODIS LST Products Users' Guide*, ERI-UCSB, distribuida para C6.1. Se agrega el DOI del conjunto MOD11A1 v061 (página oficial) y Wan (2014) (Crossref). Guía de MOD21: T. |
| Schaaf et al. (2002), RSE 83, 135–148 | Crossref `10.1016/S0034-4257(02)00091-3` | V | Agregado el número 1–2 y autores. |
| Myneni et al. (2002), RSE 83, 214–231 | Crossref `10.1016/S0034-4257(02)00074-3` | V | Agregado el número 1–2 y autores. |
| Huete et al. (2002), RSE 83, 195–213 | Crossref `10.1016/S0034-4257(02)00096-2` | V | Agregado el número 1–2 y autores. |
| Liang (2001), RSE 76, 213–238 | Crossref `10.1016/S0034-4257(00)00205-4` | V | Agregado el número 2. Crossref omite el subtítulo "Algorithms" (sí figura en la bibliografía de Olmedo et al., 2016). |
| Terra/Aqua, deriva orbital (fuente oficial) | Página oficial NASA Earthdata, aviso del 2025-05-02 | V | `TODO: identify official source` resuelto. |
| Brunsdon, Fotheringham & Charlton (1996), Geogr. Anal. 28(4), 281–298 | Crossref `10.1111/j.1538-4632.1996.tb00936.x` | V | — |
| Fotheringham, Brunsdon & Charlton (2002), libro, Wiley | Crossref sin registro del libro; título y autores en la reseña de O'Sullivan (2003), `10.1111/j.1538-4632.2003.tb01114.x` | P | Año, editorial e ISBN sin confirmar. |
| Hurvich, Simonoff & Tsai (1998), JRSS-B 60(2), 271–293 | Crossref `10.1111/1467-9868.00125` | V | Nombre completo de la serie: "Series B (Statistical Methodology)". |
| Gollini et al. (2015), JSS 63(17) | Crossref `10.18637/jss.v063.i17` | V | Sin paginación (número de artículo). |
| Fotheringham, Yang & Kang (2017), AAAG 107(6), 1247–1265 | Crossref `10.1080/24694452.2017.1352480` | V | — |
| Allen, Trezza & Tasumi (2006), AFM 139, 55–73 | Crossref `10.1016/j.agrformet.2006.05.012` | V | Agregado el número 1–2. |
| Allen, Pereira, Raes & Smith (1998), FAO-56 | Página oficial FAO `https://www.fao.org/4/x0490e/x0490e00.htm` | V | ISBN 92-5-104219-5; FAO, Roma, 1998; URL de acceso abierto registrada (ver §5). Sin DOI. |
| Bastiaanssen (2000), J. Hydrol. 229, 87–100 | Crossref `10.1016/S0022-1694(99)00202-4` | V | Confirma el DOI "candidato" de `soil-heat-flux.md`. Agregado el número 1–2. |
| Paulson (1970), J. Appl. Meteorol. 9, 857–861 | Crossref `10.1175/1520-0450(1970)009<0857:TMROWS>2.0.CO;2` | V | Agregado el número 6. |
| Webb (1970), QJRMS 96, 67–90 | Crossref `10.1002/qj.49709640708` | V | Agregado el número 407. |
| Brutsaert (1982), *Evaporation into the Atmosphere*, Reidel | Crossref `10.1007/978-94-017-1497-6` | V | Crossref lista Springer Netherlands (Dordrecht), sucesora de Reidel. Subtítulo agregado desde una bibliografía secundaria, marcado como no verificado. |
| ASCE-EWRI (2005), *The ASCE Standardized Reference ET Equation* | Crossref `10.1061/9780784408056` (monografía) | V | Autoría corporativa (Technical Committee on Standardization of Reference Evapotranspiration) con editores Allen, Walter, Elliott, Howell, Itenfisu, Jensen y Snyder; ASCE, Reston, VA. |
| Allen et al. (2013), JAWRA 49(3), 563–576 | Crossref `10.1111/jawr.12056` | V | Resuelve la asignación de DOI. |
| Morton et al. (2013), JAWRA 49(3), 549–562 | Crossref `10.1111/jawr.12054` | V | Resuelve la asignación de DOI. |
| Twine et al. (2000), AFM 103, 279–300 | Crossref `10.1016/S0168-1923(00)00123-4` | V | Agregado el número 3 y autores. |
| Wilson et al. (2002), AFM 113, 223–243 | Crossref `10.1016/S0168-1923(02)00109-0` | V | Agregado el número 1–4. |
| Gupta et al. (2009), J. Hydrol. 377, 80–91 | Crossref `10.1016/j.jhydrol.2009.08.003` | V | **Título truncado** en la entrada original; completado con ": Implications for improving hydrological modelling". Agregado el número 1–2. |
| Willmott (1981), Phys. Geogr. 2, 184–194 | Crossref `10.1080/02723646.1981.10642213` | V | Agregado el número 2. |
| Roberts et al. (2017), Ecography 40, 913–929 | Crossref `10.1111/ecog.02881` | V | Agregado el número 8. |
| Olmedo et al. (2016), R Journal 8(2), 352–369 | Crossref `10.32614/RJ-2016-051` (página inicial) + página oficial (páginas 352–369, autores) | V | **Autor corregido:** "Fonseca, D." → "Fonseca-Luengo, D." (página del artículo; el PDF imprime "Fonseca-Luego", errata; Crossref registra el nombre desordenado). |
| `water`: estado en CRAN | Página oficial CRAN | V | Archivado el 2021-10-05; última versión en CRAN 0.8 (2018-04-24). Resuelve `TODO: verify CRAN status`. Los datos de v1.0 en GitHub no se reconfirmaron (github.com bloqueado). |
| Otras implementaciones de balance de energía | — | T | `TODO: identify and verify`. |

### 2.2 Referencias agregadas (citadas en `specs/` o `SCIENTIFIC_SPEC.md`)

| Referencia | Citada en | Evidencia (2026-11-04) | Estado |
|---|---|---|---|
| Tasumi, Allen & Trezza (2008), J. Hydrol. Eng. 13(2), 51–63 | Bibliografía de Olmedo et al. (2016) (albedo); pedido de la auditoría | Crossref `10.1061/(ASCE)1084-0699(2008)13:2(51)` | V |
| Allen, Tasumi, Trezza & Kjaersgaard (2010), manual de aplicaciones METRIC v2.0.5 | Bibliografía de Olmedo et al. (2016), p. 363 | Solo cita secundaria; sitio de la University of Idaho bloqueado | T |
| Majumdar, Mathur & Kaushik (1972), Solar Energy 13(4), 383–394 | `radiation-components.md` (citada por `water`) | Crossref `10.1016/0038-092X(72)90004-7` | V (la cita que da `water` es correcta) |
| Allen (1996), JIDE 122(2), 97–106 | `radiation-components.md` (citada por `water` sin cita completa) | Crossref `10.1061/(ASCE)0733-9437(1996)122:2(97)` | V (cita); identificación como fuente de la transmisividad "extendida": T |
| Bastiaanssen (1995), tesis doctoral, Wageningen | `radiation-components.md` | Crossref `10.18174/206553` (tipo *dissertation*, aprobada en 1995, "Agricultural University") | V |
| Allen, Hartogensis & de Bruin (2000), informe RAPID | `radiation-components.md` ("Allen, 2000, informe interno") | Solo cita secundaria (bibliografía de Wasti, 2020) | T (identificado, no verificado) |
| Liu & Jordan (1960), Solar Energy 4(3), 1–19 | `radiation-components.md` (modelo isotrópico) | Crossref `10.1016/0038-092X(60)90062-1` | V |
| Liu & Jordan (1963), Solar Energy 7(2), 53–74 | idem | Crossref `10.1016/0038-092X(63)90006-9` | V; cuál es la fuente del modelo isotrópico: T |
| Duffie & Beckman (2013), Wiley | `radiation-components.md` | Crossref `10.1002/9781118671603` | V |
| Duffie, Beckman & Blair (2020), Wiley | idem (edición posterior) | Crossref `10.1002/9781119540328` | V |
| Spencer (1971), *Search* 2(5), 172 | `radiation-components.md` | Sin registro en Crossref | T |
| Tiesinga, Mohr, Newell & Taylor (2021), CODATA 2018, Rev. Mod. Phys. 93(2), 025010 | `radiation-components.md` | Crossref `10.1103/RevModPhys.93.025010` | V |
| idem, J. Phys. Chem. Ref. Data 50(3), 033105 | idem | Crossref `10.1063/5.0064853` | V |
| Rouse, Haas, Schell & Deering (1974), NASA SP-351 | `SCIENTIFIC_SPEC.md` (NDVI) | Sin registro en Crossref; ntrs.nasa.gov bloqueado | T |
| Wan (2014), RSE 140, 36–45 | Complemento de la guía LST | Crossref `10.1016/j.rse.2013.08.027` | V |
| Conjunto MOD11A1 v061 (Wan, Hook & Hulley, 2021) | Complemento de la guía LST | Página oficial NASA Earthdata (DOI `10.5067/MODIS/MOD11A1.061`) | V |
| Wasti (2020), tesis de maestría, arXiv:2007.13922 | `ef_net_radiation.md` | Documento (página de arXiv y PDF v2) | V |
| Hipps (1989), RSE 27(3), 337–342 | Fuente citada por Wasti (2020) para Rn | Crossref `10.1016/0034-4257(89)90093-X` | V |
| Brunsell & Gillies (2002), PE&RS 68(12), 1263–1270 | Fuente citada por Wasti (2020) para Rn | Sin registro en Crossref | T |
| Irradiancia solar total reciente; descomposición directa/difusa; regresión de emisividad MODIS | `radiation-components.md` §10 | — | T (`TODO: identify`) |

### 2.3 Recuento

- Referencias con estado **V**: 43 (incluye los DOI de anclas y el estado
  de `water` en CRAN como registros separados).
- **P:** 1 (Fotheringham et al., 2002).
- **T:** 11 (manual METRIC; Tasumi, 2003; guía MOD21; Rouse et al., 1974;
  informe RAPID; Spencer, 1971; Brunsell & Gillies, 2002; tres fuentes aún
  sin identificar; otras implementaciones).
- Entradas preexistentes con **corrección de metadatos** (además del DOI):
  7 (Gupta et al., 2009, título; Olmedo et al., 2016, autor; Wan, guía
  concreta; Bastiaanssen et al., 1998, puntuación del título; Hurvich et
  al., 1998, nombre de la serie; ASCE-EWRI, 2005, autoría y editores;
  Brutsaert, 1982, lugar y editorial). Otras 15 solo se completaron con
  número de fascículo o lista de autores.
- No se encontraron años, volúmenes ni páginas erróneos en las entradas
  preexistentes.

## 3. Discrepancias encontradas

1. **Gupta et al. (2009):** título truncado (faltaba el subtítulo).
2. **Olmedo et al. (2016):** el cuarto autor figuraba como "Fonseca, D.";
   el nombre correcto es "Fonseca-Luengo, D." (`SCIENTIFIC_SPEC.md` §9 ya
   lo escribía bien). El PDF del artículo imprime "Fonseca-Luego" (errata
   del PDF) y Crossref registra el nombre desordenado; se adopta la forma de
   la página oficial del artículo.
3. **ASCE-EWRI (2005):** Crossref la registra como monografía de autoría
   corporativa (comité técnico) con siete editores (incluye a Snyder, que no
   aparece en algunas citas secundarias).
4. **Liang (2001) y Brutsaert (1982):** Crossref omite los subtítulos; no es
   un error de la entrada, pero el subtítulo de Brutsaert no quedó
   verificado.
5. **arXiv:2007.13922:** `ef_net_radiation.md` la describe como "estudio
   aplicado de METRIC publicado en arXiv (2020)". Es una **tesis de
   maestría** (Wasti, University of Chinese Academy of Sciences, mayo de
   2020) depositada en arXiv, y atribuye la ecuación de Rn a Brunsell &
   Gillies (2002) y Hipps (1989), no a Allen et al. (2007) (§4.2).
6. **Olmedo et al. (2016) no presenta la ecuación de Rn** (§4.1): la
   corroboración de `ef_net_radiation.md` proviene del **código** de
   `water`, no del artículo.
7. **`soil-heat-flux.md`** afirma que Crossref estaba bloqueado; en esta
   sesión estuvo accesible y confirmó los DOI.

## 4. Ecuación de radiación neta: evidencia

### 4.1 Olmedo et al. (2016), *The R Journal* 8(2), 352–369

- Cita confirmada (§2.1). DOI `10.32614/RJ-2016-051`.
- El artículo **no** escribe la ecuación de Rn. Lo único explícito es:
  - Ec. (1), p. 353: `LE = Rn − G − H`, con Rn definida como "net
    radiation (W·m⁻²)" "calculated considering information obtained at the
    time of satellite overpass"; remite a Allen, Tasumi & Trezza (2007)
    para las ecuaciones de METRIC.
  - p. 361 (sección "Net Radiation estimation", procedimiento avanzado): la
    llamada `Rn <- netRadiation(LAI, albedo, Rs.inc, Rl.inc, Rl.out)`
    precedida de `outLWradiation(LAI, Ts)` e `incLWradiation(...)`; no hay
    fórmula.
- Fuente citada: Allen, Tasumi & Trezza (2007).
- Dato lateral (Apéndice 6.3, atribuido a Allen et al., 2007): emisividad
  de banda angosta ε_NB = 0.97 + 0.0033·LAI (0.98 si LAI > 3), para Ts con
  Landsat 7. No es la ε₀ de banda ancha.
- Conclusión: el artículo no aporta corroboración independiente de la
  forma de Rn; solo confirma que `water` delega la ecuación en
  `netRadiation()` y en Allen et al. (2007).

### 4.2 Wasti (2020), arXiv:2007.13922

- Cita: Wasti, S. (2020). *Estimation of land surface evapotranspiration
  in Nepal using Landsat based METRIC model*. Tesis de maestría
  (Atmospheric Physics and Atmospheric Environment), University of Chinese
  Academy of Sciences, Institute of Tibetan Plateau Research; fechada en
  mayo de 2020. arXiv v1 2020-07-28, v2 2020-08-01 (versión leída: v2;
  90 páginas). Autora única.
- **Ecuación (2.6)**, §2.4.1 "Net radiation", p. 24 impresa (p. 38 del PDF):

  `Rn = RS↓ − α·RS↓ + RL↓ − RL↑ − (1 − εo)·RL↓`

  con RS↓ onda corta entrante de banda ancha, RL↓ onda larga entrante, RL↑
  onda larga saliente, εo emisividad térmica superficial de banda ancha y α
  albedo. Es la misma forma de cuatro términos de `ef_net_radiation.md`.
- **Fuentes citadas para (2.6):** Brunsell & Gillies (2002) y Hipps (1989).
  Allen et al. (2007) se cita en la misma sección para METRIC y para
  cos θ_rel (Ec. 2.9), no para (2.6).
- Términos asociados en el mismo documento:
  - (2.7) RS↓ = Gsc·cos θ_rel·τsw / d², Gsc = 1367 W m⁻².
  - (2.11) τsw = 0.35 + 0.627·exp[−0.00146·P/(Kt·cos θ_hor) −
    0.075·(W/cos θ_hor)^0.4], atribuida a ASCE-EWRI (2005).
  - (2.16), p. 26: RL↑ = εo·σ·Ts⁴, σ = 5.67 × 10⁻⁸ W m⁻² K⁻⁴.
  - (2.17): εo = 0.95 + 0.01·LAI (LAI ≤ 3); 0.98 (LAI > 3), según Tasumi
    (2003).
  - (2.24), p. 28: RL↓ = εa·σ·Ts⁴ (usa Ts, temperatura de superficie).
  - (2.25): εa = 0.85·(−ln τsw)^0.09, según "Allen et al., 2000" y
    Bastiaanssen (1995).
- Independencia: no depende de `water` (otra implementación y otra
  cadena de citas), por lo que sí es una corroboración secundaria
  independiente de la **forma**. No es fuente primaria.

### 4.3 Acceso a la fuente primaria (Allen, Tasumi & Trezza, 2007) y al manual

- ascelibrary.org: bloqueado (no se intentó por indicación previa).
- Copia alojada por una agencia estatal (Montana DNRC, `dnrc.mt.gov`)
  identificada por búsqueda web: **bloqueada** por el proxy (403).
- Sitios de la University of Idaho (`www.kimberly.uidaho.edu`) y de IDWR
  (`idwr.idaho.gov`): **bloqueados** (403).
- No se usaron sitios de distribución no autorizada.
- Resultado: **no se leyó** el texto primario; no hay página ni número de
  ecuación verificados. `ef_net_radiation` debe seguir en `CANDIDATA
  (corroborada)`.

## 5. FAO-56: cita y números de ecuación verificados

Cita (página oficial): Allen, R. G., Pereira, L. S., Raes, D., & Smith, M.
(1998). *Crop evapotranspiration — Guidelines for computing crop water
requirements*. FAO Irrigation and Drainage Paper 56. FAO, Roma. ISBN
92-5-104219-5. Edición electrónica de acceso abierto:
<https://www.fao.org/4/x0490e/x0490e00.htm> (`/3/x0490e/` redirige allí).
Capítulo 3: <https://www.fao.org/4/x0490e/x0490e07.htm>.

Leído en el capítulo 3 (las ecuaciones son imágenes; los coeficientes se
confirmaron en el texto o en los ejemplos resueltos):

| Magnitud | Ec. FAO-56 | Confirmación en el texto |
|---|---|---|
| Presión atmosférica P(z) | 7 | Ejemplo 2: P = 101.3·[(293 − 0.0065·z)/293]^5.26 |
| Ra diaria, Gsc | 21 | "Gsc solar constant = 0.0820 MJ m⁻² min⁻¹" |
| Latitud en radianes | 22 | — |
| dr | 23 | Ejemplo 8: dr = 1 + 0.033·cos(2π·J/365) |
| δ | 24 | Ejemplo 8: δ = 0.409·sin(2π·J/365 − 1.39) |
| ωs | 25 | ωs = arccos[−tan(φ)·tan(δ)] |
| Ra horaria | 28 | — |
| ω (punto medio) | 31 | Lz y Lm en **grados al oeste de Greenwich** |
| Sc | 32 | Sc = 0.1645·sin(2b) − 0.1255·cos(b) − 0.025·sin(b) |
| b | 33 | Ecuación en imagen; coeficientes no leídos como texto |
| Rso = (0.75 + 2·10⁻⁵·z)·Ra | 37 | Texto explícito |
| Rnl (σ diaria = 4.903 × 10⁻⁹ MJ K⁻⁴ m⁻² d⁻¹) | 39 | Texto explícito |

## 6. Guía MODIS LST: hora de observación

Guía C6/C6.1 (Wan, 2019), §3 (MOD11A1), p. 16 del PDF: `Day_view_time` y
`Night_view_time` están en **hora solar local**, definida como hora UTC +
longitud de la celda en grados / 15 (en horas, ±24 para quedar en [0, 24)).
Codificación: uint8, escala 0.1 h, rango válido 0–240, relleno 255. La
definición no incluye la ecuación del tiempo (hora solar media), lo que es
relevante para `radiation-components.md` (§4.4 y §6.1, ángulo horario).

## 7. Pendientes no verificables en esta sesión

- Allen, Tasumi & Trezza (2007): contenido (ecuaciones y páginas).
- Manual de aplicaciones METRIC (v2.0.5 u otra versión).
- Tasumi (2003), tesis doctoral.
- Allen, Hartogensis & de Bruin (2000), informe RAPID.
- Rouse et al. (1974); Spencer (1971); Brunsell & Gillies (2002).
- Fotheringham et al. (2002): año, editorial e ISBN.
- Guía de usuario MOD21.
- Atribución de "Allen (1996)" como fuente de la transmisividad extendida.
- Cuál obra de Liu & Jordan es la fuente del modelo isotrópico; edición de
  Duffie & Beckman a usar.
- Fuentes aún no identificadas: irradiancia solar total reciente,
  descomposición directa/difusa, regresión de emisividad MODIS, otras
  implementaciones.

## 8. Correcciones necesarias en otros archivos (no editados aquí)

### `dev/specs/ef_net_radiation.md`

- §2.2 y §2.3: el DOI `10.1061/(ASCE)0733-9437(2007)133:4(380)` está
  confirmado por Crossref (2026-11-04); quitar `TODO: confirmar DOI` y
  cerrar **D4**.
- §2.2, "Fuente secundaria 2": reemplazar por la cita completa de Wasti
  (2020), tesis de maestría, arXiv:2007.13922 v2, Ec. (2.6), p. 24;
  indicar que la atribuye a Brunsell & Gillies (2002) y Hipps (1989) y que
  usa RL↑ = εo·σ·Ts⁴ (Ec. 2.16) con la misma εo. Quitar "arxiv.org no
  accesible".
- §2.2: aclarar que la "Fuente secundaria 1" es el **código** de `water`;
  el artículo de Olmedo et al. (2016) no escribe la ecuación (§4.1).
- §2.3 y **D3**: se mantienen; estado `CANDIDATA (corroborada)` (la fuente
  primaria sigue sin leerse).

### `dev/specs/radiation-components.md`

- §10: las referencias marcadas "(nueva)" ya están en `REFERENCES.md`
  (Majumdar et al., 1972; Allen, 1996; Bastiaanssen, 1995; Allen et al.,
  2000; Duffie & Beckman; Liu & Jordan; Spencer, 1971; CODATA 2018).
- §5 (tabla de constantes, σ) y §6.6: citar CODATA 2018 como Tiesinga et al.
  (2021), Rev. Mod. Phys. 93, 025010, `10.1103/RevModPhys.93.025010`.
- §5 (Gsc, P(z), Rso, δ, dr, Sc), §6.1, §6.2 y §6.3 B: números de
  ecuación FAO-56 verificados (§5): P Ec. 7; Gsc en Ec. 21; dr Ec. 23; δ
  Ec. 24; ωs Ec. 25; ω Ec. 31 (Lz, Lm al oeste de Greenwich); Sc Ec. 32 y
  b Ec. 33 (coeficientes 81 y 364 no confirmados como texto); Rso Ec. 37.
- §6.3 A (τ_sw): Majumdar et al. (1972) confirmada tal como la cita
  `water` (*Solar Energy* 13(4), 383–394); Allen (1996) identificada como
  JIDE 122(2), 97–106 solo de forma probable. La variante comentada en
  `water`, τ_sw = 0.35 + 0.627·exp(...), aparece también en Wasti (2020),
  Ec. 2.11, atribuida a ASCE-EWRI (2005) (sigue sin verificarse en
  ASCE-EWRI).
- §6.5 (RL↓): "Allen (2000), informe interno" corresponde, según Wasti
  (2020), a Allen, Hartogensis & de Bruin (2000), *Long-wave radiation over
  alfalfa during the RAPID field campaign in southern Idaho* (no
  verificado). Wasti (2020), Ec. 2.24, usa Ts en RL↓: otra fuente
  secundaria con la opción (c) de RC-12.
- §6.6 (ε₀): Wasti (2020), Ec. 2.17, usa ε₀ = 0.95 + 0.01·LAI citando a
  Tasumi (2003), igual que `water`. Olmedo et al. (2016), Apéndice 6.3,
  usa ε_NB = 0.97 + 0.0033·LAI para la recuperación de Ts (banda angosta).
- §4.4, hora de paso MODIS (`TODO` sobre hora solar media o aparente):
  la guía define `view_time` como UTC + longitud/15 (§6 de esta
  auditoría).
- §6.1 y §6.4, Duffie & Beckman: indicar edición (2013,
  `10.1002/9781118671603`, o 2020, `10.1002/9781119540328`).

### `dev/specs/soil-heat-flux.md`

- §2 (fuentes consultadas) y §3.1 (fila "Origen"): Crossref estuvo
  accesible el 2026-11-04; DOI de Bastiaanssen (2000)
  `10.1016/S0022-1694(99)00202-4` y de Allen et al. (2007) confirmados;
  quitar "DOI candidato" y "no verificado" en lo referido a la cita (las
  ecuaciones siguen sin verificar).
- §10, puntos 1 y 8: cita y DOI resueltos; Tasumi (2003) sigue pendiente.

### `dev/SCIENTIFIC_SPEC.md`

- Tabla de variables (NDVI): Rouse et al. (1974) ya figura en
  `REFERENCES.md`, aún como `TODO`.
- Tabla de variables (Rn): el DOI de Allen et al. (2007) está verificado;
  el número de ecuación sigue en `TODO`.

## 9. Hosts no accesibles (2026-11-04)

Bloqueados por el proxy de salida (no se reintentó): `research.wur.nl`,
`www.dnrc.mt.gov`, `www.kimberly.uidaho.edu`, `idwr.idaho.gov`,
`ntrs.nasa.gov`; además, por indicación previa, `ascelibrary.org`,
`github.com` y `modis.gsfc.nasa.gov`. Crossref respondió con límite de
tasa (HTTP 429) en dos consultas, que se repitieron con pausas más largas.
