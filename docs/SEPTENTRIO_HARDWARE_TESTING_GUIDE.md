# Septentrio Mosaic-H Hardware Setup and Testing Guide

**Part 2**: Hardware Connection, Verification, Testing, and Dual Antenna Setup

---

## 3. Hardware Setup Guide

### 3.1 Equipment Required

#### Essential Equipment:
1. **Septentrio Mosaic-H GNSS Receiver**
   - Part number: Mosaic-H or mosaic-X5
   - Firmware version: 4.12.0 or later recommended

2. **GNSS Antenna (Main)**
   - Multi-band capable (L1/L2/L5 for GPS, E1/E5a for Galileo)
   - Example: Septentrio PolaNt Choke Ring B3/E6
   - Low Noise Amplifier (LNA) required
   - Cable: Low-loss coaxial (RG58 or better)
   - Max cable length: 50m (with active antenna)

3. **Power Supply**
   - Voltage: 9-36V DC (mosaic-H)
   - Current: ~2W typical, 5W maximum
   - Connector: Terminal block or barrel jack (check your model)

4. **Communication Interface** (choose one):
   - **Serial**: USB-to-Serial adapter (FTDI FT232, CP2102, etc.)
   - **Ethernet**: Direct connection or network switch
   - **USB**: Direct USB connection (if supported by your model)

#### Optional Equipment (Dual Antenna):
5. **Secondary GNSS Antenna**
   - Same specs as main antenna for best results
   - Baseline: 0.5m - 10m (1-2m recommended for vehicle applications)

6. **Antenna Mounting Hardware**
   - Rigid mounting plate or vehicle roof rack
   - Precise baseline measurement tools (tape measure or total station)

---

### 3.2 Hardware Connection Procedure

#### Step 1: Antenna Installation

**Main Antenna (ANT1)**:

```
Physical Setup:
┌─────────────────────────────────────────────────────┐
│                     VEHICLE ROOF                     │
│  ┌──────────────┐                ┌──────────────┐  │
│  │   ANT1       │                │   ANT2       │  │
│  │   (Main)     │   ←Baseline→   │   (Aux)      │  │
│  │              │    1.0 - 2.0m   │              │  │
│  └──────┬───────┘                └──────┬───────┘  │
│         │                                │           │
│         │ Coax Cable                     │ Coax     │
│         ▼                                ▼           │
│    ┌────────────────────────────────────────┐      │
│    │  Septentrio Mosaic-H Receiver          │      │
│    │  ANT1 ──────┐    ┌────── ANT2          │      │
│    │  COM1       │    │       COM2          │      │
│    │  ETH        │    │       PWR           │      │
│    └────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────┘
```

**Installation Steps**:

1. **Choose antenna location**:
   - Clear sky view (ideally 360° horizon)
   - Minimize obstructions (buildings, trees)
   - Away from RF interference sources
   - Stable, non-metallic surface if possible
   - Ground plane: 30cm × 30cm minimum for optimal performance

2. **Mount main antenna**:
   ```bash
   # Tighten mounting bolts securely
   # Ensure antenna is level (use bubble level)
   # Verify antenna pointing: Most antennas mark "North" or "0°"
   # Record antenna position (lat/lon/height for reference)
   ```

3. **Cable routing**:
   - Avoid sharp bends (minimum bend radius: 10× cable diameter)
   - Keep away from power cables (EMI)
   - Weatherproof all outdoor connections
   - Leave service loop at antenna base

4. **Connect antenna to receiver**:
   ```
   ANT1 connector on Mosaic-H → Main antenna cable
   - Tighten connector hand-tight + 1/4 turn with wrench
   - Check for bent pins before connecting
   ```

#### Step 2: Power Connection

**Mosaic-H Power Specifications**:
- Input voltage: 9-36V DC
- Polarity: Check your model (usually center-positive)
- Current: 2W typ, 5W max

**Connection**:
```
Power Supply Terminal Block:
┌────────────────────────────┐
│  VCC (+)  ─────── Red wire  │ → +12V or +24V
│  GND (-)  ─────── Black wire│ → Ground
└────────────────────────────┘

Safety checks:
1. Verify voltage with multimeter BEFORE connecting
2. Check polarity (reverse polarity damages receiver!)
3. Ensure stable power (no voltage drops during boot)
```

**Power-On Sequence**:
```bash
1. Connect antenna(s) FIRST
2. Connect communication cable (serial/ethernet)
3. Apply power LAST
4. Wait 30-60 seconds for boot
5. Check LEDs:
   - PWR LED: Solid = power good
   - PVT LED: Blinking = position fix obtained
```

#### Step 3: Communication Interface Setup

**Option A: Serial (RS232/USB)**

