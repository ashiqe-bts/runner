import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:skyway_courier/app/app_controller.dart';
import 'package:skyway_courier/data/repositories.dart';
import 'package:skyway_courier/features/skyway_app.dart';
import 'package:skyway_courier/game/runner_game.dart';

class EphemeralStore implements SaveStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Fixed-size histograms prevent instrumentation itself growing during a soak.
class TimingHistogram {
  final bins = List<int>.filled(2001, 0);
  int count = 0, overBudget = 0;
  void add(Duration duration) {
    bins[(duration.inMicroseconds / 100).round().clamp(0, 2000)]++;
    count++;
    if (duration.inMicroseconds > 16667) overBudget++;
  }

  double percentile(double q) {
    var total = 0;
    for (var i = 0; i < bins.length; i++) {
      total += bins[i];
      if (total >= count * q) return i / 10;
    }
    return 200;
  }

  Map<String, Object> toJson() => {
    'frames': count,
    'p50_ms': percentile(.50),
    'p95_ms': percentile(.95),
    'p99_ms': percentile(.99),
    'over_16_67_ms': overBudget,
    'histogram_cap_ms': 200,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'native endurance and repeated navigation',
    (tester) async {
      const minutes = int.fromEnvironment(
        'SKYWAY_SOAK_MINUTES',
        defaultValue: 30,
      );
      final app = AppController(store: EphemeralStore());
      await app.initialize();
      expect(app.error, isNull);
      app.progress.completeTutorial();
      app.startRun();
      const startMeters = int.fromEnvironment('SKYWAY_SOAK_START_METERS');
      app.game.distance = startMeters.toDouble();
      app.game.speed = GameConfig.speedAt(app.game.distance);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: key,
            child: SkywayScreen(controller: app, observeLifecycle: false),
          ),
        ),
      );
      final build = TimingHistogram(),
          raster = TimingHistogram(),
          total = TimingHistogram();
      void timing(List<ui.FrameTiming> frames) {
        for (final frame in frames) {
          build.add(frame.buildDuration);
          raster.add(frame.rasterDuration);
          total.add(frame.totalSpan);
        }
      }

      SchedulerBinding.instance.addTimingsCallback(timing);
      final samples = <Map<String, Object>>[];
      final watch = Stopwatch()..start();
      final pool = app.game.objectCount;
      final sceneNodes = app.view.scene.root.children.length;
      try {
        for (var minute = 0; minute <= minutes; minute++) {
          if (minute > 0) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(minutes: 1)),
            );
          }
          final sample = <String, Object>{
            'seconds': watch.elapsedMilliseconds / 1000,
            'rss_bytes': ProcessInfo.currentRss,
            'peak_rss_bytes': ProcessInfo.maxRss,
            'distance_m': app.game.distance,
            'tick': app.game.tick,
            'phase': app.game.phase.name,
            'pool_objects': app.game.objectCount,
            'scene_roots': app.view.scene.root.children.length,
            'build': build.toJson(),
            'raster': raster.toJson(),
            'total_span': total.toJson(),
          };
          samples.add(sample);
          debugPrint('SOAK ${jsonEncode(sample)}');
          expect(app.game.objectCount, pool);
          expect(app.view.scene.root.children.length, sceneNodes);
          expect(app.game.phase, RunPhase.running);
          expect(tester.takeException(), isNull);
        }
        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
        // Reuse the loaded scene through restarts and menus, as production does.
        for (var i = 0; i < 20; i++) {
          app.pause();
          final tick = app.game.tick;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          expect(app.game.tick, tick);
          app.resume();
          app.navigate(AppPage.characters);
          app.preview(['pip', 'volt', 'nova'][i % 3]);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          app.navigate(AppPage.home);
          app.startRun();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          expect(app.game.objectCount, pool);
          expect(app.view.scene.root.children.length, sceneNodes);
          expect(tester.takeException(), isNull);
        }
        final result = <String, Object>{
          'mode': kProfileMode
              ? 'profile'
              : kReleaseMode
              ? 'release'
              : 'debug',
          'platform': Platform.operatingSystem,
          'lifecycle': 'Foreground-independent harness; explicit pause tested separately',
          'requested_minutes': minutes,
          'start_distance_m': startMeters,
          'elapsed_seconds': watch.elapsedMilliseconds / 1000,
          'restart_navigation_cycles': 20,
          'samples': samples,
          'final_rss_bytes': ProcessInfo.currentRss,
          'build': build.toJson(),
          'raster': raster.toJson(),
          'total_span': total.toJson(),
        };
        binding.reportData = result;
        await tester.runAsync(() async {
          final directory = Directory(
            '${Directory.systemTemp.path}/skyway-validation',
          )..createSync();
          await File(
            '${directory.path}/native-soak.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${directory.path}/native-soak.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          debugPrint('ARTIFACTS ${directory.path}');
        });
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(timing);
        await tester.pumpWidget(const SizedBox());
      }
    },
    timeout: const Timeout(Duration(minutes: 45)),
    skip: !const bool.fromEnvironment('SKYWAY_SOAK'),
  );
}
