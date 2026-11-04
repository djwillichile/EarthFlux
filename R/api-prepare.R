# High-level API: input preparation --------------------------------------------
#
# Purpose: assemble validated, unit-consistent inputs for a run:
#   - surface state (from a sensor module such as prep-modis.R);
#   - spatial meteorological forcing (from gwr-*.R or an alternative method);
#   - area of interest and target date/overpass time.
#
# TODO(M5): define the "prepared inputs" contract (variables, units, grid,
#   CRS, provenance) after the data contracts in dev/ARCHITECTURE.md are
#   finalised in M1.
