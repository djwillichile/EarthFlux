test_that("ef_abort() signals classed errors", {
  expect_error(ef_abort("boom"), class = "earthflux_error")
  expect_error(
    ef_abort("boom", class = "earthflux_input_error"),
    class = "earthflux_input_error"
  )
  cnd <- tryCatch(ef_abort("boom", class = "x_error"), error = identity)
  expect_identical(
    class(cnd),
    c("x_error", "earthflux_error", "error", "condition")
  )
  expect_identical(conditionMessage(cnd), "boom")
})

test_that("ef_warn() signals classed warnings", {
  expect_warning(ef_warn("careful"), class = "earthflux_warning")
  expect_warning(
    ef_warn("careful", class = "earthflux_range_warning"),
    class = "earthflux_range_warning"
  )
})

test_that("ef_abort() attaches optional data fields to the condition", {
  funnel <- c(valid = 100L, domain = 40L, selected = 0L)
  cnd <- tryCatch(
    ef_abort("no candidates", class = "earthflux_calibration_error",
             funnel = funnel, type = "hot"),
    error = identity
  )
  expect_s3_class(cnd, "earthflux_calibration_error")
  expect_s3_class(cnd, "earthflux_error")
  expect_identical(cnd$funnel, funnel)
  expect_identical(cnd$type, "hot")
  expect_identical(conditionMessage(cnd), "no candidates")
  expect_named(cnd, c("message", "call", "funnel", "type"))
})

test_that("ef_abort() keeps the class order and reports the caller", {
  f <- function() ef_abort("boom", class = "x_error", value = 1)
  cnd <- tryCatch(f(), error = identity)
  expect_identical(cnd$call, quote(f()))
  expect_identical(class(cnd), c("x_error", "earthflux_error", "error",
                                 "condition"))
  # Positional `class` still works.
  cnd2 <- tryCatch(ef_abort("boom", "y_error"), error = identity)
  expect_s3_class(cnd2, "y_error")
})

test_that("condition data fields must be uniquely named and not reserved", {
  expect_error(ef_abort("boom", NULL, 1), class = "earthflux_input_error")
  expect_error(ef_abort("boom", a = 1, a = 2), class = "earthflux_input_error")
  expect_error(ef_warn("careful", NULL, b = 1, b = 2),
               class = "earthflux_input_error")
  # `message` and `call` cannot reach `...` through ef_abort() (they match
  # its formals); the reserved names are checked by the condition builder.
  expect_error(
    ef_condition("boom", "error", call = NULL, fields = list(call = 1)),
    class = "earthflux_input_error"
  )
  expect_error(
    ef_condition("boom", "error", call = NULL, fields = list(message = "x")),
    class = "earthflux_input_error"
  )
})

test_that("ef_warn() attaches optional data fields to the warning", {
  cnd <- tryCatch(
    ef_warn("not converged", class = "earthflux_convergence_warning",
            iterations = 20L, delta = c(a = 0.03, b = 1e-4)),
    warning = identity
  )
  expect_s3_class(cnd, "earthflux_convergence_warning")
  expect_s3_class(cnd, "earthflux_warning")
  expect_identical(cnd$iterations, 20L)
  expect_identical(cnd$delta, c(a = 0.03, b = 1e-4))
  # The warning does not stop execution: the caller returns its result.
  g <- function() {
    ef_warn("not converged", class = "earthflux_convergence_warning")
    "result"
  }
  expect_warning(res <- g(), class = "earthflux_convergence_warning")
  expect_identical(res, "result")
})

test_that("check_method() requires an explicit, exact method", {
  f <- function(method) check_method(method, c("tasumi", "bastiaanssen"))
  expect_invisible(f("tasumi"))
  expect_error(f(), class = "earthflux_missing_input")
  expect_error(f(), class = "earthflux_input_error")
  expect_error(f(NULL), class = "earthflux_missing_input")
  expect_error(f("Tasumi"), class = "earthflux_unknown_method")
  expect_error(f("tas"), class = "earthflux_unknown_method")
  expect_error(f(c("tasumi", "tasumi")), class = "earthflux_input_error")
  expect_error(f(NA_character_), class = "earthflux_input_error")
  expect_error(f(1), class = "earthflux_input_error")
  cnd <- tryCatch(f("x"), error = identity)
  expect_s3_class(cnd, "earthflux_input_error")
  expect_identical(cnd$call, quote(f("x")))
  expect_identical(cnd$method, "x")
  expect_identical(cnd$choices, c("tasumi", "bastiaanssen"))
  expect_match(conditionMessage(cnd), "\"tasumi\", \"bastiaanssen\"")
})

test_that("check_string() accepts one non-empty string only", {
  expect_invisible(check_string("EF_ET_NEGATIVE"))
  expect_error(check_string(NA_character_), class = "earthflux_input_error")
  expect_error(check_string(""), class = "earthflux_input_error")
  expect_error(check_string(c("a", "b")), class = "earthflux_input_error")
  expect_error(check_string(1), class = "earthflux_input_error")
})

