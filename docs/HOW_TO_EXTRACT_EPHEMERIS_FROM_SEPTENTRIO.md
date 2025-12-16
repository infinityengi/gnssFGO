# How to Extract Ephemeris, Ionosphere, GGTO, RTCM from Septentrio Driver

**Date**: December 10, 2025  
**Purpose**: Technical guide on extracting nav data from Septentrio Mosaic-H receiver  
**Level**: For developers modifying the driver (Option A)  

---

## Table of Contents

1. [Data Available in Receiver](#1-data-available-in-receiver)
2. [SBF Block Reference](#2-sbf-block-reference)
3. [Step-by-Step Implementation Guide](#3-step-by-step-implementation-guide)
4. [Code Examples](#4-code-examples)
5. [Configuration](#5-configuration)
6. [Testing](#6-testing)

---

## 1. Data Available in Receiver

The Septentrio Mosaic-H receiver **internally uses** the following data to compute PVT, but does NOT currently expose them as ROS topics:

### 1.1 Required Data Types

| Data Type | SBF Block ID | Block Name | Update Rate | Purpose |
|-----------|--------------|-----------|-------------|---------|
| **GPS Ephemeris** | 4027 | GPSNav | ~2 hours or on change | Satellite orbit & clock for GPS signals |
| **GAL Ephemeris** | 4028 | GALNav | ~2 hours or on change | Satellite orbit & clock for Galileo signals |
| **GPS Ionosphere** | TBD (varies) | IonUtc* | Hourly or on change | Ionospheric delay model (Klobuchar) |
| **GAL Ionosphere** | TBD (varies) | GalIono* | Hourly or on change | Galileo NeQuick-G ionosphere model |
| **GGTO (GPS-GAL offset)** | TBD (varies) | GalClock* | Daily or on change | Time offset between GPS and Galileo |
| **RTCM Corrections** | (passthrough) | RTCM stream | Real-time | RTK corrections (from NTRIP/IP/serial) |

*exact block IDs vary by firmware version

---

## 2. SBF Block Reference

### 2.1 How to Find Available Blocks

**Step 1**: Check receiver firmware version
```bash
# Via ROSaic web interface (192.168.3.1)
# Or via command interface
# Look for: firmware version >= 4.10.0 (GNSS)
```

**Step 2**: Check official Septentrio documentation
- Product Support: https://www.septentrio.com/en/support/
- Find your receiver (e.g., mosaic-H)
- Download **Reference Guide** (e.g., "mosaic-H Reference Guide v4.xx")
- Chapter: "SBF Block Specifications" or "Message Reference"

**Step 3**: Locate specific blocks
- Search for: `GPSNav`, `GALNav`, `IonUtc`, `GalIono`, `GalClock` (block names)
- Record: Block ID (4-digit number), structure, update rate

### 2.2 GPS Ephemeris Block (GPSNav, ID 4027)

**Structure** (from Septentrio firmware manual):
```cpp
struct GPSNav
{
    uint8_t PRN;                    // Satellite PRN (1-32)
    uint8_t Reserved;
    uint16_t Year, Month, Day;      // Ephemeris issue date
    uint16_t Hour, Minute, Second;  // Ephemeris issue time
    double TGD;                     // Group delay (seconds)
    double IODC;                    // Issue of Data Clock
    double IODE;                    // Issue of Data Ephemeris
    double ClkA2, ClkA1, ClkA0;    // Clock polynomial coefficients
    double Crs, Crc, Cus, Cuc, Cis, Cic; // Amplitude corrections
    double Delta_n, M0, e;          // Mean motion, mean anomaly, eccentricity
    double omega, OMEGA, OMEGA_dot; // Argument of perigee, RAAN, RAAN rate
    double i0, i_dot;               // Inclination, inclination rate
    double a;                       // Semi-major axis
    // ... more fields
};
```

**Key Fields for Preprocessing**:
- `PRN`: Satellite identifier
- `ClkA0`, `ClkA1`, `ClkA2`: Clock bias, drift, drift rate
- `a`, `e`, `M0`, `omega`, `OMEGA`, `i0`: Orbital parameters
- `Year`, `Month`, `Day`, `Hour`, `Minute`, `Second`: Ephemeris epoch

### 2.3 Galileo Ephemeris Block (GALNav, ID 4028)

**Structure** (similar to GPS but Galileo-specific):
```cpp
struct GALNav
{
    uint8_t PRN;                    // Satellite PRN (1-36)
    uint8_t Reserved;
    uint16_t Year, Month, Day;
    uint16_t Hour, Minute, Second;
    double BGD_E1_E5a, BGD_E1_E5b;  // Group delay (E1-E5a, E1-E5b)
    double IODnav;                  // Issue of Data Navigation
    double ClkA2, ClkA1, ClkA0;    // Clock polynomial coefficients
    double Crs, Crc, Cus, Cuc, Cis, Cic;
    double Delta_n, M0, e;
    double omega, OMEGA, OMEGA_dot;
    double i0, i_dot;
    double a;
    // ... more fields
};
```

---

## 3. Step-by-Step Implementation Guide

The README ("Adding New SBF Blocks") outlines these steps:

### Step 3.1: Create ROS Message Definitions

Create `.msg` files for new blocks in `msg/` directory:

**File: `msg/GPSEphemeris.msg`**
```
Header header
uint8 PRN
uint16 Year
uint16 Month
uint16 Day
uint16 Hour
uint16 Minute
uint16 Second
float64 TGD
float64 IODC
float64 IODE
float64 ClkA2
float64 ClkA1
float64 ClkA0
float64 Crs
float64 Crc
float64 Cus
float64 Cuc
float64 Cis
float64 Cic
float64 Delta_n
float64 M0
float64 e
float64 omega
float64 OMEGA
float64 OMEGA_dot
float64 i0
float64 i_dot
float64 a
```

**File: `msg/GALEphemeris.msg`**
(Similar structure, with Galileo-specific fields like `BGD_E1_E5a`, `IODnav`)

**File: `msg/Ionosphere.msg`**
```
Header header
float64 ai0
float64 ai1
float64 ai2
uint16 Region
uint8 TOW
uint8 WN
```

**File: `msg/GGTO.msg`**
```
Header header
float64 a0
float64 a1
uint16 WN0
uint16 WN1
uint16 TOW0
```

### Step 3.2: Update CMakeLists.txt

In `CMakeLists.txt`, add your new messages to `add_message_files()`:

```cmake
add_message_files(
  FILES
  # ... existing messages ...
  GPSEphemeris.msg
  GALEphemeris.msg
  Ionosphere.msg
  GGTO.msg
)
```

### Step 3.3: Add Message Header & Typedef

File: `include/septentrio_gnss_driver/abstraction/typedefs.hpp` (or typedefs_ros1.hpp)

Add includes for new messages:
```cpp
#include <septentrio_gnss_driver/msg/GPSEphemeris.hpp>
#include <septentrio_gnss_driver/msg/GALEphemeris.hpp>
#include <septentrio_gnss_driver/msg/Ionosphere.hpp>
#include <septentrio_gnss_driver/msg/GGTO.hpp>
```

### Step 3.4: Add SBF Parser

File: `include/septentrio_gnss_driver/parsers/sbf_blocks.hpp`

Look for existing GPS/GAL structures (they may already exist), or add new ones:

```cpp
struct GPSNav
{
    uint8_t PRN;
    uint8_t Reserved;
    uint16_t Year, Month, Day;
    uint16_t Hour, Minute, Second;
    double TGD;
    double IODC;
    double IODE;
    // ... all fields from firmware manual
};

struct GALNav
{
    // Similar structure
};
```

**Note**: Check if these structures already exist in the file (search with grep)

### Step 3.5: Extend SBF ID Enumeration

File: `include/septentrio_gnss_driver/communication/message_handler.hpp`

Add enum values:
```cpp
enum SbfId : uint16_t
{
    // Existing IDs...
    PVTGeodetic = 4007,
    MeasEpoch = 4027,      // Note: may conflict if MeasEpoch is already using this
    GPSNav = 4027,         // GPS ephemeris
    GALNav = 4028,         // Galileo ephemeris
    // ... find correct IDs from firmware manual
};
```

**IMPORTANT**: Check the official firmware manual for **correct block IDs** (they vary by receiver type)

### Step 3.6: Add SBF Switch-Case Handler

File: `src/septentrio_gnss_driver/communication/message_handler.cpp`

Find the main `switch(sbf_id)` statement handling SBF blocks. Add cases:

```cpp
case SbfId::GPSNav: {
    parseGPSNav(buffer, gps_ephem_msg);
    pub_gps_ephem_->publish(gps_ephem_msg);
    break;
}
case SbfId::GALNav: {
    parseGALNav(buffer, gal_ephem_msg);
    pub_gal_ephem_->publish(gal_ephem_msg);
    break;
}
// ... similar for Iono, GGTO
```

### Step 3.7: Create Publisher & Toggle Parameter

File: `include/septentrio_gnss_driver/communication/receiver.hpp`

Add publisher members:
```cpp
rclcpp::Publisher<septentrio_gnss_driver::msg::GPSEphemeris>::SharedPtr pub_gps_ephem_;
rclcpp::Publisher<septentrio_gnss_driver::msg::GALEphemeris>::SharedPtr pub_gal_ephem_;
rclcpp::Publisher<septentrio_gnss_driver::msg::Ionosphere>::SharedPtr pub_iono_;
rclcpp::Publisher<septentrio_gnss_driver::msg::GGTO>::SharedPtr pub_ggto_;
```

File: `src/septentrio_gnss_driver/node/rosaic_node.cpp`

Create publishers in node initialization:
```cpp
pub_gps_ephem_ = create_publisher<septentrio_gnss_driver::msg::GPSEphemeris>(
    "/gps_ephemeris", rclcpp::SensorDataQoS());
pub_gal_ephem_ = create_publisher<septentrio_gnss_driver::msg::GALEphemeris>(
    "/gal_ephemeris", rclcpp::SensorDataQoS());
// ... etc
```

### Step 3.8: Add Configuration Parameter

File: `config/rover.yaml`

Add publish flags:
```yaml
publish:
  gpsephem: true
  galeph: true
  iono: true
  ggto: true
  # ... existing flags
```

File: `include/septentrio_gnss_driver/node/settings.h`

Add boolean variables:
```cpp
bool publish_gpsephem = false;
bool publish_galeph = false;
bool publish_iono = false;
bool publish_ggto = false;
```

### Step 3.9: Configure Receiver to Output Blocks

File: `src/septentrio_gnss_driver/communication/communication_core.cpp`

In `configureRx()` function, add setup commands to request SBF blocks:

```cpp
// Example (adjust based on actual command syntax from firmware manual)
queueRxCommand("setDataInOut,COM1,+GPSNav,sec2");      // GPS ephem every 2 sec
queueRxCommand("setDataInOut,COM1,+GALNav,sec2");      // GAL ephem every 2 sec
queueRxCommand("setDataInOut,COM1,+IonUtc,sec3600");   // Iono hourly
queueRxCommand("setDataInOut,COM1,+GalClock,sec3600"); // GGTO daily
```

---

## 4. Code Examples

### Example 4.1: Parsing GPS Ephemeris

```cpp
void parseGPSNav(const std::vector<uint8_t>& buffer, 
                 septentrio_gnss_driver::msg::GPSEphemeris& msg)
{
    // SBF blocks have header (8 bytes) + payload
    // Skip header, start reading at byte 8
    
    uint32_t offset = 8;
    
    // Parse PRN (1 byte)
    msg.PRN = buffer[offset++];
    
    // Parse Year (2 bytes, little-endian)
    msg.Year = (buffer[offset] << 8) | buffer[offset+1];
    offset += 2;
    
    // Parse Month (2 bytes)
    msg.Month = (buffer[offset] << 8) | buffer[offset+1];
    offset += 2;
    
    // ... continue for all fields
    
    // Parse double fields (8 bytes each)
    msg.TGD = parseDouble(buffer, offset);
    offset += 8;
    
    msg.IODC = parseDouble(buffer, offset);
    offset += 8;
    
    // ... etc
    
    // Set timestamp
    msg.header.stamp = rclcpp::Clock(RCL_ROS_TIME).now();
    msg.header.frame_id = frame_id_;
}

// Helper function
double parseDouble(const std::vector<uint8_t>& buffer, uint32_t offset)
{
    double value;
    std::memcpy(&value, &buffer[offset], sizeof(double));
    return value;
}
```

### Example 4.2: Gating Publisher Based on Parameter

```cpp
// In message_handler.cpp, inside the switch case:

if (settings_.publish_gpsephem)
{
    pub_gps_ephem_->publish(gps_ephem_msg);
}

if (settings_.publish_galeph)
{
    pub_gal_ephem_->publish(gal_ephem_msg);
}
```

---

## 5. Configuration

### 5.1 rover.yaml Settings

```yaml
configure_rx: true  # IMPORTANT: Must be true to configure receiver

publish:
  gpsephem: true
  galeph: true
  iono: true
  ggto: true
  
# Optional: Set block update rates (if receiver supports)
polling_period:
  ephem: 3600     # 1 hour for ephemeris
  iono: 3600      # 1 hour for ionosphere
  ggto: 86400     # 1 day for GGTO
```

### 5.2 Expected Topics After Implementation

```bash
ros2 topic list | grep -E 'ephemeris|iono|ggto'

# Should see:
/gps_ephemeris
/gal_ephemeris
/gps_iono
/gal_iono
/ggto
```

---

## 6. Testing

### 6.1 Build & Verify

```bash
cd /workspace/fgo_ws
colcon build --packages-select septentrio_gnss_driver

# Check for compilation errors
# Look for: "undefined reference to" issues related to new parsers
```

### 6.2 Launch & Inspect Topics

```bash
# Terminal 1: Launch driver
ros2 launch septentrio_gnss_driver rover.launch.py device:=tcp://192.168.3.1:28784

# Terminal 2: Verify topics appear
ros2 topic list | grep -E 'ephemeris|iono|ggto'

# Terminal 3: Inspect message content
ros2 topic echo /gps_ephemeris --max-count 3
ros2 topic echo /gal_ephemeris --max-count 3
```

### 6.3 Verify Data

Check that:
- [ ] PRN > 0 and reasonable (1-32 for GPS, 1-36 for GAL)
- [ ] Year/Month/Day are current
- [ ] Orbital parameters (a, e, M0, etc.) are non-zero
- [ ] Clock coefficients populated
- [ ] Update rate matches configuration (check timestamps)

### 6.4 Common Issues & Solutions

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| Topics don't appear | `configure_rx: false` | Set to `true` in rover.yaml |
| Parser crashes | Wrong block ID | Verify ID in firmware manual |
| Messages empty | Block not enabled in receiver | Check receiver config via web UI |
| Compilation fails | Message file not in CMakeLists | Add to `add_message_files()` |
| Data looks wrong | Byte order/endianness | Check struct packing in firmware manual |

---

## 7. Resources

### Firmware Manuals (Required)
- https://www.septentrio.com/en/support/ (product page → Reference Guide)
- Look for: "SBF Message Reference" or "Block Definitions"

### ROSaic GitHub (Reference)
- https://github.com/septentrio-gnss/septentrio_gnss_driver
- Branch: `ros2`
- Files: `include/septentrio_gnss_driver/parsers/sbf_blocks.hpp`

### Existing Block Examples (In This Driver)
- `msg/MeasEpoch.msg` — raw observations (reference)
- `msg/PVTGeodetic.msg` — position/velocity (reference)
- Examine structure to understand pattern

---

## 8. Alternative: Use PCAP Dump for Testing

If receiver not available, test parser on recorded SBF data:

```yaml
# config/rover.yaml
device: file_name:path/to/recorded.pcap  # or .sbf

# Then parser will be tested on recorded blocks
```

---

## Summary Checklist

To extract ephemeris/iono/GGTO from driver:

- [ ] Identify correct SBF block IDs (from firmware manual)
- [ ] Create `.msg` files for each block type
- [ ] Add to `CMakeLists.txt` `add_message_files()`
- [ ] Add struct definitions to `sbf_blocks.hpp`
- [ ] Add enum entries to `SbfId`
- [ ] Add switch cases in `message_handler.cpp`
- [ ] Create publishers and toggle parameters
- [ ] Configure receiver to output blocks (rover.yaml + configureRx())
- [ ] Build and test
- [ ] Verify topics publish correct data

---

**Estimated Effort**: 1-2 weeks with firmware manual access  
**Risk Level**: Medium (requires understanding SBF binary format)  
**Firmware Requirement**: >= 4.10.0 (GNSS)

