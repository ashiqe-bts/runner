import 'runner_game.dart';

enum ScenePresentation { gameplay, lobby }

/// Renderer-neutral, immutable presentation input. Elapsed time comes from the
/// simulation's fixed steps; rendering never advances gameplay itself.
class PresentationSnapshot {
  final double elapsed, x, y, speed, pursuitRecovery, stumbleRecovery;
  final int tick;
  final RunPhase phase;
  final PlayerState animation;
  final bool captured;

  PresentationSnapshot(RunnerGame game, {required this.elapsed})
    : x = game.renderX,
      y = game.renderY,
      speed = game.speed,
      pursuitRecovery = game.pursuitRecovery,
      stumbleRecovery = game.stumbleAnimation,
      tick = game.tick,
      phase = game.phase,
      animation = game.playerState,
      captured = game.captured;
}

abstract interface class RunnerRenderer {
  void setPresentation(ScenePresentation mode);
  Future<void> initialize();
  void update(PresentationSnapshot frame);
  void pause(bool paused);
  void dispose();
}
