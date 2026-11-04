# Diagnostics and quality flags ------------------------------------------------
#
# Purpose: infrastructure so that every EarthFlux result can carry
# diagnostics instead of silently modified values.
#
# Principle (dev/ARCHITECTURE.md): physically anomalous values are reported,
# never silently corrected. For example, ETa = -0.3 is kept and flagged with
# `EF_ET_NEGATIVE`; it is not replaced by 0.
#
# Specification: dev/specs/flags.md (catalogue section 4, severities
# section 5, representation section 6, registration policy section 7, tests
# section 8).
#
# Registry mechanism (one owner per stage, to avoid merge conflicts when the
# METRIC stages are developed in parallel):
#
#   ef_flag_registry()            rbinds the rows of every stage and checks
#                                 cross-row consistency (unique codes, bits)
#     ef_flags_core()             here: transversal codes (EF_INPUT_*)
#     ef_flags_radiation()        R/metric-radiation.R     (EF_RAD_*)
#     ef_flags_soil_heat()        R/metric-soil-heat.R     (EF_G_*)
#     ef_flags_anchors()          R/metric-anchors.R       (EF_ANCHOR_*)
#     ef_flags_sensible_heat()    R/metric-sensible-heat.R (EF_H_*)
#     ef_flags_et()               R/metric-et.R            (EF_ET_*)
#
#   Stages of other modules (EF_SURF_*, EF_WS_*, EF_GWR_*) add their own
#   ef_flags_<stage>() in their module file when their first code is
#   registered, and list it in ef_flag_registry().
#
#   Every stage function returns ef_flag_rows(...): a zero-row data frame
#   until the stage registers its first code. A code is registered only in
#   the same change that adds the function raising it, its tests and its
#   NEWS entry (dev/specs/flags.md section 7). Codes that need a threshold
#   without a documented reference (class II) are never registered: they
#   are listed in the guard vector of tests/testthat/test-diagnostics.R.
#
# Ownership of flag construction: cell-scope flags of a stage are built by an
# internal ef_diagnose_<stage>() function (dev/ARCHITECTURE.md section 3.2),
# never by the numeric function that computes the quantity.

#' Severity levels of diagnostic flags
#'
#' Ordered `info` < `warning` < `critical`, with numeric codes 1, 2, 3 used
#' by severity summaries (dev/specs/flags.md section 5.3; `critical` adopted
#' provisionally with decisions FL-05 and FL-06).
#'
#' @return A named integer vector.
#' @noRd
ef_flag_severity_levels <- function() {
  c(info = 1L, warning = 2L, critical = 3L)
}

#' Stages (code prefixes) of diagnostic flags
#'
#' Closed list of dev/specs/flags.md section 3.1. The prefix of a code
#' (`EF_<STAGE>_`) identifies the stage that evaluates the condition.
#'
#' @return A character vector.
#' @noRd
ef_flag_stages <- function() {
  c("INPUT", "SURF", "WS", "GWR", "RAD", "G", "ANCHOR", "H", "ET")
}

#' Scopes of diagnostic flags
#'
#' `cell`: position of a vector or cell of a raster; `record`: row of a
#' table; `object`: scene, fit, anchor set or run (dev/specs/flags.md
#' section 6.1).
#'
#' @return A character vector.
#' @noRd
ef_flag_scope_values <- function() {
  c("cell", "record", "object")
}

#' Split the scope column of the registry
#'
#' @param scope Character vector of registry scopes, each a comma-separated
#'   list without spaces (e.g. `"cell,record"`).
#' @return A list of character vectors, one per element of `scope`.
#' @noRd
ef_flag_scopes <- function(scope) {
  strsplit(scope, ",", fixed = TRUE)
}

