# MODIS: QA decoding, surface flags and layer converters -----------------------------
#
# Purpose: decode the QA layers of the MODIS products (bit fields and coded
#   layers), turn them into the cell flags EF_SURF_* of the surface stage and
#   convert the DN of the product layers into physical variables with their
#   masks, flags and QA policy. Together with R/io-modis.R,
#   R/prep-modis.R and R/modis-surface.R, the only place that knows MODIS QA
#   conventions (dev/specs/modis-products.md section 1; ARCHITECTURE
#   principle 2).
#
# Specification: dev/specs/modis-products.md section 5 (QA tables of each
#   sheet), 10 (QA policy: mask vs flag, `qa_policy`, bit decoding) and
#   13.2; dev/specs/flags.md section 4.2 (EF_SURF_ catalogue), 6.4 (bits)
#   and 7 (registration). Decisions: dev/DECISIONS.md section 1.4.
#
# Implemented (internal):
#   modis_qa_field()       one bit field of a QA integer (bit 0 = LSB)
#   modis_qa_layouts()     bit/code layout of every supported QA layer
#   modis_qa_rules()       QA field values -> EF_SURF_* codes (section 10.2)
#   modis_qa_decode()      QA DN -> data frame of named fields
#   modis_qa_masks()       decoded fields -> named list of logical masks
#   modis_qa_flags()       one QA layer -> masks, NA mask of the policy, flags
#   modis_na_codes(), modis_maskable_codes(), modis_policy_na()
#   ef_flags_surface()     registry rows of the stage (EF_SURF_*, including
#                          the view time, broadband albedo and view angle
#                          codes raised by modis_surface_state(),
#                          R/modis-surface.R, and the assigned LAI code of
#                          modis_lai())
#   ef_diagnose_surface()  masks -> earthflux_flag records (cell scope)
#   modis_flag_word()      masks -> integer flag word (bits of the registry)
#   modis_variable()       DN of one layer + its QA layers -> value, masks,
#                          flags, decoded QA and policy (the common engine)
#   modis_lst(), modis_view_zenith(), modis_band_emissivity(), modis_lai(),
#   modis_land_cover()     converters of section 13.2 built on it
#   check_lai_nonveg()     the explicit LAI of the non-vegetated classes
#                          (option `lai_nonveg`, decision MP-06)
#
# QA policy (section 10.3; decision MP-09 open): `qa_policy` is an explicit
#   argument without default, "flag" or "mask". The documented causes of NA
#   (section 10.2, mandatory rows) are applied under both: fill, DN outside
#   the valid range, MODLAND "not produced" (cloud / other reasons) and the
#   non-vegetated LAI classes (unless the user assigns them an explicit LAI
#   with `lai_nonveg`, flagged EF_SURF_LAI_ASSIGNED). "mask" additionally
#   sets to NA the conditions listed in `mask_codes`; every masked cell
#   keeps its flag and is counted. QA never changes a value otherwise.

# Bit fields --------------------------------------------------------------------

#' Extract a bit field from MODIS QA integers
#'
#' Field of `n` bits starting at bit `start` (bit 0 is the least
#' significant): `(qa %/% 2^start) %% 2^n` in double arithmetic, exact for
#' uint8, uint16 and uint32 values (dev/specs/modis-products.md section
#' 10.4).
#'
#' @param qa Numeric vector or array of QA integers in \[0, 2^32 - 1\].
#' @param start Integer. First bit (0-31).
#' @param n Integer. Number of bits (1 to `min(31, 32 - start)`, so that the
#'   field fits an R integer).
#' @return Integer vector with the shape of `qa`; `NA` where `qa` is `NA`.
#' @noRd
modis_qa_field <- function(qa, start, n) {
  check_numeric(qa)
  check_scalar(start, "start", lower = 0, upper = 31, whole = TRUE)
  check_scalar(n, "n", lower = 1, upper = min(31, 32 - start), whole = TRUE)
  v <- qa[!is.na(qa)]
  if (any(v != round(v) | v < 0 | v > 4294967295)) {
    ef_abort("`qa` must hold whole numbers in [0, 2^32 - 1].",
             class = "earthflux_input_error")
  }
  out <- (qa %/% 2^start) %% 2^n
  storage.mode(out) <- "integer"
  out
}

# Layouts and rules ------------------------------------------------------------

#' Build a QA layout
#' @noRd
qa_layout <- function(type, field, start, n, source, note = "") {
  data.frame(type = type, field = field, start = as.integer(start),
             n = as.integer(n), source = source, note = note,
             stringsAsFactors = FALSE)
}

