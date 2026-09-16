# Mobile interface redesign

The lobby and menus use a mint-and-gold illustrated interface, with a large 3D courier showcase, delivery-goal progress, earned coins, outfit previews, and a gold Play button. Upgrades, Home and Missions remain reachable through the bottom navigation. Settings and Couriers have their own lobby shortcuts.

The same interface ships on Chrome and native platforms. No new currency, energy mechanic, online service or purchase type was added. Outfit arrows only preview; purchasing/selecting remains explicit. Play always uses the saved selected courier.

## Implementation

- Shared theme, cards, counters, buttons and vector backdrop live in `lib/features/courier_ui.dart`; the responsive home/character screen and navigation live in `lib/features/lobby_screen.dart`.
- Fredoka is bundled in `assets/fonts/` with its SIL Open Font License, registered in Flutter's license registry. Source: [Google Fonts Fredoka](https://github.com/google/fonts/tree/main/ofl/fredoka). The UI needs no runtime font download.
- `ScenePresentation.lobby` hides gameplay scenery and shows a gold platform with brighter ambient lighting. Switching to gameplay restores scene visibility and lighting without changing simulation state. Models, collisions and progression are unchanged.
- Primary actions and bottom navigation remain outside the scrolling lobby content. Compact screens and enlarged text scroll the showcase area; secondary screens and result dialogs scroll. Interactive controls use at least 48 logical pixels. The portrait canvas is centered at a maximum width of 500 pixels on large displays.
- Flutter's Material feedback handles button presses without additional animation loops; the existing idle animation remains on the authoritative scene clock. The static backdrop and platform do not add motion, and reduced-motion camera behavior remains supported.
- Runtime diagnostics are now opt-in with F3 or `--dart-define=SKYWAY_DEBUG=true`, so normal debug launches show the mobile UI without a diagnostic overlay.

## Repeatable checks

```sh
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw test integration_test/scene_test.dart -d macos
./tool/flutterw test integration_test/ui_test.dart -d macos
./tool/flutterw build web --release
python3 -m http.server 8124 --directory build/web
# In another terminal, after installing Playwright outside this repository:
SKYWAY_PLAYWRIGHT=/tmp/skyway-browser/node_modules/playwright node tool/verify_web.cjs
SKYWAY_PLAYWRIGHT=/tmp/skyway-browser/node_modules/playwright node tool/review_mobile_ui.cjs
```

`test/mobile_ui_test.dart` exercises all menu screens, the four-power HUD, tutorial, pause, game-over and revival layouts at 320×568, 360×780, 390×844, 430×932, 1024×768 and 1440×900, both normal and 1.6× text size with safe-area insets. It also checks preview/selection separation and insufficient funds. Renderer-free widget checks are complemented by actual Chrome captures and native GPU smoke tests.

Browser review images are saved in `docs/screenshots/mobile-ui/`. Physical phone performance remains a separate release requirement; this UI pass does not replace device profiling.

For browser development, a Flutter hot restart can leave the existing SoLoud WASM player uninitialized. If that occurs, stop `flutter run` and launch Chrome again; a fresh launch restores audio. The final preview was opened with a fresh launch.

## Recorded results — 2026-09-16

- Static analysis passed; all 59 automated tests passed, including the 12 viewport/text-scale combinations and outfit purchase/selection checks. Loading and retry layouts are included.
- The Chrome release build passed. Browser flow checks passed for tutorial, controls, pause, every menu, rewards and save/reload. The screenshot review additionally checked the locked outfit preview and resume action.
- Native macOS GPU smoke checks passed for all animation tracks and switching lobby/gameplay presentation without changing simulation position or distance. Native UI checks passed for portrait HUD rendering, four active powers, background pause and explicit resume.
- Browser review uses Flutter's semantic button actions where its generated accessibility elements intercept synthetic pointer clicks. Widget tests exercise Flutter hit testing; hardware touch testing is still a physical-device check.

Review: [lobby](screenshots/mobile-ui/home-390.png), [couriers](screenshots/mobile-ui/couriers.png), [gameplay](screenshots/mobile-ui/gameplay.png), [missions](screenshots/mobile-ui/missions.png), [upgrades](screenshots/mobile-ui/upgrades.png), [settings](screenshots/mobile-ui/settings.png), [pause](screenshots/mobile-ui/pause.png).
