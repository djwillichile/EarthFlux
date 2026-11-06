# Compatibility with terra versions -------------------------------------------
#
# Adapters for terra calls whose return value changed between releases.
# DESCRIPTION requires terra (>= 1.7-65), which CI checks (job min-terra in
# .github/workflows/R-CMD-check.yaml). Each helper documents the terra
# release in which the new shape appeared: once the minimum reaches it, drop
# the old-shape branch (and its test in test-modis-io.R).
# Helpers here are internal and must not be exported.

#' File-level metadata tags of a SpatRaster as a named character vector
#'
#' `terra::metags()` returns a named character vector up to terra 1.8-29 and
#' a data frame with columns `name`, `value` and `domain` from terra 1.8-42
#' onwards (metadata domains). Both are normalised here; for the data frame
#' only the default domain (`""`) is kept, which is where `metags<-` with a
#' named vector writes.
#' @param r A `SpatRaster`.
#' @param m The value of `terra::metags(r)` (an argument so that both shapes
#'   can be tested whatever terra is installed).
#' @return A named character vector (possibly empty).
#' @noRd
modis_metags <- function(r, m = terra::metags(r)) {
  if (is.null(m) || length(m) == 0L) {
    return(stats::setNames(character(0), character(0)))
  }
  if (is.data.frame(m) || is.matrix(m)) {
    m <- as.data.frame(m, stringsAsFactors = FALSE)
    if (nrow(m) == 0L) {
      return(stats::setNames(character(0), character(0)))
    }
    if ("domain" %in% names(m)) {
      m <- m[is.na(m$domain) | m$domain == "", , drop = FALSE]
    }
    return(stats::setNames(as.character(m$value), as.character(m$name)))
  }
  stats::setNames(as.character(m), names(m))
}

#' GDAL, PROJ and GEOS versions used by terra
#'
#' `terra::gdal(lib = "all")` returns a named character vector up to terra
#' 1.9-45 and a one-row data frame (with an extra `TBB` column) from terra
#' 1.9-46 onwards; `$` fails on the former. Both are normalised to a list.
#' @param v The value of `terra::gdal(lib = "all")` (an argument so that both
#'   shapes can be tested whatever terra is installed).
#' @return A list with character elements `gdal`, `proj` and `geos`.
#' @noRd
modis_lib_versions <- function(v = terra::gdal(lib = "all")) {
  v <- as.list(v)
  lapply(c(gdal = "gdal", proj = "proj", geos = "geos"), function(k) {
    x <- v[[k]]
    if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x[[1L]])
  })
}
