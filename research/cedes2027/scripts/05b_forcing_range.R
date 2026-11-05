# Diagnostic of experiment M: share of the scene cells whose regionalized
# forcing at the overpass lies outside the range observed at the stations at
# that hour (extrapolation in unsampled terrain). Low cross-validation error
# at the stations does not guarantee realistic fields between them.

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))

h <- utils::read.csv(p("data", "processed", "stations_hourly.csv"), stringsAsFactors = FALSE)
x <- h[h$time == paste0(cfg$scene_date, "T14:00:00Z"), ]
rng <- list(ta = range(x$air_temperature, na.rm = TRUE),
            ea = range(x$vapour_pressure, na.rm = TRUE))
cfgs <- c("C1", "C1-lap", "C2-OLS", "C2-IDW", "C3-GWR")
out <- do.call(rbind, lapply(cfgs, function(cf) {
  r <- terra::rast(p("results", "maps", sprintf("metric_%s.tif", cf)))
  do.call(rbind, lapply(c("ta", "ea"), function(v) {
    val <- terra::values(r[[paste0("forcing_", v)]], mat = FALSE)
    val <- val[!is.na(val) & !is.na(terra::values(r[["eta"]], mat = FALSE))]
    data.frame(config = cf, variable = v, obs_min = rng[[v]][1], obs_max = rng[[v]][2],
               field_min = min(val), field_max = max(val),
               share_above = mean(val > rng[[v]][2]), share_below = mean(val < rng[[v]][1]),
               n_cells = length(val))
  }))
}))
write_csv(out, p("results", "tables", "forcing_range_check.csv"))
print(out, digits = 3)
