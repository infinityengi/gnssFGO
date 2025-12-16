# Septentrio Mosaic-H Firmware Manual Analysis

**Date**: December 10, 2025  
**Firmware Version**: v4.14.4  
**Documents Reviewed**:
- mosaic-H Firmware v4.14.4 Reference Guide
- mosaic Hardware Manual v1.9.0

---

## Executive Summary

The Septentrio Mosaic-H receiver **DOES support ephemeris, ionosphere, and time offset blocks** and they are documented in detail in the firmware reference guide. All required blocks are available and can be configured for output.

**Key Findings**:
- ✅ GPS Ephemeris block available: **GPSNav (ID: 5891)**
- ✅ Galileo Ephemeris block available: **GALNav (ID: 4002)**
- ✅ GPS Ionosphere block available: **GPSIon (ID: 5893)**
- ✅ Galileo Ionosphere block available: **GALIon (ID: 4030)**
- ✅ Galileo-GPS time offset block available: **GALGstGps (ID: 4032)**
- ✅ Galileo UTC offset block available: **GALUtc (ID: 4031)**
- ✅ GPS UTC offset block available: **GPSUtc (ID: 5894)**

---

## SBF Block Specifications - Implementation Requirements

### 1. GPS Ephemeris Block (GPSNav)

**Block ID**: 5891  
**Output Rate**: "OnChange" (output each time new ephemeris received from GPS satellite)  
**Availability**: Flexible rate decimation supported  

**Structure** (142 bytes total):
```
Header (8 bytes):
  Sync1: u1 (0x24 = '$')
  Sync2: u1 (0x40 = '@')
  CRC: u2
  ID: u2 (5891)
  Length: u2
  
Timestamp (12 bytes):
  TOW: u4 (Time of Week, units: 0.001s, DoNotUse: 4294967295)
  WNc: u2 (Week Number, units: 1 week, DoNotUse: 65535)
  PRN: u1 (GPS Satellite ID, range: 1-32)
  Reserved: u1
  
Identification (4 bytes):
  WN: u2 (Week number, 10 bits from subframe 1)
  CAorPonL2: u1 (Code(s) on L2 channel)
  URA: u1 (User Range Accuracy index)
  
Health & Status (7 bytes):
  health: u1 (6-bit health status)
  L2DataFlag: u1 (1-bit L2 P-code data flag)
  IODC: u2 (10-bit Issue of Data Clock)
  IODE2: u1 (8-bit Issue of Data Ephemeris from subframe 2)
  IODE3: u1 (8-bit Issue of Data Ephemeris from subframe 3)
  FitIntFlg: u1 (Curve fit interval, 1 bit)
  Reserved2: u1
  
Clock Correction (12 bytes):
  T_gd: f4 (Group delay differential, units: 1s)
  t_oc: u4 (Clock reference time, units: 1s)
  a_f2: f4 (SV clock aging, units: 1s/s²)
  a_f1: f4 (SV clock drift, units: 1s/s)
  a_f0: f4 (SV clock bias, units: 1s)
  
Orbital Elements (56 bytes):
  C_rs: f4 (Sine correction to orbit radius, units: 1m)
  DEL_N: f4 (Mean motion difference, units: 1 semi-circle/s)
  M_0: f8 (Mean anomaly at reference time, units: 1 semi-circle)
  C_uc: f4 (Cosine correction to argument of latitude, units: 1 rad)
  e: f8 (Eccentricity, dimensionless)
  C_us: f4 (Sine correction to argument of latitude, units: 1 rad)
  SQRT_A: f8 (Square root of semi-major axis, units: 1 m^0.5)
  t_oe: u4 (Ephemeris reference time, units: 1s)
  C_ic: f4 (Cosine correction to inclination angle, units: 1 rad)
  OMEGA_0: f8 (Longitude of ascending node, units: 1 semi-circle)
  C_is: f4 (Sine correction to inclination angle, units: 1 rad)
  L_0: f8 (Inclination angle at reference time, units: 1 semi-circle)
  C_rc: f4 (Cosine correction to orbit radius, units: 1m)
  omega: f8 (Argument of perigee, units: 1 semi-circle)
  OMEGADOT: f4 (Rate of right ascension, units: 1 semi-circle/s)
  IDOT: f4 (Rate of inclination angle, units: 1 semi-circle/s)
  
Week Numbers (4 bytes):
  WNt_oc: u2 (WN associated with t_oc, modulo 1024)
  WNt_oe: u2 (WN associated with t_oe, modulo 1024)
  
Padding: variable
```

