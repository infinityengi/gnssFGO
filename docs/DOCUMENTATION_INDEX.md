# Septentrio Mosaic-H Integration - Documentation Index

**Package**: `irt_gnss_preprocessing`  
**Integration Date**: December 8, 2025  
**Receiver**: Septentrio Mosaic-H (Dual Antenna Capable)

---

## Quick Navigation

### 🚀 Getting Started
- **[Quick Start Guide](SEPTENTRIO_QUICKSTART.md)** - Get up and running in 5 minutes
- **[Quick Reference Card](SEPTENTRIO_QUICK_REFERENCE.md)** - Command cheat sheet and troubleshooting

### 📚 Complete Documentation
- **[Integration Summary](SEPTENTRIO_INTEGRATION_SUMMARY.md)** - Technical overview and features
- **[Detailed Implementation Guide](SEPTENTRIO_DETAILED_GUIDE.md)** - Step-by-step code walkthrough
- **[Hardware & Testing Guide](SEPTENTRIO_HARDWARE_TESTING_GUIDE.md)** - Physical setup and validation

### 🛠️ Tools & Scripts
- **[Scripts README](scripts/README.md)** - Automation tools documentation

---

## Document Descriptions

### 1. SEPTENTRIO_QUICKSTART.md
**Best for**: First-time users, quick deployment  
**Time to complete**: 5-10 minutes  
**Contents**:
- Prerequisites checklist
- 3-step build process
- Basic launch commands
- Quick verification tests
- Next steps

**Use when**: You want to build and test the integration quickly

---

### 2. SEPTENTRIO_QUICK_REFERENCE.md
**Best for**: Operators, troubleshooting, daily use  
**Format**: Reference card / cheat sheet  
**Contents**:
- Essential commands
- Configuration parameters table
- Topic reference
- PVT mode codes
- Quick diagnostics
- Data recording commands
- Performance monitoring
- Environment-specific presets

**Use when**: You need quick answers or common commands

---

### 3. SEPTENTRIO_INTEGRATION_SUMMARY.md
**Best for**: Technical overview, architecture understanding  
**Length**: ~3 pages  
**Contents**:
- System architecture
- Implementation overview
- Key features
- File structure
- Configuration options
- Known limitations
- Future enhancements

**Use when**: You need to understand the integration design

---

### 4. SEPTENTRIO_DETAILED_GUIDE.md
**Best for**: Developers, integration understanding, debugging  
**Length**: ~70KB, highly detailed  
**Contents**:
- System architecture diagrams
- Step-by-step implementation details
  - Package dependencies
  - Build system configuration
  - Type definitions
  - Class structure
  - Implementation logic
  - Plugin registration
  - Configuration
  - Launch files
  - Build verification
- Code explanations
- Technical deep-dives

**Use when**: 
- Implementing similar integrations
- Understanding code internals
- Debugging issues
- Learning the architecture

---

### 5. SEPTENTRIO_HARDWARE_TESTING_GUIDE.md
**Best for**: Hardware engineers, field deployment, validation  
**Length**: ~80KB, extremely detailed  
**Contents**:
- **Hardware Setup** (Section 3)
  - Equipment requirements
  - Physical connections
  - Antenna installation
  - Power setup
  - Communication configuration
  - Receiver configuration
  - Dual antenna setup
  
- **Software Configuration** (Section 4)
  - Driver configuration
  - Preprocessing tuning
  - System integration
  
- **Verification & Testing** (Section 5)
  - Driver verification tests
  - Preprocessing verification
  - Static position test (with Python script)
  - Dynamic position test
  
- **Dual Antenna Testing** (Section 6)
  - Enable dual antenna mode
  - Baseline verification
  - Heading accuracy tests
  - Dynamic heading test
  
- **Tuning & Optimization** (Section 7)
  - Parameter tuning guide
  - Performance optimization
  - Environment-specific tuning
  
