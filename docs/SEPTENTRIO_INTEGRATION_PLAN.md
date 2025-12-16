# Septentrio Mosaic-H → irt_gnss_preprocessing Integration Plan (Full Parity with NovAtel)

Date: December 16, 2025  
Scope: End-to-end plan to achieve functional parity with NovAtel OEM7 using Septentrio mosaic‑H, covering navigation data, preprocessing integration, outputs, RTK, and dual-antenna features.

---

## 1. Objectives
- Provide all data inputs required by `irt_gnss_preprocessing` to execute preprocessing models reliably (single and dual antenna).
- Achieve observable outputs equivalent to NovAtel path: `/gnss_obs_preprocessed`, `/LeastSquarePVT`, `/ls_ant_main_residuals`, plus PVT.
- Support GPS + Galileo (merge), Ionosphere corrections, GGTO, optional RTCM (RTK/DD), and dual-antenna baseline/attitude.
- Maintain minimal complexity: wire Septentrio SBF to preprocessing buses directly; add thin compatibility topics only where external tools depend on NovAtel names.

---

## 2. Current Status Summary
- Driver: Septentrio SBF parsers implemented for 5 nav blocks (Dec 11–15).
- Topics publishing and validated by bag: `/gpsephem`, `/gpsion`, `/galfnavephem`, `/galion`, `/galclock`.
- Preprocessor: `SeptentrioSBFPreProcessor` class exists with 5 nav subscribers (ApproximateTime sync), circular buffers, and converter functions.
- Bag analysis: `nav_test_run` confirms rates and content; publication asymmetry (Galileo:GPS ~10.6×) is normal.
- Outstanding work: wire converter outputs to preprocessing buses, add MeasEpoch trigger, publish outputs, optional RTCM and dual-antenna wiring.

---

## 3. Requirements (Data & Topics)

### 3.1 Mandatory Inputs (Single Antenna)
- `MeasurementEpochBus` (from `/measepoch`) — main raw observations.
- `GpsNavBus` (from `/gpsephem`).
- `GalNavBus` (prefer F/NAV from `/galfnavephem`).
- `GpsIonBus` (from `/gpsion`).
- `GalIonBus` (from `/galion`).
- `GalGstGpsBus` (GGTO; from `/galclock`).
- `GnssParametersBus` + `IntegrityParametersBus` — from YAML.

### 3.2 Optional/Recommended Inputs
- `RTCM33L1E1Bus` — when corrections available (NTRIP/IP/serial).
- Dual-antenna: baseline (`/basevectorgeod`), attitude (`/atteuler`), and auxiliary observations (`/measepoch_aux`).
- Quality/visibility: Channel status, tracking status, DOP, ReceiverStatus (from manual SBF blocks) for LOS/NLOS and integrity gates.
- Timing: `ReceiverTime`, UTC status/leap seconds (sanity checks).

### 3.3 Outputs (Parity)
- `/gnss_obs_preprocessed` (GNSSObsPreProcessed).
- `/LeastSquarePVT` (PVTLS) — dual-antenna/LS path.
- `/ls_ant_main_residuals` (Residuals).
- `/PVT` (PVAGeodetic equivalent) — already available via Septentrio PVT topics.

---

## 4. Recommended Approach

1) Direct bus wiring: Map Septentrio SBF nav + MeasEpoch directly to preprocessing buses. Avoid cloning every NovAtel topic.
2) Minimal compat layer: Only expose NovAtel-like topics where external tools strictly depend on their names (e.g., ephemeris/iono/GGTO).
3) Parameter gating: Allow GPS-only fallback; gate GGTO/Iono uses via YAML flags to avoid stalls when sparse.
4) Incremental validation: Validate nav-rich bag first (`nav_test_run`), then broader-topic bag for robustness.

---

## 5. Implementation Steps (Files & Symbols)

