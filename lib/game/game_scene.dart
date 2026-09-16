import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'runner_game.dart';
import 'runner_renderer.dart';

class GameScene implements RunnerRenderer {
  bool _paused = false;
  int _lastTick = -1;
  final RunnerGame game;
  final bool enhanced;
  final prefabs = <String, Node>{};
  final skywayNodes = <Node>[];
  Node? officer;
  final officerClips = <String, AnimationClip>{};
  String officerClip = '';
  double pursuitX = -.7, pursuitZ = -3.2;
  bool disposed = false;
  final scene = Scene();
  final sparks = <Node>[];
  final sparkAge = List<double>.filled(12, 1);
  double shake = 0;
  final world = Node();
  final player = Node(name: 'Player');
  final tracks = <Node>[],
      obstacleNodes = <List<Node>>[],
      coinNodes = <List<Node>>[],
      powerNodes = <Node>[];
  final floors = <List<Node>>[],
      stationNodes = <Node>[],
      tunnelNodes = <Node>[];
  final models = <String, Node>{};
  final clips = <String, Map<String, AnimationClip>>{};
  final meshes = <String, Mesh>{};
  String character = 'pip', currentClip = '';
  bool debugColliders = false, reduceMotion = false;
  late Node shadow, shield, collider;
  // Use the same upgraded assets on native and web. The explicit override is
  // retained only for before/after review recordings.
  GameScene(this.game, {this.enhanced = true});
  Mesh boxMesh(
    String key,
    vm.Vector3 size,
    List<double> color, {
    bool glow = false,
  }) => meshes.putIfAbsent(key, () {
    final material = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(color[0], color[1], color[2], 1)
      ..roughnessFactor = .8
      ..metallicFactor = .15;
    if (glow) {
      material.emissiveFactor = vm.Vector4(
        color[0] * .5,
        color[1] * .5,
        color[2] * .5,
        1,
      );
    }
    return Mesh(CuboidGeometry(size), material);
  });
  Node box(
    Node parent,
    String key,
    List<double> size,
    List<double> color,
    List<double> position, {
    bool glow = false,
  }) {
    final n = Node(
      mesh: boxMesh(key, vm.Vector3.array(size), color, glow: glow),
    )..position = vm.Vector3.array(position);
    parent.add(n);
    return n;
  }

