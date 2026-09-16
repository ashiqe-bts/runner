import 'dart:collection';
import 'dart:math' as math;

import 'collision.dart';

abstract final class GameConfig {
  static const step = 1 / 120;
  static const chunkLength = 24.0, laneWidth = 2.0;
  static const chunkCount = 8, coinSlots = 9;
  static const laneDuration = .16, slideDuration = .75;
  static const gravity = -24.0, jumpVelocity = 9.0;
  static const initialSpeed = 12.0, maxSpeed = 22.0;
  static const reactionTime = .65;
  static double speedAt(double distance) =>
      math.min(maxSpeed, initialSpeed + distance / 200);
}

enum InputCommand { left, right, jump, slide }

enum RunPhase { home, running, paused, dying, dead, reviving }

enum PlayerState {
  idle,
  running,
  jumping,
  falling,
  landing,
  sliding,
  hit,
  death,
  stumbling,
  captured,
}

enum Hazard { blocker, low, high, drone, gap, wide }

enum PowerUp { magnet, shield, score, coins }

class GameEvent {
  final String type;
  final double value;
  const GameEvent(this.type, [this.value = 1]);
}

class InputRecord {
  final int tick;
  final InputCommand command;
  const InputRecord(this.tick, this.command);
}

class HudSnapshot {
  final int score,
      coins,
      lane,
      tick,
      seed,
      baseMultiplier,
      tutorialStep,
      nextChunk,
      objectCount;
  final String biome;
  final double phaseTime, x, y;
  final double distance, speed, pursuitRecovery, renderX, renderY;
  final bool captured;
  final RunPhase phase;
  final PlayerState playerState;
  final Map<PowerUp, double> powers;
  HudSnapshot(RunnerGame game)
    : baseMultiplier = game.baseMultiplier,
      tutorialStep = game.tutorialStep,
      nextChunk = game.nextChunk,
      objectCount = game.objectCount,
      biome = game.nextChunk == 0 ? 'SKYWAY' : game.biome,
      phaseTime = game.phaseTime,
      x = game.x,
      y = game.y,
      score = game.score.floor(),
      coins = game.coins,
      lane = game.lane,
      tick = game.tick,
      seed = game.seed,
      pursuitRecovery = game.pursuitRecovery,
      renderX = game.renderX,
      renderY = game.renderY,
      captured = game.captured,
      distance = game.distance,
      speed = game.speed,
      phase = game.phase,
      playerState = game.playerState,
      powers = Map.unmodifiable(game.powers);
}

class ObstacleSpawn {
  final Hazard kind;
  final int lane;
  final double z;
  final int? secondLane;
  const ObstacleSpawn(this.kind, this.lane, this.z, [this.secondLane]);
  Set<int> get occupiedLanes => {lane, ?secondLane};
}

class ChunkDefinition {
  final int index, safeLane;
  final List<ObstacleSpawn> obstacles;
  final PowerUp? power;
  const ChunkDefinition(this.index, this.safeLane, this.obstacles, this.power);
  String get biome =>
      ['SKYWAY', 'CENTRAL STATION', 'SERVICE TUNNEL'][(index ~/ 12) % 3];
}

// Stable 31-bit PRNG: identical integer operations on Dart VM and JavaScript.
class SeedRandom {
  int value;
  SeedRandom(int seed) : value = seed & 0x7fffffff;
  int next(int n) {
    value = (value * 48271) % 2147483647;
    if (value == 0) value = 1;
    return value % n;
  }
}

class FairnessValidator {
  // Conservative proof: a grounded, hazard-free route must survive every row.
  // Jump/slide routes add options but are never required for the safety witness.
  Set<int> reachable = {-1, 0, 1};
  bool accept(
    ChunkDefinition definition, {
    double speed = GameConfig.maxSpeed,
  }) {
    final occupied = <int>{
      for (final o in definition.obstacles) ...o.occupiedLanes,
    };
    final candidates = {-1, 0, 1}.difference(occupied);
    final next = candidates
        .where(
          (lane) => reachable.any(
            (old) =>
                (lane - old).abs() * GameConfig.laneDuration +
                    GameConfig.reactionTime +
                    .25 <
                GameConfig.chunkLength / speed,
          ),
        )
        .toSet();
    if (next.isEmpty) return false;
    reachable = next;
    return true;
  }
}

