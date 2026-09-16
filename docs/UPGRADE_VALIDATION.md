# Upgrade validation — 2026-09-15

This report supplements the original prototype results in [VALIDATION.md](VALIDATION.md). Desktop checks do not establish physical Android or iPhone performance.

## Completed checks

- All 46 automated simulation/economy/save/asset/checkout tests pass, including 10,000 generated chunk combinations at 22 m/s, moving-hazard corridor checks and chunk boundaries. Deterministic replay and 30 accelerated simulation minutes retain fixed pools.
- New tests cover stumble recovery, immediate capture, shield precedence, fatal hazards, revival, frozen pause timers, immutable/cached snapshots, skin weights and save compatibility.
- All 18 upgraded GLBs pass Khronos validation with zero errors and warnings. Optional buffer-view target hints are informational.
- Native GPU integration loads the three 20-joint outfits and all 12 named animation tracks. Portrait review frames cover three environments and animation states for every outfit. The officer shares the camera and scene depth. The final native animation/pause test passed again. A subsequent combined-suite attempt could not launch the visual-recording app (debug connection stopped); existing review recordings are from the earlier successful standalone run, not that failed launch.
- Native UI tests cover cancellation during loading, a 360×780 portrait HUD, all four active powers, explicit background pause/resume, and synthetic keyboard input. Debug input results are in `validation/input-latency-debug.json`; the measurement starts at the keyboard-handler callback and ends at frame-build completion. Focus routing, OS/hardware input, raster completion and screen scanout are excluded.
- Browser smoke checks pass for tutorial, keyboard controls, pause, all menus, earned rewards and persistence after reload. Follow-up on 2026-09-16: Chrome now defaults to the upgraded Flutter Scene courier, officer and world. The release web build, static analysis and browser smoke checks pass; the smoke test asserts successful loads of the upgraded compiled assets. Portrait rendering was visually checked in [the browser capture](screenshots/web-upgraded.png). This does not certify browser endurance or complete the pending Rive renderer.
- Static analysis, macOS release, web release, Android debug APK and unsigned iOS debug builds pass. The SDK wrapper was fixed to put the pinned Dart on PATH for Rive's Android setup task; the global Flutter installation is unchanged.

## Native endurance

A profile-mode full-app run records frame-time histograms, process RSS, VM heap samples and pool counts once per minute. It uses the original scene adapter with upgraded human meshes, city assets, audio and an independent HUD. The test follows safe lanes at real elapsed time, reaches maximum speed and reuses the loaded scene through 20 restart/navigation cycles.

The harness continues when the desktop loses focus so unrelated desktop activity cannot pause it. Production lifecycle behavior remains enabled; explicit background pause is tested separately. An earlier four-minute attempt correctly paused on loss of focus and was excluded from endurance acceptance.

The native profile run completed 1,800.064 seconds of continuous gameplay, covering 38,934 m and 216,008 simulation ticks. All 31 samples retained 104 gameplay objects and 107 scene roots. Across 134,930 frames, build p50/p95/p99 was 2.8/3.7/4.2 ms; raster was 0.3/0.6/0.7 ms; total frame span was 3.2/4.3/4.7 ms. Total span exceeded 16.67 ms on 38 frames.

Process RSS started at 216.8 MiB, peaked at 233.1 MiB and ended at 184.9 MiB. Post-warmup samples fluctuated without sustained growth; Dart heap samples also cycled with collection. See [profile samples](validation/native-soak.json) and [VM heap samples](validation/native-heap.json). These measurements ran alongside other development/build activity, rather than in an isolated benchmark.

The original harness stalled awaiting a widget frame after the completed endurance interval. Its pause/navigation wait was corrected, and a separate short debug run passed all 20 pause, outfit-preview, home and restart cycles with unchanged pool counts: [restart results](validation/native-restarts-debug.json). The long run preceded minor final visual/cache refinements; the short follow-up exercises the latest source. No second 30-minute run is claimed.

GPU/Metal memory is not measured separately; RSS and Dart heap measurements cannot establish physical mobile VRAM or thermal behavior.

## Rive gate

Rive CLI verification and rendering pass. The shipping native runtime rejects the unsigned scripted scene: a script-free control renders, while the scripted native texture contains a single flat color. The opt-in native test requires shaded pixels and therefore does not mistake lack of exceptions for a pass.

The native Rive replacement remains blocked on signed assets, followed by animation, depth, pause/disposal and performance validation. See [RIVE_GATE.md](RIVE_GATE.md). Full-world Rive integration and upgraded Rive browser delivery are not claimed.

## Release requirements

- Profile physical mid-range Android and older/recent iPhones: frame timing, touch-to-display latency, spawning spikes, thermal behavior and sustained CPU/GPU memory.
- Complete subjective motion/playtesting and sound-mix review. The deterministic 12 fps review videos do not certify animation smoothness at a device's display refresh rate.
- Investigate the original browser prototype's previously measured JS heap growth before certifying its strict memory criterion.
- Configure iOS signing for device installation/distribution. Android licenses were sufficient for this machine's debug build; fresh machines must accept the installed SDK licenses. No store publication was attempted.
