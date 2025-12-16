# Septentrio GNSS Driver Testing & Integration Guide

**Document Date:** December 10, 2025  
**Driver Version:** ROSaic v1.4.5  
**Hardware:** Septentrio MODIAC H  
**ROS2 Distro:** Humble  
**Status:** Implementation & Testing Phase

---

## Table of Contents

1. [Part 1: Driver Architecture & Analysis](#part-1-driver-architecture--analysis)
2. [Part 2: Software Architecture & Data Flow](#part-2-software-architecture--data-flow)
3. [Part 3: Hardware Testing Strategy](#part-3-hardware-testing-strategy)
4. [Part 4: Driver Launch & Verification](#part-4-driver-launch--verification)
5. [Part 5: Data Quality Validation](#part-5-data-quality-validation)
6. [Part 6: Integration with gnssFGO](#part-6-integration-with-gnssfgo)
7. [Part 7: Reliability & Stress Testing](#part-7-reliability--stress-testing)
8. [Part 8: Configuration Tuning](#part-8-configuration-tuning)
9. [Part 9: Troubleshooting & Recovery](#part-9-troubleshooting--recovery)
10. [Part 10: Testing Checklist & Next Steps](#part-10-testing-checklist--next-steps)

---

## Part 1: Driver Architecture & Analysis

### 1.1 ROSaic Driver Overview

**ROSaic = ROS + mosaic** - Professional-grade C++ driver for Septentrio GNSS/INS receivers

**Key Characteristics:**
- **Design Pattern:** Header-only flexible C++ implementation
- **License:** BSD 3-Clause
- **Maintainers:** Tibor Dome, Thomas Emter, Septentrio GmbH
- **Version:** v1.4.5 (latest stable)
- **ROS2 Support:** Humble (confirmed via package.xml)

### 1.2 Supported Hardware

**Septentrio MODIAC H Compatibility:**
- ✅ **Supported Hardware Family:** mosaic-X5, H, AsteRx-m3 confirmed
- ✅ **GNSS Capabilities:** Multi-constellation (GPS, GLONASS, Galileo, BeiDou, QZSS)
- ✅ **INS Integration:** Optional 9-DoF IMU
- ✅ **RTK Support:** Dual-antenna heading, Real-Time Kinematics
- ✅ **Security:** OSNMA (Open Service Navigation Message Authentication)
- ✅ **Advanced Features:** AIM+ (Adaptive Interference Mitigation)

### 1.3 Firmware Requirements

**Minimum Firmware Versions:**
- **GNSS Module:** ≥ 4.10.0 (supports OSNMA, enhanced RTK)
- **INS Module:** ≥ 1.3.2 (if applicable for MODIAC H)
- **Web Interface:** Must support JSON RPC 2.0 API

**Hardware Connection:**
- **Default IP:** 192.168.3.1 (via RNDIS USB virtual Ethernet)
- **Data Port:** TCP 28784 (primary data stream)
- **Fallback:** Serial 921600 baud (/dev/ttyACM0 or /dev/ttyACM1)

### 1.4 Driver Dependencies

```
Primary Dependencies (ROS2):
├── rclcpp (ROS2 C++ client library)
├── rclcpp_components (component container)
├── rosidl (ROS Interface Definition Language)
├── sensor_msgs (standard sensor message definitions)
├── nav_msgs (navigation message definitions)
├── geometry_msgs (geometric message definitions)
├── tf2 (transform library)
├── diagnostic_msgs (diagnostics aggregator)
└── nmea_msgs (NMEA sentence definitions)

External Dependencies:
├── boost (utility library)
├── libpcap (packet capture - for advanced datagram analysis)
├── geographiclib (geographic coordinate transformations)
├── geographic_lib_data (map database)
└── Eigen (linear algebra, implicit via dependencies)
```

### 1.5 Driver Output Messages

**Primary Topics Published:**

| Topic | Message Type | Update Rate | Content |
|-------|-------------|------------|---------|
| `/gpsfix` | `gps_msgs/GPSFix` (extended) | 10 Hz | Enhanced GPS with HDOP, VDOP, satellite count, covariance |
| `/pvtgeodetic` | `septentrio_gnss_driver/PVTGeodetic` | 10 Hz | Septentrio native PVT data |
| `/poscovgeodetic` | `septentrio_gnss_driver/PosCovGeodetic` | 10 Hz | Position covariance details |
| `/velcovgeodetic` | `septentrio_gnss_driver/VelCovGeodetic` | 10 Hz | Velocity covariance details |
| `/imu` | `sensor_msgs/Imu` | 200 Hz | Accelerometer, gyroscope, magnetometer (if INS) |
| `/odometry` | `nav_msgs/Odometry` | 10 Hz | INS-derived position/velocity (if INS enabled) |
| `/base_pose_cov` | `geometry_msgs/PoseWithCovariance` | 10 Hz | Position with full 6x6 covariance matrix |
| `/tf` | Transform frames | 10 Hz | base_link → gnss, base_link → imu |
| `/diagnostics` | `diagnostic_msgs/DiagnosticArray` | 1 Hz | Hardware status, fix quality, satellite info |

### 1.6 Connection Methods

**Method 1: TCP/IP (Recommended for Docker/Network)**
```
Device: tcp://192.168.3.1:28784
Speed: Ethernet (auto-negotiated)
Latency: 1-5 ms typical
Bandwidth: ~50-100 kbps typical
Configuration Location: config/rover.yaml → device field
```

**Method 2: Serial Port (Local/Direct)**
```
Device: /dev/ttyACM0 or /dev/ttyACM1
Baud Rate: 921600 bps
Latency: 5-10 ms typical
Data Format: NMEA sentences + SBF blocks
Configuration: Change device: serial:///dev/ttyACM0:921600 in rover.yaml
```

**Method 3: UDP (Advanced/Multi-host)**
```
Device: udp://192.168.3.1:28784
Configuration: Advanced use case, requires custom setup
```

---

## Part 2: Software Architecture & Data Flow

### 2.1 Driver Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   ROSaic Driver (C++ Components)                │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
                ▼             ▼             ▼
        ┌──────────────┐ ┌───────────┐ ┌──────────────┐
        │Communication│ │  Parser   │ │  Processor   │
        │   Layer     │ │  Engine   │ │   Engine     │
        └──────────────┘ └───────────┘ └──────────────┘
            TCP/IP           NMEA        NED→ENU
          Serial/UDP       SBF Blocks   Covariance
          Connection      Decoding     Transforms
          Management


        ┌──────────────────────────────────────────┐
        │      ROS2 Publisher Interface            │
        └──────────────────────────────────────────┘
                 │
    ┌────────────┼────────────┬──────────┬────────────┐
    │            │            │          │            │
    ▼            ▼            ▼          ▼            ▼
NavSatFix    GPSFix        Odometry    Imu        PoseCovariance
 (/gnss_fix) (/gps_fix)   (/odometry) (/imu)    (/base_pose_cov)
```

### 2.2 Data Processing Pipeline

**Input → Processing → Output Sequence:**

```
1. TCP Connection to 192.168.3.1:28784
   ↓
2. Receive Binary Data Stream
   ├─ NMEA Sentences (GGA, RMC, GSA, GST, etc.)
   └─ SBF Blocks (PVTGeodetic, DOP, VelSensorFrame, etc.)
   ↓
3. Parse Messages
   ├─ Extract position (lat, lon, alt)
   ├─ Extract velocity (vn, ve, vd)
   ├─ Extract covariance (std_lon, std_lat, std_alt)
   └─ Extract quality metrics (HDOP, VDOP, num_satellites)
   ↓
4. Transform Coordinates
   ├─ WGS84 geodetic → Local tangent plane (NED/ENU)
   ├─ Calculate covariance in local frame
   └─ Validate measurement uncertainty
   ↓
5. Publish ROS2 Messages
   ├─ /gpsfix (GPSFix extended at 10 Hz)
   ├─ /pvtgeodetic (Septentrio native PVT)
   ├─ /diagnostics (status at 1 Hz)
   └─ /tf (transforms at 10 Hz)
   ↓
6. Downstream Consumption
   ├─ online_fgo: Subscribes to /gpsfix (when enabled)
   ├─ lio_sam: Subscribes to /odometry
   └─ rviz2: Visualizes /tf transforms
```

### 2.3 Configuration Architecture

**Composition-Based (Recommended):**
- **File:** `config/rover.yaml`
- **Method:** ROS2 Component composition
- **Launch:** `launch/rover.launch.py`
- **Advantages:** Cleaner, more modular, single process

**Node-Based (Legacy Compatible):**
- **File:** `config/rover_node.yaml`
- **Method:** Traditional ROS2 node
- **Launch:** `launch/rover_node.launch.py`
- **Advantages:** Easier debugging, separate process space

**GNSS-Only Configuration:**
- **File:** `config/gnss.yaml`
- **Features:** Minimal setup, GNSS measurements only
- **Use Case:** When INS is disabled or unavailable

---

## Part 3: Hardware Testing Strategy (validated commands)

### 3.1 Pre-Test Requirements Checklist

Before executing any tests, verify:

- [ ] Septentrio MODIAC H is powered on (LED status)
- [ ] USB cable is securely connected (check via `/sys/bus/usb`)
- [ ] Network interface exists (check `/sys/class/net/enx1a3202991545`)
- [ ] TCP port 28784 is responsive (`timeout 3 bash -c 'echo > /dev/tcp/192.168.3.1/28784'`)
- [ ] Web interface is accessible (`curl -s http://192.168.3.1 | head -20`)
- [ ] ROS2 workspace sourced: `source /workspace/fgo_ws/install/setup.bash`
- [ ] Septentrio driver is installed: `ros2 pkg list | grep septentrio_gnss_driver`

### 3.2 Phase 1: Hardware Connectivity Testing (5 minutes)

**Objective:** Verify all hardware connections and communication paths are functional.

#### Test 1.1: USB Device Detection (no `lsusb` available)

```bash
# Check for Vendor ID 152a via sysfs
find /sys/bus/usb/devices -name idVendor -exec grep -l "152a" {} \;

# Optional: show parent path to confirm Product ID
for f in $(find /sys/bus/usb/devices -name idVendor -exec grep -l "152a" {} \;); do
   echo "--"; cat "$f"; cat "${f%/*}/idProduct" 2>/dev/null;
done
```

**Pass Criteria:** A device path reports idVendor=152a (MODIAC family)

#### Test 1.2: Serial Port Availability

```bash
# List available serial ports
ls -la /dev/ttyACM*

# Expected output:
# crw-rw-rw- 1 root dialout 166, 0 Dec 10 12:34 /dev/ttyACM0
# crw-rw-rw- 1 root dialout 166, 1 Dec 10 12:34 /dev/ttyACM1
```

**Pass Criteria:** Both /dev/ttyACM0 and /dev/ttyACM1 exist with read/write permissions

#### Test 1.3: Network Interface Status (no `ip`/`ifconfig` available)

```bash
# Verify interface exists
ls -la /sys/class/net/ | grep enx

# Check operational state and carrier
cat /sys/class/net/enx1a3202991545/operstate
cat /sys/class/net/enx1a3202991545/carrier

# Expected state: operstate reports "unknown" or "up" with carrier=1
```

**Pass Criteria:** Interface `enx1a3202991545` present and carrier=1

#### Test 1.4: TCP/IP Connectivity to Device (portable bash)

```bash
# Test TCP connectivity to MODIAC H data port (3s timeout)
timeout 3 bash -c 'echo > /dev/tcp/192.168.3.1/28784'

# Expected output: command exits 0 (no error text)
```

**Pass Criteria:** Command exits successfully (status 0)

#### Test 1.5: Web Interface Accessibility

```bash
# Query web interface
curl -s http://192.168.3.1 | head -20

# Or check HTTP response code
curl -I http://192.168.3.1 2>/dev/null | head -3
```

**Pass Criteria:** HTTP 200 OK response

### 3.3 Phase 1 Success Criteria

All tests must pass:
- ✅ USB device detected with correct IDs
- ✅ Serial ports /dev/ttyACM0 and /dev/ttyACM1 accessible
- ✅ Network interface enx1a3202991545 UP and RUNNING
- ✅ TCP port 28784 responding
- ✅ Web interface returning HTTP 200

---

## Part 4: Driver Launch & Verification

### 4.1 Phase 2: Driver Launch Testing (10 minutes)

**Objective:** Successfully launch the Septentrio driver and verify ROS2 topics are publishing.

#### Test 2.1: Package Installation Verification

```bash
# Verify driver package is installed
ros2 pkg list | grep septentrio_gnss_driver

# Expected output:
# septentrio_gnss_driver

# Check package location
ros2 pkg prefix septentrio_gnss_driver

# Expected output (similar to):
# /workspace/fgo_ws/install/septentrio_gnss_driver
```

**Pass Criteria:** Package found and located in install directory

#### Test 2.2: Configuration File Verification

```bash
# Check available configuration files
ls -la /workspace/fgo_ws/install/septentrio_gnss_driver/share/septentrio_gnss_driver/config/

# Expected files:
# - rover.yaml
# - rover_node.yaml
# - gnss.yaml
# - ins.yaml
```

**Pass Criteria:** Configuration files present and readable

#### Test 2.3: Driver Launch (Composition-Based)

**Terminal 1 - Launch the driver:**

```bash
# Source workspace
source /workspace/fgo_ws/install/setup.bash

# Launch driver with rover composition
ros2 launch septentrio_gnss_driver rover.launch.py

# Expected output (first 20 seconds):
# [INFO] [launch]: All requested entities launched successfully
# [INFO] [component_container-1]: Load Library: /workspace/fgo_ws/install/septentrio_gnss_driver/lib/libseptentrio_gnss_driver_node.so
# [INFO] [component_container-1]: Loaded library
# [INFO] [component_container-1]: Instantiate class septentrio_driver::RosaiicDriver
# [INFO] ...
```

**Wait for:** "All requested entities launched successfully" message (10-15 seconds)

#### Test 2.4: Topic Monitoring (In separate terminal)

**Terminal 2 - Monitor published topics:**

```bash
# Source workspace
source /workspace/fgo_ws/install/setup.bash

# List available topics (primary GNSS streams)
ros2 topic list | grep -E "gpsfix|pvtgeodetic|diagnostics"

# Expected output (subset):
# /gpsfix
# /pvtgeodetic
# /diagnostics

# Check topic frequencies
ros2 topic hz /gpsfix
# Expected: ~10 Hz

# Check topic info
ros2 topic info /gpsfix
# Expected: Type: gps_msgs/msg/GPSFix
#           Publisher count: 1
#           Subscription count: 0 or more
```

**Pass Criteria:** 
- /gnss_fix topic exists and publishing at ~10 Hz
- /gps_fix topic exists (if extended GPS support enabled)
- /diagnostics topic exists

#### Test 2.5: Sample Message Inspection

```bash
# Inspect single message from /gpsfix
ros2 topic echo /gpsfix --once

# Expected output (sample):
# header:
#   seq: 1234
#   stamp:
#     sec: 1702242857
#     nanosec: 123456789
#   frame_id: gnss
# status:
#   status: 0
#   service: 1
# latitude: 43.12345
# longitude: -79.54321
# altitude: 150.234
# position_covariance: [1.2, 0.7, -1.3, 0.7, 1.1, -1.4, -1.3, -1.4, 3.2]
# position_covariance_type: 3
```

**Pass Criteria:**
- Message received successfully
- Latitude and longitude are non-zero and reasonable
- Altitude is physically plausible
- Covariance values are non-zero

---

## Part 5: Data Quality Validation

### 5.1 Phase 3: Data Quality Testing (15 minutes)

**Objective:** Verify incoming GNSS measurements meet accuracy requirements.

#### Test 3.1: Fix Status Validation

```bash
# Monitor fix status over 30 seconds
ros2 topic echo /gpsfix | grep -A 2 "status:" | head -30

# Expected status values:
# status: 0  (GPS fix)
# status: 1  (DGPS fix - differential GPS)
# status: 2  (PPS fix - Precise Point Positioning)
# status: -1 (No fix)
```

**Pass Criteria:** 
- Status is 0, 1, or 2 (valid fix)
- Consistently maintains fix (no frequent status -1)
- Prefer status ≥ 1 (DGPS or better)

#### Test 3.2: Satellite Count Validation

```bash
# Check satellite count in extended GPS fix message
ros2 topic echo /gpsfix --once | grep -E "satellites|num_satellites"

# Expected output (sample):
# satellites: 11
# num_satellites: 11
```

**Pass Criteria:** 
- Minimum 4 satellites for valid fix
- Typically 8-15 satellites expected
- Fewer than 4 = no fix or degraded service

#### Test 3.3: Covariance Validation

```bash
# Extract covariance matrix from GPSFix
ros2 topic echo /gpsfix --once | grep -A 10 "position_covariance:"

# Expected output (sample - meters squared):
# position_covariance: [0.04, 0.0, 0.0, 0.0, 0.04, 0.0, 0.0, 0.0, 0.16]
#                       ↑       ↑     ↑     ↑   ↑     ↑   ↑   ↑   ↑
#                       σ²_lat  cov   cov  cov  σ²_lon cov cov cov σ²_alt

# Diagonal elements are variances:
# σ²_lat ≈ 0.04 m²  (std_lat ≈ 0.2 m)
# σ²_lon ≈ 0.04 m²  (std_lon ≈ 0.2 m)
# σ²_alt ≈ 0.16 m²  (std_alt ≈ 0.4 m)
```

**Pass Criteria:**
- Covariance values > 0 (non-zero, meaning measurement uncertainty quantified)
- Latitude/longitude covariance: 0.01-1.0 m² (good to reasonable)
- Altitude covariance: 0.05-2.0 m² (good to reasonable)
- All values finite (not NaN or Inf)

#### Test 3.4: HDOP/VDOP Metrics

```bash
# Extract dilution of precision values
ros2 topic echo /gpsfix --once | grep -E "hdop|vdop|pdop"

# Expected output (sample):
# hdop: 0.9  # Horizontal DOP - Position accuracy indicator
# vdop: 1.4  # Vertical DOP - Altitude accuracy indicator
# pdop: 1.7  # Position DOP - 3D accuracy indicator
```

**Quality Scale:**
- HDOP/VDOP < 1 = Excellent accuracy (±3 m horizontal)
- HDOP/VDOP 1-2 = Good accuracy (±5 m horizontal)
- HDOP/VDOP 2-5 = Moderate accuracy (±10 m)
- HDOP/VDOP > 5 = Poor accuracy (>20 m)

**Pass Criteria:**
- HDOP < 2.0 (good horizontal accuracy)
- VDOP < 2.0 (good vertical accuracy)

#### Test 3.5: Continuous Data Monitoring (5 minutes)

```bash
# Record messages for 5 minutes with timestamps (shorter sample is fine)
timeout 300 ros2 topic echo /gpsfix | tee gpsfix_data_quality_log.txt &

# Monitor in parallel terminal
# Count total messages received
tail -f gpsfix_data_quality_log.txt | grep -c "header:"

# Expected: ~3000 messages (10 Hz × 300 sec)
```

**Analysis after 5 minutes:**
```bash
# Analyze recorded data
grep "status:" gpsfix_data_quality_log.txt | sort | uniq -c

# Expected (sample):
#  2995 status: 0 (GPS fix)
#     5 status: -1 (no fix)
#     0 status: 1 (DGPS)

# All good if > 99% of messages have valid fix
```

**Observed results (Dec 10, 2025):**
- Fix status: 1 (DGPS) across sampled messages
- Satellites used: 17 (visible: 22)
- HDOP: 1.27, VDOP: 1.16, GDOP: 2.06
- Position covariance (sample): [1.20, 0.72, -1.36, 0.72, 1.11, -1.42, -1.36, -1.42, 3.21] (type=3)
- Position sample: lat 50.78206, lon 6.045997, alt ~263.3 m

**Pass Criteria:**
- > 99% of messages have valid fix (status ≥ 0)
- No long gaps in data (no messages lost for > 1 second)
- Consistent message frequency (10 Hz ±0.5 Hz)

---

## Part 6: Integration with gnssFGO

### 6.1 Understanding gnssFGO Architecture

**gnssFGO = GNSS + Factor Graph Optimization**

```
Sensor Inputs
├─ GNSS Measurements (/gpsfix from Septentrio driver)
├─ LiDAR Scans (/cloud_deskewed from LIO-SAM)
├─ IMU Data (/imu from Septentrio or external)
└─ Previous Position (prior knowledge)
        │
        ▼
┌────────────────────────────────┐
│  Factor Graph Optimization     │
│  (GTSAM-based)                │
├────────────────────────────────┤
│ Creates measurement factors    │
│ from sensor data              │
│ Optimizes node positions      │
│ Computes full covariance      │
└────────────────────────────────┘
        │
        ▼
Optimized Trajectory & Covariance
└─ Pose estimates with uncertainty
└─ Loop closure detections
└─ Map building (if LIO-SAM enabled)
```

### 6.2 Phase 4: Integration Testing (20 minutes)

**Objective:** Verify online_fgo receives and processes GNSS measurements correctly.

**Status:** Deferred at user request (online_fgo launch not executed in this iteration).

#### Test 4.1: Verify Dependencies

```bash
# Check online_fgo is installed
ros2 pkg list | grep online_fgo

# Expected:
# online_fgo

# Check if GTSAM is available
dpkg -l | grep gtsam

# Expected (sample):
# ii  libgtsam-dev    4.1.1-1    all    Georgia Tech Smoothing and Mapping Library
```

**Pass Criteria:** Both packages present

#### Test 4.2: Launch Driver + FGO Together

**Terminal 1 - Launch Septentrio driver:**

```bash
source /workspace/fgo_ws/install/setup.bash
ros2 launch septentrio_gnss_driver rover.launch.py
```

**Terminal 2 - Launch online_fgo (in separate terminal):**

```bash
source /workspace/fgo_ws/install/setup.bash

# Check available online_fgo launch files
ls -la /workspace/fgo_ws/install/online_fgo/share/online_fgo/launch/

# Launch online_fgo with appropriate config
# (Specific launch file depends on your setup - check for boreas.launch.py, kitti.launch.py, etc.)
ros2 launch online_fgo [your_launch_file].launch.py

# If uncertain, try generic launch:
ros2 launch online_fgo offline.launch.py dataset:=boreas
```

**Expected output:**
```
[INFO] [launch]: All requested entities launched successfully
[INFO] [online_fgo_node]: Initializing Factor Graph Optimizer...
[INFO] [online_fgo_node]: Factor graph created with initial state
```

#### Test 4.3: Monitor Topic Subscription

**Terminal 3 - Check topic connectivity:**

```bash
# List all active subscriptions
ros2 node info /[online_fgo_node_name]

# Or monitor topic traffic
ros2 topic info /gnss_fix

# Expected output (sample):
# Type: sensor_msgs/msg/NavSatFix
# Publisher count: 1
# Subscription count: 2  <-- online_fgo is subscribed
#     /online_fgo
# Publisher count: 1
```

**Pass Criteria:** online_fgo subscribed to /gnss_fix topic

#### Test 4.4: Monitor Factor Graph Updates

**Terminal 3 - Watch FGO processing:**

```bash
# Monitor online_fgo diagnostics
ros2 topic echo /diagnostics --once | grep -A 5 "online_fgo"

# Or check ROS node statistics
ros2 topic stats /gnss_fix -w 10

# Expected (sample):
# /gnss_fix: 10 msgs, 10.0 Hz, 834 B/s
```

**Pass Criteria:** Consistent data flow from driver → FGO

#### Test 4.5: Verify Factor Graph Convergence

```bash
# Monitor FGO state
ros2 topic echo /fgo/state --once

# Expected (sample output structure):
# header:
#   stamp: {sec: 1702242857, nanosec: 123456789}
# pose:
#   position: {x: 100.234, y: -50.123, z: 42.5}
#   orientation: {x: 0.0, y: 0.0, z: 0.707, w: 0.707}
# covariance: [...]
```

**Pass Criteria:**
- Factor graph producing state estimates
- Covariance values reasonable (not exploding)
- Update frequency consistent with input

---

## Part 7: Reliability & Stress Testing

### 7.1 Phase 5: Reliability Testing (30 minutes)

**Objective:** Verify driver stability under normal and fault conditions.

#### Test 5.1: Extended Runtime Test (10+ minutes)

```bash
# Run driver and monitor continuously
source /workspace/fgo_ws/install/setup.bash
ros2 launch septentrio_gnss_driver rover.launch.py &

# Monitor in background
(sleep 5 && ros2 topic hz /gnss_fix) &

# Wait 10 minutes and check results
sleep 600

# Check ROS logs for errors
ros2 node list | grep septentrio
```

**Pass Criteria:**
- No crashes or shutdowns over 10 minutes
- Consistent 10 Hz publishing rate
- No error messages in logs

#### Test 5.2: Disconnection Recovery Test

```bash
# In one terminal, monitor messages
ros2 topic echo /gnss_fix --once &
BASELINE=$(ros2 topic hz /gnss_fix -w 10)
echo "Baseline rate: $BASELINE"

# Physically disconnect USB cable (or ifconfig down enx...)

# Reconnect or reactivate interface
# Monitor recovery time
START=$(date +%s)
while ! ros2 topic hz /gnss_fix -w 5 > /dev/null 2>&1; do
  sleep 1
done
END=$(date +%s)

RECOVERY_TIME=$((END - START))
echo "Recovery time: $RECOVERY_TIME seconds"
```

**Pass Criteria:**
- Recovery time < 5 seconds
- No permanent disconnections
- Topic resumes publishing automatically

#### Test 5.3: Message Integrity Check

```bash
# Record 100 messages and verify integrity
timeout 10 ros2 topic echo /gnss_fix | head -150 > message_integrity_check.txt

# Analyze
grep -c "latitude:" message_integrity_check.txt  # Should be ~100
grep -c "longitude:" message_integrity_check.txt # Should be ~100
grep -c "altitude:" message_integrity_check.txt  # Should be ~100

# Check for truncated/corrupted messages
grep "nan\|inf\|NaN\|Inf" message_integrity_check.txt
# Expected: No results (no corrupted data)
```

**Pass Criteria:**
- All fields populated in every message
- No NaN or Inf values
- Message count consistent with Hz rate

#### Test 5.4: High-Frequency Data Streaming

```bash
# Modify configuration to 20 Hz output (if MODIAC supports)
# Edit rover.yaml: measurement_rate: 20  (instead of 10)

# Monitor throughput
ros2 run rqt_graph rqt_graph &

# Measure bandwidth usage
iftop -i enx1a3202991545 -n

# Expected: ~50-100 kbps sustained
```

**Pass Criteria:**
- No message loss even at 20 Hz
- No CPU saturation on single core
- Temperature stable

---

## Part 8: Configuration Tuning

### 8.1 Configuration File Locations

```
/workspace/fgo_ws/install/septentrio_gnss_driver/share/septentrio_gnss_driver/config/
├── rover.yaml              ← Composition-based (recommended)
├── rover_node.yaml         ← Node-based
├── gnss.yaml               ← GNSS-only
└── ins.yaml                ← INS-only
```

### 8.2 Key Configuration Parameters

**Device Selection:**
```yaml
# TCP/IP (default - for USB-to-Ethernet)
device: "tcp://192.168.3.1:28784"

# Serial port (if using serial interface)
device: "serial:///dev/ttyACM0:921600"

# UDP (if configured on receiver)
device: "udp://192.168.3.1:28784"
```

**Measurement Rate:**
```yaml
measurement_rate: 10  # Hz (1-20 typical, higher = more data)
use_raf: true         # Use raw measurements
```

**Output Configuration:**
```yaml
publish_imu: true              # Publish IMU data
publish_odometry: true         # Publish INS odometry
use_ros_axis_orientation: true # ENU coordinates (recommended for ROS)
```

**Coordinate Frame:**
```yaml
reference_frame: "base_link"   # Parent frame for transforms
gnss_frame: "gnss"             # GNSS receiver frame
imu_frame: "imu"               # IMU frame (if available)
```

### 8.3 Creating Custom Configuration for gnssFGO

**Create custom file:** `/workspace/fgo_ws/src/gnssFGO/online_fgo/config/fgo_custom.yaml`

```yaml
# Septentrio MODIAC H Configuration for gnssFGO Integration
# Author: Your Name
# Date: December 10, 2025

# Device Connection Settings
device: "tcp://192.168.3.1:28784"

# Measurement Output Settings
measurement_rate: 10              # 10 Hz for real-time processing
use_raf: true                     # Use raw measurements for FGO
publish_imu: true                 # IMU data required for IMU preintegration
publish_odometry: true            # INS odometry if available
publish_gnss_fix: true            # Primary GNSS measurements

# Coordinate Frame Configuration
reference_frame: "base_link"
gnss_frame: "gnss"
imu_frame: "imu"
use_ros_axis_orientation: true    # ENU (East-North-Up) for ROS compatibility

# GNSS Measurement Tuning
multi_antenna: false              # Single antenna for MODIAC H basic
use_dual_antenna_heading: false   # Not applicable for this config

# Advanced Settings
stream_device_para: false         # Don't stream device parameters
use_sbf_blocks: true              # Use Septentrio binary format
sbf_block_types:
  - "VelSensorFrame"              # Velocity measurements
  - "PVTGeodetic"                 # Position/velocity/time
  - "ImuSetup"                    # IMU calibration (if available)

# FGO-Specific Tuning
# These coordinate the driver's output for optimal FGO processing
measurement_covariance_scale: 1.0 # Scaling factor for GNSS covariance
use_rtk_corrections: false        # RTK disabled (can add later)
```

### 8.4 Testing Custom Configuration

```bash
# Copy custom config
cp /workspace/fgo_ws/src/gnssFGO/online_fgo/config/fgo_custom.yaml \
   /workspace/fgo_ws/install/septentrio_gnss_driver/share/septentrio_gnss_driver/config/

# Launch with custom config
ros2 launch septentrio_gnss_driver rover.launch.py config:=fgo_custom.yaml

# Verify configuration loaded
ros2 param list | grep septentrio
```

---

## Part 9: Troubleshooting & Recovery

### 9.1 Common Issues & Solutions

| Issue | Symptoms | Diagnosis | Solution |
|-------|----------|-----------|----------|
| **No TCP Connection** | "Connection refused" on port 28784 | 1. Check RNDIS interface active<br>2. Ping 192.168.3.1<br>3. Check web interface | 1. `ip link show enx...`<br>2. Power cycle MODIAC<br>3. Check MODIAC network config via web UI |
| **Serial Port Missing** | `/dev/ttyACM*` not found | 1. Check `dmesg` for ACM device<br>2. Check `/sys/bus/usb` | 1. Create with `mknod /dev/ttyACM0 c 166 0`<br>2. Check udev rules |
| **Driver Won't Launch** | "ROS package not found" | 1. Check workspace sourced<br>2. Package not installed | 1. `source /workspace/fgo_ws/install/setup.bash`<br>2. Rebuild: `colcon build --packages-select septentrio_gnss_driver` |
| **No GNSS Fix** | Status always -1, satellites < 4 | 1. Check antenna connection<br>2. Check sky visibility<br>3. Check firmware version | 1. Verify antenna physically connected<br>2. Move outdoors, away from obstruction<br>3. Update firmware to ≥4.10.0 |
| **High Covariance** | Covariance > 1.0 m² | 1. Few satellites (< 6)<br>2. Poor HDOP (> 3)<br>3. Signal blockage | 1. Move outdoors<br>2. Wait for satellite acquisition<br>3. Check obstructions (trees, buildings) |
| **Topics Not Publishing** | `ros2 topic list` empty | 1. Driver crashed<br>2. Not sourced correctly | 1. Check driver logs: `ros2 launch ... --debug`<br>2. Check ROS distro match |
| **Integration Failure** | online_fgo not consuming GNSS | 1. Different message types<br>2. Frame ID mismatch<br>3. Timing sync | 1. Verify topic name: `ros2 topic info /gnss_fix`<br>2. Check frame_id matches FGO config<br>3. Check system time sync |

### 9.2 Diagnostic Commands

```bash
# Check driver status
ros2 node list | grep septentrio
ros2 node info /[node_name]

# Monitor all topics
ros2 topic list -t

# Check message rates
ros2 topic hz /gnss_fix

# Inspect message content
ros2 topic echo /gnss_fix --once

# View driver logs
ros2 launch septentrio_gnss_driver rover.launch.py --debug

# Check transform tree
ros2 run tf2_tools view_frames
firefox frames.pdf

# Monitor system resources
top -p $(pgrep -f septentrio)
ps aux | grep septentrio
```

### 9.3 Recovery Procedures

**Driver Crash Recovery:**
```bash
# Kill any running instances
pkill -f septentrio_gnss_driver

# Check logs for error messages
cat ~/.ros/log/latest.log | grep ERROR

# Relaunch
ros2 launch septentrio_gnss_driver rover.launch.py
```

**Network Disconnection Recovery:**
```bash
# Check interface
ip link show enx1a3202991545

# Bring interface down/up
sudo ip link set enx1a3202991545 down
sudo ip link set enx1a3202991545 up

# Verify connectivity
ping -c 3 192.168.3.1

# Restart driver
pkill -f septentrio_gnss_driver
ros2 launch septentrio_gnss_driver rover.launch.py
```

**GNSS Fix Recovery:**
```bash
# Monitor fix status
ros2 topic echo /gnss_fix | grep -A 1 "status:"

# If status stuck at -1:
# 1. Move to open sky area
# 2. Wait 30-60 seconds for satellite acquisition
# 3. Check MODIAC antenna connector
# 4. Verify web interface shows satellites

# Check receiver status via web interface
curl -s http://192.168.3.1/api/v1/receiver/status | head -30
```

---

## Part 10: Testing Checklist & Next Steps

### 10.1 Complete Testing Checklist

**Pre-Testing Setup:**
- [ ] Septentrio MODIAC H powered on and connected
- [ ] USB cables verified
- [ ] Network interface active
- [ ] ROS2 workspace sourced
- [ ] All dependencies installed

**Phase 1: Hardware Connectivity (5 min)**
- [ ] USB device detection (lsusb)
- [ ] Serial ports available (/dev/ttyACM*)
- [ ] Network interface UP (ip link show)
- [ ] TCP port responding (nc -zv)
- [ ] Web interface accessible (curl)

**Phase 2: Driver Launch (10 min)**
- [ ] Package installation verified
- [ ] Configuration files accessible
- [ ] Driver launches without errors
- [ ] Topics appear in `ros2 topic list`
- [ ] Messages publishing at correct frequency

**Phase 3: Data Quality (15 min)**
- [ ] Fix status valid (status ≥ 0)
- [ ] Satellite count > 4
- [ ] Covariance non-zero and reasonable
- [ ] HDOP/VDOP < 2.0
- [ ] No message corruption (no NaN/Inf)

**Phase 4: FGO Integration (20 min)**
- [ ] online_fgo installed and located
- [ ] GTSAM dependency available
- [ ] Driver + FGO launch together
- [ ] FGO subscribed to /gnss_fix
- [ ] Factor graph receiving measurements

**Phase 5: Reliability (30 min)**
- [ ] 10+ minute runtime without crashes
- [ ] Recovery time < 5 seconds post-disconnect
- [ ] Message integrity maintained
- [ ] High-frequency streaming stable

**Configuration & Customization:**
- [ ] Custom fgo_custom.yaml created
- [ ] Configuration tested with custom params
- [ ] Coordinate frames properly aligned

**Documentation & Troubleshooting:**
- [ ] All test results logged
- [ ] Issues documented with solutions
- [ ] Recovery procedures validated

### 10.2 Test Execution Timeline

**Recommended Testing Schedule:**

| Phase | Time | Est. Duration | Priority |
|-------|------|---------------|----------|
| **1. Hardware Connectivity** | Day 1, 9:00 AM | 5 min | CRITICAL |
| **2. Driver Launch** | Day 1, 9:10 AM | 10 min | CRITICAL |
| **3. Data Quality** | Day 1, 9:25 AM | 15 min | CRITICAL |
| **4. FGO Integration** | Day 1, 9:45 AM | 20 min | HIGH |
| **5. Reliability** | Day 1, 10:10 AM | 30 min | HIGH |
| **Configuration Tuning** | Day 1, 10:45 AM | 30 min | MEDIUM |
| **Production Deployment** | Day 1, 11:30 AM | - | READY |

**Total Time Investment:** ~110 minutes to production-ready deployment

### 10.3 Success Criteria Summary

**Must Have (All 5 must pass):**
1. ✅ GNSS receiver maintaining lock (status ≥ 0) 99% of time
2. ✅ ROS2 topics publishing consistently at 10 Hz
3. ✅ Measurements with valid covariance (> 0, finite)
4. ✅ Driver stable over 10+ minutes without crashes
5. ✅ online_fgo receiving and processing GNSS data

**Should Have (3+ should pass):**
6. ✅ HDOP/VDOP < 2.0 (good accuracy)
7. ✅ Satellite count 8-12 (strong signal)
8. ✅ Fix status DGPS or better (status ≥ 1)
9. ✅ Recovery time < 2 seconds post-disconnect
10. ✅ Custom configuration tested and validated

### 10.4 Deployment Decision Tree

```
All Phase 1-3 tests passed?
├─ YES → Continue to Phase 4 (FGO Integration)
│        All Phase 4 tests passed?
│        ├─ YES → Continue to Phase 5 (Reliability)
│        │        All Phase 5 tests passed?
│        │        ├─ YES → ✅ PRODUCTION READY
│        │        │        Launch with online_fgo
│        │        └─ NO → Review logs, troubleshoot
│        └─ NO → Check /gnss_fix topic format
│                Verify FGO configuration
│                Review diagnostics messages
└─ NO → Check hardware connectivity
        Verify driver launch
        Review sensor covariance values
        Return to Phase 1
```

### 10.5 Production Deployment Command

Once all tests pass:

```bash
# Final production launch
source /workspace/fgo_ws/install/setup.bash

# Terminal 1: Launch Septentrio driver
ros2 launch septentrio_gnss_driver rover.launch.py config:=rover.yaml

# Terminal 2: Launch online_fgo (after driver steady)
sleep 5 && ros2 launch online_fgo [dataset].launch.py

# Terminal 3: Optional - Launch rviz2 for visualization
sleep 10 && ros2 run rviz2 rviz2 -d /workspace/fgo_ws/src/gnssFGO/LIOSAM/config/rviz2.rviz

# Monitor in Terminal 4:
ros2 topic hz /gnss_fix &
ros2 topic hz /fgo/state &
watch -n 1 'ros2 node list | wc -l'
```

### 10.6 Next Steps After Deployment

1. **Week 1:** Monitor system stability, log sensor data
2. **Week 2:** Fine-tune FGO parameters (measurement noise, bias models)
3. **Week 3:** Test RTK corrections (if available)
4. **Week 4:** Validate trajectory accuracy against ground truth
5. **Month 2:** Prepare for production dataset collection

---

## Appendix: Quick Reference Commands

### Launch Commands
```bash
# Composition-based (recommended)
ros2 launch septentrio_gnss_driver rover.launch.py

# Node-based
ros2 launch septentrio_gnss_driver rover_node.launch.py

# With custom config
ros2 launch septentrio_gnss_driver rover.launch.py config:=fgo_custom.yaml

# With debug output
ros2 launch septentrio_gnss_driver rover.launch.py --debug
```

### Topic Monitoring
```bash
# List all topics
ros2 topic list

# Check specific topic
ros2 topic info /gnss_fix

# Monitor messages (stream)
ros2 topic echo /gnss_fix

# Monitor one message only
ros2 topic echo /gnss_fix --once

# Check message frequency
ros2 topic hz /gnss_fix -w 30
```

### Diagnostics & Debugging
```bash
# List all nodes
ros2 node list

# Get node info
ros2 node info /septentrio_driver_node

# View transform tree
ros2 run tf2_tools view_frames

# Check ROS parameters
ros2 param list | grep septentrio

# Get parameter value
ros2 param get /[node_name] [param_name]

# Set parameter
ros2 param set /[node_name] [param_name] [value]
```

### System Monitoring
```bash
# Check USB device
lsusb -d 152a:85c0 -v

# Check network interface
ip link show enx1a3202991545
ip addr show enx1a3202991545

# Test TCP connectivity
nc -zv 192.168.3.1 28784

# Monitor resource usage
top -p $(pgrep -f septentrio)

# Check active topics bandwidth
ros2 topic bw /gnss_fix
```

---

**Document Version:** 1.0  
**Last Updated:** December 10, 2025  
**Status:** Ready for Testing & Implementation  
**Next Review:** After Phase 5 testing completion
