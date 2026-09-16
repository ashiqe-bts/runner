import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyway_courier/app/app_controller.dart';
import 'package:skyway_courier/data/repositories.dart';
import 'package:skyway_courier/features/courier_ui.dart';
import 'package:skyway_courier/features/skyway_app.dart';
import 'package:skyway_courier/game/runner_game.dart';
import 'package:skyway_courier/game/game_scene.dart';
import 'package:skyway_courier/game/runner_renderer.dart';

class LayoutScene extends GameScene {
  LayoutScene(super.game);
  @override
  void setPresentation(ScenePresentation mode) {
    presentation = mode;
  }

  @override
  void select(String id) {
    character = id;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class UiStore implements SaveStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

Future<AppController> mount(
  WidgetTester tester,
  Size size, {
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = AppController(store: UiStore(), sceneFactory: LayoutScene.new);
  await app.progress.load();
  app.game.start();
  app.game.phase = RunPhase.home;
  app.ready = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: courierTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 28, bottom: 20),
        ),
        child: child!,
      ),
      home: SkywayScreen(
        controller: app,
        sceneBuilder: (_, _) => const SizedBox.expand(),
      ),
    ),
  );
  return app;
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 780),
    const Size(390, 844),
    const Size(430, 932),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'all screens fit $size at text scale $scale with safe areas',
        (tester) async {
          final app = await mount(tester, size, scale: scale);
          for (final page in AppPage.values) {
            app.navigate(page);
            if (page == AppPage.game) {
              app.startRun();
              app.game.powers.addAll({
                for (final power in PowerUp.values) power: 8,
              });
              app.hud.value = app.game.snapshot;
            }
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '$page at $size / $scale',
            );
          }
          app.startRun();
          for (final phase in [
            RunPhase.paused,
            RunPhase.dead,
            RunPhase.reviving,
          ]) {
            app.game.phase = phase;
            app.hud.value = app.game.snapshot;
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '$phase at $size / $scale',
            );
          }
          app.ready = false;
          for (final error in [
            null,
            'The skyway could not load. Please try again.',
          ]) {
            app.error = error;
            app.navigate(AppPage.home);
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: 'loading/error at $size / $scale',
            );
            if (error != null) expect(find.text('TRY AGAIN'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'browsing is separate from selection and locked outfits cannot be purchased without coins',
    (tester) async {
      final app = await mount(tester, const Size(390, 844));
      await tester.tap(find.byTooltip('Next courier'));
      await tester.pump();
      expect(app.previewCharacter, 'volt');
      expect(app.progress.snapshot.selected, 'pip');
      await tester.tap(find.text('Couriers'));
      await tester.pump();
      expect(app.previewCharacter, 'volt');
      final unlock = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'UNLOCK • 1000 COINS'),
      );
      expect(unlock.onPressed, isNull);
      app.startRun();
      expect(app.progress.snapshot.selected, 'pip');
      expect(app.view.presentation.name, 'gameplay');
      app.navigate(AppPage.home);
      expect(app.previewCharacter, 'pip');
      expect(app.view.presentation.name, 'lobby');
      app.progress.settle(
        RunResult(
          id: app.progress.allocateRun(),
          coins: 1000,
          score: 100,
          distance: 10,
          stats: const {},
        ),
      );
      app.preview('volt');
      app.navigate(AppPage.characters);
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'UNLOCK • 1000 COINS'),
      );
      await tester.pump();
      expect(app.progress.snapshot.selected, 'volt');
      expect(app.progress.snapshot.wallet, 0);
      app.preview('nova');
      app.startRun();
      expect(app.view.character, 'volt');
      expect(app.progress.snapshot.selected, 'volt');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
