# Septentrio Mosaic-H Integration Summary

## Overview
Successfully integrated Septentrio Mosaic-H receiver support into the `irt_gnss_preprocessing` package following the existing plugin-based architecture.

## Date Completed
December 8, 2025

## Files Created

### 1. Header Files
- **`include/irt_gnss_preprocessing/impl/septentrio_types.h`** (84 lines)
  - PVT mode and error constants
  - Helper functions for mode/error string conversion
  - Mapping between Septentrio codes and internal representation

- **`include/irt_gnss_preprocessing/impl/septentrio_preprocessor.h`** (127 lines)
  - Main SeptentrioPreProcessor class inheriting from GNSSPreprocessor
  - Message subscribers for MeasEpoch, PVTGeodetic, covariances, ReceiverTime
  - Dual antenna support (conditional compilation with USE_DUAL_ANTENNA)
  - Circular buffers for temporal data management
  - Message synchronization using message_filters

### 2. Implementation Files
- **`src/impl/septentrio_preprocessor.cpp`** (350+ lines)
  - `initialize()` - Sets up subscribers, buffers, and synchronization
  - `onMeasEpochMainCb()` - Processes raw GNSS measurements
  - `onSolutionMsgCb()` - Handles synchronized PVT/covariance messages
  - `onReceiverTimeCb()` - Manages leap second information
  - `convertMeasEpochToRaw()` - Converts Septentrio MeasEpoch to gnssraw_measurement_t
  - `convertPVTGeodetic()` - Converts Septentrio PVTGeodetic to gnssraw_pvt_geodetic_t
  - Dual antenna callbacks (if enabled): MeasEpoch aux, Attitude, Baseline

### 3. Configuration Files
- **`config/septentrio_preprocessing.yaml`** (93 lines)
  - General preprocessing parameters (buffer sizes, print duration)
  - GNSS signal selection (GPS L1/L2/L5, Galileo E1/E5a/E5b/E6, etc.)
  - RTK/DGNSS parameters
  - Measurement quality thresholds (min CN0, elevation, correction age)
  - Cycle slip detection settings
  - Ionosphere/troposphere correction flags
  - Outlier rejection (chi-square, RAIM)
  - Dual antenna configuration (baseline length, variances)
  - Septentrio-specific parameters (topic names, accepted PVT modes, accuracy thresholds)
  - Factor Graph Optimization settings

### 4. Launch Files
- **`launch/septentrio_preprocessor.launch.py`** (103 lines)
  - Launches irt_gnss_preprocessing_node with Septentrio configuration
  - Launch arguments: config_file, use_sim_time, log_level
  - Topic remapping for Septentrio driver messages
  - Output topic configuration

## Files Modified

### 1. Package Configuration
- **`package.xml`**
  - Added `<depend>septentrio_gnss_driver</depend>` dependency

### 2. Build Configuration
- **`CMakeLists.txt`**
  - Added `find_package(septentrio_gnss_driver REQUIRED)`
  - Added `septentrio_gnss_driver` to AMENT_DEPENDENCIES
  - Added `src/impl/septentrio_preprocessor.cpp` to library sources

### 3. Plugin Registry
- **`irt_gnss_preprocessing_plugins.xml`**
  - Registered SeptentrioPreProcessor plugin with pluginlib
  - Description: "GNSS Preprocessor for Septentrio Mosaic-H receiver of IRT RWTH Aachen"

## Key Features Implemented

### Message Handling
1. **Raw Measurements (MeasEpoch)**
   - Converts Septentrio MeasEpoch messages to internal gnssraw_measurement_t format
   - Handles pseudorange reconstruction (MSB + LSB components)
   - Processes Doppler measurements
   - Reconstructs carrier phase from MSB/LSB
   - Extracts CN0 and lock time
   - Supports multiple signal types per satellite (up to 5)

2. **GNSS Solutions (PVTGeodetic + Covariances)**
   - Synchronizes PVTGeodetic, PosCovGeodetic, VelCovGeodetic messages
   - Converts position (latitude, longitude, height) and velocity (Vn, Ve, Vu)
   - Maps Septentrio PVT modes to internal codes:
     * NO_SOLUTION → 0
     * STANDALONE → 1
     * DIFFERENTIAL → 2
     * RTK_FLOAT → 5
     * RTK_FIXED → 4
     * SBAS_AIDED → 6
     * PPP → 10
   - Extracts receiver clock bias/drift
   - Computes position/velocity variances from accuracy fields
   - Stores RTK reference station ID and correction age

