# CEDES 2027 study - common setup sourced by every script.
#
# Run every script from the root of the EarthFlux sources, e.g.
#   Rscript research/cedes2027/scripts/01_download_data.R
# The installed EarthFlux must be the version of this checkout
# (R CMD INSTALL .); the version and commit are recorded in each output.

suppressPackageStartupMessages({
  library(EarthFlux)
  library(terra)
})

study_root <- file.path("research", "cedes2027")
if (!dir.exists(study_root)) {
  stop("Run the scripts from the root of the EarthFlux sources.")
}
p <- function(...) file.path(study_root, ...)

dirs <- c("data/raw", "data/external", "data/processed", "results/maps",
          "results/figures", "results/tables", "results/diagnostics",
          "results/validation")
for (d in dirs) dir.create(p(d), recursive = TRUE, showWarnings = FALSE)

# Large downloads are cached outside git (see .gitignore); their checksums
# are recorded in data/raw/manifest.csv.
cache_dir <- Sys.getenv("CEDES_CACHE", p("data", "raw", "cache"))
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- jsonlite::read_json(p("config", "study.json"), simplifyVector = TRUE)
set.seed(cfg$seed)

study_crs <- cfg$crs_projected # metres, used by every distance computation

git_commit <- function() {
  out <- tryCatch(system("git rev-parse HEAD", intern = TRUE),
                  error = function(e) NA_character_)
  if (length(out) == 0) NA_character_ else out
}

session_record <- function() {
  list(
    date_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    r = R.version.string,
    earthflux = as.character(utils::packageVersion("EarthFlux")),
    terra = as.character(utils::packageVersion("terra")),
    gdal = terra::gdal(),
    commit = git_commit(),
    seed = cfg$seed
  )
}

write_csv <- function(x, file) {
  utils::write.csv(x, file, row.names = FALSE, na = "")
  invisible(file)
}

# Download a file once into the cache and return its path.
cached_download <- function(url, dest) {
  if (!file.exists(dest) || file.size(dest) == 0) {
    status <- utils::download.file(url, dest, mode = "wb", quiet = TRUE)
    if (status != 0) stop("Download failed: ", url)
  }
  dest
}

manifest_add <- function(file, url, provider, licence, note = "") {
  mf <- p("data", "raw", "manifest.csv")
  row <- data.frame(
    file = basename(file), url = url, provider = provider,
    licence = licence, bytes = file.size(file),
    md5 = unname(tools::md5sum(file)),
    accessed_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    note = note, stringsAsFactors = FALSE
  )
  if (file.exists(mf)) {
    old <- utils::read.csv(mf, stringsAsFactors = FALSE)
    old <- old[old$file != row$file, , drop = FALSE]
    row <- rbind(old, row)
  }
  write_csv(row, mf)
}
