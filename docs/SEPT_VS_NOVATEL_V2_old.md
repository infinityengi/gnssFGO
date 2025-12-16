# Septentrio vs NovAtel Preprocessing - Comprehensive Comparison (v2)

**Date**: December 9, 2025  
**Authors**: Integration Team  
**Purpose**: Detailed technical comparison of Septentrio Mosaic-H vs NovAtel OEM7 preprocessing integration  
**Scope**: irt_gnss_preprocessing package

---

## Executive Summary

| Aspect | NovAtel OEM7 | Septentrio Mosaic-H | Status |
|--------|--------------|---------------------|---------|
| **Integration Level** | 100% Complete | ~40% Complete | 🟡 Partial |
| **Preprocessing Execution** | ✅ Fully operational | ✅ Implemented (blocked) | 🟢 Code ready |
| **Critical Blocker** | None | Missing ephemeris source | 🔴 Blocks all |
| **Estimated Completion** | N/A | 1-2 weeks + ephemeris | 🟡 In progress |

**Key Finding**: Septentrio preprocessing is **architecturally complete** but operationally **blocked** by missing navigation data (ephemeris/ionosphere/clock) that NovAtel provides but Septentrio driver does not publish.

---

## 1. Detailed Feature Comparison Matrix

### 1.1 Data Input Sources

| Input Type | NovAtel OEM7 | Septentrio Mosaic-H | Delta |
|------------|--------------|---------------------|-------|
| **Raw Observations** | | | |
| Main antenna obs | ✅ `/novatel/oem7/range` (RANGE msg) | ✅ `/measepoch` (MeasEpoch msg) | Different format |
| Aux antenna obs | ✅ `/novatel/oem7/range_aux` | ✅ `/measepoch_aux` | Different format |
| Conversion | ✅ OEM7→MeasEpochBus converter | ✅ Manual MSB/LSB reconstruction | Both working |
| LOS/NLOS filter | ✅ Lookup table screening | ❌ Not implemented | Missing feature |
| | | | |
| **Receiver Solution** | | | |
| Position | ✅ `/novatel/oem7/bestpos` | ✅ `/pvtgeodetic` | ✅ Equivalent |
| Velocity | ✅ `/novatel/oem7/bestvel` | ✅ `/velcovgeodetic` | ✅ Equivalent |
| Clock | ✅ `/novatel/oem7/clockmodel` | ⚠️ Embedded in PVT | Less detail |
| Dual-antenna heading | ✅ `/novatel/oem7/dualantennaheading` | ✅ `/atteuler` | ✅ Equivalent |
| Synchronization | ✅ 4-way message_filters sync | ✅ 3-way message_filters sync | Working |
| | | | |
| **Navigation Products** | | | |
| GPS Ephemeris | ✅ `/novatel/oem7/gpsephem` | ❌ **NOT PUBLISHED** | 🔴 **BLOCKER** |
| GAL I/NAV Ephemeris | ✅ `/novatel/oem7/galInavEphemeris` | ❌ **NOT PUBLISHED** | 🔴 **BLOCKER** |
| GAL F/NAV Ephemeris | ✅ `/novatel/oem7/galFnavEphemeris` | ❌ **NOT PUBLISHED** | 🔴 **BLOCKER** |
| GPS Ionosphere | ✅ `/novatel/oem7/ionutc` | ❌ **NOT PUBLISHED** | 🔴 **BLOCKER** |
| GAL Ionosphere | ✅ `/novatel/oem7/galiono` | ❌ **NOT PUBLISHED** | 🔴 **BLOCKER** |
| GGTO (time offset) | ✅ `/novatel/oem7/galclock` | ❌ **NOT PUBLISHED** | 🔴 **BLOCKER** |
| Converter functions | ✅ Simulink-generated | ❌ Need to create | Missing code |
| | | | |
| **RTK Corrections** | | | |
| RTCM subscription | ✅ `/rtcm_l1e1` topic | ❌ Not wired | Missing wiring |
| RTCM buffer | ✅ `rtcm_buffer_` filled | ❌ Empty buffer | Not connected |
| DD RTK preprocessing | ✅ DDRTCM block enabled | ❌ Never called | Missing execution |
| | | | |
| **Dual-Antenna Data** | | | |
| Baseline vector | ✅ Used in preprocessing | ⚠️ Buffered only | Not wired to model |
| Attitude (heading) | ✅ Used in preprocessing | ⚠️ Buffered only | Not wired to model |
| Aux measurements | ✅ Synchronized & used | ⚠️ Buffered only | Not wired to model |
| DD dual-antenna | ✅ Enabled & functional | ❌ Disabled | Missing flag setting |

