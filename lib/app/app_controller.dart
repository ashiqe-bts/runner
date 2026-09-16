import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories.dart';
import '../game/audio_controller.dart';
import '../game/game_scene.dart';
import '../game/runner_game.dart';
import '../game/runner_renderer.dart';

enum AppPage { home, game, characters, missions, upgrades, settings }

class AppController extends ChangeNotifier {
  AppController({
    SaveStore? store,
    GameScene Function(RunnerGame)? sceneFactory,
  }) : progress = ProgressRepository(store ?? PreferencesStore()) {
    settings = SettingsRepository(progress);
    characters = CharacterRepository(progress);
    audio = AudioController(settings);
    game = RunnerGame(onEvent: _event);
    view = (sceneFactory ?? GameScene.new)(game);
    hud = ValueNotifier(game.snapshot);
    progress.addListener(_progressChanged);
  }
  final ProgressRepository progress;
  late final SettingsRepository settings;
  late final CharacterRepository characters;
  late final AudioController audio;
  late final RunnerGame game;
  late GameScene view;
  late final ValueNotifier<HudSnapshot> hud;
  AppPage page = AppPage.home;
  bool ready = false,
      loading = false,
      disposed = false,
      debug = const bool.fromEnvironment('SKYWAY_DEBUG');
  String? error;
  String previewCharacter = 'pip';
  int runId = 0, bankAtStart = 0;
  double _hudTime = 0, fps = 60, frameMs = 16.7, _fpsSeconds = 0;
  int _fpsFrames = 0;
  final stats = <String, double>{};
  double _cleanStart = 0;
  Future<void> initialize() async {
    if (loading || disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await progress.load();
      if (disposed) return;
      game.start();
      game.phase = RunPhase.home;
      view.dispose();
      view = GameScene(game);
      await view.initialize();
      if (disposed) return;
      previewCharacter = progress.snapshot.selected;
      view.select(previewCharacter);
      view.setPresentation(ScenePresentation.lobby);
      await audio.initialize();
      if (disposed) return;
      ready = true;
    } catch (e, s) {
      error = 'The skyway could not load. Please try again.';
      debugPrint('$e\n$s');
    } finally {
      loading = false;
      if (!disposed) notifyListeners();
    }
  }

  void _progressChanged() {
    if (disposed) return;
    audio.applySettings();
    notifyListeners();
  }

  void navigate(AppPage next) {
    final keepPreview = page == AppPage.home && next == AppPage.characters;
    audio.play('button');
    audio.startMusic();
    if (next != AppPage.game) {
      if (game.phase == RunPhase.running || game.phase == RunPhase.paused) {
        _settle();
      }
      game.phase = RunPhase.home;
      game.x = 0;
      game.y = 0;
      game.previousX = 0;
      game.previousY = 0;
      game.lane = 0;
      if (!keepPreview) previewCharacter = progress.snapshot.selected;
      view.select(previewCharacter);
    }
    page = next;
    view.setPresentation(
      next == AppPage.game
          ? ScenePresentation.gameplay
          : ScenePresentation.lobby,
    );
    notifyListeners();
  }

  void startRun({bool replayTutorial = false}) {
    view.setPresentation(ScenePresentation.gameplay);
    bankAtStart = progress.snapshot.wallet;
    runId = progress.allocateRun();
    stats.clear();
    _cleanStart = 0;
    view.select(progress.snapshot.selected);
    for (final p in PowerUp.values) {
      game.levels[p] = progress.snapshot.levels[p.name]!;
    }
    game.start(
      seed: 928471 + runId * 7919,
      tutorial: replayTutorial || !progress.snapshot.tutorialCompleted,
      multiplier: progress.snapshot.multiplier,
    );
    audio.startMusic();
    page = AppPage.game;
    notifyListeners();
  }

