# Quick Start Guide: Septentrio Mosaic-H Preprocessing

## Prerequisites
- Septentrio Mosaic-H receiver connected and configured
- ROS2 workspace with `septentrio_gnss_driver` and `irt_gnss_preprocessing` packages built

## Build Instructions

```bash
cd /workspace/fgo_ws

# Build Septentrio driver first (if not already built)
colcon build --packages-select septentrio_gnss_driver

# Build preprocessing package
colcon build --packages-select irt_gnss_preprocessing

# Source the workspace
source install/setup.bash
```

## Running the Preprocessor

### Option 1: Using Launch File (Recommended)

```bash
# Source the workspace
source /workspace/fgo_ws/install/setup.bash

# Launch with default configuration
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py

# Launch with custom configuration
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py \
  config_file:=/path/to/your/config.yaml \
  log_level:=debug
```

### Option 2: Manual Node Startup

```bash
# Source the workspace
source /workspace/fgo_ws/install/setup.bash

# Run the preprocessing node
ros2 run irt_gnss_preprocessing irt_gnss_preprocessing_node --ros-args \
  -p GNSSPreprocessor.receiver_type:=septentrio \
  --params-file install/irt_gnss_preprocessing/share/irt_gnss_preprocessing/config/septentrio_preprocessing.yaml
```

## Configuration

Edit `config/septentrio_preprocessing.yaml` to customize:

### Essential Parameters

```yaml
GNSSPreprocessor:
  receiver_type: "septentrio"
  use_dual_antenna: false  # Set to true for dual antenna setup
  
  # Signal selection (enable signals your receiver tracks)
  use_gps_l1: true
  use_gps_l2: true
  use_gal_e1: true
  use_gal_e5a: true
  
  # Quality thresholds
  min_cn0: 25.0          # Minimum carrier-to-noise ratio (dB-Hz)
  min_elevation: 10.0    # Minimum satellite elevation (degrees)
  
  # RTK settings
  use_rtk: true
  max_age_correction: 30.0  # Maximum correction age (seconds)
```

### Topic Configuration

Ensure these match your Septentrio driver output:

```yaml
Septentrio:
  topic_measepoch: "/measepoch"
  topic_pvtgeodetic: "/pvtgeodetic"
  topic_poscovgeodetic: "/poscovgeodetic"
  topic_velcovgeodetic: "/velcovgeodetic"
```

## Topic Structure

### Input Topics (from Septentrio driver)
- `/septentrio/measepoch` - Raw GNSS measurements
- `/septentrio/pvtgeodetic` - Position/velocity solution
- `/septentrio/poscovgeodetic` - Position covariance
- `/septentrio/velcovgeodetic` - Velocity covariance
- `/septentrio/receivertime` - Receiver time and leap seconds

### Output Topics (preprocessed data)
- `/gnss/septentrio/pvt_geodetic` - Processed PVT solution
- `/gnss/septentrio/raw_measurements` - Filtered raw measurements
- `/gnss/septentrio/preprocessed_obs` - Preprocessed observations
- `/gnss/septentrio/factors` - GNSS factors for FGO

## Monitoring

### Check Node Status
```bash
ros2 node list | grep septentrio
ros2 node info /septentrio_gnss_preprocessing
```

### Monitor Topics
```bash
# List active topics
ros2 topic list | grep -E "(septentrio|gnss)"

# Echo PVT solution
ros2 topic echo /gnss/septentrio/pvt_geodetic

# Check message rate
ros2 topic hz /septentrio/measepoch
ros2 topic hz /gnss/septentrio/pvt_geodetic
```

### View Logs
```bash
# Live logs
ros2 run rqt_console rqt_console

# Or check terminal output with debug level
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py log_level:=debug
```

## Dual Antenna Setup

For heading determination with dual antenna:

1. **Update Configuration**
   ```yaml
   GNSSPreprocessor:
     use_dual_antenna: true
     baseline_length: 1.0  # Distance between antennas (meters)
   ```

2. **Rebuild with Dual Antenna Flag**
   ```bash
   cd /workspace/fgo_ws
   colcon build --packages-select irt_gnss_preprocessing \
     --cmake-args -DUSE_DUAL_ANTENNA=ON
   ```

