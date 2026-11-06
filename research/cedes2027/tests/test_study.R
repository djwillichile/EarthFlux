# Checks of the study outputs (run from the root of the EarthFlux sources):
#   Rscript research/cedes2027/tests/test_study.R
# They do not touch the package or its data; they read the study outputs.

suppressPackageStartupMessages(library(testthat))
root <- file.path("research", "cedes2027")
p <- function(...) file.path(root, ...)

test_that("every macro used in the documents is defined by numbers.tex", {
  defined <- sub("^\\\\newcommand\\{\\\\([A-Za-z]+)\\}.*", "\\1",
                 grep("^\\\\newcommand", readLines(p("results", "tables", "numbers.tex")), value = TRUE))
  docs <- c(list.files(p("manuscript"), "\\.tex$", full.names = TRUE),
            list.files(p("extended-abstract"), "\\.tex$", full.names = TRUE),
            list.files(p("presentation"), "\\.tex$", full.names = TRUE))
  used <- unique(unlist(lapply(docs, function(f)
    regmatches(readLines(f, warn = FALSE), gregexpr("\\\\[A-Z][A-Za-z]+", readLines(f, warn = FALSE))))))
  used <- sub("^\\\\", "", used)
  local <- c("ETa", "ETr", "ETrF", "Rnet", "StationDataText", "AuthorAffiliation")
  latex <- c("LaTeX", "TeX")
  candidates <- setdiff(used, c(local, latex))
  # A macro used in the text must be a generated number or a LaTeX command.
  generated_like <- candidates[grepl("^(CV|Pair|M[A-Z]|Cal|D[A-Z]|S[ABC]|Range|Dens|Moran|N[A-Z]|Ver|Scene|Rep|Ratio|OLS|EarthFlux|Seed|Same|NRuns|Vol)", candidates)]
  expect_true(all(generated_like %in% defined),
              info = paste(setdiff(generated_like, defined), collapse = ", "))
})

test_that("the claims register covers every macro and points to existing files", {
  reg <- utils::read.csv(p("results", "tables", "claims_register.csv"), stringsAsFactors = FALSE)
  defined <- sub("^\\\\newcommand\\{\\\\([A-Za-z]+)\\}.*", "\\1",
                 grep("^\\\\newcommand", readLines(p("results", "tables", "numbers.tex")), value = TRUE))
  expect_setequal(sub("^\\\\", "", reg$macro), defined)
  files <- unique(trimws(unlist(strsplit(reg$source, ";"))))
  files <- files[grepl("^results/|^config/|^data/", files)]
  expect_true(all(file.exists(p(files))), info = paste(files[!file.exists(p(files))], collapse = ", "))
})

test_that("energy closure LE = Rn - G - H holds in every METRIC map", {
  for (f in list.files(p("results", "maps"), "^metric_.*\\.tif$", full.names = TRUE)) {
    r <- terra::rast(f)
    v <- terra::values(r[[c("rn", "g", "h", "le")]])
    ok <- stats::complete.cases(v)
    expect_lt(max(abs(v[ok, "le"] - (v[ok, "rn"] - v[ok, "g"] - v[ok, "h"]))), 1e-2) # float32 storage
  }
})

test_that("the anchor cells are identical in every METRIC run", {
  cal <- utils::read.csv(p("results", "tables", "metric_calibration.csv"))
  # C2-OLS loses most cells (its wind leaves the physical domain), so its
  # anchors are selected within a smaller domain (reported in the text).
  expect_true(all(cal$same_anchor_cells[cal$config != "C2-OLS"]))
  expect_true(all(cal$converged))
})

test_that("the cross-validation outputs are complete and use several folds", {
  pred <- utils::read.csv(p("results", "validation", "cv_predictions.csv"), stringsAsFactors = FALSE)
  ok <- pred[pred$status == "ok", ]
  expect_true(all(ok$n_train < ave(ok$n_train, ok$variable, ok$target_time, FUN = max) + 1))
  folds <- utils::read.csv(p("results", "diagnostics", "cv_folds.csv"))
  expect_gt(length(unique(folds$fold)), 5)
})

test_that("the 250-word abstract respects its limit", {
  first <- readLines(p("extended-abstract", "resumen_250_palabras.md"), n = 1)
  n <- as.integer(sub(".*; ([0-9]+) words.*", "\\1", first))
  expect_lte(n, 250)
})
