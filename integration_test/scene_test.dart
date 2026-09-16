import 'package:skyway_courier/game/runner_renderer.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:skyway_courier/game/runner_game.dart';
import 'package:skyway_courier/game/game_scene.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native GPU loads skins and renders every required animation', (
    tester,
  ) async {
    final game = RunnerGame()..start();
    final view = GameScene(game);
    await view.initialize();
    final originalX = game.x, originalDistance = game.distance;
    view.setPresentation(ScenePresentation.lobby);
    expect(view.lobbyPlatform!.visible, isTrue);
    expect(view.world.visible, isFalse);
    expect(view.player.visible, isTrue);
    view.setPresentation(ScenePresentation.gameplay);
    expect(view.lobbyPlatform!.visible, isFalse);
    expect(view.world.visible, isTrue);
    expect(game.x, originalX);
    expect(game.distance, originalDistance);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xff173d49),
          body: RepaintBoundary(
            key: key,
            child: SceneView(
              view.scene,
              cameraBuilder: (_) => view.camera(),
              onTick: (_, dt) => view.update(
                PresentationSnapshot(game, elapsed: game.advance(dt)),
              ),
            ),
          ),
        ),
      ),
    );
    for (final id in ['pip', 'volt', 'nova']) {
      view.select(id);
      expect(view.models[id]!.parsedAnimations.length, 12);
      for (final state in PlayerState.values) {
        game.playerState = state;
        game.phase = RunPhase.paused;
        view.sync(.1);
        view.scene.update(.1);
        await tester.pump(const Duration(milliseconds: 100));
        expect(view.models[id]!.getChildByName('Head'), isNotNull);
        expect(tester.takeException(), isNull);
      }
    }
    game.phase = RunPhase.running;
    game.playerState = PlayerState.running;
    view.select('pip');
    view.sync(.016);
    view.scene.update(.016);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = '${Directory.systemTemp.path}/skyway-enhanced.png';
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      debugPrint('SCREENSHOT $path');
      image.dispose();
    });
    final run = view.clips['pip']!['Run']!;
    final time = run.playbackTime, weight = run.weight;
    view.pause(true);
    view.update(PresentationSnapshot(game, elapsed: 1));
    expect(run.playbackTime, time);
    expect(run.weight, weight);
    view.pause(false);
    await tester.pumpWidget(const SizedBox());
    view.dispose();
    game.dispose();
  });
}
