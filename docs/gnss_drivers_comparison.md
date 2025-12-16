# NovAtel OEM7 and Septentrio GNSS Drivers - Comprehensive Technical Documentation

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [NovAtel OEM7 Driver](#novatel-oem7-driver)
3. [Septentrio GNSS Driver](#septentrio-gnss-driver)
4. [Comparative Analysis](#comparative-analysis)
5. [Integration Guidelines](#integration-guidelines)

---

## Executive Summary

This document provides a comprehensive technical analysis of two ROS drivers for professional GNSS/INS receivers:
- **NovAtel OEM7 Driver**: Official driver for NovAtel's OEM7 family of GNSS/SPAN receivers
- **Septentrio GNSS Driver (ROSaic)**: Official driver for Septentrio's mosaic and AsteRx receiver families

Both drivers support ROS 1 (Melodic, Noetic) and ROS 2 (Humble, Iron, Jazzy, Rolling), offering high-precision positioning data for autonomous systems, robotics, and academic research applications.

---

## NovAtel OEM7 Driver

### 1.1 Overview

**Repository**: https://github.com/novatel/novatel_oem7_driver  
**Developer**: NovAtel (Hexagon | NovAtel)  
**License**: BSD  
**Supported Receivers**: OEM7 family, SPAN systems  
**Key Capabilities**:
- GNSS positioning with RTK, PPP, and multi-constellation support
- INS integration (with SPAN hardware)
- Multi-frequency, multi-GNSS (GPS, GLONASS, Galileo, BeiDou)
- TerraStar PPP corrections support

### 1.2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    NovAtel OEM7 Receiver                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ GNSS Engine  │  │  IMU (SPAN)  │  │ PPP Service  │         │
│  │ Multi-GNSS   │  │  Integration │  │  TerraStar   │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                 │
│                            │                                     │
└────────────────────────────┼─────────────────────────────────────┘
                             │ Binary/ASCII Logs
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              novatel_oem7_driver ROS Node                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Connection Layer                         │  │
│  │  Serial | TCP/IP | USB | File Playback                   │  │
│  └────────────────────────┬─────────────────────────────────┘  │
│                            │                                     │
│  ┌────────────────────────▼─────────────────────────────────┐  │
│  │             OEM7 Message Decoder                         │  │
│  │  • Binary Message Parser (SBF-like)                      │  │
│  │  • ASCII Message Parser                                  │  │
│  │  • Message Validation & Synchronization                  │  │
│  └────────────────────────┬─────────────────────────────────┘  │
│                            │                                     │
│  ┌────────────────────────▼─────────────────────────────────┐  │
│  │          Message Handler Plugins                         │  │
│  │  • BESTPOS Handler    • INSPVA Handler                   │  │
│  │  • BESTVEL Handler    • CORRIMU Handler                  │  │
│  │  • HEADING Handler    • TIME Handler                     │  │
│  └────────────────────────┬─────────────────────────────────┘  │
│                            │                                     │
│  ┌────────────────────────▼─────────────────────────────────┐  │
│  │       ROS Message Publishers                             │  │
│  │  • Native OEM7 Messages                                  │  │
│  │  • Standard ROS Messages (GPSFix, NavSatFix, IMU, Odom) │  │
│  │  • Diagnostics                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ROS Topic Outputs                            │
│                                                                  │
│  Native NovAtel Topics (Namespace: /novatel/oem7/)              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │  /bestpos      │  │  /bestvel      │  │  /inspva       │   │
│  │  /bestutm      │  │  /heading2     │  │  /inspvax      │   │
│  │  /ppppos       │  │  /time         │  │  /insstdev     │   │
│  │  /corrimu      │  │  /rxstatus     │  │  /oem7raw      │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                  │
│  Standard ROS Topics (Namespace: /gps/)                         │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │  /gps/gps      │  │  /gps/fix      │  │  /gps/imu      │   │
│  │  GPSFix.msg    │  │  NavSatFix.msg │  │  Imu.msg       │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                  │
│  Odometry Topic                                                 │
│  ┌────────────────┐                                             │
│  │  /gps/odom     │                                             │
│  │  Odometry.msg  │                                             │
│  └────────────────┘                                             │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Published Topics

#### 1.3.1 Native NovAtel OEM7 Topics

All native topics are published under the `/novatel/oem7/` namespace:

| Topic Name | Message Type | Update Rate | Description |
|-----------|--------------|-------------|-------------|
| `/novatel/oem7/bestpos` | `novatel_oem7_msgs/BESTPOS` | 10 Hz (default) | Best available position solution with quality indicators |
| `/novatel/oem7/bestvel` | `novatel_oem7_msgs/BESTVEL` | 10 Hz (default) | Best velocity solution with 3D velocity components |
| `/novatel/oem7/bestutm` | `novatel_oem7_msgs/BESTUTM` | 1 Hz (default) | UTM projected position |
| `/novatel/oem7/inspva` | `novatel_oem7_msgs/INSPVA` | 50 Hz (SPAN) | Integrated position, velocity, and attitude |
| `/novatel/oem7/inspvax` | `novatel_oem7_msgs/INSPVAX` | 1 Hz (SPAN) | Extended INS position, velocity, attitude |
| `/novatel/oem7/insstdev` | `novatel_oem7_msgs/INSSTDEV` | 1 Hz (SPAN) | INS standard deviations |
| `/novatel/oem7/corrimu` | `novatel_oem7_msgs/CORRIMU` | 100 Hz (SPAN) | Corrected IMU measurements |
| `/novatel/oem7/heading2` | `novatel_oem7_msgs/HEADING2` | Variable | Dual-antenna heading solution |
| `/novatel/oem7/time` | `novatel_oem7_msgs/TIME` | 1 Hz | Receiver time and synchronization status |
| `/novatel/oem7/rxstatus` | `novatel_oem7_msgs/RXSTATUS` | On change | Receiver status, errors, and warnings |
| `/novatel/oem7/ppppos` | `novatel_oem7_msgs/PPPPOS` | 1 Hz | PPP position solution (TerraStar) |
| `/novatel/oem7/terrastarinfo` | `novatel_oem7_msgs/TERRASTARINFO` | 1 Hz | TerraStar service information |
| `/novatel/oem7/terrastarstatus` | `novatel_oem7_msgs/TERRASTARSTATUS` | 1 Hz | TerraStar service status |
| `/novatel/oem7/oem7raw` | `novatel_oem7_msgs/Oem7RawMsg` | Variable | Raw binary OEM7 messages for logging |

#### 1.3.2 Standard ROS Topics

Published under the `/gps/` namespace for compatibility:

| Topic Name | Message Type | Description |
|-----------|--------------|-------------|
| `/gps/gps` | `gps_common/GPSFix` | GPS fix message with DOP, position, velocity |
| `/gps/fix` | `sensor_msgs/NavSatFix` | Standard ROS navigation satellite fix |
| `/gps/imu` | `sensor_msgs/Imu` | IMU data (SPAN only) with orientation, angular velocity, linear acceleration |
| `/gps/odom` | `nav_msgs/Odometry` | Odometry message with position and orientation |

### 1.4 Key Message Structures

#### 1.4.1 BESTPOS Message

**Purpose**: Provides the best available position solution from the receiver

**Key Fields**:
```
header                    # ROS standard header
  stamp                   # GPS time or ROS time
  frame_id                # Reference frame (typically "gps")
  
nov_header                # NovAtel message header
  message_name            # "BESTPOS"
  message_id              # 42
  time_status             # GPS time status (0-200)
  gps_week_number         # GPS week
  gps_week_milliseconds   # Milliseconds into GPS week

sol_status                # Solution status
  status                  # 0=SOL_COMPUTED, 1=INSUFFICIENT_OBS, etc.
  
pos_type                  # Position type
  type                    # 0=NONE, 16=SINGLE, 17=PSRDIFF, 32=L1_FLOAT,
                          # 33=IONOFREE_FLOAT, 34=NARROW_FLOAT,
                          # 48=L1_INT, 49=WIDE_INT, 50=NARROW_INT,
                          # 68=PPP_CONVERGING, 69=PPP, 70=OPERATIONAL,
                          # 77=TCAR3, etc.

lat                       # Latitude (degrees)
lon                       # Longitude (degrees)
hgt                       # Height above mean sea level (meters)
undulation                # Geoidal separation (meters)
datum_id                  # Datum ID number

lat_stdev                 # Latitude standard deviation (meters)
lon_stdev                 # Longitude standard deviation (meters)
hgt_stdev                 # Height standard deviation (meters)

stn_id                    # Base station ID (for differential)
diff_age                  # Differential age (seconds, 0=no corrections)
sol_age                   # Solution age (seconds)

num_svs                   # Number of satellites tracked
num_sol_svs               # Number of satellites used in solution
num_sol_l1_svs            # Number of L1/E1/B1 satellites
num_sol_multi_svs         # Number of multi-frequency satellites

ext_sol_stat              # Extended solution status
  status                  # Bit field for additional status
```

**Position Type Values**:
- `16`: SINGLE - Single point position
- `17`: PSRDIFF - Pseudorange differential
- `32`: L1_FLOAT - L1 float ambiguity solution
- `34`: NARROW_FLOAT - Narrow-lane float solution
- `48`: L1_INT - L1 integer ambiguity solution
- `50`: NARROW_INT - Narrow-lane integer (RTK Fixed)
- `68`: PPP_CONVERGING - PPP solution converging
- `69`: PPP - PPP solution converged
- `77`: TCAR3 - Triple-frequency carrier phase

**Quality Assessment**:
- **Standard Deviations**: `lat_stdev`, `lon_stdev`, `hgt_stdev` indicate position uncertainty
  - RTK Fixed: typically < 0.02 m
  - RTK Float: typically 0.1 - 0.5 m
  - PPP: typically 0.05 - 0.1 m
  - Single: typically > 1 m

- **Differential Age**: `diff_age` indicates freshness of corrections
  - Should be < 5 seconds for good RTK
  - 0 means no differential corrections

- **Number of Satellites**: `num_sol_svs` should be ≥ 5 for good geometry

#### 1.4.2 INSPVA Message (SPAN Systems)

**Purpose**: Integrated navigation solution with position, velocity, and attitude

**Key Fields**:
```
header                    # ROS header
nov_header                # NovAtel header

week                      # GPS week
seconds                   # Seconds into week

latitude                  # Latitude (degrees, -90 to 90)
longitude                 # Longitude (degrees, -180 to 180)
height                    # Height (meters above ellipsoid)
north_velocity            # Northward velocity (m/s)
east_velocity             # Eastward velocity (m/s)
up_velocity               # Upward velocity (m/s)

roll                      # Roll angle (degrees, -180 to 180)
pitch                     # Pitch angle (degrees, -90 to 90)
azimuth                   # Azimuth/heading (degrees, 0 to 360)

status                    # INS solution status
                          # 0=INS_INACTIVE
                          # 1=INS_ALIGNING
                          # 2=INS_HIGH_VARIANCE
                          # 3=INS_SOLUTION_GOOD
                          # 6=INS_SOLUTION_FREE
                          # 7=INS_ALIGNMENT_COMPLETE
```

**INS Status Values**:
- `0`: INS_INACTIVE - INS not enabled
- `1`: INS_ALIGNING - INS alignment in progress
- `2`: INS_HIGH_VARIANCE - Poor solution quality
- `3`: INS_SOLUTION_GOOD - Normal operation
- `6`: INS_SOLUTION_FREE - No GNSS aiding
- `7`: INS_ALIGNMENT_COMPLETE - Alignment complete

#### 1.4.3 CORRIMU Message

**Purpose**: IMU measurements corrected for sensor errors and biases

**Key Fields**:
```
header                    # ROS header
nov_header                # NovAtel short header

week                      # GPS week
seconds                   # Seconds into week (IMU timestamp)

pitch_rate                # Angular rate about Y-axis (deg/s)
roll_rate                 # Angular rate about X-axis (deg/s)
yaw_rate                  # Angular rate about Z-axis (deg/s)

lateral_acc               # Acceleration along Y-axis (m/s²)
longitudinal_acc          # Acceleration along X-axis (m/s²)
vertical_acc              # Acceleration along Z-axis (m/s²)

imu_info                  # IMU error flags
```

**Frame Convention**: 
- X: Forward
- Y: Right
- Z: Down (vehicle frame)

#### 1.4.4 Standard ROS GPSFix Message

**Message Type**: `gps_common/GPSFix`

**Key Fields**:
```
header                    # Standard ROS header

status                    # GPS fix status
  status                  # -1=NO_FIX, 0=FIX, 1=SBAS_FIX, 2=GBAS_FIX,
                          # 3=DGPS_FIX, 4=WAAS_FIX, 5=RTK_FIX
  motion_source           # Source of motion information
  orientation_source      # Source of orientation
  position_source         # Source of position

latitude                  # Latitude (degrees)
longitude                 # Longitude (degrees)
altitude                  # Altitude (meters MSL)
track                     # Track made good (degrees from true north)
speed                     # Speed over ground (m/s)
climb                     # Vertical speed (m/s)

pitch                     # Pitch angle (degrees)
roll                      # Roll angle (degrees)
dip                       # Dip/magnetic inclination (degrees)
                          # NOTE: Repurposed for heading in some configs

time                      # GPS time
gdop                      # Geometric dilution of precision
pdop                      # Position dilution of precision
hdop                      # Horizontal dilution of precision
vdop                      # Vertical dilution of precision
tdop                      # Time dilution of precision

err                       # Estimated 1-sigma error (meters)
err_horz                  # Horizontal position error (meters)
err_vert                  # Vertical position error (meters)
err_track                 # Track error (degrees)
err_speed                 # Speed error (m/s)
err_climb                 # Vertical speed error (m/s)
err_time                  # Time error (seconds)
err_pitch                 # Pitch error (degrees)
err_roll                  # Roll error (degrees)
err_dip                   # Dip error (degrees)

position_covariance[9]    # Position covariance matrix (m²)
position_covariance_type  # Type of covariance
```

### 1.5 Configuration Parameters

#### 1.5.1 Connection Settings

```yaml
# Connection type: serial, tcp, file
oem7_if_serial:
  type: "serial"
  port: "/dev/ttyUSB0"
  baudrate: 115200

oem7_if_tcp:
  type: "tcp"
  ip_address: "192.168.1.100"
  port: 3001

oem7_if_file:
  type: "file"
  location: "/path/to/logfile.log"
```

#### 1.5.2 Position Source Selection

```yaml
# Position source for GPSFix and NavSatFix messages
# Options: BESTPOS, INSPVAS, (default: auto-select best)
oem7_position_source: "INSPVAS"  # Use INSPVAS for SPAN systems
```

#### 1.5.3 Message Publishing Configuration

```yaml
# Frame IDs
oem7_frame_id: "gps"
oem7_imu_frame_id: "imu"

# Odometry settings
oem7_odometry_zero_origin: false  # Use first fix as origin
oem7_publish_odometry: true

# Raw message logging
oem7_publish_unknown_oem7raw: true  # Publish unknown messages
oem7_raw_msg_pub: true
```

### 1.6 Data Flow and Timing

```
┌──────────────────────────────────────────────────────────────┐
│                    Timing Relationships                       │
└──────────────────────────────────────────────────────────────┘

GNSS Position Data Flow:
────────────────────────
BESTPOS (10 Hz)  ───┬──> /novatel/oem7/bestpos
                    │
                    ├──> /gps/gps (GPSFix)
                    │    Combined with BESTVEL when available
                    │
                    └──> /gps/fix (NavSatFix)

BESTVEL (10 Hz)  ───┴──> /novatel/oem7/bestvel


INS Data Flow (SPAN Systems):
─────────────────────────────
INSPVA (50 Hz)   ───┬──> /novatel/oem7/inspva
                    │
                    ├──> /gps/gps (GPSFix) - Higher priority than BESTPOS
                    │
                    ├──> /gps/fix (NavSatFix)
                    │
                    └──> /gps/odom (Odometry)

CORRIMU (100 Hz) ────> /novatel/oem7/corrimu
                    └──> /gps/imu (Imu.msg)


Time Synchronization:
────────────────────
TIME (1 Hz)      ────> /novatel/oem7/time
                      - GPS Week
                      - Milliseconds
                      - UTC offset
                      - Time status
```

**Key Timing Notes**:
1. INSPVA provides higher-rate position updates (50 Hz) compared to BESTPOS (10 Hz)
2. When both are available, INSPVA is preferred for GPSFix/NavSatFix if quality is equal or better
3. IMU data (CORRIMU) runs at 100 Hz for smooth integration
4. Driver synchronizes messages using GPS time for consistency

### 1.7 Coordinate Systems and Transformations

#### 1.7.1 Position Reference Frames

**WGS-84 Ellipsoid** (BESTPOS, INSPVA):
- Latitude: Geodetic latitude (degrees)
- Longitude: Geodetic longitude (degrees)
- Height: Height above WGS-84 ellipsoid (meters)

**Mean Sea Level** (MSL):
- Altitude in GPSFix = Height - Undulation
- Undulation = geoidal separation (N)

**UTM Projection** (BESTUTM):
- Northing/Easting in meters
- Zone-specific projection

#### 1.7.2 Vehicle Frame Convention (SPAN)

**NovAtel Convention**:
- **X-axis**: Forward (along vehicle longitudinal axis)
- **Y-axis**: Right (along vehicle lateral axis)
- **Z-axis**: Down (perpendicular to vehicle plane)

**Orientation Angles**:
- **Roll**: Rotation about X-axis (right wing down = positive)
- **Pitch**: Rotation about Y-axis (nose up = positive)
- **Azimuth/Heading**: Rotation about Z-axis (clockwise from North = positive, 0° = North)

**Conversion to ROS REP-103** (if needed):
- ROS uses ENU (East-North-Up)
- May require frame transformation for compatibility with other sensors

---

## Septentrio GNSS Driver

### 2.1 Overview

**Repository**: https://github.com/septentrio-gnss/septentrio_gnss_driver  
**Developer**: Septentrio  
**License**: BSD  
**Also Known As**: ROSaic (ROS + mosaic)  
**Supported Receivers**: 
- mosaic (mosaic-X5, mosaic-H, mosaic-Sx, mosaic-T)
- AsteRx (AsteRx-m3, AsteRx-SB, AsteRx-SBi3)  

**Key Capabilities**:
- Multi-frequency, multi-constellation GNSS
- INS integration (AsteRx-m3 Pro+ with IMU)
- AIM+ interference mitigation
- OSNMA authentication support
- Dual-antenna heading (mosaic-H)

### 2.2 Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│              Septentrio GNSS/INS Receiver                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ GNSS Engine  │  │   INS Core   │  │   AIM+       │          │
│  │ Multi-GNSS   │  │  (Optional)  │  │  Interference│          │
│  │ Multi-freq   │  │              │  │  Mitigation  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                   │
│         └──────────────────┴──────────────────┘                  │
│                            │                                      │
└────────────────────────────┼──────────────────────────────────────┘
                             │ SBF Blocks / NMEA Sentences
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│           septentrio_gnss_driver ROS Node                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Connection Manager                            │  │
│  │  Serial | TCP/IP | USB (RNDIS) | File (.sbf/.pcap)       │  │
│  └────────────────────────┬──────────────────────────────────┘  │
│                            │                                      │
│  ┌────────────────────────▼──────────────────────────────────┐  │
│  │         Message Parser & Handler                          │  │
│  │  ┌──────────────────┐    ┌──────────────────┐            │  │
│  │  │  SBF Parser      │    │  NMEA Parser     │            │  │
│  │  │  Binary blocks   │    │  ASCII sentences │            │  │
│  │  └──────────────────┘    └──────────────────┘            │  │
│  └────────────────────────┬──────────────────────────────────┘  │
│                            │                                      │
│  ┌────────────────────────▼──────────────────────────────────┐  │
│  │           Message Composition & Publishing                 │  │
│  │  • Combine multiple SBF blocks for composite messages     │  │
│  │  • Time synchronization (GPS/UTC)                         │  │
│  │  • Coordinate transformation (NED ↔ ENU)                  │  │
│  │  • Diagnostics generation                                 │  │
│  └────────────────────────┬──────────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    ROS Topic Outputs                             │
│                                                                   │
│  NMEA Topics (Standard GPS sentences)                            │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                │
│  │  /gpgga    │  │  /gprmc    │  │  /gpgsa    │  /gpgsv        │
│  └────────────┘  └────────────┘  └────────────┘                │
│                                                                   │
│  SBF Topics (Native Septentrio binary format)                    │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ /pvtgeodetic   │  │ /pvtcartesian  │  │ /atteuler      │   │
│  │ /poscovgeodetic│  │ /poscovcartes. │  │ /attcoveuler   │   │
│  │ /velcovgeodetic│  │ /channelstatus │  │ /dop           │   │
│  │ /measepoch     │  │ /insnavgeod    │  │ /insnavcart    │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                   │
│  Standard ROS Topics                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │  /navsatfix    │  │  /gpsfix       │  │  /pose         │   │
│  │  NavSatFix.msg │  │  GPSFix.msg    │  │  PoseWith      │   │
│  │                │  │                │  │  CovarianceStd │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                   │
│  INS Topics (for INS-equipped receivers)                         │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │  /imu          │  │  /localization │  │  /tf           │   │
│  │  Imu.msg       │  │  Odometry.msg  │  │  TF broadcast  │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                   │
│  Status & Diagnostics                                            │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ /diagnostics   │  │ /aimplusstatus │  │ /galauthstatus │   │
│  │ /rfstatus      │  │ /receiverstatus│  │                │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

### 2.3 Published Topics

#### 2.3.1 NMEA Topics

Standard NMEA 0183 sentences converted to ROS messages:

| Topic Name | Message Type | Update Rate | Description |
|-----------|--------------|-------------|-------------|
| `/gpgga` | `nmea_msgs/Gpgga` | 1-10 Hz | Global Positioning System Fix Data |
| `/gprmc` | `nmea_msgs/Gprmc` | 1-10 Hz | Recommended Minimum Specific GNSS Data |
| `/gpgsa` | `nmea_msgs/Gpgsa` | 1-10 Hz | GNSS DOP and Active Satellites |
| `/gpgsv` | `nmea_msgs/Gpgsv` | 1-10 Hz | GNSS Satellites in View |

#### 2.3.2 SBF Topics (Septentrio Binary Format)

Native Septentrio binary blocks converted to custom ROS messages:

**Position & Velocity**:

| Topic Name | Message Type | Update Rate | Description |
|-----------|--------------|-------------|-------------|
| `/pvtgeodetic` | `septentrio_gnss_driver/PVTGeodetic` | 1-10 Hz | Position, velocity, time in geodetic coordinates |
| `/pvtcartesian` | `septentrio_gnss_driver/PVTCartesian` | 1-10 Hz | Position, velocity, time in Cartesian (ECEF) coordinates |
| `/poscovgeodetic` | `septentrio_gnss_driver/PosCovGeodetic` | 1-10 Hz | Position covariance in geodetic frame |
| `/poscovcartes` | `septentrio_gnss_driver/PosCovCartesian` | 1-10 Hz | Position covariance in Cartesian frame |
| `/velcovgeodetic` | `septentrio_gnss_driver/VelCovGeodetic` | 1-10 Hz | Velocity covariance |

**Attitude** (Dual-antenna or INS):

| Topic Name | Message Type | Update Rate | Description |
|-----------|--------------|-------------|-------------|
| `/atteuler` | `septentrio_gnss_driver/AttEuler` | 1-20 Hz | Attitude angles (heading, pitch, roll) |
| `/attcoveuler` | `septentrio_gnss_driver/AttCovEuler` | 1-20 Hz | Attitude angle covariances |

**INS Navigation** (INS-equipped receivers):

| Topic Name | Message Type | Update Rate | Description |
|-----------|--------------|-------------|-------------|
| `/insnavgeod` | `septentrio_gnss_driver/INSNavGeod` | 10-50 Hz | INS navigation in geodetic coordinates |
| `/insnavcart` | `septentrio_gnss_driver/INSNavCart` | 10-50 Hz | INS navigation in Cartesian coordinates |
| `/exteventinsnavgeod` | `septentrio_gnss_driver/ExtEventINSNavGeod` | On event | INS navigation at external event |

**Measurements & Quality**:

| Topic Name | Message Type | Update Rate | Description |
|-----------|--------------|-------------|-------------|
| `/measepoch` | `septentrio_gnss_driver/MeasEpoch` | 1-10 Hz | Measurement epoch information |
| `/channelstatus` | `septentrio_gnss_driver/ChannelStatus` | 1 Hz | Channel status for all satellites |
| `/dop` | `septentrio_gnss_driver/DOP` | 1 Hz | Dilution of Precision values |
| `/qualityind` | `septentrio_gnss_driver/QualityInd` | 1 Hz | Quality indicators |

**Baseline** (RTK/Moving base):

| Topic Name | Message Type | Update Rate | Description |
|-----------|--------------|-------------|-------------|
| `/basevectorgeod` | `septentrio_gnss_driver/BaseVectorGeod` | 1-10 Hz | Baseline vector in geodetic frame |
| `/basevectorcart` | `septentrio_gnss_driver/BaseVectorCart` | 1-10 Hz | Baseline vector in Cartesian frame |

**Status & Diagnostics**:

| Topic Name | Message Type | Update Rate | Description |
|-----------|--------------|-------------|-------------|
| `/aimplusstatus` | `septentrio_gnss_driver/AIMPlusStatus` | 1 Hz | AIM+ interference mitigation status |
| `/rfstatus` | `septentrio_gnss_driver/RFStatus` | 1 Hz | RF interference and jamming status |
| `/galauthstatus` | `septentrio_gnss_driver/GALAuthStatus` | On change | Galileo OSNMA authentication status |
| `/receiverstatus` | `septentrio_gnss_driver/ReceiverStatus` | 1 Hz | General receiver health status |
| `/diagnostics` | `diagnostic_msgs/DiagnosticArray` | 1 Hz | ROS diagnostics aggregation |

#### 2.3.3 Standard ROS Topics

Composite messages built from multiple SBF blocks:

| Topic Name | Message Type | Source SBF Blocks | Description |
|-----------|--------------|-------------------|-------------|
| `/navsatfix` | `sensor_msgs/NavSatFix` | PVTGeodetic, PosCovGeodetic | Standard ROS GNSS fix |
| `/gpsfix` | `gps_common/GPSFix` | PVTGeodetic, PosCovGeodetic, VelCovGeodetic, ChannelStatus, DOP, AttEuler, MeasEpoch | Extended GPS fix with velocity, DOP, heading |
| `/pose` | `geometry_msgs/PoseWithCovarianceStamped` | PVTGeodetic, PosCovGeodetic, AttEuler, AttCovEuler | Position and orientation with covariance |
| `/imu` | `sensor_msgs/Imu` | INSNavGeod (or ExtSensorMeas) | IMU data (INS mode) |
| `/localization` | `nav_msgs/Odometry` | INSNavGeod, INSNavCart | Full localization (INS mode) |
| `/tf` | TF2 transforms | INSNavGeod | Transform tree broadcast (INS mode) |

### 2.4 Key Message Structures

#### 2.4.1 PVTGeodetic Message

**Purpose**: Position, velocity, and time in geodetic (latitude/longitude/height) coordinates

**Message Definition**:
```
std_msgs/Header header

BlockHeader block_header
  uint8   sync_1          # Sync bytes (0x24, '$')
  uint8   sync_2          # (0x40, '@')
  uint16  crc             # CRC-CCITT
  uint16  id              # Block ID (4007 for PVTGeodetic)
  uint8   revision        # Block revision number
  uint16  length          # Block length
  uint32  tow             # Time of week (ms)
  uint16  wnc             # Week number

uint8   mode              # Position calculation mode
                          # 0: No PVT available
                          # 1: Stand-alone PVT
                          # 2: Differential PVT
                          # 3: Fixed location
                          # 4: RTK fixed
                          # 5: RTK float
                          # 6: SBAS aided
                          # 7: Moving base RTK fixed
                          # 8: Moving base RTK float
                          # 10: PPP

uint8   error             # Error code (0 = no error)

float64 latitude          # Latitude (radians, -π/2 to π/2)
float64 longitude         # Longitude (radians, -π to π)
float64 height            # Ellipsoidal height (meters)

float32 undulation        # Geoidal undulation (meters)

float32 vn                # Velocity North (m/s)
float32 ve                # Velocity East (m/s)
float32 vu                # Velocity Up (m/s)

float32 cog               # Course over ground (degrees, 0-360)

float64 rx_clk_bias       # Receiver clock bias (ms)
float32 rx_clk_drift      # Receiver clock drift (ppm)

uint8   time_system       # Time system
                          # 0: GPS time
                          # 1: Galileo time
                          # 3: GLONASS time
                          # 4: BeiDou time
                          # 5: QZSS time

uint8   datum             # Datum (0: WGS84)

uint8   nr_sv             # Total number of satellites used
uint8   wa_corr_info      # Wide area corrections info
uint16  reference_id      # Reference station ID

uint16  mean_corr_age     # Mean age of differential corrections (0.01s)

uint32  signal_info       # Signal info (bit field)

uint8   alert_flag        # Alert flag

# Position accuracy (95% confidence)
uint8   nr_bases          # Number of base stations
uint16  ppp_info          # PPP status info

# Added in later firmware versions:
uint16  latency           # Latency (ms, v4.10+)
uint16  h_accuracy        # Horizontal accuracy (cm, v4.10+)
uint16  v_accuracy        # Vertical accuracy (cm, v4.10+)
```

**Mode Values Explained**:
- **Mode 0**: No solution available
- **Mode 1**: Autonomous GNSS (no corrections)
- **Mode 2**: DGNSS (pseudorange differential)
- **Mode 4**: RTK Fixed (cm-level, carrier phase ambiguities resolved)
- **Mode 5**: RTK Float (dm-level, ambiguities not resolved)
- **Mode 10**: PPP (Precise Point Positioning, dm to cm-level)

#### 2.4.2 PosCovGeodetic Message

**Purpose**: Position covariance matrix in local geodetic frame (North-East-Down)

```
std_msgs/Header header
BlockHeader block_header

uint8   mode              # Position mode (matches PVTGeodetic)
uint8   error             # Error code

float32 cov_nn            # Variance North-North (m²)
float32 cov_ne            # Covariance North-East (m²)
float32 cov_nd            # Covariance North-Down (m²)
float32 cov_ee            # Variance East-East (m²)
float32 cov_ed            # Covariance East-Down (m²)
float32 cov_dd            # Variance Down-Down (m²)

float32 cov_bb            # Variance base-base (m²)
float32 cov_be            # Covariance base-East (m²)
float32 cov_bn            # Covariance base-North (m²)
```

**Covariance Matrix**:
```
     ┌                    ┐
     │ cov_nn  cov_ne  cov_nd │
C =  │ cov_ne  cov_ee  cov_ed │
     │ cov_nd  cov_ed  cov_dd │
     └                    ┘
```

**Standard Deviations**:
- σ_north = √(cov_nn)
- σ_east = √(cov_ee)
- σ_down = √(cov_dd)

#### 2.4.3 AttEuler Message

**Purpose**: Attitude angles (heading, pitch, roll) from dual-antenna or INS

```
std_msgs/Header header
BlockHeader block_header

uint8   nr_sv             # Number of satellites used
uint8   error             # Error code
                          # 0: Not enough measurements
                          # 1: Reserved
                          # 2: Reserved
                          # 3: Reserved
                          # 4: Reserved
                          # 10: No error

uint16  mode              # Attitude mode
                          # 0: No attitude
                          # 1: Heading, pitch (from dual-antenna)
                          # 2: Heading, pitch, roll (from dual-antenna)
                          # 3: Heading only (from dual-antenna)
                          # 4: Heading, pitch (from INS)
                          # 5: Heading, pitch, roll (from INS)

# Reserved fields
uint8   reserved1
uint8   reserved2

float32 heading           # Heading angle (degrees, 0-360)
                          # 0° = North (NED) or East (ENU)
                          # Clockwise positive (NED) or counterclockwise (ENU)

float32 pitch             # Pitch angle (degrees, -90 to 90)
                          # Positive = nose up

float32 roll              # Roll angle (degrees, -180 to 180)
                          # Positive = right wing down (NED) or left wing down (ENU)

float32 pitch_dot         # Pitch rate (deg/s)
float32 roll_dot          # Roll rate (deg/s)
float32 heading_dot       # Heading rate (deg/s)
```

**Coordinate Convention** (if `use_ros_axis_orientation: false`):
- **NED (North-East-Down)**: Septentrio native
  - Heading: 0° = North, increases clockwise
  - Pitch: Positive = nose up
  - Roll: Positive = right wing down

**Coordinate Convention** (if `use_ros_axis_orientation: true`):
- **ENU (East-North-Up)**: ROS REP-103
  - Yaw: 0° = East, increases counterclockwise
  - Pitch: Positive = nose up
  - Roll: Positive = left side up

**Driver performs automatic coordinate transformation when configured.**

#### 2.4.4 INSNavGeod Message

**Purpose**: Integrated INS navigation solution in geodetic coordinates

```
std_msgs/Header header
BlockHeader block_header

uint8   gnss_mode         # GNSS position mode (see PVTGeodetic)
uint8   error             # Error code

uint16  info              # Info bit field
                          # Bit 0-2: IMU type
                          # Bit 3: 1 = Solution stable
                          # Bit 4-5: GNSS fix quality
                          # Bit 8-10: Alignment status

uint16  sb_list           # SBF block list used

# Position
float64 latitude          # Latitude (radians)
float64 longitude         # Longitude (radians)
float64 height            # Ellipsoidal height (meters)

float32 undulation        # Geoidal undulation (meters)

# Velocity (in local geodetic frame)
float32 vn                # Velocity North (m/s)
float32 ve                # Velocity East (m/s)
float32 vu                # Velocity Up (m/s)

# Attitude (Euler angles)
float32 roll              # Roll (radians)
float32 pitch             # Pitch (radians)
float32 heading           # Heading/Azimuth (radians)

# Position accuracy
float32 latitude_std      # Latitude standard deviation (meters)
float32 longitude_std     # Longitude standard deviation (meters)
float32 height_std        # Height standard deviation (meters)

# Velocity accuracy
float32 vn_std            # North velocity std dev (m/s)
float32 ve_std            # East velocity std dev (m/s)
float32 vu_std            # Up velocity std dev (m/s)

# Attitude accuracy
float32 roll_std          # Roll std dev (radians)
float32 pitch_std         # Pitch std dev (radians)
float32 heading_std       # Heading std dev (radians)

# Additional fields (firmware dependent)
uint16  mean_corr_age     # Mean correction age (0.01s)
uint8   gnss_pvt_error    # GNSS PVT error code
uint8   ins_algo_status   # INS algorithm status
uint8   heading_source    # Heading source
                          # 0: No heading
                          # 1: GNSS dual-antenna
                          # 2: INS gyro
                          # 3: External heading

uint8   reserved
```

**INS Algorithm Status** (Bit field in `info`):
- **Bits 8-10** (Alignment Status):
  - 0: Not aligned
  - 1: Coarse alignment
  - 2: Fine alignment (heading not reliable)
  - 3: Fine alignment (heading reliable)

**GNSS Fix Quality** (Bits 4-5 in `info`):
- 0: No fix
- 1: Standalone
- 2: Differential
- 3: RTK fixed

#### 2.4.5 Standard ROS NavSatFix Message

**Message Type**: `sensor_msgs/NavSatFix`

**Composition**: Built from PVTGeodetic + PosCovGeodetic SBF blocks

```
std_msgs/Header header

sensor_msgs/NavSatStatus status
  int8 status               # -1: NO_FIX, 0: FIX, 1: SBAS_FIX, 2: GBAS_FIX
  uint16 service            # Bit field of satellite services used

float64 latitude            # Latitude (degrees)
float64 longitude           # Longitude (degrees)
float64 altitude            # Altitude above MSL (meters)
                            # altitude = height - undulation

float64[9] position_covariance     # Position covariance (m²)
                                   # [cov_ee, cov_en, cov_ed,
                                   #  cov_en, cov_nn, cov_nd,
                                   #  cov_ed, cov_nd, cov_dd]
                                   # (ENU frame in ROS)

uint8 position_covariance_type     # 0: UNKNOWN
                                   # 1: APPROXIMATED
                                   # 2: DIAGONAL_KNOWN
                                   # 3: KNOWN
```

**Status Mapping from PVTGeodetic Mode**:
- Mode 0 → NO_FIX (-1)
- Mode 1 → FIX (0)
- Mode 2, 6 → SBAS_FIX (1)
- Mode 4, 5, 7, 8 → GBAS_FIX (2) - used for RTK
- Mode 10 → FIX (0) - PPP

#### 2.4.6 Standard ROS GPSFix Message

**Message Type**: `gps_common/GPSFix`

**Composition**: Blends PVTGeodetic, PosCovGeodetic, VelCovGeodetic, ChannelStatus, DOP, AttEuler, MeasEpoch

```
std_msgs/Header header

sensor_msgs/NavSatStatus status   # See NavSatFix

float64 latitude            # Latitude (degrees)
float64 longitude           # Longitude (degrees)
float64 altitude            # Altitude MSL (meters)

float64 track               # Course over ground (degrees)
float64 speed               # Speed over ground (m/s)
float64 climb               # Vertical speed (m/s)

float64 pitch               # Pitch angle (degrees, from AttEuler)
float64 roll                # Roll angle (degrees, from AttEuler)
float64 dip                 # Repurposed for heading (degrees, from AttEuler)

float64 time                # GPS time (seconds since epoch)

float64 gdop                # Geometric DOP (from DOP block)
float64 pdop                # Position DOP
float64 hdop                # Horizontal DOP
float64 vdop                # Vertical DOP
float64 tdop                # Time DOP

float64 err                 # Position error (meters)
float64 err_horz            # Horizontal position error
float64 err_vert            # Vertical position error
float64 err_track           # Track error (degrees)
float64 err_speed           # Speed error (m/s)
float64 err_climb           # Vertical speed error (m/s)
float64 err_time            # Time error (seconds)
float64 err_pitch           # Pitch error (degrees)
float64 err_roll            # Roll error (degrees)
float64 err_dip             # Dip/heading error (degrees)

float64[9] position_covariance        # Position covariance matrix
uint8 position_covariance_type        # Covariance type
```

### 2.5 Configuration Parameters

#### 2.5.1 Connection Settings

```yaml
device:
  hw_id: "mosaic-X5"                  # Hardware ID for diagnostics
  
  # Serial connection
  serial:
    port: "/dev/ttyACM0"
    baudrate: 115200
    
  # TCP/IP connection
  tcp:
    ip_server: "192.168.3.1"
    tcp_port: 28784
    
  # USB (RNDIS) connection - automatic
  
  # File replay (.sbf or .pcap)
  file:
    path: "/path/to/recording.sbf"
```

#### 2.5.2 Frame Configuration

```yaml
frame_id: "gnss"              # Main GNSS frame
imu_frame_id: "imu"           # IMU frame (INS mode)
poi_frame_id: "base_link"     # Point of interest frame
vsm_frame_id: "vsm"           # Vehicle speed measurement frame

# Coordinate system selection
use_ros_axis_orientation: true    # true=ENU (ROS), false=NED (Septentrio)
```

#### 2.5.3 Multi-Antenna Configuration

```yaml
multi_antenna: false          # Enable for dual-antenna systems
                              # Publishes AttEuler, AttCovEuler

# Antenna lever arms (meters, in vehicle frame)
ant_aux1_x: 0.0
ant_aux1_y: 0.0
ant_aux1_z: 0.0

ant_lever_x: 0.0              # Main antenna offset
ant_lever_y: 0.0
ant_lever_z: 0.0
```

#### 2.5.4 INS Configuration

```yaml
ins_spatial_config: true      # Enable INS configuration

# INS parameters
ins_initial_heading: "auto"   # "auto" or value in degrees
ins_std_dev_x: 0.0           # Position std dev (meters)
ins_std_dev_y: 0.0
ins_std_dev_z: 0.0

ins_std_dev_vx: 0.0          # Velocity std dev (m/s)
ins_std_dev_vy: 0.0
ins_std_dev_vz: 0.0

ins_std_dev_roll: 0.0        # Attitude std dev (degrees)
ins_std_dev_pitch: 0.0
ins_std_dev_heading: 0.0

# Use vehicle speed measurements
ins_use_vsm: false
```

#### 2.5.5 Topic Selection

```yaml
# NMEA sentences to publish
publish:
  gpgga: true
  gprmc: true
  gpgsa: true
  gpgsv: true
  
# SBF blocks to publish
publish:
  pvtgeodetic: true
  pvtcartesian: false
  poscovgeodetic: true
  velcovgeodetic: true
  atteuler: true
  attcoveuler: true
  insnavgeod: true
  insnavcart: false
  
# Standard ROS messages
publish:
  navsatfix: true
  gpsfix: true
  pose: true
  diagnostics: true
```

### 2.6 Data Flow and Timing

```
┌──────────────────────────────────────────────────────────────┐
│                    Timing Relationships                       │
└──────────────────────────────────────────────────────────────┘

GNSS Position Data Flow:
────────────────────────
PVTGeodetic (10 Hz) ──┬──> /pvtgeodetic (native SBF)
                      │
                      ├──> /navsatfix (sensor_msgs)
                      │    Combined with PosCovGeodetic
                      │
                      └──> /gpsfix (gps_common)
                           Combined with VelCovGeodetic, DOP,
                           AttEuler, ChannelStatus

PosCovGeodetic (10 Hz)──> /poscovgeodetic
                          └──> Used in /navsatfix, /gpsfix, /pose

VelCovGeodetic (10 Hz)──> /velcovgeodetic
                          └──> Used in /gpsfix


Attitude Data Flow:
──────────────────
AttEuler (20 Hz)    ──┬──> /atteuler (native SBF)
                      │
                      ├──> /gpsfix (dip field = heading)
                      │
                      └──> /pose (orientation)

AttCovEuler (20 Hz) ──┬──> /attcoveuler (native SBF)
                      └──> /pose (covariance)


INS Data Flow (INS-equipped receivers):
───────────────────────────────────────
INSNavGeod (50 Hz)  ──┬──> /insnavgeod (native SBF)
                      │
                      ├──> /localization (Odometry)
                      │    Full 6-DOF pose + velocity + covariances
                      │
                      ├──> /pose (PoseWithCovarianceStamped)
                      │
                      ├──> /imu (derived from velocity & attitude rates)
                      │
                      └──> /tf (broadcast transform tree)

INSNavCart (50 Hz)  ──┬──> /insnavcart (native SBF)
                      └──> Alternative Cartesian representation


Quality & Diagnostics Flow:
───────────────────────────
ChannelStatus (1 Hz) ──> /channelstatus
                         └──> Used in /gpsfix (satellite count)

DOP (1 Hz)           ──> /dop
                         └──> Used in /gpsfix (GDOP, PDOP, etc.)

QualityInd (1 Hz)    ──> /qualityind

ReceiverStatus (1Hz) ──> /receiverstatus
                         └──> /diagnostics

AIMPlusStatus (1Hz)  ──> /aimplusstatus
                         └──> /diagnostics

RFStatus (1Hz)       ──> /rfstatus
                         └──> /diagnostics
```

**Key Timing Notes**:
1. PVTGeodetic and related blocks synchronized by receiver TOW (Time of Week)
2. INSNavGeod provides high-rate (50 Hz) integrated solution
3. AttEuler from dual-antenna can run at 20 Hz for fast heading updates
4. All messages timestamped using GPS time converted to ROS time
5. Driver can handle asynchronous arrival of different SBF blocks

### 2.7 Coordinate Systems and Transformations

#### 2.7.1 Native Septentrio Frames (NED)

**Global Frame**: 
- **North**: Reference direction (local geodetic North)
- **East**: 90° clockwise from North
- **Down**: Toward Earth center

**Vehicle Frame**:
- **X**: Forward (vehicle longitudinal)
- **Y**: Right (vehicle lateral)
- **Z**: Down (vehicle vertical)

**Attitude Convention (NED)**:
- **Heading**: 0° = North, increases clockwise (0-360°)
- **Pitch**: Positive = nose up (-90° to 90°)
- **Roll**: Positive = right wing down (-180° to 180°)

#### 2.7.2 ROS Frames (ENU - REP-103)

When `use_ros_axis_orientation: true`:

**Global Frame**:
- **East**: Reference direction
- **North**: 90° counterclockwise from East
- **Up**: Away from Earth center

**Vehicle Frame**:
- **X**: Forward (vehicle longitudinal)
- **Y**: Left (vehicle lateral)
- **Z**: Up (vehicle vertical)

**Attitude Convention (ENU)**:
- **Yaw**: 0° = East, increases counterclockwise (0-360°)
- **Pitch**: Positive = nose up (-90° to 90°)
- **Roll**: Positive = left side up (-180° to 180°)

#### 2.7.3 Automatic Transformation

Driver performs these transformations when `use_ros_axis_orientation: true`:

**Position**: NED → ENU
```
Position_ENU = [E, N, -D]^T
where: (N, E, D) from Septentrio
```

**Velocity**: NED → ENU
```
Velocity_ENU = [Ve, Vn, -Vd]^T
```

**Attitude**: NED → ENU
```
Yaw_ENU = 90° - Heading_NED
Pitch_ENU = Pitch_NED
Roll_ENU = -Roll_NED
```

**Covariance**: NED → ENU
```
Covariance_ENU = R * Covariance_NED * R^T
where R = rotation matrix from NED to ENU
```

### 2.8 Advanced Features

#### 2.8.1 AIM+ Interference Mitigation

**Topic**: `/aimplusstatus`

Monitors and reports:
- Interference detection per frequency band
- Mitigation effectiveness
- Signal quality metrics
- Jamming indicators

**Key fields**:
```
uint8 interference_detected     # 0: No, 1: Yes
uint8 mitigation_active         # 0: Off, 1: On
float32 cn0_impact              # C/N0 degradation (dB)
uint8[] freq_band_status        # Per-band status
```

#### 2.8.2 OSNMA Galileo Authentication

**Topic**: `/galauthstatus`

Reports Galileo Open Service Navigation Message Authentication:
- Authentication status per satellite
- Key status
- Tag validation results

**Use case**: Detect GNSS spoofing attempts

#### 2.8.3 Multi-Baseline RTK

For systems with multiple base stations:
- `/basevectorgeod` provides vectors to each base
- Improved positioning in challenging environments
- Automatic base station selection

#### 2.8.4 External Event Logging

Capture precise GNSS/INS state at external trigger:
- `/exteventinsnavgeod`: INS solution at trigger
- Hardware timestamping
- Used for camera synchronization, lidar triggering

---

## Comparative Analysis

### 3.1 Feature Comparison Matrix

| Feature | NovAtel OEM7 Driver | Septentrio GNSS Driver |
|---------|-------------------|----------------------|
| **ROS Support** | ROS 1 (Melodic, Noetic)<br>ROS 2 (Humble+) | ROS 1 (Melodic, Noetic)<br>ROS 2 (Humble, Iron, Jazzy, Rolling) |
| **GNSS Constellations** | GPS, GLONASS, Galileo, BeiDou, QZSS, NavIC | GPS, GLONASS, Galileo, BeiDou, QZSS, NavIC |
| **RTK Support** | ✓ | ✓ |
| **PPP Support** | ✓ (TerraStar) | ✓ |
| **INS Integration** | ✓ (SPAN systems) | ✓ (AsteRx-m3 Pro+) |
| **Dual-Antenna Heading** | ✓ (HEADING2) | ✓ (mosaic-H, AttEuler) |
| **Native Message Format** | Custom OEM7 binary/ASCII | SBF (Septentrio Binary Format) |
| **NMEA Support** | Limited | ✓ Full |
| **Update Rates** | | |
| - GNSS Position | Up to 20 Hz | Up to 100 Hz |
| - INS Position | Up to 200 Hz | Up to 100 Hz |
| - IMU Data | Up to 200 Hz | Up to 100 Hz |
| **Interference Mitigation** | GAJT, SPAN anti-jam | AIM+ Advanced |
| **Authentication** | - | OSNMA (Galileo) |
| **Connection Types** | Serial, TCP/IP, USB, File | Serial, TCP/IP, USB (RNDIS), File (.sbf/.pcap) |
| **Coordinate Systems** | Vehicle-centric (X-forward, Y-right, Z-down) | NED native, ENU optional |
| **TF Broadcasting** | Manual | Automatic (INS mode) |
| **Multi-Antenna Config** | HEADING2 log | Native dual-antenna support |

### 3.2 Message Architecture Comparison

#### 3.2.1 Position Quality Information

**NovAtel OEM7**:
```
BESTPOS message provides:
- Position type (16 distinct types)
- Solution status
- Latitude/Longitude/Height
- Standard deviations (lat, lon, height)
- Number of satellites
- Differential age
- Extended solution status
```

**Septentrio**:
```
PVTGeodetic + PosCovGeodetic provides:
- Mode (10 distinct modes)
- Position (lat, lon, height)
- Velocity (vn, ve, vu)
- Full 3x3 covariance matrix
- Accuracy estimates (h_accuracy, v_accuracy)
- Number of satellites
- Correction age
```

**Key Difference**: Septentrio provides full covariance matrix vs separate standard deviations in NovAtel.

#### 3.2.2 INS Solution

**NovAtel SPAN (INSPVA)**:
```
Provides:
- Position (lat, lon, height)
- Velocity (north, east, up)
- Attitude (roll, pitch, azimuth)
- INS status (single field)

Separate messages:
- INSSTDEV for uncertainties
- CORRIMU for IMU data
```

**Septentrio INS (INSNavGeod)**:
```
Provides in single message:
- Position (lat, lon, height)
- Velocity (vn, ve, vu)
- Attitude (roll, pitch, heading)
- All standard deviations
- INS status (bit field)
- Alignment status
- GNSS fix quality
```

**Key Difference**: Septentrio INSNavGeod is more comprehensive in single message; NovAtel distributes info across multiple messages.

#### 3.2.3 Standard ROS Message Support

**Both drivers publish**:
- `sensor_msgs/NavSatFix`
- `gps_common/GPSFix`
- `sensor_msgs/Imu` (INS mode)
- `nav_msgs/Odometry` (INS mode)

**NovAtel specifics**:
- GPSFix status derived from BESTPOS position type
- IMU from CORRIMU at 100+ Hz
- Odometry optional, requires configuration

**Septentrio specifics**:
- GPSFix includes DOP values from separate block
- IMU derived from INSNavGeod velocity derivatives
- Odometry automatically published in INS mode
- Additional `geometry_msgs/PoseWithCovarianceStamped`

### 3.3 Performance Comparison

| Metric | NovAtel OEM7 | Septentrio |
|--------|--------------|------------|
| **RTK Initialization Time** | 30-60 seconds (typical) | 30-60 seconds (typical) |
| **RTK Accuracy** | Horizontal: 8mm + 1ppm<br>Vertical: 15mm + 1ppm | Horizontal: 6mm + 0.5ppm<br>Vertical: 10mm + 0.5ppm |
| **PPP Convergence** | 15-30 minutes | 15-30 minutes |
| **PPP Accuracy** | 10 cm horizontal<br>20 cm vertical | 4 cm horizontal<br>8 cm vertical |
| **INS Position Drift** | 0.01% distance traveled | 0.01% distance traveled |
| **Heading Accuracy (dual-ant)** | 0.15° (1m baseline) | 0.1° (1m baseline) |
| **Cold Start Time** | < 60 seconds | < 45 seconds |
| **Hot Start Time** | < 10 seconds | < 10 seconds |

### 3.4 Use Case Recommendations

#### 3.4.1 Choose NovAtel OEM7 Driver When:

1. **SPAN Integration Required**
   - Working with existing SPAN-equipped systems
   - Need for high-rate IMU (200 Hz)
   - Tactical-grade IMU integration

2. **TerraStar PPP Infrastructure**
   - Already using TerraStar subscription
   - Global PPP coverage needed
   - Real-time convergence monitoring

3. **Legacy Compatibility**
   - Upgrading from older NovAtel systems
   - Existing tools use OEM7 logs
   - Need raw OEM7 message logging

4. **Specific BESTPOS Workflows**
   - Applications tuned to BESTPOS quality indicators
   - Multiple position type handling
   - Extended solution status required

#### 3.4.2 Choose Septentrio Driver When:

1. **Interference Environments**
   - Urban canyons with multipath
   - RF interference present (AIM+ advantage)
   - Jamming/spoofing concerns

2. **Multi-Frequency Performance**
   - Need for superior multi-frequency tracking
   - Mixed constellation optimization
   - Triple-frequency processing

3. **OSNMA Authentication**
   - Security-critical applications
   - Spoofing detection required
   - Galileo authentication needed

4. **ROS-Native Workflow**
   - Prefer ENU coordinate system
   - Need automatic TF broadcasting
   - Want comprehensive single-message INS solution

5. **High Update Rates**
   - Need 100 Hz GNSS position
   - Real-time robotics applications
   - Fast-moving platforms

6. **Ease of Configuration**
   - Web interface for receiver config
   - SBF logging and analysis tools
   - NMEA + SBF combined output

---

## Integration Guidelines

### 4.1 Hardware Connection

#### 4.1.1 Serial Connection

**NovAtel**:
```bash
# Find device
ls -l /dev/ttyUSB*

# Set permissions
sudo chmod 666 /dev/ttyUSB0

# Launch file
<param name="oem7_if_serial/port" value="/dev/ttyUSB0"/>
<param name="oem7_if_serial/baudrate" value="115200"/>
```

**Septentrio**:
```bash
# Typically shows as /dev/ttyACM0 (USB-CDC)
ls -l /dev/ttyACM*

# Launch file
<param name="device/serial/port" value="/dev/ttyACM0"/>
<param name="device/serial/baudrate" value="115200"/>
```

#### 4.1.2 Ethernet Connection

**NovAtel**:
```yaml
# config/oem7_net.yaml
oem7_if_tcp:
  type: "tcp"
  ip_address: "192.168.1.100"
  port: 3001  # Default OEM7 command port
```

**Septentrio**:
```yaml
# config/mosaic.yaml
device:
  tcp:
    ip_server: "192.168.3.1"  # Default mosaic IP
    tcp_port: 28784           # Default SBF stream port
```

### 4.2 Driver Launch Examples

#### 4.2.1 NovAtel OEM7 Basic Launch

**ROS 1**:
```xml
<launch>
  <node pkg="novatel_oem7_driver" type="novatel_oem7_driver_node" 
        name="novatel_oem7" output="screen">
    
    <!-- Connection -->
    <param name="oem7_if_serial/port" value="/dev/ttyUSB0"/>
    <param name="oem7_if_serial/baudrate" value="115200"/>
    
    <!-- Frame IDs -->
    <param name="oem7_frame_id" value="gps"/>
    <param name="oem7_imu_frame_id" value="imu"/>
    
    <!-- Enable topics -->
    <param name="oem7_publish_odometry" value="true"/>
    <param name="oem7_publish_unknown_oem7raw" value="false"/>
  </node>
</launch>
```

**ROS 2**:
```yaml
# config/oem7_params.yaml
novatel_oem7:
  ros__parameters:
    oem7_if_serial:
      port: "/dev/ttyUSB0"
      baudrate: 115200
    
    oem7_frame_id: "gps"
    oem7_imu_frame_id: "imu"
    oem7_publish_odometry: true
```

```bash
ros2 launch novatel_oem7_driver oem7_net.py
```

#### 4.2.2 Septentrio Basic Launch

**ROS 1**:
```xml
<launch>
  <node pkg="septentrio_gnss_driver" type="septentrio_gnss_driver_node"
        name="septentrio" output="screen">
    
    <!-- Connection -->
    <param name="device/serial/port" value="/dev/ttyACM0"/>
    <param name="device/serial/baudrate" value="115200"/>
    
    <!-- Frame IDs -->
    <param name="frame_id" value="gnss"/>
    <param name="use_ros_axis_orientation" value="true"/>
    
    <!-- Topic selection -->
    <param name="publish/gpgga" value="true"/>
    <param name="publish/gprmc" value="true"/>
    <param name="publish/pvtgeodetic" value="true"/>
    <param name="publish/navsatfix" value="true"/>
    <param name="publish/gpsfix" value="true"/>
  </node>
</launch>
```

**ROS 2**:
```yaml
# config/mosaic_params.yaml
septentrio_gnss_driver:
  ros__parameters:
    device:
      serial:
        port: "/dev/ttyACM0"
        baudrate: 115200
    
    frame_id: "gnss"
    use_ros_axis_orientation: true
    
    publish:
      gpgga: true
      gprmc: true
      pvtgeodetic: true
      navsatfix: true
      gpsfix: true
```

```bash
ros2 launch septentrio_gnss_driver mosaic_launch.py
```

### 4.3 INS Configuration

#### 4.3.1 NovAtel SPAN Setup

**Prerequisites**:
- SPAN-equipped receiver (e.g., SPAN-CPT7)
- IMU connected and powered
- Initial alignment area (straight line, < 0.5 m/s²)

**Configuration**:
```yaml
# Specify position source for standard topics
oem7_position_source: "INSPVAS"  # Use INS solution

# Enable INS-specific topics
oem7_publish_inspva: true
oem7_publish_inspvax: true
oem7_publish_insstdev: true
oem7_publish_corrimu: true

# IMU frame
oem7_imu_frame_id: "imu_link"
```

**Monitor Alignment**:
```bash
# Watch INSPVA status
rostopic echo /novatel/oem7/inspva/status

# Status values:
# 0: INS_INACTIVE
# 1: INS_ALIGNING
# 3: INS_SOLUTION_GOOD (aligned)
```

#### 4.3.2 Septentrio INS Setup

**Prerequisites**:
- AsteRx-m3 Pro+ with IMU option
- IMU calibrated
- Initial heading known or dual-antenna for heading

**Configuration**:
```yaml
# Enable INS configuration
ins_spatial_config: true

# Initial conditions (if known)
ins_initial_heading: "auto"  # or specific value in degrees

# Standard deviations for initial conditions
ins_std_dev_x: 10.0    # meters
ins_std_dev_y: 10.0
ins_std_dev_z: 10.0

ins_std_dev_heading: 5.0  # degrees

# Enable INS topics
publish:
  insnavgeod: true
  imu: true
  localization: true
  pose: true
  tf: true

# Coordinate system
use_ros_axis_orientation: true  # ENU for ROS
```

**Monitor Alignment**:
```bash
# Watch INS status
rostopic echo /insnavgeod | grep info

# Check alignment bits (8-10 in info field)
# 3 = Fine alignment complete, heading reliable
```

### 4.4 RTK Configuration

#### 4.4.1 NovAtel RTK Setup

**Base Station Configuration** (via web interface or commands):
```
CONNECTIMU COM1 ANT1
INTERFACEMODE USB1 RTCM OFF
RTKCORR SEND OUTPUT USB1
```

**Rover Driver Configuration**:
```yaml
# Driver automatically handles RTK corrections via serial/TCP
# No special driver config needed

# Monitor RTK status
# rostopic echo /novatel/oem7/bestpos/pos_type/type
# 50 = NARROW_INT (RTK Fixed)
# 34 = NARROW_FLOAT (RTK Float)
```

**NTRIP Client** (if using NTRIP caster):
```bash
# Use separate NTRIP client node
rosrun ntrip_client ntrip_client_node
# Configure to forward corrections to receiver serial port
```

#### 4.4.2 Septentrio RTK Setup

**NTRIP Configuration** (via web interface):
```
Corrections → NTRIP Client
- Host: rtk.example.com
- Port: 2101
- Mountpoint: RTCM3_BASE
- Username/Password: (if required)
```

**Or via driver** (some versions support config commands):
```yaml
# Can send receiver commands on startup
device:
  configure_on_startup: true
  commands:
    - "setNTRIPClient, host, rtk.example.com, 2101, RTCM3_BASE, user, pass"
```

**Monitor RTK**:
```bash
# Check PVT mode
rostopic echo /pvtgeodetic/mode

# Mode 4 = RTK Fixed
# Mode 5 = RTK Float

# Check correction age
rostopic echo /pvtgeodetic/mean_corr_age
# Should be < 500 (5 seconds)
```

### 4.5 Multi-Sensor Fusion

#### 4.5.1 Using robot_localization

**NovAtel + robot_localization**:
```yaml
ekf_localization_node:
  frequency: 50
  
  odom0: /novatel/oem7/odom
  odom0_config: [true, true, true,    # x, y, z
                 false, false, false,  # roll, pitch, yaw
                 false, false, false,  # vx, vy, vz
                 false, false, false,  # vroll, vpitch, vyaw
                 false, false, false]  # ax, ay, az
  
  imu0: /novatel/oem7/imu
  imu0_config: [false, false, false,
                true, true, true,      # orientation
                false, false, false,
                true, true, true,      # angular velocity
                true, true, true]      # linear acceleration
```

**Septentrio + robot_localization**:
```yaml
ekf_localization_node:
  frequency: 50
  
  # Septentrio already provides fused INS solution
  # Use localization topic directly
  odom0: /localization
  odom0_config: [true, true, true,
                 true, true, true,
                 true, true, true,
                 false, false, false,
                 false, false, false]
  
  # Can still add additional IMU if needed
  imu0: /imu
  imu0_config: [false, false, false,
                true, true, true,
                false, false, false,
                true, true, true,
                false, false, false]
```

#### 4.5.2 Frame Tree Configuration

**Typical Transform Tree**:
```
map
 └─ odom
     └─ base_link
         ├─ gps (or gnss)
         ├─ imu
         └─ other sensors (lidar, camera, etc.)
```

**NovAtel**: Manually broadcast transforms
```xml
<node pkg="tf2_ros" type="static_transform_publisher" 
      name="base_to_gps" 
      args="0.5 0 0.8 0 0 0 base_link gps"/>

<node pkg="tf2_ros" type="static_transform_publisher"
      name="base_to_imu"
      args="0.3 0 0.5 0 0 0 base_link imu"/>
```

**Septentrio**: Automatic if configured
```yaml
# Driver broadcasts transforms in INS mode
ins_spatial_config: true
publish:
  tf: true

# Define antenna/IMU offsets
ant_lever_x: 0.5
ant_lever_y: 0.0
ant_lever_z: 0.8
```

### 4.6 Troubleshooting

#### 4.6.1 Common Issues - Both Drivers

**No Data Received**:
```bash
# Check connection
ls -l /dev/ttyUSB* # or /dev/ttyACM*

# Check permissions
sudo chmod 666 /dev/ttyUSB0

# Verify baud rate matches receiver config
# Default: 115200 for most receivers

# Check receiver power and LED status
```

**Time Synchronization Issues**:
```bash
# NovAtel: Check TIME message
rostopic echo /novatel/oem7/time/time_status
# Should be 180 (FINESTEERING)

# Septentrio: Check PVTGeodetic
rostopic echo /pvtgeodetic/error
# Should be 0
```

**Poor Position Quality**:
```bash
# Check satellite count
# NovAtel:
rostopic echo /novatel/oem7/bestpos/num_sol_svs
# Should be > 5

# Septentrio:
rostopic echo /pvtgeodetic/nr_sv
# Should be > 5

# Check for obstructions, multipath
# Move to open sky area for test
```

#### 4.6.2 NovAtel-Specific Issues

**INSPVA Not Publishing**:
```bash
# Verify SPAN receiver
# Check IMU power

# Monitor INS status
rostopic echo /novatel/oem7/inspva/status

# If status = 0 (INACTIVE):
# - IMU not detected
# - Check hardware connections
# - Verify SPAN license
```

**PPP Not Converging**:
```bash
# Check TerraStar subscription
rostopic echo /novatel/oem7/terrastarstatus

# Verify BESTPOS type
rostopic echo /novatel/oem7/bestpos/pos_type/type
# 68 = PPP_CONVERGING
# 69 = PPP (converged)

# PPP requires 15-30 minutes in open sky
```

#### 4.6.3 Septentrio-Specific Issues

**INS Not Aligning**:
```bash
# Check INSNavGeod info field
rostopic echo /insnavgeod | grep info

# If alignment stuck:
# - Drive straight line 50-100m
# - Maintain < 0.5 m/s² acceleration
# - Avoid sharp turns during alignment

# Check initial heading
# If unknown, use dual-antenna or magnetometer
```

**AIM+ Status Warnings**:
```bash
# Monitor interference
rostopic echo /aimplusstatus

# If interference detected:
# - Move away from RF sources
# - Check antenna installation
# - Verify antenna cable integrity
```

**OSNMA Authentication Failures**:
```bash
# Check Galileo authentication
rostopic echo /galauthstatus

# Requires:
# - Galileo signals available
# - OSNMA enabled in receiver
# - Firmware v4.12+ for mosaic
```

### 4.7 Data Logging and Analysis

#### 4.7.1 NovAtel Logging

**Record Native OEM7 Messages**:
```yaml
# Enable raw message publishing
oem7_publish_unknown_oem7raw: true
oem7_raw_msg_pub: true
```

```bash
# Record to rosbag
rosbag record /novatel/oem7/oem7raw

# Convert to NovAtel .gps format (if tools available)
# Or analyze directly from rosbag
```

**Record Standard Topics**:
```bash
rosbag record /novatel/oem7/bestpos \
              /novatel/oem7/bestvel \
              /novatel/oem7/inspva \
              /novatel/oem7/corrimu \
              /gps/fix \
              /gps/gps
```

#### 4.7.2 Septentrio Logging

**Record SBF Directly** (best for post-processing):
```bash
# Via receiver web interface or CLI:
# Setup internal logging to SD card or USB

# Or record all SBF topics:
rosbag record /pvtgeodetic \
              /poscovgeodetic \
              /velcovgeodetic \
              /atteuler \
              /insnavgeod
```

**Record to .pcap** (for replay):
```bash
# If connected via TCP/IP:
tcpdump -i eth0 -w septentrio.pcap port 28784

# Replay:
device:
  file:
    path: "/path/to/septentrio.pcap"
```

**Post-Processing with RxTools**:
- Export rosbag to .sbf format
- Use Septentrio RxTools for analysis
- Post-process with PPP-Wizard or similar

---

## Summary

### Key Takeaways

**NovAtel OEM7 Driver**:
- ✅ Mature, well-documented driver for professional GNSS/INS
- ✅ Excellent SPAN INS integration for high-performance applications
- ✅ TerraStar PPP support for global coverage
- ✅ High-rate IMU output (200 Hz)
- ⚠️ Requires understanding of OEM7 log structure
- ⚠️ Manual TF tree management
- ⚠️ Multiple messages for complete INS solution

**Septentrio GNSS Driver**:
- ✅ Superior interference mitigation (AIM+)
- ✅ OSNMA authentication for security applications
- ✅ High update rates (100 Hz GNSS)
- ✅ Comprehensive single-message INS solution
- ✅ Automatic coordinate transformation (NED ↔ ENU)
- ✅ Built-in TF broadcasting
- ⚠️ INS option only on specific models (AsteRx-m3 Pro+)
- ⚠️ Less widespread than NovAtel in some industries

### Selection Guide

| Application | Recommended Driver | Rationale |
|-------------|-------------------|-----------|
| Autonomous vehicles | Either (based on hardware) | Both excellent; choose based on existing hardware |
| UAV/Drone navigation | Septentrio | High update rates, interference mitigation |
| Marine surveying | NovAtel | SPAN heritage, TerraStar PPP |
| Agricultural automation | Septentrio | AIM+ for rural interference |
| Mining/Construction | NovAtel | Robust SPAN systems, proven track record |
| Academic research | Either | Both well-supported in ROS ecosystem |
| Security-critical | Septentrio | OSNMA authentication |
| Urban environments | Septentrio | Superior multipath/interference handling |

### Further Resources

**NovAtel OEM7**:
- Official Documentation: https://docs.novatel.com/OEM7
- Driver Repository: https://github.com/novatel/novatel_oem7_driver
- ROS Wiki: http://wiki.ros.org/novatel_oem7_driver

**Septentrio**:
- Official Documentation: https://www.septentrio.com/en/support/documentation
- Driver Repository: https://github.com/septentrio-gnss/septentrio_gnss_driver
- ROS Wiki: http://wiki.ros.org/septentrio_gnss_driver

---

*Document Version: 1.0*  
*Last Updated: December 2024*  
*Authors: Technical analysis based on official driver documentation and ROS integration specifications*