#' Layouts of the supported MODIS QA layers
#'
#' Bit fields (`type = "bits"`, bit 0 least significant) or coded layers
#' (`type = "code"`, one field `code` holding the DN), transcribed from the
#' QA tables of dev/specs/modis-products.md section 5 (all `VERIFICADA`,
#' citation in `source`). Fields whose meaning is `TODO` are not decoded:
#' bits 3-2 of the MOD11 `QC_Day` (discrepancy d2).
#'
#' @return A named list of data frames (`type`, `field`, `start`, `n`,
#'   `source`, `note`), one per QA table key of the product table.
#' @noRd
modis_qa_layouts <- function() {
  b <- function(field, start, n, source, note = "") {
    qa_layout("bits", field, start, n, source, note)
  }
  code <- function(source) qa_layout("code", "code", 0L, NA_integer_, source)
  list(
    MOD11_QC = b(
      c("mandatory", "emis_error", "lst_error"), c(0, 4, 6), c(2, 2, 2),
      "D1 p. 21, Tabla 13 (modis-products.md 5.1 c)",
      note = "Bits 3-2 not decoded: discrepancy d2 (TODO)."
    ),
    MOD21_QC = b(
      c("mandatory", "data_quality", "cloud", "tes_iterations",
        "atm_opacity", "mmd", "emis_accuracy", "lst_accuracy"),
      seq(0, 14, by = 2), rep(2, 8),
      "D2 p. 26-27, Tabla 11 (modis-products.md 5.2 c)",
      note = "Category 00 of atm_opacity: discrepancy d3 (TODO)."
    ),
    MOD09_STATE = b(
      c("cloud_state", "cloud_shadow", "land_water", "aerosol", "cirrus",
        "internal_cloud", "internal_fire", "mod35_snow_ice",
        "cloud_adjacent", "salt_pan", "internal_snow"),
      c(0, 2, 3, 6, 8, 10, 11, 12, 13, 14, 15),
      c(2, 1, 3, 2, 2, 1, 1, 1, 1, 1, 1),
      "D3 p. 25-26, Tabla 13 (modis-products.md 5.3 c)"
    ),
    MOD09_QC_500M = b(
      c("modland", paste0("band", 1:7, "_quality"),
        "atmospheric_correction", "adjacency_correction"),
      c(0, seq(2, 26, by = 4), 30, 31), c(2, rep(4, 7), 1, 1),
      "D3 p. 22, Tabla 10 (modis-products.md 5.3 c)"
    ),
    MOD09_QC_250M = b(
      c("modland", "band1_quality", "band2_quality",
        "atmospheric_correction", "adjacency_correction"),
      c(0, 4, 8, 12, 13), c(2, 4, 4, 1, 1),
      "D3 p. 20, Tabla 8 (modis-products.md 5.4)"
    ),
    MOD13_VI_QUALITY = b(
      c("modland", "vi_usefulness", "aerosol", "adjacent_cloud",
        "brdf_correction", "mixed_clouds", "land_water", "snow_ice",
        "shadow"),
      c(0, 2, 6, 8, 9, 10, 11, 14, 15), c(2, 4, 2, 1, 1, 1, 3, 1, 1),
      "D4 p. 18, Tabla 5 (modis-products.md 5.5 c)"
    ),
    MOD13_RELIABILITY = code("D4 p. 17, Tabla 4 (modis-products.md 5.5 c)"),
    MCD15_FPARLAI_QC = b(
      c("modland", "sensor", "dead_detector", "cloud_state", "scf_qc"),
      c(0, 1, 2, 3, 5), c(1, 1, 1, 2, 3),
      "D5 p. 9-10, Tabla 5 (modis-products.md 5.7 c)"
    ),
    MCD15_FPAREXTRA_QC = b(
      c("land_sea", "snow_ice", "aerosol", "cirrus", "internal_cloud",
        "cloud_shadow", "scf_biome_mask"),
      c(0, 2, 3, 4, 5, 6, 7), c(2, 1, 1, 1, 1, 1, 1),
      "D5 p. 10 (modis-products.md 5.7 c)"
    ),
    MCD43_MANDATORY_NIR_SW = code("D8 (modis-products.md 5.6 c)"),
    MCD43A2_SNOW = code("D9 (modis-products.md 5.6 c)"),
    MCD12_QC = code("D6 p. 17, Tabla 11 (modis-products.md 5.8)")
  )
}

#' Build a QA rule
#' @noRd
qa_rule <- function(code, field, values, negate = FALSE) {
  list(code = code, field = field, values = values, negate = negate)
}

#' QA field values that raise each EF_SURF_ code
#'
#' Transcription of dev/specs/modis-products.md section 10.2 for every QA
#' table: MODLAND 01 -> `EF_SURF_QA_OTHER`, 10 -> `EF_SURF_CLOUD`, 11 ->
#' `EF_SURF_NOT_PRODUCED`; adjacent cloud / cirrus (MOD21 bits 5-4 values
#' 01 and 10; MOD09 bits 13 and 9-8; MOD13 bit 8) -> `EF_SURF_CLOUD_ADJACENT`;
#' snow/ice (MOD09 bits 12 and 15; MOD13 bit 14; MCD15 extra bit 2; MCD43A2
#' `Snow_BRDF_Albedo` = 1) -> `EF_SURF_SNOW`; land/water class other than
#' land (MOD09 and MOD13 classes 000-111 with 001 = land; MCD15 extra 00 =
#' land) -> `EF_SURF_WATER`; MOD09 bit 14 -> `EF_SURF_SALT_PAN`; MCD15
#' SCF_QC 010/011 -> `EF_SURF_LAI_BACKUP` and 100 (not produced) ->
#' `EF_SURF_NOT_PRODUCED`, and its one-bit MODLAND 1 (other quality) ->
#' `EF_SURF_QA_OTHER`; MCD43 mandatory quality 1, 3, 5, 7 ->
#' `EF_SURF_ALBEDO_MAGNITUDE`. Several rules of the same code are combined
#' with OR. Implementation decisions M4-03 and M4-04 (dev/DECISIONS.md):
#' MOD13 MODLAND 10 ("produced, probably cloudy") and MOD21 MODLAND 10
#' (discrepancy d4) are treated as `EF_SURF_CLOUD`; fields without a row in
#' section 10.2 (e.g. MOD09 cloud state, MOD21 cloud = 11, MCD15 cloud
#' state, MOD13 reliability, MCD12 QC) raise no code and stay available in
#' the decoded QA.
#'
#' @return A named list (QA table key) of lists of rules (`code`, `field`,
#'   `values`, `negate`).
#' @noRd
modis_qa_rules <- function() {
  modland <- list(
    qa_rule("EF_SURF_QA_OTHER", "modland", 1L),
    qa_rule("EF_SURF_CLOUD", "modland", 2L),
    qa_rule("EF_SURF_NOT_PRODUCED", "modland", 3L)
  )
  mandatory <- lapply(modland, function(r) {
    r$field <- "mandatory"
    r
  })
  list(
    MOD11_QC = mandatory,
    MOD21_QC = c(mandatory, list(
      qa_rule("EF_SURF_CLOUD_ADJACENT", "cloud", 1:2)
    )),
    MOD09_STATE = list(
      qa_rule("EF_SURF_CLOUD_ADJACENT", "cloud_adjacent", 1L),
      qa_rule("EF_SURF_CLOUD_ADJACENT", "cirrus", 1:3),
      qa_rule("EF_SURF_SNOW", "mod35_snow_ice", 1L),
      qa_rule("EF_SURF_SNOW", "internal_snow", 1L),
      qa_rule("EF_SURF_WATER", "land_water", 1L, negate = TRUE),
      qa_rule("EF_SURF_SALT_PAN", "salt_pan", 1L)
    ),
    MOD09_QC_500M = modland,
    MOD09_QC_250M = modland,
    MOD13_VI_QUALITY = c(modland, list(
      qa_rule("EF_SURF_CLOUD_ADJACENT", "adjacent_cloud", 1L),
      qa_rule("EF_SURF_SNOW", "snow_ice", 1L),
      qa_rule("EF_SURF_WATER", "land_water", 1L, negate = TRUE)
    )),
    MOD13_RELIABILITY = list(),
    MCD15_FPARLAI_QC = list(
      qa_rule("EF_SURF_QA_OTHER", "modland", 1L),
      qa_rule("EF_SURF_NOT_PRODUCED", "scf_qc", 4L),
      qa_rule("EF_SURF_LAI_BACKUP", "scf_qc", 2:3)
    ),
    MCD15_FPAREXTRA_QC = list(
      qa_rule("EF_SURF_WATER", "land_sea", 0L, negate = TRUE),
      qa_rule("EF_SURF_SNOW", "snow_ice", 1L)
    ),
    MCD43_MANDATORY_NIR_SW = list(
      qa_rule("EF_SURF_ALBEDO_MAGNITUDE", "code", c(1L, 3L, 5L, 7L))
    ),
    MCD43A2_SNOW = list(qa_rule("EF_SURF_SNOW", "code", 1L)),
    MCD12_QC = list()
  )
}

