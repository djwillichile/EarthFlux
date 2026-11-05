# Figures and LaTeX tables from the result files (no number is typed by hand).
#
# Figures go to results/figures/ as PDF (vector) and PNG (300 dpi, for the
# slides); the data of each figure is saved next to it as CSV. Maps are shown
# in geographic coordinates (WGS 84, EPSG:4326) for display only; every
# computation stays on its native grid (MODIS sinusoidal or UTM 18S).

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

fig_dir <- p("results", "figures")
tab_dir <- p("results", "tables")
read <- function(...) utils::read.csv(p(...), stringsAsFactors = FALSE)

theme_set(theme_bw(base_size = 9) +
            theme(panel.grid = element_blank(),
                  strip.background = element_rect(fill = "grey95", colour = NA),
                  legend.key.height = unit(0.5, "cm")))
save_fig <- function(plot, name, w, h, data = NULL) {
  ggsave(file.path(fig_dir, paste0(name, ".pdf")), plot, width = w, height = h,
         units = "cm", device = grDevices::cairo_pdf)
  ggsave(file.path(fig_dir, paste0(name, ".png")), plot, width = w, height = h,
         units = "cm", dpi = 300)
  if (!is.null(data)) write_csv(data, file.path(fig_dir, paste0(name, "_data.csv")))
}
cfg_levels <- c("C1", "C1-lap", "C2-OLS", "C2-IDW", "C3-GWR")
cfg_cols <- c("C1" = "#7f7f7f", "C1-lap" = "#bcbcbc", "C2-OLS" = "#e69f00",
              "C2-IDW" = "#56b4e9", "C3-GWR" = "#009e73")
var_lab <- c(air_temperature = "Temperatura del aire (°C)",
             vapour_pressure = "Presión de vapor (kPa)",
             wind_speed_2m = "Viento a 2 m (m/s)")

to_df <- function(r, crs_out = "EPSG:4326") {
  rr <- terra::project(r, crs_out, method = "near")
  d <- terra::as.data.frame(rr, xy = TRUE, na.rm = FALSE)
  d
}
aoi <- terra::project(terra::vect(system.file("extdata", "cauquenes-province.gpkg",
                                              package = "EarthFlux")), "EPSG:4326")
aoi_df <- as.data.frame(terra::geom(aoi))
aoi_layer <- geom_path(data = aoi_df, aes(x, y, group = interaction(geom, part, hole)),
                       inherit.aes = FALSE, linewidth = 0.25, colour = "black")
map_theme <- theme(axis.title = element_blank(), axis.text = element_text(size = 6))

## Figure 1: study area -----------------------------------------------------------
scene <- terra::unwrap(EarthFlux::cauquenes_modis)
meta <- read("data", "processed", "stations_meta.csv")
inv <- read("results", "tables", "station_inventory.csv")
rep_station <- readLines(p("results", "diagnostics", "representative_station.txt"))[1]
cov_region <- terra::rast(p("data", "processed", "covariates_region.tif"))
elev_df <- to_df(terra::aggregate(cov_region[["elevation"]], 3, mean, na.rm = TRUE))
names(elev_df)[3] <- "elevation"
meta$role <- ifelse(meta$station_id == rep_station, "Representativa (C1)", "Estación")
scene_ext <- terra::ext(terra::project(terra::as.polygons(terra::ext(scene),
                                                          crs = terra::crs(scene)), "EPSG:4326"))
p1a <- ggplot(elev_df, aes(x, y, fill = elevation)) + geom_raster() +
  scale_fill_gradientn("Elevación (m)", colours = terrain.colors(10), na.value = "#cfe3f0") +
  annotate("rect", xmin = scene_ext$xmin, xmax = scene_ext$xmax, ymin = scene_ext$ymin,
           ymax = scene_ext$ymax, fill = NA, colour = "red", linewidth = 0.4) +
  geom_point(data = meta, aes(lon, lat, shape = role), inherit.aes = FALSE, size = 1.4) +
  scale_shape_manual(NULL, values = c("Estación" = 17, "Representativa (C1)" = 8)) +
  coord_fixed(1.2) + map_theme + theme(legend.position = "bottom", legend.box = "vertical") +
  labs(title = "a) Red de estaciones y relieve")
