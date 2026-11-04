# Forcing: reference evapotranspiration (ETo grass, ETr alfalfa) ----------------
#
# Purpose: net radiation and soil heat flux of the hypothetical reference
#   surface and the combination equation of the reference evapotranspiration,
#   for the grass reference of FAO-56 (ETo) and the tall (alfalfa) reference
#   of the ASCE-EWRI standardized equation (ETr) that METRIC uses.
#
# Specification: dev/specs/weather-forcing.md sections 4.8-4.9 (reference
#   surface), 5 (combination equation, constants table 5.3, interface 5.4,
#   ETr_inst 5.5, ETr_24 5.6), 8 (FAO-56 examples 18-19 and the arithmetic
#   cases A1-A4) and 11 (open decisions). Names: dev/NAMING.md.
#
# Implemented:
#   - ef_reference_constants() (internal): the single table of constants
#     Cn, Cd and G/Rn per reference, standard, time step and day/night, with
#     the source and verification status of each row (spec 5.3).
#   - ef_ref_net_radiation() (exported): Rns, Rnl and Rn of the reference
#     surface, daily and hourly, for the explicit `standard` (FAO-56
#     Eqs. 38-40 and the hourly adaptation; ASCE-EWRI 2005 Eqs. 15-18 and
#     42-45; VERIFICADA). Returns an `earthflux_reference_net_radiation`
#     object with the flags EF_INPUT_NA and EF_WS_RS_RSO_LIMITED.
#   - ef_ref_soil_heat_flux() (exported): G of the reference surface from
#     the constants table (numeric).
#   - ef_ref_et() (exported): the only public reference ET function, with
#     explicit `reference`, `timestep`, `standard` and (hourly ASCE)
#     `daytime`; returns an `earthflux_reference_et` object with the flags
#     EF_INPUT_NA and EF_WS_ETR_NEGATIVE.
#   - ef_diagnose_reference_et() and ef_flags_reference_et() (internal):
#     record-scope flags of this stage and their registry rows.
#   - ef_ref_et_inst_interp() and ef_ref_et_daily_sum() (internal): option
#     O3 of spec 5.5 (linear interpolation of the hourly rate between period
#     midpoints) and option D1 of spec 5.6 (sum of complete days), used by
#     the station orchestration ef_station_ref_et() (R/prep-weather.R), where
#     the open decisions WF-09, WF-11 and WF-16 are explicit arguments.
#   - ef_flags_reference_et() also registers the codes raised by that
#     orchestration (EF_WS_INCOMPLETE_DAY, EF_WS_OVERPASS_OUTSIDE_RECORDS).
#
# Verification status (spec 5.3): FAO-56 grass reference rows are
#   VERIFICADA (FAO-56 Eqs. 6, 42, 45, 46, 53). The ASCE-EWRI (2005)
#   standardized rows (short and tall reference, daily and hourly, day and
#   night Cd, G/Rn ratios) are VERIFICADA against the Task Committee final
#   report of January 2005 (Eq. 1, p. 4; Table 1, p. 5; Eq. 30, p. 25;
#   Eqs. 65-66, p. 44); they were first implemented as CANDIDATA from
#   secondary implementations (`SPEI` 1.8.1, `water` 1.0) and the values
#   did not change (spec sections 5.3 and 13).
#
# Conventions: air temperature in degrees Celsius (P0-4, WF-02); radiation
#   and soil heat flux in MJ m-2 per period (d-1 or h-1) as in FAO-56;
#   normative literals of each standard (0.23; sigma 4.903e-9 of FAO-56 or
#   4.901e-9 and 2.042e-10 of ASCE-EWRI; 273.16 in Rnl, 273 in the
#   aerodynamic term, 0.408) kept inside these functions (decision WF-14). Vectorised; NA propagated; classed errors; nothing truncated
#   (negative reference ET is kept and flagged, principle 6).

# Constants table --------------------------------------------------------------

#' Constants of the reference evapotranspiration equations
#'
#' The single table of the constants of the combination equation (spec
#' 5.2-5.3) and of the soil heat flux of the reference surface (spec 4.9):
#' numerator constant `cn` \[K mm s3 Mg-1 per period\], denominator
#' constant `cd` \[s m-1\] and ratio `g_rn` = G / Rn \[-\], for each
#' reference crop, standard, time step and part of the day.
#'
#' @return A data frame with one row per combination and the columns
#'   `reference` (`"grass"`, `"alfalfa"`), `standard` (`"fao56"`,
#'   `"asce"`), `timestep` (`"daily"`, `"hourly"`), `period` (`"all"`,
#'   `"day"`, `"night"`), `cn`, `cd`, `g_rn`, `status` (`"VERIFICADA"` for
#'   every row: FAO-56 and ASCE-EWRI 2005) and `source` (equation, table and
#'   page of the primary source).
#' @noRd
ef_reference_constants <- function() {
  data.frame(
    reference = c("grass", "grass", "grass",
                  "grass", "alfalfa",
                  "grass", "grass", "alfalfa", "alfalfa"),
    standard = c("fao56", "fao56", "fao56",
                 "asce", "asce",
                 "asce", "asce", "asce", "asce"),
    timestep = c("daily", "hourly", "hourly",
                 "daily", "daily",
                 "hourly", "hourly", "hourly", "hourly"),
    period = c("all", "day", "night",
               "all", "all",
               "day", "night", "day", "night"),
    cn = c(900, 37, 37,
           900, 1600,
           37, 37, 66, 66),
    cd = c(0.34, 0.34, 0.34,
           0.34, 0.38,
           0.24, 0.96, 0.25, 1.7),
    g_rn = c(0, 0.1, 0.5,
             0, 0,
             0.1, 0.5, 0.04, 0.2),
    status = rep("VERIFICADA", 9L),
    source = c(
      "FAO-56 (Allen et al., 1998), chapter 4, Eq. 6; G: chapter 4, Eq. 42",
      "FAO-56 (Allen et al., 1998), chapter 4, Eq. 53; G: chapter 4, Eq. 45",
      "FAO-56 (Allen et al., 1998), chapter 4, Eq. 53; G: chapter 4, Eq. 46",
      paste("ASCE-EWRI (2005), Eq. 1 (p. 4) and Table 1 (p. 5), daily,",
            "short reference (ETos); G: Eq. 30 (p. 25)"),
      paste("ASCE-EWRI (2005), Eq. 1 (p. 4) and Table 1 (p. 5), daily,",
            "tall reference (ETrs); G: Eq. 30 (p. 25)"),
      paste("ASCE-EWRI (2005), Table 1 (p. 5), hourly during daytime,",
            "short reference (ETos); G: Eq. 65a (p. 44)"),
      paste("ASCE-EWRI (2005), Table 1 (p. 5), hourly during nighttime,",
            "short reference (ETos); G: Eq. 65b (p. 44)"),
      paste("ASCE-EWRI (2005), Table 1 (p. 5), hourly during daytime,",
            "tall reference (ETrs); G: Eq. 66a (p. 44)"),
      paste("ASCE-EWRI (2005), Table 1 (p. 5), hourly during nighttime,",
            "tall reference (ETrs); G: Eq. 66b (p. 44)")
    ),
    stringsAsFactors = FALSE
  )
}

