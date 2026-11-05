# Numbers of the text: every quantitative statement of the manuscript, the
# extended abstract, the 250-word abstract and the slides is a LaTeX macro
# written here from the result files. The register
# results/tables/claims_register.csv records, for each macro, its value, the
# source file, the selection and the computation.

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))

read <- function(...) utils::read.csv(p(...), stringsAsFactors = FALSE)
reg <- list()
macros <- character()
fmt <- function(x, d) formatC(x, format = "f", digits = d, decimal.mark = ",")
add <- function(name, value, source, selection, computation, digits = NULL) {
  txt <- if (is.numeric(value) && !is.null(digits)) fmt(value, digits) else as.character(value)
  macros[[name]] <<- txt
  reg[[name]] <<- data.frame(macro = paste0("\\", name), value = txt, source = source,
                             selection = selection, computation = computation)
}
cfg_key <- c("C1" = "COne", "C1-lap" = "COneLap", "C2-OLS" = "CTwoOLS",
             "C2-IDW" = "CTwoIDW", "C3-GWR" = "CThreeGWR")
var_key <- c(air_temperature = "Ta", vapour_pressure = "Ea", wind_speed_2m = "Wind")

## Software, tests, verification ---------------------------------------------------
add("EarthFluxVersion", as.character(utils::packageVersion("EarthFlux")), "DESCRIPTION",
    "Version", "packageVersion('EarthFlux')")
add("EarthFluxCommit", substr(git_commit(), 1, 7), "git", "HEAD", "git rev-parse HEAD (short)")
add("Seed", cfg$seed, "config/study.json", "seed", "value")
add("NMC", cfg$monte_carlo_replicates, "config/study.json", "monte_carlo_replicates", "value")
tests <- read("results", "diagnostics", "package_tests.csv")
add("NTests", nrow(tests), "results/diagnostics/package_tests.csv", "all rows",
    "number of test_that() blocks run")
add("NExpectations", sum(tests$nb), "results/diagnostics/package_tests.csv", "all rows", "sum(nb)")
add("NTestsFailed", sum(tests$failed > 0), "results/diagnostics/package_tests.csv", "failed > 0", "count")
add("NTestsError", sum(tests$error), "results/diagnostics/package_tests.csv", "error == TRUE", "count")
add("NTestsSkipped", sum(tests$skipped), "results/diagnostics/package_tests.csv", "skipped == TRUE", "count")
add("NTestsPassed", sum(!tests$error & tests$failed == 0 & !tests$skipped),
    "results/diagnostics/package_tests.csv", "no error, no failure, not skipped", "count")
# Verification register of the package (dev/VERIFICATION.md section 2).
vr <- c(VerRows = 49, VerVerified = 31, VerCorroborated = 3, VerCandidate = 9,
        VerDiscrepancies = 7, VerFixed = 2)
for (n in names(vr)) add(n, vr[[n]], "dev/VERIFICATION.md", "section 2 (summary table)",
                         "count of rows of the verification table")

## Scene and stations ---------------------------------------------------------------
scene <- terra::unwrap(EarthFlux::cauquenes_modis)
cov <- read("results", "diagnostics", "covariates_summary.csv")
add("SceneElevMax", round(cov$max[cov$grid == "scene_modis_sinusoidal" & cov$layer == "elevation"]),
    "results/diagnostics/covariates_summary.csv", "scene_modis_sinusoidal, elevation", "max, rounded")
in_prov <- sum(!is.na(terra::values(scene[["lst"]])) | !is.na(terra::values(scene[["ndvi"]])) |
                 !is.na(terra::values(scene[["albedo"]])))
add("SceneCellsProvince", in_prov, "EarthFlux::cauquenes_modis", "cells with LST, NDVI or albedo",
    "count")
cal <- read("results", "tables", "metric_calibration.csv")
add("SceneCellsValid", cal$n_cells[cal$config == "C1"], "results/tables/metric_calibration.csv",
    "config C1", "n_cells (all surface inputs, elevation and forcing valid)")
