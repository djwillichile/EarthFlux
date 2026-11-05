---
title: "EarthFlux: desarrollo de un paquete R para la modelación de flujos de energía y agua mediante observaciones de la Tierra"
subtitle: "Resumen extendido — 3rd International Workshop CEDES «Economics and Sustainability» (Valdivia, 21–22 de enero de 2027)"
---

<!--
Registro de la postulación (no forma parte del paquete: dev/ está en .Rbuildignore).
Plazo: 8 de noviembre de 2026, 23:59 GMT · Envío: cedes@uss.cl · Notificación: 16 de noviembre de 2026.
Cifras tomadas del repositorio a la fecha 2026-11-05 (EarthFlux 0.1.0 / 0.1.0.9000);
ver "Trazabilidad de las cifras" al final antes de enviar.
-->

| Campo | Contenido |
|---|---|
| **Título** | EarthFlux: desarrollo de un paquete R para la modelación de flujos de energía y agua mediante observaciones de la Tierra |
| **Autor** | Guillermo Servando Fuentes-Jaque (ORCID 0000-0002-7864-4899) |
| **Afiliación** | [Unidad / Facultad], Universidad San Sebastián, Chile |
| **Correo** | gfuentesj@correo.uss.cl |
| **Modalidad** | Presentación oral |
| **Ejes temáticos** | (4) Integración de la ciencia del clima en la toma de decisiones económicas · (9) Medición y valoración de servicios ecosistémicos |
| **Idioma** | Español |
| **Palabras clave** | evapotranspiración real; balance de energía superficial; METRIC; MODIS; regresión geográficamente ponderada; software científico abierto; contabilidad del agua |

## Resumen

**Contexto.** En Chile central, la megasequía iniciada en 2010 y la reforma
del Código de Aguas (Ley 21.435, de 2022) han desplazado la discusión desde
el agua *asignada* hacia el agua *efectivamente consumida*. La
evapotranspiración real (ETa) es la variable que cuantifica ese consumo y es
el eslabón físico entre clima, uso del suelo y valor económico del agua:
sin ella no es posible auditar balances hídricos de cuenca, evaluar la
eficiencia de inversiones en riego ni valorar el servicio ecosistémico de
regulación hídrica. Los modelos de balance de energía superficial
alimentados por satélite, como METRIC, permiten estimar la ETa de forma
espacialmente explícita, pero suelen depender de una única estación
meteorológica supuesta representativa de toda la escena, y sus
implementaciones disponibles son poco auditables. En territorios
heterogéneos —como el secano interior y costero del Maule— ese supuesto
introduce una incertidumbre que se propaga, sin ser cuantificada, a
cualquier decisión económica construida sobre la ETa.

**Objetivo.** Presentar EarthFlux, un paquete R de código abierto para
modelar flujos de energía y agua desde observaciones de la Tierra, cuyo
primer objetivo es la ETa diaria con METRIC sobre productos MODIS, con
forzamiento meteorológico que puede variar en el espacio.

**Métodos.** EarthFlux implementa la cadena METRIC como funciones
modulares e independientes del sensor (radiación neta, flujo de calor del
suelo, selección auditable de píxeles ancla, calibración iterativa del
calor sensible con corrección de estabilidad, calor latente y ETa diaria),
el control de calidad de estaciones y la evapotranspiración de referencia
(FAO-56 y ASCE-EWRI), y la regionalización espacial de las variables
meteorológicas con tres familias comparables bajo una interfaz común:
estación representativa (C1), regresión global e IDW (C2) y regresión
geográficamente ponderada (GWR, C3), con validación cruzada espacial por
bloques y procesamiento paralelo opcional. El diseño privilegia la
trazabilidad: cada valor físicamente anómalo se marca con diagnósticos en
lugar de corregirse en silencio, y cada resultado conserva su procedencia.
La hipótesis de que el forzamiento espacial reduce el error de la ETa
(H1) no se asume: el paquete está construido para contrastarla mediante un
diseño experimental pre-registrado que aísla cada punto de entrada del
forzamiento en METRIC.

**Resultados.** La versión 0.1.0 (noviembre de 2026; licencia MIT; DOI
10.5281/zenodo.23981326) expone 73 funciones y más de 600 pruebas
automatizadas. La verificación contra fuentes primarias reproduce los
ejemplos resueltos de FAO-56; de 49 formulaciones del núcleo contrastadas
con el manual de los autores del método, 31 quedaron verificadas, 3
corroboradas y 9 siguen como candidatas, y se detectaron 7 discrepancias,
2 de las cuales se corrigieron en el código. El núcleo GWR coincide con
GWmodel hasta 10⁻¹⁰ y entrega resultados idénticos en ejecución secuencial
y paralela. Como caso de aplicación se presenta una escena MODIS de la
provincia de Cauquenes (15 de febrero de 2019; 3 779 píxeles de 1 km, 96,7 %
con temperatura superficial válida), cuya preparación documenta la
procedencia de cada gránulo y la calidad de cada píxel. Un prototipo
previo del autor evidenció dos riesgos que hoy son parámetros explícitos:
la fragilidad de la calibración interna a 1 km y la circularidad de usar la
temperatura superficial como covariable de la temperatura del aire.

