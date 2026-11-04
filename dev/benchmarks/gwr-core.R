# Benchmark of the internal GWR core (dev/specs/gwr-forcing.md sections 6.4
# and 8.3; dev/decisions/gwr-backend.md section 2).
#
# Synthetic reference of 150 stations (set.seed(20261104)) and a regular
# prediction grid of 316 x 316 = 99 856 cells. Run from the package root:
#   Rscript dev/benchmarks/gwr-core.R
# Reports the median elapsed time of three runs of each operation.

pkgload::load_all(".", quiet = TRUE)
source("tests/testthat/helper-gwr.R")

dat <- gwr_synthetic(316L)
med <- function(expr) {
  expr <- substitute(expr)
  stats::median(replicate(3, system.time(eval(expr, parent.frame()))[[
    "elapsed"]]))
}

srch <- ef_gwr_search(n_grid = 30, tol = 1, lower_offset = 0.01,
                      upper_factor = 1.5)
cat(sprintf("Bandwidth AICc, bisquare fixed: %.2f s\n",
            med(ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                                 criterion = "AICc", search = srch))))
cat(sprintf("Bandwidth AICc, bisquare adaptive (k = 5..150): %.2f s\n",
            med(ef_gwr_bandwidth(dat$y, dat$x, dat$coords, "bisquare",
                                 adaptive = TRUE, criterion = "AICc",
                                 search = ef_gwr_search()))))

fits <- list(
  "bisquare fixed 40 km" = ef_gwr_fit(dat$y, dat$x, dat$coords, 40000,
                                      "bisquare"),
  "bisquare adaptive k = 38" = ef_gwr_fit(dat$y, dat$x, dat$coords, 38,
                                          "bisquare", adaptive = TRUE),
  "gaussian fixed 15 km" = ef_gwr_fit(dat$y, dat$x, dat$coords, 15000,
                                      "gaussian")
)
for (nm in names(fits)) {
  cat(sprintf("Prediction %d cells, %s: %.2f s\n", nrow(dat$grid_x), nm,
              med(ef_gwr_predict(fits[[nm]], dat$grid_x, dat$grid_coords))))
}
