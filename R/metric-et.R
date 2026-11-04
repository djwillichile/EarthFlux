# METRIC: instantaneous ET, ETrF and daily ETa -----------------------------------
#
# Purpose: conversion of LE to instantaneous ET, reference ET fraction
#   (ETrF = ETinst / ETr_inst) and extrapolation to daily ETa
#   (ETa = ETrF * ETr_24), with explicit reference-crop definition.
#
# TODO(M1): specify latent heat of vaporisation, reference ET method
#   (e.g. ASCE-EWRI standardised alfalfa reference) and the assumption of
#   constant ETrF during the day, with references.

# Diagnostic flags of this stage -------------------------------------------------

#' Flag codes owned by the latent heat and evapotranspiration stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_ET_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_et <- function() {
  ef_flag_rows(
    code = "EF_ET_NEGATIVE",
    stage = "ET",
    severity = "warning",
    scope = "cell",
    bit = 1L,
    error_class = NA_character_,
    description = paste(
      "Estimated evapotranspiration is negative;",
      "the value is reported unchanged."
    ),
    spec = "dev/specs/evapotranspiration.md 7.1",
    since = "0.0.0.9000"
  )
}
