# MODIS: assembly of the surface state ---------------------------------------------
#
# Purpose: assemble, on the working grid, the surface state that the METRIC
#   core consumes (dev/ARCHITECTURE.md section 4, surface contract): `lst`
#   [K], `albedo`, `ndvi`, `lai` [m2 m-2], `emissivity`, `overpass_time`
#   (numeric `doy` and `utc_hour` plus the POSIXct instant), `qa` (flag word
#   per layer and flag records) and the provenance; plus the band 31/32
#   emissivities of MOD11A1/MYD11A1 (`band_emissivity`), carried for the
#   split-window broadband emissivity (E1), which is not implemented. Together with
#   R/io-modis.R, R/modis-qa.R and R/prep-modis.R, the only place that knows
#   MODIS conventions (dev/specs/modis-products.md section 1; ARCHITECTURE
#   principle 2): everything below is built from the product table, the QA
#   decoders and the preparation steps of those files, never from new
#   constants.
#
# Specification: dev/specs/modis-products.md sections 1 (contract), 6 (view
#   time), 8 (broadband), 9 (lag and resampling), 10 (QA policy), 12
#   (example data) and 13.2 (modis_surface_state(), modis_provenance());
#   dev/specs/flags.md sections 4.2, 6.3-6.7. Decisions: dev/DECISIONS.md
#   section 1.4 (M4-11 ...).
#
# Implemented (internal, no `ef_` prefix):
#   modis_source()            declaration of the file(s) of one product:
#                             an official HDF4 file, or converted rasters
#                             with their product, UTC date and scaling
#   modis_surface_options()   the explicit choices of the assembly (no
#                             defaults for scientific choices)
#   modis_surface_state()     files + AOI + options -> earthflux_surface_state
#   modis_provenance()        granules, products, collection, DOIs, methods,
#                             product table rows and versions
#   surface_exclusion()       cells that the orchestration must exclude
#                             before the METRIC core (critical bits)
#
# Working grid (MP-08): the native 1 km sinusoidal grid of the LST file,
#   cropped to the area of interest. The 500 m layers (albedo, LAI) are read
#   on the extent of that grid and aggregated by an integer factor with
#   modis_to_grid(); NDVI (MOD13A2) is already on it.
#
# Flags (dev/specs/flags.md 4.2, 6.3): one integer flag word per output
#   layer (`flags_lst`, `flags_overpass_time`, `flags_albedo`, `flags_ndvi`,
#   `flags_lai`, `flags_emissivity` and, with the band emissivities,
#   `flags_emis_31`, `flags_emis_32`) with the bits of the SURF stage, and
#   one `earthflux_flag` record per code flagged in a layer, with the field
#   `target` naming the layer. Raised here: EF_SURF_OVERPASS_MISSING (view
#   time missing where the LST is valid), EF_SURF_ALBEDO_GT1 (broadband
#   albedo above 1, class III, critical) and EF_SURF_LAI_ASSIGNED in the
#   emissivity computed from an assigned LAI; the other codes come from the
#   converters of R/modis-qa.R.

# Product roles -----------------------------------------------------------------

#' Band emissivity layers carried with the LST
#'
#' The band 31 and 32 emissivities of MOD11A1/MYD11A1 (`Emis_31`,
#' `Emis_32`; product table, dev/specs/modis-products.md 5.1 b,
#' `VERIFICADA`), the inputs of the split-window broadband emissivity
#' (option E1 of section 8.2, not implemented). They are carried in the
#' surface state (`band_emissivity`) so that E1 can be added without
#' changing the reading; no broadband value is computed from them.
#'
#' @param lst_product Character. LST product of the options.
#' @return Character vector of SDS names (empty for other products).
#' @noRd
modis_band_emissivity_layers <- function(lst_product) {
  if (lst_product %in% c("MOD11A1", "MYD11A1")) {
    c("Emis_31", "Emis_32")
  } else {
    character(0)
  }
}

#' Products accepted for the LST of the surface state
#'
#' MOD11A1/MYD11A1 only: the semantics of `View_Time` of MOD21A1D/MYD21A1D
#' are `TODO` (dev/specs/modis-products.md 6.4, MP-01), so no overpass
#' instant can be derived from them.
#'
#' @return A list with `available` and `planned` (named reasons).
#' @noRd
modis_lst_products <- function() {
  why <- paste0("the semantics of its View_Time are TODO ",
                "(dev/specs/modis-products.md 6.4, MP-01), so the overpass ",
                "instant cannot be derived")
  list(available = c("MOD11A1", "MYD11A1"),
       planned = c(MOD21A1D = why, MYD21A1D = why))
}

#' NDVI sources accepted for the surface state
#'
#' MOD13A2 (1 km, already on the working grid; the provisional
#' recommendation of MP-05). MOD13Q1 needs the 250 m grid, whose nesting
#' factor is `TODO` (section 4); the daily reflectance path (MOD09GA/GQ,
#' option T4) needs the order of aggregation and NDVI and the QA of the
#' 1 km state layer at 500 m, not specified (MP-05, A-M4-1).
#'
#' @return A list with `available` and `planned` (named reasons).
#' @noRd
modis_ndvi_sources <- function() {
  list(
    available = "MOD13A2",
    planned = c(
      MOD13Q1 = paste0("the 250 m grid and its nesting factor are TODO ",
                       "(dev/specs/modis-products.md 4 and 9.2)"),
      MOD09GA = paste0("the daily reflectance path (option T4) needs the ",
                       "order of aggregation and NDVI and the QA of the 1 km ",
                       "state layer at 500 m, not specified (MP-05, A-M4-1)"),
      MOD09GQ = paste0("the 250 m grid and its nesting factor are TODO ",
                       "(dev/specs/modis-products.md 4 and 9.2)")
    )
  )
}

