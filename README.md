# Skyway Courier

An original, offline, true 3D endless runner made with Flutter and Dart. Guide a pizza-delivery courier through elevated skyways, stations and service tunnels while a police officer pursues. Native and browser builds use the upgraded human couriers, police pursuer and environments through Flutter Scene. Change lanes, jump, slide, collect coins, complete missions, and unlock the rest of the crew.

See [the character/world upgrade](docs/UPGRADE.md), [current validation](docs/UPGRADE_VALIDATION.md), and [the pending Rive rendering gate](docs/RIVE_GATE.md).

The [mobile interface redesign](docs/MOBILE_UI.md) adds a mint-and-gold lobby, outfit showcase, delivery goals, compact gameplay HUD and matching menus on browser and native builds. Screenshots and repeatable UI checks are linked there.

## Run

Requires **Flutter 3.47.2**. The project pins **flutter_scene 0.23.0** and the compatible **flutter_soloud 4.1.7**; SoLoud 5.x conflicts with Scene's build-hook dependency.

The repository pins Flutter **3.47.2** (revision `d3b14c8769`) and all Dart packages. The wrapper uses `SKYWAY_FLUTTER_SDK`, a project-local SDK, or the separate compatible SDK already installed on this machine. It does not upgrade a global Flutter installation. Generated Flutter Scene files are deliberately excluded because they are engine-specific; Flutter's build hook recreates them from the committed GLB assets.

```sh
# Configure the local SDK (reuses the separate installation if available):
./tool/bootstrap_sdk.sh

./tool/flutterw pub get
./tool/flutterw run -d chrome
# Native desktop development:
./tool/flutterw run -d macos --enable-flutter-gpu
# Connected Android/iOS device:
./tool/flutterw devices
./tool/flutterw run -d DEVICE_ID --enable-flutter-gpu
```

On Windows PowerShell use:

```powershell
.\tool\bootstrap_sdk.ps1
.\tool\flutterw.ps1 pub get
.\tool\flutterw.ps1 run -d chrome
```

FVM users can run `fvm install` and `fvm flutter pub get`; `.fvmrc` carries the same SDK pin. Android development also requires Android Studio/SDK and Java 17. iOS and macOS builds require macOS with Xcode. Chrome works on macOS, Windows, and Linux. Platform signing credentials are intentionally not stored in the repository.

VS Code uses `.toolchain/flutter`. After bootstrap, reload the VS Code window and select **Skyway Courier — Chrome** to run the browser preview. If dependency resolution reports Dart 3.10.1, an older global Flutter is being used: run the commands above with `./tool/flutterw` instead of plain `flutter`. Flutter 3.47.2 already includes the required Dart 3.13.2; no SDK constraint downgrade is needed.

Native platform manifests enable Flutter GPU for packaged builds too. Mobile uses portrait orientation; desktop and browser center the game in a portrait panel. All menus, models, and audio ship locally. The web preview uses local CanvasKit files and waits for the bundled SoLoud WASM before launching Dart. Serve `build/web` over HTTP rather than opening its HTML as a file.

## Controls and progression

- Swipe left/right or use arrows/A/D to change lanes.
- Swipe up / arrow up / W jumps; swipe down / arrow down / S slides.
- P or Escape pauses. Space starts another run from home or game over.
- The first run teaches each gesture before starting the world. Training can be replayed in Settings.
- Missions run in sets of three. Claiming a completed set earns 300 coins and improves the score multiplier up to 5×.
- PIP is free; VOLT costs 1,000 coins and NOVA costs 3,000. Outfits differ visually; existing character IDs and purchases are preserved.
- Magnet, shield, double score, and double coins start at eight seconds. Four upgrades add two seconds each and cost 250/500/1,000/2,000 coins. Shield always absorbs one collision.
- One revive costs 100 coins and requires at least 100 coins banked before the run. Reviving clears hazards, counts down, and grants three seconds of protection.
- Progress saves at run boundaries and backgrounding. A settlement ledger prevents duplicate rewards across revival/relaunch, writes are serialized, and a previous valid save is retained for recovery.

## Architecture

`lib/game` contains the deterministic simulation, 3D scene adapter, collision queries, and audio controller. `lib/data` owns versioned repositories and economy rules. `lib/app` connects gameplay events to progression. `lib/features` contains Flutter screens and input handling.

The simulation runs at 120 fixed steps per second and interpolates rendering. Eight 24-meter chunks recycle with fixed obstacle/coin slots. Lane centers are -2/0/2; the player remains at Z=0. Collision uses a swept capsule reduced to an exact swept-sphere/AABB distance calculation, including rounded corners. Gaps have real missing floor geometry and ground checks.

Generation uses a reproducible 31-bit PRNG and a conservative fairness proof across chunk boundaries. Every row retains a reachable grounded safe lane; moving hazards reserve their entire travel corridor. Jump/slide routes provide additional options, but the validator never depends on a perfect jump or slide to prove survival. Rejected patterns fall back to clear track.

## Checks

```sh
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw test integration_test/scene_test.dart -d macos --enable-flutter-gpu
./tool/flutterw build web --release
./tool/flutterw build macos --release
./tool/flutterw build apk --debug
./tool/flutterw build ios --debug --no-codesign
```

The unit suite includes 10,000 generated chunk combinations and 30 simulated minutes of uninterrupted safe-route running. The native integration test loads every courier and renders all required animation states. Additional native tests cover cancelled loading, portrait HUD, input timing, real-time endurance and repeated navigation.

For browser flow testing, serve the web build on port 8124, install Playwright outside the game project, and run `tool/verify_web.cjs` as described in its header.

F3 toggles runtime diagnostics and F4 displays the player collider in development builds. For diagnostics in a release build add `--dart-define=SKYWAY_DEBUG=true`. Input recording retains the latest 4,096 tick-indexed commands. To run the isolated prototype with automatic route following:

```sh
./tool/flutterw run -d chrome -t tool/soak_app.dart --dart-define=SKYWAY_SOAK=true
```

For the recorded browser heap protocol, use `tool/soak_web.cjs` against a served prototype release build. Its results are measurements, not an automatic memory-stability certification.

See [asset sources](docs/ASSETS.md) and [validation results](docs/VALIDATION.md). Physical-phone profiling and distribution signing are release requirements; desktop checks do not establish mobile frame rate.
