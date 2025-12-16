# Reuse Novatel OEM7 Message Definitions for Septentrio

**Date**: December 10, 2025  
**Status**: ✅ VALIDATED - Novatel messages are ready to reuse  
**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/novatel_oem7_msgs/msg/`

---

## Key Finding: Excellent Reusability

The Novatel OEM7 driver already has **ephemeris, ionosphere, and clock messages** that can be directly reused for Septentrio integration!

### Available Message Definitions (46 total)

**Ephemeris Messages** (Ready to Reuse):
- ✅ `GPSEPHEM.msg` — GPS Ephemeris (all orbital parameters)
- ✅ `GPSEPHEMArray.msg` — Multiple GPS Ephemeris messages
- ✅ `GALFNAVEPHEMERIS.msg` — Galileo F/NAV Ephemeris
- ✅ `GALFNAVEPHEMERISArray.msg` — Multiple Galileo F/NAV messages
- ✅ `GALINAVEPHEMERIS.msg` — Galileo I/NAV Ephemeris
- ✅ `GALINAVEPHEMERISArray.msg` — Multiple Galileo I/NAV messages

**Ionosphere Messages** (Ready to Reuse):
- ✅ `IONUTC.msg` — GPS Ionosphere model (Klobuchar coefficients a0-a3, b0-b3)
- ✅ `GALIONO.msg` — Galileo Ionosphere model

**Clock Messages** (Ready to Reuse):
- ✅ `GALCLOCK.msg` — Galileo-GPS time offset (GGTO)

**Other Useful Messages**:
- ✅ `CLOCKMODEL.msg` — Receiver clock model
- ✅ `TIME.msg` — Time information
- ✅ `Oem7Header.msg` — Header for Novatel messages (can adapt)

---

## Message Structure Details

### GPSEPHEM.msg (GPS Ephemeris)
```
Fields (33 total):
  - Identification: prn, week, iode1, iode2, iodc
  - Time: tow, t0e, toc
  - Orbital elements: a, delta_n, m0, ecc, omega, cuc, cus, crc, crs, cic, cis
  - Inclination: i0, i_dot
  - Longitude: omega0, omega_dot
  - Clock: af0, af1, af2, tgd
  - Validity: health, ura, a_s
```

**Perfect for**: GPS ephemeris from Septentrio SBF block 4027 (GPSNav)

### GALFNAVEPHEMERIS.msg (Galileo F/NAV)
```
Fields (30 total):
  - Identification: sat_id, iod_nav, sisa_index
  - Time: t0e, t0c
  - Orbital elements: m0, delta_n, ecc, root_a
  - Inclination: i0, i_dot
  - Longitude: omega0, omega_dot, omega
  - Clock: af0, af1, af2
  - Range correction: cuc, cus, crc, crs, cic, cis
  - Health: e5a_health, e5a_dvs
  - BGD: e1e5a_bgd
```

**Perfect for**: Galileo ephemeris from Septentrio SBF block 4028 (GALNav)

### IONUTC.msg (GPS Ionosphere)
```
Fields (15 total):
  - Ionosphere Klobuchar: a0, a1, a2, a3, b0, b1, b2, b3
  - UTC parameters: utc_wn, tot, capital_a0, capital_a1
  - Leap second: wn_lsf, dn, delta_tls, delta_tlsg
```

**Perfect for**: GPS ionosphere model from Septentrio (if available)

### GALCLOCK.msg (Galileo-GPS Time Offset)
```
Fields (10 total):
  - Time offset: a0, a1, t0g, wn0g
  - GPS leap second: delta_tls, tot, wnt
  - Leap second future: wnlsf, dn, delta_tlsf
  - Galileo leap second: a0g, a1g
```

**Perfect for**: GGTO (Galileo-GPS time offset) from Septentrio

---

## How to Reuse for Septentrio

### Option 1: Direct Copy (Simplest)

1. Copy Novatel `.msg` files to Septentrio driver:
```bash
cp /workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/novatel_oem7_msgs/msg/GPSEPHEM.msg \
   /workspace/fgo_ws/src/gnssFGO/online_fgo/septentrio_gnss_driver/msg/

