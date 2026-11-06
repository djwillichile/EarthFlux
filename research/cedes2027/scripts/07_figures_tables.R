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
vbar1 <- function(h = 3) guide_colourbar(title.position = "right",
                                         title.theme = element_text(angle = 90, hjust = 0.5, size = 7),
                                         barheight = unit(h, "cm"), barwidth = unit(0.3, "cm"))
p1a <- ggplot(elev_df, aes(x, y, fill = elevation)) + geom_raster() +
  scale_fill_gradientn("Elevación (m)", colours = terrain.colors(10), na.value = "#cfe3f0",
                       guide = vbar1(4)) +
  annotate("rect", xmin = scene_ext$xmin, xmax = scene_ext$xmax, ymin = scene_ext$ymin,
           ymax = scene_ext$ymax, fill = NA, colour = "red", linewidth = 0.4) +
  geom_point(data = meta, aes(lon, lat, shape = role), inherit.aes = FALSE, size = 1.4) +
  scale_shape_manual(NULL, values = c("Estación" = 17, "Representativa (C1)" = 8),
                     guide = guide_legend(position = "inside")) +
  coord_fixed(1.2, expand = FALSE) + map_theme +
  theme(legend.position = "right", legend.box = "vertical",
        legend.position.inside = c(0.02, 0.02), legend.justification.inside = c(0, 0),
        legend.background = element_rect(fill = scales::alpha("white", 0.85), colour = NA),
        legend.text = element_text(size = 7), legend.key.size = unit(0.35, "cm"),
        plot.title = element_text(size = 8)) +
  labs(title = "a) Red de estaciones y relieve")
sc <- c(scene[["lst"]] - 273.15, scene[["ndvi"]], scene[["albedo"]])
names(sc) <- c("lst_c", "ndvi", "albedo")
sdf <- to_df(sc)
ok1 <- !is.na(sdf$lst_c)
lim1 <- coord_fixed(1.2, xlim = range(sdf$x[ok1]) + c(-0.03, 0.03),
                    ylim = range(sdf$y[ok1]) + c(-0.03, 0.03), expand = FALSE)
mk <- function(col, title, legend, pal) {
  ggplot(sdf, aes(x, y, fill = .data[[col]])) + geom_raster() + aoi_layer +
    scale_fill_gradientn(legend, colours = pal, na.value = "white", guide = vbar1(2.4)) +
    scale_x_continuous(breaks = c(-72.6, -72.2)) +
    lim1 + map_theme + labs(title = title) +
    theme(legend.position = "right", plot.title = element_text(size = 8),
          plot.margin = margin(1, 2, 1, 2))
}
p1b <- mk("lst_c", "b) Temperatura superficial", "LST (°C)", rev(hcl.colors(9, "YlOrRd")))
p1c <- mk("ndvi", "c) NDVI", "NDVI (-)", hcl.colors(9, "YlGn", rev = TRUE))
p1d <- mk("albedo", "d) Albedo", "Albedo (-)", hcl.colors(9, "Grays", rev = TRUE))
save_fig(p1a + (p1b / p1c / p1d) + plot_layout(widths = c(1.45, 1)), "fig01_area", 17, 13,
         data = meta)

## Figure 3: cross-validation metrics ---------------------------------------------
met <- read("results", "tables", "cv_metrics.csv")
met$config <- factor(met$config, cfg_levels)
# Configurations without a metric are labelled in place: "no factible" when
# every fold failed (GWR of the wind), "no aplica" otherwise (the lapse rate
# of C1-lap only applies to air temperature).
pr3 <- read("results", "validation", "cv_predictions.csv")
miss <- expand.grid(variable = unique(met$variable), config = cfg_levels,
                    stringsAsFactors = FALSE)
miss <- miss[!paste(miss$variable, miss$config) %in% paste(met$variable, met$config), ]
miss$label <- ifelse(paste(miss$variable, miss$config) %in%
                       paste(pr3$variable, pr3$config)[pr3$status == "failed"],
                     "no factible", "no aplica")
