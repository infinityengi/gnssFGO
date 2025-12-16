# Septentrio Integration - Fresh Start Quick Reference Checklist

**Status**: Fresh Start (0% integration)  
**Target**: 100% integration with FGO  
**Timeline**: 6 weeks with full-time effort  

---

## Current State Summary

✅ **Working Now**:
- Septentrio driver built and functional
- Publishes: MeasEpoch, PVTGeodetic, AttEuler, BaseVectorGeod
- Dual-antenna capable hardware compatible

❌ **Missing (Blockers)**:
- No ephemeris source (GPS/GAL nav, iono, GGTO)
- No preprocessing integration code
- No FGO factor generation from Septentrio

---

## Phase 0: Foundation (Week 1) — IMMEDIATE ACTION

### 0.1 Review Driver Capabilities
```bash
# Launch driver and inspect current topics
ros2 launch septentrio_gnss_driver rover.launch.py
ros2 topic list | grep -E 'septentrio|measepoch|pvt'
ros2 topic echo /measepoch --max-count 1
ros2 topic echo /pvtgeodetic --max-count 1
```
**Action**: Confirm observations and PVT data look correct  
**Time**: 1 hour  
**Status**: [ ] Not started

### 0.2 Examine Driver Code Structure
- [ ] Read: `septentrio_gnss_driver/README.md` (sections on "Adding New SBF Blocks")
- [ ] Read: `septentrio_gnss_driver/src/communication/message_handler.cpp`
- [ ] Look for: SBF block ID handling pattern
- [ ] Document: How to add new blocks (4027 GPS ephem, 4028 GAL ephem, etc.)  
**Time**: 2-4 hours  
**Status**: [ ] Not started

### 0.3 Gather Sample Data
- **If Option B (external provider)**: Download BRDC file from IGS
  ```bash
  # Example IGS file
  wget https://cddis.nasa.gov/archive/gnss/data/daily/2025/brdc/brdc3040.25n
  ```
- **If Option A (driver extension)**: Dump SBF file from receiver containing nav blocks  
**Time**: 1-2 hours  
**Status**: [ ] Not started

### 0.4 Create Message Definitions
Create in appropriate package:
```bash
# Create msg files
msg/GPSEPHEM.msg
msg/GALFNAVEPHEMERIS.msg
msg/IONUTC.msg
msg/GALIONO.msg
msg/GALCLOCK.msg
```
**Reference**: `novatel_oem7_msgs/msg/` for field structure  
**Time**: 0 hours (reuse)  
**Status**: [x] Complete (all required messages already exist in novatel_oem7_msgs/msg/ and will be reused; no new .msg files needed for SBF block support)

### 0.5 ✅ DECISION POINT: Ephemeris Source

**Option A: Extend Driver** (recommended if you have receiver)
- Pros: Real-time, seamless, single source
- Cons: Driver modification, firmware-dependent
- Timeline: 1 week

**Option B: External Provider** (recommended for fast prototype)
- Pros: Faster, offline-testable, no driver changes
- Cons: File dependency, external node
- Timeline: 1 week

**Recommendation**: Start with **Option B**, implement Option A later

**Decision**: [ ] Option A  [ ] Option B  
**Date**: ___________  
**Rationale**: _________________________________________________________________

---

## Phase 1: Ephemeris Delivery (Week 2) — PATH A OR B

### If Option A: Extend Driver

**1.1 Check firmware version**
```bash
# Via ROSaic web UI or command
rx_version
# Check: Does firmware support GPSNav (4027), GALNav (4028)?
```
**Status**: [ ] Not started

**1.2 Add ROS message types to driver**
```bash
cd septentrio_gnss_driver
# Add to msg/CMakeLists.txt
# Create msg/GPSEphemeris.msg, etc.
colcon build --packages-select septentrio_gnss_driver
```
**Status**: [ ] Not started

**1.3 Implement SBF parsers**
- [ ] File: `src/communication/message_handler.cpp`
- [ ] Add case 4027: parse GPSNav → publish `/gps_ephemeris`
- [ ] Add case 4028: parse GALNav → publish `/gal_ephemeris`
- [ ] Add iono block cases
- [ ] Add GGTO block case
**Status**: [ ] Not started

**1.4 Configure receiver**
- [ ] File: `config/rover.yaml`
- [ ] Enable: `publish_gps_ephemeris: true`, etc.
- [ ] Configure: receiver output blocks
**Status**: [ ] Not started

**1.5 Test**
```bash
colcon build --packages-select septentrio_gnss_driver
ros2 launch septentrio_gnss_driver rover.launch.py
ros2 topic list | grep ephemeris  # Should see 5 topics
ros2 topic echo /gps_ephemeris --max-count 1
```
**Status**: [ ] Not started

---

### If Option B: External Provider

**1.1 Create provider package**
```bash
cd /workspace/fgo_ws/src/gnssFGO
ros2 pkg create --build-type ament_cmake gnss_ephemeris_provider
```
**Status**: [ ] Not started