  @override
  Future<void> initialize() async {
    await Scene.initializeStaticResources();
    if (disposed) return;
    scene.add(world);
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.4, -1, .3),
      color: vm.Vector3(1, .91, .78),
      intensity: 2.0,
    );
    scene.environmentIntensity = .65;
    scene.exposure = 1;
    scene.fog
      ..enabled = true
      ..mode = FogMode.linear
      ..start = 45
      ..end = 150
      ..color = vm.Vector3(.045, .13, .18);
    if (enhanced) {
      for (final name in [
        'skyway',
        'station',
        'tunnel',
        'pod',
        'barrier',
        'overhead',
        'drone',
        'transit',
        'magnet',
        'shield',
        'score',
        'coins',
      ]) {
        final prefab = await loadScene('assets/native_models/$name.glb');
        if (disposed) return;
        prefabs[name] = prefab;
      }
      final loadedOfficer = await loadScene('assets/native_models/officer.glb');
      if (disposed) return;
      officer = loadedOfficer;
      scene.add(officer!);
      for (final name in ['Idle', 'Pursuit', 'Jump', 'Slide', 'Capture']) {
        officerClips[name] =
            officer!.createAnimationClip(officer!.findAnimationByName(name)!)
              ..loop = true
              ..weight = 0
              ..play();
      }
    }
    for (final id in ['pip', 'volt', 'nova']) {
      final model = await loadScene(
        'assets/${enhanced ? 'native_models' : 'models'}/$id.glb',
      );
      if (disposed) return;
      models[id] = model;
      player.add(model);
      model.visible = id == character;
      clips[id] = {
        for (final name in [
          'Idle',
          'Run',
          'Jump',
          'Fall',
          'Land',
          'Slide',
          'Hit',
          'Death',
          if (enhanced) ...['Stumble', 'Capture'],
        ])
          name: model.createAnimationClip(model.findAnimationByName(name)!)
            ..loop = ['Idle', 'Run', 'Slide'].contains(name)
            ..weight = 0
            ..play(),
      };
    }
    scene.add(player);
    for (var i = 0; i < 12; i++) {
      final spark = box(world, 'spark', [.09, .09, .09], [1, .7, .2], [
        0,
        -10,
        0,
      ], glow: true);
      spark.visible = false;
      sparks.add(spark);
    }
    // The importer reflects glTF Z. sync() orients the delivery bag toward
    // the chase camera and the face toward the character-selection camera.
    player.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 0);
    shadow = Node(
      mesh: Mesh(
        SphereGeometry(radius: .5, segments: 16, rings: 4),
        PhysicallyBasedMaterial()
          ..baseColorFactor = vm.Vector4(.015, .025, .04, 1),
      ),
    );
    world.add(shadow);
    shield =
        Node(
            mesh: Mesh(
              TorusGeometry(
                radius: .64,
                tubeRadius: .035,
                radialSegments: 24,
                tubularSegments: 6,
              ),
              PhysicallyBasedMaterial()
                ..baseColorFactor = vm.Vector4(.1, .8, .95, 1)
                ..emissiveFactor = vm.Vector4(.1, .65, .8, 1),
            ),
          )
          ..position = vm.Vector3(0, .2, 0)
          ..rotation = vm.Quaternion.axisAngle(
            vm.Vector3(1, 0, 0),
            math.pi / 2,
          );
    player.add(shield);
    collider = box(world, 'collider', [.48, 1.75, .1], [1, .05, .2], [
      0,
      .9,
      -.45,
    ]);
    collider.visible = false;
    for (var i = 0; i < game.chunks.length; i++) {
      final root = Node(name: 'Track $i');
      scene.add(root);
      tracks.add(root);
      final strips = <Node>[];
      for (var lane = -1; lane <= 1; lane++) {
        final strip = Node();
        root.add(strip);
        strips.add(strip);
        // Split at the hazard row so gaps are real holes in the road.
        box(strip, 'roadFront', [1.96, .35, 10.5], [.085, .15, .20], [
          lane * 2.0,
          -.2,
          5.25,
        ]);
        box(strip, 'roadBack', [1.96, .35, 10.5], [.085, .15, .20], [
          lane * 2.0,
          -.2,
          18.75,
        ]);
        box(strip, 'roadGap', [1.96, .35, 3], [.085, .15, .20], [
          lane * 2.0,
          -.2,
          12,
        ]);
        for (final z in [2.0, 6.0, 18.0, 22.0]) {
          box(root, 'dash', [.04, .025, 1.4], [.2, .52, .53], [
            lane * 2.0 + .88,
            .005,
            z,
          ]);
        }
      }
      floors.add(strips);
      if (enhanced) {
        final skyway = prefabs['skyway']!.clone();
        final station = prefabs['station']!.clone();
        final tunnel = prefabs['tunnel']!.clone();
        for (final section in [skyway, station, tunnel]) {
          // The importer reflects glTF Z; restore forward chunk coordinates.
          section.rotation = vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            math.pi,
          );
        }
        root.add(skyway);
        root.add(station);
        root.add(tunnel);
        skywayNodes.add(skyway);
        stationNodes.add(station);
        tunnelNodes.add(tunnel);
      } else {
        for (final side in [-1.0, 1.0]) {
          box(root, 'rail', [.15, .2, 24], [.09, .6, .59], [
            side * 3.25,
            .3,
            12,
          ], glow: true);
          box(root, 'edge', [.38, .7, 24], [.04, .085, .12], [
            side * 3.3,
            -.55,
            12,
          ]);
          box(root, 'post', [.15, 1.8, .2], [.13, .23, .29], [
            side * 3.4,
            .7,
            6,
          ]);
          box(root, 'lamp', [.25, .15, .6], [.6, 1, .94], [
            side * 3.4,
            1.65,
            6,
          ], glow: true);
          final height = 6.0 + (i * 7 % 13);
          box(
            root,
            'building$i',
            [4, height, 6],
            [.055 + i * .004, .10 + i * .005, .15 + i * .007],
            [side * (9 + i % 3 * 3), height / 2 - 6, 12],
          );
          for (var floor = 0; floor < 3; floor++) {
            box(root, 'window', [.03, .15, 3], [.07, .39, .44], [
              side * (7 + i % 3 * 3),
              floor * 1.5 - 1,
              12,
            ], glow: true);
          }
        }
        final station = Node();
        root.add(station);
        stationNodes.add(station);
        box(station, 'canopy', [8, .25, 14], [.1, .22, .27], [0, 5, 12]);
        for (final side in [-1.0, 1.0]) {
          box(station, 'pillar', [.3, 5, .3], [.17, .33, .37], [
            side * 3.8,
            2.5,
            8,
          ]);
        }
        final tunnel = Node();
        root.add(tunnel);
        tunnelNodes.add(tunnel);
        box(tunnel, 'roof', [8, .4, 24], [.045, .065, .10], [0, 5.2, 12]);
        for (final side in [-1.0, 1.0]) {
          box(tunnel, 'wall', [.3, 5, 24], [.05, .09, .13], [
            side * 3.8,
            2.5,
            12,
          ]);
        }
        for (final z in [4.0, 12.0, 20.0]) {
          box(tunnel, 'strip', [5, .03, .14], [.7, .45, .16], [
            0,
            4.95,
            z,
          ], glow: true);
        }
      }
      final os = <Node>[];
      for (var j = 0; j < 2; j++) {
        final n = Node(name: 'Obstacle $i/$j');
        scene.add(n);
        os.add(n);
        if (enhanced) {
          for (final name in [
            'pod',
            'barrier',
            'overhead',
            'drone',
            'transit',
          ]) {
            n.add(prefabs[name]!.clone()..visible = false);
          }
        } else {
          box(n, 'hazard', [1, 1, 1], [.93, .35, .105], [0, 0, 0]);
          box(n, 'hazardStripe', [1.01, .15, 1.02], [1, .74, .23], [
            0,
            .1,
            0,
          ], glow: true);
        }
      }
      obstacleNodes.add(os);
      final coinMaterial = PhysicallyBasedMaterial()
        ..baseColorFactor = vm.Vector4(1, .65, .13, 1)
        ..metallicFactor = .55
        ..roughnessFactor = .35
        ..emissiveFactor = vm.Vector4(.2, .08, 0, 1);
      final coinMesh = meshes.putIfAbsent(
        'coin',
        () => Mesh(
          CylinderGeometry(
            topRadius: .2,
            bottomRadius: .2,
            height: .075,
            radialSegments: 10,
          ),
          coinMaterial,
        ),
      );
      final cs = <Node>[];
      for (var j = 0; j < GameConfig.coinSlots; j++) {
        final n = Node(mesh: coinMesh);
        scene.add(n);
        cs.add(n);
      }
      coinNodes.add(cs);
      final p = Node();
      scene.add(p);
      powerNodes.add(p);
      if (enhanced) {
        for (final name in ['magnet', 'shield', 'score', 'coins']) {
          p.add(prefabs[name]!.clone()..visible = false);
        }
      } else {
        box(p, 'power', [.55, .55, .55], [.28, .42, 1], [0, 0, 0], glow: true);
        box(p, 'powerCore', [.2, .75, .2], [.6, 1, 1], [0, 0, 0], glow: true);
      }
    }
    sync(0);
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    for (final group in clips.values) {
      for (final clip in group.values) {
        clip.pause();
      }
    }
    for (final clip in officerClips.values) {
      clip.pause();
    }
    scene.removeAll();
    models.clear();
    clips.clear();
    meshes.clear();
    prefabs.clear();
    officerClips.clear();
    tracks.clear();
    obstacleNodes.clear();
    coinNodes.clear();
    powerNodes.clear();
    floors.clear();
    skywayNodes.clear();
    stationNodes.clear();
    tunnelNodes.clear();
    sparks.clear();
    world.removeAll();
    player.removeAll();
    officer = null;
  }

  void select(String id) {
    if (!models.containsKey(id)) return;
    character = id;
    for (final e in models.entries) {
      e.value.visible = e.key == id;
      if (e.key != id) {
        for (final clip in clips[e.key]!.values) {
          clip.weight = 0;
          clip.pause();
        }
      } else {
        for (final clip in clips[e.key]!.values) {
          clip.play();
        }
      }
    }
    currentClip = '';
  }

  PerspectiveCamera camera({bool showcase = false}) => showcase
      ? PerspectiveCamera(
          position: vm.Vector3(-2.4, 2.4, -4.6),
          target: vm.Vector3(0, 1, 1),
          fovRadiansY: .8,
          fovFar: 180,
        )
      : PerspectiveCamera(
          position: vm.Vector3(
            reduceMotion
                ? 0
                : game.renderX * .3 + math.sin(game.tick * 1.7) * shake,
            4.4,
            -8.8,
          ),
          target: vm.Vector3(reduceMotion ? 0 : game.renderX * .18, 1.2, 12),
          fovRadiansY: 1.05 + (reduceMotion ? 0 : (game.speed - 8) * .005),
          fovFar: 180,
        );
  void burst() {
    if (sparks.isEmpty) return;
    for (var i = 0; i < sparks.length; i++) {
      sparkAge[i] = 0;
      sparks[i].visible = true;
      sparks[i].position = vm.Vector3(game.x, game.y + 1, 0);
    }
  }

  @override
  void pause(bool paused) => _paused = paused;

  @override
  void update(PresentationSnapshot frame) {
    if (disposed || _paused) return;
    final dt = frame.elapsed;
    if (frame.tick < _lastTick || frame.phase == RunPhase.reviving) {
      pursuitZ = -3.2;
      pursuitX = frame.x - .9;
    }
    _lastTick = frame.tick;
    if (game.phase != RunPhase.paused) {
      shake = math.max(0, shake - dt);
      for (var i = 0; i < sparks.length; i++) {
        sparkAge[i] += dt;
        final age = sparkAge[i];
        sparks[i].visible = age < .4;
        if (age < .4) {
          final angle = i * math.pi / 6;
          sparks[i].position += vm.Vector3(
            math.cos(angle) * dt * 2,
            dt * (2 - age * 6),
            math.sin(angle) * dt * 2,
          );
          sparks[i].scale = vm.Vector3.all(1 - age / .4);
        }
      }
    }
    sync(dt, frame: frame);
    scene.update(dt);
  }

  void sync(double dt, {PresentationSnapshot? frame}) {
    player.position = vm.Vector3(
      frame?.x ?? game.renderX,
      frame?.y ?? game.renderY,
      0,
    );
    if (officer != null) {
      officer!.visible = game.phase != RunPhase.home;
      final targetZ = game.captured
          ? -.65
          : game.pursuitRecovery > 0
          ? -2.0
          : -3.2;
      final blend = 1 - math.exp(-dt * 5);
      pursuitZ += (targetZ - pursuitZ) * blend;
      pursuitX += ((game.renderX - .9).clamp(-2.7, 2.2) - pursuitX) * blend;
      officer!.position = vm.Vector3(pursuitX, 0, pursuitZ);
      officer!.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
      final next = game.captured
          ? 'Capture'
          : game.phase == RunPhase.reviving
          ? 'Idle'
          : 'Pursuit';
      if (next != officerClip) {
        officerClips[next]!.replay();
        officerClip = next;
      }
      for (final clip in officerClips.entries) {
        clip.value.weight = clip.key == next ? 1 : 0;
        if (clip.key != next) clip.value.pause();
        clip.value.playbackTimeScale = game.speed / 12;
      }
    }
    player.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      (enhanced ? math.pi : 0) +
          (game.phase == RunPhase.home
              ? math.pi
              : (reduceMotion ? 0 : (game.x - game.previousX) * 1.8)),
    );
    shadow.position = vm.Vector3(game.renderX, .02, 0);
    shadow.scale = vm.Vector3(.85, .012, .7) * (1 / (1 + game.renderY * .2));
    shield.visible =
        game.powers.containsKey(PowerUp.shield) || game.invulnerability > 0;
    collider.visible = debugColliders;
    collider.position = vm.Vector3(
      game.x,
      game.y + (game.slideTime > 0 ? 0.3 : .88),
      -.3,
    );
    collider.scale = vm.Vector3(1, game.slideTime > 0 ? 0.35 : 1, 1);
    final name = game.phase == RunPhase.home
        ? 'Idle'
        : switch (game.playerState) {
            PlayerState.idle => 'Idle',
            PlayerState.running => 'Run',
            PlayerState.jumping => 'Jump',
            PlayerState.falling => 'Fall',
            PlayerState.landing => 'Land',
            PlayerState.sliding => 'Slide',
            PlayerState.hit => 'Hit',
            PlayerState.death => 'Death',
            PlayerState.stumbling => enhanced ? 'Stumble' : 'Hit',
            PlayerState.captured => enhanced ? 'Capture' : 'Death',
          };
    if (currentClip != name) {
      clips[character]![name]!.replay();
      currentClip = name;
    }
    for (final e in clips[character]!.entries) {
      e.value.weight +=
          ((e.key == name ? 1.0 : 0.0) - e.value.weight) * math.min(1, dt * 18);
      if (dt == 0) e.value.weight = e.key == name ? 1 : 0;
      if (e.key != name && e.value.weight < .001) {
        e.value.weight = 0;
        e.value.pause();
      }
      e.value.playbackTimeScale = e.key == 'Run'
          ? game.speed / (enhanced ? 12 : 8)
          : 1;
    }
    for (var i = 0; i < game.chunks.length; i++) {
      final c = game.chunks[i];
      tracks[i].position = vm.Vector3(
        0,
        0,
        c.previousZ + (c.z - c.previousZ) * game.alpha,
      );
      if (enhanced) skywayNodes[i].visible = c.definition.biome == 'SKYWAY';
      stationNodes[i].visible = c.definition.biome == 'CENTRAL STATION';
      tunnelNodes[i].visible = c.definition.biome == 'SERVICE TUNNEL';
      for (var lane = -1; lane <= 1; lane++) {
        floors[i][lane + 1].children.last.visible = !c.obstacles.any(
          (o) => o.active && o.kind == Hazard.gap && o.lane == lane,
        );
      }
      for (var j = 0; j < 2; j++) {
        final o = c.obstacles[j], n = obstacleNodes[i][j];
        n.visible = o.active && o.kind != Hazard.gap;
        if (!n.visible) continue;
        if (enhanced) {
          n.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
          final kind = switch (o.kind) {
            Hazard.blocker => 0,
            Hazard.low => 1,
            Hazard.high => 2,
            Hazard.drone => 3,
            Hazard.wide => 4,
            Hazard.gap => 0,
          };
          for (var k = 0; k < n.children.length; k++) {
            n.children[k].visible = k == kind;
          }
          n.position = vm.Vector3(
            o.x,
            0,
            o.previousZ + (o.z - o.previousZ) * game.alpha,
          );
        } else {
          final h = o.kind == Hazard.low
              ? 0.7
              : o.kind == Hazard.high
              ? 0.55
              : o.kind == Hazard.drone
              ? 1.6
              : 2.4;
          n.position = vm.Vector3(
            o.x,
            o.kind == Hazard.high ? 1.75 : h / 2,
            o.previousZ + (o.z - o.previousZ) * game.alpha,
          );
          n.scale = vm.Vector3(o.width, h, o.kind == Hazard.low ? 0.4 : 1.3);
        }
      }
      for (var j = 0; j < c.coins.length; j++) {
        final coin = c.coins[j], n = coinNodes[i][j];
        n.visible = coin.active;
        n.position = vm.Vector3(
          coin.x,
          coin.y,
          coin.previousZ + (coin.z - coin.previousZ) * game.alpha,
        );
        n.rotation = vm.Quaternion.euler(math.pi / 2, game.tick * .015, 0);
      }
      final p = powerNodes[i];
      p.visible = c.powerActive;
      if (c.powerActive && enhanced) {
        for (var k = 0; k < p.children.length; k++) {
          p.children[k].visible = k == c.definition.power!.index;
        }
      }
      if (c.powerActive && !enhanced) {
        final color = switch (c.definition.power!) {
          PowerUp.magnet => [.55, .3, .95],
          PowerUp.shield => [.1, .8, .6],
          PowerUp.score => [.15, .45, 1.0],
          PowerUp.coins => [1.0, .6, .15],
        };
        final key = 'power${c.definition.power!.name}';
        final mesh = boxMesh(key, vm.Vector3.all(.55), color, glow: true);
        if (p.children.first.mesh != mesh) p.children.first.mesh = mesh;
      }
      p.position = vm.Vector3(c.definition.safeLane * 2.0, 1.1, c.powerZ);
      p.rotation = enhanced
          ? vm.Quaternion.axisAngle(
              vm.Vector3(0, 1, 0),
              math.sin(game.tick * .01) * .35,
            )
          : vm.Quaternion.euler(.2, game.tick * .01, .2);
    }
  }
}
