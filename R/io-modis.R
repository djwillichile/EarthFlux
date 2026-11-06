# I/O: MODIS products -------------------------------------------------------------
#
# Purpose: the internal product table (the single source of MODIS product
#   facts), file name parsing, reading of raw digital numbers (DN) from the
#   official HDF4/HDF-EOS files or from converted rasters, tile mosaics and
#   the scaling of DN into physical values.
#
# Specification: dev/specs/modis-products.md sections 3-5 (collection,
#   sinusoidal grid, product sheets), 10 (QA policy), 11 (I/O) and 13.1.
#   Implementation status and decisions: the status block at the top of that
#   document and dev/DECISIONS.md section 1.4 (M4-01 ...).
#
# Implemented (all internal, `modis_` prefix, dev/specs/modis-products.md
#   section 13):
#   modis_sinusoidal_grid()      constants of the global sinusoidal grid
#   modis_tile_extent()          extent of tile hXXvYY (DERIVADA)
#   modis_product_table()        every supported layer of every product
#   modis_product_spec()         the rows of one product and collection
#   modis_product_doi()          data set DOI of each product (provenance)
#   modis_layer_spec()           the row of one layer
#   modis_parse_filename()       product, UTC date, tile, collection, ...
#   modis_has_hdf4()             is the GDAL HDF4 driver available?
#   modis_list_layers()          subdatasets of an HDF4 file
#   modis_read_raw()             raw DN of HDF4 layers, cropped to an AOI
#   modis_read_converted()       DN of a converted raster (GeoTIFF, ...)
#   modis_mosaic_tiles()         mosaic of tiles of one product and date
#   modis_apply_scale()          DN -> physical value + fill/range masks
#   modis_values(), modis_as_raster()  SpatRaster <-> numeric adapters
#   QA decoding, the surface flags and the per-variable converters live in
#   R/modis-qa.R; the area of interest in R/io-aoi.R.
#
# Rules:
# - Product facts (scale, offset, conversion convention, valid range, fill,
#   data type, QA layout) come only from rows that the specification marks
#   VERIFICADA (or DERIVADA, computed here from VERIFICADA values), each row
#   with its citation. Layers whose facts are TODO are not in the table and
#   are refused with `earthflux_modis_unsupported` (collection 6.1 only,
#   decision MP-13).
# - GDAL/terra automatic scaling is never used (MP-11): layers are read
#   with `raw = TRUE`, the DN are checked to be whole numbers inside the
#   range of their data type, and scale and offset are applied from the
#   table. A file whose scale (or zero offset) contradicts the table is
#   refused.
# - No downloads and no credentials (section 11.5): only local files.
#
# Condition classes introduced here (all inherit `earthflux_error`; see
#   dev/ARCHITECTURE.md section 3.3):
#   earthflux_modis_unsupported   product, collection or layer without a
#                                 verified sheet (+ earthflux_input_error)
#   earthflux_modis_filename_error  file name outside the MODIS convention
#                                 (+ earthflux_input_error)
#   earthflux_modis_driver_error  GDAL driver HDF4 not available
#   earthflux_modis_layer_error   layer missing or ambiguous in a file
#                                 (+ earthflux_input_error)
#   earthflux_modis_dn_error      values are not raw DN of the declared type
#                                 (e.g. already scaled) (+ input_error)
#   earthflux_modis_metadata_error  file metadata (scale, offset, NoData)
#                                 contradict the product table (+ input_error)
#   earthflux_modis_grid_error    CRS, resolution, tile extent, AOI overlap
#                                 or mosaic geometry inconsistent
#                                 (+ earthflux_input_error)

# Sinusoidal grid -------------------------------------------------------------

#' Constants of the MODIS global sinusoidal grid
#'
#' Facts of dev/specs/modis-products.md section 4: projection on a sphere of
#' radius 6371007.181 m (`VERIFICADA`, D6 p. 4-5; D13), upper-left corner of
#' the global grid (`VERIFICADA`, D6 p. 4), 500 m cell of 463.312716525 m and
#' 2400 x 2400 cells per tile (`VERIFICADA`, D6 p. 4; D5 p. 6, Tabla 3), 36 x
#' 18 tiles indexed from (h0, v0) at the upper left (`VERIFICADA`, D13; D5
#' Tabla 3). The 1 km cell (2 x 463.312716525 m) and the tile side (2400 x
#' 463.312716525 m) are `DERIVADA`.
#'
#' @return A list with `crs` (PROJ string of D6), `ulx`, `uly` \[m\],
#'   `cell_500m`, `cell_1km`, `tile_size` \[m\], `n_h`, `n_v` and `status`.
#' @noRd
modis_sinusoidal_grid <- function() {
  cell_500m <- 463.312716525
  list(
    crs = "+proj=sinu +a=6371007.181 +b=6371007.181 +units=m",
    ulx = -20015109.354,
    uly = 10007554.677,
    cell_500m = cell_500m,
    cell_1km = 2 * cell_500m,
    tile_size = 2400 * cell_500m,
    n_h = 36L,
    n_v = 18L,
    status = c(crs = "VERIFICADA", ulx = "VERIFICADA", uly = "VERIFICADA",
               cell_500m = "VERIFICADA", cell_1km = "DERIVADA",
               tile_size = "DERIVADA")
  )
}

#' Extent of a MODIS sinusoidal tile
#'
#' `DERIVADA` from the constants of `modis_sinusoidal_grid()`:
#' xmin = ULX + h * side, ymax = ULY - v * side.
#'
#' @param h,v Integer tile indices (0-35 and 0-17).
#' @return A `SpatExtent` in the sinusoidal CRS.
#' @noRd
modis_tile_extent <- function(h, v) {
  g <- modis_sinusoidal_grid()
  check_scalar(h, "h", lower = 0, upper = g$n_h - 1L, whole = TRUE)
  check_scalar(v, "v", lower = 0, upper = g$n_v - 1L, whole = TRUE)
  xmin <- g$ulx + h * g$tile_size
  ymax <- g$uly - v * g$tile_size
  terra::ext(xmin, xmin + g$tile_size, ymax - g$tile_size, ymax)
}

# Product table -----------------------------------------------------------------

#' Supported MODIS collections
#'
#' Collection 6.1 (version 061) only: the product sheets of
#' dev/specs/modis-products.md section 5 are C6.1 (section 3, `VERIFICADA`;
#' decision MP-13).
#'
#' @return Character vector.
#' @noRd
modis_supported_collections <- function() {
  "061"
}

#' Build rows of the product table
#'
#' @param product Character vector of short names sharing the rows.
#' @param layer Character vector of SDS names (canonical, as in the sheet).
#' @param ... Columns of the table (length 1 or `length(layer)`).
#' @return A data frame with one row per product and layer.
#' @noRd
mp_rows <- function(product, layer, grid, resolution, cells_per_tile,
                    data_type, kind, conversion, scale, offset, valid_min,
                    valid_max, fill, unit, source, qa_table = NA_character_,
                    sds_alternatives = "", special_min = NA_real_,
                    special_max = NA_real_, special_flag = NA_character_,
                    note = "") {
  base <- data.frame(
    layer = layer,
    sds_alternatives = sds_alternatives,
    grid = grid,
    resolution = resolution,
    cells_per_tile = as.integer(cells_per_tile),
    data_type = data_type,
    kind = kind,
    conversion = conversion,
    scale = as.numeric(scale),
    offset = as.numeric(offset),
    valid_min = as.numeric(valid_min),
    valid_max = as.numeric(valid_max),
    fill = as.numeric(fill),
    special_min = as.numeric(special_min),
    special_max = as.numeric(special_max),
    special_flag = special_flag,
    unit = unit,
    qa_table = qa_table,
    status = "VERIFICADA",
    source = source,
    note = note,
    stringsAsFactors = FALSE
  )
  out <- do.call(rbind, lapply(product, function(p) {
    cbind(data.frame(product = p, collection = "061",
                     stringsAsFactors = FALSE), base)
  }))
  rownames(out) <- NULL
  out
}