```bash
# 1. Connect USB-to-Serial adapter to Mosaic-H COM1 port
# Pin configuration (check your cable):
# Pin 2: RX (Mosaic-H receives data)
# Pin 3: TX (Mosaic-H transmits data)
# Pin 5: GND (Signal ground)

# 2. Connect USB adapter to computer
# 3. Identify serial port
ls /dev/ttyUSB*     # Linux
ls /dev/ttyACM*     # Linux (alternative)
ls /dev/cu.usbserial*  # macOS

# Typical: /dev/ttyUSB0

# 4. Set serial parameters
# Baud rate: 115200 (default) or 921600 (high-speed)
# Data bits: 8
# Parity: None
# Stop bits: 1
# Flow control: None

# 5. Test connection
sudo chmod 666 /dev/ttyUSB0  # Grant permissions
screen /dev/ttyUSB0 115200    # Or use minicom, putty

# You should see SBF binary data streaming
```

**Option B: Ethernet (TCP/IP)**

```bash
# 1. Connect Mosaic-H ETH port to computer or network switch
# 2. Default IP address: 192.168.3.1 (check manual for your model)

# 3. Configure computer network interface:
sudo ip addr add 192.168.3.100/24 dev eth0   # Linux
# Or use Network Manager GUI

# 4. Test connectivity
ping 192.168.3.1

# 5. Access web interface (configuration)
firefox http://192.168.3.1

# 6. SBF stream typically on:
# TCP port 28784 (SBF binary)
# TCP port 4001  (NMEA text)
```

#### Step 4: Receiver Configuration

**Using Web Interface** (recommended for initial setup):

```bash
# 1. Open web interface
http://192.168.3.1

# 2. Navigate to "NMEA/SBF Output"
# 3. Enable required SBF blocks:
#    - MeasEpoch (4027) - 10 Hz
#    - PVTGeodetic (4007) - 10 Hz
#    - PosCovGeodetic (5906) - 10 Hz
#    - VelCovGeodetic (5908) - 10 Hz
#    - ReceiverTime (5914) - 1 Hz
#    - AttEuler (5938) - 10 Hz [Dual antenna only]
#    - BaseVectorGeod (4028) - 10 Hz [Dual antenna only]

# 4. Set output rate: 10 Hz for all (except ReceiverTime: 1 Hz)

# 5. Configure COM1 or ETH stream:
#    - Protocol: SBF
#    - Connection: TCP Server (for Ethernet) or Serial (for COM)

# 6. GNSS Settings:
#    - Signals: GPS L1/L2, Galileo E1/E5a (minimum)
#    - Elevation mask: 5° (adjustable later in ROS config)

# 7. RTK Settings (if using RTK):
#    - Source: NTRIP, Base, Radio (configure as needed)
#    - Format: RTCM3
#    - Mount point: (your NTRIP caster details)

# 8. Save configuration!
#    - Click "Save Config" or "Save to Boot"
```

**Using Command Line Interface** (advanced):

```bash
# Connect via serial terminal or telnet
telnet 192.168.3.1 4001

# Configure SBF output
setSBFOutput, Stream1, COM1, MeasEpoch+PVTGeodetic+PosCovGeodetic+VelCovGeodetic+ReceiverTime, sec1

# Set output rate
setDataInOut, COM1, , SBF, 115200

# Save configuration
saveConfig
```

---

### 3.3 Dual Antenna Hardware Setup

**Baseline Configuration**:

```
Recommended Baseline Geometry:
┌─────────────────────────────────────────────────────┐
│                  VEHICLE HEADING →                   │
│                                                      │
│   ┌─────────┐               ┌─────────┐            │
│   │  ANT1   │←──Baseline───→│  ANT2   │            │
│   │ (Main)  │   (L)         │ (Aux)   │            │
│   └─────────┘               └─────────┘            │
│       ↑                          ↑                  │
│       │                          │                  │
│       │                          │                  │
│       └──────Aligned axis────────┘                  │
│           (for heading)                             │
└─────────────────────────────────────────────────────┘

Baseline Length (L):
- Minimum: 0.5m (heading accuracy: ~2°)
- Recommended: 1.0-2.0m (heading accuracy: ~0.5-1°)
- Maximum: 10m (diminishing returns)

Heading Accuracy Formula:
σ_heading ≈ arctan(σ_RTK / L)
Example: σ_RTK = 0.01m, L = 1.0m
         σ_heading ≈ 0.57° (1-sigma)
```

**Installation Procedure**:

1. **Measure and mark antenna positions**:
   ```bash
   # Use measuring tape or laser distance meter
   # Record baseline components:
   Δ East (m):  _____ (positive = ANT2 east of ANT1)
   Δ North (m): _____ (positive = ANT2 north of ANT1)
   Δ Up (m):    _____ (typically 0 if same plane)
   
   # Calculate baseline length:
   L = sqrt(ΔE² + ΔN² + ΔU²)
   
   # Calculate baseline azimuth (heading when vehicle points north):
   azimuth = atan2(ΔE, ΔN) * 180/π
   ```

