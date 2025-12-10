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

### Changed
- README updated to reflect actual project name: "GNSS FGO Preprocessing Module - Septentrio Driver"
- Merged with remote repository and resolved conflicts
- `gnssFGO/docker/compose.yaml` enhanced with serial ports and network configuration

### Deprecated

### Removed

### Fixed

### Security

## [0.1.0] - 2025-12-10

### Added
- Project initialization
- Changelog file created