lo <- tapply(met$rmse_lo, met$variable, min); hi <- tapply(met$rmse_hi, met$variable, max)
miss$y <- (lo[miss$variable] + hi[miss$variable]) / 2
miss$config <- factor(miss$config, cfg_levels)
p3 <- ggplot(met, aes(config, rmse, colour = config)) +
  geom_pointrange(aes(ymin = rmse_lo, ymax = rmse_hi), size = 0.3) +
  geom_text(data = miss, aes(config, y, label = label), inherit.aes = FALSE,
            angle = 90, size = 2.4, colour = "grey45", fontface = "italic") +
  scale_x_discrete(drop = FALSE) +
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
# Same layout as the ETa figure: rows aligned in the five configuration
# columns, legend titles vertical to the right of the colour bars, one tight
# extent; empty panels say why they are empty. Colour limits per row are the
# P1-P99 of the row (values beyond are saturated), so that the out-of-domain
# extrapolation of the global regression of the wind does not flatten the rest.
fext <- list(x = range(fd$x[!is.na(fd$value)]), y = range(fd$y[!is.na(fd$value)]))
flims <- coord_fixed(1.2, xlim = fext$x, ylim = fext$y, expand = FALSE)
fbar <- function() guide_colourbar(title.position = "right",
                                   title.theme = element_text(angle = 90, hjust = 0.5, size = 6.5),
                                   barheight = unit(2.0, "cm"), barwidth = unit(0.3, "cm"))
ftheme <- theme(plot.margin = margin(1, 2, 1, 2), legend.margin = margin(0, 0, 0, 2),
                strip.text = element_text(size = 7, margin = margin(1, 0, 1, 0)),
                axis.text = element_text(size = 5), panel.spacing.x = unit(1.5, "mm"))
empty_label <- function(v) {
  lab <- data.frame(config = factor(character(), cfg_levels), label = character())
  if (v != "air_temperature") lab <- rbind(lab, data.frame(config = "C1-lap", label = "no aplica\n(solo temperatura)"))
  present <- unique(as.character(fd$config[fd$variable == v]))
  for (cf in setdiff(cfg_levels, c(present, "C1-lap")))
    lab <- rbind(lab, data.frame(config = cf, label = "no factible"))
  lab$config <- factor(lab$config, cfg_levels)
  lab$x <- rep(mean(fext$x), nrow(lab)); lab$y <- rep(mean(fext$y), nrow(lab))
  lab
}
nv <- length(var_lab)
p4 <- lapply(seq_along(var_lab), function(i) {
  v <- names(var_lab)[i]
  d <- fd[fd$variable == v, ]
  lim <- stats::quantile(d$value, c(0.01, 0.99), na.rm = TRUE)
  g <- ggplot(d, aes(x, y, fill = value)) + geom_raster() + aoi_layer +
    geom_label(data = empty_label(v), aes(x, y, label = label), inherit.aes = FALSE,
               size = 2.3, colour = "grey40", fontface = "italic", fill = "white",
               label.size = 0, label.padding = unit(1.5, "pt")) +
    facet_grid(. ~ config, drop = FALSE) +
    scale_fill_gradientn(var_lab[[v]], colours = hcl.colors(11, if (v == "air_temperature")
      "RdYlBu" else if (v == "vapour_pressure") "BrBG" else "Purples", rev = v == "air_temperature"),
      limits = lim, oob = scales::squish, na.value = "white") +
    scale_x_continuous(breaks = c(-72.8, -72.0)) +
    guides(fill = fbar()) + flims + map_theme + ftheme
  if (i < nv) g <- g + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
  if (i > 1) g <- g + theme(strip.text = element_blank(), strip.background = element_blank())
  g
})
save_fig(wrap_plots(p4, ncol = 1), "fig04_forcing_maps", 18, 9.6)

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
# Legend titles vertical next to the colour bars; the difference row keeps the
# five columns of the ETa row (C1, the reference, left empty) so that every
# difference map sits under its ETa map; the height matches the panels.
vbar <- function() guide_colourbar(title.position = "right",
                                   title.theme = element_text(angle = 90, hjust = 0.5, size = 7),
                                   barheight = unit(2.8, "cm"), barwidth = unit(0.3, "cm"))
row_theme <- theme(plot.margin = margin(1, 2, 1, 2), legend.margin = margin(0, 0, 0, 2),
                   strip.text = element_text(size = 7, margin = margin(1, 0, 1, 0)),
                   axis.text = element_text(size = 5),
                   panel.spacing.x = unit(1.5, "mm"))
