# Plan: Septentrio Mosaic-H Integration into irt_gnss_preprocessing

Based on comprehensive analysis of the Septentrio driver and existing NovAtel OEM7 preprocessor implementation, here is a detailed step-by-step integration plan:

---

## TL;DR

Integrate Septentrio Mosaic-H receiver support into `irt_gnss_preprocessing` by creating a new `SeptentrioPreProcessor` plugin class similar to the existing `NovatelOEM7PreProcessor`. The Septentrio driver provides MeasEpoch (raw measurements) and PVTGeodetic (solutions) messages that directly map to NovAtel's RANGE and BESTPOS. **Critical limitation**: No ephemeris messages available - must use external ephemeris sources (IGS, BRDC files) or rely on receiver-computed satellite positions.

---

## Prerequisites & Dependencies

### 1. Build Septentrio Driver
```bash
cd /workspace/fgo_ws
colcon build --packages-select septentrio_gnss_driver
source install/setup.bash
```

### 2. Verify Message Generation
```bash
ros2 interface list | grep septentrio
# Should show: septentrio_gnss_driver/msg/MeasEpoch, PVTGeodetic, etc.
```

### 3. Check for Missing Dependencies
```bash
cd /workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing
grep -r "septentrio" . # Should return nothing initially
```

---

## Implementation Steps

### Step 1: Update irt_gnss_preprocessing Dependencies

#### 1.1 Modify `package.xml`

Add Septentrio driver dependency:

```xml
<!-- Location: /workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/package.xml -->

<!-- After line with novatel_oem7_msgs -->
<depend>septentrio_gnss_driver</depend>
```

#### 1.2 Modify `CMakeLists.txt`

Add to find_package section (around line 19):

```cmake
find_package(septentrio_gnss_driver REQUIRED)
```

Add to AMENT_DEPENDENCIES (around line 52):

```cmake
set(AMENT_DEPENDENCIES  
    "rclcpp"
    # ... existing dependencies
    "septentrio_gnss_driver"
)
```

---

### Step 2: Create Septentrio Type Definitions

#### 2.1 Create `septentrio_types.h`

**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/include/irt_gnss_preprocessing/impl/septentrio_types.h`

Define Septentrio-specific structures:

```cpp
#ifndef IRT_GNSS_PREPROCESSING_SEPTENTRIO_TYPES_H
#define IRT_GNSS_PREPROCESSING_SEPTENTRIO_TYPES_H

#include <cstdio>

namespace irt_gnss_preprocessing::Septentrio
{
    // PVT Mode mapping (from PVTGeodetic.mode)
    const unsigned int PVT_MODE_NO_SOLUTION = 0;
    const unsigned int PVT_MODE_STANDALONE = 1;
    const unsigned int PVT_MODE_DIFFERENTIAL = 2;
    const unsigned int PVT_MODE_FIXED = 3;
    const unsigned int PVT_MODE_RTK_FIXED = 4;
    const unsigned int PVT_MODE_RTK_FLOAT = 5;
    const unsigned int PVT_MODE_SBAS_AIDED = 6;
    const unsigned int PVT_MODE_MOVING_BASE_RTK_FIXED = 7;
    const unsigned int PVT_MODE_MOVING_BASE_RTK_FLOAT = 8;
    const unsigned int PVT_MODE_PPP = 10;

    // Error codes (from PVTGeodetic.error)
    const unsigned int PVT_ERROR_NONE = 0;
    const unsigned int PVT_ERROR_NOT_ENOUGH_MEAS = 1;
    const unsigned int PVT_ERROR_NOT_ENOUGH_EPHEM = 2;
    const unsigned int PVT_ERROR_DOP_TOO_LARGE = 3;
    const unsigned int PVT_ERROR_SUM_SQ_RESIDUALS_TOO_LARGE = 4;
    const unsigned int PVT_ERROR_NO_CONVERGENCE = 5;
    const unsigned int PVT_ERROR_NOT_ENOUGH_MEAS_AFTER_OUTLIER_REJECTION = 6;

    inline std::string getPVTModeString(uint8_t mode)
    {
      switch (mode) {
        case 0: return "No Solution";
        case 1: return "Stand-Alone";
        case 2: return "Differential";
        case 3: return "Fixed Location";
        case 4: return "RTK Fixed";
        case 5: return "RTK Float";
        case 6: return "SBAS-Aided";
        case 7: return "Moving-Base RTK Fixed";
        case 8: return "Moving-Base RTK Float";
        case 10: return "PPP";
        default: return "Unknown";
      }
    }
}

