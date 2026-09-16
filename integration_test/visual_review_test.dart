import 'package:vector_math/vector_math.dart' as vm;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:skyway_courier/game/game_scene.dart';
import 'package:skyway_courier/game/runner_game.dart';
import 'package:skyway_courier/game/runner_renderer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'record every native animation and environment in portrait',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory('${Directory.systemTemp.path}/skyway-review')
        ..createSync();
      for (final enhanced in [false, true]) {
        final game = RunnerGame()..start(seed: 44);
        final view = GameScene(game, enhanced: enhanced);
        await view.initialize();
        final key = GlobalKey();
        final name = enhanced ? 'after' : 'before';
        var frame = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xff173d49),
              body: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: const Color(0xff173d49),
                  child: SceneView(
                    view.scene,
                    cameraBuilder: (_) => view.camera(),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> capture() async {
          await tester.pump(const Duration(milliseconds: 1));
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/$name-${frame.toString().padLeft(4, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          frame++;
        }

        for (var biome = 0; biome < 3; biome++) {
          game.start(seed: 44);
          for (final chunk in game.chunks) {
            chunk.definition = ChunkDefinition(
              biome * 12,
              0,
              chunk.definition.obstacles,
              PowerUp.values[biome],
            );
            for (final obstacle in chunk.obstacles) {
              obstacle.active = false;
            }
            chunk.powerActive = true;
          }
          // Present every hazard beside a guaranteed clear center lane.
          final obstacle = game.chunks[2].obstacles.first;
          obstacle
            ..active = true
            ..kind = Hazard.values[biome]
            ..lane = -1
            ..x = -2
            ..previousX = -2
            ..z = 22
            ..previousZ = 22;
          for (var f = 0; f < 36; f++) {
            final elapsed = game.advance(1 / 12);
            view.update(PresentationSnapshot(game, elapsed: elapsed));
            await capture();
          }
        }
        if (enhanced) {
          for (final outfit in ['pip', 'volt', 'nova']) {
            view.select(outfit);
            game.phase = RunPhase.paused;
            for (final state in PlayerState.values) {
              game.playerState = state;
              game.captured = state == PlayerState.captured;
              for (var f = 0; f < 8; f++) {
                game.y = state == PlayerState.jumping
                    ? f / 7 * 1.5
                    : state == PlayerState.falling
                    ? (1 - f / 7) * 1.5
                    : 0;
                game.previousY = game.y;
                view.sync(1 / 12);
                view.player.rotation = vm.Quaternion.identity();
                view.officer?.rotation = vm.Quaternion.identity();
                view.scene.update(1 / 12);
                await capture();
              }
            }
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        view.dispose();
        view.dispose(); // Disposal is safe before/after loading and repeatable.
        game.dispose();
      }
      debugPrint('REVIEW_FRAMES ${directory.path}');
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !const bool.fromEnvironment('SKYWAY_RECORD_REVIEW'),
  );
}
