# Placeholder: GWR spatial forcing
#
# Status: no implementation exists yet (M3). This file documents the
# planned test cases; each must become a real expectation when the
# corresponding function is implemented. Do not replace with trivial tests.
#
# Planned test cases:
# - with a constant true relationship and a very large bandwidth, GWR approaches the global OLS fit
# - AICc bandwidth selection reproduces an independently computed reference case
# - fitted object keeps kernel, bandwidth, criterion profile, residuals and diagnostics
# - prediction outside the station support is flagged
# - LOOCV / spatial CV errors are computed on held-out stations only

test_that("GWR spatial forcing: tests pending implementation", {
  skip("Pending M3: see header for planned test cases.")
})
