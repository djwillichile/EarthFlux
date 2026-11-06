# High-level API: execution of the METRIC chain ---------------------------------
#
# Purpose: run the METRIC chain of a preset on prepared inputs (cell values of
#   the working grid, R/api-prepare.R), in the order of dev/specs/presets.md
#   section 2:
#     solar geometry -> pressure -> z_om, wind at the blending height
#     -> anchors (before Rn: incoming longwave from the cold anchor, P0-3,
#        M5-11) -> tau_sw -> Rs_in -> eps_a -> RL_in, RL_out -> Rn -> G
#     -> lambda -> anchor conditions -> H calibration (phases A and B)
#     -> LE -> ET_inst -> ETrF -> ETa_24
#   keeping each intermediate product and the flags of every stage. Only
#   ef_*() functions compute; this file passes their outputs on, applies the
#   minimum z_om of the preset (workflow_zom_floor(), flagged, M5-24),
#   converts between the terra cell order and the wide matrices of the core,
#   and builds the flag words of the result.
#
# Contents (all internal):
#   workflow_matrix(), workflow_cells()   cell order <-> wide matrices
#   workflow_zom_floor()                  minimum z_om of the preset (M5-24)
#   workflow_anchor_qa()                  strict QA of the anchor candidates
#   workflow_metric()                     the chain
#   workflow_cell_records()               flag records -> terra cells
#   workflow_flag_word()                  flag records -> flag word
#   ef_flags_workflow()                   registry rows of the workflow

#' Wide matrix of a layer in terra cell order
#'
#' @param v Numeric (or logical) vector in terra cell order.
#' @param nr,nc Rows and columns of the grid.
#' @return A matrix `nr` x `nc` (rows and columns of the grid).
#' @noRd
workflow_matrix <- function(v, nr, nc) {
  matrix(v, nrow = nr, ncol = nc, byrow = TRUE)
}

#' Values of a wide matrix in terra cell order
#'
#' @param m A matrix with the rows and columns of the grid, or a scalar.
#' @param n Number of cells (used for scalars).
#' @return A vector in terra cell order.
#' @noRd
workflow_cells <- function(m, n) {
  if (is.null(dim(m))) {
    return(rep_len(as.vector(m), n))
  }
  as.vector(t(m))
}

#' Terra cell of positions of a wide matrix
#'
#' @param pos Integer positions (column-major) in an `nr` x `nc` matrix.
#' @param nr,nc Rows and columns.
#' @return Integer terra cell numbers (row-major).
#' @noRd
workflow_pos_to_cell <- function(pos, nr, nc) {
  row <- (pos - 1L) %% nr + 1L
  col <- (pos - 1L) %/% nr + 1L
  as.integer((row - 1L) * nc + col)
}

#' Cell-scope flag records of the core expressed on terra cells
#'
#' The dispatchers of the core flag positions of the matrices they received
#' (column-major); the result refers every cell-scope record to terra cells
#' and names the layer in `target` (dev/ARCHITECTURE.md 3.5), as the surface
#' state does.
#'
#' @param records List of `earthflux_flag` records.
#' @param target Name of the layer.
#' @param nr,nc Rows and columns of the grid.
#' @return The records (cell scope only), with `index`, `n_total` and
#'   `target` updated.
#' @noRd
workflow_cell_records <- function(records, target, nr, nc) {
  cell <- Filter(function(f) identical(f$scope, "cell"), records)
  lapply(cell, function(f) {
    if (f$n_total == nr * nc) {
      f$index <- sort(workflow_pos_to_cell(f$index, nr, nc))
    }
    f$n_total <- as.integer(nr * nc)
    f$target <- target
    f
  })
}

