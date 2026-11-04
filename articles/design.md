# Design and development status

This page describes the planned design of EarthFlux and the development
status of each component. **Only the functions marked as available can
be used today.** All other functions are planned: their names, arguments
and behaviour may still change, and none of their results should be
used.

Each component is implemented only after its equations, units, domain of
validity and test cases are specified and, where possible, verified
against the primary sources. The internal specifications are linked
below for readers who want the full detail.

## Processing chain

``` text
MODIS products            weather stations
      |                         |
 surface state           quality control, reference ET
 (LST, albedo,                  |
  NDVI, LAI, emissivity)  spatial forcing (C1 single station,
      |                    C2 simple interpolation, C3 GWR)
      |                         |
      +------------+------------+
                   |
   METRIC: Rn -> G -> anchor pixels -> rah, dT -> H -> LE
                   |
          ETinst -> ETrF -> ETa  (+ diagnostic flags and provenance)
```

The use of geographically weighted regression (GWR) for the
meteorological forcing is a research hypothesis that EarthFlux is
designed to test, not an established result.

## Verification status

| Status | Meaning |
|----|----|
| Verified | The equation was checked against the primary source (equation and page or table). |
| Candidate | Known form, corroborated by secondary sources, pending verification against the primary source. |

## Components

### Radiation (milestone M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_net_radiation()`](https://djwillichile.github.io/EarthFlux/reference/ef_net_radiation.md) | Surface net radiation | **Available**; equation candidate (corroborated) |
| [`ef_solar_geometry()`](https://djwillichile.github.io/EarthFlux/reference/ef_solar_geometry.md) | Solar angles and incidence on sloping terrain | Planned; candidate |
| [`ef_air_pressure()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_pressure.md) | Atmospheric pressure from elevation | Planned; equation verified (FAO-56, Eq. 7) |
| [`ef_tau_sw()`](https://djwillichile.github.io/EarthFlux/reference/ef_tau_sw.md) | Broadband shortwave transmissivity with beam/diffuse partition | Planned; candidate |
| [`ef_rs_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rs_in.md) | Incoming shortwave radiation, including slope and aspect | Planned; candidate |
| [`ef_atm_emissivity()`](https://djwillichile.github.io/EarthFlux/reference/ef_atm_emissivity.md) | Clear-sky atmospheric emissivity | Planned; candidate |
| [`ef_rl_in()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_in.md), [`ef_rl_out()`](https://djwillichile.github.io/EarthFlux/reference/ef_rl_out.md) | Incoming and emitted longwave radiation | Planned; candidate |

Specifications:
[ef_net_radiation.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/ef_net_radiation.md),
[radiation-components.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/radiation-components.md).

### Soil heat flux (M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_g()`](https://djwillichile.github.io/EarthFlux/reference/ef_g.md) | Soil heat flux with an explicit method | Planned; candidate |

Specification:
[soil-heat-flux.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/soil-heat-flux.md).

### Anchor pixels (M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_anchor_criteria()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchor_criteria.md) | Explicit, documented selection criteria | Planned |
| [`ef_select_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_select_anchors.md) | Automatic, deterministic and auditable selection of hot and cold pixels | Planned; candidate |
| [`ef_anchors()`](https://djwillichile.github.io/EarthFlux/reference/ef_anchors.md) | Anchors chosen explicitly by the user | Planned |

Specification:
[anchor-pixels.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/anchor-pixels.md).

### Sensible heat flux (M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_zom()`](https://djwillichile.github.io/EarthFlux/reference/ef_zom.md) | Momentum roughness length | Planned; candidate |
| [`ef_ustar()`](https://djwillichile.github.io/EarthFlux/reference/ef_ustar.md), [`ef_rah()`](https://djwillichile.github.io/EarthFlux/reference/ef_rah.md) | Friction velocity and aerodynamic resistance with stability correction | Planned; candidate |
| [`ef_air_density()`](https://djwillichile.github.io/EarthFlux/reference/ef_air_density.md) | Air density | Planned; candidate |
| [`ef_dt_coef()`](https://djwillichile.github.io/EarthFlux/reference/ef_dt_coef.md) | Calibration of the near-surface temperature difference from the anchors | Planned; candidate |
| [`ef_sensible_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_sensible_heat.md) | Sensible heat flux | Planned; candidate |

Specification:
[sensible-heat.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/sensible-heat.md).

### Evapotranspiration (M2)

| Function | Purpose | Status |
|----|----|----|
| [`ef_latent_heat()`](https://djwillichile.github.io/EarthFlux/reference/ef_latent_heat.md) | Latent heat flux as the energy balance residual | Planned; balance verified (FAO-56) |
| [`ef_et_inst()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_inst.md) | Instantaneous ET from latent heat flux | Planned; unit conversion verified (FAO-56) |
| [`ef_etrf()`](https://djwillichile.github.io/EarthFlux/reference/ef_etrf.md), [`ef_et_daily()`](https://djwillichile.github.io/EarthFlux/reference/ef_et_daily.md) | Reference ET fraction and daily actual ET | Planned; candidate |
| `ef_et_period()` | ET between image dates | Planned (later) |

Specification:
[evapotranspiration.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/evapotranspiration.md).

### Weather stations and reference ET (milestone M3)

| Function | Purpose | Status |
|----|----|----|
| `ef_station_table()` | Standard station and observation tables (explicit time zone, measurement heights) | Planned |
| `ef_station_qc()` | Station quality control (values are flagged, never deleted) | Planned |
| `ef_ref_et()` | Grass (FAO-56) and alfalfa (ASCE) reference ET, hourly and daily | Planned; FAO-56 grass reference verified, alfalfa constants candidate |

Specification:
[weather-forcing.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/weather-forcing.md).

### Spatial forcing (M3)

| Function | Purpose | Status |
|----|----|----|
| `ef_gwr_fit()`, `ef_gwr_predict()` | GWR with documented kernel, bandwidth and AICc conventions; block-wise prediction | Planned |
| `ef_ols_fit()`, `ef_idw_fit()` | Simple spatial alternatives (C2) | Planned |
| `ef_station_forcing()` | Single representative station (C1) | Planned |

Specification:
[gwr-forcing.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/gwr-forcing.md).

### MODIS preprocessing (milestone M4)

Internal functions that read MODIS products, apply scale factors and
quality flags, and convert view times to UTC, producing
sensor-independent surface variables. Product metadata (layers, scale
factors, fill values, quality bits) are verified against the official
user guides.

Specification:
[modis-products.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/specs/modis-products.md).

### Integrated workflow (milestone M5)

| Function | Purpose | Status |
|----|----|----|
| `earthflux()` | Complete workflow built on the same low-level functions, returning all intermediate components, diagnostics and provenance | Planned |

## More information

- Scientific specification and index:
  [SCIENTIFIC_SPEC.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/SCIENTIFIC_SPEC.md)
- Roadmap:
  [ROADMAP.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/ROADMAP.md)
- Validation plan:
  [VALIDATION_PLAN.md](https://github.com/djwillichile/EarthFlux/blob/main/dev/VALIDATION_PLAN.md)