3. **Verify Additional Topics**
   - `/septentrio/measepoch_aux` - Auxiliary antenna measurements
   - `/septentrio/atteuler` - Attitude (heading, pitch, roll)
   - `/septentrio/basevectorgeod` - Baseline vector

## Troubleshooting

### Plugin Loading Issues
```bash
# Check plugin registration
grep -r "SeptentrioPreProcessor" install/irt_gnss_preprocessing/

# Verify shared library
ls -lh install/irt_gnss_preprocessing/lib/libirt_gnss_preprocessing.so
```

### No Data Received
1. Check Septentrio driver is running:
   ```bash
   ros2 topic list | grep septentrio
   ros2 topic hz /septentrio/pvtgeodetic
   ```

2. Verify topic remapping in launch file matches driver output

3. Check receiver configuration (output rates, message types enabled)

### Poor Solution Quality
1. Check CN0 levels: `ros2 topic echo /septentrio/measepoch`
2. Verify satellite count in PVT: `ros2 topic echo /septentrio/pvtgeodetic`
3. Reduce `min_cn0` threshold temporarily for testing
4. Check antenna placement (sky visibility, multipath)

### RTK Not Working
1. Verify RTK corrections are received: Check `mean_corr_age` in PVTGeodetic
2. Ensure `use_rtk: true` in configuration
3. Check `max_age_correction` threshold
4. Verify reference station ID is set correctly

## Integration with Factor Graph Optimization

To use preprocessed GNSS data in FGO:

1. **Ensure FGO node is running**
   ```bash
   ros2 launch online_fgo gnss_fgo.launch.py
   ```

2. **Configure FGO to subscribe to preprocessing outputs**
   ```yaml
   # In FGO configuration
   gnss_topic: "/gnss/septentrio/factors"
   ```

3. **Monitor FGO optimization**
   ```bash
   ros2 topic echo /fgo/optimized_pose
   ```

## Performance Tips

1. **Buffer Sizes**: Adjust for your data rate
   ```yaml
   default_buffer_size: 5        # Increase for higher rates
   solution_sync_queue_size: 10  # Increase if sync issues
   ```

2. **Message Filtering**: Reduce computational load
   ```yaml
   min_cn0: 30.0           # Higher = fewer satellites, faster
   min_elevation: 15.0     # Higher = better geometry, fewer satellites
   ```

3. **Disable Unused Signals**: Reduce processing
   ```yaml
   use_gps_l5: false       # If not tracking L5
   use_bds_b1: false       # If not using BeiDou
   ```

## Example: Full System Launch

```bash
#!/bin/bash
# launch_septentrio_fgo.sh

source /workspace/fgo_ws/install/setup.bash

# Start Septentrio driver (adjust parameters for your receiver)
ros2 launch septentrio_gnss_driver serial.launch.py device:=/dev/ttyUSB0 &
DRIVER_PID=$!

sleep 5  # Wait for driver to initialize

# Start preprocessing
ros2 launch irt_gnss_preprocessing septentrio_preprocessor.launch.py &
PREPROC_PID=$!

sleep 2

# Start FGO
ros2 launch online_fgo gnss_fgo.launch.py &
FGO_PID=$!

echo "System launched!"
echo "Driver PID: $DRIVER_PID"
echo "Preprocessing PID: $PREPROC_PID"
echo "FGO PID: $FGO_PID"

# Wait for user interrupt
trap "kill $DRIVER_PID $PREPROC_PID $FGO_PID; exit" INT
wait
```

## Support and Documentation

- **Integration Summary**: `SEPTENTRIO_INTEGRATION_SUMMARY.md`
- **Integration Plan**: `plan-septentrioMosaicHIntegration.md`
- **Preprocessing Details**: `preprocess_irt.md`
- **Septentrio Driver**: `../septentrio_gnss_driver/README.md`

## Known Issues

1. **Ephemeris messages not available** - Use loosely-coupled mode or external ephemeris
2. **Signal type mapping** - Verify Type field matches expected signal types
3. **Initial convergence** - May take 30-60 seconds for first RTK fix

For issues or questions, check the GitHub repository or contact the development team.
