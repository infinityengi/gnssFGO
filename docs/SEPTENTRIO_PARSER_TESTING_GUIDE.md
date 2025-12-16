# Septentrio SBF Parser Testing Guide

**Date**: December 15, 2025  
**Author**: IRT GNSS Preprocessing Team  
**Status**: Ready for Testing

---

## Overview

This document provides comprehensive testing procedures for the 5 newly implemented Septentrio SBF binary parsers:

| Block Name | SBF ID | Topic Name | Message Type |
|-----------|--------|------------|--------------|
| GPSNav | 5891 | `/gpsephem` | GPSEPHEM |
| GALNav | 4002 | `/galfnavephem` | GALFNAVEPHEMERIS |
| GPSIon | 5893 | `/gpsion` | IONUTC |
| GALIon | 4030 | `/galion` | GALIONO |
| GALGstGps | 4032 | `/galclock` | GALCLOCK |

---

## Prerequisites

### Infrastructure Verification

Run the validation script to ensure all components are properly integrated:

```bash
cd /workspace/fgo_ws
bash src/gnssFGO/scripts/validate_septentrio_parsers.sh
```

**Expected Output**: All 28 checks should pass.

### Hardware Requirements

- Septentrio Mosaic-H GNSS receiver
- Network connection (Ethernet or USB)
- Clear sky view with GPS + Galileo satellites

### Software Requirements

- ROS2 Humble workspace built successfully
- `septentrio_gnss_driver` package compiled
- `novatel_oem7_msgs` dependency installed

---

## Testing Approach

### Option 1: Live Receiver Testing (Recommended)

#### Step 1: Connect to Receiver

Configure network settings to connect to receiver (default IP: `192.168.3.1`):

```bash
# Check connection
ping 192.168.3.1
```

#### Step 2: Configure Receiver to Output SBF Blocks

Connect via web interface (`http://192.168.3.1`) or serial console and execute:

```
setSBFOutput, Stream1, Ethernet, +GPSNav+GALNav+GPSIon+GALIon+GALGstGps, OnChange
saveConfig
```

**What this does**:
- Enables all 5 navigation product blocks
- Outputs to Stream1 (typically IP port)
- `OnChange` = publishes when data updates (not at high rate)

**Alternative via RxTools CLI**:
```bash
# Connect via telnet
telnet 192.168.3.1

# Execute commands
setSBFOutput, Stream1, Ethernet, +GPSNav
setSBFOutput, Stream1, Ethernet, +GALNav
setSBFOutput, Stream1, Ethernet, +GPSIon
setSBFOutput, Stream1, Ethernet, +GALIon
setSBFOutput, Stream1, Ethernet, +GALGstGps
saveConfig
```

#### Step 3: Launch ROS2 Driver

```bash
cd /workspace/fgo_ws
source install/setup.bash
ros2 launch septentrio_gnss_driver rover.launch.py
```

#### Step 4: Verify Topics Are Publishing

Open a new terminal and monitor topics:

```bash
# Check if topics exist
ros2 topic list | grep -E 'gpsephem|galfnav|gpsion|galion|galclock'

# Expected output:
# /gpsephem
# /galfnavephem
# /gpsion
# /galion
# /galclock
```

#### Step 5: Monitor Topic Data

Check GPS ephemeris messages:
```bash
ros2 topic echo /gpsephem
```

**Expected Output Example**:
```yaml
header:
  stamp:
    sec: 1734287400
    nanosec: 250000000
  frame_id: 'gnss'
block_header:
  sync_1: 36
  sync_2: 64
  crc: 1234
  id: 5891
  length: 140
nov_header:
  gps_week: 2345
  gps_millisecs: 432000000
  # ... other fields
prn: 15
wn: 2345
tow: 432000.0
af0: -0.000123456
af1: 1.23e-12
af2: 0.0
# ... other orbital elements
```

Check Galileo navigation:
```bash
ros2 topic echo /galfnavephem
```

Check ionosphere models:
```bash
ros2 topic echo /gpsion
ros2 topic echo /galion
```

Check time offset:
```bash
ros2 topic echo /galclock
```

#### Step 6: Validate Message Rates

