# Plot methods ----------------------------------------------------------------------
#
# Purpose: diagnostic plots (e.g. anchor pixel context, energy balance
#   components, GWR residuals). Plotting packages, if any, must stay in
#   Suggests; the methods here use terra (Imports) only.
#
# Methods: plot.earthflux_result() (earthflux(), M5).

#' Plot an earthflux_result
#'
#' Maps one or more layers of the result with `terra::plot()` and marks the
#' anchor pixels (cold in blue, hot in red).
#'
#' @param x An `earthflux_result` (see [earthflux()]).
#' @param layer Character. Names of the layers to plot (default
#'   `"eta_24"`, the daily actual ET).
#' @param anchors Logical. Mark the anchor pixels.
#' @param ... Passed to `terra::plot()`.
#' @return `x`, invisibly.
#' @export
#' @noRd
plot.earthflux_result <- function(x, layer = "eta_24", anchors = TRUE, ...) {
  if (!is.character(layer) || length(layer) < 1L ||
      !all(layer %in% names(x$layers))) {
    ef_abort(sprintf("`layer` must be among: %s.",
                     paste(names(x$layers), collapse = ", ")),
             class = "earthflux_input_error")
  }
  for (nm in layer) {
    terra::plot(x$layers[[nm]],
                main = sprintf("%s (%s), %s", nm, x$units[[nm]],
                               format(x$date)), ...)
    if (isTRUE(anchors)) {
      px <- x$anchors$pixels
      pts <- terra::vect(terra::xyFromCell(x$layers, px$cell),
                         crs = terra::crs(x$layers))
      terra::points(pts, pch = 1, cex = 1.2,
                    col = ifelse(px$type == "cold", "blue", "red"))
    }
  }
  invisible(x)
}
