# Tests for the flag registry and flag records
#
# Specification: dev/specs/flags.md (tests R1-R19 in section 8). Tests that
# need a raster backend or a bit-word view (R12, R13, R16) and the list of
# retired codes (R14) are added with the code that introduces them.

reg <- ef_flag_registry()

# Class II codes (dev/specs/flags.md section 4.2): they need a threshold
# with a documented reference and must not be registered (section 7, point 7;
# test R10). The change that registers one of them removes it from here.
class_ii_guard <- c(
  "EF_SURF_LST_ERROR", "EF_SURF_EMIS_ERROR", "EF_SURF_VIEW_ANGLE_HIGH",
  "EF_SURF_COMPOSITE_LAG", "EF_SURF_AGG_INCOMPLETE",
  "EF_SURF_OVERPASS_OUTSIDE_WINDOW", "EF_SURF_LST_IMPLAUSIBLE",
  "EF_WS_IMPLAUSIBLE", "EF_WS_RH_RECALIBRATE", "EF_WS_RS_GT_RSO",
  "EF_WS_RS_CALIBRATION", "EF_WS_RS_NIGHT", "EF_WS_PERSISTENCE",
  "EF_WS_STEP", "EF_WS_RHMAX_LOW", "EF_WS_NONREFERENCE", "EF_WS_EA_DIURNAL",
  "EF_WS_TIME_SHIFT", "EF_WS_SPATIAL_OUTLIER", "EF_WS_CLOUDY_OVERPASS",
  "EF_GWR_FAR_FROM_STATIONS", "EF_GWR_ILL_CONDITIONED",
  "EF_GWR_FEW_STATIONS", "EF_GWR_ELEVATION_MISMATCH",
  "EF_RAD_SUN_LOW",
  "EF_G_NDVI_NONPOSITIVE", "EF_G_RATIO_IMPLAUSIBLE",
  "EF_ANCHOR_FEW_CANDIDATES", "EF_ANCHOR_CONTRAST_LOW",
  "EF_ANCHOR_COLD_PARTIAL_COVER", "EF_ANCHOR_HOT_RECENT_RAIN",
  "EF_H_WIND_LOW", "EF_H_STABILITY_STRONG",
  "EF_ET_ETRF_IMPLAUSIBLE", "EF_ET_PERIOD_GAP_LONG"
)

test_that("the registry has the documented columns and types", {
  expect_s3_class(reg, "data.frame")
  expect_named(reg, c("code", "stage", "severity", "scope", "bit",
                      "error_class", "description", "spec", "since"))
  expect_type(reg$bit, "integer")
  for (nm in setdiff(names(reg), "bit")) {
    expect_type(reg[[nm]], "character")
  }
  expect_true(all(c("EF_INPUT_NA", "EF_ET_NEGATIVE") %in% reg$code))
})

test_that("R1: codes are unique", {
  expect_identical(anyDuplicated(reg$code), 0L)
})

test_that("R2-R3: codes follow the closed pattern and match their stage", {
  pattern <- "^EF_(INPUT|SURF|WS|GWR|RAD|G|ANCHOR|H|ET)_[A-Z0-9]+(_[A-Z0-9]+)*$"
  expect_true(all(grepl(pattern, reg$code)))
  expect_true(all(nchar(reg$code) <= 40L))
  expect_true(all(startsWith(reg$code, paste0("EF_", reg$stage, "_"))))
})

test_that("R4: severities are valid and ordered info < warning < critical", {
  lv <- ef_flag_severity_levels()
  expect_identical(lv, c(info = 1L, warning = 2L, critical = 3L))
  expect_true(all(reg$severity %in% names(lv)))
})

test_that("R5: scopes are subsets of cell, record and object", {
  scopes <- ef_flag_scopes(reg$scope)
  expect_true(all(vapply(scopes, function(s) {
    all(s %in% c("cell", "record", "object")) && anyDuplicated(s) == 0L
  }, logical(1))))
})

test_that("R6-R8: bits are present only for cell scope and do not overlap", {
  has_cell <- vapply(ef_flag_scopes(reg$scope), function(s) "cell" %in% s,
                     logical(1))
  expect_identical(is.na(reg$bit), !has_cell)
  expect_identical(reg$bit[reg$code == "EF_INPUT_NA"], 0L)
  others <- reg$bit[reg$code != "EF_INPUT_NA" & !is.na(reg$bit)]
  expect_true(all(others >= 1L & others <= 30L))
  key <- paste(reg$stage, reg$bit)[!is.na(reg$bit)]
  expect_identical(anyDuplicated(key), 0L)
  n_cell <- table(reg$stage[has_cell])
  expect_true(all(n_cell + 1L <= 31L))
})

test_that("R9: critical codes declare an error counterpart or object scope", {
  crit <- reg$severity == "critical"
  object <- grepl("object", reg$scope, fixed = TRUE)
  expect_true(all(!crit | !is.na(reg$error_class) | object))
})

test_that("R10: class II codes are not registered", {
  expect_length(class_ii_guard, 35L)
  expect_identical(intersect(reg$code, class_ii_guard), character(0))
})

test_that("R11: every registered code is exercised by a module test", {
  # Temporary exception (dev/specs/flags.md section 8, R11): codes
  # registered in M0, before the policy, until their functions exist.
  exempt <- c("EF_INPUT_NA", "EF_ET_NEGATIVE")
  files <- list.files(test_path(), pattern = "^test-.*\\.R$",
                      full.names = TRUE)
  files <- files[basename(files) != "test-diagnostics.R"]
  text <- paste(unlist(lapply(files, readLines, warn = FALSE)),
                collapse = "\n")
  used <- vapply(reg$code, grepl, logical(1), x = text, fixed = TRUE)
  expect_identical(
    reg$code[!used & !reg$code %in% exempt],
    character(0)
  )
})

