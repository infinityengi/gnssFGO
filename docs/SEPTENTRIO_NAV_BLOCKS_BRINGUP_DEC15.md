# Septentrio SBF Navigation Blocks Bring-up (Dec 15, 2025)

Scope: End-to-end process used to bring up and validate SBF navigation products on a Septentrio mosaic‑H with the ROS2 `septentrio_gnss_driver`, including receiver configuration, driver launch, topic verification, and troubleshooting notes.

## Summary
- Implemented/fixed parsers for SBF blocks: 4002 (GAL_NAV), 4030 (GAL_ION), 4032 (GAL_GST_GPS), 5891 (GPS_NAV), 5893 (GPS_ION).
- Corrected payload modeling per firmware v4.14.4 and standardized on SBF header `TOW`/`WNc` for timing.
- Corrected `rover.yaml` publish parameter keys: `gpsephem`, `galfnavephem`, `gpsion`, `galion`, `galclock`.
- Live validation via TCP `192.168.3.1:28784`: observed `/galclock`, `/galion`, and intermittent `/galfnavephem`; GPS topics pending until broadcast.

Reference log entry: see `CHANGELOG.md` under "Septentrio SBF Nav Blocks Bring-up (Dec 15, 2025)".

## Receiver Configuration (Web UI)
1. Connect to `http://192.168.3.1/` (mosaic‑H web).
2. Enable SBF output on the primary TCP/IP stream (IP10 / port 28784).
3. Add/ensure the following blocks are enabled (OnChange recommended; for testing, 1 s periodic is acceptable):
   - 5891: GPSNav (GPS ephemeris)
   - 5893: GPSIon (GPS ionosphere – Klobuchar)
   - 4002: GALNav (Galileo F/NAV ephemeris)
   - 4030: GALIon (Galileo ionosphere)
   - 4032: GALGstGps (GPS–Galileo time offset)
4. Click Apply/OK and wait ~5–10 s.

Note: Ephemeris/ionosphere blocks are typically OnChange; using 1 s during validation helps confirm parser/publish paths quickly.

## Driver Launch
Terminal A:
```bash
# Source workspace
source /workspace/fgo_ws/install/setup.bash

# Launch the composition-based rover config
ros2 launch septentrio_gnss_driver rover.launch.py
```

Expected (first 20 s): successful component load, connection to `tcp://192.168.3.1:28784`, and INFO logs for block arrivals such as "Received GAL_ION block 4030".

## Topic Verification
Terminal B:
```bash
source /workspace/fgo_ws/install/setup.bash

# List nav topics (filter)
ros2 topic list | grep -E "gpsephem|galfnavephem|gpsion|galion|galclock"

# One-shot echo to confirm payloads when published
ros2 topic echo /galclock --once
ros2 topic echo /galion --once
ros2 topic echo /galfnavephem --once
ros2 topic echo /gpsion --once
ros2 topic echo /gpsephem --once
```

Observed in validation session:
- Present: `/galclock`, `/galion`, intermittent `/galfnavephem`.
- Pending (await broadcast): `/gpsephem`, `/gpsion`.

## Troubleshooting Notes
- Parse error "iterator past end":
  - Root cause in earlier runs was mis-modeled payload fields and re-reading time from payload.
  - Fixes: rely on SBF header `TOW`/`WNc` only; correct field sizes/order (e.g., `WN_oG` is 6-bit in a 1-byte field; `A_0G`/`A_1G` are floats per manual for 4032); include `C_rs` in GAL_NAV.
- Config parameter names:
  - Ensure `rover.yaml` uses exact keys: `gpsephem`, `galfnavephem`, `gpsion`, `galion`, `galclock`. A mismatch will prevent publishers from being created.
- Clean restart after rebuilds:
  - Stop old component processes before relaunching; otherwise logs may reflect an older binary.
- OnChange cadence:
  - Ephemeris/ionosphere blocks are sporadic; use 1 s periodic during validation if needed.
- Quick TCP check (portable):
  ```bash
  timeout 3 bash -lc 'exec 3<>/dev/tcp/192.168.3.1/28784; echo OK >&3'
  ```

## Quick Commands
```bash
# Launch
source /workspace/fgo_ws/install/setup.bash
ros2 launch septentrio_gnss_driver rover.launch.py

# Monitor topics
ros2 topic list | grep -E "gal|gpsion|gpsephem"
ros2 topic echo /galclock --once
ros2 topic echo /galion --once
ros2 topic echo /galfnavephem --once
ros2 topic echo /gpsion --once
ros2 topic echo /gpsephem --once
```

## Next Steps
- Long-run validation of `/gpsephem` and `/gpsion` on live signals.
- Value sanity checks against expected ranges (URA, week rollover, time group delays).
- Integrate these topics into the preprocessing pipeline once stability is confirmed.

## Related Documents
- `docs/SEPTENTRIO_PARSER_TESTING_GUIDE.md` – comprehensive testing procedures
- `septentrio_driver_testing_integration.md` – broader driver testing & integration
- `docs/SBF_BLOCK_REFERENCE_QUICK_GUIDE.md` – quick reference for block layouts