# Decoding ----------------------------------------------------------------------

#' Decode a MODIS QA layer
#'
#' @param qa Numeric vector or array of QA DN (raw, as read; checked).
#' @param product,layer Character. Product short name and QA layer (a row of
#'   the product table with `kind` `"qa_bits"` or `"qa_code"`).
#' @param collection Character. Collection.
#' @return A data frame with one row per element of `qa` (cell order): one
#'   integer column per field of the layout (`NA` where `qa` is `NA` or the
#'   fill value of the QA layer) and the logical column `fill`. Attributes
#'   `product`, `layer` and `qa_table`.
#' @noRd
modis_qa_decode <- function(qa, product, layer, collection = "061") {
  row <- modis_layer_spec(product, layer, collection)
  if (!row$kind %in% c("qa_bits", "qa_code")) {
    ef_abort(sprintf("Layer \"%s\" of %s is not a QA layer.", layer, product),
             class = "earthflux_input_error")
  }
  modis_check_dn(qa, row, what = "`qa`")
  layout <- modis_qa_layouts()[[row$qa_table]]
  v <- as.vector(qa)
  fill <- !is.na(v) & !is.na(row$fill) & v == row$fill
  use <- v
  use[fill] <- NA
  if (layout$type[1L] == "code") {
    cols <- list(code = as.integer(use))
  } else {
    cols <- lapply(seq_len(nrow(layout)), function(i) {
      modis_qa_field(use, layout$start[i], layout$n[i])
    })
    names(cols) <- layout$field
  }
  out <- as.data.frame(cols, stringsAsFactors = FALSE)
  out$fill <- fill
  attr(out, "product") <- product
  attr(out, "layer") <- layer
  attr(out, "qa_table") <- row$qa_table
  out
}

#' Masks of the EF_SURF_ codes raised by a decoded QA layer
#'
#' @param decoded Result of `modis_qa_decode()`.
#' @return A named list (codes, in registry order) of logical vectors
#'   without `NA`, one per code that the QA table can raise (possibly all
#'   `FALSE`); empty when the table raises none.
#' @noRd
modis_qa_masks <- function(decoded) {
  key <- attr(decoded, "qa_table", exact = TRUE)
  if (!is.data.frame(decoded) || is.null(key)) {
    ef_abort("`decoded` must be the result of modis_qa_decode().",
             class = "earthflux_input_error")
  }
  rules <- modis_qa_rules()[[key]]
  masks <- list()
  for (r in rules) {
    f <- decoded[[r$field]]
    hit <- f %in% r$values
    if (r$negate) hit <- !hit
    m <- !is.na(f) & hit
    masks[[r$code]] <- if (is.null(masks[[r$code]])) m else masks[[r$code]] | m
  }
  modis_order_masks(masks)
}

#' Order masks by the bit of their code in the registry
#' @noRd
modis_order_masks <- function(masks) {
  if (length(masks) == 0L) {
    return(masks)
  }
  reg <- ef_flag_registry()
  masks[order(reg$bit[match(names(masks), reg$code)])]
}

#' Combine masks by code with OR
#'
#' @param ... Named lists of logical masks of equal length.
#' @return A named list ordered by bit.
#' @noRd
modis_merge_masks <- function(...) {
  out <- list()
  for (m in list(...)) {
    for (code in names(m)) {
      out[[code]] <- if (is.null(out[[code]])) m[[code]] else
        out[[code]] | m[[code]]
    }
  }
  modis_order_masks(out)
}

# Policy ------------------------------------------------------------------------