```bash
# Check publishing frequency (should be low for nav products)
ros2 topic hz /gpsephem
# Expected: ~0.033 Hz (once per 30 seconds typical)

ros2 topic hz /galfnavephem
# Expected: ~0.1 Hz (once per 10 seconds typical)

ros2 topic hz /gpsion
# Expected: ~0.016 Hz (once per minute typical)
```

#### Step 7: Verify Message Content

**GPS Ephemeris Validation**:
- `prn`: Should be 1-32 for GPS
- `wn`: GPS week number (should match current week, ~2345 as of Dec 2024)
- `tow`: Time of week in seconds (0-604800)
- `health`: Should be 0 for healthy satellites
- `sqrt_a`: Square root of semi-major axis (~5153 m^0.5 for GPS)

**Galileo Ephemeris Validation**:
- `svid`: Should be 1-36 for Galileo
- `source`: Bit flags indicating I/NAV (bit 0) or F/NAV (bit 1)
- `iodnav`: Issue of Data (0-1023)
- `sqrt_a`: ~5440 m^0.5 for Galileo

**GPS Ionosphere Validation**:
- `alpha_0` through `alpha_3`: Klobuchar alpha coefficients
- `beta_0` through `beta_3`: Klobuchar beta coefficients
- All values should be non-zero and realistic

**Galileo Ionosphere Validation**:
- `ai0`, `ai1`, `ai2`: NeQuick model coefficients
- Storm flags should be 0 or 1

**Time Offset Validation**:
- `a_0g`: GPS-Galileo time offset (typically small, ±10 ns)
- `a_1g`: Drift rate (very small)

---

### Option 2: SBF Log File Testing

#### Step 1: Obtain SBF Log Files

If you have recorded SBF log files from a Septentrio receiver:

```bash
# Place log file in workspace
cp /path/to/your/logfile.sbf /workspace/fgo_ws/data/
```

#### Step 2: Play Back Log File

Use the receiver's playback capability or network streaming:

```bash
# Example: Stream SBF file to TCP port 28785
nc -l -p 28785 < /workspace/fgo_ws/data/logfile.sbf
```

Configure `rover.yaml` to connect to localhost:28785 and launch driver.

#### Step 3: Verify Message Output

Follow Steps 4-7 from Option 1.

---

### Option 3: Synthetic Test Data (For Unit Testing)

If you need to test parsers without hardware:

#### Step 1: Create Synthetic SBF Block Generator

See `scripts/generate_synthetic_sbf.py` (to be created) that generates:
- Valid SBF block structure (sync bytes, CRC, header)
- Realistic navigation data values
- Proper little-endian encoding

#### Step 2: Inject Test Data

Stream synthetic blocks to driver via TCP socket.

#### Step 3: Verify Parser Output

Confirm parsers correctly decode synthetic data.

---

## Validation Checklist

### ✅ Pre-Flight Checks

- [ ] Validation script passes all 28 checks
- [ ] ROS2 workspace builds without errors
- [ ] Configuration file `rover.yaml` has all 5 publish flags set to `true`
- [ ] Receiver is powered and connected

### ✅ Runtime Checks

- [ ] All 5 topics appear in `ros2 topic list`
- [ ] Topic message types match expected types
- [ ] Messages publish at reasonable rates (not too fast/slow)
- [ ] No parser errors in driver logs (`RCLCPP_ERROR` messages)

### ✅ Data Quality Checks

- [ ] GPS ephemeris: PRN values 1-32, reasonable orbital elements
- [ ] Galileo ephemeris: SVID values 1-36, source bits valid
- [ ] GPS ionosphere: 8 Klobuchar coefficients present
- [ ] Galileo ionosphere: 3 NeQuick coefficients + storm flags
- [ ] Time offset: Realistic A_0G and A_1G values

### ✅ Integration Checks

- [ ] Messages include valid `block_header` fields
- [ ] Messages include valid `nov_header` fields from Oem7Header type
- [ ] Timestamps are synchronized with GPS time
- [ ] No memory leaks or crashes during extended operation

---

## Troubleshooting

### Problem: Topics Not Appearing

**Cause**: Publish flags disabled in configuration

**Solution**:
```bash
# Check rover.yaml
grep -E 'gpsephem|galfnav|gpsion|galion|galclock' \
  /workspace/fgo_ws/install/septentrio_gnss_driver/share/septentrio_gnss_driver/config/rover.yaml

# All should be set to 'true'
# If not, edit source config and rebuild:
nano /workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/septentrio_gnss_driver/config/rover.yaml
colcon build --packages-select septentrio_gnss_driver
```

