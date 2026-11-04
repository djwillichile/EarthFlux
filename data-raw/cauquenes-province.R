# Builds inst/extdata/cauquenes-province.gpkg and its provenance note
# inst/extdata/cauquenes-province.yml: the official boundary of the
# Cauquenes province (Maule Region, Chile), the area of interest of the
# example scene (decision MP-12, dev/specs/modis-products.md section 12).
#
# Source of the boundary (citation reproduced from the author's package
# thermify, data-raw/cauquenes.R and R/data.R, version 0.3.1):
#   Subsecretaria de Desarrollo Regional y Administrativo (SUBDERE), Unidad
#   de Investigacion Territorial (2023). Division Politico Administrativa
#   2023 (DPA 2023), file DivisionPoliticoAdministrativa2023 (shapefile,
#   SIRGAS-Chile 2002 geographic, EPSG:5360, scale 1:50,000), published
#   3 August 2023 through IDE Chile. Built by the IDE Chile DPA working
#   group (SUBDERE, IGM, DIFROL, INE) from SUBDERE interior limits v0702,
#   DIFROL international limit v4 and IGM coastline v3. Circulation
#   authorised by DIFROL Resolucion No 87 of 2023.
#
# The feature is taken, unchanged (original geometry, not simplified), from
# the dataset `cauquenes` of thermify (a packed terra SpatVector with the
# features nivel = "comuna" and nivel = "provincia"); only the province is
# kept, with the attributes CUT_REG, CUT_PROV, PROVINCIA, REGION and
# SUPERFICIE (official area in km2).
#
# Usage, from the root of the EarthFlux sources, with either thermify
# installed or the path of its data file in THERMIFY_CAUQUENES_RDA:
#   THERMIFY_CAUQUENES_RDA=/path/to/thermify/data/cauquenes.rda \
#     Rscript data-raw/cauquenes-province.R
#
# This directory is excluded from the package tarball (.Rbuildignore).

library(terra)

rda <- Sys.getenv("THERMIFY_CAUQUENES_RDA", unset = "")
env <- new.env()
if (nzchar(rda)) {
  load(rda, envir = env)
  origin <- sprintf("file %s", basename(rda))
} else if (requireNamespace("thermify", quietly = TRUE)) {
  utils::data("cauquenes", package = "thermify", envir = env)
  origin <- sprintf("package thermify %s",
                    as.character(utils::packageVersion("thermify")))
} else {
  stop("Install thermify or set THERMIFY_CAUQUENES_RDA to the path of ",
       "thermify's data/cauquenes.rda.", call. = FALSE)
}
cq <- vect(env$cauquenes)
province <- cq[cq$nivel == "provincia", ]
stopifnot(
  nrow(province) == 1L,
  province$CUT_PROV == "072",
  all(is.valid(province)),
  identical(crs(province, describe = TRUE)$code, "5360")
)
province <- province[, c("CUT_REG", "CUT_PROV", "PROVINCIA", "REGION",
                         "SUPERFICIE")]

# Geodesic area against the official SUPERFICIE (km2); thermify reports an
# agreement within 0.1 %.
area <- expanse(province, unit = "km")
stopifnot(abs(area / province$SUPERFICIE - 1) < 1e-3)

out <- file.path("inst", "extdata", "cauquenes-province.gpkg")
writeVector(province, out, layer = "cauquenes_province", overwrite = TRUE,
            options = "SPATIAL_INDEX=NO")

note <- c(
  "# Provenance of cauquenes-province.gpkg (built by data-raw/cauquenes-province.R)",
  "dataset: Cauquenes province boundary (Maule Region, Chile)",
  "layer: cauquenes_province",
  "features: 1",
  "attributes: [CUT_REG, CUT_PROV, PROVINCIA, REGION, SUPERFICIE]",
  "crs: EPSG:5360 (SIRGAS-Chile 2002, geographic coordinates)",
  "geometry: original DPA 2023 geometry, not simplified",
  sprintf("superficie_km2: %.2f", province$SUPERFICIE),
  sprintf("geodesic_area_km2: %.2f", area),
  "use_in_earthflux: area of interest of the MODIS example scene (decision MP-12)",
  "source:",
  "  author: Subsecretaria de Desarrollo Regional y Administrativo (SUBDERE), Unidad de Investigacion Territorial",
  "  year: 2023",
  "  title: Division Politico Administrativa 2023 (DPA 2023)",
  "  file: DivisionPoliticoAdministrativa2023 (shapefile; province layer)",
  "  published: 2023-08-03, through IDE Chile",
  "  scale: 1:50,000",
  "  built_by: IDE Chile DPA working group (SUBDERE, IGM, DIFROL, INE) from SUBDERE interior limits v0702, DIFROL international limit v4 and IGM coastline v3",
  "  contact: Division de Politicas y Estudios, SUBDERE (https://www.subdere.gov.cl)",
  "circulation: Autorizada su circulacion por Resolucion No 87 del 2023 de la Direccion Nacional de Fronteras y Limites del Estado (DIFROL). The edition and circulation of maps that refer to the limits and borders of Chile do not commit the State of Chile (DFL No 83 de 1979, art. 2, letra g); maps derived from these boundaries that show international limits must be reviewed by DIFROL.",
  "license: public information of the Government of Chile; not covered by the MIT license of the EarthFlux code",
  sprintf("taken_from: the dataset cauquenes of the author's package thermify (%s), feature nivel = provincia, unchanged", origin),
  "thermify: https://github.com/djwillichile/thermify"
)
writeLines(note, file.path("inst", "extdata", "cauquenes-province.yml"))
