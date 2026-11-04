# Placeholder: MODIS preprocessing
#
# Status: no implementation exists yet (M4). This file documents the
# planned test cases; each must become a real expectation when the
# corresponding function is implemented. Do not replace with trivial tests.
#
# Planned test cases:
# - scale factors and fill values applied as documented in the product user guides
# - QA bits decoded correctly on a hand-built bit pattern
# - output variables carry documented units (LST in K, albedo dimensionless)
# - no MODIS-specific object leaks into metric-*.R inputs

test_that("MODIS preprocessing: tests pending implementation", {
  skip("Pending M4: see header for planned test cases.")
})
