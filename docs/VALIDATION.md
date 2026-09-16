# Validation — 14 September 2026

For the subsequent character/world upgrade, see [UPGRADE_VALIDATION.md](UPGRADE_VALIDATION.md). The results below describe the original prototype.

## Build and test results

| Check | Result |
| --- | --- |
| Flutter SDK | Separate Flutter 3.47.2 / Dart 3.13.2 installation |
| Static analysis | Clean |
| Unit tests | 33 passing: simulation, collision sweeps, asset structure, economy, missions, save recovery, disposal |
| Procedural generation | 10,000 combinations validated across chunk boundaries at maximum speed |
| Deterministic endurance | 30 simulated minutes completed on the safe-route controller; eight original chunk objects and 104 simulation pool slots retained |
| Native GPU integration | All three GLBs loaded and all eight required animation states rendered on macOS without Flutter exceptions |
| Khronos GLB validation | Eight assets; zero errors and zero warnings |
| Browser flow | Tutorial, keyboard movement, pause, every menu, coins, and persistence/reload passed with zero page errors |
| Browser economy | VOLT purchase/selection, magnet upgrade, mission claim, paid revival, countdown and resumed pause passed |
| Responsive review | Screens inspected at 430×900 and 360×640 |
| Web release | Built successfully |
| macOS release | Built successfully |
| Android debug APK | Built successfully; initial Gradle download timeout resolved using a checksum-verified official distribution |
| iOS debug | Built successfully with signing disabled |

The native test exercises GPU rendering; it does not establish physical mobile performance. The browser audio engine initializes successfully; one active mixed voice was verified after a user gesture. Chrome initially suspends audio until a user gesture, as expected. SoLoud 4.x also emits a ScriptProcessor deprecation warning in Chrome; this is a dependency warning, not a page exception.

## Rendered endurance check

A frozen prototype build is tested in headless Chrome at 430×900 with real-time automatic lane following. The harness takes screenshots every five minutes, requests garbage collection, and records Chrome's JS heap and DOM counters once per minute. This is distinct from the accelerated Dart simulation test.

The full 30-minute rendered run completed. Post-GC JS heap changed from 17.07 MiB at the initial sample to 23.34 MiB at minute 30. This does not satisfy a demonstrated flat-memory criterion.

Final measurements are stored alongside this report in `prototype_soak.json`. Screenshot samples show the run continuing at approximately 60 tick callbacks per second. This is not a GPU percentile benchmark. The browser page retained one document and 66 DOM nodes throughout the observed samples; simulation pools are fixed separately.

**Memory acceptance remains provisional:** browser JS heap rises during the run. Fixed object counts alone do not demonstrate a flat total memory footprint, and the measurements do not include GPU allocations or CanvasKit's entire native/WASM heap. Do not certify the PRD's strict long-run memory criterion from this test alone.

## Release gates

- Profile physical mid-range Android and older/recent iPhones for CPU/GPU frame timing, thermals, input latency, and total process/GPU memory during a sustained run.
- Investigate the browser heap growth and establish a stable post-warm-up memory range before claiming the strict endurance target.
- Complete playtesting of obstacle readability, jump timing, economy pacing, sound mix, and animation blending.
- Configure distribution signing and store identifiers before publishing. The delivered APK uses debug signing; the iOS build is unsigned.

The scope was implemented through V1 using the agreed provisional desktop route. Longer endurance verification continued in parallel with progression/UI development rather than delaying that work until the live soak completed. No mobile performance certification or store publication is claimed.
