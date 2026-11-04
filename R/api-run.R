# High-level API: execution of the METRIC chain --------------------------------
#
# Purpose: run the modular METRIC chain on prepared inputs, in order:
#   Rn -> G -> anchors -> rah/dT iteration -> H -> LE -> ETinst -> ETrF -> ETa
# keeping each intermediate product and its diagnostics.
#
# TODO(M5): implement only as a thin orchestration layer over metric-*.R.
# TODO(M1): specify the stability correction iteration (convergence criterion,
#   maximum iterations, behaviour on non-convergence) before implementation.