sc <- c(scene[["lst"]] - 273.15, scene[["ndvi"]], scene[["albedo"]])
names(sc) <- c("LST (°C)", "NDVI", "Albedo")
sdf <- to_df(sc)
mk <- function(col, title, pal) {
  ggplot(sdf, aes(x, y, fill = .data[[col]])) + geom_raster() + aoi_layer +
    scale_fill_gradientn(NULL, colours = pal, na.value = "white") +
    coord_fixed(1.2) + map_theme + labs(title = title) +
    theme(legend.position = "bottom", legend.key.width = unit(0.7, "cm"))
}
p1b <- mk("LST (°C)", "b) LST MODIS (°C)", rev(hcl.colors(9, "YlOrRd")))
p1c <- mk("NDVI", "c) NDVI", hcl.colors(9, "YlGn", rev = TRUE))
p1d <- mk("Albedo", "d) Albedo", hcl.colors(9, "Grays", rev = TRUE))
save_fig(p1a + (p1b / p1c / p1d) + plot_layout(widths = c(1.3, 1)), "fig01_area", 17, 15,
         data = meta)

## Figure 3: cross-validation metrics ---------------------------------------------
met <- read("results", "tables", "cv_metrics.csv")
met$config <- factor(met$config, cfg_levels)
p3 <- ggplot(met, aes(config, rmse, colour = config)) +
  geom_pointrange(aes(ymin = rmse_lo, ymax = rmse_hi), size = 0.3) +
  facet_wrap(~variable, scales = "free_y", labeller = as_labeller(var_lab)) +
  scale_colour_manual(values = cfg_cols, guide = "none") +
  labs(x = NULL, y = "RMSE fuera de muestra (IC 95 %)") +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
save_fig(p3, "fig03_cv_rmse", 17, 7, data = met)

## Figure 4: forcing fields at the overpass ----------------------------------------
fs <- list.files(p("results", "maps"), pattern = "^forcing_.*_utm\\.tif$", full.names = TRUE)
fd <- do.call(rbind, lapply(fs, function(f) {
  b <- sub("^forcing_", "", sub("_utm\\.tif$", "", basename(f)))
  cf <- regmatches(b, regexpr("(C1-lap|C1|C2-OLS|C2-IDW|C3-GWR)$", b))
  v <- sub(paste0("_", cf, "$"), "", b)
  d <- to_df(terra::rast(f))
  names(d)[3] <- "value"
  d$config <- cf; d$variable <- v
  d
}))
fd <- fd[fd$config != "C1-lap" | fd$variable == "air_temperature", ]
fd$config <- factor(fd$config, cfg_levels)
p4 <- lapply(names(var_lab), function(v) {
  ggplot(fd[fd$variable == v, ], aes(x, y, fill = value)) + geom_raster() + aoi_layer +
    facet_grid(. ~ config) +
    scale_fill_gradientn(var_lab[[v]], colours = hcl.colors(11, if (v == "air_temperature")
      "RdYlBu" else if (v == "vapour_pressure") "BrBG" else "Purples", rev = v == "air_temperature"),
      na.value = "white") +
    coord_fixed(1.2) + map_theme + theme(legend.position = "right")
})
save_fig(wrap_plots(p4, ncol = 1), "fig04_forcing_maps", 18, 16)

## Figure 5: energy balance and ETa per configuration -----------------------------
runs_files <- list.files(p("results", "maps"), pattern = "^metric_.*\\.tif$", full.names = TRUE)
lab_of <- function(f) sub("^metric_", "", sub("\\.tif$", "", basename(f)))
full_cfg <- intersect(cfg_levels, vapply(runs_files, lab_of, ""))
lay <- c(rn = "Rn", g = "G", h = "H", le = "LE")
ed <- do.call(rbind, lapply(full_cfg, function(cf) {
  r <- terra::rast(p("results", "maps", paste0("metric_", cf, ".tif")))
  d <- to_df(r[[c(names(lay), "eta", "etrf")]])
  d$config <- cf
  d
}))
ed$config <- factor(ed$config, cfg_levels)
long_e <- do.call(rbind, lapply(names(lay), function(l)
  data.frame(x = ed$x, y = ed$y, config = ed$config, flux = lay[[l]], value = ed[[l]])))
long_e$flux <- factor(long_e$flux, lay)
p5 <- ggplot(long_e, aes(x, y, fill = value)) + geom_raster() + aoi_layer +
  facet_grid(flux ~ config) +
  scale_fill_gradientn("W/m²", colours = hcl.colors(11, "Spectral", rev = TRUE),
                       limits = c(-50, 800), oob = scales::squish, na.value = "white") +
  coord_fixed(1.2) + map_theme