inv <- read("results", "tables", "station_inventory.csv")
add("NStations", nrow(inv), "results/tables/station_inventory.csv", "all rows", "count")
net <- function(pat) sum(grepl(pat, inv$network))
add("NStationsDMC", net("\\(DMC\\)"), "results/tables/station_inventory.csv", "network DMC SACLIM (DMC)", "count")
add("NStationsINIA", net("\\(INIA\\)"), "results/tables/station_inventory.csv", "network DMC SACLIM (INIA)", "count")
add("NStationsFDF", net("\\(FDF\\)"), "results/tables/station_inventory.csv", "network DMC SACLIM (FDF)", "count")
add("NStationsISD", net("ISD"), "results/tables/station_inventory.csv", "network NOAA ISD", "count")
add("NStationsWind", sum(inv$ws_valid > 0, na.rm = TRUE), "results/tables/station_inventory.csv",
    "ws_valid > 0", "stations with wind at the overpass hour")
rep <- readLines(p("results", "diagnostics", "representative_station.txt"))
meta <- read("data", "processed", "stations_meta.csv")
add("RepStationName", gsub("&", "\\\\&", meta$name[meta$station_id == rep[1]]),
    "results/diagnostics/representative_station.txt", "line 1", "station name from stations_meta.csv")
add("RepStationDist", as.numeric(sub(" km", "", rep[2])), "results/diagnostics/representative_station.txt",
    "line 2", "distance to the centroid of the province (km)", digits = 0)

## Experiment R ---------------------------------------------------------------------
met <- read("results", "tables", "cv_metrics.csv")
pred <- read("results", "validation", "cv_predictions.csv")
add("NCVDays", length(unique(pred$target_time)), "results/validation/cv_predictions.csv",
    "all rows", "number of distinct target times")
folds <- read("results", "diagnostics", "cv_folds.csv")
add("NFolds", length(unique(folds$fold)), "results/diagnostics/cv_folds.csv", "all rows",
    "number of distinct folds")
add("NCVPred", sum(pred$status == "ok"), "results/validation/cv_predictions.csv",
    "status == ok", "count of held-out predictions")
for (i in seq_len(nrow(met))) {
  k <- paste0("CV", var_key[[met$variable[i]]], cfg_key[[met$config[i]]])
  sel <- sprintf("variable == %s, config == %s", met$variable[i], met$config[i])
  d <- if (met$variable[i] == "vapour_pressure") 3 else 2
  add(paste0(k, "Rmse"), met$rmse[i], "results/tables/cv_metrics.csv", sel, "rmse", d)
  add(paste0(k, "RmseLo"), met$rmse_lo[i], "results/tables/cv_metrics.csv", sel, "rmse_lo (2.5 % block bootstrap)", d)
  add(paste0(k, "RmseHi"), met$rmse_hi[i], "results/tables/cv_metrics.csv", sel, "rmse_hi (97.5 % block bootstrap)", d)
  add(paste0(k, "Bias"), met$bias[i], "results/tables/cv_metrics.csv", sel, "bias (predicted - observed)", d)
  add(paste0(k, "R"), met$r[i], "results/tables/cv_metrics.csv", sel, "Pearson r", 2)
  add(paste0(k, "Failed"), met$n_failed_folds[i], "results/tables/cv_metrics.csv", sel, "n_failed_folds")
  add(paste0(k, "N"), met$n_pred[i], "results/tables/cv_metrics.csv", sel, "n_pred")
}
pv <- read("results", "tables", "cv_paired_vs_gwr.csv")
for (i in seq_len(nrow(pv))) {
  alt <- sub("C3-GWR vs ", "", pv$comparison[i])
  k <- paste0("Pair", var_key[[pv$variable[i]]], cfg_key[[alt]])
  sel <- sprintf("variable == %s, comparison == %s", pv$variable[i], pv$comparison[i])
  d <- if (pv$variable[i] == "vapour_pressure") 4 else 3
  add(paste0(k, "Dse"), pv$mean_dse[i], "results/tables/cv_paired_vs_gwr.csv", sel,
      "mean of SE(GWR) - SE(alt)", d)
  add(paste0(k, "Lo"), pv$ci_lo[i], "results/tables/cv_paired_vs_gwr.csv", sel, "ci_lo", d)
  add(paste0(k, "Hi"), pv$ci_hi[i], "results/tables/cv_paired_vs_gwr.csv", sel, "ci_hi", d)
  add(paste0(k, "Share"), 100 * pv$gwr_better_share[i], "results/tables/cv_paired_vs_gwr.csv", sel,
      "100 x share of predictions where |e_GWR| < |e_alt|", 0)
}