**Mapping to Novatel GPSEPHEM.msg**:
- All GPS ephemeris fields map directly
- Identical field names and units (mostly)
- Novatel message can be reused with minimal adaptation

---

### 2. Galileo Ephemeris Block (GALNav)

**Block ID**: 4002  
**Output Rate**: "OnChange" (output each time new navigation data batch decoded)  
**Sources**: I/NAV (source=2) or F/NAV (source=16)  

**Structure** (160+ bytes):
```
Header (8 bytes):
  Sync1: u1
  Sync2: u1
  CRC: u2
  ID: u2 (4002)
  Length: u2
  
Timestamp (12 bytes):
  TOW: u4 (Time of Week, units: 0.001s, DoNotUse: 4294967295)
  WNc: u2 (Week Number, units: 1 week, DoNotUse: 65535)
  SVID: u1 (Galileo Satellite ID, range: 1-36)
  Source: u1 (I/NAV=2, F/NAV=16)
  
Orbital Elements (56 bytes):
  SQRT_A: f8 (Square root of semi-major axis, units: 1 m^0.5)
  M_0: f8 (Mean anomaly at reference time, units: 1 semi-circle)
  e: f8 (Eccentricity, dimensionless)
  i_0: f8 (Inclination angle at reference time, units: 1 semi-circle)
  omega: f8 (Argument of perigee, units: 1 semi-circle)
  OMEGA_0: f8 (Longitude of ascending node, units: 1 semi-circle)
  OMEGADOT: f4 (Rate of right ascension, units: 1 semi-circle/s)
  IDOT: f4 (Rate of inclination angle, units: 1 semi-circle/s)
  DEL_N: f4 (Mean motion difference, units: 1 semi-circle/s)
  C_uc: f4 (Cosine correction to argument of latitude, units: 1 rad)
  C_us: f4 (Sine correction to argument of latitude, units: 1 rad)
  C_rc: f4 (Cosine correction to orbit radius, units: 1m)
  C_ic: f4 (Sine correction to orbit radius, units: 1m)
  C_is: f4 (Sine correction to inclination angle, units: 1 rad)
  
Clock Correction (24 bytes):
  t_oe: u4 (Ephemeris reference time, units: 1s)
  t_oc: u4 (Clock reference time, units: 1s)
  a_f2: f4 (SV clock aging, units: 1s/s²)
  a_f1: f4 (SV clock drift, units: 1s/s)
  a_f0: f8 (SV clock bias, units: 1s)
  WNt_oe: u2 (WN with t_oe, modulo 4096)
  WNt_oc: u2 (WN with t_oc, modulo 4096)
  IODnav: u2 (Issue of data navigation, 10 bits)
  
Health & Accuracy (10 bytes):
  Health_OSSOL: u2 (Health status and data validity for E5a/E5b/L1-B)
  Health_PRS: u1 (Reserved)
  SISA_LIE5a: u1 (Signal-In-Space Accuracy index for L1/E5a, DoNotUse: 255)
  SISA_LIE5b: u1 (Signal-In-Space Accuracy index for L1/E5b, DoNotUse: 255)
  SISA_LIAE6A: u1 (Reserved, DoNotUse: 255)
  BGD_LIE5a: f4 (Broadcast Group Delay L1/E5a, units: 1s, DoNotUse: -2e10)
  BGD_LIE5b: f4 (Broadcast Group Delay L1/E5b, units: 1s, DoNotUse: -2e10)
  BGD_LIAE6A: f4 (Reserved, DoNotUse: -2e10)
  
Encryption (1 byte):
  CNAVenc: u1 (C/NAV encryption status for E6B/E6C, DoNotUse: 255)
  
Padding: variable
```

**Mapping to Novatel GALFNAVEPHEMERIS.msg**:
- All Galileo F/NAV ephemeris fields map directly
- Health/SISA/BGD fields match Novatel definitions
- Novatel message structure proven compatible

**NOTE**: GALNav outputs both I/NAV and F/NAV when both available (two blocks per satellite)

---

### 3. GPS Ionosphere Block (GPSIon)

**Block ID**: 5893  
**Output Rate**: "OnChange" (each time subframe 4, page 18 received)  