#endif //IRT_GNSS_PREPROCESSING_SEPTENTRIO_TYPES_H
```

---

### Step 3: Create Septentrio Preprocessor Header

#### 3.1 Create `septentrio_preprocessor.h`

**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/include/irt_gnss_preprocessing/impl/septentrio_preprocessor.h`

Structure similar to `novatel_oem7_preprocessor.h`:

```cpp
#ifndef IRT_GNSS_PREPROCESSING_SEPTENTRIO_PREPROCESSOR_H
#define IRT_GNSS_PREPROCESSING_SEPTENTRIO_PREPROCESSOR_H

#pragma once

#include <rclcpp/rclcpp.hpp>
#include <message_filters/sync_policies/approximate_time.h>
#include <message_filters/subscriber.h>

#include "gnss_preprocessor.h"
#include "septentrio_types.h"

// Septentrio message includes
#include <septentrio_gnss_driver/msg/meas_epoch.hpp>
#include <septentrio_gnss_driver/msg/pvt_geodetic.hpp>
#include <septentrio_gnss_driver/msg/pvt_cartesian.hpp>
#include <septentrio_gnss_driver/msg/pos_cov_geodetic.hpp>
#include <septentrio_gnss_driver/msg/vel_cov_geodetic.hpp>
#include <septentrio_gnss_driver/msg/receiver_time.hpp>
#include <septentrio_gnss_driver/msg/att_euler.hpp>
#include <septentrio_gnss_driver/msg/att_cov_euler.hpp>
#include <septentrio_gnss_driver/msg/base_vector_geod.hpp>

namespace irt_gnss_preprocessing {

class SeptentrioPreProcessor : public GNSSPreprocessor {
private:
    // Message synchronization policy for solution data
    typedef message_filters::sync_policies::ApproximateTime<
        septentrio_gnss_driver::msg::PVTGeodetic,
        septentrio_gnss_driver::msg::PosCovGeodetic,
        septentrio_gnss_driver::msg::VelCovGeodetic> SeptentrioSolSyncPolicy;

    // Subscribers
    message_filters::Subscriber<septentrio_gnss_driver::msg::PVTGeodetic> pvt_sub_;
    message_filters::Subscriber<septentrio_gnss_driver::msg::PosCovGeodetic> poscov_sub_;
    message_filters::Subscriber<septentrio_gnss_driver::msg::VelCovGeodetic> velcov_sub_;
    std::unique_ptr<message_filters::Synchronizer<SeptentrioSolSyncPolicy>> sol_sync_;

    rclcpp::Subscription<septentrio_gnss_driver::msg::MeasEpoch>::SharedPtr measepoch_main_sub_;
    rclcpp::Subscription<septentrio_gnss_driver::msg::ReceiverTime>::SharedPtr receiver_time_sub_;
    
    // Dual antenna (if enabled)
#if USE_DUAL_ANTENNA
    rclcpp::Subscription<septentrio_gnss_driver::msg::MeasEpoch>::SharedPtr measepoch_aux_sub_;
    rclcpp::Subscription<septentrio_gnss_driver::msg::AttEuler>::SharedPtr attitude_sub_;
    rclcpp::Subscription<septentrio_gnss_driver::msg::BaseVectorGeod>::SharedPtr baseline_sub_;
#endif

    // Circular buffers
    CircularDataBuffer<septentrio_gnss_driver::msg::MeasEpoch> measepoch_main_buffer_;
    CircularDataBuffer<septentrio_gnss_driver::msg::PVTGeodetic> pvt_buffer_;
    CircularDataBuffer<septentrio_gnss_driver::msg::ReceiverTime> receiver_time_buffer_;
    
#if USE_DUAL_ANTENNA
    CircularDataBuffer<septentrio_gnss_driver::msg::MeasEpoch> measepoch_aux_buffer_;
    CircularDataBuffer<septentrio_gnss_driver::msg::AttEuler> attitude_buffer_;
    CircularDataBuffer<septentrio_gnss_driver::msg::BaseVectorGeod> baseline_buffer_;
#endif

    // Callback functions
    void onMeasEpochMainCb(const septentrio_gnss_driver::msg::MeasEpoch::ConstSharedPtr msg);
    void onSolutionMsgCb(
        const septentrio_gnss_driver::msg::PVTGeodetic::ConstSharedPtr pvt,
        const septentrio_gnss_driver::msg::PosCovGeodetic::ConstSharedPtr poscov,
        const septentrio_gnss_driver::msg::VelCovGeodetic::ConstSharedPtr velcov);
    void onReceiverTimeCb(const septentrio_gnss_driver::msg::ReceiverTime::ConstSharedPtr msg);

#if USE_DUAL_ANTENNA
    void onMeasEpochAuxCb(const septentrio_gnss_driver::msg::MeasEpoch::ConstSharedPtr msg);
    void onAttitudeCb(const septentrio_gnss_driver::msg::AttEuler::ConstSharedPtr msg);
    void onBaselineCb(const septentrio_gnss_driver::msg::BaseVectorGeod::ConstSharedPtr msg);
#endif

    // Conversion functions
    static gnssraw_measurement_t convertMeasEpochToRaw(
        const septentrio_gnss_driver::msg::MeasEpoch& msg);
    static gnssraw_pvt_geodetic_t convertPVTGeodetic(
        const septentrio_gnss_driver::msg::PVTGeodetic& msg);

public:
    void initialize(rclcpp::Node& node, const std::string& receiver_type) override;
};

} // namespace irt_gnss_preprocessing

#include <pluginlib/class_list_macros.hpp>
PLUGINLIB_EXPORT_CLASS(irt_gnss_preprocessing::SeptentrioPreProcessor, 
                       irt_gnss_preprocessing::GNSSPreprocessor)

#endif // IRT_GNSS_PREPROCESSING_SEPTENTRIO_PREPROCESSOR_H
```