#' Codes whose condition always makes the value NA
#'
#' The mandatory rows of dev/specs/modis-products.md section 10.2: fill, DN
#' outside the valid range, MODLAND "not produced" (cloud, other reasons)
#' and the non-vegetated LAI classes.
#'
#' @return Character vector.
#' @noRd
modis_na_codes <- function() {
  c("EF_SURF_FILL", "EF_SURF_CLOUD", "EF_SURF_NOT_PRODUCED",
    "EF_SURF_DN_OUT_OF_RANGE", "EF_SURF_LAI_NONVEG")
}

#' Codes that `qa_policy = "mask"` may set to NA
#'
#' The kept-with-flag rows of section 10.2 raised by the decoders.
#'
#' @return Character vector.
#' @noRd
modis_maskable_codes <- function() {
  c("EF_SURF_QA_OTHER", "EF_SURF_CLOUD_ADJACENT", "EF_SURF_SNOW",
    "EF_SURF_WATER", "EF_SURF_SALT_PAN", "EF_SURF_LAI_BACKUP",
    "EF_SURF_ALBEDO_MAGNITUDE")
}

#' Check the QA policy arguments
#'
#' @param qa_policy `"flag"` or `"mask"`, no default (MP-09 provisional).
#' @param mask_codes `NULL` with `"flag"`; with `"mask"`, a non-empty
#'   subset of `modis_maskable_codes()`.
#' @return `mask_codes` as a character vector (possibly empty), invisibly.
#' @noRd
check_qa_policy <- function(qa_policy, mask_codes, call = sys.call(-1)) {
  check_method(qa_policy, c("flag", "mask"), arg = "qa_policy", call = call)
  if (qa_policy == "flag") {
    if (length(mask_codes) > 0L) {
      ef_abort("`mask_codes` is only used with `qa_policy = \"mask\"`.",
               class = "earthflux_input_error", call = call)
    }
    return(invisible(character(0)))
  }
  ok <- is.character(mask_codes) && length(mask_codes) > 0L &&
    !anyNA(mask_codes) && all(mask_codes %in% modis_maskable_codes())
  if (!ok) {
    ef_abort(
      sprintf(paste0("With `qa_policy = \"mask\"`, `mask_codes` must list ",
                     "the conditions to mask, among: %s."),
              paste(modis_maskable_codes(), collapse = ", ")),
      class = "earthflux_input_error", call = call
    )
  }
  invisible(unique(mask_codes))
}

#' Cells set to NA by the QA policy
#'
#' @param masks Named list of masks (codes).
#' @param qa_policy,mask_codes See `check_qa_policy()` (already checked).
#' @param n Integer. Number of cells.
#' @return A list with `na` (logical) and `n_masked` (named integer: cells
#'   set to NA by each masked code under `"mask"`).
#' @noRd
modis_policy_na <- function(masks, mask_codes, n) {
  na <- rep(FALSE, n)
  for (code in intersect(names(masks), modis_na_codes())) {
    na <- na | masks[[code]]
  }
  n_masked <- integer(0)
  for (code in mask_codes) {
    m <- if (is.null(masks[[code]])) rep(FALSE, n) else masks[[code]]
    n_masked[code] <- sum(m & !na)
  }
  for (code in mask_codes) {
    if (!is.null(masks[[code]])) na <- na | masks[[code]]
  }
  list(na = na, n_masked = n_masked)
}

#' Surface flags of one decoded MODIS QA layer
#'
#' @param decoded Result of `modis_qa_decode()`.
#' @param qa_policy Character, no default: `"flag"` or `"mask"`
#'   (dev/specs/modis-products.md section 10.3; the recommendation `"flag"`
#'   of MP-09 is provisional, so internal functions take it explicitly).
#' @param mask_codes With `"mask"`: codes to set to `NA` (subset of
#'   `modis_maskable_codes()`); `NULL` with `"flag"`.
#' @return A list with `masks` (named logical masks, see
#'   `modis_qa_masks()`), `na` (cells that the policy sets to `NA`:
#'   mandatory codes plus `mask_codes`), `n_masked`, `flags` (records of
#'   `ef_diagnose_surface()`, with the attribute `evaluated`) and `policy`.
#' @noRd
modis_qa_flags <- function(decoded, qa_policy, mask_codes = NULL) {
  mask_codes <- check_qa_policy(qa_policy, mask_codes)
  masks <- modis_qa_masks(decoded)
  pol <- modis_policy_na(masks, mask_codes, nrow(decoded))
  list(masks = masks, na = pol$na, n_masked = pol$n_masked,
       flags = ef_diagnose_surface(masks),
       policy = list(qa_policy = qa_policy, mask_codes = mask_codes))
}

# Registry and diagnostics -------------------------------------------------------