#' MODIS product table (all supported products and layers)
#'
#' The single source of MODIS product constants (dev/specs/modis-products.md
#' section 13.1). Built only from rows that section 5 marks `VERIFICADA`,
#' each with its citation `[document, PDF page, table]` (documents D1-D12 of
#' section 2.1); the physical range columns are `DERIVADA`. Layers whose
#' facts are `TODO` (e.g. the night LST layers of MOD11A1, given only as
#' "equivalents", `Fpar_500m`, `LaiStdDev_500m`, MCD43A2 layers other than
#' `Snow_BRDF_Albedo`) are not included.
#'
#' Columns: `product`, `collection`, `layer` (SDS name of the sheet),
#' `sds_alternatives` (other official spellings, `|`-separated; resolved by
#' exact match against the file), `grid` (HDF-EOS grid, `NA` when not
#' documented), `resolution`, `cells_per_tile` (`NA` when `TODO`),
#' `data_type`, `kind` (`"value"`, `"qa_bits"`, `"qa_code"`, `"class"`,
#' `"doy"`, `"count"`), `conversion` (`"scale_offset"`: DN * scale + offset,
#' D10; `"offset_scale"`: (DN - offset) * scale, D8/D9; `"scale_only"`:
#' DN * scale, sheets that declare a scale and no offset; `"none"`),
#' `scale`, `offset`, `valid_min`, `valid_max` (`NA` when the valid range
#' must not be used, discrepancies d6/d6b), `fill` (`NA`: no fill value),
#' `special_min`, `special_max`, `special_flag` (documented class codes
#' outside the valid range, e.g. LAI 249-254), `unit`, `qa_table` (key of
#' `modis_qa_layouts()`), `status`, `source`, `note`, `physical_min`,
#' `physical_max` (`DERIVADA`).
#'
#' The table is static (built from code): `modis_product_table()` builds it
#' once per session and then returns the cached copy (as
#' `ef_flag_registry()` does; building it costs about 0.1 s and the readers
#' and converters look it up for every layer); `modis_product_table_build()`
#' always rebuilds it.
#'
#' @return A data frame.
#' @noRd
modis_product_table <- function() {
  tab <- modis_table_cache$table
  if (is.null(tab)) {
    tab <- modis_product_table_build()
    assign("table", tab, envir = modis_table_cache)
  }
  tab
}

#' Cache of the MODIS product table
#' @noRd
modis_table_cache <- new.env(parent = emptyenv())

