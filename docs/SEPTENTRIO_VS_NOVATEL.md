# Septentrio vs NovAtel Preprocessing Guide (Expanded)

Date: December 8, 2025  
Package: irt_gnss_preprocessing  
Purpose: Deep gap analysis of Septentrio Mosaic-H preprocessing vs NovAtel OEM7, with concrete wiring plan, risk notes, and further considerations for rollout and testing.

---

## 1) High-Level Summary (what works vs blocked)
- Septentrio today: converts MeasEpoch → `gnssraw_measurement_t`, PVT → `gnssraw_pvt_geodetic_t`, buffers data, publishes PVT, subscribes dual-antenna topics (AttEuler/BaseVectorGeod) but never injects them into processing.
- NovAtel today: full pipeline—ephemeris/iono/clock ingestion + converters, GGTO handling, RTCM/DD, LOS/NLOS filter, dual-antenna (incl. DD), integrity + mode-switch, publishes `GNSSObsPreProcessed`, LS PVT, residuals.
- Core blocker: Septentrio never calls `gnss_preprocessor_->step()` with assembled inputs and lacks all nav/iono/clock/RTCM feeds; therefore no preprocessed obs reach FGO, only PVT.

---

## 2) Feature Matrix (with wiring deltas)
| Area | NovAtel OEM7 (working) | Septentrio (current) | Impact | Required wiring
|------|------------------------|----------------------|--------|-----------------
| Raw obs ingest | RANGE → Simulink MeasEpoch converter; dual main+aux sync; LOS screen | MeasEpoch → manual convert; dual aux buffered only | Obs never reach model | Build MeasurementEpoch bus and call `step()`; optional LOS filter
| PVT solution | BESTPOS/BESTVEL/CLOCK/DUALANTHEADING sync → rich PVT bus | PVTGeodetic + PosCov + VelCov → lean PVT bus | Less quality metadata | Map additional fields if available; align struct
| Ephemeris | GPS, GAL F/NAV/I/NAV via converters into `gnssraw_*_nav_t` | None | No sat positions | Subscribe to SBF nav blocks; add converters (GPS+GAL)
| Iono/Clock | GALIONO, IONUTC, GALCLOCK → iono/clock buses | None | No iono/clock corrections | Subscribe/convert iono+clock (GPS+GAL)
| GGTO | GAL-GPS GGTO handled | None | Wrong inter-system timing | If driver publishes GGTO, convert; else disable merge
| RTCM / DD RTK | RTCM buffer + DDRTCM block | None | No RTK/DD | Add RTCM subscription; gate DD flags if absent
| Dual antenna | Full dual-antenna + DD path | AttEuler/BaseVectorGeod buffered only | No heading/baseline factors | Feed baseline/att into dual block; enable DD dual-antenna if needed
| Integrity / mode switch | IntegrityParametersBus + mode gating | Not wired | No quality flags | Map params; propagate integrity outputs
| LOS/NLOS | getSatInfoNovAtel LUT | None | Multipath risk | Add simple CN0/elev gate or LUT
| Outputs | GNSSObsPreProcessed + LS PVT + residuals | Only PVAGeodetic | FGO starved of factors | Publish preprocessed obs + LS outputs

---

## 3) Missing Pieces (Septentrio)
1) **Navigation products**: No GPS/GAL ephemeris, iono, GGTO, or clock messages ingested; converters absent.  
2) **RTCM/DD**: No RTCM subscription/buffer; DD RTK block unused.  
3) **Dual-antenna wiring**: Baseline/attitude buffered but never connected to preprocessing; DD dual-antenna path unused.  
4) **Integrity + mode switch**: IntegrityParametersBus not populated; flags not propagated.  
5) **LOS/NLOS**: No screening; CN0/elevation unused.  
6) **Execution**: No `gnss_preprocessor_->step()` with assembled inputs.  
7) **Outputs**: No `GNSSObsPreProcessed`, LS PVT, or residuals published.  
8) **Parameter parity**: YAML → parameter structs not mapped for Septentrio receiver type.  
9) **Config/launch**: Topics/params for new subscriptions not exposed.

---

## 4) Impact on Downstream FGO
- Missing factors: GNSS factors absent → solver relies on other sensors only.
- Missing corrections: No ephemeris/iono/clock → ranges invalid; preprocessing drops epochs.
- No RTK/DD: Cannot reach cm-level; only receiver PVT (standalone/RTK-internal) passes through.
- No integrity: Graph cannot gate bad epochs; risk of biased solutions if later wired without checks.
- Dual-antenna idle: Heading/baseline constraints not contributed.
- Potential multipath: Without LOS filter, later-enabling preprocessing risks noisy factors.

---

## 5) Correction Plan (priority-ordered tasks)
**P1 – Execute the model**
- Add preprocessing trigger (prefer MeasEpoch callback once nav/iono present, or synced with PVT): build input bus, call `gnss_preprocessor_->step()`, publish outputs.
- Load GNSS/integrity parameters from YAML (mirror NovAtel path) based on receiver type.