### 1.2 Preprocessing Execution

| Component | NovAtel OEM7 | Septentrio Mosaic-H | Status |
|-----------|--------------|---------------------|---------|
| **Core Pipeline** | | | |
| Input assembly | ✅ Complete struct fill | ✅ Complete struct fill | ✅ Implemented |
| Simulink model call | ✅ `gnss_preprocessor_->step()` | ✅ `gnss_preprocessor_->step()` | ✅ Implemented |
| Guards for missing data | ✅ `checkHaveEphem()` | ✅ `checkHaveEphem()` | ✅ Implemented |
| Early return on failure | ✅ With warnings | ✅ With warnings | ✅ Implemented |
| Periodic logging | ✅ Every N epochs | ✅ Every 10 epochs | ✅ Implemented |
| | | | |
| **Input Buses** | | | |
| MeasurementEpochBus | ✅ From RANGE | ✅ From MeasEpoch | ✅ Working |
| GpsNavBus | ✅ Filled from ephem | ❌ Empty → **EXIT** | 🔴 Blocked |
| GpsIonBus | ✅ Filled from ionutc | ❌ Empty | 🟡 Optional |
| GalInavBus | ✅ Filled from GAL ephem | ❌ Empty → **EXIT** | 🔴 Blocked |
| GalIonBus | ✅ Filled from galiono | ❌ Empty | 🟡 Optional |
| GalGstGpsBus (GGTO) | ✅ Filled from galclock | ❌ Empty → **EXIT** | 🔴 Blocked |
| RTCM33L1E1Bus | ✅ Filled if available | ❌ Empty (no sub) | 🟡 Feature missing |
| GnssParametersBus | ✅ Loaded from YAML | ✅ Loaded from YAML | ✅ Working |
| IntegrityParametersBus | ✅ Loaded from YAML | ✅ Loaded from YAML | ✅ Working |
| UserPosLLHVec | ✅ From estimation | ✅ From estimation | ✅ Working |
| | | | |
| **Control Flags** | | | |
| UseModeSwitchLogic | ✅ Set from param | ✅ Set from param | ✅ Working |
| EnableGGTO | ✅ Set from param | ✅ Set from param | ✅ Working |
| EnableGNSSMerge | ✅ Set from param | ✅ Set from param | ✅ Working |
| EnableDualAntennaDD | ✅ Set from param | ❌ Hardcoded `false` | 🟡 Not wired |

### 1.3 Output Publishing

| Output | NovAtel OEM7 | Septentrio Mosaic-H | Delta |
|--------|--------------|---------------------|-------|
| **Preprocessed Observations** | | | |
| Topic | ✅ `/gnss_obs_preprocessed` | ❌ Not published | Missing publisher |
| Message type | ✅ `GNSSObsPreProcessed` | ❌ N/A | Missing code |
| Satellite data | ✅ Full arrays | ❌ N/A | Not generated |
| Quality metrics | ✅ DOP, integrity flags | ❌ N/A | Not generated |
| | | | |
| **Receiver PVT** | | | |
| Topic | ✅ `/PVT` | ✅ `/PVT` | ✅ Working |
| Message type | ✅ `PVAGeodetic` | ✅ `PVAGeodetic` | ✅ Working |
| Fields populated | ✅ ~30 fields | ⚠️ ~15 fields | Less complete |
| | | | |
| **Least Squares Solution** | | | |
| Topic | ✅ `/LeastSquarePVT` | ❌ Not published | Missing publisher |
| Message type | ✅ `PVTLS` | ❌ N/A | Missing code |
| | | | |
| **Residuals** | | | |
| Topic | ✅ `/ls_ant_main_residuals` | ❌ Not published | Missing publisher |
| Message type | ✅ `Residuals` | ❌ N/A | Missing code |
| NavSatFix | ✅ `/ant_main_ls` | ❌ Not published | Missing publisher |

### 1.4 Code Structure