save_fig(p5, "fig05_energy_balance", 18, 17)

## Figure 6: ETa maps and differences against C1 ------------------------------------
eta_lim <- stats::quantile(ed$eta, c(0.01, 0.99), na.rm = TRUE)
p6a <- ggplot(ed, aes(x, y, fill = eta)) + geom_raster() + aoi_layer +
  facet_grid(. ~ config) +
  scale_fill_gradientn("ETa (mm/d)", colours = hcl.colors(11, "YlGnBu", rev = TRUE),
                       limits = eta_lim, oob = scales::squish, na.value = "white") +
  coord_fixed(1.2) + map_theme
base <- ed[ed$config == "C1", c("x", "y", "eta")]
dd <- merge(ed[ed$config != "C1", c("x", "y", "config", "eta")], base, by = c("x", "y"),
            suffixes = c("", "_c1"))
dd$diff <- dd$eta - dd$eta_c1
lim <- max(abs(stats::quantile(dd$diff, c(0.01, 0.99), na.rm = TRUE)))
p6b <- ggplot(dd, aes(x, y, fill = diff)) + geom_raster() + aoi_layer +
  facet_grid(. ~ config) +
  scale_fill_gradientn("ΔETa vs C1\n(mm/d)", colours = hcl.colors(11, "RdBu"),
                       limits = c(-lim, lim), oob = scales::squish, na.value = "white") +
  coord_fixed(1.2) + map_theme
save_fig(p6a / p6b, "fig06_eta_maps", 18, 12)

## Figure 7: one-at-a-time attribution ---------------------------------------------
dv <- read("results", "tables", "metric_differences_vs_C1.csv")
oat <- dv[grepl("^C1\\+GWR:", dv$config) & dv$variable == "eta", ]
full <- dv[dv$config %in% cfg_levels & dv$variable == "eta", ]
if (nrow(oat) > 0) {
  oat$input <- factor(sub("^C1\\+GWR:", "", oat$config),
                      c("ta", "ea", "u2", "etr_inst", "etr_24"),
                      c("Ta (RL↓)", "ea (τsw)", "u2 (rah)", "ETr inst (ancla fría)", "ETr 24 h"))
  p7 <- ggplot(oat, aes(input, mean_diff)) +
    geom_col(fill = cfg_cols[["C3-GWR"]], width = 0.6) +
    geom_errorbar(aes(ymin = p05, ymax = p95), width = 0.2) +
    geom_hline(yintercept = 0, linewidth = 0.3) +
    geom_hline(yintercept = full$mean_diff[full$config == "C3-GWR"], linetype = 2,
               colour = cfg_cols[["C3-GWR"]]) +
    labs(x = "Entrada sustituida por su campo C3-GWR (resto = C1)",
         y = "ΔETa respecto de C1 (mm/d)\nmedia de la escena y P5–P95")
  save_fig(p7, "fig07_attribution", 15, 7.5, data = oat)
}

## Figure 8: sensitivity ----------------------------------------------------------
sa <- read("results", "tables", "sensitivity_SA_anchors.csv")
sb <- read("results", "tables", "sensitivity_SB_modis.csv")
sens <- rbind(data.frame(source = "S-A anclas y\ncondiciones de borde", config = sa$config,
                         eta_mean = sa$eta_mean),
              data.frame(source = "S-B ruido\nMODIS (LST, albedo)", config = sb$config,
                         eta_mean = sb$eta_mean))
sens$config <- factor(sens$config, cfg_levels)
p8 <- ggplot(sens, aes(config, eta_mean, fill = config)) +
  geom_violin(scale = "width", linewidth = 0.2, alpha = 0.8) +
  geom_boxplot(width = 0.12, outlier.size = 0.3, fill = "white", linewidth = 0.25) +
  facet_wrap(~source) + scale_fill_manual(values = cfg_cols, guide = "none") +
  labs(x = NULL, y = "ETa media de la escena (mm/d)")
save_fig(p8, "fig08_sensitivity", 14, 7, data = sens)

