test_that("flag registry has unique codes and valid severities", {
  reg <- ef_flag_registry()
  expect_s3_class(reg, "data.frame")
  expect_named(reg, c("code", "severity", "description"))
  expect_false(anyDuplicated(reg$code) > 0)
  expect_true(all(reg$severity %in% c("info", "warning")))
  expect_true(all(grepl("^EF_[A-Z0-9_]+$", reg$code)))
})

test_that("ef_flag() records flagged positions without altering values", {
  eta <- c(1.2, -0.3, 0, 4.5, -0.01)
  flag <- ef_flag(eta < 0, "EF_ET_NEGATIVE")

  expect_s3_class(flag, "earthflux_flag")
  expect_identical(flag$code, "EF_ET_NEGATIVE")
  expect_identical(flag$severity, "warning")
  expect_identical(flag$index, c(2L, 5L))
  expect_identical(flag$n_flagged, 2L)
  expect_identical(flag$n_total, 5L)
  # Values are reported, never corrected: the input vector is untouched.
  expect_identical(eta, c(1.2, -0.3, 0, 4.5, -0.01))
})

test_that("ef_flag() handles empty and all-false masks", {
  none <- ef_flag(c(FALSE, FALSE), "EF_INPUT_NA")
  expect_identical(none$index, integer(0))
  expect_identical(none$n_flagged, 0L)

  empty <- ef_flag(logical(0), "EF_INPUT_NA")
  expect_identical(empty$n_total, 0L)
})

test_that("ef_flag() requires an explicit decision about NA", {
  eta <- c(1, NA, -2)
  expect_error(ef_flag(eta < 0, "EF_ET_NEGATIVE"), class = "earthflux_input_error")
  flag <- ef_flag(!is.na(eta) & eta < 0, "EF_ET_NEGATIVE")
  expect_identical(flag$index, 3L)
})

test_that("ef_flag() rejects unknown codes", {
  expect_error(ef_flag(TRUE, "EF_DOES_NOT_EXIST"), class = "earthflux_unknown_flag")
})