### Step 1 — Wire Nav Buses in Sync Callback
- File: `irt_gnss_preprocessing/irt_gnss_preprocessing/src/impl/septentrio_sbf_preprocessor.cpp`
- Function: `onSeptentrioNavMsgCb(...)`
- Actions:
  - Call existing converters: `convertSeptentrioGPSEphem`, `convertSeptentrioGAL...`, `convertSeptentrioIONUTC`, `convertSeptentrioGALIONO`, `convertSeptentrioGALCLOCK`.
  - Update buffers: `GpsNavBus`, `GalFNavBus`, `GpsIonBus`, `GalIonBus`, `GalGstGpsBus`.
  - Ensure thread safety (mutex/guard) consistent with NovAtel preprocessor patterns.

  Reference files to inspect for field mappings:
  - `irt_gnss_preprocessing/src/impl/novatel_oem7_preprocessor.cpp` (bus filling patterns, guards, publishers)
  - `irt_gnss_preprocessing/include/irt_gnss_preprocessing/impl/septentrio_sbf_preprocessor.h` (subscriber types, converter signatures)
  - `novatel_oem7_msgs/msg/{GPSEPHEM,GALFNAVEPHEMERIS,IONUTC,GALIONO,GALCLOCK}.msg` (field names expected by converters)
  - `septentrio_gnss_driver/msg/{gpsephem,galfnavephemeris,ionutc,galiono,galclock}.msg` (source fields from SBF)
  - SBF specs in manual: `driver_modification/septentrio_mosiac_h_manuals/mosaic_hardware_manual_v1.9.0.pdf-ocr.txt` (block sizes/IDs)

### Step 2 — Add MeasEpoch Trigger → Model Execution
- Files: `.../include/.../septentrio_sbf_preprocessor.h` and `.../src/impl/.../septentrio_sbf_preprocessor.cpp`.
- Actions:
  - Subscribe to `/measepoch` (and optional `/measepoch_aux`).
  - Map to `MeasurementEpochBus` (mirror NovAtel RANGE mapping: PRN, CN0, psr, adr, dopp, lock time, channel status).
  - Build model inputs using latest nav/iono/GGTO buffers; apply guards (`checkHaveEphem()` & flag checks).
  - Call `gnss_preprocessor_->step()`.

  Reference files/settings for MeasEpoch mapping:
  - `septentrio_gnss_driver/msg/measepoch.msg` (confirm field names: PRN, CN0, pseudorange, carrier phase, Doppler, locktime)
  - `irt_gnss_preprocessing/include/irt_gnss_preprocessing/gnss_preprocessor.h` (MeasurementEpochBus structure)
  - `irt_gnss_preprocessing/src/impl/novatel_oem7_preprocessor.cpp` (RANGE → MeasurementEpochBus mapping code)
  - Manual channel/tracking status SBFs for advanced mapping: `ChannelStatus`, `TrackingStatus`

### Step 3 — Publish Outputs
- File: `septentrio_sbf_preprocessor.cpp`.
- Actions:
  - Create publishers for `/gnss_obs_preprocessed`, `/LeastSquarePVT`, `/ls_ant_main_residuals`.
  - Map model outputs (`..._Y`) to messages (reuse NovAtel mappings).
  - Publish each step; log rates and field sanity.

### Step 4 — Param Tuning (YAML)
- File: `config/gnss_preprocessing_septentrio_test.yaml` (or equivalent).
- Actions:
  - `GNSSPreprocessor.nav_sync_queue_size: 20`.
  - `GNSSPreprocessor.msg_lower_bound: 3000000000–5000000000` (3–5 seconds).
  - Enable GPS+Galileo, `enable_ionospheric_correction: true`.
  - `ggto_sync_mode: 1` (set `0` for GPS-only fallback tests).

### Step 5 — Manual-Driven Enhancements (Driver)
- Files: `septentrio_gnss_driver/*`, `rover.yaml`.
- Actions:
  - Enable additional SBF outputs: ChannelStatus, TrackingStatus, DOP, ReceiverStatus, ReceiverTime.
  - Configure with `setSBFOutput` and confirm with `getSBFOutput`. Use `exeSBFOnce` for spot validation.
  - Wire RTCM passthrough (NTRIP/IP) to a ROS topic; buffer in preprocessor as `RTCM33L1E1Bus`.
  - Wire dual-antenna baseline/attitude and (optional) auxiliary observations.

  Concrete SBF blocks and IDs (verify in manual and driver):
  - Navigation:
    - GPS_NAV: Block ID 5891 (`/gpsephem`)
    - GAL_NAV (F/NAV): Block ID 4002 (`/galfnavephem`)
  - Ionosphere/Clock:
    - GPS_IONUTC: Block ID 5893 (`/gpsion`)
    - GAL_IONO: Block ID 4030 (`/galion`)
    - GAL_GST_GPS (GGTO): Block ID 4032 (`/galclock`)
  - Measurement/Quality (enable via driver config):
    - ChannelStatus: per-channel lock/CN0 flags (manual section)
    - TrackingStatus: per-signal tracking state
    - DOP: dilution of precision values
    - ReceiverStatus: overall health/status bits
    - ReceiverTime: UTC/leap seconds/time validity

  Driver files to modify/inspect:
  - `septentrio_gnss_driver/src/message_handler.cpp` (switch-case for SBF blocks; ensure cases for above blocks)
  - `septentrio_gnss_driver/include/.../message_handler.hpp` (SbfId enum includes 5891, 4002, 5893, 4030, 4032)
  - `septentrio_gnss_driver/params/rover.yaml` (publish.* flags and stream configuration)
  - `septentrio_gnss_driver/src/communication_core.cpp::configureRx()` (program output streams via setSBFOutput)
  - Manual commands: `setSBFOutput <Stream> <BlockName> <OnChange|Sec1|Sec10>`, `getSBFOutput`, `exeSBFOnce <BlockName>`

