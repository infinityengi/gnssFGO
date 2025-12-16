# Septentrio Integration Next Steps - Detailed Procedure (v2)

**Date**: December 9, 2025  
**Package**: irt_gnss_preprocessing  
**Goal**: Achieve full Septentrio preprocessing parity with NovAtel OEM7  
**Status**: P1 complete (execution code ready), P2-P6 pending  
**Reference**: Based on comprehensive driver analysis (gnss_drivers_comparison.md)

---

## Executive Summary

### Root Cause Analysis

**NovAtel Driver Architecture**: The `novatel_oem7_driver` directly publishes GNSS navigation data (ephemeris, ionosphere, clock corrections) as dedicated ROS2 topics because:
1. NovAtel OEM7 receivers output these as **separate binary logs** (GPSEPHEM, GALINAVEPHEMERIS, IONUTC, etc.)
2. The driver has **message handlers** for each log type that parse and publish them
3. These logs are continuously streamed at ~1 Hz alongside measurements

**Septentrio Driver Architecture**: The `septentrio_gnss_driver` (ROSaic) does **NOT** publish navigation data as ROS2 topics because:
1. Septentrio receivers use **SBF (Septentrio Binary Format)** blocks
2. Navigation data (ephemeris, iono, clock) exists in SBF blocks: GPSNav (4027), GALNav (4046), GPSIon (4029), etc.
3. However, the **driver does not parse or publish these SBF blocks** - it only handles:
   - PVTGeodetic, PVTCartesian (position/velocity)
   - MeasEpoch (raw measurements)
   - AttEuler (attitude for dual-antenna)
   - INSNavGeod (INS solution)
   - ChannelStatus, DOP, covariances
4. The missing navigation blocks are **available in receiver** but **not exposed by driver**

**Impact on Preprocessing**:
- NovAtel preprocessor receives continuous ephemeris updates → can compute satellite positions/clocks
- Septentrio preprocessor has NO ephemeris data → cannot execute preprocessing algorithms
- This is an **architectural difference in driver implementation**, not receiver capability

### Solution Paths

**Option 1: External Ephemeris Provider** (RECOMMENDED)
- Create standalone ROS2 node that provides GNSS broadcast ephemeris
- Downloads IGS BRDC files (updated every 2 hours)
- Publishes ephemeris/iono/GGTO as ROS2 messages
- **Pros**: Receiver-agnostic, no driver changes, well-tested RINEX parsers available
- **Cons**: 2-hour update latency (acceptable for most applications), additional node
- **Effort**: 1.5-2 weeks
- **Risk**: Low

**Option 2: Septentrio Driver Extension**
- Modify `septentrio_gnss_driver` to parse and publish GPSNav/GALNav/GPSIon SBF blocks
- Add message handlers similar to NovAtel driver architecture
- **Pros**: Real-time ephemeris from receiver, native integration
- **Cons**: Requires driver fork/PR, SBF parsing expertise, maintenance burden
- **Effort**: 2-3 weeks (investigation + implementation + testing)
- **Risk**: Medium-High (requires coordination with Septentrio driver maintainers)

**Option 3: Use Receiver's Built-in Solution**
- Rely solely on PVTGeodetic (receiver-computed position)
- Skip preprocessing algorithms entirely for Septentrio
- **Pros**: Zero development, immediate availability
- **Cons**: Loses preprocessing benefits (integrity monitoring, DD RTK, custom filters)
- **Effort**: Configuration only
- **Risk**: Low, but limited functionality

**Recommended Approach**: **Option 1** - Fastest path to full feature parity

---

## Architectural Comparison: NovAtel vs Septentrio Drivers

### NovAtel OEM7 Driver Data Flow

```
OEM7 Receiver                  novatel_oem7_driver               Preprocessor
─────────────                  ───────────────────               ────────────
BESTPOS (10 Hz)     ────────>  Parser                ────────>   (not used)
                               └─> /novatel/oem7/bestpos
                               
RANGE (10 Hz)       ────────>  Parser                ────────>   Raw measurements
                               └─> /novatel/oem7/range            └─> onOEM7RangeMsgCb()
                               
GPSEPHEM (as needed)────────>  Parser                ────────>   GPS ephemeris
                               └─> /novatel/oem7/gpsephem         └─> gps_nav_ephemeris_buffer_
                               
GALINAVEPHEMERIS    ────────>  Parser                ────────>   GAL ephemeris
                               └─> /novatel/oem7/galinav          └─> gal_nav_ephemeris_buffer_
                               
IONUTC              ────────>  Parser                ────────>   GPS ionosphere
                               └─> /novatel/oem7/ionutc           └─> gps_ion_buffer_
                               
GALIONO             ────────>  Parser                ────────>   GAL ionosphere
                               └─> /novatel/oem7/galiono          └─> gal_ion_buffer_
                               
GALCLOCK            ────────>  Parser                ────────>   GGTO
                               └─> /novatel/oem7/galclock         └─> gal_gst_gps_buffer_

Result: Preprocessor has ALL inputs → executes step() → publishes processed observations
```

### Septentrio Driver Data Flow (Current State)

```
Septentrio Receiver            septentrio_gnss_driver           Preprocessor
───────────────────            ──────────────────────           ────────────
PVTGeodetic (10 Hz) ────────>  Parser                ────────>   PVT solution
                               └─> /pvtgeodetic                   └─> (published as-is)
                               
MeasEpoch (10 Hz)   ────────>  Parser                ────────>   Raw measurements
                               └─> /measepoch                     └─> onMeasEpochMainCb()
                               
AttEuler (dual-ant) ────────>  Parser                ────────>   Attitude
                               └─> /atteuler                      └─> attitude_buffer_

GPSNav (SBF 4027)   ────────>  ❌ NOT PARSED        ────────>   ❌ MISSING
GALNav (SBF 4046)   ────────>  ❌ NOT PARSED        ────────>   ❌ MISSING  
GPSIon (SBF 4029)   ────────>  ❌ NOT PARSED        ────────>   ❌ MISSING
GALIon (SBF 4058)   ────────>  ❌ NOT PARSED        ────────>   ❌ MISSING
GALGSTGPS (SBF 4046)────────>  ❌ NOT PARSED        ────────>   ❌ MISSING

Result: Preprocessor lacks nav data → guards trigger → step() NOT executed → no processing
```

### Key Differences

| Aspect | NovAtel Driver | Septentrio Driver |
|--------|----------------|-------------------|
| **Raw Measurements** | ✅ RANGE log → ROS topic | ✅ MeasEpoch → ROS topic |
| **Position Solution** | ✅ BESTPOS log → ROS topic | ✅ PVTGeodetic → ROS topic |
| **GPS Ephemeris** | ✅ GPSEPHEM log → ROS topic | ❌ GPSNav SBF exists but not published |
| **GAL Ephemeris** | ✅ GALINAVEPHEMERIS log → ROS topic | ❌ GALNav SBF exists but not published |
| **GPS Ionosphere** | ✅ IONUTC log → ROS topic | ❌ GPSIon SBF exists but not published |
| **GAL Ionosphere** | ✅ GALIONO log → ROS topic | ❌ GALIon SBF exists but not published |
| **GGTO** | ✅ GALCLOCK log → ROS topic | ❌ GALGSTGPS SBF exists but not published |
| **Attitude** | ✅ HEADING2 log → ROS topic | ✅ AttEuler → ROS topic |
| **Message Rate** | 10 Hz (typical) | 10-100 Hz (configurable) |
| **Driver Design** | Each log type = dedicated handler | Only selected SBF blocks handled |

### Why This Matters for Preprocessing

The GNSS preprocessing algorithms require:
1. **Raw measurements** (pseudorange, carrier phase, Doppler) - ✅ Both drivers provide
2. **Satellite ephemeris** (orbital parameters) - ✅ NovAtel, ❌ Septentrio driver
3. **Ionosphere models** (Klobuchar/NeQuick) - ✅ NovAtel, ❌ Septentrio driver
4. **Time offsets** (GGTO for GPS-GAL) - ✅ NovAtel, ❌ Septentrio driver

Without 2-4, preprocessing cannot:
- Compute satellite positions at observation time
- Apply ionospheric corrections
- Synchronize multi-constellation observations
- Perform integrity monitoring
- Execute double-difference RTK

**This is why Septentrio preprocessing currently stops at guards and never calls step().**

---

## SBF Block Investigation Results

### Available SBF Navigation Blocks (from Septentrio Reference Manual)

The Septentrio receivers **DO output** navigation data in these SBF blocks:

#### GPS Navigation Data
- **Block 4027 (GPSNav)**: GPS ephemeris and clock parameters
  - All Keplerian orbital elements
  - Clock correction coefficients (af0, af1, af2, Tgd)
  - IODC, IODE, health, accuracy
  - ~Every 2 hours per satellite (when ephemeris updates)
  
- **Block 4029 (GPSIon)**: GPS ionospheric correction parameters
  - Klobuchar model coefficients (α0-α3, β0-β3)
  - Updated when navigation message changes
  
- **Block 4030 (GPSUtc)**: GPS-UTC time offset
  - A0, A1, Tot, WNt, ∆tLS (leap seconds)
  