#' Flag codes of the surface stage (EF_SURF_*)
#'
#' Codes of dev/specs/flags.md section 4.2 raised by the surface stage, with
#' the bits of section 6.4 (cell scope): the twelve class I codes of the
#' MODIS decoders of this file (bits 1-12), `EF_SURF_OVERPASS_MISSING`
#' (bit 13, class I: the view time is missing where the LST is valid; mask
#' `missing` of `modis_overpass_time()`) and the class III
#' `EF_SURF_ALBEDO_GT1` (bit 14, `critical`, error counterpart
#' `earthflux_domain_error`: the broadband albedo is above 1 and kept; mask
#' `gt1` of `modis_albedo()`), both raised by `modis_surface_state()`
#' (R/modis-surface.R), and `EF_SURF_LAI_ASSIGNED` (bit 15, class I,
#' `info`: the LAI of a non-vegetated class was assigned by the explicit
#' option `lai_nonveg` of `modis_lai()`; decision MP-06) and
#' `EF_SURF_VIEW_ANGLE_HIGH` (bit 16, class I, `warning`: the absolute view
#' zenith angle of the LST observation, `Day_view_angl`, is above the
#' explicit option `view_angle_max` of `modis_surface_options()`; raised by
#' `modis_surface_state()` in `flags_lst`; decision M5-26, which moved the
#' code from class II to class I with the threshold as an option without
#' default). Not registered: the class II codes
#' (`EF_SURF_LST_ERROR`, `EF_SURF_EMIS_ERROR`, `EF_SURF_COMPOSITE_LAG`,
#' `EF_SURF_AGG_INCOMPLETE`, `EF_SURF_OVERPASS_OUTSIDE_WINDOW`,
#' `EF_SURF_LST_IMPLAUSIBLE`), which need a threshold with a reference.
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_surface <- function() {
  codes <- c(
    "EF_SURF_FILL", "EF_SURF_CLOUD", "EF_SURF_NOT_PRODUCED",
    "EF_SURF_DN_OUT_OF_RANGE", "EF_SURF_LAI_NONVEG", "EF_SURF_QA_OTHER",
    "EF_SURF_CLOUD_ADJACENT", "EF_SURF_SNOW", "EF_SURF_WATER",
    "EF_SURF_SALT_PAN", "EF_SURF_LAI_BACKUP", "EF_SURF_ALBEDO_MAGNITUDE",
    "EF_SURF_OVERPASS_MISSING", "EF_SURF_ALBEDO_GT1", "EF_SURF_LAI_ASSIGNED",
    "EF_SURF_VIEW_ANGLE_HIGH"
  )
  n <- length(codes)
  ef_flag_rows(
    code = codes,
    stage = rep("SURF", n),
    severity = c(rep("info", 5L), rep("warning", 8L), "critical", "info",
                 "warning"),
    scope = rep("cell", n),
    bit = seq_len(n),
    error_class = c(rep(NA_character_, 13L), "earthflux_domain_error",
                    NA_character_, NA_character_),
    description = c(
      "The product value is the fill value of its layer; the output is NA.",
      paste0("The product QA reports the value as not produced (or most ",
             "probably cloudy) because of clouds; the output is NA."),
      paste0("The product QA reports the value as not produced for other ",
             "reasons; the output is NA."),
      paste0("The stored value is outside the valid range of its layer and ",
             "is not the fill value; the output is NA."),
      paste0("The LAI value is a non-vegetated land class code (249-254); ",
             "LAI is NA and the class is kept."),
      paste0("The product QA reports a value produced with other than the ",
             "best quality; the value is kept."),
      paste0("The product QA reports adjacent clouds or cirrus at this ",
             "location; the value is kept."),
      "The product QA reports snow or ice at this location; the value is kept.",
      paste0("The product QA reports a land/water class other than land at ",
             "this location; the value is kept."),
      "The product QA reports a salt pan at this location; the value is kept.",
      paste0("The LAI was retrieved with the backup empirical method ",
             "(SCF_QC 010 or 011); the value is kept."),
      paste0("The albedo was retrieved by a magnitude inversion (mandatory ",
             "quality 1, 3, 5 or 7); the value is kept."),
      paste0("The view time is missing where the LST is valid; the LST is ",
             "kept and the solar geometry of the cell is NA downstream."),
      paste0("The broadband albedo is above 1; the value is kept and must ",
             "be excluded before the soil heat flux and the net radiation."),
      paste0("The LAI value is a non-vegetated land class code (249-254) ",
             "and the LAI was assigned by the user option lai_nonveg (not ",
             "retrieved); the value and the layers computed from it are ",
             "kept."),
      paste0("The absolute view zenith angle of the LST observation is ",
             "above the option view_angle_max (large, mixed off-nadir ",
             "footprint); the LST is kept.")
    ),
    spec = c(
      rep("dev/specs/flags.md 4.2; dev/specs/modis-products.md 10.2", 12L),
      "dev/specs/flags.md 4.2; dev/specs/modis-products.md 6.2",
      "dev/specs/flags.md 4.2 (C12); dev/specs/modis-products.md 8.1",
      "dev/specs/flags.md 4.2; dev/specs/modis-products.md 5.7, 15 (MP-06)",
      "dev/specs/flags.md 4.2; dev/specs/modis-products.md 5.1 e (M5-26)"
    ),
    since = c(rep("0.1.0", n - 1L), "0.1.0.9000")
  )
}

#' Cell flags of the surface stage
#'
#' The `ef_diagnose_<stage>()` of the surface stage (dev/ARCHITECTURE.md
#' section 3.2): one `earthflux_flag` record (cell scope) per code flagged
#' somewhere; the codes evaluated travel in the attribute `evaluated`.
#'
#' @param masks Named list of logical masks without `NA` (codes registered
#'   for the cell scope, e.g. `EF_INPUT_NA` and `EF_SURF_*`).
#' @return A list built with `ef_flag_set()`.
#' @noRd
ef_diagnose_surface <- function(masks) {
  ef_flag_set(masks, scope = "cell")
}

#' Integer flag word of a surface layer
#'
#' Sets, for every cell, the bit of each code whose mask is `TRUE`, with the
#' bits read from the registry (dev/specs/flags.md section 6.3-6.4; never
#' fixed numbers). `0` = evaluated and no condition active.
#'
#' @param masks Named list of logical masks of equal length (codes of the
#'   stages `INPUT` and `SURF`).
#' @return Integer vector (cell order).
#' @noRd
modis_flag_word <- function(masks) {
  if (length(masks) == 0L) {
    ef_abort("`masks` must contain at least one mask.",
             class = "earthflux_input_error")
  }
  reg <- ef_flag_registry()
  i <- match(names(masks), reg$code)
  if (anyNA(i) || any(!reg$stage[i] %in% c("INPUT", "SURF")) ||
      anyNA(reg$bit[i])) {
    ef_abort("`masks` must be named by registered INPUT/SURF cell codes.",
             class = "earthflux_unknown_flag")
  }
  n <- length(masks[[1L]])
  word <- rep(0L, n)
  for (k in seq_along(masks)) {
    word <- bitwOr(word, ifelse(as.vector(masks[[k]]),
                                bitwShiftL(1L, reg$bit[i[k]]), 0L))
  }
  word
}

