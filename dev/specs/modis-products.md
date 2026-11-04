# EarthFlux — Especificación: productos MODIS → variables de superficie

Estado: **borrador M1; implementado en M4** (bloque de estado abajo) ·
Componente: `surface` · Archivos: `R/io-modis.R`, `R/modis-qa.R`,
`R/prep-modis.R`, `R/modis-surface.R`, `R/io-aoi.R` · Tests:
`tests/testthat/test-modis*.R`, `test-surface-chain.R`

> Este documento detalla la sección 4 ("Productos MODIS candidatos") y las
> filas Ts, NDVI, LAI, α y ε₀ de la tabla de variables de
> `SCIENTIFIC_SPEC.md` (§3), además de §2.3 (escala espacial) y §2.4
> (continuidad de MODIS). Implementa los principios 1–2 y el contrato de
> datos de `surface` de `ARCHITECTURE.md` (§1, §4). `SCIENTIFIC_SPEC.md`
> sigue siendo la fuente de verdad: cuando un valor o una ecuación de este
> documento se adopte, debe trasladarse allí.

Revisión documental: **2026-11-04**. Todas las fuentes de §2 se leyeron en
esa fecha.

> **Estado de implementación (M4, 2026-11-04; bloque único tras la
> armonización de M4).** Implementado como funciones internas (`@noRd`,
> prefijo `modis_`) en `R/io-modis.R` (tabla, DOI, nombres de archivo,
> lectores, mosaico, escalado), `R/modis-qa.R` (decodificación QA, flags
> `EF_SURF_*`, política QA y conversores), `R/prep-modis.R` (hora de paso,
> banda ancha, NDVI desde reflectancia, desfase y agregación),
> `R/modis-surface.R` (ensamblaje del estado de superficie y procedencia) y
> `R/io-aoi.R` (AOI y límite de Cauquenes). Tests:
> `tests/testthat/test-modis.R` (S1–S10, Q1–Q5, MODLAND 00/01/10/11, LAI
> 253, política), `test-modis-io.R` (GeoTIFF y HDF4 sintéticos; los de
> HDF4 se omiten sin el driver), `test-modis-prep.R` (V1–V4, N1, G1,
> vector = ráster), `test-modis-surface.R` (estado de superficie, flags
> positivos y negativos, política, AOI, procedencia) y
> `test-surface-chain.R` (de extremo a extremo hasta Rn y G). Decisiones:
> M4-01 … M4-30 de `DECISIONS.md` §1.4 (M4-27 … M4-30: decisiones del
> autor del 2026-11-04 sobre la escena de ejemplo, el LAI de las clases no
> vegetadas y la preparación de E1); abiertas A-M4-1 … A-M4-7 (A-M4-6
> actualizada).
>
> 1. **Tabla única** (§13.1; M4-01): `modis_product_spec(product,
>    collection = "061")` y `modis_layer_spec(product, layer, collection =
>    "061")` devuelven filas de `modis_product_table()` (construida una vez
>    por sesión) con columnas `product`, `collection`, `layer`,
>    `sds_alternatives`, `grid`, `resolution`, `cells_per_tile`,
>    `data_type`, `kind`, `conversion`, `scale`, `offset`, `valid_min`,
>    `valid_max`, `fill`, `special_min`, `special_max`, `special_flag`,
>    `unit`, `qa_table`, `status`, `source`, `note`, `physical_min`,
>    `physical_max`. Solo filas `VERIFICADA` con su cita; colección 061
>    (MP-13). Capas con hechos `TODO` → `earthflux_modis_unsupported`. DOI
>    por producto en `modis_product_doi()` (M4-25).
> 2. **Escalado** (§11.3, MP-11; M4-02): `modis_apply_scale(dn,
>    spec_row)` con las convenciones `scale_offset` (D10), `offset_scale`
>    (D8/D9) y `scale_only`; relleno, fuera de rango y códigos especiales →
>    `NA` con máscaras. Lectores con `raw = TRUE`, DN enteros dentro del
>    tipo y escala del archivo contrastada con la tabla.
> 3. **QA** (§10.4; M4-03, M4-04): `modis_qa_field()`,
>    `modis_qa_decode()`, `modis_qa_masks()`, `modis_qa_flags()`;
>    correspondencia campo → código según §10.2; campos sin fila se
>    decodifican sin flag; bits 3–2 de `QC_Day` sin decodificar (d2).
> 4. **Política** (§10.3, MP-09 abierta; M4-05): `qa_policy` = `"flag"` o
>    `"mask"` sin defecto; `NA` obligatorio solo por relleno, rango,
>    MODLAND 10/11 y LAI 249–254 (salvo LAI asignado explícitamente con
>    `lai_nonveg`, M4-28); `"mask"` con `mask_codes` explícitos y conteo.
> 5. **Conversores** (§13.2; M4-09): `modis_variable()` (motor común),
>    `modis_lst()`, `modis_view_zenith()`, `modis_band_emissivity()`,
>    `modis_lai()` (con la opción `lai_nonveg`, M4-28; `check_lai_nonveg()`),
>    `modis_land_cover()`.
> 6. **I/O** (§11; M4-06, M4-07): `modis_parse_filename()`,
>    `modis_list_layers()`, `modis_read_raw(path, layers, aoi)`,
>    `modis_read_converted(path, product, layer, scaled, aoi)` (MP-10),
>    `modis_mosaic_tiles()`; geometría sinusoidal contrastada en cada
>    lectura HDF4. Sin descargas ni credenciales en el paquete (§11.5).
> 7. **Preparación** (§6, §8, §9; M4-11 … M4-18): `modis_overpass_time()`
>    (hora solar media → `doy` + `utc_hour` UTC, sin ecuación del tiempo),
>    `modis_cell_lonlat()`, `modis_albedo()` (A1–A3),
>    `modis_broadband_emissivity()` (E3), `modis_ndvi_from_reflectance()`,
>    `modis_match_composite()` (T1, T2, T4/T5) y `modis_to_grid()`
>    (agregación por factor entero); opciones `TODO` →
>    `earthflux_method_not_implemented`; listas de opciones únicas en
>    `modis_*_methods()`.
> 8. **Estado de superficie** (§1, §13.2; M4-19 … M4-24):
>    `modis_surface_state(files, aoi, options)` con `modis_source()`
>    (HDF4 oficial o convertidos declarados, período del compuesto) y
>    `modis_surface_options()` (todas las elecciones científicas sin
>    defecto; `lai_nonveg = NULL` conserva el `NA` documentado) devuelve
>    `earthflux_surface_state` en la grilla de 1 km de la LST: `lst`,
>    `albedo`, `ndvi`, `lai`, `emissivity`, `band_emissivity` (`Emis_31`,
>    `Emis_32` de MOD11A1/MYD11A1, llevadas para E1 sin usarse, M4-30),
>    `overpass_time` (`doy`, `utc_hour`, `time`), `lonlat`, `qa` (palabra
>    de flags por capa,
>    fracciones válidas, desfases, política), `units`, `flags` (con
>    `target`) y `provenance` (`modis_provenance()`, M4-25). Traspaso al
>    núcleo y exclusiones: `ARCHITECTURE.md` §4 y `surface_exclusion()`.
> 9. **Flags** (`flags.md` §4.2, §6.4; M4-08, M4-22): `ef_flags_surface()`
>    registra 15 códigos (bits 1–15): los 12 de clase I de los
>    decodificadores, `EF_SURF_OVERPASS_MISSING` (clase I, donde falta la
>    hora de paso y la LST es válida), `EF_SURF_ALBEDO_GT1` (clase III,
>    `critical`, contraparte `earthflux_domain_error`, valor conservado y
>    excluido antes de G y Rn) y `EF_SURF_LAI_ASSIGNED` (clase I, `info`,
>    bit 15: LAI de clase no vegetada asignado con `lai_nonveg`, en
>    `flags_lai` y `flags_emissivity`; M4-29). Los 7 de clase II siguen sin
>    registrar.
> 10. **Datos de ejemplo** (§12, MP-12; M4-26): límite de la provincia de
>    Cauquenes en `inst/extdata/cauquenes-province.gpkg` (DPA 2023, desde
>    `thermify`) con `aoi_cauquenes()`; script reproducible
>    `data-raw/modis-example.R` (CMR + LP DAAC con `EARTHDATA_TOKEN` del
>    entorno), con la fecha **2019-02-15** (Terra, decisión del autor,
>    M4-27) y `lai_nonveg = 0` (M4-28). **Pendiente**: ejecutar el script en
>    un entorno con `EARTHDATA_TOKEN` y acceso a los dominios de Earthdata y
>    versionar `inst/extdata/modis-example/` (comando y salidas esperadas en
>    §12); contraste con granulos reales (§16; A-M4-3); fixtures de DN
>    crudos reales (`tests/testthat/fixtures/`).
> 11. **E1/E2** (`"split_window_regression"`, `"tes_regression"`): siguen
>    `earthflux_method_not_implemented`; lo que falta para implementarlas
>    está en la lista de §8.2 (M4-30).

---

## 0. Convenciones de este documento

### 0.1 Estados

Se usan dos tipos de estado, porque este documento mezcla **hechos de
producto** (escalas, rellenos, bits) y **ecuaciones**:

| Estado | Aplicado a | Significado |
|---|---|---|
| `VERIFICADA` | Hecho de producto | Leído en esta revisión en un documento oficial (guía de usuario LP DAAC, especificación de archivo LAADS, página de catálogo Earthdata, alerta oficial), con documento y página/tabla citados. **No** implica verificación contra un archivo real: esa verificación es un ítem aparte (§16, "contraste con archivo"). |
| `TODO` | Cualquiera | No leído en una fuente oficial en esta revisión, o fuentes oficiales en conflicto. No implementar. |
| `CANDIDATA` | Ecuación o método | Misma definición de `SCIENTIFIC_SPEC.md`: forma conocida, pendiente de verificar contra la fuente primaria con unidades, dominio y caso numérico. No implementar. |
| `DERIVADA` | Hecho de producto | Resultado aritmético directo de valores `VERIFICADA` (p. ej., rango físico = rango válido × escala + offset). Se muestra el cálculo. |

Ninguna ecuación de este documento está en estado `VERIFICADA` en el
sentido de `SCIENTIFIC_SPEC.md` (Definition of Done, `DEVELOPMENT.md` §3).

### 0.2 Citas

Formato: `[Dn, p. X, Tabla Y]`. "p." es el **número de página del PDF**
(índice del visor, empezando en 1), no el número impreso, porque varias
guías tienen portadas C6.1 añadidas que desplazan la numeración impresa.

### 0.3 Notación

- DN: valor digital almacenado en el archivo (entero).
- Conversión física: `valor = DN · scale + offset` salvo que se indique otra
  convención (ver §11.3: las fuentes oficiales usan **dos** convenciones).
- Bits: bit 0 es el menos significativo en todos los productos revisados.

---

## 1. Alcance y contrato de salida

El módulo `surface` debe entregar, por píxel de la grilla de trabajo, las
variables del contrato de `ARCHITECTURE.md` §4. Este documento especifica
cómo se obtienen desde MODIS:

| Variable del contrato | Unidad | Producto principal candidato | Alternativas | Sección |
|---|---|---|---|---|
| `lst` | K | MOD11A1 / MYD11A1 (`LST_Day_1km`) | MOD21A1D / MYD21A1D (`LST_1KM`) | §5.1, §5.2 |
| `emissivity` (ε₀, banda ancha) | – | Derivada de `Emis_31`/`Emis_32` (MOD11A1) o `Emis_29/31/32` (MOD21A1D) | Empírica desde LAI (METRIC) | §8.2 |
| `albedo` (α, banda ancha) | – | MCD43A3 (`Albedo_BSA_shortwave`, `Albedo_WSA_shortwave`) | Banda angosta → ancha desde MOD09GA | §5.6, §8.1 |
| `ndvi` | – | MOD13A2 / MOD13Q1 (compuesto 16 días) | Calculado desde MOD09GA/MOD09GQ (diario) | §5.3–5.5 |
| `lai` | m² m⁻² | MCD15A2H (`Lai_500m`) | Empírico desde SAVI (CANDIDATA, SPEC §3) | §5.7 |
| `overpass_time` | POSIXct (UTC) | `Day_view_time` (MOD11A1) + longitud del píxel | `View_Time` (MOD21A1D; semántica `TODO`) | §6 |
| `qa` | flags | Bits QA de cada producto | – | §10 |
| Cobertura (apoyo a anclas y rugosidad) | clase | MCD12Q1 (`LC_Type1`) | Cobertura local | §5.8 |

Fuera de alcance: MDE (`elevation`, `slope`, `aspect`), forzamiento
meteorológico, descarga automática de datos (ver §11.5).

Regla arquitectónica (`ARCHITECTURE.md` principio 2): **solo** `io-modis.R`,
`modis-qa.R`, `prep-modis.R` y `modis-surface.R` (los dos últimos desde
M4) conocen escalas, rellenos, bits QA, nombres de SDS y hora de paso de
MODIS. Las funciones `metric-*.R` reciben las variables del
contrato.

---

## 2. Fuentes consultadas

### 2.1 Documentos oficiales leídos

