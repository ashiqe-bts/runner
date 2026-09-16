import 'package:flutter_test/flutter_test.dart';
import 'package:skyway_courier/game/runner_game.dart';

void advance(RunnerGame game, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) {
    game.advance(GameConfig.step);
  }
}

void safe(RunnerGame game) {
  for (final c in game.chunks) {
    for (final o in c.obstacles) {
      o.active = false;
    }
  }
}

void main() {
  test('lane transition is smooth, bounded and permits airborne changes', () {
    final g = RunnerGame()..start();
    g.submit(InputCommand.left);
    advance(g, .08);
    expect(g.x, greaterThan(-2));
    expect(g.x, lessThan(0));
    advance(g, .1);
    expect(g.x, -2);
    g.submit(InputCommand.left);
    advance(g, .2);
    expect(g.lane, -1);
    g.submit(InputCommand.jump);
    advance(g, .1);
    g.submit(InputCommand.right);
    advance(g, .2);
    expect(g.y, greaterThan(0));
    expect(g.lane, 0);
  });
  test('jump rejects slide and returns exactly to ground', () {
    final g = RunnerGame()..start();
    g.submit(InputCommand.jump);
    advance(g, .1);
    g.submit(InputCommand.slide);
    advance(g, .1);
    expect(g.slideTime, 0);
    advance(g, 1);
    expect(g.y, 0);
    expect(g.velocityY, 0);
  });
  test('slide times out and prevents jump while active', () {
    final g = RunnerGame()..start();
    g.submit(InputCommand.slide);
    advance(g, .1);
    g.submit(InputCommand.jump);
    advance(g, .1);
    expect(g.y, 0);
    advance(g, .6);
    expect(g.slideTime, 0);
  });
  test('pause freezes movement and power-up timers', () {
    final g = RunnerGame()..start();
    g.activate(PowerUp.magnet);
    g.pause();
    final d = g.distance, t = g.powers[PowerUp.magnet];
    advance(g, 3);
    expect(g.distance, d);
    expect(g.powers[PowerUp.magnet], t);
    g.resume();
    advance(g, .1);
    expect(g.distance, greaterThan(d));
  });
  test('fixed steps produce identical runs across frame rates', () {
    final a = RunnerGame()..start(seed: 8), b = RunnerGame()..start(seed: 8);
    for (var i = 0; i < 240; i++) {
      a.advance(1 / 60);
    }
    for (var i = 0; i < 120; i++) {
      b.advance(1 / 30);
    }
    expect(a.distance, closeTo(b.distance, 1e-8));
    expect(a.phase, b.phase);
    expect(a.coins, b.coins);
  });
  test('score multiplier only applies while active', () {
    final g = RunnerGame()..start(multiplier: 2);
    advance(g, 1);
    expect(g.score, closeTo(g.distance * 2, 1e-7));
    final before = g.score, d = g.distance;
    g.activate(PowerUp.score);
    advance(g, 1);
    expect(g.score - before, closeTo((g.distance - d) * 4, 1e-7));
  });
  test('same power refreshes and distinct powers coexist', () {
    final g = RunnerGame()..start();
    g.activate(PowerUp.score);
    advance(g, 1);
    g.activate(PowerUp.score);
    g.activate(PowerUp.coins);
    expect(g.powers[PowerUp.score], 8);
    expect(g.powers.length, 2);
  });
  test('all six hazards hit standing courier, shield consumes once', () {
    for (final kind in Hazard.values) {
      final g = RunnerGame()..start();
      safe(g);
      final o = g.chunks.first.obstacles.first;
      o.active = true;
      o.kind = kind;
      o.lane = 0;
      o.secondLane = 1;
      o.x = 0;
      o.previousX = 0;
      o.z = .2;
      o.previousZ = .2;
      g.activate(PowerUp.shield);
      advance(g, .02);
      expect(g.phase, RunPhase.running, reason: kind.name);
      expect(g.powers.containsKey(PowerUp.shield), false, reason: kind.name);
      expect(o.active, false);
    }
  });
  test('collision ends run and revival is limited', () {
    final g = RunnerGame()..start();
    safe(g);
    final o = g.chunks.first.obstacles.first;
    o.active = true;
    o.x = 0;
    o.z = .2;
    advance(g, .02);
    expect(g.phase, RunPhase.dying);
    advance(g, 1.1);
    expect(g.phase, RunPhase.dead);
    g.revive();
    expect(g.revived, true);
    advance(g, 3.1);
    expect(g.phase, RunPhase.running);
    expect(g.invulnerability, greaterThan(2));
  });
  test('jump clears low barrier and slide clears overhead', () {
    for (final kind in [Hazard.low, Hazard.high]) {
      final g = RunnerGame()..start();
      safe(g);
      g.submit(kind == Hazard.low ? InputCommand.jump : InputCommand.slide);
      advance(g, .25);
      final o = g.chunks.first.obstacles.first;
      o.active = true;
      o.kind = kind;
      o.x = 0;
      o.z = .1;
      advance(g, .05);
      expect(g.phase, RunPhase.running);
    }
  });
  test('validator rejects full lane blockage and excessive speed', () {
    final v = FairnessValidator();
    expect(
      v.accept(
        const ChunkDefinition(0, 0, [
          ObstacleSpawn(Hazard.blocker, -1, 12),
          ObstacleSpawn(Hazard.blocker, 0, 12),
          ObstacleSpawn(Hazard.blocker, 1, 12),
        ], null),
      ),
      false,
    );
    expect(v.accept(const ChunkDefinition(0, 0, [], null), speed: 100), false);
  });
  test('10,000 chunk combinations preserve a route at maximum speed', () {
    for (var seed = 1; seed <= 100; seed++) {
      final gen = ChunkGenerator(seed), validator = FairnessValidator();
      for (var i = 0; i < 100; i++) {
        final chunk = gen.next(i);
        expect(validator.accept(chunk), true, reason: 'seed=$seed chunk=$i');
        for (final o in chunk.obstacles) {
          expect(o.occupiedLanes.contains(chunk.safeLane), false);
        }
      }
    }
  });
  test('seed generation is reproducible', () {
    final a = ChunkGenerator(44), b = ChunkGenerator(44);
    for (var i = 0; i < 100; i++) {
      final x = a.next(i), y = b.next(i);
      expect(x.safeLane, y.safeLane);
      expect(x.obstacles.map((o) => o.kind), y.obstacles.map((o) => o.kind));
      expect(x.power, y.power);
    }
  });
  test('30 simulated minutes retain fixed pools and surviving safe routes', () {
    final g = RunnerGame()..start(seed: 237);
    final identities = g.chunks.map(identityHashCode).toList();
    for (var i = 0; i < 30 * 60 * 60; i++) {
      final ahead = g.chunks.where((c) => c.z + 12 > -2).toList()
        ..sort((a, b) => a.z.compareTo(b.z));
      if (ahead.isNotEmpty) {
        final lane = ahead.first.definition.safeLane;
        if (g.lane < lane) g.submit(InputCommand.right);
        if (g.lane > lane) g.submit(InputCommand.left);
      }
      g.advance(1 / 60);
      if (g.phase != RunPhase.running) {
        fail('Died tick ${g.tick} distance ${g.distance}');
      }
    }
    expect(g.chunks.map(identityHashCode), identities);
    expect(g.objectCount, 104);
    expect(g.inputRecording.length, lessThanOrEqualTo(4096));
    expect(g.distance, greaterThan(20000));
  });
  test('tutorial requires intended commands and finishes after coin', () {
    final g = RunnerGame()..start(tutorial: true);
    g.submit(InputCommand.jump);
    advance(g, .1);
    expect(g.tutorialStep, 0);
    for (final cmd in InputCommand.values) {
      g.submit(cmd);
      advance(g, cmd == InputCommand.slide ? 0.01 : 1);
    }
    expect(g.tutorialStep, 4);
    for (final c in g.chunks) {
      for (final coin in c.coins) {
        coin.active = false;
      }
    }
    final coin = g.chunks.first.coins.first;
    coin.active = true;
    coin.x = g.x;
    coin.y = 1;
    coin.z = .1;
    advance(g, .02);
    expect(g.tutorialStep, -1);
  });
}