class ChunkGenerator {
  final SeedRandom random;
  final validator = FairnessValidator();
  ChunkGenerator(int seed) : random = SeedRandom(seed);
  ChunkDefinition next(int index) {
    final safe = random.next(3) - 1;
    final other = [-1, 0, 1]..remove(safe);
    final tier = index * GameConfig.chunkLength < 500
        ? 0
        : index * GameConfig.chunkLength < 1500
        ? 1
        : 2;
    final hazards = <ObstacleSpawn>[];
    if (index > 1) {
      var kind = Hazard.values[random.next(tier == 0 ? 3 : 6)];
      if (kind == Hazard.wide && (other[0] - other[1]).abs() != 1) {
        kind = Hazard.blocker;
      }
      if (kind == Hazard.drone && (other[0] - other[1]).abs() != 1) {
        kind = Hazard.low;
      }
      hazards.add(
        ObstacleSpawn(
          kind,
          other[0],
          12,
          kind == Hazard.wide || kind == Hazard.drone ? other[1] : null,
        ),
      );
      if (tier > 0 && kind != Hazard.wide && kind != Hazard.drone) {
        hazards.add(ObstacleSpawn(Hazard.values[random.next(3)], other[1], 12));
      }
    }
    final result = ChunkDefinition(
      index,
      safe,
      List.unmodifiable(hazards),
      index > 2 && index % 4 == 0 ? PowerUp.values[random.next(4)] : null,
    );
    if (validator.accept(result)) return result;
    final fallback = ChunkDefinition(index, 0, const [], null);
    validator.accept(fallback);
    return fallback;
  }
}

class CoinBody {
  double x = 0, y = 1, z = 0, previousZ = 0;
  bool active = false;
}

class ObstacleBody {
  Hazard kind = Hazard.blocker;
  double x = 0, previousX = 0, z = 0, previousZ = 0, width = 1.5;
  int lane = 0;
  int? secondLane;
  bool active = false, passed = false;
}

class TrackChunk {
  double z = 0, previousZ = 0;
  late ChunkDefinition definition;
  final obstacles = List.generate(2, (_) => ObstacleBody());
  final coins = List.generate(GameConfig.coinSlots, (_) => CoinBody());
  bool powerActive = false;
  double powerZ = 0;
}

class RunnerGame {
  final void Function(GameEvent)? onEvent;
  RunnerGame({this.onEvent});
  final chunks = List.generate(GameConfig.chunkCount, (_) => TrackChunk());
  final Queue<InputCommand> _commands = Queue();
  final Queue<InputRecord> inputRecording = Queue();
  final powers = <PowerUp, double>{};
  final levels = <PowerUp, int>{for (final p in PowerUp.values) p: 1};
  late ChunkGenerator generator;
  int seed = 928471,
      tick = 0,
      lane = 0,
      coins = 0,
      baseMultiplier = 1,
      nextChunk = 0;
  double x = 0,
      previousX = 0,
      y = 0,
      previousY = 0,
      velocityY = 0,
      distance = 0,
      score = 0;
  double speed = GameConfig.initialSpeed,
      slideTime = 0,
      landingTime = 0,
      invulnerability = 0;
  double _accumulator = 0,
      _laneStart = 0,
      _laneElapsed = GameConfig.laneDuration,
      phaseTime = 0;
  double pursuitRecovery = 0, stumbleAnimation = 0;
  bool captured = false;
  bool revived = false, disposed = false;
  RunPhase phase = RunPhase.home;
  PlayerState playerState = PlayerState.idle;
  int tutorialStep = -1;
  double get alpha => _accumulator / GameConfig.step;
  double get renderX => previousX + (x - previousX) * alpha;
  double get renderY => previousY + (y - previousY) * alpha;
  int get objectCount => chunks.length * (1 + 2 + GameConfig.coinSlots + 1);
  HudSnapshot get snapshot => HudSnapshot(this);
  String get biome =>
      chunks.reduce((a, b) => a.z.abs() < b.z.abs() ? a : b).definition.biome;
  void start({int seed = 928471, bool tutorial = false, int multiplier = 1}) {
    this.seed = seed;
    generator = ChunkGenerator(seed);
    tick = 0;
    lane = 0;
    coins = 0;
    x = 0;
    y = 0;
    previousX = 0;
    previousY = 0;
    velocityY = 0;
    distance = 0;
    score = 0;
    speed = GameConfig.initialSpeed;
    pursuitRecovery = 0;
    stumbleAnimation = 0;
    captured = false;
    slideTime = 0;
    landingTime = 0;
    invulnerability = 0;
    _accumulator = 0;
    _laneElapsed = GameConfig.laneDuration;
    phaseTime = 0;
    revived = false;
    nextChunk = 0;
    baseMultiplier = multiplier;
    _commands.clear();
    inputRecording.clear();
    powers.clear();
    phase = RunPhase.running;
    playerState = PlayerState.running;
    tutorialStep = tutorial ? 0 : -1;
    for (var i = 0; i < chunks.length; i++) {
      _populate(chunks[i], (i - 1) * GameConfig.chunkLength);
    }
    if (tutorial) {
      for (final chunk in chunks) {
        if (chunk.z >= 0 && chunk.z < 24) {
          for (final coin in chunk.coins) {
            coin.x = 0;
          }
        }
      }
    }
    onEvent?.call(const GameEvent('start'));
  }

