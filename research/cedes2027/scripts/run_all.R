# Run the whole CEDES 2027 study from the root of the EarthFlux sources:
Sys.setenv(LC_ALL = "C.UTF-8", LANG = "C.UTF-8") # UTF-8 labels in figures and tables
#   Rscript research/cedes2027/scripts/run_all.R
# Optional: CEDES_SKIP_DOWNLOAD=1 to reuse the cache; CEDES_WORKERS=n to set a
# future plan for the cross-validation (results are identical for any plan).

steps <- c("01_download_data.R", "02_covariates.R", "03_stations.R",
           "04_regionalization_cv.R", "04b_residuals_density.R",
           "05_metric_experiment.R", "05b_forcing_range.R",
           "06_sensitivity.R", "07_figures_tables.R", "08_numbers.R")
if (nzchar(Sys.getenv("CEDES_SKIP_DOWNLOAD"))) steps <- steps[-1]
root <- file.path("research", "cedes2027")
log <- file.path(root, "results", "diagnostics", "run_all_log.csv")
timing <- data.frame(step = character(), seconds = numeric(), status = character())
for (s in steps) {
  t0 <- Sys.time()
  st <- system2("Rscript", file.path(root, "scripts", s))
  timing <- rbind(timing, data.frame(step = s, seconds = as.numeric(difftime(
    Sys.time(), t0, units = "secs")), status = if (st == 0) "ok" else "error"))
  if (st != 0) stop("step failed: ", s)
}
for (d in c("manuscript", "extended-abstract", "presentation")) {
  tex <- list.files(file.path(root, d), pattern = "^(manuscrito|resumen_extendido|resumen_250|presentacion).*\\.tex$")
  for (f in tex) {
    st <- system2("latexmk", c("-pdf", "-interaction=nonstopmode", "-silent",
                               "-cd", file.path(root, d, f)))
    timing <- rbind(timing, data.frame(step = f, seconds = NA, status = if (st == 0) "ok" else "error"))
  }
}
utils::write.csv(timing, log, row.names = FALSE)
print(timing)
