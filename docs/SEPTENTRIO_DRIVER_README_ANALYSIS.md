# Septentrio Driver README Analysis - Key Findings

**Date**: December 10, 2025  
**Source**: `septentrio_gnss_driver/README.md` (786 lines)  
**Purpose**: Extract key technical information needed for integration

---

## Key Findings Summary

### ✅ What Driver Currently Supports (Already Works)

**Hardware**:
- Septentrio mosaic-H, mosaic-X5
- AsteRx-m3 Pro+, AsteRx-SB Pro+, AsteRx-SBi3 Pro
- Single antenna GNSS
- Dual antenna GNSS
- INS (Inertial Navigation System) receivers

**Connection Types**:
- Serial (via /dev/ttyS0, USB, COM ports)
- TCP/IP (default: 192.168.3.1:28784)
- UDP
- PCAP playback (from recorded files)
- SBF file playback (from .sbf logs)

**Published Topics** (Currently Working):
- `/measepoch` — raw observations (MeasEpoch SBF block)
- `/pvtgeodetic` — position/velocity/time (PVTGeodetic SBF block)
- `/poscovgeodetic` — position covariance
- `/velcovgeodetic` — velocity covariance
- `/atteuler` — dual-antenna heading/pitch
- `/basevectorgeod` — dual-antenna baseline vector
- `/gpsfix` — composite message (blends multiple blocks)
- `/navsatfix` — standard ROS NavSatFix message
- `/pose` — geometry_msgs/PoseWithCovarianceStamped
- `/twist` — velocity with covariance
- `/diagnostics` — receiver status

**ROS2 Support**:
- Humble (✅ Our version)
- Foxy, Galactic, Iron, Jazzy, Rolling
- Built with C++17

---

### ❌ What Driver Does NOT Support (Missing)

**Navigation Data NOT Published**:
- ❌ GPS Ephemeris (SBF block 4027 `GPSNav`)
- ❌ Galileo Ephemeris (SBF block 4028 `GALNav`)
- ❌ GPS Ionosphere (IonUtc)
- ❌ Galileo Ionosphere (GalIono)
- ❌ GGTO (Galileo-GPS time offset, `GalClock`)
- ❌ RTCM Corrections (passthrough from NTRIP/IP/serial)

**Why Missing**: 
- These blocks exist in receiver's internal processing
- Driver doesn't expose them as ROS topics
- Would require adding: messages, parsers, publishers

---

## Critical Configuration Settings

### configure_rx Parameter (MOST IMPORTANT)

**Default**: `true`

**Effect**:
- When `true`: Driver configures the receiver (programs it)
- When `false`: Receiver must be pre-configured via web interface; driver just reads

```yaml
configure_rx: true  # ← MUST BE TRUE to enable new blocks
```

**Why Important**: If you add new SBF blocks (ephemeris, iono, GGTO), the receiver needs to output them. Setting `configure_rx: true` makes the driver send setup commands to the receiver.

### publishing_period Settings

Controls how often SBF blocks are requested:

```yaml
polling_period:
  pvt: 500        # PVT every 500ms (2 Hz)
  rest: 500       # Other blocks every 500ms
```

**For Ephemeris/Iono/GGTO**: These update slowly:
```yaml
polling_period:
  pvt: 500
  rest: 3600      # or 86400 for daily updates
```

### Device Connection

```yaml
device: tcp://192.168.3.1:28784  # Default TCP via USB
# OR
device: serial:/dev/serial/by-id/usb-Septentrio_...
# OR
device: file_name:/path/to/file.pcap  # For testing offline
```

---

## SBF Block Architecture

### How SBF Blocks Work (From README)

**SBF** = Septentrio Binary Format

**Block Structure**:
```
[Header (8 bytes)] [Payload (variable)] [CRC (2 bytes)]
```

**Key Blocks Already Supported**:
```
MeasEpoch       (4101?) → raw observations
PVTGeodetic     (4007)  → position/velocity
PosCovGeodetic  (5902)  → position covariance
VelCovGeodetic  (5903)  → velocity covariance
AttEuler        (5905)  → attitude (heading/pitch)
BaseVectorGeod  (4028?) → baseline (dual-antenna)
ReceiverTime    (5914)  → receiver clock info
ChannelStatus   (4013)  → satellite signal info
DOP             (4001)  → dilution of precision
RFStatus        (4014)  → RF band status
```

**Blocks We Want to Add**:
```
GPSNav          (4027)  → GPS ephemeris
GALNav          (4028)  → Galileo ephemeris
IonUtc          (?)     → Ionosphere model (GPS)
GalIono         (?)     → Ionosphere model (GAL)
GalClock        (?)     → GPS-Galileo time offset
```

---

## "Adding New SBF Blocks" Process (From README)

The README (section: "Adding New SBF Blocks or NMEA Sentences") gives exact steps:

### Step 1: Find Block Reference
→ Check firmware manual for SBF block definition

### Step 2: Add ROS Message File
→ Create `msg/YourBlock.msg` file

### Step 3: Update CMakeLists.txt
→ Add to `add_message_files()` section

### Step 4: Add Struct & Typedef
→ `include/septentrio_gnss_driver/abstraction/typedefs.hpp`
→ `include/septentrio_gnss_driver/parsers/sbf_blocks.hpp`