# Same extent, without padding, in both rows (the scene with valid ETa).
okc <- !is.na(ed$eta)
map_lims <- coord_fixed(1.2, xlim = range(ed$x[okc]) + c(-0.03, 0.03),
                        ylim = range(ed$y[okc]) + c(-0.03, 0.03), expand = FALSE)
# Energy balance: one row per flux with its own colour bar (P1-P99 of the
# row), the same five columns and extent as the ETa figure.
flux_lab <- c(rn = "Rn (W/m²)", g = "G (W/m²)", h = "H (W/m²)", le = "LE (W/m²)")
flux_pal <- list(rn = hcl.colors(11, "YlOrRd", rev = TRUE), g = hcl.colors(11, "Oranges", rev = TRUE),
                 h = hcl.colors(11, "Reds", rev = TRUE), le = hcl.colors(11, "YlGnBu", rev = TRUE))
p5 <- lapply(seq_along(lay), function(i) {
  l <- names(lay)[i]
  lim <- stats::quantile(ed[[l]], c(0.01, 0.99), na.rm = TRUE)
  g <- ggplot(ed, aes(x, y, fill = .data[[l]])) + geom_raster() + aoi_layer +
    facet_grid(. ~ config) +
    scale_fill_gradientn(flux_lab[[l]], colours = flux_pal[[l]], limits = lim,
                         oob = scales::squish, na.value = "white") +
    scale_x_continuous(breaks = c(-72.6, -72.2)) +
    guides(fill = vbar()) + map_lims + map_theme + row_theme
  if (i < length(lay)) g <- g + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
  if (i > 1) g <- g + theme(strip.text = element_blank(), strip.background = element_blank())
  g
})
save_fig(wrap_plots(p5, ncol = 1), "fig05_energy_balance", 18, 15.2)

## Figure 6: ETa maps and differences against C1 ------------------------------------
eta_lim <- stats::quantile(ed$eta, c(0.01, 0.99), na.rm = TRUE)
p6a <- ggplot(ed, aes(x, y, fill = eta)) + geom_raster() + aoi_layer +
  facet_grid(. ~ config) +
  scale_fill_gradientn("ETa (mm/d)", colours = hcl.colors(11, "YlGnBu", rev = TRUE),
                       limits = eta_lim, oob = scales::squish, na.value = "white") +
  guides(fill = vbar()) + map_lims + map_theme + row_theme +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
base <- ed[ed$config == "C1", c("x", "y", "eta")]
dd <- merge(ed[ed$config != "C1", c("x", "y", "config", "eta")], base, by = c("x", "y"),
            suffixes = c("", "_c1"))
dd$diff <- dd$eta - dd$eta_c1
dd$config <- factor(as.character(dd$config), levels(ed$config))
lim <- max(abs(stats::quantile(dd$diff, c(0.01, 0.99), na.rm = TRUE)))
p6b <- ggplot(dd, aes(x, y, fill = diff)) + geom_raster() +
  facet_grid(. ~ config, drop = FALSE,
             labeller = as_labeller(function(x) ifelse(x == "C1", "C1 (referencia)", x))) +
  geom_path(data = aoi_df[rep(seq_len(nrow(aoi_df)), 1), ], aes(x, y, group = interaction(geom, part, hole)),
            inherit.aes = FALSE, linewidth = 0.25, colour = "black") +
  scale_fill_gradientn("ΔETa vs C1 (mm/d)", colours = hcl.colors(11, "RdBu"),
                       limits = c(-lim, lim), oob = scales::squish, na.value = "white") +
  scale_x_continuous(breaks = c(-72.6, -72.2)) +
  guides(fill = vbar()) + map_lims + map_theme + row_theme
