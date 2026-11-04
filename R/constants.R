# Physical constants ---------------------------------------------------------------
#
# Purpose: one named constant per physical magnitude used by the core, defined
#   in a single place and never repeated as a literal (dev/DECISIONS.md, P0-5;
#   dev/specs/radiation-components.md section 5; dev/specs/sensible-heat.md
#   section 4.3).
#
# Rules:
# - Every constant records its unit, source and verification status
#   (VERIFICADA / CANDIDATA / TODO, as in dev/SCIENTIFIC_SPEC.md).
# - Normative coefficients of standardised equations (FAO-56, ASCE-EWRI) stay
#   as literals inside the function that implements that equation, next to its
#   reference (decision WF-14); e.g. the coefficients of P(z) live in
#   ef_air_pressure().
# - Only magnitudes defined in the specifications are listed here; values are
#   never invented. A constant whose value is CANDIDATA is still usable, but
#   its status must be reported by the functions that use it.
# - Naming (`EF_*` in upper case) follows the specifications; whether to
#   rename them to lower-case internal names is decision FL-08
#   (dev/specs/flags.md). Flag codes cannot collide with these names: the
#   closed code pattern and test R15 of dev/specs/flags.md section 8 prevent
#   it.
# - Internal: none of these objects is exported.

# Offset between the Kelvin and Celsius scales [K].
# Source: definition of the Celsius scale (SI); package convention 273.15
#   everywhere (decision G-D9, dev/specs/soil-heat-flux.md section 3.2;
#   transversal group T-06).
# Status: exact by definition; adoption DECIDIDA (provisional, 2026-11-04).
EF_KELVIN_OFFSET <- 273.15

# Stefan-Boltzmann constant [W m-2 K-4].
# Source: CODATA 2018 recommended values; exact in the 2019 revision of the SI
#   (derived from the exact h, k and c). Full citation of the CODATA/NIST
#   publication: TODO (dev/specs/radiation-components.md section 5).
# Status: value exact; adoption in the core DECIDIDA (provisional, 2026-11-04,
#   decision RC-07). The rounded 5.67e-8 found in METRIC implementations is a
#   reproducibility alternative only (CANDIDATA); FAO-56 reference ET keeps its
#   own literal (WF-14).
EF_STEFAN_BOLTZMANN <- 5.670374419e-8

# Solar constant Gsc [W m-2].
# Source: FAO-56 (Allen et al., 1998), chapter 3, Eq. 21:
#   Gsc = 0.0820 MJ m-2 min-1 = 0.0820e6 / 60 W m-2 = 1366.67 W m-2
#   (dev/specs/weather-forcing.md section 4.6; radiation-components.md
#   section 5).
# Status: value VERIFICADA as FAO-56 Eq. 21. Its adoption as the Gsc of the
#   METRIC core is CANDIDATA: decision RC-06 requires the value with which the
#   coefficients of the shortwave transmissivity were derived (ASCE-EWRI,
#   2005, not yet verified). The alternative of about 1361 W m-2 (recent total
#   solar irradiance) has no primary source yet (TODO).
EF_SOLAR_CONSTANT <- 0.0820 * 1e6 / 60

# von Karman constant [-].
# Source: FAO-56, chapter 2, Eq. 4 ("von Karman's constant, 0.41").
# Status: VERIFICADA as the value used in FAO-56; its use in METRIC is
#   CANDIDATA (dev/specs/sensible-heat.md section 4.3).
EF_VON_KARMAN <- 0.41

# Gravitational acceleration [m s-2].
# Source: value used in METRIC implementations (`water`) and in the general
#   form of the pressure-elevation relation of FAO-56, annex 3, Eq. 3-2
#   (dev/specs/weather-forcing.md section 4.1).
# Status: CANDIDATA; value and reference for the METRIC core (standard
#   gravity versus 9.81) are TODO (decision SH-10, dev/specs/sensible-heat.md
#   section 4.3).
EF_GRAVITY <- 9.807

# Specific heat of air at constant pressure c_p [J kg-1 K-1].
# Source: dev/SCIENTIFIC_SPEC.md section 3 ("c_p ~ 1004") and METRIC
#   implementations (`water`). Alternative: 1013 J kg-1 K-1, FAO-56,
#   chapter 3, text of Eq. 8 (VERIFICADA as an FAO-56 value; FAO-56 reference
#   ET keeps it as a literal, WF-14).
# Status: CANDIDATA. The METRIC value must be confirmed in Allen, Tasumi and
#   Trezza (2007) (decision SH-09, still ABIERTA; dev/DECISIONS.md P0-1, P0-6).
#   Sensitivity is low: c_p cancels in H except through the Monin-Obukhov
#   length (dev/specs/sensible-heat.md section 8.3).
EF_SPECIFIC_HEAT_AIR <- 1004

# Density of liquid water rho_w [kg m-3].
# Source: FAO-56, chapter 3, box 8 ("density of water, i.e., 1000 kg m-3");
#   chapter 1, note to table 1 (dev/specs/evapotranspiration.md section 4.4).
# Status: VERIFICADA; internal constant, not an argument (decision ET-D3).
EF_WATER_DENSITY <- 1000

# Latent heat of vaporization, FAO-56 constant value [J kg-1].
# Source: FAO-56, chapter 3, "Latent heat of vaporization": 2.45 MJ kg-1, the
#   latent heat for an air temperature of about 20 degrees C; annex 3
#   (dev/specs/evapotranspiration.md section 4.1).
# Status: VERIFICADA. Used by ef_latent_heat_vaporization(method = "constant").
EF_LATENT_HEAT_FAO56 <- 2.45e6