#' @rdname modis_product_table
#' @noRd
modis_product_table_build <- function() {
  lst <- c("MOD11A1", "MYD11A1")
  src11 <- "D1 p. 17, Tabla 9; D10; D12 (modis-products.md 5.1 b)"
  g11 <- "MODIS_Grid_Daily_1km_LST"
  mod11 <- rbind(
    mp_rows(lst, "LST_Day_1km", g11, "1km", 1200, "uint16", "value",
            "scale_offset", 0.02, 0, 7500, 65535, 0, "K", src11),
    mp_rows(lst, "QC_Day", g11, "1km", 1200, "uint8", "qa_bits", "none",
            NA, NA, 0, 255, NA, "bits",
            "D1 p. 17, Tabla 9; D1 p. 21, Tabla 13; D10 (modis-products.md 5.1 b-c)",
            qa_table = "MOD11_QC",
            note = "No _FillValue (D1 p. 16; D10); read together with LST."),
    mp_rows(lst, "Day_view_time", g11, "1km", 1200, "uint8", "value",
            "scale_offset", 0.1, 0, 0, 240, 255, "h", src11,
            note = "Local solar time: UTC + longitude / 15 (D1 p. 16)."),
    mp_rows(lst, "Day_view_angl", g11, "1km", 1200, "uint8", "value",
            "scale_offset", 1, -65, 0, 130, 255, "degree", src11,
            note = "Negative: cell observed from the east (D1 p. 16-17)."),
    mp_rows(lst, c("Emis_31", "Emis_32"), g11, "1km", 1200, "uint8",
            "value", "scale_offset", 0.002, 0.49, 1, 255, 0, "1", src11),
    mp_rows(lst, "Clear_day_cov", g11, "1km", 1200, "uint16", "value",
            "scale_offset", 0.0005, 0, 1, 65535, 0, "1", src11)
  )

  tes <- c("MOD21A1D", "MYD21A1D")
  src21 <- "D2 p. 23, Tabla 9; D11; D12 (modis-products.md 5.2 b)"
  g21 <- "MODIS_Grid_Daily_1km_LST21"
  mod21 <- rbind(
    mp_rows(tes, "LST_1KM", g21, "1km", 1200, "uint16", "value",
            "scale_offset", 0.02, 0, 7500, 65535, 0, "K", src21),
    mp_rows(tes, "QC", g21, "1km", 1200, "uint16", "qa_bits", "none",
            NA, NA, 0, 65535, NA, "bits",
            "D2 p. 23, Tabla 9; D2 p. 26-27, Tabla 11; D11 (modis-products.md 5.2 b-c)",
            qa_table = "MOD21_QC"),
    mp_rows(tes, c("Emis_29", "Emis_31", "Emis_32"), g21, "1km", 1200,
            "uint8", "value", "scale_offset", 0.002, 0.49, 1, 255, 0, "1",
            src21),
    mp_rows(tes, "View_Angle", g21, "1km", 1200, "uint8", "value",
            "scale_offset", 1, -65, 0, 130, 255, "degree", src21),
    mp_rows(tes, "View_Time", g21, "1km", 1200, "uint8", "value",
            "scale_offset", 0.1, 0, 0, 240, 255, "h", src21,
            note = paste("Time convention TODO (modis-products.md 6.4):",
                         "never converted to UTC automatically."))
  )

  src09 <- "D3 p. 14-15, Tabla 4; D12 (modis-products.md 5.3 b)"
  no_offset <- paste("No offset declared (D3 tables; D12 'N/A'): DN * scale;",
                     "a non-zero add_offset in the file is refused.")
  mod09ga <- rbind(
    mp_rows("MOD09GA", sprintf("sur_refl_b%02d_1", 1:7), NA, "500m", 2400,
            "int16", "value", "scale_only", 0.0001, NA, -100, 16000, -28672,
            "1", src09, note = no_offset),
    mp_rows("MOD09GA", "QC_500m_1", NA, "500m", 2400, "uint32", "qa_bits",
            "none", NA, NA, NA, NA, 787410671, "bits",
            "D3 p. 14-15, Tabla 4; D3 p. 22, Tabla 10 (modis-products.md 5.3 b-c)",
            qa_table = "MOD09_QC_500M",
            note = "Valid range not used (discrepancy d6b); bits decoded."),
    mp_rows("MOD09GA", "state_1km_1", NA, "1km", 1200, "uint16", "qa_bits",
            "none", NA, NA, NA, NA, 65535, "bits",
            "D3 p. 14-15, Tabla 4; D3 p. 25-26, Tabla 13 (modis-products.md 5.3 b-c)",
            qa_table = "MOD09_STATE",
            note = "Valid range not used (discrepancy d6); bits decoded."),
    mp_rows("MOD09GA", c("SensorZenith_1", "SolarZenith_1"), NA, "1km",
            1200, "int16", "value", "scale_only", 0.01, NA, 0, 18000, -32767,
            "degree", src09, note = no_offset),
    mp_rows("MOD09GA", "num_observations_500m", NA, "500m", 2400, "int8",
            "count", "none", NA, NA, 0, 127, -1, "count", src09)
  )

  src09q <- "D3 p. 13, Tabla 3; D12 (modis-products.md 5.4)"
  mod09gq <- rbind(
    mp_rows("MOD09GQ", c("sur_refl_b01_1", "sur_refl_b02_1"), NA, "250m",
            NA, "int16", "value", "scale_only", 0.0001, NA, -100, 16000,
            -28672, "1", src09q, note = no_offset),
    mp_rows("MOD09GQ", "QC_250m_1", NA, "250m", NA, "uint16", "qa_bits",
            "none", NA, NA, NA, NA, 2995, "bits",
            "D3 p. 13, Tabla 3; D3 p. 20, Tabla 8 (modis-products.md 5.4)",
            qa_table = "MOD09_QC_250M",
            note = "Valid range not used (D3 0-8000 vs D12 0-4096, TODO).")
  )

  mod13 <- function(product, prefix, alt_prefix, resolution, cells, src) {
    alt <- function(suffix) {
      if (is.na(alt_prefix)) "" else paste0(alt_prefix, suffix)
    }
    sfx <- function(s) paste0(prefix, s)
    rbind(
      mp_rows(product, sfx("NDVI"), NA, resolution, cells, "int16", "value",
              "scale_only", 0.0001, NA, -2000, 10000, -3000, "1", src,
              sds_alternatives = alt("NDVI")),
      mp_rows(product, sfx("VI Quality"), NA, resolution, cells, "uint16",
              "qa_bits", "none", NA, NA, 0, 65534, 65535, "bits",
              paste0(src, "; D4 p. 18, Tabla 5"),
              qa_table = "MOD13_VI_QUALITY",
              sds_alternatives = alt("VI Quality")),
      mp_rows(product, sfx("composite day of the year"), NA, resolution,
              cells, "int16", "doy", "none", NA, NA, 1, 366, -1,
              "day of year", src,
              sds_alternatives = alt("composite day of the year")),
      mp_rows(product, sfx("pixel reliability"), NA, resolution, cells,
              "int8", "qa_code", "none", NA, NA, 0, 3, -1, "code",
              paste0(src, "; D4 p. 17, Tabla 4"),
              qa_table = "MOD13_RELIABILITY",
              sds_alternatives = alt("pixel reliability")),
      mp_rows(product, sfx(c("view zenith angle", "sun zenith angle")), NA,
              resolution, cells, "int16", "value", "scale_only", 0.01, NA, 0,
              18000, -10000, "degree", src,
              sds_alternatives = alt(c("view zenith angle",
                                       "sun zenith angle"))),
      mp_rows(product, sfx(c("red reflectance", "NIR reflectance")), NA,
              resolution, cells, "int16", "value", "scale_only", 0.0001, NA,
              0, 10000, -1000, "1", src,
              sds_alternatives = alt(c("red reflectance",
                                       "NIR reflectance")))
    )
  }
  mod13q1 <- mod13("MOD13Q1", "250m 16 days ", NA, "250m", NA,
                   "D4 p. 12, Tabla 1; D12 (modis-products.md 5.5 b)")
  mod13a2 <- mod13("MOD13A2", "1 km 16 days ", "1km 16 days ", "1km", 1200,
                   "D4 p. 21, Tabla 8; D12 (modis-products.md 5.5 b)")

  src43 <- "D8; D12 (modis-products.md 5.6 b)"
  bands43 <- c("shortwave", "vis", "nir", paste0("Band", 1:7))
  mcd43a3 <- rbind(
    mp_rows("MCD43A3",
            c(paste0("Albedo_BSA_", bands43), paste0("Albedo_WSA_", bands43)),
            "MOD_Grid_BRDF", "500m", 2400, "int16", "value",
            "offset_scale", 0.001, 0, 0, 32766, 32767, "1", src43,
            note = paste("Values above 1 with a valid DN are kept",
                         "(modis-products.md 5.6 b).")),
    mp_rows("MCD43A3", "BRDF_Albedo_Band_Mandatory_Quality_shortwave",
            "MOD_Grid_BRDF", "500m", 2400, "uint8", "qa_code", "none", NA,
            NA, 0, 254, 255, "code", "D8 (modis-products.md 5.6 b-c)",
            qa_table = "MCD43_MANDATORY_NIR_SW")
  )
  mcd43a2 <- mp_rows("MCD43A2", "Snow_BRDF_Albedo", NA, NA, NA, "uint8",
                     "qa_code", "none", NA, NA, 0, 1, 255, "code",
                     "D9 (modis-products.md 5.6 c)", qa_table = "MCD43A2_SNOW")

  src15 <- "D5 p. 8, Tabla 4; D12 (modis-products.md 5.7 b)"
  mcd15 <- rbind(
    mp_rows("MCD15A2H", "Lai_500m", NA, "500m", 2400, "uint8", "value",
            "scale_only", 0.1, NA, 0, 100, 255, "m2 m-2", src15,
            special_min = 249, special_max = 254,
            special_flag = "EF_SURF_LAI_NONVEG",
            note = paste("249-254: non-vegetated classes (D5 p. 11, Tabla 6);",
                         "255: fill.")),
    mp_rows("MCD15A2H", "FparLai_QC", NA, "500m", 2400, "uint8", "qa_bits",
            "none", NA, NA, 0, 254, 255, "bits",
            "D5 p. 8, Tabla 4; D5 p. 9-10, Tabla 5 (modis-products.md 5.7 b-c)",
            qa_table = "MCD15_FPARLAI_QC"),
    mp_rows("MCD15A2H", "FparExtra_QC", NA, "500m", 2400, "uint8",
            "qa_bits", "none", NA, NA, 0, 254, 255, "bits",
            "D5 p. 8, Tabla 4; D5 p. 10 (modis-products.md 5.7 b-c)",
            qa_table = "MCD15_FPAREXTRA_QC")
  )

  src12 <- "D6 p. 7, Tabla 1; D12 (modis-products.md 5.8)"
  mcd12 <- rbind(
    mp_rows("MCD12Q1", "LC_Type1", NA, "500m", 2400, "uint8", "class",
            "none", NA, NA, 1, 17, 255, "class", src12,
            note = "IGBP classes (D6 p. 9, Tabla 3)."),
    mp_rows("MCD12Q1", "LC_Type3", NA, "500m", 2400, "uint8", "class",
            "none", NA, NA, 0, 10, 255, "class", src12,
            note = "LAI scheme (D6 p. 11, Tabla 5)."),
    mp_rows("MCD12Q1", "QC", NA, "500m", 2400, "uint8", "qa_code", "none",
            NA, NA, 0, 10, 255, "code",
            "D6 p. 7, Tabla 1; D6 p. 17, Tabla 11 (modis-products.md 5.8)",
            qa_table = "MCD12_QC"),
    mp_rows("MCD12Q1", "LW", NA, "500m", 2400, "uint8", "class", "none",
            NA, NA, 1, 2, 255, "class", src12,
            note = "1 water, 2 land (from MOD44W).")
  )

  tab <- rbind(mod11, mod21, mod09ga, mod09gq, mod13q1, mod13a2, mcd43a3,
               mcd43a2, mcd15, mcd12)
  tab$physical_min <- modis_convert(tab$valid_min, tab)
  tab$physical_max <- modis_convert(tab$valid_max, tab)
  rownames(tab) <- NULL
  tab
}