wf <- pred[pred$variable == "wind_speed_2m" & pred$config == "C3-GWR", ]
add("CVWindCThreeGWRFailed", sum(wf$status == "failed"), "results/validation/cv_predictions.csv",
    "variable == wind_speed_2m, config == C3-GWR, status == failed", "count")
add("CVWindCThreeGWRTotal", nrow(wf), "results/validation/cv_predictions.csv",
    "variable == wind_speed_2m, config == C3-GWR", "count")
wo <- pred[pred$variable == "wind_speed_2m" & pred$config == "C2-OLS" & pred$status == "ok", ]
add("CVWindOLSMax", max(wo$predicted), "results/validation/cv_predictions.csv",
    "wind_speed_2m, C2-OLS, ok", "max predicted", 0)
add("CVWindOLSNeg", sum(wo$predicted < 0), "results/validation/cv_predictions.csv",
    "wind_speed_2m, C2-OLS, ok", "count of predicted < 0")
mo <- read("results", "tables", "cv_residual_moran_summary.csv")
for (i in seq_len(nrow(mo))) {
  k <- paste0("Moran", var_key[[mo$variable[i]]], cfg_key[[mo$config[i]]])
  sel <- sprintf("variable == %s, config == %s", mo$variable[i], mo$config[i])
  add(paste0(k, "I"), mo$median_I[i], "results/tables/cv_residual_moran_summary.csv", sel,
      "median Moran's I over target times", 2)
  add(paste0(k, "Sig"), 100 * mo$share_sig[i], "results/tables/cv_residual_moran_summary.csv", sel,
      "100 x share of times with p < 0.05 (199 permutations)", 0)
}
de <- read("results", "tables", "cv_station_density_summary.csv")
fk <- c("0.25" = "Quarter", "0.5" = "Half", "0.75" = "ThreeQ", "1" = "All")
for (i in seq_len(nrow(de))) {
  k <- paste0("Dens", var_key[[de$variable[i]]], cfg_key[[de$config[i]]], fk[[as.character(de$fraction[i])]])
  sel <- sprintf("variable == %s, config == %s, fraction == %s", de$variable[i], de$config[i], de$fraction[i])
  d <- if (de$variable[i] == "vapour_pressure") 3 else 2
  add(k, de$rmse_mean[i], "results/tables/cv_station_density_summary.csv", sel, "mean RMSE over subsets", d)
  add(paste0(k, "N"), de$n_stations[i], "results/tables/cv_station_density_summary.csv", sel, "stations")
}

## Experiment M ----------------------------------------------------------------------
stt <- read("results", "diagnostics", "scene_regionalization_status.csv")
add("OLSWindOOD", stt$n_ood[stt$config == "C2-OLS" & stt$variable == "wind_speed_2m"],
    "results/diagnostics/scene_regionalization_status.csv", "C2-OLS, wind_speed_2m",
    "cells x hours of the UTM grid with u2 out of the physical domain")