  void _populate(TrackChunk chunk, double z) {
    chunk.definition = generator.next(nextChunk++);
    chunk.z = z;
    chunk.previousZ = z;
    for (var i = 0; i < chunk.obstacles.length; i++) {
      final o = chunk.obstacles[i];
      o.active = i < chunk.definition.obstacles.length;
      o.passed = false;
      if (!o.active) continue;
      final s = chunk.definition.obstacles[i];
      o.kind = s.kind;
      o.lane = s.lane;
      o.secondLane = s.secondLane;
      o.x = s.kind == Hazard.wide
          ? (s.lane + s.secondLane!).toDouble()
          : s.lane * 2.0;
      o.previousX = o.x;
      o.width = s.kind == Hazard.wide ? 3.5 : 1.5;
      o.z = z + s.z;
      o.previousZ = o.z;
    }
    for (var i = 0; i < chunk.coins.length; i++) {
      final c = chunk.coins[i];
      c.active = true;
      c.x = chunk.definition.safeLane * 2.0;
      c.y = 1;
      c.z = z + 3 + i * 2;
      c.previousZ = c.z;
    }
    chunk.powerActive = chunk.definition.power != null;
    chunk.powerZ = z + 20;
  }

  void submit(InputCommand command) {
    if (phase != RunPhase.running || disposed) return;
    if (tutorialStep >= 0 &&
        tutorialStep < 4 &&
        command != InputCommand.values[tutorialStep]) {
      return;
    }
    if (_commands.length < 4) _commands.add(command);
  }

  void pause() {
    if (phase == RunPhase.running ||
        phase == RunPhase.reviving ||
        phase == RunPhase.dying) {
      _beforePause = phase;
      phase = RunPhase.paused;
      _commands.clear();
      onEvent?.call(const GameEvent('pause'));
    }
  }

  RunPhase _beforePause = RunPhase.running;
  void resume() {
    if (phase == RunPhase.paused) {
      phase = _beforePause;
      _accumulator = 0;
      onEvent?.call(const GameEvent('resume'));
    }
  }

  void revive() {
    if (phase != RunPhase.dead || revived) return;
    revived = true;
    pursuitRecovery = 0;
    stumbleAnimation = 0;
    captured = false;
    phase = RunPhase.reviving;
    phaseTime = 3;
    playerState = PlayerState.idle;
    x = lane * 2.0;
    y = 0;
    velocityY = 0;
    slideTime = 0;
    previousX = x;
    previousY = y;
    invulnerability = 3;
    for (final c in chunks) {
      for (final o in c.obstacles) {
        if (o.z < speed * 4) o.active = false;
      }
    }
    onEvent?.call(const GameEvent('revive'));
  }

  void restart() => start(seed: seed + 1, multiplier: baseMultiplier);
  double advance(double delta) {
    final before = tick;
    if (disposed ||
        phase == RunPhase.paused ||
        phase == RunPhase.home ||
        phase == RunPhase.dead) {
      return 0;
    }
    // Catch up ordinary rendering stalls; lifecycle pauses discard background time.
    _accumulator += delta.clamp(0, .5);
    while (_accumulator >= GameConfig.step) {
      _step(GameConfig.step);
      _accumulator -= GameConfig.step;
    }
    return (tick - before) * GameConfig.step;
  }

