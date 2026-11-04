# Identidad visual de EarthFlux

Guía de marca e identidad gráfica — Versión 1.0 · Autor: Guillermo Servando
Fuentes-Jaque.

## 1. Concepto de marca

- **Nombre:** EarthFlux
- **Categoría:** software científico / paquete R
- **Área:** teledetección, evapotranspiración, balance energético y
  modelación ambiental
- **Eslogan propuesto:** *Mapping Earth's Water and Energy Fluxes.*

EarthFlux es un paquete científico orientado a la estimación de
evapotranspiración mediante productos satelitales MODIS, el modelo METRIC y
regresión geográficamente ponderada (GWR). Su identidad visual representa la
interacción entre la energía solar, la vegetación, el suelo y la atmósfera,
destacando el intercambio de agua y energía que gobierna la
evapotranspiración.

La propuesta se inspira en los paisajes agrícolas de Chile central y los
bosques templados del sur de Chile, sin representaciones cartográficas
explícitas ni fronteras nacionales.

Atributos que la identidad busca transmitir:

- **Rigor científico:** métodos físicos y computacionales reproducibles.
- **Conexión territorial:** ecosistemas agrícolas y forestales.
- **Tecnología geoespacial:** observación de la Tierra y modelación
  ambiental.
- **Simplicidad:** geometría reconocible, adaptable y legible en distintos
  tamaños.

## 2. Elementos gráficos

| Elemento | Representa | Diseño |
|---|---|---|
| Sol | Energía radiativa que impulsa el balance energético superficial y la evapotranspiración | Círculo amarillo con rayos geométricos sencillos |
| Flujos ascendentes | Transporte de agua desde la superficie hacia la atmósfera (el elemento más directamente ligado al nombre) | Dos flechas curvas celestes; formas fluidas que evocan movimiento y continuidad |
| Bosques | Bosques templados del centro-sur y sur de Chile | Dos árboles geométricos tipo conífera, legibles a baja resolución |
| Cultivos | Agroecosistemas y paisajes productivos de Chile central | Franjas curvas verdes que evocan parcelas, cobertura vegetal y variabilidad espacial |

La combinación de bosques y cultivos comunica que EarthFlux no se limita a un
solo uso del suelo.

### 2.1 Diseño vectorial adoptado (v7, 2026-11-04)

El hexágono oficial se construyó como SVG a partir de esta guía y de las
indicaciones del autor:

| Elemento | Diseño | Significado |
|---|---|---|
| Franja de terreno | Cruza todo el hexágono; base arqueada hacia arriba con borde verde claro | Curvatura de la Tierra; superficie terrestre |
| Loma de cultivos (izquierda) | Verde claro con hileras diagonales | Agroecosistemas de Chile central |
| Montículo de bosque (centro) | Verde oscuro, con un árbol latifoliado y una conífera | Bosque mixto (nativo y conífera) |
| Loma de suelo desnudo (derecha) | Ocre, separada de las demás por un filete del color de fondo | Suelo seco; píxel caliente de METRIC |
| Flujo de agua | Flecha ondulada celeste que nace de los cultivos | Evapotranspiración (calor latente, LE) |
| Flujo de calor | Flecha ondulada naranja que nace del suelo seco | Calor sensible (H) |
| Sol | Grande, asomando desde la esquina superior derecha | Radiación solar que impulsa el balance de energía |

El logo resume así el balance de energía superficial que modela el paquete:
radiación entrante, flujo de calor latente desde la vegetación y flujo de
calor sensible desde el suelo seco.

## 3. Paleta cromática

