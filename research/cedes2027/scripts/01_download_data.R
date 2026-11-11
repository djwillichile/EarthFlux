# Download the public inputs of the study into the cache and record them in
# data/raw/manifest.csv (provider, URL, licence, size, MD5, access time).
# See docs/data_sources.md. The DMC SACLIM sheets are downloaded by
# scripts/01_download_dmc.py (called below for January-March 2019).

source(file.path("research", "cedes2027", "scripts", "00_setup.R"))

dir.create(file.path(cache_dir, "isd"), showWarnings = FALSE)
dir.create(file.path(cache_dir, "dem"), showWarnings = FALSE)
dir.create(file.path(cache_dir, "ne"), showWarnings = FALSE)

## NOAA ISD global-hourly 2019 (airports of the region) --------------------------
isd_ids <- c("85586099999", "85620099999", "85629099999", "85631099999",
             "85672099999", "85682099999", "85703099999", "85196099999")
for (id in isd_ids) {
  url <- sprintf("https://noaa-global-hourly-pds.s3.amazonaws.com/2019/%s.csv", id)
  dest <- file.path(cache_dir, "isd", paste0(id, ".csv"))
  ok <- tryCatch({cached_download(url, dest); TRUE}, error = function(e) FALSE)
  if (ok) manifest_add(dest, url, "NOAA NCEI ISD (AWS Open Data)", "NOAA open data")
  else message("not available: ", url) # e.g. Talca 856200 has no 2019 file
}

## Copernicus DEM GLO-90 -----------------------------------------------------------
for (la in 34:39) for (lo in sprintf("%03d", 71:74)) {
  n <- sprintf("Copernicus_DSM_COG_30_S%02d_00_W%s_00_DEM", la, lo)
  url <- sprintf("https://copernicus-dem-90m.s3.amazonaws.com/%s/%s.tif", n, n)
  dest <- file.path(cache_dir, "dem", paste0(n, ".tif"))
  ok <- tryCatch({cached_download(url, dest); TRUE}, error = function(e) FALSE)
  if (ok) manifest_add(dest, url, "ESA Copernicus DEM GLO-90 (AWS Open Data)",
                       "Copernicus DEM GLO-90 licence (free, attribution)")
  else unlink(dest) # all-ocean tiles do not exist
}

## Natural Earth land ----------------------------------------------------------------
url <- "https://naciscdn.org/naturalearth/10m/physical/ne_10m_land.zip"
z <- cached_download(url, file.path(cache_dir, "ne", "ne_10m_land.zip"))
utils::unzip(z, exdir = file.path(cache_dir, "ne"))
manifest_add(z, url, "Natural Earth", "Public domain")

## DMC SACLIM (DMC, INIA, FDF stations) ------------------------------------------------
dmc_dir <- file.path(cache_dir, "dmc")
if (!file.exists(file.path(dmc_dir, "dmc_stations_box.csv"))) {
  stop("dmc_stations_box.csv is missing: it lists the 67 SACLIM stations of the ",
       "box (station finder of product RE3017); see docs/data_sources.md.")
}
for (m in 1:3) {
  f <- file.path(dmc_dir, sprintf("dmc_RE1022_hourly_2019%02d.csv", m))
  if (!file.exists(f)) {
    system2("python3", c("-I", p("scripts", "01_download_dmc.py"), "2019", m),
            env = paste0("CEDES_DMC_DIR=", dmc_dir))
  }
}
for (f in list.files(dmc_dir, pattern = "\\.csv$", full.names = TRUE)) {
  manifest_add(f, "https://climatologia.meteochile.gob.cl/application/ (RE1022, RE1019, RE3017)",
               "Direccion Meteorologica de Chile, SACLIM",
               "Public access and use; cite DMC as source")
}
print(utils::read.csv(p("data", "raw", "manifest.csv"))[, c("file", "bytes", "md5")])
