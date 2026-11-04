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

#' Check that an argument is a numeric vector, matrix or array
#'
#' Accepts double and integer storage. Logical, character, complex and
#' classed non-numeric objects (e.g. factors, dates) are rejected so that
#' silent coercion never alters a physical input.
#'
#' @inheritParams check_string
#' @param call The call to report in the error. Defaults to the caller of
#'   `check_numeric()`.
#' @return `x`, invisibly, if the check passes.
#' @noRd
check_numeric <- function(x, arg = deparse(substitute(x)), call = sys.call(-1)) {
  if (!is.numeric(x)) {
    ef_abort(
      sprintf("`%s` must be numeric, not %s.", arg, class(x)[1L]),
      class = "earthflux_input_error",
      call = call
    )
  }
  invisible(x)
}

#' Check that arguments have length 1 or a common length
#'
#' Encodes the recycling rule of the vectorised physics core: every argument
#' must have either length 1 or the same length `n` (the largest length
#' among the arguments). Zero-length arguments are rejected, so `n >= 1`.
#'
#' @param args A named list of the arguments to check. Names are used in
#'   the error message.
#' @param call The call to report in the error. Defaults to the caller of
#'   `check_common_length()`.
#' @return The common length `n` (an integer), invisibly, if the check
#'   passes.
#' @noRd
check_common_length <- function(args, call = sys.call(-1)) {
  lens <- lengths(args, use.names = TRUE)
  empty <- names(lens)[lens == 0L]
  if (length(empty) > 0L) {
    ef_abort(
      sprintf(
        "Arguments must not be empty; zero-length argument(s): %s.",
        paste0("`", empty, "`", collapse = ", ")
      ),
      class = "earthflux_input_error",
      call = call
    )
  }
  n <- max(lens)
  bad <- lens != 1L & lens != n
  if (any(bad)) {
    ef_abort(
      sprintf(
        paste0(
          "Arguments must have length 1 or a common length (%d); ",
          "incompatible length(s): %s."
        ),
        n,
        paste0("`", names(lens)[bad], "` (", lens[bad], ")", collapse = ", ")
      ),
      class = "earthflux_input_error",
      call = call
    )
  }
  invisible(as.integer(n))
}

#' Check that matrix or array arguments share the same dimensions
#'
#' Arguments without a `dim` attribute are ignored. Arguments that carry a
#' `dim` attribute are not recycled: they must all have the same `dim` and
#' their length must equal the common length of the call. This prevents
#' base R from raising unclassed "non-conformable arrays" errors or
#' deprecation warnings when arrays are mixed.
#'
#' @inheritParams check_common_length
#' @param n Integer. The common length of the call, as returned by
#'   `check_common_length()`.
#' @return `TRUE`, invisibly, if the check passes.
#' @noRd
check_same_dim <- function(args, n, call = sys.call(-1)) {
  dims <- lapply(args, dim)
  has_dim <- !vapply(dims, is.null, logical(1))
  if (!any(has_dim)) {
    return(invisible(TRUE))
  }
  ref <- dims[has_dim][[1L]]
  same <- vapply(dims[has_dim], identical, logical(1), y = ref)
  if (!all(same) || prod(ref) != n) {
    ef_abort(
      sprintf(
        paste0(
          "Matrix or array arguments must share the same `dim` and have the ",
          "common length (%d); check: %s."
        ),
        n,
        paste0("`", names(args)[has_dim], "`", collapse = ", ")
      ),
      class = "earthflux_input_error",
      call = call
    )
  }
  invisible(TRUE)
}

#' Check that the values of a numeric argument lie in an interval
#'
#' Missing values (`NA`, `NaN`) are ignored: they propagate through the
#' computation and are flagged by the orchestration layer, not here.
#' Infinite values are always rejected, whatever the bounds. Violations
#' raise an error of class
#' `c("earthflux_domain_error", "earthflux_input_error")` that names the
#' argument and the number of offending values. Values are never corrected.
#'
#' @inheritParams check_string
#' @param lower,upper Numeric scalars. Bounds of the interval; use `-Inf`
#'   or `Inf` for an unbounded side.
#' @param lower_inclusive,upper_inclusive Logical scalars. Whether the
#'   corresponding bound belongs to the interval. Ignored for infinite
#'   bounds.
#' @param call The call to report in the error. Defaults to the caller of
#'   `check_in_range()`.
#' @return `x`, invisibly, if the check passes.
#' @noRd
check_in_range <- function(x, arg = deparse(substitute(x)),
                           lower = -Inf, upper = Inf,
                           lower_inclusive = TRUE, upper_inclusive = TRUE,
                           call = sys.call(-1)) {
  domain_class <- c("earthflux_domain_error", "earthflux_input_error")
  ok <- !is.na(x)
  vals <- x[ok]

  n_inf <- sum(is.infinite(vals))
  if (n_inf > 0L) {
    ef_abort(
      sprintf(
        "`%s` must be finite; found %d infinite value(s).",
        arg, n_inf
      ),
      class = domain_class,
      call = call
    )
  }

  below <- if (lower_inclusive) vals < lower else vals <= lower
  above <- if (upper_inclusive) vals > upper else vals >= upper
  n_bad <- sum(below | above)
  if (n_bad > 0L) {
    interval <- sprintf(
      "%s%s, %s%s",
      if (lower_inclusive && is.finite(lower)) "[" else "(",
      format(lower),
      format(upper),
      if (upper_inclusive && is.finite(upper)) "]" else ")"
    )
    ef_abort(
      sprintf(
        "`%s` must lie in %s; found %d value(s) outside this interval.",
        arg, interval, n_bad
      ),
      class = domain_class,
      call = call
    )
  }
  invisible(x)
}