### Step 5: Add Parser & Switch Case
→ `src/septentrio_gnss_driver/communication/message_handler.cpp`
→ Extend `SbfId` enum
→ Add switch case for new block ID

### Step 6: Create Publish Parameter
→ `config/rover.yaml`: add `publish.xxx: true/false`
→ `include/septentrio_gnss_driver/node/settings.h`: add boolean flag

### Step 7: Configure Receiver Output
→ `src/septentrio_gnss_driver/communication/communication_core.cpp`
→ In `configureRx()` function, request block from receiver

---

## Firmware Requirements

**Minimum Versions**:
- GNSS: >= 4.10.0
- INS: >= 1.3.2

**Known Limitations**:
- GNSS < 4.10.0: No IP over USB
- GNSS < 4.12.1: No OSNMA (authentication)
- GNSS < 4.14: No PTP server clock
- UDP over USB: Blocks sent twice on firmware <= 4.12.1 (fixed in 4.14)

**For Ephemeris Blocks**: Need to verify if firmware supports GPSNav/GALNav blocks. Check with receiver's reference guide for your firmware version.

---

## Data Stream Configuration

### Important Notes from README

1. **SBF blocks use bandwidth** 
   - MeasEpoch = ~400 kBit/s (high bandwidth)
   - Ephemeris blocks = very low bandwidth (infrequent updates)
   - Ensure baudrate sufficient (921600 default is OK)

2. **Multiple SBF blocks must be synchronized**
   - If composing messages from multiple blocks
   - All blocks should have same output period
   - Example: GPSFix message blends 8 different SBF blocks

3. **Static TCP Server Recommended** (not dynamic connection)
   - `stream_device.tcp.ip_server` and `stream_device.tcp.port`
   - More reliable than dynamic TCP on `device` parameter
   - Useful when receiver may reconnect

4. **Custom Commands File**
   - Can pass additional setup commands via `custom_commands_file: path/to/commands.txt`
   - Format: one command per line
   - Example: commands to request specific SBF blocks

---

## Current Driver Code Files Involved

### Files to Read/Modify for Adding Ephemeris

**Message Definitions**:
- `msg/` — all `.msg` files
- Example: `msg/MeasEpoch.msg` (observe structure)

**Core Parser Logic**:
- `include/septentrio_gnss_driver/parsers/sbf_blocks.hpp` — struct definitions
- `src/septentrio_gnss_driver/communication/message_handler.cpp` — parsing + publishing

**Configuration**:
- `config/rover.yaml` — runtime parameters
- `include/septentrio_gnss_driver/node/settings.h` — parameter definitions

**Receiver Communication**:
- `src/septentrio_gnss_driver/communication/communication_core.cpp` — setup commands

**Node Initialization**:
- `src/septentrio_gnss_driver/node/rosaic_node.cpp` — publisher creation

---

## What Firmware Manual You Need

**Find**: Septentrio mosaic-H (or your receiver) Reference Guide

**Location**: https://www.septentrio.com/en/support/

**Sections Needed**:
1. **SBF Block Specifications** (Chapter 4 or similar)
   - GPSNav block structure and fields
   - GALNav block structure and fields
   - Any iono/clock blocks available

2. **Block IDs**
   - Exact ID numbers (4027, 4028, etc.)
   - Some IDs may differ from examples

3. **Command Reference**
   - How to request blocks (e.g., `setDataInOut` command)
   - How to set block output rates

---

## Testing Strategy (From README)

### Option 1: Live Receiver
```bash
ros2 launch septentrio_gnss_driver rover.launch.py device:=tcp://192.168.3.1:28784
```

### Option 2: Offline Playback (No Receiver Needed)
```yaml
# config/rover.yaml
device: file_name:/path/to/recorded.pcap  # PCAP capture log
# or
device: file_name:/path/to/recorded.sbf   # SBF binary log
```

**Advantage**: Can test parser on same data repeatedly without receiver

---

## Summary Table

| Aspect | Status | Details |
|--------|--------|---------|
| **Driver Support** | ✅ Excellent | Well-designed, extensible |
| **Current Outputs** | ✅ Good | Observations, PVT, dual-antenna |
| **Ephemeris Support** | ❌ None | Must implement from scratch |
| **Effort to Add** | 🟡 Medium | ~1-2 weeks with firmware manual |
| **Risk Level** | 🟡 Medium | Requires binary parsing, firmware knowledge |
| **Alternative** | ✅ Yes | External BRDC provider (faster) |

---

## Next Steps

1. **Obtain Firmware Manual**
   - Go to: https://www.septentrio.com/en/support/
   - Download: mosaic-H (or your receiver) Reference Guide
   - Find: Chapter on SBF blocks, GPSNav & GALNav specifications

2. **Check Firmware Version**
   - Access web UI: 192.168.3.1
   - Note: firmware version
   - Verify: minimum 4.10.0

3. **Decide: Option A vs B**
   - Option A (Extend Driver): Start implementation if manual available
   - Option B (External Provider): Faster if you want quick prototype

---

**Document Created**: 2025-12-10  
**Status**: Ready for next phase  
**Recommendation**: Obtain firmware manual before starting driver modification

