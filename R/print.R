# Print and summary methods ---------------------------------------------------------
#
# Purpose: concise print/summary methods for EarthFlux classes, always showing
#   units and the number of flagged elements. Methods of the classes of the
#   METRIC core, the forcing and the surface state live next to their
#   constructors; this file holds those of the workflow (M5):
#   earthflux_result (earthflux()) and earthflux_preset (ef_preset()).

#' Print an earthflux_preset
#'
#' @param x An `earthflux_preset` (see [ef_preset()]).
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
#' @noRd
print.earthflux_preset <- function(x, ...) {
  cat(sprintf("<earthflux_preset> %s (version %s, %s)\n", x$name, x$version,
              x$status))
  cat(strwrap(x$description, indent = 2, exdent = 2), sep = "\n")
  show <- function(label, values) {
    v <- vapply(values, function(e) {
      if (is.null(e)) "NULL" else if (is.list(e)) "<list>" else
        paste(format(e), collapse = ", ")
    }, character(1))
    cat(sprintf("%s:\n", label))
    cat(sprintf("  %-24s %s\n", names(v), v), sep = "")
  }
  show("MODIS", x$modis$surface_options)
  show("Terrain", x$terrain)
  show("Weather", x$weather[c("qc_policy", "use_qc", "one_station",
                              "several_stations", "variables")])
  show("ERA5", x$weather$era5)
  show("Reference ET", x$reference_et)
  show("Radiation", x$radiation)
  show("Soil heat flux, roughness, wind, lambda",
       c(soil_heat = x$soil_heat$method, zom = x$roughness$method,
         zom_min = x$roughness$zom_min, zom_station = x$wind$zom_station,
         d_station = x$wind$d_station, lambda = x$lambda$method))
  show("Anchors", x$anchors[c("aggregate", "search_area", "etrf_cold",
                              "etrf_hot")])
  show("Sensible heat", x$sensible_heat[c("lapse_rate", "datum_elevation")])
  show("ET", x$et)
  if (!is.null(x$terrain_rule)) {
    show("Terrain rule", x$terrain_rule[c("method",
                                          "max_elevation_difference",
                                          "flag", "status")])
  }
  cat(sprintf("Unverified elements (%d): %s\n", length(x$unverified),
              paste(names(x$unverified), collapse = ", ")))
  cat("Anchor criteria: x$anchors$criteria; relaxation: x$anchors$relax.\n")
  invisible(x)
}

#' Print an earthflux_result
#'
#' @param x An `earthflux_result` (see [earthflux()]).
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
#' @noRd
print.earthflux_result <- function(x, ...) {
  p <- x$provenance
  sc <- p$scene
  cat(sprintf("<earthflux_result> %s, preset %s (version %s, %s)\n",
              format(x$date), p$preset$name, p$preset$version,
              p$preset$status))
  cat(sprintf("  grid: %d x %d cells of %.0f m (MODIS sinusoidal), %d in the AOI\n",
              sc$grid$nrow, sc$grid$ncol, sc$grid$res[1L],
              p$counts[["in_aoi"]]))
  cat(sprintf("  weather: %s, %s; overpass %s to %s\n", sc$weather_source,
              if (identical(sc$regionalization_method, "station"))
                paste0("one station (", sc$representative_station, ")") else
                  paste0(sc$regionalization_method, ", ",
                         length(sc$stations_used), " stations"),
              sc$overpass_range[1L], sc$overpass_range[2L]))
  cp <- x$anchors$calibration_points
  cat(sprintf("  anchors: cold Ts %.2f K, hot Ts %.2f K; dT = %.4g + %.4g Ts_datum\n",
              cp$lst[cp$type == "cold"], cp$lst[cp$type == "hot"],
              x$h_calibration$a, x$h_calibration$b))
  rng <- function(nm) {
    v <- terra::values(x$layers[[nm]], mat = FALSE)
    v <- v[!is.na(v)]
    if (length(v) == 0L) return("all NA")
    sprintf("%.3g to %.3g %s (median %.3g, %d cells)", min(v), max(v),
            x$units[[nm]], stats::median(v), length(v))
  }
  tr <- sc$terrain_rule
  if (!is.null(tr) && "terrain_rule_excluded" %in% names(p$counts)) {
    cat(sprintf(paste0("  terrain rule: %d cells excluded (more than %g m ",
                       "outside the calibration range %.0f to %.0f m; kept %.0f ",
                       "to %.0f m)\n"),
                p$counts[["terrain_rule_excluded"]],
                tr$max_elevation_difference,
                min(tr$reference_elevations), max(tr$reference_elevations),
                tr$range[["lower"]], tr$range[["upper"]]))
  }
  cat(sprintf("  ETa_24: %s\n", rng("eta_24")))
  cat(sprintf("  ETrF:   %s\n", rng("etrf")))
  sev <- vapply(x$flags, `[[`, "", "severity")
  cat(sprintf("  flags: %d records (%d critical, %d warning, %d info)\n",
              length(x$flags), sum(sev == "critical"), sum(sev == "warning"),
              sum(sev == "info")))
  if (!identical(p$preset$status, "VERIFICADA")) {
    cat(sprintf("  unverified elements of the preset: %s\n",
                paste(names(p$preset$unverified), collapse = ", ")))
  }
  cat("  layers: ", paste(names(x$layers), collapse = ", "), "\n", sep = "")
  invisible(x)
}

