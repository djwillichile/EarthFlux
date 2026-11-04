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