2. **Mount antennas**:
   - Use level to ensure same horizontal plane
   - Rigid mounting (no flex during motion)
   - Both antennas same model for best results
   - Same cable length if possible (phase matching)

3. **Cable routing**:
   - Keep cables parallel if possible
   - Same length ± 1m (for phase coherence)
   - Label cables clearly: "ANT1" and "ANT2"

4. **Connect to receiver**:
   ```
   ANT1 connector → Main antenna cable
   ANT2 connector → Auxiliary antenna cable
   ```

5. **Configure receiver for dual antenna**:
   ```bash
   # Web interface:
   # Navigate to "Attitude" or "Multi-Antenna"
   # Enable: "Attitude Determination"
   # Set baseline length: [measured value] meters
   # Set baseline tolerance: 0.1m (for verification)
   # Enable "AttEuler" and "BaseVectorGeod" SBF blocks
   ```

6. **Verify baseline**:
   ```bash
   # After RTK fix, check BaseVectorGeod message:
   # Baseline components should match your measurements ±2cm
   # If large difference, recheck antenna positions
   ```

---

## 4. Software Configuration

### 4.1 Septentrio Driver Configuration

**Driver Configuration File**: `config/septentrio_driver_config.yaml`

```yaml
/**:
  ros__parameters:
    # Connection settings
    device: "/dev/ttyUSB0"              # Serial device
    # OR for Ethernet:
    # tcp_ip: "192.168.3.1"
    # tcp_port: 28784
    
    baudrate: 115200                    # Serial baudrate
    frame_id: "gnss"                    # TF frame ID
    
    # SBF blocks to request
    enable_sbf_stream: true
    sbf_output_rate: 10.0               # Hz
    
    # Dual antenna
    dual_antenna: false                 # Set true for dual setup
    aux_antenna_frame_id: "gnss_aux"
    
    # Coordinate frame
    use_gnss_time: true
    leap_seconds: 18                    # GPS-UTC offset (update as needed)
```

**Launch Septentrio Driver**:

```bash
# For serial connection
ros2 launch septentrio_gnss_driver serial.launch.py \
  device:=/dev/ttyUSB0 \
  baudrate:=115200

# For Ethernet connection
ros2 launch septentrio_gnss_driver tcp.launch.py \
  tcp_ip:=192.168.3.1 \
  tcp_port:=28784

# Verify topics are publishing
ros2 topic list | grep septentrio
ros2 topic hz /septentrio/pvtgeodetic  # Should show ~10 Hz
```

---

### 4.2 Preprocessing Configuration

**Configuration File**: `config/septentrio_preprocessing.yaml` (already created)

**Key Parameters to Tune**:

```yaml
# Adjust based on your environment
GNSSPreprocessor:
  # Urban canyon: raise CN0, lower min satellites
  min_cn0: 30.0                    # 25-35 dB-Hz typical
  min_elevation: 15.0              # 10-20° typical
  
  # RTK settings
  use_rtk: true
  max_age_correction: 30.0         # Depends on baseline distance
  
  # For dual antenna
  use_dual_antenna: false          # Change to true when ready
  baseline_length: 1.5             # Your measured baseline
  baseline_variance: 0.01          # 1cm² typical for RTK
  heading_variance: 0.5            # deg² (adjust based on baseline)
```

---

### 4.3 System Integration

**Complete System Launch** (script):

```bash
#!/bin/bash
# launch_septentrio_fgo_system.sh

# Source workspace
source /workspace/fgo_ws/install/setup.bash

# Launch Septentrio driver
ros2 launch septentrio_gnss_driver serial.launch.py \
  device:=/dev/ttyUSB0 &
DRIVER_PID=$!
echo "Septentrio driver started (PID: $DRIVER_PID)"

# Wait for driver initialization
sleep 5

# Launch GNSS preprocessing
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  log_level:=info &
PREPROC_PID=$!
echo "Preprocessing started (PID: $PREPROC_PID)"

# Wait for preprocessing initialization
sleep 3

# Launch factor graph optimization
ros2 launch online_fgo gnss_fgo.launch.py &
FGO_PID=$!
echo "FGO started (PID: $FGO_PID)"

# Launch visualization
sleep 2
rviz2 -d /workspace/fgo_ws/src/gnssFGO/LIOSAM/config/rviz2.rviz &
RVIZ_PID=$!
echo "RViz started (PID: $RVIZ_PID)"

# Wait for user interrupt
echo ""
echo "==================================="
echo "Septentrio FGO System Running"
echo "==================================="
echo "Press Ctrl+C to stop all nodes"
echo ""

# Trap Ctrl+C and cleanup
trap "echo 'Shutting down...'; kill $DRIVER_PID $PREPROC_PID $FGO_PID $RVIZ_PID 2>/dev/null; exit" INT

# Wait
wait
```

---

## 5. Verification and Testing