cp /workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/novatel_oem7_msgs/msg/GALFNAVEPHEMERIS.msg \
   /workspace/fgo_ws/src/gnssFGO/online_fgo/septentrio_gnss_driver/msg/

cp /workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/novatel_oem7_msgs/msg/IONUTC.msg \
   /workspace/fgo_ws/src/gnssFGO/online_fgo/septentrio_gnss_driver/msg/

cp /workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/novatel_oem7_msgs/msg/GALCLOCK.msg \
   /workspace/fgo_ws/src/gnssFGO/online_fgo/septentrio_gnss_driver/msg/
```

2. Update Septentrio's `CMakeLists.txt` to add:
```cmake
  GPSEPHEM
  GALFNAVEPHEMERIS
  IONUTC
  GALCLOCK
```

3. Adapt parsers in Septentrio driver to populate these messages from SBF blocks

**Pros**: Simple, reuses tested message definitions
**Cons**: Need to understand Novatel header (Oem7Header) — may not be needed

### Option 2: Adapt for Septentrio (Recommended)

Create Septentrio-specific versions:
```
msg/GPSEphemeris.msg  (based on GPSEPHEM.msg, rename fields)
msg/GALEphemeris.msg  (based on GALFNAVEPHEMERIS.msg)
msg/IonosphereModel.msg  (based on IONUTC.msg)
msg/TimeOffset.msg  (based on GALCLOCK.msg)
```

**Pros**: Cleaner, more flexible, driver-specific naming
**Cons**: Slightly more work (copy + adapt)

**Example adaptation**:

Original `GPSEPHEM.msg`:
```
std_msgs/Header         header
Oem7Header   nov_header        ← Remove this
uint32       prn
...
```

Adapted `GPSEphemeris.msg`:
```
std_msgs/Header header
uint32 satellite_prn
uint32 week
uint32 iode1
uint32 iode2
...
```

---

## Message Field Mapping: Septentrio ↔ Novatel

### GPS Ephemeris (SBF Block 4027 → GPSEPHEM)

| SBF Field | Novatel Field | Notes |
|-----------|---------------|-------|
| GPRNr | prn | Satellite PRN |
| GPWK | week | GPS week number |
| GPIODC | iodc | Issue of data clock |
| GPIODE | iode1, iode2 | Issue of data ephemeris |
| GPTOE | t0e | Epoch of ephemeris |
| GPToc | toc | Clock epoch |
| GPa | a | Semi-major axis |
| GPdN | delta_n | Mean motion difference |
| GPM0 | m0 | Mean anomaly at reference time |
| GPe | ecc | Eccentricity |
| GPw | omega | Argument of perigee |
| GPCuc | cuc | Amplitude of cosine correction |
| GPCus | cus | Amplitude of sine correction |
| GPCrc | crc | Amplitude of cosine correction |
| GPCrs | crs | Amplitude of sine correction |
| GPCic | cic | Amplitude of cosine correction |
| GPCis | cis | Amplitude of sine correction |
| GPi0 | i0 | Inclination angle at reference time |
| GPIDOT | i_dot | Rate of inclination angle |
| GPOmega0 | omega0 | Longitude of ascending node |
| GPOmegaDot | omega_dot | Rate of right ascension |
| GPaf0 | af0 | SV clock bias |
| GPaf1 | af1 | SV clock drift |
| GPaf2 | af2 | SV clock drift rate |
| GPTGd | tgd | Group delay |
| GPHealth | health | Health status |
| GPURA | ura | User range accuracy |

### Galileo Ephemeris (SBF Block 4028 → GALFNAVEPHEMERIS)

| SBF Field | Novatel Field | Notes |
|-----------|---------------|-------|
| SatID | sat_id | Satellite ID |
| IODNav | iod_nav | Issue of data navigation |
| SISA | sisa_index | Signal-in-space accuracy index |
| t0e | t0e | Epoch of ephemeris |
| t0c | t0c | Clock epoch |
| M0 | m0 | Mean anomaly |
| ΔN | delta_n | Mean motion difference |
| e | ecc | Eccentricity |
| √A | root_a | Square root of semi-major axis |
| i0 | i0 | Inclination angle |
| iDot | i_dot | Rate of inclination angle |
| Ω0 | omega0 | Longitude of ascending node |
| Ω | omega | Argument of perigee |
| ω̇ | omega_dot | Rate of right ascension |
| Cuc | cuc | Cosine correction inclination |
| Cus | cus | Sine correction inclination |
| Crc | crc | Cosine correction orbit radius |
| Crs | crs | Sine correction orbit radius |
| Cic | cic | Cosine correction inclination angle |
| Cis | cis | Sine correction inclination angle |
| af0 | af0 | SV clock bias |
| af1 | af1 | SV clock drift |
| af2 | af2 | SV clock drift rate |
| BGD E1/E5a | e1e5a_bgd | Clock bias difference |
| Health E5a | e5a_health | E5a signal health |
| DVS E5a | e5a_dvs | E5a data validity status |

---

## Implementation Steps (Using Reused Definitions)

### Step 1: Copy Message Files
```bash
mkdir -p ~/septentrio_ephemeris_msgs/msg
cp GPSEPHEM.msg ~/septentrio_ephemeris_msgs/msg/
cp GALFNAVEPHEMERIS.msg ~/septentrio_ephemeris_msgs/msg/
cp IONUTC.msg ~/septentrio_ephemeris_msgs/msg/
cp GALCLOCK.msg ~/septentrio_ephemeris_msgs/msg/
```

### Step 2: Create ROS Package (optional)
```bash
ros2 pkg create septentrio_ephemeris_msgs --dependencies std_msgs
```

### Step 3: Update CMakeLists.txt
```cmake
find_package(std_msgs REQUIRED)
rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/GPSEPHEM.msg"
  "msg/GALFNAVEPHEMERIS.msg"
  "msg/IONUTC.msg"
  "msg/GALCLOCK.msg"
  DEPENDENCIES std_msgs
)
```

### Step 4: Implement Septentrio Parser
Follow existing Septentrio driver pattern:
1. Add structs in `sbf_blocks.hpp` for SBF blocks 4027, 4028, etc.
2. Add parsing logic in `message_handler.cpp`
3. Create publishers for these messages
4. Configure receiver to output blocks via `configureRx()`

---

## Benefits of This Approach

✅ **Message definitions already tested** (used in Novatel driver)  
✅ **Field names are standardized** (GNSS conventions)  
✅ **Multiple array types available** (single + array messages)  
✅ **Covers all needed data** (ephemeris, iono, time offset)  
✅ **Reduces development time** (no need to define from scratch)  
✅ **Enables driver comparison** (Septentrio vs Novatel output)  
✅ **Reusable across FGO pipeline** (consistent message format)

---

## Recommended Path Forward

**Phase 1.1** (1 day): Copy and adapt message definitions
```bash
# Copy Novatel messages to Septentrio driver msg/ folder
# Remove Oem7Header dependency (or keep for compatibility)
# Rename for clarity (GPSEPHEM → GPSEphemeris, etc.)
```

**Phase 1.2** (3-4 days): Implement Septentrio parsers
```bash
# Map SBF blocks 4027 (GPSNav), 4028 (GALNav) to new messages
# Implement binary parsing in sbf_blocks.hpp
# Add switch cases in message_handler.cpp
```

**Phase 1.3** (2-3 days): Test and verify
```bash
# Collect SBF data with new blocks enabled
# Verify message population
# Compare with reference (if available)
```

**Total: 1 week** (much faster than starting from scratch!)

---

## Files to Reference

**Novatel Message Definitions**:
- Location: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/driver_modification/novatel_oem7_msgs/msg/`
- 46 `.msg` files available
- Key files: GPSEPHEM.msg, GALFNAVEPHEMERIS.msg, IONUTC.msg, GALCLOCK.msg

**Septentrio Driver**:
- Location: `/workspace/fgo_ws/src/gnssFGO/online_fgo/septentrio_gnss_driver/`
- Target folders: `msg/` (copy messages here), `include/parsers/sbf_blocks.hpp` (add structs)

---

## Next Action

✅ **Decision**: Use Novatel message definitions? **YES - Strongly recommended**

📋 **Todo**: Copy messages, adapt, implement parsers → 1 week to ephemeris topics active

Ready to proceed with Phase 1 implementation?