#' DOI of the MODIS products
#'
#' Data set DOIs of the collection 6.1 products, for the provenance of the
#' surface state (`modis_provenance()`). `VERIFICADA` where the product
#' sheet gives the DOI (dev/specs/modis-products.md 5.1 a, 5.2 a, 5.6 a:
#' MOD11A1, MYD11A1, MOD21A1D, MYD21A1D, MCD43A3); `DERIVADA` for the other
#' products of the catalogue pages D12, from the pattern
#' `10.5067/MODIS/<product>.061` that every page of D12 shows (section 3,
#' `VERIFICADA`). MCD43A2 is not among the pages of D12 and has no row
#' (its DOI is `NA` in the provenance).
#'
#' @return A data frame with `product`, `collection`, `doi`, `status` and
#'   `source`.
#' @noRd
modis_product_doi <- function() {
  sheet <- c("MOD11A1", "MYD11A1", "MOD21A1D", "MYD21A1D", "MCD43A3")
  pattern <- c("MOD09GA", "MOD09GQ", "MOD13Q1", "MOD13A2", "MCD15A2H",
               "MCD12Q1")
  product <- c(sheet, pattern)
  data.frame(
    product = product,
    collection = "061",
    doi = sprintf("10.5067/MODIS/%s.061", product),
    status = c(rep("VERIFICADA", length(sheet)),
               rep("DERIVADA", length(pattern))),
    source = c(
      rep("D12 (modis-products.md 5.1 a)", 2L),
      rep("D2 p. 10, Tabla 2; D12 (modis-products.md 5.2 a)", 2L),
      "D12 (modis-products.md 5.6 a)",
      rep(paste0("D12, DOI 10.5067/MODIS/<product>.061 on every catalogue ",
                 "page (modis-products.md 3)"), length(pattern))
    ),
    stringsAsFactors = FALSE
  )
}

#' Supported MODIS products
#'
#' @return Character vector of short names with a product sheet.
#' @noRd
modis_supported_products <- function() {
  unique(modis_product_table()$product)
}

#' Product sheet of one MODIS product and collection
#'
#' @param product Character. Short name (e.g. `"MOD11A1"`).
#' @param collection Character. Collection (`"061"`).
#' @return The rows of `modis_product_table()` of that product, one per
#'   supported layer. Error `earthflux_modis_unsupported` when the product
#'   or the collection has no verified sheet.
#' @noRd
modis_product_spec <- function(product, collection = "061") {
  check_string(product)
  check_string(collection)
  unsupported <- c("earthflux_modis_unsupported", "earthflux_input_error")
  if (!collection %in% modis_supported_collections()) {
    ef_abort(
      sprintf(paste0("MODIS collection \"%s\" has no verified product ",
                     "sheet; supported: %s (decision MP-13)."),
              collection, paste(modis_supported_collections(), collapse = ", ")),
      class = unsupported, product = product, collection = collection
    )
  }
  tab <- modis_product_table()
  rows <- tab[tab$product == product & tab$collection == collection, ,
              drop = FALSE]
  if (nrow(rows) == 0L) {
    ef_abort(
      sprintf("MODIS product \"%s\" has no verified product sheet; supported: %s.",
              product, paste(unique(tab$product), collapse = ", ")),
      class = unsupported, product = product, collection = collection
    )
  }
  rownames(rows) <- NULL
  rows
}

#' Product sheet row of one MODIS layer
#'
#' @inheritParams modis_product_spec
#' @param layer Character. SDS name as written in the sheet (one of
#'   `modis_product_spec(product)$layer`).
#' @return A one-row data frame. Error `earthflux_modis_unsupported` when the
#'   layer is not supported (its facts are `TODO` or it is not in the sheet).
#' @noRd
modis_layer_spec <- function(product, layer, collection = "061") {
  rows <- modis_product_spec(product, collection)
  check_string(layer)
  i <- match(layer, rows$layer)
  if (is.na(i)) {
    ef_abort(
      sprintf(paste0("Layer \"%s\" of %s (collection %s) is not supported: ",
                     "its facts are not verified in the product sheet. ",
                     "Supported layers: %s."),
              layer, product, collection,
              paste0("\"", rows$layer, "\"", collapse = ", ")),
      class = c("earthflux_modis_unsupported", "earthflux_input_error"),
      product = product, layer = layer
    )
  }
  rows[i, , drop = FALSE]
}

#' Check a product table row passed as argument
#'
#' @param spec_row Object to check.
#' @param call The call to report.
#' @return `spec_row`, invisibly.
#' @noRd
check_spec_row <- function(spec_row, call = sys.call(-1)) {
  need <- c("product", "layer", "data_type", "kind", "conversion", "scale",
            "offset", "valid_min", "valid_max", "fill", "special_min",
            "special_max")
  if (!is.data.frame(spec_row) || nrow(spec_row) != 1L ||
      !all(need %in% names(spec_row))) {
    ef_abort(
      paste0("`spec_row` must be one row of the MODIS product table ",
             "(modis_layer_spec())."),
      class = "earthflux_input_error", call = call
    )
  }
  invisible(spec_row)
}

# Conversions ---------------------------------------------------------------------

#' Convert DN to physical values with the convention of the table
#'
#' @param dn Numeric DN.
#' @param rows Rows of the product table (one, or one per element of `dn`).
#' @return Numeric, same shape as `dn`.
#' @noRd
modis_convert <- function(dn, rows) {
  conv <- rows$conversion
  scale <- rows$scale
  offset <- rows$offset
  out <- dn
  i <- conv == "scale_offset"
  out[i] <- (dn * scale + offset)[i]
  i <- conv == "offset_scale"
  out[i] <- ((dn - offset) * scale)[i]
  i <- conv == "scale_only"
  out[i] <- (dn * scale)[i]
  out
}

#' Invert the conversion of a layer (physical value -> DN, not rounded)
#'
#' @param x Numeric physical values.
#' @param row One row of the product table.
#' @return Numeric, same shape as `x`.
#' @noRd
modis_invert <- function(x, row) {
  switch(row$conversion,
         scale_offset = (x - row$offset) / row$scale,
         offset_scale = x / row$scale + row$offset,
         scale_only = x / row$scale,
         none = x)
}

#' Limits of a data type of the product sheets
#'
#' @param data_type Character (e.g. `"uint16"`).
#' @return Numeric vector `c(min, max)`.
#' @noRd
modis_type_range <- function(data_type) {
  switch(data_type,
         uint8 = c(0, 255),
         int8 = c(-128, 127),
         uint16 = c(0, 65535),
         int16 = c(-32768, 32767),
         uint32 = c(0, 4294967295),
         int32 = c(-2147483648, 2147483647),
         ef_abort(sprintf("Unknown MODIS data type \"%s\".", data_type),
                  class = "earthflux_input_error"))
}

#' Tolerance to recover DN from scaled values (in DN)
#'
#' A converted file declared as scaled (`scaled = TRUE`) is turned back into
#' DN with the inverse conversion of the table; the result must lie within
#' this distance of a whole number (single precision storage of a scaled
#' value is within about 1e-3 DN). Numerical convention, not a product fact
#' (decision M4-06).
#'
#' @noRd
modis_dn_tolerance <- 0.01

#' Check that values are raw DN of a layer
#'
#' MP-11: the reader verifies that no scaling was applied. Non-missing values
#' must be whole numbers inside the range of the data type of the layer.
#'
#' @param dn Numeric.
#' @param row One row of the product table.
#' @param what Character. Description of the source for the message.
#' @return `dn`, invisibly. Error `earthflux_modis_dn_error` otherwise.
#' @noRd
modis_check_dn <- function(dn, row, what = "`dn`", call = sys.call(-1)) {
  if (!is.numeric(dn)) {
    ef_abort(sprintf("%s must be numeric, not %s.", what, class(dn)[1L]),
             class = "earthflux_input_error", call = call)
  }
  v <- dn[!is.na(dn)]
  lim <- modis_type_range(row$data_type)
  n_frac <- sum(v != round(v))
  n_type <- sum(v < lim[1L] | v > lim[2L])
  if (n_frac > 0L || n_type > 0L) {
    ef_abort(
      sprintf(paste0("%s must be raw DN of layer \"%s\" (%s): found %d ",
                     "non-whole value(s) and %d value(s) outside [%s, %s]. ",
                     "Already scaled values must be declared as such ",
                     "(decision MP-11)."),
              what, row$layer, row$data_type, n_frac, n_type,
              format(lim[1L], scientific = FALSE),
              format(lim[2L], scientific = FALSE)),
      class = c("earthflux_modis_dn_error", "earthflux_input_error"),
      layer = row$layer, n_non_whole = n_frac, n_outside_type = n_type,
      call = call
    )
  }
  invisible(dn)
}

