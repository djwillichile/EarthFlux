# Fuentes de datos del estudio CEDES 2027

Todas las descargas se guardan en `data/raw/cache/` (fuera de git por
tamaño). Sus sumas MD5 están en `data/raw/manifest.csv`, que genera
`scripts/01_download_data.R`. Fecha de acceso: 5 de noviembre de 2026.

| Conjunto | Proveedor | Acceso | Resolución / período | Licencia o términos | Uso en el estudio |
|---|---|---|---|---|---|
| Escena MODIS `cauquenes_modis` (MOD11A1, MCD43A3, MOD13A2, MCD15A2H, C6.1) | NASA LP DAAC, empaquetada en EarthFlux 0.1.0 | `EarthFlux::cauquenes_modis`; procedencia en `data-raw/cauquenes_modis.yml` | 1 km (sinusoidal, 926,6 m); 15-02-2019, Terra | Datos NASA EOSDIS sin restricciones; citar los DOI de cada producto | Estado de superficie de METRIC |
| Límite de la provincia de Cauquenes | SUBDERE, DPA 2023 (en EarthFlux) | `inst/extdata/cauquenes-province.gpkg` | Vectorial | Ver `inst/extdata/cauquenes-province.yml` | Máscara y mapas |
| Copernicus DEM GLO-90 | ESA / Copernicus (AWS Open Data, `copernicus-dem-90m`) | `https://copernicus-dem-90m.s3.amazonaws.com/<tile>/<tile>.tif` | 3 arcsec (≈ 90 m) | Licencia de acceso libre de Copernicus DEM GLO-90 (uso y redistribución con atribución) | Elevación (1 km) y presión superficial |
| Natural Earth `ne_10m_land` | Natural Earth | `https://naciscdn.org/naturalearth/10m/physical/ne_10m_land.zip` | 1:10 m | Dominio público | Máscara tierra/mar y distancia a la costa |
| NOAA Integrated Surface Database (global-hourly) | NOAA NCEI (AWS Open Data, `noaa-global-hourly-pds`) | `https://noaa-global-hourly-pds.s3.amazonaws.com/2019/<USAF><WBAN>.csv` | Horaria (METAR/SYNOP), 2019 | Datos NOAA, uso libre | Estaciones de aeropuerto no repetidas en la DMC |
| Portal de Servicios Climáticos, SACLIM (DMC; incluye estaciones de INIA y de la Fundación para el Desarrollo Frutícola) | Dirección Meteorológica de Chile | Hoja mensual horaria RE1022: `https://climatologia.meteochile.gob.cl/application/mensualb/hojaMensualDatos/<código>/<año>/<mes>`; radiación RE1019: `.../mensual/radiacionGlobalInstantanea/<código>/<año>/<mes>`; script `scripts/01_download_dmc.py` | Horaria UTC (HH:00), enero–marzo 2019 | «Todos los datos e información publicados en este Portal son de acceso y uso público; […] se solicita citar a la Dirección Meteorológica de Chile como la fuente». Datos sin control de calidad del proveedor | Temperatura, humedad (punto de rocío o HR) y viento (solo estaciones DMC) |

## Fuentes evaluadas y no usadas

- **agrometeorologia.cl (INIA, Red Agroclimática Nacional):** la descarga
  requiere un formulario web con verificación antirrobot, o una clave de
  API. No se usó (las estaciones INIA llegan igualmente por SACLIM, aunque
  sin viento ni radiación).
- **API JSON de la DMC (datos de 15 min):** requiere registro (usuario y
  token). No se usó.
- **DGA (snia.mop.gob.cl):** protegida por reCAPTCHA.
- **CR2 explorador:** solo datos diarios.
- **Validación de ETa:** AmeriFlux tiene cinco sitios en Chile, ninguno en
  el área (CL-ACF, CL-SDF, CL-SDP, CL-FJS, CL-OPP). No se encontraron datos
  públicos de covarianza de torbellinos o lisímetros para el Maule en
  febrero de 2019. El conjunto Zenodo 10.5281/zenodo.15476997 (avellanos en
  Ñuble) contiene salidas de un modelo (SEB-PV), no mediciones, y está fuera
  de la escena.
- **Reanálisis (ERA5-Land u otros):** no se usan como verdad observacional.