---

### Step 4: Implement Septentrio Preprocessor

#### 4.1 Create `septentrio_preprocessor.cpp`

**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/src/impl/septentrio_preprocessor.cpp`

Key implementation points:

1. **Initialize subscriptions** to Septentrio topics
2. **Convert MeasEpoch → gnssraw_measurement_t** (similar to RANGE conversion)
3. **Convert PVTGeodetic → gnssraw_pvt_geodetic_t** (similar to BESTPOS conversion)
4. **Handle time synchronization** using ReceiverTime messages
5. **Process dual antenna** data if enabled

**Critical conversion details:**

##### MeasEpoch Parsing:
- Loop through `type1` channels (MeasEpochChannelType1)
- Extract: sv_id, pseudorange (code_lsb + misc), carrier phase (carrier_lsb + carrier_msb), doppler, cn0, lock_time
- Handle multi-frequency observations (type2 sub-blocks)
- Convert units: CN0 (0.25 dB-Hz → dB-Hz), lock_time, pseudorange (LSB + MSB)

##### PVT Conversion:
- Map Septentrio `mode` → internal solution type codes
- Convert latitude/longitude from radians
- Extract height, velocities, clock bias/drift
- Copy nr_sv, accuracy estimates

---

### Step 5: Update Plugin Registry

#### 5.1 Modify `irt_gnss_preprocessing_plugins.xml`

Add Septentrio plugin after Ublox entry:

```xml
<!-- Location: around line 50 -->
<class name="SeptentrioPreProcessor" 
       type="irt_gnss_preprocessing::SeptentrioPreProcessor" 
       base_class_type="irt_gnss_preprocessing::GNSSPreprocessor">
    <description>
        GNSS Preprocessor for Septentrio Mosaic/AsteRx receivers
    </description>
</class>
```

---

### Step 6: Update Build System

#### 6.1 Update CMakeLists.txt

Add Septentrio preprocessor to library sources (around line 65):

```cmake
add_library(${PROJECT_NAME} SHARED
        src/gnss_utils.cpp
        src/impl/novatel_oem7_preprocessor.cpp
        src/impl/ublox_f9p_preprocessor.cpp
        src/impl/septentrio_preprocessor.cpp  # ADD THIS LINE
)
```

---

### Step 7: Create Configuration File

#### 7.1 Create `septentrio_preprocessing.yaml`

**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/config/septentrio_preprocessing.yaml`

