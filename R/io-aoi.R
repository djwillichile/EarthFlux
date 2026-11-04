# I/O: area of interest ---------------------------------------------------------
#
# Purpose: read and validate the area of interest (AOI) and express it in the
#   CRS of a raster, so that readers crop in the native grid of the data
#   before any reprojection (dev/specs/modis-products.md section 11.4).
#
# Spatial backend: terra (dev/ARCHITECTURE.md section 6.2, ACCEPTED).
#
# Implemented (internal):
#   aoi_extent()       AOI (SpatVector in any CRS, or SpatExtent) -> extent
#                      in the CRS of a raster
#   aoi_crop_extent()  the same, intersected with the raster, with a classed
#                      error when they do not overlap
#
# Not implemented yet: the target processing grid (decision MP-08).

#' Extent of an area of interest in the CRS of a raster
#'
#' A `SpatVector` is projected to the CRS of `x` (it must carry a CRS);
#' lines and polygons in geographic coordinates are densified every 1000 m
#' first, so that the bounding box of the projected vertices also contains
#' the curved edges (e.g. in the sinusoidal projection). A `SpatExtent` has
#' no CRS and is taken as already being in the CRS of `x`.
#'
#' @param aoi A `SpatVector` or a `SpatExtent`.
#' @param x A `SpatRaster` (its CRS is the target).
#' @return A `SpatExtent` in the CRS of `x`.
#' @noRd
aoi_extent <- function(aoi, x) {
  if (inherits(aoi, "SpatExtent")) {
    return(aoi)
  }
  if (!inherits(aoi, "SpatVector")) {
    ef_abort("`aoi` must be a SpatVector or a SpatExtent.",
             class = "earthflux_input_error")
  }
  if (!nzchar(terra::crs(aoi))) {
    ef_abort("`aoi` must have a coordinate reference system.",
             class = "earthflux_input_error")
  }
  if (terra::is.lonlat(aoi) && terra::geomtype(aoi) %in% c("lines", "polygons")) {
    aoi <- terra::densify(aoi, 1000)
  }
  if (!isTRUE(terra::same.crs(aoi, x))) {
    aoi <- terra::project(aoi, terra::crs(x))
  }
  terra::ext(aoi)
}

#' Extent of an area of interest intersected with a raster
#'
#' @inheritParams aoi_extent
#' @return A `SpatExtent` (CRS of `x`) inside the extent of `x`. Error
#'   `earthflux_modis_grid_error` when the AOI does not overlap `x`.
#' @noRd
aoi_crop_extent <- function(x, aoi) {
  e <- aoi_extent(aoi, x)
  common <- terra::intersect(terra::ext(x), e)
  if (is.null(common)) {
    ef_abort("The area of interest does not overlap the raster.",
             class = c("earthflux_modis_grid_error", "earthflux_input_error"))
  }
  # An AOI edge that falls on a cell edge up to rounding must not add a row
  # or column when the crop snaps outwards: shrink by 1e-6 cell when the
  # extent is wide enough.
  v <- as.vector(common)
  eps <- 1e-6 * terra::res(x)
  if (v[["xmax"]] - v[["xmin"]] > 4 * eps[1L]) {
    v[c("xmin", "xmax")] <- v[c("xmin", "xmax")] + c(1, -1) * eps[1L]
  }
  if (v[["ymax"]] - v[["ymin"]] > 4 * eps[2L]) {
    v[c("ymin", "ymax")] <- v[c("ymin", "ymax")] + c(1, -1) * eps[2L]
  }
  terra::ext(v)
}