summ <- read("results", "tables", "metric_summary.csv")
for (i in which(summ$variable %in% c("rn", "g", "h", "le", "eta", "etrf", "forcing_ta",
                                     "forcing_etr_24", "forcing_etr_inst", "forcing_u2",
                                     "forcing_ea") & summ$config %in% names(cfg_key))) {
  v <- summ$variable[i]
  vk <- c(rn = "Rn", g = "G", h = "H", le = "LE", eta = "Eta", etrf = "Etrf",
          forcing_ta = "FTa", forcing_etr_24 = "FEtrDay", forcing_etr_inst = "FEtrInst",
          forcing_u2 = "FWind", forcing_ea = "FEa")[[v]]
  d <- if (v %in% c("rn", "g", "h", "le")) 0 else if (v == "forcing_etr_inst") 3 else 2
  k <- paste0("M", vk, cfg_key[[summ$config[i]]])
  sel <- sprintf("config == %s, variable == %s", summ$config[i], v)
  add(paste0(k, "Mean"), summ$mean[i], "results/tables/metric_summary.csv", sel, "spatial mean", d)
  add(paste0(k, "Sd"), summ$sd[i], "results/tables/metric_summary.csv", sel, "spatial sd", d)
}
for (i in seq_len(nrow(cal))) {
  cf <- cal$config[i]
  key <- if (cf %in% names(cfg_key)) cfg_key[[cf]] else paste0("Oat", c(
    "C1+GWR:ta" = "Ta", "C1+GWR:ea" = "Ea", "C1+GWR:u2" = "Wind",
    "C1+GWR:etr_inst" = "EtrInst", "C1+GWR:etr_24" = "EtrDay")[[cf]])
  sel <- sprintf("config == %s", cf)
  add(paste0("Cal", key, "A"), cal$a[i], "results/tables/metric_calibration.csv", sel, "a (K)", 2)
  add(paste0("Cal", key, "B"), cal$b[i], "results/tables/metric_calibration.csv", sel, "b (-)", 3)
  add(paste0("Cal", key, "Iter"), cal$iterations[i], "results/tables/metric_calibration.csv", sel, "iterations")
  add(paste0("Cal", key, "Neg"), cal$n_eta_negative[i], "results/tables/metric_calibration.csv", sel,
      "cells with ETa < 0")
}
fr <- read("results", "tables", "forcing_range_check.csv")
for (i in seq_len(nrow(fr))) {
  k <- paste0("Range", c(ta = "Ta", ea = "Ea")[[fr$variable[i]]], cfg_key[[fr$config[i]]])
  sel <- sprintf("config == %s, variable == %s", fr$config[i], fr$variable[i])
  add(paste0(k, "Above"), 100 * fr$share_above[i], "results/tables/forcing_range_check.csv", sel,
      "100 x share of scene cells above the station maximum at 14 UTC", 1)
  add(paste0(k, "Max"), fr$field_max[i], "results/tables/forcing_range_check.csv", sel, "field max", 1)
  add(paste0(k, "ObsMax"), fr$obs_max[i], "results/tables/forcing_range_check.csv", sel, "station max", 1)
}
add("OLSValidCells", cal$n_cells[cal$config == "C2-OLS"], "results/tables/metric_calibration.csv",
    "config == C2-OLS", "n_cells")
add("SameAnchors", if (all(cal$same_anchor_cells[cal$config != "C2-OLS"])) "sí" else "no",
    "results/tables/metric_calibration.csv", "same_anchor_cells, config != C2-OLS", "all()")
add("NRunsSameAnchors", sum(cal$same_anchor_cells), "results/tables/metric_calibration.csv",
    "same_anchor_cells == TRUE", "count of runs with the anchor cells of C1")