| Color | Código de referencia | Significado |
|---|---|---|
| Azul petróleo profundo | `#003B46` | Tecnología, ciencia y atmósfera |
| Verde vegetal | `#80C65A` | Bosques, cultivos y vegetación |
| Verde oscuro | `#248052` | Cobertura terrestre |
| Celeste | `#8AE4F3` | Agua, vapor y evapotranspiración |
| Amarillo solar | `#FFBE35` | Radiación y energía |
| Blanco cálido | `#F5F5F0` | Claridad y legibilidad |
| Tierra ocre | `#BA894E` | Suelo y superficie agrícola |
| Naranja calor | `#F5793B` | Flujo de calor sensible (H) |
| Naranja "Flux" | `#FC9C38` | Nombre del paquete (sílaba "Flux") |
| Verde bosque | `#1E6B40` | Montículo forestal y suelo |
| Fondo del hexágono / borde | `#01515E` / `#01303A` | Fondo y borde del hexágono |

Los códigos son referencias aproximadas para normalizar las propuestas
visuales y deben ajustarse al elaborar los archivos vectoriales definitivos.
La paleta mantiene compatibilidad con `thermify`: el azul petróleo es el
color estructural y los secundarios representan procesos científicos.

**Accesibilidad (contraste sobre blanco, WCAG):** `#003B46` 12,3:1 y
`#00606F` 7,2:1 (aptos para texto); `#248052` 4,9:1 (apto para texto
normal); celeste `#8AE4F3` (1,5:1) y amarillo `#FFBE35` (1,7:1) **no** deben
usarse para texto sobre fondo claro, solo sobre fondos oscuros o como
elementos gráficos.

## 4. Versiones del logotipo

### A. Hexágono (*hex sticker*)

Uso principal: paquete R, GitHub, pkgdown, presentaciones y documentación
técnica. Hexágono con vértices superior e inferior, fondo azul petróleo,
borde exterior grueso más oscuro, campos y árboles en la zona inferior, dos
flechas celestes ascendentes, sol en la parte superior derecha y el nombre
con «Earth» en blanco y «Flux» en naranja.

### B. Logotipo horizontal (*wordmark*)

Uso principal: README, encabezados web, publicaciones, material
institucional y presentaciones. Símbolo ambiental a la izquierda (árboles,
franjas agrícolas, flujos ascendentes y sol) y la palabra EarthFlux a la
derecha, sans serif de alto peso: «Earth» en blanco cálido y «Flux» en
celeste brillante.

### C. Ícono independiente

Uso principal: favicon, avatar, accesos directos y tamaños pequeños. Solo
el símbolo, sin texto. Para tamaños reducidos se recomienda simplificarlo
(un sol, una o dos flechas, una superficie vegetal, sin detalles internos
pequeños) para mantener legibilidad entre 32 × 32 y 128 × 128 px.

## 5. Tipografía

Sans serif moderna, geométrica y de bordes suaves; peso semibold o bold;
trazos limpios, alta legibilidad, proporciones amplias, sin ornamentos.
Tipografías recomendadas: **Inter**, **Montserrat**, **Nunito Sans**.

El nombre se escribe siempre **EarthFlux**: E y F mayúsculas, sin espacio.

## 6. Estilo gráfico

Lenguaje *flat design*: formas geométricas simples, colores planos y
contrastados, curvas suaves, contornos limpios, composición equilibrada,
pocos elementos de alta relevancia conceptual, sin texturas fotográficas y
con uso mínimo de sombras y degradados.

Evitar mapas políticos, fronteras nacionales, globos terráqueos detallados o
representaciones satelitales complejas: la identidad se concentra en los
procesos físicos observados, no en una localización específica.

## 7. Coherencia con `thermify` y `tempify`

EarthFlux forma parte de una familia conceptual de herramientas científicas
junto con `thermify` y `tempify`. Comparten simplicidad visual, geometría
reconocible, identidad cromática compatible, formato hexagonal para paquetes
R, variantes horizontales e iconografía ligada a su función científica.
Cada paquete conserva elementos propios:

- `thermify`: temperatura, acumulación de calor y frío, fenología.
- **EarthFlux:** evapotranspiración, vegetación, radiación y transferencia de
  energía.
- `tempify`: reconstrucción y densificación temporal de datos.

