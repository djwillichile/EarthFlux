# Tests for the lightweight object constructor (R/classes.R)

flag <- ef_flag(TRUE, "EF_ET_NEGATIVE")

test_that("new_ef_object() builds a classed list with flags", {
  obj <- new_ef_object(
    list(value = 1, method = "manual", flags = list(flag)),
    class = "earthflux_test_object"
  )
  expect_s3_class(obj, "earthflux_test_object")
  expect_identical(class(obj), c("earthflux_test_object", "list"))
  expect_identical(obj$value, 1)
  expect_length(obj$flags, 1L)

  empty <- new_ef_object(list(flags = list()), class = "earthflux_test_object")
  expect_identical(empty$flags, list())
})

test_that("new_ef_object() requires a flags element of flag records", {
  expect_error(new_ef_object(list(value = 1), "earthflux_x"),
               class = "earthflux_input_error")
  expect_error(new_ef_object(list(flags = "none"), "earthflux_x"),
               class = "earthflux_input_error")
  expect_error(new_ef_object(list(flags = list(1)), "earthflux_x"),
               class = "earthflux_input_error")
})

test_that("new_ef_object() validates names and class", {
  expect_error(new_ef_object(list(1, flags = list()), "earthflux_x"),
               class = "earthflux_input_error")
  expect_error(new_ef_object(list(a = 1, a = 2, flags = list()),
                             "earthflux_x"),
               class = "earthflux_input_error")
  expect_error(new_ef_object(c(flags = 1), "earthflux_x"),
               class = "earthflux_input_error")
  expect_error(new_ef_object(list(flags = list()), "anchors"),
               class = "earthflux_input_error")
  expect_error(new_ef_object(list(flags = list()), character(0)),
               class = "earthflux_input_error")
  obj <- new_ef_object(list(flags = list()), "earthflux_x")
  expect_error(new_ef_object(obj, "earthflux_y"),
               class = "earthflux_input_error")
})
