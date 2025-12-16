# Septentrio Preprocessing Implementation Status

**Date**: December 9, 2025  
**Package**: irt_gnss_preprocessing

## Summary

Implementation of P1 (preprocessing execution) is **COMPLETE** but **BLOCKED** on ephemeris data availability.

## What Was Implemented (P1)

✅ **Preprocessing Execution Pipeline**
- Added `executePreprocessing()` method with full input assembly
- Wired `gnss_preprocessor_->step()` call in `onMeasEpochMainCb()`
- Added parameter loading from YAML (uses base class `getGNSSParameters()`)
- Implemented guards for missing ephemeris/ionosphere/GGTO data
- Added `checkHaveEphem()` template for GPS/GAL ephemeris validation
- Supports both single-antenna and dual-antenna (#if USE_DUAL_ANTENNA) modes
- Added periodic logging of preprocessing stats (every 10 epochs)
- Warns gracefully when required navigation data is missing

## Critical Blocker: No Ephemeris Messages

### The Problem
Unlike NovAtel OEM7 which publishes:
- `GPSEPHEM` → GPS ephemeris
- `GALINAVEPHEMERIS` / `GALFNAVEPHEMERIS` → Galileo ephemeris
- `IONUTC` → GPS ionospheric correction
- `GALIONO` → Galileo ionospheric correction
- `GALCLOCK` → GGTO (Galileo-GPS Time Offset)

**Septentrio driver does NOT expose these as ROS messages.**

The Septentrio driver only publishes:
- `MeasEpoch` (raw observations)
- `PVTGeodetic` (position/velocity solution - already computed by receiver)
- `PosCovGeodetic` / `VelCovGeodetic` (covariances)
- `AttEuler` / `BaseVectorGeod` (dual-antenna attitude/baseline)
- `ReceiverTime` (leap seconds)

### Why This Matters
The preprocessing Simulink models (`GNSS_preprocessingModelClass`, `GNSSPreProcessingDualAntenna`) **require**:
1. **Ephemeris data** to compute satellite positions/velocities
2. **Ionospheric models** for ionospheric delay corrections
3. **Clock corrections** for inter-system time offsets (GGTO)

Without these, the preprocessing model:
- Cannot compute satellite positions → drops all observations
- Cannot apply corrections → reduced accuracy
- Cannot merge GPS/Galileo → single-constellation only

### Current Behavior
The implementation will:
1. Convert `MeasEpoch` → `gnssraw_measurement_t` ✅
2. Check for GPS ephemeris → **FAIL (no data)** ❌
3. Log warning: *"GPS enabled but no ephemeris data received yet"*
4. Return early without calling `step()`

**Result**: No preprocessed observations published, only raw PVT from receiver.

## Solution Options

### Option 1: External Ephemeris Source (RECOMMENDED)
**Add a separate ROS2 node that provides ephemeris/ionosphere data**

**Sources**:
- **Broadcast Ephemeris (BRDC)**: Download from IGS (ftp://igs.bkg.bund.de/IGS/BRDC/)
- **Receiver Internal**: Some Septentrio commands may expose nav data (needs investigation)
- **RTCM Messages**: If base station provides RTCM 1019 (GPS), 1045/1046 (GAL)

**Implementation**:
1. Create `ephemeris_provider_node` that:
   - Downloads/reads BRDC files
   - Parses GPS/GAL ephemeris
   - Converts to `gnssraw_gps_nav_t`, `gnssraw_gal_nav_t`
   - Publishes to topics (e.g., `/gps_ephemeris`, `/gal_ephemeris`)
2. Septentrio preprocessor subscribes to these topics
3. Fills ephemeris buffers from external source

**Pros**: Clean separation, works with any GNSS receiver  
**Cons**: Additional node, latency in ephemeris updates

### Option 2: Septentrio Driver Extension
**Modify `septentrio_gnss_driver` to extract and publish nav data**

**Investigation needed**:
- Check if Septentrio SBF format includes raw ephemeris blocks (GPSNav, GALNav, etc.)
- If yes, add message definitions and publishers to driver
- If no, this option is not viable

**Pros**: Native integration, low latency  
**Cons**: Driver modification required, depends on receiver capabilities

### Option 3: Use Receiver-Computed PVT Only (CURRENT STATE)
**Accept limitation: no factor-graph-level GNSS corrections**

**What works**:
- Septentrio computes PVT internally (with ephemeris/iono/clock)
- Driver publishes `PVTGeodetic` → converted to `irt_nav_msgs/PVAGeodetic`
- FGO can use PVT as position prior or loose GNSS factor

**What doesn't work**:
- No raw pseudorange/carrier-phase factors
- No satellite-level integrity monitoring
- No multi-path detection at preprocessing stage
- RTK/DD preprocessing unused
- Dual-antenna preprocessing unused

**Pros**: Works immediately, no additional development  
**Cons**: Reduced GNSS integration quality, most preprocessing features idle

### Option 4: Hybrid Approach
**Use receiver PVT for coarse positioning, wait for ephemeris for fine processing**

1. Publish PVT immediately (already working)
2. When ephemeris becomes available (Option 1 or 2), enable preprocessing
3. Switch FGO to use preprocessed obs when quality improves

**Pros**: Gradual degradation, works in both modes  
**Cons**: Complex mode switching, requires both paths

## Recommended Path Forward

### Phase 1: External Ephemeris Provider (Next 2-3 days)
1. Create `gnss_ephemeris_provider` package
2. Implement BRDC file parser (use existing GNSS libraries: GPSTk, RTKLIB)
3. Publish ephemeris on standard topics
4. Connect Septentrio preprocessor to these topics

### Phase 2: Complete P2-P5 (After ephemeris available)
2. **P2**: Subscribe to ephemeris topics, add converters ✅ (ready to implement)
3. **P3**: RTCM subscription (if base station available)
4. **P4**: Dual-antenna wiring (if using Mosaic-H dual setup)
5. **P5**: Integrity/LOS filtering
6. **P6**: Output publishing (GNSSObsPreProcessed, LS PVT, residuals)

### Phase 3: Validation
7. Test with static data
8. Test with RTK corrections
9. Compare against NovAtel preprocessing quality

## Current Code Status

### Files Modified
- `septentrio_preprocessor.h`: Added `executePreprocessing()`, `checkHaveEphem()`
- `septentrio_preprocessor.cpp`: Implemented full preprocessing pipeline with guards

### What Compiles
All code compiles cleanly. The implementation is feature-complete for P1 but will skip preprocessing at runtime due to missing ephemeris.

### What Runs
- ✅ MeasEpoch conversion
- ✅ PVT conversion and publishing
- ⚠️ Preprocessing execution (skipped with warning)
- ❌ Preprocessed obs publishing (no data to publish)

## Testing Instructions

### Build
```bash
cd /workspace/fgo_ws
colcon build --packages-select irt_gnss_preprocessing
source install/setup.bash
```

### Run
```bash
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py
```

### Expected Behavior
- Subscribes to `/measepoch`, `/pvtgeodetic`, etc.
- Publishes `/PVT` (receiver solution) ✅
- Logs every 5s: *"GPS enabled but no ephemeris data received yet"*
- No `/gnss_obs_preprocessed` published (waiting for ephemeris)

### To Verify
```bash
# Check topics
ros2 topic list | grep -E "(measepoch|pvt|gnss_obs)"

# Monitor PVT output
ros2 topic echo /PVT

# Check for warnings
ros2 topic echo /rosout | grep -i ephemeris
```

## Next Steps

**Immediate**: Decide on Option 1, 2, 3, or 4 above.

**If Option 1 (External Ephemeris)**:
1. Research BRDC parser libraries
2. Design ephemeris ROS message format (or reuse existing)
3. Implement provider node
4. Complete P2 implementation

**If Option 3 (PVT-only)**:
1. Document limitation in FGO integration guide
2. Configure FGO to use PVT factors instead of raw obs
3. Accept reduced accuracy

## References
- Septentrio SBF Reference: https://www.septentrio.com/en/support/software/sbf
- IGS BRDC files: ftp://igs.bkg.bund.de/IGS/BRDC/
- RTKLIB (ephemeris parsing): https://github.com/tomojitakasu/RTKLIB
- GPSTk library: https://github.com/SGL-UT/GPSTk