### 5.1 Driver Verification

**Test 1: Topic Publishing**

```bash
# List all topics from driver
ros2 topic list | grep septentrio

# Expected output:
/septentrio/measepoch
/septentrio/pvtgeodetic
/septentrio/poscovgeodetic
/septentrio/velcovgeodetic
/septentrio/receivertime
# (If dual antenna enabled):
/septentrio/atteuler
/septentrio/basevectorgeod
```

**Test 2: Message Rate**

```bash
# Check each topic rate (should be ~10 Hz)
ros2 topic hz /septentrio/pvtgeodetic

# Expected:
average rate: 10.000
    min: 0.099s max: 0.101s std dev: 0.00050s window: 100
```

**Test 3: Message Content**

```bash
# Echo PVT message
ros2 topic echo /septentrio/pvtgeodetic --once

# Verify:
# - latitude/longitude reasonable (your location)
# - mode: 4 (RTK fixed) or 5 (RTK float) or 1 (standalone)
# - error: 0 (no error)
# - nr_sv: 8-20 typical
# - h_accuracy: <0.1m for RTK, <5m for standalone
```

**Test 4: Data Recording**

```bash
# Record 30 seconds of data
ros2 bag record -o test_septentrio \
  /septentrio/measepoch \
  /septentrio/pvtgeodetic \
  /septentrio/poscovgeodetic \
  /septentrio/velcovgeodetic \
  --duration 30

# Verify recording
ros2 bag info test_septentrio_0.db3

# Check message counts (should be ~300 for 10 Hz × 30 sec)
```

---

### 5.2 Preprocessing Verification

**Test 1: Node Startup**

```bash
# Launch preprocessing
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  log_level:=debug

# Check log for:
[INFO] [...] Septentrio GNSS Preprocessor initialized successfully
[DEBUG] [...] Subscribed to /septentrio/measepoch
[DEBUG] [...] Subscribed to /septentrio/pvtgeodetic
# etc.

# Look for errors:
grep "ERROR" ~/.ros/log/latest/septentrio_gnss_preprocessing*
# Should be empty
```

**Test 2: Plugin Loading**

```bash
# Verify plugin is loaded
ros2 param get /septentrio_gnss_preprocessing GNSSPreprocessor.receiver_type

# Expected: septentrio

# Check node info
ros2 node info /septentrio_gnss_preprocessing

# Should show subscribers:
# /septentrio/measepoch
# /septentrio/pvtgeodetic
# /septentrio/poscovgeodetic
# /septentrio/velcovgeodetic
```

**Test 3: Output Topics**

```bash
# Check preprocessing outputs
ros2 topic list | grep gnss

# Expected:
/gnss/septentrio/pvt_geodetic
/gnss/septentrio/raw_measurements
/gnss/septentrio/preprocessed_obs
/gnss/septentrio/factors

# Echo preprocessed PVT
ros2 topic echo /gnss/septentrio/pvt_geodetic --once

# Verify fields populated correctly
```

**Test 4: Message Conversion**

```bash
# Record driver and preprocessing simultaneously
ros2 bag record -o conversion_test \
  /septentrio/pvtgeodetic \
  /gnss/septentrio/pvt_geodetic \
  --duration 10

# Play back and compare
ros2 bag play conversion_test_0.db3

# In another terminal, check timestamps match
ros2 topic echo /septentrio/pvtgeodetic --field block_header.tow
ros2 topic echo /gnss/septentrio/pvt_geodetic --field tow
# Should be identical (or within 1ms)
```

**Test 5: Performance Metrics**

```bash
# Monitor CPU usage
top -p $(pgrep -f septentrio_gnss_preprocessing)

# Typical: 5-15% CPU for single core
# If >30%, investigate (too many satellites, inefficient processing)

# Check latency
ros2 topic delay /gnss/septentrio/pvt_geodetic

# Expected: <10ms end-to-end delay
```

---

### 5.3 Static Position Test

**Purpose**: Verify absolute positioning accuracy and stability

**Procedure**:

```bash
# 1. Place receiver in static location with clear sky view
# 2. Let receiver acquire RTK fix (wait 2-5 minutes)
# 3. Record 10 minutes of data

ros2 bag record -o static_test_$(date +%Y%m%d_%H%M%S) \
  /septentrio/pvtgeodetic \
  /gnss/septentrio/pvt_geodetic \
  /gnss/septentrio/preprocessed_obs \
  --duration 600

# 4. Analyze results (Python script)
```

**Analysis Script**: `analyze_static_test.py`