  void _step(double dt) {
    tick++;
    previousX = x;
    previousY = y;
    if (phase == RunPhase.dying) {
      phaseTime += dt;
      playerState = captured
          ? PlayerState.captured
          : phaseTime < .2
          ? PlayerState.hit
          : PlayerState.death;
      if (phaseTime >= 1) {
        phase = RunPhase.dead;
        onEvent?.call(const GameEvent('gameover'));
      }
      return;
    }
    if (phase == RunPhase.reviving) {
      phaseTime -= dt;
      if (phaseTime <= 0) {
        phase = RunPhase.running;
        playerState = PlayerState.running;
      }
      return;
    }
    if (phase != RunPhase.running) return;
    if (_commands.isNotEmpty) {
      final command = _commands.removeFirst();
      inputRecording.add(InputRecord(tick, command));
      if (inputRecording.length > 4096) inputRecording.removeFirst();
      var accepted = false;
      switch (command) {
        case InputCommand.left:
        case InputCommand.right:
          final target = (lane + (command == InputCommand.left ? -1 : 1)).clamp(
            -1,
            1,
          );
          if (target != lane) {
            _laneStart = x;
            lane = target;
            _laneElapsed = 0;
            accepted = true;
          }
        case InputCommand.jump:
          if (y == 0 && slideTime <= 0) {
            velocityY = GameConfig.jumpVelocity;
            playerState = PlayerState.jumping;
            accepted = true;
            onEvent?.call(const GameEvent('jump'));
          }
        case InputCommand.slide:
          if (y == 0 && velocityY == 0 && slideTime <= 0) {
            slideTime = GameConfig.slideDuration;
            accepted = true;
            onEvent?.call(const GameEvent('slide'));
          }
      }
      if (accepted && tutorialStep >= 0 && tutorialStep < 4) {
        tutorialStep++;
        onEvent?.call(const GameEvent('tutorial'));
      }
    }
    _laneElapsed = math.min(GameConfig.laneDuration, _laneElapsed + dt);
    final t = _laneElapsed / GameConfig.laneDuration;
    x = _laneStart + (lane * 2 - _laneStart) * (t * t * (3 - 2 * t));
    if (y > 0 || velocityY > 0) {
      velocityY += GameConfig.gravity * dt;
      y += velocityY * dt;
      playerState = velocityY > 0 ? PlayerState.jumping : PlayerState.falling;
      if (y <= 0) {
        y = 0;
        velocityY = 0;
        landingTime = .08;
        onEvent?.call(const GameEvent('land'));
      }
    }
    pursuitRecovery = math.max(0, pursuitRecovery - dt);
    stumbleAnimation = math.max(0, stumbleAnimation - dt);
    slideTime = math.max(0, slideTime - dt);
    landingTime = math.max(0, landingTime - dt);
    invulnerability = math.max(0, invulnerability - dt);
    if (y == 0 && velocityY == 0) {
      playerState = stumbleAnimation > 0
          ? PlayerState.stumbling
          : slideTime > 0
          ? PlayerState.sliding
          : landingTime > 0
          ? PlayerState.landing
          : PlayerState.running;
    }
    for (final p in powers.keys.toList()) {
      powers[p] = math.max(0, powers[p]! - dt);
      if (powers[p] == 0) powers.remove(p);
    }
    // Tutorial prompts wait in a safe section until each action is demonstrated.
    if (tutorialStep >= 0 && tutorialStep < 4) return;
    speed = GameConfig.speedAt(distance);
    final move = speed * dt;
    distance += move;
    score +=
        move * baseMultiplier * (powers.containsKey(PowerUp.score) ? 2 : 1);
    onEvent?.call(GameEvent('distance', move));
    for (final chunk in chunks) {
      chunk.previousZ = chunk.z;
      chunk.z -= move;
      for (final o in chunk.obstacles) {
        if (!o.active) continue;
        o.previousZ = o.z;
        o.previousX = o.x;
        o.z -= move;
        if (o.kind == Hazard.drone) {
          final center = (o.lane + o.secondLane!).toDouble();
          o.x = center + math.sin(tick * dt * 1.4) * .7;
        }
        if (_hits(o) && invulnerability <= 0) {
          if (powers.containsKey(PowerUp.shield)) {
            powers.remove(PowerUp.shield);
            o.active = false;
            invulnerability = 1.2;
            if (o.kind == Hazard.gap) {
              y = 0;
              velocityY = 0;
            }
            onEvent?.call(const GameEvent('shield'));
          } else if ((o.kind == Hazard.low || o.kind == Hazard.high) &&
              pursuitRecovery <= 0) {
            o.active = false;
            pursuitRecovery = 6;
            stumbleAnimation = .45;
            playerState = PlayerState.stumbling;
            onEvent?.call(const GameEvent('stumble'));
          } else {
            captured = (o.kind == Hazard.low || o.kind == Hazard.high);
            if (captured) onEvent?.call(const GameEvent('capture'));
            phase = RunPhase.dying;
            phaseTime = 0;
            playerState = PlayerState.hit;
            onEvent?.call(const GameEvent('hit'));
            return;
          }
        }
        if (!o.passed && o.z < -.8) {
          o.passed = true;
          if (o.kind == Hazard.low && y > .7) {
            onEvent?.call(const GameEvent('barrier'));
          }
        }
      }
      for (final c in chunk.coins) {
        if (!c.active) continue;
        c.previousZ = c.z;
        c.z -= move;
        final dx = x - c.x, dy = y + .9 - c.y, dz = -c.z;
        if (powers.containsKey(PowerUp.magnet) &&
            dx * dx + dy * dy + dz * dz < 64) {
          final amount = 1 - math.exp(-9 * dt);
          c.x += dx * amount;
          c.y += dy * amount;
          c.z += dz * amount;
        }
        if ((x - c.x).abs() < .65 &&
            (y + .9 - c.y).abs() < .8 &&
            c.z < .6 &&
            c.previousZ > -.6) {
          c.active = false;
          final amount = powers.containsKey(PowerUp.coins) ? 2 : 1;
          coins += amount;
          onEvent?.call(GameEvent('coin', amount.toDouble()));
          if (tutorialStep == 4) {
            tutorialStep = -1;
            onEvent?.call(const GameEvent('tutorialDone'));
          }
        }
        if (c.z < -4) c.active = false;
      }
      chunk.powerZ -= move;
      if (chunk.powerActive &&
          chunk.powerZ < .7 &&
          chunk.powerZ > -.7 &&
          (x - chunk.definition.safeLane * 2).abs() < .7 &&
          (y - 0.2).abs() < 1) {
        chunk.powerActive = false;
        activate(chunk.definition.power!);
      }
      if (chunk.z + GameConfig.chunkLength < -12) {
        final front = chunks.map((c) => c.z).reduce(math.max);
        _populate(chunk, front + GameConfig.chunkLength);
      }
    }
  }

