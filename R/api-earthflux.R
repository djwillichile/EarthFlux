# High-level API: earthflux() --------------------------------------------------
#
# Purpose: single entry point for the complete workflow
#   surface state + weather stations -> spatial forcing (GWR) -> METRIC -> ETa
#
# Planned interface (not implemented; see dev/ARCHITECTURE.md, section "API"):
#   result <- earthflux(modis = modis, weather = stations, aoi = aoi, date = date)
#
# Rules:
# - Must NOT duplicate scientific code: it only orchestrates api-prepare.R and
#   api-run.R, which call the same low-level ef_*() functions available to
#   advanced users.
# - Must return every intermediate component (Rn, G, anchors, rah, dT, H, LE,
#   ETinst, ETrF, ETa), diagnostics and provenance.
#
# TODO(M5): implement after M2 (METRIC core), M3 (GWR) and M4 (MODIS) exist.
