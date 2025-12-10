# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure with CHANGELOG.md, README.md, and .gitignore
- Git repository initialized locally
- Remote repository connected to RWTH GitLab
- Project-specific README with proper naming and structure
- gnssFGO repository added as Git submodule with all nested submodules
- `driver_modification` folder created inside `gnssFGO/irt_gnss_preprocessing/`
- Two driver repositories added as submodules:
  - `novatel_oem7_driver` from rwth-irt
  - `septentrio_gnss_driver` from infinityengi
- CONTRIBUTING.md with detailed workflow guidelines
- Docker configuration improvements:
  - Updated `compose.yaml` with serial device mappings (/dev/ttyACM0, /dev/ttyACM1)
  - Enabled host network mode for internet access
  - Configured TTY for interactive terminal access
  - X11 forwarding for GUI support
  - GPU support (NVIDIA)
- Created `run.sh` script for smart container lifecycle management
- Docker image rebuilt (no cache) with memory-friendly settings:
  - Limited parallelism for mapviz/gtsam/NumCpp builds
  - Cleaned build artifacts during image build
  - Fresh compose up from rebuilt image
- Host build stability improvements:
  - Enabled additional 8GB swapfile for heavy builds (total swap now 12GB)
  - Container started with updated image via docker compose
- Snapshot guidance and backup:
  - Documented snapshot usage in `docker/SNAPSHOT.md`
  - Saved running container as image `gnssfgo:built` and exported `/home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built.tar`
- Septentrio MODIAC H hardware integration verified:
  - USB connectivity confirmed (Vendor ID: 152a, Product ID: 85c0)
  - Serial ports mapped to `/dev/ttyACM0` and `/dev/ttyACM1`
  - Ethernet interface `enx1a3202991545` active and functional
  - Web interface accessible at `http://192.168.3.1/`
- Created `septentrio_driver_setup_test.md` with:
  - Hardware connectivity verification guide
  - Serial port configuration and testing procedures
  - Network interface setup instructions
  - Web interface and API testing methods
  - Troubleshooting documentation
- Full workspace build (Release, Ninja) completed with novatel_oem7_driver excluded by design; all other packages built successfully and summarized in `BUILD_SUMMARY.md`

### Changed
- README updated to reflect actual project name: "GNSS FGO Preprocessing Module - Septentrio Driver"
- Merged with remote repository and resolved conflicts
- `gnssFGO/docker/compose.yaml` enhanced with serial ports and network configuration
- CHANGELOG.md updated with Septentrio hardware integration details

### Deprecated

### Removed

### Fixed

### Security

## [0.1.0] - 2025-12-10

### Added
- Project initialization
- Changelog file created
