# Internal utilities -----------------------------------------------------------
#
# Purpose: small, dependency-free helpers shared across modules.
#
# Conventions:
# - All errors and warnings raised by EarthFlux carry a class so that tests
#   and downstream code can catch them precisely (e.g. `earthflux_error`,
#   `earthflux_input_error`).
# - Helpers here are internal and must not be exported.

#' Signal a classed EarthFlux error
#'
#' @param message Character. Error message.
#' @param class Character vector of additional condition classes, most
#'   specific first.
#' @param call The call to report. Defaults to the caller of `ef_abort()`.
#' @return Never returns; signals an error condition of class
#'   `c(class, "earthflux_error", "error", "condition")`.
#' @noRd
ef_abort <- function(message, class = NULL, call = sys.call(-1)) {
  cnd <- structure(
    class = c(class, "earthflux_error", "error", "condition"),
    list(message = message, call = call)
  )
  stop(cnd)
}

#' Signal a classed EarthFlux warning
#'
#' @inheritParams ef_abort
#' @return Invisibly `NULL`; signals a warning condition of class
#'   `c(class, "earthflux_warning", "warning", "condition")`.
#' @noRd
ef_warn <- function(message, class = NULL, call = sys.call(-1)) {
  cnd <- structure(
    class = c(class, "earthflux_warning", "warning", "condition"),
    list(message = message, call = call)
  )
  warning(cnd)
  invisible(NULL)
}

#' Check that an argument is a single non-missing string
#'
#' @param x Object to check.
#' @param arg Name of the argument, used in the error message.
#' @return `x`, invisibly, if the check passes.
#' @noRd
check_string <- function(x, arg = deparse(substitute(x))) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    ef_abort(
      sprintf("`%s` must be a single non-empty string.", arg),
      class = "earthflux_input_error"
    )
  }
  invisible(x)
}

#' Check that an argument is a logical vector without missing values
#'
#' Missing values are rejected on purpose: deciding how an `NA` should be
#' interpreted (flagged or not) is a scientific decision that must be made
#' explicitly by the caller.
#'
#' @inheritParams check_string
#' @return `x`, invisibly, if the check passes.
#' @noRd
check_logical_no_na <- function(x, arg = deparse(substitute(x))) {
  if (!is.logical(x)) {
    ef_abort(
      sprintf("`%s` must be a logical vector, not %s.", arg, class(x)[1L]),
      class = "earthflux_input_error"
    )
  }
  if (anyNA(x)) {
    ef_abort(
      sprintf(
        "`%s` contains missing values; resolve them explicitly before flagging.",
        arg
      ),
      class = "earthflux_input_error"
    )
  }
  invisible(x)
}