#' Merge cell records by code and target, restricted to evaluated cells
#'
#' One record per code and layer (e.g. `EF_INPUT_NA` of the
#' transmissivity and of the shortwave, both on `rs_in`), with the indices
#' restricted to the cells evaluated (inside the AOI); records left without
#' flagged cells are dropped (dev/specs/flags.md 6.7: only codes that hold).
#'
#' @param records Cell-scope records on terra cells.
#' @param evaluated Logical per cell.
#' @return A list of `earthflux_flag` records.
#' @noRd
workflow_merge_records <- function(records, evaluated) {
  if (length(records) == 0L) {
    return(list())
  }
  key <- vapply(records, function(f) paste(f$code, f$target), "")
  out <- lapply(unique(key), function(k) {
    group <- records[key == k]
    f <- group[[1L]]
    idx <- sort(unique(unlist(lapply(group, `[[`, "index"))))
    f$index <- as.integer(idx[evaluated[idx]])
    f$n_flagged <- length(f$index)
    f
  })
  Filter(function(f) f$n_flagged > 0L, out)
}

#' Flag word of a layer from cell-scope records
#'
#' Bits of the registry (read by code, never fixed); `NA` where the cell is
#' not evaluated (outside the AOI), 0 where evaluated and no condition
#' holds (dev/specs/flags.md 6.3).
#'
#' @param records Cell-scope records on terra cells
#'   (`workflow_cell_records()`).
#' @param evaluated Logical per cell.
#' @return Integer vector in terra cell order.
#' @noRd
workflow_flag_word <- function(records, evaluated) {
  reg <- ef_flag_registry()
  word <- ifelse(evaluated, 0L, NA_integer_)
  for (f in records) {
    b <- reg$bit[match(f$code, reg$code)]
    if (is.na(b) || length(f$index) == 0L) next
    i <- f$index[evaluated[f$index]]
    word[i] <- bitwOr(word[i], bitwShiftL(1L, b))
  }
  word
}

#' Registry rows of the workflow
#'
#' `EF_H_ZOM_FLOOR_APPLIED` (decision M5-24, dev/specs/sensible-heat.md
#' SH-02): the presets raise the momentum roughness length of
#' `ef_zom(method = "lai")` to the minimum of the preset (0.005 m,
#' `CANDIDATA`) where 0.018 LAI is below it, and flag the cell. Class I-m
#' (the minimum is part of the roughness rule of the preset), `info`, cell
#' scope, bit 1 of the `H` stage (the bit planned in dev/specs/flags.md
#' 6.4). Registered with a `CANDIDATA` rule by decision of the author, as
#' `EF_G_LOW_LAI_BRANCH` (exception to dev/specs/flags.md 7, point 3).
#' Raised by `workflow_zom_floor()`. It replaces `EF_H_ZOM_UNDEFINED`
#' (M5-13, retired with its bit kept as occupied, `ef_flag_retired()`).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_workflow <- function() {
  ef_flag_rows(
    code = "EF_H_ZOM_FLOOR_APPLIED",
    stage = "H",
    severity = "info",
    scope = "cell",
    bit = 1L,
    error_class = NA_character_,
    description = paste0(
      "The momentum roughness length of the method is below the minimum ",
      "of the preset and was raised to that minimum."
    ),
    spec = "dev/specs/flags.md 4.2; dev/specs/sensible-heat.md 5.6",
    since = "0.1.0.9000"
  )
}

