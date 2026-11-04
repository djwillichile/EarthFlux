# METRIC: anchor (hot/cold) pixel selection --------------------------------------
#
# Purpose: auditable selection of the hot and cold anchor pixels used for the
#   internal calibration of dT. Kept separate from the sensible heat module.
#
# Each selection must record: pixel location, LST, NDVI, albedo, land cover,
#   selection criteria, percentiles used, QA flags and whether the selection
#   was automatic or user-supplied (manual/explicit selection must be possible).
#
# TODO(M1): document the selection rules from the METRIC literature (e.g.
#   Allen et al., 2007; Allen et al., 2013; Morton et al., 2013) and their
#   applicability at MODIS spatial resolution before implementation.

# Diagnostic flags of this stage -------------------------------------------------

#' Flag codes owned by the anchor pixel stage
#'
#' Rows of `ef_flag_registry()` for the codes with prefix `EF_ANCHOR_`
#' (dev/specs/flags.md section 4.2). A code is added here, with
#' `ef_flag_rows()`, only in the change that implements the function raising
#' it, its tests and its NEWS entry (dev/specs/flags.md section 7).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_anchors <- function() {
  ef_flag_rows()
}
