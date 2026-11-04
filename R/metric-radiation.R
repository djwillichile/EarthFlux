# METRIC: radiation components and net radiation (Rn) ----------------------------
#
# Purpose: net radiation at the land surface and its components:
#   incoming shortwave (including direct/diffuse partition and terrain
#   correction for slope and aspect), incoming and outgoing longwave.
#
# First scientific function candidate: ef_net_radiation().
# It is NOT implemented until the checklist in dev/DEVELOPMENT.md
# ("Definition of Done for scientific functions") is complete, including:
#   - verified equation and reference;
#   - argument definitions and units;
#   - NA behaviour and domain of validity;
#   - a verifiable numerical case and designed tests.
#
# Note: the reflected incoming longwave term must be handled explicitly; see
#   dev/SCIENTIFIC_SPEC.md, section 3 (net radiation row).
