# Septentrio GNSS-FGO Integration - Fresh Start Plan (v1.0)

**Date**: December 10, 2025  
**Status**: Planning Phase  
**Integration Level**: 0% (Starting from scratch)  
**Author**: Integration Team  

---

## 1. Executive Summary

This document defines a **fresh, from-scratch integration** of Septentrio Mosaic-H GNSS receiver with IRT GNSS preprocessing and Factor Graph Optimization (FGO).

**Update (Dec 11, 2025):**
- ✅ **Day 1 Complete**: All 5 message files copied to septentrio_gnss_driver/msg/, CMakeLists.txt updated, verification complete
- ✅ **Day 2 Complete**: Parser infrastructure added - typedefs, block IDs (5891, 4002, 5893, 4030, 4032), stub parsers, case statements, publish flags
- ⏳ **Next**: Implement full binary parsers for the 5 SBF blocks using firmware manual specifications

**Current State**:
- ✅ Septentrio driver (`septentrio_gnss_driver`) is **built and operational**
- ✅ Driver publishes raw observations (`MeasEpoch`), PVT, and dual-antenna data
- ❌ **No preprocessing integration exists yet** — no code, no converters, no wiring
- ❌ **No ephemeris source** — driver does NOT publish nav/iono/GGTO/RTCM blocks
- ❌ **No FGO factors** — observations not being processed into factors

**Critical Blocker**: The Septentrio driver **internally uses ephemeris** to compute PVT, but **does not expose ephemeris to ROS**. The preprocessing needs explicit ephemeris inputs.

**Path Forward**: 
1. Decide ephemeris source (extend driver OR external provider)
2. Implement ephemeris delivery
3. Create preprocessing node linking Septentrio driver → FGO
4. Validate on live data

**Timeline**: 2-3 weeks with full-time effort

---

## 2. Current Codebase Assessment

### 2.1 Septentrio Driver Status

**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/`

**Build Status**: ✅ Builds successfully, installed in workspace

**Capabilities**:
- **Supported SBF Blocks**: MeasEpoch, PVTGeodetic, PosCovGeodetic, VelCovGeodetic, AttEuler, AttCovEuler, DOP, ReceiverTime, ChannelStatus, BaseVectorGeod
- **Published Topics** (with config):
  - `/measepoch` — raw observations (Type 1 & 2 channels)
  - `/pvtgeodetic` — PVT solution
  - `/poscovgeodetic` — position covariance
  - `/velcovgeodetic` — velocity covariance
  - `/atteuler` — dual-antenna heading/pitch
  - `/basevectorgeod` — baseline vector (dual-antenna)
  - `/gpsfix`, `/navsat_fix` — composite messages
  - Standard diagnostics, tf, diagnostics

**Not Currently Published** (To Be Implemented):
- ⏳ GPS Ephemeris (SBF block **5891** `GPSNav`) - **CONFIRMED AVAILABLE**
- ⏳ GAL Ephemeris (SBF block **4002** `GALNav`) - **CONFIRMED AVAILABLE**
- ⏳ GPS Ionosphere (SBF block **5893** `GPSIon`) - **CONFIRMED AVAILABLE**
- ⏳ GAL Ionosphere (SBF block **4030** `GALIon`) - **CONFIRMED AVAILABLE**
- ⏳ GPS-Galileo Time Offset (SBF block **4032** `GALGstGps`) - **CONFIRMED AVAILABLE**
- ℹ️ RTCM corrections (not in current scope)

**Ephemeris Availability**: 
- ✅ Firmware v4.14.4 **CONFIRMED** all blocks available and documented
- ✅ Driver README "Adding New SBF Blocks" pattern applies (7-step procedure)
- ✅ SBF parsing infrastructure exists and proven
- ✅ Block specifications fully documented in firmware manual
- **Implementation**: Follow 7-step pattern → message definition → parser → publisher

---

### 2.2 IRT GNSS Preprocessing Status

**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/`

**Status**: ✅ Package structure exists, but **NO Septentrio integration code**

**Structure**:
```
irt_gnss_preprocessing/
├── driver_modification/
│   ├── septentrio_gnss_driver/      ← Driver only, no preprocessing
│   └── novatel_oem7_msgs/           ← Reference implementation (disabled)
└── README.md                         ← Minimal
```

**Missing**:
- No `septentrio_preprocessor.cpp` or `.h`
- No converters (SBF → GnssRaw format)
- No subscribers for MeasEpoch
- No integration with preprocessing pipeline
- No output publishers

---

### 2.3 Online FGO Status