```yaml
---
/irt_gnss_preprocessing/irt_gnss_preprocessing:
    ros__parameters:
        use_sim_time: true
        GNSSPreprocessor:
            gnss_receiver_handler:           'Septentrio'  # Changed from NovatelOEM7
            NLOSCSVFilePath:                 ""
            publish_gnss_obs:                true
            user_estimation_from_topic:      true
            default_buffer_size:             5
            enable_gnss_merge:               false
            enable_dual_antenna_dd:          true  # If dual antenna Mosaic-H
            enable_rtcm_dd:                  true
            print_info_duration:             1.0
            msg_lower_bound:                 50000000
            range_sync_queue_size:           10
            solution_sync_queue_size:        10
            antenna_heading_offset:          0.0  # Adjust based on antenna setup

        # Rest remains same as gnss_preprocessing.yaml
        CommonGNSSParameters:
            enable_galileo_timebase:         false
            enable_differential_correction:  true
            enable_tropospheric_correction:  false
            enable_ionospheric_correction:   false
            enable_SatPosVel_calculation:    true  # CRITICAL: Set to false if no ephemeris
            enable_WL_correction:            false
            elevation_mask:                  15.0
            ggto_sync_mode:                  0
            use_mode_switch_logic:           false

        CommonGPSParameters:
            enable: true
            enable_l1: true
            enable_l2: false

        CommonGalileoParameters:
            enable: true
            enable_e1: true
            enable_e5: false
            enable_e5a: false
            enable_e5b: false

        CommonGateParameters:
            enable: false
            prn_flags: [ 0., 0., 0., 0., 0., 0., 0., 0., 0. ]

        DDRTCMGNSSParameters:
            enable_galileo_timebase: false
            enable_differential_correction: false
            enable_tropospheric_correction: false
            enable_ionospheric_correction: false
            enable_SatPosVel_calculation: true
            enable_WL_correction: false
            elevation_mask: 15.
            ggto_sync_mode: 1
            use_mode_switch_logic: false

        DDRTCMGPSParameters:
            enable: true
            enable_l1: true
            enable_l2: false

        DDRTCMGalileoParameters:
            enable: false
            enable_e1: false
            enable_e5: false
            enable_e5a: false
            enable_e5b: false

        DDRTCMGateParameters:
            enable: false
            prn_flags: [ 0., 0., 0., 0., 0., 0., 0., 0., 0. ]

        DDDualAntennaGNSSParameters:
            enable_galileo_timebase: false
            enable_differential_correction: false
            enable_tropospheric_correction: false
            enable_ionospheric_correction: false
            enable_SatPosVel_calculation: true
            enable_WL_correction: false
            elevation_mask: 15.
            ggto_sync_mode: 1
            use_mode_switch_logic: false

        DDDualAntennaGPSParameters:
            enable: true
            enable_l1: true
            enable_l2: false

        DDDualAntennaGalileoParameters:
            enable: false
            enable_e1: false
            enable_e5: false
            enable_e5a: false
            enable_e5b: false

        DDDualAntennaGateParameters:
            enable: false
            prn_flags: [ 0., 0., 0., 0., 0., 0., 0., 0., 0. ]
```

---

### Step 8: Handle Ephemeris Data Challenge

**Critical Issue**: Septentrio driver does NOT provide ephemeris messages.

#### Solutions (implement ONE of these):

##### Option A: External Ephemeris (Recommended)

1. Download IGS/BRDC ephemeris files
2. Parse RINEX navigation files
3. Load into ephemeris buffers before processing
4. Set `enable_SatPosVel_calculation: false` in config

##### Option B: Use Receiver-Computed Satellite Positions

1. Request `ChannelStatus` block from receiver (contains satellite positions if available)
2. Modify Septentrio driver to expose this data
3. Parse satellite ECEF positions directly

##### Option C: Simplified Processing (Recommended for Initial Testing)

1. Use only PVT solutions (loosely coupled mode)
2. Skip raw pseudorange/carrier phase processing
3. Set `enable_SatPosVel_calculation: false`

**Recommendation**: Start with Option C for initial testing, then implement Option A for full functionality.

---

### Step 9: Create Launch File

#### 9.1 Create `septentrio_preprocessor.launch.py`

**Location**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/launch/septentrio_preprocessor.launch.py`

Copy `gnss_preprocessor.launch.py` and modify:

```python
#!/usr/bin/env python3
# Copyright 2021 Institute of Automatic Control RWTH Aachen University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Haoming Zhang (h.zhang@irt.rwth-aachen.de)
#

import os
import yaml
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def get_params(p):
    with open(p, 'r') as f:
        print(yaml.safe_load(f))
        return yaml.safe_load(f)