  bool _hits(ObstacleBody o) {
    final depth = o.kind == Hazard.gap
        ? 1.5
        : o.kind == Hazard.low
        ? .2
        : .65;
    if (o.z > depth + .25 || o.previousZ < -depth - .25) return false;
    if (o.kind == Hazard.gap) {
      return math.min(previousY, y) < .32 &&
          math.max(previousX, x) + .2 > o.x - o.width / 2 &&
          math.min(previousX, x) - .2 < o.x + o.width / 2;
    }
    const radius = .24;
    final height = slideTime > 0 ? .62 : 1.75;
    final halfSegment = height / 2 - radius;
    final lower = o.kind == Hazard.high ? 1.05 : 0.0;
    final upper = switch (o.kind) {
      Hazard.low => .68,
      Hazard.high => 2.16,
      Hazard.drone => 1.75,
      Hazard.wide => 2.2,
      Hazard.blocker => 2.3,
      Hazard.gap => 0.0,
    };
    return sweptSphereBox(
      from: [previousX - o.previousX, previousY + height / 2, -o.previousZ],
      to: [x - o.x, y + height / 2, -o.z],
      min: [-o.width / 2 + .1, lower - halfSegment, -depth],
      max: [o.width / 2 - .1, upper + halfSegment, depth],
      radius: radius,
    );
  }

  void activate(PowerUp power) {
    powers[power] = 8 + (levels[power]! - 1) * 2.0;
    onEvent?.call(GameEvent('powerup', power.index.toDouble()));
  }

  void dispose() {
    disposed = true;
    _commands.clear();
    inputRecording.clear();
    powers.clear();
  }
}