```python
#!/usr/bin/env python3
import rosbag2_py
import numpy as np
from rclpy.serialization import deserialize_message
from septentrio_gnss_driver.msg import PVTGeodetic

def analyze_static_test(bag_file):
    # Load bag
    reader = rosbag2_py.SequentialReader()
    storage_options = rosbag2_py.StorageOptions(uri=bag_file, storage_id='sqlite3')
    converter_options = rosbag2_py.ConverterOptions('', '')
    reader.open(storage_options, converter_options)
    
    latitudes = []
    longitudes = []
    heights = []
    h_accuracies = []
    modes = []
    
    # Read messages
    while reader.has_next():
        topic, data, timestamp = reader.read_next()
        if topic == '/septentrio/pvtgeodetic':
            msg = deserialize_message(data, PVTGeodetic)
            latitudes.append(msg.latitude * 180 / np.pi)  # Convert to degrees
            longitudes.append(msg.longitude * 180 / np.pi)
            heights.append(msg.height)
            h_accuracies.append(msg.h_accuracy * 0.01)  # Convert to meters
            modes.append(msg.mode)
    
    # Compute statistics
    lat_mean = np.mean(latitudes)
    lon_mean = np.mean(longitudes)
    h_mean = np.mean(heights)
    
    lat_std = np.std(latitudes) * 111320  # Convert deg to meters (approx)
    lon_std = np.std(longitudes) * 111320 * np.cos(lat_mean * np.pi / 180)
    h_std = np.std(heights)
    
    print("="*60)
    print("STATIC POSITION TEST RESULTS")
    print("="*60)
    print(f"Number of epochs: {len(latitudes)}")
    print(f"Mean position (WGS84):")
    print(f"  Latitude:  {lat_mean:.8f}°")
    print(f"  Longitude: {lon_mean:.8f}°")
    print(f"  Height:    {h_mean:.3f} m")
    print(f"\nPosition standard deviation (1-sigma):")
    print(f"  Horizontal: {np.sqrt(lat_std**2 + lon_std**2):.3f} m")
    print(f"  Vertical:   {h_std:.3f} m")
    print(f"\nReceiver reported accuracy (mean):")
    print(f"  Horizontal: {np.mean(h_accuracies):.3f} m")
    print(f"\nPVT Mode distribution:")
    for mode_val in set(modes):
        count = modes.count(mode_val)
        pct = count / len(modes) * 100
        mode_name = {0: "NO_SOLUTION", 1: "STANDALONE", 4: "RTK_FIXED", 
                     5: "RTK_FLOAT", 10: "PPP"}.get(mode_val, f"UNKNOWN({mode_val})")
        print(f"  {mode_name}: {count} epochs ({pct:.1f}%)")
    print("="*60)
    
    # Pass/Fail criteria
    if np.sqrt(lat_std**2 + lon_std**2) < 0.02 and modes.count(4) / len(modes) > 0.95:
        print("✓ TEST PASSED: RTK fixed solution with <2cm horizontal accuracy")
    else:
        print("✗ TEST FAILED: Check RTK corrections or antenna setup")

if __name__ == '__main__':
    import sys
    analyze_static_test(sys.argv[1])
```

**Run Analysis**:
```bash
python3 analyze_static_test.py static_test_20251208_143000_0.db3
```

**Expected Results** (RTK fixed):
- Horizontal std dev: <0.02m (2cm)
- Vertical std dev: <0.05m (5cm)
- RTK fixed mode: >95% of epochs

---

### 5.4 Dynamic Position Test

**Purpose**: Verify positioning during motion

**Procedure**:

```bash
# 1. Mount receiver on vehicle (or carry receiver while walking)
# 2. Plan route with variety of conditions:
#    - Open sky
#    - Tree canopy
#    - Near buildings
# 3. Record entire route (10-30 minutes)

ros2 bag record -o dynamic_test_$(date +%Y%m%d_%H%M%S) \
  /septentrio/pvtgeodetic \
  /septentrio/measepoch \
  /gnss/septentrio/pvt_geodetic \
  /gnss/septentrio/preprocessed_obs \
  /gnss/septentrio/factors \
  --duration 1800

# 4. Visualize trajectory in real-time
ros2 run rviz2 rviz2
# Add "Path" display, topic: /gnss/septentrio/pvt_geodetic
```

**Post-Processing Analysis**:

```bash
# Plot trajectory
ros2 bag play dynamic_test_*_0.db3

# In another terminal, run plotting script (if available)
ros2 run irt_gnss_preprocessing plot_trajectory.py

# Or export to KML for Google Earth
ros2 run irt_gnss_preprocessing bag_to_kml.py \
  dynamic_test_*_0.db3 \
  --topic /gnss/septentrio/pvt_geodetic \
  --output trajectory.kml
```

**Metrics to Check**:
- Continuous positioning (no large gaps)
- Smooth trajectory (no jumps >1m)
- Mode transitions (RTK fixed ↔ float in difficult areas)
- Number of satellites (should stay >6 in open areas)

---

## 6. Dual Antenna Setup and Testing

### 6.1 Enable Dual Antenna Mode

**Step 1: Rebuild with Dual Antenna Support**