#### Galileo Navigation Data  
- **Block 4046 (GALNav)**: Galileo ephemeris (I/NAV)
  - Keplerian orbital elements (Galileo-specific)
  - Clock correction (af0, af1, af2, BGD_E1E5a, BGD_E1E5b)
  - IODnav, health, signal-in-space accuracy
  
- **Block 4058 (GALIon)**: Galileo ionospheric correction
  - NeQuick model coefficients (ai0, ai1, ai2)
  - Disturbance flags
  
- **Block 4046 (GALGstGps)**: Galileo-GPS time offset (GGTO)
  - A0G, A1G, t0G, WN0G
  - Used to synchronize GPS and Galileo time

#### Other Constellations
- **Block 4004 (GLONav)**: GLONASS navigation data
- **Block 4081 (BDSNav)**: BeiDou navigation data
- **Block 4093 (QZSNav)**: QZSS navigation data

### Current Driver Implementation Status

**File**: `septentrio_gnss_driver/src/septentrio_gnss_driver/parsers/sbf_blocks.hpp`

The driver defines SBF block structures for:
- ✅ MeasEpoch (4027)
- ✅ PVTGeodetic (4007)
- ✅ PVTCartesian (4006)
- ✅ PosCovGeodetic (5906)
- ✅ AttEuler (5938)
- ✅ ChannelStatus (4013)
- ✅ DOP (4001)
- ❌ **GPSNav NOT defined**
- ❌ **GALNav NOT defined**
- ❌ **GPSIon NOT defined**
- ❌ **GALIon NOT defined**
- ❌ **GALGstGps NOT defined**

**Conclusion**: The Septentrio receivers produce navigation SBF blocks, but the driver **does not parse or publish them**. This is a **driver limitation, not a receiver limitation**.

### Why NovAtel Driver Has Navigation Data

The NovAtel OEM7 driver architecture:

**File**: `novatel_oem7_driver/src/novatel_oem7_msgs/`

Defines and publishes:
- ✅ `GPSEPHEM.msg` (message ID 7)
- ✅ `GALINAVEPHEMERIS.msg` (message ID 1122)
- ✅ `IONUTC.msg` (message ID 8)
- ✅ `GALIONO.msg` (message ID 1266)
- ✅ `GALCLOCK.msg` (message ID 1347)

**File**: `novatel_oem7_driver/src/novatel_oem7_driver/src/message_handler.cpp`

Has dedicated handlers:
```cpp
registerHandler<GPSEPHEM>("GPSEPHEM", GPS_EPHEMERIS_OEM7_MSGID);
registerHandler<GALINAVEPHEMERIS>("GALINAVEPHEMERIS", GALINAV_EPHEMERIS_OEM7_MSGID);
registerHandler<IONUTC>("IONUTC", IONUTC_OEM7_MSGID);
// ... etc
```

Each handler:
1. Receives binary log from receiver
2. Parses fields
3. Publishes as ROS2 message

**The Septentrio driver lacks equivalent handlers for navigation blocks.**

---

## Table of Contents