**Structure** (48 bytes):
```
Header (8 bytes):
  Sync1: u1
  Sync2: u1
  CRC: u2
  ID: u2 (5893)
  Length: u2
  
Timestamp (12 bytes):
  TOW: u4 (units: 0.001s, DoNotUse: 4294967295)
  WNc: u2 (units: 1 week, DoNotUse: 65535)
  PRN: u1 (GPS satellite ID from which coefficients received)
  Reserved: u1
  
Ionosphere Klobuchar Coefficients (32 bytes):
  alpha_0: f4 (vertical delay coefficient 0, units: 1s)
  alpha_1: f4 (vertical delay coefficient 1, units: 1s/semi-circle)
  alpha_2: f4 (vertical delay coefficient 2, units: 1s/semi-circle²)
  alpha_3: f4 (vertical delay coefficient 3, units: 1s/semi-circle³)
  beta_0: f4 (model period coefficient 0, units: 1s)
  beta_1: f4 (model period coefficient 1, units: 1s/semi-circle)
  beta_2: f4 (model period coefficient 2, units: 1s/semi-circle²)
  beta_3: f4 (model period coefficient 3, units: 1s/semi-circle³)
  
Padding: variable
```

**Mapping to Novatel IONUTC.msg**:
- All 8 Klobuchar coefficients match exactly
- Novatel message includes UTC fields too (GPSUtc separate in Septentrio)
- Full reuse possible with field mapping

---

### 4. Galileo Ionosphere Block (GALIon)

**Block ID**: 4030  
**Output Rate**: "OnChange" (each time ionospheric parameters received)  

**Structure** (36 bytes):
```
Header (8 bytes):
  Sync1: u1
  Sync2: u1
  CRC: u2
  ID: u2 (4030)
  Length: u2
  
Timestamp (12 bytes):
  TOW: u4 (units: 0.001s, DoNotUse: 4294967295)
  WNc: u2 (units: 1 week, DoNotUse: 65535)
  SVID: u1 (Galileo satellite ID)
  Source: u1 (I/NAV=2, F/NAV=16)
  
Ionosphere Model (12 bytes):
  a_i0: f4 (Effective ionization level, units: 1e-22 W/(m²Hz))
  a_i1: f4 (Effective ionization level, units: 1e-22 W/(m²Hz)/deg)
  a_i2: f4 (Effective ionization level, units: 1e-22 W/(m²Hz)/deg²)
  
Storm Flags (1 byte):
  StormFlags: u1 (Ionospheric storm flags SF1-SF5, bits 0-4)
  
Padding: variable
```

**Note**: Different from GPS Klobuchar coefficients
- Galileo uses effective ionization level coefficients
- Storm flags unique to Galileo
- No direct Novatel equivalent (different models)

---

### 5. Galileo-GPS Time Offset Block (GALGstGps)

**Block ID**: 4032  
**Output Rate**: "OnChange" (when valid GST-GPS offset parameters received)  

**Structure** (32 bytes):
```
Header (8 bytes):
  Sync1: u1
  Sync2: u1
  CRC: u2
  ID: u2 (4032)
  Length: u2
  
Timestamp (12 bytes):
  TOW: u4 (units: 0.001s, DoNotUse: 4294967295)
  WNc: u2 (units: 1 week, DoNotUse: 65535)
  SVID: u1 (Galileo satellite ID)
  Source: u1 (I/NAV=2, F/NAV=16)
  
Time Offset Parameters (8 bytes):
  A_0G: f4 (Constant term of offset, units: 1e9 ns)
  A_1G: f4 (Rate of change of offset, units: 1e9 ns/s)
  t_oG: u4 (Reference time of week, units: 1s)
  WN_oG: u1 (6-bit reference week number)
  
Padding: variable
```

**Mapping to Novatel GALCLOCK.msg**:
- GPS-Galileo time offset fields match (GGTO)
- Novatel has same parameters (a0, a1, t0g, wn0g)
- Direct reuse possible

---

### 6. GPS UTC Block (GPSUtc)

**Block ID**: 5894  
**Output Rate**: "OnChange"  

**Structure** (36 bytes):
```
Header + Timestamp (20 bytes)

UTC Parameters (16 bytes):
  A_1: f4 (first order polynomial term, units: 1s/s)
  A_0: f8 (constant polynomial term, units: 1s)
  T_ot: u4 (reference time for UTC data, units: 1s)
  WN_ot: u2 (UTC reference week number)
  Delta_t_LS: i1 (delta time due to leap seconds, units: 1s)
  WN_LSF: u2 (effectivity time of leap second, week)
  DN: u1 (effectivity time of leap second, day 1-7)
  Delta_t_LSF: i1 (delta time if effectivity in past, units: 1s)
```