```bash
cd /workspace/fgo_ws

# Clean previous build
rm -rf build/irt_gnss_preprocessing install/irt_gnss_preprocessing

# Rebuild with USE_DUAL_ANTENNA flag
colcon build --packages-select irt_gnss_preprocessing \
  --cmake-args -DUSE_DUAL_ANTENNA=ON -DCMAKE_BUILD_TYPE=Release

# Source workspace
source install/setup.bash
```

**Step 2: Update Configuration**

Edit `config/septentrio_preprocessing.yaml`:

```yaml
GNSSPreprocessor:
  use_dual_antenna: true
  baseline_length: 1.5              # Your measured baseline (meters)
  baseline_variance: 0.0001         # 1mm² for RTK baseline
  heading_variance: 0.3             # deg² (depends on baseline)
```

**Step 3: Update Driver Configuration**

Edit Septentrio driver config:

```yaml
dual_antenna: true
aux_antenna_frame_id: "gnss_aux"
```

**Step 4: Enable Dual Antenna in Receiver**

```bash
# Web interface: Enable "Attitude Determination"
# Or via command line:
telnet 192.168.3.1 4001
setAntennaLocation, Main, 0, 0, 0
setAntennaLocation, Aux, 1.5, 0, 0  # Baseline along X-axis
setAttitudeMode, On
saveConfig
```

---

### 6.2 Dual Antenna Verification

**Test 1: Baseline Verification**

```bash
# Check baseline vector
ros2 topic echo /septentrio/basevectorgeod --once

# Verify:
# vector_info_geod[0].delta_north: Should match your ΔN ±2cm
# vector_info_geod[0].delta_east:  Should match your ΔE ±2cm
# vector_info_geod[0].delta_up:    Should match your ΔU ±2cm
# vector_info_geod[0].mode: 4 (RTK fixed baseline)
```

**Test 2: Heading Output**

```bash
# Check attitude message
ros2 topic echo /septentrio/atteuler --once

# Verify:
# heading: [value in degrees, 0-360]
# pitch: [vehicle pitch, typically -10 to +10]
# roll: [vehicle roll, typically -10 to +10]
# heading_std: [heading uncertainty in degrees, <1° for 1m baseline]
```

**Test 3: Heading Accuracy**

```bash
# Static heading test:
# 1. Point vehicle to known direction (use compass or landmark)
# 2. Record attitude for 5 minutes

ros2 bag record -o heading_test \
  /septentrio/atteuler \
  /septentrio/basevectorgeod \
  --duration 300

# 3. Analyze heading statistics
ros2 bag play heading_test_0.db3
ros2 topic echo /septentrio/atteuler --field heading | python3 -c "
import sys
import numpy as np
headings = [float(line.strip()) for line in sys.stdin if line.strip()]
print(f'Mean heading: {np.mean(headings):.2f}°')
print(f'Std dev: {np.std(headings):.3f}°')
print(f'Min: {np.min(headings):.2f}°, Max: {np.max(headings):.2f}°')
"

# Expected std dev:
# Baseline 1.0m: <0.5°
# Baseline 2.0m: <0.3°
```

**Test 4: Dynamic Heading Test**

```bash
# 1. Drive vehicle in figure-8 pattern (covers all heading directions)
# 2. Record data

ros2 bag record -o dynamic_heading_test \
  /septentrio/atteuler \
  /septentrio/basevectorgeod \
  /septentrio/pvtgeodetic \
  --duration 300

# 3. Verify smooth heading transitions
# Plot heading vs time (use Python/MATLAB/etc.)
```

---

### 6.3 Dual Antenna Troubleshooting

**Problem 1: No Heading Output**

```bash
# Check:
1. Both antennas connected and powered?
   ros2 topic hz /septentrio/measepoch     # Main antenna data
   ros2 topic hz /septentrio/measepoch_aux  # Aux antenna data
   # Both should be ~10 Hz

2. Receiver configured for dual antenna?
   # Check web interface: "Attitude" section enabled

3. Baseline mode = RTK fixed?
   ros2 topic echo /septentrio/basevectorgeod --field vector_info_geod[0].mode
   # Should be 4 (fixed) or 5 (float), NOT 0 (no solution)

4. Satellites visible to both antennas?
   ros2 topic echo /septentrio/measepoch --field n_obs     # Main
   ros2 topic echo /septentrio/measepoch_aux --field n_obs  # Aux
   # Should be similar (±2 satellites)
```

**Problem 2: Heading Jumps/Unstable**

```bash
# Possible causes:
1. Loose antenna mounting
   → Tighten mounting hardware, verify no flex

2. Baseline too short
   → Increase baseline to 1-2m minimum

3. Multipath on one antenna
   → Move antennas away from metal surfaces
   → Add ground plane under antennas

4. Phase center offset incorrect
   → Use identical antennas for both
   → Check receiver antenna calibration

5. RTK baseline not fixed
   → Ensure good RTK corrections (age <30s)
   → Check baseline constraints in receiver settings
```

