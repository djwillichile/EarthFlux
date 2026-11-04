# Preprocessing: MODIS -> standardised surface state ------------------------------
#
# Purpose: convert MODIS products into sensor-independent physical variables
#   (LST [K], broadband albedo [-], NDVI [-], LAI [m2 m-2], broadband surface
#   emissivity [-]) on a common grid, with QA masks and provenance.
#
# Architectural rule: functions in metric-*.R never receive MODIS-specific
#   objects. This module is the only place that knows about MODIS scale
#   factors, fill values, QA bit fields and view times.
#
# TODO(M1): document scale factors, fill values and QA bits per product from
#   the official user guides (no values entered from memory).
# TODO(M4): implement.
