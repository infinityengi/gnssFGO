# Septentrio vs NovAtel Preprocessing – Current Implementation Status

Date: December 9, 2025  
Scope: irt_gnss_preprocessing (Septentrio Mosaic-H vs NovAtel OEM7)

## Snapshot (what’s integrated today)
- **Preprocessing execution (Simulink models)**: ✅ Implemented and building; `executePreprocessing()` called from MeasEpoch. Guards prevent running without nav data.
- **Raw observations**: ✅ MeasEpoch → internal `gnssraw_measurement_t`; dual-antenna MeasEpoch buffered.
- **Receiver PVT**: ✅ PVTGeodetic converted and published as `PVAGeodetic`.
- **Ephemeris/Iono/Clock/GGTO**: ❌ No Septentrio ROS topics; preprocessing exits early with warnings.
- **RTCM/DD RTK**: ❌ No RTCM subscription wired; DD path unused.
- **Dual-antenna preprocessing**: ⚠️ Input buffering present; not wired into preprocessing inputs (DD disabled).
- **Integrity/LOS**: ❌ Not mapped; no CN0/elevation gating.
- **Outputs**: ❌ `GNSSObsPreProcessed` / LS PVT / residuals not published.

## Driver reality (septentrio_gnss_driver)
- Publishes: `MeasEpoch`, `PVTGeodetic`, `PosCovGeodetic`, `VelCovGeodetic`, `AttEuler`, `BaseVectorGeod`, `ReceiverTime` (per README).
- Does **not** publish: GPS/GAL ephemeris, ionosphere, GGTO/clock blocks as ROS messages.
- Implication: External source or driver extension required to feed preprocessing models.

## Delta vs NovAtel (feature-by-feature)
| Area | NovAtel OEM7 | Septentrio now | Gap / Action |
|---|---|---|---|
| Raw obs ingest | RANGE → converter → step() | MeasEpoch → convert; step() called | ✅ Done once nav present |
| PVT | BESTPOS/BESTVEL/CLOCK/DUALANTHEADING → rich PVT | PVTGeodetic → lean PVT | Minor: map extra fields if available |
| GPS Ephemeris | GPSEPHEM | None | **Blocker**: add provider/subscription |
| GAL Ephemeris | GALI/FNAV | None | **Blocker**: add provider/subscription |
| Ionosphere | IONUTC/GALIONO | None | **Blocker**: add provider/subscription |
| GGTO | GALCLOCK | None | Optional: disable or provide |
| RTCM/DD RTK | RTCM buffer + DDRTCM | None | Add RTCM sub; gate DD |
| Dual antenna | Full dual + DD | Buffers only | Wire baseline/aux + enable DD |
| Integrity/mode | IntegrityParametersBus | Not wired | Map params; propagate flags |
| LOS/NLOS | LUT filter | None | Add CN0/elev gate or LUT |
| Outputs | GNSSObsPreProcessed + LS PVT/residuals | Not published | Add publishers |

## What still needs to be done (ordered)
1) **Ephemeris/Iono/Clock feed (P2)**
   - Add subscriptions to ephemeris topics (from external provider or driver extension).
   - Convert to `gnssraw_gps_nav_t`, `gnssraw_gal_nav_t`, `gnssraw_gps_ion_t`, `gnssraw_gal_ion_t`, `gnssraw_ggto_t`.
   - Keep guards to skip preprocessing until data present.

2) **RTCM / DD RTK (P2)**
   - Subscribe to RTCM corrections; fill `rtcm_buffer_`.
   - Gate DD/RTK flags off when empty; enable when present.

3) **Dual-antenna wiring (P3)**
   - Feed `AttEuler` + `BaseVectorGeod` + aux MeasEpoch into dual-antenna input buses.
   - Enable `EnableDualAntennaDD` when baseline valid.

4) **Integrity + LOS (P4)**
   - Populate `IntegrityParametersBus`; propagate flags.
   - Add CN0/elevation screening (or LUT) before feeding measurements.

5) **Outputs (P5)**
   - Publish `GNSSObsPreProcessed`, LS PVT, residuals (topics aligned with NovAtel).
   - Add diagnostics for missing nav/iono/RTCM.

## Practical step-by-step plan
1. **Decide nav source**: external ephemeris provider vs driver extension. (External is fastest.)
2. **Wire nav inputs**: add subscribers + converters; remove early-return once data flows.
3. **Enable RTCM path**: add subscription, guard DD flags.
4. **Connect dual-antenna inputs**: baseline/att + aux MeasEpoch; enable dual DD if needed.
5. **Map integrity/LOS**: params to buses; CN0/elev gate.
6. **Publish outputs**: `gnss_obs_preprocessed`, LS PVT, residuals.
7. **Test**: static open-sky, RTK, dual-antenna, GPS+GAL, regression bag.

## Validation checklist (post-fix)
- Preprocessed obs count > 0; GPS ephem present; no nav-missing warnings.
- If GAL enabled: GGTO valid (or explicitly disabled) and GAL obs present.
- RTCM available → DD outputs non-empty; has_rtk flag set.
- Dual-antenna: baseline/heading populated; DD dual indices valid.
- Integrity flags and CN0/elev gating functioning.
- Topics published: `/gnss_obs_preprocessed`, `/PVT`, `/LeastSquarePVT`, `/ls_ant_main_residuals`.

## References
- Septentrio implementation: `src/impl/septentrio_preprocessor.{h,cpp}`
- NovAtel reference: `src/impl/novatel_oem7_preprocessor.{h,cpp}`
- Driver docs: `septentrio_gnss_driver/README.md`
- Status notes: `SEPTENTRIO_IMPLEMENTATION_STATUS.md`, `P1_IMPLEMENTATION_COMPLETE.md`