#' Scale MODIS DN into physical values
#'
#' Applies the conversion of the product table (`DN * scale + offset`,
#' `(DN - offset) * scale`, `DN * scale` or none; dev/specs/modis-products.md
#' section 11.3) and turns the documented causes of `NA` into `NA`: the fill
#' value and values outside the valid range of the layer (section 10.2),
#' and documented class codes outside the valid range (`special_*`
#' columns, e.g. LAI 249-254). Never relies on GDAL scaling (MP-11).
#' `NA` DN propagate (no mask is set for them).
#'
#' @param dn Numeric vector or array of raw DN (whole numbers inside the
#'   data type of the layer; checked).
#' @param spec_row One row of the product table (`modis_layer_spec()`).
#' @return A list with `value` (numeric, the shape of `dn`, in the unit of
#'   the row) and three logical vectors without `NA` (cell order, `dim`
#'   dropped): `fill` (DN equal to the fill value), `special` (DN among the
#'   documented special codes) and `out_of_range` (DN outside the valid
#'   range, neither fill nor special). `value` is `NA` wherever a mask is
#'   `TRUE`.
#' @noRd
modis_apply_scale <- function(dn, spec_row) {
  check_spec_row(spec_row)
  modis_check_dn(dn, spec_row)
  ok <- !is.na(dn)
  v <- as.vector(dn)
  okv <- as.vector(ok)
  fill <- okv & !is.na(spec_row$fill) & v == spec_row$fill
  fill[is.na(fill)] <- FALSE
  special <- okv & !fill & !is.na(spec_row$special_min) &
    v >= spec_row$special_min & v <= spec_row$special_max
  special[is.na(special)] <- FALSE
  below <- if (is.na(spec_row$valid_min)) FALSE else v < spec_row$valid_min
  above <- if (is.na(spec_row$valid_max)) FALSE else v > spec_row$valid_max
  out_of_range <- okv & !fill & !special & (below | above)
  out_of_range[is.na(out_of_range)] <- FALSE

  x <- dn
  storage.mode(x) <- "double"
  value <- modis_convert(x, spec_row)
  value[fill | special | out_of_range] <- NA_real_
  list(value = value, fill = fill, special = special,
       out_of_range = out_of_range)
}

# SpatRaster adapters ---------------------------------------------------------------

#' Values of a single-layer SpatRaster (or a numeric) as a numeric vector
#'
#' The converters of R/modis-qa.R work on plain numeric vectors in cell
#' order; this adapter makes a `SpatRaster` layer usable with them, so that
#' a vector and a raster give the same result (modis-products.md section
#' 14).
#'
#' @param x A single-layer `SpatRaster` or a numeric vector/array.
#' @return Numeric vector (cell order for a raster; `x` unchanged otherwise).
#' @noRd
modis_values <- function(x) {
  if (inherits(x, "SpatRaster")) {
    if (terra::nlyr(x) != 1L) {
      ef_abort("Give one layer at a time (`x[[i]]`).",
               class = "earthflux_input_error")
    }
    return(terra::values(x, mat = FALSE))
  }
  check_numeric(x)
  x
}

#' Put a numeric vector back into the geometry of a raster
#'
#' @param value Numeric or logical vector of length `ncell(template)`.
#' @param template A `SpatRaster` (its geometry is used).
#' @param name Character. Layer name.
#' @return A single-layer `SpatRaster`.
#' @noRd
modis_as_raster <- function(value, template, name) {
  out <- terra::rast(template, nlyrs = 1)
  out <- terra::setValues(out, as.vector(value))
  names(out) <- name
  out
}

# File names --------------------------------------------------------------------

#' Parse a MODIS file name
#'
#' Convention `<SHORTNAME>.AYYYYDDD.hXXvYY.<collection>.<YYYYDDDHHMMSS>.hdf`
#' (dev/specs/modis-products.md section 4, `VERIFICADA`: D12; D5 p. 6-7).
#' The acquisition date is a UTC day (D1 p. 16).
#'
#' @param path Character. Path or file name.
#' @return A list with `file` (base name), `product`, `date` (`Date`, UTC
#'   day of the data), `year`, `doy`, `h`, `v`, `tile` (`"hXXvYY"`),
#'   `collection` and `production` (`POSIXct`, UTC). Error
#'   `earthflux_modis_filename_error` when the name does not follow the
#'   convention or holds an impossible date or tile.
#' @noRd
modis_parse_filename <- function(path) {
  check_string(path)
  file <- basename(path)
  rx <- paste0("^([A-Z0-9]+)\\.A([0-9]{4})([0-9]{3})\\.h([0-9]{2})",
               "v([0-9]{2})\\.([0-9]{3})\\.([0-9]{13})\\.hdf$")
  bad <- function(why) {
    ef_abort(
      sprintf(paste0("File name \"%s\" does not follow the MODIS convention ",
                     "<SHORTNAME>.AYYYYDDD.hXXvYY.<collection>.",
                     "<YYYYDDDHHMMSS>.hdf (%s)."), file, why),
      class = c("earthflux_modis_filename_error", "earthflux_input_error"),
      file = file
    )
  }
  if (!grepl(rx, file)) bad("pattern")
  p <- regmatches(file, regexec(rx, file))[[1L]][-1L]
  year <- as.integer(p[2L])
  doy <- as.integer(p[3L])
  h <- as.integer(p[4L])
  v <- as.integer(p[5L])
  g <- modis_sinusoidal_grid()
  leap <- (year %% 4L == 0L & year %% 100L != 0L) | year %% 400L == 0L
  if (doy < 1L || doy > 365L + leap) bad("day of year")
  if (h > g$n_h - 1L || v > g$n_v - 1L) bad("tile index")
  production <- as.POSIXct(strptime(p[7L], "%Y%j%H%M%S", tz = "UTC"))
  if (is.na(production)) bad("production time stamp")
  list(
    file = file,
    product = p[1L],
    date = as.Date(sprintf("%04d-01-01", year)) + (doy - 1L),
    year = year,
    doy = doy,
    h = h,
    v = v,
    tile = sprintf("h%02dv%02d", h, v),
    collection = p[6L],
    production = production
  )
}

# HDF4 reading ----------------------------------------------------------------------

#' Is the GDAL HDF4 driver available to terra?
#'
#' Not every build of GDAL includes it (modis-products.md section 11.1,
#' risk for the CRAN binaries).
#'
#' @return `TRUE` or `FALSE`.
#' @noRd
modis_has_hdf4 <- function() {
  drv <- terra::gdal(drivers = TRUE)
  any(drv$name == "HDF4" & grepl("read", drv$can, fixed = TRUE))
}

#' Stop when the HDF4 driver is missing
#' @noRd
modis_require_hdf4 <- function(call = sys.call(-1)) {
  if (!modis_has_hdf4()) {
    ef_abort(
      paste0("The GDAL driver HDF4 is not available in this build of terra; ",
             "convert the layers (e.g. to GeoTIFF) and read them with ",
             "modis_read_converted() (decision MP-10)."),
      class = "earthflux_modis_driver_error", call = call
    )
  }
  invisible(TRUE)
}

