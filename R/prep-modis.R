# Preprocessing: MODIS -> standardised surface state ------------------------------
#
# Purpose: convert MODIS products into sensor-independent physical variables
#   (LST [K], broadband albedo [-], NDVI [-], LAI [m2 m-2], broadband surface
#   emissivity [-], overpass instant) on a common grid, with QA masks and
#   provenance.
#
# Architectural rule (dev/ARCHITECTURE.md principles 1-2;
#   dev/specs/modis-products.md section 1): functions in metric-*.R never
#   receive MODIS-specific objects. Only the MODIS files know about MODIS
#   scale factors, fill values, QA bit fields and view times.
#
# Specification: dev/specs/modis-products.md sections 6 (view time), 8
#   (broadband conversions), 9 (temporal lag and spatial resampling), 13.2
#   and 15 (decisions MP-02, MP-03, MP-04, MP-05, MP-07, MP-08); time
#   convention of the core in dev/specs/radiation-components.md 4.4 (RC-03)
#   and emissivity requirement in 6.6 (RC-14).
#
# Implemented here (milestone M4, preparation steps that do not depend on
#   the product tables; all internal, no `ef_` prefix, section 13):
#   - modis_overpass_time(): MOD11A1/MYD11A1 view time (local MEAN solar
#     time) -> numeric `doy` and `utc_hour` of the core, plus a POSIXct UTC
#     wrapper (section 6.2, CANDIDATA);
#   - modis_cell_lonlat(): longitude and latitude of the cell centres of a
#     SpatRaster (the "grid's longitude" of section 6.1);
#   - modis_albedo(): broadband albedo from MCD43A3 black-sky and white-sky
#     albedos, options A1-A3 of section 8.1 (CANDIDATA);
#   - modis_broadband_emissivity(): broadband surface emissivity, option E3
#     of section 8.2 (CANDIDATA, RC-14);
#   - modis_ndvi_from_reflectance(): NDVI from red and NIR reflectances
#     (MOD13 user guide, Eq. 1; form VERIFICADA);
#   - modis_match_composite(): temporal matching of composites to the LST
#     date, options T1, T2 and T4/T5 of section 9.1 (MP-07);
#   - modis_to_grid(): integer-factor aggregation to the working grid with a
#     minimum valid fraction and the valid-fraction layer (section 9.2,
#     MP-08).
#
# Options of the specification that are TODO (A4, E1, E2, E4, T3) or whose
#   coefficients are TODO (A5, A6) are not implemented: requesting them
#   raises earthflux_method_not_implemented (subclass of
#   earthflux_unknown_method and earthflux_input_error; fields `method` and
#   `choices`, the available methods). # TODO(shared): list this class in
#   the condition-class catalogue at the top of R/utils.R.
#
# Flags: these functions raise no flag. They return logical masks that the
#   surface stage (ef_flags_surface(), owned by the product/QA module) maps
#   to EF_SURF_ codes (dev/specs/flags.md 4.2, bits 6.4):
#   - modis_overpass_time()$missing  -> EF_SURF_OVERPASS_MISSING (bit 13,
#     class I) where the LST is valid;
#   - modis_albedo()$gt1             -> EF_SURF_ALBEDO_GT1 (bit 14, class
#     III, critical);
#   - modis_to_grid()$incomplete     -> EF_SURF_AGG_INCOMPLETE (class II,
#     threshold TODO: must not be registered yet);
#   - modis_match_composite()$lag_days feeds EF_SURF_COMPOSITE_LAG (class
#     II, threshold TODO: no mask is computed);
#   - modis_ndvi_from_reflectance()$undefined / $outside_unit: no code in
#     the catalogue (open question).
#
# SpatRaster inputs: modis_overpass_time(), modis_albedo(),
#   modis_broadband_emissivity(), modis_ndvi_from_reflectance() and the
#   `composite_doy` of modis_match_composite() accept single-layer
#   SpatRasters with a common geometry (or length-1 numbers); the numeric
#   code path is applied to the cell values (same results as with vectors,
#   dev/specs/modis-products.md section 14), and every per-cell output is
#   returned as a SpatRaster with the geometry of the inputs.

# Internal helpers -------------------------------------------------------------

#' Check a method of a MODIS conversion, distinguishing planned options
#'
#' @param method The caller's `method` argument (possibly missing).
#' @param available Character vector of the implemented methods.
#' @param planned Named character vector: names are method identifiers of
#'   options listed in dev/specs/modis-products.md but not implemented;
#'   values explain why (status and section).
#' @param call The call to report.
#' @return `method`, invisibly. A planned method raises
#'   `c("earthflux_method_not_implemented", "earthflux_unknown_method",
#'   "earthflux_input_error")` with fields `method` and `choices` (the
#'   available methods); missing, malformed or unknown methods raise the
#'   classes of `check_method()`.
#' @noRd
modis_check_method <- function(method, available, planned, call) {
  if (!missing(method) && is.character(method) && length(method) == 1L &&
      !is.na(method) && method %in% names(planned)) {
    ef_abort(
      sprintf(
        paste0(
          "`method = \"%s\"` is not implemented: %s. ",
          "Available methods: %s."
        ),
        method, planned[[method]],
        paste0("\"", available, "\"", collapse = ", ")
      ),
      class = c("earthflux_method_not_implemented",
                "earthflux_unknown_method", "earthflux_input_error"),
      method = method,
      choices = available,
      call = call
    )
  }
  check_method(method, available, call = call)
}