def generate_launch_description():
    logger = LaunchConfiguration("log_level")
    config_common_path = LaunchConfiguration('config_common_path')
    default_config_common = os.path.join(
        get_package_share_directory('irt_gnss_preprocessing'),
        'config',
        'septentrio_preprocessing.yaml'  # Changed filename
    )

    declare_config_common_path_cmd = DeclareLaunchArgument(
        'config_common_path',
        default_value=default_config_common,
        description='GNSS_Parameters')

    node_gnss_preprocessing = Node(
        package='irt_gnss_preprocessing',
        executable='node_gnss_preprocessing',
        namespace="irt_gnss_preprocessing",
        name="irt_gnss_preprocessing",
        output='screen',
        emulate_tty=True,
        parameters=[
            config_common_path,
        ],
        remappings=[
            ('/user_estimation', '/deutschland/user_estimation'),
        ]
    )
    
    ld = LaunchDescription()
    ld.add_action(declare_config_common_path_cmd)
    ld.add_action(node_gnss_preprocessing)
    ld.add_action(DeclareLaunchArgument(
        "log_level",
        default_value=["error"],
        description="Logging level"))

    return ld
```

---

## Further Considerations

### 1. Dual Antenna Mosaic-H Configuration

**Question**: Do you have dual antenna Mosaic-H (e.g., mosaic-H with two antennas)?

**If YES**:
- Enable `enable_dual_antenna_dd: true`
- Subscribe to `/atteuler` and `/basevectorgeod`
- Implement BaseVectorGeod → baseline conversion
- Calculate heading from attitude message

**If NO**:
- Set `enable_dual_antenna_dd: false`
- Skip dual antenna callbacks

---

### 2. RTCM Corrections

**Question**: Will you use NTRIP/RTCM corrections?

**Configuration in Septentrio driver** (`rover.yaml`):
```yaml
rtk_settings:
  ntrip_1:
    caster: "your.ntrip.caster"
    caster_port: 2101
    mountpoint: "YOUR_MOUNT"
    username: "user"
    password: "pass"
    send_gga: "auto"
```

Preprocessing will automatically handle RTK solutions from PVTGeodetic (mode = 4 or 5).

---

### 3. Time Synchronization

**Options**:
- Set `use_gnss_time: true` in Septentrio driver config
- Use `ReceiverTime` message for leap second info
- Synchronize GPS/Galileo time using receiver clock offset

---

### 4. Message Rate Configuration

**Critical**: Ensure Septentrio publishes at sufficient rate

In Septentrio driver config:
```yaml
polling_period:
  pvt: 100       # 10 Hz (100 ms period)
  rest: 500      # 2 Hz
```

For preprocessing, recommend:
- PVT: 5-10 Hz
- MeasEpoch: 1-5 Hz (raw measurements)

---

### 5. Testing Strategy

#### Phase 1: Driver Verification
```bash
# Terminal 1: Launch Septentrio driver
ros2 launch septentrio_gnss_driver rover.launch.py

# Terminal 2: Check topics
ros2 topic list | grep septentrio
ros2 topic echo /pvtgeodetic --once
ros2 topic echo /measepoch --once

# Terminal 3: Monitor data rate
ros2 topic hz /pvtgeodetic
ros2 topic hz /measepoch
```

#### Phase 2: Preprocessor Testing
```bash
# Terminal 1: Launch driver
ros2 launch septentrio_gnss_driver rover.launch.py

# Terminal 2: Launch preprocessor
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py

# Terminal 3: Check preprocessed output
ros2 topic echo /irt_gnss_preprocessing/gnss_obs_preprocessed --once
ros2 topic hz /irt_gnss_preprocessing/gnss_obs_preprocessed

# Terminal 4: Check for errors
ros2 node info /irt_gnss_preprocessing/irt_gnss_preprocessing
```

#### Phase 3: Integration with FGO
```bash
# Terminal 1: Driver
ros2 launch septentrio_gnss_driver rover.launch.py

# Terminal 2: Preprocessor
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py

# Terminal 3: Online FGO (loosely coupled first)
ros2 launch online_fgo aachen_lc.launch.py