#' Split a GDAL subdataset name into grid and SDS name
#'
#' `HDF4_EOS:EOS_GRID:"<file>":<grid>:<sds>` gives the grid and the SDS name
#' (the SDS name may contain spaces, never a colon); other forms
#' (`HDF4_SDS:<type>:"<file>":<index>`) give `NA` grid and the part after
#' the file name.
#'
#' @param name Character vector of subdataset names.
#' @return A data frame with `grid` and `sds`.
#' @noRd
modis_parse_sds_name <- function(name) {
  rest <- sub('^.*":', "", name)
  eos <- startsWith(name, "HDF4_EOS:EOS_GRID:") & grepl(":", rest, fixed = TRUE)
  grid <- ifelse(eos, sub(":.*$", "", rest), NA_character_)
  sds <- ifelse(eos, sub("^[^:]*:", "", rest), rest)
  # GDAL quotes SDS names that contain spaces (MOD13: "1 km 16 days NDVI")
  sds <- sub('^"(.*)"$', "\\1", sds)
  data.frame(grid = grid, sds = sds, stringsAsFactors = FALSE)
}

#' Check that a file exists
#' @noRd
check_file <- function(path, call = sys.call(-1)) {
  check_string(path)
  if (!file.exists(path)) {
    ef_abort(sprintf("File \"%s\" does not exist.", path),
             class = "earthflux_input_error", call = call)
  }
  invisible(path)
}

#' Subdatasets (layers) of a MODIS HDF4 file
#'
#' @param path Character. Path of an HDF4/HDF-EOS file.
#' @return A data frame with `sds` (SDS name), `grid` (HDF-EOS grid or `NA`),
#'   `name` (GDAL subdataset name), `nrow` and `ncol`.
#' @noRd
modis_list_layers <- function(path) {
  check_file(path)
  modis_require_hdf4()
  d <- terra::describe(path, sds = TRUE)
  if (is.null(d) || nrow(d) == 0L) {
    ef_abort(sprintf("File \"%s\" has no subdatasets (not an HDF4 file?).",
                     basename(path)),
             class = c("earthflux_modis_layer_error", "earthflux_input_error"))
  }
  parts <- modis_parse_sds_name(d$name)
  data.frame(sds = parts$sds, grid = parts$grid, name = d$name,
             nrow = d$nrow, ncol = d$ncol, stringsAsFactors = FALSE)
}

#' Match product table rows with the subdatasets of a file
#'
#' Exact match of the SDS name (or one of its official alternatives) and,
#' when both are known, of the HDF-EOS grid (modis-products.md section 5.5:
#' names are resolved against the file, never assumed).
#'
#' @param rows Rows of the product table.
#' @param listing Result of `modis_list_layers()`.
#' @return Character vector of GDAL subdataset names, one per row.
#' @noRd
modis_match_layers <- function(rows, listing, call = sys.call(-1)) {
  vapply(seq_len(nrow(rows)), function(i) {
    cand <- c(rows$layer[i], strsplit(rows$sds_alternatives[i], "|",
                                      fixed = TRUE)[[1L]])
    cand <- cand[nzchar(cand)]
    hit <- listing$sds %in% cand
    if (!is.na(rows$grid[i])) {
      hit <- hit & (is.na(listing$grid) | listing$grid == rows$grid[i])
    }
    if (sum(hit) != 1L) {
      ef_abort(
        sprintf(paste0("Layer \"%s\" is %s in the file (exact match against ",
                       "the subdataset names; candidates: %s)."),
                rows$layer[i], if (sum(hit) == 0L) "missing" else "ambiguous",
                paste0("\"", cand, "\"", collapse = ", ")),
        class = c("earthflux_modis_layer_error", "earthflux_input_error"),
        layer = rows$layer[i], call = call
      )
    }
    listing$name[hit]
  }, character(1))
}

#' NoData value declared by GDAL for a single-band source
#'
#' @param source Character. File or subdataset name.
#' @return Numeric (`NA` when none is declared).
#' @noRd
modis_nodata <- function(source) {
  txt <- terra::describe(source)
  line <- grep("NoData Value=", txt, value = TRUE, fixed = TRUE)
  if (length(line) == 0L) {
    return(NA_real_)
  }
  val <- trimws(sub("^.*NoData Value=", "", line[1L]))
  suppressWarnings(as.numeric(val))
}

#' Check the scale and offset declared by a file against the table
#'
#' MP-11 and section 16, item 12: GDAL may expose `scale_factor` and
#' `add_offset`, under a convention that is `TODO` for HDF4. The values are
#' never applied; the scale must equal the table, its reciprocal (MOD13
#' files declare 10000 for a table scale of 1e-4) or be absent and, for
#' layers without an offset in the table, the offset must be zero. A
#' non-zero offset of a layer with a non-zero table offset is only recorded.
#'
#' @param so Numeric `c(scale, offset)` declared by the file (terra `scoff`).
#' @param row One row of the product table.
#' @param scaled Logical. Whether the values are declared already scaled.
#' @return `so`, invisibly.
#' @noRd
modis_check_file_scaling <- function(so, row, scaled, call = sys.call(-1)) {
  s <- so[1L]
  o <- so[2L]
  identity <- isTRUE(all.equal(s, 1)) && isTRUE(all.equal(o, 0))
  if (identity) {
    return(invisible(so))
  }
  meta <- c("earthflux_modis_metadata_error", "earthflux_input_error")
  if (scaled) {
    ef_abort(
      sprintf(paste0("Layer \"%s\" is declared as already scaled but the file ",
                     "declares scale %s and offset %s; the declaration is ",
                     "ambiguous (decision MP-10)."), row$layer, s, o),
      class = meta, layer = row$layer, file_scale = s, file_offset = o,
      call = call
    )
  }
  # The official HDF4 files use both conventions: MOD11, MCD15 and MCD43
  # declare the multiplier (DN * scale), MOD13 its reciprocal (DN / 10000).
  # The declared value is never applied, so either form is accepted.
  scale_ok <- (is.na(row$scale) && isTRUE(all.equal(s, 1))) ||
    (!is.na(row$scale) && (isTRUE(all.equal(s, row$scale)) ||
                             isTRUE(all.equal(1 / s, row$scale))))
  zero_offset <- is.na(row$offset) || row$offset == 0
  offset_ok <- !zero_offset || isTRUE(all.equal(o, 0))
  if (!scale_ok || !offset_ok) {
    ef_abort(
      sprintf(paste0("The file declares scale %s and offset %s for layer ",
                     "\"%s\", which contradict the product table (scale %s, ",
                     "offset %s)."), s, o, row$layer, row$scale, row$offset),
      class = meta, layer = row$layer, file_scale = s, file_offset = o,
      call = call
    )
  }
  invisible(so)
}