#' Check which optional inputs a method uses
#'
#' Inputs used by the chosen method must be supplied; inputs it does not use
#' must be `NULL`, so that a change of method is never hidden behind an
#' ignored argument.
#'
#' @param args Named list of the optional inputs (`NULL` when absent).
#' @param used Character vector of the names used by the method.
#' @param method Character. The method, for the messages.
#' @param call The call to report.
#' @return `TRUE`, invisibly.
#' @noRd
modis_check_used <- function(args, used, method, call) {
  absent <- vapply(args, is.null, logical(1))
  missing_used <- intersect(used, names(args)[absent])
  if (length(missing_used) > 0L) {
    ef_abort(
      sprintf(
        "`method = \"%s\"` requires %s.",
        method, paste0("`", missing_used, "`", collapse = ", ")
      ),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  unused <- setdiff(names(args)[!absent], used)
  if (length(unused) > 0L) {
    ef_abort(
      sprintf(
        "%s not used by `method = \"%s\"`; leave it `NULL`.",
        paste0("`", unused, "`", collapse = ", "), method
      ),
      class = "earthflux_input_error",
      call = call
    )
  }
  invisible(TRUE)
}

#' Check a Date argument
#'
#' @param x Object to check.
#' @param arg Argument name.
#' @param scalar Logical. Whether `x` must have length 1.
#' @param call The call to report.
#' @return `x`, invisibly. Errors of class `earthflux_input_error` when `x`
#'   is not a `Date`, is empty, has missing values, has fractional days or
#'   (with `scalar = TRUE`) has length other than 1.
#' @noRd
modis_check_date <- function(x, arg, scalar = FALSE, call) {
  if (!inherits(x, "Date")) {
    ef_abort(
      sprintf("`%s` must be a `Date` (UTC calendar date), not %s.",
              arg, class(x)[1L]),
      class = "earthflux_input_error", call = call
    )
  }
  if (length(x) == 0L || (scalar && length(x) != 1L)) {
    ef_abort(
      sprintf("`%s` must have length %s.", arg,
              if (scalar) "1" else "at least 1"),
      class = "earthflux_input_error", call = call
    )
  }
  days <- unclass(x)
  if (anyNA(days) || any(days != floor(days))) {
    ef_abort(
      sprintf("`%s` must not contain missing values or fractional days.",
              arg),
      class = "earthflux_input_error", call = call
    )
  }
  invisible(x)
}

#' Whether any element of a list is a SpatRaster
#'
#' @param args A list.
#' @return Logical scalar.
#' @noRd
modis_any_raster <- function(args) {
  any(vapply(args, inherits, logical(1), what = "SpatRaster"))
}

#' Apply a numeric MODIS conversion to the cells of SpatRasters
#'
#' Every `SpatRaster` in `args` must have one layer and the geometry of the
#' first one (`terra::compareGeom()`); they are replaced by their cell
#' values (terra cell order) and `fun` is called on the numeric arguments.
#' The elements of the result named in `outputs` are written back as
#' single-layer `SpatRaster`s with that geometry.
#'
#' @param fun The numeric function.
#' @param args Named list of its arguments.
#' @param outputs Character vector of the names of the per-cell outputs.
#' @param call The call to report.
#' @return The result of `fun` with the `outputs` elements as `SpatRaster`s.
#' @noRd
modis_raster_apply <- function(fun, args, outputs, call) {
  is_r <- vapply(args, inherits, logical(1), what = "SpatRaster")
  template <- args[is_r][[1L]]
  for (nm in names(args)[is_r]) {
    r <- args[[nm]]
    if (terra::nlyr(r) != 1L) {
      ef_abort(sprintf("`%s` must be a single-layer SpatRaster.", nm),
               class = "earthflux_input_error", call = call)
    }
    if (!isTRUE(terra::compareGeom(template, r, stopOnError = FALSE))) {
      ef_abort(
        sprintf("`%s` does not share the geometry of the other rasters.",
                nm),
        class = "earthflux_input_error", call = call
      )
    }
    args[[nm]] <- terra::values(r, mat = FALSE)
  }
  res <- do.call(fun, args)
  as_raster <- function(v, nm) {
    out <- terra::rast(template, nlyrs = 1L)
    terra::values(out) <- as.vector(v)
    names(out) <- nm
    out
  }
  if (!is.list(res)) {
    return(as_raster(res, outputs[[1L]]))
  }
  for (nm in outputs) {
    res[[nm]] <- as_raster(res[[nm]], nm)
  }
  res
}

# Cell coordinates -------------------------------------------------------------

#' Longitude and latitude of the cell centres of a SpatRaster
#'
#' Geographic coordinates (WGS84, degrees, longitude positive east) of the
#' centre of every cell of `x`, as needed by the view-time conversion (the
#' "grid's longitude" of the MOD11 user guide, dev/specs/modis-products.md
#' 6.1) and by `ef_solar_geometry()` (after conversion to radians). Cells in
#' a projected CRS (e.g. the MODIS sinusoidal grid) are projected with
#' `terra::project()`.
#'
#' @param x A `SpatRaster` with a defined CRS.
#' @return A two-layer `SpatRaster` (`lon`, `lat`) \[degrees\] with the
#'   geometry of `x`. Errors: `x` not a `SpatRaster` or without CRS ->
#'   `earthflux_input_error`.
#' @noRd
modis_cell_lonlat <- function(x) {
  call <- sys.call()
  if (!inherits(x, "SpatRaster")) {
    ef_abort("`x` must be a SpatRaster.", class = "earthflux_input_error",
             call = call)
  }
  if (!nzchar(terra::crs(x))) {
    ef_abort("`x` has no coordinate reference system.",
             class = "earthflux_input_error", call = call)
  }
  xy <- terra::xyFromCell(x, seq_len(terra::ncell(x)))
  if (!terra::is.lonlat(x)) {
    xy <- terra::project(xy, from = terra::crs(x), to = "EPSG:4326")
  }
  out <- terra::rast(x, nlyrs = 2L)
  terra::values(out) <- xy
  names(out) <- c("lon", "lat")
  out
}

# View time -> UTC -------------------------------------------------------------

#' Overpass instant (UTC) from the MOD11A1/MYD11A1 view time
#'
#' @description
#' Converts the daytime view time of MOD11A1/MYD11A1 (`Day_view_time`,
#' already scaled to hours), which is the local **mean** solar time of the
#' observation, into the time inputs of the METRIC core: the day of year
#' `doy` of the UTC date and the UTC hour `utc_hour` (decision RC-03), plus
#' the instant as `POSIXct` in UTC (the `overpass_time` of the surface
#' contract, dev/ARCHITECTURE.md section 4).
#'
#' @param view_time_h Numeric vector, matrix or array, or single-layer
#'   `SpatRaster`. Local mean solar time of the observation \[h\], in
#'   \[0, 24\] (physical range of `Day_view_time`, DN 0-240 times 0.1;
#'   dev/specs/modis-products.md 5.1). Fill values must already be `NA`.
#' @param lon_deg Numeric. Longitude of the cell centre \[degrees\], positive
#'   east, in \[-180, 180\]; length 1 or the length (and `dim`) of
#'   `view_time_h`. With a `SpatRaster` `view_time_h` it may be `NULL` (the
#'   default) to use the cell centres (`modis_cell_lonlat()`), or a
#'   single-layer `SpatRaster` with the same geometry. Required for numeric
#'   input.
#' @param date_utc `Date`. UTC date of the data day in the file name
#'   (dev/specs/modis-products.md 5.1, "día de datos en UTC"); length 1 or
#'   the common length. For a `SpatRaster` input it must have length 1.
#'
#' @return A list:
#'   * `doy`: day of year of `date_utc` \[-\] (whole number, 1-366);
#'   * `utc_hour`: UTC time of day \[h\], in \[0, 24);
#'   * `time`: the instant as `POSIXct` with `tz = "UTC"` (a plain vector
#'     in the order of the cells; it does not keep `dim`);
#'   * `missing`: logical, `TRUE` where no overpass instant exists (missing
#'     view time). It maps to the flag `EF_SURF_OVERPASS_MISSING` (bit 13,
#'     class I) on the cells where the LST is valid; the flag is raised by
#'     the surface stage, not here.
#'
#'   `doy`, `utc_hour`, `time` are `NA` where `missing` is `TRUE`. Numeric
#'   outputs keep the common length and `dim` of the inputs; with a
#'   `SpatRaster` input `doy`, `utc_hour` and `missing` are single-layer
#'   `SpatRaster`s and `time` is in terra cell order.
#'
#' @details
#' With \eqn{t_{ls}} the local mean solar time \[h\], \eqn{\lambda} the
#' longitude of the cell centre \[degrees, east positive\] and \eqn{D} the
#' UTC date of the file:
#' \deqn{t_{UTC} = (t_{ls} - \lambda / 15) \bmod 24, \quad
#'   \mathrm{instant} = D\ 00{:}00\ \mathrm{UTC} + t_{UTC}\ \mathrm{h}}
#' and `doy` is the day of year of \eqn{D}. The definition of the product,
#' local solar time = UTC + \eqn{\lambda}/15 h with a +/-24 h correction
#' (MOD11 user guide, PDF p. 16), is inverted by subtracting
#' \eqn{\lambda}/15 and reducing modulo 24. The observation belongs to the
#' UTC day \eqn{D} of the file, so the instant is kept inside \eqn{D}: when
#' the local solar date of the cell differs from \eqn{D} (e.g. near the
#' antimeridian, cases V2 and V3 of section 6.2) the UTC date is never
#' shifted. A result that rounds to 24 h is set to 0 h of the same date
#' (floating-point guard of the modulo; mathematically the result is in
#' \[0, 24)).
#'
#' **Equation of time.** The MOD11A1/MYD11A1 view time is local **mean**
#' solar time (UTC plus longitude/15, without equation of time;
#' dev/specs/modis-products.md 6.1, VERIFICADA). This conversion therefore
#' uses only the longitude and applies **no** equation of time; the
#' equation of time is applied exactly once in the whole chain, inside
#' `ef_hour_angle()` (called by `ef_solar_geometry()`), as required by
#' decision RC-03 (dev/specs/radiation-components.md 4.4). Passing the
#' resulting `utc_hour` to `ef_solar_geometry()` with the same longitude
#' gives a hour angle that corresponds to the apparent solar time
#' \eqn{t_{ls} + S_c}.
#'
#' Only MOD11A1/MYD11A1 are supported: the semantics of `View_Time` of
#' MOD21A1D/MYD21A1D are `TODO` (section 6.4, MP-01) and must not be passed
#' here. Terra and Aqua (MP-02) are handled alike: the view time is read per
#' pixel, never assumed (section 7.2).
#'
#' Errors: non-numeric or mismatched inputs -> `earthflux_input_error`;
#' `view_time_h` outside \[0, 24\] or `lon_deg` outside \[-180, 180\] ->
#' `earthflux_domain_error`; `date_utc` not a `Date`, with `NA` or of
#' incompatible length -> `earthflux_input_error`.
#'
#' @section Verification status:
#' The semantics of the view time (local mean solar time, UTC data day) are
#' `VERIFICADA` (MOD11 C6.1 user guide, PDF p. 16; dev/specs/modis-products.md
#' 6.1). The inverse conversion is `CANDIDATA` (logical derivation, section
#' 6.2), pending a test with a real granule; the assumption that every
#' observation of the file of day \eqn{D} falls inside \[00:00, 24:00) UTC
#' of \eqn{D} is `TODO` (section 16, item 5). With several observations per
#' cell (latitude > 30 degrees) the meaning of the view time (single pass or
#' average) is `TODO` (discrepancy d1, section 5.1).
#' @noRd
modis_overpass_time <- function(view_time_h, lon_deg = NULL, date_utc) {
  call <- sys.call()
  if (inherits(view_time_h, "SpatRaster")) {
    modis_check_date(date_utc, "date_utc", scalar = TRUE, call = call)
    if (is.null(lon_deg)) {
      lon_deg <- modis_cell_lonlat(view_time_h)[["lon"]]
    }
    return(modis_raster_apply(
      modis_overpass_time,
      list(view_time_h = view_time_h, lon_deg = lon_deg,
           date_utc = date_utc),
      outputs = c("doy", "utc_hour", "missing"),
      call = call
    ))
  }
  if (is.null(lon_deg)) {
    ef_abort("`lon_deg` must be supplied for numeric `view_time_h`.",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  n <- check_core_args(list(view_time_h = view_time_h, lon_deg = lon_deg),
                       call)
  modis_check_date(date_utc, "date_utc", call = call)
  if (!length(date_utc) %in% c(1L, n)) {
    ef_abort(
      sprintf("`date_utc` must have length 1 or the common length (%d).", n),
      class = "earthflux_input_error", call = call
    )
  }
  check_in_range(view_time_h, "view_time_h", lower = 0, upper = 24,
                 call = call)
  check_in_range(lon_deg, "lon_deg", lower = -180, upper = 180, call = call)
  d <- common_dim(list(view_time_h = view_time_h, lon_deg = lon_deg))

  # Section 6.2: inverse of "UTC + longitude / 15, +/- 24 h" (no equation of
  # time: the view time is local MEAN solar time, section 6.1).
  utc_hour <- rep_len(as.vector((view_time_h - lon_deg / 15) %% 24), n)
  # Floating-point guard: x %% 24 can round to 24 for tiny negative x.
  utc_hour[!is.na(utc_hour) & utc_hour >= 24] <- 0
  missing_time <- is.na(utc_hour)

  date_utc <- rep_len(date_utc, n)
  doy <- as.numeric(as.POSIXlt(date_utc, tz = "UTC")$yday) + 1
  doy[missing_time] <- NA_real_
  time <- .POSIXct(as.numeric(unclass(date_utc)) * 86400 + utc_hour * 3600,
                   tz = "UTC")

  list(
    doy = ef_reshape(doy, n, d),
    utc_hour = ef_reshape(utc_hour, n, d),
    time = time,
    missing = ef_reshape(missing_time, n, d)
  )
}

# Broadband albedo -------------------------------------------------------------

#' Broadband surface albedo from MCD43A3 black-sky and white-sky albedos
#'
#' @description
#' Broadband (shortwave) surface albedo from the MCD43A3 black-sky albedo
#' (BSA, directional-hemispherical reflectance at local solar noon) and
#' white-sky albedo (WSA, bihemispherical reflectance), options A1-A3 of
#' dev/specs/modis-products.md 8.1 (decision MP-03). The choice is explicit:
#' `method` has no default.
#'
#' @param bsa Numeric (or single-layer `SpatRaster`). `Albedo_BSA_shortwave`
#'   already scaled \[-\], >= 0 (physical range 0-32.766; values above 1 are
#'   kept and flagged, never truncated). Used by `"blue_sky"` and
#'   `"black_sky"`; must be `NULL` otherwise.
#' @param wsa Numeric (or single-layer `SpatRaster`).
#'   `Albedo_WSA_shortwave` already scaled \[-\], >= 0. Used by `"blue_sky"`
#'   and `"white_sky"`; must be `NULL` otherwise.
#' @param diffuse_fraction Numeric (or single-layer `SpatRaster`). Fraction
#'   of diffuse shortwave radiation \eqn{S} \[-\], in \[0, 1\]. Required by
#'   `"blue_sky"` (no default: its model is an open decision, see
#'   Details); must be `NULL` otherwise.
#' @param method Character, no default. One of:
#'   * `"blue_sky"` (A1): \eqn{\alpha = (1 - S)\,BSA + S\,WSA};
#'   * `"white_sky"` (A2): \eqn{\alpha = WSA};
#'   * `"black_sky"` (A3): \eqn{\alpha = BSA} (local solar noon).
#'
#'   Options of section 8.1 that are not implemented raise
#'   `earthflux_method_not_implemented`: `"bsa_at_overpass"` (A4, `TODO`:
#'   requires the MCD43A1 BRDF parameters), `"narrow_to_broadband"` (A5,
#'   coefficients of Liang, 2001, `TODO`) and `"metric_tasumi"` (A6,
#'   transferability to MODIS `TODO`, formula not in the specification).
#'
#' @return A list:
#'   * `albedo`: broadband albedo \[-\] with the common length and `dim` of
#'     the inputs (a `SpatRaster` for raster input);
#'   * `gt1`: logical, `TRUE` where `albedo > 1` (value kept). It maps to
#'     `EF_SURF_ALBEDO_GT1` (bit 14, class III, `critical`;
#'     dev/specs/flags.md C12): the orchestration must exclude these cells
#'     before `ef_g()` and `ef_net_radiation()`, which reject albedo > 1.
#'
#' @details
#' A1 is the interpolation between BSA and WSA by the diffuse fraction,
#' assuming isotropic diffuse radiation (MODIS BRDF/albedo ATBD v5.0, 1999,
#' PDF p. 11, Eq. 32), applied here to the shortwave broadband albedos;
#' the approximation has relative errors of a few percent (ATBD, PDF p. 24).
#' The diffuse fraction is an explicit input because its model is open:
#' taking it from `ef_tau_sw_allen()`, which uses the albedo as ground
#' reflectance, is circular (DECISIONS T-11); the caller must document how
#' it breaks the circularity (e.g. albedo of the previous date, or WSA as
#' first approximation).
#'
#' All options use the MCD43A3 albedo at local **solar noon**, not at the
#' overpass time (BSA depends on the solar zenith angle; A4 would correct
#' it). With the temporal option T5 (section 9.1) the albedo of the LST date
#' is used, but it still represents a 16-day window weighted to its ninth
#' day.
#'
#' Errors: missing or unknown `method`, missing inputs required by the
#' method, or inputs supplied but not used by it -> classed input errors;
#' negative albedo or `diffuse_fraction` outside \[0, 1\] ->
#' `earthflux_domain_error`. `NA` propagates.
#'
#' @section Verification status:
#' A1, A2 and A3 are `CANDIDATA` (dev/specs/modis-products.md 8.1): the form
#' of A1 is the ATBD Eq. 32 for spectral albedos, and its application to
#' broadband albedos assumes a spectrally constant diffuse fraction (`TODO`,
#' Román et al., 2010). The ATBD is the 1999 version (pre-C6); its validity
#' for C6.1 is `TODO`.
#' @noRd
modis_albedo <- function(bsa = NULL, wsa = NULL, diffuse_fraction = NULL,
                         method) {
  call <- sys.call()
  available <- c("blue_sky", "white_sky", "black_sky")
  modis_check_method(
    method, available,
    planned = c(
      bsa_at_overpass = paste0(
        "option A4 (BSA at the overpass from the MCD43A1 BRDF ",
        "parameters) is TODO in dev/specs/modis-products.md 8.1"
      ),
      narrow_to_broadband = paste0(
        "option A5 needs the narrowband-to-broadband coefficients of ",
        "Liang (2001), TODO in dev/specs/modis-products.md 8.1"
      ),
      metric_tasumi = paste0(
        "option A6 (Tasumi et al., 2008) is not given with a formula and ",
        "its transferability to MODIS is TODO (dev/specs/modis-products.md ",
        "8.1)"
      )
    ),
    call = call
  )
  args <- list(bsa = bsa, wsa = wsa, diffuse_fraction = diffuse_fraction)
  used <- switch(method,
    blue_sky = c("bsa", "wsa", "diffuse_fraction"),
    white_sky = "wsa",
    black_sky = "bsa"
  )
  modis_check_used(args, used, method, call)
  args <- args[used]
  if (modis_any_raster(args)) {
    return(modis_raster_apply(
      function(...) modis_albedo(..., method = method),
      args, outputs = c("albedo", "gt1"), call = call
    ))
  }
  n <- check_core_args(args, call)
  for (nm in intersect(c("bsa", "wsa"), used)) {
    check_in_range(args[[nm]], nm, lower = 0, call = call)
  }
  if ("diffuse_fraction" %in% used) {
    check_in_range(diffuse_fraction, "diffuse_fraction", lower = 0,
                   upper = 1, call = call)
  }
  d <- common_dim(args)

  albedo <- switch(method,
    # Option A1: ATBD Eq. 32 applied to the shortwave broadband albedos.
    blue_sky = (1 - diffuse_fraction) * bsa + diffuse_fraction * wsa,
    white_sky = wsa,
    black_sky = bsa
  )
  albedo <- ef_reshape(albedo, n, d)
  gt1 <- !is.na(albedo) & albedo > 1
  dim(gt1) <- d
  list(albedo = albedo, gt1 = gt1)
}

# Broadband emissivity ---------------------------------------------------------

#' Broadband surface emissivity for the MODIS surface state
#'
#' @description
#' Broadband surface emissivity \eqn{\varepsilon_0} \[-\], the `emissivity`
#' of the surface contract, used by `ef_rl_out()` and `ef_net_radiation()`
#' (decision RC-14, requirement C2: the same value in both). Options of
#' dev/specs/modis-products.md 8.2 (decision MP-04); `method` has no
#' default.
#'
#' @param e31,e32 Band 31 and band 32 emissivities of MOD11A1/MYD11A1
#'   (`Emis_31`, `Emis_32`, already scaled) \[-\]. Reserved for option E1,
#'   which is not implemented; they must be `NULL` with the implemented
#'   method.
#' @param lai Numeric (or single-layer `SpatRaster`). Leaf area index
#'   \[m2 m-2\], >= 0. Used by `"lai_empirical"`. Non-vegetated MCD15A2H
#'   classes must already be `NA` (MP-06): they are never set to 0 here.
#' @param method Character, no default. Implemented:
#'   * `"lai_empirical"` (E3):
#'     \eqn{\varepsilon_0 = \min(0.95 + 0.01\,LAI,\ 0.98)}.
#'
#'   Not implemented (raise `earthflux_method_not_implemented`):
#'   `"split_window_regression"` (E1, regression on \eqn{\varepsilon_{31}},
#'   \eqn{\varepsilon_{32}}; Wang et al., 2005, coefficients `TODO`),
#'   `"tes_regression"` (E2, from MOD21A1D, reference `TODO`) and `"camel"`
#'   (E4, external product, `TODO`).
#'
#' @return Numeric broadband emissivity \[-\], in \[0.95, 0.98\], with the
#'   length and `dim` of `lai` (a `SpatRaster` for raster input). `NA`
#'   propagates.
#'
#' @details
#' E3 is the empirical METRIC form (form observed in the `water` package;
#' dev/specs/radiation-components.md 6.6). It is **decoupled from the LST
#' retrieval**: MOD11A1 retrieves the LST with its own band 31/32
#' emissivities (by classification), so a LAI-based \eqn{\varepsilon_0}
#' does not describe the same surface emissivity as the LST product
#' (RC-14). The provisional recommendation of the specification (MP-04) is a
#' regression on the LST product emissivities (E1/E2) once its primary
#' reference is verified; E3 is offered as an explicit option meanwhile.
#' Sensitivity: \eqn{\Delta\varepsilon_0 = 0.01} changes Rn by about
#' -1.4 W m-2 (dev/specs/radiation-components.md 6.6).
#'
#' Errors: missing or unknown `method`, missing `lai`, or `e31`/`e32`
#' supplied -> classed input errors; negative `lai` ->
#' `earthflux_domain_error`.
#'
#' @section Verification status:
#' E3 is `CANDIDATA` (RC-14; dev/specs/modis-products.md 8.2): form and
#' coefficients observed in a secondary implementation, primary reference
#' (Allen et al., 2007; Tasumi, 2003) not verified; its domain (e.g.
#' treatment of water and bare soil) is not specified.
#' @noRd
modis_broadband_emissivity <- function(e31 = NULL, e32 = NULL, lai = NULL,
                                       method) {
  call <- sys.call()
  modis_check_method(
    method, "lai_empirical",
    planned = c(
      split_window_regression = paste0(
        "option E1 (regression on the band 31/32 emissivities, Wang et ",
        "al., 2005) has its coefficients TODO in ",
        "dev/specs/modis-products.md 8.2"
      ),
      tes_regression = paste0(
        "option E2 (regression on the MOD21A1D emissivities) is TODO in ",
        "dev/specs/modis-products.md 8.2"
      ),
      camel = paste0(
        "option E4 (CAMEL broadband product) is TODO in ",
        "dev/specs/modis-products.md 8.2"
      )
    ),
    call = call
  )
  args <- list(e31 = e31, e32 = e32, lai = lai)
  modis_check_used(args, "lai", method, call)
  if (modis_any_raster(list(lai = lai))) {
    return(modis_raster_apply(
      function(lai) modis_broadband_emissivity(lai = lai, method = method),
      list(lai = lai), outputs = "emissivity", call = call
    ))
  }
  n <- check_core_args(list(lai = lai), call)
  check_in_range(lai, "lai", lower = 0, call = call)
  # Option E3 (RC-14): 0.95 + 0.01 LAI, capped at 0.98.
  ef_reshape(pmin(0.95 + 0.01 * lai, 0.98), n, dim(lai))
}

# NDVI from reflectance --------------------------------------------------------

#' NDVI from red and near-infrared surface reflectances
#'
#' @description
#' Normalized difference vegetation index from surface reflectances (e.g.
#' MOD09GA/MOD09GQ bands 1 and 2, option T4 of section 9.1, or the red and
#' NIR reflectance layers of MOD13):
#' \deqn{NDVI = \frac{\rho_{NIR} - \rho_{red}}{\rho_{NIR} + \rho_{red}}}
#'
#' @param red,nir Numeric (or single-layer `SpatRaster`). Red and NIR
#'   surface reflectances, already scaled \[-\]; finite. Valid reflectances
#'   may be slightly negative (MOD09 valid range from DN -100, i.e. -0.01;
#'   dev/specs/modis-products.md 5.3).
#'
#' @return A list:
#'   * `ndvi`: NDVI \[-\] with the common length and `dim` of the inputs
#'     (a `SpatRaster` for raster input); `NA` where it is undefined;
#'   * `undefined`: logical, `TRUE` where \eqn{\rho_{NIR} + \rho_{red} \le
#'     0} (the quotient is undefined or has no meaning as an index; NDVI set
#'     to `NA`);
#'   * `outside_unit`: logical, `TRUE` where the computed NDVI lies outside
#'     \[-1, 1\] (possible when one reflectance is negative); the value is
#'     kept.
#'
#'   No EF_SURF_ code exists yet for `undefined` or `outside_unit` (open
#'   question for dev/specs/flags.md 4.2).
#'
#' @details
#' Aggregation to the working grid (MP-08, section 9.2): NDVI is not
#' linear, so the NDVI of the mean reflectances differs from the mean NDVI;
#' the order (aggregate reflectances with `modis_to_grid()` and then compute
#' NDVI, or the reverse) is a choice of the caller and must be recorded in
#' the provenance. Errors: non-numeric or mismatched inputs ->
#' `earthflux_input_error`; infinite values -> `earthflux_domain_error`.
#' `NA` propagates.
#'
#' @section Verification status:
#' `VERIFICADA` (form): MODIS vegetation index user guide (MOD13 C6.1), PDF
#' p. 5, Eq. 1 (dev/specs/modis-products.md 5.5). The treatment of a
#' non-positive denominator is an implementation decision recorded in the
#' specification status block.
#' @noRd
modis_ndvi_from_reflectance <- function(red, nir) {
  call <- sys.call()
  args <- list(red = red, nir = nir)
  if (modis_any_raster(args)) {
    return(modis_raster_apply(
      modis_ndvi_from_reflectance, args,
      outputs = c("ndvi", "undefined", "outside_unit"), call = call
    ))
  }
  n <- check_core_args(args, call)
  check_in_range(red, "red", call = call)
  check_in_range(nir, "nir", call = call)
  d <- common_dim(args)
  red <- rep_len(as.vector(red), n)
  nir <- rep_len(as.vector(nir), n)

  denom <- nir + red
  undefined <- !is.na(denom) & denom <= 0
  ndvi <- rep(NA_real_, n)
  ok <- !is.na(denom) & !undefined
  # MOD13 user guide, Eq. 1.
  ndvi[ok] <- (nir[ok] - red[ok]) / denom[ok]
  outside_unit <- !is.na(ndvi) & abs(ndvi) > 1

  list(
    ndvi = ef_reshape(ndvi, n, d),
    undefined = ef_reshape(undefined, n, d),
    outside_unit = ef_reshape(outside_unit, n, d)
  )
}

# Temporal matching ------------------------------------------------------------

#' Match a composite product to the LST date
#'
#' @description
#' Selects, for the UTC date of an LST scene, the composite (or daily file)
#' of a product to use, and reports the temporal lag, following the options
#' of dev/specs/modis-products.md 9.1 (decision MP-07). The option is
#' explicit: `method` has no default.
#'
#' @param lst_date `Date`, length 1. UTC date of the LST scene.
#' @param composite_start `Date` vector. For `"period"` and
#'   `"period_pixel_lag"`, first day of the period of each composite; for
#'   `"same_day"`, the nominal date of each daily file.
#' @param composite_end `Date` vector of the length of `composite_start`:
#'   last day (inclusive) of each period. Required by `"period"` and
#'   `"period_pixel_lag"`; must be `NULL` with `"same_day"`. The relation
#'   between the date in the file name and the period of MOD13 and MCD15
#'   composites is a product fact supplied by the caller (not stated in the
#'   specification).
#' @param method Character, no default:
#'   * `"period"` (T1): the composite whose period contains `lst_date`;
#'   * `"period_pixel_lag"` (T2): T1 plus the lag per pixel from the
#'     composite day of the year (MOD13 `composite day of the year`);
#'   * `"same_day"` (T4/T5): the daily file whose nominal date is
#'     `lst_date` (MOD09GA for T4, MCD43A3 for T5).
#'
#'   `"interpolate"` (T3, linear interpolation between adjacent composites)
#'   raises `earthflux_method_not_implemented`: the reference instant of a
#'   composite is not defined in the specification, and interpolation must
#'   never be the default.
#' @param composite_doy Numeric (or single-layer `SpatRaster`). Composite
#'   day of the year of each pixel of the selected composite (1-366, whole;
#'   fill already `NA`). Required by `"period_pixel_lag"`; must be `NULL`
#'   otherwise.
#'
#' @return A list:
#'   * `index`: integer index (into `composite_start`) of the selected
#'     composite, `NA` when none matches;
#'   * `start`, `end`: its period (`Date`; `end` equals `start` for
#'     `"same_day"`; `NA` when none matches);
#'   * `lag_bound_days`: for `"period"`/`"period_pixel_lag"`, the largest
#'     possible absolute lag between `lst_date` and a day of the period,
#'     `max(lst_date - start, end - lst_date)` \[days\]; 0 for `"same_day"`
#'     (difference of nominal dates; MCD43A3 still represents a 16-day
#'     window);
#'   * `lag_days`: for `"period_pixel_lag"`, the lag per pixel
#'     `lst_date - pixel date` \[days\] (positive when the composite
#'     observation precedes the LST), with the length and `dim` of
#'     `composite_doy` (a `SpatRaster` for raster input; all `NA` when no
#'     composite matches); `NULL` otherwise. It is the input of the flag
#'     `EF_SURF_COMPOSITE_LAG` (class II, threshold `TODO`), not raised
#'     here.
#'
#' @details
#' The pixel date of T2 is the date with day of year `composite_doy` that
#' lies inside the period of the selected composite (periods may cross a
#' year boundary). Errors: `lst_date`, `composite_start` or `composite_end`
#' not `Date`, with `NA` or inconsistent (end before start, unequal
#' lengths) -> `earthflux_input_error`; more than one composite matching
#' (overlapping periods or duplicated dates) -> `earthflux_input_error`;
#' `composite_doy` outside 1-366, not whole, or not inside the period of the
#' selected composite -> `earthflux_domain_error` / `earthflux_input_error`.
#'
#' @section Verification status:
#' Not a physical formulation. The composite steps (MOD13 16 days, MCD15A2H
#' 8 days, MCD43A3 daily over 16 days) and the per-pixel composite day of
#' MOD13 are `VERIFICADA` product facts (dev/specs/modis-products.md 9.1);
#' the choice among T1-T5 is the open decision MP-07 (provisional
#' recommendation: T2 for NDVI and LAI, T5 for albedo).
#' @noRd
modis_match_composite <- function(lst_date, composite_start,
                                  composite_end = NULL, method,
                                  composite_doy = NULL) {
  call <- sys.call()
  available <- c("period", "period_pixel_lag", "same_day")
  modis_check_method(
    method, available,
    planned = c(
      interpolate = paste0(
        "option T3 (linear interpolation between adjacent composites) ",
        "needs a reference instant per composite, not defined in ",
        "dev/specs/modis-products.md 9.1"
      )
    ),
    call = call
  )
  used <- switch(method,
    period = "composite_end",
    period_pixel_lag = c("composite_end", "composite_doy"),
    same_day = character(0)
  )
  modis_check_used(
    list(composite_end = composite_end, composite_doy = composite_doy),
    used, method, call
  )
  modis_check_date(lst_date, "lst_date", scalar = TRUE, call = call)
  modis_check_date(composite_start, "composite_start", call = call)

  if (method == "same_day") {
    hit <- which(composite_start == lst_date)
    if (length(hit) > 1L) {
      ef_abort(
        sprintf("%d files share the nominal date %s; expected at most one.",
                length(hit), format(lst_date)),
        class = "earthflux_input_error", call = call
      )
    }
    index <- if (length(hit) == 1L) hit else NA_integer_
    start <- composite_start[index]
    return(list(index = index, start = start, end = start,
                lag_bound_days = if (is.na(index)) NA_real_ else 0,
                lag_days = NULL))
  }

  modis_check_date(composite_end, "composite_end", call = call)
  if (length(composite_end) != length(composite_start)) {
    ef_abort("`composite_end` must have the length of `composite_start`.",
             class = "earthflux_input_error", call = call)
  }
  if (any(composite_end < composite_start)) {
    ef_abort("Every `composite_end` must be on or after its start.",
             class = "earthflux_input_error", call = call)
  }
  hit <- which(composite_start <= lst_date & lst_date <= composite_end)
  if (length(hit) > 1L) {
    ef_abort(
      sprintf(
        paste0("%d composite periods contain %s (overlapping periods); ",
               "expected at most one."),
        length(hit), format(lst_date)
      ),
      class = "earthflux_input_error", call = call
    )
  }
  index <- if (length(hit) == 1L) hit else NA_integer_
  start <- composite_start[index]
  end <- composite_end[index]
  lag_bound <- if (is.na(index)) {
    NA_real_
  } else {
    max(as.numeric(lst_date - start), as.numeric(end - lst_date))
  }
  out <- list(index = index, start = start, end = end,
              lag_bound_days = lag_bound, lag_days = NULL)
  if (method == "period") {
    return(out)
  }

  if (inherits(composite_doy, "SpatRaster")) {
    lag <- modis_raster_apply(
      function(composite_doy) {
        modis_pixel_lag(composite_doy, lst_date, start, end, call)
      },
      list(composite_doy = composite_doy), outputs = "lag_days",
      call = call
    )
  } else {
    lag <- modis_pixel_lag(composite_doy, lst_date, start, end, call)
  }
  out$lag_days <- lag
  out
}

#' Lag per pixel from the composite day of the year (option T2)
#'
#' @param composite_doy Numeric composite day of the year (1-366, whole,
#'   `NA` allowed).
#' @param lst_date,start,end `Date` scalars (`start`/`end` `NA` when no
#'   composite matches).
#' @param call The call to report.
#' @return Numeric lag \[days\], `lst_date - pixel date`, with the length and
#'   `dim` of `composite_doy`.
#' @noRd
modis_pixel_lag <- function(composite_doy, lst_date, start, end, call) {
  n <- check_core_args(list(composite_doy = composite_doy), call)
  check_whole(composite_doy, "composite_doy", call = call)
  check_in_range(composite_doy, "composite_doy", lower = 1, upper = 366,
                 call = call)
  d <- dim(composite_doy)
  doy <- as.vector(composite_doy)
  lag <- rep(NA_real_, n)
  if (is.na(start)) {
    return(ef_reshape(lag, n, d))
  }
  ok <- !is.na(doy)
  date_in_year <- function(year) {
    as.Date(sprintf("%04d-01-01", year)) + (doy[ok] - 1)
  }
  years <- as.POSIXlt(c(start, end))$year + 1900L
  pixel_date <- date_in_year(years[1L])
  outside <- pixel_date < start | pixel_date > end
  if (years[2L] != years[1L] && any(outside)) {
    alt <- date_in_year(years[2L])
    pixel_date[outside] <- alt[outside]
    outside <- pixel_date < start | pixel_date > end
  }
  if (any(outside)) {
    ef_abort(
      sprintf(
        paste0(
          "`composite_doy` must fall inside the composite period (%s to %s); ",
          "found %d value(s) outside it."
        ),
        format(start), format(end), sum(outside)
      ),
      class = c("earthflux_domain_error", "earthflux_input_error"),
      call = call
    )
  }
  lag[ok] <- as.numeric(lst_date - pixel_date)
  ef_reshape(lag, n, d)
}

# Spatial resampling -----------------------------------------------------------

#' Aggregate a MODIS layer to the working grid by an integer factor
#'
#' @description
#' Aggregates a finer MODIS layer (e.g. 500 m albedo, LAI or reflectances)
#' to the working grid (decision MP-08: the native 1 km sinusoidal grid of
#' the LST) by an integer factor, computing each value from the valid
#' sub-cells only when their fraction reaches `min_valid_fraction`, and
#' returns the valid-fraction layer (dev/specs/modis-products.md 9.2).
#'
#' @param x `SpatRaster` (one or more layers) on a grid nested in
#'   `template`: same CRS, same extent, and a resolution that divides the
#'   resolution of `template` by a whole factor (1 allowed: no aggregation).
#'   Invalid sub-cells (fill, QA masked) must already be `NA`.
#' @param template `SpatRaster` defining the working grid.
#' @param method Character, no default. Aggregation of the valid sub-cells:
#'   * `"mean"`: arithmetic mean (albedo, LAI, reflectances: section 9.2);
#'   * `"median"`: median (alternative for LAI);
#'   * `"modal"`: most frequent value, ties resolved to the smallest value
#'     (land cover classes; never a mean);
#'   * `"any"`: for 0/1 (or logical) mask layers, 1 when any valid sub-cell
#'     is 1 (worst case of a decoded QA condition; bits are never
#'     interpolated).
#'
#'   `"bilinear"` raises `earthflux_method_not_implemented`: interpolation
#'   is never used for aggregation (section 9.2, rule 1); a final
#'   reprojection of continuous variables is not part of this step.
#' @param min_valid_fraction Numeric scalar in (0, 1\], no default (the
#'   threshold is `TODO` in the specification): minimum fraction of valid
#'   sub-cells for a value to be computed.
#'
#' @return A list of `SpatRaster`s on the grid of `template`, one layer per
#'   layer of `x`:
#'   * `value`: aggregated values, `NA` where the valid fraction is below
#'     `min_valid_fraction`;
#'   * `valid_fraction`: fraction of valid sub-cells \[-\], in \[0, 1\];
#'   * `incomplete`: logical, `TRUE` where some but not enough sub-cells are
#'     valid (0 < fraction < `min_valid_fraction`). It maps to
#'     `EF_SURF_AGG_INCOMPLETE` (class II, threshold `TODO`; not
#'     registered). Cells without any valid sub-cell are `NA` for the
#'     upstream cause (fill, cloud, ...), not for the aggregation.
#'
#' @details
#' The grid must nest exactly: when the extents or the origins of `x` and
#' `template` do not match, the alignment rule is `TODO` (section 9.2, rule
#' 3) and an error is raised; nothing is shifted or resampled silently. The
#' exact nesting of the 500 m and 1 km MODIS grids is `DERIVADA` and pending
#' confirmation with a real file (section 4), and the factor for 250 m is
#' `TODO`. The view time and MOD13A2 NDVI are already at 1 km and need no
#' aggregation.
#'
#' Errors: `x` or `template` not a `SpatRaster`, different CRS, non-whole
#' resolution factor or misaligned extent -> `earthflux_input_error`;
#' `min_valid_fraction` outside (0, 1\] -> `earthflux_domain_error`; values
#' other than 0/1 with `"any"` -> `earthflux_domain_error`.
#'
#' @section Verification status:
#' Not a physical formulation; the rules are the provisional decision
#' MP-08 (dev/specs/modis-products.md 9.2). The area mean of the albedo
#' assumes uniform irradiance within the cell; non-linear effects of LAI
#' aggregation on G and the emissivity are `TODO`.
#' @noRd
modis_to_grid <- function(x, template, method, min_valid_fraction) {
  call <- sys.call()
  modis_check_method(
    method, c("mean", "median", "modal", "any"),
    planned = c(
      bilinear = paste0(
        "interpolation is never used to aggregate MODIS layers ",
        "(dev/specs/modis-products.md 9.2, rule 1)"
      )
    ),
    call = call
  )
  if (missing(min_valid_fraction)) {
    ef_abort("`min_valid_fraction` must be supplied explicitly.",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }
  check_scalar(min_valid_fraction, "min_valid_fraction", lower = 0,
               upper = 1, lower_inclusive = FALSE, call = call)
  for (nm in c("x", "template")) {
    if (!inherits(get(nm), "SpatRaster")) {
      ef_abort(sprintf("`%s` must be a SpatRaster.", nm),
               class = "earthflux_input_error", call = call)
    }
  }
  if (!terra::same.crs(x, template)) {
    ef_abort("`x` and `template` must share the CRS (no reprojection here).",
             class = "earthflux_input_error", call = call)
  }
  ratio <- terra::res(template) / terra::res(x)
  fact <- round(ratio)
  if (any(fact < 1) || any(abs(ratio - fact) > 1e-6 * fact)) {
    ef_abort(
      sprintf(
        paste0("The resolution of `template` must be a whole multiple of ",
               "that of `x`; ratio %s."),
        paste(format(ratio), collapse = " x ")
      ),
      class = "earthflux_input_error", call = call
    )
  }
  ex <- as.vector(terra::ext(x))
  et <- as.vector(terra::ext(template))
  if (any(abs(ex - et) > 1e-6 * min(terra::res(x)))) {
    ef_abort(
      paste0(
        "`x` and `template` must have the same extent (nested grids); the ",
        "alignment rule for other cases is TODO (dev/specs/modis-products.md ",
        "9.2, rule 3)."
      ),
      class = "earthflux_input_error", call = call
    )
  }
  if (method == "any") {
    v <- terra::values(x, mat = FALSE)
    if (any(!is.na(v) & !(v %in% c(0, 1)))) {
      ef_abort("`method = \"any\"` requires 0/1 (or logical) layers.",
               class = c("earthflux_domain_error", "earthflux_input_error"),
               call = call)
    }
  }

  valid <- !is.na(x)
  if (all(fact == 1L)) {
    value <- x
    frac <- valid * 1
  } else {
    frac <- terra::aggregate(valid, fact = fact, fun = "sum") / prod(fact)
    value <- switch(method,
      mean = terra::aggregate(x, fact = fact, fun = "mean", na.rm = TRUE),
      median = terra::aggregate(x, fact = fact, fun = "median",
                                na.rm = TRUE),
      modal = terra::aggregate(x, fact = fact, fun = modis_modal),
      any = terra::aggregate(x, fact = fact, fun = "max", na.rm = TRUE)
    )
  }
  if (!isTRUE(terra::compareGeom(value, template, stopOnError = FALSE))) {
    ef_abort("The aggregated grid does not match `template`.",
             class = "earthflux_input_error", call = call)
  }
  # Tolerance for fractions such as 2/3 compared with a threshold 2/3.
  enough <- frac >= min_valid_fraction - sqrt(.Machine$double.eps)
  value <- terra::ifel(enough, value, NA)
  incomplete <- frac > 0 & !enough
  names(value) <- names(x)
  names(frac) <- paste0(names(x), "_valid_fraction")
  names(incomplete) <- paste0(names(x), "_incomplete")
  list(value = value, valid_fraction = frac, incomplete = incomplete)
}

#' Most frequent value of a block, ties to the smallest value
#'
#' @param v Numeric vector of the sub-cell values.
#' @param ... Ignored (arguments passed by `terra::aggregate()`).
#' @return The most frequent non-missing value, or `NA` if none.
#' @noRd
modis_modal <- function(v, ...) {
  v <- v[!is.na(v)]
  if (length(v) == 0L) {
    return(NA_real_)
  }
  u <- sort(unique(v))
  u[which.max(tabulate(match(v, u), nbins = length(u)))]
}
