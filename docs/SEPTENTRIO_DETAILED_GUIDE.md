# Septentrio Mosaic-H Integration - Complete Detailed Guide

**Date**: December 8, 2025  
**Target Hardware**: Septentrio Mosaic-H GNSS Receiver  
**Software Version**: ROS2 Humble, gnssFGO framework

---

## Table of Contents

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Step-by-Step Implementation Details](#2-step-by-step-implementation-details)
3. [Hardware Setup Guide](#3-hardware-setup-guide)
4. [Software Configuration](#4-software-configuration)
5. [Verification and Testing](#5-verification-and-testing)
6. [Dual Antenna Setup and Testing](#6-dual-antenna-setup-and-testing)
7. [Tuning and Optimization](#7-tuning-and-optimization)
8. [Troubleshooting Guide](#8-troubleshooting-guide)

---

## 1. System Architecture Overview

### 1.1 Complete System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SEPTENTRIO MOSAIC-H RECEIVER                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  Main Antenna│  │  Aux Antenna │  │    Serial/   │              │
│  │   (GPS/GAL/  │  │  (Optional   │  │   Ethernet   │              │
│  │    BDS/GLO)  │  │  Dual Ant.)  │  │   Interface  │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                  │                  │                       │
│         └──────────────────┴──────────────────┘                      │
│                             │                                         │
│                    ┌────────▼────────┐                               │
│                    │  SBF Protocol   │                               │
│                    │  Message Stream │                               │
│                    └────────┬────────┘                               │
└─────────────────────────────┼────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  SEPTENTRIO GNSS DRIVER (ROS2)                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  SBF Block Parser                                             │ │
│  │  - MeasEpoch (4027) → /measepoch                             │ │
│  │  - PVTGeodetic (4007) → /pvtgeodetic                         │ │
│  │  - PosCovGeodetic (5906) → /poscovgeodetic                   │ │
│  │  - VelCovGeodetic (5908) → /velcovgeodetic                   │ │
│  │  - ReceiverTime (5914) → /receivertime                       │ │
│  │  - AttEuler (5938) → /atteuler [Dual Antenna]                │ │
│  │  - BaseVectorGeod (4028) → /basevectorgeod [Dual Antenna]    │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────┬───────────────────────────────────────┘
                              │ ROS2 Topics
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│           IRT GNSS PREPROCESSING (SeptentrioPreProcessor)           │
│  ┌────────────────────────────────────────────────────────────────┐│
│  │  PLUGIN ARCHITECTURE (pluginlib)                               ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        ││
│  │  │   Message    │  │   Message    │  │   Circular   │        ││
│  │  │ Subscribers  │→ │    Filters   │→ │   Buffers    │        ││
│  │  │              │  │(Time Sync)   │  │              │        ││
│  │  └──────────────┘  └──────────────┘  └──────┬───────┘        ││
│  │                                               │                 ││
│  │  ┌────────────────────────────────────────────▼──────────────┐││
│  │  │         MESSAGE CONVERSION LAYER                          │││
│  │  │  - convertMeasEpochToRaw()                               │││
│  │  │    * MeasEpoch → gnssraw_measurement_t                   │││
│  │  │    * Pseudorange reconstruction (MSB + LSB)              │││
│  │  │    * Carrier phase reconstruction                         │││
│  │  │    * Doppler, CN0, Lock time extraction                  │││
│  │  │  - convertPVTGeodetic()                                  │││
│  │  │    * PVTGeodetic → gnssraw_pvt_geodetic_t                │││
│  │  │    * Position/velocity conversion                         │││
│  │  │    * Mode/error code mapping                             │││
│  │  │    * Covariance computation                              │││
│  │  └──────────────────────────────────────────┬───────────────┘││
│  │                                               │                 ││
│  │  ┌────────────────────────────────────────────▼──────────────┐││
│  │  │      GNSS PREPROCESSING ALGORITHM (GTSAM-based)          │││
│  │  │  - Cycle slip detection                                  │││
│  │  │  - Carrier phase smoothing                               │││
│  │  │  - Outlier rejection (RAIM, Chi-square)                  │││
│  │  │  - Ionosphere/Troposphere corrections                    │││
│  │  │  - Dual antenna baseline processing [Optional]           │││
│  │  │  - Double differencing (RTK) [Optional]                  │││
│  │  └──────────────────────────────────────────┬───────────────┘││
│  └──────────────────────────────────────────────┼────────────────┘│
└───────────────────────────────────────────────┼──────────────────┘
                                                 │
                                                 ▼
                          ┌──────────────────────────────────┐
                          │    OUTPUT ROS2 TOPICS            │
                          │  - /gnss/raw_measurements        │
                          │  - /gnss/pvt_geodetic            │
                          │  - /gnss/preprocessed_obs        │
                          │  - /gnss/factors                 │
                          └──────────────┬───────────────────┘
                                         │
                                         ▼
                          ┌──────────────────────────────────┐
                          │  ONLINE FACTOR GRAPH             │
                          │  OPTIMIZATION (online_fgo)       │
                          │  - GNSS factors                  │
                          │  - IMU factors                   │
                          │  - LiDAR factors                 │
                          │  → Optimized trajectory          │
                          └──────────────────────────────────┘
```

### 1.2 Data Flow Diagram

```
Time Synchronization Flow:
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ PVTGeodetic  │────▶│              │     │              │
│  (10 Hz)     │     │  Message     │────▶│  Callback    │
├──────────────┤     │  Filters     │     │  Triggered   │
│PosCovGeodetic│────▶│ (Approx Time)│     │              │
│  (10 Hz)     │     │              │     │  Store in    │
├──────────────┤     │  Queue: 10   │     │  Buffers     │
│VelCovGeodetic│────▶│  Age: 0ms    │     │              │
│  (10 Hz)     │     └──────────────┘     └──────┬───────┘
└──────────────┘                                  │
                                                  ▼
┌──────────────────────────────────────────────────────────┐
│              CIRCULAR BUFFER STORAGE                      │
│  ┌─────────┬─────────┬─────────┬─────────┬─────────┐    │
│  │ Epoch-5 │ Epoch-4 │ Epoch-3 │ Epoch-2 │ Epoch-1 │    │
│  └─────────┴─────────┴─────────┴─────────┴─────────┘    │
│  Default size: 5 epochs (configurable)                   │
└──────────────────────────────────────────────────────────┘
```

### 1.3 Message Conversion Flow

```
MeasEpoch (SBF Block 4027) Conversion:
┌─────────────────────────────────────────────────────────────┐
│  Input: septentrio_gnss_driver::msg::MeasEpoch             │
│  ┌────────────────────────────────────────────────────────┐│
│  │ BlockHeader:                                           ││
│  │   - TOW (ms)          → Convert to seconds             ││
│  │   - WNc (weeks)       → Copy directly                  ││
│  │ Type1 Channels: [array of measurements]               ││
│  │   - sv_id             → SVID[i]                        ││
│  │   - code_lsb (0.001m) → Reconstruct pseudorange       ││
│  │   - misc (MSB)        → Pseudorange[i] = MSB + LSB    ││
│  │   - doppler (0.0001Hz)→ Doppler[i]                    ││
│  │   - carrier_lsb       → Reconstruct carrier phase     ││
│  │   - carrier_msb       → Carrier[i] = MSB + LSB        ││
│  │   - cn0 (0.25 dB-Hz)  → CN0[i]                        ││
│  │   - lock_time         → Locktime[i]                   ││
│  │   - type              → Type[i] (signal type)         ││
│  └────────────────────────────────────────────────────────┘│
│  ↓                                                          │
│  Output: gnssraw_measurement_t                             │
│  ┌────────────────────────────────────────────────────────┐│
│  │ TOW, WNc, N (number of satellites)                    ││
│  │ SVID[40], Pseudorange[200], Carrier[200]              ││
│  │ Doppler[200], CN0[200], Type[200]                     ││
│  │ Pseudorange_Sigma[200], Carrier_Sigma[200]            ││
│  │ Locktime[200]                                          ││
│  │                                                        ││
│  │ Note: Array layout = 40 SVs × 5 signals per SV        ││
│  └────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Step-by-Step Implementation Details

### Step 1: Package Dependency Configuration

**File Modified**: `package.xml`  
**Lines Changed**: Added line 22

**Change Made**:
```xml
<depend>septentrio_gnss_driver</depend>
```

**Purpose**: 
- Declares dependency on Septentrio GNSS driver package
- Enables ROS2 build system to find Septentrio message definitions
- Ensures driver is built before preprocessing package
- Allows linking against Septentrio message libraries

**Technical Details**:
- ROS2 uses `ament` build system
- `<depend>` tag creates compile-time and runtime dependency
- Enables `#include <septentrio_gnss_driver/msg/...>` in C++ code

---

### Step 2: Build System Configuration

**File Modified**: `CMakeLists.txt`  
**Lines Changed**: Line ~23, Line ~54, Line ~72

**Changes Made**:

1. **Package Finding** (Line ~23):
```cmake
find_package(septentrio_gnss_driver REQUIRED)
```

2. **Add to Dependencies** (Line ~54):
```cmake
set(AMENT_DEPENDENCIES
  rclcpp
  pluginlib
  message_filters
  novatel_oem7_msgs
  ublox_msgs
  septentrio_gnss_driver  # ADDED
  irt_nav_common
  irt_nav_msgs
  # ... other dependencies
)
```

3. **Add Source File** (Line ~72):
```cmake
add_library(${PROJECT_NAME} SHARED
  src/gnss_utils.cpp
  src/impl/novatel_oem7_preprocessor.cpp
  src/impl/ublox_f9p_preprocessor.cpp
  src/impl/septentrio_preprocessor.cpp  # ADDED
)
```

**Purpose**:
- `find_package`: Locates Septentrio package CMake config
- `AMENT_DEPENDENCIES`: Links message libraries automatically
- `add_library`: Compiles new Septentrio preprocessor source

**Technical Details**:
- CMake searches in `install/septentrio_gnss_driver/share/`
- AMENT automatically handles include paths and linking
- Shared library (.so) contains all preprocessor implementations

---

### Step 3: Type Definitions Header

**File Created**: `include/irt_gnss_preprocessing/impl/septentrio_types.h`  
**Total Lines**: 84

**Contents**:

```cpp
namespace Septentrio {

// PVT Mode Constants (from SBF Reference Manual)
constexpr uint8_t PVT_MODE_NO_SOLUTION = 0;           // No solution
constexpr uint8_t PVT_MODE_STANDALONE = 1;            // Stand-alone PVT
constexpr uint8_t PVT_MODE_DIFFERENTIAL = 2;          // Differential
constexpr uint8_t PVT_MODE_RTK_FIXED = 4;             // RTK with fixed ambiguities
constexpr uint8_t PVT_MODE_RTK_FLOAT = 5;             // RTK with float ambiguities
constexpr uint8_t PVT_MODE_SBAS_AIDED = 6;            // SBAS aided
constexpr uint8_t PVT_MODE_MOVING_BASE_RTK_FIXED = 7; // Moving base RTK fixed
constexpr uint8_t PVT_MODE_MOVING_BASE_RTK_FLOAT = 8; // Moving base RTK float
constexpr uint8_t PVT_MODE_PPP = 10;                  // Precise Point Positioning

// PVT Error Constants
constexpr uint8_t PVT_ERROR_NONE = 0;                 // No error
constexpr uint8_t PVT_ERROR_NOT_ENOUGH_MEAS = 1;      // Not enough measurements
constexpr uint8_t PVT_ERROR_NOT_ENOUGH_EPHEM = 2;     // Not enough ephemerides
constexpr uint8_t PVT_ERROR_DOP_TOO_LARGE = 3;        // DOP too large
constexpr uint8_t PVT_ERROR_SUM_SQUARED_RESIDUALS = 4;// Residuals too large
constexpr uint8_t PVT_ERROR_NO_CONVERGENCE = 5;       // No convergence
constexpr uint8_t PVT_ERROR_NOT_ENOUGH_MEAS_AFTER_OUTLIER_REJECTION = 6;

// Helper Functions
inline std::string getPVTModeString(uint8_t mode) {
    switch(mode) {
        case PVT_MODE_NO_SOLUTION: return "NO_SOLUTION";
        case PVT_MODE_STANDALONE: return "STANDALONE";
        case PVT_MODE_DIFFERENTIAL: return "DIFFERENTIAL";
        case PVT_MODE_RTK_FIXED: return "RTK_FIXED";
        case PVT_MODE_RTK_FLOAT: return "RTK_FLOAT";
        case PVT_MODE_SBAS_AIDED: return "SBAS";
        case PVT_MODE_PPP: return "PPP";
        default: return "UNKNOWN";
    }
}

inline std::string getPVTErrorString(uint8_t error) {
    switch(error) {
        case PVT_ERROR_NONE: return "NONE";
        case PVT_ERROR_NOT_ENOUGH_MEAS: return "NOT_ENOUGH_MEASUREMENTS";
        case PVT_ERROR_NOT_ENOUGH_EPHEM: return "NOT_ENOUGH_EPHEMERIDES";
        case PVT_ERROR_DOP_TOO_LARGE: return "DOP_TOO_LARGE";
        case PVT_ERROR_NO_CONVERGENCE: return "NO_CONVERGENCE";
        default: return "UNKNOWN_ERROR";
    }
}

} // namespace Septentrio
```

**Purpose**:
- Centralizes Septentrio-specific constants
- Provides human-readable status strings for logging
- Maps Septentrio codes to internal representation
- Improves code maintainability and readability

**Design Decisions**:
- Used `constexpr` for compile-time constants (zero runtime cost)
- `inline` functions avoid multiple definition linker errors
- Namespace prevents name collisions with other receiver types

---

### Step 4: Preprocessor Class Header

**File Created**: `include/irt_gnss_preprocessing/impl/septentrio_preprocessor.h`  
**Total Lines**: 127

**Class Structure**:

```cpp
class SeptentrioPreProcessor : public GNSSPreprocessor {
public:
    // Plugin interface (must override)
    void initialize(rclcpp::Node& node, const std::string& receiver_type) override;

private:
    // ============ MESSAGE SUBSCRIBERS ============
    
    // Main antenna raw measurements (direct subscription)
    rclcpp::Subscription<septentrio_gnss_driver::msg::MeasEpoch>::SharedPtr 
        measepoch_main_sub_;
    
    // Solution messages (synchronized subscription via message_filters)
    message_filters::Subscriber<septentrio_gnss_driver::msg::PVTGeodetic> pvt_sub_;
    message_filters::Subscriber<septentrio_gnss_driver::msg::PosCovGeodetic> poscov_sub_;
    message_filters::Subscriber<septentrio_gnss_driver::msg::VelCovGeodetic> velcov_sub_;
    
    // Receiver time (leap seconds)
    rclcpp::Subscription<septentrio_gnss_driver::msg::ReceiverTime>::SharedPtr 
        receiver_time_sub_;
    
    // ============ TIME SYNCHRONIZATION ============
    
    // Synchronization policy: Allow ~10ms time difference between messages
    using SeptentrioSolSyncPolicy = message_filters::sync_policies::ApproximateTime<
        septentrio_gnss_driver::msg::PVTGeodetic,
        septentrio_gnss_driver::msg::PosCovGeodetic,
        septentrio_gnss_driver::msg::VelCovGeodetic>;
    
    std::unique_ptr<message_filters::Synchronizer<SeptentrioSolSyncPolicy>> sol_sync_;
    
    // ============ CIRCULAR BUFFERS ============
    
    CircularBuffer<septentrio_gnss_driver::msg::MeasEpoch> measepoch_main_buffer_;
    CircularBuffer<septentrio_gnss_driver::msg::PVTGeodetic> pvt_buffer_;
    CircularBuffer<septentrio_gnss_driver::msg::PosCovGeodetic> poscov_buffer_;
    CircularBuffer<septentrio_gnss_driver::msg::VelCovGeodetic> velcov_buffer_;
    CircularBuffer<septentrio_gnss_driver::msg::ReceiverTime> receiver_time_buffer_;
    
    // ============ CALLBACK FUNCTIONS ============
    
    void onMeasEpochMainCb(
        const septentrio_gnss_driver::msg::MeasEpoch::ConstSharedPtr msg);
    
    void onSolutionMsgCb(
        const septentrio_gnss_driver::msg::PVTGeodetic::ConstSharedPtr pvt,
        const septentrio_gnss_driver::msg::PosCovGeodetic::ConstSharedPtr poscov,
        const septentrio_gnss_driver::msg::VelCovGeodetic::ConstSharedPtr velcov);
    
    void onReceiverTimeCb(
        const septentrio_gnss_driver::msg::ReceiverTime::ConstSharedPtr msg);
    
    // ============ CONVERSION FUNCTIONS ============
    
    gnssraw_measurement_t convertMeasEpochToRaw(
        const septentrio_gnss_driver::msg::MeasEpoch& msg);
    
    gnssraw_pvt_geodetic_t convertPVTGeodetic(
        const septentrio_gnss_driver::msg::PVTGeodetic& msg);
    
    uint8_t convertPVTModeToInternal(uint8_t septentrio_mode);
    uint8_t convertPVTErrorToInternal(uint8_t septentrio_error);
    
    // ============ DUAL ANTENNA SUPPORT (CONDITIONAL) ============
#if USE_DUAL_ANTENNA
    rclcpp::Subscription<septentrio_gnss_driver::msg::MeasEpoch>::SharedPtr 
        measepoch_aux_sub_;
    rclcpp::Subscription<septentrio_gnss_driver::msg::AttEuler>::SharedPtr 
        attitude_sub_;
    rclcpp::Subscription<septentrio_gnss_driver::msg::BaseVectorGeod>::SharedPtr 
        baseline_sub_;
    
    CircularBuffer<septentrio_gnss_driver::msg::MeasEpoch> measepoch_aux_buffer_;
    CircularBuffer<septentrio_gnss_driver::msg::AttEuler> attitude_buffer_;
    CircularBuffer<septentrio_gnss_driver::msg::BaseVectorGeod> baseline_buffer_;
    
    void onMeasEpochAuxCb(
        const septentrio_gnss_driver::msg::MeasEpoch::ConstSharedPtr msg);
    void onAttitudeCb(
        const septentrio_gnss_driver::msg::AttEuler::ConstSharedPtr msg);
    void onBaselineCb(
        const septentrio_gnss_driver::msg::BaseVectorGeod::ConstSharedPtr msg);
#endif
};

// Plugin export macro (required by pluginlib)
PLUGINLIB_EXPORT_CLASS(
    irt_gnss_preprocessing::SeptentrioPreProcessor,
    irt_gnss_preprocessing::GNSSPreprocessor)
```

**Key Design Patterns**:

1. **Plugin Architecture**:
   - Inherits from `GNSSPreprocessor` base class
   - `PLUGINLIB_EXPORT_CLASS` enables dynamic loading
   - No changes needed in main node code

2. **Message Synchronization**:
   - Uses `message_filters::ApproximateTime` policy
   - Synchronizes PVT + PosCov + VelCov with same timestamp
   - Tolerates small timing differences (configured via `setAgePenalty`)

3. **Circular Buffers**:
   - Thread-safe storage for temporal data
   - Default size: 5 epochs
   - Enables historical data access for preprocessing algorithms

4. **Conditional Compilation**:
   - `#if USE_DUAL_ANTENNA` includes dual antenna code only when needed
   - Reduces binary size and complexity for single antenna setups
   - Enables/disables at CMake configuration time

---

### Step 5: Preprocessor Implementation

**File Created**: `src/impl/septentrio_preprocessor.cpp`  
**Total Lines**: 350+

**Function Breakdown**:

#### 5.1 `initialize()` Function

```cpp
void SeptentrioPreProcessor::initialize(
    rclcpp::Node& node, 
    const std::string& receiver_type)
{
    node_ptr_ = &node;
    receiver_type_ = receiver_type;
    
    // Initialize base class components
    this->initializeCommons();
    
    // Read parameters from configuration
    RosParameter<int> buffer_size("GNSSPreprocessor.default_buffer_size", 5, *node_ptr_);
    RosParameter<int> msg_lower_bound("GNSSPreprocessor.msg_lower_bound", 50000000, *node_ptr_);
    RosParameter<int> solution_sync_queue_size("GNSSPreprocessor.solution_sync_queue_size", 10, *node_ptr_);
    
    // Resize all circular buffers
    measepoch_main_buffer_.resize_buffer(buffer_size.value());
    pvt_buffer_.resize_buffer(buffer_size.value());
    poscov_buffer_.resize_buffer(buffer_size.value());
    velcov_buffer_.resize_buffer(buffer_size.value());
    receiver_time_buffer_.resize_buffer(buffer_size.value());
    
    // Set up message_filters synchronization for solution messages
    pvt_sub_.subscribe(node_ptr_, "/pvtgeodetic");
    poscov_sub_.subscribe(node_ptr_, "/poscovgeodetic");
    velcov_sub_.subscribe(node_ptr_, "/velcovgeodetic");
    
    sol_sync_ = std::make_unique<message_filters::Synchronizer<SeptentrioSolSyncPolicy>>(
        SeptentrioSolSyncPolicy(solution_sync_queue_size.value()),
        pvt_sub_, poscov_sub_, velcov_sub_);
    
    sol_sync_->setAgePenalty(0.);  // No penalty for age differences
    sol_sync_->registerCallback(
        std::bind(&SeptentrioPreProcessor::onSolutionMsgCb, this, 
                  std::placeholders::_1, std::placeholders::_2, std::placeholders::_3));
    
    // Set inter-message lower bound (prevents too-frequent callbacks)
    sol_sync_->setInterMessageLowerBound(0, rclcpp::Duration(0, msg_lower_bound.value()));
    sol_sync_->setInterMessageLowerBound(1, rclcpp::Duration(0, msg_lower_bound.value()));
    sol_sync_->setInterMessageLowerBound(2, rclcpp::Duration(0, msg_lower_bound.value()));
    
    // Subscribe to raw measurement messages (no synchronization needed)
    measepoch_main_sub_ = node_ptr_->create_subscription<MeasEpoch>(
        "/measepoch", rclcpp::SensorDataQoS(),
        [this](const MeasEpoch::ConstSharedPtr msg) {
            this->onMeasEpochMainCb(msg);
        }, *commonSubOpt_);
    
    // Subscribe to receiver time (for leap seconds)
    receiver_time_sub_ = node_ptr_->create_subscription<ReceiverTime>(
        "/receivertime", rclcpp::SensorDataQoS(),
        [this](const ReceiverTime::ConstSharedPtr msg) {
            this->onReceiverTimeCb(msg);
        }, *commonSubOpt_);
    
    // Initialize preprocessing algorithm instances
    gnss_preprocessor_ = std::make_unique<GNSS_preprocessingModelClass>();
    gnss_preprocessor_->initialize();
    
    RCLCPP_INFO(node_ptr_->get_logger(), 
                "Septentrio GNSS Preprocessor initialized successfully");
}
```

**Key Points**:
- Parameters loaded from YAML config file
- Message filters provide time-synchronized callbacks
- Lambda functions capture `this` pointer for member function callbacks
- QoS policy set to `SensorDataQoS()` for best-effort delivery

#### 5.2 `convertMeasEpochToRaw()` Function

```cpp
gnssraw_measurement_t SeptentrioPreProcessor::convertMeasEpochToRaw(
    const septentrio_gnss_driver::msg::MeasEpoch& msg)
{
    gnssraw_measurement_t raw_meas{};
    
    // Time conversion: Septentrio uses milliseconds, internal uses seconds
    raw_meas.TOW = msg.block_header.tow / 1000.0;
    raw_meas.WNc = msg.block_header.wnc;
    
    size_t num_obs = 0;
    
    // Process all Type1 measurement channels
    for (size_t i = 0; i < msg.type1.size() && num_obs < 40; ++i) {
        const auto& chan = msg.type1[i];
        
        // Store satellite ID
        raw_meas.SVID[num_obs] = chan.sv_id;
        
        // PSEUDORANGE RECONSTRUCTION
        // Septentrio splits pseudorange into MSB (misc field) and LSB (code_lsb)
        // MSB unit: 4294967.296 meters (2^32 / 1000)
        // LSB unit: 0.001 meters
        double pseudorange_msb = static_cast<double>(chan.misc) * 4294967.296;
        double pseudorange_lsb = static_cast<double>(chan.code_lsb) * 0.001;
        
        // Base index for signal array (40 SVs × 5 signals = 200 total)
        size_t base_idx = num_obs * 5;
        
        raw_meas.Pseudorange[base_idx] = pseudorange_msb + pseudorange_lsb;
        
        // DOPPLER CONVERSION
        // Septentrio unit: 0.0001 Hz
        raw_meas.Doppler[base_idx] = static_cast<double>(chan.doppler) * 0.0001;
        
        // CARRIER PHASE RECONSTRUCTION
        // MSB unit: 65.536 cycles
        // LSB unit: 0.001 cycles
        double carrier_msb = static_cast<double>(chan.carrier_msb) * 65.536;
        double carrier_lsb = static_cast<double>(chan.carrier_lsb) * 0.001;
        raw_meas.Carrier[base_idx] = carrier_msb + carrier_lsb;
        
        // CN0 CONVERSION
        // Septentrio unit: 0.25 dB-Hz
        raw_meas.CN0[base_idx] = static_cast<double>(chan.cn0) * 0.25;
        
        // LOCK TIME (directly in milliseconds)
        raw_meas.Locktime[base_idx] = static_cast<real32_T>(chan.lock_time);
        
        // SIGNAL TYPE
        raw_meas.Type[base_idx] = chan.type;
        
        // Initialize measurement variances (refined by preprocessing algorithm)
        raw_meas.Pseudorange_Sigma[base_idx] = 1.0;     // 1 meter default
        raw_meas.Carrier_Sigma[base_idx] = 0.01;        // 1 cm default
        
        num_obs++;
    }
    
    raw_meas.N = static_cast<uint8_T>(num_obs);
    
    return raw_meas;
}
```

**Technical Details**:
- **MSB/LSB Split**: Septentrio uses this to increase precision while keeping message size small
- **Array Indexing**: [SV index × 5 + signal index] allows multiple signals per satellite
- **Default Variances**: Initial values, preprocessing algorithm computes actual values based on CN0, elevation, etc.

#### 5.3 `convertPVTGeodetic()` Function

```cpp
gnssraw_pvt_geodetic_t SeptentrioPreProcessor::convertPVTGeodetic(
    const septentrio_gnss_driver::msg::PVTGeodetic& msg)
{
    gnssraw_pvt_geodetic_t pvt{};
    
    // TIME
    pvt.TOW = msg.block_header.tow / 1000.0;  // ms → seconds
    pvt.WNc = msg.block_header.wnc;
    
    // POSITION (Septentrio already provides in radians and meters)
    pvt.phi = msg.latitude;      // radians
    pvt.lambda = msg.longitude;  // radians
    pvt.h = msg.height;          // meters
    pvt.Undulation = msg.undulation;
    
    // VELOCITY (already in m/s)
    pvt.Vn = msg.vn;  // North
    pvt.Ve = msg.ve;  // East
    pvt.Vu = msg.vu;  // Up
    
    // COURSE OVER GROUND
    pvt.COG = msg.cog * M_PI / 180.0;  // degrees → radians
    
    // RECEIVER CLOCK
    pvt.RxClkBias = msg.rx_clk_bias * 0.001;    // ms → seconds
    pvt.RxClkDrift = msg.rx_clk_drift * 1e-6;   // ppm → fraction
    
    // SOLUTION QUALITY
    pvt.Mode = convertPVTModeToInternal(msg.mode);
    pvt.Error = convertPVTErrorToInternal(msg.error);
    pvt.NrSV = msg.nr_sv;
    
    // ACCURACY → VARIANCE
    // Septentrio provides accuracy in 0.01m units
    // Convert to meters then square for variance
    float h_acc_m = msg.h_accuracy * 0.01;
    float v_acc_m = msg.v_accuracy * 0.01;
    pvt.phi_var = h_acc_m * h_acc_m;
    pvt.lambda_var = h_acc_m * h_acc_m;
    pvt.h_var = v_acc_m * v_acc_m;
    
    // RTK INFORMATION
    pvt.ReferenceID = msg.reference_id;
    pvt.MeanCorrAge = static_cast<uint16_t>(msg.mean_corr_age);  // Already in 0.01s
    
    return pvt;
}
```

**Key Conversions**:
- Septentrio uses **accuracy** (1-sigma), internal format uses **variance** (sigma²)
- Time: milliseconds → seconds
- Angles: degrees → radians (except lat/lon already in radians)
- Clock drift: ppm (parts per million) → unitless fraction

#### 5.4 Mode/Error Mapping Functions

```cpp
uint8_t SeptentrioPreProcessor::convertPVTModeToInternal(uint8_t septentrio_mode)
{
    // Map Septentrio PVT modes to internal codes
    // (Internal codes match NovAtel for consistency)
    switch (septentrio_mode) {
        case Septentrio::PVT_MODE_NO_SOLUTION:          return 0;  // No solution
        case Septentrio::PVT_MODE_STANDALONE:           return 1;  // Single point
        case Septentrio::PVT_MODE_DIFFERENTIAL:         return 2;  // DGNSS
        case Septentrio::PVT_MODE_RTK_FLOAT:            return 5;  // RTK Float
        case Septentrio::PVT_MODE_RTK_FIXED:            return 4;  // RTK Fixed
        case Septentrio::PVT_MODE_SBAS_AIDED:           return 6;  // SBAS
        case Septentrio::PVT_MODE_PPP:                  return 10; // PPP
        case Septentrio::PVT_MODE_MOVING_BASE_RTK_FIXED:return 4;  // Treat as RTK Fixed
        case Septentrio::PVT_MODE_MOVING_BASE_RTK_FLOAT:return 5;  // Treat as RTK Float
        default:                                         return 11; // Unknown
    }
}

uint8_t SeptentrioPreProcessor::convertPVTErrorToInternal(uint8_t septentrio_error)
{
    switch (septentrio_error) {
        case Septentrio::PVT_ERROR_NONE:                return 0;  // No error
        case Septentrio::PVT_ERROR_NOT_ENOUGH_MEAS:     return 1;  // Insufficient obs
        case Septentrio::PVT_ERROR_NOT_ENOUGH_EPHEM:    return 2;  // No ephemeris
        case Septentrio::PVT_ERROR_DOP_TOO_LARGE:       return 3;  // Poor geometry
        case Septentrio::PVT_ERROR_NO_CONVERGENCE:      return 5;  // No convergence
        default:                                         return 9;  // Unknown error
    }
}
```

**Purpose**: Maintains consistency with existing NovAtel preprocessor codes, enabling common downstream processing.

---

### Step 6: Plugin Registry Update

**File Modified**: `irt_gnss_preprocessing_plugins.xml`  
**Lines Added**: 5 lines before closing `</library>` tag

**Addition**:
```xml
<class name="SeptentrioPreProcessor" 
       type="irt_gnss_preprocessing::SeptentrioPreProcessor" 
       base_class_type="irt_gnss_preprocessing::GNSSPreprocessor">
    <description>
        GNSS Preprocessor for Septentrio Mosaic-H receiver of IRT RWTH Aachen
    </description>
</class>
```

**Purpose**:
- Registers plugin with `pluginlib` system
- Enables dynamic loading via `ClassLoader`
- `name`: User-facing plugin name (used in config files)
- `type`: Fully qualified C++ class name
- `base_class_type`: Base class for polymorphism

**How It Works**:
1. Main node loads `irt_gnss_preprocessing_plugins.xml` at startup
2. Reads `receiver_type` parameter from config (e.g., "septentrio")
3. Uses `pluginlib::ClassLoader` to instantiate `SeptentrioPreProcessor`
4. Calls `initialize()` method to set up subscriptions

---

### Step 7: Configuration File Creation

**File Created**: `config/septentrio_preprocessing.yaml`  
**Total Lines**: 93

**Structure** (organized by category):

```yaml
/**:
  ros__parameters:
    # =============== GENERAL PARAMETERS ===============
    GNSSPreprocessor:
      receiver_type: "septentrio"
      use_gnss_sensor_on_board: true
      use_dual_antenna: false              # Enable for dual antenna setup
      print_info_duration: 10.0            # Status print interval (seconds)
      
      # Buffer configuration
      default_buffer_size: 5               # Number of epochs to store
      solution_sync_queue_size: 10         # Message sync queue depth
      msg_lower_bound: 50000000            # Min time between messages (ns)
      
      # =============== SIGNAL SELECTION ===============
      # Enable/disable specific GNSS signals
      use_gps_l1: true
      use_gps_l2: true
      use_gps_l5: false
      use_gal_e1: true
      use_gal_e5a: true
      use_gal_e5b: false
      use_gal_e6: false
      use_bds_b1: false
      use_bds_b2: false
      use_bds_b3: false
      use_glo_l1: false
      use_glo_l2: false
      
      # =============== RTK/DGNSS SETTINGS ===============
      use_rtk: true
      use_dgnss: false
      rtk_base_station_id: 0
      
      # =============== QUALITY THRESHOLDS ===============
      min_cn0: 25.0                        # Minimum C/N0 (dB-Hz)
      min_elevation: 10.0                  # Minimum elevation (degrees)
      max_age_correction: 30.0             # Max RTK correction age (seconds)
      
      # =============== PREPROCESSING ALGORITHMS ===============
      enable_cycle_slip_detection: true
      cycle_slip_threshold: 0.5            # Threshold in cycles
      
      enable_ionosphere_correction: true
      enable_troposphere_correction: true
      use_carrier_smoothing: true
      smoothing_window: 100                # Number of epochs
      
      # Outlier rejection
      enable_chi_square_test: true
      chi_square_threshold: 3.84           # 95% confidence
      enable_raim: true
      raim_threshold: 6.0
      
      # =============== DUAL ANTENNA PARAMETERS ===============
      baseline_length: 1.0                 # Distance between antennas (m)
      baseline_variance: 0.01              # Baseline uncertainty (m²)
      heading_variance: 0.1                # Heading uncertainty (deg²)
      
    # =============== SEPTENTRIO-SPECIFIC ===============
    Septentrio:
      # Topic names (adjust if driver uses different names)
      topic_measepoch: "/measepoch"
      topic_pvtgeodetic: "/pvtgeodetic"
      topic_poscovgeodetic: "/poscovgeodetic"
      topic_velcovgeodetic: "/velcovgeodetic"
      topic_receivertime: "/receivertime"
      
      # Dual antenna topics
      topic_measepoch_aux: "/measepoch_aux"
      topic_atteuler: "/atteuler"
      topic_basevectorgeod: "/basevectorgeod"
      
      # Solution mode acceptance
      accept_no_solution: false
      accept_standalone: true
      accept_differential: true
      accept_rtk_fixed: true
      accept_rtk_float: true
      accept_sbas_aided: true
      accept_moving_base_rtk_fixed: true
      accept_moving_base_rtk_float: false
      accept_ppp: true
      
      # Quality constraints
      min_satellites: 4
      max_horizontal_accuracy: 10.0        # meters
      max_vertical_accuracy: 20.0          # meters
      max_velocity_accuracy: 5.0           # m/s
      
    # =============== FACTOR GRAPH OPTIMIZATION ===============
    FGO:
      use_fgo: true
      optimization_window: 10              # Number of epochs
      gnss_variance_factor: 1.0
      use_robust_kernel: true
      robust_kernel_type: "Huber"          # Huber, Tukey, Cauchy
      robust_kernel_parameter: 1.345
      
    # =============== OUTPUT CONFIGURATION ===============
    Publishers:
      pub_raw_measurements: true
      pub_pvt_geodetic: true
      pub_preprocessed_obs: true
      pub_gnss_factors: true
      
      topic_raw_measurements: "/gnss/raw_measurements"
      topic_pvt_geodetic: "/gnss/pvt_geodetic"
      topic_preprocessed_obs: "/gnss/preprocessed_obs"
      topic_gnss_factors: "/gnss/factors"
```

**Configuration Tips**:
- **Buffer Size**: Increase if preprocessing requires more historical data
- **CN0 Threshold**: Lower for difficult environments, raise for urban canyons (removes multipath)
- **Elevation Mask**: 10-15° typical, higher reduces multipath but fewer satellites
- **RTK Correction Age**: Depends on baseline length (longer = more tolerance needed)

---

### Step 8: Launch File Creation

**File Created**: `launch/septentrio_preprocessor.launch.py`  
**Total Lines**: 103

**Contents**:

```python
#!/usr/bin/env python3

import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

def generate_launch_description():
    """
    Launch Septentrio GNSS preprocessor with configurable parameters.
    """
    
    # Get package directory
    pkg_dir = get_package_share_directory('irt_gnss_preprocessing')
    
    # Declare launch arguments
    config_file_arg = DeclareLaunchArgument(
        'config_file',
        default_value=os.path.join(pkg_dir, 'config', 'septentrio_preprocessing.yaml'),
        description='Path to preprocessing configuration YAML'
    )
    
    use_sim_time_arg = DeclareLaunchArgument(
        'use_sim_time',
        default_value='false',
        description='Use simulation (Gazebo) clock if true'
    )
    
    log_level_arg = DeclareLaunchArgument(
        'log_level',
        default_value='info',
        description='Logging level: debug, info, warn, error, fatal'
    )
    
    # GNSS Preprocessing Node
    preprocessing_node = Node(
        package='irt_gnss_preprocessing',
        executable='irt_gnss_preprocessing_node',
        name='septentrio_gnss_preprocessing',
        output='screen',
        parameters=[
            LaunchConfiguration('config_file'),
            {'use_sim_time': LaunchConfiguration('use_sim_time')}
        ],
        arguments=['--ros-args', '--log-level', LaunchConfiguration('log_level')],
        remappings=[
            # Input: Septentrio driver topics
            ('/measepoch', '/septentrio/measepoch'),
            ('/pvtgeodetic', '/septentrio/pvtgeodetic'),
            ('/poscovgeodetic', '/septentrio/poscovgeodetic'),
            ('/velcovgeodetic', '/septentrio/velcovgeodetic'),
            ('/receivertime', '/septentrio/receivertime'),
            
            # Input: Dual antenna (if enabled)
            ('/measepoch_aux', '/septentrio/measepoch_aux'),
            ('/atteuler', '/septentrio/atteuler'),
            ('/basevectorgeod', '/septentrio/basevectorgeod'),
            
            # Output: Preprocessed data
            ('/gnss/raw_measurements', '/gnss/septentrio/raw_measurements'),
            ('/gnss/pvt_geodetic', '/gnss/septentrio/pvt_geodetic'),
            ('/gnss/preprocessed_obs', '/gnss/septentrio/preprocessed_obs'),
            ('/gnss/factors', '/gnss/septentrio/factors'),
        ]
    )
    
    return LaunchDescription([
        config_file_arg,
        use_sim_time_arg,
        log_level_arg,
        preprocessing_node,
    ])
```

**Launch Options**:
```bash
# Default configuration
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py

# Custom config file
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  config_file:=/path/to/custom_config.yaml

# Debug logging
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  log_level:=debug

# Simulation mode
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  use_sim_time:=true
```

---

### Step 9: Build and Verification

**Build Process**:

```bash
cd /workspace/fgo_ws

# Step 1: Build Septentrio driver (dependency)
colcon build --packages-select septentrio_gnss_driver --cmake-args -DCMAKE_BUILD_TYPE=Release

# Step 2: Build preprocessing package
colcon build --packages-select irt_gnss_preprocessing --cmake-args -DCMAKE_BUILD_TYPE=Release

# Step 3: Source workspace
source install/setup.bash
```

**Compilation Issues Encountered and Fixed**:

1. **Issue**: Field name mismatches
   - Septentrio uses `latitude`, internal uses `phi`
   - Septentrio uses `vn`, internal uses `Vn` (capital)
   - **Solution**: Updated conversion functions to use correct field names

2. **Issue**: Array indexing for measurements
   - Internal format uses `Pseudorange[200]` (40 SVs × 5 signals)
   - **Solution**: Use `base_idx = num_obs * 5` for indexing

3. **Issue**: BaseVectorGeod structure
   - Message contains `vector_info_geod[]` array, not direct fields
   - **Solution**: Access `msg->vector_info_geod[0].delta_north` etc.

**Build Success Indicators**:
```
Finished <<< irt_gnss_preprocessing [34.7s]
Summary: 1 package finished [34.9s]
  1 package had stderr output: irt_gnss_preprocessing  # Only warnings, no errors
```

**Verification**:
```bash
# Check plugin registration
find install/irt_gnss_preprocessing -name "*plugins.xml" -exec cat {} \;
# Should show SeptentrioPreProcessor entry

# Check shared library
ls -lh install/irt_gnss_preprocessing/lib/libirt_gnss_preprocessing.so
# Should exist and be ~few MB in size

# Check installed files
ls install/irt_gnss_preprocessing/share/irt_gnss_preprocessing/
# Should contain: config/, launch/, irt_gnss_preprocessing_plugins.xml
```

---

## Summary of Files Created/Modified

| File | Type | Lines | Purpose |
|------|------|-------|---------|
| `package.xml` | Modified | +1 | Added Septentrio dependency |
| `CMakeLists.txt` | Modified | +3 | Build configuration |
| `septentrio_types.h` | Created | 84 | Type definitions |
| `septentrio_preprocessor.h` | Created | 127 | Class declaration |
| `septentrio_preprocessor.cpp` | Created | 350+ | Implementation |
| `irt_gnss_preprocessing_plugins.xml` | Modified | +5 | Plugin registration |
| `septentrio_preprocessing.yaml` | Created | 93 | Configuration |
| `septentrio_preprocessor.launch.py` | Created | 103 | Launch file |

**Total**: 5 new files, 3 modified files, ~760+ lines of new code

---

This completes the implementation details section. Would you like me to continue with Section 3 (Hardware Setup Guide)?