**Problem 3: Heading Offset**

```bash
# If heading is consistently wrong by fixed angle:
1. Measure actual vehicle heading with compass
2. Compare to receiver reported heading
3. Compute offset: offset = compass_heading - receiver_heading

# Update configuration:
# In receiver web interface:
# "Attitude" → "Heading Offset" → [offset value]

# Or add offset in ROS config:
heading_offset_deg: 5.0  # Example: 5° clockwise
```

---

## 7. Tuning and Optimization

### 7.1 Parameter Tuning Guide

**Signal Selection** (improve fix rate):

```yaml
# Baseline (GPS + Galileo):
use_gps_l1: true
use_gps_l2: true
use_gal_e1: true
use_gal_e5a: true

# Add for difficult environments:
use_gps_l5: true      # Better multipath rejection
use_gal_e5b: true     # More signals
use_bds_b1: true      # BeiDou (Asia, global coverage)
use_glo_l1: true      # GLONASS (Russia, global coverage)

# Note: More signals = more processing, but better availability
```

**Quality Thresholds** (balance availability vs accuracy):

```yaml
# Conservative (best accuracy, fewer satellites):
min_cn0: 35.0
min_elevation: 20.0

# Balanced (recommended):
min_cn0: 25.0
min_elevation: 10.0

# Aggressive (difficult environments, accept lower quality):
min_cn0: 20.0
min_elevation: 5.0
```

**RTK Settings** (optimize for your baseline):

```yaml
# Short baseline (<10 km):
max_age_correction: 10.0   # 10 seconds max
use_rtk: true
use_dgnss: false

# Medium baseline (10-30 km):
max_age_correction: 30.0   # 30 seconds max
use_rtk: true

# Long baseline (>30 km) or no base station:
use_rtk: false
use_dgnss: true            # Differential corrections OK
# OR use PPP mode in receiver
```

---

### 7.2 Performance Optimization

**CPU Usage Reduction**:

```yaml
# Reduce processing load:
default_buffer_size: 3          # Smaller buffer (was 5)
solution_sync_queue_size: 5     # Smaller queue (was 10)
enable_cycle_slip_detection: false  # If not needed
use_carrier_smoothing: false    # Simple but faster
```

**Memory Usage**:

```bash
# Monitor memory usage
ps aux | grep septentrio_gnss_preprocessing

# If high memory usage:
# 1. Reduce buffer sizes in config
# 2. Check for memory leaks (run valgrind)
# 3. Disable unused features (dual antenna, DD processing)
```

**Latency Reduction**:

```yaml
# Minimize processing delay:
msg_lower_bound: 10000000       # 10ms (was 50ms)
# Note: Too low may cause message drops

# QoS settings (C++ code):
rclcpp::SensorDataQoS()         # Best effort, low latency
# vs
rclcpp::ReliableQoS()           # Reliable, higher latency
```

---

### 7.3 Environment-Specific Tuning

**Urban Canyon**:

```yaml
min_cn0: 30.0                # Reject weak multipath
min_elevation: 15.0          # Higher mask reduces multipath
enable_raim: true            # Outlier rejection critical
raim_threshold: 5.0          # Stricter than default
enable_chi_square_test: true
chi_square_threshold: 3.0    # 95% confidence
```

**Forest/Tree Canopy**:

```yaml
min_cn0: 20.0                # Accept weaker signals
min_elevation: 5.0           # Need low-elevation satellites
min_satellites: 5            # Reduced from 6
use_carrier_smoothing: true  # Helps with noisy pseudorange
```

**Open Sky (Highway, Ocean)**:

```yaml
min_cn0: 30.0                # Can be selective
min_elevation: 10.0
enable_ionosphere_correction: true  # Worth the processing
enable_troposphere_correction: true
```

---

## 8. Troubleshooting Guide

### 8.1 Common Issues

**Issue: No Position Fix**

```bash
# Diagnosis:
1. Check antenna connection
   ros2 topic echo /septentrio/measepoch --once
   # Should show satellites (n_obs > 0)

2. Check sky view
   # Are there obstructions? Buildings, trees?
   # Move to open area for initial test

3. Check receiver time
   ros2 topic echo /septentrio/receivertime --once
   # utc_valid should be true

4. Check ephemeris
   # Wait 12.5 minutes for full GPS almanac download
   # Check receiver status in web interface

# Solution:
# - Improve antenna placement
# - Wait for ephemeris download
# - Check receiver configuration
```

**Issue: RTK Not Working**