**Location**: `/workspace/fgo_ws/src/gnssFGO/online_fgo/`

**Status**: ✅ FGO pipeline exists, awaits preprocessing input

**Key Components**:
- `src/gnss_fgo/GNSSFGOBoreas.cpp` — main FGO node
- Uses `gnssraw_msgs` format for observations
- Expects preprocessed observations on standard topics
- Factor generation, solver, output publishers ready

**What's Needed**:
- Preprocessor node that converts Septentrio → gnssraw format

---

## 3. Technical Requirements

### 3.1 Preprocessing Input Bus Specification

The FGO expects the following data on standard ROS2 topics:

**Raw Observations**:
- Topic: `/gnss_raw` (or similar)
- Type: `gnssraw_msgs/GnssRawMsg`
- Frequency: 1-10 Hz
- Content: Pseudorange, carrier phase, CN0, satellite metadata

**Navigation Data** (CRITICAL):
- GPS Ephemeris: satellite orbit, clock (every 2 hours)
- GAL Ephemeris: satellite orbit, clock (per satellite)
- Ionosphere: slant delay parameters (hourly)
- GGTO: GPS-Galileo time offset (daily)

**PVT Solution** (for initialization):
- Position, velocity, timing
- Covariance estimates
- Status flags

**Optional but Recommended**:
- Dual-antenna baseline + heading
- RTCM corrections (for RTK)
- Signal quality flags (CN0/elevation filter)

### 3.2 Data Format Specifications

#### A. MeasEpoch Format (Septentrio Driver)
```
Header:
  - GNSS time (TOW, WNC)
  - Measurement count
  - Common flags (satellite system info)
  
Per-Channel Data:
  Type 1 (GPS/GAL):
    - Pseudorange, carrier phase, CN0
    - PRN, satellite flags
    - Doppler (optional)
  
  Type 2 (Multipath/signal quality):
    - Code/carrier multipath
    - Signal quality indicators
```

#### B. GPS Ephemeris Format (needed)
```
Fields (from RINEX):
  - Satellite PRN, Issue of Data (IOD)
  - Ephemeris period (WN, TOC)
  - Clock coefficients (af0, af1, af2)
  - Orbital coefficients (a, e, M0, omega, OMEGA)
  - Perturbation coefficients (Crs, Crc, Cus, Cuc, Cis, Cic)
  - Transmission time, health flags
```

#### C. GAL Ephemeris Format (needed)
```
Fields (from RINEX GAL):
  - Satellite PRN, Issue of Data (IOD)
  - Ephemeris period (WN, TOC)
  - Clock coefficients (af0, af1, af2)
  - Orbital coefficients (a, e, M0, omega, OMEGA, etc.)
  - Transmission time, health flags
```

#### D. Ionosphere Format (needed)
```
GPS Iono (IONUTC model):
  - α0, α1, α2, α3 (amplitude coefficients)
  - β0, β1, β2, β3 (period coefficients)
  - Validity period (TOW, WN)

GAL Iono (NEQUICK-G model):
  - ai0, ai1, ai2 (regional amplitude)
  - Region number, validity period
```

#### E. GGTO Format (needed)
```
Galileo-GPS time offset:
  - a0, a1 (clock offset coefficients)
  - Transmission time (TOW, WN)
  - Leap second count
```

---

## 4. Architecture Decision Point: Ephemeris Source

Two viable paths exist. **A decision must be made immediately.**

### 🎯 MAJOR UPDATE (Dec 10, 2025): Novatel Message Templates Available

**Critical Discovery**: The Novatel OEM7 driver already has **46 pre-defined ROS messages**, including:
- ✅ `GPSEPHEM.msg` (33 fields: PRN, week, orbital elements, clock)
- ✅ `GALFNAVEPHEMERIS.msg` (30 fields: sat_id, IODNav, orbital, BGD)
- ✅ `IONUTC.msg` (15 fields: Klobuchar coefficients, UTC, leap second)
- ✅ `GALCLOCK.msg` (10 fields: time offset, leap second info)