### Step 6 — Minimal NovAtel Compatibility (Optional)
- Files: bridge or driver publishers.
- Topics (only if necessary): `/novatel/oem7/gpsephem`, `/novatel/oem7/galFnavEphemeris`, `/novatel/oem7/ionutc`, `/novatel/oem7/galiono`, `/novatel/oem7/galclock`, `/novatel/oem7/range` (from `/measepoch`).
- Prefer reusing `novatel_oem7_msgs` to avoid new type definitions.

---

## 6. Configuration Checklist
- [ ] YAML: Increase ApproximateTime slop to 3–5s; queue size 20.
- [ ] YAML: Enable GPS & Galileo; `enable_ionospheric_correction: true`.
- [ ] YAML: Set `ggto_sync_mode: 1` (use `0` for GPS-only tests).
- [ ] Preprocessor: Enable dual-antenna flags when baseline/attitude present.
- [ ] Driver: Ensure `publish.measepoch`, `publish.pvtgeodetic`, and 5 nav topics are true.
- [ ] Driver: Add ChannelStatus, TrackingStatus, DOP, ReceiverStatus as needed.
- [ ] RTCM: Configure NTRIP/IP and topic forwarding if RTK/DD is desired.

Detailed driver settings (verify against manual):
- Stream configuration:
  - Navigation blocks: `OnChange` mode (do not force periodic)
  - Quality/status blocks: `Sec1` or `Sec10` (reasonable rates)
- Time settings:
  - Confirm UTC validity and leap seconds via `ReceiverTime` and status bits
- Dual-antenna:
  - Enable and publish `AttEuler`, `BaseVectorGeod`; ensure frame and units match preprocessor expectations

---

## 7. Testing Plan

### 7.1 Build & Run
```bash
# Build
cd /workspace/fgo_ws
colcon build --packages-select irt_gnss_preprocessing --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=OFF
source install/setup.bash

# Run preprocessor (example)
# NOTE: executable is `node_gnss_preprocessing` and the params file must target node name `GNSSPreProcessorStandaloneNode`.
ros2 run irt_gnss_preprocessing node_gnss_preprocessing --ros-args --params-file /workspace/fgo_ws/config/gnss_preprocessing_septentrio_test.yaml
```

### 7.2 Bag Validation
- Bag A (nav-rich): `/workspace/fgo_ws/src/gnssFGO/bags/nav_test_run`
```bash
ros2 bag play /workspace/fgo_ws/src/gnssFGO/bags/nav_test_run --clock --loop
ros2 topic echo /gpsephem --once
ros2 topic hz /galion
ros2 topic hz /gnss_obs_preprocessed
ros2 topic echo /gnss_obs_preprocessed --once
ros2 topic echo /galclock --once
ros2 topic echo /gpsion --once
```
- Bag B (broad topics): `/workspace/fgo_ws/src/gnssFGO/bags/rosbag2_2025_12_16-09_47_24`
```bash
ros2 bag play /workspace/fgo_ws/src/gnssFGO/bags/rosbag2_2025_12_16-09_47_24 --clock --loop
ros2 topic hz /measepoch
ros2 topic echo /pvtgeodetic --once
ros2 topic hz /gnss_obs_preprocessed
ros2 topic echo /basevectorgeod --once
ros2 topic echo /atteuler --once
```