#' Construct rows of the flag registry
#'
#' Constructor used by every `ef_flags_<stage>()` function so that all stages
#' add rows uniformly. Arguments are vectors with one element per code and
#' must all have the same length (no recycling: every row states every
#' column explicitly). Called without arguments it returns the zero-row
#' registry template. Each row is validated (dev/specs/flags.md section 8,
#' tests R2-R6, R9 and R17); cross-row checks (unique codes, distinct bits
#' within a stage) are done by `ef_flag_registry()`.
#'
#' @param code Character. Flag code, `EF_<STAGE>_<CONDITION>` in upper case,
#'   at most 40 characters, with a prefix from the closed list of stages.
#' @param stage Character. Stage that evaluates the condition; must match
#'   the prefix of `code` (e.g. `"RAD"` for `EF_RAD_RN_NEGATIVE`).
#' @param severity Character. `"info"`, `"warning"` or `"critical"`.
#' @param scope Character. One or more of `"cell"`, `"record"`, `"object"`,
#'   comma-separated without spaces (e.g. `"cell,record"`).
#' @param bit Integer. Bit in the flag word of the stage (0-30); `NA` if and
#'   only if `scope` does not include `"cell"`. Bit 0 is reserved for
#'   `EF_INPUT_NA`.
#' @param error_class Character. Error class of the core that is the
#'   counterpart of the condition (class III), or `NA`.
#' @param description Character. One English sentence ending with a period.
#' @param spec Character. Specification and section defining the code
#'   (e.g. `"dev/specs/flags.md 4.2"`).
#' @param since Character. Package version in which the code was registered.
#' @return A data frame with columns `code`, `stage`, `severity`, `scope`,
#'   `bit` (integer), `error_class`, `description`, `spec` and `since`.
#' @noRd
ef_flag_rows <- function(code = character(0), stage = character(0),
                         severity = character(0), scope = character(0),
                         bit = integer(0), error_class = character(0),
                         description = character(0), spec = character(0),
                         since = character(0)) {
  cols <- list(
    code = code, stage = stage, severity = severity, scope = scope,
    bit = bit, error_class = error_class, description = description,
    spec = spec, since = since
  )
  n <- length(code)
  lens <- lengths(cols)
  if (any(lens != n)) {
    registry_abort(sprintf(
      "All columns must have one element per code (%d); check: %s.",
      n, paste0("`", names(lens)[lens != n], "`", collapse = ", ")
    ))
  }

  chr_cols <- setdiff(names(cols), "bit")
  for (nm in chr_cols) {
    x <- cols[[nm]]
    if (!(is.character(x) || (is.logical(x) && all(is.na(x))))) {
      registry_abort(sprintf("`%s` must be character.", nm))
    }
    cols[[nm]] <- as.character(x)
  }
  if (!(is.numeric(bit) || (is.logical(bit) && all(is.na(bit)))) ||
      any(!is.na(bit) & bit != round(bit))) {
    registry_abort("`bit` must contain whole numbers or NA.")
  }
  cols$bit <- as.integer(bit)

  out <- as.data.frame(cols, stringsAsFactors = FALSE)
  rownames(out) <- NULL
  if (n == 0L) {
    return(out)
  }

  check_flag_rows(out)
  out
}

