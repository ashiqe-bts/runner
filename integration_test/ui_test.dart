import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:skyway_courier/app/app_controller.dart';
import 'package:skyway_courier/features/skyway_app.dart';
import 'package:skyway_courier/features/courier_ui.dart';
import 'package:skyway_courier/game/runner_game.dart';

import 'native_soak_test.dart' show EphemeralStore;

class DelayedStore extends EphemeralStore {
  final gate = Completer<void>();
  @override
  Future<String?> read(String key) async {
    await gate.future;
    return super.read(key);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('cancelled loading does not recreate a disposed scene', (
    tester,
  ) async {
    final store = DelayedStore();
    final app = AppController(store: store);
    final loading = app.initialize();
    app.dispose();
    store.gate.complete();
    await loading;
    expect(app.ready, isFalse);
    expect(app.view.disposed, isTrue);
  });
  testWidgets(
    'native portrait UI, lifecycle and input-handler-to-frame latency',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(store: EphemeralStore());
      await app.initialize();
      expect(app.error, isNull);
      app.progress.completeTutorial();
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: courierTheme(),
          home: RepaintBoundary(
            key: key,
            child: SkywayScreen(controller: app, observeLifecycle: false),
          ),
        ),
      );
      final latencies = <double>[];
      for (var sample = 0; sample < 20; sample++) {
        app.startRun();
        await tester.pump();
        final listener = tester.widget<KeyboardListener>(
          find.byType(KeyboardListener),
        );
        await tester.pump(const Duration(milliseconds: 30));
        final presented = Completer<void>();
        void afterFrame(Duration _) {
          if (app.game.renderY > 0) {
            if (!presented.isCompleted) presented.complete();
          } else if (!presented.isCompleted) {
            SchedulerBinding.instance.addPostFrameCallback(afterFrame);
          }
        }

        SchedulerBinding.instance.addPostFrameCallback(afterFrame);
        final watch = Stopwatch()..start();
        listener.onKeyEvent!(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.arrowUp,
            logicalKey: LogicalKeyboardKey.arrowUp,
            timeStamp: Duration.zero,
          ),
        );
        await tester.runAsync(
          () => presented.future.timeout(const Duration(seconds: 2)),
        );
        latencies.add(watch.elapsedMicroseconds / 1000);
        debugPrint(
          'INPUT sample=$sample ms=${latencies.last} tick=${app.game.tick} phase=${app.game.phase} focused=${listener.focusNode.hasFocus} commands=${app.game.inputRecording.length}',
        );
        expect(app.game.renderY, greaterThan(0));
        expect(tester.takeException(), isNull);
      }
      app.game.activate(PowerUp.magnet);
      app.game.activate(PowerUp.shield);
      app.game.activate(PowerUp.score);
      app.game.activate(PowerUp.coins);
      app.background();
      final paused = app.game.snapshot;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      expect(app.game.phase, RunPhase.paused);
      expect(app.game.tick, paused.tick);
      expect(app.game.powers, paused.powers);
      app.resume();
      await tester.pump(const Duration(milliseconds: 200));
      expect(app.game.phase, RunPhase.running);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final directory = Directory('${Directory.systemTemp.path}/skyway-ui')
          ..createSync();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${directory.path}/portrait-hud.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        final result = {
          'mode': kProfileMode ? 'profile' : 'debug',
          'measurement': 'Synthetic native keyboard-handler callback to completed frame build with changed player transform; excludes focus routing, OS input, hardware, raster completion and scanout',
          'samples_ms': latencies,
        };
        binding.reportData = result;
        await File('${directory.path}/input-latency.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(result));
        debugPrint('UI_ARTIFACTS ${directory.path}');
      });
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