#' Read the raw DN of one single-band source
#'
#' Reads with `raw = TRUE` (no GDAL scaling), crops to `aoi_ext` and turns
#' the cells that GDAL hides as NoData back into their DN when the NoData
#' value is the fill value of the layer (so that fill stays distinguishable
#' from missing data).
#'
#' @param source Character. File or subdataset name.
#' @param row One row of the product table.
#' @param aoi_ext `SpatExtent` or `NULL`.
#' @param strict Logical. `TRUE` (official HDF files): a NoData value
#'   different from the fill of the table is an error, except in bit-field
#'   layers without fill value, where it is a valid bit pattern. `FALSE` (converted
#'   files): it is taken as missing data.
#' @param scaled Logical. Declaration of the values (converted files).
#' @return A list with `raster` (single-layer `SpatRaster` in memory),
#'   `values` (numeric), `file_scale`, `file_offset` and `nodata`.
#' @noRd
modis_read_source <- function(source, row, aoi_ext, strict, scaled,
                              call = sys.call(-1)) {
  so <- as.numeric(terra::scoff(terra::rast(source))[1L, ])
  modis_check_file_scaling(so, row, scaled = scaled, call = call)
  r <- terra::rast(source, raw = TRUE)
  if (terra::nlyr(r) != 1L) {
    ef_abort(sprintf("Source of layer \"%s\" must have one band, not %d.",
                     row$layer, terra::nlyr(r)),
             class = "earthflux_input_error", call = call)
  }
  integer_type <- startsWith(terra::datatype(r), "INT")
  if (!is.null(aoi_ext)) {
    r <- terra::crop(r, aoi_ext, snap = "out")
  }
  v <- terra::values(r, mat = FALSE)
  v[is.nan(v)] <- NA
  nd <- modis_nodata(source)
  if (!is.na(nd) && !scaled) {
    is_fill <- !is.na(row$fill) && nd == row$fill
    # A bit-field layer without fill value (e.g. MOD11A1 QC_Day, whose files
    # declare _FillValue = 0 although 0 is the best-quality code): the
    # declared NoData is a valid bit pattern, so its cells are restored.
    is_bit_pattern <- is.na(row$fill) && identical(row$kind, "qa_bits")
    if (strict && !is_fill && !is_bit_pattern) {
      ef_abort(
        sprintf(paste0("The file declares NoData %s for layer \"%s\", but the ",
                       "product table gives fill %s."),
                nd, row$layer, row$fill),
        class = c("earthflux_modis_metadata_error", "earthflux_input_error"),
        layer = row$layer, nodata = nd, call = call
      )
    }
    if ((is_fill || is_bit_pattern) && integer_type) {
      v[is.na(v)] <- nd
    }
  }
  list(raster = r, values = v, file_scale = so[1L], file_offset = so[2L],
       nodata = nd)
}

#' Build the in-memory DN raster of several layers
#' @noRd
modis_stack <- function(parts, rows) {
  layers <- lapply(seq_along(parts), function(i) {
    modis_as_raster(parts[[i]]$values, parts[[i]]$raster, rows$layer[i])
  })
  terra::rast(layers)
}

#' Check the geometry of a tile read from an official file
#'
#' Sinusoidal CRS of the sheet, cell size equal to the derived value for
#' the number of cells per tile (section 4: always read the resolution from
#' the file and compare it with the derived value) and extent equal to the
#' extent of the tile named in the file (`modis_tile_extent()`). Skipped for
#' a geometry that is `TODO` (250 m).
#'
#' @param r `SpatRaster` (whole tile, before cropping).
#' @param row One row of the product table.
#' @param info Result of `modis_parse_filename()`.
#' @return `r`, invisibly.
#' @noRd
modis_check_tile_geometry <- function(r, row, info, call = sys.call(-1)) {
  g <- modis_sinusoidal_grid()
  grid_error <- c("earthflux_modis_grid_error", "earthflux_input_error")
  if (!isTRUE(terra::same.crs(r, g$crs))) {
    ef_abort(
      sprintf("Layer \"%s\" is not in the MODIS sinusoidal CRS (%s).",
              row$layer, g$crs),
      class = grid_error, layer = row$layer, call = call
    )
  }
  if (is.na(row$cells_per_tile)) {
    return(invisible(r))
  }
  cell <- g$tile_size / row$cells_per_tile
  res <- terra::res(r)
  tol <- 1e-3 * cell
  if (any(abs(res - cell) > tol)) {
    ef_abort(
      sprintf(paste0("Layer \"%s\" has cell size %s m; the sinusoidal grid ",
                     "with %d cells per tile gives %s m."),
              row$layer, paste(format(res, digits = 12), collapse = " x "),
              row$cells_per_tile, format(cell, digits = 12)),
      class = grid_error, layer = row$layer, resolution = res,
      expected = cell, call = call
    )
  }
  e <- as.vector(terra::ext(r))
  te <- as.vector(modis_tile_extent(info$h, info$v))
  if (any(abs(e - te) > tol)) {
    ef_abort(
      sprintf("Layer \"%s\" does not cover the extent of tile %s.",
              row$layer, info$tile),
      class = grid_error, layer = row$layer, extent = e, expected = te,
      call = call
    )
  }
  invisible(r)
}

#' Set the metadata tags of a DN raster
#' @noRd
modis_tag <- function(r, tags) {
  terra::metags(r) <- tags
  r
}

#' Read raw DN of MODIS layers from an official HDF4 file
#'
#' Reads the subdatasets that match `layers` exactly (modis-products.md
#' section 11.1), without GDAL scaling (MP-11), checks the geometry of the
#' tile (sinusoidal CRS, cell size, tile extent; section 4), crops to the
#' area of interest in the native sinusoidal grid before any reprojection
#' (section 11.4) and verifies that the values are raw DN.
#'
#' @param path Character. Path of the HDF4 file, named with the MODIS
#'   convention (product and collection are taken from the name).
#' @param layers Character. SDS names (sheet spelling) of layers of the same
#'   resolution.
#' @param aoi `NULL`, a `SpatVector` in any CRS, or a `SpatExtent` in the
#'   sinusoidal CRS (see `aoi_extent()`).
#' @return A `SpatRaster` of DN (in memory), one layer per element of
#'   `layers`, named as in the sheet, with metadata tags `product`,
#'   `collection`, `date`, `tile`, `file` and `input = "dn"`.
#' @noRd
modis_read_raw <- function(path, layers, aoi = NULL) {
  check_file(path)
  info <- modis_parse_filename(path)
  if (!is.character(layers) || length(layers) == 0L || anyNA(layers) ||
      anyDuplicated(layers) > 0L) {
    ef_abort("`layers` must be a non-empty character vector without duplicates.",
             class = "earthflux_input_error")
  }
  rows <- do.call(rbind, lapply(layers, modis_layer_spec,
                                product = info$product,
                                collection = info$collection))
  if (length(unique(paste(rows$resolution))) != 1L) {
    ef_abort(
      sprintf(paste0("Layers of different resolution (%s) must be read in ",
                     "separate calls."),
              paste(unique(rows$resolution), collapse = ", ")),
      class = "earthflux_input_error"
    )
  }
  modis_require_hdf4()
  listing <- modis_list_layers(path)
  sources <- modis_match_layers(rows, listing)

  full <- terra::rast(sources[1L], raw = TRUE)
  modis_check_tile_geometry(full, rows[1L, ], info)
  aoi_ext <- if (is.null(aoi)) NULL else aoi_crop_extent(full, aoi)

  parts <- lapply(seq_along(sources), function(i) {
    part <- modis_read_source(sources[i], rows[i, , drop = FALSE], aoi_ext,
                              strict = TRUE, scaled = FALSE)
    modis_check_dn(part$values, rows[i, , drop = FALSE],
                   what = sprintf("Layer \"%s\"", rows$layer[i]))
    part
  })
  r <- modis_stack(parts, rows)
  modis_tag(r, c(product = info$product, collection = info$collection,
                 date = format(info$date), tile = info$tile, file = info$file,
                 input = "dn"))
}