| Component | NovAtel OEM7 | Septentrio Mosaic-H | Comparison |
|-----------|--------------|---------------------|------------|
| **Files** | | | |
| Header | `novatel_oem7_preprocessor.h` (200 lines) | `septentrio_preprocessor.h` (140 lines) | Simpler (no ephem subs) |
| Source | `novatel_oem7_preprocessor.cpp` (984 lines) | `septentrio_preprocessor.cpp` (587 lines) | 60% of NovAtel size |
| Type defs | `novatel_types.h` | `septentrio_types.h` (84 lines) | Similar |
| | | | |
| **Subscribers** | | | |
| Total count | 11 topics | 7 topics | Missing 4 nav topics |
| Ephemeris | 3 (GPS, GAL I/NAV, F/NAV) | 0 | **Missing all** |
| Ionosphere | 2 (GPS, GAL) | 0 | **Missing both** |
| Clock/GGTO | 1 (GALCLOCK) | 0 | **Missing** |
| RTCM | 1 | 0 | **Missing** |
| | | | |
| **Callbacks** | | | |
| Ephemeris handlers | ✅ 3 callbacks + converters | ❌ None | Missing 300+ lines |
| Iono handlers | ✅ 2 callbacks + converters | ❌ None | Missing 100+ lines |
| GGTO handler | ✅ 1 callback + converter | ❌ None | Missing 50+ lines |
| RTCM handler | ✅ 1 callback | ❌ None | Missing |
| Range/MeasEpoch | ✅ 1 (complex) | ✅ 1 (simpler) | Both working |
| | | | |
| **Converters** | | | |
| OEM7→GpsNav | ✅ Simulink-generated | ❌ Missing | Need to create |
| OEM7→GalNav | ✅ Simulink-generated | ❌ Missing | Need to create |
| OEM7→Iono | ✅ Simulink-generated | ❌ Missing | Need to create |
| OEM7→GGTO | ✅ Simulink-generated | ❌ Missing | Need to create |
| Range→MeasEpoch | ✅ Simulink-generated | ✅ Manual code | Both working |

---

## 2. Root Cause Analysis

### 2.1 Why NovAtel Works Completely

**Driver Capabilities**:
- NovAtel OEM7 firmware **broadcasts all navigation data** as separate messages
- Driver (`novatel_oem7_driver`) publishes each SBF block as ROS2 topic
- Messages include: `GPSEPHEM`, `GALINAVEPHEMERIS`, `GALFNAVEPHEMERIS`, `IONUTC`, `GALIONO`, `GALCLOCK`

**Preprocessing Integration**:
- Each nav message → dedicated subscriber → converter → buffer
- When RANGE arrives → check ephemeris present → assemble input → call `step()` → publish
- Complete data flow: **Driver → Preprocessing → FGO**

### 2.2 Why Septentrio is Blocked

**Driver Limitation**:
- Septentrio driver (`septentrio_gnss_driver`) **does NOT publish navigation data as ROS2 topics**
- Only publishes: `MeasEpoch`, `PVTGeodetic`, covariances, dual-antenna (AttEuler/BaseVectorGeod), `ReceiverTime`
- SBF format **may contain** nav blocks internally, but driver doesn't expose them

**Preprocessing Block**:
- When MeasEpoch arrives → preprocessing checks ephemeris → **NOT PRESENT** → early return with warning
- Guard prevents calling `step()` without sat positions → **no output**
- Incomplete data flow: **Driver → ❌ (missing link) → Preprocessing** → (never reached)

