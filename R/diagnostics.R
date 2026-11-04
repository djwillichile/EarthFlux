# Diagnostics and quality flags ------------------------------------------------
#
# Purpose: minimal infrastructure so that every EarthFlux result can carry
# diagnostics instead of silently modified values.
#
# Principle (dev/ARCHITECTURE.md): physically anomalous values are reported,
# never silently corrected. For example, ETa = -0.3 is kept and flagged with
# `EF_ET_NEGATIVE`; it is not replaced by 0.
#
# Scope in M0 (deliberately small):
# - an internal registry of flag codes with severity and description;
# - a constructor that turns a logical mask into a flag record.
#
# Out of scope until specified in M1 (dev/SCIENTIFIC_SPEC.md):
# - thresholds that require scientific justification (e.g. tolerated energy
#   balance residuals, plausible ETrF ranges);
# - an S3 result class aggregating flags (see R/classes.R);
# - print/summary methods for flags (see R/print.R).

#' Registry of EarthFlux diagnostic flag codes
#'
#' Only codes whose triggering condition is unambiguous are registered. Codes
#' that depend on thresholds still under scientific review are added once the
#' threshold is documented in `dev/SCIENTIFIC_SPEC.md`.
#'
#' @return A data frame with columns `code`, `severity` (`"info"`,
#'   `"warning"`) and `description`.
#' @noRd
ef_flag_registry <- function() {
  data.frame(
    code = c(
      "EF_INPUT_NA",
      "EF_ET_NEGATIVE"
    ),
    severity = c(
      "info",
      "warning"
    ),
    description = c(
      "A required input value is missing; the output is NA at this location.",
      "Estimated evapotranspiration is negative; the value is reported unchanged."
    ),
    stringsAsFactors = FALSE
  )
}

#' Create a diagnostic flag record from a logical mask
#'
#' @param mask Logical vector without `NA`. `TRUE` marks the elements
#'   (pixels, stations, time steps) for which the condition holds.
#' @param code Character. A code registered in `ef_flag_registry()`.
#' @return A list of class `earthflux_flag` with elements `code`, `severity`,
#'   `description`, `index` (integer positions where `mask` is `TRUE`),
#'   `n_flagged` and `n_total`.
#' @noRd
ef_flag <- function(mask, code) {
  check_logical_no_na(mask)
  check_string(code)

  registry <- ef_flag_registry()
  row <- match(code, registry$code)
  if (is.na(row)) {
    ef_abort(
      sprintf("Unknown diagnostic flag code: '%s'.", code),
      class = "earthflux_unknown_flag"
    )
  }

  index <- which(mask)
  structure(
    list(
      code = code,
      severity = registry$severity[row],
      description = registry$description[row],
      index = index,
      n_flagged = length(index),
      n_total = length(mask)
    ),
    class = "earthflux_flag"
  )
}
