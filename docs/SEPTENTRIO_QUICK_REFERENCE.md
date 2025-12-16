# Septentrio Mosaic-H Quick Reference Card

**Date**: December 8, 2025 | **Package**: irt_gnss_preprocessing

---

## Quick Start Commands

### 1. Build System
```bash
# Build driver + preprocessing
cd /workspace/fgo_ws
colcon build --packages-select septentrio_gnss_driver irt_gnss_preprocessing
source install/setup.bash
```

### 2. Launch System
```bash
# Single Antenna
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py

# Dual Antenna (requires rebuild with -DUSE_DUAL_ANTENNA=ON)
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  config_file:=install/irt_gnss_preprocessing/share/irt_gnss_preprocessing/config/septentrio_preprocessing_dual.yaml
```

### 3. Quick Health Check
```bash
# Check all topics are publishing
ros2 topic list | grep -E "(septentrio|gnss)"

# Verify message rates (should be ~10 Hz)
ros2 topic hz /septentrio/pvtgeodetic

# Check positioning mode
ros2 topic echo /septentrio/pvtgeodetic --field mode
# 0=No solution, 1=Standalone, 4=RTK Fixed, 5=RTK Float, 10=PPP
```

---

## Key Configuration Parameters

### config/septentrio_preprocessing.yaml

| Parameter | Default | Adjust For | Effect |
|-----------|---------|------------|--------|
| `min_cn0` | 25.0 | Urban: 30-35<br>Forest: 20-25 | Higher = fewer satellites, less multipath |
| `min_elevation` | 10.0 | Urban: 15-20<br>Open: 5-10 | Higher = better geometry, fewer sats |
| `use_rtk` | true | No base: false | Enable/disable RTK processing |
| `max_age_correction` | 30.0 | Long baseline: 60<br>Short: 10 | Max age of RTK corrections (sec) |
| `baseline_length` | 1.0 | Measured | Distance between antennas (m) |

---

## Topic Reference

### Input Topics (from Septentrio driver)
| Topic | Rate | Description |
|-------|------|-------------|
| `/septentrio/measepoch` | 10 Hz | Raw GNSS measurements |
| `/septentrio/pvtgeodetic` | 10 Hz | Position/velocity/time solution |
| `/septentrio/poscovgeodetic` | 10 Hz | Position covariance |
| `/septentrio/velcovgeodetic` | 10 Hz | Velocity covariance |
| `/septentrio/receivertime` | 1 Hz | Receiver time/leap seconds |
| `/septentrio/atteuler` | 10 Hz | Attitude (dual antenna) |
| `/septentrio/basevectorgeod` | 10 Hz | Baseline vector (dual antenna) |

### Output Topics (from preprocessing)
| Topic | Rate | Description |
|-------|------|-------------|
| `/gnss/septentrio/pvt_geodetic` | 10 Hz | Processed PVT |
| `/gnss/septentrio/raw_measurements` | 10 Hz | Filtered raw measurements |
| `/gnss/septentrio/preprocessed_obs` | 10 Hz | Preprocessed observations |
| `/gnss/septentrio/factors` | 10 Hz | GNSS factors for FGO |

---

## PVT Mode Codes

| Code | Name | Accuracy | Description |
|------|------|----------|-------------|
| 0 | NO_SOLUTION | N/A | No position fix |
| 1 | STANDALONE | 1-5m | Standard GPS positioning |
| 2 | DIFFERENTIAL | 0.5-3m | SBAS or DGNSS corrections |
| 4 | RTK_FIXED | 1-2cm | RTK with fixed ambiguities (best) |
| 5 | RTK_FLOAT | 10-50cm | RTK with float ambiguities |
| 6 | SBAS_AIDED | 1-3m | SBAS augmentation |
| 10 | PPP | 5-10cm | Precise Point Positioning |

---

## Quick Diagnostics

### Problem: No Position Fix
```bash
# Check satellite count
ros2 topic echo /septentrio/pvtgeodetic --field nr_sv
# Need: >4 satellites

# Check error code
ros2 topic echo /septentrio/pvtgeodetic --field error
# 0=OK, 1=Not enough measurements, 3=DOP too large
```

### Problem: No RTK Fix
```bash
# Check correction age
ros2 topic echo /septentrio/pvtgeodetic --field mean_corr_age
# Should be: <3000 (30 seconds), NOT 0 or 65535

# Check reference station ID
ros2 topic echo /septentrio/pvtgeodetic --field reference_id
# Should match your base station, NOT 0
```

### Problem: Poor Dual Antenna Heading
```bash
# Check baseline mode
ros2 topic echo /septentrio/basevectorgeod --field vector_info_geod[0].mode
# Need: 4 (RTK fixed), NOT 5 (float) or 0 (no solution)

# Check heading uncertainty
ros2 topic echo /septentrio/atteuler --field heading_std
# Should be: <1.0 degree for 1m baseline
```