#' Check the reference, time step and standard of a reference ET call
#'
#' The three choices are explicit (no defaults). FAO-56 defines only the
#' grass reference: `standard = "fao56"` with `reference = "alfalfa"` raises
#' `earthflux_undefined_reference` (spec 5.4).
#'
#' @param reference,timestep,standard The caller's arguments (`NULL` when
#'   missing).
#' @param call The call to report.
#' @return The rows of `ef_reference_constants()` of the combination.
#' @noRd
check_reference_setup <- function(reference, timestep, standard,
                                  call = sys.call(-1)) {
  check_method(reference, c("alfalfa", "grass"), arg = "reference",
               call = call)
  check_method(timestep, c("hourly", "daily"), arg = "timestep",
               call = call)
  check_method(standard, c("asce", "fao56"), arg = "standard",
               call = call)
  if (standard == "fao56" && reference == "alfalfa") {
    ef_abort(
      paste0(
        "FAO-56 defines only the grass reference: `standard = \"fao56\"` ",
        "cannot be used with `reference = \"alfalfa\"`; use ",
        "`standard = \"asce\"` (ASCE-EWRI 2005) for the tall reference."
      ),
      class = c("earthflux_undefined_reference", "earthflux_input_error"),
      reference = reference,
      standard = standard,
      call = call
    )
  }
  k <- ef_reference_constants()
  k <- k[k$reference == reference & k$standard == standard &
           k$timestep == timestep, , drop = FALSE]
  rownames(k) <- NULL
  k
}

