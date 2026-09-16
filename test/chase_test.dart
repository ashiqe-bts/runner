import 'package:flutter_test/flutter_test.dart';
import 'package:skyway_courier/game/runner_game.dart';

void step(RunnerGame g, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) {
    g.advance(GameConfig.step);
  }
}

RunnerGame empty() {
  final g = RunnerGame()..start();
  for (final c in g.chunks) {
    for (final o in c.obstacles) {
      o.active = false;
    }
  }
  return g;
}

void hit(RunnerGame g, Hazard hazard) {
  final o = g.chunks.first.obstacles.first;
  o
    ..active = true
    ..passed = false
    ..kind = hazard
    ..lane = 0
    ..secondLane = 1
    ..x = 0
    ..previousX = 0
    ..z = .2
    ..previousZ = .2;
  step(g, .025);
}

void main() {
  test('HUD snapshot is safe before loading and remains immutable', () {
    final g = RunnerGame();
    final cold = g.snapshot;
    expect(cold.biome, 'SKYWAY');
    g.start();
    g.activate(PowerUp.shield);
    final snapshot = g.snapshot;
    g.powers.clear();
    expect(snapshot.powers, contains(PowerUp.shield));
    expect(() => snapshot.powers.clear(), throwsUnsupportedError);
  });
  test('a stumble grants no protection against another hazard', () {
    final g = empty();
    hit(g, Hazard.low);
    hit(g, Hazard.blocker);
    expect(g.phase, RunPhase.dying);
    final other = empty();
    hit(other, Hazard.high);
    hit(other, Hazard.low);
    expect(other.captured, isTrue);
  });
  test('pause also freezes a capture in progress', () {
    final g = empty();
    hit(g, Hazard.low);
    hit(g, Hazard.high);
    expect(g.captured, isTrue);
    final time = g.phaseTime;
    g.pause();
    step(g, 3);
    expect(g.phaseTime, time);
    expect(g.phase, RunPhase.paused);
    g.resume();
    expect(g.phase, RunPhase.dying);
  });
  test('first minor collision stumbles and consumes that obstacle', () {
    final g = empty();
    hit(g, Hazard.low);
    expect(g.phase, RunPhase.running);
    expect(g.playerState, PlayerState.stumbling);
    expect(g.pursuitRecovery, closeTo(6, .03));
    expect(g.chunks.first.obstacles.first.active, isFalse);
    step(g, .7);
    expect(g.phase, RunPhase.running);
    hit(g, Hazard.high);
    expect(g.captured, isTrue);
    expect(g.phase, RunPhase.dying);
    step(g, 1.1);
    expect(g.phase, RunPhase.dead);
    expect(g.playerState, PlayerState.captured);
  });
  test('six clean seconds recover from pursuit', () {
    final g = empty();
    hit(g, Hazard.high);
    step(g, 6.1);
    expect(g.pursuitRecovery, 0);
    hit(g, Hazard.low);
    expect(g.phase, RunPhase.running);
    expect(g.captured, isFalse);
  });
  test('shield takes precedence over pursuit consequences', () {
    final g = empty();
    hit(g, Hazard.low);
    step(g, .7);
    g.activate(PowerUp.shield);
    hit(g, Hazard.high);
    expect(g.phase, RunPhase.running);
    expect(g.captured, isFalse);
    expect(g.powers.containsKey(PowerUp.shield), isFalse);
  });
  test('major collisions remain fatal after a stumble', () {
    for (final hazard in [
      Hazard.blocker,
      Hazard.drone,
      Hazard.gap,
      Hazard.wide,
    ]) {
      final g = empty();
      hit(g, Hazard.low);
      step(g, .7);
      hit(g, hazard);
      expect(g.phase, RunPhase.dying, reason: hazard.name);
      expect(g.captured, isFalse);
    }
  });
  test('pause freezes recovery; revive restores a safe chase', () {
    final g = empty();
    hit(g, Hazard.low);
    final recovery = g.pursuitRecovery;
    g.pause();
    step(g, 10);
    expect(g.pursuitRecovery, recovery);
    g.resume();
    step(g, .7);
    hit(g, Hazard.high);
    step(g, 1.1);
    g.revive();
    expect(g.pursuitRecovery, 0);
    expect(g.captured, isFalse);
    expect(g.invulnerability, 3);
    expect(g.phase, RunPhase.reviving);
  });
  test(
    'pace follows the new curve and ordinary stalls retain simulation time',
    () {
      expect(GameConfig.speedAt(0), 12);
      expect(GameConfig.speedAt(1000), 17);
      expect(GameConfig.speedAt(2000), 22);
      expect(GameConfig.speedAt(9000), 22);
      final a = empty(), b = empty();
      a.advance(.25);
      step(b, .25);
      expect(a.distance, closeTo(b.distance, 1e-8));
      expect(a.tick, b.tick);
    },
  );
}
