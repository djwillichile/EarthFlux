# I/O: MODIS products -------------------------------------------------------------
#
# Purpose: locate and read MODIS products (local files first). Downloading
#   from NASA Earthdata, if ever supported, must be optional, never required
#   in tests or examples, and must never store credentials in the repository.
#
# TODO(M1): define the product list and collection (see dev/SCIENTIFIC_SPEC.md,
#   section "Productos MODIS candidatos").
# TODO(M4): implement readers for small local files.
