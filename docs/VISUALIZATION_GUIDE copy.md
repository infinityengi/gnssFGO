# gnssFGO Visualization Guide

This guide explains how to visualize the gnssFGO localization system output using RViz2 and Mapviz.

## Overview

The gnssFGO system publishes various topics that can be visualized in real-time:
- **Optimized trajectory**: `/deutschland/stateOptmizedNavFix`
- **Predicted trajectory**: `/deutschland/statePredictedNavFix`
- **Reference GNSS**: `/novatel/gps/fix`
- **Odometry**: `/gnss_fgo/mapping/odometry`
- **Point clouds**: `/gnss_fgo/mapping/cloud_registered`
- **Path**: `/gnss_fgo/mapping/path`

---

## Method 1: Using Mapviz (Recommended for GPS Visualization)

Mapviz provides an interactive 2D map interface ideal for visualizing GPS trajectories.

### Step 1: Launch the System

Open **4 separate terminals** and run the following commands:

#### Terminal 1: GNSS Preprocessor
```bash
cd /workspace/fgo_ws
source install/setup.bash
ros2 launch irt_gnss_preprocessing gnss_preprocessor.launch.py
```

#### Terminal 2: Online FGO (Loosely Coupled)
```bash
cd /workspace/fgo_ws
source install/setup.bash
ros2 launch online_fgo aachen_lc.launch.py
```

#### Terminal 3: Mapviz Visualization
```bash
cd /workspace/fgo_ws
source install/setup.bash
ros2 launch mapviz mapviz.launch.py
```

#### Terminal 4: Play Bag File
```bash
cd /workspace/fgo_ws
source install/setup.bash
ros2 bag play /workspace/fgo_ws/src/gnssFGO/bags/AC_0.db3 --clock --start-offset 60
```

### Step 2: Configure Mapviz

Once Mapviz opens, you can either:

**Option A: Load Pre-configured Settings**
1. In Mapviz, click **File → Open Config**
2. Navigate to: `/workspace/fgo_ws/src/gnssFGO/online_fgo/launch/deutschland.mvc`
3. Click **Open**

**Option B: Manual Configuration**
1. Click **Add Display** button
2. Add **tile_map** plugin:
   - Select "GoogleMapHybrid" or "OpenStreetMap" as source
   - This provides the background map
3. Add **navsat** plugin (Repeat 3 times for different topics):
   - **Reference GPS**: 
     - Topic: `/novatel/gps/fix`
     - Color: Blue
     - Draw Style: Points
   - **Predicted State**: 
     - Topic: `/deutschland/statePredictedNavFix`
     - Color: Red
     - Draw Style: Points
   - **Optimized State**: 
     - Topic: `/deutschland/stateOptmizedNavFix`
     - Color: Green
     - Draw Style: Points
4. Set **Fixed Frame** to `map` in the top toolbar
5. Adjust zoom level to see the trajectory

### Step 3: What You Should See

- **Blue dots/line**: Raw GNSS measurements from the reference receiver
- **Red dots/line**: Predicted vehicle trajectory from the filter
- **Green dots/line**: Optimized vehicle trajectory after factor graph optimization
- The green line should be smoother and more accurate than the blue reference

---

## Method 2: Using RViz2 (For 3D Visualization with LiDAR)

RViz2 is better suited when using LiDAR data (LIO-SAM integration).

### Step 1: Launch the System with LiDAR

#### Terminal 1: GNSS Preprocessor
```bash
cd /workspace/fgo_ws
source install/setup.bash
ros2 launch irt_gnss_preprocessing gnss_preprocessor.launch.py
```

#### Terminal 2: Online FGO with LiDAR
```bash
cd /workspace/fgo_ws
source install/setup.bash
ros2 launch online_fgo aachen_lc_all.launch.py
```

#### Terminal 3: LIO-SAM (if using LiDAR)
```bash
cd /workspace/fgo_ws
source install/setup.bash
ros2 launch lio_sam fgorun.launch.py
```

#### Terminal 4: RViz2
```bash
cd /workspace/fgo_ws
source install/setup.bash
rviz2 -d /workspace/fgo_ws/src/gnssFGO/LIOSAM/config/rviz2.rviz
```

#### Terminal 5: Play Bag File
```bash
ros2 bag play /workspace/fgo_ws/src/gnssFGO/bags/AC_0.db3 --clock --start-offset 60
```

### Step 2: RViz2 Configuration

If not using the provided config file, manually add these displays:

1. **Grid**: For reference
   - Fixed Frame: `map`

2. **PointCloud2**: For LiDAR visualization
   - Topic: `/gnss_fgo/mapping/cloud_registered`
   - Size: 2-3
   - Color: Intensity or AxisColor

3. **Odometry**: For trajectory
   - Topic: `/gnss_fgo/mapping/odometry`
   - Shape: Arrow
   - Color: Green

4. **Path**: For trajectory history
   - Topic: `/gnss_fgo/mapping/path`
   - Color: Red