# Layer converters ---------------------------------------------------------------

#' Convert the DN of one MODIS layer with its QA layers
#'
#' The common engine of the converters of dev/specs/modis-products.md
#' section 13.2: scales the DN with the product table
#' (`modis_apply_scale()`), decodes each QA layer (`modis_qa_decode()`),
#' builds the masks of `EF_INPUT_NA` (DN missing), `EF_SURF_FILL`,
#' `EF_SURF_DN_OUT_OF_RANGE`, the special codes of the layer (LAI
#' `EF_SURF_LAI_NONVEG`) and of every code the QA layers can raise, and
#' applies the QA policy. QA layers must be on the same cells as `dn`
#' (resampling QA is the job of the caller, never by interpolation).
#'
#' @param dn Numeric vector or array of raw DN (or a single-layer
#'   `SpatRaster`, converted with `modis_values()`).
#' @param product,layer Character. Product and value layer.
#' @param qa Named list of QA DN (names: QA layers of the same product),
#'   possibly empty. Each element has the length of `dn`.
#' @param qa_policy `"flag"` or `"mask"`, no default; required when a QA
#'   layer can raise a code, ignored (may be `NULL`) otherwise.
#' @param mask_codes See `modis_qa_flags()`.
#' @param collection Character. Collection.
#' @return A list with `value` (numeric, shape of `dn`, unit of the layer;
#'   `NA` for the documented causes and the masked codes), `product`,
#'   `layer`, `unit`, `masks` (named logical vectors in cell order, one per
#'   code evaluated, ordered by bit), `na` (logical: cells set to `NA` by
#'   the policy or by the scaling), `flags` (records, attribute `evaluated`),
#'   `qa` (named list of decoded QA data frames), `policy` (`qa_policy`,
#'   `mask_codes`, `n_masked`) and `source` (product table rows used, with
#'   their citations).
#' @noRd
modis_variable <- function(dn, product, layer, qa, qa_policy,
                           mask_codes = NULL, collection = "061") {
  dn <- modis_values(dn)
  row <- modis_layer_spec(product, layer, collection)
  if (row$kind %in% c("qa_bits", "qa_code")) {
    ef_abort(sprintf("Layer \"%s\" is a QA layer; use modis_qa_decode().",
                     layer), class = "earthflux_input_error")
  }
  if (!is.list(qa) || (length(qa) > 0L &&
                       (is.null(names(qa)) || any(!nzchar(names(qa)))))) {
    ef_abort("`qa` must be a named list of QA layers (possibly empty).",
             class = "earthflux_input_error")
  }
  qa <- lapply(qa, modis_values)
  n <- length(dn)
  bad_len <- names(qa)[lengths(qa) != n]
  if (length(bad_len) > 0L) {
    ef_abort(sprintf("QA layer(s) %s must have the length of `dn` (%d).",
                     paste0("\"", bad_len, "\"", collapse = ", "), n),
             class = "earthflux_input_error")
  }
  qa_rows <- lapply(names(qa), modis_layer_spec, product = product,
                    collection = collection)
  can_raise <- any(vapply(qa_rows, function(r) {
    !is.na(r$qa_table) && length(modis_qa_rules()[[r$qa_table]]) > 0L
  }, logical(1)))
  if (can_raise || (!missing(qa_policy) && !is.null(qa_policy))) {
    mask_codes <- check_qa_policy(qa_policy, mask_codes)
  } else {
    qa_policy <- NULL
    mask_codes <- character(0)
  }

  sc <- modis_apply_scale(dn, row)
  masks <- list(EF_INPUT_NA = as.vector(is.na(dn)),
                EF_SURF_FILL = sc$fill,
                EF_SURF_DN_OUT_OF_RANGE = sc$out_of_range)
  if (!is.na(row$special_flag)) {
    masks[[row$special_flag]] <- sc$special
  }
  decoded <- lapply(names(qa), function(nm) {
    modis_qa_decode(qa[[nm]], product, nm, collection)
  })
  names(decoded) <- names(qa)
  masks <- modis_merge_masks(masks, list(),
                             Reduce(modis_merge_masks,
                                    lapply(decoded, modis_qa_masks),
                                    list()))
  pol <- modis_policy_na(masks, mask_codes, n)
  na <- pol$na | sc$fill | sc$special | sc$out_of_range
  value <- sc$value
  value[na] <- NA_real_

  list(
    value = value,
    product = product,
    layer = layer,
    unit = row$unit,
    masks = masks,
    na = na,
    flags = ef_diagnose_surface(masks),
    qa = decoded,
    policy = list(qa_policy = qa_policy, mask_codes = mask_codes,
                  n_masked = pol$n_masked),
    source = do.call(rbind, c(list(row), qa_rows))
  )
}

#' Land surface temperature from MODIS
#'
#' `LST_Day_1km` + `QC_Day` (MOD11A1/MYD11A1) or `LST_1KM` + `QC`
#' (MOD21A1D/MYD21A1D): LST \[K\] = DN * 0.02 (product table; section 5.1,
#' 5.2), with fill and range `NA`, MODLAND flags and the QA policy.
#'
#' @param lst_dn,qc_dn DN of the LST and QC layers (same cells).
#' @param product Character. One of `"MOD11A1"`, `"MYD11A1"`, `"MOD21A1D"`,
#'   `"MYD21A1D"` (decision MP-01 open: no default product).
#' @inheritParams modis_variable
#' @return See `modis_variable()`; `value` is LST \[K\].
#' @noRd
modis_lst <- function(lst_dn, qc_dn, product, qa_policy, mask_codes = NULL,
                      collection = "061") {
  check_method(product, c("MOD11A1", "MYD11A1", "MOD21A1D", "MYD21A1D"),
               arg = "product")
  mod11 <- product %in% c("MOD11A1", "MYD11A1")
  layer <- if (mod11) "LST_Day_1km" else "LST_1KM"
  qc <- if (mod11) "QC_Day" else "QC"
  modis_variable(lst_dn, product, layer, stats::setNames(list(qc_dn), qc),
                 qa_policy, mask_codes, collection)
}