  void _event(GameEvent e) {
    if (e.type == 'distance') return;
    if (ready &&
        (e.type == 'coin' || e.type == 'powerup' || e.type == 'shield')) {
      view.burst();
    }
    if (ready && (e.type == 'hit' || e.type == 'stumble')) view.shake = .22;
    if (e.type == 'barrier') stats['barriers'] = (stats['barriers'] ?? 0) + 1;
    if (e.type == 'slide') stats['slides'] = (stats['slides'] ?? 0) + 1;
    if (e.type == 'powerup' && e.value.toInt() == PowerUp.magnet.index) {
      stats['magnets'] = (stats['magnets'] ?? 0) + 1;
    }
    if (e.type == 'shield' || e.type == 'hit' || e.type == 'stumble') {
      final clean = game.distance - _cleanStart;
      if (clean > (stats['clean'] ?? 0)) stats['clean'] = clean;
      _cleanStart = game.distance;
    }
    if (e.type == 'tutorialDone') progress.completeTutorial();
    if (e.type == 'gameover') _settle();
    if (e.type == 'pause') audio.pause(true);
    if (e.type == 'resume') audio.pause(false);
    audio.play(e.type == 'shield' || e.type == 'stumble' ? 'hit' : e.type);
    audio.haptic(e.type);
  }

  void _settle() {
    if (runId == 0) return;
    final clean = game.distance - _cleanStart;
    if (clean > (stats['clean'] ?? 0)) stats['clean'] = clean;
    progress.settle(
      RunResult(
        id: runId,
        coins: game.coins,
        score: game.score.floor(),
        distance: game.distance,
        stats: Map.of(stats),
      ),
    );
  }

  bool get canRevive =>
      !game.revived && bankAtStart >= 100 && progress.snapshot.wallet >= 100;
  void revive() {
    if (game.phase != RunPhase.dead || !canRevive) return;
    if (progress.spendRevive(bankAtStart: bankAtStart)) {
      game.revive();
      audio.startMusic();
      notifyListeners();
    }
  }

  void pause() {
    game.pause();
    notifyListeners();
  }

  void resume() {
    game.resume();
    notifyListeners();
  }

  void preview(String id) {
    previewCharacter = id;
    view.select(id);
    notifyListeners();
  }

  bool unlockOrSelect() {
    final id = previewCharacter;
    if (!progress.snapshot.unlocked.contains(id) && !characters.unlock(id)) {
      return false;
    }
    characters.select(id);
    audio.play('powerup');
    notifyListeners();
    return true;
  }

  void tick(double dt) {
    if (!ready || disposed) return;
    if (const bool.fromEnvironment('SKYWAY_SOAK') &&
        page == AppPage.game &&
        game.phase == RunPhase.running) {
      final ahead = game.chunks.where((c) => c.z + 12 > -2).toList()
        ..sort((a, b) => a.z.compareTo(b.z));
      if (ahead.isNotEmpty) {
        final target = ahead.first.definition.safeLane;
        if (game.lane < target) game.submit(InputCommand.right);
        if (game.lane > target) game.submit(InputCommand.left);
      }
    }
    view.reduceMotion = settings.settings.reduceMotion;
    final elapsed = game.advance(dt);
    view.pause(game.phase == RunPhase.paused);
    view.update(
      PresentationSnapshot(
        game,
        elapsed: game.phase == RunPhase.home ? dt.clamp(0, .1) : elapsed,
      ),
    );
    audio.step(
      elapsed,
      game.phase == RunPhase.running && game.y == 0 && game.slideTime == 0,
      speed: game.speed,
    );
    _fpsFrames++;
    _fpsSeconds += dt;
    _hudTime += dt;
    if (_fpsSeconds >= 1) {
      fps = _fpsFrames / _fpsSeconds;
      frameMs = 1000 / fps;
      _fpsFrames = 0;
      _fpsSeconds = 0;
    }
    if (_hudTime >= .1) {
      _hudTime = 0;
      hud.value = game.snapshot;
    }
  }

  void background() {
    pause();
    audio.pause(true);
    if (runId > 0) _settle();
    unawaited(progress.flush());
  }

  @override
  void notifyListeners() {
    hud.value = game.snapshot;
    super.notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    progress.removeListener(_progressChanged);
    hud.dispose();
    game.dispose();
    view.dispose();
    audio.dispose();
    progress.dispose();
    super.dispose();
  }
}