**Impact**:
- Receiver internally uses ephemeris (that's how it computes PVT)
- But preprocessing models need **explicit ephemeris inputs** to compute corrections
- Without external source, preprocessing **cannot run**

---

## 3. Missing Components Breakdown

### 3.1 Critical (P1) - Blocks All Preprocessing

| Component | Lines | Complexity | Impact |
|-----------|-------|------------|---------|
| **Ephemeris Provider** | ~500 | High | Without this, nothing works |
| - GPS ephemeris parser | ~150 | Medium | BRDC file reading |
| - GAL ephemeris parser | ~150 | Medium | RINEX NAV parsing |
| - ROS2 publishers | ~50 | Low | Topic setup |
| - Ephemeris buffers | ~50 | Low | Circular buffers |
| - Converters to gnssraw | ~100 | Medium | Format conversion |
| **OR Driver Extension** | ~300 | High | Alternative to provider |
| - Expose SBF nav blocks | ~200 | High | Driver modification |
| - Create ROS2 messages | ~100 | Medium | Message definitions |

### 3.2 High Priority (P2) - RTK/Corrections

| Component | Lines | Complexity | Impact |
|-----------|-------|------------|---------|
| RTCM subscription | ~30 | Low | No RTK without this |
| RTCM buffer wiring | ~20 | Low | Enable DD processing |
| DD flag gating | ~10 | Low | Graceful degradation |

### 3.3 Medium Priority (P3) - Dual-Antenna

| Component | Lines | Complexity | Impact |
|-----------|-------|------------|---------|
| Baseline/attitude input | ~50 | Low | No heading factors |
| Aux MeasEpoch sync | ~30 | Low | Dual-antenna idle |
| DD dual-antenna flag | ~10 | Low | Advanced RTK unused |

### 3.4 Low Priority (P4-P5) - Quality & Output

| Component | Lines | Complexity | Impact |
|-----------|-------|------------|---------|
| LOS/NLOS filter | ~80 | Medium | Multipath risk |
| Integrity mapping | ~40 | Low | No quality gates |
| Output publishers | ~150 | Medium | FGO integration |
| - GNSSObsPreProcessed | ~80 | Low | Main output |
| - LS PVT | ~30 | Low | Validation |
| - Residuals | ~40 | Low | Diagnostics |

---

## 4. Quantitative Comparison

### 4.1 Code Metrics

| Metric | NovAtel OEM7 | Septentrio | % Complete |
|--------|--------------|------------|------------|
| Total lines (cpp) | 984 | 587 | 60% |
| Subscribers | 11 | 7 | 64% |
| Callbacks | 14 | 7 | 50% |
| Converters | 8 | 2 | 25% |
| Publishers | 4 | 1 | 25% |
| Buffers | 18 | 11 | 61% |

### 4.2 Feature Completion

| Category | Total Features | Implemented | % Done | Blocked |
|----------|----------------|-------------|---------|---------|
| Data ingestion | 10 | 4 | 40% | 6 |
| Preprocessing execution | 8 | 8 | 100% | 0* |
| Navigation products | 6 | 0 | 0% | 6 |
| RTK/DD | 3 | 0 | 0% | 0 |
| Dual-antenna | 4 | 2 | 50% | 0 |
| Quality/Integrity | 3 | 1 | 33% | 0 |
| Output publishing | 4 | 1 | 25% | 0 |
| **TOTAL** | **38** | **16** | **42%** | **12** |

*Note: Preprocessing execution is code-complete but operationally blocked by missing inputs.

### 4.3 Effort Estimates

| Phase | Task | Est. Hours | Dependencies |
|-------|------|-----------|--------------|
| **Phase 0** | Decide nav source | 2 | Management decision |
| **Phase 1** | Ephemeris provider | 16-24 | BRDC parser, ROS2 |
| **Phase 2** | Wire nav inputs | 8 | Phase 1 complete |
| **Phase 3** | RTCM integration | 4 | Corrections available |
| **Phase 4** | Dual-antenna wiring | 4 | Baseline data available |
| **Phase 5** | Integrity/LOS | 6 | Testing data |
| **Phase 6** | Output publishers | 6 | All above complete |
| **Phase 7** | Testing/validation | 8 | Test scenarios |
| **TOTAL** | | **54-62 hrs** | **~1.5-2 weeks** |

---

## 5. Architectural Differences

### 5.1 NovAtel Architecture (Working)

```
┌─────────────────┐
│ NovAtel OEM7 Rx │
└────────┬────────┘
         │ Serial/TCP
         ▼
┌─────────────────┐
│ novatel_driver  │ ◄── Publishes ALL messages
└────────┬────────┘
         │
         ├── /novatel/oem7/range ──────────┐
         ├── /novatel/oem7/gpsephem ───────┤
         ├── /novatel/oem7/galInavEphem ───┤
         ├── /novatel/oem7/ionutc ─────────┤
         ├── /novatel/oem7/galiono ────────┤
         ├── /novatel/oem7/galclock ───────┤
         ├── /novatel/oem7/bestpos ────────┤
         └── ... (more topics) ────────────┤
                                           ▼
                          ┌─────────────────────────────┐
                          │ NovatelOEM7PreProcessor     │
                          │  - 11 subscribers           │
                          │  - Ephemeris converters     │
                          │  - Full input assembly      │
                          │  - step() ✅ EXECUTES       │
                          └──────────┬──────────────────┘
                                     │
                                     ├── /gnss_obs_preprocessed ──┐
                                     ├── /PVT ────────────────────┤
                                     ├── /LeastSquarePVT ─────────┤
                                     └── /ls_ant_main_residuals ──┤
                                                                   ▼
                                                          ┌─────────────┐
                                                          │ FGO Solver  │
                                                          │ (Full data) │
                                                          └─────────────┘
```

### 5.2 Septentrio Architecture (Current - Blocked)

```
┌─────────────────┐
│ Septentrio Rx   │
└────────┬────────┘
         │ Serial/TCP
         ▼
┌─────────────────┐
│ septentrio_     │ ◄── Does NOT publish nav data
│ gnss_driver     │
└────────┬────────┘
         │
         ├── /measepoch ──────────────────┐
         ├── /pvtgeodetic ─────────────────┤
         ├── /poscovgeodetic ──────────────┤
         ├── /velcovgeodetic ──────────────┤
         ├── /atteuler ────────────────────┤
         └── /basevectorgeod ──────────────┤
                                           ▼
                          ┌─────────────────────────────┐
                          │ SeptentrioPreProcessor      │
                          │  - 7 subscribers ✅         │
                          │  - NO ephemeris input ❌    │
                          │  - Input assembly ✅        │
                          │  - checkHaveEphem() → FAIL  │
                          │  - step() ❌ NEVER CALLED   │
                          └──────────┬──────────────────┘
                                     │
                                     └── /PVT only ──────────────┐
                                         (preprocessed blocked)  │
                                                                 ▼
                                                        ┌─────────────┐
                                                        │ FGO Solver  │
                                                        │ (PVT only)  │
                                                        └─────────────┘
```

### 5.3 Septentrio Architecture (Proposed - With Ephemeris Provider)

```
┌─────────────────┐
│ Septentrio Rx   │
└────────┬────────┘
         │ Serial/TCP
         ▼
┌─────────────────┐         ┌─────────────────────┐
│ septentrio_     │         │ ephemeris_provider  │ ◄── NEW NODE
│ gnss_driver     │         │  - BRDC file reader │
└────────┬────────┘         │  - RINEX parser     │
         │                  │  - ROS2 publishers  │
         │                  └──────────┬──────────┘
         │                             │
         ├── /measepoch ──────────┐    ├── /gps_ephemeris ──────┐
         ├── /pvtgeodetic ─────────┤    ├── /gal_ephemeris ──────┤
         ├── /poscovgeodetic ──────┤    ├── /gps_ionosphere ─────┤
         ├── /velcovgeodetic ──────┤    ├── /gal_ionosphere ─────┤
         ├── /atteuler ────────────┤    └── /ggto_data ───────────┤
         └── /basevectorgeod ──────┤                              │
                                   ▼                              │
                  ┌────────────────────────────────────────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ SeptentrioPreProcessor      │
    │  - 12 subscribers ✅         │
    │  - Ephemeris converters ✅   │
    │  - Full input assembly ✅    │
    │  - checkHaveEphem() → PASS   │
    │  - step() ✅ EXECUTES        │
    └──────────┬──────────────────┘
               │
               ├── /gnss_obs_preprocessed ──┐
               ├── /PVT ────────────────────┤
               ├── /LeastSquarePVT ─────────┤
               └── /ls_ant_main_residuals ──┤
                                            ▼
                                   ┌─────────────┐
                                   │ FGO Solver  │
                                   │ (Full data) │
                                   └─────────────┘
```

---

## 6. Testing & Validation Status

### 6.1 NovAtel (Baseline)

| Test Scenario | Status | Notes |
|---------------|--------|-------|
| Static open-sky | ✅ Pass | GPS+GAL, >10 SVs |
| RTK fixed | ✅ Pass | cm-level accuracy |
| Dual-antenna | ✅ Pass | Heading valid |
| Multi-constellation | ✅ Pass | GPS+GAL merge |
| Integrity monitoring | ✅ Pass | Flags propagate |
| Regression suite | ✅ Pass | Automated tests |

### 6.2 Septentrio (Current)

| Test Scenario | Status | Notes |
|---------------|--------|-------|
| PVT publishing | ✅ Pass | Receiver solution only |
| MeasEpoch conversion | ✅ Pass | Format correct |
| Dual-antenna buffering | ✅ Pass | Data stored |
| Preprocessing execution | ⚠️ Skip | Warns: no ephemeris |
| Preprocessed obs output | ❌ Fail | Never generated |
| FGO integration | ⚠️ Partial | PVT factors only |

---

## 7. Risk Assessment

### 7.1 Current Risks

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| **No ephemeris source identified** | 🔴 Critical | High | Immediate decision needed |
| **Driver extension impossible** | 🟡 High | Medium | Verify SBF capabilities |
| **External provider too slow** | 🟡 High | Low | Optimize file parsing |
| **BRDC files unavailable** | 🟠 Medium | Low | Fallback to IGS precise |
| **Converter bugs in new code** | 🟠 Medium | Medium | Thorough unit testing |
| **RTCM source missing** | 🟡 High | Medium | Operate without RTK |

### 7.2 Technical Debt

| Item | Impact | Effort to Fix |
|------|--------|---------------|
| No LOS/NLOS filter | Medium | 4 hours |
| Incomplete PVT fields | Low | 2 hours |
| Missing output publishers | High | 6 hours |
| No regression tests | Medium | 8 hours |
| Undocumented params | Low | 2 hours |

---

## 8. Recommendations

### 8.1 Immediate Actions (This Week)

1. **Decide on ephemeris source** (Option 1 or 2):
   - Option 1: External ephemeris provider (RECOMMENDED)
   - Option 2: Extend Septentrio driver

2. **If Option 1** (External Provider):
   - Research BRDC parser libraries (RTKLIB, GPSTk)
   - Prototype ephemeris ROS2 message format
   - Begin provider node implementation

3. **If Option 2** (Driver Extension):
   - Investigate Septentrio SBF block 4027 (GPSNav), 4028 (GLONav), etc.
   - Check if driver already parses these internally
   - Plan message definition additions

### 8.2 Short-Term (Next 2 Weeks)

1. Complete ephemeris provider/extension
2. Wire ephemeris inputs to preprocessing
3. Enable RTCM subscription
4. Test basic preprocessing pipeline
5. Document new configuration

### 8.3 Medium-Term (Following Month)

1. Complete dual-antenna wiring
2. Implement LOS/NLOS filtering
3. Add all output publishers
4. Conduct full regression testing
5. Measure accuracy vs NovAtel

---

## 9. Conclusion

**Current State**: Septentrio preprocessing is **60% integrated** by code volume but **0% operational** due to missing navigation data.

**Root Cause**: Architectural difference between receivers—NovAtel publishes ephemeris, Septentrio does not.

**Path Forward**: Add ephemeris source (external provider or driver extension) → complete remaining wiring → achieve parity with NovAtel.

**Timeline**: With focused effort, **1.5-2 weeks** to full parity, assuming ephemeris provider is chosen and implemented first.

**Success Criteria**:
- ✅ Preprocessing executes without warnings
- ✅ GNSSObsPreProcessed published with >0 observations
- ✅ Accuracy comparable to NovAtel (<10cm RTK, <2m standalone)
- ✅ All test scenarios pass

---

## 10. Data Required by `irt_gnss_preprocessing` (formats & sources)
- **Mandatory buses**: `GpsNavBus`, `GalNavBus`, `GpsIonBus`, `GalIonBus`, `GalGstGpsBus` (GGTO), `MeasurementEpochBus` (main/aux), `GnssParametersBus`, `IntegrityParametersBus`.
- **Optional/quality**: `RTCM33L1E1Bus` (RTK/DD), dual-antenna baseline/heading, LOS/NLOS filter inputs (CN0/elevation), integrity flags.
- **Expected formats** (from current models):
  - GPS ephemeris: nav array with WNc > 0; Galileo ephemeris: IODnav > 0.
  - Ionosphere: GPS iono (IONUTC-like), Galileo iono (GALIONO-like).
  - GGTO: GAL-GPS time offset (GALCLOCK-like) when GPS/GAL merge enabled.
  - RTCM: raw RTCM L1/E1 block for DD/RTK path; gate DD when absent.
  - Dual-antenna: baseline vector + attitude (heading/pitch/roll) + aux MeasEpoch.

- **SBF blocks to tap in Septentrio**:
  - Ephemeris: `GPSNav` (4027), `GALNav` (4028).
  - Iono/clock: SBF ionosphere blocks + GGTO/clock block (if available in firmware).
  - RTCM passthrough: RTCM stream blocks (from NTRIP/IP/serial) if receiver forwards them.
  - Dual-antenna: `AttEuler`, `BaseVectorGeod`, `MeasEpochAux`.

## 11. Driver Extension Plan (publish nav/iono/GGTO/RTCM)
- **Add messages**: Define ROS2 msg types for GPS/GAL ephemeris, iono, GGTO, RTCM (reuse NovAtel-style fields where possible); add to `msg/` and `CMakeLists` `add_message_files`.
- **Parse SBF nav blocks**: In `parsers/sbf_blocks.hpp` + `message_handler.cpp` add cases for `GPSNav`/`GALNav` (+ iono/GGTO/RTCM if present). Follow README “Adding New SBF Blocks”: add msg header/typedef, extend `SbfId` enum, extend switch-case, add `publish.*` param, and configure data stream in `communication_core.cpp::configureRx()`.
- **Publish topics**: `/gps_ephemeris`, `/gal_ephemeris`, `/gps_iono`, `/gal_iono`, `/ggto`, `/rtcm_raw` (names can mirror NovAtel equivalents for parity). Gate with new `publish.*` params in `rover.yaml`.
- **Configure receiver**: In `rover.yaml`, request nav blocks at low rate (e.g., 1 Hz) and enable RTCM forwarding if used. Ensure `configure_rx: true` so the driver programs the Rx stream list.
- **Wire preprocessing**: Subscribe in `septentrio_preprocessor` to the new topics, fill nav/iono/GGTO/RTCM buffers, and keep guards (`checkHaveEphem`, GGTO gate, DD gate). Feed dual-antenna baseline/att into dual path; enable `EnableDualAntennaDD` when data present.
- **Execute & publish outputs**: Call `gnss_preprocessor_->step()` once nav present; publish `/gnss_obs_preprocessed`, `/LeastSquarePVT`, `/ls_ant_main_residuals` for parity with NovAtel.
- **Testing**: (1) Unit: parse recorded SBF containing nav/iono/GGTO/RTCM. (2) Live: confirm topics exist and `checkHaveEphem()` passes; `/gnss_obs_preprocessed` non-empty. (3) Regression: bag replay with nav+obs; assert factor counts and GGTO gating.

## 12. Next Actions (short list)
1) Implement SBF parsers + msgs for `GPSNav`/`GALNav` (+ iono/GGTO/RTCM if available) and expose `publish.*` params.
2) Add Rx stream setup in `configureRx()` to request those blocks at 1 Hz.
3) Wire new subscriptions into `septentrio_preprocessor`, keep guards, and call `step()`.
4) Publish preprocessed outputs and validate on live data; fall back to external ephemeris provider only if Rx nav blocks are unavailable.

