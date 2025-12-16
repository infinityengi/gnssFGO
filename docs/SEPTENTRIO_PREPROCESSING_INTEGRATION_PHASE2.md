# Septentrio Preprocessing Integration (Phase 2) - Dec 15, 2025

## Status: IN PROGRESS

## Objective
Wire the 5 live Septentrio SBF nav topics (`/gpsephem`, `/gpsion`, `/galfnavephem`, `/galion`, `/galclock`) into the `irt_gnss_preprocessing` pipeline to produce preprocessed observations for the online FGO system.

## Architecture
```
Septentrio mosaic-H (TCP 192.168.3.1:28784)
  ↓
septentrio_gnss_driver (rover.launch.py)
  ↓ publishes 5 topics
/gpsephem, /gpsion, /galfnavephem, /galion, /galclock
  ↓
[NEW] SeptentrioPreProcessor (ROS2 component)
  ↓ subscribes to 5 topics
  ↓ converts to preprocessing input bus
  ↓
GNSSPreProcessingSingleAntenna (Simulink model)
  ↓
irt_gnss_preprocessing node
  ↓
Preprocessed observations → online_fgo
```

## Implementation Plan

### Step 1: Create Septentrio Preprocessor Header
- File: `irt_gnss_preprocessing/include/irt_gnss_preprocessing/impl/septentrio_sbf_preprocessor.h`
- Model: Copy structure from `novatel_oem7_preprocessor.h`
- Subscriptions: 5 SBF nav topics
- Conversions: Map Septentrio messages to preprocessing input bus

### Step 2: Create Septentrio Preprocessor Implementation
- File: `irt_gnss_preprocessing/src/impl/septentrio_sbf_preprocessor.cpp`
- Implement message callbacks
- Implement Septentrio-to-bus conversion logic
- Reuse existing Simulink models (ConvertOEM7To* templates adapted)

### Step 3: Register Preprocessor in Main Component
- File: `irt_gnss_preprocessing/src/gnss_preprocessor_component.cpp`
- Add Septentrio provider option
- Wire into plugin registry

### Step 4: Update CMakeLists.txt
- Add septentrio_gnss_driver dependency
- Link new preprocessor files

### Step 5: Create Launch File
- File: `irt_gnss_preprocessing/launch/septentrio_preprocessing.launch.py`
- Launch: driver + preprocessor + online_fgo (all-in-one)

### Step 6: Testing
- Live data with Septentrio receiver
- Verify preprocessed observations output

## Current Progress
- ✅ Phase 1 Complete: 5 SBF topics live and publishing
- ⏳ Phase 2 Step 1: Starting header creation

## Next Actions
1. Create `septentrio_sbf_preprocessor.h`
2. Create `septentrio_sbf_preprocessor.cpp`
3. Register in component system
4. Build and test with live data