| ID | Documento | Versión / fecha | URL |
|---|---|---|---|
| D1 | *MODIS Collection 6.1 (C61) Product User Guide* (portada C61) + *Collection-6 MODIS Land Surface Temperature Products Users' Guide*, Z. Wan | Junio 2019 (C6; portada indica que C61 es idéntico en formato) | https://lpdaac.usgs.gov/documents/715/MOD11_User_Guide_V61.pdf |
| D2 | *MODIS Land Surface Temperature and Emissivity Product (MxD21) User Guide, Collection 6.1*, G. Hulley, R. Freepartner, N. Malakar, S. Sarkar (JPL) | Abril 2022 | https://lpdaac.usgs.gov/documents/1398/MOD21_User_Guide_V61.pdf |
| D3 | *MODIS C61 LSR Product User Guide* (portada) + *MODIS Surface Reflectance User's Guide, Collection 6*, J. C. Roger, J. P. Ray, E. F. Vermote | Versión 1.5, julio 2020 | https://lpdaac.usgs.gov/documents/925/MOD09_User_Guide_V61.pdf |
| D4 | *MODIS C61 Vegetation Index Product User Guide* (portada) + *MODIS Vegetation Index User's Guide (MOD13 Series)*, K. Didan, A. Barreto Munoz | Versión 3.10, septiembre 2019 (Collection 6.1) | https://lpdaac.usgs.gov/documents/621/MOD13_User_Guide_V61.pdf |
| D5 | *MODIS Collection 6.1 (C6.1) LAI/FPAR Product User's Guide* | Actualizada 21-abr-2020 | https://lpdaac.usgs.gov/documents/926/MOD15_User_Guide_V61.pdf |
| D6 | *MODIS C61 Land Cover Type Product User Guide* (portada) + *User Guide to Collection 6 MODIS Land Cover (MCD12Q1 and MCD12C1) Product*, D. Sulla-Menashe, M. A. Friedl | 20-abr-2022 | https://lpdaac.usgs.gov/documents/1409/MCD12_User_Guide_V61.pdf |
| D7 | *MODIS BRDF/Albedo Product: Algorithm Theoretical Basis Document*, A. H. Strahler et al. | Versión 5.0, abril 1999 | https://lpdaac.usgs.gov/documents/97/MCD43_ATBD.pdf |
| D8 | LAADS DAAC, *MODIS HDF File Specification* MCD43A3 | V6.1.0, Dec-2021 | https://ladsweb.modaps.eosdis.nasa.gov/filespec/MODIS/61/MCD43A3 |
| D9 | LAADS DAAC, *MODIS HDF File Specification* MCD43A2 | V6.1.0, Sep-2019 | https://ladsweb.modaps.eosdis.nasa.gov/filespec/MODIS/61/MCD43A2 |
| D10 | LAADS DAAC, *MOD11A1 Daily 1km L3 LST product specifications* | Version 61, modificada 09/18/2019 | https://ladsweb.modaps.eosdis.nasa.gov/filespec/MODIS/61/MOD11A1 |
| D11 | LAADS DAAC, file specification MOD21A1D_c61 | (sin fecha visible) | https://ladsweb.modaps.eosdis.nasa.gov/filespec/MODIS/61/MOD21A1D_c61 |
| D12 | Páginas de catálogo Earthdata (resumen del producto y tabla *Variables*), consultadas 2026-11-04. Las URL `lpdaac.usgs.gov/products/<producto>v061/` redirigen aquí. | – | `https://www.earthdata.nasa.gov/data/catalog/lpcloud-<producto>-061` para mod11a1, myd11a1, mod21a1d, mod09ga, mod09gq, mod13q1, mod13a2, mcd15a2h, mcd43a3, mcd12q1 |
| D13 | Earthdata, página del instrumento MODIS (sección *Sinusoidal Tile Grid*) | consultada 2026-11-04 | https://www.earthdata.nasa.gov/data/instruments/modis |
| D14 | LAADS DAAC, *Alerts and Issues* (alertas individuales citadas por número) | ver §7 | https://ladsweb.modaps.eosdis.nasa.gov/alerts-and-issues/ |
| D15 | Earthdata, artículo *From Terra to Terra Firma* (enlazado por la alerta LAADS 200051 del 2022-04-21) | fecha de publicación `TODO` | https://www.earthdata.nasa.gov/news/feature-articles/from-terra-to-terra-firma |
| D16 | Páginas de catálogo Earthdata de VIIRS: VJ121 (v002), VNP21 (v001, nota de retiro), VJ143MA3 (v002) | consultadas 2026-11-04 | `https://www.earthdata.nasa.gov/data/catalog/lpcloud-vj121-002`, `…/lpcloud-vnp21-001`, `…/lpcloud-vj143ma3-002` |
| D17 | *CRAN Repository Policy* | Revision 6985 | https://cran.r-project.org/web/packages/policies.html |
| D18 | Página CRAN de `terra` | 1.9-50, publicada 2026-09-08 | https://cran.r-project.org/web/packages/terra/index.html |

### 2.2 Referencias bibliográficas (metadatos verificados, contenido no leído)

Metadatos (autores, revista, volumen, páginas, DOI) verificados vía
`api.crossref.org` el 2026-11-04. **El contenido no fue consultado**; toda
afirmación atribuida a estas obras es `CANDIDATA`/`TODO`.

| Referencia | DOI | Uso en este documento |
|---|---|---|
| Wan, Z., & Dozier, J. (1996). A generalized split-window algorithm for retrieving land-surface temperature from space. *IEEE TGRS*, 34, 892–905. | `10.1109/36.508406` | Algoritmo MOD11 (citado en D1 p. 6) |
| Wan, Z. (2014). New refinements and validation of the collection-6 MODIS land-surface temperature/emissivity product. *Remote Sensing of Environment*, 140, 36–45. | `10.1016/j.rse.2013.08.027` | Refinamientos C6 de MOD11 (citado en D1 p. 5, 9) |
| Wang, K., Wan, Z., Wang, P., Sparrow, M., Liu, J., Zhou, X., & Haginoya, S. (2005). Estimation of surface long wave radiation and broadband emissivity using MODIS land surface temperature/emissivity products. *J. Geophys. Res. Atmos.*, 110, D11. | `10.1029/2004JD005566` | Candidata para ε 31/32 → banda ancha (§8.2) |
| Feltz, M., Borbas, E., Knuteson, R., Hulley, G., et al. (2018). The Combined ASTER and MODIS Emissivity over Land (CAMEL) Global Broadband Infrared Emissivity Product. *Remote Sensing*, 10, 1027. | `10.3390/rs10071027` | Alternativa externa de ε banda ancha (§8.2) |
| Liang, S. (2001). Narrowband to broadband conversions of land surface albedo I: Algorithms. *Remote Sensing of Environment*, 76(2), 213–238. | `10.1016/S0034-4257(00)00205-4` | Coeficientes banda angosta → ancha (§8.1) |
| Liang, S., Shuey, C., Russ, A., Fang, H., Chen, M., Walthall, C., et al. (2003). Narrowband to broadband conversions of land surface albedo: II. Validation. *Remote Sensing of Environment*, 84(1), 25–41. | `10.1016/S0034-4257(02)00068-8` | Ídem |
| Schaaf, C. B., Gao, F., Strahler, A. H., Lucht, W., et al. (2002). First operational BRDF, albedo nadir reflectance products from MODIS. *Remote Sensing of Environment*, 83(1–2), 135–148. | `10.1016/S0034-4257(02)00091-3` | MCD43 |
| Román, M. O., Schaaf, C. B., Lewis, P., Gao, F., et al. (2010). Assessing the coupling between surface albedo derived from MODIS and the fraction of diffuse skylight over spatially-characterized landscapes. *Remote Sensing of Environment*, 114, 738–760. | `10.1016/j.rse.2009.11.014` | Albedo *blue-sky* (§8.1) |
| Tasumi, M., Allen, R. G., & Trezza, R. (2008). At-surface reflectance and albedo from satellite for operational calculation of land surface energy balance. *J. Hydrol. Eng.*, 13(2), 51–63. | `10.1061/(ASCE)1084-0699(2008)13:2(51)` | Albedo en METRIC (§8.1) |
| Myneni, R. B., Hoffman, S., Knyazikhin, Y., Privette, J. L., et al. (2002). Global products of vegetation leaf area and fraction absorbed PAR from year one of MODIS data. *Remote Sensing of Environment*, 83(1–2), 214–231. | `10.1016/S0034-4257(02)00074-3` | MCD15 |
| Huete, A., Didan, K., Miura, T., Rodriguez, E. P., et al. (2002). Overview of the radiometric and biophysical performance of the MODIS vegetation indices. *Remote Sensing of Environment*, 83(1–2), 195–213. | `10.1016/S0034-4257(02)00096-2` | MOD13 |

`TODO`: trasladar a `REFERENCES.md` las citas que se adopten (allí figuran
como `TODO: verify full citation`).

### 2.3 Hosts no accesibles durante la revisión

| Host | Qué se buscaba | Resultado |
|---|---|---|
| `www.umb.edu` | Guía de usuario MCD43 (enlazada desde D12 MCD43A3) | No accesible (HTTP 403). Se usó D7, D8, D9 y D12 en su lugar. |
| `terra.nasa.gov`, `aqua.nasa.gov` | Estado oficial de las misiones | Sin conexión |
| `landweb.modaps.eosdis.nasa.gov` | Notas LDOPE / problemas conocidos C6.1 | Sin conexión |
| `modis.gsfc.nasa.gov`, `cmr.earthdata.nasa.gov`, `github.com` | – | Conocidos como bloqueados; no se intentaron |

No se reintentó ningún host bloqueado.

---

## 3. Colección vigente

| Afirmación | Estado | Fuente |
|---|---|---|
| Los productos de tierra usados aquí se distribuyen como **Collection 6.1 (versión 061)** | `VERIFICADA` | D12 (todas las páginas: "Version 6.1", DOI `10.5067/MODIS/<producto>.061`); portadas C61 de D1–D6 |
| C6.1 no cambia el algoritmo científico respecto de C6 (MOD11, MOD09, MOD13, MOD15); los cambios provienen de calibración L1B y corrección de polarización | `VERIFICADA` | D1 p. 1; D3 p. 1; D4 p. 1; D5 p. 1. MCD12Q1: "no major change" + insumos aguas arriba, D6 p. 1 |
| MOD09 C6.1 cambió la estimación de aerosoles altos; afecta los bits 6–7 del *state QA* (renombrados "aerosol quantity: level of uncertainty in aerosol correction") y productos aguas abajo (VI, BRDF/albedo) | `VERIFICADA` | D3 p. 1 |
| Producción de MOD11 **V6 (C6.0)** Terra discontinuada el 15-nov-2022; se recomienda V6.1 | `VERIFICADA` | D14, alerta 200029 (2022-12-06) |
| MODIS **Version 7.0** L1B (radiancias calibradas y geolocalización) publicada el 2026-03-17; L1B V6.1 se retira el 2026-09-30 | `VERIFICADA` | D14, alerta 199931 |
| Existencia, calendario y cambios de formato de productos de **tierra** C7 (LST, reflectancia, VI, LAI, albedo, cobertura) | `TODO` | No encontrado en las fuentes leídas. Riesgo: migración de nombres de SDS, escalas o formato (ver decisión MP-13) |

Consecuencia: la especificación se fija en **C6.1**; el código debe leer la
colección desde el nombre del archivo y rechazar (error clasificado) una
colección para la cual no exista ficha de producto.

---

## 4. Grilla MODIS común (sinusoidal)

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Proyección | Sinusoidal sobre esfera de radio 6371007.181 m | `VERIFICADA` | D6 p. 4–5 (PROJ4 `+proj=sinu +a=6371007.181 +b=6371007.181 +units=m` y WKT); D13 |
| Teselas | ≈ 10° × 10° en el ecuador; índice (h, v) desde (0, 0) arriba a la izquierda hasta (h35, v17); 460 teselas no vacías | `VERIFICADA` | D13; D5 p. 5–6 (Tabla 3); D3 p. 7 (Fig. 1) |
| Esquina superior izquierda de la grilla global | ULX = −20015109.354 m, ULY = 10007554.677 m | `VERIFICADA` | D6 p. 4 |
| Tamaño de celda "500 m" | 463.312716525 m; 2400 × 2400 celdas por tesela | `VERIFICADA` | D6 p. 4; D5 p. 6 (Tabla 3) |
| Celdas "1 km" por tesela | 1200 × 1200 | `VERIFICADA` | D1 p. 7 (Tabla 1), p. 16; D2 p. 10 (Tabla 1) |
| Tamaño de celda "1 km" | D1 indica "0.928 km by 0.928 km" (p. 16) y "about 1113 km by 1113 km in 1200 rows" (p. 6). Con D6: 2 × 463.312716525 = 926.625433 m | `VERIFICADA` (D1, aproximado) / `DERIVADA` (926.625433 m) | Discrepancia menor (0.928 vs 0.9266 km): **leer siempre la resolución desde el archivo** y comparar con el valor derivado (test) |
| Celdas "250 m" por tesela y tamaño exacto | – | `TODO` | No indicado en D3 |
| Anidamiento 1 km ↔ 500 m | Misma extensión de tesela y 2400 = 2 × 1200 ⇒ cada celda de 1 km contiene exactamente 2 × 2 celdas de 500 m | `DERIVADA` | `TODO`: confirmar con archivos reales que las extensiones coinciden al metro |
| Convención de nombre de archivo | `<SHORTNAME>.AYYYYDDD.hXXvYY.<colección>.<YYYYDDDHHMMSS de producción>.hdf` | `VERIFICADA` | D12 (MCD43A3: "File Naming Convention"); D5 p. 6–7 |
| Metadatos de esquinas | `UpperLeftPointMtrs` / `LowerRightMtrs` en coordenadas de proyección; son las únicas que reflejan exactamente las esquinas | `VERIFICADA` | D13 |

Recomendación (decisión MP-08): trabajar en la grilla sinusoidal nativa de
1 km de la LST y reproyectar, si se requiere, **solo al final**. La latitud
y longitud por píxel (necesarias en `ef_solar_geometry()` y en §6) se
calculan transformando las **coordenadas de los centros de celda**, no
remuestreando valores.

---

## 5. Fichas de producto

Para cada producto: (a) características generales; (b) capas (SDS) que
EarthFlux necesita; (c) bits QA relevantes para enmascarar/marcar;
(d) discrepancias entre fuentes oficiales; (e) uso en EarthFlux.