save_fig(p6a / p6b + plot_layout(heights = c(1, 1)), "fig06_eta_maps", 18, 8.4)

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
    labs(x = "Entrada sustituida por su campo regionalizado (C3-GWR; viento: C2-IDW); resto = C1",
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
dg <- ifelse(met$variable == "vapour_pressure", 3, 2)
fv <- function(x) mapply(function(v, d) sub("^-(0,0*)$", "\\1", fmt(v, d)), x, dg)
rows <- sprintf("%s & %s & %d & %s [%s; %s] & %s & %s [%s; %s] & %s & %d \\\\",
                ifelse(duplicated(met$variable), "", vl[met$variable]), met$config, met$n_pred,
                fv(met$rmse), fv(met$rmse_lo), fv(met$rmse_hi), fv(met$mae),
                fv(met$bias), fv(met$bias_lo), fv(met$bias_hi), fmt(met$r),
                met$n_failed_folds)
pr <- read("results", "validation", "cv_predictions.csv")
gw <- pr[pr$variable == "wind_speed_2m" & pr$config == "C3-GWR", ]
if (nrow(gw) > 0 && all(gw$status == "failed"))
  rows <- c(rows, sprintf(" & C3-GWR & 0 & \\multicolumn{4}{l}{no factible (sin ancho de banda factible)} & %d \\\\", nrow(gw)))
tex_table("tab_cv_metrics.tex",
          "Variable & Config. & $n$ & RMSE [IC 95\\,\\%] & MAE & Sesgo [IC 95\\,\\%] & $r$ & Fallidas \\\\",
          rows, "llrlrlrr",
          "Validación cruzada espacial anidada de la regionalización a la hora del paso (14:00 UTC, enero--marzo de 2019).",
          "tab:cv",
          notes = c("$n$: predicciones fuera de muestra. Sesgo = predicho $-$ observado. IC: \\emph{bootstrap} de días completos ($B = 2000$).",
                    "C1 no se evalúa en su propia estación. Fallidas: predicciones cuyo pliegue no pudo ajustarse con las estaciones de entrenamiento (p.\\,ej., GWR o regresión global con menos estaciones que parámetros + 3)."),
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
          "tab:metric", notes = "Flujos en \\si{\\watt\\per\\square\\metre}. Las celdas ancla son las mismas en todas las configuraciones salvo C2-OLS, cuyo dominio válido se reduce porque su viento sale del rango físico.",
          size = "\\footnotesize")
message("figures and tables written")

## Figure 9: station density -----------------------------------------------------------
dens <- read("results", "tables", "cv_station_density_summary.csv")
dens$config <- factor(dens$config, cfg_levels)
p9 <- ggplot(dens, aes(n_stations, rmse_mean, colour = config)) +
  geom_line(linewidth = 0.4) + geom_point(size = 1.2) +
  geom_errorbar(aes(ymin = rmse_mean - rmse_sd, ymax = rmse_mean + rmse_sd), width = 1.2,
                linewidth = 0.3, na.rm = TRUE) +
  facet_wrap(~variable, scales = "free_y", labeller = as_labeller(var_lab)) +
  scale_colour_manual(NULL, values = cfg_cols) +
  labs(x = "Estaciones disponibles", y = "RMSE fuera de muestra")
save_fig(p9, "fig09_density", 15, 6.5, data = dens)

## Table: verification of the components used --------------------------------------------
vm <- utils::read.csv(p("config", "verification_map.csv"), stringsAsFactors = FALSE)
tests <- read("results", "diagnostics", "package_tests.csv")
count_tests <- function(files) {
  pats <- trimws(strsplit(files, ";")[[1]])
  sum(vapply(pats, function(pt) {
    rx <- glob2rx(pt)
    sum(grepl(rx, tests$file))
  }, 0))
}
vm$n_tests <- vapply(vm$test_files, count_tests, 0)
esc <- function(x) gsub("_", "\\\\_", gsub("&", "\\\\&", x))
rows <- sprintf("%s & \\texttt{%s} & %s & %s & %d \\\\", esc(vm$component),
                esc(gsub("\"", "", vm$functions)), esc(vm$status), esc(vm$source), vm$n_tests)
writeLines(c("\\begin{tabularx}{\\textwidth}{>{\\raggedright\\arraybackslash}p{3.4cm}>{\\raggedright\\arraybackslash}X>{\\raggedright\\arraybackslash}p{2.9cm}>{\\raggedright\\arraybackslash}p{3.1cm}r}",
             "\\toprule", "Componente & Funciones & Estado & Fuente & Pruebas \\\\", "\\midrule",
             rows, "\\bottomrule", "\\end{tabularx}"),
           file.path(tab_dir, "tab_verification.tex"))
message("figure 9 and verification table written")
