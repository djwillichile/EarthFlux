# Builds the MODIS example scene of EarthFlux: inst/extdata/modis-example/
#
# What it does (dev/specs/modis-products.md section 12; decision MP-12):
#   1. searches NASA CMR for the collection 6.1 granules of tile h12v12 that
#      cover `scene_date`: MOD11A1 (LST, QC, view time) and MCD43A3 (albedo)
#      of that day, and the MOD13A2 (NDVI, 16 days) and MCD15A2H (LAI,
#      8 days) composites whose period contains it;
#   2. downloads them from the LP DAAC cloud archive with a NASA Earthdata
#      Login token read ONLY from the environment variable EARTHDATA_TOKEN;
#   3. assembles the surface state with modis_surface_state() on the area of
#      interest of the Cauquenes province (inst/extdata/
#      cauquenes-province.gpkg; data-raw/cauquenes-province.R), with the
#      explicit options below;
#   4. masks the cells outside the province and writes the physical layers
#      and the flag words as compressed GeoTIFF (target: < 500 KB in all),
#      plus the provenance (CSV and YAML) and the bit table of the flag
#      words.
#
# What the author must provide:
#   * `scene_date` below: a clear-sky summer day before 2020 (before the
#     orbital drift of Terra), chosen with the data (MP-12). The script
#     stops while it is NA.
#   * EARTHDATA_TOKEN: a NASA Earthdata Login user token (generated at
#     https://urs.earthdata.nasa.gov, "Generate Token"), in the environment:
#       EARTHDATA_TOKEN=... Rscript data-raw/modis-example.R
#     The token is never written to disk, printed, logged or saved: it only
#     lives in the HTTP header of the download requests. Do not put it in
#     this file, in .Renviron of the repository or in the shell history of a
#     shared machine.
#   * A build of terra with the GDAL HDF4 driver (checked).
#
# Downloads are cached in data-raw/private/modis/ (ignored by git); the full
# HDF files are never versioned (DEVELOPMENT.md section 6). This directory
# (data-raw/) is excluded from the package tarball (.Rbuildignore).
#
# Run from the root of the EarthFlux sources (needs pkgload and jsonlite).

## Parameters -------------------------------------------------------------------

# UTC date of the scene (MP-12): clear-sky summer day before 2020, Terra.
# To be chosen with the data, e.g. as.Date("2019-01-15") after checking the
# MOD11A1 QC over the province.
scene_date <- as.Date(NA)

tile <- "h12v12"   # Cauquenes province lies inside this tile
collection <- "061" # MP-13

# Explicit choices of the assembly (no defaults in the package; each one is
# recorded in the provenance). Provisional recommendations of
# dev/specs/modis-products.md section 15 where they exist.
surface_options <- list(
  lst_product = "MOD11A1",                 # MP-01, MP-02: Terra
  albedo_method = "white_sky",             # MP-03: A2 (A1 needs a diffuse
  diffuse_fraction = NULL,                 #   fraction model, T-11)
  emissivity_method = "lai_empirical",     # MP-04: E3, the only option
  ndvi_source = "MOD13A2",                 # MP-05
  composite_method = c(albedo = "same_day",        # MP-07: T5
                       ndvi = "period_pixel_lag",  # T2
                       lai = "period"),            # T1 (no per-pixel day)
  resampling_method = "mean",              # MP-08
  min_valid_fraction = 1,                  # threshold TODO: only cells with
                                           #   every 500 m sub-cell valid
  qa_policy = "flag"                       # MP-09 (provisional)
)

size_limit <- 500 * 1024 # bytes, all files of the example together

## Checks (before any network access) -------------------------------------------

token_present <- nzchar(Sys.getenv("EARTHDATA_TOKEN", unset = ""))
if (!token_present) {
  stop("The environment variable EARTHDATA_TOKEN is not set. Generate a ",
       "NASA Earthdata Login token and run:\n",
       "  EARTHDATA_TOKEN=<token> Rscript data-raw/modis-example.R",
       call. = FALSE)
}
if (is.na(scene_date)) {
  stop("Set `scene_date` at the top of data-raw/modis-example.R: a ",
       "clear-sky summer day before 2020 (decision MP-12).", call. = FALSE)
}
if (scene_date >= as.Date("2020-01-01") ||
    !as.integer(format(scene_date, "%m")) %in% c(12L, 1L, 2L, 3L)) {
  stop("`scene_date` must be a southern summer day (December-March) ",
       "before 2020 (decision MP-12).", call. = FALSE)
}
for (pkg in c("pkgload", "jsonlite")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package %s is needed by this script.", pkg), call. = FALSE)
  }
}
pkgload::load_all(".", quiet = TRUE)
if (!modis_has_hdf4()) {
  stop("terra has no GDAL HDF4 driver in this installation.", call. = FALSE)
}