- **Troubleshooting** (Section 8)
  - Common issues and solutions
  - Data quality checks
  - Debug tools

**Use when**:
- Deploying to vehicle
- Setting up antennas
- Testing in field
- Calibrating system
- Troubleshooting hardware issues

---

## Tools & Scripts

### calibration_procedure.py
**Purpose**: Interactive calibration assistant  
**Duration**: 2-17 minutes (depending on procedures selected)  
**Features**:
- Static position calibration (10 min)
- Dual antenna baseline measurement (5 min)
- Heading offset calibration (2 min)
- Automated data analysis
- Configuration recommendations

**Usage**:
```bash
ros2 run irt_gnss_preprocessing calibration_procedure.py
```

---

### automated_test_suite.sh
**Purpose**: Comprehensive system testing  
**Duration**: ~2 minutes  
**Tests**: 11 test categories, 40+ individual tests  
**Features**:
- Environment validation
- Package verification
- Configuration checks
- Live data quality testing
- Performance benchmarks
- Detailed reporting

**Usage**:
```bash
./scripts/automated_test_suite.sh
```

---

### trajectory_visualizer.py
**Purpose**: Real-time trajectory visualization  
**Features**:
- 2D/3D trajectory plots
- Velocity profiles
- Quality metrics
- Heading visualization
- Distance statistics

**Usage**:
```bash
# Basic visualization
ros2 run irt_gnss_preprocessing trajectory_visualizer.py

# 3D with heading
ros2 run irt_gnss_preprocessing trajectory_visualizer.py --3d --heading
```

---

## Reading Order Recommendations

### For First-Time Users:
1. **SEPTENTRIO_QUICKSTART.md** - Get system running
2. **SEPTENTRIO_QUICK_REFERENCE.md** - Learn essential commands
3. **SEPTENTRIO_HARDWARE_TESTING_GUIDE.md** (Section 5) - Verify installation

### For Developers:
1. **SEPTENTRIO_INTEGRATION_SUMMARY.md** - Understand architecture
2. **SEPTENTRIO_DETAILED_GUIDE.md** - Study implementation
3. **scripts/README.md** - Learn automation tools

### For Hardware Engineers:
1. **SEPTENTRIO_HARDWARE_TESTING_GUIDE.md** (Section 3) - Setup hardware
2. **SEPTENTRIO_QUICK_REFERENCE.md** - Learn commands
3. **scripts/calibration_procedure.py** - Calibrate system

### For Integration/Adaptation:
1. **SEPTENTRIO_DETAILED_GUIDE.md** - Full implementation details
2. **SEPTENTRIO_INTEGRATION_SUMMARY.md** - Architecture patterns
3. Review source code in `src/impl/` and `include/irt_gnss_preprocessing/impl/`

---

## File Locations

```
irt_gnss_preprocessing/
├── DOCUMENTATION_INDEX.md                    ← This file
├── SEPTENTRIO_QUICKSTART.md                 ← Start here
├── SEPTENTRIO_QUICK_REFERENCE.md            ← Reference card
├── SEPTENTRIO_INTEGRATION_SUMMARY.md        ← Technical summary
├── SEPTENTRIO_DETAILED_GUIDE.md             ← Implementation details
├── SEPTENTRIO_HARDWARE_TESTING_GUIDE.md     ← Hardware & testing
│
├── scripts/
│   ├── README.md                            ← Scripts documentation
│   ├── calibration_procedure.py            ← Calibration tool
│   ├── automated_test_suite.sh             ← Test suite
│   └── trajectory_visualizer.py            ← Visualization tool
│
├── src/impl/
│   └── septentrio_preprocessor.cpp         ← Implementation
│
├── include/irt_gnss_preprocessing/impl/
│   ├── septentrio_preprocessor.h           ← Class header
│   └── septentrio_types.h                  ← Type definitions
│
├── config/
│   └── septentrio_preprocessing.yaml       ← Configuration
│
└── launch/
    └── septentrio_preprocessor.launch.py   ← Launch file
```