### Problem: Parse Errors in Logs

**Symptom**: `RCLCPP_ERROR: parse error in GPSNav` (or similar)

**Causes**:
1. Incorrect block ID mapping
2. Binary parsing logic error
3. Corrupted data from receiver

**Debugging**:
```bash
# Enable verbose logging
export RCUTILS_CONSOLE_OUTPUT_FORMAT="[{severity}] [{name}]: {message}"
ros2 launch septentrio_gnss_driver rover.launch.py

# Check parser code in sbf_blocks.hpp
# Verify SBF IDs match receiver documentation
```

### Problem: No Messages Received

**Cause**: Receiver not configured to output blocks

**Solution**:
```bash
# Verify receiver configuration via web interface
# Check "SBF Output" tab and ensure blocks are enabled
# Verify IP/port match driver configuration
```

### Problem: Message Fields All Zero

**Cause**: Parser not extracting data correctly

**Solution**:
- Check `qiLittleEndianParser` usage in parser code
- Verify field sizes match SBF documentation (v4.15+)
- Add debug prints to parser to inspect raw bytes

---

## Expected Message Rates

Based on typical Septentrio receiver configuration:

| Message Type | Typical Rate | Notes |
|-------------|-------------|-------|
| GPS Ephemeris | 1 per 30s per satellite | Updates when new ephemeris broadcast |
| GAL Ephemeris | 1 per 10s per satellite | Updates when new ephemeris broadcast |
| GPS Ionosphere | 1 per minute | Updates infrequently |
| GAL Ionosphere | 1 per minute | Updates infrequently |
| GPS-GAL Time Offset | 1 per minute | Updates infrequently |

**Note**: Actual rates depend on satellite visibility and receiver configuration.

---

## Next Steps After Validation

Once all parsers are validated:

### 1. Integration with irt_gnss_preprocessing

Test that navigation products are consumed by preprocessing pipeline:

```bash
# Launch full preprocessing chain
ros2 launch irt_gnss_preprocessing preprocess.launch.py

# Verify ephemeris factors are created
# Check log output for ionosphere corrections applied
```

### 2. End-to-End FGO Testing

Run complete GNSS FGO with navigation products:

```bash
# Launch online FGO with rover data
ros2 launch online_fgo rover_fgo.launch.py

# Monitor factor graph size and optimization results
# Verify navigation product factors improve accuracy
```

### 3. Performance Benchmarking

Compare positioning accuracy with/without navigation products:
- Baseline: Using broadcast ephemeris from observations
- Enhanced: Using parsed SBF navigation products

---

## Reference Commands

### Quick Topic Monitoring

```bash
# All navigation topics at once
ros2 topic echo --once /gpsephem & \
ros2 topic echo --once /galfnavephem & \
ros2 topic echo --once /gpsion & \
ros2 topic echo --once /galion & \
ros2 topic echo --once /galclock &
```

### Topic Info

```bash
ros2 topic info /gpsephem
ros2 topic info /galfnavephem
ros2 topic info /gpsion
ros2 topic info /galion
ros2 topic info /galclock
```

### Message Type Inspection

```bash
ros2 interface show septentrio_gnss_driver/msg/GPSEPHEM
ros2 interface show septentrio_gnss_driver/msg/GALFNAVEPHEMERIS
ros2 interface show septentrio_gnss_driver/msg/IONUTC
ros2 interface show septentrio_gnss_driver/msg/GALIONO
ros2 interface show septentrio_gnss_driver/msg/GALCLOCK
```

### Logging

```bash
# Save topic data to bag file for later analysis
ros2 bag record /gpsephem /galfnavephem /gpsion /galion /galclock

# Play back recorded data
ros2 bag play <bagfile>
```

---

## Testing Status

**Current Status**: Infrastructure validated, ready for live testing

**Validation Results**:
- ✅ All 28 validation checks passed
- ✅ Package builds cleanly
- ✅ Configuration files updated
- ⏳ Awaiting live receiver or SBF log files

**Last Updated**: December 15, 2025

---

## Contacts