#' View zenith angle from MODIS
#'
#' `Day_view_angl` (MOD11A1/MYD11A1) or `View_Angle` (MOD21A1D/MYD21A1D):
#' angle \[degree\] = DN * 1 - 65, negative when the cell is observed from
#' the east (D1 p. 16-17). The zenith angle itself is the absolute value.
#'
#' @param view_angle_dn DN of the view angle layer.
#' @inheritParams modis_lst
#' @return See `modis_variable()`; `value` in degrees, with sign.
#' @noRd
modis_view_zenith <- function(view_angle_dn, product, collection = "061") {
  check_method(product, c("MOD11A1", "MYD11A1", "MOD21A1D", "MYD21A1D"),
               arg = "product")
  layer <- if (product %in% c("MOD11A1", "MYD11A1")) "Day_view_angl" else
    "View_Angle"
  modis_variable(view_angle_dn, product, layer, list(), NULL,
                 collection = collection)
}

#' Band emissivity from MODIS
#'
#' `Emis_<band>`: emissivity \[-\] = DN * 0.002 + 0.49 (MOD11A1/MYD11A1:
#' bands 31, 32; MOD21A1D/MYD21A1D: 29, 31, 32). Narrow-band values; the
#' broadband conversion is decision MP-04 (R/prep-modis.R).
#'
#' @param emis_dn DN of the emissivity layer.
#' @param band Character. `"29"`, `"31"` or `"32"`.
#' @inheritParams modis_lst
#' @return See `modis_variable()`; `value` dimensionless.
#' @noRd
modis_band_emissivity <- function(emis_dn, product, band,
                                  collection = "061") {
  check_method(product, c("MOD11A1", "MYD11A1", "MOD21A1D", "MYD21A1D"),
               arg = "product")
  check_method(band, c("29", "31", "32"), arg = "band")
  modis_variable(emis_dn, product, paste0("Emis_", band), list(), NULL,
                 collection = collection)
}

#' Labels of the non-vegetated LAI class codes
#'
#' D5 p. 11, Tabla 6 (dev/specs/modis-products.md section 5.7, `VERIFICADA`).
#'
#' @return Named character vector (names: codes 249-254).
#' @noRd
modis_lai_classes <- function() {
  c("249" = "unclassified",
    "250" = "urban or built-up",
    "251" = "permanent wetlands",
    "252" = "perennial snow or ice",
    "253" = "barren or sparse vegetation (rock, tundra, desert)",
    "254" = "perennial salt or inland fresh water")
}

#' Check the explicit LAI of the non-vegetated MCD15A2H classes
#'
#' Option `lai_nonveg` (decision MP-06, author's decision of 2026-11-04;
#' open question A-M4-6): `NULL` keeps the non-vegetated class codes
#' 249-254 as `NA`; a single unnamed number assigns that LAI to the six
#' classes; a named vector assigns a LAI per class, named by class code
#' (`"249"` ... `"254"`, `modis_lai_classes()`), and the classes not named
#' stay `NA`.
#'
#' @param lai_nonveg `NULL`, a single number, or a named numeric vector.
#'   Values in \[0, maximum physical LAI of `Lai_500m`\] \[m2 m-2\]
#'   (product table, `DERIVADA`), no `NA`.
#' @return `NULL`, or a named numeric vector (names: class codes, in
#'   increasing order). Errors: malformed values or names ->
#'   `earthflux_input_error`; values outside the range ->
#'   `earthflux_domain_error`.
#' @noRd
check_lai_nonveg <- function(lai_nonveg, call = sys.call(-1)) {
  if (is.null(lai_nonveg)) {
    return(NULL)
  }
  classes <- names(modis_lai_classes())
  nms <- names(lai_nonveg)
  if (!is.numeric(lai_nonveg) || length(lai_nonveg) == 0L ||
      anyNA(lai_nonveg)) {
    ef_abort(
      paste0("`lai_nonveg` must be NULL, one number or a numeric vector ",
             "named by class code (249-254), without NA."),
      class = "earthflux_input_error", call = call
    )
  }
  if (is.null(nms)) {
    if (length(lai_nonveg) != 1L) {
      ef_abort(
        paste0("An unnamed `lai_nonveg` must be one number (all the ",
               "non-vegetated classes); name the values by class code to ",
               "assign them per class."),
        class = "earthflux_input_error", call = call
      )
    }
    lai_nonveg <- stats::setNames(rep(as.numeric(lai_nonveg),
                                      length(classes)), classes)
  } else if (any(is.na(nms) | !nms %in% classes) || anyDuplicated(nms) > 0L) {
    ef_abort(
      sprintf(paste0("The names of `lai_nonveg` must be distinct class codes ",
                     "among %s."), paste(classes, collapse = ", ")),
      class = "earthflux_input_error", call = call
    )
  }
  row <- modis_layer_spec("MCD15A2H", "Lai_500m")
  check_in_range(lai_nonveg, "lai_nonveg", lower = 0,
                 upper = row$physical_max, call = call)
  lai_nonveg <- lai_nonveg[order(as.integer(names(lai_nonveg)))]
  stats::setNames(as.numeric(lai_nonveg), names(lai_nonveg))
}

