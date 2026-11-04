# METRIC: sensible heat flux (H) ----------------------------------------------------
#
# Purpose: sensible heat flux H = rho_air * cp * dT / rah, computed from the
#   outputs of metric-dt.R and metric-aerodynamics.R. Anchor selection is NOT
#   performed here.
#
# TODO(M1): specify air density and cp computation, units and references.

# Diagnostic flags of this stage -------------------------------------------------

#' Flag codes owned by the sensible heat (z_om, u*, rah, stability, dT and H) stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_H_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_sensible_heat <- function() {
  ef_flag_rows()
}
