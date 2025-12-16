# GNSS Ephemeris Provider

External ephemeris provider for Septentrio GNSS preprocessing, downloading broadcast ephemeris from IGS servers.

## Overview

This package provides GNSS navigation data (ephemeris, ionosphere corrections, time system offsets) by downloading and parsing IGS broadcast ephemeris files. It was created to bridge the gap where the Septentrio driver doesn't publish ephemeris data like NovAtel drivers do.

**Purpose**: Provide external ephemeris data to `irt_gnss_preprocessing` for Septentrio receivers.

## Architecture

```
┌─────────────────────────────────────────────┐
│         gnss_ephemeris_provider             │
│                                             │
│  ┌──────────────┐      ┌──────────────┐    │
│  │ BRDC         │──────▶│ RINEX        │    │
│  │ Downloader   │      │ Parser       │    │
│  └──────────────┘      └──────────────┘    │
│         │                     │             │
│         │ Every 2 hours       │             │
│         ▼                     ▼             │
│  ftp://igs.bkg.bund.de   Parse RINEX 3.x   │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │     EphemerisProviderNode            │  │
│  │  - GPS/GAL Ephemeris Array (1 Hz)   │  │
│  │  - GPS/GAL Ionosphere (1 Hz)        │  │
│  │  - GGTO (1 Hz)                       │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
                  │
                  ▼
        ┌────────────────────┐
        │ irt_gnss_          │
        │ preprocessing      │
        │ (Septentrio)       │
        └────────────────────┘
```

## Features

- **Automatic Download**: Fetches IGS broadcast ephemeris every 2 hours
- **Multi-Constellation**: Supports GPS and Galileo
- **RINEX 3.x Parsing**: Handles mixed GNSS navigation files
- **Ephemeris Validation**: Checks age (2hr GPS, 3hr Galileo)
- **Intelligent Caching**: Stores multiple ephemeris per satellite, selects most recent valid
- **Fallback Mode**: Uses cached files if download fails
- **ROS2 Integration**: Publishes standard topic messages

## Topics Published

| Topic | Message Type | Rate | Description |
|-------|--------------|------|-------------|
| `/gnss/gps_ephemeris` | `GPSEphemerisArray` | 1 Hz | GPS broadcast ephemeris for all satellites |
| `/gnss/gal_ephemeris` | `GALEphemerisArray` | 1 Hz | Galileo broadcast ephemeris for all satellites |
| `/gnss/gps_ionosphere` | `GPSIonosphere` | 1 Hz | Klobuchar ionosphere model (α/β) |
| `/gnss/gal_ionosphere` | `GALIonosphere` | 1 Hz | NeQuick ionosphere model |
| `/gnss/ggto` | `GGTO` | 1 Hz | GPS-Galileo Time Offset |

## Message Definitions

### GPSEphemeris
37 fields including:
- Satellite ID, GPS week, TOW
- Clock corrections: `af0`, `af1`, `af2`, `toc`
- Orbital elements: `sqrt_a`, `ecc`, `i0`, `omega0`, `omega`, `m0`
- Perturbations: `crs`, `crc`, `cuc`, `cus`, `cic`, `cis`
- Rates: `delta_n`, `omega_dot`, `idot`
- Health: `health`, `iodc`, `iode`
- Group delay: `tgd`

### GALEphemeris
36 fields including Galileo-specific:
- `iod_nav` (Issue of Data)
- `bgd_e1e5a`, `bgd_e1e5b` (Group delays)
- Health per signal: `e1b_health`, `e5a_health`, `e5b_health`

## Build Instructions

```bash
cd /workspace/fgo_ws
colcon build --packages-select gnss_ephemeris_provider
source install/setup.bash
```

## Usage

### Launch with default parameters:
```bash
ros2 launch gnss_ephemeris_provider ephemeris_provider.launch.py
```

### Launch with custom config:
```bash
ros2 run gnss_ephemeris_provider ephemeris_provider_node \
  --ros-args \
  --params-file /path/to/custom_config.yaml
```

### Monitor topics:
```bash
# List topics
ros2 topic list | grep gnss

# Echo GPS ephemeris
ros2 topic echo /gnss/gps_ephemeris

# Check publish rate
ros2 topic hz /gnss/gps_ephemeris
```

## Configuration

Edit `config/ephemeris_provider.yaml`:

```yaml
/**:
  ros__parameters:
    brdc_update_interval: 7200  # 2 hours
    publish_rate: 1.0           # 1 Hz
    cache_dir: "/tmp/gnss_brdc"
    igs_server: "igs.bkg.bund.de"
```

## Integration with Septentrio Preprocessing

To integrate with `irt_gnss_preprocessing/septentrio_preprocessor.cpp`:

### 1. Add subscribers to header:
```cpp
// In septentrio_preprocessor.h
rclcpp::Subscription<gnss_ephemeris_provider::msg::GPSEphemerisArray>::SharedPtr gps_ephem_sub_;
rclcpp::Subscription<gnss_ephemeris_provider::msg::GALEphemerisArray>::SharedPtr gal_ephem_sub_;
rclcpp::Subscription<gnss_ephemeris_provider::msg::GPSIonosphere>::SharedPtr gps_iono_sub_;
rclcpp::Subscription<gnss_ephemeris_provider::msg::GALIonosphere>::SharedPtr gal_iono_sub_;
rclcpp::Subscription<gnss_ephemeris_provider::msg::GGTO>::SharedPtr ggto_sub_;

void onGPSEphemArrayCb(const gnss_ephemeris_provider::msg::GPSEphemerisArray::SharedPtr msg);
void onGALEphemArrayCb(const gnss_ephemeris_provider::msg::GALEphemerisArray::SharedPtr msg);
void onGPSIonoCb(const gnss_ephemeris_provider::msg::GPSIonosphere::SharedPtr msg);
void onGALIonoCb(const gnss_ephemeris_provider::msg::GALIonosphere::SharedPtr msg);
void onGGTOCb(const gnss_ephemeris_provider::msg::GGTO::SharedPtr msg);
```