add("NRuns", nrow(cal), "results/tables/metric_calibration.csv", "all rows", "count of METRIC runs")
dv <- read("results", "tables", "metric_differences_vs_C1.csv")
for (i in which(dv$variable %in% c("eta", "h", "rn", "etrf"))) {
  cf <- dv$config[i]
  key <- if (cf %in% names(cfg_key)) cfg_key[[cf]] else paste0("Oat", c(
    "C1+GWR:ta" = "Ta", "C1+GWR:ea" = "Ea", "C1+GWR:u2" = "Wind",
    "C1+GWR:etr_inst" = "EtrInst", "C1+GWR:etr_24" = "EtrDay")[[cf]])
  vk <- c(eta = "Eta", h = "H", rn = "Rn", etrf = "Etrf")[[dv$variable[i]]]
  d <- if (dv$variable[i] %in% c("h", "rn")) 1 else 2
  k <- paste0("D", vk, key)
  sel <- sprintf("config == %s, variable == %s", cf, dv$variable[i])
  add(paste0(k, "Mean"), dv$mean_diff[i], "results/tables/metric_differences_vs_C1.csv", sel,
      "mean of (config - C1) over common cells", d)
  add(paste0(k, "Mad"), dv$mad[i], "results/tables/metric_differences_vs_C1.csv", sel, "mean |config - C1|", d)
  add(paste0(k, "Pct"), dv$rel_mean_diff_pct[i], "results/tables/metric_differences_vs_C1.csv", sel,
      "100 x mean diff / mean(C1)", 1)
  add(paste0(k, "Lo"), dv$p05[i], "results/tables/metric_differences_vs_C1.csv", sel, "P5 of the difference", d)
  add(paste0(k, "Hi"), dv$p95[i], "results/tables/metric_differences_vs_C1.csv", sel, "P95 of the difference", d)
  if (dv$variable[i] == "eta")
    add(paste0(k, "Share"), 100 * dv$share_abs_gt[i], "results/tables/metric_differences_vs_C1.csv", sel,
        "100 x share of cells with |diff| > 0.5 mm/d", 0)
}

## Experiment S -------------------------------------------------------------------------
fe <- read("results", "tables", "sensitivity_forcing_effect.csv")
ss <- read("results", "tables", "sensitivity_summary.csv")
for (i in seq_len(nrow(fe))) {
  k <- c("S-A anchors/boundary" = "SA", "S-B MODIS noise" = "SB")[[fe$source[i]]]
  sel <- sprintf("source == %s", fe$source[i])
  add(paste0(k, "EffMean"), fe$mean[i], "results/tables/sensitivity_forcing_effect.csv", sel,
      "mean paired difference of scene-mean ETa", 2)
  add(paste0(k, "EffLo"), fe$p025[i], "results/tables/sensitivity_forcing_effect.csv", sel, "P2.5", 2)
  add(paste0(k, "EffHi"), fe$p975[i], "results/tables/sensitivity_forcing_effect.csv", sel, "P97.5", 2)
  add(paste0(k, "EffSign"), 100 * fe$share_same_sign[i], "results/tables/sensitivity_forcing_effect.csv",
      sel, "100 x share of replicates with the sign of the mean", 0)
  add("SContrast", fe$contrast[i], "results/tables/sensitivity_forcing_effect.csv", sel, "contrast label")
}
for (src in c("S-A anchors/boundary", "S-B MODIS noise")) {
  k <- c("S-A anchors/boundary" = "RatioSA", "S-B MODIS noise" = "RatioSB")[[src]]
  add(k, abs(fe$mean[fe$source == src]) / ss$eta_mean_sd[ss$source == src & ss$config == "C1"],
      "results/tables/sensitivity_forcing_effect.csv; results/tables/sensitivity_summary.csv",
      sprintf("source == %s; config == C1", src),
      "|mean paired effect C3-GWR - C1| / sd of scene-mean ETa with C1", 1)
}
for (i in seq_len(nrow(ss))) {
  k <- c("S-A anchors/boundary" = "SA", "S-B MODIS noise" = "SB", "S-C structural" = "SC")[[ss$source[i]]]
  ck <- cfg_key[[ss$config[i]]]
  sel <- sprintf("source == %s, config == %s", ss$source[i], ss$config[i])
  add(paste0(k, ck, "Sd"), ss$eta_mean_sd[i], "results/tables/sensitivity_summary.csv", sel,
      "sd of scene-mean ETa over replicates", 2)
  add(paste0(k, ck, "Lo"), ss$eta_mean_p025[i], "results/tables/sensitivity_summary.csv", sel, "P2.5", 2)
  add(paste0(k, ck, "Hi"), ss$eta_mean_p975[i], "results/tables/sensitivity_summary.csv", sel, "P97.5", 2)
  add(paste0(k, ck, "Conv"), 100 * ss$share_converged[i], "results/tables/sensitivity_summary.csv", sel,
      "100 x share of converged calibrations", 0)
}
sc <- read("results", "tables", "sensitivity_SC_structural.csv")
for (i in seq_len(nrow(sc))) {
  k <- paste0("SC", gsub("[^A-Za-z]", "", tools::toTitleCase(gsub("_", " ", sc$variant[i]))),
              cfg_key[[sc$config[i]]])
  add(k, sc$eta_mean[i], "results/tables/sensitivity_SC_structural.csv",
      sprintf("variant == %s, config == %s", sc$variant[i], sc$config[i]), "scene-mean ETa", 2)
}