**1.2 Choose parser library**
- [ ] Recommend: **GPSTk** (GPS Toolkit)
- [ ] Install: `sudo apt install gpstk` (if available)
**Status**: [ ] Not started

**1.3 Implement provider node**
- [ ] File: `src/ephemeris_provider_node.cpp`
- [ ] Read BRDC file (GPS ephemeris)
- [ ] Read RINEX NAV file (Galileo ephemeris)
- [ ] Buffer by PRN and time
- [ ] On each MeasEpoch, lookup current ephemeris
- [ ] Publish to `/gps_ephemeris`, `/gal_ephemeris`, etc.
**Status**: [ ] Not started

**1.4 Test**
```bash
colcon build --packages-select gnss_ephemeris_provider
ros2 run gnss_ephemeris_provider ephemeris_provider_node \
    --ros-args -p brdc_file:=/path/to/brdc3040.25n
ros2 topic list | grep ephemeris
```
**Status**: [ ] Not started

**Phase 1 Complete**: [ ] Yes (all ephemeris topics active and publishing)

---

## Phase 2: Preprocessing Integration (Weeks 3-4) — CORE WORK

### 2.1 Create Septentrio Preprocessor Package
```bash
cd /workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing
mkdir -p septentrio_preprocessor/{include,src,config,launch}
```
**Status**: [ ] Not started

### 2.2 Define Preprocessor Interface
- [ ] Header: `include/septentrio_preprocessor.h`
- [ ] Subscribers: MeasEpoch, PVTGeodetic, ephemeris, iono, GGTO, dual-antenna (optional)
- [ ] Publishers: `/gnss_obs_preprocessed`, `/ls_pvt`, `/ls_residuals`
**Status**: [ ] Not started

### 2.3 Implement Converters
```cpp
// Convert MeasEpoch to GnssRaw format
void convertMeasEpochToGnssRaw(
    const septentrio_gnss_driver::msg::MeasEpoch& msg,
    gnssraw_msgs::GnssRawMsg& output);

// Buffer ephemeris
void onGpsEphemeris(const gps_ephemeris_msg& msg);
void onGalEphemeris(const gal_ephemeris_msg& msg);
```
**Status**: [ ] Not started

### 2.4 Call Preprocessing Model
- [ ] Main loop: onMeasEpoch() callback
- [ ] Convert observations
- [ ] Check data availability (checkHaveEphem())
- [ ] Assemble preprocessing input bus
- [ ] Call `gnss_preprocessor_->step()`
- [ ] Publish output
**Status**: [ ] Not started

### 2.5 Test & Validate
```bash
colcon build --packages-select septentrio_preprocessor
ros2 launch septentrio_preprocessor septentrio_preproc.launch.py
ros2 topic echo /gnss_obs_preprocessed --max-count 1
# Check: satellite count > 0, observations valid
```
**Status**: [ ] Not started

**Phase 2 Complete**: [ ] Yes (preprocessor running, output published)

---

## Phase 3: FGO Integration (Week 5) — FINAL WIRING

### 3.1 Modify FGO Main Node
- [ ] File: `online_fgo/src/gnss_fgo/GNSSFGOBoreas.cpp`
- [ ] Add: subscriber to `/gnss_obs_preprocessed`
- [ ] Logic: buffer preprocessed observations
- [ ] Trigger: factor generation on new observations
**Status**: [ ] Not started

### 3.2 Enable Factor Types
- [ ] Enable GPS/GAL single-point factors
- [ ] Enable dual-antenna (DD) factors if available
- [ ] Enable RTK/DD factors if RTCM available
- [ ] Set feature flags in config
**Status**: [ ] Not started

### 3.3 Test Full Pipeline
```bash
ros2 launch online_fgo gnssfgo_septentrio.launch.py
# Monitor: /fgo_pose, /fgo_covariance topics
# Check: factors generated, solver converging
```
**Status**: [ ] Not started

**Phase 3 Complete**: [ ] Yes (FGO factors generated, solution stable)

---

## Phase 4: Validation (Weeks 6-7) — VERIFICATION

### 4.1 Unit Tests
- [ ] MeasEpoch → GnssRaw converter (known input/output)
- [ ] Ephemeris parser (BRDC or SBF dump)
- [ ] Preprocessing calls
**Status**: [ ] Not started

### 4.2 Live System Test
```bash
# Setup receiver at known location (roof, control point)
# Run 30+ minutes, record output
ros2 bag record -a

# Post-process:
# - Compare FGO position to truth
# - Target: < 2m RMS (standalone), < 10cm (RTK)
```
**Status**: [ ] Not started

### 4.3 Regression Test
```bash
# Replay recorded bag
ros2 bag play session.db3
# Re-run pipeline
# Verify: outputs reproducible
```
**Status**: [ ] Not started