cache <- file.path("data-raw", "private", "modis")
out_dir <- file.path("inst", "extdata", "modis-example")
dir.create(cache, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

## 1. Granule search (NASA CMR) ---------------------------------------------------

cmr_url <- "https://cmr.earthdata.nasa.gov/search/granules.json"

# One CMR granule search. `name` is a granule name pattern (`*` wildcard);
# `temporal` (TRUE) restricts to granules whose time range contains the date.
cmr_search <- function(short_name, name, temporal) {
  q <- c(
    short_name = short_name,
    version = collection,
    provider = "LPCLOUD",
    "readable_granule_name[]" = name,
    "options[readable_granule_name][pattern]" = "true",
    page_size = "50"
  )
  if (temporal) {
    q["temporal"] <- sprintf("%sT00:00:00Z,%sT23:59:59Z", scene_date,
                             scene_date)
  }
  url <- paste0(cmr_url, "?", paste(
    vapply(names(q), utils::URLencode, character(1), reserved = TRUE),
    vapply(q, utils::URLencode, character(1), reserved = TRUE),
    sep = "=", collapse = "&"
  ))
  entries <- jsonlite::fromJSON(url, simplifyVector = FALSE)$feed$entry
  rows <- lapply(entries, function(e) {
    hrefs <- vapply(e$links, function(l) {
      if (!is.null(l$rel) && grepl("/data#$", l$rel) &&
          !is.null(l$href) && startsWith(l$href, "https://") &&
          grepl("\\.hdf$", l$href)) l$href else NA_character_
    }, character(1))
    hrefs <- unique(stats::na.omit(hrefs))
    data.frame(
      short_name = short_name,
      concept_id = e$id,
      granule_ur = e$title,
      producer_granule_id = if (is.null(e$producer_granule_id)) NA else
        e$producer_granule_id,
      time_start = e$time_start,
      time_end = e$time_end,
      url = if (length(hrefs) == 1L) hrefs else NA_character_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

# One granule per product: the file of the day for MOD11A1 and MCD43A3 (the
# MCD43A3 file of day D is weighted to D, section 5.6), the composite whose
# period contains the day for MOD13A2 and MCD15A2H.
doy_tag <- format(scene_date, "A%Y%j")
search <- list(
  lst = list("MOD11A1", sprintf("MOD11A1.%s.%s.%s.*", doy_tag, tile,
                                collection), FALSE),
  albedo = list("MCD43A3", sprintf("MCD43A3.%s.%s.%s.*", doy_tag, tile,
                                   collection), FALSE),
  ndvi = list("MOD13A2", sprintf("MOD13A2.*.%s.%s.*", tile, collection),
              TRUE),
  lai = list("MCD15A2H", sprintf("MCD15A2H.*.%s.%s.*", tile, collection),
             TRUE)
)
granules <- do.call(rbind, lapply(names(search), function(role) {
  s <- search[[role]]
  g <- cmr_search(s[[1]], s[[2]], s[[3]])
  if (is.null(g) || nrow(g) != 1L || is.na(g$url)) {
    stop(sprintf("CMR returned %d granule(s) of %s for %s (one expected).",
                 if (is.null(g)) 0L else nrow(g), s[[1]], scene_date),
         call. = FALSE)
  }
  cbind(role = role, g)
}))
granules$file <- basename(granules$url)
# Composite period from the granule metadata (RangeBeginningDate and
# RangeEndingDate): the specification does not state the relation between
# the date in the file name and the period of MOD13/MCD15 composites.
granules$period_start <- as.Date(substr(granules$time_start, 1L, 10L))
granules$period_end <- as.Date(substr(granules$time_end, 1L, 10L))
print(granules[, c("role", "file", "period_start", "period_end")])

## 2. Download (LP DAAC, Earthdata Login token) ----------------------------------

# The token is read from the environment inside this function only and
# passed as an HTTP header; it is not returned, printed or stored.
download_granule <- function(url, dest) {
  if (file.exists(dest) && file.size(dest) > 0) {
    return(invisible(dest))
  }
  tmp <- paste0(dest, ".part")
  on.exit(unlink(tmp), add = TRUE)
  status <- tryCatch(
    utils::download.file(
      url, tmp, method = "libcurl", mode = "wb", quiet = TRUE,
      headers = c(Authorization = paste(
        "Bearer", Sys.getenv("EARTHDATA_TOKEN")
      ))
    ),
    error = function(e) 1L
  )
  # HDF4 files start with the magic number 0e 03 13 01; a login page or an
  # error document does not.
  magic <- if (file.exists(tmp)) readBin(tmp, "raw", n = 4L) else raw(0)
  if (!identical(status, 0L) ||
      !identical(magic, as.raw(c(0x0e, 0x03, 0x13, 0x01)))) {
    stop(sprintf(paste0("Download of %s failed (check that EARTHDATA_TOKEN ",
                        "is valid and not expired)."), basename(url)),
         call. = FALSE)
  }
  file.rename(tmp, dest)
  invisible(dest)
}
granules$path <- file.path(cache, granules$file)
for (i in seq_len(nrow(granules))) {
  download_granule(granules$url[i], granules$path[i])
}
download_date <- Sys.Date()

## 3. Area of interest -----------------------------------------------------------------

province <- aoi_cauquenes()

## 4. Surface state ------------------------------------------------------------------------

src <- function(role, period = FALSE) {
  i <- match(role, granules$role)
  modis_source(granules$path[i],
               period = if (period) c(granules$period_start[i],
                                      granules$period_end[i]))
}
files <- list(lst = src("lst"), albedo = src("albedo"),
              ndvi = src("ndvi", period = TRUE),
              lai = src("lai", period = TRUE))
st <- modis_surface_state(files, aoi = province, options = surface_options)

## 5. Mask outside the province and write -------------------------------------------

inside <- !is.na(terra::rasterize(terra::project(province,
                                                  terra::crs(st$lst)),
                                   st$lst, touches = TRUE))
outside_na <- function(r) terra::mask(r, inside, maskvalues = FALSE)
gtiff <- function(r, name, datatype, predictor) {
  f <- file.path(out_dir, name)
  terra::writeRaster(
    outside_na(r), f, overwrite = TRUE, datatype = datatype,
    gdal = c("COMPRESS=DEFLATE", "ZLEVEL=9", paste0("PREDICTOR=", predictor))
  )
  f
}
written <- c(
  gtiff(st$lst, "lst.tif", "FLT4S", 3),
  gtiff(st$albedo, "albedo.tif", "FLT4S", 3),
  gtiff(st$ndvi, "ndvi.tif", "FLT4S", 3),
  gtiff(st$lai, "lai.tif", "FLT4S", 3),
  gtiff(st$emissivity, "emissivity.tif", "FLT4S", 3),
  gtiff(st$overpass_time$doy, "overpass_doy.tif", "INT2S", 2),
  gtiff(st$overpass_time$utc_hour, "overpass_utc_hour.tif", "FLT4S", 3),
  # flag words: NA outside the province = not evaluated (flags.md 6.3)
  gtiff(st$qa$flag_word, "flags.tif", "INT4S", 2),
  gtiff(st$qa$valid_fraction, "valid_fraction.tif", "FLT4S", 3),
  gtiff(st$qa$composite$ndvi$lag_days, "ndvi_lag_days.tif", "INT2S", 2)
)

# Bit table of the flag words (travels with the files, flags.md 6.3).
bits_csv <- file.path(out_dir, "flag_bits.csv")
utils::write.csv(st$qa$flag_bits, bits_csv, row.names = FALSE)

## 6. Provenance ---------------------------------------------------------------------

p <- st$provenance
gr <- merge(p$granules,
            granules[, c("role", "concept_id", "granule_ur", "time_start",
                         "time_end", "url")],
            by = "role", sort = FALSE)
gr$download_date <- format(download_date)
prov_csv <- file.path(out_dir, "provenance.csv")
utils::write.csv(gr, prov_csv, row.names = FALSE)

yaml_scalar <- function(x) {
  x <- as.character(x)
  ifelse(is.na(x), "null", paste0("\"", gsub("\"", "\\\\\"", x), "\""))
}
methods <- p$methods
yml <- c(
  "# Provenance of the MODIS example scene (built by data-raw/modis-example.R)",
  "dataset: EarthFlux MODIS example scene, Cauquenes province (Maule, Chile)",
  "synthetic: false",
  sprintf("scene_date_utc: %s", yaml_scalar(format(scene_date))),
  sprintf("tile: %s", yaml_scalar(tile)),
  sprintf("collection: %s", yaml_scalar(collection)),
  sprintf("download_date: %s", yaml_scalar(format(download_date))),
  "download_source: NASA LP DAAC cloud archive (LPCLOUD), found with NASA CMR",
  "area_of_interest: inst/extdata/cauquenes-province.gpkg (DPA 2023, SUBDERE; see cauquenes-province.yml); cells outside the province are NA",
  "grid: MODIS sinusoidal, 1 km cells of the MOD11A1 file (MP-08)",
  "granules:",
  unlist(lapply(seq_len(nrow(gr)), function(i) c(
    sprintf("  - role: %s", yaml_scalar(gr$role[i])),
    sprintf("    product: %s", yaml_scalar(gr$product[i])),
    sprintf("    local_granule_id: %s", yaml_scalar(gr$file[i])),
    sprintf("    cmr_concept_id: %s", yaml_scalar(gr$concept_id[i])),
    sprintf("    doi: %s", yaml_scalar(gr$doi[i])),
    sprintf("    doi_status: %s", yaml_scalar(gr$doi_status[i])),
    sprintf("    data_day: %s", yaml_scalar(gr$date[i])),
    sprintf("    time_start: %s", yaml_scalar(gr$time_start[i])),
    sprintf("    time_end: %s", yaml_scalar(gr$time_end[i])),
    sprintf("    production: %s", yaml_scalar(gr$production[i]))
  ))),
  "options:",
  sprintf("  %s: %s", c("lst_product", "albedo_method", "emissivity_method",
                         "ndvi_source", "qa_policy"),
          yaml_scalar(unlist(methods[c("lst_product", "albedo_method",
                                       "emissivity_method", "ndvi_source",
                                       "qa_policy")]))),
  sprintf("  diffuse_fraction: %s",
          yaml_scalar(if (is.null(methods$diffuse_fraction)) NA else
            methods$diffuse_fraction)),
  sprintf("  composite_method_%s: %s", names(methods$composite_method),
          yaml_scalar(methods$composite_method)),
  sprintf("  resampling_method_%s: %s", names(methods$resampling_method),
          yaml_scalar(methods$resampling_method)),
  sprintf("  min_valid_fraction: %s", methods$min_valid_fraction),
  "status:",
  sprintf("  %s: %s", names(p$status), yaml_scalar(p$status)),
  "versions:",
  sprintf("  %s: %s", names(p$versions), yaml_scalar(unlist(p$versions))),
  "layers:",
  "  lst.tif: land surface temperature [K]",
  "  albedo.tif: broadband shortwave albedo [-]",
  "  ndvi.tif: NDVI [-]",
  "  lai.tif: leaf area index [m2 m-2]",
  "  emissivity.tif: broadband surface emissivity [-]",
  "  overpass_doy.tif: day of year of the UTC date [-]",
  "  overpass_utc_hour.tif: UTC hour of the overpass [h]",
  "  flags.tif: flag words (INT4S), one layer per output; bits in flag_bits.csv",
  "  valid_fraction.tif: fraction of valid 500 m sub-cells of each aggregated input [-]",
  "  ndvi_lag_days.tif: LST date minus composite day of the NDVI pixel [days]",
  "license: MODIS data are shared openly without restriction (EOSDIS Data Use and Citation Guidance); citation requirements for redistribution TODO (modis-products.md section 16, item 20)"
)
prov_yml <- file.path(out_dir, "provenance.yml")
writeLines(yml, prov_yml)

## 7. Size check -----------------------------------------------------------------------

all_files <- c(written, bits_csv, prov_csv, prov_yml)
total <- sum(file.size(all_files))
message(sprintf("Example scene: %d files, %.1f KB.", length(all_files),
                total / 1024))
if (total > size_limit) {
  stop(sprintf("The example scene is %.1f KB, above the %.0f KB target.",
               total / 1024, size_limit / 1024), call. = FALSE)
}