```bash
# Diagnosis:
ros2 topic echo /septentrio/pvtgeodetic --field mode
# If mode = 1 (standalone), not 4 (RTK fixed):

1. Check corrections received
   ros2 topic echo /septentrio/pvtgeodetic --field mean_corr_age
   # Should be <30 seconds, NOT 0 or 65535

2. Check reference station
   ros2 topic echo /septentrio/pvtgeodetic --field reference_id
   # Should match your base station ID, NOT 0

3. Check baseline distance
   # If >50km, RTK may not work (use PPP instead)

4. Check receiver RTK settings
   # Web interface: NTRIP client configured correctly?

# Solution:
# - Verify NTRIP credentials
# - Check network connectivity
# - Reduce max_age_correction if corrections delayed
```

**Issue: Preprocessing Node Crashes**

```bash
# Check logs:
cat ~/.ros/log/latest/septentrio_gnss_preprocessing-*.log

# Common causes:
1. Message type mismatch
   # Error: "Failed to deserialize message"
   # → Check driver and preprocessing versions match

2. Null pointer
   # Error: "Segmentation fault"
   # → Check buffer initialization in config

3. Parameter not found
   # Error: "Parameter ... not found"
   # → Verify config file path in launch file

# Debug mode:
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  log_level:=debug

# Run with GDB:
gdb --args ros2 run irt_gnss_preprocessing irt_gnss_preprocessing_node \
  --ros-args --params-file <config_file>
```

**Issue: Poor Heading Accuracy (Dual Antenna)**

```bash
# Check baseline quality:
ros2 topic echo /septentrio/basevectorgeod

# Diagnosis:
1. Baseline mode not fixed?
   vector_info_geod[0].mode: 4 (fixed) or 5 (float)?
   # If float, heading accuracy degraded

2. Baseline length error?
   # Compute: measured = sqrt(ΔN² + ΔE² + ΔU²)
   # Compare to configured baseline_length in config
   # If difference >10cm, recheck antenna positions

3. Heading std dev too large?
   ros2 topic echo /septentrio/atteuler --field heading_std
   # Should be <1° for 1m baseline
   # If >2°, investigate baseline or multipath

# Solution:
# - Improve baseline RTK fix (check corrections)
# - Increase baseline length
# - Add ground planes under antennas
```

---

### 8.2 Data Quality Checks

**CN0 (Carrier-to-Noise Ratio)**:

```bash
# Monitor signal strength
ros2 topic echo /septentrio/measepoch --field type1[0].cn0

# Interpretation:
# cn0 units: 0.25 dB-Hz, so multiply by 0.25
# Good: >40 dB-Hz (cn0 > 160)
# OK: 30-40 dB-Hz
# Poor: <30 dB-Hz (multipath or obstruction)

# If many satellites <30 dB-Hz:
# - Check antenna gain/LNA
# - Check cable quality (high loss?)
# - Check for interference sources
```

**Number of Satellites**:

```bash
ros2 topic echo /septentrio/pvtgeodetic --field nr_sv

# Expected:
# GPS only: 8-12 satellites
# GPS + Galileo: 15-25 satellites
# GPS + Gal + BeiDou + GLONASS: 25-40 satellites

# If low (<6):
# - Poor sky view (obstructions)
# - Antenna problem
# - Receiver signal selection too strict
```

**DOP (Dilution of Precision)**:

```bash
# Check geometry quality (if available in output)
# GDOP < 3: Excellent
# GDOP 3-6: Good
# GDOP 6-10: Moderate
# GDOP >10: Poor (positioning unreliable)

# Improve DOP by:
# - Lowering elevation mask
# - Enabling more constellations
# - Moving to better location
```

---

### 8.3 Support Resources

**Septentrio Resources**:
- Manual: https://www.septentrio.com/en/support/mosaic-receivers
- Firmware updates: Check Septentrio website
- SBF Reference Guide: Detailed message format specifications

**ROS2 Resources**:
- Septentrio driver: `/workspace/fgo_ws/src/gnssFGO/septentrio_gnss_driver/README.md`
- Preprocessing docs: This guide and `SEPTENTRIO_INTEGRATION_SUMMARY.md`

**Debugging Tools**:
```bash
# ROS2 tools
ros2 topic list
ros2 topic hz <topic>
ros2 topic echo <topic>
ros2 node info <node>
ros2 param list <node>

# System tools
top              # CPU usage
htop             # Better top
iotop            # Disk I/O
nethogs          # Network usage

# Logging
ros2 run rqt_console rqt_console
journalctl -f    # System logs
```

---

## Conclusion

This guide provides a complete workflow for integrating, testing, and tuning the Septentrio Mosaic-H receiver with the gnssFGO preprocessing system. Follow the steps sequentially for best results, and refer to the troubleshooting section when issues arise.

**Quick Start Summary**:
1. Connect hardware (antennas, power, communication)
2. Configure receiver (enable SBF blocks)
3. Launch driver and verify topics
4. Launch preprocessing and verify conversion
5. Test static position accuracy
6. Test dynamic positioning
7. (Optional) Enable and test dual antenna
8. Tune parameters for your environment

For additional support, refer to the integration summary document and the Septentrio receiver manual.