---

## Appendices

### A. Topic Mapping

| NovAtel Topic | Septentrio Topic | Equivalent? |
|---------------|------------------|-------------|
| `/novatel/oem7/range` | `/measepoch` | ✅ Yes (different format) |
| `/novatel/oem7/range_aux` | `/measepoch_aux` | ✅ Yes |
| `/novatel/oem7/bestpos` | `/pvtgeodetic` | ✅ Yes |
| `/novatel/oem7/bestvel` | `/velcovgeodetic` | ✅ Yes |
| `/novatel/oem7/dualantennaheading` | `/atteuler` | ✅ Yes |
| `/novatel/oem7/gpsephem` | ❌ N/A | **Missing** |
| `/novatel/oem7/galInavEphemeris` | ❌ N/A | **Missing** |
| `/novatel/oem7/galFnavEphemeris` | ❌ N/A | **Missing** |
| `/novatel/oem7/ionutc` | ❌ N/A | **Missing** |
| `/novatel/oem7/galiono` | ❌ N/A | **Missing** |
| `/novatel/oem7/galclock` | ❌ N/A | **Missing** |

### B. File References

- NovAtel implementation: `src/impl/novatel_oem7_preprocessor.{h,cpp}`
- Septentrio implementation: `src/impl/septentrio_preprocessor.{h,cpp}`
- Septentrio driver: `septentrio_gnss_driver/` package
- Base class: `include/irt_gnss_preprocessing/gnss_preprocessor.h`
- Status docs: `SEPTENTRIO_VS_NOVATEL.md`, `P1_IMPLEMENTATION_COMPLETE.md`

### C. Key Contacts

- Package maintainer: h.zhang@irt.rwth-aachen.de
- Septentrio driver: githubuser@septentrio.com
- GNSS integration team: [Add contact]