#' Summary of an earthflux_result
#'
#' One row per layer of the result: unit, number of valid cells, minimum,
#' quartiles and maximum; and the flag records of the run by code.
#'
#' @param object An `earthflux_result` (see [earthflux()]).
#' @param ... Ignored.
#' @return An object of class `summary.earthflux_result`: a list with
#'   `layers` (data frame), `flags` (data frame `code`, `stage`,
#'   `severity`, `scope`, `target`, `n_flagged`), `preset` and `date`.
#' @export
#' @noRd
summary.earthflux_result <- function(object, ...) {
  nms <- names(object$layers)
  rows <- lapply(nms, function(nm) {
    v <- terra::values(object$layers[[nm]], mat = FALSE)
    v <- v[!is.na(v)]
    q <- if (length(v) > 0L) {
      stats::quantile(v, c(0, 0.25, 0.5, 0.75, 1), names = FALSE)
    } else {
      rep(NA_real_, 5L)
    }
    data.frame(layer = nm, unit = object$units[[nm]], n_valid = length(v),
               min = q[1L], q25 = q[2L], median = q[3L], q75 = q[4L],
               max = q[5L], stringsAsFactors = FALSE)
  })
  layers <- do.call(rbind, rows)
  f <- object$flags
  flags <- data.frame(
    code = vapply(f, `[[`, "", "code"),
    stage = vapply(f, `[[`, "", "stage"),
    severity = vapply(f, `[[`, "", "severity"),
    scope = vapply(f, `[[`, "", "scope"),
    target = vapply(f, function(r) if (is.null(r$target)) NA_character_ else
      r$target, ""),
    n_flagged = vapply(f, function(r) as.integer(r$n_flagged), integer(1)),
    stringsAsFactors = FALSE
  )
  structure(
    list(layers = layers, flags = flags, preset = object$provenance$preset,
         date = object$date),
    class = "summary.earthflux_result"
  )
}

#' Print the summary of an earthflux_result
#'
#' @param x A `summary.earthflux_result`.
#' @param ... Passed to `print.data.frame()`.
#' @return `x`, invisibly.
#' @export
#' @noRd
print.summary.earthflux_result <- function(x, ...) {
  cat(sprintf("EarthFlux result of %s, preset %s (version %s, %s)\n\n",
              format(x$date), x$preset$name, x$preset$version,
              x$preset$status))
  cat("Layers:\n")
  print(x$layers, row.names = FALSE, digits = 4, ...)
  cat("\nFlags:\n")
  if (nrow(x$flags) == 0L) {
    cat("  none\n")
  } else {
    print(x$flags, row.names = FALSE, ...)
  }
  invisible(x)
}