**Mapping to Novatel IONUTC.msg**:
- UTC parameters map to Novatel IONUTC message
- Can combine GPS and GAL UTC/iono into single message or separate

---

### 7. Galileo UTC Block (GALUtc)

**Block ID**: 4031  
**Output Rate**: "OnChange"  

**Structure** (36 bytes):
```
Similar to GPSUtc but with Galileo-specific fields
```

---

## Configuration Requirements

### Enabling Block Output

The firmware supports configurable SBF block output. To enable blocks:

```
Command: setSBFOutput, <Stream>, <Connection>, <Messages>, <Interval>

Example to enable ephemeris blocks:
setSBFOutput, Stream1, Ethernet, +GPSNav+GALNav, OnChange
setSBFOutput, Stream2, Ethernet, +GPSIon+GALIon+GALGstGps, OnChange
setSBFOutput, Stream3, Ethernet, +GPSUtc+GALUtc, OnChange
```

**Key Points**:
- Blocks with "OnChange" rate cannot be decimated (always output at native rate)
- Multiple streams can output to same connection
- Default: all streams are empty (no blocks output)
- Must save configuration to non-volatile memory after setting

### Receiver Capability Check

The firmware documentation confirms (section 4.2.6):
- GPS decoded message blocks: GPSNav, GPSAlm, GPSIon, GPSUtc
- Galileo decoded message blocks: GALNav, GALAlm, GALIon, GALUtc, GALGstGps
- All blocks support "PostProcess" output mode (used for logs and playback)
- All blocks available in "Support" permission set

---

## Implementation Checklist

### Phase 1: Message Definition
- [ ] Copy Novatel GPSEPHEM.msg → Septentrio driver msg/
- [ ] Copy Novatel GALFNAVEPHEMERIS.msg → Septentrio driver msg/
- [ ] Copy Novatel IONUTC.msg → Septentrio driver msg/
- [ ] Copy Novatel GALCLOCK.msg → Septentrio driver msg/
- [ ] Create new GALIon.msg (Galileo ionosphere)
- [ ] Update CMakeLists.txt to include all 5 messages

### Phase 2: SBF Block Parsing

**GPSNav (5891)** → GPSEPHEM.msg
- [ ] Add struct definition to sbf_blocks.hpp
- [ ] Implement parseGPSNav() function
- [ ] Map 140 bytes binary → ROS message fields
- [ ] Handle endianness (little-endian SBF format)
- [ ] Add switch case in message_handler.cpp (block ID 5891)
- [ ] Create publisher for `/gps_ephemeris` topic

**GALNav (4002)** → GALFNAVEPHEMERIS.msg
- [ ] Add struct definition with I/NAV and F/NAV variants
- [ ] Implement parseGALNav() function
- [ ] Map 160 bytes binary → ROS message fields
- [ ] Handle Source field (2=I/NAV, 16=F/NAV)
- [ ] Add switch case in message_handler.cpp (block ID 4002)
- [ ] Create publisher for `/gal_ephemeris` topic

**GPSIon (5893)** → IONUTC.msg
- [ ] Add struct definition to sbf_blocks.hpp
- [ ] Implement parseGPSIon() function
- [ ] Map 48 bytes binary → Klobuchar coefficients
- [ ] Add switch case in message_handler.cpp (block ID 5893)
- [ ] Create publisher for `/gps_iono` topic

**GALIon (4030)** → new GALIon.msg
- [ ] Define new message with a_i0, a_i1, a_i2, StormFlags
- [ ] Add struct definition to sbf_blocks.hpp
- [ ] Implement parseGALIon() function
- [ ] Add switch case in message_handler.cpp (block ID 4030)
- [ ] Create publisher for `/gal_iono` topic

**GALGstGps (4032)** → GALCLOCK.msg
- [ ] Add struct definition to sbf_blocks.hpp
- [ ] Implement parseGALGstGps() function
- [ ] Map 32 bytes binary → time offset parameters
- [ ] Add switch case in message_handler.cpp (block ID 4032)
- [ ] Create publisher for `/gal_ggto` topic

### Phase 3: Receiver Configuration

- [ ] In configureRx() function, add setSBFOutput commands:
  ```
  setSBFOutput Stream1 Ethernet +GPSNav+GALNav OnChange
  setSBFOutput Stream2 Ethernet +GPSIon+GALIon+GALGstGps OnChange
  setSBFOutput Stream3 Ethernet +GPSUtc+GALUtc OnChange
  ```
