# Courier chase upgrade

The native and browser game now uses rounded, skinned human couriers and a police pursuer in the retained Flutter Scene renderer. The Rive replacement is **pending script signing and its native rendering gate**; it is not presented as an integrated renderer. See [the concrete gate result](RIVE_GATE.md).

## Delivered behavior

- PIP, VOLT and NOVA are delivery outfits on a shared 20-joint human rig. Existing IDs, prices, purchases and saves remain compatible. The courier wears a cap, jacket, sneakers and a pizza bag; the officer has a separate uniform, cap and badge.
- Generated clips include Idle, Run, Jump, Fall, Land, Slide, Stumble, Crash, Pursuit and Capture, plus Hit/Death compatibility aliases. Running uses articulated elbows/knees/ankles, a grounded stance calculation, body lean and bag motion. Clip blending and footsteps follow simulation time and speed.
- Speed starts at 12 m/s and reaches 22 m/s at 2,000 m. Lane changes remain 160 ms; slides remain 750 ms. Generation validates a reachable grounded lane at maximum speed, including moving-drone corridors and chunk boundaries.
- Low and overhead collisions cause a stumble. Another minor collision within six seconds causes capture. Cargo pods, drones, transit vehicles and gaps remain fatal on contact. Shield protection applies first, and consumed obstacles cannot hit twice. A stumble does not grant protection from other hazards. Pause freezes pursuit; revival resets the officer and restores existing protection.
- City sections use shared meshes for towers, illuminated infrastructure, station platforms, tunnel supports, signs and distant hover traffic. Hazards have distinct cargo-pod, barricade, service-arm, drone and transit-vehicle silhouettes; gaps remain actual missing floor geometry.
- Horseshoe magnets, shield badges, score stars marked 2× and paired coins marked 2× appear in the world and UI. A shield uses an energy ring around the courier. The ordinary coin counter is separate from the double-coins symbol.
- Original wind audio is bundled alongside the existing synthesized music and effects. Music/SFX volumes, haptics, reduced motion and explicit resume after backgrounding remain supported.

## Runtime and resource ownership

`RunnerGame.advance` returns the elapsed fixed-step time. `RunnerRenderer` accepts an immutable `PresentationSnapshot`; the scene no longer advances simulation. The existing scene adapter reads the fixed chunk pools during synchronous rendering without owning their lifetimes. Changing renderer does not reset scoring, rewards, purchases or missions.

HUD snapshots refresh independently at 10 Hz. Settings and progression have cached immutable read models, avoiding JSON copies during scene ticks and UI reads. Scene assets and animation clips load before play. Eight chunks, 104 gameplay objects and their scene nodes are reused; navigation and restart reuse the loaded renderer. Disposing or cancelling loading clears listeners, animation clips, scene references and audio resources. Flutter Scene owns shared GPU buffers; its public adapter API does not expose per-resource VRAM counters.

The simulation catches up ordinary stalls up to 500 ms. Background pauses discard elapsed background time. Longer stalls are deliberately bounded rather than running an unlimited catch-up loop.

## Commands

Use the pinned SDK through `tool/flutterw`; it also sets PATH for native dependency setup scripts that invoke Dart themselves.

```sh
./tool/flutterw pub get
./tool/flutterw run -d macos --profile
./tool/flutterw run -d chrome  # upgraded courier, police and world

./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw test integration_test/scene_test.dart -d macos
./tool/flutterw test integration_test/ui_test.dart -d macos

# Full app + audio + HUD, real elapsed time; uses ephemeral progression.
./tool/flutterw drive -d macos --profile \
  --driver=test_driver/integration.dart \
  --target=integration_test/native_soak_test.dart \
  --dart-define=SKYWAY_SOAK=true --dart-define=SKYWAY_SOAK_MINUTES=30

# Profile synthetic keyboard-handler callback to completed frame build.
./tool/flutterw drive -d macos --profile \
  --driver=test_driver/integration.dart --target=integration_test/ui_test.dart

# Review frames for legacy presentation and all native environments/outfits.
./tool/flutterw test integration_test/visual_review_test.dart -d macos \
  --dart-define=SKYWAY_RECORD_REVIEW=true

./tool/flutterw build web --release
./tool/flutterw build macos --release
./tool/flutterw build apk --debug
./tool/flutterw build ios --debug --no-codesign
```

The soak harness deliberately continues when the desktop loses focus; production still pauses on backgrounding. Pause is tested explicitly. The test prints its artifact directory inside the macOS application container, and `flutter drive` also writes `build/integration_response_data.json`. `tool/sample_vm_memory.py` adds read-only VM heap samples without forcing GC.

## Review artifacts and limits

[Before](recordings/before.mp4) and [after](recordings/after.mp4) are deterministic scene review recordings at 12 frames/s, not performance recordings. The first nine seconds compare the three environments. The remaining after footage cycles through animation states for all three outfits. The before recording uses the retained prototype presentation with the current simulation; original prototype screenshots remain in `docs/screenshots/`.

[Native HUD](screenshots/native-hud.png), [gameplay](screenshots/native-gameplay.png), [station](screenshots/native-station.png), and [tunnel](screenshots/native-tunnel.png) provide portrait stills. [Validation](UPGRADE_VALIDATION.md) distinguishes native rendering, automated tests, build results and physical-device requirements.

Rive signing, expansion of the signed Rive gate into the full replacement renderer, physical Android/iPhone profiling and final art/playtesting remain outside the completed validation. No account, backend, real-money purchase or store publication was added to gameplay.