#' Leaf area index from MCD15A2H
#'
#' `Lai_500m` \[m2 m-2\] = DN * 0.1 with `FparLai_QC` and, when given,
#' `FparExtra_QC`. The non-vegetated class codes 249-254 give `NA` LAI with
#' `EF_SURF_LAI_NONVEG` and the class kept in `class` (decision MP-06: no
#' silent LAI = 0), unless an explicit LAI is assigned to them with
#' `lai_nonveg`.
#'
#' **Assigned LAI** (`lai_nonveg`, MP-06; `CANDIDATA`): in the cells of an
#' assigned class the LAI is the value given (the class code, not a
#' retrieval, is its source) and the cell carries `EF_SURF_LAI_ASSIGNED`
#' (`info`) instead of `EF_SURF_LAI_NONVEG`, which keeps its meaning (the
#' LAI is `NA`) and is still raised in the classes not assigned. The causes
#' of `NA` of the QA of the absent retrieval (e.g. `EF_SURF_NOT_PRODUCED`
#' from SCF_QC 100) are not raised in an assigned cell, as in the
#' aggregation (M4-21: they explain a missing value); the warnings of the
#' QA (`EF_SURF_QA_OTHER`, `EF_SURF_SNOW`, `EF_SURF_WATER`, ...) are kept.
#' The codes masked by the user (`qa_policy = "mask"`) take precedence: a
#' masked cell of an assigned class stays `NA` with its flags and is counted
#' in `n_masked`.
#'
#' @param lai_dn,fparlai_qc_dn DN of `Lai_500m` and `FparLai_QC`.
#' @param fparextra_qc_dn DN of `FparExtra_QC`, or `NULL` (no default: the
#'   caller states whether the snow and land/sea bits are evaluated).
#' @param lai_nonveg `NULL` (default: the non-vegetated classes are `NA`,
#'   the provisional recommendation of MP-06), or the explicit LAI
#'   \[m2 m-2\] of those classes: one number for all of them, or a vector
#'   named by class code (`"249"` ... `"254"`); see `check_lai_nonveg()`.
#' @inheritParams modis_variable
#' @return See `modis_variable()`, plus `class` (integer class code 249-254,
#'   `NA` elsewhere; kept in assigned cells), `class_labels`
#'   (`modis_lai_classes()`) and `lai_nonveg` (the checked option, `NULL`
#'   when not used).
#' @noRd
modis_lai <- function(lai_dn, fparlai_qc_dn, fparextra_qc_dn, qa_policy,
                      mask_codes = NULL, collection = "061",
                      lai_nonveg = NULL) {
  lai_nonveg <- check_lai_nonveg(lai_nonveg, call = sys.call())
  qa <- list(FparLai_QC = fparlai_qc_dn)
  if (!is.null(fparextra_qc_dn)) qa$FparExtra_QC <- fparextra_qc_dn
  out <- modis_variable(lai_dn, "MCD15A2H", "Lai_500m", qa, qa_policy,
                        mask_codes, collection)
  v <- as.vector(modis_values(lai_dn))
  cls <- ifelse(out$masks$EF_SURF_LAI_NONVEG, v, NA)
  out$class <- as.integer(cls)
  out$class_labels <- modis_lai_classes()
  out$lai_nonveg <- lai_nonveg
  if (!is.null(lai_nonveg)) {
    out <- modis_lai_assign(out, lai_nonveg)
  }
  out
}

#' Assign the explicit LAI of the non-vegetated classes
#'
#' @param x Result of `modis_lai()` before the assignment.
#' @param lai_nonveg Checked option (`check_lai_nonveg()`), not `NULL`.
#' @return `x` with `value`, `na`, `masks`, `flags` and `policy$n_masked`
#'   updated (see `modis_lai()`).
#' @noRd
modis_lai_assign <- function(x, lai_nonveg) {
  n <- length(x$class)
  given <- unname(lai_nonveg[as.character(x$class)])
  assignable <- !is.na(given)
  na_codes <- modis_na_codes()
  # Masks as if the assignable cells had a value: the NA causes of the
  # absent retrieval are not raised there (M4-21); then the codes masked
  # by the user decide (and are counted).
  masks <- x$masks
  for (code in intersect(names(masks), na_codes)) {
    masks[[code]] <- masks[[code]] & !assignable
  }
  pol <- modis_policy_na(masks, x$policy$mask_codes, n)
  assign <- assignable & !pol$na
  for (code in intersect(names(masks), na_codes)) {
    masks[[code]] <- x$masks[[code]] & !assign
  }
  masks$EF_SURF_LAI_ASSIGNED <- assign
  masks <- modis_order_masks(masks)
  value <- x$value
  value[assign] <- given[assign]
  x$value <- value
  x$na <- x$na & !assign
  x$masks <- masks
  x$flags <- ef_diagnose_surface(masks)
  x$policy$n_masked <- pol$n_masked
  x
}

#' Land cover class from MCD12Q1
#'
#' `LC_Type1` (IGBP) or `LC_Type3` (LAI scheme) as integer classes, with the
#' coded `QC` decoded (no QC code raises a flag: the meaning of each code
#' for EarthFlux is not specified in section 10.2).
#'
#' @param lc_dn,qc_dn DN of the class layer and of `QC`.
#' @param layer Character. `"LC_Type1"` or `"LC_Type3"`, no default.
#' @inheritParams modis_variable
#' @return See `modis_variable()`; `value` is the class code.
#' @noRd
modis_land_cover <- function(lc_dn, qc_dn, layer, collection = "061") {
  check_method(layer, c("LC_Type1", "LC_Type3"), arg = "layer")
  modis_variable(lc_dn, "MCD12Q1", layer, list(QC = qc_dn), NULL,
                 collection = collection)
}