- [ ] Add configuration flags to rover.yaml:
  ```yaml
  publish:
    gps_ephemeris: true
    gal_ephemeris: true
    gps_iono: true
    gal_iono: true
    gal_ggto: true
  ```
- [ ] Save configuration to non-volatile memory

### Phase 4: Testing

- [ ] Build driver: `colcon build`
- [ ] Source workspace: `source install/setup.bash`
- [ ] Launch with receiver: `ros2 launch septentrio_gnss_driver rover.launch.py`
- [ ] Verify topics exist:
  ```bash
  ros2 topic list | grep ephemeris
  ros2 topic list | grep iono
  ```
- [ ] Monitor data:
  ```bash
  ros2 topic echo /gps_ephemeris (first 5 messages)
  ros2 topic echo /gal_ephemeris
  ros2 topic echo /gps_iono
  ```
- [ ] Verify data is populating (non-zero fields)
- [ ] Check timestamp consistency with observations
- [ ] Run for 1+ hour and verify continuous data stream

---

## Critical Technical Notes

### Byte Ordering
- SBF format uses **little-endian** byte ordering
- All multi-byte integers and floats are little-endian
- Ensure platform compatibility (usually x86_64 is little-endian)

### Time Stamps
- TOW (Time of Week): 0.001 second units, range 0-604799999 (0-604799.999s)
- WNc (Week Number): 1 week units
- All blocks in single stream have correlated timestamps

### Padding
- SBF blocks have padding bytes to align to 4-byte boundaries
- Padding must be accounted for in binary parsing
- Parser ignores padding (handled by struct definition)

### Block Update Rates
- "OnChange" blocks: output at satellite signal reception rate
- GPS ephemeris: typically every 2 hours per satellite
- Galileo ephemeris: typically every 10 seconds per satellite
- Ionosphere: every 3-4 hours (GPS), per-satellite (Galileo)
- No need to decimate "OnChange" blocks

### CRC Verification
- SBF blocks include 2-byte CRC
- Driver should verify CRC for data integrity
- CRC polynomial documented in SBF specification (see firmware manual section 4.1.1)

---

## Reference Information

### SBF Block Header Format
```
Byte 0: Sync1 = 0x24 ('$')
Byte 1: Sync2 = 0x40 ('@')
Bytes 2-3: CRC (u2)
Bytes 4-5: Block ID (u2)
Bytes 6-7: Block Length (u2) in bytes
```

### Data Types in SBF
- u1, u2, u4: unsigned int (1, 2, 4 bytes)
- i1, i2, i4: signed int
- f4: 4-byte IEEE 754 float
- f8: 8-byte IEEE 754 double
- c1: character

### Firmware Manual Sections (v4.14.4)
- **Section 4.1**: SBF Outline (format, header, timestamp)
- **Section 4.2.3**: GPS Decoded Message Blocks (GPSNav, GPSAlm, GPSIon, GPSUtc)
- **Section 4.2.5**: Galileo Decoded Message Blocks (GALNav, GALAlm, GALIon, GALUtc, GALGstGps)
- **Section 3.2.16**: SBF Configuration (setSBFOutput command)
- **Appendix B**: List of SBF Blocks with update rates and flex rate support

---

## Summary: What You Need to Implement

**5 ROS Message Types**:
1. GPSEPHEM.msg (GPS ephemeris) - **reuse from Novatel** ✅
2. GALFNAVEPHEMERIS.msg (Galileo ephemeris) - **reuse from Novatel** ✅
3. IONUTC.msg (GPS ionosphere + UTC) - **reuse from Novatel** ✅
4. GALCLOCK.msg (Galileo-GPS time offset) - **reuse from Novatel** ✅
5. GALIon.msg (Galileo ionosphere) - **create new** ⚠️

**5 SBF Block Parsers**:
1. GPSNav (5891) → 140 bytes → GPSEPHEM
2. GALNav (4002) → 160 bytes → GALFNAVEPHEMERIS
3. GPSIon (5893) → 48 bytes → IONUTC
4. GALIon (4030) → 36 bytes → GALIon.msg
5. GALGstGps (4032) → 32 bytes → GALCLOCK

**Configuration**: 3 setSBFOutput commands in configureRx()

**Estimated Effort**: 5-7 days for experienced C++ developer with SBF binary parsing knowledge

---

**Status**: All technical requirements understood. Implementation can begin immediately.

