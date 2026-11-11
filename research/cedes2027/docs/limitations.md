# Informe de limitaciones científicas

Este informe delimita lo que el estudio pudo y no pudo demostrar. Las
cifras están en `results/tables/` y en el manuscrito.

## 1. Lo que no se validó

1. **Exactitud absoluta de ETa.** No hay mediciones públicas e
   independientes de flujo de calor latente o de ETa (covarianza de
   torbellinos, lisímetros) para la provincia de Cauquenes ni para el 15 de
   febrero de 2019 (`docs/data_sources.md`). Por eso **ninguna diferencia
   entre configuraciones puede interpretarse como mejora o deterioro de la
   exactitud de ETa**: el estudio mide cambios entre modelos, no errores.
2. **Radiación de onda corta.** La red no ofrece radiación media horaria
   (SACLIM publica el máximo horario de lecturas instantáneas), por lo que
   Rs se modela con la transmisividad de Allen (forma `CANDIDATA`) y no se
   contrasta con mediciones. Esto afecta por igual a todas las
   configuraciones, pero no a su nivel absoluto.
3. **Verificación de METRIC.** Varias formas usadas siguen `CANDIDATA` en el
   paquete: la transmisividad particionada, los criterios de selección de
   anclas y la regionalización (corroborada numéricamente con GWmodel, no
   contra una fuente primaria). El cruce con Allen, Tasumi y Trezza (2007)
   está pendiente (`dev/VERIFICATION.md`).

## 2. Representatividad y generalización

4. **Una sola escena.** El experimento M usa una escena MODIS (verano
   seco, cielo despejado). Sus resultados no se generalizan a otras
   estaciones del año, condiciones de nubosidad, años o regiones. La
   validación meteorológica (experimento R) sí cubre los 90 días de
   enero–marzo de 2019, pero solo a la hora del paso de Terra.
5. **Viento.** Solo las estaciones de la DMC y de aeropuertos miden viento
   en la red pública usada. Con ese número de estaciones, la regresión
   global y GWR del viento son infactibles o inestables; en METRIC se usa
   entonces el campo C1 (D-14). El efecto del viento espacial sobre la
   calibración queda evaluado solo con IDW.
6. **Escala.** MODIS de 1 km mezcla coberturas; la calibración interna es
   más frágil a esta escala que con Landsat (Tang et al., 2013; Long y
   Singh, 2013). Las anclas son medianas de grupos de celdas, no píxeles
   puros.
7. **Alturas de sensores y tiempo.** Se asumió temperatura y humedad a 2 m
   (la DMC documenta 1,5 m) y valores puntuales a HH:00 UTC. Los vacíos de
   hasta 6 h se rellenaron por interpolación lineal (D-09).

## 3. Decisiones que condicionan los resultados

8. Condiciones de borde (ETrF frío = 1,05; caliente = 0), criterios de
   anclas, método de G y piso de rugosidad son decisiones explícitas; su
   efecto se cuantificó en el experimento S, pero otras elecciones
   razonables (p. ej., LE_hot > 0 o anclas manuales) no se exploraron.
9. La elección de C1 como línea base responde a la práctica convencional;
   no implica que C1 sea correcta.
10. Las covariables de GWR se limitaron a elevación y distancia a la costa
    para evitar la circularidad Ta–LST; covariables de superficie podrían
    mejorar la interpolación de Ta, pero con riesgo de acoplamiento.

## 4. Implicaciones para la gestión del agua

11. Ninguna cifra del estudio debe convertirse en volúmenes de agua
    ahorrados ni en beneficios monetarios: eso exigiría validar ETa,
    agregar en el tiempo (temporada) y datos económicos (precio sombra del
    agua, costos de riego) que no forman parte de este trabajo.