### 7.3 RTK & Dual-Antenna Tests (Optional)
- RTCM source enabled (NTRIP/IP):
```bash
ros2 topic hz /rtcm_l1e1
ros2 topic echo /rtcm_l1e1 --once
```
- Dual-antenna:
```bash
ros2 topic echo /basevectorgeod --once
ros2 topic echo /atteuler --once
# Verify outputs if enabled
ros2 topic echo /LeastSquarePVT --once
ros2 topic hz /ls_ant_main_residuals
```

### 7.4 Acceptance Criteria
- Nav buses populated within seconds of bag start; `checkHaveEphem()` passes.
- `/gnss_obs_preprocessed` publishes at MeasEpoch cadence; non-zero satellite count; realistic CN0/psr.
- GPS-only fallback works (`ggto_sync_mode: 0`); Galileo merge works when GGTO present.
- No persistent “missing ephemeris” warnings after initial warm-up.
- Optional: RTCM/dual-antenna paths publish without blocking core single-antenna outputs.

---

## 8. Risks & Mitigations
- Sparse GPS nav → sync misses: expand slop (3–5s), raise queue size, use GPS-only fallback.
- Typesupport/ABI issues (pip/setuptools vs colcon): build with system Python (outside venv).
- MeasEpoch mapping mismatch: cross-check against NovAtel RANGE→MeasEpochBus mapping; spot-check `/gnss_obs_preprocessed` contents.
- GGTO/Iono gaps: gate usage via yaml flags; accept periods without corrections.
- Topic name drift across runs: always verify with `ros2 topic list`; adjust subscriptions accordingly.

---

## 9. Timeline & Milestones
- Day 0 (today): Wire buses, add `/measepoch` trigger, publish outputs — 2–4 hours.
- Day 1: Validate with both bags; adjust slop/queues; finalize yaml gates.
- Day 2+: Optional enhancements — RTCM, dual-antenna wiring, quality/integrity expansions; targeted NovAtel topic compatibility if needed.

---

## 10. References
- `docs/SEPT_VS_NOVATEL_V2.md` — updated status and detailed comparisons.
- `irt_gnss_preprocessing/src/impl/novatel_oem7_preprocessor.cpp` — mapping reference for buses and outputs.
- `irt_gnss_preprocessing/src/impl/septentrio_sbf_preprocessor.cpp` — current subscribers and converters.
- Septentrio mosaic-H manual (SBF blocks, configuration commands): `driver_modification/septentrio_mosiac_h_manuals/mosaic_hardware_manual_v1.9.0.pdf-ocr.txt`.
  - Useful manual sections:
    - SBF Block Reference: block IDs, sizes, fields (NAV, IONO, GGTO, Channel/Tracking/DOP/Status)
    - Receiver Configuration Commands: `setSBFOutput`, `getSBFOutput`, `exeSBFOnce`
    - Time/UTC/Leap Second handling and validity bits

## 11. Update Log
- Dec 16, 2025 (Evening): Root cause analysis of "Galileo enabled but no ephemeris yet" warnings completed.
  - **Finding**: Active code path is single-antenna (USE_DUAL_ANTENNA=OFF), but guard instrumentation was placed only in dual-antenna callback (lines 389–500).
  - **Impact**: Guard debug log not visible; actual guard condition unclear.
  - **Next**: Add debug log to single-antenna guard (line ~684), inspect parameter loading, verify why guard fires despite config showing Galileo disabled.
  - **See**: `WORK_LOG_DEC16_2025.md` for full technical analysis.

- Dec 16, 2025 (Afternoon): Implemented Galileo SVID normalization and guard instrumentation.
  - Added Galileo ephemeris callback SVID mapping: SBF 71–106 → ROS PRN 1–36.
  - One-time debug log added to dual-antenna guard (later found to be wrong code path).
  - Rebuild successful; issue: guard log not appearing in runtime output.

- Dec 16, 2025 (Morning): Started Septentrio Galileo ephemeris guard warning investigation.
  - Verified topic format correct via `ros2 topic echo`.
  - Confirmed topics active: `/gpsephem`, `/gpsion`, `/galfnavephem`, `/galion`, `/galclock`.

