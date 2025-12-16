# Septentrio SBF Monitoring & Verification Guide

Purpose: Quickly verify that all required SBF navigation blocks are arriving, being parsed, and published to the expected ROS2 topics. Applicable to Septentrio mosaic‑H over TCP `192.168.3.1:28784` using `septentrio_gnss_driver` (ROS2 Humble).

## Required SBF Blocks and Expected Topics
- 5891: GPS_NAV → `/gpsephem` (GPSEPHEM)
- 5893: GPS_ION → `/gpsion` (IONUTC)
- 4002: GAL_NAV → `/galfnavephem` (GALFNAVEPHEMERIS)
- 4030: GAL_ION → `/galion` (GALIONO)
- 4032: GAL_GST_GPS → `/galclock` (GALCLOCK)

## Receiver-side Checks (Web UI)
1) Connect to `http://192.168.3.1/`.
2) Ensure SBF output on IP10 / TCP 28784 is enabled.
3) Enable blocks above; for validation, set rate to 1 s (instead of OnChange) to force frequent publishes.
4) Apply/Save; wait ~5–10 s.

## Connectivity Sanity
```bash
# TCP reachability
timeout 3 bash -lc 'echo > /dev/tcp/192.168.3.1/28784'

# (Optional) Peek bytes from the stream
timeout 3 bash -lc 'exec 3<>/dev/tcp/192.168.3.1/28784; head -c 128 <&3 | hexdump -C | head'
```

## Launch the Driver
```bash
# Recommended: disable Fast DDS SHM to avoid port lock noise during quick echos
export RMW_FASTRTPS_USE_SHM=0
source /workspace/fgo_ws/install/setup.bash
ros2 launch septentrio_gnss_driver rover.launch.py
```

Expected startup: connection to `tcp://192.168.3.1:28784`, then INFO logs like "Received GAL_ION block 4030" when blocks arrive.

## Verify Blocks Arriving (Logs)
Active log files are in `/tmp/` (e.g., `septentrio_galnavfix.log` or `septentrio_live.log`).
```bash
# See latest log files
ls -ltr /tmp/septentrio_*log | tail

# Watch GPS/GAL nav+ion blocks
tail -f /tmp/septentrio_*log | grep -E 'GPS_(NAV|ION)|GAL_(NAV|ION|GST)'
```
What to expect:
- GPS: "Received GPS_NAV block 5891", "Received GPS_ION block 5893"
- Galileo: "Received GAL_NAV block 4002", "Received GAL_ION block 4030", "Received GAL_GST_GPS block 4032"

## Verify Topics (Presence and Data)
```bash
# List topics
ros2 topic list | grep -E 'gpsephem|gpsion|galfnavephem|galion|galclock'

# One-shot echoes (may need 20–60 s if OnChange)
export RMW_FASTRTPS_USE_SHM=0
source /workspace/fgo_ws/install/setup.bash
timeout 30 ros2 topic echo /gpsephem --once
timeout 30 ros2 topic echo /gpsion --once
timeout 30 ros2 topic echo /galfnavephem --once
timeout 30 ros2 topic echo /galion --once
timeout 30 ros2 topic echo /galclock --once
```
Expectations:
- Topics exist when publish parameters in `rover.yaml` are true (`gpsephem`, `gpsion`, `galfnavephem`, `galion`, `galclock`).
- Messages appear intermittently; ephemeris/ionosphere are low-rate (OnChange). Use 1 s rate for bring-up if needed.

## Quick Decision Table
- Logs show block arrivals but topic absent → check `rover.yaml` publish flags.
- Topic exists but no messages → wait longer or set 1 s rate; ensure driver was launched after setting `RMW_FASTRTPS_USE_SHM=0` if SHM errors appear.
- No block arrivals in log → verify receiver SBF config and TCP reachability.

## Troubleshooting
- DDS SHM port lock warnings: set `export RMW_FASTRTPS_USE_SHM=0` before launching and before running `ros2 topic echo`.
- Stale process: ensure no old component containers are running; restart driver after rebuilds.
- Parameter names: exact keys in `config/rover.yaml` must be `gpsephem`, `galfnavephem`, `gpsion`, `galion`, `galclock`.
- Slow ephemeris: leave running several minutes; OnChange cadence depends on satellite subframes.

## Minimal End-to-End Check (2 terminals)
Terminal A (driver):
```bash
export RMW_FASTRTPS_USE_SHM=0
source /workspace/fgo_ws/install/setup.bash
ros2 launch septentrio_gnss_driver rover.launch.py
```
Terminal B (monitor):
```bash
export RMW_FASTRTPS_USE_SHM=0
source /workspace/fgo_ws/install/setup.bash
ros2 topic list | grep -E 'gpsephem|gpsion|gal'
tail -f /tmp/septentrio_*log | grep -E 'GPS_(NAV|ION)|GAL_(NAV|ION|GST)'
# try echoes over time
timeout 30 ros2 topic echo /gpsephem --once
timeout 30 ros2 topic echo /gpsion --once
```

## Expected Outcomes
- Log lines confirm all five blocks arriving at least occasionally.
- Topics visible: `/gpsephem`, `/gpsion`, `/galfnavephem`, `/galion`, `/galclock`.
- Echoes eventually print structured messages; if not, re-check SBF rates and SHM setting, then relaunch.

## OnChange vs. Periodic Rates
**OnChange behavior (default):**
- GAL/GPS nav blocks publish only when satellite ephemeris/ionosphere data changes.
- Typical cadence: every 30 minutes to 2 hours (depends on satellite constellation updates).
- Bandwidth efficient for production; unpredictable for development.

**Periodic rates (recommended for preprocessing):**
- Set all 5 blocks to **30 sec** in web UI for consistent data availability.
- Example: `IP10: SBF, GPSNav+GPSIon+GALNav+GALIon+GALGstGps, 30 sec`
- Ensures preprocessing pipeline always has recent nav data without overwhelming it.

**GPS Ephemeris (5891) Specific:**
- GPS_NAV blocks are broadcast only when satellites have fresh ephemeris to send.
- Timing depends on satellite subframe schedule and constellation updates (every ~2 hours typical).
- Parser is correct and ready; absence is due to natural satellite broadcast cadence, not code issues.
- If testing GPS_NAV specifically, use 30 sec periodic rate to force consistent polling.
