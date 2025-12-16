# Update — Septentrio Mosaic-H Support 


## How `irt_gnss_preprocessing` works (and what it expects)
- The preprocessing node ingests two classes of inputs:
  1) **Raw observations** (pseudorange, carrier phase, Doppler, CN0) per satellite/frequency.
  2) **Navigation products** (ephemeris/orbit/clock, ionosphere model, GPS–GAL time offset) to compute satellite states and corrections at each measurement epoch.
- Required message types (ROS topics) for full GPS/GAL support:
  - `GPSEPHEM` (GPS ephemeris), `GALFNAVEPHEMERIS` (GAL ephemeris)
  - `IONUTC` (GPS ionosphere / UTC params)
  - `GALIONO` (GAL ionosphere)
  - `GALCLOCK` (GPS–GAL time offset / GGTO)
- With these plus raw measurements, preprocessing builds factor inputs and feeds the online FGO pipeline end-to-end.

## What NovAtel provides (reference)
- Raw observations and all required navigation products are published already:
  - `GPSEPHEM`, `GALFNAVEPHEMERIS`, `IONUTC`, `GALCLOCK`
  - Raw measurement streams and solution topics (PVT, covariances, dual-antenna attitude)
- Result: `irt_gnss_preprocessing` has everything it needs; the NovAtel path is fully operational.

## What Septentrio driver originally provided (gap)
- Provided: raw observations (`MeasEpoch`), PVT, dual-antenna attitude, covariances, diagnostics.
- Missing: ephemeris (GPS/GAL), ionosphere (GPS/GAL), GPS–GAL time offset.
- Impact: Preprocessing cannot complete required inputs; FGO cannot run end-to-end on Septentrio until these nav products are published.

## Required driver extensions (SBF → ROS messages)
- Add SBF block support and publish ROS topics:
  - GPSNav (5891) → `GPSEPHEM`
  - GALNav (4002) → `GALFNAVEPHEMERIS`
  - GPSIon (5893) → `IONUTC`
  - GALIon (4030) → `GALIONO`
  - GALGstGps (4032) → `GALCLOCK`
- Goal: Mirror NovAtel’s navigation product outputs so preprocessing can treat Septentrio identically.

## Plan (driver extension) and current status
- **Message reuse**: Copied existing `.msg` files from NovAtel package and added to Septentrio build (done).
- **Wiring done**: SBF IDs added, typedefs added, `parseSbf` switch cases added, new publish flags/params added; stub parsers for all 5 blocks inserted (done).
- **Next critical work**: Implement full binary parsers in `sbf_blocks.hpp` for all 5 SBF blocks (GPSIon/GALIon/GALGstGps are simpler; GPSNav/GALNav are larger) and validate with SBF logs or live receiver.
- **Receiver config for live tests**: enable outputs, e.g., `setSBFOutput ... +GPSNav+GALNav+GPSIon+GALIon+GALGstGps OnChange`, then `saveConfig`.

## What’s done vs. what’s next
- **Done**: Messages copied; CMake wired; publish flags/params added; parse switch cases added; stub parsers inserted; docs/changelog updated.
- **Next steps**:
  1) Complete binary parsers for GPSNav, GALNav, GPSIon, GALIon, GALGstGps.
  2) Validate published topics with SBF logs or live receiver.
  3) Run end-to-end with `irt_gnss_preprocessing` + online FGO using Septentrio data.

