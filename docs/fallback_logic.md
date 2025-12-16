# JSON Fallback for Nav/Iono/Clock (Septentrio)

This document describes a lightweight fallback mechanism to ensure the GNSS preprocessing can start and step even when the receiver isn’t currently publishing the five OnChange navigation products.

- Topics covered: `/gpsephem`, `/gpsion`, `/galfnavephem`, `/galion`, `/galclock`
- Cache format: JSON files under a chosen `--cache-dir` (default: `/workspace/fgo_ws/nav_cache`)
- Publisher: `scripts/nav_cache_node.py` (ROS 2 Python node)

## Why
Septentrio SBF navigation products are published OnChange and can be sparse (minutes to hours). The preprocessing node may wait for ephemeris/iono/clock and refuse to step without them. The JSON fallback keeps the last known values available so startup and initial steps succeed, while seamlessly updating when the receiver publishes fresh data.

## How It Works
- Subscribes to the five topics and caches the latest message for each into JSON files.
- On startup, loads any JSON files present and publishes one message per topic using TRANSIENT_LOCAL QoS.
- Periodically republishes cached messages (configurable) so late subscribers also receive data.
- Automatically updates JSON files when the receiver publishes new data; republish continues using the latest.

## Quick Start (Detached/Non-blocking)
```bash
# 1) Environment
source install/setup.bash

# 2) Start JSON cache publisher
nohup python3 scripts/nav_cache_node.py \
  --cache-dir /workspace/fgo_ws/nav_cache \
  --publish-on-load true \
  --republish-period 5 \
  > /tmp/nav_cache.log 2>&1 < /dev/null & echo $! > /tmp/nav_cache.pid

# 3) Verify topics have data
ros2 topic echo /gpsephem --once
ros2 topic echo /gpsion --once
ros2 topic echo /galfnavephem --once
ros2 topic echo /galion --once
ros2 topic echo /galclock --once

# 4) Start preprocessing (detached)
nohup ros2 run irt_gnss_preprocessing node_gnss_preprocessing \
  --ros-args --params-file config/gnss_preprocessing_septentrio_test.yaml \
  > /tmp/preprocessing.log 2>&1 < /dev/null & echo $! > /tmp/preprocessing.pid
```

## Stop/Restart
```bash
# Stop cache node
kill $(cat /tmp/nav_cache.pid) && rm -f /tmp/nav_cache.pid

# Stop preprocessing
kill $(cat /tmp/preprocessing.pid) && rm -f /tmp/preprocessing.pid
```

## Configuration
- `--cache-dir`: Directory for JSON files (default: `/workspace/fgo_ws/nav_cache`).
- `--publish-on-load`: Publish cached messages immediately at node start (`true`/`false`).
- `--republish-period`: Seconds between periodic republish (e.g., `5.0`; set `0` to disable).

## JSON Files
The node writes one JSON per topic (same schema as the ROS 2 message):
- `gpsephem.json`, `gpsion.json`, `galfnavephem.json`, `galion.json`, `galclock.json`

You may prefill or edit these files manually for testing; they will be published on load and then refreshed as live data arrives.

## Notes & Behavior
- QoS: Publishers use TRANSIENT_LOCAL so late subscribers can latch the last message; periodic republish further helps discovery.
- Multiple publishers: If the receiver also publishes a topic, ROS 2 may print a QoS notice. That’s expected; the preprocessor will receive data regardless.
- Staleness: Ephemeris/iono/clock are time-referenced. For long offline runs, prefer recent caches. Replace JSONs when appropriate.
- YAML params fix: If you use `config/gnss_preprocessing_septentrio_test.yaml`, ensure numeric scalars are valid (e.g., `5.0` not `5.`) to avoid parsing errors.

## Troubleshooting
- No echo output:
  - Check the cache node: `ps -fp $(cat /tmp/nav_cache.pid) || tail -n 80 /tmp/nav_cache.log`
  - Ensure JSON files exist in the cache dir.
- Preprocessing still skips steps:
  - Confirm all five topics have a message (`ros2 topic echo ... --once`).
  - Review `/tmp/preprocessing.log` for guard messages (e.g., missing ephemeris or iono). Update/refresh the JSONs accordingly.
- QoS warning about durability:
  - Harmless; ROS 2 connects to all publishers even if durability differs.

## File Locations
- Script: `scripts/nav_cache_node.py`
- Cache dir (default): `/workspace/fgo_ws/nav_cache`
- Logs: `/tmp/nav_cache.log` and `/tmp/preprocessing.log`
- Params: `config/gnss_preprocessing_septentrio_test.yaml`