#' Minimum momentum roughness length of a preset
#'
#' Raises the momentum roughness length to `zom_min` where the method gives
#' less (z_om = 0.018 LAI is 0 where LAI = 0, which `ef_ustar()` rejects),
#' and flags those cells with `EF_H_ZOM_FLOOR_APPLIED` (decision M5-24;
#' dev/specs/sensible-heat.md 5.6, SH-02). The minimum is `CANDIDATA`: the
#' SEBAL Idaho manual gives z_om = 0.018 LAI only for agricultural areas
#' (p. 27, Eq. 31a) and land-use values in its appendix 2 (water 0.0005 m,
#' snow 0.005 m, among others) with no value for bare soil. Missing values
#' stay missing.
#'
#' @param zom Numeric (matrix) of z_om from `ef_zom()` \[m\].
#' @param zom_min Numeric scalar \[m\], `> 0`.
#' @return A list: `zom` (same shape), `floored` (logical, same shape) and
#'   `flags` (the result of `ef_flag_set()`, cell scope, positions of
#'   `as.vector(zom)`).
#' @noRd
workflow_zom_floor <- function(zom, zom_min) {
  check_scalar(zom_min, "zom_min", lower = 0, lower_inclusive = FALSE)
  floored <- !is.na(zom) & zom < zom_min
  zom[floored] <- zom_min
  list(
    zom = zom,
    floored = floored,
    flags = ef_flag_set(list(EF_H_ZOM_FLOOR_APPLIED = as.vector(floored)),
                        scope = "cell")
  )
}

#' Strict QA of the anchor candidates
#'
#' Decisions M5-10 / M5-17 / M5-24 (dev/specs/presets.md 4): a cell may
#' hold an anchor only if no `warning` or `critical` bit of the surface
#' stage, nor any bit of `exclude_codes` (`EF_SURF_LAI_ASSIGNED` in the
#' presets: LAI set by an option, not retrieved), is set in the words of
#' LST, albedo, NDVI, LAI and emissivity, every aggregated input has all its
#' sub-cells valid, the forcing at its overpass time is neither
#' extrapolated nor outside the hull or the domain of the fits (GWR bits 1,
#' 3, 6), and every input of the chain at the anchor is defined (elevation,
#' z_om, forcing, overpass time).
#'
#' @param st The surface state.
#' @param forcing Result of `workflow_forcing()`.
#' @param defined Logical per cell: every input of the chain defined.
#' @param exclude_codes Character. Surface codes that exclude a cell
#'   whatever their severity.
#' @return Logical per cell (no `NA`).
#' @noRd
workflow_anchor_qa <- function(st, forcing, defined,
                               exclude_codes = character(0)) {
  words <- terra::values(st$qa$flag_word, mat = TRUE)
  bits <- st$qa$flag_bits
  bad_codes <- union(bits$code[bits$severity %in% c("warning", "critical")],
                     intersect(exclude_codes, bits$code))
  ok <- defined
  for (l in paste0("flags_", c("lst", "albedo", "ndvi", "lai",
                               "emissivity"))) {
    if (!l %in% colnames(words)) next
    w <- as.integer(words[, l])
    ok <- ok & !is.na(w) & !workflow_word_has(w, bits, bad_codes)
  }
  vf <- terra::values(st$qa$valid_fraction, mat = TRUE)
  if (ncol(vf) > 0L) {
    ok <- ok & rowSums(is.na(vf) | vf < 1) == 0L
  }
  gwr <- c("EF_GWR_EXTRAPOLATION_COVARIATE", "EF_GWR_OUTSIDE_HULL",
           "EF_GWR_OUT_OF_DOMAIN")
  for (w in forcing$words) {
    ok <- ok & !is.na(w) & !workflow_word_has(w, forcing$flag_bits, gwr)
  }
  ok & !is.na(ok)
}