#' Validate rows of the flag registry
#'
#' @param reg A data frame as returned by `ef_flag_rows()`.
#' @return `reg`, invisibly, if every row is valid.
#' @noRd
check_flag_rows <- function(reg) {
  bad_rows <- function(ok, what) {
    if (any(!ok)) {
      registry_abort(sprintf(
        "%s; offending code(s): %s.",
        what, paste(reg$code[!ok], collapse = ", ")
      ))
    }
  }

  stages <- ef_flag_stages()
  pattern <- sprintf(
    "^EF_(%s)_[A-Z0-9]+(_[A-Z0-9]+)*$", paste(stages, collapse = "|")
  )
  required <- c("code", "stage", "severity", "scope", "description", "spec",
                "since")
  for (nm in required) {
    bad_rows(!is.na(reg[[nm]]) & nzchar(reg[[nm]]),
             sprintf("`%s` must not be missing or empty", nm))
  }
  bad_rows(
    grepl(pattern, reg$code) & nchar(reg$code) <= 40L,
    "Codes must match EF_<STAGE>_<CONDITION> with at most 40 characters"
  )
  bad_rows(reg$stage %in% stages, "Unknown `stage`")
  bad_rows(startsWith(reg$code, paste0("EF_", reg$stage, "_")),
           "The prefix of `code` must match `stage`")
  bad_rows(reg$severity %in% names(ef_flag_severity_levels()),
           "`severity` must be \"info\", \"warning\" or \"critical\"")

  scopes <- ef_flag_scopes(reg$scope)
  scope_ok <- vapply(scopes, function(s) {
    length(s) > 0L && all(s %in% ef_flag_scope_values()) &&
      anyDuplicated(s) == 0L
  }, logical(1))
  bad_rows(scope_ok,
           "`scope` must be a comma-separated subset of cell, record, object")

  has_cell <- vapply(scopes, function(s) "cell" %in% s, logical(1))
  bad_rows(is.na(reg$bit) == !has_cell,
           "`bit` must be NA if and only if `scope` does not include \"cell\"")
  is_input_na <- reg$code == "EF_INPUT_NA"
  bit_ok <- is.na(reg$bit) |
    (is_input_na & reg$bit == 0L) |
    (!is_input_na & reg$bit >= 1L & reg$bit <= 30L)
  bad_rows(bit_ok, "`bit` must be 0 for EF_INPUT_NA and in 1-30 otherwise")

  bad_rows(
    is.na(reg$error_class) | grepl("^earthflux_[a-z_]+$", reg$error_class),
    "`error_class` must be NA or an earthflux_* condition class"
  )
  bad_rows(reg$severity != "critical" | !is.na(reg$error_class) |
             vapply(scopes, function(s) "object" %in% s, logical(1)),
           "A critical code needs an `error_class` or the object scope")
  bad_rows(grepl("\\.$", reg$description),
           "`description` must be one sentence ending with a period")
  invisible(reg)
}

#' Signal a malformed flag registry
#'
#' @param message Character. Error message.
#' @return Never returns.
#' @noRd
registry_abort <- function(message) {
  ef_abort(message, class = "earthflux_registry_error", call = NULL)
}

#' Transversal flag codes
#'
#' Codes evaluated by the orchestration layer rather than by one stage.
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_core <- function() {
  ef_flag_rows(
    code = "EF_INPUT_NA",
    stage = "INPUT",
    severity = "info",
    scope = "cell,record",
    bit = 0L,
    error_class = NA_character_,
    description =
      "A required input value is missing; the output is NA at this location.",
    spec = "dev/specs/flags.md 4.2",
    since = "0.0.0.9000"
  )
}

#' Registry of EarthFlux diagnostic flag codes
#'
#' Binds the rows owned by each stage (see the header of this file) and
#' checks cross-row consistency: unique codes, and distinct bits within each
#' stage with bit 0 used only by `EF_INPUT_NA`.
#'
#' @return A data frame with columns `code`, `stage`, `severity` (`"info"`,
#'   `"warning"`, `"critical"`), `scope`, `bit`, `error_class`,
#'   `description`, `spec` and `since` (dev/specs/flags.md section 7).
#' @noRd
ef_flag_registry <- function() {
  reg <- rbind(
    ef_flags_core(),
    ef_flags_radiation(),
    ef_flags_soil_heat(),
    ef_flags_anchors(),
    ef_flags_sensible_heat(),
    ef_flags_et()
  )
  rownames(reg) <- NULL

  dup <- unique(reg$code[duplicated(reg$code)])
  if (length(dup) > 0L) {
    registry_abort(sprintf(
      "Flag codes must be unique; duplicated: %s.", paste(dup, collapse = ", ")
    ))
  }
  key <- paste(reg$stage, reg$bit)[!is.na(reg$bit)]
  clash <- unique(key[duplicated(key)])
  if (length(clash) > 0L) {
    registry_abort(sprintf(
      "Bits must be distinct within a stage; clash (stage bit): %s.",
      paste(clash, collapse = ", ")
    ))
  }
  reg
}