#' Layers read for one role of the surface state
#'
#' @param role Character: `"lst"`, `"albedo"`, `"ndvi"` or `"lai"`.
#' @param options An `earthflux_modis_surface_options` object.
#' @return A list with `product` (the product expected for the role),
#'   `required` and `optional` (SDS names of the product table; optional
#'   layers are always read from an HDF4 file and read from converted files
#'   only when declared).
#' @noRd
modis_surface_layers <- function(role, options) {
  switch(role,
    lst = list(product = options$lst_product,
               required = c("LST_Day_1km", "QC_Day", "Day_view_time"),
               optional = modis_band_emissivity_layers(options$lst_product)),
    albedo = list(
      product = "MCD43A3",
      required = c(
        switch(options$albedo_method,
               blue_sky = c("Albedo_BSA_shortwave", "Albedo_WSA_shortwave"),
               white_sky = "Albedo_WSA_shortwave",
               black_sky = "Albedo_BSA_shortwave"),
        "BRDF_Albedo_Band_Mandatory_Quality_shortwave"
      ),
      optional = character(0)
    ),
    ndvi = list(
      product = options$ndvi_source,
      required = c(
        "1 km 16 days NDVI", "1 km 16 days VI Quality",
        if (options$composite_method[["ndvi"]] == "period_pixel_lag") {
          "1 km 16 days composite day of the year"
        }
      ),
      optional = character(0)
    ),
    lai = list(product = "MCD15A2H",
               required = c("Lai_500m", "FparLai_QC"),
               optional = "FparExtra_QC")
  )
}

# Sources -----------------------------------------------------------------------