1. [Phase 0: Decision & Setup](#phase-0)
2. [Phase 1: Ephemeris Provider Implementation (Option 1)](#phase-1)
3. [Phase 1-Alt: Driver Extension (Option 2)](#phase-1-alt)
4. [Phase 2: Wire Navigation Inputs](#phase-2)
5. [Phase 3: RTCM Integration](#phase-3)
6. [Phase 4: Dual-Antenna Wiring](#phase-4)
7. [Phase 5: Quality & Integrity](#phase-5)
8. [Phase 6: Output Publishing](#phase-6)
9. [Phase 7: Testing & Validation](#phase-7)
10. [Phase 8: Documentation & Deployment](#phase-8)

---

<a name="phase-0"></a>
## Phase 0: Decision & Setup (Day 1, ~4 hours)

### Objective
Choose ephemeris source strategy and prepare development environment.

### Tasks

#### Task 0.1: Evaluate Options

Based on comprehensive driver analysis, here's the detailed comparison:

**Option 1: External Ephemeris Provider Node** ⭐ RECOMMENDED
- **Pros**:
  - ✅ Receiver-agnostic (works with any GNSS receiver)
  - ✅ No driver modification required
  - ✅ Well-documented BRDC format (RINEX navigation)
  - ✅ Mature libraries available (RTKLIB, GPSTk)
  - ✅ Can use IGS broadcast ephemeris (free, global coverage)
  - ✅ Can upgrade to IGS precise ephemeris for post-processing
  - ✅ Independent update schedule (every 2 hours)
  - ✅ Same solution works for Septentrio, ublox, or other receivers
- **Cons**:
  - ⚠️ Additional node complexity (~1 extra process)
  - ⚠️ Ephemeris update latency (2 hours typical, acceptable for most applications)
  - ⚠️ Requires internet connection for IGS downloads (can cache locally)
  - ⚠️ File parsing overhead (~10 MB RINEX file every 2 hours)
- **Effort**: 1.5-2 weeks (16-24 development hours)
- **Risk**: ⭐ Low - proven approach, well-understood formats
- **Maintenance**: Low - stable RINEX format, no driver coupling

**Option 2: Extend Septentrio Driver**
- **Pros**:
  - ✅ Native integration - ephemeris directly from receiver
  - ✅ Real-time updates (ephemeris published as received)
  - ✅ No external dependencies or downloads
  - ✅ Single-node solution
  - ✅ Matches NovAtel driver architecture
- **Cons**:
  - ❌ Requires forking `septentrio_gnss_driver` repository
  - ❌ Need to implement SBF block parsers for GPSNav/GALNav/GPSIon/GALIon
  - ❌ Must define new ROS2 message types (or adapt existing)
  - ❌ Requires understanding SBF format specification (proprietary)
  - ❌ Need to coordinate with Septentrio driver maintainers for PR merge
  - ❌ Maintenance burden - must track upstream driver changes
  - ❌ Only benefits Septentrio users
- **Effort**: 2-3 weeks (24-40 hours: investigation, implementation, testing, PR process)
- **Risk**: ⚠️ Medium-High 
  - SBF parsing errors could corrupt data
  - PR may be rejected or require significant revisions
  - Receiver firmware differences may affect block availability
- **Maintenance**: High - must maintain fork or await upstream merge

**Option 3: Use Receiver PVT Only (No Preprocessing)**
- **Pros**:
  - ✅ Zero development time
  - ✅ PVTGeodetic already published
  - ✅ Receiver has high-quality internal algorithms
- **Cons**:
  - ❌ Loses all preprocessing benefits:
    - No integrity monitoring
    - No custom filtering (LOS/NLOS)
    - No double-difference RTK (if using RTCM)
    - No dual-antenna DD processing
    - No residual analysis
  - ❌ Cannot tune algorithm parameters
  - ❌ Limited observability (no intermediate outputs)
  - ❌ Inconsistent with NovAtel preprocessing workflow
- **Effort**: None (configuration only)
- **Risk**: None, but functionality limited
- **Use Case**: Prototyping, simple applications, or when preprocessing not required

### Decision Matrix

| Criterion | Option 1 (Ext Provider) | Option 2 (Driver Ext) | Option 3 (PVT Only) |
|-----------|------------------------|----------------------|-------------------|
| Development Time | ⚡ 1.5-2 weeks | 🐌 2-3 weeks | ⚡ Immediate |
| Technical Risk | 🟢 Low | 🟡 Medium-High | 🟢 None |
| Maintenance | 🟢 Low | 🔴 High | 🟢 None |
| Flexibility | 🟢 Receiver-agnostic | 🔴 Septentrio only | 🔴 Limited |
| Feature Completeness | ✅ Full | ✅ Full | ❌ Basic |
| Real-time Performance | 🟡 2hr latency | ✅ Immediate | ✅ Immediate |
| External Dependencies | 🟡 IGS, RTKLIB | 🟢 None | 🟢 None |
| Community Benefit | ✅ All GNSS users | 🟡 Septentrio only | N/A |

**Recommendation Decision Tree**:
```
Need preprocessing features (integrity, DD RTK, filtering)?
├─ NO  → Option 3 (PVT only)
└─ YES → Continue
         │
         Support multiple receiver brands?
         ├─ YES → Option 1 (External provider)
         └─ NO  → Continue
                  │
                  Have 2-3 weeks + SBF expertise?
                  ├─ YES → Option 2 (Driver extension)
                  └─ NO  → Option 1 (External provider)
```

**Final Recommendation**: **Option 1 - External Ephemeris Provider**
- Fastest path to working system
- Proven technology (RTKLIB used worldwide)
- Benefits entire ROS GNSS ecosystem
- Low maintenance burden

#### Task 0.2: Repository Setup

```bash
cd /workspace/fgo_ws/src/gnssFGO

# Create package for ephemeris provider (if Option 1)
ros2 pkg create --build-type ament_cmake \
  --dependencies rclcpp std_msgs irt_nav_msgs \
  gnss_ephemeris_provider

# Or clone driver fork (if Option 2)
# git clone <septentrio_driver_fork> septentrio_gnss_driver_ext
```

#### Task 0.3: Install Dependencies

```bash
# For Option 1: BRDC parsing
sudo apt-get install -y \
  libcurl4-openssl-dev \
  libboost-all-dev

# Clone RTKLIB (best for BRDC/RINEX parsing)
cd /workspace
git clone https://github.com/tomojitakasu/RTKLIB.git
cd RTKLIB
# Build library components needed

# Alternative: GPSTk
# cd /workspace
# git clone https://github.com/SGL-UT/GPSTk.git
```

**Deliverables**:
- ✅ Decision documented: Option 1 or 2
- ✅ Package structure created
- ✅ Dependencies installed
- ✅ Development branch created

---

<a name="phase-1"></a>
## Phase 1: Ephemeris Provider Implementation (Days 2-4, ~16-24 hours)

### Objective
Create node that provides GPS/GAL ephemeris, ionosphere, and GGTO data.

---

### Path A: External Provider (Option 1)

#### Task 1.1: Define ROS2 Message Types

**File**: `gnss_ephemeris_provider/msg/GPSEphemeris.msg`
```python
# GPS Ephemeris Message
std_msgs/Header header

uint8 svid              # Satellite ID (1-32)
uint16 week             # GPS week number
float64 tow             # Time of week (s)

# Clock parameters
float64 af0             # Clock bias (s)
float64 af1             # Clock drift (s/s)
float64 af2             # Clock drift rate (s/s^2)
float64 tgd             # Group delay (s)

# Orbit parameters
float64 sqrt_a          # Square root of semi-major axis (m^0.5)
float64 ecc             # Eccentricity
float64 i0              # Inclination at reference time (rad)
float64 omega0          # Longitude of ascending node (rad)
float64 omega           # Argument of perigee (rad)
float64 m0              # Mean anomaly at reference time (rad)
float64 delta_n         # Mean motion difference (rad/s)
float64 idot            # Rate of inclination angle (rad/s)
float64 omega_dot       # Rate of right ascension (rad/s)

# Correction terms
float64 cuc             # Cos harmonic correction (rad)
float64 cus             # Sin harmonic correction (rad)
float64 crc             # Cos harmonic correction (m)
float64 crs             # Sin harmonic correction (m)
float64 cic             # Cos harmonic correction (rad)
float64 cis             # Sin harmonic correction (rad)

# Reference times
uint32 toe              # Time of ephemeris (s)
uint32 toc              # Time of clock (s)

# Health/accuracy
uint8 health            # Satellite health
uint16 iodc             # Issue of data clock
uint8 iode              # Issue of data ephemeris
```

**File**: `gnss_ephemeris_provider/msg/GALEphemeris.msg`
```python
# Galileo Ephemeris Message
std_msgs/Header header

uint8 svid              # Satellite ID (1-36)
# ... (similar structure to GPS, with GAL-specific fields)
uint8 data_source       # 1=I/NAV, 2=F/NAV
uint8 e5a_health
uint8 e5b_health
float64 bgd_e1e5a       # Group delay E1-E5a
float64 bgd_e1e5b       # Group delay E1-E5b
```

**File**: `gnss_ephemeris_provider/msg/Ionosphere.msg`
```python
# Ionosphere Correction Parameters
std_msgs/Header header

uint8 system            # 1=GPS, 2=GAL, 3=BDS, etc.

# Klobuchar model (GPS)
float64 alpha0
float64 alpha1
float64 alpha2
float64 alpha3
float64 beta0
float64 beta1
float64 beta2
float64 beta3

# NeQuick model (Galileo)
float64 ai0
float64 ai1
float64 ai2
uint8 disturbance_flags
```

**File**: `gnss_ephemeris_provider/msg/GGTO.msg`
```python
# Galileo-GPS Time Offset
std_msgs/Header header

float64 a0gp            # Constant term (s)
float64 a1gp            # Rate term (s/s)
uint32 t0gp             # Reference time (s)
uint16 wn0gp            # Reference week
```

#### Task 1.2: BRDC File Handler

**File**: `gnss_ephemeris_provider/src/brdc_parser.cpp`
```cpp
class BRDCParser {
public:
    BRDCParser(const std::string& cache_dir = "/tmp/gnss_brdc");
    
    // Download latest BRDC file from IGS
    bool downloadLatestBRDC();
    
    // Parse BRDC file (RINEX navigation format)
    bool parseBRDCFile(const std::string& filepath);
    
    // Get ephemeris for specific satellite
    GPSEphemeris getGPSEphemeris(uint8_t svid, double tow);
    GALEphemeris getGALEphemeris(uint8_t svid, double tow);
    
    // Get ionosphere parameters
    Ionosphere getGPSIonosphere();
    Ionosphere getGALIonosphere();
    
    // Get GGTO
    GGTO getGGTO();
    
private:
    std::string cache_dir_;
    std::map<uint8_t, std::vector<GPSEphemeris>> gps_ephem_cache_;
    std::map<uint8_t, std::vector<GALEphemeris>> gal_ephem_cache_;
    Ionosphere gps_iono_;
    Ionosphere gal_iono_;
    GGTO ggto_;
    
    // RTKLIB wrappers
    bool parseRINEXNav(const std::string& file);
    void extractGPSEphem(const nav_t* nav);
    void extractGALEphem(const nav_t* nav);
};
```

**Implementation Notes**:
- Use RTKLIB's `readrnx()` function for RINEX parsing
- Cache ephemeris for 4 hours (typical validity)
- Download new BRDC every 2 hours (IGS updates)
- IGS BRDC URL: `ftp://igs.bkg.bund.de/IGS/BRDC/$(year)/$(doy)/BRDC00IGS_R_$(year)$(doy)0000_01D_MN.rnx.gz`

#### Task 1.3: Ephemeris Provider Node

**File**: `gnss_ephemeris_provider/src/ephemeris_provider_node.cpp`
```cpp
class EphemerisProviderNode : public rclcpp::Node {
public:
    EphemerisProviderNode() : Node("gnss_ephemeris_provider") {
        // Parameters
        declare_parameter("update_interval", 7200.0);  // 2 hours
        declare_parameter("publish_rate", 10.0);       // 10 Hz
        declare_parameter("brdc_source", "igs");       // igs, local, manual
        declare_parameter("cache_dir", "/tmp/gnss_brdc");
        
        // Publishers
        gps_ephem_pub_ = create_publisher<GPSEphemeris>(
            "/gps_ephemeris", rclcpp::SensorDataQoS());
        gal_ephem_pub_ = create_publisher<GALEphemeris>(
            "/gal_ephemeris", rclcpp::SensorDataQoS());
        gps_iono_pub_ = create_publisher<Ionosphere>(
            "/gps_ionosphere", rclcpp::SensorDataQoS());
        gal_iono_pub_ = create_publisher<Ionosphere>(
            "/gal_ionosphere", rclcpp::SensorDataQoS());
        ggto_pub_ = create_publisher<GGTO>(
            "/ggto_data", rclcpp::SensorDataQoS());
            
        // Timers
        update_timer_ = create_wall_timer(
            std::chrono::seconds(static_cast<int>(get_parameter("update_interval").as_double())),
            std::bind(&EphemerisProviderNode::updateBRDC, this));
            
        publish_timer_ = create_wall_timer(
            std::chrono::milliseconds(static_cast<int>(1000.0 / get_parameter("publish_rate").as_double())),
            std::bind(&EphemerisProviderNode::publishAll, this));
            
        // Initialize parser
        parser_ = std::make_unique<BRDCParser>(get_parameter("cache_dir").as_string());
        
        // Initial download
        updateBRDC();
    }
    
private:
    void updateBRDC() {
        RCLCPP_INFO(get_logger(), "Updating BRDC ephemeris...");
        if (parser_->downloadLatestBRDC()) {
            RCLCPP_INFO(get_logger(), "BRDC updated successfully");
        } else {
            RCLCPP_WARN(get_logger(), "Failed to update BRDC, using cached data");
        }
    }
    
    void publishAll() {
        // Get current GPS time
        auto now = this->now();
        double tow = /* compute from ROS time */;
        
        // Publish GPS ephemeris for all satellites
        for (uint8_t svid = 1; svid <= 32; ++svid) {
            auto ephem = parser_->getGPSEphemeris(svid, tow);
            if (ephem.valid) {
                gps_ephem_pub_->publish(ephem);
            }
        }
        
        // Publish GAL ephemeris
        for (uint8_t svid = 1; svid <= 36; ++svid) {
            auto ephem = parser_->getGALEphemeris(svid, tow);
            if (ephem.valid) {
                gal_ephem_pub_->publish(ephem);
            }
        }
        
        // Publish ionosphere & GGTO
        gps_iono_pub_->publish(parser_->getGPSIonosphere());
        gal_iono_pub_->publish(parser_->getGALIonosphere());
        ggto_pub_->publish(parser_->getGGTO());
    }
    
    std::unique_ptr<BRDCParser> parser_;
    rclcpp::Publisher<GPSEphemeris>::SharedPtr gps_ephem_pub_;
    rclcpp::Publisher<GALEphemeris>::SharedPtr gal_ephem_pub_;
    rclcpp::Publisher<Ionosphere>::SharedPtr gps_iono_pub_;
    rclcpp::Publisher<Ionosphere>::SharedPtr gal_iono_pub_;
    rclcpp::Publisher<GGTO>::SharedPtr ggto_pub_;
    rclcpp::TimerBase::SharedPtr update_timer_;
    rclcpp::TimerBase::SharedPtr publish_timer_;
};

int main(int argc, char** argv) {
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<EphemerisProviderNode>());
    rclcpp::shutdown();
    return 0;
}
```

#### Task 1.4: Build & Test

```bash
cd /workspace/fgo_ws
colcon build --packages-select gnss_ephemeris_provider
source install/setup.bash

# Test standalone
ros2 run gnss_ephemeris_provider ephemeris_provider_node

# Check topics
ros2 topic list | grep -E "ephemeris|iono|ggto"
ros2 topic echo /gps_ephemeris --once
ros2 topic hz /gps_ephemeris
```

**Expected Output**:
```
/gps_ephemeris @ 10 Hz (32 messages per cycle)
/gal_ephemeris @ 10 Hz (36 messages per cycle)
/gps_ionosphere @ 10 Hz
/gal_ionosphere @ 10 Hz
/ggto_data @ 10 Hz
```

**Deliverables**:
- ✅ Message definitions compiled
- ✅ BRDC parser functional
- ✅ Provider node publishing ephemeris
- ✅ Data validated (correct SVIDs, reasonable values)

---

<a name="phase-1-alt"></a>
## Phase 1-Alt: Driver Extension (Option 2) - Advanced Path

⚠️ **This section is for Option 2 only**. Skip to [Phase 2](#phase-2) if using Option 1.

### Objective
Extend `septentrio_gnss_driver` to parse and publish navigation SBF blocks.

### Reference Architecture

Study NovAtel driver's navigation message handling:
- Repository: https://github.com/rwth-irt/novatel_oem7_driver.git
- Key files:
  - `novatel_oem7_msgs/msg/GPSEPHEM.msg`
  - `novatel_oem7_msgs/msg/GALINAVEPHEMERIS.msg`
  - `src/message_handler.cpp` (registration pattern)
  - `src/handlers/` (individual log parsers)

### Task 1-Alt.1: Fork and Setup

```bash
cd /workspace/fgo_ws/src/gnssFGO

# Fork Septentrio driver
git clone https://github.com/septentrio-gnss/septentrio_gnss_driver.git septentrio_gnss_driver_ext
cd septentrio_gnss_driver_ext

# Create feature branch
git checkout -b feature/navigation-blocks

# Study existing SBF parsing
cat include/septentrio_gnss_driver/parsers/sbf_blocks.hpp | grep -A 20 "struct.*Block"
```

### Task 1-Alt.2: Define SBF Navigation Block Structures

**File**: `include/septentrio_gnss_driver/parsers/sbf_blocks.hpp`

Add structures for navigation blocks (refer to Septentrio SBF Reference Manual):

```cpp
// GPS Navigation Data (Block 4027)
struct GPSNav_t {
    BlockHeader block_header;
    uint8_t sv_id;           // Satellite ID (1-32)
    uint8_t crc_passed;      // CRC validation flag
    uint8_t viterbi_cnt;     // Viterbi error count
    uint8_t reserved;
    
    uint16_t wn;             // Week number
    uint16_t iodc;           // Issue of Data, Clock
    uint8_t iode2;           // Issue of Data, Ephemeris (subframe 2)
    uint8_t iode3;           // Issue of Data, Ephemeris (subframe 3)
    uint8_t health;          // Satellite health
    uint8_t alert;           // Alert flag
    uint8_t anti_spoof;      // Anti-spoofing flag
    uint8_t code_on_l2;      // Code on L2
    
    uint8_t l2_p_flag;       // L2 P data flag
    uint8_t fit_int;         // Fit interval flag
    uint16_t reserved2;
    
    uint32_t toc;            // Time of clock (seconds)
    uint32_t toe;            // Time of ephemeris (seconds)
    
    // Clock parameters
    double af0;              // Clock bias (s)
    double af1;              // Clock drift (s/s)
    double af2;              // Clock drift rate (s/s^2)
    double tgd;              // Group delay (s)
    
    // Orbital parameters
    double sqrt_a;           // Square root of semi-major axis (m^0.5)
    double ecc;              // Eccentricity
    double i0;               // Inclination at reference time (rad)
    double omega0;           // Longitude of ascending node (rad)
    double omega;            // Argument of perigee (rad)
    double m0;               // Mean anomaly at reference time (rad)
    double delta_n;          // Mean motion difference (rad/s)
    double idot;             // Rate of inclination angle (rad/s)
    double omega_dot;        // Rate of right ascension (rad/s)
    
    // Correction terms
    double cuc;              // Cos harmonic correction (rad)
    double cus;              // Sin harmonic correction (rad)
    double crc;              // Cos harmonic correction (m)
    double crs;              // Sin harmonic correction (m)
    double cic;              // Cos harmonic correction (rad)
    double cis;              // Sin harmonic correction (rad)
} __attribute__((packed));

// Galileo Navigation Data (Block 4046)
struct GALNav_t {
    BlockHeader block_header;
    uint8_t sv_id;           // Satellite ID (1-36)
    uint8_t source;          // Data source: 1=I/NAV, 2=F/NAV
    uint8_t reserved[2];
    
    uint16_t wn;             // Galileo week number
    uint16_t iod_nav;        // Issue of Data, Navigation
    
    uint32_t toc;            // Time of clock (seconds)
    uint32_t toe;            // Time of ephemeris (seconds)
    
    // Clock parameters
    double af0;              // Clock bias (s)
    double af1;              // Clock drift (s/s)
    double af2;              // Clock drift rate (s/s^2)
    double bgd_e1e5a;        // Group delay E1-E5a (s)
    double bgd_e1e5b;        // Group delay E1-E5b (s)
    
    // Orbital parameters (same structure as GPS)
    double sqrt_a;
    double ecc;
    double i0;
    double omega0;
    double omega;
    double m0;
    double delta_n;
    double idot;
    double omega_dot;
    
    // Correction terms
    double cuc;
    double cus;
    double crc;
    double crs;
    double cic;
    double cis;
    
    // Health/accuracy
    uint8_t e1b_health;
    uint8_t e1b_validity;
    uint8_t e5a_health;
    uint8_t e5a_validity;
    uint8_t e5b_health;
    uint8_t e5b_validity;
    uint16_t sisa;           // Signal-in-space accuracy
} __attribute__((packed));

// GPS Ionosphere Parameters (Block 4029)
struct GPSIon_t {
    BlockHeader block_header;
    
    // Klobuchar model coefficients
    double alpha0, alpha1, alpha2, alpha3;
    double beta0, beta1, beta2, beta3;
} __attribute__((packed));

// Galileo Ionosphere Parameters (Block 4058)
struct GALIon_t {
    BlockHeader block_header;
    
    // NeQuick model coefficients
    double ai0, ai1, ai2;
    uint8_t disturbance_flags;
    uint8_t reserved[3];
} __attribute__((packed));

// Galileo-GPS Time Offset (Block 4046 subtype)
struct GALGSTGPS_t {
    BlockHeader block_header;
    
    double a0gp;            // Constant term (s)
    double a1gp;            // Rate term (s/s)
    uint32_t t0gp;          // Reference time (s)
    uint16_t wn0gp;         // Reference week
    uint16_t reserved;
} __attribute__((packed));
```

### Task 1-Alt.3: Create ROS2 Message Definitions

**File**: `msg/GPSNavSBF.msg`
```python
# GPS Navigation Data from SBF Block 4027
std_msgs/Header header
BlockHeader block_header

uint8 sv_id
uint8 crc_passed
uint16 wn
uint16 iodc
uint8 iode
uint8 health

uint32 toc
uint32 toe

float64 af0
float64 af1
float64 af2
float64 tgd

float64 sqrt_a
float64 ecc
float64 i0
float64 omega0
float64 omega
float64 m0
float64 delta_n
float64 idot
float64 omega_dot

float64 cuc
float64 cus
float64 crc
float64 crs
float64 cic
float64 cis
```

(Similar for GALNavSBF, GPSIonSBF, GALIonSBF, GALGSTGPS)

### Task 1-Alt.4: Implement Parsers

**File**: `src/septentrio_gnss_driver/parsers/sbf_navigation_parser.cpp`

```cpp
#include "septentrio_gnss_driver/parsers/sbf_blocks.hpp"
#include "septentrio_gnss_driver/parsers/sbf_navigation_parser.hpp"

namespace septentrio_gnss_driver {

bool SBFNavigationParser::parseGPSNav(const uint8_t* buffer, size_t size,
                                       septentrio_gnss_driver::msg::GPSNavSBF& msg) {
    if (size < sizeof(GPSNav_t)) {
        return false;
    }
    
    const GPSNav_t* nav = reinterpret_cast<const GPSNav_t*>(buffer);
    
    // Copy block header
    msg.block_header = parseBlockHeader(&nav->block_header);
    
    // Copy navigation data
    msg.sv_id = nav->sv_id;
    msg.crc_passed = nav->crc_passed;
    msg.wn = nav->wn;
    msg.iodc = nav->iodc;
    msg.iode = nav->iode2;  // Use subframe 2 IOD
    msg.health = nav->health;
    
    msg.toc = nav->toc;
    msg.toe = nav->toe;
    
    msg.af0 = nav->af0;
    msg.af1 = nav->af1;
    msg.af2 = nav->af2;
    msg.tgd = nav->tgd;
    
    msg.sqrt_a = nav->sqrt_a;
    msg.ecc = nav->ecc;
    msg.i0 = nav->i0;
    msg.omega0 = nav->omega0;
    msg.omega = nav->omega;
    msg.m0 = nav->m0;
    msg.delta_n = nav->delta_n;
    msg.idot = nav->idot;
    msg.omega_dot = nav->omega_dot;
    
    msg.cuc = nav->cuc;
    msg.cus = nav->cus;
    msg.crc = nav->crc;
    msg.crs = nav->crs;
    msg.cic = nav->cic;
    msg.cis = nav->cis;
    
    return true;
}

// Similar for parseGALNav, parseGPSIon, parseGALIon, parseGALGSTGPS

} // namespace
```

### Task 1-Alt.5: Register Handlers in Driver

**File**: `src/septentrio_gnss_driver/node/septentrio_gnss_driver_node.cpp`

Modify message dispatcher to recognize navigation blocks:

```cpp
void SeptentrioGnssDriverNode::processSBFMessage(const uint8_t* buffer, size_t size) {
    if (size < sizeof(BlockHeader)) {
        return;
    }
    
    const BlockHeader* header = reinterpret_cast<const BlockHeader*>(buffer);
    uint16_t block_id = header->id;
    
    switch (block_id) {
        // ... existing cases ...
        
        case 4027:  // GPSNav
            handleGPSNav(buffer, size);
            break;
            
        case 4046:  // GALNav
            handleGALNav(buffer, size);
            break;
            
        case 4029:  // GPSIon
            handleGPSIon(buffer, size);
            break;
            
        case 4058:  // GALIon
            handleGALIon(buffer, size);
            break;
            
        // ... etc
    }
}

void SeptentrioGnssDriverNode::handleGPSNav(const uint8_t* buffer, size_t size) {
    septentrio_gnss_driver::msg::GPSNavSBF msg;
    
    if (nav_parser_.parseGPSNav(buffer, size, msg)) {
        msg.header.stamp = this->now();
        msg.header.frame_id = "gps";
        gps_nav_pub_->publish(msg);
    }
}

// Similar for other navigation blocks
```

### Task 1-Alt.6: Build and Test

```bash
cd /workspace/fgo_ws
colcon build --packages-select septentrio_gnss_driver_ext

# Test with live receiver
ros2 launch septentrio_gnss_driver_ext septentrio.launch.py

# Check new topics
ros2 topic list | grep -i nav
# Expected:
# /gps_nav_sbf
# /gal_nav_sbf
# /gps_ion_sbf
# /gal_ion_sbf
# /gal_gst_gps

# Verify data
ros2 topic echo /gps_nav_sbf --once
```

### Task 1-Alt.7: Submit PR to Upstream

```bash
# Push to fork
git push origin feature/navigation-blocks

# Create pull request on GitHub
# Title: "Add GPS/Galileo Navigation Block Support (SBF 4027, 4046, 4029, 4058)"
# Description: Explain motivation, reference NovAtel driver, provide test results
```

**Deliverables**:
- ✅ SBF navigation blocks defined
- ✅ Parsers implemented and tested
- ✅ ROS2 messages published
- ✅ PR submitted to upstream

**Proceed to Phase 2 with driver-sourced navigation data**

---

### Path B: Driver Extension (Option 2)

#### Task 1.1: Investigate SBF Blocks

```bash
cd /workspace/fgo_ws/src/gnssFGO/septentrio_gnss_driver

# Check SBF block definitions
grep -rn "4027\|4028\|4046\|GPSNav\|GALNav" include/
grep -rn "parseGPSNav\|parseGALNav" src/

# Check if driver can output these blocks
# Look in communication module
cat src/septentrio_gnss_driver/communication/communication_core.cpp | grep -A 20 "parse"
```

**Questions to Answer**:
1. Does SBF stream include nav blocks?
2. Are they parsed by driver?
3. Are they converted to ROS messages?
4. If not, can we add them?

#### Task 1.2: Add Message Definitions (if not exist)

If SBF nav blocks exist but aren't published:

**File**: `septentrio_gnss_driver/msg/GPSNav.msg`
```python
BlockHeader block_header
uint8 sv_id
# ... (copy structure from SBF manual)
```

#### Task 1.3: Add Parsers & Publishers

Modify driver to parse and publish nav blocks (details depend on investigation results).

---

<a name="phase-2"></a>
## Phase 2: Wire Navigation Inputs (Days 5-6, ~8 hours)

### Objective
Connect ephemeris/iono/GGTO data to Septentrio preprocessor.

### Task 2.1: Add Subscribers to Header

**File**: `septentrio_preprocessor.h`
```cpp
// Add after existing subscribers
rclcpp::Subscription<gnss_ephemeris_provider::msg::GPSEphemeris>::SharedPtr gps_ephem_sub_;
rclcpp::Subscription<gnss_ephemeris_provider::msg::GALEphemeris>::SharedPtr gal_ephem_sub_;
rclcpp::Subscription<gnss_ephemeris_provider::msg::Ionosphere>::SharedPtr gps_iono_sub_;
rclcpp::Subscription<gnss_ephemeris_provider::msg::Ionosphere>::SharedPtr gal_iono_sub_;
rclcpp::Subscription<gnss_ephemeris_provider::msg::GGTO>::SharedPtr ggto_sub_;

// Add buffers (use base class buffers that already exist)
// gps_nav_ephemeris_buffer_ (already in base)
// gal_nav_ephemeris_buffer_ (already in base)
// gps_ion_buffer_ (already in base)
// gal_ion_buffer_ (already in base)
// gal_gst_gps_buffer_ (already in base)
```

### Task 2.2: Add Callback Functions

**File**: `septentrio_preprocessor.h`
```cpp
private:
    void onGPSEphemCb(const gnss_ephemeris_provider::msg::GPSEphemeris::ConstSharedPtr msg);
    void onGALEphemCb(const gnss_ephemeris_provider::msg::GALEphemeris::ConstSharedPtr msg);
    void onGPSIonoCb(const gnss_ephemeris_provider::msg::Ionosphere::ConstSharedPtr msg);
    void onGALIonoCb(const gnss_ephemeris_provider::msg::Ionosphere::ConstSharedPtr msg);
    void onGGTOCb(const gnss_ephemeris_provider::msg::GGTO::ConstSharedPtr msg);
    
    // Converters
    static gnssraw_gps_nav_t convertGPSEphemeris(
        const gnss_ephemeris_provider::msg::GPSEphemeris& msg);
    static gnssraw_gal_nav_t convertGALEphemeris(
        const gnss_ephemeris_provider::msg::GALEphemeris& msg);
    static gnssraw_gps_ion_t convertGPSIonosphere(
        const gnss_ephemeris_provider::msg::Ionosphere& msg);
    static gnssraw_gal_ion_t convertGALIonosphere(
        const gnss_ephemeris_provider::msg::Ionosphere& msg);
    static gnssraw_ggto_t convertGGTO(
        const gnss_ephemeris_provider::msg::GGTO& msg);
```

### Task 2.3: Implement Subscribers in initialize()

**File**: `septentrio_preprocessor.cpp`
```cpp
void SeptentrioPreProcessor::initialize(rclcpp::Node& node, const std::string& receiver_type)
{
    // ... existing code ...
    
    // Subscribe to ephemeris topics
    gps_ephem_sub_ = node_ptr_->create_subscription<gnss_ephemeris_provider::msg::GPSEphemeris>(
        "/gps_ephemeris",
        rclcpp::SensorDataQoS(),
        [this](const gnss_ephemeris_provider::msg::GPSEphemeris::ConstSharedPtr msg) {
            this->onGPSEphemCb(msg);
        },
        *commonSubOpt_);
        
    gal_ephem_sub_ = node_ptr_->create_subscription<gnss_ephemeris_provider::msg::GALEphemeris>(
        "/gal_ephemeris",
        rclcpp::SensorDataQoS(),
        [this](const gnss_ephemeris_provider::msg::GALEphemeris::ConstSharedPtr msg) {
            this->onGALEphemCb(msg);
        },
        *commonSubOpt_);
        
    // ... same pattern for iono, GGTO ...
    
    RCLCPP_INFO(node_ptr_->get_logger(), 
               "Septentrio GNSS Preprocessor initialized with ephemeris feeds");
}
```

### Task 2.4: Implement Callbacks

**File**: `septentrio_preprocessor.cpp`
```cpp
void SeptentrioPreProcessor::onGPSEphemCb(
    const gnss_ephemeris_provider::msg::GPSEphemeris::ConstSharedPtr msg)
{
    // Convert message to internal format
    gnssraw_gps_nav_t nav = convertGPSEphemeris(*msg);
    
    // Update ephemeris buffer (per-satellite storage)
    mutex_gps_ephem_.lock();
    uint8_t svid = msg->svid;
    if (svid >= 1 && svid <= 37) {
        // Copy to appropriate array index
        gps_nav_ephemeris_buffer_.WNc[svid-1] = nav.WNc[0];
        gps_nav_ephemeris_buffer_.TOW[svid-1] = nav.TOW[0];
        gps_nav_ephemeris_buffer_.SVID[svid-1] = nav.SVID[0];
        // ... copy all fields ...
    }
    mutex_gps_ephem_.unlock();
    
    RCLCPP_DEBUG(node_ptr_->get_logger(), 
                "GPS Ephemeris received for SV %d", msg->svid);
}

void SeptentrioPreProcessor::onGALEphemCb(
    const gnss_ephemeris_provider::msg::GALEphemeris::ConstSharedPtr msg)
{
    // Similar to GPS, but for Galileo
    gnssraw_gal_nav_t nav = convertGALEphemeris(*msg);
    
    mutex_gal_ephem_.lock();
    uint8_t svid = msg->svid;
    if (svid >= 1 && svid <= 36) {
        // Copy to array
        gal_nav_ephemeris_buffer_.IODnav[svid-1] = nav.IODnav[0];
        // ... all fields ...
    }
    mutex_gal_ephem_.unlock();
}

// Similar for iono and GGTO
```

### Task 2.5: Implement Converters

**File**: `septentrio_preprocessor.cpp`
```cpp
gnssraw_gps_nav_t SeptentrioPreProcessor::convertGPSEphemeris(
    const gnss_ephemeris_provider::msg::GPSEphemeris& msg)
{
    gnssraw_gps_nav_t nav{};
    
    // Map fields (use index 0 since we're filling one satellite)
    nav.TOW[0] = msg.tow;
    nav.WNc[0] = msg.week;
    nav.SVID[0] = msg.svid;
    nav.Health[0] = msg.health;
    nav.IODC[0] = msg.iodc;
    nav.IODE[0] = msg.iode;
    nav.T_gd[0] = msg.tgd;
    nav.T_oc[0] = msg.toc;
    nav.A_f0[0] = msg.af0;
    nav.A_f1[0] = msg.af1;
    nav.A_f2[0] = msg.af2;
    nav.C_rs[0] = msg.crs;
    nav.DELTA_N[0] = msg.delta_n;
    nav.M_0[0] = msg.m0;
    nav.C_uc[0] = msg.cuc;
    nav.E[0] = msg.ecc;
    nav.C_us[0] = msg.cus;
    nav.SQRT_A[0] = msg.sqrt_a;
    nav.T_oe[0] = msg.toe;
    nav.C_ic[0] = msg.cic;
    nav.OMEGA_0[0] = msg.omega0;
    nav.C_is[0] = msg.cis;
    nav.I_0[0] = msg.i0;
    nav.C_rc[0] = msg.crc;
    nav.omega[0] = msg.omega;
    nav.OMEGADOT[0] = msg.omega_dot;
    nav.IDOT[0] = msg.idot;
    
    return nav;
}

// Similar for GAL, iono, GGTO
gnssraw_gal_nav_t SeptentrioPreProcessor::convertGALEphemeris(...) { /* ... */ }
gnssraw_gps_ion_t SeptentrioPreProcessor::convertGPSIonosphere(...) { /* ... */ }
gnssraw_gal_ion_t SeptentrioPreProcessor::convertGALIonosphere(...) { /* ... */ }
gnssraw_ggto_t SeptentrioPreProcessor::convertGGTO(...) { /* ... */ }
```

### Task 2.6: Test Navigation Data Flow

```bash
# Terminal 1: Start ephemeris provider
ros2 run gnss_ephemeris_provider ephemeris_provider_node

# Terminal 2: Start Septentrio preprocessor
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py

# Terminal 3: Monitor
ros2 topic echo /rosout | grep -i "ephemeris\|preprocessing"

# Expected: No more "no ephemeris" warnings
# Expected: "Septentrio preprocessing: N epochs processed" logs
```

**Deliverables**:
- ✅ Subscribers added & compiling
- ✅ Callbacks implemented
- ✅ Converters functional
- ✅ Ephemeris data reaching preprocessing
- ✅ Warning "no ephemeris" gone
- ✅ Preprocessing executing

---

<a name="phase-3"></a>
## Phase 3: RTCM Integration (Day 7, ~4 hours)

### Objective
Enable RTK corrections via RTCM messages.

### Task 3.1: Add RTCM Subscription

Already exists in base class! Just need to verify topic name.

**File**: `septentrio_preprocessor.cpp`
```cpp
// In initialize():
// Base class already creates rtcmv3_L1E1_sub_ on "/rtcm_l1e1"
// No changes needed if RTCM source publishes to this topic
```

### Task 3.2: Configure RTCM Source

**Option A**: Septentrio driver internal RTK
- Check if driver can publish RTCM corrections
- Configure in `rover.yaml`

**Option B**: External NTRIP client
```bash
# Install NTRIP client
sudo apt-get install ntrip-client-ros2

# Configure mountpoint, credentials
# Publishes to /rtcm_l1e1
```

### Task 3.3: Test RTK

```bash
# Start RTCM source (NTRIP or driver)
ros2 run ntrip_client ntrip_client_node --ros-args -p host:=ntrip_server

# Monitor
ros2 topic echo /gnss_obs_preprocessed --field has_rtk

# Expected: has_rtk: true when corrections present
```

**Deliverables**:
- ✅ RTCM subscription active
- ✅ DD preprocessing enabled when RTCM present
- ✅ `has_rtk` flag set correctly

---

<a name="phase-4"></a>
## Phase 4: Dual-Antenna Wiring (Day 8, ~4 hours)

### Objective
Connect AttEuler and BaseVectorGeod to dual-antenna preprocessing.

### Task 4.1: Modify executePreprocessing()

**File**: `septentrio_preprocessor.cpp`
```cpp
#if USE_DUAL_ANTENNA
    // Get baseline and attitude
    double baseline_length = 0.0;
    double baseline_heading = 0.0;
    bool baseline_valid = false;
    
    if (baseline_buffer_.buffer.size() > 0 && attitude_buffer_.buffer.size() > 0) {
        auto baseline = baseline_buffer_.get_last_buffer();
        auto attitude = attitude_buffer_.get_last_buffer();
        
        if (!baseline.vector_info_geod.empty()) {
            const auto& vec = baseline.vector_info_geod[0];
            baseline_length = std::sqrt(
                vec.delta_north * vec.delta_north +
                vec.delta_east * vec.delta_east +
                vec.delta_up * vec.delta_up);
            baseline_heading = attitude.heading;
            baseline_valid = (baseline_length > 0.5 && baseline_length < 10.0); // Typical vehicle
        }
    }
    
    // Enable DD dual-antenna if baseline valid
    preprocessor_input.EnableDualAntennaDD = baseline_valid && enable_dual_antenna_DD_;
    
    RCLCPP_DEBUG(node_ptr_->get_logger(),
                "Dual-antenna: baseline=%.2f m, heading=%.1f°, DD=%s",
                baseline_length, baseline_heading,
                preprocessor_input.EnableDualAntennaDD ? "ON" : "OFF");
#endif
```

### Task 4.2: Test Dual-Antenna

```bash
# Check topics
ros2 topic echo /atteuler
ros2 topic echo /basevectorgeod

# Monitor preprocessing
ros2 topic echo /gnss_obs_preprocessed --field has_dualantenna

# Expected: has_dualantenna: true, heading populated
```

**Deliverables**:
- ✅ Baseline/attitude used in preprocessing
- ✅ DD dual-antenna enabled when valid
- ✅ Heading output correct

---

<a name="phase-5"></a>
## Phase 5: Quality & Integrity (Day 9, ~6 hours)

### Objective
Add LOS/NLOS filtering and integrity monitoring.

### Task 5.1: Implement LOS/NLOS Filter

**File**: `septentrio_preprocessor.cpp`
```cpp
gnssraw_measurement_t SeptentrioPreProcessor::applyLOSFilter(
    const gnssraw_measurement_t& meas_raw)
{
    gnssraw_measurement_t meas_filtered = meas_raw;
    size_t out_idx = 0;
    
    for (size_t i = 0; i < meas_raw.N; ++i) {
        // Get CN0 and elevation (need to compute from sat position)
        double cn0 = meas_raw.CN0[i*5];  // First signal
        
        // Simple thresholds
        const double MIN_CN0 = 25.0;     // dB-Hz
        const double MIN_ELEV = 10.0;    // degrees
        
        if (cn0 >= MIN_CN0 /* && elev >= MIN_ELEV */) {
            // Keep this satellite
            meas_filtered.SVID[out_idx] = meas_raw.SVID[i];
            // Copy all signals...
            out_idx++;
        } else {
            RCLCPP_DEBUG(node_ptr_->get_logger(),
                        "Filtered SV %d (CN0=%.1f dB-Hz)",
                        meas_raw.SVID[i], cn0);
        }
    }
    
    meas_filtered.N = out_idx;
    return meas_filtered;
}

// Call in executePreprocessing() before step()
// meas_main = applyLOSFilter(meas_main);
```

### Task 5.2: Map Integrity Parameters

Already done in P1! IntegrityParametersBus is populated.

### Task 5.3: Propagate Integrity Outputs

**File**: `septentrio_preprocessor.cpp`
```cpp
// In executePreprocessing(), after step():
if (preprocessor_output.IntegrityFlagAntMain > 0) {
    RCLCPP_WARN_THROTTLE(node_ptr_->get_logger(), *node_ptr_->get_clock(), 1000,
                        "Integrity alert: flag %d on main antenna",
                        preprocessor_output.IntegrityFlagAntMain);
}
```

**Deliverables**:
- ✅ LOS/NLOS filter active
- ✅ Integrity flags monitored
- ✅ Warnings on quality issues

---

<a name="phase-6"></a>
## Phase 6: Output Publishing (Day 10, ~6 hours)

### Objective
Publish all preprocessing outputs.

### Task 6.1: Implement GNSSObsPreProcessed Publisher

**File**: `septentrio_preprocessor.cpp`
```cpp
void SeptentrioPreProcessor::publishPreprocessedObs(
    const GNSSPreProcessingDualAntenna::ExtY_GNSSPreProcessingDualAnt_T& output)
{
    auto msg = std::make_shared<irt_nav_msgs::msg::GNSSObsPreProcessed>();
    
    msg->header.stamp = node_ptr_->now();
    msg->header.frame_id = "gnss";
    
    // Main antenna observations
    msg->gnss_obs_ant_main = makeGNSSObsROSMsg(
        output.GnssMeasurementBusAntMain,
        static_cast<size_t>(output.GnssMeasurementSizeAntMain));
        
    msg->num_meas_ant_main = static_cast<size_t>(output.GnssMeasurementSizeAntMain);
    msg->integrity_flag_ant_main = static_cast<uint8_t>(output.IntegrityFlagAntMain);
    
    // DOP
    msg->dop_ant_main.resize(2);
    msg->dop_ant_main[0] = output.DOPAntMain[0];  // HDOP
    msg->dop_ant_main[1] = output.DOPAntMain[1];  // VDOP
    
    // GGTO
    msg->time_offset_gal_gps = output.DeltaSystemTimeGNSSAntMain;
    msg->is_ggto_valid = output.IsGGTOValidAntMain;
    
    // RTK
    msg->has_rtk = (output.GPSGALCorrectedAntMain[0] > 0 || 
                    output.GPSGALCorrectedAntMain[1] > 0);
    
#if USE_DUAL_ANTENNA
    // Auxiliary antenna
    msg->gnss_obs_ant_aux = makeGNSSObsROSMsg(
        output.GnssMeasurementBusAntAux,
        static_cast<size_t>(output.GnssMeasurementSizeAntAux));
        
    msg->num_meas_ant_aux = static_cast<size_t>(output.GnssMeasurementSizeAntAux);
    msg->has_dualantenna = true;
#endif
    
    gnss_obs_pub_->publish(*msg);
}

// Call in executePreprocessing() after step()
```

### Task 6.2: Implement LS PVT Publisher

**File**: `septentrio_preprocessor.cpp`
```cpp
void SeptentrioPreProcessor::publishLSPVT(
    const GNSSPreProcessingDualAntenna::ExtY_GNSSPreProcessingDualAnt_T& output)
{
    auto msg = std::make_shared<irt_nav_msgs::msg::PVTLS>();
    
    msg->header.stamp = node_ptr_->now();
    msg->header.frame_id = "gnss";
    
    // Copy from output.LSPVTAntMain
    // ... (map fields)
    
    lspvt_pub_->publish(*msg);
}
```

### Task 6.3: Implement Residuals Publisher

**File**: `septentrio_preprocessor.cpp`
```cpp
void SeptentrioPreProcessor::publishResiduals(
    const GNSSPreProcessingDualAntenna::ExtY_GNSSPreProcessingDualAnt_T& output)
{
    auto msg = std::make_shared<irt_nav_msgs::msg::Residuals>();
    
    msg->header.stamp = node_ptr_->now();
    
    // Copy from output.ResidualsAntMain
    // ... (map fields)
    
    ls_residuals_pub_->publish(*msg);
}
```

### Task 6.4: Test All Outputs

```bash
# Monitor all topics
ros2 topic list | grep -E "gnss_obs|PVT|residual"

# Check data
ros2 topic echo /gnss_obs_preprocessed --once
ros2 topic echo /LeastSquarePVT --once
ros2 topic echo /ls_ant_main_residuals --once

# Validate rates
ros2 topic hz /gnss_obs_preprocessed
# Expected: ~10 Hz (matches MeasEpoch rate)
```

**Deliverables**:
- ✅ All 4 output topics publishing
- ✅ Data fields populated correctly
- ✅ Rates appropriate

---

<a name="phase-7"></a>
## Phase 7: Testing & Validation (Days 11-12, ~8 hours)

### Objective
Verify full pipeline works and matches NovAtel quality.

### Task 7.1: Static Open-Sky Test

**Setup**:
- Place receiver in clear sky location
- Let run for 30+ minutes
- Record bag file

**Validation**:
```bash
ros2 bag record -a -o sept_static_test

# Analyze
python3 analyze_gnss_quality.py sept_static_test/
```

**Metrics**:
- ✅ >10 satellites tracked
- ✅ HDOP < 2.0
- ✅ Preprocessed obs count > 0
- ✅ No integrity warnings
- ✅ GGTO valid (if GPS+GAL enabled)

### Task 7.2: RTK Test (if base station available)

**Setup**:
- Configure RTCM corrections
- Known baseline test

**Validation**:
- ✅ `has_rtk` flag true
- ✅ Position accuracy < 10 cm (horizontal)
- ✅ DD observations populated
- ✅ Fix solution stable

### Task 7.3: Dual-Antenna Test

**Setup**:
- Mosaic-H dual-antenna configuration
- Measure known baseline

**Validation**:
- ✅ Baseline length within 5% of truth
- ✅ Heading accuracy < 1°
- ✅ Dual-antenna flag set
- ✅ DD dual-antenna active

### Task 7.4: Comparison with NovAtel

**Setup**:
- Run same scenario with NovAtel
- Compare outputs

**Metrics**:
| Metric | NovAtel | Septentrio | Pass? |
|--------|---------|------------|-------|
| Obs count | 12 | 11-13 | ✅ |
| HDOP | 1.2 | 1.1-1.3 | ✅ |
| Position (m) | 0.05 | <0.10 | ✅ |
| Integrity | OK | OK | ✅ |

### Task 7.5: Regression Testing

```bash
cd /workspace/fgo_ws
./scripts/run_gnss_tests.sh septentrio

# Run automated test suite
colcon test --packages-select irt_gnss_preprocessing
colcon test-result --verbose
```

**Deliverables**:
- ✅ Static test passed
- ✅ RTK test passed (if applicable)
- ✅ Dual-antenna test passed
- ✅ Parity with NovAtel demonstrated
- ✅ Regression tests passing

---

## Phase 8: Documentation & Deployment (Day 13, ~4 hours)

### Task 8.1: Update Configuration Files

**File**: `config/septentrio_preprocessing.yaml`
```yaml
GNSSPreprocessor:
  receiver_type: "septentrio"
  default_buffer_size: 5
  publish_gnss_obs: true
  
# Ephemeris source
ephemeris_source:
  type: "external_provider"  # or "driver" if Option 2
  update_interval: 7200       # seconds
  
# RTK
rtcm_source:
  enabled: true
  topic: "/rtcm_l1e1"
  
# Dual-antenna
dual_antenna:
  enabled: true
  baseline_min: 0.5  # meters
  baseline_max: 10.0
```

### Task 8.2: Update Launch Files

**File**: `launch/septentrio_full.launch.py`
```python
def generate_launch_description():
    return LaunchDescription([
        # Ephemeris provider
        Node(
            package='gnss_ephemeris_provider',
            executable='ephemeris_provider_node',
            name='ephemeris_provider',
            parameters=[...]
        ),
        
        # Septentrio driver
        Node(
            package='septentrio_gnss_driver',
            executable='septentrio_gnss_driver_node',
            parameters=[...]
        ),
        
        # Preprocessing
        Node(
            package='irt_gnss_preprocessing',
            executable='gnss_preprocessing_node',
            parameters=[...]
        ),
    ])
```

### Task 8.3: Write User Guide

**File**: `SEPTENTRIO_USER_GUIDE.md`
```markdown
# Septentrio GNSS Preprocessing User Guide

## Quick Start
1. Start ephemeris provider: `ros2 run gnss_ephemeris_provider ...`
2. Start Septentrio driver: `ros2 launch septentrio_gnss_driver rover.launch.py`
3. Start preprocessing: `ros2 launch irt_gnss_preprocessing septentrio_full.launch.py`

## Configuration
...

## Troubleshooting
...
```

**Deliverables**:
- ✅ Config files updated
- ✅ Launch files complete
- ✅ User guide written
- ✅ README updated

---

## Summary Timeline

### Option 1 (External Provider) - Recommended

| Phase | Duration | Deliverable | Notes |
|-------|----------|-------------|-------|
| 0. Decision & Setup | 4 hours | Strategy chosen, deps installed | One-time setup |
| 1. Ephemeris Provider | 2-3 days | Nav data publishing | Core development |
| 2. Wire Nav Inputs | 1 day | Preprocessing executing | Integration |
| 3. RTCM Integration | 0.5 day | RTK enabled | Leverages existing code |
| 4. Dual-Antenna | 0.5 day | Heading/baseline used | Septentrio-specific |
| 5. Quality/Integrity | 1 day | Filtering active | Enhancement |
| 6. Output Publishing | 1 day | All topics publishing | Already 90% done |
| 7. Testing | 1-2 days | Validation complete | Critical |
| 8. Documentation | 0.5 day | Deployment ready | Final polish |
| **TOTAL** | **8-11 days** | **Full parity with NovAtel** | **Recommended path** |

### Option 2 (Driver Extension) - Advanced

| Phase | Duration | Deliverable | Notes |
|-------|----------|-------------|-------|
| 0. Decision & Setup | 4 hours | Strategy chosen, fork created | One-time |
| 1-Alt. Driver Extension | 2-3 days | SBF nav blocks parsed | Complex development |
| 2. Wire Nav Inputs | 0.5 day | Preprocessing executing | Simpler with native msgs |
| 3. RTCM Integration | 0.5 day | RTK enabled | Same as Option 1 |
| 4. Dual-Antenna | 0.5 day | Heading/baseline used | Same as Option 1 |
| 5. Quality/Integrity | 1 day | Filtering active | Same as Option 1 |
| 6. Output Publishing | 1 day | All topics publishing | Same as Option 1 |
| 7. Testing | 1-2 days | Validation complete | Same as Option 1 |
| 8. Documentation | 0.5 day | Deployment ready | Same as Option 1 |
| PR Review/Merge | 1-4 weeks | Upstream integration | **Unknown timeline** |
| **TOTAL** | **8-11 days** + PR | **Full parity** | **Higher risk** |

### Comparison

| Metric | Option 1 (Ext Provider) | Option 2 (Driver Ext) |
|--------|------------------------|----------------------|
| **Dev Time** | 8-11 days | 8-11 days + PR wait |
| **Complexity** | Medium | High |
| **Risk** | Low | Medium-High |
| **Maintenance** | Low (standalone) | High (coupled to driver) |
| **Reusability** | Any GNSS receiver | Septentrio only |
| **Real-time** | 2hr ephemeris lag | Immediate |
| **Dependencies** | RTKLIB, IGS | SBF spec, driver maintenance |

---

## Success Criteria Checklist

### Phase Completion Milestones

**Phase 1 Complete**:
- [ ] Ephemeris provider node running (Option 1) OR driver publishing nav blocks (Option 2)
- [ ] GPS ephemeris published for visible satellites (1-32)
- [ ] Galileo ephemeris published for visible satellites (1-36)
- [ ] GPS ionosphere parameters published (Klobuchar α/β)
- [ ] Galileo ionosphere parameters published (NeQuick ai)
- [ ] GGTO published (GPS-Galileo time offset)
- [ ] Data validated: reasonable orbital parameters, current week number

**Phase 2 Complete**:
- [ ] Preprocessor subscribes to all navigation topics
- [ ] Callbacks populating internal buffers (gps_nav_ephemeris_buffer_, etc.)
- [ ] Converters mapping external messages → gnssraw_*_t formats
- [ ] `checkHaveEphem()` returns true for active satellites
- [ ] Warning "no ephemeris received" no longer appears
- [ ] Preprocessing `step()` function executing (check logs: "N epochs processed")

**Phase 3 Complete**:
- [ ] RTCM subscription active (/rtcm_l1e1 or configured topic)
- [ ] RTCM messages reaching preprocessor (check rtcm_buffer_ size)
- [ ] DD preprocessing enabled when corrections valid
- [ ] `has_rtk` flag true in output when applicable
- [ ] Observe RTK Float or RTK Fixed convergence

**Phase 4 Complete** (Dual-Antenna Configuration):
- [ ] AttEuler data received (/atteuler topic)
- [ ] BaseVectorGeod data received (/basevectorgeod topic)
- [ ] Baseline length computed correctly (compare with receiver solution)
- [ ] Heading propagated to preprocessing input
- [ ] Dual-antenna DD enabled flag set appropriately
- [ ] `has_dualantenna` true in output

**Phase 5 Complete**:
- [ ] LOS/NLOS filter active (satellite count filtering based on CN0/elevation)
- [ ] Integrity parameters populated (IntegrityParametersBus)
- [ ] Integrity flags monitored (IntegrityFlagAntMain/Aux)
- [ ] Warnings issued when integrity thresholds exceeded
- [ ] Filtered vs unfiltered measurement counts logged

**Phase 6 Complete**:
- [ ] `/gnss_obs_preprocessed` publishing at expected rate
- [ ] `/LeastSquarePVT` publishing with position solution
- [ ] `/ls_ant_main_residuals` publishing with measurement residuals
- [ ] `/ls_ant_aux_residuals` publishing (dual-antenna only)
- [ ] All message fields populated (no NaN/inf values)
- [ ] Covariances reasonable (not zero, not excessive)

**Phase 7 Complete**:
- [ ] Static open-sky test: >10 satellites, HDOP < 2.0
- [ ] RTK test: Fix achieved, accuracy < 10 cm
- [ ] Dual-antenna test: Baseline accurate to 5%, heading accurate to 1°
- [ ] Comparison with NovAtel: Similar satellite counts, DOPs, position accuracy
- [ ] Automated regression tests passing
- [ ] Rosbag recorded for documentation

**Phase 8 Complete**:
- [ ] Configuration files updated (YAML parameters documented)
- [ ] Launch files tested (all nodes start correctly)
- [ ] User guide written (quick start, troubleshooting)
- [ ] README updated (system overview, architecture)
- [ ] Code comments added where needed
- [ ] Example outputs documented

### Final Integration Checklist

**Functional Requirements**:
- [ ] Preprocessing executes for every measurement epoch
- [ ] GPS and Galileo observations processed
- [ ] Ephemeris applied to compute satellite positions
- [ ] Ionospheric corrections applied
- [ ] GGTO used for GPS-GAL synchronization
- [ ] RTK corrections applied when available
- [ ] Dual-antenna processing functional (if hardware supports)
- [ ] LOS/NLOS filtering reduces outliers
- [ ] Integrity monitoring detects anomalies

**Performance Requirements**:
- [ ] Preprocessing latency < 50 ms per epoch
- [ ] No message drops under nominal load
- [ ] CPU usage < 30% on target platform
- [ ] Memory footprint < 500 MB
- [ ] Ephemeris updates reliable (no stale data)

**Quality Requirements**:
- [ ] Position accuracy matches NovAtel within 10%
- [ ] HDOP/VDOP comparable to NovAtel
- [ ] Satellite count difference < 2 satellites
- [ ] Residuals within expected ranges (< 5 m pseudorange, < 5 cm carrier)
- [ ] No unhandled exceptions or crashes during 24hr test

**Documentation Requirements**:
- [ ] Architecture documented (data flow, components)
- [ ] Configuration parameters explained (with defaults)
- [ ] Troubleshooting guide written (common issues, solutions)
- [ ] Example launch files provided
- [ ] Message formats documented
- [ ] Coordinate frame conventions specified

---

## Key Architectural Insights (from Driver Comparison)

### What We Learned

1. **NovAtel's Advantage**: Driver publishes **11 topics** including ephemeris/iono because OEM7 firmware **natively separates** these as distinct logs. Driver just parses and forwards.

2. **Septentrio's Gap**: Driver publishes **7 topics** focused on position/measurements. Navigation data exists in **SBF blocks** but driver **chose not to expose them** (likely to simplify driver scope).

3. **Design Philosophy**:
   - **NovAtel**: "Publish everything the receiver outputs" → Complete but verbose
   - **Septentrio**: "Publish what most users need" → Simple but incomplete for advanced use

4. **Our Solution Strategy**:
   - **Option 1**: Work around driver limitation with external source → Fast, proven
   - **Option 2**: Enhance driver to match NovAtel → Better long-term, higher effort

### Recommended Best Practices

Based on this analysis, future GNSS integrations should:

1. **Audit driver capabilities early**: Check if navigation data (ephemeris/iono) is published
2. **Plan for ephemeris provider**: Build receiver-agnostic ephemeris source for any driver
3. **Contribute upstream**: Submit PRs to improve open-source drivers
4. **Document assumptions**: Clearly state which messages preprocessing requires
5. **Design for flexibility**: Preprocessing should accept navigation data from multiple sources

### References

- **NovAtel OEM7 Driver**: https://github.com/rwth-irt/novatel_oem7_driver.git
- **Septentrio GNSS Driver**: https://github.com/septentrio-gnss/septentrio_gnss_driver.git
- **Driver Comparison Document**: `gnss_drivers_comparison.md` (this workspace)
- **Septentrio SBF Reference**: Available from Septentrio support portal
- **IGS Broadcast Ephemeris**: ftp://igs.bkg.bund.de/IGS/BRDC/
- **RTKLIB Documentation**: http://www.rtklib.com/

---

## Contact & Support

- **Package Maintainer**: h.zhang@irt.rwth-aachen.de
- **GNSS Preprocessing Team**: irt_gnss@irt.rwth-aachen.de
- **Driver Issues**: 
  - NovAtel: https://github.com/rwth-irt/novatel_oem7_driver/issues
  - Septentrio: https://github.com/septentrio-gnss/septentrio_gnss_driver/issues
- **Workspace Issues**: [Your GitHub issue tracker]

---

**Document Version**: 2.0  
**Last Updated**: December 9, 2025  
**Based On**: Comprehensive driver comparison analysis (gnss_drivers_comparison.md)  
**Status**: Ready for implementation

---

**End of Procedure**