#' Check a list of diagnostic flag records
#'
#' @param flags Object to check: a list (possibly empty) whose elements are
#'   all of class `earthflux_flag`.
#' @inheritParams check_string
#' @param call The call to report. Defaults to the caller.
#' @return `flags`, invisibly, if the check passes.
#' @noRd
check_flag_list <- function(flags, arg = deparse(substitute(flags)),
                            call = sys.call(-1)) {
  ok <- is.list(flags) && !is.object(flags) &&
    all(vapply(flags, inherits, logical(1), what = "earthflux_flag"))
  if (!ok) {
    ef_abort(
      sprintf("`%s` must be a list of `earthflux_flag` records.", arg),
      class = "earthflux_input_error",
      call = call
    )
  }
  invisible(flags)
}

#' Create a diagnostic flag record from a logical mask
#'
#' @param mask Logical vector without `NA`. `TRUE` marks the elements
#'   (pixels, stations, time steps, table rows) for which the condition
#'   holds. Build it as `!is.na(x) & condition`. For the object scope it
#'   must have length 1.
#' @param code Character. A code registered in `ef_flag_registry()`.
#' @param scope Character or `NULL`. Scope of this record (`"cell"`,
#'   `"record"` or `"object"`), one of those registered for `code`. May be
#'   `NULL` when the code has a single registered scope.
#' @return A list of class `earthflux_flag` with elements `code`, `stage`,
#'   `severity`, `scope`, `description`, `index` (integer positions where
#'   `mask` is `TRUE`), `n_flagged` and `n_total`.
#' @noRd
ef_flag <- function(mask, code, scope = NULL) {
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

  allowed <- ef_flag_scopes(registry$scope[row])[[1L]]
  if (is.null(scope)) {
    if (length(allowed) != 1L) {
      ef_abort(
        sprintf(
          "Code '%s' has several scopes (%s); give `scope` explicitly.",
          code, paste(allowed, collapse = ", ")
        ),
        class = "earthflux_input_error"
      )
    }
    scope <- allowed
  }
  check_string(scope)
  if (!scope %in% allowed) {
    ef_abort(
      sprintf(
        "Scope '%s' is not registered for code '%s' (allowed: %s).",
        scope, code, paste(allowed, collapse = ", ")
      ),
      class = "earthflux_input_error"
    )
  }
  if (scope == "object" && length(mask) != 1L) {
    ef_abort(
      "An object-scope flag needs a mask of length 1.",
      class = "earthflux_input_error"
    )
  }

  index <- which(mask)
  structure(
    list(
      code = code,
      stage = registry$stage[row],
      severity = registry$severity[row],
      scope = scope,
      description = registry$description[row],
      index = index,
      n_flagged = length(index),
      n_total = length(mask)
    ),
    class = "earthflux_flag"
  )
}

#' Missing-input flag of a dispatcher
#'
#' Builds the transversal `EF_INPUT_NA` record (cell scope) for the
#' positions where any of the required inputs is missing (`NA` or `NaN`).
#' Shared by every dispatcher of the METRIC core (dev/ARCHITECTURE.md
#' section 3.2).
#'
#' @param inputs Named list of the required inputs (each of length 1 or
#'   `n`); `NULL` elements are ignored.
#' @param n Integer. Common length of the call.
#' @return A list with one `earthflux_flag` record, or an empty list.
#' @noRd
ef_input_na_flags <- function(inputs, n) {
  inputs <- inputs[!vapply(inputs, is.null, logical(1))]
  if (length(inputs) == 0L) {
    return(list())
  }
  mask <- Reduce(`|`, lapply(inputs, function(x) rep_len(is.na(x), n)))
  if (!any(mask)) {
    return(list())
  }
  list(ef_flag(as.vector(mask), "EF_INPUT_NA", scope = "cell"))
}