---

## Data Recording

### Record All Data (30 seconds)
```bash
ros2 bag record -o test_$(date +%Y%m%d_%H%M%S) \
  /septentrio/measepoch \
  /septentrio/pvtgeodetic \
  /septentrio/poscovgeodetic \
  /septentrio/velcovgeodetic \
  /gnss/septentrio/pvt_geodetic \
  /gnss/septentrio/preprocessed_obs \
  --duration 30
```

### Record Dual Antenna Data
```bash
ros2 bag record -o dual_ant_test_$(date +%Y%m%d_%H%M%S) \
  /septentrio/atteuler \
  /septentrio/basevectorgeod \
  /septentrio/pvtgeodetic \
  --duration 60
```

---

## Performance Monitoring

### CPU Usage
```bash
# Check preprocessing CPU
top -p $(pgrep -f septentrio_gnss_preprocessing)
# Typical: 5-15% on modern CPU
```

### Message Latency
```bash
# Check end-to-end delay
ros2 topic delay /gnss/septentrio/pvt_geodetic
# Target: <10ms
```

### Memory Usage
```bash
# Check memory consumption
ps aux | grep septentrio_gnss_preprocessing | awk '{print $6/1024 " MB"}'
# Typical: 50-200 MB
```

---

## Environment-Specific Presets

### Urban Canyon
```yaml
min_cn0: 30.0
min_elevation: 15.0
enable_raim: true
raim_threshold: 5.0
use_carrier_smoothing: true
```

### Forest/Tree Cover
```yaml
min_cn0: 20.0
min_elevation: 5.0
min_satellites: 5
use_carrier_smoothing: true
```

### Open Sky (Highway)
```yaml
min_cn0: 30.0
min_elevation: 10.0
enable_ionosphere_correction: true
enable_troposphere_correction: true
```

---

## Hardware Connection Quick Check

### Antenna
```
✓ Secure mounting (no wobble)
✓ Clear sky view (>270° horizon)
✓ Cable: <50m, tight connectors
✓ Power indicator LED on receiver
```

### Power
```
✓ Voltage: 9-36V DC
✓ Current: <5W
✓ Stable (no brown-outs during boot)
```

### Communication
```
✓ Serial: 115200 baud, 8N1
  OR
✓ Ethernet: 192.168.3.1, ping successful
```

---

## Emergency Recovery

### Receiver Not Responding
```bash
# 1. Power cycle receiver (wait 10 seconds)
# 2. Check LED status
# 3. Factory reset via web interface: http://192.168.3.1
#    Settings → System → Factory Reset
# 4. Reconfigure SBF output blocks
```

### Preprocessing Node Crash
```bash
# 1. Check logs
cat ~/.ros/log/latest/septentrio_gnss_preprocessing*.log | tail -50

# 2. Restart with debug logging
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  log_level:=debug

# 3. Verify configuration file syntax
yamllint config/septentrio_preprocessing.yaml
```

---

## Useful ROS2 Commands

```bash
# List all nodes
ros2 node list

# Node details
ros2 node info /septentrio_gnss_preprocessing

# Get parameter value
ros2 param get /septentrio_gnss_preprocessing GNSSPreprocessor.min_cn0

# Set parameter value (temporary)
ros2 param set /septentrio_gnss_preprocessing GNSSPreprocessor.min_cn0 30.0

# Monitor logs
ros2 run rqt_console rqt_console

# Plot topics
ros2 run rqt_plot rqt_plot /septentrio/pvtgeodetic/nr_sv
```

---

## Signal Constellation Codes

| Code | Constellation | Frequencies |
|------|---------------|-------------|
| GPS | US GPS | L1 (1575 MHz), L2 (1227 MHz), L5 (1176 MHz) |
| GAL | EU Galileo | E1 (1575 MHz), E5a (1176 MHz), E5b (1207 MHz), E6 (1278 MHz) |
| BDS | China BeiDou | B1 (1561 MHz), B2 (1207 MHz), B3 (1268 MHz) |
| GLO | Russia GLONASS | L1 (~1602 MHz), L2 (~1246 MHz) |

---

## Contact & Support

- **Integration Docs**: `SEPTENTRIO_DETAILED_GUIDE.md`
- **Testing Guide**: `SEPTENTRIO_HARDWARE_TESTING_GUIDE.md`
- **Summary**: `SEPTENTRIO_INTEGRATION_SUMMARY.md`
- **Quick Start**: `SEPTENTRIO_QUICKSTART.md`

**Package Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/`

---

*Last Updated: December 8, 2025*