test_that("R15: no code coincides with an object of the package", {
  objects <- ls(asNamespace("EarthFlux"), all.names = TRUE)
  expect_identical(intersect(reg$code, objects), character(0))
})

test_that("R17: descriptions are one sentence ending with a period", {
  expect_true(all(nzchar(reg$description)))
  expect_true(all(grepl("\\.$", reg$description)))
  expect_true(all(nzchar(reg$spec) & nzchar(reg$since)))
})

test_that("every stage function returns registry rows", {
  stage_fns <- list(ef_flags_core, ef_flags_radiation, ef_flags_soil_heat,
                    ef_flags_anchors, ef_flags_sensible_heat, ef_flags_et)
  for (fn in stage_fns) {
    rows <- fn()
    expect_identical(names(rows), names(reg))
    expect_type(rows$bit, "integer")
  }
  template <- ef_flag_rows()
  expect_identical(nrow(template), 0L)
  expect_identical(names(template), names(reg))
})

valid_row <- list(
  code = "EF_RAD_TEST_CONDITION", stage = "RAD", severity = "warning",
  scope = "cell", bit = 5L, error_class = NA_character_,
  description = "A test condition holds.", spec = "dev/specs/flags.md 4.2",
  since = "0.0.0.9000"
)
row_with <- function(...) do.call(ef_flag_rows,
                                  utils::modifyList(valid_row, list(...)))

test_that("ef_flag_rows() builds valid rows", {
  rows <- row_with()
  expect_identical(nrow(rows), 1L)
  expect_identical(rows$bit, 5L)
  object_row <- row_with(scope = "object", bit = NA, severity = "critical")
  expect_identical(object_row$bit, NA_integer_)
  multi <- row_with(scope = "cell,record")
  expect_identical(ef_flag_scopes(multi$scope), list(c("cell", "record")))
})

test_that("ef_flag_rows() rejects malformed rows", {
  err <- "earthflux_registry_error"
  expect_error(row_with(code = "EF_RAD_lower"), class = err)
  expect_error(row_with(code = "EF_XYZ_TEST"), class = err)
  expect_error(row_with(code = paste0("EF_RAD_", strrep("A", 40))),
               class = err)
  expect_error(row_with(stage = "G"), class = err)
  expect_error(row_with(severity = "error"), class = err)
  expect_error(row_with(scope = "pixel"), class = err)
  expect_error(row_with(scope = "cell, record"), class = err)
  expect_error(row_with(bit = NA), class = err)
  expect_error(row_with(scope = "object"), class = err)
  expect_error(row_with(bit = 0L), class = err)
  expect_error(row_with(bit = 31L), class = err)
  expect_error(row_with(bit = 1.5), class = err)
  expect_error(row_with(severity = "critical"), class = err)
  expect_error(row_with(error_class = "SomeError"), class = err)
  expect_error(row_with(description = "No final period"), class = err)
  expect_error(row_with(spec = ""), class = err)
  expect_error(row_with(code = c("EF_RAD_A", "EF_RAD_B")), class = err)
  expect_silent(row_with(severity = "critical",
                         error_class = "earthflux_domain_error"))
})

test_that("ef_flag() records flagged positions without altering values", {
  eta <- c(1.2, -0.3, 0, 4.5, -0.01)
  flag <- ef_flag(eta < 0, "EF_ET_NEGATIVE")

  expect_s3_class(flag, "earthflux_flag")
  expect_named(flag, c("code", "stage", "severity", "scope", "description",
                       "index", "n_flagged", "n_total"))
  expect_identical(flag$code, "EF_ET_NEGATIVE")
  expect_identical(flag$stage, "ET")
  expect_identical(flag$severity, "warning")
  expect_identical(flag$scope, "cell")
  expect_identical(flag$index, c(2L, 5L))
  expect_identical(flag$n_flagged, 2L)
  expect_identical(flag$n_total, 5L)
  # Values are reported, never corrected: the input vector is untouched.
  expect_identical(eta, c(1.2, -0.3, 0, 4.5, -0.01))
})

test_that("ef_flag() handles empty and all-false masks", {
  none <- ef_flag(c(FALSE, FALSE), "EF_INPUT_NA", scope = "cell")
  expect_identical(none$index, integer(0))
  expect_identical(none$n_flagged, 0L)

  empty <- ef_flag(logical(0), "EF_INPUT_NA", scope = "record")
  expect_identical(empty$n_total, 0L)
  expect_identical(empty$scope, "record")
})

test_that("ef_flag() requires an explicit scope when several are registered", {
  expect_error(ef_flag(TRUE, "EF_INPUT_NA"), class = "earthflux_input_error")
  expect_error(ef_flag(TRUE, "EF_INPUT_NA", scope = "object"),
               class = "earthflux_input_error")
  expect_error(ef_flag(TRUE, "EF_ET_NEGATIVE", scope = "record"),
               class = "earthflux_input_error")
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

test_that("check_flag_list() accepts only lists of flag records", {
  flag <- ef_flag(c(TRUE, FALSE), "EF_ET_NEGATIVE")
  expect_invisible(check_flag_list(list()))
  expect_invisible(check_flag_list(list(flag, flag)))
  expect_error(check_flag_list(flag), class = "earthflux_input_error")
  expect_error(check_flag_list(list(flag, "x")),
               class = "earthflux_input_error")
  expect_error(check_flag_list(NULL), class = "earthflux_input_error")
})