**P2 – Feed required data**
- Ephemeris: subscribe to Septentrio nav/ephemeris topics (SBF nav blocks) → convert to `gnssraw_gps_nav_t`, `gnssraw_gal_nav_t`.
- Iono/clock: subscribe/convert to `gps_ion`, `gal_ion`, `gal_gst_gps`; gate preprocessing until present when enabled.
- RTCM: add subscription/buffer; if absent, disable DD/RTK flags to avoid silent empties.

**P3 – Dual-antenna**
- Use `AttEuler` + `BaseVectorGeod` + aux MeasEpoch to populate dual inputs; enable dual block when `USE_DUAL_ANTENNA`.
- For DD dual-antenna, mirror NovAtel DD flow (inputs + params + output mapping).

**P4 – Quality/integrity**
- Populate IntegrityParametersBus and mode-switch flags; propagate integrity to outputs.
- Add LOS/NLOS gate (CN0/elevation threshold or LUT) before feeding measurements.

**P5 – Outputs and config**
- Publish `GNSSObsPreProcessed`, LS PVT, residuals; keep topic names consistent with NovAtel.
- Expose new params/topics in launch files; add diagnostics/logs for missing nav/iono/RTCM.

---

## 6) Minimal Patch Sketch (conceptual wiring)
```cpp
// 1) Subs/buffers: add ephem (GPS/GAL), iono, clock/GGTO, RTCM; keep MeasEpoch/PVT/dual as-is.

// 2) Build input (single or dual):
GNSS_preprocessingModelClass::ExtU_GNSS_preprocessing_T in{};
in.MeasurementEpochBus = meas_main;
in.GpsNavBus = gps_nav_bus;  // gate: checkHaveEphem
in.GpsIonBus = gps_ion_bus;  // optional gate
in.GalInavBus = gal_inav_bus; // or GalFnav
in.GalIonBus = gal_ion_bus;
in.GalGstGpsBus = gal_gstgps_bus; // GGTO
in.RTCM33L1E1Bus = rtcm_bus; // if available
in.GnssParametersBus = parameters_gnss_;
in.IntegrityParametersBus = parameters_integrity_;
in.UseModeSwitchLogic = use_mode_switch_logic_;
in.EnableGGTO = ggto_sync_mode_;

gnss_preprocessor_->setExternalInputs(&in);
gnss_preprocessor_->step();
auto out = gnss_preprocessor_->getExternalOutputs();
publish(makeGNSSObsPreProcessedROSMsg(out));
```
Guards: warn+return when nav missing; auto-disable RTK/DD when RTCM absent; skip GGTO when not provided.

---

## 7) Validation Plan (post-fix)
1) Static open-sky: preprocessed obs >0; DOP sane; integrity flag toggles when satellites masked.
2) RTK (if corrections available): `has_rtk` true; DD outputs populated; PVT/factors converge to cm-level.
3) Dual antenna: baseline/heading present; std within expected; DD dual-antenna indices non-zero.
4) Multi-constellation: GPS+GAL both present; GGTO delta nonzero/finite; no warnings about missing nav.
5) Regression: run `automated_test_suite.sh` plus Septentrio bag replay; add assertions for published topics and sizes.

---

## 8) Quick Checklist
- [ ] Add ephemeris/iono/clock subscribers + converters (GPS+GAL, GGTO if available)
- [ ] Wire preprocessing step with required inputs + guards
- [ ] Publish GNSSObsPreProcessed, LS PVT, residuals (topic parity with NovAtel)
- [ ] Map YAML params (GNSS/integrity/mode-switch) for Septentrio receiver type
- [ ] Dual-antenna path enabled and validated; DD dual-antenna if needed
- [ ] RTCM/DD integration gated (if corrections available)
- [ ] LOS/NLOS filter added (CN0/elev or LUT)

---

## 9) Further Considerations
- **Data availability**: Confirm Septentrio driver publishes nav/iono/clock/GGTO/RTCM topics; if not, plan external sources (BRDC/IGS) or disable features explicitly.
- **Parameter parity**: Ensure YAML keys exist and are loaded when `receiver_type == septentrio`; align defaults with NovAtel to avoid silent divergences.
- **Performance**: MeasEpoch rate can be high; keep buffer sizes sane and avoid heavy logging in callbacks.
- **Frame/time**: Validate time system consistency (GPS vs GAL vs ROS time); ensure GGTO disabled if data missing.
- **Safety gates**: Prefer hard gates (return early) when nav/iono/RTCM missing to avoid emitting bogus obs.
- **Testing assets**: Keep a small Septentrio bag with nav/iono/RTCM for regression; include open-sky and RTK cases.

## 10) References (code anchors)
- Septentrio: `src/impl/septentrio_preprocessor.cpp` (no `step()` call; only PVT publish)
- Septentrio header: `include/irt_gnss_preprocessing/impl/septentrio_preprocessor.h`
- NovAtel: `src/impl/novatel_oem7_preprocessor.cpp` (full pipeline: ephemeris/iono/RTCM/GGTO/dual/DD/integrity/output)