test_that("check_logical_no_na() rejects non-logical input and NA", {
  expect_invisible(check_logical_no_na(c(TRUE, FALSE)))
  expect_invisible(check_logical_no_na(logical(0)))
  expect_error(check_logical_no_na(c(1, 0)), class = "earthflux_input_error")
  expect_error(check_logical_no_na(c(TRUE, NA)), "missing values")
})

test_that("check_numeric() accepts double and integer only", {
  expect_invisible(check_numeric(1.5))
  expect_invisible(check_numeric(1:3))
  expect_invisible(check_numeric(matrix(1, 2, 2)))
  expect_invisible(check_numeric(NA_real_))
  expect_error(check_numeric("1"), class = "earthflux_input_error")
  expect_error(check_numeric(TRUE), class = "earthflux_input_error")
  expect_error(check_numeric(NA), class = "earthflux_input_error")
  expect_error(check_numeric(factor(1)), class = "earthflux_input_error")
  expect_error(check_numeric(1i), class = "earthflux_input_error")
  expect_error(check_numeric("a", arg = "albedo"), "`albedo` must be numeric")
})

test_that("check_numeric() reports the caller's call", {
  f <- function(x) check_numeric(x, "x")
  cnd <- tryCatch(f("a"), error = identity)
  expect_identical(cnd$call, quote(f("a")))
})

test_that("check_common_length() returns n and enforces the recycling rule", {
  expect_identical(check_common_length(list(a = 1, b = 1:3, c = 2)), 3L)
  expect_identical(check_common_length(list(a = 1, b = 2)), 1L)
  expect_invisible(check_common_length(list(a = 1:2, b = 3:4)))
  expect_error(
    check_common_length(list(a = 1:2, b = 1:3)),
    class = "earthflux_input_error"
  )
  expect_error(
    check_common_length(list(a = 1:2, b = 1:3, c = 1)),
    "`a` \\(2\\)"
  )
  expect_error(
    check_common_length(list(a = numeric(0), b = 1)),
    class = "earthflux_input_error"
  )
  expect_error(check_common_length(list(a = numeric(0))), "`a`")
})

test_that("check_same_dim() requires identical dims of full length", {
  m <- matrix(1, 2, 3)
  expect_invisible(check_same_dim(list(a = 1, b = 1:6), n = 6L))
  expect_invisible(check_same_dim(list(a = m, b = m, c = 1), n = 6L))
  expect_invisible(check_same_dim(list(a = m, b = 1:6), n = 6L))
  expect_error(
    check_same_dim(list(a = m, b = matrix(1, 3, 2)), n = 6L),
    class = "earthflux_input_error"
  )
  # A length-1 array is not recycled against longer arguments.
  expect_error(
    check_same_dim(list(a = matrix(1), b = 1:3), n = 3L),
    class = "earthflux_input_error"
  )
})

test_that("check_in_range() enforces closed and open bounds", {
  expect_invisible(check_in_range(c(0, 0.5, 1), "a", 0, 1))
  expect_error(check_in_range(1.1, "a", 0, 1), class = "earthflux_domain_error")
  expect_error(check_in_range(-0.1, "a", 0, 1), class = "earthflux_domain_error")
  expect_error(
    check_in_range(0, "a", 0, 1, lower_inclusive = FALSE),
    class = "earthflux_domain_error"
  )
  expect_error(
    check_in_range(1, "a", 0, 1, upper_inclusive = FALSE),
    class = "earthflux_domain_error"
  )
  expect_invisible(check_in_range(1e6, "a", lower = 0))
  expect_invisible(check_in_range(integer(0), "a", 0, 1))
})

test_that("check_in_range() ignores NA/NaN and rejects infinite values", {
  expect_invisible(check_in_range(c(NA, NaN, 0.5), "a", 0, 1))
  expect_error(check_in_range(Inf, "a"), class = "earthflux_domain_error")
  expect_error(check_in_range(c(1, -Inf, Inf), "a"), "2 infinite value")
})

test_that("check_in_range() errors are classed, counted and named", {
  cnd <- tryCatch(
    check_in_range(c(-1, 0.5, 2, NA, 3), "albedo", 0, 1),
    error = identity
  )
  expect_s3_class(cnd, "earthflux_domain_error")
  expect_s3_class(cnd, "earthflux_input_error")
  expect_s3_class(cnd, "earthflux_error")
  expect_match(conditionMessage(cnd), "`albedo` must lie in [0, 1]", fixed = TRUE)
  expect_match(conditionMessage(cnd), "found 3 value(s)", fixed = TRUE)

  cnd_open <- tryCatch(
    check_in_range(0, "emissivity", 0, 1, lower_inclusive = FALSE),
    error = identity
  )
  expect_match(conditionMessage(cnd_open), "(0, 1]", fixed = TRUE)

  cnd_inf <- tryCatch(
    check_in_range(-1, "rl_in", lower = 0, lower_inclusive = FALSE),
    error = identity
  )
  expect_match(conditionMessage(cnd_inf), "(0, Inf)", fixed = TRUE)
})