### 2. Create subscribers in constructor:
```cpp
gps_ephem_sub_ = this->create_subscription<gnss_ephemeris_provider::msg::GPSEphemerisArray>(
  "/gnss/gps_ephemeris", rclcpp::SensorDataQoS(),
  std::bind(&SeptentrioPreprocessor::onGPSEphemArrayCb, this, std::placeholders::_1));

gal_ephem_sub_ = this->create_subscription<gnss_ephemeris_provider::msg::GALEphemerisArray>(
  "/gnss/gal_ephemeris", rclcpp::SensorDataQoS(),
  std::bind(&SeptentrioPreprocessor::onGALEphemArrayCb, this, std::placeholders::_1));
  
// Similar for ionosphere and GGTO...
```

### 3. Implement callbacks:
```cpp
void SeptentrioPreprocessor::onGPSEphemArrayCb(
  const gnss_ephemeris_provider::msg::GPSEphemerisArray::SharedPtr msg)
{
  for (const auto& eph : msg->ephemeris) {
    gnssraw_gps_nav_t nav;
    nav.svid = eph.svid;
    nav.week = eph.week;
    nav.health = eph.health;
    nav.iodc = eph.iodc;
    nav.iode = eph.iode;
    nav.toe = eph.toe;
    nav.toc = eph.toc;
    nav.tgd = eph.tgd;
    nav.af0 = eph.af0;
    nav.af1 = eph.af1;
    nav.af2 = eph.af2;
    nav.crs = eph.crs;
    nav.delta_n = eph.delta_n;
    nav.m0 = eph.m0;
    nav.cuc = eph.cuc;
    nav.ecc = eph.ecc;
    nav.cus = eph.cus;
    nav.sqrt_a = eph.sqrt_a;
    nav.cic = eph.cic;
    nav.omega0 = eph.omega0;
    nav.cis = eph.cis;
    nav.i0 = eph.i0;
    nav.crc = eph.crc;
    nav.omega = eph.omega;
    nav.omega_dot = eph.omega_dot;
    nav.idot = eph.idot;
    
    gps_nav_ephemeris_buffer_.push_back(nav);
  }
  
  has_ephemeris_ = true;  // Enable preprocessing
}
```

## Dependencies

- **ROS2 Humble**
- **libcurl**: FTP downloads
- **zlib**: Gzip decompression
- **irt_nav_msgs**: Common GNSS message types

## Implementation Details

### BRDC Downloader (`brdc_downloader.cpp`)
- Downloads from `ftp://igs.bkg.bund.de/IGS/BRDC/YYYY/DDD/`
- File format: `BRDC00IGS_R_YYYYDDD0000_01D_MN.rnx.gz`
- 5-minute timeout
- Automatic gzip decompression
- GPS week/DOY calculation

### RINEX Parser (`brdc_parser.cpp`)
- Handles RINEX 3.x format
- Parses 8-line ephemeris records (GPS/Galileo)
- Extracts ionosphere corrections from header
- Multi-ephemeris caching per satellite
- Validity checking based on TOE age

### Ephemeris Provider Node (`ephemeris_provider_node.cpp`)
- Update timer: Downloads BRDC every 2 hours
- Publish timer: Publishes ephemeris at 1 Hz
- Selects valid ephemeris based on current TOW
- Handles download failures gracefully

## Troubleshooting

### No data published
- Check internet connectivity for IGS server
- Verify cache directory is writable: `/tmp/gnss_brdc`
- Check logs: `ros2 topic echo /rosout`

### Download failures
- IGS server may be down or slow
- Try alternative server: `edit igs_server parameter`
- Check cached files: `ls /tmp/gnss_brdc/`

### Empty ephemeris arrays
- RINEX file may not contain data for requested constellation
- Check ephemeris age (>2hr GPS, >3hr Galileo are invalid)
- Verify GPS week/TOW calculation is correct

### Integration issues
- Ensure topic names match: `/gnss/gps_ephemeris`
- Check QoS settings: `SensorDataQoS()` recommended
- Verify message field mapping matches `gnssraw_*_t` structs

## Testing

```bash
# Test download (requires internet)
ros2 run gnss_ephemeris_provider ephemeris_provider_node

# Check published data
ros2 topic echo /gnss/gps_ephemeris --once

# Monitor rates
ros2 topic hz /gnss/gps_ephemeris
ros2 topic hz /gnss/gal_ephemeris

# Inspect messages
ros2 interface show gnss_ephemeris_provider/msg/GPSEphemeris
```

## Future Enhancements

- [ ] GLONASS support (RINEX GLONASS nav)
- [ ] BeiDou support (RINEX BeiDou nav)
- [ ] Precise ephemeris option (IGS SP3 files)
- [ ] Multiple IGS server fallback
- [ ] Automatic leap second updates
- [ ] SBAS augmentation data

## References

- IGS BRDC: https://igs.bkg.bund.de/
- RINEX 3.04: https://files.igs.org/pub/data/format/rinex304.pdf
- Klobuchar model: ICD-GPS-200
- NeQuick model: Galileo ICD

## License

MIT

## Author

Created for Septentrio integration with `irt_gnss_preprocessing`