For issues or questions:
- Parser Implementation: See `BINARY_PARSER_IMPLEMENTATION_DAY3.md`
- Septentrio Documentation: SBF Reference Guide v4.15+
- ROS2 Integration: septentrio_gnss_driver package README

---

## Appendix: SBF Block Structures

### GPS Navigation Message (Block 5891, 140 bytes)

```
Offset | Field         | Type    | Size | Description
-------|---------------|---------|------|------------------
0      | TOW           | uint32  | 4    | Time of week (ms)
4      | WNc           | uint16  | 2    | GPS week number
6      | PRN           | uint8   | 1    | Satellite PRN (1-32)
7      | CAorPonY      | int8    | 1    | C/A or P on Y
8      | Health        | uint8   | 1    | SV health
9      | IODC          | uint16  | 2    | Issue of data clock
11     | IODE          | uint8   | 1    | Issue of data ephemeris
12     | t_oc          | uint32  | 4    | Clock correction epoch
16     | t_oe          | uint32  | 4    | Ephemeris epoch
20     | A             | double  | 8    | Semi-major axis (m)
28     | Delta_n       | double  | 8    | Mean motion difference
36     | M_0           | double  | 8    | Mean anomaly at reference
44     | e             | double  | 8    | Eccentricity
52     | sqrt_A        | double  | 8    | Square root of A
60     | OMEGA_0       | double  | 8    | Longitude of ascending node
68     | i_0           | double  | 8    | Inclination angle
76     | omega         | double  | 8    | Argument of perigee
84     | OMEGADOT      | double  | 8    | Rate of right ascension
92     | IDOT          | double  | 8    | Rate of inclination angle
100    | C_uc          | double  | 8    | Amplitude cos harmonic, lat
108    | C_us          | double  | 8    | Amplitude sin harmonic, lat
116    | C_rc          | double  | 8    | Amplitude cos harmonic, radius
124    | C_rs          | double  | 8    | Amplitude sin harmonic, radius
132    | C_ic          | double  | 8    | Amplitude cos harmonic, incl
140    | C_is          | double  | 8    | Amplitude sin harmonic, incl
```

### Galileo Navigation (Block 4002, 160 bytes)

Similar structure with additional fields for Galileo-specific parameters.

### GPS Ionosphere (Block 5893, 48 bytes)

```
Offset | Field   | Type   | Size | Description
-------|---------|--------|------|----------------------
0      | TOW     | uint32 | 4    | Time of week (ms)
4      | WNc     | uint16 | 2    | GPS week number
6      | PRN     | uint8  | 1    | Reference PRN
7      | Reserved| uint8  | 1    | Reserved
8      | alpha_0 | float  | 4    | Klobuchar alpha 0
12     | alpha_1 | float  | 4    | Klobuchar alpha 1
16     | alpha_2 | float  | 4    | Klobuchar alpha 2
20     | alpha_3 | float  | 4    | Klobuchar alpha 3
24     | beta_0  | float  | 4    | Klobuchar beta 0
28     | beta_1  | float  | 4    | Klobuchar beta 1
32     | beta_2  | float  | 4    | Klobuchar beta 2
36     | beta_3  | float  | 4    | Klobuchar beta 3
```

### Galileo Ionosphere (Block 4030, 36 bytes)

```
Offset | Field        | Type   | Size | Description
-------|--------------|--------|------|------------------
0      | TOW          | uint32 | 4    | Time of week (ms)
4      | WNc          | uint16 | 2    | Galileo week number
6      | Source       | uint8  | 1    | Data source
7      | ai0          | float  | 4    | NeQuick ai0
11     | ai1          | float  | 4    | NeQuick ai1
15     | ai2          | float  | 4    | NeQuick ai2
19     | StormFlags   | uint8  | 1    | Storm condition flags (5 bits)
```

### GAL-GPS Time Offset (Block 4032, 32 bytes)

```
Offset | Field   | Type   | Size | Description
-------|---------|--------|------|----------------------
0      | TOW     | uint32 | 4    | Time of week (ms)
4      | WNc     | uint16 | 2    | Galileo week number
6      | Source  | uint8  | 1    | Data source
7      | A_0G    | double | 8    | Constant term (s)
15     | A_1G    | double | 8    | Rate term (s/s)
23     | t_0G    | uint32 | 4    | Reference time
27     | WN_0G   | uint16 | 2    | Reference week
```

---

*End of Testing Guide*