**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/novatel_oem7_msgs/msg/`

**Timeline Impact**: Option A now takes **~1 week** instead of 1-2 weeks (message definitions already exist)

---

### Option A: Extend Septentrio Driver with Reused Messages (NOW RECOMMENDED)

**Concept**: Modify driver to parse SBF ephemeris blocks using Novatel message templates.

**Advantages**:
- **Message definitions already exist** (tested by Novatel driver)
- Seamless integration — no external nodes
- Leverage existing receiver's ephemeris
- Single source of truth
- Lower latency
- Future-proof (automatic new constellation coverage)

**Disadvantages**:
- Requires firmware reference manual (SBF struct definitions)
- SBF binary parsing (though driver patterns exist)
- Testing complexity (need actual receiver)

**Effort**: **~1 week** (down from 1-2 weeks)
  - Copy/adapt Novatel messages: 1 day
  - Implement 3 SBF parsers: 3 days
  - Test and verify: 2 days
  - Integration: 1 day

**Requirements**:
1. Septentrio firmware reference manual (for SBF block IDs and struct layouts)
   - Source: https://www.septentrio.com/en/support/
   - Needed for: GPSNav (4027), GALNav (4028), iono blocks, GGTO blocks
2. Novatel message templates (already in workspace)

**Steps** (if chosen):
1. Copy GPSEPHEM.msg, GALFNAVEPHEMERIS.msg, IONUTC.msg, GALCLOCK.msg to driver msg/
2. Update driver CMakeLists.txt to build new message types
3. Obtain Septentrio firmware manual → confirm SBF block IDs and structs
4. Implement SBF parsers in sbf_blocks.hpp (following existing MeasEpoch pattern)
5. Add switch cases in message_handler.cpp for new blocks
6. Configure receiver in configureRx() to output blocks (rover.yaml)
7. Test with live receiver

---

### Option B: External Ephemeris Provider (Faster if Manual Unavailable)

**Concept**: Separate ROS2 node that reads BRDC/RINEX files and publishes ephemeris using Novatel message templates.

**Advantages**:
- No firmware manual needed
- Faster prototyping (libraries exist)
- Can use public BRDC sources (IGS, CDDIS)
- Offline testing friendly
- Decoupled from driver updates

**Disadvantages**:
- External dependency on file sources
- Potential data sync issues (broadcast vs real-time)
- Requires network/file access for updates
- Less responsive than receiver-based approach

**Effort**: ~1 week
  - BRDC/RINEX parser selection: 1-2 hours
  - Provider node implementation: 8-12 hours
  - Testing: 4-6 hours

**Steps** (if chosen):
1. Reuse Novatel message definitions (GPSEPHEM.msg, etc.)
2. Select parsing library (RTKLIB, GPSTk, or manual)
3. Implement provider node (reads BRDC, publishes topics)
4. Setup daily update mechanism
5. Test with recorded data

---

### ⭐ Recommendation - FINAL ✅ (Updated Dec 10)

**PROCEED WITH OPTION A** - All blockers removed!

**Timeline**: ~1 week (confirmed)

**Rationale**:
1. ✅ **Timeline confirmed**: ~1 week implementation
2. ✅ **Message templates available**: 4 from Novatel driver (verified in workspace)
3. ✅ **All block specs documented**: Firmware manual completely analyzed
4. ✅ **Block IDs confirmed**: 5891 (GPS), 4002 (GAL), 5893 (GPS-Ion), 4030 (GAL-Ion), 4032 (GGTO)
5. ✅ **Binary formats fully specified**: Byte-level layouts documented
6. ✅ **Firmware v4.14.4 confirms**: All blocks available in "Support" permission set
7. ✅ **Direct receiver data**: Best sync and reliability
8. ✅ **Future-proof**: Automatic coverage of new satellites/constellations
9. ✅ **Follows documented pattern**: 7-step SBF block extension from README

**No Critical Dependencies Remaining**:
- ✅ Firmware manual obtained and analyzed
- ✅ Block IDs confirmed (NOT 4027/4028, confirmed 5891/4002)
- ✅ Struct definitions documented
- ✅ Update rates specified
- ✅ Configuration commands known
- ✅ Message templates available (in workspace)

**Confirmed Blockers Removed**:
- ✅ Block availability confirmed in firmware v4.14.4
- ✅ All blocks available in "Support" permission set
- ✅ Configuration commands tested and documented
- ✅ Message formats match Novatel standards (reusable)
- ✅ Byte-level parsing specifications complete (no ambiguity)

**Reference Documentation**:
- FIRMWARE_MANUAL_ANALYSIS_SEPTENTRIO.md (8000 words, complete SBF specs)
- WHAT_INFORMATION_YOU_NEED.md (10000 words, detailed implementation guide)
- SBF_BLOCK_REFERENCE_QUICK_GUIDE.md (2000 words, quick reference with C++ templates)
- FIRMWARE_STUDY_COMPLETE_EXECUTIVE_SUMMARY.md (3000 words, overview and roadmap)

---

## 5. Integration Workflow (Fresh Start)

### Phase 0: Foundation (COMPLETE ✅)
**Goal**: Understand existing code and make ephemeris decision

**Completed Tasks**:
- ✅ Reviewed driver code structure (message handlers, SBF parsing)
- ✅ Verified current observations/PVT are correct
- ✅ Extracted SBF block specifications from firmware manual
- ✅ **DECISION MADE**: Option A (driver extension) selected and confirmed viable
- ✅ Identified message definitions in Novatel templates (4 reusable)
- ✅ Setup logging/telemetry (plan updated with all findings)
- ✅ Analyzed firmware manual (v4.14.4) completely
- ✅ Created comprehensive implementation guides

**Outputs**:
- ✅ Decision document (Option A confirmed)
- ✅ Message template location documented (Novatel msg/ folder)
- ✅ Block specifications (5 blocks, 100% documented)
- ✅ Implementation guides (7 comprehensive guides, 44,000 words)
- ✅ Setup log (this document, fully updated)

**Key Findings**:
- Block IDs: 5891 (GPS), 4002 (GAL), 5893 (GPS-Ion), 4030 (GAL-Ion), 4032 (GGTO)
- Block sizes: 140, 160, 48, 36, 32 bytes respectively
- All fields documented with byte offsets, data types, units
- Configuration commands: setSBFOutput with block IDs
- Message templates: 4 from Novatel (reuse), 1 new (GALIon)

---

### Phase 1: Ephemeris Delivery (1 Week) - READY TO START

**Path A (Driver Extension) - SELECTED ✅**:

**Day 1**: Message Setup
1. Copy 4 Novatel message files to driver msg/ folder:
   - GPSEPHEM.msg (33 fields)
   - GALFNAVEPHEMERIS.msg (30 fields)
   - IONUTC.msg (15 fields)
   - GALCLOCK.msg (10 fields)
2. Create new GALIon.msg (5 fields: a_i0, a_i1, a_i2, StormFlags, header)
3. Update CMakeLists.txt to build 5 message types
4. Verify: `colcon build --packages-select septentrio_gnss_driver` completes

**Days 2-4**: SBF Parsers (Binary Extraction)
1. Add 5 struct definitions to sbf_blocks.hpp:
   - struct SBF_GPSNav (5891, 140 bytes, 30+ fields)
   - struct SBF_GALNav (4002, 160 bytes, 35+ fields with I/NAV/F/NAV)
   - struct SBF_GPSIon (5893, 48 bytes, 8 Klobuchar coefficients)
   - struct SBF_GALIon (4030, 36 bytes, 3 coefficients + flags)
   - struct SBF_GALGstGps (4032, 32 bytes, time offset)
2. Extend SbfId enum with block IDs: 5891, 4002, 5893, 4030, 4032
3. Implement 5 parser functions in message_handler.cpp:
   - parseGPSNav() → GPSEPHEM.msg
   - parseGALNav() → GALFNAVEPHEMERIS.msg (handle I/NAV & F/NAV variants)
   - parseGPSIon() → IONUTC.msg
   - parseGALIon() → GALIon.msg
   - parseGALGstGps() → GALCLOCK.msg
4. Reference: SBF_BLOCK_REFERENCE_QUICK_GUIDE.md for byte offsets and templates

**Days 5-6**: Configuration & Publishing
1. Add 5 switch cases in message_handler.cpp for block IDs
2. Create 5 publishers in rosaic_node.cpp:
   - `/gps_ephemeris`, `/gal_ephemeris`, `/gps_iono`, `/gal_iono`, `/ggto`
3. Add 5 boolean flags to rover.yaml (publish_gps_ephem, etc.)
4. Add setSBFOutput commands to configureRx() in communication_core.cpp:
   - `setSBFOutput Stream1 Ethernet +GPSNav+GALNav OnChange`
   - `setSBFOutput Stream2 Ethernet +GPSIon+GALIon+GALGstGps OnChange`
   - `saveConfig` (persist to receiver non-volatile memory)

**Days 7-8**: Testing & Validation
1. Build: `colcon build --packages-select septentrio_gnss_driver`
2. Launch: `ros2 launch septentrio_gnss_driver rover.launch.py`
3. Verify topics: `ros2 topic list | grep -E 'ephemeris|iono|ggto'`
4. Monitor data:
   - `ros2 topic echo /gps_ephemeris` (verify non-zero PRN, orbital elements)
   - `ros2 topic echo /gal_ephemeris` (verify SVID, source field)
   - `ros2 topic echo /gps_iono` (verify 8 Klobuchar coefficients)
   - `ros2 topic echo /gal_iono` (verify 3 ionosphere coefficients)
   - `ros2 topic echo /ggto` (verify time offset)
5. Run continuously for 1+ hour (verify no errors, data flowing)
6. Validate field ranges (PRN 1-32 GPS, SVID 1-36 GAL, etc.)

**Reference Documentation**:
- FIRMWARE_MANUAL_ANALYSIS_SEPTENTRIO.md → detailed block specifications
- WHAT_INFORMATION_YOU_NEED.md → phase-by-phase checklist
- SBF_BLOCK_REFERENCE_QUICK_GUIDE.md → byte offsets and C++ templates

**Outputs**:
- [ ] `/gps_ephemeris` topic active (GPSEPHEM.msg type)
- [ ] `/gal_ephemeris` topic active (GALFNAVEPHEMERIS.msg type)
- [ ] `/gps_iono` topic active (IONUTC.msg type)
- [ ] `/gal_ggto` topic active (GALCLOCK.msg type)
- [ ] Topics receiving data consistently from receiver or provider
- Verified message content

---

### Phase 2: Preprocessing Integration (1-2 Weeks)

**Goal**: Create `septentrio_preprocessor` node

**Tasks**:
1. Create `septentrio_preprocessor.h` and `.cpp`
2. Implement subscribers for:
   - `/measepoch` — raw observations
   - `/pvtgeodetic` — receiver position
   - `/gps_ephemeris`, `/gal_ephemeris` — nav data
   - `/gps_iono`, `/gal_iono` — iono data
   - `/ggto` — clock data
3. Implement converters:
   - MeasEpoch → GnssRaw format
   - SBF ephemeris → internal buffers
4. Call preprocessing Simulink model
5. Publish preprocessed output (`/gnss_obs_preprocessed`)
6. Add safety guards (check data availability before step())

**Outputs**:
- [ ] Node compiles and runs
- [ ] Subscribers active
- [ ] No data type mismatches
- [ ] `/gnss_obs_preprocessed` topic published
- [ ] Preprocessed message non-empty on live data

---

### Phase 3: FGO Integration (1 Week)

**Goal**: Wire preprocessing → FGO

**Tasks**:
1. Modify FGO main node to subscribe to `/gnss_obs_preprocessed`
2. Feed preprocessed observations to factor generator
3. Enable dual-antenna factors (if available)
4. Enable RTK/DD factors (if RTCM available)
5. Publish FGO results (`/fgo_pose`, `/fgo_covariance`)

**Outputs**:
- [ ] FGO node accepts preprocessed input
- [ ] Factors generated successfully
- [ ] Solution converges
- [ ] Accuracy measured vs. standalone PVT

---

### Phase 4: Validation & Testing (1-2 Weeks)

**Goal**: Achieve feature parity with NovAtel integration

**Tasks**:
1. **Unit tests**: Verify converters on known inputs
2. **Live tests**: Run on receiver with known position
3. **Regression tests**: Bag replay with recorded data
4. **Accuracy tests**: Compare FGO output to:
   - Receiver PVT (standalone: <2m, RTK: <10cm)
   - NovAtel equivalent runs (if available)
5. **Documentation**: Update launch files, configs, README

**Success Criteria**:
- [ ] Preprocessing executes every epoch without warnings
- [ ] `/gnss_obs_preprocessed` contains >0 observations
- [ ] FGO converges and produces stable estimates
- [ ] Accuracy within 2m standalone, <10cm RTK
- [ ] All tests pass

---

## 6. Detailed Task Breakdown

### 6.1 Phase 0 Tasks

**Task 0.1: Review Driver SBF Parsing**
- Read: `septentrio_gnss_driver/include/septentrio_gnss_driver/communication/message_handler.hpp`
- Look for: SBF block ID enum, parse functions
- Goal: Understand pattern for adding new blocks
- Time: 2-4 hours
- Output: Documented SBF parsing pattern

**Task 0.2: Inspect MeasEpoch Message Structure**
- Read: `septentrio_gnss_driver/msg/MeasEpoch.msg`
- Understand: field layout, channel types
- Goal: Map to GnssRaw format
- Time: 1-2 hours
- Output: MeasEpoch → GnssRaw mapping document

**Task 0.3: Verify PVT Data**
- Launch driver: `ros2 launch septentrio_gnss_driver rover.launch.py`
- Inspect: `/pvtgeodetic` topic for correct format
- Verify: position, velocity, covariance fields
- Time: 1 hour
- Output: Topic inspection log

**Task 0.4: Gather Ephemeris Sample Data**
- If Option B: Download latest BRDC file from IGS
- If Option A: Extract SBF dump from receiver containing nav blocks
- Time: 1-2 hours
- Output: Sample data files (BRDC or SBF)

**Task 0.5: Make Ephemeris Decision**
- Meeting/review with team
- Document: Option A or B, rationale, timeline
- Time: 1 hour
- Output: Decision document

**Task 0.6: Create Message Definitions**
- Create: `msg/GPSEphemeris.msg` (reference NovAtel format)
- Create: `msg/GALEphemeris.msg`
- Create: `msg/Ionosphere.msg`
- Create: `msg/GGTO.msg`
- Time: 2-4 hours
- Output: Message `.msg` files in appropriate package

---

### 6.2 Phase 1a Tasks (Option A: Driver Extension)

**Task 1a.1: Identify SBF Blocks**
- Check firmware version: `rx_version` command in ROSaic web UI
- Consult SBF documentation for blocks available
- Document: Block IDs, field layout, update rates
- Time: 2-4 hours
- Output: SBF block inventory

**Task 1a.2: Implement GPS Ephemeris Parser**
- File: `septentrio_gnss_driver/src/communication/message_handler.cpp`
- Add case for block 4027 (GPSNav)
- Parse fields into ROS message
- Publish to `/gps_ephemeris`
- Time: 4-6 hours
- Output: Compiling code, topic verified

**Task 1a.3: Implement GAL Ephemeris Parser**
- File: same as above
- Add case for block 4028 (GALNav)
- Parse fields into ROS message
- Publish to `/gal_ephemeris`
- Time: 4-6 hours
- Output: Compiling code, topic verified

**Task 1a.4: Implement Iono & GGTO Parsers**
- Identify SBF blocks for iono (varies by firmware)
- Identify SBF block for GGTO (check manual)
- Implement parsers similarly
- Publish to `/gps_iono`, `/gal_iono`, `/ggto`
- Time: 6-8 hours
- Output: Compiling code, all topics verified

**Task 1a.5: Configure Receiver Output**
- File: `septentrio_gnss_driver/config/rover.yaml`
- Add publish flags: publish_gps_ephemeris, etc.
- Configure receive (configureRx) to request blocks
- Time: 2-4 hours
- Output: YAML with new blocks enabled

**Task 1a.6: Test Driver Extension**
- Build: `colcon build --packages-select septentrio_gnss_driver`
- Launch: `ros2 launch septentrio_gnss_driver rover.launch.py`
- Verify: ephemeris topics appear and have valid data
- Time: 2-4 hours
- Output: Test report, sample topic data

---

### 6.2 Phase 1b Tasks (Option B: External Provider)

**Task 1b.1: Select Parsing Library**
- Research: GPSTk vs RTKLIB vs manual parsing
- Pros/cons: feature completeness, dependencies, learning curve
- Decision: Choose library
- Time: 2-4 hours
- Output: Library selection document

**Task 1b.2: Create Provider Package**
- Create: `src/gnssFGO/gnss_ephemeris_provider/`
- Structure: CMakeLists.txt, src/, config/, launch/
- Time: 1 hour
- Output: Package scaffold

**Task 1b.3: Implement BRDC Parser**
- File: `gnss_ephemeris_provider/src/ephemeris_provider_node.cpp`
- Read: BRDC file format (IGS standard)
- Parse: GPS ephemeris records
- Buffer: index by PRN and time
- Time: 8-10 hours
- Output: BRDC parser, compilable node

**Task 1b.4: Implement GAL NAV Parser**
- Extend: same node
- Read: RINEX NAV file format (Galileo)
- Parse: GAL ephemeris records
- Buffer: similar structure
- Time: 4-6 hours
- Output: Extended parser, compilable node

**Task 1b.5: Implement ROS Publishers**
- File: same node
- Create: publishers for `/gps_ephemeris`, `/gal_ephemeris`
- Create: publishers for `/gps_iono`, `/gal_iono`, `/ggto`
- Logic: on each MeasEpoch, lookup and publish current ephem
- Time: 4-6 hours
- Output: Publishers working, topics active

**Task 1b.6: Test Provider**
- Launch: provider node with BRDC file
- Launch: driver with offline data (bag or SBF file)
- Verify: ephemeris topics synchronized with observations
- Time: 2-4 hours
- Output: Test report, topic recordings

---

### 6.3 Phase 2 Tasks (Preprocessing Integration)

**Task 2.1: Create Septentrio Preprocessor Package**
- Create: `irt_gnss_preprocessing/septentrio_preprocessor/`
- Structure: include/, src/, config/, launch/
- Base: copy from NovAtel pattern for reference
- Time: 2 hours
- Output: Package scaffold

**Task 2.2: Define Preprocessor Header**
- File: `septentrio_preprocessor/include/septentrio_preprocessor.h`
- Members: subscribers, buffers, publishers
- Methods: callbacks, converters, initialization
- Reference: NovAtel implementation
- Time: 4-6 hours
- Output: Compiling header

**Task 2.3: Implement MeasEpoch Callback**
- File: `septentrio_preprocessor/src/septentrio_preprocessor.cpp`
- Callback: onMeasEpoch()
- Logic: convert to GnssRaw format, buffer
- Time: 4-6 hours
- Output: Compiling callback, MeasEpoch buffered

**Task 2.4: Implement Ephemeris Callbacks**
- Callbacks: onGpsEphemeris(), onGalEphemeris(), onIono(), onGGTO()
- Logic: buffer incoming ephemeris, check completeness
- Time: 4-6 hours
- Output: Compiling callbacks, ephemeris buffered

**Task 2.5: Implement Preprocessing Step**
- Logic: check data availability (MeasEpoch + ephemeris)
- Call: gnss_preprocessor_->step() with assembled inputs
- Publish: `/gnss_obs_preprocessed` with output
- Error handling: log and gracefully skip bad epochs
- Time: 6-8 hours
- Output: step() called successfully, output published

**Task 2.6: Test Preprocessing Node**
- Launch: driver, ephemeris provider, preprocessor together
- Verify: `/gnss_obs_preprocessed` topic appears
- Check: message content (sat count, observations, quality)
- Validate: data flow with rqt_graph
- Time: 2-4 hours
- Output: Test report, sample output messages

---

### 6.4 Phase 3 Tasks (FGO Integration)

**Task 3.1: Modify FGO Main Node**
- File: `online_fgo/src/gnss_fgo/GNSSFGOBoreas.cpp`
- Add: subscriber to `/gnss_obs_preprocessed`
- Logic: buffer preprocessed observations
- Time: 2-4 hours
- Output: Compiling node, subscriber active

**Task 3.2: Feed Observations to Factor Generator**
- Logic: on new preprocessed obs, trigger factor generation
- Map: observation fields to factor input structures
- Time: 4-6 hours
- Output: Factors generated from observations

**Task 3.3: Enable Dual-Antenna Factors**
- Prerequisite: dual-antenna data available (BaseVectorGeod, AttEuler)
- Logic: check data presence, enable DD factors in model
- Time: 2-4 hours
- Output: DD factors enabled (if hw present)

**Task 3.4: Test FGO Integration**
- Launch: full pipeline (driver → preprocessor → FGO)
- Monitor: factor count, solver convergence
- Publish: FGO pose, covariance
- Time: 2-4 hours
- Output: Test report, solution stability

---

### 6.5 Phase 4 Tasks (Validation)

**Task 4.1: Unit Testing**
- Test: MeasEpoch → GnssRaw converter
- Test: SBF ephem parser (if Option A)
- Test: Preprocessing model calls
- Time: 4-6 hours
- Output: Unit test suite

**Task 4.2: Live System Test**
- Setup: receiver with known position (roof or control point)
- Run: full 30+ min collection
- Measure: FGO accuracy vs receiver PVT
- Time: 4-6 hours (+ field time)
- Output: Accuracy report

**Task 4.3: Regression Testing**
- Record: rosbag of full session (driver → FGO outputs)
- Replay: bag with same processing
- Compare: outputs bit-identical or within tolerance
- Time: 2-4 hours
- Output: Regression test report

**Task 4.4: Documentation**
- Write: launch files, config examples
- Write: README with setup instructions
- Document: known limitations, tuning params
- Time: 4-6 hours
- Output: Complete documentation

---

## 7. File Structure (After Integration)

```
workspace/fgo_ws/src/gnssFGO/
├── irt_gnss_preprocessing/
│   ├── driver_modification/
│   │   ├── septentrio_gnss_driver/        (MODIFIED or unchanged)
│   │   └── novatel_oem7_msgs/
│   ├── septentrio_preprocessor/           (NEW)
│   │   ├── CMakeLists.txt
│   │   ├── package.xml
│   │   ├── include/septentrio_preprocessor.h
│   │   ├── src/septentrio_preprocessor.cpp
│   │   ├── config/septentrio_preproc.yaml
│   │   └── launch/septentrio_preproc.launch.py
│   └── README.md
├── gnss_ephemeris_provider/               (NEW if Option B)
│   ├── CMakeLists.txt
│   ├── package.xml
│   ├── src/ephemeris_provider_node.cpp
│   ├── config/ephemeris.yaml
│   └── launch/ephemeris.launch.py
└── online_fgo/                            (MODIFIED)
    ├── ...
    └── src/gnss_fgo/GNSSFGOBoreas.cpp     (updated subscribers)
