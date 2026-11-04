# Placeholder: net radiation
#
# Status: no implementation exists yet (M2). This file documents the
# planned test cases; each must become a real expectation when the
# corresponding function is implemented. Do not replace with trivial tests.
#
# Planned test cases:
# - hand-computed Rn from a verified reference example (tolerance justified by floating point)
# - Rn equals (1 - albedo) * Rs_in when longwave terms cancel
# - NA in any input propagates to NA output and is flagged EF_INPUT_NA
# - albedo or emissivity outside [0, 1] raises a classed error
# - vectorised inputs of unequal length raise a classed error

test_that("net radiation: tests pending implementation", {
  skip("Pending M2: see header for planned test cases.")
})