## Station paragraph of section 3.3 (generated, so its numbers stay in sync) ----------
st_text <- sprintf(paste0(
  "Se usaron %d estaciones con observaciones horarias entre el 1 de enero y el 31 de marzo ",
  "de 2019 dentro del rectángulo \\ang{34}--\\ang{38.5}~S, \\ang{70.3}--\\ang{73.6}~O ",
  "(figura~\\ref{fig:area}): %d de la Dirección Meteorológica de Chile (DMC), %d de la red ",
  "del Instituto de Investigaciones Agropecuarias (INIA) y %d de la Fundación para el ",
  "Desarrollo Frutícola (FDF), todas obtenidas del portal público SACLIM de la DMC, más %d ",
  "estaciones de aeropuerto de la base NOAA ISD no repetidas en la DMC. Todas registran ",
  "temperatura y humedad del aire (punto de rocío o humedad relativa, de la que se obtiene ",
  "la presión de vapor con FAO-56); solo %d miden viento, a \\SI{10}{\\metre}. El portal ",
  "publica la radiación global como máximo horario de lecturas instantáneas, no como media, ",
  "por lo que no se usa como forzamiento (D-04). Los valores a HH:00~UTC se tratan como ",
  "puntuales. Las alturas de los sensores de temperatura se asumieron en \\SI{2}{\\metre}."),
  as.integer(macros[["NStations"]]), as.integer(macros[["NStationsDMC"]]),
  as.integer(macros[["NStationsINIA"]]), as.integer(macros[["NStationsFDF"]]),
  as.integer(macros[["NStationsISD"]]), as.integer(macros[["NStationsWind"]]))
writeLines(c("% Generated by scripts/08_numbers.R - do not edit by hand.",
             paste0("\\newcommand{\\StationDataText}{", st_text, "}"),
             "% Affiliation: to be confirmed by the author (no verified affiliation in the package metadata).",
             "\\newcommand{\\AuthorAffiliation}{Afiliación institucional por confirmar}"),
           p("manuscript", "stationtext.tex"))

## Write ----------------------------------------------------------------------------------
stopifnot(!any(grepl("[0-9]", names(macros))))
lines <- c("% Generated by scripts/08_numbers.R - do not edit by hand.",
           sprintf("\\newcommand{\\%s}{%s}", names(macros), unname(macros)))
writeLines(lines, p("results", "tables", "numbers.tex"))
write_csv(do.call(rbind, reg), p("results", "tables", "claims_register.csv"))
message(length(macros), " macros written")

## 250-word abstract (Markdown) from its template --------------------------------------
tpl <- readLines(p("extended-abstract", "resumen_250_template.md"), encoding = "UTF-8")
txt <- paste(tpl, collapse = "\n")
for (k in regmatches(txt, gregexpr("\\{[A-Za-z]+\\}", txt))[[1]]) {
  key <- gsub("[{}]", "", k)
  if (!key %in% names(macros)) stop("unknown macro in template: ", key)
  txt <- gsub(k, macros[[key]], txt, fixed = TRUE)
}
body <- strsplit(txt, "\n")[[1]]
body_text <- body[nzchar(body) & !grepl("^#|^\\*\\*", body)]
n_words <- length(strsplit(paste(body_text, collapse = " "), "\\s+")[[1]])
writeLines(c(paste0("<!-- Generated by scripts/08_numbers.R from resumen_250_template.md; ",
                    n_words, " words in the abstract body. -->"), body),
           p("extended-abstract", "resumen_250_palabras.md"), useBytes = TRUE)
if (n_words > 250) warning("the abstract has ", n_words, " words")
message("250-word abstract: ", n_words, " words")