#' The METRIC chain of a preset on prepared inputs
#'
#' @param x Named list of cell values in terra cell order: `lst`, `albedo`
#'   (critical surface cells already `NA`), `ndvi`, `lai`, `emissivity`,
#'   `doy`, `utc_hour`, `lon`, `lat` (degrees), `elevation`, `etr_inst`,
#'   `etr_24`, `wind_speed_2m`, `anchor_qa` (logical) and `search_area`
#'   (`NULL` or a list of logical vectors).
#' @param preset An `earthflux_preset`.
#' @param grid The working grid.
#' @param scene Scene constants: `tau_elevation` (flat preset),
#'   `datum_elevation` (`NULL`: the elevation of the cold calibration
#'   point) and `etr_source`.
#' @return A list with `layers` (named list of wide matrices), `objects`
#'   (the classed results of the core) and `flags` (cell records on terra
#'   cells per layer, `evaluated` codes) and `zom_floor_applied` (count of
#'   cells raised to the minimum z_om).
#' @noRd
workflow_metric <- function(x, preset, grid, scene) {
  nr <- terra::nrow(grid)
  nc <- terra::ncol(grid)
  m <- function(v) workflow_matrix(v, nr, nc)
  deg <- pi / 180
  lst <- m(x$lst)
  albedo <- m(x$albedo)
  ndvi <- m(x$ndvi)
  lai <- m(x$lai)
  emissivity <- m(x$emissivity)
  elevation <- m(x$elevation)
  etr_inst <- m(x$etr_inst)
  etr_24 <- m(x$etr_24)
  wind <- m(x$wind_speed_2m)

  # Solar geometry at the overpass, flat projection (slope 0, RC-09) ----------
  geo <- ef_solar_geometry(doy = m(x$doy), utc_hour = m(x$utc_hour),
                           lat = m(x$lat) * deg, lon = m(x$lon) * deg,
                           slope = preset$radiation$slope, aspect = 0)
  pressure <- ef_air_pressure(elevation)

  # Roughness (with the minimum of the preset, M5-24) and wind at the
  # blending height ------------------------------------------------------------
  zom_obj <- ef_zom(lai = lai, method = preset$roughness$method)
  zf <- workflow_zom_floor(zom_obj$zom, preset$roughness$zom_min)
  zom <- zf$zom
  w <- preset$wind
  u_blend <- ef_blending_wind(wind, height = w$height,
                              zom_station = w$zom_station,
                              d_station = w$d_station,
                              blending_height = w$blending_height)

  # Anchors before Rn (incoming longwave from the cold anchor) -----------------
  defined <- !is.na(lst) & !is.na(albedo) & !is.na(ndvi) & !is.na(lai) &
    !is.na(emissivity) & !is.na(elevation) & !is.na(zom) &
    !is.na(u_blend) & !is.na(etr_inst) & !is.na(geo$cos_zenith)
  qa <- m(x$anchor_qa) & defined
  search <- if (is.null(x$search_area)) NULL else lapply(x$search_area, m)
  ext <- terra::ext(grid)
  a <- preset$anchors
  anchors <- ef_select_anchors(
    lst, ndvi, albedo, lai = lai, qa = qa, elevation = elevation,
    utc_hour = m(x$utc_hour), search_area = search, criteria = a$criteria,
    relax = a$relax, aggregate = a$aggregate,
    cell_size = terra::res(grid)[1L],
    origin = c(terra::xmin(ext), terra::ymax(ext)),
    crs = terra::crs(grid, proj = TRUE)
  )
  cp <- anchors$calibration_points
  t_cold <- cp$lst[cp$type == "cold"]
  z_cold <- cp$elevation[cp$type == "cold"]

  # Shortwave: tau_sw from elevation (Eq. 11), Rs_in on the horizontal ---------
  r <- preset$radiation
  tau <- if (identical(r$tau_elevation, "pixel (elevation model)")) {
    ef_tau_sw(elevation = elevation, method = r$tau_method)
  } else {
    ef_tau_sw(elevation = scene$tau_elevation, method = r$tau_method)
  }
  rs <- ef_rs_in(cos_zenith = geo$cos_zenith,
                 cos_incidence = geo$cos_incidence,
                 inv_distance = geo$inv_distance, tau_beam = tau$total,
                 tau_diffuse = 0, slope = r$slope, method = r$rs_method)

  # Longwave: cold-anchor temperature, adjusted by elevation (Eq. 12-8) ------
  atm <- ef_atm_emissivity(tau$total)
  t_rl <- if (r$rl_in_lapse_rate == 0) {
    t_cold
  } else {
    t_cold + r$rl_in_lapse_rate * (z_cold - elevation)
  }
  rl_in <- ef_rl_in(temperature = t_rl, atm_emissivity = atm)
  rl_out <- ef_rl_out(lst, emissivity)
  rn <- ef_net_radiation(rs_in = rs$total, albedo = albedo, rl_in = rl_in,
                         rl_out = rl_out, emissivity = emissivity)
  g <- ef_g(rn, lst = lst, albedo = albedo, ndvi = ndvi,
            method = preset$soil_heat$method)

  # Boundary conditions and calibration of H -----------------------------------
  lambda <- ef_lambda(method = preset$lambda$method)
  anchors <- ef_anchor_conditions(
    anchors, rn = rn, g = g$g, etr_inst = etr_inst, lambda = lambda,
    etrf_cold = a$etrf_cold, etrf_hot = a$etrf_hot,
    reference = preset$et$reference, source = a$conditions_source,
    status = a$conditions_status, etr_source = scene$etr_source,
    zom = zom, u_blend = u_blend, pressure = pressure
  )
  sh <- preset$sensible_heat
  datum <- if (is.null(scene$datum_elevation)) z_cold else
    scene$datum_elevation
  cal <- ef_calibrate_h(
    anchors, control = sh$control, lapse_rate = sh$lapse_rate,
    datum_elevation = datum,
    pixels = list(lst = lst, elevation = elevation, zom = zom,
                  u_blend = u_blend, pressure = pressure, rn = rn, g = g$g)
  )

  # Latent heat and evapotranspiration -----------------------------------------
  le <- ef_latent_heat(rn, g$g, cal$pixels$h)
  et_inst <- ef_et_inst(le, lambda)
  etrf <- ef_etrf(et_inst, etr_inst, reference = preset$et$reference)
  eta <- ef_et_daily(etrf, etr_24, reference = preset$et$reference,
                     method = preset$et$method)

  # Flags of the core on terra cells, per layer ---------------------------------
  zu_flags <- ef_flags_combine(zf$flags)
  recs <- list(
    rs_in = c(workflow_cell_records(tau$flags, "rs_in", nr, nc),
              workflow_cell_records(rs$flags, "rs_in", nr, nc)),
    g = workflow_cell_records(g$flags, "g", nr, nc),
    zom = workflow_cell_records(c(zom_obj$flags, zu_flags$flags), "zom",
                                nr, nc),
    h = workflow_cell_records(cal$flags, "h", nr, nc),
    eta_24 = workflow_cell_records(eta$flags, "eta_24", nr, nc)
  )
  evaluated <- unique(c(tau$provenance$flags_evaluated,
                        rs$provenance$flags_evaluated,
                        g$provenance$flags_evaluated,
                        zom_obj$provenance$flags_evaluated,
                        zu_flags$evaluated,
                        cal$provenance$flags_evaluated,
                        eta$provenance$flags_evaluated))

  layers <- list(
    eta_24 = eta$eta_24, etrf = etrf, et_inst = et_inst, le = le,
    h = cal$pixels$h, g = g$g, rn = rn, rah = cal$pixels$rah,
    dt = cal$pixels$dt, rs_in = rs$total, rl_in = rl_in, rl_out = rl_out,
    tau_sw = tau$total, zom = zom, u_blend = u_blend,
    u_star = cal$pixels$u_star, ts_datum = cal$pixels$ts_datum,
    air_density = cal$pixels$air_density, pressure = pressure,
    etr_inst = etr_inst, etr_24 = etr_24
  )
  list(
    layers = layers,
    objects = list(solar_geometry = geo, tau_sw = tau, rs_in = rs, g = g,
                   zom = zom_obj, anchors = anchors, h_calibration = cal,
                   eta_24 = eta, lambda = lambda),
    records = recs,
    evaluated = evaluated,
    t_rl = c(t_cold = t_cold, z_cold = z_cold),
    datum_elevation = datum,
    zom_floor_applied = sum(zf$floored)
  )
}