3. **Time Synchronization**
   - Manages receiver time and leap seconds
   - Uses message_filters for approximate time synchronization
   - Configurable inter-message lower bounds

4. **Dual Antenna Support** (conditional compilation)
   - Auxiliary antenna measurements
   - Attitude (heading, pitch, roll) from dual antenna baseline
   - Baseline vector (dN, dE, dU)
   - Double-differenced measurements for heading determination

### Architecture Highlights
- **Plugin-based**: Uses ROS2 pluginlib for dynamic loading
- **Circular buffers**: Thread-safe temporal data storage
- **Message synchronization**: ApproximateTime policy for multi-topic sync
- **Modular design**: Follows NovatelOEM7PreProcessor pattern
- **Preprocessor integration**: Interfaces with GTSAM-based GNSS preprocessing algorithms

## Known Limitations

### 1. Ephemeris Messages
**Issue**: The Septentrio driver does not provide GPS/Galileo ephemeris messages (navigation data).

**Impact**: 
- Cannot compute satellite positions/clocks internally
- Limits tight-coupling capabilities
- May require external ephemeris sources (IGS BRDC files) or loosely-coupled mode

**Workarounds**:
1. Use loosely-coupled mode (rely on receiver's PVT solutions)
2. Download external ephemeris from IGS/BRDC services
3. Future enhancement: Add ephemeris extraction from Septentrio SBF blocks

### 2. Signal Type Mapping
The current implementation uses a simplified signal type mapping. The Septentrio MeasEpoch `type` field needs careful validation against:
- GPS L1 C/A, L1P, L2P, L2C, L5
- Galileo E1, E5a, E5b, E6
- BeiDou B1, B2, B3
- GLONASS L1, L2

### 3. Measurement Array Indexing
The gnssraw_measurement_t structure uses a fixed layout (5 signals per satellite). Verify this matches the preprocessing algorithm expectations.

## Build Status
✅ **SUCCESS** - Package builds without errors
- Minor warnings (member initialization order) do not affect functionality
- All plugin exports configured correctly
- Configuration and launch files installed properly

## Testing Recommendations

### 1. Plugin Loading Test
```bash
source /workspace/fgo_ws/install/setup.bash
ros2 run irt_gnss_preprocessing irt_gnss_preprocessing_node --ros-args \
  -p GNSSPreprocessor.receiver_type:=septentrio \
  --params-file /workspace/fgo_ws/install/irt_gnss_preprocessing/share/irt_gnss_preprocessing/config/septentrio_preprocessing.yaml
```

### 2. Launch File Test
```bash
source /workspace/fgo_ws/install/setup.bash
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py
```

### 3. Message Flow Test
With Septentrio driver running:
```bash
# Terminal 1: Start Septentrio driver
ros2 launch septentrio_gnss_driver <your_septentrio_launch_file>

# Terminal 2: Start preprocessor
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py

# Terminal 3: Monitor outputs
ros2 topic echo /gnss/septentrio/pvt_geodetic
ros2 topic echo /gnss/septentrio/preprocessed_obs
```

### 4. Integration Test with FGO
Test the full pipeline: Septentrio driver → Preprocessing → Factor Graph Optimization

## Next Steps

### Short-term
1. Test with live Septentrio Mosaic-H receiver
2. Validate message conversions with real data
3. Fine-tune preprocessing parameters (CN0 thresholds, elevation masks)
4. Verify RTK baseline computations

### Medium-term
1. Add ephemeris handling (external RINEX/BRDC files or SBF extraction)
2. Implement signal type validation and mapping table
3. Add dual antenna heading integration
4. Optimize buffer sizes based on actual data rates

### Long-term
1. Add Septentrio-specific quality indicators (e.g., receiver status, DOP)
2. Support for multi-frequency multi-GNSS tight coupling
3. Integration with RTK base station corrections
4. PPP support with external clock/orbit products

## References
- Integration plan: `plan-septentrioMosaicHIntegration.md`
- Preprocessing documentation: `preprocess_irt.md`
- Septentrio driver: `/workspace/fgo_ws/src/gnssFGO/septentrio_gnss_driver`
- NovAtel reference: `impl/novatel_oem7_preprocessor.{h,cpp}`

## Contributors
- Integration implemented: December 8, 2025
- Based on existing architecture by Haoming Zhang (h.zhang@irt.rwth-aachen.de)
- Institute of Automatic Control, RWTH Aachen University
