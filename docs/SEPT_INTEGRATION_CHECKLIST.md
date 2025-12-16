# Septentrio Preprocessing Integration - Practical Checklist

**Date**: December 10, 2025  
**Purpose**: Clear action items separated by **ALREADY DONE** vs. **YOU MUST DO**

---

## Status Overview

| Category | State | Details |
|----------|-------|---------|
| **Code Structure** | ✅ Exists | `septentrio_preprocessor.h/cpp` files are present |
| **Preprocessing Logic** | ✅ Exists | `step()` function callable; guards in place |
| **PVT Output** | ✅ Works | `/PVT` topic published from receiver |
| **Ephemeris Input** | ❌ **MISSING** | No GPS/GAL ephemeris source connected |
| **Iono/GGTO Input** | ❌ **MISSING** | No ionosphere or clock data source |
| **RTCM Input** | ❌ **MISSING** | RTK corrections not wired |
| **Dual-Antenna Wiring** | ⚠️ Partial | Buffered but not fed to model |
| **Output Publishers** | ❌ **MISSING** | `/gnss_obs_preprocessed`, `/LeastSquarePVT`, residuals not published |

---

## Phase 1: Enable Ephemeris Delivery (BLOCKER - DO THIS FIRST)

This is the **critical path**. Preprocessing will not execute until nav data arrives.

### Option A: Tap Septentrio Driver's Internal SBF Data (Recommended if firmware supports it)

**Goal**: Extend driver to expose GPS/GAL ephemeris as ROS2 topics

**Steps**:

1. **Verify SBF block support** (30 min)
   - [ ] Check Septentrio firmware version: `rx_version` command in ROSaic
   - [ ] Confirm `GPSNav` (block 4027) and `GALNav` (block 4028) are available
   - [ ] Check SBF documentation or ROSaic source code for iono/GGTO blocks
   - **File**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/`

2. **Create ROS2 message types** (1-2 hours)
   - [ ] Define `GPS_Ephemeris.msg` with fields: `PRN`, `WNc`, `TOC`, `a0`, `a1`, `a2`, `Crs`, `Crc`, `Cn0`, `Cus`, `Cuc`, etc.
   - [ ] Define `GAL_Ephemeris.msg` with similar fields (IODnav, af0, af1, etc.)
   - [ ] Define `Ionosphere.msg` with `ai0`, `ai1`, `ai2`, `regn`, `tot`, `wot`
   - [ ] Define `GGTO.msg` (Galileo-GPS time offset) with `a0`, `a1`, `wn0`, `wn1`
   - [ ] Create `msg/` directory in `septentrio_gnss_driver` if not present
   - [ ] Add `add_message_files()` and `rosidl_generate_interfaces()` to `CMakeLists.txt`
   - **Files to create**: 
     - `src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/msg/GPSEphemeris.msg`
     - `src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/msg/GALEphemeris.msg`
     - `src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/msg/Ionosphere.msg`
     - `src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/msg/GGTO.msg`

3. **Parse SBF blocks in driver** (2-4 hours)
   - [ ] Open `septentrio_gnss_driver/src/communication/message_handler.cpp` (or equivalent)
   - [ ] Locate the switch-case for SBF block IDs (look for `case 4001:` or similar)
   - [ ] Add case `4027:` → parse GPS ephemeris fields → create `GPS_Ephemeris` msg → publish to `/gps_ephemeris`
   - [ ] Add case `4028:` → parse GAL ephemeris → create `GAL_Ephemeris` msg → publish to `/gal_ephemeris`
   - [ ] Add cases for iono blocks (SBF IDs TBD based on firmware) → `/gps_iono`, `/gal_iono`
   - [ ] Add case for GGTO block → `/ggto`
   - [ ] Reference driver README section: "Adding New SBF Blocks"
   - **File**: `src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/src/communication/message_handler.cpp`

4. **Add publish parameters to driver config** (30 min)
   - [ ] Open `rover.yaml` (driver config)
   - [ ] Add publish flags: `publish_gps_ephemeris: true`, `publish_gal_ephemeris: true`, `publish_iono: true`, `publish_ggto: true`
   - [ ] In driver code, gate each publisher with corresponding param (e.g., `if (publish_gps_ephemeris_) { pub_gps_ephem_.publish(...); }`)
   - **File**: `src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/config/rover.yaml`

5. **Configure Rx to output nav blocks** (30 min)
   - [ ] In driver's `configureRx()` or `communication_core.cpp`, add setup command for each SBF block
   - [ ] Example: Send `setDataInOut,COM1,+GpsNav` (or ROSaic equivalent) to request GPSNav on COM1
   - [ ] Set update rate: 1 Hz (low overhead, sufficient for preprocessing)
   - [ ] Test that receiver acknowledges and outputs blocks
   - **File**: `src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/src/communication/communication_core.cpp` (or init method)

6. **Build and test driver** (30 min)
   - [ ] Run `colcon build --packages-select septentrio_gnss_driver`
   - [ ] Launch driver and verify new topics appear: `ros2 topic list | grep -E 'ephemeris|iono|ggto'`
   - [ ] Inspect message content: `ros2 topic echo /gps_ephemeris` (should see PRN, WNc, coefficients)
   - [ ] Verify data arrives at ~1 Hz (loose update)

**Fallback if driver extension is too complex**: Go to **Option B** below.

---

### Option B: External Ephemeris Provider (Faster to prototype)

**Goal**: Create a separate ROS2 node that reads BRDC files and publishes ephemeris

**Steps**:

1. **Create ephemeris provider package** (1-2 hours)
   - [ ] `ros2 pkg create --build-type ament_cmake gnss_ephemeris_provider`
   - [ ] Create `src/ephemeris_provider_node.cpp`
   - [ ] Create `config/ephemeris_provider.yaml` with paths to BRDC files
   - **Directory**: `src/gnssFGO/gnss_ephemeris_provider/`

2. **Implement BRDC parser** (4-6 hours)
   - [ ] Use existing library (e.g., GPSTk, RTKLIB, or hand-parse BRDC format)
   - [ ] Parse BRDC file → extract GPS ephemeris records
   - [ ] Parse GAL NAV file → extract Galileo ephemeris records
   - [ ] Load into circular buffers (indexed by PRN and time)
   - [ ] Provide lookup function: `EphemerisRecord* getEphemeris(int prn, double time, int system)`

3. **Publish as ROS2 topics** (1-2 hours)
   - [ ] Create publishers for `/gps_ephemeris`, `/gal_ephemeris` (use same msg format as Option A)
   - [ ] On each MeasEpoch arrival, lookup current ephemeris for all observed PRNs
   - [ ] Publish at message rate (triggered by receiver, not periodic)

4. **Test** (30 min)
   - [ ] Point to valid BRDC file in config
   - [ ] Run provider node
   - [ ] Verify topics appear and data flows
   - [ ] Inspect with `ros2 topic echo /gps_ephemeris`

**Timeline**: ~1 week with library choice and integration.

---

## Phase 2: Wire Ephemeris Inputs to Preprocessor (3-4 hours)

Once ephemeris topics exist (from Phase 1):

1. **Add ephemeris subscribers** (1 hour)
   - [ ] Open `septentrio_preprocessor.cpp`
   - [ ] Add member variables:
     ```cpp
     rclcpp::Subscription<your_msgs::GPSEphemeris>::SharedPtr sub_gps_ephem_;
     rclcpp::Subscription<your_msgs::GALEphemeris>::SharedPtr sub_gal_ephem_;
     std::deque<your_msgs::GPSEphemeris> gps_ephem_buffer_;
     std::deque<your_msgs::GALEphemeris> gal_ephem_buffer_;
     ```
   - [ ] In constructor, create subscriptions:
     ```cpp
     sub_gps_ephem_ = create_subscription<your_msgs::GPSEphemeris>(
         "/gps_ephemeris", 10,
         std::bind(&SeptentrioPreProcessor::onGpsEphemeris, this, std::placeholders::_1));
     ```
   - [ ] Implement callback to buffer: `onGpsEphemeris()`, `onGalEphemeris()`
   - **File**: `src/gnssFGO/online_fgo/src/impl/septentrio_preprocessor.cpp` + header

2. **Fill nav buffers in converter** (1.5 hours)
   - [ ] Locate the `convertToGpsNavBus()` function (or similar) in preprocessor
   - [ ] Pull latest ephemeris from buffer for each satellite
   - [ ] Map message fields → `GpsNavBus` structure (reference NovAtel converter for field mapping)
   - [ ] Do same for GAL with `convertToGalNavBus()`
   - **File**: `src/gnssFGO/online_fgo/src/impl/septentrio_preprocessor.cpp`

3. **Wire ionosphere & GGTO** (1.5 hours)
   - [ ] Similar process: add subscribers, buffers, converters for iono and GGTO
   - [ ] Populate `GpsIonBus`, `GalIonBus`, `GalGstGpsBus` (GGTO)
   - [ ] Keep guards: if iono missing, preprocessing can still run (optional in most models)
   - [ ] If GGTO missing, disable GPS/GAL merge (set `EnableGNSSMerge = false`)

4. **Update `checkHaveEphem()` guard** (30 min)
   - [ ] Open function in preprocessor
   - [ ] Change condition from `if (gps_ephem_buffer_.empty())` → should now return `true` once ephemeris arrives
   - [ ] Log when guard passes for first time: `RCLCPP_INFO(get_logger(), "Ephemeris available, starting preprocessing")`

5. **Test wiring** (30 min)
   - [ ] Build: `colcon build --packages-select online_fgo`
   - [ ] Launch driver + ephemeris provider (or extended driver) + preprocessor
   - [ ] Check logs: should see "Ephemeris available" message
   - [ ] Verify `/gnss_obs_preprocessed` topic appears (next step publishes it)

---

## Phase 3: Publish Preprocessed Outputs (2-3 hours)

Once `step()` executes successfully:

1. **Create output publishers** (1 hour)
   - [ ] Add member publishers in `septentrio_preprocessor.h`:
     ```cpp
     rclcpp::Publisher<gnssraw_msgs::GNSSObsPreProcessed>::SharedPtr pub_gnss_obs_preprocessed_;
     rclcpp::Publisher<gnssraw_msgs::PVTLS>::SharedPtr pub_ls_pvt_;
     rclcpp::Publisher<gnssraw_msgs::Residuals>::SharedPtr pub_residuals_;
     ```
   - [ ] In constructor, create publishers on relevant topics
   - **File**: `src/gnssFGO/online_fgo/src/impl/septentrio_preprocessor.h`

2. **Fill and publish after `step()`** (1-2 hours)
   - [ ] After successful `step()` call, extract outputs from Simulink model
   - [ ] Populate message fields (satellite counts, observations, quality metrics)
   - [ ] Publish: `pub_gnss_obs_preprocessed_->publish(obs_msg);`
   - [ ] Do same for LS PVT and residuals
   - [ ] Reference NovAtel preprocessor for exact field mappings
   - **File**: `src/gnssFGO/online_fgo/src/impl/septentrio_preprocessor.cpp`

3. **Test output** (30 min)
   - [ ] Launch full pipeline
   - [ ] Check topic: `ros2 topic echo /gnss_obs_preprocessed` (should show observations)
   - [ ] Verify message is non-empty and arrives at ~10-20 Hz

---

## Phase 4: Wire Dual-Antenna Data (Optional but Recommended) (1-2 hours)

If hardware has dual-antenna:

1. **Buffer baseline and attitude** (30 min)
   - [ ] Already done in preprocessor (baseline_buffer_, attitude_buffer_)
   - [ ] Verify they're being filled from `/basevectorgeod` and `/atteuler`

2. **Wire to preprocessing model** (1 hour)
   - [ ] In preprocessing input assembly, populate baseline & attitude fields
   - [ ] Set `EnableDualAntennaDD = true` in model inputs
   - [ ] Ensure Aux MeasEpoch is synchronized
   - **File**: `src/gnssFGO/online_fgo/src/impl/septentrio_preprocessor.cpp`

3. **Test** (30 min)
   - [ ] Verify dual-antenna factors appear in preprocessed output
   - [ ] Check heading is reasonable (should match receiver's solution)

---

## Phase 5: Wire RTCM RTK Corrections (Optional) (1-2 hours)

If base station / NTRIP corrections are available:

1. **Subscribe to RTCM** (30 min)
   - [ ] Add RTCM subscriber (already in NovAtel version, reference it)
   - [ ] Buffer incoming RTCM messages
   - **File**: `src/gnssFGO/online_fgo/src/impl/septentrio_preprocessor.cpp`

2. **Wire to model** (30 min)
   - [ ] Populate `RTCM33L1E1Bus` from buffer
   - [ ] Model will gate DD processing: if empty, use single-point positioning

3. **Test** (1 hour)
   - [ ] Launch with RTCM source available
   - [ ] Verify preprocessing still works (with or without RTCM)

---

## Quick Reference: Files to Modify/Create

### Create (New)
- [ ] `msg/GPSEphemeris.msg` (or reuse from driver if extended)
- [ ] `msg/GALEphemeris.msg`
- [ ] `msg/Ionosphere.msg`
- [ ] `msg/GGTO.msg`
- [ ] `gnss_ephemeris_provider/` package (if Option B)

### Modify (Existing)
- [ ] `online_fgo/src/impl/septentrio_preprocessor.h` → add subscribers, buffers, publishers
- [ ] `online_fgo/src/impl/septentrio_preprocessor.cpp` → implement callbacks, converters, output publishing
- [ ] `septentrio_gnss_driver/CMakeLists.txt` → add message generation (if Option A)
- [ ] `septentrio_gnss_driver/src/communication/message_handler.cpp` → parse SBF blocks (if Option A)
- [ ] `septentrio_gnss_driver/config/rover.yaml` → add publish flags & Rx setup (if Option A)

---

## Build & Test Sequence

```bash
# Phase 1: Build ephemeris source (Option A or B)
colcon build --packages-select septentrio_gnss_driver  # (if Option A)
# OR
colcon build --packages-select gnss_ephemeris_provider  # (if Option B)

# Phase 2-3: Build preprocessor
colcon build --packages-select online_fgo

# Launch integration test
source /workspace/fgo_ws/install/setup.bash
ros2 launch online_fgo septentrio_fgo.launch.py
```

**Expected success criteria**:
- ✅ `/gps_ephemeris` topic exists and publishes data
- ✅ `/gal_ephemeris` topic exists and publishes data
- ✅ Preprocessor logs show "Ephemeris available, starting preprocessing"
- ✅ `/gnss_obs_preprocessed` topic exists with non-empty observations
- ✅ Accuracy within 2m standalone, <10cm RTK (if available)

---

## Notes

- **Ephemeris choice** is the critical path; complete Phase 1 before anything else.
- **Phases 2-3** unlock the preprocessing pipeline and must be done together.
- **Phases 4-5** are enhancements; skip if time-constrained.
- All file paths are relative to `/workspace/fgo_ws/`.