#' Declare the file(s) of one MODIS product for the surface state
#'
#' @description
#' Either an **official HDF4/HDF-EOS file** named with the MODIS convention
#' (one tile; product, UTC date, tile and collection are parsed from the
#' name, dev/specs/modis-products.md section 4), or a set of **converted
#' single-band rasters** (GeoTIFF, ...), one per layer, declared with their
#' product, UTC date and scaling (decision MP-10, M4-06): nothing is
#' inferred from the name of a converted file.
#'
#' @param path Character. An unnamed path of one HDF4 file, or a named
#'   character vector of converted files whose names are SDS names of the
#'   product table (e.g. `c(LST_Day_1km = "lst.tif", QC_Day = "qc.tif",
#'   Day_view_time = "vt.tif")`).
#' @param product Character. Product short name. Required for converted
#'   files; for an HDF4 file it may be given and must match the name.
#' @param date `Date`, length 1. UTC data day (nominal date of the file).
#'   Required for converted files; for an HDF4 file it may be given and must
#'   match the name.
#' @param scaled Logical, no default for converted files: whether the value
#'   layers already hold physical values (`TRUE`) or raw DN (`FALSE`); see
#'   `modis_read_converted()`. Layers without a conversion (QA, composite
#'   day of the year) are always read as DN. Must be `NULL` for HDF4.
#' @param period `Date` vector of length 2 (first and last day, inclusive)
#'   of the composite period, or `NULL`. Required for a composite matched
#'   with `"period"` or `"period_pixel_lag"`: the relation between the date
#'   in the file name and the period of MOD13 and MCD15 composites is not
#'   stated in the specification, so the caller supplies it (e.g. from the
#'   `RangeBeginningDate`/`RangeEndingDate` of the granule metadata).
#' @param collection Character. Collection of converted files (`"061"`);
#'   for an HDF4 file the collection of the name is used.
#' @return A specification object of class `earthflux_modis_source` (a list
#'   with `type` = `"hdf4"` or `"converted"`, `path`, `product`, `date`,
#'   `collection`, `tile`, `production`, `scaled` and `period`). Errors:
#'   malformed paths, names or declarations -> `earthflux_input_error`
#'   (`earthflux_missing_input` for a missing declaration,
#'   `earthflux_modis_filename_error` for an HDF4 name outside the
#'   convention, `earthflux_modis_unsupported` for unknown products or
#'   layers).
#' @noRd
modis_source <- function(path, product = NULL, date = NULL, scaled = NULL,
                         period = NULL, collection = "061") {
  call <- sys.call()
  if (!is.character(path) || length(path) == 0L || anyNA(path) ||
      any(!nzchar(path))) {
    ef_abort("`path` must be a non-empty character vector of file paths.",
             class = "earthflux_input_error", call = call)
  }
  if (is.null(names(path))) {
    if (length(path) != 1L) {
      ef_abort(
        paste0("An official source is one HDF4 file (one tile); mosaics of ",
               "several tiles are not assembled here."),
        class = "earthflux_input_error", call = call
      )
    }
    info <- modis_parse_filename(path)
    given <- list(product = product, date = date)
    for (nm in names(given)) {
      if (!is.null(given[[nm]]) &&
          !identical(format(given[[nm]]), format(info[[nm]]))) {
        ef_abort(
          sprintf("`%s` does not match the name of \"%s\".", nm, info$file),
          class = "earthflux_input_error", call = call
        )
      }
    }
    if (!is.null(scaled)) {
      ef_abort("`scaled` is only declared for converted files; leave it NULL.",
               class = "earthflux_input_error", call = call)
    }
    out <- list(type = "hdf4", path = path, product = info$product,
                date = info$date, collection = info$collection,
                tile = info$tile, production = info$production,
                scaled = NULL)
  } else {
    nms <- names(path)
    if (any(is.na(nms) | !nzchar(nms)) || anyDuplicated(nms) > 0L) {
      ef_abort("The names of `path` (layers) must be unique and non-empty.",
               class = "earthflux_input_error", call = call)
    }
    if (is.null(product) || is.null(date) || is.null(scaled)) {
      ef_abort(
        paste0("Converted files need explicit `product`, `date` (UTC) and ",
               "`scaled` (decision MP-10)."),
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
    check_string(product)
    check_string(collection)
    modis_check_date(date, "date", scalar = TRUE, call = call)
    if (!is.logical(scaled) || length(scaled) != 1L || is.na(scaled)) {
      ef_abort("`scaled` must be TRUE or FALSE.",
               class = "earthflux_input_error", call = call)
    }
    for (layer in nms) {
      modis_layer_spec(product, layer, collection)
    }
    out <- list(type = "converted", path = path, product = product,
                date = date, collection = collection, tile = NA_character_,
                production = .POSIXct(NA_real_, tz = "UTC"),
                scaled = scaled)
  }
  if (!is.null(period)) {
    modis_check_date(period, "period", call = call)
    if (length(period) != 2L || period[2L] < period[1L]) {
      ef_abort(
        "`period` must be two dates (first and last day), in order.",
        class = "earthflux_input_error", call = call
      )
    }
  }
  out$period <- period
  structure(out, class = "earthflux_modis_source")
}

#' Turn an element of `files` into a source
#' @noRd
as_modis_source <- function(x, role, call) {
  if (inherits(x, "earthflux_modis_source")) {
    return(x)
  }
  if (is.character(x) && length(x) == 1L && is.null(names(x))) {
    return(modis_source(x))
  }
  ef_abort(
    sprintf(paste0("`files$%s` must be the path of an HDF4 file or a ",
                   "modis_source() declaration."), role),
    class = "earthflux_input_error", call = call
  )
}

#' Read the DN layers of a source
#'
#' @param src An `earthflux_modis_source`.
#' @param layers List with `required` and `optional` SDS names.
#' @param aoi Area of interest (see `modis_read_raw()`).
#' @return A `SpatRaster` of DN, one layer per layer read, named as in the
#'   product table.
#' @noRd
modis_read_source_layers <- function(src, layers, aoi, call) {
  if (src$type == "hdf4") {
    return(modis_read_raw(src$path, c(layers$required, layers$optional),
                          aoi = aoi))
  }
  given <- names(src$path)
  absent <- setdiff(layers$required, given)
  if (length(absent) > 0L) {
    ef_abort(
      sprintf("The %s source lacks the layer(s) %s.", src$product,
              paste0("\"", absent, "\"", collapse = ", ")),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  unused <- setdiff(given, c(layers$required, layers$optional))
  if (length(unused) > 0L) {
    ef_abort(
      sprintf(paste0("Layer(s) %s of the %s source are not used with these ",
                     "options; remove them."),
              paste0("\"", unused, "\"", collapse = ", "), src$product),
      class = "earthflux_input_error", call = call
    )
  }
  read <- c(layers$required, intersect(layers$optional, given))
  parts <- lapply(read, function(layer) {
    row <- modis_layer_spec(src$product, layer, src$collection)
    scaled <- if (row$conversion == "none") FALSE else src$scaled
    modis_read_converted(src$path[[layer]], src$product, layer,
                         scaled = scaled, aoi = aoi,
                         collection = src$collection)
  })
  for (k in seq_along(parts)[-1L]) {
    if (!isTRUE(terra::compareGeom(parts[[1L]], parts[[k]],
                                   stopOnError = FALSE))) {
      ef_abort(
        sprintf("Layers \"%s\" and \"%s\" of the %s source differ in geometry.",
                read[1L], read[k], src$product),
        class = c("earthflux_modis_grid_error", "earthflux_input_error"),
        call = call
      )
    }
  }
  terra::rast(parts)
}

# Options -----------------------------------------------------------------------

#' Options of the MODIS surface state
#'
#' @description
#' Collects and checks the choices of `modis_surface_state()`. Every
#' scientific choice is explicit and has no default (T-15; decisions MP-01,
#' MP-03, MP-04, MP-05, MP-07, MP-08 and MP-09 are open or provisional).
#' The only argument with a default, `lai_nonveg = NULL`, keeps the
#' documented behaviour (no value is assigned; MP-06).
#'
#' @param lst_product Character. `"MOD11A1"` (Terra) or `"MYD11A1"` (Aqua)
#'   (MP-01, MP-02). `"MOD21A1D"`/`"MYD21A1D"` raise
#'   `earthflux_method_not_implemented` (view time `TODO`).
#' @param albedo_method Character. Method of `modis_albedo()`:
#'   `"blue_sky"`, `"white_sky"` or `"black_sky"` (MP-03, `CANDIDATA`).
#' @param diffuse_fraction With `"blue_sky"`: diffuse fraction \[-\], a number
#'   in \[0, 1\] or a single-layer `SpatRaster` on the working grid (its
#'   model is open, T-11); `NULL` otherwise.
#' @param emissivity_method Character. Method of
#'   `modis_broadband_emissivity()`: `"lai_empirical"` (E3, `VERIFICADA
#'   (SEBAL-Idaho 2002)` as a formulation; its consistency with the LST
#'   product is open, RC-14, MP-04).
#' @param ndvi_source Character. `"MOD13A2"` (MP-05); other sources raise
#'   `earthflux_method_not_implemented`.
#' @param composite_method Named character with elements `albedo`, `ndvi`
#'   and `lai`: methods of `modis_match_composite()` (MP-07). `"same_day"`
#'   matches the nominal date of the file; `"period"` and
#'   `"period_pixel_lag"` need the `period` of the source;
#'   `"period_pixel_lag"` only for NDVI (MOD13 composite day of the year;
#'   MCD43A3 and MCD15A2H have no such layer).
#' @param resampling_method Character. Aggregation of the 500 m layers
#'   (albedo inputs, LAI) to the working grid (MP-08): `"mean"` or
#'   `"median"`; one value for both, or named `c(albedo = , lai = )`.
#' @param min_valid_fraction Numeric in (0, 1\]: minimum fraction of valid
#'   sub-cells (threshold `TODO`, no default).
#' @param qa_policy,mask_codes QA policy (`"flag"` or `"mask"`) and, with
#'   `"mask"`, the codes to mask (MP-09; see `modis_qa_flags()`).
#' @param lai_nonveg Explicit LAI \[m2 m-2\] of the non-vegetated MCD15A2H
#'   classes 249-254 (MP-06; A-M4-6). `NULL` (default) keeps them `NA`
#'   with `EF_SURF_LAI_NONVEG`, so the E3 emissivity (and Rn, G downstream)
#'   is `NA` there; a single number (e.g. `0`) is assigned to the six
#'   classes; a vector named by class code (e.g. `c("253" = 0, "250" =
#'   0)`) assigns per class and leaves the others `NA`. Assigned cells
#'   carry `EF_SURF_LAI_ASSIGNED` in `flags_lai` and `flags_emissivity`;
#'   the value is recorded in the provenance (`methods$lai_nonveg`,
#'   `CANDIDATA`). See `modis_lai()`.
#' @return A specification object of class
#'   `earthflux_modis_surface_options` (a list of the checked choices;
#'   `lai_nonveg` as a vector named by class code, or `NULL`).
#' @noRd
modis_surface_options <- function(lst_product, albedo_method,
                                  diffuse_fraction = NULL, emissivity_method,
                                  ndvi_source, composite_method,
                                  resampling_method, min_valid_fraction,
                                  qa_policy, mask_codes = NULL,
                                  lai_nonveg = NULL) {
  call <- sys.call()
  m <- modis_lst_products()
  modis_check_method(lst_product, m$available, m$planned, call = call,
                     arg = "lst_product")
  m <- modis_albedo_methods()
  modis_check_method(albedo_method, m$available, m$planned, call = call,
                     arg = "albedo_method")
  if (albedo_method == "blue_sky") {
    if (is.null(diffuse_fraction)) {
      ef_abort(
        paste0("`albedo_method = \"blue_sky\"` requires `diffuse_fraction` ",
               "(no default: its model is open, T-11)."),
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
    if (inherits(diffuse_fraction, "SpatRaster")) {
      if (terra::nlyr(diffuse_fraction) != 1L) {
        ef_abort("`diffuse_fraction` must be a single-layer SpatRaster.",
                 class = "earthflux_input_error", call = call)
      }
    } else {
      check_scalar(diffuse_fraction, "diffuse_fraction", lower = 0,
                   upper = 1, call = call)
    }
  } else if (!is.null(diffuse_fraction)) {
    ef_abort(
      sprintf(paste0("`diffuse_fraction` is not used by `albedo_method = ",
                     "\"%s\"`; leave it NULL."), albedo_method),
      class = "earthflux_input_error", call = call
    )
  }
  m <- modis_emissivity_methods()
  modis_check_method(emissivity_method, m$available, m$planned, call = call,
                     arg = "emissivity_method")
  m <- modis_ndvi_sources()
  modis_check_method(ndvi_source, m$available, m$planned, call = call,
                     arg = "ndvi_source")

  roles <- c("albedo", "ndvi", "lai")
  if (missing(composite_method)) {
    ef_abort("`composite_method` must be supplied: c(albedo = , ndvi = , lai = ).",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  if (!is.character(composite_method) ||
      !setequal(names(composite_method), roles) ||
      length(composite_method) != length(roles)) {
    ef_abort(
      "`composite_method` must be a character vector named albedo, ndvi, lai.",
      class = "earthflux_input_error", call = call
    )
  }
  m <- modis_composite_methods()
  for (r in roles) {
    modis_check_method(composite_method[[r]], m$available, m$planned,
                       call = call, arg = sprintf("composite_method[[\"%s\"]]", r))
  }
  if (any(composite_method[c("albedo", "lai")] == "period_pixel_lag")) {
    ef_abort(
      paste0("`\"period_pixel_lag\"` needs a composite day of the year per ",
             "pixel, which only MOD13 provides (NDVI)."),
      class = "earthflux_input_error", call = call
    )
  }
  composite_method <- composite_method[roles]

  if (missing(resampling_method)) {
    ef_abort("`resampling_method` must be supplied: \"mean\" or \"median\".",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  if (!is.character(resampling_method)) {
    ef_abort("`resampling_method` must be character.",
             class = "earthflux_input_error", call = call)
  }
  agg <- c("albedo", "lai")
  if (length(resampling_method) == 1L && is.null(names(resampling_method))) {
    resampling_method <- stats::setNames(rep(resampling_method, 2L), agg)
  }
  if (!setequal(names(resampling_method), agg) ||
      length(resampling_method) != 2L) {
    ef_abort(
      "`resampling_method` must be one value or a vector named albedo, lai.",
      class = "earthflux_input_error", call = call
    )
  }
  m <- modis_grid_methods()
  for (r in agg) {
    a <- sprintf("resampling_method[[\"%s\"]]", r)
    modis_check_method(resampling_method[[r]], m$available, m$planned,
                       call = call, arg = a)
    if (!resampling_method[[r]] %in% c("mean", "median")) {
      ef_abort(
        sprintf(paste0("`%s = \"%s\"` is for classes or QA masks; continuous ",
                       "variables use \"mean\" or \"median\"."),
                a, resampling_method[[r]]),
        class = "earthflux_input_error", call = call
      )
    }
  }
  resampling_method <- resampling_method[agg]

  if (missing(min_valid_fraction)) {
    ef_abort("`min_valid_fraction` must be supplied explicitly.",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  check_scalar(min_valid_fraction, "min_valid_fraction", lower = 0,
               upper = 1, lower_inclusive = FALSE, call = call)
  mask_codes <- check_qa_policy(qa_policy, mask_codes, call = call)
  lai_nonveg <- check_lai_nonveg(lai_nonveg, call = call)

  structure(
    list(lst_product = lst_product, albedo_method = albedo_method,
         diffuse_fraction = diffuse_fraction,
         emissivity_method = emissivity_method, ndvi_source = ndvi_source,
         composite_method = composite_method,
         resampling_method = resampling_method,
         min_valid_fraction = min_valid_fraction, qa_policy = qa_policy,
         mask_codes = mask_codes, lai_nonveg = lai_nonveg),
    class = "earthflux_modis_surface_options"
  )
}

# Helpers -------------------------------------------------------------------------

#' Bring a converted MODIS variable to the working grid with its masks
#'
#' The values are aggregated with `modis_to_grid()` (`method`,
#' `min_valid_fraction`); every mask is aggregated with `"any"` (worst case
#' of the sub-cells, section 9.2). The masks of the causes of `NA`
#' (`EF_INPUT_NA` and `modis_na_codes()`) are kept only where the
#' aggregated value is `NA`: they explain why the cell has no value, not
#' that one sub-cell had none. The masks of kept values (QA warnings) keep
#' the worst case. On the same grid (factor 1) nothing changes.
#'
#' @param var Result of `modis_variable()` (or a converter built on it) on
#'   the cells of `geometry`.
#' @param geometry `SpatRaster` with the native geometry of `var`.
#' @param template `SpatRaster` of the working grid.
#' @param method,min_valid_fraction See `modis_to_grid()`.
#' @param name Character. Name of the value layer.
#' @return A list with `value` (numeric, cell order of `template`),
#'   `valid_fraction` (`SpatRaster`) and `masks` (named logical vectors).
#' @noRd
surface_to_grid <- function(var, geometry, template, method,
                            min_valid_fraction, name) {
  value_r <- modis_as_raster(var$value, geometry, name)
  g <- modis_to_grid(value_r, template, method, min_valid_fraction)
  value <- terra::values(g$value, mat = FALSE)
  codes <- names(var$masks)
  mr <- terra::rast(lapply(codes, function(code) {
    modis_as_raster(as.numeric(var$masks[[code]]), geometry, code)
  }))
  ga <- modis_to_grid(mr, template, "any", min_valid_fraction)$value
  na_codes <- c("EF_INPUT_NA", modis_na_codes())
  masks <- lapply(seq_along(codes), function(k) {
    m <- terra::values(ga[[k]], mat = FALSE)
    m <- !is.na(m) & m == 1
    if (codes[k] %in% na_codes) m <- m & is.na(value)
    m
  })
  names(masks) <- codes
  list(value = value, valid_fraction = g$valid_fraction, masks = masks)
}

#' Select the composite of a source for the LST date
#' @noRd
surface_match <- function(src, role, lst_date, method, composite_doy, call) {
  if (method == "same_day") {
    res <- modis_match_composite(lst_date, src$date, method = method)
  } else {
    if (is.null(src$period)) {
      ef_abort(
        sprintf(paste0("`composite_method[[\"%s\"]] = \"%s\"` needs the ",
                       "composite `period` of the %s source (modis_source())."),
                role, method, src$product),
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
    res <- modis_match_composite(
      lst_date, src$period[1L], src$period[2L], method = method,
      composite_doy = if (method == "period_pixel_lag") composite_doy
    )
  }
  if (is.na(res$index)) {
    ef_abort(
      sprintf(paste0("The %s source (%s) does not match the LST date %s with ",
                     "`composite_method[[\"%s\"]] = \"%s\"`."),
              src$product,
              if (is.null(src$period)) format(src$date) else
                paste(format(src$period), collapse = " to "),
              format(lst_date), role, method),
      class = "earthflux_input_error", call = call
    )
  }
  res
}

#' Records of the flags of one layer, with the layer as `target`
#' @noRd
surface_flags <- function(masks, target) {
  recs <- ef_diagnose_surface(masks)
  evaluated <- ef_flags_evaluated(recs)
  recs <- lapply(recs, function(f) {
    f$target <- target
    f
  })
  attr(recs, "evaluated") <- evaluated
  recs
}

# Surface state -----------------------------------------------------------------

#' Surface state of one MODIS scene on the working grid
#'
#' @description
#' Assembles the surface contract of dev/ARCHITECTURE.md section 4 from
#' MODIS files of one scene (one LST date, one tile), with the preparation
#' steps of R/io-modis.R, R/modis-qa.R and R/prep-modis.R:
#'
#' 1. LST (MOD11A1/MYD11A1 `LST_Day_1km`, `QC_Day`) read on the area of
#'    interest; its 1 km sinusoidal grid is the working grid (MP-08). The
#'    band 31/32 emissivities (`Emis_31`, `Emis_32`,
#'    `modis_band_emissivity()`) are read with it (always from an HDF4
#'    file; from converted files when declared) and carried as
#'    `band_emissivity`: no broadband value is computed from them (E1 is
#'    not implemented, dev/specs/modis-products.md 8.2).
#' 2. Overpass instant from `Day_view_time` and the longitude of the cell
#'    centres (`modis_overpass_time()`, local mean solar time -> UTC, no
#'    equation of time).
#' 3. Broadband albedo: MCD43A3 black-/white-sky shortwave albedos with their
#'    mandatory quality, aggregated to the working grid, then
#'    `modis_albedo()` (aggregation before the combination, so that a
#'    diffuse fraction on the working grid can be used).
#' 4. NDVI: MOD13A2 with `VI Quality` (and the composite day of the year
#'    for the per-pixel lag).
#' 5. LAI: MCD15A2H with `FparLai_QC` (and `FparExtra_QC` when available),
#'    non-vegetated classes `NA` or, with the option `lai_nonveg`, the
#'    explicit LAI assigned to them at 500 m (MP-06, `modis_lai()`),
#'    aggregated to the working grid.
#' 6. Broadband emissivity from the LAI on the working grid
#'    (`modis_broadband_emissivity()`).
#' 7. Composites matched to the LST date (`modis_match_composite()`).
#'
#' @param files Named list with elements `lst`, `albedo`, `ndvi` and `lai`:
#'   each the path of an official HDF4 file or a `modis_source()`
#'   declaration (converted files).
#' @param aoi Area of interest: `NULL` (whole LST file), a `SpatVector` in
#'   any CRS or a `SpatExtent` in the CRS of the LST file. No default.
#' @param options An `earthflux_modis_surface_options` object
#'   (`modis_surface_options()`), or a list of its arguments.
#'
#' @return An object of class `earthflux_surface_state` (built with
#'   `new_ef_object()`), a list:
#'   * `lst` \[K\], `albedo` \[-\], `ndvi` \[-\], `lai` \[m2 m-2\],
#'     `emissivity` \[-\]: single-layer `SpatRaster`s on the working grid;
#'   * `band_emissivity`: two-layer `SpatRaster` (`emis_31`, `emis_32`)
#'     \[-\] of the MOD11A1/MYD11A1 band emissivities on the working grid,
#'     or `NULL` when a converted LST source does not declare them (not an
#'     input of the METRIC core: reserved for option E1);
#'   * `overpass_time`: list with `doy` and `utc_hour` (single-layer
#'     `SpatRaster`s; day of year of the UTC date and UTC hour, the time
#'     inputs of the core) and `time` (`POSIXct`, UTC, terra cell order);
#'   * `lonlat`: two-layer `SpatRaster` (`lon`, `lat`) \[degrees\] of the cell
#'     centres (WGS84);
#'   * `qa`: list with `flag_word` (`SpatRaster`, one integer layer per
#'     output: `flags_lst`, `flags_overpass_time`, `flags_albedo`,
#'     `flags_ndvi`, `flags_lai`, `flags_emissivity` and, with
#'     `band_emissivity`, `flags_emis_31`, `flags_emis_32`), `flag_bits` (bit,
#'     code, severity, description of the INPUT/SURF cell codes, a view of
#'     the registry), `valid_fraction` (`SpatRaster` of the fraction of
#'     valid sub-cells of each aggregated input), `composite` (per product:
#'     matched period, `lag_bound_days` and, for NDVI with
#'     `"period_pixel_lag"`, the per-pixel `lag_days` `SpatRaster`) and
#'     `policy` (`qa_policy`, `mask_codes`, `n_masked` per input at its
#'     native resolution);
#'   * `units`: named character vector of the units;
#'   * `flags`: `earthflux_flag` records (cell scope, index = cell of the
#'     working grid), one per code flagged in a layer, with `target` = the
#'     layer;
#'   * `provenance`: `modis_provenance()` plus `flags_evaluated`,
#'     `flags_evaluated_by_target` and `flags` (registry rows, policies and
#'     counts, dev/specs/flags.md 6.7).
#'
#' @details
#' **Flags.** Besides the codes of the converters, the stage raises
#' `EF_SURF_OVERPASS_MISSING` in `flags_overpass_time` where the LST is
#' valid and the view time is missing (fill, out of range or missing DN),
#' and `EF_SURF_ALBEDO_GT1` (class III, `critical`) in `flags_albedo` where
#' the broadband albedo is above 1 (value kept). The emissivity carries
#' `EF_INPUT_NA` where the LAI is `NA` and `EF_SURF_LAI_ASSIGNED` where it
#' is computed from an assigned LAI (option `lai_nonveg`; the LAI carries it
#' where any of its sub-cells was assigned). The band emissivities carry
#' the codes of their scaling (`EF_INPUT_NA`, `EF_SURF_FILL`,
#' `EF_SURF_DN_OUT_OF_RANGE`). For aggregated layers, the masks of the
#' sub-cells are combined as described in `surface_to_grid()`.
#'
#' **Handing the state to the METRIC core** (M5): see
#' dev/ARCHITECTURE.md section 4 and `surface_exclusion()`.
#'
#' Errors: malformed `files`, `options` or sources -> classed input errors;
#' sources of the wrong product, composites that do not match the LST date,
#' or grids that do not nest -> `earthflux_input_error` (grid errors also
#' `earthflux_modis_grid_error`); the classed errors of the readers and of
#' the preparation steps propagate.
#'
#' @section Verification status:
#' Assembly only; the status of each step is that of the function used:
#' product facts `VERIFICADA` (product table), view time conversion and
#' broadband albedo `CANDIDATA`, broadband emissivity E3 `VERIFICADA
#' (SEBAL-Idaho 2002)` as a formulation (RC-14 open), the assigned LAI of the
#' non-vegetated classes `CANDIDATA` (MP-06), NDVI and band emissivities
#' `VERIFICADA` (product layers), temporal matching and aggregation
#' provisional decisions (MP-07, MP-08). Not contrasted with a real granule
#' yet (A-M4-3).
#' @noRd
modis_surface_state <- function(files, aoi, options) {
  call <- sys.call()
  if (missing(aoi)) {
    ef_abort("`aoi` must be supplied (NULL for the whole LST file).",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  if (is.list(options) && !inherits(options, "earthflux_modis_surface_options")) {
    options <- do.call(modis_surface_options, options)
  }
  if (!inherits(options, "earthflux_modis_surface_options")) {
    ef_abort("`options` must come from modis_surface_options().",
             class = "earthflux_input_error", call = call)
  }
  roles <- c("lst", "albedo", "ndvi", "lai")
  if (!is.list(files) || !setequal(names(files), roles) ||
      length(files) != length(roles)) {
    ef_abort("`files` must be a list named lst, albedo, ndvi, lai.",
             class = "earthflux_input_error", call = call)
  }
  sources <- lapply(roles, function(r) as_modis_source(files[[r]], r, call))
  names(sources) <- roles
  layers <- lapply(roles, modis_surface_layers, options = options)
  names(layers) <- roles
  for (r in roles) {
    if (sources[[r]]$product != layers[[r]]$product) {
      ef_abort(
        sprintf("`files$%s` is %s; these options need %s.", r,
                sources[[r]]$product, layers[[r]]$product),
        class = "earthflux_input_error", call = call
      )
    }
  }
  qa_policy <- options$qa_policy
  mask_codes <- options$mask_codes
  mvf <- options$min_valid_fraction

  # 1. LST and the working grid --------------------------------------------
  src <- sources$lst
  lst_date <- src$date
  dn <- modis_read_source_layers(src, layers$lst, aoi, call)
  template <- terra::rast(dn, nlyrs = 1L)
  lst <- modis_lst(dn[["LST_Day_1km"]], dn[["QC_Day"]], src$product,
                   qa_policy = qa_policy, mask_codes = mask_codes,
                   collection = src$collection)
  rows <- list(lst$source)

  # 2. Overpass instant -----------------------------------------------------
  lonlat <- modis_cell_lonlat(template)
  vt <- modis_variable(dn[["Day_view_time"]], src$product, "Day_view_time",
                       list(), NULL, collection = src$collection)
  rows <- c(rows, list(vt$source))
  ov <- modis_overpass_time(modis_as_raster(vt$value, template, "view_time"),
                            lon_deg = lonlat[["lon"]], date_utc = lst_date)
  lst_valid <- !is.na(lst$value)
  ov_masks <- vt$masks
  ov_masks$EF_SURF_OVERPASS_MISSING <-
    terra::values(ov$missing, mat = FALSE) == 1 & lst_valid
  ov_masks <- modis_order_masks(ov_masks)
  names(ov$doy) <- "doy"
  names(ov$utc_hour) <- "utc_hour"

  # Band emissivities (inputs of option E1, carried only) -----------------
  band_emis <- list()
  for (layer in intersect(layers$lst$optional, names(dn))) {
    be <- modis_band_emissivity(dn[[layer]], src$product,
                                sub("^Emis_", "", layer),
                                collection = src$collection)
    rows <- c(rows, list(be$source))
    band_emis[[tolower(layer)]] <- be
  }

  # Inputs on other grids are read on the extent of the working grid.
  grid_ext <- terra::ext(template)
  composite <- list()
  valid_fraction <- list()
  n_masked <- list(lst = lst$policy$n_masked)

  # 3. Broadband albedo -----------------------------------------------------
  src <- sources$albedo
  composite$albedo <- surface_match(src, "albedo", lst_date,
                                    options$composite_method[["albedo"]],
                                    NULL, call)
  dn <- modis_read_source_layers(src, layers$albedo, grid_ext, call)
  q <- "BRDF_Albedo_Band_Mandatory_Quality_shortwave"
  alb_in <- list()
  for (layer in setdiff(layers$albedo$required, q)) {
    v <- modis_variable(dn[[layer]], src$product, layer,
                        stats::setNames(list(dn[[q]]), q), qa_policy,
                        mask_codes, collection = src$collection)
    rows <- c(rows, list(v$source))
    n_masked[[layer]] <- v$policy$n_masked
    g <- surface_to_grid(v, dn, template,
                         options$resampling_method[["albedo"]], mvf, layer)
    valid_fraction[[layer]] <- g$valid_fraction
    alb_in[[layer]] <- g
  }
  as_r <- function(name) {
    if (is.null(alb_in[[name]])) NULL else
      modis_as_raster(alb_in[[name]]$value, template, name)
  }
  df <- options$diffuse_fraction
  if (inherits(df, "SpatRaster") &&
      !isTRUE(terra::compareGeom(df, template, stopOnError = FALSE))) {
    ef_abort("`diffuse_fraction` must be on the working grid (the LST grid).",
             class = c("earthflux_modis_grid_error", "earthflux_input_error"),
             call = call)
  }
  alb <- modis_albedo(bsa = as_r("Albedo_BSA_shortwave"),
                      wsa = as_r("Albedo_WSA_shortwave"),
                      diffuse_fraction = df, method = options$albedo_method)
  albedo_v <- terra::values(alb$albedo, mat = FALSE)
  alb_masks <- Reduce(modis_merge_masks, lapply(alb_in, `[[`, "masks"))
  if (inherits(df, "SpatRaster")) {
    df_na <- is.na(terra::values(df, mat = FALSE)) & is.na(albedo_v)
    alb_masks$EF_INPUT_NA <- alb_masks$EF_INPUT_NA | df_na
  }
  alb_masks$EF_SURF_ALBEDO_GT1 <- terra::values(alb$gt1, mat = FALSE) == 1 &
    !is.na(albedo_v)
  alb_masks <- modis_order_masks(alb_masks)

  # 4. NDVI -------------------------------------------------------------------
  src <- sources$ndvi
  dn <- modis_read_source_layers(src, layers$ndvi, grid_ext, call)
  nd <- modis_variable(dn[["1 km 16 days NDVI"]], src$product,
                       "1 km 16 days NDVI",
                       list("1 km 16 days VI Quality" =
                              dn[["1 km 16 days VI Quality"]]),
                       qa_policy, mask_codes, collection = src$collection)
  rows <- c(rows, list(nd$source))
  n_masked$ndvi <- nd$policy$n_masked
  # MOD13A2 is on the working grid (factor 1): the aggregation method is
  # not used, the call only checks the grid and builds the masks.
  ndvi_g <- surface_to_grid(nd, dn, template, "mean", mvf, "ndvi")
  cdoy <- NULL
  if (options$composite_method[["ndvi"]] == "period_pixel_lag") {
    layer <- "1 km 16 days composite day of the year"
    cd <- modis_variable(dn[[layer]], src$product, layer, list(), NULL,
                         collection = src$collection)
    rows <- c(rows, list(cd$source))
    cdoy <- modis_as_raster(cd$value, template, "composite_doy")
  }
  composite$ndvi <- surface_match(src, "ndvi", lst_date,
                                  options$composite_method[["ndvi"]], cdoy,
                                  call)

  # 5. LAI --------------------------------------------------------------------
  src <- sources$lai
  composite$lai <- surface_match(src, "lai", lst_date,
                                 options$composite_method[["lai"]], NULL,
                                 call)
  dn <- modis_read_source_layers(src, layers$lai, grid_ext, call)
  extra <- if ("FparExtra_QC" %in% names(dn)) dn[["FparExtra_QC"]] else NULL
  la <- modis_lai(dn[["Lai_500m"]], dn[["FparLai_QC"]], extra, qa_policy,
                  mask_codes, collection = src$collection,
                  lai_nonveg = options$lai_nonveg)
  rows <- c(rows, list(la$source))
  n_masked$lai <- la$policy$n_masked
  lai_g <- surface_to_grid(la, dn, template,
                           options$resampling_method[["lai"]], mvf, "lai")
  valid_fraction$lai <- lai_g$valid_fraction
  lai_r <- modis_as_raster(lai_g$value, template, "lai")

  # 6. Broadband emissivity ---------------------------------------------------
  emissivity <- modis_broadband_emissivity(lai = lai_r,
                                           method = options$emissivity_method)
  names(emissivity) <- "emissivity"
  emis_masks <- list(EF_INPUT_NA = is.na(lai_g$value))
  if (!is.null(lai_g$masks$EF_SURF_LAI_ASSIGNED)) {
    emis_masks$EF_SURF_LAI_ASSIGNED <- lai_g$masks$EF_SURF_LAI_ASSIGNED &
      !is.na(lai_g$value)
  }
  emis_masks <- modis_order_masks(emis_masks)

  # Flags -------------------------------------------------------------------
  masks <- c(list(lst = lst$masks, overpass_time = ov_masks,
                  albedo = alb_masks, ndvi = ndvi_g$masks, lai = lai_g$masks,
                  emissivity = emis_masks),
             lapply(band_emis, `[[`, "masks"))
  words <- terra::rast(lapply(names(masks), function(l) {
    modis_as_raster(modis_flag_word(masks[[l]]), template, paste0("flags_", l))
  }))
  recs <- lapply(names(masks), function(l) surface_flags(masks[[l]], l))
  names(recs) <- names(masks)
  evaluated_by_target <- lapply(recs, ef_flags_evaluated)
  flags <- unname(do.call(c, lapply(recs, function(r) {
    attr(r, "evaluated") <- NULL
    unname(r)
  })))
  if (is.null(flags)) flags <- list()
  evaluated <- unique(unlist(evaluated_by_target, use.names = FALSE))

  reg <- ef_flag_registry()
  bits <- reg[reg$stage %in% c("INPUT", "SURF") & !is.na(reg$bit),
              c("bit", "code", "severity", "description")]
  bits <- bits[order(bits$bit), ]
  rownames(bits) <- NULL
  counts <- do.call(rbind, lapply(names(masks), function(l) {
    data.frame(target = l, code = names(masks[[l]]),
               n_flagged = vapply(masks[[l]], sum, integer(1)),
               n_total = terra::ncell(template), stringsAsFactors = FALSE)
  }))
  rownames(counts) <- NULL
  policy <- list(qa_policy = qa_policy, mask_codes = mask_codes,
                 n_masked = n_masked)

  provenance <- modis_provenance(sources, options,
                                 unique(do.call(rbind, rows)))
  provenance$flags_evaluated <- evaluated
  provenance$flags_evaluated_by_target <- evaluated_by_target
  provenance$flags <- list(
    package_version = as.character(getNamespaceVersion("EarthFlux")),
    registry = reg[reg$code %in% evaluated,
                   c("code", "stage", "severity", "scope", "bit",
                     "description", "since")],
    evaluated = evaluated_by_target,
    bit_tables = list(stage = "SURF", bits = bits[, c("bit", "code",
                                                      "severity")]),
    policies = policy,
    counts = counts
  )

  lst_r <- modis_as_raster(lst$value, template, "lst")
  albedo_r <- alb$albedo
  names(albedo_r) <- "albedo"
  ndvi_r <- modis_as_raster(ndvi_g$value, template, "ndvi")
  band_emis_r <- if (length(band_emis) > 0L) {
    terra::rast(lapply(names(band_emis), function(l) {
      modis_as_raster(band_emis[[l]]$value, template, l)
    }))
  }

  new_ef_object(
    list(
      lst = lst_r,
      albedo = albedo_r,
      ndvi = ndvi_r,
      lai = lai_r,
      emissivity = emissivity,
      band_emissivity = band_emis_r,
      overpass_time = list(doy = ov$doy, utc_hour = ov$utc_hour,
                           time = ov$time),
      lonlat = lonlat,
      qa = list(
        flag_word = words,
        flag_bits = bits,
        valid_fraction = terra::rast(unname(valid_fraction)),
        composite = composite,
        policy = policy
      ),
      units = c(lst = "K", albedo = "1", ndvi = "1", lai = "m2 m-2",
                emissivity = "1", emis_31 = "1", emis_32 = "1",
                doy = "1", utc_hour = "h",
                time = "POSIXct (UTC)", lon = "degree", lat = "degree"),
      flags = flags,
      provenance = provenance
    ),
    "earthflux_surface_state"
  )
}

# Provenance --------------------------------------------------------------------

#' Provenance of a MODIS surface state
#'
#' @param sources Named list of `earthflux_modis_source` (roles `lst`,
#'   `albedo`, `ndvi`, `lai`).
#' @param options An `earthflux_modis_surface_options` object.
#' @param rows Rows of the product table used (with their citations).
#' @return A list: `granules` (data frame, one row per source: `role`,
#'   `product`, `collection`, `date` (UTC data day), `period_start`,
#'   `period_end`, `tile`, `file` (granule file names; `;`-separated for
#'   converted layers), `input` (`"hdf4"`, `"converted_dn"`,
#'   `"converted_scaled"`), `production` (UTC, from the HDF4 name),
#'   `doi`, `doi_status`), `products`, `collection`, `methods` (the options,
#'   with the diffuse fraction recorded as a number or as `"SpatRaster"` and
#'   `lai_nonveg` as the LAI assigned per class code or `NULL`),
#'   `status` (verification status of each step), `product_rows`, `versions`
#'   (EarthFlux, terra, GDAL, PROJ, GEOS, R) and `spec`.
#' @noRd
modis_provenance <- function(sources, options, rows) {
  dois <- modis_product_doi()
  granules <- do.call(rbind, lapply(names(sources), function(role) {
    s <- sources[[role]]
    i <- match(paste(s$product, s$collection),
               paste(dois$product, dois$collection))
    data.frame(
      role = role,
      product = s$product,
      collection = s$collection,
      date = format(s$date),
      period_start = if (is.null(s$period)) NA_character_ else
        format(s$period[1L]),
      period_end = if (is.null(s$period)) NA_character_ else
        format(s$period[2L]),
      tile = s$tile,
      file = paste(basename(unname(s$path)), collapse = ";"),
      input = if (s$type == "hdf4") "hdf4" else if (isTRUE(s$scaled))
        "converted_scaled" else "converted_dn",
      production = format(s$production, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      doi = dois$doi[i],
      doi_status = dois$status[i],
      stringsAsFactors = FALSE
    )
  }))
  methods <- unclass(options)
  if (inherits(methods$diffuse_fraction, "SpatRaster")) {
    methods$diffuse_fraction <- "SpatRaster"
  }
  lib <- modis_lib_versions()
  list(
    granules = granules,
    products = unique(granules$product),
    collection = unique(granules$collection),
    methods = methods,
    status = c(
      product_facts = "VERIFICADA",
      overpass_time = "CANDIDATA",
      albedo = "CANDIDATA",
      emissivity = "VERIFICADA (SEBAL-Idaho 2002); RC-14 open",
      lai_nonveg = if (is.null(options$lai_nonveg))
        "not used: non-vegetated classes NA (MP-06)" else
        "CANDIDATA (explicit LAI of the non-vegetated classes, MP-06)",
      band_emissivity = paste0("VERIFICADA (product layers); broadband ",
                               "conversion E1 not implemented (MP-04)"),
      ndvi = "VERIFICADA",
      composite_matching = "DECIDIDA (provisional), MP-07",
      resampling = "DECIDIDA (provisional), MP-08",
      real_granule_check = "TODO (A-M4-3)"
    ),
    product_rows = rows,
    versions = list(
      earthflux = as.character(getNamespaceVersion("EarthFlux")),
      terra = as.character(utils::packageVersion("terra")),
      gdal = as.character(lib$gdal),
      proj = as.character(lib$proj),
      geos = as.character(lib$geos),
      r = R.version.string
    ),
    spec = "dev/specs/modis-products.md 13.2; dev/ARCHITECTURE.md 4"
  )
}

# Hand-over to the core ---------------------------------------------------------

#' Cells of a surface state to exclude before the METRIC core
#'
#' Reads the flag words of the state and returns the cells where a
#' `critical` code of the surface stage is active in any layer (today
#' `EF_SURF_ALBEDO_GT1`): their values are kept in the state, but the core
#' (`ef_g()`, `ef_net_radiation()`) rejects them with
#' `earthflux_domain_error`, so the orchestration sets them to `NA` before
#' the call and counts the exclusion (dev/specs/flags.md 4.1 class III,
#' 6.6; P0-11). The bits are read from the registry, never fixed.
#'
#' @param x An `earthflux_surface_state`.
#' @return A list with `exclude` (logical, terra cell order) and `counts`
#'   (named integer: cells per critical code).
#' @noRd
surface_exclusion <- function(x) {
  if (!inherits(x, "earthflux_surface_state")) {
    ef_abort("`x` must be an earthflux_surface_state.",
             class = "earthflux_input_error")
  }
  reg <- ef_flag_registry()
  crit <- reg[reg$stage == "SURF" & reg$severity == "critical" &
                !is.na(reg$bit), ]
  words <- terra::values(x$qa$flag_word, mat = TRUE)
  exclude <- rep(FALSE, nrow(words))
  counts <- integer(0)
  for (k in seq_len(nrow(crit))) {
    hit <- bitwAnd(as.integer(words), bitwShiftL(1L, crit$bit[k])) != 0L
    dim(hit) <- dim(words)
    cell <- rowSums(hit) > 0L
    counts[crit$code[k]] <- sum(cell)
    exclude <- exclude | cell
  }
  list(exclude = exclude, counts = counts)
}

#' GDAL, PROJ and GEOS versions used by terra
#'
#' `terra::gdal(lib = "all")` returns a named character vector up to terra
#' 1.9-45 and a one-row data frame (with an extra `TBB` column) from terra
#' 1.9-46 onwards; `$` fails on the former. Both are normalised to a list.
#' @param v The value of `terra::gdal(lib = "all")` (an argument so that both
#'   shapes can be tested whatever terra is installed).
#' @return A list with character elements `gdal`, `proj` and `geos`.
#' @noRd
modis_lib_versions <- function(v = terra::gdal(lib = "all")) {
  v <- as.list(v)
  lapply(c(gdal = "gdal", proj = "proj", geos = "geos"), function(k) {
    x <- v[[k]]
    if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x[[1L]])
  })
}