Formato de archivo de **todos** los productos de esta sección: HDF-EOS
(HDF4) con estructura *grid* — `VERIFICADA`: D1 p. 5; D2 p. 8; D4 p. 8;
D5 p. 6 (Tabla 3); D6 p. 4 ("HDF4 file format"); D12 (extensión `.hdf`).
Grilla: sinusoidal (§4) — `VERIFICADA`: D12 ("MODIS Sinusoidal Tiling
System") para los diez productos.

### 5.1 MOD11A1 (Terra) / MYD11A1 (Aqua) — LST y emisividad, split-window

**(a) Generales**

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Resolución espacial | 1 km nominal (1200 × 1200 celdas por tesela; ver §4) | `VERIFICADA` | D1 p. 7 (Tabla 1), p. 16; D12 |
| Resolución temporal | Diaria; día de datos en **UTC** | `VERIFICADA` | D1 p. 16; D12 ("1 Day") |
| Extensión temporal | MOD11A1: 2000-02-24 → presente; MYD11A1: 2002-07-04 → presente | `VERIFICADA` | D12 |
| DOI | `10.5067/MODIS/MOD11A1.061`, `10.5067/MODIS/MYD11A1.061` | `VERIFICADA` | D12 |
| Algoritmo | Split-window generalizado (Wan & Dozier, 1996) bajo cielo despejado (MOD35: confianza ≥ 95 % sobre tierra ≤ 2000 m; ≥ 66 % sobre tierra > 2000 m; ≥ 66 % sobre lagos) | `VERIFICADA` | D1 p. 16 |
| Emisividades de bandas 31/32 | Estimadas por **clasificación** (Snyder & Wan, 1998) según cobertura (MCDLC1KM) y nieve diaria (MOD10_L2); ajuste prototipo de ±0.0063 en zonas áridas/semiáridas, de signo opuesto en ε31 y ε32 (Wan, 2014) | `VERIFICADA` | D1 p. 9 |
| Grilla HDF-EOS | `MODIS_Grid_Daily_1km_LST` | `VERIFICADA` | D10 (dimensiones `YDim/XDim:MODIS_Grid_Daily_1km_LST`) |
| Aqua | Misma estructura con prefijo MYD | `VERIFICADA` | D1 p. 7 |

**(b) Capas necesarias** — fuente principal: D1 p. 17, Tabla 9; contrastada
con D10 y D12 (coinciden en tipo, escala, offset, rango y relleno).

| SDS | Contenido | Tipo | Escala | Offset | Rango válido (DN) | Relleno | Unidad física | Rango físico (`DERIVADA`) |
|---|---|---|---|---|---|---|---|---|
| `LST_Day_1km` | LST diurna | uint16 | 0.02 | 0.0 | 7500–65535 | 0 | K | 150.00–1310.70 K |
| `QC_Day` | QA diurno (bits, ver c) | uint8 | – | – | 0–255 | sin `_FillValue` (ver nota) | – | – |
| `Day_view_time` | Hora **solar local** de la observación diurna | uint8 | 0.1 | 0 | 0–240 | 255 | h | 0.0–24.0 h; cuantización 0.1 h = 6 min |
| `Day_view_angl` | Ángulo cenital de visión (signo: ver nota) | uint8 | 1.0 | −65.0 | 0–130 | 255 | grados | −65° a +65° |
| `Emis_31` | Emisividad banda 31 | uint8 | 0.002 | 0.49 | 1–255 | 0 | – | 0.492–1.000 |
| `Emis_32` | Emisividad banda 32 | uint8 | 0.002 | 0.49 | 1–255 | 0 | – | 0.492–1.000 |
| `Clear_day_cov` | Cobertura de cielo despejado diurna | uint16 | 0.0005 | 0 | 1–65535 | 0 | – | – |
| `LST_Night_1km`, `QC_Night`, `Night_view_time`, `Night_view_angl`, `Clear_night_cov` | Equivalentes nocturnos (mismos tipos/escalas) | – | – | – | – | – | – | No usados por METRIC; útiles para diagnósticos |

Notas `VERIFICADA`:

- Convención de conversión en D10: `LST = DN · scale_factor`;
  `view_angl = DN · scale_factor + add_offset`;
  `Emis_31 = DN · scale_factor + add_offset` (D10, definiciones de SDS).
- `QC_Day` no tiene `_FillValue`; si `LST_Day_1km` = 0 (relleno), los bits
  1–0 de `QC_Day` valen 10 u 11 y los demás campos con 0 son indefinidos.
  Se debe leer LST y QC juntos (D1 p. 16; D10, nota de `QC_Day`).
- Signo del ángulo de visión: negativo = MODIS observa la celda desde el
  **este**; el cenital en sí es siempre positivo (D1 p. 16–17).
- Selección de observaciones: ver discrepancia (d1).

**(c) Bits QA de `QC_Day` / `QC_Night`** — D1 p. 21, Tabla 13.

| Bits | Campo | Valores |
|---|---|---|
| 1–0 | Mandatory QA | 00 LST producida, buena calidad; 01 producida, otra calidad (examinar QA detallado); 10 no producida por nubes; 11 no producida por otras razones |
| 3–2 | Data quality | **Ver discrepancia (d2)** |
| 5–4 | Error medio de emisividad | 00 ≤ 0.01; 01 ≤ 0.02; 10 ≤ 0.04; 11 > 0.04 |
| 7–6 | Error medio de LST | 00 ≤ 1 K; 01 ≤ 2 K; 10 ≤ 3 K; 11 > 3 K |

**(d) Discrepancias entre fuentes oficiales**

| # | Tema | Fuente A | Fuente B | Estado / acción |
|---|---|---|---|---|
| d1 | Píxeles con varias observaciones (latitud > 30°) | D1 p. 16: se elige **una** observación (menor ángulo cenital de visión, o mayor ángulo si su LST es ≥ 2 K más alta) | D12: el valor es el **promedio** de todas las observaciones que cumplen el criterio | `TODO`. Afecta la interpretación de `Day_view_time` (¿hora de una pasada o hora promediada?). Chile continental está casi entero sobre 30° S. |
| d2 | Bits 3–2 de `QC_Day` | D1 Tabla 13: campo de 2 bits "Data quality flag" (00 buena; 01 otra; 10/11 TBD) | D10: bit 2 = "Data Quality flag", bit 3 = "Snow/Lakeice" según MOD10 | `TODO`. No usar los bits 3–2 hasta resolver con un archivo real y con el equipo del producto. |

**(e) Uso en EarthFlux**

- `lst` [K] desde `LST_Day_1km`; `overpass_time` desde `Day_view_time` (§6).
- `Emis_31`/`Emis_32` como insumo de ε₀ (§8.2). Advertencia: al ser
  emisividades por clasificación (D1 p. 9), aportan poca información
  independiente sobre la superficie real; en zonas áridas su
  incertidumbre es mayor (D1 p. 9).
- `Day_view_angl` como diagnóstico (flag de ángulo alto, umbral `TODO`).

### 5.2 MOD21A1D (Terra) / MYD21A1D (Aqua) — LST y emisividad, TES

Nombre correcto de los productos diarios: **MOD21A1D** (día) y
**MOD21A1N** (noche), no "MOD21A1" — `VERIFICADA`: D2 p. 10 (Tablas 1–2),
p. 22–23.

**(a) Generales**

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Resolución | 1 km; 1200 × 1200 celdas por tesela ("0.928km by 0.928km") | `VERIFICADA` | D2 p. 10, p. 22 |
| Temporal | Diaria, productos separados día/noche | `VERIFICADA` | D2 p. 10, 22 |
| Extensión (MOD21A1D) | 2000-02-24 → presente | `VERIFICADA` | D12 |
| DOI | `10.5067/MODIS/MOD21A1D.061` (y MOD21A1N, MYD21A1D, MYD21A1N) | `VERIFICADA` | D2 p. 10 (Tabla 2); D12 |
| Algoritmo | Temperature and Emissivity Separation (TES); valor diario = promedio ponderado por cobertura de las observaciones despejadas con buena exactitud; solo observaciones con cobertura > 15 %; el byte QA final refleja la **peor** calidad de las observaciones promediadas | `VERIFICADA` | D2 p. 11, 22; D12 |
| Grilla HDF-EOS | `MODIS_Grid_Daily_1km_LST21` | `VERIFICADA` | D11 |
| Compresión interna | Gzip nivel 4 | `VERIFICADA` | D11 |

**(b) Capas** — D2 p. 23, Tabla 9; contrastada con D11 y D12 (coinciden).

| SDS | Tipo | Escala | Offset | Rango válido (DN) | Relleno | Unidad | Rango físico (`DERIVADA`) |
|---|---|---|---|---|---|---|---|
| `LST_1KM` | uint16 | 0.02 | 0.0 | 7500–65535 | 0 | K | 150.00–1310.70 K |
| `QC` | uint16 | – | – | 0–65535 | n/a | – | – |
| `Emis_29`, `Emis_31`, `Emis_32` | uint8 | 0.002 | 0.49 | 1–255 | 0 | – | 0.492–1.000 |
| `View_Angle` | uint8 | 1 | −65 | 0–130 | 255 | grados | −65° a +65° |
| `View_Time` | uint8 | 0.1 | 0 | 0–240 | 255 | h | 0.0–24.0 h |

`View_Time`: D2 (Tabla 9: "Time of MODIS observation") y D11 ("Time of LST
observation") **no indican** si es hora solar local o UTC. En el producto
CMG MxD21C1 la hora se rotula "(UTC)" (D2 p. 32, Tabla 14), lo que impide
suponer que A1 usa la misma convención que MOD11A1. **Semántica `TODO`**
(ver §6.4).

**(c) Bits QA de `QC`** — D2 p. 26–27, Tabla 11 (contrastada con D11).

| Bits | Campo | Valores |
|---|---|---|
| 1–0 | Mandatory QA | 00 buena calidad; 01 calidad nominal (ε31 y ε32 < 0.95, nube cercana o transmisividad baja < 0.4); 10 no producido por nubes; 11 no producido por otras razones |
| 3–2 | Data quality | 00 L1B buena (bandas 29, 31, 32); 01 píxel faltante; 10 calibración aceptable; 11 mala calibración, TES omitido |
| 5–4 | Nubes | 00 despejado; 01 cirros delgados; 10 a ≤ 2 píxeles de nube; 11 nuboso |
| 7–6 | Iteraciones TES | 00 lenta; 01–10 nominal; 11 rápida |
| 9–8 | Opacidad atmosférica | 00 "≥3" (texto de D2/D11; ver d3); 01 0.2–0.3; 10 0.1–0.2; 11 < 0.1 |
| 11–10 | MMD (diferencia mín–máx de emisividad) | 00 > 0.15; 01 0.1–0.15; 10 0.03–0.1; 11 < 0.03 |
| 13–12 | Exactitud de emisividad | 00 > 0.02; 01 0.015–0.02; 10 0.01–0.015; 11 < 0.01 |
| 15–14 | Exactitud de LST | 00 > 2 K; 01 1.5–2 K; 10 1–1.5 K; 11 < 1 K |

**(d) Discrepancias**

| # | Tema | Detalle | Acción |
|---|---|---|---|
| d3 | Bits 9–8, valor 00 | D2 Tabla 11 y D11: "≥3"; D2 Tabla 8 (producto L2): "0.3" | Probable errata; no usar el valor numérico de la categoría 00; `TODO` |
| d4 | Bits 1–0, valor 10 | D2 Tabla 11: "not produced due to cloud"; D11: "Pixel produced, but most probably cloudy" | Tratar como "no utilizable por nubes" en ambos casos; `TODO` confirmar |
| d5 | Umbrales de exactitud (bits 13–12, 15–14) | L2 (Tabla 8, p. 21) y A1 (Tabla 11) usan umbrales distintos | Usar los de A1 (Tabla 11) para MOD21A1D |

**Problemas conocidos `VERIFICADA`:**

- Terra, desde el 29-ago-2006: detector muerto en la banda 29 produce
  bandeo en MOD21 L2; esos píxeles se marcan 11 en bits 1–0 y 3–2 y no
  deben usarse cuantitativamente (D2 p. 20).
- Aqua (MYD21*): tendencia de calentamiento espuria desde ~2018 por
  *crosstalk* electrónico en la banda 29; afecta toda la serie MYD21
  (D14, alerta 199983, 2024-01-17). Estado de la corrección: `TODO`.

**(e) Uso en EarthFlux:** alternativa a MOD11A1 (decisión MP-01). Ventaja:
emisividad recuperada dinámicamente (TES), potencialmente más coherente con
LST en suelos desnudos áridos. Desventajas: semántica de `View_Time` sin
documentar; anomalía MYD21 en Aqua.

### 5.3 MOD09GA — reflectancia superficial diaria 500 m + QA 1 km

**(a) Generales**

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Contenido | Reflectancia superficial bandas 1–7 a 500 m; observación, geometría y *state QA* a 1 km | `VERIFICADA` | D3 p. 14; D12 |
| Nivel | L2G-lite diario | `VERIFICADA` | D3 p. 6 (Tabla 1), p. 14 |
| Temporal / extensión | Diario; 2000-02-24 → presente (Terra) | `VERIFICADA` | D12 |
| Terra/Aqua | "MOD" designa ambos; no hay productos MOD09 combinados | `VERIFICADA` | D3 p. 34 (§4.5) |
| Exactitud típica | ±(0.005 + 0.05·ρ) en condiciones favorables; LUT con límites de 5.0 en espesor óptico de aerosol y 75° en cenital solar | `VERIFICADA` | D3 p. 35 (§5) |

**(b) Capas necesarias** — D3 p. 14–15, Tabla 4; contrastada con D12.

| SDS | Resolución | Tipo | Escala | Rango válido | Relleno | Unidad |
|---|---|---|---|---|---|---|
| `sur_refl_b01_1` (rojo, 620–670 nm) | 500 m | int16 | 0.0001 | −100–16000 | −28672 | reflectancia (–) |
| `sur_refl_b02_1` (NIR, 841–876 nm) | 500 m | int16 | 0.0001 | −100–16000 | −28672 | – |
| `sur_refl_b03_1` … `sur_refl_b07_1` | 500 m | int16 | 0.0001 | −100–16000 | −28672 | – |
| `QC_500m_1` | 500 m | uint32 | – | (ver d6) | 787410671 | bits (D3 Tabla 10) |
| `state_1km_1` | 1 km | uint16 | – | (ver d6) | 65535 | bits (D3 Tabla 13) |
| `SensorZenith_1`, `SolarZenith_1` | 1 km | int16 | 0.01 | 0–18000 | −32767 | grados |
| `num_observations_500m` | 500 m | int8 | – | 0–127 | −1 | – |

Offset: las tablas de D3 no tienen columna de offset y D12 indica "N/A".
`TODO`: confirmar `add_offset` = 0 en los atributos del archivo.

Valores de reflectancia fuera de −100–16000 son L1B sin corregir (p. ej.,
cenital solar alto) o relleno (D3 p. 34, §4.4) — `VERIFICADA`.

**(c) Bits QA**

`state_1km_1` — D3 p. 25–26, Tabla 13:

| Bits | Campo | Valores |
|---|---|---|
| 1–0 | Estado de nubes | 00 despejado; 01 nuboso; 10 mixto; 11 no definido, se asume despejado |
| 2 | Sombra de nube | 1 sí |
| 5–3 | Tierra/agua | 000 océano somero; 001 tierra; 010 costas y orillas; 011 agua interior somera; 100 agua efímera; 101 agua interior profunda; 110 océano continental/moderado; 111 océano profundo |
| 7–6 | Aerosol (incertidumbre de la corrección; C6.1) | 00 climatología; 01 bajo; 10 promedio; 11 alto |
| 9–8 | Cirros | 00 ninguno; 01 pequeño; 10 promedio; 11 alto |
| 10 | Algoritmo interno de nubes | 1 nube |
| 11 | Algoritmo interno de fuego | 1 fuego |
| 12 | Nieve/hielo MOD35 | 1 sí |
| 13 | Adyacente a nube | 1 sí |
| 14 | Salar (*salt pan*) | 1 sí |
| 15 | Máscara interna de nieve | 1 nieve |

`QC_500m_1` — D3 p. 22, Tabla 10: bits 1–0 MODLAND (00 calidad ideal; 01
menor que ideal; 10 no producido por nubes; 11 no producido por otras
razones, puede ser relleno; 11 prevalece sobre 01); bits 2–5, 6–9, …, 26–29
calidad de las bandas 1–7 (0000 máxima calidad; 0111 detector ruidoso;
1000 detector muerto interpolado; 1001 cenital solar ≥ 86°; 1010 cenital
solar 85–86°; 1011 insumo faltante; 1100 constante interna en vez de
climatología; 1101 corrección fuera de límites; 1110 L1B defectuoso; 1111 no
procesado por océano profundo o nubes); bit 30 corrección atmosférica
realizada; bit 31 corrección de adyacencia realizada.

El bit 14 (salar) es relevante en el norte de Chile (salares altiplánicos).

**(d) Discrepancias**

| # | Tema | D3 | D12 | Acción |
|---|---|---|---|---|
| d6 | Rango válido de `state_1km_1` | 0–57343 | 0–57335 | `TODO`; no usar el rango válido para descartar QA; decodificar bits |
| d6b | Rango válido de `QC_500m_1` | NA | 0–4294966019 | Ídem |

**(e) Uso en EarthFlux:** base para NDVI diario propio y para albedo
banda angosta → ancha (alternativas, §8.1, §9.1). Mismo día y misma
plataforma que la LST (p. ej., MOD09GA + MOD11A1 Terra). `TODO`: verificar
que la capa `_1` corresponde a la misma pasada que la LST del día (D3 no lo
establece; el sufijo `_1` y `num_observations` sugieren varias
observaciones por celda).

### 5.4 MOD09GQ — reflectancia superficial diaria 250 m (bandas 1–2)

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Contenido | Bandas 1 y 2 a 250 m; diseñado para usarse **junto con MOD09GA** (QA y geometría) | `VERIFICADA` | D3 p. 13; D12 |
| Temporal / extensión | Diario; 2000-02-24 → presente | `VERIFICADA` | D12 |

Capas — D3 p. 13, Tabla 3; contrastada con D12:

| SDS | Tipo | Escala | Rango válido | Relleno |
|---|---|---|---|---|
| `sur_refl_b01_1`, `sur_refl_b02_1` | int16 | 0.0001 | −100–16000 | −28672 |
| `QC_250m_1` | uint16 | – | D3: 0–8000; D12: 0–4096 (discrepancia, `TODO`) | 2995 |

Bits de `QC_250m_1` — D3 p. 20, Tabla 8: 1–0 MODLAND (mismas claves que
`QC_500m_1`); 3–2 sin uso; 7–4 calidad banda 1 y 11–8 calidad banda 2
(mismas claves de 4 bits que la Tabla 10); 12 corrección atmosférica; 13
corrección de adyacencia; 15–14 sin uso.

Uso: NDVI a 250 m si se adopta agregación desde 250 m (MP-05, MP-08). La
nubosidad debe tomarse del `state_1km_1` de MOD09GA (D3 p. 13, p. 32).

### 5.5 MOD13Q1 (250 m) / MOD13A2 (1 km) — NDVI compuesto de 16 días

**(a) Generales**

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Resolución | MOD13Q1 250 m; MOD13A2 1 km (agrega 250/500 m nativos a 1 km en la etapa de reflectancia) | `VERIFICADA` | D4 p. 9; D12 |
| Compuesto | 16 días; desde C6 ingiere reflectancia L2G **pre-compuesta de 8 días**; método CV-MVC (de las n = 2 observaciones con mayor NDVI, la de menor ángulo de visión); respaldo MVC | `VERIFICADA` | D4 p. 9–11 |
| Discontinuidades | Píxeles adyacentes pueden provenir de días distintos con geometría y contaminación distintas | `VERIFICADA` | D4 p. 12 |
| Extensión | 2000-02-18 → presente | `VERIFICADA` | D12 |
| Definición de NDVI | NDVI = (NIR − Red)/(NIR + Red), ec. (1) | `VERIFICADA` (forma) | D4 p. 5 |

**(b) Capas necesarias** — MOD13Q1: D4 p. 12, Tabla 1; MOD13A2: D4 p. 21,
Tabla 8; contrastadas con D12.

| SDS (nombre en HDF según D12) | Tipo | Escala | Rango válido | Relleno | Unidad |
|---|---|---|---|---|---|
| `250m 16 days NDVI` / `1 km 16 days NDVI` | int16 | 0.0001 | −2000–10000 | −3000 | – |
| `… VI Quality` | uint16 | – | 0–65534 | 65535 | bits |
| `… composite day of the year` | int16 | – | 1–366 | −1 | día del año |
| `… pixel reliability` | int8 | – | 0–3 | −1 | rango |
| `… view zenith angle`, `… sun zenith angle` | int16 | 0.01 | 0–18000 | −10000 | grados |
| `… red reflectance`, `… NIR reflectance` | int16 | 0.0001 | 0–10000 | −1000 | – |

Rango físico de NDVI (`DERIVADA`): −0.2000 a 1.0000.

Nombres de SDS: D12 escribe "1 km 16 days …" (con espacio) y D4 Tabla 8
escribe "1km 16 days …". `TODO`: confirmar con un archivo real; el lector
debe resolver nombres por coincidencia exacta contra la lista de
subdatasets del archivo, no por suposición.

**(c) QA**

*Pixel reliability* — D4 p. 17, Tabla 4: −1 relleno/no procesado; 0 buen
dato; 1 marginal (revisar otra QA); 2 nieve/hielo; 3 nuboso.

*VI Quality* — D4 p. 18, Tabla 5: 1–0 MODLAND (00 buena; 01 producido,
revisar otra QA; 10 producido pero probablemente nuboso; 11 no producido
por otras razones); 5–2 utilidad del VI (0000 máxima … 1100 mínima; 1101
inútil; 1110 L1B defectuoso; 1111 no útil/no procesado); 7–6 aerosol; 8 nube
adyacente; 9 corrección BRDF atmósfera; 10 nubes mixtas; 13–11 tierra/agua
(mismas clases que MOD09); 14 posible nieve/hielo; 15 posible sombra. En la
práctica no se aplica corrección de adyacencia ni BRDF y esos bits valen 0
(D4 p. 19).

**(d) Uso en EarthFlux:** `ndvi` por defecto candidato (MP-05). La capa
`composite day of the year` permite calcular, **por píxel**, el desfase en
días respecto de la fecha de la LST (§9.1) y marcarlo.

### 5.6 MCD43A3 — albedo (Terra + Aqua)

**(a) Generales**

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Contenido | Albedo *black-sky* (reflectancia direccional-hemisférica) y *white-sky* (bihemisférica) **a mediodía solar local**, bandas 1–7 y bandas anchas vis, nir y shortwave; calidad obligatoria por banda | `VERIFICADA` | D12; D8 (descripción de `Albedo_BSA_Band1`: "@ local solar noon") |
| Producción | Diaria, usando **16 días** de Terra y Aqua, ponderado temporalmente al **noveno día** (fecha del nombre de archivo) | `VERIFICADA` | D12 |
| Resolución | 500 m | `VERIFICADA` | D12 |
| Extensión | 2000-02-16 → presente | `VERIFICADA` | D12 |
| DOI | `10.5067/MODIS/MCD43A3.061` | `VERIFICADA` | D12 |
| QA completa | En el archivo compañero MCD43A2 (debe consultarse) | `VERIFICADA` | D12 |
| Grilla HDF-EOS | `MODIS_Grid_BRDF` | `VERIFICADA` | D8 |

**(b) Capas necesarias** — D8 (definiciones de campos) y D12 (tabla de
variables); coinciden.

| SDS | Tipo | Escala | Offset | Rango válido | Relleno | Unidad |
|---|---|---|---|---|---|---|
| `Albedo_BSA_shortwave` | int16 | 0.001 | 0.0 | 0–32766 | 32767 | – |
| `Albedo_WSA_shortwave` | int16 | 0.001 | 0.0 | 0–32766 | 32767 | – |
| `BRDF_Albedo_Band_Mandatory_Quality_shortwave` | uint8 | – | – | 0–254 | 255 | código |
| (opcionales) `Albedo_BSA_vis/nir`, `Albedo_WSA_vis/nir`, `…Band1`–`…Band7` | int16 | 0.001 | 0.0 | 0–32766 | 32767 | – |

Rango físico (`DERIVADA`): 0.000–32.766 (los valores físicamente
plausibles están en [0, 1]; valores > 1 válidos en DN deben marcarse, no
truncarse).

Convención de conversión declarada en D8: `albedo = (DN − add_offset) ·
scale_factor` (con `add_offset` = 0, equivalente a `DN · scale`).

**(c) QA**

`BRDF_Albedo_Band_Mandatory_Quality_<banda>` — D8:

| Código | Bandas 1–7 y vis | nir y shortwave |
|---|---|---|
| 0 | Procesado, buena calidad (inversión BRDF completa) | Ídem |
| 1 | Procesado, ver otra QA (inversión de magnitud) | Ídem |
| 2–7 | – | Variantes de 0/1 con banda 5 y/o 6 como relleno por detectores no funcionales o ruidosos (2/3: solo banda 6; 4/5: solo banda 5; 6/7: ambas) |
| 255 | Relleno | Relleno |

MCD43A2 (D9) — capas útiles para la política QA:

| SDS | Contenido |
|---|---|
| `Snow_BRDF_Albedo` (uint8) | 0 albedo sin nieve; 1 albedo con nieve; 255 relleno |
| `BRDF_Albedo_LandWaterType` (uint8) | 0–7, mismas clases tierra/agua que MOD09 |
| `BRDF_Albedo_Band_Quality_Band1..7` (uint8) | 0 mejor calidad, inversión completa; 1 buena, inversión completa; 2 inversión de magnitud (n obs ≥ 7); 3 inversión de magnitud (2 ≤ n obs < 7); 4 relleno |
| `BRDF_Albedo_LocalSolarNoon` (uint8) | Cenital solar a mediodía solar local, grados, 0–90, relleno 255 |
| `BRDF_Albedo_Platform` (uint8) | 0 Terra; 1 Terra/Aqua; 2 Aqua |
| `BRDF_Albedo_Uncertainty` (uint16) | escala 0.001, rango 0–32766, relleno 32767 |

**(d) Discrepancias / notas:** D12 describe `Albedo_BSA_Band7` como "Band
6" (errata de la página). La guía de usuario MCD43 no pudo leerse (§2.3);
toda recomendación de uso de la guía (p. ej., criterios de "mejor calidad")
queda `TODO`.

**(e) Uso en EarthFlux:** `albedo` por defecto candidato (MP-03); exige una
regla para combinar BSA y WSA y para la diferencia entre mediodía solar y
hora de paso (§8.1).

### 5.7 MCD15A2H — LAI (Terra + Aqua, 8 días)

**(a) Generales**

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Resolución / grilla | 500 m; 2400 × 2400 por tesela | `VERIFICADA` | D5 p. 5–6 (Tablas 2–3); D12 |
| Compuesto | 8 días; mejor píxel de ambos sensores en el período | `VERIFICADA` | D5 p. 5 (Tabla 2); D12 |
| Nivel | L4 | `VERIFICADA` | D12 |
| Extensión | 2002-07-04 → presente | `VERIFICADA` | D5 p. 6 (Tabla 3); D12 |
| Definición de LAI | Área foliar verde de una cara por unidad de área de suelo (latifoliadas); la mitad del área total de acículas (coníferas) | `VERIFICADA` | D5 p. 3 |
| Ejecución | El algoritmo se ejecuta **independientemente de la calidad del insumo**: el usuario debe consultar las capas QC | `VERIFICADA` | D5 p. 8 |

**(b) Capas** — D5 p. 8, Tabla 4; nombres y unidades según D12.

| SDS | Tipo | Escala | Rango válido | Relleno | Unidad |
|---|---|---|---|---|---|
| `Lai_500m` | uint8 | 0.1 | 0–100 | 249–255 (clases, ver abajo) | m² m⁻² (D12; D5 indica "Dimensionless") |
| `FparLai_QC` | uint8 | – | 0–254 | 255 | bits |
| `FparExtra_QC` | uint8 | – | 0–254 | 255 | bits |
| `LaiStdDev_500m` | uint8 | 0.1 | 0–100 | 248–255 | m² m⁻² |

Rango físico de LAI (`DERIVADA`): 0.0–10.0 m² m⁻².

Valores de relleno con significado (D5 p. 11, Tabla 6): 255 relleno
(reflectancia o cobertura con relleno); 254 sal perenne o agua dulce
interior; **253 estéril o vegetación rala (roca, tundra, desierto)**; 252
nieve/hielo perenne; 251 humedal permanente; 250 urbano; 249 no
clasificado. Para `LaiStdDev_500m` además 248 = sin desviación estándar,
píxel producido con el método de respaldo (D5 p. 12, Tabla 7).

Relevancia para Chile: en el norte árido y en la alta cordillera una
fracción grande de píxeles puede llevar la clase 253 o 252; **no** deben
convertirse silenciosamente a LAI = 0 (§10, decisión MP-06).

**(c) QA** — D5 p. 9–10, Tabla 5 (`FparLai_QC`) y tabla siguiente
(`FparExtra_QC`):

| Capa | Bits | Campo | Valores |
|---|---|---|---|
| `FparLai_QC` | 0 | MODLAND | 0 buena calidad (algoritmo principal, con o sin saturación); 1 otra calidad (respaldo o relleno) |
| | 1 | Sensor | 0 Terra; 1 Aqua |
| | 2 | Detector muerto | 1 detectores muertos causaron > 50 % de recuperación adyacente |
| | 4–3 | Nubes (heredado) | 00 sin nubes significativas; 01 nubes significativas; 10 nube mixta; 11 no definido, se asume despejado |
| | 7–5 | SCF_QC (confianza, 5 niveles) | 000 principal sin saturación; 001 principal con saturación; 010 principal falló por geometría, empírico; 011 principal falló por otras razones, empírico; 100 no producido |
| `FparExtra_QC` | 1–0 | Tierra/mar | 00 tierra; 01 costa; 10 agua dulce; 11 océano |
| | 2 | Nieve/hielo | 1 detectado |
| | 3 | Aerosol | 1 nivel promedio o alto |
| | 4 | Cirros | 1 detectado |
| | 5 | Máscara interna de nubes | 1 nubes |
| | 6 | Sombra de nube | 1 detectada |
| | 7 | Máscara de bioma SCF | 1 bioma en intervalo ⟨1,4⟩ |

D5 identifica a SCF_QC como el indicador clave de calidad de la
recuperación (p. 9).

**(d) Uso en EarthFlux:** `lai` por defecto candidato (MP-06), necesario
para G (Tasumi/METRIC, `soil-heat-flux.md`) y ε₀ empírica (RC-14).

**Clases no vegetadas — decisión MP-06 (autor, 2026-11-04; M4-28, M4-29).**
Por defecto (`lai_nonveg = NULL`), las clases 249–254 dan LAI `NA` con
`EF_SURF_LAI_NONVEG` y la clase se conserva. Con la opción explícita
`lai_nonveg` de `modis_surface_options()`/`modis_lai()` se asigna un LAI
declarado: un número para las seis clases, o un vector con nombre por
código de clase (`c("253" = 0, "250" = 0)`; las clases no nombradas siguen
`NA`). Valores en [0, 10] m² m⁻² (rango físico `DERIVADA`). La celda
asignada lleva `EF_SURF_LAI_ASSIGNED` (clase I, `info`, bit 15) y no
`EF_SURF_LAI_NONVEG`, que sigue significando LAI `NA`; los códigos
enmascarados por el usuario prevalecen; el valor queda en la procedencia.
Estado del valor asignado: `CANDIDATA` (práctica de implementaciones
METRIC: con E3, LAI 0 da ε₀ = 0,95; forma observada en `water`,
`radiation-components.md` §6.6). Nunca se asigna en silencio. Con LAI 0,
agua (254) y nieve (252) también entran en la rama de suelo desnudo de G de
Tasumi: la asignación por clase permite excluirlas (A-M4-6).

### 5.8 MCD12Q1 — cobertura de suelo anual

| Elemento | Valor | Estado | Fuente |
|---|---|---|---|
| Resolución / grilla | 500 m; teselas sinusoidales HDF4 | `VERIFICADA` | D6 p. 2, p. 4; D12 |
| Temporal | Anual; 2001-01-01 → presente | `VERIFICADA` | D6 p. 2; D12 |
| Advertencia de uso | No usar para detectar cambio de cobertura post-clasificación | `VERIFICADA` | D6 p. 3 |

Capas — D6 p. 7, Tabla 1; nombres en HDF según D12:

| SDS | Contenido | Tipo | Rango válido | Relleno |
|---|---|---|---|---|
| `LC_Type1` | IGBP anual (clases 1–17; tabla de clases D6 p. 9, Tabla 3) | uint8 | 1–17 | 255 |
| `LC_Type3` | Esquema LAI (0–10; D6 p. 11, Tabla 5) | uint8 | 0–10 | 255 |
| `QC` | Calidad (0 tierra clasificada … 10 sin dato; D6 p. 17, Tabla 11) | uint8 | 0–10 | 255 |
| `LW` | Máscara tierra (2) / agua (1) desde MOD44W | uint8 | 1–2 | 255 |

Problemas conocidos con efecto directo en Chile (D6 p. 5, §2.2,
`VERIFICADA`): bosques templados de coníferas siempreverdes clasificados
como latifoliados siempreverdes en Chile; un glaciar en Chile tratado como
permanentemente nuboso y clasificado parcialmente como pradera; glaciares
en sombra topográfica clasificados como agua; humedales subrepresentados.

Uso en EarthFlux: apoyo a la selección de anclas (SPEC §7) y a rugosidad;
la regla de agregación a 1 km debe ser modal o por fracciones (§9.2), nunca
promedio.

---

## 6. Hora de paso (*view time*) → UTC por píxel

### 6.1 Semántica en MOD11A1/MYD11A1 — `VERIFICADA`

D1 p. 16: `Day_view_time` y `Night_view_time` están en **hora solar
local**, definida como *"UTC time plus grid's longitude in degrees / 15
degrees (in hours, +24 if local solar time < 0 or −24 if local solar time
≥ 24)"*. El día de datos del nombre de archivo está en **UTC**, por lo que
el día en hora solar local de una celda puede diferir en un día del día UTC.
D10 describe la capa como "Local sun time of daytime Land-surface
Temperature observation".

Consecuencias:

1. Es **hora solar media** (UTC + λ/15), **sin** ecuación del tiempo. Esto
   resuelve, para MOD11A1, la pregunta abierta de `radiation-components.md`
   §4.4 (RC-03): la conversión a UTC usa solo la longitud, y la ecuación
   del tiempo debe aplicarse **una vez**, dentro de `ef_solar_geometry()`.
2. La longitud es la del **centro de la celda** ("grid's longitude").
3. Cuantización: escala 0.1 h ⇒ resolución temporal de 6 min (`DERIVADA`).

### 6.2 Conversión propuesta — `CANDIDATA` (derivación lógica, pendiente de test con granulo real)

Con `t_ls` hora solar local [h], `λ` longitud del centro de celda [grados,
este positivo] y `D` la fecha UTC del nombre de archivo:

```text
t_utc = (t_ls − λ/15) mod 24          [h, en [0, 24)]
instante_UTC = D (00:00 UTC) + t_utc horas
doy = día del año de D;  utc_hour = t_utc     (entradas del núcleo, RC-03)
```

Justificación: la regla de D1 suma λ/15 y luego corrige ±24; invertirla es
restar λ/15 y reducir módulo 24. Como la observación pertenece al día UTC
`D` del archivo, el instante queda dentro de `D`. **Supuesto a verificar**
(`TODO`): que ninguna observación incluida en el archivo del día `D` caiga
fuera de [00:00, 24:00) UTC de `D`.

Casos numéricos (aritmética):

| Caso | λ [°] | `t_ls` [h] | t_utc [h] | Resultado |
|---|---|---|---|---|
| V1 (Chile central) | −71.0 | 10.6 | 10.6 + 4.7333 = 15.3333 | 15:20 UTC del día `D` |
| V2 (corrección −24) | −170.0 | 23.0 | 23.0 + 11.3333 = 34.3333 → 10.3333 | 10:20 UTC |
| V3 (corrección +24) | +170.0 | 1.0 | 1.0 − 11.3333 = −10.3333 → 13.6667 | 13:40 UTC |
| V4 (relleno) | cualquiera | DN = 255 | NA | `NA` + flag |

### 6.3 Por qué importa

- **ETr instantánea y condición del ancla fría.** El ancla fría usa ETr a la
  hora de paso (SPEC §1.2, §2.1). Con la deriva orbital (§7) la hora de paso
  cambia entre fechas y, dentro de una escena, entre píxeles (distinta
  posición en la franja y, según d1, posible promedio de pasadas). Suponer
  una hora fija sesga ETr_inst y, por tanto, la calibración dT–Ts de toda la
  escena.
- **Geometría solar y Rs↓.** `ef_solar_geometry()` necesita `doy` y
  `utc_hour` por píxel (`radiation-components.md` §4.4). Un error de 6 min
  (cuantización) cambia el ángulo horario en 1.5°.
- **Desfase con productos de mediodía.** El BSA de MCD43A3 está calculado a
  mediodía solar local (§5.6), no a la hora de paso.
- **Supuestos de "mediodía".** Las formulaciones empíricas de G se
  presentan como válidas cerca del mediodía (`soil-heat-flux.md` §3.1); una
  pasada muy temprana (Terra en deriva) puede salir de ese dominio
  (flag propuesto `EF_OVERPASS_OUTSIDE_WINDOW`, umbral `TODO`).

### 6.4 MOD21A1D — `TODO`

La semántica de `View_Time` no está documentada en D2 ni D11 (§5.2). Hasta
resolverla, si se usa MOD21A1D: (a) no convertir a UTC automáticamente;
(b) exigir que el usuario declare la convención o (c) contrastar con
MOD11A1 del mismo día y plataforma en un granulo real. Decisión MP-01.

---

## 7. Estado de Terra/Aqua, deriva orbital y continuidad

### 7.1 Hechos `VERIFICADA` (fuentes oficiales; estado al momento de cada alerta)

| Hecho | Fuente |
|---|---|
| Terra mantuvo 10:30 MLT (±2 min) en el nodo descendente por más de 20 años; última maniobra de inclinación en febrero de 2020; desde entonces el cruce ecuatorial se adelanta | D15; D14 alerta 200071; D14 alerta 199931 (fecha exacta: 27-feb-2020) |
| Plan publicado (2021-10-19): Terra alcanzaría 10:15 MLT en octubre de 2022, saldría de la constelación y bajaría a 694 km; la MLT seguiría derivando hasta ≈ 9:00 AM hacia diciembre de 2025; fin de misión previsto en diciembre de 2025 | D14 alerta 200071 |
| Las maniobras de salida de constelación de Terra se realizaron el 12 y 19 de octubre de 2022; producción Terra reanudada desde el día 296 (23-oct-2022) 22:35 UTC | D14 alerta 200035 |
| Tras esas maniobras, la producción de MOD11 V6 se discontinuó por degradación de píxeles válidos en latitudes medias (V6.1 continúa) | D14 alerta 200029 |
| Aqua mantuvo 1:30 PM MLT (nodo ascendente) y 705 km hasta marzo de 2021 (última maniobra de inclinación: 8-mar-2021); deriva hacia horas más tardías; plan publicado (2021-10-26): ≈ 3:50 PM hacia agosto de 2026 y fin de misión previsto en agosto de 2026 | D14 alerta 200068; D14 alerta 199931 |
| Efectos previstos por el equipo: menor elevación solar (más sombras) en pasadas tempranas, cambios de cobertura espacial y de tamaño efectivo de grilla, y pérdida del ciclo de repetición estricto de 16 días | D14 alertas 200071 y 200068 |
| Terra seguía operando en 2026: anomalía el 26-mar-2026; datos entre 2026-085 20:00z y 2026-086 19:30z marcados como cuestionables/malos | D14 alerta 199930 |

Notas: la alerta 200068 dice "1:45 AM MLT" para Aqua, probablemente errata
de "PM" (`TODO`). Los planes de 2021 (fin de misión dic-2025 / ago-2026) son
**anteriores** a la evidencia de operación de 2026; el estado actual y las
fechas oficiales de fin de operación siguen `TODO` (sitios de misión no
accesibles, §2.3). SPEC §2.4 debe actualizarse con estos hechos cuando el
autor lo apruebe.

### 7.2 Implicancias para EarthFlux

1. La hora de paso **debe** leerse por píxel (§6); nunca suponerse 10:30 o
   13:30.
2. Comparaciones entre fechas anteriores y posteriores a 2020–2022 mezclan
   geometrías solares distintas: registrar la hora de paso por píxel en la
   procedencia y en los diagnósticos.
3. MCD43A3 y MCD15A2H combinan Terra y Aqua: su composición de plataformas
   cambia con el tiempo (`BRDF_Albedo_Platform`, bit "Sensor" de
   `FparLai_QC`); registrarlo.

### 7.3 Continuidad (VIIRS) — `TODO` salvo lo indicado

| Hecho | Estado | Fuente |
|---|---|---|
| VJ121 (NOAA-20 VIIRS LST&E, v002): mismo enfoque TES que MOD21 C6.1, bandas M14, M15, M16, 750 m, diario, 2018-01-01 → presente | `VERIFICADA` | D16 |
| VNP21 v001 retirado el 8-abr-2025; v002 disponible para SNPP (VNP21) y NOAA-20 (VJ121) | `VERIFICADA` | D16 |
| VJ143MA3 (NOAA-20, v002): WSA/BSA a mediodía solar local, 1 km, diario con 16 días ponderados al noveno día, bandas anchas vis/nir/shortwave | `VERIFICADA` | D16 |
| Entrega de datos de Suomi NPP cesa el 2-nov-2026 13:00 UTC; NOAA-20/NOAA-21 como continuidad (p. ej., VNP09 → VJ109 / VJ209) | `VERIFICADA` | D14 alerta 199913 |
| Productos VIIRS L3 en grilla equivalentes a MOD11A1/MOD13/MCD15 (nombres, escalas, view time) | `TODO` | No leído |

La arquitectura independiente del sensor (principios 1–2) permite agregar
un módulo VIIRS con su propia ficha de producto sin tocar `metric-*.R`.
Decisión MP-14.

---

## 8. Conversiones a banda ancha

### 8.1 Albedo

**Hechos `VERIFICADA` (D7, ATBD v5.0, 1999):**

- BSA y WSA son propiedades intrínsecas de la superficie, independientes de
  la atmósfera; representan iluminación totalmente directa y totalmente
  difusa, respectivamente (D7 p. 2, p. 11).
- El albedo "real" (*actual*) se interpola entre ambos según la fracción de
  radiación difusa S, suponiendo difusa isotrópica — D7 p. 11, ec. (32);
  la aproximación tiene errores relativos de pocos por ciento (D7 p. 24,
  §VI-D).
- La conversión espectral → banda ancha usa coeficientes de ponderación por
  banda; D7 p. 17–18, Tabla II, reproduce coeficientes MODIS de Liang et al.
  (no se transcriben aquí: la extracción de texto del PDF no conserva los
  signos negativos con fiabilidad; transcribir desde Liang, 2001, tras
  verificar).
- La conversión depende del estado atmosférico y del ángulo cenital; los
  coeficientes son para casos promedio, con efecto de "pocos por ciento"
  (D7 p. 17).

Advertencia: D7 es la versión de 1999 (pre-C6). Su vigencia para C6.1 es
`TODO` (la guía MCD43 actual no fue accesible).

**Opciones**

| ID | Método | Estado | Entradas | Pros | Contras |
|---|---|---|---|---|---|
| A1 | *Blue-sky*: α = (1 − S)·BSA_sw + S·WSA_sw (forma de D7 ec. 32 aplicada a banda ancha) | `CANDIDATA` | MCD43A3 + fracción difusa S | Físicamente consistente con Rs↓ instantánea; usa productos oficiales de banda ancha | BSA es a **mediodía solar**, no a la hora de paso; S requiere un modelo (posible acoplamiento con `ef_tau_sw_allen()`, que a su vez usa α como ρ_g: riesgo de circularidad); aplicar ec. 32 a banda ancha supone que S no varía espectralmente (`TODO`, Román et al., 2010) |
| A2 | Solo WSA_sw | `CANDIDATA` | MCD43A3 | Simple; sin dependencia de S | Sesgo bajo cielo despejado (iluminación mayormente directa) |
| A3 | Solo BSA_sw (mediodía) | `CANDIDATA` | MCD43A3 | Simple; cielo despejado coherente con LST despejada | Ignora difusa; ángulo de mediodía ≠ hora de paso |
| A4 | BSA a la hora de paso desde parámetros BRDF (MCD43A1) con el polinomio en el cenital solar de D7 §IV/V | `TODO` | MCD43A1 (no especificado aquí) | Corrige la diferencia mediodía/hora de paso | Producto adicional; más complejidad |
| A5 | Banda angosta → ancha desde MOD09GA (coeficientes de Liang, 2001) | `CANDIDATA` | MOD09GA bandas 1–7 | Mismo día y plataforma que la LST | Reflectancia direccional (no albedo hemisférico): sesgo BRDF; ruido diario; coeficientes `TODO` |
| A6 | Método METRIC de albedo a nivel de superficie (Tasumi et al., 2008) | `CANDIDATA` | Reflectancias | Coherencia con METRIC original | Desarrollado para Landsat; transferibilidad a MODIS `TODO` |

Recomendación provisional: A1 con S del módulo de radiación **solo si** se
resuelve la circularidad (p. ej., S calculada con α de la fecha anterior o
con WSA como primera aproximación, documentado); mientras tanto A2/A3 como
alternativas explícitas, con el método registrado en la procedencia.
Decisión MP-03.

### 8.2 Emisividad (bandas 31/32 → banda ancha)

Requisito heredado (`radiation-components.md` §6.6, RC-14; C2): ε₀ debe ser
de banda ancha, coherente con la LST y la **misma** en `ef_rl_out()` y
`ef_net_radiation()`.

| ID | Método | Estado | Pros | Contras |
|---|---|---|---|---|
| E1 | Regresión ε_bb = f(ε31, ε32) desde MOD11A1 (Wang et al., 2005) | `CANDIDATA` (coeficientes `TODO`) | Usa la emisividad del mismo producto que la LST | ε31/ε32 de MOD11 son por clasificación (D1 p. 9): poca información independiente; mayor incertidumbre en zonas áridas (D1 p. 9) |
| E2 | Regresión desde ε29/31/32 de MOD21A1D (TES) | `TODO` (referencia a identificar) | Emisividad recuperada; coherente con la LST TES | Requiere referencia primaria; anomalía MYD21 (§5.2) |
| E3 | Empírica METRIC desde LAI (ε₀ = 0.95 + 0.01·LAI, tope 0.98; forma observada en `water`) | `CANDIDATA` (RC-14) | Coherencia con METRIC original | Desacoplada de la LST MODIS; LAI de MCD15 con clases no vegetadas (§5.7) |
| E4 | Producto externo de banda ancha (CAMEL; Feltz et al., 2018) | `TODO` | Producto dedicado | Resolución, latencia y acceso `TODO`; dependencia externa |

Notas: el rango físico de `Emis_31/32` es 0.492–1.000 (§5.1, `DERIVADA`);
los bits 5–4 de `QC_Day` dan una cota del error medio de emisividad (≤ 0.01
… > 0.04), utilizable como flag. Sensibilidad: Δε₀ = 0.01 → ≈ −1.4 W m⁻² en
Rn (cálculo de `radiation-components.md` §6.6). Decisión MP-04 (vinculada a
RC-14).

**Estado de implementación (2026-11-04).** Implementada solo E3
(`"lai_empirical"`, `CANDIDATA`), con la opción `lai_nonveg` para las
clases no vegetadas (§5.7; M4-28): con `lai_nonveg = 0`, ε₀ = 0,95 en esas
clases y `EF_SURF_LAI_ASSIGNED` en `flags_emissivity`; sin la opción, ε₀
`NA` con `EF_INPUT_NA`. E1 (`"split_window_regression"`), E2
(`"tes_regression"`) y E4 (`"camel"`) dan
`earthflux_method_not_implemented`. Para preparar E1, el estado de
superficie ya lee y lleva `Emis_31` y `Emis_32` de MOD11A1/MYD11A1
(`band_emissivity`, capas `emis_31`, `emis_32`, con sus palabras de flags;
siempre desde HDF4, desde convertidos si se declaran; M4-30). Ningún
coeficiente de E1/E2 se propone aquí.

**Qué falta para implementar E1 (`"split_window_regression"`)** — todo
`TODO`; cada punto debe cumplirse desde la **fuente primaria** antes de
escribir código (`DEVELOPMENT.md` §3; regla de §0.1):

1. **Fuente primaria leída.** Wang et al. (2005), *J. Geophys. Res.
   Atmos.* 110, D11, DOI `10.1029/2004JD005566` (§2.2: hoy solo metadatos
   verificados, contenido no leído). Agregar la cita completa a
   `REFERENCES.md` y el ítem 9 de §16.
2. **Forma funcional.** Transcribir la ecuación exacta ε_bb = f(ε31, ε32)
   con su número de ecuación, página y tabla: términos (lineal, con o sin
   intercepto, otros), variables de entrada (emisividades de banda ya
   escaladas, §5.1) y sin reordenar ni redondear.
3. **Coeficientes.** Valores y número de cifras tal como se publican, con
   la tabla de origen; si hay varios juegos (por superficie, por
   colección de MOD11 o por sensor), cuál aplica a la colección 6.1 de
   Terra y Aqua. Ninguno se infiere de fuentes secundarias.
4. **Definición de "banda ancha".** Intervalo espectral de la ε_bb del
   artículo y su coherencia con `ef_rl_out()` y `ef_net_radiation()`, que
   usan σ·ε₀·T⁴ sobre todo el espectro (RC-14, requisito C2: la misma ε₀
   en ambas).
5. **Rango de validez.** Dominio de ε31/ε32 y tipos de superficie del
   ajuste (biblioteca espectral o sitios), colección de MOD11 usada en el
   ajuste frente a C6.1 (emisividades por clasificación y ajuste de zonas
   áridas de Wan, 2014; D1 p. 9), error del ajuste, y qué hacer fuera del
   dominio (`earthflux_domain_error` en el núcleo numérico; flag de clase I
   o II en `surface` según tenga umbral con referencia).
6. **Casos de prueba.** (a) Un caso numérico publicado (entrada ε31, ε32
   → ε_bb) o, si el artículo no lo da, un cálculo a mano desde los
   coeficientes transcritos, con tolerancia de `VALIDATION_PLAN.md`;
   (b) bordes: `NA`, relleno (`EF_SURF_FILL` de `Emis_31/32`), DN fuera de
   rango, ε fuera del dominio de validez (error con clase); (c) vector =
   ráster; (d) estado de superficie con `emissivity_method =
   "split_window_regression"`: ε₀ desde `band_emissivity` y flags de
   `flags_emis_31`/`flags_emis_32` propagados a `flags_emissivity`.
7. **Integración.** Con E1, `Emis_31`/`Emis_32` pasan a ser obligatorias
   también en fuentes convertidas; `e31`/`e32` dejan de ser `NULL` en
   `modis_broadband_emissivity()`; el estado de verificación de la
   procedencia pasa a `VERIFICADA` solo con los puntos 1–6; actualizar
   RC-14 (`radiation-components.md` §6.6), MP-04, `SCIENTIFIC_SPEC.md` y
   `NEWS.md`. El flag de error de emisividad de los bits 5–4 de `QC_Day`
   (`EF_SURF_EMIS_ERROR`, clase II) sigue sin registrar hasta tener umbral
   con referencia.

**Qué falta para implementar E2 (`"tes_regression"`)** — `TODO`: los
puntos 1–7 de E1 aplicados a ε29/ε31/ε32 de MOD21A1D/MYD21A1D (las filas
`Emis_29/31/32` ya están en la tabla de producto, §5.2, `VERIFICADA`),
más: (a) **identificar** la referencia primaria (hoy no hay ninguna
candidata, tabla de arriba); (b) resolver la semántica de `View_Time` de
MOD21 (§6.4, MP-01), sin la cual MOD21A1D no puede ser producto LST del
estado de superficie; (c) evaluar la anomalía de MYD21 (§5.2, §16 punto
17).

Decisión abierta asociada: MP-04 (E1–E4) y A-M4-6 de `DECISIONS.md` §1.4.

---

## 9. Desfase temporal y remuestreo espacial

### 9.1 Desfase temporal (decisión MP-07)

| Variable | Producto | Paso temporal (`VERIFICADA`) | Referencia temporal |
|---|---|---|---|
| LST | MOD11A1/MYD11A1 | Diario (día UTC) | Hora de paso por píxel |
| NDVI | MOD13Q1/MOD13A2 | 16 días (CV-MVC) | `composite day of the year` por píxel |
| LAI | MCD15A2H | 8 días | Período del compuesto (sin día por píxel en las capas leídas: `TODO`) |
| Albedo | MCD43A3 | Diario, ventana de 16 días ponderada al noveno día | Fecha del archivo |
| Reflectancia | MOD09GA/GQ | Diario | Misma pasada (por verificar, §5.3) |
| Cobertura | MCD12Q1 | Anual | Año |

Opciones:

| ID | Regla | Pros | Contras |
|---|---|---|---|
| T1 | Compuesto cuyo período contiene la fecha de la LST | Simple; reproducible | Desfase de hasta ~15 días (NDVI) sin control por píxel |
| T2 | T1 + desfase por píxel con `composite day of the year` (MOD13) y flag si \|desfase\| > umbral | Auditable; usa información oficial por píxel | Umbral `TODO`; LAI no tiene día por píxel |
| T3 | Interpolación lineal entre compuestos adyacentes | Reduce el desfase medio | Suaviza eventos (riego, cosecha); introduce valores no observados; requiere dos compuestos |
| T4 | NDVI diario desde MOD09GA del mismo día y plataforma | Sin desfase; misma geometría | Nubes y ruido; sin compuesto; ver §5.3 sobre la pasada |
| T5 | Mismo día para albedo (MCD43A3 diario) | Disponible a diario | Sigue representando 16 días |

Recomendación provisional: T2 para NDVI y LAI (con flag
`EF_MODIS_COMPOSITE_LAG`), T5 para albedo, T4 como alternativa explícita.
Nunca interpolar por defecto (T3 solo como opción declarada).

### 9.2 Remuestreo espacial (decisión MP-08)

Grilla de trabajo propuesta: **grilla sinusoidal nativa de 1 km de la LST**
(evita remuestrear la variable que gobierna la calibración de anclas, SPEC
§2.3). Las capas de 500 m se agregan por factor entero 2 (anidamiento,
§4, `DERIVADA`, por confirmar); las de 250 m, por factor `TODO`.

| Variable | Método candidato | Alternativa | Comentario |
|---|---|---|---|
| Reflectancias (→ NDVI) | Promedio de reflectancias válidas y luego NDVI | Promedio de NDVI | NDVI es no lineal: NDVI(promedio) ≠ promedio(NDVI); elegir y documentar |
| NDVI de MOD13A2 | Sin remuestreo (ya 1 km) | MOD13Q1 agregado | MOD13A2 ya agrega desde 250/500 m en origen (D4 p. 9) |
| Albedo | Promedio (área) de celdas válidas | – | El albedo de área es el promedio bajo irradiancia uniforme (supuesto) |
| LAI | Promedio de celdas válidas | Mediana | Efectos no lineales en G y ε₀ (`TODO` cuantificar) |
| Cobertura | Moda + fracción de cada clase | Vecino más cercano | **Nunca** promedio; fracciones útiles para homogeneidad de anclas |
| Capas QA | Peor caso + fracción de sub-celdas válidas | – | Nunca interpolar bits |
| `Day_view_time` | Sin remuestreo (nativa de 1 km) | – | – |

Reglas:

1. Bilineal/cúbico **nunca** para QA, clases ni bits; solo eventualmente
   para reproyección final de variables continuas (opción del usuario).
2. Agregación con sub-celdas inválidas: el valor se calcula con las válidas
   solo si la fracción válida ≥ umbral (`TODO`); si no, `NA` + flag
   `EF_MODIS_AGG_INCOMPLETE`. La capa de fracción válida se conserva.
3. Si las extensiones 500 m/1 km no coincidieran exactamente en un archivo
   real, se requiere una regla de alineación explícita (`TODO`).

---

## 10. Política QA

### 10.1 Principios (de `ARCHITECTURE.md` §1)

- Los diagnósticos son parte del resultado (principio 5); nada se corrige
  silenciosamente (principio 6).
- Distinción clave: un **relleno** no es un dato (no hay valor que
  "borrar"); un dato de **calidad dudosa** sí es un valor y se conserva con
  flag, salvo que el usuario elija enmascararlo explícitamente.
- Las capas QA crudas se conservan (decodificadas) en la salida `qa` para
  que toda decisión sea auditable.

### 10.2 Enmascarar vs marcar

| Condición | Acción por defecto | Flag propuesto | ¿Umbral? |
|---|---|---|---|
| DN = `_FillValue` | `NA` (obligatorio: no existe valor) | `EF_INPUT_NA` (ya registrado) aguas abajo; `EF_MODIS_FILL` con la capa | No |
| MODLAND 10 (no producido por nubes) | `NA` (el valor es relleno; D1 p. 16) | `EF_MODIS_CLOUD` | No |
| MODLAND 11 (no producido, otras razones) | `NA` | `EF_MODIS_NOT_PRODUCED` | No |
| DN fuera del rango válido y distinto de relleno | `NA` (el documento lo define inválido) | `EF_MODIS_OUT_OF_RANGE` | No |
| MODLAND 01 (producido, otra calidad) | **Conservar** | `EF_MODIS_QA_OTHER` | No |
| Error de LST en categoría > 2 K (MOD11 bits 7–6 ≥ 10) o > 2 K / 1.5–2 K (MOD21 bits 15–14) | Conservar | `EF_MODIS_LST_ERROR` | Sí (qué categoría) `TODO` |
| Error de emisividad > 0.02 (MOD11 bits 5–4 ≥ 10) | Conservar | `EF_MODIS_EMIS_ERROR` | Sí `TODO` |
| Nube adyacente / cirros (MOD21 bits 5–4; MOD09 bits 13, 9–8; MOD13 bit 8) | Conservar | `EF_MODIS_CLOUD_ADJACENT` | No |
| Nieve/hielo (MOD09 bits 12, 15; MOD13 bit 14; MCD43A2 `Snow_BRDF_Albedo` = 1; MCD15 extra bit 2) | Conservar | `EF_MODIS_SNOW` | No |
| Agua (tierra/agua ≠ tierra) | Conservar | `EF_MODIS_WATER` | No |
| LAI con clase no vegetada (249–254) | `NA` en `lai` (no hay estimación) + clase conservada en `qa` | `EF_MODIS_LAI_NONVEG` | No |
| LAI de respaldo (SCF_QC 010/011) | Conservar | `EF_MODIS_LAI_BACKUP` | No |
| Albedo por inversión de magnitud (código 1, 3, 5, 7) | Conservar | `EF_MODIS_ALBEDO_MAGNITUDE` | No |
| Albedo > 1 con DN válido | Conservar | `EF_MODIS_ALBEDO_GT1` | No |
| Ángulo de visión alto | Conservar | `EF_MODIS_VIEW_ANGLE_HIGH` | Sí `TODO` |
| Desfase compuesto–LST | Conservar | `EF_MODIS_COMPOSITE_LAG` | Sí `TODO` |
| Agregación con sub-celdas inválidas | `NA` bajo umbral | `EF_MODIS_AGG_INCOMPLETE` | Sí `TODO` |
| LST válida sin `view_time` válido | Conservar LST; `overpass_time` = `NA` | `EF_OVERPASS_TIME_MISSING` | No |
| Hora de paso fuera de la ventana de validez de métodos "de mediodía" | Conservar | `EF_OVERPASS_OUTSIDE_WINDOW` | Sí `TODO` |
| Salar (MOD09 bit 14) | Conservar | `EF_MODIS_SALT_PAN` | No |

Códigos **propuestos, no registrados**. Se registran en
`ef_flag_registry()` (`R/diagnostics.R`) solo cuando la condición sea
inequívoca y esta especificación esté fusionada; los que requieren umbral
esperan su justificación (misma regla que `radiation-components.md` §4.8).

### 10.3 Niveles de política (argumento `qa_policy`, propuesta)

| Nivel | Comportamiento |
|---|---|
| `"flag"` (por defecto) | Solo se ponen en `NA` las filas "obligatorias" de §10.2; todo lo demás se conserva con flags |
| `"mask"` | Además, se ponen en `NA` las condiciones que el usuario liste (p. ej., `EF_MODIS_QA_OTHER`), y cada píxel enmascarado queda contado en el flag correspondiente (enmascarar ≠ borrar en silencio) |
| Anclas | La selección de anclas (SPEC §7) debe usar un filtro más estricto e independiente del nivel elegido: solo MODLAND 00 en LST, NDVI y albedo; sin nieve, agua, nube adyacente ni salar (`TODO`: justificar en la especificación de anclas) |

### 10.4 Decodificación de bits

Extracción genérica de un campo de `n` bits que empieza en `k` (bit 0 =
LSB): `campo = (DN %/% 2^k) %% 2^n` (aritmética entera; válida para uint8,
uint16 y uint32 representados como `double` en R). Para uint32 (MOD09
`QC_500m_1`) verificar que no hay pérdida de precisión ni conversión a
entero con signo al leer con `terra` (`TODO`).

---

## 11. Diseño de I/O

### 11.1 Lectura de HDF4/HDF-EOS con `terra`/GDAL

| Aspecto | Estado |
|---|---|
| `terra` 1.9-50 requiere GDAL (≥ 2.2.3) (`SystemRequirements`) | `VERIFICADA` (D18) |
| En el entorno Linux de esta revisión, `terra` 1.9.50 enlazado con GDAL 3.8.4 lista los drivers `HDF4` (lectura) y `HDF4Image` | Observado localmente (no generalizable) |
| Soporte HDF4 en los **binarios CRAN** de `terra` para Windows y macOS | `TODO` — **riesgo conocido**: si un binario no incluye el driver HDF4, la lectura directa de `.hdf` falla. Verificar en ambos sistemas antes de M4 y documentar la alternativa |
| Sintaxis de subdatasets (`HDF4_EOS:EOS_GRID:"<archivo>":<grilla>:<SDS>`) y funciones `terra::describe(..., sds = TRUE)` / `terra::sds()` / `terra::rast(..., subds = )` | `TODO`: verificar con archivos reales; los nombres de grilla están en §5 (D10, D11, D8) |
| Lectura de atributos `scale_factor`/`add_offset` por GDAL y aplicación automática por `terra` | `TODO` (ver §11.3) |

### 11.2 Formatos alternativos (sin credenciales en tests)

| Opción | Estado | Comentario |
|---|---|---|
| HDF4 original, aportado por el usuario | Formato oficial (`VERIFICADA`, §5) | Ruta principal |
| GeoTIFF/COG ya convertido por el usuario | Diseño | El lector exige declarar producto, capa y si el valor está escalado; sin esa declaración → error clasificado (evita doble escalado) |
| NetCDF/GeoTIFF de servicios de subconjuntos en la nube (p. ej., servicios de LP DAAC) | `TODO` | Formatos, escalado y metadatos no verificados en esta revisión; requieren credenciales Earthdata |
| Archivos en Earthdata Cloud (`LPCLOUD`) | `VERIFICADA` que los productos tienen ID de concepto LPCLOUD (p. ej., MCD43A3: `C2278860820-LPCLOUD`, D12) | Mismo formato HDF; acceso con credenciales |

### 11.3 Escala y offset: dos convenciones en documentos oficiales

| Producto | Convención declarada | Fuente |
|---|---|---|
| MOD11A1 | `valor = DN · scale + add_offset` | D10 |
| MCD43A3, MCD43A2 | `valor = (DN − add_offset) · scale` | D8, D9 |

Para todas las capas con `add_offset` = 0 ambas coinciden. **Difieren** para
`Emis_31/32` (offset 0.49) y `Day_view_angl` (offset −65) de MOD11A1, y
para `Emis_*`/`View_Angle` de MOD21A1D. Las tablas de D1 (p. 17), D2 (p. 23),
D10 y D12 son consistentes con `DN · scale + offset` para MOD11/MOD21
(DN = 255 → ε = 1.000; DN = 0 → ángulo = −65°).

Decisión MP-11 (recomendación): **no confiar** en la aplicación automática
de escala/offset de GDAL/`terra`. Leer DN crudos, verificar (test) que no se
aplicó escalado, y aplicar escala, offset y relleno desde la ficha interna
de producto (§13), que registra la convención y la fuente de cada capa.

### 11.4 Teselas y área de interés

- El usuario entrega el AOI; el lector recorta en coordenadas sinusoidales
  **antes** de cualquier reproyección.
- Un AOI puede cruzar varias teselas: mosaico de teselas del mismo día y
  producto antes de recortar (`TODO`: verificar continuidad exacta entre
  teselas adyacentes).

### 11.5 Credenciales y descargas

- Ninguna credencial Earthdata se versiona (`DEVELOPMENT.md` §6). Si en el
  futuro se agrega descarga, las credenciales se leen del entorno del
  usuario (p. ej., `~/.netrc` o variable de entorno), nunca de archivos del
  repositorio, y la función es opcional.
- Tests y ejemplos no usan internet (`DEVELOPMENT.md` §5); los tests en
  línea, si existen, se activan con `EARTHFLUX_ONLINE_TESTS` y deben fallar
  con elegancia si el recurso no está disponible (D17).
- Paquetes CRAN relacionados que podrían evaluarse (sin decisión; listados
  como dependencias inversas de `terra` en D18): `MODISTools`, `modisfast`,
  `appeears`, `earthdatalogin`. `TODO`: revisar licencia, mantenimiento y
  necesidad antes de cualquier dependencia (`DEVELOPMENT.md` §4).

---

## 12. Datos de ejemplo para tests y vignettes

Restricciones `VERIFICADA` (D17): datos y documentación ≤ 5 MB como regla
general; tarball de fuentes idealmente ≤ 10 MB; ejemplos de pocos segundos;
máximo 2 núcleos; recursos de internet deben fallar con elegancia.

Licencia de los datos: los datos MODIS se comparten abiertamente, sin
restricción, según la *EOSDIS Data Use and Citation Guidance* (D12,
sección *Citation* de MCD43A3) — `VERIFICADA`; `TODO`: confirmar requisitos
de cita para datos redistribuidos dentro de un paquete.

Diseño propuesto:

| Elemento | Contenido | Formato | Tamaño objetivo |
|---|---|---|---|
| `tests/testthat/fixtures/modis-raw/` | Recortes de DN **crudos** (p. ej., 10 × 10 celdas de 1 km y 20 × 20 de 500 m) de `LST_Day_1km`, `QC_Day`, `Day_view_time`, `Emis_31/32`, NDVI/QA, LAI/QC, albedo/QA, escritos con tipo de dato original | GeoTIFF sin escalar | < 200 KB |
| `inst/extdata/modis-example/` | Variables físicas derivadas en la grilla de 1 km (lst, albedo, ndvi, lai, emissivity, utc_hour, doy, qa) para un AOI chileno pequeño (p. ej., 20 × 20 km) | GeoTIFF comprimido | < 500 KB |
| `data-raw/modis-example.R` (excluido del tarball) | Script que reproduce los recortes desde los HDF originales | R | – |
| Procedencia | `LocalGranuleID`, producto, colección, DOI, fecha de producción, tesela, ventana fila/columna, versión de GDAL/`terra`, fecha de descarga | YAML/CSV junto a los datos y en `@source` de roxygen | – |

Casos que los fixtures deben cubrir: relleno, MODLAND 00/01/10/11,
`view_time` relleno con LST válida, LAI = 253 (estéril), albedo de inversión
de magnitud, nieve, agua. Si un caso no aparece en el recorte real, se
agrega un fixture **sintético** marcado como tal (nunca presentado como
dato real). AOI y fecha: decisión MP-12.

**Escena de ejemplo (MP-12, decidida por el autor el 2026-11-04; M4-26,
M4-27).** Provincia de Cauquenes; **2019-02-15** (UTC), Terra, tesela
h12v12 (3 % de nubosidad de tesela), colección 061; opciones explícitas de
`data-raw/modis-example.R` (MOD11A1, albedo `"white_sky"`, E3 con
`lai_nonveg = 0`, MOD13A2 con `"period_pixel_lag"`, MCD43A3 con
`"same_day"`, MCD15A2H con `"period"`, `"mean"`, `min_valid_fraction = 1`,
`qa_policy = "flag"`).

**Paso pendiente: generar y versionar la escena** (no se puede hacer sin
credenciales ni red; ejecutable más tarde sin más contexto):

1. Requisitos: R con `EarthFlux` en desarrollo (fuentes de este
   repositorio), `pkgload`, `jsonlite` y `terra` con el driver GDAL HDF4
   (el script lo comprueba); un token de usuario de NASA Earthdata Login
   (https://urs.earthdata.nasa.gov, *Generate Token*); salida HTTPS
   permitida a `cmr.earthdata.nasa.gov` (búsqueda),
   `data.lpdaac.earthdatacloud.nasa.gov` (descarga), `urs.earthdata.nasa.gov`
   (autenticación) y al almacenamiento al que LP DAAC redirige las
   descargas (URL firmadas).
2. Comando, desde la raíz de las fuentes, en una rama nueva desde `main`:

   ```bash
   EARTHDATA_TOKEN=<token> Rscript data-raw/modis-example.R
   ```

   El token solo se lee del entorno (nunca se escribe ni se imprime); no
   guardarlo en `.Renviron` del repositorio.
3. Salida esperada en consola: la tabla de los 4 granulos (`role`,
   `file`, `period_start`, `period_end`), uno por producto:
   `MOD11A1.A2019046.h12v12.061.*.hdf` y `MCD43A3.A2019046.h12v12.061.*.hdf`
   (día 46 = 2019-02-15) y los compuestos MOD13A2 y MCD15A2H cuyo período
   contiene esa fecha (su período lo dan los metadatos CMR, A-M4-5); y el
   mensaje `Example scene: 14 files, <n> KB.` con `<n>` < 500. El script
   se detiene con un error claro si falta el token, si CMR no devuelve
   exactamente un granulo por producto, si una descarga no es HDF4, si no
   hay driver HDF4 o si la escena supera 500 KB. Las descargas quedan en
   `data-raw/private/modis/` (ignorado por git).
4. Archivos esperados en `inst/extdata/modis-example/` (14): `lst.tif`,
   `albedo.tif`, `ndvi.tif`, `lai.tif`, `emissivity.tif`,
   `band_emissivity.tif` (capas `emis_31`, `emis_32`), `overpass_doy.tif`,
   `overpass_utc_hour.tif`, `flags.tif` (8 capas `INT4S`: `flags_lst`,
   `flags_overpass_time`, `flags_albedo`, `flags_ndvi`, `flags_lai`,
   `flags_emissivity`, `flags_emis_31`, `flags_emis_32`; `NA` fuera de la
   provincia), `valid_fraction.tif`, `ndvi_lag_days.tif`, `flag_bits.csv`,
   `provenance.csv` y `provenance.yml` (granulos con `LocalGranuleID`,
   concept ID de CMR, DOI, fechas, producción y descarga; opciones,
   incluido `lai_nonveg_249` … `lai_nonveg_254: 0`; estados; versiones).
5. Revisar `provenance.yml` y el conteo de `EF_SURF_LAI_ASSIGNED`, luego
   `devtools::check()` (tamaño del tarball) y versionar:

   ```bash
   git add inst/extdata/modis-example
   git commit -m "data: add the modis example scene of cauquenes"
   ```

   Después: contraste con el granulo real (§16, A-M4-3), fixtures de DN
   crudos y documentación de la escena (`@source`).

Los HDF completos nunca se versionan (`DEVELOPMENT.md` §6).

---

## 13. Funciones internas propuestas

Todas internas (`@noRd`), sin prefijo `ef_` (reservado a la API pública de
bajo nivel, `DEVELOPMENT.md` §1). El paralelismo sigue `ARCHITECTURE.md`
§6.3 (secuencial por defecto; `future` entre fechas/teselas).

### 13.1 `R/io-modis.R`

| Función | Entradas | Salida | Notas |
|---|---|---|---|
| `modis_product_spec(product, collection = "061")` | Nombre corto, colección | `data.frame` por capa: SDS, grilla, tipo, escala, offset, convención de offset, rango válido, relleno, unidad, ID de tabla QA, fuente (doc, página, tabla) | Única fuente de constantes de producto; se construye desde §5. Error clasificado si la colección no tiene ficha |
| `modis_parse_filename(path)` | Ruta | Lista: producto, fecha UTC (`Date`), doy, tesela h/v, colección, marca de producción | Convención de §4 |
| `modis_list_layers(path)` | Ruta HDF | Nombres de subdatasets | Contraste exacto con la ficha |
| `modis_read_raw(path, layers, aoi = NULL)` | Ruta, capas, AOI (`SpatVector`/`SpatExtent` en cualquier CRS) | `SpatRaster` de DN crudos, recortado en sinusoidal | Verifica que no se aplicó escalado (MP-11) |
| `modis_read_converted(path, product, layer, scaled)` | GeoTIFF/NetCDF convertido | `SpatRaster` | `scaled` obligatorio |
| `modis_mosaic_tiles(rasters)` | Lista de `SpatRaster` del mismo día y producto | `SpatRaster` | §11.4 |

### 13.2 `R/prep-modis.R`

| Función | Entradas (unidades) | Salida (unidades) |
|---|---|---|
| `modis_apply_scale(dn, spec_row)` | DN | Valor físico; relleno y fuera de rango → `NA`; máscaras lógicas para flags |
| `modis_qa_field(qa, start, n)` | QA entero | Entero del campo (§10.4) |
| `modis_qa_decode(qa, product, layer)` | QA entero | `data.frame`/capas con campos con nombre |
| `modis_qa_flags(decoded, policy)` | Campos decodificados | Registros `earthflux_flag` (cuando los códigos estén registrados) |
| `modis_lst(raw, product)` | DN de LST y QC | `lst` [K] + QA |
| `modis_overpass_time(view_time_h, lon_deg, date_utc)` | h (solar local), grados, `Date` | Lista `doy` (–), `utc_hour` [h]; envoltorio a `POSIXct` UTC para el contrato. Solo MOD11A1/MYD11A1 hasta resolver §6.4 |
| `modis_view_zenith(view_angl)` | DN | grados (con signo este/oeste) |
| `modis_band_emissivity(raw)` | DN `Emis_*` | ε por banda [–] |
| `modis_broadband_emissivity(e31, e32, lai, method)` | [–] | ε₀ [–] (E3 `CANDIDATA`; E1/E2/E4 `earthflux_method_not_implemented`, lista de §8.2; MP-04) |
| `modis_ndvi_from_reflectance(red, nir)` | Reflectancia [–] | NDVI [–] (D4 ec. 1) |
| `modis_ndvi_composite(raw, lst_date)` | DN MOD13 | NDVI [–] + desfase [días] |
| `modis_lai(raw, …, lai_nonveg = NULL)` | DN MCD15A2H | LAI [m² m⁻²] + clase no vegetada + QA; con `lai_nonveg`, LAI asignado a las clases no vegetadas y `EF_SURF_LAI_ASSIGNED` (MP-06, M4-28) |
| `modis_albedo(bsa, wsa, diffuse_fraction = NULL, method)` | [–] | α [–] (MP-03) |
| `modis_land_cover(raw)` | DN MCD12Q1 | Clase IGBP + QC |
| `modis_to_grid(x, template, method, min_valid_fraction)` | `SpatRaster` | `SpatRaster` en la grilla de trabajo + fracción válida |
| `modis_match_composite(lst_date, composite_dates)` | `Date` | Índice del compuesto y desfase [días] |
| `modis_surface_state(files, aoi, options)` (`R/modis-surface.R`) | Fuentes `modis_source()` o rutas HDF4, AOI, `modis_surface_options()` (producto LST, métodos, `qa_policy`, `lai_nonveg`) | `earthflux_surface_state` con el contrato de `surface` (`lst`, `albedo`, `ndvi`, `lai`, `emissivity`, `overpass_time`, `qa`), `band_emissivity` (E1 en preparación) + procedencia (`ARCHITECTURE.md` §4) |
| `modis_provenance(sources, options, rows)` (`R/modis-surface.R`) | Fuentes, opciones, filas de la tabla | Lista: granulos, colecciones, DOI, métodos, estados, filas de la tabla, versiones de GDAL/`terra`/PROJ/GEOS/R |

Estado de implementación: bloque único al inicio de este documento; las
decisiones de implementación de esta sección son M4-11 … M4-30 de
`DECISIONS.md` §1.4.

---

## 14. Tests planificados (`tests/testthat/test-modis.R`)

Aritmética desde valores `VERIFICADA` (tolerancia de máquina):

| Caso | Entrada | Esperado |
|---|---|---|
| S1 | `LST_Day_1km` DN = 15000 | 300.00 K |
| S2 | DN = 7500 / 65535 | 150.00 K / 1310.70 K |
| S3 | `LST_Day_1km` DN = 0 | `NA` + máscara de relleno |
| S4 | `Emis_31` DN = 255 / 1 / 0 | 1.000 / 0.492 / `NA` |
| S5 | `Day_view_angl` DN = 0 / 65 / 130 / 255 | −65° / 0° / +65° / `NA` |
| S6 | `Day_view_time` DN = 106 / 255 | 10.6 h / `NA` |
| S7 | NDVI MOD13 DN = −3000 / −2000 / 10000 | `NA` / −0.2 / 1.0 |
| S8 | `Lai_500m` DN = 35 / 253 | 3.5 m² m⁻² / `NA` + clase "estéril" |
| S9 | `Albedo_WSA_shortwave` DN = 180 / 32767 | 0.180 / `NA` |
| S10 | Reflectancia DN = −28672 | `NA` |
| Q1 | `QC_Day` = 0 | MODLAND 00, error ε ≤ 0.01, error LST ≤ 1 K |
| Q2 | `QC_Day` = 0b01010001 (= 81) | bits 1–0 = 01; 5–4 = 01; 7–6 = 01 |
| Q3 | MOD21 `QC` = 2 | MODLAND 10 |
| Q4 | `QC_500m_1` = 787410671 (relleno) | Relleno reconocido sin desbordamiento uint32 |
| Q5 | `FparLai_QC` = 64 | SCF_QC = 010 (bits 7–5); `TODO`: contrastar con la interpretación de D5 Fig. 3 (imagen no extraíble) |
| V1–V4 | §6.2 | Según tabla |
| N1 | red = 0.05, NIR = 0.45 | NDVI = 0.8 |
| G1 | Agregación 2 × 2 con una celda inválida y umbral 0.75 | Promedio de 3 celdas + fracción 0.75 |

Otros: el lector rechaza colecciones sin ficha; el lector detecta escalado
automático indebido; mismo resultado en vector y `SpatRaster`; mismo
resultado con distinto tamaño de bloque y en secuencial vs paralelo
(`ARCHITECTURE.md` §6.3, §6.6).

---

## 15. Registro de decisiones abiertas

| ID | Decisión | Opciones | Recomendación provisional |
|---|---|---|---|
| MP-01 | Producto LST | MOD11A1/MYD11A1 vs MOD21A1D/MYD21A1D | MOD11A1 por defecto (view time documentado); MOD21A1D como alternativa cuando se resuelva §6.4 |
| MP-02 | Plataforma | Terra, Aqua o ambas (dos escenas por día) | Configurable; registrar plataforma; considerar deriva (§7) |
| MP-03 | Albedo | A1–A6 (§8.1) | A1 si se resuelve la circularidad con Rs↓; si no, A2/A3 explícitas |
| MP-04 | Emisividad de banda ancha | E1–E4 (§8.2) | Vinculada a RC-14; preferir E1/E2 por coherencia con LST, con referencia primaria verificada. Sigue abierta: E3 implementada; para E1 las bandas 31/32 ya viajan en el estado y lo que falta está en la lista de §8.2 (M4-30) |
| MP-05 | Fuente de NDVI | MOD13A2, MOD13Q1 agregado, MOD09GA/GQ diario | MOD13A2 + desfase por píxel (T2) |
| MP-06 | LAI y clases no vegetadas | `NA` + flag; asignación explícita por el usuario (p. ej., 0 para clase 253) con flag; LAI empírico | `NA` + flag por defecto; asignación solo como opción declarada. **DECIDIDA (autor, 2026-11-04)**: opción `lai_nonveg` (un valor o uno por clase) con `EF_SURF_LAI_ASSIGNED`; valor `CANDIDATA`; la escena de ejemplo usa 0 (§5.7; M4-28, M4-29) |
| MP-07 | Desfase temporal | T1–T5 (§9.1) | T2 (NDVI/LAI), T5 (albedo) |
| MP-08 | Grilla y remuestreo | Grilla LST 1 km sinusoidal vs otra grilla/CRS | Grilla LST nativa; agregación por factor entero |
| MP-09 | Política QA por defecto | `"flag"` vs `"mask"` | `"flag"`; anclas con filtro estricto |
| MP-10 | Formatos de entrada | Solo HDF4; HDF4 + convertidos | HDF4 + convertidos con declaración obligatoria |
| MP-11 | Escala/offset | Automático GDAL vs ficha interna | Ficha interna (§11.3) |
| MP-12 | Datos de ejemplo | AOI, fecha, productos | AOI: **provincia de Cauquenes, Región del Maule** (decisión del autor, 2026-11-04; área de estudio habitual, también en `thermify`). Fecha: **2019-02-15**, Terra, tesela h12v12, 3 % de nubosidad de tesela (**decisión del autor, 2026-11-04**; M4-27). Pendiente: ejecutar el script y versionar la escena (§12) |
| MP-13 | Migración a C7 de tierra | Esperar / soportar ambas | Fichas por colección; C6.1 hasta que C7 de tierra esté documentada |
| MP-14 | Continuidad | VIIRS (VJ1/VJ2), Landsat, Sentinel-3 | Módulo de sensor separado; fuera de M4 |

Relación con decisiones existentes: RC-03 (tiempo; parcialmente resuelta
para MOD11A1 por §6.1) y RC-14 (emisividad) de `radiation-components.md`.

---

## 16. Pendientes de verificación

1. **Contraste con archivo real** (para cada producto de §5): nombres
   exactos de SDS y grillas, tipos, `scale_factor`, `add_offset`,
   `_FillValue`, `valid_range` y resolución leídos con `terra`/GDAL, y
   comparación con las tablas de este documento.
2. Discrepancia d1 (MOD11A1: observación única vs promedio) y su efecto en
   `Day_view_time`.
3. Discrepancia d2 (bits 3–2 de `QC_Day`).
4. Semántica de `View_Time` en MOD21A1D/MYD21A1D (§6.4).
5. Supuesto de §6.2: todas las observaciones del archivo caen en el día UTC
   del nombre.
6. Estado actual y fechas oficiales de fin de operación de Terra y Aqua
   (§7.1); errata "1:45 AM" en alerta 200068; fecha del artículo D15.
7. Existencia y calendario de productos de tierra C7 (§3).
8. Guía de usuario MCD43 C6.1 (host bloqueado): criterios de calidad
   recomendados, vigencia de D7 para C6.1, BSA a la hora de paso (MCD43A1).
9. Coeficientes de banda angosta → ancha (Liang, 2001) y de emisividad de
   banda ancha (Wang et al., 2005; referencia para MOD21) desde las fuentes
   primarias, con unidades, dominio y caso numérico.
10. Fracción difusa S para albedo *blue-sky* y su acoplamiento con el
    módulo de radiación.
11. Soporte HDF4 en binarios CRAN de `terra` para Windows y macOS (§11.1).
12. Comportamiento de `terra`/GDAL con `scale_factor`/`add_offset` en HDF4
    (¿aplica escalado automático?, ¿qué convención?) (§11.3).
13. Anidamiento exacto 500 m ↔ 1 km y dimensiones de la grilla de 250 m
    (§4).
14. Capa `_1` de MOD09GA: ¿misma pasada que la LST del día? (§5.3).
15. Offset de MOD09GA/GQ (= 0 esperado, no declarado en D3).
16. Discrepancias de rango válido de QA (d6, d6b, `QC_250m_1`).
17. Estado de la corrección de la anomalía MYD21 (§5.2).
18. Productos VIIRS L3 equivalentes (nombres, escalas, *view time*) (§7.3).
19. Formatos y escalado de servicios de subconjuntos en la nube (§11.2).
20. Requisitos de cita para datos MODIS redistribuidos en el paquete (§12).
21. Umbrales de los flags marcados "Sí" en §10.2 (con justificación
    bibliográfica antes de registrarlos).
22. Interpretación del ejemplo `FparLai_QC` = 64 de D5 (Fig. 3).