5. **TF**: For coordinate frames
   - Enable to see sensor transformations

---

## Method 3: Using Command Line Tools

For quick inspection without GUI:

### View Available Topics
```bash
ros2 topic list
```

### Monitor Optimized State
```bash
ros2 topic echo /deutschland/stateOptimized
```

### Monitor GPS Fix
```bash
ros2 topic echo /deutschland/stateOptmizedNavFix
```

### Monitor Trajectory Stats
```bash
ros2 topic hz /deutschland/stateOptimized
```

### Plot Data with PlotJuggler (if available)
```bash
ros2 run plotjuggler plotjuggler
```
Then connect to ROS2 topics and plot position, velocity, or covariance data.

---

## Method 4: Using Docker Compose (Includes X11 Forwarding)

If running in Docker, visualization requires X11 forwarding:

### Step 1: Enable X11 Access
```bash
xhost +local:docker
```

### Step 2: Run Docker Compose
```bash
cd /workspace/fgo_ws/src/gnssFGO/docker
docker compose up -d
```

### Step 3: Access Container
```bash
docker exec -it gnssfgo bash
```

### Step 4: Inside Container
```bash
cd /workspace/fgo_ws
source install/setup.bash
# Run mapviz or rviz2 as shown above
```

---

## Troubleshooting

### No Display / Can't Open GUI
```bash
# Enable X11 forwarding
export DISPLAY=:0
xhost +
```

### Topics Not Showing in Mapviz/RViz
- Ensure all nodes are running (preprocessor, FGO, bag player)
- Check topics are publishing: `ros2 topic list`
- Verify clock is running: `ros2 topic echo /clock`

### Bag File Issues
- Use full path to bag file: `/workspace/fgo_ws/src/gnssFGO/bags/AC_0.db3`
- Include `--clock` flag for time synchronization
- Use `--start-offset 60` to skip initial stationary period

### Map Not Loading in Mapviz
- Check internet connection (required for online map tiles)
- Try different map source (OpenStreetMap, GoogleMapHybrid, etc.)
- Ensure GPS coordinates are valid (lat/lon in reasonable range)

### Performance Issues
- Reduce bag playback rate: `--rate 0.5`
- Decrease buffer size in visualization plugins
- Close unused displays in RViz2/Mapviz

---

## Key Topics Reference

| Topic | Type | Description |
|-------|------|-------------|
| `/deutschland/stateOptmizedNavFix` | NavSatFix | Optimized GPS position (Green) |
| `/deutschland/statePredictedNavFix` | NavSatFix | Predicted GPS position (Red) |
| `/deutschland/stateOptimized` | Odometry | Full state with covariance |
| `/deutschland/statePredicted` | Odometry | Predicted full state |
| `/novatel/gps/fix` | NavSatFix | Reference GNSS solution |
| `/gnss_fgo/mapping/odometry` | Odometry | LiDAR odometry |
| `/gnss_fgo/mapping/path` | Path | Trajectory history |
| `/gnss_fgo/mapping/cloud_registered` | PointCloud2 | Registered point cloud |

---

## Advanced: Recording Your Own Visualization

### Save Screenshot in Mapviz
1. Click the camera icon in Mapviz toolbar
2. Choose save location
3. Screenshot will be saved

### Record Video of Visualization
```bash
# Using ROS2 bag to record specific visualization topics
ros2 bag record /deutschland/stateOptmizedNavFix /deutschland/statePredictedNavFix /novatel/gps/fix
```

### Export Trajectory to File
```bash
# Record and convert to CSV/KML for external tools
ros2 topic echo /deutschland/stateOptmizedNavFix > trajectory.txt
```

---

## Quick Start Command Summary

**Fastest way to visualize AC_0 bag:**

```bash
# Terminal 1
cd /workspace/fgo_ws && source install/setup.bash && \
ros2 launch irt_gnss_preprocessing gnss_preprocessor.launch.py

# Terminal 2
cd /workspace/fgo_ws && source install/setup.bash && \
ros2 launch online_fgo aachen_lc.launch.py

# Terminal 3
cd /workspace/fgo_ws && source install/setup.bash && \
ros2 launch mapviz mapviz.launch.py

# Terminal 4
ros2 bag play /workspace/fgo_ws/src/gnssFGO/bags/AC_0.db3 --clock --start-offset 60
```

Then load `/workspace/fgo_ws/src/gnssFGO/online_fgo/launch/deutschland.mvc` in Mapviz.

---

## Next Steps

- Try tightly coupled mode: `ros2 launch online_fgo aachen_tc.launch.py`
- Experiment with different launch files: `aachen_lc_all.launch.py` includes LiDAR
- Test with the second bag file: `C01_0.db3`
- Modify visualization colors and styles in Mapviz
- Add custom displays for IMU data, satellite counts, or error metrics

For more information, see the main README at `/workspace/fgo_ws/src/gnssFGO/README.md`
