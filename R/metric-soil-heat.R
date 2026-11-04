# METRIC: soil heat flux (G) ---------------------------------------------------------
#
# Purpose: soil heat flux from net radiation and surface variables using a
#   documented empirical method, with the method name stored in the result.
#
# TODO(M1): verify candidate formulations (e.g. Bastiaanssen, 2000; Tasumi,
#   2003) and their domain of validity before implementation.

# Diagnostic flags of this stage -------------------------------------------------

#' Flag codes owned by the soil heat flux (G) stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_G_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_soil_heat <- function() {
  ef_flag_rows()
}
