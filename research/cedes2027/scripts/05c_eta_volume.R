# Daily ETa expressed as a volume over the processed cells of the scene.
#
# The MODIS sinusoidal grid is equal-area, so every cell has the same area
# (res^2 m2). Volume [m3 d-1] = sum(ETa [mm d-1] * 1e-3 m mm-1 * area [m2]).
# The differences between configurations are DISAGREEMENTS BETWEEN MODELS on
# the same cells and day, not water saved or lost: ETa accuracy is not
# validated in this study (docs/limitations.md).
#
# Output: results/tables/eta_volume.csv

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))

cfgs <- c("C1", "C1-lap", "C2-IDW", "C3-GWR")
r <- lapply(cfgs, function(cf) terra::rast(p("results", "maps", sprintf("metric_%s.tif", cf)))[["eta"]])
names(r) <- cfgs
cell_area <- prod(terra::res(r[[1]]))                       # m2 (equal-area grid)
v <- sapply(r, function(x) terra::values(x, mat = FALSE))
common <- stats::complete.cases(v)                           # cells valid in every run
vol <- colSums(v[common, , drop = FALSE]) * 1e-3 * cell_area # m3 d-1
out <- data.frame(
  config = cfgs, n_cells = sum(common), cell_area_m2 = cell_area,
  area_km2 = sum(common) * cell_area / 1e6,
  volume_m3_d = unname(vol),
  diff_vs_C1_m3_d = unname(vol - vol[["C1"]]),
  diff_vs_C1_pct = unname(100 * (vol - vol[["C1"]]) / vol[["C1"]])
)
write_csv(out, p("results", "tables", "eta_volume.csv"))
print(out, digits = 4)