La coherencia no exige logotipos idénticos, sino un lenguaje gráfico común.

## 8. Archivos y estado de implementación

| Archivo | Estado | Uso |
|---|---|---|
| `branding/earthflux-hex.svg` | ✅ Maestro vectorial (v7), 7,5 KB, texto convertido a trazos (Inter Bold) | Hexágono oficial |
| `branding/earthflux-icon.svg` | ✅ Variante sin texto, para tamaños pequeños | Ícono y favicons |
| `branding/src/make-hex.py`, `branding/src/render-svg.js` | ✅ Generador reproducible (`python3 make-hex.py salida.svg [--icon]`) y renderizado a PNG | Regenerar el logo |
| `branding/earthflux-hex.png` | ✅ Renderizado del SVG (1040 × 1200, fondo transparente) | Usos raster |
| `branding/earthflux-icon.png` | ✅ Renderizado cuadrado del ícono (600 × 600) | Base de favicons |
| `branding/earthflux-hex-original.png` | Referencia histórica | Propuesta raster original del autor |
| `branding/earthflux-horizontal.svg` | ✅ Maestro vectorial: emblema circular con el paisaje del hexágono + nombre (Inter Bold en trazos); fondo `#012C35`, "Earth" `#F8F8F4` (14,0:1), "Flux" `#5CD0E8` (8,2:1) | README, web, presentaciones sobre fondo oscuro |
| `branding/earthflux-horizontal-light.svg` | ✅ Versión para fondo claro, fondo transparente; "Earth" `#01303A` (14,1:1), "Flux" `#087E9C` (contraste AA) | Documentos, pósteres, fondos claros |
| `branding/earthflux-horizontal.png`, `branding/earthflux-horizontal-light.png` | ✅ Renderizados 1720 × 540 | Usos raster |
| `branding/earthflux-horizontal-original.png` | Referencia histórica | Propuesta raster original del autor |
| `branding/src/earthflux_scene.py`, `make-wordmark.py` | ✅ Geometría compartida por todos los logos y generador del logo horizontal (`python3 make-wordmark.py salida.svg [--light | --transparent]`) | Regenerar los logos |
| `man/figures/logo.png` | ✅ 240 × 277 desde el SVG | Logo hexagonal del paquete; tarjetas sociales del sitio (`og:image`) |
| `man/figures/logo-horizontal.svg` | ✅ Igual a `earthflux-horizontal-light.svg` | Encabezado del README (modo claro) y portada de pkgdown |
| `man/figures/logo-horizontal-dark.svg` | ✅ Colores de fondo oscuro sin rectángulo de fondo (`--transparent`) | Encabezado del README en GitHub con modo oscuro |
| `pkgdown/extra.css`, `pkgdown/extra.js` | ✅ Ocultan el hexágono que pkgdown añade junto al título y fuerzan la versión clara (el sitio solo tiene tema claro) | Portada de pkgdown |
| `pkgdown/favicon/` | ✅ favicon.svg, favicon.ico y PNG de 16 a 512 px desde el ícono SVG | Sitio web |
| `branding/earthflux-monochrome.svg` | ⏳ Pendiente | Impresión y fondos especiales |

El tema del sitio pkgdown usa `#003B46` como color primario y `#00606F` para
enlaces (contraste 7,2:1 sobre blanco). La carpeta `branding/` está excluida
del paquete (`.Rbuildignore`); de los logos, solo los archivos de `man/figures/`
forman parte de él.

## 9. Síntesis

EarthFlux representa la interacción entre la superficie terrestre y la
atmósfera mediante una identidad científica, ambiental y tecnológica: cultivos,
bosques, energía solar y flujos ascendentes de agua, inspirados en los
paisajes agrícolas y forestales chilenos. La combinación de azul petróleo,
verde vegetal, celeste y amarillo da una estética contemporánea, coherente con
las herramientas científicas de R y adaptable a distintos formatos, legible
tanto en publicaciones como en interfaces digitales de baja resolución.