#' Read the DN of a MODIS layer from a converted raster
#'
#' Converted files (GeoTIFF, COG, ...) are accepted only with an explicit
#' declaration of the product, the layer and whether the values are already
#' scaled (decision MP-10; modis-products.md section 11.2). Without the
#' declaration the reader stops, which prevents double scaling.
#'
#' * `scaled = FALSE`: the values must be raw DN (checked). A NoData value
#'   equal to the fill of the layer is turned back into the fill DN (and
#'   flagged downstream); any other NoData is missing data.
#' * `scaled = TRUE`: the values are physical; they are turned back into DN
#'   with the inverse conversion of the table and must land within
#'   `modis_dn_tolerance` of a whole number inside the data type (otherwise
#'   the declaration is wrong). NoData is missing data (the fill cannot be
#'   recognised once converted).
#'
#' The geometry is not checked against the sinusoidal grid (a converted
#' file may have been reprojected); the CRS is kept.
#'
#' @param path Character. Path of a single-band raster readable by terra.
#' @param product,layer Character. Product short name and SDS name.
#' @param scaled Logical, no default. See above.
#' @param aoi `NULL`, `SpatVector` (any CRS) or `SpatExtent` (CRS of the
#'   file).
#' @param collection Character. Collection of the product.
#' @return A single-layer `SpatRaster` of DN (in memory) named `layer`, with
#'   metadata tags `product`, `collection`, `file` and `input`
#'   (`"converted_dn"` or `"converted_scaled"`).
#' @noRd
modis_read_converted <- function(path, product, layer, scaled, aoi = NULL,
                                 collection = "061") {
  check_file(path)
  row <- modis_layer_spec(product, layer, collection)
  if (missing(scaled) || is.null(scaled)) {
    ef_abort(
      paste0("`scaled` must be declared explicitly for a converted file: ",
             "TRUE if the values are physical, FALSE if they are raw DN ",
             "(decision MP-10)."),
      class = c("earthflux_missing_input", "earthflux_input_error")
    )
  }
  if (!is.logical(scaled) || length(scaled) != 1L || is.na(scaled)) {
    ef_abort("`scaled` must be TRUE or FALSE.",
             class = "earthflux_input_error")
  }
  full <- terra::rast(path)
  aoi_ext <- if (is.null(aoi)) NULL else aoi_crop_extent(full, aoi)
  part <- modis_read_source(path, row, aoi_ext, strict = FALSE,
                            scaled = scaled)
  v <- part$values
  if (scaled) {
    dn <- modis_invert(v, row)
    off <- abs(dn - round(dn))
    n_off <- sum(off > modis_dn_tolerance, na.rm = TRUE)
    if (n_off > 0L) {
      ef_abort(
        sprintf(paste0("%d value(s) of layer \"%s\" are not a whole DN after ",
                       "inverting the conversion of the table; the values ",
                       "are not scaled as declared."), n_off, layer),
        class = c("earthflux_modis_dn_error", "earthflux_input_error"),
        layer = layer, n_non_whole = n_off
      )
    }
    v <- round(dn)
  }
  modis_check_dn(v, row, what = sprintf("Layer \"%s\" of \"%s\"", layer,
                                        basename(path)))
  r <- modis_as_raster(v, part$raster, layer)
  modis_tag(r, c(product = product, collection = collection,
                 file = basename(path),
                 input = if (scaled) "converted_scaled" else "converted_dn"))
}

# Tiles -------------------------------------------------------------------------------

#' File-level metadata tags of a SpatRaster as a named character vector
#'
#' `terra::metags()` returns a named character vector up to terra 1.8-29 and
#' a data frame with columns `name`, `value` and `domain` from terra 1.8-42
#' onwards (metadata domains). Both are normalised here; for the data frame
#' only the default domain (`""`) is kept, which is where `metags<-` with a
#' named vector writes.
#' @param r A `SpatRaster`.
#' @param m The value of `terra::metags(r)` (an argument so that both shapes
#'   can be tested whatever terra is installed).
#' @return A named character vector (possibly empty).
#' @noRd
modis_metags <- function(r, m = terra::metags(r)) {
  if (is.null(m) || length(m) == 0L) {
    return(stats::setNames(character(0), character(0)))
  }
  if (is.data.frame(m) || is.matrix(m)) {
    m <- as.data.frame(m, stringsAsFactors = FALSE)
    if (nrow(m) == 0L) {
      return(stats::setNames(character(0), character(0)))
    }
    if ("domain" %in% names(m)) {
      m <- m[is.na(m$domain) | m$domain == "", , drop = FALSE]
    }
    return(stats::setNames(as.character(m$value), as.character(m$name)))
  }
  stats::setNames(as.character(m), names(m))
}

#' Value of a metadata tag of a SpatRaster (or NA)
#' @noRd
modis_get_tag <- function(r, name) {
  m <- modis_metags(r)
  i <- match(name, names(m))
  if (is.na(i)) NA_character_ else unname(m[i])
}

#' Mosaic MODIS tiles of the same product and date
#'
#' Joins adjacent tiles before cropping (modis-products.md section 11.4).
#' The tiles must share CRS, cell size, cell alignment and layer names, and
#' the product, collection and date tags when present; overlapping tiles are
#' refused (continuity between adjacent tiles is `TODO` in the
#' specification, so no overlap rule is invented). Cells covered by no tile
#' are `NA`.
#'
#' @param rasters A list of `SpatRaster` (e.g. from `modis_read_raw()`).
#' @return A `SpatRaster` with the tags of the first tile and `tile`
#'   listing all tiles.
#' @noRd
modis_mosaic_tiles <- function(rasters) {
  grid_error <- c("earthflux_modis_grid_error", "earthflux_input_error")
  if (inherits(rasters, "SpatRaster")) rasters <- list(rasters)
  if (!is.list(rasters) || length(rasters) == 0L ||
      !all(vapply(rasters, inherits, logical(1), what = "SpatRaster"))) {
    ef_abort("`rasters` must be a non-empty list of SpatRaster.",
             class = "earthflux_input_error")
  }
  first <- rasters[[1L]]
  if (length(rasters) == 1L) {
    return(first)
  }
  for (k in seq_along(rasters)[-1L]) {
    r <- rasters[[k]]
    if (!identical(names(r), names(first))) {
      ef_abort("Tiles must have the same layers (names and order).",
               class = grid_error)
    }
    if (!isTRUE(terra::same.crs(r, first))) {
      ef_abort("Tiles must share the CRS.", class = grid_error)
    }
    tol <- 1e-6 * terra::res(first)
    if (any(abs(terra::res(r) - terra::res(first)) > tol)) {
      ef_abort("Tiles must share the cell size.", class = grid_error)
    }
    shift <- (as.vector(terra::ext(r))[c(1L, 3L)] -
                as.vector(terra::ext(first))[c(1L, 3L)]) / terra::res(first)
    if (any(abs(shift - round(shift)) > 1e-6)) {
      ef_abort("Tiles must be aligned on the same cell grid.",
               class = grid_error)
    }
    for (tag in c("product", "collection", "date")) {
      a <- modis_get_tag(first, tag)
      b <- modis_get_tag(r, tag)
      if (!is.na(a) && !is.na(b) && a != b) {
        ef_abort(sprintf("Tiles must share the %s (\"%s\" vs \"%s\").",
                         tag, a, b),
                 class = grid_error)
      }
    }
  }
  exts <- lapply(rasters, function(r) as.vector(terra::ext(r)))
  for (i in seq_along(exts)) {
    for (j in seq_along(exts)) {
      if (i < j) {
        a <- exts[[i]]
        b <- exts[[j]]
        w <- min(a[2L], b[2L]) - max(a[1L], b[1L])
        h <- min(a[4L], b[4L]) - max(a[3L], b[3L])
        res <- terra::res(first)
        if (w > 0.5 * res[1L] && h > 0.5 * res[2L]) {
          ef_abort(sprintf("Tiles %d and %d overlap.", i, j),
                   class = grid_error)
        }
      }
    }
  }
  out <- terra::merge(terra::sprc(rasters))
  names(out) <- names(first)
  tiles <- vapply(rasters, modis_get_tag, character(1), name = "tile")
  tagv <- modis_metags(first)
  tagv <- tagv[setdiff(names(tagv), c("AREA_OR_POINT", "file"))]
  if (!all(is.na(tiles))) tagv["tile"] <- paste(tiles, collapse = ",")
  if (length(tagv) > 0L) out <- modis_tag(out, tagv)
  out
}