---

## Document Statistics

| Document | Size | Lines | Focus Area |
|----------|------|-------|------------|
| QUICKSTART | 4 KB | ~100 | Getting started |
| QUICK_REFERENCE | 10 KB | ~300 | Command reference |
| INTEGRATION_SUMMARY | 15 KB | ~400 | Architecture |
| DETAILED_GUIDE | 69 KB | ~1900 | Implementation |
| HARDWARE_TESTING_GUIDE | 78 KB | ~2100 | Hardware & testing |
| **Total Documentation** | **~176 KB** | **~4800 lines** | **Complete coverage** |

---

## Integration Features Summary

### ✅ Implemented
- Plugin-based architecture (dynamic loading)
- Single antenna positioning (RTK/PPP/Standalone)
- Dual antenna support (conditional compilation)
- Message synchronization (ApproximateTime policy)
- Raw measurement conversion (pseudorange, carrier phase, Doppler)
- PVT solution conversion (position, velocity, time, clock)
- Covariance propagation
- Quality filtering (CN0, elevation, mode)
- Circular buffer data storage
- Configuration via YAML
- Launch file with remapping
- Complete documentation
- Calibration tools
- Automated testing
- Visualization tools

### 🔧 Configuration Options
- Signal selection (GPS L1/L2/L5, Galileo E1/E5a/E5b/E6, BeiDou, GLONASS)
- Quality thresholds (min CN0, elevation)
- RTK settings (max age, mode filtering)
- Dual antenna parameters (baseline, variance)
- Preprocessing algorithms (cycle slip, smoothing, outlier rejection)

### 📊 Tested Scenarios
- Static position (RTK fixed)
- Dynamic trajectory
- Dual antenna heading
- Multi-constellation
- Urban/forest/open sky

---

## Quick Links

### Configuration Files
- Main config: `config/septentrio_preprocessing.yaml`
- Launch: `launch/septentrio_preprocessor.launch.py`
- Plugin XML: `irt_gnss_preprocessing_plugins.xml`

### Source Code
- Implementation: `src/impl/septentrio_preprocessor.cpp`
- Header: `include/irt_gnss_preprocessing/impl/septentrio_preprocessor.h`
- Types: `include/irt_gnss_preprocessing/impl/septentrio_types.h`

### Build Files
- CMake: `CMakeLists.txt`
- Package: `package.xml`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-08 | Initial integration complete |
| | | - All 9 implementation steps |
| | | - Complete documentation |
| | | - Testing and calibration tools |
| | | - Visualization utilities |

---

## Support & Contact

For issues or questions:
1. Check **SEPTENTRIO_QUICK_REFERENCE.md** for quick troubleshooting
2. Run **automated_test_suite.sh** to diagnose issues
3. Review **SEPTENTRIO_HARDWARE_TESTING_GUIDE.md** Section 8 (Troubleshooting)
4. Examine detailed implementation in **SEPTENTRIO_DETAILED_GUIDE.md**

---

## Next Steps

After reading the documentation:

1. **Build the system**:
   ```bash
   cd /workspace/fgo_ws
   colcon build --packages-select septentrio_gnss_driver irt_gnss_preprocessing
   source install/setup.bash
   ```

2. **Run automated tests**:
   ```bash
   ./src/gnssFGO/irt_gnss_preprocessing/irt_gnss_preprocessing/scripts/automated_test_suite.sh
   ```

3. **Launch with hardware**:
   ```bash
   ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py
   ```

4. **Calibrate system**:
   ```bash
   ros2 run irt_gnss_preprocessing calibration_procedure.py
   ```

5. **Visualize trajectory**:
   ```bash
   ros2 run irt_gnss_preprocessing trajectory_visualizer.py --3d --heading
   ```

---

*Happy integrating! 🚀*

*Last Updated: December 8, 2025*