**Discusión.** La contribución no es un mapa de ETa, sino una
infraestructura verificable que hace explícita la incertidumbre del
forzamiento meteorológico antes de que llegue a la contabilidad hídrica o
a la valoración económica del agua. Se discuten sus implicancias para la
fiscalización del uso consuntivo, la evaluación de programas de riego y la
valoración de servicios ecosistémicos hídricos en países en desarrollo, así
como los límites actuales: la validación con observaciones independientes
de ETa constituye la siguiente etapa del proyecto.

## Abstract (English)

**EarthFlux: an R package for modelling land-surface energy and water
fluxes from Earth observation data**

In central Chile, the megadrought that began in 2010 and the 2022 reform of
the Water Code have shifted the debate from water that is *allocated* to
water that is *actually consumed*. Actual evapotranspiration (ETa) measures
that consumption and links climate, land use and the economic value of
water. Satellite surface energy balance models such as METRIC map ETa, but
usually rely on a single weather station assumed to represent the whole
scene, and their implementations are hard to audit. In heterogeneous
landscapes this assumption introduces an unquantified uncertainty that
propagates into every economic decision built on ETa.

We present EarthFlux, an open-source R package whose first target is daily
ETa from METRIC and MODIS with spatially varying meteorological forcing. It
implements the METRIC chain as modular, sensor-independent functions; weather
station quality control and reference evapotranspiration (FAO-56,
ASCE-EWRI); and the regionalization of weather variables with three
comparable families (representative station, global regression or IDW, and
geographically weighted regression), with spatial block cross-validation
and optional parallel processing. Anomalous values are flagged, never
silently corrected, and every result keeps its provenance. The hypothesis
that spatial forcing reduces ETa error is not assumed but framed for testing
through a pre-registered experimental design.

Release 0.1.0 (November 2026, MIT licence, DOI 10.5281/zenodo.23981326)
exposes 73 functions and more than 600 automated tests. It reproduces the
FAO-56 worked examples; of 49 core formulations checked against the method
authors' manual, 31 were verified, 3 corroborated and 9 remain candidates,
and 7 discrepancies were found, 2 of them corrected in the code. The GWR
core agrees with GWmodel to 1e-10 and gives identical sequential and
parallel results. An application scene covers Cauquenes province (Maule
Region; 15 February 2019; 3,779 1-km pixels, 96.7 % with valid land surface
temperature). The contribution is a verifiable infrastructure that makes
forcing uncertainty explicit before it reaches water accounting and the
economic valuation of water; validation against independent ETa
observations is the next stage.

**Keywords:** actual evapotranspiration; surface energy balance; METRIC;
MODIS; geographically weighted regression; open scientific software; water
accounting.

## Correo de envío

> **Para:** cedes@uss.cl
> **Asunto:** Envío de resumen – 3rd International Workshop CEDES 2027 – Fuentes-Jaque
>
> Estimado Comité Científico:
>
> Junto con saludar, envío para su evaluación el resumen extendido del
> trabajo «EarthFlux: desarrollo de un paquete R para la modelación de
> flujos de energía y agua mediante observaciones de la Tierra», para ser
> presentado en modalidad oral en el 3rd International Workshop CEDES
> «Economics and Sustainability» (Valdivia, 21 y 22 de enero de 2027).
>
> El trabajo se inscribe en los ejes «Integrating Climate Science into
> Economic Decision-Making» y «Measurement and Valuation of Ecosystem
> Services». Se adjunta el resumen en español, con su versión en inglés.
>
> Autor: Guillermo Servando Fuentes-Jaque (ORCID 0000-0002-7864-4899),
> [Unidad / Facultad], Universidad San Sebastián.
>
> Quedo atento a cualquier consulta.
>
> Saludos cordiales,
> Guillermo Fuentes-Jaque

## Trazabilidad de las cifras

Verificar antes de enviar; todas provienen del repositorio a la fecha
2026-11-05.

| Cifra | Fuente en el repositorio |
|---|---|
| Versión 0.1.0, MIT, DOI 10.5281/zenodo.23981326 | `CITATION.cff`, `DESCRIPTION` |
| 73 funciones exportadas | `NAMESPACE` (líneas `export(...)`) |
| > 600 pruebas automatizadas (614 bloques `test_that`) | `tests/testthat/` |
| Ejemplos FAO-56 reproducidos | `dev/VALIDATION_PLAN.md` §1.3.1; `README.md` |
| 49 formulaciones; 31 verificadas (30 SEBAL-Idaho 2002 + 1 IAHS 2012); 3 corroboradas; 9 candidatas; 7 discrepancias, 2 corregidas | `dev/VERIFICATION.md` §2 (las 6 filas restantes: 3 sin cambio por redondeo y 3 formas no implementadas) |
| GWR = GWmodel 2.4-1 hasta 1e-10; secuencial = paralelo | `NEWS.md` (0.1.0) |
| Cauquenes 2019-02-15: 3 779 píxeles en la provincia, 3 656 con LST válida (96,7 %) | `data/cauquenes_modis.rda`, `data-raw/cauquenes_modis.yml` |
| Prototipo: anclas manuales, coeficiente del píxel frío 0,5 vs ~1,05, circularidad Ta-LST | `dev/decisions/antecedente-metric-modis.md` |
| H1 y diseño C1/C2/C3 | `dev/SCIENTIFIC_SPEC.md` §1.1; `dev/VALIDATION_PLAN.md` §2 |

Datos de la escena útiles para la presentación (no incluidos en el
resumen): LST 289,8–308,3 K (media 302,3 K); albedo medio 0,153; NDVI
medio 0,54; radiación de onda larga emitida 383–490 W m⁻² (media 458 W m⁻²).