## LaTeX tables ---------------------------------------------------------------------
fmt <- function(x, d = 2) formatC(x, format = "f", digits = d, decimal.mark = ",")
tex_table <- function(file, header, rows, align, caption, label, notes = NULL, size = "\\small") {
  out <- c("\\begin{table}[htbp]", "\\centering", size,
           sprintf("\\caption{%s}\\label{%s}", caption, label),
           "\\begin{threeparttable}",
           sprintf("\\begin{tabular}{%s}", align), "\\toprule", header, "\\midrule",
           rows, "\\bottomrule", "\\end{tabular}",
           if (!is.null(notes)) c("\\begin{tablenotes}\\footnotesize", paste0("\\item ", notes),
                                  "\\end{tablenotes}"),
           "\\end{threeparttable}", "\\end{table}")
  writeLines(out, file.path(tab_dir, file))
}
vl <- c(air_temperature = "$T_a$ (\\si{\\celsius})", vapour_pressure = "$e_a$ (\\si{\\kilo\\pascal})",
        wind_speed_2m = "$u_2$ (\\si{\\metre\\per\\second})")
met <- met[order(match(met$variable, names(vl)), met$config), ]
rows <- sprintf("%s & %s & %d & %s [%s; %s] & %s & %s [%s; %s] & %s & %d \\\\",
                ifelse(duplicated(met$variable), "", vl[met$variable]), met$config, met$n_pred,
                fmt(met$rmse), fmt(met$rmse_lo), fmt(met$rmse_hi), fmt(met$mae),
                fmt(met$bias), fmt(met$bias_lo), fmt(met$bias_hi), fmt(met$r),
                met$n_failed_folds)
tex_table("tab_cv_metrics.tex",
          "Variable & Config. & $n$ & RMSE [IC 95\\,\\%] & MAE & Sesgo [IC 95\\,\\%] & $r$ & Pliegues fallidos \\\\",
          rows, "llrlrlrr",
          "Validación cruzada espacial anidada de la regionalización a la hora del paso (14:00 UTC, enero--marzo de 2019).",
          "tab:cv",
          notes = c("$n$: predicciones fuera de muestra. Sesgo = predicho $-$ observado. IC: \\emph{bootstrap} de días completos ($B = 2000$).",
                    "C1 no se evalúa en su propia estación. Pliegue fallido: el método no pudo ajustarse con las estaciones de entrenamiento (p.\\,ej., GWR o regresión global con menos estaciones que parámetros + 3)."),
          size = "\\footnotesize")

summ <- read("results", "tables", "metric_summary.csv")
cal <- read("results", "tables", "metric_calibration.csv")
vars_m <- c(rn = "$R_n$", g = "$G$", h = "$H$", le = "$LE$", etrf = "$\\mathrm{ET_rF}$",
            eta = "$\\mathrm{ET_a}$ (mm/d)", forcing_etr_24 = "$\\mathrm{ET_r^{24}}$ (mm/d)")
cfs <- intersect(cfg_levels, unique(summ$config))
rows <- vapply(names(vars_m), function(v) {
  vals <- vapply(cfs, function(cf) {
    x <- summ[summ$config == cf & summ$variable == v, ]
    if (nrow(x) == 0) return("--")
    d <- if (v %in% c("etrf")) 2 else if (v %in% c("eta", "forcing_etr_24")) 2 else 0
    sprintf("%s (%s)", fmt(x$mean, d), fmt(x$sd, d))
  }, "")
  paste(vars_m[[v]], "&", paste(vals, collapse = " & "), "\\\\")
}, "")
calrow <- function(col, lab, d) paste(lab, "&", paste(vapply(cfs, function(cf)
  fmt(cal[cal$config == cf, col], d), ""), collapse = " & "), "\\\\")
rows <- c(rows, "\\midrule", calrow("a", "$a$ (K)", 2), calrow("b", "$b$ (--)", 3),
          calrow("iterations", "Iteraciones", 0),
          calrow("etr_inst_cold", "$\\mathrm{ET_r}$ inst. ancla fría (mm/h)", 3),
          calrow("u_blend_cold", "$u_{200}$ ancla fría (m/s)", 2),
          calrow("n_eta_negative", "Celdas con $\\mathrm{ET_a} < 0$", 0))
tex_table("tab_metric_summary.tex",
          paste("Variable &", paste(cfs, collapse = " & "), "\\\\"),
          rows, paste0("l", strrep("r", length(cfs))),
          "Balance de energía y $\\mathrm{ET_a}$ de la escena de Cauquenes (15-02-2019) por configuración: media (desviación estándar espacial) y parámetros de calibración.",
          "tab:metric", notes = "Flujos en \\si{\\watt\\per\\square\\metre}. Las celdas ancla son las mismas en todas las configuraciones.",
          size = "\\footnotesize")
message("figures and tables written")