# Terminal 4: Visualization
rviz2 -d /workspace/fgo_ws/src/gnssFGO/LIOSAM/config/rviz2.rviz
```

---

### 6. Parameters to Tune

#### Preprocessing Parameters:
- `elevation_mask` (10-20° for urban, 5° for open sky)
- `enable_ionospheric_correction` (only if using single-frequency)
- `enable_tropospheric_correction` (for high-precision < 1m)
- `antenna_heading_offset` (measure physical antenna orientation)

#### Septentrio Driver Parameters:
- `use_ros_axis_orientation: true` (converts NED → ENU for ROS)
- `datum: "ETRS89"` or `"WGS84"` (match your region)
- `leap_seconds: 18` (update as needed)
- `polling_period.pvt` (100-200 ms for 5-10 Hz)

---

### 7. Debugging Tools

#### Check message conversion:
```bash
# Compare raw Septentrio vs preprocessed
ros2 topic echo /pvtgeodetic > sept_raw.txt
ros2 topic echo /irt_gnss_preprocessing/pvt_geodetic > sept_processed.txt
diff sept_raw.txt sept_processed.txt
```

#### Monitor preprocessing performance:
```bash
# Check for dropped messages
ros2 topic hz /measepoch
ros2 topic hz /irt_gnss_preprocessing/gnss_obs_preprocessed

# Check latency
ros2 topic echo /irt_gnss_preprocessing/gnss_obs_preprocessed | grep -E "(header|timestamp)"
```

#### Verify plugin loading:
```bash
# Check if Septentrio plugin is registered
ros2 plugin list | grep -i gnss
ros2 run irt_gnss_preprocessing node_gnss_preprocessing --ros-args -p GNSSPreprocessor.gnss_receiver_handler:=Septentrio
```

---

## Summary Checklist

### Before Starting:
- [ ] Septentrio driver built and tested standalone
- [ ] Receiver connected and publishing messages
- [ ] Understand ephemeris limitation (no ephemeris messages available)

### Implementation:
- [ ] Update `package.xml` with septentrio dependency
- [ ] Update `CMakeLists.txt` with septentrio package
- [ ] Create `septentrio_types.h`
- [ ] Create `septentrio_preprocessor.h`
- [ ] Implement `septentrio_preprocessor.cpp`
- [ ] Update `irt_gnss_preprocessing_plugins.xml`
- [ ] Add source file to `CMakeLists.txt`
- [ ] Create `septentrio_preprocessing.yaml` config
- [ ] Create `septentrio_preprocessor.launch.py`

### Testing:
- [ ] Build: `colcon build --packages-select irt_gnss_preprocessing`
- [ ] Test plugin loading
- [ ] Test with live receiver data
- [ ] Verify preprocessed message generation
- [ ] Test dual antenna (if applicable)
- [ ] Test RTCM integration (if applicable)
- [ ] Integrate with online_fgo loosely coupled
- [ ] Integrate with online_fgo tightly coupled (if ephemeris available)

### Documentation:
- [ ] Update main README.md with Septentrio support
- [ ] Document ephemeris workaround
- [ ] Add Septentrio-specific configuration examples
- [ ] Update preprocess_irt.md guide

---

## Expected Outcome

After completing this integration:

1. **Functional**: Septentrio Mosaic-H fully supported in preprocessing pipeline
2. **Plugin System**: Seamlessly switch between NovAtel/Ublox/Septentrio via config parameter
3. **Message Flow**: `MeasEpoch` → preprocessing → `GNSSObsPreProcessed` → online_fgo
4. **Dual Antenna**: Heading/attitude available if dual antenna configured
5. **RTK Support**: Differential corrections automatically handled

**Limitation**: External ephemeris source required for full tightly-coupled processing or set `enable_SatPosVel_calculation: false` to use loosely-coupled mode only.

---

## Key Message Mappings

| NovAtel OEM7 | Septentrio SBF | Notes |
|--------------|----------------|-------|
| RANGE | MeasEpoch (4027) | Raw pseudorange, carrier phase, Doppler |
| BESTPOS | PVTGeodetic (4007) | Position, velocity, time solution |
| BESTVEL | PVTGeodetic + VelCovGeodetic | Velocity in PVT, covariance separate |
| DUALANTENNAHEADING | AttEuler (5938) + BaseVectorGeod (4028) | Attitude + baseline |
| GPSEPHEMERIS | ❌ Not Available | Must use external source |
| GALEPHEMERIS | ❌ Not Available | Must use external source |

---

## Additional Resources

- **Septentrio Driver**: `/workspace/fgo_ws/src/gnssFGO/septentrio_gnss_driver/`
- **NovAtel Preprocessor Reference**: `/workspace/fgo_ws/src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/src/impl/novatel_oem7_preprocessor.cpp`
- **Septentrio SBF Reference Manual**: Available from Septentrio website
- **IGS Ephemeris**: https://cddis.nasa.gov/archive/gnss/data/daily/
- **BRDC Ephemeris**: Available from IGS data centers