### 4.4 Documentation
- [ ] Launch files for Septentrio
- [ ] Config examples
- [ ] README with setup instructions
- [ ] Known limitations
- [ ] Tuning parameters
**Status**: [ ] Not started

**Phase 4 Complete**: [ ] Yes (all tests passing, documented)

---

## Success Criteria Checklist

### Phase 0 ✅
- [ ] Ephemeris source strategy decided
- [ ] Message definitions created (.msg files in repo)
- [ ] Driver understanding documented
- [ ] Sample data obtained

### Phase 1 ✅
- [ ] Ephemeris topics active (`/gps_ephemeris`, `/gal_ephemeris`, `/iono`, `/ggto`)
- [ ] Messages validated (fields populated, non-zero)
- [ ] Data rate stable (1+ Hz)
- [ ] No build errors

### Phase 2 ✅
- [ ] Preprocessor package builds cleanly
- [ ] All subscribers active and receiving data
- [ ] `/gnss_obs_preprocessed` published at 10+ Hz
- [ ] Message satellite count > 0
- [ ] No early returns on data availability checks

### Phase 3 ✅
- [ ] FGO node accepts preprocessed input without errors
- [ ] Factor generation runs every epoch
- [ ] Solver converges smoothly
- [ ] `/fgo_pose` and `/fgo_covariance` published at consistent rate

### Phase 4 ✅
- [ ] Standalone accuracy: < 2m RMS
- [ ] RTK accuracy: < 10cm RMS (if available)
- [ ] All unit tests pass
- [ ] Regression tests show reproducible outputs
- [ ] Documentation updated and reviewed

---

## Build & Test Command Reference

### Full Build Sequence
```bash
source /opt/ros/humble/setup.bash
cd /workspace/fgo_ws

# Phase 1: Ephemeris
colcon build --packages-select septentrio_gnss_driver         # If Option A
# OR
colcon build --packages-select gnss_ephemeris_provider        # If Option B

# Phase 2: Preprocessor
colcon build --packages-select septentrio_preprocessor

# Phase 3: FGO
colcon build --packages-select online_fgo

# Everything
colcon build --symlink-install
```

### Full Pipeline Launch
```bash
# Terminal 1: Ephemeris + Driver
ros2 launch septentrio_gnss_driver rover.launch.py
# + ephemeris provider (if Option B)

# Terminal 2: Preprocessor
ros2 launch septentrio_preprocessor septentrio_preproc.launch.py

# Terminal 3: FGO
ros2 launch online_fgo gnssfgo_septentrio.launch.py

# Terminal 4: Monitor
ros2 topic list
rqt_graph
```

### Key Topics to Monitor
```bash
ros2 topic echo /measepoch --max-count 1
ros2 topic echo /gps_ephemeris --max-count 1
ros2 topic echo /gnss_obs_preprocessed --max-count 1
ros2 topic echo /fgo_pose --max-count 1
```

---

## Weekly Progress Tracking

| Week | Phase | Target | Completed | Notes |
|------|-------|--------|-----------|-------|
| 1 | 0 | Foundation | [ ] | Ephemeris decision, messages |
| 2 | 1 | Ephemeris | [ ] | Topics active, data valid |
| 3-4 | 2 | Preprocessing | [ ] | Node built, output published |
| 5 | 3 | FGO Integration | [ ] | Factors generated, solution |
| 6-7 | 4 | Validation | [ ] | Tests pass, accuracy achieved |

---

## Key Files to Create/Modify

### Create (New)
- `/irt_gnss_preprocessing/septentrio_preprocessor/` ← Main work
- `/gnss_ephemeris_provider/` ← If Option B
- `msg/GPSEphemeris.msg`, `msg/GALEphemeris.msg`, etc.

### Modify (Existing)
- `septentrio_gnss_driver/` ← Only if Option A
- `online_fgo/src/gnss_fgo/GNSSFGOBoreas.cpp` ← Add subscribers (Phase 3)

### Reference (Read-Only)
- `SEPTENTRIO_INTEGRATION_FRESH_START.md` ← Comprehensive plan
- `septentrio_gnss_driver/README.md` ← Driver documentation

---

## Troubleshooting

| Problem | Likely Cause | Solution |
|---------|--------------|----------|
| No `/measepoch` data | Receiver not streaming | Check driver connection, config |
| Ephemeris topics empty | Ephemeris source not running | Launch provider, check config |
| Preprocessor exits early | Missing ephemeris | Verify checkHaveEphem() passes |
| `/gnss_obs_preprocessed` has 0 sats | Converter issue | Check MeasEpoch → GnssRaw mapping |
| FGO not generating factors | Wrong message format | Inspect GnssRaw field alignment |
| Solution unstable | Covariance issue | Check preprocessing output quality |

---

**Last Updated**: 2025-12-10  
**Version**: 1.0  
**Status**: Ready for Phase 0 Kickoff