#' Check the `daytime` argument of the hourly reference functions
#'
#' @param daytime Logical vector or `NULL`.
#' @param needed Logical. Whether the combination uses `daytime`.
#' @param timestep Character time step.
#' @param args Named list of the numeric arguments of the call (for the
#'   length and dim checks).
#' @param call The call to report.
#' @return The common length `n` of `args` plus `daytime`, invisibly.
#' @noRd
check_daytime <- function(daytime, needed, timestep, args,
                          call = sys.call(-1)) {
  if (timestep == "daily" && !is.null(daytime)) {
    ef_abort(
      "`daytime` must be NULL for `timestep = \"daily\"` (no day/night split).",
      class = "earthflux_input_error",
      call = call
    )
  }
  if (needed && is.null(daytime)) {
    ef_abort(
      paste0(
        "`daytime` (logical, TRUE for daytime periods) is required for ",
        "this hourly combination; the day/night criterion is the caller's ",
        "choice (decision WF-15)."
      ),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }
  if (!is.null(daytime) && !is.logical(daytime)) {
    ef_abort(
      sprintf("`daytime` must be logical, not %s.", class(daytime)[1L]),
      class = "earthflux_input_error",
      call = call
    )
  }
  all_args <- c(args, list(daytime = daytime))
  all_args <- all_args[!vapply(all_args, is.null, logical(1))]
  n <- check_common_length(all_args, call = call)
  check_same_dim(all_args, n, call = call)
  invisible(n)
}

# Net radiation of the reference surface ------------------------------------------

#' Net radiation of the reference surface
#'
#' @description
#' Computes the net radiation \eqn{R_n}{Rn} of the hypothetical reference
#' surface (albedo 0.23) and its components, the net shortwave radiation
#' \eqn{R_{ns}}{Rns} and the net outgoing longwave radiation
#' \eqn{R_{nl}}{Rnl}, for a daily or an hourly time step and the explicit
#' standard (FAO-56 or the ASCE-EWRI standardized procedure). It is the net
#' radiation entering [ef_ref_et()] and [ef_ref_soil_heat_flux()]; it is
#' **not** the net radiation of a pixel ([ef_net_radiation()]).
#'
#' @param solar_radiation Numeric. Measured (or estimated) solar radiation
#'   \eqn{R_s}{Rs} of the period \[MJ m-2 d-1 or MJ m-2 h-1\]. Must be
#'   finite and `>= 0`.
#' @param clear_sky_radiation Numeric or `NULL`. Clear-sky radiation
#'   \eqn{R_{so}}{Rso} of the same period and unit, from [ef_rso()]. Must
#'   be finite and `> 0` where the cloudiness term is computed from
#'   \eqn{R_s/R_{so}}{Rs/Rso}. May be `NULL` only when `cloudiness` is
#'   supplied.
#' @param vapour_pressure Numeric. Actual vapour pressure \eqn{e_a}{ea}
#'   \[kPa\] of the period (from [ef_ea_daily()] or [ef_ea_rh()]). Must be
#'   finite and `>= 0`.
#' @param air_temperature Numeric or `NULL`. Mean hourly air temperature
#'   \[degrees Celsius\], required for `timestep = "hourly"` (and `NULL`
#'   for `"daily"`). Must be finite and `> -273.16`.
#' @param tmax,tmin Numeric or `NULL`. Daily maximum and minimum air
#'   temperatures \[degrees Celsius\], required for `timestep = "daily"`
#'   (and `NULL` for `"hourly"`). Finite, `> -273.16` and `tmin <= tmax`.
#' @param timestep Character, no default. `"daily"` (FAO-56 Eq. 39;
#'   ASCE-EWRI Eq. 17) or `"hourly"` (FAO-56 chapter 4, "Hourly time
#'   step"; ASCE-EWRI Eq. 44).
#' @param standard Character, no default. `"fao56"` or `"asce"`
#'   (ASCE-EWRI 2005 standardized procedure). It selects the
#'   Stefan-Boltzmann constant and the limits of the relative solar
#'   radiation (see Details).
#' @param cloudiness Numeric or `NULL`. The cloudiness term
#'   \eqn{f = 1.35 R_s/R_{so} - 0.35}{f = 1.35 * Rs / Rso - 0.35} \[-\] to
#'   use instead of computing it from `solar_radiation` and
#'   `clear_sky_radiation`, in \[-0.35, 1\] for `"fao56"` and in
#'   \[0.05, 1\] for `"asce"` (the ranges of each standard). It serves night-time (and, for ASCE-EWRI, low sun angle)
#'   periods, where the ratio is undefined or unreliable and is carried from
#'   an earlier period (see Details). When supplied it is used at every
#'   position. Default `NULL`: computed from the radiation.
#'
#' @return An object of class `earthflux_reference_net_radiation`: a list
#'   with
#'   * `rn`: net radiation of the reference surface \eqn{R_n}{Rn};
#'   * `rns`: net shortwave radiation \eqn{R_{ns}}{Rns};
#'   * `rnl`: net outgoing longwave radiation \eqn{R_{nl}}{Rnl};
#'   * `cloudiness`: the cloudiness term \eqn{f}{f} used \[-\];
#'
#'   all numeric \[MJ m-2 d-1 or MJ m-2 h-1, the unit of
#'   `solar_radiation`\] with the common length (and `dim`) of the inputs;
#'   * `timestep`, `standard`;
#'   * `flags`: list of `earthflux_flag` records (record scope) for the
#'     codes that hold somewhere: `EF_INPUT_NA` (a required input is
#'     missing) and `EF_WS_RS_RSO_LIMITED` (\eqn{R_s/R_{so}}{Rs / Rso}
#'     outside the range of the standard, limited inside the cloudiness
#'     term);
#'   * `provenance`: time step, standard, verification status, constants,
#'     source of the cloudiness term, references, `flags_evaluated` and
#'     package version.
#'
#' @details
#' \deqn{R_{ns} = (1 - \alpha) R_s, \quad \alpha = 0.23}{Rns = (1 - 0.23) *
#'   Rs}
#' (FAO-56, chapter 3, Eq. 38; ASCE-EWRI, 2005, Eqs. 16 and 43: albedo
#' fixed at 0.23 for the short and the tall reference, daily and hourly),
#' \deqn{R_{nl} = \sigma \frac{T_{max,K}^4 + T_{min,K}^4}{2} (0.34 - 0.14
#'   \sqrt{e_a}) \left(1.35 \frac{R_s}{R_{so}} - 0.35\right)}{Rnl = sigma *
#'   (TmaxK^4 + TminK^4) / 2 * (0.34 - 0.14 * sqrt(ea)) * (1.35 * Rs / Rso -
#'   0.35)}
#' with \eqn{T_K = T + 273.16}{TK = T + 273.16} (FAO-56, chapter 3, Eq. 39;
#' ASCE-EWRI Eqs. 17-18), and \eqn{R_n = R_{ns} - R_{nl}}{Rn = Rns - Rnl}
#' (FAO-56 Eq. 40; ASCE-EWRI Eqs. 15 and 42). For the hourly time step
#' (FAO-56, chapter 4, "Hourly time step"; ASCE-EWRI Eqs. 44-45) the mean of
#' the fourth powers is replaced by \eqn{T_{hr,K}^4}{ThrK^4}.
#'
#' **Constants and limits of each standard** (decision WF-14: the literals
#' of each standard are used as written):
#'
#' | | `"fao56"` | `"asce"` |
#' |---|---|---|
#' | \eqn{\sigma}{sigma}, daily \[MJ K-4 m-2 d-1\] | 4.903e-9 (Eq. 39) | 4.901e-9 (Eq. 17, p. 19) |
#' | \eqn{\sigma}{sigma}, hourly \[MJ K-4 m-2 h-1\] | 4.903e-9 / 24 | 2.042e-10 (Eq. 44, p. 34) |
#' | \eqn{R_s/R_{so}}{Rs/Rso} in the cloudiness term | \eqn{\le 1}{<= 1} (Eq. 39) | in \[0.3, 1\] (Eqs. 18 and 45, pp. 20 and 35) |
#' | cloudiness term \eqn{f}{f} | \[-0.35, 1\] | \[0.05, 1\] (Eqs. 17 and 44) |
#'
#' The limits act only inside the cloudiness term; `solar_radiation` and
#' `rns` are not modified, and the positions where a limit acts are flagged
#' `EF_WS_RS_RSO_LIMITED`. The report is not consistent here: it states
#' that the ratio limits \eqn{0.3 \le R_s/R_{so} \le 1}{0.3 <= Rs/Rso <= 1}
#' give \eqn{0.05 \le f \le 1}{0.05 <= f <= 1} (pp. 20 and 35), but
#' \eqn{1.35 \times 0.3 - 0.35 = 0.055}{1.35 * 0.3 - 0.35 = 0.055}. The ratio
#' limit is applied (so a computed term is at least 0.055), and a supplied
#' `cloudiness` is accepted in the stated range \[0.05, 1\]. The two Stefan-Boltzmann values differ by 0.04 %
#' (daily); the ASCE-EWRI hourly value is the published one (4.901e-9 / 24
#' = 2.04208e-10).
#'
#' **Night-time and low sun angle.** With \eqn{R_{so} = 0}{Rso = 0} the
#' ratio is undefined. FAO-56 sets it to the value of a period 2-3 hours
#' before sunset, identified by \eqn{\omega_s - 0.79 \le \omega \le \omega_s
#' - 0.52}{ws - 0.79 <= w <= ws - 0.52}, or, approximately, to 0.4-0.6 in
#' humid and sub-humid and 0.7-0.8 in arid and semi-arid climates (0.3 means
#' complete cloud cover). ASCE-EWRI (2005, Eq. 46, pp. 35-36) uses, for
#' every period whose sun angle at the midpoint is below 0.3 rad (night,
#' dusk and dawn), the cloudiness term of the last period before the sun
#' angle fell below 0.3 rad. Selecting that value is the task of the station
#' orchestration ([ef_station_ref_et()], argument `night_cloudiness`); here
#' the resulting term is passed as `cloudiness` (for a ratio \eqn{r}{r},
#' `cloudiness = 1.35 * r - 0.35`).
#'
#' **Normative constants.** \eqn{\sigma}{sigma} of each standard (FAO-56
#' 4.903e-9 MJ m-2 d-1 K-4, about 5.6748e-8 W m-2 K-4, 0.08 % below the
#' CODATA value used elsewhere in the package) and 273.16 in the conversion
#' to kelvin, as written in both standards; the package constants
#' (`EF_STEFAN_BOLTZMANN`, 273.15) are not used inside the reference surface
#' equations. \eqn{R_{nl}}{Rnl} is an empirical longwave balance of the
#' reference surface and is not interchangeable with the incoming and
#' emitted longwave radiation of a pixel.
#'
#' Missing values propagate (and are flagged `EF_INPUT_NA`). Missing,
#' unknown or inconsistent `timestep`, `standard` and temperature arguments
#' raise `earthflux_missing_input`, `earthflux_unknown_method` or
#' `earthflux_input_error`; values outside the domains above (including
#' \eqn{R_{so} = 0}{Rso = 0} without `cloudiness`, and `tmin > tmax`) raise
#' `earthflux_domain_error`.
#'
#' @section Verification status:
#' `standard = "fao56"`: `VERIFICADA` (FAO-56, chapter 3, Eqs. 38-40;
#' chapter 4, hourly time step; cases V10, V11, V14, V15 and V16 of
#' dev/specs/weather-forcing.md 8.1). `standard = "asce"`: `VERIFICADA`
#' (ASCE-EWRI, 2005, Eqs. 15-18, pp. 17-20, and Eqs. 42-45, pp. 32-35).
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
#' Equation*. Task Committee on Standardization of Reference
#' Evapotranspiration, Environmental and Water Resources Institute of the
#' American Society of Civil Engineers. Final report, January 2005.
#' Published as Allen, R. G., Walter, I. A., Elliott, R. L., Howell, T. A.,
#' Itenfisu, D., Jensen, M. E., & Snyder, R. L. (Eds.), American Society of
#' Civil Engineers, Reston, VA. \doi{10.1061/9780784408056}
#'
#' @family reference evapotranspiration functions
#' @export
#'
#' @examples
#' # FAO-56 example 18 (Uccle, 6 July): daily step
#' rn <- ef_ref_net_radiation(
#'   solar_radiation = 22.07, clear_sky_radiation = 30.90,
#'   vapour_pressure = 1.409, tmax = 21.5, tmin = 12.3, timestep = "daily",
#'   standard = "fao56"
#' )
#' rn$rn
#'
#' # Same inputs with the ASCE-EWRI constants (sigma = 4.901e-9)
#' ef_ref_net_radiation(
#'   solar_radiation = 22.07, clear_sky_radiation = 30.90,
#'   vapour_pressure = 1.409, tmax = 21.5, tmin = 12.3, timestep = "daily",
#'   standard = "asce"
#' )$rn
#'
#' # FAO-56 example 19, 02:00-03:00: night, Rs/Rso = 0.8 carried
#' ef_ref_net_radiation(
#'   solar_radiation = 0, clear_sky_radiation = NULL,
#'   vapour_pressure = 3.402, air_temperature = 28, timestep = "hourly",
#'   standard = "fao56", cloudiness = 1.35 * 0.8 - 0.35
#' )$rn
ef_ref_net_radiation <- function(solar_radiation, clear_sky_radiation,
                                 vapour_pressure, air_temperature = NULL,
                                 tmax = NULL, tmin = NULL, timestep, standard,
                                 cloudiness = NULL) {
  call <- sys.call()
  check_method(if (missing(timestep)) NULL else timestep,
               c("hourly", "daily"), arg = "timestep", call = call)
  check_method(if (missing(standard)) NULL else standard, c("asce", "fao56"),
               arg = "standard", call = call)
  if (missing(clear_sky_radiation)) {
    clear_sky_radiation <- NULL
  }
  if (missing(solar_radiation) || missing(vapour_pressure)) {
    ef_abort("`solar_radiation` and `vapour_pressure` must be supplied.",
             class = c("earthflux_missing_input", "earthflux_input_error"),
             call = call)
  }

  if (timestep == "daily") {
    if (is.null(tmax) || is.null(tmin) || !is.null(air_temperature)) {
      ef_abort(
        paste0(
          "`timestep = \"daily\"` requires `tmax` and `tmin` and no ",
          "`air_temperature`."
        ),
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
    temps <- list(tmax = tmax, tmin = tmin)
  } else {
    if (is.null(air_temperature) || !is.null(tmax) || !is.null(tmin)) {
      ef_abort(
        paste0(
          "`timestep = \"hourly\"` requires `air_temperature` and no ",
          "`tmax` or `tmin`."
        ),
        class = c("earthflux_missing_input", "earthflux_input_error"),
        call = call
      )
    }
    temps <- list(air_temperature = air_temperature)
  }
  if (is.null(clear_sky_radiation) && is.null(cloudiness)) {
    ef_abort(
      paste0(
        "`clear_sky_radiation` is required unless the cloudiness term is ",
        "supplied in `cloudiness`."
      ),
      class = c("earthflux_missing_input", "earthflux_input_error"),
      call = call
    )
  }

  args <- c(
    list(solar_radiation = solar_radiation,
         clear_sky_radiation = clear_sky_radiation,
         vapour_pressure = vapour_pressure),
    temps,
    list(cloudiness = cloudiness)
  )
  args <- args[!vapply(args, is.null, logical(1))]
  n <- check_core_args(args, call)
  d <- common_dim(args)

  check_in_range(solar_radiation, "solar_radiation", lower = 0, call = call)
  check_in_range(vapour_pressure, "vapour_pressure", lower = 0, call = call)
  for (nm in names(temps)) {
    # T + 273.16 > 0 (conversion to kelvin of FAO-56 Eq. 39 and ASCE-EWRI
    # Eqs. 17 and 44).
    check_in_range(temps[[nm]], nm, lower = -273.16, lower_inclusive = FALSE,
                   call = call)
  }
  if (timestep == "daily") {
    check_condition(tmin <= tmax, "`tmin` must not exceed `tmax`", call)
  }

  # Limits of the relative solar radiation Rs/Rso inside the cloudiness
  # term: FAO-56 Eq. 39 (<= 1); ASCE-EWRI (2005) Eqs. 18 and 45 ([0.3, 1]).
  ratio_min <- if (standard == "asce") 0.3 else 0
  limited <- NULL
  if (is.null(cloudiness)) {
    check_in_range(clear_sky_radiation, "clear_sky_radiation", lower = 0,
                   lower_inclusive = FALSE, call = call)
    ratio <- solar_radiation / clear_sky_radiation
    limited <- !is.na(ratio) & (ratio > 1 | ratio < ratio_min)
    f <- 1.35 * pmin(pmax(ratio, ratio_min), 1) - 0.35
    cloud_source <- "computed from solar_radiation / clear_sky_radiation"
    cloud_inputs <- list(solar_radiation = solar_radiation,
                         clear_sky_radiation = clear_sky_radiation)
  } else {
    if (!is.null(clear_sky_radiation)) {
      check_in_range(clear_sky_radiation, "clear_sky_radiation", lower = 0,
                     call = call)
    }
    # Range of the cloudiness term: FAO-56 [-0.35, 1] (Rs/Rso in [0, 1]);
    # ASCE-EWRI (2005), Eqs. 17 and 44: 0.05 <= fcd <= 1.
    check_in_range(cloudiness, "cloudiness",
                   lower = if (standard == "asce") 0.05 else -0.35,
                   upper = 1, call = call)
    f <- cloudiness
    cloud_source <- "supplied in `cloudiness`"
    cloud_inputs <- list(cloudiness = cloudiness)
  }

  # FAO-56, chapter 3, Eq. 38; ASCE-EWRI (2005), Eqs. 16 and 43 (albedo of
  # the reference surface, WF-14).
  rns <- (1 - 0.23) * solar_radiation
  # FAO-56, chapter 3, Eq. 39 (hourly: chapter 4, sigma / 24, T_hr^4);
  # ASCE-EWRI (2005), Eq. 17 (daily) and Eq. 44 (hourly). Literals of each
  # standard, with 273.16 (WF-14).
  sigma <- switch(
    paste(standard, timestep),
    "fao56 daily" = 4.903e-9,
    "fao56 hourly" = 4.903e-9 / 24,
    "asce daily" = 4.901e-9,
    "asce hourly" = 2.042e-10
  )
  if (timestep == "daily") {
    sigma_t4 <- sigma * ((tmax + 273.16)^4 + (tmin + 273.16)^4) / 2
  } else {
    sigma_t4 <- sigma * (air_temperature + 273.16)^4
  }
  rnl <- sigma_t4 * (0.34 - 0.14 * sqrt(vapour_pressure)) * f
  # FAO-56, chapter 3, Eq. 40; ASCE-EWRI (2005), Eqs. 15 and 42.
  rn <- rns - rnl

  rn <- ef_reshape(rn, n, d)
  na_inputs <- c(list(solar_radiation = solar_radiation,
                      vapour_pressure = vapour_pressure),
                 temps, cloud_inputs)
  na_mask <- Reduce(`|`, lapply(na_inputs, function(x) rep_len(is.na(x), n)))
  masks <- list(EF_INPUT_NA = as.vector(na_mask))
  if (!is.null(limited)) {
    masks$EF_WS_RS_RSO_LIMITED <- rep_len(as.vector(limited), n)
  }
  flags <- ef_flags_combine(ef_flag_set(masks, scope = "record"))

  new_ef_object(
    list(
      rn = rn,
      rns = ef_reshape(rns, n, d),
      rnl = ef_reshape(rnl, n, d),
      cloudiness = ef_reshape(f, n, d),
      timestep = timestep,
      standard = standard,
      flags = flags$flags,
      provenance = list(
        timestep = timestep,
        standard = standard,
        fun = "ef_ref_net_radiation",
        status = "VERIFICADA",
        references = if (standard == "fao56") {
          c(
            "FAO-56 (Allen et al., 1998), chapter 3, Eqs. 38-40",
            "FAO-56 (Allen et al., 1998), chapter 4, hourly time step"
          )
        } else {
          paste("ASCE-EWRI (2005), Eqs. 15-18 (daily, pp. 17-20) and",
                "Eqs. 42-45 (hourly, pp. 32-35)")
        },
        constants = list(albedo = 0.23, sigma = sigma,
                         kelvin_offset = 273.16,
                         ratio_limits = c(ratio_min, 1)),
        cloudiness = cloud_source,
        flags_evaluated = flags$evaluated,
        earthflux_version = as.character(getNamespaceVersion("EarthFlux"))
      )
    ),
    "earthflux_reference_net_radiation"
  )
}

# Soil heat flux of the reference surface ------------------------------------------

#' Soil heat flux of the reference surface
#'
#' @description
#' Computes the soil heat flux \eqn{G}{G} of the hypothetical reference
#' surface from its net radiation, with the ratios of the reference
#' evapotranspiration standards: zero for daily periods, and a fixed
#' fraction of the net radiation, different by day and by night, for
#' hourly periods. It is the soil heat flux entering [ef_ref_et()]; it is
#' **not** a method for the soil heat flux of a pixel ([ef_g()]).
#'
#' @param net_radiation Numeric. Net radiation of the reference surface
#'   \eqn{R_n}{Rn} \[MJ m-2 d-1 or MJ m-2 h-1\], for example
#'   `ef_ref_net_radiation()$rn`. Any finite value.
#' @param reference Character, no default. Reference crop: `"grass"` (short
#'   reference, 0.12 m) or `"alfalfa"` (tall reference, about 0.5 m).
#' @param timestep Character, no default. `"daily"` or `"hourly"`.
#' @param standard Character, no default. `"fao56"` (FAO-56, grass only) or
#'   `"asce"` (ASCE-EWRI 2005 standardized equation).
#' @param daytime Logical or `NULL`. For `timestep = "hourly"`, `TRUE` for
#'   daytime and `FALSE` for night-time periods (required); must be `NULL`
#'   for `"daily"`. `NA` gives `NA`. The criterion is the caller's choice
#'   (decision WF-15): FAO-56 speaks of "daylight periods" without a
#'   threshold; ASCE-EWRI (2005) defines daytime as a positive hourly net
#'   radiation, `daytime = net_radiation > 0` (see Details).
#'
#' @return A numeric vector of soil heat flux of the reference surface
#'   \eqn{G}{G} in the unit of `net_radiation`, with the common length of
#'   the inputs, keeping their `dim`. For daily periods it is 0 (and `NA`
#'   where `net_radiation` is `NA`).
#'
#' @details
#' \eqn{G = c_G R_n}{G = cG * Rn} with \eqn{c_G}{cG} from the internal
#' constants table of the reference equations
#' (dev/specs/weather-forcing.md 5.3):
#'
#' | Reference, standard | Daily | Hourly, day | Hourly, night | Status |
#' |---|---|---|---|---|
#' | grass, `"fao56"` | 0 (Eq. 42) | 0.1 (Eq. 45) | 0.5 (Eq. 46) | `VERIFICADA` |
#' | grass, `"asce"` | 0 (Eq. 30) | 0.1 (Eq. 65a) | 0.5 (Eq. 65b) | `VERIFICADA` |
#' | alfalfa, `"asce"` | 0 (Eq. 30) | 0.04 (Eq. 66a) | 0.2 (Eq. 66b) | `VERIFICADA` |
#'
#' FAO-56 (Eq. 42) and ASCE-EWRI (2005, Eq. 30, p. 25) state that the daily
#' soil heat flux beneath the reference surface is small and is ignored
#' (G = 0). The monthly forms (FAO-56 Eqs. 43-44; ASCE-EWRI Eqs. 31-32) are
#' out of scope.
#'
#' **Day and night in ASCE-EWRI (2005).** The report defines daytime as a
#' positive mean net radiation of the hourly period (text before Table 1,
#' p. 5; Table 2, p. 5: daytime \eqn{R_n > 0}{Rn > 0}, night-time
#' \eqn{R_n \le 0}{Rn <= 0}), which `daytime = net_radiation > 0` follows
#' (option `"rn_positive"` of [ef_station_ref_et()]). The report is not
#' consistent at \eqn{R_n = 0}{Rn = 0}: p. 44 (after Eqs. 65-66) and the
#' glossary (p. 58) define night-time as \eqn{R_n < 0}{Rn < 0} and daytime
#' as \eqn{R_n \ge 0}{Rn >= 0}. At \eqn{R_n = 0}{Rn = 0} G is 0 under
#' both readings; only \eqn{C_d}{Cd} of [ef_ref_et()] depends on it.
#'
#' `standard = "fao56"` with
#' `reference = "alfalfa"` raises `earthflux_undefined_reference` (also
#' `earthflux_input_error`): FAO-56 does not define the tall reference.
#'
#' Missing values propagate. Missing or unknown choices raise
#' `earthflux_missing_input` or `earthflux_unknown_method`; a missing or
#' non-logical `daytime` where required, or a `daytime` given for a daily
#' step, raise `earthflux_input_error` (or `earthflux_missing_input`);
#' infinite `net_radiation` raises `earthflux_domain_error`.
#'
#' @section Verification status:
#' FAO-56 grass rows: `VERIFICADA` (FAO-56, chapter 4, Eqs. 42, 45, 46;
#' cases V15 and V16). ASCE-EWRI rows: `VERIFICADA` (ASCE-EWRI, 2005,
#' Eq. 30, p. 25; Eqs. 65a-b and 66a-b, p. 44).
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
#' Equation*. Task Committee on Standardization of Reference
#' Evapotranspiration, Environmental and Water Resources Institute of the
#' American Society of Civil Engineers. Final report, January 2005.
#' Published as Allen, R. G., Walter, I. A., Elliott, R. L., Howell, T. A.,
#' Itenfisu, D., Jensen, M. E., & Snyder, R. L. (Eds.), American Society of
#' Civil Engineers, Reston, VA. \doi{10.1061/9780784408056}
#'
#' @family reference evapotranspiration functions
#' @export
#'
#' @examples
#' # FAO-56 example 19: daytime (Rn = 1.749) and night (Rn = -0.100) hours
#' ef_ref_soil_heat_flux(c(1.749, -0.100), reference = "grass",
#'                       timestep = "hourly", standard = "fao56",
#'                       daytime = c(TRUE, FALSE))
#'
#' # Tall reference, ASCE-EWRI daytime rule (Rn > 0)
#' rn <- c(1.749, -0.100)
#' ef_ref_soil_heat_flux(rn, reference = "alfalfa", timestep = "hourly",
#'                       standard = "asce", daytime = rn > 0)
#'
#' # Daily step: G = 0
#' ef_ref_soil_heat_flux(13.28, reference = "grass", timestep = "daily",
#'                       standard = "fao56")
ef_ref_soil_heat_flux <- function(net_radiation, reference, timestep,
                                  standard, daytime = NULL) {
  call <- sys.call()
  k <- check_reference_setup(
    if (missing(reference)) NULL else reference,
    if (missing(timestep)) NULL else timestep,
    if (missing(standard)) NULL else standard,
    call = call
  )
  args <- list(net_radiation = net_radiation)
  check_core_args(args, call)
  n <- check_daytime(daytime, needed = timestep == "hourly", timestep,
                     args, call = call)
  check_in_range(net_radiation, "net_radiation", call = call)

  if (timestep == "daily") {
    ratio <- k$g_rn[k$period == "all"]
  } else {
    ratio <- ifelse(daytime, k$g_rn[k$period == "day"],
                    k$g_rn[k$period == "night"])
  }
  d <- common_dim(c(args, list(daytime = daytime)))
  ef_reshape(rep_len(ratio, n) * rep_len(net_radiation, n), n, d)
}

# Reference evapotranspiration -----------------------------------------------------

#' Reference evapotranspiration (grass ETo, alfalfa ETr)
#'
#' @description
#' Computes the reference evapotranspiration with the combination
#' (Penman-Monteith) equation of a hypothetical reference surface, for the
#' grass reference of FAO-56 (ETo) or the tall alfalfa reference of the
#' ASCE-EWRI standardized equation (ETr, the reference used by METRIC), with
#' a daily or an hourly time step. All choices are explicit arguments
#' without defaults. The inputs are the reference-surface quantities already
#' computed (net radiation, soil heat flux, slope of the saturation curve,
#' psychrometric constant, vapour pressure deficit, wind at 2 m).
#'
#' @param net_radiation Numeric. Net radiation of the reference surface
#'   \eqn{R_n}{Rn} \[MJ m-2 d-1 or MJ m-2 h-1\], from
#'   [ef_ref_net_radiation()]. Any finite value.
#' @param soil_heat_flux Numeric. Soil heat flux of the reference surface
#'   \eqn{G}{G} in the same unit, from [ef_ref_soil_heat_flux()] (0 for
#'   daily steps). Any finite value.
#' @param air_temperature Numeric. Air temperature \[degrees Celsius\]: the
#'   daily mean \eqn{(T_{max} + T_{min})/2}{(Tmax + Tmin) / 2} for daily
#'   steps, the hourly mean for hourly steps. Finite and `> -273`.
#' @param wind_speed_2m Numeric. Wind speed at 2 m \eqn{u_2}{u2} \[m s-1\],
#'   from [ef_wind_2m()]. Finite and `>= 0`.
#' @param vapour_pressure_deficit Numeric. Vapour pressure deficit
#'   \eqn{e_s - e_a}{es - ea} \[kPa\] ([ef_es()] and the [ef_ea] functions).
#'   Any finite value: a negative deficit (actual above saturation vapour
#'   pressure) is kept.
#' @param slope Numeric. Slope of the saturation vapour pressure curve
#'   \eqn{\Delta}{Delta} \[kPa degC-1\], from [ef_es_slope()]. Finite and
#'   `> 0`.
#' @param psychrometric Numeric. Psychrometric constant \eqn{\gamma}{gamma}
#'   \[kPa degC-1\], from [ef_psychrometric()]. Finite and `> 0`.
#' @param reference Character, no default. `"grass"` (ETo, short reference,
#'   0.12 m) or `"alfalfa"` (ETr, tall reference, about 0.5 m). It is kept in
#'   the result, because a crop coefficient on a grass basis and a METRIC
#'   reference fraction on an alfalfa basis are not interchangeable.
#' @param timestep Character, no default. `"daily"` or `"hourly"`.
#' @param standard Character, no default. `"fao56"` (FAO-56 Eqs. 6 and 53;
#'   grass only) or `"asce"` (ASCE-EWRI 2005 standardized equation, Eq. 1
#'   and Table 1); both `VERIFICADA`.
#' @param daytime Logical or `NULL`. Required for `timestep = "hourly"` with
#'   `standard = "asce"`, where \eqn{C_d}{Cd} differs by day and night:
#'   `TRUE` for daytime periods (`NA` gives `NA`); the day/night criterion is
#'   the caller's choice (decision WF-15); ASCE-EWRI (2005, p. 5) defines
#'   daytime as \eqn{R_n > 0}{Rn > 0} (see [ef_ref_soil_heat_flux()]). Not
#'   used with
#'   `standard = "fao56"` (\eqn{C_d}{Cd} = 0.34 day and night); must be
#'   `NULL` for daily steps.
#'
#' @return An object of class `earthflux_reference_et`: a list with
#'   * `et_ref`: reference evapotranspiration \[mm d-1 for daily steps,
#'     mm h-1 for hourly steps\], numeric with the common length (and
#'     `dim`) of the inputs; negative values are kept;
#'   * `reference`, `timestep`, `standard`: the choices made;
#'   * `flags`: list of `earthflux_flag` records (record scope) for the
#'     codes that hold somewhere: `EF_INPUT_NA` and `EF_WS_ETR_NEGATIVE`
#'     (negative reference ET, kept; the code covers ETo and ETr);
#'   * `provenance`: the rows of the constants table used (`constants`,
#'     with source and status of each), the verification `status`
#'     (`"VERIFICADA"`), references, `flags_evaluated` and package version.
#'
#' @details
#' \deqn{ET_{ref} = \frac{0.408\,\Delta (R_n - G) + \gamma
#'   \frac{C_n}{T + 273} u_2 (e_s - e_a)}{\Delta + \gamma (1 + C_d u_2)}}{
#'   ETref = (0.408 * Delta * (Rn - G) + gamma * Cn / (T + 273) * u2 *
#'   (es - ea)) / (Delta + gamma * (1 + Cd * u2))}
#' This is the standardized reference evapotranspiration equation of
#' ASCE-EWRI (2005, Eq. 1, p. 4), with ETos (short) and ETrs (tall
#' reference). With \eqn{C_n}{Cn} = 900 and \eqn{C_d}{Cd} = 0.34 it is
#' FAO-56 Eq. 6 (daily ETo, mm d-1); with \eqn{C_n}{Cn} = 37 and
#' \eqn{C_d}{Cd} = 0.34, FAO-56 Eq. 53 (hourly ETo, mm h-1). The constants
#' come from one internal table with the source and status of each row
#' (dev/specs/weather-forcing.md 5.3):
#'
#' | Reference, standard, step | \eqn{C_n}{Cn} | \eqn{C_d}{Cd} | Source |
#' |---|---|---|---|
#' | grass, `"fao56"`, daily | 900 | 0.34 | FAO-56 Eq. 6 |
#' | grass, `"fao56"`, hourly | 37 | 0.34 | FAO-56 Eq. 53 |
#' | grass, `"asce"`, daily | 900 | 0.34 | ASCE-EWRI Table 1 |
#' | alfalfa, `"asce"`, daily | 1600 | 0.38 | ASCE-EWRI Table 1 |
#' | grass, `"asce"`, hourly | 37 | 0.24 day / 0.96 night | ASCE-EWRI Table 1 |
#' | alfalfa, `"asce"`, hourly | 66 | 0.25 day / 1.7 night | ASCE-EWRI Table 1 |
#'
#' All rows are `VERIFICADA`. Units (ASCE-EWRI, p. 4): \eqn{C_n}{Cn} in K
#' mm s3 Mg-1 d-1 or h-1 (it absorbs the time conversion, the
#' \eqn{K_{time}}{Ktime} of 86400 s d-1 or 3600 s h-1 of the full
#' Penman-Monteith form), \eqn{C_d}{Cd} in s m-1 and 0.408 in m2 mm MJ-1
#' (1 / 2.45 MJ kg-1 with a water density of 1 Mg m-3, pp. 9 and 27). The
#' report fixes the reference heights (0.12 m short, 0.50 m tall), the
#' surface resistances (daily 70 and 45 s m-1; hourly 50 and 30 s m-1 by
#' day, 200 s m-1 by night) and \eqn{\lambda}{lambda} = 2.45 MJ kg-1
#' behind these constants (Table 2, p. 5).
#'
#' FAO-56 reference surface: hypothetical grass 0.12 m high, fixed surface
#' resistance 70 s m-1 and albedo 0.23, with measurements at 2 m (FAO-56,
#' chapter 2). The factor 0.408 (1 / 2.45 MJ kg-1) and 273 in the
#' aerodynamic term are the literals of the standard (decision WF-14).
#' FAO-56 (chapter 4) warns that the fixed surface resistance may
#' underestimate hourly ETo in daytime and overestimate it in the evening,
#' and that hourly values summed over 24 hours generally match the daily
#' computation.
#'
#' **`standard` matters for the grass reference.** For hourly grass, FAO-56
#' uses \eqn{C_d}{Cd} = 0.34 day and night, while ASCE-EWRI (2005) uses
#' 0.24 / 0.96: with the inputs of FAO-56 example 19 (14:00-15:00) they give
#' 0.627 and 0.656 mm h-1.
#'
#' `standard = "fao56"` with `reference = "alfalfa"` raises
#' `earthflux_undefined_reference` (also `earthflux_input_error`): FAO-56
#' does not define the tall reference. The worked examples of ASCE-EWRI
#' (2005) (its Appendix C, Greeley, Colorado) are not part of the copy of
#' the report that was read, so no published ETrs value is reproduced yet
#' (dev/specs/weather-forcing.md 8.2).
#'
#' The instantaneous reference ET at the satellite overpass (spec 5.5) and
#' the daily ETr from hourly values (spec 5.6) belong to the station
#' orchestration [ef_station_ref_et()], not to this function.
#'
#' Missing values propagate (and are flagged `EF_INPUT_NA`). Negative
#' results (for example at night, when \eqn{R_n - G < 0}{Rn - G < 0} with a
#' small deficit) are kept and flagged `EF_WS_ETR_NEGATIVE` (principle 6),
#' never truncated; ASCE-EWRI (2005, p. 45) states that it "may be
#' appropriate to retain the negative values" in the 24-hour sums. Missing or unknown choices raise
#' `earthflux_missing_input` or `earthflux_unknown_method`; values outside
#' the domains above raise `earthflux_domain_error`.
#'
#' @section Verification status:
#' `standard = "fao56"`, `reference = "grass"`: `VERIFICADA` (FAO-56,
#' chapter 4, Eqs. 6 and 53; examples 18 and 19, cases V14-V16 of
#' dev/specs/weather-forcing.md 8.1). `standard = "asce"` (short and tall
#' reference, daily and hourly, day and night \eqn{C_d}{Cd}): `VERIFICADA`
#' (ASCE-EWRI, 2005, Eq. 1, p. 4, and Table 1, p. 5; the values are those
#' first implemented from secondary sources, unchanged). No worked example
#' of ASCE-EWRI (2005) is reproduced yet (Appendix C not read).
#'
#' @references
#' Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop
#' evapotranspiration: Guidelines for computing crop water requirements*
#' (FAO Irrigation and Drainage Paper 56). FAO, Rome. ISBN 92-5-104219-5.
#'
#' ASCE-EWRI (2005). *The ASCE Standardized Reference Evapotranspiration
#' Equation*. Task Committee on Standardization of Reference
#' Evapotranspiration, Environmental and Water Resources Institute of the
#' American Society of Civil Engineers. Final report, January 2005.
#' Published as Allen, R. G., Walter, I. A., Elliott, R. L., Howell, T. A.,
#' Itenfisu, D., Jensen, M. E., & Snyder, R. L. (Eds.), American Society of
#' Civil Engineers, Reston, VA. \doi{10.1061/9780784408056}
#'
#' @family reference evapotranspiration functions
#' @export
#'
#' @examples
#' # FAO-56 example 18 (Uccle, 6 July, 100 m): daily grass ETo
#' tmean <- (21.5 + 12.3) / 2
#' ea <- ef_ea_daily(tmin = 12.3, tmax = 21.5, rh_max = 84, rh_min = 63,
#'                   method = "rhmax_rhmin")
#' es <- mean(ef_es(c(21.5, 12.3)))
#' rn <- ef_ref_net_radiation(solar_radiation = 22.07,
#'                            clear_sky_radiation = 30.90,
#'                            vapour_pressure = ea, tmax = 21.5, tmin = 12.3,
#'                            timestep = "daily", standard = "fao56")$rn
#' eto <- ef_ref_et(
#'   net_radiation = rn, soil_heat_flux = 0, air_temperature = tmean,
#'   wind_speed_2m = ef_wind_2m(10 / 3.6, 10),
#'   vapour_pressure_deficit = es - ea, slope = ef_es_slope(tmean),
#'   psychrometric = ef_psychrometric(ef_air_pressure(100)),
#'   reference = "grass", timestep = "daily", standard = "fao56"
#' )
#' eto$et_ref
#'
#' # Same inputs, tall reference with the ASCE-EWRI (2005) constants
#' ef_ref_et(
#'   net_radiation = rn, soil_heat_flux = 0, air_temperature = tmean,
#'   wind_speed_2m = ef_wind_2m(10 / 3.6, 10),
#'   vapour_pressure_deficit = es - ea, slope = ef_es_slope(tmean),
#'   psychrometric = ef_psychrometric(ef_air_pressure(100)),
#'   reference = "alfalfa", timestep = "daily", standard = "asce"
#' )$et_ref
ef_ref_et <- function(net_radiation, soil_heat_flux, air_temperature,
                      wind_speed_2m, vapour_pressure_deficit, slope,
                      psychrometric, reference, timestep, standard,
                      daytime = NULL) {
  call <- sys.call()
  k <- check_reference_setup(
    if (missing(reference)) NULL else reference,
    if (missing(timestep)) NULL else timestep,
    if (missing(standard)) NULL else standard,
    call = call
  )
  args <- list(
    net_radiation = net_radiation, soil_heat_flux = soil_heat_flux,
    air_temperature = air_temperature, wind_speed_2m = wind_speed_2m,
    vapour_pressure_deficit = vapour_pressure_deficit, slope = slope,
    psychrometric = psychrometric
  )
  check_core_args(args, call)
  split <- timestep == "hourly" && standard == "asce"
  n <- check_daytime(daytime, needed = split, timestep, args, call = call)
  used_daytime <- if (split) daytime else NULL
  d <- common_dim(c(args, list(daytime = used_daytime)))

  check_in_range(net_radiation, "net_radiation", call = call)
  check_in_range(soil_heat_flux, "soil_heat_flux", call = call)
  # T + 273 > 0 (aerodynamic term of FAO-56 Eqs. 6 and 53).
  check_in_range(air_temperature, "air_temperature", lower = -273,
                 lower_inclusive = FALSE, call = call)
  check_in_range(wind_speed_2m, "wind_speed_2m", lower = 0, call = call)
  check_in_range(vapour_pressure_deficit, "vapour_pressure_deficit",
                 call = call)
  check_in_range(slope, "slope", lower = 0, lower_inclusive = FALSE,
                 call = call)
  check_in_range(psychrometric, "psychrometric", lower = 0,
                 lower_inclusive = FALSE, call = call)

  if (split) {
    cn <- k$cn[k$period == "day"]
    cd <- ifelse(daytime, k$cd[k$period == "day"], k$cd[k$period == "night"])
  } else {
    cn <- k$cn[1L]
    cd <- k$cd[1L]
  }

  # Combination equation (FAO-56 Eqs. 6 and 53; ASCE-EWRI 2005 Eq. 1, the
  # general Cn/Cd form): 0.408 and 273 are literals of the standard (WF-14).
  et_ref <- (0.408 * slope * (net_radiation - soil_heat_flux) +
               psychrometric * cn / (air_temperature + 273) * wind_speed_2m *
                 vapour_pressure_deficit) /
    (slope + psychrometric * (1 + cd * wind_speed_2m))
  et_ref <- ef_reshape(et_ref, n, d)

  flags <- ef_flags_combine(
    ef_diagnose_reference_et(
      et_ref = et_ref,
      inputs = c(args, list(daytime = used_daytime)),
      n = n
    )
  )
  new_ef_object(
    list(
      et_ref = et_ref,
      reference = reference,
      timestep = timestep,
      standard = standard,
      flags = flags$flags,
      provenance = list(
        reference = reference,
        timestep = timestep,
        standard = standard,
        fun = "ef_ref_et",
        status = "VERIFICADA",
        constants = k,
        daytime = if (split) "supplied by the caller (WF-15)" else "not used",
        references = if (standard == "fao56") {
          "FAO-56 (Allen et al., 1998), chapter 4, Eqs. 6 and 53"
        } else {
          paste("ASCE-EWRI (2005), Eq. 1 (p. 4) and Table 1 (p. 5);",
                "G: Eq. 30 (p. 25), Eqs. 65-66 (p. 44)")
        },
        flags_evaluated = flags$evaluated,
        earthflux_version = as.character(getNamespaceVersion("EarthFlux"))
      )
    ),
    "earthflux_reference_et"
  )
}

# Diagnostics ---------------------------------------------------------------------

#' Diagnostics of the reference evapotranspiration
#'
#' Builds the record-scope flags of `ef_ref_et()` (dev/ARCHITECTURE.md
#' section 3.2, point 2): `EF_INPUT_NA` where a required input is missing
#' and `EF_WS_ETR_NEGATIVE` where the reference ET is negative (kept,
#' principle 6). Only codes flagged somewhere produce a record; the codes
#' evaluated are attached as the attribute `evaluated`.
#'
#' @param et_ref Numeric reference ET.
#' @param inputs Named list of the required inputs (`NULL` ignored).
#' @param n Common length.
#' @return A list of `earthflux_flag` records with attribute `evaluated`.
#' @noRd
ef_diagnose_reference_et <- function(et_ref, inputs, n) {
  inputs <- inputs[!vapply(inputs, is.null, logical(1))]
  na_mask <- Reduce(`|`, lapply(inputs, function(x) rep_len(is.na(x), n)))
  ef_flag_set(
    list(
      EF_INPUT_NA = as.vector(na_mask),
      EF_WS_ETR_NEGATIVE = as.vector(!is.na(et_ref) & et_ref < 0)
    ),
    scope = "record"
  )
}

#' Flag codes of the reference evapotranspiration stage
#'
#' Registry rows owned by this file and by the station orchestration
#' `ef_station_ref_et()` (`R/prep-weather.R`) (dev/specs/flags.md section
#' 4.2, stage `WS`): `EF_WS_RS_RSO_LIMITED` (class I-m, the limit
#' Rs/Rso <= 1 of FAO-56 Eq. 39 and the limits 0.3 <= Rs/Rso <= 1 of
#' ASCE-EWRI 2005 Eqs. 18 and 45, `VERIFICADA`), `EF_WS_ETR_NEGATIVE`
#' (class I; the normalised name of `EF_ETREF_NEGATIVE`),
#' `EF_WS_INCOMPLETE_DAY` (class I, QC-10: a day without all its periods
#' gives no daily sum) and `EF_WS_OVERPASS_OUTSIDE_RECORDS` (class I, cause
#' of `NA` of the reference ET at the overpass). All have the record scope
#' and no bit (the cell scope of `EF_WS_ETR_NEGATIVE` depends on decision
#' FL-09).
#'
#' @return A data frame built with `ef_flag_rows()`.
#' @noRd
ef_flags_reference_et <- function() {
  ef_flag_rows(
    code = c("EF_WS_RS_RSO_LIMITED", "EF_WS_ETR_NEGATIVE",
             "EF_WS_INCOMPLETE_DAY", "EF_WS_OVERPASS_OUTSIDE_RECORDS"),
    stage = rep("WS", 4L),
    severity = c("info", "info", "warning", "info"),
    scope = rep("record", 4L),
    bit = rep(NA_integer_, 4L),
    error_class = rep(NA_character_, 4L),
    description = c(
      paste(
        "The ratio Rs/Rso is outside the range of the standard (above 1;",
        "for ASCE-EWRI also below 0.3) and is limited inside the",
        "cloudiness term of the reference net longwave radiation;",
        "Rs is unchanged."
      ),
      "The reference evapotranspiration is negative; the value is kept.",
      paste(
        "The day does not have a valid reference evapotranspiration in all",
        "its periods; the daily sum is missing."
      ),
      paste(
        "The overpass time is outside the time range covered by the",
        "records of the station; the instantaneous reference",
        "evapotranspiration is missing."
      )
    ),
    spec = c("dev/specs/weather-forcing.md 4.8",
             "dev/specs/weather-forcing.md 5.4",
             "dev/specs/weather-forcing.md 3.2 (QC-10), 5.6",
             "dev/specs/weather-forcing.md 5.5"),
    since = rep("0.0.0.9000", 4L)
  )
}

# Instantaneous and daily reference ET from an hourly series -----------------------

#' Reference ET at the overpass time by linear interpolation (option O3)
#'
#' Option O3 of dev/specs/weather-forcing.md 5.5 (provisional
#' recommendation of decision WF-09, still open): the hourly reference ET
#' rates of consecutive periods are interpolated linearly in time between
#' the midpoints of the periods. No extrapolation: an overpass time outside
#' \[first midpoint, last midpoint\] gives `NA` (the orchestration
#' `ef_station_ref_et()` flags it `EF_WS_OVERPASS_OUTSIDE_RECORDS`). A
#' missing rate at either neighbour gives `NA` (no interpolation across
#' gaps).
#'
#' @param et_ref Numeric hourly reference ET rates \[mm h-1\], one per
#'   period.
#' @param period_mid Numeric midpoints of the periods (any numeric time
#'   unit, e.g. decimal hours or seconds), strictly increasing, without
#'   `NA`, same length as `et_ref`.
#' @param overpass Numeric overpass times in the unit of `period_mid`.
#' @return Numeric instantaneous reference ET \[mm h-1\], one per
#'   `overpass`.
#' @section Verification status: `TODO` (method choice WF-09 open; the
#'   arithmetic reproduces case O3 of spec 5.5: 0.77 mm h-1).
#' @noRd
ef_ref_et_inst_interp <- function(et_ref, period_mid, overpass) {
  call <- sys.call()
  check_numeric(et_ref, "et_ref", call = call)
  check_numeric(period_mid, "period_mid", call = call)
  check_numeric(overpass, "overpass", call = call)
  if (length(et_ref) != length(period_mid) || length(et_ref) < 2L ||
      length(overpass) == 0L) {
    ef_abort(
      paste0(
        "`et_ref` and `period_mid` must have the same length (at least 2) ",
        "and `overpass` must not be empty."
      ),
      class = "earthflux_input_error",
      call = call
    )
  }
  if (anyNA(period_mid) || any(diff(period_mid) <= 0)) {
    ef_abort("`period_mid` must be strictly increasing and without NA.",
             class = "earthflux_input_error", call = call)
  }
  check_in_range(et_ref, "et_ref", call = call)
  check_in_range(overpass, "overpass", call = call)

  m <- length(period_mid)
  i <- findInterval(overpass, period_mid, rightmost.closed = TRUE)
  out <- rep(NA_real_, length(overpass))
  inside <- !is.na(i) & i >= 1L & i < m
  j <- i[inside]
  frac <- (overpass[inside] - period_mid[j]) /
    (period_mid[j + 1L] - period_mid[j])
  out[inside] <- et_ref[j] + frac * (et_ref[j + 1L] - et_ref[j])
  out
}

#' Daily reference ET as the sum of complete days (option D1)
#'
#' Option D1 of dev/specs/weather-forcing.md 5.6 (provisional
#' recommendation of decision WF-16): the daily reference ET is the sum of
#' the per-period depths of each day. The day of each period (local
#' standard or UTC day, decision WF-11 open) is given by the caller. A day
#' with fewer than `periods_per_day` periods or with a missing value gives
#' `NA` (the orchestration `ef_station_ref_et()` flags it
#' `EF_WS_INCOMPLETE_DAY`); no gap is filled.
#'
#' @param et_ref Numeric reference ET per period \[mm h-1 times 1 h = mm\].
#' @param day Vector (character, integer, Date) with the day of each period,
#'   same length as `et_ref`, without `NA`.
#' @param periods_per_day Whole number of periods of a complete day (24 for
#'   hourly data).
#' @return Named numeric daily reference ET \[mm d-1\], one per day in order
#'   of first appearance.
#' @section Verification status: `TODO` for the use in METRIC (D1 for
#'   METRIC, Allen et al., 2007, not verified); FAO-56 (chapter 4) states
#'   that hourly sums over 24 hours generally match the daily computation
#'   for grass, and ASCE-EWRI (2005, p. 45) sums hourly ETos or ETrs "over
#'   the 24-hour period" keeping negative values, without defining the
#'   clock of the day (WF-11).
#' @noRd
ef_ref_et_daily_sum <- function(et_ref, day, periods_per_day) {
  call <- sys.call()
  check_numeric(et_ref, "et_ref", call = call)
  check_scalar(periods_per_day, "periods_per_day", lower = 1, whole = TRUE,
               call = call)
  if (length(day) != length(et_ref) || length(et_ref) == 0L || anyNA(day)) {
    ef_abort(
      "`day` must have the length of `et_ref` (not 0) and no NA.",
      class = "earthflux_input_error",
      call = call
    )
  }
  check_in_range(et_ref, "et_ref", call = call)
  key <- as.character(day)
  groups <- split(as.vector(et_ref), factor(key, levels = unique(key)))
  vapply(groups, function(x) {
    if (length(x) != periods_per_day) NA_real_ else sum(x)
  }, numeric(1))
}