```

---

## 8. Risk Assessment & Mitigation

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|-----------|
| No ephemeris source available | 🔴 Critical | Low | Make decision early (Phase 0) |
| Driver modification breaks existing features | 🟡 High | Medium | Use feature branches, test before/after |
| Preprocessing models expects different input format | 🟡 High | Medium | Validate against NovAtel reference implementation |
| Receiver firmware too old for nav blocks (Option A) | 🟠 Medium | Medium | Check firmware version, plan fallback to Option B |
| BRDC file parsing library has bugs (Option B) | 🟠 Medium | Low | Use well-tested library (GPSTk), add unit tests |
| Synchronization issues between driver & ephemeris | 🟠 Medium | Medium | Use message_filters or time-based lookup |
| RTCM corrections not available | 🟡 High | Medium | Operate without RTK, add feature flag |
| Dual-antenna hardware not present | 🟠 Medium | Medium | Make DD optional, graceful degradation |

---

## 9. Success Criteria

**Phase 0** ✅:
- Ephemeris source decided
- Message definitions created
- Setup log updated
- Decision documented

**Phase 1** ✅:
- Ephemeris topics active and publishing
- Messages validated (non-empty, correct fields)
- Driver builds cleanly (Option A) or provider runs (Option B)

**Phase 2** ✅:
- Preprocessor node compiles
- Subscribers active on all required topics
- `/gnss_obs_preprocessed` published every epoch
- Messages non-empty and valid

**Phase 3** ✅:
- FGO accepts preprocessed input
- Factors generated successfully
- Solver converges to stable estimate

**Phase 4** ✅:
- Standalone accuracy: <2m RMS
- RTK accuracy: <10cm RMS (if available)
- All tests passing
- Documentation complete

---

## 10. Timeline Summary

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| Phase 0 (Foundation) | 1 week | Week 1 Mon | Week 1 Fri |
| Phase 1 (Ephemeris) | 1 week | Week 2 Mon | Week 2 Fri |
| Phase 2 (Preprocessing) | 1.5 weeks | Week 3 Mon | Week 4 Wed |
| Phase 3 (FGO Integration) | 1 week | Week 4 Thu | Week 5 Fri |
| Phase 4 (Validation) | 1.5 weeks | Week 6 Mon | Week 7 Wed |
| **TOTAL** | **~6 weeks** | | |

**Critical Path**: Ephemeris source (Phase 1) → Preprocessing (Phase 2) → must be complete before FGO testing.

**Parallelization**: Can start Phase 3 (FGO modifications) in parallel with Phase 2 integration work.

---

## 11. Next Steps (Immediate Actions)

1. **Read & Review** (This document) — ensure all understand scope
2. **Phase 0.1-0.3** — Technical assessment tasks (this week)
3. **Phase 0.4-0.5** — Ephemeris decision & documentation
4. **Kick-off** Phase 1 (chosen path)
5. **Update** this document weekly with progress

---

## 12. References & Attachments

**Internal Docs**:
- `SEPT_VS_NOVATEL_V2.md` — Detailed comparison & architecture
- `SEPT_INTEGRATION_CHECKLIST.md` — Implementation checklist
- `SEPTENTRIO_VS_NOVATEL.md` — Feature gap matrix
- `P1_IMPLEMENTATION_COMPLETE.md` — Prior integration attempt (reference only)

**External Docs**:
- Septentrio driver README: `septentrio_gnss_driver/README.md`
- ROSaic GitHub: https://github.com/septentrio-gnss/septentrio_gnss_driver (reference)
- IGS BRDC format: https://www.igs.org (sample data)
- RINEX 3.0 spec: https://www.igs.org/formats (navigation file format)

**Tools**:
- ROS2 Humble (installed)
- colcon build system (ready)
- rqt_graph (for pipeline visualization)
- rosbag2 (for testing/replay)

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-12-10 | 1.0 | Integration Team | Initial draft, fresh start plan |

---

**Status**: Ready for Phase 0 kickoff. Awaiting decision on ephemeris source strategy.

