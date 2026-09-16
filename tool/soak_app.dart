import 'package:skyway_courier/game/runner_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';

import 'package:skyway_courier/game/game_scene.dart';
import 'package:skyway_courier/game/runner_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: Prototype()),
  );
}

class Prototype extends StatefulWidget {
  const Prototype({super.key});
  @override
  State<Prototype> createState() => _PrototypeState();
}

class _PrototypeState extends State<Prototype> {
  final focus = FocusNode();
  late final RunnerGame game;
  late final GameScene view;
  bool ready = false;
  String? error;
  double elapsed = 0, fps = 60;
  Offset? start;
  @override
  void initState() {
    super.initState();
    focus.requestFocus();
    game = RunnerGame();
    game.start();
    view = GameScene(game);
    view
        .initialize()
        .then((_) {
          if (mounted) setState(() => ready = true);
        })
        .catchError((Object e, StackTrace s) {
          debugPrint('$e\n$s');
          if (mounted) setState(() => error = '$e');
        });
  }

  @override
  void dispose() {
    focus.dispose();
    view.dispose();
    game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff102b3d),
    body: !ready
        ? Center(
            child: error != null
                ? Text(error!, style: const TextStyle(color: Colors.white))
                : const CircularProgressIndicator(),
          )
        : KeyboardListener(
            focusNode: focus,
            onKeyEvent: (e) {
              if (e is KeyDownEvent) {
                final cmd = {
                  LogicalKeyboardKey.arrowLeft: InputCommand.left,
                  LogicalKeyboardKey.arrowRight: InputCommand.right,
                  LogicalKeyboardKey.arrowUp: InputCommand.jump,
                  LogicalKeyboardKey.arrowDown: InputCommand.slide,
                }[e.logicalKey];
                if (cmd != null) game.submit(cmd);
                if (e.logicalKey == LogicalKeyboardKey.space) game.restart();
              }
            },
            child: GestureDetector(
              onPanStart: (e) => start = e.localPosition,
              onPanEnd: (_) => start = null,
              onPanUpdate: (e) {
                if (start == null) return;
                final d = e.localPosition - start!;
                if (d.distance > 24) {
                  game.submit(
                    d.dx.abs() > d.dy.abs()
                        ? (d.dx < 0 ? InputCommand.left : InputCommand.right)
                        : (d.dy < 0 ? InputCommand.jump : InputCommand.slide),
                  );
                  start = null;
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: SceneView(
                      view.scene,
                      cameraBuilder: (_) => view.camera(),
                      onTick: (_, dt) {
                        if (const bool.fromEnvironment('SKYWAY_SOAK')) {
                          final ahead =
                              game.chunks.where((c) => c.z + 12 > -2).toList()
                                ..sort((a, b) => a.z.compareTo(b.z));
                          if (ahead.isNotEmpty) {
                            final target = ahead.first.definition.safeLane;
                            if (game.lane < target) {
                              game.submit(InputCommand.right);
                            }
                            if (game.lane > target) {
                              game.submit(InputCommand.left);
                            }
                          }
                        }
                        view.update(
                          PresentationSnapshot(game, elapsed: game.advance(dt)),
                        );
                        elapsed += dt;
                        if (elapsed > .2) {
                          elapsed = 0;
                          if (mounted) {
                            setState(() => fps = dt > 0 ? 1 / dt : 60);
                          }
                        }
                      },
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'SKYWAY COURIER\n${game.score.floor()} M     ${game.coins} COINS\n${fps.toStringAsFixed(0)} FPS  •  ${game.phase.name}\nSwipe / arrow keys to move',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (game.phase == RunPhase.dead)
                    Center(
                      child: FilledButton(
                        onPressed: () => setState(game.restart),
                        child: const Text('RUN AGAIN'),
                      ),
                    ),
                ],
              ),
            ),
          ),
  );
}
