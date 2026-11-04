# Spatial forcing: GWR bandwidth selection --------------------------------------
#
# Purpose: bandwidth selection (fixed or adaptive) by a documented criterion
#   (AICc or cross-validation), keeping the full criterion profile so that the
#   selection is auditable.
#
# TODO(M1): specify kernels, criteria and their references (Hurvich et al.,
#   1998 for AICc; Fotheringham et al., 2002) - see dev/REFERENCES.md.
# TODO(M3): implement and test against a published or independently computed
#   reference case.