- Dec 16, 2025: Expanded with file references, SBF block IDs, driver settings, manual command references, and additional test commands.
- Dec 16, 2025: Fixed build warning in `irt_gnss_preprocessing/src/impl/septentrio_sbf_preprocessor.cpp` by moving `#if USE_DUAL_ANTENNA` out of the `RCLCPP_INFO` argument list; rebuild confirmed.
- Dec 16, 2025: Implemented single-antenna `MeasEpoch -> step() -> publish` wiring in `SeptentrioSBFPreProcessor::onSeptentrioMeasEpochMsgCb(...)` (guards, model execution, `/gnss_obs_preprocessed` + LS outputs).
- Dec 16, 2025: Fixed `config/gnss_preprocessing_septentrio_test.yaml` node key to `GNSSPreProcessorStandaloneNode` so required statically-typed parameters (e.g., `GNSSPreprocessor.NLOSCSVFilePath`) are applied.

---

## 12. Action Items (Checklist) — UPDATED Dec 16, 2025 Evening

### Phase 1: Diagnostics (Today/Tomorrow)
- [ ] **Add debug log to single-antenna guard** (line ~684 in septentrio_sbf_preprocessor.cpp)
  - Print actual `gal_enabled` and `have_ephem` values before warning.
  - Restart node and capture logs to `/tmp/preprocessing.log`.
  - **Goal**: Determine if guard state matches config or if parameters are being overridden.

- [ ] **Inspect parameter loading** (`gnss_preprocessor.h` lines 630–640)
  - Add debug print after `enable_gnss_merge_` and Galileo enable assignment.
  - Verify both read correctly from yaml and stay `false` throughout init.

- [ ] **Review RosParameter defaults** (`ros_parameter.h`)
  - Check default value for Galileo enable if config key is missing.
  - Ensure defaults are safe (false for Galileo, false for merge).

### Phase 2: Fix Guard (Once Root Cause Known)
- [ ] Disable warning if guard is incorrectly triggered (Option A: gate guard logic).
- [ ] OR trace and fix parameter override if that's the issue (Option B: fix loading).

### Phase 3: Full Single-Antenna Path (After Guard Resolved)
- [ ] Move guard debug log from dual-antenna callback to single-antenna path.
- [ ] Verify preprocessing runs without guards for extended period (5+ minutes).
- [ ] Validate `/gnss_obs_preprocessed` output.

### Phase 4: Dual-Antenna Support (Optional, Lower Priority)
- [ ] Confirm `/measepoch_aux` is publishing at same rate as `/measepoch`.
- [ ] Re-enable `USE_DUAL_ANTENNA` if both topics are synchronized.
- [ ] Verify message_filters synchronizer receives both topics.

### Phase 5: SBF Output Verification (Confirm All Blocks Present)
- [ ] Confirm Septentrio driver is outputting all required SBF blocks:
  - `GPS_NAV` (5891)
  - `GAL_FNAV` (4002)
  - `GPS_IONUTC` (5893)
  - `GAL_IONO` (4030)
  - `GAL_GST_GPS` (4032)
- [ ] Manual verification command (on Septentrio device):
  ```bash
  setSBFOutput+GPS_NAV,OnChange,UART1
  getSBFOutput+GPS_NAV
  ```

### Phase 6: Full System Integration
- [ ] Collect multi-minute bag with all topics active.
- [ ] Replay bag and verify preprocessing runs end-to-end without repeated guard warnings.
- [ ] Validate `/gnss_obs_preprocessed` and LS outputs are published.

---

## 13. References
- `docs/SEPT_VS_NOVATEL_V2.md` — updated status and detailed comparisons.
- `irt_gnss_preprocessing/src/impl/novatel_oem7_preprocessor.cpp` — mapping reference for buses and outputs.
- `irt_gnss_preprocessing/src/impl/septentrio_sbf_preprocessor.cpp` — current subscribers and converters.
- `WORK_LOG_DEC16_2025.md` — full technical session log including root cause analysis.
- Septentrio mosaic-H manual (SBF blocks, configuration commands): `driver_modification/septentrio_mosiac_h_manuals/mosaic_hardware_manual_v1.9.0.pdf-ocr.txt`.
  - Useful manual sections:
    - SBF Block Reference: block IDs, sizes, fields (NAV, IONO, GGTO, Channel/Tracking/DOP/Status)
    - Receiver Configuration Commands: `setSBFOutput`, `getSBFOutput`, `exeSBFOnce`
    - Time/UTC/Leap Second handling and validity bits

